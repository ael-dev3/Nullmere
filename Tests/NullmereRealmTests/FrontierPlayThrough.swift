import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// Two realms and the Frontier between them played through as keepers play
/// them: three stewards running on their own clocks, each with its realm's
/// database, reading each other's status; and two keepers' clients, the
/// shipped link each, at home in different realms. Each crosses by an
/// order, goes across to the Frontier's database with the same key, is
/// seated there for their realm's kingdom at war with the other's, with
/// their levy, keeps the Frontier's season to its end, and is told home.
/// Played over databases held in memory here, and over a real SpacetimeDB
/// server in CI (see `SpacetimeIntegrationTests`).
enum FrontierPlayThrough {
    struct Databases {
        var west: any SpacetimeTransport
        var east: any SpacetimeTransport
        var lost: any SpacetimeTransport
        /// The Frontier's address, as the home realms' stewards are given it.
        var lostAddress: String
        var westAddress: String
        var eastAddress: String
        /// Makes a keeper's key, once their client has it, known to every
        /// database on the server: nothing to do on a real server.
        var share: (SpacetimeCredentials) async -> Void = { _ in }
    }

    /// How long a watch lasts at the Frontier here: its season of
    /// twenty-four passes in under a minute.
    static let watch = 1.5

    @MainActor
    static func until(_ what: String, timeout: Double = 60, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !condition() {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    @MainActor
    static func play(_ db: Databases, token: String) async throws {
        let suffix = String(KeeperIdentity.make().filter(\.isLetter).prefix(5)).lowercased()
        let now = Date().timeIntervalSince1970
        let home = try await RealmSteward(transport: db.west, token: token, name: "The Nullmere", seed: "west " + suffix, seats: 4,
                                          watchLength: 600, now: now)
        let away = try await RealmSteward(transport: db.east, token: token, name: "The Farmere", seed: "east " + suffix, seats: 4,
                                          watchLength: 600, now: now)
        let frontier = try await RealmSteward(transport: db.lost, token: token, name: "The Lost Shore", seed: "lost " + suffix, seats: 4,
                                              watchLength: watch, frontier: true, now: now)
        await home.border(db.lost, at: db.lostAddress)
        await away.border(db.lost, at: db.lostAddress)
        await frontier.border(db.west, at: db.westAddress)
        await frontier.border(db.east, at: db.eastAddress)
        let running = [home, away, frontier].map { steward in Task { await steward.run() } }
        defer { running.forEach { $0.cancel() } }

        // Each keeper's client at home, as the app's is.
        let ilsenKey = MemoryStore(), orlaKey = MemoryStore()
        let ilsen = NetworkRealmLink(transport: db.west, credentials: ilsenKey, pollInterval: 0.2)
        let orla = NetworkRealmLink(transport: db.east, credentials: orlaKey, pollInterval: 0.2)
        let ilsenEar = Listener(), orlaEar = Listener()
        ilsenEar.listen(to: ilsen)
        orlaEar.listen(to: orla)
        ilsen.connect()
        orla.connect()
        try await until("their realms' status") { ilsenEar.hasStatus && orlaEar.hasStatus }
        ilsen.arrive(name: "Ilsen" + suffix)
        orla.arrive(name: "Orla" + suffix)
        try await until("both at home") { ilsenEar.keeper != nil && orlaEar.keeper != nil }
        for key in [ilsenKey, orlaKey] {
            let credentials = try JSONDecoder().decode(SpacetimeCredentials.self, from: Data(try XCTUnwrap(key.value).utf8))
            await db.share(credentials)
        }
        let ilsenID = try XCTUnwrap(ilsenEar.keeper?.id), orlaID = try XCTUnwrap(orlaEar.keeper?.id)
        try await until("word of the Frontier at home, read from its own status") {
            ilsenEar.lastStatus?.frontier?.open == true && orlaEar.lastStatus?.frontier?.address == db.lostAddress
        }
        XCTAssertEqual(ilsenEar.lastStatus?.frontier?.address, db.lostAddress)

        // They cross, each by an order to their own realm.
        func crossed(_ ear: Listener) -> Bool {
            ear.events.contains { event in
                guard case .answered(let events) = event else { return false }
                return events.contains { if case .frontier(.crossed) = $0 { return true } else { return false } }
            }
        }
        ilsen.send(.crossToFrontier)
        orla.send(.crossToFrontier)
        try await until("both crossings, as each realm answers") { crossed(ilsenEar) && crossed(orlaEar) }
        ilsen.leave()
        orla.leave()

        // Across, by the same keys, to the Frontier's own database.
        let ilsenThere = NetworkRealmLink(transport: db.lost, credentials: ilsenKey, pollInterval: 0.2)
        let orlaThere = NetworkRealmLink(transport: db.lost, credentials: orlaKey, pollInterval: 0.2)
        let ilsenSees = Listener(), orlaSees = Listener()
        ilsenSees.listen(to: ilsenThere)
        orlaSees.listen(to: orlaThere)
        ilsenThere.connect()
        orlaThere.connect()
        defer {
            ilsenThere.close()
            orlaThere.close()
        }
        try await until("the Frontier's status") { ilsenSees.hasStatus && orlaSees.hasStatus }
        // In, as the app goes in: again a little later while the Frontier
        // hasn't yet read the crossings from home.
        var asked = Date.distantPast
        try await until("both seated at the Frontier") {
            if ilsenSees.keeper != nil && orlaSees.keeper != nil { return true }
            if Date().timeIntervalSince(asked) > 1 {
                asked = Date()
                if ilsenSees.keeper == nil { ilsenThere.arrive(name: nil) }
                if orlaSees.keeper == nil { orlaThere.arrive(name: nil) }
            }
            return false
        }
        let mine = try XCTUnwrap(ilsenSees.keeper?.house), theirs = try XCTUnwrap(orlaSees.keeper?.house)
        let kingdoms = await (frontier.state.frontier?.kingdom(of: mine), frontier.state.frontier?.kingdom(of: theirs))
        XCTAssertEqual(kingdoms.0, "The Nullmere")
        XCTAssertEqual(kingdoms.1, "The Farmere")
        let atWar = await frontier.state.world.isAtWar(mine, theirs)
        XCTAssertTrue(atWar, "Kingdoms meet at war")
        let levy = try XCTUnwrap(ilsenSees.world).units(of: mine).filter(\.kind.isMilitary)
        XCTAssertFalse(levy.isEmpty, "Ilsen sees their levy about their seat there")
        try await until("the kingdoms told to any who read the Frontier's status") {
            Set(ilsenSees.lastStatus?.frontier?.standings.map(\.realm) ?? []) == ["The Nullmere", "The Farmere"]
        }
        print("REALM keepers of two realms crossed by their clients to the Frontier and were seated there for their kingdoms, at war")

        // They keep its season to its end; then each realm is told, once.
        try await until("the Frontier's season to end", timeout: Double(FrontierState.lasts) * watch * 3 + 30) {
            await frontier.state.frontier?.season == 2
        }
        let ended = await frontier.state.frontierReport?.last
        let result = try XCTUnwrap(ended)
        XCTAssertEqual(Set(result.honours.map(\.keeper)), [ilsenID, orlaID])
        try await until("the season told home in both realms") {
            let west = await home.state.keeper(ilsenID)?.crossing, east = await away.state.keeper(orlaID)?.crossing
            let told = await (home.state.frontierNews?.last?.season, away.state.frontierNews?.last?.season)
            return west == nil && east == nil && told.0 == 1 && told.1 == 1
        }
        let lines = await home.state.world.chronicle.filter { $0.text.contains("comes home from the Frontier's first season") }.count
        XCTAssertEqual(lines, 1, "Told once")
        print("REALM the Frontier's season ran its watches and was told home in both realms, once")
    }
}

/// The play-through over databases held in memory, each knowing every key
/// on the server as a real server's databases do.
final class FrontierPlayThroughTests: XCTestCase {
    @MainActor
    func testKeepersOfTwoRealmsMeetAtTheFrontierThroughTheirClients() async throws {
        let west = FakeSpacetime(), east = FakeSpacetime(), lost = FakeSpacetime()
        let steward = try await west.createIdentity()
        for db in [east, lost] { await db.publish(by: steward) }
        let databases = FrontierPlayThrough.Databases(
            west: west, east: east, lost: lost, lostAddress: "http://server.test/lost", westAddress: "http://server.test/west",
            eastAddress: "http://server.test/east",
            share: { credentials in
                for db in [west, east, lost] { await db.remember(credentials) }
            })
        try await FrontierPlayThrough.play(databases, token: steward.token)
    }
}
