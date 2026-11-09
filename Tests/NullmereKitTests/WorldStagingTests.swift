import Foundation
import LauncherCore
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

    /// A frame's motes but the companies' torches, which burn in every
    /// frame, motion or none: what a test of what else is thrown up looks
    /// at. A torch's light is the torch's flame, brighter or dimmer.
    private func thrown(_ motes: [Mote]) -> [Mote] {
        let flame = WorldStage.torchFlame
        return motes.filter { mote in
            !(mote.colour.w == 0 && mote.colour.x > 0 && abs(mote.colour.y / mote.colour.x - flame.y / flame.x) < 1e-4
                && abs(mote.colour.z / mote.colour.x - flame.z / flame.x) < 1e-4)
        }
    }

    private func session(_ build: (inout GameState) throws -> Void = { _ in }) throws -> GameSession {
        var state = GameState(settings: GameSettings(seedText: "staged", houseCount: 3, radius: 14, keepers: 1))
        try build(&state)
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        return session
    }

    /// The keeper's Detail reaches the land's furniture: less of it drawn
    /// a tier down, none at the lowest; and a Mac whose graphics falter
    /// steps down a tier at a time, told, before the painting.
    func testDetailThinsTheLandAndStepsDownWhenTheGraphicsFalter() throws {
        let session = try session()
        // The land's growth: its landmarks are drawn at every Detail.
        func furniture() -> Int {
            session.sceneFrame(at: 4).fixed.filter { if case .furnishing(let piece) = $0.key { return !piece.isLandmark } else { return false } }
                .reduce(0) { $0 + $1.instances.count }
        }
        let whole = furniture()
        XCTAssertGreaterThan(whole, 0)
        XCTAssertEqual(session.stage?.furnitureShare, 1)
        session.detail = .medium
        XCTAssertEqual(session.stage?.furnitureShare, 0.5)
        XCTAssertLessThan(furniture(), whole)
        session.detail = .low
        XCTAssertEqual(furniture(), 0)

        session.detail = .high
        XCTAssertTrue(WorldView.stepDown(session))
        XCTAssertEqual(session.detail, .medium)
        XCTAssertTrue(session.notices.last?.text.hasPrefix("This Mac's graphics faltered") == true)
        XCTAssertTrue(WorldView.stepDown(session))
        XCTAssertEqual(session.detail, .low)
        XCTAssertFalse(WorldView.stepDown(session), "Below the lowest, the painting")
        XCTAssertEqual(session.detail, .low)
    }

    func testTheWorldIsStagedFromWhatTheKeeperKnows() throws {
        let session = try session()
        let frame = session.sceneFrame(at: 4)
        let keys = Set((frame.fixed + frame.batches).map(\.key))
        XCTAssertTrue(frame.fixed.allSatisfy { if case .furnishing = $0.key { return true } else { return false } },
                      "only the land's furniture stands still")
        // The keeper's seat, a keep as its House's people build one.
        XCTAssertTrue(keys.contains(.keepOf(session.state.heritage(of: session.player), seat: true)), "the keeper's seat")
        XCTAssertTrue(keys.contains { if case .furnishing = $0 { return true } else { return false } }, "the land's furniture")
        XCTAssertTrue(keys.contains { if case .figure = $0 { return true } else { return false } }, "the keeper's companies")
        XCTAssertTrue(keys.contains(.prop(.bird)), "birds over the water")
        let known = session.state.holds.filter { session.isExplored($0.position) }.count
        func isKeep(_ key: ModelKey) -> Bool {
            switch key {
            case .keep, .keepOf: return true
            default: return false
            }
        }
        XCTAssertEqual(frame.batches.filter { isKeep($0.key) }.flatMap(\.instances).count, known,
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

    /// The veil of the Still lies on the world as a low mist about the
    /// veiled House's holds in sight, six banks to each, faint and flat.
    func testAVeilLiesAsMistAboutItsHolds() throws {
        let clear = try session()
        let veiled = try session { state in
            state.houses[state.player].stock.moonsalt = 60
            _ = try state.perform(.drawVeil, as: state.player)
        }
        XCTAssertTrue(veiled.state.isVeiled(veiled.player))
        func puffs(_ session: GameSession) -> [ModelInstance] {
            session.sceneFrame(at: 2).batches.first { $0.key == .prop(.puff) }?.instances ?? []
        }
        let mist = puffs(veiled).count - puffs(clear).count
        XCTAssertGreaterThanOrEqual(mist, 6, "Mist about the seat at least")
        XCTAssertEqual(mist % 6, 0, "Six banks to a hold")
        let banks = puffs(veiled).filter { $0.model.c0.x > 3 }
        XCTAssertEqual(banks.count, mist)
        XCTAssertTrue(banks.allSatisfy { $0.params.y < 0.4 }, "Faint")
        veiled.motion = .still
        XCTAssertTrue(puffs(veiled).filter { $0.model.c0.x > 3 }.count == mist, "Mist lies still, too")
    }

    func testTheOmensWeatherFallsOnTheWorld() throws {
        let clear = try session()
        XCTAssertEqual(clear.sceneFrame(at: 2).weather, .clear)
        let rainy = try session { $0.omen = Omen(kind: .leanWatch, began: 1, ends: 4) }
        let frame = rainy.sceneFrame(at: 2)
        XCTAssertEqual(frame.weather, .rain)
        XCTAssertGreaterThanOrEqual(frame.motes.count, Weather.drops * 2, "The rain falls about the middle of the view")
        let misty = try session { $0.omen = Omen(kind: .risingMist, began: 1, ends: 4) }
        XCTAssertEqual(misty.sceneFrame(at: 2).weather, .mist)
        misty.motion = .still
        XCTAssertEqual(thrown(misty.sceneFrame(at: 2).motes).count, 0, "Still, no weather moves, though it is known")
        XCTAssertEqual(misty.sceneFrame(at: 2).weather, .mist)
    }

    /// Frames timed over passes keep each frame's steadiest time: a slow
    /// moment in one pass is not counted, a frame slow in every pass is.
    /// The House's expedition field stands under the Spine nearest its seat
    /// once it is in sight: its war camp, and a waystone for each stage,
    /// lit for each it has won.
    func testTheExpeditionFieldStandsUnderTheSpine() throws {
        let session = try session { state in
            let me = state.player
            state.expeditions = [me: 4]
            guard let (from, _) = GameSession.expeditionField(in: state, for: me),
                  let index = state.units.firstIndex(where: { $0.owner == me }) else { return }
            state.units[index].position = from
        }
        guard let (from, _) = GameSession.expeditionField(in: session.state, for: session.player) else {
            throw XCTSkip("no Spine on this lake")
        }
        XCTAssertTrue(session.isVisible(from), "the field in sight")
        let scene = session.sceneFrame(at: 5)
        let count = { (key: ModelKey) in scene.batches.filter { $0.key == key }.flatMap(\.instances).count }
        XCTAssertEqual(count(.prop(.waystoneLit)), 4, "a stone lit for each stage won")
        XCTAssertEqual(count(.prop(.waystone)) + count(.prop(.waystoneLit)), ExpeditionStage.count)
        XCTAssertGreaterThanOrEqual(count(.rallyCamp), 1, "the House's camp below the ridge")
    }

    func testEachFramesSteadiestTimeIsKept() {
        let passes: [[Double]] = [[1, 5, 2, 7], [4, 1, 2, 7], [1, 1, 9, 7]]
        XCTAssertEqual(StagingTimes.steadiest(passes), [1, 1, 2, 7])
        XCTAssertEqual(StagingTimes.percentile([1, 1, 2, 7], 0.5), 2)
        XCTAssertEqual(StagingTimes.percentile([1, 1, 2, 7], 0.95), 7, "The frame slow in every pass")
        XCTAssertEqual(StagingTimes.percentile([], 0.5), 0)
        XCTAssertEqual(StagingTimes.slowest([1, 5, 2, 7, 3]), "frame 4 7.00, frame 2 5.00, frame 5 3.00, frame 3 2.00")
    }

    /// Staging a frame of a full realm, every hold known, takes a small
    /// share of a frame on the main thread once the land is laid out.
    func testStagingAFrameKeepsWithinItsShare() throws {
        var state = GameState(settings: GameSettings(seedText: "a full realm staged", houseCount: 12, radius: 24, keepers: 1))
        state.houses[state.player].explored = Explored(repeating: true, count: state.map.count)
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        let started = ThreadClock.milliseconds()
        let first = session.sceneFrame(at: 0)
        let laying = ThreadClock.milliseconds() - started
        // The same second of frames staged three times, each frame's
        // steadiest staging kept: a model first made as a frame shows it,
        // or the shared Mac busy with something else for a moment, slows a
        // frame in one pass, at whichever frame it falls; the stage's own
        // work slows the frame in every pass.
        var passes: [[Double]] = []
        // Plain work timed between the passes, none of it the game's: how
        // busy the shared Mac is while the stage is timed, so that
        // scripts/perf-check.py paces the stage's figures by it.
        var beside: [Double] = []
        func plain() {
            let start = ThreadClock.milliseconds()
            XCTAssertNotEqual(StagingTimes.plainWork(seed: UInt64(beside.count)), 0)
            beside.append(ThreadClock.milliseconds() - start)
        }
        for _ in 0..<3 {
            plain()
            var times: [Double] = []
            for index in 1...60 {
                let start = ThreadClock.milliseconds()
                let frame = session.sceneFrame(at: Double(index) / 60)
                times.append(ThreadClock.milliseconds() - start)
                XCTAssertEqual(frame.fixedVersion, first.fixedVersion, "the land laid out once")
            }
            passes.append(times)
        }
        plain()
        print("PERFMETRIC stage.pace.cpu \(String(format: "%.3f", beside.min() ?? 0))")
        let steadiest = StagingTimes.steadiest(passes)
        let p50 = StagingTimes.percentile(steadiest, 0.5), p95 = StagingTimes.percentile(steadiest, 0.95)
        for (index, pass) in passes.enumerated() {
            print("PERF staging pass \(index + 1): p50 \(String(format: "%.2f", StagingTimes.percentile(pass, 0.5))) ms, "
                  + "p95 \(String(format: "%.2f", StagingTimes.percentile(pass, 0.95))) ms; slowest \(StagingTimes.slowest(pass))")
        }
        print("PERF staging a frame of \(first.instanceCount) models, \(first.palette.count) poses: the land laid out in "
              + "\(String(format: "%.1f", laying)) ms, then p50 \(String(format: "%.2f", p50)) ms, p95 \(String(format: "%.2f", p95)) ms")
        print("PERFMETRIC stage.cpu.p50 \(String(format: "%.3f", p50))")
        print("PERFMETRIC stage.cpu.p95 \(String(format: "%.3f", p95))")
        XCTAssertLessThan(p50, 16.7, "well inside a frame")
    }

    /// A realm of forty-eight seats, every hold known: a frame staged for
    /// the view stages only the holds, towns and companies it can show, the
    /// land's furniture laid out once whatever the view, and in a small
    /// share of a frame. One of ninety-six seats stages its frame in about
    /// the time the forty-eight's does: what is in view, not how wide.
    func testAWideRealmStagesOnlyWhatTheViewTakesIn() throws {
        let wide = try stageNear(seats: 48, seed: "a wide realm staged")
        print("PERF staging a wide realm's frame near: \(wide.viewed) of \(wide.whole) models, p50 \(String(format: "%.2f", wide.p50)) ms")
        print("PERFMETRIC stage.wide.cpu.p50 \(String(format: "%.3f", wide.p50))")
        XCTAssertLessThan(wide.p50, 16.7, "well inside a frame")
        let wider = try stageNear(seats: 96, seed: "a wider realm staged")
        print("PERF staging a wider realm's frame near: \(wider.viewed) of \(wider.whole) models, p50 \(String(format: "%.2f", wider.p50)) ms")
        print("PERFMETRIC stage.wider.cpu.p50 \(String(format: "%.3f", wider.p50))")
        XCTAssertLessThanOrEqual(wider.p50, wide.p50 * 1.5 + 1, "A realm twice as wide stages a frame near in what the narrower does")
    }

    /// A frame near a realm's seat staged for the view, every hold known:
    /// the models it stages and those of the whole realm, and the median of
    /// thirty frames' thread time.
    private func stageNear(seats: Int, seed: String) throws -> (viewed: Int, whole: Int, p50: Double) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: seats, radius: RealmState.radius(forSeats: seats), keepers: 1))
        state.houses[state.player].explored = Explored(repeating: true, count: state.map.count)
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        let seat = try XCTUnwrap(state.seat(of: state.player)).position
        session.camera = Camera(scale: 28)
        session.camera.focus(on: seat)
        let size = CGSize(width: 1512, height: 982)
        let whole = session.sceneFrame(at: 1)
        let viewed = session.sceneFrame(at: 1, in: size)
        let count = { (frame: SceneFrame) in frame.batches.reduce(0) { $0 + $1.instances.count } }
        XCTAssertEqual(viewed.fixedVersion, whole.fixedVersion, "The land laid out once, whatever the view")
        XCTAssertLessThan(count(viewed) * 4, count(whole), "Most of a wide realm's holds out of view, and not staged")
        let seatHex = SIMD2(Int32(seat.q), Int32(seat.r))
        XCTAssertTrue(viewed.batches.contains { $0.instances.contains { $0.hex == seatHex } }, "The seat in view, staged")
        // Thirty frames staged three times, each frame's steadiest kept.
        var passes: [[Double]] = []
        // Plain work timed between the passes, none of it the game's: how
        // busy the shared Mac is while the stage is timed, so that
        // scripts/perf-check.py paces the stage's figures by it.
        var beside: [Double] = []
        func plain() {
            let start = ThreadClock.milliseconds()
            XCTAssertNotEqual(StagingTimes.plainWork(seed: UInt64(beside.count)), 0)
            beside.append(ThreadClock.milliseconds() - start)
        }
        for _ in 0..<3 {
            plain()
            var times: [Double] = []
            for index in 1...30 {
                let start = ThreadClock.milliseconds()
                _ = session.sceneFrame(at: 1 + Double(index) / 60, in: size)
                times.append(ThreadClock.milliseconds() - start)
            }
            passes.append(times)
        }
        return (count(viewed), count(whole), StagingTimes.percentile(StagingTimes.steadiest(passes), 0.5))
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

    func testCompaniesEaseFromOneClipIntoTheNext() throws {
        let session = try session()
        let lantern = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .lantern })
        // Drawn at rest first.
        let before = Date()
        XCTAssertNil(session.companyPoses(at: before, animated: true, time: 2).first { $0.unit == lantern.id }?.blend)
        let target = try XCTUnwrap(lantern.position.spiral(3).first {
            $0.distance(to: lantern.position) == 2 && session.state.map[$0]?.terrain.isPassable == true
                && session.state.unit(at: $0) == nil && session.state.path(for: lantern, to: $0) != nil
        })
        XCTAssertTrue(session.perform(.move(unit: lantern.id, to: target)))
        let march = try XCTUnwrap(session.marches[lantern.id])
        // Setting off, it eases out of rest into the march.
        let setting = try XCTUnwrap(session.companyPoses(at: march.start.addingTimeInterval(0.05), animated: true, time: 2.05)
            .first { $0.unit == lantern.id })
        XCTAssertEqual(setting.clip, .march)
        let blend = try XCTUnwrap(setting.blend, "easing out of rest")
        XCTAssertEqual(blend.clip, .idle)
        XCTAssertGreaterThan(blend.weight, 0.5)
        // A moment later the march has taken over.
        let going = try XCTUnwrap(session.companyPoses(at: march.start.addingTimeInterval(0.6), animated: true, time: 2.6)
            .first { $0.unit == lantern.id })
        XCTAssertNil(going.blend)
        // Below full motion nothing eases.
        XCTAssertNil(session.companyPoses(at: march.start.addingTimeInterval(0.05), animated: false, time: 2).first { $0.unit == lantern.id }?.blend)
    }

    func testBlowsThrowUpMotesAndLightAndTheStruckReel() throws {
        let session = try session()
        let player = session.player
        let units = session.state.units(of: player)
        let striker = try XCTUnwrap(units.first { $0.kind.isMilitary })
        let struck = try XCTUnwrap(units.first { $0.id != striker.id && $0.position != striker.position })
        let from = try XCTUnwrap(struck.position.neighbors.first { session.state.map[$0] != nil })
        session.showBlows([.battle(Battle(attacker: striker.id, attackerOwner: player, attackerKind: striker.kind, defender: struck.id,
                                          defenderOwner: player, defenderKind: struck.kind, hold: nil, at: struck.position,
                                          damageDealt: 10, damageTaken: 0, attackerFell: false, defenderFell: false))],
                           from: [striker.id: from])
        let blow = try XCTUnwrap(session.blows.last)
        // As it lands: sparks, a flash, and the ground lit round it.
        let landing = blow.start.addingTimeInterval(Double(Happenings.landing) + 0.05)
        let frame = session.sceneFrame(at: 50, now: landing)
        XCTAssertFalse(thrown(frame.motes).isEmpty, "sparks and dust")
        XCTAssertTrue(thrown(frame.motes).contains { $0.colour.w == 0 && $0.colour.x > 1 }, "bright sparks")
        XCTAssertFalse(frame.lights.isEmpty, "the blow lights the ground")
        // The struck company reels back from the blow, and stands again.
        let centre = Relief.centre(of: struck.position), away = Relief.centre(of: from)
        let reeling = try XCTUnwrap(session.companyPoses(at: blow.start.addingTimeInterval(Double(Happenings.landing) + 0.2), animated: true, time: 50)
            .first { $0.unit == struck.id })
        let standing = try XCTUnwrap(session.companyPoses(at: blow.start.addingTimeInterval(1.2), animated: true, time: 51)
            .first { $0.unit == struck.id })
        let pushed = (reeling.position.x - standing.position.x) * (centre.x - away.x) + (reeling.position.z - standing.position.z) * (centre.z - away.z)
        XCTAssertGreaterThan(pushed, 0, "back from the striker")
        let still = try XCTUnwrap(session.companyPoses(at: blow.start.addingTimeInterval(1.2), animated: false, time: 51)
            .first { $0.unit == struck.id })
        XCTAssertEqual(standing.position, still.position, "and stands where it stood")
        // A commander's skill firing at the striker's head, in its archetype's
        // look: a vanguard's fire thrown out, and its light, warm.
        session.showBlows([.skillFired(commander: 1, house: player, skill: .fellCharge, at: striker.position)])
        let fury = try XCTUnwrap(session.furies.last)
        XCTAssertEqual(fury.at, striker.position)
        XCTAssertEqual(fury.skill, .fellCharge)
        let fired = session.sceneFrame(at: 60, now: fury.start.addingTimeInterval(0.3))
        XCTAssertTrue(fired.lights.contains { $0.colour.x > 1 && $0.colour.x > 2 * $0.colour.z }, "the fury's light, warm as its fire")
        let foes = (player + 1) % session.state.houses.count
        let hidden = try XCTUnwrap(session.state.map.hexes.first { !session.isVisible($0) })
        session.showBlows([.skillFired(commander: 2, house: foes, skill: .harry, at: hidden)])
        XCTAssertEqual(session.furies.count, 1, "a foe's fury out of sight is not drawn")
        // Still, nothing is thrown up.
        session.motion = .still
        let quiet = session.sceneFrame(at: 50, now: landing)
        XCTAssertTrue(thrown(quiet.motes).isEmpty, "but the companies' torches")
        XCTAssertTrue(quiet.lights.isEmpty)
    }

    /// An ambush sprung, the House's own or upon it, throws leaves up from
    /// the wood where the company lay in wait, gone a while after; still,
    /// nothing is thrown.
    func testAnAmbushSprungThrowsLeavesUpFromTheWood() throws {
        let session = try session()
        let player = session.player
        let company = try XCTUnwrap(session.state.units(of: player).first { $0.kind.isMilitary })
        let foe = (player + 1) % session.state.houses.count
        XCTAssertTrue(session.springs.isEmpty)
        session.showBlows([.ambushSprung(unit: company.id, owner: player, at: company.position, struck: 9_000, struckOwner: foe)])
        let spring = try XCTUnwrap(session.springs.last)
        XCTAssertEqual(spring.at, company.position)
        // Dark, small and green or brown: hiding what is behind them.
        func leaves(_ motes: [Mote]) -> Int {
            thrown(motes).filter { $0.colour.w > 0 && $0.colour.y > $0.colour.z && $0.place.w < 0.05 }.count
        }
        let flying = leaves(session.sceneFrame(at: 50, now: spring.start.addingTimeInterval(0.3)).motes)
        let settled = leaves(session.sceneFrame(at: 50, now: spring.start.addingTimeInterval(3.0)).motes)
        XCTAssertGreaterThan(flying, settled + 10, "leaves thrown up as it springs, gone after")
        session.motion = .still
        XCTAssertEqual(leaves(session.sceneFrame(at: 50, now: spring.start.addingTimeInterval(0.3)).motes), 0, "still, none")
    }

    /// The hamlets and barrows the keeper's House has found are drawn where
    /// they lie, the land's growth giving way to them as it does to a site
    /// or a lair (their hearts clear, nothing tall on their ground, only
    /// grass, heather or a fern at their edges); one in the mist it has not
    /// seen is not.
    func testHamletsAndBarrowsFoundAreDrawnWhereTheyLie() throws {
        var hidden: Find?
        let session = try session { state in
            let me = state.player
            hidden = state.findsInLand.first { !state.isExplored($0.position, by: me) }
        }
        let unseen = try XCTUnwrap(hidden, "A find still in the mist")
        func key(_ hex: Hex) -> SIMD2<Int32> { SIMD2(Int32(hex.q), Int32(hex.r)) }
        func drawn(_ find: Find, in frame: SceneFrame) -> Bool {
            frame.batches.contains { batch in
                (batch.key == .town(.well) || batch.key == .furnishing(.barrowMound)) && batch.instances.contains { $0.hex == key(find.position) }
            }
        }
        XCTAssertFalse(drawn(unseen, in: session.sceneFrame(at: 20)), "Not while the mist hides it")
        // Every one found, once the House has seen the whole land.
        let known = try session { state in
            state.houses[state.player].explored = Explored(repeating: true, count: state.map.count)
        }
        let frame = known.sceneFrame(at: 20)
        for find in known.state.findsInLand where known.state.find(at: find.position) != nil && known.state.site(at: find.position) == nil {
            XCTAssertTrue(drawn(find, in: frame), "\(find.named) drawn")
            // The land's growth gives way to it: nothing in its heart, where
            // its homes or its mound stand, and nothing taller than what lies
            // underfoot within its ground.
            let centre = Relief.centre(of: find.position)
            for batch in frame.fixed {
                guard case .furnishing(let furnishing) = batch.key else { continue }
                for piece in batch.instances where piece.hex == key(find.position) {
                    let at = hypot(piece.model.c3.x - centre.x, piece.model.c3.z - centre.z)
                    XCTAssertGreaterThanOrEqual(at, Scatter.heart, "\(find.named)'s heart cleared of \(furnishing)")
                    if Scatter.height(furnishing) > Scatter.underfoot {
                        XCTAssertGreaterThanOrEqual(at, Scatter.held, "nothing tall within \(find.named)'s ground: \(furnishing)")
                    }
                }
            }
        }
        XCTAssertTrue(frame.batches.contains { $0.key == .town(.well) }, "A hamlet among them")
    }

    /// Wood seen catching alight flares up where it catches, for a few
    /// seconds; a fire already burning when the world is first drawn
    /// doesn't.
    func testWoodFlaresUpWhereTheFireCatches() throws {
        var alight: Hex?
        let session = try session { state in
            let me = state.player
            state.houses[me].explored = Explored(repeating: true, count: state.map.count)
            let wood = try XCTUnwrap(state.map.hexes.first { state.isBlackwood($0) && state.hold(at: $0) == nil })
            state.wildfires = [Wildfire(at: wood, by: me, caught: state.watch, out: state.watch + Wildfire.burns)]
            alight = wood
        }
        XCTAssertNotNil(alight)
        let stage = WorldStage(map: session.state.map, relief: session.relief)
        let now = Date()
        let first = session.happenings(poses: [], sights: [], stage: stage, at: now, time: 30)
        XCTAssertEqual(first.woodFires.count, 3, "the wood burning")
        XCTAssertTrue(first.catching.isEmpty, "burning when first drawn: no flare")
        // Seen catching since the world was last drawn: it flares, a few seconds.
        session.firesSeen = []
        let caught = session.happenings(poses: [], sights: [], stage: stage, at: now, time: 30)
        XCTAssertEqual(caught.catching.count, 1)
        XCTAssertEqual(caught.catching.first?.start ?? 0, 30, accuracy: 0.001)
        XCTAssertEqual(session.happenings(poses: [], sights: [], stage: stage, at: now.addingTimeInterval(1), time: 31).catching.count, 1,
                       "still flaring")
        XCTAssertTrue(session.happenings(poses: [], sights: [], stage: stage, at: now.addingTimeInterval(4), time: 34).catching.isEmpty,
                      "and gone")
    }

    func testBurningHoldsSmokeAndGiveFirelightAndFinishedWorksRaiseDust() throws {
        var seatID = 0
        let session = try session { state in
            let index = try XCTUnwrap(state.holds.firstIndex { $0.owner == state.player && $0.isSeat })
            state.holds[index].ward = 1
            state.holds[index].levels[.granary] = 1
            seatID = state.holds[index].id
        }
        let seat = try XCTUnwrap(session.state.hold(seatID))
        let now = Date()
        let happenings = session.happenings(poses: [], sights: [HoldSight(hold: seat, colour: .zero)],
                                            stage: WorldStage(map: session.state.map, relief: session.relief), at: now, time: 30)
        XCTAssertEqual(happenings.blazes.count, 1, "its ward broken, the seat burns")
        XCTAssertGreaterThan(happenings.blazes[0].strength, 0.9)
        let frame = session.sceneFrame(at: 30, now: now)
        XCTAssertTrue(frame.lights.contains { $0.colour.x > $0.colour.z }, "firelight")
        XCTAssertTrue(thrown(frame.motes).contains { $0.colour.w == 0 && $0.colour.x > $0.colour.z }, "embers")
        // A work finished lately raises the dust of its last course, for a few seconds.
        session.completions.append(GameSession.Completion(hold: seatID, kind: .granary, level: 1, at: now))
        let stage = WorldStage(map: session.state.map, relief: session.relief)
        let finishing = session.happenings(poses: [], sights: [], stage: stage, at: now, time: 30)
        XCTAssertEqual(finishing.finished.count, 1)
        XCTAssertTrue(session.happenings(poses: [], sights: [], stage: stage, at: now.addingTimeInterval(4), time: 34).finished.isEmpty)
        // Close in, fireflies over the reeds and the grass near the eye.
        session.camera.scale = 60
        let close = session.happenings(poses: [], sights: [], stage: stage, at: now, time: 30)
        XCTAssertLessThanOrEqual(close.fireflies.count, 10)
        session.camera.scale = 20
        XCTAssertTrue(session.happenings(poses: [], sights: [], stage: stage, at: now, time: 30).fireflies.isEmpty, "afar, none")
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

        // A Mangonel's: one stone, loosed as its arm reaches the stop bar.
        session.showBlows([.battle(Battle(attacker: striker.id, attackerOwner: player, attackerKind: .mangonel, defender: nil,
                                          defenderOwner: (player + 1) % 3, defenderKind: nil, hold: nil, at: far, damageDealt: 30,
                                          damageTaken: 0, attackerFell: false, defenderFell: false))])
        let hurled = try XCTUnwrap(session.blows.last)
        XCTAssertTrue(hurled.hurled)
        XCTAssertFalse(shot.hurled)
        XCTAssertTrue(session.arrows(at: hurled.start.addingTimeInterval(0.05)).filter(\.stone).isEmpty, "not yet loosed")
        let stones = session.arrows(at: hurled.start.addingTimeInterval(0.4)).filter(\.stone)
        XCTAssertEqual(stones.count, 1)
        XCTAssertTrue(session.arrows(at: hurled.start.addingTimeInterval(1)).filter(\.stone).isEmpty, "landed")
        let thrown = session.sceneFrame(at: 2, now: hurled.start.addingTimeInterval(0.4))
        XCTAssertTrue(thrown.batches.contains { $0.key == .prop(.stone) })
    }
}
