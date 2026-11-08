import Foundation
import NullmereCore
@testable import NullmereWorld
import XCTest

/// The lake heard at its edge near the view (`ShoreSound`): only where its
/// own water meets the land, only water the House has seen, the nearer the
/// louder and from where it lies across the view; silent out on the open
/// lake and from far back. How the shore itself sounds is measured in
/// NullmereSoundTests.
final class ShoreSoundTests: XCTestCase {
    private let state = GameState(settings: GameSettings(seedText: "shore", keepers: 1))

    private func isEdge(_ hex: Hex) -> Bool {
        guard let tile = state.map[hex], ShoreSound.isLake(tile.terrain) else { return false }
        return hex.neighbors.contains { state.map[$0].map { !$0.terrain.isWater } ?? false }
    }

    /// The strand with the most strand about it.
    private func strand() throws -> Hex {
        try XCTUnwrap(state.map.hexes.filter(isEdge).max { a, b in
            (a.spiral(3).filter(isEdge).count, b) < (b.spiral(3).filter(isEdge).count, a)
        })
    }

    func testTheEdgeIsTheLakesOwnWaterBesideTheLand() throws {
        let map = state.map
        let edge = try strand()
        let found = ShoreSound.edges(about: edge, reach: 3, in: map) { _ in true }
        XCTAssertEqual(found.first, edge, "Nearest first")
        XCTAssertEqual(Set(found), Set(edge.spiral(3).filter(isEdge)), "Every stretch of strand within reach, and nothing else")
        XCTAssertGreaterThan(found.count, 3)
        XCTAssertEqual(ShoreSound.edges(about: edge, reach: 3, in: map) { _ in false }, [], "Water no one has seen is not heard")
        let seen = Set(found.prefix(2))
        XCTAssertEqual(Set(ShoreSound.edges(about: edge, reach: 3, in: map) { seen.contains($0) }), seen)
        // Out on the open lake, far from any strand: silent.
        let open = try XCTUnwrap(map.hexes.first { hex in
            map[hex]?.terrain == .still && hex.spiral(4).allSatisfy { map[$0].map { ShoreSound.isLake($0.terrain) } ?? true }
        })
        XCTAssertEqual(ShoreSound.edges(about: open, reach: 3, in: map) { _ in true }, [])
        XCTAssertTrue(ShoreSound.isLake(.still))
        XCTAssertTrue(ShoreSound.isLake(.shallows))
        XCTAssertFalse(ShoreSound.isLake(.stream), "A stream runs; it doesn't lap")
        XCTAssertFalse(ShoreSound.isLake(.ford))
        XCTAssertFalse(ShoreSound.isLake(.strand))
        // As far as about half the view at its nearness.
        XCTAssertEqual(ShoreSound.reach(at: Camera.maximumScale), 3)
        XCTAssertEqual(ShoreSound.reach(at: 64), 7)
        XCTAssertEqual(ShoreSound.reach(at: Camera.minimumScale), 12)
    }

    func testTheShoreIsHeardAsNearAsTheViewComesAndFromWhereItLies() throws {
        let edge = try strand()
        var camera = Camera()
        camera.focus(on: edge)
        camera.heading = 0
        let edges = ShoreSound.edges(about: edge, reach: ShoreSound.reach(at: ShoreSound.fullest), in: state.map) { _ in true }
        camera.scale = ShoreSound.faintest - 4
        XCTAssertNil(ShoreSound.heard(edges, from: camera), "Well back, the shore is not heard")
        camera.scale = ShoreSound.fullest
        let close = try XCTUnwrap(ShoreSound.heard(edges, from: camera))
        XCTAssertGreaterThan(close.level, 0.5, "The strand all about the view's middle, close")
        XCTAssertLessThanOrEqual(close.level, 1)
        camera.scale = (ShoreSound.faintest + ShoreSound.fullest) / 2
        let farther = try XCTUnwrap(ShoreSound.heard(edges, from: camera))
        XCTAssertLessThan(farther.level, close.level, "Farther back, fainter")
        XCTAssertNil(ShoreSound.heard([], from: camera), "No strand, no sound")

        // One stretch of strand a little to the right of the view: heard
        // from the right; the view turned about, from the left.
        camera.scale = ShoreSound.fullest
        camera.centerX -= 0.3 * 600 / camera.scale
        let one = try XCTUnwrap(ShoreSound.heard([edge], from: camera))
        XCTAssertGreaterThan(one.pan, 0.1, "From the right")
        XCTAssertLessThan(one.level, close.level, "One stretch quieter than the strand all about")
        camera.heading = .pi
        XCTAssertLessThan(try XCTUnwrap(ShoreSound.heard([edge], from: camera)).pan, -0.1, "Turned about, from the left")

        // The calmer the Still lies, the quieter it laps.
        XCTAssertEqual(ShoreSound.stilled(by: 0), 1)
        XCTAssertEqual(ShoreSound.stilled(by: 4), 0.7, accuracy: 1e-6)
        XCTAssertEqual(ShoreSound.stilled(by: Calm.deepest), 0.25, accuracy: 1e-6)
        XCTAssertEqual(ShoreSound.stilled(by: 99), 0.25, accuracy: 1e-6)
    }
}
