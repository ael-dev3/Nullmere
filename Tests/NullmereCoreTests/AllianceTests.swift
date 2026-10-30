import Foundation
import XCTest
@testable import NullmereCore

/// Alliances of several Houses under one leader: founded, joined by
/// invitation or by asking, left, cast out of, led anew when the leader
/// goes. Allies can't make war on each other, share their sight, and
/// hasten each other's works; an alliance takes a third of the seats.
final class AllianceTests: XCTestCase {
    /// A realm-sized lake, its first House a keeper's: room for alliances
    /// of four.
    private func lake(_ seed: String = "alliances") -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: 12, radius: 36, keepers: 1))
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

    func testABannerIsRaised() throws {
        var state = lake()
        let me = state.player
        XCTAssertEqual(state.allianceLimit, 4)
        XCTAssertEqual(refusal(.foundAlliance(name: "x"), in: state, as: me), .allianceNameInvalid)
        XCTAssertEqual(refusal(.foundAlliance(name: "The Grey Hand 7"), in: state, as: me), .allianceNameInvalid)
        XCTAssertEqual(refusal(.foundAlliance(name: String(repeating: "a", count: 25)), in: state, as: me), .allianceNameInvalid)
        let events = try state.perform(.foundAlliance(name: "  The Grey Hand "), as: me)
        let alliance = try XCTUnwrap(state.alliance(of: me))
        XCTAssertEqual(events, [.allianceFounded(alliance: alliance.id, house: me)])
        XCTAssertEqual(alliance.name, "The Grey Hand")
        XCTAssertEqual(alliance.leader, me)
        XCTAssertEqual(alliance.members, [me])
        XCTAssertEqual(alliance.founded, state.watch)
        XCTAssertTrue(state.chronicle.contains { $0.kind == .alliance && $0.text.contains("The Grey Hand") })
        XCTAssertEqual(refusal(.foundAlliance(name: "Another"), in: state, as: me), .inAnAlliance)
        XCTAssertEqual(refusal(.foundAlliance(name: "the grey hand"), in: state, as: 1), .allianceNameTaken)
        XCTAssertNil(refusal(.foundAlliance(name: "Saltward"), in: state, as: 1))
        XCTAssertTrue(Alliance.isValidName("O'Rourke's Pact"))
        XCTAssertFalse(Alliance.isValidName("-Pact"))
        XCTAssertNil(state.alliance(of: 1))
        XCTAssertFalse(state.areAllied(me, me), "A House is no ally of itself")
    }

    func testInvitationsAndRequests() throws {
        var state = lake("invitations")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "Lantern Oath"), as: me)
        let id = try XCTUnwrap(state.alliance(of: me)).id
        XCTAssertEqual(refusal(.inviteToAlliance(house: me), in: state, as: me), .unknownHouse)
        XCTAssertEqual(refusal(.inviteToAlliance(house: 99), in: state, as: me), .unknownHouse)
        XCTAssertEqual(refusal(.inviteToAlliance(house: 2), in: state, as: 1), .notInAlliance)

        // A steward answers at once, as its temper would.
        state.houses[1].temperament = .steadfast
        let answered = try state.perform(.inviteToAlliance(house: 1), as: me)
        XCTAssertEqual(answered, [.allianceInvited(alliance: id, house: 1), .allianceAnswered(alliance: id, house: 1, accepted: true),
                                  .allianceJoined(alliance: id, house: 1)])
        XCTAssertTrue(state.areAllied(me, 1))
        XCTAssertEqual(refusal(.inviteToAlliance(house: 2), in: state, as: 1), .notAllianceLeader)
        XCTAssertEqual(refusal(.inviteToAlliance(house: 1), in: state, as: me), .inAnAlliance)
        state.houses[2].temperament = .ambitious
        var strong = state
        let theirSeat = try XCTUnwrap(strong.seat(of: 2)).position
        for _ in 0..<4 { strong.put(.rider, tier: 3, of: 2, at: try XCTUnwrap(strong.freeHex(near: theirSeat, within: 1...3))) }
        let refused = try strong.perform(.inviteToAlliance(house: 2), as: me)
        XCTAssertEqual(refused.last, .allianceAnswered(alliance: id, house: 2, accepted: false), "The ambitious join no weaker alliance")
        XCTAssertEqual(strong.alliance(id)?.members, [me, 1])

        // A keeper answers in their own time.
        state.houses[3].isPlayer = true
        XCTAssertEqual(try state.perform(.inviteToAlliance(house: 3), as: me), [.allianceInvited(alliance: id, house: 3)])
        XCTAssertEqual(state.alliance(id)?.invited, [3])
        XCTAssertEqual(refusal(.inviteToAlliance(house: 3), in: state, as: me), .alreadyInvited)
        XCTAssertEqual(refusal(.answerInvitation(alliance: id, accept: true), in: state, as: 4), .noInvitation)
        var declined = state
        XCTAssertEqual(try declined.perform(.answerInvitation(alliance: id, accept: false), as: 3), [.allianceAnswered(alliance: id, house: 3, accepted: false)])
        XCTAssertEqual(declined.alliance(id)?.invited, [])
        let joined = try state.perform(.answerInvitation(alliance: id, accept: true), as: 3)
        XCTAssertEqual(joined, [.allianceAnswered(alliance: id, house: 3, accepted: true), .allianceJoined(alliance: id, house: 3)])
        XCTAssertEqual(state.alliance(id)?.members, [me, 1, 3])

        // Asking: a keeper's alliance's leader answers in their own time.
        XCTAssertEqual(refusal(.askToJoin(alliance: 4_242), in: state, as: 4), .unknownAlliance)
        XCTAssertEqual(try state.perform(.askToJoin(alliance: id), as: 4), [.allianceAsked(alliance: id, house: 4)])
        XCTAssertEqual(refusal(.askToJoin(alliance: id), in: state, as: 4), .alreadyAsked)
        XCTAssertEqual(refusal(.answerRequest(house: 5, accept: true), in: state, as: me), .noRequest)
        XCTAssertEqual(refusal(.answerRequest(house: 4, accept: true), in: state, as: 1), .noRequest, "Only its leader answers")
        XCTAssertEqual(try state.perform(.answerRequest(house: 4, accept: true), as: me),
                       [.allianceAnswered(alliance: id, house: 4, accepted: true), .allianceJoined(alliance: id, house: 4)])
        XCTAssertEqual(state.alliance(id)?.members.count, 4)
        XCTAssertEqual(refusal(.inviteToAlliance(house: 6), in: state, as: me), .allianceFull, "A third of the seats")
        XCTAssertEqual(refusal(.askToJoin(alliance: id), in: state, as: 6), .allianceFull)

        // No alliance takes in a war.
        var warring = lake("no war within")
        _ = try warring.perform(.foundAlliance(name: "Shorewatch"), as: warring.player)
        let shore = try XCTUnwrap(warring.alliance(of: warring.player)).id
        _ = try warring.declareWar(by: 5, on: warring.player)
        XCTAssertEqual(refusal(.inviteToAlliance(house: 5), in: warring, as: warring.player), .atWarWithAMember(warring.player))
        XCTAssertEqual(refusal(.askToJoin(alliance: shore), in: warring, as: 5), .atWarWithAMember(warring.player))
        XCTAssertEqual(refusal(.answerRequest(house: 5, accept: true), in: warring, as: warring.player), .noRequest)
        // An invitation that a war has since overtaken is answered no.
        warring.houses[6].isPlayer = true
        _ = try warring.perform(.inviteToAlliance(house: 6), as: warring.player)
        _ = try warring.declareWar(by: 6, on: warring.player)
        XCTAssertEqual(try warring.perform(.answerInvitation(alliance: shore, accept: true), as: 6).last,
                       .allianceAnswered(alliance: shore, house: 6, accepted: false))
    }

    func testAlliesMakeNoWarNorDemandsOnEachOther() throws {
        var state = lake("no war between allies")
        let me = state.player
        state.houses[1].temperament = .steadfast
        XCTAssertTrue(state.mayDemandTribute(by: me, of: 1))
        _ = try state.perform(.foundAlliance(name: "Quiet Banner"), as: me)
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        XCTAssertFalse(state.mayDemandTribute(by: me, of: 1), "No demands between allies")
        XCTAssertEqual(refusal(.declareWar(on: 1), in: state, as: me), .allyInAlliance(1))
        XCTAssertEqual(refusal(.declareWar(on: me), in: state, as: 1), .allyInAlliance(me))
        XCTAssertEqual(refusal(.propose(.tribute, to: 1), in: state, as: me), .allyInAlliance(1))
        XCTAssertNil(refusal(.declareWar(on: 2), in: state, as: me), "Others it may")
    }

    func testAlliesShareTheirSight() throws {
        var state = lake("shared sight")
        let me = state.player
        state.houses[1].temperament = .wary
        let theirs = try XCTUnwrap(state.units(of: 1).first)
        let tile = try XCTUnwrap(state.map.index(of: theirs.position))
        XCTAssertFalse(state.visibility(for: me)[tile], "Far off, unseen")
        _ = try state.perform(.foundAlliance(name: "Moonward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        XCTAssertTrue(state.areAllied(me, 1))
        XCTAssertTrue(state.visibility(for: me)[tile], "An ally's sight is its own")
        XCTAssertNotNil(state.view(for: me).unit(theirs.id))
    }

    func testLeavingCastingOutAndTheBannerPassed() throws {
        var state = lake("leaving")
        let me = state.player
        for house in 1...3 { state.houses[house].temperament = .steadfast }
        _ = try state.perform(.foundAlliance(name: "Ninefold"), as: me)
        let id = try XCTUnwrap(state.alliance(of: me)).id
        for house in 1...3 { _ = try state.perform(.inviteToAlliance(house: house), as: me) }
        XCTAssertEqual(state.alliance(id)?.members, [me, 1, 2, 3])

        XCTAssertEqual(refusal(.expel(house: 2), in: state, as: 1), .notAllianceLeader)
        XCTAssertEqual(refusal(.expel(house: 7), in: state, as: me), .notAMember)
        XCTAssertEqual(refusal(.expel(house: me), in: state, as: me), .notAMember)
        XCTAssertEqual(try state.perform(.expel(house: 3), as: me), [.allianceLeft(alliance: id, house: 3, expelled: true)])
        XCTAssertNil(state.alliance(of: 3))
        XCTAssertEqual(try state.perform(.leaveAlliance, as: 2), [.allianceLeft(alliance: id, house: 2, expelled: false)])
        XCTAssertEqual(refusal(.leaveAlliance, in: state, as: 2), .notInAlliance)
        XCTAssertEqual(refusal(.expel(house: 1), in: state, as: 2), .notInAlliance)

        // The leader goes: the banner passes to the strongest still sworn.
        for house in [2, 3] { _ = try state.perform(.inviteToAlliance(house: house), as: me) }
        let seat = try XCTUnwrap(state.seat(of: 3)).position
        for _ in 0..<4 { state.put(.rider, tier: 3, of: 3, at: try XCTUnwrap(state.freeHex(near: seat, within: 1...3))) }
        let left = try state.perform(.leaveAlliance, as: me)
        XCTAssertEqual(left, [.allianceLeft(alliance: id, house: me, expelled: false), .allianceLed(alliance: id, house: 3)])
        XCTAssertEqual(state.alliance(id)?.leader, 3)
        XCTAssertTrue(state.chronicle.contains { $0.text.contains("takes up the banner of Ninefold") })

        // A leader that falls is succeeded; an alliance with none left is no more.
        var falling = state
        _ = falling.eliminate(3, by: 5)
        XCTAssertFalse(falling.alliance(id)?.members.contains(3) ?? true)
        XCTAssertNotEqual(falling.alliance(id)?.leader, 3)
        _ = try state.perform(.leaveAlliance, as: 1)
        _ = try state.perform(.leaveAlliance, as: 2)
        XCTAssertEqual(try state.perform(.leaveAlliance, as: 3),
                       [.allianceLeft(alliance: id, house: 3, expelled: false), .allianceDisbanded(alliance: id, name: "Ninefold")])
        XCTAssertNil(state.alliance(id))
        XCTAssertTrue(state.alliancesStanding.isEmpty)
    }

    /// A steward that takes up a keeper's banner answers the Houses asking
    /// to join it, which the keeper had left waiting; a caretaker leaves
    /// them to the keeper.
    func testABannerTakenUpAnswersThoseAsking() throws {
        var state = lake("banner taken up")
        let me = state.player
        state.houses[1].temperament = .steadfast
        state.houses[2].isPlayer = true
        _ = try state.perform(.foundAlliance(name: "Wickward"), as: me)
        let id = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        _ = try state.perform(.askToJoin(alliance: id), as: 2)
        _ = try state.perform(.leaveAlliance, as: me)
        XCTAssertEqual(state.alliance(id)?.leader, 1)
        XCTAssertEqual(state.alliance(id)?.asking, [2])
        var random = SeededRandom(seed: 3)
        var kept = state
        XCTAssertEqual(RivalMind(house: 1, caretaking: true).tendAlliance(in: &kept, random: &random), [])
        XCTAssertEqual(kept.alliance(id)?.asking, [2])
        let events = RivalMind(house: 1).tendAlliance(in: &state, random: &random)
        XCTAssertEqual(Array(events.prefix(2)), [.allianceAnswered(alliance: id, house: 2, accepted: true), .allianceJoined(alliance: id, house: 2)])
        XCTAssertEqual(state.alliance(id)?.members, [1, 2])
    }

    /// Allies hasten each other's works, musters and studies: every second
    /// help takes a watch off one, never its last; each ally helps each
    /// once.
    func testAlliesHastenEachOthersWorks() throws {
        var state = lake("help")
        let me = state.player
        for house in 1...3 { state.houses[house].temperament = .steadfast }
        _ = try state.perform(.foundAlliance(name: "Hearthward"), as: me)
        for house in 1...3 { _ = try state.perform(.inviteToAlliance(house: house), as: me) }
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].project = Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 5)
        state.holds[seat].training = Hold.Training(kind: .spear, watchesLeft: 2)
        state.houses[me].research.pursuit = Pursuit(study: .drill, grade: 1, watchesLeft: 3)
        XCTAssertEqual(state.helpable(by: 1, for: me), 3)
        XCTAssertEqual(try state.perform(.help(house: me), as: 1), [.helpGiven(by: 1, to: me, count: 3)])
        XCTAssertEqual(state.holds[seat].project?.watchesLeft, 5, "One help is half a watch")
        XCTAssertEqual(refusal(.help(house: me), in: state, as: 1), .nothingToHelp, "Each helps each once")
        _ = try state.perform(.help(house: me), as: 2)
        XCTAssertEqual(state.holds[seat].project?.watchesLeft, 4, "Two helps, a watch")
        XCTAssertEqual(state.holds[seat].training?.watchesLeft, 1)
        XCTAssertEqual(state.houses[me].research.pursuit?.watchesLeft, 2)
        XCTAssertEqual(state.holds[seat].project?.helpers, [1, 2])
        state.holds[seat].project?.watchesLeft = 1
        state.holds[seat].project?.helpers = [1]
        _ = try state.perform(.help(house: me), as: 3)
        XCTAssertEqual(state.holds[seat].project?.watchesLeft, 1, "Never its last watch")
        XCTAssertEqual(refusal(.help(house: 5), in: state, as: 1), .notAnAlly)
        XCTAssertEqual(refusal(.help(house: 1), in: state, as: 1), .notAnAlly)
        XCTAssertEqual(state.helpable(by: 5, for: me), 0)
    }

    /// Allies know what each other has under way, so a keeper's own copy
    /// of the world can help it; no one else does.
    func testAlliesSeeWhatEachOtherHasUnderWay() throws {
        var state = lake("under way")
        let me = state.player
        state.houses[1].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Openhand"), as: me)
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        let theirs = try XCTUnwrap(state.holds.firstIndex { $0.owner == 1 && $0.isSeat })
        let others = try XCTUnwrap(state.holds.firstIndex { $0.owner == 2 && $0.isSeat })
        for index in [theirs, others] {
            state.holds[index].project = Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 4)
            state.holds[index].training = Hold.Training(kind: .spear, watchesLeft: 2)
        }
        state.houses[1].research.pursuit = Pursuit(study: .drill, grade: 1, watchesLeft: 3)
        state.houses[1].research.known = [Learned(study: .furrowLore, grade: 1)]
        var view = state.view(for: me)
        XCTAssertEqual(view.holds[theirs].project, state.holds[theirs].project)
        XCTAssertEqual(view.holds[theirs].training, state.holds[theirs].training)
        XCTAssertEqual(view.houses[1].research.pursuit, state.houses[1].research.pursuit)
        XCTAssertEqual(view.houses[1].research.known, [], "What it knows is its own")
        XCTAssertNil(view.holds[others].project)
        XCTAssertNil(state.view(for: 2).holds[theirs].project)
        XCTAssertEqual(try view.perform(.help(house: 1), as: me), [.helpGiven(by: me, to: 1, count: 3)])
    }

    /// Alliances are known to all; who is invited or asking, only to the
    /// alliance's Houses and the House concerned; and what passes between
    /// allies is heard by those it concerns.
    func testAViewKnowsAlliancesButNotTheirCounsel() throws {
        var state = lake("alliance counsel")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "Saltbound"), as: 1)
        let id = try XCTUnwrap(state.alliance(of: 1)).id
        state.houses[2].isPlayer = true
        state.houses[1].isPlayer = true
        _ = try state.perform(.inviteToAlliance(house: 2), as: 1)
        _ = try state.perform(.askToJoin(alliance: id), as: 3)
        let view = state.view(for: me)
        XCTAssertEqual(view.alliance(id)?.name, "Saltbound")
        XCTAssertEqual(view.alliance(id)?.invited, [])
        XCTAssertEqual(view.alliance(id)?.asking, [])
        XCTAssertEqual(state.view(for: 2).alliance(id)?.invited, [2], "The invited knows it is")
        XCTAssertEqual(state.view(for: 1).alliance(id)?.asking, [3], "Its own leader knows all")
        let events: [GameEvent] = [
            .allianceFounded(alliance: id, house: 1), .allianceInvited(alliance: id, house: 2), .allianceAsked(alliance: id, house: 3),
            .allianceAnswered(alliance: id, house: 3, accepted: false), .helpGiven(by: 1, to: 2, count: 1),
            .allianceJoined(alliance: id, house: 2), .allianceLeft(alliance: id, house: 2, expelled: false),
            .allianceLed(alliance: id, house: 1), .allianceDisbanded(alliance: id, name: "Saltbound"),
        ]
        XCTAssertEqual(state.events(events, heardBy: me), [
            .allianceFounded(alliance: id, house: 1), .allianceJoined(alliance: id, house: 2), .allianceLeft(alliance: id, house: 2, expelled: false),
            .allianceLed(alliance: id, house: 1), .allianceDisbanded(alliance: id, name: "Saltbound"),
        ])
        XCTAssertEqual(state.events(events, heardBy: 3).count, 7)
    }

    func testSavesFromBeforeAlliancesHaveNone() throws {
        var state = lake("older alliances")
        _ = try state.perform(.foundAlliance(name: "Old Oath"), as: state.player)
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == state.player && $0.isSeat })
        state.holds[seat].project = Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 3, helpers: [2])
        let old = try Scene.without(["alliances", "helpers"], in: state)
        let loaded = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertNil(loaded.alliances)
        XCTAssertNil(loaded.holds[seat].project?.helpers)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        var realm = RealmState(name: "R", seed: "parts of alliances", seats: 4, radius: 18, watchLength: 60, now: 0)
        realm.world.alliances = state.alliances
        XCTAssertEqual(try RealmState(parts: realm.parts(using: Scene.encoder)), realm)
    }

    func testStewardsTakeAndKeepAlliances() throws {
        var state = lake("steward alliances")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "Keeper's Banner"), as: me)
        let alliance = try XCTUnwrap(state.alliance(of: me))
        for temperament in Temperament.allCases {
            state.houses[1].temperament = temperament
            let takes = RivalMind(house: 1).acceptsInvitation(to: alliance, in: state)
            XCTAssertEqual(takes, temperament == .wary || temperament == .steadfast, "\(temperament)")
        }
        XCTAssertFalse(RivalMind(house: 1, caretaking: true).acceptsInvitation(to: alliance, in: state), "A caretaker swears no keeper in")
        var wronged = state
        wronged.houses[1].temperament = .steadfast
        _ = try wronged.declareWar(by: me, on: 1)
        wronged.setStance(.peace, between: me, and: 1, by: me)
        XCTAssertFalse(RivalMind(house: 1).acceptsInvitation(to: alliance, in: wronged), "Not with a House that wronged it")
        var feared = state
        feared.houses[1].temperament = .steadfast
        feared.holds[try XCTUnwrap(feared.holds.firstIndex { $0.owner == me && $0.isSeat })].levels[.moonspire] = 3
        XCTAssertFalse(RivalMind(house: 1).acceptsInvitation(to: alliance, in: feared), "Not beside a rising Moonspire")

        // A steward leading an alliance weighs those asking by its temper.
        var led = lake("steward leads")
        _ = try led.perform(.foundAlliance(name: "Steward's Banner"), as: 1)
        let theirs = try XCTUnwrap(led.alliance(of: 1))
        for (temperament, takes) in [(Temperament.steadfast, true), (.cunning, true), (.wary, false)] {
            led.houses[1].temperament = temperament
            XCTAssertEqual(RivalMind(house: 1).acceptsMember(2, to: theirs, in: led), takes, "\(temperament)")
        }
        led.houses[1].temperament = .wary
        led.setStance(.pact, between: 1, and: 2, by: 1)
        XCTAssertTrue(RivalMind(house: 1).acceptsMember(2, to: theirs, in: led), "The wary take a sworn friend")
        led.houses[1].temperament = .ambitious
        XCTAssertEqual(RivalMind(house: 1).acceptsMember(2, to: theirs, in: led), led.might(of: 2) <= led.might(of: 1))

        // Played out, the stewards raise banners and swear to them, and help
        // their allies.
        var realm = GameState(settings: GameSettings(seedText: "stewards ally", houseCount: 12, radius: 36, keepers: 0))
        var helped = 0
        for _ in 0..<60 where realm.outcome == nil {
            helped += realm.endWatch().filter { if case .helpGiven = $0 { return true } else { return false } }.count
        }
        XCTAssertFalse(realm.alliancesStanding.isEmpty, "Some banner stands")
        XCTAssertTrue(realm.alliancesStanding.contains { $0.members.count > 1 }, "and Houses are sworn to it")
        XCTAssertGreaterThan(helped, 0, "and allies help each other")
        XCTAssertEqual(realm.problems(), [])
    }

    func testUnsoundAlliancesAreCaught() throws {
        var state = lake("unsound alliances")
        state.houses[1].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Unsound"), as: state.player)
        _ = try state.perform(.inviteToAlliance(house: 1), as: state.player)
        func caught(_ text: String, _ change: (inout GameState) -> Void) {
            var broken = state
            change(&broken)
            XCTAssertTrue(broken.problems().contains { $0.contains(text) }, "\(text): \(broken.problems())")
        }
        caught("is led by a House not of it") { $0.alliances![0].leader = 5 }
        caught("sworn to two alliances") { $0.alliances!.append(Alliance(id: 999, name: "Twice", leader: 1, founded: 1)) }
        caught("at war") { $0.setStance(.war, between: 0, and: 1, by: 0) }
        caught("isn't standing") { $0.houses[1].isEliminated = true }
        caught("has no House") { $0.alliances![0].members = []; $0.alliances![0].leader = 0 }
        caught("Houses") { state in for house in 2...6 { state.alliances![0].members.append(house) } }
        caught("waits on House") { $0.alliances![0].invited = [1] }
    }

    func testAlliancesAreToldInTheGamesWords() throws {
        var state = lake("told alliances")
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "Greycloak"), as: me)
        let id = try XCTUnwrap(state.alliance(of: me)).id
        let them = state.houses[1].title
        func said(_ event: GameEvent, to viewer: Int? = nil) -> String? { state.tidings(of: event, for: viewer ?? me)?.text }
        XCTAssertEqual(said(.allianceFounded(alliance: id, house: me)), "You raise a banner: Greycloak.")
        XCTAssertEqual(said(.allianceFounded(alliance: id, house: me), to: 1), "\(state.houses[me].title) raises a banner: Greycloak.")
        XCTAssertEqual(said(.allianceInvited(alliance: id, house: 1), to: 1), "\(state.houses[me].title) invites you into Greycloak.")
        XCTAssertEqual(said(.allianceInvited(alliance: id, house: 1)), "\(them) is invited into Greycloak.")
        XCTAssertEqual(said(.allianceAsked(alliance: id, house: 1), to: 1), "You ask to join Greycloak.")
        XCTAssertEqual(said(.allianceAsked(alliance: id, house: 1)), "\(them) asks to join Greycloak.")
        XCTAssertNil(said(.allianceAnswered(alliance: id, house: 1, accepted: true)), "Told by its joining")
        XCTAssertEqual(said(.allianceAnswered(alliance: id, house: 1, accepted: false), to: 1), "There is no place for you in Greycloak now.")
        XCTAssertEqual(said(.allianceAnswered(alliance: id, house: 1, accepted: false)), "\(them) stays outside Greycloak.")
        XCTAssertEqual(said(.allianceAnswered(alliance: 777, house: 1, accepted: false)), "\(them) stays outside the alliance.",
                       "Told even of an alliance gone")
        XCTAssertEqual(said(.allianceJoined(alliance: id, house: 1), to: 1), "You are sworn to Greycloak.")
        XCTAssertEqual(state.tidings(of: .allianceJoined(alliance: id, house: 1), for: me), Tidings("\(them) joins Greycloak.", .good))
        XCTAssertEqual(state.tidings(of: .allianceJoined(alliance: id, house: 1), for: 2)?.tone, .neutral)
        XCTAssertEqual(said(.allianceLeft(alliance: id, house: me, expelled: true)), "You are cast out of Greycloak.")
        XCTAssertEqual(said(.allianceLeft(alliance: id, house: me, expelled: false)), "You leave Greycloak.")
        XCTAssertEqual(said(.allianceLeft(alliance: id, house: 1, expelled: true)), "\(them) is cast out of Greycloak.")
        XCTAssertEqual(said(.allianceLeft(alliance: 777, house: 1, expelled: false)), "\(them) leaves its alliance.")
        XCTAssertEqual(said(.allianceLed(alliance: id, house: me)), "The banner of Greycloak passes to you.")
        XCTAssertEqual(said(.allianceLed(alliance: id, house: 1)), "\(them) takes up the banner of Greycloak.")
        XCTAssertEqual(said(.allianceDisbanded(alliance: id, name: "Greycloak")), "Greycloak is no more.")
        XCTAssertEqual(said(.helpGiven(by: 1, to: me, count: 2)), "\(them) helps 2 of your works.")
        XCTAssertEqual(said(.helpGiven(by: me, to: 1, count: 1)), "You help 1 of \(them)'s work.")
        XCTAssertNil(said(.helpGiven(by: 1, to: 2, count: 1)))
        XCTAssertNil(said(.allianceInvited(alliance: 777, house: 1)))
        XCTAssertEqual(RuleError.atWarWithAMember(3).description, "No alliance takes in a House at war with one of its own.")
        XCTAssertEqual(RuleError.allyInAlliance(3).description, "Your House is sworn to the same alliance as theirs.")
        let texts = [RuleError.inAnAlliance, .notInAlliance, .notAllianceLeader, .allianceNameInvalid, .allianceNameTaken, .unknownAlliance,
                     .allianceFull, .alreadyInvited, .alreadyAsked, .noInvitation, .noRequest, .notAMember, .notAnAlly, .nothingToHelp].map(\.description)
        XCTAssertEqual(Set(texts).count, texts.count, "Each refusal its own words")
    }
}
