import Foundation
import XCTest
@testable import NullmereCore

/// What a commander remembers of the battles they led: each report names
/// the House's own commanders who led its companies there, as it was
/// filed; counsel is briefed with the latest few of them, as the report
/// reads, and the keeper may ask the commander of one; only the House's
/// own commanders free to speak are asked, on the Mac and the phone alike.
final class BattleMemoryTests: XCTestCase {
    /// A keeper's House with its first commander at the head of a spear.
    private func world() throws -> (GameState, me: Int, commander: Commander, spear: NullmereCore.Unit) {
        var world = Scene.world("battle memory")
        let me = world.player
        let commander = try XCTUnwrap(world.commanders(of: me).first)
        let spear = try XCTUnwrap(world.units(of: me).first { $0.kind == .spear })
        try world.perform(.assign(commander: commander.id, unit: spear.id), as: me)
        return (world, me, commander, try XCTUnwrap(world.unit(spear.id)))
    }

    func testAFieldsReportNamesTheHousesOwnLeadersOnce() {
        var field = Field(id: 5, at: Hex(0, 0), joined: 3, first: 0, second: 1)
        field.sides[0].append(2)
        let leaders = ["Ilsa Vane", nil, "Ilsa Vane", "Corin Hale"]
        for (index, leader) in leaders.enumerated() {
            field.fighters.append(Fighter(unit: 100 + index, owner: 0, side: 0, kind: .spear, tier: 1, leader: leader, troops: 1_000))
        }
        field.fighters.append(Fighter(unit: 200, owner: 2, side: 0, kind: .bow, tier: 1, leader: "An Ally", troops: 1_000))
        field.fighters.append(Fighter(unit: 300, owner: 1, side: 1, kind: .rider, tier: 1, leader: "The Foe", troops: 1_000))
        field.held = 0
        let state = Scene.world("field memory", houses: 3)
        XCTAssertEqual(state.report(of: field, id: 1, for: 0)?.led, ["Ilsa Vane", "Corin Hale"], "The House's own, in the order they came, each once")
        XCTAssertEqual(state.report(of: field, id: 1, for: 1)?.led, ["The Foe"], "Each House's report names its own")
        XCTAssertEqual(state.report(of: field, id: 1, for: 2)?.led, ["An Ally"])
    }

    func testABattleAHuntAndALairNameTheLeadersOfTheHousesCompanyStillStanding() throws {
        let (world, me, commander, spear) = try world()
        let foe = (me + 1) % world.houses.count
        func battle(attacking: Bool, unit: Int) -> Battle {
            Battle(attacker: attacking ? unit : 9_999, attackerOwner: attacking ? me : foe, attackerKind: .spear,
                   defender: attacking ? 9_999 : unit, defenderOwner: attacking ? foe : me, defenderKind: .rider, hold: nil,
                   at: spear.position, damageDealt: 30, damageTaken: 10, attackerFell: false, defenderFell: false)
        }
        XCTAssertEqual(world.report(of: battle(attacking: true, unit: spear.id), id: 1, for: me)?.led, [commander.name])
        XCTAssertEqual(world.report(of: battle(attacking: false, unit: spear.id), id: 2, for: me)?.led, [commander.name], "Struck, as striking")
        XCTAssertEqual(world.report(of: battle(attacking: true, unit: 77_777), id: 3, for: me)?.led, [], "A company gone names none")
        let hunt = Hunt(attacker: spear.id, attackerOwner: me, attackerKind: .spear, wild: 1, wildKind: .reavers, level: 1, at: spear.position,
                        damageDealt: 20, damageTaken: 5, attackerFell: false, wildFell: true, spoils: .zero)
        XCTAssertEqual(world.report(of: hunt, id: 4, for: me)?.led, [commander.name])
        // A second at its head is named after its leader.
        var seconded = world
        let other = Commander(id: (seconded.commanders ?? []).map(\.id).max()! + 1, name: "Corin Hale", archetype: .warden, owner: me)
        seconded.commanders?.append(other)
        seconded.units[try XCTUnwrap(seconded.unitIndex(spear.id))].second = other.id
        XCTAssertEqual(seconded.leaders(of: spear.id), [commander.name, other.name])
        XCTAssertEqual(seconded.leaders(of: nil), [])
    }

