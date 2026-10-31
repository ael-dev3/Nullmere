import Dispatch
import Foundation
import NullmereCore
@testable import NullmereModels
import XCTest

/// What every model in the library must be: sound geometry within its
/// budget, parts within its rig, the same however often it is built, and
/// told apart from its kin.
final class CatalogueTests: XCTestCase {
    static let keys = Library.catalogue

    static func isCompany(_ key: ModelKey) -> Bool {
        switch key {
        case .figure, .signature, .wild, .commander: return true
        default: return false
        }
    }

    /// The materials the renderer shows in a House's colour.
    static let housely: Set<Material> = [.house, .cloth]

    /// The surface of a model's triangles in these materials.
    static func area(_ mesh: Mesh, _ materials: Set<Material>) -> Float {
        mesh.triangles.reduce(0) { total, triangle in
            guard materials.contains(triangle.0.material) else { return total }
            return total + (triangle.1.position - triangle.0.position).cross(triangle.2.position - triangle.0.position).length / 2
        }
    }

    /// The cells of a coarse grid a model's surface passes through, with
    /// what shows there: the House's colour, steel, or anything else. Its
    /// look from afar, roughly.
    static func cells(_ mesh: Mesh, size: Float = 0.03) -> Set<SIMD4<Int32>> {
        var cells: Set<SIMD4<Int32>> = []
        for (a, b, c) in mesh.triangles {
            let look: Int32 = CatalogueTests.housely.contains(a.material) ? 1 : a.material == .metal ? 2 : 0
            for (u, v) in [(Float(0), Float(0)), (1, 0), (0, 1), (0.33, 0.33), (0.5, 0), (0, 0.5), (0.5, 0.5)] {
                let p = a.position + (b.position - a.position) * u + (c.position - a.position) * v
                cells.insert(SIMD4<Int32>(Int32((p.x / size).rounded(.down)), Int32((p.y / size).rounded(.down)),
                                          Int32((p.z / size).rounded(.down)), look))
            }
        }
        return cells
    }

    static func unlike(_ a: Set<SIMD4<Int32>>, _ b: Set<SIMD4<Int32>>) -> Float {
        1 - Float(a.intersection(b).count) / Float(max(a.union(b).count, 1))
    }

    func testTheCatalogueNamesEveryModelOnce() {
        let keys = CatalogueTests.keys
        XCTAssertEqual(Set(keys).count, keys.count, "each key once")
        XCTAssertTrue(keys.allSatisfy { $0.canonical == $0 }, "each its own canonical key")
        XCTAssertEqual(Set(keys.map(\.description)).count, keys.count, "each named apart")
        // Every kind at every tier, every work at every level, every furnishing, site and prop.
        for kind in UnitKind.allCases {
            for tier in 1...ModelKey.tiers(of: kind) {
                XCTAssertTrue(keys.contains(.figure(kind, tier: tier)))
            }
        }
        for kind in BuildingKind.allCases {
            for level in 1...kind.maxLevel {
                XCTAssertTrue(keys.contains(ModelKey.work(kind, level: level).canonical), "\(kind) \(level)")
            }
        }
        XCTAssertTrue(Furnishing.allCases.allSatisfy { keys.contains(.furnishing($0)) })
        XCTAssertTrue(Prop.allCases.allSatisfy { keys.contains(.prop($0)) })
        XCTAssertTrue(Resource.allCases.allSatisfy { keys.contains(.site($0)) })
        XCTAssertEqual(keys.filter { if case .wild = $0 { return true } else { return false } }.count, 3)
        XCTAssertEqual(keys.filter { if case .commander = $0 { return true } else { return false } }.count, 6)
        XCTAssertEqual(keys.filter { if case .study = $0 { return true } else { return false } }.count, 5)
        XCTAssertTrue(keys.contains(.keep(seat: true)) && keys.contains(.keep(seat: false)) && keys.contains(.scaffold))
    }

