import Foundation
import XCTest
@testable import NullmereCore

/// The Crown of the Marches: a ring of the Spine about the land between
/// the Frontier's meres, four gates through it held by the wilds, which any
/// company may strike, and the Heartstone in its heart, which scores each
/// watch for its holder's kingdom. Only the Marches wear one.
final class CrownTests: XCTestCase {
    private func walk(from start: Hex, in map: WorldMap, shut: Set<Hex> = []) -> Set<Hex> {
        var seen: Set<Hex> = [start]
        var frontier = [start]
        while let hex = frontier.popLast() {
            for next in map.neighbors(of: hex) where !seen.contains(next) && !shut.contains(next) && (map[next]?.terrain.isPassable ?? false) {
                seen.insert(next)
                frontier.append(next)
            }
        }
        return seen
    }

    /// A ring of the Spine, closed but for its four gates between the
    /// meres, one tile wide and walked straight through; no seat within it
    /// or at its gates; its heart bare ground, reached through the gates
    /// alone.
    func testTheMarchesWearACrownOfPeaksWithFourGates() throws {
        for (radius, seats) in [(18, 4), (36, 12)] {
            let world = WorldGenerator(seed: Seed.from("crowned \(radius)"), radius: radius, houseCount: seats, lake: .marches, rivers: true).generate()
            let crown = WorldGenerator.crown(radius: radius)
            XCTAssertEqual(world.gates.count, 4)
            XCTAssertEqual(Set(world.gates).count, 4)
            XCTAssertTrue(world.gates.allSatisfy { $0.length == crown })
            for hex in world.map.hexes where hex.length == crown && !world.gates.contains(hex) {
                XCTAssertEqual(world.map[hex]?.terrain, .spine, "The ring closed at \(hex)")
            }
            for gate in world.gates {
                XCTAssertEqual(world.map[gate]?.terrain.isPassable, true)
                XCTAssertNil(world.map[gate]?.feature)
                XCTAssertTrue(gate.neighbors.contains { $0.length < crown && world.map[$0]?.terrain.isPassable == true }, "Walked in")
                XCTAssertTrue(gate.neighbors.contains { $0.length > crown && world.map[$0]?.terrain.isPassable == true }, "Walked out")
            }
            // Between the meres: one in each quarter of the world.
            let quarters = Set(world.gates.map { gate -> Int in
                let c = HexLayout().center(of: gate)
                return (c.x > 0 ? 1 : 0) + (c.y > 0 ? 2 : 0)
            })
            XCTAssertEqual(quarters.count, 4)
            XCTAssertTrue(world.seats.allSatisfy { $0.length > crown + 2 }, "No seat within the Crown or at its gates")
            XCTAssertEqual(world.map[.origin]?.terrain.isPassable, true)
            XCTAssertNil(world.map[.origin]?.feature)
            // The heart is walked to through the gates, and through them alone.
            let seat = try XCTUnwrap(world.seats.first)
            XCTAssertTrue(walk(from: seat, in: world.map).contains(.origin))
            XCTAssertFalse(walk(from: seat, in: world.map, shut: Set(world.gates)).contains(.origin), "Shut, the gates close the heart")
            // No stream runs within the Crown or before its gates.
            XCTAssertTrue(world.streams.allSatisfy { $0.allSatisfy { $0.length > crown + 3 } })
        }
        // Every other lake goes bare-headed.
        for lake in Lake.ofTheRealm {
            XCTAssertEqual(WorldGenerator(seed: Seed.from("bare"), radius: 24, houseCount: 5, lake: lake).generate().gates, [])
        }
    }

