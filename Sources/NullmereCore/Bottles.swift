/// Bottles on the lake: words sealed in a bottle and set on the still water
/// from a hold on its shore. The lake's slow current carries each round its
/// deep heart, a hex a watch, until it washes up on a shore, where the
/// first company or hold of any House beside it finds it and reads it:
/// signed or not, an offer, a warning or a lie, to a stranger. A bottle
/// afloat too long sinks.
public struct Bottle: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    /// The House that set it on the water.
    public let from: Int
    /// Whether its finder is told whose it was.
    public let signed: Bool
    /// The words in it; in a keeper's view, only of their own bottles and
    /// those they found.
    public internal(set) var words: String
    /// The watch it was set on the water.
    public let cast: Int
    public internal(set) var position: Hex
    /// Washed up on a shore, rather than afloat.
    public internal(set) var ashore: Bool
    /// The House that found it, once found.
    public internal(set) var foundBy: Int?

    public init(id: Int, from: Int, signed: Bool, words: String, cast: Int, position: Hex, ashore: Bool = false, foundBy: Int? = nil) {
        self.id = id
        self.from = from
        self.signed = signed
        self.words = words
        self.cast = cast
        self.position = position
        self.ashore = ashore
        self.foundBy = foundBy
    }
}

extension GameState {
    /// What a bottle and its cork cost.
    public static let bottleCost = Stock(grain: 10)
    /// The watches a bottle stays afloat before it sinks.
    public static let bottleAfloat = 40
    /// The most bottles the lake keeps, the oldest found let go first.
    public static let bottlesKept = 60
    /// In a hundred, the chance a bottle beside a shore washes up on it.
    public static let washesUp = 40

    /// Every bottle afloat, ashore, or found and kept.
    public var bottlesOnTheLake: [Bottle] { bottles ?? [] }

    /// The water beside a hold a bottle is set on: its still water or
    /// shallows nearest the deep heart.
    public func castingWater(beside hold: Hold) -> Hex? {
        let heart = moonWater?.hex ?? .origin
        return map.neighbors(of: hold.position)
            .filter { map[$0].map { $0.terrain == .still || $0.terrain == .shallows } ?? false }
            .min { ($0.distance(to: heart), $0) < ($1.distance(to: heart), $1) }
    }

    /// Why a House can't set a bottle on the water from a hold now, if it can't.
    public func castRefusal(_ words: String, from holdID: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard let hold = hold(holdID) else { return .unknownHold }
        guard hold.owner == house else { return .notYours }
        guard castingWater(beside: hold) != nil else { return .noWaterBeside }
        guard Envoy.carried(words) != nil else { return .nothingToSay }
        guard houses[house].stock.covers(GameState.bottleCost) else { return .shortOf(houses[house].stock.shortfall(for: GameState.bottleCost)) }
        if bottlesOnTheLake.contains(where: { $0.from == house && $0.cast == watch }) { return .castThisWatch }
        return nil
    }

    mutating func castBottle(_ words: String, from holdID: Int, signed: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = castRefusal(words, from: holdID, as: house) { throw refusal }
        let hold = self.hold(holdID)!
        houses[house].stock.debit(GameState.bottleCost)
        let bottle = Bottle(id: takeID(), from: house, signed: signed, words: Envoy.carried(words)!, cast: watch,
                            position: castingWater(beside: hold)!)
        bottles = bottlesOnTheLake + [bottle]
        return [.bottleCast(bottle: bottle.id, from: house, at: bottle.position)]
    }

    /// The lake's current at a hex: round its deep heart, against the sun.
    func current(at hex: Hex) -> (x: Double, y: Double) {
        let layout = HexLayout(size: 1)
        let point = layout.center(of: hex), heart = layout.center(of: moonWater?.hex ?? .origin)
        let (dx, dy) = (point.x - heart.x, point.y - heart.y)
        return (-dy, dx)
    }

    /// The bottles as the watch turns: each afloat drifts a hex on the
    /// current, washes up beside a shore, or sinks when too long afloat;
    /// each washed up and not yet found is found by the first company or
    /// hold beside it.
    mutating func driftBottles() -> [GameEvent] {
        guard var all = bottles, !all.isEmpty else { return [] }
        var events: [GameEvent] = []
        let layout = HexLayout(size: 1)
        for index in all.indices where all[index].foundBy == nil {
            var bottle = all[index]
            if !bottle.ashore {
                var random = SeededRandom(seed: Seed.mix(settings.seed, UInt64(watch), UInt64(bottle.id)))
                let neighbours = map.neighbors(of: bottle.position)
                let shores = neighbours.filter { map[$0].map { !$0.terrain.isWater && $0.terrain.isPassable } ?? false }
                if let shore = shores.min(), random.chance(GameState.washesUp) {
                    bottle.position = shore
                    bottle.ashore = true
                } else {
                    // A hex on with the current, the way most along it.
                    let flow = current(at: bottle.position), here = layout.center(of: bottle.position)
                    let along = neighbours.filter { map[$0].map { $0.terrain == .still || $0.terrain == .shallows } ?? false }
                        .max { a, b in
                            let (pa, pb) = (layout.center(of: a), layout.center(of: b))
                            return ((pa.x - here.x) * flow.x + (pa.y - here.y) * flow.y, a) < ((pb.x - here.x) * flow.x + (pb.y - here.y) * flow.y, b)
                        }
                    if let along { bottle.position = along }
                }
            }
            all[index] = bottle
            if bottle.ashore, let finder = finder(of: bottle) {
                all[index].foundBy = finder
                events.append(.bottleFound(bottle: all[index], by: finder))
            }
        }
        // Too long afloat, a bottle sinks; the found are kept, the latest.
        let sunk = all.filter { !$0.ashore && $0.foundBy == nil && watch - $0.cast >= GameState.bottleAfloat }
        all.removeAll { bottle in sunk.contains { $0.id == bottle.id } }
        let found = all.filter { $0.foundBy != nil }
        if found.count > GameState.bottlesKept {
            let letGo = Set(found.prefix(found.count - GameState.bottlesKept).map(\.id))
            all.removeAll { letGo.contains($0.id) }
        }
        bottles = all
        return events
    }

    /// The House that finds a bottle washed up: of a company standing on or
    /// beside it, the first mustered; else of a hold beside it.
    func finder(of bottle: Bottle) -> Int? {
        let near = units.filter { $0.position.distance(to: bottle.position) <= 1 && houses.indices.contains($0.owner) && !houses[$0.owner].isEliminated }
        if let unit = near.min(by: { $0.id < $1.id }) { return unit.owner }
        return holds.filter { $0.position.distance(to: bottle.position) <= 1 }.min { $0.id < $1.id }?.owner
    }
}
