import LauncherCore
import Metal
import XCTest
@testable import LauncherKit

final class LakeShaderTests: XCTestCase {
    func testUniformLayoutMatchesTheShaderStruct() {
        // Two float4 fields in Metal: 32 bytes, 16-byte aligned.
        XCTAssertEqual(MemoryLayout<LakeUniforms>.size, 32)
        XCTAssertEqual(MemoryLayout<LakeUniforms>.stride, 32)
        XCTAssertEqual(MemoryLayout<LakeUniforms>.alignment, 16)
    }

    func testSourceDeclaresTheEntryPoints() {
        XCTAssertTrue(LakeShader.source.contains("vertex LakeVertexOut \(LakeShader.vertexFunction)("))
        XCTAssertTrue(LakeShader.source.contains("fragment float4 \(LakeShader.fragmentFunction)("))
        XCTAssertTrue(LakeShader.source.contains("// BEGIN SCENE"))
        XCTAssertTrue(LakeShader.source.contains("// END SCENE"))
    }

    func testMoonMatchesTheSharedComposition() throws {
        XCTAssertEqual(try define("NM_MOON_X"), LakeComposition.moonX, accuracy: 1e-9)
        XCTAssertEqual(try define("NM_MOON_Y"), LakeComposition.moonY, accuracy: 1e-9)
        XCTAssertEqual(try define("NM_MOON_R"), LakeComposition.moonRadius, accuracy: 1e-9)
    }

    /// Compiles the shader and builds the pipeline on this Mac's GPU. Skipped
    /// on machines without Metal, such as some virtualised CI runners;
    /// `scripts/check-shader.sh` covers those with the offline compiler.
    func testShaderCompilesAndBuildsAPipeline() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        let library = try device.makeLibrary(source: LakeShader.source, options: nil)
        XCTAssertNoThrow(try LakeRenderer(device: device, library: library, pixelFormat: .bgra8Unorm))
    }

    /// The scene starts over without a jump: its clock's period is a whole
    /// number of the falling star's chances and of the moon's breath.
    func testTheSceneStartsOverWithoutAJump() throws {
        let star = try define("NM_STAR_PERIOD")
        XCTAssertEqual(SceneClock.period.truncatingRemainder(dividingBy: star), 0)
        XCTAssertEqual(SceneClock.period.truncatingRemainder(dividingBy: 9), 0)
        XCTAssertTrue(LakeShader.source.contains("sin(NM_TAU * fract(time / 9.0))"), "The moon's breath is nine seconds")
    }

    private func define(_ name: String) throws -> Double {
        let line = try XCTUnwrap(
            LakeShader.source.split(separator: "\n").first { $0.contains("#define \(name) ") },
            "Missing #define \(name)"
        )
        return try XCTUnwrap(line.split(separator: " ").last.flatMap { Double($0) })
    }
}
