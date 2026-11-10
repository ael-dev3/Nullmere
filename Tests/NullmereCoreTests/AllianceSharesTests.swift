import Foundation
import XCTest
@testable import NullmereCore

/// Shares of the alliance's spoils (Rise of Kingdoms' alliance gifts):
/// set aside for each keeper's House of an alliance when one of its Houses
/// strikes down the wilds or breaks a lair, the doer's own among them, none
/// for a House its steward keeps alone nor another alliance's; taken when
/// the keeper will, stores up to what the House can store and an hourglass
/// from a lair; twelve waiting at most, and lapsing after twenty-four watches.
final class AllianceSharesTests: XCTestCase {
    private func realm() throws -> (state: GameState, me: Int, ally: Int, steward: Int, outsider: Int) {
        var state = GameState(settings: GameSettings(seedText: "shares of the spoils", houseCount: 9, radius: 20, keepers: 1))
        let me = state.player
        let others = state.houses.indices.filter { $0 != me }
        let (ally, steward, outsider) = (others[0], others[1], others[2])
        state.houses[ally].isPlayer = true
        _ = try state.perform(.foundAlliance(name: "The Reedbound"), as: me)
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: alliance, accept: true), as: ally)
        // A House its steward keeps, sworn to it too.
        let index = try XCTUnwrap(state.alliances?.firstIndex { $0.id == alliance })
        if !state.alliances![index].members.contains(steward) { state.alliances![index].members.append(steward) }
        XCTAssertEqual(Set(try XCTUnwrap(state.alliance(of: me)).members), [me, ally, steward])
        XCTAssertNil(state.alliance(of: outsider))
        return (state, me, ally, steward, outsider)
    }

    private func hunt(by house: Int, level: Int, fell: Bool = true) -> GameEvent {
        .hunted(Hunt(attacker: 1, attackerOwner: house, attackerKind: .spear, wild: 2, wildKind: .saltwights, level: level, at: Hex(0, 0),
                     damageDealt: 10, damageTaken: 0, attackerFell: false, wildFell: fell, spoils: Stock()))
    }

    private func lair(calledBy house: Int, level: Int, broken: Bool = true) -> GameEvent {
        .lairAssaulted(LairAssault(rally: 1, caller: house, lair: 3, kind: .reavers, level: level, at: Hex(0, 0), strikes: [],
                                   before: 50, strength: broken ? 0 : 20, might: 40, shares: []))
    }

    func testAShareIsSetAsideForEachKeeperOfTheAlliance() throws {
        var (state, me, ally, steward, outsider) = try realm()
        state.tally([hunt(by: ally, level: 3)])
        XCTAssertEqual(state.shares(of: me).map(\.from), [ally], "the doer's ally given one")
        XCTAssertEqual(state.shares(of: ally).map(\.from), [ally], "the doer its own")
        XCTAssertTrue(state.shares(of: steward).isEmpty, "no keeper to take it")
        XCTAssertTrue(state.shares(of: outsider).isEmpty, "nor another alliance's or none's")
        let share = try XCTUnwrap(state.shares(of: me).first)
        XCTAssertEqual(share.deed, .wilds)
        XCTAssertEqual(share.level, 3)
        XCTAssertEqual(share.stores, Stock(grain: 30, timber: 30, stone: 15))
        XCTAssertTrue(share.items.isEmpty)
        XCTAssertEqual(state.shareLine(share), "\(state.houses[ally].title) struck down a band of the wilds, level III")

        // A steward ally's deed shared with the keepers; an outsider's not.
        state.tally([hunt(by: steward, level: 1)])
        XCTAssertEqual(state.shares(of: me).last?.from, steward, "a steward's deed shared with the keepers")
        XCTAssertTrue(state.shares(of: steward).isEmpty)
        let before = state.shares(of: me).count
        state.tally([hunt(by: outsider, level: 5), hunt(by: me, level: 2, fell: false), lair(calledBy: me, level: 2, broken: false)])
        XCTAssertEqual(state.shares(of: me).count, before, "nothing for another's deed, a wild left standing or a lair unbroken")

        // A lair broken: more, and an hourglass.
        state.tally([lair(calledBy: me, level: 2)])
        let broken = try XCTUnwrap(state.shares(of: me).last)
        XCTAssertEqual(broken.deed, .lair)
        XCTAssertEqual(broken.stores, Stock(grain: 60, timber: 60, stone: 40, moonsalt: 2))
        XCTAssertEqual(broken.items, [.hourglass])
        XCTAssertEqual(state.shareLine(broken), "Your House broke a lair of the wilds, level II")
        XCTAssertEqual(state.shares(of: ally).last?.deed, .lair)
    }

    func testAKeeperTakesTheirShares() throws {
        var (state, me, ally, steward, _) = try realm()
        XCTAssertEqual(state.takeSharesRefusal(as: me), .noSharesWaiting)
        XCTAssertThrowsError(try state.perform(.takeShares, as: me))
        XCTAssertEqual(state.takeSharesRefusal(as: steward), .notAKeeper)
        state.tally([hunt(by: ally, level: 2), lair(calledBy: ally, level: 1)])
        state.houses[me].stock = Stock(grain: 10, timber: 10, stone: 10, moonsalt: 1)
        let held = state.sharesHeld(by: me)
        XCTAssertEqual(held.stores, Stock(grain: 50, timber: 50, stone: 30, moonsalt: 1))
        XCTAssertEqual(held.items, [.hourglass])
        let hourglasses = state.items(.hourglass, of: me)
        let events = try state.perform(.takeShares, as: me)
        XCTAssertEqual(state.houses[me].stock, Stock(grain: 60, timber: 60, stone: 40, moonsalt: 2))
        XCTAssertEqual(state.items(.hourglass, of: me), hourglasses + 1)
        XCTAssertTrue(events.contains(.itemsGiven(house: me, kind: .hourglass, count: 1)))
        XCTAssertTrue(state.shares(of: me).isEmpty, "taken")
        XCTAssertEqual(state.shares(of: ally).count, 2, "the ally's left to the ally")
        XCTAssertEqual(state.takeSharesRefusal(as: me), .noSharesWaiting)

        // Stores up to what the House can store.
        state.tally([lair(calledBy: ally, level: 10)])
        let room = state.storage(of: me)
        state.houses[me].stock = Stock(grain: room - 5)
        _ = try state.perform(.takeShares, as: me)
        XCTAssertEqual(state.houses[me].stock.grain, room)
        XCTAssertTrue(RuleError.noSharesWaiting.description.contains("alliance's spoils"))
    }

    func testSharesWaitALimitAndLapse() throws {
        var (state, me, ally, _, _) = try realm()
        for level in 1...15 { state.tally([hunt(by: ally, level: min(level, 10))]) }
        XCTAssertEqual(state.shares(of: me).count, AllianceShare.kept, "twelve wait at most")
        XCTAssertEqual(state.shares(of: me).first?.level, 4, "the oldest gave way")
        let given = try XCTUnwrap(state.shares(of: me).first).given
        state.watch = given + AllianceShare.lasts - 1
        XCTAssertEqual(state.shares(of: me).count, AllianceShare.kept)
        state.watch = given + AllianceShare.lasts
        XCTAssertTrue(state.shares(of: me).isEmpty, "lapsed untaken")
        XCTAssertEqual(state.takeSharesRefusal(as: me), .noSharesWaiting)
        state.lapseShares()
        XCTAssertNil(state.allianceShares, "and forgotten as the watch turns")
    }

    func testSharesAreTheirKeepersOwnToKnowAndKeptWithTheWorld() throws {
        var (state, me, ally, _, _) = try realm()
        state.tally([hunt(by: ally, level: 2)])
        let view = state.view(for: me)
        XCTAssertEqual(view.allianceShares?.map(\.house), [me], "its own alone")
        XCTAssertEqual(view.shares(of: me).count, 1)
        XCTAssertTrue(view.shares(of: ally).isEmpty)
        XCTAssertNil(state.view(for: (0..<state.houses.count).first { ![me, ally].contains($0) }!).allianceShares)
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.allianceShares, state.allianceShares)
        XCTAssertFalse(AllianceShare.said.isEmpty)
    }
}
