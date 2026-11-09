import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// A company of the keeper's lying in wait, hidden in the wood: half seen
/// while it waits at rest and whole the moment it moves; the trees of the
/// wood standing among its ranks where every other company's ground gives
/// way to them; another House's company never drawn so.
final class AmbushStageTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "stage", houseCount: 4, radius: 12, keepers: 1))
    private static let relief = Relief(map: state.map)

    private func company(_ unit: Int, at hex: Hex, isOwn: Bool, clip: Clip = .idle) -> CompanyPose {
        let centre = Relief.centre(of: hex)
        return CompanyPose(unit: unit, key: .figure(.spear, tier: 2), sigil: 1, health: 100, hex: hex,
                           position: Vec3(centre.x, 0, centre.z), heading: 0.4, clip: clip, isOwn: isOwn)
    }

    func testACompanyLyingInWaitIsHalfSeenAmongTheTreesOfTheWood() throws {
        let map = Self.state.map
        let wood = try XCTUnwrap(map.hexes.first { hex in
            Self.state.isCover(hex) && hex.neighbors.allSatisfy { map[$0]?.terrain == .blackwood }
        }, "A hex deep in the blackwood")
        let open = try XCTUnwrap(map.hexes.filter { hex in
            hex.distance(to: wood) > 2 && map[hex]?.terrain.isPassable == true && map[hex]?.terrain.isWater == false
        }.prefix(2).map { $0 })
        let waiting = company(4, at: wood, isOwn: true)
        let other = company(5, at: open[0], isOwn: true)
        let foreign = company(6, at: open[1], isOwn: false)
        let (drawn, ground) = WorldStage.lyingInWait([waiting, other, foreign], waiting: [4, 6])
        // Half seen, never lost to its own keeper.
        XCTAssertEqual(drawn[0].opacity, WorldStage.waitingOpacity)
        XCTAssertLessThan(WorldStage.waitingOpacity, 0.8)
        XCTAssertGreaterThan(WorldStage.waitingOpacity, 0.4)
        XCTAssertEqual(drawn[1].opacity, 1, "A company not lying in wait shows whole")
        XCTAssertEqual(drawn[2].opacity, 1, "Only the keeper's own are drawn hidden")
        XCTAssertEqual(drawn.map(\.unit), [4, 5, 6], "Every company still drawn, in its order")
        // Whole the moment it moves: striking, struck, or on the march.
        for clip in [Clip.attack, .hit, .march] {
            XCTAssertEqual(WorldStage.lyingInWait([company(4, at: wood, isOwn: true, clip: clip)], waiting: [4]).companies[0].opacity, 1, "\(clip)")
        }
        // The trees of the wood stand among its ranks; every other company's
        // ground gives way to them.
        XCTAssertEqual(ground, Set(open), "\(ground)")
        XCTAssertEqual(WorldStage.lyingInWait([waiting, other], waiting: []).ground, [wood, open[0]], "None lying in wait, none hidden")
        let stage = WorldStage(map: map, relief: Self.relief)
        let among = stage.furnish(occupied: ground, holds: []).filter(\.isTall).count(at: wood)
        let cleared = stage.furnish(occupied: ground.union([wood]), holds: []).filter(\.isTall).count(at: wood)
        XCTAssertGreaterThan(among, cleared, "Trees standing on its ground while it waits, which give way to a company not lying in wait")
    }
}

private extension ModelBatch {
    /// Whether its pieces rise above what lies underfoot: trees, not ferns.
    var isTall: Bool {
        guard case .furnishing(let furnishing) = key else { return false }
        return Scatter.height(furnishing) > Scatter.underfoot
    }
}

private extension Array where Element == ModelBatch {
    /// How many pieces stand on a hex.
    func count(at hex: Hex) -> Int {
        flatMap(\.instances).filter { $0.hex == SIMD2(Int32(hex.q), Int32(hex.r)) }.count
    }
}
