import ExpoModulesCore
import Foundation
import NetworkExtension

public final class ScrollblockModule: Module {
  private var observer: NSObjectProtocol?
  private var changing = false
  private var providerID: String { (Bundle.main.bundleIdentifier ?? "com.softdev.scrollblock") + ".tunnel" }

  public func definition() -> ModuleDefinition {
    Name("Scrollblock")
    Events("onStateChange")

    OnCreate {
      self.observer = NotificationCenter.default.addObserver(forName: .NEVPNStatusDidChange, object: nil, queue: .main) { [weak self] _ in
        self?.load { manager, _ in
          guard let self else { return }
          self.sendEvent("onStateChange", self.state(manager))
        }
      }
    }
    OnDestroy { if let observer = self.observer { NotificationCenter.default.removeObserver(observer) } }

    AsyncFunction("getState") { (promise: Promise) in
      self.load { manager, error in
        if let error { promise.reject(error) } else { promise.resolve(self.state(manager)) }
      }
    }.runOnQueue(.main)

    AsyncFunction("start") { (mode: String, promise: Promise) in
      guard !self.changing else { promise.reject("BUSY", "A connection change is already in progress."); return }
      guard mode == "observe" || mode == "block" else { promise.reject("MODE", "Unknown test mode."); return }
      if mode == "block", (try? RuleSet.load().canBlock) != true {
        promise.reject("RULES_UNAVAILABLE", "Reels blocking is not ready. No selective blocking rules have been validated on a device."); return
      }
      self.changing = true
      self.load { existing, error in
        if let error { self.changing = false; promise.reject(error); return }
        let manager = existing ?? NETunnelProviderManager()
        guard ![NEVPNStatus.connected, .connecting, .reasserting, .disconnecting].contains(manager.connection.status) else {
          self.changing = false; promise.reject("BUSY", "Stop the current test before starting another."); return
        }
        let configuration = NETunnelProviderProtocol()
        configuration.providerBundleIdentifier = self.providerID
        configuration.serverAddress = "Scrollblock DNS test"
        configuration.providerConfiguration = ["mode": mode]
        manager.protocolConfiguration = configuration
        manager.localizedDescription = "Scrollblock"
        manager.isEnabled = true
        manager.isOnDemandEnabled = false
        manager.onDemandRules = []
        manager.saveToPreferences { error in
          DispatchQueue.main.async {
            if let error { self.changing = false; promise.reject(error); return }
            manager.loadFromPreferences { error in
              DispatchQueue.main.async {
                self.changing = false
                if let error { promise.reject(error); return }
                do {
                  try manager.connection.startVPNTunnel()
                  promise.resolve(self.state(manager))
                } catch { promise.reject(error) }
              }
            }
          }
        }
      }
    }.runOnQueue(.main)

    AsyncFunction("stop") { (promise: Promise) in
      guard !self.changing else { promise.reject("BUSY", "A connection change is already in progress."); return }
      self.changing = true
      self.load { manager, error in
        if let error { self.changing = false; promise.reject(error); return }
        guard let manager else { self.changing = false; promise.resolve(self.state(nil)); return }
        manager.connection.stopVPNTunnel()
        manager.isOnDemandEnabled = false
        manager.onDemandRules = []
        manager.isEnabled = false
        manager.saveToPreferences { error in
          DispatchQueue.main.async {
            self.changing = false
            if let error { promise.reject(error) } else { promise.resolve(self.state(manager)) }
          }
        }
      }
    }.runOnQueue(.main)

    AsyncFunction("snapshot") { (action: String, phase: String, promise: Promise) in
      self.load { manager, error in
        if let error { promise.reject(error); return }
        guard let connection = manager?.connection as? NETunnelProviderSession, connection.status == .connected else {
          promise.reject("NOT_CONNECTED", "Start a test session first. Diagnostics are cleared when it ends."); return
        }
        var completed = false
        let timeout = DispatchWorkItem {
          guard !completed else { return }; completed = true
          promise.reject("TIMEOUT", "The test session did not respond. Try refreshing its status.")
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + 3, execute: timeout)
        do {
          let request = try JSONSerialization.data(withJSONObject: ["action": action, "phase": phase])
          try connection.sendProviderMessage(request) { response in
            DispatchQueue.main.async {
              guard !completed else { return }; completed = true; timeout.cancel()
              guard let response, let value = String(data: response, encoding: .utf8) else {
                promise.reject("NO_RESPONSE", "No diagnostic response was received."); return
              }
              promise.resolve(value)
            }
          }
        } catch { completed = true; timeout.cancel(); promise.reject(error) }
      }
    }.runOnQueue(.main)
  }

  private func load(_ completion: @escaping (NETunnelProviderManager?, Error?) -> Void) {
    NETunnelProviderManager.loadAllFromPreferences { managers, error in
      DispatchQueue.main.async {
        completion(managers?.first { ($0.protocolConfiguration as? NETunnelProviderProtocol)?.providerBundleIdentifier == self.providerID }, error)
      }
    }
  }

  private func state(_ manager: NETunnelProviderManager?) -> [String: Any] {
    let status: String
    switch manager?.connection.status ?? .invalid {
    case .connected: status = "connected"
    case .connecting: status = "connecting"
    case .disconnecting: status = "disconnecting"
    case .reasserting: status = "reasserting"
    case .disconnected, .invalid: status = "disconnected"
    @unknown default: status = "unknown"
    }
    let config = (manager?.protocolConfiguration as? NETunnelProviderProtocol)?.providerConfiguration
    return ["status": status, "mode": config?["mode"] as? String ?? "observe",
            "rulesReady": (try? RuleSet.load().canBlock) == true, "available": true]
  }
}
