import AppKit
import LauncherCore
import SwiftUI
import XCTest
@testable import LauncherKit

/// The launcher hears the pointer through AppKit's tracking areas, not
/// SwiftUI's hover, which keeps what lay under the pointer alive.
@MainActor
final class PointerAreaTests: XCTestCase {
    private func crossing(_ type: NSEvent.EventType) -> NSEvent {
        NSEvent.enterExitEvent(with: type, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0, context: nil,
                               eventNumber: 0, trackingNumber: 0, userData: nil)!
    }

    func testThePointerIsHeardComingAndGoingOnceEach() {
        var heard: [Bool] = []
        let area = PointerAreaView(cursor: nil) { heard.append($0) }
        area.mouseEntered(with: crossing(.mouseEntered))
        area.mouseEntered(with: crossing(.mouseEntered))
        XCTAssertTrue(area.isInside)
        area.mouseExited(with: crossing(.mouseExited))
        area.mouseExited(with: crossing(.mouseExited))
        XCTAssertFalse(area.isInside)
        XCTAssertEqual(heard, [true, false], "Told once as the pointer came, once as it left")

        // It follows its own visible rect, and only while the app is in front.
        XCTAssertEqual(area.trackingAreas.count, 1)
        let options = area.trackingAreas[0].options
        XCTAssertTrue(options.contains(.mouseEnteredAndExited))
        XCTAssertTrue(options.contains(.inVisibleRect))
        XCTAssertTrue(options.contains(.activeInActiveApp))
        // Clicks pass through it to what lies beneath.
        XCTAssertNil(area.hitTest(NSPoint(x: 1, y: 1)))
    }

    func testALinkShowsThePointingHandAndOthersNoCursor() {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let link = PointerAreaView(cursor: .pointingHand, onChange: nil)
        link.frame = NSRect(x: 0, y: 0, width: 100, height: 40)
        window.contentView?.addSubview(link)
        link.resetCursorRects()
        link.cursor = nil
        link.resetCursorRects()
        XCTAssertNil(link.cursor)
        link.cursor = .pointingHand
        XCTAssertEqual(link.cursor, .pointingHand)
        link.mouseEntered(with: crossing(.mouseEntered))
        XCTAssertTrue(link.isInside, "A link with no one listening still knows the pointer is there")

        // The modifier sets it so where it is drawn.
        let host = NSHostingView(rootView: Text("nullmere.online").linkPointer())
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 40)
        window.contentView = host
        let drawn = drawnAreas(in: host, expecting: 1)
        XCTAssertEqual(drawn.count, 1)
        XCTAssertEqual(drawn.first?.cursor, .pointingHand)
    }

    /// Each item of the main menu is chosen as the pointer comes over it, as
    /// it was by SwiftUI's hover.
    func testTheMenuFollowsThePointer() throws {
        let suite = "PointerAreaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let model = LauncherModel(defaults: defaults, environment: LauncherEnvironment(
            modelReadiness: { .ready },
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { _ in true },
            terminate: {}
        ))
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 120), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = NSHostingView(rootView: MainMenu(model: model))
        window.contentView = host
        window.orderFrontRegardless()
        let drawn = drawnAreas(in: host, expecting: MenuItem.allCases.count)
        XCTAssertEqual(drawn.count, MenuItem.allCases.count, "An area for each item")
        var chosen: [MenuItem] = []
        for area in drawn {
            area.pointer(isInside: true)
            chosen.append(model.menuSelection)
            area.pointer(isInside: false)
        }
        XCTAssertEqual(Set(chosen.map(\.title)), Set(MenuItem.allCases.map(\.title)), "The pointer over each item chooses it")
    }

    /// The areas drawn in a window's hosting view, once it has drawn them.
    private func drawnAreas(in host: NSView, expecting count: Int) -> [PointerAreaView] {
        let deadline = Date().addingTimeInterval(5)
        while areas(in: host).count < count, Date() < deadline {
            host.layoutSubtreeIfNeeded()
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        return areas(in: host)
    }

    private func areas(in view: NSView) -> [PointerAreaView] {
        view.subviews.flatMap { child -> [PointerAreaView] in ((child as? PointerAreaView).map { [$0] } ?? []) + areas(in: child) }
    }
}
