import Foundation
import XCTest
@testable import NullmereCore

/// The realm raises the wilds in the far country, levels I to X: they never
/// march and take no hold, any House may strike them without a war, they
/// strike back at a company beside them, and what falls with them is
/// stores for the House and lessons for the company's commander.
final class WildTests: XCTestCase {
    /// A keeper's spear on open ground, a company of the wilds beside it.
    private func hunt(_ kind: WildKind = .reavers, level: Int = 1, seed: String = "the wilds") throws -> (GameState, me: Int, spear: Int, wild: Int, at: Hex) {
        var state = Scene.world(seed)
        let me = state.player
        state.wilds = []
        let ground = try XCTUnwrap(state.openGround())
        let spear = state.put(.spear, of: me, at: ground)
        let there = ground + Hex.directions[0]
        let wild = state.raise(kind, level: level, at: there)
        return (state, me, spear, wild, there)
    }

    func testTheWildsRiseInTheFarCountry() throws {
        var state = Scene.world("far country", houses: 4, radius: 18)
        XCTAssertTrue(state.wildsStanding.isEmpty, "None at the first watch")
        _ = state.endWatch()
        XCTAssertEqual(state.wildsStanding.count, 2, "Two a watch")
        for _ in 0..<20 { state.raiseWilds() }
        XCTAssertEqual(state.wildsStanding.count, state.houses.count * 2, "Up to two for each seat")
        for wild in state.wildsStanding {
            let tile = try XCTUnwrap(state.map[wild.position])
            XCTAssertTrue(tile.terrain.isPassable && !tile.terrain.isWater && tile.feature == nil)
            XCTAssertGreaterThanOrEqual(state.holds.map { $0.position.distance(to: wild.position) }.min() ?? 0, GameState.wildsFromHolds)
            XCTAssertTrue((1...Wild.highestLevel).contains(wild.level))
            XCTAssertEqual(wild.kind, WildKind.of(tile.terrain), "Each rises from its own ground")
        }
        XCTAssertEqual(state.problems(), [])
        var again = Scene.world("far country", houses: 4, radius: 18)
        _ = again.endWatch()
        for _ in 0..<20 { again.raiseWilds() }
        XCTAssertEqual(again.wildsStanding, state.wildsStanding, "The same words, the same wilds")
        XCTAssertEqual(Set(WildKind.allCases.map(\.title)).count, WildKind.allCases.count)
        XCTAssertEqual(Terrain.allCases.map(WildKind.of).count, Terrain.allCases.count)
    }

    func testAnyHouseMayStrikeTheWildsWithoutAWar() throws {
        var (state, me, spear, wild, there) = try hunt()
        XCTAssertTrue(state.relations.allSatisfy { $0.stance != .war })
        let forecast = try XCTUnwrap(state.forecast(unit: spear, at: there))
        XCTAssertEqual(forecast.target, .wild(.reavers, level: 1))
        XCTAssertFalse(forecast.couldCapture)
        XCTAssertGreaterThan(forecast.taken.upperBound, 0, "It strikes back at a company beside it")
        XCTAssertTrue(state.strikeTargets(of: try XCTUnwrap(state.unit(spear))).contains(there))
        let events = try state.perform(.attack(unit: spear, target: there), as: me)
        guard case .hunted(let blow)? = events.first else { return XCTFail("A strike on the wilds: \(events)") }
        XCTAssertEqual(blow.wild, wild)
        XCTAssertEqual(blow.attackerOwner, me)
        XCTAssertTrue(forecast.dealt.contains(blow.damageDealt), "\(blow.damageDealt) in \(forecast.dealt)")
        XCTAssertTrue(forecast.taken.contains(blow.damageTaken))
        XCTAssertEqual(state.wild(wild)?.health, 100 - blow.damageDealt)
        XCTAssertEqual(state.unit(spear)?.movesLeft, 0)
        XCTAssertThrowsError(try state.perform(.attack(unit: spear, target: there), as: me)) { error in
            XCTAssertEqual(error as? RuleError, .noMovesLeft)
        }

        // A bow from two tiles takes nothing back.
        var (archery, keeper, _, _, prey) = try hunt(seed: "archery")
        let stand = try XCTUnwrap(prey.ring(2).first { archery.map[$0]?.terrain.isPassable == true && archery.isClear($0) && archery.wild(at: $0) == nil })
        let bow = archery.put(.bow, of: keeper, at: stand)
        XCTAssertEqual(archery.forecast(unit: bow, at: prey)?.taken, 0...0)
        let shot = try archery.perform(.attack(unit: bow, target: prey), as: keeper)
        guard case .hunted(let arrow)? = shot.first else { return XCTFail("A shot") }
        XCTAssertEqual(arrow.damageTaken, 0)
        let far = try XCTUnwrap(prey.ring(4).first { archery.map[$0]?.terrain.isPassable == true && archery.isClear($0) && archery.wild(at: $0) == nil })
        let distant = archery.put(.spear, of: keeper, at: far)
        XCTAssertThrowsError(try archery.perform(.attack(unit: distant, target: prey), as: keeper)) { error in
            XCTAssertEqual(error as? RuleError, .outOfReach)
        }
        let lantern = archery.put(.lantern, of: keeper, at: try XCTUnwrap(archery.freeHex(near: prey, within: 1...1)))
        XCTAssertThrowsError(try archery.perform(.attack(unit: lantern, target: prey), as: keeper)) { error in
            XCTAssertEqual(error as? RuleError, .cannotFight)
        }
    }

