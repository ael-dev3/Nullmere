import XCTest
@testable import NullmereCore

final class RulesTests: XCTestCase {
    private func newGame(_ seed: String = "the still water") -> GameState {
        GameState(settings: GameSettings(seedText: seed, keepers: 1))
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

        // The Spine, once seen, can't be crossed.
        let spine = state.map.hexes.first { state.map[$0]?.terrain == .spine }!
        state.reveal(around: spine, range: 0, for: 0)
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

final class EconomyTests: XCTestCase {
    func testBarterTradesThreeToOneWithMoonsaltDearer() throws {
        var state = GameState(settings: GameSettings(seedText: "barter", keepers: 1))
        state.houses[0].stock = Stock(grain: 300, timber: 0, stone: 10, moonsalt: 30)
        try state.perform(.barter(give: .grain, take: .timber, amount: 50), as: 0)
        XCTAssertEqual(state.houses[0].stock.grain, 150)
        XCTAssertEqual(state.houses[0].stock.timber, 50)
        XCTAssertEqual(Resource.moonsalt.barterCost(of: 10, paidIn: .grain), 90)
        XCTAssertEqual(Resource.stone.barterCost(of: 10, paidIn: .moonsalt), 10)
        XCTAssertThrowsError(try state.perform(.barter(give: .stone, take: .grain, amount: 10), as: 0)) { error in
            XCTAssertEqual(error as? RuleError, .shortOf(Stock(stone: 20)))
        }
        XCTAssertThrowsError(try state.perform(.barter(give: .grain, take: .grain, amount: 10), as: 0))
    }

    func testStorageLimitsWhatAHouseKeeps() {
        var state = GameState(settings: GameSettings(seedText: "storage", keepers: 1))
        let room = state.storage(of: 0)
        XCTAssertEqual(room, GameState.baseStorage + GameState.storagePerHold)
        state.houses[0].stock = Stock(grain: room, timber: room, stone: room, moonsalt: room)
        state.endWatch()
        for resource in Resource.allCases {
            XCTAssertLessThanOrEqual(state.houses[0].stock[resource], room)
        }
    }

    func testTheMoonspireCanBeFinishedByAFourHoldRealm() {
        let top = BuildingKind.moonspire.cost(toLevel: BuildingKind.moonspire.maxLevel)
        let storage = GameState.baseStorage + GameState.storagePerHold * 4
        for resource in Resource.allCases {
            XCTAssertLessThanOrEqual(top[resource], storage, "\(resource) for the last stage must fit four holds' stores")
        }
        let threeHolds = GameState.baseStorage + GameState.storagePerHold * 3
        XCTAssertTrue(Resource.allCases.contains { top[$0] > threeHolds }, "A small realm can't finish it")
    }

    func testRivalsFearARisingMoonspire() {
        var state = GameState(settings: GameSettings(seedText: "fear", keepers: 1))
        let seat = state.seat(of: 0)!
        state.holds[state.holdIndex(seat.id)!].levels[.moonspire] = 3
        XCTAssertEqual(RivalMind(house: 1).spireThreat(in: state), 0)
        XCTAssertNil(RivalMind(house: 0).spireThreat(in: state), "A House doesn't fear its own tower")
    }
}

final class ForecastTests: XCTestCase {
    /// Every attack lands inside its forecast: at each watch of a few whole
    /// games, every attack any unit could make is forecast, then made on a
    /// copy of the game.
    func testAttacksLandInsideTheirForecasts() throws {
        var checked = 0
        for seed in ["forecast one", "forecast two", "forecast three"] {
            var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
            for _ in 0..<160 where state.outcome == nil {
                for unit in state.units {
                    for hex in unit.position.spiral(unit.kind.range) {
                        guard let forecast = state.forecast(unit: unit.id, at: hex) else { continue }
                        var trial = state
                        let events = try trial.perform(.attack(unit: unit.id, target: hex), as: unit.owner)
                        for case .battle(let battle) in events {
                            XCTAssertTrue(forecast.dealt.contains(battle.damageDealt), "\(battle) vs \(forecast)")
                            XCTAssertTrue(forecast.taken.contains(battle.damageTaken), "\(battle) vs \(forecast)")
                            checked += 1
                        }
                    }
                }
                _ = state.endWatch()
            }
        }
        XCTAssertGreaterThan(checked, 20, "enough attacks were tried")
    }

    /// A blow that breaks a ward takes the hold only if the striker lives
    /// through the walls' return blow, and the forecast promises no more.
    func testAStrikerFellByTheWallsIsPromisedNoHold() throws {
        var state = GameState(settings: GameSettings(seedText: "the last blow", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player, rival = 1
        let seat = try XCTUnwrap(state.seat(of: rival))
        let index = try XCTUnwrap(state.holdIndex(seat.id))
        state.units.removeAll { $0.owner == rival }
        state.holds[index].levels[.walls] = 1
        state.holds[index].ward = 5
        let spot = try XCTUnwrap(state.map.neighbors(of: seat.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        var spear = Unit(id: state.nextID, kind: .spear, owner: me, position: spot)
        spear.health = 8
        state.units.append(spear)
        state.nextID += 1
        _ = try state.declareWar(by: me, on: rival)
        let forecast = try XCTUnwrap(state.forecast(unit: spear.id, at: seat.position))
        XCTAssertTrue(forecast.surelyFinishes, "The ward breaks")
        XCTAssertEqual(forecast.taken, 9...9, "and the walls strike back for nine")
        XCTAssertTrue(forecast.mayFall)
        XCTAssertFalse(forecast.couldCapture, "No hold promised to a company that falls at its gate")
        let events = try state.perform(.attack(unit: spear.id, target: seat.position), as: me)
        XCTAssertFalse(events.contains { if case .holdCaptured = $0 { return true } else { return false } })
        XCTAssertEqual(state.hold(seat.id)?.ward, 0)
        XCTAssertEqual(state.hold(seat.id)?.owner, rival)
        XCTAssertNil(state.unit(spear.id))
        // A striker that lives through it is promised the hold, and takes it.
        state.holds[index].ward = 5
        spear = Unit(id: state.nextID, kind: .spear, owner: me, position: spot)
        state.units.append(spear)
        state.nextID += 1
        XCTAssertEqual(state.forecast(unit: spear.id, at: seat.position)?.couldCapture, true)
        _ = try state.perform(.attack(unit: spear.id, target: seat.position), as: me)
        XCTAssertEqual(state.hold(seat.id)?.owner, me)
    }

    func testNoForecastWithoutAWar() {
        let state = GameState(settings: GameSettings(seedText: "no war", houseCount: 3, radius: 14, keepers: 1))
        let unit = state.units(of: state.player).first { $0.kind.isMilitary }!
        for hex in unit.position.spiral(3) {
            XCTAssertNil(state.forecast(unit: unit.id, at: hex))
        }
    }
}

final class VeterancyTests: XCTestCase {
    func testRanksFollowExperience() {
        XCTAssertEqual(Unit.rank(forExperience: 0), 0)
        XCTAssertEqual(Unit.rank(forExperience: 2), 1)
        XCTAssertEqual(Unit.rank(forExperience: 5), 2)
        XCTAssertEqual(Unit.rank(forExperience: 9), 3)
        XCTAssertEqual(Unit.rank(forExperience: 40), 3)
    }

    /// Survivors of battles gain experience; over whole games some companies
    /// rise in rank, and a veteran fights better than a fresh company.
    func testBattlesMakeVeterans() throws {
        var promotions = 0
        var state = GameState(settings: GameSettings(seedText: "veterans", houseCount: 4, radius: 18, keepers: 1))
        for _ in 0..<160 where state.outcome == nil {
            var events = state.stewardTurn(for: state.player)
            events += state.endWatch()
            promotions += events.filter { if case .promoted = $0 { return true } else { return false } }.count
        }
        XCTAssertGreaterThan(promotions, 0)

        let fresh = Unit(id: 1, kind: .spear, owner: 0, position: Hex(0, 0))
        var veteran = fresh
        veteran.experience = 9
        let foe = Unit(id: 2, kind: .spear, owner: 1, position: Hex(1, 0))
        XCTAssertGreaterThan(state.strengths(of: veteran, against: foe, at: foe.position).attack,
                             state.strengths(of: fresh, against: foe, at: foe.position).attack)
    }

    /// Games saved before veterancy still load, with every company untried.
    func testOlderSavesLoad() throws {
        let unit = Unit(id: 7, kind: .bow, owner: 2, position: Hex(3, -1))
        var json = try XCTUnwrap(JSONSerialization.jsonObject(with: JSONEncoder().encode(unit)) as? [String: Any])
        json["experience"] = nil
        let old = try JSONSerialization.data(withJSONObject: json)
        let loaded = try JSONDecoder().decode(Unit.self, from: old)
        XCTAssertEqual(loaded.experience, 0)
        XCTAssertEqual(loaded.id, 7)
        XCTAssertEqual(try JSONDecoder().decode(Unit.self, from: JSONEncoder().encode(unit)), unit)
    }
}

final class ReachTests: XCTestCase {
    /// Every hex in reach is where a march there ends this watch, and every
    /// hex just beyond is not.
    func testReachMatchesWhatMarchesDo() throws {
        var checked = 0
        for seed in ["reach one", "reach two"] {
            var state = GameState(settings: GameSettings(seedText: seed, houseCount: 3, radius: 16, keepers: 1))
            for _ in 0..<30 {
                for unit in state.units(of: state.player) where unit.movesLeft > 0 {
                    let reach = state.reach(of: unit)
                    for hex in unit.position.spiral(unit.kind.movement + 1).dropFirst() {
                        guard state.map[hex]?.terrain.isPassable == true, state.unit(at: hex) == nil,
                              state.hold(at: hex).map({ $0.owner == unit.owner }) ?? true,
                              state.forecast(unit: unit.id, at: hex) == nil
                        else { continue }
                        var trial = state
                        guard (try? trial.perform(.move(unit: unit.id, to: hex), as: unit.owner)) != nil else {
                            XCTAssertNil(reach[hex], "\(hex) can't be marched to at all")
                            continue
                        }
                        let arrived = trial.unit(unit.id)?.position == hex
                        XCTAssertEqual(reach[hex] != nil, arrived, "\(unit.kind) to \(hex): reach says \(reach[hex].map(String.init) ?? "no")")
                        if arrived { XCTAssertEqual(trial.unit(unit.id)?.movesLeft, reach[hex]) }
                        checked += 1
                    }
                }
                _ = state.stewardTurn(for: state.player)
                _ = state.endWatch()
            }
        }
        XCTAssertGreaterThan(checked, 200)
    }

    func testNothingIsInReachWithoutMoves() throws {
        let state = GameState(settings: GameSettings(seedText: "spent", houseCount: 3, radius: 16, keepers: 1))
        var unit = try XCTUnwrap(state.units(of: state.player).first)
        XCTAssertFalse(state.reach(of: unit).isEmpty)
        unit.movesLeft = 0
        XCTAssertTrue(state.reach(of: unit).isEmpty)
    }
}

final class ExpansionAndFallTests: XCTestCase {
    func testEachNewHoldCostsMoreThanTheLast() throws {
        var state = GameState(settings: GameSettings(seedText: "dearer holds", houseCount: 3, radius: 16, keepers: 1))
        let base = state.trainingCost(of: .founder, for: state.player)
        XCTAssertEqual(base, UnitKind.founder.cost, "The first Founders cost their price")
        XCTAssertEqual(state.trainingCost(of: .spear, for: state.player), UnitKind.spear.cost, "Only Founders grow dearer")

        // A House with more holds pays more: play until the player's grows.
        for _ in 0..<80 where state.holds(of: state.player).count < 3 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        let holds = state.holds(of: state.player).count
        XCTAssertGreaterThan(holds, 1)
        XCTAssertGreaterThan(state.trainingCost(of: .founder, for: state.player).grain, base.grain)
    }

    /// A House can be destroyed outright.
    func testAHouseCanBeDestroyed() {
        // In one of a few worlds, played out, a House falls outright: the
        // first of them to see one is enough (32, as the rules now stand).
        var state = GameState(settings: GameSettings(seedText: "siege check 31", keepers: 1))
        var fallen: ChronicleEntry?
        for seed in 31..<41 where fallen == nil {
            state = GameState(settings: GameSettings(seedText: "siege check \(seed)", keepers: 1))
            while state.outcome == nil, state.watch < 170, fallen == nil {
                _ = state.stewardTurn(for: state.player)
                _ = state.endWatch()
                fallen = state.chronicle.first { $0.kind == .fall && $0.text.contains(" falls") }
            }
        }
        XCTAssertNotNil(fallen, "A House falls in one of these worlds")
        if let fallen, let loser = fallen.houses.first {
            XCTAssertTrue(state.houses[loser].isEliminated)
            XCTAssertTrue(state.holds(of: loser).isEmpty)
        }
    }

    /// A rival can win the lake by dominion, its vassals' holds counted
    /// with its own.
    func testARivalCanWinByDominion() throws {
        // In one of a few worlds, played out, a rival wins by dominion.
        var state = GameState(settings: GameSettings(seedText: "siege check 15", keepers: 1))
        for seed in 15..<35 {
            state = GameState(settings: GameSettings(seedText: "siege check \(seed)", keepers: 1))
            while state.outcome == nil, state.watch < 200 {
                _ = state.stewardTurn(for: state.player)
                _ = state.endWatch()
            }
            if let outcome = state.outcome, outcome.kind == .dominion, outcome.winner != state.player,
               state.houses.contains(where: { $0.liege == outcome.winner }) { break }
        }
        let outcome = try XCTUnwrap(state.outcome)
        XCTAssertEqual(outcome.kind, .dominion)
        XCTAssertNotEqual(outcome.winner, state.player)
        XCTAssertTrue(state.isSupreme(outcome.winner))
        XCTAssertGreaterThanOrEqual(state.realm(of: outcome.winner) * 100, state.holds.count * GameState.supremacyShare)
        let vassals = state.houses.filter { $0.liege == outcome.winner }
        XCTAssertFalse(vassals.isEmpty, "Beaten Houses bent the knee")
        XCTAssertTrue(state.chronicle.contains { $0.text.contains("swears fealty") })
    }

    /// A vassal can't turn on its liege; a liege that turns on its vassal frees it.
    func testFealtyBindsTheVassal() throws {
        var state = GameState(settings: GameSettings(seedText: "fealty", houseCount: 3, radius: 16, keepers: 1))
        let liege = 1, vassal = 2
        _ = try state.propose(.fealty, from: vassal, to: liege)
        XCTAssertEqual(state.houses[vassal].liege, liege)
        XCTAssertEqual(state.stance(vassal, liege), .pact)
        XCTAssertThrowsError(try state.declareWar(by: vassal, on: liege))
        _ = try state.declareWar(by: liege, on: vassal)
        XCTAssertNil(state.houses[vassal].liege, "Betrayed, the vassal is free")
    }
}

final class ConquestTests: XCTestCase {
    /// Stages a siege: `taker`'s spear beside `house`'s seat, at war, and
    /// strikes until the seat falls. Returns the events of the capture.
    private func takeSeat(of house: Int, by taker: Int, in state: inout GameState) throws -> [GameEvent] {
        let seat = try XCTUnwrap(state.seat(of: house))
        state.units.removeAll { $0.owner == house }
        let spot = try XCTUnwrap(seat.position.ring(1).first { hex in
            (state.map[hex]?.terrain.isPassable ?? false) && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: taker, near: spot))
        if state.stance(taker, house) != .war { _ = try state.declareWar(by: taker, on: house) }
        for _ in 0..<20 {
            let index = try XCTUnwrap(state.unitIndex(spear.id))
            state.units[index].movesLeft = UnitKind.spear.movement
            state.units[index].health = 100
            let events = try state.perform(.attack(unit: spear.id, target: seat.position), as: taker)
            if events.contains(where: { if case .holdCaptured = $0 { return true } else { return false } }) { return events }
        }
        XCTFail("The seat never fell")
        return []
    }

    /// Gives `house` a second hold far from its seat.
    private func addHold(for house: Int, in state: inout GameState) throws -> Int {
        let seat = try XCTUnwrap(state.seat(of: house))
        let site = try XCTUnwrap(state.map.hexes.first { hex in
            (state.map[hex]?.terrain.isSettleable ?? false) && hex.distance(to: seat.position) == 5
                && state.holds.allSatisfy { $0.position.distance(to: hex) >= 3 }
        })
        let id = 90_000 + state.holds.count
        state.holds.append(Hold(id: id, name: "Stillmarch", owner: house, position: site, isSeat: false, foundedWatch: state.watch))
        return id
    }

    func testTakingASeatCarriesOffHalfItsStoresAndBreaksTheHouse() throws {
        var state = GameState(settings: GameSettings(seedText: "spoils", houseCount: 3, radius: 18, keepers: 1))
        let rival = 1
        let heir = try addHold(for: rival, in: &state)
        let theirs = state.houses[rival].stock
        let mine = state.houses[state.player].stock

        let events = try takeSeat(of: rival, by: state.player, in: &state)

        XCTAssertEqual(state.houses[state.player].stock, mine + theirs.share(1, of: 2), "Half a seat's stores go to the taker")
        XCTAssertEqual(state.houses[rival].stock + theirs.share(1, of: 2), theirs)
        XCTAssertFalse(state.houses[rival].isEliminated)
        XCTAssertEqual(state.hold(heir)?.isSeat, true, "The seat moves")
        XCTAssertEqual(state.houses[rival].liege, state.player, "Broken, it bends the knee to its conqueror")
        XCTAssertEqual(state.stance(rival, state.player), .pact)
        XCTAssertTrue(events.contains(.stanceChanged(first: rival, second: state.player, stance: .pact, by: rival)))
        XCTAssertTrue(state.chronicle.contains { $0.text.contains("carries off its stores") })
        XCTAssertTrue(state.chronicle.contains { $0.text.contains("swears fealty") })
    }

    func testTakingAnOutlyingHoldCarriesOffItsShare() throws {
        var state = GameState(settings: GameSettings(seedText: "spoils", houseCount: 3, radius: 18, keepers: 1))
        let rival = 1
        let outlying = try addHold(for: rival, in: &state)
        let theirs = state.houses[rival].stock
        let mine = state.houses[state.player].stock
        let hold = try XCTUnwrap(state.hold(outlying))
        state.holds[state.holdIndex(outlying)!].ward = 0
        let spot = try XCTUnwrap(hold.position.ring(1).first { hex in
            (state.map[hex]?.terrain.isPassable ?? false) && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let spear = try XCTUnwrap(state.placeUnit(.spear, for: state.player, near: spot))
        _ = try state.declareWar(by: state.player, on: rival)
        _ = try state.perform(.attack(unit: spear.id, target: hold.position), as: state.player)

        XCTAssertEqual(state.hold(outlying)?.owner, state.player)
        XCTAssertEqual(state.houses[state.player].stock, mine + theirs.share(1, of: 2), "One of two holds: half the stores")
        XCTAssertNil(state.houses[rival].liege, "Losing an outlying hold breaks no one")
    }

    /// A company standing in a hold whose ward is down falls in close
    /// combat: a spear takes the hold with its victory; a bow, which can't
    /// hold ground, only clears it; and a ward still standing keeps the
    /// victors out.
    func testCloseCombatInAHoldWithItsWardDownTakesIt() throws {
        func scene(_ kind: UnitKind, ward: Int) throws -> (GameState, Hold, Int, [GameEvent]) {
            var state = GameState(settings: GameSettings(seedText: "close combat", houseCount: 3, radius: 18, keepers: 1))
            let rival = 1
            let seat = try XCTUnwrap(state.seat(of: rival))
            state.units.removeAll { $0.owner == rival }
            var garrison = NullmereCore.Unit(id: state.nextID, kind: .spear, owner: rival, position: seat.position)
            garrison.health = 1
            state.units.append(garrison)
            state.nextID += 1
            let index = try XCTUnwrap(state.holds.firstIndex { $0.id == seat.id })
            state.holds[index].ward = ward
            let spot = try XCTUnwrap(seat.position.ring(1).first { hex in
                (state.map[hex]?.terrain.isPassable ?? false) && state.unit(at: hex) == nil && state.hold(at: hex) == nil
            })
            let attacker = try XCTUnwrap(state.placeUnit(kind, for: 0, near: spot))
            XCTAssertEqual(attacker.position, spot)
            _ = try state.declareWar(by: 0, on: rival)
            let events = try state.perform(.attack(unit: attacker.id, target: seat.position), as: 0)
            XCTAssertNil(state.unit(garrison.id), "The garrison falls")
            return (state, seat, attacker.id, events)
        }
        func captured(_ events: [GameEvent]) -> Bool {
            events.contains { if case .holdCaptured = $0 { return true } else { return false } }
        }

        let (taken, seat, spear, won) = try scene(.spear, ward: 0)
        XCTAssertTrue(captured(won))
        XCTAssertEqual(taken.hold(seat.id)?.owner, 0)
        XCTAssertEqual(taken.unit(spear)?.position, seat.position, "The victors march in")

        let (cleared, _, bow, shot) = try scene(.bow, ward: 0)
        XCTAssertFalse(captured(shot), "A bow can't hold ground")
        XCTAssertEqual(cleared.hold(seat.id)?.owner, 1)
        XCTAssertNotEqual(cleared.unit(bow)?.position, seat.position)

        let (warded, _, held, kept) = try scene(.spear, ward: 30)
        XCTAssertFalse(captured(kept), "The ward still stands")
        XCTAssertEqual(warded.hold(seat.id)?.owner, 1)
        XCTAssertNotEqual(warded.unit(held)?.position, seat.position)
    }

    func testThePlayerNeverBendsTheKnee() throws {
        var state = GameState(settings: GameSettings(seedText: "spoils", houseCount: 3, radius: 18, keepers: 1))
        _ = try addHold(for: state.player, in: &state)
        _ = try takeSeat(of: state.player, by: 1, in: &state)
        XCTAssertNil(state.houses[state.player].liege)
        XCTAssertFalse(state.houses[state.player].isEliminated)
    }
}