    func testKeysOutOfRangeDrawTheNearestModel() {
        XCTAssertEqual(ModelKey.figure(.spear, tier: 9).canonical, .figure(.spear, tier: 5))
        XCTAssertEqual(ModelKey.figure(.bow, tier: 0).canonical, .figure(.bow, tier: 1))
        XCTAssertEqual(ModelKey.figure(.lantern, tier: 4).canonical, .figure(.lantern, tier: 1))
        XCTAssertEqual(ModelKey.walls(level: 0).canonical, .walls(level: 1))
        XCTAssertEqual(ModelKey.work(.walls, level: 3).canonical, .walls(level: 3))
        XCTAssertEqual(ModelKey.work(.beacon, level: 5).canonical, .work(.beacon, level: 3))
        XCTAssertEqual(ModelKey.wild(tier: 7).canonical, .wild(tier: 3))
        XCTAssertEqual(ModelKey.commander(variant: 8).canonical, .commander(variant: 2))
        XCTAssertEqual(ModelKey.commander(variant: -1).canonical, .commander(variant: 5))
        XCTAssertEqual(ModelKey.study(level: 12).canonical, .study(level: 5))
        XCTAssertEqual(ModelKey.site(.stone).canonical, .site(.stone))
        XCTAssertEqual(Library.model(.figure(.rider, tier: 40)).mesh, Library.model(.figure(.rider, tier: 5)).mesh)
        XCTAssertEqual(Library.model(.work(.walls, level: 2)).mesh, Library.model(.walls(level: 2)).mesh)
        XCTAssertEqual(Works.build(.walls, level: 2, name: "walls 2").mesh, Library.model(.walls(level: 2)).mesh)
        XCTAssertEqual([ModelKey.site(.grain), .wild(tier: 2), .commander(variant: 4), .study(level: 3)].map(\.description),
                       ["grain site", "wild 2", "commander 4", "study 3"])
        XCTAssertEqual(Library.model(.study(level: 2)).name, "study 2")
    }

    func testEveryMeshIsSound() {
        for key in CatalogueTests.keys {
            let model = Library.model(key)
            let mesh = model.mesh
            XCTAssertFalse(mesh.isEmpty, "\(key) has triangles")
            XCTAssertEqual(mesh.indices.count % 3, 0, "\(key)")
            XCTAssertTrue(mesh.indices.allSatisfy { Int($0) < mesh.vertices.count }, "\(key)'s indices in range")
            for vertex in mesh.vertices {
                let values = [vertex.position.x, vertex.position.y, vertex.position.z, vertex.normal.x, vertex.normal.y, vertex.normal.z]
                XCTAssertTrue(values.allSatisfy(\.isFinite), "\(key) has no NaN")
                XCTAssertEqual(vertex.normal.length, 1, accuracy: 1e-3, "\(key)'s normals are unit length")
                XCTAssertTrue((0...1).contains(vertex.color.x) && (0...1).contains(vertex.color.y) && (0...1).contains(vertex.color.z),
                              "\(key)'s colours are albedo")
                XCTAssertTrue((0...1).contains(vertex.sway), "\(key)'s sway")
                XCTAssertLessThan(Int(vertex.part), model.rig.count, "\(key)'s parts within its rig")
            }
            var turned = 0
            for (a, b, c) in mesh.triangles {
                let n = (b.position - a.position).cross(c.position - a.position)
                XCTAssertGreaterThan(n.length, 0, "\(key) has no flat triangle")
                if n.normalized.dot(a.normal) < 0.99 || b.normal != a.normal || c.normal != a.normal {
                    turned += 1
                }
            }
            XCTAssertEqual(turned, 0, "\(key)'s winding agrees with its normals")
            XCTAssertLessThanOrEqual(mesh.triangleCount, key.budget, "\(key) keeps its budget")
            XCTAssertLessThanOrEqual(model.rig.count, 24, "\(key)'s rig")
            XCTAssertEqual(model.name, key.description)
            XCTAssertTrue(mesh.packed.map(\.material).allSatisfy { $0 != nil }, "\(key) packs for the GPU")
        }
    }

