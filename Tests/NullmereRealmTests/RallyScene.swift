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
        // the rally's caller, and more for both climbing the ladder of the
        // lairs to its first rung; each keeper counts only their own.
        try await until("both on the ladder's first rung") { earA.world?.lairRung(of: ama) == 1 && earB.world?.lairRung(of: bel) == 1 }
        let level = 1
        try await until("the sculptures counted, each House its own") {
            earA.world?.sculptures(of: ama) == 2 * GameState.sculpturesPerLairLevel * level + GameState.sculpturesPerRung * level
                && earB.world?.sculptures(of: bel) == GameState.sculpturesPerLairLevel * level + GameState.sculpturesPerRung * level
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

extension RallyScene {
    /// The realm's calendar as two keepers' clients foretell it: the same
    /// happening on the same watch for both; brought to its eve, the watch
    /// turns and both see that very happening begin, its end now foretold.
    func foretellAHappening(ama: Int, bel: Int) async throws {
        let foretold = try await MainActor.run { () -> (CalendarEntry, CalendarEntry?) in
            let a = try XCTUnwrap(earA.world).calendar(for: ama, span: Happening.every + 1)
            let b = try XCTUnwrap(earB.world).calendar(for: bel, span: Happening.every + 1)
            let first = try XCTUnwrap(a.first { if case .happening = $0.kind { return true } else { return false } })
            return (first, b.first { $0.watch == first.watch && $0.kind == first.kind })
        }
        XCTAssertEqual(foretold.1, foretold.0, "Both keepers foretell the same happening on the same watch")
        guard case .happening(let kind) = foretold.0.kind else { return XCTFail() }
        // To its eve, every happening before it over.
        await steward.reshape { realm in
            realm.world.watch = max(realm.world.watch, foretold.0.watch - 1)
            realm.world.happening = nil
        }
        try await until("both at the happening's eve") {
            earA.world?.watch == foretold.0.watch - 1 && earB.world?.watch == foretold.0.watch - 1
        }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the happening begun, as both see it") {
            earA.world?.happening?.kind == kind && earB.world?.happening?.kind == kind
        }
        let ends = foretold.0.watch + Happening.lasts
        let both = await MainActor.run {
            (earA.world?.calendar(for: ama).contains(CalendarEntry(watch: ends, kind: .happeningEnds(kind))),
             earB.world?.calendar(for: bel).contains(CalendarEntry(watch: ends, kind: .happeningEnds(kind))))
        }
        XCTAssertEqual(both.0, true, "Its end foretold for Ama")
        XCTAssertEqual(both.1, true, "and for Bel")
    }
}

