import Foundation
import XCTest
@testable import NullmereCore

/// Sites of the land, one store each, finite: a company of war sent to one
/// marches there, gathers each watch at its rate until it carries all it
/// can, then brings it home to the nearest hold. Gatherers can be struck
/// by Houses at war with theirs, and leave half their load to the victor.
final class GatheringTests: XCTestCase {
    /// A keeper's spear on open ground, and a site of grain beside it.
    private func field(_ seed: String = "gathering", level: Int = 1) throws -> (GameState, me: Int, spear: Int, site: Int, at: Hex) {
        var state = Scene.world(seed)
        let me = state.player
        // Of a people that gathers at no other pace.
        state.houses[me].heritage = .fenfolk
        state.sites = []
        state.wilds = []
        let ground = try XCTUnwrap(state.openGround())
        let spear = state.put(.spear, of: me, at: ground)
        let there = ground + Hex.directions[0]
        let site = Site(id: state.takeID(), store: .grain, level: level, position: there, found: state.watch)
        state.sites = [site]
        state.reveal(around: there, range: 1, for: me)
        return (state, me, spear, site.id, there)
    }

    private func refusal(_ command: Command, in state: GameState, as house: Int) -> RuleError? {
        var trial = state
        do {
            try trial.perform(command, as: house)
            return nil
        } catch {
            return error
        }
    }

    func testSitesComeUpInTheLand() throws {
        var state = Scene.world("sites", houses: 4, radius: 18)
        XCTAssertTrue(state.sitesInLand.isEmpty)
        _ = state.endWatch()
        XCTAssertEqual(state.sitesInLand.count, 3, "Three a watch")
        for _ in 0..<20 { state.raiseSites() }
        XCTAssertEqual(state.sitesInLand.count, state.houses.count * 3, "Up to three for each seat")
        for site in state.sitesInLand {
            let tile = try XCTUnwrap(state.map[site.position])
            XCTAssertEqual(Site.store(of: tile.terrain), site.store, "Each the store of its ground")
            XCTAssertEqual(site.remaining, Site.richness(of: site.store, level: site.level))
            XCTAssertGreaterThanOrEqual(state.holds.map { $0.position.distance(to: site.position) }.min() ?? 0, GameState.sitesFromHolds)
            XCTAssertNil(state.wild(at: site.position))
        }
        XCTAssertEqual(state.problems(), [])
        XCTAssertEqual(Resource.allCases.map(Site.title), ["Fallow Field", "Deadfall", "Scree", "Salt Pan"])
        XCTAssertNil(Site.store(of: .still))
        XCTAssertEqual(Site(id: 1, store: .moonsalt, level: 9, position: .origin, found: 1).level, Site.highestLevel)
        XCTAssertLessThan(Site.richness(of: .moonsalt, level: 3), Site.richness(of: .stone, level: 3), "Moonsalt lies thin")
    }

    func testACompanyGathersAndBringsItHome() throws {
        var (state, me, spear, site, there) = try field()
        let events = try state.perform(.gather(unit: spear, site: site), as: me)
        XCTAssertEqual(events.first, .sentToGather(unit: spear, site: site))
        XCTAssertEqual(state.unit(spear)?.position, there, "It marches there")
        XCTAssertEqual(state.unit(spear)?.errand, .gather(site: site))
        let unit = try XCTUnwrap(state.unit(spear))
        let rate = state.gatheringRate(of: unit, for: .grain)
        let capacity = state.capacity(of: unit, for: .grain)
        XCTAssertEqual(rate, 30)
        XCTAssertEqual(capacity, 150)
        var gathered: [GameEvent] = []
        for watch in 1...(capacity / rate) {
            gathered += state.endWatch().filter { if case .gathered = $0 { return true } else { return false } }
            XCTAssertEqual(state.unit(spear)?.load?.grain, min(rate * watch, capacity))
        }
        XCTAssertEqual(state.site(site)?.remaining, Site.richness(of: .grain, level: 1) - capacity)
        XCTAssertEqual(gathered, [.gathered(unit: spear, owner: me, load: Stock(grain: capacity))])
        XCTAssertEqual(state.unit(spear)?.errand, .homeward, "Full, it turns for home")
        let home = try XCTUnwrap(state.holds(of: me).min { $0.position.distance(to: there) < $1.position.distance(to: there) })
        XCTAssertEqual(state.unit(spear)?.destination, home.position)
        var delivered: [GameEvent] = []
        var stock = state.houses[me].stock
        for _ in 0..<20 where delivered.isEmpty {
            stock = state.houses[me].stock
            delivered += state.endWatch().filter { if case .delivered = $0 { return true } else { return false } }
        }
        XCTAssertEqual(delivered, [.delivered(unit: spear, owner: me, hold: home.id, load: Stock(grain: capacity))])
        XCTAssertNil(state.unit(spear)?.load)
        XCTAssertNil(state.unit(spear)?.errand, "Its errand done")
        XCTAssertGreaterThanOrEqual(state.houses[me].stock.grain, min(stock.grain + capacity - state.upkeep(of: me), state.storage(of: me)) - 1)
        XCTAssertEqual(state.problems(), [])
    }

