import Foundation
import XCTest
@testable import NullmereCore

/// A parley with a commander the keeper's House holds prisoner: who they
/// are told they are, what they know as the keeper's view tells it (when
/// they were taken and when they slip away, their ransom, how the Houses
/// stand, what they have told) and nothing more of their House; what they
/// may put to the keeper, weighed as the order book weighs its line; and
/// what they are told as the realm moves on, the true thing they tell when
/// questioned shown to the keeper too. The order book questions, lets go
/// and ransoms.
final class PrisonerParleyTests: XCTestCase {
    /// A keeper at war with a steward whose commander they took three
    /// watches ago.
    private func holding(_ seed: String) throws -> (state: GameState, me: Int, steward: Int, prisoner: Commander) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }?.id)
        _ = try state.perform(.declareWar(on: steward), as: me)
        let commander = try XCTUnwrap(state.commanders(of: steward).first)
        state.commanders![try XCTUnwrap(state.commanderIndex(commander.id))].captive = Captivity(by: me, since: state.watch - 3, questioned: 0)
        return (state, me, steward, try XCTUnwrap(state.commander(commander.id)))
    }

    func testAPrisonerIsParleyedWith() throws {
        let (state, me, steward, prisoner) = try holding("a prisoner's parley")
        let view = state.view(for: me)
        let title = state.houses[steward].title, mine = state.houses[me].title
        let parley = try XCTUnwrap(PrisonerParley(state: view, player: me, prisoner: prisoner.id))
        XCTAssertEqual(parley.subject, .prisoner(prisoner.id))
        XCTAssertEqual(Parleys.parley(.prisoner(prisoner.id), in: view, player: me)?.subject, .prisoner(prisoner.id))
        XCTAssertEqual(parley.speaker, prisoner.name)
        XCTAssertEqual(parley.named, prisoner.name)
        XCTAssertEqual(parley.addressed, "the prisoner")
        XCTAssertEqual(parley.spokenFor, "a prisoner")
        XCTAssertEqual(parley.subtitle, "\(prisoner.archetype.title) of \(title), level \(prisoner.level)")
        XCTAssertEqual(parley.summary, "Slips away in 17 watches.")
        XCTAssertEqual(parley.opening, "\(prisoner.name), your House's prisoner, is brought before you. Speak with them as you would: "
                       + "they tell nothing more of their House unless you question them, and put to you what you would do with them, to give.")
        XCTAssertEqual(parley.whenPut, "The keeper decides; questioned, the realm says what true thing you tell.")

        // Who they are, what they keep to, and how they put something forward.
        let told = parley.instructions
        XCTAssertTrue(told.hasPrefix("You are \(prisoner.name), \(prisoner.archetype.named) of \(title), taken in battle and held "
                                     + "prisoner by the keeper of \(mine)"), told)
        XCTAssertTrue(told.contains("Tell nothing of your House beyond the true things you have already told"), told)
        XCTAssertTrue(told.contains("When the keeper says they would question you, or let you go home, put it to them with putToKeeper"), told)
        XCTAssertTrue(told.contains("Never invent numbers, places, names, promises or events"))

        // What they know: the realm's facts as the keeper's view tells them,
        // and nothing of their House they have not told.
        XCTAssertEqual(parley.facts, [
            "You are \(prisoner.name), \(prisoner.archetype.named) of \(title), at level \(prisoner.level).",
            "\(mine) took you prisoner 3 watches ago, when your company fell to theirs.",
            "You slip away in 17 watches, unless you are freed before.",
            "Your House may ransom you for \(GameState.ransom(for: prisoner)); only your House may pay it.",
            "Your House and the keeper's stand at war.",
            "You have told the keeper nothing of your House.",
            "The keeper may question you once this watch, and the realm then says what true thing you tell.",
        ])
        XCTAssertEqual(parley.briefing, Parleys.briefing(parley.facts))
        for known in state.knowledge(of: steward) {
            XCTAssertFalse(parley.briefing.contains(known), "Untold: \(known)")
            XCTAssertFalse(parley.instructions.contains(known), "Untold: \(known)")
        }

        // What they may put to the keeper, each as the order book reads it.
        let question = parley.putAnswer("question")
        XCTAssertEqual(question.line, "QUESTION \(prisoner.name)")
        XCTAssertEqual(question.command, .question(commander: prisoner.id))
        XCTAssertEqual(question.told, "You question \(prisoner.name) of \(title); what true thing they tell is the realm's to say.")
        XCTAssertTrue(question.isGiven)
        XCTAssertEqual(SpokenOrders.read(line: question.line, in: view, player: me)?.told, question.told, "As the order book tells it")
        let letGo = parley.putAnswer(" Let go ")
        XCTAssertEqual(letGo.line, "LET \(prisoner.name) GO")
        XCTAssertEqual(letGo.command, .release(commander: prisoner.id))
        XCTAssertEqual(letGo.told, "You let \(prisoner.name) of \(title) go home, for nothing.")
        XCTAssertNil(letGo.why)
        XCTAssertEqual(SpokenOrders.read(line: letGo.line, in: view, player: me)?.command, letGo.command)
        let ransomed = parley.putAnswer("ransom")
        XCTAssertNil(ransomed.command)
        XCTAssertEqual(ransomed.why, PrisonerParley.onlyTheseAnswers)
    }

    func testQuestionedTheTrueThingIsToldThemAndShownTheKeeper() throws {
        var (state, me, steward, prisoner) = try holding("a prisoner questioned in parley")
        let before = try XCTUnwrap(PrisonerParley(state: state.view(for: me), player: me, prisoner: prisoner.id))
        // The realm questions them, and says what they tell.
        _ = try state.perform(.question(commander: prisoner.id), as: me)
        let word = try XCTUnwrap(state.commander(prisoner.id)?.captive?.told?.last)
        XCTAssertTrue(state.knowledge(of: steward).contains(word))
        let after = try XCTUnwrap(PrisonerParley(state: state.view(for: me), player: me, prisoner: prisoner.id))
        XCTAssertEqual(after.news(since: before), ParleyNews(told: "Questioned, you told the keeper this true thing: \(word)",
                                                            shown: "\(prisoner.name) tells you: \(word)"))
        XCTAssertNil(after.news(since: after), "Nothing new")
        XCTAssertNil(before.news(since: after))
        XCTAssertTrue(after.facts.contains("The true things you have told the keeper of your House: \(word)"), "\(after.facts)")
        XCTAssertTrue(after.facts.contains("The keeper has questioned you this watch already, and may again when it turns."))
        XCTAssertEqual(after.summary, "Slips away in 17 watches. The last true thing they told: \(word)")
        XCTAssertEqual(after.putAnswer("question").why, RuleError.questionedThisWatch.description)
        XCTAssertTrue(after.putAnswer("let go").isGiven)

        // Let go, they are gone, and there is no parley with them.
        _ = try state.perform(.release(commander: prisoner.id), as: me)
        XCTAssertNil(PrisonerParley(state: state.view(for: me), player: me, prisoner: prisoner.id))
        XCTAssertNil(Parleys.parley(.prisoner(prisoner.id), in: state.view(for: me), player: me))
    }

    /// Held their full time but a watch, they slip away as it turns; of
    /// what they told, the latest few things, each once.
    func testTheirLastWatchAndWhatTheyToldLongAgo() throws {
        var (state, me, steward, prisoner) = try holding("a prisoner's last watch")
        let index = try XCTUnwrap(state.commanderIndex(prisoner.id))
        state.commanders![index].captive = Captivity(by: me, since: state.watch - GameState.captivityLasts + 1, questioned: 7,
                                                     told: ["One.", "Two.", "One.", "Three.", "Four.", "Five.", "Six."])
        let parley = try XCTUnwrap(PrisonerParley(state: state.view(for: me), player: me, prisoner: prisoner.id))
        XCTAssertTrue(parley.facts.contains("\(state.houses[me].title) took you prisoner \(GameState.captivityLasts - 1) watches ago, "
                                            + "when your company fell to theirs."), "\(parley.facts)")
        XCTAssertTrue(parley.facts.contains("You slip away as the watch turns, unless you are freed before."))
        XCTAssertTrue(parley.facts.contains("The true things you have told the keeper of your House: Two. Three. Four. Five. Six."),
                      "\(parley.facts)")
        XCTAssertEqual(parley.summary, "Slips away as the watch turns. The last true thing they told: Six.")
        // Their House fallen, no ransom is told and no standing between Houses.
        state.houses[steward].isEliminated = true
        let fallen = try XCTUnwrap(PrisonerParley(state: state, player: me, prisoner: prisoner.id))
        XCTAssertFalse(fallen.facts.contains { $0.hasPrefix("Your House may ransom you") })
        XCTAssertFalse(fallen.facts.contains { $0.hasPrefix("Your House and the keeper's stand") })
    }

    func testNoParleyWithAnotherHousesPrisonerOrAFreeCommander() throws {
        let (state, me, steward, prisoner) = try holding("no parley with these")
        let other = try XCTUnwrap(state.houses.first { $0.id != me && $0.id != steward }?.id)
        XCTAssertNil(PrisonerParley(state: state, player: other, prisoner: prisoner.id), "Held by another House")
        XCTAssertNil(PrisonerParley(state: state, player: 99, prisoner: prisoner.id))
        XCTAssertNil(PrisonerParley(state: state, player: me, prisoner: 99_999), "No such commander")
        let free = try XCTUnwrap(state.commanders(of: me).first)
        XCTAssertNil(PrisonerParley(state: state, player: me, prisoner: free.id), "One of the keeper's own, free")
    }

    /// The order book questions a prisoner the House holds and lets them go
    /// by name, and ransoms the House's own commander held by another; each
    /// refused in the realm's words where it can't be, and the briefing
    /// tells whom.
    func testTheOrderBookQuestionsLetsGoAndRansoms() throws {
        var (state, me, steward, prisoner) = try holding("prisoners in the order book")
        let title = state.houses[steward].title
        let view = state.view(for: me)
        let question = try XCTUnwrap(SpokenOrders.read(line: "question \(prisoner.name.lowercased())", in: view, player: me))
        XCTAssertEqual(question.command, .question(commander: prisoner.id))
        XCTAssertEqual(question.told, view.questionSaid(prisoner))
        XCTAssertNil(question.why)
        let letGo = try XCTUnwrap(SpokenOrders.read(line: "LET \(prisoner.name) GO HOME", in: view, player: me))
        XCTAssertEqual(letGo.command, .release(commander: prisoner.id))
        XCTAssertEqual(letGo.told, "You let \(prisoner.name) of \(title) go home, for nothing.")
        let nobody = try XCTUnwrap(SpokenOrders.read(line: "QUESTION Nobody at All", in: view, player: me))
        XCTAssertNil(nobody.command)
        XCTAssertEqual(nobody.why, "Your House holds no prisoner by the name Nobody at All.")
        XCTAssertNil(SpokenOrders.read(line: "LET \(prisoner.name)", in: view, player: me), "Not of the form")
        let briefing = SpokenOrders.briefing(for: view, player: me)
        XCTAssertTrue(briefing.contains("QUESTION <prisoner>") && briefing.contains("LET <prisoner> GO") && briefing.contains("RANSOM <commander>"))
        XCTAssertTrue(briefing.contains("Prisoners your House holds (QUESTION, LET GO): \(prisoner.name) of \(title), level \(prisoner.level), "
                                        + "who may be questioned this watch"), briefing)
        XCTAssertFalse(briefing.contains("held by other Houses"), "None of its own held")

        // Questioned once this watch, the next is refused in the realm's words.
        _ = try state.perform(.question(commander: prisoner.id), as: me)
        let again = try XCTUnwrap(SpokenOrders.read(line: "QUESTION \(prisoner.name)", in: state.view(for: me), player: me))
        XCTAssertEqual(again.why, RuleError.questionedThisWatch.description)
        XCTAssertFalse(SpokenOrders.briefing(for: state.view(for: me), player: me).contains("who may be questioned this watch"))

        // The steward's House ransoms its own commander held by the keeper,
        // as the order book reads it for whichever House gives it.
        let ransom = try XCTUnwrap(SpokenOrders.read(line: "RANSOM \(prisoner.name)", in: state, player: steward))
        XCTAssertEqual(ransom.command, .ransom(commander: prisoner.id))
        XCTAssertEqual(ransom.told, "Your House ransoms \(prisoner.name) from \(state.houses[me].title) for \(GameState.ransom(for: prisoner)).")
        XCTAssertTrue(SpokenOrders.briefing(for: state, player: steward)
            .contains("Your commanders held by other Houses (RANSOM): \(prisoner.name), held by \(state.houses[me].title), "
                      + "ransomed for \(GameState.ransom(for: prisoner))"))
        let none = try XCTUnwrap(SpokenOrders.read(line: "RANSOM \(prisoner.name)", in: view, player: me))
        XCTAssertNil(none.command)
        XCTAssertEqual(none.why, "None of your House's commanders by the name \(prisoner.name) is held prisoner.")
    }
}
