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
        // More sites known than it names: the nearest the seat, so many.
        let ground = state.map.hexes.filter { state.map[$0]?.terrain.isWater == false }.prefix(SpokenOrders.briefedSites + 4)
        state.sites = ground.enumerated().map { Site(id: 800 + $0.offset, store: .stone, level: 1, position: $0.element, found: 0) }
        for hex in ground { state.reveal(around: hex, range: 0, for: me) }
        let briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains("\nC\(SpokenOrders.briefedCompanies): "))
        XCTAssertFalse(briefing.contains("\nC\(SpokenOrders.briefedCompanies + 1): "))
        let known = try XCTUnwrap(briefing.split(separator: "\n").first { $0.hasPrefix("Places you know: ") })
        XCTAssertLessThanOrEqual(known.components(separatedBy: ", ").count, SpokenOrders.briefedPlaces)
        XCTAssertEqual(known.components(separatedBy: "Moonwell").count - 1, 1, "Each name once")
        let sites = try XCTUnwrap(briefing.split(separator: "\n").first { $0.hasPrefix("Sites to gather at, the nearest your seat first: ") })
        XCTAssertEqual(sites.components(separatedBy: "; ").count, SpokenOrders.briefedSites, String(sites))
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

    /// Torches from the book: DOUSE has a company march dark, and the
    /// briefing tells the model which march so; LIGHT lights them again;
    /// each line once done is told why not, in the realm's own words.
    func testTorchesAreDousedAndLitFromTheBook() throws {
        var state = world()
        let me = state.player
        let companies = SpokenOrders.companies(in: state, player: me)
        let unit = try XCTUnwrap(companies.first { $0.kind.isMilitary })
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == unit.id }) + 1)"
        let douse = try XCTUnwrap(SpokenOrders.read("DOUSE \(handle)", in: state, player: me).first)
        XCTAssertEqual(douse.command, .torches(unit: unit.id, lit: false))
        XCTAssertNil(douse.why)
        XCTAssertEqual(douse.told, "Your \(SpokenOrders.named(unit, in: state)) douse their torches and march dark.")
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("light \(handle)", in: state, player: me).first).why,
                       RuleError.torchesAlready(lit: true).description, "Lit already")
        XCTAssertFalse(SpokenOrders.briefing(for: state, player: me).contains("marching dark"))
        _ = try state.perform(.torches(unit: unit.id, lit: false), as: me)
        let briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(handle): ") && $0.hasSuffix(", marching dark, its torches doused (LIGHT)") }, "\(briefing)")
        let light = try XCTUnwrap(SpokenOrders.read("LIGHT \(handle)", in: state, player: me).first)
        XCTAssertEqual(light.command, .torches(unit: unit.id, lit: true))
        XCTAssertNil(light.why)
        XCTAssertEqual(light.told, "Your \(SpokenOrders.named(unit, in: state)) light their torches again.")
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("DOUSE \(handle)", in: state, player: me).first).why,
                       RuleError.torchesAlready(lit: false).description, "Dark already")
        XCTAssertTrue(["DOUSE <company>", "LIGHT <company>"].allSatisfy(SpokenOrders.forms.contains))
    }

    /// The dead buried from the book: BURY has a company of war bury the
    /// dead lying unburied where it stands, the briefing telling the model
    /// which may; where none lie, told why not; and a commander may put it
    /// forward, the House's unburied dead in counsel's briefing.
    func testTheDeadAreBuriedFromTheBookAndCounselMayProposeIt() throws {
        var state = world()
        let me = state.player
        let companies = SpokenOrders.companies(in: state, player: me)
        let unit = try XCTUnwrap(companies.first { $0.kind.isMilitary })
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == unit.id }) + 1)"
        XCTAssertTrue(SpokenOrders.forms.contains("BURY <company>"))
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("BURY \(handle)", in: state, player: me).first).why,
                       RuleError.noDeadHere.description, "none lie there")
        XCTAssertFalse(SpokenOrders.briefing(for: state, player: me).contains("(BURY)"))
        state.layTheFallen(7_000, of: me, at: unit.position)
        let briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(handle): ") && $0.hasSuffix(", where 7,000 troops' dead lie unburied, which it may bury (BURY)") },
                      "\(briefing)")
        let bury = try XCTUnwrap(SpokenOrders.read("bury \(handle)", in: state, player: me).first)
        XCTAssertEqual(bury.command, .bury(unit: unit.id))
        XCTAssertNil(bury.why)
        XCTAssertEqual(bury.told, "Your \(SpokenOrders.named(unit, in: state)) bury the dead that lie there under a barrow.")
        // A commander's counsel knows of them, and may put the burial forward.
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id))
        XCTAssertTrue(counsel.affairs.contains("Its dead lie unburied: 7,000 troops \(state.placeName(of: unit.position)), "
                                               + "who rise as Barrowkin at the dark of the moon unless buried; the dark of the moon comes in "),
                      counsel.affairs)
        XCTAssertTrue(CommanderCounsel.actions.contains("bury"))
        let ownHandle = try XCTUnwrap(counsel.handle(of: unit))
        let proposed = counsel.propose("bury", company: ownHandle, place: "")
        XCTAssertEqual(proposed.command, .bury(unit: unit.id))
        XCTAssertNil(proposed.why)
        XCTAssertTrue(CommanderCounsel.onlyThese.contains("bury"))
        // Buried, nothing more to bury.
        _ = try state.perform(.bury(unit: unit.id), as: me)
        XCTAssertFalse(SpokenOrders.briefing(for: state, player: me).contains("(BURY)"))
        XCTAssertFalse(try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id)).affairs.contains("unburied"))
    }

    /// Gathering from the book: GATHER sends a company of war to the nearest
    /// site of the store asked that it may work, as the rules would send
    /// it, the store named as itself or as its sites are; or to the nearest
    /// of any. The briefing names the sites the House knows, nearest its
    /// seat first, and the companies out gathering; what can't be gathered
    /// is told why in the realm's own words; and a commander may put it
    /// forward.
    func testCompaniesAreSentToGatherFromTheBookAndCounselMayProposeIt() throws {
        var state = Scene.world("gather from the book")
        let me = state.player
        state.sites = []
        state.wilds = []
        let ground = try XCTUnwrap(state.openGround())
        let spear = state.put(.spear, of: me, at: ground)
        let lantern = state.put(.lantern, of: me, at: ground)
        let east = ground + Hex.directions[0], west = ground + Hex.directions[3]
        let grain = Site(id: state.takeID(), store: .grain, level: 2, position: east, found: state.watch)
        let timber = Site(id: state.takeID(), store: .timber, level: 1, position: west, found: state.watch)
        state.sites = [grain, timber]
        for hex in [ground, east, west] { state.houses[me].explored[try XCTUnwrap(state.map.index(of: hex))] = false }
        let companies = SpokenOrders.companies(in: state, player: me)
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == spear }) + 1)"
        let lanterns = "C\(try XCTUnwrap(companies.firstIndex { $0.id == lantern }) + 1)"
        XCTAssertTrue(SpokenOrders.forms.contains("GATHER <store> WITH <company>"))
        func read(_ line: String) throws -> SpokenOrders.Line { try XCTUnwrap(SpokenOrders.read(line, in: state, player: me).first, line) }

        // Unseen, no site is the House's to send a company to.
        XCTAssertTrue(SpokenOrders.briefing(for: state, player: me).contains("\nSites to gather at: none your House knows of.\n"))
        XCTAssertEqual(try read("GATHER TIMBER WITH \(handle)").why, "Your House knows of no site of timber to gather at.")
        XCTAssertEqual(try read("GATHER \(handle)").why, "Your House knows of no site of any store to gather at.")

        state.reveal(around: ground, range: 1, for: me)
        let home = try XCTUnwrap(state.seat(of: me)).position
        let told = [grain, timber].sorted { ($0.position.distance(to: home), $0.id) < ($1.position.distance(to: home), $1.id) }
            .map { "\(state.siteSaid($0)) (\($0.store.title.lowercased())), \(GameState.waySaid(to: $0.position, from: home))" }
        XCTAssertTrue(SpokenOrders.briefing(for: state, player: me)
            .contains("\nSites to gather at, the nearest your seat first: " + told.joined(separator: "; ") + "\n"))
        XCTAssertEqual(told.filter { $0.hasPrefix("the Deadfall I (timber), ") }.count, 1, "\(told)")

        let unit = try XCTUnwrap(state.unit(spear))
        let gather = try read("gather timber with \(handle)")
        XCTAssertEqual(gather.command, .gather(unit: spear, site: timber.id))
        XCTAssertNil(gather.why)
        XCTAssertEqual(gather.told, "Your \(SpokenOrders.named(unit, in: state)) gather timber at the Deadfall I, "
                       + "\(GameState.waySaid(to: west, from: ground)).")
        // The store by its sites' name, or its alliance's yards'; without
        // WITH, the last word is the company.
        XCTAssertEqual(try read("GATHER THE DEADFALL WITH \(handle)").command, gather.command)
        XCTAssertEqual(try read("GATHER the Timber Yard WITH \(handle)").command, gather.command)
        XCTAssertEqual(try read("GATHER Fallow Field II WITH \(handle)").command, .gather(unit: spear, site: grain.id))
        XCTAssertEqual(try read("GATHER TIMBER \(handle)").command, gather.command)
        // Of any store, the nearest; between two as near, the older site.
        XCTAssertEqual(try read("GATHER \(handle)").command, .gather(unit: spear, site: grain.id))
        XCTAssertEqual(state.sitesToGather(by: unit, as: me, most: 5).map(\.id), [grain.id, timber.id])
        XCTAssertEqual(state.sitesToGather(by: unit, as: me, store: .timber, most: 5).map(\.id), [timber.id])
        XCTAssertEqual(state.sitesToGather(by: unit, as: me, most: 0), [])

        // What can't be gathered, told why.
        XCTAssertEqual(try read("GATHER GOLD WITH \(handle)").why, "No store goes by the name GOLD.")
        XCTAssertEqual(try read("GATHER TIMBER WITH C99").why, "Your House has no company C99.")
        XCTAssertEqual(try read("GATHER GRAIN WITH \(lanterns)").why, RuleError.cannotGather(.lantern).description)
        var laden = state
        laden.units[try XCTUnwrap(laden.units.firstIndex { $0.id == spear })].load = Stock(grain: 10)
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("GATHER TIMBER WITH \(handle)", in: laden, player: me).first).why,
                       RuleError.loadFull.description, "it carries grain")
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("GATHER \(handle)", in: laden, player: me).first).command,
                       .gather(unit: spear, site: grain.id), "more grain it may carry")

        // A commander may put it forward, by the store or for the nearest.
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id))
        let own = try XCTUnwrap(counsel.handle(of: unit))
        let proposed = counsel.propose(" Gather ", company: own, place: "timber")
        XCTAssertEqual(proposed.line, "GATHER timber WITH \(own)")
        XCTAssertTrue(proposed.isGiven, proposed.why ?? "")
        XCTAssertEqual(proposed.command, gather.command)
        XCTAssertEqual(counsel.propose("gather", company: own, place: "").line, "GATHER \(own)")
        XCTAssertEqual(counsel.propose("gather", company: own, place: "").command, .gather(unit: spear, site: grain.id))
        XCTAssertTrue(CommanderCounsel.actions.contains("gather"))
        XCTAssertTrue(CommanderCounsel.onlyThese.contains("gather (a store, at the nearest site of it the company may work)"))

        // Sent, the briefing and counsel tell it out gathering.
        _ = try state.perform(try XCTUnwrap(gather.command), as: me)
        let sent = try XCTUnwrap(state.unit(spear))
        let work = try XCTUnwrap(state.gatheringSaid(of: sent))
        let lines = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(lines.contains { $0.hasPrefix("\(handle): ") && $0.hasSuffix(", out gathering: \(work)") }, "\(lines)")
        let after = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id))
        XCTAssertTrue(after.report(on: own).contains(", out gathering: \(work)"), after.report(on: own))
    }

    /// Each commander's bent has its line: SCOUT sends Lanterns near another
    /// House's hold to scout it, REINFORCE a company of war to keep the gates
    /// of a hold of its House or an ally's, RALLY a company to a rally of its
    /// side still gathering, by its target or the soonest. The briefing tells
    /// the model which Lanterns may scout, the rallies gathering and each
    /// company's errand; what can't be done is told why in the realm's
    /// words; and a commander may put each forward.
    func testScoutsReinforcementsAndRalliesFromTheBook() throws {
        var state = Scene.world("scouts and rallies", houses: 4, radius: 18)
        let me = state.player
        _ = try state.declareWar(by: me, on: 2)
        let seat = try XCTUnwrap(state.seat(of: me)), foe = try XCTUnwrap(state.seat(of: 2))
        state.reveal(around: foe.position, range: 2, for: me)
        let lantern = state.put(.lantern, of: me, at: try XCTUnwrap(state.freeHex(near: foe.position, within: 1...2)))
        let spear = state.put(.spear, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 1...2)))
        let companies = SpokenOrders.companies(in: state, player: me)
        let lanterns = "C\(try XCTUnwrap(companies.firstIndex { $0.id == lantern }) + 1)"
        let spears = "C\(try XCTUnwrap(companies.firstIndex { $0.id == spear }) + 1)"
        func read(_ line: String) throws -> SpokenOrders.Line { try XCTUnwrap(SpokenOrders.read(line, in: state, player: me).first, line) }
        func named(_ id: Int) throws -> String { SpokenOrders.named(try XCTUnwrap(state.unit(id)), in: state) }
        XCTAssertTrue(["RECALL <company>", "SCOUT <hold> WITH <company>", "REINFORCE <hold> WITH <company>",
                       "RALLY AGAINST <target> WITH <company>"].allSatisfy(SpokenOrders.forms.contains))

        // Scouting: the Lanterns near the foe's seat, told so in the briefing.
        let briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(lanterns): ") && $0.contains(", near \(foe.name), which it may scout (SCOUT)") },
                      "\(briefing)")
        XCTAssertFalse(briefing.contains { $0.hasPrefix("\(spears): ") && $0.contains("(SCOUT)") })
        let scout = try read("SCOUT \(foe.name) WITH \(lanterns)")
        XCTAssertEqual(scout.command, .scout(unit: lantern, hold: foe.id))
        XCTAssertNil(scout.why, scout.why ?? "")
        XCTAssertEqual(scout.told, "Your \(try named(lantern)) scout \(foe.name).")
        XCTAssertEqual(try read("SCOUT \(seat.name) WITH \(lanterns)").why, RuleError.ownHold.description)
        XCTAssertEqual(try read("SCOUT \(foe.name) WITH \(spears)").why, RuleError.notAScout.description)
        XCTAssertEqual(try read("SCOUT Nowhere WITH \(lanterns)").why, "Your House knows no hold by the name Nowhere.")

        // Keeping gates: the House's own, never a foe's; Lanterns keep none.
        let keep = try read("reinforce \(seat.name) with \(spears)")
        XCTAssertEqual(keep.command, .reinforce(unit: spear, hold: seat.id))
        XCTAssertNil(keep.why, keep.why ?? "")
        XCTAssertEqual(keep.told, "Your \(try named(spear)) go to keep the gates of \(seat.name).")
        XCTAssertEqual(try read("REINFORCE \(foe.name) WITH \(spears)").why, RuleError.notAnAllysHold.description)
        XCTAssertEqual(try read("REINFORCE \(seat.name) WITH \(lanterns)").why, RuleError.cannotFight.description)
        var keeping = state
        _ = try keeping.perform(try XCTUnwrap(keep.command), as: me)
        XCTAssertTrue(SpokenOrders.briefing(for: keeping, player: me).contains(", keeping the gates of \(seat.name)"))

        // Rallies: none gathering, then one, told in the briefing.
        XCTAssertEqual(try read("RALLY \(spears)").why, "Your side has no rally gathering.")
        XCTAssertFalse(SpokenOrders.briefing(for: state, player: me).contains("Rallies of your side"))
        let rally = Rally(id: state.takeID(), caller: me, muster: seat.id, target: foe.id, called: state.watch, setsOut: state.watch + 3)
        state.rallies = [rally]
        let gathering = "against \(foe.name), mustering at \(seat.name), setting out in 3 watches"
        XCTAssertTrue(SpokenOrders.briefing(for: state, player: me).contains("\nRallies of your side gathering (RALLY): \(gathering)\n"))
        let join = try read("RALLY AGAINST \(foe.name) WITH \(spears)")
        XCTAssertEqual(join.command, .joinRally(rally: rally.id, unit: spear))
        XCTAssertNil(join.why, join.why ?? "")
        XCTAssertEqual(join.told, "Your \(try named(spear)) go to the rally \(gathering).")
        XCTAssertEqual(try read("RALLY \(spears)").command, join.command, "the soonest")
        XCTAssertEqual(try read("RALLY AGAINST Nowhere WITH \(spears)").why, "Your side has no rally gathering against Nowhere.")
        XCTAssertEqual(try read("RALLY \(lanterns)").why, RuleError.cannotFight.description)

        // A commander may put each forward.
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id))
        XCTAssertEqual(counsel.propose("scout", company: lanterns, place: foe.name).command, scout.command)
        XCTAssertEqual(counsel.propose("reinforce", company: spears, place: seat.name).command, keep.command)
        XCTAssertEqual(counsel.propose("rally", company: spears, place: "").line, "RALLY \(spears)")
        XCTAssertEqual(counsel.propose("rally", company: spears, place: foe.name).line, "RALLY AGAINST \(foe.name) WITH \(spears)")
        XCTAssertTrue(counsel.propose("rally", company: spears, place: foe.name).isGiven)
        XCTAssertEqual(counsel.propose("scout", company: lanterns, place: " ").why, "Scouting or keeping a hold's gates wants the hold's name.")
        XCTAssertTrue(["recall", "scout", "reinforce", "rally"].allSatisfy(CommanderCounsel.actions.contains))

        // Sent, the briefing and counsel tell it at the rally.
        _ = try state.perform(try XCTUnwrap(join.command), as: me)
        let lines = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(lines.contains { $0.hasPrefix("\(spears): ") && $0.contains(", sent to the rally against \(foe.name)") }, "\(lines)")
        let after = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id))
        XCTAssertTrue(after.report(on: spears).contains(", sent to the rally against \(foe.name)"), after.report(on: spears))
    }

    /// RECALL calls a company home from the land's work with what it
    /// carries; one not gathering is told why not; a commander may put it
    /// forward.
    func testACompanyIsCalledHomeFromTheBook() throws {
        var state = Scene.world("recall from the book")
        let me = state.player
        state.sites = []
        state.wilds = []
        let ground = try XCTUnwrap(state.openGround())
        let spear = state.put(.spear, of: me, at: ground)
        let site = Site(id: state.takeID(), store: .grain, level: 1, position: ground + Hex.directions[0], found: state.watch)
        state.sites = [site]
        state.reveal(around: ground, range: 1, for: me)
        let handle = "C\(try XCTUnwrap(SpokenOrders.companies(in: state, player: me).firstIndex { $0.id == spear }) + 1)"
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("RECALL \(handle)", in: state, player: me).first).why, RuleError.notGathering.description)
        _ = try state.perform(.gather(unit: spear, site: site.id), as: me)
        let recall = try XCTUnwrap(SpokenOrders.read("recall \(handle)", in: state, player: me).first)
        XCTAssertEqual(recall.command, .recall(unit: spear))
        XCTAssertNil(recall.why, recall.why ?? "")
        XCTAssertEqual(recall.told, "Your \(SpokenOrders.named(try XCTUnwrap(state.unit(spear)), in: state)) "
                       + "are called home from the land's work with what they carry.")
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        let counsel = try XCTUnwrap(CommanderCounsel(state: state, player: me, commander: commander.id))
        XCTAssertEqual(counsel.propose("recall", company: handle, place: "").command, .recall(unit: spear))
        XCTAssertTrue(counsel.propose("recall", company: handle, place: "").isGiven)
    }

    /// An ambush from the book: WAIT has a company marching dark in the
    /// blackwood lie in wait there, the briefing telling the model which
    /// may and which wait; out of the wood or lit, told why not.
    func testACompanyLiesInWaitFromTheBook() throws {
        var state = world()
        let me = state.player
        let companies = SpokenOrders.companies(in: state, player: me)
        let unit = try XCTUnwrap(companies.first { $0.kind.isMilitary })
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == unit.id }) + 1)"
        XCTAssertTrue(SpokenOrders.forms.contains("WAIT <company>"))
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("WAIT \(handle)", in: state, player: me).first).why,
                       state.waitRefusal(unit.id, waiting: true, as: me)?.description, "Lit, or out of the wood")
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let seen = state.view(for: me)
        let wood = try XCTUnwrap(state.map.hexes.filter { hex in
            seen.isCover(hex) && state.hold(at: hex) == nil && state.unit(at: hex) == nil
        }.min { ($0.distance(to: seat), $0.q, $0.r) < ($1.distance(to: seat), $1.q, $1.r) })
        state.units[try XCTUnwrap(state.unitIndex(unit.id))].position = wood
        _ = try state.perform(.torches(unit: unit.id, lit: false), as: me)
        var briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(handle): ") && $0.contains(", in the blackwood where it may lie in wait (WAIT), marching dark") },
                      "\(briefing)")
        let wait = try XCTUnwrap(SpokenOrders.read("wait \(handle)", in: state, player: me).first)
        XCTAssertEqual(wait.command, .lieInWait(unit: unit.id, waiting: true))
        XCTAssertNil(wait.why)
        XCTAssertEqual(wait.told, "Your \(SpokenOrders.named(unit, in: state)) lie in wait in the wood.")
        _ = try state.perform(.lieInWait(unit: unit.id, waiting: true), as: me)
        briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(handle): ") && $0.contains(", lying in wait in the wood, marching dark") }, "\(briefing)")
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("WAIT \(handle)", in: state, player: me).first).why,
                       RuleError.waitingAlready(true).description, "Waiting already")
    }

    /// A hamlet or barrow from the book: SEEK has Lanterns on or beside one
    /// their House knows of seek it, the briefing telling the model which
    /// may; Lanterns by none, or by one sought already, told why not.
    func testLanternsSeekAHamletFromTheBook() throws {
        var state = world()
        let me = state.player
        let companies = SpokenOrders.companies(in: state, player: me)
        let lantern = try XCTUnwrap(companies.first { $0.kind == .lantern })
        let handle = "C\(try XCTUnwrap(companies.firstIndex { $0.id == lantern.id }) + 1)"
        XCTAssertTrue(SpokenOrders.forms.contains("SEEK <company>"))
        XCTAssertNil(state.findToSeek(by: lantern, as: me), "None by the Lanterns as the age opens")
        let none = try XCTUnwrap(SpokenOrders.read("SEEK \(handle)", in: state, player: me).first)
        XCTAssertNil(none.command)
        XCTAssertEqual(none.why, "Your \(SpokenOrders.named(lantern, in: state)) stand by no hamlet or barrow your House has yet to seek.")
        let hamlet = try XCTUnwrap(state.findsInLand.first { $0.kind == .hamlet })
        let beside = try XCTUnwrap(hamlet.position.neighbors.first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil
        })
        state.units[try XCTUnwrap(state.unitIndex(lantern.id))].position = beside
        state.refreshSight()
        let moved = try XCTUnwrap(state.unit(lantern.id))
        XCTAssertEqual(state.findToSeek(by: moved, as: me), hamlet)
        var briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(handle): ") && $0.contains(", by \(hamlet.named), which it may seek (SEEK)") },
                      "\(briefing)")
        let seek = try XCTUnwrap(SpokenOrders.read("seek \(handle)", in: state, player: me).first)
        XCTAssertEqual(seek.command, .seek(unit: lantern.id, find: hamlet.id))
        XCTAssertNil(seek.why)
        XCTAssertEqual(seek.told, "Your \(SpokenOrders.named(moved, in: state)) seek out \(hamlet.named).")
        // A company of war by it may not: the rules say why.
        let spears = try XCTUnwrap(companies.first { $0.kind.isMilitary })
        let other = "C\(try XCTUnwrap(companies.firstIndex { $0.id == spears.id }) + 1)"
        let open = try XCTUnwrap(hamlet.position.neighbors.first { hex in
            hex != beside && state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil
        })
        state.units[try XCTUnwrap(state.unitIndex(spears.id))].position = open
        XCTAssertEqual(try XCTUnwrap(SpokenOrders.read("SEEK \(other)", in: state, player: me).first).why,
                       RuleError.notAScout.description)
        briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertFalse(briefing.contains { $0.hasPrefix("\(other): ") && $0.contains("(SEEK)") }, "Only Lanterns are told they may seek")
        XCTAssertTrue(briefing.contains { $0.hasPrefix("\(handle): ") && $0.contains("(SEEK)") })
        // Sought: told no more, and why not.
        _ = try state.perform(.seek(unit: lantern.id, find: hamlet.id), as: me)
        briefing = SpokenOrders.briefing(for: state, player: me).split(separator: "\n").map(String.init)
        XCTAssertFalse(briefing.contains { $0.hasPrefix("\(handle): ") && $0.contains("(SEEK)") }, "\(briefing)")
        XCTAssertNil(try XCTUnwrap(SpokenOrders.read("SEEK \(handle)", in: state, player: me).first).command)
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

    /// The House's part in its alliance from the book: a hand lent to an
    /// ally's works (HELP), the shares of the spoils taken (TAKE THE
    /// SHARES) and ground marked by its leader or an officer (MARK), each
    /// told in the briefing only while there is something to do, and each
    /// weighed by the rules.
    func testTheAlliancesOrdersFromTheBook() throws {
        var state = world()
        let me = state.player
        let ally = (me + 1) % state.houses.count
        state.houses[ally].isPlayer = true
        let title = state.houses[ally].title
        let mine = try XCTUnwrap(state.seat(of: me))
        func read(_ line: String, as house: Int = -1) throws -> SpokenOrders.Line {
            try XCTUnwrap(SpokenOrders.read(line, in: state, player: house < 0 ? me : house).first, line)
        }
        // Sworn to none: nothing told, and each line refused in the realm's words.
        var briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertFalse(briefing.contains("(HELP)") || briefing.contains("(TAKE THE SHARES)") || briefing.contains("(MARK)"), briefing)
        XCTAssertEqual(try read("HELP \(title)").why, RuleError.notAnAlly.description)
        XCTAssertEqual(try read("MARK STRIKE AT \(mine.name)").why, RuleError.notInAlliance.description)
        XCTAssertEqual(try read("TAKE THE SHARES").why, RuleError.noSharesWaiting.description)
        XCTAssertEqual(try read("HELP House Nobody").why, "No House goes by the name House Nobody.")

        // Sworn together, the ally at work: help told and given.
        _ = try state.perform(.foundAlliance(name: "Lantern Oath"), as: me)
        let id = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: id, accept: true), as: ally)
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == ally && $0.isSeat })
        state.holds[seat].project = Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 5)
        briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains("Allies' works, musters and studies your House may help (HELP): \(title), 1 under way"), briefing)
        let help = try read("HELP \(title)")
        XCTAssertEqual(help.command, .help(house: ally))
        XCTAssertNil(help.why)
        XCTAssertEqual(help.told, "Your House lends a hand to the works, musters and study of \(title) under way.")

        // Its leader marks ground at a place it knows, with words or none.
        XCTAssertTrue(briefing.contains("Your House may mark ground for its alliance (MARK): Gather, Strike, Hold, Beware"), briefing)
        let mark = try read("MARK GATHER AT \(mine.name) SAYING Bring the spears")
        XCTAssertEqual(mark.command, .markGround(mine.position, .gather, words: "Bring the spears"))
        XCTAssertNil(mark.why)
        XCTAssertEqual(mark.told, "Gather here, marked at \(mine.name) for your alliance: “Bring the spears”.")
        XCTAssertEqual(try read("MARK BEWARE AT \(mine.name)").command, .markGround(mine.position, .beware, words: nil))
        XCTAssertEqual(try read("MARK STRIKE AT the Drowned Moon").why, "Your House knows no place by the name the Drowned Moon.")
        XCTAssertTrue(SpokenOrders.read("MARK FEAST AT \(mine.name)\nMARK GATHER AT", in: state, player: me).isEmpty, "No such mark, no place")
        // A House of the alliance that is no officer may not.
        XCTAssertEqual(try read("MARK GATHER AT \(mine.name)", as: ally).why, RuleError.notAllianceOfficer.description)
        XCTAssertFalse(SpokenOrders.briefing(for: state, player: ally).contains("(MARK)"))

        // A share of the spoils waiting, told and taken.
        state.allianceShares = [AllianceShare(house: me, from: ally, deed: .wilds, level: 2, given: state.watch)]
        let held = state.sharesHeldSaid(by: me)
        briefing = SpokenOrders.briefing(for: state, player: me)
        XCTAssertTrue(briefing.contains("Shares of the alliance's spoils waiting for your House (TAKE THE SHARES): 1, holding \(held)"), briefing)
        let take = try read("TAKE THE SHARES")
        XCTAssertEqual(take.command, .takeShares)
        XCTAssertNil(take.why)
        XCTAssertEqual(take.told, "Your House takes up the shares of the alliance's spoils, holding \(held).")
        XCTAssertEqual(try read("take the spoils").command, .takeShares)
        XCTAssertTrue(SpokenOrders.read("TAKE THE HILL", in: state, player: me).isEmpty, "Not a line of the book")
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
