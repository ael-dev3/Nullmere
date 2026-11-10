import Foundation

/// A commander's word to their keeper as the keeper turns to the company
/// they lead, given by a device's own model on the Mac and the phone alike
/// from what the House knows alone: who leads, where the company stands,
/// how strong it is and what it is about, what lies near it, and the fight
/// they last led it in. A word, never an order: the commander proposes
/// nothing here, for counsel is where an order may be put forward and held
/// to the rules.
extension Voicing {
    /// What the model is asked for a commander's word on their company
    /// (`CommanderCounsel.word`).
    public static let commanderTask = "Speak as the commander, reporting to your keeper as they turn to the company you lead: where it "
        + "stands, how strong it is, what it is about and what lies near, keeping every name and number as given. Propose nothing "
        + "and promise nothing. One or two sentences, at most 40 words."
}

extension CommanderCounsel {
    /// The tiles about the company a commander's word looks over, and the
    /// most it tells of what lies there, the nearest first.
    public static let wordLooks = 2
    public static let wordTells = 4
    /// The watches a fight the commander led is still told in their word.
    public static let wordRemembers = 2

    /// The commander's word on the company they lead, for the device's
    /// model to give: who leads it and the company as they would tell it,
    /// where it stands, what it is about, what the House sees near it, and
    /// the fight they led lately; nil unless they lead a company at its
    /// head.
    public var word: Voicing.Moment? {
        guard let unit = company, unit.leader == commander.id, let handle = handle(of: unit) else { return nil }
        var facts = ["\(commander.name), \(commander.archetype.named) of level \(commander.level), leads \(handle) of \(houseTitle): "
                     + "\(described(unit))."]
        let place = state.placeName(of: unit.position)
        facts.append("The company stands \(place).")
        if let doing = errandSaid(unit) { facts.append(doing) }
        let near = seen(about: unit, within: CommanderCounsel.wordLooks).prefix(CommanderCounsel.wordTells)
        facts.append(near.isEmpty ? "Near it the House sees nothing but the land."
                                  : "Near it the House sees: " + near.joined(separator: "; ") + ".")
        if let fight = battles.first, state.watch - fight.watch <= CommanderCounsel.wordRemembers {
            facts.append("In watch \(fight.watch) \(commander.name) led the fight \(fight.place): \(fight.title). \(fight.outcome.said).")
        }
        return Voicing.Moment(task: Voicing.commanderTask, facts: facts)
    }

    /// What the company is about beyond its march, as the Mac's panel and
    /// the phone's list say it: in battle, out at the land's work, at a
    /// rally or keeping an ally's gates.
    func errandSaid(_ unit: Unit) -> String? {
        if let field = state.field(of: unit.id) { return "It is in battle \(state.placeName(of: field.at))." }
        if let gathering = state.gatheringSaid(of: unit) { return gathering.prefix(1).uppercased() + gathering.dropFirst() + "." }
        switch unit.errand {
        case .rally(let id)?: return state.rallySaid(id) + "."
        case .reinforce(let hold)?: return "It keeps the gates of \(state.hold(hold)?.name ?? "an ally's hold")."
        case .gather?, .homeward?, nil: return nil
        }
    }

    /// The key a commander's word is kept under on the Mac and the phone:
    /// the commander, the watch, and what their company is about (where it
    /// marches, dug in or not, its errand, whether it lies in wait or marches
    /// dark, whether it fights, and its strength by the quarter), so a word
    /// is asked afresh each watch and once its orders or its fortunes
    /// change, but not at each pace of its march. Nil unless they lead a
    /// company at its head.
    public var wordKey: Int? {
        guard let unit = company, unit.leader == commander.id else { return nil }
        var about = 17
        func mix(_ value: Int) { about = (about * 31 + value) % 1_000_003 }
        mix(unit.destination.map { ($0.q + 2_048) * 4_096 + ($0.r + 2_048) } ?? 0)
        mix(unit.fortified ? 1 : 0)
        switch unit.errand {
        case .gather(let site)?: mix(1 + site % 4_096)
        case .homeward?: mix(5_000)
        case .rally(let id)?: mix(6_000 + id % 4_096)
        case .reinforce(let hold)?: mix(11_000 + hold % 4_096)
        case nil: mix(0)
        }
        mix(state.isWaiting(unit.id) ? 1 : 0)
        mix(state.isUnlit(unit.id) ? 1 : 0)
        mix(state.field(of: unit.id) == nil ? 0 : 1)
        mix(min(max(unit.health, 0), 100) / 25)
        return (commander.id * 100_000 + state.watch % 100_000) * 1_000 + about % 1_000
    }

    /// The commander a word's key is of.
    public static func commander(ofWord key: Int) -> Int { key / 100_000_000 }
}
