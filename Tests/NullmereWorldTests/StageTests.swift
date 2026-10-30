import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The world's models gathered for a frame: the land's furniture laid out
/// once and again only where it changed, holds with their works rising
/// under scaffolds, companies in formation on the land under their feet,
/// and what flies over them.
final class StageTests: XCTestCase {
    private static let state = GameState(settings: GameSettings(seedText: "stage", houseCount: 4, radius: 12, keepers: 1))
    private static let relief = Relief(map: state.map)

    private func stage() -> WorldStage {
        WorldStage(map: Self.state.map, relief: Self.relief)
    }

    private func count(_ batches: [ModelBatch]) -> Int {
        batches.reduce(0) { $0 + $1.instances.count }
    }

    func testTheLandIsFurnishedOnceAndClearedWhereACompanyStands() throws {
        let stage = stage()
        let started = Date()
        let all = stage.furnish(occupied: [], holds: [])
        print("STAGE furniture \(count(all)) pieces in \(String(format: "%.1f", Date().timeIntervalSince(started) * 1000)) ms")
        XCTAssertGreaterThan(count(all), Self.state.map.count / 2, "most of the land has something on it")
        for batch in all {
            guard case .furnishing = batch.key else { return XCTFail("only the land's furniture: \(batch.key)") }
            XCTAssertEqual(Library.model(batch.key).rig.count, 1, "furniture sways in the shader, not by its parts")
            XCTAssertTrue(batch.instances.allSatisfy { $0.palette == 0 && $0.colour.w == 0 && $0.flags == 0 })
        }
        XCTAssertEqual(stage.furnish(occupied: [], holds: []), all, "kept, not laid out again")
        XCTAssertEqual(stage.furnitureVersion, 1)

        // A company comes to a wooded hex: its heart is cleared, and nothing else moves.
        let wooded = try XCTUnwrap(Self.state.map.hexes.first { hex in
            Scatter.pieces(in: hex, map: Self.state.map, relief: Self.relief).contains {
                let centre = Relief.centre(of: hex)
                let p = $0.position
                return ((p.x - centre.x) * (p.x - centre.x) + (p.z - centre.z) * (p.z - centre.z)).squareRoot() < Scatter.heart
            }
        })
        let cleared = stage.furnish(occupied: [wooded], holds: [])
        XCTAssertEqual(stage.furnitureVersion, 2, "laid out again, and sent again")
        let centre = Relief.centre(of: wooded)
        for instance in cleared.flatMap(\.instances) where instance.hex == SIMD2(Int32(wooded.q), Int32(wooded.r)) {
            let p = instance.model.c3
            XCTAssertGreaterThanOrEqual(((p.x - centre.x) * (p.x - centre.x) + (p.z - centre.z) * (p.z - centre.z)).squareRoot(),
                                        Scatter.heart - 0.001)
        }
        let others = { (batches: [ModelBatch]) in
            batches.flatMap(\.instances).filter { $0.hex != SIMD2(Int32(wooded.q), Int32(wooded.r)) }.map(\.model.c3)
        }
        XCTAssertEqual(Set(others(cleared).map { "\($0)" }), Set(others(all).map { "\($0)" }), "every other hex as it was")
        // And when it goes, the hex is as it was before.
        XCTAssertEqual(count(stage.furnish(occupied: [], holds: [])), count(all))

        // A hold founded: the ground round it is bare.
        let seat = try XCTUnwrap(Self.state.holds.first)
        let round = stage.furnish(occupied: [], holds: [seat.position])
        XCTAssertLessThan(count(round), count(all))
        let heart = Relief.centre(of: seat.position)
        for instance in round.flatMap(\.instances) {
            let p = instance.model.c3
            XCTAssertGreaterThan(((p.x - heart.x) * (p.x - heart.x) + (p.z - heart.z) * (p.z - heart.z)).squareRoot(), HoldLayout.reach - 0.01)
        }
    }

