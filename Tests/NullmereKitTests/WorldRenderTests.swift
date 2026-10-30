import AppKit
import Metal
@testable import NullmereCore
@testable import NullmereKit
import NullmereModels
import NullmereWorld
import XCTest

/// The world in three dimensions, drawn by its own shaders on this Mac's
/// GPU and looked at: the still black lake holding the stars and the
/// moon, the mist over what the keeper has never seen, the land lit by the
/// moon, and the hex chosen. CI keeps the frames, and prints them small.
final class WorldRenderTests: XCTestCase {
    static let width = 960
    static let height = 600
    static var size: CGSize { CGSize(width: width, height: height) }

    struct Drawn {
        let name: String
        let pixels: [UInt8]
        let camera: Camera

        func luminance(_ x: Int, _ y: Int) -> Double {
            let i = (y * WorldRenderTests.width + x) * 4
            return 0.0722 * Double(pixels[i]) + 0.7152 * Double(pixels[i + 1]) + 0.2126 * Double(pixels[i + 2])
        }
    }

    /// A realm's world, as its keeper first sees it, and whole.
    struct World {
        let state: GameState
        let opening: [UInt8]
        let whole: [UInt8]
        let terrain: TerrainMesh
        let relief: Relief

        init() {
            var state = GameState(settings: GameSettings(seedText: "drawn in the round", houseCount: 12, radius: 24, keepers: 1))
            opening = TileTexture.bytes(for: state, viewer: state.player)
            state.houses[state.player].explored = Array(repeating: true, count: state.map.count)
            whole = TileTexture.bytes(for: state, viewer: state.player)
            self.state = state
            terrain = TerrainMesh.shared(for: state.map)
            relief = Relief(map: state.map)
        }
    }

    static let world = World()

    func renderer() throws -> WorldRenderer {
        guard let device = MTLCreateSystemDefaultDevice() else { throw XCTSkip("No Metal device available") }
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
        try renderer.setLand(WorldRenderTests.world.terrain, for: WorldRenderTests.world.state.map)
        return renderer
    }

    func draw(_ renderer: WorldRenderer, _ name: String, camera: Camera, tiles: [UInt8], selected: Hex? = nil) throws -> Drawn {
        let world = WorldRenderTests.world
        try renderer.updateTiles(tiles, side: TileTexture.side(for: world.state.map))
        let target = try renderer.makeTarget(width: WorldRenderTests.width, height: WorldRenderTests.height)
        let frame = FrameUniforms.make(camera: camera, size: WorldRenderTests.size, pixelsPerPoint: 1, time: 20, motion: 1,
                                       radius: world.state.map.radius, terrain: world.terrain, hovered: nil, selected: selected,
                                       houses: WorldView.houseColours)
        let pixels = try XCTUnwrap(renderer.pixels(frame, into: target), "\(name) drawn")
        return Drawn(name: name, pixels: pixels, camera: camera)
    }

    /// Where the view's ray through a pixel meets the world, and what is there.
    func ground(at x: Int, _ y: Int, in drawn: Drawn) -> (hex: Hex, terrain: Terrain?)? {
        let world = WorldRenderTests.world
        let (origin, direction) = drawn.camera.ray(through: CGPoint(x: x, y: y), in: WorldRenderTests.size)
        guard let hit = world.relief.intersect(origin: origin, direction: direction) else { return nil }
        let hex = HexLayout(size: 1).hex(atX: Double(hit.x), y: Double(hit.z))
        return (hex, world.state.map[hex]?.terrain)
    }

    func testTheStillWaterHoldsTheMoonAndTheStars() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        let lake = try XCTUnwrap(world.state.moonWater).hex
        var camera = Camera(scale: 16)
        camera.focus(on: lake)
        camera.centerY += 6
        let drawn = try draw(renderer, "lake", camera: camera, tiles: world.whole)
        try keep([drawn], as: "world-lake")

