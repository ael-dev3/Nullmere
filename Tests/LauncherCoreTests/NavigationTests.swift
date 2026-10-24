import LauncherCore
import XCTest

final class NavigationTests: XCTestCase {
    func testMenuMovesAndWraps() {
        XCTAssertEqual(MenuItem.play.moved(by: 1), .settings)
        XCTAssertEqual(MenuItem.quit.moved(by: 1), .play)
        XCTAssertEqual(MenuItem.play.moved(by: -1), .quit)
        XCTAssertEqual(MenuItem.play.moved(by: -1, wrapping: false), .play)
        XCTAssertEqual(MenuItem.settings.moved(by: 7, wrapping: false), .quit)
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

    func testLayoutUnitScalesWithHeightWithinBounds() {
        XCTAssertEqual(LakeComposition.unit(forHeight: 800), 1)
        XCTAssertEqual(LakeComposition.unit(forHeight: 400), 0.72)
        XCTAssertEqual(LakeComposition.unit(forHeight: 4000), 1.7)
        XCTAssertEqual(LakeComposition.waterline(forHeight: 1000), 550, accuracy: 1e-9)
    }
}
