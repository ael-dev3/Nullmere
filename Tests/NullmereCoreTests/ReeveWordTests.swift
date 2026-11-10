import Foundation
import XCTest
@testable import NullmereCore

/// The reeve's word as the keeper turns to a hold of theirs, for a device's
/// own model to give: only what the House knows of the hold (its works,
/// what it raises and musters, its walls and ward, who keeps its gates,
/// what lies about it, a plea waiting, fire on its land), asked afresh each
/// watch and once its work or its danger changes; never an order; no word
/// for another House's hold.
final class ReeveWordTests: XCTestCase {
    /// A keeper's seat with nothing under way, stores to spend, at the
    /// first watch pleas may come.
    private func seat(_ seed: String = "the reeve's word") throws -> (world: GameState, me: Int, seat: Int, at: Int) {
        var world = Scene.world(seed)
        world.watch = Petition.from
        let me = world.player
        let seat = try XCTUnwrap(world.holds(of: me).first { $0.isSeat })
        let index = try XCTUnwrap(world.holdIndex(seat.id))
        world.holds[index].project = nil
        world.holds[index].training = nil
        world.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        return (world, me, seat.id, index)
    }

    func testTheReeveTellsTheHoldAsTheHouseKnowsIt() throws {
        let (world, me, id, _) = try seat()
        let view = world.view(for: me)
        let hold = try XCTUnwrap(view.hold(id))
        let word = try XCTUnwrap(view.reeveWord(of: id, for: me))
        XCTAssertEqual(word.task, Voicing.reeveTask)
        XCTAssertEqual(word.facts.first, "\(hold.name) is the seat of \(view.houses[me].title).")
        XCTAssertTrue(word.facts.contains("It raises no work now."), word.facts.joined(separator: "\n"))
        XCTAssertTrue(word.facts.contains("\(GameState.wallsSaid(hold.level(.walls))), its ward \(hold.ward) of \(hold.maximumWard)."),
                      word.facts.joined(separator: "\n"))
        // Never a word the voices keep from: no level, no turns.
        for fact in word.facts + [Voicing.reeveTask] {
            let words = Set(fact.lowercased().split(whereSeparator: { !$0.isLetter }).map(String.init))
            XCTAssertTrue(words.isDisjoint(with: ["level", "levels", "turn", "turns"]), fact)
        }
        // Its works, the highest first, as the order book names them.
        let works = hold.levels.filter { $0.key != .walls && $0.value > 0 }
        if let highest = works.max(by: { ($0.value, $1.key.title) < ($1.value, $0.key.title) }) {
            let line = try XCTUnwrap(word.facts.first { $0.hasPrefix("Its works: ") })
            XCTAssertTrue(line.hasPrefix("Its works: \(highest.key.title) \(BuildingKind.numeral(highest.value))"), line)
        }
        // Its own companies at its gates, counted as every line counts them.
        for unit in view.units where unit.owner == me && unit.position == hold.position {
            let gates = try XCTUnwrap(word.facts.first { $0.hasPrefix("At its gates: ") })
            XCTAssertTrue(gates.contains("your \(SpokenOrders.named(unit, in: view)), \(GameState.counted(view.troops(of: unit))) troops"), gates)
        }
        // What lies about it as a commander's look tells it, the hold itself left out.
        let near = view.seen(around: hold.position, by: me, within: GameState.reeveLooks, besides: id).prefix(GameState.reeveTells)
        XCTAssertFalse(near.contains { $0.hasPrefix("\(hold.name), a hold of") }, "the hold is not about itself")
        let told = near.isEmpty ? "About it the House sees nothing but the land." : "About it the House sees: " + near.joined(separator: "; ") + "."
        XCTAssertTrue(word.facts.contains(told), word.facts.joined(separator: "\n"))
        XCTAssertFalse(word.facts.contains("Its folk wait at the gate with a plea."), "no plea waits")
        XCTAssertTrue(word.prompt.hasPrefix(Voicing.reeveTask))
        XCTAssertTrue(Voicing.reeveTask.contains("Propose nothing and promise nothing"), "a word, never an order")
        XCTAssertTrue(Voicing.reeveTask.contains("keeping every name and number as given"))
    }

    func testWhatItRaisesAndMustersIsTold() throws {
        var (world, me, id, _) = try seat()
        try world.perform(.build(hold: id, kind: .granary), as: me)
        let hold = try XCTUnwrap(world.hold(id))
        let project = try XCTUnwrap(hold.project)
        let word = try XCTUnwrap(world.reeveWord(of: id, for: me))
        XCTAssertTrue(word.facts.contains("It raises \(project.kind.title) \(BuildingKind.numeral(project.targetLevel)), done in "
                                          + "\(GameState.watches(project.watchesLeft))."), word.facts.joined(separator: "\n"))
        XCTAssertFalse(word.facts.contains("It raises no work now."))
        if let kind = UnitKind.allCases.first(where: { world.tierRefusal(of: $0, tier: 1, at: hold, for: me) == nil && $0.isMilitary }) {
            try world.perform(.train(hold: id, kind: kind, tier: 1), as: me)
            let training = try XCTUnwrap(world.hold(id)?.training)
            let mustering = try XCTUnwrap(world.reeveWord(of: id, for: me))
            XCTAssertTrue(mustering.facts.contains("It musters \(training.kind.named(tier: training.musteredTier)), ready in "
                                                   + "\(GameState.watches(training.watchesLeft))."), mustering.facts.joined(separator: "\n"))
        }
    }

