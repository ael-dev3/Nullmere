import Foundation
import XCTest
@testable import NullmereCore

/// The Infirmary: a House's companies of war that fall are carried to the
/// nearest of its holds with a bed free, kept there until healed for half
/// what mustering them anew costs, and rise whole as the watch turns; a
/// hold that falls loses those in its beds.
final class InfirmaryTests: XCTestCase {
    /// A company of the House's falls where it stands.
    private func fell(_ kind: UnitKind, tier: Int = 1, experience: Int = 0, of house: Int, at hex: Hex,
                      in state: inout GameState) -> [GameEvent] {
        let id = state.put(kind, tier: tier, of: house, at: hex)
        state.units[state.unitIndex(id)!].experience = experience
        var events: [GameEvent] = []
        XCTAssertTrue(state.applyDamage(500, to: id, events: &events))
        return events
    }

    private func carried(_ events: [GameEvent]) -> [GameEvent] {
        events.filter { if case .carriedToInfirmary = $0 { return true } else { return false } }
    }

    /// A hold of the House's beside a hex.
    private func addHold(for house: Int, near hex: Hex, in state: inout GameState) throws -> Int {
        let site = try XCTUnwrap(state.map.hexes.first { candidate in
            (state.map[candidate]?.terrain.isSettleable ?? false) && candidate.distance(to: hex) <= 4 && state.isClear(candidate)
                && state.holds.allSatisfy { $0.position.distance(to: candidate) >= 3 }
        })
        let id = state.takeID()
        state.holds.append(Hold(id: id, name: "Stillmarch", owner: house, position: site, isSeat: false, foundedWatch: state.watch))
        return id
    }

