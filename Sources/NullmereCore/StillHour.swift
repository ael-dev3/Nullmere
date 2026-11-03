import Foundation

/// The Still Hour (an invention of Nullmere's own): twice a moon the black
/// lake lies so still that it is a mirror, and every company of war
/// standing on its shore is seen in it by every House on the lake, where it
/// stands, how many and whose. A House that would not be seen casts a
/// ripple-stone from one of its holds on the shore, for moonsalt: the water
/// before its shore stirs, and none of its companies is mirrored at the
/// next Still Hour. What the lake shows is shown to all alike.
public struct StillHour: Codable, Equatable, Sendable {
    /// One company seen in the still water.
    public struct Glimpse: Codable, Equatable, Sendable {
        public let owner: Int
        public let kind: UnitKind
        public let at: Hex
        public let troops: Int
    }

    /// The watch the lake lay still.
    public let watch: Int
    /// What it showed.
    public let glimpses: [Glimpse]
    /// The Houses whose stones stirred the water, so none of theirs was seen.
    public let rippled: [Int]
}

extension GameState {
    /// The moon's ages at which the lake lies still: between the full and
    /// the half, and between the half and the dark, apart from the
    /// riddles' half moons and the dreams' dark.
    public static let stillMoons: Set<Int> = [4, 19]
    /// What a ripple-stone costs.
    public static let rippleCost = Stock(moonsalt: 8)

    /// Whether the lake lies still at a watch.
    public static func isStillHour(at watch: Int) -> Bool {
        stillMoons.contains(moonAge(at: watch))
    }

    /// The next watch the lake lies still, from this one on.
    public static func nextStillHour(from watch: Int) -> Int {
        var next = watch
        while !isStillHour(at: next) { next += 1 }
        return next
    }

    /// Whether a hex is the lake's shore: land beside its water.
    public func isShore(_ hex: Hex) -> Bool {
        guard let tile = map[hex], !tile.terrain.isWater else { return false }
        return hex.neighbors.contains { map[$0]?.terrain.isWater == true }
    }

    /// Whether a House has stirred the water against the next Still Hour.
    public func hasRippled(_ house: Int) -> Bool {
        ripples?.contains(house) == true
    }

    /// Why a House may not cast a ripple-stone from a hold now, if it may
    /// not: its own hold, on the shore, the stone paid for, one a moon.
    public func rippleRefusal(from holdID: Int, as house: Int) -> RuleError? {
        guard let hold = hold(holdID) else { return .unknownHold }
        guard hold.owner == house else { return .notYours }
        guard isShore(hold.position) || hold.position.spiral(1).contains(where: isShore) else { return .notOnTheShore }
        guard !hasRippled(house) else { return .alreadyRippled }
        guard houses[house].stock.covers(GameState.rippleCost) else { return .shortOf(houses[house].stock.shortfall(for: GameState.rippleCost)) }
        return nil
    }

    mutating func castRipple(from holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = rippleRefusal(from: holdID, as: house) { throw refusal }
        houses[house].stock.debit(GameState.rippleCost)
        ripples = (ripples ?? []) + [house]
        return [.rippleCast(house: house, hold: holdID)]
    }

    /// At the Still Hour, the lake shows every company of war on its shore
    /// to every House, but those of the Houses whose stones stirred it; and
    /// the stones sink, their stirring spent.
    mutating func layTheLakeStill() -> [GameEvent] {
        guard GameState.isStillHour(at: watch) else {
            // The last mirror fades the watch after it is shown.
            if let shown = stillHour, shown.watch < watch { stillHour = nil }
            return []
        }
        let stirred = ripples ?? []
        var glimpses: [StillHour.Glimpse] = []
        for unit in units where unit.kind.isMilitary && !stirred.contains(unit.owner) && isShore(unit.position) {
            glimpses.append(.init(owner: unit.owner, kind: unit.kind, at: unit.position, troops: troops(of: unit)))
        }
        glimpses += mirrorTheFalse()
        stillHour = StillHour(watch: watch, glimpses: glimpses, rippled: stirred.sorted())
        ripples = nil
        let shownOf = Set(glimpses.map(\.owner)).sorted()
        if !glimpses.isEmpty {
            record(.omen, shownOf, "The lake lay still as glass, and on it every House saw \(glimpses.count) companies standing on its shore.")
        }
        return [.stillHour(glimpses: glimpses.count, houses: shownOf)]
    }
}
