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

    /// A march to one of the House's holds is offered only where there is
    /// a way there, as the realm would march it: a hold walled in by the
    /// Spine is offered to none, an open one to every company that can go.
    func testMarchesAreOfferedOnlyWhereThereIsAWay() throws {
        var (state, me) = try world()
        func open(_ hex: Hex) -> Bool {
            state.map[hex]?.terrain.isSettleable == true && state.unit(at: hex) == nil
                && state.holds.allSatisfy { $0.position.distance(to: hex) >= 4 }
        }
        let seat = try XCTUnwrap(state.seat(of: me))
        let near = state.map.hexes.filter(open).sorted { ($0.distance(to: seat.position), $0) < ($1.distance(to: seat.position), $1) }
        let walled = try XCTUnwrap(near.first { $0.neighbors.allSatisfy { state.unit(at: $0) == nil && state.hold(at: $0) == nil } })
        state.holds.append(Hold(id: state.takeID(), name: "Walled Keep", owner: me, position: walled, isSeat: false, foundedWatch: 1))
        for hex in walled.neighbors where state.map[hex] != nil {
            state.map.set(hex, Tile(terrain: .spine))
        }
        let reachable = try XCTUnwrap(near.first { hex in
            open(hex) && hex.distance(to: walled) >= 4 && state.units(of: me).contains { state.path(for: $0, to: hex) != nil }
        })
        state.holds.append(Hold(id: state.takeID(), name: "Open Keep", owner: me, position: reachable, isSeat: false, foundedWatch: 1))
        XCTAssertEqual(state.refusal(of: .move(unit: try XCTUnwrap(state.units(of: me).first).id, to: walled), as: me), .noPath)
        let ledger = CompanionLedger(world: state, player: me)
        let marches = ledger.companies.flatMap(\.marches)
        XCTAssertFalse(marches.contains { $0.title == "March to Walled Keep" }, "No way there, so no march offered")
        XCTAssertTrue(marches.contains { $0.title == "March to Open Keep" })
        assertTaken(marches, in: state, as: me)
    }

    /// Letters on the phone: the House's own, the latest first, lined as the
    /// Mac lines them; the keepers it may write to, never a steward's House,
    /// those it has letters with first; a letter written taken by the rules.
    func testThePhoneReadsAndWritesLetters() throws {
        var (state, me) = try world()
        let others = state.houses.indices.filter { $0 != me }
        XCTAssertTrue(CompanionLedger(world: state, player: me).correspondents.isEmpty, "No other keeper, none to write to")
        let friend = try XCTUnwrap(others.last), near = try XCTUnwrap(others.first)
        state.houses[friend].isPlayer = true
        state.houses[near].isPlayer = true
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(Set(ledger.correspondents.map(\.id)), [friend, near], "Keepers alone")
        XCTAssertTrue(ledger.letters.isEmpty)

        let write = Command.writeLetter(to: friend, words: "Hold the ford.")
        XCTAssertNil(state.refusal(of: write, as: me))
        _ = try state.perform(write, as: me)
        _ = try state.perform(.writeLetter(to: me, words: "It is held."), as: friend)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.letters.map(\.line), ["From \(state.houses[friend].title): It is held.",
                                                    "To \(state.houses[friend].title): Hold the ford."], "The latest first")
        XCTAssertEqual(ledger.letters.map(\.incoming), [true, false])
        XCTAssertEqual(ledger.correspondents.map(\.id), [friend, near], "Those it has letters with first")
        XCTAssertTrue(CompanionLedger(world: state.view(for: near), player: near).letters.isEmpty, "No other keeper reads them")
    }

    /// The Spine on the phone: its next stage told as the Mac tells it; a line
    /// of the House's strongest free commanders and each alone offered, each
    /// one the rules send; once ventured, none until the watch turns.
    func testThePhoneSendsCommandersUpTheSpine() throws {
        var (state, me) = try world()
        var ledger = CompanionLedger(world: state, player: me)
        let first = try XCTUnwrap(ExpeditionStage.stage(1))
        XCTAssertTrue(ledger.spine.said.hasPrefix("The Spine, \(first.name) (1 of \(ExpeditionStage.count)): its host weighs \(first.strength)"),
                      ledger.spine.said)
        let free = state.commanders(of: me).filter { $0.captive == nil && ($0.woundedUntil ?? 0) <= state.watch }
        XCTAssertFalse(free.isEmpty, "A House begins with a commander")
        XCTAssertEqual(ledger.spine.ventures.count, free.count + (free.count > 1 ? 1 : 0), "\(ledger.spine.ventures.map(\.title))")
        XCTAssertEqual(ledger.armyWaiting, 1, "The Army tab's badge: the watch's venture up the Spine")
        XCTAssertEqual(ledger.venturesWaiting, ["Your commanders may stand a line in the Ring", "This watch's venture up the Spine still to make"])
        assertTaken(ledger.spine.ventures, in: state, as: me)
        let alone = try XCTUnwrap(ledger.spine.ventures.last)
        _ = try state.perform(alone.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.spine.ventures.isEmpty, "Once a watch")
        XCTAssertEqual(ledger.armyWaiting, 0, "Ventured: nothing waits")
        XCTAssertFalse(ledger.venturesWaiting.contains { $0.contains("Spine") }, "Ventured: the Spine waits no more")
        XCTAssertTrue(ledger.spine.said.hasSuffix("Your House has ventured this watch.") || ledger.spine.said == "Every stage of the Spine is yours.",
                      ledger.spine.said)
    }

    /// The pedlar on the phone, while he lies off one of the House's holds:
    /// where and how long, each ware with its price, bought as the rules sell
    /// it or why not; a ware bought told sold; none while none lies off.
    func testThePhoneBuysOfThePedlar() throws {
        var (state, me) = try world()
        XCTAssertNil(CompanionLedger(world: state, player: me).pedlar, "None lies off")
        let seat = try XCTUnwrap(state.seat(of: me))
        state.pedlars = [Pedlar(house: me, hold: seat.id, at: seat.position, came: state.watch,
                                wares: GameState.pedlarWares(for: me, at: state.watch, firstID: state.takeID()))]
        var pedlar = try XCTUnwrap(CompanionLedger(world: state, player: me).pedlar)
        XCTAssertEqual(pedlar.said, "The Pedlar of the Still lies off \(seat.name); he poles away in \(Pedlar.stays) watches.")
        XCTAssertEqual(pedlar.wares.count, 3)
        XCTAssertTrue(pedlar.wares.allSatisfy { $0.buy != nil && $0.why == nil }, "The House's stores cover all three")
        // Each a row of its own, begun with a capital ("A Ward Stone, for ..."), never "a Ward Stone".
        XCTAssertTrue(pedlar.wares.allSatisfy { $0.title.first.map { !$0.isLowercase } ?? false }, "\(pedlar.wares.map(\.title))")
        assertTaken(pedlar.wares.compactMap(\.buy), in: state, as: me)
        let bought = try XCTUnwrap(pedlar.wares.first?.buy)
        _ = try state.perform(bought.command, as: me)
        pedlar = try XCTUnwrap(CompanionLedger(world: state, player: me).pedlar)
        XCTAssertTrue(pedlar.wares[0].title.hasSuffix(": sold"), pedlar.wares[0].title)
        XCTAssertNil(pedlar.wares[0].buy)

        state.houses[me].stock = Stock()
        pedlar = try XCTUnwrap(CompanionLedger(world: state, player: me).pedlar)
        XCTAssertTrue(pedlar.wares.dropFirst().allSatisfy { $0.buy == nil && $0.why != nil }, "Why not, in the realm's words")
    }

    /// The Lantern Inn on the phone: the House's keys told, a word when one
    /// more silver would be lost; each chest offered one the rules open, a
    /// gold one for moonsalt where there's no gold key.
    func testThePhoneOpensTheInnsChests() throws {
        var (state, me) = try world()
        state.houses[me].stock = Stock(grain: 100, timber: 100, stone: 100, moonsalt: 0)
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.inn.opens.isEmpty, "No key and no moonsalt: no chest")
        XCTAssertEqual(ledger.inn.keys, "0 silver keys and 0 gold keys, of \(InnKeys.mostKeys) of each kept")

        state.innBook = [me: InnKeys(silver: InnKeys.mostKeys, gold: 0, sinceCommander: 0, opened: 0)]
        state.houses[me].stock = Stock(grain: 100, timber: 100, stone: 100, moonsalt: 100)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.inn.opens.map(\.title), ["Open a silver chest", "Open the gold chest for \(InnKeys.goldPrice.moonsalt) moonsalt"])
        XCTAssertTrue(ledger.inn.keys.hasSuffix("open a silver chest, or the next silver key is lost"), ledger.inn.keys)
        assertTaken(ledger.inn.opens, in: state, as: me)
        _ = try state.perform(ledger.inn.opens[0].command, as: me)
        XCTAssertEqual(state.innKeys(of: me).silver, InnKeys.mostKeys - 1)
        XCTAssertFalse(CompanionLedger(world: state, player: me).inn.keys.contains("lost"), "Room for the next key")
    }

    /// The House tab's way to the market, the Inn and the satchel says only
    /// what waits there now: nothing at first; the pedlar while he lies off
    /// with wares unsold, and how many of them the House may buy; the
    /// House's keys at the Inn, and a word before a silver key is lost; the
    /// satchel's items it may use now, and none it can't.
    func testTheHouseTabSaysWhatWaitsAtTheMarketAndTheInn() throws {
        var (state, me) = try world()
        XCTAssertEqual(CompanionLedger(world: state, player: me).errands, [], "Nothing waits but barter")

        let seat = try XCTUnwrap(state.seat(of: me))
        state.pedlars = [Pedlar(house: me, hold: seat.id, at: seat.position, came: state.watch,
                                wares: GameState.pedlarWares(for: me, at: state.watch, firstID: state.takeID()))]
        state.innBook = [me: InnKeys(silver: 2, gold: 1, sinceCommander: 0, opened: 0)]
        _ = state.give(.hourglass, 2, to: me)
        _ = state.give(.grainCache, to: me)
        state.houses[me].stock = Stock(grain: 0, timber: 5_000, stone: 5_000, moonsalt: 500)
        var ledger = CompanionLedger(world: state, player: me)
        let buyable = try XCTUnwrap(ledger.pedlar).wares.filter { $0.buy != nil }.count
        XCTAssertGreaterThan(buyable, 0)
        // His call from the water, keyed as the Mac keys it and given words
        // by the phone's own model.
        let lyingOff = try XCTUnwrap(state.pedlar(for: me))
        XCTAssertEqual(ledger.pedlar?.voice, "pedlar-\(GameState.voiceKey(of: lyingOff))")
        XCTAssertTrue(state.view(for: me).voicedMoments(for: me).contains { $0.key == ledger.pedlar?.voice })
        XCTAssertEqual(ledger.errands, ["The pedlar lies off \(seat.name): \(buyable == 1 ? "a ware" : "\(buyable) wares") you may buy",
                                        "2 silver keys and a gold key to spend at the Inn",
                                        "A \(ItemKind.grainCache.title) ready to use"],
                       "Nothing under way to hasten: the hourglasses wait unsaid")

        // The stores gone and every key spent but five silver: the pedlar told
        // without wares to buy, the Inn a word before the next key is lost.
        state.houses[me].stock = Stock()
        state.innBook = [me: InnKeys(silver: InnKeys.mostKeys, gold: 0, sinceCommander: 0, opened: 0)]
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.errands, ["The pedlar lies off \(seat.name)",
                                        "\(InnKeys.mostKeys) silver keys to spend at the Inn, before the next silver key is lost",
                                        "A \(ItemKind.grainCache.title) ready to use"])

        // Every ware sold, no key, nothing to use: nothing waits.
        let wares = try XCTUnwrap(state.pedlars?.first).wares.indices
        for index in wares { state.pedlars?[0].wares[index].sold = true }
        state.innBook = [:]
        state.houses[me].stock = Stock(grain: state.storage(of: me), timber: 0, stone: 0, moonsalt: 0)
        XCTAssertEqual(CompanionLedger(world: state, player: me).errands, [])
    }

    /// The watch's labours and the happening on the phone, in the Mac's words:
    /// none set at first and the next happening told; the labours as they
    /// stand and the vigour toward the next chest; the happening under way,
    /// what counts in it, the House's points toward its next mark and its place.
    func testThePhoneTellsTheWatchsLaboursAndTheHappening() throws {
        var (state, me) = try world()
        var course = CompanionLedger(world: state, player: me).course
        XCTAssertNil(course.labours, "None set before the first watch turns")
        XCTAssertEqual(course.tasks, [])
        XCTAssertNil(course.standing)
        let next = try XCTUnwrap(state.realmBoard(for: me).nextKind)
        XCTAssertEqual(course.happening, "\(next.title) begins at the tenth watch: \(next.goal).")

        state.labourBook = [me: Labours(watch: state.watch, tasks: [Labour(kind: .muster, done: 0), Labour(kind: .raise, done: 1),
                                                                    Labour(kind: .gather, done: 200)], vigour: 10, opened: 0)]
        course = CompanionLedger(world: state, player: me).course
        XCTAssertEqual(course.labours, "2 of 3 done this watch · vigour 10 of 20 for the next chest")
        XCTAssertEqual(course.tasks, [.init(text: "Muster companies: 0 of 1", done: false), .init(text: "Raise works: 1 of 1", done: true),
                                      .init(text: "Bring stores home from the land's sites: 150 of 150", done: true)])

        var muster = Happening(number: 0, kind: .muster, begins: state.watch, houses: state.houses.count)
        let other = (me + 1) % state.houses.count
        muster.points[me] = 14
        muster.passed[me] = 1
        muster.points[other] = 30
        muster.passed[other] = 2
        state.happening = muster
        course = CompanionLedger(world: state, player: me).course
        XCTAssertEqual(course.happening, "The Great Muster, until the \(ordinal(muster.ends)) watch, \(muster.ends - state.watch) to go: "
                       + "\(HappeningKind.muster.goal).")
        XCTAssertEqual(course.standing, "Your points: 14 of 25 for the next mark, second of 2 with points")
        state.happening?.passed[me] = Happening.marks.count
        XCTAssertEqual(CompanionLedger(world: state, player: me).course.standing, "Your points: 14, every mark passed, second of 2 with points")
    }

    /// The Infirmary on the phone, in the Mac's words: nothing while none lie
    /// in a hold's beds; those carried in told, and their healing offered for
    /// what it costs, one the rules take; paid for, told healing and offered
    /// no more; one more carried in with the stores gone, told, not offered.
    func testThePhoneHealsTheWoundedInTheInfirmary() throws {
        var (state, me) = try world()
        let seat = try XCTUnwrap(state.seat(of: me))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        func hold() throws -> CompanionLedger.Hold {
            try XCTUnwrap(CompanionLedger(world: state, player: me).holds.first { $0.id == seat.id })
        }
        XCTAssertNil(try hold().infirmary, "None in its beds")
        XCTAssertNil(try hold().heal)

        state.holds[index].levels[.infirmary] = 2
        state.holds[index].wounded = [Wounded(kind: .spear, tier: 2, experience: 3, since: state.watch),
                                      Wounded(kind: .bow, tier: 1, experience: 0, since: state.watch)]
        let beds = state.holds[index].beds
        XCTAssertEqual(try hold().infirmary, "Infirmary, 2 of \(beds) beds: Spears II · Bows I")
        let heal = try XCTUnwrap(try hold().heal)
        XCTAssertEqual(heal.title, "Heal 2 for \(state.healingCost(at: state.holds[index]))")
        XCTAssertEqual(CompanionLedger(world: state, player: me).houseWaiting, 1, "The House tab's badge: wounded to heal")
        assertTaken([heal], in: state, as: me)
        _ = try state.perform(heal.command, as: me)
        XCTAssertEqual(try hold().infirmary, "Infirmary, 2 of \(beds) beds: Spears II, healing · Bows I, healing")
        XCTAssertNil(try hold().heal, "Paid for, none left waiting")
        XCTAssertEqual(CompanionLedger(world: state, player: me).houseWaiting, 0)

        let carried = Wounded(kind: .rider, tier: 1, experience: 0, since: state.watch)
        state.holds[index].wounded?.append(carried)
        state.houses[me].stock = Stock()
        XCTAssertEqual(try hold().infirmary, "Infirmary, 3 of \(beds) beds: Spears II, healing · Bows I, healing · Riders I")
        XCTAssertNil(try hold().heal, "The stores can't pay for it")
        XCTAssertNotNil(state.refusal(of: .heal(hold: seat.id), as: me), "Nor would the rules take it")
    }

    /// The veil of the Still on the phone, in the Mac's words: offered for its
    /// moonsalt and taken by the rules; drawn, told until when and offered no
    /// more; lifted, told when it may be drawn anew; rested, offered again,
    /// but not without the moonsalt, and then not told on the House tab at
    /// all while no foe gathers near.
    func testThePhoneDrawsTheVeilOfTheStill() throws {
        var (state, me) = try world()
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.veil, "The veil of the Still, for \(GameState.veilCost): for \(GameState.veilLasts) watches none may "
                       + "strike your holds, unless you strike first.")
        let draw = try XCTUnwrap(ledger.drawVeil)
        XCTAssertEqual(draw.command, .drawVeil)
        XCTAssertFalse(ledger.veiled)
        XCTAssertNil(ledger.veilShort, "Moonsalt enough, nothing short")
        XCTAssertTrue(ledger.wallsTold, "It may be drawn: told")
        assertTaken([draw], in: state, as: me)
        _ = try state.perform(draw.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.veiled)
        XCTAssertNil(ledger.veilShort, "Lying, its words say until when")
        let until = state.watch + GameState.veilLasts
        XCTAssertEqual(ledger.veil, "Veiled until watch \(until): none may strike, rally on or scout your holds, unless you strike first.")
        XCTAssertNil(ledger.drawVeil, "Drawn already")
        XCTAssertTrue(ledger.wallsTold, "Lying: told")

        state.watch = until
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.veil, "The mist gathers again: the veil may be drawn anew at watch \(until + GameState.veilRest).")
        XCTAssertNil(ledger.drawVeil)
        XCTAssertTrue(ledger.wallsTold, "Resting: told, and until when")
        state.watch = until + GameState.veilRest
        XCTAssertNotNil(CompanionLedger(world: state, player: me).drawVeil, "Rested")
        state.houses[me].stock = Stock(grain: 100, timber: 100, stone: 100, moonsalt: 6)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertNil(ledger.drawVeil, "Too little moonsalt for it")
        XCTAssertEqual(ledger.veilShort, "Short of 24 moonsalt.", "What it is short of, as the Mac's seat record says it")
        XCTAssertFalse(ledger.veiled)
        XCTAssertTrue(ledger.gatherings.isEmpty)
        XCTAssertFalse(ledger.wallsTold, "A veil it can't pay for, no foe near: not on the House tab")
    }

    /// The Lyceum on the phone, as the Mac's card sets it: nothing while it
    /// doesn't sit; sitting, the House's next question with its four answers,
    /// each one the rules take, and the House tab counting it; answered, the
    /// next; all five answered, nothing more.
    func testThePhoneAnswersTheLyceum() throws {
        var (state, me) = try world()
        state.watch = 12
        XCTAssertNil(CompanionLedger(world: state, player: me).lyceum, "It doesn't sit")
        state.watch = 20
        state.openLyceum()
        let questions = try XCTUnwrap(state.lyceumNow)
        var asked = try XCTUnwrap(CompanionLedger(world: state, player: me).lyceum)
        XCTAssertEqual(asked.place, "1 of \(Lyceum.questions)")
        XCTAssertEqual(asked.text, questions[0].text)
        XCTAssertEqual(asked.answers.map(\.title), questions[0].choices)
        assertTaken(asked.answers, in: state, as: me)
        XCTAssertEqual(CompanionLedger(world: state, player: me).houseWaiting, 1, "The House tab's badge: the Lyceum sits")
        _ = try state.perform(asked.answers[0].command, as: me)
        asked = try XCTUnwrap(CompanionLedger(world: state, player: me).lyceum)
        XCTAssertEqual(asked.place, "2 of \(Lyceum.questions)")
        XCTAssertEqual(asked.text, questions[1].text)
        for _ in 1..<Lyceum.questions {
            let next = try XCTUnwrap(CompanionLedger(world: state, player: me).lyceum?.answers.first)
            _ = try state.perform(next.command, as: me)
        }
        XCTAssertNil(CompanionLedger(world: state, player: me).lyceum, "Every question answered")
        XCTAssertEqual(CompanionLedger(world: state, player: me).houseWaiting, 0)
    }

    /// What still waits for the keeper's orders on the phone, as the Mac's
    /// top bar says it: companies that may still act this watch, on no march
    /// and not dug in, and holds raising nothing; nothing said when none do.
    func testThePhoneSaysWhatStillWaitsForOrders() throws {
        var (state, me) = try world()
        let companies = state.units(of: me).filter { $0.movesLeft > 0 && $0.destination == nil && !$0.fortified }
        let idle = state.holds(of: me).filter { $0.project == nil }
        XCTAssertFalse(companies.isEmpty)
        XCTAssertFalse(idle.isEmpty)
        XCTAssertEqual(CompanionLedger(world: state, player: me).waiting, GameState.waitingSaid(companies: companies.count, holds: idle.count))
        for company in companies {
            let index = try XCTUnwrap(state.units.firstIndex { $0.id == company.id })
            state.units[index].fortified = true
        }
        for hold in idle {
            let index = try XCTUnwrap(state.holdIndex(hold.id))
            state.holds[index].project = Hold.Project(kind: .granary, targetLevel: 2, watchesLeft: 3, watches: 3)
        }
        XCTAssertNil(CompanionLedger(world: state, player: me).waiting, "Every company dug in, every hold at work")
        XCTAssertEqual(GameState.waitingSaid(companies: 2, holds: 1), "2 companies wait · 1 hold idle")
        XCTAssertEqual(GameState.waitingSaid(companies: 1, holds: 0), "1 company waits")
        XCTAssertEqual(GameState.waitingSaid(companies: 0, holds: 3), "3 holds idle")
        XCTAssertNil(GameState.waitingSaid(companies: 0, holds: 0))
    }

    /// The House's stores on the phone as the Mac's top bar shows them:
    /// each with what it gains as the watch turns, the holds' income and
    /// the grain less what the companies eat, and that gain is what each
    /// store gains when the watch turns; a store losing told so, read aloud
    /// in the same words as on the Mac.
    func testThePhoneTellsWhatEachStoreGainsAsTheWatchTurns() throws {
        var (state, me) = try world()
        state.houses[me].stock = Stock(grain: 40, timber: 40, stone: 40, moonsalt: 10)
        let ledger = CompanionLedger(world: state, player: me)
        let income = state.income(of: me)
        let upkeep = state.upkeep(of: me)
        XCTAssertGreaterThan(upkeep, 0, "The House's companies eat")
        XCTAssertEqual(ledger.stores.map(\.resource), Resource.allCases)
        XCTAssertEqual(ledger.stores.map(\.amount), [40, 40, 40, 10])
        XCTAssertEqual(ledger.stores.map(\.gain), Resource.allCases.map { income[$0] - ($0 == .grain ? upkeep : 0) })
        XCTAssertEqual(ledger.stores.map(\.gain), Resource.allCases.map { state.gain(of: me)[$0] })
        // The watch turns: each store gains what was told.
        _ = state.endWatch()
        XCTAssertEqual(Resource.allCases.map { state.houses[me].stock[$0] }, ledger.stores.map { $0.amount + $0.gain })
        // Companies that eat more than the land brings in: the grain told losing.
        let seat = try XCTUnwrap(state.seat(of: me))
        for _ in 0..<40 {
            state.units.append(Unit(id: state.takeID(), kind: .spear, owner: me, position: seat.position))
        }
        let starving = CompanionLedger(world: state, player: me)
        let grain = try XCTUnwrap(starving.stores.first { $0.resource == .grain })
        XCTAssertLessThan(grain.gain, 0)
        XCTAssertEqual(grain.gain, state.income(of: me).grain - state.upkeep(of: me))
        XCTAssertEqual(Resource.gainSaid(12), "+12")
        XCTAssertEqual(Resource.gainSaid(0), "+0")
        XCTAssertEqual(Resource.gainSaid(-3), "−3")
        XCTAssertEqual(Resource.grain.storeName(40, room: 400), "Grain")
        XCTAssertEqual(Resource.grain.storeName(400, room: 400), "Grain · full")
        XCTAssertEqual(Resource.timber.storeSaid(60, gain: 12, room: 400), "Timber 60, gaining 12 each watch, storage 400")
        XCTAssertEqual(Resource.grain.storeSaid(60, gain: -3, room: 400), "Grain 60, losing 3 each watch, storage 400")
    }

    /// Prisoners from the phone, as the Mac's Commanders show them: a
    /// commander of another House the House holds, told whose they are and
    /// how long until they slip away, with Question and Let go, each taken
    /// by the rules, the Army tab counting a prisoner to question;
    /// questioned, the true thing they told shown plainly and no second
    /// question offered this watch; let go, gone. And the House's own
    /// commander held by another: their ransom offered while the stores
    /// would pay it, and not without.
    func testThePhoneQuestionsLetsGoAndRansomsPrisoners() throws {
        var (state, me) = try world()
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        let theirs = try XCTUnwrap(state.commanders(of: other).first)
        let waitingBefore = CompanionLedger(world: state, player: me).armyWaiting
        XCTAssertTrue(CompanionLedger(world: state, player: me).prisoners.isEmpty)
        func hold(_ commander: Commander, by captor: Int) throws {
            let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == commander.id })
            let held = Captivity(by: captor, since: state.watch, questioned: 0, lastQuestioned: nil)
            state.commanders?[index].captive = held
        }
        try hold(theirs, by: me)
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.prisoners.map(\.id), [theirs.id])
        var prisoner = try XCTUnwrap(ledger.prisoners.first)
        XCTAssertEqual(prisoner.name, theirs.name)
        XCTAssertEqual(prisoner.of, "of \(state.houses[other].title), level \(theirs.level)")
        XCTAssertEqual(prisoner.held, "Slips away in \(GameState.captivityLasts) watches")
        XCTAssertNil(prisoner.told)
        let question = try XCTUnwrap(prisoner.question)
        XCTAssertEqual(question.title, "Question \(theirs.name)")
        XCTAssertEqual(prisoner.release.title, "Let \(theirs.name) go home")
        assertTaken([question, prisoner.release], in: state, as: me)
        XCTAssertEqual(ledger.armyWaiting, waitingBefore + 1, "A prisoner to question")

        // Questioned: the true thing told plainly, and once a watch.
        _ = try state.perform(question.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        prisoner = try XCTUnwrap(ledger.prisoners.first)
        let told = try XCTUnwrap(state.commander(theirs.id)?.captive?.told?.last)
        XCTAssertEqual(prisoner.told, told)
        XCTAssertTrue(state.knowledge(of: other).contains(told), "One true thing of their House")
        XCTAssertNil(prisoner.question, "Questioned this watch")
        XCTAssertEqual(ledger.armyWaiting, waitingBefore)

        // Let go: gone home, a prisoner no more.
        _ = try state.perform(prisoner.release.command, as: me)
        XCTAssertTrue(CompanionLedger(world: state, player: me).prisoners.isEmpty)
        XCTAssertNil(state.commander(theirs.id)?.captive)

        // The House's own commander held by another: ransomed while the stores pay it.
        let mine = try XCTUnwrap(state.commanders(of: me).first)
        XCTAssertNil(CompanionLedger(world: state, player: me).commanders.first { $0.id == mine.id }?.ransom, "Not held: no ransom")
        try hold(mine, by: other)
        ledger = CompanionLedger(world: state, player: me)
        let line = try XCTUnwrap(ledger.commanders.first { $0.id == mine.id })
        XCTAssertEqual(line.standing, "Held prisoner by \(state.houses[other].title)")
        let ransom = try XCTUnwrap(line.ransom)
        XCTAssertEqual(ransom.title, "Ransom for \(GameState.ransom(for: mine))")
        assertTaken([ransom], in: state, as: me)
        state.houses[me].stock.moonsalt = 5
        XCTAssertNil(CompanionLedger(world: state, player: me).commanders.first { $0.id == mine.id }?.ransom, "Not without the moonsalt")
        state.houses[me].stock.moonsalt = 500
        _ = try state.perform(ransom.command, as: me)
        XCTAssertNil(state.commander(mine.id)?.captive, "Ransomed home")
        XCTAssertNil(CompanionLedger(world: state, player: me).commanders.first { $0.id == mine.id }?.ransom)
    }

    /// The realm's law from the phone, in the Mac's words: nothing to tell
    /// while the House may put no edict and none is before the realm; with
    /// two holds, each edict offered for its cost and taken by the rules;
    /// one another keeper put, told before the realm with its tally, Aye
    /// and Nay offered and taken and the Alliance tab counting the vote to
    /// cast, none to put meanwhile; voted, the House's vote told and
    /// offered no more; passed, holding the realm in its line.
    func testThePhonePutsAndVotesOnTheRealmsLaw() throws {
        var (state, me) = try world()
        for house in state.houses.indices where !state.houses[house].isPlayer { state.houses[house].temperament = .wary }
        XCTAssertTrue(CompanionLedger(world: state, player: me).law.isEmpty, "One hold: nothing to tell, nothing to put")
        let seat = try XCTUnwrap(state.seat(of: me))
        let ground = try XCTUnwrap(seat.position.spiral(4).dropFirst(7).first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !state.isOccupied(hex) && state.hold(at: hex) == nil
        })
        state.holds.append(Hold(id: state.takeID(), name: "Second", owner: me, position: ground, isSeat: false, foundedWatch: 1))
        var law = CompanionLedger(world: state, player: me).law
        XCTAssertNil(law.before)
        XCTAssertTrue(law.inForce.isEmpty)
        XCTAssertEqual(law.proposals.map(\.heading), EdictKind.allCases.map(\.heading))
        XCTAssertEqual(law.proposals.map(\.law), EdictKind.allCases.map(\.lawSaid))
        XCTAssertEqual(law.proposals.first?.order.title, "Put \(EdictKind.allCases[0].title) to the realm, for \(GameState.edictCost)")
        assertTaken(law.proposals.map(\.order), in: state, as: me)
        let waitingBefore = CompanionLedger(world: state, player: me).allianceWaiting

        // Another keeper puts Safe Conduct to the realm.
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        state.houses[other].isPlayer = true
        state.edicts = [Edict(id: state.takeID(), kind: .safeConduct, proposer: other, proposed: state.watch, ayes: [other])]
        let edict = try XCTUnwrap(state.edictInVote)
        var ledger = CompanionLedger(world: state, player: me)
        law = ledger.law
        XCTAssertEqual(law.before, "Before the realm, put by \(state.houses[other].title): Safe Conduct, \(EdictKind.safeConduct.law).")
        XCTAssertEqual(law.tally, state.tallySaid(edict))
        XCTAssertNil(law.voted)
        XCTAssertEqual(law.votes.map(\.title), ["Vote aye on Safe Conduct", "Vote nay on Safe Conduct"])
        assertTaken(law.votes, in: state, as: me)
        XCTAssertTrue(law.proposals.isEmpty, "None may be put while one is before the realm")
        XCTAssertEqual(ledger.allianceWaiting, waitingBefore + 1, "A vote to cast")
        XCTAssertEqual(ledger.realmWaiting, ["A vote to cast on the edict before the realm"], "Said on the way to the realm's page")

        // Voted aye: told, and offered no more.
        _ = try state.perform(law.votes[0].command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.law.voted, "Your House votes aye.")
        XCTAssertTrue(ledger.law.votes.isEmpty)
        XCTAssertEqual(ledger.allianceWaiting, waitingBefore)

        // The vote closes and the edict passes: it holds the realm.
        for _ in 0..<GameState.edictVote { _ = state.endWatch() }
        let held = try XCTUnwrap(state.edictsInForce.first)
        law = CompanionLedger(world: state, player: me).law
        XCTAssertNil(law.before)
        XCTAssertEqual(law.inForce, [state.inForceSaid(held)])
        XCTAssertTrue(law.inForce[0].hasPrefix("Safe Conduct holds"), law.inForce[0])
        XCTAssertFalse(law.proposals.contains { $0.heading == EdictKind.safeConduct.heading }, "Not put again while it holds")
        XCTAssertEqual(EdictKind.safeConduct.lawSaid, "No House strikes Founders or Lanterns.")
    }

    /// A House's Lanterns scout from the phone, as on the Mac: a Lantern
    /// within two tiles of another House's hold offered Scout, taken by the
    /// rules; scouted, its moves spent, offered no more; none offered by a
    /// hold of its own House or one beyond its reach.
    func testThePhoneSendsLanternsToScoutAHold() throws {
        var (state, me) = try world()
        let foreign = try XCTUnwrap(state.holds.first { $0.owner != me })
        let near = try XCTUnwrap(foreign.position.spiral(2).dropFirst().first { hex in
            hex.distance(to: foreign.position) == 2
                && state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && !state.isOccupied(hex) && state.hold(at: hex) == nil
        })
        let lantern = Unit(id: state.takeID(), kind: .lantern, owner: me, position: near)
        state.units.append(lantern)
        func scouting() throws -> [CompanionLedger.Order] {
            let company = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == lantern.id })
            return company.orders.filter { if case .scout = $0.command { return true }; return false }
        }
        let offered = try scouting()
        XCTAssertEqual(offered.first?.title, "Scout \(foreign.name)")
        XCTAssertEqual(offered.first?.command, .scout(unit: lantern.id, hold: foreign.id))
        XCTAssertFalse(offered.contains { if case .scout(_, let hold) = $0.command { return state.hold(hold)?.owner == me }; return false },
                       "Never the House's own hold")
        assertTaken(offered, in: state, as: me)
        let events = try state.perform(try XCTUnwrap(offered.first).command, as: me)
        XCTAssertTrue(events.contains { if case .holdScouted = $0 { return true }; return false })
        XCTAssertTrue(try scouting().isEmpty, "Its moves spent")
        // Beyond reach: nothing offered.
        let far = try XCTUnwrap(state.seat(of: me)).position
        let home = Unit(id: state.takeID(), kind: .lantern, owner: me, position: far)
        state.units.append(home)
        let homeCompany = try XCTUnwrap(CompanionLedger(world: state, player: me).companies.first { $0.id == home.id })
        XCTAssertEqual(homeCompany.orders.filter { if case .scout = $0.command { return true }; return false }.isEmpty,
                       !state.holds.contains { $0.owner != me && $0.position.distance(to: far) <= GameState.scoutReach })
    }

    /// The Ring from the phone, as the Mac's Commanders tell it: standing
    /// no line, told how to enter and offered its heaviest commanders as
    /// its line, taken by the rules; stood, told its standing and the
    /// challenges left it, the same line offered no more; another keeper's
    /// line told with its standing and weight and challenged, taken by the
    /// rules; the bout told, and a challenge fewer left.
    func testThePhoneStandsALineInTheRingAndChallenges() throws {
        var (state, me) = try world()
        _ = state.commanderJoins(me, why: "answers the banner of")
        var ring = CompanionLedger(world: state, player: me).ring
        XCTAssertTrue(ring.standing.hasPrefix("Your House stands no line in the Ring."), ring.standing)
        XCTAssertTrue(ring.rivals.isEmpty)
        let stand = try XCTUnwrap(ring.stand)
        let strongest = state.strongestRingLine(of: me)
        XCTAssertEqual(stand.command, .standInTheRing(strongest))
        XCTAssertEqual(strongest.count, 2)
        XCTAssertGreaterThanOrEqual(state.ringWeight(of: try XCTUnwrap(state.commander(strongest[0]))),
                                    state.ringWeight(of: try XCTUnwrap(state.commander(strongest[1]))), "The heaviest first")
        let names = strongest.compactMap { state.commander($0)?.name }
        XCTAssertEqual(stand.title, "Stand \(names[0]) and \(names[1]) in the Ring")
        assertTaken([stand], in: state, as: me)
        _ = try state.perform(stand.command, as: me)
        ring = CompanionLedger(world: state, player: me).ring
        XCTAssertEqual(ring.standing, "Your standing is \(GameState.ringStart), first of 1. \(GameState.ringChallenges) challenges left this watch.")
        XCTAssertNil(ring.stand, "That line stands already")

        // Another keeper stands a line: told, and challenged.
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        state.houses[other].isPlayer = true
        let theirs = try XCTUnwrap(state.commanders(of: other).first).id
        _ = try state.perform(.standInTheRing([theirs]), as: other)
        ring = CompanionLedger(world: state, player: me).ring
        let rival = try XCTUnwrap(ring.rivals.first)
        XCTAssertEqual(rival.id, other)
        XCTAssertEqual(rival.name, state.houses[other].title)
        XCTAssertEqual(rival.line, state.ringLineSaid(of: other))
        let challenge = try XCTUnwrap(rival.challenge)
        XCTAssertEqual(challenge.title, "Challenge \(state.houses[other].title)")
        assertTaken([challenge], in: state, as: me)
        _ = try state.perform(challenge.command, as: me)
        ring = CompanionLedger(world: state, player: me).ring
        let bout = try XCTUnwrap(state.ring?.bouts.last)
        XCTAssertEqual(ring.bouts, [state.boutSaid(bout, to: me)])
        XCTAssertTrue(ring.bouts[0].hasPrefix("Watch \(bout.watch): You challenged \(state.houses[other].title), and"), ring.bouts[0])
        XCTAssertTrue(ring.standing.hasSuffix("\(GameState.ringChallenges - 1) challenges left this watch."), ring.standing)
        // Said on the Army tab's way to the Ring and the Spine.
        let ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.venturesWaiting.first, "A keeper's line to challenge in the Ring")
        XCTAssertEqual(ledger.venturesWaiting.contains("This watch's venture up the Spine still to make"), !ledger.spine.ventures.isEmpty)
    }

    /// The Forge from the phone, as the Mac's Commanders tell it: with none,
    /// told how to come by one; with a Forge and makings enough, each piece
    /// of the three sets at the finest it makes told with what it gives
    /// and takes, offered where the rules would forge it, and said on the
    /// way to the page; forged, into the House's armoury.
    func testThePhoneForgesGear() throws {
        var (state, me) = try world()
        var forge = CompanionLedger(world: state, player: me).forge
        XCTAssertEqual(forge.heading, "Forge")
        XCTAssertEqual(forge.none, GameState.noForgeSaid)
        XCTAssertTrue(forge.sets.isEmpty)
        XCTAssertEqual(forge.makings, state.makingsSaid(of: me))
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.forge] = 1
        _ = state.give(makings: Dictionary(uniqueKeysWithValues: Making.allCases.map { ($0, 60) }), to: me)
        forge = CompanionLedger(world: state, player: me).forge
        XCTAssertEqual(forge.heading, "Forge · level I")
        XCTAssertNil(forge.none)
        XCTAssertEqual(forge.sets.map(\.name), GearSet.allCases.map(\.name))
        let quality = try XCTUnwrap(GearQuality.forged(atLevel: 1))
        let first = try XCTUnwrap(GearSet.allCases.first?.pieces.first)
        let piece = try XCTUnwrap(forge.sets.first?.pieces.first)
        XCTAssertEqual(piece.title, "\(first.title) · \(first.slot.title.lowercased())")
        XCTAssertTrue(piece.said.hasSuffix("Takes \(state.recipeSaid(first, quality, for: me))."), piece.said)
        let offered = forge.sets.flatMap(\.pieces).compactMap(\.forge)
        XCTAssertFalse(offered.isEmpty)
        assertTaken(offered, in: state, as: me)
        XCTAssertEqual(forge.forgeable, offered.count)
        let ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.venturesWaiting.contains { $0.contains("the Forge may make") }, "\(ledger.venturesWaiting)")
        let before = state.gear(of: me).count
        _ = try state.perform(try XCTUnwrap(offered.first).command, as: me)
        XCTAssertEqual(state.gear(of: me).count, before + 1, "Into the armoury")
    }

    /// The shares of the alliance's spoils on the phone, as the Mac's
    /// Alliance panel shows them: none while none waits; each share's deed,
    /// the newest first, what they hold all told and the order to take
    /// them, taken by the rules, the Alliance tab's count waiting with them;
    /// taken, gone.
    func testThePhoneOffersTheSharesOfTheSpoils() throws {
        var (state, me) = try world()
        XCTAssertNil(CompanionLedger(world: state, player: me).shares)
        _ = try state.perform(.foundAlliance(name: "The Salt Pact"), as: me)
        let ally = (me + 1) % state.houses.count
        state.houses[ally].isPlayer = true
        let alliance = try XCTUnwrap(state.alliance(of: me)).id
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: alliance, accept: true), as: ally)
        let quiet = CompanionLedger(world: state.view(for: me), player: me).allianceWaiting
        state.tally([.hunted(Hunt(attacker: 1, attackerOwner: ally, attackerKind: .spear, wild: 2, wildKind: .reavers, level: 2,
                                  at: Hex(0, 0), damageDealt: 9, damageTaken: 0, attackerFell: false, wildFell: true, spoils: Stock())),
                     .lairAssaulted(LairAssault(rally: 1, caller: me, lair: 3, kind: .barrowkin, level: 1, at: Hex(0, 0), strikes: [],
                                                before: 40, strength: 0, might: 30, shares: []))])
        let view = state.view(for: me)
        let ledger = CompanionLedger(world: view, player: me)
        let shares = try XCTUnwrap(ledger.shares)
        XCTAssertEqual(shares.count, 2)
        XCTAssertEqual(shares.lines, ["Your House broke a lair of the wilds, level I",
                                      "\(state.houses[ally].title) struck down a band of the wilds, level II"])
        XCTAssertEqual(shares.held, "50 grain, 50 timber, 30 stone, 1 moonsalt, with a Salt Hourglass")
        XCTAssertEqual(shares.take.command, .takeShares)
        assertTaken([shares.take], in: view, as: me)
        XCTAssertEqual(ledger.allianceWaiting, quiet + 1, "the Alliance tab counts them waiting")
        _ = try state.perform(.takeShares, as: me)
        XCTAssertNil(CompanionLedger(world: state.view(for: me), player: me).shares, "taken, gone")
    }

    /// The Rankings on the phone, as the Mac's Realm panel shows them, read
    /// from the keeper's view: every House and alliance by might and by
    /// foes slain, and where the House stands in a line; the ledger changed
    /// when only they change.
    func testThePhoneShowsTheRankings() throws {
        var (state, me) = try world()
        let foe = (me + 1) % state.houses.count
        state.foesSlain = [Int](repeating: 0, count: state.houses.count)
        state.foesSlain![foe] = 900
        let view = state.view(for: me)
        let ledger = CompanionLedger(world: view, player: me)
        XCTAssertEqual(ledger.rankings, view.rankings(for: me))
        XCTAssertEqual(ledger.rankings.map(\.title), ["Houses by might", "Houses by foes slain", "Alliances by might", "Alliances by foes slain"])
        XCTAssertEqual(ledger.rankings[1].lines.map(\.id), [foe])
        XCTAssertEqual(ledger.rankings[1].lines.map(\.figure), [900])
        XCTAssertEqual(ledger.rankings[0].lines.map(\.at), ledger.rankings[0].lines.map { view.seat(of: $0.id)?.position },
                       "each line leads to its House's seat, where the chart may turn")
        XCTAssertEqual(ledger.rankingsSaid, view.rankingsSaid(for: me))
        XCTAssertTrue(ledger.rankingsSaid.hasSuffix(" by might and has slain no foe this age."), ledger.rankingsSaid)
        XCTAssertEqual(ledger.rankings[2].standing, "Your House is sworn to no alliance.")
        state.foesSlain![me] = 1_200
        let later = CompanionLedger(world: state.view(for: me), player: me)
        XCTAssertNotEqual(later, ledger, "changed when only the rankings change")
        XCTAssertEqual(later.rankings[1].lines.first?.isOwn, true)
    }

    /// What the House's alliance keeps of its own on the phone, in the words
    /// of the Mac's Alliance panel: nothing while sworn to no alliance;
    /// sworn, its standards, hall, coffers, storehouse and yards told, and
    /// nothing to lay up while no storehouse stands; the leader may cast
    /// another House out, the other may not; the storehouse standing whole,
    /// what the House has laid up, each measure offered to lay up and take
    /// back as the rules take it, and all it laid up.
    func testThePhoneKeepsTheAlliancesOwnStoresAndCastsOut() throws {
        var (state, me) = try world()
        XCTAssertNil(CompanionLedger(world: state, player: me).allianceOwn)
        _ = try state.perform(.foundAlliance(name: "The Stone Accord"), as: me)
        let ally = (me + 1) % state.houses.count
        state.houses[ally].isPlayer = true
        let founded = try XCTUnwrap(state.alliance(of: me))
        _ = try state.perform(.inviteToAlliance(house: ally), as: me)
        _ = try state.perform(.answerInvitation(alliance: founded.id, accept: true), as: ally)
        var ledger = CompanionLedger(world: state, player: me)
        let sworn = try XCTUnwrap(state.alliance(of: me))
        let own = try XCTUnwrap(ledger.allianceOwn)
        XCTAssertEqual(own.lines, [state.standardsSaid(of: sworn), state.hallSaid(of: sworn), state.coffersSaid(of: sworn),
                                   state.storehouseSaid(of: sworn), state.yardsSaid(of: sworn)])
        XCTAssertTrue(own.lines[3].hasPrefix("Storehouse: none yet."), own.lines[3])
        XCTAssertNil(own.laidUp)
        XCTAssertTrue(own.layUp.isEmpty && own.takeBack.isEmpty, "Nothing laid up while no storehouse stands")
        XCTAssertEqual(ledger.castOut.map(\.title), ["Cast \(state.houses[ally].title) out of The Stone Accord"])
        assertTaken(ledger.castOut, in: state, as: me)
        XCTAssertTrue(CompanionLedger(world: state, player: ally).castOut.isEmpty, "Not the ally's to do")

        // A standard stands, and the storehouse rises whole on its land.
        let seat = try XCTUnwrap(state.seat(of: me))
        state.reveal(around: seat.position, range: 7, for: me)
        let flag = try XCTUnwrap(seat.position.spiral(3).first { hex in
            (2...3).contains(hex.distance(to: seat.position)) && state.standardRefusal(at: hex, by: me) == nil
        })
        _ = try state.perform(.raiseStandard(at: flag), as: me)
        for index in (state.standards ?? []).indices { state.standards![index].built = Standard.raising }
        let spot = try XCTUnwrap(flag.spiral(Standard.reach).first { state.storehouseRefusal(at: $0, by: me) == nil })
        _ = try state.perform(.raiseStorehouse(at: spot), as: me)
        for _ in 0..<Storehouse.raising { _ = state.keepAllianceStores() }
        state.houses[me].stock.grain = 200 // room enough to take back what it lays up
        ledger = CompanionLedger(world: state, player: me)
        let standing = try XCTUnwrap(ledger.allianceOwn)
        XCTAssertTrue(standing.lines[3].hasPrefix("Storehouse: standing"), standing.lines[3])
        XCTAssertEqual(standing.laidUp, Storehouse.laidUpSaid(.zero))
        XCTAssertEqual(standing.layUp.map(\.title), Storehouse.measures.map { "Lay up \($0)" })
        XCTAssertTrue(standing.takeBack.isEmpty, "Nothing laid up to take back")
        assertTaken(standing.layUp, in: state, as: me)

        // Laid up: told, and offered back.
        let first = Storehouse.measures[0]
        _ = try state.perform(try XCTUnwrap(standing.layUp.first).command, as: me)
        let laid = try XCTUnwrap(CompanionLedger(world: state, player: me).allianceOwn)
        XCTAssertEqual(laid.laidUp, Storehouse.laidUpSaid(first))
        XCTAssertEqual(laid.takeBack.map(\.title), ["Take back \(first)", "Take back all you laid up"])
        assertTaken(laid.takeBack, in: state, as: me)
    }

    /// The Augury on the phone, as the Mac's Realm panel tells it: no
    /// prophecy, nothing; another keeper's, told with how it stands and a
    /// stake offered on either side, taken by the rules; staked, told
    /// anew and offered no more; the House's own, told as its own.
    func testThePhoneStakesOnTheAugury() throws {
        var (state, me) = try world()
        XCTAssertTrue(CompanionLedger(world: state, player: me).prophecies.isEmpty)
        XCTAssertTrue(CompanionLedger(world: state, player: me).mayForetell)
        XCTAssertTrue(CompanionLedger(world: state, player: me).hasRealmMatters, "A keeper may always foretell")
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        let third = try XCTUnwrap(state.houses.last { $0.id != me && $0.id != other }?.id)
        state.houses[other].isPlayer = true
        state.houses[other].stock.moonsalt = 100
        _ = try state.perform(.prophesy(.falls(house: third), until: state.watch + 12, moonsalt: 20), as: other)
        let prophecy = try XCTUnwrap(state.prophecies.first)
        var ledger = CompanionLedger(world: state, player: me)
        let told = try XCTUnwrap(ledger.prophecies.first)
        XCTAssertEqual(told.said, "\(state.houses[other].title) foretells that \(state.told(prophecy.claim)) by watch \(prophecy.until).")
        XCTAssertEqual(told.standing, "20 moonsalt backing it, 0 against; stakes close at watch \(prophecy.stakesClose).")
        let back = try XCTUnwrap(told.back), against = try XCTUnwrap(told.standAgainst)
        XCTAssertEqual(back.title, "Back it with \(Prophecy.stakeLaid) moonsalt")
        XCTAssertEqual(against.title, "Stand against it with \(Prophecy.stakeLaid) moonsalt")
        assertTaken([back, against], in: state, as: me)
        XCTAssertTrue(ledger.hasRealmMatters)
        XCTAssertEqual(ledger.realmWaiting, ["A prophecy open to your stake"])
        _ = try state.perform(against.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        let staked = try XCTUnwrap(ledger.prophecies.first)
        XCTAssertEqual(staked.standing, "20 moonsalt backing it, \(Prophecy.stakeLaid) against; stakes close at watch \(prophecy.stakesClose).")
        XCTAssertNil(staked.back, "Staked once")
        XCTAssertNil(staked.standAgainst)
        XCTAssertEqual(ledger.realmWaiting, [], "Nothing more waits once staked")
        // To its prophet, its own.
        XCTAssertTrue(CompanionLedger(world: state, player: other).prophecies.first?.said.hasPrefix("You foretold that ") == true)
    }

    /// A prophecy of the House's own made from the phone, as the Mac's
    /// Augury makes one: nothing until a House is chosen; a House's fall
    /// said with its stake and Foretell taken by the rules; war wanting its
    /// second House; foretold, the House may foretell no more while it is
    /// open, and a prophecy refused says why.
    func testThePhoneForetells() throws {
        var (state, me) = try world()
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        XCTAssertNil(CompanionLedger.foretelling(.falls, first: nil, second: nil, in: state, player: me), "Of no House yet")
        XCTAssertNil(CompanionLedger.foretelling(.war, first: other, second: nil, in: state, player: me), "Wanting the second House")
        let falls = try XCTUnwrap(CompanionLedger.foretelling(.falls, first: other, second: nil, in: state, player: me))
        let until = state.watch + Prophecy.lookedAhead
        XCTAssertEqual(falls.said, "That \(state.told(.falls(house: other))) by watch \(until), staking \(Prophecy.stakeLaid) moonsalt.")
        let foretell = try XCTUnwrap(falls.foretell)
        XCTAssertNil(falls.why)
        assertTaken([foretell], in: state, as: me)
        _ = try state.perform(foretell.command, as: me)
        let ledger = CompanionLedger(world: state, player: me)
        XCTAssertFalse(ledger.mayForetell, "Its own prophecy is open")
        XCTAssertTrue(ledger.prophecies.first?.said.hasPrefix("You foretold that ") == true)
        let again = try XCTUnwrap(CompanionLedger.foretelling(.takesAHold, first: other, second: nil, in: state, player: me))
        XCTAssertNil(again.foretell)
        XCTAssertEqual(again.why, RuleError.prophecyOpen.description)
    }

    /// A letter to the age to come from the phone, as the Mac's hold record
    /// offers it: every hold of the House offers one while none is sealed;
    /// words sealed at one, taken by the rules; sealed, that hold keeps it
    /// and says so, and no hold offers another.
    func testThePhoneSealsALetterToTheAgeToCome() throws {
        var (state, me) = try world()
        var ledger = CompanionLedger(world: state, player: me)
        let seat = try XCTUnwrap(ledger.holds.first(where: \.isSeat))
        XCTAssertTrue(seat.maySealLetter)
        XCTAssertNil(seat.letterKept)
        XCTAssertNil(CompanionLedger.sealing("   ", in: seat.id, world: state, player: me), "Nothing to seal")
        let seal = try XCTUnwrap(CompanionLedger.sealing("We were here before the water.", in: seat.id, world: state, player: me))
        XCTAssertEqual(seal.title, "Seal the letter, for \(GameState.letterCost)")
        assertTaken([seal], in: state, as: me)
        _ = try state.perform(seal.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        let sealed = try XCTUnwrap(ledger.holds.first(where: \.isSeat))
        XCTAssertEqual(sealed.letterKept, "Your letter to the age to come lies under these stones: \u{201C}We were here before the water.\u{201D}")
        XCTAssertFalse(sealed.maySealLetter)
        XCTAssertTrue(ledger.holds.allSatisfy { !$0.maySealLetter }, "One an age")
        XCTAssertNil(CompanionLedger.sealing("Again.", in: seat.id, world: state, player: me))
    }

    /// Another keeper's words reported from the phone to the realm's
    /// steward, as the Mac's Words report them: offered for another's line,
    /// never the House's own, taken by the rules; reported, marked so and
    /// offered no more.
    func testThePhoneReportsAnotherKeepersWords() throws {
        var (state, me) = try world()
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        state.houses[other].isPlayer = true
        _ = try state.perform(.say(words: "Hear me, all of you.", toAlliance: false), as: other)
        _ = try state.perform(.say(words: "And hear me.", toAlliance: false), as: me)
        var ledger = CompanionLedger(world: state, player: me)
        let theirs = try XCTUnwrap(ledger.realmWords.first { !$0.isOwn })
        let mine = try XCTUnwrap(ledger.realmWords.first { $0.isOwn })
        XCTAssertNil(mine.report, "Not the House's own")
        let report = try XCTUnwrap(theirs.report)
        XCTAssertEqual(report.title, "Report to the realm's steward")
        XCTAssertFalse(theirs.reported)
        assertTaken([report], in: state, as: me)
        _ = try state.perform(report.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        let reported = try XCTUnwrap(ledger.realmWords.first { $0.id == theirs.id })
        XCTAssertTrue(reported.reported)
        XCTAssertNil(reported.report, "Reported once")
    }

    /// A bottle on the water from the phone, as the Mac's hold record
    /// offers it: a hold on the shore offers one, one inland none; words
    /// cast, signed or not, taken by the rules; cast, none more this watch.
    func testThePhoneCastsABottleFromAShoreHold() throws {
        var (state, me) = try world()
        let inland = try XCTUnwrap(state.seat(of: me))
        XCTAssertEqual(CompanionLedger(world: state, player: me).holds.first { $0.id == inland.id }?.mayCastBottle,
                       state.castingWater(beside: inland) != nil, "Offered on the shore alone")
        // A hold of the House's own on the shore, beside the still water.
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.hold(at: hex) == nil
                && state.map.neighbors(of: hex).contains { state.map[$0].map { $0.terrain == .still || $0.terrain == .shallows } ?? false }
        })
        let hold = Hold(id: state.takeID(), name: "Saltwatch", owner: me, position: shore, isSeat: false, foundedWatch: 1)
        state.holds.append(hold)
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.holds.first { $0.id == hold.id }?.mayCastBottle, true)
        XCTAssertNil(CompanionLedger.casting("", from: hold.id, signed: true, world: state, player: me), "Nothing to seal in it")
        let unsigned = try XCTUnwrap(CompanionLedger.casting("Whoever finds this: the reeds are kind.", from: hold.id, signed: false,
                                                               world: state, player: me))
        XCTAssertEqual(unsigned.title, "Cast the bottle, for \(GameState.bottleCost)")
        XCTAssertEqual(unsigned.command, .castBottle(words: "Whoever finds this: the reeds are kind.", from: hold.id, signed: false))
        assertTaken([unsigned], in: state, as: me)
        _ = try state.perform(unsigned.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertFalse(ledger.holds.contains { $0.mayCastBottle }, "One a watch")
    }

    /// A vigil for the fallen from the phone, as the Mac offers it: none
    /// while the House has lost no company; one on the shore once it has,
    /// taken by the rules; kept, it burns on the realm page for every
    /// keeper, honoured by another where the rules would take it, never by
    /// its own House, and honoured but once.
    func testThePhoneKeepsAndHonoursVigilsForTheFallen() throws {
        var (state, me) = try world()
        let other = (me + 1) % 4
        state.houses[other].isPlayer = true
        let shore = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isSettleable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
                && state.map.neighbors(of: hex).contains { state.map[$0].map { $0.terrain == .still || $0.terrain == .shallows } ?? false }
        })
        let hold = Hold(id: state.takeID(), name: "Mournwater", owner: me, position: shore, isSeat: false, foundedWatch: 1)
        state.holds.append(hold)
        XCTAssertFalse(CompanionLedger(world: state, player: me).holds.contains { $0.mayKeepVigil }, "None fallen, none offered")
        XCTAssertTrue(CompanionLedger(world: state, player: me).vigils.isEmpty)
        // A company of war of the House's struck down.
        let at = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain.isPassable == true && state.unit(at: $0) == nil && state.hold(at: $0) == nil })
        let fallen = Unit(id: state.takeID(), kind: .spear, owner: me, position: at)
        state.units.append(fallen)
        var events: [GameEvent] = []
        XCTAssertTrue(state.applyDamage(1_000, to: fallen.id, events: &events))
        XCTAssertEqual(CompanionLedger(world: state, player: me).holds.first { $0.id == hold.id }?.mayKeepVigil, true)
        XCTAssertNil(CompanionLedger.keepingVigil("", from: hold.id, world: state, player: me), "Nothing said")
        let keep = try XCTUnwrap(CompanionLedger.keepingVigil("For the spears at the ford", from: hold.id, world: state, player: me))
        XCTAssertEqual(keep.title, "Set the light, for \(GameState.vigilCost)")
        XCTAssertEqual(keep.command, .keepVigil(words: "For the spears at the ford", hold: hold.id))
        assertTaken([keep], in: state, as: me)
        _ = try state.perform(keep.command, as: me)
        XCTAssertFalse(CompanionLedger(world: state, player: me).holds.contains { $0.mayKeepVigil }, "Its fallen mourned")

        let vigil = try XCTUnwrap(state.vigilsOnTheLake.last)
        let own = try XCTUnwrap(CompanionLedger(world: state, player: me).vigils.first)
        XCTAssertEqual(own.title, "Your House's vigil")
        XCTAssertEqual(own.line, "For 1 company fallen: “For the spears at the ford” Lit in watch \(vigil.lit), honoured by none yet; "
                           + "it burns until watch \(vigil.until).")
        XCTAssertNil(own.honour, "A House keeps its own vigil")
        let theirs = try XCTUnwrap(CompanionLedger(world: state, player: other).vigils.first)
        XCTAssertEqual(theirs.title, "\(state.houses[me].title)'s vigil")
        let honour = try XCTUnwrap(theirs.honour)
        XCTAssertEqual(honour.command, .honourVigil(vigil.id))
        XCTAssertEqual(theirs.honourSaid, "Honour it, and your House may not strike \(state.houses[me].title), nor rally on its holds, "
                           + "until watch \(vigil.until); the honour adds to its keeper's renown as the age ends.")
        assertTaken([honour], in: state, as: other)
        _ = try state.perform(honour.command, as: other)
        let honoured = try XCTUnwrap(CompanionLedger(world: state, player: other).vigils.first)
        XCTAssertNil(honoured.honour, "Honoured but once")
        XCTAssertTrue(honoured.line.contains("honoured by your House"))
        XCTAssertTrue(try XCTUnwrap(CompanionLedger(world: state, player: me).vigils.first).line.contains("honoured by \(state.houses[other].title)"))
    }

    /// The titles of the Spire on the phone, as the Mac's Realm panel tells
    /// them: no broken Spire found, none told; held by the House, it names
    /// them, each House among those offered named where the rules take it;
    /// named, the title borne told to the House named and to the giver.
    func testThePhoneNamesTheSpiresTitles() throws {
        var (state, me) = try world()
        XCTAssertFalse(CompanionLedger(world: state, player: me).titles.shown)
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain.isPassable == true && state.map[hex]?.terrain.isWater == false && state.hold(at: hex) == nil
        })
        state.shrines = (state.shrines ?? []) + [Shrine(id: 99, kind: .brokenSpire, position: ground, holder: me, since: state.watch)]
        var ledger = CompanionLedger(world: state, player: me)
        // The broken Spire is a holy site the House holds, told as the Mac tells it.
        let spire = try XCTUnwrap(state.holySites.first { $0.kind == .brokenSpire })
        let site = try XCTUnwrap(ledger.holySites.first { $0.id == spire.id })
        XCTAssertEqual(site.held, "Yours")
        XCTAssertTrue(site.isFriendly)
        XCTAssertEqual(site.said, "\(spire.kind.effect); \(state.placeName(of: spire.position))")
        XCTAssertTrue(ledger.titles.shown)
        XCTAssertTrue(ledger.titles.mayName)
        XCTAssertEqual(ledger.titles.giver, "Your House holds the broken Spire: you name the realm's titles.")
        XCTAssertTrue(ledger.hasRealmMatters)
        let others = state.houses.indices.filter { $0 != me }
        let title = try XCTUnwrap(Title.allCases.first)
        let naming = CompanionLedger.naming(title, among: others, in: state, player: me)
        XCTAssertEqual(naming.map(\.title), others.map { "Name \(state.houses[$0].title) \(title.title)" })
        assertTaken(naming, in: state, as: me)
        _ = try state.perform(try XCTUnwrap(naming.first).command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.titles.borne.map(\.title), [title.title])
        XCTAssertEqual(ledger.titles.borne.first?.house, state.houses[others[0]].title)
        XCTAssertEqual(ledger.titles.borne.first?.isBoon, title.isBoon)
        XCTAssertEqual(CompanionLedger.naming(title, among: [others[0]], in: state, player: me), [], "Borne already")
        let named = CompanionLedger(world: state, player: others[0]).titles
        XCTAssertEqual(named.borne.first?.house, "Your House")
        XCTAssertFalse(named.mayName)
        XCTAssertEqual(CompanionLedger(world: state, player: others[0]).holySites.first { $0.id == spire.id }?.held,
                       "Held by \(state.houses[me].title)")
    }

    /// Whispers on the water from the phone, as the Mac's Realm panel makes
    /// and tells them: nothing until a House is chosen; granaries low, one
    /// whisper for its moonsalt, taken by the rules; a host, one at each
    /// hold of that House; let loose, heard as the House's own and
    /// unproven, and another refused with the rules' reason.
    func testThePhoneWhispersAndHearsWhispers() throws {
        var (state, me) = try world()
        XCTAssertTrue(CompanionLedger(world: state, player: me).whispers.isEmpty)
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        XCTAssertNil(CompanionLedger.whispering(.granaries, house: nil, in: state, player: me))
        let granaries = try XCTUnwrap(CompanionLedger.whispering(.granaries, house: other, in: state, player: me))
        XCTAssertEqual(granaries.whispers.map(\.title),
                       ["Whisper that \(state.told(.granariesLow(house: other))), for \(GameState.whisperCost)"])
        XCTAssertNil(granaries.why)
        assertTaken(granaries.whispers, in: state, as: me)
        let host = try XCTUnwrap(CompanionLedger.whispering(.host, house: other, in: state, player: me))
        XCTAssertEqual(host.whispers.count, state.holds.filter { $0.owner == other }.count, "One at each hold of that House")
        assertTaken(host.whispers, in: state, as: me)
        _ = try state.perform(try XCTUnwrap(granaries.whispers.first).command, as: me)
        let ledger = CompanionLedger(world: state, player: me)
        let heard = try XCTUnwrap(ledger.whispers.first)
        let whisper = try XCTUnwrap(state.whispersHeard.last)
        XCTAssertEqual(heard.said, "Watch \(whisper.spoken): \(state.told(whisper.claim)).")
        XCTAssertTrue(heard.standing.hasPrefix("Yours. Unproven"), heard.standing)
        XCTAssertFalse(heard.unmasked)
        XCTAssertTrue(ledger.hasRealmMatters)
        let again = try XCTUnwrap(CompanionLedger.whispering(.walls, house: other, in: state, player: me))
        XCTAssertTrue(again.whispers.isEmpty, "Rested since its last")
        XCTAssertNotNil(again.why)
    }

    /// Trade from the phone, as the Mac's trade popover offers it, in one
    /// wording for both: terms that can't be offered say why; good terms to
    /// a steward's House, how they weigh and that its steward answers at
    /// once, the offer taken by the rules; to a keeper's, answered by envoy,
    /// and another while the first waits refused in the rules' words; no
    /// trade offered across a war.
    /// The trade the phone's CI check offers (CompanionCheck): at an age's
    /// start, with a House's first stores, the phone's opening terms to the
    /// nearest House at peace a steward keeps are an offer the rules take,
    /// and the steward answers it at once.
    func testTheTradeThePhonesCheckOffersIsTakenAndAnsweredAtOnce() throws {
        var state = GameState(settings: GameSettings(seedText: "the phone's check", houseCount: 12, radius: 36, keepers: 1))
        let me = state.player
        let ledger = CompanionLedger(world: state, player: me)
        let dealing = try XCTUnwrap(ledger.dealings.first { dealing in
            dealing.mayTrade && state.houses.indices.contains(dealing.id) && !state.houses[dealing.id].isPlayer
        }, "A steward's House at peace among the nearest")
        let trading = CompanionLedger.trading(Trade.opening(from: state.houses[me].stock), with: dealing.id, in: state, player: me)
        let offer = try XCTUnwrap(trading.offer, trading.said)
        XCTAssertNil(state.refusal(of: offer.command, as: me))
        let events = try state.perform(offer.command, as: me)
        XCTAssertTrue(events.contains { event in
            if case .tradeAnswered(_, me, dealing.id, _) = event { return true }
            return false
        }, "Answered at once: \(events)")
    }

    func testThePhoneOffersATrade() throws {
        var (state, me) = try world()
        state.houses[me].stock = Stock(grain: 300, timber: 40, stone: 40, moonsalt: 20)
        let near = try XCTUnwrap(CompanionLedger(world: state, player: me).dealings.first)
        XCTAssertTrue(near.mayTrade)
        XCTAssertEqual(Trade.opening(from: state.houses[me].stock), Trade(give: .grain, 10, for: .timber, 10),
                       "Ten of the store the House's own is worth most in, for timber")
        XCTAssertEqual([Trade.step(of: .grain), Trade.step(of: .moonsalt)], [5, 1], "Moonsalt, worth three, chosen one at a time")
        XCTAssertEqual(CompanionLedger.trading(Trade(give: .grain, 10, for: .grain, 10), with: near.id, in: state, player: me),
                       CompanionLedger.Trading(said: "Choose two different stores.", offer: nil))
        XCTAssertEqual(CompanionLedger.trading(Trade(give: .moonsalt, 30, for: .grain, 10), with: near.id, in: state, player: me).said,
                       "You have only 20 moonsalt.")
        let fair = Trade(give: .grain, 60, for: .timber, 50)
        let steward = CompanionLedger.trading(fair, with: near.id, in: state, player: me)
        XCTAssertEqual(steward.said, fair.offerSaid(stock: state.houses[me].stock, keeper: false))
        XCTAssertTrue(steward.said.hasSuffix("Their steward answers at once; the cunning ask more, allies less."), steward.said)
        let offer = try XCTUnwrap(steward.offer)
        XCTAssertEqual(offer.title, "Offer 60 grain for 50 timber to \(state.houses[near.id].title)")
        assertTaken([offer], in: state, as: me)

        // A keeper's House answers by envoy, and one offer waits at a time.
        state.houses[near.id].isPlayer = true
        let keeper = CompanionLedger.trading(fair, with: near.id, in: state, player: me)
        XCTAssertTrue(keeper.said.hasSuffix("Their keeper answers by envoy."), keeper.said)
        XCTAssertEqual(CompanionLedger(world: state, player: me).dealings.first { $0.id == near.id }?.waiting, [], "None on the road yet")
        _ = try state.perform(try XCTUnwrap(keeper.offer).command, as: me)
        XCTAssertEqual(CompanionLedger.trading(fair, with: near.id, in: state, player: me),
                       CompanionLedger.Trading(said: RuleError.envoyWaiting.description, offer: nil))
        XCTAssertEqual(CompanionLedger(world: state, player: me).dealings.first { $0.id == near.id }?.waiting,
                       ["Your envoy with a trade of 60 grain for 50 timber waits on their answer."], "Said on its row while it waits")

        // No trade crosses a war.
        let foe = try XCTUnwrap(CompanionLedger(world: state, player: me).dealings.dropFirst().first).id
        _ = try state.declareWar(by: me, on: foe)
        XCTAssertEqual(CompanionLedger(world: state, player: me).dealings.first { $0.id == foe }?.mayTrade, false)
        XCTAssertEqual(CompanionLedger.trading(fair, with: foe, in: state, player: me).said, RuleError.noTradeAcrossWar(foe).description)
    }

    /// The Sundering and the Frontier on the phone's realm page, as the
    /// Mac's Realm panel tells them, in the rules' words: when the Sundering
    /// comes, how the shores and the House stand while it is fought, and
    /// how it ended; the Frontier's season with the House's levy and how
    /// its kingdoms stand, and nothing while the realm borders none.
    func testThePhoneTellsTheSunderingAndTheFrontier() throws {
        var (state, me) = try world()
        XCTAssertEqual(CompanionLedger(world: state, player: me).sundering,
                       "The Sundering comes at the \(briefOrdinal(Sundering.next(from: state.watch))) watch: the shores war as kingdoms.")
        state.watch = Sundering.first
        _ = state.turnSundering()
        let shore = try XCTUnwrap(state.sundering?.shore(of: me))
        state.sundering!.points[me] = 12
        let east = state.sundering!.score(of: .eastern), west = state.sundering!.score(of: .western)
        let ends = state.sundering!.ends
        XCTAssertEqual(CompanionLedger(world: state, player: me).sundering,
                       "The Sundering: you stand with \(shore.title), your House 12 points; the Eastern Shore \(east), "
                        + "the Western \(west), until the \(briefOrdinal(ends)) watch.")
        XCTAssertEqual(CompanionLedger(world: state, player: me).realmWaiting.first,
                       "The shores war as kingdoms until the \(briefOrdinal(ends)) watch", "Said on the way to the realm while fought")
        state.watch = ends
        _ = state.turnSundering()
        let settled = CompanionLedger(world: state, player: me).sundering
        XCTAssertTrue(settled.hasPrefix("The last Sundering: \(shore.title) prevailed, 12 to 0; the next at the "), settled)
        XCTAssertFalse(CompanionLedger(world: state, player: me).realmWaiting.contains { $0.hasPrefix("The shores war") }, "Ended, not said")

        let ledger = CompanionLedger(world: state, player: me)
        XCTAssertNil(ledger.frontier(nil), "No Frontier, nothing of it")
        XCTAssertEqual(ledger.levy, state.units(of: me).filter(\.kind.isMilitary).count)
        let open = FrontierNews(address: "https://frontier.example/nullmere", season: 2, watch: 14, lasts: 40, open: true,
                                standings: [KingdomStanding(realm: "The Nullmere", points: 40, keepers: 3),
                                            KingdomStanding(realm: "Thornmere", points: 12, keepers: 1)],
                                last: FrontierResult(season: 1, standings: [], prevailed: "Thornmere", honours: []))
        let frontier = try XCTUnwrap(ledger.frontier(open))
        XCTAssertEqual(frontier.said, open.said(atFrontier: false, levy: ledger.levy))
        XCTAssertTrue(frontier.said.hasPrefix("The Frontier's second season is open, until the 40th watch: cross there"), frontier.said)
        XCTAssertTrue(frontier.said.hasSuffix(" Its last: Thornmere prevailed."), frontier.said)
        XCTAssertEqual(frontier.standings, "The Nullmere 40 (3 keepers) · Thornmere 12 (1 keeper)")
        let ending = FrontierNews(address: "", season: 3, watch: 39, lasts: 40, open: false, standings: [], last: nil)
        XCTAssertEqual(ending.said(atFrontier: false, levy: 4), "The Frontier's third season is ending; the next opens as it does.")
        XCTAssertTrue(open.said(atFrontier: true, levy: 4).hasPrefix("The Frontier's second season, until the 40th watch: you stand here"))
        XCTAssertEqual(briefOrdinal(11), "eleventh")
        XCTAssertEqual(briefOrdinal(13), "13th")
    }

    /// The Remembering on the phone, as the Mac's Realm panel sets it: no
    /// riddle, nothing; set, how it stands, its line and each name to
    /// answer, taken by the rules and counted on the House tab; answered
    /// rightly, told so, none to answer; answered wrongly, the name it was.
    func testThePhoneAnswersTheRemembering() throws {
        var (state, me) = try world()
        XCTAssertNil(CompanionLedger(world: state, player: me).remembering)
        let before = CompanionLedger(world: state, player: me).houseWaiting
        let names = state.houses.map(\.title)
        state.riddles = [Riddle(house: me, set: state.watch, line: "——— raises its first hold by the reeds.",
                                choices: names, answer: names[1])]
        var ledger = CompanionLedger(world: state, player: me)
        let riddle = try XCTUnwrap(ledger.remembering)
        XCTAssertEqual(riddle.standing, "Set at watch \(state.watch): answer it rightly before the next half moon for \(GameState.riddleReward).")
        XCTAssertEqual(riddle.line, "——— raises its first hold by the reeds.")
        XCTAssertEqual(riddle.answers.map(\.title), names)
        assertTaken(riddle.answers, in: state, as: me)
        XCTAssertEqual(ledger.houseWaiting, before + 1, "An unanswered riddle waits on the House tab")
        var wrong = state
        _ = try wrong.perform(.answerRiddle(names[0]), as: me)
        XCTAssertEqual(CompanionLedger(world: wrong, player: me).remembering?.standing, "You said \(names[0]); it was \(names[1]).")
        _ = try state.perform(try XCTUnwrap(riddle.answers.first { $0.title == names[1] }).command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.remembering?.standing, "Rightly remembered: it was \(names[1]).")
        XCTAssertEqual(ledger.remembering?.answers, [])
        XCTAssertEqual(ledger.houseWaiting, before)
    }

    /// A commander's stars on the phone, in the words of the Mac's
    /// Commanders: one of five and what the next asks, nothing offered
    /// without the sculptures; with them, Raise a star, taken by the rules
    /// and counted on the Army tab's badge; raised, told anew; at five,
    /// all of them, and none offered.
    func testThePhoneRaisesACommandersStarsWithSculptures() throws {
        var (state, me) = try world()
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        var line = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == commander.id })
        XCTAssertEqual(line.stars, "1 of \(Commander.mostStars) stars · Next star: 10 sculptures, 0 kept")
        XCTAssertNil(line.raiseStar, "No sculptures kept")
        let before = CompanionLedger(world: state, player: me).armyWaiting
        _ = state.giveSculptures(25, to: me)
        let ledger = CompanionLedger(world: state, player: me)
        line = try XCTUnwrap(ledger.commanders.first { $0.id == commander.id })
        XCTAssertEqual(line.stars, "1 of \(Commander.mostStars) stars · Next star: 10 sculptures, 25 kept")
        let raise = try XCTUnwrap(line.raiseStar)
        XCTAssertEqual(raise.title, "Raise \(commander.name) to 2 stars")
        assertTaken([raise], in: state, as: me)
        if line.talents.isEmpty { XCTAssertEqual(ledger.armyWaiting, before + 1, "A star to raise waits on the Army tab") }
        _ = try state.perform(raise.command, as: me)
        line = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == commander.id })
        XCTAssertEqual(line.stars, "2 of \(Commander.mostStars) stars · Next star: 20 sculptures, 15 kept")
        XCTAssertNil(line.raiseStar, "Not sculptures enough for the next")
        // At five stars, all of them, none offered.
        let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == commander.id })
        state.commanders?[index].stars = Commander.mostStars
        _ = state.giveSculptures(500, to: me)
        line = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == commander.id })
        XCTAssertEqual(line.stars, "\(Commander.mostStars) of \(Commander.mostStars) stars · All \(Commander.mostStars) stars")
        XCTAssertNil(line.raiseStar)
    }

    /// The armoury and what each commander wears on the phone, in the words
    /// of the Mac's Commanders: nothing kept, told how gear comes; a piece
    /// kept, offered to every free commander and to break up, each taken by
    /// the rules; worn, on its commander's line with Take off, taken by the
    /// rules; taken off, kept again; broken up, gone for its moonsalt; and
    /// a commander held by another House arms with nothing.
    func testThePhoneArmsCommandersFromTheArmoury() throws {
        var (state, me) = try world()
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.armoury.heading, "Armoury · 0 of \(GameState.armouryLimit)")
        XCTAssertEqual(ledger.armoury.none, GameState.noGearSaid)
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        XCTAssertEqual(ledger.commanders.first { $0.id == commander.id }?.worn, [])
        _ = state.awardGear(from: .saltwights, level: 3, to: me)
        _ = state.awardGear(from: .reavers, level: 5, to: me)
        let pieces = state.gear(of: me)
        XCTAssertEqual(pieces.count, 2)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.armoury.heading, "Armoury · 2 of \(GameState.armouryLimit)")
        XCTAssertNil(ledger.armoury.none)
        XCTAssertEqual(ledger.armoury.kept.map(\.title), pieces.map(\.keptSaid))
        XCTAssertEqual(ledger.armoury.kept.map(\.effect), pieces.map(\.effect))
        let first = try XCTUnwrap(ledger.armoury.kept.first)
        XCTAssertEqual(first.arm.map(\.title), ["Arm \(commander.name)"])
        XCTAssertEqual(first.breakUp?.title, "Break up the \(pieces[0].title) for \(pieces[0].scrap) moonsalt")
        assertTaken(ledger.armoury.kept.flatMap { $0.arm + [$0.breakUp].compactMap { $0 } }, in: state, as: me)

        // Worn: on the commander's line, out of the armoury, still counted.
        _ = try state.perform(try XCTUnwrap(first.arm.first).command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        let line = try XCTUnwrap(ledger.commanders.first { $0.id == commander.id })
        XCTAssertEqual(line.worn.map(\.title), [pieces[0].wornSaid])
        XCTAssertEqual(line.worn.first?.effect, pieces[0].effect)
        let takeOff = try XCTUnwrap(line.worn.first?.takeOff)
        XCTAssertEqual(takeOff.title, "Take the \(pieces[0].title) off \(commander.name)")
        assertTaken([takeOff], in: state, as: me)
        XCTAssertEqual(ledger.armoury.kept.map(\.id), [pieces[1].id])
        XCTAssertEqual(ledger.armoury.heading, "Armoury · 2 of \(GameState.armouryLimit)")

        // Taken off: kept again; broken up: gone, for its moonsalt.
        _ = try state.perform(takeOff.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.commanders.first { $0.id == commander.id }?.worn, [])
        XCTAssertEqual(ledger.armoury.kept.count, 2)
        state.houses[me].stock.moonsalt = 0 // well within the House's room
        _ = try state.perform(try XCTUnwrap(ledger.armoury.kept.first?.breakUp).command, as: me)
        XCTAssertEqual(state.houses[me].stock.moonsalt, pieces[0].scrap)
        XCTAssertEqual(CompanionLedger(world: state, player: me).armoury.kept.map(\.id), [pieces[1].id])

        // Held by another House: no commander to arm.
        let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == commander.id })
        let captive = Captivity(by: (me + 1) % state.houses.count, since: state.watch, questioned: 0)
        state.commanders?[index].captive = captive
        XCTAssertEqual(CompanionLedger(world: state, player: me).armoury.kept.first?.arm, [])
    }

    /// Oaths on the phone, in the words of the Mac's Houses: one the House
    /// swore told and offered to renounce, taken by the rules; renounced,
    /// told until when it binds and offered no more; one sworn to the House
    /// told as its swearer swore it.
    func testThePhoneTellsAndRenouncesOaths() throws {
        var (state, me) = try world()
        XCTAssertTrue(CompanionLedger(world: state, player: me).oathsSworn.isEmpty)
        let other = try XCTUnwrap(state.houses.first { $0.id != me }?.id)
        state.houses[other].isPlayer = true
        _ = try state.perform(.swear(.peace, to: other, watches: 10), as: me)
        var ledger = CompanionLedger(world: state, player: me)
        let sworn = try XCTUnwrap(ledger.oathsSworn.first)
        let oath = try XCTUnwrap(state.oaths(by: me).first)
        let quell = state.houses[other].title
        XCTAssertEqual(sworn.terms, "Your oath to \(quell): peace until watch \(state.lastWatch(of: oath))")
        let renounce = try XCTUnwrap(sworn.renounce)
        XCTAssertEqual(renounce.title, "Renounce the oath of peace to \(quell)")
        assertTaken([renounce], in: state, as: me)
        _ = try state.perform(renounce.command, as: me)
        ledger = CompanionLedger(world: state, player: me)
        let renounced = try XCTUnwrap(ledger.oathsSworn.first)
        XCTAssertNil(renounced.renounce, "Renounced once")
        XCTAssertEqual(renounced.terms, "Your oath to \(quell): peace until watch \(state.watch + GameState.oathNotice), renounced")
        // Sworn to the House: told as its swearer swore it, not the House's
        // to renounce.
        _ = try state.perform(.swear(.send(.grain, 30), to: me, watches: 8), as: other)
        let theirs = try XCTUnwrap(CompanionLedger(world: state, player: me).oathsToUs.first)
        XCTAssertEqual(theirs.terms, "\(quell)'s oath to you: 30 grain each watch until watch \(state.watch + 8)")
        XCTAssertNil(theirs.renounce, "Not the House's to renounce")
    }

    /// The caretaker's standing orders on the phone: told as they stand,
    /// every order offered one the rules take; given, told so and offered no
    /// more, the other way offered; cleared, the House kept as it sees fit.
    func testThePhoneSetsTheCaretakersStandingOrders() throws {
        var (state, me) = try world()
        var ledger = CompanionLedger(world: state, player: me)
        XCTAssertEqual(ledger.standing.said, StandingOrders(house: me).said, "None given: as it sees fit")
        assertTaken(ledger.standing.musters + ledger.standing.raises + ledger.standing.others, in: state, as: me)
        XCTAssertFalse(ledger.standing.musters.isEmpty)
        XCTAssertFalse(ledger.standing.raises.isEmpty)
        XCTAssertFalse(ledger.standing.others.contains { $0.command == .standDown }, "Nothing to clear")
        let spears = try XCTUnwrap(ledger.standing.musters.first { $0.command == .stand(.muster(.spear)) })
        _ = try state.perform(spears.command, as: me)
        let peace = try XCTUnwrap(ledger.standing.others.first { $0.command == .stand(.peace(true)) })
        _ = try state.perform(peace.command, as: me)

        ledger = CompanionLedger(world: state, player: me)
        XCTAssertTrue(ledger.standing.said.contains("musters only Spears"), ledger.standing.said)
        XCTAssertTrue(ledger.standing.said.contains("makes peace with any House"), ledger.standing.said)
        XCTAssertFalse(ledger.standing.musters.contains { $0.command == .stand(.muster(.spear)) }, "Offered no more")
        XCTAssertFalse(ledger.standing.others.contains { $0.command == .stand(.peace(true)) })
        XCTAssertTrue(ledger.standing.others.contains { $0.command == .stand(.peace(false)) }, "The other way offered")
        assertTaken(ledger.standing.musters + ledger.standing.raises + ledger.standing.others, in: state, as: me)
        let clear = try XCTUnwrap(ledger.standing.others.first { $0.command == .standDown })
        _ = try state.perform(clear.command, as: me)
        XCTAssertEqual(CompanionLedger(world: state, player: me).standing.said, StandingOrders(house: me).said, "Cleared")
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
        let waiting = CompanionLedger(world: state, player: me).armyWaiting
        let index = try XCTUnwrap(state.commanders?.firstIndex { $0.id == second.id })
        state.commanders?[index].experience = 100_000
        let learned = try XCTUnwrap(CompanionLedger(world: state, player: me).commanders.first { $0.id == second.id })
        XCTAssertFalse(learned.talents.isEmpty)
        XCTAssertEqual(CompanionLedger(world: state, player: me).armyWaiting, waiting + 1,
                       "The Army tab's badge: a commander with a talent to learn")
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
        XCTAssertEqual(CompanionLedger(world: state, player: me).allianceWaiting, 1, "The Alliance tab's badge: an ally to help")
        XCTAssertEqual(help.command, .help(house: ally))
        XCTAssertEqual(help.title, "Help \(state.houses[ally].title), \(state.helpable(by: me, for: ally)) under way")
        assertTaken([help], in: state, as: me)
        var helped = state
        _ = try helped.perform(help.command, as: me)
        XCTAssertTrue(CompanionLedger(world: helped, player: me).helps.isEmpty, "Helped, nothing left to help")
        XCTAssertEqual(CompanionLedger(world: helped, player: me).allianceWaiting, 0)

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
        XCTAssertEqual(company.doing, "Sent to the rally against \(foeSeat.name)", "As the Mac's panel says it")
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
        XCTAssertTrue(ledger.satchel.allSatisfy { $0.count.first.map { !$0.isLowercase } ?? false }, "One begins \"A ...\": \(ledger.satchel.map(\.count))")
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
        XCTAssertEqual(ledger.allianceWaiting, 1, "The Alliance tab's badge: an invitation to answer")
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
        XCTAssertEqual(ledger.houseWaiting, 2, "The House tab's badge: two envoys to answer")
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
        // Nothing yet between them to remember; once the keeper has turned
        // the trader's envoy away, its next is told so, in the Mac's words.
        XCTAssertNil(trade.remembered)
        var answered = state
        _ = try answered.perform(.answer(envoy: trade.id, accept: false), as: me)
        let next = Envoy(id: answered.takeID(), from: trader, to: me, proposal: .pact, arrived: answered.watch)
        answered.envoys.append(next)
        let remembered = try XCTUnwrap(CompanionLedger(world: answered, player: me).envoys.first { $0.id == next.id }?.remembered)
        XCTAssertEqual(remembered, answered.remembered(next, for: me))
        XCTAssertEqual(remembered, "\(state.houses[trader].title)'s last envoy, in watch \(answered.watch), came offering a trade, and you turned it away.")

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
        // Foes near: the walls told, and the veil with them, though the
        // House is short of the moonsalt for it.
        state.houses[me].stock.moonsalt = 0
        let walls = CompanionLedger(world: state, player: me)
        XCTAssertNotNil(walls.veilShort)
        XCTAssertTrue(walls.wallsTold)
        XCTAssertEqual(CompanionLedger(world: state, player: me).houseWaiting, 3, "And the companies gathered near the seat")
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
        // Named as the Mac's map names it: "Strike Barrowkin, level II", "Strike the Drowned, level I".
        let strike = try XCTUnwrap(company.strikes.first { $0.title == "Strike \(wild.kind.title), level \(BuildingKind.numeral(wild.level))" },
                                   "\(company.strikes.map(\.title))")
        XCTAssertFalse(company.strikes.contains { $0.title.contains("the the") })
        XCTAssertEqual(strike.command, .attack(unit: spear.id, target: wild.position))
        assertTaken(company.strikes, in: state, as: me)
        // Gathering: at most the nearest few sites, each one the rules would send it to.
        XCTAssertLessThanOrEqual(company.gathers.count, CompanionLedger.sitesOffered)
        assertTaken(company.gathers, in: state, as: me)
        for gather in company.gathers {
            XCTAssertTrue(gather.title.hasPrefix("Gather "))
            // The site by its name, which way and how far: never "at on the blackwood by" a hold.
            guard case .gather(_, let siteID, _) = gather.command, let site = state.site(siteID) else { return XCTFail(gather.title) }
            XCTAssertEqual(gather.title, "Gather \(site.store.title.lowercased()) at \(state.siteSaid(site)), "
                           + GameState.waySaid(to: site.position, from: spear.position))
            XCTAssertFalse([" at on ", " at in ", " at at "].contains { gather.title.contains($0) }, gather.title)
        }
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
        if let walking = marching.unit(spear.id), walking.destination != nil {
            // As the Mac's panel says it, which way and how far, for the phone
            // has no map beside its list: run 753's phone said "Lanterns I on
            // the blackwood by Wenholme, Marching to the blackwood by Wenholme".
            let distance = walking.position.distance(to: seat.position)
            XCTAssertTrue(moving.doing.hasPrefix("Marching to \(seat.name), \(distance) tile\(distance == 1 ? "" : "s") "
                                                 + GameState.direction(of: seat.position, from: walking.position)),
                          "To a hold by its name, never \"to at\" it: \(moving.doing)")
            XCTAssertEqual(moving.doing, marching.marchSaid(of: walking, for: me))
            XCTAssertTrue(moving.orders.contains { $0.title == "Halt" })
        }
        // Out at the land's work, as the Mac's gatherers say it: which site,
        // and when it will be there or full, where the phone said "Gathering".
        if let gather = company.gathers.first {
            var gathering = state
            _ = try gathering.perform(gather.command, as: me)
            let out = try XCTUnwrap(CompanionLedger(world: gathering, player: me).companies.first { $0.id == spear.id })
            let said = try XCTUnwrap(gathering.gatheringSaid(of: try XCTUnwrap(gathering.unit(spear.id))))
            XCTAssertEqual(out.doing, said.prefix(1).uppercased() + said.dropFirst())
            XCTAssertTrue(out.doing.hasPrefix("Bound for the ") || out.doing.hasPrefix("At the "), out.doing)
        }
        // To open ground by what it is, never "to on" nor "to in" it (run 658's phone said "Marching to on the barrows").
        var ground = state
        let at = try XCTUnwrap(ground.unitIndex(spear.id))
        let open = try XCTUnwrap(seat.position.neighbors.first { hex in
            ground.hold(at: hex) == nil && (ground.map.index(of: hex).map { ground.houses[me].explored[$0] } ?? false)
        }, "Ground the House has seen beside its seat")
        ground.units[at].destination = open
        let from = ground.units[at].position, distance = from.distance(to: open)
        let onward = try XCTUnwrap(CompanionLedger(world: ground, player: me).companies.first { $0.id == spear.id })
        XCTAssertEqual(onward.doing, "Marching to \(try XCTUnwrap(ground.map[open]).terrain.ground), "
                       + "\(distance) tile\(distance == 1 ? "" : "s") \(GameState.direction(of: open, from: from))")
    }
}
