import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereCore
import NullmereModels
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
                                                 .strings([]), .strings([]), .strings([]), .strings([])],
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
                                                 .strings([]), .strings([]), .strings([]), .strings([])],
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
        Task { await steward.run() }
        // Stopped, not cancelled: its round under way finishes, so no
        // request in flight is cancelled.
        defer { Task { await steward.stop() } }

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
        // The realm itself keeps the compact: a client that says nothing of
        // it (a build from before, or one changed) is not taken in, and
        // those that came in are recorded with the edition they accepted.
        let (d, earD) = await MainActor.run { () -> (NetworkRealmLink, Listener) in
            let d = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 0.2)
            d.compactAccepted = nil
            let earD = Listener()
            earD.listen(to: d)
            d.connect()
            return (d, earD)
        }
        try await until("the realm's status for the third") { earD.hasStatus }
        await MainActor.run { d.arrive(name: "Cyn" + suffix) }
        try await until("the realm to refuse a keeper who has not accepted the compact") {
            earD.refusals.contains(RealmError.compactUnaccepted.description)
        }
        let dIn = await MainActor.run { earD.keeper }
        XCTAssertNil(dIn, "Not taken in")
        await MainActor.run { d.close() }
        let recorded = await MainActor.run { (earA.keeper?.compact, earB.keeper?.compact) }
        XCTAssertEqual(recorded.0, Compact.edition)
        XCTAssertEqual(recorded.1, Compact.edition)
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

        // Allied, they break a lair of the wilds with a rally, each sending
        // companies from their own client.
        let scene = RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60)
        try await scene.helpEachOther(ama: houseA, bel: houseB)
        print("REALM two allied keepers studied together, one helped the other's work and sent a gift, each from their own client")
        try await scene.breakALair(ama: houseA, bel: houseB)
        try await scene.writeAndTrade(ama: houseA, bel: houseB)
        print("REALM two keepers wrote each other letters only they read, and one bought of her pedlar and kept it through the watch")
        try await scene.foretellAHappening(ama: houseA, bel: houseB)
        print("REALM two keepers' calendars foretold the same happening, and both saw it begin on its watch")
        try await scene.laboursOfTheWatch(ama: houseA, bel: houseB)
        try await scene.joinTheGreatMuster(ama: houseA, bel: houseB)
        print("REALM one keeper mustered in the Great Muster from his own client; both clients saw him foremost on its standing")
        try await scene.openTheInnsChests(ama: houseA, bel: houseB)
        try await scene.walkTheMirror(ama: houseA, bel: houseB)
        try await scene.heedTheBeacon(ama: houseA, bel: houseB)
        try await scene.breakTheCalm(ama: houseA, bel: houseB)
        try await scene.gatherAndBringItHome(ama: houseA, bel: houseB)
        print("REALM a keeper gathered from a field both clients saw fall; the other was refused it while taken; All home brought the gatherers back")
        try await scene.hideAHouse(ama: houseA, bel: houseB)
        try await scene.makeTheWordsSafe(ama: houseA, bel: houseB)
        print("REALM two keepers each raised a work or a muster for their watch's labour, and each was told only of their own")
        try await scene.teachTheLakeToLie(ama: houseA, bel: houseB)
        print("REALM one keeper taught the lake to lie, and the other saw her false company mirrored at the Still Hour")
        try await scene.keepAVigil(ama: houseA, bel: houseB)
        print("REALM one keeper kept a vigil for her fallen; the other read it, honoured it and was held to its truce, as both clients saw")
        try await scene.markTheGround(ama: houseA, bel: houseB)
        print("REALM the alliance's leader marked ground from her own client and her ally saw it where it lay; his own mark was refused; she lifted it from both")
        try await scene.upTheSpine(ama: houseA, bel: houseB)
        try await scene.learnATalent(ama: houseA, bel: houseB)
        try await scene.studyAndScout(ama: houseA, bel: houseB)
        try await scene.healTheWounded(ama: houseA, bel: houseB)
        print("REALM one keeper paid for her wounded's healing from her own client and saw them rise whole; the other was refused her beds")
        print("REALM one keeper began a study her ally saw under way, and scouted his seat: she had the report, he heard it seen")
        print("REALM one keeper's commander learned a talent from her own client; the other's order on it was refused by the realm")
        print("REALM two keepers sent a line and a commander up the Spine from their own clients, each seeing only their own stars")
        print("REALM two allied keepers rallied on a lair from their own clients, broke it, and both were told of it and their shares")
        try await RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60).raiseAStandardTogether(ama: houseA, bel: houseB)
        print("REALM one keeper began a standard and her ally lent a hand from his own client; both saw it rise a watch sooner and its land become the alliance's")
        try await RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60).raiseTheAlliancesWorks(ama: houseA, bel: houseB)
        print("REALM an alliance's leader began its hall and storehouse from her own client, and her ally saw both rise in his")
        let gatekeeper = try await RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60).keepAnAllysGates(ama: houseA, bel: houseB)
        print("REALM one keeper sent a company to keep his ally's seat from his own client; both saw it keep her gates, her client its banner and sentries there")
        await MainActor.run { b.send(.leaveAlliance) }
        try await until("Bel gone from the alliance, as both see it") {
            earA.world?.areAllied(houseA, houseB) == false && earB.world?.alliance(of: houseB) == nil
        }
        // No longer allies, Bel's company leaves Ama's gates as the watch turns.
        let parted = try await MainActor.run { try XCTUnwrap(earA.world?.watch) }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the watch after parting") { (earB.world?.watch ?? 0) > parted }
        try await until("Bel's spears gone from Ama's gates") {
            if case .reinforce? = earB.world?.unit(gatekeeper)?.errand { return false }
            return earB.world?.unit(gatekeeper) != nil
        }
        // Its part played, the company is taken off the field the battle below is staged on.
        await RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60).dismiss(gatekeeper)

        // Then war between them, as both see it.
        await MainActor.run { a.send(.declareWar(on: houseB)) }
        try await until("war, as both keepers see it") {
            earA.world?.isAtWar(houseA, houseB) == true && earB.world?.isAtWar(houseA, houseB) == true
        }
        print("REALM one keeper declared war on another, and both saw it")
        try await RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60).fightAGreatBattle(ama: houseA, bel: houseB)
        print("REALM a host of 200,000 met a garrison of 200,000 before a seat, each ordered from its own client, all 400,000 in one field both saw fought out and told alike")

        // Each in an alliance of their own, they fight over the Drowned
        // Crown on the bare ford, each from their own client.
        try await RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60).contestTheCrown(ama: houseA, bel: houseB)
        print("REALM two alliances fought over the Drowned Crown from their own clients: taken, struck down, taken again, and given as the water came back")
        let scene2 = RallyScene(steward: steward, a: a, earA: earA, b: b, earB: earB, timeout: 60)
        try await scene2.waitInLine(ama: houseA, bel: houseB) { NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 0.2) }
        print("REALM a seat freed went to the keeper first in line, as both the line's keepers saw it")
        try await scene2.sitTheLyceum(ama: houseA, bel: houseB)
        try await scene2.takeAHolySite(ama: houseA, bel: houseB)
        print("REALM one keeper's spears took a holy site from her own client; both clients saw it hers and the other heard it taken")
        print("REALM two keepers sat the Lyceum in its lit hall from their own clients, answered blind, and were judged and paid alike")

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

        // Ama's client sees her hold in the world's 3D models as the realm
        // keeps it: a sawpit ordered raised rises in its scaffold, the
        // sawyers' rig at work beside it, every piece within its budget.
        let seatID = try XCTUnwrap(world.holds.first { $0.owner == houseA && $0.isSeat }?.id)
        let relief = Relief(map: world.map)
        await MainActor.run { a.send(.build(hold: seatID, kind: .sawpit)) }
        try await until("the sawpit to be begun") { earA.world?.hold(seatID)?.project?.kind == .sawpit }
        let rising = try await MainActor.run { try XCTUnwrap(earA.world?.hold(seatID)) }
        let keys = HoldLayout.pieces(hold: rising, relief: relief, progress: 0.4).map(\.key)
        XCTAssertTrue(keys.contains(.work(.sawpit, level: try XCTUnwrap(rising.project?.targetLevel))), "\(keys)")
        XCTAssertTrue(keys.contains(.scaffold))
        XCTAssertTrue(keys.contains(.raising(.sawpit)), "The sawyers' rig at work beside it")
        for key in keys {
            XCTAssertTrue((1...key.budget).contains(Library.model(key).mesh.triangleCount), "\(key) drawn within its budget")
        }
        print("REALM a keeper's client saw its sawpit rise in its 3D models, its rig at work, from the realm on SpacetimeDB")

        // Last, its turned watch and its company's id moving none of the scenes before.
        try await scene2.setTheWoodAlight(ama: houseA, bel: houseB)
        print("REALM one keeper set the blackwood alight from her own client and both clients saw it burn; the other's order on her company was refused; as the watch turned both saw the fire as the realm left it")
        // And after it, for it parts the two Houses' sight.
        try await scene2.marchInTheDark(ama: houseA, bel: houseB)
        print("REALM one keeper's spears doused their torches from her own client: the other's client lost them in the dark while hers knew they marched dark; come by his seat, his client saw them, torchless; lit again, both saw it")
        // With their sight parted, each House's seeking its own.
        try await scene2.seekAHamlet(ama: houseA, bel: houseB)
        print("REALM one keeper's Lanterns sought out a hamlet from her own client, which was told of its folk's gift while the other's was told nothing; sought once, they were refused it again, and the other's Lanterns sought it for his own House, hers told nothing of it")
        // Last, for it sets the two Houses at war.
        try await scene2.lieInWait(ama: houseA, bel: houseB)
        print("REALM one keeper's spears lay in wait in the blackwood from her own client, which knew it while the other's never did; his order on them refused, his company come beside the wood was sprung upon as the watch turned, and both clients saw the blow")
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
        try await west.call("arrive", [.string("i1-" + suffix), .string(ArrivalPayload(name: "Ilsen" + suffix, compact: Compact.edition).encoded)], token: ilsen.token)
        try await east.call("arrive", [.string("o1-" + suffix), .string(ArrivalPayload(name: "Orla" + suffix, compact: Compact.edition).encoded)], token: orla.token)
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
        try await lost.call("arrive", [.string("i3-" + suffix), .string(ArrivalPayload(name: "Ilsen" + suffix, compact: Compact.edition).encoded)], token: ilsen.token)
        try await lost.call("arrive", [.string("o3-" + suffix), .string(ArrivalPayload(name: "Orla" + suffix, compact: Compact.edition).encoded)], token: orla.token)
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
        try await FrontierPlayThrough.playBounded(databases, token: token)
    }

    /// A keeper's phone beside their Mac on a real server, each by its own
    /// identity and its own connections: the Mac offers a link by the
    /// code's digest, the phone brings the code and comes in as the keeper,
    /// reading their view; an order from either is seen on the other, and
    /// how long each took is said; the phone gone and back by its own key
    /// sees what was done while it was away; one device leaving leaves the
    /// keeper there while the other is; and let go from the Mac, the phone
    /// is told the realm links it to no one. No stranger reads who speaks
    /// for whom. A database of its own, fresh: CI sets
    /// NULLMERE_STDB_COMPANION to it.
    @MainActor
    func testAKeepersPhonePlaysBesideTheirMacThroughSpacetime() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let text = environment["NULLMERE_STDB_COMPANION"], let url = URL(string: text), let transport = SpacetimeHTTP(address: url),
              let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB_COMPANION and NULLMERE_STDB_TOKEN to play a keeper's phone beside their Mac on a SpacetimeDB server")
        }
        func own() -> any SpacetimeTransport { SpacetimeHTTP(address: url, session: URLSession(configuration: .ephemeral))! }
        let steward = try await takeUp(transport, token, seats: 4, watchLength: 600)
        Task { await steward.run() }
        defer { Task { await steward.stop() } }
        func device(_ store: MemoryStore) -> (NetworkRealmLink, Listener) {
            let link = NetworkRealmLink(transport: own(), credentials: store, pollInterval: 0.5)
            let ear = Listener()
            ear.listen(to: link)
            link.connect()
            return (link, ear)
        }
        func waitedFor(_ what: String, timeout: Double = 60, _ condition: @MainActor () -> Bool) async throws -> Double {
            let began = Date()
            while !condition() {
                if Date().timeIntervalSince(began) > timeout { throw SpacetimeError("Timed out waiting for \(what)") }
                try await Task.sleep(nanoseconds: 20_000_000)
            }
            return Date().timeIntervalSince(began)
        }
        let macStore = MemoryStore(), phoneStore = MemoryStore()
        let (mac, macEar) = device(macStore)
        _ = try await waitedFor("the realm's status on the Mac") { macEar.hasStatus }
        let name = "Ama" + String(KeeperIdentity.make().filter(\.isLetter).prefix(6))
        mac.arrive(name: name)
        _ = try await waitedFor("the keeper to arrive on the Mac") { macEar.keeper != nil }
        let keeper = try XCTUnwrap(macEar.keeper)
        let house = try XCTUnwrap(keeper.house)

        // The Mac offers a link by the code's digest alone.
        let code = LinkCode.make()
        let offered = Answered<Result<Int, LinkRefusal>>()
        mac.offerLink(code: code) { offered.value = $0 }
        _ = try await waitedFor("the realm to take the offer") { offered.value != nil }
        XCTAssertEqual(try offered.value?.get(), 0)

        // The phone, by its own identity, brings the code.
        let (phone, phoneEar) = device(phoneStore)
        _ = try await waitedFor("the realm's status on the phone") { phoneEar.hasStatus }
        phone.takeLink(code: LinkCode.shown(code))
        let linking = try await waitedFor("the phone to come in as the keeper") { phoneEar.keeper != nil }
        XCTAssertEqual(phoneEar.keeper?.id, keeper.id, "The phone speaks for the keeper")
        XCTAssertEqual(phoneEar.keeper?.name, name)
        XCTAssertEqual(phoneEar.world?.houses[house].stock, macEar.world?.houses[house].stock, "and is shown their House as their Mac is")
        let phoneIdentity = try XCTUnwrap(phone.credentials?.identity)
        XCTAssertNotEqual(phoneIdentity, keeper.id, "Its own identity: the Mac's key never leaves the Mac")
        let linked = try await transport.query("SELECT identity, keeper FROM companion", token: token)
        XCTAssertEqual(linked.map { $0.compactMap(\.string) }, [[phoneIdentity, keeper.id]])
        let stranger = try await transport.createIdentity()
        let peeked = (try? await transport.query("SELECT * FROM companion", token: stranger.token)) ?? []
        XCTAssertTrue(peeked.isEmpty, "No stranger reads who speaks for whom")
        print(String(format: "REALM a keeper's phone took the link their Mac offered and came in as them in %.2f s", linking))
        // Their Mac sees the phone in the realm with them.
        let phoneSeen = try await waitedFor("the Mac to see its phone in the realm") { macEar.toldKeeper?.companionsHere == 1 }
        print(String(format: "REALM the keeper's Mac saw their phone in the realm with them %.2f s after it came in", phoneSeen))

        // An order from the phone, seen on the Mac; one from the Mac, on the phone.
        let world = try XCTUnwrap(phoneEar.world)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        phone.send(.fortify(unit: spear.id))
        let toMac = try await waitedFor("the phone's order seen on the Mac") { macEar.world?.unit(spear.id)?.fortified == true }
        let stores = phoneEar.world?.houses[house].stock
        mac.send(.barter(give: .timber, take: .stone, amount: 3))
        let toPhone = try await waitedFor("the Mac's order seen on the phone") { phoneEar.world?.houses[house].stock != stores }
        print(String(format: "REALM an order given on the phone was seen on the Mac in %.2f s, one on the Mac on the phone in %.2f s",
                     toMac, toPhone))

        // The phone gone and back by its own key, kept: what was done while
        // it was away is what it sees.
        phone.close()
        let before = macEar.world?.houses[house].stock
        mac.send(.barter(give: .timber, take: .stone, amount: 3))
        _ = try await waitedFor("the Mac's order while the phone was away") { macEar.world?.houses[house].stock != before }
        let (back, backEar) = device(phoneStore)
        _ = try await waitedFor("the phone's status again") { backEar.hasStatus }
        let returning = Date()
        back.accompany()
        _ = try await waitedFor("the phone in again as the keeper") { backEar.keeper?.id == keeper.id }
        XCTAssertEqual(back.credentials?.identity, phoneIdentity, "By its own key, kept")
        XCTAssertEqual(backEar.world?.houses[house].stock, macEar.world?.houses[house].stock, "Caught up with what was done meanwhile")
        print(String(format: "REALM the phone, back, came in again and was shown what was done while it was away in %.2f s",
                     Date().timeIntervalSince(returning)))

        // Leaving on the phone leaves the keeper there, on their Mac.
        back.leave()
        let deadline = Date().addingTimeInterval(30)
        while Date() < deadline {
            let waiting = try await transport.query("SELECT nonce FROM request WHERE keeper = \(sqlString(phoneIdentity))", token: token)
            if waiting.isEmpty { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let online = await steward.state.keeper(keeper.id)?.isOnline
        XCTAssertEqual(online, true, "Still there, on their Mac")
        // And the Mac sees the phone gone, and when it was last in the realm.
        let phoneGone = try await waitedFor("the Mac to see its phone gone") {
            macEar.toldKeeper?.companionsHere == nil && macEar.toldKeeper?.companionLastHeard != nil
        }
        print(String(format: "REALM the keeper's Mac saw their phone leave the realm, and when it last was, %.2f s after it left", phoneGone))

        // Let go from the Mac: the phone is told the realm links it to no one.
        let unlinked = Answered<String?>()
        mac.unlinkDevices { unlinked.value = .some($0) }
        _ = try await waitedFor("the devices let go") { unlinked.value != nil }
        XCTAssertEqual(unlinked.value, .some(nil))
        let left = try await transport.query("SELECT identity, keeper FROM companion", token: token)
        XCTAssertTrue(left.isEmpty)
        let (gone, goneEar) = device(phoneStore)
        _ = try await waitedFor("the phone's status once let go") { goneEar.hasStatus }
        gone.accompany()
        _ = try await waitedFor("the phone told it speaks for no one") { goneEar.refusals.contains(RealmError.unknownKeeper.description) }
        print("REALM a keeper's phone let go from their Mac was told the realm links it to no one")
        gone.close()
        mac.leave()
    }

    /// Every seat of a realm taken at once, each by a keeper's own client,
    /// on a real server: all seated and shown the world, all ready and every
    /// client seeing the watch turn, one keeper heard by all. A database of
    /// its own, fresh. CI sets NULLMERE_STDB_CROWD to it and plays ninety-six
    /// seats; NULLMERE_STDB_CROWD_SEATS asks for more, up to the widest
    /// realm's thousand and twenty-four.
    @MainActor
    func testAFullRealmOfKeepersPlaysAtOnce() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let text = environment["NULLMERE_STDB_CROWD"], let url = URL(string: text), SpacetimeHTTP(address: url) != nil,
              let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB_CROWD and NULLMERE_STDB_TOKEN to play a full realm of keepers on a SpacetimeDB server")
        }
        // The steward and every keeper's Mac each reach the server by their
        // own connections, as they do in the world, not queued in one.
        func own() -> any SpacetimeTransport { SpacetimeHTTP(address: url, session: URLSession(configuration: .ephemeral))! }
        let seats = min(Int(environment["NULLMERE_STDB_CROWD_SEATS"] ?? "") ?? 96, WorldGenerator.mostHouses)
        let timings = try await CrowdPlayThrough.play(own(), token: token, seats: seats, watchLength: 20, newcomerWait: 2...4,
                                                      timeout: 600, clients: own, log: TimedTransport.Log())
        print("REALM \(seats) keepers' clients took every seat of a realm of \(seats) at once on SpacetimeDB: \(timings)")
    }

    /// A realm whose every world is too big for one call of a publication,
    /// as a realm of hundreds of keepers' is: it goes ahead of the call that
    /// publishes it, and keepers' clients, each by its own connections, are
    /// seated, shown it, see the watch turn and hear each other as ever;
    /// the world as the server keeps it reads whole, every keeper seated in
    /// it, and nothing is left aside.
    func testAWorldSentAheadIsPublishedWhole() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let text = environment["NULLMERE_STDB_AHEAD"], let url = URL(string: text), let transport = SpacetimeHTTP(address: url),
              let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB_AHEAD and NULLMERE_STDB_TOKEN to send a realm's world ahead on a SpacetimeDB server")
        }
        func own() -> any SpacetimeTransport { SpacetimeHTTP(address: url, session: URLSession(configuration: .ephemeral))! }
        let seats = 12
        let timings = try await CrowdPlayThrough.play(own(), token: token, seats: seats, watchLength: 6, newcomerWait: 0.5...1,
                                                      timeout: 240, budget: 16_000, clients: own)
        XCTAssertGreaterThan(timings.callsSentAhead, 1, "The world sent ahead of the call that publishes it")
        let world = try RealmState(parts: try await RealmSteward.keptParts(transport, token: token))
        XCTAssertEqual(world.keepers.filter { $0.house != nil }.count, seats, "Every keeper seated in the world as kept")
        let aside = try await transport.query("SELECT name FROM world_ahead", token: token)
        XCTAssertTrue(aside.isEmpty, "Nothing left aside")
        print("REALM \(seats) keepers' clients on a realm whose world goes ahead of its publications: \(timings)")
    }

    /// The module's own rules for the world sent ahead, on a database of
    /// their own, as `ModuleRulesTests` holds the fake to them: none of the
    /// world until the call that publishes it names it; one named that was
    /// never sent ahead, or was sent ahead of another publication, and
    /// nothing of it is kept; those it doesn't name let go with it, and
    /// those sent ahead of a publication that never came let go by the next
    /// sent ahead of another; none sent ahead but by the steward, or ahead
    /// of a publication passed.
    func testTheWorldSentAheadIsNoneOfItUntilPublished() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let text = environment["NULLMERE_STDB_AHEAD_RULES"], let url = URL(string: text), let transport = SpacetimeHTTP(address: url),
              let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB_AHEAD_RULES and NULLMERE_STDB_TOKEN to hold a SpacetimeDB server to the world sent ahead")
        }
        let hold = ReducerArgument.string("a test's hold")
        func publish(_ version: UInt64, ahead: [String]) -> [ReducerArgument] {
            [.integer(version), .strings([]), .strings([]), .strings([]), .string("{}"), .strings([]), .strings([]), .strings([]),
             .integers([]), .strings([]), hold, .strings([]), .strings([]), .strings([]), .strings(ahead)]
        }
        func refusal(_ reducer: String, _ arguments: [ReducerArgument], token: String) async -> String? {
            do {
                try await transport.call(reducer, arguments, token: token)
                return nil
            } catch {
                return "\(error)"
            }
        }
        func aside() async throws -> [String] {
            try await transport.query("SELECT name FROM world_ahead", token: token).compactMap { $0.first?.string }.sorted()
        }
        let sent = await refusal("send_ahead", [.integer(5), .strings(["map.0", "spare"]), .strings(["{\"m\":1}", "{}"]), hold], token: token)
        XCTAssertNil(sent)
        let none = try await RealmSteward.keptParts(transport, token: token)
        XCTAssertEqual(none, [:], "None of the world until published")
        let sentAside = try await aside()
        XCTAssertEqual(sentAside, ["map.0", "spare"])

        let unsent = await refusal("publish", publish(5, ahead: ["map.0", "map.9"]), token: token)
        XCTAssertTrue(unsent?.contains("The part map.9 was never sent ahead.") == true, "\(unsent ?? "kept")")
        let other = await refusal("publish", publish(6, ahead: ["map.0"]), token: token)
        XCTAssertTrue(other?.contains("The part map.0 was sent ahead of another publication.") == true, "\(other ?? "kept")")
        let refused = try await RealmSteward.keptParts(transport, token: token)
        XCTAssertEqual(refused, [:], "Nothing of a publication refused kept")

        let published = await refusal("publish", publish(5, ahead: ["map.0"]), token: token)
        XCTAssertNil(published)
        let kept = try await RealmSteward.keptParts(transport, token: token)
        XCTAssertEqual(kept, ["map.0": "{\"m\":1}"], "The part named published, the one it didn't let go")
        let gone = try await aside()
        XCTAssertEqual(gone, [])

        for (version, name) in [(UInt64(7), "map.1"), (8, "map.2")] {
            let ahead = await refusal("send_ahead", [.integer(version), .strings([name]), .strings(["{}"]), hold], token: token)
            XCTAssertNil(ahead)
        }
        let left = try await aside()
        XCTAssertEqual(left, ["map.2"], "Those sent ahead of a publication that never came let go")
        let passed = await refusal("send_ahead", [.integer(5), .strings([]), .strings([]), hold], token: token)
        XCTAssertTrue(passed?.contains("Version 5 is not after 5.") == true, "\(passed ?? "kept")")
        let stranger = try await transport.createIdentity()
        let strange = await refusal("send_ahead", [.integer(9), .strings([]), .strings([]), .string("x")], token: stranger.token)
        XCTAssertTrue(strange?.contains("Only the steward writes the world.") == true, "\(strange ?? "kept")")
        print("REALM the world sent ahead is none of it until published")
    }
}
