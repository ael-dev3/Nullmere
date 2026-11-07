import Foundation
import NullmereCore

/// What a keeper's Mac shows to link their phone: the realm's address and
/// the code, together in the link its QR code carries,
/// `nullmere://link?realm=<address>&code=<code>`, or typed apart. Only a
/// realm reached over HTTPS is linked to, or one on this very machine for a
/// realm raised to test: a code shown in a stranger's link can send the
/// phone to no realm in the clear.
public struct CompanionInvite: Equatable, Sendable {
    public let realm: URL
    /// The code, as the realm reads it: twelve letters and figures.
    public let code: String

    /// The scheme of the link a keeper's Mac shows.
    public static let scheme = "nullmere"
    /// The realm proper, where a phone goes unless told otherwise.
    public static let realmProper = URL(string: "https://maincloud.spacetimedb.com/nullmere")!

    public init?(realm: URL, code text: String) {
        guard CompanionInvite.isAcceptable(realm), let code = LinkCode.read(text) else { return nil }
        self.realm = realm
        self.code = code
    }

    /// A realm's address as typed and a code: an address without its scheme
    /// is taken as HTTPS.
    public init?(realm typed: String, code text: String) {
        let trimmed = typed.trimmingCharacters(in: .whitespacesAndNewlines)
        let written = trimmed.contains("://") ? trimmed : "https://" + trimmed
        guard !trimmed.isEmpty, let url = URL(string: written) else { return nil }
        self.init(realm: url, code: text)
    }

    /// The link a keeper's Mac shows, read back.
    public init?(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: false)
        guard components?.scheme?.lowercased() == CompanionInvite.scheme, components?.host?.lowercased() == "link",
              let items = components?.queryItems,
              let realm = items.first(where: { $0.name == "realm" })?.value.flatMap(URL.init(string:)),
              let code = items.first(where: { $0.name == "code" })?.value else { return nil }
        self.init(realm: realm, code: code)
    }

    /// The link to show, for the phone's camera to read.
    public var url: URL {
        var components = URLComponents()
        components.scheme = CompanionInvite.scheme
        components.host = "link"
        components.queryItems = [URLQueryItem(name: "realm", value: realm.absoluteString), URLQueryItem(name: "code", value: code)]
        return components.url!
    }

    /// Whether a phone may go to a realm at this address: over HTTPS, to a
    /// database named in its path, or over HTTP to this machine alone.
    public static func isAcceptable(_ realm: URL) -> Bool {
        let components = URLComponents(url: realm, resolvingAgainstBaseURL: false)
        guard let host = components?.host, !host.isEmpty, realm.pathComponents.contains(where: { $0 != "/" }) else { return false }
        switch components?.scheme?.lowercased() {
        case "https": return true
        case "http": return ["127.0.0.1", "localhost", "::1"].contains(host.lowercased())
        default: return false
        }
    }
}
