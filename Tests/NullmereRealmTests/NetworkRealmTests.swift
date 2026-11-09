import Foundation
@testable import NullmereCore
import NullmereModels
import XCTest
@testable import NullmereRealm
import NullmereTestSupport


/// Everything a link hears, on the main actor where links live.
@MainActor
final class Listener {
    var events: [RealmEvent] = []

    func listen(to link: NetworkRealmLink) {
        link.onEvent = { [weak self] in self?.events.append($0) }
    }

    var keeper: Keeper? {
        for event in events { if case .arrived(let keeper, _) = event { return keeper } }
        return nil
    }

    /// The keeper as the realm last told it, as each arrival answers.
    var lastKeeper: Keeper? {
        for event in events.reversed() { if case .arrived(let keeper, _) = event { return keeper } }
        return nil
    }

    /// The keeper as the realm last told them: on arriving, or as their
    /// record changed since.
    var toldKeeper: Keeper? {
        for event in events.reversed() {
            switch event {
            case .arrived(let keeper, _), .keeperChanged(let keeper): return keeper
            default: continue
            }
        }
        return nil
    }

    var world: GameState? {
        for event in events.reversed() {
            switch event {
            case .arrived(_, let world), .changed(let world), .watchTurned(let world, _), .orderRefused(_, let world), .settled(let world, _):
                return world
            default: continue
            }
        }
        return nil
    }

    var lastStatus: RealmStatus? {
        for event in events.reversed() { if case .status(let status) = event { return status } }
        return nil
    }

    var refusals: [String] {
        events.compactMap {
            switch $0 {
            case .orderRefused(let error, _), .refused(let error): return error.description
            default: return nil
            }
        }
    }

    var turned: Bool { events.contains { if case .watchTurned = $0 { return true } else { return false } } }
    var hasStatus: Bool { events.contains { if case .status = $0 { return true } else { return false } } }
    var silenceTold: Bool {
        events.contains { if case .unreachable(NetworkRealmLink.silentSteward) = $0 { return true } else { return false } }
    }
}

