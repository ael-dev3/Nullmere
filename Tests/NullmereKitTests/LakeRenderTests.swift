import AppKit
import Metal
@testable import NullmereCore
import XCTest
@testable import NullmereKit

/// Each age's lake, drawn by the world's own shader, whole and known, for
/// the eye: CI prints the four together.
final class LakeRenderTests: XCTestCase {
    func testEveryLakeIsDrawn() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShader.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        let width = 640, height = 440
        var images: [CGImage] = []
        for lake in Lake.allCases {
            var state = GameState(settings: GameSettings(seedText: "drawn \(lake.rawValue)", houseCount: 12, radius: 36, lake: lake))
            state.houses[state.player].explored = Array(repeating: true, count: state.map.count)
            try renderer.updateTiles(TileTexture.bytes(for: state, viewer: state.player), side: TileTexture.side(for: state.map))
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
            descriptor.usage = [.renderTarget, .shaderRead]
            descriptor.storageMode = .shared
            let target = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
            let uniforms = WorldUniforms(
                view: SIMD4(Float(width), Float(height), 3.4, 20),
                camera: SIMD4(0, 0, Float(state.map.radius), 1),
                highlight: SIMD4(999, 999, 999, 999)
            )
            XCTAssertNotNil(renderer.measureFrame(uniforms, into: target), "\(lake) drawn")
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            target.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            // Black water, lit land: the picture is neither empty nor flat.
            var lit = 0
            for start in stride(from: 0, to: pixels.count, by: 4) {
                let brightness: Int = Int(pixels[start]) + Int(pixels[start + 1]) + Int(pixels[start + 2])
                if brightness > 60 { lit += 1 }
            }
            let share = Double(lit) / Double(width * height)
            XCTAssertTrue((0.1...0.95).contains(share), "\(lake): \(Int(share * 100))% lit")
            let provider = try XCTUnwrap(CGDataProvider(data: Data(pixels) as CFData))
            let image = try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(),
                                              bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                              provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
            images.append(image)
        }
        guard let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] else { return }
        let sheet = NSImage(size: NSSize(width: width * 2, height: height * 2))
        sheet.lockFocus()
        for (index, image) in images.enumerated() {
            let x = (index % 2) * width, y = (1 - index / 2) * height
            NSImage(cgImage: image, size: NSSize(width: width, height: height)).draw(in: NSRect(x: x, y: y, width: width, height: height))
        }
        sheet.unlockFocus()
        let tiff = try XCTUnwrap(sheet.tiffRepresentation)
        let png = try XCTUnwrap(NSBitmapImageRep(data: tiff)?.representation(using: .png, properties: [:]))
        try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
        try png.write(to: URL(fileURLWithPath: path).appendingPathComponent("game-lakes.png"))
    }
}