    func testBudgetsByFamily() {
        XCTAssertEqual(ModelKey.figure(.spear, tier: 1).budget, 700)
        XCTAssertEqual(ModelKey.wild(tier: 3).budget, 700)
        XCTAssertEqual(ModelKey.commander(variant: 0).budget, 700)
        XCTAssertEqual(ModelKey.furnishing(.fir).budget, 300)
        XCTAssertEqual(ModelKey.prop(.puff).budget, 300)
        XCTAssertEqual(ModelKey.work(.granary, level: 5).budget, 3000)
        XCTAssertEqual(ModelKey.walls(level: 5).budget, 3000)
        XCTAssertEqual(ModelKey.keep(seat: true).budget, 4500)
        XCTAssertEqual(ModelKey.site(.timber).budget, 3000)
        XCTAssertEqual(ModelKey.study(level: 5).budget, 3000)
        XCTAssertEqual(ModelKey.scaffold.budget, 3000)
    }

    func testEveryModelIsTheSameEachTimeItIsBuilt() {
        for key in CatalogueTests.keys {
            let once = Library.build(key), twice = Library.build(key), kept = Library.model(key)
            XCTAssertEqual(once.mesh, twice.mesh, "\(key)")
            XCTAssertEqual(once.rig, twice.rig, "\(key)")
            XCTAssertEqual(once.mesh, kept.mesh, "\(key)")
            for clip in Clip.allCases {
                for time in [Float(0), 0.37, 1.9] {
                    XCTAssertEqual(once.pose(clip, at: time), twice.pose(clip, at: time), "\(key) \(clip)")
                }
            }
        }
    }

    func testTheLibraryBuildsEachOnceForEveryThread() {
        let keys = Array(CatalogueTests.keys.prefix(40))
        let results = Results()
        DispatchQueue.concurrentPerform(iterations: 8) { worker in
            for (index, key) in keys.enumerated() where (index + worker) % 2 == 0 {
                results.add(key, Library.model(key).mesh.triangleCount)
            }
        }
        for key in keys {
            XCTAssertEqual(Set(results.counts[key] ?? []), [Library.model(key).mesh.triangleCount], "\(key)")
        }
    }

    /// Each heritage's own company: its kind's body, rig, ranks and pace at
    /// the fifth tier, in its people's own gear, none like another's.
    func testEachHeritagesOwnCompanyIsItsKindInItsOwnGear() throws {
        var looks: [[Vec3]] = []
        for heritage in Heritage.allCases {
            let key = ModelKey.signature(heritage)
            let plain = ModelKey.figure(heritage.signature, tier: 5)
            let own = Library.model(key), base = Library.model(plain)
            XCTAssertEqual(own.rig.count, base.rig.count, "\(heritage) moves as its kind does")
            XCTAssertNotNil(own.motion)
            let colours = own.mesh.vertices.map(\.color)
            XCTAssertNotEqual(colours, base.mesh.vertices.map(\.color), "\(heritage) in its own gear")
            XCTAssertFalse(looks.contains(colours), "\(heritage) like no other")
            looks.append(colours)
            XCTAssertEqual(key.marchSpeed, plain.marchSpeed)
            XCTAssertEqual(Formation.offsets(key, health: 100), Formation.offsets(plain, health: 100))
            XCTAssertEqual(key.canonical, key)
            XCTAssertLessThanOrEqual(own.mesh.triangleCount, key.budget, "\(heritage)")
            XCTAssertEqual(ModelKey.company(heritage.signature, tier: 5, heritage: heritage), key)
            XCTAssertEqual(ModelKey.company(heritage.signature, tier: 4, heritage: heritage), .figure(heritage.signature, tier: 4))
            let other = try XCTUnwrap(UnitKind.allCases.first { $0.isMilitary && $0 != heritage.signature })
            XCTAssertEqual(ModelKey.company(other, tier: 5, heritage: heritage), .figure(other, tier: 5))
            XCTAssertEqual(ModelKey.company(.lantern, tier: 1, heritage: heritage), .figure(.lantern, tier: 1))
        }
    }

