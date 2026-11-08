import Foundation
import XCTest
@testable import NullmereCore

/// The Still Hour: twice a moon the lake is a mirror, and every House sees
/// every company of war on its shore; a House that casts a ripple-stone
/// from a hold on the shore is not seen at the next one.
final class StillHourTests: XCTestCase {
    /// A world, a shore hex beside its water, and a company of war of the
    /// keeper's own House and of another set on it and beside it.
    private func world() throws -> (GameState, me: Int, other: Int, mine: Int, theirs: Int) {
        var state = GameState(settings: GameSettings(seedText: "the still hour", houseCount: 4, radius: 20, keepers: 1))
        let me = state.player
        let other = (me + 1) % state.houses.count
        let shore = try XCTUnwrap((0..<state.map.count).lazy.map { state.map.hex(at: $0) }.first { hex in
            state.isShore(hex) && state.unit(at: hex) == nil && state.hold(at: hex) == nil
                && hex.neighbors.contains { state.isShore($0) && state.unit(at: $0) == nil && state.hold(at: $0) == nil }
        })
        let beside = try XCTUnwrap(shore.neighbors.first { state.isShore($0) && state.unit(at: $0) == nil && state.hold(at: $0) == nil })
        let mine = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary }).id
        let theirs = try XCTUnwrap(state.units(of: other).first { $0.kind.isMilitary }).id
        state.units[try XCTUnwrap(state.unitIndex(mine))].position = shore
        state.units[try XCTUnwrap(state.unitIndex(theirs))].position = beside
        return (state, me, other, mine, theirs)
    }

    func testTheLakeLiesStillTwiceAMoonApartFromTheRiddlesAndDreams() {
        let still = (0..<GameState.lunarMonth).filter(GameState.isStillHour(at:))
        XCTAssertEqual(still.count, 2)
        XCTAssertTrue(GameState.riddleMoons.isDisjoint(with: still.map(GameState.moonAge(at:))))
        XCTAssertFalse(still.map(GameState.moonAge(at:)).contains(15), "Not at the dark, the dreams' night")
        XCTAssertTrue(GameState.isStillHour(at: GameState.nextStillHour(from: 0)))
    }

    func testEveryHouseSeesTheShoreInTheStillWater() throws {
        var (state, me, other, _, _) = try world()
        // The watch's turn lays the lake still at its hour.
        var turned = state
        turned.watch = GameState.nextStillHour(from: state.watch) - 1
        _ = turned.endWatch()
        XCTAssertNotNil(turned.stillHour, "The watch's turn lays the lake still")
        // At the hour, the companies standing on the shore are mirrored.
        state.watch = GameState.nextStillHour(from: state.watch)
        XCTAssertEqual(state.layTheLakeStill().count, 1)
        let shown = try XCTUnwrap(state.stillHour)
        XCTAssertTrue(GameState.isStillHour(at: shown.watch))
        XCTAssertTrue(shown.glimpses.contains { $0.owner == me })
        XCTAssertTrue(shown.glimpses.contains { $0.owner == other })
        XCTAssertTrue(shown.glimpses.allSatisfy { state.isShore($0.at) && $0.troops > 0 })
        // Shown to every House alike, the keeper's view too.
        XCTAssertEqual(state.view(for: me).stillHour, shown)
        XCTAssertEqual(state.view(for: other).stillHour, shown)
        // And it fades with the watch after.
        state.watch += 1
        _ = state.layTheLakeStill()
        XCTAssertNil(state.stillHour)
        XCTAssertEqual(state.problems(), [])
    }

    /// The still water told in the game's words, one company as one: where
    /// a phone's chronicle read "every House saw 1 companies".
    func testTheStillWaterIsToldCountingItsCompanies() throws {
        var (state, me, _, _, _) = try world()
        XCTAssertEqual(state.tidings(of: .stillHour(glimpses: 1, houses: []), for: me)?.text,
                       "The lake lies still as glass: 1 company stands mirrored on its shore for all to see.")
        XCTAssertEqual(state.tidings(of: .stillHour(glimpses: 7, houses: []), for: me)?.text,
                       "The lake lies still as glass: 7 companies stand mirrored on its shore for all to see.")
        XCTAssertEqual(GameState.companies(1), "1 company")
        XCTAssertEqual(GameState.companies(1_200), "1,200 companies")
        // The Chronicle's line, counting what the hour showed.
        state.watch = GameState.nextStillHour(from: state.watch)
        _ = state.layTheLakeStill()
        let shown = try XCTUnwrap(state.stillHour).glimpses.count
        XCTAssertTrue(state.chronicle.contains { $0.text == "The lake lay still as glass, and on it every House saw \(GameState.companies(shown)) standing on its shore." },
                      "\(state.chronicle.suffix(3).map(\.text))")
    }

    func testARippleStoneHidesAHousesCompaniesAtTheNextStillHour() throws {
        var (state, me, other, mine, _) = try world()
        // A hold of the keeper's own on the shore, where its company stands.
        let seatIndex = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        let inlandBefore = state.holds[seatIndex]
        state.holds[seatIndex].position = try XCTUnwrap(state.unit(mine)).position
        let shoreHold = state.holds[seatIndex]
        if !inlandBefore.position.spiral(1).contains(where: state.isShore) {
            var inland = state
            inland.holds[seatIndex].position = inlandBefore.position
            XCTAssertEqual(inland.rippleRefusal(from: shoreHold.id, as: me), .notOnTheShore)
        }
        XCTAssertEqual(state.rippleRefusal(from: try XCTUnwrap(state.holds(of: other).first).id, as: me), .notYours)
        state.houses[me].stock = .zero
        XCTAssertNotNil(state.rippleRefusal(from: shoreHold.id, as: me), "The stone is paid for")
        state.houses[me].stock = Stock(moonsalt: 20)
        try state.perform(.castRipple(hold: shoreHold.id), as: me)
        XCTAssertEqual(state.houses[me].stock.moonsalt, 20 - GameState.rippleCost.moonsalt)
        XCTAssertEqual(state.rippleRefusal(from: shoreHold.id, as: me), .alreadyRippled, "One stone a Still Hour")
        state.watch = GameState.nextStillHour(from: state.watch + 1)
        _ = state.layTheLakeStill()
        let shown = try XCTUnwrap(state.stillHour)
        XCTAssertFalse(shown.glimpses.contains { $0.owner == me }, "Its own unseen")
        XCTAssertTrue(shown.glimpses.contains { $0.owner == other }, "Others seen still")
        XCTAssertEqual(shown.rippled, [me])
        XCTAssertNil(state.ripples, "The stone sinks, its stirring spent")
        XCTAssertNil(state.rippleRefusal(from: shoreHold.id, as: me))
        // Saved and read again, the mirror stands.
        let read = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(read.stillHour, shown)
    }

    /// A wary steward at war, its companies on the shore, stirs the water
    /// the watch before the Still Hour.
    func testAWaryStewardStirsTheWaterBeforeTheHour() throws {
        var (state, me, other, mine, _) = try world()
        let steward = other
        let seatIndex = try XCTUnwrap(state.holds.firstIndex { $0.owner == steward && $0.isSeat })
        let theirs = try XCTUnwrap(state.units(of: steward).first { $0.kind.isMilitary })
        state.holds[seatIndex].position = theirs.position
        state.houses[steward].temperament = .wary
        state.houses[steward].stock.moonsalt = 60
        _ = try state.declareWar(by: steward, on: me)
        state.watch = GameState.nextStillHour(from: state.watch + 1) - 1
        var random = SeededRandom(seed: 3)
        let events = RivalMind(house: steward).stirTheWater(in: &state, random: &random)
        XCTAssertTrue(events.contains { if case .rippleCast(steward, _) = $0 { return true } else { return false } }, "\(events)")
        XCTAssertTrue(state.hasRippled(steward))
        _ = mine
    }
}
