import Foundation
import NullmereCore
import XCTest
@testable import NullmereRealm

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
            try await transport.call("publish", [.integer(999_999), .string("{}"), .string("{}"), .string("[]")], token: stranger.token)
            XCTFail("A stranger wrote the world")
        } catch {
            XCTAssertTrue(String(describing: error).contains("steward"), "\(error)")
        }
        _ = token
    }

    func testKeepersPlayThroughSpacetime() async throws {
        let (transport, token) = try server()
        let steward = try await RealmSteward(transport: transport, token: token, name: "The Nullmere", seed: "integration",
                                             seats: 4, watchLength: 600, now: Date().timeIntervalSince1970)
        let running = Task { await steward.run() }
        defer { running.cancel() }

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
        try await until("Bel to see Ama's order") { earB.world?.unit(spear.id)?.fortified == true }

        let watch = world.watch
        await MainActor.run {
            a.setReady(true)
            b.setReady(true)
        }
        try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        print("REALM two keepers met, gave orders and turned the watch on SpacetimeDB")
    }
}