    /// Each people builds its keep its own way, its walls, roof and crown
    /// over the common keep's shape; the common keep is as it was.
    func testEachPeopleBuildsItsKeepItsOwnWay() {
        var looks: [[Vec3]] = []
        for heritage in Heritage.allCases {
            for seat in [false, true] {
                let key = ModelKey.keepOf(heritage, seat: seat)
                let own = Library.model(key).mesh, common = Library.model(.keep(seat: seat)).mesh
                let colours = own.vertices.map(\.color)
                XCTAssertNotEqual(colours, common.vertices.map(\.color), "\(key) is not the common keep")
                XCTAssertFalse(looks.contains(colours), "\(key) like no other")
                looks.append(colours)
                XCTAssertTrue(own.vertices.contains { $0.material == .house }, "\(key) keeps its House's roof and banner")
                XCTAssertEqual(Library.smoke(of: key), Library.smoke(of: .keep(seat: seat)))
                XCTAssertTrue(own.vertices.contains { $0.surface == .stone || $0.surface == .timber }, "\(key)'s walls keep their grain")
                XCTAssertEqual(key.canonical, key)
            }
        }
        func mesh(_ heritage: Heritage) -> Mesh { Library.model(.keepOf(heritage, seat: true)).mesh }
        XCTAssertTrue(mesh(.saltborn).vertices.contains { $0.material == .crystal }, "Moonsalt crowns the Saltborn's")
        XCTAssertTrue(mesh(.saltborn).vertices.contains { $0.color == Palette.saltCrust && $0.surface == .stone })
        XCTAssertTrue(mesh(.strandfolk).vertices.contains { $0.material == .glow && $0.color == Palette.fire }, "A beacon burns on the Strandfolk's")
        XCTAssertTrue(mesh(.moundClans).vertices.contains { $0.color == Palette.moss && $0.surface == .earth }, "Turf on the Mound Clans'")
        XCTAssertTrue(mesh(.blackwood).vertices.contains { $0.color == Palette.barkBlack && $0.surface == .timber }, "Shingle on the Blackwood's")
        XCTAssertGreaterThan(mesh(.blackwood).bounds.max.y, Library.model(.keep(seat: true)).mesh.bounds.max.y - 0.001)
        XCTAssertEqual(Library.model(.keep(seat: true)).mesh, Holds.keep(seat: true, name: "seat keep").mesh, "The common keep as it was")
    }

    func testFiguresAndKeepsWearTheirHouse() {
        for key in CatalogueTests.keys {
            let materials = Set(Library.model(key).mesh.vertices.map(\.material))
            switch key {
            case .figure, .signature, .commander, .keep, .keepOf, .folk:
                XCTAssertTrue(materials.contains(.house), "\(key) wears its House's colour")
            case .wild:
                XCTAssertTrue(materials.isDisjoint(with: CatalogueTests.housely), "\(key) answers to no House")
                XCTAssertTrue(materials.contains(.glow), "\(key)'s eyes are lit")
            default:
                break
            }
        }
        // Walls from the fifth level fly the House's colours; works raised high show them too.
        XCTAssertTrue(Library.model(.walls(level: 5)).mesh.vertices.contains { $0.material == .house })
        XCTAssertTrue(Library.model(.work(.moonspire, level: 5)).mesh.vertices.contains { CatalogueTests.housely.contains($0.material) })
        // Banners, pennants and cloaks are the House's cloth, rippling from where they hang.
        for key: ModelKey in [.prop(.banner), .figure(.spear, tier: 5), .keep(seat: true), .commander(variant: 4)] {
            let cloth = Library.model(key).mesh.vertices.filter { $0.material == .cloth }
            XCTAssertFalse(cloth.isEmpty, "\(key) flies cloth")
            XCTAssertGreaterThan(cloth.map(\.sway).max() ?? 0, 0.5, "\(key)'s cloth moves at its end")
            XCTAssertLessThan(cloth.map(\.sway).min() ?? 1, 0.1, "\(key)'s cloth is held where it hangs")
        }
    }