/// Keepers, a steward and SpacetimeDB (in memory): the realm as it runs
/// across the network.
final class NetworkRealmTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 15, _ condition: @escaping @MainActor @Sendable () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !MainActor.run(body: condition) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func steward(_ db: FakeSpacetime) async throws -> (RealmSteward, Task<Void, Never>, SpacetimeCredentials) {
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "network test",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        return (steward, running, credentials)
    }

    @MainActor
    private func keeper(_ db: FakeSpacetime, store: MemoryStore = MemoryStore()) -> (NetworkRealmLink, Listener) {
        let link = NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05)
        let listener = Listener()
        listener.listen(to: link)
        link.connect()
        return (link, listener)
    }

    /// Connecting again while already connected, as when the app comes back
    /// to the front, keeps the one line and tells the realm's status afresh.
    func testConnectingAgainTellsTheStatusAfresh() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (link, ear) = await MainActor.run { keeper(db) }
        try await until("the realm's status") { ear.hasStatus }
        // Unchanged, the status isn't told again, however often it is read.
        let linksToken = await MainActor.run { link.credentials?.token }
        let token = try XCTUnwrap(linksToken)
        try await db.waitFor(2, more: FakeSpacetime.statusPoll, by: token)
        let told = await MainActor.run { ear.events.filter { if case .status = $0 { return true } else { return false } }.count }
        try await db.waitFor(6, more: FakeSpacetime.statusPoll, by: token)
        let still = await MainActor.run { ear.events.filter { if case .status = $0 { return true } else { return false } }.count }
        XCTAssertEqual(still, told, "Told once while it stands still")
        await MainActor.run { link.connect() }
        try await until("the status told afresh") {
            ear.events.filter { if case .status = $0 { return true } else { return false } }.count > told
        }
        await MainActor.run { link.leave() }
    }

    /// A keeper's words carry them to another Mac across the network: the
    /// first Mac seals them, words not theirs take up no one, and the
    /// second Mac, bringing theirs, arrives as them.
    /// The realm keeps the compact: a client that brings no accepted
    /// edition is refused at the door; one that brings it comes in, the
    /// edition recorded, and an order from a keeper the realm holds no
    /// acceptance for is refused.
    func testTheRealmTakesInOnlyKeepersWhoAcceptedTheCompact() async throws {
        let db = FakeSpacetime()
        let (steward, running, _) = try await steward(db)
        defer { running.cancel() }
        let (link, ear) = await MainActor.run { keeper(db) }
        try await until("the realm's status") { ear.hasStatus }
        await MainActor.run {
            link.compactAccepted = nil
            link.arrive(name: "Ama")
        }
        try await until("refused at the door") { ear.refusals.contains(RealmError.compactUnaccepted.description) }
        let none = await MainActor.run { ear.keeper }
        XCTAssertNil(none)
        await MainActor.run {
            link.compactAccepted = Compact.edition
            link.arrive(name: "Ama")
        }
        try await until("taken in") { ear.keeper != nil }
        let recorded = await MainActor.run { ear.keeper?.compact }
        XCTAssertEqual(recorded, Compact.edition)
        let kept = await steward.state.keepers.first?.compact
        XCTAssertEqual(kept, Compact.edition, "recorded at the realm, not only on the Mac")
        XCTAssertEqual(ArrivalPayload(decoding: ArrivalPayload(name: "Bel", compact: 3).encoded), ArrivalPayload(name: "Bel", compact: 3))
        XCTAssertEqual(ArrivalPayload(decoding: "Bel"), ArrivalPayload(name: "Bel", compact: nil), "an old build's arrival brings none")
        XCTAssertEqual(ArrivalPayload(decoding: ArrivalPayload(name: nil, compact: 2).encoded), ArrivalPayload(name: nil, compact: 2))
    }

    func testAKeeperIsCarriedToAnotherMacByTheirWords() async throws {
        let db = FakeSpacetime()
        let (steward, running, _) = try await steward(db)
        defer { running.cancel() }
        let (first, earFirst) = await MainActor.run { keeper(db) }
        let (second, earSecond) = await MainActor.run { keeper(db) }
        try await until("the realm's status") { earFirst.hasStatus && earSecond.hasStatus }
        await MainActor.run { first.arrive(name: "Ama") }
        try await until("Ama in") { earFirst.keeper != nil }

        let proof = KeeperWords.proof(of: KeeperWords.make())
        func seal(_ proof: String) async -> String? {
            await withCheckedContinuation { (done: CheckedContinuation<String?, Never>) in
                Task { @MainActor in first.seal(proof: proof) { done.resume(returning: $0) } }
            }
        }
        let kept = await seal(proof)
        XCTAssertNil(kept, "The realm keeps the words")
        let garbled = await seal("garbled")
        XCTAssertEqual(garbled, "The words' proof couldn't be read.")
        let firstIdentity = await MainActor.run { first.credentials?.identity }
        let sealed = await steward.state.keeper(try XCTUnwrap(firstIdentity))?.seal
        XCTAssertEqual(sealed, KeeperWords.seal(of: proof))

        await MainActor.run { second.reclaim(proof: KeeperWords.proof(of: KeeperWords.make())) }
        try await until("words not Ama's refused") { !earSecond.refusals.isEmpty }
        let refused = await MainActor.run { earSecond.refusals }
        XCTAssertEqual(refused, [RealmError.unknownWords.description])
        await MainActor.run { second.reclaim(proof: proof) }
        try await until("Ama on the second Mac") { earSecond.keeper != nil }
        let carried = await MainActor.run { earSecond.keeper?.name }
        XCTAssertEqual(carried, "Ama")
        let left = await steward.state.keeper(try XCTUnwrap(firstIdentity))
        XCTAssertNil(left, "The first Mac no longer speaks for Ama")
        await MainActor.run { second.leave() }
    }

    /// A keeper's client sees its hold in the world's models as the realm
    /// keeps it: a sawpit ordered over the link rises in its scaffold, the
    /// sawyers' rig at work beside it, every piece drawn within its budget.
    func testAKeepersClientSeesItsWorksRiseInTheirModels() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (link, ear) = await MainActor.run { keeper(db) }
        try await until("the realm's status") { ear.hasStatus }
        await MainActor.run { link.arrive(name: "Cai") }
        try await until("the keeper to arrive") { ear.keeper != nil }
        let house = try await MainActor.run { try XCTUnwrap(ear.keeper?.house) }
        let world = try await MainActor.run { try XCTUnwrap(ear.world) }
        let id = try XCTUnwrap(world.holds.first { $0.owner == house && $0.isSeat }?.id)
        let relief = Relief(map: world.map)
        XCTAssertEqual(HoldLayout.pieces(hold: try XCTUnwrap(world.hold(id)), relief: relief).map(\.key), [.keep(seat: true)])
        await MainActor.run { link.send(.build(hold: id, kind: .sawpit)) }
        try await until("the sawpit to be begun") { ear.world?.hold(id)?.project?.kind == .sawpit }
        let rising = try await MainActor.run { try XCTUnwrap(ear.world?.hold(id)) }
        let keys = HoldLayout.pieces(hold: rising, relief: relief, progress: 0.4).map(\.key)
        XCTAssertTrue(keys.contains(.work(.sawpit, level: 1)), "\(keys)")
        XCTAssertTrue(keys.contains(.scaffold))
        XCTAssertTrue(keys.contains(.raising(.sawpit)))
        for key in keys {
            let triangles = Library.model(key).mesh.triangleCount
            XCTAssertTrue((1...key.budget).contains(triangles), "\(key): \(triangles)")
        }
        await MainActor.run { link.close() }
    }

    func testKeepersMeetThroughTheSteward() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (a, earA) = await MainActor.run { keeper(db) }
        let (b, earB) = await MainActor.run { keeper(db) }
        try await until("the realm's status") { earA.hasStatus && earB.hasStatus }

        await MainActor.run {
            a.arrive(name: "Ama")
            b.arrive(name: "Bel")
        }
        try await until("both keepers to arrive") { earA.keeper != nil && earB.keeper != nil }
        let (houseA, houseB) = await MainActor.run { (earA.keeper!.house!, earB.keeper!.house!) }
        XCTAssertNotEqual(houseA, houseB)
        let worldA = try await MainActor.run { try XCTUnwrap(earA.world) }
        XCTAssertEqual(worldA.houses[houseA].title, "House Ama")

        // Ama's order is carried out; Bel's view never holds Ama's company,
        // out of sight, nor Ama's stores.
        let spear = try XCTUnwrap(worldA.units(of: houseA).first { $0.kind == .spear })
        await MainActor.run { a.send(.fortify(unit: spear.id)) }
        try await until("Ama's order to be carried out") { earA.world?.unit(spear.id)?.fortified == true }
        let belsWorld = try await MainActor.run { try XCTUnwrap(earB.world) }
        XCTAssertNil(belsWorld.unit(spear.id))
        XCTAssertEqual(belsWorld.houses[houseA].stock, .zero)
        XCTAssertEqual(belsWorld.settings.seedText, "")

        // Nor can a keeper read the world, or anyone's requests, directly.
        let stranger = try await db.createIdentity()
        for table in ["world", "world_part", "request", "keeper_view", "view_part", "reply"] {
            do {
                _ = try await db.query("SELECT * FROM \(table)", token: stranger.token)
                XCTFail("A keeper read the private \(table) table")
            } catch {}
        }

        // An order for another's company is refused, with the world as it stands.
        let theirs = try XCTUnwrap(belsWorld.units(of: houseB).first { $0.kind == .spear })
        await MainActor.run { a.send(.fortify(unit: theirs.id)) }
        try await until("the refusal") { !earA.refusals.isEmpty }

        // The watch turns when both are ready.
        await MainActor.run { a.setReady(true) }
        let deadline = Date().addingTimeInterval(20)
        while await db.handled(kind: "ready") < 1 {
            if Date() > deadline { return XCTFail("Ama's readiness was never carried out") }
            try await Task.sleep(nanoseconds: 10_000_000)
        }
        // Rounds of the steward, and polls of Ama's, after it: the watch
        // still waits.
        try await db.waitFor(3, more: FakeSpacetime.stewardRound)
        let amasToken = await MainActor.run { a.credentials?.token }
        try await db.waitFor(3, more: FakeSpacetime.statusPoll, by: try XCTUnwrap(amasToken))
        let early = await MainActor.run { earA.turned }
        XCTAssertFalse(early, "Bel isn't ready yet")
        await MainActor.run { b.setReady(true) }
        try await until("the watch to turn") { earA.turned && earB.turned }
        let watch = await MainActor.run { earB.world?.watch }
        XCTAssertEqual(watch, 2)
    }

    func testAQuietRealmIsNotReadAgainAndAgain() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (ama, ear) = await MainActor.run { keeper(db) }
        await MainActor.run { ama.arrive(name: "Ama") }
        try await until("arrival") { ear.keeper != nil }
        let amasToken = await MainActor.run { ama.credentials?.token }
        let token = try XCTUnwrap(amasToken)
        try await db.waitFor(3, more: FakeSpacetime.statusPoll, by: token)
        let before = await MainActor.run { ama.viewReads }
        // Twenty polls, with nothing published.
        try await db.waitFor(20, more: FakeSpacetime.statusPoll, by: token)
        let quiet = await MainActor.run { ama.viewReads } - before
        XCTAssertLessThanOrEqual(quiet, 1, "The view is read when the realm publishes, not on every poll")

        // An order publishes, and the view is read again: the order's own
        // answer brings the world it made, and the next poll, finding the
        // realm has published, reads the view for it.
        let world = try await MainActor.run { try XCTUnwrap(ear.world) }
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        await MainActor.run { ama.send(.fortify(unit: spear.id)) }
        try await until("the order") { ear.world?.unit(spear.id)?.fortified == true }
        try await until("the view read for the publication") { ama.viewReads > before + quiet }
    }

    func testAKeeperHearsWhatAnotherDoesAsItHappens() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (a, earA) = await MainActor.run { keeper(db) }
        let (b, earB) = await MainActor.run { keeper(db) }
        await MainActor.run {
            a.arrive(name: "Ama")
            b.arrive(name: "Bel")
        }
        try await until("both keepers") { earA.keeper != nil && earB.keeper != nil }
        let seat = await MainActor.run { earB.keeper?.house }
        let bel = try XCTUnwrap(seat)
        await MainActor.run { a.send(.gift(to: bel, resource: .grain, amount: 20)) }
        try await until("Bel to hear of Ama's gift") {
            earB.events.contains { event in
                if case .heard(let events) = event { return events.contains { if case .gifted = $0 { return true } else { return false } } }
                return false
            }
        }
        let amasToken = await MainActor.run { a.credentials?.token }
        try await db.waitFor(6, more: FakeSpacetime.statusPoll, by: try XCTUnwrap(amasToken))
        let toldOwn = await MainActor.run {
            earA.events.contains { if case .heard = $0 { return true } else { return false } }
        }
        XCTAssertFalse(toldOwn, "Ama isn't told of her own gift again")
    }

    func testAKeeperIsToldWhatAStewardAnswered() async throws {
        // The keeper's copy can't see a steward's stores, so can't know
        // whether it takes a trade: the realm says, after the order.
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (ama, ear) = await MainActor.run { keeper(db) }
        await MainActor.run { ama.arrive(name: "Ama") }
        try await until("arrival") { ear.keeper != nil }
        let world = try await MainActor.run { try XCTUnwrap(ear.world) }
        let mine = try await MainActor.run { try XCTUnwrap(ear.keeper?.house) }
        let other = try XCTUnwrap(world.houses.first { !$0.isPlayer && $0.temperament == .steadfast && !$0.isEliminated }?.id)
        XCTAssertEqual(world.houses[other].stock, .zero, "Another House's stores are hidden from the keeper")
        let trade = Trade(give: .timber, 12, for: .stone, 12)
        await MainActor.run { ama.send(.offerTrade(trade, to: other, words: nil)) }
        try await until("the realm's answer") {
            ear.events.contains { if case .answered = $0 { return true } else { return false } }
        }
        let answers = await MainActor.run { ear.events.compactMap { if case .answered(let events) = $0 { return events } else { return nil } } }
        XCTAssertEqual(answers.first, [.tradeAnswered(trade: trade, from: mine, to: other, accepted: true)])
        try await until("the stone to arrive") { (ear.world?.houses[mine].stock.stone ?? 0) == world.houses[mine].stock.stone + 12 }
        // And her view remembers how the steward answered her envoy, as the
        // next of its own to her will say.
        try await until("the answer remembered in her view") { ear.world?.lastAnswer(from: mine, to: other)?.answer == .accepted }
    }

    func testAKeeperConnectingMidWatchCountsItsTimeTrue() async throws {
        // The status is published now and then; a keeper connecting long
        // after takes off the time since, by the server's clock.
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let (first, early) = await MainActor.run { keeper(db) }
        try await until("a status") { early.lastStatus != nil }
        let published = try await MainActor.run { try XCTUnwrap(early.lastStatus?.secondsLeft) }
        XCTAssertGreaterThan(published, 20)
        await db.advance(15)
        let (second, late) = await MainActor.run { keeper(db) }
        try await until("a status") { late.lastStatus != nil }
        let heard = await MainActor.run { late.lastStatus?.secondsLeft }
        withExtendedLifetime((first, second)) {}
        XCTAssertEqual(heard, published - 15, "Fifteen seconds of the watch are gone")
        XCTAssertEqual(RealmStatus(name: "R", age: 1, watch: 1, seats: 1, freeSeats: 1, keepers: 0, online: 0, ready: 0,
                                   secondsLeft: 10, isEnding: false).aged(by: 30).secondsLeft, 0, "never below nothing")
    }

    func testHTTPDatesAreRead() {
        XCTAssertEqual(SpacetimeHTTP.httpDate("Mon, 26 Oct 2026 22:04:54 GMT")?.timeIntervalSince1970, 1_793_052_294)
        XCTAssertNil(SpacetimeHTTP.httpDate("yesterday"))
    }

    func testASilentStewardIsToldAndItsReturnToo() async throws {
        let db = FakeSpacetime()
        // A steward at work: its clock runs on past a heartbeat each round,
        // so it publishes every round, as a running realm always does
        // within the silence a keeper is told of.
        let credentials = try await db.createIdentity()
        let first = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "network test",
                                           seats: 4, watchLength: 600, now: 0)
        let clock = SteppingClock(step: RealmSteward.heartbeat + 1)
        let running = Task { await first.run(clock: { clock.next() }) }
        let (link, ear) = await MainActor.run { () -> (NetworkRealmLink, Listener) in
            let link = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05, stewardSilence: 0.6)
            let listener = Listener()
            listener.listen(to: link)
            link.connect()
            link.arrive(name: "Ama")
            return (link, listener)
        }
        try await until("arrival") { ear.keeper != nil }
        // Twice the silence, and never silent.
        try await Task.sleep(nanoseconds: 1_200_000_000)
        let early = await MainActor.run { ear.silenceTold }
        XCTAssertFalse(early, "A steward at work isn't silent")

        // The steward stops: within the silence, the keeper is told.
        running.cancel()
        try await until("the silence told") { ear.silenceTold }
        let count = await MainActor.run { ear.events.count }

        // Another steward takes up the realm; the realm stands again.
        await db.advance(61)
        let second = try await RealmSteward(transport: db, token: credentials.token, name: "x", seed: "x", now: 2)
        let again = Task { await second.run(clock: { 3 }) }
        defer { again.cancel() }
        try await until("the realm's status again") {
            ear.events.dropFirst(count).contains { if case .status = $0 { return true } else { return false } }
        }
        let told = await MainActor.run { ear.events.filter { if case .unreachable(NetworkRealmLink.silentSteward) = $0 { return true } else { return false } }.count }
        XCTAssertEqual(told, 1, "Told once")
        _ = link
    }

    func testAKeeperReturnsByIdentityAlone() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let store = MemoryStore()
        let (first, earFirst) = await MainActor.run { keeper(db, store: store) }
        await MainActor.run { first.arrive(name: "Ama") }
        try await until("arrival") { earFirst.keeper != nil }
        let house = await MainActor.run { earFirst.keeper?.house }
        XCTAssertNotNil(store.value, "The credentials are kept")
        await MainActor.run { first.leave() }

        let (again, earAgain) = await MainActor.run { keeper(db, store: store) }
        await MainActor.run { again.arrive(name: nil) }
        try await until("return") { earAgain.keeper != nil }
        let returned = await MainActor.run { earAgain.keeper?.house }
        XCTAssertEqual(returned, house, "Back to the same House")

        let (stranger, earStranger) = await MainActor.run { keeper(db) }
        await MainActor.run { stranger.arrive(name: nil) }
        try await until("refusal") { !earStranger.refusals.isEmpty }
    }

    func testOrdersGivenOutOfReachGoInOrderOnceItAnswers() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let line = Flaky(db)
        let (ama, ear) = await MainActor.run { () -> (NetworkRealmLink, Listener) in
            let link = NetworkRealmLink(transport: line, credentials: MemoryStore(), pollInterval: 0.05, retryDelay: 0.05)
            let listener = Listener()
            listener.listen(to: link)
            link.connect()
            link.arrive(name: "Ama")
            return (link, listener)
        }
        try await until("arrival") { ear.keeper != nil }
        let world = try await MainActor.run { try XCTUnwrap(ear.world) }
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })

        // The line goes down; two orders, whose order matters, and ready.
        await line.setDown(true)
        await MainActor.run {
            ama.send(.fortify(unit: spear.id))
            ama.send(.disband(unit: spear.id))
            ama.setReady(true)
        }
        try await until("the realm out of reach") {
            ear.events.contains { if case .unreachable = $0 { return true } else { return false } }
        }
        let waiting = await MainActor.run { ama.waiting }
        XCTAssertEqual(waiting, 3, "Nothing is lost")
        await line.setDown(false)
        try await until("the orders, carried out in turn") { ear.world?.unit(spear.id) == nil && ear.turned }
        let refusals = await MainActor.run { ear.refusals }
        XCTAssertEqual(refusals, [], "Fortified, then disbanded: in the order given")
        let after = await MainActor.run { ama.waiting }
        XCTAssertEqual(after, 0)
    }

    func testAnOrderWhoseAnswerWasLostIsCarriedOutOnce() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let line = Flaky(db)
        let (ama, ear) = await MainActor.run { () -> (NetworkRealmLink, Listener) in
            let link = NetworkRealmLink(transport: line, credentials: MemoryStore(), pollInterval: 0.05, retryDelay: 0.05)
            let listener = Listener()
            listener.listen(to: link)
            link.connect()
            link.arrive(name: "Ama")
            return (link, listener)
        }
        try await until("arrival") { ear.keeper != nil }
        let world = try await MainActor.run { try XCTUnwrap(ear.world) }
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let before = world.houses[house].stock
        // The order reaches the realm, but its answer is lost on the way back.
        await line.loseNextCall()
        await MainActor.run { ama.send(.barter(give: .timber, take: .grain, amount: 10)) }
        try await until("the barter") { ear.world?.houses[house].stock != before && ama.waiting == 0 }
        // Rounds of the steward after: nothing carried out again.
        try await db.waitFor(4, more: FakeSpacetime.stewardRound)
        let orders = await db.handled(kind: "order")
        XCTAssertEqual(orders, 1, "Sent twice, carried out once")
        let stock = await MainActor.run { ear.world?.houses[house].stock }
        XCTAssertEqual(stock?.grain, before.grain + 10, "Ten grain bought, once")
    }

    func testARoundWhosePublicationFailedIsPublishedOnceAfter() async throws {
        let db = FakeSpacetime()
        let owner = try await db.createIdentity()
        let line = Flaky(db)
        let steward = try await RealmSteward(transport: line, token: owner.token, name: "The Nullmere", seed: "publish fails",
                                             seats: 4, watchLength: 600, now: 0)
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        try await steward.step(now: 1)
        let keeper = await steward.state.keeper(ama.identity)
        let house = try XCTUnwrap(keeper?.house)
        let before = await steward.state.world.houses[house].stock

        try await db.call("order", [.string("a2"), .string(String(decoding: try JSONEncoder().encode(Command.barter(give: .timber, take: .grain, amount: 10)), as: UTF8.self))], token: ama.token)
        await line.failNext("publish")
        do {
            try await steward.step(now: 2)
            XCTFail("The publication was lost")
        } catch {}
        let unanswered = try await db.query("SELECT * FROM my_replies", token: ama.token)
        XCTAssertFalse(unanswered.contains { $0.first?.string == "a2" }, "No answer for a world not kept")

        try await steward.step(now: 3)
        let answered = try await db.query("SELECT * FROM my_replies", token: ama.token)
        XCTAssertTrue(answered.contains { $0.first?.string == "a2" })
        let grain = await steward.state.world.houses[house].stock.grain
        XCTAssertEqual(grain, before.grain + 10, "Carried out once")
        let kept = try await db.query("SELECT name, text FROM world_part", token: owner.token)
        let world = try RealmState(parts: Dictionary(uniqueKeysWithValues: kept.map { ($0[0].string ?? "", $0[1].string ?? "") }))
        XCTAssertEqual(world.world.houses[house].stock.grain, before.grain + 10, "and kept")
    }

    /// A realm of two keepers whose steward publishes the world, each page
    /// told alike and each view in calls of their own, and a round of it,
    /// Ama speaking to the realm and Bo bartering, whose call showing Bo
    /// his view, the last, is lost.
    private struct PartWay {
        let db: FakeSpacetime
        let owner: SpacetimeCredentials
        let steward: RealmSteward
        let ama: SpacetimeCredentials, bo: SpacetimeCredentials
        let amasHouse: Int, bosHouse: Int
        let words: String
        let grain: Int
        /// The status's version before the round, and after its calls kept.
        let before: UInt64, kept: UInt64

        func published() async throws -> UInt64 {
            let rows = try await db.query("SELECT version FROM status", token: owner.token)
            return try XCTUnwrap(rows.first?.first?.number.map { UInt64($0) })
        }

        /// Whether a keeper's view as the server keeps it has the words.
        func heard(_ keeper: SpacetimeCredentials, _ house: Int) async throws -> Bool {
            let view = try await db.keptView(of: keeper.identity)
            return view?.world.words(heardBy: house).contains { $0.text == words } == true
        }
    }

    private func publicationLostPartWay() async throws -> PartWay {
        let db = FakeSpacetime()
        let owner = try await db.createIdentity()
        let line = Flaky(db)
        let steward = try await RealmSteward(transport: line, token: owner.token, name: "The Nullmere", seed: "publish part way",
                                             seats: 4, watchLength: 600, now: 0)
        await steward.setPublicationBudget(1)
        let ama = try await db.createIdentity(), bo = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        try await db.call("arrive", [.string("b1"), .string(ArrivalPayload(name: "Bo", compact: Compact.edition).encoded)], token: bo.token)
        try await steward.step(now: 1)
        let (publications, calls) = (await steward.publications, await steward.publicationCalls)
        XCTAssertGreaterThanOrEqual(calls - publications, 2, "The world, the pages told alike and each view in calls of their own")
        let seated = await steward.state
        let amasHouse = try XCTUnwrap(seated.keeper(ama.identity)?.house)
        let bosHouse = try XCTUnwrap(seated.keeper(bo.identity)?.house)
        let grain = seated.world.houses[bosHouse].stock.grain

        let words = "The reeds are whispering"
        let say = String(decoding: try JSONEncoder().encode(Command.say(words: words, toAlliance: false)), as: UTF8.self)
        let barter = String(decoding: try JSONEncoder().encode(Command.barter(give: .timber, take: .grain, amount: 10)), as: UTF8.self)
        try await db.call("order", [.string("a2"), .string(say)], token: ama.token)
        try await db.call("order", [.string("b2"), .string(barter)], token: bo.token)
        let rows = try await db.query("SELECT version FROM status", token: owner.token)
        let before = try XCTUnwrap(rows.first?.first?.number.map { UInt64($0) })
        await line.failCall(showing: bo.identity)
        do {
            try await steward.step(now: 2)
            XCTFail("The last call was lost")
        } catch {}
        let after = try await db.query("SELECT version FROM status", token: owner.token)
        let kept = try XCTUnwrap(after.first?.first?.number.map { UInt64($0) })
        return PartWay(db: db, owner: owner, steward: steward, ama: ama, bo: bo, amasHouse: amasHouse, bosHouse: bosHouse,
                       words: words, grain: grain, before: before, kept: kept)
    }

    /// A publication in several calls that fails part way: the calls the
    /// server kept stand, the world and both answers among them, and the
    /// next round shows the keeper whose call never reached it their view,
    /// numbered on from the last call kept.
    func testAPublicationFailedPartWayShowsTheRestNext() async throws {
        let realm = try await publicationLostPartWay()
        XCTAssertGreaterThan(realm.kept, realm.before, "The calls before Bo's kept: the world's, and Ama's view")
        for (keeper, nonce) in [(realm.ama, "a2"), (realm.bo, "b2")] {
            let replies = try await realm.db.query("SELECT * FROM my_replies", token: keeper.token)
            XCTAssertTrue(replies.contains { $0.first?.string == nonce }, "\(nonce) answered with the world")
        }
        let amaHeard = try await realm.heard(realm.ama, realm.amasHouse)
        let boHeard = try await realm.heard(realm.bo, realm.bosHouse)
        XCTAssertTrue(amaHeard)
        XCTAssertFalse(boHeard, "Bo's view never reached the server")

        // The next round, nothing new asked: Bo is shown the realm as it is.
        try await realm.steward.step(now: 3)
        let boHeardAfter = try await realm.heard(realm.bo, realm.bosHouse)
        XCTAssertTrue(boHeardAfter)
        let state = await realm.steward.state
        let bosView = try await realm.db.keptView(of: realm.bo.identity)
        XCTAssertEqual(bosView, state.view(for: realm.bo.identity))
        XCTAssertEqual(bosView?.world.houses[realm.bosHouse].stock.grain, realm.grain + 10)
        let after = try await realm.published()
        let version = await realm.steward.version
        XCTAssertGreaterThan(after, realm.kept, "Numbered on from the last call kept")
        XCTAssertEqual(after, version)
        let orders = await realm.db.handled(kind: "order")
        XCTAssertEqual(orders, 2, "Each carried out once")
    }

    /// The steward stops just after a publication failed part way: another
    /// takes up the realm as the server kept it, the world with both orders
    /// carried out, and carries neither out again.
    func testAStewardStoppedBetweenCallsCarriesNothingOutTwice() async throws {
        let realm = try await publicationLostPartWay()
        await realm.db.advance(61)
        let second = try await RealmSteward(transport: realm.db, token: realm.owner.token, name: "ignored", seed: "ignored", now: 3)
        // Bo is still there, and says so.
        try await realm.db.call("here", [.string("b3")], token: realm.bo.token)
        try await second.step(now: 4)
        let state = await second.state
        XCTAssertEqual(state.world.houses[realm.bosHouse].stock.grain, realm.grain + 10, "Bo's barter carried out once")
        XCTAssertEqual(state.world.words(heardBy: realm.bosHouse).filter { $0.text == realm.words }.count, 1, "Ama's words said once")
        let orders = await realm.db.handled(kind: "order")
        XCTAssertEqual(orders, 2)
        let boHeard = try await realm.heard(realm.bo, realm.bosHouse)
        XCTAssertTrue(boHeard, "Bo shown the realm as it was kept")
    }

    /// A publication whose world goes ahead of it, one of those calls lost:
    /// nothing of it is the world and no answer is given; the next round
    /// sends it all ahead again and publishes it, the world the server keeps
    /// the steward's own, nothing left aside, and the arrival carried out
    /// once.
    func testAWorldSentAheadAndLostIsSentAgain() async throws {
        let db = FakeSpacetime()
        let owner = try await db.createIdentity()
        let line = Flaky(db)
        let steward = try await RealmSteward(transport: line, token: owner.token, name: "The Nullmere", seed: "sent ahead and lost",
                                             seats: 4, watchLength: 600, budget: 1_000, now: 0)
        let first = await steward.callsSentAhead
        XCTAssertGreaterThan(first, 1, "The first world sent ahead of the call that publishes it")
        let kept = await db.worldParts
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        await line.failNext("send_ahead")
        do {
            try await steward.step(now: 1)
            XCTFail("A call sending the world ahead was lost")
        } catch {}
        let unchanged = await db.worldParts
        XCTAssertEqual(unchanged, kept, "Nothing of it the world")
        let unanswered = try await db.query("SELECT * FROM my_replies", token: ama.token)
        XCTAssertTrue(unanswered.isEmpty, "Nor any answer given")

        try await steward.step(now: 2)
        let answered = try await db.query("SELECT * FROM my_replies", token: ama.token)
        XCTAssertTrue(answered.contains { $0.first?.string == "a1" }, "Answered once it is published")
        let published = await db.worldParts
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        let world = try await steward.state.parts(using: encoder)
        XCTAssertEqual(published, world, "The world the server keeps is the steward's")
        let aside = await db.sentAhead
        XCTAssertTrue(aside.isEmpty, "Nothing left aside")
        let arrivals = await db.handled(kind: "arrive")
        XCTAssertEqual(arrivals, 1)
        let again = await steward.callsSentAhead
        XCTAssertGreaterThan(again, first, "Sent ahead again")
    }

    func testAStewardThatStopsBeforePublishingLosesNothing() async throws {
        let db = FakeSpacetime()
        let owner = try await db.createIdentity()
        let line = Flaky(db)
        let first = try await RealmSteward(transport: line, token: owner.token, name: "The Nullmere", seed: "steward stops",
                                           seats: 4, watchLength: 600, now: 0)
        let ama = try await db.createIdentity()
        try await db.call("arrive", [.string("a1"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: ama.token)
        try await first.step(now: 1)
        let keeper = await first.state.keeper(ama.identity)
        let house = try XCTUnwrap(keeper?.house)
        let before = await first.state.world.houses[house].stock
        try await db.call("order", [.string("a2"), .string(String(decoding: try JSONEncoder().encode(Command.barter(give: .timber, take: .grain, amount: 10)), as: UTF8.self))], token: ama.token)
        await line.failNext("publish")
        _ = try? await first.step(now: 2)

        // The steward stops here; once its hold on the realm lapses, another
        // takes up the realm as it was kept, and carries the order out once.
        await db.advance(61)
        let second = try await RealmSteward(transport: db, token: owner.token, name: "ignored", seed: "ignored", now: 3)
        let firstVersion = await first.version
        let secondVersion = await second.version
        XCTAssertGreaterThan(secondVersion, firstVersion - 1, "Versions never run back")
        try await second.step(now: 4)
        let grain = await second.state.world.houses[house].stock.grain
        XCTAssertEqual(grain, before.grain + 10)
        let orders = await db.handled(kind: "order")
        XCTAssertEqual(orders, 1)
    }

    func testOneStewardHoldsTheRealmAtATime() async throws {
        let db = FakeSpacetime()
        let (first, running, credentials) = try await steward(db)
        defer { running.cancel() }
        do {
            _ = try await RealmSteward(transport: db, token: credentials.token, name: "x", seed: "x", now: 1)
            XCTFail("A second steward took up a realm already held")
        } catch {
            XCTAssertTrue(RealmSteward.isHeldByAnother(error), "\(error)")
        }
        // The first keeps its hold, round after round.
        try await first.step(now: 30)
        let displaced = await first.isDisplaced
        XCTAssertFalse(displaced)

        // Should the first fall silent past its hold, another may take the
        // realm, and the first, finding it held, stops.
        running.cancel()
        await db.advance(61)
        let second = try await RealmSteward(transport: db, token: credentials.token, name: "x", seed: "x", now: 2)
        do {
            try await first.step(now: 100)
            XCTFail("The old steward published over the new")
        } catch {
            let stopped = await first.isDisplaced
            XCTAssertTrue(stopped)
        }
        try await second.step(now: 3)
    }

    /// A steward that fell silent past its hold, set running again after
    /// another has taken up the realm, finds it held, says so and stops.
    func testARunningStewardFindingTheRealmHeldSaysSoAndStops() async throws {
        let db = FakeSpacetime()
        let (first, running, credentials) = try await steward(db)
        running.cancel()
        await running.value
        await db.advance(61)
        _ = try await RealmSteward(transport: db, token: credentials.token, name: "x", seed: "x", now: 2)
        let said = Said()
        await first.setReporter { said.add($0) }
        await first.run(clock: { 100 })
        let displaced = await first.isDisplaced
        XCTAssertTrue(displaced, "It stops of itself")
        XCTAssertTrue(said.lines.contains { $0.hasPrefix("Another steward holds the realm; this one stops.") }, "\(said.lines)")
    }

    /// A key the server won't take, as the keeper looks on, is kept: never
    /// erased, never made anew. The keeper is told plainly, and when the
    /// server takes the key again the realm answers as before.
    func testAKeyTheServerWontTakeIsNeverMadeAnew() async throws {
        let db = FakeSpacetime()
        let (_, running, _) = try await steward(db)
        defer { running.cancel() }
        let store = MemoryStore()
        let (link, ear) = await MainActor.run { keeper(db, store: store) }
        await MainActor.run { link.arrive(name: "Ama") }
        try await until("arrival") { ear.keeper != nil }
        let kept = await MainActor.run { link.credentials }
        let old = try XCTUnwrap(kept)
        let key = try XCTUnwrap(store.value)

        await db.forget(token: old.token)
        try await until("the keeper told") {
            ear.events.contains { if case .unreachable(SpacetimeError.unauthorized.description) = $0 { return true } else { return false } }
        }
        let still = await MainActor.run { link.credentials }
        XCTAssertEqual(still, old, "The key is kept")
        XCTAssertEqual(store.value, key, "and never erased")
        let doors = await MainActor.run { ear.events.filter { if case .refused = $0 { return true } else { return false } }.count }
        XCTAssertEqual(doors, 0, "The keeper isn't sent to the door to begin anew")

        // The server takes it again: the realm answers, to the same keeper.
        let told = await MainActor.run { ear.events.count }
        await db.remember(old)
        try await until("the realm's status again") {
            ear.events.dropFirst(told).contains { if case .status = $0 { return true } else { return false } }
        }
        let after = await MainActor.run { link.credentials }
        XCTAssertEqual(after, old)
        await MainActor.run { link.leave() }
    }

    func testOneKeepersFloodDoesNotCrowdOutAnother() async throws {
        let db = FakeSpacetime()
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "flood",
                                             seats: 4, watchLength: 600, now: 0)
        let loud = try await db.createIdentity()
        let quiet = try await db.createIdentity()
        for index in 0..<30 {
            try await db.call("here", [.string("loud-\(index)")], token: loud.token)
        }
        try await db.call("arrive", [.string("quiet-arrives"), .string(ArrivalPayload(name: "Ama", compact: Compact.edition).encoded)], token: quiet.token)
        try await steward.step(now: 1)
        let answered = try await db.query("SELECT * FROM my_replies", token: quiet.token)
        XCTAssertTrue(answered.contains { $0.first?.string == "quiet-arrives" }, "The quiet keeper is heard in the first round")
        let loudAnswered = try await db.query("SELECT * FROM my_replies", token: loud.token)
        XCTAssertEqual(loudAnswered.count, RealmSteward.requestsPerRound, "The loud one a few at a time")
        try await steward.step(now: 2)
        let more = try await db.query("SELECT * FROM my_replies", token: loud.token)
        XCTAssertEqual(more.count, RealmSteward.requestsPerRound * 2)
    }

    func testANewStewardTakesUpTheRealmWhereItStands() async throws {
        let db = FakeSpacetime()
        let (first, running, credentials) = try await steward(db)
        let (link, ear) = await MainActor.run { keeper(db) }
        await MainActor.run { link.arrive(name: "Ama") }
        try await until("arrival") { ear.keeper != nil }
        await MainActor.run { link.setReady(true) }
        try await until("the watch") { ear.turned }
        running.cancel()
        let watch = await first.state.world.watch
        let version = await first.version

        // The steward starts again, as after a restart, once its old hold
        // on the realm has lapsed.
        await db.advance(61)
        let resumed = try await RealmSteward(transport: db, token: credentials.token, name: "ignored", seed: "ignored", now: 2)
        let resumedWatch = await resumed.state.world.watch
        let resumedVersion = await resumed.version
        XCTAssertEqual(resumedWatch, watch)
        XCTAssertGreaterThan(resumedVersion, version)
        let anyoneThere = await resumed.state.keepers.contains { $0.isOnline }
        XCTAssertFalse(anyoneThere, "No one is there until they say so")
    }
}

