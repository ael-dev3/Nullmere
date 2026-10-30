import Foundation
import XCTest
@testable import NullmereCore

/// Scouting: Lanterns within two tiles of another House's hold scout it for
/// their moves, and bring back what they saw there: the companies at its
/// gates and who leads them, its ward, what it raises and musters, the
/// stores its taking would carry off, and how many lie in its beds. The
/// hold's House hears it was watched.
final class ScoutTests: XCTestCase {
    func testLanternsScoutAHoldAndItsHouseHearsOfIt() throws {
        var state = Scene.world("scouted", houses: 4, radius: 18)
        let me = state.player, foe = 1, ally = 2
        let seat = try XCTUnwrap(state.seat(of: foe))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.units.removeAll { $0.position.distance(to: seat.position) <= 1 }
        // Its garrison: a hardened spear led by a commander on the seat, a
        // bow at its gates, and an ally's spear keeping them.
        let spear = state.put(.spear, tier: 3, of: foe, at: seat.position, health: 80)
        state.units[state.unitIndex(spear)!].experience = 5
        let commander = try XCTUnwrap(state.commanders(of: foe).first)
        state.units[state.unitIndex(spear)!].leader = commander.id
        let gates = seat.position.neighbors.filter { state.map[$0]?.terrain.isPassable == true && state.isClear($0) && state.wild(at: $0) == nil }
        XCTAssertGreaterThanOrEqual(gates.count, 2)
        state.put(.bow, of: foe, at: gates[0])
        _ = try state.perform(.foundAlliance(name: "The Shut Gate"), as: foe)
        state.houses[ally].isPlayer = true
        _ = try state.perform(.inviteToAlliance(house: ally), as: foe)
        _ = try state.perform(.answerInvitation(alliance: try XCTUnwrap(state.alliance(of: foe)).id, accept: true), as: ally)
        state.put(.spear, of: ally, at: gates[1])
        // Under way: walls rising, riders mustering; one lying in its beds.
        state.holds[index].project = Hold.Project(kind: .walls, targetLevel: 2, watchesLeft: 3)
        state.holds[index].training = Hold.Training(kind: .rider, watchesLeft: 2, tier: 2)
        state.holds[index].levels[.infirmary] = 1
        state.holds[index].wounded = [Wounded(kind: .bow, tier: 1, experience: 0, since: 0)]
        state.holds[index].ward = 40
        state.houses[foe].stock = Stock(grain: 100, timber: 60, stone: 40, moonsalt: 10)
        let spot = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...2))
        let lantern = state.put(.lantern, of: me, at: spot)

        let events = try state.perform(.scout(unit: lantern, hold: seat.id), as: me)
        guard case .holdScouted(let report)? = events.first else { return XCTFail("A report: \(events)") }
        XCTAssertEqual(events.last, .scoutSeen(hold: seat.id, by: me))
        XCTAssertEqual(report.hold, seat.id)
        XCTAssertEqual(report.owner, foe)
        XCTAssertEqual(report.by, me)
        XCTAssertEqual(report.watch, state.watch)
        XCTAssertEqual(report.garrison, [
            ScoutReport.Company(kind: .spear, tier: 3, health: 80, rank: 2, owner: foe, commander: commander.name),
            ScoutReport.Company(kind: .bow, tier: 1, health: 100, rank: 0, owner: foe, commander: nil),
            ScoutReport.Company(kind: .spear, tier: 1, health: 100, rank: 0, owner: ally, commander: nil),
        ])
        XCTAssertEqual(report.ward, 40)
        XCTAssertEqual(report.maximumWard, state.hold(seat.id)?.maximumWard)
        XCTAssertEqual(report.project?.kind, .walls)
        XCTAssertEqual(report.training?.kind, .rider)
        XCTAssertEqual(report.spoils, Stock(grain: 50, timber: 30, stone: 20, moonsalt: 5), "Half a seat's stores")
        XCTAssertEqual(report.spoils, state.spoils(ofTaking: try XCTUnwrap(state.hold(seat.id))))
        XCTAssertEqual(report.wounded, 1)
        XCTAssertEqual(state.unit(lantern)?.movesLeft, 0, "For all its moves")

        // Each House hears its part: the report its own, the watching the hold's.
        XCTAssertEqual(state.events(events, heardBy: me), [events[0]])
        XCTAssertEqual(state.events(events, heardBy: foe), [events[1]])
        XCTAssertEqual(state.events(events, heardBy: ally), [])
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "Your Lanterns scout \(seat.name): 3 companies at its gates, its ward 40 of \(report.maximumWard).")
        XCTAssertEqual(state.tidings(of: events[1], for: foe)?.text, "Lanterns of \(state.houses[me].title) watch \(seat.name).")
        XCTAssertEqual(state.tidings(of: events[1], for: foe)?.tone, .bad)
        XCTAssertNil(state.tidings(of: events[0], for: foe))

        // As the Chronicle's reports tell it.
        let told = try XCTUnwrap(state.report(of: report, id: 7, for: me))
        XCTAssertEqual(told.outcome, .scouted)
        XCTAssertEqual(told.title, "Your Lanterns scouted \(seat.name), \(state.houses[foe].title)'s seat")
        XCTAssertEqual(told.place, "at \(seat.name)")
        XCTAssertEqual(told.lines, [
            "At its gates: Spears III, 80 strong, Hardened, led by \(commander.name); Bows I; Spears I of \(state.houses[ally].title)",
            "Its ward 40 of \(report.maximumWard)",
            "Raising Walls II, 3 watches left",
            "Mustering Riders II, 2 watches left",
            "Its taking would carry off 50 grain, 30 timber, 20 stone, 5 moonsalt",
            "1 lies in its Infirmary",
        ])
        XCTAssertNil(state.report(of: report, id: 7, for: foe), "Its House reads no report of it")

        // The report comes through the wire whole.
        let back = try JSONDecoder().decode(GameEvent.self, from: try JSONEncoder().encode(events[0]))
        XCTAssertEqual(back, events[0])
    }

    func testOnlyLanternsWithinReachAndWithMovesScoutAnothersHold() throws {
        var state = Scene.world("scouting refused", houses: 3, radius: 18)
        let me = state.player, foe = 1
        let theirs = try XCTUnwrap(state.seat(of: foe))
        let mine = try XCTUnwrap(state.seat(of: me))
        let near = try XCTUnwrap(state.freeHex(near: theirs.position, within: 1...2))
        let far = try XCTUnwrap(state.freeHex(near: theirs.position, within: 3...4))
        let lantern = state.put(.lantern, of: me, at: near)
        let distant = state.put(.lantern, of: me, at: far)
        let spear = state.put(.spear, of: me, at: try XCTUnwrap(state.freeHex(near: theirs.position, within: 2...2)))
        func refused(_ command: Command, as house: Int = me) -> RuleError? { state.refusal(of: command, as: house) }
        XCTAssertEqual(refused(.scout(unit: spear, hold: theirs.id)), .notAScout)
        XCTAssertEqual(refused(.scout(unit: distant, hold: theirs.id)), .outOfReach)
        XCTAssertEqual(refused(.scout(unit: lantern, hold: mine.id)), .ownHold)
        XCTAssertEqual(refused(.scout(unit: lantern, hold: 987_654)), .unknownHold)
        XCTAssertEqual(refused(.scout(unit: lantern, hold: theirs.id), as: foe), .notYours)
        XCTAssertNil(refused(.scout(unit: lantern, hold: theirs.id)), "At peace or at war alike")
        _ = try state.perform(.scout(unit: lantern, hold: theirs.id), as: me)
        XCTAssertEqual(refused(.scout(unit: lantern, hold: theirs.id)), .noMovesLeft)
        XCTAssertEqual(RuleError.notAScout.description, "Only Lanterns scout.")
        XCTAssertEqual(RuleError.ownHold.description, "That hold is your own.")
        XCTAssertEqual(GameState.scoutReach, 2)
    }

    func testAnOutlyingHoldsSpoilsAreItsShareAndAnEmptyOnesSaySo() throws {
        var state = Scene.world("scouted outlying", houses: 3, radius: 18)
        let me = state.player, foe = 1
        let seat = try XCTUnwrap(state.seat(of: foe))
        let site = try XCTUnwrap(state.map.hexes.first { hex in
            (state.map[hex]?.terrain.isSettleable ?? false) && hex.distance(to: seat.position) == 5 && state.isClear(hex)
                && state.holds.allSatisfy { $0.position.distance(to: hex) >= 3 }
        })
        let id = state.takeID()
        state.holds.append(Hold(id: id, name: "Stillmarch", owner: foe, position: site, isSeat: false, foundedWatch: state.watch))
        state.houses[foe].stock = Stock(grain: 90, timber: 30)
        state.units.removeAll { $0.position.distance(to: site) <= 1 }
        let lantern = state.put(.lantern, of: me, at: try XCTUnwrap(state.freeHex(near: site, within: 2...2)))
        let events = try state.perform(.scout(unit: lantern, hold: id), as: me)
        guard case .holdScouted(let report)? = events.first else { return XCTFail("A report") }
        XCTAssertEqual(report.spoils, Stock(grain: 45, timber: 15), "Its share: one of two holds")
        XCTAssertEqual(report.garrison, [])
        let told = try XCTUnwrap(state.report(of: report, id: 1, for: me))
        XCTAssertEqual(told.title, "Your Lanterns scouted Stillmarch, a hold of \(state.houses[foe].title)")
        XCTAssertEqual(told.lines.first, "No company at its gates")
        XCTAssertFalse(told.lines.contains { $0.hasPrefix("Raising") || $0.hasPrefix("Mustering") || $0.contains("Infirmary") })
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "Your Lanterns scout Stillmarch: no company at its gates, its ward \(report.ward) of \(report.maximumWard).")
    }

    func testAStewardsLanternsScoutAFoesHoldNowAndThen() throws {
        var state = Scene.world("steward scouts", houses: 3, radius: 18)
        let me = state.player, steward = 2
        _ = try state.declareWar(by: steward, on: me)
        let mine = try XCTUnwrap(state.seat(of: me))
        state.units.removeAll { $0.owner == steward }
        let lantern = state.put(.lantern, of: steward, at: try XCTUnwrap(state.freeHex(near: mine.position, within: 2...2)))
        // On its watch: it scouts the hold before going on its way.
        state.watch = RivalMind.scoutEvery * 10 - lantern % RivalMind.scoutEvery
        let events = state.stewardTurn(for: steward)
        XCTAssertTrue(events.contains(.scoutSeen(hold: mine.id, by: steward)), "\(events)")
        XCTAssertEqual(state.unit(lantern)?.movesLeft, 0)
        // Off it, it explores as ever.
        var again = Scene.world("steward scouts", houses: 3, radius: 18)
        _ = try again.declareWar(by: steward, on: me)
        again.units.removeAll { $0.owner == steward }
        let other = again.put(.lantern, of: steward, at: try XCTUnwrap(again.freeHex(near: mine.position, within: 2...2)))
        again.watch = RivalMind.scoutEvery * 10 - other % RivalMind.scoutEvery + 1
        XCTAssertFalse(again.stewardTurn(for: steward).contains(.scoutSeen(hold: mine.id, by: steward)))
    }
}