    func testHoldsStandInTheirHousesColoursWithTheirWorksRising() throws {
        let stage = stage()
        var hold = try XCTUnwrap(Self.state.holds.first { $0.isSeat })
        hold.levels[.walls] = 2
        hold.levels[.granary] = 1
        let red = Vec4(0.8, 0.1, 0.1, 1)
        var frame = SceneFrame()
        let (whole, hearths) = stage.holds([HoldSight(hold: hold, colour: red)], time: 3, into: &frame)
        let keys = Set(whole.map(\.key))
        XCTAssertTrue(keys.contains(.keep(seat: true)))
        XCTAssertTrue(keys.contains(.walls(level: 2)))
        XCTAssertTrue(keys.contains(.work(.granary, level: 1)))
        XCTAssertFalse(keys.contains(.scaffold), "nothing is being raised")
        for instance in whole.flatMap(\.instances) {
            XCTAssertEqual(instance.colour, red)
            XCTAssertEqual(instance.params.x, WorldStage.whole, "whole")
        }
        XCTAssertFalse(hearths.isEmpty, "the keep's hall smokes")
        XCTAssertTrue(hearths.allSatisfy { $0.point.y > Relief.waterline })
        XCTAssertEqual(stage.pieces(of: hold, progress: nil), stage.pieces(of: hold, progress: nil), "laid out once")

        // A sawpit begun: it rises under its scaffold, a little more as the watches pass.
        hold.project = try JSONDecoder().decode(Hold.Project.self, from: Data(#"{"kind":"sawpit","targetLevel":1,"watchesLeft":2}"#.utf8))
        var rising = SceneFrame()
        let begun = stage.holds([HoldSight(hold: hold, colour: red, progress: 0.25)], time: 3, into: &rising).batches
        let sawpit = try XCTUnwrap(begun.first { $0.key == .work(.sawpit, level: 1) }?.instances.first)
        XCTAssertLessThan(sawpit.params.x, WorldStage.whole)
        XCTAssertEqual(begun.first { $0.key == .scaffold }?.instances.count, 1)
        let later = stage.holds([HoldSight(hold: hold, colour: red, progress: 0.75)], time: 3, into: &rising).batches
        let higher = try XCTUnwrap(later.first { $0.key == .work(.sawpit, level: 1) }?.instances.first)
        XCTAssertGreaterThan(higher.params.x, sawpit.params.x)

        // Finished, it rises its last stretch before it stands whole, and smokes only then.
        hold.project = nil
        hold.levels[.sawpit] = 1
        let last = HoldLayout.Plan.Rising(work: .building(.sawpit), level: 1, progress: 0.9)
        let finishing = stage.holds([HoldSight(hold: hold, colour: red, finishing: last)], time: 3, into: &rising).batches
        let almost = try XCTUnwrap(finishing.first { $0.key == .work(.sawpit, level: 1) }?.instances.first)
        XCTAssertGreaterThan(almost.params.x, higher.params.x)
        XCTAssertLessThan(almost.params.x, WorldStage.whole)
        let done = stage.holds([HoldSight(hold: hold, colour: red)], time: 3, into: &rising).batches
        XCTAssertEqual(done.first { $0.key == .work(.sawpit, level: 1) }?.instances.first?.params.x, WorldStage.whole)
        XCTAssertNil(done.first { $0.key == .scaffold })
    }

    func testCompaniesStandInFormationOnTheLandUnderEachFigure() throws {
        let unit = try XCTUnwrap(Self.state.units.first { $0.kind == .spear })
        let centre = Relief.centre(of: unit.position)
        let at = Vec3(centre.x, Self.relief.height(of: unit.position), centre.z)
        func company(health: Int, heading: Float = 0, clip: Clip = .idle, time: Float = 0, commander: Int? = nil, spread: Float = 1)
            -> CompanyPose {
            CompanyPose(unit: unit.id, key: .figure(.spear, tier: 2), sigil: 1, health: health, hex: unit.position, position: at,
                        heading: heading, clip: clip, clipTime: time, isOwn: true, commander: commander, spread: spread)
        }
        let houses = [Vec4(1, 0, 0, 1), Vec4(0, 0, 1, 1)]
        var frame = SceneFrame()
        let full = stage().companies([company(health: 100)], houses: houses, into: &frame)
        XCTAssertEqual(full.map(\.key), [.figure(.spear, tier: 2)])
        let figures = try XCTUnwrap(full.first).instances
        XCTAssertEqual(figures.count, Formation.count(.figure(.spear, tier: 2), health: 100))
        for figure in figures {
            let p = figure.model.c3
            XCTAssertEqual(p.y, max(Self.relief.height(atX: p.x, z: p.z), Relief.waterline), accuracy: 1e-4, "on the land under it")
            XCTAssertEqual(figure.colour, Vec4(0, 0, 1, 1), "its House's colour, by sigil")
            XCTAssertEqual(figure.flags, ModelInstance.alwaysShown)
            XCTAssertGreaterThan(figure.palette, 0, "posed")
        }
        // Worn down, it shows fewer; led, its commander rides at its head.
        var worn = SceneFrame()
        XCTAssertLessThan(count(stage().companies([company(health: 30)], houses: houses, into: &worn)), figures.count)
        var led = SceneFrame()
        let withLeader = stage().companies([company(health: 100, commander: 3)], houses: houses, into: &led)
        XCTAssertEqual(withLeader.first { $0.key == .commander(variant: 3) }?.instances.count, 1)
        // Turned about, the formation turns with it.
        var turned = SceneFrame()
        let about = stage().companies([company(health: 100, heading: .pi)], houses: houses, into: &turned)
        let front = figures[0].model.c3, back = try XCTUnwrap(about.first?.instances.first).model.c3
        XCTAssertEqual(front.x - at.x, -(back.x - at.x), accuracy: 1e-3)
        XCTAssertEqual(front.z - at.z, -(back.z - at.z), accuracy: 1e-3)
        // Drawn up small within a hold's walls.
        var small = SceneFrame()
        let within = stage().companies([company(health: 100, spread: 0.3)], houses: houses, into: &small)
        let spread = { (instances: [ModelInstance]) in instances.map { ($0.model.c3.x - at.x).magnitude }.max() ?? 0 }
        XCTAssertLessThan(spread(try XCTUnwrap(within.first).instances), spread(figures) * 0.31)
    }

    func testSitesFillTheirHexesHearts() {
        let stage = stage()
        let hexes = Array(Self.state.map.hexes.filter { Self.state.map[$0]?.terrain.isPassable == true }.prefix(4))
        let batches = stage.sites(zip(Resource.allCases, hexes).map { ($0, $1) })
        XCTAssertEqual(Set(batches.map(\.key)), Set(Resource.allCases.map { ModelKey.site($0) }))
        for (batch, hex) in zip(batches, hexes) {
            let instance = try! XCTUnwrap(batch.instances.first)
            let centre = Relief.centre(of: hex)
            XCTAssertEqual(instance.model.c3.x, centre.x, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.z, centre.z, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.y, stage.ground(atX: centre.x, z: centre.z) - Scatter.sink, accuracy: 1e-4)
            XCTAssertEqual(instance.hex, SIMD2(Int32(hex.q), Int32(hex.r)), "shown where the keeper knows its hex")
        }
        XCTAssertTrue(stage.sites([]).isEmpty)
    }

    func testHolySitesStandInTheirHexesHeartsInTheirHoldersColours() throws {
        let stage = stage()
        let hexes = Array(Self.state.map.hexes.filter { Self.state.map[$0]?.terrain.isPassable == true }.prefix(3))
        let red = Vec4(0.8, 0.1, 0.1, 1)
        let batches = stage.shrines([(.moonwell, hexes[0], red), (.stillStone, hexes[1], nil), (.moonwell, hexes[2], nil)])
        XCTAssertEqual(batches.map(\.key), [.shrine(.moonwell), .shrine(.stillStone)], "One batch a kind, in the order first met")
        let moonwells = try XCTUnwrap(batches.first).instances
        XCTAssertEqual(moonwells.count, 2)
        XCTAssertEqual(moonwells[0].colour, red, "Its holder's colour")
        XCTAssertEqual(moonwells[1].colour, .zero, "Grey while none holds it")
        for (instance, hex) in zip(moonwells, [hexes[0], hexes[2]]) {
            let centre = Relief.centre(of: hex)
            XCTAssertEqual(instance.model.c3.x, centre.x, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.z, centre.z, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.y, stage.ground(atX: centre.x, z: centre.z) - Scatter.sink, accuracy: 1e-4)
            XCTAssertEqual(instance.hex, SIMD2(Int32(hex.q), Int32(hex.r)))
        }
        XCTAssertTrue(stage.shrines([]).isEmpty)
    }

    func testFirefliesWanderOverTheReedsAndGrassNearest() {
        let stage = stage()
        _ = stage.furnish(occupied: [], holds: [])
        let focus = Vec3(0, 0, 0)
        let spots = stage.fireflySpots(near: focus, within: 6, most: 4)
        XCTAssertLessThanOrEqual(spots.count, 4)
        XCTAssertFalse(spots.isEmpty, "Reeds or grass somewhere near the lake's heart")
        let layout = HexLayout(size: 1)
        for spot in spots {
            let hex = layout.hex(atX: Double(spot.x), y: Double(spot.z))
            XCTAssertLessThanOrEqual(hex.distance(to: .origin), 6, "Within reach")
        }
        XCTAssertLessThanOrEqual(stage.fireflySpots(near: focus, within: 6, most: 1).count, 1)
    }

    func testACompanyEasesOutOfItsLastClipFigureByFigure() throws {
        let unit = try XCTUnwrap(Self.state.units.first { $0.kind == .spear })
        let centre = Relief.centre(of: unit.position)
        let at = Vec3(centre.x, Self.relief.height(of: unit.position), centre.z)
        func company(_ blend: CompanyPose.Blend?) -> CompanyPose {
            CompanyPose(unit: unit.id, key: .figure(.spear, tier: 1), sigil: 0, health: 100, hex: unit.position, position: at,
                        heading: 0, clip: .march, clipTime: 0.4, isOwn: true, blend: blend)
        }
        var plain = SceneFrame(), eased = SceneFrame()
        _ = stage().companies([company(nil)], houses: [], into: &plain)
        _ = stage().companies([company(CompanyPose.Blend(clip: .idle, time: 0.2, weight: 0.6))], houses: [], into: &eased)
        XCTAssertNotEqual(plain.palette, eased.palette, "Still part in the clip it leaves")
        var leavingOnce = SceneFrame()
        _ = stage().companies([company(CompanyPose.Blend(clip: .attack, time: 0.1, weight: 0.5))], houses: [], into: &leavingOnce)
        XCTAssertNotEqual(leavingOnce.palette, eased.palette, "Out of a strike, not out of standing")
    }

    func testTheArchiveStandsAsTheStudy() {
        XCTAssertEqual(ModelKey.work(.archive, level: 3).canonical, .study(level: 3))
        XCTAssertEqual(HoldLayout.Work(.archive), .study)
        XCTAssertEqual(HoldLayout.Work(.granary), .building(.granary))
        XCTAssertFalse(Library.catalogue.contains(.work(.archive, level: 1)), "its models are the study's")
    }

    func testTheLandUnderFiguresIsWorkedOutOnce() {
        let stage = stage()
        let first = stage.ground(atX: 1.3, z: -2.2)
        XCTAssertEqual(first, max(Self.relief.height(atX: 1.3, z: -2.2), Relief.waterline))
        XCTAssertEqual(stage.ground(atX: 1.304, z: -2.2), first, "a step too small to matter shares it")
        // However many points are asked after, the kept heights stay few.
        for i in 0..<60_002 {
            _ = stage.ground(atX: Float(i % 300) / 7, z: Float(i / 300) / 7)
        }
        XCTAssertEqual(stage.ground(atX: 1.3, z: -2.2), first, accuracy: 1e-6)
    }

    func testFiguresAtOneMomentShareTheirPose() {
        var frame = SceneFrame()
        var shared: [WorldStage.PoseKey: UInt32] = [:]
        let key = ModelKey.figure(.bow, tier: 1)
        let first = WorldStage.pose(key, .march, at: 0.25, shared: &shared, into: &frame)
        XCTAssertEqual(WorldStage.pose(key, .march, at: 0.25, shared: &shared, into: &frame), first)
        XCTAssertEqual(WorldStage.pose(key, .march, at: 1.25, shared: &shared, into: &frame), first, "a looping clip, a period on")
        XCTAssertNotEqual(WorldStage.pose(key, .march, at: 0.5, shared: &shared, into: &frame), first)
        let fallen = WorldStage.pose(key, .death, at: 9, shared: &shared, into: &frame)
        XCTAssertEqual(WorldStage.pose(key, .death, at: 30, shared: &shared, into: &frame), fallen, "the dead lie still")
        XCTAssertEqual(frame.palette.count, 1 + 3 * Library.model(key).rig.count)
    }

    func testMarchesAndArrowsFollowTheirWays() throws {
        let march = MarchPath(path: [Hex(0, 0), Hex(1, 0), Hex(2, 0)], duration: 2)
        XCTAssertNil(march.point(after: -0.1))
        XCTAssertNil(march.point(after: 2), "there")
        let start = try XCTUnwrap(march.point(after: 0))
        XCTAssertEqual(start.x, Relief.centre(of: Hex(0, 0)).x, accuracy: 1e-5)
        let middle = try XCTUnwrap(march.point(after: 1))
        XCTAssertEqual(middle.x, Relief.centre(of: Hex(1, 0)).x, accuracy: 1e-3)
        XCTAssertEqual(middle.heading, .pi / 2, accuracy: 1e-4, "east")
        XCTAssertNil(MarchPath(path: [Hex(0, 0)], duration: 1).point(after: 0.5))
        XCTAssertEqual(CompanyPose.heading(from: Hex(0, 0), to: Hex(0, 0)), 0)

        let arrow = ArrowFlight(from: Vec3(0, 0, 0), to: Vec3(4, 0, 0), progress: 0)
        XCTAssertEqual(arrow.transform.c3.x, 0, accuracy: 1e-5)
        var landing = arrow
        landing.progress = 1
        XCTAssertEqual(landing.transform.c3.x, 4, accuracy: 1e-4)
        XCTAssertEqual(landing.transform.c3.y, 0, accuracy: 1e-4)
        var aloft = arrow
        aloft.progress = 0.5
        XCTAssertGreaterThan(aloft.transform.c3.y, 0.3, "it arcs")
        // Nose up as it rises, down as it falls.
        var rising = arrow, falling = arrow
        rising.progress = 0.1
        falling.progress = 0.9
        XCTAssertGreaterThan(rising.transform.transformDirection(Vec3(0, 0, 1)).y, 0)
        XCTAssertLessThan(falling.transform.transformDirection(Vec3(0, 0, 1)).y, 0)
    }

    func testArrowsBirdsAndSmokeFly() {
        var frame = SceneFrame()
        let arrows = [ArrowFlight(from: .zero, to: Vec3(3, 0, 0), progress: 0.5), ArrowFlight(from: .zero, to: Vec3(3, 0, 0), progress: 1.5)]
        let hearths = [Hearth(point: Vec3(1, 1, 1), hex: Hex(2, -1)), Hearth(point: Vec3(5, 1, 1), hex: Hex(4, -1))]
        let flown = WorldStage.flights(arrows: arrows, birdsOver: Vec3(0, 0, 0), hearths: hearths, time: 1.3, into: &frame)
        XCTAssertEqual(flown.first { $0.key == .prop(.arrow) }?.instances.count, 1, "only arrows in flight")
        let birds = flown.first { $0.key == .prop(.bird) }?.instances ?? []
        XCTAssertEqual(birds.count, 5)
        XCTAssertTrue(birds.allSatisfy { $0.flags == ModelInstance.alwaysShown && $0.model.c3.y > 1 })
        let puffs = flown.first { $0.key == .prop(.puff) }?.instances ?? []
        XCTAssertEqual(puffs.map(\.hex), [SIMD2(2, -1), SIMD2(4, -1)], "smoke shows where its hold is known")
        XCTAssertTrue(puffs.allSatisfy { $0.params.y > 0 && $0.params.y <= 0.85 })
        // The birds wheel: a moment later they are elsewhere.
        var later = SceneFrame()
        let moved = WorldStage.flights(arrows: [], birdsOver: .zero, hearths: [], time: 4, into: &later)
        XCTAssertNotEqual(moved.first?.instances.first?.model, birds.first?.model)
        var none = SceneFrame()
        XCTAssertTrue(WorldStage.flights(arrows: [], birdsOver: nil, hearths: [], time: 0, into: &none).isEmpty)
    }

    func testModelsStandAsHighAsTheMapsPlatesExpect() {
        // The map's plates (names, bars) sit just above these heights.
        let keep = Library.model(.keep(seat: false)).mesh.bounds.max.y
        let seat = Library.model(.keep(seat: true)).mesh.bounds.max.y
        let figures = UnitKind.allCases.map { Library.model(.figure($0, tier: ModelKey.tiers(of: $0))).mesh.bounds.max.y }
        print("STAGE heights keep \(keep) seat \(seat) figures \(figures)")
        XCTAssertLessThan(keep, 1.1)
        XCTAssertLessThan(seat, 1.6, "the seat's banner flies higher")
        XCTAssertTrue(figures.allSatisfy { $0 < 0.9 }, "the lantern's pole the tallest")
    }

    func testBatchesKeepTheirOrderAndColoursTheirHouses() {
        let placed: [(ModelKey, ModelInstance)] = [(.work(.walls, level: 2), ModelInstance(model: .identity)),
                                                   (.scaffold, ModelInstance(model: .identity)),
                                                   (.walls(level: 2), ModelInstance(model: .identity))]
        let batches = WorldStage.batches(placed)
        XCTAssertEqual(batches.map(\.key), [.walls(level: 2), .scaffold], "a work's walls are the walls")
        XCTAssertEqual(batches.first?.instances.count, 2)
        XCTAssertEqual(WorldStage.colour([], sigil: 3), Vec4(0.6, 0.6, 0.6, 1))
        XCTAssertEqual(WorldStage.colour([Vec4(1, 0, 0, 1), Vec4(0, 1, 0, 1)], sigil: -1), Vec4(0, 1, 0, 1))
        XCTAssertNotEqual(WorldStage.phase(of: Hex(1, 2), salt: 1), WorldStage.phase(of: Hex(2, 1), salt: 1))
    }
}
