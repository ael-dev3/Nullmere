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

    /// Detail thins the land's furniture: about half of it at a half
    /// share, always the same pieces, none at none; laid out again as the
    /// share changes, and whole again at a whole one.
    func testDetailThinsTheLandsFurniture() {
        let stage = stage()
        let all = stage.furnish(occupied: [], holds: [])
        stage.furnitureShare = 1
        XCTAssertEqual(stage.furnitureVersion, 1, "No change, nothing laid out again")
        stage.furnitureShare = 0.5
        let half = stage.furnish(occupied: [], holds: [])
        XCTAssertEqual(stage.furnitureVersion, 2, "Laid out again at the new share")
        let share = Double(count(half)) / Double(count(all))
        XCTAssertEqual(share, 0.5, accuracy: 0.1, "About half: \(count(half)) of \(count(all))")
        let kept = Set(all.flatMap(\.instances).map { "\($0.model)" })
        XCTAssertTrue(half.flatMap(\.instances).allSatisfy { kept.contains("\($0.model)") }, "Only pieces the whole land has")
        XCTAssertEqual(WorldStage(map: Self.state.map, relief: Self.relief).thinned(0.5), half, "Always the same pieces")
        stage.furnitureShare = 0
        let none = stage.furnish(occupied: [], holds: [])
        XCTAssertTrue(none.allSatisfy { if case .furnishing(let piece) = $0.key { return piece.isLandmark } else { return false } },
                      "None of the growth at none")
        XCTAssertEqual(count(none), count(all.filter { if case .furnishing(let piece) = $0.key { return piece.isLandmark } else { return false } }),
                       "The landmarks all kept")
        stage.furnitureShare = 1
        XCTAssertEqual(stage.furnish(occupied: [], holds: []), all, "Whole again")
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

        // A company comes to a wooded hex: whatever would rise among its
        // ranks gives way, in its hex and the edges of those beside it, and
        // nothing moves; what lies underfoot stays (run 753's battle had
        // firs standing through its formations).
        let map = Self.state.map
        let wooded = try XCTUnwrap(map.hexes.first { hex in
            map[hex]?.terrain == .blackwood && hex.neighbors.allSatisfy { map[$0]?.terrain == .blackwood }
        }, "A blackwood hex in the blackwood")
        let cleared = stage.furnish(occupied: [wooded], holds: [])
        XCTAssertEqual(stage.furnitureVersion, 2, "laid out again, and sent again")
        let centre = Relief.centre(of: wooded)
        func reach(_ instance: ModelInstance) -> Float {
            let p = instance.model.c3
            return ((p.x - centre.x) * (p.x - centre.x) + (p.z - centre.z) * (p.z - centre.z)).squareRoot()
        }
        func ground(_ furnishing: Furnishing, _ instance: ModelInstance) -> Float {
            let c = instance.model.c0
            return Scatter.held + Scatter.footprint(furnishing) * (c.x * c.x + c.y * c.y + c.z * c.z).squareRoot()
        }
        let stood = Set(all.flatMap(\.instances).map { "\($0.model.c3)" })
        XCTAssertTrue(cleared.flatMap(\.instances).allSatisfy { stood.contains("\($0.model.c3)") }, "nothing moves")
        for batch in cleared {
            guard case .furnishing(let furnishing) = batch.key, Scatter.height(furnishing) > Scatter.underfoot else { continue }
            for instance in batch.instances {
                XCTAssertGreaterThanOrEqual(reach(instance), ground(furnishing, instance) - 0.001, "\(furnishing) clear of its ranks")
            }
        }
        let standing = Set(cleared.flatMap(\.instances).map { "\($0.model.c3)" })
        var gave = 0
        for batch in all {
            guard case .furnishing(let furnishing) = batch.key else { continue }
            for instance in batch.instances where !standing.contains("\(instance.model.c3)") {
                // What rose in its ranks' way, or stood in the heart of its hex, where it and its leader stand.
                let c = instance.model.c0
                let heart = Scatter.heart + Scatter.footprint(furnishing) * (c.x * c.x + c.y * c.y + c.z * c.z).squareRoot()
                let inHeart = instance.hex == SIMD2(Int32(wooded.q), Int32(wooded.r)) && reach(instance) < heart + 0.001
                let inWay = Scatter.height(furnishing) > Scatter.underfoot && reach(instance) < ground(furnishing, instance) + 0.001
                XCTAssertTrue(inHeart || inWay, "only what stood in its way: \(furnishing) at \(reach(instance))")
                gave += 1
            }
        }
        XCTAssertGreaterThan(gave, 0, "the firs in its way give way")
        XCTAssertTrue(cleared.contains { batch in
            guard case .furnishing(let furnishing) = batch.key, Scatter.height(furnishing) <= Scatter.underfoot else { return false }
            return batch.instances.contains { reach($0) < Scatter.held }
        }, "ferns and pebbles stay underfoot")
        // And when it goes, the land is as it was before.
        XCTAssertEqual(stage.furnish(occupied: [], holds: []), all)
        // At half the Detail, a company changes nothing beyond its ground:
        // what was kept elsewhere is kept still.
        stage.furnitureShare = 0.5
        let half = stage.furnish(occupied: [], holds: []).flatMap(\.instances)
        let halfHeld = stage.furnish(occupied: [wooded], holds: []).flatMap(\.instances)
        let halfStood = Set(half.map { "\($0.model.c3)" }), halfStanding = Set(halfHeld.map { "\($0.model.c3)" })
        XCTAssertTrue(halfStanding.isSubset(of: halfStood), "Nothing moves or comes at half")
        for instance in half where !halfStanding.contains("\(instance.model.c3)") {
            XCTAssertLessThan(reach(instance), Scatter.held + 0.5, "Only what stood in its way gives way at half")
        }
        stage.furnitureShare = 1
        XCTAssertEqual(stage.furnish(occupied: [], holds: []), all)

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

    /// A forge at work throws its firelight on its yard when the eye is
    /// near, flickering; far off, none.
    func testAForgeAtWorkLightsItsYard() throws {
        let stage = stage()
        var hold = try XCTUnwrap(Self.state.holds.first { $0.isSeat })
        hold.levels[.forge] = 3
        var frame = SceneFrame()
        _ = stage.holds([HoldSight(hold: hold, colour: Vec4(0.8, 0.1, 0.1, 1))], time: 3, into: &frame)
        let heart = Relief.centre(of: hold.position)
        let near = stage.forgeFires(near: Vec3(heart.x, 0, heart.z), time: 1)
        XCTAssertEqual(near.count, 1, "the forge lit")
        XCTAssertGreaterThan(near[0].colour.x, near[0].colour.z, "fire-warm")
        XCTAssertNotEqual(near[0].colour, stage.forgeFires(near: Vec3(heart.x, 0, heart.z), time: 1.37)[0].colour, "flickering")
        XCTAssertTrue(stage.forgeFires(near: Vec3(heart.x + 40, 0, heart.z), time: 1).isEmpty, "none far off")
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

        // Its House's people raise their own keep, its hall smoking as any.
        var theirs = SceneFrame()
        let built = stage.holds([HoldSight(hold: hold, colour: red, heritage: .moundClans)], time: 3, into: &theirs)
        let raised = Set(built.batches.map(\.key))
        XCTAssertTrue(raised.contains(.keepOf(.moundClans, seat: true)))
        XCTAssertFalse(raised.contains(.keep(seat: true)))
        XCTAssertEqual(built.hearths.count, hearths.count, "its hall smokes as the common keep's does")
        XCTAssertEqual(stage.pieces(of: hold, progress: nil, heritage: .moundClans).first?.key, .keepOf(.moundClans, seat: true))

        // Its works, walls and town are built in its people's way; its keep
        // is theirs already. A House whose people are unknown builds the
        // common way.
        let clans = WorldStage.peopleFlags(.moundClans)
        for batch in built.batches {
            for instance in batch.instances {
                switch batch.key {
                case .work, .walls, .town: XCTAssertEqual(instance.flags, clans, "\(batch.key) is built the Mound Clans' way")
                default: XCTAssertEqual(instance.flags, 0, "\(batch.key) is as it is")
                }
            }
        }
        XCTAssertTrue(whole.flatMap(\.instances).allSatisfy { $0.flags == 0 })
    }

    func testEachPeopleIsMarkedForTheShaderInTheSecondByte() {
        XCTAssertEqual(WorldStage.peopleFlags(nil), 0)
        let marks = Heritage.allCases.map(WorldStage.peopleFlags)
        XCTAssertEqual(marks.map { $0 >> 8 }, Array(1...UInt32(Heritage.allCases.count)), "one more than each people's place")
        XCTAssertTrue(marks.allSatisfy { $0 & 0xFF == 0 && $0 & ModelInstance.alwaysShown == 0 }, "the first byte is left alone")
        // The shader knows each people's roofs and walls, and no more.
        let count = Heritage.allCases.count
        XCTAssertTrue(WorldShaders.source.contains("constant float3 kPeopleRoof[\(count)]"))
        XCTAssertTrue(WorldShaders.source.contains("constant float3 kPeopleWall[\(count)]"))
        XCTAssertTrue(WorldShaders.source.contains("people <= \(count)u"))
        XCTAssertTrue(WorldStage.isPeoples(.study(level: 1)))
        XCTAssertFalse(WorldStage.isPeoples(.scaffold))
        XCTAssertFalse(WorldStage.isPeoples(.keepOf(.saltborn, seat: false)))
    }

    func testCompaniesStandInFormationOnTheLandUnderEachFigure() throws {
        let unit = try XCTUnwrap(Self.state.units.first { $0.kind == .spear })
        let centre = Relief.centre(of: unit.position)
        let at = Vec3(centre.x, Self.relief.height(of: unit.position), centre.z)
        func company(health: Int, heading: Float = 0, clip: Clip = .idle, time: Float = 0, commander: Int? = nil, spread: Float = 1,
                     muster: Int = 100) -> CompanyPose {
            CompanyPose(unit: unit.id, key: .figure(.spear, tier: 2), sigil: 1, health: health, hex: unit.position, position: at,
                        heading: heading, clip: clip, clipTime: time, isOwn: true, commander: commander, spread: spread, muster: muster)
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
        // Worn down, it shows fewer; drilled, more; led, its commander rides at its head.
        var worn = SceneFrame()
        XCTAssertLessThan(count(stage().companies([company(health: 30)], houses: houses, into: &worn)), figures.count)
        var drilled = SceneFrame()
        let host = stage().companies([company(health: 100, commander: 2, muster: 900)], houses: houses, into: &drilled)
        XCTAssertEqual(host.first { $0.key == .figure(.spear, tier: 2) }?.instances.count, Formation.strength(.figure(.spear, tier: 2), muster: 900))
        XCTAssertGreaterThan(Formation.strength(.figure(.spear, tier: 2), muster: 900), figures.count)
        XCTAssertEqual(host.first { $0.key == .commander(variant: 2) }?.instances.count, 1)
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

    func testLairsStandInTheirHexesHeartsAndTheirFiresSmoke() throws {
        let stage = stage()
        let hexes = Array(Self.state.map.hexes.filter { Self.state.map[$0]?.terrain.isPassable == true }.prefix(3))
        let (batches, hearths) = stage.lairs([(.reavers, hexes[0]), (.barrowkin, hexes[1]), (.reavers, hexes[2])])
        XCTAssertEqual(batches.map(\.key), [.lair(.reavers), .lair(.barrowkin)])
        XCTAssertEqual(batches.first?.instances.count, 2)
        for (instance, hex) in zip(try XCTUnwrap(batches.first).instances, [hexes[0], hexes[2]]) {
            let centre = Relief.centre(of: hex)
            XCTAssertEqual(instance.model.c3.x, centre.x, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.z, centre.z, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.y, stage.ground(atX: centre.x, z: centre.z) - Scatter.sink, accuracy: 1e-4)
            XCTAssertEqual(instance.colour, .zero, "No House's")
        }
        XCTAssertEqual(hearths.map(\.hex), [hexes[0], hexes[2]], "The Reavers' fires smoke; the barrow's cold light doesn't")
        for (hearth, hex) in zip(hearths, [hexes[0], hexes[2]]) {
            let centre = Relief.centre(of: hex)
            XCTAssertLessThan(Vec3(hearth.point.x - centre.x, 0, hearth.point.z - centre.z).length, 0.2, "From its fire, by its heart")
            XCTAssertGreaterThan(hearth.point.y, stage.ground(atX: centre.x, z: centre.z) - Scatter.sink)
        }
        XCTAssertTrue(stage.lairs([]).batches.isEmpty)
    }

    /// The Crown's gates stand across their passes, each turned so its way
    /// through runs toward the Crown's heart, and their fires smoke.
    func testTheCrownsGatesStandAcrossTheirPassesTurnedToTheHeart() throws {
        let stage = stage()
        let gates = [Hex(4, 0), Hex(-4, 4), Hex(0, -4)]
        let (batches, hearths) = stage.gates(gates)
        XCTAssertEqual(batches.map(\.key), [.gatehold])
        let instances = try XCTUnwrap(batches.first).instances
        XCTAssertEqual(instances.count, 3)
        for (instance, hex) in zip(instances, gates) {
            let centre = Relief.centre(of: hex), heart = Relief.centre(of: .origin)
            XCTAssertEqual(instance.model.c3.x, centre.x, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.z, centre.z, accuracy: 1e-4)
            // Its own z, the way through, runs out from the heart.
            let through = Vec3(instance.model.c2.x, 0, instance.model.c2.z)
            let out = Vec3(centre.x - heart.x, 0, centre.z - heart.z)
            XCTAssertGreaterThan((through.x * out.x + through.z * out.z) / out.length, 0.99, "Turned to the heart at \(hex)")
        }
        XCTAssertEqual(hearths.map(\.hex), gates, "Each its fire")
        XCTAssertTrue(stage.gates([]).batches.isEmpty)
    }

    func testStandardsStandInTheirHexesInTheirAlliancesColours() throws {
        let stage = stage()
        let hexes = Array(Self.state.map.hexes.filter { Self.state.map[$0]?.terrain.isPassable == true }.prefix(2))
        let blue = Vec4(0.1, 0.2, 0.9, 1), gold = Vec4(0.8, 0.7, 0.2, 1)
        let batches = stage.standards([(hexes[0], blue, 1), (hexes[1], gold, 1)])
        XCTAssertEqual(batches.map(\.key), [.standard])
        let instances = try XCTUnwrap(batches.first).instances
        XCTAssertEqual(instances.map(\.colour), [blue, gold])
        for (instance, hex) in zip(instances, hexes) {
            let centre = Relief.centre(of: hex)
            XCTAssertEqual(instance.model.c3.x, centre.x, accuracy: 1e-4)
            XCTAssertEqual(instance.model.c3.z, centre.z, accuracy: 1e-4)
            XCTAssertEqual(instance.hex, SIMD2(Int32(hex.q), Int32(hex.r)))
        }
        XCTAssertTrue(stage.standards([]).isEmpty)
        // One rising: drawn up its pole as far as it has come, in a scaffold.
        let rising = stage.standards([(hexes[0], blue, 0.5)])
        XCTAssertEqual(Set(rising.map(\.key)), [.standard, .scaffold])
        let half = try XCTUnwrap(rising.first { $0.key == .standard }?.instances.first).params.x
        let bounds = Library.model(.standard).mesh.bounds
        XCTAssertEqual(half, bounds.min.y + 0.6 * (bounds.max.y - bounds.min.y), accuracy: 1e-4)
        let nearly = stage.standards([(hexes[0], blue, 0.9)]).first { $0.key == .standard }?.instances.first
        XCTAssertLessThan(half, try XCTUnwrap(nearly).params.x)
        XCTAssertEqual(instances.first?.params.x, WorldStage.whole, "whole ones stand whole")
    }

    /// A rally gathering pitches its war camp just past its muster's walls,
    /// on the side of its march, its banner in its caller's colour and its
    /// fire smoking.
    func testRallyCampsStandPastTheirMustersTowardTheirTargets() throws {
        let stage = stage()
        let hexes = Array(Self.state.map.hexes.filter { Self.state.map[$0]?.terrain.isPassable == true }.prefix(3))
        let red = Vec4(0.8, 0.1, 0.1, 1)
        let (batches, hearths) = stage.rallyCamps([(muster: hexes[0], target: hexes[2], colour: red)])
        XCTAssertEqual(batches.map(\.key), [.rallyCamp])
        let camp = try XCTUnwrap(batches.first?.instances.first)
        XCTAssertEqual(camp.colour, red)
        XCTAssertEqual(camp.hex, SIMD2(Int32(hexes[0].q), Int32(hexes[0].r)))
        let muster = Relief.centre(of: hexes[0]), target = Relief.centre(of: hexes[2])
        let at = Vec3(camp.model.c3.x - muster.x, 0, camp.model.c3.z - muster.z)
        let way = Vec3(target.x - muster.x, 0, target.z - muster.z)
        XCTAssertEqual(at.length, WorldStage.rallyCampReach, accuracy: 1e-3, "Just past the walls")
        XCTAssertGreaterThan((at.x * way.x + at.z * way.z) / (at.length * way.length), 0.999, "On the side of its march")
        let facing = Vec3(camp.model.c2.x, 0, camp.model.c2.z)
        XCTAssertGreaterThan((facing.x * way.x + facing.z * way.z) / (facing.length * way.length), 0.99, "Turned toward it")
        XCTAssertEqual(hearths.map(\.hex), [hexes[0]], "Its fire smokes")
        XCTAssertTrue(stage.rallyCamps([]).batches.isEmpty)
    }

    /// A rally host on the march goes under its caller's banner, borne
    /// among its leading company, turned as it marches.
    func testHostBannersRideAmongTheirLeadingCompanies() throws {
        let stage = stage()
        let hex = try XCTUnwrap(Self.state.map.hexes.first { Self.state.map[$0]?.terrain.isPassable == true })
        let lead = CompanyPose(unit: 7, key: .figure(.spear, tier: 2), sigil: 1, health: 10, hex: hex,
                               position: Vec3(1.5, 0.2, -2), heading: 0.8, isOwn: false)
        let gold = Vec4(0.8, 0.7, 0.2, 1)
        let batches = stage.hostBanners([(lead: lead, colour: gold)])
        XCTAssertEqual(batches.map { $0.key }, [ModelKey.hostBanner])
        let banner = try XCTUnwrap(batches.first?.instances.first)
        XCTAssertEqual(banner.colour, gold)
        XCTAssertEqual(banner.model.c3.x, 1.5, accuracy: 1e-5)
        XCTAssertEqual(banner.model.c3.y, 0.2, accuracy: 1e-5)
        XCTAssertEqual(banner.model.c3.z, -2, accuracy: 1e-5)
        XCTAssertEqual(banner.model.c2.x, sin(0.8), accuracy: 1e-4, "Turned as it marches")
        XCTAssertTrue(stage.hostBanners([]).isEmpty)
        XCTAssertLessThanOrEqual(Library.model(.hostBanner).mesh.triangleCount, ModelKey.hostBanner.budget)
    }

    /// A commander's leading talents glow on the ground beneath it as its
    /// company marches, in its tree's own sigil, wider the more ranks it
    /// holds; at rest, or untaught, there is none.
    func testTalentSigilsGlowUnderMarchingCommanders() throws {
        let stage = stage()
        let hex = try XCTUnwrap(Self.state.map.hexes.first { Self.state.map[$0]?.terrain.isPassable == true })
        func company(_ clip: Clip, tree: Int, ranks: Int) -> CompanyPose {
            var pose = CompanyPose(unit: 3, key: .figure(.spear, tier: 2), sigil: 0, health: 10, hex: hex,
                                   position: Vec3(Relief.centre(of: hex).x, 0, Relief.centre(of: hex).z), heading: 0.3, clip: clip, isOwn: true, commander: 1)
            pose.talentTree = tree
            pose.talentRanks = ranks
            return pose
        }
        var frame = SceneFrame()
        func sigils(_ pose: CompanyPose) -> [ModelInstance] {
            stage.companies([pose], houses: [Vec4(1, 0, 0, 1)], into: &frame).filter {
                if case .talentSigil = $0.key { return true } else { return false }
            }.flatMap(\.instances)
        }
        let few = sigils(company(.march, tree: 1, ranks: 2)), many = sigils(company(.march, tree: 1, ranks: 20))
        XCTAssertEqual(few.count, 1)
        XCTAssertGreaterThan(Vec3(many[0].model.c0.x, many[0].model.c0.y, many[0].model.c0.z).length,
                             Vec3(few[0].model.c0.x, few[0].model.c0.y, few[0].model.c0.z).length, "Wider with more ranks")
        XCTAssertEqual(stage.companies([company(.march, tree: 0, ranks: 3)], houses: [Vec4(1, 0, 0, 1)], into: &frame)
            .contains { $0.key == .talentSigil(tree: 0) }, true, "Each tree its own sigil")
        XCTAssertTrue(sigils(company(.idle, tree: 1, ranks: 5)).isEmpty, "Only on the march")
        XCTAssertTrue(sigils(company(.march, tree: -1, ranks: 0)).isEmpty, "None untaught")
        XCTAssertLessThan(WorldStage.sigilScale(ranks: 1), WorldStage.sigilScale(ranks: 15))
    }

    /// Each ally that helped a hold's work or muster is a light circling
    /// over its keep, each once however much it helped; a hold unhelped
    /// has none.
    func testHelpCirclesOverTheHoldHelped() throws {
        let stage = stage()
        var hold = try XCTUnwrap(Self.state.holds.first)
        hold.project = nil
        hold.training = nil
        XCTAssertTrue(stage.helpLights([HoldSight(hold: hold, colour: Vec4(1, 1, 1, 1))], time: 0).isEmpty)
        var raised = hold
        var project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 3)
        project.helpers = [2, 4]
        raised.project = project
        var training = Hold.Training(kind: .spear, watchesLeft: 2)
        training.helpers = [4, 5]
        raised.training = training
        let lights = stage.helpLights([HoldSight(hold: raised, colour: Vec4(1, 1, 1, 1))], time: 2).flatMap(\.instances)
        XCTAssertEqual(lights.count, 3, "Each ally once")
        let centre = Relief.centre(of: raised.position)
        for light in lights {
            let off = Vec3(light.model.c3.x - centre.x, 0, light.model.c3.z - centre.z)
            XCTAssertEqual(off.length, WorldStage.helpRadius, accuracy: 1e-3, "Circling the keep")
        }
        let later = stage.helpLights([HoldSight(hold: raised, colour: Vec4(1, 1, 1, 1))], time: 3).flatMap(\.instances)
        XCTAssertNotEqual(later.first?.model.c3.x, lights.first?.model.c3.x, "Turning")
    }

    /// A field of battle has both sides' banners at its heart, apart, each
    /// in its side's colour; the side giving ground leans, the broken
    /// side's lies flat, and the side holding stands.
    func testFieldBannersLeanAsTheirSideGivesGround() throws {
        let stage = stage()
        let hex = try XCTUnwrap(Self.state.map.hexes.first { Self.state.map[$0]?.terrain.isPassable == true })
        let red = Vec4(1, 0, 0, 1), blue = Vec4(0, 0, 1, 1)
        let banners = stage.fieldBanners([(at: hex, colours: [red, blue], shares: [0.8, 0.2])], time: 0).flatMap(\.instances)
        XCTAssertEqual(banners.map(\.colour), [red, blue])
        let centre = Relief.centre(of: hex)
        for banner in banners {
            XCTAssertEqual(Vec3(banner.model.c3.x - centre.x, 0, banner.model.c3.z - centre.z).length, WorldStage.fieldBannerSpread,
                           accuracy: 1e-3)
        }
        func upright(_ banner: ModelInstance) -> Float { banner.model.c1.y }
        XCTAssertGreaterThan(upright(banners[0]), upright(banners[1]), "The side giving ground leans further")
        XCTAssertEqual(WorldStage.bannerLean(share: 0.5), 0, "Even: upright")
        XCTAssertEqual(WorldStage.bannerLean(share: 0), 1.45, "Broken: laid down")
        XCTAssertTrue(stage.fieldBanners([], time: 0).isEmpty)
    }

    /// A border stone stands toward the side of its hex where its
    /// alliance's land ends, facing out, in the alliance's colour.
    func testBorderStonesStandAtTheEdgeFacingOut() throws {
        let stage = stage()
        let hex = try XCTUnwrap(Self.state.map.hexes.first { Self.state.map[$0]?.terrain.isPassable == true })
        let teal = Vec4(0, 0.6, 0.6, 1)
        let stones = stage.borderStones([(hex: hex, outward: Hex.directions[0], colour: teal)]).flatMap(\.instances)
        XCTAssertEqual(stones.count, 1)
        XCTAssertEqual(stones[0].colour, teal)
        let centre = Relief.centre(of: hex)
        let beyond = Relief.centre(of: Hex(hex.q + Hex.directions[0].q, hex.r + Hex.directions[0].r))
        let at = Vec3(stones[0].model.c3.x - centre.x, 0, stones[0].model.c3.z - centre.z)
        let way = Vec3(beyond.x - centre.x, 0, beyond.z - centre.z)
        XCTAssertEqual(at.length, WorldStage.borderInset, accuracy: 1e-3)
        XCTAssertGreaterThan((at.x * way.x + at.z * way.z) / (at.length * way.length), 0.999, "Toward the land beyond")
        XCTAssertTrue(stage.borderStones([]).isEmpty)
    }

    /// A hold's House crest hangs beside its gate, facing out: its board
    /// in the field's tincture and its charge on it in the charge's.
    func testCrestsHangBesideTheGatesInTheirTinctures() throws {
        let stage = stage()
        let hold = try XCTUnwrap(Self.state.holds.first)
        let crest = Crest(field: .blue, charge: .key, tincture: .gold)
        let batches = stage.crestBoards([(hex: hold.position, crest: crest)])
        let board = try XCTUnwrap(batches.first { $0.key == ModelKey.crestBoard }?.instances.first)
        let charge = try XCTUnwrap(batches.first { $0.key == ModelKey.crestCharge(5) }?.instances.first)
        XCTAssertEqual(board.colour, WorldStage.colour(of: .blue))
        XCTAssertEqual(charge.colour, WorldStage.colour(of: .gold))
        XCTAssertEqual(board.model, charge.model, "The charge on the shield")
        let front = HoldLayout.frontAngle(of: hold.position)
        let facing = Vec3(board.model.c2.x, 0, board.model.c2.z)
        XCTAssertGreaterThan(facing.x * Float(cos(Double(front))) + facing.z * Float(sin(Double(front))), 0.99, "Facing out")
        XCTAssertTrue(stage.crestBoards([]).isEmpty)
    }

    /// A barge rides the still water from where it pushed off toward where
    /// it makes for, as far as the watch has gone, heading there.
    func testBargesRideTheWaterAsTheWatchGoes() throws {
        let stage = stage()
        let water = Self.state.map.hexes.filter { Self.state.map[$0]?.terrain == .still }
        let from = try XCTUnwrap(water.first), to = try XCTUnwrap(water.last)
        let a = Relief.centre(of: from), b = Relief.centre(of: to)
        let start = WorldStage.bargePlace(from: from, to: to, progress: 0)
        let end = WorldStage.bargePlace(from: from, to: to, progress: 1)
        let mid = WorldStage.bargePlace(from: from, to: to, progress: 0.5)
        XCTAssertEqual(start.at.x, a.x, accuracy: 1e-4)
        XCTAssertEqual(end.at.z, b.z, accuracy: 1e-4)
        XCTAssertEqual(mid.at.x, (a.x + b.x) / 2, accuracy: 1e-3)
        XCTAssertEqual(mid.at.y, Relief.waterline, "On the water")
        let instances = stage.barges([(from: from, to: to, progress: 0.5)], time: 1).flatMap(\.instances)
        XCTAssertEqual(instances.count, 1)
        let forward = Vec3(instances[0].model.c2.x, 0, instances[0].model.c2.z)
        let way = Vec3(b.x - a.x, 0, b.z - a.z)
        XCTAssertGreaterThan((forward.x * way.x + forward.z * way.z) / (forward.length * way.length), 0.99, "Heading for the far shore")
    }

    /// The Drowned Crown turns just above the ground where it lies, and
    /// rides high over the company that bears it.
    func testTheDrownedCrownLiesLowAndIsBorneHigh() throws {
        let stage = stage()
        let hex = try XCTUnwrap(Self.state.map.hexes.first { Self.state.map[$0]?.terrain.isWater == false })
        let centre = Relief.centre(of: hex)
        let ground = stage.ground(atX: centre.x, z: centre.z)
        let lying = try XCTUnwrap(stage.drownedCrown(at: hex, borne: false, time: 0).flatMap(\.instances).first)
        let borne = try XCTUnwrap(stage.drownedCrown(at: hex, borne: true, time: 0).flatMap(\.instances).first)
        XCTAssertEqual(lying.model.c3.y, ground + WorldStage.crownLying, accuracy: 1e-4)
        XCTAssertEqual(borne.model.c3.y, ground + WorldStage.crownBorne, accuracy: 1e-4)
        XCTAssertEqual(lying.flags & ModelInstance.alwaysShown, ModelInstance.alwaysShown, "Lit by the moon for every House")
        XCTAssertEqual(stage.drownedCrown(at: hex, borne: false, time: 0).first?.key, .drownedCrown)
    }

    /// A House's listening stones stand on the water where they were sunk,
    /// seen by every House, each turned its own way; one that heard a march
    /// last watch turns its ripples faster.
    func testListeningStonesStandOnTheWaterWhereTheyWereSunk() throws {
        let stage = stage()
        let water = Array(Self.state.map.hexes.filter { Self.state.map[$0]?.terrain.isWater == true }.prefix(2))
        XCTAssertEqual(water.count, 2)
        let batches = stage.listeningStones([(at: water[0], heard: false), (at: water[1], heard: true)])
        XCTAssertEqual(batches.map(\.key), [.listeningStone])
        let stones = batches.flatMap(\.instances)
        XCTAssertEqual(stones.count, 2)
        for (stone, hex) in zip(stones, water) {
            let centre = Relief.centre(of: hex)
            XCTAssertEqual(stone.model.c3.x, centre.x, accuracy: 1e-4)
            XCTAssertEqual(stone.model.c3.z, centre.z, accuracy: 1e-4)
            XCTAssertEqual(stone.model.c3.y, stage.ground(atX: centre.x, z: centre.z), accuracy: 1e-4, "on the water's face")
            XCTAssertEqual(stone.hex, SIMD2(Int32(hex.q), Int32(hex.r)))
            XCTAssertEqual(stone.flags & ModelInstance.alwaysShown, ModelInstance.alwaysShown, "seen by every House")
        }
        XCTAssertNotEqual(stones[0].model.c0, stones[1].model.c0, "each turned its own way")
        XCTAssertGreaterThan(stones[1].params.z, stones[0].params.z, "the one that heard turns its ripples faster")
    }

    /// The pedlar's skiff lies on the water off a hold, its prow toward the
    /// shore, rocking a little as time goes.
    func testThePedlarsSkiffLiesOffTheShoreItsProwToTheLand() throws {
        let stage = stage()
        let water = try XCTUnwrap(Self.state.map.hexes.first { hex in
            Self.state.map[hex]?.terrain.isWater == true && hex.neighbors.contains { Self.state.map[$0]?.terrain.isWater == false }
        })
        let shore = try XCTUnwrap(water.neighbors.first { Self.state.map[$0]?.terrain.isWater == false })
        let batches = stage.pedlarSkiff(at: water, toward: shore, time: 1.3)
        XCTAssertEqual(batches.map(\.key), [.pedlarSkiff])
        let skiff = try XCTUnwrap(batches.first?.instances.first)
        let centre = Relief.centre(of: water), land = Relief.centre(of: shore)
        XCTAssertEqual(skiff.model.c3.x, centre.x, accuracy: 1e-4)
        XCTAssertEqual(skiff.model.c3.z, centre.z, accuracy: 1e-4)
        XCTAssertEqual(skiff.model.c3.y, stage.ground(atX: centre.x, z: centre.z), accuracy: 0.006, "on the water, rocking a little")
        let prow = skiff.model.transformDirection(Vec3(0, 0, 1))
        let toward = Vec3(land.x - centre.x, 0, land.z - centre.z).normalized
        XCTAssertGreaterThan(Vec3(prow.x, 0, prow.z).normalized.dot(toward), 0.999, "its prow toward the shore")
        let later = try XCTUnwrap(stage.pedlarSkiff(at: water, toward: shore, time: 2.9).first?.instances.first)
        XCTAssertNotEqual(later.model, skiff.model, "rocking as time goes")
        XCTAssertEqual(skiff.flags & ModelInstance.alwaysShown, ModelInstance.alwaysShown)
    }

    /// A work being raised raises its dust where it is drawn, carried out
    /// from the hold's middle as its works are, and only while it rises.
    func testDustRisesWhereTheRisingWorkIsDrawn() throws {
        let stage = stage()
        var hold = try XCTUnwrap(Self.state.holds.first { $0.isSeat })
        XCTAssertEqual(stage.risingWorks([HoldSight(hold: hold, colour: Vec4(1, 1, 1, 1))]), [], "nothing being raised")
        hold.project = try JSONDecoder().decode(Hold.Project.self, from: Data(#"{"kind":"sawpit","targetLevel":1,"watchesLeft":2}"#.utf8))
        let sight = HoldSight(hold: hold, colour: Vec4(1, 1, 1, 1), progress: 0.25)
        let dust = stage.risingWorks([sight])
        XCTAssertEqual(dust.count, 1, "the sawpit alone, not its scaffold")
        var frame = SceneFrame()
        let drawn = try XCTUnwrap(stage.holds([sight], time: 3, into: &frame).batches.first { $0.key == .work(.sawpit, level: 1) }?.instances.first)
        XCTAssertEqual(dust[0].x, drawn.model.c3.x, accuracy: 1e-4)
        XCTAssertEqual(dust[0].z, drawn.model.c3.z, accuracy: 1e-4)
        let middle = Relief.centre(of: hold.position)
        let planned = try XCTUnwrap(stage.pieces(of: hold, progress: 0.25).first { $0.key == .work(.sawpit, level: 1) }).position
        let out = (Vec3(dust[0].x - middle.x, 0, dust[0].z - middle.z)).length
        let plan = (Vec3(planned.x - middle.x, 0, planned.z - middle.z)).length
        XCTAssertEqual(out, plan * HoldLayout.grandeur, accuracy: 1e-3, "as far out as the hold is drawn, not as its plan lies")
    }

    /// A commander's skill works where it fired: its look's model there
    /// from the moment it fires, seen by every House and drawn whole,
    /// posed anew as it works and fading as it ends; none before, none once
    /// it is done.
    func testACommandersSkillWorksWhereItFired() throws {
        let at = Vec3(1.5, 0.2, -2.0)
        let fired = FuryLook.allCases.enumerated().map { index, look in
            Happenings.Fury(at: at + Vec3(Float(index), 0, 0), start: 10, look: look, seed: UInt32(index * 37))
        }
        func staged(_ time: Float) -> (batches: [ModelBatch], frame: SceneFrame) {
            var frame = SceneFrame()
            let batches = WorldStage.furies(fired, time: time, into: &frame)
            return (batches, frame)
        }
        XCTAssertTrue(staged(9.9).batches.isEmpty, "Nothing before it fires")
        XCTAssertTrue(staged(10 + WorldStage.furyWorks).batches.isEmpty, "Nothing once it is done")
        let early = staged(10.2), late = staged(10 + WorldStage.furyWorks * 0.9)
        XCTAssertEqual(Set(early.batches.map(\.key)), Set(FuryLook.allCases.map { ModelKey.fury($0) }), "Each its look's model")
        for batch in early.batches {
            let instance = try XCTUnwrap(batch.instances.first)
            guard case .fury(let look) = batch.key else { return XCTFail("\(batch.key)") }
            let index = try XCTUnwrap(FuryLook.allCases.firstIndex(of: look))
            XCTAssertEqual(instance.model.c3.x, at.x + Float(index), accuracy: 1e-4, "Where it fired")
            XCTAssertEqual(instance.model.c3.y, at.y, accuracy: 1e-4)
            XCTAssertEqual(instance.params.x, WorldStage.whole, "Drawn whole, however tall it stands")
            XCTAssertEqual(instance.params.y, WorldStage.furyOpacity(look), accuracy: 1e-5, "At its fullest early on")
            XCTAssertEqual(instance.flags & ModelInstance.alwaysShown, ModelInstance.alwaysShown, "Seen by every House")
            let ending = try XCTUnwrap(late.batches.first { $0.key == batch.key }?.instances.first)
            XCTAssertLessThan(ending.params.y, instance.params.y * 0.5, "Fading as it ends")
            let posedEarly = Array(early.frame.palette[Int(instance.palette)..<Int(instance.palette) + Library.model(batch.key).rig.count])
            let posedLate = Array(late.frame.palette[Int(ending.palette)..<Int(ending.palette) + Library.model(batch.key).rig.count])
            XCTAssertNotEqual(posedEarly, posedLate, "\(look) moves as it works")
        }
        XCTAssertLessThan(WorldStage.furyOpacity(.ward), WorldStage.furyOpacity(.quake), "A ward's company seen within it; a quake's rock solid")
    }

    /// The Lyceum's hall stands dark between sittings; while its scholars
    /// sit its orrery turns over the dome and five lights circle it.
    func testTheLyceumStandsDarkAndIsLitWhileItSits() throws {
        let stage = stage()
        let hex = try XCTUnwrap(Self.state.map.hexes.first { Self.state.map[$0]?.terrain.isWater == false })
        let centre = Relief.centre(of: hex)
        let ground = stage.ground(atX: centre.x, z: centre.z)
        let dark = stage.lyceum(at: hex, lit: false, time: 1)
        XCTAssertEqual(dark.map(\.key), [.lyceumHall])
        XCTAssertEqual(try XCTUnwrap(dark.first?.instances.first).model.c3.y, ground, accuracy: 1e-4)
        let lit = stage.lyceum(at: hex, lit: true, time: 1)
        XCTAssertEqual(Set(lit.map(\.key)), [.lyceumHall, .lyceumOrrery, .helpLight])
        XCTAssertEqual(lit.first { $0.key == .helpLight }?.instances.count, Lyceum.questions)
        let orrery = { (time: Float) in try XCTUnwrap(stage.lyceum(at: hex, lit: true, time: time).first { $0.key == .lyceumOrrery }?.instances.first).model }
        XCTAssertEqual(try orrery(1).c3.y, ground + LyceumHall.orreryAt.y, accuracy: 1e-4)
        XCTAssertNotEqual(try orrery(1).c0.x, try orrery(2).c0.x, accuracy: 1e-3, "it turns")
        for batch in lit {
            for instance in batch.instances {
                XCTAssertEqual(instance.flags & ModelInstance.alwaysShown, ModelInstance.alwaysShown, "every House sees it")
            }
        }
    }

    func testHallsStandInTheirAlliancesColoursRisingInTheirScaffolds() throws {
        let stage = stage()
        let hexes = Array(Self.state.map.hexes.filter { hex in
            Self.state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
        }.prefix(2))
        let blue = Vec4(0.1, 0.2, 0.9, 1), gold = Vec4(0.8, 0.7, 0.2, 1)
        let (batches, hearths) = stage.halls([HallSight(hex: hexes[0], colour: blue), HallSight(hex: hexes[1], colour: gold, progress: 0.25)])
        XCTAssertEqual(Set(batches.map(\.key)), [.allianceHall, .scaffold])
        let halls = try XCTUnwrap(batches.first { $0.key == .allianceHall }).instances
        XCTAssertEqual(halls.map(\.colour), [blue, gold])
        XCTAssertEqual(halls[0].params.x, WorldStage.whole, "Whole, drawn whole")
        XCTAssertLessThan(halls[1].params.x, WorldStage.whole, "Rising, drawn so far")
        XCTAssertEqual(try XCTUnwrap(batches.first { $0.key == .scaffold }).instances.count, 1, "A scaffold about the one rising")
        XCTAssertEqual(hearths.map(\.hex), [hexes[0]], "Only a whole hall's louvre smokes")
        XCTAssertEqual(stage.risingHalls([HallSight(hex: hexes[0], colour: blue), HallSight(hex: hexes[1], colour: gold, progress: 0.25)]).count, 1)
        XCTAssertTrue(stage.halls([]).batches.isEmpty)
    }

    func testStorehousesAndYardsStandInTheirAlliancesColours() throws {
        let stage = stage()
        let hexes = Array(Self.state.map.hexes.filter { hex in
            Self.state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
        }.prefix(4))
        let blue = Vec4(0.1, 0.2, 0.9, 1), gold = Vec4(0.8, 0.7, 0.2, 1)
        var frame = SceneFrame()
        let batches = stage.storehouses([HallSight(hex: hexes[0], colour: blue), HallSight(hex: hexes[1], colour: gold, progress: 0.5)],
                                        time: 2, into: &frame)
        XCTAssertEqual(Set(batches.map(\.key)), [.storehouse, .scaffold])
        let storehouses = try XCTUnwrap(batches.first { $0.key == .storehouse }).instances
        XCTAssertEqual(storehouses.map(\.colour), [blue, gold])
        XCTAssertEqual(storehouses[0].params.x, WorldStage.whole, "Whole, drawn whole")
        XCTAssertLessThan(storehouses[1].params.x, WorldStage.whole, "Rising, drawn so far")
        XCTAssertEqual(try XCTUnwrap(batches.first { $0.key == .scaffold }).instances.count, 1, "A scaffold about the one rising")
        XCTAssertGreaterThan(storehouses[0].palette, 0, "Whole, its hoist works")
        XCTAssertGreaterThan(storehouses[1].palette, 0, "Rising, its hoist rests, posed all the same")
        var later = SceneFrame()
        let rising = stage.storehouses([HallSight(hex: hexes[1], colour: gold, progress: 0.5)], time: 7, into: &later)
        let start = Int(try XCTUnwrap(rising.first { $0.key == .storehouse }?.instances.first?.palette))
        let rig = Library.model(.storehouse).rig.count
        XCTAssertEqual(Array(later.palette[start..<start + rig]), Array(frame.palette[Int(storehouses[1].palette)..<Int(storehouses[1].palette) + rig]),
                       "Still while it rises")
        XCTAssertTrue(stage.storehouses([], time: 2, into: &frame).isEmpty)
        // Yards, each its store's, smoking where salt is boiled, their machinery working.
        let (yards, hearths) = stage.yards([(.grain, hexes[2], blue), (.moonsalt, hexes[3], gold)], time: 2, into: &frame)
        XCTAssertEqual(Set(yards.map(\.key)), [.yard(.grain), .yard(.moonsalt)])
        for batch in yards {
            for instance in batch.instances {
                let hex = batch.key == .yard(.grain) ? hexes[2] : hexes[3]
                let centre = Relief.centre(of: hex)
                XCTAssertEqual(instance.model.c3.x, centre.x, accuracy: 1e-4)
                XCTAssertEqual(instance.model.c3.z, centre.z, accuracy: 1e-4)
                XCTAssertEqual(instance.colour, batch.key == .yard(.grain) ? blue : gold)
            }
        }
        XCTAssertEqual(hearths.map(\.hex), [hexes[3]], "The salt works' boiling house smokes")
        XCTAssertEqual(yards.first { $0.key == .yard(.grain) }?.instances.first?.palette, 0, "A tilled acre stands still")
        XCTAssertGreaterThan(yards.first { $0.key == .yard(.moonsalt) }?.instances.first?.palette ?? 0, 0, "The salt works' windlass turns")
        XCTAssertTrue(stage.yards([], time: 2, into: &frame).batches.isEmpty)
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
        // The veil's mist: six low, wide banks ringing the hold, faint and breathing: a
        // breath on the air, never cotton before a low eye.
        let banks = WorldStage.mist(about: Hex(2, -1), height: 0.3)
        XCTAssertEqual(banks.count, 6)
        XCTAssertTrue(banks.allSatisfy { $0.hex == Hex(2, -1) && abs($0.point.y - 0.34) < 1e-5 })
        let middle = Relief.centre(of: Hex(2, -1))
        XCTAssertTrue(banks.allSatisfy { abs(Vec3($0.point.x - middle.x, 0, $0.point.z - middle.z).length - 0.42) < 1e-4 })
        var misty = SceneFrame()
        let veiled = WorldStage.flights(arrows: [], birdsOver: nil, hearths: [], mists: banks, time: 2, into: &misty)
        let lying = veiled.first { $0.key == .prop(.puff) }?.instances ?? []
        XCTAssertEqual(lying.count, 6)
        XCTAssertTrue(lying.allSatisfy { $0.params.y >= 0.05 && $0.params.y <= 0.1 && $0.model.c0.x > 3 && $0.model.c1.y < 1 })
        // A Mangonel's stone flies as a stone, higher than an arrow over the same ground.
        var stones = SceneFrame()
        let stone = ArrowFlight(from: .zero, to: Vec3(3, 0, 0), progress: 0.5, stone: true)
        let hurled = WorldStage.flights(arrows: [stone], birdsOver: nil, hearths: [], time: 0, into: &stones)
        XCTAssertEqual(hurled.map(\.key), [.prop(.stone)])
        XCTAssertGreaterThan(stone.transform.c3.y, arrows[0].transform.c3.y * 1.5)
        XCTAssertFalse(arrows[0].stone)
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

private extension WorldStage {
    /// This stage's furniture, all of it, at `share`.
    func thinned(_ share: Float) -> [ModelBatch] {
        furnitureShare = share
        return furnish(occupied: [], holds: [])
    }
}

/// The land's pieces that have a rig are set working on the stage: each
/// instance given its own pose in the frame's palette; still ones left be.
final class AnimatedLandTests: XCTestCase {
    func testHolySitesAndStandardsArePosedOnTheStage() {
        let map = GameState(settings: GameSettings(seedText: "posed", houseCount: 2, radius: 16)).map
        let stage = WorldStage(map: map, relief: Relief(map: map))
        var frame = SceneFrame()
        let hexes = [Hex(1, 0), Hex(-2, 1)]
        let shrines = stage.animate(stage.shrines([(.moonwell, hexes[0], nil), (.heartstone, hexes[1], nil)]), time: 1.3, into: &frame)
        XCTAssertFalse(frame.palette.isEmpty, "The holy sites' parts are posed")
        XCTAssertTrue(shrines.allSatisfy { $0.instances.allSatisfy { Int($0.palette) < frame.palette.count } })
        let before = frame.palette.count
        let still = stage.animate(stage.lairs([(.reavers, hexes[0])]).batches, time: 1.3, into: &frame)
        XCTAssertEqual(frame.palette.count, before, "A lair stands still")
        XCTAssertEqual(still, stage.lairs([(.reavers, hexes[0])]).batches)
    }
}

/// The lake's mirror at the Still Hour: each glimpse a faint company in
/// its House's colour, shown whatever the keeper knows of its hex.
final class MirrorTests: XCTestCase {
    func testTheStillWaterShowsFaintCompanies() {
        let map = GameState(settings: GameSettings(seedText: "mirror", houseCount: 2, radius: 16)).map
        let stage = WorldStage(map: map, relief: Relief(map: map))
        let red = Vec4(1, 0, 0, 1)
        let batches = stage.mirrored([(.spear, Hex(1, 0), red), (.spear, Hex(2, 0), red), (.bow, Hex(0, 1), red)])
        XCTAssertEqual(batches.count, 2, "By kind")
        XCTAssertEqual(batches.flatMap(\.instances).count, 3)
        XCTAssertTrue(batches.flatMap(\.instances).allSatisfy { $0.params.y < 0.5 && $0.flags & ModelInstance.alwaysShown != 0 })
        XCTAssertTrue(stage.mirrored([]).isEmpty)
    }
}

/// However many holy sites stand, the stage poses each kind at no more than
/// four moments a frame: their poses shared.
final class SharedLandPoseTests: XCTestCase {
    func testManySitesShareFewPoses() {
        let map = GameState(settings: GameSettings(seedText: "shared poses", houseCount: 2, radius: 16)).map
        let stage = WorldStage(map: map, relief: Relief(map: map))
        var frame = SceneFrame()
        let hexes = (0..<40).map { Hex($0 % 8 - 4, $0 / 8 - 2) }
        let batches = stage.animate(stage.shrines(hexes.map { (.moonwell, $0, nil) }), time: 2.1, into: &frame)
        XCTAssertEqual(batches.flatMap(\.instances).count, 40)
        XCTAssertLessThanOrEqual(Set(batches.flatMap(\.instances).map(\.palette)).count, 4)
    }
}

final class BattleFrontTests: XCTestCase {
    /// Along a front of a field of battle steel flashes and sparks fly,
    /// clash on clash, with the glint of it lighting the throngs.
    func testAFrontFlashesAndSparksAlongItsLength() {
        var happenings = Happenings()
        let from = Vec3(0, 0, 0), to = Vec3(1, 0, 0)
        happenings.fronts = [Happenings.Front(from: from, to: to, strength: 2, seed: 3)]
        let (motes, lights) = happenings.effects(at: 10)
        XCTAssertFalse(motes.isEmpty, "the front throws flashes and sparks")
        XCTAssertEqual(lights.count, 1, "and its glint")
        let quiet = Happenings().effects(at: 10)
        XCTAssertTrue(quiet.motes.isEmpty)
        let later = happenings.effects(at: 10 + Happenings.clashEvery * 3).motes
        XCTAssertNotEqual(motes, later, "clash after clash")
    }
}

final class ThrongPoseTests: XCTestCase {
    /// A throng of 48 shares a handful of poses: its figures out of step
    /// with each other in a few steps, not each posed apart.
    func testAThrongSharesItsPoses() {
        let map = WorldMap(radius: 6, fill: Tile(terrain: .greyfield))
        let stage = WorldStage(map: map, relief: Relief(map: map))
        var pose = CompanyPose(unit: 3, key: .figure(.spear, tier: 5), sigil: 0, health: 100, hex: Hex(0, 0), position: .zero, heading: 0,
                               clip: .attack, clipTime: 0.4, isOwn: true)
        pose.throng = Formation.throngMost
        var frame = SceneFrame()
        let batches = stage.companies([pose], houses: [Vec4(1, 0, 0, 1)], into: &frame)
        XCTAssertEqual(batches.flatMap(\.instances).count, Formation.throngMost, "every figure of the throng drawn")
        XCTAssertLessThanOrEqual(Set(batches.flatMap(\.instances).map(\.palette)).count, WorldStage.throngSteps, "in a few shared poses")
    }

    /// A throng struck in its field: every other step reels under the
    /// foe's blows while the rest strike; out of a field, none does.
    func testAStruckThrongStrikesAndReelsByTurns() {
        var pose = CompanyPose(unit: 4, key: .figure(.rider, tier: 3), sigil: 0, health: 100, hex: Hex(0, 0), position: .zero, heading: 0,
                               clip: .attack, clipTime: 0.2, isOwn: true)
        pose.throng = Formation.throngMost
        XCTAssertEqual(WorldStage.throngClip(pose, step: 1), .attack, "not struck, all strike")
        pose.struck = true
        let clips = (0..<WorldStage.throngSteps).map { WorldStage.throngClip(pose, step: $0) }
        XCTAssertEqual(clips, [.attack, .hit, .attack, .hit, .attack])
        var marching = pose
        marching.clip = .march
        XCTAssertEqual(WorldStage.throngClip(marching, step: 1), .march, "only a company at the foe takes blows")
        let map = WorldMap(radius: 6, fill: Tile(terrain: .greyfield))
        let stage = WorldStage(map: map, relief: Relief(map: map))
        var frame = SceneFrame(), still = SceneFrame()
        _ = stage.companies([pose], houses: [Vec4(1, 0, 0, 1)], into: &frame)
        pose.struck = false
        _ = stage.companies([pose], houses: [Vec4(1, 0, 0, 1)], into: &still)
        XCTAssertNotEqual(frame.palette, still.palette, "its reeling ranks stand otherwise than striking ones")
    }
}

final class FallingTests: XCTestCase {
    /// A company losing men in its field shows them falling before it, one
    /// after another, as many more as it has lost, up to a few.
    func testACompanyLosingMenShowsThemFalling() {
        XCTAssertEqual(WorldStage.fallingCount(lost: 0), 0, "none lost, none falling")
        XCTAssertEqual(WorldStage.fallingCount(lost: 1), 1)
        XCTAssertGreaterThan(WorldStage.fallingCount(lost: 6_000), WorldStage.fallingCount(lost: 1))
        XCTAssertEqual(WorldStage.fallingCount(lost: 400_000), WorldStage.fallingMost)
        // Each man in his turn: falling, lying, then gone as the next goes down.
        let times = (0..<64).map { WorldStage.falling(count: 3, unit: 7, at: Float($0) * 0.1) }
        XCTAssertTrue(times.allSatisfy { $0.allSatisfy { $0 >= 0 && $0 <= Clip.death.period + WorldStage.fallenLies } })
        XCTAssertTrue(times.contains { $0.count < 3 }, "some between their turns")
        XCTAssertTrue(times.contains { $0.contains { $0 < 0.3 } }, "one just struck down")
        XCTAssertTrue(times.flatMap { $0 }.allSatisfy { ($0 * 10 - ($0 * 10).rounded()).magnitude < 1e-3 }, "to the tenth, so shared")

        let map = WorldMap(radius: 6, fill: Tile(terrain: .greyfield))
        let stage = WorldStage(map: map, relief: Relief(map: map))
        var pose = CompanyPose(unit: 2, key: .figure(.spear, tier: 2), sigil: 0, health: 100, hex: Hex(0, 0), position: .zero, heading: 0,
                               clip: .attack, clipTime: 0.3, isOwn: true)
        pose.throng = 12
        pose.struck = true
        pose.falling = [0.2, 1.4]
        var frame = SceneFrame()
        let drawn = stage.companies([pose], houses: [Vec4(1, 0, 0, 1)], into: &frame).flatMap(\.instances)
        XCTAssertEqual(drawn.count, 12 + 2, "the throng and its two falling")
    }
}

final class ImpactTests: XCTestCase {
    /// Where a struck throng takes its blows, steel sparks and flashes beat
    /// on beat, on its phase; a struck engine's timber splinters.
    func testBlowsLandOnTheStruckBeatOnBeat() {
        var happenings = Happenings()
        happenings.impacts = [Happenings.Impact(at: Vec3(1, 0, 1), phase: 0.3, every: 1.5, seed: 9)]
        let landed = happenings.effects(at: 1.5 * 6 + 0.3 + 0.05).motes
        XCTAssertFalse(landed.isEmpty, "a blow just landed")
        XCTAssertTrue(landed.allSatisfy { ($0.place.x - 1).magnitude < 0.6 && ($0.place.z - 1).magnitude < 0.6 }, "where it landed")
        XCTAssertNotEqual(landed, happenings.effects(at: 1.5 * 7 + 0.3 + 0.05).motes, "each blow its own")
        var engine = happenings
        engine.impacts[0].timber = true
        XCTAssertNotEqual(engine.effects(at: 1.5 * 6 + 0.3 + 0.05).motes, landed, "timber splinters where steel sparks")
        XCTAssertTrue(Happenings().effects(at: 9.35).motes.isEmpty)
    }
}

final class LakeLifeTests: XCTestCase {
    /// Fishers row out on the lake at night, only over water, each with a
    /// lantern whose light lies on the water about it and flickers.
    func testFishersRowTheLakeWithTheirLanterns() throws {
        let map = WorldMap(radius: 6, fill: Tile(terrain: .still))
        let stage = WorldStage(map: map, relief: Relief(map: map))
        var frame = SceneFrame()
        let out = stage.boats(about: Vec3(0, Relief.waterline, 0), time: 3, into: &frame)
        let boats = out.batches.flatMap(\.instances)
        XCTAssertEqual(boats.count, WorldStage.boatCount, "every boat out on open water")
        XCTAssertEqual(out.lights.count, boats.count, "each with its lantern lit")
        XCTAssertTrue(out.lights.allSatisfy { $0.colour.x > $0.colour.z }, "lantern-warm")
        let later = stage.boats(about: Vec3(0, Relief.waterline, 0), time: 9, into: &frame)
        XCTAssertNotEqual(later.lights.map(\.position), out.lights.map(\.position), "rowing round")
        let land = WorldMap(radius: 6, fill: Tile(terrain: .greyfield))
        let ashore = WorldStage(map: land, relief: Relief(map: land)).boats(about: .zero, time: 3, into: &frame)
        XCTAssertTrue(ashore.batches.isEmpty && ashore.lights.isEmpty, "no boat on dry land")
        // The boat rocks on the swell and its fisher rows.
        let boat = Library.model(.prop(.boat))
        XCTAssertNotEqual(boat.pose(.idle, at: 0), boat.pose(.idle, at: 1), "it rows")
    }
}

final class ExpeditionFieldTests: XCTestCase {
    /// An expedition's own field under the Spine: the House's camp in its
    /// colour, and a waystone for every stage, lit for each one won.
    func testTheFieldLightsAWaystoneForEveryStageWon() {
        let map = WorldMap(radius: 6, fill: Tile(terrain: .greyfield))
        let stage = WorldStage(map: map, relief: Relief(map: map))
        var frame = SceneFrame()
        let colour = Vec4(0.7, 0.2, 0.1, 1)
        let field = stage.expeditionField(from: Hex(0, 0), at: Hex(1, 0), won: 5, colour: colour, into: &frame, time: 2)
        let count = { (key: ModelKey) in field.filter { $0.key == key }.flatMap(\.instances).count }
        XCTAssertEqual(count(.rallyCamp), 1, "the House's camp")
        XCTAssertEqual(field.first { $0.key == .rallyCamp }?.instances.first?.colour, colour)
        XCTAssertEqual(count(.prop(.waystoneLit)), 5, "a stone lit for each stage won")
        XCTAssertEqual(count(.prop(.waystone)) + count(.prop(.waystoneLit)), ExpeditionStage.count, "one for every stage")
        let none = stage.expeditionField(from: Hex(0, 0), at: Hex(1, 0), won: 0, colour: colour, into: &frame, time: 2)
        XCTAssertTrue(none.allSatisfy { $0.key != .prop(.waystoneLit) }, "none lit before the first is won")
    }
}

final class HoldGlowTests: XCTestCase {
    /// From afar each hold the keeper knows glows warm over its keep, so the
    /// realm's holds ring the black lake in small lights: one glow for each,
    /// high over its middle, light only; a seat's brighter and wider than a
    /// hold's, one burning red and brighter still; coming as the view draws
    /// away and keeping its size on the screen as it does; none as close as
    /// the keeps' own windows and fires are seen.
    func testHoldsGlowFromAfar() throws {
        let state = GameState(settings: GameSettings(seedText: "glows", houseCount: 4, radius: 12, keepers: 1))
        let stage = WorldStage(map: state.map, relief: Relief(map: state.map))
        var seat = try XCTUnwrap(state.holds.first { $0.isSeat })
        seat.ward = seat.maximumWard
        var hold = seat
        hold.isSeat = false
        var burning = hold
        burning.ward = burning.maximumWard / 2 - 1
        hold.ward = hold.maximumWard
        let colour = Vec4(0.5, 0.5, 0.5, 1)
        let sights = [seat, hold, burning].map { HoldSight(hold: $0, colour: colour) }

        let far = stage.glows(sights, scale: Camera.minimumScale)
        XCTAssertEqual(far.count, 3, "One glow for each")
        let centre = Relief.centre(of: seat.position)
        XCTAssertEqual(far[0].place.x, centre.x)
        XCTAssertEqual(far[0].place.z, centre.z)
        XCTAssertGreaterThan(far[0].place.y, stage.ground(atX: centre.x, z: centre.z), "High over its keep")
        XCTAssertTrue(far.allSatisfy { $0.colour.w == 0 }, "Light only")
        XCTAssertTrue(far.allSatisfy { $0.colour.x > 2 * $0.colour.z }, "Warm")
        XCTAssertGreaterThan(far[0].colour.x, far[1].colour.x, "A seat's brighter")
        XCTAssertGreaterThan(far[0].place.w, far[1].place.w, "and wider")
        XCTAssertGreaterThan(far[2].colour.x, far[1].colour.x, "One burning brighter")
        XCTAssertGreaterThan(far[2].colour.x / far[2].colour.y, far[1].colour.x / far[1].colour.y, "and redder")

        let nearer = stage.glows(sights, scale: 22)
        XCTAssertEqual(nearer.count, 3)
        XCTAssertLessThan(nearer[0].colour.x, far[0].colour.x, "Fainter as the view comes down")
        XCTAssertEqual(Double(nearer[0].place.w) * 22, Double(far[0].place.w) * Camera.minimumScale, accuracy: 1e-4,
                       "The same size on the screen")
        XCTAssertTrue(stage.glows(sights, scale: WorldStage.glowFrom).isEmpty, "None where the keeps' own lights are seen")
        XCTAssertTrue(stage.glows(sights, scale: Camera.maximumScale).isEmpty)
        XCTAssertTrue(stage.glows([], scale: Camera.minimumScale).isEmpty)
    }
}
