import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The land's furniture drawn only where a frame's view reaches: gathered
/// region by region, each region's bounds kept, and a frame drawing just
/// the runs of each batch its view can see, never a piece it could show.
final class RegionsTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "regions", houseCount: 12, radius: 36))
    private static let furniture: (stage: WorldStage, batches: [ModelBatch]) = {
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        return (stage, stage.furnish(occupied: [], holds: Set(state.holds.map(\.position))))
    }()

    func testFurnitureIsGatheredRegionByRegion() throws {
        let (stage, batches) = RegionsTests.furniture
        let regions = try XCTUnwrap(stage.furnitureRegions)
        XCTAssertEqual(regions.columns, 10)
        XCTAssertEqual(regions.starts.count, batches.count, "Each batch its starts")
        for (batch, starts) in zip(batches, regions.starts) {
            XCTAssertEqual(starts.first, 0)
            XCTAssertEqual(starts.last, batch.instances.count)
            for region in 0..<(starts.count - 1) {
                XCTAssertLessThanOrEqual(starts[region], starts[region + 1])
                for instance in batch.instances[starts[region]..<starts[region + 1]] {
                    let hex = Hex(Int(instance.hex.x), Int(instance.hex.y))
                    XCTAssertEqual(Regions.region(of: hex, radius: 36), region, "\(batch.key) at \(hex)")
                    let box = try XCTUnwrap(regions.boxes[region])
                    let at = instance.model.c3
                    XCTAssertTrue(at.x >= box.low.x && at.x <= box.high.x && at.y >= box.low.y && at.y <= box.high.y
                                  && at.z >= box.low.z && at.z <= box.high.z, "Within its region's bounds")
                }
            }
        }
        // The same pieces, kind for kind, as gathered in the land's order.
        let placed = batches.flatMap { batch in batch.instances.map { (batch.key, $0) } }
        let plain = WorldStage.batches(placed)
        XCTAssertEqual(plain.map(\.key), batches.map(\.key))
        for (a, b) in zip(plain, batches) {
            XCTAssertEqual(Set(a.instances.map { "\($0.model.c3)" }), Set(b.instances.map { "\($0.model.c3)" }))
        }
        // Regions fill the map row by row, every hex in one.
        XCTAssertEqual(Regions.region(of: Hex(-36, 0), radius: 36), 40)
        XCTAssertEqual(Regions.region(of: Hex(0, -36), radius: 36), 4)
        XCTAssertEqual(Regions.region(of: Hex(36, 0), radius: 36), 49)
        let all = Set(RegionsTests.state.map.hexes.map { Regions.region(of: $0, radius: 36) })
        XCTAssertTrue(all.allSatisfy { (0..<100).contains($0) })
    }

    /// Where a point of the world falls in the view, -1 to 1 each way and
    /// its depth, as the GPU has it.
    private func clip(_ point: Vec4, _ m: Mat4) -> Vec4 {
        m.c0 * point.x + m.c1 * point.y + m.c2 * point.z + m.c3 * point.w
    }

    func testAFrameDrawsOnlyTheRegionsItSees() throws {
        let (stage, batches) = RegionsTests.furniture
        let regions = try XCTUnwrap(stage.furnitureRegions)
        let size = CGSize(width: 1512, height: 982)
        let total = batches.reduce(0) { $0 + $1.instances.count }
        let seat = try XCTUnwrap(RegionsTests.state.holds.first { $0.isSeat }).position
        for (scale, tilt, heading) in [(60.0, 0.72, 0.0), (28.0, 0.72, 0.0), (28.0, 0.95, 2.1), (12.0, 0.6, 0.0), (9.0, 0.25, 0.4)] {
            var camera = Camera(scale: scale, tilt: tilt, heading: heading)
            camera.focus(on: seat)
            let viewProjection = camera.viewProjection(in: size)
            let runs = regions.runs(seenBy: viewProjection)
            XCTAssertEqual(runs.count, batches.count)
            var drawn = 0
            for (batch, runs) in zip(batches, runs) {
                var inRuns = [Bool](repeating: false, count: batch.instances.count)
                for run in runs {
                    XCTAssertFalse(run.isEmpty)
                    drawn += run.count
                    for index in run { inRuns[index] = true }
                }
                // Every piece whose foot lies in the view is drawn.
                for (index, instance) in batch.instances.enumerated() where !inRuns[index] {
                    let at = clip(Vec4(instance.model.c3.x, instance.model.c3.y, instance.model.c3.z, 1), viewProjection)
                    let shown = at.w > 0 && abs(at.x) <= at.w && abs(at.y) <= at.w && at.z >= 0 && at.z <= at.w
                    XCTAssertFalse(shown, "\(batch.key) at \(instance.hex) is in view at scale \(scale) but not drawn")
                }
            }
            print("REGIONS scale \(scale) tilt \(tilt): \(drawn) of \(total) pieces drawn")
            if scale >= 28 { XCTAssertLessThan(drawn, total / 2, "Near, most of the land unseen and undrawn") }
        }
        // A view of nothing at all draws nothing.
        var away = Camera(scale: 60)
        away.centerX = 10_000
        XCTAssertTrue(regions.runs(seenBy: away.viewProjection(in: size)).allSatisfy(\.isEmpty))
    }

    /// What the view takes in: every point it shows seen, those far off
    /// not, and one just past an edge seen once a ball about it reaches in.
    func testTheViewSeesWhatItShowsAndLittleMore() throws {
        let size = CGSize(width: 1512, height: 982)
        let seat = try XCTUnwrap(RegionsTests.state.holds.first { $0.isSeat }).position
        var camera = Camera(scale: 28)
        camera.focus(on: seat)
        let viewProjection = camera.viewProjection(in: size)
        let view = ViewFrustum(viewProjection: viewProjection)
        XCTAssertEqual(view.planes.count, 6)
        XCTAssertTrue(view.sees(seat, within: 0))
        XCTAssertFalse(view.sees(Hex(seat.q + 60, seat.r), within: 4), "Far off")
        var shown = 0, seen = 0
        for x in stride(from: -40 as Float, through: 40, by: 1.7) {
            for z in stride(from: -40 as Float, through: 40, by: 1.7) {
                for y in [0 as Float, 1.5] {
                    let point = Vec3(camera.focus.x + x, y, camera.focus.z + z)
                    let at = clip(Vec4(point.x, point.y, point.z, 1), viewProjection)
                    let inside = at.w > 0 && abs(at.x) <= at.w && abs(at.y) <= at.w && at.z >= 0 && at.z <= at.w
                    if inside { shown += 1 }
                    if view.sees(point, within: 0) { seen += 1 }
                    if inside { XCTAssertTrue(view.sees(point, within: 0), "\(point) in view") }
                }
            }
        }
        XCTAssertGreaterThan(shown, 100)
        XCTAssertLessThanOrEqual(seen, shown + shown / 100, "No more seen than shown, but on the edges")
        // A point a unit past the right edge: not itself, but a ball of a
        // unit and a half about it.
        let edge = camera.world(at: CGPoint(x: size.width, y: size.height / 2), in: size)
        let past = Vec3(Float(edge.x) + 1, 0, Float(edge.y))
        XCTAssertFalse(view.sees(past, within: 0))
        XCTAssertTrue(view.sees(past, within: 1.5))
    }

    /// A lake of forty-eight seats has four times the land, and near, a
    /// frame draws no more of it than over the realm proper's.
    func testAWideLakeDrawsNearAsMuchAsTheRealmPropers() throws {
        let state = GameState(settings: GameSettings(seedText: "regions", houseCount: 48, radius: 72))
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        let batches = stage.furnish(occupied: [], holds: Set(state.holds.map(\.position)))
        let regions = try XCTUnwrap(stage.furnitureRegions)
        XCTAssertEqual(regions.columns, 19)
        let size = CGSize(width: 1512, height: 982)
        let total = batches.reduce(0) { $0 + $1.instances.count }
        let near = RegionsTests.furniture
        let nearRegions = try XCTUnwrap(near.stage.furnitureRegions)
        func drawn(_ regions: Regions, at seat: Hex) -> Int {
            var camera = Camera(scale: 28)
            camera.focus(on: seat)
            return regions.runs(seenBy: camera.viewProjection(in: size)).joined().reduce(0) { $0 + $1.count }
        }
        let wide = drawn(regions, at: try XCTUnwrap(state.holds.first { $0.isSeat }).position)
        let proper = drawn(nearRegions, at: try XCTUnwrap(RegionsTests.state.holds.first { $0.isSeat }).position)
        print("REGIONS wide lake: \(wide) of \(total) pieces drawn at scale 28, against \(proper) over the realm proper's")
        XCTAssertLessThan(wide, total / 6, "Most of a wide lake out of sight")
        XCTAssertLessThan(Double(wide), Double(proper) * 1.5, "No more drawn near for a wider lake")
    }
}