/// A line to SpacetimeDB that can go down, or lose an answer on the way back.
actor Flaky: SpacetimeTransport {
    private let db: FakeSpacetime
    private var down = false
    private var losing = false
    private var failing: Set<String> = []

    init(_ db: FakeSpacetime) { self.db = db }

    func setDown(_ value: Bool) { down = value }
    func loseNextCall() { losing = true }
    /// The next call to this reducer is carried out, but its answer is lost.
    func loseAnswer(to reducer: String) { losingAnswers.insert(reducer) }
    private var losingAnswers: Set<String> = []
    /// The next call to this reducer never reaches the server.
    func failNext(_ reducer: String) { failing.insert(reducer) }
    /// The next publication's call showing this keeper their view never
    /// reaches the server: one call of a publication in several.
    func failCall(showing keeper: String) { failingShown = keeper }
    private var failingShown: String?
    /// Answers asked after by their nonce wait until let through.
    func holdAnswers(_ hold: Bool) { holdingAnswers = hold }
    private var holdingAnswers = false
    /// An answer asked after is being held.
    private(set) var isHoldingAnAnswer = false

    func createIdentity() async throws -> SpacetimeCredentials {
        if down { throw SpacetimeError("The network is down.") }
        return try await db.createIdentity()
    }

    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        if down { throw SpacetimeError("The network is down.") }
        if failing.remove(reducer) != nil { throw SpacetimeError("The call to \(reducer) was lost.") }
        if reducer == "publish", let keeper = failingShown, arguments.count > 5, case .strings(let shown) = arguments[5], shown.contains(keeper) {
            failingShown = nil
            throw SpacetimeError("The call to \(reducer) was lost.")
        }
        try await db.call(reducer, arguments, token: token)
        if losingAnswers.remove(reducer) != nil { throw SpacetimeError("The answer was lost.") }
        if losing, reducer == "order" {
            losing = false
            throw SpacetimeError("The answer was lost.")
        }
    }

    func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        if down { throw SpacetimeError("The network is down.") }
        if holdingAnswers, sql.hasPrefix("SELECT * FROM my_replies") {
            // Held however the one asking fares meanwhile, as a slow
            // server's answer is.
            isHoldingAnAnswer = true
            while holdingAnswers { await Task.detached { try? await Task.sleep(nanoseconds: 10_000_000) }.value }
            isHoldingAnAnswer = false
        }
        return try await db.query(sql, token: token)
    }
}

