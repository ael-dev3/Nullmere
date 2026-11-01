import Foundation
import XCTest
@testable import NullmereCore

/// Mangonels, Rise of Kingdoms' siege engines: a company of war mustered
/// from a Muster Hall of IV, in five tiers, that hurls stones from two
/// tiles away, three times as hard as any other company on walls and
/// wards, soft in the field and riders' prey, taking no hold itself.
/// Stewards at war muster a few.
final class MangonelTests: XCTestCase {
    func testAMangonelIsAnEngineOfSiege() {
        let kind = UnitKind.mangonel
        XCTAssertEqual(kind.title, "Mangonels")
        XCTAssertTrue(kind.isMilitary)
        XCTAssertTrue(kind.hasTiers)
        XCTAssertEqual(kind.highestTier, Unit.highestTier)
        XCTAssertEqual(kind.range, 2, "from two tiles away")
        XCTAssertFalse(kind.canCapture, "it breaks walls; others take the hold")
        XCTAssertEqual(kind.requiredMuster, 4)
        XCTAssertEqual(kind.requiredMuster(tier: 5), 5)
        XCTAssertEqual(kind.wardPercent, 300)
        XCTAssertEqual(UnitKind.spear.wardPercent, 100)
        XCTAssertEqual(UnitKind.rider.bonusAgainstMangonels, 50)
        XCTAssertEqual(UnitKind.bow.bonusAgainstMangonels, 0)
        XCTAssertLessThan(kind.attack, UnitKind.bow.attack, "soft in the field")
        XCTAssertLessThan(kind.defense, UnitKind.bow.defense)
        XCTAssertEqual(kind.troops(tier: 1), 300)
        XCTAssertEqual(kind.troops(tier: 5), 600)
        XCTAssertGreaterThan(kind.cost.timber, UnitKind.bow.cost.timber, "an engine of timber")
        XCTAssertEqual(BuildingKind.roadLevel(for: kind), 4)
        XCTAssertEqual(BuildingKind.wayhouse.effect(atLevel: 4), "Bows and Mangonels of the House a step further every watch")
        XCTAssertEqual(BuildingKind.musterHall.effect(atLevel: 4), "Trains Mangonels; companies of war of tier IV, once studied")
    }

