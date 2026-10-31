import AVFoundation
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The din of a field of battle in sight: voices, the tramp of feet and
/// steel on steel, as loud as the troops fighting there and as near as the
/// view stands, heard from where the field is across the view; nothing
/// where no field is in sight, and it eases in and out, never clipping.
final class BattleDinTests: XCTestCase {
    static let rate: Float = 48_000

    /// Both channels of `seconds` of sound.
    private func render(_ synth: Synth, seconds: Float) -> (left: [Float], right: [Float]) {
        let frames = Int(seconds * Self.rate), chunk = 512
        var left: [Float] = [], right: [Float] = []
        let list = AudioBufferList.allocate(maximumBuffers: 2)
        defer { free(list.unsafeMutablePointer) }
        let l = UnsafeMutablePointer<Float>.allocate(capacity: chunk), r = UnsafeMutablePointer<Float>.allocate(capacity: chunk)
        defer { l.deallocate(); r.deallocate() }
        list[0] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: l)
        list[1] = AudioBuffer(mNumberChannels: 1, mDataByteSize: UInt32(chunk * 4), mData: r)
        var done = 0
        while done < frames {
            let n = min(chunk, frames - done)
            synth.render(frames: n, into: list)
            left.append(contentsOf: UnsafeBufferPointer(start: l, count: n))
            right.append(contentsOf: UnsafeBufferPointer(start: r, count: n))
            done += n
        }
        return (left, right)
    }

    private func settled() -> Synth {
        let synth = Synth()
        synth.prepare(sampleRate: Self.rate)
        synth.settle()
        return synth
    }

    private func rms(_ x: ArraySlice<Float>) -> Float {
        (x.reduce(0) { $0 + $1 * $1 } / Float(max(x.count, 1))).squareRoot()
    }

    func testABattleIsHeardFromWhereItIsAboveTheNightAndNeverClips() {
        // The night alone, over the same seconds as the din is heard and
        // after it is gone: from two to four, and from six to eight.
        let rate = Int(Self.rate)
        let held = (2 * rate)..<(4 * rate), after = (6 * rate)..<(8 * rate)
        let quiet = render(settled(), seconds: 8)
        let bed = (left: rms(quiet.left[held]), right: rms(quiet.right[held]))
        let bedAfter = rms(quiet.left[after])
        // How much of a channel is the din's, past the night's.
        func din(_ heard: Float, over night: Float) -> Float { max(heard * heard - night * night, 0) }

        let loud = settled()
        loud.setDin(level: 1, pan: 0.8)
        let battle = render(loud, seconds: 4)
        let left = rms(battle.left[held]), right = rms(battle.right[held])
        print("SOUND din \(String(format: "%.1f", 20 * log10(max(left, right)))) dBFS rms beside a bed of \(String(format: "%.1f", 20 * log10(bed.right)))")
        XCTAssertGreaterThan(right, bed.right * 2, "A great battle close by is heard well above the night")
        XCTAssertGreaterThan(din(right, over: bed.right), 4 * din(left, over: bed.left), "from the right, where it is")
        XCTAssertLessThan(max(battle.left.map(abs).max() ?? 0, battle.right.map(abs).max() ?? 0), 0.95, "and never clips")
        XCTAssertEqual(loud.dinHeard.level, 1, accuracy: 0.05)

        // A smaller fight farther off is fainter, and heard from the left.
        let faint = settled()
        faint.setDin(level: 0.35, pan: -1)
        let far = render(faint, seconds: 4)
        let farLeft = rms(far.left[held]), farRight = rms(far.right[held])
        XCTAssertLessThan(din(farLeft, over: bed.left), din(right, over: bed.right) / 2, "Fainter for fewer, farther off")
        XCTAssertGreaterThan(din(farLeft, over: bed.left), 4 * din(farRight, over: bed.right), "from the left")
        // And the din eases out when none is in sight.
        loud.setDin(level: 0, pan: 0)
        let gone = render(loud, seconds: 4)
        XCTAssertLessThan(rms(gone.left[(2 * rate)...]), bedAfter * 1.2, "Gone again with the battle")
        XCTAssertEqual(loud.dinHeard.level, 0, accuracy: 0.01)
    }

    @MainActor
    func testTheSessionHearsTheFieldsInSightAsLoudAsTheTroopsFightingThere() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "din", keepers: 1))
        let quiet = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("quiet")))
        XCTAssertNil(quiet.battleDin(), "No battle, no din")
        var told: [(Float, Float)] = []
        quiet.onDin = { told.append(($0, $1)) }
        quiet.hearBattles()
        XCTAssertTrue(told.isEmpty, "Silence is not told again")

        // A field where the keeper's company stands.
        let player = state.player
        let mine = try XCTUnwrap(state.units(of: player).first { $0.kind.isMilitary })
        var field = Field(id: 1, at: mine.position, joined: state.watch, first: player, second: (player + 1) % 4)
        field.fighters = [Fighter(unit: mine.id, owner: player, side: 0, kind: mine.kind, tier: mine.tier, leader: nil, troops: 9_000),
                          Fighter(unit: 999, owner: (player + 1) % 4, side: 1, kind: .spear, tier: 2, leader: nil, troops: 6_000)]
        state.fields = [field]
        let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("battle")))
        // The view a little to the left of it, the field within its
        // middle: to its right.
        var camera = session.camera
        camera.focus(on: mine.position)
        camera.heading = 0
        camera.centerX -= 0.3 * 600 / camera.scale
        session.camera = camera
        let din = try XCTUnwrap(session.battleDin())
        XCTAssertEqual(din.level, 1, accuracy: 1e-4, "Fifteen thousand fighting, close by: as loud as it gets")
        XCTAssertGreaterThan(din.pan, 0, "to the right of the view")
        var heard: [(Float, Float)] = []
        session.onDin = { heard.append(($0, $1)) }
        session.hearBattles()
        XCTAssertEqual(heard.count, 1)
        XCTAssertEqual(heard.last?.0 ?? 0, din.level, accuracy: 1e-4)
        session.hearBattles()
        XCTAssertEqual(heard.count, 1, "Told as it changes, not every frame")
        _ = session.sceneFrame(at: 1)
        XCTAssertEqual(heard.count, 1, "The frame hears it too, unchanged")
        // Under the stillest motion, the world and its din are still.
        session.motion = .still
        session.hearBattles()
        XCTAssertEqual(heard.last?.0, 0)
    }
}