        // Over the open water, deep from any shore: black, but for the
        // moon and the stars it gives back.
        var water: [Double] = []
        var brightest = (value: 0.0, x: 0, y: 0)
        for y in stride(from: 0, to: WorldRenderTests.height, by: 3) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 3) {
                guard let found = ground(at: x, y, in: drawn), found.terrain == .still,
                      found.hex.neighbors.allSatisfy({ world.state.map[$0]?.terrain == .still }) else { continue }
                let value = drawn.luminance(x, y)
                water.append(value)
                if value > brightest.value { brightest = (value, x, y) }
            }
        }
        XCTAssertGreaterThan(water.count, 2000, "the view holds open water")
        let sorted = water.sorted()
        XCTAssertLessThan(sorted[sorted.count / 2], 26, "the still water is black")
        XCTAssertGreaterThan(brightest.value, 170, "the moon lies in it")
        let stars = water.filter { $0 > 45 }.count
        XCTAssertGreaterThan(stars, 6, "and the stars")
    }

    func testTheUnknownLiesUnderMistAndTheKnownIsLit() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        let seat = try XCTUnwrap(world.state.seat(of: world.state.player)).position
        var camera = Camera(scale: 30)
        camera.focus(on: seat)
        let opening = try draw(renderer, "opening", camera: camera, tiles: world.opening, selected: seat)
        try keep([opening], as: "world-opening")
        let explored = world.state.houses[world.state.player].explored
        // As the keeper first sees it: their own land lit, the rest unknown.
        var mist: [Double] = [], land: [Double] = []
        for y in stride(from: 0, to: WorldRenderTests.height, by: 4) {
            for x in stride(from: 0, to: WorldRenderTests.width, by: 4) {
                let point = CGPoint(x: x, y: y)
                let flat = camera.hex(at: point, in: WorldRenderTests.size)
                guard let index = world.state.map.index(of: flat) else { continue }
                let around = flat.neighbors.compactMap { world.state.map.index(of: $0) }
                if !explored[index], around.allSatisfy({ !explored[$0] }) {
                    mist.append(opening.luminance(x, y))
                } else if explored[index], around.allSatisfy({ explored[$0] }), !(world.state.map[flat]?.terrain.isWater ?? true) {
                    land.append(opening.luminance(x, y))
                }
            }
        }
        XCTAssertGreaterThan(mist.count, 200)
        XCTAssertGreaterThan(land.count, 50)
        let mistMean = mist.reduce(0, +) / Double(mist.count), landMean = land.reduce(0, +) / Double(land.count)
        XCTAssertLessThan(mistMean, 40, "the mist is night-dark")
        XCTAssertGreaterThan(landMean, mistMean, "the known land is lit above the mist")
        let spread = (mist.map { ($0 - mistMean) * ($0 - mistMean) }.reduce(0, +) / Double(mist.count)).squareRoot()
        XCTAssertGreaterThan(spread, 0.3, "the mist lies in banks, never one flat grey")

        // The hex chosen is ringed.
        let plain = try draw(renderer, "unchosen", camera: camera, tiles: world.opening)
        let centre = camera.viewPoint(of: seat, height: Double(world.relief.height(of: seat)), in: WorldRenderTests.size)
        var brighter = 0
        for dy in -40...40 {
            for dx in -60...60 {
                let x = Int(centre.x) + dx, y = Int(centre.y) + dy
                guard x >= 0, y >= 0, x < WorldRenderTests.width, y < WorldRenderTests.height else { continue }
                if opening.luminance(x, y) > plain.luminance(x, y) + 8 { brighter += 1 }
            }
        }
        XCTAssertGreaterThan(brighter, 40, "a light rings the chosen hex")
    }

    func testTheWholeWorldFromAfarAndTurned() throws {
        let renderer = try renderer()
        let world = WorldRenderTests.world
        let far = try draw(renderer, "whole", camera: Camera(scale: 9, tilt: 0.6), tiles: world.whole)
        var turned = Camera(scale: 24, heading: 0.9)
        turned.focus(on: try XCTUnwrap(world.state.seat(of: world.state.player)).position)
        let side = try draw(renderer, "turned", camera: turned, tiles: world.whole)
        try keep([far, side], as: "world-afar")
        for drawn in [far, side] {
            var lit = 0, total = 0
            for y in stride(from: 0, to: WorldRenderTests.height, by: 5) {
                for x in stride(from: 0, to: WorldRenderTests.width, by: 5) {
                    total += 1
                    if drawn.luminance(x, y) > 14 { lit += 1 }
                }
            }
            let share = Double(lit) / Double(total)
            XCTAssertTrue((0.15...0.97).contains(share), "\(drawn.name): \(Int(share * 100))% of the view lit")
        }
    }

    /// Keeps the frames as one sheet when NULLMERE_KEEP_RENDERS names a
    /// folder, and prints it small for CI's log.
    func keep(_ frames: [Drawn], as name: String) throws {
        let width = WorldRenderTests.width, height = WorldRenderTests.height
        let images: [CGImage] = try frames.map { drawn in
            let provider = try XCTUnwrap(CGDataProvider(data: Data(drawn.pixels) as CFData))
            return try XCTUnwrap(CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                                         space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                                         bitmapInfo: CGBitmapInfo(rawValue: CGImageAlphaInfo.noneSkipFirst.rawValue | CGBitmapInfo.byteOrder32Little.rawValue),
                                         provider: provider, decode: nil, shouldInterpolate: false, intent: .defaultIntent))
        }
        let sheet = NSImage(size: NSSize(width: width * images.count, height: height))
        sheet.lockFocus()
        for (index, image) in images.enumerated() {
            NSImage(cgImage: image, size: NSSize(width: width, height: height)).draw(in: NSRect(x: index * width, y: 0, width: width, height: height))
        }
        sheet.unlockFocus()
        let tiff = try XCTUnwrap(sheet.tiffRepresentation)
        let rep = try XCTUnwrap(NSBitmapImageRep(data: tiff))
        if let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] {
            let png = try XCTUnwrap(rep.representation(using: .png, properties: [:]))
            try FileManager.default.createDirectory(at: URL(fileURLWithPath: path), withIntermediateDirectories: true)
            try png.write(to: URL(fileURLWithPath: path).appendingPathComponent("\(name).png"))
        }
        // Small enough to print: a fifth of each side, as a JPEG.
        let small = NSImage(size: NSSize(width: width * images.count / 2, height: height / 2))
        small.lockFocus()
        sheet.draw(in: NSRect(x: 0, y: 0, width: width * images.count / 2, height: height / 2))
        small.unlockFocus()
        if let smallTIFF = small.tiffRepresentation, let smallRep = NSBitmapImageRep(data: smallTIFF),
           let jpeg = smallRep.representation(using: .jpeg, properties: [.compressionFactor: 0.6]) {
            let text = jpeg.base64EncodedString()
            var start = text.startIndex
            var line = 0
            while start < text.endIndex {
                let end = text.index(start, offsetBy: 2000, limitedBy: text.endIndex) ?? text.endIndex
                print("RENDER64 \(name) \(String(format: "%03d", line)) \(text[start..<end])")
                start = end
                line += 1
            }
        }
    }
}
