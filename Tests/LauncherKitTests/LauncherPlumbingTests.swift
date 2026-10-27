import AppKit
import LauncherCore
import Metal
import NullmereTestSupport
import SwiftUI
import XCTest
@testable import LauncherKit

/// The news fetched from the repository, against a server in memory: the
/// feed read, and each way the download can fail.
final class NewsDownloaderTests: XCTestCase {
    private func download(_ answer: StubHTTP.Answer) async throws -> Data {
        let server = StubHTTP.serve { _ in answer }
        return try await NewsDownloader.download(from: server.address.appendingPathComponent("news/news.json"),
                                                 configuration: server.session.configuration)
    }

    func testTheFeedIsRead() async throws {
        let server = StubHTTP.serve { _ in StubHTTP.Answer(text: #"{"items":[]}"#) }
        let data = try await NewsDownloader.download(from: server.address.appendingPathComponent("news/news.json"),
                                                     configuration: server.session.configuration)
        XCTAssertEqual(String(decoding: data, as: UTF8.self), #"{"items":[]}"#)
        XCTAssertEqual(server.requests.first?.url.path, "/news/news.json")
        XCTAssertEqual(server.requests.first?.method, "GET")
    }

    func testAMissingFeedFails() async {
        do {
            _ = try await download(StubHTTP.Answer(status: 404, text: "Not Found"))
            XCTFail("A missing feed is not news")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .badServerResponse)
        }
    }

    func testAnOversizedFeedFails() async {
        do {
            _ = try await download(StubHTTP.Answer(body: Data(count: NewsDownloader.maximumSize + 1)))
            XCTFail("Too large to be news")
        } catch {
            XCTAssertEqual((error as? URLError)?.code, .dataLengthExceedsMaximum)
        }
    }

    func testAServerOutOfReachFails() async {
        let server = StubHTTP.serve { _ in throw URLError(.cannotConnectToHost) }
        do {
            _ = try await NewsDownloader.download(from: server.address, configuration: server.session.configuration)
            XCTFail("No news from a server out of reach")
        } catch {
            XCTAssertNotNil(error as? URLError)
        }
    }

    func testTheFeedIsMainsUnlessABuildForTestingSaysOtherwise() {
        XCTAssertEqual(NewsDownloader.mainFeedURL.absoluteString, "https://raw.githubusercontent.com/ael-dev3/Nullmere/main/news/news.json")
        let key = "NULLMERE_NEWS_URL"
        let saved = ProcessInfo.processInfo.environment[key]
        defer { if let saved { setenv(key, saved, 1) } else { unsetenv(key) } }
        unsetenv(key)
        XCTAssertEqual(NewsDownloader.feedURL, NewsDownloader.mainFeedURL)
        setenv(key, "http://plain.test/news.json", 1)
        XCTAssertEqual(NewsDownloader.feedURL, NewsDownloader.mainFeedURL, "Only https")
        setenv(key, "https://raw.githubusercontent.com/ael-dev3/Nullmere/branch/news/news.json", 1)
        XCTAssertEqual(NewsDownloader.feedURL.absoluteString, "https://raw.githubusercontent.com/ael-dev3/Nullmere/branch/news/news.json")
    }
}

/// What the launcher asks of the Mac: the live answers, and the keys a
/// test build can be driven by.
@MainActor
final class LauncherEnvironmentTests: XCTestCase {
    func testTheLiveEnvironmentAnswers() {
        let live = LauncherEnvironment.live
        _ = live.systemSavesEnergy()
        let readiness = live.modelReadiness()
        XCTAssertEqual(readiness, OnDeviceModel.current())
    }

    func testDebugKeysAreRead() {
        let key = "NULLMERE_LAUNCHER_KEYS"
        let saved = ProcessInfo.processInfo.environment[key]
        defer { if let saved { setenv(key, saved, 1) } else { unsetenv(key) } }
        setenv(key, "up, down,left,RIGHT,return,enter,space,escape,esc,sideways", 1)
        XCTAssertEqual(LauncherEnvironment.debugKeys, [.up, .down, .left, .right, .confirm, .confirm, .confirm, .back, .back])
        unsetenv(key)
        XCTAssertEqual(LauncherEnvironment.debugKeys, [])
    }
}

/// The lake's Metal view in a real window: the shader loaded, frames drawn
/// at the size and pace asked for, the display link stopped when there is
/// nothing to animate, and a shader that fails said once.
@MainActor
final class LakeMetalViewTests: XCTestCase {
    private func spin(_ seconds: Double) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func configuration(_ motion: ResolvedMotion = .full, renderScale: Double = 0.5) -> LakeConfiguration {
        LakeConfiguration(motion: motion, renderScale: renderScale, framesPerSecond: 30, horizon: LakeComposition.horizon)
    }

    func testTheLakeDrawsInAWindow() throws {
        guard LakeMetalView.systemDevice != nil else { throw XCTSkip("No Metal device available") }
        let view = LakeMetalView(configuration: configuration())
        var failures = 0
        view.onFailure = { failures += 1 }
        XCTAssertTrue(view.isOpaque)
        XCTAssertTrue(view.mouseDownCanMoveWindow, "The lake moves the window")

        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 800, height: 500), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = view
        window.orderFrontRegardless()
        defer { window.close() }
        let deadline = Date().addingTimeInterval(20)
        while view.renderer == nil, Date() < deadline { spin(0.05) }
        XCTAssertNotNil(view.renderer, "The shader compiled and the pipeline was built")
        XCTAssertEqual(failures, 0)
        XCTAssertEqual(view.preferredFramesPerSecond, 30)

        func expectedWidth(_ scale: Double) -> CGFloat {
            max(1, (view.bounds.width * window.backingScaleFactor * scale).rounded())
        }
        XCTAssertEqual(view.drawableSize.width, expectedWidth(0.5), "Drawn at half the display's pixels")
        view.draw(view.bounds)
        spin(0.1)
        if window.occlusionState.contains(.visible) {
            XCTAssertFalse(view.isPaused, "A visible lake in full motion animates")
        }

        // Still: one frame per change, no display link.
        view.configuration = configuration(.still)
        XCTAssertTrue(view.isPaused)
        XCTAssertTrue(view.enableSetNeedsDisplay)
        view.draw(view.bounds)

        // Sharper, and resized.
        view.configuration = configuration(.reduced, renderScale: 1)
        XCTAssertEqual(view.drawableSize.width, expectedWidth(1))
        view.setFrameSize(NSSize(width: 640, height: 400))
        XCTAssertEqual(view.drawableSize.width, expectedWidth(1))
        view.viewDidChangeBackingProperties()
        view.draw(view.bounds)

        // Out of the window: nothing is watched, and nothing animates.
        window.contentView = nil
        XCTAssertTrue(view.isPaused)
        XCTAssertEqual(failures, 0)
    }

    func testAFailingShaderIsSaidOnce() throws {
        guard let device = LakeMetalView.systemDevice else { throw XCTSkip("No Metal device available") }
        let uncompiled = LakeMetalView(configuration: configuration())
        var told = 0
        uncompiled.onFailure = { told += 1 }
        uncompiled.finishLoading(device: device, library: nil, error: nil, pixelFormat: .bgra8Unorm)
        uncompiled.finishLoading(device: device, library: nil, error: nil, pixelFormat: .bgra8Unorm)
        XCTAssertEqual(told, 1, "Told once")
        XCTAssertNil(uncompiled.renderer)

        // A library without the lake's functions: no pipeline.
        let empty = try device.makeLibrary(source: "#include <metal_stdlib>\nusing namespace metal;\nkernel void nothing() {}\n", options: nil)
        let unbuilt = LakeMetalView(configuration: configuration())
        var unbuiltTold = 0
        unbuilt.onFailure = { unbuiltTold += 1 }
        unbuilt.finishLoading(device: device, library: empty, error: nil, pixelFormat: .bgra8Unorm)
        XCTAssertEqual(unbuiltTold, 1)
        XCTAssertNil(unbuilt.renderer)
    }
}

/// The window the launcher lives in: styled for the lake, and the keys and
/// clicks it sees passed to the model as the launcher means them.
@MainActor
final class WindowBridgeTests: XCTestCase {
    private func key(_ code: UInt16, in window: NSWindow?, modifiers: NSEvent.ModifierFlags = [], repeated: Bool = false) -> NSEvent {
        NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: modifiers, timestamp: 0, windowNumber: window?.windowNumber ?? 0,
                         context: nil, characters: "", charactersIgnoringModifiers: "", isARepeat: repeated, keyCode: code)!
    }

