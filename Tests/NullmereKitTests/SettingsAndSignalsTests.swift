import AVFoundation
import SwiftUI
import XCTest
import NullmereRealm
@testable import NullmereCore
@testable import NullmereKit

/// Volumes: each slider remembered and given to the sound. That each
/// governs its own part is measured in NullmereSoundTests.
final class VolumeTests: XCTestCase {
    @MainActor
    func testVolumesAreRememberedAndApplied() {
        let keys = ["volume.effects", "volume.ambience", "volume.music"]
        keys.forEach { UserDefaults.standard.removeObject(forKey: $0) }
        defer { keys.forEach { UserDefaults.standard.removeObject(forKey: $0) } }
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let identity = FileIdentityStore(url: dir.appendingPathComponent("identity"))
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: "volumes"), identity: identity)
        app.effectsVolume = 0.3
        app.musicVolume = 0.6
        XCTAssertEqual(UserDefaults.standard.double(forKey: "volume.effects"), 0.3)
        XCTAssertEqual(app.ambience.effectsVolume, 0.3, accuracy: 0.0001)
        XCTAssertEqual(app.ambience.musicVolume, 0.6, accuracy: 0.0001)
        let again = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: "volumes"), identity: identity)
        XCTAssertEqual(again.effectsVolume, 0.3)
        XCTAssertEqual(again.ambience.effectsVolume, 0.3, accuracy: 0.0001)
        XCTAssertEqual(again.ambienceVolume, 1)
    }
}

@MainActor
final class SignalsTests: XCTestCase {
    private func session(_ state: GameState) -> (GameSession, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        return (GameSession(state: state, store: LocalStore(directory: dir)), dir)
    }

    func testEachKindOfCompanySoundsItsOwn() throws {
        var state = GameState(settings: GameSettings(seedText: "voices of war", houseCount: 3, radius: 16, keepers: 1))
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let rider = try XCTUnwrap(state.placeUnit(.rider, for: state.player, near: seat.position))
        let spear = try XCTUnwrap(state.units(of: state.player).first { $0.kind == .spear })
        let to = rider.position
        XCTAssertEqual(GameSession.cues(for: .move(unit: rider.id, to: to), events: [], in: state, player: state.player), [.ride])
        XCTAssertEqual(GameSession.cues(for: .move(unit: spear.id, to: to), events: [], in: state, player: state.player), [.order])
        let ruin = GameEvent.ruinSearched(at: to, by: state.player, reward: Stock(stone: 20))
        XCTAssertEqual(GameSession.cues(for: .move(unit: spear.id, to: to), events: [ruin], in: state, player: state.player), [.order, .rise],
                       "A drowned ruin searched on the way rises after the march")
        func battle(_ kind: UnitKind) -> GameEvent {
            .battle(Battle(attacker: 1, attackerOwner: state.player, attackerKind: kind, defender: 2, defenderOwner: 1,
                           defenderKind: .spear, hold: nil, at: to, damageDealt: 10, damageTaken: 0,
                           attackerFell: false, defenderFell: false))
        }
        XCTAssertEqual(GameSession.cues(for: .attack(unit: 1, target: to), events: [battle(.bow)], in: state, player: state.player), [.loose])
        XCTAssertEqual(GameSession.cues(for: .attack(unit: 1, target: to), events: [battle(.spear)], in: state, player: state.player), [.clash])
        XCTAssertEqual(GameSession.cues(for: .attack(unit: 1, target: to), events: [battle(.mangonel)], in: state, player: state.player), [.batter],
                       "a Mangonel's stone lands as a ram's blow")
        XCTAssertEqual(GameSession.cues(for: .attack(unit: 1, target: to), events: [], in: state, player: state.player), [.clash])
        XCTAssertEqual(GameSession.cues(for: .build(hold: seat.id, kind: .granary), events: [], in: state, player: state.player), [.rise])
    }

    func testWatchmenSeeEnemiesGather() throws {
        var state = GameState(settings: GameSettings(seedText: "gathering", houseCount: 3, radius: 16, keepers: 1))
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let near = seat.position.ring(2).filter { state.map[$0]?.terrain.isPassable == true && state.unit(at: $0) == nil }
        XCTAssertGreaterThanOrEqual(near.count, 2)
        for hex in near.prefix(2) {
            state.units.append(NullmereCore.Unit(id: 70_000 + state.units.count, kind: .spear, owner: 1, position: hex))
        }
        let visible = state.visibility(for: state.player)
        XCTAssertTrue(Sentinel.threats(in: state, player: state.player, visible: visible).isEmpty, "Not while at peace")
        _ = try state.declareWar(by: 1, on: state.player)
        let threats = Sentinel.threats(in: state, player: state.player, visible: visible)
        XCTAssertEqual(threats, [Sentinel.Threat(hold: seat.id, house: 1, companies: 2)])
        XCTAssertTrue(Sentinel.line(for: threats[0], in: state).text.contains(seat.name))
        let blind = visible.map { _ in false }
        XCTAssertTrue(Sentinel.threats(in: state, player: state.player, visible: blind).isEmpty, "Only what can be seen")

        let (session, dir) = session(state)
        defer { try? FileManager.default.removeItem(at: dir) }
        XCTAssertEqual(session.threatened, [seat.id], "The hold is marked on the map")
    }

