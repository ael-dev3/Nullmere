import Foundation
import NullmereTestSupport
import XCTest
@testable import NullmereCore
@testable import NullmereRealm

/// A steward taking up a world gone wrong says so, at the next turn of
/// the watch, to whoever runs the realm.
final class StewardSoundnessTests: XCTestCase {
    func testAnUnsoundWorldIsSaidAtTheTurnOfTheWatch() async throws {
        var realm = RealmState(name: "The Nullmere", seed: "gone wrong", seats: 4, watchLength: 60, now: 0)
        // Two standings between the same two Houses: a world gone wrong.
        realm.world.relations.append(realm.world.relations[0])
        XCTAssertFalse(realm.world.problems().isEmpty)
        let db = FakeSpacetime()
        await db.seed(world: String(decoding: try JSONEncoder().encode(realm), as: UTF8.self), version: 3)
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "gone wrong",
                                             seats: 4, watchLength: 60, now: 0)
        let heard = Lines()
        await steward.setReporter { heard.add($0) }
        let keeper = try await db.createIdentity()
        try await db.call("arrive", [.string("arrival"), .string("Ama")], token: keeper.token)
        try await steward.step(now: 1)
        try await steward.step(now: 61)
        XCTAssertTrue(heard.all.contains { $0.hasPrefix("The world is unsound at watch") }, "\(heard.all)")
        XCTAssertTrue(heard.all.contains { $0.contains("more than one standing") })
    }
}

private final class Lines: @unchecked Sendable {
    private let lock = NSLock()
    private var said: [String] = []
    func add(_ line: String) { lock.lock(); said.append(line); lock.unlock() }
    var all: [String] { lock.lock(); defer { lock.unlock() }; return said }
}
