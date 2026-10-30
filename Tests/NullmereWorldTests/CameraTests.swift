import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

final class CameraTests: XCTestCase {
    let size = CGSize(width: 1000, height: 700)

    func testTheMiddleOfTheViewIsTheFocus() {
        var camera = Camera(centerX: 3, centerY: -4, scale: 30)
        let middle = camera.viewPoint(worldX: 3, worldY: -4, in: size)
        XCTAssertEqual(middle.x, 500, accuracy: 0.01)
        XCTAssertEqual(middle.y, 350, accuracy: 0.01)
        let back = camera.world(at: CGPoint(x: 500, y: 350), in: size)
        XCTAssertEqual(back.x, 3, accuracy: 1e-3)
        XCTAssertEqual(back.y, -4, accuracy: 1e-3)
        camera.focus(on: Hex(2, 1))
        XCTAssertEqual(camera.centreHex, Hex(2, 1))
    }

    func testScaleIsPointsPerUnitAtTheMiddle() {
        let camera = Camera(scale: 40, tilt: 0.5)
        let a = camera.viewPoint(worldX: -0.01, worldY: 0, in: size), b = camera.viewPoint(worldX: 0.01, worldY: 0, in: size)
        XCTAssertEqual(Double(b.x - a.x) / 0.02, 40, accuracy: 0.2, "across the view, a unit spans the scale")
    }

    func testNorthIsUpAndTheNearIsLarger() {
        let camera = Camera(scale: 30)
        let north = camera.viewPoint(worldX: 0, worldY: -3, in: size), south = camera.viewPoint(worldX: 0, worldY: 3, in: size)
        XCTAssertLessThan(north.y, south.y, "north lies up the view")
        let farSpan = camera.viewPoint(worldX: 1, worldY: -3, in: size).x - north.x
        let nearSpan = camera.viewPoint(worldX: 1, worldY: 3, in: size).x - south.x
        XCTAssertGreaterThan(nearSpan, farSpan, "nearer the eye, nearer the foot of the view, larger")
        let east = camera.viewPoint(worldX: 3, worldY: 0, in: size)
        XCTAssertGreaterThan(east.x, 500, "east lies right")
        let high = camera.viewPoint(worldX: 0, worldY: 0, height: 1, in: size)
        XCTAssertLessThan(high.y, 350, "what stands taller shows higher")
    }

    func testPointsAndHexesRoundTrip() {
        for camera in [Camera(scale: 30), Camera(centerX: 5, centerY: 2, scale: 60, tilt: 0.9, heading: 1.2),
                       Camera(scale: 12, tilt: 0.3, heading: -2)] {
            for hex in [Hex(0, 0), Hex(3, -2), Hex(-4, 5), Hex(6, 1)] {
                let point = camera.viewPoint(of: hex, in: size)
                XCTAssertEqual(camera.hex(at: point, in: size), hex, "\(camera) \(hex)")
            }
        }
    }

    func testTheReliefPicksTheHexTheLandShows() {
        let state = GameState(settings: GameSettings(seedText: "camera", houseCount: 6, radius: 14))
        let relief = Relief(map: state.map)
        let camera = Camera(scale: 40, tilt: 0.95)
        for hex in [Hex(1, 1), Hex(-3, 2), Hex(4, -4)] {
            let point = camera.viewPoint(of: hex, height: Double(relief.height(of: hex)), in: size)
            XCTAssertEqual(camera.hex(at: point, in: size, relief: relief), hex)
        }
        let sky = camera.hex(at: CGPoint(x: 500, y: -5000), in: size, relief: relief)
        XCTAssertGreaterThan(sky.distance(to: Hex(0, 0)), 14, "above the horizon, far off")
    }

    func testPanningFollowsThePointer() {
        var camera = Camera(scale: 30, tilt: 0.7, heading: 0.4)
        let grabbed = camera.world(at: CGPoint(x: 500, y: 350), in: size)
        camera.pan(dx: 60, dy: -25, in: size)
        let now = camera.world(at: CGPoint(x: 560, y: 325), in: size)
        XCTAssertEqual(now.x, grabbed.x, accuracy: 1e-3)
        XCTAssertEqual(now.y, grabbed.y, accuracy: 1e-3)
        var flung = Camera(scale: 10, tilt: 1.0)
        flung.pan(dx: 0, dy: 5000, in: size)
        XCTAssertLessThanOrEqual(abs(flung.centerY), 1000 / 10 + 1e-6, "no drag flings the view past its width")
    }