    func testQuietWatchesPassUntilSomethingNeedsThePlayer() throws {
        var state = GameState(settings: GameSettings(seedText: "quiet watches", houseCount: 3, radius: 16, keepers: 1))
        for index in state.units.indices where state.units[index].owner == state.player {
            state.units[index].fortified = true
        }
        let seat = try XCTUnwrap(state.seat(of: state.player))
        _ = try state.perform(.build(hold: seat.id, kind: .granary), as: state.player)
        let (session, dir) = session(state)
        defer { try? FileManager.default.removeItem(at: dir) }
        let start = session.state.watch
        XCTAssertFalse(GameSession.needsPlayer(after: [], from: state, to: state, player: state.player, threatened: []))
        session.endWatchesUntilNeeded()
        let passed = session.state.watch - start
        XCTAssertGreaterThan(passed, 1, "Quiet watches pass together")
        XCTAssertLessThanOrEqual(passed, GameSession.quietWatchLimit)
        XCTAssertTrue(session.notices.contains { $0.text == "\(passed) quiet watches pass." })
        XCTAssertNil(session.state.outcome)
        // Short of the limit, it stopped because the seat stands idle.
        if passed < GameSession.quietWatchLimit {
            XCTAssertTrue(session.idleHolds.contains { $0.id == seat.id }, "Stopped at \(passed): the seat stands idle")
        }
    }
}

@MainActor
final class GrowingHoldTests: XCTestCase {
    func testAHoldRaisesTowersAsItGrows() {
        var hold = Hold(id: 1, name: "Test", owner: 0, position: Hex(0, 0), isSeat: false, foundedWatch: 1)
        XCTAssertEqual(TokenArt.towerCount(for: hold), 0)
        hold.levels[.walls] = 5
        hold.levels[.moonspire] = 3
        XCTAssertEqual(TokenArt.towerCount(for: hold), 0, "Walls and the spire have their own marks")
        hold.levels[.granary] = 2
        hold.levels[.quarry] = 1
        XCTAssertEqual(TokenArt.towerCount(for: hold), 1)
        hold.levels[.sawpit] = 5
        XCTAssertEqual(TokenArt.towerCount(for: hold), 2)

        let c = CGPoint(x: 100, y: 100)
        let keep = TokenArt.keep(at: c, radius: 12, seat: false).boundingRect
        let one = TokenArt.towers(at: c, radius: 12, count: 1).boundingRect
        let two = TokenArt.towers(at: c, radius: 12, count: 2).boundingRect
        XCTAssertLessThan(one.minX, keep.minX, "A tower stands beside the keep")
        XCTAssertGreaterThan(two.maxX, keep.maxX, "and a second on the other side")
        XCTAssertLessThan(one.height, keep.height, "lower than the keep")
        XCTAssertTrue(TokenArt.towers(at: c, radius: 12, count: 0).isEmpty)
    }
}

/// The advisor: new counsel spoken in the Mac's voice, when it may be.
@MainActor
final class AdvisorTests: XCTestCase {
    private final class Ear: Speaking {
        var heard: [String] = []
        var hushed = 0
        func say(_ words: String) { heard.append(words) }
        func hush() { hushed += 1 }
    }

    func testTheAdvisorSpeaksNewCounselWhenItMay() {
        let ear = Ear()
        var voiceOver = false
        let advisor = Advisor(voice: ear, enabled: true, voiceOver: { voiceOver })
        XCTAssertTrue(advisor.counsel("Raise a Granary."))
        XCTAssertFalse(advisor.counsel("Raise a Granary."), "Never the same counsel twice running")
        voiceOver = true
        XCTAssertFalse(advisor.counsel("Muster a company."), "VoiceOver reads the charges itself")
        voiceOver = false
        advisor.isSoundOn = false
        XCTAssertFalse(advisor.counsel("Muster a company."), "Silent with the sound")
        XCTAssertEqual(ear.hushed, 1, "and hushed as it goes")
        advisor.isSoundOn = true
        advisor.isEnabled = false
        XCTAssertFalse(advisor.counsel("Muster a company."))
        XCTAssertEqual(ear.hushed, 2)
        advisor.isEnabled = true
        XCTAssertTrue(advisor.counsel("Muster a company."))
        XCTAssertEqual(ear.heard, ["Raise a Granary.", "Muster a company."])
        // The Mac's own voice is made and hushed without a word said; it
        // would speak a little slower and lower than the Mac's own way.
        MacVoice().hush()
        let utterance = MacVoice.utterance("Raise a Granary.")
        XCTAssertEqual(utterance.speechString, "Raise a Granary.")
        XCTAssertLessThan(utterance.rate, AVSpeechUtteranceDefaultSpeechRate)
        XCTAssertLessThan(utterance.pitchMultiplier, 1)
        XCTAssertLessThan(utterance.volume, 1)
        XCTAssertEqual(Advisor.defaultsKey, "advisor.speaks")
    }
}
