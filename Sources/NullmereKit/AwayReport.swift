import Foundation
import NullmereCore

/// What a keeper last saw of their House, kept on their Mac.
struct LastSeen: Codable, Equatable {
    let watch: Int
    let stock: Stock
    let holds: Int
}

/// What happened while the keeper was away: how many watches passed, how
/// their stores and holds changed, and the news that touched them.
struct AwayReport: Equatable {
    let watches: Int
    let changes: [WatchSummary.Change]
    let holdsChange: Int
    /// At most `lines` entries of the chronicle, oldest first.
    let news: [String]

    static let lines = 5

    /// Nil when nothing passed worth telling.
    init?(since seen: LastSeen, now world: GameState, player: Int) {
        guard world.watch > seen.watch, world.houses.indices.contains(player) else { return nil }
        watches = world.watch - seen.watch
        let stock = world.houses[player].stock
        changes = Resource.allCases.compactMap { resource in
            let delta = stock[resource] - seen.stock[resource]
            return delta == 0 ? nil : WatchSummary.Change(resource: resource, delta: delta)
        }
        holdsChange = world.holds(of: player).count - seen.holds
        let touching = world.chronicle.filter { entry in
            entry.watch > seen.watch && (entry.houses.contains(player) || [.fall, .ending].contains(entry.kind))
        }
        news = touching.suffix(AwayReport.lines).map(\.text)
    }

    var title: String {
        watches == 1 ? "While you were away, a watch passed" : "While you were away, \(watches) watches passed"
    }

    var holdsLine: String? {
        switch holdsChange {
        case 0: return nil
        case 1: return "You hold one more hold."
        case -1: return "You lost a hold."
        case let n where n > 0: return "You hold \(n) more holds."
        default: return "You lost \(-holdsChange) holds."
        }
    }
}

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
