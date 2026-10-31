import Foundation
import XCTest
@testable import NullmereCore
@testable import NullmereRealm
import NullmereTestSupport

/// Whoever runs the realm gives its steward orders in plain words: a line
/// taken out of the Words, a House barred from them for a while; what was
/// done, or why nothing was, said back in a line.
final class StewardOrdersTests: XCTestCase {
    func testTheStewardTakesLinesAwayAndBarsHouses() async throws {
        let db = FakeSpacetime()
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "orders",
                                             seats: 4, watchLength: 600, now: 0)
        let watch = await steward.state.world.watch
        let title = await steward.state.world.houses[1].title
        let barred = await steward.obey("bar 1 5")
        XCTAssertEqual(barred, "Barred \(title) from the Words until watch \(watch + 5).")
        let until = await steward.state.world.barredFromWords(1)
        XCTAssertEqual(until, watch + 5)
        let none = await steward.obey("remove 424242")
        XCTAssertEqual(none, "No line 424242 is kept in the Words.")
        let nobody = await steward.obey("bar 99 5")
        XCTAssertEqual(nobody, "No House 99 to bar, or no watches to bar it for.")
        let unknown = await steward.obey("banish everyone")
        XCTAssertTrue(unknown.hasPrefix("Not an order the steward knows: banish everyone."), unknown)
        XCTAssertTrue(unknown.hasSuffix("forget <keeper>."), unknown)
    }

    /// A keeper who asked to be forgotten, by the name they go by: gone
    /// from the realm's roll, their House a steward's under another name,
    /// their seat open again.
    func testTheStewardForgetsAKeeperWhoAsks() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "forget me",
                                             seats: 2, watchLength: 600, now: 0)
        let ama = try await db.createIdentity(), bel = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama Lin")], token: ama.token)
        try await db.call("arrive", [.string("b1"), .string("Bel")], token: bel.token)
        try await steward.step(now: 1)
        let held = await steward.state.keeper(ama.identity)?.house
        let house = try XCTUnwrap(held)
        let nobody = await steward.obey("forget Nobody")
        XCTAssertEqual(nobody, "No keeper goes by Nobody.")
        let said = await steward.obey("forget ama lin")
        let title = await steward.state.world.houses[house].title
        XCTAssertEqual(said, "Forgot Ama Lin and their identity. \(title) is the stewards' to keep.")
        XCTAssertNotEqual(title, "House Ama Lin")
        let gone = await steward.state.keeper(ama.identity)
        XCTAssertNil(gone)
        try await steward.step(now: 2)
        let status = await steward.state.status(now: 2)
        XCTAssertEqual(status.keepers, 1, "Only Bel on the roll")
        XCTAssertEqual(status.freeSeats, 1, "Ama's seat open again")
    }
}
