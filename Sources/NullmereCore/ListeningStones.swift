import Foundation

/// Listening stones (an invention of Nullmere's own): the black lake
/// carries sound as no air does. A House sinks a stone of moonsalt in the
/// water before one of its holds on the shore, and each watch it hears at
/// the stone every company of war of another House that has marched
/// within its reach out of the House's sight: not where it is, nor whose,
/// only the quarter it was heard from and whether near or far. Two stones
/// hearing one march cross their bearings on it; a march that keeps away
/// from the water goes unheard. Its House alone knows of a stone or what
/// it heard.
public struct ListeningStone: Codable, Equatable, Sendable, Identifiable {
    public let id: Int
    public let owner: Int
    /// The hold by the lake it was sunk before.
    public let hold: Int
    /// The water it lies in.
    public let at: Hex
    public let sunk: Int
    /// Whether it has listened once: its first listening learns where
    /// every company in its reach stands, and hears nothing.
    public internal(set) var listening: Bool = false
}

/// What a stone heard in a watch.
public struct Sounding: Codable, Equatable, Sendable {
    public let stone: Int
    /// The quarter it was heard from, one of eight, east first and turning
    /// south about.
    public let quarter: Int
    /// Within half the stone's reach.
    public let near: Bool
    public let watch: Int

    public static let quarters = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
    public var quarterName: String { Sounding.quarters[quarter] }
}

extension GameState {
    /// What a stone costs.
    public static let stoneCost = Stock(moonsalt: 6)
    /// The stones a House may keep in the water.
    public static let stonesKept = 3
    /// How far a stone hears.
    public static let stoneReach = 6
    /// How far from its hold a stone may be sunk: the lake within the
    /// hold's own reach.
    public static let stoneFromHold = 5

    public var listeningStonesSunk: [ListeningStone] { listeningStones ?? [] }

    /// A House's stones.
    public func stones(of house: Int) -> [ListeningStone] {
        listeningStonesSunk.filter { $0.owner == house }
    }

    /// What a House's stones heard at the last turn of the watch.
    public func soundings(heardBy house: Int) -> [Sounding] {
        let mine = Set(stones(of: house).map(\.id))
        return (soundings ?? []).filter { mine.contains($0.stone) }
    }

    /// The water before a hold where a stone would lie: the nearest of the
    /// lake within its reach, in a steady order.
    public func stoneWater(before hold: Hold) -> Hex? {
        hold.position.spiral(GameState.stoneFromHold).filter { map[$0]?.terrain.isWater == true && map[$0]?.terrain != .ford }
            .min { ($0.distance(to: hold.position), $0.q, $0.r) < ($1.distance(to: hold.position), $1.q, $1.r) }
    }

    /// Why a House may not sink a stone before a hold, if it may not.
    public func stoneRefusal(before holdID: Int, as house: Int) -> RuleError? {
        guard let hold = hold(holdID) else { return .unknownHold }
        guard hold.owner == house else { return .notYours }
        guard let water = stoneWater(before: hold) else { return .notOnTheShore }
        guard !listeningStonesSunk.contains(where: { $0.at == water }) else { return .stoneAlreadySunk }
        guard stones(of: house).count < GameState.stonesKept else { return .tooManyStones(GameState.stonesKept) }
        guard houses[house].stock.covers(GameState.stoneCost) else { return .shortOf(houses[house].stock.shortfall(for: GameState.stoneCost)) }
        return nil
    }

    mutating func sinkStone(before holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = stoneRefusal(before: holdID, as: house) { throw refusal }
        let water = stoneWater(before: hold(holdID)!)!
        houses[house].stock.debit(GameState.stoneCost)
        let stone = ListeningStone(id: takeID(), owner: house, hold: holdID, at: water, sunk: watch)
        listeningStones = listeningStonesSunk + [stone]
        return [.stoneSunk(stone: stone.id, house: house, hold: holdID)]
    }

    /// The quarter one hex lies in from another.
    static func quarter(of hex: Hex, from origin: Hex) -> Int {
        let layout = HexLayout()
        let a = layout.center(of: origin), b = layout.center(of: hex)
        let angle = atan2(b.y - a.y, b.x - a.x)
        return Int(((angle < 0 ? angle + 2 * .pi : angle) / (2 * .pi) * 8).rounded()) % 8
    }

    /// As the watch turns: a stone whose hold is no longer its House's is
    /// lost; each other hears every company of war of another House that
    /// has moved within its reach since it last listened, and that its
    /// House can't see.
    mutating func listenAtTheStones() -> [GameEvent] {
        guard var stones = listeningStones, !stones.isEmpty else {
            soundings = nil
            listened = nil
            return []
        }
        var events: [GameEvent] = []
        stones.removeAll { stone in
            let kept = hold(stone.hold)?.owner == stone.owner && !houses[stone.owner].isEliminated
            if !kept { events.append(.stoneLost(stone: stone.id, house: stone.owner)) }
            return !kept
        }
        listeningStones = stones.isEmpty ? nil : stones
        let before = listened ?? [:]
        var now: [Int: Hex] = [:]
        var heard: [Sounding] = []
        var sight: [Int: [Bool]] = [:]
        // A company marching dark is out of sight but close by, so the
        // stones hear it where eyes would not see it.
        var darkness: [Int: (dark: Set<Int>, close: [Bool])] = [:]
        for stone in stones.sorted(by: { $0.id < $1.id }) {
            let seen = sight[stone.owner] ?? visibility(for: stone.owner)
            sight[stone.owner] = seen
            let unseen = darkness[stone.owner] ?? {
                let dark = darkTo(stone.owner)
                return (dark, dark.isEmpty ? [] : closeSight(for: stone.owner))
            }()
            darkness[stone.owner] = unseen
            var count = 0
            for unit in units.sorted(by: { $0.id < $1.id }) where unit.owner != stone.owner && unit.kind.isMilitary {
                let distance = unit.position.distance(to: stone.at)
                guard distance <= GameState.stoneReach else { continue }
                now[unit.id] = unit.position
                guard stone.listening, before[unit.id] != unit.position else { continue }
                if let index = map.index(of: unit.position), seen.indices.contains(index), seen[index],
                   !unseen.dark.contains(unit.id) || unseen.close[index] { continue }
                heard.append(Sounding(stone: stone.id, quarter: GameState.quarter(of: unit.position, from: stone.at),
                                      near: distance <= GameState.stoneReach / 2, watch: watch))
                count += 1
            }
            if count > 0 { events.append(.stoneHeard(stone: stone.id, house: stone.owner, marches: count)) }
        }
        for index in stones.indices { stones[index].listening = true }
        listeningStones = stones.isEmpty ? nil : stones
        soundings = heard.isEmpty ? nil : heard
        listened = now.isEmpty ? nil : now
        return events
    }
}
