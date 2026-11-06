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
    /// A steward asked to stop finishes the round under way and begins no
    /// other: its running ends without a request cancelled in flight.
    func testAStewardAskedToStopEndsItsRunning() async throws {
        let db = FakeSpacetime()
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "stopped", seats: 2,
                                             watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        try await db.waitFor(1, more: FakeSpacetime.stewardRound)
        await steward.stop()
        await running.value
        let rounds = await db.queried(FakeSpacetime.stewardRound)
        try await Task.sleep(nanoseconds: 600_000_000)
        let after = await db.queried(FakeSpacetime.stewardRound)
        XCTAssertEqual(after, rounds, "No round begun once stopped")
    }

    /// A steward resting long between rounds begins one as the server says
    /// a request has come, not at the rest's end; and asked to stop, or
    /// its running cancelled, it ends its rest at once and stops watching.
    func testARequestIsTakenAsItComesNotAtTheRestsEnd() async throws {
        let db = FakeSpacetime()
        await db.setPushing(true)
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "woken", seats: 4,
                                             watchLength: 600, now: 0)
        let running = Task.detached { await steward.run(clock: { 1 }, resting: 600) }
        try await db.waitFor(1, more: FakeSpacetime.stewardRound)
        let watching = await db.watchingRequests
        XCTAssertEqual(watching, 1, "The steward watching the requests")
        // Resting now, for ten minutes but for a request.
        try await Task.sleep(nanoseconds: 100_000_000)
        let rounds = await db.queried(FakeSpacetime.stewardRound)
        let ama = try await db.createIdentity()
        let asked = Date()
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        let deadline = Date().addingTimeInterval(10)
        while try await db.keptView(of: ama.identity) == nil {
            if Date() > deadline { return XCTFail("Ama's arrival was never taken") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        XCTAssertLessThan(Date().timeIntervalSince(asked), 5, "Taken as it came, not after the rest")
        let afterRounds = await db.queried(FakeSpacetime.stewardRound)
        XCTAssertLessThanOrEqual(afterRounds - rounds, 3, "A round or two for it, not rounds without rest")

        let stopping = Date()
        await steward.stop()
        await running.value
        XCTAssertLessThan(Date().timeIntervalSince(stopping), 5, "Its rest ended as it was asked to stop")
        try await until("the watch let go") { await db.watchingRequests == 0 }

        // Its running cancelled while it rests: it ends as soon. (The
        // first's hold on the realm let lapse.)
        await db.advance(61)
        let again = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "woken", seats: 4,
                                           watchLength: 600, now: 2)
        let cancelled = Task.detached { await again.run(clock: { 2 }, resting: 600) }
        try await db.waitFor(1, more: FakeSpacetime.stewardRound)
        try await Task.sleep(nanoseconds: 100_000_000)
        let cancelling = Date()
        cancelled.cancel()
        await cancelled.value
        XCTAssertLessThan(Date().timeIntervalSince(cancelling), 5, "Its rest ended as its running was cancelled")
    }

    private func until(_ what: String, timeout: Double = 10, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

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
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        try await db.call("arrive", [.string("b1"), .string(ArrivalPayload(name: "Bel", compact: Compact.edition).encoded)], token: bel.token)
        try await db.call("arrive", [.string("c1"), .string(ArrivalPayload(name: "Cor", compact: Compact.edition).encoded)], token: cor.token)
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
        try await db.call("arrive", [.string("d1"), .string(ArrivalPayload(name: "Cor", compact: Compact.edition).encoded)], token: dee.token)
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
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
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
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
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

    /// A publication too large for one call goes in several, each one the
    /// server keeps whole on its own: the world's parts that changed and
    /// those gone, and every answer, in the first, the world and what came
    /// of it in one transaction; every keeper's view in one call, its parts
    /// with its row; each answer telling the version its keeper's view is
    /// written at, or 0; one version to a call, numbered on; and no call
    /// over the budget but one carrying a single thing larger.
    func testAPublicationTooLargeForOneCallGoesInSeveral() throws {
        let units = String(repeating: "u", count: 400)
        let world: [(key: String, value: String)] = [("head", String(repeating: "w", count: 300)), ("map.0", String(repeating: "m", count: 500))]
        let shown = (0..<6).map { index in
            RealmSteward.Shown(keeper: "k\(index)", parts: ["head": "h\(index)", "units.0": units], changed: [(key: "units.0", value: units)],
                               at: ["head": 3], heard: "[]")
        }
        let answers = [(1, "k4"), (2, "elsewhere"), (3, "k0")].map { id, keeper in
            RealmSteward.Answer(id: UInt64(id), nonce: "n\(id)", keeper: keeper, reply: .done)
        }
        func told(_ call: RealmSteward.Call) throws -> [UInt64?] {
            try call.replies.map { try JSONDecoder().decode(RealmReply.self, from: Data($0.utf8)).viewAt }
        }
        let budget = 1_000
        let calls = try RealmSteward.calls(world: world, gone: ["units.9"], shown: shown, answers: answers, from: 10, budget: budget)
        XCTAssertEqual(calls.map(\.version), [10, 11, 12, 13], "The world alone, then two views to a call")
        XCTAssertEqual(calls[0].worldNames, ["head", "map.0"])
        XCTAssertEqual(calls[0].worldTexts, world.map(\.value))
        XCTAssertEqual(calls[0].gone, ["units.9"])
        XCTAssertTrue(calls.dropFirst().allSatisfy { $0.worldNames.isEmpty && $0.gone.isEmpty }, "The world whole, in the first")
        XCTAssertEqual(calls.flatMap(\.keepers), shown.map(\.keeper), "Every view once, in order")
        for call in calls {
            XCTAssertTrue(call.size <= budget || call.keepers.count <= 1, "Over the budget only with one thing in it")
            XCTAssertEqual(call.partKeepers, call.keepers, "Each view's parts in the call with its row")
            XCTAssertEqual(call.partNames, call.keepers.map { _ in "units.0" })
            for (keeper, row) in zip(call.keepers, call.views) {
                let named = try XCTUnwrap(ViewRow(row)).own
                XCTAssertEqual(named, ["head": 3, "units.0": call.version], "Its new part written in the call that carries it")
                XCTAssertEqual(call.shownAt[keeper], named, "Kept as shown once the call is")
                XCTAssertEqual(call.shown[keeper], ["head": "h\(keeper.dropFirst())", "units.0": units])
            }
            XCTAssertEqual(call.heard.count, call.keepers.count)
        }
        XCTAssertEqual(calls[0].answers.map(\.id), [1, 2, 3], "Every answer with the world")
        XCTAssertEqual(try told(calls[0]), [13, 0, 11], "Each telling where its keeper's view is written, or that it isn't")
        XCTAssertTrue(calls.dropFirst().allSatisfy { $0.answers.isEmpty && $0.replies.isEmpty })

        // Small enough, it is one call as it always was.
        let one = try RealmSteward.calls(world: world, gone: [], shown: shown, answers: answers, from: 10, budget: RealmSteward.publicationBudget)
        XCTAssertEqual(one.count, 1)
        XCTAssertEqual(one[0].keepers.count, 6)
        XCTAssertEqual(one[0].answers.map(\.id), [1, 2, 3])
        XCTAssertEqual(try told(one[0]), [10, 0, 10])
        // Nothing changed and no one shown: one call, the answers telling
        // their keepers no view of theirs is written.
        let quiet = try RealmSteward.calls(world: [], gone: [], shown: [], answers: answers, from: 10, budget: 1)
        XCTAssertEqual(quiet.count, 1)
        XCTAssertEqual(try told(quiet[0]), [0, 0, 0])
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
        try await db.call("arrive", [.string("first"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: keeper.token)
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
