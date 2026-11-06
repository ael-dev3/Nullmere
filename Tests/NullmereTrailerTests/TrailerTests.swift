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
        XCTAssertEqual(Trailer.framesPerSecond, 60)
        XCTAssertEqual(trailer.frameCount, Int((trailer.duration * 60).rounded()))
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

    func testItsRainFallsInStreaksAndNeverBlotsTheLens() throws {
        let trailer = TrailerTests.trailer
        let rain = try XCTUnwrap(trailer.shots.first { $0.weather == .rain })
        let time = rain.start + rain.length / 2
        let camera = trailer.camera(of: rain, at: time)
        let eye = Trailer.eye(of: camera)
        let motes = trailer.scene(of: rain, at: time).motes
        XCTAssertGreaterThan(motes.count, 400, "Rain enough to see")
        XCTAssertEqual(motes.count % Trailer.streak, 0, "Each drop a streak")
        for index in stride(from: 0, to: motes.count, by: Trailer.streak) {
            let head = motes[index].place, tail = motes[index + Trailer.streak - 1].place
            XCTAssertEqual(head.x, tail.x)
            XCTAssertEqual(head.z, tail.z)
            XCTAssertEqual(tail.y - head.y, 0.06, accuracy: 1e-4, "Drawn out down its fall")
            let next = motes[index + 1].place
            XCTAssertLessThan(next.y - head.y, head.w, "Its motes run together into one line, not beads")
            XCTAssertGreaterThan((Vec3(head.x, head.y, head.z) - eye).length, Trailer.nearestDrop, "Never near enough the lens to blot it")
        }
        // The eye where the camera's distance puts it: high over the ground,
        // a few keeps' height, not more.
        XCTAssertGreaterThan(eye.y, camera.focus.y + 0.5)
        XCTAssertLessThan(eye.y, camera.focus.y + 4)
    }

    func testTheMoonIsEatenInItsOwnShotAndWholeInEveryOther() throws {
        let trailer = TrailerTests.trailer
        let eclipse = try XCTUnwrap(trailer.shots.first { $0.look == .eclipse })
        XCTAssertEqual(trailer.eaten(of: eclipse, at: eclipse.start), 0, "Whole as it begins")
        XCTAssertGreaterThan(trailer.eaten(of: eclipse, at: eclipse.start + eclipse.length / 2), 0.3)
        XCTAssertEqual(trailer.eaten(of: eclipse, at: eclipse.end), 1, "Wholly dark as it ends")
        XCTAssertEqual(trailer.eaten(of: eclipse, at: eclipse.end + 1), 1, "And so while it dissolves away")
        // The field after it lies under the eaten moon, and the moon is
        // whole again over the title.
        let after = try XCTUnwrap(trailer.shots.first { $0.start == eclipse.end })
        XCTAssertEqual(after.action, .aftermath)
        XCTAssertEqual(after.weather, .eclipse)
        for shot in trailer.shots where shot.look != .eclipse {
            XCTAssertEqual(trailer.eaten(of: shot, at: shot.start + shot.length / 2), 0, shot.name)
        }
    }

    func testItsWorldIsGrownKnownAndCrowned() throws {
        let world = TrailerTests.trailer.world
        let state = world.state
        XCTAssertEqual(world.holds.map(\.id), state.holds.map(\.id), "Every hold drawn")
        XCTAssertEqual(state.holds.first { $0.id == world.seat.id }?.position, world.seat.position, "The realm left as it was")
        XCTAssertEqual(world.seat.level(.moonspire), BuildingKind.moonspire.maxLevel, "The heart's Moonspire crowned")
        XCTAssertEqual(world.rising.level(.moonspire), 3, "Another rising, its crane at work")
        XCTAssertNotEqual(world.rising.owner, world.seat.owner)
        XCTAssertNotEqual(world.besieged.owner, world.seat.owner, "Another House's hold besieged")
        XCTAssertGreaterThanOrEqual(world.besieged.level(.walls), 4, "Walled in stone")
        XCTAssertFalse([world.town.id, world.shore.id].contains(world.besieged.id))
        XCTAssertEqual(world.holds.first { $0.id == world.besieged.id }, world.besieged, "Drawn as it is dressed")
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
                // Nothing laid over the world: no lanes ringing the holds.
                XCTAssertFalse((scene.fixed + scene.batches).contains { $0.key == .town(.lane) }, "\(shot.name) at \(u): no lanes")
                if shot.weather == .clear && ![.battle, .aftermath, .siege].contains(shot.action) {
                    XCTAssertTrue(scene.motes.isEmpty, "\(shot.name) at \(u): nothing hanging in the air, no fireflies, no dust")
                }
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
        XCTAssertTrue(trailer.scene(of: march, at: march.start + 4).motes.isEmpty, "No dust or fireflies hanging over the column")
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
        XCTAssertEqual(furies, 0, "No skill's ring or sigil laid over the field")
        let beats = trailer.battle.beats
        XCTAssertEqual(beats.filter { $0.sound == .fall }.count, 3)
        XCTAssertEqual(beats.filter { $0.sound == .horn }.count, 4, "The commanders' horns, heard")
        // What the battle throws up is steel's sparks, its fire and its
        // smoke: never a blow's flash or a skill's ring.
        XCTAssertTrue(Trailer.leftOut.isSuperset(of: [.flash, .fury, .sigil, .pillar, .fireflies, .dust]))
        XCTAssertGreaterThan(beats.filter { if case .clash = $0.sound { return true } else { return false } }.count, 20)
        XCTAssertEqual(beats.map(\.time), beats.map(\.time).sorted())
        // After it, the fallen lie still and the rest stand.
        var after: [CompanyPose] = []
        var smoke = Happenings()
        trailer.battle.after(at: 2, in: trailer.world, poses: &after, happenings: &smoke)
        XCTAssertEqual(after.filter { $0.clip == .death }.count, 3)
        XCTAssertEqual(after.filter { $0.clip == .idle }.count, 13)
    }

    /// A hold besieged at its gate: its walls struck by the Mangonels'
    /// stones and the spears' blows, volleys loosed over them and back from
    /// within, the hold burning once the stones fall; every besieger before
    /// the gate on land clear of the hold's works, its defenders within the
    /// walls.
    func testTheSiegeHurlsStonesAtTheGateAndIsAnsweredFromTheWalls() throws {
        let trailer = TrailerTests.trailer
        let shot = try XCTUnwrap(trailer.shots.first { $0.action == .siege })
        XCTAssertEqual(shot.length, Siege.length)
        var clips: Set<Clip> = []
        var stones = 0, arrows = 0, strikes = 0, burning = 0
        for step in stride(from: 0.0, through: Siege.length, by: 0.25) {
            var poses: [CompanyPose] = []
            var flights: [ArrowFlight] = []
            var happenings = Happenings()
            trailer.siege.stage(at: step, in: trailer.world, poses: &poses, arrows: &flights, happenings: &happenings)
            XCTAssertEqual(poses.count, 11, "Three Mangonels, two bows, three spears and a commander's riders; two bows within")
            clips.formUnion(poses.map(\.clip))
            stones += flights.filter { $0.stone && (0...1).contains($0.progress) }.count
            arrows += flights.filter { !$0.stone && (0...1).contains($0.progress) }.count
            strikes += happenings.strikes.count
            burning += happenings.blazes.count
            if step < Siege.burns { XCTAssertTrue(happenings.blazes.isEmpty, "Not burning before the stones fall") }
        }
        XCTAssertEqual(clips, [.idle, .attack], "Standing and striking")
        XCTAssertGreaterThan(stones, 10, "Stones in flight")
        XCTAssertGreaterThan(arrows, 40, "Volleys in flight")
        XCTAssertGreaterThan(strikes, 20)
        XCTAssertGreaterThan(burning, 0)
        let beats = trailer.siege.beats
        XCTAssertGreaterThanOrEqual(beats.filter { $0.sound == .batter }.count, 4, "Stones heard on the walls")
        XCTAssertEqual(beats.filter { $0.sound == .horn }.count, 2)
        XCTAssertTrue(beats.contains { $0.sound == .loose })
        XCTAssertEqual(beats.map(\.time), beats.map(\.time).sorted())
        // Where they stand: the besiegers before the gate, outside the walls
        // as the hold is drawn, none on a work; its own within them.
        let world = trailer.world
        let centre = world.ground(world.besieged.position)
        let walls = HoldLayout.wallRadius * HoldLayout.grandeur
        var poses: [CompanyPose] = []
        var flights: [ArrowFlight] = []
        var happenings = Happenings()
        trailer.siege.stage(at: 0, in: world, poses: &poses, arrows: &flights, happenings: &happenings)
        let works = HoldLayout.pieces(hold: world.besieged, relief: world.relief).compactMap { piece -> Vec3? in
            switch piece.key {
            case .walls, .keep, .keepOf, .town(.lane): return nil
            default: return Vec3(centre.x, 0, centre.z) + (Vec3(piece.transform.c3.x, 0, piece.transform.c3.z) - Vec3(centre.x, 0, centre.z)) * HoldLayout.grandeur
            }
        }
        for pose in poses {
            let from = Vec3(pose.position.x - centre.x, 0, pose.position.z - centre.z).length
            if pose.isOwn {
                XCTAssertGreaterThan(from, walls * 0.95, "\(pose.key) besieging from outside the walls")
                XCTAssertTrue(works.allSatisfy { (Vec3(pose.position.x, 0, pose.position.z) - $0).length >= 0.39 }, "\(pose.key) on no work")
            } else {
                XCTAssertLessThan(from, walls, "\(pose.key) defending within the walls")
            }
        }
    }

    /// The heart's Moonspire seen close as it is crowned: its last stage
    /// rising in its scaffold, then standing crowned, the scaffold gone.
    func testTheHeartsMoonspireIsCrownedClose() throws {
        let trailer = TrailerTests.trailer
        let shot = try XCTUnwrap(trailer.shots.first { $0.action == .crowning })
        let next = try XCTUnwrap(trailer.shots.first { $0.start == shot.end })
        XCTAssertEqual(next.name, "the seat", "Crowned, then seen whole about its seat")
        let crowned = ModelKey.work(.moonspire, level: BuildingKind.moonspire.maxLevel)
        let seat = trailer.world.ground(trailer.world.seat.position)
        func near(_ instance: ModelInstance) -> Bool {
            Vec3(instance.model.c3.x - seat.x, 0, instance.model.c3.z - seat.z).length < HoldLayout.reach * HoldLayout.grandeur
        }
        func spires(at time: Double) -> [ModelInstance] {
            trailer.scene(of: shot, at: time).batches.filter { $0.key == crowned }.flatMap(\.instances).filter(near)
        }
        func scaffolds(at time: Double) -> [ModelInstance] {
            trailer.scene(of: shot, at: time).batches.filter { $0.key == .scaffold }.flatMap(\.instances).filter(near)
        }
        let rising = try XCTUnwrap(spires(at: shot.start + 0.5).first, "The last stage in view")
        XCTAssertLessThan(rising.params.x, WorldStage.whole, "Rising")
        XCTAssertFalse(scaffolds(at: shot.start + 0.5).isEmpty, "In its scaffold")
        let higher = try XCTUnwrap(spires(at: shot.start + 3).first)
        XCTAssertGreaterThan(higher.params.x, rising.params.x, "Higher as the shot goes")
        let done = try XCTUnwrap(spires(at: shot.end - 0.5).first)
        XCTAssertEqual(done.params.x, WorldStage.whole, "Crowned")
        XCTAssertTrue(scaffolds(at: shot.end - 0.5).isEmpty, "Its scaffold gone")
        XCTAssertNil(Trailer.risen(at: Trailer.crowningLength - Trailer.crownedFor))
        XCTAssertEqual(try XCTUnwrap(Trailer.risen(at: 0)), 0.45, accuracy: 1e-6)
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
        // The vignette: the middle kept whole, the corners a quarter darker,
        // the alpha never touched.
        let keep = Pixels.vignette(width: 64, height: 36)
        XCTAssertEqual(keep[18 * 64 + 32], 256)
        XCTAssertEqual(Double(keep[0]), 256 * 0.74, accuracy: 3)
        XCTAssertEqual(keep[0], keep[35 * 64 + 63], "Its corners alike")
        XCTAssertLessThan(keep[18 * 64], keep[18 * 64 + 16], "Darker toward its edges")
        var lit = [UInt8](repeating: 200, count: 64 * 36 * 4)
        Pixels.vignette(&lit, keeping: keep)
        XCTAssertEqual(Array(lit[(18 * 64 + 32) * 4..<(18 * 64 + 33) * 4]), [200, 200, 200, 200])
        let corner = UInt8((200 * Int(keep[0])) >> 8)
        XCTAssertEqual(Array(lit[0..<4]), [corner, corner, corner, 200])
        XCTAssertLessThan(corner, 152)
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
        let siege = try XCTUnwrap(trailer.shots.first { $0.action == .siege })
        let clashes = soundtrack.events.filter { if case .cue(.clash, _, _) = $0.event { return true } else { return false } }
        XCTAssertTrue(clashes.allSatisfy { ($0.time >= battle.start && $0.time <= battle.end + 1) || ($0.time >= siege.start && $0.time <= siege.end + 1) },
                      "Blows heard in the battle and at the siege's gate")
        let stones = soundtrack.events.filter { if case .cue(.batter, _, _) = $0.event { return true } else { return false } }
        XCTAssertTrue(stones.contains { $0.time >= siege.start && $0.time <= siege.end }, "The siege's stones heard on the walls")
        let crowning = try XCTUnwrap(trailer.shots.first { $0.action == .crowning })
        XCTAssertTrue(soundtrack.events.contains { event in
            if case .cue(.triumph, _, _) = event.event { return event.time > crowning.start && event.time < crowning.end }
            return false
        }, "The Moonspire's crowning heard")
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