    func testTheFallenAreCarriedToTheNearestFreeBed() throws {
        var state = Scene.world("infirmary beds", houses: 3, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let field = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        XCTAssertEqual(BuildingKind.infirmary.title, "Infirmary")
        XCTAssertEqual((1...5).map { Hold.beds(infirmaryLevel: $0) }, [2, 3, 4, 5, 6])
        XCTAssertEqual(Hold.beds(infirmaryLevel: 0), 0)
        XCTAssertEqual(BuildingKind.infirmary.effect(atLevel: 2), "Beds for 3 of the House's fallen companies of war")

        // With no Infirmary, the fallen are lost.
        var events = fell(.spear, of: me, at: field, in: &state)
        XCTAssertTrue(carried(events).isEmpty)
        XCTAssertNil(state.hold(seat.id)?.wounded)

        // With one, a company of war is carried to it as it was.
        state.holds[state.holdIndex(seat.id)!].levels[.infirmary] = 1
        events = fell(.spear, tier: 2, experience: 6, of: me, at: field, in: &state)
        XCTAssertEqual(carried(events), [.carriedToInfirmary(kind: .spear, owner: me, hold: seat.id)])
        XCTAssertEqual(events.first.map { if case .unitLost = $0 { return true } else { return false } }, true, "It falls all the same")
        XCTAssertEqual(state.hold(seat.id)?.wounded, [Wounded(kind: .spear, tier: 2, experience: 6, since: state.watch)])
        XCTAssertEqual(state.hold(seat.id)?.freeBeds, 1)
        XCTAssertEqual(state.tidings(of: carried(events)[0], for: me)?.text,
                       "Your fallen Spears are carried to the Infirmary at \(seat.name), to be healed there.")
        XCTAssertNil(state.tidings(of: carried(events)[0], for: 1))
        XCTAssertEqual(carried(state.events(events, heardBy: 1)), [], "Its own House's to hear")
        XCTAssertEqual(carried(state.events(events, heardBy: me)).count, 1)

        // A Founder is no company of war: lost.
        XCTAssertTrue(carried(fell(.founder, of: me, at: field, in: &state)).isEmpty)

        // The beds full, the next is lost.
        XCTAssertEqual(carried(fell(.bow, of: me, at: field, in: &state)).count, 1)
        XCTAssertEqual(state.hold(seat.id)?.freeBeds, 0)
        XCTAssertTrue(carried(fell(.bow, of: me, at: field, in: &state)).isEmpty)

        // Another hold with beds free takes the next; and the nearest of
        // two with beds free takes a company falling beside it.
        let near = try addHold(for: me, near: field, in: &state)
        state.holds[state.holdIndex(near)!].levels[.infirmary] = 1
        events = fell(.rider, of: me, at: field, in: &state)
        XCTAssertEqual(carried(events), [.carriedToInfirmary(kind: .rider, owner: me, hold: near)])
        state.holds[state.holdIndex(seat.id)!].levels[.infirmary] = 3
        let besideSeat = try XCTUnwrap(state.freeHex(near: seat.position))
        if besideSeat.distance(to: seat.position) < besideSeat.distance(to: try XCTUnwrap(state.hold(near)).position) {
            XCTAssertEqual(carried(fell(.spear, of: me, at: besideSeat, in: &state)), [.carriedToInfirmary(kind: .spear, owner: me, hold: seat.id)])
        }
        XCTAssertEqual(state.problems(), [])
    }

    func testHealingPaysHalfAndTheHealedRiseAsTheWatchTurns() throws {
        var state = Scene.world("infirmary healing", houses: 3, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.infirmary] = 2
        let field = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        _ = fell(.spear, tier: 2, experience: 6, of: me, at: field, in: &state)
        _ = fell(.bow, of: me, at: field, in: &state)
        let spear = try XCTUnwrap(state.hold(seat.id)?.wounded?.first)
        let bow = try XCTUnwrap(state.hold(seat.id)?.wounded?.last)
        let spearCost = state.healingCost(of: spear, for: me)
        XCTAssertEqual(spearCost, state.trainingCost(of: .spear, tier: 2, for: me).scaled(percent: 50), "Half what mustering it anew costs")
        XCTAssertEqual(state.healingCost(at: try XCTUnwrap(state.hold(seat.id))), spearCost + state.healingCost(of: bow, for: me))

        // Stores for one: the first carried in is healed first.
        state.houses[me].stock = spearCost
        let begun = try state.perform(.heal(hold: seat.id), as: me)
        XCTAssertEqual(begun, [.healingBegun(hold: seat.id, house: me, count: 1)])
        XCTAssertEqual(state.houses[me].stock, .zero)
        XCTAssertEqual(state.hold(seat.id)?.wounded?.map(\.healing), [true, false])
        XCTAssertEqual(state.tidings(of: begun[0], for: me)?.text, "The healers at \(seat.name) tend a company; they rise as the watch turns.")
        XCTAssertEqual(state.events(begun, heardBy: 1), [])
        XCTAssertThrowsError(try state.perform(.heal(hold: seat.id), as: me)) {
            XCTAssertEqual($0 as? RuleError, .shortOf(state.healingCost(of: bow, for: me)))
        }
        XCTAssertThrowsError(try state.perform(.heal(hold: seat.id), as: 1)) { XCTAssertEqual($0 as? RuleError, .notYours) }
        XCTAssertThrowsError(try state.perform(.heal(hold: 999_999), as: me)) { XCTAssertEqual($0 as? RuleError, .unknownHold) }
        state.houses[me].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 50)
        XCTAssertEqual(try state.perform(.heal(hold: seat.id), as: me), [.healingBegun(hold: seat.id, house: me, count: 1)])
        XCTAssertThrowsError(try state.perform(.heal(hold: seat.id), as: me)) { XCTAssertEqual($0 as? RuleError, .noneWounded) }
        XCTAssertEqual(RuleError.noneWounded.description, "No company lies in that hold's Infirmary waiting to be healed.")

        // As the watch turns they rise whole beside the seat, as they were.
        let before = Set(state.units(of: me).map(\.id))
        let turned = state.endWatch()
        let healed = turned.compactMap { event -> Int? in
            if case .unitHealed(let unit, let hold) = event, hold == seat.id { return unit }
            return nil
        }
        XCTAssertEqual(healed.count, 2)
        let risen = healed.compactMap(state.unit)
        XCTAssertEqual(risen.map(\.kind), [.spear, .bow])
        XCTAssertEqual(risen.map(\.tier), [2, 1])
        XCTAssertEqual(risen.map(\.experience), [6, 0], "Its rank kept")
        XCTAssertTrue(risen.allSatisfy { $0.health == 100 && $0.position.distance(to: seat.position) <= 3 && !before.contains($0.id) })
        XCTAssertNil(state.hold(seat.id)?.wounded)
        let rose = try XCTUnwrap(turned.first { if case .unitHealed = $0 { return true } else { return false } })
        XCTAssertEqual(state.tidings(of: rose, for: me)?.text, "Your Spears rise healed at \(seat.name).")
        XCTAssertEqual(state.events([rose], heardBy: me), [rose])
        XCTAssertEqual(state.events([rose], heardBy: 1), [])
        XCTAssertEqual(state.problems(), [])
    }