    /// A march onto the wilds within reach strikes them; one from further
    /// off stops beside them, for they hold their ground.
    func testTheWildsHoldTheirGround() throws {
        var (state, me, spear, wild, there) = try hunt(seed: "held ground")
        let events = try state.perform(.move(unit: spear, to: there), as: me)
        XCTAssertTrue(events.contains { if case .hunted = $0 { return true } else { return false } }, "A march onto them in reach strikes")
        XCTAssertNotNil(state.wild(wild))

        var road = try hunt(seed: "on the road").0
        let keeper = road.player
        road.wilds = []
        let ground = try XCTUnwrap(road.openGround())
        let walker = road.put(.spear, of: keeper, at: ground)
        let blocker = ground + Hex.directions[0]
        road.raise(.saltwights, level: 2, at: blocker)
        let beyond = blocker + Hex.directions[0]
        let path = try XCTUnwrap(road.path(for: try XCTUnwrap(road.unit(walker)), to: beyond))
        XCTAssertFalse(path.contains(blocker), "The way goes round them")
        XCTAssertNil(road.reach(of: try XCTUnwrap(road.unit(walker)))[blocker])
        let far = blocker + Hex.directions[0] * 3
        if road.map[far]?.terrain.isPassable == true, road.isClear(far) {
            let lantern = road.put(.lantern, of: keeper, at: far)
            _ = try road.perform(.move(unit: lantern, to: blocker), as: keeper)
            XCTAssertNotEqual(road.unit(lantern)?.position, blocker, "A march to their ground stops beside them")
        }
        // No company musters on their ground.
        let around = road.freeHex(near: blocker)
        XCTAssertNotNil(around)
        let placed = road.placeUnit(.spear, for: keeper, near: blocker)
        XCTAssertNotEqual(placed?.position, blocker)
    }

    func testAFallenCompanyOfTheWildsGivesStoresAndLessons() throws {
        var (state, me, spear, wild, there) = try hunt(.barrowkin, level: 8, seed: "felled")
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        state.units[try XCTUnwrap(state.unitIndex(spear))].leader = commander
        state.wilds![0].health = 1
        let before = state.houses[me].stock
        let events = try state.perform(.attack(unit: spear, target: there), as: me)
        guard case .hunted(let blow)? = events.first else { return XCTFail("A strike") }
        XCTAssertTrue(blow.wildFell)
        XCTAssertNil(state.wild(wild), "Gone from the land")
        let spoils = WildKind.barrowkin.spoils * 8
        XCTAssertEqual(blow.spoils, spoils)
        XCTAssertEqual(state.houses[me].stock, before + spoils)
        XCTAssertEqual(state.commander(commander)?.experience, (15 + 50) * 8, "Its commander learns from the blow and the fall")
        XCTAssertTrue(state.chronicle.contains { $0.kind == .hunt && $0.text.contains("Barrowkin") && $0.text.contains("eighth level") })
        XCTAssertEqual(state.unit(spear)?.experience, 1, "and the company too")

        // A wildsbane's blows fall harder on them.
        var bane = try hunt(.spineHunters, level: 4, seed: "bane").0
        let led = try XCTUnwrap(bane.units(of: bane.player).last)
        let prey = try XCTUnwrap(bane.wildsStanding.first)
        let plain = bane.strengths(of: led, against: prey).attack
        let id = try XCTUnwrap(bane.commanders(of: bane.player).first).id
        bane.commanders![id - 1] = Commander(id: id, name: "Bane", archetype: .outrider, owner: bane.player)
        bane.commanders![id - 1].experience = Commander.experience(forLevel: 20)
        bane.units[try XCTUnwrap(bane.unitIndex(led.id))].leader = id
        XCTAssertGreaterThan(bane.strengths(of: try XCTUnwrap(bane.unit(led.id)), against: prey).attack, plain * 120 / 100 - 1)
    }

