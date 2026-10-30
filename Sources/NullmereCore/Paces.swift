import Foundation

/// Two companies locked in battle in a realm's watch: after the first
/// exchange, blows fall again at each pace, until one falls, one draws
/// off, the war between them ends, or the fight has run its rounds.
public struct Engagement: Codable, Equatable, Sendable {
    public let attacker: Int
    public let defender: Int
    /// Where each stood as it began: one that has moved has drawn off.
    public let attackerAt: Hex
    public let defenderAt: Hex
    /// Exchanges still to come.
    public internal(set) var rounds: Int
}

/// How far a realm's watch has been walked: the paces gone by, and the
/// Houses whose stewards have given this watch's orders.
public struct Pacing: Codable, Equatable, Sendable {
    /// The paces walked so far this watch.
    public internal(set) var walked = 0
    /// The Houses whose stewards have given this watch's orders, in turn.
    public internal(set) var stewarded: [Int] = []

    public init() {}
}

extension GameState {
    /// The paces of a watch in a realm. A realm's watch isn't resolved all
    /// at once as it turns: companies on the march take their steps as it
    /// passes, each its share of the watch's moves by each pace; a host
    /// strikes the moment it is there; and each steward gives its orders at
    /// a pace of its own, spread through the watch. The last pace is the
    /// turn's own, which walks whatever is left.
    public static let pacesPerWatch = 12

    /// The moves of a watch a company may have spent by a pace: an even
    /// share of them, its first step at the first pace.
    public static func allowance(of moves: Int, by pace: Int) -> Int {
        (moves * min(max(pace, 0), pacesPerWatch) + pacesPerWatch - 1) / pacesPerWatch
    }

    /// The pace at which the steward `index`-th in this watch's order of
    /// `count` gives its orders: the first at the first pace, the rest
    /// spread evenly through the watch, all before its turn.
    public static func stewardPace(_ index: Int, of count: Int) -> Int {
        1 + index * (pacesPerWatch - 1) / max(count, 1)
    }

    /// Whether the watch is walked pace by pace, as in a realm.
    public var isPaced: Bool { pacing != nil }

    /// Exchanges of blows a battle in a realm has after its first: three in
    /// all, a pace apart, unless one side falls or draws off first.
    public static let engagementRounds = 2

    /// The battles going on.
    public var battlesJoined: [Engagement] { engagements ?? [] }

    /// A battle joined, in a realm: an attacker strikes but once at a time.
    mutating func join(_ attacker: Unit, against defender: Unit) {
        guard isPaced else { return }
        var joined = battlesJoined.filter { $0.attacker != attacker.id }
        joined.append(Engagement(attacker: attacker.id, defender: defender.id, attackerAt: attacker.position,
                                 defenderAt: defender.position, rounds: GameState.engagementRounds))
        engagements = joined
    }

    /// The battles going on exchange their blows for a pace: each whose
    /// companies both stand where they stood, within reach and at war,
    /// fights again; the rest are over.
    mutating func fightOn() -> [GameEvent] {
        var events: [GameEvent] = []
        for engagement in battlesJoined {
            guard let index = engagements?.firstIndex(of: engagement) else { continue }
            guard let attacker = unit(engagement.attacker), let defender = unit(engagement.defender),
                  attacker.position == engagement.attackerAt, defender.position == engagement.defenderAt,
                  attacker.position.distance(to: defender.position) <= attacker.kind.range,
                  isAtWar(attacker.owner, defender.owner), engagement.rounds > 0 else {
                engagements?.remove(at: index)
                continue
            }
            engagements?[index].rounds -= 1
            let left = engagement.rounds - 1
            events += exchange(attacker: attacker.id, defender: defender.id, at: defender.position)
            if left == 0 || unit(attacker.id) == nil || unit(defender.id) == nil,
               let done = engagements?.firstIndex(where: { $0.attacker == engagement.attacker && $0.defender == engagement.defender }) {
                engagements?.remove(at: done)
            }
        }
        if engagements?.isEmpty == true { engagements = nil }
        return events
    }

    /// The watch walked on to a pace: at each pace between, the stewards
    /// whose pace it is give their orders, then the companies on the march
    /// step and the hosts walk and strike. What came of it, in the order it
    /// came. Nothing in a world not walked pace by pace, nor past the last
    /// pace before the turn.
    @discardableResult
    public mutating func walk(to pace: Int, keptFor absent: Set<Int> = []) -> [GameEvent] {
        guard outcome == nil, pacing != nil else { return [] }
        var events: [GameEvent] = []
        let order = stewardOrder(keptFor: absent)
        while let walked = pacing?.walked, walked < min(pace, GameState.pacesPerWatch - 1) {
            let now = walked + 1
            pacing?.walked = now
            for (index, house) in order.enumerated() where GameState.stewardPace(index, of: order.count) == now {
                guard pacing?.stewarded.contains(house) == false, !houses[house].isEliminated else { continue }
                pacing?.stewarded.append(house)
                // What a steward does counts as it does it, as a keeper's orders do.
                events += RivalMind(house: house, caretaking: houses[house].isPlayer).takeTurn(in: &self)
            }
            var stepped = fightOn()
            for unit in units.sorted(by: { $0.id < $1.id }) where unit.destination != nil {
                guard let current = self.unit(unit.id) else { continue }
                let moves = movement(of: current)
                stepped += march(unit.id, keeping: moves - GameState.allowance(of: moves, by: now))
            }
            stepped += walkRallies(by: now)
            tally(stepped)
            noteDeeds(stepped)
            events += stepped
        }
        return events
    }

    /// What the paces left unwalked when the watch turns, early or on time:
    /// every company on the march spends the rest of the watch's moves, and
    /// every host walks the rest of its way and strikes if it is there.
    mutating func walkTheRest() -> [GameEvent] {
        var events: [GameEvent] = []
        for unit in units.sorted(by: { $0.id < $1.id }) where unit.destination != nil {
            events += march(unit.id)
        }
        events += walkRallies(by: nil)
        tally(events)
        noteDeeds(events)
        return events
    }
}
