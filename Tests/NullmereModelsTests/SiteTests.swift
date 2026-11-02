import NullmereCore
@testable import NullmereModels
import XCTest

/// Where companies gather is modelled at the density of the works: the
/// outcrop, the stand of firs, the grain field and the salt pan each near
/// two thousand triangles or more, within their budget.
final class SiteTests: XCTestCase {
    func testEverySiteIsModelledAtTheWorksDensity() {
        for resource in Resource.allCases {
            let key = ModelKey.site(resource)
            let triangles = Library.model(key).mesh.triangleCount
            XCTAssertLessThanOrEqual(triangles, key.budget, "\(resource)")
            XCTAssertGreaterThan(triangles, 1_900, "\(resource)")
        }
    }

    /// The yards, the lairs and the gatehold, once the plainest pieces of
    /// the land, now each near fifteen hundred triangles or more.
    func testTheYardsLairsAndGateholdAreNoLongerPlain() {
        let keys: [ModelKey] = Resource.allCases.map { .yard($0) } + WildKind.allCases.map { .lair($0) } + [.gatehold]
        for key in keys {
            let triangles = Library.model(key).mesh.triangleCount
            XCTAssertLessThanOrEqual(triangles, key.budget, "\(key)")
            XCTAssertGreaterThan(triangles, 1_400, "\(key)")
        }
    }
}
