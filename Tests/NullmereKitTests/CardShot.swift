import AppKit
import NullmereTestSupport
import SwiftUI
import XCTest

/// A card or panel photographed as AppKit draws it in a window, for CI to
/// print with its screenshots. SwiftUI's ImageRenderer, which drew them
/// before, can't draw what AppKit draws for a view: it drew a "prohibited"
/// sign where a card's button stands, and left blank the title VoiceOver is
/// sent to first (run 766's `game-briefing.png` and `game-away.png`), so the
/// cards CI printed were not the cards a keeper sees.
@MainActor
enum CardShot {
    /// The view drawn on black at twice its size in points, at `size` or as
    /// large as it would be.
    static func draw(_ view: some View, size: CGSize? = nil) throws -> CGImage {
        let hosting = NSHostingView(rootView: AnyView(view.background(Color.black)))
        let drawn = size ?? hosting.fittingSize
        XCTAssertGreaterThan(drawn.width * drawn.height, 0, "A size to draw at")
        hosting.frame = NSRect(origin: .zero, size: drawn)
        let window = NSWindow(contentRect: hosting.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = hosting
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        // Laid out and drawn in the window, as it would be shown.
        for _ in 0..<4 {
            hosting.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        let scale: CGFloat = 2
        let rep = try XCTUnwrap(NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(drawn.width * scale), pixelsHigh: Int(drawn.height * scale),
                                                 bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                                                 colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0))
        rep.size = drawn
        hosting.cacheDisplay(in: hosting.bounds, to: rep)
        return try XCTUnwrap(rep.cgImage)
    }

    /// The view drawn, never blank, and kept as `name` where CI asks for
    /// its renders.
    static func keep(_ view: some View, as name: String, size: CGSize? = nil) throws {
        let image = try draw(view, size: size)
        XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
        guard let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] else { return }
        let build = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: build.appendingPathComponent(name))
    }
}
