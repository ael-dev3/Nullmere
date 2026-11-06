import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// A keeper's link to a realm that pushes the rows themselves, as
/// SpacetimeDB's subscriptions do: the status, the keeper's view and its
/// parts, and the answers to their requests come as they are written, and
/// the link takes them rather than ask after them.
final class LinkPushedRowsTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 20, _ condition: @MainActor () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !condition() {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// What a keeper asks after of their status, view and answers.
    private func asked(_ db: FakeSpacetime, by token: String) async -> [String: Int] {
        var counts: [String: Int] = [:]
        for statement in [FakeSpacetime.statusPoll, FakeSpacetime.viewPartsAsked, FakeSpacetime.viewPartAsked, FakeSpacetime.answerAsked,
                          "SELECT * FROM my_view", "SELECT version FROM my_view", "SELECT version, at_micros FROM stamp"] {
            counts[statement] = await db.queried(statement, by: token)
        }
        return counts
    }

    private func realm(_ seed: String) async throws -> (FakeSpacetime, Task<Void, Never>) {
        let db = FakeSpacetime()
        await db.setPushing(true, rows: true)
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: seed, seats: 4,
                                             watchLength: 600, now: 0)
        return (db, Task.detached { await steward.run(clock: { 1 }) })
    }

    @MainActor
    func testAKeeperTakesWhatTheRealmPushesRatherThanAskAfterIt() async throws {
        let (db, running) = try await realm("pushed rows")
        defer { running.cancel() }
        let ama = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        let ear = Listener()
        ear.listen(to: ama)
        ama.connect()
        defer { ama.close() }
        try await until("the realm watched") { await db.watching == 1 }
        ama.arrive(name: "Ama")
        try await until("Ama seated and shown the world") { ear.keeper?.house != nil && ear.world != nil }
        let token = try XCTUnwrap(ama.credentials?.token), identity = try XCTUnwrap(ama.credentials?.identity)
        let house = try XCTUnwrap(ear.keeper?.house)

        // Her words carried out, answered and heard, with the link reading
        // as often as twenty times a second: none of it asked after.
        let before = await asked(db, by: token)
        let pushed = await db.rowsPushed
        let words = "The lake is full tonight"
        ama.send(.say(words: words, toAlliance: false))
        try await until("Ama's words answered and heard") {
            ama.waiting == 0 && (ear.world?.words(heardBy: house).contains { $0.text == words } ?? false)
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        let after = await asked(db, by: token)
        XCTAssertEqual(after, before, "Nothing asked after while the realm pushes it")
        let pushedSince = await db.rowsPushed - pushed
        XCTAssertGreaterThan(pushedSince, 0)
        // The view she took is the one the realm keeps for her.
        let kept = try await db.keptView(of: identity)
        XCTAssertEqual(ear.world, kept?.world)
        XCTAssertTrue(ear.refusals.isEmpty, "\(ear.refusals)")
    }

    /// The first status a subscription brings is aged by the server's clock,
    /// as a status read is; those it pushes after are as old as the push.
    @MainActor
    func testOnlyTheFirstStatusPushedIsAgedByTheServersClock() async throws {
        let (db, running) = try await realm("aged once")
        defer { running.cancel() }
        let ama = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        let ear = Listener()
        ear.listen(to: ama)
        ama.connect()
        defer { ama.close() }
        try await until("the realm watched") { await db.watching == 1 }
        ama.arrive(name: "Ama")
        try await until("Ama seated") { ear.keeper?.house != nil }
        let token = try XCTUnwrap(ama.credentials?.token)
        let stamps = await db.queried("SELECT version, at_micros FROM stamp", by: token)
        let bel = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 60)
        bel.connect()
        defer { bel.close() }
        bel.arrive(name: "Bel")
        try await until("the realm's word of Bel's coming") { (ear.lastStatus?.keepers ?? 0) >= 2 }
        let stampsAfter = await db.queried("SELECT version, at_micros FROM stamp", by: token)
        XCTAssertEqual(stampsAfter, stamps, "A status pushed isn't aged again")
    }

    /// The line quiet for longer than the steward ever is, the rows held
    /// may be a dead line's: the realm is asked, as it is without them.
    @MainActor
    func testARealmQuietTooLongIsAskedAgain() async throws {
        let (db, running) = try await realm("gone quiet")
        defer { running.cancel() }
        let clock = LinkClock()
        let ama = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        ama.now = { clock.value }
        let ear = Listener()
        ear.listen(to: ama)
        ama.connect()
        defer { ama.close() }
        try await until("the realm watched") { await db.watching == 1 }
        ama.arrive(name: "Ama")
        try await until("Ama seated and shown the world") { ear.keeper?.house != nil && ear.world != nil }
        let token = try XCTUnwrap(ama.credentials?.token)
        let read = await db.queried(FakeSpacetime.statusPoll, by: token)
        try await Task.sleep(nanoseconds: 300_000_000)
        let unasked = await db.queried(FakeSpacetime.statusPoll, by: token)
        XCTAssertEqual(unasked, read, "While the word comes, the status isn't asked after")
        clock.value += NetworkRealmLink.wordWindow + 1
        ama.wake()
        try await until("the status asked after") { await db.queried(FakeSpacetime.statusPoll, by: token) > read }
    }

    /// An answer whose row was lost on the way is asked after all the
    /// same, now and then, while the rest of the realm's word comes.
    @MainActor
    func testAnAnswerNotPushedIsAskedAfterNowAndThen() async throws {
        let (db, running) = try await realm("lost word")
        defer { running.cancel() }
        let ama = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        let ear = Listener()
        ear.listen(to: ama)
        ama.connect()
        defer { ama.close() }
        try await until("the realm watched") { await db.watching == 1 }
        ama.arrive(name: "Ama")
        try await until("Ama seated") { ear.keeper?.house != nil && ear.world != nil }
        let token = try XCTUnwrap(ama.credentials?.token)
        await db.withhold("my_replies")
        let asked = await db.queried(FakeSpacetime.answerAsked, by: token)
        ama.send(.say(words: "Asked after", toAlliance: false))
        try await until("the order answered", timeout: 15) { ama.waiting == 0 }
        let askedAfter = await db.queried(FakeSpacetime.answerAsked, by: token)
        XCTAssertGreaterThan(askedAfter, asked, "Asked after, its row never pushed")
        XCTAssertLessThanOrEqual(askedAfter - asked, 3, "Asked after now and then, not as often as the link reads")
        XCTAssertTrue(ear.refusals.isEmpty, "\(ear.refusals)")
    }

    /// Rows that don't make the keeper's view whole, its parts lost on the
    /// way: the view is read from the realm, as it is without them.
    @MainActor
    func testAViewTheRowsDontMakeWholeIsReadFromTheRealm() async throws {
        let (db, running) = try await realm("parts lost")
        defer { running.cancel() }
        await db.withhold("my_view_parts")
        let ama = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        let ear = Listener()
        ear.listen(to: ama)
        ama.connect()
        defer { ama.close() }
        try await until("the realm watched") { await db.watching == 1 }
        ama.arrive(name: "Ama")
        try await until("Ama seated and shown the world") { ear.keeper?.house != nil && ear.world != nil }
        let token = try XCTUnwrap(ama.credentials?.token), identity = try XCTUnwrap(ama.credentials?.identity)
        let asked = await db.queried(FakeSpacetime.viewPartsAsked, by: token)
        XCTAssertGreaterThan(asked, 0, "Her view's parts asked for, the rows lacking them")
        let kept = try await db.keptView(of: identity)
        XCTAssertEqual(ear.world, kept?.world)
    }

    /// A publication in many calls: an answer comes before the view it
    /// names, and the keeper takes that view as its rows are pushed after,
    /// asking after none of it.
    @MainActor
    func testAnAnswerBeforeItsViewWaitsForTheViewPushed() async throws {
        let db = FakeSpacetime()
        await db.setPushing(true, rows: true)
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "many calls", seats: 4,
                                             watchLength: 600, now: 0)
        await steward.setPublicationBudget(4_000)
        let running = Task.detached { await steward.run(clock: { 1 }) }
        defer { running.cancel() }
        let ama = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 60)
        let ear = Listener()
        ear.listen(to: ama)
        ama.connect()
        defer { ama.close() }
        try await until("the realm watched") { await db.watching == 1 }
        ama.arrive(name: "Ama")
        try await until("Ama seated and shown the world") { ear.keeper?.house != nil && ear.world != nil }
        let token = try XCTUnwrap(ama.credentials?.token)
        let calls = await steward.publicationCalls, publications = await steward.publications
        XCTAssertGreaterThan(calls, publications, "Publications in more calls than one")
        let asked = await asked(db, by: token)
        XCTAssertEqual(asked[FakeSpacetime.viewPartsAsked], 0, "Her view taken as pushed")
        XCTAssertEqual(asked["SELECT * FROM my_view"], 0)
    }
}

/// A clock a test moves on.
final class LinkClock: @unchecked Sendable {
    var value = 1_000.0
}
