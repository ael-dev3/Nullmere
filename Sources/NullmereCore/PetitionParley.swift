import Foundation

/// A parley with one of the keeper's own folk come to the gate of a hold
/// with a plea (beyond Rise of Kingdoms, whose townsfolk never speak): the
/// keeper speaks with them in their own words, and they answer through
/// Apple's on-device model on the Mac or the phone, from the plea's facts
/// alone as the keeper's view tells them: who brings it and from which
/// hold, what the folk ask and what granting it does, what turning it away
/// costs, what came of the hold's last plea, how long they wait, and
/// whether the House can pay. They ask no more than their folk ask and
/// promise nothing beyond it. When the keeper's words come to granting the
/// plea or turning it away, they put it to the keeper, weighed as the order
/// book weighs GRANT THE PLEA or TURN AWAY THE PLEA, and the keeper gives it
/// or sets it aside; what comes of it is the realm's to decide.
public struct PetitionParley: Parley {
    public let state: GameState
    public let player: Int
    public let petition: Petition

    /// A parley with the petitioner of a plea waiting on the keeper's
    /// House, or nil if no such plea waits on it.
    public init?(state: GameState, player: Int, petition id: Int) {
        guard state.houses.indices.contains(player),
              let petition = state.petitions?.first(where: { $0.id == id && $0.house == player }) else { return nil }
        self.state = state
        self.player = player
        self.petition = petition
    }

    public var subject: ParleySubject { .petition(petition.id) }
    public var speaker: String { petition.name }
    public var named: String { state.petitioner(of: petition) }
    public var addressed: String { "the petitioner" }
    public var spokenFor: String { "a petitioner" }

    /// Their trade and hold, and how long they wait: "A mason of Wenholme ·
    /// Waits 3 watches".
    public var subtitle: String {
        let trade = petition.plea.trade
        let from = "\(trade.prefix(1).uppercased())\(trade.dropFirst()) of \(state.hold(petition.hold)?.name ?? "a hold")"
        return "\(from) · \(GameState.pleaWaitsSaid(petition, at: state.watch))"
    }

    /// The plea, as its card tells it.
    public var summary: String { state.asked(by: petition) }

    /// What they may put to the keeper.
    public static let answers = ["grant", "turn away"]

    /// Why a petitioner can't put anything else to the keeper.
    public static let onlyTheseAnswers = "A petitioner may put to the keeper only that they grant the plea (grant) "
        + "or turn it away (turn away)."

    public var instructions: String {
        let keeper = state.houses[player].title
        return """
        You are \(state.petitioner(of: petition)), one of the folk of \(keeper), come to the gate of your keeper with a plea, in \
        Nullmere Online, a game of great Houses around a vast black lake of dead, perfectly still water under a full moon. Speak \
        only as this petitioner, to your keeper, plainly and with respect, like an old chronicle: never cheerful, no modern words, \
        no exclamation marks, one to three sentences. Use only the facts you are given. Never invent numbers, places, names, \
        promises or events, and never mention games, players, turns or rules. Ask no more than your folk ask, and promise nothing \
        beyond what granting the plea does. When the keeper says they would grant your plea, or turn it away, put it to them with \
        putPleaToKeeper, so that they may give it; you never give it yourself.
        """
    }

    /// What the petitioner knows, a fact to a line: the plea as the realm
    /// voices it (who brings it, what the folk ask and what granting does,
    /// what turning it away costs, what came of the hold's last plea), how
    /// long they wait, and whether the House can grant it now.
    public var facts: [String] {
        var facts = state.voiced(petition).facts
        let left = max(Petition.patience - (state.watch - petition.arrived), 1)
        facts.append(left == 1 ? "The keeper must answer this watch, or silence turns you away."
                     : "You wait \(GameState.counted(left)) watches more for the keeper's answer before silence turns you away.")
        if let refusal = state.petitionRefusal(petition.id, grant: true, as: player) {
            facts.append(refusal == .notApplicable ? "Your folk's need has passed." : "The keeper can't grant it now: \(refusal.description)")
        }
        return facts
    }

    public var briefing: String { Parleys.briefing(facts) }

    public var opening: String {
        "\(state.petitioner(of: petition)), waits at the gate. Speak with them as you would: they keep to what their folk ask, "
            + "and put your answer to you to give."
    }

    public var whenPut: String { "The keeper decides, and the realm says what comes of it." }

    /// Granting or turning away put to the keeper, weighed as the order book
    /// weighs its line.
    public func putAnswer(_ answer: String) -> CounselProposal {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "grant", "granted", "yes":
            return weighed(GameState.grantLine, .answerPetition(petition.id, grant: true), state.grantSaid(petition))
        case "turn away", "turned away", "refuse", "no":
            return weighed(GameState.turnAwayLine, .answerPetition(petition.id, grant: false), state.turnAwaySaid(petition))
        default:
            return CounselProposal(line: answer, told: answer, command: nil, why: PetitionParley.onlyTheseAnswers)
        }
    }

    private func weighed(_ line: String, _ command: Command, _ told: String) -> CounselProposal {
        CounselProposal(line: line, told: told, command: command, why: state.refusal(of: command, as: player)?.description)
    }

    /// A plea changes only by being answered, and then the parley ends.
    public func news(since before: any Parley) -> ParleyNews? { nil }
}

extension GameState {
    /// The order book's lines for the plea at the gate: a House has one at a
    /// time.
    public static let grantLine = "GRANT THE PLEA"
    public static let turnAwayLine = "TURN AWAY THE PLEA"

    /// What granting a plea orders, as the order book and a parley tell it.
    public func grantSaid(_ petition: Petition) -> String {
        "Your House grants \(petition.name)'s plea, for \(petition.price)."
    }

    /// What turning a plea away orders, as the order book and a parley tell
    /// it, and what it costs.
    public func turnAwaySaid(_ petition: Petition) -> String {
        "Your House turns \(petition.name)'s plea away, and the folk of \(hold(petition.hold)?.name ?? "the hold") "
            + "go back to their work grudging."
    }

    /// How long a plea waits for its answer: "Waits 3 watches", "Waits this
    /// watch", as the Mac's card and the phone's row tell it.
    public static func pleaWaitsSaid(_ petition: Petition, at watch: Int) -> String {
        let left = max(Petition.patience - (watch - petition.arrived), 1)
        return left == 1 ? "Waits this watch" : "Waits \(left) watches"
    }
}
