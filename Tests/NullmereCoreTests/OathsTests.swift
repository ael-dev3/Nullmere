import Foundation
import XCTest
@testable import NullmereCore

/// Oaths the realm keeps: sworn by a keeper to another House and held to
/// by the realm. Sworn to peace, the House's declaration of war is refused;
/// sworn to send goods, they are sent each watch, and an oath unpaid is
/// broken and remembered; renounced, it binds three watches more; ended
/// with its last watch or a fallen House; gone with its keeper; read from
/// the order book; and a world of stewards swears none.
final class OathsTests: XCTestCase {
    private func world(_ seed: String) throws -> (GameState, me: Int, other: Int, third: Int) {
        let state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let others = state.houses.filter { $0.id != me }.map(\.id)
        return (state, me, try XCTUnwrap(others.first), try XCTUnwrap(others.last))
    }

    private func sworn(_ events: [GameEvent]) throws -> Oath {
        guard case .oathSworn(let oath) = try XCTUnwrap(events.first) else {
            XCTFail("No oath sworn: \(events)")
            throw RuleError.notApplicable
        }
        return oath
    }

    func testSwornToPeaceTheRealmRefusesTheirWar() throws {
        var (state, me, other, third) = try world("sworn to peace")
        let events = try state.perform(.swear(.peace, to: other, watches: 10), as: me)
        let oath = try sworn(events)
        XCTAssertEqual(oath.until, state.watch + 10)
        XCTAssertEqual(state.lastWatch(of: oath), oath.until)
        XCTAssertTrue(state.isSwornToPeace(me, with: other))
        XCTAssertThrowsError(try state.perform(.declareWar(on: other), as: me)) {
            XCTAssertEqual($0 as? RuleError, .swornToPeace(other))
        }
        XCTAssertNotNil(RuleError.swornToPeace(other).description)
        XCTAssertNoThrow(try state.perform(.declareWar(on: third), as: me), "Bound only toward the House sworn to")
        XCTAssertEqual(state.swearRefusal(.peace, to: other, watches: 10, as: me), .notApplicable, "Sworn already")
        XCTAssertEqual(state.swearRefusal(.peace, to: third, watches: 10, as: me), .alreadyStance(.war), "Not while at war")
        XCTAssertEqual(state.swearRefusal(.send(.grain, 10), to: other, watches: 61, as: me), .invalidAmount)
        XCTAssertEqual(state.swearRefusal(.send(.grain, 0), to: other, watches: 5, as: me), .invalidAmount)
        XCTAssertEqual(state.swearRefusal(.peace, to: me, watches: 5, as: me), .unknownHouse)
        XCTAssertEqual(state.swearRefusal(.peace, to: me, watches: 5, as: other), .notAKeeper, "Stewards swear none")
        // Before the whole realm: every House hears it, the chronicle keeps
        // it, and every keeper's view shows it.
        XCTAssertEqual(state.events(events, heardBy: third), events)
        XCTAssertEqual(state.tidings(of: events[0], for: other)?.tone, .good)
        XCTAssertTrue(state.tidings(of: events[0], for: me)?.text.hasPrefix("Your House is sworn: peace with") == true)
        XCTAssertTrue(state.tidings(of: events[0], for: third)?.text.contains("swears an oath to") == true)
        XCTAssertTrue(state.chronicle.last { $0.kind == .pact }?.text.contains("swears an oath") == true)
        XCTAssertEqual(state.view(for: me).oathsInForce, [oath])
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.oathsInForce, [oath])

