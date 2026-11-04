/// The Beacon's watch (after Rise of Kingdoms' watchtower): a keeper's hold
/// with a Beacon is warned of every company of war of another House bound
/// for it, its land or its walls, wherever that company marches from,
/// seen or not. The higher the Beacon, the more it tells: at the first
/// grade only where the march comes from; at the second whose it is and of
/// what kind; at the third how many troops march and in how many watches
/// they come. The realm works it out for each keeper's view alone.
public struct MarchWarning: Codable, Equatable, Sendable {
    /// The hold it is bound for.
    public let hold: Int
    /// Where the march is now.
    public let from: Hex
    /// Whose it is and of what kind, from a second-grade Beacon.
    public let house: Int?
    public let kind: UnitKind?
    /// How many march and when they come, from a third-grade Beacon.
    public let troops: Int?
    public let watches: Int?

    /// How far out a Beacon of a grade sees a march coming: its hold's
    /// sight and three tiles for every grade.
    public static func reach(sight: Int, grade: Int) -> Int { sight + 3 * grade }
}

extension GameState {
    /// The marches of other Houses' companies of war bound for a House's
    /// beaconed holds, as each hold's Beacon tells of them.
    public func marchWarnings(for house: Int) -> [MarchWarning] {
        guard houses.indices.contains(house) else { return [] }
        var warnings: [MarchWarning] = []
        for hold in holds(of: house) {
            let grade = hold.level(.beacon)
            guard grade > 0 else { continue }
            let reach = MarchWarning.reach(sight: hold.sight, grade: grade)
            for unit in units where unit.owner != house && unit.kind.isMilitary {
                guard let bound = unit.destination, bound.distance(to: hold.position) <= hold.territoryRadius,
                      unit.position.distance(to: hold.position) <= reach,
                      unit.position.distance(to: hold.position) > 0 else { continue }
                let steps = unit.position.distance(to: bound)
                let pace = max(unit.kind.movement, 1)
                warnings.append(MarchWarning(hold: hold.id, from: unit.position,
                                             house: grade >= 2 ? unit.owner : nil, kind: grade >= 2 ? unit.kind : nil,
                                             troops: grade >= 3 ? troops(of: unit) : nil,
                                             watches: grade >= 3 ? (steps + pace - 1) / pace : nil))
            }
        }
        return warnings.sorted { ($0.hold, $0.from.q, $0.from.r) < ($1.hold, $1.from.q, $1.from.r) }
    }
}
