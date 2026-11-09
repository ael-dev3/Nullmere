import Foundation
import XCTest
@testable import NullmereCore

/// The unquiet dead: a keeper's troops fallen in battle lie unburied where
/// they fell (a steward's House buries its own); left where many fell, at
/// the dark of the moon they rise as Barrowkin and stand there; a company
/// of war may bury any House's dead where it stands instead, its watch
/// spent, under a barrow that counts toward its keeper's renown.
final class BurialTests: XCTestCase {
    /// A keeper's spears on open ground beside a steward House's spears, at war.
    private func field(_ seed: String = "the unquiet dead") throws
        -> (GameState, me: Int, foe: Int, mine: NullmereCore.Unit, theirs: NullmereCore.Unit) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let foe = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        state.setStance(.war, between: me, and: foe, by: me)
        func open(_ hex: Hex) -> Bool {
            guard let terrain = state.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && !state.isOccupied(hex) && state.shrine(at: hex) == nil
                && state.holds.allSatisfy { $0.position.distance(to: hex) >= 3 }
        }
        let ground = try XCTUnwrap(state.map.hexes.first { open($0) && $0.neighbors.contains(where: open) }, "Open ground for a field")
        let beside = try XCTUnwrap(ground.neighbors.first(where: open))
        let mine = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        state.units[try XCTUnwrap(state.unitIndex(mine.id))].position = ground
        let theirs = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: foe, near: beside))
        state.units[try XCTUnwrap(state.unitIndex(theirs.id))].position = beside
        return (state, me, foe, try XCTUnwrap(state.unit(mine.id)), try XCTUnwrap(state.unit(theirs.id)))
    }

    /// A barrow keeps whose dead lie in it, and the House that raised it is
    /// given the facts for the words cut on its stone: who raised it and
    /// when, over how many, whose dead they are and where they fell; never
    /// another House. Each barrow has its own key.
    func testABarrowsStoneIsGivenItsDeadAndWhereTheyFell() throws {
        var (state, me, foe, mine, _) = try field("the stone's words")
        state.layTheFallen(3_000, of: me, at: mine.position)
        state.houses[foe].isPlayer = true
        state.layTheFallen(1_200, of: foe, at: mine.position)
        _ = try state.perform(.bury(unit: mine.id), as: me)
        let grave = try XCTUnwrap(state.grave(at: mine.position))
        XCTAssertEqual(grave.dead, [me, foe], "whose dead lie in it, in the order they fell")
        XCTAssertEqual(grave.troops, 4_200)
        let moment = try XCTUnwrap(state.voiced(grave, for: me))
        XCTAssertEqual(moment.task, Voicing.graveTask)
        XCTAssertEqual(moment.facts, [
            "\(state.houses[me].title) raised this barrow in watch \(state.watch) over \(GameState.counted(4_200)) troops.",
            "The dead are of \(listed([state.houses[me].title, state.houses[foe].title])).",
            "They fell \(state.placeName(of: mine.position)).",
        ])
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.graveTask))
        XCTAssertNil(state.voiced(grave, for: foe), "another House's barrow is not theirs to word")
        // A barrow from before whose dead were kept is the House's own.
        let older = Grave(at: Hex(2, -3), troops: 500, house: me, watch: 4)
        XCTAssertEqual(state.voiced(older, for: me)?.facts[1], "The dead are of \(state.houses[me].title).")
        // Each its own key: by where and when, never below nought.
        XCTAssertNotEqual(older.key, grave.key)
        XCTAssertNotEqual(Grave(at: Hex(2, -3), troops: 500, house: me, watch: 5).key, older.key)
        XCTAssertNotEqual(Grave(at: Hex(-2, 3), troops: 500, house: me, watch: 4).key, older.key)
        XCTAssertGreaterThanOrEqual(Grave(at: Hex(-999, -999), troops: 1, house: me, watch: 0).key, 0)
        // Kept through the realm as it is told.
        let decoded = try JSONDecoder().decode(Grave.self, from: try JSONEncoder().encode(grave))
        XCTAssertEqual(decoded, grave)
        let bare = try JSONDecoder().decode(Grave.self, from: Data(#"{"at":{"q":1,"r":2},"troops":9,"house":0,"watch":3}"#.utf8))
        XCTAssertNil(bare.dead, "a barrow kept before its dead were")
    }

    /// The watch before the next dark of the moon after `watch`.
    private func eveOfTheDark(after watch: Int) -> Int {
        var at = watch + 1
        while GameState.moonAge(at: at + 1) != GameState.dreamingMoon { at += 1 }
        return at
    }

    func testAKeepersDeadLieWhereTheyFellAndAStewardsHouseBuriesItsOwn() throws {
        var (state, me, foe, mine, theirs) = try field()
        XCTAssertTrue(state.houses[me].isPlayer)
        XCTAssertFalse(state.houses[foe].isPlayer)
        let mineBefore = state.troops(of: mine), theirsBefore = state.troops(of: theirs)
        let events = try state.perform(.attack(unit: mine.id, target: theirs.position), as: me)
        let battle = try XCTUnwrap(events.compactMap { event -> Battle? in if case .battle(let b) = event { return b } else { return nil } }.first)
        let lost = try XCTUnwrap(battle.lost), slain = try XCTUnwrap(battle.slain)
        XCTAssertEqual(lost, mineBefore - (state.unit(mine.id).map(state.troops(of:)) ?? 0))
        XCTAssertEqual(slain, theirsBefore - (state.unit(theirs.id).map(state.troops(of:)) ?? 0))
        XCTAssertGreaterThan(lost, 0, "the blow struck back cost the keeper troops")
        // The keeper's dead lie where the keeper's company stood; the steward's
        // House's, where it struck them, are buried as they fell.
        let field = try XCTUnwrap(state.fieldOfDead(at: mine.position))
        XCTAssertEqual(field.troops, lost)
        XCTAssertEqual(field.houses, [me])
        XCTAssertEqual(field.since, state.watch)
        XCTAssertNil(state.fieldOfDead(at: theirs.position))
        // More falling there adds to them; another House's dead there are its too.
        state.layTheFallen(400, of: me, at: mine.position)
        XCTAssertEqual(state.fieldOfDead(at: mine.position)?.troops, lost + 400)
        state.layTheFallen(0, of: me, at: theirs.position)
        state.layTheFallen(300, of: foe, at: theirs.position)
        XCTAssertNil(state.fieldOfDead(at: theirs.position), "none fallen, or a steward's, lie nowhere")
    }

    func testAtTheDarkOfTheMoonTheUnburiedRiseWhereManyFellAndTheLandTakesTheRest() throws {
        var (state, me, foe, mine, theirs) = try field("the dark of the moon")
        let many = mine.position, few = theirs.position
        state.layTheFallen(GameState.unquietAt + GameState.unquietPerLevel + 500, of: me, at: many)
        state.layTheFallen(GameState.unquietAt - 1, of: me, at: few)
        // Not before the dark of the moon.
        state.watch = eveOfTheDark(after: state.watch) - 1
        XCTAssertEqual(state.raiseTheUnquiet(), [])
        XCTAssertEqual(state.fieldsOfDead.count, 2)
        state.watch += 1
        XCTAssertEqual(state.watchesToTheDark(from: state.watch), 1)
        state.watch += 1
        XCTAssertEqual(state.watchesToTheDark(from: state.watch), 0)
        let wildsBefore = state.wildsStanding.count
        let events = state.raiseTheUnquiet()
        XCTAssertEqual(events.count, 1, "where many fell, and only there")
        guard case .unquietRose(let field, let wildID, let at, let level) = events[0] else { return XCTFail("\(events)") }
        XCTAssertEqual(field.at, many)
        XCTAssertEqual(level, 2, "a level past the first for each four thousand past six")
        let risen = try XCTUnwrap(state.wild(wildID))
        XCTAssertEqual(risen.kind, .barrowkin)
        XCTAssertEqual(risen.level, 2)
        XCTAssertEqual(risen.position, at)
        XCTAssertLessThanOrEqual(at.distance(to: many), 2, "on the field or the nearest open ground")
        XCTAssertEqual(state.wildsStanding.count, wildsBefore + 1)
        XCTAssertTrue(state.fieldsOfDead.isEmpty, "the land takes back the rest")
        XCTAssertNil(state.unburied)
        XCTAssertTrue(state.chronicle.last?.text.contains("rise, \(GameState.counted(field.troops)) troops, and stand there as Barrowkin") == true)
        // Told to the Houses whose dead they were and whoever sees it.
        XCTAssertEqual(state.events(events, heardBy: me).count, 1)
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.hasPrefix("At the dark of the moon your dead left unburied"), told)
        XCTAssertTrue(told.contains("Barrowkin of the second level stand"), told)
        _ = foe
        // Once more, a month on: none lie, none rise.
        state.watch += GameState.lunarMonth
        XCTAssertEqual(state.raiseTheUnquiet(), [])
    }

    func testACompanyBuriesTheDeadWhereItStandsUnderABarrow() throws {
        var (state, me, foe, mine, theirs) = try field("a barrow raised")
        state.layTheFallen(GameState.unquietAt + 2_000, of: me, at: mine.position)
        // Refused: another House's company, a company that isn't of war, none
        // lying where it stands, one that has struck this watch.
        XCTAssertEqual(state.burialRefusal(by: theirs.id, as: me), .notYours)
        XCTAssertEqual(state.burialRefusal(by: theirs.id, as: foe), .noDeadHere)
        let lantern = try XCTUnwrap(state.placeUnit(.lantern, tier: 1, for: me, near: mine.position))
        state.units[try XCTUnwrap(state.unitIndex(lantern.id))].position = mine.position
        XCTAssertEqual(state.burialRefusal(by: lantern.id, as: me), .cannotFight)
        var struck = state
        struck.units[try XCTUnwrap(struck.unitIndex(mine.id))].acted = true
        XCTAssertEqual(struck.burialRefusal(by: mine.id, as: me), .spentThisWatch)
        XCTAssertEqual(RuleError.noDeadHere.description, "No dead lie unburied where that company stands.")
        XCTAssertEqual(state.burialRefusal(by: 987_654, as: me), .unknownUnit)
        XCTAssertNil(state.burialRefusal(by: mine.id, as: me))
        // Buried: its watch spent, the dead under a barrow, the House honoured.
        let field = try XCTUnwrap(state.fieldOfDead(at: mine.position))
        let events = try state.perform(.bury(unit: mine.id), as: me)
        XCTAssertEqual(events, [.buried(field, by: me)])
        let after = try XCTUnwrap(state.unit(mine.id))
        XCTAssertTrue(after.acted)
        XCTAssertEqual(after.movesLeft, 0)
        XCTAssertNil(state.fieldOfDead(at: mine.position))
        XCTAssertEqual(state.gravesRaised, [Grave(at: mine.position, troops: field.troops, house: me, watch: state.watch, dead: field.houses)])
        XCTAssertEqual(state.houses[me].buried, 1)
        XCTAssertEqual(state.burialsCounted(of: me), 1)
        XCTAssertTrue(state.chronicle.last?.text.hasSuffix("buries the dead \(state.placeName(of: mine.position)), \(GameState.counted(field.troops)) troops, under a barrow.") == true)
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.hasPrefix("Your company buries the dead"), told)
        // They rise no more at the dark of the moon.
        state.watch = eveOfTheDark(after: state.watch) + 1
        XCTAssertEqual(state.raiseTheUnquiet(), [])
        XCTAssertThrowsError(try state.perform(.bury(unit: mine.id), as: me))
    }

    func testAnyHousesDeadMayBeBuriedAndAtMostFiveCountTowardRenown() throws {
        var (state, me, foe, mine, theirs) = try field("the foe's dead")
        // The steward's company buries the keeper's dead where it stands.
        state.layTheFallen(800, of: me, at: theirs.position)
        let events = try state.perform(.bury(unit: theirs.id), as: foe)
        guard case .buried(let field, let by) = try XCTUnwrap(events.first) else { return XCTFail("\(events)") }
        XCTAssertEqual(by, foe)
        XCTAssertEqual(field.houses, [me])
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.contains("buries your dead "), told)
        XCTAssertEqual(state.events(events, heardBy: me).count, 1, "the House whose dead they were is told")
        // Seven fields buried, five count.
        for count in 0..<7 {
            state.units[try XCTUnwrap(state.unitIndex(mine.id))].acted = false
            state.layTheFallen(100 + count, of: me, at: mine.position)
            _ = try state.perform(.bury(unit: mine.id), as: me)
        }
        XCTAssertEqual(state.houses[me].buried, 7)
        XCTAssertEqual(state.burialsCounted(of: me), GameState.burialsThatCount)
        XCTAssertEqual(state.burialsCounted(of: 99), 0)
        XCTAssertEqual(state.gravesRaised.count, 8)
        XCTAssertTrue(GameState.burialSaid.contains("rise as Barrowkin"))
    }

    func testTheCaretakerOfAKeeperAwayBuriesTheDeadWhereItsCompaniesStandIdle() throws {
        var state = GameState(settings: GameSettings(seedText: "kept while away", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        // A company of war at home in its seat, idle, where the House's dead lie.
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary })
        state.units[try XCTUnwrap(state.unitIndex(company.id))].position = seat
        let home = try XCTUnwrap(state.unit(company.id))
        state.layTheFallen(3_000, of: me, at: home.position)
        let events = state.stewardTurn(for: me, caretaking: true)
        let after = try XCTUnwrap(state.unit(home.id))
        if after.position == home.position, after.movesLeft == state.movement(of: after) || after.acted {
            XCTAssertTrue(events.contains { if case .buried(_, let by) = $0 { return by == me } else { return false } }, "\(events)")
            XCTAssertNil(state.fieldOfDead(at: home.position))
        } else {
            XCTAssertNotNil(state.fieldOfDead(at: home.position), "sent on, it leaves them for another")
        }
        XCTAssertEqual(state.houses[me].buried ?? 0, state.gravesRaised.count)
    }

    func testTheViewsShowTheDeadToTheirHouseAndWhoeverSeesTheField() throws {
        var (state, me, foe, mine, _) = try field("seen and unseen")
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me && $0.id != foe }).id
        // Far from every House's sight but the keeper's own company.
        state.layTheFallen(5_000, of: me, at: mine.position)
        XCTAssertEqual(state.view(for: me).fieldOfDead(at: mine.position)?.troops, 5_000, "its own dead, a House always knows")
        let seen = state.visibility(for: other)
        let sees = state.map.index(of: mine.position).map { seen[$0] } ?? false
        XCTAssertEqual(state.view(for: other).fieldOfDead(at: mine.position) != nil, sees, "another House, where it sees the field")
        // The barrow over them, on ground a House has seen.
        _ = try state.perform(.bury(unit: mine.id), as: me)
        XCTAssertEqual(state.view(for: me).gravesRaised.count, 1, "its own barrow, a House always knows")
        let explored = state.isExplored(mine.position, by: other)
        XCTAssertEqual(state.view(for: other).gravesRaised.count, explored ? 1 : 0, "another's, on ground it has seen")
        // Carried in the realm's parts like the rest of the world.
        var round = state
        round.unburied = [FieldOfDead(at: mine.position, troops: 1_234, houses: [me], since: 3)]
        let data = try JSONEncoder().encode(round)
        let back = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(back.fieldsOfDead, round.fieldsOfDead)
        XCTAssertEqual(back.gravesRaised, round.gravesRaised)
    }
}
