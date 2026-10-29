import Foundation
import LauncherCore
import XCTest

final class LauncherSettingsTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() {
        super.setUp()
        suiteName = "LauncherSettingsTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        defaults.removePersistentDomain(forName: suiteName)
        defaults = nil
        super.tearDown()
    }

    /// Each resolution draws the lake at its share of the display's pixels,
    /// finest first, and each row of the panel is named as it is shown.
    func testResolutionsAndRowsAreNamedAndScaled() {
        XCTAssertEqual(RenderQuality.allCases.map(\.scale), [1, 0.75, 0.5])
        XCTAssertEqual(RenderQuality.allCases.map(\.title), ["Native", "Balanced", "Efficient"])
        XCTAssertEqual(SettingsRow.allCases.map(\.title), ["Motion", "Resolution", "Frame rate", "Full screen at launch"])
    }

    func testEmptyDefaultsProduceDefaultSettings() {
        XCTAssertEqual(LauncherSettings(defaults: defaults), LauncherSettings())
        XCTAssertEqual(LauncherSettings().motion, .system)
        XCTAssertEqual(LauncherSettings().frameRate, .sixty)
        XCTAssertFalse(LauncherSettings().startsInFullScreen)
    }

    func testSettingsRoundTrip() {
        let settings = LauncherSettings(motion: .still, quality: .efficient, frameRate: .oneTwenty, startsInFullScreen: true)
        settings.save(to: defaults)
        XCTAssertEqual(LauncherSettings(defaults: defaults), settings)
    }

    func testUnrecognisedStoredValuesFallBackToDefaults() {
        defaults.set("cinematic", forKey: "launcher.motion")
        defaults.set("ultra", forKey: "launcher.renderQuality")
        defaults.set(144, forKey: "launcher.frameRate")
        XCTAssertEqual(LauncherSettings(defaults: defaults), LauncherSettings())
    }

    func testSystemMotionFollowsAccessibilitySetting() {
        XCTAssertEqual(MotionPreference.system.resolved(systemReducesMotion: false), .full)
        XCTAssertEqual(MotionPreference.system.resolved(systemReducesMotion: true), .reduced)
        XCTAssertEqual(MotionPreference.full.resolved(systemReducesMotion: true), .full)
        XCTAssertEqual(MotionPreference.still.resolved(systemReducesMotion: false), .still)
        XCTAssertEqual(ResolvedMotion.still.clockRate, 0)
        XCTAssertEqual(ResolvedMotion.still.activity, 0)
        XCTAssertEqual(ResolvedMotion.full.activity, 1)
        XCTAssertLessThan(ResolvedMotion.reduced.activity, 0.5, "Stars fall only above 0.5")
    }

    func testTheFrameRateCapAppliesOnlyAtFullMotionWhileNotSavingEnergy() {
        XCTAssertEqual(FrameRateCap.oneTwenty.framesPerSecond(motion: .full, isSavingEnergy: false), 120)
        XCTAssertEqual(FrameRateCap.sixty.framesPerSecond(motion: .full, isSavingEnergy: false), 60)
        XCTAssertEqual(FrameRateCap.oneTwenty.framesPerSecond(motion: .full, isSavingEnergy: true), 30)
        XCTAssertEqual(FrameRateCap.sixty.framesPerSecond(motion: .reduced, isSavingEnergy: false), 30)
        XCTAssertEqual(FrameRateCap.thirty.framesPerSecond(motion: .full, isSavingEnergy: false), 30)
    }

    func testEveryRowHasItsCurrentValueSelected() {
        let settings = LauncherSettings(motion: .reduced, quality: .balanced, frameRate: .thirty, startsInFullScreen: true)
        XCTAssertEqual(settings.options(for: .motion)[settings.selectedIndex(for: .motion)], "Reduced")
        XCTAssertEqual(settings.options(for: .quality)[settings.selectedIndex(for: .quality)], "Balanced")
        XCTAssertEqual(settings.options(for: .frameRate)[settings.selectedIndex(for: .frameRate)], "30")
        XCTAssertEqual(settings.options(for: .startsInFullScreen)[settings.selectedIndex(for: .startsInFullScreen)], "On")
    }

    func testSteppingStopsAtTheEndsUnlessWrapping() {
        var settings = LauncherSettings(quality: .native)
        settings.step(.quality, by: -1)
        XCTAssertEqual(settings.quality, .native)
        settings.step(.quality, by: 5)
        XCTAssertEqual(settings.quality, .efficient)
        settings.step(.quality, by: 1, wrapping: true)
        XCTAssertEqual(settings.quality, .native)
        settings.step(.startsInFullScreen, by: 1, wrapping: true)
        XCTAssertTrue(settings.startsInFullScreen)
    }

    func testSelectingAnOutOfRangeOptionIsIgnored() {
        var settings = LauncherSettings()
        settings.select(9, for: .frameRate)
        settings.select(-1, for: .motion)
        XCTAssertEqual(settings, LauncherSettings())
    }
}