extension RallyScene {
    /// The watch's labours between two keepers: Ama raises a work and Bel
    /// musters a company, each from their own client, each set to it as a
    /// labour; as the watch turns both are done, each House told of its own
    /// labour and never of the other's.
    func laboursOfTheWatch(ama: Int, bel: Int) async throws {
        let (seatA, seatB) = try await MainActor.run {
            (try XCTUnwrap(earA.world?.seat(of: ama)).id, try XCTUnwrap(earB.world?.seat(of: bel)).id)
        }
        // A work and a muster each keeper can pay for.
        await steward.reshape { realm in
            for house in [ama, bel] { realm.world.houses[house].stock.credit(Stock(grain: 600, timber: 600, stone: 600, moonsalt: 20)) }
            if let index = realm.world.holdIndex(seatA) { realm.world.holds[index].project = nil }
            if let index = realm.world.holdIndex(seatB) { realm.world.holds[index].training = nil }
        }
        try await until("the stores given") { (earA.world?.houses[ama].stock.timber ?? 0) >= 600 && (earB.world?.houses[bel].stock.timber ?? 0) >= 600 }
        let work = try await MainActor.run { () -> BuildingKind in
            let world = try XCTUnwrap(earA.world)
            return try XCTUnwrap(BuildingKind.allCases.first { world.refusal(of: .build(hold: seatA, kind: $0), as: ama) == nil })
        }
        let kind = try await MainActor.run { () -> UnitKind in
            let world = try XCTUnwrap(earB.world)
            return try XCTUnwrap(UnitKind.allCases.first { world.refusal(of: .train(hold: seatB, kind: $0), as: bel) == nil })
        }
        await MainActor.run { a.send(.build(hold: seatA, kind: work)) }
        await MainActor.run { b.send(.train(hold: seatB, kind: kind)) }
        try await until("the work and the muster under way") {
            earA.world?.hold(seatA)?.project != nil && earB.world?.hold(seatB)?.training != nil
        }
        // Set to them as their labours, and both a watch from done.
        await steward.reshape { realm in
            realm.world.labourBook = [ama: Labours(watch: realm.world.watch, tasks: [Labour(kind: .raise, done: 0)], vigour: 0, opened: 0),
                                      bel: Labours(watch: realm.world.watch, tasks: [Labour(kind: .muster, done: 0)], vigour: 0, opened: 0)]
            if let index = realm.world.holdIndex(seatA) { realm.world.holds[index].project?.watchesLeft = 1 }
            if let index = realm.world.holdIndex(seatB) { realm.world.holds[index].training?.watchesLeft = 1 }
        }
        try await until("each keeper's labour shown, their own alone") {
            earA.world?.labours(of: ama)?.tasks.first?.kind == .raise && earB.world?.labours(of: bel)?.tasks.first?.kind == .muster
                && earA.world?.labours(of: bel) == nil && earB.world?.labours(of: ama) == nil
        }
        let watch = await MainActor.run { earA.world?.watch ?? 0 }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        let told: @MainActor @Sendable (Listener, Int, LabourKind) -> Bool = { ear, house, kind in
            ear.events.contains { event in
                switch event {
                case .heard(let events), .watchTurned(_, let events), .answered(let events), .settled(_, let events):
                    return events.contains(.labourDone(house: house, kind: kind))
                default: return false
                }
            }
        }
        try await until("each told of their own labour done") { told(earA, ama, .raise) && told(earB, bel, .muster) }
        let crossed = await MainActor.run { (told(earA, bel, .muster), told(earB, ama, .raise)) }
        XCTAssertFalse(crossed.0, "Ama never hears of Bel's labour")
        XCTAssertFalse(crossed.1, "nor Bel of Ama's")
        let vigour = await MainActor.run { (earA.world?.labours(of: ama)?.vigour, earB.world?.labours(of: bel)?.vigour) }
        XCTAssertEqual(vigour.0, Labours.vigourPerLabour)
        XCTAssertEqual(vigour.1, Labours.vigourPerLabour)
    }
}

