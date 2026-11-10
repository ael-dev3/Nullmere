import Foundation
@testable import NullmereCore
import XCTest
@testable import NullmereCompanionCore

/// The House's land on the phone, read from the keeper's view: the ground
/// about its seat as its House knows it, explored and seen as the realm
/// keeps it; what stands there marked by whose it is; and at a hex chosen,
/// what lies there and every order offered one the rules take as offered.
final class CompanionChartTests: XCTestCase {
    private func world() -> (GameState, Int) {
        var state = GameState(settings: GameSettings(seedText: "companion chart", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        return (state, me)
    }

    private func assertTaken(_ orders: [CompanionLedger.Order], in state: GameState, as house: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        for order in orders {
            XCTAssertNil(state.refusal(of: order.command, as: house), "\(order.title) offered but refused", file: file, line: line)
        }
    }

    /// The chart reaches from the House's seat past its farthest hold or
    /// company, each hex as the House knows it: explored and seen as the
    /// realm keeps them, unexplored land plain under the fog, and the
    /// House's own seat and companies marked as its own.
    func testTheChartIsTheHousesLandAsItsViewHoldsIt() throws {
        let (state, me) = world()
        let view = state.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        let seat = try XCTUnwrap(state.seat(of: me))
        XCTAssertEqual(chart.center, seat.position)
        let farthest = (state.holds(of: me).map(\.position) + state.units(of: me).map(\.position)).map { $0.distance(to: seat.position) }.max() ?? 0
        XCTAssertEqual(chart.radius, min(max(farthest + CompanionChart.margin, CompanionChart.leastRadius), CompanionChart.mostRadius))
        XCTAssertEqual(chart.cells.first?.hex, seat.position, "Spiralling out from its heart")
        XCTAssertEqual(chart.cells.map(\.hex), seat.position.spiral(chart.radius).filter { state.map.contains($0) })
        let seen = state.visibility(for: me)
        var unexplored = 0
        for cell in chart.cells {
            let index = try XCTUnwrap(state.map.index(of: cell.hex))
            XCTAssertEqual(cell.explored, state.houses[me].explored[index], "\(cell.hex)")
            XCTAssertEqual(cell.seen, seen[index], "\(cell.hex)")
            if cell.explored {
                XCTAssertEqual(cell.terrain, state.map[index].terrain, "Explored ground as it is")
            } else {
                unexplored += 1
                XCTAssertEqual(cell.terrain, GameState.unknown(state.map[index]).terrain, "Unexplored land plain, its water as it is")
            }
        }
        XCTAssertGreaterThan(unexplored, 0, "The House has ground still to explore")
        XCTAssertTrue(chart.contains(seat.position))
        XCTAssertFalse(chart.contains(seat.position + Hex(chart.radius + 1, 0)))

        let own = try XCTUnwrap(chart.marks.first { $0.id == "hold \(seat.id)" })
        XCTAssertEqual(own.thing, .seat)
        XCTAssertEqual(own.side, .own)
        XCTAssertEqual(own.name, "\(seat.name), your seat")
        for unit in state.units(of: me) {
            let mark = try XCTUnwrap(chart.marks.first { $0.id == "company \(unit.id)" })
            XCTAssertEqual(mark.hex, unit.position)
            XCTAssertEqual(mark.side, .own)
            XCTAssertEqual(mark.name, "Your \(unit.named), \(GameState.counted(state.troops(of: unit))) troops")
            // A tier only for the companies of war: never "Your Lanterns I".
            XCTAssertFalse(!unit.kind.hasTiers && mark.name.hasPrefix("Your \(unit.kind.title) I"), mark.name)
            // Its kind, for its mark to be drawn within it when close.
            XCTAssertEqual(mark.kind, unit.kind)
        }
        XCTAssertTrue(chart.marks.filter { $0.thing != .company }.allSatisfy { $0.kind == nil }, "a kind for companies alone")
        for mark in chart.marks {
            XCTAssertLessThanOrEqual(mark.hex.distance(to: chart.center), chart.radius, "\(mark.name) on the chart")
        }
        // Another House's companies only where the House sees them; its
        // holds wherever they stand, as every keeper knows the realm's holds.
        for mark in chart.marks where mark.thing == .company && mark.side != .own {
            XCTAssertTrue(try XCTUnwrap(chart.cells.first { $0.hex == mark.hex }).seen, "\(mark.name) seen")
        }
        for hold in state.holds where hold.owner != me && hold.position.distance(to: chart.center) <= chart.radius {
            let mark = try XCTUnwrap(chart.marks.first { $0.id == "hold \(hold.id)" })
            XCTAssertEqual(mark.side, .other, "At peace as the age begins")
            XCTAssertEqual(mark.name, "\(hold.name), \(state.houses[hold.owner].title)'s \(hold.isSeat ? "seat" : "hold")")
        }
        // The holds first, so what stands in the field is drawn over them.
        let things = chart.marks.map(\.thing)
        let lastHold = things.lastIndex { $0 == .seat || $0 == .hold } ?? -1
        XCTAssertFalse(things.prefix(lastHold + 1).contains(.company))
        XCTAssertEqual(chart, CompanionChart(world: view, player: me), "Read alike from the same view")
        // The shores' regions whose hearts lie on the chart, named as every map names them.
        let regions = (state.atlas?.regions ?? []).filter { $0.heart.distance(to: chart.center) <= chart.radius }
        XCTAssertEqual(chart.regions.map(\.name), regions.map(\.name))
        XCTAssertEqual(chart.regions.map(\.hex), regions.map(\.heart))
    }

    /// A lake with its streams and regions: the regions whose hearts lie on
    /// the chart written there, a company far afield taking it to its most.
    func testTheRegionsAboutTheSeatAreWrittenOnTheChart() throws {
        var state = GameState(settings: GameSettings(seedText: "companion chart regions", houseCount: 4, radius: 18, keepers: 1, rivers: true))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let afield = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: seat.position) == CompanionChart.mostRadius - CompanionChart.margin
                && state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let index = try XCTUnwrap(state.units.firstIndex { $0.owner == me })
        state.units[index].position = afield
        let chart = CompanionChart(world: state.view(for: me), player: me)
        XCTAssertEqual(chart.radius, CompanionChart.mostRadius)
        let expected = try XCTUnwrap(state.atlas).regions.filter { $0.heart.distance(to: seat.position) <= chart.radius }
        XCTAssertFalse(expected.isEmpty, "Regions within eighteen hexes of the seat")
        XCTAssertEqual(chart.regions.map(\.name), expected.map(\.name))
        for region in chart.regions {
            XCTAssertLessThanOrEqual(region.hex.distance(to: chart.center), chart.radius)
            XCTAssertTrue(try XCTUnwrap(state.atlas).regions.contains { $0.name == region.name && $0.heart == region.hex })
        }
    }

    /// Pinched out, the chart names the Houses at their seats as the Mac's
    /// map names them from afar: each whose seat lies on the chart and the
    /// House has seen, its own first, in the colour of how each stands to
    /// it; a seat it has not seen, none.
    func testTheHousesSeatsOnTheChartAreNamedTheKeepersOwnFirst() throws {
        var (state, me) = world()
        let seat = try XCTUnwrap(state.seat(of: me))
        let afield = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: seat.position) == CompanionChart.mostRadius - CompanionChart.margin
                && state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let index = try XCTUnwrap(state.units.firstIndex { $0.owner == me })
        state.units[index].position = afield
        let early = CompanionChart(world: state.view(for: me), player: me)
        XCTAssertEqual(early.houseNames.first, CompanionChart.HouseName(house: me, name: state.houses[me].name, seat: seat.position, side: .own))
        let unseen = state.houses.map(\.id).filter { other in
            other != me && state.seat(of: other).map { !state.isExplored($0.position, by: me) && $0.position.distance(to: seat.position) <= early.radius } == true
        }
        XCTAssertTrue(Set(early.houseNames.map(\.house)).isDisjoint(with: unseen), "a seat not seen, named")

        // Every seat seen: each on the chart named, in the rules' order.
        state.reveal(around: seat.position, range: 40, for: me)
        let view = state.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        let expected = view.namedFromAfar(by: me, around: chart.center).filter { $0.seat.distance(to: chart.center) <= chart.radius }
        XCTAssertGreaterThan(expected.count, 1, "another House's seat within the chart's reach")
        XCTAssertEqual(chart.houseNames.map(\.house), expected.map(\.house))
        XCTAssertEqual(chart.houseNames.first?.side, .own)
        for name in chart.houseNames {
            XCTAssertEqual(name.name, state.houses[name.house].name)
            XCTAssertEqual(name.seat, try XCTUnwrap(state.seat(of: name.house)).position)
            XCTAssertTrue(chart.contains(name.seat))
            XCTAssertEqual(chart.marks.first { $0.hex == name.seat && $0.thing == .seat }?.side, name.side, "named in its seat's colour")
        }
    }

