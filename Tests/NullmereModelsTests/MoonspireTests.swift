import NullmereCore
@testable import NullmereModels
import XCTest

/// The Moonspire stands in a court of its own, richer with each stage, and
/// no common estate: within its budget, its crystal turning when crowned.
final class MoonspireTests: XCTestCase {
    func testItsCourtGrowsWithinItsBudget() {
        let models = (1...5).map { Library.model(.work(.moonspire, level: $0)) }
        let counts = models.map(\.mesh.triangleCount)
        XCTAssertTrue(counts.allSatisfy { $0 <= ModelKey.work(.moonspire, level: 1).budget }, "\(counts)")
        XCTAssertEqual(counts, counts.sorted(), "\(counts)")
        XCTAssertGreaterThan(counts[4], 2500)
        for (stage, model) in zip(1..., models) {
            let out = { (p: Vec3) in (p.x * p.x + p.z * p.z).squareRoot() }
            // Obelisks round the plinth's edge, each to a point of moonsalt,
            // one more with each stage up to five, the way to the door open.
            let points = model.mesh.vertices.filter { $0.material == .crystal && (0.19...0.2).contains($0.position.y) && out($0.position) > 0.28 }
            let tips = Set(points.map { "\(Int(($0.position.x * 100).rounded())),\(Int(($0.position.z * 100).rounded()))" })
            XCTAssertEqual(tips.count, min(stage + 1, 5), "Its court's obelisks at stage \(stage)")
            XCTAssertFalse(points.contains { abs($0.position.x) < 0.1 && $0.position.z > 0 }, "No obelisk stands in the way to the door at stage \(stage)")
            // Its braziers burn in the court from the third stage.
            XCTAssertEqual(model.mesh.vertices.contains { $0.material == .glow && out($0.position) > 0.28 }, stage >= 3, "stage \(stage)")
        }
        let crowned = Library.model(.work(.moonspire, level: 5))
        XCTAssertTrue(crowned.motion != nil || crowned.skeleton?.actions[.idle] != nil, "The crowned spire's crystal turns")
        let crown = crowned.rig.index(of: "crown"), halo = crowned.rig.index(of: "halo")
        XCTAssertNotNil(crown)
        XCTAssertNotNil(halo)
        if let crown, let halo {
            XCTAssertNotEqual(crowned.pose(.idle, at: 0)[crown], crowned.pose(.idle, at: 1)[crown], "The crown turns")
            XCTAssertNotEqual(crowned.pose(.idle, at: 0)[halo], crowned.pose(.idle, at: 1)[halo], "Its halo turns")
        }
        // Until it is crowned, the masons' crane slews on the stage last raised.
        for stage in 1...4 {
            let model = models[stage - 1]
            let crane = model.rig.index(of: "crane")
            XCTAssertNotNil(crane, "stage \(stage)")
            if let crane {
                XCTAssertNotEqual(model.pose(.idle, at: 0)[crane], model.pose(.idle, at: 1)[crane], "stage \(stage)")
            }
        }
    }
}
