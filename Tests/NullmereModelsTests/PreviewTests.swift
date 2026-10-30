import Foundation
import NullmereCore
@testable import NullmereModels
import XCTest

/// The models as a browser previews them: always made and checked; written
/// out for Tools/model-preview when NULLMERE_MODEL_PREVIEW names a folder.
final class PreviewTests: XCTestCase {
    static func samples() -> [(name: String, model: Model)] {
        var tower = MeshBuilder()
        tower.lathe([(0.32, 0), (0.3, 0.7), (0.36, 0.72), (0.36, 0.8)], sides: 8, color: Vec3(0.62, 0.6, 0.56))
        tower.place(.translation(Vec3(0, 0.8, 0))) { $0.cone(sides: 8, radius: 0.38, to: 0.45, color: Vec3(0.3, 0.3, 0.34)) }
        tower.with(material: .glow) { $0.box(center: Vec3(0, 0.45, 0.31), size: Vec3(0.08, 0.12, 0.02), color: Vec3(1, 0.75, 0.42)) }
        var fir = MeshBuilder()
        fir.prism(sides: 5, radius: 0.03, to: 0.2, color: Vec3(0.22, 0.16, 0.12))
        fir.with(material: .foliage, sway: 1) {
            $0.swayRange = (0.1, 0.8)
            for (index, base) in [Float(0.12), 0.3, 0.46].enumerated() {
                $0.cone(sides: 7, radius: 0.2 - Float(index) * 0.045, from: base, to: base + 0.28, color: Vec3(0.12, 0.2, 0.15))
            }
        }
        var hall = MeshBuilder()
        hall.box(min: Vec3(-0.4, 0, -0.25), max: Vec3(0.4, 0.35, 0.25), color: Vec3(0.5, 0.45, 0.38))
        hall.with(material: .house) { $0.gableRoof(width: 0.8, depth: 0.5, base: 0.35, height: 0.25, color: Vec3(0.6, 0.6, 0.6), overhang: 0.05) }
        return [("tower", Model(name: "tower", mesh: tower.mesh)), ("fir", Model(name: "fir", mesh: fir.mesh)),
                ("hall", Model(name: "hall", mesh: hall.mesh))]
    }

    func testModelsExportForThePreview() throws {
        let samples = PreviewTests.samples()
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
        try write(data, as: "samples.json")

        let state = GameState(settings: GameSettings(seedText: "preview", houseCount: 6, radius: 14))
        let terrain = TerrainMesh(relief: Relief(map: state.map), spacing: 0.35)
        try write(try PreviewExport.json([("land", Model(name: "land", mesh: terrain.mesh))]), as: "land.json")
    }

    private func write(_ data: Data, as name: String) throws {
        guard let folder = ProcessInfo.processInfo.environment["NULLMERE_MODEL_PREVIEW"] else { return }
        let url = URL(fileURLWithPath: folder, isDirectory: true)
        try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        try data.write(to: url.appendingPathComponent(name))
    }
}
