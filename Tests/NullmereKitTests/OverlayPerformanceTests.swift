import NullmereCore
import SwiftUI
import XCTest
@testable import NullmereKit
import NullmereWorld

/// The marks drawn over the world (names, bars, ranks, routes, reach)
/// must leave the GPU its frame: measured offscreen over a busy late game,
/// as the game draws them over the world's models, and as a Mac that
/// cannot draw the world draws them flat, tokens and all.
@MainActor
final class OverlayPerformanceTests: XCTestCase {
    func testTheMarksDrawWellWithinAFrame() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "busy overlay", keepers: 1)), store: LocalStore(directory: dir))
        session.autoplay(watches: 90)
        session.selectNextReadyUnit()
        var camera = session.camera
        camera.scale = 16
        session.camera = camera

        let size = CGSize(width: 1512, height: 982)
        // A fresh renderer each time: one renderer keeps its image.
        func renderOnce(modelsDrawn: Bool) -> Double {
            let renderer = ImageRenderer(content: WorldMarks(session: session, modelsDrawn: modelsDrawn).frame(width: size.width, height: size.height))
            renderer.scale = 2
            let start = ThreadClock.milliseconds()
            let image = renderer.cgImage
            let elapsed = ThreadClock.milliseconds() - start
            XCTAssertNotNil(image)
            return elapsed
        }
        let holds = session.state.holds.filter { session.isExplored($0.position) }.count
        for (name, modelsDrawn) in [("marks", true), ("marks.flat", false)] {
            _ = renderOnce(modelsDrawn: modelsDrawn)
            var times: [Double] = []
            for _ in 0..<12 {
                times.append(renderOnce(modelsDrawn: modelsDrawn))
            }
            times.sort()
            let median = times[times.count / 2]
            print("PERFMETRIC \(name).cpu.p50 \(String(format: "%.3f", median))")
            print("PERF \(name) \(Int(size.width))x\(Int(size.height))@2x, \(holds) holds and \(session.state.units.count) companies, "
                  + "\(session.blows.count) blows, \(session.reach.count) tiles of reach: median \(String(format: "%.2f", median)) ms")
            XCTAssertLessThan(median, 5, "The marks must leave the frame to the world (\(name))")
        }
    }
}
