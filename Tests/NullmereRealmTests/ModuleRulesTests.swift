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
                                                  .strings([]), .strings([]), .integers([]), .strings([]), .string("a stranger's hold"),
                                                  .strings([]), .strings([]), .strings([]), .strings([])],
                                  token: key.token)
        XCTAssertEqual(stale, "Version \(version) is not after \(version).")
        let second = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "no hold", seats: 4, watchLength: 600, now: 1)
        let taken = await second.version
        XCTAssertGreaterThan(taken, version, "Taken up at once")
    }

    /// The world's parts sent ahead of a publication are none of the world
    /// until the call that publishes it names them: one named that was
    /// never sent ahead, or was sent ahead of another publication, and
    /// nothing of it is kept; those it doesn't name are let go with it, and
    /// those sent ahead of a publication that never came are let go by the
    /// next sent ahead of another. None but the steward sends any ahead, and
    /// none ahead of a publication passed. `SpacetimeIntegrationTests` holds
    /// a real server to the same.
    func testTheWorldSentAheadIsNoneOfItUntilPublished() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "ahead", seats: 4, watchLength: 600, now: 0)
        let next = await steward.version + 1
        await db.advance(FakeSpacetime.leaseSeconds + 1)
        let hold = ReducerArgument.string("a test's hold")
        func publish(_ version: UInt64, ahead: [String]) -> [ReducerArgument] {
            [.integer(version), .strings([]), .strings([]), .strings([]), .string("{}"), .strings([]), .strings([]), .strings([]),
             .integers([]), .strings([]), hold, .strings([]), .strings([]), .strings([]), .strings(ahead)]
        }
        let before = try await RealmSteward.keptParts(db, token: key.token)
        let sent = await refusal(db, "send_ahead", [.integer(next), .strings(["map.0", "spare"]), .strings(["{\"m\":1}", "{}"]), hold],
                                 token: key.token)
        XCTAssertNil(sent)
        let aside = try await RealmSteward.keptParts(db, token: key.token)
        XCTAssertEqual(aside, before, "None of the world until published")

        let unsent = await refusal(db, "publish", publish(next, ahead: ["map.0", "map.9"]), token: key.token)
        XCTAssertEqual(unsent, "The part map.9 was never sent ahead.")
        let other = await refusal(db, "publish", publish(next + 1, ahead: ["map.0"]), token: key.token)
        XCTAssertEqual(other, "The part map.0 was sent ahead of another publication.")
        let refused = try await RealmSteward.keptParts(db, token: key.token)
        XCTAssertEqual(refused, before, "Nothing of a publication refused kept")

        let published = await refusal(db, "publish", publish(next, ahead: ["map.0"]), token: key.token)
        XCTAssertNil(published)
        var world = before
        world["map.0"] = "{\"m\":1}"
        let kept = try await RealmSteward.keptParts(db, token: key.token)
        XCTAssertEqual(kept, world, "The part named published, the one it didn't let go")
        let gone = await db.sentAhead
        XCTAssertTrue(gone.isEmpty)

        for (version, name) in [(next + 2, "map.1"), (next + 3, "map.2")] {
            let ahead = await refusal(db, "send_ahead", [.integer(version), .strings([name]), .strings(["{}"]), hold], token: key.token)
            XCTAssertNil(ahead)
        }
        let left = await db.sentAhead
        XCTAssertEqual(Array(left.keys), ["map.2"], "Those sent ahead of a publication that never came let go")
        let passed = await refusal(db, "send_ahead", [.integer(next), .strings([]), .strings([]), hold], token: key.token)
        XCTAssertEqual(passed, "Version \(next) is not after \(next).")
        let stranger = try await db.createIdentity()
        let strange = await refusal(db, "send_ahead", [.integer(next + 9), .strings([]), .strings([]), .string("x")], token: stranger.token)
        XCTAssertEqual(strange, "Only the steward writes the world.")
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