/// What a steward said, from wherever it said it.
private final class Said: @unchecked Sendable {
    private let lock = NSLock()
    private var kept: [String] = []

    func add(_ line: String) {
        lock.lock()
        kept.append(line)
        lock.unlock()
    }

    var lines: [String] {
        lock.lock()
        defer { lock.unlock() }
        return kept
    }
}

/// A steward's clock that runs on by a step at every reading.
private final class SteppingClock: @unchecked Sendable {
    private let lock = NSLock()
    private var now = 0.0
    private let step: Double

    init(step: Double) {
        self.step = step
    }

    func next() -> Double {
        lock.lock()
        defer { lock.unlock() }
        now += step
        return now
    }
}


/// Keepers of an alliance break a lair of the wilds together, each from
/// their own client, through the steward.
final class NetworkRallyTests: XCTestCase {
    @MainActor
    private func keeper(_ db: FakeSpacetime) -> (NetworkRealmLink, Listener) {
        let link = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        let listener = Listener()
        listener.listen(to: link)
        link.connect()
        return (link, listener)
    }

    func testAnAllianceRallyBreaksALairFromTwoClients() async throws {
        let db = FakeSpacetime()
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "rally on a lair",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        defer { running.cancel() }
        let (a, earA) = await MainActor.run { keeper(db) }
        let (b, earB) = await MainActor.run { keeper(db) }
        await MainActor.run { a.arrive(name: "Ama"); b.arrive(name: "Bel") }
        let scene = RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 20)
        try await scene.until("both keepers to arrive") { earA.keeper != nil && earB.keeper != nil }
        let (ama, bel) = await MainActor.run { (earA.keeper!.house!, earB.keeper!.house!) }

