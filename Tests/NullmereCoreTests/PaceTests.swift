import Foundation
import XCTest
@testable import NullmereCore

/// A realm's watch passes pace by pace: companies on the march walk their
/// share of the watch's moves at each pace, stewards give their orders at
/// paces of their own, and the turn walks only what the paces left.
final class PaceTests: XCTestCase {
    /// A small lake where every House has its keeper, so no steward stirs,
    /// and the keeper's Spears bound for open ground seven tiles off, the
    /// way there greyfield all along: a step a move.
    private func marching(_ seed: String, paced: Bool) throws -> (state: GameState, spear: Int, destination: Hex) {
        var state = Scene.world(seed, houses: 3, radius: 16)
        for index in state.houses.indices { state.houses[index].isPlayer = true }
        if paced { state.pacing = Pacing() }
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        state.reveal(around: seat, range: 10, for: me)
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let destination = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: spear.position) == 7 && state.map[hex]?.terrain.isPassable == true && state.isClear(hex)
                && state.wild(at: hex) == nil && state.site(at: hex) == nil && state.path(for: spear, to: hex) != nil
        })
        for hex in try XCTUnwrap(state.path(for: spear, to: destination)) where state.hold(at: hex) == nil {
            state.map.set(hex, Tile(terrain: .greyfield))
        }
        return (state, spear.id, destination)
    }

    private func steps(of unit: Int, in events: [GameEvent]) -> Int {
        events.reduce(0) { count, event in
            if case .moved(unit, let path) = event { return count + path.count }
            return count
        }
    }

    func testAShareOfTheMovesAtEachPaceAndStewardsSpreadThroughTheWatch() {
        XCTAssertEqual(GameState.pacesPerWatch, 12)
        XCTAssertEqual((0...12).map { GameState.allowance(of: 2, by: $0) }, [0, 1, 1, 1, 1, 1, 1, 2, 2, 2, 2, 2, 2])
        XCTAssertEqual((0...12).map { GameState.allowance(of: 4, by: $0) }, [0, 1, 1, 1, 2, 2, 2, 3, 3, 3, 4, 4, 4])
        XCTAssertEqual(GameState.allowance(of: 3, by: 40), 3, "Never more than the watch's moves")
        XCTAssertEqual(GameState.allowance(of: 3, by: -2), 0)
        XCTAssertEqual((0..<11).map { GameState.stewardPace($0, of: 11) }, Array(1...11), "Eleven stewards, a pace each")
        XCTAssertEqual((0..<3).map { GameState.stewardPace($0, of: 3) }, [1, 4, 8])
        XCTAssertEqual(GameState.stewardPace(0, of: 0), 1)
        XCTAssertTrue((0..<40).allSatisfy { GameState.stewardPace($0, of: 40) < GameState.pacesPerWatch }, "Every steward before the turn")
    }

    func testAMarchWalksThroughTheWatchAsFarAsAtItsTurn() throws {
        var (paced, spear, destination) = try marching("pace by pace", paced: true)
        var (turned, _, _) = try marching("pace by pace", paced: false)
        let me = paced.player
        // The order is carried out at once, as far as this watch's moves go.
        let first = try paced.perform(.move(unit: spear, to: destination), as: me)
        XCTAssertEqual(first, try turned.perform(.move(unit: spear, to: destination), as: me))
        XCTAssertEqual(steps(of: spear, in: first), 2)
        let setOut = try XCTUnwrap(paced.unit(spear)).position

        // The watch turns: the paced march waits for the paces.
        let turn = paced.endWatch()
        XCTAssertEqual(steps(of: spear, in: turn), 0, "No burst as the watch turns")
        XCTAssertEqual(paced.unit(spear)?.position, setOut)
        XCTAssertEqual(paced.pacing, Pacing(), "A new watch, walked from its first pace")
        XCTAssertEqual(steps(of: spear, in: turned.endWatch()), 2, "Unpaced, it walks the watch's moves at once")

        // Pace by pace: a step at the first, the next at the seventh.
        var walked: [Int] = []
        for pace in 1...11 {
            walked.append(steps(of: spear, in: paced.walk(to: pace)))
            XCTAssertEqual(paced.pacing?.walked, pace)
        }
        XCTAssertEqual(walked, [1, 0, 0, 0, 0, 0, 1, 0, 0, 0, 0])
        XCTAssertEqual(walked.reduce(0, +), 2, "The watch's moves all walked by its end, as at its turn unpaced")
        XCTAssertEqual(paced.walk(to: 30), [], "The last pace is the turn's own")
        XCTAssertEqual(paced.pacing?.walked, 11)
        XCTAssertEqual(paced.walk(to: 4), [], "Paces walked aren't walked again")

        // Both turn on and walk on; the march ends where it was bound.
        for _ in 0..<3 {
            paced.endWatch()
            paced.walk(to: 11)
            turned.endWatch()
        }
        XCTAssertEqual(paced.unit(spear)?.position, destination)
        XCTAssertEqual(turned.unit(spear)?.position, destination)
        XCTAssertNil(paced.unit(spear)?.destination)
        XCTAssertEqual(paced.problems(), [])
    }

    func testTheTurnWalksWhatThePacesLeft() throws {
        var (state, spear, destination) = try marching("the rest", paced: true)
        let me = state.player
        try state.perform(.move(unit: spear, to: destination), as: me)
        state.endWatch()
        let start = try XCTUnwrap(state.unit(spear)).position
        XCTAssertEqual(steps(of: spear, in: state.walk(to: 3)), 1)
        // Everyone ready at the third pace: the watch turns early, and the
        // march walks the rest of its moves first.
        let turn = state.endWatch()
        XCTAssertEqual(steps(of: spear, in: turn), 1)
        XCTAssertEqual(try XCTUnwrap(state.unit(spear)).position.distance(to: start), 2)
        XCTAssertEqual(state.unit(spear)?.movesLeft, state.movement(of: try XCTUnwrap(state.unit(spear))), "Moves restored for the new watch")

        // No way to known ground: waited out at a pace, given up as the watch turns.
        let water = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain.isPassable == false && state.isExplored($0, by: me) })
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].destination = water
        XCTAssertEqual(state.march(spear, keeping: 0), [])
        XCTAssertEqual(state.unit(spear)?.destination, water, "A pace waits")
        XCTAssertEqual(state.march(spear), [])
        XCTAssertNil(state.unit(spear)?.destination, "The turn gives it up")
    }

    func testStewardsGiveTheirOrdersThroughTheWatchAndOnceOnly() throws {
        var state = Scene.world("stewards by pace", houses: 4, radius: 16)
        state.pacing = Pacing()
        let order = state.stewardOrder()
        XCTAssertEqual(order.count, 3)
        var joined: [Int: Int] = [:]
        for pace in 1...11 {
            state.walk(to: pace)
            for house in state.pacing?.stewarded ?? [] where joined[house] == nil { joined[house] = pace }
        }
        XCTAssertEqual(state.pacing?.stewarded, order, "Each in this watch's order")
        XCTAssertEqual(order.map { joined[$0] }, [1, 4, 8])

        // Their orders given, the turn doesn't give them again: nothing new
        // begun at their holds as it turns.
        var again = state
        let before = again
        again.endWatch()
        for house in order {
            let begun = again.holds(of: house).filter { hold in
                (hold.project != nil && before.hold(hold.id)?.project == nil) || (hold.training != nil && before.hold(hold.id)?.training == nil)
            }
            XCTAssertEqual(begun.map(\.name), [], "\(state.houses[house].title) gave its orders at its pace")
        }
        XCTAssertEqual(again.pacing, Pacing())

        // Unpaced, the same stewards give theirs as the watch turns.
        var turned = Scene.world("stewards by pace", houses: 4, radius: 16)
        let fresh = turned
        turned.endWatch()
        let begunAtTurn = order.flatMap { house in
            turned.holds(of: house).filter { hold in
                (hold.project != nil && fresh.hold(hold.id)?.project == nil) || (hold.training != nil && fresh.hold(hold.id)?.training == nil)
            }
        }
        XCTAssertFalse(begunAtTurn.isEmpty, "Stewards begin works and musters at their first watch")
        XCTAssertEqual(state.walk(to: 11, keptFor: []), [], "Walked already")
    }

    private func battles(_ events: [GameEvent]) -> Int {
        events.filter { if case .battle = $0 { return true } else { return false } }.count
    }

    /// Two Houses at war, every House kept, a company of each face to face.
    private func lockedInBattle(_ seed: String, paced: Bool) throws -> (state: GameState, mine: Int, theirs: Int, at: Hex) {
        var state = Scene.world(seed, houses: 3, radius: 16)
        for index in state.houses.indices { state.houses[index].isPlayer = true }
        if paced { state.pacing = Pacing() }
        let me = state.player
        _ = try state.declareWar(by: me, on: 1)
        let ground = try XCTUnwrap(state.openGround())
        let mine = state.put(.spear, of: me, at: ground)
        let there = ground + Hex.directions[0]
        let theirs = state.put(.spear, of: 1, at: there)
        return (state, mine, theirs, there)
    }

    func testInARealmABattleGoesOnPaceByPace() throws {
        var (state, mine, theirs, there) = try lockedInBattle("lasting battle", paced: true)
        let me = state.player
        let struck = try state.perform(.attack(unit: mine, target: there), as: me)
        XCTAssertEqual(battles(struck), 1)
        let field = try XCTUnwrap(state.fieldsOfBattle.first, "Battle is joined: a field of battle")
        XCTAssertEqual(struck.first, .fieldJoined(field: field.id, at: there, first: me, second: 1), "Told before its first blow")
        XCTAssertEqual(field.sides, [[me], [1]])
        XCTAssertEqual(field.fighters.map(\.unit), [mine, theirs])
        XCTAssertEqual(state.view(for: me).fieldsOfBattle.count, 1, "Seen by those who fight in it")
        var later: [GameEvent] = []
        for pace in 1...(GameState.pacesPerWatch - 1) where !state.fieldsOfBattle.isEmpty {
            later += state.walk(to: pace)
        }
        XCTAssertGreaterThanOrEqual(battles(later), 2, "Blows again at the paces after, and the struck strikes back")
        XCTAssertTrue(later.allSatisfy { event in
            if case .battle(let battle) = event { return battle.field == field.id }
            return true
        }, "Every blow the field's")
        XCTAssertEqual(state.fieldsOfBattle, [], "Over: a side fallen")
        XCTAssertTrue(state.unit(mine) == nil || state.unit(theirs) == nil)
        XCTAssertEqual(state.problems(), [])

        // Outside a realm, a strike is one exchange.
        var (turned, mine3, _, there3) = try lockedInBattle("one exchange", paced: false)
        let once = try turned.perform(.attack(unit: mine3, target: there3), as: turned.player)
        XCTAssertEqual(turned.fieldsOfBattle, [])
        XCTAssertFalse(once.contains { if case .fieldJoined = $0 { return true } else { return false } })

        // One that draws off ends it, with no blow.
        var (drawn, mine2, theirs2, there2) = try lockedInBattle("drawn off", paced: true)
        try drawn.perform(.attack(unit: mine2, target: there2), as: drawn.player)
        XCTAssertNotNil(drawn.unit(mine2))
        XCTAssertNotNil(drawn.unit(theirs2), "Whole companies both stand the first exchange")
        let away = try XCTUnwrap(drawn.freeHex(near: there2, within: 4...5))
        drawn.units[try XCTUnwrap(drawn.unitIndex(theirs2))].position = away
        let ended = drawn.walk(to: 1)
        XCTAssertEqual(battles(ended), 0)
        XCTAssertEqual(drawn.fieldsOfBattle, [])
        let over = try XCTUnwrap(ended.compactMap { event -> Field? in
            if case .fieldEnded(let field) = event { return field }
            return nil
        }.first)
        XCTAssertEqual(over.held, 0, "The side still there holds the field")
        XCTAssertEqual(over.fighter(theirs2)?.standing, false)
        XCTAssertEqual(over.fighter(theirs2)?.fell, false, "Drawn off, not fallen")
    }

    func testARealmsWatchIsWalkedOnItsClock() throws {
        var realm = RealmState(name: "The Nullmere", seed: "paced realm", seats: 4, radius: 16, watchLength: 120, now: 0)
        XCTAssertEqual(realm.world.pacing, Pacing(), "A realm's watch passes pace by pace")
        XCTAssertEqual(realm.pace(now: 50), [], "An empty realm sleeps")
        XCTAssertEqual(realm.world.pacing?.walked, 0)

        let keeper = try realm.arrive("pacer", name: "Ama", now: 0)
        let me = try XCTUnwrap(keeper.house)
        _ = realm.pace(now: 9.9)
        XCTAssertEqual(realm.world.pacing?.walked, 0, "Not yet the first pace")
        _ = realm.pace(now: 10)
        XCTAssertEqual(realm.world.pacing?.walked, 1)
        XCTAssertEqual(realm.world.pacing?.stewarded.count, 1, "The first steward gives its orders at the first pace")
        _ = realm.pace(now: 119)
        XCTAssertEqual(realm.world.pacing?.walked, 11)
        XCTAssertEqual(Set(try XCTUnwrap(realm.world.pacing).stewarded), Set(realm.world.houses.indices.filter { $0 != me }))
        XCTAssertNil(realm.tick(now: 119.5))
        XCTAssertNotNil(realm.tick(now: 120), "The watch turns on time")
        XCTAssertEqual(realm.world.pacing, Pacing())
        XCTAssertEqual(realm.world.watch, 2)

        // A keeper's march walks on through the next watch.
        let spear = try XCTUnwrap(realm.world.units(of: me).first { $0.kind == .spear })
        realm.world.reveal(around: spear.position, range: 10, for: me)
        let far = try XCTUnwrap(realm.world.map.hexes.first { hex in
            hex.distance(to: spear.position) == 8 && realm.world.map[hex]?.terrain.isPassable == true && realm.world.isClear(hex)
                && realm.world.wild(at: hex) == nil && realm.world.path(for: spear, to: hex) != nil
        })
        _ = try realm.perform(.move(unit: spear.id, to: far), by: "pacer")
        _ = realm.tick(now: 240)
        let after = try XCTUnwrap(realm.world.unit(spear.id)).position
        let walked = realm.pace(now: 240 + 10)
        XCTAssertTrue(walked.contains { if case .moved(spear.id, _) = $0 { return true } else { return false } }, "A step at the first pace")
        XCTAssertNotEqual(realm.world.unit(spear.id)?.position, after)
        XCTAssertEqual(realm.world.events(walked, heardBy: me).filter { if case .moved(spear.id, _) = $0 { return true } else { return false } }.count, 1,
                       "Heard by its keeper")

        // Kept in its parts, and a realm from before paces walks so from now on.
        let parts = try realm.parts(using: Scene.encoder)
        XCTAssertEqual(try RealmState(parts: parts).world.pacing, realm.world.pacing)
        var older = realm
        older.world.pacing = nil
        older.fillIn()
        XCTAssertEqual(older.world.pacing, Pacing())
    }
}
