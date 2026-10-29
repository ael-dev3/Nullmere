/// Now and then the lake itself turns: an omen falls on the whole realm for
/// a few watches, the same for every House, told in the chronicle.
public enum OmenKind: String, Codable, CaseIterable, Sendable {
    /// Moonsalt blooms on the flats: salt yields doubled.
    case moonsaltBloom
    /// Mist rises from the Still: every company and hold sees a hex less.
    case risingMist
    /// The fields fail: grain yields fall by a third.
    case leanWatch
    /// So still a night the watchmen rest easy: wards mend twice as fast.
    case stillNight

    public var title: String {
        switch self {
        case .moonsaltBloom: return "Moonsalt Bloom"
        case .risingMist: return "Rising Mist"
        case .leanWatch: return "Lean Watch"
        case .stillNight: return "Still Night"
        }
    }

    /// What it does, in a line.
    public var effect: String {
        switch self {
        case .moonsaltBloom: return "Moonsalt yields are doubled."
        case .risingMist: return "Every company and hold sees one tile less."
        case .leanWatch: return "Grain yields fall by a third."
        case .stillNight: return "Wards mend twice as fast."
        }
    }

    var beginning: String {
        switch self {
        case .moonsaltBloom: return "Moonsalt blooms white across the flats."
        case .risingMist: return "Mist rises from the Still and lies on every shore."
        case .leanWatch: return "The fields fail; the grain comes in thin."
        case .stillNight: return "A night so still that the watchmen rest easy."
        }
    }

    var ending: String {
        switch self {
        case .moonsaltBloom: return "The bloom fades from the flats."
        case .risingMist: return "The mist lifts from the shores."
        case .leanWatch: return "The fields come back to the plough."
        case .stillNight: return "The wind returns to the water."
        }
    }
}

public struct Omen: Codable, Equatable, Sendable {
    public let kind: OmenKind
    /// The watch it fell.
    public let began: Int
    /// The watch it lifts.
    public let ends: Int

    public func watchesLeft(at watch: Int) -> Int { max(0, ends - watch) }
}

extension GameState {
    /// The chance, in a hundred, that an omen falls on a watch with none.
    static let omenChance = 7
    /// Watches with no omen after one lifts.
    static let omenRest = 6

    /// The omen on the realm, if any.
    public var currentOmen: Omen? { omen }

    /// After the watch turns: an omen lifts, or one may fall.
    mutating func turnOmens() {
        if let current = omen {
            guard watch >= current.ends else { return }
            omen = nil
            omenLifted = watch
            record(.omen, [], current.kind.ending)
            return
        }
        guard watch - (omenLifted ?? 0) > GameState.omenRest else { return }
        var random = random()
        guard random.chance(GameState.omenChance) else { return }
        let kind = random.pick(OmenKind.allCases)
        let lasts = 3 + random.int(below: 3)
        omen = Omen(kind: kind, began: watch, ends: watch + lasts)
        record(.omen, [], "\(kind.beginning) \(kind.effect)")
    }

    /// How far a company sees, under the omen there is.
    func sight(of unit: Unit) -> Int {
        let range = unit.kind.sight + (map[unit.position]?.terrain.visionBonus ?? 0)
        return omen?.kind == .risingMist ? max(1, range - 1) : range
    }

    /// How far a hold sees, under the omen there is.
    func sight(of hold: Hold) -> Int {
        omen?.kind == .risingMist ? max(1, hold.sight - 1) : hold.sight
    }

    /// A hold's yield, under the omen there is.
    func underOmen(_ yield: Stock) -> Stock {
        var total = yield
        switch omen?.kind {
        case .moonsaltBloom?: total.moonsalt *= 2
        case .leanWatch?: total.grain = total.grain * 2 / 3
        default: break
        }
        return total
    }

    /// Ward mended in a watch, under the omen there is.
    var wardMending: Int {
        omen?.kind == .stillNight ? Hold.wardRecovery * 2 : Hold.wardRecovery
    }
}
