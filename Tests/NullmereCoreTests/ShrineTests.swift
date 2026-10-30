import Foundation
import XCTest
@testable import NullmereCore

/// The lake's holy sites: found as the world is made, far from the holds
/// and from each other; held by the House whose company of war stands on
/// one as the watch turns with no foe beside it; and what each gives, it
/// gives its holder's whole side.
final class ShrineTests: XCTestCase {
    func testHolySitesAreFoundFarFromTheHoldsAndEachOther() throws {
        let state = GameState(settings: GameSettings(seedText: "holy sites", houseCount: 12, radius: 36, keepers: 0))
        XCTAssertEqual(state.holySites.count, 6, "One for every two seats")
        XCTAssertEqual(state.holySites.map(\.id), Array(1...6))
        XCTAssertEqual(Set(state.holySites.map(\.kind)), Set(ShrineKind.allCases))
        for shrine in state.holySites {
            XCTAssertTrue(state.holds.allSatisfy { $0.position.distance(to: shrine.position) >= GameState.shrinesFromHolds })
            XCTAssertTrue(state.holySites.allSatisfy { $0.id == shrine.id || $0.position.distance(to: shrine.position) >= GameState.shrinesApart })
            XCTAssertEqual(state.map[shrine.position]?.terrain.isPassable, true)
            XCTAssertNil(shrine.holder)
        }
        XCTAssertEqual(state, GameState(settings: state.settings), "The same words, the same holy sites")
        XCTAssertEqual(GameState(settings: GameSettings(seedText: "a small lake", houseCount: 3, radius: 16, keepers: 1)).holySites.count, 2,
                       "Two at least")
        XCTAssertEqual(ShrineKind.allCases.map(\.title), ["Moonwell", "Still Stone", "Salt Altar"])
    }

    func testAShrineIsTakenByStandingOnItAndGivesItsHoldersSide() throws {
        var state = Scene.world("taken shrine", houses: 4, radius: 18)
        let me = state.player
        // Every House of one people, whose strengths touch no company's arms.
        for house in state.houses.indices { state.houses[house].heritage = .strandfolk }
        let shrine = try XCTUnwrap(state.holySites.first { $0.kind == .moonwell })
        let attack = state.bonus(.attack(.spear), for: me)
        // A company stands on it as the watch turns: it is taken.
        let spear = state.put(.spear, of: me, at: shrine.position)
        let events = state.holdShrines()
        XCTAssertEqual(events, [.shrineTaken(shrine: shrine.id, house: me, from: nil)])
        XCTAssertEqual(state.holySites.first { $0.id == shrine.id }?.holder, me)
        XCTAssertEqual(state.bonus(.attack(.spear), for: me), attack + 8, "Its gift to its holder")
        XCTAssertEqual(state.bonus(.attack(.rider), for: me), state.bonus(.attack(.rider), for: 3) + 8 - state.shrineBonus(.attack(.rider), for: 3))
        XCTAssertEqual(state.bonus(.defense(.spear), for: me) - state.houses[me].research.total(.defense(.spear)), 0, "Not what it doesn't give")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "Your company takes the Moonwell: +8% attack to every company of its holders' side.")
        XCTAssertEqual(state.tidings(of: events[0], for: 2)?.text, "\(state.houses[me].title) takes the Moonwell.")
        XCTAssertEqual(state.events(events, heardBy: 2), events, "Heard by all")
        XCTAssertEqual(state.holdShrines(), [], "Held already: nothing new")

        // An ally shares the gift.
        _ = try state.perform(.foundAlliance(name: "The Still Oath"), as: me)
        state.houses[1].isPlayer = true
        _ = try state.perform(.inviteToAlliance(house: 1), as: me)
        _ = try state.perform(.answerInvitation(alliance: try XCTUnwrap(state.alliance(of: me)).id, accept: true), as: 1)
        XCTAssertEqual(state.shrineBonus(.attack(.bow), for: 1), 8)
        XCTAssertEqual(state.tidings(of: events[0], for: 1)?.text,
                       "\(state.houses[me].title), your ally, takes the Moonwell: +8% attack to every company of its holders' side.")

