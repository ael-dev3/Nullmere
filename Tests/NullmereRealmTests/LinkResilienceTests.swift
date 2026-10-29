import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// A keeper's line through sleep, drops and restarts: readiness counts only
/// for the watch it was given in, an order the realm carried out is never
/// called lost, readiness the realm lost is put right, a keeper the realm
/// no longer knows goes back to the door, a realm that is down isn't
/// hammered, one failed poll isn't told, and a Mac waking asks at once.
@MainActor
final class LinkResilienceTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 20, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func steward(_ db: FakeSpacetime, seed: String) async throws -> (RealmSteward, Task<Void, Never>, SpacetimeCredentials) {
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: seed,
                                             seats: 4, watchLength: 600, now: 0)
        return (steward, Task { await steward.run(clock: { 1 }) }, key)
    }

    private func keeper(_ transport: any SpacetimeTransport, name: String, retryDelay: Double = 0.05) async throws -> (NetworkRealmLink, Listener) {
        let link = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 0.05, retryDelay: retryDelay)
        let ear = Listener()
        ear.listen(to: link)
        link.connect()
        link.arrive(name: name)
        try await until("\(name)'s arrival") { ear.keeper != nil }
        return (link, ear)
    }

    func testReadinessCountsOnlyInTheWatchItWasGivenIn() async throws {
        let db = FakeSpacetime()
        let (steward, running, _) = try await steward(db, seed: "ready in its watch")
        defer { running.cancel() }
        let (ama, _) = try await keeper(db, name: "Ama")
        defer { ama.close() }
        // The link says which watch it is ready in.
        ama.setReady(true)
        try await until("Ama's readiness carried out") { await db.handled(kind: "ready") >= 1 }
        let calls = await db.calls
        XCTAssertTrue(calls.contains("ready_in_watch"))
        // Readiness for a watch already gone, carried only now: nothing.
        let bel = try await db.createIdentity()
        try await db.call("arrive", [.string("b1"), .string("Bel")], token: bel.token)
        try await db.waitFor(3, more: FakeSpacetime.stewardRound)
        let watch = await steward.state.world.watch
        try await db.call("ready_in_watch", [.string("b2"), .bool(true), .integer(UInt64(watch - 1))], token: bel.token)
        try await db.waitFor(3, more: FakeSpacetime.stewardRound)
        let belReady = await steward.state.keepers.first { $0.name == "Bel" }?.isReady
        XCTAssertEqual(belReady, false, "Ready in a watch gone is not ready in this one")
        let turned = await steward.state.world.watch
        XCTAssertEqual(turned, watch, "and turns nothing")
        // Ready in this watch: ready.
        try await db.call("ready_in_watch", [.string("b3"), .bool(true), .integer(UInt64(watch))], token: bel.token)
        try await until("Bel ready in this watch") { await steward.state.keepers.first { $0.name == "Bel" }?.isReady == true }
    }

    func testAnOrderTheRealmCarriedOutIsNeverCalledLost() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db, seed: "carried, not lost")
        defer { running.cancel() }
        let line = Flaky(db)
        // Slow to send again, so the order outlives its lifetime first.
        let (ama, ear) = try await keeper(line, name: "Ama", retryDelay: 2)
        defer { ama.close() }
        var clock = 1_000.0
        ama.now = { clock }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        // The order reaches the realm; its answer is lost, and the line with
        // it; by the time the line is back the order is past its lifetime.
        await line.loseNextCall()
        ama.send(.fortify(unit: spear.id))
        try await until("the order carried out") { await db.handled(kind: "order") == 1 }
        clock += NetworkRealmLink.orderLifetime + 1
        try await until("the order settled") { ama.waiting == 0 }
        XCTAssertFalse(ear.refusals.contains { $0.contains("too old") }, "Carried out, and not said to be lost: \(ear.refusals)")
        let carried = await db.handled(kind: "order")
        XCTAssertEqual(carried, 1, "Once")
    }

    /// An order that reached the realm while its steward was silent waits
    /// there past its time, and is never said to be lost: the steward,
    /// back, carries it out, once.
    func testAnOrderWaitingAtASilentRealmIsNeverLetGo() async throws {
        let db = FakeSpacetime()
        let (_, first, key) = try await steward(db, seed: "a silent realm")
        let (ama, ear) = try await keeper(db, name: "Ama")
        defer { ama.close() }
        var clock = 1_000.0
        ama.now = { clock }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        first.cancel()
        await first.value
        ama.send(.fortify(unit: spear.id))
        try await until("the order sent") { await db.calls.contains("order") }
        clock += NetworkRealmLink.orderLifetime + 1
        try await db.waitFor(3, more: "SELECT nonce FROM my_requests")
        XCTAssertEqual(ama.waiting, 1, "Still waiting on the realm's word")
        XCTAssertTrue(ear.refusals.isEmpty, "Never said to be lost: \(ear.refusals)")
        let sent = await db.calls.filter { $0 == "order" }.count
        // A steward takes the realm up again, and answers it.
        await db.advance(61)
        let second = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "a silent realm",
                                            seats: 4, watchLength: 600, now: 100)
        let running = Task { await second.run(clock: { 101 }) }
        defer { running.cancel() }
        try await until("the order answered") { ama.waiting == 0 }
        let carried = await db.handled(kind: "order")
        XCTAssertEqual(carried, 1, "Carried out once")
        let sentInAll = await db.calls.filter { $0 == "order" }.count
        XCTAssertEqual(sentInAll, sent, "Past its time, only asked after, never sent again")
        XCTAssertTrue(ear.refusals.isEmpty, "\(ear.refusals)")
    }

    /// An order carried out whose answer was lost, and then forgotten by the
    /// realm before the keeper's line came back past the order's time, is
    /// never sent again (it would be carried out twice); the keeper is told
    /// the world shows what came of it.
    func testAnOrderPastItsTimeIsNeverSentTwice() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db, seed: "never twice")
        defer { running.cancel() }
        let line = Flaky(db)
        let (ama, ear) = try await keeper(line, name: "Ama", retryDelay: 2)
        defer { ama.close() }
        var clock = 1_000.0
        ama.now = { clock }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        await line.loseNextCall()
        ama.send(.fortify(unit: spear.id))
        try await until("the order carried out") { await db.handled(kind: "order") == 1 }
        await db.forgetReplies()
        clock += NetworkRealmLink.orderLifetime + 1
        try await until("the order settled") { ama.waiting == 0 }
        XCTAssertTrue(ear.refusals.contains(NetworkRealmLink.unanswered), "\(ear.refusals)")
        XCTAssertFalse(ear.refusals.contains(NetworkRealmLink.tooOldToSend), "It may have reached the realm: not called too old to send")
        let carried = await db.handled(kind: "order")
        XCTAssertEqual(carried, 1, "Never sent again, so never carried out twice")
    }

    /// Only an error that proves a request never left the Mac lets an order
    /// past its time go as never sent.
    func testOnlyAnErrorBeforeSendingProvesARequestNeverLeft() {
        for code in [URLError.Code.notConnectedToInternet, .cannotFindHost, .dnsLookupFailed, .cannotConnectToHost, .secureConnectionFailed] {
            XCTAssertTrue(NetworkRealmLink.neverLeftThisMac(URLError(code)), "\(code)")
        }
        for code in [URLError.Code.timedOut, .networkConnectionLost, .badServerResponse] {
            XCTAssertFalse(NetworkRealmLink.neverLeftThisMac(URLError(code)), "\(code): it may have reached the realm")
        }
        XCTAssertFalse(NetworkRealmLink.neverLeftThisMac(SpacetimeError("The realm answered 503.")))
    }

    func testReadinessTheRealmLostIsPutRight() async throws {
        let db = FakeSpacetime()
        let (_, first, key) = try await steward(db, seed: "readiness lost")
        let (ama, ear) = try await keeper(db, name: "Ama")
        defer { ama.close() }
        let bel = try await db.createIdentity()
        try await db.call("arrive", [.string("b1"), .string("Bel")], token: bel.token)
        ama.setReady(true)
        try await until("Ama's readiness carried out") { await db.handled(kind: "ready") >= 1 }
        // The steward stops and another takes the realm up: whoever was
        // there is taken to have gone, and their readiness with them.
        first.cancel()
        await db.advance(61)
        let second = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "readiness lost",
                                            seats: 4, watchLength: 600, now: 100)
        let running = Task { await second.run(clock: { 101 }) }
        defer { running.cancel() }
        // Ama's client says she's here; she's back, but not ready, and is told so.
        try await db.call("here", [.string("a-here")], token: try XCTUnwrap(ama.credentials?.token))
        try await until("the realm's word on her readiness") {
            ear.events.contains { if case .readiness(false) = $0 { return true } else { return false } }
        }
    }

    func testAKeeperTheRealmNoLongerKnowsGoesBackToTheDoor() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db, seed: "forgotten")
        defer { running.cancel() }
        // A key the server knows, for a keeper the realm doesn't.
        let stranger = try await db.createIdentity()
        let store = MemoryStore(value: String(decoding: try JSONEncoder().encode(stranger), as: UTF8.self))
        let link = NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05, retryDelay: 0.05)
        defer { link.close() }
        let ear = Listener()
        ear.listen(to: link)
        link.setReady(true)
        try await until("the door") {
            ear.events.contains { if case .refused(.unknownKeeper) = $0 { return true } else { return false } }
        }
        XCTAssertEqual(link.waiting, 0, "Nothing left to send for no one")
    }

    func testARealmOutOfReachIsAskedLessOftenAndOneFailureIsntTold() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db, seed: "out of reach")
        defer { running.cancel() }
        let link = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 1, retryDelay: 0.05)
        defer { link.close() }
        let ear = Listener()
        ear.listen(to: link)
        await link.poll()
        XCTAssertEqual(link.nextPoll, 1, "Answering: the link's own interval")
        await db.setReachable(false)
        await link.poll()
        XCTAssertFalse(ear.events.contains { if case .unreachable = $0 { return true } else { return false } }, "One failure, not told")
        await link.poll()
        XCTAssertTrue(ear.events.contains { if case .unreachable = $0 { return true } else { return false } }, "Two, told")
        for _ in 0..<6 { await link.poll() }
        XCTAssertGreaterThanOrEqual(link.nextPoll, 0.8 * NetworkRealmLink.longestPoll, "Asked less and less often, to half a minute")
        XCTAssertLessThanOrEqual(link.nextPoll, 1.2 * NetworkRealmLink.longestPoll)
        await db.setReachable(true)
        await link.poll()
        XCTAssertEqual(link.nextPoll, 1, "Answering again: as often as before")
    }

    func testAMacWakingAsksTheRealmAtOnce() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db, seed: "waking")
        defer { running.cancel() }
        // Polls an hour apart: only a wake asks sooner.
        let link = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 3600, retryDelay: 0.05)
        defer { link.close() }
        link.connect()
        try await until("the first poll") { await db.queried(FakeSpacetime.statusPoll) >= 1 }
        let polls = await db.queried(FakeSpacetime.statusPoll)
        link.wake()
        try await db.waitFor(1, more: FakeSpacetime.statusPoll, timeout: 5)
        let after = await db.queried(FakeSpacetime.statusPoll)
        XCTAssertGreaterThan(after, polls)
    }
}
