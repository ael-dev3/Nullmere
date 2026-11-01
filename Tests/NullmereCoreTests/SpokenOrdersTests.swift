import Foundation
import XCTest
@testable import NullmereCore

/// Orders in a keeper's own words: the model's answer, the order book's
/// lines, read against the keeper's view into the orders the realm would
/// take, or why not; the briefing the model is given of what the House has
/// and knows.
final class SpokenOrdersTests: XCTestCase {
    private func world() -> GameState {
        GameState(settings: GameSettings(seedText: "orders in words", houseCount: 4, radius: 18, keepers: 1, rivers: true))
    }

    func testTheBriefingNumbersTheCompaniesAndNamesWhatTheHouseKnows() throws {
        let state = world()
        let me = state.player
        let briefing = SpokenOrders.briefing(for: state, player: me)
        let companies = SpokenOrders.companies(in: state, player: me)
        XCTAssertFalse(companies.isEmpty)
        XCTAssertEqual(companies.map(\.id), companies.map(\.id).sorted())
        for (index, unit) in companies.enumerated() {
            XCTAssertTrue(briefing.contains("C\(index + 1): \(SpokenOrders.named(unit, in: state))"), briefing)
        }
        let seat = try XCTUnwrap(state.seat(of: me))
        XCTAssertTrue(briefing.contains("Your holds: \(seat.name)"))
        XCTAssertTrue(briefing.contains("Granary"))
        XCTAssertTrue(briefing.contains("Riders"))
        XCTAssertTrue(SpokenOrders.forms.allSatisfy(briefing.contains))
        for region in try XCTUnwrap(state.atlas?.regions) { XCTAssertTrue(briefing.contains(region.name), region.name) }
        // Each place named once, the nearest the seat first; the House's
        // own holds among its holds, not again among the places.
        let known = try XCTUnwrap(briefing.split(separator: "\n").first { $0.hasPrefix("Places you know: ") })
        let names = known.dropFirst("Places you know: ".count).components(separatedBy: ", ")
        XCTAssertEqual(names.count, Set(names).count)
        XCTAssertFalse(names.contains(seat.name))
        let distances = names.compactMap { name in SpokenOrders.places(in: state).filter { $0.name == name }.map { $0.at.distance(to: seat.position) }.min() }
        XCTAssertEqual(distances, distances.sorted())
    }

