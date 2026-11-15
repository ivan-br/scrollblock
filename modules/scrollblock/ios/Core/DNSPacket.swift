import Foundation

// Deliberately limited to unfragmented IPv4/UDP DNS on our virtual DNS address.
// Unsupported traffic terminates a diagnostic session instead of silently black-holing it.
struct DNSPacket {
  let ip: [UInt8]
  let query: [UInt8]
  let headerLength: Int
  let host: String
  let questionEnd: Int
  static let server: [UInt8] = [198, 18, 0, 53]

  static func word(_ bytes: [UInt8], _ offset: Int) -> Int {
    Int(bytes[offset]) << 8 | Int(bytes[offset + 1])
  }

  init?(_ data: Data) {
    let bytes = [UInt8](data)
    guard bytes.count >= 40, bytes[0] >> 4 == 4 else { return nil }
    let ihl = Int(bytes[0] & 15) * 4
    guard ihl >= 20, bytes.count >= ihl + 20,
          Self.word(bytes, 2) == bytes.count, Self.word(bytes, 6) & 0x3fff == 0,
          bytes[9] == 17, Array(bytes[16..<20]) == Self.server,
          Self.word(bytes, ihl + 2) == 53,
          Self.word(bytes, ihl + 4) == bytes.count - ihl else { return nil }
    let dns = Array(bytes[(ihl + 8)...])
    guard dns.count >= 17, dns.count <= 1232, dns[2] & 0xf8 == 0,
          Self.word(dns, 4) == 1, Self.word(dns, 6) == 0, Self.word(dns, 8) == 0 else { return nil }
    var cursor = 12
    var labels: [String] = []
    while cursor < dns.count {
      let count = Int(dns[cursor]); cursor += 1
      if count == 0 { break }
      guard count <= 63, cursor + count < dns.count else { return nil }
      let label = dns[cursor..<(cursor + count)]
      guard label.allSatisfy({ (65...90).contains($0) || (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }) else { return nil }
      labels.append(String(bytes: label, encoding: .ascii)!.lowercased())
      cursor += count
    }
    guard !labels.isEmpty, cursor + 4 <= dns.count,
          Self.word(dns, cursor + 2) == 1 else { return nil }
    let name = labels.joined(separator: ".")
    guard name.utf8.count <= 253 else { return nil }
    ip = bytes; query = dns; headerLength = ihl; host = name; questionEnd = cursor + 4
  }

  func errorResponse(code: UInt8) -> Data {
    var dns = Array(query.prefix(questionEnd))
    dns[2] = 0x80 | (query[2] & 1)
    dns[3] = 0x80 | (code & 15)
    for index in 6..<12 { dns[index] = 0 }
    return Data(dns)
  }

  func responseMatches(_ data: Data) -> Bool {
    let dns = [UInt8](data)
    guard dns.count >= questionEnd, dns.count <= 1232, dns[0] == query[0], dns[1] == query[1],
          dns[2] & 0x80 != 0, Self.word(dns, 4) == 1 else { return false }
    return Array(dns[12..<questionEnd]) == Array(query[12..<questionEnd])
  }

  func reply(_ payload: Data) -> Data {
    let length = 28 + payload.count
    var output = [UInt8](repeating: 0, count: 28)
    output[0] = 0x45; output[2] = UInt8(length >> 8); output[3] = UInt8(length & 255)
    output[8] = 64; output[9] = 17
    output.replaceSubrange(12..<16, with: Self.server)
    output.replaceSubrange(16..<20, with: ip[12..<16])
    output[20] = 0; output[21] = 53
    output[22] = ip[headerLength]; output[23] = ip[headerLength + 1]
    let udpLength = 8 + payload.count
    output[24] = UInt8(udpLength >> 8); output[25] = UInt8(udpLength & 255)
    var sum = 0
    for offset in stride(from: 0, to: 20, by: 2) { sum += Self.word(output, offset) }
    while sum >> 16 != 0 { sum = (sum & 65535) + (sum >> 16) }
    let checksum = (~sum) & 65535
    output[10] = UInt8(checksum >> 8); output[11] = UInt8(checksum & 255)
    // Zero UDP checksum is permitted for IPv4. No IPv6 packet is synthesized.
    output.append(contentsOf: payload)
    return Data(output)
  }
}
