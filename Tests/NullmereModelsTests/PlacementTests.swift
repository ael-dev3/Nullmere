import Foundation
@testable import NullmereCore
@testable import NullmereModels
import XCTest

extension SIMD2 where Scalar == Float {
    var length: Float { (x * x + y * y).squareRoot() }
}

/// Where the models stand: companies in their hexes, holds on their land,
/// the land's furniture over the map.
final class PlacementTests: XCTestCase {
    static let worlds: [GameState] = ["placement", "second shore", "the third lake"].map {
        GameState(settings: GameSettings(seedText: $0, houseCount: 6, radius: 14))
    }

    /// How far a model reaches across the ground from its foot.
    static func reach(_ key: ModelKey) -> Float {
        Library.model(key).mesh.vertices.reduce(0) { max($0, ($1.position.x * $1.position.x + $1.position.z * $1.position.z).squareRoot()) }
    }

    /// A model's extent across the ground as it stands at idle, as a box,
    /// leaving out what it has put away.
    static func extent(_ key: ModelKey) -> (min: SIMD2<Float>, max: SIMD2<Float>) {
        let model = Library.model(key)
        let pose = model.pose(.idle, at: 0)
        var low = SIMD2<Float>(repeating: .infinity), high = SIMD2<Float>(repeating: -.infinity)
        for vertex in model.mesh.vertices {
            let m = pose[Int(vertex.part)]
            guard Vec3(m.c0.x, m.c0.y, m.c0.z).length > 0.01 else { continue }
            let p = m.transformPoint(vertex.position)
            low = pointwiseMin(low, SIMD2(p.x, p.z))
            high = pointwiseMax(high, SIMD2(p.x, p.z))
        }
        return (low, high)
    }

    static var companies: [ModelKey] {
        Library.catalogue.filter {
            switch $0 {
            case .figure, .wild: return true
            default: return false
            }
        }
    }

    // MARK: Formations

    func testCompaniesThinAsTheyAreWornDown() {
        for key in PlacementTests.companies {
            XCTAssertEqual(Formation.count(key, health: 0), 0, "\(key): none once gone")
            XCTAssertEqual(Formation.count(key, health: -5), 0)
            XCTAssertEqual(Formation.count(key, health: 1), 1, "\(key): one while it stands")
            XCTAssertEqual(Formation.count(key, health: 100), Formation.strength(key), "\(key): all when whole")
            XCTAssertEqual(Formation.count(key, health: 140), Formation.strength(key))
            var last = 0
            for health in 0...100 {
                let count = Formation.count(key, health: health)
                XCTAssertGreaterThanOrEqual(count, last, "\(key) never grows as it is worn down")
                XCTAssertEqual(Formation.offsets(key, health: health).count, count)
                XCTAssertEqual(Formation.offsets(key, health: health, led: true).count, count)
                last = count
            }
            XCTAssertLessThan(Formation.count(key, health: 50), Formation.strength(key), "\(key) shows its wounds")
        }
        XCTAssertGreaterThan(Formation.strength(.figure(.spear, tier: 1)), Formation.strength(.figure(.rider, tier: 1)), "a block of spears")
        XCTAssertEqual(Formation.strength(.keep(seat: false)), 1)
        XCTAssertEqual(Formation.offsets(.prop(.cart), health: 50), [.zero])
        XCTAssertEqual(Formation.offsets(.prop(.cart), health: 0), [])
        XCTAssertEqual(Formation.commander(.scaffold), .zero)
    }