    /// A House of many companies and a realm of many places: the briefing
    /// names only so many of either, so it stays within what the model
    /// reads at once.
    func testTheBriefingKeepsWithinWhatTheModelReads() throws {
        var state = world()
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        var placed = 0
        for hex in state.map.hexes where placed < SpokenOrders.briefedCompanies + 5 {
            guard let tile = state.map[hex], tile.terrain.isPassable, !tile.terrain.isWater, state.isClear(hex) else { continue }
            _ = state.put(.spear, tier: 1, of: me, at: hex)
            placed += 1
        }
        state.shrines = (0..<SpokenOrders.briefedPlaces).map { Shrine(id: 900 + $0, kind: .moonwell, position: Hex($0 % 9, $0 / 9)) }
        let briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains("\nC\(SpokenOrders.briefedCompanies): "))
        XCTAssertFalse(briefing.contains("\nC\(SpokenOrders.briefedCompanies + 1): "))
        let known = try XCTUnwrap(briefing.split(separator: "\n").first { $0.hasPrefix("Places you know: ") })
        XCTAssertLessThanOrEqual(known.components(separatedBy: ", ").count, SpokenOrders.briefedPlaces)
        XCTAssertEqual(known.components(separatedBy: "Moonwell").count - 1, 1, "Each name once")
        // A company past those the briefing names may still be ordered by its number.
        let last = SpokenOrders.companies(in: state, player: me).count
        XCTAssertNotNil(SpokenOrders.company("C\(last)", in: state, player: me))
        XCTAssertTrue(briefing.contains("Your holds: \(seat.name)"))
    }

    func testTheOrderBooksLinesAreReadIntoOrders() throws {
        let state = world()
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let companies = SpokenOrders.companies(in: state, player: me)
        let first = try XCTUnwrap(companies.first { $0.kind.isMilitary })
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == first.id }) + 1)"
        let region = try XCTUnwrap(state.atlas?.regions.first)
        // As a model might set them down: numbered, marked, quoted, a
        // company named before its handle.
        let answer = """
        1. MARCH \(handle) TO \(region.name).
        `fortify \(handle)`
        - **HALT the company \(handle)**
        BUILD the granary AT \(seat.name)
        "TRAIN rider AT \(seat.name)"
        NONE
        Some chatter the model added.
        """
        let lines = SpokenOrders.read(answer, in: state, player: me)
        XCTAssertEqual(lines.count, 5, "The chatter and NONE passed over")
        XCTAssertEqual(lines[0].text, "MARCH \(handle) TO \(region.name).")
        XCTAssertEqual(lines[0].command, .move(unit: first.id, to: region.heart))
        XCTAssertEqual(lines[0].told, "Your \(SpokenOrders.named(first, in: state)) march to \(region.name).")
        XCTAssertEqual(lines[1].command, .fortify(unit: first.id))
        XCTAssertEqual(lines[2].command, .halt(unit: first.id))
        XCTAssertEqual(lines[3].command, .build(hold: seat.id, kind: .granary))
        XCTAssertEqual(lines[3].told, "\(seat.name) raises its Granary.")
        XCTAssertEqual(lines[4].command, .train(hold: seat.id, kind: .rider))
        XCTAssertEqual(lines[4].told, "\(seat.name) musters a company of Riders.")
        // Each line's refusal is the realm's own, asked of the keeper's view.
        for line in lines {
            XCTAssertEqual(line.why, line.command.flatMap { state.refusal(of: $0, as: me) }?.description)
        }
        // At most six orders at once.
        let many = Array(repeating: "FORTIFY \(handle)", count: 9).joined(separator: "\n")
        XCTAssertEqual(SpokenOrders.read(many, in: state, player: me).count, SpokenOrders.most)
    }

    /// The House's dealings with the others: envoys of peace, of a pact or
    /// demanding tribute, war, gifts and offers of trade, each House named
    /// by its title or its name alone.
    func testTheHousesDealingsAreReadIntoOrders() throws {
        let state = world()
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me })
        let name = other.name
        let lines = SpokenOrders.read("""
        OFFER PEACE TO \(other.title)
        OFFER A PACT TO \(name)
        DEMAND TRIBUTE FROM \(other.title)
        DECLARE WAR ON \(other.title)
        GIVE 20 timber TO \(other.title)
        TRADE 1,000 timber FOR 20 grain WITH \(name)
        """, in: state, player: me)
        XCTAssertEqual(lines.map(\.command), [
            .propose(.peace, to: other.id), .propose(.pact, to: other.id), .propose(.tribute, to: other.id), .declareWar(on: other.id),
            .gift(to: other.id, resource: .timber, amount: 20), .offerTrade(Trade(give: .timber, 1_000, for: .grain, 20), to: other.id, words: nil),
        ])
        XCTAssertEqual(lines.map(\.told), [
            "An envoy to \(other.title), offering peace.", "An envoy to \(other.title), offering a pact.",
            "An envoy to \(other.title), demanding tribute.", "War on \(other.title).", "20 timber sent to \(other.title).",
            "1,000 timber offered to \(other.title) for 20 grain.",
        ])
        for line in lines { XCTAssertEqual(line.why, line.command.flatMap { state.refusal(of: $0, as: me) }?.description) }

        // A House, or a store, the realm doesn't know; a line short of its parts.
        let wrong = SpokenOrders.read("""
        OFFER PEACE TO House Nobody
        GIVE 20 gold TO \(other.title)
        TRADE 10 timber FOR 5 pearls WITH \(other.title)
        TRADE 10 silk FOR 5 grain WITH \(other.title)
        GIVE timber TO \(other.title)
        OFFER CAKE TO \(other.title)
        TRADE 10 timber WITH \(other.title)
        """, in: state, player: me)
        XCTAssertEqual(wrong.map(\.why), ["No House goes by the name House Nobody.", "No store goes by the name gold.",
                                          "No store goes by the name pearls.", "No store goes by the name silk."])
        XCTAssertTrue(wrong.allSatisfy { $0.command == nil })
        XCTAssertNil(SpokenOrders.house(state.houses[me].title, in: state, player: me), "Not the House's own")

        // The briefing names the other Houses standing, as the House stands
        // with each, and the stores.
        let briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains("\(other.title) (\(state.stance(me, other.id).standing))"), briefing)
        XCTAssertFalse(briefing.contains("\(state.houses[me].title) ("))
        XCTAssertTrue(briefing.contains("Stores: Grain, Timber, Stone, Moonsalt"))
    }

    func testWhatCantBeReadIsSaidSo() throws {
        var state = world()
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let lines = SpokenOrders.read("""
        MARCH C99 TO \(seat.name)
        MARCH C1 TO Nowhere At All
        BUILD a Palace AT \(seat.name)
        TRAIN Dragons AT \(seat.name)
        BUILD Granary AT Elsewhere
        DANCE C1
        """, in: state, player: me)
        XCTAssertEqual(lines.count, 5, "A line of no form is passed over")
        XCTAssertTrue(lines.allSatisfy { $0.command == nil })
        XCTAssertEqual(lines.map(\.why), ["Your House has no company C99.", "Your House knows no place by the name Nowhere At All.",
                                          "No work goes by the name a Palace.", "No company goes by the name Dragons.",
                                          "Your House holds no hold by the name Elsewhere."])
        // A company of no handle, and a line short of its parts.
        XCTAssertNil(SpokenOrders.company("Riders", in: state, player: me))
        XCTAssertTrue(SpokenOrders.read("MARCH TO \(seat.name)\nSTRIKE WITH C1", in: state, player: me).isEmpty)
        // Of several of a name, the nearest.
        let unit = try XCTUnwrap(SpokenOrders.companies(in: state, player: me).first)
        state.shrines = [Shrine(id: 1, kind: .moonwell, position: Hex(9, 0)), Shrine(id: 2, kind: .moonwell, position: unit.position)]
        XCTAssertEqual(SpokenOrders.place("the Moonwell", near: unit.position, in: state)?.at, unit.position)
        // A strike reads its target and its company the other way about.
        let struck = SpokenOrders.read("STRIKE the Moonwell WITH C1", in: state, player: me)
        XCTAssertEqual(struck.first?.command, .attack(unit: unit.id, target: unit.position))
        XCTAssertNotNil(struck.first?.why, "Nothing there to strike: the realm says why")
    }
}
