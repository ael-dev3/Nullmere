import NullmereCore
@testable import NullmereModels
import XCTest

/// The land's furniture where a company stands: whatever would rise among
/// its ranks gives way to it, in its hex and the edge of each beside it;
/// what lies underfoot stays, and no piece moves for it.
final class ScatterTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "a glade", houseCount: 3, radius: 12, keepers: 1))
    private static let relief = Relief(map: state.map)

    private func reach(_ piece: Piece, from hex: Hex) -> Float {
        let centre = Relief.centre(of: hex), p = piece.position
        return ((p.x - centre.x) * (p.x - centre.x) + (p.z - centre.z) * (p.z - centre.z)).squareRoot()
    }

    func testWhatRisesGivesWayToACompanyAndNothingMoves() throws {
        let map = Self.state.map
        let held = try XCTUnwrap(map.hexes.first { hex in
            map[hex]?.terrain == .blackwood && hex.neighbors.allSatisfy { map[$0]?.terrain == .blackwood }
        }, "A blackwood hex in the blackwood")
        // Its own ground: laid out as on open ground, then only what rises left out.
        let open = Scatter.pieces(in: held, map: map, relief: Self.relief)
        let here = Scatter.pieces(in: held, map: map, relief: Self.relief, occupied: [held])
        XCTAssertTrue(here.allSatisfy(open.contains), "Nothing moves")
        XCTAssertTrue(open.contains { $0.key == .furnishing(.fir) }, "A wood to clear")
        XCTAssertFalse(here.contains { $0.key == .furnishing(.fir) }, "No fir among its ranks")
        for piece in here {
            guard case .furnishing(let furnishing) = piece.key else { continue }
            XCTAssertLessThanOrEqual(Scatter.height(furnishing), Scatter.underfoot, "Only what lies underfoot: \(furnishing)")
            let c = piece.transform.c0
            XCTAssertGreaterThanOrEqual(reach(piece, from: held),
                                        Scatter.heart + Scatter.footprint(furnishing) * (c.x * c.x + c.y * c.y + c.z * c.z).squareRoot() - 1e-4,
                                        "Its heart clear of all, where the company stands")
        }
        // Beside it, the edge it reaches into gives way; the wood beyond stands.
        var gave = 0, stood = 0
        for beside in held.neighbors {
            let laid = Scatter.pieces(in: beside, map: map, relief: Self.relief)
            let kept = Scatter.pieces(in: beside, map: map, relief: Self.relief, occupied: [held])
            XCTAssertTrue(kept.allSatisfy(laid.contains), "Nothing moves beside it")
            for piece in laid where piece.key == .furnishing(.fir) {
                let c = piece.transform.c0
                let ground = Scatter.held + Scatter.footprint(.fir) * (c.x * c.x + c.y * c.y + c.z * c.z).squareRoot()
                XCTAssertEqual(kept.contains(piece), reach(piece, from: held) >= ground, "A fir gives way only in its ranks' way")
                if kept.contains(piece) { stood += 1 } else { gave += 1 }
            }
            XCTAssertEqual(Scatter.pieces(in: beside, map: map, relief: Self.relief, occupied: []), laid, "Gone, all as it was")
        }
        XCTAssertGreaterThan(gave, 0, "Some of the wood beside it gives way")
        XCTAssertGreaterThan(stood, gave, "Most of it stands")
        // A company two hexes off clears nothing here.
        let far = try XCTUnwrap(map.hexes.first { $0.distance(to: held) == 2 })
        XCTAssertEqual(Scatter.pieces(in: held, map: map, relief: Self.relief, occupied: [far]), open)
        // Firs and birches rise above a man's third; ferns, heather and pebbles don't.
        for furnishing in [Furnishing.fir, .birch, .deadTree, .crag, .elderTree] {
            XCTAssertGreaterThan(Scatter.height(furnishing), Scatter.underfoot, "\(furnishing)")
        }
        for furnishing in [Furnishing.fern, .heather, .pebbles, .grass, .steppingStones, .furrows] {
            XCTAssertLessThanOrEqual(Scatter.height(furnishing), Scatter.underfoot, "\(furnishing)")
        }
        XCTAssertEqual(Scatter.held, Formation.hexInner, "As far as its figures reach")
    }
}
