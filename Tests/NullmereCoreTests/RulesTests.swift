import XCTest
@testable import NullmereCore

final class RulesTests: XCTestCase {
    private func newGame(_ seed: String = "the still water") -> GameState {
        GameState(settings: GameSettings(seedText: seed))
    }

    /// A free passable hex next to `hex`, for staging a scene.
    private func freeNeighbor(of hex: Hex, in state: GameState) -> Hex {
        hex.ring(1).first { candidate in
            guard let tile = state.map[candidate] else { return false }
            return tile.terrain.isPassable && state.unit(at: candidate) == nil && state.hold(at: candidate) == nil
        }!
    }

    func testANewGameSeatsEveryHouse() {
        let state = newGame()
        XCTAssertEqual(state.houses.count, 5)
        XCTAssertEqual(state.player, 0)
        XCTAssertTrue(state.houses[0].isPlayer)
        XCTAssertEqual(state.houses[0].name, "Aurel")
        for house in state.houses {
            XCTAssertEqual(state.holds(of: house.id).count, 1)
            XCTAssertNotNil(state.seat(of: house.id))
            XCTAssertEqual(state.units(of: house.id).map(\.kind).sorted { $0.rawValue < $1.rawValue }, [.lantern, .spear])
            let seat = state.seat(of: house.id)!
            XCTAssertTrue(house.explored[state.map.index(of: seat.position)!], "A House sees its own seat")
        }
        XCTAssertTrue(state.relations.allSatisfy { $0.stance == .peace })
        XCTAssertEqual(state.chronicle.count, 1)
    }

    func testUnitsMarchAndRefuseTheImpossible() throws {
        var state = newGame()
        let lantern = state.units(of: 0).first { $0.kind == .lantern }!
        let target = lantern.position.spiral(2).first { hex in
            hex.distance(to: lantern.position) == 2 && state.map[hex]?.terrain.moveCost == 1 && state.unit(at: hex) == nil
        }!
        let events = try state.perform(.move(unit: lantern.id, to: target), as: 0)
        XCTAssertEqual(state.unit(lantern.id)?.position, target)
        XCTAssertLessThan(state.unit(lantern.id)!.movesLeft, UnitKind.lantern.movement)
        guard case .moved(_, let path)? = events.first else { return XCTFail("expected a march") }
        XCTAssertEqual(path.last, target)

        let spine = state.map.hexes.first { state.map[$0]?.terrain == .spine }!
        XCTAssertThrowsError(try state.perform(.move(unit: lantern.id, to: spine), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .impassable(.spine))
        }
        let rivalUnit = state.units(of: 1)[0]
        XCTAssertThrowsError(try state.perform(.move(unit: rivalUnit.id, to: target), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .notYours)
        }
    }

    func testLongMarchesContinueInLaterWatches() throws {
        var state = newGame()
        let spear = state.units(of: 0).first { $0.kind == .spear }!
        let far = state.map.hexes
            .filter { state.map[$0]!.terrain.isPassable && state.unit(at: $0) == nil && state.hold(at: $0) == nil }
            .filter { $0.distance(to: spear.position) == 6 && state.path(for: spear, to: $0) != nil }
            .first!
        try state.perform(.move(unit: spear.id, to: far), as: 0)
        XCTAssertEqual(state.unit(spear.id)?.destination, far)
        for _ in 0..<8 where state.unit(spear.id)?.position != far {
            state.endWatch()
        }
        XCTAssertEqual(state.unit(spear.id)?.position, far)
        XCTAssertNil(state.unit(spear.id)?.destination)
    }