    func testTheWindowIsStyledAndItsKeysAndClicksReachTheModel() throws {
        var keys: [KeyCommand] = []
        var clicks = 0
        let bridge = WindowBridgeView(startsInFullScreen: false, onKey: { keys.append($0) }, onClick: { clicks += 1 })
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled, .fullSizeContentView],
                              backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        window.contentView = content
        content.addSubview(bridge)
        window.orderFrontRegardless()
        defer { window.close() }

        XCTAssertEqual(window.backgroundColor, .black)
        XCTAssertTrue(window.titlebarAppearsTransparent)
        XCTAssertEqual(window.titleVisibility, .hidden)
        XCTAssertTrue(window.isMovableByWindowBackground)
        XCTAssertTrue(bridge.isMonitoring)
        XCTAssertFalse(window.styleMask.contains(.fullScreen))

        // Arrows step, held or not; Return acts once per press.
        XCTAssertNil(bridge.monitored(key(126, in: window), keyboardNavigation: false))
        XCTAssertNil(bridge.monitored(key(125, in: window, repeated: true), keyboardNavigation: false))
        XCTAssertNil(bridge.monitored(key(36, in: window), keyboardNavigation: false))
        XCTAssertNil(bridge.monitored(key(36, in: window, repeated: true), keyboardNavigation: false), "Taken, but not acted on again")
        XCTAssertEqual(keys, [.up, .down, .confirm])

