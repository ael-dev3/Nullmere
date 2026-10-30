import Foundation
import NullmereCore
import XCTest
@testable import NullmereRealm
import NullmereTestSupport

/// The realm on a real SpacetimeDB server: the module published, the
/// steward running, two keepers playing. CI sets NULLMERE_STDB to the
/// database's address and NULLMERE_STDB_TOKEN to the publisher's token.
final class SpacetimeIntegrationTests: XCTestCase {
    private func server() throws -> (SpacetimeHTTP, String) {
        let environment = ProcessInfo.processInfo.environment
        guard let text = environment["NULLMERE_STDB"], let url = URL(string: text), let transport = SpacetimeHTTP(address: url),
              let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB and NULLMERE_STDB_TOKEN to test against a SpacetimeDB server")
        }
        return (transport, token)
    }

    private func until(_ what: String, timeout: Double = 60, _ condition: @escaping @MainActor @Sendable () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !MainActor.run(body: condition) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func testTheModuleKeepsTheWorldForTheStewardAlone() async throws {
        let (transport, token) = try server()
        let stranger = try await transport.createIdentity()
        do {
            try await transport.call("publish", [.integer(999_999), .strings(["head"]), .strings(["{}"]), .strings([]), .string("{}"),
                                                 .strings([]), .strings([]), .strings([]), .integers([]), .strings([]), .string("stranger")],
                                     token: stranger.token)
            XCTFail("A stranger wrote the world")
        } catch {
            XCTAssertTrue(String(describing: error).contains("steward"), "\(error)")
        }
        _ = token
    }

    func testARequestSentTwiceWaitsOnce() async throws {
        let (transport, token) = try server()
        let keeper = try await transport.createIdentity()
        let nonce = "twice" + KeeperIdentity.make().prefix(12)
        try await transport.call("here", [.string(nonce)], token: keeper.token)
        try await transport.call("here", [.string(nonce)], token: keeper.token)
        let waiting = try await transport.query("SELECT id FROM request WHERE nonce = \(sqlString(nonce))", token: token)
        let answered = try await transport.query("SELECT nonce FROM reply WHERE nonce = \(sqlString(nonce))", token: token)
        XCTAssertEqual(waiting.count + answered.count, 1, "The same request, once")
        // The keeper asks after it by its nonce alone, as the link does.
        let mine = try await transport.query("SELECT nonce FROM my_requests WHERE nonce = \(sqlString(nonce))", token: keeper.token)
        let theirs = try await transport.query("SELECT * FROM my_replies WHERE nonce = \(sqlString(nonce))", token: keeper.token)
        XCTAssertEqual(mine.count + theirs.count, 1, "and finds it, by its nonce")
        print("REALM a request sent twice was taken once, and found by its nonce")
    }

    /// The module's own bounds, as the fake keeps them: a nonce of one to
    /// sixty-four bytes, a payload of four kilobytes at most.
    func testTheModuleKeepsARequestWithinItsBounds() async throws {
        let (transport, _) = try server()
        let keeper = try await transport.createIdentity()
        func refusal(_ reducer: String, _ arguments: [ReducerArgument]) async -> String? {
            do {
                try await transport.call(reducer, arguments, token: keeper.token)
                return nil
            } catch {
                return "\(error)"
            }
        }
        let tag = String(KeeperIdentity.make().prefix(8))
        let nonce = "A request needs a nonce of 1 to 64 characters."
        let none = await refusal("here", [.string("")])
        XCTAssertEqual(none, nonce)
        let wide = await refusal("here", [.string(String(repeating: "é", count: 33))])
        XCTAssertEqual(wide, nonce, "Counted in bytes")
        let most = await refusal("here", [.string(tag + String(repeating: "n", count: FakeSpacetime.maxNonce - tag.count))])
        XCTAssertNil(most)
        let heavy = await refusal("order", [.string(tag + "-heavy"), .string(String(repeating: "x", count: FakeSpacetime.maxPayload + 1))])
        XCTAssertEqual(heavy, "The request is too long.")
        let full = await refusal("order", [.string(tag + "-full"), .string(String(repeating: "x", count: FakeSpacetime.maxPayload))])
        XCTAssertNil(full)
        print("REALM the module keeps a request within its bounds")
    }

    /// A key the server never issued is refused as such, never as anything
    /// a keeper's client would take for a realm that has forgotten them.
    func testAKeyTheServerDoesntKnowIsRefusedAsSuch() async throws {
        let (transport, _) = try server()
        do {
            _ = try await transport.query("SELECT version FROM status", token: "not.a.key")
            XCTFail("A key never issued was taken")
        } catch {
            XCTAssertEqual(error as? SpacetimeError, .unauthorized, "\(error)")
        }
    }

    /// A publication refused, here for a version already passed, takes no
    /// hold on the realm, as the fake keeps it: the reducer's failure undoes
    /// the hold it took with the rest. A minute and more, waiting for holds
    /// to lapse.
    func testAPublicationRefusedTakesNoHold() async throws {
        let (transport, token) = try server()
        let first = try await takeUp(transport, token)
        let version = await first.version
        try await Task.sleep(nanoseconds: UInt64((FakeSpacetime.leaseSeconds + 2) * 1_000_000_000))
        do {
            try await transport.call("publish", [.integer(version), .strings([]), .strings([]), .strings([]), .string("{}"), .strings([]),
                                                 .strings([]), .strings([]), .integers([]), .strings([]), .string("a stranger's hold")],
                                     token: token)
            XCTFail("A publication for a version passed was kept")
        } catch {
            XCTAssertTrue("\(error)".contains("is not after"), "\(error)")
        }
        do {
            _ = try await RealmSteward(transport: transport, token: token, name: "x", seed: "x", now: Date().timeIntervalSince1970)
        } catch {
            XCTFail("The refused publication held the realm: \(error)")
        }
        print("REALM a publication refused took no hold on the realm")
    }

    /// A steward that takes up the realm (or begins it, so shaped), once the
    /// hold of any that came before, in an earlier test, has lapsed.
    private func takeUp(_ transport: SpacetimeHTTP, _ token: String, seats: Int = 4, watchLength: Double = 600) async throws -> RealmSteward {
        let deadline = Date().addingTimeInterval(100)
        while true {
            do {
                return try await RealmSteward(transport: transport, token: token, name: "The Nullmere", seed: "integration",
                                              seats: seats, watchLength: watchLength, now: Date().timeIntervalSince1970)
            } catch where RealmSteward.isHeldByAnother(error) && Date() < deadline {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    func testKeepersPlayThroughSpacetime() async throws {
        let (transport, token) = try server()
        let steward = try await takeUp(transport, token, seats: 4, watchLength: 600)
        let running = Task { await steward.run() }
        defer { running.cancel() }

        // A second steward, started by mistake, finds the realm held.
        do {
            _ = try await RealmSteward(transport: transport, token: token, name: "x", seed: "x", now: Date().timeIntervalSince1970)
            XCTFail("Two stewards held the realm at once")
        } catch {
            XCTAssertTrue(RealmSteward.isHeldByAnother(error), "\(error)")
            print("REALM a second steward found the realm held")
        }

        let (a, earA, b, earB) = await MainActor.run { () -> (NetworkRealmLink, Listener, NetworkRealmLink, Listener) in
            let a = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 0.2)
            let b = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 0.2)
            let earA = Listener(), earB = Listener()
            earA.listen(to: a)
            earB.listen(to: b)
            a.connect()
            b.connect()
            return (a, earA, b, earB)
        }
        // A third client that, on its own, would read the realm only every
        // two minutes: it hears what happens at once, by SpacetimeDB's push.
        let (c, earC) = await MainActor.run { () -> (NetworkRealmLink, Listener) in
            let c = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 120)
            let earC = Listener()
            earC.listen(to: c)
            c.connect()
            return (c, earC)
        }
        try await until("the realm's status") { earA.hasStatus && earB.hasStatus }
        let suffix = String(KeeperIdentity.make().filter(\.isLetter).prefix(6))
        await MainActor.run {
            a.arrive(name: "Ama" + suffix)
            b.arrive(name: "Bel" + suffix)
        }
        try await until("both keepers to arrive") { earA.keeper != nil && earB.keeper != nil }
        let houseA = try await MainActor.run { try XCTUnwrap(earA.keeper?.house) }
        let world = try await MainActor.run { try XCTUnwrap(earA.world) }
        let spear = try XCTUnwrap(world.units(of: houseA).first { $0.kind == .spear })
        await MainActor.run { a.send(.fortify(unit: spear.id)) }
        try await until("Ama's order to be carried out") { earA.world?.unit(spear.id)?.fortified == true }
        let belsWorld = try await MainActor.run { try XCTUnwrap(earB.world) }
        XCTAssertNil(belsWorld.unit(spear.id), "Ama's company is out of Bel's sight")
        XCTAssertEqual(belsWorld.houses[houseA].stock, .zero, "and Ama's stores are Ama's to know")

        // Private tables stay private to a keeper.
        let stranger = try await transport.createIdentity()
        for table in ["world", "world_part", "request", "keeper_view", "reply"] {
            let rows = (try? await transport.query("SELECT * FROM \(table)", token: stranger.token)) ?? []
            XCTAssertTrue(rows.isEmpty, "A keeper read the private \(table) table")
        }

        // A stranger's "here" is answered, that the realm doesn't know them:
        // the answer a client reads, by its nonce alone, to find a realm
        // begun anew.
        let here = "here-" + KeeperIdentity.make().prefix(12)
        try await transport.call("here", [.string(here)], token: stranger.token)
        var answer: RealmReply?
        for _ in 0..<200 where answer == nil {
            let rows = try await transport.query("SELECT * FROM my_replies WHERE nonce = \(sqlString(here))", token: stranger.token)
            if let text = rows.first?[2].string { answer = try JSONDecoder().decode(RealmReply.self, from: Data(text.utf8)) }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertEqual(answer?.unknownKeeper, true)
        print("REALM a stranger's here was answered: the realm doesn't know them")

        // The server stamps each publication by its own clock, and says
        // its clock with each answer, so a countdown can be made true.
        let (stamps, date) = try await transport.queryDated("SELECT version, at_micros FROM stamp", token: stranger.token)
        let at = try XCTUnwrap(stamps.first?[1].number) / 1_000_000
        let now = try XCTUnwrap(date, "The server dates its answers").timeIntervalSince1970
        XCTAssertLessThan(abs(now - Date().timeIntervalSince1970), 120, "The server's clock, near ours")
        XCTAssertTrue((0...60).contains(now.rounded(.down) - at.rounded(.down)), "Stamped lately: \(now - at) s ago")
        print("REALM the status is stamped by the server's clock, \(Int(now - at)) s ago")

        // A keeper offers a steward trade and is told the realm's answer.
        let stewarded = try XCTUnwrap(world.houses.first { !$0.isPlayer && !$0.isEliminated }?.id)
        await MainActor.run { a.send(.offerTrade(Trade(give: .timber, 30, for: .stone, 10), to: stewarded, words: nil)) }
        try await until("the realm's answer to the trade") {
            earA.events.contains { event in
                if case .answered(let events) = event { return events.contains { if case .tradeAnswered = $0 { return true } else { return false } } }
                return false
            }
        }
        print("REALM a keeper offered a steward trade and heard its answer")

        let watch = world.watch
        await MainActor.run {
            a.setReady(true)
            b.setReady(true)
        }
        try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        print("REALM two keepers met, gave orders and turned the watch on SpacetimeDB")

        // The client reading only every two minutes heard each change
        // pushed: its status moved with the realm's, long before it would
        // have read it.
        try await until("the pushed word", timeout: 20) { c.pushes > 0 && (earC.lastStatus?.watch ?? 0) > watch }
        await MainActor.run { c.close() }
        print("REALM SpacetimeDB pushed the realm's changes to a client over its WebSocket")

        // Keeper to keeper: Ama's envoy carries an offer of trade to Bel,
        // who takes it, and the stores change hands.
        let houseB = try await MainActor.run { try XCTUnwrap(earB.keeper?.house) }
        await MainActor.run { a.send(.offerTrade(Trade(give: .grain, 10, for: .stone, 10), to: houseB, words: nil)) }
        try await until("Ama's envoy at Bel's gate") {
            earB.world?.envoys.contains { $0.from == houseA && $0.to == houseB && $0.proposal == .trade } == true
        }
        let envoy = try await MainActor.run {
            try XCTUnwrap(earB.world?.envoys.first { $0.from == houseA && $0.to == houseB && $0.proposal == .trade })
        }
        let grain = try await MainActor.run { try XCTUnwrap(earB.world?.houses[houseB].stock.grain) }
        await MainActor.run { b.send(.answer(envoy: envoy.id, accept: true)) }
        try await until("the trade kept, as Bel's stores show it") { (earB.world?.houses[houseB].stock.grain ?? 0) >= grain + 10 }
        print("REALM one keeper's envoy carried a trade to another, who took it, and the stores changed hands")

        // Then war between them, as both see it.
        await MainActor.run { a.send(.declareWar(on: houseB)) }
        try await until("war, as both keepers see it") {
            earA.world?.isAtWar(houseA, houseB) == true && earB.world?.isAtWar(houseA, houseB) == true
        }
        print("REALM one keeper declared war on another, and both saw it")

        // Ama marches on Bel's seat, watch by watch as both keepers turn
        // them, and strikes at it.
        let realm: GameState = await steward.state.world
        let belsSeat: Hold = try XCTUnwrap(realm.seat(of: houseB))
        let target: Hex = belsSeat.position
        let soldiers: [NullmereCore.Unit] = realm.units(of: houseA).filter { $0.kind.isMilitary }
        let marcher: NullmereCore.Unit = try XCTUnwrap(soldiers.min { $0.position.distance(to: target) < $1.position.distance(to: target) })
        let free: [Hex] = target.neighbors.filter { hex in
            realm.map[hex]?.terrain.isPassable == true && realm.unit(at: hex) == nil && realm.hold(at: hex) == nil
        }
        let gate: Hex = try XCTUnwrap(free.min { $0.distance(to: marcher.position) < $1.distance(to: marcher.position) })
        await MainActor.run { a.send(.move(unit: marcher.id, to: gate)) }
        var watches = 0
        while try await MainActor.run(body: { try XCTUnwrap(earA.world?.unit(marcher.id), "Ama's company lives").position != gate }) {
            guard watches < 30 else { return XCTFail("Ama's company never reached Bel's gate") }
            let now = try await MainActor.run { try XCTUnwrap(earA.world?.watch) }
            await MainActor.run {
                a.setReady(true)
                b.setReady(true)
            }
            try await until("watch \(now + 1)") { (earA.world?.watch ?? 0) > now && (earB.world?.watch ?? 0) > now }
            watches += 1
            // Its way blocked a while, it is sent on again.
            if await MainActor.run(body: { earA.world?.unit(marcher.id)?.destination == nil && earA.world?.unit(marcher.id)?.position != gate }) {
                await MainActor.run { a.send(.move(unit: marcher.id, to: gate)) }
            }
        }
        await MainActor.run { a.send(.attack(unit: marcher.id, target: belsSeat.position)) }
        try await until("the blow, as Ama is told it") {
            earA.events.contains { event in
                if case .answered(let events) = event { return events.contains { if case .battle = $0 { return true } else { return false } } }
                return false
            }
        }
        try await until("the blow, as Bel hears it") {
            earB.events.contains { event in
                if case .heard(let events) = event {
                    return events.contains { if case .battle(let battle) = $0 { return battle.defenderOwner == houseB } else { return false } }
                }
                return false
            }
        }
        print("REALM one keeper marched on another's seat over \(watches) watches and struck it, and both saw the blow")
    }
}
