import NullmereCore

/// Watchmen on the walls: word when an enemy's companies gather near one
/// of the player's holds.
enum Sentinel {
    struct Threat: Equatable {
        let hold: Int
        let house: Int
        let companies: Int
    }

    /// How near, in tiles, a gathering is watched for.
    static let reach = 3
    /// How many companies of one House make a gathering.
    static let gathering = 2

    /// Each of the player's holds with enemy companies the player can see
    /// gathering near it, the largest House's gathering at each.
    static func threats(in state: GameState, player: Int, visible: [Bool]) -> [Threat] {
        var threats: [Threat] = []
        for hold in state.holds(of: player) {
            var counts: [Int: Int] = [:]
            for unit in state.units where unit.kind.isMilitary && state.isAtWar(player, unit.owner)
                && unit.position.distance(to: hold.position) <= reach {
                guard let index = state.map.index(of: unit.position), visible.indices.contains(index), visible[index] else { continue }
                counts[unit.owner, default: 0] += 1
            }
            if let largest = counts.max(by: { ($0.value, -$0.key) < ($1.value, -$1.key) }), largest.value >= gathering {
                threats.append(Threat(hold: hold.id, house: largest.key, companies: largest.value))
            }
        }
        return threats
    }

    static func line(for threat: Threat, in state: GameState) -> Narration.Line {
        let hold = state.hold(threat.hold)?.name ?? "your hold"
        return .init(text: "\(threat.companies) companies of \(state.houses[threat.house].title) gather near \(hold).", tone: .bad)
    }
}
