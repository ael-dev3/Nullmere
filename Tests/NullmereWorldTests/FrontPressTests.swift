import Foundation
@testable import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// Two hosts in a field of battle meet: each company fighting hand to
/// hand presses from the heart of its hex toward the foe beside it until
/// its foremost man stands just short of the line midway between them,
/// so the two fronts meet there and its steel flashes along that line;
/// it eases up to the foe as it comes to the fight and back as it leaves.
final class FrontPressTests: XCTestCase {
    private func heart(_ hex: Hex) -> Vec3 {
        let centre = Relief.centre(of: hex)
        return Vec3(centre.x, 0, centre.z)
    }

    func testTwoCompaniesBesideEachOtherMeetOnTheLineBetweenThem() {
        let mine = heart(Hex(3, 4)), theirs = heart(Hex(4, 4))
        let between = (theirs - mine).length
        for count in [8, 24, Formation.throngMost] {
            let front = WorldStage.frontReach(throng: count, unit: 7, spread: 1)
            let foeFront = WorldStage.frontReach(throng: count, unit: 9, spread: 1)
            XCTAssertGreaterThan(front, 0, "the foremost man stands before the company's heart")
            XCTAssertLessThan(front + foeFront, between - WorldStage.frontGap,
                              "unpressed, \(count) men a side stand apart: the gap the press closes")
            let way = WorldStage.pressWay(from: mine, toward: theirs, front: front)
            let back = WorldStage.pressWay(from: theirs, toward: mine, front: foeFront)
            XCTAssertEqual(way.y, 0, "pressed over the ground")
            XCTAssertGreaterThan(way.dot(theirs - mine), 0, "toward the foe")
            XCTAssertEqual(way.normalized.dot((theirs - mine).normalized), 1, accuracy: 0.0001, "straight at it")
            // Each foremost man half a man's breadth short of the middle line,
            // so the two fronts are a man's breadth apart: met, not passed through.
            XCTAssertEqual(way.length + front, between / 2 - WorldStage.frontGap / 2, accuracy: 0.0001)
            let apart = between - (way.length + front) - (back.length + foeFront)
            XCTAssertEqual(apart, WorldStage.frontGap, accuracy: 0.0001, "the fronts meet, \(count) men a side")
            XCTAssertLessThanOrEqual(way.length, between * WorldStage.pressMost + 0.0001, "never deep into the foe's ground")
        }
    }

    func testACompanyWhoseRanksReachTheLineOrStandsOnTheFoesHexIsNotPressed() {
        let mine = heart(Hex(0, 0)), theirs = heart(Hex(1, 0))
        let between = (theirs - mine).length
        XCTAssertEqual(WorldStage.pressWay(from: mine, toward: theirs, front: between / 2), Vec3(0, 0, 0),
                       "its foremost man already on the line")
        XCTAssertEqual(WorldStage.pressWay(from: mine, toward: mine, front: 0.2), Vec3(0, 0, 0), "the foe on its own hex")
        // A thin front, far back, is pressed no more than its most.
        XCTAssertEqual(WorldStage.pressWay(from: mine, toward: theirs, front: 0).length, between * WorldStage.pressMost, accuracy: 0.0001)
    }

    func testTheFrontStandsFurtherForwardTheMoreRanksTheThrongHas() {
        let few = WorldStage.frontReach(throng: 8, unit: 3, spread: 1)
        let many = WorldStage.frontReach(throng: Formation.throngMost, unit: 3, spread: 1)
        XCTAssertGreaterThan(many, few, "a deeper throng's front rank stands further forward")
        XCTAssertEqual(WorldStage.frontReach(throng: 8, unit: 3, spread: 2), few * 2, accuracy: 0.0001, "and wider spread, further still")
        XCTAssertEqual(WorldStage.frontReach(throng: 0, unit: 3, spread: 1), 0, "no throng, no front")
    }

    func testACompanyComingToTheFightEasesUpToTheFoeAndBackAsItLeaves() throws {
        let way = Vec3(0.4, 0, 0)
        // Coming to the fight: from its own ground, eased in over the press's time.
        var press = try XCTUnwrap(FrontPress.step(nil, toward: way, at: 10))
        XCTAssertEqual(press.offset, Vec3(0, 0, 0), "it starts from its own ground")
        let half = Double(WorldStage.pressTime) / 2
        press = try XCTUnwrap(FrontPress.step(press, toward: way, at: 10 + half))
        XCTAssertEqual(press.offset.x, 0.2, accuracy: 0.0001, "half way at half the time")
        let early = try XCTUnwrap(FrontPress.step(FrontPress(way: way, amount: 0, at: 10), toward: way, at: 10 + half / 3))
        XCTAssertLessThan(early.offset.x, 0.4 / 6, "slow to start")
        press = try XCTUnwrap(FrontPress.step(press, toward: way, at: 10 + 4 * half))
        XCTAssertEqual(press.offset, way, "at the front once its time is out")
        press = try XCTUnwrap(FrontPress.step(press, toward: way, at: 30))
        XCTAssertEqual(press.offset, way, "and there it stays while it fights")
        // Its foe shifting: it presses the new way.
        let other = Vec3(0, 0, -0.3)
        press = try XCTUnwrap(FrontPress.step(press, toward: other, at: 30.1))
        XCTAssertEqual(press.offset, other)
        // Leaving the fight: back to its own ground the way it came, then let go.
        press = try XCTUnwrap(FrontPress.step(press, toward: nil, at: 30.1 + half))
        XCTAssertEqual(press.offset.z, -0.15, accuracy: 0.0001, "half way back at half the time")
        XCTAssertNil(FrontPress.step(press, toward: nil, at: 30.1 + 3 * half), "back on its own ground, nothing kept")
        XCTAssertNil(FrontPress.step(nil, toward: nil, at: 40), "a company never at the foe keeps nothing")
    }