    func testZoomKeepsThePointUnderTheAnchor() {
        var camera = Camera(scale: 30, tilt: 0.8, heading: 0.3)
        let anchor = CGPoint(x: 700, y: 200)
        let before = camera.world(at: anchor, in: size)
        camera.zoom(by: 1.7, around: anchor, in: size)
        let after = camera.world(at: anchor, in: size)
        XCTAssertEqual(camera.scale, 51, accuracy: 1e-9)
        XCTAssertEqual(after.x, before.x, accuracy: 1e-3)
        XCTAssertEqual(after.y, before.y, accuracy: 1e-3)
        camera.zoom(by: 100, around: anchor, in: size)
        XCTAssertEqual(camera.scale, Camera.maximumScale)
        camera.zoom(by: 0.0001, around: anchor, in: size)
        XCTAssertEqual(camera.scale, Camera.minimumScale)
    }

    func testTurningAndLeaning() {
        var camera = Camera()
        camera.turn(by: .pi / 2)
        let east = camera.viewPoint(worldX: 3, worldY: 0, in: size)
        XCTAssertGreaterThan(east.y, 350, "turned a quarter, the eye stands east looking west: the east lies toward the foot of the view")
        camera.turn(by: 4 * .pi)
        XCTAssertLessThan(abs(camera.heading), 2 * .pi)
        camera.lean(by: 10)
        XCTAssertEqual(camera.tilt, Camera.maximumTilt)
        camera.lean(by: -10)
        XCTAssertEqual(camera.tilt, Camera.minimumTilt)
    }

    func testTheViewStaysOverTheWorld() {
        var camera = Camera(centerX: 500, centerY: -500)
        camera.clamp(toRadius: 10)
        XCTAssertEqual(camera.centerX, 3.0.squareRoot() * 10, accuracy: 1e-9)
        XCTAssertEqual(camera.centerY, -15)
    }

    func testBehindTheEyeIsFarOff() {
        let camera = Camera(scale: 90, tilt: 1.0)
        let behind = camera.viewPoint(worldX: 0, worldY: 400, height: 300, in: size)
        XCTAssertLessThan(behind.x, -1000)
    }

    func testTheMatricesAgreeWithTheProjection() {
        let camera = Camera(centerX: 2, centerY: 3, scale: 25, tilt: 0.6, heading: 0.8)
        let clip = camera.viewProjection(in: size).apply(Vec4(2, 0, 3, 1))
        XCTAssertEqual(clip.x / clip.w, 0, accuracy: 1e-4)
        XCTAssertEqual(clip.y / clip.w, 0, accuracy: 1e-4)
        XCTAssertGreaterThan(clip.z / clip.w, 0)
        XCTAssertLessThan(clip.z / clip.w, 1)
        let eye = camera.eye(in: size)
        XCTAssertEqual(Double((eye - camera.focus).length), camera.distance(in: size), accuracy: 1e-3)
        XCTAssertGreaterThan(eye.y, 0)
    }
}

final class CameraPrecisionTests: XCTestCase {
    /// A drag across the middle of the view moves it by exactly the drag
    /// over the scale, as the map has always moved.
    func testADragAcrossMovesTheViewByItsLength() {
        var camera = Camera(centerX: 31.7, centerY: -12.2, scale: 28)
        let before = camera
        camera.pan(dx: 28, dy: 0)
        XCTAssertEqual(camera.centerX, before.centerX - 28 / before.scale, accuracy: 1e-9)
        XCTAssertEqual(camera.centerY, before.centerY, accuracy: 1e-9)
        var keys = Camera(scale: 30)
        keys.zoom(by: 1.25)
        XCTAssertEqual(keys.scale, 37.5)
        keys.zoom(by: 100)
        XCTAssertEqual(keys.scale, Camera.maximumScale)
    }

    func testTheMatrixAndThePointsAgree() {
        let size = CGSize(width: 1000, height: 700)
        let camera = Camera(centerX: 2, centerY: 3, scale: 25, tilt: 0.6, heading: 0.8)
        let matrix = camera.viewProjection(in: size)
        for (x, y, h) in [(2.0, 3.0, 0.0), (5.0, -1.0, 0.4), (-3.0, 6.0, 1.2)] {
            let clip = matrix.apply(Vec4(Float(x), Float(h), Float(y), 1))
            let point = camera.viewPoint(worldX: x, worldY: y, height: h, in: size)
            XCTAssertEqual(Double((clip.x / clip.w + 1) / 2) * 1000, Double(point.x), accuracy: 0.05)
            XCTAssertEqual(Double((1 - clip.y / clip.w) / 2) * 700, Double(point.y), accuracy: 0.05)
        }
    }
}
