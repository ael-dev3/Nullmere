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

    /// Disabled, an area hears nothing; turned off with the pointer over it,
    /// it says the pointer left, and turned back on, that it came.
    func testADisabledAreaIsDeaf() {
        var heard: [Bool] = []
        let area = PointerAreaView(cursor: .pointingHand) { heard.append($0) }
        area.isEnabled = false
        area.pointer(isInside: true)
        settle()
        XCTAssertEqual(heard, [], "Disabled, it hears the pointer come and says nothing")
        XCTAssertTrue(area.isInside, "but knows it is there")
        area.isEnabled = true
        XCTAssertEqual(heard, [], "Told only once SwiftUI is done updating the view")
        settle()
        XCTAssertEqual(heard, [true])
        area.isEnabled = false
        settle()
        XCTAssertEqual(heard, [true, false], "Turned off under the pointer, it lets it go")
        area.pointer(isInside: false)
        area.isEnabled = true
        settle()
        XCTAssertEqual(heard, [true, false], "and the pointer gone, turning it on says nothing")

        // A disabled link shows no hand.
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 200, height: 100), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = NSHostingView(rootView: Text("nullmere.online").linkPointer().disabled(true))
        host.frame = NSRect(x: 0, y: 0, width: 200, height: 40)
        window.contentView = host
        let drawn = drawnAreas(in: host, expecting: 1)
        XCTAssertEqual(drawn.first?.isEnabled, false, "SwiftUI's disabling reaches the area")
        drawn.first?.resetCursorRects()
    }

    /// While the launcher's menu waits hidden for the lake and the title, its
    /// items don't answer a pointer resting where they will be.
    func testTheLaunchersHiddenMenuIsDeaf() throws {
        let suite = "PointerAreaTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        // In full motion, whatever the Mac's own setting, the opening plays
        // out over seconds.
        LauncherSettings(motion: .full).save(to: defaults)
        let model = LauncherModel(defaults: defaults, environment: LauncherEnvironment(
            modelReadiness: { .ready },
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { _ in true },
            terminate: {}
        ))
        model.refreshReadiness()
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        defer { window.close() }
        let host = NSHostingView(rootView: LauncherRootView(model: model))
        window.contentView = host
        window.orderFrontRegardless()
        // The menu's items, the footer's link.
        let count = MenuItem.allCases.count + 1
        let hidden = drawnAreas(in: host, expecting: count)
        XCTAssertEqual(hidden.count, count)
        XCTAssertFalse(model.intro.showsMenu, "The menu still waits for the lake and the title")
        XCTAssertTrue(hidden.allSatisfy { !$0.isEnabled }, "Hidden, the menu and the footer are deaf")

        model.completeIntro()
        let deadline = Date().addingTimeInterval(5)
        while !areas(in: host).allSatisfy(\.isEnabled), Date() < deadline { settle() }
        XCTAssertTrue(areas(in: host).allSatisfy(\.isEnabled), "Shown, they answer")
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

    /// In every panel, as on the menu, the pointer over an item chooses it.
    func testEachPanelFollowsThePointer() throws {
        func model(_ readiness: ModelReadiness) throws -> LauncherModel {
            let suite = "PointerAreaTests.\(UUID().uuidString)"
            let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
            addTeardownBlock { defaults.removePersistentDomain(forName: suite) }
            let model = LauncherModel(defaults: defaults, environment: LauncherEnvironment(
                modelReadiness: { readiness },
                systemSavesEnergy: { false },
                downloadNews: { throw URLError(.notConnectedToInternet) },
                open: { _ in true },
                terminate: {}
            ))
            model.refreshReadiness()
            return model
        }
        /// Hosts the panel, brings the pointer over each item in turn, and
        /// says what was chosen each time.
        func chosen<T>(in panel: some View, count: Int, _ choice: () -> T) -> [T] {
            let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 700), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false
            defer { window.close() }
            let host = NSHostingView(rootView: panel)
            window.contentView = host
            window.orderFrontRegardless()
            var picks: [T] = []
            for area in drawnAreas(in: host, expecting: count) where area.onChange != nil {
                area.pointer(isInside: true)
                picks.append(choice())
                area.pointer(isInside: false)
            }
            return picks
        }

        let ready = try model(.ready)
        XCTAssertGreaterThan(ready.visibleNews.count, 1)
        let news = chosen(in: NewsPanel(model: ready), count: ready.visibleNews.count) { ready.newsSelection }
        XCTAssertEqual(Set(news), Set(ready.visibleNews.indices), "Each headline")
        let play = chosen(in: PlayPanel(model: ready), count: LauncherModel.PlayChoice.allCases.count) { ready.playSelection }
        XCTAssertEqual(Set(play.map { "\($0)" }).count, LauncherModel.PlayChoice.allCases.count, "Each way on")
        let settings = chosen(in: SettingsPanel(model: ready), count: SettingsRow.allCases.count) { ready.settingsSelection }
        XCTAssertEqual(Set(settings.map { "\($0)" }).count, SettingsRow.allCases.count, "Each setting")

        let gated = try model(.appleIntelligenceNotEnabled)
        XCTAssertTrue(gated.isGated)
        let actions = gated.readiness.actions.count
        XCTAssertGreaterThan(actions, 1)
        let requirement = chosen(in: RequirementPanel(model: gated), count: actions) { gated.requirementSelection }
        XCTAssertEqual(Set(requirement), Set(0..<actions), "Each way to make this Mac ready")
    }

    /// Lets what was set aside for the main queue run.
    private func settle() {
        RunLoop.main.run(until: Date().addingTimeInterval(0.05))
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
