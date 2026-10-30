import Foundation
import XCTest
@testable import NullmereCore

/// A realm fair to every keeper in it: one House's fall ends no one
/// else's age, the fallen don't hold up a watch, a seat counted free can be
/// taken, a new age seats those still coming, a name is short however it
/// is written, a House a keeper takes up never bends the knee for them, and
/// neither a keeper's view nor the words of a refusal tell anything another
/// House keeps to itself.
final class RealmFairnessTests: XCTestCase {
    private func realm(seats: Int = 4) -> RealmState {
        RealmState(name: "The Nullmere", seed: "fair realm", seats: seats, radius: 18, watchLength: 60, now: 0)
    }

    /// Takes a House off the lake: its holds go to another, its companies
    /// are gone.
    private func fell(_ house: Int, to taker: Int, in world: inout GameState) {
        for index in world.holds.indices where world.holds[index].owner == house {
            world.holds[index].owner = taker
            world.holds[index].isSeat = false
        }
        world.units.removeAll { $0.owner == house }
        world.houses[house].isEliminated = true
    }

    func testOneHousesFallEndsNoOneElsesAge() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        XCTAssertEqual(realm.world.player, ama, "The first kept House is the world's player")
        fell(ama, to: bel, in: &realm.world)
        _ = realm.world.endWatch()
        XCTAssertNil(realm.world.outcome, "Three Houses still stand: the age goes on")

