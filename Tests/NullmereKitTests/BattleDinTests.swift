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
        let quiet = render(settled(), seconds: 4)
        let bed = rms(quiet.left[...])
        let loud = settled()
        loud.setDin(level: 1, pan: 0.8)
        let battle = render(loud, seconds: 4)
        // Past its easing in, the last two seconds.
        let second = Int(2 * Self.rate)
        let left = rms(battle.left[second...]), right = rms(battle.right[second...])
        print("SOUND din \(String(format: "%.1f", 20 * log10(max(left, right)))) dBFS rms beside a bed of \(String(format: "%.1f", 20 * log10(bed)))")
        XCTAssertGreaterThan(right, bed * 2, "A great battle close by is heard well above the night")
        XCTAssertGreaterThan(right, left * 1.5, "from the right, where it is")
        XCTAssertLessThan(max(battle.left.map(abs).max() ?? 0, battle.right.map(abs).max() ?? 0), 0.95, "and never clips")
        XCTAssertEqual(loud.dinHeard.level, 1, accuracy: 0.05)

        // A small fight far off is fainter; and the din eases out when none is in sight.
        let faint = settled()
        faint.setDin(level: 0.15, pan: -1)
        let far = render(faint, seconds: 4)
        XCTAssertLessThan(rms(far.left[second...]), right, "Fainter for fewer, farther off")
        XCTAssertGreaterThan(rms(far.left[second...]), rms(far.right[second...]), "from the left")
        loud.setDin(level: 0, pan: 0)
        let after = render(loud, seconds: 4)
        XCTAssertLessThan(rms(after.left[second...]), bed * 1.2, "Gone again with the battle")
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
        // The view a little to the left of it: the field to its right.
        var camera = session.camera
        camera.focus(on: mine.position)
        camera.centerX -= 40
        session.camera = camera
        let din = try XCTUnwrap(session.battleDin())
        XCTAssertGreaterThan(din.level, 0.5, "Fifteen thousand fighting, close by")
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
