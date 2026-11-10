import Foundation
import XCTest
@testable import NullmereCore

/// A commander's word as the keeper turns to the company they lead, for a
/// device's own model to give: only what the House knows of the company,
/// where it stands, what it is about and what lies near, and the fight the
/// commander led lately; asked afresh each watch and at each new order, but
/// not at each pace of a march; never an order of their own.
final class CommanderWordTests: XCTestCase {
    /// A keeper's House with its first commander leading a spear at its
    /// seat, and the keeper's own view of it.
    private func leading(_ seed: String = "a commander's word") throws -> (world: GameState, me: Int, commander: Int, spear: Int) {
        var world = Scene.world(seed)
        let me = world.player
        let commander = try XCTUnwrap(world.commanders(of: me).first).id
        let seat = try XCTUnwrap(world.seat(of: me))
        let spear = try XCTUnwrap(world.units(of: me).first { $0.kind == .spear })
        if let there = world.unit(at: seat.position), let other = world.unitIndex(there.id) {
            world.units[other].position = spear.position
        }
        world.units[try XCTUnwrap(world.unitIndex(spear.id))].position = seat.position
        try world.perform(.assign(commander: commander, unit: spear.id), as: me)
        return (world, me, commander, spear.id)
    }

    private func counsel(_ world: GameState, _ me: Int, _ commander: Int, reports: [BattleReport] = []) throws -> CommanderCounsel {
        try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: commander, reports: reports))
    }

    func testTheCommanderTellsTheirCompanyAsTheHouseKnowsIt() throws {
        let (world, me, id, spear) = try leading()
        let counsel = try counsel(world, me, id)
        let word = try XCTUnwrap(counsel.word)
        let view = counsel.state
        let commander = counsel.commander
        let unit = try XCTUnwrap(view.unit(spear))
        let handle = try XCTUnwrap(counsel.handle(of: unit))
        XCTAssertEqual(word.task, Voicing.commanderTask)
        let first = try XCTUnwrap(word.facts.first)
        XCTAssertTrue(first.hasPrefix("\(commander.name), \(commander.archetype.named) of level \(commander.level), leads \(handle) of "
                                      + "\(view.houses[me].title): "), first)
        XCTAssertTrue(first.contains("\(GameState.counted(view.troops(of: unit))) troops"), "its troops, counted as every line counts them")
        XCTAssertTrue(word.facts.contains("The company stands \(view.placeName(of: unit.position))."))
        // What lies near, as counsel's look tells it, the nearest few.
        let near = counsel.seen(about: unit, within: CommanderCounsel.wordLooks).prefix(CommanderCounsel.wordTells)
        let told = near.isEmpty ? "Near it the House sees nothing but the land." : "Near it the House sees: " + near.joined(separator: "; ") + "."
        XCTAssertTrue(word.facts.contains(told), word.facts.joined(separator: "\n"))
        XCTAssertFalse(word.facts.contains { $0.hasPrefix("In watch") }, "no fight led, none told")
        XCTAssertTrue(word.prompt.hasPrefix(Voicing.commanderTask))
        XCTAssertTrue(Voicing.commanderTask.contains("Propose nothing and promise nothing"), "a word, never an order")
        XCTAssertTrue(Voicing.commanderTask.contains("keeping every name and number as given"))
    }

    func testWhatLiesNearIsWhatTheHouseSeesAndNoMore() throws {
        var (world, me, id, spear) = try leading()
        let unit = try XCTUnwrap(world.unit(spear))
        // A company of another House on a tile beside the commander's.
        let other = (me + 1) % world.houses.count
        let foreign = try XCTUnwrap(world.units(of: other).first)
        let beside = try XCTUnwrap(unit.position.neighbors.first { world.map[$0].map { !$0.terrain.isWater } ?? false })
        world.units[try XCTUnwrap(world.unitIndex(foreign.id))].position = beside
        let counsel = try counsel(world, me, id)
        let word = try XCTUnwrap(counsel.word)
        let near = try XCTUnwrap(word.facts.first { $0.hasPrefix("Near it the House sees: ") })
        XCTAssertTrue(near.contains("\(world.houses[other].title)'s"), near)
        XCTAssertTrue(near.contains(GameState.waySaid(to: beside, from: unit.position)), "which way and how far, as every line says it")
        XCTAssertLessThanOrEqual(near.components(separatedBy: "; ").count, CommanderCounsel.wordTells, "the nearest few alone")
        // Counsel's look still tells as it did.
        XCTAssertTrue(counsel.lookAround(within: 1).contains("\(world.houses[other].title)'s"))
    }

    func testAWordIsAskedAfreshEachWatchAndAtANewOrderButNotAtEachPace() throws {
        var (world, me, id, spear) = try leading()
        let key = try XCTUnwrap(try counsel(world, me, id).wordKey)
        XCTAssertEqual(try counsel(world, me, id).wordKey, key, "the same company as it was, the same word")
        XCTAssertEqual(CommanderCounsel.commander(ofWord: key), id)
        let index = try XCTUnwrap(world.unitIndex(spear))
        let start = world.units[index].position
        // A march ordered: a fresh word.
        let far = try XCTUnwrap(world.map.hexes.first { $0.distance(to: start) == 4 && !(world.map[$0]?.terrain.isWater ?? true) })
        world.units[index].destination = far
        let marching = try XCTUnwrap(try counsel(world, me, id).wordKey)
        XCTAssertNotEqual(marching, key, "a new order calls afresh")
        // A pace along it: the same word.
        world.units[index].position = try XCTUnwrap(start.neighbors.min { $0.distance(to: far) < $1.distance(to: far) })
        XCTAssertEqual(try counsel(world, me, id).wordKey, marching, "not at each pace of the march")
        // Dug in instead: a fresh word.
        world.units[index].destination = nil
        world.units[index].fortified = true
        let dug = try XCTUnwrap(try counsel(world, me, id).wordKey)
        XCTAssertNotEqual(dug, marching)
        // Its strength fallen by a quarter: a fresh word.
        world.units[index].health = 40
        XCTAssertNotEqual(try counsel(world, me, id).wordKey, dug, "its fortunes changed, a fresh word")
        // A new watch: a fresh word.
        let hurt = try XCTUnwrap(try counsel(world, me, id).wordKey)
        world.watch += 1
        let next = try XCTUnwrap(try counsel(world, me, id).wordKey)
        XCTAssertNotEqual(next, hurt, "each watch its word")
        XCTAssertEqual(CommanderCounsel.commander(ofWord: next), id)
    }

    func testOnlyACommanderAtACompanysHeadHasAWord() throws {
        var (world, me, id, spear) = try leading()
        let index = try XCTUnwrap(world.unitIndex(spear))
        // Second at its head, not leading: no word of theirs.
        world.units[index].leader = nil
        world.units[index].second = id
        let second = try counsel(world, me, id)
        XCTAssertNil(second.word)
        XCTAssertNil(second.wordKey)
        // Leading none: no word.
        world.units[index].second = nil
        let idle = try counsel(world, me, id)
        XCTAssertNil(idle.company)
        XCTAssertNil(idle.word)
        XCTAssertNil(idle.wordKey)
    }

    func testAFightLedLatelyIsToldAndAnOldOneIsNot() throws {
        var (world, me, id, _) = try leading()
        world.watch = max(world.watch, 10)
        let name = try XCTUnwrap(world.commander(id)).name
        var lately = BattleReport(id: 1, watch: world.watch - 1, title: "Your Spears struck Dravic's Archers", place: "at Wenholme",
                                  outcome: .won, lines: [])
        lately.led = [name]
        let told = try XCTUnwrap(try counsel(world, me, id, reports: [lately]).word)
        XCTAssertTrue(told.facts.contains("In watch \(world.watch - 1) \(name) led the fight at Wenholme: Your Spears struck Dravic's Archers. Won."),
                      told.facts.joined(separator: "\n"))
        var long = lately
        long = BattleReport(id: 2, watch: world.watch - CommanderCounsel.wordRemembers - 1, title: lately.title, place: lately.place,
                            outcome: .lost, lines: [])
        long.led = [name]
        let old = try XCTUnwrap(try counsel(world, me, id, reports: [long]).word)
        XCTAssertFalse(old.facts.contains { $0.hasPrefix("In watch") }, "an old fight is not told in a word")
        // Another commander's fight is not theirs to tell.
        var others = lately
        others.led = ["Someone Else"]
        XCTAssertFalse(try XCTUnwrap(try counsel(world, me, id, reports: [others]).word).facts.contains { $0.hasPrefix("In watch") })
    }

    func testWhatTheCompanyIsAboutIsTold() throws {
        var (world, me, id, spear) = try leading()
        let index = try XCTUnwrap(world.unitIndex(spear))
        let ally = try XCTUnwrap(world.holds.first { $0.owner != me })
        world.units[index].errand = .reinforce(hold: ally.id)
        let word = try XCTUnwrap(try counsel(world, me, id).word)
        XCTAssertTrue(word.facts.contains("It keeps the gates of \(ally.name)."), word.facts.joined(separator: "\n"))
        XCTAssertEqual(word.facts.filter { $0.hasPrefix("It keeps") }.count, 1)
    }
}
