import Foundation
import NullmereCore
import NullmereModels
import NullmereSound
@testable import NullmereTrailer
import NullmereWorld
import XCTest

/// The trailer as it is staged before the Mac draws it: a minute and a
/// half and more, shot after shot, each world shot showing the world and
/// its own life, ending on the title; and its score, heard throughout.
final class TrailerTests: XCTestCase {
    static let houses: [Vec4] = (0..<12).map { Vec4(0.2 + Float($0) * 0.05, 0.3, 0.5, 1) }
    static let trailer = Trailer(houses: houses)

    func testItRunsAMinuteAndAHalfShotAfterShotAndEndsOnTheTitle() {
        let trailer = TrailerTests.trailer
        XCTAssertGreaterThanOrEqual(trailer.duration, 60)
        XCTAssertLessThanOrEqual(trailer.duration, 120)
        XCTAssertEqual(trailer.shots.first?.look, .lake, "It opens on the lake")
        XCTAssertEqual(trailer.shots.last?.look, .title, "It ends on the title")
        for (before, shot) in zip(trailer.shots, trailer.shots.dropFirst()) {
            XCTAssertEqual(shot.start, before.end, accuracy: 1e-9, "\(shot.name) follows \(before.name)")
            XCTAssertLessThan(shot.dissolve, shot.length)
        }
        XCTAssertEqual(trailer.frameCount, Int((trailer.duration * 30).rounded()))
        XCTAssertEqual(trailer.brightness(at: 0), 0, "Up from black")
        XCTAssertEqual(trailer.brightness(at: trailer.duration / 2), 1)
        XCTAssertEqual(trailer.brightness(at: trailer.duration), 0, "Down to black")
        XCTAssertEqual(trailer.title(at: trailer.titleRises - 1), 0)
        XCTAssertEqual(trailer.title(at: trailer.titleRises + 3), 1)
        XCTAssertLessThan(trailer.titleRises, trailer.fadesOut - 3, "The title holds before the picture goes")
        // Dissolves: the shot before shows through at a new shot's start.
        let battle = trailer.shots.first { $0.action == .battle }!
        let start = trailer.shot(at: battle.start)
        XCTAssertNotNil(start.from)
        XCTAssertEqual(start.weight, 0, accuracy: 1e-9)
        XCTAssertNil(trailer.shot(at: battle.start + battle.dissolve + 0.01).from)
    }

    func testItsWorldIsGrownKnownAndCrowned() throws {
        let world = TrailerTests.trailer.world
        let state = world.state
        XCTAssertEqual(world.holds.map(\.id), state.holds.map(\.id), "Every hold drawn")
        XCTAssertEqual(state.holds.first { $0.id == world.seat.id }?.position, world.seat.position, "The realm left as it was")
        XCTAssertEqual(world.seat.level(.moonspire), BuildingKind.moonspire.maxLevel, "The heart's Moonspire crowned")
        XCTAssertEqual(world.rising.level(.moonspire), 3, "Another rising, its crane at work")
        XCTAssertNotEqual(world.rising.owner, world.seat.owner)
        XCTAssertGreaterThan(state.holds.count, 24, "Holds about the whole lake")
        XCTAssertFalse(world.furniture.isEmpty)
        XCTAssertFalse(world.ways.isEmpty, "Ways for the carts")
    }

    func testEveryWorldShotShowsTheWorldAndItsOwnLife() throws {
        let trailer = TrailerTests.trailer
        for shot in trailer.shots where shot.look == .world {
            for u in [0.0, 0.5, 1.0] {
                let time = shot.start + u * shot.length
                let camera = trailer.camera(of: shot, at: time)
                XCTAssertTrue(camera.centerX.isFinite && camera.centerY.isFinite && camera.scale > 0, "\(shot.name) at \(u)")
                let scene = trailer.scene(of: shot, at: time)
                XCTAssertGreaterThan(scene.instanceCount, 100, "\(shot.name) at \(u): the world in view")
                XCTAssertEqual(scene.weather, shot.weather)
            }
        }
        // The march: its companies on the march, and their dust.
        let march = try XCTUnwrap(trailer.shots.first { $0.action == .march })
        var poses: [CompanyPose] = []
        var happenings = Happenings()
        trailer.march.stage(at: 4, in: trailer.world, poses: &poses, happenings: &happenings)
        XCTAssertEqual(poses.count, 7)
        XCTAssertTrue(poses.allSatisfy { $0.clip == .march })
        XCTAssertEqual(poses.compactMap(\.commander).count, 2, "Two commanders ride at their companies' heads")
        XCTAssertFalse(trailer.scene(of: march, at: march.start + 4).motes.isEmpty, "The dust of the march")
        // It moves on: its head further along a moment later.
        let early = trailer.march.head(at: 1), late = trailer.march.head(at: 6)
        XCTAssertGreaterThan(Vec3(late.x - early.x, 0, late.z - early.z).length, 2)
    }

