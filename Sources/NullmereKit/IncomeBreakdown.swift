import NullmereCore

/// Where a resource comes from and goes each watch, a line each: every
/// hold's yield, what the companies eat, and the omen there is.
struct IncomeBreakdown: Equatable {
    struct Line: Equatable {
        let label: String
        let amount: Int
    }

    let resource: Resource
    let lines: [Line]
    let net: Int
    let stored: Int
    let room: Int
    /// What the omen does to it, if anything.
    let omen: String?

    /// `territory` may be passed when already worked out.
    init(state: GameState, house: Int, resource: Resource, territory: [Int?]? = nil) {
        self.resource = resource
        let territory = territory ?? state.territory()
        var lines = state.holds(of: house)
            .sorted { ($0.isSeat ? 0 : 1, $0.name) < ($1.isSeat ? 0 : 1, $1.name) }
            .map { Line(label: $0.name, amount: state.income(of: $0, territory: territory)[resource]) }
            .filter { $0.amount != 0 }
        if resource == .grain {
            let upkeep = state.upkeep(of: house)
            if upkeep > 0 { lines.append(Line(label: "Companies eat", amount: -upkeep)) }
        }
        self.lines = lines
        net = lines.reduce(0) { $0 + $1.amount }
        stored = state.houses[house].stock[resource]
        room = state.storage(of: house)
        switch (state.currentOmen?.kind, resource) {
        case (.moonsaltBloom?, .moonsalt): omen = "Moonsalt Bloom doubles it."
        case (.leanWatch?, .grain): omen = "A Lean Watch takes a third of it."
        default: omen = nil
        }
    }

    /// One line, for the tooltip.
    var summary: String {
        let sources = lines.map { "\($0.label) \($0.amount >= 0 ? "+" : "")\($0.amount)" }.joined(separator: ", ")
        var text = "\(resource.title): \(stored) of \(room) stored. Each watch \(net >= 0 ? "+" : "")\(net)"
        if !sources.isEmpty { text += ": \(sources)" }
        text += "."
        if let omen { text += " \(omen)" }
        return text
    }
}