    func testAPleaAtTheGateAndAWardBrokenAreToldAndCallAfresh() throws {
        var (world, me, id, at) = try seat()
        let key = try XCTUnwrap(world.reeveWordKey(of: id, for: me))
        XCTAssertEqual(world.reeveWordKey(of: id, for: me), key, "the hold as it was, the same word")
        XCTAssertEqual(GameState.hold(ofWord: key), id)
        world.holds[at].ward = 1
        let broken = try XCTUnwrap(world.reeveWordKey(of: id, for: me))
        XCTAssertNotEqual(broken, key, "its ward broken, a fresh word")
        _ = world.bringPetitions()
        XCTAssertEqual(world.petition(of: me)?.hold, id)
        let word = try XCTUnwrap(world.reeveWord(of: id, for: me))
        XCTAssertTrue(word.facts.contains("Its folk wait at the gate with a plea."), word.facts.joined(separator: "\n"))
        XCTAssertTrue(word.facts.contains { $0.contains("its ward 1 of") })
        XCTAssertNotEqual(world.reeveWordKey(of: id, for: me), broken, "a plea brought, a fresh word")
    }

    func testAWordIsAskedAfreshEachWatchAndAtWorkBegunOrAFoeNear() throws {
        var (world, me, id, _) = try seat()
        let key = try XCTUnwrap(world.reeveWordKey(of: id, for: me))
        try world.perform(.build(hold: id, kind: .granary), as: me)
        let raising = try XCTUnwrap(world.reeveWordKey(of: id, for: me))
        XCTAssertNotEqual(raising, key, "work begun, a fresh word")
        // A foe come within two tiles.
        let hold = try XCTUnwrap(world.hold(id))
        let foe = try XCTUnwrap(world.units.first { $0.owner != me })
        let near = try XCTUnwrap(world.map.hexes.first { $0.distance(to: hold.position) == 2 && world.map[$0].map { !$0.terrain.isWater } == true })
        world.units[try XCTUnwrap(world.unitIndex(foe.id))].position = near
        let threatened = try XCTUnwrap(world.reeveWordKey(of: id, for: me))
        XCTAssertNotEqual(threatened, raising, "a foe near, a fresh word")
        let word = try XCTUnwrap(world.reeveWord(of: id, for: me))
        let about = try XCTUnwrap(word.facts.first { $0.hasPrefix("About it the House sees: ") })
        XCTAssertTrue(about.contains(GameState.waySaid(to: near, from: hold.position)), about)
        world.watch += 1
        XCTAssertNotEqual(world.reeveWordKey(of: id, for: me), threatened, "each watch its word")
    }

    func testWallsAreSaidByTheirHeightNeverAsALevel() {
        XCTAssertEqual(GameState.wallsSaid(0), "It has no walls yet")
        XCTAssertEqual(GameState.wallsSaid(2), "Its walls stand at the second of their \(BuildingKind.walls.maxLevel == 5 ? "five" : "\(BuildingKind.walls.maxLevel)") heights")
        XCTAssertTrue(GameState.wallsSaid(BuildingKind.walls.maxLevel).hasPrefix("Its walls stand at the "))
    }

    func testNoWordForAnotherHousesHold() throws {
        let (world, me, id, _) = try seat()
        let other = try XCTUnwrap(world.holds.first { $0.owner != me })
        XCTAssertNil(world.reeveWord(of: other.id, for: me))
        XCTAssertNil(world.reeveWordKey(of: other.id, for: me))
        XCTAssertNil(world.reeveWord(of: id, for: other.owner), "nor of the keeper's for another House")
        XCTAssertNil(world.reeveWord(of: 987_654, for: me), "nor of a hold that is not")
    }

    /// Each hold's reeve goes by one name for its life, the name a plea
    /// for the folk's hands is brought by (`PetitionTests`).
    func testAHoldsReeveGoesByOneName() throws {
        let (world, _, id, _) = try seat()
        let name = world.reeveName(of: id)
        XCTAssertTrue(Petition.names.contains(name))
        var later = world
        later.watch += 30
        XCTAssertEqual(later.reeveName(of: id), name, "the same reeve through the age")
        let hold = try XCTUnwrap(world.hold(id))
        XCTAssertEqual(world.reeveSaid(of: hold), "\(name), the reeve of \(hold.name)")
        // Not every hold's reeve is called alike.
        XCTAssertGreaterThan(Set(world.holds.map { world.reeveName(of: $0.id) }).count, 1)
        XCTAssertTrue(Petition.names.contains(world.reeveName(of: -5)), "any id names a reeve")
    }
}
