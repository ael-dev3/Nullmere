import XCTest
@testable import NullmereCore

/// The world's own checks on itself, each wrong a world can go, and the
/// names, effects and geometry the rules give the interface.
final class SoundnessTests: XCTestCase {
    private let world = GameState(settings: GameSettings(seedText: "sound or not", houseCount: 4, radius: 16))

    private func assertFinds(_ expected: String, _ wrong: (inout GameState) -> Void, file: StaticString = #filePath, line: UInt = #line) {
        var state = world
        wrong(&state)
        let problems = state.problems()
        XCTAssertTrue(problems.contains { $0.contains(expected) }, "Expected \"\(expected)\" in \(problems)", file: file, line: line)
    }

    func testASoundWorldAnswersNothing() {
        XCTAssertEqual(world.problems(), [])
    }

    func testEachWrongIsFound() {
        let seat = world.holds[0]
        let unit = world.units[0]
        let water = world.map.hexes.first { !(world.map[$0]?.terrain.isPassable ?? true) }!
        assertFinds("has id 7 at 1") { $0.houses[1] = House(id: 7, name: "Stray", sigil: 1, isPlayer: false, temperament: $0.houses[1].temperament, tileCount: $0.map.count) }
        assertFinds("has explored 3 of") { $0.houses[0].explored = [true, false, true] }
        assertFinds("-5 Grain") { $0.houses[0].stock.grain = -5 }
        assertFinds("is sworn to 0") { $0.houses[0].liege = 0 }
        assertFinds("Two companies share id \(unit.id)") { $0.units.append(unit) }
        assertFinds("belongs to no House (99)") { $0.units[0].owner = 99 }
        assertFinds("still stands") { state in state.houses[unit.owner].isEliminated = true }
        assertFinds("stands outside the world") { $0.units[0].position = Hex(999, 0) }
        assertFinds("stands on") { $0.units[0].position = water }
        assertFinds("has 0 health") { $0.units[0].health = 0 }
        assertFinds("has -1 moves") { $0.units[0].movesLeft = -1 }
        assertFinds("Two holds share id \(seat.id)") { state in
            let elsewhere = state.map.hexes.first { hex in state.hold(at: hex) == nil && state.map[hex]?.terrain.isSettleable == true }!
            state.holds.append(Hold(id: seat.id, name: "Echo", owner: seat.owner, position: elsewhere, isSeat: false, foundedWatch: 1))
        }
        assertFinds("Two holds stand at") { state in
            state.holds.append(Hold(id: state.nextID, name: "Echo", owner: seat.owner, position: seat.position, isSeat: false, foundedWatch: 1))
            state.nextID += 1
        }
        assertFinds("belongs to no House (42)") { $0.holds[0].owner = 42 }
        assertFinds("stands on ground no hold can") { state in
            state.holds.append(Hold(id: state.nextID, name: "Drowned", owner: seat.owner, position: water, isSeat: false, foundedWatch: 1))
            state.nextID += 1
        }
        assertFinds("has ward 9999") { $0.holds[0].ward = 9999 }
        assertFinds("at level 99") { $0.holds[0].levels[.walls] = 99 }
        assertFinds("A company and a hold share an id") { state in
            var twin = state.units[0]
            twin = NullmereCore.Unit(id: seat.id, kind: twin.kind, owner: twin.owner, position: twin.position)
            state.units[0] = twin
        }
        assertFinds("was given out before the next id") { $0.nextID = 1 }
        assertFinds("Envoy 1234 runs from") { $0.envoys.append(Envoy(id: 1234, from: 1, to: 1, proposal: .peace, arrived: 1)) }
        assertFinds("Two Houses have more than one standing") { $0.relations.append($0.relations[0]) }
        assertFinds("A standing between 2 and 2") { $0.relations.append(Relation(first: 2, second: 2)) }
    }
}

