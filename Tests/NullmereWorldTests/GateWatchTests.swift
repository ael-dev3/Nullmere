import XCTest
import NullmereCore
import NullmereModels
@testable import NullmereWorld

/// An ally keeping a hold's gates is seen there: its banner at the gate
/// and two sentries of its kind pacing across it.
final class GateWatchTests: XCTestCase {
    private let state = GameState(settings: GameSettings(seedText: "gate watch", houseCount: 4, radius: 12, keepers: 1))

    func testAnAllyKeepingTheGatesStandsItsBannerAndSentriesThere() throws {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let hold = try XCTUnwrap(state.holds.first).position
        let keeper = hold.neighbors[2]
        let watch = WorldStage.GateWatch(hold: hold, keeper: keeper, kind: .spear, tier: 2, colour: Vec4(0.2, 0.4, 0.9, 1))
        var frame = SceneFrame()
        let batches = stage.gateWatch([watch], time: 3, into: &frame)
        let banners = batches.first { $0.key == .hostBanner }?.instances ?? []
        let sentries = batches.first { $0.key == ModelKey.figure(.spear, tier: 2).canonical }?.instances ?? []
        XCTAssertEqual(banners.count, 1, "The ally's banner at the gate")
        XCTAssertEqual(sentries.count, 2, "Two sentries")
        XCTAssertTrue(sentries.allSatisfy { $0.colour == watch.colour }, "In the ally's colour")
        // At the gate on the keeper's side of the hold, not in the keep.
        let inside = Relief.centre(of: hold), outside = Relief.centre(of: keeper)
        for sentry in sentries {
            let at = sentry.model.c3
            let fromHeart = (Vec3(at.x, 0, at.z) - Vec3(inside.x, 0, inside.z)).length
            XCTAssertEqual(fromHeart, WorldStage.gateReach, accuracy: WorldStage.gateBeat + 0.02)
            XCTAssertLessThan((Vec3(at.x, 0, at.z) - Vec3(outside.x, 0, outside.z)).length, (Vec3(inside.x, 0, inside.z) - Vec3(outside.x, 0, outside.z)).length)
        }
        // They pace: a moment later they stand elsewhere.
        var later = SceneFrame()
        let moved = stage.gateWatch([watch], time: 4.5, into: &later).first { $0.key == ModelKey.figure(.spear, tier: 2).canonical }?.instances ?? []
        XCTAssertNotEqual(moved.map(\.model.c3.x), sentries.map(\.model.c3.x))
        // A company standing on the hold itself keeps no gate to draw.
        var none = SceneFrame()
        XCTAssertTrue(stage.gateWatch([WorldStage.GateWatch(hold: hold, keeper: hold, kind: .spear, tier: 2, colour: watch.colour)],
                                      time: 1, into: &none).isEmpty)
    }
}
