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

extension RallyScene {
    /// The Drowned Crown fought over by two sides, each keeper's House in
    /// its own alliance and at war with the other: the ford laid bare late
    /// in its days, Ama's company takes the crown up, Bel's strikes its
    /// bearer down and takes it in turn, and as the water comes back the
    /// side that bore it longest is given the lake's moonsalt. Every step
    /// is an order from a keeper's own client; both see each turn of it.
    func contestTheCrown(ama: Int, bel: Int) async throws {
        // Each in an alliance of their own, and at war.
        for (link, ear, house, name) in [(a, earA, ama, "The Pale Oar"), (b, earB, bel, "The Black Reed")] {
            let sworn = await MainActor.run { ear.world?.alliance(of: house) }
            if let sworn, sworn.members.contains(ama) && sworn.members.contains(bel) {
                await MainActor.run { link.send(.leaveAlliance) }
                try await until("\(name)'s founder free of the shared alliance") { ear.world?.alliance(of: house) == nil }
            }
            if await MainActor.run(body: { ear.world?.alliance(of: house) == nil }) {
                await MainActor.run { link.send(.foundAlliance(name: name)) }
                try await until("\(name) founded") { ear.world?.alliance(of: house) != nil }
            }
        }
        if await MainActor.run(body: { earB.world?.isAtWar(bel, ama) != true }) {
            await MainActor.run { b.send(.declareWar(on: ama)) }
        }
        try await until("war between the two alliances, as both see it") {
            earA.world?.isAtWar(ama, bel) == true && earB.world?.isAtWar(ama, bel) == true
        }
        let sides = await MainActor.run { (earA.world!.crownSide(of: ama), earB.world!.crownSide(of: bel)) }
        XCTAssertNotEqual(sides.0, sides.1, "Two sides")

        // The scene: the ford bare six watches before the water comes
        // back, the crown at its heart, a weak company of Ama's beside it
        // and a strong one of Bel's on its other side.
        let staged = CrownStage()
        await steward.reshape { realm in
            var world = realm.world
            guard world.crown == nil, world.ford == nil else { return }
            var watch = max(world.watch, GameState.lunarMonth)
            while !(GameState.fordOpen(at: watch) && GameState.fordWatchesLeft(at: watch) == 6) { watch += 1 }
            world.watch = watch
            _ = world.turnTide()
            _ = world.contestCrown()
            guard let course = world.ford, let crown = world.crown else { return }
            let beside = crown.hex.neighbors.filter { hex in
                (course.contains(hex) || world.map[hex]?.terrain.isPassable == true) && world.hold(at: hex) == nil
                    && world.lair(at: hex) == nil
            }
            guard beside.count >= 2 else { return }
            for hex in [crown.hex, beside[0], beside[1]] {
                world.units.removeAll { $0.position == hex }
            }
            var weak = Unit(id: world.takeID(), kind: .spear, owner: ama, position: beside[0], tier: 1)
            weak.health = 10
            let strong = Unit(id: world.takeID(), kind: .spear, owner: bel, position: beside[1], tier: 5)
            world.units += [weak, strong]
            for house in [ama, bel] { world.reveal(around: crown.hex, range: 2, for: house) }
            realm.world = world
            staged.set(heart: crown.hex, ama: weak.id, bel: strong.id)
        }
        guard let heart = staged.heart else { return XCTFail("The ford could not be laid bare") }
        let (amas, bels) = (staged.ama, staged.bel)
        try await until("both to see the crown on the ford") { earA.world?.crown != nil && earB.world?.crown != nil }

        func turnTheWatch() async throws {
            let watch = await MainActor.run { earA.world?.watch ?? 0 }
            await MainActor.run { a.setReady(true); b.setReady(true) }
            try await until("the watch after \(watch)") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        }

        // Ama's company steps onto it and takes it up.
        await MainActor.run { a.send(.move(unit: amas, to: heart)) }
        for _ in 0..<3 where await MainActor.run(body: { earA.world?.crown?.bearer != amas }) { try await turnTheWatch() }
        try await until("the crown borne by Ama's company, as both see it") {
            earA.world?.crown?.bearer == amas && earB.world?.crown?.bearer == amas
        }
        try await turnTheWatch()
        try await until("a mark for Ama's side") { (earB.world?.crown?.marks[sides.0] ?? 0) >= 1 }

        // Bel's strikes its bearer down, and takes the crown where it fell.
        for _ in 0..<4 where await MainActor.run(body: { earB.world?.unit(amas) != nil }) {
            let at = await MainActor.run { earB.world?.unit(amas)?.position ?? heart }
            await MainActor.run { b.send(.attack(unit: bels, target: at)) }
            try await turnTheWatch()
        }
        try await until("Ama's bearer struck down") { earA.world?.unit(amas) == nil && earA.world?.crown?.bearer != amas }
        for _ in 0..<4 where await MainActor.run(body: { earB.world?.crown?.bearer != bels }) {
            if let fell = await MainActor.run(body: { earB.world?.crown?.hex }), await MainActor.run(body: { earB.world?.unit(bels)?.position != fell }) {
                await MainActor.run { b.send(.move(unit: bels, to: fell)) }
            }
            try await turnTheWatch()
        }
        try await until("the crown borne by Bel's company, as both see it") {
            earA.world?.crown?.bearer == bels && earB.world?.crown?.bearer == bels
        }

        // The watches run on until the water comes back over the ford.
        var marks: [Int: Int] = [:]
        for _ in 0..<8 {
            if let held = await MainActor.run(body: { earB.world?.crown?.marks }) { marks = held }
            if await MainActor.run(body: { earA.world?.crown == nil && earB.world?.crown == nil }) { break }
            try await turnTheWatch()
        }
        XCTAssertGreaterThan(marks[sides.0] ?? 0, 0, "Ama's side bore it")
        XCTAssertGreaterThan(marks[sides.1] ?? 0, 0, "and so did Bel's")
        let sank: @MainActor @Sendable (Listener) -> (Int?, [Int])? = { ear in
            for event in ear.events {
                let events: [GameEvent]
                switch event {
                case .heard(let heard), .answered(let heard), .watchTurned(_, let heard), .settled(_, let heard): events = heard
                default: continue
                }
                for case .crownSank(let side, let houses) in events { return (side, houses) }
            }
            return nil
        }
        try await until("both told the crown sank") { sank(earA) != nil && sank(earB) != nil }
        let told = await MainActor.run { (sank(earA)!, sank(earB)!) }
        let leader = marks.max { ($0.value, -$0.key) < ($1.value, -$1.key) }?.key
        XCTAssertEqual(told.0.0, leader, "The side that bore it longest has it")
        XCTAssertEqual(told.1.0, leader)
        XCTAssertTrue(told.0.1.contains(leader == sides.0 ? ama : bel), "and its House is given the moonsalt")
    }
}

/// Where the crown was set, and the companies set beside it.
final class CrownStage: @unchecked Sendable {
    private let lock = NSLock()
    private var values: (heart: Hex?, ama: Int, bel: Int) = (nil, 0, 0)
    func set(heart: Hex, ama: Int, bel: Int) { lock.lock(); values = (heart, ama, bel); lock.unlock() }
    var heart: Hex? { lock.lock(); defer { lock.unlock() }; return values.heart }
    var ama: Int { lock.lock(); defer { lock.unlock() }; return values.ama }
    var bel: Int { lock.lock(); defer { lock.unlock() }; return values.bel }
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
