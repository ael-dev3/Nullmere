import Foundation
@testable import NullmereCore
import XCTest
@testable import NullmereCompanionCore

/// What the phone lists of a House, read from the keeper's view: every
/// order it offers one the rules take as offered, and none it offers that
/// would do nothing; the stores, holds and words as the realm keeps them.
final class CompanionLedgerTests: XCTestCase {
    private func world() throws -> (GameState, Int) {
        var state = GameState(settings: GameSettings(seedText: "companion ledger", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        return (state, me)
    }

    /// Every order offered is one the rules would carry out as offered.
    private func assertTaken(_ orders: [CompanionLedger.Order], in state: GameState, as house: Int,
                             file: StaticString = #filePath, line: UInt = #line) {
        for order in orders {
            XCTAssertNil(state.refusal(of: order.command, as: house), "\(order.title) offered but refused", file: file, line: line)
        }
    }

    /// Two of the House's companies that would be named alike (the same
    /// kind and tier about the same place) are told apart on the phone,
    /// numbered in the order they were raised; a name no other shares is
    /// kept as it is; and the orders that name them name them so.
    func testCompaniesNamedAlikeAreToldApart() throws {
        var (state, me) = try world()
        let seat = try XCTUnwrap(state.seat(of: me))
        let first = Unit(id: state.takeID(), kind: .spear, owner: me, position: seat.position)
        let second = Unit(id: state.takeID(), kind: .spear, owner: me, position: seat.position)
        state.units.append(first)
        state.units.append(second)
        let plain = SpokenOrders.named(first, in: state)
        XCTAssertEqual(plain, SpokenOrders.named(second, in: state), "Alike by kind, tier and place")

        let names = SpokenOrders.distinctNames(in: state, player: me)
        XCTAssertEqual(Set(names.values).count, names.count, "Each of the House's companies its own name")
        XCTAssertEqual(names.count, state.units(of: me).count)
        let alike = state.units(of: me).filter { SpokenOrders.named($0, in: state) == plain }.sorted { $0.id < $1.id }
        XCTAssertGreaterThanOrEqual(alike.count, 2)
        for (index, unit) in alike.enumerated() {
            XCTAssertEqual(names[unit.id], "\(plain) (\(index + 1))", "Numbered in the order they were raised")
        }
        let counted = Dictionary(grouping: state.units(of: me)) { SpokenOrders.named($0, in: state) }
        for (name, units) in counted where units.count == 1 {
            XCTAssertEqual(names[units[0].id], name, "A name no other shares, as it is")
        }

        let ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(Set(ledger.companies.map(\.name)).count, ledger.companies.count, "Told apart on the phone")
        XCTAssertEqual(ledger.companies.first { $0.id == second.id }?.name, names[second.id])
        if let commander = ledger.commanders.first(where: { !$0.leads.isEmpty }) {
            XCTAssertEqual(Set(commander.leads.map(\.title)).count, commander.leads.count, "\(commander.leads.map(\.title))")
        }
        // On the chart, marched elsewhere by the same names.
        let view = state.view(for: me)
        let ground = try XCTUnwrap(seat.position.neighbors.first { view.map[$0]?.terrain.isPassable == true && view.map[$0]?.terrain.isWater == false })
        let place = CompanionChart(world: view, player: me).place(at: ground, in: view, player: me)
        let viewNames = SpokenOrders.distinctNames(in: view, player: me)
        for march in place.marches {
            guard case .move(let unit, _) = march.command, let name = viewNames[unit] else { return XCTFail("\(march.title)") }
            XCTAssertEqual(march.title, "March the \(name) here")
        }
        XCTAssertEqual(Set(place.marches.map(\.title)).count, place.marches.count)
    }

    /// The House's studies on the phone: none before it has an Archive;
    /// then each it may begin, at its next grade, one the rules take as
    /// offered; and one under way said with how long it has to go, none
    /// offered beside it.
    func testThePhoneOffersTheStudiesTheHouseMayBegin() throws {
        var (state, me) = try world()
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.archive] = 0
        XCTAssertTrue(CompanionLedger(world: state, player: me).studies.isEmpty, "No Archive, no study")
        state.holds[seat].levels[.archive] = 1
        let ledger = CompanionLedger(world: state, player: me)
        XCTAssertNil(ledger.studying)
        XCTAssertFalse(ledger.studies.isEmpty)
        assertTaken(ledger.studies, in: state, as: me)
        for order in ledger.studies {
            guard case .study(let study) = order.command else { return XCTFail("\(order.title) is no study") }
            XCTAssertEqual(order.title, "Study \(study.title) I", "Its first grade")
        }
        let first = ledger.studies[0]
        guard case .study(let begun) = first.command else { return XCTFail() }
        _ = try state.perform(first.command, as: me)
        let studying = CompanionLedger(world: state, player: me)
        XCTAssertTrue(studying.studies.isEmpty, "None beside one under way")
        let watches = try XCTUnwrap(state.houses[me].research.pursuit).watchesLeft
        XCTAssertEqual(studying.studying, "Studying \(begun.title) I, \(CompanionLedger.watches(watches))")
        XCTAssertNotEqual(studying, ledger, "The phone's ledger changes with it")
    }

    func testTheHousesWorksAndMustersAreThoseTheRulesTake() throws {
        let (state, me) = try world()
        let ledger = CompanionLedger(world: state, player: me)
        let seat = try XCTUnwrap(ledger.holds.first(where: \.isSeat))
        XCTAssertEqual(ledger.holds.first?.id, seat.id, "The seat first")
        XCTAssertTrue(seat.works.contains { $0.title == "Raise Granary I" }, "\(seat.works.map(\.title))")
        XCTAssertFalse(seat.musters.isEmpty)
        let hold = try XCTUnwrap(state.hold(seat.id))
        assertTaken(seat.works + seat.musters, in: state, as: me)
        // Raising one, the hold offers no other work until it is done; one
        // mustering, no other muster.
        var raising = state
        _ = try raising.perform(.build(hold: hold.id, kind: .granary), as: me)
        let busy = try XCTUnwrap(CompanionLedger(world: raising, player: me).holds.first(where: \.isSeat))
        XCTAssertTrue(busy.works.isEmpty)
        XCTAssertTrue(busy.work.contains { $0.hasPrefix("Raising Granary I,") }, "\(busy.work)")
        let muster = try XCTUnwrap(seat.musters.first)
        _ = try raising.perform(muster.command, as: me)
        let mustering = try XCTUnwrap(CompanionLedger(world: raising, player: me).holds.first(where: \.isSeat))
        XCTAssertTrue(mustering.musters.isEmpty)
        XCTAssertTrue(mustering.work.contains { $0.hasPrefix("Mustering ") }, "\(mustering.work)")
        // A House with nothing in its stores raises and musters nothing.
        var poor = state
        poor.houses[me].stock = .zero
        let bare = try XCTUnwrap(CompanionLedger(world: poor, player: me).holds.first(where: \.isSeat))
        XCTAssertTrue(bare.works.isEmpty)
        XCTAssertTrue(bare.musters.isEmpty)
    }

    /// The House's commanders as the Mac's board orders them, each with
    /// how they stand; one held prisoner may not be asked for counsel.
    func testTheHousesCommandersAndHowTheyStand() throws {
        var (state, me) = try world()
        let first = try XCTUnwrap(state.commanders(of: me).first, "Every House begins with a commander")
        let ledger = CompanionLedger(world: state, player: me)
        let listed = try XCTUnwrap(ledger.commanders.first { $0.id == first.id })
        XCTAssertEqual(listed.name, first.name)
        XCTAssertEqual(listed.title, "\(first.archetype.title) · level \(first.level)")
        XCTAssertTrue(listed.canCounsel)
        if let unit = state.company(ledBy: first.id) {
            XCTAssertEqual(listed.standing, "Leads the \(SpokenOrders.named(unit, in: state))")
        } else {
            XCTAssertEqual(listed.standing, "Free to lead a company of war")
        }
        // Wounded, and then taken.
        let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == first.id })
        state.commanders?[index].woundedUntil = state.watch + 3
        XCTAssertEqual(CompanionLedger(world: state, player: me).commanders.first { $0.id == first.id }?.standing,
                       "Wounded: whole again in 3 watches")
        let captor = (me + 1) % state.houses.count
        state.commanders?[index].captive = Captivity(by: captor, since: state.watch, questioned: 0)
        let held = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == first.id })
        XCTAssertEqual(held.standing, "Held prisoner by \(state.houses[captor].title)")
        XCTAssertFalse(held.canCounsel)
        XCTAssertNotEqual(CompanionLedger(world: state, player: me), ledger, "A commander's standing changes the ledger")
    }

    /// The Houses nearest the keeper's seat on the phone, the nearest first:
    /// each with how it stands with the keeper's House, the envoys the rules
    /// would carry and war where it may be declared; peace offered once at
    /// war, and war no longer; an ally named as sworn to the alliance.
    func testTheHousesNearestAreDealtWithFromThePhone() throws {
        var (state, me) = try world()
        let home = try XCTUnwrap(state.seat(of: me)).position
        var ledger = CompanionLedger(world: state, player: me)
        let others = state.houses.indices.filter { $0 != me }
        XCTAssertEqual(Set(ledger.dealings.map(\.id)), Set(others), "Every House of a small lake")
        let distances = ledger.dealings.map { try? XCTUnwrap(state.seat(of: $0.id)).position.distance(to: home) }
        XCTAssertEqual(distances, distances.sorted { ($0 ?? 0) < ($1 ?? 0) }, "The nearest first")
        for dealing in ledger.dealings {
            XCTAssertEqual(dealing.name, state.houses[dealing.id].title)
            XCTAssertEqual(dealing.stance, "At peace with your House")
            XCTAssertEqual(dealing.war?.command, .declareWar(on: dealing.id))
            XCTAssertFalse(dealing.envoys.contains { $0.command == .propose(.peace, to: dealing.id) }, "No peace offered at peace")
            XCTAssertEqual(dealing.gifts.map(\.title), Resource.allCases.map { resource in
                "Send \(resource == .moonsalt ? 25 : 100) \(resource.title.lowercased()) to \(dealing.name)"
            }, "Each store, as much as a House takes in a watch")
            assertTaken(dealing.envoys + dealing.gifts + [try XCTUnwrap(dealing.war)], in: state, as: me)
        }
        // Gifts given up to what the House takes in a watch: no more to it then.
        let given = try XCTUnwrap(ledger.dealings.first)
        _ = try state.perform(try XCTUnwrap(given.gifts.first).command, as: me)
        XCTAssertTrue(try XCTUnwrap(CompanionLedger(world: state, player: me).dealings.first { $0.id == given.id }).gifts.isEmpty)

        XCTAssertEqual(CompanionLedger.dealingsLine(ledger.dealings), "The \(others.count) Houses nearest", "Folded behind its line")
        let foe = try XCTUnwrap(ledger.dealings.first).id
        _ = try state.declareWar(by: me, on: foe)
        ledger = CompanionLedger(world: state, player: me)
        let atWar = try XCTUnwrap(ledger.dealings.first { $0.id == foe })
        XCTAssertEqual(atWar.stance, "At war with your House")
        XCTAssertNil(atWar.war, "At war already")
        XCTAssertTrue(atWar.gifts.isEmpty, "No gifts to a House at war")
        let peace = try XCTUnwrap(atWar.envoys.first { $0.command == .propose(.peace, to: foe) }, "\(atWar.envoys.map(\.title))")
        XCTAssertEqual(peace.title, "Offer peace to \(state.houses[foe].title)")
        assertTaken(atWar.envoys, in: state, as: me)

        let ally = try XCTUnwrap(others.first { $0 != foe })
        state.houses[ally].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Dealward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        XCTAssertTrue(state.areAllied(me, ally))
        let sworn = try XCTUnwrap(CompanionLedger(world: state, player: me).dealings.first { $0.id == ally })
        XCTAssertEqual(sworn.stance, "Sworn to your alliance")
        XCTAssertEqual(CompanionLedger.dealingsLine(CompanionLedger(world: state, player: me).dealings),
                       "The \(others.count) Houses nearest: 1 at war with yours, 1 of your alliance")
        XCTAssertEqual(CompanionLedger.dealingsLine(Array(ledger.dealings.prefix(1))), "The House nearest: 1 at war with yours")
        if let war = sworn.war { assertTaken([war], in: state, as: me) }
        XCTAssertNotEqual(CompanionLedger(world: state, player: me), ledger)
    }

    /// The alliance's studies from the phone, as the Mac's Alliance panel
    /// keeps them: none sworn to no alliance; the leader offered each study
    /// at its next grade, none given toward before one is pursued; then what
    /// is still to give, all of it or each store lacking, each gift one the
    /// rules take; a grade paid for learned at once, the next pursued; a
    /// House short of every store offered nothing to give.
    func testTheAlliancesStudiesAreFundedFromThePhone() throws {
        var (state, me) = try world()
        let sworn = CompanionLedger(world: state, player: me)
        XCTAssertTrue(sworn.allianceLore.isEmpty && sworn.pursuits.isEmpty && sworn.allianceGifts.isEmpty, "Sworn to no alliance")
        _ = try state.perform(.foundAlliance(name: "Studyward"), as: me)
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.allianceLore, ["Your alliance pursues no study."])
        XCTAssertTrue(ledger.allianceGifts.isEmpty, "Nothing pursued, nothing to give toward")
        XCTAssertEqual(ledger.pursuits.map(\.title), AllianceStudy.allCases.map { "Pursue \($0.title) I" })
        assertTaken(ledger.pursuits, in: state, as: me)

        let study = try XCTUnwrap(AllianceStudy.allCases.first)
        _ = try state.perform(.pursueAllianceStudy(study), as: me)
        ledger = CompanionLedger(world: state, player: me)
        let cost = study.cost(grade: 1)
        XCTAssertEqual(ledger.allianceLore, ["Pursuing \(study.title) I: \(cost) still to give"])
        XCTAssertFalse(ledger.pursuits.contains { $0.command == .pursueAllianceStudy(study) }, "Not the study pursued")
        let all = try XCTUnwrap(ledger.allianceGifts.first)
        XCTAssertEqual(all.title, "Give all \(study.title) I still needs: \(cost)")
        XCTAssertEqual(all.command, .giveToAlliance(cost))
        let lacking = Resource.allCases.filter { cost[$0] > 0 }
        XCTAssertEqual(ledger.allianceGifts.count, lacking.count > 1 ? 1 + lacking.count : 1)
        assertTaken(ledger.allianceGifts, in: state, as: me)

        _ = try state.perform(all.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.allianceLore, ["Pursuing \(study.title) II: \(study.cost(grade: 2)) still to give", "Learned together: \(study.title) I"])

        // Short of every store: nothing offered to give.
        state.houses[me].stock = .zero
        XCTAssertTrue(CompanionLedger(world: state, player: me).allianceGifts.isEmpty)
        // Short of one store: as much of it as the House has.
        var some = Stock()
        some[try XCTUnwrap(Resource.allCases.first { study.cost(grade: 2)[$0] > 0 })] = 1
        state.houses[me].stock = some
        let little = CompanionLedger(world: state, player: me)
        XCTAssertFalse(little.allianceGifts.isEmpty)
        assertTaken(little.allianceGifts, in: state, as: me)
        XCTAssertNotEqual(little, ledger)
    }

    /// The House's commanders kept from the phone as from the Mac's board,
    /// each order offered one the rules take: a free commander taking up a
    /// company of war by a hold, then riding home; a second sent to ride
    /// beside the leader; the next rank of a talent, a point each; a piece
    /// of the armoury worn, from whoever wore it. A prisoner is offered no
    /// company, no second's place and no gear.
    func testTheHousesCommandersAreKeptFromThePhone() throws {
        var (state, me) = try world()
        let first = try XCTUnwrap(state.commanders(of: me).first)
        if state.company(ledBy: first.id) != nil { _ = try state.perform(.unassign(commander: first.id), as: me) }
        let seat = try XCTUnwrap(state.seat(of: me))
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: seat.position))
        XCTAssertLessThanOrEqual(spear.position.distance(to: seat.position), 1)
        var ledger = CompanionLedger(world: state, player: me)
        var listed = try XCTUnwrap(ledger.commanders.first { $0.id == first.id })
        let lead = try XCTUnwrap(listed.leads.first { $0.command == .assign(commander: first.id, unit: spear.id) }, "\(listed.leads.map(\.title))")
        XCTAssertEqual(lead.title, "Lead the \(SpokenOrders.named(spear, in: state))")
        XCTAssertNil(listed.home, "Free, with no company to leave")
        XCTAssertTrue(listed.seconds.isEmpty, "No company led to ride second with")
        assertTaken(listed.leads, in: state, as: me)
        _ = try state.perform(lead.command, as: me)

        ledger = CompanionLedger(world: state, player: me)
        listed = try XCTUnwrap(ledger.commanders.first { $0.id == first.id })
        XCTAssertTrue(listed.leads.isEmpty, "One company at a time")
        XCTAssertEqual(listed.home, CompanionLedger.Order(title: "Ride home", command: .unassign(commander: first.id)))
        assertTaken([try XCTUnwrap(listed.home)], in: state, as: me)

        // A second commander sent to ride beside the first.
        var random = SeededRandom(seed: 41)
        let second = try XCTUnwrap(state.raiseCommander(for: me, using: &random))
        let beside = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == second.id })
        let ride = try XCTUnwrap(beside.seconds.first { $0.command == .assignSecond(commander: second.id, unit: spear.id) },
                                 "\(beside.seconds.map(\.title))")
        XCTAssertEqual(ride.title, "Ride second with the \(SpokenOrders.named(spear, in: state))")
        assertTaken(beside.seconds + beside.leads, in: state, as: me)

        // Talents: none without a point to spend, then the first ranks open.
        XCTAssertTrue(beside.talents.isEmpty, "\(beside.talents.map(\.title))")
        let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == second.id })
        state.commanders?[index].experience = 100_000
        let learned = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == second.id })
        XCTAssertFalse(learned.talents.isEmpty)
        assertTaken(learned.talents, in: state, as: me)
        for order in learned.talents {
            guard case .learnTalent(_, let talent) = order.command else { return XCTFail("\(order.title) is no talent") }
            XCTAssertEqual(order.title, "Learn \(talent.title) I")
        }

        // Gear: a piece in the armoury, worn by the first, offered the second from them.
        state.armoury = [Gear(id: 9_001, kind: .saltGlaive, quality: .fine, owner: me, wornBy: first.id)]
        let armed = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == second.id })
        let wear = try XCTUnwrap(armed.gear.first)
        XCTAssertEqual(wear.title, "Wear the Fine Salt Glaive, from \(first.name)")
        XCTAssertEqual(wear.command, .wear(gear: 9_001, commander: second.id))
        assertTaken(armed.gear, in: state, as: me)
        XCTAssertTrue(try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == first.id }).gear.isEmpty,
                      "Not offered what they wear already")

        // Held prisoner: no company, no second's place, no gear.
        let captor = (me + 1) % state.houses.count
        state.commanders?[index].captive = Captivity(by: captor, since: state.watch, questioned: 0)
        let held = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == second.id })
        XCTAssertTrue(held.leads.isEmpty && held.seconds.isEmpty && held.gear.isEmpty)
        assertTaken(held.talents, in: state, as: me)
    }

    /// What the phone offers the House's alliance, each the rules would
    /// take: help for an ally's works under way, a company sent to a rally
    /// of the House's side, and a company sent to keep an ally's gates.
    func testAllianceHelpRalliesAndGatesAreThoseTheRulesTake() throws {
        var (state, me) = try world()
        let seat = try XCTUnwrap(state.seat(of: me))
        let walker = Unit(id: -1, kind: .spear, owner: me, position: seat.position)
        let others = state.houses.indices.filter { $0 != me }
        let ally = try XCTUnwrap(others.first { other in
            state.seat(of: other).map { state.path(for: walker, to: $0.position) != nil } ?? false
        }, "An ally's seat the House's companies can reach")
        let foe = try XCTUnwrap(others.first { $0 != ally })
        state.houses[ally].temperament = .steadfast
        _ = try state.perform(.foundAlliance(name: "Hostward"), as: me)
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        XCTAssertTrue(state.areAllied(me, ally))
        XCTAssertTrue(CompanionLedger(world: state, player: me).helps.isEmpty, "Nothing of theirs under way")

        // Help: an ally raising a work.
        state.houses[ally].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        let allySeat = try XCTUnwrap(state.seat(of: ally))
        _ = try state.perform(.build(hold: allySeat.id, kind: .granary), as: ally)
        let help = try XCTUnwrap(CompanionLedger(world: state, player: me).helps.first)
        XCTAssertEqual(help.command, .help(house: ally))
        XCTAssertEqual(help.title, "Help \(state.houses[ally].title), \(state.helpable(by: me, for: ally)) under way")
        assertTaken([help], in: state, as: me)
        var helped = state
        _ = try helped.perform(help.command, as: me)
        XCTAssertTrue(CompanionLedger(world: helped, player: me).helps.isEmpty, "Helped, nothing left to help")

        // Keeping an ally's gates: their seat, the company free to go.
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: seat.position))
        var company = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertEqual(company.gates.map(\.command), [.reinforce(unit: spear.id, hold: allySeat.id)])
        XCTAssertEqual(company.gates.first?.title, "Keep the gates of \(allySeat.name)")
        assertTaken(company.gates, in: state, as: me)
        XCTAssertTrue(company.rallies.isEmpty, "No rally called")

        // A rally of the House's own, against a foe's seat it knows.
        _ = try state.declareWar(by: me, on: foe)
        let seatIndex = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[seatIndex].levels[.musterHall] = 1
        let foeSeat = try XCTUnwrap(state.seat(of: foe))
        state.reveal(around: foeSeat.position, range: 0, for: me)
        _ = try state.perform(.callRally(from: seat.id, against: foeSeat.id, watches: 2), as: me)
        let rally = try XCTUnwrap(state.ralliesStanding.first)
        company = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertEqual(company.rallies.map(\.command), [.joinRally(rally: rally.id, unit: spear.id)])
        XCTAssertEqual(company.rallies.first?.title, "Join the rally against \(foeSeat.name)")
        assertTaken(company.rallies, in: state, as: me)
        // Sent to it, it is offered neither again, nor any gates, while on its errand.
        _ = try state.perform(.joinRally(rally: rally.id, unit: spear.id), as: me)
        company = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertTrue(company.rallies.isEmpty)
        XCTAssertTrue(company.gates.isEmpty)
        XCTAssertEqual(state.joinRallyRefusal(rally.id, with: spear.id, as: me), .alreadyRallying)
        // A company not of war is sent to neither.
        if let founder = state.units(of: me).first(where: { !$0.kind.isMilitary }) {
            let plain = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == founder.id })
            XCTAssertTrue(plain.rallies.isEmpty)
            XCTAssertTrue(plain.gates.isEmpty)
        }
    }

    /// The House's satchel on the phone, as the Mac's panels use it: each
    /// item, how many and what one does, with the uses the rules take now:
    /// an hourglass for each hold with work to hasten and for the study, a
    /// cache while the stores have room, a ward stone for a hold whose ward
    /// isn't whole, a draught while a company is hurt; none where it would
    /// do nothing.
    func testTheSatchelIsUsedFromThePhone() throws {
        var (state, me) = try world()
        state.houses[me].stock = Stock(grain: 0, timber: 5_000, stone: 5_000, moonsalt: 500)
        XCTAssertTrue(CompanionLedger(world: state, player: me).satchel.isEmpty, "Nothing in it")
        // The stores and their room, as barter on the phone reads them.
        XCTAssertEqual(CompanionLedger(world: state, player: me).stock, state.houses[me].stock)
        XCTAssertEqual(CompanionLedger(world: state, player: me).storage, state.storage(of: me))
        _ = state.give(.hourglass, 2, to: me)
        _ = state.give(.grainCache, to: me)
        _ = state.give(.wardStone, to: me)
        _ = state.give(.mendingDraught, to: me)
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.satchel.map(\.kind), [.hourglass, .grainCache, .wardStone, .mendingDraught])
        XCTAssertEqual(ledger.satchel.first?.count, "2 Salt Hourglasses")
        XCTAssertEqual(ledger.satchel.first?.effect, "A hold's work and muster a watch nearer, or the House's study")
        XCTAssertEqual(ledger.satchel.filter { !$0.uses.isEmpty }.map(\.kind), [.grainCache],
                       "Nothing under way, no ward broken, none hurt: only the cache opens")
        XCTAssertEqual(ledger.satchel[1].uses.map(\.command), [.useItem(.grainCache, hold: nil)])
        assertTaken(ledger.satchel[1].uses, in: state, as: me)

        // A work under way at the seat and a study, the seat's ward broken, a company hurt.
        let seat = try XCTUnwrap(state.seat(of: me))
        let seatIndex = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[seatIndex].project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 3, watches: 3)
        state.houses[me].research.pursuit = Pursuit(study: .drill, grade: 1, watchesLeft: 3)
        state.holds[seatIndex].ward = 1
        let hurt = try XCTUnwrap(state.units.firstIndex { $0.owner == me })
        state.units[hurt].health = 50
        ledger = CompanionLedger(world: state, player: me)
        let uses = Dictionary(uniqueKeysWithValues: ledger.satchel.map { ($0.kind, $0.uses) })
        XCTAssertEqual(uses[.hourglass]?.map(\.command), [.useItem(.hourglass, hold: seat.id), .useItem(.hourglass, hold: nil)])
        XCTAssertEqual(uses[.hourglass]?.map(\.title), ["Hasten \(seat.name)", "Hasten the study"])
        XCTAssertEqual(uses[.wardStone]?.map(\.command), [.useItem(.wardStone, hold: seat.id)])
        XCTAssertEqual(uses[.wardStone]?.first?.title, "Make the ward of \(seat.name) whole")
        XCTAssertEqual(uses[.mendingDraught]?.map(\.command), [.useItem(.mendingDraught, hold: nil)])
        assertTaken(ledger.satchel.flatMap(\.uses), in: state, as: me)

        // A watch left of each is none to hasten; the granary full, the cache stays shut.
        state.holds[seatIndex].project?.watchesLeft = 1
        state.houses[me].research.pursuit?.watchesLeft = 1
        state.houses[me].stock = Stock(grain: state.storage(of: me), timber: 5_000, stone: 5_000, moonsalt: 500)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.satchel.first { $0.kind == .hourglass }?.uses, [])
        XCTAssertEqual(ledger.satchel.first { $0.kind == .grainCache }?.uses, [])
        for order in [Command.useItem(.hourglass, hold: seat.id), .useItem(.hourglass, hold: nil), .useItem(.grainCache, hold: nil)] {
            XCTAssertNotNil(state.refusal(of: order, as: me), "\(order) refused by the rules too")
        }
    }

    /// The alliances from the phone, as the Mac's Alliance panel reads them:
    /// sworn to none, the House asks to join those that would take it, the
    /// nearest first, answers those that invited it (no acceptance offered
    /// where one couldn't take it), and raises a banner of its own; leading
    /// it, it answers the Houses asking to join, invites the nearest that
    /// could, and may leave. Every order one the rules take as offered.
    func testTheAlliancesAreKeptFromThePhone() throws {
        var (state, me) = try world()
        let others = state.houses.indices.filter { $0 != me }
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.asks.isEmpty && ledger.invitations.isEmpty && ledger.requests.isEmpty && ledger.invites.isEmpty,
                      "No alliance stands")
        XCTAssertNil(ledger.leave)

        // Two stewards raise banners: the keeper may ask either, the nearest first.
        _ = try state.perform(.foundAlliance(name: "Hostward"), as: others[0])
        _ = try state.perform(.foundAlliance(name: "Farward"), as: others[1])
        let hostward = try XCTUnwrap(state.alliance(of: others[0]))
        let farward = try XCTUnwrap(state.alliance(of: others[1]))
        let home = try XCTUnwrap(state.seat(of: me)).position
        func distance(_ house: Int) -> Int { state.seat(of: house).map { $0.position.distance(to: home) } ?? Int.max }
        let nearestFirst = [hostward, farward].sorted { (distance($0.leader), $0.id) < (distance($1.leader), $1.id) }
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.asks.map(\.command), nearestFirst.map { Command.askToJoin(alliance: $0.id) })
        XCTAssertEqual(ledger.asks.map(\.title), nearestFirst.map { "Ask to join \($0.name)" })
        assertTaken(ledger.asks, in: state, as: me)

        // Hostward invites the keeper: answered, not asked.
        _ = try state.perform(.inviteToAlliance(house: me), as: others[0])
        ledger = CompanionLedger(world: state, player: me)
        let invitation = try XCTUnwrap(ledger.invitations.first)
        XCTAssertEqual(invitation.question, "Hostward invites your House to join it.")
        let join = try XCTUnwrap(invitation.accept)
        XCTAssertEqual(join.command, .answerInvitation(alliance: hostward.id, accept: true))
        XCTAssertEqual(join.title, "Join Hostward")
        XCTAssertEqual(invitation.refuse.command, .answerInvitation(alliance: hostward.id, accept: false))
        XCTAssertNil(invitation.unable)
        XCTAssertEqual(ledger.asks.map(\.command), [.askToJoin(alliance: farward.id)], "The alliance that invited it isn't asked")
        assertTaken([join, invitation.refuse], in: state, as: me)
        // Full, Hostward couldn't take it: its invitation answered no other way than declined.
        var full = state
        let index = try XCTUnwrap(full.alliances?.firstIndex { $0.id == hostward.id })
        full.alliances?[index].members.append(others[2])
        let crowded = try XCTUnwrap(CompanionLedger(world: full, player: me).invitations.first)
        XCTAssertNil(crowded.accept)
        XCTAssertEqual(crowded.unable, "It is full, or one of its Houses is at war with yours.")

        // Declined, the keeper raises a banner of their own, and leads it.
        _ = try state.perform(invitation.refuse.command, as: me)
        _ = try state.perform(.foundAlliance(name: "Moonward"), as: me)
        let moonward = try XCTUnwrap(state.alliance(of: me))
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.invitations.isEmpty)
        XCTAssertTrue(ledger.asks.isEmpty, "Sworn, it asks no other")
        XCTAssertEqual(ledger.leave?.command, .leaveAlliance)
        XCTAssertEqual(ledger.leave?.title, "Leave Moonward")
        XCTAssertEqual(ledger.invites.map(\.command), [.inviteToAlliance(house: others[2])], "The leaders of the others can't be invited")
        XCTAssertEqual(ledger.invites.first?.title, "Invite \(state.houses[others[2]].title)")
        assertTaken(ledger.invites + [try XCTUnwrap(ledger.leave)], in: state, as: me)

        // A House asking to join waits on the leader's answer; admitted, the alliance is full.
        _ = try state.perform(.askToJoin(alliance: moonward.id), as: others[2])
        ledger = CompanionLedger(world: state, player: me)
        let request = try XCTUnwrap(ledger.requests.first)
        XCTAssertEqual(request.question, "\(state.houses[others[2]].title) asks to join Moonward.")
        let admit = try XCTUnwrap(request.accept)
        XCTAssertEqual(admit.command, .answerRequest(house: others[2], accept: true))
        XCTAssertEqual(request.refuse.command, .answerRequest(house: others[2], accept: false))
        assertTaken([admit, request.refuse], in: state, as: me)
        XCTAssertTrue(CompanionLedger(world: state, player: others[2]).requests.isEmpty, "Only the leader answers")
        _ = try state.perform(admit.command, as: me)
        XCTAssertTrue(state.areAllied(me, others[2]))
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.requests.isEmpty)
        XCTAssertTrue(ledger.invites.isEmpty, "Full: no House could join it now")
    }

    /// Rallies called from the phone, as on the Mac: none while the House is
    /// sworn to no alliance or has no Muster Hall; then on a hold it has
    /// found of a House at war, mustered at its own Muster Hall and gathering
    /// two watches, one the rules take; none once it has called one.
    func testRalliesAreCalledFromThePhone() throws {
        var (state, me) = try world()
        let foe = try XCTUnwrap(state.houses.indices.first { $0 != me })
        let seat = try XCTUnwrap(state.seat(of: me))
        let seatIndex = try XCTUnwrap(state.holdIndex(seat.id))
        _ = try state.declareWar(by: me, on: foe)
        let foeSeat = try XCTUnwrap(state.seat(of: foe))
        state.reveal(around: foeSeat.position, range: 0, for: me)
        XCTAssertTrue(CompanionLedger(world: state, player: me).calls.isEmpty, "Sworn to no alliance")
        _ = try state.perform(.foundAlliance(name: "Rallyward"), as: me)
        XCTAssertTrue(CompanionLedger(world: state, player: me).calls.isEmpty, "No Muster Hall")
        state.holds[seatIndex].levels[.musterHall] = 1
        let ledger = CompanionLedger(world: state, player: me)
        let call = try XCTUnwrap(ledger.calls.first { $0.command == .callRally(from: seat.id, against: foeSeat.id, watches: 2) })
        XCTAssertEqual(call.title, "Rally on \(foeSeat.name)")
        XCTAssertLessThanOrEqual(ledger.calls.count, CompanionLedger.alliancesOffered)
        assertTaken(ledger.calls, in: state, as: me)
        _ = try state.perform(call.command, as: me)
        XCTAssertTrue(CompanionLedger(world: state, player: me).calls.isEmpty, "One rally called at a time")
    }

    /// Envoys waiting on the keeper, the first come first, their terms as
    /// the Mac words them and the answers the rules take; a trade the keeper
    /// can't pay offered no acceptance; a steward's demand of tribute marked,
    /// refusing it being war. And companies of a House at war gathered near
    /// a hold, as the walls' watchmen tell it.
    func testEnvoysWaitingAndGatheringsNearTheHoldsAreTold() throws {
        var (state, me) = try world()
        let others = state.houses.indices.filter { $0 != me }
        let trader = others[0], demander = others[1], foe = others[2]
        state.envoys.append(Envoy(id: state.takeID(), from: trader, to: me, proposal: .trade, arrived: state.watch,
                                  words: "Fair winds to your House.",
                                  trade: Trade(give: .grain, 40, for: .moonsalt, 9_000)))
        state.envoys.append(Envoy(id: state.takeID(), from: demander, to: me, proposal: .tribute, arrived: state.watch))
        state.envoys.append(Envoy(id: state.takeID(), from: trader, to: others[2], proposal: .pact, arrived: state.watch))
        let ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.envoys.map(\.offer), ["Trade", "Tribute"], "Those waiting on this House alone")
        let trade = try XCTUnwrap(ledger.envoys.first)
        let tradeEnvoy = try XCTUnwrap(state.envoys.first { $0.id == trade.id })
        XCTAssertEqual(trade.from, state.houses[trader].title)
        XCTAssertEqual(trade.terms, state.terms(of: tradeEnvoy, for: me))
        XCTAssertTrue(trade.terms.contains("You have only"), "Told what it lacks: \(trade.terms)")
        XCTAssertNil(trade.accept, "Not offered what it can't pay")
        XCTAssertEqual(trade.words, "Fair winds to your House.")
        XCTAssertEqual(trade.waits, "Waits \(Envoy.patience) watches")
        XCTAssertFalse(trade.refusingIsWar)
        let tribute = ledger.envoys[1]
        XCTAssertTrue(tribute.refusingIsWar, "A steward's demand refused is war")
        let accept = try XCTUnwrap(tribute.accept)
        assertTaken([accept, tribute.refuse, trade.refuse], in: state, as: me)

        // Companies of a House at war gathered near the seat.
        XCTAssertTrue(ledger.gatherings.isEmpty)
        _ = try state.declareWar(by: me, on: foe)
        let seat = try XCTUnwrap(state.seat(of: me))
        var placed = 0
        for hex in seat.position.spiral(GameState.gatheringReach) where placed < GameState.gatheringCompanies {
            guard hex.distance(to: seat.position) >= 2, state.map[hex]?.terrain.isPassable == true, state.unit(at: hex) == nil,
                  state.hold(at: hex) == nil, state.wild(at: hex) == nil else { continue }
            state.units.append(Unit(id: state.takeID(), kind: .spear, owner: foe, position: hex))
            placed += 1
        }
        XCTAssertEqual(placed, GameState.gatheringCompanies)
        let gathered = CompanionLedger(world: state, player: me).gatherings
        XCTAssertEqual(gathered, ["\(GameState.gatheringCompanies) companies of \(state.houses[foe].title) gather near \(seat.name)."])
        XCTAssertEqual(state.gatherings(against: me) { _ in false }, [], "Nothing gathers that isn't seen")
    }

    func testACompanysStrikesAndGatheringAreThoseTheRulesTake() throws {
        var (state, me) = try world()
        // A company of war set beside a wild of the land, once the wilds rise.
        for _ in 0..<40 where state.wildsStanding.isEmpty && state.outcome == nil {
            _ = state.stewardTurn(for: me)
            _ = state.endWatch()
        }
        state.houses[me].stock = Stock(grain: 5_000, timber: 5_000, stone: 5_000, moonsalt: 500)
        let wild = try XCTUnwrap(state.wildsStanding.first, "The wilds rise within forty watches")
        let beside = try XCTUnwrap(wild.position.neighbors.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.wild(at: hex) == nil
                && state.hold(at: hex) == nil && state.lair(at: hex) == nil
        })
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: me, near: beside))
        XCTAssertEqual(spear.position, beside)
        let ledger = CompanionLedger(world: state, player: me)
        let company = try XCTUnwrap(ledger.companies.first { $0.id == spear.id })
        let strike = try XCTUnwrap(company.strikes.first { $0.title == "Strike the \(wild.kind.title)" }, "\(company.strikes.map(\.title))")
        XCTAssertEqual(strike.command, .attack(unit: spear.id, target: wild.position))
        assertTaken(company.strikes, in: state, as: me)
        // Gathering: at most the nearest few sites, each one the rules would send it to.
        XCTAssertLessThanOrEqual(company.gathers.count, CompanionLedger.sitesOffered)
        assertTaken(company.gathers, in: state, as: me)
        for gather in company.gathers { XCTAssertTrue(gather.title.hasPrefix("Gather ")) }
        // Its moves spent, it strikes nothing.
        let index = try XCTUnwrap(state.units.firstIndex { $0.id == spear.id })
        state.units[index].movesLeft = 0
        let spent = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == spear.id })
        XCTAssertTrue(spent.strikes.isEmpty)
        // A founder strikes and gathers nothing, and is offered no fortifying.
        if let founder = ledger.companies.first(where: { state.unit($0.id)?.kind == .founder }) {
            XCTAssertTrue(founder.strikes.isEmpty)
            XCTAssertTrue(founder.gathers.isEmpty)
            XCTAssertFalse(founder.orders.contains { $0.title == "Fortify" })
        }
        // What each company is about, in a few words.
        XCTAssertEqual(company.doing, "At rest")
        var marching = state
        let seat = try XCTUnwrap(marching.seat(of: me))
        _ = try marching.perform(.move(unit: spear.id, to: seat.position), as: me)
        let moving = try XCTUnwrap(CompanionLedger(world: marching, player: me).companies.first { $0.id == spear.id })
        if marching.unit(spear.id)?.destination != nil {
            XCTAssertEqual(moving.doing, "Marching to \(seat.name)", "To a hold by its name, never \"to at\" it")
            XCTAssertTrue(moving.orders.contains { $0.title == "Halt" })
        }
        // To open ground, its own words: never "to on" nor "to in" it (run 658's phone said "Marching to on the barrows").
        XCTAssertEqual(CompanionLedger.whither("on the barrows by Tirford"), "the barrows by Tirford")
        XCTAssertEqual(CompanionLedger.whither("in the field"), "the field")
        XCTAssertEqual(CompanionLedger.whither("at Tirford"), "Tirford")
        XCTAssertEqual(CompanionLedger.whither("Tirford"), "Tirford")
    }
}