extension RallyScene {
    /// A false reflection cast from Ama's client, and at the Still Hour
    /// Bel's client shows Ama's company mirrored on a shore where none is.
    func teachTheLakeToLie(ama: Int, bel: Int) async throws {
        let cast = Staged()
        await steward.reshape { realm in
            var world = realm.world
            guard let pair = world.holds(of: ama).lazy.compactMap({ hold -> (Hold, Hex)? in
                hold.position.spiral(GameState.falseReflectionReach)
                    .first { world.isShore($0) && world.unit(at: $0) == nil && world.hold(at: $0) == nil }.map { (hold, $0) }
            }).first else { return }
            world.houses[ama].stock.credit(Stock(moonsalt: 20))
            realm.world = world
            cast.set(seat: pair.0.id, lair: 0, spoils: .zero, companies: [(pair.1.q, pair.1.r)])
        }
        guard let spot = cast.companies.first else { throw XCTSkip("No shore by any hold of Ama's") }
        let shore = Hex(spot.0, spot.1)
        try await until("the moonsalt given") { (earA.world?.houses[ama].stock.moonsalt ?? 0) >= GameState.falseReflectionCost.moonsalt }
        await MainActor.run { a.send(.castReflection(hold: cast.seat, at: shore, kind: .spear)) }
        try await until("Ama's reflection waiting, hers alone to know") {
            earA.world?.falseReflections(of: ama).contains { $0.at == shore } == true && earB.world?.reflections == nil
        }
        // To the eve of the Still Hour, as the realm sets it.
        let set = Staged()
        await steward.reshape { realm in
            let eve = GameState.nextStillHour(from: realm.world.watch + 1) - 1
            realm.world.watch = max(realm.world.watch, eve)
            set.set(seat: realm.world.watch, lair: 0, spoils: .zero, companies: [])
        }
        let watch = set.seat
        XCTAssertTrue(GameState.isStillHour(at: watch + 1), "The next watch is the Still Hour")
        try await until("both at the eve") { earA.world?.watch == watch && earB.world?.watch == watch }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the lake still, as Bel sees it") { (earB.world?.watch ?? 0) > watch && earB.world?.stillHour != nil }
        let seen = await MainActor.run { (earB.world?.stillHour?.glimpses.first { $0.at == shore }, earB.world?.unit(at: shore)) }
        XCTAssertEqual(seen.0?.owner, ama, "Bel sees Ama's company mirrored on that shore")
        XCTAssertNil(seen.1, "where none stands")
    }
}

