import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
import NullmereCore
@testable import NullmereRealm
import NullmereTestSupport
import XCTest
@testable import NullmereCompanionCore

/// The keeper's phone, through its own session as the companion app keeps
/// it, on a real SpacetimeDB server beside their Mac, its line to the realm
/// cut and mended while the Mac plays on: the network lost under the phone
/// and found again, the server and the Mac going on all the while. CI sets
/// NULLMERE_STDB_COMPANION_LOST to a database of its own, fresh, and
/// NULLMERE_STDB_TOKEN to the publisher's token; its realm job runs it with
/// the rest of the play-through.
@MainActor
final class CompanionSpacetimeIntegrationTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 60, _ condition: () -> Bool) async throws -> Double {
        let began = Date()
        while !condition() {
            if Date().timeIntervalSince(began) > timeout { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        return Date().timeIntervalSince(began)
    }

    /// The realm's steward, taking up the database once whoever held it last
    /// has let it go.
    private func takeUp(_ transport: SpacetimeHTTP, _ token: String) async throws -> RealmSteward {
        let deadline = Date().addingTimeInterval(100)
        while true {
            do {
                return try await RealmSteward(transport: transport, token: token, name: "The Nullmere", seed: "phone-lost",
                                              seats: 4, watchLength: 600, now: Date().timeIntervalSince1970)
            } catch where RealmSteward.isHeldByAnother(error) && Date() < deadline {
                try await Task.sleep(nanoseconds: 5_000_000_000)
            }
        }
    }

    /// Cut off mid-game, the phone says the realm is out of reach in its
    /// own words and keeps the House as it last stood; an order given then
    /// waits. The Mac plays on. The line mended, the phone is in reach
    /// again by the same key, never linked again, shown what the Mac did
    /// meanwhile, and the order it gave while cut off is carried out by the
    /// realm and seen on the Mac. Cut again and mended with no word that
    /// the network is back, it finds the realm again by its own reads.
    func testThePhonesLineToTheRealmCutAndMendedWhileTheMacPlaysOn() async throws {
        let environment = ProcessInfo.processInfo.environment
        guard let text = environment["NULLMERE_STDB_COMPANION_LOST"], let address = URL(string: text),
              let direct = SpacetimeHTTP(address: address),
              let token = environment["NULLMERE_STDB_TOKEN"], !token.isEmpty else {
            throw XCTSkip("Set NULLMERE_STDB_COMPANION_LOST and NULLMERE_STDB_TOKEN to cut a keeper's phone off from a SpacetimeDB server and back")
        }
        let steward = try await takeUp(direct, token)
        Task { await steward.run() }
        defer { Task { await steward.stop() } }

        // The keeper in by their Mac, straight to the server.
        let mac = NetworkRealmLink(transport: SpacetimeHTTP(address: address, session: URLSession(configuration: .ephemeral))!,
                                   credentials: MemoryStore(), pollInterval: 0.5)
        var macWorld: GameState?
        var arrived: Keeper?
        mac.onEvent = { event in
            switch event {
            case .arrived(let keeper, let world):
                arrived = keeper
                macWorld = world
            case .changed(let world), .watchTurned(let world, _), .settled(let world, _), .orderRefused(_, let world):
                macWorld = world
            default: break
            }
        }
        mac.connect()
        mac.arrive(name: "Ama" + String(KeeperIdentity.make().filter(\.isLetter).prefix(6)))
        _ = try await until("the keeper in by their Mac") { arrived != nil }
        let keeper = try XCTUnwrap(arrived)
        let house = try XCTUnwrap(keeper.house)

        // The phone, its own session as the app keeps it, through a line of
        // its own to the same server, linked by the code the Mac shows.
        let relay = try LineRelay(to: address)
        defer { relay.stop() }
        let reached = relay.carrying(address)
        let store = MemoryStore()
        let phone = CompanionSession(memory: PassingMemory()) { realm in
            SpacetimeHTTP(address: realm, session: URLSession(configuration: .ephemeral)).map {
                NetworkRealmLink(transport: $0, credentials: store, pollInterval: 0.5)
            }
        }
        let code = LinkCode.make()
        var offered: Result<Int, LinkRefusal>?
        mac.offerLink(code: code) { offered = $0 }
        _ = try await until("the realm to take the Mac's offer") { offered != nil }
        _ = try XCTUnwrap(offered).get()
        phone.take(try XCTUnwrap(CompanionInvite(realm: reached, code: code)))
        _ = try await until("the phone in as the keeper") { phone.phase == .keeping && phone.ledger != nil }
        XCTAssertEqual(phone.keeper?.id, keeper.id)
        let key = try XCTUnwrap(store.value, "The phone's own key, kept")
        let company = try XCTUnwrap(phone.ledger?.companies.first { $0.orders.contains { $0.title == "Fortify" } })

        // The line cut: the phone says so in its own words, and keeps the House.
        relay.cut()
        let noticed = try await until("the phone to say the realm is out of reach") { phone.outOfReach != nil }
        let said = try XCTUnwrap(phone.outOfReach)
        XCTAssertFalse(said.contains("Mac"), "Told in the phone's words: \(said)")
        XCTAssertEqual(phone.phase, .keeping, "Still in, the House as it last stood")
        XCTAssertNotNil(phone.ledger)
        XCTAssertEqual(phone.keeper?.id, keeper.id)

        // An order given while it is cut off waits; the Mac plays on.
        phone.give(.fortify(unit: company.id), told: "Fortify the \(company.name)")
        XCTAssertEqual(phone.word?.awaited, true)
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): \(CompanionSession.waitsForReach)",
                       "Told it waits, not that it went")
        let before = try XCTUnwrap(macWorld?.houses[house].stock)
        mac.send(.barter(give: .timber, take: .stone, amount: 3))
        _ = try await until("the Mac's barter while the phone is cut off") { macWorld?.houses[house].stock != before }
        let bartered = try XCTUnwrap(macWorld?.houses[house].stock)
        XCTAssertNotEqual(phone.world?.houses[house].stock, bartered, "Unseen on the phone while its line is down")
        XCTAssertEqual(phone.word?.awaited, true, "Its order still waiting")
        XCTAssertNotEqual(macWorld?.unit(company.id)?.fortified, true, "and nowhere carried out")