    func testAHealedCompanyWithNoRoomBesideItsHoldWaits() throws {
        var state = Scene.world("infirmary crowded", houses: 3, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.infirmary] = 1
        state.holds[index].wounded = [Wounded(kind: .spear, tier: 1, experience: 0, since: 0, healing: true)]
        // Every hex within three of the seat taken.
        var crowd: [Int] = []
        for hex in seat.position.spiral(3) where state.map[hex]?.terrain.isPassable == true && state.isClear(hex) && state.wild(at: hex) == nil {
            crowd.append(state.put(.lantern, of: 1, at: hex))
        }
        if state.unit(at: seat.position) == nil { crowd.append(state.put(.lantern, of: me, at: seat.position)) }
        XCTAssertEqual(state.raiseTheHealed(), [])
        XCTAssertEqual(state.hold(seat.id)?.wounded?.count, 1, "Still in its bed")
        state.units.removeAll { crowd.contains($0.id) }
        XCTAssertEqual(state.raiseTheHealed().count, 1)
        XCTAssertNil(state.hold(seat.id)?.wounded)
    }

    func testNoneIsCarriedIntoOrRisesFromAHoldUnderSiege() throws {
        var state = Scene.world("infirmary siege", houses: 3, radius: 18)
        let me = state.player, foe = 1
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.infirmary] = 2
        _ = try state.declareWar(by: foe, on: me)
        let gate = try XCTUnwrap(state.freeHex(near: seat.position))
        let besieger = state.put(.spear, of: foe, at: gate)
        XCTAssertTrue(state.isBesieged(try XCTUnwrap(state.hold(seat.id))))
        // A foe at its gates: none carried in, so the fallen is lost.
        let field = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        XCTAssertTrue(carried(fell(.spear, of: me, at: field, in: &state)).isEmpty)
        // Nor does a healed company rise there until the foe is gone.
        state.holds[index].wounded = [Wounded(kind: .bow, tier: 1, experience: 0, since: 0, healing: true)]
        XCTAssertEqual(state.raiseTheHealed(), [])
        state.units.removeAll { $0.id == besieger }
        XCTAssertFalse(state.isBesieged(try XCTUnwrap(state.hold(seat.id))))
        XCTAssertEqual(state.raiseTheHealed().count, 1)
        XCTAssertEqual(carried(fell(.spear, of: me, at: field, in: &state)).count, 1)
    }

    func testATakenHoldLosesThoseInItsBeds() throws {
        var state = Scene.world("infirmary taken", houses: 3, radius: 18)
        let rival = 1
        let outlying = try addHold(for: rival, near: try XCTUnwrap(state.seat(of: rival)).position, in: &state)
        let index = try XCTUnwrap(state.holdIndex(outlying))
        state.holds[index].levels[.infirmary] = 2
        state.holds[index].wounded = [Wounded(kind: .spear, tier: 1, experience: 0, since: 0),
                                      Wounded(kind: .bow, tier: 1, experience: 2, since: 0, healing: true)]
        state.holds[index].ward = 0
        let hold = try XCTUnwrap(state.hold(outlying))
        state.units.removeAll { $0.position == hold.position }
        let spot = try XCTUnwrap(state.freeHex(near: hold.position))
        let spear = state.put(.spear, of: state.player, at: spot)
        _ = try state.declareWar(by: state.player, on: rival)
        let events = try state.perform(.attack(unit: spear, target: hold.position), as: state.player)
        XCTAssertEqual(state.hold(outlying)?.owner, state.player)
        XCTAssertNil(state.hold(outlying)?.wounded)
        let lost = GameEvent.woundedLost(hold: outlying, house: rival, count: 2)
        XCTAssertTrue(events.contains(lost))
        let taken = try XCTUnwrap(events.firstIndex(of: .holdCaptured(hold: outlying, from: rival, by: state.player)))
        XCTAssertLessThan(taken, try XCTUnwrap(events.firstIndex(of: lost)), "Its taking told first")
        XCTAssertEqual(state.tidings(of: lost, for: rival)?.text, "The 2 companies in the Infirmary at \(hold.name) are lost with it.")
        XCTAssertEqual(state.tidings(of: .woundedLost(hold: outlying, house: rival, count: 1), for: rival)?.text,
                       "The company in the Infirmary at \(hold.name) are lost with it.")
        XCTAssertEqual(state.events([lost], heardBy: rival), [lost])
        XCTAssertEqual(state.events([lost], heardBy: 2), [])
        XCTAssertEqual(state.problems(), [])
    }

    func testOnlyItsOwnHouseKnowsWhoLiesInAHoldsBeds() throws {
        var state = Scene.world("infirmary view", houses: 3, radius: 18)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.infirmary] = 1
        state.holds[index].wounded = [Wounded(kind: .spear, tier: 1, experience: 0, since: 0)]
        XCTAssertEqual(state.view(for: me).hold(seat.id)?.wounded?.count, 1)
        XCTAssertNil(state.view(for: 1).hold(seat.id)?.wounded)
        XCTAssertEqual(state.view(for: 1).hold(seat.id)?.level(.infirmary), 1, "Its works are known to all")

        // Kept, and read back; a hold from before Infirmaries reads none.
        let data = try JSONEncoder().encode(state.holds[index])
        XCTAssertEqual(try JSONDecoder().decode(Hold.self, from: data), state.holds[index])
        let old = try Scene.without(["wounded"], in: state.holds[index])
        XCTAssertNil(try JSONDecoder().decode(Hold.self, from: old).wounded)
        state.holds[index].wounded = nil
        XCTAssertFalse(String(decoding: try JSONEncoder().encode(state.holds[index]), as: UTF8.self).contains("wounded"))

        // More in its beds than it has, or a company no Infirmary takes, is unsound.
        state.holds[index].wounded = Array(repeating: Wounded(kind: .spear, tier: 1, experience: 0, since: 0), count: 3)
        XCTAssertEqual(state.problems(), ["\(seat.name) keeps 3 wounded in 2 beds"])
        state.holds[index].wounded = [Wounded(kind: .founder, tier: 1, experience: 0, since: 0)]
        XCTAssertEqual(state.problems(), ["\(seat.name) keeps wounded Founders of tier 1"])
        state.holds[index].wounded = []
        XCTAssertEqual(state.problems(), ["\(seat.name) keeps 0 wounded in 2 beds"])
    }

    func testStewardsHealTheirFallenAndRaiseAnInfirmary() throws {
        var state = Scene.world("infirmary stewards", houses: 3, radius: 18)
        let steward = 2
        let seat = try XCTUnwrap(state.seat(of: steward))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.watch = 16
        for kind in BuildingKind.allCases where kind != .moonspire && kind != .infirmary {
            state.holds[index].levels[kind] = kind.maxLevel
        }
        state.houses[steward].stock = Stock(grain: 400, timber: 400, stone: 400, moonsalt: 40)
        _ = state.stewardTurn(for: steward)
        XCTAssertEqual(state.hold(seat.id)?.project?.kind, .infirmary, "Once it musters, an Infirmary at the seat")

        state.holds[index].project = nil
        state.holds[index].levels[.infirmary] = 1
        state.holds[index].wounded = [Wounded(kind: .spear, tier: 1, experience: 0, since: 15)]
        let events = state.stewardTurn(for: steward)
        XCTAssertTrue(events.contains(.healingBegun(hold: seat.id, house: steward, count: 1)))
        XCTAssertEqual(state.hold(seat.id)?.wounded?.map(\.healing), [true])
    }
}
