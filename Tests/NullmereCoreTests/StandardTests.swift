import Foundation
import XCTest
@testable import NullmereCore

/// Alliance land: a House of an alliance raises a standard on open land
/// near the alliance's holds or standards, for its stores; the land about
/// it is the alliance's, where its companies stand firmer, mend sooner and
/// gather more. A House at war with the one that raised it strikes its
/// ward and tears it down; a House gone from the alliance takes its down.
final class StandardTests: XCTestCase {
    private struct Stage {
        var state: GameState
        let me: Int
        let ally: Int
        let seat: Hold
    }

    private func staged(_ seed: String = "standards") throws -> Stage {
        var state = Scene.world(seed, houses: 4, radius: 18)
        let me = state.player, ally = 1
        _ = try state.perform(.foundAlliance(name: "The Raised Banner"), as: me)
        state.houses[ally].isPlayer = true
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: try XCTUnwrap(state.alliance(of: me)).id, accept: true), as: ally)
        state.houses[me].stock = Stock(grain: 200, timber: 300, stone: 300, moonsalt: 20)
        let seat = try XCTUnwrap(state.seat(of: me))
        state.reveal(around: seat.position, range: 6, for: me)
        return Stage(state: state, me: me, ally: ally, seat: seat)
    }

    /// Open land a few tiles from the keeper's seat.
    private func ground(near hex: Hex, within: ClosedRange<Int> = 2...3, in state: GameState) throws -> Hex {
        try XCTUnwrap(hex.spiral(within.upperBound).first { candidate in
            within.contains(candidate.distance(to: hex)) && state.map[candidate].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
                && !state.isOccupied(candidate) && state.site(at: candidate) == nil && state.shrine(at: candidate) == nil
        })
    }

    func testAStandardIsRaisedNearTheAlliancesHoldsAndItsLandIsTheAlliances() throws {
        var stage = try staged()
        let me = stage.me
        let spot = try ground(near: stage.seat.position, in: stage.state)
        let before = stage.state.houses[me].stock
        let events = try stage.state.perform(.raiseStandard(at: spot), as: me)
        let standard = try XCTUnwrap(stage.state.standard(at: spot))
        XCTAssertEqual(events, [.standardRaised(standard: standard.id, alliance: standard.alliance, house: me, at: spot)])
        XCTAssertEqual(stage.state.houses[me].stock + Standard.cost, before, "For its stores")
        XCTAssertEqual(standard.ward, Standard.maximumWard)
        let alliance = try XCTUnwrap(stage.state.alliance(of: me))
        XCTAssertEqual(stage.state.allianceLand(at: spot), alliance.id)
        XCTAssertEqual(stage.state.allianceLand(at: try XCTUnwrap(spot.ring(Standard.reach).first)), alliance.id)
        XCTAssertNil(stage.state.allianceLand(at: try XCTUnwrap(spot.ring(Standard.reach + 1).first)), "Two tiles each way")
        XCTAssertTrue(stage.state.isOccupied(spot), "Nothing rises on it")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: me)?.text,
                       "You raise a standard of The Raised Banner \(stage.state.placeName(of: spot)); the land about it is your alliance's.")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: stage.ally)?.tone, .good)
        XCTAssertEqual(stage.state.events(events, heardBy: stage.ally), events, "Its alliance hears it")
        XCTAssertEqual(stage.state.view(for: me).standardsStanding.count, 1)
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testAStandardIsRaisedOnlyWhereItMay() throws {
        var stage = try staged("standards refused")
        let me = stage.me
        func refused(_ hex: Hex, as house: Int? = nil) -> RuleError? { stage.state.refusal(of: .raiseStandard(at: hex), as: house ?? me) }
        let near = try ground(near: stage.seat.position, in: stage.state)
        XCTAssertNil(refused(near))
        XCTAssertEqual(refused(near, as: 3), .notInAlliance)
        XCTAssertEqual(refused(stage.seat.position), .standardGround, "Not on a hold")
        let far = try XCTUnwrap(stage.state.map.hexes.first { hex in
            hex.distance(to: stage.seat.position) >= 6 && stage.state.isExplored(hex, by: me)
                && stage.state.holds.allSatisfy { $0.position.distance(to: hex) > Standard.tether }
                && stage.state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !stage.state.isOccupied(hex)
                && stage.state.site(at: hex) == nil && stage.state.shrine(at: hex) == nil
        })
        XCTAssertEqual(refused(far), .standardTooFar)
        let unknown = try XCTUnwrap(stage.state.map.hexes.first { !stage.state.isExplored($0, by: me) })
        XCTAssertEqual(refused(unknown), .unexplored)
        // Beside another House's hold, it is theirs.
        let theirs = try XCTUnwrap(stage.state.seat(of: 2))
        stage.state.reveal(around: theirs.position, range: 3, for: me)
        let beside = try ground(near: theirs.position, within: 2...2, in: stage.state)
        var reaching = stage.state
        reaching.standards = [Standard(id: reaching.takeID(), alliance: try XCTUnwrap(reaching.alliance(of: me)).id, raisedBy: me,
                                       position: try ground(near: beside, within: 3...4, in: reaching), raised: 0)]
        XCTAssertEqual(reaching.refusal(of: .raiseStandard(at: beside), as: me), .foreignTerritory)
        // Short of stores, or with as many standards as the alliance may keep.
        var poor = stage.state
        poor.houses[me].stock = .zero
        XCTAssertEqual(poor.refusal(of: .raiseStandard(at: near), as: me), .shortOf(Standard.cost))
        var many = stage.state
        let alliance = try XCTUnwrap(many.alliance(of: me)).id
        XCTAssertEqual(Standard.allowed(members: 2), 3)
        many.standards = (0..<3).map { Standard(id: 900 + $0, alliance: alliance, raisedBy: me, position: Hex(50 + $0, 0), raised: 0) }
        XCTAssertEqual(many.refusal(of: .raiseStandard(at: near), as: me), .standardsEnough)
        XCTAssertEqual(Standard.allowed(members: 30), 8, "Eight at most")
        XCTAssertEqual(RuleError.standardTooFar.description, "A standard stands within four tiles of your alliance's holds or standards.")
    }

    func testOnItsLandTheAlliancesCompaniesStandFirmerMendSoonerAndGatherMore() throws {
        var stage = try staged("standards land")
        let me = stage.me
        let spot = try ground(near: stage.seat.position, in: stage.state)
        let beside = try ground(near: spot, within: 1...1, in: stage.state)
        let spear = stage.state.put(.spear, of: me, at: beside, health: 50)
        let foe = stage.state.put(.spear, of: 3, at: try ground(near: beside, within: 1...1, in: stage.state))
        let unit = try XCTUnwrap(stage.state.unit(spear))
        let attacker = try XCTUnwrap(stage.state.unit(foe))
        let bare = stage.state.strengths(of: attacker, against: unit, at: beside).defense
        let rate = stage.state.gatheringRate(of: unit, for: .grain)
        XCTAssertFalse(stage.state.isOnOwnLand(unit))
        _ = try stage.state.perform(.raiseStandard(at: spot), as: me)
        XCTAssertTrue(stage.state.isOnOwnLand(unit))
        let held = stage.state.strengths(of: attacker, against: unit, at: beside).defense
        XCTAssertGreaterThan(held, bare, "Firmer on its own land")
        XCTAssertEqual(stage.state.gatheringRate(of: unit, for: .grain), rate * (100 + Standard.gathering) / 100)
        XCTAssertFalse(stage.state.isOnOwnLand(attacker), "Not the foe's land")
        // Mends five more each watch there.
        var resting = stage.state
        resting.units.removeAll { $0.id == foe }
        let other = resting.put(.spear, of: me, at: try XCTUnwrap(resting.freeHex(near: resting.seat(of: me)!.position, within: 7...9)), health: 50)
        _ = resting.endWatch()
        let onLand = try XCTUnwrap(resting.unit(spear)).health, offLand = try XCTUnwrap(resting.unit(other)).health
        XCTAssertGreaterThanOrEqual(onLand - offLand, Standard.mendingOnLand)
    }

    func testAFoeAtWarStrikesAStandardDownAndAHouseGoneTakesItsDown() throws {
        var stage = try staged("standards torn")
        let me = stage.me, foe = 3
        let spot = try ground(near: stage.seat.position, in: stage.state)
        _ = try stage.state.perform(.raiseStandard(at: spot), as: me)
        let standard = try XCTUnwrap(stage.state.standard(at: spot))
        let beside = try ground(near: spot, within: 1...1, in: stage.state)
        let spear = stage.state.put(.spear, tier: 5, of: foe, at: beside)
        XCTAssertEqual(stage.state.refusal(of: .attack(unit: spear, target: spot), as: foe), .notAtWar(me), "Only at war")
        _ = try stage.state.declareWar(by: foe, on: me)
        var events: [GameEvent] = []
        for _ in 0..<12 where stage.state.standard(at: spot) != nil {
            stage.state.units[stage.state.unitIndex(spear)!].movesLeft = 2
            events += try stage.state.perform(.attack(unit: spear, target: spot), as: foe)
        }
        XCTAssertNil(stage.state.standard(at: spot), "Torn down")
        XCTAssertTrue(events.contains(.standardTorn(standard: standard.id, alliance: standard.alliance, by: foe, at: spot)))
        let struck = try XCTUnwrap(events.first { if case .standardStruck = $0 { return true } else { return false } })
        XCTAssertEqual(stage.state.events([struck], heardBy: foe), [struck])
        let torn = GameEvent.standardTorn(standard: standard.id, alliance: standard.alliance, by: foe, at: spot)
        XCTAssertEqual(stage.state.tidings(of: torn, for: me)?.text,
                       "\(stage.state.houses[foe].title) tears down your alliance's standard \(stage.state.placeName(of: spot)).")
        XCTAssertEqual(stage.state.tidings(of: torn, for: foe)?.text, "Your company tears down a standard of The Raised Banner.")
        XCTAssertTrue(stage.state.chronicle.last?.text.contains("tears down a standard of The Raised Banner") == true)
        // A House that leaves its alliance takes its standards down as the watch turns.
        var leaving = try staged("standards left")
        let flag = try ground(near: leaving.seat.position, in: leaving.state)
        _ = try leaving.state.perform(.raiseStandard(at: flag), as: leaving.me)
        let raised = try XCTUnwrap(leaving.state.standard(at: flag))
        XCTAssertEqual(leaving.state.keepStandards(), [], "Kept while its House is sworn")
        leaving.state.standards![0].ward = 10
        _ = leaving.state.keepStandards()
        XCTAssertEqual(leaving.state.standard(at: flag)?.ward, 10 + Standard.mending, "Struck, it mends")
        _ = try leaving.state.perform(.leaveAlliance, as: leaving.me)
        XCTAssertEqual(leaving.state.keepStandards(), [.standardTorn(standard: raised.id, alliance: raised.alliance, by: nil, at: flag)])
        XCTAssertNil(leaving.state.standard(at: flag))
        XCTAssertEqual(stage.state.problems(), [])
    }

    /// Standards and lairs out of true are found: two standards on one
    /// ground, a lair on a hold, a lair with no strength left standing.
    func testStandardsAndLairsOutOfTrueAreFound() throws {
        var stage = try staged("unsound ground")
        let spot = try ground(near: stage.seat.position, in: stage.state)
        _ = try stage.state.perform(.raiseStandard(at: spot), as: stage.me)
        let raised = try XCTUnwrap(stage.state.standard(at: spot))
        XCTAssertEqual(stage.state.standard(raised.id), raised)
        XCTAssertNil(stage.state.standard(raised.id + 1_000))
        stage.state.standards!.append(Standard(id: 9_001, alliance: raised.alliance, raisedBy: stage.me, position: spot, raised: 0))
        stage.state.lairs = [Lair(id: 9_002, kind: .reavers, level: 1, position: stage.seat.position, raised: 0)]
        stage.state.lairs![0].strength = 0
        let problems = stage.state.problems()
        XCTAssertTrue(problems.contains("The Reavers' Stockade 9002 stands at 0 of \(Lair.might(level: 1)), level 1"), "\(problems)")
        XCTAssertTrue(problems.contains("The Reavers' Stockade 9002 shares its ground at \(stage.seat.position)"), "\(problems)")
        XCTAssertTrue(problems.contains("Standard 9001 shares its ground at \(spot)"), "\(problems)")
    }

    func testAStewardOfAnAllianceRaisesAStandardWhereItTakesInSites() throws {
        var state = Scene.world("steward standards", houses: 4, radius: 18)
        let steward = 2
        _ = try state.perform(.foundAlliance(name: "The Far Banner"), as: steward)
        let seat = try XCTUnwrap(state.seat(of: steward))
        state.reveal(around: seat.position, range: 6, for: steward)
        state.houses[steward].stock = Stock(grain: 400, timber: 400, stone: 400, moonsalt: 40)
        // A site of the land a few tiles off, for its standard to take in.
        let siteSpot = try XCTUnwrap(state.freeHex(near: seat.position, within: 3...4, avoiding: [.strand, .shallows, .still]))
        state.sites = (state.sites ?? []) + [Site(id: state.takeID(), store: .grain, level: 1, position: siteSpot, found: state.watch)]
        state.watch = RivalMind.standardsFrom + (6 - (RivalMind.standardsFrom + steward) % 6) % 6
        let events = state.stewardTurn(for: steward)
        let raised = events.compactMap { event -> Hex? in
            if case .standardRaised(_, _, steward, let at) = event { return at }
            return nil
        }
        let at = try XCTUnwrap(raised.first, "\(events)")
        XCTAssertLessThanOrEqual(at.distance(to: siteSpot), Standard.reach, "Its land takes in the site")
    }
}