        // Mended, and the phone told its network is back, as the app is.
        // Each time is from the mending, to when it was seen.
        let mended = Date()
        relay.mend()
        phone.networkReturned()
        _ = try await until("the phone in reach again") { phone.outOfReach == nil }
        let back = Date().timeIntervalSince(mended)
        _ = try await until("the phone shown the Mac's barter") { phone.world?.houses[house].stock.stone == bartered.stone }
        let caughtUp = Date().timeIntervalSince(mended)
        XCTAssertEqual(phone.phase, .keeping)
        XCTAssertEqual(phone.keeper?.id, keeper.id)
        XCTAssertEqual(store.value, key, "By the same key, never linked again")
        _ = try await until("the realm's word on the order given while cut off") { phone.word?.awaited == false }
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): carried out by the realm.")
        _ = try await until("the order seen on the Mac") { macWorld?.unit(company.id)?.fortified == true }
        let seen = Date().timeIntervalSince(mended)
        print(String(format: "REALM the phone's line to the realm cut: it said so in %.2f s (\"%@\") and kept the House; mended and "
                     + "told its network was back, it was in reach again %.2f s after and shown the Mac's barter made meanwhile by "
                     + "%.2f s, by the same key; the order it gave while cut off was carried out by the realm and seen on the Mac by %.2f s",
                     noticed, said, back, caughtUp, seen))

        // Cut again, and mended with no word of the network: the phone finds
        // the realm again by its own reads, further apart while it is gone.
        relay.cut()
        _ = try await until("the phone to say the realm is out of reach again") { phone.outOfReach != nil }
        let stores = try XCTUnwrap(macWorld?.houses[house].stock)
        mac.send(.barter(give: .timber, take: .stone, amount: 3))
        _ = try await until("the Mac's second barter") { macWorld?.houses[house].stock != stores }
        let again = try XCTUnwrap(macWorld?.houses[house].stock)
        relay.mend()
        let found = try await until("the phone in reach again by its own reads", timeout: 90) {
            phone.outOfReach == nil && phone.world?.houses[house].stock.stone == again.stone
        }
        XCTAssertEqual(store.value, key)
        print(String(format: "REALM cut again and mended with no word of the network, the phone found the realm and the Mac's "
                     + "second barter by its own reads in %.2f s; the line turned away %d connections while it was down",
                     found, relay.refused))
        phone.pause()
        mac.leave()
    }
}