    func testACompanyFirstSeenInAFightUnderWayStandsAtTheFrontAtOnce() throws {
        let way = Vec3(0, 0, 0.35)
        let seen = try XCTUnwrap(FrontPress.step(nil, toward: way, at: 5, firstSeen: true))
        XCTAssertEqual(seen.offset, way, "the keeper's eye falls on a fight already joined")
        // The world's clock never runs back; should a frame be drawn for an earlier moment, nothing moves.
        let again = try XCTUnwrap(FrontPress.step(FrontPress(way: way, amount: 0.5, at: 5), toward: way, at: 4))
        XCTAssertEqual(again.amount, 0.5)
    }

    /// A field of two spears a side face to face, each side's bow behind
    /// its spears: each spear fights the foe's beside it hand to hand; the
    /// bows, which fight at a distance, press no foe.
    func testEachSpearFightsTheFoeBesideItHandToHandAndTheBowsNone() throws {
        var state = GameState(settings: GameSettings(seedText: "fronts", houseCount: 4, radius: 12, keepers: 1))
        let me = state.player, foe = (me + 1) % state.houses.count
        _ = try state.declareWar(by: me, on: foe)
        state.pacing = Pacing()
        let seat = try XCTUnwrap(state.seat(of: me))
        let east = Hex.directions[0], along = Hex.directions[5]
        func open(_ hex: Hex) -> Bool {
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }
        let ground = try XCTUnwrap(seat.position.spiral(8).first { g in
            g.distance(to: seat.position) >= 3 && [0, 1].allSatisfy { step in
                [-1, 0, 1, 2].allSatisfy { open(g + along * step + east * $0) }
            }
        }, "open ground for the field")
        func raise(_ kind: UnitKind, of house: Int, at hex: Hex) -> Int {
            var unit = Unit(id: state.takeID(), kind: kind, owner: house, position: hex, tier: 5)
            unit.drilled = 25_000 - state.firstMuster(of: unit)
            state.units.append(unit)
            return unit.id
        }
        var spears: [(mine: Int, theirs: Int, at: Hex)] = []
        var bows: [Int] = []
        var orders: [(Int, Int, Hex)] = []
        for step in [0, 1] {
            let front = ground + along * step
            let mine = raise(.spear, of: me, at: front), theirs = raise(.spear, of: foe, at: front + east)
            spears.append((mine, theirs, front))
            orders.append((me, mine, front + east))
            orders.append((foe, theirs, front))
            let myBow = raise(.bow, of: me, at: front - east), theirBow = raise(.bow, of: foe, at: front + east * 2)
            bows += [myBow, theirBow]
            orders.append((me, myBow, front + east))
            orders.append((foe, theirBow, front))
        }
        for (house, unit, target) in orders { _ = try state.perform(.attack(unit: unit, target: target), as: house) }
        XCTAssertFalse(state.fieldsOfBattle.isEmpty, "the blows joined in a field")
        let atFoe = WorldStage.handToHand(in: state)
        for pair in spears {
            XCTAssertEqual(atFoe[pair.mine], pair.at + east, "each spear presses the foe's beside it")
            XCTAssertEqual(atFoe[pair.theirs], pair.at)
        }
        for bow in bows { XCTAssertNil(atFoe[bow], "a bow fights at a distance and presses none") }
        XCTAssertTrue(WorldStage.handToHand(in: GameState(settings: GameSettings(seedText: "quiet", houseCount: 4, radius: 12, keepers: 1)))
            .isEmpty, "no field, no one pressed")
    }

    func testTheSteelFlashesAlongTheLineWhereTheFrontsMeet() {
        var happenings = Happenings()
        let from = Vec3(0, 0, 0), to = Vec3(1.732, 0, 0)
        happenings.fronts = [Happenings.Front(from: from, to: to, strength: 4, seed: 11)]
        var flashes: [Vec3] = []
        for step in 0..<40 {
            let (motes, _) = happenings.effects(at: 10 + Float(step) * Happenings.clashEvery)
            // A flash: one swell of warm light where the blow lands, at the height steel meets.
            for mote in motes where mote.colour.w == 0 && mote.colour.y > 0 && abs(mote.colour.x / mote.colour.y - 1.5 / 1.05) < 0.01 {
                flashes.append(Vec3(mote.place.x, mote.place.y, mote.place.z))
            }
        }
        XCTAssertGreaterThan(flashes.count, 40, "clash on clash")
        let along = flashes.map(\.x), across = flashes.map(\.z)
        let middle = (from.x + to.x) / 2
        for x in along {
            XCTAssertEqual(x, middle, accuracy: 1.732 * Happenings.clashAlong + 0.001, "where the two throngs meet, not among their ranks")
        }
        XCTAssertGreaterThan((across.max() ?? 0) - (across.min() ?? 0), Happenings.clashAcross,
                             "all along the meeting of the fronts, not at one point of it")
        XCTAssertTrue(across.allSatisfy { abs($0) <= Happenings.clashAcross + 0.001 })
    }
}