    /// A House's companies marching far afield take the chart no further
    /// than its most, and a chart of a House of nothing lies about the lake.
    func testTheChartReachesNoFurtherThanItsMost() throws {
        var (state, me) = world()
        let seat = try XCTUnwrap(state.seat(of: me))
        let far = try XCTUnwrap(state.map.hexes.filter { hex in
            hex.distance(to: seat.position) > CompanionChart.mostRadius && state.map[hex]?.terrain.isPassable == true
                && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }.min { ($0.distance(to: seat.position), $0) < ($1.distance(to: seat.position), $1) })
        let index = try XCTUnwrap(state.units.firstIndex { $0.owner == me })
        state.units[index].position = far
        let chart = CompanionChart(world: state.view(for: me), player: me)
        XCTAssertEqual(chart.radius, CompanionChart.mostRadius)
        XCTAssertFalse(chart.contains(far))
        XCTAssertNil(chart.marks.first { $0.id == "company \(state.units[index].id)" }, "Off the chart, on the Army tab")

        let nobody = CompanionChart(world: state, player: state.houses.count + 3)
        XCTAssertEqual(nobody.center, .origin)
        XCTAssertEqual(nobody.radius, CompanionChart.leastRadius)
        XCTAssertTrue(nobody.cells.allSatisfy { !$0.explored && !$0.seen })
        XCTAssertFalse(nobody.marks.contains { $0.side == .own })
    }

