import Foundation
import XCTest
@testable import NullmereCore

/// A House's satchel: hourglasses that hasten what a hold has under way or
/// the House's study, caches of stores, ward stones and mending draughts;
/// given by lairs broken, happenings' marks and the charges kept, used
/// when the keeper will.
final class ItemTests: XCTestCase {
    func testItemsAreGivenKeptAndCounted() throws {
        var state = Scene.world("satchel", houses: 3, radius: 16)
        let me = state.player
        XCTAssertEqual(state.satchel(of: me), [])
        XCTAssertEqual(state.give(.hourglass, 2, to: me), [.itemsGiven(house: me, kind: .hourglass, count: 2)])
        _ = state.give(.wardStone, to: me)
        _ = state.give(.hourglass, to: me)
        _ = state.give(.grainCache, to: 1)
        XCTAssertEqual(state.items(.hourglass, of: me), 3)
        XCTAssertEqual(state.satchel(of: me).map(\.kind), [.hourglass, .wardStone], "In the order of their kinds")
        XCTAssertEqual(state.satchel(of: 1).map(\.kind), [.grainCache])
        // No more of a kind than it may keep.
        XCTAssertEqual(state.give(.hourglass, 50, to: me), [.itemsGiven(house: me, kind: .hourglass, count: GameState.itemsKept - 3)])
        XCTAssertEqual(state.give(.hourglass, to: me), [], "Full")
        XCTAssertEqual(state.items(.hourglass, of: me), GameState.itemsKept)
        // Only its own House knows what is in its satchel.
        XCTAssertEqual(state.view(for: me).satchel(of: me).count, 2)
        XCTAssertTrue(state.view(for: me).satchel(of: 1).isEmpty)
        let given = GameEvent.itemsGiven(house: me, kind: .wardStone, count: 1)
        XCTAssertEqual(state.events([given], heardBy: me), [given])
        XCTAssertEqual(state.events([given], heardBy: 1), [])
        XCTAssertEqual(state.tidings(of: given, for: me)?.text, "Your House gains a Ward Stone: a hold's ward made whole.")
        XCTAssertEqual(state.tidings(of: .itemsGiven(house: me, kind: .hourglass, count: 2), for: me)?.text,
                       "Your House gains 2 Salt Hourglasses: a hold's work and muster a watch nearer, or the House's study.")
        XCTAssertEqual(ItemKind.allCases.map(\.title), ["Salt Hourglass", "Cache of Grain", "Cache of Timber", "Cache of Stone",
                                                        "Cache of Moonsalt", "Ward Stone", "Mending Draught"])
        XCTAssertEqual(Set(ItemKind.allCases.map(\.plural)).count, ItemKind.allCases.count)
        XCTAssertEqual(ItemKind.allCases.map { $0.needsHold }, [false, false, false, false, false, true, false])
        XCTAssertEqual(Resource.allCases.map(ItemKind.cache(of:)), [.grainCache, .timberCache, .stoneCache, .moonsaltCache])
        XCTAssertEqual(state.problems(), [])
        // Kept in saves.
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(state))
        XCTAssertEqual(kept.satchel(of: me), state.satchel(of: me))
        // A fallen House is given nothing.
        state.houses[2].isEliminated = true
        XCTAssertEqual(state.give(.wardStone, to: 2), [])
        XCTAssertEqual(state.give(.wardStone, 0, to: me), [])
    }

    func testASatchelOutOfTrueIsFound() {
        var state = Scene.world("satchel unsound", houses: 3, radius: 16)
        state.satchel = [ItemStack(house: 9, kind: .hourglass, count: 1), ItemStack(house: 0, kind: .wardStone, count: 0),
                         ItemStack(house: 1, kind: .hourglass, count: 2), ItemStack(house: 1, kind: .hourglass, count: GameState.itemsKept + 1)]
        XCTAssertEqual(state.problems(), ["A satchel is of no House (9)", "House 0 keeps 0 of Ward Stones",
                                          "House 1 keeps \(GameState.itemsKept + 1) of Salt Hourglasses", "House 1 keeps Salt Hourglasses twice"])
    }

    func testAnHourglassHastensAHoldsWorkAndMusterOrTheHousesStudy() throws {
        var state = Scene.world("hourglass", houses: 3, radius: 16)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        _ = state.give(.hourglass, 3, to: me)
        XCTAssertThrowsError(try state.perform(.useItem(.hourglass, hold: seat.id), as: me)) {
            XCTAssertEqual($0 as? RuleError, .nothingToHasten)
        }
        state.holds[index].project = Hold.Project(kind: .granary, targetLevel: 1, watchesLeft: 3)
        state.holds[index].training = Hold.Training(kind: .spear, watchesLeft: 2)
        let used = try state.perform(.useItem(.hourglass, hold: seat.id), as: me)
        XCTAssertEqual(used, [.itemUsed(house: me, kind: .hourglass, hold: seat.id)])
        XCTAssertEqual(state.hold(seat.id)?.project?.watchesLeft, 2)
        XCTAssertEqual(state.hold(seat.id)?.training?.watchesLeft, 1)
        XCTAssertEqual(state.items(.hourglass, of: me), 2)
        // Never past its last watch: what is done is done as the watch turns.
        _ = try state.perform(.useItem(.hourglass, hold: seat.id), as: me)
        XCTAssertEqual(state.hold(seat.id)?.project?.watchesLeft, 1)
        XCTAssertEqual(state.hold(seat.id)?.training?.watchesLeft, 1)
        XCTAssertThrowsError(try state.perform(.useItem(.hourglass, hold: seat.id), as: me)) {
            XCTAssertEqual($0 as? RuleError, .nothingToHasten)
        }
        // Naming no hold, it hastens the House's study.
        state.houses[me].research.pursuit = Pursuit(study: .furrowLore, grade: 1, watchesLeft: 3)
        _ = try state.perform(.useItem(.hourglass, hold: nil), as: me)
        XCTAssertEqual(state.houses[me].research.pursuit?.watchesLeft, 2)
        XCTAssertEqual(state.items(.hourglass, of: me), 0)
        XCTAssertThrowsError(try state.perform(.useItem(.hourglass, hold: nil), as: me)) { XCTAssertEqual($0 as? RuleError, .noItem) }
        XCTAssertThrowsError(try state.perform(.useItem(.hourglass, hold: try XCTUnwrap(state.seat(of: 1)).id), as: me)) {
            XCTAssertEqual($0 as? RuleError, .noItem, "None left before whose hold it is")
        }
        _ = state.give(.hourglass, to: me)
        XCTAssertThrowsError(try state.perform(.useItem(.hourglass, hold: try XCTUnwrap(state.seat(of: 1)).id), as: me)) {
            XCTAssertEqual($0 as? RuleError, .notYours)
        }
        XCTAssertEqual(state.tidings(of: used[0], for: me)?.text, "You use a Salt Hourglass at \(seat.name).")
        XCTAssertNil(state.tidings(of: used[0], for: 1))
        XCTAssertEqual(state.tidings(of: .itemUsed(house: me, kind: .hourglass, hold: nil), for: me)?.text,
                       "You use a Salt Hourglass on your House's study.")
        XCTAssertEqual(state.tidings(of: .itemUsed(house: me, kind: .wardStone, hold: 9999), for: me)?.text, "You use a Ward Stone at your hold.")
        XCTAssertNil(state.tidings(of: .itemsGiven(house: me, kind: .wardStone, count: 1), for: 1))
        XCTAssertEqual(state.events([used[0]], heardBy: 1), [])
        XCTAssertEqual(RuleError.nothingToHasten.description, "Nothing under way there has a watch to spare: what has one left is done as the watch turns.")
    }

    func testCachesWardStonesAndDraughtsDoWhatTheySay() throws {
        var state = Scene.world("caches", houses: 3, radius: 16)
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.houses[me].stock = .zero
        _ = state.give(.timberCache, to: me)
        let opened = try state.perform(.useItem(.timberCache, hold: nil), as: me)
        XCTAssertEqual(state.houses[me].stock.timber, 120)
        XCTAssertEqual(state.tidings(of: opened[0], for: me)?.text, "You open a Cache of Timber: 120 timber to your stores.")
        XCTAssertEqual(state.satchel(of: me), [], "Its last used, the stack is gone")
        // A full store takes no more: the cache is kept.
        let room = state.storage(of: me)
        state.houses[me].stock = Stock(grain: room, timber: room, stone: room, moonsalt: room)
        _ = state.give(.grainCache, to: me)
        XCTAssertThrowsError(try state.perform(.useItem(.grainCache, hold: nil), as: me)) { XCTAssertEqual($0 as? RuleError, .storageFull) }
        XCTAssertEqual(state.items(.grainCache, of: me), 1)
        // A ward stone makes a hold's ward whole; on a whole ward it waits.
        _ = state.give(.wardStone, to: me)
        XCTAssertThrowsError(try state.perform(.useItem(.wardStone, hold: seat.id), as: me)) { XCTAssertEqual($0 as? RuleError, .wardWhole) }
        XCTAssertThrowsError(try state.perform(.useItem(.wardStone, hold: nil), as: me)) { XCTAssertEqual($0 as? RuleError, .unknownHold) }
        state.holds[index].ward = 3
        _ = try state.perform(.useItem(.wardStone, hold: seat.id), as: me)
        XCTAssertEqual(state.hold(seat.id)?.ward, state.hold(seat.id)?.maximumWard)
        // A mending draught: every hurt company of the House mends.
        _ = state.give(.mendingDraught, to: me)
        XCTAssertThrowsError(try state.perform(.useItem(.mendingDraught, hold: nil), as: me)) { XCTAssertEqual($0 as? RuleError, .noneHurt) }
        let hurt = state.put(.spear, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3)), health: 40)
        let theirs = state.put(.spear, of: 1, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 3...4)), health: 40)
        let shared = try state.perform(.useItem(.mendingDraught, hold: nil), as: me)
        XCTAssertEqual(state.unit(hurt)?.health, 40 + GameState.draughtMending)
        XCTAssertEqual(state.unit(theirs)?.health, 40, "Its own only")
        XCTAssertEqual(state.tidings(of: shared[0], for: me)?.text, "You share out a Mending Draught: every hurt company of yours mends.")
        XCTAssertEqual(RuleError.noItem.description, "Your House has none of that.")
        XCTAssertEqual(RuleError.wardWhole.description, "That hold's ward is whole.")
        XCTAssertEqual(RuleError.noneHurt.description, "None of your companies is hurt.")
        XCTAssertEqual(ItemKind.mendingDraught.effect, "30 health to every company of the House")
        XCTAssertEqual(ItemKind.moonsaltCache.effect, "20 moonsalt to the House's stores")
        XCTAssertEqual(state.problems(), [])
    }

    func testLairsMarksAndChargesFillTheSatchel() throws {
        // A lair broken: its caller gains an hourglass and a cache of what
        // the lair gave; every other House of the host, a cache.
        var state = Scene.world("satchel filled", houses: 3, radius: 16)
        let me = state.player
        let events = state.rewardLair(LairAssault(rally: 1, caller: me, lair: 2, kind: .reavers, level: 2, at: .origin, strikes: [],
                                                  before: 450, strength: 0, might: 450,
                                                  shares: [.init(house: me, spoils: .zero), .init(house: 1, spoils: .zero)]))
        XCTAssertEqual(state.items(.hourglass, of: me), 2, "One a level")
        XCTAssertEqual(state.items(.timberCache, of: me), 1, "The Reavers' timber")
        XCTAssertEqual(state.items(.timberCache, of: 1), 1)
        XCTAssertEqual(state.items(.hourglass, of: 1), 0)
        XCTAssertEqual(events.count, 3)
        // The first charges bring hourglasses, to learn by.
        XCTAssertEqual(Charge.raiseGranary.items, [.hourglass])
        XCTAssertTrue(Charge.allCases.contains { $0.items.contains(.mendingDraught) })
    }

    func testAStewardUsesItsItems() throws {
        var state = Scene.world("steward satchel", houses: 3, radius: 16)
        let steward = 2
        let seat = try XCTUnwrap(state.seat(of: steward))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[index].project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 4)
        state.holds[index].ward = 2
        _ = state.give(.hourglass, to: steward)
        _ = state.give(.wardStone, to: steward)
        let events = state.stewardTurn(for: steward)
        XCTAssertTrue(events.contains(.itemUsed(house: steward, kind: .hourglass, hold: seat.id)), "\(events)")
        XCTAssertTrue(events.contains(.itemUsed(house: steward, kind: .wardStone, hold: seat.id)))
    }
}
