import NullmereCore

/// The race for the lake: word to the player when any House, theirs
/// included, comes within reach of winning.
enum Race {
    /// A line for each House whose road to victory grew short this watch,
    /// said once each time it does.
    static func warnings(before: GameState, after: GameState, player: Int) -> [Narration.Line] {
        var lines: [Narration.Line] = []
        for house in after.livingHouses {
            let now = after.standing(of: house.id)
            guard let threat = now.threat, before.standing(of: house.id).threat != threat else { continue }
            lines.append(line(for: now, threat: threat, in: after, player: player))
        }
        return lines
    }

    static func line(for standing: Standing, threat: Outcome.Kind, in state: GameState, player: Int) -> Narration.Line {
        let mine = standing.house == player
        let name = state.houses[standing.house].title
        let short = max(standing.needed - standing.realm, 0)
        switch (threat, mine) {
        case (.ascendancy, true):
            return .init(text: "Your Moonspire reaches its fourth stage. One more, and the lake is yours.", tone: .good)
        case (.ascendancy, false):
            return .init(text: "The Moonspire of \(name) reaches its fourth stage. One more, and the lake is theirs: march on its seat.", tone: .bad)
        case (.dominion, true):
            return .init(text: "Your realm holds \(standing.realm) of the \(standing.needed) holds dominion needs: \(holds(short)) more.", tone: .good)
        case (.dominion, false):
            return .init(text: "\(name) rules \(standing.realm) of the \(standing.needed) holds dominion needs. Take holds from it before it takes the lake.", tone: .bad)
        }
    }

    private static func holds(_ count: Int) -> String {
        count == 1 ? "one" : "\(count)"
    }
}
