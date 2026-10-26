import NullmereCore

/// The map as VoiceOver reads it: one element for each hold the player
/// knows of and each company they can see, the player's own first, each
/// saying what it is, whose, and its state, and selecting it when chosen.
enum MapAccessibility {
    struct Item: Identifiable, Equatable {
        let id: String
        let label: String
        let selection: GameSession.Selection
    }

    @MainActor
    static func items(for session: GameSession) -> [Item] {
        let state = session.state
        let player = session.player
        func whose(_ owner: Int) -> String {
            owner == player ? "yours" : state.houses[owner].title
        }
        func place(_ hex: Hex) -> String {
            if let hold = state.hold(at: hex) { return "at \(hold.name)" }
            if let terrain = state.map[hex]?.terrain { return "on \(terrain.title.lowercased())" }
            return ""
        }

        var holds: [Item] = []
        for hold in state.holds where session.isExplored(hold.position) {
            var parts = ["\(hold.name), \(hold.isSeat ? "seat" : "hold"), \(whose(hold.owner))"]
            if hold.owner == player || session.isVisible(hold.position) {
                parts.append("ward \(hold.ward) of \(hold.maximumWard)")
            }
            if let project = hold.project, hold.owner == player {
                parts.append("raising \(project.kind.title)")
            } else if hold.owner == player {
                parts.append("idle")
            }
            if hold.level(.moonspire) > 0 { parts.append("Moonspire stage \(hold.level(.moonspire))") }
            holds.append(Item(id: "hold-\(hold.id)", label: parts.joined(separator: ", "), selection: .hold(hold.id)))
        }

        var companies: [Item] = []
        for unit in state.units where unit.owner == player || session.isVisible(unit.position) {
            let rank = unit.rank > 0 ? "\(Unit.rankTitles[unit.rank]) " : ""
            var parts = ["\(rank)\(unit.kind.title), \(whose(unit.owner)), \(place(unit.position))", "health \(unit.health)"]
            if unit.owner == player {
                if unit.fortified { parts.append("fortified") }
                else if unit.destination != nil { parts.append("marching") }
                else if unit.movesLeft > 0 { parts.append("\(unit.movesLeft) moves left, awaiting orders") }
                else { parts.append("no moves left") }
            }
            companies.append(Item(id: "unit-\(unit.id)", label: parts.joined(separator: ", "), selection: .unit(unit.id)))
        }

        func mineFirst(_ items: [Item]) -> [Item] {
            items.filter { $0.label.contains(", yours") } + items.filter { !$0.label.contains(", yours") }
        }
        return mineFirst(holds) + mineFirst(companies)
    }
}
