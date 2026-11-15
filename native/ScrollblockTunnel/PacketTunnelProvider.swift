import Foundation
import NetworkExtension

final class PacketTunnelProvider: NEPacketTunnelProvider {
  private let work = DispatchQueue(label: "com.softdev.scrollblock.dns")
  private var running = false
  private var mode = "observe"
  private var rules: RuleSet?
  private var session: URLSession?
  private var timer: DispatchSourceTimer?
  private var pending = 0
  private var queried = 0
  private var blocked = 0
  private var phase = "baseline"
  private var events: [[String: Any]] = []

  override func startTunnel(options: [String: NSObject]?, completionHandler: @escaping (Error?) -> Void) {
    work.async {
      do {
        let configuration = (self.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration ?? [:]
        self.mode = configuration["mode"] as? String ?? "observe"
        guard ["observe", "block"].contains(self.mode) else { throw self.failure("Unknown session mode.") }
        let rules = try RuleSet.load()
        guard self.mode != "block" || rules.canBlock else {
          throw self.failure("Reels blocking is unavailable: no validated selective rules are installed.")
        }
        self.rules = rules
        let settings = NEPacketTunnelNetworkSettings(tunnelRemoteAddress: "198.18.0.53")
        let ipv4 = NEIPv4Settings(addresses: ["198.18.0.1"], subnetMasks: ["255.255.255.255"])
        ipv4.includedRoutes = [NEIPv4Route(destinationAddress: "198.18.0.53", subnetMask: "255.255.255.255")]
        settings.ipv4Settings = ipv4
        let dns = NEDNSSettings(servers: ["198.18.0.53"])
        dns.matchDomains = RuleSet.scopes
        dns.matchDomainsNoSearch = true
        settings.dnsSettings = dns
        settings.mtu = 1280
        self.setTunnelNetworkSettings(settings) { error in
          self.work.async {
            guard error == nil else { completionHandler(error); return }
            let config = URLSessionConfiguration.ephemeral
            config.timeoutIntervalForRequest = 4
            config.timeoutIntervalForResource = 5
            config.httpMaximumConnectionsPerHost = 6
            config.urlCache = nil
            config.httpCookieStorage = nil
            self.session = URLSession(configuration: config)
            self.running = true
            // Research sessions stop themselves. There is no unattended/on-demand capture.
            let timer = DispatchSource.makeTimerSource(queue: self.work)
            timer.schedule(deadline: .now() + 300)
            timer.setEventHandler { [weak self] in self?.finish("The five-minute test session ended.") }
            self.timer = timer; timer.resume()
            completionHandler(nil)
            self.readPackets()
          }
        }
      } catch { completionHandler(error) }
    }
  }

  private func readPackets() {
    guard running else { return }
    packetFlow.readPackets { packets, _ in
      self.work.async {
        guard self.running else { return }
        for data in packets {
          guard self.running else { break }
          guard let packet = DNSPacket(data), RuleSet.isScoped(packet.host) else {
            // Includes TCP DNS, fragments, unexpected routing, and oversized packets.
            self.finish("Unsupported DNS traffic encountered. The test stopped to restore normal DNS.")
            break
          }
          self.process(packet)
        }
        self.readPackets()
      }
    }
  }

  private func process(_ packet: DNSPacket) {
    queried += 1
    let deny = mode == "block" && rules?.blocks(packet.host) == true
    if events.count == 128 { events.removeFirst() }
    events.append(["host": packet.host, "phase": phase, "blocked": deny,
                   "time": ISO8601DateFormatter().string(from: Date())])
    if deny {
      blocked += 1
      packetFlow.writePackets([packet.reply(packet.errorResponse(code: 3))], withProtocols: [NSNumber(value: AF_INET)])
      return
    }
    guard pending < 32, let session else {
      finish("DNS capacity was exceeded. The test stopped to preserve connectivity."); return
    }
    pending += 1
    var request = URLRequest(url: URL(string: "https://cloudflare-dns.com/dns-query")!)
    request.httpMethod = "POST"
    request.setValue("application/dns-message", forHTTPHeaderField: "Content-Type")
    request.setValue("application/dns-message", forHTTPHeaderField: "Accept")
    request.httpBody = Data(packet.query)
    session.dataTask(with: request) { data, response, error in
      self.work.async {
        self.pending -= 1
        guard self.running else { return }
        guard error == nil, (response as? HTTPURLResponse)?.statusCode == 200,
              let data, packet.responseMatches(data), data[2] & 2 == 0 else {
          self.packetFlow.writePackets([packet.reply(packet.errorResponse(code: 2))], withProtocols: [NSNumber(value: AF_INET)])
          self.finish("DNS forwarding failed or needs an unsupported transport. Normal DNS is being restored.")
          return
        }
        self.packetFlow.writePackets([packet.reply(data)], withProtocols: [NSNumber(value: AF_INET)])
      }
    }.resume()
  }

  override func handleAppMessage(_ messageData: Data, completionHandler: ((Data?) -> Void)?) {
    work.async {
      if let request = try? JSONSerialization.jsonObject(with: messageData) as? [String: String] {
        if request["action"] == "clear" { self.events.removeAll(); self.queried = 0; self.blocked = 0 }
        if let phase = request["phase"], ["baseline", "reels", "stories", "messages", "feed"].contains(phase) { self.phase = phase }
      }
      let result: [String: Any] = ["mode": self.mode, "phase": self.phase, "queries": self.queried,
                                  "blocked": self.blocked, "events": self.events, "coverage": "OS DNS for instagram.com and cdninstagram.com only"]
      completionHandler?(try? JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]))
    }
  }

  override func stopTunnel(with reason: NEProviderStopReason, completionHandler: @escaping () -> Void) {
    work.async { self.cleanUp(); completionHandler() }
  }

  private func cleanUp() {
    running = false; timer?.cancel(); timer = nil
    session?.invalidateAndCancel(); session = nil
    events.removeAll()
  }

  private func finish(_ message: String) {
    guard running else { return }
    cleanUp()
    cancelTunnelWithError(failure(message))
  }

  private func failure(_ message: String) -> NSError {
    NSError(domain: "Scrollblock", code: 1, userInfo: [NSLocalizedDescriptionKey: message])
  }
}
