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
        XCTAssertEqual(SettingsRow.allCases.map(\.title), ["Motion", "Resolution", "Frame rate", "Text", "Music", "Full screen at launch"])
    }

    func testEmptyDefaultsProduceDefaultSettings() {
        XCTAssertEqual(LauncherSettings(defaults: defaults), LauncherSettings())
        XCTAssertEqual(LauncherSettings().motion, .system)
        XCTAssertEqual(LauncherSettings().frameRate, .sixty)
        XCTAssertFalse(LauncherSettings().startsInFullScreen)
        XCTAssertFalse(LauncherSettings().largerText)
        XCTAssertTrue(LauncherSettings().music, "The score plays until it is turned off")
    }

    func testSettingsRoundTrip() {
        let settings = LauncherSettings(motion: .still, quality: .efficient, frameRate: .oneTwenty, largerText: true, music: false,
                                        startsInFullScreen: true)
        settings.save(to: defaults)
        XCTAssertEqual(LauncherSettings(defaults: defaults), settings)
    }

    /// The launcher's Music is the realm's: kept where the realm always
    /// kept it, so one choice serves both.
    func testMusicIsReadWhereTheRealmKeepsIt() {
        defaults.set(false, forKey: "music.enabled")
        XCTAssertFalse(LauncherSettings(defaults: defaults).music)
        var settings = LauncherSettings(defaults: defaults)
        XCTAssertEqual(settings.options(for: .music), ["Off", "On"])
        XCTAssertEqual(settings.selectedIndex(for: .music), 0)
        settings.select(1, for: .music)
        settings.save(to: defaults)
        XCTAssertEqual(defaults.object(forKey: "music.enabled") as? Bool, true)
    }

    /// Larger Text keeps its choice where it always has, so a choice made
    /// before it was a setting of the launcher's carries over.
    func testLargerTextIsReadWhereItWasAlwaysKept() {
        defaults.set(true, forKey: "text.larger")
        XCTAssertTrue(LauncherSettings(defaults: defaults).largerText)
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
        let settings = LauncherSettings(motion: .reduced, quality: .balanced, frameRate: .thirty, largerText: true, startsInFullScreen: true)
        XCTAssertEqual(settings.options(for: .motion)[settings.selectedIndex(for: .motion)], "Reduced")
        XCTAssertEqual(settings.options(for: .text)[settings.selectedIndex(for: .text)], "Larger")
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
        settings.step(.text, by: 1)
        XCTAssertTrue(settings.largerText)
        settings.step(.text, by: 1, wrapping: true)
        XCTAssertFalse(settings.largerText)
    }

    func testSelectingAnOutOfRangeOptionIsIgnored() {
        var settings = LauncherSettings()
        settings.select(9, for: .frameRate)
        settings.select(-1, for: .motion)
        XCTAssertEqual(settings, LauncherSettings())
    }
}