        // An alliance sworn between them, each by their own orders.
        await MainActor.run { a.send(.foundAlliance(name: "The Long Spear")) }
        try await scene.until("the alliance founded") { earA.world?.alliance(of: ama) != nil }
        await MainActor.run { a.send(.inviteToAlliance(house: bel)) }
        let alliance = try await MainActor.run { try XCTUnwrap(earA.world?.alliance(of: ama)).id }
        try await scene.until("Bel to hear the invitation") { earB.world?.alliancesStanding.first { $0.id == alliance }?.invited.contains(bel) == true }
        await MainActor.run { b.send(.answerInvitation(alliance: alliance, accept: true)) }
        try await scene.until("both to see the alliance sworn") {
            earA.world?.areAllied(ama, bel) == true && earB.world?.areAllied(ama, bel) == true
        }
        try await scene.helpEachOther(ama: ama, bel: bel)
        try await scene.breakALair(ama: ama, bel: bel)
        try await scene.writeAndTrade(ama: ama, bel: bel)
        try await scene.foretellAHappening(ama: ama, bel: bel)
        try await scene.laboursOfTheWatch(ama: ama, bel: bel)
        try await scene.openTheInnsChests(ama: ama, bel: bel)
        try await scene.walkTheMirror(ama: ama, bel: bel)
        try await scene.heedTheBeacon(ama: ama, bel: bel)
        try await scene.breakTheCalm(ama: ama, bel: bel)
        try await scene.gatherAndBringItHome(ama: ama, bel: bel)
        try await scene.hideAHouse(ama: ama, bel: bel)
        try await scene.makeTheWordsSafe(ama: ama, bel: bel)
        try await scene.teachTheLakeToLie(ama: ama, bel: bel)
        try await scene.keepAVigil(ama: ama, bel: bel)
        try await scene.markTheGround(ama: ama, bel: bel)
        try await scene.upTheSpine(ama: ama, bel: bel)
        // Last: its watches turned would move the pedlar's and others' staged watches.
        try await scene.raiseAStandardTogether(ama: ama, bel: bel)
        // After all else, its turned watch and its company's id moving none of theirs.
        try await scene.setTheWoodAlight(ama: ama, bel: bel)
        // And after it, for it parts the two Houses' sight.
        try await scene.marchInTheDark(ama: ama, bel: bel)
        // With their sight parted, each House's seeking its own.
        try await scene.seekAHamlet(ama: ama, bel: bel)
        // Last, for it sets the two Houses at war.
        try await scene.lieInWait(ama: ama, bel: bel)
    }

    func testAGreatBattleOfFourHundredThousandFromTwoClients() async throws {
        let db = FakeSpacetime()
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "the great battle",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        defer { running.cancel() }
        let (a, earA) = await MainActor.run { keeper(db) }
        let (b, earB) = await MainActor.run { keeper(db) }
        await MainActor.run { a.arrive(name: "Ama"); b.arrive(name: "Bel") }
        let scene = RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 20)
        try await scene.until("both keepers to arrive") { earA.keeper != nil && earB.keeper != nil }
        let (ama, bel) = await MainActor.run { (earA.keeper!.house!, earB.keeper!.house!) }
        await MainActor.run { a.send(.declareWar(on: bel)) }
        try await scene.until("war, as both see it") { earA.world?.isAtWar(ama, bel) == true && earB.world?.isAtWar(ama, bel) == true }
        try await scene.fightAGreatBattle(ama: ama, bel: bel)
    }

    func testTwoAlliancesContestTheDrownedCrownFromTheirClients() async throws {
        let db = FakeSpacetime()
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "the crown contested",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        defer { running.cancel() }
        let (a, earA) = await MainActor.run { keeper(db) }
        let (b, earB) = await MainActor.run { keeper(db) }
        await MainActor.run { a.arrive(name: "Ama"); b.arrive(name: "Bel") }
        let scene = RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 20)
        try await scene.until("both keepers to arrive") { earA.keeper != nil && earB.keeper != nil }
        let (ama, bel) = await MainActor.run { (earA.keeper!.house!, earB.keeper!.house!) }
        try await scene.contestTheCrown(ama: ama, bel: bel)
        try await scene.waitInLine(ama: ama, bel: bel) { NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05) }
        try await scene.sitTheLyceum(ama: ama, bel: bel)
    }
}