    func testTheBattleTradesBlowsLoosesFallsAndBurns() throws {
        let trailer = TrailerTests.trailer
        let shot = try XCTUnwrap(trailer.shots.first { $0.action == .battle })
        XCTAssertEqual(shot.length, Battle.length)
        var clips: Set<Clip> = []
        var arrowsSeen = 0, strikes = 0, furies = 0
        for step in stride(from: 0.0, through: Battle.length, by: 0.25) {
            var poses: [CompanyPose] = []
            var arrows: [ArrowFlight] = []
            var happenings = Happenings()
            trailer.battle.stage(at: step, in: trailer.world, poses: &poses, arrows: &arrows, happenings: &happenings)
            XCTAssertEqual(poses.count, 16, "Five a side in front, three bows behind each")
            clips.formUnion(poses.map(\.clip))
            arrowsSeen += arrows.filter { (0...1).contains($0.progress) }.count
            strikes += happenings.strikes.count
            furies += happenings.furies.count
        }
        XCTAssertEqual(clips, [.idle, .attack, .death], "Standing, striking and falling")
        XCTAssertGreaterThan(arrowsSeen, 50, "Volleys in flight")
        XCTAssertGreaterThan(strikes, 50)
        XCTAssertGreaterThan(furies, 0, "Commanders' skills")
        let beats = trailer.battle.beats
        XCTAssertEqual(beats.filter { $0.sound == .fall }.count, 3)
        XCTAssertGreaterThan(beats.filter { if case .clash = $0.sound { return true } else { return false } }.count, 20)
        XCTAssertEqual(beats.map(\.time), beats.map(\.time).sorted())
        // After it, the fallen lie still and the rest stand.
        var after: [CompanyPose] = []
        var smoke = Happenings()
        trailer.battle.after(at: 2, in: trailer.world, poses: &after, happenings: &smoke)
        XCTAssertEqual(after.filter { $0.clip == .death }.count, 3)
        XCTAssertEqual(after.filter { $0.clip == .idle }.count, 13)
    }

    func testPicturesDissolveAndDarken() {
        let from: [UInt8] = [0, 100, 200, 255], into: [UInt8] = [255, 100, 0, 255]
        var a = from
        Pixels.dissolve(&a, into: into, weight: 0)
        XCTAssertEqual(a, from, "Nothing of the next yet")
        a = from
        Pixels.dissolve(&a, into: into, weight: 1)
        XCTAssertEqual(a, into, "All of the next")
        a = from
        Pixels.dissolve(&a, into: into, weight: 0.5)
        XCTAssertEqual(a, [128, 100, 100, 255], "Halfway")
        var b = from
        Pixels.darken(&b, to: 1)
        XCTAssertEqual(b, from, "As it is")
        Pixels.darken(&b, to: 0.5)
        XCTAssertEqual(b, [0, 50, 100, 127])
        Pixels.darken(&b, to: 0)
        XCTAssertEqual(b, [0, 0, 0, 0], "Black")
    }

    func testTheScoreIsHeardFromTheFirstMomentAndFollowsThePicture() throws {
        let trailer = TrailerTests.trailer
        let soundtrack = Soundtrack(trailer: trailer)
        XCTAssertEqual(soundtrack.duration, trailer.duration)
        XCTAssertEqual(soundtrack.events.map(\.time), soundtrack.events.map(\.time).sorted())
        let battle = try XCTUnwrap(trailer.shots.first { $0.action == .battle })
        let clashes = soundtrack.events.filter { if case .cue(.clash, _, _) = $0.event { return true } else { return false } }
        XCTAssertTrue(clashes.allSatisfy { $0.time >= battle.start && $0.time <= battle.end + 1 }, "Blows heard in the battle")
        // Its opening seconds: sound rising out of silence, never clipped.
        let (left, right) = soundtrack.render(until: 12)
        XCTAssertEqual(left.count, 12 * Soundtrack.sampleRate)
        func rms(_ samples: ArraySlice<Float>) -> Float { (samples.reduce(0) { $0 + $1 * $1 } / Float(max(samples.count, 1))).squareRoot() }
        let first = rms(left[0..<4_800]), later = rms(left[(8 * 48_000)..<(9 * 48_000)])
        XCTAssertLessThan(first, later, "It rises")
        XCTAssertGreaterThan(later, 0.01, "Heard")
        XCTAssertLessThanOrEqual(max(left.map(abs).max() ?? 0, right.map(abs).max() ?? 0), 0.9)
        let wav = Soundtrack.wav(left: Array(left.prefix(48_000)), right: Array(right.prefix(48_000)))
        XCTAssertEqual(wav.count, 44 + 48_000 * 4)
        XCTAssertEqual(String(decoding: wav.prefix(4), as: UTF8.self), "RIFF")
        if let directory = ProcessInfo.processInfo.environment["NULLMERE_TRAILER_SOUND"] {
            try Soundtrack.wav(left: left, right: right).write(to: URL(fileURLWithPath: directory).appendingPathComponent("trailer-opening.wav"))
        }
    }
}
