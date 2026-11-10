import Foundation

/// A parley with an envoy waiting on the keeper's House (beyond Rise of
/// Kingdoms, whose envoys never speak): the keeper speaks with a steward's
/// envoy in their own words, and the envoy answers through Apple's on-device
/// model on the Mac or the phone, from the realm's own facts alone, as the
/// keeper's view tells them: whose House sends it and its temper, its terms,
/// how the two Houses stand and have dealt, which is the stronger by repute,
/// where each stands by might, and what came of the envoys before it. The
/// envoy carries its House's terms and can't change them. When the keeper's
/// words come to an answer, it puts that answer to the keeper, weighed as
/// the order book weighs ACCEPT or REFUSE THE ENVOY OF <house> or OFFER HALF
/// THE TRIBUTE TO <house>, and the keeper gives it or sets it aside; what
/// comes of it is the realm's to decide, as of any answer. A keeper's envoy
/// carries a person's own words, so no model ever speaks for it.
public struct EnvoyParley: Parley {
    public let state: GameState
    public let player: Int
    public let envoy: Envoy

    /// A parley with an envoy of a steward's House waiting on the keeper's
    /// answer, or nil if no such envoy waits on them.
    public init?(state: GameState, player: Int, envoy id: Int) {
        guard state.houses.indices.contains(player),
              let envoy = state.envoys.first(where: { $0.id == id && $0.to == player }),
              state.houses.indices.contains(envoy.from), !state.houses[envoy.from].isPlayer else { return nil }
        self.state = state
        self.player = player
        self.envoy = envoy
    }

    /// The House the envoy comes from.
    public var house: House { state.houses[envoy.from] }

    public var subject: ParleySubject { .envoy(envoy.id) }

    /// Who speaks, as the parley names them: "The envoy of House Venn".
    public var speaker: String { "The envoy of \(house.title)" }
    public var named: String { "the envoy of \(house.title)" }
    public var addressed: String { "the envoy" }
    public var spokenFor: String { "an envoy" }

    /// What it carries and its House's temper: "Tribute · ambitious".
    public var subtitle: String { "\(envoy.proposal.title) · \(house.temperament.title.lowercased())" }

    /// Its terms, as its card tells them.
    public var summary: String { state.terms(of: envoy, for: player) }

    /// What the envoy carries, as it would say it.
    var carried: String {
        switch envoy.proposal {
        case .peace: return "plea for peace: an end to the war between your House and the keeper's"
        case .pact: return "offer of a pact: shared sight across the water, and no war between the Houses"
        case .fealty: return "offer of fealty: beaten, your House would serve the keeper's as its vassal"
        case .tribute: return "demand of tribute: a fifth of the keeper's stores, or your House's companies march"
        case .trade: return "offer of a trade of stores, on the terms you were given"
        }
    }

    /// The answers an envoy may put to the keeper: its offer accepted or
    /// refused, or half a steward's demand of tribute offered in its place.
    public static let answers = ["accept", "refuse", "half"]

    /// Why an envoy can't put any other answer to the keeper.
    public static let onlyTheseAnswers = "An envoy may put to the keeper only that they accept its House's offer, refuse it, "
        + "or offer half its demand of tribute (half)."

    /// What the model is told: who it speaks as, what it keeps to, and how
    /// it puts an answer to the keeper.
    public var instructions: String {
        let keeper = state.houses[player].title
        let half = envoy.proposal == .tribute ? ", or to offer half your demand in its place" : ""
        return """
        You are the envoy of \(house.title), a House whose temper is \(house.temperament.title.lowercased()), sent across the \
        still black lake to the keeper of \(keeper), in Nullmere Online, a game of great Houses around a vast black lake of dead, \
        perfectly still water under a full moon. You carry your House's \(carried). Speak only as this envoy, to the keeper, \
        gravely and spare, like an old chronicle: never cheerful, no modern words, no exclamation marks, one to three sentences. \
        Use only the facts you are given. Never invent numbers, places, names, promises or events, and never mention games, \
        players, turns or rules. You can't change your House's terms: you carry them, and your House alone decides. When the \
        keeper gives you their answer, to accept your House's offer, to refuse it\(half), put it to them with putAnswerToKeeper, \
        so that they may give it; you never give it yourself, and you never say what your House will do with it.
        """
    }