    /// A gatherer full with no hold of its House's left to bring it to is
    /// done with its errand where it stands, load and all.
    func testAGathererWithNoHoldToGoHomeToStandsWithItsLoad() throws {
        var (state, me, spear, site, there) = try field("no home")
        _ = try state.perform(.gather(unit: spear, site: site), as: me)
        XCTAssertEqual(state.unit(spear)?.position, there)
        let unit = try XCTUnwrap(state.unit(spear))
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].load = Stock(grain: state.capacity(of: unit, for: .grain) - 1)
        state.holds.removeAll { $0.owner == me }
        let events = state.workTheLand()
        XCTAssertTrue(events.contains { if case .gathered(spear, me, _) = $0 { return true } else { return false } })
        XCTAssertNil(state.unit(spear)?.errand)
        XCTAssertNil(state.unit(spear)?.destination)
        XCTAssertEqual(state.unit(spear)?.load?.grain, state.capacity(of: unit, for: .grain))
    }

    func testAGatheringOrderIsRefusedAsTheGameSaysIt() throws {
        var (state, me, spear, site, there) = try field("refused gathering")
        let lantern = state.put(.lantern, of: me, at: try XCTUnwrap(state.freeHex(near: there, within: 2...3)))
        XCTAssertEqual(refusal(.gather(unit: lantern, site: site), in: state, as: me), .cannotGather(.lantern))
        XCTAssertEqual(refusal(.gather(unit: spear, site: 987_654), in: state, as: me), .unknownSite)
        XCTAssertEqual(refusal(.gather(unit: 987_654, site: site), in: state, as: me), .unknownUnit)
        let theirs = try XCTUnwrap(state.units(of: 1).first { $0.kind.isMilitary })
        XCTAssertEqual(refusal(.gather(unit: theirs.id, site: site), in: state, as: me), .notYours)
        // A site the House has never seen is no site of its.
        let unexplored = try XCTUnwrap(state.map.hexes.first { hex in
            !state.isExplored(hex, by: me) && state.map[hex]?.terrain == .blackwood && state.isClear(hex)
        })
        let hidden = Site(id: state.takeID(), store: .timber, level: 2, position: unexplored, found: 1)
        state.sites!.append(hidden)
        XCTAssertEqual(refusal(.gather(unit: spear, site: hidden.id), in: state, as: me), .unknownSite)
        // Full, or carrying another store.
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].load = Stock(grain: 150)
        XCTAssertEqual(refusal(.gather(unit: spear, site: site), in: state, as: me), .loadFull)
        state.units[index].load = Stock(stone: 10)
        XCTAssertEqual(refusal(.gather(unit: spear, site: site), in: state, as: me), .loadFull)
        state.units[index].load = Stock(grain: 10)
        XCTAssertNil(refusal(.gather(unit: spear, site: site), in: state, as: me), "More of the same, with room")
    }

    func testRateAndLoadGrowWithTierCommanderAndStudies() throws {
        var (state, me, spear, _, _) = try field("better gatherers")
        let plain = try XCTUnwrap(state.unit(spear))
        let tiered = Unit(id: 1, kind: .spear, owner: me, position: plain.position, tier: 5)
        XCTAssertGreaterThan(state.gatheringRate(of: tiered, for: .grain), state.gatheringRate(of: plain, for: .grain))
        XCTAssertGreaterThan(state.capacity(of: tiered, for: .grain), state.capacity(of: plain, for: .grain))
        XCTAssertEqual(state.gatheringRate(of: plain, for: .moonsalt), state.gatheringRate(of: plain, for: .grain) / 4)
        let rider = Unit(id: 2, kind: .rider, owner: me, position: plain.position)
        XCTAssertGreaterThan(state.capacity(of: rider, for: .stone), state.capacity(of: plain, for: .stone))
        XCTAssertEqual(state.gatheringRate(of: Unit(id: 3, kind: .lantern, owner: me, position: plain.position), for: .grain), 0)
        XCTAssertEqual(state.capacity(of: Unit(id: 3, kind: .founder, owner: me, position: plain.position), for: .grain), 0)
        var studied = state
        studied.houses[me].research.learn(.gleaning, grade: 3)
        studied.houses[me].research.learn(.ladenCarts, grade: 2)
        XCTAssertEqual(studied.gatheringRate(of: plain, for: .grain), 30 * 130 / 100)
        XCTAssertEqual(studied.capacity(of: plain, for: .grain), 150 * 130 / 100)
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        state.commanders![commander - 1] = Commander(id: commander, name: "Gleaner", archetype: .gleaner, owner: me)
        state.commanders![commander - 1].experience = Commander.experience(forLevel: 10)
        state.units[try XCTUnwrap(state.unitIndex(spear))].leader = commander
        let led = try XCTUnwrap(state.unit(spear))
        XCTAssertEqual(state.gatheringRate(of: led, for: .grain), 30 * 115 / 100)
        XCTAssertEqual(state.capacity(of: led, for: .grain), 150 * 120 / 100)
    }

    /// A site worked out is gone; its gatherer comes home with what it has;
    /// and the land brings another up.
    func testASiteWorkedOutIsGone() throws {
        var (state, me, spear, site, _) = try field("worked out")
        state.sites![0].remaining = 40
        _ = try state.perform(.gather(unit: spear, site: site), as: me)
        var events = state.endWatch()
        XCTAssertEqual(state.unit(spear)?.load?.grain, 30)
        events += state.endWatch()
        XCTAssertEqual(state.unit(spear)?.load?.grain, 40, "All that was left")
        XCTAssertNil(state.site(site))
        XCTAssertTrue(events.contains { if case .siteWorkedOut(site, .grain, _) = $0 { return true } else { return false } })
        XCTAssertEqual(state.unit(spear)?.errand, .homeward)
        XCTAssertFalse(state.sitesInLand.isEmpty, "Others come up")
        // A company bound for a site gone home with nothing is simply done.
        var empty = try field("bound for nothing").0
        let walker = try XCTUnwrap(empty.units(of: empty.player).last)
        empty.units[try XCTUnwrap(empty.unitIndex(walker.id))].errand = .gather(site: 424_242)
        _ = empty.endWatch()
        XCTAssertNil(empty.unit(walker.id)?.errand)
    }

    /// Any other order ends an errand, but what is carried stays carried,
    /// and is given up whenever the company comes by one of its holds.
    func testAnotherOrderEndsTheErrandButNotTheLoad() throws {
        var (state, me, spear, site, _) = try field("called off")
        _ = try state.perform(.gather(unit: spear, site: site), as: me)
        _ = state.endWatch()
        XCTAssertEqual(state.unit(spear)?.load?.grain, 30)
        _ = try state.perform(.halt(unit: spear), as: me)
        XCTAssertNil(state.unit(spear)?.errand)
        XCTAssertEqual(state.unit(spear)?.load?.grain, 30)
        for command in [Command.fortify(unit: spear)] {
            var trial = state
            trial.units[try XCTUnwrap(trial.unitIndex(spear))].errand = .homeward
            _ = try trial.perform(command, as: me)
            XCTAssertNil(trial.unit(spear)?.errand)
        }
        let seat = try XCTUnwrap(state.seat(of: me))
        let gate = try XCTUnwrap(state.freeHex(near: seat.position))
        state.units[try XCTUnwrap(state.unitIndex(spear))].position = gate
        let before = state.houses[me].stock.grain
        let events = state.endWatch()
        XCTAssertTrue(events.contains(.delivered(unit: spear, owner: me, hold: seat.id, load: Stock(grain: 30))))
        XCTAssertGreaterThan(state.houses[me].stock.grain, before)
    }

    /// Called home, a gatherer turns for the nearest hold with all it
    /// carries and gives it up there; carrying nothing, it is done where it
    /// stands. Only a company out at the land's work can be called.
    func testAGathererIsCalledHomeWithWhatItCarries() throws {
        var (state, me, spear, site, there) = try field("called home")
        XCTAssertEqual(refusal(.recall(unit: spear), in: state, as: me), .notGathering, "Not yet sent")
        _ = try state.perform(.gather(unit: spear, site: site), as: me)
        XCTAssertTrue(state.isOutGathering(try XCTUnwrap(state.unit(spear))))
        _ = state.endWatch()
        let carried = try XCTUnwrap(state.unit(spear)?.load)
        XCTAssertEqual(carried.grain, 30)
        let home = try XCTUnwrap(state.holds(of: me).min { ($0.position.distance(to: there), $0.id) < ($1.position.distance(to: there), $1.id) })

        let events = try state.perform(.recall(unit: spear), as: me)
        XCTAssertTrue(events.contains(.recalled(unit: spear, owner: me)), "\(events)")
        XCTAssertEqual(state.unit(spear)?.errand, .homeward, "Home with what it carries")
        XCTAssertEqual(state.unit(spear)?.destination, home.position)
        XCTAssertEqual(state.unit(spear)?.load, carried, "All of it")
        XCTAssertEqual(state.site(site)?.remaining, Site.richness(of: .grain, level: 1) - 30, "The site keeps what was left")
        XCTAssertEqual(state.tidings(of: .recalled(unit: spear, owner: me), for: me)?.tone, .neutral)
        XCTAssertNil(state.tidings(of: .recalled(unit: spear, owner: me), for: (me + 1) % state.houses.count), "Told to its keeper alone")

        var delivered: [GameEvent] = []
        for _ in 0..<20 where delivered.isEmpty {
            delivered += state.endWatch().filter { if case .delivered = $0 { return true } else { return false } }
        }
        XCTAssertEqual(delivered, [.delivered(unit: spear, owner: me, hold: home.id, load: carried)])
        XCTAssertFalse(state.isOutGathering(try XCTUnwrap(state.unit(spear))), "Home, it is done")
        XCTAssertEqual(refusal(.recall(unit: spear), in: state, as: me), .notGathering)

        // Sent again and called back before it has gathered a thing, it is
        // done where it stands.
        var (fresh, _, idle, freshSite, _) = try field("called back")
        _ = try fresh.perform(.gather(unit: idle, site: freshSite), as: me)
        let stood = try XCTUnwrap(fresh.unit(idle)).position
        let back = try fresh.perform(.recall(unit: idle), as: me)
        XCTAssertEqual(back, [.recalled(unit: idle, owner: me)])
        XCTAssertNil(fresh.unit(idle)?.errand)
        XCTAssertNil(fresh.unit(idle)?.destination)
        XCTAssertEqual(fresh.unit(idle)?.position, stood)
        _ = fresh.endWatch()
        XCTAssertNil(fresh.unit(idle)?.load, "Gathering no more")

        // Not another House's company, nor one there is not.
        let theirs = try XCTUnwrap(state.units(of: 1).first { $0.kind.isMilitary })
        XCTAssertEqual(refusal(.recall(unit: theirs.id), in: state, as: me), .notYours)
        XCTAssertEqual(refusal(.recall(unit: 987_654), in: state, as: me), .unknownUnit)
        XCTAssertEqual(RuleError.notGathering.description, "It isn't gathering, and carries nothing home.")
    }

    /// How long a gatherer at its site still takes: to fill its load, or to
    /// work the site out if that comes first.
    func testAGathererKnowsWhenItWillBeFull() throws {
        var (state, me, spear, site, _) = try field("full when")
        XCTAssertNil(state.watchesToFill(try XCTUnwrap(state.unit(spear))), "Not sent")
        _ = try state.perform(.gather(unit: spear, site: site), as: me)
        XCTAssertEqual(state.watchesToFill(try XCTUnwrap(state.unit(spear))), 5, "150 to carry at 30 a watch")
        _ = state.endWatch()
        XCTAssertEqual(state.watchesToFill(try XCTUnwrap(state.unit(spear))), 4)
        let index = try XCTUnwrap(state.sites?.firstIndex { $0.id == site })
        state.sites![index].remaining = 31
        XCTAssertEqual(state.watchesToFill(try XCTUnwrap(state.unit(spear))), 2, "The site worked out first")
        state.units[try XCTUnwrap(state.unitIndex(spear))].load = Stock(grain: 150)
        XCTAssertEqual(state.watchesToFill(try XCTUnwrap(state.unit(spear))), 1, "Full: home as the watch turns")
        state.units[try XCTUnwrap(state.unitIndex(spear))].position = try XCTUnwrap(state.openGround())
        XCTAssertNil(state.watchesToFill(try XCTUnwrap(state.unit(spear))), "Away from its site")
    }

    /// Every gatherer of a House called home at once, the first mustered
    /// first: one beside its hold gives up its load there and then, one
    /// carrying a load it was left with turns for home, and a company at
    /// other work is let be.
    func testEveryGathererIsCalledHomeAtOnce() throws {
        var (state, me, spear, site, _) = try field("all home")
        XCTAssertEqual(refusal(.recallAll, in: state, as: me), .noneGathering, "None out")
        XCTAssertEqual(RuleError.noneGathering.description, "None of your companies is out gathering.")
        _ = try state.perform(.gather(unit: spear, site: site), as: me)
        _ = state.endWatch()
        let seat = try XCTUnwrap(state.seat(of: me))
        let porter = state.put(.spear, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position)))
        state.units[try XCTUnwrap(state.unitIndex(porter))].load = Stock(timber: 20)
        let idler = state.put(.bow, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position, within: 2...3)))
        let before = state.houses[me].stock.timber

        let events = try state.perform(.recallAll, as: me)
        XCTAssertEqual(events.filter { if case .recalled = $0 { return true } else { return false } },
                       [.recalled(unit: spear, owner: me), .recalled(unit: porter, owner: me)], "The first mustered first")
        XCTAssertTrue(events.contains(.delivered(unit: porter, owner: me, hold: seat.id, load: Stock(timber: 20))), "At its gate, at once")
        XCTAssertGreaterThanOrEqual(state.houses[me].stock.timber, min(before + 20, state.storage(of: me)))
        XCTAssertNil(state.unit(porter)?.load)
        XCTAssertNil(state.unit(porter)?.errand)
        XCTAssertEqual(state.unit(spear)?.errand, .homeward)
        XCTAssertNil(state.unit(idler)?.errand, "Let be")
        XCTAssertEqual(refusal(.recallAll, in: state, as: me), nil, "One still on its way home is still out")
        XCTAssertEqual(state.problems(), [])
    }

    func testAGathererStruckLeavesHalfItsLoadToTheVictor() throws {
        var (state, me, spear, _, there) = try field("struck gatherer")
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].load = Stock(grain: 100)
        state.units[index].health = 1
        let striker = state.put(.rider, tier: 4, of: 1, at: try XCTUnwrap(state.freeHex(near: state.units[index].position, avoiding: [.shallows])))
        _ = there
        _ = try state.perform(.declareWar(on: me), as: 1)
        let before = state.houses[1].stock.grain
        _ = try state.perform(.attack(unit: striker, target: state.units[index].position), as: 1)
        XCTAssertNil(state.unit(spear))
        XCTAssertEqual(state.houses[1].stock.grain, min(before + 50, state.storage(of: 1)))
    }

    func testAHoldFoundedOnASiteSettlesIt() throws {
        var (state, me, _, site, there) = try field("settled site")
        state.holds.removeAll { $0.owner == me && !$0.isSeat }
        let founder = state.put(.founder, of: me, at: there)
        guard state.canFound(at: there, for: me) == nil else { return }
        _ = try state.perform(.found(unit: founder), as: me)
        XCTAssertNil(state.site(site), "Settled ground now")
    }

    /// A keeper sees the sites on ground their House has explored, and
    /// nothing of another House's errands or loads.
    func testAViewShowsSitesAndKeepsOthersErrands() throws {
        var (state, me, _, site, _) = try field("seen sites")
        let unexplored = try XCTUnwrap(state.map.hexes.first { hex in
            !state.isExplored(hex, by: me) && state.map[hex]?.terrain == .barrow && state.isClear(hex)
        })
        state.sites!.append(Site(id: state.takeID(), store: .stone, level: 1, position: unexplored, found: 1))
        let theirs = try XCTUnwrap(state.units.firstIndex { $0.owner == 1 && $0.kind.isMilitary })
        state.units[theirs].errand = .homeward
        state.units[theirs].load = Stock(timber: 40)
        let seat = try XCTUnwrap(state.seat(of: me))
        state.units[theirs].position = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...2))
        let view = state.view(for: me)
        XCTAssertEqual(view.sitesInLand.map(\.id), [site])
        let seen = try XCTUnwrap(view.unit(state.units[theirs].id))
        XCTAssertNil(seen.errand)
        XCTAssertNil(seen.load)
        let mine = GameEvent.delivered(unit: 1, owner: me, hold: seat.id, load: Stock(grain: 3))
        let other = GameEvent.gathered(unit: 2, owner: 1, load: Stock(timber: 3))
        let far = GameEvent.siteWorkedOut(site: 9, store: .stone, at: unexplored)
        XCTAssertEqual(state.events([mine, other, far], heardBy: me), [mine])
    }

    func testWorldsFromBeforeGatheringFindTheirSites() throws {
        var (state, me, spear, site, _) = try field("older sites")
        _ = try state.perform(.gather(unit: spear, site: site), as: me)
        _ = state.endWatch()
        let old = try Scene.without(["sites", "errand", "load"], in: state)
        var loaded = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertNil(loaded.sites)
        XCTAssertTrue(loaded.units.allSatisfy { $0.errand == nil && $0.load == nil })
        _ = loaded.endWatch()
        XCTAssertFalse(loaded.sitesInLand.isEmpty)
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        XCTAssertEqual(try JSONDecoder().decode(Errand.self, from: JSONEncoder().encode(Errand.gather(site: 4))), .gather(site: 4))
    }

    /// A steward at peace, short of a store, sends an idle company to work
    /// a site of it near its land, and brings it home.
    func testStewardsGatherWhatTheyLack() throws {
        var state = Scene.world("stewards gather")
        let steward = 1
        state.sites = []
        state.wilds = []
        let seat = try XCTUnwrap(state.seat(of: steward)).position
        // No scout of its own to wander onto the site first.
        state.units.removeAll { $0.owner == steward }
        state.put(.spear, of: steward, at: seat)
        let stand = try XCTUnwrap(state.freeHex(near: seat, within: 3...3, avoiding: [.shallows]))
        let gatherer = state.put(.spear, of: steward, at: stand)
        let spot = try XCTUnwrap(state.freeHex(near: stand, within: 2...3, avoiding: [.shallows]))
        let site = Site(id: state.takeID(), store: .stone, level: 1, position: spot, found: 1)
        state.sites = [site]
        state.reveal(around: spot, range: 1, for: steward)
        state.houses[steward].stock.stone = 0
        XCTAssertEqual(RivalMind(house: steward).site(for: try XCTUnwrap(state.unit(gatherer)), in: state), site.id)
        var rich = state
        rich.richen(steward)
        XCTAssertNil(RivalMind(house: steward).site(for: try XCTUnwrap(rich.unit(gatherer)), in: rich), "Nothing it lacks")
        _ = state.stewardTurn(for: steward)
        XCTAssertEqual(state.unit(gatherer)?.errand, .gather(site: site.id))
        var delivered = false
        for _ in 0..<16 where !delivered {
            delivered = state.endWatch().contains { if case .delivered(gatherer, steward, _, _) = $0 { return true } else { return false } }
        }
        XCTAssertTrue(delivered, "It works the site and brings the stone home")
    }

    func testUnsoundSitesAndLoadsAreCaught() throws {
        let (state, me, spear, _, _) = try field("unsound sites")
        func caught(_ text: String, _ change: (inout GameState) -> Void) {
            var broken = state
            change(&broken)
            XCTAssertTrue(broken.problems().contains { $0.contains(text) }, "\(text): \(broken.problems())")
        }
        caught("worked out but still there") { $0.sites![0].remaining = 0 }
        caught("numbered twice") { $0.sites!.append($0.sites![0]) }
        caught("before the next id") { $0.nextID = 1 }
        caught("lies under something else") { state in
            let seat = state.seat(of: me)!.position
            state.sites![0] = Site(id: state.sites![0].id, store: .grain, level: 1, position: seat, found: 1)
        }
        caught("lies where none can go") { state in
            let water = state.map.hexes.first { state.map[$0]?.terrain == .still }!
            state.sites![0] = Site(id: state.sites![0].id, store: .grain, level: 1, position: water, found: 1)
        }
        caught("carries") { $0.units[$0.unitIndex(spear)!].load = Stock(grain: -4) }
        caught("carries stores") { state in
            let lantern = state.units.firstIndex { $0.owner == me && $0.kind == .lantern }!
            state.units[lantern].load = Stock(grain: 4)
        }
    }

    func testGatheringIsToldInTheGamesWords() throws {
        var (state, me, spear, site, _) = try field("told gathering")
        XCTAssertEqual(RuleError.unknownSite.description, "Your House knows of no such site.")
        XCTAssertEqual(RuleError.cannotGather(.founder).description, "Founders gather nothing.")
        XCTAssertEqual(RuleError.loadFull.description, "It carries all it can; bring it home first.")
        XCTAssertEqual(state.tidings(of: .sentToGather(unit: spear, site: site), for: me), Tidings("Your Spears set out to work the fallow field.", .neutral))
        XCTAssertEqual(state.tidings(of: .sentToGather(unit: spear, site: 5), for: me)?.text, "Your Spears set out to work the site.")
        XCTAssertNil(state.tidings(of: .sentToGather(unit: spear, site: site), for: 1))
        XCTAssertEqual(state.tidings(of: .gathered(unit: spear, owner: me, load: Stock(grain: 150)), for: me),
                       Tidings("Your Spears turn for home with 150 grain.", .neutral))
        XCTAssertEqual(state.tidings(of: .gathered(unit: 4, owner: me, load: Stock(grain: 1)), for: me)?.text, "Your gatherers turn for home with 1 grain.")
        let seat = try XCTUnwrap(state.seat(of: me))
        XCTAssertEqual(state.tidings(of: .delivered(unit: spear, owner: me, hold: seat.id, load: Stock(stone: 90)), for: me),
                       Tidings("90 stone brought home to \(seat.name).", .good))
        XCTAssertNil(state.tidings(of: .delivered(unit: spear, owner: 1, hold: seat.id, load: Stock(stone: 90)), for: me))
        XCTAssertEqual(state.tidings(of: .siteWorkedOut(site: site, store: .moonsalt, at: .origin), for: me), Tidings("The salt pan is worked out.", .neutral))
        state.sites = nil
        XCTAssertTrue(state.sitesInLand.isEmpty)
    }
}
