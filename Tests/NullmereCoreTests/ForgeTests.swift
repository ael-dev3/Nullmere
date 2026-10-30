import Foundation
import XCTest
@testable import NullmereCore

/// The Forge: the wilds, the lairs and the land's sites bring a House
/// makings; its Forge works them into gear of three sets, as fine as the
/// Forge stands high, for fewer makings the higher it stands; and the
/// pieces of a set worn together give their commander's company more.
final class ForgeTests: XCTestCase {
    private struct Stage {
        var state: GameState
        let me: Int
        let seat: Hold
        let commander: Int
    }

    /// A keeper's House with a Forge of a level at its seat, makings and
    /// moonsalt to spare.
    private func staged(_ seed: String = "the forge", forge level: Int = 1) throws -> Stage {
        var state = Scene.world(seed)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].levels[.forge] = level
        _ = state.give(makings: [.hide: 60, .iron: 60, .heartwood: 60, .moonglass: 60], to: me)
        state.houses[me].stock.moonsalt = 120
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        return Stage(state: state, me: me, seat: seat, commander: commander)
    }

    func testMakingsComeFromTheWildsTheLairsAndTheLandsSites() throws {
        var stage = try staged("makings", forge: 0)
        let me = stage.me
        XCTAssertEqual(Set(WildKind.allCases.map(Making.left(by:))), Set(Making.allCases), "Each making has its wilds")
        XCTAssertEqual(Making.left(by: .drowned), .moonglass)
        XCTAssertEqual(Making.allCases.map(\.title), ["Hide", "Iron", "Heartwood", "Moonglass"])
        XCTAssertEqual(Resource.allCases.map(Making.of), [.hide, .heartwood, .iron, .moonglass])
        // A company of the wilds struck down: a piece of its making for each of its levels.
        let spear = try XCTUnwrap(stage.state.units(of: me).first { $0.kind == .spear }).id
        let ground = try XCTUnwrap(stage.state.unit(spear)).position
        let hex = try XCTUnwrap(stage.state.freeHex(near: ground))
        let wild = stage.state.raise(.barrowkin, level: 4, at: hex)
        stage.state.wilds![stage.state.wilds!.firstIndex { $0.id == wild }!].health = 1
        let before = stage.state.makings(.iron, of: me)
        let events = try stage.state.perform(.attack(unit: spear, target: hex), as: me)
        XCTAssertTrue(events.contains(.makingsFound(house: me, making: .iron, count: 4)), "\(events)")
        XCTAssertEqual(stage.state.makings(.iron, of: me), before + 4)
        // A load brought in from the land's sites brings makings with it.
        XCTAssertEqual(GameState.makings(in: Stock(grain: 85, timber: 39, stone: 40, moonsalt: 17)), [.hide: 2, .iron: 1, .moonglass: 2])
        XCTAssertEqual(GameState.makings(in: Stock(grain: 39)), [:])
        let home = stage.seat
        let carrier = stage.state.put(.spear, of: me, at: try XCTUnwrap(stage.state.freeHex(near: home.position)))
        let index = try XCTUnwrap(stage.state.unitIndex(carrier))
        stage.state.units[index].load = Stock(stone: 80)
        stage.state.units[index].errand = .homeward
        let watch = stage.state.endWatch()
        XCTAssertTrue(watch.contains(.makingsFound(house: me, making: .iron, count: 2)), "\(watch.filter { if case .delivered = $0 { return true } else { return false } })")
        // A lair broken: three for each of its levels to each House of the host.
        let assault = LairAssault(rally: 1, caller: me, lair: 2, kind: .reavers, level: 3, at: .origin, strikes: [], before: 900,
                                  strength: 0, might: 900, shares: [.init(house: me, spoils: .zero), .init(house: 1, spoils: .zero)])
        let rewarded = stage.state.rewardLair(assault)
        XCTAssertTrue(rewarded.contains(.makingsFound(house: 1, making: .heartwood, count: 9)))
        XCTAssertEqual(stage.state.makings(.heartwood, of: 1), 9)
        // Kept up to two hundred of each.
        _ = stage.state.give(makings: [.hide: 500], to: me)
        XCTAssertEqual(stage.state.makings(.hide, of: me), GameState.makingsKept)
        XCTAssertEqual(stage.state.give(makings: [.hide: 0], to: me), [])
        XCTAssertEqual(stage.state.give(makings: [.hide: 5], to: 99), [], "No House, no makings")
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testAForgeForgesGearAsFineAsItStandsHigh() throws {
        var stage = try staged()
        let me = stage.me
        func refused(_ kind: GearKind, _ quality: GearQuality, in state: GameState? = nil) -> RuleError? {
            (state ?? stage.state).refusal(of: .forge(kind, quality: quality), as: me)
        }
        XCTAssertEqual(refused(.saltGlaive, .plain), .notForged, "What the wilds leave is not forged")
        XCTAssertEqual(refused(.wardensBlade, .fine), .needsForge(2))
        XCTAssertNil(refused(.wardensBlade, .plain))
        var bare = stage.state
        bare.holds[try XCTUnwrap(bare.holdIndex(stage.seat.id))].levels[.forge] = 0
        XCTAssertEqual(refused(.wardensBlade, .plain, in: bare), .needsForge(1), "No Forge, no gear")
        var poor = stage.state
        poor.makings = poor.makings!.filter { $0.making != .heartwood }
        XCTAssertEqual(refused(.wardensBlade, .plain, in: poor), .shortOfMakings(.heartwood, 2))
        poor.houses[me].stock.moonsalt = 1
        XCTAssertEqual(refused(.pathfindersLodestone, .plain, in: poor), .shortOf(Stock(moonsalt: 3)))
        var full = stage.state
        full.armoury = (0..<GameState.armouryLimit).map { Gear(id: 5_000 + $0, kind: .huntersEye, quality: .plain, owner: me) }
        XCTAssertEqual(refused(.wardensBlade, .plain, in: full), .armouryFull)
        // Forged: its makings and moonsalt spent, into the armoury.
        let moonsalt = stage.state.houses[me].stock.moonsalt
        let events = try stage.state.perform(.forge(.wardensBlade, quality: .plain), as: me)
        let piece = try XCTUnwrap(stage.state.gear(of: me).first { $0.kind == .wardensBlade })
        XCTAssertEqual(events, [.gearForged(house: me, gear: piece)])
        XCTAssertEqual(piece.quality, .plain)
        XCTAssertNil(piece.wornBy)
        XCTAssertEqual(stage.state.makings(.iron, of: me), 56)
        XCTAssertEqual(stage.state.makings(.heartwood, of: me), 58)
        XCTAssertEqual(stage.state.houses[me].stock.moonsalt, moonsalt - GameState.forgingMoonsalt)
        XCTAssertEqual(stage.state.tidings(of: events[0], for: me)?.text,
                       "Your smiths forge a Plain Warden's Blade, of the Warden's Harness: +2% attack, +2% defence.")
        XCTAssertNil(stage.state.tidings(of: events[0], for: 1))
        XCTAssertEqual(stage.state.tidings(of: .makingsFound(house: me, making: .iron, count: 3), for: me)?.text, "3 iron for your Forge.")
        // A higher Forge forges finer, for fewer makings.
        var high = try staged("the high forge", forge: 5)
        XCTAssertEqual(GearQuality.allCases.map(\.forgeLevel), [1, 2, 4, 5])
        XCTAssertEqual((0...5).map { GearQuality.forged(atLevel: $0) }, [nil, .plain, .fine, .fine, .masterwork, .fabled])
        XCTAssertEqual(high.state.recipe(.wardensMail, .plain, for: high.me), [.iron: 3, .hide: 1], "Two fifths fewer at the fifth level")
        XCTAssertEqual(high.state.recipe(.wardensMail, .fabled, for: high.me), [.iron: 24, .hide: 10])
        XCTAssertEqual(GameState.forgingCost(.fabled), Stock(moonsalt: 32))
        _ = try high.state.perform(.forge(.wardensMail, quality: .fabled), as: high.me)
        XCTAssertEqual(high.state.gear(of: high.me).first { $0.kind == .wardensMail }?.title, "Fabled Warden's Mail")
        XCTAssertEqual(RuleError.needsForge(4).description, "Raise a Forge to level IV to forge gear so fine.")
        XCTAssertEqual(RuleError.notForged.description, "That gear is not forged: only the wilds leave it.")
        XCTAssertEqual(RuleError.armouryFull.description, "Your armoury is full: break up a piece to make room.")
        XCTAssertEqual(RuleError.shortOfMakings(.moonglass, 3).description, "You need 3 more moonglass.")
        XCTAssertEqual(BuildingKind.forge.effect(atLevel: 1), "Forges plain gear of the three sets")
        XCTAssertEqual(BuildingKind.forge.effect(atLevel: 4), "Forges masterwork gear of the three sets, for 30% fewer makings")
        XCTAssertEqual(stage.state.problems(), [])
    }

    func testThePiecesOfASetWornTogetherGiveMore() throws {
        var stage = try staged("sets worn", forge: 1)
        let me = stage.me
        let commander = try XCTUnwrap(stage.state.commander(stage.commander))
        let plain = stage.state.edge(.defense, of: commander)
        _ = try stage.state.perform(.forge(.wardensBlade, quality: .plain), as: me)
        _ = try stage.state.perform(.forge(.wardensMail, quality: .plain), as: me)
        _ = try stage.state.perform(.forge(.wardensSeal, quality: .plain), as: me)
        _ = try stage.state.perform(.forge(.raidersSpear, quality: .plain), as: me)
        func piece(_ kind: GearKind) throws -> Int { try XCTUnwrap(stage.state.gear(of: me).first { $0.kind == kind }).id }
        _ = try stage.state.perform(.wear(gear: try piece(.wardensBlade), commander: stage.commander), as: me)
        XCTAssertEqual(stage.state.edge(.defense, of: commander), plain + 2, "One piece gives its own")
        _ = try stage.state.perform(.wear(gear: try piece(.wardensMail), commander: stage.commander), as: me)
        XCTAssertEqual(stage.state.edge(.defense, of: commander), plain + 2 + 4 + 4, "Two give the set's first gift")
        XCTAssertEqual(stage.state.edge(.garrison, of: commander) - commander.edge(.garrison), 3)
        _ = try stage.state.perform(.wear(gear: try piece(.wardensSeal), commander: stage.commander), as: me)
        XCTAssertEqual(stage.state.edge(.garrison, of: commander) - commander.edge(.garrison), 3 + 4 + 6, "All three, its second")
        XCTAssertEqual(stage.state.edge(.healing, of: commander) - commander.edge(.healing), 1 + 2)
        // Another set's piece in a slot breaks the set.
        _ = try stage.state.perform(.wear(gear: try piece(.raidersSpear), commander: stage.commander), as: me)
        XCTAssertEqual(stage.state.edge(.defense, of: commander), plain + 4 + 4, "Two of the Harness again")
        XCTAssertEqual(stage.state.edge(.attack, of: commander) - commander.edge(.attack), 4)
        XCTAssertEqual(GearSet.raider.bonus(pieces: 3), [.attack: 4, .wardDamage: 8, .moves: 1])
        XCTAssertEqual(GearSet.pathfinder.bonus(pieces: 2), [.gathering: 6, .load: 6])
        XCTAssertEqual(GearSet.warden.bonus(pieces: 1), [:])
        XCTAssertEqual(GearSet.allCases.map(\.name), ["The Warden's Harness", "The Raider's Kit", "The Pathfinder's Gear"])
        XCTAssertEqual(GearKind.forged.count, 9)
        XCTAssertTrue(GearKind.forged.allSatisfy { !$0.recipe.isEmpty && $0.set?.pieces.contains($0) == true })
        XCTAssertEqual(GearSet.allCases.map { $0.pieces.map(\.slot) }, Array(repeating: [.weapon, .armour, .charm], count: 3))
        XCTAssertEqual(Archetype.allCases.map(GearSet.suiting), [.warden, .raider, .pathfinder, .pathfinder, .raider])
        XCTAssertTrue(GearSet.allCases.allSatisfy { $0.effect.hasPrefix("two pieces: ") })
    }

    func testAStewardForgesTheSetThatSuitsItsForemostCommander() throws {
        var state = Scene.world("steward forges")
        let steward = 1
        let seat = try XCTUnwrap(state.seat(of: steward))
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].levels[.forge] = 2
        _ = state.give(makings: [.hide: 80, .iron: 80, .heartwood: 80, .moonglass: 80], to: steward)
        state.houses[steward].stock.moonsalt = 200
        let lead = try XCTUnwrap(state.commanders(of: steward).max { ($0.level, -$0.id) < ($1.level, -$1.id) })
        let set = GearSet.suiting(lead.archetype)
        let events = state.stewardTurn(for: steward)
        let forged = events.compactMap { event -> Gear? in if case .gearForged(steward, let piece) = event { return piece } else { return nil } }
        XCTAssertEqual(forged.map(\.kind), [set.pieces[0]], "\(events)")
        XCTAssertEqual(forged.first?.quality, .fine, "As fine as its Forge allows")
        XCTAssertEqual(state.gear(forged[0].id)?.wornBy, lead.id, "And worn")
        // Its next watch, the next piece.
        state.watch += 1
        let next = state.stewardTurn(for: steward).compactMap { event -> GearKind? in
            if case .gearForged(steward, let piece) = event { return piece.kind } else { return nil }
        }
        XCTAssertEqual(next, [set.pieces[1]])
        XCTAssertEqual(state.problems(), [])
    }

    func testMakingsAreTheHousesOwnToKnowAndKeptInSaves() throws {
        var stage = try staged("makings kept")
        XCTAssertEqual(stage.state.view(for: stage.me).makings(.iron, of: stage.me), 60)
        XCTAssertEqual(stage.state.view(for: 1).makings(.iron, of: stage.me), 0, "Its own to know")
        let found = GameEvent.makingsFound(house: stage.me, making: .hide, count: 2)
        XCTAssertEqual(stage.state.events([found], heardBy: stage.me), [found])
        XCTAssertEqual(stage.state.events([found], heardBy: 1), [])
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(stage.state))
        XCTAssertEqual(kept.makings(.moonglass, of: stage.me), 60)
        let older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["makings"], in: stage.state))
        XCTAssertEqual(older.makings(.moonglass, of: stage.me), 0, "Saves from before have none")
        // Makings out of true are found.
        stage.state.makings!.append(MakingStack(house: stage.me, making: .iron, count: 3))
        stage.state.makings!.append(MakingStack(house: 77, making: .hide, count: 0))
        let problems = stage.state.problems()
        for problem in ["House \(stage.me) keeps iron twice", "Makings are of no House (77)", "House 77 keeps 0 hide"] {
            XCTAssertTrue(problems.contains(problem), "\(problem) in \(problems)")
        }
    }
}
