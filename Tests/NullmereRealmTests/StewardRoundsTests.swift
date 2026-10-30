import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// The steward's rounds beyond the happy path: how it says the realm's
/// health, an order it can't read, answers forgotten once old, even those
/// an earlier steward gave, a server that fails and comes back, told to
/// whoever runs the realm, and a steward that keeps nothing of passers-by
/// and works out no view that can't have changed.
final class StewardRoundsTests: XCTestCase {
    /// Neither the steward nor the realm keeps every identity it hears of:
    /// strangers who never came in are kept by neither, the steward keeps
    /// only what it needs of those there, and a keeper long gone without a
    /// seat is forgotten, their name free again.
    func testNeitherTheStewardNorTheRealmKeepsEveryPasserBy() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "passers-by", seats: 2, watchLength: 600, now: 0)
        for index in 0..<20 {
            let stranger = try await db.createIdentity()
            try await db.call("here", [.string("s\(index)")], token: stranger.token)
        }
        let ama = try await db.createIdentity(), bel = try await db.createIdentity(), cor = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama")], token: ama.token)
        try await db.call("arrive", [.string("b1"), .string("Bel")], token: bel.token)
        try await db.call("arrive", [.string("c1"), .string("Cor")], token: cor.token)
        try await steward.step(now: 1)
        let remembered = await steward.keepersRemembered
        XCTAssertEqual(remembered, 3, "The three there, and no stranger")
        let seatless = await steward.state.keeper(cor.identity)
        XCTAssertNil(seatless?.house, "Two seats, and Cor came third")

        // Cor leaves; long after, all are gone, and the realm forgets Cor.
        try await db.call("leave", [.string("c2")], token: cor.token)
        try await steward.step(now: 2)
        try await steward.step(now: 2 + RealmState.unplayedSeatHeldFor)
        let gone = await steward.state.keeper(cor.identity)
        XCTAssertNil(gone, "Forgotten")
        let kept = await steward.state.keepers.map(\.name)
        XCTAssertEqual(kept, ["Ama", "Bel"], "Those with seats are kept")
        let after = await steward.keepersRemembered
        XCTAssertEqual(after, 0, "No one there, nothing kept of them by the steward")
        // Another may go by the name.
        let dee = try await db.createIdentity()
        try await db.call("arrive", [.string("d1"), .string("Cor")], token: dee.token)
        try await steward.step(now: 3 + RealmState.unplayedSeatHeldFor)
        let named = await steward.state.keeper(dee.identity)?.name
        XCTAssertEqual(named, "Cor")
    }

    /// A round that changes nothing a keeper can see, as answering "here",
    /// works out no view: each would be found as it was published.
    func testAViewThatCantHaveChangedIsNotWorkedOutAgain() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "unchanged", seats: 4, watchLength: 600, now: 0)
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama")], token: ama.token)
        try await steward.step(now: 1)
        let worked = await steward.viewsWorkedOut
        for round in 0..<5 {
            try await db.call("here", [.string("h\(round)")], token: ama.token)
            try await steward.step(now: 2 + Double(round))
        }
        let idle = await steward.viewsWorkedOut - worked
        XCTAssertEqual(idle, 0, "Five rounds answering 'here': no view worked out")
        let state = await steward.state
        let house = try XCTUnwrap(state.keeper(ama.identity)?.house)
        let spear = try XCTUnwrap(state.world.units(of: house).first { $0.kind == .spear })
        let order = String(decoding: try JSONEncoder().encode(Command.fortify(unit: spear.id)), as: UTF8.self)
        try await db.call("order", [.string("a2"), .string(order)], token: ama.token)
        try await steward.step(now: 10)
        let busy = await steward.viewsWorkedOut - worked
        XCTAssertEqual(busy, 1, "An order: Ama's view worked out again")
    }

    /// Answers a steward gave before it stopped are forgotten in their time
    /// by the one that takes the realm up, not kept for ever.
    func testAnswersAnEarlierStewardGaveAreForgottenInTheirTime() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let first = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "an earlier steward", now: 0)
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string("Ama")], token: ama.token)
        try await first.step(now: 1)
        let given = try await db.query("SELECT * FROM my_replies", token: ama.token)
        XCTAssertEqual(given.count, 1)
        await db.advance(61)
        let second = try await RealmSteward(transport: db, token: key.token, name: "N", seed: "an earlier steward", now: 100)
        try await second.step(now: 100 + RealmSteward.answerKept / 2)
        let kept = try await db.query("SELECT * FROM my_replies", token: ama.token)
        XCTAssertEqual(kept.count, 1, "Kept a while, as any answer is")
        try await second.step(now: 100 + RealmSteward.answerKept + 1)
        let left = try await db.query("SELECT * FROM my_replies", token: ama.token)
        XCTAssertTrue(left.isEmpty, "Forgotten in their time, though another steward gave them")
    }

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