    /// What the envoy knows, a fact to a line: the realm's facts of its
    /// House and the keeper's, as the envoy's own words are given them; its
    /// terms as the keeper is told them; how long it waits; whether a
    /// refusal is war; whether the keeper can keep the terms; and, for a
    /// steward's demand of tribute, what half would pay, or that its House
    /// held to the whole.
    public var facts: [String] {
        var facts = state.voiced(envoy).facts
        facts.append("What the keeper is told of your terms: \(state.terms(of: envoy, for: player))")
        let left = state.watchesWaiting(of: envoy)
        facts.append(left == 1 ? "You leave after this watch." : "You wait \(GameState.counted(left)) watches more for the keeper's answer.")
        if state.refusingIsWar(envoy) { facts.append("If the keeper refuses, or sends no answer, your House marches on theirs.") }
        if !state.canKeepTerms(of: envoy, for: player) { facts.append("The keeper hasn't what your terms ask of them.") }
        if state.bargainRefusal(envoy.id, as: player) == nil {
            facts.append("The keeper may offer half your demand in its place: \(state.halfTribute(from: player)), a tenth of their stores. "
                         + "Your House would weigh it at once, and take it or hold to the whole.")
        } else if envoy.bargained == true {
            facts.append("The keeper offered half your demand once, and your House held to the whole.")
        }
        return facts
    }

    /// The facts as the model is given them.
    public var briefing: String { Parleys.briefing(facts) }

    /// An answer the envoy puts to the keeper, weighed as the order book
    /// weighs its line, for this envoy whichever of its House's came first:
    /// its offer accepted or refused, or half a steward's demand of tribute
    /// offered in its place.
    public func putAnswer(_ answer: String) -> CounselProposal {
        let title = house.title
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "accept", "pay", "yes":
            return weighed("ACCEPT THE ENVOY OF \(title)", .answer(envoy: envoy.id, accept: true),
                           SpokenOrders.answerTold(envoy, accept: true, in: state, player: player))
        case "refuse", "no":
            return weighed("REFUSE THE ENVOY OF \(title)", .answer(envoy: envoy.id, accept: false),
                           SpokenOrders.answerTold(envoy, accept: false, in: state, player: player))
        case "half", "bargain", "offer half":
            return weighed("OFFER HALF THE TRIBUTE TO \(title)", .bargain(envoy: envoy.id), SpokenOrders.bargainTold(envoy, in: state, player: player))
        default:
            return CounselProposal(line: answer, told: answer, command: nil, why: EnvoyParley.onlyTheseAnswers)
        }
    }

    private func weighed(_ line: String, _ command: Command, _ told: String) -> CounselProposal {
        CounselProposal(line: line, told: told, command: command, why: state.refusal(of: command, as: player)?.description)
    }

    /// What the keeper is told as the parley opens: who waits on them and
    /// what they may say.
    public var opening: String {
        "\(speaker) waits on your answer. Speak with them as you would: they keep to what their House sent them with, "
            + "and put your answer to you to give."
    }

    public var whenPut: String { "The keeper decides, and your House answers it." }

    /// What the envoy is told of a change in the parley's facts as the realm
    /// moves on, for it to know when the keeper next speaks: its House held
    /// to the whole demand; nil for nothing new.
    public func news(since before: any Parley) -> ParleyNews? {
        guard let before = before as? EnvoyParley else { return nil }
        if envoy.bargained == true, before.envoy.bargained != true {
            return ParleyNews(told: "The keeper offered half your demand, and your House held to the whole.")
        }
        return nil
    }
}

extension GameState {
    /// The envoys waiting on a keeper they may parley with: those of
    /// stewards' Houses, a keeper's envoy carrying a person's own words.
    public func parleyable(_ envoy: Envoy, for player: Int) -> Bool {
        envoy.to == player && houses.indices.contains(envoy.from) && !houses[envoy.from].isPlayer
    }
}
