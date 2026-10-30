import Foundation
import XCTest
@testable import NullmereCore

/// Rallies: a House of an alliance calls one at its hold against a hold of
/// a House at war with it; its side sends companies; the host sets out
/// together, marches at the pace of its slowest and strikes together.
/// And allies keep each other's gates.
final class RallyTests: XCTestCase {
    /// A small lake: the keeper's House and House 1 sworn together, both at
    /// war with House 2, which holds Thornwick, a walled hold a few tiles
    /// from the keeper's seat; House 3 stands apart.
    private struct Stage {
        var state: GameState
        let me: Int
        let seat: Int
        let target: Int

        var seatHex: Hex { state.hold(seat)!.position }
        var targetHex: Hex { state.hold(target)!.position }
    }

    private func staged(_ seed: String = "rallies") throws -> Stage {
        var state = Scene.world(seed, houses: 4, radius: 18)
        let me = state.player
        state.houses[1].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Hostward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        _ = try state.declareWar(by: me, on: 2)
        let seat = try XCTUnwrap(state.seat(of: me))
        let spot = try XCTUnwrap(state.map.hexes.first { hex in
            (5...6).contains(hex.distance(to: seat.position)) && state.map[hex]?.terrain == .greyfield && state.isClear(hex)
                && state.wild(at: hex) == nil && state.site(at: hex) == nil
                && state.holds.allSatisfy { $0.position.distance(to: hex) >= 4 }
                && state.path(for: Unit(id: -1, kind: .spear, owner: me, position: seat.position), to: hex) != nil
        })
        var thornwick = Hold(id: state.takeID(), name: "Thornwick", owner: 2, position: spot, isSeat: false, foundedWatch: state.watch)
        thornwick.levels[.walls] = 3
        thornwick.ward = thornwick.maximumWard
        state.holds.append(thornwick)
        state.reveal(around: spot, range: 2, for: me)
        // The keeper's seat left clear for the companies gathering there:
        // its first Spears gone, its lantern sent off a way.
        state.units.removeAll { $0.owner == me && $0.kind == .spear }
        let lantern = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind == .lantern })
        state.units[lantern].position = try XCTUnwrap(state.freeHex(near: seat.position, within: 4...5))
        return Stage(state: state, me: me, seat: seat.id, target: thornwick.id)
    }

    private func refusal(_ command: Command, in state: GameState, as house: Int) -> RuleError? {
        var trial = state
        do {
            try trial.perform(command, as: house)
            return nil
        } catch {
            return error
        }
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

    /// A company of a House put on free ground a few tiles from a hex.
    @discardableResult
    private func company(_ kind: UnitKind, of house: Int, near hex: Hex, in state: inout GameState) throws -> Int {
        let spot = try XCTUnwrap(state.freeHex(near: hex, within: 2...3, avoiding: [.strand]))
        return state.put(kind, of: house, at: spot)
    }

    func testARallyIsCalled() throws {
        let stage = try staged()
        var state = stage.state
        let me = stage.me
        XCTAssertEqual(refusal(.callRally(from: stage.seat, against: stage.target, watches: 2), in: state, as: me), .needsMusterHall(1))
        let seatIndex = try XCTUnwrap(state.holdIndex(stage.seat))
        state.holds[seatIndex].levels[.musterHall] = 1
        XCTAssertEqual(refusal(.callRally(from: stage.seat, against: stage.target, watches: 2), in: state, as: 3), .notInAlliance)
        let theirSeat = try XCTUnwrap(state.seat(of: 1)).id
        XCTAssertEqual(refusal(.callRally(from: theirSeat, against: stage.target, watches: 2), in: state, as: me), .notYours)
        XCTAssertEqual(refusal(.callRally(from: stage.seat, against: 9_999, watches: 2), in: state, as: me), .unknownHold)
        let unknown = try XCTUnwrap(state.seat(of: 3))
        XCTAssertFalse(state.isExplored(unknown.position, by: me))
        XCTAssertEqual(refusal(.callRally(from: stage.seat, against: unknown.id, watches: 2), in: state, as: me), .unknownHold,
                       "No rally against a hold the House hasn't found")
        state.reveal(around: unknown.position, range: 0, for: me)
        XCTAssertEqual(refusal(.callRally(from: stage.seat, against: unknown.id, watches: 2), in: state, as: me), .notAtWar(3))
        for watches in [0, 5] {
            XCTAssertEqual(refusal(.callRally(from: stage.seat, against: stage.target, watches: watches), in: state, as: me), .rallyWatches)
        }
        let events = try state.perform(.callRally(from: stage.seat, against: stage.target, watches: 2), as: me)
        let rally = try XCTUnwrap(state.ralliesStanding.first)
        XCTAssertEqual(events, [.rallyCalled(rally: rally.id, caller: me, target: stage.target)])
        XCTAssertEqual(rally.setsOut, state.watch + 2)
        XCTAssertEqual(rally.muster, stage.seat)
        XCTAssertFalse(rally.marching)
        XCTAssertEqual(rally.companies, [])
        XCTAssertEqual(state.capacity(of: rally), 4)
        XCTAssertEqual(refusal(.callRally(from: stage.seat, against: stage.target, watches: 1), in: state, as: me), .rallyCalled)

        // Only its own side knows of it.
        XCTAssertEqual(state.view(for: 1).ralliesStanding.map(\.id), [rally.id])
        XCTAssertEqual(state.view(for: 2).ralliesStanding, [])
        XCTAssertEqual(state.view(for: 3).ralliesStanding, [])
        XCTAssertEqual(state.events(events, heardBy: 1), events)
        XCTAssertEqual(state.events(events, heardBy: 2), [])
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "You call a rally at \(state.hold(stage.seat)!.name) against Thornwick.")
        XCTAssertEqual(state.tidings(of: events[0], for: 1)?.text,
                       "\(state.houses[me].title) calls a rally at \(state.hold(stage.seat)!.name) against Thornwick; it sets out in 2 watches.")
    }

    func testCompaniesAreSentToARally() throws {
        let stage = try staged("sent to a rally")
        var state = stage.state
        let me = stage.me
        state.holds[try XCTUnwrap(state.holdIndex(stage.seat))].levels[.musterHall] = 1
        _ = try state.perform(.callRally(from: stage.seat, against: stage.target, watches: 3), as: me)
        let id = try XCTUnwrap(state.ralliesStanding.first).id
        let spear = try company(.spear, of: me, near: stage.seatHex, in: &state)
        let theirs = try company(.rider, of: 1, near: stage.seatHex, in: &state)
        let stranger = try company(.spear, of: 3, near: stage.seatHex, in: &state)
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern }).id

        XCTAssertEqual(refusal(.joinRally(rally: 4_242, unit: spear), in: state, as: me), .unknownRally)
        XCTAssertEqual(refusal(.joinRally(rally: id, unit: stranger), in: state, as: 3), .unknownRally, "Only its side may join")
        XCTAssertEqual(refusal(.joinRally(rally: id, unit: theirs), in: state, as: me), .notYours)
        XCTAssertEqual(refusal(.joinRally(rally: id, unit: lantern), in: state, as: me), .cannotFight)
        XCTAssertEqual(refusal(.joinRally(rally: id, unit: theirs), in: state, as: 1), .notAtWar(2), "An ally joins a war it shares")
        _ = try state.declareWar(by: 1, on: 2)

        let joined = try state.perform(.joinRally(rally: id, unit: theirs), as: 1)
        XCTAssertEqual(joined.first, .rallyJoined(rally: id, unit: theirs, house: 1))
        XCTAssertEqual(state.unit(theirs)?.errand, .rally(id))
        XCTAssertEqual(refusal(.joinRally(rally: id, unit: theirs), in: state, as: 1), .alreadyRallying)
        _ = try state.perform(.joinRally(rally: id, unit: spear), as: me)
        XCTAssertEqual(state.rally(id)?.companies, [theirs, spear])
        XCTAssertEqual(state.tidings(of: .rallyJoined(rally: id, unit: theirs, house: 1), for: me)?.text,
                       "\(state.houses[1].title) sends Riders to the rally at \(state.hold(stage.seat)!.name).")
        XCTAssertEqual(state.tidings(of: .rallyJoined(rally: id, unit: spear, house: me), for: me)?.text,
                       "Your Spears march to the rally at \(state.hold(stage.seat)!.name).")
        XCTAssertEqual(state.events([.rallyJoined(rally: id, unit: theirs, house: 1)], heardBy: 3), [])

        for _ in 0..<2 { _ = try company(.spear, of: me, near: stage.seatHex, in: &state) }
        let more = state.units(of: me).filter { $0.kind == .spear && $0.id != spear && $0.errand == nil }.map(\.id)
        for unit in more.prefix(2) { _ = try state.perform(.joinRally(rally: id, unit: unit), as: me) }
        XCTAssertEqual(state.rally(id)?.companies.count, 4)
        let fifth = try company(.bow, of: me, near: stage.seatHex, in: &state)
        XCTAssertEqual(refusal(.joinRally(rally: id, unit: fifth), in: state, as: me), .rallyFull, "A Muster Hall I takes four")

        // A company given another order leaves the rally; its place is free.
        _ = try state.perform(.halt(unit: spear), as: me)
        XCTAssertNil(state.unit(spear)?.errand)
        XCTAssertNil(refusal(.joinRally(rally: id, unit: fifth), in: state, as: me))

        // Those sent march to the muster; an ally's stands at its gates.
        for _ in 0..<2 { turn(&state) }
        XCTAssertLessThanOrEqual(try XCTUnwrap(state.unit(theirs)).position.distance(to: stage.seatHex), 1)
        XCTAssertNotEqual(state.unit(theirs)?.position, stage.seatHex)
        XCTAssertEqual(state.problems(), [])
    }

    func testAHostMarchesTogetherAndStrikesTogether() throws {
        let stage = try staged("host")
        var state = stage.state
        let me = stage.me
        state.holds[try XCTUnwrap(state.holdIndex(stage.seat))].levels[.musterHall] = 2
        _ = try state.declareWar(by: 1, on: 2)
        _ = try state.perform(.callRally(from: stage.seat, against: stage.target, watches: 1), as: me)
        let id = try XCTUnwrap(state.ralliesStanding.first).id
        let host = [
            try company(.spear, of: me, near: stage.seatHex, in: &state), try company(.rider, of: me, near: stage.seatHex, in: &state),
            try company(.bow, of: me, near: stage.seatHex, in: &state), try company(.rider, of: 1, near: stage.seatHex, in: &state),
        ]
        for unit in host {
            _ = try state.perform(.joinRally(rally: id, unit: unit), as: try XCTUnwrap(state.unit(unit)).owner)
        }
        // One sent from far off isn't there when the host sets out.
        let far = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: stage.seatHex) >= 9 && state.map[hex]?.terrain.isPassable == true && state.isClear(hex) && state.wild(at: hex) == nil
                && state.path(for: Unit(id: -1, kind: .spear, owner: me, position: hex), to: stage.seatHex) != nil
        })
        let late = state.put(.spear, of: me, at: far)
        _ = try state.perform(.joinRally(rally: id, unit: late), as: me)

        var setOut: [GameEvent] = []
        for _ in 0..<4 where setOut.isEmpty {
            setOut = turn(&state).filter { if case .rallySetOut = $0 { return true } else { return false } }
        }
        let ready = try XCTUnwrap(state.rally(id)).companies
        XCTAssertEqual(setOut, [.rallySetOut(rally: id, caller: me, target: stage.target, defender: 2, companies: ready.count)])
        XCTAssertGreaterThanOrEqual(ready.count, 3, "Those at the muster set out")
        XCTAssertTrue(Set(ready).isSubset(of: host))
        XCTAssertFalse(ready.contains(late), "The late are left")
        XCTAssertNil(state.unit(late)?.errand)
        XCTAssertNil(state.unit(late)?.destination)
        XCTAssertEqual(refusal(.joinRally(rally: id, unit: late), in: state, as: me), .rallySetOut)
        XCTAssertEqual(state.view(for: 2).ralliesStanding.map(\.id), [id], "A host on the march is seen by the House it marches on")
        XCTAssertEqual(state.tidings(of: setOut[0], for: 2), Tidings("A host of \(ready.count) companies marches on Thornwick!", .bad))
        XCTAssertEqual(state.tidings(of: setOut[0], for: me)?.text, "Your host of \(ready.count) companies sets out for Thornwick.")
        XCTAssertEqual(state.tidings(of: .rallySetOut(rally: id, caller: 1, target: stage.target, defender: 2, companies: 1), for: me)?.text,
                       "\(state.houses[1].title)'s host of 1 company sets out for Thornwick.")

        let wardBefore = try XCTUnwrap(state.hold(stage.target)).ward
        var struck: [GameEvent] = []
        var watches = 0
        while struck.isEmpty, watches < Rally.marchLimit {
            let before = Dictionary(uniqueKeysWithValues: host.compactMap { id in state.unit(id).map { (id, $0.position) } })
            let events = turn(&state)
            watches += 1
            if let strikeAt = events.firstIndex(where: { if case .rallyStruck = $0 { return true } else { return false } }) {
                struck = Array(events[..<(strikeAt + 1)])
                break
            }
            // The host keeps to its slowest's pace.
            for id in host {
                guard let from = before[id], let now = state.unit(id)?.position else { continue }
                XCTAssertLessThanOrEqual(from.distance(to: now), 2, "Riders keep the Spears' pace")
            }
        }
        guard case .rallyStruck(let rallyID, let caller, let target, let defender, let taken)? = struck.last else {
            return XCTFail("The host never struck: \(state.rally(id).map { "\($0)" } ?? "gone")")
        }
        XCTAssertEqual([rallyID, caller, target, defender], [id, me, stage.target, 2])
        let blows = struck.compactMap { event -> Battle? in
            if case .battle(let battle) = event, battle.hold == stage.target { return battle }
            return nil
        }
        XCTAssertGreaterThanOrEqual(blows.count, 2, "Struck together, in the one watch")
        XCTAssertEqual(blows.first?.attackerKind, .bow, "Arrows first")
        XCTAssertEqual(state.hold(stage.target)?.owner == 2, !taken)
        if !taken { XCTAssertLessThan(try XCTUnwrap(state.hold(stage.target)).ward, wardBefore) }
        XCTAssertNil(state.rally(id))
        XCTAssertTrue(host.allSatisfy { state.unit($0).map { $0.errand == nil } ?? true }, "The host goes back to its Houses' orders")
        XCTAssertTrue(state.chronicle.contains { $0.kind == .rally && $0.text.hasPrefix("A host of \(state.houses[me].title) and \(state.houses[1].title) falls upon Thornwick") })
        XCTAssertEqual(state.events([struck.last!], heardBy: 2), [struck.last!])
        XCTAssertEqual(state.events([struck.last!], heardBy: 3), [])
        XCTAssertEqual(state.problems(), [])
    }

    func testAHostTakesAHoldItBreaks() throws {
        let stage = try staged("a hold taken")
        var state = stage.state
        let me = stage.me
        state.holds[try XCTUnwrap(state.holdIndex(stage.seat))].levels[.musterHall] = 2
        let targetIndex = try XCTUnwrap(state.holdIndex(stage.target))
        state.holds[targetIndex].ward = 10
        _ = try state.perform(.callRally(from: stage.seat, against: stage.target, watches: 1), as: me)
        let id = try XCTUnwrap(state.ralliesStanding.first).id
        let second = id
        let gathered = [try company(.spear, of: me, near: stage.seatHex, in: &state), try company(.spear, of: me, near: stage.seatHex, in: &state)]
        for unit in gathered { _ = try state.perform(.joinRally(rally: second, unit: unit), as: me) }
        var taken = false
        for _ in 0..<Rally.marchLimit where !taken {
            taken = turn(&state).contains(.rallyStruck(rally: second, caller: me, target: stage.target, defender: 2, taken: true))
        }
        XCTAssertTrue(taken)
        XCTAssertEqual(state.hold(stage.target)?.owner, me)
        XCTAssertEqual(state.tidings(of: .rallyStruck(rally: second, caller: me, target: stage.target, defender: 2, taken: true), for: 2),
                       Tidings("The host takes Thornwick.", .bad))
        XCTAssertEqual(state.tidings(of: .rallyStruck(rally: second, caller: me, target: stage.target, defender: 2, taken: true), for: me),
                       Tidings("The host takes Thornwick!", .good))
        XCTAssertTrue(state.chronicle.contains { $0.kind == .rally && $0.text == "A host of \(state.houses[me].title) falls upon Thornwick and takes it." })
    }

    func testARallyComesToNothingWhenItsCauseIsGone() throws {
        let stage = try staged("to nothing")
        var state = stage.state
        let me = stage.me
        state.holds[try XCTUnwrap(state.holdIndex(stage.seat))].levels[.musterHall] = 1
        _ = try state.perform(.callRally(from: stage.seat, against: stage.target, watches: 2), as: me)
        let id = try XCTUnwrap(state.ralliesStanding.first).id
        let spear = try company(.spear, of: me, near: stage.seatHex, in: &state)
        _ = try state.perform(.joinRally(rally: id, unit: spear), as: me)

        // Peace with the hold's House ends it.
        var peace = state
        peace.setStance(.peace, between: me, and: 2, by: me)
        XCTAssertEqual(turn(&peace).last, .rallyDispersed(rally: id, caller: me))
        XCTAssertNil(peace.unit(spear)?.errand)
        XCTAssertEqual(peace.tidings(of: .rallyDispersed(rally: id, caller: me), for: me), Tidings("Your rally comes to nothing.", .bad))
        XCTAssertEqual(peace.tidings(of: .rallyDispersed(rally: id, caller: me), for: 1)?.text, "\(state.houses[me].title)'s rally comes to nothing.")

        // So does leaving the alliance.
        var alone = state
        _ = try alone.perform(.leaveAlliance, as: me)
        XCTAssertEqual(turn(&alone).last, .rallyDispersed(rally: id, caller: me))

        // And a gathering that comes to the muster empty.
        var empty = state
        _ = try empty.perform(.halt(unit: spear), as: me)
        turn(&empty)
        XCTAssertEqual(turn(&empty).last, .rallyDispersed(rally: id, caller: me))

        // And a host that can't come to its hold in time.
        var stuck = state
        for _ in 0..<2 { turn(&stuck) }
        XCTAssertTrue(try XCTUnwrap(stuck.rally(id)).marching)
        stuck.watch += Rally.marchLimit + 1
        XCTAssertEqual(stuck.advanceRallies().last, .rallyDispersed(rally: id, caller: me))
        XCTAssertNil(stuck.unit(spear)?.errand)
    }

    func testAlliesKeepEachOthersGates() throws {
        let stage = try staged("gates")
        var state = stage.state
        let me = stage.me
        let theirSeat = try XCTUnwrap(state.seat(of: 1))
        let keeper = try company(.bow, of: me, near: theirSeat.position, in: &state)
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern }).id
        XCTAssertEqual(refusal(.reinforce(unit: lantern, hold: theirSeat.id), in: state, as: me), .cannotFight)
        XCTAssertEqual(refusal(.reinforce(unit: keeper, hold: 9_999), in: state, as: me), .unknownHold)
        XCTAssertEqual(refusal(.reinforce(unit: keeper, hold: try XCTUnwrap(state.seat(of: 3)).id), in: state, as: me), .notAnAllysHold)
        XCTAssertEqual(refusal(.reinforce(unit: keeper, hold: theirSeat.id), in: state, as: 1), .notYours)
        let sent = try state.perform(.reinforce(unit: keeper, hold: theirSeat.id), as: me)
        XCTAssertEqual(sent.first, .sentToReinforce(unit: keeper, owner: me, hold: theirSeat.id))
        XCTAssertEqual(state.tidings(of: sent[0], for: 1)?.text, "\(state.houses[me].title)'s Bows come to keep the gates of \(theirSeat.name).")
        XCTAssertEqual(state.tidings(of: sent[0], for: me)?.text, "Your Bows march to keep the gates of \(theirSeat.name).")
        XCTAssertEqual(state.events(sent, heardBy: 1).count, sent.count)
        for _ in 0..<3 { turn(&state) }
        let standing = try XCTUnwrap(state.unit(keeper))
        XCTAssertLessThanOrEqual(standing.position.distance(to: theirSeat.position), 1)
        XCTAssertEqual(state.keepers(of: theirSeat.id).map(\.id), [keeper])
        XCTAssertEqual(refusal(.reinforce(unit: keeper, hold: theirSeat.id), in: state, as: me), .alreadyThere)
        _ = try state.perform(.fortify(unit: keeper), as: me)
        XCTAssertEqual(state.unit(keeper)?.errand, .reinforce(hold: theirSeat.id), "Digging in at the gates is keeping them")

        // A company of House 2 strikes the hold from its gates: the keeper
        // strikes back, for its House is at war with House 2 too.
        _ = try state.declareWar(by: 1, on: 2)
        let beside = try XCTUnwrap(state.map.neighbors(of: theirSeat.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.isClear(hex)
        })
        let striker = state.put(.spear, of: 2, at: beside)
        let seatIndex = try XCTUnwrap(state.holdIndex(theirSeat.id))
        let garrisoned = state.unit(at: theirSeat.position)
        if let garrisoned { state.units.removeAll { $0.id == garrisoned.id } }
        state.holds[seatIndex].ward = state.holds[seatIndex].maximumWard
        let blows = try state.perform(.attack(unit: striker, target: theirSeat.position), as: 2)
        let battles = blows.compactMap { event -> Battle? in if case .battle(let battle) = event { return battle } else { return nil } }
        XCTAssertEqual(battles.first?.hold, theirSeat.id)
        XCTAssertEqual(battles.dropFirst().first?.attacker, keeper, "The keeper of the gates strikes back")
        XCTAssertEqual(battles.dropFirst().first?.defender, striker)
        XCTAssertLessThanOrEqual(try XCTUnwrap(state.unit(keeper)).position.distance(to: theirSeat.position), 1, "and holds its ground")

        // Against a House at war with the hold's but not with its own, it
        // stands by.
        var apart = stage.state
        _ = try apart.declareWar(by: 3, on: 1)
        let mine = try company(.bow, of: me, near: theirSeat.position, in: &apart)
        _ = try apart.perform(.reinforce(unit: mine, hold: theirSeat.id), as: me)
        for _ in 0..<3 { turn(&apart) }
        XCTAssertLessThanOrEqual(try XCTUnwrap(apart.unit(mine)).position.distance(to: theirSeat.position), 1)
        let foeSpot = try XCTUnwrap(apart.map.neighbors(of: theirSeat.position).first { hex in
            apart.map[hex]?.terrain.isPassable == true && apart.isClear(hex)
        })
        let foe = apart.put(.spear, of: 3, at: foeSpot)
        let alone = try apart.perform(.attack(unit: foe, target: theirSeat.position), as: 3)
        XCTAssertFalse(alone.contains { if case .battle(let battle) = $0 { return battle.attacker == mine } else { return false } })

        // An ally no longer an ally's gates are let go.
        _ = try apart.perform(.expel(house: 1), as: me)
        _ = apart.advanceRallies()
        XCTAssertNil(apart.unit(mine)?.errand)
    }

    func testRalliesAreSoundAndKeptInSaves() throws {
        let stage = try staged("sound rallies")
        var state = stage.state
        let me = stage.me
        state.holds[try XCTUnwrap(state.holdIndex(stage.seat))].levels[.musterHall] = 1
        _ = try state.perform(.callRally(from: stage.seat, against: stage.target, watches: 2), as: me)
        let id = try XCTUnwrap(state.ralliesStanding.first).id
        let spear = try company(.spear, of: me, near: stage.seatHex, in: &state)
        _ = try state.perform(.joinRally(rally: id, unit: spear), as: me)
        XCTAssertEqual(state.problems(), [])
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        let old = try JSONDecoder().decode(GameState.self, from: Scene.without(["rallies"], in: state))
        XCTAssertNil(old.rallies)

        func caught(_ text: String, _ change: (inout GameState) -> Void) {
            var broken = state
            change(&broken)
            XCTAssertTrue(broken.problems().contains { $0.contains(text) }, "\(text): \(broken.problems())")
        }
        caught("called two rallies") { $0.rallies!.append($0.rallies![0]) }
        caught("not its caller's") { $0.holds[$0.holdIndex(stage.seat)!].owner = 3 }
        caught("marches on no hold") { $0.holds.removeAll { $0.id == stage.target } }
        caught("not sent to it") { $0.units[$0.unitIndex(spear)!].errand = nil }
        caught("sent to no rally") { $0.rallies![0].companies = [] }
        caught("companies") { state in state.rallies![0].companies = Array(repeating: spear, count: 5) }
        caught("keeps the gates of no hold") { $0.units[$0.unitIndex(spear)!].errand = .reinforce(hold: 9_999) }
    }

    func testStewardsRallyAndKeepTheirAlliesGates() throws {
        let stage = try staged("steward rallies")
        var state = stage.state
        // House 1's steward, at war with House 2 beside the keeper, calls a
        // rally from a hold of its own with a Muster Hall near Thornwick.
        _ = try state.declareWar(by: 1, on: 2)
        let near = try XCTUnwrap(state.map.hexes.first { hex in
            (4...6).contains(hex.distance(to: stage.targetHex)) && state.map[hex]?.terrain == .greyfield && state.isClear(hex)
                && state.site(at: hex) == nil && state.holds.allSatisfy { $0.position.distance(to: hex) >= 3 }
        })
        var outpost = Hold(id: state.takeID(), name: "Wardholt", owner: 1, position: near, isSeat: false, foundedWatch: state.watch)
        outpost.levels[.musterHall] = 1
        state.holds.append(outpost)
        // It knows of Thornwick, and of no other hold of House 2's.
        state.houses[1].explored = Array(repeating: false, count: state.map.count)
        state.reveal(around: try XCTUnwrap(state.seat(of: 1)).position, range: 2, for: 1)
        state.reveal(around: stage.targetHex, range: 1, for: 1)
        state.watch = RivalMind.alliancesFrom
        state.houses[1].temperament = .ambitious
        var called: GameState?
        for seed in 0..<40 where called == nil {
            var trial = state
            var random = SeededRandom(seed: UInt64(seed))
            if !RivalMind(house: 1).callRally(in: &trial, random: &random).isEmpty { called = trial }
        }
        var rallied = try XCTUnwrap(called, "An ambitious steward calls a rally, now and then")
        let rally = try XCTUnwrap(rallied.ralliesStanding.first)
        XCTAssertEqual(rally.caller, 1)
        XCTAssertEqual(rally.target, stage.target)
        XCTAssertEqual(rally.muster, outpost.id)
        var random = SeededRandom(seed: 1)
        XCTAssertEqual(RivalMind(house: 1).callRally(in: &rallied, random: &random), [], "One at a time")

        // Its own companies, and an ally's, are sent: never the last a hold
        // would need.
        for _ in 0..<3 { try company(.spear, of: 1, near: near, in: &rallied) }
        let sent = RivalMind(house: 1).sendToRallies(in: &rallied)
        let joined = sent.filter { if case .rallyJoined = $0 { return true } else { return false } }
        XCTAssertEqual(joined.count, rallied.units(of: 1).filter(\.kind.isMilitary).count - rallied.holds(of: 1).count)
        XCTAssertGreaterThan(joined.count, 0)
        // A rally's company is the rally's: the steward gives it no orders.
        var ordered = rallied
        let before = ordered.units.filter { $0.errand == .rally(rally.id) }
        _ = ordered.stewardTurn(for: 1)
        for unit in before {
            XCTAssertEqual(ordered.unit(unit.id)?.errand, .rally(rally.id))
        }

        // A steward keeps an ally's gates while a foe of both is near them,
        // and leaves them when it's gone.
        var gates = stage.state
        _ = try gates.declareWar(by: 1, on: 2)
        let seat = stage.seatHex
        for _ in 0..<3 { try company(.spear, of: 1, near: seat, in: &gates) }
        let foe = try company(.rider, of: 2, near: seat, in: &gates)
        let kept = RivalMind(house: 1).keepAlliesGates(in: &gates)
        let keeperID = try XCTUnwrap(kept.compactMap { event -> Int? in
            if case .sentToReinforce(let unit, 1, stage.seat) = event { return unit } else { return nil }
        }.first)
        XCTAssertEqual(gates.unit(keeperID)?.errand, .reinforce(hold: stage.seat))
        XCTAssertEqual(RivalMind(house: 1).keepAlliesGates(in: &gates).filter { if case .sentToReinforce = $0 { return true } else { return false } }, [],
                       "One keeper to a hold")
        gates.units.removeAll { $0.id == foe }
        _ = RivalMind(house: 1).keepAlliesGates(in: &gates)
        XCTAssertNil(gates.unit(keeperID)?.errand, "The threat gone, the gates are left")
    }
}