    func testLanternsAndFiresGiveLight() {
        let lantern = Library.model(.figure(.lantern, tier: 1))
        let glowing = lantern.mesh.vertices.filter { $0.material == .glow }
        XCTAssertFalse(glowing.isEmpty, "a lantern is lit")
        XCTAssertTrue(glowing.allSatisfy { $0.part == Limb.extra }, "the light is in the lantern")
        XCTAssertGreaterThan(glowing.map(\.position.y).min() ?? 0, 0.25, "carried high")
        for key: ModelKey in [.work(.beacon, level: 1), .work(.beacon, level: 3), .prop(.brazier), .keep(seat: false), .commander(variant: 1),
                              .work(.moonspire, level: 5), .study(level: 1)] {
            XCTAssertTrue(Library.model(key).mesh.vertices.contains { $0.material == .glow }, "\(key) gives light")
        }
        for key: ModelKey in [.furnishing(.saltCrystals), .site(.moonsalt), .work(.saltworks, level: 1), .wild(tier: 3)] {
            XCTAssertTrue(Library.model(key).mesh.vertices.contains { $0.material == .crystal }, "\(key) has moonsalt")
        }
        XCTAssertTrue(Library.model(.furnishing(.fir)).mesh.vertices.contains { $0.material == .foliage && $0.sway > 0.5 })
    }

    /// From a padded coat and a bare spear to plate, crests, the House's
    /// cloaks and shields: each tier shows more steel and more of its House.
    func testEachTierIsBetterEquipped() {
        for kind in [UnitKind.spear, .bow, .rider] {
            var last: Float = 0
            for tier in 1...5 {
                let mesh = Library.model(.figure(kind, tier: tier)).mesh
                let gear = CatalogueTests.area(mesh, CatalogueTests.housely.union([.metal]))
                XCTAssertGreaterThan(gear, last * 1.08, "\(kind) \(tier) is better equipped than the tier below")
                last = gear
            }
            let first = CatalogueTests.area(Library.model(.figure(kind, tier: 1)).mesh, CatalogueTests.housely)
            let fifth = CatalogueTests.area(Library.model(.figure(kind, tier: 5)).mesh, CatalogueTests.housely)
            XCTAssertGreaterThan(fifth, first * 3, "\(kind)'s fifth tier is clad in its House's colours")
        }
    }

    /// Kinds and tiers read apart: their shapes differ, not just their colours.
    func testKindsAndTiersAreToldApart() {
        let companies = CatalogueTests.keys.filter(CatalogueTests.isCompany)
        let shapes = companies.map { CatalogueTests.cells(Library.model($0).mesh) }
        for i in companies.indices {
            for j in companies.indices where j > i {
                let unlike = CatalogueTests.unlike(shapes[i], shapes[j])
                XCTAssertGreaterThan(unlike, 0.15, "\(companies[i]) and \(companies[j]) differ in look")
            }
        }
        // At the same tier, each kind is far from every other.
        for tier in [1, 3, 5] {
            let kinds = [ModelKey.figure(.spear, tier: tier), .figure(.bow, tier: tier), .figure(.rider, tier: tier)]
            for i in kinds.indices {
                for j in kinds.indices where j > i {
                    let unlike = CatalogueTests.unlike(CatalogueTests.cells(Library.model(kinds[i]).mesh),
                                                       CatalogueTests.cells(Library.model(kinds[j]).mesh))
                    XCTAssertGreaterThan(unlike, 0.35, "\(kinds[i]) and \(kinds[j]) read apart")
                }
            }
        }
        // Every model differs from every other.
        let meshes = CatalogueTests.keys.map { Library.model($0).mesh }
        for i in meshes.indices {
            for j in meshes.indices where j > i {
                XCTAssertNotEqual(meshes[i], meshes[j], "\(CatalogueTests.keys[i]) and \(CatalogueTests.keys[j])")
            }
        }
    }

