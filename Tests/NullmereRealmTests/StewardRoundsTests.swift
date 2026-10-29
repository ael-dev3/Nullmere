import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// The steward's rounds beyond the happy path: how it says the realm's
/// health, an order it can't read, answers forgotten once old, and a
/// server that fails and comes back, told to whoever runs the realm.
final class StewardRoundsTests: XCTestCase {
    func testHealthIsSaidPlainly() {
        let one = RealmStatus(name: "N", age: 2, watch: 40, seats: 12, freeSeats: 1, keepers: 11, online: 1, ready: 0,
                              secondsLeft: 60, isEnding: false)
        XCTAssertEqual(RealmSteward.health(one), "Age 2, watch 40: 1 keeper there of 11, 1 seat open of 12.")
        let many = RealmStatus(name: "N", age: 1, watch: 3, seats: 12, freeSeats: 7, keepers: 5, online: 3, ready: 1,
                               secondsLeft: 60, isEnding: false)
        XCTAssertEqual(RealmSteward.health(many), "Age 1, watch 3: 3 keepers there of 5, 7 seats open of 12.")
        XCTAssertTrue(RealmSteward.isHeldByAnother(SpacetimeError("Another steward holds the realm until 12:00.")))
        XCTAssertFalse(RealmSteward.isHeldByAnother(SpacetimeError("The realm isn't open yet.")))
    }

    func testAnUnreadableOrderIsRefusedAndOldAnswersAreForgotten() async throws {
        let db = FakeSpacetime()
        let stewardKey = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: stewardKey.token, name: "N", seed: "rounds", now: 0)
        let keeper = try await db.createIdentity()
        try await db.call("arrive", [.string("first"), .string("Ama")], token: keeper.token)
        try await steward.step(now: 1)
        try await db.call("order", [.string("garbled"), .string("not an order")], token: keeper.token)
        try await steward.step(now: 2)
        let replies = try await db.query("SELECT * FROM my_replies", token: keeper.token)
        let row = try XCTUnwrap(replies.first { $0.first?.string == "garbled" })
        let reply = try JSONDecoder().decode(RealmReply.self, from: Data(try XCTUnwrap(row[2].string).utf8))
        XCTAssertFalse(reply.ok)
        XCTAssertEqual(reply.refusal, "The order couldn't be read.")

        // Long after, the answers are forgotten: an order can't be sent again that late.
        try await steward.step(now: 2 + RealmSteward.answerKept + 60)
        let calls = await db.calls
        XCTAssertTrue(calls.contains("forget"))
        let left = try await db.query("SELECT * FROM my_replies", token: keeper.token)
        XCTAssertTrue(left.isEmpty, "Old answers forgotten")
    }

    func testAFailingServerIsToldOfAndSoIsItsReturn() async throws {
        let db = FakeSpacetime()
        let stewardKey = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: stewardKey.token, name: "N", seed: "failing", now: 0)
        let heard = Heard()
        await steward.setReporter { heard.add($0) }
        let clock = Clock()
        let running = Task { await steward.run(clock: { clock.next() }) }
        defer { running.cancel() }

        func until(_ what: String, _ condition: @escaping (String) -> Bool) async throws {
            let deadline = Date().addingTimeInterval(20)
            while !heard.lines.contains(where: condition) {
                if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what); heard \(heard.lines)") }
                try await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        try await until("the realm's health") { $0.hasPrefix("Age 1, watch") }
        await db.setReachable(false)
        try await until("a failed round") { $0.hasPrefix("A round failed (") }
        await db.setReachable(true)
        try await until("the server's return") { $0.hasPrefix("The server answers again after") }
    }
}

/// What the steward has said, kept across threads.
private final class Heard: @unchecked Sendable {
    private let lock = NSLock()
    private var said: [String] = []
    func add(_ line: String) { lock.lock(); said.append(line); lock.unlock() }
    var lines: [String] { lock.lock(); defer { lock.unlock() }; return said }
}

/// A clock a minute and a little more on at every reading, so each round
/// may speak, and the health is said every ten.
private final class Clock: @unchecked Sendable {
    private let lock = NSLock()
    private var now = 0.0
    func next() -> Double { lock.lock(); defer { lock.unlock() }; now += 61; return now }
}