    func testCompaniesStandWithinTheirHex() {
        let leader = (0..<6).map { PlacementTests.reach(.commander(variant: $0)) }.max() ?? 0
        for key in PlacementTests.companies {
            let reach = PlacementTests.reach(key), box = PlacementTests.extent(key)
            for health in [100, 80, 55, 30, 1] {
                for led in [false, true] {
                    let offsets = Formation.offsets(key, health: health, led: led)
                    for offset in offsets {
                        XCTAssertEqual(offset.y, 0)
                        XCTAssertLessThanOrEqual(SIMD2(offset.x, offset.z).length + reach, Formation.hexInner,
                                                 "\(key) at \(health) stands within its hex, turned any way")
                    }
                    // No two figures stand in each other.
                    for i in offsets.indices {
                        for j in offsets.indices where j > i {
                            let a = (box.min + SIMD2(offsets[i].x, offsets[i].z), box.max + SIMD2(offsets[i].x, offsets[i].z))
                            let b = (box.min + SIMD2(offsets[j].x, offsets[j].z), box.max + SIMD2(offsets[j].x, offsets[j].z))
                            let apart = a.1.x <= b.0.x || b.1.x <= a.0.x || a.1.y <= b.0.y || b.1.y <= a.0.y
                            XCTAssertTrue(apart, "\(key)'s figures \(i) and \(j) stand apart")
                        }
                    }
                    guard led else { continue }
                    let commander = Formation.commander(key, health: health)
                    XCTAssertLessThanOrEqual(SIMD2(commander.x, commander.z).length + leader, Formation.hexInner,
                                             "\(key)'s commander rides within the hex")
                    let front = offsets.map(\.z).max() ?? 0
                    XCTAssertGreaterThan(commander.z - front, 0.3, "\(key)'s commander rides at its head")
                }
            }
            // The company stands about the heart, front to back.
            let whole = Formation.offsets(key, health: 100)
            let middle = ((whole.map(\.z).max() ?? 0) + (whole.map(\.z).min() ?? 0)) / 2
            XCTAssertEqual(middle, 0, accuracy: 1e-4, "\(key) is centred")
        }
    }

    // MARK: Holds

    static func grandPlan(_ hex: Hex, rising: HoldLayout.Plan.Rising? = nil) -> HoldLayout.Plan {
        var levels: [HoldLayout.Work: Int] = [.study: 5]
        for kind in BuildingKind.allCases {
            levels[HoldLayout.Work(kind)] = kind.maxLevel
        }
        return HoldLayout.Plan(hex: hex, isSeat: true, levels: levels, rising: rising)
    }