        // Kept to its last watch, and then war may be declared.
        state.watch = oath.until - 1
        XCTAssertEqual(state.keepOaths(), [])
        state.watch = oath.until
        let ended = state.keepOaths()
        XCTAssertEqual(ended, [.oathEnded(oath, why: .kept)])
        XCTAssertEqual(state.tidings(of: ended[0], for: me)?.tone, .good)
        XCTAssertNil(state.tidings(of: ended[0], for: third))
        XCTAssertFalse(state.isSwornToPeace(me, with: other))
        XCTAssertNil(state.oaths, "None left")
        XCTAssertNoThrow(try state.perform(.declareWar(on: other), as: me))
    }

    func testAnOathRenouncedBindsThreeWatchesMore() throws {
        var (state, me, other, third) = try world("renounced")
        let oath = try sworn(try state.perform(.swear(.peace, to: other, watches: 30), as: me))
        XCTAssertEqual(state.renounceRefusal(oath.id, as: other), .notYourOath)
        let events = try state.perform(.renounce(oath: oath.id), as: me)
        guard case .oathRenounced(let renounced) = try XCTUnwrap(events.first) else { return XCTFail("\(events)") }
        XCTAssertEqual(state.lastWatch(of: renounced), state.watch + GameState.oathNotice)
        XCTAssertEqual(state.events(events, heardBy: third), events, "Told to the whole realm")
        XCTAssertEqual(state.tidings(of: events[0], for: other)?.tone, .bad)
        XCTAssertNotNil(state.tidings(of: events[0], for: third))
        XCTAssertNotNil(state.tidings(of: events[0], for: me))
        XCTAssertEqual(state.renounceRefusal(oath.id, as: me), .notApplicable, "Renounced once")
        XCTAssertTrue(state.isSwornToPeace(me, with: other), "Still bound through its notice")
        state.watch += GameState.oathNotice
        let ended = state.keepOaths()
        XCTAssertEqual(ended, [.oathEnded(renounced, why: .renounced)])
        XCTAssertEqual(state.tidings(of: ended[0], for: other)?.tone, .bad)
        XCTAssertEqual(state.tidings(of: ended[0], for: me)?.tone, .neutral)
        XCTAssertFalse(state.isSwornToPeace(me, with: other))
    }

    func testGoodsSwornAreSentEachWatchAndAnOathUnpaidIsBroken() throws {
        var (state, me, other, third) = try world("goods sworn")
        state.houses[me].stock.grain = 70
        let before = state.houses[other].stock.grain
        let oath = try sworn(try state.perform(.swear(.send(.grain, 30), to: other, watches: 5), as: me))
        XCTAssertTrue(state.sendsByOath(me, to: other))
        XCTAssertTrue(state.terms(of: oath).hasPrefix("30 grain to "))
        state.watch += 1
        XCTAssertEqual(state.keepOaths(), [])
        XCTAssertEqual(state.houses[me].stock.grain, 40)
        XCTAssertEqual(state.houses[other].stock.grain, before + 30)
        state.watch += 1
        _ = state.keepOaths()
        XCTAssertEqual(state.houses[me].stock.grain, 10)
        // Thirty owed and ten in store: broken, and remembered.
        let betrayals = state.relation(me, other)?.betrayals ?? 0
        state.watch += 1
        let broken = state.keepOaths()
        XCTAssertEqual(broken, [.oathEnded(oath, why: .broken)])
        XCTAssertEqual(state.houses[me].stock.grain, 10, "Nothing sent")
        XCTAssertEqual(state.relation(me, other)?.betrayals, betrayals + 1)
        XCTAssertTrue(state.chronicle.last { $0.kind == .betrayal }?.text.contains("breaks its oath") == true)
        XCTAssertEqual(state.events(broken, heardBy: third), broken, "A broken oath the whole realm hears of")
        XCTAssertEqual(state.tidings(of: broken[0], for: me)?.tone, .bad)
        XCTAssertEqual(state.tidings(of: broken[0], for: other)?.tone, .bad)
        XCTAssertNotNil(state.tidings(of: broken[0], for: third))
        XCTAssertFalse(state.sendsByOath(me, to: other))
    }

    func testOathsEndWithAFallenHouseAndGoWithTheirKeeper() throws {
        var (state, me, other, _) = try world("fallen")
        let oath = try sworn(try state.perform(.swear(.peace, to: other, watches: 20), as: me))
        var fallen = state
        fallen.houses[other].isEliminated = true
        XCTAssertEqual(fallen.keepOaths(), [.oathEnded(oath, why: .fallen)])
        XCTAssertNil(fallen.tidings(of: .oathEnded(oath, why: .fallen), for: me))
        // A keeper gone takes the oaths they swore with them.
        state.withdrawOaths(of: other)
        XCTAssertEqual(state.oathsInForce, [oath])
        state.withdrawOaths(of: me)
        XCTAssertNil(state.oaths)
        // No more than six held at once.
        var many = try world("many oaths").0
        let keeper = many.player
        let target = try XCTUnwrap(many.houses.first { $0.id != keeper }?.id)
        many.houses[keeper].stock.grain = 1_000
        for _ in 0..<GameState.oathsHeld { _ = try many.perform(.swear(.send(.grain, 1), to: target, watches: 10), as: keeper) }
        XCTAssertEqual(many.swearRefusal(.send(.grain, 1), to: target, watches: 10, as: keeper), .oathsHeld)
        XCTAssertNotNil(RuleError.oathsHeld.description)
        XCTAssertNotNil(RuleError.notYourOath.description)
    }

    /// The order book reads an oath, and its renouncing, from the lines the
    /// keeper's words become.
    func testTheOrderBookReadsOaths() throws {
        var (state, me, other, _) = try world("oaths read")
        let title = state.houses[other].title
        let peace = try XCTUnwrap(SpokenOrders.read(line: "SWEAR PEACE WITH \(title) FOR 12 WATCHES", in: state, player: me))
        XCTAssertEqual(peace.command, .swear(.peace, to: other, watches: 12))
        XCTAssertNil(peace.why)
        let send = try XCTUnwrap(SpokenOrders.read(line: "SWEAR TO SEND 25 timber TO \(title) EACH WATCH FOR 8 WATCHES", in: state, player: me))
        XCTAssertEqual(send.command, .swear(.send(.timber, 25), to: other, watches: 8))
        XCTAssertTrue(send.told.hasPrefix("Your House swears to send 25 timber"))
        XCTAssertEqual(SpokenOrders.read(line: "SWEAR PEACE WITH Nobody FOR 3 WATCHES", in: state, player: me)?.command, nil)
        XCTAssertNil(SpokenOrders.read(line: "SWEAR LOUDLY", in: state, player: me))
        XCTAssertNil(SpokenOrders.read(line: "SWEAR PEACE WITH \(title) FOR EVER", in: state, player: me))
        XCTAssertNotNil(SpokenOrders.read(line: "SWEAR TO SEND 25 sand TO \(title) EACH WATCH FOR 8 WATCHES", in: state, player: me)?.why)
        // Nothing yet to renounce.
        XCTAssertNotNil(SpokenOrders.read(line: "RENOUNCE THE OATH TO \(title)", in: state, player: me)?.why)
        let oath = try sworn(try state.perform(.swear(.peace, to: other, watches: 12), as: me))
        XCTAssertTrue(SpokenOrders.briefing(for: state, player: me).contains("Your House's oaths: peace with \(title)"))
        let renounce = try XCTUnwrap(SpokenOrders.read(line: "RENOUNCE THE OATH TO \(title)", in: state, player: me))
        XCTAssertEqual(renounce.command, .renounce(oath: oath.id))
        XCTAssertNil(SpokenOrders.read(line: "RENOUNCE EVERYTHING", in: state, player: me))
        XCTAssertTrue(SpokenOrders.forms.contains("RENOUNCE THE OATH TO <house>"))
    }

    /// A world of stewards swears no oath, and goes as it always did.
    func testStewardsSwearNone() {
        var stewards = GameState(settings: GameSettings(seedText: "stewards swear none", houseCount: 4, radius: 18))
        for _ in 0..<40 { _ = stewards.endWatch() }
        XCTAssertNil(stewards.oaths)
    }
}