    /// A Frontier's world: its gates held by the wilds from the first and
    /// known to every House, with the Heartstone in the Crown's heart; no
    /// way into the heart while they stand.
    func testTheWildsHoldTheGatesAndTheHeartstoneStandsInTheHeart() throws {
        let state = GameState(settings: GameSettings(seedText: "a crowned world", houseCount: 4, radius: 18, keepers: 1, lake: .marches))
        let me = state.player
        XCTAssertEqual(state.gatesStanding.count, 4)
        XCTAssertEqual(state.gatesStanding.map(\.title), Lair.gateQuarters.map { "\($0) Gate" })
        XCTAssertTrue(state.gatesStanding.allSatisfy { $0.level == Lair.gateLevel && $0.strength == $0.might })
        XCTAssertEqual(state.gatesStanding.first?.named, "the South-East Gate of the Crown")
        let heart = try XCTUnwrap(state.heartstone)
        XCTAssertEqual(heart.position, .origin)
        XCTAssertNil(heart.holder)
        XCTAssertEqual(heart.title, "Heartstone")
        XCTAssertTrue(heart.kind.effect.contains("\(FrontierState.heartPoints) points a watch"))
        XCTAssertEqual(state.holySites.filter { $0.kind == .heartstone }.count, 1)
        XCTAssertTrue(state.holySites.filter { $0.kind != .heartstone }.allSatisfy { $0.position.distance(to: .origin) >= GameState.shrinesApart })
        XCTAssertTrue(state.holySites.allSatisfy { state.lair(at: $0.position) == nil })
        // Known to every House from afar.
        for house in state.houses.indices {
            let view = state.view(for: house)
            XCTAssertEqual(view.gatesStanding.count, 4, "\(house)")
            XCTAssertNotNil(view.heartstone, "\(house)")
        }
        XCTAssertEqual(state.problems(), [])
        // No way in while the gates stand.
        let company = try XCTUnwrap(state.units.first { $0.owner == me && $0.kind.isMilitary })
        XCTAssertNil(state.path(for: company, to: .origin))
        // Not of the far country's lairs: those still rise in their turn.
        var later = state
        later.watch = GameState.lairsFrom
        later.raiseLairs()
        XCTAssertEqual(later.lairsStanding.filter { $0.gate == nil }.count, 1)
        // Kept with the world.
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.lairs, state.lairs)
        XCTAssertEqual(kept.shrines, state.shrines)
    }

    /// Any company of war strikes a gate, from beside it or with arrows from
    /// its reach, and takes its blow back beside it; broken, the gate is
    /// gone, the way through it open, its spoils the striker's, and the
    /// whole Frontier hears of it.
    func testAnyCompanyStrikesAGateAndBrokenItLiesOpen() throws {
        var state = GameState(settings: GameSettings(seedText: "a gate struck", houseCount: 4, radius: 18, keepers: 1, lake: .marches))
        let me = state.player
        let other = (me + 1) % state.houses.count
        state.houses[other].isPlayer = true
        let gate = try XCTUnwrap(state.gatesStanding.first)
        let before = try XCTUnwrap(gate.neighbors(in: state).first { $0.length > gate.position.length })
        let placed = state.put(.spear, tier: 5, of: me, at: before)
        let spear = try XCTUnwrap(state.unit(placed))
        var struck: [GameEvent] = []
        var strikes = 0
        while state.lair(gate.id) != nil, strikes < 40 {
            let index = try XCTUnwrap(state.unitIndex(spear.id))
            state.units[index].movesLeft = state.movement(of: state.units[index])
            state.units[index].acted = false
            state.units[index].health = 100
            struck = try state.perform(.attack(unit: spear.id, target: gate.position), as: me)
            strikes += 1
            let assault = try XCTUnwrap(struck.lazy.compactMap { event -> LairAssault? in
                if case .lairAssaulted(let assault) = event { return assault } else { return nil }
            }.first)
            XCTAssertEqual(assault.rally, 0, "One company, no host")
            XCTAssertEqual(assault.gate, gate.gate)
            XCTAssertEqual(assault.houses, [me])
            XCTAssertGreaterThan(assault.dealt, 0)
            XCTAssertGreaterThan(assault.strikes.first?.taken ?? 0, 0, "Its blow back, beside it")
            if !assault.broken {
                XCTAssertEqual(state.tidings(of: struck[0], for: me)?.text.hasPrefix("Your company strikes the South-East Gate of the Crown for "), true)
                let seen = state.visibility(for: other)[try XCTUnwrap(state.map.index(of: gate.position))]
                XCTAssertEqual(state.events(struck, heardBy: other).contains(struck[0]), seen, "Struck, not broken: heard by those who see it")
            }
        }
        XCTAssertGreaterThan(strikes, 1, "Too strong to fall at one blow")
        XCTAssertNil(state.lair(gate.id), "Broken within \(strikes) strikes")
        XCTAssertEqual(state.gatesStanding.count, 3)
        let assault = try XCTUnwrap(struck.lazy.compactMap { event -> LairAssault? in
            if case .lairAssaulted(let assault) = event { return assault } else { return nil }
        }.first)
        XCTAssertTrue(assault.broken)
        XCTAssertEqual(assault.shares.first?.spoils, gate.spoils, "Its spoils the striker's")
        XCTAssertTrue(struck.contains { if case .gearFound(let house, _, _) = $0 { return house == me } else { return false } })
        XCTAssertEqual(state.chronicle.last?.text,
                       "\(state.houses[me].title) breaks the South-East Gate of the Crown: the way to the Heartstone lies open there.")
        XCTAssertTrue(state.tidings(of: struck[0], for: me)?.text.hasPrefix("Your company breaks the South-East Gate of the Crown") == true)
        XCTAssertEqual(state.tidings(of: struck[0], for: other)?.text, "\(state.houses[me].title) breaks the South-East Gate of the Crown.")
        XCTAssertTrue(state.events(struck, heardBy: other).contains(struck[0]), "A gate broken, the whole Frontier hears")
        XCTAssertEqual(state.report(of: assault, id: 1, for: me)?.title, "Your company broke the South-East Gate of the Crown")
        // The way through it open.
        let unit = try XCTUnwrap(state.unit(spear.id))
        XCTAssertNotNil(state.path(for: unit, to: .origin))
        // Out of reach, a gate may not be struck; a lair still needs a host.
        let far = try XCTUnwrap(state.gatesStanding.first)
        let index = try XCTUnwrap(state.unitIndex(spear.id))
        state.units[index].movesLeft = state.movement(of: state.units[index])
        state.units[index].acted = false
        XCTAssertThrowsError(try state.perform(.attack(unit: spear.id, target: far.position), as: me))
        let lairHex = try XCTUnwrap(unit.position.neighbors.first { state.map[$0]?.terrain.isPassable == true && state.isClear($0) && state.lair(at: $0) == nil })
        state.lairs = (state.lairs ?? []) + [Lair(id: state.takeID(), kind: .reavers, level: 1, position: lairHex, raised: state.watch)]
        XCTAssertThrowsError(try state.perform(.attack(unit: spear.id, target: lairHex), as: me)) {
            XCTAssertEqual($0 as? RuleError, .lairNeedsRally)
        }
    }

    /// At the Frontier, a gate broken counts for its breaker's kingdom, and
    /// the Heartstone, held, counts each watch for its holder's: not for a
    /// House that stands for none.
    func testAtTheFrontierTheGatesAndTheHeartstoneCountForTheKingdoms() throws {
        var frontier = RealmState(frontier: "The Lost Shore", seed: "frontier", seats: 4, radius: 18, watchLength: 60, now: 0)
        frontier.admit([Crossing(keeper: "id-ilsen", name: "Ilsen", realm: "The Nullmere", season: 1, heritage: nil,
                                 levy: [Levy(kind: .spear, tier: 5)])], from: "The Nullmere")
        frontier.admit([Crossing(keeper: "id-orla", name: "Orla", realm: "The Farmere", season: 1, heritage: nil,
                                 levy: [Levy(kind: .bow, tier: 1)])], from: "The Farmere")
        let mine = try XCTUnwrap(try frontier.arrive("id-ilsen", name: nil, now: 1).house)
        _ = try XCTUnwrap(try frontier.arrive("id-orla", name: nil, now: 2).house)
        XCTAssertEqual(frontier.world.gatesStanding.count, 4)

        // A gate broken by a company of the Nullmere's kingdom.
        let gate = try XCTUnwrap(frontier.world.gatesStanding.first)
        let before = try XCTUnwrap(gate.neighbors(in: frontier.world).first { $0.length > gate.position.length })
        let spear = try XCTUnwrap(frontier.world.units.last { $0.owner == mine && $0.kind == .spear })
        frontier.world.units[try XCTUnwrap(frontier.world.unitIndex(spear.id))].position = before
        var strikes = 0
        while frontier.world.lair(gate.id) != nil, strikes < 40 {
            let index = try XCTUnwrap(frontier.world.unitIndex(spear.id))
            frontier.world.units[index].movesLeft = frontier.world.movement(of: frontier.world.units[index])
            frontier.world.units[index].acted = false
            frontier.world.units[index].health = 100
            _ = try frontier.perform(.attack(unit: spear.id, target: gate.position), by: "id-ilsen")
            strikes += 1
        }
        XCTAssertNil(frontier.world.lair(gate.id))
        XCTAssertEqual(frontier.frontier?.points[mine], FrontierState.gatePoints)

        // Its company on the Heartstone as the watch turns: the Heartstone
        // taken, and counted for the kingdom from that watch on.
        let index = try XCTUnwrap(frontier.world.unitIndex(spear.id))
        frontier.world.units[index].position = .origin
        frontier.world.units[index].destination = nil
        _ = frontier.tick(now: 62)
        XCTAssertEqual(frontier.world.heartstone?.holder, mine)
        let held = try XCTUnwrap(frontier.frontier?.points[mine])
        XCTAssertGreaterThanOrEqual(held, FrontierState.gatePoints + FrontierState.heartPoints)
        _ = frontier.tick(now: 124)
        XCTAssertGreaterThanOrEqual(try XCTUnwrap(frontier.frontier?.points[mine]), held + FrontierState.heartPoints)

        // A House of the Lost Shore's own, standing for none, scores nothing for holding it.
        let steward = try XCTUnwrap(frontier.world.houses.indices.first { frontier.frontier?.kingdom(of: $0) == nil })
        var stewards = frontier
        stewards.world.shrines![stewards.world.shrines!.firstIndex { $0.kind == .heartstone }!].holder = steward
        let points = stewards.frontier?.points
        stewards.scoreTheHeart()
        XCTAssertEqual(stewards.frontier?.points, points)
        // Nor does the Heartstone count anywhere but the Frontier.
        var home = RealmState(name: "The Nullmere", seed: "west", seats: 4, radius: 18, watchLength: 60, now: 0)
        XCTAssertNil(home.world.heartstone)
        home.scoreTheHeart()
        XCTAssertNil(home.frontier)
    }

    /// Stewards strike the Crown's gates from their reach and send a
    /// company before one near their holds; and, a gate broken, seek the
    /// Heartstone. While every gate stands, none is sent for it.
    func testStewardsBreakTheCrownsGatesAndSeekTheHeartstone() throws {
        var state = GameState(settings: GameSettings(seedText: "stewards at the Crown", houseCount: 4, radius: 18, lake: .marches))
        var struck: Int?, broken: Int?, held: Int?
        for _ in 0..<80 where held == nil {
            let events = state.endWatch()
            if state.gatesStanding.count == Lair.gateQuarters.count {
                XCTAssertFalse(state.units.contains { $0.destination == .origin }, "No way to the Heartstone while every gate stands")
            }
            for case .lairAssaulted(let assault) in events where assault.gate != nil {
                struck = struck ?? state.watch
                if assault.broken { broken = broken ?? state.watch }
            }
            if state.heartstone?.holder != nil { held = state.watch }
        }
        print("CROWN stewards struck a gate at watch \(struck ?? -1), broke one at \(broken ?? -1), held the Heartstone at \(held ?? -1)")
        XCTAssertNotNil(struck, "Stewards strike the Crown's gates")
        XCTAssertNotNil(broken, "and break one")
        XCTAssertNotNil(held, "and take the Heartstone")
        XCTAssertEqual(state.problems(), [])
    }

    /// Only the Marches wear a Crown: a world on any other lake has no gate
    /// and no Heartstone, so it goes as it always did.
    func testOnlyTheMarchesWearACrown() {
        for lake in Lake.ofTheRealm {
            let state = GameState(settings: GameSettings(seedText: "bare-headed", houseCount: 4, radius: 18, keepers: 1, lake: lake))
            XCTAssertNil(state.lairs, "\(lake)")
            XCTAssertNil(state.heartstone, "\(lake)")
            XCTAssertTrue(state.holySites.allSatisfy { ShrineKind.raised.contains($0.kind) }, "\(lake)")
        }
    }
}

private extension Lair {
    /// The ground about it, as a company could stand there.
    func neighbors(in state: GameState) -> [Hex] {
        position.neighbors.filter { state.map[$0]?.terrain.isPassable == true && state.isClear($0) }
    }
}