    /// Every piece of a hold stands on the relief, within the hold's land,
    /// and clear of every other.
    static func check(_ pieces: [Piece], _ plan: HoldLayout.Plan, _ relief: Relief, file: StaticString = #filePath, line: UInt = #line) {
        let centre = Relief.centre(of: plan.hex)
        let heart = SIMD2(centre.x, centre.z)
        let land = HoldLayout.land(of: plan.hex, relief: relief)
        let layout = HexLayout(size: 1)
        XCTAssertEqual(pieces.first?.key, plan.heritage.map { .keepOf($0, seat: plan.isSeat) } ?? .keep(seat: plan.isSeat), file: file, line: line)
        var works: [(SIMD2<Float>, Piece)] = []
        func ground(_ point: Vec3) -> Float { relief.height(atX: point.x, z: point.z) }
        /// Points over a footprint: its middle and two rings, finer than the layout samples.
        func footprint(_ centre: Vec3, _ radius: Float) -> [Vec3] {
            [centre] + (0..<24).flatMap { index -> [Vec3] in
                let angle = Float(index) * .pi / 12 + 0.07
                return [centre + MeshBuilder.ring(radius, 0, angle), centre + MeshBuilder.ring(radius * 0.55, 0, angle)]
            }
        }
        for piece in pieces {
            let at = SIMD2(piece.position.x, piece.position.z)
            let model = Library.model(piece.key)
            XCTAssertTrue((0...1).contains(piece.progress), file: file, line: line)
            XCTAssertEqual(piece.hex, layout.hex(atX: Double(at.x), y: Double(at.y)), "\(piece.key) names its hex", file: file, line: line)
            XCTAssertGreaterThan(piece.position.y, ground(piece.position) - 0.4, "\(piece.key) is not buried", file: file, line: line)
            switch piece.key {
            case .keep, .keepOf:
                XCTAssertLessThan((at - heart).length, 1e-4, file: file, line: line)
                for point in footprint(piece.position, 0.36) {
                    XCTAssertLessThanOrEqual(piece.position.y + model.mesh.bounds.min.y, ground(point) + 1e-3,
                                             "the keep's plinth reaches the ground", file: file, line: line)
                    XCTAssertLessThanOrEqual(piece.position.y, ground(point) + 0.06, "the keep stands on its ground", file: file, line: line)
                }
            case .walls:
                XCTAssertLessThan((at - heart).length, 1e-4, file: file, line: line)
                let ring = (0..<24).map { piece.position + MeshBuilder.ring(Holds.wallRadius, 0, Float($0) * .pi / 12) }
                for point in ring {
                    XCTAssertLessThanOrEqual(piece.position.y + model.mesh.bounds.min.y, ground(point) + 1e-3,
                                             "the walls' footings reach the ground all round", file: file, line: line)
                }
                XCTAssertLessThanOrEqual(piece.position.y, (ring.map(ground).max() ?? 0) + 1e-3, file: file, line: line)
                XCTAssertGreaterThanOrEqual(piece.position.y, (ring.map(ground).min() ?? 0) - 1e-3, file: file, line: line)
            case .scaffold:
                XCTAssertTrue(works.contains { ($0.0 - at).length < 1e-4 }, "a scaffold stands round its work", file: file, line: line)
            default:
                for point in HoldLayout.points(around: piece.position, radius: HoldLayout.workRadius) {
                    let hex = layout.hex(atX: Double(point.x), y: Double(point.z))
                    XCTAssertTrue(land.contains(hex), "\(piece.key) stands on the hold's land", file: file, line: line)
                }
                // Its pad goes down further than the ground falls away under it anywhere.
                for point in footprint(piece.position, HoldLayout.workRadius * 0.95) {
                    XCTAssertLessThanOrEqual(piece.position.y, ground(point) + 0.1, "\(piece.key) never floats", file: file, line: line)
                }
                XCTAssertGreaterThan((at - heart).length - HoldLayout.workRadius, Holds.wallRadius + 0.12,
                                     "\(piece.key) stands outside the walls", file: file, line: line)
                for (other, work) in works {
                    XCTAssertGreaterThanOrEqual((other - at).length, 2 * HoldLayout.workRadius - 1e-3,
                                                "\(piece.key) and \(work.key) stand apart", file: file, line: line)
                }
                works.append((at, piece))
            }
        }
    }

    func testHoldsStandOnTheirLand() {
        for state in PlacementTests.worlds {
            let relief = Relief(map: state.map)
            for hold in state.holds {
                let grand = PlacementTests.grandPlan(hold.position)
                let pieces = HoldLayout.pieces(grand, relief: relief)
                PlacementTests.check(pieces, grand, relief)
                let slots = HoldLayout.slots(grand, relief: relief).count
                let works = pieces.filter { if case .work = $0.key { return true } else if case .study = $0.key { return true } else { return false } }
                XCTAssertEqual(works.count, min(slots, HoldLayout.Work.order.count), "\(hold.position): every work that has a slot")
                XCTAssertEqual(pieces.filter { $0.key == .walls(level: 5) }.count, 1)
                // A hold as the rules keep it: just founded, its keep alone.
                let bare = HoldLayout.pieces(hold: hold, relief: relief)
                XCTAssertEqual(bare.map(\.key), [.keep(seat: hold.isSeat)])
            }
        }
    }