extension RallyScene {
    /// Up the Spine from two keepers' clients: Ama sends a line of her
    /// commanders, Bel one of his, each at their first stage; each sees
    /// their own stage taken with its stars, and nothing of the other's.
    func upTheSpine(ama: Int, bel: Int) async throws {
        await steward.reshape { realm in
            for house in [ama, bel] {
                while realm.world.commanders(of: house).count < 2 { _ = realm.world.commanderJoins(house, why: "joins") }
                for commander in realm.world.commanders(of: house) {
                    let index = realm.world.commanderIndex(commander.id)!
                    realm.world.commanders![index].experience = Commander.experience(forLevel: 12)
                    realm.world.commanders![index].woundedUntil = nil
                }
                realm.world.ventured = nil
            }
        }
        try await until("both Houses' commanders risen") {
            (earA.world?.commanders(of: ama).count ?? 0) >= 2 && (earB.world?.commanders(of: bel).first?.level ?? 0) >= 12
        }
        let line = try await MainActor.run { try XCTUnwrap(earA.world).commanders(of: ama).prefix(2).map(\.id) }
        let single = try await MainActor.run { try XCTUnwrap(earB.world?.commanders(of: bel).first).id }
        let first = await MainActor.run { (earA.world?.expeditionStage(of: ama) ?? 0, earB.world?.expeditionStage(of: bel) ?? 0) }
        await MainActor.run { a.send(.ventureLine(commanders: line, stage: nil)) }
        await MainActor.run { b.send(.venture(commander: single)) }
        try await until("each House's stage taken, as its keeper sees it") {
            earA.world?.expeditionStage(of: ama) == first.0 + 1 && earB.world?.expeditionStage(of: bel) == first.1 + 1
        }
        let stars = await MainActor.run { (earA.world?.expeditionStars(of: ama, stage: first.0 + 1) ?? 0, earB.world?.expeditionStars(of: bel, stage: first.1 + 1) ?? 0) }
        XCTAssertTrue((1...3).contains(stars.0), "Ama's line won it with its stars")
        XCTAssertTrue((1...3).contains(stars.1), "and Bel's commander with his")
        let peeked = await MainActor.run { (earA.world?.expeditionStage(of: bel), earB.world?.expeditionStage(of: ama)) }
        XCTAssertEqual(peeked.0, 0, "Ama knows nothing of Bel's way up the Spine")
        XCTAssertEqual(peeked.1, 0, "nor Bel of Ama's")
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

extension RallyScene {
    /// At the Lantern Inn: Ama opens a silver chest with the key the watch
    /// gave her House; Bel a gold chest for moonsalt. The realm draws each,
    /// each keeper is told of their own chest alone, and neither sees the
    /// other's keys.
    func openTheInnsChests(ama: Int, bel: Int) async throws {
        let price = InnKeys.goldPrice.moonsalt
        await steward.reshape { realm in
            realm.world.innBook = [ama: InnKeys(silver: 1, gold: 0, sinceCommander: 0, opened: 0),
                                   bel: InnKeys(silver: 0, gold: 0, sinceCommander: 0, opened: 0)]
            realm.world.houses[bel].stock.credit(Stock(moonsalt: price))
        }
        try await until("the keys shown, each their own") {
            earA.world?.innKeys(of: ama).silver == 1 && earB.world?.innBook?[bel] != nil
                && earA.world?.innBook?[bel] == nil && earB.world?.innBook?[ama] == nil
        }
        await MainActor.run {
            a.send(.openInnChest(.silver))
            b.send(.openInnChest(.gold))
        }
        let opened: @MainActor @Sendable (Listener, Int, InnChest) -> Bool = { ear, house, chest in
            ear.events.contains { event in
                switch event {
                case .heard(let events), .watchTurned(_, let events), .answered(let events), .settled(_, let events):
                    return events.contains { if case .innChestOpened(house, chest, _) = $0 { return true } else { return false } }
                default: return false
                }
            }
        }
        try await until("each told of their own chest") { opened(earA, ama, .silver) && opened(earB, bel, .gold) }
        let crossed = await MainActor.run { (opened(earA, bel, .gold), opened(earB, ama, .silver)) }
        XCTAssertFalse(crossed.0, "Ama never hears of Bel's chest")
        XCTAssertFalse(crossed.1, "nor Bel of Ama's")
        try await until("the key spent") { earA.world?.innKeys(of: ama).silver == 0 }
        let refused = await MainActor.run { earA.world?.refusal(of: .openInnChest(.silver), as: ama) }
        XCTAssertEqual(refused, .noInnKey(.silver), "One key, one chest")
    }
}

extension RallyScene {
    /// Ama's company on the Still's shore walks the mirror. Bel's client is
    /// shown the water stilling where it will come out; as the watch turns
    /// both clients see it on the far shore.
    func walkTheMirror(ama: Int, bel: Int) async throws {
        let walk = StagedWalk()
        await steward.reshape { realm in
            let world = realm.world
            guard let shore = world.map.hexes.first(where: { hex in
                world.isOnTheStill(hex) && world.map[hex]!.terrain.isPassable && world.unit(at: hex) == nil
                    && world.hold(at: hex) == nil && world.mirrorLanding(from: hex) != nil
            }) else { return }
            let id = realm.world.takeID()
            realm.world.units.append(NullmereCore.Unit(id: id, kind: .spear, owner: ama, position: shore))
            realm.world.houses[ama].stock.credit(MirrorWalk.price)
            walk.unit = id
            walk.at = shore
        }
        let unitID = try XCTUnwrap(walk.unit, "A shore to stand on")
        let shore = try XCTUnwrap(walk.at)
        try await until("the company on the shore in Ama's client") { earA.world?.unit(unitID)?.position == shore }
        await MainActor.run { a.send(.walkTheMirror(unit: unitID)) }
        let begun: @MainActor @Sendable (Listener) -> Hex? = { ear in
            for event in ear.events {
                switch event {
                case .heard(let events), .watchTurned(_, let events), .answered(let events), .settled(_, let events):
                    for case let .mirrorWalkBegun(unit, _, _, to) in events where unit == unitID { return to }
                default: continue
                }
            }
            return nil
        }
        try await until("both told where the water stills") { begun(earA) != nil && begun(earB) != nil }
        let landing = try await MainActor.run { try XCTUnwrap(begun(earB)) }
        let seenByA = await MainActor.run { begun(earA) }
        XCTAssertEqual(seenByA, landing, "Each shore sees the same water still")
        let watch = await MainActor.run { earA.world?.watch ?? 0 }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        try await until("Ama's company out on the far shore") { earA.world?.unit(unitID)?.position == landing }
        let shown = await MainActor.run { earB.world?.unit(unitID)?.position }
        if let shown { XCTAssertEqual(shown, landing, "Where Bel sees it, it is where the water stilled") }
    }
}

/// Where the mirror's walk was staged, set inside the steward's reshape.
final class StagedWalk: @unchecked Sendable {
    private let lock = NSLock()
    private var values: (unit: Int?, at: Hex?) = (nil, nil)
    var unit: Int? {
        get { lock.lock(); defer { lock.unlock() }; return values.unit }
        set { lock.lock(); values.unit = newValue; lock.unlock() }
    }
    var at: Hex? {
        get { lock.lock(); defer { lock.unlock() }; return values.at }
        set { lock.lock(); values.at = newValue; lock.unlock() }
    }
}

extension RallyScene {
    /// Bel's Riders march on Ama's seat, where a third-grade Beacon stands:
    /// Ama's client is warned whose they are, how many and when they come
    /// (as Rise of Kingdoms' watchtower, of any House's march, an ally's
    /// too); Bel's client is told nothing of it.
    func heedTheBeacon(ama: Int, bel: Int) async throws {
        let staged = StagedWalk()
        await steward.reshape { realm in
            guard let index = realm.world.holds.firstIndex(where: { $0.owner == ama && $0.isSeat }) else { return }
            realm.world.holds[index].levels[.beacon] = 3
            let seat = realm.world.holds[index]
            let world = realm.world
            let seen = world.visibility(for: ama)
            let rings = (seat.sight + 1)...MarchWarning.reach(sight: seat.sight, grade: 3)
            guard let start = rings.lazy.flatMap({ seat.position.ring($0) }).first(where: { hex in
                world.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && world.unit(at: hex) == nil && world.hold(at: hex) == nil
                    && !(world.map.index(of: hex).map { seen[$0] } ?? true)
            }) else { return }
            let id = realm.world.takeID()
            var riders = NullmereCore.Unit(id: id, kind: .rider, owner: bel, position: start)
            riders.destination = seat.position
            realm.world.units.append(riders)
            staged.unit = id
            staged.at = start
        }
        let start = try XCTUnwrap(staged.at, "Open ground to march from")
        try await until("Ama warned of the march") { earA.world?.warnings?.contains { $0.from == start } == true }
        let warning = try await MainActor.run { try XCTUnwrap(earA.world?.warnings?.first { $0.from == start }) }
        XCTAssertEqual(warning.house, bel)
        XCTAssertEqual(warning.kind, .rider)
        XCTAssertNotNil(warning.troops)
        XCTAssertNotNil(warning.watches)
        let belWarned = await MainActor.run { earB.world?.warnings?.contains { $0.from == start } ?? false }
        XCTAssertFalse(belWarned, "Bel is told nothing of Ama's Beacon")
    }
}

extension RallyScene {
    /// The Still lies calm six watches; Bel's spears come to the water as
    /// the watch turns. Both clients are told the calm is broken and by
    /// whom, and see it gone from the lake; Ama's shore gives no more.
    func breakTheCalm(ama: Int, bel: Int) async throws {
        let staged = StagedWalk()
        await steward.reshape { realm in
            let world = realm.world
            guard let shore = world.map.hexes.first(where: { hex in
                world.isShore(hex) && world.map[hex]!.terrain.isPassable && world.unit(at: hex) == nil && world.hold(at: hex) == nil
            }) else { return }
            realm.world.calm = 6
            let id = realm.world.takeID()
            realm.world.units.append(NullmereCore.Unit(id: id, kind: .spear, owner: bel, position: shore))
            staged.unit = id
            staged.at = shore
        }
        _ = try XCTUnwrap(staged.unit, "A shore to stand on")
        try await until("both see the calm") { earA.world?.stillCalm == 6 && earB.world?.stillCalm == 6 }
        let broken: @MainActor @Sendable (Listener) -> [Int]? = { ear in
            for event in ear.events {
                switch event {
                case .heard(let events), .watchTurned(_, let events), .answered(let events), .settled(_, let events):
                    for case let .calmBroken(houses, calm) in events where calm == 6 { return houses }
                default: continue
                }
            }
            return nil
        }
        let watch = await MainActor.run { earA.world?.watch ?? 0 }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        try await until("both told the calm is broken") { broken(earA) != nil && broken(earB) != nil }
        let (byA, byB) = await MainActor.run { (broken(earA), broken(earB)) }
        XCTAssertEqual(byA, byB, "One lake, one telling")
        XCTAssertTrue(byA?.contains(bel) == true, "Bel's spears named")
        let calms = await MainActor.run { (earA.world?.stillCalm, earB.world?.stillCalm) }
        XCTAssertEqual(calms.0, 0)
        XCTAssertEqual(calms.1, 0)
    }
}

extension RallyScene {
    /// Warpkeep's own loop between two clients: Ama sends spears to gather
    /// a field beside them; as the watch turns both clients see them at
    /// work and the field's store fall; Ama brings them home, and both see
    /// the errand end. Bel, of another House, is refused Ama's company.
    func gatherAndBringItHome(ama: Int, bel: Int) async throws {
        let staged = StagedWalk()
        let siteBox = StagedWalk()
        await steward.reshape { realm in
            let world = realm.world
            guard let ground = world.map.hexes.first(where: { hex in
                guard world.map[hex]?.terrain.isPassable == true, world.map[hex]?.terrain.isWater == false,
                      world.unit(at: hex) == nil, world.hold(at: hex) == nil, world.site(at: hex) == nil else { return false }
                let there = hex + Hex.directions[0]
                return world.map[there].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
                    && world.unit(at: there) == nil && world.hold(at: there) == nil && world.site(at: there) == nil
            }) else { return }
            let there = ground + Hex.directions[0]
            let id = realm.world.takeID()
            realm.world.units.append(NullmereCore.Unit(id: id, kind: .spear, owner: ama, position: ground))
            let site = Site(id: realm.world.takeID(), store: .grain, level: 2, position: there, found: realm.world.watch)
            realm.world.sites = (realm.world.sites ?? []) + [site]
            realm.world.reveal(around: there, range: 2, for: ama)
            realm.world.reveal(around: there, range: 2, for: bel)
            staged.unit = id
            staged.at = there
            siteBox.unit = site.id
        }
        let unitID = try XCTUnwrap(staged.unit, "Open ground beside a field")
        let siteID = try XCTUnwrap(siteBox.unit)
        let field = try XCTUnwrap(staged.at)
        try await until("the field in both clients") { earA.world?.site(siteID) != nil && earB.world?.site(siteID) != nil }
        let full = await MainActor.run { earA.world?.site(siteID)?.remaining ?? 0 }
        // Bel may not send Ama's company.
        let belRefused = await MainActor.run { earB.world?.refusal(of: .gather(unit: unitID, site: siteID), as: bel) }
        XCTAssertEqual(belRefused, .notYours)
        await MainActor.run { a.send(.gather(unit: unitID, site: siteID)) }
        try await until("Ama's spears sent") {
            if case .gather(site: siteID)? = earA.world?.unit(unitID)?.errand { return true } else { return false }
        }
        let watch = await MainActor.run { earA.world?.watch ?? 0 }
        await MainActor.run { a.setReady(true); b.setReady(true) }
        try await until("the watch to turn") { (earA.world?.watch ?? 0) > watch && (earB.world?.watch ?? 0) > watch }
        try await until("the spears at work on the field") { earA.world?.unit(unitID)?.position == field }
        try await until("the field's store falling, in Bel's client too") {
            (earB.world?.site(siteID)?.remaining ?? full) < full && (earA.world?.site(siteID)?.remaining ?? full) < full
        }
        let seenByBel = await MainActor.run { earB.world?.unit(unitID)?.position }
        XCTAssertEqual(seenByBel, field, "Bel sees Ama's spears where they gather")
        await MainActor.run { a.send(.recall(unit: unitID)) }
        try await until("brought home: the errand ended in both clients") {
            let home: (NullmereCore.Unit?) -> Bool = { unit in
                if case .gather? = unit?.errand { return false }
                return unit != nil
            }
            return home(earA.world?.unit(unitID)) && home(earB.world?.unit(unitID))
        }
    }
}

extension RallyScene {
    /// The Words made safe, between two clients: Bel says a line, Ama
    /// reports it and is told the steward has it; the realm's steward takes
    /// it out, and both clients see it gone where it stood; barred, Bel's
    /// next line is refused by the realm.
    func makeTheWordsSafe(ama: Int, bel: Int) async throws {
        let line = "Foul words on the water \(Int.random(in: 1000...9999))"
        await MainActor.run { b.send(.say(words: line, toAlliance: false)) }
        let said: @MainActor @Sendable (Listener) -> Word? = { ear in ear.world?.wordsSaid.last { $0.text == line } }
        try await until("both hear Bel's line") { said(earA) != nil && said(earB) != nil }
        let word = try await MainActor.run { try XCTUnwrap(said(earA)) }
        await MainActor.run { a.send(.reportWord(word: word.id)) }
        try await until("Ama's report kept at the realm") {
            earA.world?.wordReports.contains { $0.word == word.id && $0.by == ama } == true
        }
        let belSees = await MainActor.run { earB.world?.wordReports.contains { $0.word == word.id } ?? false }
        XCTAssertFalse(belSees, "A report is its reporter's alone")
        let kept = await steward.state.world.wordReports.contains { $0.word == word.id && $0.by == ama }
        XCTAssertTrue(kept, "the realm's own steward has it")
        // The steward takes the line out.
        let took = await steward.obey("remove \(word.id)")
        XCTAssertEqual(took, "Took line \(word.id) out of the Words.")
        let gone: @MainActor @Sendable (Listener) -> Bool = { ear in
            ear.world?.wordsSaid.first { $0.id == word.id }?.removed == true
        }
        try await until("the line gone in both clients") { gone(earA) && gone(earB) }
        // And bars Bel's House from the Words for two watches.
        let barred = await steward.obey("bar \(bel) 2")
        XCTAssertTrue(barred.hasPrefix("Barred "), barred)
        try await until("Bel's client knows it is barred") { earB.world?.barredFromWords(bel) != nil }
        await MainActor.run { b.send(.say(words: "Let me speak", toAlliance: false)) }
        try await until("the realm refuses Bel's line") {
            earB.refusals.contains { $0.hasPrefix("You are barred from the Words") || $0.contains("barred") }
        }
        let spoke = await MainActor.run { earA.world?.wordsSaid.contains { $0.text == "Let me speak" } ?? false }
        XCTAssertFalse(spoke, "Ama never hears it")
    }
}

extension RallyScene {
    /// Ama hides Bel's House at the realm: Bel's next line never reaches
    /// Ama's client, though Bel's own client has it; let be, Ama hears Bel
    /// again.
    func hideAHouse(ama: Int, bel: Int) async throws {
        await MainActor.run { a.send(.hideHouse(house: bel, hidden: true)) }
        try await until("the realm keeps Ama's hiding") { earA.world?.hears(bel, as: ama) == false }
        let line = "Unheard by Ama \(Int.random(in: 1000...9999))"
        // Bel's bar from the Words may still stand: wait it out.
        try await until("Bel may speak") { earB.world.map { $0.barredFromWords(bel) == nil } ?? false }
        await MainActor.run { b.send(.say(words: line, toAlliance: false)) }
        try await until("Bel's own client has the line") { earB.world?.wordsSaid.contains { $0.text == line } == true }
        let heard = await MainActor.run { earA.world?.wordsSaid.contains { $0.text == line } ?? false }
        XCTAssertFalse(heard, "kept from Ama by the realm")
        await MainActor.run { a.send(.hideHouse(house: bel, hidden: false)) }
        try await until("Ama hears Bel again") { earA.world?.wordsSaid.contains { $0.text == line } == true }
    }
}

extension RallyScene {
    /// The line for a seat, kept by the realm: with every seat taken, two
    /// newcomers ask and are told their places, first and second; a seat
    /// falls free; the second, asking first, still waits, and the seat goes
    /// to the first as they ask. `newcomer` makes a fresh client.
    func waitInLine(ama: Int, bel: Int, newcomer: @MainActor () -> NetworkRealmLink) async throws {
        let filled = StagedHouses()
        // Every House a keeper's, as far as seats go.
        await steward.reshape { realm in
            // The realm takes in a few newcomers a watch; these come fresh.
            realm.newcomers = nil
            for house in realm.world.houses.indices where !realm.world.houses[house].isPlayer && !realm.world.houses[house].isEliminated {
                realm.world.houses[house].isPlayer = true
                filled.add(house)
            }
        }
        let suffix = String(KeeperIdentity.make().filter(\.isLetter).prefix(5))
        let (e, earE, f, earF) = await MainActor.run { () -> (NetworkRealmLink, Listener, NetworkRealmLink, Listener) in
            let e = newcomer(), f = newcomer()
            let earE = Listener(), earF = Listener()
            earE.listen(to: e)
            earF.listen(to: f)
            e.connect()
            f.connect()
            return (e, earE, f, earF)
        }
        try await until("the newcomers see the realm") { earE.hasStatus && earF.hasStatus }
        await MainActor.run { e.arrive(name: "Eda" + suffix) }
        try await until("the first newcomer told their place") { earE.keeper?.placeInLine == 1 }
        await MainActor.run { f.arrive(name: "Fen" + suffix) }
        try await until("the second told theirs") { earF.keeper?.placeInLine == 2 }
        // A seat falls free.
        let freed = filled.houses.first!
        await steward.reshape { realm in realm.world.houses[freed].isPlayer = false }
        // The second, asking first, still waits behind the first.
        let fAsks = await MainActor.run { earF.events.count }
        await MainActor.run { f.arrive(name: nil) }
        try await until("the second answered") { earF.events.count > fAsks && earF.lastKeeper?.placeInLine != nil }
        let fStill = await MainActor.run { (earF.lastKeeper?.house, earF.lastKeeper?.placeInLine) }
        XCTAssertNil(fStill.0, "no seat taken ahead of the first in line")
        XCTAssertEqual(fStill.1, 2)
        await MainActor.run { e.arrive(name: nil) }
        try await until("the seat goes to the first in line") { earE.lastKeeper?.house == freed }
        await MainActor.run { f.arrive(name: nil) }
        try await until("the second now first") { earF.lastKeeper?.placeInLine == 1 }
        // The scene undone: the newcomers go, the Houses filled for it freed.
        await MainActor.run { e.leave(); f.leave() }
        await steward.reshape { realm in
            for house in filled.houses where house != freed { realm.world.houses[house].isPlayer = false }
        }
    }
}

/// The Houses a scene filled, set inside the steward's reshape.
final class StagedHouses: @unchecked Sendable {
    private let lock = NSLock()
    private var list: [Int] = []
    func add(_ house: Int) { lock.lock(); list.append(house); lock.unlock() }
    var houses: [Int] { lock.lock(); defer { lock.unlock() }; return list }
}
