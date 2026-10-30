import Foundation
import NullmereCore
@testable import NullmereModels
import XCTest

/// The models as a browser previews them: always made and checked; written
/// out for Tools/model-preview when NULLMERE_MODEL_PREVIEW names a folder,
/// as sheets: every model at rest, every clip at moments through it, and
/// the land round a seat with its pieces placed.
final class PreviewTests: XCTestCase {
    static func entries(_ keys: [ModelKey], clip: Clip = .idle, time: Float = 0.3) -> [(name: String, model: Model, clip: Clip, time: Float)] {
        keys.map { (name: $0.description, model: Library.model($0), clip: clip, time: time) }
    }

    func testModelsExportForThePreview() throws {
        let samples: [(name: String, model: Model)] = [ModelKey.figure(.spear, tier: 3), .keep(seat: true), .furnishing(.fir)].map {
            (name: $0.description, model: Library.model($0))
        }
        let data = try PreviewExport.json(samples)
        let decoded = try XCTUnwrap(try JSONSerialization.jsonObject(with: data) as? [String: Any])
        let models = try XCTUnwrap(decoded["models"] as? [[String: Any]])
        XCTAssertEqual(models.count, samples.count)
        for (entry, sample) in zip(models, samples) {
            XCTAssertEqual(entry["name"] as? String, sample.name)
            XCTAssertEqual((entry["positions"] as? [Double])?.count, sample.model.mesh.vertices.count * 3)
            XCTAssertEqual((entry["indices"] as? [Int])?.count, sample.model.mesh.indices.count)
            XCTAssertEqual((entry["pose"] as? [[Double]])?.count, sample.model.rig.count)
        }
    }

    /// Every model in the catalogue, in sheets by family, and each clip of a
    /// figure of every kind at moments through it.
    func testTheCatalogueExportsForThePreview() throws {
        guard ProcessInfo.processInfo.environment["NULLMERE_MODEL_PREVIEW"] != nil else { return }
        let keys = Library.catalogue
        func family(_ test: (ModelKey) -> Bool) -> [ModelKey] { keys.filter(test) }
        let figures = family {
            switch $0 {
            case .figure, .signature, .wild, .commander: return true
            default: return false
            }
        }
        let holds = family {
            switch $0 {
            case .keep, .keepOf, .walls, .scaffold: return true
            default: return false
            }
        }
        let works = family {
            switch $0 {
            case .work, .study: return true
            default: return false
            }
        }
        let land = family {
            switch $0 {
            case .furnishing, .site, .prop, .shrine, .lair, .standard: return true
            default: return false
            }
        }
        let counts = keys.map { key -> String in
            let model = Library.model(key)
            return "\(key)\t\(model.mesh.triangleCount)\t\(model.rig.count)\t\(key.budget)"
        }
        try write(Data((["model\ttriangles\tparts\tbudget"] + counts).joined(separator: "\n").utf8), as: "counts.tsv")
        try write(try PreviewExport.json(PreviewTests.entries(figures)), as: "figures.json")
        // The figures side by side at their true sizes, at idle.
        var lineup = Mesh()
        for (index, key) in figures.enumerated() {
            let at = Vec3(Float(index % 9) * 0.5, 0, Float(index / 9) * 0.7)
            lineup.append(PreviewTests.posed(Library.model(key), .idle, 0.3), transform: .translation(at))
        }
        try write(try PreviewExport.json([("lineup", Model(name: "lineup", mesh: lineup))]), as: "lineup.json")
        try write(try PreviewExport.json(PreviewTests.entries(holds)), as: "holds.json")
        try write(try PreviewExport.json(PreviewTests.entries(works)), as: "works.json")
        try write(try PreviewExport.json(PreviewTests.entries(land)), as: "land.json")

        let actors: [ModelKey] = [.figure(.spear, tier: 1), .figure(.spear, tier: 5), .figure(.bow, tier: 3), .figure(.rider, tier: 3),
                                  .figure(.lantern, tier: 1), .figure(.founder, tier: 1), .wild(tier: 1), .wild(tier: 3),
                                  .commander(variant: 1), .prop(.bird), .prop(.cart), .work(.sawpit, level: 3)]
        for clip in Clip.allCases {
            let moments: [Float] = (0..<4).map { clip.period * Float($0) / (clip.loops ? 4 : 3) }
            var entries: [(name: String, model: Model, clip: Clip, time: Float)] = []
            for key in actors {
                for moment in moments {
                    entries.append((name: "\(key) \(clip.rawValue) \(moment)", model: Library.model(key), clip: clip, time: moment))
                }
            }
            try write(try PreviewExport.json(entries), as: "clip-\(clip.rawValue).json")
        }

        let state = GameState(settings: GameSettings(seedText: "preview", houseCount: 6, radius: 14))
        let terrain = TerrainMesh(relief: Relief(map: state.map), spacing: 0.35)
        try write(try PreviewExport.json([("terrain", Model(name: "terrain", mesh: terrain.mesh))]), as: "terrain.json")
        try write(try PreviewExport.json([("companies", Model(name: "companies", mesh: PreviewTests.companies()))]), as: "companies.json")
        for (index, seat) in state.holds.prefix(2).enumerated() {
            try write(try PreviewExport.json([("scene", Model(name: "scene", mesh: PreviewTests.scene(state, around: seat.position,
                                                                                                        grand: index == 0)))]),
                      as: "scene\(index).json")
        }
    }

