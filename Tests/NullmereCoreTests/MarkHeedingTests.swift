import Foundation
import XCTest
@testable import NullmereCore

/// A keeper's alliance marks bid its steward allies, not only its keepers:
/// a steward sworn to an alliance a keeper leads strikes the hold its
/// leader marks to strike, waits where its leader marks to gather or to
/// hold, and keeps its hunting and its gathering clear of ground marked to
/// beware. No caretaker heeds them, nor any steward where a steward leads.
final class MarkHeedingTests: XCTestCase {
    /// A keeper's House leading an alliance with a steward's House sworn to
    /// it, at war with a third House that keeps a second hold farther from
    /// the steward than its seat; every House knowing the whole map.
    private func sworn(_ seed: String = "marks heeded") throws -> (GameState, me: Int, ally: Int, foe: Int, far: Hold) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 6, radius: 20, keepers: 1))
        let me = state.player
        let others = state.houses.indices.filter { $0 != me }
        let ally = others[0], foe = others[1]
        for house in state.houses.indices { state.houses[house].explored = Explored(repeating: true, count: state.map.count) }
        _ = try state.perform(.foundAlliance(name: "Lantern Oath"), as: me)
        let index = try XCTUnwrap(state.alliances?.firstIndex { $0.leader == me })
        state.alliances![index].members.append(ally)
        _ = try state.perform(.declareWar(on: foe), as: ally)
        XCTAssertTrue(state.isAtWar(ally, foe))
        let allySeat = try XCTUnwrap(state.seat(of: ally)).position
        let foeSeat = try XCTUnwrap(state.seat(of: foe)).position
        let ground = try XCTUnwrap(state.map.hexes.filter { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && hex.distance(to: allySeat) > foeSeat.distance(to: allySeat) + 4
        }.min { ($0.distance(to: foeSeat), $0.q, $0.r) < ($1.distance(to: foeSeat), $1.q, $1.r) })
        let far = Hold(id: state.takeID(), name: "Farmere", owner: foe, position: ground, isSeat: false, foundedWatch: state.watch)
        state.holds.append(far)
        return (state, me, ally, foe, far)
    }

    func testAStewardSwornToAKeeperStrikesTheHoldItsLeaderMarks() throws {
        var (state, me, ally, foe, far) = try sworn()
        let foeSeat = try XCTUnwrap(state.seat(of: foe)).position
        XCTAssertEqual(RivalMind(house: ally).siegePlan(in: state)?.target, foeSeat, "Unbidden, it goes for the nearer seat")
        _ = try state.perform(.markGround(far.position, .strike, words: "Burn it"), as: me)
        XCTAssertEqual(RivalMind(house: ally).siegePlan(in: state)?.target, far.position, "Bidden, for the hold its leader marked")
        // Answering it as the watch's orders are given, the alliance is told, once.
        var turned = state
        let told = turned.stewardTurn(for: ally)
        let answered = try XCTUnwrap(turned.marksSeen(by: me).first { $0.at == far.position })
        XCTAssertEqual(answered.heededBy, [ally])
        XCTAssertTrue(told.contains(.markHeeded(answered, by: ally)))
        XCTAssertEqual(turned.tidings(of: .markHeeded(answered, by: ally), for: me)?.text,
                       "\(turned.houses[ally].title) answers the alliance's mark at Farmere (Strike here): its host makes for Farmere.")
        XCTAssertEqual(turned.events([.markHeeded(answered, by: ally)], heardBy: foe), [], "Its foe hears nothing of it")
        XCTAssertFalse(turned.stewardTurn(for: ally).contains { event in
            if case .markHeeded = event { return true } else { return false }
        }, "Told once")
        // The newest strike mark first.
        _ = try state.perform(.markGround(foeSeat, .strike, words: nil), as: me)
        XCTAssertEqual(RivalMind(house: ally).siegePlan(in: state)?.target, foeSeat)
        // A mark on a hold of a House it is at peace with bids it nothing.
        let friend = try XCTUnwrap(state.houses.indices.first { $0 != me && $0 != ally && $0 != foe && !state.isAtWar(ally, $0) })
        var peaceful = state
        peaceful.allianceMarks = nil
        _ = try peaceful.perform(.markGround(try XCTUnwrap(peaceful.seat(of: friend)).position, .strike, words: nil), as: me)
        XCTAssertEqual(RivalMind(house: ally).siegePlan(in: peaceful)?.target, foeSeat)
    }

    func testOnlyAStewardSwornToAKeeperHeedsAndNeverItsCaretaker() throws {
        var (state, me, ally, _, far) = try sworn()
        _ = try state.perform(.markGround(far.position, .strike, words: nil), as: me)
        XCTAssertEqual(RivalMind(house: ally).leadersMarks(in: state).map(\.at), [far.position])
        XCTAssertEqual(RivalMind(house: me).leadersMarks(in: state), [], "Its leader bids, and does not heed")
        XCTAssertEqual(RivalMind(house: ally, caretaking: true).leadersMarks(in: state), [], "A caretaker begins nothing")
        var stewardLed = state
        stewardLed.houses[me].isPlayer = false
        XCTAssertEqual(RivalMind(house: ally).leadersMarks(in: stewardLed), [], "Where a steward leads, none")
        let outsider = try XCTUnwrap(state.houses.indices.first { $0 != me && state.alliance(of: $0) == nil })
        XCTAssertEqual(RivalMind(house: outsider).leadersMarks(in: state), [], "Nor any House outside the alliance")
    }

    func testAStewardSwornToAKeeperWaitsWhereItsLeaderMarksToGather() throws {
        var (state, me, ally, foe, _) = try sworn()
        // At peace again, with no wilds about, its companies idle by its
        // seat: one keeping its gates, the others free.
        state.setStance(.peace, between: ally, and: foe, by: ally)
        state.wilds = nil
        let seat = try XCTUnwrap(state.seat(of: ally)).position
        for _ in 0..<2 { XCTAssertNotNil(state.placeUnit(.spear, tier: 1, for: ally, near: seat)) }
        let gather = try XCTUnwrap(seat.spiral(6).first { hex in
            hex.distance(to: seat) == 6 && state.map[hex]?.terrain.isPassable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
        })
        func nearest(_ world: GameState, to hex: Hex) -> Int {
            world.units(of: ally).filter(\.kind.isMilitary).map { ($0.destination ?? $0.position).distance(to: hex) }.min() ?? .max
        }
        let before = nearest(state, to: gather)
        var unbidden = state
        _ = unbidden.stewardTurn(for: ally)
        XCTAssertGreaterThanOrEqual(nearest(unbidden, to: gather), before - 1, "Unbidden, none makes for it")
        _ = try state.perform(.markGround(gather, .gather, words: "Here"), as: me)
        var bidden = state
        _ = bidden.stewardTurn(for: ally)
        XCTAssertLessThanOrEqual(nearest(bidden, to: gather), 1, "Bidden, a company free of its gates is bound for the mark")
        XCTAssertEqual(bidden.marksSeen(by: me).first?.heededBy, [ally], "and the alliance told it answers")
        XCTAssertEqual(bidden.tidings(of: .markHeeded(try XCTUnwrap(bidden.marksSeen(by: me).first), by: ally), for: me)?.text,
                       "\(bidden.houses[ally].title) answers the alliance's mark \(bidden.placeName(of: gather)) (Gather here): its companies gather there.")
        // Beyond its reach, a mark bids it nothing.
        var beyond = state
        beyond.allianceMarks = nil
        let distant = try XCTUnwrap(beyond.map.hexes.first { hex in
            hex.distance(to: seat) > RivalMind.markReach + 3 && beyond.map[hex]?.terrain.isPassable == true && beyond.hold(at: hex) == nil
        })
        _ = try beyond.perform(.markGround(distant, .gather, words: nil), as: me)
        var still = beyond
        _ = still.stewardTurn(for: ally)
        XCTAssertGreaterThan(nearest(still, to: distant), 1)
    }

    func testAStewardSwornToAKeeperHuntsAndGathersClearOfGroundMarkedToBeware() throws {
        var (state, me, ally, _, _) = try sworn()
        let seat = try XCTUnwrap(state.seat(of: ally)).position
        let company = try XCTUnwrap(state.units(of: ally).first { $0.kind.isMilitary })
        let mind = RivalMind(house: ally)
        // A lone wild of the least kind near its seat, which it would hunt.
        state.wilds = nil
        let den = try XCTUnwrap(company.position.spiral(3).first { hex in
            hex.distance(to: company.position) == 3 && state.map[hex]?.terrain.isPassable == true
                && state.hold(at: hex) == nil && state.unit(at: hex) == nil
        })
        state.wilds = [Wild(id: state.takeID(), kind: WildKind.allCases[0], level: 1, position: den, raised: state.watch)]
        XCTAssertEqual(mind.prey(for: company, in: state), den, "Unbidden, it hunts the wild")
        var wary = state
        _ = try wary.perform(.markGround(den, .beware, words: "Wolves"), as: me)
        XCTAssertTrue(mind.bewares(den, in: wary))
        XCTAssertNil(mind.prey(for: company, in: wary), "Bidden to beware, it hunts no wild there")
        // Nor works a site there, short of every store as it is: a field
        // of grain found four tiles from its seat, with a company of war
        // beside it.
        var poor = state
        poor.houses[ally].stock = Stock.zero
        func open(_ hex: Hex) -> Bool {
            poor.map[hex]?.terrain.isSettleable == true && poor.hold(at: hex) == nil && poor.unit(at: hex) == nil && poor.site(at: hex) == nil
        }
        let field = try XCTUnwrap(seat.spiral(4).first { $0.distance(to: seat) == 4 && open($0) })
        poor.sites = [Site(id: poor.takeID(), store: .grain, level: 1, position: field, found: poor.watch)]
        let beside = try XCTUnwrap(field.neighbors.first(where: open))
        let worker = try XCTUnwrap(poor.placeUnit(.spear, tier: 1, for: ally, near: beside))
        let siteID = try XCTUnwrap(mind.site(for: worker, in: poor), "A site by its company it would work")
        let site = try XCTUnwrap(poor.sitesInLand.first { $0.id == siteID })
        _ = try poor.perform(.markGround(site.position, .beware, words: nil), as: me)
        XCTAssertNotEqual(mind.site(for: worker, in: poor), siteID, "Bidden to beware, it works no site there")
        // Its berth: ground two tiles off the mark is within it, three is not.
        let two = site.position.spiral(RivalMind.bewareBerth).first { $0.distance(to: site.position) == RivalMind.bewareBerth }!
        let three = site.position.spiral(RivalMind.bewareBerth + 1).first { $0.distance(to: site.position) == RivalMind.bewareBerth + 1 }!
        XCTAssertTrue(mind.bewares(two, in: poor))
        XCTAssertFalse(mind.bewares(three, in: poor))
        XCTAssertFalse(RivalMind(house: ally, caretaking: true).bewares(site.position, in: poor), "A caretaker heeds no mark")
    }
}
