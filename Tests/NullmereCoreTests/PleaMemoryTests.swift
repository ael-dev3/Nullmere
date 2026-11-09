import Foundation
import XCTest
@testable import NullmereCore

/// A hold's folk remember their last plea at the gate: who brought it,
/// what it asked, and whether it was granted, turned away or left waiting
/// until they went home; the next petitioner from the hold comes knowing
/// it and the keeper is told it on the card; only the House the hold is
/// the folk of knows it; a hold taken by another House starts afresh.
final class PleaMemoryTests: XCTestCase {
    /// A small lake at the first watch pleas may come, the keeper's seat
    /// with nothing under way, its ward broken and its stores full.
    private func world() throws -> (GameState, me: Int, seat: Hold) {
        var world = Scene.world("the folk remember")
        world.watch = Petition.from
        let me = world.player
        let seat = try XCTUnwrap(world.holds(of: me).first { $0.isSeat })
        let index = try XCTUnwrap(world.holdIndex(seat.id))
        world.holds[index].project = nil
        world.holds[index].training = nil
        world.holds[index].ward = 1
        world.houses[me].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 50)
        return (world, me, try XCTUnwrap(world.hold(seat.id)))
    }

    func testAHoldsFolkRememberTheirLastPleaAndTheNextComesKnowingIt() throws {
        var (world, me, seat) = try world()
        _ = world.bringPetitions()
        let first = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(first.plea, .mend)
        XCTAssertNil(world.rememberedPlea(first), "Nothing to remember before the first")
        XCTAssertTrue(world.rememberedPleaFacts(first).isEmpty)
        // Turned away, and the realm keeps it.
        _ = try world.perform(.answerPetition(first.id, grant: false), as: me)
        let refused = world.watch
        XCTAssertEqual(world.lastPlea(of: seat.id),
                       PleaAnswer(hold: seat.id, house: me, plea: .mend, name: first.name, watch: refused, granted: false, silently: false, turnedAway: 1))
        // The next from the hold comes knowing it.
        world.watch += Petition.every
        _ = world.bringPetitions()
        let second = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(second.hold, seat.id)
        XCTAssertEqual(world.rememberedPlea(second),
                       "\(seat.name)'s folk last came to your gate in watch \(refused): \(first.name), a mason, asked to have its ward mended, "
                       + "and you turned them away.")
        let facts = world.voiced(second).facts
        XCTAssertTrue(facts.contains("When \(seat.name)'s folk last came to the keeper's gate, in watch \(refused), \(first.name), a mason, "
                                     + "asked to have its ward mended, and the keeper turned them away."), "\(facts)")
        XCTAssertFalse(facts.contains { $0.contains("pleas this age") }, "Once is not yet a habit")
        // Left waiting until they go home: turned away all the same.
        world.watch += Petition.patience
        _ = world.bringPetitions()
        XCTAssertNil(world.petition(of: me), "Gone home unanswered")
        let lapsed = world.watch
        XCTAssertEqual(world.lastPlea(of: seat.id),
                       PleaAnswer(hold: seat.id, house: me, plea: .mend, name: second.name, watch: lapsed, granted: false, silently: true, turnedAway: 2))
        // The third is granted: remembered so, what was turned away before still counted.
        world.watch += Petition.every
        _ = world.bringPetitions()
        let third = try XCTUnwrap(world.petition(of: me))
        XCTAssertEqual(world.rememberedPlea(third),
                       "\(seat.name)'s folk last came to your gate in watch \(lapsed): \(second.name), a mason, asked to have its ward mended, "
                       + "and you sent no answer. You have turned away 2 of their pleas this age.")
        XCTAssertTrue(world.voiced(third).facts.contains("The keeper has turned away 2 of \(seat.name)'s pleas this age."))
        _ = try world.perform(.answerPetition(third.id, grant: true), as: me)
        XCTAssertEqual(world.lastPlea(of: seat.id)?.granted, true)
        XCTAssertEqual(world.lastPlea(of: seat.id)?.turnedAway, 2)
        let feast = Petition(id: world.takeID(), house: me, hold: seat.id, plea: .feast, arrived: world.watch, name: "Tam", price: Stock(grain: 10))
        XCTAssertEqual(world.rememberedPlea(feast),
                       "\(seat.name)'s folk last came to your gate in watch \(world.watch): \(third.name), a mason, asked to have its ward mended, "
                       + "and you granted it. You have turned away 2 of their pleas this age.")
    }

    /// Only the House whose hold it is knows what its folk remember; a hold
    /// another House has taken remembers nothing of the old one's answers
    /// and counts afresh; and it goes with the keeper's own parts of their
    /// view.
    func testOnlyTheHoldsOwnHouseKnowsItAndATakenHoldStartsAfresh() throws {
        var (world, me, seat) = try world()
        _ = world.bringPetitions()
        let first = try XCTUnwrap(world.petition(of: me))
        _ = try world.perform(.answerPetition(first.id, grant: false), as: me)
        XCTAssertEqual(world.view(for: me).lastPlea(of: seat.id)?.turnedAway, 1)
        let other = try XCTUnwrap(world.houses.first { $0.id != me }).id
        XCTAssertNil(world.view(for: other).pleas, "Another House is told nothing of it")
        // Taken by another House: what the old one answered is not theirs to hear.
        let theirs = Petition(id: world.takeID(), house: other, hold: seat.id, plea: .mend, arrived: world.watch, name: "Osric", price: Stock(stone: 10))
        XCTAssertNil(world.rememberedPlea(theirs))
        XCTAssertTrue(world.rememberedPleaFacts(theirs).isEmpty)
        world.rememberPlea(theirs, granted: false, silently: false)
        XCTAssertEqual(world.lastPlea(of: seat.id)?.house, other)
        XCTAssertEqual(world.lastPlea(of: seat.id)?.turnedAway, 1, "Counted afresh")
        XCTAssertNil(world.view(for: me).pleas)
        // A world kept and read back keeps it; one from before has none.
        let read = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(world))
        XCTAssertEqual(read.lastPlea(of: seat.id), world.lastPlea(of: seat.id))
        var before = world
        before.pleas = nil
        XCTAssertNil(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(before)).lastPlea(of: seat.id))
    }

    /// It travels with the keeper's own parts of their view, and the
    /// realm's, read back whole.
    func testItGoesWithTheKeepersOwnPartsOfTheirView() throws {
        var realm = RealmState(name: "The Nullmere", seed: "pleas remembered", seats: 12, radius: 36, watchLength: 180, now: 0)
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 0).house)
        let seat = try XCTUnwrap(realm.world.holds(of: ama).first { $0.isSeat })
        let plea = Petition(id: realm.world.takeID(), house: ama, hold: seat.id, plea: .hands, arrived: realm.world.watch, name: "Wenna",
                            price: Stock(grain: 20))
        realm.world.rememberPlea(plea, granted: true, silently: false)
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let hers = try XCTUnwrap(realm.view(for: "id-ama"))
        XCTAssertEqual(hers.world.lastPlea(of: seat.id)?.name, "Wenna")
        XCTAssertEqual(try RealmView(parts: hers.parts(using: encoder)), hers)
        XCTAssertEqual(try RealmState(parts: realm.parts(using: encoder)), realm)
    }

    func testWhatEachPleaAskedIsSaid() {
        XCTAssertEqual(Petition.Plea.allCases.map(\.askedFor), [
            "to have its ward mended", "to have the fire in its blackwood beaten out", "to have a hurt company tended",
            "to lend the folk's hands to its work", "to hold a feast",
        ])
    }
}