    /// Every company whole in its own hex, in formation, and some led by
    /// each commander or worn down: how they read from above.
    static func companies() -> Mesh {
        let keys = Library.catalogue.filter {
            switch $0 {
            case .figure, .signature, .wild: return true
            default: return false
            }
        }
        var entries: [(key: ModelKey, health: Int, led: Int?)] = keys.map { ($0, 100, nil) }
        entries += [(.figure(.spear, tier: 3), 100, 0), (.figure(.bow, tier: 4), 70, 1), (.figure(.rider, tier: 5), 100, 2),
                    (.figure(.lantern, tier: 1), 100, 3), (.figure(.founder, tier: 1), 100, 4), (.figure(.spear, tier: 5), 40, 5)]
        var mesh = Mesh()
        for (index, entry) in entries.enumerated() {
            let row = index / 6, column = index % 6
            let hex = Hex(column - row / 2, row)
            let centre = Relief.centre(of: hex)
            var tile = MeshBuilder()
            tile.polygon((0..<6).map { MeshBuilder.ring(0.97, 0, Float($0) * .pi / 3 + .pi / 6) },
                         color: TerrainMesh.colour(row % 2 == 0 ? .greyfield : .strand))
            mesh.append(tile.mesh, transform: .translation(Vec3(centre.x, 0, centre.z)))
            var figures = Formation.offsets(entry.key, health: entry.health, led: entry.led != nil).map { (entry.key, $0) }
            if let variant = entry.led {
                figures.append((.commander(variant: variant), Formation.commander(entry.key, health: entry.health)))
            }
            for (key, offset) in figures {
                mesh.append(posed(Library.model(key), .idle, 0.6), transform: .translation(Vec3(centre.x, 0, centre.z) + offset))
            }
        }
        return mesh
    }

