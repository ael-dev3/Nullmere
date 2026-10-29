import LauncherCore
import SwiftUI
import XCTest
@testable import LauncherKit

/// Every item of the launcher's menus: what it opens, and that Settings…
/// and the news wait while the window shows only the requirement screen.
@MainActor
final class LauncherMenuTests: XCTestCase {
    func testEveryMenuItemDoesWhatItSays() throws {
        let suite = "launcher-menu-\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        var opened: [URL] = []
        let environment = LauncherEnvironment(
            modelReadiness: { .ready },
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { opened.append($0); return true },
            terminate: {}
        )
        let model = LauncherModel(defaults: defaults, environment: environment)
        _ = LauncherCommands(model: model).body
        _ = LauncherCommands(model: model, settings: {}).body
        model.refreshReadiness()
        model.completeIntro()
        XCTAssertFalse(model.isGated, "A ready model opens the launcher")

        XCTAssertEqual(Set(LauncherMenu.allCases.map(\.title)).count, LauncherMenu.allCases.count)
        XCTAssertEqual(LauncherMenu.settings.shortcut, KeyboardShortcut(",", modifiers: .command))
        for item in LauncherMenu.allCases {
            XCTAssertEqual(item.isEnabled(gated: true), item == .website || item == .repository, item.title)
            XCTAssertTrue(item.isEnabled(gated: false), item.title)
            XCTAssertEqual(item.isEnabled(gated: nil), item == .website || item == .repository, "No window, no settings")
            // Settings… routed to whatever has the window: the realm's own,
            // once the launcher has made way for it.
            XCTAssertEqual(item.isEnabled(gated: nil, routed: true), item != .news, item.title)
            XCTAssertEqual(item.isEnabled(gated: true, routed: true), item == .website || item == .repository, item.title)
            XCTAssertTrue(item.isEnabled(gated: false, routed: true), item.title)
        }

        LauncherMenu.settings.perform(model: model, settings: nil)
        XCTAssertEqual(model.screen, .settings, "Settings… opens the launcher's own panel")
        var asked = false
        LauncherMenu.settings.perform(model: model, settings: { asked = true })
        XCTAssertTrue(asked, "or whatever has the window decides")
        LauncherMenu.news.perform(model: model, settings: nil)
        XCTAssertEqual(model.screen, .news)
        LauncherMenu.website.perform(model: model, settings: nil)
        LauncherMenu.repository.perform(model: model, settings: nil)
        XCTAssertEqual(opened.count, 2, "The website and the repository open outside the window")
        XCTAssertEqual(Set(opened).count, 2)
    }
}
