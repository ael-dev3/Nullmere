import Foundation
import XCTest
@testable import NullmereCore

/// Petitions at the gate: the folk of a keeper's hold bring a plea grounded
/// in how the hold stands, the most pressing first (a broken ward, a
/// company hurt at its gates, hands for its work, a feast at the full
/// moon); granted, the House pays what they ask and the boon is done;
/// turned away, by the keeper or by silence, what the hold has under way
/// is set back a watch; a plea whose need passed is withdrawn owing
/// nothing. Keepers' Houses alone, one plea at a time, the next some
/// watches after; their own view alone carries it, and their devices
/// voice it from its facts.
final class PetitionTests: XCTestCase {
    /// A small lake at the first watch pleas may come, its keeper's seat
    /// with nothing under way.
    private func world(_ seed: String = "petitions") throws -> (GameState, me: Int, seat: Hold, at: Int) {
        var world = Scene.world(seed)
        world.watch = Petition.from
        let me = world.player
        let seat = try XCTUnwrap(world.holds(of: me).first { $0.isSeat })
        let index = try XCTUnwrap(world.holdIndex(seat.id))
        world.holds[index].project = nil
        world.holds[index].training = nil
        world.houses[me].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 50)
        return (world, me, try XCTUnwrap(world.hold(seat.id)), index)
    }

    func testABrokenWardBringsTheMasonsAndGrantingMendsItWhole() throws {
        var (world, me, seat, at) = try world()
        world.holds[at].ward = 1
        let events = world.bringPetitions()
        let petition = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(events, [.petitionBrought(petition)])
        XCTAssertEqual(petition.plea, .mend)
        XCTAssertEqual(petition.hold, seat.id)
        XCTAssertEqual(petition.price, Stock(stone: 10 + 10 * seat.level(.walls)), "Priced by its walls")
        XCTAssertTrue(Petition.names.contains(petition.name))
        XCTAssertEqual(world.petitioner(of: petition), "\(petition.name), a mason of \(seat.name)")
        XCTAssertEqual(world.asked(by: petition),
                       "\(seat.name)'s ward is broken (1 of \(seat.maximumWard)). For \(petition.price), its masons will mend it whole.")
        XCTAssertEqual(world.tidings(of: events[0], for: me)?.text,
                       "\(petition.name), a mason of \(seat.name) comes to your gate with a plea. \(world.asked(by: petition))")
        let foe = (me + 1) % world.houses.count
        XCTAssertNil(world.petition(of: foe), "A steward's House is brought none")
        XCTAssertNil(world.tidings(of: events[0], for: foe), "Its folk speak to their own keeper alone")

        let stone = world.houses[me].stock.stone
        let granted = try world.perform(.answerPetition(petition.id, grant: true), as: me)
        XCTAssertEqual(granted, [.petitionAnswered(petition, granted: true, silently: false)])
        XCTAssertEqual(world.hold(seat.id)?.ward, world.hold(seat.id)?.maximumWard)
        XCTAssertEqual(world.houses[me].stock.stone, stone - petition.price.stone)
        XCTAssertNil(world.petitions)
        XCTAssertEqual(world.tidings(of: granted[0], for: me)?.text, "You grant the plea of \(petition.name) of \(seat.name): its masons mend the ward whole.")

        // The next comes only so many watches after the last.
        world.holds[at].ward = 1
        world.watch += 1
        XCTAssertTrue(world.bringPetitions().isEmpty)
        world.watch = Petition.from + Petition.every
        XCTAssertEqual(world.bringPetitions().count, 1)
        XCTAssertEqual(world.bringPetitions().count, 0, "One plea at a time")
        XCTAssertTrue(world.problems().isEmpty, "\(world.problems())")
    }

    func testTheMostPressingPleaComesFirst() throws {
        var (world, me, seat, at) = try world("pleas in order")
        // Nothing amiss and the moon not full: none.
        world.watch = Petition.from == 0 ? 1 : Petition.from
        XCTAssertNil(world.plea(for: me))
        // At the full moon, the seat's feast.
        var full = world
        full.watch = GameState.lunarMonth * 2
        XCTAssertEqual(full.plea(for: me)?.plea, .feast)
        XCTAssertEqual(full.plea(for: me)?.price, Stock(grain: 60))
        // A work under way: hands.
        world.holds[at].project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 4)
        XCTAssertEqual(world.plea(for: me)?.plea, .hands)
        XCTAssertEqual(world.plea(for: me)?.price, Stock(grain: 40))
        // A company hurt at its gates comes before it.
        let company = try XCTUnwrap(world.units(of: me).first { $0.position == seat.position } ?? world.units(of: me).first)
        let unit = try XCTUnwrap(world.unitIndex(company.id))
        world.units[unit].position = seat.position
        world.units[unit].health = Petition.hurt - 1
        XCTAssertEqual(world.plea(for: me)?.plea, .tend)
        XCTAssertEqual(world.plea(for: me)?.unit, company.id)
        // And a broken ward before all.
        world.holds[at].ward = 0
        XCTAssertEqual(world.plea(for: me)?.plea, .mend)
        // Tended, the company is mended by a draught's worth.
        world.holds[at].ward = world.holds[at].maximumWard
        _ = world.bringPetitions()
        let petition = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(petition.plea, .tend)
        XCTAssertTrue(world.asked(by: petition).contains("lies hurt at \(seat.name)'s gates, at \(Petition.hurt - 1) of its strength,"),
                      world.asked(by: petition))
        try world.perform(.answerPetition(petition.id, grant: true), as: me)
        XCTAssertEqual(world.unit(company.id)?.health, Petition.hurt - 1 + GameState.draughtMending)
    }

    func testTurnedAwayOrUnansweredTheHoldIsSetBackAndAPassedNeedIsWithdrawn() throws {
        var (world, me, seat, at) = try world("turned away")
        world.holds[at].project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 4)
        _ = world.bringPetitions()
        let hands = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(hands.plea, .hands)
        // Granted, a watch nearer.
        var granted = world
        try granted.perform(.answerPetition(hands.id, grant: true), as: me)
        XCTAssertEqual(granted.hold(seat.id)?.project?.watchesLeft, 3)
        XCTAssertEqual(granted.houses[me].stock.grain, 500 - 40)
        // Turned away, a watch further.
        var refused = world
        let turned = try refused.perform(.answerPetition(hands.id, grant: false), as: me)
        XCTAssertEqual(turned, [.petitionAnswered(hands, granted: false, silently: false)])
        XCTAssertEqual(refused.hold(seat.id)?.project?.watchesLeft, 5)
        XCTAssertEqual(refused.houses[me].stock, world.houses[me].stock, "Nothing paid")
        XCTAssertEqual(refused.tidings(of: turned[0], for: me)?.tone, .bad)
        // Left unanswered too long, turned away by silence.
        var silent = world
        silent.watch += Petition.patience
        let lapsed = silent.bringPetitions()
        XCTAssertEqual(lapsed.first, .petitionAnswered(hands, granted: false, silently: true))
        XCTAssertEqual(silent.hold(seat.id)?.project?.watchesLeft, 5)
        XCTAssertTrue(silent.tidings(of: lapsed[0], for: me)?.text.hasPrefix("No answer came to the plea of \(hands.name)") ?? false)
        // Its need passed, withdrawn, owing nothing.
        var passed = world
        passed.holds[at].project = nil
        passed.watch += 1
        XCTAssertEqual(passed.bringPetitions(), [.petitionWithdrawn(hands)])
        XCTAssertNil(passed.petitions)
        XCTAssertEqual(passed.tidings(of: .petitionWithdrawn(hands), for: me)?.text,
                       "\(hands.name) of \(seat.name) withdraws the plea: its need has passed.")
        // Its folk speak to their own keeper alone: no other House hears a word of it.
        let all: [GameEvent] = [.petitionBrought(hands), .petitionAnswered(hands, granted: false, silently: false), .petitionWithdrawn(hands)]
        XCTAssertEqual(world.events(all, heardBy: me), all)
        XCTAssertTrue(world.events(all, heardBy: (me + 1) % world.houses.count).isEmpty)
    }

    func testOnlyAKeeperAnswersTheirOwnPleaAndPaysForIt() throws {
        var (world, me, _, at) = try world("refusals")
        world.holds[at].ward = 1
        _ = world.bringPetitions()
        let petition = try XCTUnwrap(world.petition(of: me))
        let foe = (me + 1) % world.houses.count
        XCTAssertEqual(world.petitionRefusal(petition.id, grant: true, as: foe), .notAKeeper)
        XCTAssertEqual(world.petitionRefusal(petition.id + 999, grant: true, as: me), .notApplicable)
        var poor = world
        poor.houses[me].stock = .zero
        XCTAssertEqual(poor.petitionRefusal(petition.id, grant: true, as: me), .shortOf(petition.price))
        XCTAssertNil(poor.petitionRefusal(petition.id, grant: false, as: me), "Turning away costs nothing to say")
        var mended = world
        mended.holds[at].ward = mended.holds[at].maximumWard
        XCTAssertEqual(mended.petitionRefusal(petition.id, grant: true, as: me), .notApplicable, "Its need passed")
        XCTAssertThrowsError(try world.perform(.answerPetition(petition.id, grant: true), as: foe))
    }

    func testTheFeastGivesAnHourglassAndTheCaretakerGrantsWhatTheHouseCanWellAfford() throws {
        var (world, me, seat, _) = try world("feast")
        world.watch = GameState.lunarMonth * 2
        _ = world.bringPetitions()
        let feast = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(feast.plea, .feast)
        XCTAssertEqual(feast.hold, seat.id)
        XCTAssertEqual(feast.price, Stock(grain: 60))
        var granted = world
        let events = try granted.perform(.answerPetition(feast.id, grant: true), as: me)
        XCTAssertEqual(granted.items(.hourglass, of: me), world.items(.hourglass, of: me) + 1)
        XCTAssertTrue(events.contains(.petitionAnswered(feast, granted: true, silently: false)))
        // The caretaker grants it while the keeper is away, with stores to spare.
        var kept = world
        _ = kept.stewardTurn(for: me, caretaking: true)
        XCTAssertNil(kept.petition(of: me))
        XCTAssertEqual(kept.items(.hourglass, of: me), world.items(.hourglass, of: me) + 1)
        // Not with too little.
        var lean = world
        lean.houses[me].stock = Stock(grain: 100)
        XCTAssertNil(RivalMind(house: me, caretaking: true).hearThePetition(in: &lean).first)
        XCTAssertNotNil(lean.petition(of: me))
    }

    func testThePleaGoesToItsKeepersViewAloneAndIsVoicedFromItsFacts() throws {
        var (world, me, seat, at) = try world("voiced plea")
        world.holds[at].ward = 1
        _ = world.bringPetitions()
        let petition = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(world.view(for: me).petitions, [petition])
        XCTAssertNil(world.view(for: (me + 1) % world.houses.count).petitions)
        XCTAssertNil(world.view(for: me).petitioned)
        let moment = try XCTUnwrap(world.voicedMoments(for: me).first { $0.key == "petition-\(petition.id)" }?.moment)
        XCTAssertEqual(moment.task, Voicing.petitionTask)
        XCTAssertEqual(moment.facts, ["The petitioner is \(petition.name), a mason of \(seat.name), a hold of \(world.houses[me].title).",
                                      world.asked(by: petition), GameState.turnedAwaySaid])
        // Kept through a save as through the realm's parts.
        let saved = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(world))
        XCTAssertEqual(saved.petitions, world.petitions)
        XCTAssertEqual(saved.petitioned, world.petitioned)
    }

    /// Pleas come as a realm's watch turns, its keepers there to hear
    /// them or their caretakers; a world played wholly by stewards,
    /// turned outside a realm, has no one to hear them, and none come.
    func testAPleaComesAsARealmsWatchTurnsAndNotToAWorldOfStewardsAlone() throws {
        var realm = RealmState(name: "The Nullmere", seed: "realm pleas", seats: 3, radius: 16, watchLength: 60, now: 0)
        let house = try XCTUnwrap(try realm.arrive("ama", name: "Ama", now: 0).house)
        for _ in 0..<40 where realm.world.petition(of: house) == nil {
            // The seat's ward broken each watch, so a plea comes once they may.
            let seat = try XCTUnwrap(realm.world.seat(of: house))
            realm.world.holds[try XCTUnwrap(realm.world.holdIndex(seat.id))].ward = 1
            realm.watchBegan = -1e13
            _ = realm.tick(now: 1e12)
        }
        let petition = try XCTUnwrap(realm.world.petition(of: house))
        XCTAssertEqual(petition.plea, .mend)
        XCTAssertEqual(petition.arrived, Petition.from)
        XCTAssertEqual(realm.world.view(for: house).petitions, [petition])

        var world = Scene.world("stewards alone")
        let seat = try XCTUnwrap(world.seat(of: world.player))
        for _ in 0..<(Petition.from + 2) {
            world.holds[try XCTUnwrap(world.holdIndex(seat.id))].ward = 1
            _ = world.stewardTurn(for: world.player)
            _ = world.endWatch()
        }
        XCTAssertNil(world.petitions, "No realm, no one to hear them")
    }
}
