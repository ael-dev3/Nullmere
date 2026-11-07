import Foundation
import XCTest
@testable import NullmereCore

/// The works that hasten a House: the Wayhouse, each level of which sends
/// one more kind of its companies a step further every watch, and the
/// Masons' Lodge, each level of which raises its works sooner. A keeper's
/// alone: the stewards raise neither, so their worlds go as they always did.
final class HasteningWorksTests: XCTestCase {
    private func staged(_ seed: String) throws -> (state: GameState, me: Int, seat: Int) {
        var state = Scene.world(seed)
        let me = state.player
        let seat = try XCTUnwrap(state.holdIndex(try XCTUnwrap(state.seat(of: me)).id))
        state.houses[me].stock = Stock(grain: 9000, timber: 9000, stone: 9000, moonsalt: 900)
        return (state, me, seat)
    }

    /// Each level of the Wayhouse sends one more kind a step further: the
    /// Lanterns, then the Founders, the Spears, the Bows with the
    /// Mangonels, and the Riders; the highest Wayhouse among a House's
    /// holds counts.
    func testAWayhouseSendsTheHousesCompaniesAStepFurther() throws {
        var (state, me, seat) = try staged("the wayhouse")
        let order = UnitKind.allCases.sorted { BuildingKind.roadLevel(for: $0) < BuildingKind.roadLevel(for: $1) }
        XCTAssertEqual(order, [.lantern, .founder, .spear, .bow, .mangonel, .rider])
        XCTAssertEqual(UnitKind.allCases.map(BuildingKind.roadLevel(for:)).sorted(), [1, 2, 3, 4, 4, 5], "One kind a level, the engines with the bows")
        let before = UnitKind.allCases.map { state.bonus(.moves($0), for: me) }
        XCTAssertEqual(before, [0, 0, 0, 0, 0, 0])

        let events = try state.perform(.build(hold: state.holds[seat].id, kind: .wayhouse), as: me)
        XCTAssertEqual(events, [.buildingStarted(hold: state.holds[seat].id, kind: .wayhouse, level: 1)])
        for _ in 0..<BuildingKind.wayhouse.buildWatches(toLevel: 1) { _ = state.endWatch() }
        XCTAssertEqual(state.holds[seat].level(.wayhouse), 1)
        XCTAssertEqual(state.bonus(.moves(.lantern), for: me), 1)
        XCTAssertEqual(state.bonus(.moves(.spear), for: me), 0)
        let lanterns = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        XCTAssertEqual(state.movement(of: lanterns), UnitKind.lantern.movement + 1, "A step further every watch")

        for level in 2...5 {
            state.holds[seat].levels[.wayhouse] = level
            let hastened = UnitKind.allCases.filter { state.bonus(.moves($0), for: me) == 1 }
            XCTAssertEqual(hastened.count, level + (level >= 4 ? 1 : 0), "\(level) kinds at level \(level), the Mangonels with the Bows")
        }
        // The highest among the House's holds, none of another House's.
        state.holds[seat].levels[.wayhouse] = nil
        XCTAssertEqual(state.highest(.wayhouse, of: me), 0)
        let other = (me + 1) % state.houses.count
        let theirs = try XCTUnwrap(state.holdIndex(try XCTUnwrap(state.seat(of: other)).id))
        state.holds[theirs].levels[.wayhouse] = 5
        XCTAssertEqual(state.bonus(.moves(.rider), for: me), 0)
        XCTAssertEqual(state.bonus(.moves(.rider), for: other), 1)
        XCTAssertEqual(BuildingKind.wayhouse.effect(atLevel: 3), "Spears of the House a step further every watch")
        XCTAssertEqual(BuildingKind.wayhouse.title, "Wayhouse")
    }

