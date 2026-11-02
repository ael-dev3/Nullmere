import Foundation
import NullmereCore
import XCTest
@testable import NullmereRealm
import NullmereTestSupport

/// The realm everyone plays, as two Macs would meet it: set
/// NULLMERE_LIVE_REALM to its address (https://maincloud.spacetimedb.com/nullmere)
/// and two keepers' clients, as shipped, with no token but the identities
/// SpacetimeDB gives them, arrive, see each other in the realm, and hear
/// each other's words. Run by the Live realm smoke workflow; it needs no
/// secret, only the realm up and its steward running.
final class LiveRealmSmokeTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 120, _ condition: @escaping @MainActor @Sendable () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !MainActor.run(body: condition) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func testTwoKeepersMeetInTheLiveRealm() async throws {
        guard let text = ProcessInfo.processInfo.environment["NULLMERE_LIVE_REALM"], let url = URL(string: text),
              let transport = SpacetimeHTTP(address: url) else {
            throw XCTSkip("Set NULLMERE_LIVE_REALM to the live realm's address to meet in it")
        }
        let (a, earA, b, earB) = await MainActor.run { () -> (NetworkRealmLink, Listener, NetworkRealmLink, Listener) in
            let a = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 1)
            let b = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 1)
            let earA = Listener(), earB = Listener()
            earA.listen(to: a)
            earB.listen(to: b)
            a.connect()
            b.connect()
            return (a, earA, b, earB)
        }
        defer { Task { @MainActor in a.close(); b.close() } }
        try await until("the realm's status: is the realm up and its steward running?") { earA.hasStatus && earB.hasStatus }
        let status = try await MainActor.run { try XCTUnwrap(earA.lastStatus) }
        print("LIVE \(status.name), age \(status.age), watch \(status.watch): \(status.keepers) keepers, \(status.freeSeats) seats free")
        let mark = String(KeeperIdentity.make().filter(\.isLetter).prefix(5))
        await MainActor.run {
            a.arrive(name: "Sma" + mark)
            b.arrive(name: "Smb" + mark)
        }
        try await until("both keepers to arrive") { earA.keeper?.house != nil && earB.keeper?.house != nil }
        let (houseA, houseB) = await MainActor.run { (earA.keeper!.house!, earB.keeper!.house!) }
        XCTAssertNotEqual(houseA, houseB, "Two keepers, two Houses")
        try await until("each to see the other's House in the realm") {
            earA.world?.houses.indices.contains(houseB) == true && earB.world?.houses.indices.contains(houseA) == true
        }
        let words = "Well met at " + mark
        await MainActor.run { a.send(.say(words: words, toAlliance: false)) }
        try await until("Ama's words heard by Bel") {
            earB.world?.words(heardBy: houseB).contains { $0.from == houseA && $0.text == words } == true
        }
        print("LIVE two keepers arrived in the live realm and one heard the other speak")
    }
}
