import NullmereCore

/// Watchmen on the walls: word when an enemy's companies gather near one
/// of the player's holds.
enum Sentinel {
    typealias Threat = Gathering

    /// How near, in tiles, a gathering is watched for.
    static let reach = GameState.gatheringReach
    /// How many companies of one House make a gathering.
    static let gathering = GameState.gatheringCompanies

    /// Each of the player's holds with enemy companies the player can see
    /// gathering near it, the largest House's gathering at each.
    static func threats(in state: GameState, player: Int, visible: [Bool]) -> [Threat] {
        state.gatherings(against: player) { hex in
            guard let index = state.map.index(of: hex), visible.indices.contains(index) else { return false }
            return visible[index]
        }
    }

    static func line(for threat: Threat, in state: GameState) -> Narration.Line {
        .init(text: state.words(of: threat), tone: .bad)
    }
}