    func testTheKeepAndWallsFitTheHex() {
        let layout = HexLayout(size: 1)
        for level in 1...5 {
            let walls = Library.model(.walls(level: level)).mesh
            // Turned as a hold turns them, every stone lies within the hex.
            for front in 0..<6 {
                let turn = Mat4.rotationY(Float.pi / 2 - Float(front) * .pi / 3)
                for vertex in walls.vertices {
                    let p = turn.transformPoint(vertex.position)
                    XCTAssertEqual(layout.hex(atX: Double(p.x), y: Double(p.z)), .origin, "walls \(level) within the hex")
                }
            }
        }
        for seat in [false, true] {
            XCTAssertLessThan(PlacementTests.reach(.keep(seat: seat)), Holds.wallRadius * 0.866 - 0.1, "the keep within its walls")
        }
        for key in Library.catalogue {
            switch key {
            case .work, .study:
                XCTAssertLessThanOrEqual(PlacementTests.reach(key), HoldLayout.workRadius, "\(key) fits its slot")
            default:
                break
            }
        }
    }

    func testAWorkRisesInItsScaffold() throws {
        let state = PlacementTests.worlds[0]
        let relief = Relief(map: state.map)
        let hex = state.holds[0].position
        // A new work: drawn from nothing up, in a scaffold.
        let new = HoldLayout.Plan(hex: hex, isSeat: true, levels: [.building(.walls): 2],
                                  rising: .init(work: .building(.granary), level: 1, progress: 0.25))
        let pieces = HoldLayout.pieces(new, relief: relief)
        PlacementTests.check(pieces, new, relief)
        let granary = try XCTUnwrap(pieces.first { $0.key == .work(.granary, level: 1) })
        XCTAssertEqual(granary.progress, 0.25, accuracy: 1e-5)
        let scaffold = try XCTUnwrap(pieces.first { $0.key == .scaffold })
        XCTAssertEqual(scaffold.position, granary.position)
        let stretch = Vec3(scaffold.transform.c0.x, scaffold.transform.c0.y, scaffold.transform.c0.z).length
        XCTAssertEqual(stretch, HoldLayout.scaffoldWidth, accuracy: 1e-4, "a scaffold as wide as the work's slot allows")
        // An upgrade starts from the height of the level that stands.
        let upgrade = HoldLayout.Plan(hex: hex, isSeat: true, levels: [.building(.moonspire): 3],
                                      rising: .init(work: .building(.moonspire), level: 4, progress: 0))
        let spire = try XCTUnwrap(HoldLayout.pieces(upgrade, relief: relief).first { $0.key == .work(.moonspire, level: 4) })
        XCTAssertGreaterThan(spire.progress, 0.4, "the third stage already stands")
        XCTAssertLessThan(spire.progress, 1)
        let done = HoldLayout.Plan(hex: hex, isSeat: true, levels: [.building(.moonspire): 3],
                                   rising: .init(work: .building(.moonspire), level: 4, progress: 1))
        XCTAssertEqual(HoldLayout.pieces(done, relief: relief).first { $0.key == .work(.moonspire, level: 4) }?.progress, 1)
        // Walls rise in place, without a scaffold.
        let walls = HoldLayout.Plan(hex: hex, isSeat: false, levels: [.building(.walls): 1],
                                    rising: .init(work: .building(.walls), level: 2, progress: 0.5))
        let ring = HoldLayout.pieces(walls, relief: relief)
        XCTAssertEqual(ring.map(\.key), [.keep(seat: false), .walls(level: 2)])
        XCTAssertGreaterThan(ring[1].progress, 0.5)
        // The study rises too.
        let study = HoldLayout.Plan(hex: hex, isSeat: false, rising: .init(work: .study, level: 1, progress: 0.6))
        XCTAssertTrue(HoldLayout.pieces(study, relief: relief).contains { $0.key == .study(level: 1) && $0.progress == 0.6 })
    }

