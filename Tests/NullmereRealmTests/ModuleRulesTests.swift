import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// The realm module's own rules, kept by SpacetimeDB in memory as the
/// module keeps them: a nonce and a payload within their bounds, counted
/// in bytes; a publication refused that takes no hold on the realm, as a
/// reducer that fails undoes all it did; and a realm handed to another
/// steward. `SpacetimeIntegrationTests` holds a real server to the same.
final class ModuleRulesTests: XCTestCase {
    private func refusal(_ db: FakeSpacetime, _ reducer: String, _ arguments: [ReducerArgument], token: String) async -> String? {
        do {
            try await db.call(reducer, arguments, token: token)
            return nil
        } catch {
            return "\(error)"
        }
    }

    func testARequestIsKeptWithinItsBounds() async throws {
        let db = FakeSpacetime()
        _ = try await db.createIdentity()
        let keeper = try await db.createIdentity()
        let nonce = "A request needs a nonce of 1 to 64 characters."
        let none = await refusal(db, "here", [.string("")], token: keeper.token)
        XCTAssertEqual(none, nonce)
        let long = await refusal(db, "here", [.string(String(repeating: "n", count: 65))], token: keeper.token)
        XCTAssertEqual(long, nonce)
        let most = await refusal(db, "here", [.string(String(repeating: "n", count: 64))], token: keeper.token)
        XCTAssertNil(most, "Sixty-four will do")
        let wide = await refusal(db, "here", [.string(String(repeating: "é", count: 33))], token: keeper.token)
        XCTAssertEqual(wide, nonce, "Thirty-three letters, sixty-six bytes: counted as the module counts")
        let heavy = await refusal(db, "order", [.string("heavy"), .string(String(repeating: "x", count: 4097))], token: keeper.token)
        XCTAssertEqual(heavy, "The request is too long.")
        let full = await refusal(db, "order", [.string("full"), .string(String(repeating: "x", count: 4096))], token: keeper.token)
        XCTAssertNil(full)
    }

    /// A publication refused, here for a version already passed, takes no
    /// hold on the realm: a steward that comes after takes it up at once.
    func testAPublicationRefusedTakesNoHold() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let first = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "no hold", seats: 4, watchLength: 600, now: 0)
        let version = await first.version
        await db.advance(FakeSpacetime.leaseSeconds + 1)
        let stale = await refusal(db, "publish", [.integer(version), .strings([]), .strings([]), .strings([]), .string("{}"), .strings([]),
                                                  .strings([]), .strings([]), .integers([]), .strings([]), .string("a stranger's hold")],
                                  token: key.token)
        XCTAssertEqual(stale, "Version \(version) is not after \(version).")
        let second = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "no hold", seats: 4, watchLength: 600, now: 1)
        let taken = await second.version
        XCTAssertGreaterThan(taken, version, "Taken up at once")
    }

    /// The realm handed to another identity: it stewards the realm from
    /// then on, and the one that handed it over does so no more, though as
    /// the publisher it still owns the database and alone reads its private
    /// tables.
    func testTheRealmHandedOverHasANewSteward() async throws {
        let db = FakeSpacetime()
        let publisher = try await db.createIdentity()
        let dedicated = try await db.createIdentity()
        let stranger = await refusal(db, "hand_over", [.string(dedicated.identity)], token: dedicated.token)
        XCTAssertEqual(stranger, "Only the steward hands over the realm.")
        let handed = await refusal(db, "hand_over", [.string(dedicated.identity)], token: publisher.token)
        XCTAssertNil(handed)
        let theirs = await refusal(db, "forget", [.strings([])], token: dedicated.token)
        XCTAssertNil(theirs)
        let old = await refusal(db, "forget", [.strings([])], token: publisher.token)
        XCTAssertEqual(old, "Only the steward forgets answers.")
        let unread = try? await db.query(FakeSpacetime.stewardRound, token: dedicated.token)
        XCTAssertNil(unread, "Private to the owner")
        let read = try await db.query(FakeSpacetime.stewardRound, token: publisher.token)
        XCTAssertEqual(read.count, 0)
    }
}
