import Foundation
import XCTest
@testable import NullmereCore

/// The realm's happenings: ten watches in which every House strives at one
/// thing for points, marks passed rewarded, the foremost honoured.
final class HappeningTests: XCTestCase {
    func testHappeningsComeRoundOnAFixedCourse() {
        XCTAssertNil(Happening.number(beginningAt: 9))
        XCTAssertEqual(Happening.number(beginningAt: 10), 0)
        XCTAssertNil(Happening.number(beginningAt: 25))
        XCTAssertEqual(Happening.number(beginningAt: 40), 1)
        XCTAssertEqual(Happening.number(beginningAt: 100), 3)
        let seed = Seed.from("course")
        let kinds = (0..<5).map { Happening.kind(number: $0, seed: seed) }
        XCTAssertEqual(Set(kinds).count, 5, "Each kind in turn")
        XCTAssertEqual(kinds, (0..<5).map { Happening.kind(number: $0, seed: seed) }, "The same course for the same realm")
        XCTAssertEqual(Happening.kind(number: 5, seed: seed), kinds[0])
        XCTAssertEqual(Set(HappeningKind.allCases.map(\.title)).count, 5)
        XCTAssertEqual(Set(HappeningKind.allCases.map(\.goal)).count, 5)
    }

    func testWhatEarnsPoints() throws {
        var state = Scene.world("points")
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        let rider = state.put(.rider, tier: 3, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position)))
        let hunt = Hunt(attacker: rider, attackerOwner: me, attackerKind: .rider, wild: 1, wildKind: .reavers, level: 3, at: seat.position,
                        damageDealt: 40, damageTaken: 5, attackerFell: false, wildFell: true, spoils: .zero)
        let missed = Hunt(attacker: rider, attackerOwner: me, attackerKind: .rider, wild: 1, wildKind: .reavers, level: 3, at: seat.position,
                          damageDealt: 10, damageTaken: 5, attackerFell: false, wildFell: false, spoils: .zero)
        func points(_ kind: HappeningKind, _ event: GameEvent) -> Int? {
            kind.points(for: event, in: state).map { $0.house == me ? $0.points : -1 }
        }
        XCTAssertEqual(points(.longHunt, .hunted(hunt)), 6)
        XCTAssertNil(points(.longHunt, .hunted(missed)), "Only what falls")
        XCTAssertEqual(points(.harvestFair, .delivered(unit: rider, owner: me, hold: seat.id, load: Stock(grain: 60, moonsalt: 5))), 4)
        XCTAssertEqual(points(.raising, .buildingCompleted(hold: seat.id, kind: .walls, level: 2)), 4)
        XCTAssertEqual(points(.muster, .unitTrained(unit: rider, hold: seat.id)), 6)
        XCTAssertEqual(points(.learnedSeason, .studyCompleted(house: me, study: .drill, grade: 2)), 5)
        XCTAssertNil(points(.raising, .hunted(hunt)))
        XCTAssertNil(points(.muster, .buildingCompleted(hold: seat.id, kind: .walls, level: 2)))
    }

    func testAHappeningBeginsCountsRewardsAndEnds() throws {
        var state = Scene.world("a happening", houses: 4, radius: 18)
        let me = state.player
        state.watch = Happening.first - 1
        let begun = state.endWatch().filter { if case .happeningBegun = $0 { return true } else { return false } }
        let happening = try XCTUnwrap(state.happening)
        XCTAssertEqual(begun, [.happeningBegun(kind: happening.kind, ends: Happening.first + Happening.lasts)])
        XCTAssertEqual(happening.kind, Happening.kind(number: 0, seed: state.settings.seed))
        XCTAssertEqual(happening.points, [0, 0, 0, 0])
        XCTAssertTrue(state.chronicle.contains { $0.kind == .happening && $0.text == "\(happening.kind.title) begins: \(happening.kind.goal), until the 20th watch." })
        XCTAssertEqual(state.events(begun, heardBy: me), begun)

        // A Raising staged: what each House raises counts.
        state.happening = Happening(number: 0, kind: .raising, begins: state.watch, houses: 4)
        let seat = try XCTUnwrap(state.seat(of: me)).id
        let theirs = try XCTUnwrap(state.seat(of: 1)).id
        let others = try XCTUnwrap(state.seat(of: 2)).id
        state.tally([.buildingCompleted(hold: seat, kind: .walls, level: 3), .buildingCompleted(hold: seat, kind: .granary, level: 3)])
        state.tally([.buildingCompleted(hold: theirs, kind: .walls, level: 4), .buildingCompleted(hold: others, kind: .walls, level: 1)])
        XCTAssertEqual(state.happening?.points, [12, 8, 2, 0])
        XCTAssertEqual(state.happening?.leaderboard, [me, 1, 2])
        state.houses[me].stock = .zero
        let marks = state.turnHappenings()
        XCTAssertEqual(marks, [.happeningMark(house: me, kind: .raising, mark: 1, reward: Happening.markRewards[0])])
        XCTAssertEqual(state.houses[me].stock, Happening.markRewards[0])
        XCTAssertEqual(state.happening?.passed, [1, 0, 0, 0])
        XCTAssertEqual(state.turnHappenings(), [], "A mark is passed once")
        XCTAssertEqual(state.events(marks, heardBy: me), marks)
        XCTAssertEqual(state.events(marks, heardBy: 1), [])
        XCTAssertEqual(state.tidings(of: marks[0], for: me)?.text, "Your House passes the first mark of The Raising: \(Happening.markRewards[0]).")
        XCTAssertNil(state.tidings(of: marks[0], for: 1))

        // Two marks at once, passed in turn.
        state.tally([.buildingCompleted(hold: theirs, kind: .granary, level: 5), .buildingCompleted(hold: theirs, kind: .walls, level: 5)])
        XCTAssertEqual(state.turnHappenings().count, 2)
        XCTAssertEqual(state.happening?.passed[1], 2)

        // Its end: the foremost honoured, in the chronicle and in stores.
        state.watch = try XCTUnwrap(state.happening).ends
        for house in 0..<4 { state.houses[house].stock = .zero }
        let ended = state.turnHappenings()
        XCTAssertEqual(ended, [.happeningEnded(kind: .raising, leaders: [1, me, 2])])
        XCTAssertNil(state.happening)
        XCTAssertEqual(state.houses[1].stock, Happening.honours[0])
        XCTAssertEqual(state.houses[me].stock, Happening.honours[1])
        XCTAssertEqual(state.houses[2].stock, Happening.honours[2])
        XCTAssertEqual(state.houses[3].stock, .zero)
        let names = [1, me, 2].map { state.houses[$0].title }
        XCTAssertEqual(state.chronicle.last?.text, "The Raising ends: \(names[0]) takes the honours, ahead of \(names[1]) and \(names[2]).")
        XCTAssertEqual(state.tidings(of: ended[0], for: me), Tidings("The Raising ends: your House stands second, and is honoured.", .good))
        XCTAssertEqual(state.tidings(of: ended[0], for: 3)?.text, "The Raising ends: \(names[0]) takes the honours.")
        XCTAssertEqual(state.tidings(of: .happeningEnded(kind: .muster, leaders: []), for: 3)?.text, "The Great Muster ends with no House to honour.")
        XCTAssertEqual(state.events(ended, heardBy: 3), ended)

        // The next comes at its watch, and not before.
        state.watch = Happening.first + Happening.every - 1
        XCTAssertEqual(state.turnHappenings(), [])
        state.watch += 1
        XCTAssertEqual(state.turnHappenings(), [.happeningBegun(kind: Happening.kind(number: 1, seed: state.settings.seed), ends: state.watch + Happening.lasts)])
    }

    func testFewerThanThreeHonoured() throws {
        var state = Scene.world("few honoured", houses: 3)
        func season(_ completed: [GameEvent]) -> [GameEvent] {
            state.happening = Happening(number: 0, kind: .learnedSeason, begins: state.watch, houses: 3)
            state.tally(completed)
            state.watch = state.happening!.ends
            return state.turnHappenings()
        }
        XCTAssertEqual(season([.studyCompleted(house: 2, study: .drill, grade: 1)]), [.happeningEnded(kind: .learnedSeason, leaders: [2])])
        XCTAssertEqual(state.chronicle.last?.text, "The Learned Season ends: \(state.houses[2].title) takes the honours.")
        XCTAssertEqual(season([.studyCompleted(house: 2, study: .drill, grade: 1), .studyCompleted(house: 1, study: .drill, grade: 2)]).last,
                       .happeningEnded(kind: .learnedSeason, leaders: [1, 2]))
        XCTAssertEqual(state.chronicle.last?.text,
                       "The Learned Season ends: \(state.houses[1].title) takes the honours, ahead of \(state.houses[2].title).")
        XCTAssertEqual(season([]).last, .happeningEnded(kind: .learnedSeason, leaders: []))
        XCTAssertEqual(state.chronicle.last?.text, "The Learned Season ends with no House to honour.")
        // A fallen House is honoured no more.
        state.houses[2].isEliminated = true
        XCTAssertEqual(season([.studyCompleted(house: 2, study: .drill, grade: 3)]).last, .happeningEnded(kind: .learnedSeason, leaders: []))
        // Nothing counts once it is over.
        state.happening = Happening(number: 0, kind: .learnedSeason, begins: state.watch, houses: 3)
        state.watch = state.happening!.ends
        state.tally([.studyCompleted(house: 1, study: .drill, grade: 1)])
        XCTAssertEqual(state.happening?.points, [0, 0, 0])
    }

    /// A keeper's own deeds count as they are done: a company of the
    /// wilds struck down in a Long Hunt.
    func testAKeepersDeedsCountAsTheyAreDone() throws {
        var state = Scene.world("a keeper's hunt")
        let me = state.player
        state.happening = Happening(number: 0, kind: .longHunt, begins: state.watch, houses: state.houses.count)
        let spot = try XCTUnwrap(state.openGround(awayFromHolds: 2))
        let rider = state.put(.rider, tier: 3, of: me, at: spot)
        let prey = try XCTUnwrap(state.map.neighbors(of: spot).first { state.isClear($0) && state.map[$0]?.terrain.isPassable == true })
        let wild = state.raise(.saltwights, level: 2, at: prey)
        state.wilds![state.wilds!.firstIndex { $0.id == wild }!].health = 1
        let events = try state.perform(.attack(unit: rider, target: prey), as: me)
        XCTAssertTrue(events.contains { if case .hunted(let hunt) = $0 { return hunt.wildFell } else { return false } })
        XCTAssertEqual(state.happening?.points[me], 4)
    }

    func testHappeningsAreKeptInSavesAndSeenByAll() throws {
        var state = Scene.world("kept happenings")
        state.happening = Happening(number: 2, kind: .harvestFair, begins: 70, houses: state.houses.count)
        state.tally([.delivered(unit: 1, owner: 1, hold: 1, load: Stock(grain: 200))])
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        XCTAssertNil(try JSONDecoder().decode(GameState.self, from: Scene.without(["happening"], in: state)).happening)
        XCTAssertEqual(state.view(for: 2).happening, state.happening, "Its standings are known to all")
    }

    /// In a Long Hunt the ambitious and the cunning hunt further afield;
    /// in a Harvest Fair the steadfast and the wary gather any store they
    /// have room for.
    func testStewardsLeanIntoAHappeningByTheirTemper() throws {
        var state = Scene.world("leaning in", houses: 3, radius: 18)
        let steward = 1
        let seat = try XCTUnwrap(state.seat(of: steward)).position
        state.wilds = []
        state.units.removeAll { $0.owner == steward }
        let hunter = state.put(.rider, tier: 5, of: steward, at: try XCTUnwrap(state.freeHex(near: seat, within: 1...2)))
        let far = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: seat) == RivalMind.huntingGround + 5 && hex.distance(to: state.unit(hunter)!.position) <= RivalMind.huntingGround + 6
                && state.map[hex]?.terrain.isPassable == true && state.isClear(hex) && state.holds.allSatisfy { $0.position.distance(to: hex) >= 6 }
        })
        state.raise(.reavers, level: 1, at: far)
        state.houses[steward].temperament = .ambitious
        let mind = RivalMind(house: steward)
        XCTAssertNil(mind.prey(for: state.unit(hunter)!, in: state), "Beyond its usual ground")
        state.happening = Happening(number: 0, kind: .longHunt, begins: state.watch, houses: 3)
        XCTAssertEqual(mind.prey(for: state.unit(hunter)!, in: state), far, "In a Long Hunt, further afield")
        state.houses[steward].temperament = .wary
        XCTAssertNil(mind.prey(for: state.unit(hunter)!, in: state), "The wary keep their ground")

        // A site of a store the House has more than half the room for.
        var fair = Scene.world("a fair", houses: 3, radius: 18)
        fair.units.removeAll { $0.owner == steward }
        let home = try XCTUnwrap(fair.seat(of: steward)).position
        let gatherer = fair.put(.spear, of: steward, at: try XCTUnwrap(fair.freeHex(near: home, within: 1...2)))
        let spot = try XCTUnwrap(fair.freeHex(near: home, within: 4...5))
        fair.sites = [Site(id: fair.takeID(), store: .timber, level: 1, position: spot, found: fair.watch)]
        fair.reveal(around: spot, range: 0, for: steward)
        let room = fair.storage(of: steward)
        fair.houses[steward].stock = Stock(grain: room, timber: room * 7 / 10, stone: room, moonsalt: room)
        fair.houses[steward].temperament = .steadfast
        XCTAssertNil(mind.site(for: fair.unit(gatherer)!, in: fair))
        fair.happening = Happening(number: 0, kind: .harvestFair, begins: fair.watch, houses: 3)
        XCTAssertEqual(mind.site(for: fair.unit(gatherer)!, in: fair), fair.sites?.first?.id)
        fair.houses[steward].temperament = .ambitious
        XCTAssertNil(mind.site(for: fair.unit(gatherer)!, in: fair))
    }
}