    /// An alliance's hall fills its hex's heart, every stone within the hex
    /// however it is turned; it stands on the lowest of its ground, its
    /// platform from the first, the hall rising above it in a scaffold.
    func testAnAlliancesHallRisesOnItsPlatformWithinItsHex() throws {
        let layout = HexLayout(size: 1)
        let hall = Library.model(.allianceHall).mesh
        for front in 0..<6 {
            let turn = Mat4.rotationY(Float.pi / 2 - Float(front) * .pi / 3)
            for vertex in hall.vertices {
                let p = turn.transformPoint(vertex.position)
                XCTAssertEqual(layout.hex(atX: Double(p.x), y: Double(p.z)), .origin, "the hall within its hex")
            }
        }
        XCTAssertGreaterThan(PlacementTests.reach(.allianceHall), PlacementTests.reach(.keep(seat: true)), "Broader than a seat's keep")
        let state = PlacementTests.worlds[0]
        let relief = Relief(map: state.map)
        let hex = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && hex.distance(to: .origin) > 3
        })
        let whole = HoldLayout.hall(at: hex, progress: 1, relief: relief)
        XCTAssertEqual(whole.map(\.key), [.allianceHall])
        XCTAssertEqual(whole[0].progress, 1)
        XCTAssertNil(whole[0].risen, "Whole, it is drawn whole")
        let centre = Relief.centre(of: hex)
        XCTAssertEqual(whole[0].position.x, centre.x, accuracy: 1e-4)
        XCTAssertEqual(whole[0].position.z, centre.z, accuracy: 1e-4)
        XCTAssertLessThanOrEqual(whole[0].position.y, relief.height(atX: centre.x, z: centre.z) + 1e-4, "On the lowest of its ground")
        XCTAssertEqual(whole[0].smoke.count, 1, "Its louvre smokes")
        // Begun: its platform stands, the hall not yet, a scaffold about it.
        let begun = HoldLayout.hall(at: hex, progress: 0, relief: relief)
        XCTAssertEqual(begun.map(\.key), [.allianceHall, .scaffold])
        let bounds = Library.model(.allianceHall).mesh.bounds
        XCTAssertEqual(try XCTUnwrap(begun[0].risen), Halls.floor, accuracy: 1e-4, "Drawn up to its floor")
        let stretch = Vec3(begun[1].transform.c0.x, begun[1].transform.c0.y, begun[1].transform.c0.z).length
        XCTAssertEqual(stretch, HoldLayout.hallScaffold, accuracy: 1e-4)
        let half = HoldLayout.hall(at: hex, progress: 0.5, relief: relief)
        XCTAssertGreaterThan(try XCTUnwrap(half[0].risen), Halls.floor)
        XCTAssertLessThan(try XCTUnwrap(half[0].risen), bounds.max.y)
        XCTAssertGreaterThan(half[1].transform.c1.y, begun[1].transform.c1.y, "The scaffold climbs with it")
    }

    func testAHoldAsTheRulesKeepIt() throws {
        let state = PlacementTests.worlds[1]
        let relief = Relief(map: state.map)
        var hold = state.holds[0]
        hold.levels = [.granary: 2, .walls: 1, .beacon: 0]
        hold.project = Hold.Project(kind: .granary, targetLevel: 3, watchesLeft: 1)
        let plan = HoldLayout.Plan(hold: hold, study: 2)
        XCTAssertEqual(plan.levels, [.building(.granary): 2, .building(.walls): 1, .study: 2])
        let rising = try XCTUnwrap(plan.rising)
        XCTAssertEqual(rising.work, .building(.granary))
        XCTAssertEqual(rising.level, 3)
        XCTAssertEqual(rising.progress, 1 - 1 / Float(BuildingKind.granary.buildWatches(toLevel: 3)), accuracy: 1e-5)
        XCTAssertEqual(HoldLayout.Plan(hold: hold, progress: 0.3).rising?.progress, 0.3)
        let pieces = HoldLayout.pieces(hold: hold, relief: relief, study: 2, progress: 0.3)
        PlacementTests.check(pieces, plan, relief)
        XCTAssertTrue(pieces.contains { $0.key == .work(.granary, level: 3) })
        XCTAssertTrue(pieces.contains { $0.key == .study(level: 2) })
        XCTAssertTrue(pieces.contains { $0.key == .scaffold })
        XCTAssertTrue(pieces.contains { $0.key == .keep(seat: hold.isSeat) }, "The common keep, its people unnamed")
        // A House's people raise their own keep, in the same place.
        let theirs = HoldLayout.pieces(HoldLayout.Plan(hold: hold, study: 2, progress: 0.3, heritage: .blackwood), relief: relief)
        PlacementTests.check(theirs, HoldLayout.Plan(hold: hold, study: 2, progress: 0.3, heritage: .blackwood), relief)
        let keep = try XCTUnwrap(theirs.first { $0.key == .keepOf(.blackwood, seat: hold.isSeat) })
        XCTAssertEqual(keep.transform, try XCTUnwrap(pieces.first { $0.key == .keep(seat: hold.isSeat) }).transform)
        XCTAssertEqual(theirs.count, pieces.count)
    }

    /// With room for every work, each keeps its place whatever else is
    /// built; each draws toward the ground it works.
    func testWorksKeepTheirPlaces() {
        for state in PlacementTests.worlds {
            let relief = Relief(map: state.map)
            for hold in state.holds {
                let grand = PlacementTests.grandPlan(hold.position)
                guard HoldLayout.slots(grand, relief: relief).count >= HoldLayout.Work.order.count else { continue }
                let everything = HoldLayout.pieces(grand, relief: relief)
                for (work, level) in grand.levels where work != .building(.walls) {
                    let alone = HoldLayout.Plan(hex: hold.position, isSeat: true, levels: [work: level])
                    let piece = HoldLayout.pieces(alone, relief: relief).last
                    XCTAssertEqual(piece?.position, everything.first { $0.key == work.key(level: level) }?.position,
                                   "\(work) stands where it would among all the others")
                }
            }
        }
        XCTAssertEqual(HoldLayout.affinity(.granary, terrain: .greyfield, feature: .darkLoam), 2)
        XCTAssertEqual(HoldLayout.affinity(.sawpit, terrain: .blackwood, feature: nil), 1)
        XCTAssertEqual(HoldLayout.affinity(.quarry, terrain: .barrow, feature: .stoneSeam), 2)
        XCTAssertEqual(HoldLayout.affinity(.saltworks, terrain: .saltFlat, feature: .moonsaltBed), 2)
        XCTAssertEqual(HoldLayout.affinity(.beacon, terrain: .barrow, feature: nil), 0)
    }

    /// A hold on a spit of land between waters has fewer slots: the works it
    /// has share them, the rest unshown.
    func testACrampedHoldPlacesWhatFits() {
        var cramped = 0
        for state in PlacementTests.worlds {
            let relief = Relief(map: state.map)
            for hex in state.map.hexes where HoldLayout.isLand(hex, relief) {
                let neighbours = hex.neighbors.filter { HoldLayout.isLand($0, relief) }.count
                guard neighbours <= 2, neighbours > 0 else { continue }
                let plan = PlacementTests.grandPlan(hex)
                let slots = HoldLayout.slots(plan, relief: relief).count
                let pieces = HoldLayout.pieces(plan, relief: relief)
                PlacementTests.check(pieces, plan, relief)
                XCTAssertLessThanOrEqual(pieces.count - 2, slots)
                let few = HoldLayout.Plan(hex: hex, isSeat: false, levels: [.building(.granary): 1])
                XCTAssertEqual(HoldLayout.pieces(few, relief: relief).count, slots > 0 ? 2 : 1)
                cramped += 1
                if cramped > 12 { return }
            }
        }
        XCTAssertGreaterThan(cramped, 0, "the worlds have narrow land to test")
    }

    func testGatesFaceTheLake() {
        XCTAssertEqual(HoldLayout.frontAngle(of: Hex(3, 0)), .pi, accuracy: 1e-5, "east of the heart, the gate faces west")
        XCTAssertEqual(HoldLayout.frontAngle(of: Hex(-3, 0)), 0, accuracy: 1e-5)
        XCTAssertEqual(HoldLayout.frontAngle(of: .origin), 0, accuracy: 1e-5)
        XCTAssertEqual(HoldLayout.Work.study.key(level: 2), .study(level: 2))
        XCTAssertEqual(HoldLayout.Work.building(.walls).key(level: 4), .walls(level: 4))
    }

    // MARK: The land's furniture

    func testTheLandIsFurnishedTheSameEveryTime() {
        let state = PlacementTests.worlds[0]
        let relief = Relief(map: state.map)
        let first = Scatter.pieces(map: state.map, relief: relief)
        XCTAssertEqual(first, Scatter.pieces(map: state.map, relief: relief), "the same map, the same furniture")
        XCTAssertEqual(first, state.map.hexes.flatMap { Scatter.pieces(in: $0, map: state.map, relief: relief) }, "hex by hex alike")
        XCTAssertGreaterThan(first.count, state.map.count, "the land is furnished")
        XCTAssertEqual(Scatter.pieces(in: Hex(40, 0), map: state.map, relief: relief), [], "nothing beyond the map")
        let kinds = Set(PlacementTests.worlds.flatMap { Scatter.pieces(map: $0.map, relief: Relief(map: $0.map)) }.map(\.key))
        for furnishing in Furnishing.allCases {
            XCTAssertTrue(kinds.contains(.furnishing(furnishing)), "\(furnishing) is found somewhere")
        }
        // Each terrain its own: firs in the blackwood, crags on the Spine, none on the open water.
        for piece in first {
            let terrain = state.map[piece.hex]!.terrain
            switch piece.key {
            case .furnishing(.fir): XCTAssertEqual(terrain, .blackwood)
            case .furnishing(.crag): XCTAssertEqual(terrain, .spine)
            default: XCTAssertNotEqual(terrain, .still)
            }
        }
    }

    func testTheLandsFurnitureStandsOnTheLandAndLeavesHeartsClear() {
        for state in PlacementTests.worlds {
            let relief = Relief(map: state.map)
            let occupied = Set(state.units.map(\.position) + state.map.hexes.enumerated().filter { $0.offset % 5 == 0 }.map(\.element))
            let holds = Set(state.holds.map(\.position))
            let pieces = Scatter.pieces(map: state.map, relief: relief, occupied: occupied, holds: holds)
            let layout = HexLayout(size: 1)
            for piece in pieces {
                let at = piece.position
                XCTAssertEqual(at.y, relief.height(atX: at.x, z: at.z) - Scatter.sink, accuracy: 1e-4, "\(piece.key) stands on the land")
                XCTAssertEqual(layout.hex(atX: Double(at.x), y: Double(at.z)), piece.hex, "\(piece.key) within its hex")
                guard case .furnishing(let furnishing) = piece.key else { return XCTFail("only furniture") }
                let scale = Vec3(piece.transform.c0.x, piece.transform.c0.y, piece.transform.c0.z).length
                let reach = Scatter.footprint(furnishing) * scale
                let here = SIMD2(at.x, at.z)
                for hex in [piece.hex] + piece.hex.neighbors {
                    let centre = Relief.centre(of: hex)
                    let distance = (here - SIMD2(centre.x, centre.z)).length
                    if hex != piece.hex || occupied.contains(hex) || holds.contains(hex) {
                        XCTAssertGreaterThanOrEqual(distance, Scatter.heart + reach - 1e-4, "\(piece.key) leaves \(hex)'s heart clear")
                    }
                }
                for hold in holds {
                    let centre = Relief.centre(of: hold)
                    XCTAssertGreaterThanOrEqual((here - SIMD2(centre.x, centre.z)).length, HoldLayout.reach + reach - 1e-4,
                                                "\(piece.key) leaves the hold at \(hold) its ground")
                }
            }
            // The hold's own pieces are clear of the land's furniture.
            for hold in state.holds {
                let grand = PlacementTests.grandPlan(hold.position)
                for work in HoldLayout.pieces(grand, relief: relief) {
                    let at = SIMD2(work.position.x, work.position.z)
                    XCTAssertFalse(pieces.contains { (SIMD2($0.position.x, $0.position.z) - at).length < HoldLayout.workRadius })
                }
            }
        }
    }
}
