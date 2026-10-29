import LauncherCore
import SwiftUI
import XCTest
@testable import LauncherKit

/// The launcher's buttons pressed as a keeper presses them: each screen
/// drawn while the test listens, and each button pressed by its title,
/// running its own action.
@MainActor
final class LauncherPressTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var opened: [URL] = []
    private var terminated = false
    private var crossings = 0

    override func setUp() async throws {
        suiteName = "LauncherPressTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        opened = []
        terminated = false
        crossings = 0
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        defaults.removePersistentDomain(forName: suiteName)
    }

    private func model(_ readiness: ModelReadiness = .ready) -> LauncherModel {
        let environment = LauncherEnvironment(
            modelReadiness: { readiness },
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { [weak self] url in self?.opened.append(url); return true },
            terminate: { [weak self] in self?.terminated = true }
        )
        let model = LauncherModel(defaults: defaults, environment: environment)
        model.enterRealm = { [weak self] in self?.crossings += 1 }
        model.refreshReadiness()
        model.completeIntro()
        return model
    }

    /// Draws the launcher as it stands, so its buttons are those it shows now.
    private func draw(_ model: LauncherModel) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: LauncherRootView(model: model).frame(width: 1280, height: 800).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    func testTheMenuAndItsPanelsArePressed() async throws {
        let model = model()
        draw(model)
        XCTAssertTrue(PressableButtons.press("News"), "Among \(shown)")
        XCTAssertEqual(model.screen, .news)
        draw(model)
        let headline = try XCTUnwrap(model.visibleNews.last)
        XCTAssertTrue(PressableButtons.press(headline.title), "Among \(shown)")
        XCTAssertEqual(model.newsSelection, model.visibleNews.count - 1)
        if headline.link != nil {
            draw(model)
            XCTAssertTrue(PressableButtons.press("Read more"), "Among \(shown)")
            XCTAssertEqual(opened.last, headline.link)
        }
        XCTAssertTrue(PressableButtons.press("Back"))
        XCTAssertEqual(model.screen, .title)

        draw(model)
        XCTAssertTrue(PressableButtons.press("Settings"))
        XCTAssertEqual(model.screen, .settings)
        draw(model)
        XCTAssertTrue(PressableButtons.press("Full"), "Among \(shown)")
        XCTAssertEqual(model.settings.motion, .full)
        XCTAssertTrue(PressableButtons.press("On"))
        XCTAssertTrue(model.settings.startsInFullScreen)
        XCTAssertTrue(PressableButtons.press("Back"))
        XCTAssertEqual(model.screen, .title)

        draw(model)
        let before = opened.count
        XCTAssertTrue(PressableButtons.press("Repository"))
        XCTAssertTrue(PressableButtons.press("nullmere.online"), "Among \(shown)")
        XCTAssertEqual(opened.count, before + 2, "The repository, then the website")
        XCTAssertTrue(PressableButtons.press("Play"))
        XCTAssertTrue(model.isLeaving, "The launcher fades")
        let deadline = Date().addingTimeInterval(3)
        while crossings == 0, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(crossings, 1, "and Play crosses into the realm")
    }

    func testQuitIsPressed() async throws {
        let model = model()
        draw(model)
        XCTAssertTrue(PressableButtons.press("Quit"), "Among \(shown)")
        let deadline = Date().addingTimeInterval(3)
        while !terminated, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertTrue(terminated, "The launcher quits once it has faded")
    }

    /// Play, pressed, crosses to the realm's front door: the launcher fades,
    /// and the way in is taken once.
    func testPlayIsPressed() async throws {
        let model = model()
        draw(model)
        XCTAssertTrue(PressableButtons.press("Play"), "Among \(shown)")
        XCTAssertTrue(model.isLeaving, "The launcher fades out")
        let deadline = Date().addingTimeInterval(3)
        while crossings == 0, Date() < deadline { try await Task.sleep(nanoseconds: 50_000_000) }
        XCTAssertEqual(crossings, 1)
    }

    /// On a Mac whose model is off, the requirement screen's way to turn it
    /// on opens System Settings where it is.
    func testTheRequirementScreenIsPressed() throws {
        let model = model(.appleIntelligenceNotEnabled)
        XCTAssertTrue(model.isGated)
        draw(model)
        XCTAssertTrue(PressableButtons.press("Open System Settings"), "Among \(shown)")
        XCTAssertEqual(opened.count, 1)
        XCTAssertEqual(model.requirementSelection, 0)
    }

    func testNothingIsKeptWhileNoTestListens() {
        PressableButtons.isListening = false
        let renderer = ImageRenderer(content: LauncherRootView(model: model()).frame(width: 1280, height: 800))
        _ = renderer.cgImage
        XCTAssertTrue(PressableButtons.actions.isEmpty)
        XCTAssertFalse(PressableButtons.press("Play"))
    }
}
