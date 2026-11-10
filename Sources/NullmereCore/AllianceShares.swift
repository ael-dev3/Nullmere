/// Shares of the alliance's spoils (Rise of Kingdoms' alliance gifts):
/// when a House of an alliance strikes down a band of the wilds or breaks
/// a lair, a share is set aside for each keeper's House of the alliance,
/// the doer's own among them, theirs to take when they will: stores by the
/// deed's level, and from a lair an hourglass too. Twelve wait for a House
/// at most, the oldest giving way to the newest, and each lapses untaken
/// after twenty-four watches. None is set aside for a House kept by its
/// steward alone, which has no keeper to take it.
public struct AllianceShare: Codable, Equatable, Sendable {
    /// What earned it.
    public enum Deed: String, Codable, CaseIterable, Sendable {
        /// A band of the wilds struck down.
        case wilds
        /// A lair broken.
        case lair
    }

    /// The House it is set aside for.
    public let house: Int
    /// The House whose deed earned it.
    public let from: Int
    public let deed: Deed
    /// The level of the wilds struck down or of the lair broken.
    public let level: Int
    /// The watch it was set aside.
    public let given: Int

    public init(house: Int, from: Int, deed: Deed, level: Int, given: Int) {
        self.house = house
        self.from = from
        self.deed = deed
        self.level = level
        self.given = given
    }

    /// The stores it holds, more for a greater deed.
    public var stores: Stock {
        let level = max(level, 1)
        switch deed {
        case .wilds: return Stock(grain: 10 * level, timber: 10 * level, stone: 5 * level)
        case .lair: return Stock(grain: 30 * level, timber: 30 * level, stone: 20 * level, moonsalt: level)
        }
    }

    /// The items it holds besides: an hourglass from a lair.
    public var items: [ItemKind] { deed == .lair ? [.hourglass] : [] }

    /// The watch it lapses at, untaken.
    public var lapses: Int { given + AllianceShare.lasts }

    /// How many watches a share waits to be taken.
    public static let lasts = 24
    /// The most that wait for a House at once.
    public static let kept = 12
    /// What taking them does, said beside them on the Mac and the phone.
    public static let said = "When a House of your alliance strikes down the wilds or breaks a lair, a share of the spoils is set aside "
        + "for each of its keepers: yours to take within \(lasts) watches, \(kept) waiting at most."
}

extension GameState {
    /// The shares waiting for a House, the oldest first.
    public func shares(of house: Int) -> [AllianceShare] {
        (allianceShares ?? []).filter { $0.house == house && $0.lapses > watch }
    }

    /// What a House's shares hold, all told: their stores and their items.
    public func sharesHeld(by house: Int) -> (stores: Stock, items: [ItemKind]) {
        let waiting = shares(of: house)
        var stores = Stock()
        for share in waiting { stores = stores + share.stores }
        return (stores, waiting.flatMap(\.items))
    }

    /// A share said as a line: "House Orren struck down a band of the wilds, level II".
    public func shareLine(_ share: AllianceShare) -> String {
        let doer = share.from == share.house ? "Your House"
            : houses.indices.contains(share.from) ? houses[share.from].title : "A fallen House"
        let level = BuildingKind.numeral(share.level)
        switch share.deed {
        case .wilds: return "\(doer) struck down a band of the wilds, level \(level)"
        case .lair: return "\(doer) broke a lair of the wilds, level \(level)"
        }
    }

    /// Shares said as lines, the newest first, the most shown and how many more.
    public func sharesSaid(_ shares: [AllianceShare], most: Int = 5) -> [String] {
        var lines = shares.reversed().prefix(most).map(shareLine)
        if shares.count > most { lines.append("And \(shares.count - most) more") }
        return lines
    }

    /// What a House's shares hold, said as a line: "60 grain, 60 timber,
    /// 40 stone, 2 moonsalt, with a Salt Hourglass".
    public func sharesHeldSaid(by house: Int) -> String {
        let (stores, items) = sharesHeld(by: house)
        let things = ItemKind.allCases.compactMap { kind -> String? in
            let count = items.filter { $0 == kind }.count
            return count > 0 ? kind.counted(count) : nil
        }
        return things.isEmpty ? "\(stores)" : "\(stores), with \(things.joined(separator: " and "))"
    }

    /// Why a House can't take its shares now, if it can't.
    public func takeSharesRefusal(as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        return shares(of: house).isEmpty ? .noSharesWaiting : nil
    }

    /// A keeper takes every share waiting for their House: its stores, up
    /// to what the House can store, and its items, up to what it may keep.
    mutating func takeShares(as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = takeSharesRefusal(as: house) { throw refusal }
        let (stores, items) = sharesHeld(by: house)
        allianceShares?.removeAll { $0.house == house }
        if allianceShares?.isEmpty == true { allianceShares = nil }
        store(stores, for: house)
        return give(items, to: house)
    }

    /// Shares set aside for the deeds among `events`: for each keeper's
    /// House of the doer's alliance, the doer's own among them.
    mutating func setAsideShares(for events: [GameEvent]) {
        var set: [AllianceShare] = []
        for event in events {
            let doer: Int, deed: AllianceShare.Deed, level: Int
            switch event {
            case .hunted(let hunt) where hunt.wildFell:
                (doer, deed, level) = (hunt.attackerOwner, .wilds, hunt.level)
            case .lairAssaulted(let assault) where assault.broken:
                (doer, deed, level) = (assault.caller, .lair, assault.level)
            default:
                continue
            }
            guard let alliance = alliance(of: doer) else { continue }
            for member in alliance.members where houses.indices.contains(member) && houses[member].isPlayer && !houses[member].isEliminated {
                set.append(AllianceShare(house: member, from: doer, deed: deed, level: level, given: watch))
            }
        }
        guard !set.isEmpty else { return }
        var kept = (allianceShares ?? []) + set
        // The most a House keeps waiting, its oldest giving way.
        for house in Set(set.map(\.house)) {
            let theirs = kept.indices.filter { kept[$0].house == house }
            guard theirs.count > AllianceShare.kept else { continue }
            let dropped = Set(theirs.prefix(theirs.count - AllianceShare.kept))
            kept = kept.enumerated().filter { !dropped.contains($0.offset) }.map(\.element)
        }
        allianceShares = kept
    }

    /// Shares untaken past their time lapse as the watch turns.
    mutating func lapseShares() {
        guard let kept = allianceShares else { return }
        let left = kept.filter { $0.lapses > watch }
        allianceShares = left.isEmpty ? nil : left
    }
}
