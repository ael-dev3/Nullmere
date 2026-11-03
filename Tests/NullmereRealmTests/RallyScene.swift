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

        // Sculptures for both Houses' commanders' stars, twice as many to
        // the rally's caller; each keeper counts only their own.
        let level = 1
        try await until("the sculptures counted, each House its own") {
            earA.world?.sculptures(of: ama) == 2 * GameState.sculpturesPerLairLevel * level
                && earB.world?.sculptures(of: bel) == GameState.sculpturesPerLairLevel * level
        }
        let peeked = await MainActor.run { (earA.world?.sculptures(of: bel), earB.world?.sculptures(of: ama)) }
        XCTAssertEqual(peeked.0, 0, "Ama can't count Bel's")
        XCTAssertEqual(peeked.1, 0, "nor Bel Ama's")
        // Enough more for a star each, and each raises one from their own client.
        await steward.reshape { realm in
            for house in [ama, bel] {
                _ = realm.world.giveSculptures(Commander.sculpturesToRaise(from: 1)! - realm.world.sculptures(of: house), to: house)
            }
        }
        for (link, ear, house) in [(a, earA, ama), (b, earB, bel)] {
            try await until("a star's sculptures kept") { ear.world?.sculptures(of: house) == Commander.sculpturesToRaise(from: 1) }
            let commander = try await MainActor.run { try XCTUnwrap(ear.world?.commanders(of: house).first).id }
            await MainActor.run { link.send(.raiseStar(commander: commander)) }
            try await until("the star raised, as its keeper sees it") {
                ear.world?.commander(commander)?.starCount == 2 && ear.world?.sculptures(of: house) == 0
            }
        }
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

extension RallyScene {
    /// What allies do for each other, each from their own client: Ama,
    /// the alliance's leader, sets it a study, both Houses give stores
    /// toward it until its first grade is learned for both; Ama raises a
    /// work, and Bel's help hastens it; Bel sends Ama a gift of timber.
    /// Each keeper sees what the other did.
    func helpEachOther(ama: Int, bel: Int) async throws {
        let alliance = try await MainActor.run { try XCTUnwrap(earA.world?.alliance(of: ama)) }
        XCTAssertEqual(alliance.leader, ama, "Ama leads it")
        XCTAssertTrue(alliance.members.contains(bel))
        let study = AllianceStudy.fieldcraft
        let cost = study.cost(grade: 1)
        // Stores enough for each to give half, and to raise a work.
        await steward.reshape { realm in
            for house in [ama, bel] { realm.world.houses[house].stock.credit(cost + Stock(grain: 200, timber: 200, stone: 200, moonsalt: 10)) }
        }
        try await until("the stores given them") { (earA.world?.houses[ama].stock.grain ?? 0) >= cost.grain }

        // The study, set by Ama and seen by Bel.
        await MainActor.run { a.send(.pursueAllianceStudy(study)) }
        try await until("Bel to see the study set") { earB.world?.alliance(of: bel)?.lore?.pursuit == study }
        let half = Stock(grain: cost.grain / 2, timber: cost.timber / 2, stone: cost.stone / 2, moonsalt: cost.moonsalt / 2)
        await MainActor.run { a.send(.giveToAlliance(half)) }
        try await until("Ama's half given, as Bel sees it") { earB.world?.alliance(of: bel)?.lore?.given == half }
        await MainActor.run { b.send(.giveToAlliance(Stock(grain: cost.grain - half.grain, timber: cost.timber - half.timber, stone: cost.stone - half.stone, moonsalt: cost.moonsalt - half.moonsalt))) }
        try await until("the first grade learned, as both see it") {
            earA.world?.alliance(of: ama)?.lore?.grade(of: study) == 1 && earB.world?.alliance(of: bel)?.lore?.grade(of: study) == 1
        }

        // A work raised by Ama, hastened by Bel's help.
        let seat = try await MainActor.run { try XCTUnwrap(earA.world?.seat(of: ama)).id }
        if await MainActor.run(body: { earA.world?.hold(seat)?.project == nil }) {
            let kind = try await MainActor.run { () -> BuildingKind in
                let world = try XCTUnwrap(earA.world)
                return try XCTUnwrap(BuildingKind.allCases.first { world.refusal(of: .build(hold: seat, kind: $0), as: ama) == nil })
            }
            await MainActor.run { a.send(.build(hold: seat, kind: kind)) }
            try await until("Ama's work begun") { earA.world?.hold(seat)?.project != nil }
        }
        await MainActor.run { b.send(.help(house: ama)) }
        try await until("Bel's help on Ama's work, as Ama sees it") {
            earA.world?.hold(seat)?.project?.helpers?.contains(bel) == true
        }
        let heard: @MainActor @Sendable (Listener, (GameEvent) -> Bool) -> Bool = { ear, match in
            ear.events.contains { event in
                switch event {
                case .heard(let events), .answered(let events), .watchTurned(_, let events), .settled(_, let events): return events.contains(where: match)
                default: return false
                }
            }
        }
        try await until("Ama told of Bel's help") { heard(earA) { if case .helpGiven(bel, ama, _) = $0 { return true } else { return false } } }

        // A gift of timber from Bel to Ama.
        await MainActor.run { b.send(.gift(to: ama, resource: .timber, amount: 25)) }
        try await until("Ama told of Bel's gift") {
            heard(earA) { if case .gifted(bel, ama, let gift) = $0 { return gift.timber == 25 } else { return false } }
        }
    }
}

