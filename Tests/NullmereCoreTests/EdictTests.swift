import Foundation
import XCTest
@testable import NullmereCore

/// Edicts of the realm: a keeper's House of two holds puts a law to the
/// realm, every House votes over three watches with its might, and an
/// edict passed holds every House for twenty watches, the breaker named
/// and fined, and the stewards keeping it.
final class EdictTests: XCTestCase {
    /// A lake of four Houses, two of them keepers', the first with a
    /// second hold and stores to spend.
    private func world(_ seed: String = "edicts") throws -> (GameState, me: Int, other: Int) {
        var state = Scene.world(seed, houses: 4, radius: 16)
        let me = state.player
        let other = (me + 1) % 4
        state.houses[other].isPlayer = true
        state.houses[me].stock = Stock(grain: 400, timber: 200, stone: 200, moonsalt: 40)
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me })
        let ground = try XCTUnwrap(state.freeHex(near: seat.position, within: 3...4))
        state.holds.append(Hold(id: state.takeID(), name: "Second", owner: me, position: ground, isSeat: false, foundedWatch: 1))
        return (state, me, other)
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

    /// The watch turned until an edict's vote closes, with what was told.
    private func closeTheVote(_ state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        for _ in 0..<GameState.edictVote { events += state.endWatch() }
        return events
    }

    func testAnEdictIsPutToTheRealmVotedOnAndHolds() throws {
        var (state, me, other) = try world()
        for house in state.houses.indices where !state.houses[house].isPlayer { state.houses[house].temperament = .wary }
        let grain = state.houses[me].stock.grain
        let events = try state.perform(.proposeEdict(kind: .safeConduct), as: me)
        let edict = try XCTUnwrap(state.edictInVote)
        XCTAssertEqual(events, [.edictProposed(edict)])
        XCTAssertEqual(edict.ayes, [me], "Its proposer is for it")
        XCTAssertEqual(state.houses[me].stock.grain, grain - GameState.edictCost.grain)
        XCTAssertEqual(state.chronicle.last?.kind, .edict)
        XCTAssertEqual(state.tidings(of: events[0], for: other)?.text, "\(state.houses[me].title) puts Safe Conduct to the realm: "
                       + "no House strikes Founders or Lanterns. Every House votes aye or nay, each with its might, for 3 watches.")
        XCTAssertEqual(state.watchesToVote(on: edict), GameState.edictVote)

        // Another keeper votes; once.
        XCTAssertEqual(try state.perform(.voteEdict(edict: edict.id, aye: true), as: other), [.edictVoted(edict: edict.id, house: other, aye: true)])
        XCTAssertEqual(refusal(.voteEdict(edict: edict.id, aye: false), in: state, as: other), .votedAlready)
        XCTAssertEqual(state.tidings(of: .edictVoted(edict: edict.id, house: other, aye: true), for: other)?.text, "Your House votes aye.")
        XCTAssertNil(state.tidings(of: .edictVoted(edict: edict.id, house: other, aye: true), for: me), "Each vote is not told to all")

        // The stewards vote as the watch turns; three watches on, the vote closes.
        let turned = closeTheVote(&state)
        let closed = try XCTUnwrap(state.edictsOfTheRealm.first { $0.id == edict.id })
        XCTAssertEqual(closed.ayes.count + closed.nays.count, state.livingHouses.count, "Every House voted")
        XCTAssertTrue(closed.passed)
        XCTAssertEqual(closed.closed, edict.proposed + GameState.edictVote)
        XCTAssertTrue(turned.contains(.edictPassed(closed)))
        XCTAssertEqual(state.tidings(of: .edictPassed(closed), for: other)?.text,
                       "The realm passes Safe Conduct: for 20 watches no House strikes Founders or Lanterns.")
        XCTAssertTrue(state.chronicle.contains { $0.kind == .edict && $0.text.hasPrefix("The realm passes Safe Conduct, ") })
        XCTAssertEqual(state.edictsInForce.map(\.id), [edict.id])
        XCTAssertEqual(state.watchesLeft(of: closed), GameState.edictLasts)
        XCTAssertNil(state.edictInVote)
        XCTAssertEqual(state.problems(), [])

        // Known to every House; kept as the world is.
        XCTAssertEqual(state.view(for: other).edictsOfTheRealm, state.edictsOfTheRealm)
        XCTAssertTrue(state.events(turned.filter { if case .edictPassed = $0 { return true } else { return false } }, heardBy: other).count == 1)
        let data = try JSONEncoder().encode(state)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: data), state)

        // Twenty watches on, it holds the realm no longer, told once.
        var lapsed: [GameEvent] = []
        for _ in 0..<GameState.edictLasts { lapsed += state.endWatch() }
        XCTAssertEqual(lapsed.filter { if case .edictLapsed = $0 { return true } else { return false } }.count, 1)
        XCTAssertTrue(state.edictsInForce.isEmpty)
        XCTAssertEqual(state.tidings(of: .edictLapsed(closed), for: me)?.text, "Safe Conduct holds the realm no longer.")
    }

    func testAnEdictTheMightierRefuseFails() throws {
        var (state, me, _) = try world("edicts refused")
        for house in state.houses.indices { state.houses[house].isPlayer = true }
        _ = try state.perform(.proposeEdict(kind: .moonPeace), as: me)
        let edict = try XCTUnwrap(state.edictInVote)
        for house in state.houses.indices where house != me {
            _ = try state.perform(.voteEdict(edict: edict.id, aye: false), as: house)
        }
        let (aye, nay) = state.tally(of: try XCTUnwrap(state.edictInVote))
        XCTAssertGreaterThan(nay, aye, "Three Houses' might against one")
        let turned = closeTheVote(&state)
        let closed = try XCTUnwrap(state.edictsOfTheRealm.first)
        XCTAssertFalse(closed.passed)
        XCTAssertEqual(closed.ayeMight, aye)
        XCTAssertTrue(turned.contains(.edictFailed(closed)))
        XCTAssertEqual(state.tidings(of: .edictFailed(closed), for: me)?.text, "The realm refuses the Moon's Peace.")
        XCTAssertTrue(state.edictsInForce.isEmpty)
        XCTAssertTrue(state.chronicle.contains { $0.text == "The realm refuses the Moon's Peace, 3 of 4 Houses against it." })
    }

    func testOnlyAKeepersHouseOfTwoHoldsPutsOneAtATime() throws {
        var (state, me, other) = try world("edicts refusals")
        let steward = try XCTUnwrap(state.houses.indices.first { !state.houses[$0].isPlayer })
        XCTAssertEqual(refusal(.proposeEdict(kind: .holyGround), in: state, as: steward), .notAKeeper)
        XCTAssertEqual(refusal(.proposeEdict(kind: .holyGround), in: state, as: other), .tooFewHolds)
        var poor = state
        poor.houses[me].stock = .zero
        XCTAssertEqual(refusal(.proposeEdict(kind: .holyGround), in: poor, as: me), .shortOf(Stock.zero.shortfall(for: GameState.edictCost)))
        _ = try state.perform(.proposeEdict(kind: .holyGround), as: me)
        let edict = try XCTUnwrap(state.edictInVote)
        XCTAssertEqual(refusal(.proposeEdict(kind: .harvestTruce), in: state, as: me), .edictInVote)
        XCTAssertEqual(refusal(.voteEdict(edict: 424_242, aye: true), in: state, as: other), .unknownEdict)
        XCTAssertEqual(refusal(.voteEdict(edict: edict.id, aye: true), in: state, as: steward), .notAKeeper, "Stewards vote as the watch turns")
        _ = closeTheVote(&state)
        XCTAssertEqual(refusal(.voteEdict(edict: edict.id, aye: true), in: state, as: other), .voteClosed)
        XCTAssertEqual(refusal(.proposeEdict(kind: .harvestTruce), in: state, as: me), .proposedLately)
        if state.edictsOfTheRealm.first?.passed == true {
            // Another keeper's House of two holds, putting what holds already.
            let seat = try XCTUnwrap(state.holds.first { $0.owner == other })
            let ground = try XCTUnwrap(state.freeHex(near: seat.position, within: 3...4))
            state.holds.append(Hold(id: state.takeID(), name: "Other's", owner: other, position: ground, isSeat: false, foundedWatch: 1))
            state.houses[other].stock = Stock(grain: 400, moonsalt: 40)
            XCTAssertEqual(refusal(.proposeEdict(kind: .holyGround), in: state, as: other), .edictInForce)
        }
        XCTAssertEqual(RuleError.tooFewHolds.description, "Only a House of two holds or more may put an edict to the realm.")
        XCTAssertEqual(RuleError.edictInVote.description, "An edict is before the realm already; another when its vote is done.")
    }

    func testABreakerIsNamedAndFinedOnceAWatchAndTheStewardsKeepIt() throws {
        var (state, me, other) = try world("edicts broken")
        state.edicts = [Edict(id: 7, kind: .safeConduct, proposer: me, proposed: 1, ayes: [me], closed: state.watch, ayeMight: 10, nayMight: 0)]
        state.setStance(.war, between: me, and: other, by: me)
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat })
        let at = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3))
        let founder = state.put(.founder, of: other, at: try XCTUnwrap(state.freeHex(near: at)))
        let target = try XCTUnwrap(state.unit(founder)).position
        let spear = state.put(.spear, of: me, at: at)
        let second = state.put(.spear, of: me, at: try XCTUnwrap(state.map.neighbors(of: target).first { state.isClear($0) && state.map[$0]?.terrain.isPassable == true }))
        let (mine, theirs) = (state.houses[me].stock, state.houses[other].stock)

        let events = try state.perform(.attack(unit: spear, target: target), as: me)
        let fine = Stock(grain: min(mine.grain, GameState.edictFine.grain), timber: min(mine.timber, GameState.edictFine.timber),
                         stone: min(mine.stone, GameState.edictFine.stone), moonsalt: min(mine.moonsalt, GameState.edictFine.moonsalt))
        XCTAssertEqual(events.first, .edictBroken(edict: 7, kind: .safeConduct, by: me, against: other, fine: fine))
        XCTAssertEqual(state.houses[me].stock.moonsalt, mine.moonsalt - fine.moonsalt)
        XCTAssertGreaterThanOrEqual(state.houses[other].stock.moonsalt, min(theirs.moonsalt + fine.moonsalt, state.storage(of: other)))
        XCTAssertEqual(state.breaches(by: me), 1)
        XCTAssertTrue(state.chronicle.contains { $0.kind == .betrayal && $0.text.hasPrefix("\(state.houses[me].title) breaks Safe Conduct, striking \(state.houses[other].title)") })
        XCTAssertEqual(state.tidings(of: events[0], for: other)?.text,
                       "\(state.houses[me].title) breaks Safe Conduct, striking your House, and pays you \(fine).")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text,
                       "Your House breaks Safe Conduct, striking \(state.houses[other].title), and pays them \(fine).")
        // Once a watch for each edict.
        if state.unit(founder) != nil {
            let again = try state.perform(.attack(unit: second, target: target), as: me)
            XCTAssertFalse(again.contains { if case .edictBroken = $0 { return true } else { return false } })
        }
        XCTAssertEqual(state.problems(), [])

        // A steward at war with Founders in reach leaves them be while it holds.
        var keeping = state
        keeping.watch += 1
        keeping.houses[me].isPlayer = false
        keeping.units.removeAll { $0.owner == me && $0.id != spear }
        // Each hold kept by a company of its own, so this one is free to campaign.
        for hold in keeping.holds(of: me) where keeping.unit(at: hold.position) == nil {
            keeping.put(.spear, of: me, at: hold.position)
        }
        let index = try XCTUnwrap(keeping.units.firstIndex { $0.id == spear })
        keeping.units[index].movesLeft = 2
        keeping.units[index].health = 100
        let near = try XCTUnwrap(keeping.map.neighbors(of: keeping.units[index].position).first {
            keeping.isClear($0) && keeping.map[$0]?.terrain.isPassable == true
        })
        let fresh = keeping.put(.founder, of: other, at: near)
        var lawless = keeping
        lawless.edicts = nil
        _ = lawless.stewardTurn(for: me)
        XCTAssertNotEqual(lawless.unit(fresh)?.health, 100, "With no edict, the steward strikes them")
        let before = keeping.breaches(by: me)
        _ = keeping.stewardTurn(for: me)
        XCTAssertEqual(keeping.breaches(by: me), before, "The steward kept Safe Conduct")
        XCTAssertEqual(keeping.unit(fresh)?.health, 100)
    }

    func testWhatEachEdictForbids() throws {
        var (state, me, other) = try world("what edicts forbid")
        let theirSeat = try XCTUnwrap(state.holds.first { $0.owner == other && $0.isSeat })
        let striker = NullmereCore.Unit(id: 900_001, kind: .spear, owner: me, position: try XCTUnwrap(state.map.neighbors(of: theirSeat.position).first))
        func inForce(_ kind: EdictKind) {
            state.edicts = [Edict(id: 1, kind: kind, proposer: me, proposed: state.watch, ayes: [me], closed: state.watch, ayeMight: 1, nayMight: 0)]
        }
        // The Moon's Peace: a hold, about the full moon only.
        state.watch = GameState.lunarMonth * 3
        inForce(.moonPeace)
        XCTAssertTrue(GameState.moonIsFull(at: state.watch))
        XCTAssertEqual(state.edictsBroken(striking: theirSeat.position, from: striker).map(\.kind), [.moonPeace])
        state.watch += GameState.lunarMonth / 2
        inForce(.moonPeace)
        XCTAssertFalse(GameState.moonIsFull(at: state.watch))
        XCTAssertEqual(state.edictsBroken(striking: theirSeat.position, from: striker), [])

        // The Harvest Truce: a company out at the land's work.
        let hex = try XCTUnwrap(state.freeHex(near: theirSeat.position, within: 3...4))
        let gatherer = state.put(.spear, of: other, at: hex)
        inForce(.harvestTruce)
        XCTAssertEqual(state.edictsBroken(striking: hex, from: striker), [])
        state.units[try XCTUnwrap(state.units.firstIndex { $0.id == gatherer })].errand = .homeward
        XCTAssertEqual(state.edictsBroken(striking: hex, from: striker).map(\.kind), [.harvestTruce])

        // Holy Ground: a company standing on a holy site.
        inForce(.holyGround)
        XCTAssertEqual(state.edictsBroken(striking: hex, from: striker), [])
        state.shrines = [Shrine(id: state.takeID(), kind: .moonwell, position: hex)]
        XCTAssertEqual(state.edictsBroken(striking: hex, from: striker).map(\.kind), [.holyGround])

        // Nothing holds once its watches are done; nor against one's own.
        state.watch += GameState.edictLasts
        XCTAssertEqual(state.edictsBroken(striking: hex, from: striker), [])
        XCTAssertEqual(EdictKind.moonPeace.heading, "The Moon's Peace")

        // How the stewards vote.
        state.houses[other].temperament = .wary
        XCTAssertTrue(state.stewardVotesAye(on: .moonPeace, as: other))
        state.houses[other].temperament = .ambitious
        let weaker = (state.byMight.firstIndex(of: other) ?? 0) >= state.byMight.count / 2
        XCTAssertEqual(state.stewardVotesAye(on: .moonPeace, as: other), weaker)
        state.shrines = [Shrine(id: state.takeID(), kind: .moonwell, position: hex, holder: other)]
        XCTAssertTrue(state.stewardVotesAye(on: .holyGround, as: other), "A holder of a holy site")

        // Unsound edicts.
        var unsound = state
        unsound.edicts = [Edict(id: 3, kind: .moonPeace, proposer: 99, proposed: 5, ayes: [me, me], closed: 2),
                          Edict(id: 4, kind: .holyGround, proposer: me, proposed: 5), Edict(id: 5, kind: .safeConduct, proposer: me, proposed: 6)]
        let problems = unsound.problems()
        XCTAssertTrue(problems.contains("Edict 3 names a House that isn't"), "\(problems)")
        XCTAssertTrue(problems.contains("Edict 3 counts a House's vote twice"))
        XCTAssertTrue(problems.contains("Edict 3 closed before it was put"))
        XCTAssertTrue(problems.contains("More than one edict is before the realm"))
    }
}