    func testHigherLevelsAreStrongerHardierAndRicher() {
        for level in 2...Wild.highestLevel {
            let lower = Wild(id: 1, kind: .drowned, level: level - 1, position: .origin, raised: 1)
            let higher = Wild(id: 2, kind: .drowned, level: level, position: .origin, raised: 1)
            XCTAssertGreaterThan(higher.mightPercent, lower.mightPercent)
            XCTAssertGreaterThan(higher.bodyPercent, lower.bodyPercent)
            XCTAssertGreaterThan(higher.spoils.grain, lower.spoils.grain)
            XCTAssertGreaterThan(higher.fallLessons, lower.fallLessons)
        }
        XCTAssertEqual(Wild(id: 1, kind: .drowned, level: 40, position: .origin, raised: 1).level, Wild.highestLevel)
        XCTAssertEqual(Wild(id: 1, kind: .drowned, level: -3, position: .origin, raised: 1).level, 1)
    }

    func testTheWoundedWildsMend() throws {
        var (state, _, _, wild, _) = try hunt(seed: "mending")
        state.wilds![0].health = 50
        _ = state.endWatch()
        XCTAssertEqual(state.wild(wild)?.health, 50 + GameState.wildsMending)
    }

    /// A keeper sees the wilds in sight alone, and hears of a strike on
    /// them by their own House or where they can see.
    func testAViewShowsTheWildsInSight() throws {
        var (state, me, _, wild, there) = try hunt(seed: "seen wilds")
        let seen = state.visibility(for: me)
        let hidden = try XCTUnwrap(state.map.hexes.first { hex in
            !seen[state.map.index(of: hex)!] && state.map[hex]?.terrain == .greyfield && state.isClear(hex)
        })
        let unseen = state.raise(.saltwights, level: 3, at: hidden)
        let view = state.view(for: me)
        XCTAssertNotNil(view.wild(wild))
        XCTAssertNil(view.wild(unseen))
        let mine = Hunt(attacker: 1, attackerOwner: me, attackerKind: .spear, wild: wild, wildKind: .reavers, level: 1, at: hidden,
                        damageDealt: 3, damageTaken: 2, attackerFell: false, wildFell: false, spoils: .zero)
        let theirsSeen = Hunt(attacker: 2, attackerOwner: 1, attackerKind: .bow, wild: wild, wildKind: .reavers, level: 1, at: there,
                              damageDealt: 3, damageTaken: 0, attackerFell: false, wildFell: false, spoils: .zero)
        let theirsHidden = Hunt(attacker: 3, attackerOwner: 1, attackerKind: .bow, wild: unseen, wildKind: .saltwights, level: 3, at: hidden,
                                damageDealt: 3, damageTaken: 0, attackerFell: false, wildFell: true, spoils: Stock(moonsalt: 3))
        XCTAssertEqual(state.events([.hunted(mine), .hunted(theirsSeen), .hunted(theirsHidden)], heardBy: me), [.hunted(mine), .hunted(theirsSeen)])
    }

    /// Worlds from before the wilds raise them as the watch turns.
    func testWorldsFromBeforeTheWildsRaiseThem() throws {
        var (state, _, _, _, _) = try hunt(seed: "older wilds")
        let old = try Scene.without(["wilds"], in: state)
        var loaded = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertNil(loaded.wilds)
        _ = loaded.endWatch()
        XCTAssertFalse(loaded.wildsStanding.isEmpty)
        state.wilds![0].health = 40
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
    }

