import Foundation
import NullmereLive
import NullmereRealm

/// The way into a realm: where it is, and who the player is there.
public enum LiveDoor {
    /// A realm's address read from one line of text: a server and, as its
    /// path, the name of the realm's database there, as in
    /// `https://maincloud.spacetimedb.com/nullmere-online`. Nil where the
    /// text is no such address.
    public static func address(_ text: String) -> (server: URL, database: String)? {
        let text = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let url = URL(string: text), var parts = URLComponents(url: url, resolvingAgainstBaseURL: false),
              parts.scheme == "https" || parts.scheme == "http", let host = parts.host, !host.isEmpty else { return nil }
        let names = url.path.split(separator: "/")
        guard names.count == 1, let name = names.first,
              name.allSatisfy({ $0.isASCII && ($0.isLetter || $0.isNumber || $0 == "-" || $0 == "_") }) else { return nil }
        parts.path = ""
        parts.query = nil
        parts.fragment = nil
        guard let server = parts.url else { return nil }
        return (server, String(name))
    }

    /// Opens a line to a realm as the identity a store keeps, or as a new
    /// one the server makes, which the store keeps from then on: the
    /// player comes back to the same city.
    public static func open(server: URL, database: String, keeping store: any IdentityStore) async throws -> LiveClient {
        if let credentials = kept(in: store) {
            return try await LiveClient.open(server: server, database: database, credentials: credentials)
        }
        let client = try await LiveClient.open(server: server, database: database)
        try store.save(String(decoding: try JSONEncoder().encode(client.credentials), as: UTF8.self))
        return client
    }

    /// The credentials a store keeps, if it keeps any that read.
    static func kept(in store: any IdentityStore) -> SpacetimeCredentials? {
        guard let text = store.load(), let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode(SpacetimeCredentials.self, from: data)
    }
}