    func testBuildingCostsStockAndCompletesOverWatches() throws {
        var state = newGame()
        let seat = state.seat(of: 0)!
        let before = state.income(of: seat)
        state.houses[0].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 100)
        try state.perform(.build(hold: seat.id, kind: .granary), as: 0)
        XCTAssertEqual(state.houses[0].stock.timber, 500 - BuildingKind.granary.cost(toLevel: 1).timber)
        XCTAssertThrowsError(try state.perform(.build(hold: seat.id, kind: .quarry), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .busy)
        }
        for _ in 0..<BuildingKind.granary.buildWatches(toLevel: 1) {
            state.endWatch()
        }
        let built = state.seat(of: 0)!
        XCTAssertEqual(built.level(.granary), 1)
        XCTAssertNil(built.project)
        XCTAssertEqual(state.income(of: built).grain, before.grain * 125 / 100)
    }

    func testShortfallsAreExact() {
        var state = newGame()
        let seat = state.seat(of: 0)!
        state.houses[0].stock = Stock(grain: 0, timber: 5, stone: 100)
        XCTAssertThrowsError(try state.perform(.build(hold: seat.id, kind: .granary), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .shortOf(Stock(grain: 10, timber: 20)))
        }
        XCTAssertThrowsError(try state.perform(.build(hold: seat.id, kind: .moonspire), as: 1)) { error in
            XCTAssertEqual(error as? RuleError, .notYours)
        }
    }

    func testTrainingNeedsAMusterHallAndYieldsAUnit() throws {
        var state = newGame()
        let seat = state.seat(of: 0)!
        state.houses[0].stock = Stock(grain: 500, timber: 500, stone: 500, moonsalt: 100)
        XCTAssertThrowsError(try state.perform(.train(hold: seat.id, kind: .spear), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .needsMusterHall(1))
        }
        state.holds[state.holdIndex(seat.id)!].levels[.musterHall] = 1
        try state.perform(.train(hold: seat.id, kind: .spear), as: 0)
        let count = state.units(of: 0).count
        for _ in 0..<UnitKind.spear.trainWatches { state.endWatch() }
        XCTAssertEqual(state.units(of: 0).count, count + 1)
    }

    func testFoundersSettleOnlyWithRoom() throws {
        var state = newGame()
        let seat = state.seat(of: 0)!
        let founder = state.placeUnit(.founder, for: 0, near: freeNeighbor(of: seat.position, in: state))!
        XCTAssertThrowsError(try state.perform(.found(unit: founder.id), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .tooCloseToHold)
        }
        let site = state.map.hexes.first { hex in
            state.canFound(at: hex, for: 0) == nil && hex.distance(to: seat.position) == 4 && state.unit(at: hex) == nil
        }!
        state.units[state.unitIndex(founder.id)!].position = site
        try state.perform(.found(unit: founder.id), as: 0)
        XCTAssertEqual(state.holds(of: 0).count, 2)
        XCTAssertNil(state.unit(founder.id), "The founders become the hold")
        XCTAssertEqual(state.chronicle.last?.kind, .founding)
    }

    func testWarBreaksWardsTakesHoldsAndEndsHouses() throws {
        var state = newGame()
        let rival = 1
        let target = state.seat(of: rival)!
        state.units.removeAll { $0.owner == rival }
        let spot = freeNeighbor(of: target.position, in: state)
        let spear = state.placeUnit(.spear, for: 0, near: spot)!
        XCTAssertEqual(spear.position, spot)

        XCTAssertThrowsError(try state.perform(.attack(unit: spear.id, target: target.position), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .notAtWar(rival))
        }
        try state.perform(.declareWar(on: rival), as: 0)
        XCTAssertEqual(state.stance(0, rival), .war)
        XCTAssertEqual(state.chronicle.last?.kind, .war)

        var captured = false
        for _ in 0..<12 where !captured {
            if let index = state.unitIndex(spear.id) {
                state.units[index].movesLeft = UnitKind.spear.movement
                state.units[index].health = 100
            }
            let events = try state.perform(.attack(unit: spear.id, target: target.position), as: 0)
            captured = events.contains { if case .holdCaptured = $0 { return true } else { return false } }
        }
        XCTAssertTrue(captured)
        XCTAssertEqual(state.hold(target.id)?.owner, 0)
        XCTAssertEqual(state.unit(spear.id)?.position, target.position, "The victors march in")
        XCTAssertTrue(state.houses[rival].isEliminated, "A House with no holds falls")
        XCTAssertEqual(state.chronicle.last?.kind, .fall)
    }

    func testBattlesHurtBothSidesAndBowsStrikeFromAfar() throws {
        var state = newGame()
        state.units.removeAll()
        let ground = state.map.hexes.first { hex in
            state.map[hex]?.terrain == .greyfield && hex.ring(1).allSatisfy { state.map[$0]?.terrain == .greyfield }
                && hex.spiral(3).allSatisfy { state.hold(at: $0) == nil }
        }!
        let spear = state.placeUnit(.spear, for: 0, near: ground)!
        let enemy = state.placeUnit(.spear, for: 1, near: ground + Hex.directions[0])!
        try state.perform(.declareWar(on: 1), as: 0)
        let events = try state.perform(.attack(unit: spear.id, target: enemy.position), as: 0)
        guard case .battle(let battle)? = events.first else { return XCTFail("expected a battle") }
        XCTAssertGreaterThan(battle.damageDealt, 0)
        XCTAssertGreaterThan(battle.damageTaken, 0)
        XCTAssertLessThan(state.unit(spear.id)!.health, 100)
        XCTAssertThrowsError(try state.perform(.attack(unit: spear.id, target: enemy.position), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .noMovesLeft)
        }

        let bow = state.placeUnit(.bow, for: 0, near: ground + Hex.directions[3] * 1)!
        XCTAssertEqual(bow.position.distance(to: enemy.position), 2)
        let volley = try state.perform(.attack(unit: bow.id, target: enemy.position), as: 0)
        guard case .battle(let shot)? = volley.first else { return XCTFail("expected a volley") }
        XCTAssertEqual(shot.damageTaken, 0, "Bows take no blow in return")
        XCTAssertEqual(state.unit(bow.id)?.health, 100)
    }

    func testRivalsWeighPeaceAndPactsAndEnvoysWaitForAnswers() throws {
        var state = newGame()
        XCTAssertThrowsError(try state.perform(.propose(.peace, to: 2), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .alreadyStance(.peace))
        }
        // A rival sends the player an envoy offering a pact.
        let events = try state.propose(.pact, from: 2, to: 0)
        guard case .envoyArrived(let envoy)? = events.first else { return XCTFail("expected an envoy") }
        XCTAssertEqual(state.envoys.count, 1)
        try state.perform(.answer(envoy: envoy.id, accept: true), as: 0)
        XCTAssertEqual(state.stance(0, 2), .pact)
        XCTAssertTrue(state.envoys.isEmpty)
        let allySeat = state.seat(of: 2)!
        XCTAssertTrue(state.visibility(for: 0)[state.map.index(of: allySeat.position)!], "Allies share sight")

        // Breaking it is remembered.
        try state.perform(.declareWar(on: 2), as: 0)
        XCTAssertEqual(state.chronicle.last?.kind, .betrayal)
        XCTAssertEqual(state.relation(0, 2)?.betrayals, 1)
        state.watch += 5
        try state.perform(.propose(.peace, to: 2), as: 0)
        XCTAssertFalse(RivalMind(house: 2).accepts(.pact, from: 0, in: state), "No pact with a betrayer")
    }

    func testEnvoysLeaveIfUnanswered() throws {
        var state = newGame()
        _ = try state.propose(.pact, from: 3, to: 0)
        XCTAssertEqual(state.envoys.count, 1)
        for _ in 0..<Envoy.patience { state.endWatch() }
        XCTAssertFalse(state.envoys.contains { $0.from == 3 && $0.arrived == 1 })
    }

    func testHungerWoundsTheNewestCompanies() {
        var state = newGame()
        let seat = state.seat(of: 0)!
        for _ in 0..<40 {
            state.placeUnit(.spear, for: 0, near: seat.position)
        }
        state.houses[0].stock.grain = 0
        let events = state.endWatch()
        XCTAssertTrue(events.contains(.starving(house: 0)))
        XCTAssertTrue(state.units(of: 0).contains { $0.health < 100 })
    }

    func testTheSameCommandsReplayTheSameHistory() throws {
        func play() -> GameState {
            var state = newGame("replay")
            for _ in 0..<40 {
                state.stewardTurn(for: state.player)
                state.endWatch()
            }
            return state
        }
        XCTAssertEqual(play(), play())
    }

    func testSavesRoundTrip() throws {
        var state = newGame()
        for _ in 0..<15 {
            state.stewardTurn(for: 0)
            state.endWatch()
        }
        let data = try JSONEncoder().encode(state)
        let restored = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(restored, state)
    }
}