final class RuleNamesTests: XCTestCase {
    func testEveryBuildingIsNamedAndSaysWhatEachLevelDoes() {
        let titles = BuildingKind.allCases.map(\.title)
        XCTAssertEqual(Set(titles).count, titles.count, "Each its own name")
        for kind in BuildingKind.allCases {
            for level in 1...kind.maxLevel {
                XCTAssertFalse(kind.effect(atLevel: level).isEmpty, "\(kind) at \(level)")
            }
        }
        XCTAssertEqual(BuildingKind.moonspire.effect(atLevel: BuildingKind.moonspire.maxLevel), "Ascendancy over the lake")
        XCTAssertEqual(BuildingKind.moonspire.effect(atLevel: 3), "Stage 3 of 5")
        XCTAssertEqual(BuildingKind.granary.effect(atLevel: 1), "+\(BuildingKind.yieldBoostPerLevel)% to the grain this hold yields")
        XCTAssertTrue(BuildingKind.walls.effect(atLevel: 1).hasPrefix("Ward "))
        XCTAssertEqual(BuildingKind.musterHall.effect(atLevel: 1), "Trains Spears")
        XCTAssertEqual(BuildingKind.musterHall.effect(atLevel: 2), "Trains Bows")
        XCTAssertEqual(BuildingKind.musterHall.effect(atLevel: 3), "Trains Riders; all but Lanterns a watch sooner")
    }

    /// A Beacon's line says what its level does: sight at every level, and
    /// a tile more of land only where the land truly grows.
    func testABeaconSaysWhereItsLandGrows() {
        for isSeat in [false, true] {
            for level in 1...BuildingKind.beacon.maxLevel {
                let line = BuildingKind.beacon.effect(atLevel: level, isSeat: isSeat)
                XCTAssertTrue(line.hasPrefix("Sight \(Hold.sight(beaconLevel: level))"), line)
                let grows = Hold.territoryRadius(isSeat: isSeat, beaconLevel: level) > Hold.territoryRadius(isSeat: isSeat, beaconLevel: level - 1)
                XCTAssertEqual(line.contains("its land reaches a tile further"), grows, "Level \(level): \(line)")
            }
        }
        XCTAssertEqual(BuildingKind.beacon.effect(atLevel: 2), "Sight 4; its land reaches a tile further")
        XCTAssertEqual(BuildingKind.beacon.effect(atLevel: 3), "Sight 5")
    }

    /// The watches a company takes, as the panel shows them, are the
    /// watches the rules give it: one fewer at a Muster Hall III, but never
    /// for Lanterns, which take one already.
    func testTrainingTakesTheWatchesItSays() throws {
        for musterHall in 0...BuildingKind.musterHall.maxLevel {
            for kind in UnitKind.allCases where kind.requiredMuster <= musterHall {
                var state = GameState(settings: GameSettings(seedText: "training watches"))
                let me = state.player
                let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
                state.holds[seat].levels[.musterHall] = musterHall
                state.houses[me].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 900)
                let hold = state.holds[seat]
                _ = try state.perform(.train(hold: hold.id, kind: kind), as: me)
                XCTAssertEqual(state.holds[seat].training?.watchesLeft, hold.trainingWatches(for: kind), "\(kind) at Muster Hall \(musterHall)")
                let faster = musterHall >= 3 && kind != .lantern
                XCTAssertEqual(hold.trainingWatches(for: kind), kind.trainWatches - (faster ? 1 : 0), "\(kind) at Muster Hall \(musterHall)")
            }
        }
    }

    func testLevelsAreWrittenInNumerals() {
        XCTAssertEqual((1...5).map(BuildingKind.numeral), ["I", "II", "III", "IV", "V"])
        XCTAssertEqual(RuleError.needsMusterHall(2).description, "Needs a Muster Hall II.")
    }

    /// One cause, one refusal: a sentence never borrowed for another.
    func testEachRefusalSaysItsOwnCause() {
        XCTAssertEqual(RuleError.alreadyStance(.pact).description, "Already in a pact.")
        XCTAssertEqual(RuleError.alreadyStance(.war).description, "Already at war.")
        XCTAssertEqual(RuleError.alreadyStance(.peace).description, "Already at peace.")
        let texts = [RuleError.invalidAmount, .sameStore, .storageFull, .noRoomWithThem, .atWarWith(1), .noTradeAcrossWar(1)].map(\.description)
        XCTAssertEqual(Set(texts).count, texts.count, "\(texts)")
        XCTAssertEqual(RuleError.gameOver.description, "The age is over.")
    }

    func testStancesAndProposalsAreNamed() {
        XCTAssertEqual([Stance.war, .peace, .pact].map(\.title), ["War", "Peace", "Pact"])
        XCTAssertEqual(Proposal.allCases.map(\.title), ["Peace", "Pact", "Fealty", "Tribute", "Trade"])
        XCTAssertEqual(Proposal.allCases.map(\.offered), ["peace", "a pact", "fealty", "tribute", "trade"])
        XCTAssertEqual([Stance.war, .peace, .pact].map(\.standing), ["at war", "at peace", "in a pact"])
        let relation = Relation(first: 1, second: 3)
        XCTAssertEqual(relation.other(than: 1), 3)
        XCTAssertEqual(relation.other(than: 3), 1)
    }

    func testHexArithmeticAndCorners() {
        let a = Hex(2, -1), b = Hex(-1, 3)
        XCTAssertEqual(a.s, -1)
        XCTAssertEqual(a + b, Hex(1, 2))
        XCTAssertEqual(a - b, Hex(3, -4))
        XCTAssertEqual(a * 3, Hex(6, -3))
        XCTAssertTrue(a < b, "Ordered by row, then column")
        XCTAssertEqual(a.description, "(2, -1)")
        XCTAssertEqual(Hex.origin, Hex(0, 0))
        let layout = HexLayout(size: 2)
        let centre = layout.center(of: a)
        let corners = layout.corners(of: a)
        XCTAssertEqual(corners.count, 6)
        for corner in corners {
            XCTAssertEqual(hypot(corner.x - centre.x, corner.y - centre.y), 2, accuracy: 1e-9, "Each corner a size from the centre")
        }
    }
}

