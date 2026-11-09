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
        // A company named as every line names it: a tier for the companies
        // of war, none for Lanterns and Founders, who have none to tell,
        // where run 755's phone chart said "Lanterns I" and "Founders I".
        XCTAssertEqual(UnitKind.spear.named(tier: 2), "Spears II")
        XCTAssertEqual(UnitKind.mangonel.named(tier: 5), "Mangonels V")
        XCTAssertEqual(UnitKind.lantern.named(tier: 1), "Lanterns")
        XCTAssertEqual(UnitKind.founder.named(tier: 1), "Founders")
        for kind in UnitKind.allCases {
            XCTAssertEqual(kind.named(tier: 1) == kind.title, !kind.hasTiers, "\(kind)")
        }
        var founded = state
        let founder = Unit(id: founded.takeID(), kind: .founder, owner: me, position: try XCTUnwrap(state.seat(of: me)).position)
        founded.units.append(founder)
        XCTAssertEqual(SpokenOrders.named(founder, in: founded), "Founders \(founded.placeName(of: founder.position))")
        XCTAssertFalse(SpokenOrders.briefing(for: founded, player: me).contains("Founders I "))
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

    /// The fire in the blackwood from the book: a company standing in
    /// blackwood it may set alight is told so in the briefing, the wind with
    /// it, and KINDLE sets it alight; once it burns there, the line is told
    /// why not in the realm's own words.
    func testTheBlackwoodIsSetAlightFromTheBook() throws {
        var state = GameState(settings: GameSettings(seedText: "fire in the blackwood", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let sites = Set(state.sitesInLand.map(\.position))
        let owners = state.territory()
        let wood = try XCTUnwrap(state.map.hexes.filter { hex in
            state.isBlackwood(hex) && state.hold(at: hex) == nil && !sites.contains(hex) && state.unit(at: hex) == nil
                && (state.territoryOwner(of: hex, in: owners) ?? me) == me
        }.min { ($0.distance(to: seat), $0.q, $0.r) < ($1.distance(to: seat), $1.q, $1.r) })
        let placed = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: me, near: wood))
        let index = try XCTUnwrap(state.unitIndex(placed.id))
        state.units[index].position = wood
        state.units[index].movesLeft = state.movement(of: state.units[index])
        let unit = try XCTUnwrap(state.unit(placed.id))
        XCTAssertNil(state.kindleRefusal(unit.id, as: me))
        let companies = SpokenOrders.companies(in: state, player: me)
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == unit.id }) + 1)"
        // The briefing tells the model the fire is there to order, and the
        // wind, each company that may set the wood alight and no other.
        let briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        let told = "\(handle): \(SpokenOrders.named(unit, in: state)), \(GameState.counted(state.troops(of: unit))) troops, in blackwood it may set alight (KINDLE)"
        XCTAssertTrue(briefing.contains(told), "\(briefing)")
        XCTAssertTrue(briefing.contains("This watch \(state.windSaid)."), "\(briefing)")
        XCTAssertEqual(briefing.filter { $0.hasSuffix("(KINDLE)") }.count,
                       companies.prefix(SpokenOrders.briefedCompanies).filter { state.isBlackwood($0.position) && state.kindleRefusal($0.id, as: me) == nil }.count)
        let line = try XCTUnwrap(SpokenOrders.read("KINDLE \(handle)", in: state, player: me).first)
        XCTAssertEqual(line.command, .kindle(unit: unit.id))
        XCTAssertNil(line.why)
        XCTAssertEqual(line.told, "Your \(SpokenOrders.named(unit, in: state)) set the wood alight.")
        // Burning there, the same line is told why not, and the briefing no
        // longer offers it.
        var burning = state
        _ = try burning.perform(.kindle(unit: unit.id), as: me)
        let again = try XCTUnwrap(SpokenOrders.read("kindle \(handle)", in: burning, player: me).first)
        XCTAssertEqual(again.command, .kindle(unit: unit.id))
        XCTAssertEqual(again.why, RuleError.burntGround.description)
        let after = SpokenOrders.briefing(for: burning, player: me).split(separator: "\n")
        XCTAssertFalse(after.contains { $0.hasPrefix("\(handle): ") && $0.hasSuffix("(KINDLE)") })
        XCTAssertTrue(SpokenOrders.forms.contains("KINDLE <company>"))
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

    /// Standing orders, for the caretaker that keeps the House while its
    /// keeper is away, read from the book's WHILE AWAY lines.
    func testStandingOrdersAreReadFromTheBook() throws {
        var state = world()
        let me = state.player
        let lines = SpokenOrders.read("""
        WHILE AWAY MUSTER Bows
        WHILE AWAY RAISE the Walls FIRST
        WHILE AWAY KEEP HOME
        WHILE AWAY MAKE NO PEACE
        WHILE AWAY PAY TRIBUTE.
        WHILE AWAY AS YOU SEE FIT
        """, in: state, player: me)
        XCTAssertEqual(lines.map(\.command), [.stand(.muster(.bow)), .stand(.raise(.walls)), .stand(.home), .stand(.peace(false)),
                                             .stand(.tribute(true)), .standDown])
        XCTAssertEqual(lines[0].told, "While you are away, your caretaker musters only \(UnitKind.bow.title).")
        XCTAssertEqual(lines[2].told, "While you are away, your caretaker keeps every company on your land.")
        XCTAssertEqual(lines[5].told, "While you are away, your caretaker keeps your House as it sees fit.")
        XCTAssertEqual(lines[5].why, RuleError.noStandingOrders.description, "None given yet to clear")
        XCTAssertTrue(lines.prefix(5).allSatisfy { $0.why == nil })
        for line in lines.prefix(5) { _ = try state.perform(try XCTUnwrap(line.command), as: me) }
        XCTAssertNil(SpokenOrders.read("WHILE AWAY AS YOU SEE FIT", in: state, player: me).first?.why, "Now there are some to clear")

        // What the book doesn't know, said so; a line of no form passed over.
        let wrong = SpokenOrders.read("""
        WHILE AWAY MUSTER Dragons
        WHILE AWAY RAISE a Tower
        WHILE AWAY MUSTER Lanterns
        WHILE AWAY DANCE
        WHILE ASLEEP KEEP HOME
        """, in: state, player: me)
        XCTAssertEqual(wrong.map(\.why), ["No company goes by the name Dragons.", "No work goes by the name a Tower.",
                                          RuleError.notACompanyOfWar.description])
        XCTAssertTrue(SpokenOrders.briefing(for: state, player: me).contains("WHILE AWAY KEEP HOME"))
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