        // A foe at war beside it keeps another from taking it; alone, it takes it.
        state.units.removeAll { $0.id == spear }
        _ = try state.declareWar(by: 2, on: me)
        let theirs = state.put(.spear, of: 2, at: shrine.position)
        let beside = try XCTUnwrap(state.freeHex(near: shrine.position))
        let guardian = state.put(.bow, of: me, at: beside)
        XCTAssertEqual(state.holdShrines(), [], "Contested: it stays as it is")
        state.units.removeAll { $0.id == guardian }
        let taken = state.holdShrines()
        XCTAssertEqual(taken, [.shrineTaken(shrine: shrine.id, house: 2, from: me)])
        XCTAssertEqual(state.tidings(of: taken[0], for: me)?.text, "\(state.houses[2].title) takes the Moonwell from you.")
        XCTAssertEqual(state.bonus(.attack(.spear), for: me), attack, "The gift goes with it")
        _ = theirs

        // A fallen holder's shrine is held by none.
        state.houses[2].isEliminated = true
        state.units.removeAll { $0.owner == 2 }
        _ = state.holdShrines()
        XCTAssertNil(state.holySites.first { $0.id == shrine.id }?.holder)
        XCTAssertEqual(state.problems(), [])
    }

    func testNoHoldIsRaisedOnAHolySiteAndTheWildsKeepOff() throws {
        var state = Scene.world("no hold on it", houses: 3, radius: 16)
        let me = state.player
        let shrine = try XCTUnwrap(state.holySites.first)
        let founder = state.put(.founder, of: me, at: shrine.position)
        XCTAssertEqual(state.refusal(of: .found(unit: founder), as: me), .holySite)
        XCTAssertEqual(RuleError.holySite.description, "No hold is raised on a holy site.")
        // Many watches of the wilds and the sites rising: none on a holy site.
        state.units.removeAll { $0.id == founder }
        for _ in 0..<40 { state.endWatch() }
        let sacred = Set(state.holySites.map(\.position))
        XCTAssertTrue(state.wildsStanding.allSatisfy { !sacred.contains($0.position) })
        XCTAssertTrue(state.sitesInLand.allSatisfy { !sacred.contains($0.position) })
    }

    func testStewardsAtPeaceGoToHoldTheHolySitesNearThem() throws {
        var state = Scene.world("stewards hold shrines", houses: 3, radius: 18)
        let steward = 1
        let seat = try XCTUnwrap(state.seat(of: steward)).position
        // A holy site set six tiles from the steward's seat, on open ground.
        let spot = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: seat) == 6 && state.map[hex]?.terrain == .greyfield && state.isClear(hex) && state.wild(at: hex) == nil
                && state.site(at: hex) == nil && state.holds.allSatisfy { $0.position.distance(to: hex) >= GameState.shrinesFromHolds }
                && state.path(for: Unit(id: -1, kind: .spear, owner: steward, position: seat), to: hex) != nil
        })
        state.shrines = [Shrine(id: 1, kind: .stillStone, position: spot)]
        var held: Int?
        for _ in 0..<16 where held == nil {
            state.endWatch()
            held = state.holySites.first?.holder
        }
        XCTAssertEqual(held, steward, "A steward's company went and stood on it")
        XCTAssertEqual(state.problems(), [])
    }

    func testHolySitesAreKeptSeenWhereExploredAndFoundInOlderSaves() throws {
        var state = Scene.world("kept shrines", houses: 3, radius: 16)
        let me = state.player
        let shrine = try XCTUnwrap(state.holySites.first)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        let view = state.view(for: me)
        XCTAssertEqual(view.holySites.map(\.id), state.holySites.filter { state.isExplored($0.position, by: me) }.map(\.id))
        state.reveal(around: shrine.position, range: 1, for: me)
        XCTAssertNotNil(state.view(for: me).shrine(at: shrine.position), "Found once explored")
        var older = try JSONDecoder().decode(GameState.self, from: try Scene.without(["shrines"], in: state))
        XCTAssertEqual(older.holySites, [])
        older.endWatch()
        XCTAssertEqual(older.holySites.count, 2, "Found as the watch turns")
    }
}
