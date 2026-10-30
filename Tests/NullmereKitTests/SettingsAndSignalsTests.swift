import AVFoundation
import SwiftUI
import XCTest
import NullmereRealm
@testable import NullmereCore
@testable import NullmereKit

/// Volumes, rendered offline: each slider governs its own part of the sound.
final class VolumeTests: XCTestCase {
    private func render(_ synth: Synth, seconds: Float) -> [Float] {
        let frames = Int(seconds * 48_000)
        let chunk = 1024
        var out: [Float] = []
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        let left = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
        defer { left.deallocate(); right.deallocate() }
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: left)
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: right)
        var done = 0
        while done < frames {
            let n = min(chunk, frames - done)
            synth.render(frames: n, into: list)
            out.append(contentsOf: UnsafeBufferPointer(start: left, count: n))
            done += n
        }
        return out
    }

    private func synth(effects: Float = 1, ambience: Float = 1, music: Float = 1, score: Bool = false) -> Synth {
        let synth = Synth()
        synth.prepare(sampleRate: 48_000)
        synth.settle()
        synth.setMusic(on: score, mood: .peace)
        synth.setVolumes(effects: effects, ambience: ambience, music: music)
        return synth
    }

    private func rms(_ x: [Float]) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
    }

    /// The cue's own peak: the cued render less an identical plain one,
    /// with the night silent (its wind shares the cues' noise source).
    private func cuePeak(effects: Float) -> Float {
        let plain = synth(effects: effects, ambience: 0), cued = synth(effects: effects, ambience: 0)
        _ = render(plain, seconds: 0.5)
        _ = render(cued, seconds: 0.5)
        cued.trigger(.clash)
        let a = render(plain, seconds: 0.6), b = render(cued, seconds: 0.6)
        return zip(a, b).map { abs($1 - $0) }.max() ?? 0
    }

    /// Both ears' renders of a cue alone, the night silent.
    private func ears(_ cue: Ambience.Cue, at place: SoundPlace) -> (left: Float, right: Float) {
        let synth = synth(ambience: 0)
        synth.trigger(cue, at: place)
        let frames = 24_000
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        let left = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        let right = UnsafeMutablePointer<Float>.allocate(capacity: frames)
        defer { left.deallocate(); right.deallocate() }
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(frames * 4), mData: left)
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(frames * 4), mData: right)
        synth.render(frames: frames, into: list)
        return (rms(Array(UnsafeBufferPointer(start: left, count: frames))), rms(Array(UnsafeBufferPointer(start: right, count: frames))))
    }

    func testACueIsHeardFromWhereItHappened() {
        let middle = ears(.clash, at: .middle)
        XCTAssertEqual(middle.left, middle.right, accuracy: middle.left * 0.02, "In the middle, both ears alike")
        let right = ears(.clash, at: SoundPlace(pan: 1, gain: 1))
        XCTAssertGreaterThan(right.right, right.left * 3, "At the right edge, the right ear")
        XCTAssertGreaterThan(right.left, 0, "never gone from the other")
        let left = ears(.clash, at: SoundPlace(pan: -1, gain: 1))
        XCTAssertGreaterThan(left.left, left.right * 3)
        let far = ears(.clash, at: SoundPlace(pan: 0, gain: 0.3))
        XCTAssertEqual(far.left / middle.left, 0.3, accuracy: 0.03, "Far off, quieter")
        XCTAssertEqual(SoundPlace(pan: 4, gain: -1), SoundPlace(pan: 1, gain: 0), "Kept within its bounds")
        XCTAssertEqual(SoundPlace.middle.left, 1, accuracy: 0.001)
    }

    func testEffectsVolumeScalesTheCues() {
        let full = cuePeak(effects: 1)
        let half = cuePeak(effects: 0.5)
        XCTAssertEqual(half / full, 0.5, accuracy: 0.05)
        XCTAssertEqual(cuePeak(effects: 0), 0, accuracy: 0.0001)
    }

    func testTheNightAndTheScoreHaveTheirOwnVolumes() {
        XCTAssertLessThan(rms(render(synth(ambience: 0), seconds: 2)), 0.0001, "No drone, no wind")
        let scoreOnly = rms(render(synth(ambience: 0, music: 1, score: true), seconds: 20))
        let silenced = rms(render(synth(ambience: 0, music: 0, score: true), seconds: 20))
        XCTAssertGreaterThan(scoreOnly, 0.001)
        XCTAssertLessThan(silenced, 0.0001)
    }

    func testTheHoovesFallInTurn() {
        let plain = synth(ambience: 0), cued = synth(ambience: 0)
        cued.trigger(.ride)
        let a = render(plain, seconds: 0.4), b = render(cued, seconds: 0.4)
        let difference = zip(a, b).map { abs($1 - $0) }
        func peak(_ from: Double, _ to: Double) -> Float {
            difference[Int(from * 48_000)..<Int(to * 48_000)].max() ?? 0
        }
        // Each hoof lands after the one before has faded.
        XCTAssertGreaterThan(peak(0, 0.03), peak(0.08, 0.115) * 2)
        XCTAssertGreaterThan(peak(0.12, 0.15), peak(0.08, 0.115) * 2)
        XCTAssertGreaterThan(peak(0.21, 0.24), peak(0.08, 0.115) * 2)
    }

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