    /// Houses at war are marked as foes, allies as allies, and a company of
    /// war beside a foe's is offered the strike the rules would take on it,
    /// a march to it refused and so never offered.
    func testFoesAndAlliesAreMarkedAndAFoeStruckFromTheChart() throws {
        var (state, me) = world()
        let others = state.houses.indices.filter { $0 != me }
        let seat = try XCTUnwrap(state.seat(of: me))
        let walker = Unit(id: -1, kind: .spear, owner: me, position: seat.position)
        let ally = try XCTUnwrap(others.first { other in
            state.seat(of: other).map { state.path(for: walker, to: $0.position) != nil } ?? false
        })
        let foe = try XCTUnwrap(others.first { $0 != ally })
        state.houses[ally].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Chartward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        XCTAssertTrue(state.areAllied(me, ally))
        _ = try state.declareWar(by: me, on: foe)

        // A spear of the House beside a spear of the foe's, out in the field.
        let field = try XCTUnwrap(seat.position.ring(3).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
                && hex.neighbors.contains { state.map[$0]?.terrain.isPassable == true && state.unit(at: $0) == nil && state.hold(at: $0) == nil }
        })
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: field))
        let beside = try XCTUnwrap(spear.position.neighbors.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
                && state.wild(at: hex) == nil && state.lair(at: hex) == nil
        })
        let theirs = try XCTUnwrap(state.placeUnit(.spear, for: foe, near: beside))
        XCTAssertEqual(theirs.position, beside)
        let view = state.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        let mark = try XCTUnwrap(chart.marks.first { $0.id == "company \(theirs.id)" }, "Seen beside the House's spear")
        XCTAssertEqual(mark.side, .foe)
        XCTAssertEqual(mark.name, "\(state.houses[foe].title)'s Spears I, \(GameState.counted(state.troops(of: theirs))) troops")
        if let allyHold = state.holds(of: ally).first(where: { chart.contains($0.position) }) {
            XCTAssertEqual(chart.marks.first { $0.id == "hold \(allyHold.id)" }?.side, .ally)
        }
        if let foeHold = state.holds(of: foe).first(where: { chart.contains($0.position) }) {
            XCTAssertEqual(chart.marks.first { $0.id == "hold \(foeHold.id)" }?.side, .foe)
        }

        let place = chart.place(at: beside, in: view, player: me)
        XCTAssertEqual(place.lines, [mark.name])
        XCTAssertTrue(place.companies.isEmpty, "None of the House's own there")
        XCTAssertNil(place.hold)
        let strike = try XCTUnwrap(place.strikes.first { $0.command == .attack(unit: spear.id, target: beside) }, "\(place.orders.map(\.title))")
        // The House's company by its name told apart from its others'.
        let ours = try XCTUnwrap(SpokenOrders.distinctNames(in: view, player: me)[spear.id])
        XCTAssertEqual(strike.title, "Strike \(state.houses[foe].title)'s \(SpokenOrders.named(theirs, in: view)) with the \(ours)")
        assertTaken(place.orders, in: view, as: me)
        // A company of the wilds struck from the chart, named as the map
        // labels it, the company sent after a comma of its own.
        var wilder = state
        let lair = try XCTUnwrap(spear.position.neighbors.first { hex in
            hex != beside && wilder.map[hex]?.terrain.isPassable == true && wilder.unit(at: hex) == nil && wilder.hold(at: hex) == nil
                && wilder.wild(at: hex) == nil && wilder.lair(at: hex) == nil
        })
        wilder.wilds = (wilder.wilds ?? []) + [Wild(id: wilder.takeID(), kind: .barrowkin, level: 2, position: lair, raised: wilder.watch)]
        let wild = wilder.view(for: me)
        let struck = try XCTUnwrap(CompanionChart(world: wild, player: me).place(at: lair, in: wild, player: me).strikes
            .first { $0.command == .attack(unit: spear.id, target: lair) })
        XCTAssertEqual(struck.title, "Strike Barrowkin, level II, with the \(try XCTUnwrap(SpokenOrders.distinctNames(in: wild, player: me)[spear.id]))")
        assertTaken([struck], in: wild, as: me)
        for march in place.marches {
            guard case .move(let id, let to) = march.command else { return XCTFail("\(march.title) is no march") }
            XCTAssertEqual(to, beside)
            XCTAssertEqual(view.unit(id)?.owner, me, "Only the House's own companies are marched")
        }
    }

    /// At the seat, the seat and what stands there, the House's hold and
    /// companies there given by their ids; on open ground nearby, its ground
    /// and the hold it lies by, and the House's companies marched there, the
    /// nearest first, as many as are offered, each taken by the rules; on
    /// unexplored ground, the same, the realm finding the true way.
    func testAPlaceSaysWhatLiesThereAndMarchesTheHousesCompaniesThere() throws {
        let (state, me) = world()
        let view = state.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        let seat = try XCTUnwrap(state.seat(of: me))

        let home = chart.place(at: seat.position, in: view, player: me)
        XCTAssertEqual(home.title, seat.name)
        XCTAssertTrue(home.lines.contains("\(seat.name), your seat"), "\(home.lines)")
        XCTAssertEqual(home.hold, seat.id)
        XCTAssertEqual(home.companies, state.units(of: me).filter { $0.position == seat.position }.map(\.id))
        assertTaken(home.orders, in: view, as: me)

        let open = try XCTUnwrap(chart.cells.first { cell in
            cell.explored && cell.terrain.isPassable && !cell.terrain.isWater && cell.hex.distance(to: seat.position) == 2
                && !chart.marks.contains { $0.hex == cell.hex }
        })
        let there = chart.place(at: open.hex, in: view, player: me)
        XCTAssertEqual(there.title, "\(open.terrain.title) by \(seat.name)")
        XCTAssertEqual(there.lines, ["Nothing your House knows of stands here."])
        XCTAssertTrue(there.companies.isEmpty)
        XCTAssertNil(there.hold)
        let marches = there.marches
        XCTAssertEqual(there.orders, there.strikes + there.calls + there.gathers + there.marches + there.raisings.flatMap(\.orders))
        XCTAssertTrue(marches.allSatisfy { if case .move = $0.command { return true }; return false })
        XCTAssertTrue(there.strikes.isEmpty && there.calls.isEmpty && there.gathers.isEmpty, "Nothing there to strike, rally on or gather")
        XCTAssertFalse(marches.isEmpty, "The House's companies may march there")
        XCTAssertLessThanOrEqual(marches.count, CompanionChart.offered)
        assertTaken(there.orders, in: view, as: me)
        let marched = marches.compactMap { order -> NullmereCore.Unit? in
            guard case .move(let id, let to) = order.command, to == open.hex else { return nil }
            return state.unit(id)
        }
        XCTAssertEqual(marched.count, marches.count, "Each to the hex chosen")
        XCTAssertEqual(marched.map { $0.position.distance(to: open.hex) }, marched.map { $0.position.distance(to: open.hex) }.sorted(), "The nearest first")
        for (unit, order) in zip(marched, marches) {
            XCTAssertEqual(order.title, "March the \(SpokenOrders.named(unit, in: view)) here")
        }

        let fogged = try XCTUnwrap(chart.cells.first { cell in !cell.explored && !cell.terrain.isWater && !chart.marks.contains { $0.hex == cell.hex } })
        let unknown = chart.place(at: fogged.hex, in: view, player: me)
        XCTAssertTrue(unknown.title.hasPrefix("Unexplored ground"), unknown.title)
        XCTAssertEqual(unknown.lines, ["Your House hasn't explored this ground."])
        assertTaken(unknown.orders, in: view, as: me)

        // Bound there already, a company isn't offered the march again.
        var bound = state
        let first = try XCTUnwrap(marched.first)
        _ = try bound.perform(.move(unit: first.id, to: open.hex), as: me)
        let boundView = bound.view(for: me)
        let again = CompanionChart(world: boundView, player: me).place(at: open.hex, in: boundView, player: me)
        XCTAssertFalse(again.orders.contains { $0.command == .move(unit: first.id, to: open.hex) && bound.unit(first.id)?.position != open.hex })
    }

    /// What may be raised at a hex is offered from the chart as the Mac's
    /// ground panel offers it, each said in its words and taken by the
    /// rules: the seat raised anew, and a watchfire, on the House's own
    /// open ground; a
    /// standard of its alliance near its seat; a hand lent by an ally to
    /// the standard as it rises; and once it stands, the leader's
    /// storehouse and yards on the alliance's land, which the ally may not
    /// raise.
    func testWhatMayBeRaisedIsOfferedFromTheChart() throws {
        var (state, me) = world()
        let seat = try XCTUnwrap(state.seat(of: me))
        state.reveal(around: seat.position, range: 7, for: me)
        // In no alliance: the seat, raised anew on the House's own open ground.
        let ground = try XCTUnwrap(seat.position.spiral(3).first { state.seatMoveRefusal(to: $0, as: me) == nil })
        let view = state.view(for: me)
        let place = CompanionChart(world: view, player: me).place(at: ground, in: view, player: me)
        // And a watchfire, on the House's own open ground as the seat is.
        XCTAssertEqual(place.raisings.map(\.said), [Watchfire.explained, GameState.seatMoveSaid])
        XCTAssertEqual(place.raisings.first?.orders.map(\.title), ["Light a watchfire, for \(Watchfire.cost)"])
        XCTAssertEqual(place.raisings.last?.orders.map(\.title), ["Raise the seat here, for \(GameState.seatMoveCost)"])
        assertTaken(place.orders, in: view, as: me)

        // Leading an alliance with an ally: a standard near its seat.
        _ = try state.perform(.foundAlliance(name: "The Stone Accord"), as: me)
        let ally = (me + 1) % state.houses.count
        state.houses[ally].isPlayer = true
        state.houses[ally].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: alliance, accept: true), as: ally)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.standardRefusal(at: hex, by: me) == nil
        })
        let standing = CompanionChart.raisings(at: flag, in: state, player: me)
        XCTAssertTrue(standing.contains { $0.said == Standard.raiseSaid && $0.orders.map(\.title) == ["Raise a standard, for \(Standard.cost)"] },
                      "\(standing.map(\.said))")
        assertTaken(standing.flatMap(\.orders), in: state, as: me)

        // Raised, and rising: the ally lends a hand.
        _ = try state.perform(.raiseStandard(at: flag), as: me)
        let standard = try XCTUnwrap(state.standard(at: flag))
        let lending = try XCTUnwrap(CompanionChart.raisings(at: flag, in: state, player: ally).first { $0.said == standard.risingSaid })
        XCTAssertEqual(lending.orders.map(\.title), ["Lend a hand, for \(Standard.helpCost)"])
        XCTAssertEqual(lending.orders.first?.command, .helpStandard(standard: standard.id))
        assertTaken(lending.orders, in: state, as: ally)

        // Standing whole: the leader's storehouse and yards on its land.
        for index in (state.standards ?? []).indices { state.standards![index].built = Standard.raising }
        let land = try XCTUnwrap(flag.spiral(Standard.reach).first { state.storehouseRefusal(at: $0, by: me) == nil })
        let raisings = CompanionChart.raisings(at: land, in: state, player: me)
        XCTAssertTrue(raisings.contains { $0.said == Storehouse.raiseSaid && $0.orders.map(\.title) == ["Raise the storehouse, for \(Storehouse.cost)"] },
                      "\(raisings.map(\.said))")
        let yards = Resource.allCases.filter { state.yardRefusal($0, at: land, by: me) == nil }
        XCTAssertEqual(raisings.first { $0.said == Yard.raiseSaid }?.orders.map(\.title) ?? [],
                       yards.map { "Raise a \(Yard.title(of: $0).lowercased()), for \(Yard.cost)" })
        XCTAssertEqual(raisings.contains { $0.said == AllianceHall.raiseSaid }, state.hallRefusal(at: land, by: me) == nil)
        assertTaken(raisings.flatMap(\.orders), in: state, as: me)
        let theirs = CompanionChart.raisings(at: land, in: state, player: ally).map(\.said)
        XCTAssertFalse(theirs.contains(Storehouse.raiseSaid) || theirs.contains(Yard.raiseSaid) || theirs.contains(AllianceHall.raiseSaid),
                       "Only the leader raises the alliance's works: \(theirs)")
    }

    /// The chart shows the alliances' land as the Mac's map does: each hex
    /// under the keeper's alliance's standards its alliance's, the land's
    /// edges where it meets other ground, and a place there saying whose it
    /// is; another alliance's land only once the House has explored it.
    func testTheChartShowsTheAlliancesLand() throws {
        var (state, me) = world()
        _ = try state.perform(.foundAlliance(name: "The Near Accord"), as: me)
        let sworn = try XCTUnwrap(state.alliance(of: me)).id
        let seat = try XCTUnwrap(state.seat(of: me))
        let spot = try XCTUnwrap(seat.position.spiral(2).first { $0.distance(to: seat.position) == 2 && state.map[$0] != nil && state.hold(at: $0) == nil })
        var standard = Standard(id: state.takeID(), alliance: sworn, raisedBy: me, position: spot, raised: state.watch)
        standard.built = Standard.raising
        state.standards = state.standardsStanding + [standard]
        var view = state.view(for: me)
        var chart = CompanionChart(world: view, player: me)
        let land = Set(chart.cells.filter { $0.alliance == .ally }.map(\.hex))
        XCTAssertTrue(land.contains(spot))
        for cell in chart.cells {
            XCTAssertEqual(cell.alliance, view.allianceLand(at: cell.hex).map { $0 == sworn ? .ally : .other }, "\(cell.hex)")
        }
        XCTAssertTrue(land.allSatisfy { $0.distance(to: spot) <= Standard.reach })
        XCTAssertFalse(chart.allianceBorders.isEmpty)
        for border in chart.allianceBorders {
            XCTAssertTrue(land.contains(border.hex), "an edge of the land from within it")
            XCTAssertFalse(land.contains(border.beyond), "to ground beyond it")
            XCTAssertEqual(border.side, .ally)
        }
        XCTAssertTrue(chart.place(at: spot, in: view, player: me).lines.contains("On the land of The Near Accord, your alliance."),
                      "\(chart.place(at: spot, in: view, player: me).lines)")
        let away = try XCTUnwrap(chart.cells.first { $0.alliance == nil }?.hex)
        XCTAssertFalse(chart.place(at: away, in: view, player: me).lines.contains { $0.hasPrefix("On the land of") })

        // Another alliance's standard on the chart, on ground the House has
        // not explored: not shown until it has.
        let other = try XCTUnwrap(state.houses.indices.first { $0 != me && state.alliance(of: $0) == nil })
        _ = try state.perform(.foundAlliance(name: "The Far Pact"), as: other)
        let theirs = try XCTUnwrap(state.alliance(of: other)).id
        let far = try XCTUnwrap(chart.cells.filter { state.hold(at: $0.hex) == nil && state.map[$0.hex] != nil }
            .max { ($0.hex.distance(to: spot), $1.hex.q, $1.hex.r) < ($1.hex.distance(to: spot), $0.hex.q, $0.hex.r) }?.hex)
        XCTAssertGreaterThan(far.distance(to: spot), 2 * Standard.reach, "the two alliances' lands apart")
        for hex in far.spiral(Standard.reach) {
            if let index = state.map.index(of: hex) { state.houses[me].explored[index] = false }
        }
        var foreign = Standard(id: state.takeID(), alliance: theirs, raisedBy: other, position: far, raised: state.watch)
        foreign.built = Standard.raising
        state.standards = state.standardsStanding + [foreign]
        view = state.view(for: me)
        chart = CompanionChart(world: view, player: me)
        XCTAssertFalse(chart.cells.contains { $0.alliance == .other }, "not over ground the House hasn't explored")
        state.reveal(around: far, range: Standard.reach, for: me)
        view = state.view(for: me)
        chart = CompanionChart(world: view, player: me)
        XCTAssertEqual(chart.cells.first { $0.hex == far }?.alliance, .other)
        XCTAssertTrue(chart.allianceBorders.contains { $0.side == .other && $0.hex.distance(to: far) <= Standard.reach })
        XCTAssertTrue(chart.place(at: far, in: view, player: me).lines.contains("On the land of The Far Pact."),
                      "\(chart.place(at: far, in: view, player: me).lines)")
    }

    /// On the alliance's land beyond the House's own, the seat raised anew
    /// is offered from the chart in its own words, for its dearer moonsalt,
    /// as the Mac's ground panel offers it.
    func testTheSeatIsOfferedOnTheAlliancesLand() throws {
        var (state, me) = world()
        _ = try state.perform(.foundAlliance(name: "The Far Accord"), as: me)
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        let territory = state.territory()
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isSettleable == true && state.territoryOwner(of: hex, in: territory) == nil
                && !state.holds.contains { $0.position.distance(to: hex) < 3 } && state.shrine(at: hex) == nil
                && state.unit(at: hex) == nil && state.site(at: hex) == nil
                && hex.neighbors.contains { state.map[$0] != nil && state.hold(at: $0) == nil }
        })
        let spot = try XCTUnwrap(ground.neighbors.first { state.map[$0] != nil && state.hold(at: $0) == nil })
        var standard = Standard(id: state.takeID(), alliance: alliance, raisedBy: me, position: spot, raised: state.watch)
        standard.built = Standard.raising
        state.standards = state.standardsStanding + [standard]
        state.reveal(around: ground, range: 0, for: me)
        XCTAssertNil(state.seatMoveRefusal(to: ground, as: me))
        let view = state.view(for: me)
        let raisings = CompanionChart.raisings(at: ground, in: view, player: me)
        let raising = try XCTUnwrap(raisings.first { $0.said == GameState.seatMoveAllianceSaid }, "\(raisings.map(\.said))")
        XCTAssertFalse(raisings.contains { $0.said == GameState.seatMoveSaid }, "Said once, in the alliance's words")
        XCTAssertEqual(raising.orders.map(\.title), ["Raise the seat here, for \(GameState.seatMoveAllianceCost)"])
        XCTAssertEqual(raising.orders.map(\.command), [.raiseSeat(at: ground)])
        assertTaken(raising.orders, in: view, as: me)
        assertTaken(raising.orders, in: state, as: me)
    }

    /// At a site of the land the House has explored, its companies of war
    /// are offered to gather there as the rules would send them; and on a
    /// foe's hold, sworn to an alliance with a Muster Hall, a rally called.
    func testASiteIsGatheredAndAFoeRalliedOnFromTheChart() throws {
        var (state, me) = world()
        // The land's sites come up as the watches turn.
        for _ in 0..<8 where state.sitesInLand.isEmpty { _ = state.endWatch() }
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        let seat = try XCTUnwrap(state.seat(of: me))
        let site = try XCTUnwrap(state.sitesInLand.min { ($0.position.distance(to: seat.position), $0.id) < ($1.position.distance(to: seat.position), $1.id) })
        state.reveal(around: site.position, range: 0, for: me)
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: seat.position))
        let view = state.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        let place = chart.place(at: site.position, in: view, player: me)
        let gathers = place.gathers
        XCTAssertTrue(gathers.allSatisfy { if case .gather = $0.command { return true }; return false })
        let gather = try XCTUnwrap(gathers.first { $0.command == .gather(unit: spear.id, site: site.id) }, "\(place.orders.map(\.title))")
        let ours = try XCTUnwrap(SpokenOrders.distinctNames(in: view, player: me)[spear.id])
        XCTAssertEqual(gather.title, "Gather \(site.store.title.lowercased()) here with the \(ours)")
        XCTAssertLessThanOrEqual(gathers.count, CompanionChart.offered)
        assertTaken(place.orders, in: view, as: me)
        if chart.contains(site.position) {
            XCTAssertTrue(place.lines.contains { $0.hasPrefix("\(site.title) \(BuildingKind.numeral(site.level))") }, "\(place.lines)")
        }

        let foe = try XCTUnwrap(state.houses.indices.first { $0 != me })
        _ = try state.declareWar(by: me, on: foe)
        let foeSeat = try XCTUnwrap(state.seat(of: foe))
        state.reveal(around: foeSeat.position, range: 0, for: me)
        _ = try state.perform(.foundAlliance(name: "Chartrally"), as: me)
        let seatIndex = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[seatIndex].levels[.musterHall] = 1
        let warView = state.view(for: me)
        let onFoe = CompanionChart(world: warView, player: me).place(at: foeSeat.position, in: warView, player: me)
        XCTAssertEqual(onFoe.title, foeSeat.name)
        let call = try XCTUnwrap(onFoe.orders.first { $0.command == .callRally(from: seat.id, against: foeSeat.id, watches: CompanionLedger.rallyGathering) },
                                 "\(onFoe.orders.map(\.title))")
        XCTAssertEqual(call.title, "Rally on \(foeSeat.name)")
        assertTaken(onFoe.orders, in: warView, as: me)
        XCTAssertEqual(onFoe.calls, [call], "The rally on what lies there alone")
    }

    /// Beside another House's hold, the House's Lanterns are offered to
    /// scout it, as the rules would send them, its report to follow; none
    /// offered at the House's own seat.
    func testAHoldIsScoutedFromTheChart() throws {
        var (state, me) = world()
        let other = try XCTUnwrap(state.holds.first { $0.owner != me })
        let beside = try XCTUnwrap(other.position.neighbors.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let lantern = try XCTUnwrap(state.placeUnit(.lantern, for: me, near: beside))
        XCTAssertLessThanOrEqual(lantern.position.distance(to: other.position), GameState.scoutReach)
        let view = state.view(for: me)
        let place = CompanionChart(world: view, player: me).place(at: other.position, in: view, player: me)
        let scout = try XCTUnwrap(place.scouts.first { $0.command == .scout(unit: lantern.id, hold: other.id) }, "\(place.orders.map(\.title))")
        XCTAssertEqual(scout.title, "Scout \(other.name) with the \(SpokenOrders.named(lantern, in: view))")
        XCTAssertEqual(place.orders, place.strikes + place.calls + place.scouts + place.gathers + place.marches)
        assertTaken(place.orders, in: view, as: me)
        let seat = try XCTUnwrap(state.seat(of: me))
        XCTAssertTrue(CompanionChart(world: view, player: me).place(at: seat.position, in: view, player: me).scouts.isEmpty, "Not its own hold")
    }

    /// Ground the House sees drawn in its own colour; explored but unseen,
    /// dimmed; unexplored land under the fog, its water showing through.
    func testEachCellIsShadedAsTheHouseKnowsIt() {
        for terrain in Terrain.allCases {
            let seen = CompanionChart.shade(of: .init(hex: .origin, terrain: terrain, explored: true, seen: true))
            let unseen = CompanionChart.shade(of: .init(hex: .origin, terrain: terrain, explored: true, seen: false))
            let fogged = CompanionChart.shade(of: .init(hex: .origin, terrain: terrain, explored: false, seen: false))
            XCTAssertEqual(unseen.red, seen.red * CompanionChart.unseenLight, accuracy: 1e-12, "\(terrain)")
            XCTAssertEqual(unseen.green, seen.green * CompanionChart.unseenLight, accuracy: 1e-12, "\(terrain)")
            XCTAssertEqual(unseen.blue, seen.blue * CompanionChart.unseenLight, accuracy: 1e-12, "\(terrain)")
            for value in [seen.red, seen.green, seen.blue] { XCTAssertTrue((0...1).contains(value)) }
            if terrain.isWater {
                XCTAssertEqual(fogged.blue, seen.blue * 0.6, accuracy: 1e-12, "\(terrain): water shows through the fog")
            } else {
                XCTAssertTrue(fogged == CompanionChart.fog, "\(terrain) under the fog")
            }
        }
        let shades = Terrain.allCases.map { CompanionChart.shade(of: .init(hex: .origin, terrain: $0, explored: true, seen: true)) }
        XCTAssertEqual(Set(shades.map { "\($0.red) \($0.green) \($0.blue)" }).count, Terrain.allCases.count, "Each ground its own colour")
    }

    /// The chart changes as the world does: a company marched is marked
    /// where it stands now.
    func testTheChartFollowsTheWorld() throws {
        var (state, me) = world()
        let view = state.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        let order = try XCTUnwrap(chart.place(at: try XCTUnwrap(chart.cells.first { cell in
            cell.explored && !cell.terrain.isWater && cell.terrain.isPassable && cell.hex.distance(to: chart.center) == 2
                && !chart.marks.contains { $0.hex == cell.hex }
        }).hex, in: view, player: me).orders.first { if case .move = $0.command { return true }; return false })
        guard case .move(let id, _) = order.command else { return XCTFail() }
        let before = try XCTUnwrap(state.unit(id)).position
        XCTAssertNil(chart.marks.first { $0.id == "company \(id)" }?.bound, "Standing, bound nowhere")
        _ = try state.perform(order.command, as: me)
        // On the march, the line of its march drawn to where it is bound.
        guard case .move(_, let target) = order.command else { return XCTFail() }
        let marching = CompanionChart(world: state.view(for: me), player: me)
        let line = marching.marks.first { $0.id == "company \(id)" }?.bound
        XCTAssertTrue(state.unit(id)?.position == target ? line == nil : line == target,
                      "Bound to its march's end while it marches, and to nowhere once there")
        _ = state.endWatch()
        let after = try XCTUnwrap(state.unit(id)).position
        XCTAssertNotEqual(after, before, "It marched")
        let moved = CompanionChart(world: state.view(for: me), player: me)
        XCTAssertEqual(moved.marks.first { $0.id == "company \(id)" }?.hex, after)
        XCTAssertNotEqual(moved, chart)
    }

    /// Whose land each hex lies in, by the holds' claims the keeper's view
    /// knows: the seat in the House's own; each land's edge drawn where it
    /// meets another House's or no one's, the House's own wherever it runs
    /// on the chart, another's only over ground the House has explored.
    func testTheHousesLandAndItsBordersAreCharted() throws {
        let (state, me) = world()
        let view = state.view(for: me)
        let chart = CompanionChart(world: view, player: me)
        let seat = try XCTUnwrap(view.seat(of: me))
        let cells = Dictionary(uniqueKeysWithValues: chart.cells.map { ($0.hex, $0) })
        XCTAssertEqual(cells[seat.position]?.land, .own, "The seat stands in the House's own land")
        let claims = view.territory()
        for cell in chart.cells {
            let index = try XCTUnwrap(view.map.index(of: cell.hex))
            let house = claims[index].flatMap { view.hold($0)?.owner }
            XCTAssertEqual(cell.land == .own, house == me, "\(cell.hex)")
            XCTAssertEqual(cell.land == nil, house == nil, "\(cell.hex)")
        }
        let own = chart.borders.filter { $0.side == .own }
        XCTAssertFalse(own.isEmpty, "The House's land has its edge on the chart")
        for border in chart.borders {
            XCTAssertEqual(cells[border.hex]?.land, border.side)
            XCTAssertTrue(border.hex.neighbors.contains(border.beyond))
            XCTAssertNotNil(cells[border.beyond], "Both sides of an edge on the chart")
            if border.side != .own {
                XCTAssertEqual(cells[border.hex]?.explored, true, "Another's edge only over ground the House has explored")
            }
        }
        for cell in chart.cells where cell.land == .own {
            for beyond in cell.hex.neighbors where cells[beyond] != nil && cells[beyond]?.land != .own {
                XCTAssertTrue(own.contains(CompanionChart.Border(hex: cell.hex, beyond: beyond, side: .own)),
                              "The edge between \(cell.hex) and \(beyond)")
            }
        }
    }
}

