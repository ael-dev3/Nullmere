import Foundation
import XCTest
@testable import NullmereCore

/// Fire in the blackwood: a keeper's company of war sets it alight; it
/// burns three watches, catching the blackwood beside it with the watch's
/// wind, takes its toll of the companies standing in it, and lies as ash
/// that yields nothing until the wood grows back; a Still Night keeps it
/// where it is and Rising Mist puts it out; it takes nothing but the
/// blackwood, and every House sees it.
final class WildfireTests: XCTestCase {
    /// A keeper's spears standing in the blackwood nearest its seat, on its
    /// own House's land or land no hold's, with blackwood all about.
    private func kindling(_ seed: String = "fire in the blackwood") throws -> (GameState, me: Int, unit: Int, at: Hex) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me)).position
        let sites = Set(state.sitesInLand.map(\.position))
        let owners = state.territory()
        func woods(_ hex: Hex) -> Int { hex.neighbors.filter { state.map[$0]?.terrain == .blackwood }.count }
        let at = try XCTUnwrap(state.map.hexes.filter { hex in
            state.map[hex]?.terrain == .blackwood && state.hold(at: hex) == nil && !sites.contains(hex) && state.unit(at: hex) == nil
                && (state.territoryOwner(of: hex, in: owners) ?? me) == me && woods(hex) >= 4
        }.min { ($0.distance(to: seat), $0.q, $0.r) < ($1.distance(to: seat), $1.q, $1.r) })
        let unit = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: me, near: at))
        let index = try XCTUnwrap(state.unitIndex(unit.id))
        state.units[index].position = at
        state.units[index].movesLeft = state.movement(of: state.units[index])
        state.omen = nil
        return (state, me, unit.id, at)
    }

    func testAKeepersCompanySetsTheBlackwoodAlight() throws {
        var (state, me, unit, at) = try kindling()
        let moves = try XCTUnwrap(state.unit(unit)).movesLeft
        XCTAssertNil(state.kindleRefusal(unit, as: me))
        let events = try state.perform(.kindle(unit: unit), as: me)
        XCTAssertEqual(events, [.woodKindled(at: at, by: me, unit: unit)])
        let fire = try XCTUnwrap(state.wildfire(at: at))
        XCTAssertEqual(fire, Wildfire(at: at, by: me, caught: state.watch, out: state.watch + Wildfire.burns))
        XCTAssertTrue(state.isBurning(at))
        XCTAssertEqual(state.burning, [fire])
        XCTAssertEqual(try XCTUnwrap(state.unit(unit)).movesLeft, moves - 1, "It spends a move on it, and may walk on")
        XCTAssertTrue(try XCTUnwrap(state.unit(unit)).acted)
        XCTAssertEqual(state.problems(), [])
        // Its keeper is told the wind; every other House sees the smoke.
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)?.text)
        XCTAssertTrue(told.hasPrefix("Your company sets the blackwood alight \(state.placeName(of: at)); "), told)
        XCTAssertTrue(told.contains(state.windSaid), told)
        for other in state.houses.indices where other != me {
            XCTAssertEqual(state.events(events, heardBy: other), events)
            let seen = try XCTUnwrap(state.tidings(of: events[0], for: other)?.text)
            XCTAssertTrue(seen.hasPrefix("\(state.houses[me].title) sets the blackwood alight \(state.placeName(of: at))"), seen)
            XCTAssertTrue(seen.hasSuffix("smoke rises over the lake."), seen)
            XCTAssertEqual(state.view(for: other).wildfires, [fire], "Every House sees the fire")
        }
        // Not twice on one ground.
        XCTAssertEqual(state.kindleRefusal(unit, as: me), .burntGround)
    }

    func testOnlyAKeepersCompanyOfWarInTheBlackwoodOnItsOwnOrAFoesLandMaySetIt() throws {
        let (state, me, unit, at) = try kindling()
        // Another House's order.
        let steward = try XCTUnwrap(state.houses.indices.first { $0 != me })
        XCTAssertEqual(state.kindleRefusal(unit, as: steward), .notYours)
        // A steward's own company.
        var stewards = state
        let theirs = try XCTUnwrap(stewards.placeUnit(.spear, tier: 1, for: steward, near: at))
        stewards.units[try XCTUnwrap(stewards.unitIndex(theirs.id))].position = at
        XCTAssertEqual(stewards.kindleRefusal(theirs.id, as: steward), .keepersFire)
        // Lanterns light no fires.
        var lanterns = state
        let lantern = try XCTUnwrap(lanterns.placeUnit(.lantern, tier: 1, for: me, near: at))
        lanterns.units[try XCTUnwrap(lanterns.unitIndex(lantern.id))].position = at
        XCTAssertEqual(lanterns.kindleRefusal(lantern.id, as: me), .cannotFight)
        // Only the blackwood burns.
        var elsewhere = state
        let open = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain == .greyfield && state.hold(at: $0) == nil })
        elsewhere.units[try XCTUnwrap(elsewhere.unitIndex(unit))].position = open
        XCTAssertEqual(elsewhere.kindleRefusal(unit, as: me), .onlyBlackwood)
        XCTAssertThrowsError(try elsewhere.perform(.kindle(unit: unit), as: me)) { XCTAssertEqual($0 as? RuleError, .onlyBlackwood) }
        // With no move left, none.
        var spent = state
        spent.units[try XCTUnwrap(spent.unitIndex(unit))].movesLeft = 0
        XCTAssertEqual(spent.kindleRefusal(unit, as: me), .noMovesLeft)
        // On the land of a House at peace with its own, none; at war, it may.
        let owners = state.territory()
        let foreign = try XCTUnwrap(state.map.hexes.filter { hex in
            guard state.map[hex]?.terrain == .blackwood, state.hold(at: hex) == nil, let owner = state.territoryOwner(of: hex, in: owners) else { return false }
            return owner != me
        }.min { ($0.distance(to: at), $0.q, $0.r) < ($1.distance(to: at), $1.q, $1.r) })
        let owner = try XCTUnwrap(state.territoryOwner(of: foreign))
        var abroad = state
        abroad.units[try XCTUnwrap(abroad.unitIndex(unit))].position = foreign
        XCTAssertFalse(abroad.isAtWar(me, owner))
        XCTAssertEqual(abroad.kindleRefusal(unit, as: me), .notAtWar(owner))
        _ = try abroad.perform(.declareWar(on: owner), as: me)
        XCTAssertNil(abroad.kindleRefusal(unit, as: me))
    }

    func testTheFireCatchesTheWoodMostOfAllDownwind() throws {
        let (base, me, _, at) = try kindling()
        let sites = Set(base.sitesInLand.map(\.position))
        var tried = [0, 0, 0, 0], caught = [0, 0, 0, 0]
        for trial in 0..<400 {
            var state = base
            state.watch = 40 + trial
            state.keepTheWind()
            state.units.removeAll { $0.position == at }
            state.wildfires = [Wildfire(at: at, by: me, caught: state.watch - 1, out: state.watch + 2)]
            let wind = try XCTUnwrap(state.wind)
            let events = state.turnWildfires()
            var spread: [Hex] = []
            for event in events { if case .fireSpread(let hexes, let by, let blew) = event { XCTAssertEqual(by, me); XCTAssertEqual(blew, wind); spread += hexes } }
            for (way, step) in Hex.directions.enumerated() {
                let next = at + step
                guard base.map[next]?.terrain == .blackwood, base.hold(at: next) == nil, !sites.contains(next) else {
                    XCTAssertFalse(spread.contains(next), "Fire takes nothing but the blackwood")
                    continue
                }
                let off = min((way - wind + 6) % 6, (wind - way + 6) % 6)
                tried[off] += 1
                if spread.contains(next) {
                    caught[off] += 1
                    XCTAssertEqual(state.wildfire(at: next), Wildfire(at: next, by: me, caught: state.watch, out: state.watch + Wildfire.burns))
                }
            }
            XCTAssertEqual(state.problems(), [])
        }
        func share(_ off: Int) -> Double { tried[off] == 0 ? 0 : Double(caught[off]) / Double(tried[off]) }
        XCTAssertGreaterThan(tried[0], 30)
        XCTAssertGreaterThan(tried[3], 30)
        XCTAssertEqual(share(0), 0.30, accuracy: 0.12, "Downwind: \(caught[0]) of \(tried[0])")
        XCTAssertEqual(share(1), 0.12, accuracy: 0.07, "Beside the wind: \(caught[1]) of \(tried[1])")
        XCTAssertLessThan(share(2), 0.08, "Across the wind: \(caught[2]) of \(tried[2])")
        XCTAssertEqual(caught[3], 0, "Never upwind")
        XCTAssertGreaterThan(share(0), share(1))
        XCTAssertGreaterThan(share(1), share(2))
    }

    func testACompanyStandingInFirePaysItsTollAndTheFireBurnsOutToAsh() throws {
        var (state, me, unit, at) = try kindling()
        _ = try state.perform(.kindle(unit: unit), as: me)
        let before = try XCTUnwrap(state.unit(unit))
        let kindled = state.watch
        let events = state.endWatch()
        let after = try XCTUnwrap(state.unit(unit))
        XCTAssertEqual(after.position, at, "Its keeper left it standing in the fire")
        XCTAssertEqual(after.health, before.health - Wildfire.toll)
        let lost = state.troops(of: before) - state.troops(of: after)
        XCTAssertGreaterThan(lost, 0)
        XCTAssertTrue(events.contains(.burnedInFire(unit: unit, owner: me, at: at, troops: lost, lost: false)))
        XCTAssertEqual(state.tidings(of: .burnedInFire(unit: unit, owner: me, at: at, troops: lost, lost: false), for: me)?.text,
                       "The fire takes \(GameState.counted(lost)) troops of your company \(state.placeName(of: at)).")
        // Whatever it caught as the watch turned, it caught with the watch's wind, beside it.
        for event in events { if case .fireSpread(let hexes, _, let wind) = event {
            XCTAssertEqual(wind, state.wind)
            XCTAssertTrue(hexes.allSatisfy { $0.distance(to: at) == 1 && state.map[$0]?.terrain == .blackwood })
        } }
        // Three watches it burns; then ash, which yields nothing and burns no one.
        state.units.removeAll { $0.id == unit }
        while state.watch < kindled + Wildfire.burns { state.endWatch() }
        let fire = try XCTUnwrap(state.wildfire(at: at))
        XCTAssertFalse(fire.isBurning(at: state.watch))
        XCTAssertEqual(fire.regrows, kindled + Wildfire.burns + Wildfire.ash)
        XCTAssertEqual(state.problems(), [])
    }

    func testAStillNightKeepsTheFireWhereItIsAndRisingMistPutsItOut() throws {
        var (state, me, unit, at) = try kindling()
        _ = try state.perform(.kindle(unit: unit), as: me)
        state.units.removeAll { $0.id == unit }
        state.watch += 1
        state.omen = Omen(kind: .stillNight, began: state.watch, ends: state.watch + 3)
        state.keepTheWind()
        XCTAssertNil(state.wind)
        XCTAssertEqual(state.windSaid, "no wind blows")
        XCTAssertEqual(state.turnWildfires(), [], "No wind, no spreading")
        XCTAssertEqual(state.wildfires?.count, 1)
        XCTAssertTrue(state.isBurning(at))
        // The mist puts it out, and the ash lies on.
        let spears = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: me, near: at))
        state.units[try XCTUnwrap(state.unitIndex(spears.id))].position = at
        let health = try XCTUnwrap(state.unit(spears.id)).health
        state.watch += 1
        state.omen = Omen(kind: .risingMist, began: state.watch, ends: state.watch + 3)
        state.keepTheWind()
        let doused = state.turnWildfires()
        XCTAssertEqual(doused, [.firesDoused([at], rain: false)])
        XCTAssertEqual(state.tidings(of: doused[0], for: me)?.text, "The mist lies on the blackwood and puts out its fires.")
        XCTAssertFalse(state.isBurning(at))
        XCTAssertNotNil(state.wildfire(at: at), "Its ash lies on")
        XCTAssertEqual(try XCTUnwrap(state.unit(spears.id)).health, health, "Out, it burns no one")
    }

    /// A lean watch comes with cold rain over the lake, as the world draws
    /// it, and the rain puts out every fire burning in the blackwood as the
    /// watch turns, the wood it burnt lying as ash.
    func testALeanWatchsColdRainPutsTheFireOut() throws {
        var (state, me, unit, at) = try kindling()
        _ = try state.perform(.kindle(unit: unit), as: me)
        state.units.removeAll { $0.id == unit }
        state.watch += 1
        state.omen = Omen(kind: .leanWatch, began: state.watch, ends: state.watch + 3)
        state.keepTheWind()
        let doused = state.turnWildfires()
        XCTAssertEqual(doused, [.firesDoused([at], rain: true)], "Out, and spread nowhere")
        XCTAssertEqual(state.tidings(of: doused[0], for: me)?.text, "The cold rain falls on the blackwood and puts out its fires.")
        XCTAssertEqual(state.tidings(of: doused[0], for: (me + 1) % state.houses.count)?.text,
                       "The cold rain falls on the blackwood and puts out its fires.", "Every House sees the smoke go")
        XCTAssertFalse(state.isBurning(at))
        XCTAssertEqual(state.ash, [at], "Its ash lies on")
        XCTAssertEqual(state.burning, [])
        XCTAssertEqual(state.problems(), [])
    }

    func testAshYieldsNothingUntilTheWoodGrowsBack() throws {
        var state = GameState(settings: GameSettings(seedText: "ash on the land", houseCount: 4, radius: 18, keepers: 1))
        let owners = state.territory()
        let (hold, hex) = try XCTUnwrap(state.holds.lazy.compactMap { hold -> (Hold, Hex)? in
            let wood = hold.position.spiral(hold.territoryRadius).first { hex in
                guard let index = state.map.index(of: hex) else { return false }
                return owners[index] == hold.id && state.map[index].terrain == .blackwood && state.map[index].yield.timber > 0
            }
            return wood.map { (hold, $0) }
        }.first)
        let before = state.income(of: hold)
        state.wildfires = [Wildfire(at: hex, by: hold.owner, caught: state.watch - 4, out: state.watch - 1)]
        let burnt = state.income(of: hold)
        XCTAssertLessThan(burnt.timber, before.timber, "Its ash yields nothing")
        // The wood grows back as its time comes.
        state.watch = state.wildfires![0].regrows
        XCTAssertEqual(state.turnWildfires(), [])
        XCTAssertNil(state.wildfires)
        XCTAssertEqual(state.income(of: hold), before)
    }

    func testAStewardsCompanyStandingInFireStepsOutOfIt() throws {
        var (state, me, unit, at) = try kindling()
        _ = try state.perform(.kindle(unit: unit), as: me)
        let steward = try XCTUnwrap(state.houses.indices.first { $0 != me && !state.houses[$0].isPlayer })
        let theirs = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: steward, near: at))
        let index = try XCTUnwrap(state.unitIndex(theirs.id))
        state.units[index].position = at
        state.units[index].movesLeft = state.movement(of: state.units[index])
        state.units[index].destination = nil
        _ = state.stewardTurn(for: steward)
        let after = try XCTUnwrap(state.unit(theirs.id))
        XCTAssertNotEqual(after.position, at, "It steps out of the fire")
        XCTAssertFalse(state.isBurning(after.position))
    }

    func testTheFireIsToldToThoseItTouches() throws {
        let (state, me, unit, at) = try kindling()
        let other = try XCTUnwrap(state.houses.indices.first { $0 != me })
        let wind = 3
        // Its spreading: to the House whose fire it is, and to the House whose land it burns.
        let spread = GameEvent.fireSpread(to: [at], by: me, wind: wind)
        XCTAssertEqual(state.tidings(of: spread, for: me)?.text,
                       "Your House's fire takes a tile more of the blackwood \(state.placeName(of: at)), on the wind from the east.")
        let theirs = GameEvent.fireSpread(to: [at, at + Hex.directions[0]], by: other, wind: wind)
        let burning = try XCTUnwrap(state.tidings(of: theirs, for: me))
        XCTAssertTrue(burning.text.hasPrefix("\(state.houses[other].title)'s fire takes 2 tiles more of the blackwood"), burning.text)
        if state.territoryOwner(of: at) == me {
            XCTAssertTrue(burning.text.hasSuffix(", burning your House's land."), burning.text)
            XCTAssertEqual(burning.tone, .bad)
        }
        XCTAssertEqual(state.events([spread], heardBy: me), [spread])
        let index = try XCTUnwrap(state.map.index(of: at))
        let blind = try XCTUnwrap(state.houses.indices.first { $0 != me && !state.visibility(for: $0)[index] })
        XCTAssertEqual(state.events([spread], heardBy: blind), [], "Unseen, the spreading is no news")
        // A company lost to it whole.
        let lost = GameEvent.burnedInFire(unit: unit, owner: me, at: at, troops: 300, lost: true)
        XCTAssertEqual(state.tidings(of: lost, for: me)?.text, "Your company is lost to the fire \(state.placeName(of: at)).")
        XCTAssertEqual(state.tidings(of: lost, for: other)?.text,
                       "A company of \(state.houses[me].title)'s is lost to the fire \(state.placeName(of: at)).")
        let toll = GameEvent.burnedInFire(unit: unit, owner: me, at: at, troops: 1_200, lost: false)
        XCTAssertEqual(state.tidings(of: toll, for: other)?.text,
                       "The fire takes 1,200 troops of \(state.houses[me].title)'s company \(state.placeName(of: at)).")
        XCTAssertEqual(state.events([toll], heardBy: blind), [], "Unseen, no news either")
        XCTAssertNil(state.tidings(of: .firesDoused([], rain: false), for: me))
        // Every keeper is told the realm's wind, though a view holds no seed to find it by.
        var turning = state
        for _ in 0..<6 {
            XCTAssertEqual(turning.view(for: other).wind, turning.wind)
            XCTAssertEqual(turning.view(for: me).windSaid, turning.windSaid)
            turning.endWatch()
        }
        XCTAssertEqual(GameState.windFrom(0), "from the west")
        XCTAssertEqual(GameState.windFrom(4), "from the north-east")
    }

    func testCounselKnowsTheFireOnItsHousesLand() throws {
        var (state, me, unit, at) = try kindling()
        let commander = try XCTUnwrap(state.commanders(of: me).first)
        func affairs() throws -> String {
            try XCTUnwrap(CommanderCounsel(state: state.view(for: me), player: me, commander: commander.id)).affairs
        }
        XCTAssertFalse(try affairs().contains("blackwood"), "No fire, no word of one")
        guard state.territoryOwner(of: at) == me else { return }
        _ = try state.perform(.kindle(unit: unit), as: me)
        let burning = try affairs()
        XCTAssertTrue(burning.contains("Fire burns in the blackwood on 1 tile of its land; \(state.windSaid)."), burning)
        state.wildfires = [Wildfire(at: at, by: me, caught: state.watch - 4, out: state.watch - 1)]
        let ash = try affairs()
        XCTAssertTrue(ash.hasSuffix("Ash lies on 1 tile of its land, yielding nothing."), ash)
    }

    func testAWorldOfStewardsAloneBurnsNothing() {
        var state = GameState(settings: GameSettings(seedText: "no fire unbidden", houseCount: 4, radius: 14, keepers: 0))
        for _ in 0..<20 { state.endWatch() }
        XCTAssertNil(state.wildfires)
    }
}
