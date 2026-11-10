import Foundation
import XCTest
@testable import NullmereCore

/// A parley with one of the keeper's folk come to the gate with a plea: who
/// they are told they are, what they know (the plea as the realm voices it,
/// how long they wait, whether the House can grant it), granting or turning
/// it away put to the keeper as the order book weighs it; and the order book
/// itself granting or turning away the plea at the gate.
final class PetitionParleyTests: XCTestCase {
    /// A keeper whose seat's ward lies broken, its mason Osric at the gate.
    private func pleading(_ seed: String) throws -> (state: GameState, me: Int, seat: Hold, petition: Petition) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 3, radius: 16, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].ward = 1
        state.houses[me].stock = Stock(grain: 100, timber: 100, stone: 100, moonsalt: 10)
        let petition = Petition(id: state.takeID(), house: me, hold: seat.id, plea: .mend, arrived: state.watch, name: "Osric",
                                price: Stock(stone: 20))
        state.petitions = [petition]
        return (state, me, try XCTUnwrap(state.hold(seat.id)), petition)
    }

    func testAPetitionerIsParleyedWith() throws {
        let (state, me, seat, petition) = try pleading("a plea's parley")
        let view = state.view(for: me)
        let parley = try XCTUnwrap(PetitionParley(state: view, player: me, petition: petition.id))
        XCTAssertEqual(parley.subject, .petition(petition.id))
        XCTAssertEqual(Parleys.parley(.petition(petition.id), in: view, player: me)?.subject, .petition(petition.id))
        XCTAssertEqual(parley.speaker, "Osric")
        XCTAssertEqual(parley.named, "Osric, a mason of \(seat.name)")
        XCTAssertEqual(parley.addressed, "the petitioner")
        XCTAssertEqual(parley.spokenFor, "a petitioner")
        XCTAssertEqual(parley.subtitle, "A mason of \(seat.name) · Waits 3 watches")
        XCTAssertEqual(parley.summary, view.asked(by: petition))
        XCTAssertEqual(parley.whenPut, "The keeper decides, and the realm says what comes of it.")
        XCTAssertEqual(parley.opening, "Osric, a mason of \(seat.name), waits at the gate. Speak with them as you would: they keep to what "
                       + "their folk ask, and put your answer to you to give.")
        let told = parley.instructions
        XCTAssertTrue(told.hasPrefix("You are Osric, a mason of \(seat.name), one of the folk of \(state.houses[me].title), come to the gate"), told)
        XCTAssertTrue(told.contains("When the keeper says they would grant your plea, or turn it away, put it to them with putPleaToKeeper"), told)
        XCTAssertTrue(told.contains("Never invent numbers, places, names, promises or events"))

        // What they know: the plea as the realm voices it, and how long they wait.
        let voiced = view.voiced(petition).facts
        XCTAssertEqual(Array(parley.facts.prefix(voiced.count)), voiced)
        XCTAssertTrue(parley.facts.contains("You wait 3 watches more for the keeper's answer before silence turns you away."), "\(parley.facts)")
        XCTAssertFalse(parley.facts.contains { $0.hasPrefix("The keeper can't grant it now") })
        XCTAssertEqual(parley.briefing, Parleys.briefing(parley.facts))

        // Granting or turning away, each as the order book reads it.
        let grant = parley.putAnswer("grant")
        XCTAssertEqual(grant.line, "GRANT THE PLEA")
        XCTAssertEqual(grant.command, .answerPetition(petition.id, grant: true))
        XCTAssertEqual(grant.told, "Your House grants Osric's plea, for \(petition.price).")
        XCTAssertTrue(grant.isGiven)
        XCTAssertEqual(SpokenOrders.read(line: grant.line, in: view, player: me)?.command, grant.command)
        let turned = parley.putAnswer(" Turn away ")
        XCTAssertEqual(turned.line, "TURN AWAY THE PLEA")
        XCTAssertEqual(turned.command, .answerPetition(petition.id, grant: false))
        XCTAssertEqual(turned.told, "Your House turns Osric's plea away, and the folk of \(seat.name) go back to their work grudging.")
        XCTAssertEqual(SpokenOrders.read(line: turned.line, in: view, player: me)?.told, turned.told, "As the order book tells it")
        XCTAssertEqual(parley.putAnswer("ask for more").why, PetitionParley.onlyTheseAnswers)
        XCTAssertNil(parley.news(since: parley), "A plea changes only by being answered")
    }

    /// Short of what the folk ask, the plea can't be granted, and the
    /// petitioner knows it; its need passed, they know that; answered, or
    /// another House's, there is no parley.
    func testShortOfStoresOrTheNeedPassedOrAnswered() throws {
        var (state, me, seat, petition) = try pleading("a plea short")
        state.houses[me].stock = Stock()
        let short = try XCTUnwrap(PetitionParley(state: state, player: me, petition: petition.id))
        XCTAssertTrue(short.facts.contains { $0.hasPrefix("The keeper can't grant it now: ") }, "\(short.facts)")
        XCTAssertNotNil(short.putAnswer("grant").why)
        XCTAssertTrue(short.putAnswer("turn away").isGiven)
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].ward = seat.maximumWard
        let mended = try XCTUnwrap(PetitionParley(state: state, player: me, petition: petition.id))
        XCTAssertTrue(mended.facts.contains("Your folk's need has passed."), "\(mended.facts)")
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        XCTAssertNil(PetitionParley(state: state, player: other, petition: petition.id), "Another House's to answer")
        XCTAssertNil(PetitionParley(state: state, player: me, petition: petition.id + 1_000), "No such plea")
        _ = try state.perform(.answerPetition(petition.id, grant: false), as: me)
        XCTAssertNil(PetitionParley(state: state, player: me, petition: petition.id), "Answered")
        XCTAssertNil(Parleys.parley(.petition(petition.id), in: state, player: me))
    }

    /// The order book grants or turns away the plea at the gate, told whose
    /// it is in the briefing; with none waiting, it says so.
    func testTheOrderBookGrantsOrTurnsAwayThePlea() throws {
        let (state, me, seat, petition) = try pleading("a plea in the order book")
        let view = state.view(for: me)
        let granted = try XCTUnwrap(SpokenOrders.read(line: "grant the plea", in: view, player: me))
        XCTAssertEqual(granted.command, .answerPetition(petition.id, grant: true))
        XCTAssertEqual(granted.told, view.grantSaid(petition))
        XCTAssertNil(granted.why)
        XCTAssertEqual(SpokenOrders.read(line: "TURN AWAY THE PLEA", in: view, player: me)?.command, .answerPetition(petition.id, grant: false))
        let briefing = SpokenOrders.briefing(for: view, player: me)
        XCTAssertTrue(briefing.contains("GRANT THE PLEA") && briefing.contains("TURN AWAY THE PLEA"))
        XCTAssertTrue(briefing.contains("A plea at the gate (GRANT THE PLEA or TURN AWAY THE PLEA): Osric, a mason of \(seat.name): "
                                        + view.asked(by: petition)), briefing)
        var none = state
        none.petitions = nil
        let nothing = try XCTUnwrap(SpokenOrders.read(line: "TURN AWAY THE PLEA", in: none.view(for: me), player: me))
        XCTAssertNil(nothing.command)
        XCTAssertEqual(nothing.why, "No plea waits at your gate.")
        XCTAssertFalse(SpokenOrders.briefing(for: none.view(for: me), player: me).contains("A plea at the gate"))
        XCTAssertNil(SpokenOrders.read(line: "GRANT THE WISH", in: view, player: me), "Not of the form")
    }
}
