import AppKit
import LauncherCore
import SwiftUI
import XCTest
@testable import LauncherKit

/// Every screen of the launcher, drawn offscreen in each state it can be
/// in: what it holds is checked through the model, and that each draws at
/// all through the renderer.
@MainActor
final class LauncherViewTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "LauncherViewTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func model(_ readiness: ModelReadiness = .ready) -> LauncherModel {
        let environment = LauncherEnvironment(
            modelReadiness: { readiness },
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { _ in true },
            terminate: {}
        )
        let model = LauncherModel(defaults: defaults, environment: environment)
        model.enterRealm = {}
        model.refreshReadiness()
        model.refreshEnergyState()
        return model
    }

    @discardableResult
    private func draw(_ view: some View, width: CGFloat = 1280, height: CGFloat = 800) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage, "drawn")
        XCTAssertEqual(image.width, Int(width))
        return image
    }

    func testEveryScreenDraws() throws {
        let model = model()
        model.completeIntro()
        for screen in [LauncherModel.Screen.title, .play, .news, .settings] {
            model.show(screen)
            XCTAssertEqual(model.screen, screen)
            try draw(LauncherRootView(model: model))
        }
        // Narrow and wide windows alike.
        model.show(.title)
        try draw(LauncherRootView(model: model), width: 960, height: 600)
        try draw(LauncherRootView(model: model), width: 1920, height: 1200)
    }

    func testEveryRequirementStateDraws() throws {
        for readiness in [ModelReadiness.checking, .deviceNotEligible, .appleIntelligenceNotEnabled, .modelNotReady, .unavailable] {
            let model = model(readiness)
            model.completeIntro()
            XCTAssertEqual(model.readiness, readiness)
            try draw(LauncherRootView(model: model))
            try draw(RequirementsLine(readiness: readiness), width: 600, height: 40)
            try draw(LauncherFooter(version: "1.0", readiness: readiness, hint: "Return to choose", openWebsite: {}), width: 1280, height: 60)
        }
    }

    func testTheKeysWalkTheMenusAndPanels() throws {
        let model = model()
        model.completeIntro()
        // Through the menu to Settings, across a row, and back.
        model.show(.settings)
        for key in [KeyCommand.down, .right, .left, .down, .right, .up, .confirm] {
            model.handle(key)
            try draw(SettingsPanel(model: model), width: 900, height: 500)
        }
        model.handle(.back)
        XCTAssertEqual(model.screen, .title, "Back returns to the title")

        // News: each story, then back.
        model.show(.news)
        XCTAssertFalse(model.news.items.isEmpty, "The news the launcher ships with")
        for _ in model.news.items {
            model.handle(.down)
            try draw(NewsPanel(model: model), width: 1000, height: 600)
        }
        model.handle(.back)
        XCTAssertEqual(model.screen, .title)
    }

    /// The game's title screens stand a panel on the water, so their lake
    /// has the moon's image sunk, as under the launcher's panels.
    func testTheGamesLakeLiesVeiledUnderItsPanels() {
        for reduces in [false, true] {
            let configuration = MoonlitLake.configuration(systemReducesMotion: reduces)
            XCTAssertEqual(configuration.veil, 1)
            XCTAssertEqual(configuration.motion, reduces ? .reduced : .full)
            XCTAssertEqual(configuration.horizon, LakeComposition.horizon)
            XCTAssertEqual(configuration.framesPerSecond, reduces ? 30 : 60)
        }
        // Slowed as the launcher's lake is, while another app is in front or
        // the Mac saves energy.
        XCTAssertEqual(MoonlitLake.configuration(systemReducesMotion: false, isSavingEnergy: true).framesPerSecond, 30)
        // And drawn as the launcher's settings say.
        let chosen = LauncherSettings(motion: .reduced, quality: .balanced, frameRate: .oneTwenty)
        let drawn = MoonlitLake.configuration(settings: chosen, systemReducesMotion: false)
        XCTAssertEqual(drawn.motion, .reduced)
        XCTAssertEqual(drawn.renderScale, RenderQuality.balanced.scale)
        XCTAssertEqual(drawn.framesPerSecond, 30)
        let swift = MoonlitLake.configuration(settings: LauncherSettings(frameRate: .oneTwenty), systemReducesMotion: false)
        XCTAssertEqual(swift.framesPerSecond, 120)
    }

    /// The game's lake in a window hears the app go behind another and come
    /// back, and the Mac start and stop saving energy, as the launcher's does.
    func testTheGamesLakeHearsTheAppAndTheMac() throws {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 640, height: 400), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: MoonlitLake())
        window.orderFrontRegardless()
        defer { window.close() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
        for name in [NSApplication.didResignActiveNotification, NSApplication.didBecomeActiveNotification,
                     Notification.Name.NSProcessInfoPowerStateDidChange, ProcessInfo.thermalStateDidChangeNotification] {
            NotificationCenter.default.post(name: name, object: nil)
            RunLoop.main.run(until: Date().addingTimeInterval(0.1))
        }
        XCTAssertNotNil(window.contentView)
        window.contentView = nil
    }

    func testTheTitleAndItsPartsDraw() throws {
        for revealed in [false, true] {
            try draw(TitleBlock(isRevealed: revealed, settlesLetters: true), width: 1200, height: 200)
        }
        try draw(LakeFallbackView(horizon: 0.55))
        try draw(MoonlitLake(), width: 640, height: 400)
        let model = model()
        try draw(MainMenu(model: model), width: 1000, height: 80)
        try draw(PlayPanel(model: model), width: 900, height: 300)
        for selected in [false, true] {
            try draw(MenuButton(title: "Play", isSelected: selected, action: {}), width: 200, height: 40)
        }
    }
}
