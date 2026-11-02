import NullmereCore
@testable import NullmereModels
import XCTest

/// A work rising stands with its family's own rig beside its scaffold,
/// its builders at work; a work standing whole has none.
final class RaisingTests: XCTestCase {
    func testAWorkRisesWithItsFamilysRigAtWork() throws {
        let relief = Relief(map: GameState(settings: GameSettings(seedText: "raising", keepers: 1)).map)
        let seat = Hex(0, 0)
        for kind in Raising.families {
            let rising = HoldLayout.Plan(hex: seat, isSeat: true, levels: [.building(kind): 1],
                                         rising: HoldLayout.Plan.Rising(work: .building(kind), level: 2, progress: 0.4))
            let keys = HoldLayout.pieces(rising, relief: relief).map(\.key)
            XCTAssertTrue(keys.contains(.raising(kind)), "\(kind) rises with its rig")
            XCTAssertTrue(keys.contains(.scaffold))
            let whole = HoldLayout.Plan(hex: seat, isSeat: true, levels: [.building(kind): 2])
            XCTAssertFalse(HoldLayout.pieces(whole, relief: relief).map(\.key).contains(.raising(kind)), "\(kind) whole, its rig gone")

            let model = Library.model(.raising(kind))
            XCTAssertLessThanOrEqual(model.mesh.triangleCount, ModelKey.raising(kind).budget)
            let motion = try XCTUnwrap(model.motion)
            XCTAssertNotEqual(motion(.idle, 0), motion(.idle, 0.4), "\(kind)'s rig works")
        }
        XCTAssertEqual(ModelKey.raising(.lodge).description, "raising lodge")
        // A family with no rig of its own rises in the scaffold alone.
        let granary = HoldLayout.Plan(hex: seat, isSeat: true, levels: [.building(.granary): 1],
                                      rising: HoldLayout.Plan.Rising(work: .building(.granary), level: 2, progress: 0.4))
        XCTAssertFalse(HoldLayout.pieces(granary, relief: relief).map(\.key).contains(.raising(.granary)))
    }
}
