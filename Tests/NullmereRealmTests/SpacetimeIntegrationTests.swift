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
                                                 .strings([]), .strings([]), .strings([]), .integers([]), .strings([]), .string("stranger"),
                                                 .strings([]), .strings([]), .strings([])],
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
                                                 .strings([]), .strings([]), .integers([]), .strings([]), .string("a stranger's hold"),
                                                 .strings([]), .strings([]), .strings([])],
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
        for table in ["world", "world_part", "request", "keeper_view", "view_part", "reply"] {
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

        // Ama raises a banner and invites Bel, who joins it: one alliance of
        // two, as both keepers see it. Bel leaves it again, as war between
        // them would need.
        let banner = "The Grey Hand " + suffix
        await MainActor.run { a.send(.foundAlliance(name: banner)) }
        try await until("Ama's banner raised") { earA.world?.alliance(of: houseA)?.name == banner }
        await MainActor.run { a.send(.inviteToAlliance(house: houseB)) }
        try await until("the invitation at Bel's gate") {
            earB.world?.alliancesStanding.contains { $0.name == banner && $0.invited.contains(houseB) } == true
        }
        let allianceID = try await MainActor.run { try XCTUnwrap(earB.world?.alliancesStanding.first { $0.name == banner }?.id) }
        await MainActor.run { b.send(.answerInvitation(alliance: allianceID, accept: true)) }
        try await until("one alliance of two, as both keepers see it") {
            earA.world?.areAllied(houseA, houseB) == true && earB.world?.areAllied(houseA, houseB) == true
        }
        print("REALM one keeper raised a banner and invited another, who joined it, and both saw the alliance")

        // Words between them: to the whole realm, and to their alliance alone.
        await MainActor.run { a.send(.say(words: "Well met, neighbour", toAlliance: false)) }
        await MainActor.run { b.send(.say(words: "Our banner holds", toAlliance: true)) }
        try await until("each keeper's words heard by the other") {
            earB.world?.words(heardBy: houseB).contains { $0.from == houseA && $0.text == "Well met, neighbour" && $0.alliance == nil } == true
                && earA.world?.words(heardBy: houseA).contains { $0.from == houseB && $0.text == "Our banner holds" && $0.alliance == allianceID } == true
        }
        print("REALM two keepers spoke across the realm and within their alliance, and each heard the other")
        await MainActor.run { b.send(.leaveAlliance) }
        try await until("Bel gone from the alliance, as both see it") {
            earA.world?.areAllied(houseA, houseB) == false && earB.world?.alliance(of: houseB) == nil
        }

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
        // Come to Bel's gate: beside the seat, wherever another company stands.
        func away() async throws -> Int {
            try await MainActor.run { try XCTUnwrap(earA.world?.unit(marcher.id), "Ama's company lives").position.distance(to: target) }
        }
        var watches = 0
        while try await away() > 1 {
            guard watches < 90 else { return XCTFail("Ama's company never came to Bel's gate: \(try await away()) away") }
            let now = try await MainActor.run { try XCTUnwrap(earA.world?.watch) }
            await MainActor.run {
                a.setReady(true)
                b.setReady(true)
            }
            try await until("watch \(now + 1)") { (earA.world?.watch ?? 0) > now && (earB.world?.watch ?? 0) > now }
            watches += 1
            if watches % 10 == 0 { print("REALM-MARCH watch \(watches): \(try await away()) from Bel's seat") }
            // Its way closed, it is sent on again, to whichever side of the seat is free.
            let stopped = await MainActor.run { earA.world?.unit(marcher.id)?.destination == nil }
            let distance = try await away()
            if stopped && distance > 1 {
                let world = try await MainActor.run { try XCTUnwrap(earA.world) }
                let at = try XCTUnwrap(world.unit(marcher.id)).position
                let sides = target.neighbors.filter { world.map[$0]?.terrain.isPassable == true && world.unit(at: $0) == nil }
                let side = sides.min { $0.distance(to: at) < $1.distance(to: at) } ?? gate
                await MainActor.run { a.send(.move(unit: marcher.id, to: side)) }
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

    /// Two realms and the Frontier between them, each its own database on
    /// one server with its own steward, the stewards reading each other's
    /// status as any keeper may: keepers cross from home by an order, are
    /// seated at the Frontier for their realms' kingdoms and at war, keep
    /// its season to its end, and are told home of it, once. CI sets
    /// NULLMERE_STDB_FRONTIER to the two realms' and the Frontier's
    /// addresses, between commas, each with the module published.
    func testKeepersOfTwoRealmsMeetAtTheFrontier() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let set = environment["NULLMERE_STDB_FRONTIER"], let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB_FRONTIER and NULLMERE_STDB_TOKEN to test the Frontier against a SpacetimeDB server")
        }
        let addresses = set.split(separator: ",").map(String.init)
        let transports = addresses.compactMap { URL(string: $0).flatMap { SpacetimeHTTP(address: $0) } }
        guard transports.count == 3 else { return XCTFail("Three addresses: two realms, then the Frontier") }
        let (west, east, lost) = (transports[0], transports[1], transports[2])
        // A clock of the test's own, so a season of watches passes in moments.
        var now = Date().timeIntervalSince1970
        let suffix = String(KeeperIdentity.make().filter(\.isLetter).prefix(5)).lowercased()
        let home = try await RealmSteward(transport: west, token: token, name: "The Nullmere", seed: "west " + suffix, seats: 4,
                                          watchLength: 600, now: now)
        let away = try await RealmSteward(transport: east, token: token, name: "The Farmere", seed: "east " + suffix, seats: 4,
                                          watchLength: 600, now: now)
        let frontier = try await RealmSteward(transport: lost, token: token, name: "The Lost Shore", seed: "lost " + suffix, seats: 4,
                                              watchLength: 600, frontier: true, now: now)
        await home.border(lost, at: addresses[2])
        await away.border(lost, at: addresses[2])
        await frontier.border(west, at: addresses[0])
        await frontier.border(east, at: addresses[1])
        func round(_ seconds: Double = 1) async throws {
            now += seconds
            try await frontier.step(now: now)
            try await home.step(now: now)
            try await away.step(now: now)
        }
        let ilsen = try await west.createIdentity(), orla = try await east.createIdentity()
        try await west.call("arrive", [.string("i1-" + suffix), .string("Ilsen" + suffix)], token: ilsen.token)
        try await east.call("arrive", [.string("o1-" + suffix), .string("Orla" + suffix)], token: orla.token)
        try await round()
        let heard = await home.state.frontierNews
        XCTAssertEqual(heard?.address, addresses[2], "Where to cross to, read from the Frontier's own status")

        let cross = String(decoding: try JSONEncoder().encode(Command.crossToFrontier), as: UTF8.self)
        try await west.call("order", [.string("i2-" + suffix), .string(cross)], token: ilsen.token)
        try await east.call("order", [.string("o2-" + suffix), .string(cross)], token: orla.token)
        try await round(RealmSteward.bordersEvery)
        try await round(RealmSteward.bordersEvery)
        let admitted = await frontier.state.frontier?.admitted.keys.sorted()
        XCTAssertEqual(admitted, [ilsen.identity, orla.identity].sorted(), "Each realm's crossing, read from its status")

        // The same identities, at the Frontier's own database.
        try await lost.call("arrive", [.string("i3-" + suffix), .string("Ilsen" + suffix)], token: ilsen.token)
        try await lost.call("arrive", [.string("o3-" + suffix), .string("Orla" + suffix)], token: orla.token)
        try await round()
        let seated = await (frontier.state.keeper(ilsen.identity)?.house, frontier.state.keeper(orla.identity)?.house)
        let mine = try XCTUnwrap(seated.0), theirs = try XCTUnwrap(seated.1)
        let kingdoms = await (frontier.state.frontier?.kingdom(of: mine), frontier.state.frontier?.kingdom(of: theirs))
        XCTAssertEqual(kingdoms.0, "The Nullmere")
        XCTAssertEqual(kingdoms.1, "The Farmere")
        let atWar = await frontier.state.world.isAtWar(mine, theirs)
        XCTAssertTrue(atWar, "Kingdoms meet at war")
        let shown = try await lost.query("SELECT version, status FROM status", token: ilsen.token)
        let status = try JSONDecoder().decode(RealmStatus.self, from: Data(try XCTUnwrap(shown.first?[1].string).utf8))
        XCTAssertEqual(Set(status.frontier?.standings.map(\.realm) ?? []), ["The Nullmere", "The Farmere"], "Told to any who read it")
        print("REALM keepers of two realms crossed to the Frontier and were seated there for their kingdoms, at war")

        // They keep its season to its end.
        var watches = 0
        while await frontier.state.frontier?.season == 1, watches < FrontierState.lasts + 4 {
            watches += 1
            try await lost.call("here", [.string("ih\(watches)-" + suffix)], token: ilsen.token)
            try await lost.call("here", [.string("oh\(watches)-" + suffix)], token: orla.token)
            try await round(601)
        }
        let season = await frontier.state.frontier?.season
        XCTAssertEqual(season, 2, "The season ran its watches")
        try await round(RealmSteward.bordersEvery)
        let told = await home.state.frontierNews?.last?.season
        XCTAssertEqual(told, 1)
        let crossing = await home.state.keeper(ilsen.identity)?.crossing
        XCTAssertNil(crossing, "Home again")
        let lines = await home.state.world.chronicle.filter { $0.text.contains("comes home from the Frontier's first season") }.count
        XCTAssertEqual(lines, 1)
        try await round(RealmSteward.bordersEvery)
        let again = await home.state.world.chronicle.filter { $0.text.contains("comes home from the Frontier's first season") }.count
        XCTAssertEqual(again, 1, "Told once")
        print("REALM the Frontier's season ran \(watches) watches and was told home, once")
    }

    /// The Frontier as keepers play it, through their own clients, the
    /// three stewards on their own clocks: as `FrontierPlayThroughTests`
    /// plays it over databases held in memory. Three databases of its own,
    /// fresh, since a steward takes up the world a database keeps.
    @MainActor
    func testKeepersCrossToTheFrontierThroughTheirClients() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let set = environment["NULLMERE_STDB_FRONTIER_PLAY"], let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB_FRONTIER_PLAY and NULLMERE_STDB_TOKEN to play the Frontier through keepers' clients")
        }
        let addresses = set.split(separator: ",").map(String.init)
        let transports = addresses.compactMap { URL(string: $0).flatMap { SpacetimeHTTP(address: $0) } }
        guard transports.count == 3 else { return XCTFail("Three addresses: two realms, then the Frontier") }
        let databases = FrontierPlayThrough.Databases(west: transports[0], east: transports[1], lost: transports[2], lostAddress: addresses[2],
                                                      westAddress: addresses[0], eastAddress: addresses[1])
        try await FrontierPlayThrough.play(databases, token: token)
    }
}
