import Foundation

/// Who a keeper is to the realm: a long random token, made once on this
/// Mac and kept. It names no one; the realm knows the keeper by it and by
/// the name they chose.
public enum KeeperIdentity {
    /// A new identity: 128 random bits, as 32 hex digits.
    public static func make() -> String {
        var generator = SystemRandomNumberGenerator()
        return (0..<16).map { _ in String(format: "%02x", UInt8.random(in: .min ... .max, using: &generator)) }.joined()
    }

    public static func isWellFormed(_ identity: String) -> Bool {
        identity.count == 32 && identity.allSatisfy(\.isHexDigit)
    }
}

/// Where a keeper's identity is kept.
public protocol IdentityStore {
    func load() -> String?
    func save(_ identity: String) throws
}

extension IdentityStore {
    /// The kept identity, or a new one, kept from now on.
    public func identity() -> String {
        if let kept = load(), KeeperIdentity.isWellFormed(kept) { return kept }
        let made = KeeperIdentity.make()
        try? save(made)
        return made
    }
}

/// An identity kept in a file: for tests, and for a realm in this process.
public struct FileIdentityStore: IdentityStore {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public func load() -> String? {
        (try? String(contentsOf: url, encoding: .utf8))?.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    public func save(_ identity: String) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try identity.write(to: url, atomically: true, encoding: .utf8)
    }
}
