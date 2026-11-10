import Foundation

/// A parley with a commander the keeper's House holds prisoner (beyond Rise
/// of Kingdoms, whose captives never speak): the keeper speaks with them in
/// their own words, and they answer through Apple's on-device model on the
/// Mac or the phone, from the realm's own facts alone as the keeper's view
/// tells them: who they are and whose, how long they have been held and
/// have yet to be, what their House would pay to ransom them, how their
/// House and the keeper's stand, and the true things they have told. They
/// tell nothing more of their House: what more they know comes out only
/// when the keeper questions them, and the realm says what they tell. When
/// the keeper's words come to questioning them or letting them go home,
/// they put it to the keeper, weighed as the order book weighs QUESTION
/// <prisoner> or LET <prisoner> GO, and the keeper gives it or sets it
/// aside.
public struct PrisonerParley: Parley {
    public let state: GameState
    public let player: Int
    public let prisoner: Commander

    /// A parley with a commander the keeper's House holds prisoner, or nil
    /// if it holds no such commander.
    public init?(state: GameState, player: Int, prisoner id: Int) {
        guard state.houses.indices.contains(player), let prisoner = state.commander(id), prisoner.captive?.by == player else { return nil }
        self.state = state
        self.player = player
        self.prisoner = prisoner
    }

    public var subject: ParleySubject { .prisoner(prisoner.id) }
    public var speaker: String { prisoner.name }
    public var named: String { prisoner.name }
    public var addressed: String { "the prisoner" }
    public var spokenFor: String { "a prisoner" }

    /// Their kind of commander, whose they are and their level: "Warden of
    /// House Wenmor, level 2".
    public var subtitle: String { "\(prisoner.archetype.title) \(state.prisonerOf(prisoner))" }

    /// How long until they slip away, and the last true thing they told,
    /// as the Commanders panel and the phone's row tell them.
    public var summary: String {
        guard let captive = prisoner.captive else { return "" }
        let held = captive.leftSaid(at: state.watch) + "."
        guard let last = captive.told?.last else { return held }
        return held + " The last true thing they told: \(last)"
    }

    /// Their House's name, or that it is gone.
    var house: String {
        state.houses.indices.contains(prisoner.owner) ? state.houses[prisoner.owner].title : "a House since gone"
    }

    /// The most of what they told that they are given again, the latest.
    public static let toldRecalled = 5

    /// What questioning or letting go they may put to the keeper.
    public static let answers = ["question", "let go"]

    /// Why a prisoner can't put anything else to the keeper.
    public static let onlyTheseAnswers = "A prisoner may put to the keeper only that they question them (question) "
        + "or let them go home (let go)."

    public var instructions: String {
        let keeper = state.houses[player].title
        return """
        You are \(prisoner.name), \(prisoner.archetype.named) of \(house), taken in battle and held prisoner by the keeper of \
        \(keeper), in Nullmere Online, a game of great Houses around a vast black lake of dead, perfectly still water under a \
        full moon. Speak only as this prisoner, to the keeper who holds you, gravely and spare, like an old chronicle: proud and \
        guarded, never cheerful, no modern words, no exclamation marks, one to three sentences. Use only the facts you are given. \
        Never invent numbers, places, names, promises or events, and never mention games, players, turns or rules. Tell nothing \
        of your House beyond the true things you have already told: what more you know comes out only when the keeper questions \
        you, and then the realm says what you tell. You can't free yourself, and you never say what your House will do. When the \
        keeper says they would question you, or let you go home, put it to them with putToKeeper, so that they may give it; you \
        never give it yourself.
        """
    }

    /// What the prisoner knows, a fact to a line: who they are, when they
    /// were taken and when they slip away, what their House would pay to
    /// ransom them and how it stands with the keeper's, what they have
    /// told, and whether the keeper may question them this watch.
    public var facts: [String] {
        guard let captive = prisoner.captive else { return [] }
        let keeper = state.houses[player].title
        var facts = ["You are \(prisoner.name), \(prisoner.archetype.named) of \(house), at level \(prisoner.level)."]
        let held = state.watch - captive.since
        let when = held <= 0 ? "this watch" : held == 1 ? "a watch ago" : "\(GameState.counted(held)) watches ago"
        facts.append("\(keeper) took you prisoner \(when), when your company fell to theirs.")
        let left = captive.since + GameState.captivityLasts - state.watch
        facts.append(left <= 1 ? "You slip away as the watch turns, unless you are freed before."
                     : "You slip away in \(GameState.counted(left)) watches, unless you are freed before.")
        if state.houses.indices.contains(prisoner.owner), !state.houses[prisoner.owner].isEliminated {
            facts.append("Your House may ransom you for \(GameState.ransom(for: prisoner)); only your House may pay it.")
            facts.append("Your House and the keeper's stand at \(state.stance(prisoner.owner, player).title.lowercased()).")
        }
        var seen = Set<String>()
        let told = (captive.told ?? []).filter { seen.insert($0).inserted }.suffix(Self.toldRecalled)
        facts.append(told.isEmpty ? "You have told the keeper nothing of your House."
                     : "The true things you have told the keeper of your House: " + told.joined(separator: " "))
        facts.append(state.questionRefusal(prisoner.id, as: player) == nil
                     ? "The keeper may question you once this watch, and the realm then says what true thing you tell."
                     : "The keeper has questioned you this watch already, and may again when it turns.")
        return facts
    }

    public var briefing: String { Parleys.briefing(facts) }

    public var opening: String {
        "\(prisoner.name), your House's prisoner, is brought before you. Speak with them as you would: they tell nothing more "
            + "of their House unless you question them, and put to you what you would do with them, to give."
    }

    public var whenPut: String { "The keeper decides; questioned, the realm says what true thing you tell." }

    /// Questioning or letting go put to the keeper, weighed as the order
    /// book weighs its line for this prisoner.
    public func putAnswer(_ answer: String) -> CounselProposal {
        switch answer.trimmingCharacters(in: .whitespacesAndNewlines).lowercased() {
        case "question", "questioned", "ask":
            return weighed(GameState.questionLine(prisoner), .question(commander: prisoner.id), state.questionSaid(prisoner))
        case "let go", "let go home", "let me go", "release", "free", "go home":
            return weighed(GameState.letGoLine(prisoner), .release(commander: prisoner.id), state.letGoSaid(prisoner))
        default:
            return CounselProposal(line: answer, told: answer, command: nil, why: PrisonerParley.onlyTheseAnswers)
        }
    }

    private func weighed(_ line: String, _ command: Command, _ told: String) -> CounselProposal {
        CounselProposal(line: line, told: told, command: command, why: state.refusal(of: command, as: player)?.description)
    }

    /// Questioned, the true thing they told, as the realm says it: told to
    /// them, and shown the keeper at once.
    public func news(since before: any Parley) -> ParleyNews? {
        guard let before = before as? PrisonerParley, before.prisoner.id == prisoner.id else { return nil }
        let was = before.prisoner.captive?.told ?? [], now = prisoner.captive?.told ?? []
        guard now.count > was.count, let word = now.last else { return nil }
        return ParleyNews(told: "Questioned, you told the keeper this true thing: \(word)", shown: "\(prisoner.name) tells you: \(word)")
    }
}
