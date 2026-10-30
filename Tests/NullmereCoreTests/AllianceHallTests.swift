import Foundation
import XCTest
@testable import NullmereCore

/// An alliance's hall: its leader begins it on the alliance's own land, it
/// rises over four watches, and whole it widens the alliance's land, gives
/// its rallies room and its standards number, and its keepers stand
/// firmer. Only the alliance's companies enter it; a House at war with
/// the alliance strikes it down, and an alliance gone leaves it to ruin.
final class AllianceHallTests: XCTestCase {
    private struct Stage {
        var state: GameState
        let me: Int
        let ally: Int
        let alliance: Int
        let seat: Hold
        /// The alliance's standard, near the keeper's seat.
        let flag: Hex
        /// Ground on the alliance's land where its hall may be begun.
        let spot: Hex
    }

    private func staged(_ seed: String = "alliance halls") throws -> Stage {
        var state = Scene.world(seed, houses: 4, radius: 18)
        let me = state.player, ally = 1
        _ = try state.perform(.foundAlliance(name: "The Stone Accord"), as: me)
        state.houses[ally].isPlayer = true
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: alliance, accept: true), as: ally)
        state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let seat = try XCTUnwrap(state.seat(of: me))
        state.reveal(around: seat.position, range: 7, for: me)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.refusal(of: .raiseStandard(at: hex), as: me) == nil
        })
        _ = try state.perform(.raiseStandard(at: flag), as: me)
        let spot = try XCTUnwrap(flag.spiral(Standard.reach).first { state.hallRefusal(at: $0, by: me) == nil })
        return Stage(state: state, me: me, ally: ally, alliance: alliance, seat: seat, flag: flag, spot: spot)
    }

    /// Ground some way from a hex, beyond the reach of every standard.
    private func beyondStandards(_ hex: Hex, at distance: Int, in state: GameState) throws -> Hex {
        try XCTUnwrap(hex.ring(distance).first { candidate in
            state.map[candidate] != nil && state.standardsStanding.allSatisfy { $0.position.distance(to: candidate) > Standard.reach }
        })
    }

    private func raised(_ stage: inout Stage, whole: Bool = true) throws -> AllianceHall {
        _ = try stage.state.perform(.raiseAllianceHall(at: stage.spot), as: stage.me)
        if whole {
            for _ in 0..<AllianceHall.raising { _ = stage.state.keepHalls() }
        }
        return try XCTUnwrap(stage.state.hall(at: stage.spot))
    }

    func testAHallIsBegunOnItsAlliancesLandAndRisesOverFourWatches() throws {
        var stage = try staged()
        let me = stage.me, at = stage.spot
        let before = stage.state.houses[me].stock
        let events = try stage.state.perform(.raiseAllianceHall(at: at), as: me)
        let hall = try XCTUnwrap(stage.state.hall(at: at))
        XCTAssertEqual(events, [.hallRaised(hall: hall.id, alliance: stage.alliance, house: me, at: at)])
        XCTAssertEqual(stage.state.houses[me].stock + AllianceHall.cost, before, "For the leader's stores")
        XCTAssertEqual(hall.ward, AllianceHall.firstWard)
        XCTAssertEqual(hall.progress, 0)
        XCTAssertFalse(hall.isWhole)
        XCTAssertEqual(stage.state.hall(of: stage.alliance), hall)
        XCTAssertEqual(stage.state.hall(hall.id), hall)
        XCTAssertNil(stage.state.hall(hall.id + 1_000))
        XCTAssertTrue(stage.state.isOccupied(at), "Nothing else rises on it")
        // Its land, its rallies' room and its standards wait until it is whole.
        let far = try beyondStandards(at, at: AllianceHall.reach, in: stage.state)
        XCTAssertNil(stage.state.allianceLand(at: far))
        let alliance = try XCTUnwrap(stage.state.alliance(of: me))
        let allySeat = try XCTUnwrap(stage.state.seat(of: stage.ally))
        let rally = Rally(id: 9_000, caller: stage.ally, muster: allySeat.id, target: 0, called: 0, setsOut: 1)
        let room = stage.state.capacity(of: rally), allowed = stage.state.standardsAllowed(for: alliance)
        XCTAssertEqual(allowed, Standard.allowed(members: 2))
        var risen: [GameEvent] = []
        var wards: [Int] = []
        for _ in 0..<AllianceHall.raising {
            XCTAssertEqual(stage.state.capacity(of: rally), room)
            risen += stage.state.keepHalls()
            wards.append(try XCTUnwrap(stage.state.hall(at: at)).ward)
        }
        XCTAssertEqual(wards, [90, 140, 190, AllianceHall.maximumWard], "Its ward grows as it rises")
        XCTAssertEqual(risen, [.hallRisen(hall: hall.id, alliance: stage.alliance, at: at)])
        XCTAssertTrue(try XCTUnwrap(stage.state.hall(at: at)).isWhole)
        XCTAssertEqual(stage.state.hall(at: at)?.progress, 1)
        XCTAssertEqual(stage.state.allianceLand(at: far), stage.alliance, "Three tiles about it")
        XCTAssertNil(stage.state.allianceLand(at: try beyondStandards(at, at: AllianceHall.reach + 1, in: stage.state)))
        XCTAssertEqual(stage.state.capacity(of: rally), room + AllianceHall.rallyCompanies, "Its rallies take more")
        XCTAssertEqual(stage.state.standardsAllowed(for: alliance), allowed + AllianceHall.standards, "It may keep more standards")
        let place = stage.state.placeName(of: at)
        XCTAssertTrue(stage.state.chronicle.contains { $0.text == "The hall of The Stone Accord stands whole \(place)." })
        // Told to each as it concerns them.
        let title = stage.state.houses[me].title
        XCTAssertEqual(stage.state.tidings(of: events[0], for: me)?.text, "You begin the hall of The Stone Accord \(place): it rises over 4 watches.")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: stage.ally)?.text, "\(title) begins your alliance's hall \(place): it rises over 4 watches.")
        XCTAssertEqual(stage.state.tidings(of: events[0], for: 2)?.text, "\(title) begins a hall of The Stone Accord \(place).")
        XCTAssertEqual(stage.state.tidings(of: risen[0], for: stage.ally)?.text,
                       "Your alliance's hall stands whole \(place): its land reaches 3 tiles about it, your rallies take 2 more companies, "
                       + "and the alliance may keep 2 more standards.")
        XCTAssertEqual(stage.state.tidings(of: risen[0], for: 2)?.text, "The hall of The Stone Accord stands whole \(place).")
        XCTAssertNil(stage.state.tidings(of: .hallRisen(hall: hall.id, alliance: 9_999, at: at), for: me))
        XCTAssertNil(stage.state.tidings(of: .hallRaised(hall: hall.id, alliance: 9_999, house: me, at: at), for: me))
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testAHallIsBegunOnlyWhereItMay() throws {
        var stage = try staged("halls refused")
        let me = stage.me
        func refused(_ hex: Hex, as house: Int? = nil, in state: GameState? = nil) -> RuleError? {
            (state ?? stage.state).refusal(of: .raiseAllianceHall(at: hex), as: house ?? me)
        }
        XCTAssertNil(refused(stage.spot))
        XCTAssertEqual(refused(stage.spot, as: 3), .notInAlliance)
        XCTAssertEqual(refused(stage.spot, as: stage.ally), .notAllianceLeader, "Its leader raises it")
        XCTAssertEqual(refused(stage.flag), .hallGround, "Not on its standard")
        XCTAssertEqual(refused(Hex(900, 0)), .outsideTheWorld)
        let off = try XCTUnwrap(stage.state.map.hexes.first { hex in
            stage.state.isExplored(hex, by: me) && stage.state.allianceLand(at: hex) == nil
                && stage.state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
                && !stage.state.isOccupied(hex) && stage.state.site(at: hex) == nil && stage.state.shrine(at: hex) == nil
        })
        XCTAssertEqual(refused(off), .notAllianceLand)
        let unknown = try XCTUnwrap(stage.state.map.hexes.first { !stage.state.isExplored($0, by: me) })
        XCTAssertEqual(refused(unknown), .unexplored)
        // Near another alliance's standard, it is theirs.
        var crowded = stage.state
        let theirs = try XCTUnwrap(stage.spot.ring(AllianceHall.reach + Standard.reach).first { crowded.map[$0] != nil })
        crowded.standards!.append(Standard(id: crowded.takeID(), alliance: 9_999, raisedBy: 2, position: theirs, raised: 0))
        XCTAssertEqual(refused(stage.spot, in: crowded), .foreignTerritory)
        var poor = stage.state
        poor.houses[me].stock = .zero
        XCTAssertEqual(refused(stage.spot, in: poor), .shortOf(AllianceHall.cost))
        _ = try raised(&stage, whole: false)
        let another = try XCTUnwrap(stage.flag.spiral(Standard.reach).first {
            !stage.state.isOccupied($0) && stage.state.map[$0].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
        })
        XCTAssertEqual(refused(another), .hallStanding, "One to an alliance")
        XCTAssertEqual(RuleError.hallStanding.description, "Your alliance has its hall already: it raises one, and another only once that one falls.")
        XCTAssertEqual(RuleError.hallGround.description, "A hall stands only on open land, with nothing on it.")
        XCTAssertEqual(RuleError.notAllianceLand.description, "A hall stands on your alliance's own land, within reach of its standards.")
        // A standard is raised near the hall, not near another's.
        XCTAssertEqual(stage.state.refusal(of: .raiseStandard(at: stage.spot), as: me), .standardGround)
        var foreign = stage.state
        let near = try XCTUnwrap(stage.spot.ring(AllianceHall.reach + 1).first { hex in
            foreign.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !foreign.isOccupied(hex)
                && foreign.site(at: hex) == nil && foreign.shrine(at: hex) == nil && foreign.isExplored(hex, by: me)
                && min(hex.distance(to: stage.flag), hex.distance(to: stage.seat.position)) <= Standard.tether
        })
        foreign.halls![0] = AllianceHall(id: foreign.halls![0].id, alliance: 9_999, raisedBy: 2, position: stage.spot, begun: 0)
        XCTAssertEqual(foreign.refusal(of: .raiseStandard(at: near), as: me), .foreignTerritory)
    }

    func testOnlyItsAlliancesCompaniesEnterItAndItsKeepersStandFirmer() throws {
        var stage = try staged("halls kept")
        let at = stage.spot
        _ = try raised(&stage)
        let gates = stage.spot.ring(1).filter { stage.state.map[$0].map { $0.terrain.isPassable } == true && !stage.state.isOccupied($0) }
        XCTAssertGreaterThanOrEqual(gates.count, 3)
        // Another House's company, at peace, stops at its gate.
        let stranger = stage.state.put(.spear, of: 2, at: gates[0])
        _ = try stage.state.perform(.move(unit: stranger, to: at), as: 2)
        XCTAssertEqual(stage.state.unit(stranger)?.position, gates[0], "Only its alliance's companies enter")
        let around = try XCTUnwrap(stage.state.path(for: try XCTUnwrap(stage.state.unit(stranger)), to: gates[1]))
        XCTAssertFalse(around.contains(at), "And none passes through it")
        // The alliance's own marches in.
        let keeper = stage.state.put(.spear, of: stage.ally, at: gates[1])
        _ = try stage.state.perform(.move(unit: keeper, to: at), as: stage.ally)
        XCTAssertEqual(stage.state.unit(keeper)?.position, at)
        // Keeping it whole, it stands a quarter firmer.
        let foe = stage.state.put(.spear, of: 3, at: gates[2])
        let attacker = try XCTUnwrap(stage.state.unit(foe)), defender = try XCTUnwrap(stage.state.unit(keeper))
        let held = stage.state.strengths(of: attacker, against: defender, at: at).defense
        var rising = stage.state
        rising.halls![0].built = AllianceHall.raising - 1
        let bare = rising.strengths(of: attacker, against: defender, at: at).defense
        XCTAssertGreaterThan(held, bare)
        XCTAssertFalse(stage.state.takesTheField(attacker, at: at), "A foe that wins at its gate never steps in")
    }

    func testAFoeAtWarWithItsAllianceStrikesItDown() throws {
        var stage = try staged("halls torn")
        let me = stage.me, foe = 3, at = stage.spot
        let hall = try raised(&stage)
        let beside = try XCTUnwrap(stage.state.freeHex(near: at, within: 1...1))
        let spear = stage.state.put(.spear, tier: 5, of: foe, at: beside)
        XCTAssertFalse(stage.state.isFoe(foe, of: hall))
        XCTAssertEqual(stage.state.refusal(of: .attack(unit: spear, target: at), as: foe), .notAtWar(me), "Only at war")
        // At war with one of its Houses, it is the alliance's foe.
        _ = try stage.state.declareWar(by: foe, on: stage.ally)
        XCTAssertTrue(stage.state.isFoe(foe, of: hall))
        XCTAssertFalse(stage.state.isFoe(stage.ally, of: hall), "Never its own")
        var events: [GameEvent] = []
        for _ in 0..<40 where stage.state.hall(at: at) != nil {
            stage.state.units[stage.state.unitIndex(spear)!].movesLeft = 2
            events += try stage.state.perform(.move(unit: spear, to: at), as: foe)
        }
        XCTAssertNil(stage.state.hall(at: at), "Torn down")
        XCTAssertNotEqual(stage.state.unit(spear)?.position, at, "Struck from beside it")
        let torn = GameEvent.hallTorn(hall: hall.id, alliance: stage.alliance, by: foe, at: at)
        XCTAssertTrue(events.contains(torn))
        let struck = try XCTUnwrap(events.first { if case .hallStruck = $0 { return true } else { return false } })
        guard case .hallStruck(_, _, let ward, _, _) = struck else { return XCTFail() }
        XCTAssertEqual(stage.state.events([struck], heardBy: foe), [struck])
        XCTAssertEqual(stage.state.events([struck], heardBy: stage.ally), [struck], "Its alliance hears it")
        let place = stage.state.placeName(of: at), name = stage.state.houses[foe].title
        XCTAssertEqual(stage.state.tidings(of: struck, for: foe)?.text, "Your company strikes the hall of The Stone Accord: its ward \(ward) of 240.")
        XCTAssertEqual(stage.state.tidings(of: struck, for: stage.ally)?.text, "\(name) strikes your alliance's hall \(place): its ward \(ward) of 240.")
        XCTAssertEqual(stage.state.tidings(of: struck, for: stage.ally)?.tone, .bad)
        XCTAssertNil(stage.state.tidings(of: struck, for: 2))
        XCTAssertEqual(stage.state.tidings(of: torn, for: me)?.text, "\(name) tears down your alliance's hall \(place).")
        XCTAssertEqual(stage.state.tidings(of: torn, for: foe)?.text, "Your company tears down the hall of The Stone Accord.")
        XCTAssertEqual(stage.state.tidings(of: torn, for: 2)?.text, "\(name) tears down the hall of The Stone Accord \(place).")
        XCTAssertNil(stage.state.tidings(of: .hallTorn(hall: hall.id, alliance: stage.alliance, by: nil, at: at), for: me))
        XCTAssertTrue(stage.state.chronicle.contains { $0.text == "\(name) tears down the hall of The Stone Accord \(place)." })
        XCTAssertEqual(stage.state.problems(), [])
        // A keeper of its own in it is fought first.
        var kept = try staged("halls defended")
        _ = try raised(&kept)
        let keeper = kept.state.put(.spear, of: kept.ally, at: kept.spot)
        let striker = kept.state.put(.spear, tier: 5, of: foe, at: try XCTUnwrap(kept.state.freeHex(near: kept.spot, within: 1...1)))
        _ = try kept.state.declareWar(by: foe, on: kept.ally)
        let fought = try kept.state.perform(.attack(unit: striker, target: kept.spot), as: foe)
        XCTAssertTrue(fought.contains { if case .battle(let battle) = $0 { return battle.defender == keeper } else { return false } })
        XCTAssertEqual(kept.state.hall(at: kept.spot)?.ward, AllianceHall.maximumWard, "Its ward untouched while it is kept")
    }

    func testItsRalliesLoseTheRoomItGaveWhenTheirCallerLeavesIt() throws {
        var stage = try staged("halls rallies")
        _ = try raised(&stage)
        let rally = Rally(id: stage.state.takeID(), caller: stage.me, muster: stage.seat.id, target: 0, called: 0, setsOut: 2)
        let room = stage.state.capacity(of: rally)
        stage.state.rallies = [rally]
        var sent: [Int] = []
        for _ in 0..<room {
            let id = stage.state.put(.spear, of: stage.me, at: try XCTUnwrap(stage.state.freeHex(near: stage.seat.position, within: 1...4)))
            stage.state.units[stage.state.unitIndex(id)!].errand = .rally(rally.id)
            stage.state.rallies![0].companies.append(id)
            sent.append(id)
        }
        stage.state.fitRallies()
        XCTAssertEqual(stage.state.rally(rally.id)?.companies, sent, "Room for all while the hall stands")
        _ = try stage.state.perform(.leaveAlliance, as: stage.me)
        XCTAssertEqual(stage.state.rally(rally.id)?.companies, Array(sent.prefix(room - AllianceHall.rallyCompanies)))
        for id in sent.suffix(AllianceHall.rallyCompanies) {
            XCTAssertNil(stage.state.unit(id)?.errand, "The last sent go back to their House's orders")
        }
    }

    func testAHallWhoseAllianceIsNoMoreFallsIntoRuin() throws {
        var stage = try staged("halls ruined")
        let hall = try raised(&stage, whole: false)
        XCTAssertEqual(stage.state.keepHalls(), [], "Kept while its alliance stands")
        _ = try stage.state.perform(.leaveAlliance, as: stage.ally)
        _ = try stage.state.perform(.leaveAlliance, as: stage.me)
        XCTAssertNil(stage.state.alliance(stage.alliance))
        let events = stage.state.keepHalls()
        XCTAssertEqual(events, [.hallTorn(hall: hall.id, alliance: stage.alliance, by: nil, at: stage.spot)])
        XCTAssertNil(stage.state.hall(at: stage.spot))
        XCTAssertEqual(stage.state.tidings(of: events[0], for: 2)?.text,
                       "A hall \(stage.state.placeName(of: stage.spot)) falls into ruin, its alliance no more.")
        // No hold is founded on an alliance's ground.
        var founding = stage.state
        let open = try XCTUnwrap(founding.map.hexes.first { founding.canFound(at: $0, for: stage.me) == nil && !founding.isOccupied($0) })
        founding.standards = [Standard(id: founding.takeID(), alliance: 1, raisedBy: stage.me, position: open, raised: 0)]
        XCTAssertEqual(founding.canFound(at: open, for: stage.me), .allianceGround)
        founding.standards = nil
        founding.halls = [AllianceHall(id: founding.takeID(), alliance: 1, raisedBy: stage.me, position: open, begun: 0)]
        XCTAssertEqual(founding.canFound(at: open, for: stage.me), .allianceGround)
        XCTAssertEqual(RuleError.allianceGround.description, "An alliance's standard or hall stands here: a hold is founded on open land.")
    }

    func testHallsAreSeenOnGroundExploredAndKeptInSaves() throws {
        var stage = try staged("halls seen")
        let hall = try raised(&stage, whole: false)
        XCTAssertEqual(stage.state.view(for: stage.me).hallsStanding, [hall])
        XCTAssertFalse(stage.state.isExplored(stage.spot, by: 2))
        XCTAssertEqual(stage.state.view(for: 2).hallsStanding, [], "Not on ground unexplored")
        let begun = GameEvent.hallRaised(hall: hall.id, alliance: stage.alliance, house: stage.me, at: stage.spot)
        XCTAssertEqual(stage.state.events([begun], heardBy: stage.ally), [begun])
        XCTAssertEqual(stage.state.events([begun], heardBy: 2), [])
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(stage.state))
        XCTAssertEqual(kept.hall(at: stage.spot), hall)
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["halls"], in: stage.state))
        XCTAssertEqual(older.hallsStanding, [], "Saves from before halls have none")
    }

    func testHallsOutOfTrueAreFound() throws {
        var stage = try staged("halls unsound")
        let hall = try raised(&stage, whole: false)
        stage.state.halls![0].built = 9
        stage.state.halls![0].ward = 500
        stage.state.halls!.append(AllianceHall(id: 9_001, alliance: hall.alliance, raisedBy: stage.me, position: stage.spot, begun: 0))
        stage.state.halls!.append(AllianceHall(id: 9_002, alliance: 8_888, raisedBy: stage.me, position: stage.seat.position, begun: 0))
        let water = try XCTUnwrap(stage.state.map.hexes.first { stage.state.map[$0]?.terrain.isPassable == false })
        stage.state.halls!.append(AllianceHall(id: 9_003, alliance: 8_887, raisedBy: stage.me, position: water, begun: 0))
        let problems = stage.state.problems()
        for problem in ["Hall \(hall.id) is built 9 of 4", "Hall \(hall.id) has ward 500 of 240", "Alliance \(hall.alliance) has two halls",
                        "Hall 9001 shares its ground at \(stage.spot)", "Hall 9002 stands for no alliance",
                        "Hall 9002 shares its ground at \(stage.seat.position)", "Hall 9003 stands where none can"] {
            XCTAssertTrue(problems.contains(problem), "\(problem) in \(problems)")
        }
    }

    func testAStewardLeaderBeginsItsAlliancesHallOnItsLand() throws {
        var state = Scene.world("steward halls", houses: 4, radius: 18)
        let steward = 2
        _ = try state.perform(.foundAlliance(name: "The Far Hall"), as: steward)
        let seat = try XCTUnwrap(state.seat(of: steward))
        state.reveal(around: seat.position, range: 6, for: steward)
        state.houses[steward].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 90)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.refusal(of: .raiseStandard(at: hex), as: steward) == nil
        })
        _ = try state.perform(.raiseStandard(at: flag), as: steward)
        state.watch = RivalMind.hallsFrom + (4 - (RivalMind.hallsFrom + steward) % 4) % 4
        let events = state.stewardTurn(for: steward)
        let begun = events.compactMap { event -> Hex? in
            if case .hallRaised(_, _, steward, let at) = event { return at }
            return nil
        }
        let at = try XCTUnwrap(begun.first, "\(events)")
        XCTAssertEqual(state.allianceLand(at: at), state.alliance(of: steward)?.id, "On its alliance's land")
        XCTAssertEqual(state.problems(), [])
    }

    func testStewardsAtWarStrikeAFoesHallLeftUnkept() throws {
        var stage = try staged("stewards strike halls")
        _ = try raised(&stage)
        let foe = 3
        _ = try stage.state.declareWar(by: foe, on: stage.me)
        // Companies of war at its gates, with nothing else of a foe's in reach.
        let gates = stage.spot.ring(1).filter { hex in
            stage.state.map[hex].map { $0.terrain.isPassable } == true && !stage.state.isOccupied(hex)
                && hex.ring(1).allSatisfy { stage.state.hold(at: $0) == nil && stage.state.unit(at: $0) == nil }
        }
        XCTAssertGreaterThanOrEqual(gates.count, 2)
        for gate in gates.prefix(2) { stage.state.put(.spear, tier: 3, of: foe, at: gate) }
        let events = stage.state.stewardTurn(for: foe)
        XCTAssertTrue(events.contains { if case .hallStruck(_, _, _, foe, _) = $0 { return true } else { return false } }, "\(events)")
    }
}
