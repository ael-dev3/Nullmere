import LauncherCore
import XCTest

final class NavigationTests: XCTestCase {
    func testMenuMovesAndWraps() {
        XCTAssertEqual(MenuItem.allCases, [.play, .news, .settings, .repository, .quit])
        XCTAssertEqual(MenuItem.play.moved(by: 1), .news)
        XCTAssertEqual(MenuItem.quit.moved(by: 1), .play)
        XCTAssertEqual(MenuItem.play.moved(by: -1), .quit)
        XCTAssertEqual(MenuItem.play.moved(by: -1, wrapping: false), .play)
        XCTAssertEqual(MenuItem.settings.moved(by: 7, wrapping: false), .quit)
        XCTAssertEqual(MenuItem.repository.title, "Repository")
    }

    func testKeyCodesMapToCommands() {
        XCTAssertEqual(KeyCommand(keyCode: 126), .up)
        XCTAssertEqual(KeyCommand(keyCode: 125), .down)
        XCTAssertEqual(KeyCommand(keyCode: 123), .left)
        XCTAssertEqual(KeyCommand(keyCode: 124), .right)
        XCTAssertEqual(KeyCommand(keyCode: 36), .confirm)
        XCTAssertEqual(KeyCommand(keyCode: 76), .confirm)
        XCTAssertEqual(KeyCommand(keyCode: 49), .confirm)
        XCTAssertEqual(KeyCommand(keyCode: 53), .back)
        XCTAssertNil(KeyCommand(keyCode: 0)) // "A"
    }

    func testKeyboardNavigationKeepsSpaceForTheFocusedControl() {
        XCTAssertNil(KeyCommand(keyCode: 49, keyboardNavigation: true))
        XCTAssertEqual(KeyCommand(keyCode: 36, keyboardNavigation: true), .confirm)
        XCTAssertEqual(KeyCommand(keyCode: 124, keyboardNavigation: true), .right)
    }

    func testOnlyArrowsRepeatWhenHeld() {
        XCTAssertTrue(KeyCommand.up.repeatsWhenHeld)
        XCTAssertTrue(KeyCommand.right.repeatsWhenHeld)
        XCTAssertFalse(KeyCommand.confirm.repeatsWhenHeld, "A held Return mustn't flip a panel open and shut")
        XCTAssertFalse(KeyCommand.back.repeatsWhenHeld)
    }
}

final class SceneTests: XCTestCase {
    func testClockAdvancesAtTheMotionRate() {
        var clock = SceneClock()
        XCTAssertEqual(clock.advance(to: 10, rate: 1), 0)
        XCTAssertEqual(clock.advance(to: 10.05, rate: 1), 0.05, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 10.10, rate: 0.5), 0.075, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 10.15, rate: 0), 0.075, accuracy: 1e-9)
    }

    func testClockSkipsLongGapsAndBackwardsTime() {
        var clock = SceneClock()
        clock.advance(to: 1, rate: 1)
        XCTAssertEqual(clock.advance(to: 600, rate: 1), SceneClock.maximumStep, accuracy: 1e-9)
        XCTAssertEqual(clock.advance(to: 500, rate: 1), SceneClock.maximumStep, accuracy: 1e-9)
        clock.resetInterval()
        XCTAssertEqual(clock.advance(to: 900, rate: 1), SceneClock.maximumStep, accuracy: 1e-9)
    }

    func testClockStartsOverAfterAPeriod() {
        var clock = SceneClock(time: SceneClock.period - 0.03)
        clock.advance(to: 0, rate: 1)
        XCTAssertEqual(clock.advance(to: 0.05, rate: 1), 0.02, accuracy: 1e-6)
        // A 32-bit float still resolves a millisecond just before the wrap.
        let latest = Float(SceneClock.period)
        XCTAssertLessThan(latest.nextUp - latest, 0.001)
    }

    func testStarCatalogIsDeterministicAndInRange() {
        let stars = StarCatalog.stars(count: 300, seed: 42)
        XCTAssertEqual(stars, StarCatalog.stars(count: 300, seed: 42))
        XCTAssertNotEqual(stars, StarCatalog.stars(count: 300, seed: 43))
        for star in stars {
            XCTAssert((0..<1).contains(star.x))
            XCTAssert((0...1).contains(star.altitude))
            XCTAssert((0...1).contains(star.brightness))
            XCTAssertGreaterThan(star.radius, 0)
        }
    }

    func testLayoutUnitFollowsTheTighterDimensionWithinBounds() {
        XCTAssertEqual(LakeComposition.unit(width: 1200, height: 800), 1)
        XCTAssertEqual(LakeComposition.unit(width: 1920, height: 800), 1, "Wide windows scale with height")
        XCTAssertEqual(LakeComposition.unit(width: 960, height: 1200), 0.8, "Tall windows scale with width")
        XCTAssertEqual(LakeComposition.unit(width: 600, height: 400), 0.72)
        XCTAssertEqual(LakeComposition.unit(width: 6000, height: 4000), 1.7)
        XCTAssertEqual(LakeComposition.waterline(forHeight: 1000), 530, accuracy: 1e-9)
    }

    func testMoonSitsHighAboveTheWaterAndItsReflectionStaysOnScreen() {
        let mirroredMoon = 2 * LakeComposition.horizon - LakeComposition.moonY
        XCTAssertGreaterThan(LakeComposition.moonY - LakeComposition.moonRadius, LakeComposition.horizon + 0.2)
        XCTAssertGreaterThan(mirroredMoon - LakeComposition.moonRadius, 0, "The full reflection fits above the bottom edge")
        XCTAssertEqual(LakeComposition.moonX, 0.5, "The full moon is centred")
    }
}