    /// Each level of the Masons' Lodge raises every work of the House a
    /// sixteenth sooner, near enough: six in a hundred a level.
    func testAMasonsLodgeRaisesTheHousesWorksSooner() throws {
        var (state, me, seat) = try staged("the lodge")
        let plain = state.buildWatches(of: .moonspire, toLevel: 5, for: me)
        XCTAssertEqual(plain, GameState.hastened(BuildingKind.moonspire.buildWatches(toLevel: 5), by: state.bonus(.buildSpeed, for: me)))
        state.holds[seat].levels[.lodge] = 5
        XCTAssertEqual(state.bonus(.buildSpeed, for: me) - GameState.lodgePace * 5, Scene.world("the lodge").bonus(.buildSpeed, for: me))
        XCTAssertLessThan(state.buildWatches(of: .moonspire, toLevel: 5, for: me), plain, "Sooner")
        XCTAssertEqual(BuildingKind.lodge.effect(atLevel: 2), "Every work of the House 12% sooner")
        XCTAssertEqual(BuildingKind.lodge.title, "Masons' Lodge")
        XCTAssertGreaterThan(BuildingKind.lodge.cost(toLevel: 1).stone, BuildingKind.lodge.cost(toLevel: 1).timber)
        XCTAssertEqual(BuildingKind.lodge.maxLevel, 5)
        XCTAssertFalse(BuildingKind.lodge.requiresSeat)
        XCTAssertNil(BuildingKind.wayhouse.boostedResource)
    }

    /// A work begun keeps the watches it was to take: hastened by the
    /// Lodge it still begins from nothing, where it once began part risen,
    /// and its watches and its allies' help bring it on alike; a work begun
    /// before works kept their length is measured against the work's own.
    func testAWorkBegunKeepsTheWatchesItWasToTake() throws {
        var (state, me, seat) = try staged("a work's length")
        state.holds[seat].levels[.lodge] = 5
        state.holds[seat].project = nil
        _ = try state.perform(.build(hold: state.holds[seat].id, kind: .moonspire), as: me)
        var project = try XCTUnwrap(state.holds[seat].project)
        XCTAssertEqual(project.watches, state.buildWatches(of: .moonspire, toLevel: 1, for: me))
        XCTAssertEqual(project.watchesLeft, project.watches)
        XCTAssertLessThan(project.watchesLeft, BuildingKind.moonspire.buildWatches(toLevel: 1), "Hastened")
        XCTAssertEqual(project.progress, 0, "Begun, nothing risen yet")
        project.watchesLeft -= 1
        XCTAssertEqual(project.progress, 1 / Double(try XCTUnwrap(project.watches)), accuracy: 1e-12)

        // Begun before works kept their length: the work's own stands in.
        XCTAssertEqual(Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 1).progress,
                       1 - 1 / Double(BuildingKind.walls.buildWatches(toLevel: 1)), accuracy: 1e-12)
        XCTAssertEqual(Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 99).progress, 0, "Never below nothing")
        let older = try JSONDecoder().decode(Hold.Project.self, from: Data(#"{"kind":"walls","targetLevel":1,"watchesLeft":1}"#.utf8))
        XCTAssertNil(older.watches, "Older saves read as they were")
        let kept = try JSONDecoder().decode(Hold.Project.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(kept, project, "Its length kept with it")
    }

    /// The works are kept with the hold, and travel with the world.
    func testTheWorksAreKeptWithTheHold() throws {
        var (state, _, seat) = try staged("kept works")
        state.holds[seat].levels[.wayhouse] = 2
        state.holds[seat].levels[.lodge] = 4
        let kept = try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state))
        XCTAssertEqual(kept.holds[seat].level(.wayhouse), 2)
        XCTAssertEqual(kept.holds[seat].level(.lodge), 4)
    }

    /// Stewards raise neither, so a world of stewards goes as it always did.
    func testStewardsRaiseNeither() {
        var state = GameState(settings: GameSettings(seedText: "stewards build", houseCount: 6, radius: 20))
        for _ in 0..<60 { _ = state.endWatch() }
        XCTAssertGreaterThan(state.holds.reduce(0) { $0 + $1.levels.values.reduce(0, +) }, 30, "They built")
        XCTAssertTrue(state.holds.allSatisfy { $0.level(.wayhouse) == 0 && $0.level(.lodge) == 0 })
    }
}
