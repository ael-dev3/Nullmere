import Foundation

/// What a hold's folk remember of their last plea at their keeper's gate:
/// who brought it, what it asked, and whether it was granted, turned away,
/// or left waiting until they went home (turned away all the same); and
/// how many of the hold's pleas its House has turned away this age. Kept
/// by the realm and told only to the House the hold belongs to; the next
/// petitioner from the hold is given it to speak from (`voiced(_:)`), and
/// the keeper is told it on the plea's card, on the Mac and the phone alike
/// (`rememberedPlea(_:)`).
public struct PleaAnswer: Codable, Equatable, Sendable {
    public let hold: Int
    /// The House whose gate the folk came to.
    public var house: Int
    public var plea: Petition.Plea
    /// Who brought it.
    public var name: String
    /// The watch it was answered, or the folk went home unanswered.
    public var watch: Int
    public var granted: Bool
    /// Left waiting until the folk went home.
    public var silently: Bool
    /// How many of the hold's pleas its House has turned away this age.
    public var turnedAway: Int

    public init(hold: Int, house: Int, plea: Petition.Plea, name: String, watch: Int, granted: Bool, silently: Bool, turnedAway: Int) {
        self.hold = hold
        self.house = house
        self.plea = plea
        self.name = name
        self.watch = watch
        self.granted = granted
        self.silently = silently
        self.turnedAway = turnedAway
    }

    /// How it was answered, by `who`: "you granted it", "the keeper
    /// turned them away", "you sent no answer".
    public func said(by who: String) -> String {
        granted ? "\(who) granted it" : silently ? "\(who) sent no answer" : "\(who) turned them away"
    }
}

extension Petition.Plea {
    /// What a plea of this kind asked, as a line of memory says it: "to
    /// have its ward mended".
    public var askedFor: String {
        switch self {
        case .mend: return "to have its ward mended"
        case .douse: return "to have the fire in its blackwood beaten out"
        case .tend: return "to have a hurt company tended"
        case .hands: return "to lend the folk's hands to its work"
        case .feast: return "to hold a feast"
        }
    }
}

extension GameState {
    /// What the folk of `hold` remember of their last plea, if they have
    /// brought one this age.
    public func lastPlea(of hold: Int) -> PleaAnswer? {
        pleas?.first { $0.hold == hold }
    }

    /// Keeps how a plea was answered. A hold taken by another House starts
    /// its count afresh.
    mutating func rememberPlea(_ petition: Petition, granted: Bool, silently: Bool) {
        var kept = pleas ?? []
        let turned = granted ? 0 : 1
        let before = kept.firstIndex { $0.hold == petition.hold }
        let count = before.map { kept[$0].house == petition.house ? kept[$0].turnedAway : 0 } ?? 0
        let answer = PleaAnswer(hold: petition.hold, house: petition.house, plea: petition.plea, name: petition.name, watch: watch,
                                granted: granted, silently: silently, turnedAway: count + turned)
        if let before { kept[before] = answer } else { kept.append(answer) }
        pleas = kept
    }

    /// What the keeper is told on a plea's card of the hold's last: "Wenholme's
    /// folk last came to your gate in watch 9: Edda, a mason, asked to have
    /// its ward mended, and you turned them away." Nil before any, or where
    /// the hold was another House's when they came.
    public func rememberedPlea(_ petition: Petition) -> String? {
        guard let last = lastPlea(of: petition.hold), last.house == petition.house else { return nil }
        let place = hold(petition.hold)?.name ?? "The hold"
        var line = "\(place)'s folk last came to your gate in watch \(last.watch): \(last.name), \(last.plea.trade), "
            + "asked \(last.plea.askedFor), and \(last.said(by: "you"))."
        if last.turnedAway > 1 { line += " You have turned away \(last.turnedAway) of their pleas this age." }
        return line
    }

    /// The hold's last plea, as the model voicing its next petitioner is told it.
    func rememberedPleaFacts(_ petition: Petition) -> [String] {
        guard let last = lastPlea(of: petition.hold), last.house == petition.house else { return [] }
        let place = hold(petition.hold)?.name ?? "the hold"
        var facts = ["When \(place)'s folk last came to the keeper's gate, in watch \(last.watch), \(last.name), \(last.plea.trade), "
                     + "asked \(last.plea.askedFor), and \(last.said(by: "the keeper"))."]
        if last.turnedAway > 1 { facts.append("The keeper has turned away \(last.turnedAway) of \(place)'s pleas this age.") }
        return facts
    }
}
