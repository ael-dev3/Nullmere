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
        // Drawn into one bitmap kept across the samples, as the game draws
        // its marks into a layer kept from frame to frame: what is timed is
        // their drawing, not a fresh image of 3024x1964 made and filled for
        // each, whose cost is the test process's memory's more than the
        // marks' (run 902 timed 27 holds, 67 companies and no blows at 4.10
        // ms that way). A fresh renderer each time: one renderer keeps its
        // image.
        // The bitmap is cleared before each sample's clock starts: a layer
        // is cleared by the compositor, not by the marks, and clearing all
        // 3024x1964 points (24 MB) in the timed part made it most of the
        // figure (run 914: 2.45 ms against 1.98 for a fresh image each time,
        // whose untouched pages cost nothing). Its cost is told beside the
        // marks as marks.clear.cpu.p50. In sRGB, as the screen's layers are.
        let pixels = CGSize(width: size.width * 2, height: size.height * 2)
        let canvas = try XCTUnwrap(CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                                             bytesPerRow: 0, space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                             bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        var clears: [Double] = []
        func renderOnce(modelsDrawn: Bool) -> Double {
            let marks = ImageRenderer(content: WorldMarks(session: session, modelsDrawn: modelsDrawn).frame(width: size.width, height: size.height))
            let cleared = ThreadClock.milliseconds()
            canvas.clear(CGRect(origin: .zero, size: pixels))
            clears.append(ThreadClock.milliseconds() - cleared)
            let start = ThreadClock.milliseconds()
            marks.render(rasterizationScale: 2) { _, draw in
                canvas.saveGState()
                canvas.scaleBy(x: 2, y: 2)
                draw(canvas)
                canvas.restoreGState()
            }
            return ThreadClock.milliseconds() - start
        }
        /// How many of the bitmap's points the marks drew, sampled every
        /// eighth point of every eighth row: that the drawing timed drew.
        func drawn() -> Int {
            guard let data = canvas.data else { return 0 }
            let bytes = data.bindMemory(to: UInt8.self, capacity: canvas.bytesPerRow * canvas.height)
            var count = 0
            for y in stride(from: 0, to: canvas.height, by: 8) {
                for x in stride(from: 0, to: canvas.width, by: 8) where bytes[y * canvas.bytesPerRow + x * 4 + 3] > 0 {
                    count += 1
                }
            }
            return count
        }
        // The old way too, a fresh image each time, held to nothing: told
        // beside the drawing alone, so a run shows what the image costs.
        func imageOnce() -> Double {
            let marks = ImageRenderer(content: WorldMarks(session: session, modelsDrawn: true).frame(width: size.width, height: size.height))
            marks.scale = 2
            let start = ThreadClock.milliseconds()
            let image = marks.cgImage
            let elapsed = ThreadClock.milliseconds() - start
            XCTAssertNotNil(image)
            return elapsed
        }
        let holds = session.state.holds.filter { session.isExplored($0.position) }.count
        // Plain work timed beside the marks, none of it the game's: how busy
        // the shared Mac is while they are timed (scripts/perf-check.py
        // paces the marks' figures by it, and so does the bound here).
        var beside: [Double] = []
        func plain() {
            let start = ThreadClock.milliseconds()
            XCTAssertNotEqual(StagingTimes.plainWork(seed: UInt64(beside.count)), 0)
            beside.append(ThreadClock.milliseconds() - start)
        }
        plain()
        var medians: [(String, Double)] = []
        for (name, modelsDrawn) in [("marks", true), ("marks.flat", false)] {
            // Warmed three times and timed 25: ImageRenderer's first draws
            // pay for caches, and a dozen samples on a shared runner let one
            // stall move the median (runs 511 and 517 timed the same marks at
            // 1.75 and 5.07 ms).
            for _ in 0..<3 { _ = renderOnce(modelsDrawn: modelsDrawn) }
            var times: [Double] = []
            for _ in 0..<25 {
                times.append(renderOnce(modelsDrawn: modelsDrawn))
            }
            XCTAssertGreaterThan(drawn(), 0, "The marks drawn in the bitmap timed (\(name))")
            times.sort()
            let median = times[times.count / 2]
            print("PERFMETRIC \(name).cpu.p50 \(String(format: "%.3f", median))")
            print("PERF \(name) \(Int(size.width))x\(Int(size.height))@2x, \(holds) holds and \(session.state.units.count) companies, "
                  + "\(session.blows.count) blows, \(session.reach.count) tiles of reach: median \(String(format: "%.2f", median)) ms")
            medians.append((name, median))
            plain()
        }
        for _ in 0..<3 { _ = imageOnce() }
        let images = (0..<25).map { _ in imageOnce() }.sorted()
        clears.sort()
        print("PERFMETRIC marks.clear.cpu.p50 \(String(format: "%.3f", clears[clears.count / 2]))")
        print("PERF the marks' bitmap cleared before each sample, untimed: median \(String(format: "%.2f", clears[clears.count / 2])) ms")
        print("PERFMETRIC marks.image.cpu.p50 \(String(format: "%.3f", images[images.count / 2]))")
        print("PERF marks as a fresh image each time, held to nothing: median \(String(format: "%.2f", images[images.count / 2])) ms")
        let best = beside.min() ?? StagingTimes.plainPace
        print("PERFMETRIC marks.pace.cpu \(String(format: "%.3f", best))")
        let pace = min(max(best / StagingTimes.plainPace, 1), 2)
        for (name, median) in medians {
            XCTAssertLessThan(median, 5 * pace, "The marks must leave the frame to the world (\(name), at x\(pace) for the Mac's pace)")
        }
    }
}
