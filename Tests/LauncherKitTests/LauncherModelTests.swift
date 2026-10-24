import LauncherCore
import XCTest
@testable import LauncherKit

@MainActor
final class LauncherModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "LauncherModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    func testFirstKeySkipsTheIntro() {
        let model = LauncherModel(defaults: defaults)
        model.handle(.down)
        XCTAssertEqual(model.intro, .complete)
        XCTAssertEqual(model.menuSelection, .play, "The skipping key press should not also navigate")
    }

    func testMenuNavigationOpensPanelsAndReturns() {
        let model = LauncherModel(defaults: defaults)
        model.completeIntro()

        model.handle(.down)
        XCTAssertEqual(model.menuSelection, .settings)
        model.handle(.confirm)
        XCTAssertEqual(model.screen, .settings)
        model.handle(.back)
        XCTAssertEqual(model.screen, .title)

        model.handle(.up)
        XCTAssertEqual(model.menuSelection, .play)
        model.handle(.confirm)
        XCTAssertEqual(model.screen, .play)
        model.handle(.confirm)
        XCTAssertEqual(model.screen, .title)
    }

    func testSettingsChangesArePersisted() {
        let model = LauncherModel(defaults: defaults)
        model.show(.settings)

        model.handle(.right) // Motion: System → Full
        model.handle(.down)
        model.handle(.down)
        model.handle(.left) // Frame rate: 60 → 30
        model.choose(1, for: .startsInFullScreen)

        let stored = LauncherSettings(defaults: defaults)
        XCTAssertEqual(stored.motion, .full)
        XCTAssertEqual(stored.frameRate, .thirty)
        XCTAssertTrue(stored.startsInFullScreen)
        XCTAssertEqual(LauncherModel(defaults: defaults).settings, stored)
    }

    func testBackdropFollowsSettings() {
        LauncherSettings(motion: .still, quality: .efficient, frameRate: .thirty).save(to: defaults)
        let configuration = LauncherModel(defaults: defaults).backdropConfiguration(systemReducesMotion: false)
        XCTAssertEqual(configuration.motion, .still)
        XCTAssertEqual(configuration.renderScale, 0.5)
        XCTAssertEqual(configuration.framesPerSecond, 30)
        XCTAssertEqual(configuration.horizon, LakeComposition.horizon)
    }
}