extension RallyScene {
    /// Letters between two keepers, each read by its writer and reader
    /// alone; and the pedlar lying off Ama's hold, a ware bought of him
    /// from her client kept through the watches after, Bel never knowing
    /// of him.
    func writeAndTrade(ama: Int, bel: Int) async throws {
        // A letter each way.
        await MainActor.run { a.send(.writeLetter(to: bel, words: "The ford opens at the full moon")) }
        try await until("Bel to read Ama's letter") {
            earB.world?.letters(of: bel).contains { $0.from == ama && $0.text == "The ford opens at the full moon" } == true
        }
        await MainActor.run { b.send(.writeLetter(to: ama, words: "Then we cross together")) }
        try await until("Ama to read Bel's answer") {
            earA.world?.letters(of: ama).contains { $0.from == bel && $0.text == "Then we cross together" } == true
        }
        let told = await MainActor.run {
            earB.events.contains { event in
                if case .heard(let events) = event { return events.contains { if case .letterSent(let l) = $0 { return l.from == ama } else { return false } } }
                return false
            }
        }
        XCTAssertTrue(told, "Bel is told the letter came")

        // The pedlar comes to Ama's hold by the lake.
        let came = Staged()
        await steward.reshape { realm in
            var world = realm.world
            guard world.holds(of: ama).contains(where: { world.stoneWater(before: $0) != nil }) else { return }
            world.watch = GameState.pedlarComes(to: ama, from: world.watch + 1)
            _ = world.turnThePedlars()
            guard let pedlar = world.pedlar(for: ama),
                  let ware = pedlar.wares.first(where: { if case .sculptures = $0.goods { return true } else { return false } }) else { return }
            world.houses[ama].stock.credit(ware.price)
            realm.world = world
            came.set(seat: pedlar.hold, lair: ware.id, spoils: ware.price, companies: [])
        }
        let ware = came.lair
        guard ware != 0 else { return XCTFail("The pedlar found no hold of Ama's by the lake") }
        try await until("Ama to see the pedlar lying off her hold") { earA.world?.pedlar(for: ama) != nil }
        let bels = await MainActor.run { earB.world?.pedlar(for: ama) }
        XCTAssertNil(bels, "Bel knows nothing of Ama's pedlar")
        let before = await MainActor.run { earA.world?.sculptures(of: ama) ?? 0 }
        await MainActor.run { a.send(.buyFromPedlar(ware: ware)) }
        try await until("the ware sold, as Ama sees it") {
            earA.world?.pedlar(for: ama)?.wares.first { $0.id == ware }?.sold == true && (earA.world?.sculptures(of: ama) ?? 0) > before
        }
        let bought = await MainActor.run { earA.world?.sculptures(of: ama) ?? 0 }
        // Kept through the watch's turn: what was bought stays bought.
        let watch = await MainActor.run { earA.world?.watch ?? 0 }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        let kept = await MainActor.run { (earA.world?.sculptures(of: ama) ?? 0, earA.world?.pedlar(for: ama)?.wares.first { $0.id == ware }?.sold) }
        XCTAssertGreaterThanOrEqual(kept.0, bought, "The sculptures bought are kept")
        XCTAssertNotEqual(kept.1, false, "and the ware stays sold while he lies there")
        let again = await MainActor.run { earA.world?.refusal(of: .buyFromPedlar(ware: ware), as: ama) }
        XCTAssertEqual(again, kept.1 == nil ? .noPedlar : .wareSold, "Not to be bought again")
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
