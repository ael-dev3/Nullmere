import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

final class SceneTests: XCTestCase {
    func testTheGPUReadsTheFrameAndTheModelsAsTheShadersDeclareThem() {
        XCTAssertEqual(MemoryLayout<FrameUniforms>.stride, 464)
        XCTAssertEqual(MemoryLayout<FrameUniforms>.offset(of: \FrameUniforms.still), 384)
        XCTAssertTrue(WorldShaders.source.contains("float4 still;"))
        XCTAssertEqual(MemoryLayout<FrameUniforms>.offset(of: \FrameUniforms.shadow), 400)
        XCTAssertTrue(WorldShaders.source.contains("float4x4 shadow;"))
        XCTAssertEqual(MemoryLayout<FrameUniforms>.offset(of: \FrameUniforms.lights), 256)
        XCTAssertFalse(WorldShaders.source.contains("houses["), "The Houses' colours go apart, as their palette")
        XCTAssertTrue(WorldShaders.source.contains("texture2d<float, access::read> housePalette [[texture(3)]]"))
        XCTAssertTrue(WorldShaders.source.contains("slot % \(HousePalette.side)u, slot / \(HousePalette.side)u"), "The palette's rows as wide")
        XCTAssertLessThan(MemoryLayout<FrameUniforms>.stride, 4096, "Small enough to be sent with each frame")
        XCTAssertEqual(MemoryLayout<Mote>.stride, 32)
        XCTAssertTrue(WorldShaders.source.contains("float4 lights[8];"))
        XCTAssertTrue(WorldShaders.source.contains("struct Mote"))
        XCTAssertEqual(MemoryLayout<FrameUniforms>.offset(of: \FrameUniforms.eye), 128)
        XCTAssertEqual(MemoryLayout<FrameUniforms>.offset(of: \FrameUniforms.heights), 240)
        XCTAssertEqual(MemoryLayout<ModelInstance>.stride, 112)
        XCTAssertEqual(MemoryLayout<ModelInstance>.offset(of: \ModelInstance.hex), 96)
        XCTAssertEqual(MemoryLayout<ModelInstance>.offset(of: \ModelInstance.palette), 104)
        let instance = ModelInstance(model: .translation(Vec3(1, 2, 3)), colour: Vec4(1, 0, 0, 1), rise: 0.4, opacity: 0.5, phase: 2,
                                     emphasis: 1, hex: SIMD2(3, -4), palette: 7, flags: ModelInstance.alwaysShown)
        XCTAssertEqual(instance.params, Vec4(0.4, 0.5, 2, 1))
        XCTAssertEqual(instance.flags & ModelInstance.alwaysShown, 1)
        XCTAssertTrue(WorldShaders.source.contains("struct ModelInstance"))
        XCTAssertEqual(Set(WorldShaders.functions).count, 11)
        for name in WorldShaders.functions {
            XCTAssertTrue(WorldShaders.source.contains(" \(name)("), "\(name) is in the source")
        }
    }

    /// The Houses' colours as the shaders read them: a House's a texel past
    /// its sigil, the first texel no House's, every texel no House has grey,
    /// and room for every House the widest lake seats.
    func testEveryHouseHasATexelOfThePalette() {
        let texels = HousePalette.texels([Vec4(1, 0, 0, 1), Vec4(0, 1, 0, 1)])
        func texel(_ slot: Int) -> Vec4 { Vec4(texels[slot * 4], texels[slot * 4 + 1], texels[slot * 4 + 2], texels[slot * 4 + 3]) }
        XCTAssertEqual(texels.count, HousePalette.side * HousePalette.side * 4)
        XCTAssertEqual(texel(1), Vec4(1, 0, 0, 1), "A House's colour a texel past its sigil")
        XCTAssertEqual(texel(2), Vec4(0, 1, 0, 1))
        XCTAssertEqual(texel(0), HousePalette.none, "No House's")
        XCTAssertEqual(texel(3), HousePalette.none, "Texels no House has, grey")
        XCTAssertGreaterThanOrEqual(HousePalette.slots, WorldGenerator.mostHouses, "A texel for every House a lake seats")
        let wide = HousePalette.texels((0..<WorldGenerator.mostHouses).map { Vec4(Float($0), 0, 0, 1) })
        let last = WorldGenerator.mostHouses
        XCTAssertEqual(wide[last * 4], Float(last - 1), "The last House a lake seats has its own")
        XCTAssertEqual(HousePalette.texels(Array(repeating: Vec4(1, 1, 1, 1), count: 5_000)).count, wide.count, "No more than the texture holds")
    }

