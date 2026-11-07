import Foundation
import NullmereCore

// What a keeper last saw of their House, and what happened while they were
// away, are the rules' (NullmereCore's AwayReport); this Mac keeps the first.

extension LocalStore {
    var lastSeenURL: URL { directory.appendingPathComponent("last-seen.json") }

    func loadLastSeen() -> LastSeen? {
        guard let data = try? Data(contentsOf: lastSeenURL) else { return nil }
        return try? JSONDecoder().decode(LastSeen.self, from: data)
    }

    func saveLastSeen(_ seen: LastSeen) {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try? JSONEncoder().encode(seen).write(to: lastSeenURL, options: .atomic)
    }
}
