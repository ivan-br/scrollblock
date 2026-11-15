import Foundation

struct RuleSet: Codable {
  let version: Int
  let validated: Bool
  let evidence: String
  let domains: [String]

  // Scope is by DNS name, not by source application. No wildcard or CDN-wide blocking.
  static let scopes = ["instagram.com", "cdninstagram.com"]
  static let sharedHosts = Set(["i.instagram.com", "www.instagram.com", "graph.instagram.com"])

  static func isScoped(_ host: String) -> Bool {
    scopes.contains { host == $0 || host.hasSuffix("." + $0) }
  }

  static func isCandidate(_ host: String) -> Bool {
    guard host == host.lowercased(), host.utf8.count <= 253,
          isScoped(host), !scopes.contains(host), !sharedHosts.contains(host) else { return false }
    return host.split(separator: ".", omittingEmptySubsequences: false).allSatisfy { label in
      !label.isEmpty && label.utf8.count <= 63 && label.first != "-" && label.last != "-" &&
      label.utf8.allSatisfy { (97...122).contains($0) || (48...57).contains($0) || $0 == 45 }
    }
  }

  var canBlock: Bool {
    version == 1 && validated && !evidence.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
    !domains.isEmpty && domains.count <= 64 && Set(domains).count == domains.count &&
    domains.allSatisfy(Self.isCandidate)
  }

  func blocks(_ host: String) -> Bool { canBlock && domains.contains(host.lowercased()) }

  static func load(from bundle: Bundle = .main) throws -> RuleSet {
    guard let url = bundle.url(forResource: "rules", withExtension: "json") else {
      throw NSError(domain: "Scrollblock", code: 1, userInfo: [NSLocalizedDescriptionKey: "Blocking rules are missing from this build."])
    }
    return try JSONDecoder().decode(RuleSet.self, from: Data(contentsOf: url))
  }
}