    /// The widest lakes' Houses each have a colour of their own, after the
    /// ninety-six the interface names by hand, as light and as rich as
    /// those: no channel as dark or as bright as theirs never are.
    func testTheWidestLakesHousesEachHaveAColourOfTheirOwn() {
        let colours = HousePalette.widestLakes
        XCTAssertEqual(colours.count, WorldGenerator.mostHouses - 96)
        XCTAssertEqual(Set(colours).count, colours.count, "Each its own")
        for colour in colours {
            for channel in [colour >> 16 & 0xFF, colour >> 8 & 0xFF, colour & 0xFF] {
                XCTAssertTrue((41...230).contains(channel), "0x\(String(colour, radix: 16)): as far from black and white as the hand-named")
            }
        }
    }

    func testAFrameKeepsItsPosesTogether() {
        var frame = SceneFrame(palette: [])
        XCTAssertEqual(frame.palette, [.identity], "the first pose stands still")
        XCTAssertEqual(frame.add(pose: [.identity]), 0, "a model at rest shares it")
        let moved = [Mat4.identity, .translation(Vec3(0, 1, 0))]
        XCTAssertEqual(frame.add(pose: moved), 1)
        XCTAssertEqual(frame.add(pose: moved), 3)
        XCTAssertEqual(frame.palette.count, 5)
        frame.batches = [ModelBatch(key: .scaffold, instances: [ModelInstance(model: .identity), ModelInstance(model: .identity)]),
                         ModelBatch(key: .prop(.arrow), instances: [ModelInstance(model: .identity)])]
        XCTAssertEqual(frame.instanceCount, 3)
        frame.fixed = [ModelBatch(key: .furnishing(.fir), instances: [ModelInstance(model: .identity)])]
        frame.fixedVersion = 2
        XCTAssertEqual(frame.instanceCount, 4, "what stands still counts too")
        XCTAssertEqual(SceneFrame(fixed: frame.fixed, fixedVersion: 2).fixedVersion, 2)
    }

    func testAFramesUniformsFollowTheCameraAndTheLand() throws {
        let state = GameState(settings: GameSettings(seedText: "uniforms", houseCount: 6, radius: 14))
        let terrain = TerrainMesh.shared(for: state.map, spacing: 0.6)
        XCTAssertEqual(TerrainMesh.shared(for: state.map, spacing: 0.6).mesh.vertices.count, terrain.mesh.vertices.count, "kept, not made again")
        let camera = Camera(centerX: 2, centerY: -1, scale: 30)
        let size = CGSize(width: 800, height: 500)
        let frame = FrameUniforms.make(camera: camera, size: size, pixelsPerPoint: 2, time: 12, motion: 0.5, radius: 14, terrain: terrain,
                                       hovered: Hex(1, 1), selected: nil)
        XCTAssertEqual(frame.viewport, Vec4(1600, 1000, 1 / 1600, 1 / 1000))
        XCTAssertEqual(frame.world, Vec4(14, 29, 60, 0.5))
        XCTAssertEqual(frame.highlight, Vec4(1, 1, 999, 999))
        XCTAssertEqual(frame.eye.w, 12)
        XCTAssertEqual(frame.extent.x, terrain.mesh.bounds.min.x)
        XCTAssertEqual(frame.heights, Vec4(terrain.originX, terrain.originZ, Float(terrain.columns), Float(terrain.rows)))
        XCTAssertGreaterThan(frame.haze.x, 0)
        XCTAssertEqual(frame.haze.w, 0.6)
        let eye = camera.eye(in: size)
        XCTAssertEqual(Vec3(frame.eye.x, frame.eye.y, frame.eye.z), eye)
        let inverse = try XCTUnwrap(frame.viewProjection.inverse)
        XCTAssertEqual(frame.inverseViewProjection, inverse)
        XCTAssertEqual(frame, frame)
        var other = frame
        other.highlight = Vec4(0, 0, 0, 0)
        XCTAssertNotEqual(frame, other)
        XCTAssertNotEqual(Sky.moon.y, 0)
        XCTAssertEqual(Sky.moon.length, 1, accuracy: 1e-5)
    }

    func testOnlyAFewLandsAreKept() {
        let maps = (0..<5).map { GameState(settings: GameSettings(seedText: "kept \($0)", houseCount: 6, radius: 12)).map }
        for map in maps { _ = TerrainMesh.shared(for: map, spacing: 1.2) }
        let again = TerrainMesh.shared(for: maps[4], spacing: 1.2)
        XCTAssertEqual(again.spacing, 1.2)
        XCTAssertGreaterThan(again.mesh.vertices.count, 100)
    }
}