    /// From a Muster Hall of IV, and not below.
    func testMangonelsAreMusteredFromAHallOfFour() throws {
        var state = Scene.world("mangonels mustered")
        let me = state.player
        state.richen(me)
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.musterHall] = 3
        let id = state.holds[seat].id
        XCTAssertThrowsError(try state.perform(.train(hold: id, kind: .mangonel), as: me))
        state.holds[seat].levels[.musterHall] = 4
        XCTAssertEqual(try state.perform(.train(hold: id, kind: .mangonel), as: me), [.trainingStarted(hold: id, kind: .mangonel)])
        for _ in 0..<6 where state.holds[seat].training != nil { _ = state.endWatch() }
        XCTAssertTrue(state.units.contains { $0.owner == me && $0.kind == .mangonel })
    }

    /// Its stones take three times what another's blow of its strength
    /// would from a ward, from two tiles away and with nothing returned;
    /// and with the ward down, it takes no hold.
    func testAMangonelBreaksWallsFromAfar() throws {
        var state = Scene.world("stones on the walls")
        let me = state.player
        let foe = (me + 1) % state.houses.count
        _ = try state.declareWar(by: me, on: foe)
        let hold = try XCTUnwrap(state.holds.first { $0.owner == foe })
        let hex = try XCTUnwrap(state.freeHex(near: hold.position, within: 2...2))
        let engine = state.put(.mangonel, of: me, at: hex)
        let mangonel = try XCTUnwrap(state.unit(engine))
        XCTAssertEqual(state.wardDamage(by: mangonel), (12 + 4 * 4) * 3, "thrice its strength's")
        let bow = Unit(id: 0, kind: .bow, owner: me, position: hex)
        XCTAssertGreaterThan(state.wardDamage(by: mangonel), state.wardDamage(by: bow) * 2)
        // Garrisons fight first: the hold is struck bare.
        state.units.removeAll { $0.position == hold.position }
        let ward = try XCTUnwrap(state.hold(hold.id)).ward
        let events = try state.perform(.attack(unit: engine, target: hold.position), as: me)
        guard case .battle(let battle)? = events.first else { return XCTFail("A blow on the ward: \(events)") }
        XCTAssertEqual(battle.attackerKind, .mangonel)
        XCTAssertEqual(battle.damageTaken, 0, "nothing returned to two tiles away")
        let struck = try XCTUnwrap(state.hold(hold.id)).ward
        XCTAssertLessThan(struck, ward)
        XCTAssertGreaterThanOrEqual(ward - struck, min(ward, state.wardDamage(by: mangonel) * 8 / 10))
        // Its ward down, the hold is still its House's.
        let index = try XCTUnwrap(state.holdIndex(hold.id))
        state.holds[index].ward = 1
        state.units[try XCTUnwrap(state.units.firstIndex { $0.id == engine })].acted = false
        state.units[try XCTUnwrap(state.units.firstIndex { $0.id == engine })].movesLeft = UnitKind.mangonel.movement
        _ = try state.perform(.attack(unit: engine, target: hold.position), as: me)
        XCTAssertEqual(state.hold(hold.id)?.ward, 0)
        XCTAssertEqual(state.hold(hold.id)?.owner, foe, "a Mangonel takes no hold")
    }

    /// Riders fall on Mangonels half again as hard as on others.
    func testRidersFallOnMangonels() throws {
        var state = Scene.world("riders on the engines")
        let me = state.player
        let foe = (me + 1) % state.houses.count
        let seat = try XCTUnwrap(state.seat(of: me))
        let at = try XCTUnwrap(state.freeHex(near: seat.position, within: 3...4))
        let near = try XCTUnwrap(state.freeHex(near: at))
        let riders = state.put(.rider, of: foe, at: near)
        let engines = state.put(.mangonel, of: me, at: at)
        let rider = try XCTUnwrap(state.unit(riders))
        let engine = try XCTUnwrap(state.unit(engines))
        let bow = Unit(id: 0, kind: .bow, owner: me, position: at)
        let onEngine = state.strengths(of: rider, against: engine, at: at).attack
        let onBow = state.strengths(of: rider, against: bow, at: at).attack
        XCTAssertLessThanOrEqual(abs(onEngine - onBow * 3 / 2), 1, "half again as hard: \(onEngine) against \(onBow)")
    }

    /// Its crew gather slowly at the land's sites, but its bed carries much.
    func testAMangonelGathersSlowlyAndCarriesMuch() throws {
        var state = Scene.world("engines at the quarry")
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let at = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        let engines = state.put(.mangonel, of: me, at: at), spears = state.put(.spear, of: me, at: try XCTUnwrap(state.freeHex(near: at)))
        let engine = try XCTUnwrap(state.unit(engines)), spear = try XCTUnwrap(state.unit(spears))
        XCTAssertLessThan(state.gatheringRate(of: engine, for: .stone), state.gatheringRate(of: spear, for: .stone))
        XCTAssertGreaterThan(state.capacity(of: engine, for: .stone), state.capacity(of: spear, for: .stone))
    }

    /// A steward musters an engine only from a hall of IV, so a world of
    /// stewards goes as it always did until its halls stand so high.
    func testStewardsMusterEnginesOnlyFromAHallOfIV() {
        var state = GameState(settings: GameSettings(seedText: "no engines", houseCount: 5, radius: 18))
        for _ in 0..<60 { _ = state.endWatch() }
        let high = Set(state.holds.filter { $0.level(.musterHall) >= UnitKind.mangonel.requiredMuster }.map(\.owner))
        XCTAssertTrue(state.units.filter { $0.kind == .mangonel }.allSatisfy { high.contains($0.owner) })
        XCTAssertFalse(state.units.contains { $0.kind == .mangonel }, "None in the first sixty watches, before any hall is so high")
    }
}
