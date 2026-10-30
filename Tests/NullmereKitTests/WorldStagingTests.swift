import Foundation
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereModels
import NullmereWorld

/// The session's world as its models show it: every hold it knows with
/// its works, a work rising as the watches pass and finishing its last
/// stretch, companies at rest, drawn up within their walls, on the march
/// and striking, and the fallen falling.
@MainActor
final class WorldStagingTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func session(_ build: (inout GameState) throws -> Void = { _ in }) throws -> GameSession {
        var state = GameState(settings: GameSettings(seedText: "staged", houseCount: 3, radius: 14, keepers: 1))
        try build(&state)
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        return session
    }

    func testTheWorldIsStagedFromWhatTheKeeperKnows() throws {
        let session = try session()
        let frame = session.sceneFrame(at: 4)
        let keys = Set((frame.fixed + frame.batches).map(\.key))
        XCTAssertTrue(frame.fixed.allSatisfy { if case .furnishing = $0.key { return true } else { return false } },
                      "only the land's furniture stands still")
        XCTAssertTrue(keys.contains(.keep(seat: true)), "the keeper's seat")
        XCTAssertTrue(keys.contains { if case .furnishing = $0 { return true } else { return false } }, "the land's furniture")
        XCTAssertTrue(keys.contains { if case .figure = $0 { return true } else { return false } }, "the keeper's companies")
        XCTAssertTrue(keys.contains(.prop(.bird)), "birds over the water")
        let known = session.state.holds.filter { session.isExplored($0.position) }.count
        XCTAssertEqual(frame.batches.filter { if case .keep = $0.key { return true } else { return false } }.flatMap(\.instances).count, known,
                       "a keep for each hold the keeper knows, and none for the rest")
        XCTAssertLessThan(known, session.state.holds.count)
        XCTAssertGreaterThan(frame.palette.count, 1, "the figures posed")
        // Laid out once: drawn again, the same land, not sent again.
        let again = session.sceneFrame(at: 4)
        XCTAssertEqual(again.fixed, frame.fixed)
        XCTAssertEqual(again.fixedVersion, frame.fixedVersion)
        // Still, nothing flies.
        session.motion = .still
        let still = session.sceneFrame(at: 4)
        XCTAssertFalse(still.batches.contains { $0.key == .prop(.bird) || $0.key == .prop(.puff) })
    }

    /// Staging a frame of a full realm, every hold known, takes a small
    /// share of a frame on the main thread once the land is laid out.
    func testStagingAFrameKeepsWithinItsShare() throws {
        var state = GameState(settings: GameSettings(seedText: "a full realm staged", houseCount: 12, radius: 24, keepers: 1))
        state.houses[state.player].explored = Array(repeating: true, count: state.map.count)
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        let started = ThreadClock.milliseconds()
        let first = session.sceneFrame(at: 0)
        let laying = ThreadClock.milliseconds() - started
        var times: [Double] = []
        for index in 1...60 {
            let start = ThreadClock.milliseconds()
            let frame = session.sceneFrame(at: Double(index) / 60)
            times.append(ThreadClock.milliseconds() - start)
            XCTAssertEqual(frame.fixedVersion, first.fixedVersion, "the land laid out once")
        }
        times.sort()
        let p50 = times[times.count / 2], p95 = times[Int(Double(times.count) * 0.95)]
        print("PERF staging a frame of \(first.instanceCount) models, \(first.palette.count) poses: the land laid out in "
              + "\(String(format: "%.1f", laying)) ms, then p50 \(String(format: "%.2f", p50)) ms, p95 \(String(format: "%.2f", p95)) ms")
        print("PERFMETRIC stage.cpu.p50 \(String(format: "%.3f", p50))")
        print("PERFMETRIC stage.cpu.p95 \(String(format: "%.3f", p95))")
        XCTAssertLessThan(p50, 16.7, "well inside a frame")
    }

    func testAWorkRisesAsTheWatchesPassAndFinishesItsLastStretch() throws {
        var seatID = 0
        let session = try session { state in
            let index = try XCTUnwrap(state.holds.firstIndex { $0.owner == state.player && $0.isSeat })
            state.holds[index].project = Hold.Project(kind: .granary, targetLevel: 1, watchesLeft: 2)
            seatID = state.holds[index].id
        }
        var hold = try XCTUnwrap(session.state.hold(seatID))
        let start = Date()
        let total = Float(BuildingKind.granary.buildWatches(toLevel: 1))
        let begun = session.rising(of: hold, at: start, animated: true)
        XCTAssertEqual(try XCTUnwrap(begun.progress), 1 - 2 / total, accuracy: 1e-4)
        XCTAssertNil(begun.finishing)
        // A watch passes: it rises toward its new height over a moment.
        hold.project?.watchesLeft = 1
        let turned = start.addingTimeInterval(10)
        XCTAssertEqual(try XCTUnwrap(session.rising(of: hold, at: turned, animated: true).progress), 1 - 2 / total, accuracy: 1e-4)
        let halfway = try XCTUnwrap(session.rising(of: hold, at: turned.addingTimeInterval(WorldStage.riseSeconds / 2), animated: true).progress)
        XCTAssertGreaterThan(halfway, 1 - 2 / total)
        XCTAssertLessThan(halfway, 1 - 1 / total)
        let risen = session.rising(of: hold, at: turned.addingTimeInterval(WorldStage.riseSeconds), animated: true)
        XCTAssertEqual(try XCTUnwrap(risen.progress), 1 - 1 / total, accuracy: 1e-4)
        // Finished: the rest of the way, then whole.
        hold.project = nil
        hold.levels[.granary] = 1
        let done = start.addingTimeInterval(20)
        let finishing = try XCTUnwrap(session.rising(of: hold, at: done.addingTimeInterval(0.2), animated: true).finishing)
        XCTAssertEqual(finishing.work, .building(.granary))
        XCTAssertLessThan(finishing.progress, 1)
        let after = session.rising(of: hold, at: done.addingTimeInterval(WorldStage.riseSeconds + 1), animated: true)
        XCTAssertNil(after.progress)
        XCTAssertNil(after.finishing)
        // Below full motion it stands where the watches have brought it.
        hold.project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 3)
        let still = session.rising(of: hold, at: done, animated: false)
        XCTAssertEqual(try XCTUnwrap(still.progress), 0, accuracy: 1e-4)
        hold.project = nil
        XCTAssertNil(session.rising(of: hold, at: done, animated: false).finishing)
        // Staged, the work stands under its scaffold.
        XCTAssertTrue(session.sceneFrame(at: 1).batches.contains { $0.key == .scaffold })
    }

    func testCompaniesMarchStrikeAndFall() throws {
        let session = try session()
        let player = session.player
        // At rest within the seat's walls, drawn up small.
        let seat = try XCTUnwrap(session.state.seat(of: player))
        let poses = session.companyPoses(at: Date(), animated: true, time: 2)
        if let home = poses.first(where: { $0.hex == seat.position }) {
            XCTAssertEqual(home.spread, 0.3)
            XCTAssertEqual(home.clip, .idle)
        }
        // On the march: along the way, its feet going, facing where it goes.
        let lantern = try XCTUnwrap(session.state.units(of: player).first { $0.kind == .lantern })
        let target = try XCTUnwrap(lantern.position.spiral(3).first {
            $0.distance(to: lantern.position) == 2 && session.state.map[$0]?.terrain.isPassable == true
                && session.state.unit(at: $0) == nil && session.state.path(for: lantern, to: $0) != nil
        })
        XCTAssertTrue(session.perform(.move(unit: lantern.id, to: target)))
        let march = try XCTUnwrap(session.marches[lantern.id])
        let marching = try XCTUnwrap(session.companyPoses(at: march.start.addingTimeInterval(march.duration / 2), animated: true, time: 2)
            .first { $0.unit == lantern.id })
        XCTAssertEqual(marching.clip, .march)
        XCTAssertGreaterThan(marching.clipTime, 0)
        let there = Relief.centre(of: target)
        XCTAssertGreaterThan(abs(marching.position.x - there.x) + abs(marching.position.z - there.z), 0.1, "not yet there")
        let arrived = try XCTUnwrap(session.companyPoses(at: march.start.addingTimeInterval(march.duration + 1), animated: true, time: 2)
            .first { $0.unit == lantern.id })
        XCTAssertEqual(arrived.clip, .idle)
        XCTAssertEqual(arrived.heading, session.headings[lantern.id], "facing the way it came")
        XCTAssertEqual(session.companyPoses(at: march.start, animated: false, time: 2).first { $0.unit == lantern.id }?.clip, .idle,
                       "below full motion, there at once")

        // A blow struck close: the striker leans in, and falls; the struck turns to face it.
        let striker = try XCTUnwrap(session.state.units(of: player).first { $0.kind.isMilitary })
        let foeAt = try XCTUnwrap(striker.position.neighbors.first { session.state.map[$0] != nil })
        session.showBlows([.battle(Battle(attacker: striker.id, attackerOwner: player, attackerKind: striker.kind, defender: 9_999,
                                          defenderOwner: (player + 1) % 3, defenderKind: .spear, hold: nil, at: foeAt, damageDealt: 30,
                                          damageTaken: 100, attackerFell: true, defenderFell: true))])
        let blow = try XCTUnwrap(session.blows.last)
        XCTAssertEqual(session.headings[9_999], CompanyPose.heading(from: foeAt, to: striker.position))
        let struck = session.companyPoses(at: blow.start.addingTimeInterval(0.1), animated: true, time: 2)
        let leaning = try XCTUnwrap(struck.first { $0.unit == striker.id })
        XCTAssertEqual(leaning.clip, .attack)
        XCTAssertEqual(leaning.heading, CompanyPose.heading(from: striker.position, to: foeAt), accuracy: 1e-5)
        let upright = try XCTUnwrap(session.companyPoses(at: blow.start.addingTimeInterval(1), animated: true, time: 2)
            .first { $0.unit == striker.id })
        XCTAssertEqual(upright.clip, .attack, "still striking, back where it stood")
        let home = Relief.centre(of: striker.position), foe = Relief.centre(of: foeAt)
        let toward = (leaning.position.x - upright.position.x) * (foe.x - home.x) + (leaning.position.z - upright.position.z) * (foe.z - home.z)
        XCTAssertGreaterThan(toward, 0, "leaning into the foe's ground")
        let fallen = struck.filter { $0.clip == .death }
        XCTAssertEqual(fallen.count, 2, "both fall")
        XCTAssertTrue(fallen.allSatisfy { $0.unit < 0 })
        XCTAssertTrue(session.arrows(at: blow.start.addingTimeInterval(0.1)).isEmpty, "steel, not arrows")
        // The fallen lie still, then fade before the blow is forgotten.
        let fading = session.companyPoses(at: blow.start.addingTimeInterval(GameSession.Blow.lingers - 0.1), animated: true, time: 2)
        XCTAssertTrue(fading.filter { $0.clip == .death }.isEmpty, "gone before the blow is")
        let held = session.companyPoses(at: blow.start, animated: false, time: 2).filter { $0.clip == .death }
        XCTAssertTrue(held.allSatisfy { $0.clipTime == Clip.death.period && $0.opacity == 1 }, "still, already lying")

        // A shot from afar: arrows in flight, a few, coming down about the mark.
        let far = try XCTUnwrap(session.state.map.hexes.first { $0.distance(to: striker.position) == 2 })
        session.showBlows([.battle(Battle(attacker: striker.id, attackerOwner: player, attackerKind: .bow, defender: nil,
                                          defenderOwner: (player + 1) % 3, defenderKind: nil, hold: nil, at: far, damageDealt: 10,
                                          damageTaken: 0, attackerFell: false, defenderFell: false))])
        let shot = try XCTUnwrap(session.blows.last)
        XCTAssertTrue(shot.isRanged)
        let flying = session.arrows(at: shot.start.addingTimeInterval(0.12))
        XCTAssertFalse(flying.isEmpty)
        XCTAssertTrue(flying.allSatisfy { (0...1).contains($0.progress) })
        XCTAssertTrue(session.arrows(at: shot.start.addingTimeInterval(1)).isEmpty, "landed")
        let frame = session.sceneFrame(at: 2, now: shot.start.addingTimeInterval(0.12))
        XCTAssertTrue(frame.batches.contains { $0.key == .prop(.arrow) })
    }
}
