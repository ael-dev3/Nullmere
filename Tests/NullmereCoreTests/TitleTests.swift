import Foundation
import XCTest
@testable import NullmereCore

/// Titles of the Spire: the keeper whose House holds the broken Spire names
/// other Houses to the realm's titles, boons and slights, each borne by one
/// House at a time and resting three watches between namings; they lapse
/// when the Spire passes. Stewards name none.
final class TitleTests: XCTestCase {
    /// A realm whose keeper's House holds the broken Spire.
    private func spireHeld(_ seed: String = "titles") throws -> (state: GameState, me: Int, others: [Int]) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 5, radius: 18, keepers: 1))
        let me = state.player
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.hold(at: hex) == nil
        })
        state.shrines = (state.shrines ?? []) + [Shrine(id: 99, kind: .brokenSpire, position: ground, holder: me, since: state.watch)]
        return (state, me, state.livingHouses.map(\.id).filter { $0 != me })
    }

    func testTheSpiresKeeperNamesTheRealmsTitles() throws {
        var (state, me, others) = try spireHeld()
        XCTAssertEqual(state.titleGiver, me)
        XCTAssertEqual(Title.allCases.filter(\.isBoon).count, 4)
        XCTAssertEqual(Title.allCases.filter { !$0.isBoon }.count, 3)
        XCTAssertEqual(state.bestowRefusal(.swordOfTheLake, on: me, as: me), .notApplicable, "Not on itself")
        XCTAssertEqual(state.bestowRefusal(.swordOfTheLake, on: others[0], as: others[1]), .notTheSpiresHolder)

        // A boon: the House named strikes harder.
        let spear = try XCTUnwrap(state.units(of: others[0]).first { $0.kind.isMilitary })
        let before = state.attackPercent(of: spear)
        let events = try state.perform(.bestow(.swordOfTheLake, on: others[0]), as: me)
        XCTAssertEqual(events, [.titleBestowed(title: .swordOfTheLake, house: others[0], by: me)])
        XCTAssertEqual(state.title(of: others[0]), Bestowal(title: .swordOfTheLake, house: others[0], by: me, watch: state.watch))
        XCTAssertEqual(state.titleBonus(.attack(.spear), for: others[0]), 5)
        XCTAssertGreaterThan(state.attackPercent(of: spear), before)
        XCTAssertEqual(state.bestowRefusal(.swordOfTheLake, on: others[0], as: me), .notApplicable, "Borne already")
        XCTAssertEqual(state.chronicle.last?.kind, .title)

        // Each title rests three watches before it is named anew; a House
        // named to another title lays down the first.
        XCTAssertEqual(state.bestowRefusal(.swordOfTheLake, on: others[1], as: me), .titleResting(until: state.watch + GameState.titleRest))
        _ = try state.perform(.bestow(.oathbreaker, on: others[0]), as: me)
        XCTAssertEqual(state.title(of: others[0])?.title, .oathbreaker)
        XCTAssertEqual(state.titlesBorne.count, 1, "One title a House")
        XCTAssertEqual(state.titleBonus(.defense(.spear), for: others[0]), -5, "A slight")
        XCTAssertEqual(state.titleBonus(.attack(.spear), for: others[0]), 0)
        state.watch += GameState.titleRest
        _ = try state.perform(.bestow(.oathbreaker, on: others[1]), as: me)
        XCTAssertNil(state.title(of: others[0]), "Whoever bore it before bears it no more")
        let plain = state.bonus(.gathering, for: others[3])
        _ = try state.perform(.bestow(.granaryWarden, on: others[2]), as: me)
        _ = try state.perform(.bestow(.shoreBeggar, on: others[3]), as: me)
        XCTAssertEqual(state.titleBonus(.gathering, for: others[2]), 10)
        XCTAssertEqual(state.titleBonus(.gathering, for: others[3]), -10)
        XCTAssertEqual(state.bonus(.gathering, for: others[3]), plain - 10, "Gathered less")

        // Told to the realm: to the House named, its namer and the rest.
        let named = GameEvent.titleBestowed(title: .shoreBeggar, house: others[3], by: me)
        XCTAssertEqual(state.tidings(of: named, for: others[3])?.tone, .bad)
        XCTAssertTrue(state.tidings(of: named, for: others[3])?.text.contains("names your House Beggar of the Shore") == true)
        XCTAssertTrue(state.tidings(of: named, for: me)?.text.hasPrefix("You name ") == true)
        XCTAssertEqual(state.tidings(of: named, for: others[0])?.tone, .neutral)
        XCTAssertTrue(state.events([named], heardBy: others[0]).contains(named), "Heard by every House")

        // Kept with the world, and in every House's view.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.bestowals, state.bestowals)
        XCTAssertEqual(state.view(for: others[0]).bestowals, state.bestowals)
    }

    /// The Spire passing to another, every title its keeper named lapses,
    /// each House told what it bore no more.
    func testTheTitlesLapseWhenTheSpirePasses() throws {
        var (state, me, others) = try spireHeld("lapsed titles")
        _ = try state.perform(.bestow(.masterMason, on: others[0]), as: me)
        _ = try state.perform(.bestow(.craven, on: others[1]), as: me)
        let named = state.titlesBorne
        XCTAssertEqual(state.keepTitles(), [], "Still the Spire's keeper's")

        let spire = try XCTUnwrap(state.shrines?.firstIndex { $0.kind == .brokenSpire })
        state.shrines![spire].holder = others[2]
        XCTAssertNil(state.titleGiver, "A steward's House names none")
        let events = state.keepTitles()
        XCTAssertEqual(events, [.titlesLapsed(by: me, titles: named)])
        XCTAssertNil(state.bestowals)
        XCTAssertEqual(state.chronicle.last?.kind, .title)
        let lapsed = try XCTUnwrap(events.first)
        XCTAssertEqual(state.tidings(of: lapsed, for: me)?.tone, .bad)
        XCTAssertEqual(state.tidings(of: lapsed, for: others[0])?.text, "Your House is Master Mason no more: the title lapses with the broken Spire.")
        XCTAssertEqual(state.tidings(of: lapsed, for: others[1])?.tone, .good, "A slight lifted")
        XCTAssertTrue(state.tidings(of: lapsed, for: others[3])?.text.hasPrefix("The titles ") == true)
        XCTAssertEqual(state.bestowRefusal(.masterMason, on: others[0], as: me), .notTheSpiresHolder)

        // As the watch turns, too.
        state.shrines![spire].holder = me
        _ = try state.perform(.bestow(.sageOfTheStill, on: others[0]), as: me)
        state.shrines![spire].holder = nil
        XCTAssertTrue(state.endWatch().contains { if case .titlesLapsed = $0 { return true } else { return false } })
        XCTAssertTrue(state.titlesBorne.isEmpty)
    }

    /// Stewards name no titles, so a world of stewards goes as it always did.
    func testStewardsNameNone() throws {
        var state = GameState(settings: GameSettings(seedText: "stewards' titles", houseCount: 5, radius: 18))
        let ground = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain.isPassable == true && state.hold(at: $0) == nil })
        state.shrines = (state.shrines ?? []) + [Shrine(id: 99, kind: .brokenSpire, position: ground, holder: 0, since: 1)]
        XCTAssertNil(state.titleGiver)
        for _ in 0..<20 { _ = state.endWatch() }
        XCTAssertNil(state.bestowals)
        XCTAssertEqual(Title.sageOfTheStill.effect, "every study done 10% sooner")
        XCTAssertEqual(Title.swordOfTheLake.title, "Sword of the Lake")
    }
}
