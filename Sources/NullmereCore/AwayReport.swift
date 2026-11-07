import Foundation

/// A store's change, for those that moved.
public struct StockChange: Hashable, Sendable {
    public let resource: Resource
    public let delta: Int

    public init(resource: Resource, delta: Int) {
        self.resource = resource
        self.delta = delta
    }
}

/// What a keeper last saw of their House, kept on their Mac or their phone.
public struct LastSeen: Codable, Equatable, Sendable {
    public let watch: Int
    public let stock: Stock
    public let holds: Int
    /// The House it was: absent in what was kept before it was noted.
    public var house: Int?

    public init(watch: Int, stock: Stock, holds: Int, house: Int? = nil) {
        self.watch = watch
        self.stock = stock
        self.holds = holds
        self.house = house
    }

    /// What a House is seen to be in a world.
    public init(of house: Int, in world: GameState) {
        self.init(watch: world.watch, stock: world.houses[house].stock, holds: world.holds(of: house).count, house: house)
    }
}

/// What happened while the keeper was away: how many watches passed, how
/// their stores and holds changed, and the news that touched them.
public struct AwayReport: Equatable, Sendable {
    public let watches: Int
    public let changes: [StockChange]
    public let holdsChange: Int
    /// At most `lines` entries of the chronicle, oldest first: what touched
    /// the keeper's House before what the whole lake heard (a fall, the end
    /// of an age), and of the omens, only the latest.
    public let news: [String]
    /// How many more of those the Chronicle holds than are told here.
    public let more: Int
    /// That a caretaker kept the House by the keeper's standing orders,
    /// where it kept it and they had given any.
    public let standing: String?

    public static let lines = 8

    /// Nil when nothing passed worth telling.
    public init?(since seen: LastSeen, now world: GameState, player: Int) {
        guard world.watch > seen.watch, world.houses.indices.contains(player) else { return nil }
        watches = world.watch - seen.watch
        let stock = world.houses[player].stock
        changes = Resource.allCases.compactMap { resource in
            let delta = stock[resource] - seen.stock[resource]
            return delta == 0 ? nil : StockChange(resource: resource, delta: delta)
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
        let orders = world.standingOrders(of: player)
        standing = watches >= RealmState.caretakerAfter && !orders.isEmpty
            ? "A caretaker kept your House by your standing orders, which still stand." : nil
    }

    /// The Chronicle's share of the rest, when there is more than is told.
    public var moreLine: String? {
        switch more {
        case ..<1: return nil
        case 1: return "And one more in the Chronicle."
        default: return "And \(more) more in the Chronicle."
        }
    }

    public var title: String {
        watches == 1 ? "While you were away, a watch passed" : "While you were away, \(watches) watches passed"
    }

    public var holdsLine: String? {
        switch holdsChange {
        case 0: return nil
        case 1: return "You hold one more hold."
        case -1: return "You lost a hold."
        case let n where n > 0: return "You hold \(n) more holds."
        default: return "You lost \(-holdsChange) holds."
        }
    }
}
