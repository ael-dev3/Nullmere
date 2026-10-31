import Foundation
import XCTest
@testable import NullmereCore

/// Each House's crest: the lake's gift, the same for the same realm, and a
/// keeper's own choice once an age, seen by every House and told.
final class CrestTests: XCTestCase {
    private func world(_ seed: String = "crests", houses: Int = 12) -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: houses, radius: 20, keepers: 1))
    }

    /// The lake gives every House a crest of its own: readable, the same
    /// for the same realm, and no two of a realm alike.
    func testTheLakeGivesEachHouseItsOwnCrest() {
        let state = world()
        let crests = state.houses.map { state.crest(of: $0.id) }
        XCTAssertTrue(crests.allSatisfy(\.isReadable), "Every charge stands out from its field")
        XCTAssertEqual(Set(crests.map { "\($0.charge) on \($0.field)" }).count, crests.count, "No two alike")
        XCTAssertEqual(crests, world().houses.map { world().crest(of: $0.id) }, "The same for the same realm")
        XCTAssertNotEqual(crests, world("another realm").houses.map { world("another realm").crest(of: $0.id) })
        XCTAssertEqual(Set((0..<70).map { Crest.given(to: $0, seedText: "wide") }.map { "\($0.charge) \($0.field)" }).count, 70,
                       "Seventy side by side, none alike")
        XCTAssertEqual(state.crest(of: 99), Crest(field: .black, charge: .moon, tincture: .silver), "No such House")
        XCTAssertTrue(state.houses.allSatisfy { $0.crest == nil }, "None chosen yet")
    }

    func testACrestIsToldInWords() {
        XCTAssertEqual(Crest(field: .blue, charge: .heron, tincture: .silver).blazon, "a silver heron on blue")
        XCTAssertEqual(Crest(field: .black, charge: .antler, tincture: .gold).blazon, "a gold antler on black")
        XCTAssertFalse(Crest(field: .red, charge: .flame, tincture: .red).isReadable)
        XCTAssertEqual(Crest.Tincture.allCases.count, 7)
        XCTAssertEqual(Crest.Charge.allCases.count, 10)
    }

    /// A keeper's House takes its crest once an age: a readable one only;
    /// every House sees it and hears of it; it travels with the world.
    func testAKeeperTakesTheirCrestOnceAnAge() throws {
        var state = world()
        let me = state.player
        let unreadable = Crest(field: .green, charge: .oar, tincture: .green)
        XCTAssertEqual(state.crestRefusal(unreadable, as: me), .crestUnreadable)
        XCTAssertThrowsError(try state.perform(.takeCrest(unreadable), as: me)) { XCTAssertEqual($0 as? RuleError, .crestUnreadable) }

        let mine = Crest(field: .purple, charge: .bell, tincture: .gold)
        let events = try state.perform(.takeCrest(mine), as: me)
        XCTAssertEqual(events, [.crestTaken(house: me, crest: mine)])
        XCTAssertEqual(state.crest(of: me), mine)
        XCTAssertTrue(state.chronicle.contains { $0.text == "\(state.houses[me].title) takes for its crest a gold bell on purple." })
        XCTAssertEqual(state.crestRefusal(Crest(field: .blue, charge: .star, tincture: .silver), as: me), .crestChosenAlready)
        XCTAssertThrowsError(try state.perform(.takeCrest(Crest(field: .blue, charge: .star, tincture: .silver)), as: me)) {
            XCTAssertEqual($0 as? RuleError, .crestChosenAlready)
        }

        let other = (me + 1) % state.houses.count
        XCTAssertEqual(state.view(for: other).crest(of: me), mine, "Every House sees it")
        XCTAssertEqual(state.tidings(of: events[0], for: me)?.text, "Your House takes for its crest a gold bell on purple, and bears it until the age ends.")
        XCTAssertEqual(state.tidings(of: events[0], for: other)?.text, "\(state.houses[me].title) takes for its crest a gold bell on purple.")
        XCTAssertTrue(state.events([events[0]], heardBy: other).contains(events[0]), "Heard by all")

        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.houses[me].crest, mine)
        XCTAssertEqual(RuleError.crestChosenAlready.description, "Your House took its crest this age; it bears it until the age ends.")
        XCTAssertTrue(RuleError.crestUnreadable.description.hasPrefix("A charge must be of another tincture"))
    }
}
