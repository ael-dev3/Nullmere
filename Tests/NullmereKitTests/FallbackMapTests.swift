import AppKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The map painted without Metal plays as the full map does: the moon lies
/// in its water, a hold's land shows whose it is, and the tile chosen and
/// the one under the pointer are outlined.
@MainActor
final class FallbackMapTests: XCTestCase {
    private let size = CGSize(width: 600, height: 400)

    private func session(knowingTheMoonsWater: Bool = false) -> (GameSession, URL) {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        var state = GameState(settings: GameSettings(seedText: "painted without metal", houseCount: 4, radius: 18))
        if knowingTheMoonsWater, let water = state.moonWater {
            state.reveal(around: water.hex, range: 4, for: state.player)
        }
        return (GameSession(state: state, store: LocalStore(directory: dir)), dir)
    }

    /// The painting, as RGBA bytes.
    private func paint(_ session: GameSession) throws -> (pixels: [UInt8], width: Int) {
        try paint(WorldFallback(session: session))
    }

    private func paint(_ view: some View) throws -> (pixels: [UInt8], width: Int) {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        let width = image.width, height = image.height
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        let context = try XCTUnwrap(CGContext(data: &pixels, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                              space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        return (pixels, width)
    }

    private func light(_ painted: (pixels: [UInt8], width: Int), at point: CGPoint) -> Int {
        let i = (Int(point.y) * painted.width + Int(point.x)) * 4
        return Int(painted.pixels[i]) + Int(painted.pixels[i + 1]) + Int(painted.pixels[i + 2])
    }

    func testTheMoonLiesInItsWaterWhereTheKeeperKnowsIt() throws {
        let (session, dir) = session(knowingTheMoonsWater: true)
        defer { try? FileManager.default.removeItem(at: dir) }
        let moon = session.moon
        XCTAssertEqual(moon.w, 1, "This lake holds the moon")
        session.camera = Camera(centerX: Double(moon.x), centerY: Double(moon.y), scale: 30)
        let painted = try paint(session)
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        XCTAssertGreaterThan(light(painted, at: centre), 600, "The moon, bright on the water")
        let away = CGPoint(x: centre.x + CGFloat(moon.z) * 30 * 4, y: centre.y)
        XCTAssertLessThan(light(painted, at: away), 120, "and the water beyond it dark")

        // Water the keeper hasn't seen tells nothing of the moon in it.
        let (unknowing, otherDir) = self.session()
        defer { try? FileManager.default.removeItem(at: otherDir) }
        unknowing.camera = session.camera
        XCTAssertLessThan(light(try paint(unknowing), at: centre), 60, "Unknown water, dark")
    }

    func testAHoldsLandShowsWhoseItIs() throws {
        let (session, dir) = session()
        defer { try? FileManager.default.removeItem(at: dir) }
        let state = session.state
        let seat = try XCTUnwrap(state.seat(of: session.player))
        let land = try XCTUnwrap(state.map.hexes.enumerated().first { index, hex in
            hex != seat.position && session.territory[index] == seat.id && state.map[index].terrain != .still
        })
        session.camera.focus(on: land.element)
        let painted = try paint(session)
        // The same ground, unwashed, painted the same way.
        let seen = session.visible[land.offset]
        let tint = WorldFallback.colour(for: state.map[land.offset].terrain)
        let bare = try paint(Rectangle().fill(seen ? tint : tint.opacity(0.5)).background(WorldFallback.water))
        let centre = CGPoint(x: size.width / 2, y: size.height / 2)
        XCTAssertGreaterThan(abs(light(painted, at: centre) - light(bare, at: centre)), 6, "Washed in the House's colour")
    }

    func testTheChosenTileAndTheOneUnderThePointerAreOutlined() throws {
        let (session, dir) = session()
        defer { try? FileManager.default.removeItem(at: dir) }
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        session.camera.focus(on: seat.position)
        let plain = try paint(session)
        session.selection = .hold(seat.id)
        XCTAssertEqual(session.selectedHex, seat.position)
        let chosen = try paint(session)
        let neighbour = try XCTUnwrap(session.state.map.neighbors(of: seat.position).first)
        session.selection = .none
        session.hover(neighbour)
        let hovered = try paint(session)
        // The pixels that changed, and how many of them lie away from the tile.
        func changed(_ other: (pixels: [UInt8], width: Int), around hex: Hex) -> (count: Int, far: Int) {
            var count = 0, far = 0
            for i in stride(from: 0, to: plain.pixels.count, by: 4) where plain.pixels[i ..< i + 3] != other.pixels[i ..< i + 3] {
                count += 1
                let point = CGPoint(x: (i / 4) % plain.width, y: (i / 4) / plain.width)
                if session.camera.hex(at: point, in: size).distance(to: hex) > 1 { far += 1 }
            }
            return (count, far)
        }
        let selection = changed(chosen, around: seat.position)
        XCTAssertGreaterThan(selection.count, 40, "The chosen tile is outlined")
        XCTAssertEqual(selection.far, 0, "there, and nowhere else")
        let pointer = changed(hovered, around: neighbour)
        XCTAssertGreaterThan(pointer.count, 20, "The tile under the pointer is outlined")
        XCTAssertEqual(pointer.far, 0)
    }
}
