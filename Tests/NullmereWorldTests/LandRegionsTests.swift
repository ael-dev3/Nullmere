import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The land drawn only where a frame's view reaches, as its furniture is:
/// its triangles gathered chunk by chunk, each chunk's bounds kept, and a
/// frame drawing just the chunks it sees, never a triangle it could show.
final class LandRegionsTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "regions", houseCount: 12, radius: 36))
    private static let terrain = TerrainMesh.shared(for: state.map)
    private static let land = LandRegions(terrain)
    private static let size = CGSize(width: 1512, height: 982)

    private func clip(_ point: Vec3, _ m: Mat4) -> Vec4 {
        m.c0 * point.x + m.c1 * point.y + m.c2 * point.z + m.c3
    }

    private func shown(_ point: Vec3, _ m: Mat4) -> Bool {
        let at = clip(point, m)
        return at.w > 0 && abs(at.x) <= at.w && abs(at.y) <= at.w && at.z >= 0 && at.z <= at.w
    }

    func testEveryTriangleOfTheLandIsKeptOnceInItsChunk() {
        let terrain = LandRegionsTests.terrain, land = LandRegionsTests.land
        func triangles(_ indices: [UInt32]) -> [SIMD3<UInt32>] {
            stride(from: 0, to: indices.count, by: 3).map { SIMD3(indices[$0], indices[$0 + 1], indices[$0 + 2]) }
        }
        let mine = triangles(land.indices), mesh = triangles(terrain.mesh.indices)
        XCTAssertEqual(mine.count, mesh.count)
        XCTAssertEqual(Set(mine), Set(mesh), "The same triangles, each wound as the mesh winds it")
        XCTAssertEqual(Set(mine).count, mine.count, "Each once")

        let across = (terrain.columns - 1 + LandRegions.side - 1) / LandRegions.side
        let down = (terrain.rows - 1 + LandRegions.side - 1) / LandRegions.side
        XCTAssertEqual(land.boxes.count, across * down, "Chunks of the grid, row by row")
        XCTAssertEqual(land.starts.count, land.boxes.count + 1)
        XCTAssertEqual(land.starts.first, 0)
        XCTAssertEqual(land.starts.last, land.indices.count)
        XCTAssertEqual(land.starts[1] - land.starts[0], LandRegions.side * LandRegions.side * 6, "A whole chunk's squares")
        for chunk in land.boxes.indices {
            let box = land.boxes[chunk]
            XCTAssertLessThan(land.starts[chunk], land.starts[chunk + 1], "No chunk empty")
            XCTAssertLessThanOrEqual(box.low.y, LandRegions.mistLevel, "Reaching down to the mist")
            XCTAssertGreaterThanOrEqual(box.high.y, LandRegions.mistLevel)
            for index in land.indices[land.starts[chunk]..<land.starts[chunk + 1]] {
                let p = terrain.mesh.vertices[Int(index)].position
                XCTAssertTrue(p.x >= box.low.x && p.x <= box.high.x && p.y >= box.low.y && p.y <= box.high.y
                              && p.z >= box.low.z && p.z <= box.high.z, "Chunk \(chunk)'s point \(p) within its bounds")
            }
        }
    }

    /// The land's shader lays what is unknown under the mist at this height.
    func testTheMistLevelIsTheShadersOwn() {
        XCTAssertTrue(WorldShaders.source.contains("kMistLevel = \(LandRegions.mistLevel);"))
    }

    func testAFrameDrawsOnlyTheLandItSees() throws {
        let terrain = LandRegionsTests.terrain, land = LandRegionsTests.land
        let seat = try XCTUnwrap(LandRegionsTests.state.holds.first { $0.isSeat }).position
        let total = land.indices.count
        for (scale, tilt, heading) in [(60.0, 0.72, 0.0), (28.0, 0.72, 0.0), (28.0, 0.95, 2.1), (12.0, 0.6, 0.0), (9.0, 0.25, 0.4), (2.0, 0.72, 0.0)] {
            var camera = Camera(scale: scale, tilt: tilt, heading: heading)
            camera.focus(on: seat)
            let viewProjection = camera.viewProjection(in: LandRegionsTests.size)
            let runs = land.runs(seenBy: viewProjection)
            var drawn = [Bool](repeating: false, count: total / 3), count = 0
            for run in runs {
                XCTAssertFalse(run.isEmpty)
                XCTAssertEqual(run.lowerBound % 3, 0, "Runs of whole triangles")
                for first in stride(from: run.lowerBound, to: run.upperBound, by: 3) { drawn[first / 3] = true }
                count += run.count
            }
            for (a, b) in zip(runs, runs.dropFirst()) {
                XCTAssertLessThan(a.upperBound, b.lowerBound, "In order, neighbours joined")
            }
            // Each point of the land in view, where it stands or laid under
            // the mist: every triangle with a corner there is drawn.
            let inView = terrain.mesh.vertices.map { vertex in
                shown(vertex.position, viewProjection) || shown(Vec3(vertex.position.x, LandRegions.mistLevel, vertex.position.z), viewProjection)
            }
            var missed = 0
            for triangle in drawn.indices where !drawn[triangle] {
                if (0..<3).contains(where: { inView[Int(land.indices[3 * triangle + $0])] }) { missed += 1 }
            }
            XCTAssertEqual(missed, 0, "Triangles in view at scale \(scale) but not drawn")
            print("LAND scale \(scale) tilt \(tilt): \(count / 3) of \(total / 3) triangles drawn in \(runs.count) runs")
            if scale >= 28 { XCTAssertLessThan(count, total / 3, "Near, most of the land unseen and undrawn") }
        }
        // A view of nothing at all draws nothing.
        var away = Camera(scale: 60)
        away.centerX = 10_000
        XCTAssertTrue(land.runs(seenBy: away.viewProjection(in: LandRegionsTests.size)).isEmpty)
    }

    /// A realm of ninety-six seats has some seven times the land of twelve,
    /// and near its seat a frame draws about as much of it as the twelve's.
    func testAWideRealmsFrameDrawsNearAsMuchLandAsANarrowOnes() throws {
        func drawnNear(seats: Int) throws -> (drawn: Int, whole: Int) {
            let state = GameState(settings: GameSettings(seedText: "a wide land", houseCount: seats,
                                                         radius: RealmState.radius(forSeats: seats)))
            let land = LandRegions(TerrainMesh.shared(for: state.map))
            var camera = Camera(scale: 28)
            camera.focus(on: try XCTUnwrap(state.holds.first { $0.isSeat }).position)
            let drawn = land.runs(seenBy: camera.viewProjection(in: LandRegionsTests.size)).reduce(0) { $0 + $1.count }
            return (drawn, land.indices.count)
        }
        let narrow = try drawnNear(seats: 12), wide = try drawnNear(seats: 96)
        print("LAND near a seat: \(narrow.drawn / 3) of \(narrow.whole / 3) triangles of twelve seats, "
              + "\(wide.drawn / 3) of \(wide.whole / 3) of ninety-six")
        XCTAssertGreaterThan(wide.whole, narrow.whole * 4, "The wide realm's land is the greater")
        XCTAssertLessThan(Double(wide.drawn), Double(narrow.drawn) * 1.5, "but no more of it is drawn near")
    }
}
