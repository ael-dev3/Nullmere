import Foundation
import NullmereCore

/// What a keeper last saw of their House, kept on their Mac.
struct LastSeen: Codable, Equatable {
    let watch: Int
    let stock: Stock
    let holds: Int
    /// The House it was: absent in what was kept before it was noted.
    var house: Int?
}

/// What happened while the keeper was away: how many watches passed, how
/// their stores and holds changed, and the news that touched them.
struct AwayReport: Equatable {
    let watches: Int
    let changes: [WatchSummary.Change]
    let holdsChange: Int
    /// At most `lines` entries of the chronicle, oldest first: what touched
    /// the keeper's House before what the whole lake heard (a fall, the end
    /// of an age), and of the omens, only the latest.
    let news: [String]
    /// How many more of those the Chronicle holds than are told here.
    let more: Int

    static let lines = 8

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
        let chronicle = world.chronicle
        let since = chronicle.indices.filter { chronicle[$0].watch > seen.watch }
        let theirs = since.filter { chronicle[$0].houses.contains(player) }
        let lakes = since.filter { !chronicle[$0].houses.contains(player) && [.fall, .ending].contains(chronicle[$0].kind) }
        let omen = since.last { !chronicle[$0].houses.contains(player) && chronicle[$0].kind == .omen }
        var told = Array(theirs.suffix(AwayReport.lines))
        for index in (lakes + [omen].compactMap { $0 }).sorted().reversed() where told.count < AwayReport.lines {
            told.append(index)
        }
        news = told.sorted().map { chronicle[$0].text }
        more = theirs.count + lakes.count + (omen == nil ? 0 : 1) - told.count
    }

    /// The Chronicle's share of the rest, when there is more than is told.
    var moreLine: String? {
        switch more {
        case ..<1: return nil
        case 1: return "And one more in the Chronicle."
        default: return "And \(more) more in the Chronicle."
        }
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
