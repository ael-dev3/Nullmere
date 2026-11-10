import NullmereCore

/// The keeper's search on the phone's chart, as the Mac's Seek on the land
/// (Rise of Kingdoms' search on its map): a kind of place sought among what
/// the House has seen on the chart (`GameState.seek`), the nearest its seat
/// first; the same kind sought again, the one after the last found, round to
/// the nearest again.
public struct ChartSeeking: Equatable, Sendable {
    /// What was last sought.
    public private(set) var seeking: Seeking?
    /// Every place of it on the chart, nearest its heart first.
    public private(set) var found: [Hex] = []
    /// Which of them the chart was turned to.
    public private(set) var index = 0

    public init() {}

    /// The place the chart was turned to; nil where none was seen.
    public var at: Hex? { found.indices.contains(index) ? found[index] : nil }

    /// Seeks a kind of place on the chart, sought afresh from the world as it
    /// stands, and gives the place found: the nearest the chart's heart, or,
    /// the same kind sought again, the one after the last found (round to
    /// the nearest again); nil where the House has seen none on the chart.
    @discardableResult
    public mutating func seek(_ kind: Seeking, on chart: CompanionChart, in world: GameState, player: Int) -> Hex? {
        let fresh = world.seek(kind, from: chart.center, by: player).filter { chart.contains($0) }
        if kind == seeking, let last = at, let was = fresh.firstIndex(of: last) {
            index = (was + 1) % fresh.count
        } else {
            index = 0
        }
        seeking = kind
        found = fresh
        return at
    }

    /// What the search found, in a line as the Mac's says it, from the seat:
    /// "Saltwights, level III, 4 tiles north-east of your seat; 1 of 3
    /// seen", or that the House has seen none; nil before a search.
    public func line(on chart: CompanionChart) -> String? {
        guard let seeking else { return nil }
        guard let at else { return seeking.noneSeen }
        let things = ChartSeeking.things(of: seeking)
        let name = chart.marks.first { $0.hex == at && things.contains($0.thing) }?.name ?? "A place"
        let way = at == chart.center ? "at your seat" : "\(GameState.waySaid(to: at, from: chart.center)) of your seat"
        let of = found.count == 1 ? "the only one seen" : "\(index + 1) of \(found.count) seen"
        return "\(name.lineBegun), \(way); \(of)"
    }

    /// The chart's marks for a kind sought.
    static func things(of seeking: Seeking) -> Set<CompanionChart.Thing> {
        switch seeking {
        case .wilds: return [.wild]
        case .grain, .timber, .stone, .moonsalt: return [.site]
        case .lairs: return [.lair]
        case .shrines: return [.shrine]
        case .finds: return [.hamlet, .barrow]
        }
    }
}