    func testCounselRemembersTheLatestBattlesTheCommanderLed() throws {
        let (world, me, commander, _) = try world()
        var field = BattleReport(id: 9, watch: 12, title: "Your side held the field, 3 companies against 2", place: "at Wenholme", outcome: .won,
                                 lines: ["Your Spears I, led by \(commander.name), slew 1,200, lost 800, and held"])
        field.sides = [BattleReport.Side(title: "Your side", houses: 1, companies: 3, troops: 9_000, lost: 1_200, fallen: 0),
                       BattleReport.Side(title: "The foe", houses: 1, companies: 2, troops: 6_000, lost: 3_100, fallen: 1)]
        field.led = [commander.name]
        var other = BattleReport(id: 8, watch: 11, title: "Your Riders struck the reavers", place: "in the field", outcome: .held, lines: [])
        other.led = ["Someone Else"]
        var scouted = BattleReport(id: 7, watch: 10, title: "Your Lanterns scouted Galstead", place: "at Galstead", outcome: .scouted, lines: [])
        scouted.led = [commander.name]
        var older: [BattleReport] = []
        for watch in [9, 8, 7] {
            var report = BattleReport(id: watch, watch: watch, title: "Your Spears struck the reavers", place: "on the barrows", outcome: .won, lines: [])
            report.led = [commander.name]
            older.append(report)
        }
        let reports = [field, other, scouted] + older
        let counsel = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: commander.id, reports: reports))
        XCTAssertEqual(counsel.battles.map(\.watch), [12, 9, 8], "Theirs, the latest first, at most three; none scouted")
        let briefing = counsel.briefing
        XCTAssertTrue(briefing.contains("Battles you led your House's companies in lately"), briefing)
        XCTAssertTrue(briefing.contains("In watch 12, at Wenholme: Your side held the field, 3 companies against 2. "
            + "Your side: 3 companies, 9,000 troops; 1,200 lost. The foe: 2 companies, 6,000 troops; 3,100 lost, 1 company fallen. "
            + "Your Spears I, led by \(commander.name), slew 1,200, lost 800, and held."), briefing)
        XCTAssertFalse(briefing.contains("watch 7,"), "No more than it remembers")
        XCTAssertFalse(briefing.contains("Galstead"))
        XCTAssertEqual(CommanderCounsel.askedOf(field), "How went the fight at Wenholme in watch 12?")
        // With no reports, no battles in the briefing; its budget still leaves room.
        let plain = try XCTUnwrap(CommanderCounsel(state: world.view(for: me), player: me, commander: commander.id))
        XCTAssertTrue(plain.battles.isEmpty)
        XCTAssertFalse(plain.briefing.contains("Battles you led"))
        XCTAssertGreaterThan(CounselBudget.recall(context: 4_096, instructions: counsel.instructions, briefing: briefing), 0)
    }

    func testOnlyTheHousesOwnCommanderFreeToSpeakIsAsked() throws {
        let (world, me, commander, _) = try world()
        var report = BattleReport(id: 1, watch: 3, title: "Your Spears struck the reavers", place: "on the barrows", outcome: .won, lines: [])
        XCTAssertNil(world.askable(of: report, by: me), "No commander named")
        report.led = [commander.name]
        XCTAssertEqual(world.askable(of: report, by: me)?.id, commander.id)
        let foe = (me + 1) % world.houses.count
        XCTAssertNil(world.askable(of: report, by: foe), "Another House's commander of the same name is not theirs to ask")
        var held = world
        held.commanders![try XCTUnwrap(held.commanderIndex(commander.id))].captive = Captivity(by: foe, since: 2, questioned: 0)
        XCTAssertNil(held.askable(of: report, by: me), "A prisoner speaks to no counsel")
        var scouting = BattleReport(id: 2, watch: 3, title: "Your Lanterns scouted Galstead", place: "at Galstead", outcome: .scouted, lines: [])
        scouting.led = [commander.name]
        XCTAssertNil(world.askable(of: scouting, by: me))
    }

    func testASideAndAnOutcomeAreSaidAlikeOnTheMacAndThePhone() {
        XCTAssertEqual(BattleReport.Side(title: "Your side", houses: 1, companies: 1, troops: 1_200, lost: 200, fallen: 0).said,
                       "Your side: 1 company, 1,200 troops; 200 lost")
        XCTAssertEqual(BattleReport.Side(title: "The foe", houses: 2, companies: 3, troops: 3_000, lost: 900, fallen: 2).said,
                       "The foe: 3 companies of 2 Houses, 3,000 troops; 900 lost, 2 companies fallen")
        XCTAssertEqual([BattleReport.Outcome.won, .lost, .held, .scouted].map(\.said), ["Won", "Lost", "Both stood", "Scouted"])
    }
}
