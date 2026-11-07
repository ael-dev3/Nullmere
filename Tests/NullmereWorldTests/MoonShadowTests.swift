import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The moon's shadow map over what the view sees close by.
final class MoonShadowTests: XCTestCase {
    private let size = CGSize(width: 1512, height: 982)

    private func camera(scale: Double, heading: Double = 0, x: Double = 3, y: Double = -2) -> Camera {
        Camera(centerX: x, centerY: y, scale: scale, tilt: Camera.leaning(at: scale), heading: heading)
    }

    /// Where a point of the world falls in the map: its texture coordinates
    /// (0 to 1, rows down as Metal reads them) and its depth.
    private func mapped(_ point: Vec3, by matrix: Mat4) -> (uv: SIMD2<Float>, depth: Float) {
        let clip = matrix.apply(Vec4(point.x, point.y, point.z, 1))
        return (SIMD2(clip.x * 0.5 + 0.5, 0.5 - clip.y * 0.5), clip.z / clip.w)
    }

    /// Far out the moon casts none, what stands on the land being too small
    /// for its shadows; close in it does.
    func testTheMoonCastsShadowsOnlyCloseIn() {
        XCTAssertNil(MoonShadow.matrix(camera: camera(scale: 28), size: size))
        XCTAssertNil(MoonShadow.matrix(camera: camera(scale: MoonShadow.nearest - 1), size: size))
        XCTAssertNotNil(MoonShadow.matrix(camera: camera(scale: MoonShadow.nearest), size: size))
        XCTAssertNotNil(MoonShadow.matrix(camera: camera(scale: Camera.maximumScale), size: size))
    }

    /// The ground in view lies in the map, and what stands on it as high as
    /// the tallest thing on the land: every corner of the view, on the
    /// ground and above it, falls inside, at a depth between the map's near
    /// and far.
    func testTheGroundInViewAndWhatStandsOnItLieInTheMap() throws {
        for scale in [MoonShadow.nearest, 70, 150, Camera.maximumScale] {
            for heading in [0.0, 0.9, 2.4, 4.0] {
                let eye = camera(scale: scale, heading: heading)
                let matrix = try XCTUnwrap(MoonShadow.matrix(camera: eye, size: size))
                for corner in [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height),
                               CGPoint(x: size.width, y: size.height), CGPoint(x: size.width / 2, y: size.height / 2)] {
                    let ground = eye.world(at: corner, in: size)
                    for height in [Float(0), MoonShadow.tallest] {
                        let at = mapped(Vec3(Float(ground.x), height, Float(ground.y)), by: matrix)
                        XCTAssertTrue((0...1).contains(at.uv.x) && (0...1).contains(at.uv.y), "Scale \(scale), heading \(heading): \(at.uv)")
                        XCTAssertTrue((0...1).contains(at.depth), "Scale \(scale), heading \(heading): depth \(at.depth)")
                    }
                }
            }
        }
    }

    /// Along the moon's light, what stands nearer the moon falls on the same
    /// texel as the ground it shades, and nearer: so it keeps the light off.
    func testWhatStandsNearerTheMoonFallsOnTheGroundItShades() throws {
        let matrix = try XCTUnwrap(MoonShadow.matrix(camera: camera(scale: 90), size: size))
        let ground = Vec3(3.5, 0, -1.5)
        let tower = ground + Sky.moon * 3
        let below = mapped(ground, by: matrix), above = mapped(tower, by: matrix)
        XCTAssertEqual(below.uv.x, above.uv.x, accuracy: 1e-5)
        XCTAssertEqual(below.uv.y, above.uv.y, accuracy: 1e-5)
        XCTAssertLessThan(above.depth, below.depth, "Nearer the moon, nearer in the map")
        // The moon lies high in the north: a shadow falls to the south.
        XCTAssertGreaterThan(Sky.moon.y, 0.5)
        XCTAssertLessThan(Sky.moon.z, 0)
    }

    /// As the view pans, the map moves by whole texels, so a shadow's edge
    /// stays where it fell; as it turns, the map keeps its size, so its
    /// texels neither grow nor shrink.
    func testTheMapMovesByWholeTexelsAndKeepsItsSizeAsTheViewTurns() throws {
        let still = try XCTUnwrap(MoonShadow.matrix(camera: camera(scale: 80), size: size))
        let texel = MoonShadow.texel(of: still)
        for step in [0.13, 0.5, 1.7, 9.31] {
            let panned = try XCTUnwrap(MoonShadow.matrix(camera: camera(scale: 80, x: 3 + step, y: -2 + step / 3), size: size))
            XCTAssertEqual(MoonShadow.texel(of: panned), texel, accuracy: texel * 1e-4)
            let point = Vec3(4, 0.5, -1)
            let moved = (mapped(point, by: panned).uv - mapped(point, by: still).uv) * Float(MoonShadow.side)
            XCTAssertEqual(moved.x, moved.x.rounded(), accuracy: 0.02, "Moved by \(moved.x) texels across")
            XCTAssertEqual(moved.y, moved.y.rounded(), accuracy: 0.02, "Moved by \(moved.y) texels down")
        }
        for heading in [0.4, 1.9, 3.3] {
            let turned = try XCTUnwrap(MoonShadow.matrix(camera: camera(scale: 80, heading: heading), size: size))
            XCTAssertEqual(MoonShadow.texel(of: turned), texel, accuracy: texel * 1e-4, "The same size, turned \(heading)")
        }
        // Closer, finer: the map's texel a few hundredths of a hex at most.
        let close = try XCTUnwrap(MoonShadow.matrix(camera: camera(scale: Camera.maximumScale), size: size))
        XCTAssertLessThan(MoonShadow.texel(of: close), texel)
        XCTAssertLessThan(texel, 0.05)
    }

    /// A frame close in casts the moon's shadows by its matrix and says so,
    /// with a texel's width in the world and in the map; one far out, or
    /// told to cast none, casts none.
    func testAFrameSaysWhetherTheMoonCasts() throws {
        let state = GameState(settings: GameSettings(seedText: "moonlit", houseCount: 4, radius: 12, keepers: 1))
        let terrain = TerrainMesh(relief: Relief(map: state.map), spacing: 0.3)
        func frame(_ scale: Double) -> FrameUniforms {
            FrameUniforms.make(camera: camera(scale: scale), size: size, pixelsPerPoint: 2, time: 1, motion: 1, radius: 12,
                               terrain: terrain, hovered: nil, selected: nil, houses: [])
        }
        var close = frame(90)
        XCTAssertTrue(close.casts)
        let matrix = try XCTUnwrap(MoonShadow.matrix(camera: camera(scale: 90), size: size))
        XCTAssertEqual(close.shadow, matrix)
        XCTAssertEqual(close.still.z, MoonShadow.texel(of: matrix))
        XCTAssertEqual(close.still.w, 1 / Float(MoonShadow.side))
        close.calm(Calm.deepest)
        XCTAssertTrue(close.casts, "The Still's calm and the moon's shadows side by side")
        XCTAssertEqual(close.still.x, 1)
        close.cast(nil)
        XCTAssertFalse(close.casts)
        XCTAssertFalse(frame(20).casts)
    }
}