extension CompanionChartTests {
    /// A vigil's light on the water, near enough the seat, is marked on the
    /// phone's chart where it burns, named as the Mac names it; one beyond
    /// the chart's reach is not.
    func testAVigilBurningNearIsMarkedWhereItIs() throws {
        var state = GameState(settings: GameSettings(seedText: "companion chart vigils", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let water = try XCTUnwrap(state.map.hexes.filter { [.still, .shallows].contains(state.map[$0]?.terrain) }
            .min { ($0.distance(to: seat.position), $0.q, $0.r) < ($1.distance(to: seat.position), $1.q, $1.r) })
        let far = try XCTUnwrap(state.map.hexes.first { $0.distance(to: seat.position) > CompanionChart.mostRadius + 2 })
        let other = (me + 1) % state.houses.count
        state.vigils = [Vigil(id: 41, house: other, words: "For those who fell at the ford", fallen: 2, lit: state.watch, position: water),
                        Vigil(id: 42, house: me, words: "Ours", fallen: 1, lit: state.watch, position: far)]
        let chart = CompanionChart(world: state.view(for: me), player: me)
        let marked = chart.marks.filter { $0.thing == .vigil }
        XCTAssertEqual(marked.map(\.id), ["vigil 41"], "Only the one within the chart's reach")
        let mark = try XCTUnwrap(marked.first)
        XCTAssertEqual(mark.hex, water)
        XCTAssertEqual(mark.name, state.view(for: me).vigilTitle(state.vigils![0], for: me))
    }

    /// The plea waiting at one of the House's holds is marked on the phone's
    /// chart at that hold, who brings it named as the Mac names them.
    func testAPleaAtTheGateIsMarkedAtItsHold() throws {
        var state = GameState(settings: GameSettings(seedText: "companion chart plea", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.watch = Petition.from
        let seat = try XCTUnwrap(state.seat(of: me))
        state.holds[try XCTUnwrap(state.holdIndex(seat.id))].ward = 1
        XCTAssertTrue(CompanionChart(world: state.view(for: me), player: me).marks.allSatisfy { $0.thing != .plea }, "None while no plea waits")
        _ = state.bringPetitions()
        let petition = try XCTUnwrap(state.petition(of: me))
        let mark = try XCTUnwrap(CompanionChart(world: state.view(for: me), player: me).marks.first { $0.thing == .plea })
        XCTAssertEqual(mark.id, "plea \(petition.id)")
        XCTAssertEqual(mark.hex, seat.position)
        XCTAssertEqual(mark.side, .own)
        XCTAssertEqual(mark.name, "A plea at the gate: \(state.petitioner(of: petition))")
    }

    /// The ground the House's alliance has marked is on the phone's chart
    /// where it lies, in the mark's hue, said as the Mac says it; its leader
    /// marks ground and lifts a mark from the chart, by the rules' own
    /// refusals, and a House sworn to it only sees them.
    func testTheAlliancesMarksAreOnTheChartAndMadeFromIt() throws {
        var state = GameState(settings: GameSettings(seedText: "companion chart marks", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let ally = try XCTUnwrap(state.houses.indices.first { $0 != me })
        _ = try state.perform(.foundAlliance(name: "Lantern Oath"), as: me)
        let alliance = try XCTUnwrap(state.alliance(of: me))
        state.alliances![try XCTUnwrap(state.alliances?.firstIndex { $0.id == alliance.id })].members.append(ally)
        let seat = try XCTUnwrap(state.seat(of: me))
        let ground = try XCTUnwrap(seat.position.neighbors.first { hex in
            state.map.index(of: hex).map { state.houses[me].explored[$0] } ?? false
        })
        // Unmarked, its leader is offered every kind of mark there.
        let before = CompanionChart(world: state.view(for: me), player: me)
        let offered = try XCTUnwrap(before.place(at: ground, in: state.view(for: me), player: me).marking)
        XCTAssertEqual(offered.said, AllianceMark.explained)
        XCTAssertEqual(offered.orders.map(\.title), ["Mark: Gather here", "Mark: Strike here", "Mark: Hold this ground", "Mark: Beware"])
        assertTaken(offered.orders, in: state, as: me)
        XCTAssertNil(before.place(at: ground, in: state.view(for: ally), player: ally).marking, "A sworn House marks nothing")

        // Marked, the alliance's Houses see it where it lies.
        _ = try state.perform(.markGround(ground, .strike, words: "Before the moon"), as: me)
        let made = try XCTUnwrap(state.marksSeen(by: me).first)
        for (house, side) in [(me, CompanionChart.Side.own), (ally, .ally)] {
            let view = state.view(for: house)
            // Wherever it lies, the House's ledger says it with its alliance's own.
            let said = try XCTUnwrap(CompanionLedger(world: view, player: house).allianceOwn).lines
            XCTAssertEqual(said.last, view.marksSaid(of: alliance.id).last)
            XCTAssertEqual(said.last, "Strike here, \(view.placeName(of: ground)): “Before the moon”. \(view.markMaker(made))")
            // On the chart where the chart reaches it: always about the leader's own seat.
            let chart = CompanionChart(world: view, player: house)
            guard chart.contains(ground) else {
                XCTAssertNotEqual(house, me)
                XCTAssertFalse(chart.marks.contains { $0.thing == .allianceMark }, "Beyond the chart, on the ledger alone")
                continue
            }
            let mark = try XCTUnwrap(chart.marks.first { $0.thing == .allianceMark })
            XCTAssertEqual(mark.id, "alliance mark \(made.id)")
            XCTAssertEqual(mark.hex, ground)
            XCTAssertEqual(mark.side, side)
            XCTAssertEqual(mark.bids, .strike)
            XCTAssertEqual(mark.name, "The alliance's mark: Strike here: “Before the moon”")
            let place = chart.place(at: ground, in: view, player: house)
            XCTAssertTrue(place.lines.contains(mark.name))
            XCTAssertEqual(place.lines.last, view.markMaker(made))
            if house == me {
                let orders = try XCTUnwrap(place.marking).orders
                XCTAssertEqual(orders.last?.title, "Lift the alliance's mark")
                XCTAssertEqual(orders.last?.command, .unmarkGround(made.id))
                assertTaken(orders, in: state, as: me)
            } else {
                XCTAssertNil(place.marking, "Only its leader lifts it")
            }
        }
        // No other House sees it.
        let other = try XCTUnwrap(state.houses.indices.first { $0 != me && $0 != ally })
        XCTAssertFalse(CompanionChart(world: state.view(for: other), player: other).marks.contains { $0.thing == .allianceMark })
        // Each kind's hue its own.
        XCTAssertEqual(Set(AllianceMark.Kind.allCases.map { "\($0.hue)" }).count, AllianceMark.Kind.allCases.count)
    }
}