    /// The land round a seat with its hold laid out, the land's furniture
    /// and a few companies, baked into one mesh.
    static func scene(_ state: GameState, around seat: Hex, grand: Bool) -> Mesh {
        let relief = Relief(map: state.map)
        var levels: [HoldLayout.Work: Int] = [.building(.walls): grand ? 5 : 2, .building(.granary): grand ? 5 : 1,
                                              .building(.sawpit): 3, .building(.quarry): grand ? 5 : 2, .building(.musterHall): 3]
        if grand {
            levels[.building(.saltworks)] = 4
            levels[.building(.beacon)] = 3
            levels[.study] = 5
            levels[.building(.moonspire)] = 3
        }
        let rising = HoldLayout.Plan.Rising(work: grand ? .building(.moonspire) : .building(.beacon), level: grand ? 4 : 1, progress: 0.4)
        let plan = HoldLayout.Plan(hex: seat, isSeat: true, levels: levels, rising: rising)
        var pieces = HoldLayout.pieces(plan, relief: relief)
        // Companies on land a little way out, facing the hold.
        let companies: [(key: ModelKey, health: Int, led: Int?)] = [
            (.figure(.spear, tier: 5), 100, 0), (.figure(.bow, tier: 3), 80, nil), (.figure(.rider, tier: 4), 100, 4),
            (.figure(.spear, tier: 2), 45, nil), (.wild(tier: 2), 100, nil), (.figure(.founder, tier: 1), 100, nil),
            (.wild(tier: 3), 100, nil), (.figure(.lantern, tier: 1), 100, 1),
        ]
        let ground = seat.ring(3).filter { HoldLayout.isLand($0, relief) }
        var occupied: Set<Hex> = []
        for (company, hex) in zip(companies, ground.enumerated().filter { $0.offset % 2 == 0 }.map(\.element)) {
            occupied.insert(hex)
            let centre = Relief.centre(of: hex), heart = Relief.centre(of: seat)
            let heading = Float(atan2(Double(heart.x - centre.x), Double(heart.z - centre.z)))
            let turn = Mat4.rotationY(heading)
            var figures = Formation.offsets(company.key, health: company.health, led: company.led != nil).map { (company.key, $0) }
            if let variant = company.led {
                figures.append((.commander(variant: variant), Formation.commander(company.key, health: company.health)))
            }
            for (key, offset) in figures {
                let at = Vec3(centre.x, 0, centre.z) + turn.transformDirection(offset)
                let y = relief.height(atX: at.x, z: at.z)
                pieces.append(Piece(key: key, transform: .translation(Vec3(at.x, y, at.z)) * turn, hex: hex))
            }
        }
        let near = state.map.hexes.filter { $0.distance(to: seat) <= 5 }
        for hex in near {
            pieces += Scatter.pieces(in: hex, map: state.map, relief: relief, clearHeart: occupied.contains(hex) || hex == seat,
                                     holds: [seat])
        }
        var mesh = Mesh()
        let centre = Relief.centre(of: seat)
        let land = TerrainMesh(relief: relief, spacing: 0.25).mesh
        for (a, b, c) in land.triangles {
            let p = a.position
            guard (p.x - centre.x) * (p.x - centre.x) + (p.z - centre.z) * (p.z - centre.z) < 70 else { continue }
            for var corner in [a, b, c] {
                corner.part = 0
                // The still water's face, drawn over the lake bed.
                if corner.position.y < Relief.waterline {
                    corner.position.y = Relief.waterline - 0.002
                    corner.color = Vec3(0.05, 0.06, 0.07)
                    corner.normal = .up
                }
                mesh.vertices.append(corner)
                mesh.indices.append(UInt32(mesh.vertices.count - 1))
            }
        }
        for piece in pieces {
            mesh.append(posed(Library.model(piece.key), .idle, 0.6), transform: piece.transform)
        }
        // About the seat's heart, for the preview to look at.
        var centred = Mesh()
        centred.append(mesh, transform: .translation(Vec3(-centre.x, 0, -centre.z)))
        return centred
    }

    /// A model's mesh as it stands at a moment of a clip, all in one part.
    static func posed(_ model: Model, _ clip: Clip, _ time: Float) -> Mesh {
        let pose = model.pose(clip, at: time)
        var mesh = model.mesh
        for index in mesh.vertices.indices {
            let m = pose[Int(mesh.vertices[index].part)]
            mesh.vertices[index].position = m.transformPoint(mesh.vertices[index].position)
            mesh.vertices[index].normal = m.normalMatrix.transformDirection(mesh.vertices[index].normal).normalized
            mesh.vertices[index].part = 0
        }
        return mesh
    }

    private func write(_ data: Data, as name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["NULLMERE_MODEL_PREVIEW"] else { return }
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try data.write(to: url.appendingPathComponent(name))
    }
}