    /// The things that move have rigs to move them; the land's furniture
    /// stands still.
    func testWhatMovesHasARig() {
        for key in CatalogueTests.keys {
            let model = Library.model(key)
            switch key {
            case .figure, .signature, .wild, .commander, .folk:
                XCTAssertNotNil(model.motion, "\(key)")
                XCTAssertGreaterThanOrEqual(model.rig.count, 17, "\(key) has a body's parts")
            case .furnishing, .scaffold, .site, .keep, .keepOf, .walls, .prop(.arrow), .shrine, .lair, .standard, .allianceHall, .yard(.grain),
                 .town:
                XCTAssertNil(model.motion, "\(key) stands still")
            case .prop:
                XCTAssertNotNil(model.motion, "\(key)")
            case .work, .study, .storehouse, .yard:
                break
            }
        }
        for key: ModelKey in [.work(.sawpit, level: 3), .work(.quarry, level: 3), .work(.beacon, level: 1), .work(.saltworks, level: 2),
                              .work(.moonspire, level: 5), .study(level: 3), .study(level: 5), .work(.forge, level: 1),
                              .work(.forge, level: 5), .storehouse, .yard(.timber), .yard(.stone), .yard(.moonsalt)] {
            XCTAssertNotNil(Library.model(key).motion, "\(key) has an idle motion")
        }
        // A rider is one model: horse and rider, the rider's parts on the horse's back.
        let rider = Library.model(.figure(.rider, tier: 3)).rig
        XCTAssertEqual(rider.count, 24)
        XCTAssertEqual(rider.bones[Int(Steed.seat)].parent, Int(Steed.body))
    }

    func testSmokeRisesFromChimneys() {
        for key in CatalogueTests.keys {
            let mesh = Library.model(key).mesh
            for point in Library.smoke(of: key) {
                XCTAssertTrue(mesh.vertices.contains { ($0.position - point).length < 0.05 && $0.position.y <= point.y + 1e-3 },
                              "\(key)'s smoke rises from the top of a chimney")
            }
        }
        XCTAssertEqual(Library.smoke(of: .keep(seat: true)).count, 1)
        XCTAssertEqual(Library.smoke(of: .work(.saltworks, level: 3)).count, 1)
        XCTAssertEqual(Library.smoke(of: .work(.saltworks, level: 1)), [], "no furnace yet")
        XCTAssertEqual(Library.smoke(of: .figure(.spear, tier: 1)), [])
        let piece = Piece(key: .keep(seat: false), transform: .translation(Vec3(2, 1, 0)), hex: .origin)
        XCTAssertEqual(piece.smoke, [Holds.chimney(seat: false) + Vec3(2, 1, 0)])
    }

    func testPiecesSayWhereTheyStand() {
        let piece = Piece(key: .scaffold, transform: .translation(Vec3(1, 2, 3)), hex: Hex(4, 5))
        XCTAssertEqual(piece.position, Vec3(1, 2, 3))
        XCTAssertEqual(piece.progress, 1, "whole unless rising")
        XCTAssertNil(piece.risen, "a whole piece is drawn whole")
        let spire = Piece(key: .work(.moonspire, level: 5), transform: .identity, hex: .origin, progress: 0.25)
        let bounds = Library.model(spire.key).mesh.bounds
        XCTAssertEqual(spire.progress, 0.25)
        XCTAssertEqual(spire.risen ?? 0, bounds.min.y + 0.25 * (bounds.max.y - bounds.min.y), accuracy: 1e-5)
        XCTAssertEqual(Piece(key: spire.key, transform: .identity, hex: .origin, progress: 0).risen, bounds.min.y, "begun from its footings")
    }
}

/// Counts gathered from many threads.
private final class Results: @unchecked Sendable {
    private let lock = NSLock()
    private(set) var counts: [ModelKey: [Int]] = [:]

    func add(_ key: ModelKey, _ count: Int) {
        lock.lock()
        counts[key, default: []].append(count)
        lock.unlock()
    }
}