/// Watches at the edges of the rules: companies starving, a House left
/// alone on the lake, and a march halted.
final class WatchEdgeTests: XCTestCase {
    func testStarvingCompaniesWeakenAndFall() throws {
        var state = GameState(settings: GameSettings(seedText: "a hungry watch", houseCount: 3, radius: 16))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        // More spears than the land can feed, worn already, and no grain in store.
        for _ in 0..<40 {
            var spear = NullmereCore.Unit(id: state.nextID, kind: .spear, owner: me, position: seat.position)
            spear.health = 15
            state.units.append(spear)
            state.nextID += 1
        }
        state.houses[me].stock.grain = 0
        var starved = false, lost = false
        for _ in 0..<8 where !lost {
            let events = state.endWatch()
            starved = starved || events.contains { if case .starving(house: me) = $0 { return true } else { return false } }
            lost = events.contains { if case .unitLost(_, _, let owner, _) = $0 { return owner == me } else { return false } }
        }
        XCTAssertTrue(starved, "The grain runs out")
        XCTAssertTrue(lost, "and a company with nothing to eat falls in the end")
    }

    func testAHouseLeftAloneHoldsTheLake() {
        var state = GameState(settings: GameSettings(seedText: "alone on the shore", houseCount: 3, radius: 16))
        for index in state.houses.indices where index != state.player {
            state.houses[index].isEliminated = true
            state.units.removeAll { $0.owner == index }
            state.holds.removeAll { $0.owner == index }
        }
        let events = state.endWatch()
        XCTAssertTrue(events.contains { if case .gameEnded = $0 { return true } else { return false } })
        XCTAssertEqual(state.outcome?.kind, .dominion)
        XCTAssertEqual(state.outcome?.winner, state.player)
    }

    func testAMarchOnAHeldHexWaitsBesideIt() throws {
        var state = GameState(settings: GameSettings(seedText: "a held hex", houseCount: 3, radius: 16))
        let me = state.player
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        let target = try XCTUnwrap(state.map.hexes.first { hex in
            (3...4).contains(hex.distance(to: lantern.position)) && state.unit(at: hex) == nil && state.hold(at: hex) == nil
                && state.map[hex]?.terrain.isPassable == true && state.path(for: lantern, to: hex) != nil
        })
        // Another company already stands where the lantern is bound.
        state.units.append(NullmereCore.Unit(id: state.nextID, kind: .spear, owner: me, position: target))
        state.nextID += 1
        for _ in 0..<4 {
            _ = try? state.perform(.move(unit: lantern.id, to: target), as: me)
            _ = state.endWatch()
        }
        let moved = try XCTUnwrap(state.unit(lantern.id))
        XCTAssertNotEqual(moved.position, target, "It never steps onto a held hex")
        XCTAssertEqual(moved.position.distance(to: target), 1, "It waits beside it")
    }

    func testAMarchIsHalted() throws {
        var state = GameState(settings: GameSettings(seedText: "a halted march", houseCount: 3, radius: 16))
        let me = state.player
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        let far = try XCTUnwrap(state.map.hexes.first { hex in
            hex.distance(to: lantern.position) >= 8 && state.path(for: lantern, to: hex) != nil
        })
        _ = try state.perform(.move(unit: lantern.id, to: far), as: me)
        XCTAssertNotNil(state.unit(lantern.id)?.destination, "Marching on")
        _ = try state.perform(.halt(unit: lantern.id), as: me)
        XCTAssertNil(state.unit(lantern.id)?.destination, "Halted")
    }
}
