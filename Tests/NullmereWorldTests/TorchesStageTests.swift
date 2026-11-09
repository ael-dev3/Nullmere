import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The torches the companies carry through the night: two at the front of
/// each company in sight, borne in the outer hands of its front rank's
/// outermost, warm, flickering each in its own time and steady where motion
/// is reduced, their glow keeping a few points on the screen as the view
/// draws away; none for a company marching dark, nor one within walls,
/// aboard a barge, in a field of battle or fallen; the nearest so many
/// companies to the view at most.
final class TorchesStageTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "stage", houseCount: 4, radius: 12, keepers: 1))
    private static let relief = Relief(map: state.map)

    private func stage() -> WorldStage {
        WorldStage(map: Self.state.map, relief: Self.relief)
    }

    private func company(_ unit: Int, at hex: Hex, heading: Float = 0.8, health: Int = 100, stage: WorldStage) -> CompanyPose {
        let centre = Relief.centre(of: hex)
        return CompanyPose(unit: unit, key: .figure(.spear, tier: 2), sigil: 1, health: health, hex: hex,
                           position: Vec3(centre.x, stage.ground(atX: centre.x, z: centre.z), centre.z), heading: heading, isOwn: false)
    }

    private var land: [Hex] {
        Self.state.map.hexes.filter { Self.state.map[$0]?.terrain.isPassable == true && Self.state.map[$0]?.terrain.isWater == false }
    }

    private static func flames(_ motes: [Mote]) -> [Mote] { motes.filter { $0.place.w == WorldStage.torchFlameSize } }

    func testACompanyBearsTwoTorchesAtItsFrontInItsOuterHands() throws {
        let stage = stage()
        let hex = try XCTUnwrap(land.first)
        let pose = company(4, at: hex, stage: stage)
        let motes = stage.torches([pose], dark: [], near: pose.position, scale: 60, time: 3)
        XCTAssertEqual(motes.count, 4, "A flame and its glow for each of two torches")
        let flames = Self.flames(motes)
        XCTAssertEqual(flames.count, 2)
        let turn = Mat4.rotationY(pose.heading)
        let forward = turn.transformDirection(Vec3(0, 0, 1)), across = turn.transformDirection(Vec3(1, 0, 0))
        var sides: [Float] = []
        for flame in flames {
            let from = Vec3(flame.place.x - pose.position.x, 0, flame.place.z - pose.position.z)
            // Held up at the shoulder over the ground where its bearer stands.
            let ground = stage.ground(atX: flame.place.x, z: flame.place.z)
            XCTAssertEqual(flame.place.y - ground, WorldStage.torchHand.y * WorldStage.figureScale, accuracy: 0.05, "At the raised hand")
            // At the front of the company, within its hex.
            XCTAssertGreaterThan(from.x * forward.x + from.z * forward.z, 0, "In its front rank")
            XCTAssertLessThan(from.length, Relief.hexSpacing, "Within its ground")
            sides.append(from.x * across.x + from.z * across.z)
            // Warm, an open fire's light, hiding nothing.
            XCTAssertTrue(flame.colour.x > flame.colour.y && flame.colour.y > flame.colour.z && flame.colour.z > 0, "\(flame.colour)")
            XCTAssertEqual(flame.colour.w, 0)
        }
        XCTAssertLessThan(sides[0] * sides[1], 0, "One at either end of the rank")
        XCTAssertGreaterThan(abs(sides[0] - sides[1]), 0.5, "Held outward, wider than the rank's own figures")
        // Each flame in its glow, the glow dimmer and wider.
        for glow in motes where glow.place.w != WorldStage.torchFlameSize {
            XCTAssertTrue(flames.contains { $0.place.x == glow.place.x && $0.place.z == glow.place.z && $0.colour.x > glow.colour.x * 5 })
            XCTAssertEqual(glow.colour.w, 0)
        }
        // A company worn down to one figure bears one torch.
        let worn = stage.torches([company(4, at: hex, health: 8, stage: stage)], dark: [], near: pose.position, scale: 60, time: 3)
        XCTAssertEqual(Self.flames(worn).count, 1)
    }

    func testTheGlowKeepsAFewPointsOnTheScreenFromAfar() throws {
        let stage = stage()
        let pose = company(4, at: try XCTUnwrap(land.first), stage: stage)
        func glows(at scale: Double) -> [Mote] {
            stage.torches([pose], dark: [], near: pose.position, scale: scale, time: 3).filter { $0.place.w != WorldStage.torchFlameSize }
        }
        for glow in glows(at: Camera.minimumScale) {
            XCTAssertEqual(Double(glow.place.w) * Camera.minimumScale, WorldStage.torchGlowPoints, accuracy: 0.001, "Its points on the screen from afar")
        }
        for glow in glows(at: Camera.maximumScale) {
            XCTAssertEqual(glow.place.w, WorldStage.torchGlowSize, "No smaller than its own light close by")
        }
    }

    func testACompanyMarchingDarkCarriesNone() throws {
        let stage = stage()
        let hexes = Array(land.prefix(6))
        let lit = company(1, at: hexes[0], stage: stage), dark = company(2, at: hexes[1], stage: stage)
        let both = stage.torches([lit, dark], dark: [2], near: lit.position, scale: 60, time: 3)
        XCTAssertEqual(both, stage.torches([lit], dark: [], near: lit.position, scale: 60, time: 3), "Only the lit company's")
        XCTAssertEqual(stage.torches([lit, dark], dark: [1, 2], near: lit.position, scale: 60, time: 3), [])
        // Nor within a hold's walls or aboard a barge, drawn up small; nor
        // in a field of battle, its throng lit by the fight; nor fallen.
        var walled = company(3, at: hexes[2], stage: stage)
        walled.spread = 0.3
        var fighting = company(4, at: hexes[3], stage: stage)
        fighting.throng = 40
        let fallen = company(-5, at: hexes[4], stage: stage)
        // Nor the wilds, creatures of the dark.
        var wild = company(6, at: hexes[5], stage: stage)
        wild.key = .wild(tier: 1)
        XCTAssertEqual(stage.torches([walled, fighting, fallen, wild], dark: [], near: lit.position, scale: 60, time: 3), [])
        XCTAssertEqual(stage.torches([], dark: [], near: lit.position, scale: 60, time: 3), [])
    }

    func testTorchesFlickerEachInItsOwnTimeAndHoldStillWhereMotionIsReduced() throws {
        let stage = stage()
        let hexes = Array(land.prefix(2))
        let one = company(1, at: hexes[0], stage: stage), two = company(2, at: hexes[1], stage: stage)
        let now = Self.flames(stage.torches([one], dark: [], near: one.position, scale: 60, time: 3))
        let soon = Self.flames(stage.torches([one], dark: [], near: one.position, scale: 60, time: 3.07))
        XCTAssertNotEqual(now.map(\.colour), soon.map(\.colour), "Flickering")
        for (a, b) in zip(now, soon) {
            XCTAssertEqual(a.place.x, b.place.x)
            XCTAssertEqual(a.place.y, b.place.y, accuracy: 0.013, "Licking up, held where it was")
        }
        let theirs = Self.flames(stage.torches([two], dark: [], near: one.position, scale: 60, time: 3))
        XCTAssertNotEqual(now.map(\.colour.x), theirs.map(\.colour.x), "Each company's in its own time")
        for time in stride(from: Float(0), to: 3, by: 0.1) {
            let flames = Self.flames(stage.torches([one], dark: [], near: one.position, scale: 60, time: time))
            XCTAssertTrue(flames.allSatisfy { $0.colour.x > 0.8 }, "Never out")
            let still = stage.torches([one], dark: [], near: one.position, scale: 60, time: time, still: true)
            XCTAssertEqual(still, stage.torches([one], dark: [], near: one.position, scale: 60, time: 0, still: true), "Steady")
        }
    }

    func testOnlyTheNearestCompaniesBearTorchesInAFrame() throws {
        let stage = stage()
        let ground = land
        let count = WorldStage.mostTorchBearers + 12
        XCTAssertGreaterThanOrEqual(ground.count, count)
        let focusHex = try XCTUnwrap(ground.first)
        let centre = Relief.centre(of: focusHex), focus = Vec3(centre.x, 0, centre.z)
        let poses = ground.prefix(count).enumerated().map { company($0.offset, at: $0.element, stage: stage) }
        let motes = stage.torches(poses, dark: [], near: focus, scale: 60, time: 3)
        XCTAssertEqual(motes.count, WorldStage.mostTorchBearers * 4)
        func away(_ pose: CompanyPose) -> Float {
            (pose.position.x - focus.x) * (pose.position.x - focus.x) + (pose.position.z - focus.z) * (pose.position.z - focus.z)
        }
        let nearest = poses.sorted { (away($0), $0.unit) < (away($1), $1.unit) }.prefix(WorldStage.mostTorchBearers)
        XCTAssertEqual(motes, stage.torches(Array(nearest), dark: [], near: focus, scale: 60, time: 3), "The nearest to the view")
    }
}
