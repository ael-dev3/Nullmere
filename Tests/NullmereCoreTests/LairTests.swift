import Foundation
import XCTest
@testable import NullmereCore

/// Lairs of the wilds: raised by the realm far out in the country from the
/// twelfth watch, the later the higher; too strong for any company alone,
/// broken only by a rally's host striking together, its spoils shared by
/// the companies each House sent, gear for its caller, mending if it holds.
final class LairTests: XCTestCase {
    /// The keeper's House and House 1 sworn together; a lair of the
    /// Reavers a few tiles from the keeper's seat, on ground it has seen.
    private struct Stage {
        var state: GameState
        let me: Int
        let seat: Int
        let lair: Int

        var seatHex: Hex { state.hold(seat)!.position }
        var lairHex: Hex { state.lair(lair)!.position }
    }

    private func staged(_ seed: String = "lairs", level: Int = 1) throws -> Stage {
        var state = Scene.world(seed, houses: 4, radius: 18)
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Long Spear"), as: me)
        state.houses[1].isPlayer = true
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        _ = try state.perform(.answerInvitation(alliance: try XCTUnwrap(state.alliance(of: me)).id, accept: true), as: 1)
        let seat = try XCTUnwrap(state.seat(of: me))
        let spot = try XCTUnwrap(state.map.hexes.first { hex in
            (4...5).contains(hex.distance(to: seat.position)) && state.map[hex]?.terrain == .greyfield && state.isClear(hex)
                && state.wild(at: hex) == nil && state.site(at: hex) == nil && state.shrine(at: hex) == nil
                && state.holds.allSatisfy { $0.position.distance(to: hex) >= 4 }
                && state.path(for: Unit(id: -1, kind: .spear, owner: me, position: seat.position), to: hex) != nil
        })
        let lair = Lair(id: state.takeID(), kind: .reavers, level: level, position: spot, raised: state.watch)
        state.lairs = [lair]
        state.reveal(around: spot, range: 2, for: me)
        state.holds[state.holdIndex(seat.id)!].levels[.musterHall] = 1
        // The keeper's seat left clear for the companies gathering there:
        // its companies of war gone, its Lanterns sent off a way.
        state.units.removeAll { $0.owner == me && $0.kind.isMilitary }
        for index in state.units.indices where state.units[index].owner == me && state.units[index].position.distance(to: seat.position) <= 2 {
            state.units[index].position = try XCTUnwrap(state.freeHex(near: seat.position, within: 6...8))
        }
        state.houses[me].stock = Stock(grain: 20, timber: 20, stone: 20, moonsalt: 5)
        return Stage(state: state, me: me, seat: seat.id, lair: lair.id)
    }

    /// The world's part of a watch, without the stewards: moves restored,
    /// marches on, rallies gathered, marched and struck.
    @discardableResult
    private func turn(_ state: inout GameState) -> [GameEvent] {
        for index in state.units.indices {
            state.units[index].movesLeft = state.movement(of: state.units[index])
        }
        state.watch += 1
        var events: [GameEvent] = []
        for unit in state.units.sorted(by: { $0.id < $1.id }) where unit.destination != nil {
            events += state.march(unit.id)
        }
        return events + state.advanceRallies()
    }

    /// A company put near the keeper's seat, a step or two from its muster.
    @discardableResult
    private func company(_ kind: UnitKind, tier: Int = 1, of house: Int, in stage: inout Stage) throws -> Int {
        let spot = try XCTUnwrap(stage.state.freeHex(near: stage.seatHex, within: 1...2, avoiding: [.strand]))
        return stage.state.put(kind, tier: tier, of: house, at: spot)
    }

    private func assault(in events: [GameEvent]) -> LairAssault? {
        events.lazy.compactMap { event -> LairAssault? in
            if case .lairAssaulted(let assault) = event { return assault }
            return nil
        }.first
    }