        // A House's own game still ends with its House.
        var own = GameState(settings: GameSettings(seedText: "one House", houseCount: 3, radius: 14, keepers: 1))
        let other = try XCTUnwrap(own.houses.first { !$0.isPlayer }).id
        fell(own.player, to: other, in: &own)
        _ = own.endWatch()
        XCTAssertNotNil(own.outcome)
    }

    func testTheAgeEndsWhenEveryKeepersHouseHasFallen() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let steward = try XCTUnwrap(realm.world.houses.first { !$0.isPlayer }).id
        fell(ama, to: steward, in: &realm.world)
        // Alone and fallen, her readiness still turns the watch, and the age
        // ends: the greatest House left holds the lake.
        XCTAssertNotNil(realm.setReady("id-ama", true, now: 2))
        let outcome = try XCTUnwrap(realm.world.outcome)
        XCTAssertEqual(outcome.kind, .dominion)
        XCTAssertFalse(realm.world.houses[outcome.winner].isPlayer)
        // A realm no keeper has come to yet goes on.
        var empty = self.realm()
        _ = empty.world.endWatch()
        XCTAssertNil(empty.world.outcome)
    }

    func testAWorldFromBeforeHasItsMoonFoundAgain() throws {
        var realm = realm()
        let water = realm.world.moonWater
        realm.world.moonWater = nil
        realm.fillIn()
        XCTAssertEqual(realm.world.moonWater, water)
    }

    func testTheFallenDontHoldUpTheWatch() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        fell(bel, to: ama, in: &realm.world)
        let watch = realm.world.watch
        XCTAssertNotNil(realm.setReady("id-ama", true, now: 2), "Ama alone stands; her readiness turns the watch")
        XCTAssertEqual(realm.world.watch, watch + 1)
    }

    func testAFallenKeeperMayTakeUpAFreeHouse() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        fell(bel, to: ama, in: &realm.world)
        XCTAssertTrue(realm.hasFreeSeat)
        XCTAssertEqual(try realm.arrive("id-bel", name: nil, now: 2, reseatsTheFallen: false).house, bel, "Heard from, not asking")
        let taken = try XCTUnwrap(realm.arrive("id-bel", name: nil, now: 3).house, "Asking, seated anew")
        XCTAssertNotEqual(taken, bel)
        XCTAssertFalse(realm.world.houses[taken].isEliminated)
        XCTAssertEqual(realm.world.houses[taken].name, "Bel")
        // Once an age: fallen again, Bel looks on, though a seat stands open.
        fell(taken, to: ama, in: &realm.world)
        XCTAssertTrue(realm.hasFreeSeat)
        XCTAssertEqual(try realm.arrive("id-bel", name: nil, now: 4).house, taken, "No House after House")
        // A new age seats Bel afresh, and Bel may rise once more in it.
        realm.world.outcome = Outcome(winner: ama, kind: .dominion, watch: realm.world.watch)
        _ = realm.tick(now: 1e9)
        XCTAssertEqual(realm.age, 2)
        let anew = try XCTUnwrap(realm.keeper("id-bel")?.house)
        fell(anew, to: try XCTUnwrap(realm.keeper("id-ama")?.house), in: &realm.world)
        XCTAssertNotEqual(try realm.arrive("id-bel", name: nil, now: 1e9 + 1).house, anew)

        // With no House free, the fallen keep their fallen House and look on.
        var two = self.realm(seats: 2)
        let first = try XCTUnwrap(two.arrive("id-ama", name: "Ama", now: 1).house)
        let second = try XCTUnwrap(two.arrive("id-bel", name: "Bel", now: 1).house)
        fell(second, to: first, in: &two.world)
        XCTAssertFalse(two.hasFreeSeat)
        XCTAssertEqual(try two.arrive("id-bel", name: nil, now: 2).house, second)
    }

    func testASeatCountedFreeCanBeTaken() throws {
        var realm = realm(seats: 3)
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        for index in realm.world.houses.indices where index != ama {
            realm.world.houses[index].liege = ama
        }
        XCTAssertEqual(realm.status(now: 2).freeSeats, 0, "A sworn House is no seat")
        XCTAssertNil(try realm.arrive("id-cor", name: "Cor", now: 2).house)
    }

    func testANewAgeSeatsThoseStillComing() throws {
        var realm = realm()
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        _ = try realm.arrive("id-bel", name: "Bel", now: 1)
        _ = try realm.arrive("id-cor", name: "Cor", now: 1)
        _ = realm.setReady("id-bel", true, now: 5)
        XCTAssertEqual(realm.keeper("id-bel")?.hasPlayed, true)
        realm.depart("id-bel", now: 10)
        realm.depart("id-cor", now: 10)
        let later = 10 + RealmState.unplayedSeatHeldFor + 1
        realm.world.outcome = Outcome(winner: 0, kind: .dominion, watch: realm.world.watch)
        XCTAssertNotNil(realm.setReady("id-ama", true, now: later))
        XCTAssertEqual(realm.age, 2)
        XCTAssertNotNil(realm.keeper("id-ama")?.house, "There")
        XCTAssertNotNil(realm.keeper("id-bel")?.house, "Away less than a week, after playing")
        XCTAssertNil(realm.keeper("id-cor")?.house, "Away longer than an unplayed seat is held")
        XCTAssertNotNil(try realm.arrive("id-cor", name: nil, now: later + 1).house, "Seated as they come back")
    }

    func testANameIsShortHoweverItIsWritten() {
        XCTAssertTrue(RealmState.isValidName("Ilsë"))
        let stacked = "A" + String(repeating: "\u{0301}", count: 1500) + "b"
        XCTAssertEqual(stacked.count, 2)
        XCTAssertEqual(RealmState.nameProblem(stacked), "No more than twenty letters.")
    }

    func testAKeptHouseNeverBendsTheKneeForItsKeeper() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let other = try XCTUnwrap(realm.world.houses.first { !$0.isPlayer }).id
        let envoy = Envoy(id: realm.world.nextID, from: other, to: ama, proposal: .fealty, arrived: realm.world.watch)
        realm.world.nextID += 1
        realm.world.envoys.append(envoy)
        // Bel takes up the House that sent it.
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 2).house)
        XCTAssertEqual(bel, other)
        let events = try realm.perform(.answer(envoy: envoy.id, accept: true), by: "id-ama")
        XCTAssertNil(realm.world.houses[bel].liege)
        XCTAssertTrue(events.contains(.proposalAnswered(proposal: .fealty, from: bel, to: ama, accepted: false)))
    }

    /// An order naming a company out of the keeper's sight, or striking where
    /// they can't see, is refused just as if nothing stood there: a refusal
    /// is no spyglass.
    func testARefusalTellsNoMoreThanTheKeepersOwnView() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        let seen = realm.world.visibility(for: ama)
        func inSight(_ hex: Hex) -> Bool { realm.world.map.index(of: hex).map { seen[$0] } ?? false }
        // Out of sight, and in no hold, whose walls every House knows.
        let hidden = try XCTUnwrap(realm.world.units(of: bel).first { !inSight($0.position) && realm.world.hold(at: $0.position) == nil })
        let empty = try XCTUnwrap(realm.world.map.hexes.first { hex in
            !inSight(hex) && realm.world.unit(at: hex) == nil && realm.world.hold(at: hex) == nil
        })
        let spear = try XCTUnwrap(realm.world.units(of: ama).first { $0.kind == .spear })
        func refusal(_ command: Command) -> String? {
            do {
                _ = try realm.perform(command, by: "id-ama")
                return nil
            } catch {
                return error.description
            }
        }
        // Their company, out of sight, is no more there than one never made.
        XCTAssertEqual(refusal(.fortify(unit: hidden.id)), refusal(.fortify(unit: 987_654)))
        XCTAssertEqual(refusal(.fortify(unit: hidden.id)), RuleError.unknownUnit.description)
        // A strike where Ama can't see, at peace and at war.
        XCTAssertEqual(refusal(.attack(unit: spear.id, target: hidden.position)), refusal(.attack(unit: spear.id, target: empty)))
        _ = try realm.perform(.declareWar(on: bel), by: "id-ama")
        XCTAssertEqual(refusal(.attack(unit: spear.id, target: hidden.position)), refusal(.attack(unit: spear.id, target: empty)))
        XCTAssertEqual(refusal(.attack(unit: spear.id, target: empty)), RuleError.nothingToAttack.description)

        // A company in sight is another's, and said so.
        let mine = try XCTUnwrap(realm.world.seat(of: ama)?.position)
        let beside = try XCTUnwrap(realm.world.map.neighbors(of: mine).first { hex in
            realm.world.map[hex]?.terrain.isPassable == true && realm.world.unit(at: hex) == nil && realm.world.hold(at: hex) == nil
        })
        let index = try XCTUnwrap(realm.world.units.firstIndex { $0.id == hidden.id })
        realm.world.units[index].position = beside
        XCTAssertEqual(refusal(.fortify(unit: hidden.id)), RuleError.notYours.description)
    }

    /// A bow in the mist, its foe in reach but out of its sight: the realm
    /// strikes only what the keeper's House can see.
    func testNoStrikeIsLoosedIntoTheDark() throws {
        var realm = realm()
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        _ = try realm.perform(.declareWar(on: bel), by: "id-ama")
        // A bow of Ama's stands alone by Bel's seat, a company of Bel's two
        // tiles off; Rising Mist shortens the bow's sight to one.
        let world = realm.world
        func free(_ hex: Hex) -> Bool {
            world.map[hex]?.terrain.isPassable == true && world.map[hex]?.terrain != .barrow
                && world.unit(at: hex) == nil && world.hold(at: hex) == nil
        }
        let theirs = try XCTUnwrap(world.seat(of: bel)?.position)
        let (stand, foe) = try XCTUnwrap(world.map.hexes.lazy.filter { $0.distance(to: theirs) == 4 && free($0) }.compactMap { stand in
            stand.spiral(2).first { $0.distance(to: stand) == 2 && free($0) }.map { (stand, $0) }
        }.first)
        let bow = Unit(id: realm.world.takeID(), kind: .bow, owner: ama, position: stand)
        let enemy = Unit(id: realm.world.takeID(), kind: .spear, owner: bel, position: foe)
        realm.world.units += [bow, enemy]
        realm.world.omen = Omen(kind: .risingMist, began: realm.world.watch, ends: realm.world.watch + 3)
        let seen = realm.world.visibility(for: ama)
        XCTAssertEqual(realm.world.map.index(of: foe).map { seen[$0] }, false, "Out of sight in the mist")
        XCTAssertThrowsError(try realm.perform(.attack(unit: bow.id, target: foe), by: "id-ama")) {
            XCTAssertEqual(($0 as? RealmError)?.description, RuleError.nothingToAttack.description)
        }
        XCTAssertEqual(realm.world.unit(enemy.id)?.health, 100, "Untouched")
        // The mist lifts: in sight, it is struck.
        realm.world.omen = nil
        XCTAssertNoThrow(try realm.perform(.attack(unit: bow.id, target: foe), by: "id-ama"))
        XCTAssertLessThan(realm.world.unit(enemy.id)?.health ?? 0, 100)
    }

    func testAViewKeepsOtherHousesCounsel() throws {
        var world = GameState(settings: GameSettings(seedText: "kept counsel", houseCount: 3, radius: 16, keepers: 1))
        let me = world.player
        let others = world.houses.filter { !$0.isPlayer }.map(\.id)
        world.gifts = [Gift(from: others[0], to: others[1], worth: 5, watch: 1),
                       Gift(from: me, to: others[0], worth: 9, watch: 1)]
        let theirs = try XCTUnwrap(world.units.firstIndex { $0.owner == others[0] })
        // Their company stands beside my seat, bound elsewhere.
        let seat = try XCTUnwrap(world.seat(of: me)?.position)
        let beside = try XCTUnwrap(world.map.neighbors(of: seat).first { hex in
            world.map[hex]?.terrain.isPassable == true && world.unit(at: hex) == nil && world.hold(at: hex) == nil
        })
        world.units[theirs].destination = world.units[theirs].position
        world.units[theirs].position = beside
        let view = world.view(for: me)
        XCTAssertEqual(view.gifts, [Gift(from: me, to: others[0], worth: 9, watch: 1)], "Only the gifts their own House gave or took")
        let seen = try XCTUnwrap(view.units.first { $0.id == world.units[theirs].id })
        XCTAssertNil(seen.destination, "A company in sight, not its orders")
    }
}
