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
                highlight: SIMD4(999, 999, 999, 999),
                moon: MoonMirror.place(in: state.map)
            )
            XCTAssertNotNil(renderer.measureFrame(uniforms, into: target), "\(lake) drawn")
            var pixels = [UInt8](repeating: 0, count: width * height * 4)
            target.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
            // A night scene: the world's hexagon drawn, its edges in the dark.
            var lit = 0
            for start in stride(from: 0, to: pixels.count, by: 4) {
                let brightness: Int = Int(pixels[start]) + Int(pixels[start + 1]) + Int(pixels[start + 2])
                if brightness > 12 { lit += 1 }
            }
            let share = Double(lit) / Double(width * height)
            XCTAssertTrue((0.1...0.95).contains(share), "\(lake): \(Int(share * 100))% drawn")
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

    /// The moon lays a path of light down the water beneath it: the water
    /// under the moon is plainly brighter than open water to either side.
    func testTheMoonLaysAPathOnTheWater() throws {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShader.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        let width = 900, height = 600
        let scale: Float = 12
        var state = GameState(settings: GameSettings(seedText: "moon path", houseCount: 12, radius: 36, lake: .round))
        state.houses[state.player].explored = Array(repeating: true, count: state.map.count)
        try renderer.updateTiles(TileTexture.bytes(for: state, viewer: state.player), side: TileTexture.side(for: state.map))
        let moon = MoonMirror.place(in: state.map)
        XCTAssertEqual(moon.w, 1, "The round lake holds the moon")
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .bgra8Unorm, width: width, height: height, mipmapped: false)
        descriptor.usage = [.renderTarget, .shaderRead]
        descriptor.storageMode = .shared
        let target = try XCTUnwrap(device.makeTexture(descriptor: descriptor))
        // The moon a little above the middle, so the path runs below it.
        let centre = SIMD2(moon.x, moon.y + 4)
        let uniforms = WorldUniforms(view: SIMD4(Float(width), Float(height), scale, 20),
                                     camera: SIMD4(centre.x, centre.y, Float(state.map.radius), 1),
                                     highlight: SIMD4(999, 999, 999, 999), moon: moon)
        XCTAssertNotNil(renderer.measureFrame(uniforms, into: target))
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        target.getBytes(&pixels, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)

        // Open water only: a hex of still water whose neighbours are too,
        // away from the moon's own face and glow.
        let layout = HexLayout(size: 1)
        func openWater(_ hex: Hex) -> Bool {
            guard state.map[hex]?.terrain == .still else { return false }
            return state.map.neighbors(of: hex).allSatisfy { state.map[$0]?.terrain == .still }
        }
        let moonX = Float(width) / 2 + (moon.x - centre.x) * scale
        var path: [Int] = [], side: [Int] = []
        for y in stride(from: height / 2, to: height - 4, by: 2) {
            for x in stride(from: 0, to: width, by: 2) {
                let wx = (Float(x) - Float(width) / 2) / scale + centre.x
                let wy = (Float(y) - Float(height) / 2) / scale + centre.y
                guard (wy - moon.y) > 4, openWater(layout.hex(atX: Double(wx), y: Double(wy))) else { continue }
                let i = (y * width + x) * 4
                let sum = Int(pixels[i]) + Int(pixels[i + 1]) + Int(pixels[i + 2])
                let off = abs(Float(x) - moonX) / Float(height)
                if off < 0.04 { path.append(sum) } else if off > 0.25 { side.append(sum) }
            }
        }
        XCTAssertGreaterThan(path.count, 100, "Open water under the moon")
        XCTAssertGreaterThan(side.count, 100, "Open water to either side")
        // Medians, so reflected stars don't count.
        func median(_ values: [Int]) -> Int { values.sorted()[values.count / 2] }
        let lit = median(path), dark = median(side)
        XCTAssertGreaterThanOrEqual(lit - dark, 20, "The path shows: \(lit) under the moon, \(dark) beside it")
        XCTAssertLessThan(lit, 200, "and the lake stays black glass: \(lit)")
    }
}