    /// A steward at peace hunts the wilds near its land when the odds are
    /// good, and leaves a stronger company of them be.
    func testStewardsHuntTheWildsNearTheirLand() throws {
        var state = Scene.world("steward hunts")
        let steward = 1
        state.wilds = []
        let seat = try XCTUnwrap(state.seat(of: steward)).position
        state.units.removeAll { $0.owner == steward && $0.kind == .spear }
        let stand = try XCTUnwrap(state.freeHex(near: seat, within: 3...4, avoiding: [.shallows]))
        let hunter = state.put(.spear, tier: 3, of: steward, at: stand)
        let preyAt = try XCTUnwrap(state.freeHex(near: stand, within: 2...2, avoiding: [.shallows]))
        state.raise(.saltwights, level: 1, at: preyAt)
        XCTAssertEqual(RivalMind(house: steward).prey(for: try XCTUnwrap(state.unit(hunter)), in: state), preyAt)
        var strong = state
        strong.wilds![0] = Wild(id: strong.wilds![0].id, kind: .spineHunters, level: 10, position: preyAt, raised: 1)
        XCTAssertNil(RivalMind(house: steward).prey(for: try XCTUnwrap(strong.unit(hunter)), in: strong), "Not against odds like these")
        var tired = state
        tired.units[try XCTUnwrap(tired.unitIndex(hunter))].health = 30
        XCTAssertNil(RivalMind(house: steward).prey(for: try XCTUnwrap(tired.unit(hunter)), in: tired), "Not wounded")

        // Its turn played, with a garrison at its seat: the hunter goes for
        // them, and strikes once beside them.
        if let standing = state.unit(at: seat), let index = state.unitIndex(standing.id) {
            state.units[index].position = try XCTUnwrap(state.freeHex(near: seat, within: 1...2))
        }
        state.put(.spear, of: steward, at: seat)
        var played = state
        _ = played.stewardTurn(for: steward)
        let after = try XCTUnwrap(played.unit(hunter))
        XCTAssertTrue(after.position.distance(to: preyAt) < stand.distance(to: preyAt) || played.wild(at: preyAt)?.health ?? 0 < 100,
                      "It goes for them")
        for _ in 0..<4 where played.wild(at: preyAt) != nil {
            _ = played.endWatch()
            _ = played.stewardTurn(for: steward)
        }
        XCTAssertNil(played.wild(at: preyAt), "and strikes them down")
    }

    func testUnsoundWildsAreCaught() throws {
        let (state, _, spear, _, _) = try hunt(seed: "unsound wilds")
        func caught(_ text: String, _ change: (inout GameState) -> Void) {
            var broken = state
            change(&broken)
            XCTAssertTrue(broken.problems().contains { $0.contains(text) }, "\(text): \(broken.problems())")
        }
        caught("share their ground") { $0.wilds![0] = Wild(id: $0.wilds![0].id, kind: .reavers, level: 1, position: $0.unit(spear)!.position, raised: 1) }
        caught("health") { $0.wilds![0].health = 0 }
        caught("given twice") { $0.wilds!.append($0.wilds![0]) }
        caught("before the next id") { $0.nextID = 1 }
        caught("stand where none can") { state in
            let water = state.map.hexes.first { state.map[$0]?.terrain == .still }!
            state.wilds![0] = Wild(id: state.wilds![0].id, kind: .drowned, level: 1, position: water, raised: 1)
        }
    }

    func testTheWildsAreToldInTheGamesWords() throws {
        let (state, me, _, _, there) = try hunt(seed: "told wilds")
        let blow = Hunt(attacker: 1, attackerOwner: me, attackerKind: .spear, wild: 9, wildKind: .drowned, level: 3, at: there,
                        damageDealt: 30, damageTaken: 12, attackerFell: false, wildFell: true, spoils: Stock(grain: 30))
        XCTAssertEqual(state.tidings(of: .hunted(blow), for: me),
                       Tidings("Your Spears strike the Drowned of level 3 for 30; they fall, and leave 30 grain.", .good))
        let lost = Hunt(attacker: 1, attackerOwner: me, attackerKind: .rider, wild: 9, wildKind: .reavers, level: 9, at: there,
                        damageDealt: 8, damageTaken: 100, attackerFell: true, wildFell: false, spoils: .zero)
        XCTAssertEqual(state.tidings(of: .hunted(lost), for: me),
                       Tidings("Your Riders strike Blackwood Reavers of level 9 for 8; your company is lost.", .bad))
        let theirs = Hunt(attacker: 1, attackerOwner: 1, attackerKind: .bow, wild: 9, wildKind: .saltwights, level: 2, at: there,
                          damageDealt: 8, damageTaken: 0, attackerFell: false, wildFell: true, spoils: Stock(moonsalt: 12))
        XCTAssertEqual(state.tidings(of: .hunted(theirs), for: me),
                       Tidings("\(state.houses[1].title)'s Bows strike Saltwights of level 2, and they fall.", .neutral))
        let bare = Hunt(attacker: 1, attackerOwner: me, attackerKind: .bow, wild: 9, wildKind: .saltwights, level: 2, at: there,
                        damageDealt: 8, damageTaken: 0, attackerFell: false, wildFell: true, spoils: .zero)
        XCTAssertEqual(state.tidings(of: .hunted(bare), for: me)?.text, "Your Bows strike Saltwights of level 2 for 8; they fall.")
    }
}
