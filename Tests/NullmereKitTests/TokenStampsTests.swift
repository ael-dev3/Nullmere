import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereTestSupport
import NullmereWorld

/// The flat world's tokens drawn once and stamped (`TokenStamps`): each
/// stamp drawn once while it is kept, however many frames and tokens set
/// it; upright, in its House's colour about a dark shield, transparent
/// beyond it; and let go together past the most kept.
@MainActor
final class TokenStampsTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        TokenStamps.shared.forget()
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
        TokenStamps.shared.forget()
    }

    private func render(_ session: GameSession) throws -> CGImage {
        let renderer = ImageRenderer(content: WorldMarks(session: session, modelsDrawn: false).frame(width: 1000, height: 700)
            .background(Color.black))
        renderer.scale = 2
        return try XCTUnwrap(renderer.cgImage)
    }

    func testEachTokenIsDrawnOnceAndStampedEveryFrame() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "stamped tokens", keepers: 1)), store: LocalStore(directory: dir))
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        var camera = session.camera
        camera.focus(on: seat.position)
        camera.scale = 20
        session.camera = camera
        let first = try render(session)
        XCTAssertGreaterThanOrEqual(litPixels(first), 20, "Drawn, not blank")
        let made = TokenStamps.shared.made
        XCTAssertGreaterThan(made, 0, "The seat and its companies stamped")
        XCTAssertEqual(TokenStamps.shared.count, made, "Each kept as it was drawn")
        let again = try render(session)
        XCTAssertEqual(TokenStamps.shared.made, made, "Kept: none drawn again")
        XCTAssertGreaterThanOrEqual(litPixels(again), 20, "And set again")
        // Closer in, the tokens grow, and each new size is drawn once.
        camera.scale = 40
        session.camera = camera
        _ = try render(session)
        XCTAssertGreaterThan(TokenStamps.shared.made, made)
    }

    func testAStampIsUprightInItsHousesColourAboutADarkShield() throws {
        let red = Color(red: 0.9, green: 0.1, blue: 0.1).resolve(in: EnvironmentValues())
        let (_, stamp) = TokenStamps.shared.company(.spear, radius: 10, colour: red, fortified: false, scale: 2)
        let image = try XCTUnwrap(stamp.image)
        XCTAssertEqual(CGFloat(image.width), stamp.size.width * 2, accuracy: 0.5)
        XCTAssertEqual(CGFloat(image.height), stamp.size.height * 2, accuracy: 0.5)
        XCTAssertLessThan(stamp.offset.x, -8.5, "The shield's edge, its line and a point more, left of its centre")
        XCTAssertLessThan(stamp.offset.y, -8.5)
        // Read back in the order it is drawn, top row first.
        let width = image.width, height = image.height
        let space = try XCTUnwrap(CGColorSpace(name: CGColorSpace.sRGB))
        let reader = try XCTUnwrap(CGContext(data: nil, width: width, height: height, bitsPerComponent: 8, bytesPerRow: 0,
                                             space: space, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue))
        reader.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        let pixels = try XCTUnwrap(reader.data).bindMemory(to: UInt8.self, capacity: reader.bytesPerRow * height)
        let row = reader.bytesPerRow
        func pixel(atX x: CGFloat, y: CGFloat) -> (red: Int, green: Int, blue: Int, alpha: Int) {
            let column = Int(((x - stamp.offset.x) * 2).rounded(.down)), line = Int(((y - stamp.offset.y) * 2).rounded(.down))
            let at = line * row + column * 4
            return (Int(pixels[at]), Int(pixels[at + 1]), Int(pixels[at + 2]), Int(pixels[at + 3]))
        }
        // The shield's top edge, 8.5 points above its centre, in the House's red.
        let edge = pixel(atX: -4, y: -8.5)
        XCTAssertGreaterThan(edge.red, 150, "\(edge)")
        XCTAssertLessThan(edge.blue, 80, "\(edge)")
        // Its point, ten points below, red too: upright, the point down.
        let point = pixel(atX: 0, y: 9.6)
        XCTAssertGreaterThan(point.alpha, 100, "\(point)")
        XCTAssertGreaterThan(point.red, point.blue, "\(point)")
        // Within, the dark it is filled with; beyond its corner, nothing.
        let within = pixel(atX: -5, y: -5)
        XCTAssertGreaterThan(within.alpha, 200, "\(within)")
        XCTAssertLessThan(within.red, 40, "\(within)")
        let beyond = pixel(atX: stamp.offset.x + 0.25, y: stamp.offset.y + 0.25)
        XCTAssertEqual(beyond.alpha, 0, "\(beyond)")
        // Asked again, the same stamp; dug in, another, its line bolder.
        let made = TokenStamps.shared.made
        _ = TokenStamps.shared.company(.spear, radius: 10.1, colour: red, fortified: false, scale: 2)
        XCTAssertEqual(TokenStamps.shared.made, made, "The same to a quarter of a point")
        let (_, dug) = TokenStamps.shared.company(.spear, radius: 10, colour: red, fortified: true, scale: 2)
        XCTAssertEqual(TokenStamps.shared.made, made + 1)
        XCTAssertLessThan(dug.offset.x, stamp.offset.x + 0.01)
    }

    func testAHoldsStampShowsWhatItHasRaised() throws {
        var state = GameState(settings: GameSettings(seedText: "stamped holds", keepers: 1))
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let gold = Color(red: 0.8, green: 0.7, blue: 0.3).resolve(in: EnvironmentValues())
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].levels[.walls] = 0
        state.holds[index].levels[.moonspire] = 0
        let (bare, plain) = TokenStamps.shared.hold(state.holds[index], radius: 12, colour: gold, scale: 2)
        state.holds[index].levels[.walls] = 3
        state.holds[index].levels[.moonspire] = 2
        let walled = state.holds[index]
        let (raised, grown) = TokenStamps.shared.hold(walled, radius: 12, colour: gold, scale: 2)
        XCTAssertNotEqual(bare, raised, "Its walls and spire make another stamp")
        XCTAssertNotNil(plain.image)
        XCTAssertNotNil(grown.image)
        XCTAssertLessThan(grown.offset.y, plain.offset.y, "The spire's needle stands above the banner")
        XCTAssertGreaterThan(grown.size.height, plain.size.height)
    }

    func testStampsPastTheMostAreLetGoTogether() {
        // As many Houses' colours as are kept, each a small stamp of its own.
        for shade in 0..<TokenStamps.most {
            let colour = Color(red: Double(shade % 32) / 31, green: Double(shade / 32 % 32) / 31, blue: 0.2).resolve(in: EnvironmentValues())
            _ = TokenStamps.shared.company(.bow, radius: 4, colour: colour, fortified: false, scale: 2)
        }
        XCTAssertEqual(TokenStamps.shared.count, TokenStamps.most)
        XCTAssertEqual(TokenStamps.shared.made, TokenStamps.most)
        let grey = Color.gray.resolve(in: EnvironmentValues())
        _ = TokenStamps.shared.company(.rider, radius: 7, colour: grey, fortified: false, scale: 2)
        XCTAssertEqual(TokenStamps.shared.count, 1, "Let go together, and the new one kept")
    }
}
