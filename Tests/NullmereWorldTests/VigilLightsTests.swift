import Foundation
@testable import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The vigils' lights for the fallen as the stage draws them: a flame and
/// a glow riding the water for each, carried on with the current through
/// the watch without a jump, lowering as their watches run out, each a
/// light the water mirrors, and seen from across the lake.
final class VigilLightsTests: XCTestCase {
    private let sight = VigilSight(at: Hex(2, -1), next: Hex(3, -1), id: 7, burned: 0)

    func testEachVigilIsAFlameAndAGlowOnTheWaterAndALight() {
        let (motes, lights) = WorldStage.vigils([sight, VigilSight(at: Hex(-4, 2), next: nil, id: 8, burned: 0.3)], progress: 0, scale: 60, time: 3)
        XCTAssertEqual(motes.count, 4)
        XCTAssertEqual(lights.count, 2)
        for mote in motes {
            XCTAssertGreaterThan(mote.place.y, Relief.waterline, "Riding the water")
            XCTAssertLessThan(mote.place.y, Relief.waterline + 0.06)
            XCTAssertEqual(mote.colour.w, 0, "Light only: it hides nothing")
        }
        XCTAssertGreaterThan(motes[1].place.w, motes[0].place.w, "The glow about the flame")
        XCTAssertGreaterThan(lights[0].colour.x, lights[0].colour.z, "Warm")
        // Where it floats: about the middle of its water, never more than its wander from it.
        let centre = Relief.centre(of: sight.at)
        let off = ((motes[0].place.x - centre.x) * (motes[0].place.x - centre.x) + (motes[0].place.z - centre.z) * (motes[0].place.z - centre.z)).squareRoot()
        XCTAssertLessThanOrEqual(off, WorldStage.vigilWander * 1.5)
    }

    func testCarriedOnThroughTheWatchWithoutAJump() {
        let start = WorldStage.vigils([sight], progress: 0, scale: 60, time: 3).motes[0].place
        let end = WorldStage.vigils([sight], progress: 1, scale: 60, time: 3).motes[0].place
        // At the watch's end where the next watch begins it: on the water the current took it to.
        let after = VigilSight(at: Hex(3, -1), next: Hex(4, -1), id: 7, burned: 0)
        let next = WorldStage.vigils([after], progress: 0, scale: 60, time: 3).motes[0].place
        XCTAssertEqual(end.x, next.x, accuracy: 0.0001)
        XCTAssertEqual(end.z, next.z, accuracy: 0.0001)
        let from = Relief.centre(of: sight.at), to = Relief.centre(of: Hex(3, -1))
        let travelled = ((end.x - start.x) * (end.x - start.x) + (end.z - start.z) * (end.z - start.z)).squareRoot()
        let hex = ((to.x - from.x) * (to.x - from.x) + (to.z - from.z) * (to.z - from.z)).squareRoot()
        XCTAssertEqual(travelled, hex, accuracy: 0.0001, "A hex on over the watch")
        // And it wanders and bobs as time goes, in its own time.
        let later = WorldStage.vigils([sight], progress: 0, scale: 60, time: 9).motes[0].place
        XCTAssertNotEqual(later, start)
        let other = WorldStage.vigils([VigilSight(at: sight.at, next: sight.next, id: 8, burned: 0)], progress: 0, scale: 60, time: 3).motes[0].place
        XCTAssertNotEqual(other, start, "Each its own")
    }

    func testItsFlameLowersAsItsWatchesRunOutAndShowsFromAfar() {
        func flame(_ burned: Float, scale: Double = 60) -> Mote {
            WorldStage.vigils([VigilSight(at: sight.at, next: sight.next, id: sight.id, burned: burned)], progress: 0, scale: scale, time: 3).motes[0]
        }
        XCTAssertEqual(flame(0).colour.x, flame(0.5).colour.x, accuracy: 0.0001, "Burning full through most of its watches")
        XCTAssertLessThan(flame(1).colour.x, flame(0).colour.x * 0.5, "Guttering at the last")
        // Close in, a small flame; from across the lake, its size kept on the screen.
        XCTAssertEqual(flame(0, scale: 200).place.w, 0.026, accuracy: 0.0001)
        XCTAssertEqual(flame(0, scale: 10).place.w * 10, WorldStage.vigilFlamePoints, accuracy: 0.0001)
        XCTAssertTrue(WorldStage.vigils([], progress: 0.5, scale: 60, time: 3).motes.isEmpty)
    }
}
