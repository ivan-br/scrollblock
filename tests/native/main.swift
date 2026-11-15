import Foundation

func check(_ condition: @autoclosure () -> Bool, _ message: String) {
  guard condition() else { fatalError(message) }
}
let unknown = RuleSet(version: 1, validated: false, evidence: "", domains: [])
check(!unknown.canBlock, "Empty rules must never enable blocking")
for host in ["instagram.com", "cdninstagram.com", "i.instagram.com", "www.instagram.com", "graph.instagram.com", "evilinstagram.com", "instagram.com.evil.test", "*.instagram.com", "media.fbcdn.net", "foo..instagram.com", "-x.instagram.com", "X.instagram.com"] {
  check(!RuleSet.isCandidate(host), "Unsafe or shared domain accepted: \(host)")
}
// This is a synthetic parser fixture, NOT a real Reels endpoint.
let host = "fixture.instagram.com"
let rule = RuleSet(version: 1, validated: true, evidence: "Synthetic test only", domains: [host])
check(rule.canBlock && rule.blocks(host), "Exact hostname rule must match")
check(!rule.blocks("child." + host), "No implicit subdomain blocking")
check(!rule.blocks("i.instagram.com"), "General Instagram API must not be blocked")
check(!RuleSet(version: 1, validated: false, evidence: "unverified", domains: [host]).canBlock, "Unverified rules enabled")
check(!RuleSet(version: 2, validated: true, evidence: "unknown schema", domains: [host]).canBlock, "Unknown rule schema enabled")

var dns: [UInt8] = [0x12, 0x34, 1, 0, 0, 1, 0, 0, 0, 0, 0, 0]
for label in host.split(separator: ".") { dns.append(UInt8(label.utf8.count)); dns.append(contentsOf: label.utf8) }
dns.append(contentsOf: [0, 0, 1, 0, 1])
func wire(_ dns: [UInt8]) -> Data {
  let length = dns.count + 28
  var ip: [UInt8] = [0x45, 0, UInt8(length >> 8), UInt8(length & 255), 0, 0, 0, 0, 64, 17, 0, 0, 198, 18, 0, 1, 198, 18, 0, 53, 0xc0, 0, 0, 53, 0, UInt8(dns.count + 8), 0, 0]
  ip.append(contentsOf: dns); return Data(ip)
}
let input = wire(dns)
guard let packet = DNSPacket(input) else { fatalError("Valid DNS query rejected") }
check(packet.host == host, "Hostname parsing")
let nxdomain = packet.errorResponse(code: 3)
check(nxdomain[0] == 0x12 && nxdomain[1] == 0x34 && nxdomain[3] & 15 == 3, "NXDOMAIN flags/transaction")
check(packet.responseMatches(nxdomain), "Response should match original question")
var wrongID = nxdomain; wrongID[0] = 0
check(!packet.responseMatches(wrongID), "Mismatched upstream transaction accepted")
let reply = [UInt8](packet.reply(nxdomain))
check(Array(reply[12..<16]) == DNSPacket.server && Array(reply[16..<20]) == [198, 18, 0, 1], "Reply address swap")
check(DNSPacket.word(reply, 20) == 53 && DNSPacket.word(reply, 22) == 49152, "Reply port swap")
check(DNSPacket.word(reply, 2) == reply.count && DNSPacket.word(reply, 24) == reply.count - 20, "Reply lengths")
var sum = 0
for offset in stride(from: 0, to: 20, by: 2) { sum += DNSPacket.word(reply, offset) }
while sum >> 16 != 0 { sum = (sum & 65535) + (sum >> 16) }
check(sum == 65535, "IPv4 checksum")
for length in 0..<input.count { check(DNSPacket(input.prefix(length)) == nil, "Truncation accepted at \(length)") }
for (offset, value) in [(0, UInt8(0x65)), (9, UInt8(6)), (6, UInt8(0x20)), (19, UInt8(54)), (25, UInt8(0))] {
  var invalid = input; invalid[offset] = value
  check(DNSPacket(invalid) == nil, "Invalid packet accepted at byte \(offset)")
}
var compressed = dns; compressed[12] = 0xc0
check(DNSPacket(wire(compressed)) == nil, "Compressed query names must fail safely")
var seed: UInt64 = 42
for count in 0..<4096 {
  let bytes: [UInt8] = (0..<(count % 256)).map { _ in seed = seed &* 6364136223846793005 &+ 1; return UInt8(truncatingIfNeeded: seed >> 32) }
  _ = DNSPacket(Data(bytes))
}
print("Native checks passed: rule gates, exact matching, DNS parsing, responses, checksums, truncation and 4096 malformed packets.")
