import Foundation

/// The steward who kept a House until its keeper came, welcoming them the
/// first time they take it up in an age, given by a device's own model from
/// what the House knows alone: how long the stewards kept it, its seat and
/// holds, the people it comes of and what that gives it, how it stands in
/// strength among the Houses about the lake, its wars and pacts, and an
/// omen lying on the realm. A greeting, never an order: the first things
/// to do stand on the keeper's card beneath it.
extension Voicing {
    /// What the model is asked for the steward's welcome
    /// (`GameState.stewardWelcome`).
    public static let stewardTask = "Speak as the steward who kept the House until its keeper came, welcoming them as they take it "
        + "up: what it holds, how it stands among the Houses and what lies on the realm, keeping every name and number as given. "
        + "Propose nothing and promise nothing. Two sentences, at most 45 words."
}

extension GameState {
    /// The steward's welcome to a keeper taking up their House, for the
    /// device's model to give; nil for a House that is not.
    public func stewardWelcome(for house: Int) -> Voicing.Moment? {
        guard houses.indices.contains(house) else { return nil }
        let title = houses[house].title
        var facts = [watch > 1 ? "The stewards kept \(title) until watch \(watch), and give it to its keeper now."
                               : "\(title) passes to its keeper as the age opens."]
        let holds = holds(of: house)
        if let seat = seat(of: house) {
            let others = holds.count - 1
            facts.append("Its seat is \(seat.name), by the Still" + (others == 0 ? "." : others == 1 ? ", with one hold besides."
                                                                                     : ", with \(GameState.counted(others)) holds besides."))
        }
        let heritage = heritage(of: house)
        facts.append("It comes of \(heritage.title): \(heritage.strengths[0]), and \(heritage.strengths[1]).")
        let living = livingHouses
        let mine = strength(of: house)
        let stronger = living.filter { strength(of: $0.id) > mine }.count
        facts.append(stronger == 0 ? "Of \(GameState.counted(living.count)) Houses around the lake, none is stronger than \(title)."
                                   : "Of \(GameState.counted(living.count)) Houses around the lake, \(stronger == 1 ? "one is" : "\(GameState.counted(stronger)) are") "
                                     + "stronger than \(title).")
        let wars = living.filter { $0.id != house && stance(house, $0.id) == .war }.map(\.title)
        let pacts = living.filter { $0.id != house && stance(house, $0.id) == .pact }.map(\.title)
        facts.append(wars.isEmpty ? "It is at war with no House." : "It is at war with " + listed(Array(wars.prefix(6))) + ".")
        if !pacts.isEmpty { facts.append("It stands in a pact with " + listed(Array(pacts.prefix(6))) + ".") }
        if let omen = currentOmen {
            facts.append("An omen lies on the realm, \(omen.kind.title): \(omen.kind.effect)")
        }
        return Voicing.Moment(task: Voicing.stewardTask, facts: facts)
    }
}
