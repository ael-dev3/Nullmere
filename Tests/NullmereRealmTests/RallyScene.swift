import Foundation
@testable import NullmereCore
import XCTest
@testable import NullmereRealm
import NullmereTestSupport

/// Two keepers of one alliance, each on their own client, break a lair of
/// the wilds with a rally: the scene set in the steward's realm, then
/// played out by their orders alone. Played over SpacetimeDB in memory
/// and on a real server alike.
struct RallyScene {
    let steward: RealmSteward
    let a: NetworkRealmLink, earA: Listener
    let b: NetworkRealmLink, earB: Listener
    let timeout: Double

    func until(_ what: String, _ condition: @escaping @MainActor @Sendable () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !MainActor.run(body: condition) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// Ama's and Bel's Houses, allied: a lair is set out from Ama's seat
    /// with a Muster Hall there and strong companies of both by it; Ama
    /// calls a rally, both send companies, and the watches turn until the
    /// host has broken it. Both clients see it gone and the spoils shared.
    func breakALair(ama: Int, bel: Int) async throws {
        let staged = Staged()
        await steward.reshape { realm in
            var world = realm.world
            guard let seat = world.seat(of: ama), let spot = world.map.hexes.first(where: { hex in
                (4...5).contains(hex.distance(to: seat.position)) && world.map[hex]?.terrain == .greyfield
                    && world.unit(at: hex) == nil && world.hold(at: hex) == nil && world.wild(at: hex) == nil
                    && world.site(at: hex) == nil && world.shrine(at: hex) == nil && world.lair(at: hex) == nil
                    && world.holds.allSatisfy { $0.position.distance(to: hex) >= 4 }
                    && world.path(for: Unit(id: -1, kind: .spear, owner: ama, position: seat.position), to: hex) != nil
            }) else { return }
            let lair = Lair(id: world.takeID(), kind: .reavers, level: 1, position: spot, raised: world.watch)
            world.lairs = world.lairsStanding + [lair]
            world.reveal(around: spot, range: 2, for: ama)
            world.holds[world.holdIndex(seat.id)!].levels[.musterHall] = max(1, seat.level(.musterHall))
            var free = seat.position.spiral(3).filter { hex in
                (1...3).contains(hex.distance(to: seat.position)) && world.map[hex]?.terrain.isPassable == true
                    && world.map[hex]?.terrain != .strand && world.unit(at: hex) == nil && world.hold(at: hex) == nil
            }
            guard free.count >= 4 else { return }
            var companies: [(Int, Int)] = []
            for house in [ama, ama, ama, bel] {
                let unit = Unit(id: world.takeID(), kind: .spear, owner: house, position: free.removeFirst(), tier: 5)
                world.units.append(unit)
                companies.append((unit.id, house))
            }
            realm.world = world
            staged.set(seat: seat.id, lair: lair.id, spoils: lair.spoils, companies: companies)
        }
        let (seat, lair, companies) = (staged.seat, staged.lair, staged.companies)
        XCTAssertFalse(companies.isEmpty, "The scene was set")
        guard !companies.isEmpty else { return }
        try await until("Ama to see the lair") { earA.world?.lair(lair) != nil }

        // Ama calls the rally; both Houses send their companies to it.
        await MainActor.run { a.send(.callRally(from: seat, against: lair, watches: 1)) }
        try await until("the rally called") { earA.world?.ralliesStanding.contains { $0.target == lair } == true }
        let rally = try await MainActor.run { try XCTUnwrap(earA.world?.ralliesStanding.first { $0.target == lair }).id }
        try await until("Bel to know of the rally") { earB.world?.rally(rally) != nil }
        for (unit, house) in companies {
            let link = house == ama ? a : b
            await MainActor.run { link.send(.joinRally(rally: rally, unit: unit)) }
        }
        try await until("every company sent") { earA.world?.rally(rally)?.companies.count == companies.count }

        // Watch by watch, both ready, until the host has struck.
        for _ in 0..<12 {
            let gone = await MainActor.run { earA.world?.lair(lair) == nil }
            if gone { break }
            let watch = await MainActor.run { earA.world?.watch ?? 0 }
            await MainActor.run { a.setReady(true); b.setReady(true) }
            try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        }
        try await until("the lair broken, as both keepers see it") {
            earA.world?.lair(lair) == nil && earB.world?.lair(lair) == nil && earA.world?.rally(rally) == nil
        }
        let assault: @MainActor @Sendable (Listener) -> LairAssault? = { ear in
            for event in ear.events {
                let events: [GameEvent]
                switch event {
                case .heard(let heard), .answered(let heard), .watchTurned(_, let heard), .settled(_, let heard): events = heard
                default: continue
                }
                for case .lairAssaulted(let assault) in events where assault.broken { return assault }
            }
            return nil
        }
        let told = await MainActor.run { (assault(earA), assault(earB)) }
        XCTAssertEqual(told.0?.houses, [ama, bel], "Ama is told of the host that broke it, its caller first")
        XCTAssertEqual(told.1?.houses, [ama, bel], "and so is Bel")
        // The spoils shared by the companies each sent: three parts to Ama, one to Bel.
        let spoils = staged.spoils
        XCTAssertEqual(told.0?.shares.first { $0.house == ama }?.spoils, spoils.share(3, of: 4), "Ama's share")
        XCTAssertEqual(told.1?.shares.first { $0.house == bel }?.spoils, spoils.share(1, of: 4), "Bel's share")
        XCTAssertNotEqual(spoils.share(1, of: 4), .zero, "A share worth having")
    }
}

/// What a scene set in the steward's realm holds, read back by the test.
final class Staged: @unchecked Sendable {
    private let lock = NSLock()
    private var values: (seat: Int, lair: Int, spoils: Stock, companies: [(Int, Int)]) = (0, 0, .zero, [])
    func set(seat: Int, lair: Int, spoils: Stock, companies: [(Int, Int)]) {
        lock.lock(); values = (seat, lair, spoils, companies); lock.unlock()
    }
    var seat: Int { lock.lock(); defer { lock.unlock() }; return values.seat }
    var lair: Int { lock.lock(); defer { lock.unlock() }; return values.lair }
    var spoils: Stock { lock.lock(); defer { lock.unlock() }; return values.spoils }
    var companies: [(Int, Int)] { lock.lock(); defer { lock.unlock() }; return values.companies }
}
