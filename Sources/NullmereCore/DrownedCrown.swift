/// The Drowned Crown (after Rise of Kingdoms' Ark of Osiris): while the
/// Moonford lies bare about each full moon, the crown of the drowned age
/// rests at its heart, lit by the moon for every House to see. A company of
/// war that stands on it as the watch turns takes it up and bears it where
/// it goes; each watch it is borne, its bearer's side, its alliance or its
/// House alone, has a mark. Struck down, the bearer lets it fall where it
/// stood, for whoever comes next. When the water comes back, the side with
/// the most marks is given moonsalt, each of its Houses; the crown sinks
/// again until the next full moon.
public struct DrownedCrown: Codable, Equatable, Sendable {
    /// Where it lies, or is borne.
    public internal(set) var hex: Hex
    /// The company bearing it, if one is.
    public internal(set) var bearer: Int?
    /// Marks by side: an alliance's id, or minus one less the House's.
    public internal(set) var marks: [Int: Int]

    public init(hex: Hex, bearer: Int? = nil, marks: [Int: Int] = [:]) {
        self.hex = hex
        self.bearer = bearer
        self.marks = marks
    }
}

extension GameState {
    /// What each House of the side that bore the crown longest is given.
    public static let crownPrize = Stock(moonsalt: 20)

    /// The side a House stands on for the crown: its alliance, or itself.
    public func crownSide(of house: Int) -> Int {
        alliance(of: house).map(\.id) ?? -1 - house
    }

    /// The Houses of a side.
    public func houses(ofCrownSide side: Int) -> [Int] {
        if side < 0 { return houses.indices.contains(-1 - side) ? [-1 - side] : [] }
        return alliance(side)?.members ?? []
    }

    /// A side's name, as the realm tells it.
    public func crownSideName(_ side: Int) -> String {
        if side < 0 { return houses.indices.contains(-1 - side) ? houses[-1 - side].name : "a House gone" }
        return alliance(side)?.name ?? "an alliance gone"
    }

    /// The side leading, with its marks, if any has one.
    public func crownLeader() -> (side: Int, marks: Int)? {
        guard let crown, let best = crown.marks.max(by: { ($0.value, -$0.key) < ($1.value, -$1.key) }), best.value > 0 else { return nil }
        return (best.key, best.value)
    }

    /// The crown as the watch turns, after the tide: surfaced as the ford
    /// lies bare, borne and marked while it does, and given as it closes.
    mutating func contestCrown() -> [GameEvent] {
        guard let course = ford, !course.isEmpty else {
            guard crown != nil else { return [] }
            let leader = crownLeader()
            crown = nil
            guard let leader else { return [.crownSank(side: nil, houses: [])] }
            let winners = houses(ofCrownSide: leader.side).filter { !houses[$0].isEliminated }
            for house in winners { houses[house].stock.credit(GameState.crownPrize) }
            record(.omen, winners, "The water comes back over the ford and the Drowned Crown sinks; "
                + "\(crownSideName(leader.side)) bore it longest, \(leader.marks) watch\(leader.marks == 1 ? "" : "es"), and the lake gives them moonsalt.")
            return [.crownSank(side: leader.side, houses: winners)]
        }
        guard var held = crown else {
            let heart = course[course.count / 2]
            crown = DrownedCrown(hex: heart)
            record(.omen, [], "The Drowned Crown lies at the heart of the ford, lit by the moon.")
            return [.crownSurfaced(at: heart)]
        }
        var events: [GameEvent] = []
        if let bearer = held.bearer {
            if let unit = unit(bearer) {
                held.hex = unit.position
                held.marks[crownSide(of: unit.owner), default: 0] += 1
            } else {
                held.bearer = nil
                events.append(.crownFell(at: held.hex))
            }
        }
        crown = held
        return events + takeUpCrown()
    }

    /// A company of war standing on the crown unborne takes it up, and its
    /// side has the watch's mark: as the watch turns, and as marches end.
    mutating func takeUpCrown() -> [GameEvent] {
        guard var held = crown, held.bearer == nil, let taker = unit(at: held.hex), taker.kind.isMilitary else { return [] }
        held.bearer = taker.id
        held.marks[crownSide(of: taker.owner), default: 0] += 1
        crown = held
        return [.crownTaken(unit: taker.id, house: taker.owner)]
    }
}