        // Space confirms, unless keyboard navigation gives it to the focused control.
        XCTAssertNil(bridge.monitored(key(49, in: window), keyboardNavigation: false))
        XCTAssertNotNil(bridge.monitored(key(49, in: window), keyboardNavigation: true))
        XCTAssertEqual(keys.last, .confirm)
        XCTAssertEqual(keys.count, 4)

        // Shortcuts, other keys and other windows' keys pass on untouched.
        XCTAssertNotNil(bridge.monitored(key(126, in: window, modifiers: [.command]), keyboardNavigation: false))
        XCTAssertNotNil(bridge.monitored(key(0, in: window), keyboardNavigation: false), "A is no command")
        let other = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 100, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        other.isReleasedWhenClosed = false
        other.orderFrontRegardless()
        defer { other.close() }
        XCTAssertNotNil(bridge.monitored(key(126, in: other), keyboardNavigation: false))
        XCTAssertEqual(keys.count, 4)
        // Arrows carry the function and keypad flags, and still count.
        XCTAssertNil(bridge.monitored(key(124, in: window, modifiers: [.function, .numericPad, .shift]), keyboardNavigation: false))
        XCTAssertEqual(keys.last, .right)

        // A click is told, and still reaches the window.
        let click = NSEvent.mouseEvent(with: .leftMouseDown, location: NSPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0,
                                       windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
        XCTAssertNotNil(bridge.monitored(click, keyboardNavigation: false))
        XCTAssertEqual(clicks, 1)

        // Out of the window, it stops listening.
        bridge.removeFromSuperview()
        XCTAssertFalse(bridge.isMonitoring)
    }

    func testFullScreenAtLaunchIsAskedForOnce() {
        var entered: [NSWindow] = []
        let bridge = WindowBridgeView(startsInFullScreen: true, onKey: { _ in }, onClick: {})
        bridge.enterFullScreen = { entered.append($0) }
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 600, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let content = NSView(frame: NSRect(x: 0, y: 0, width: 600, height: 400))
        window.contentView = content
        defer { window.close() }
        content.addSubview(bridge)
        // Moved again within the same window: configured once.
        bridge.removeFromSuperview()
        content.addSubview(bridge)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(entered.count, 1)
        XCTAssertTrue(entered.first === window)

        let windowed = WindowBridgeView(startsInFullScreen: false, onKey: { _ in }, onClick: {})
        windowed.enterFullScreen = { entered.append($0) }
        content.addSubview(windowed)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        XCTAssertEqual(entered.count, 1, "Not asked for, not entered")
    }
}

/// The darkness laid on the water under an open panel: deepest over the
/// moon's reflection, where the panels' words and buttons lie, so they
/// read clearly over it, and clear toward the lake's far edges.
@MainActor
final class PanelScrimTests: XCTestCase {
    func testTheReflectionIsDarkenedUnderAPanelAndTheEdgesAreNot() throws {
        let width = 1200, height = Int(800 * LakeComposition.horizon)
        let renderer = ImageRenderer(content: PanelScrim().frame(width: CGFloat(width), height: CGFloat(height)).background(Color.white))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return false }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
            return true
        }
        XCTAssertTrue(drawn)
        // How much of the white beneath shows through, 0...1, the buffer's first row the top.
        func light(_ x: Double, _ y: Double) -> Double {
            let px = min(width - 1, Int(x * Double(width))), py = min(height - 1, Int(y * Double(height)))
            let i = (py * width + px) * 4
            return Double(Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])) / 765
        }
        let depth = PanelScrim.reflectionDepth
        XCTAssertEqual(depth, 0.69, accuracy: 0.01)
        // The moon's image, a disc of its radius about that depth.
        let radius = LakeComposition.moonRadius / LakeComposition.horizon
        let across = LakeComposition.moonRadius * 800 / 1200
        for (dx, dy) in [(0.0, 0.0), (0.0, -radius), (0.0, radius), (-across, 0.0), (across, 0.0)] {
            XCTAssertLessThan(light(0.5 + dx, depth + dy), 0.2, "Over the moon's image, at \(dx), \(dy)")
        }
        XCTAssertGreaterThan(light(0.02, 0.02), 0.9, "The lake's far corners are left clear")
        XCTAssertGreaterThan(light(0.5, 0.0), light(0.5, depth) + 0.2, "The water by the shore is lighter than over the reflection")
    }
}
