import NullmereCore
import SwiftUI
import XCTest
@testable import NullmereKit
import NullmereWorld

/// The marks drawn over the map (holds, companies, names, routes, reach)
/// must leave the GPU its frame: measured offscreen over a busy late game.
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
        func renderOnce() -> Double {
            let renderer = ImageRenderer(content: WorldMarks(session: session).frame(width: size.width, height: size.height))
            renderer.scale = 2
            let start = ThreadClock.milliseconds()
            let image = renderer.cgImage
            let elapsed = ThreadClock.milliseconds() - start
            XCTAssertNotNil(image)
            return elapsed
        }
        _ = renderOnce()
        var times: [Double] = []
        for _ in 0..<12 {
            times.append(renderOnce())
        }
        times.sort()
        let median = times[times.count / 2]
        print("PERFMETRIC marks.cpu.p50 \(String(format: "%.3f", median))")
        let holds = session.state.holds.filter { session.isExplored($0.position) }.count
        print("PERF marks \(Int(size.width))x\(Int(size.height))@2x, \(holds) holds and \(session.state.units.count) companies: median \(String(format: "%.2f", median)) ms")
        XCTAssertLessThan(median, 5, "The marks must leave the frame to the world")
    }
}