    func testLairsRiseFarOutFromTheTwelfthWatchTheLaterTheHigher() throws {
        var state = Scene.world("lairs rising", houses: 6, radius: 24)
        state.raiseLairs()
        XCTAssertTrue(state.lairsStanding.isEmpty, "None before the twelfth watch")
        state.watch = GameState.lairsFrom
        state.raiseLairs()
        XCTAssertEqual(state.lairsStanding.count, 1)
        state.watch += 1
        state.raiseLairs()
        XCTAssertEqual(state.lairsStanding.count, 1, "One every few watches")
        state.watch = GameState.lairsFrom + GameState.lairEvery
        state.raiseLairs()
        XCTAssertEqual(state.lairsStanding.count, 2)
        state.watch += GameState.lairEvery
        state.raiseLairs()
        XCTAssertEqual(state.lairsStanding.count, 2, "Two for six seats")
        for lair in state.lairsStanding {
            XCTAssertTrue(state.holds.allSatisfy { $0.position.distance(to: lair.position) >= GameState.lairsFromHolds })
            XCTAssertTrue(state.holySites.allSatisfy { $0.position.distance(to: lair.position) >= GameState.lairsApart })
            XCTAssertEqual(state.map[lair.position]?.terrain.isWater, false)
            XCTAssertTrue((1...2).contains(lair.level), "Low early in the age")
            XCTAssertEqual(lair.strength, lair.might)
        }
        XCTAssertGreaterThanOrEqual(state.lairsStanding[0].position.distance(to: state.lairsStanding[1].position), GameState.lairsApart)
        XCTAssertEqual(state.problems(), [])
        // The same words, the same lairs.
        var again = Scene.world("lairs rising", houses: 6, radius: 24)
        again.watch = GameState.lairsFrom
        again.raiseLairs()
        XCTAssertEqual(again.lairsStanding.first?.position, state.lairsStanding.first?.position)
        // Late in the age they rise higher.
        var late = Scene.world("lairs rising", houses: 6, radius: 24)
        late.watch = GameState.lairsFrom + GameState.lairEvery * 40
        late.raiseLairs()
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(late.lairsStanding.first).level, 4)
        XCTAssertEqual(WildKind.allCases.map(\.lairTitle), ["Salt Hollow", "Reavers' Stockade", "Barrow Hall", "Hunters' Eyrie", "Drowned Chapel"])
        XCTAssertEqual((1...5).map { Lair.might(level: $0) }, [200, 450, 800, 1_250, 1_800])
    }

    func testNoCompanyAloneStrikesALairAndNoneWalksThroughIt() throws {
        var stage = try staged("lair alone")
        let me = stage.me
        let beside = try XCTUnwrap(stage.state.freeHex(near: stage.lairHex))
        let spear = stage.state.put(.spear, tier: 5, of: me, at: beside)
        XCTAssertEqual(stage.state.refusal(of: .attack(unit: spear, target: stage.lairHex), as: me), .lairNeedsRally)
        XCTAssertEqual(stage.state.refusal(of: .move(unit: spear, to: stage.lairHex), as: me), .lairNeedsRally)
        XCTAssertEqual(RuleError.lairNeedsRally.description, "Only a rally's host can break a lair: call one against it.")
        // A way past it goes round it, and nothing stands on it.
        let unit = try XCTUnwrap(stage.state.unit(spear))
        for hex in stage.lairHex.neighbors where hex != beside && stage.state.map[hex]?.terrain.isPassable == true {
            if let way = stage.state.path(for: unit, to: hex) {
                XCTAssertFalse(way.contains(stage.lairHex))
            }
        }
        XCTAssertTrue(stage.state.isOccupied(stage.lairHex))
        XCTAssertNil(stage.state.reach(of: unit)[stage.lairHex])
        // Known on ground explored, as a site is; to others, not yet.
        XCTAssertEqual(stage.state.view(for: me).lairsStanding.map(\.id), [stage.lair])
        let far = (me + 3) % stage.state.houses.count
        XCTAssertTrue(stage.state.view(for: far).lairsStanding.isEmpty)
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testARallyNeedsNoWarToStrikeALairButItsGroundKnown() throws {
        var stage = try staged("lair rallies")
        let me = stage.me
        XCTAssertNil(stage.state.refusal(of: .callRally(from: stage.seat, against: stage.lair, watches: 2), as: me), "No war needed")
        let stranger = 2
        var unknown = stage.state
        unknown.houses[stranger].isPlayer = true
        _ = try unknown.perform(.foundAlliance(name: "The Far Gate"), as: stranger)
        let theirs = try XCTUnwrap(unknown.seat(of: stranger))
        unknown.holds[unknown.holdIndex(theirs.id)!].levels[.musterHall] = 1
        XCTAssertEqual(unknown.refusal(of: .callRally(from: theirs.id, against: stage.lair, watches: 2), as: stranger), .unknownLair,
                       "A lair on ground they've never seen")
        var unsworn = Scene.world("lair unsworn", houses: 4, radius: 18)
        let seat = try XCTUnwrap(unsworn.seat(of: unsworn.player))
        unsworn.lairs = [Lair(id: unsworn.takeID(), kind: .drowned, level: 1, position: try XCTUnwrap(unsworn.freeHex(near: seat.position, within: 3...3)), raised: 0)]
        XCTAssertEqual(unsworn.refusal(of: .callRally(from: seat.id, against: unsworn.lairsStanding[0].id, watches: 2), as: unsworn.player), .notInAlliance)
        let called = try stage.state.perform(.callRally(from: stage.seat, against: stage.lair, watches: 2), as: me)
        XCTAssertEqual(stage.state.tidings(of: called[0], for: me)?.text,
                       "You call a rally at \(try XCTUnwrap(stage.state.hold(stage.seat)).name) against the Reavers' Stockade.")
        XCTAssertEqual(stage.state.targetName(stage.lair), "the Reavers' Stockade")
        XCTAssertEqual(stage.state.target(of: try XCTUnwrap(stage.state.ralliesStanding.first))?.owner, Rally.noHouse)
    }

    func testAHostBreaksALairAndSharesItsSpoilsByTheCompaniesEachSent() throws {
        var stage = try staged("lair broken")
        let me = stage.me, ally = 1
        _ = try stage.state.perform(.callRally(from: stage.seat, against: stage.lair, watches: 1), as: me)
        let rally = try XCTUnwrap(stage.state.ralliesStanding.first).id
        var sent: [Int] = []
        for _ in 0..<3 { sent.append(try company(.spear, tier: 5, of: me, in: &stage)) }
        sent.append(try company(.spear, tier: 5, of: ally, in: &stage))
        _ = try stage.state.perform(.joinRally(rally: rally, unit: sent[0]), as: me)
        _ = try stage.state.perform(.joinRally(rally: rally, unit: sent[1]), as: me)
        _ = try stage.state.perform(.joinRally(rally: rally, unit: sent[2]), as: me)
        _ = try stage.state.perform(.joinRally(rally: rally, unit: sent[3]), as: ally)
        let before = (mine: stage.state.houses[me].stock, theirs: stage.state.houses[ally].stock)
        let lair = try XCTUnwrap(stage.state.lair(stage.lair))
        var events: [GameEvent] = []
        for _ in 0..<8 where assault(in: events) == nil {
            events = turn(&stage.state)
        }
        let struck = try XCTUnwrap(assault(in: events), "The host strikes the lair")
        XCTAssertTrue(struck.broken)
        XCTAssertTrue((3...4).contains(struck.strikes.count), "Struck until it broke")
        XCTAssertEqual(struck.dealt, lair.might)
        XCTAssertEqual(struck.houses, [me, ally], "Its caller first")
        XCTAssertNil(stage.state.lair(stage.lair), "Broken, it is gone")
        XCTAssertTrue(stage.state.ralliesStanding.isEmpty)
        XCTAssertTrue(sent.allSatisfy { stage.state.unit($0)?.errand == nil }, "Back to their Houses' orders")
        // Its spoils, three parts to the keeper's House, one to its ally's.
        let mine = try XCTUnwrap(struck.shares.first { $0.house == me }).spoils
        let theirs = try XCTUnwrap(struck.shares.first { $0.house == ally }).spoils
        XCTAssertEqual(mine, lair.spoils.share(3, of: 4))
        XCTAssertEqual(theirs, lair.spoils.share(1, of: 4))
        XCTAssertEqual(stage.state.houses[me].stock, before.mine + mine)
        XCTAssertEqual(stage.state.houses[ally].stock, before.theirs + theirs)
        // Gear for its caller among the ruins, and the chronicle tells it.
        XCTAssertTrue(events.contains { if case .gearFound(me, _, .reavers) = $0 { return true } else { return false } })
        // Hourglasses for its caller, one a level; the Reavers' timber in a
        // cache for every House of the host.
        let given = events.filter { if case .itemsGiven = $0 { return true } else { return false } }
        XCTAssertEqual(given, [.itemsGiven(house: me, kind: .hourglass, count: lair.level), .itemsGiven(house: me, kind: .timberCache, count: 1),
                               .itemsGiven(house: ally, kind: .timberCache, count: 1)])
        let line = try XCTUnwrap(stage.state.chronicle.last)
        XCTAssertEqual(line.kind, .hunt)
        XCTAssertTrue(line.text.hasPrefix("A host of \(stage.state.houses[me].title) and \(stage.state.houses[ally].title) breaks the Reavers' Stockade of the first level"),
                      line.text)
        // Told to its host, and to those who saw it.
        let event = GameEvent.lairAssaulted(struck)
        XCTAssertEqual(stage.state.tidings(of: event, for: me)?.text,
                       "Your host breaks the Reavers' Stockade of the first level, and your House carries off \(mine).")
        XCTAssertEqual(stage.state.events([event], heardBy: ally), [event])
        let far = (me + 3) % stage.state.houses.count
        if !stage.state.visibility(for: far)[stage.state.map.index(of: struck.at)!] {
            XCTAssertEqual(stage.state.events([event], heardBy: far), [])
        }
        let told = try XCTUnwrap(stage.state.report(of: struck, id: 1, for: me))
        XCTAssertEqual(told.outcome, .won)
        XCTAssertEqual(told.title, "Your host broke the Reavers' Stockade of the first level")
        XCTAssertEqual(told.lines.filter { $0.hasPrefix("Your Spears") }.count, 3)
        XCTAssertEqual(told.lines.last, "It broke, and your House carried off \(mine)")
        XCTAssertNil(stage.state.report(of: struck, id: 1, for: far))
        XCTAssertEqual(HappeningKind.longHunt.points(for: event, in: stage.state)?.house, me)
        XCTAssertEqual(HappeningKind.longHunt.points(for: event, in: stage.state)?.points, 10)
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testALairThatHoldsStandsWoundedStrikesBackAndMends() throws {
        var stage = try staged("lair holds", level: 3)
        let me = stage.me
        _ = try stage.state.perform(.callRally(from: stage.seat, against: stage.lair, watches: 1), as: me)
        let rally = try XCTUnwrap(stage.state.ralliesStanding.first).id
        let spear = try company(.spear, of: me, in: &stage)
        _ = try stage.state.perform(.joinRally(rally: rally, unit: spear), as: me)
        var events: [GameEvent] = []
        for _ in 0..<8 where assault(in: events) == nil {
            events = turn(&stage.state)
        }
        let struck = try XCTUnwrap(assault(in: events))
        XCTAssertFalse(struck.broken)
        XCTAssertEqual(struck.strikes.first?.taken, stage.state.bodily(try XCTUnwrap(stage.state.lair(stage.lair)).blowBack,
                                                                      on: Unit(id: 0, kind: .spear, owner: me, position: .origin)),
                       "Struck back from beside it")
        XCTAssertTrue(struck.shares.allSatisfy { $0.spoils.isZero })
        let standing = try XCTUnwrap(stage.state.lair(stage.lair))
        XCTAssertEqual(standing.strength, struck.strength)
        XCTAssertLessThan(standing.strength, standing.might)
        XCTAssertEqual(stage.state.tidings(of: .lairAssaulted(struck), for: me)?.text,
                       "Your host strikes the Reavers' Stockade of the third level for \(struck.dealt); it holds, \(struck.strength) of 800 still standing.")
        XCTAssertEqual(stage.state.report(of: struck, id: 2, for: me)?.outcome, .held)
        XCTAssertNil(HappeningKind.longHunt.points(for: .lairAssaulted(struck), in: stage.state))
        // As the watch turns it mends a twentieth of its might.
        stage.state.watch = GameState.lairsFrom + 1
        stage.state.raiseLairs()
        XCTAssertEqual(stage.state.lair(stage.lair)?.strength, min(800, struck.strength + 40))
    }

    func testAStewardRalliesOnALairItKnowsWithCompaniesToSpare() throws {
        var state = Scene.world("steward lairs", houses: 4, radius: 18)
        let steward = 2
        _ = try state.perform(.foundAlliance(name: "The Wild Hunt"), as: steward)
        state.watch = 20
        let seat = try XCTUnwrap(state.seat(of: steward))
        state.holds[state.holdIndex(seat.id)!].levels[.musterHall] = 1
        state.houses[steward].temperament = .ambitious
        let spot = try XCTUnwrap(state.freeHex(near: seat.position, within: 5...6, avoiding: [.strand]))
        state.lairs = [Lair(id: state.takeID(), kind: .barrowkin, level: 1, position: spot, raised: 0)]
        state.reveal(around: spot, range: 1, for: steward)
        for _ in 0..<5 { _ = state.put(.spear, of: steward, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))) }
        var called = false
        for _ in 0..<40 where !called {
            let events = state.stewardTurn(for: steward)
            called = events.contains { if case .rallyCalled(_, steward, state.lairsStanding[0].id) = $0 { return true } else { return false } }
        }
        XCTAssertTrue(called, "Sooner or later it rallies on the lair")
        let rally = try XCTUnwrap(state.ralliesStanding.first { $0.caller == steward })
        XCTAssertEqual(rally.target, state.lairsStanding[0].id)
        _ = state.stewardTurn(for: steward)
        XCTAssertFalse(try XCTUnwrap(state.rally(rally.id)).companies.isEmpty, "And sends companies to it")
    }
}
