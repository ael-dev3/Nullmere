import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// A hold seen taken changes its banners at its keep: the House it was
/// taken from has its banner lowered into the earth, then the taker's is
/// raised out of it, stands a while and fades.
final class CaptureBannersTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "captures", houseCount: 4, radius: 12, keepers: 1))
    private static let relief = Relief(map: state.map)
    private var stage: WorldStage { WorldStage(map: Self.state.map, relief: Self.relief) }
    private var hold: Hex { Self.state.holds[0].position }
    private let gold = Vec4(0.9, 0.7, 0.2, 1)
    private let teal = Vec4(0.1, 0.7, 0.6, 1)

    /// How far below where it stands upright a banner's foot lies.
    private func sunk(_ banner: ModelInstance) -> Float {
        let centre = Relief.centre(of: hold)
        let x = centre.x + WorldStage.captureOffset.x, z = centre.z + WorldStage.captureOffset.z
        return stage.ground(atX: x, z: z) - Scatter.sink - banner.model.c3.y
    }

    func testTheOldBannerIsLoweredThenTheTakersRaisedStandsAndFades() {
        let start = WorldStage.captureShowing(age: 0)
        XCTAssertEqual(start.old, 1, "the old banner stands when the hold is taken")
        XCTAssertEqual(start.new, 0, "the taker's not yet raised")
        XCTAssertEqual(start.fade, 1)
        let lowering = WorldStage.captureShowing(age: 0.6)
        XCTAssertEqual(lowering.old, 0.5, accuracy: 1e-5, "half lowered halfway through")
        XCTAssertEqual(lowering.new, 0)
        let between = WorldStage.captureShowing(age: 1.3)
        XCTAssertEqual(between.old, 0, "the old banner gone before the taker's rises")
        XCTAssertEqual(between.new, 0)
        let raising = WorldStage.captureShowing(age: 2.1)
        XCTAssertEqual(raising.new, 0.5, accuracy: 1e-5, "half raised halfway through")
        let standing = WorldStage.captureShowing(age: 4)
        XCTAssertEqual(standing.new, 1, "the taker's banner stands")
        XCTAssertEqual(standing.fade, 1, "and shows fully")
        XCTAssertEqual(WorldStage.captureShowing(age: WorldStage.captureSeconds - 0.5).fade, 0.5, accuracy: 1e-5, "fading over the last second")
        XCTAssertEqual(WorldStage.captureShowing(age: WorldStage.captureSeconds).fade, 0, "gone at the end")
        // Eased at each end: slow to start and slow to stop.
        XCTAssertLessThan(1 - WorldStage.captureShowing(age: 0.12).old, 0.1 / 2)
        XCTAssertLessThan(WorldStage.captureShowing(age: 1.4 + 0.14).new, 0.1 / 2)
    }

    func testTheOldHousesBannerSinksIntoTheEarthAtTheKeep() throws {
        let batches = stage.captures([(at: hold, from: teal, by: gold, age: 0.6)])
        XCTAssertEqual(batches.map(\.key), [.hostBanner])
        let banners = try XCTUnwrap(batches.first).instances
        XCTAssertEqual(banners.count, 1, "only the old House's banner while it is lowered")
        let banner = try XCTUnwrap(banners.first)
        XCTAssertEqual(banner.colour, teal, "in the colour of the House it was taken from")
        XCTAssertEqual(sunk(banner), WorldStage.bannerHeight * 0.5, accuracy: 1e-4, "half sunk halfway through")
        let centre = Relief.centre(of: hold)
        XCTAssertEqual(banner.model.c3.x, centre.x + WorldStage.captureOffset.x, accuracy: 1e-4)
        XCTAssertEqual(banner.model.c3.z, centre.z + WorldStage.captureOffset.z, accuracy: 1e-4)
        let fromHeart = ((banner.model.c3.x - centre.x) * (banner.model.c3.x - centre.x)
            + (banner.model.c3.z - centre.z) * (banner.model.c3.z - centre.z)).squareRoot()
        XCTAssertGreaterThan(fromHeart, WorldStage.markBannerOffset, "clear of the keep, as an alliance's mark is")
        let fromMark = ((banner.model.c3.x - centre.x) * (banner.model.c3.x - centre.x)
            + (banner.model.c3.z - centre.z - WorldStage.markBannerOffset) * (banner.model.c3.z - centre.z - WorldStage.markBannerOffset)).squareRoot()
        XCTAssertGreaterThan(fromMark, 0.3, "and clear of an alliance's mark on the same ground")
        XCTAssertEqual(banner.flags & ModelInstance.alwaysShown, ModelInstance.alwaysShown)
        XCTAssertEqual(banner.hex, SIMD2(Int32(hold.q), Int32(hold.r)))
        XCTAssertEqual(banner.params.y, 1, "the old banner shows fully as it goes down")

        let atStart = try XCTUnwrap(stage.captures([(at: hold, from: teal, by: gold, age: 0)]).first?.instances.first)
        XCTAssertEqual(sunk(atStart), 0, accuracy: 1e-4, "standing when the hold is taken")
    }

    func testTheTakersBannerRisesStandsAndFades() throws {
        let rising = try XCTUnwrap(stage.captures([(at: hold, from: teal, by: gold, age: 2.1)]).first).instances
        XCTAssertEqual(rising.map(\.colour), [gold], "only the taker's banner once the old is down")
        XCTAssertEqual(sunk(rising[0]), WorldStage.bannerHeight * 0.5, accuracy: 1e-4, "half risen halfway through")
        XCTAssertEqual(rising[0].params.y, 1)

        let standing = try XCTUnwrap(stage.captures([(at: hold, from: teal, by: gold, age: 4)]).first).instances
        XCTAssertEqual(standing.map(\.colour), [gold])
        XCTAssertEqual(sunk(standing[0]), 0, accuracy: 1e-4, "standing on its ground")
        XCTAssertEqual(standing[0].params.y, 1)

        let fading = try XCTUnwrap(stage.captures([(at: hold, from: teal, by: gold, age: WorldStage.captureSeconds - 0.5)]).first).instances
        XCTAssertEqual(fading[0].params.y, 0.5, accuracy: 1e-5, "fading at the last")
        XCTAssertTrue(stage.captures([(at: hold, from: teal, by: gold, age: WorldStage.captureSeconds + 0.5)]).isEmpty, "gone once past")
        XCTAssertTrue(stage.captures([(at: hold, from: teal, by: gold, age: -1)]).isEmpty, "nothing before it was taken")
        XCTAssertTrue(stage.captures([]).isEmpty)
        XCTAssertTrue(stage.captures([(at: hold, from: teal, by: gold, age: 1.3)]).isEmpty, "a moment bare between the two")
    }

    func testAHoldOfNoHouseShowsOnlyTheTakersBanner() throws {
        XCTAssertTrue(stage.captures([(at: hold, from: nil, by: gold, age: 0.6)]).isEmpty, "no banner to lower where it was no House's")
        let standing = try XCTUnwrap(stage.captures([(at: hold, from: nil, by: gold, age: 4)]).first).instances
        XCTAssertEqual(standing.map(\.colour), [gold])
    }

    func testEachHoldTakenHasItsOwnBanners() throws {
        let other = Self.state.holds[1].position
        let banners = try XCTUnwrap(stage.captures([(at: hold, from: teal, by: gold, age: 4), (at: other, from: gold, by: teal, age: 0.3)]).first).instances
        XCTAssertEqual(banners.count, 2)
        XCTAssertEqual(banners.map(\.hex), [SIMD2(Int32(hold.q), Int32(hold.r)), SIMD2(Int32(other.q), Int32(other.r))])
        XCTAssertEqual(banners.map(\.colour), [gold, gold], "the taker's standing at one, the old House's going down at the other")
        XCTAssertGreaterThan(WorldStage.bannerHeight, 0.3, "a banner tall enough to see go down")
        XCTAssertLessThan(WorldStage.bannerHeight, 2)
    }
}
