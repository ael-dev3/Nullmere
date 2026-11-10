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
        // marks as marks.clear.cpu.p50. In sRGB, as the screen's layers are,
        // and in their four bytes a point, blue first and alpha last in
        // memory (premultiplied first, in the host's order): the form
        // CoreGraphics draws into without turning each blend about. Drawn
        // into red-first points instead (premultiplied last), the flat marks
        // timed 8.17 ms in run 918 while the marks over the models, as a
        // fresh image in the renderer's own form, timed 2.87. The flat marks
        // are timed into red-first points once more here, beside the rest
        // (marks.flat.rgba.cpu.p50), so a run shows what that form costs.
        let pixels = CGSize(width: size.width * 2, height: size.height * 2)
        let sRGB = CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB()
        let canvas = try XCTUnwrap(CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                                             bytesPerRow: 0, space: sRGB,
                                             bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue))
        let redFirst = try XCTUnwrap(CGContext(data: nil, width: Int(pixels.width), height: Int(pixels.height), bitsPerComponent: 8,
                                               bytesPerRow: 0, space: sRGB, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        var clears: [Double] = []
        func renderOnce(modelsDrawn: Bool, into other: CGContext? = nil) -> Double {
            let target = other ?? canvas
            let marks = ImageRenderer(content: WorldMarks(session: session, modelsDrawn: modelsDrawn).frame(width: size.width, height: size.height))
            let cleared = ThreadClock.milliseconds()
            target.clear(CGRect(origin: .zero, size: pixels))
            if other == nil { clears.append(ThreadClock.milliseconds() - cleared) }
            let start = ThreadClock.milliseconds()
            marks.render(rasterizationScale: 2) { _, draw in
                target.saveGState()
                target.scaleBy(x: 2, y: 2)
                draw(target)
                target.restoreGState()
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
        // The flat marks once more into red-first points, the form they were
        // timed in until run 918: told beside them, held to nothing.
        for _ in 0..<3 { _ = renderOnce(modelsDrawn: false, into: redFirst) }
        let reds = (0..<25).map { _ in renderOnce(modelsDrawn: false, into: redFirst) }.sorted()
        print("PERFMETRIC marks.flat.rgba.cpu.p50 \(String(format: "%.3f", reds[reds.count / 2]))")
        print("PERF the flat marks into red-first points (premultiplied last), held to nothing: median "
              + "\(String(format: "%.2f", reds[reds.count / 2])) ms")
        for _ in 0..<3 { _ = imageOnce() }
        let images = (0..<25).map { _ in imageOnce() }.sorted()
        clears.sort()
        print("PERFMETRIC marks.clear.cpu.p50 \(String(format: "%.3f", clears[clears.count / 2]))")
        print("PERF the marks' bitmap cleared before each sample, untimed: median \(String(format: "%.2f", clears[clears.count / 2])) ms")
        print("PERFMETRIC marks.image.cpu.p50 \(String(format: "%.3f", images[images.count / 2]))")
        print("PERF marks as a fresh image each time, held to nothing: median \(String(format: "%.2f", images[images.count / 2])) ms")
        let best = beside.min() ?? StagingTimes.plainPace
        print("PERFMETRIC marks.pace.cpu \(String(format: "%.3f", best))")
        // The same shapes timed three ways into the same canvas, held to
        // nothing and told beside the marks: a path for them all (run 939's
        // marks, a path a colour across the view), a path for each square of
        // the view (`GatheredMarks`), and a fill for each shape (run 933's).
        // A run shows which way the marks' cost goes on the runner.
        let spots: [CGRect] = (0..<120).map { index in
            CGRect(x: CGFloat((index * 7919) % Int(size.width)), y: CGFloat((index * 104729) % Int(size.height)), width: 9, height: 9)
        }
        func shapesOnce(_ mode: Int) -> Double {
            let shapes = Canvas { context, _ in
                switch mode {
                case 0:
                    var whole = Path()
                    for spot in spots { whole.addRect(spot) }
                    context.fill(whole, with: .color(.white))
                case 1:
                    var squares: [Int: Path] = [:]
                    for spot in spots { squares[GatheredMarks.key(0, at: spot.origin), default: Path()].addRect(spot) }
                    for key in squares.keys.sorted() {
                        if let square = squares[key] { context.fill(square, with: .color(.white)) }
                    }
                default:
                    for spot in spots { context.fill(Path(spot), with: .color(.white)) }
                }
            }
            let renderer = ImageRenderer(content: shapes.frame(width: size.width, height: size.height))
            canvas.clear(CGRect(origin: .zero, size: pixels))
            let start = ThreadClock.milliseconds()
            renderer.render(rasterizationScale: 2) { _, draw in
                canvas.saveGState()
                canvas.scaleBy(x: 2, y: 2)
                draw(canvas)
                canvas.restoreGState()
            }
            return ThreadClock.milliseconds() - start
        }
        for mode in 0..<3 { for _ in 0..<3 { _ = shapesOnce(mode) } }
        var shapeTimes: [[Double]] = [[], [], []]
        for _ in 0..<25 { for mode in 0..<3 { shapeTimes[mode].append(shapesOnce(mode)) } }
        for (mode, name) in ["shapes.whole", "shapes.squares", "shapes.each"].enumerated() {
            let sorted = shapeTimes[mode].sorted()
            print("PERFMETRIC \(name).cpu.p50 \(String(format: "%.3f", sorted[sorted.count / 2]))")
        }
        let pace = min(max(best / StagingTimes.plainPace, 1), 2)
        for (name, median) in medians {
            XCTAssertLessThan(median, 5 * pace, "The marks must leave the frame to the world (\(name), at x\(pace) for the Mac's pace)")
        }
    }
}
