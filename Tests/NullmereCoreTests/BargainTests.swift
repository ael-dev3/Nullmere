import Foundation
import XCTest
@testable import NullmereCore

/// Bargaining with a steward's demand of tribute: half offered, a tenth of
/// the keeper's stores, taken where the steward's House is less than half
/// again as strong as the keeper's (a cunning one, a third again) and
/// keeping the peace half the respite; held to otherwise, the envoy waiting
/// with its demand whole, never bargained with again. Told to the keeper,
/// remembered by the envoys, read from the order book and put forward in
/// counsel; refused in the realm's words.
final class BargainTests: XCTestCase {
    /// A realm whose steward of House 1 demands tribute of the keeper, each
    /// House's companies alike and so many of them.
    private func demanded(steward companies: Int, keeper own: Int, temper: Temperament = .ambitious) throws
        -> (state: GameState, me: Int, rival: Int, envoy: Envoy) {
        var state = GameState(settings: GameSettings(seedText: "bargained tribute", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player, rival = 1
        state.houses[rival].temperament = temper
        state.units.removeAll { $0.owner == rival || $0.owner == me }
        let mine = try XCTUnwrap(state.seat(of: me)), theirs = try XCTUnwrap(state.seat(of: rival))
        for _ in 0..<own { XCTAssertNotNil(state.placeUnit(.spear, for: me, near: mine.position)) }
        for _ in 0..<companies { XCTAssertNotNil(state.placeUnit(.spear, for: rival, near: theirs.position)) }
        _ = try state.propose(.tribute, from: rival, to: me)
        let envoy = try XCTUnwrap(state.envoys.first { $0.from == rival && $0.to == me })
        return (state, me, rival, envoy)
    }

    func testHalfIsTakenWhereTheStewardIsLessThanHalfAgainAsStrong() throws {
        var (state, me, rival, envoy) = try demanded(steward: 4, keeper: 3)
        XCTAssertLessThan(state.strength(of: rival) * 2, state.strength(of: me) * 3, "Less than half again as strong")
        XCTAssertNil(state.bargainRefusal(envoy.id, as: me))
        let half = state.halfTribute(from: me)
        XCTAssertEqual(half, state.houses[me].stock.share(1, of: 10))
        XCTAssertNotEqual(half, Stock())
        XCTAssertEqual(state.bargainSaid(for: me), "Offer half: \(half)")
        let mine = state.houses[me].stock, theirs = state.houses[rival].stock

        let events = try state.perform(.bargain(envoy: envoy.id), as: me)
        XCTAssertEqual(events, [.tributeBargained(from: rival, to: me, paid: half)])
        XCTAssertEqual(state.houses[me].stock + half, mine)
        XCTAssertEqual(state.houses[rival].stock, theirs + half)
        XCTAssertFalse(state.envoys.contains { $0.id == envoy.id }, "Its envoy goes home")
        XCTAssertEqual(state.stance(me, rival), .peace)
        XCTAssertTrue(state.chronicle.contains { $0.kind == .tribute && $0.text.contains("half the tribute it demanded") })
        let title = state.houses[rival].title
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "\(title) takes half its demand: \(half). It keeps the peace \(GameState.halfTributeRespite) watches.")
        XCTAssertNil(state.tidings(of: events[0], for: 2))
        XCTAssertEqual(state.events(events, heardBy: 2), [], "Between the two Houses alone")
        XCTAssertEqual(state.events(events, heardBy: rival), events)

        // The peace kept half the respite: no demand again until it runs out.
        XCTAssertTrue(state.paidTributeLately(rival, me))
        var later = state
        later.watch += GameState.halfTributeRespite - 1
        XCTAssertTrue(later.paidTributeLately(rival, me))
        later.watch += 1
        XCTAssertFalse(later.paidTributeLately(rival, me), "Half the tribute, half the respite")

        // Remembered as half paid, never as turned away.
        let answered = try XCTUnwrap(state.lastAnswer(from: rival, to: me))
        XCTAssertEqual(answered.answer, .halved)
        XCTAssertEqual(answered.turnedAway, 0)
        XCTAssertEqual(answered.said(by: "you"), "you paid half of it")
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
    }

    func testAStewardFarTheStrongerHoldsToTheWhole() throws {
        var (state, me, rival, envoy) = try demanded(steward: 5, keeper: 3)
        XCTAssertGreaterThanOrEqual(state.strength(of: rival) * 2, state.strength(of: me) * 3, "Half again as strong, or more")
        let stores = state.houses[me].stock
        let events = try state.perform(.bargain(envoy: envoy.id), as: me)
        XCTAssertEqual(events, [.tributeBargained(from: rival, to: me, paid: nil)])
        XCTAssertEqual(state.houses[me].stock, stores, "Nothing paid")
        let waiting = try XCTUnwrap(state.envoys.first { $0.id == envoy.id }, "Its envoy waits on, its demand whole")
        XCTAssertEqual(waiting.bargained, true)
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "\(state.houses[rival].title) holds to its demand: a fifth of your stores, or it marches.")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.tone, .bad)
        // Never bargained with again, and kept so in saves.
        XCTAssertEqual(state.bargainRefusal(envoy.id, as: me), .bargainedAlready)
        XCTAssertEqual(RuleError.bargainedAlready.description, "Their envoy holds to the whole demand: pay it, or refuse.")
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        XCTAssertNil(state.lastAnswer(from: rival, to: me), "Nothing answered yet")
        // The whole may still be paid.
        let whole = state.tribute(from: me)
        _ = try state.perform(.answer(envoy: envoy.id, accept: true), as: me)
        XCTAssertEqual(state.houses[me].stock + whole, stores)
        XCTAssertEqual(state.lastAnswer(from: rival, to: me)?.answer, .accepted)
    }

    func testACunningStewardTakesHalfOnlyWithinAThird() throws {
        // Seven companies against five: less than half again, but more than a third again.
        let (ambitious, me, rival, asked) = try demanded(steward: 7, keeper: 5)
        XCTAssertLessThan(ambitious.strength(of: rival) * 2, ambitious.strength(of: me) * 3)
        XCTAssertGreaterThanOrEqual(ambitious.strength(of: rival) * 3, ambitious.strength(of: me) * 4)
        var taken = ambitious
        XCTAssertEqual(try taken.perform(.bargain(envoy: asked.id), as: me).first,
                       .tributeBargained(from: rival, to: me, paid: ambitious.halfTribute(from: me)))
        var (cunning, _, _, envoy) = try demanded(steward: 7, keeper: 5, temper: .cunning)
        XCTAssertEqual(try cunning.perform(.bargain(envoy: envoy.id), as: me), [.tributeBargained(from: rival, to: me, paid: nil)])
        // Five against four is within a third again, and the cunning takes it.
        var (near, _, _, nearEnvoy) = try demanded(steward: 5, keeper: 4, temper: .cunning)
        XCTAssertLessThan(near.strength(of: rival) * 3, near.strength(of: me) * 4)
        let half = near.halfTribute(from: me)
        XCTAssertEqual(try near.perform(.bargain(envoy: nearEnvoy.id), as: me).first, .tributeBargained(from: rival, to: me, paid: half))
    }

    func testOnlyAStewardsStandingDemandOfTributeIsBargained() throws {
        let (state, me, rival, envoy) = try demanded(steward: 4, keeper: 3)
        func refused(_ change: (inout GameState) -> Void, envoy id: Int? = nil, as house: Int? = nil) -> RuleError? {
            var changed = state
            change(&changed)
            return changed.refusal(of: .bargain(envoy: id ?? envoy.id), as: house ?? me)
        }
        XCTAssertNil(refused { _ in })
        XCTAssertEqual(refused({ _ in }, envoy: 9_999), .unknownEnvoy)
        XCTAssertEqual(refused({ _ in }, as: 2), .unknownEnvoy, "Another House's envoy")
        XCTAssertEqual(refused { $0.envoys = [Envoy(id: envoy.id, from: rival, to: me, proposal: .pact, arrived: $0.watch)] },
                       .notBargained)
        XCTAssertEqual(refused { $0.houses[rival].isPlayer = true }, .notBargained, "A keeper's demand is bargained in words")
        XCTAssertEqual(refused { $0.setStance(.war, between: me, and: rival, by: rival) }, .notApplicable)
        XCTAssertEqual(RuleError.notBargained.description, "Only a steward's demand of tribute is bargained over.")
    }

    func testEnvoysAreAnsweredFromTheOrderBook() throws {
        let (state, me, rival, envoy) = try demanded(steward: 4, keeper: 3)
        let title = state.houses[rival].title
        let read = SpokenOrders.read("ACCEPT THE ENVOY OF \(title)\nREFUSE THE ENVOY OF \(title)\nOFFER HALF THE TRIBUTE TO \(title)",
                                     in: state, player: me)
        XCTAssertEqual(read.map(\.command), [.answer(envoy: envoy.id, accept: true), .answer(envoy: envoy.id, accept: false),
                                             .bargain(envoy: envoy.id)])
        XCTAssertEqual(read.map(\.why), [nil, nil, nil])
        XCTAssertEqual(read[0].told, "Your House pays \(title) its tribute: \(state.tribute(from: me)).")
        XCTAssertEqual(read[1].told, "Your House refuses \(title) its tribute, and it marches on you.")
        XCTAssertEqual(read[2].told, "Your House offers \(title) half its demand: \(state.halfTribute(from: me)), "
                       + "for \(GameState.halfTributeRespite) watches' peace.")
        XCTAssertEqual(SpokenOrders.read("OFFER HALF TO \(title)", in: state, player: me).first?.command, .bargain(envoy: envoy.id))
        let other = state.houses[2].title
        XCTAssertEqual(SpokenOrders.read("ACCEPT THE ENVOY OF \(other)", in: state, player: me).first?.why,
                       "No envoy of \(other) waits on your answer.")
        XCTAssertEqual(SpokenOrders.read("REFUSE THE ENVOY OF House Nobody", in: state, player: me).first?.why,
                       "No House goes by the name House Nobody.")
        // The briefing names the envoy, its demand, and what half would pay.
        let briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains("Envoys waiting on your answer (ACCEPT or REFUSE THE ENVOY OF <house>): \(state.terms(of: envoy, for: me))"),
                      briefing)
        XCTAssertTrue(briefing.contains(" Half may be offered (OFFER HALF THE TRIBUTE TO \(title)): \(state.halfTribute(from: me))."), briefing)
        XCTAssertTrue(SpokenOrders.forms.contains("OFFER HALF THE TRIBUTE TO <house>"))
        // Another kind of offer is taken or turned away in its own words.
        var offered = state
        offered.envoys = [Envoy(id: envoy.id, from: rival, to: me, proposal: .pact, arrived: state.watch)]
        let pact = SpokenOrders.read("ACCEPT THE ENVOY OF \(title)\nREFUSE THE ENVOY OF \(title)\nOFFER HALF THE TRIBUTE TO \(title)",
                                     in: offered, player: me)
        XCTAssertEqual(pact.map(\.told), ["Your House takes \(title)'s offer of a pact.", "Your House turns away \(title)'s offer of a pact.",
                                          pact[2].told])
        XCTAssertEqual(pact[2].why, RuleError.notBargained.description)
        XCTAssertFalse(SpokenOrders.briefing(for: offered, player: me).contains("Half may be offered"))
    }

    func testACommanderKnowsTheEnvoysAndMayPutAnAnswerForward() throws {
        var (state, me, rival, envoy) = try demanded(steward: 5, keeper: 3)
        let title = state.houses[rival].title
        let id = try XCTUnwrap(state.commanders(of: me).first).id
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        XCTAssertTrue(counsel.affairs.contains("An envoy of \(title) waits on your keeper's answer: \(state.terms(of: envoy, for: me)) "
                                               + "\(title)'s companies are reputed \(GameState.counted(state.strength(of: rival))) strong "
                                               + "to your House's \(GameState.counted(state.strength(of: me)))."), counsel.affairs)
        XCTAssertTrue(counsel.affairs.contains("Half its demand may be offered instead, \(state.halfTribute(from: me)). \(GameState.bargainRule)"),
                      counsel.affairs)
        XCTAssertTrue(counsel.instructions.contains("in answer to an envoy waiting on your House"))
        let bargain = counsel.proposeAnswer("bargain", house: title)
        XCTAssertEqual(bargain.command, .bargain(envoy: envoy.id))
        XCTAssertNil(bargain.why)
        XCTAssertEqual(bargain.line, "OFFER HALF THE TRIBUTE TO \(title)")
        XCTAssertEqual(counsel.proposeAnswer("pay", house: title).command, .answer(envoy: envoy.id, accept: true))
        XCTAssertEqual(counsel.proposeAnswer("Refuse", house: " \(title) ").command, .answer(envoy: envoy.id, accept: false))
        XCTAssertEqual(counsel.proposeAnswer("dance", house: title).why, CommanderCounsel.onlyTheseForEnvoys)
        XCTAssertEqual(counsel.proposeAnswer("accept", house: "").why, "An answer to an envoy wants the House it comes from.")
        XCTAssertEqual(CommanderCounsel.envoyActions, ["accept", "refuse", "bargain"])

        // Held to the whole, the commander knows it and bargains no more.
        _ = try state.perform(.bargain(envoy: envoy.id), as: me)
        let after = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: id))
        XCTAssertTrue(after.affairs.contains("Offered half, its steward held to the whole."), after.affairs)
        XCTAssertEqual(after.proposeAnswer("bargain", house: title).why, RuleError.bargainedAlready.description)
        XCTAssertFalse(SpokenOrders.briefing(for: state, player: me).contains("Half may be offered"))
    }
}
