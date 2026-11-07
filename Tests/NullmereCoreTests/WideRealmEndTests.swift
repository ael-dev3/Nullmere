import Foundation
import XCTest
@testable import NullmereCore

/// How a wide realm's age ends: the Moonspire's stages take longer the more
/// seats a realm has, and allies' help takes four watches at most off any
/// work however great their alliance, so the quickest of a hundred Houses
/// doesn't end the age before its armies have grown; a realm of twelve
/// seats or fewer is as it was. A work begun keeps the watches it was to
/// take, and how far it has risen is counted against them.
final class WideRealmEndTests: XCTestCase {
    private static let wide = RealmState(name: "The Wide Nullmere", seed: "a wide realm's end", seats: 96, now: 0).world

    private static func lake() -> GameState {
        GameState(settings: GameSettings(seedText: "a lake of twelve", houseCount: 12, radius: 36, keepers: 1))
    }

    func testTheMoonspireTakesLongerOnAWiderLake() {
        XCTAssertEqual(GameState.moonspireSpan(seats: 6), 1)
        XCTAssertEqual(GameState.moonspireSpan(seats: 12), 1)
        XCTAssertEqual(GameState.moonspireSpan(seats: 48), 2)
        XCTAssertEqual(GameState.moonspireSpan(seats: 96), 8.0.squareRoot(), accuracy: 1e-12)
        XCTAssertEqual(GameState.moonspireSpan(seats: 1_024), (1_024.0 / 12).squareRoot(), accuracy: 1e-12)

        let small = WideRealmEndTests.lake()
        let wide = WideRealmEndTests.wide
        let (me, house) = (small.player, 40)
        for level in 1...BuildingKind.moonspire.maxLevel {
            let own = BuildingKind.moonspire.buildWatches(toLevel: level)
            XCTAssertEqual(small.buildWatches(of: .moonspire, toLevel: level, for: me),
                           GameState.hastened(own, by: small.bonus(.buildSpeed, for: me)), "Stage \(level) as ever on a lake of twelve")
            XCTAssertEqual(wide.buildWatches(of: .moonspire, toLevel: level, for: house),
                           GameState.hastened(Int((Double(own) * 8.0.squareRoot()).rounded()), by: wide.bonus(.buildSpeed, for: house)),
                           "Stage \(level) nearly thrice as long on a lake of ninety-six")
        }
        for kind in BuildingKind.allCases where kind != .moonspire {
            XCTAssertEqual(wide.buildWatches(of: kind, toLevel: 1, for: house),
                           GameState.hastened(kind.buildWatches(toLevel: 1), by: wide.bonus(.buildSpeed, for: house)), "\(kind) as long on any lake")
        }
    }

    /// Allies' help takes a watch off a work for every second ally that
    /// gives it, never its last, and four at most: an alliance of a third
    /// of ninety-six seats takes no more off one than eight allies would.
    func testAlliesTakeFourWatchesAtMostOffAWork() throws {
        var state = WideRealmEndTests.wide
        let me = 40
        let allies = Array(state.livingIDs.filter { $0 != me }.prefix(11))
        var accord = Alliance(id: 1, name: "the Wide Accord", leader: me, founded: state.watch)
        accord.members += allies
        state.alliances = [accord]
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].project = Hold.Project(kind: .moonspire, targetLevel: 1, watchesLeft: 17, watches: 17)
        var left: [Int] = []
        for ally in allies {
            _ = try state.perform(.help(house: me), as: ally)
            left.append(try XCTUnwrap(state.holds[seat].project).watchesLeft)
        }
        XCTAssertEqual(left, [17, 16, 16, 15, 15, 14, 14, 13, 13, 13, 13], "A watch for every second help, four at most")
        XCTAssertEqual(state.holds[seat].project?.helpers, allies, "Each ally helped it all the same")
        XCTAssertEqual(try XCTUnwrap(state.holds[seat].project).progress, 4.0 / 17, accuracy: 1e-12, "Brought on four watches of seventeen")
        XCTAssertEqual(GameState.mostWatchesHelped, 4)
    }

    /// A work begun keeps the watches it was to take: how far it has risen
    /// starts from nothing however hastened or long it is, and comes on
    /// with its watches and its allies' help alike; one begun before works
    /// kept their length is measured against the work's own, never below
    /// nothing.
    func testAWorkBegunKeepsTheWatchesItWasToTake() throws {
        let plenty = Stock(grain: 100_000, timber: 100_000, stone: 100_000, moonsalt: 100_000)
        var state = WideRealmEndTests.wide
        let me = 40
        let seat = try XCTUnwrap(state.holds.first { $0.owner == me && $0.isSeat }).id
        state.houses[me].stock = plenty
        state.houses[me].research.learn(.scaffolding, grade: 3)
        XCTAssertGreaterThan(state.bonus(.buildSpeed, for: me), 0, "Hastened")
        _ = try state.perform(.build(hold: seat, kind: .moonspire), as: me)
        var project = try XCTUnwrap(state.hold(seat)?.project)
        XCTAssertEqual(project.watches, state.buildWatches(of: .moonspire, toLevel: 1, for: me))
        XCTAssertEqual(project.watchesLeft, project.watches)
        XCTAssertGreaterThan(project.watchesLeft, BuildingKind.moonspire.buildWatches(toLevel: 1), "Longer than its own on a lake of ninety-six")
        XCTAssertEqual(project.progress, 0, "Begun, nothing risen yet")
        project.watchesLeft -= 3
        XCTAssertEqual(project.progress, 3 / Double(try XCTUnwrap(project.watches)), accuracy: 1e-12)

        // Hastened on a lake of twelve, where it once began part risen.
        var small = WideRealmEndTests.lake()
        let keeper = small.player
        let home = try XCTUnwrap(small.holds.first { $0.owner == keeper && $0.isSeat }).id
        small.houses[keeper].stock = plenty
        small.houses[keeper].research.learn(.scaffolding, grade: 3)
        _ = try small.perform(.build(hold: home, kind: .moonspire), as: keeper)
        let begun = try XCTUnwrap(small.hold(home)?.project)
        XCTAssertLessThan(begun.watchesLeft, BuildingKind.moonspire.buildWatches(toLevel: 1), "Hastened")
        XCTAssertEqual(begun.progress, 0)

        // Begun before works kept their length: the work's own stands in.
        XCTAssertEqual(Hold.Project(kind: .moonspire, targetLevel: 1, watchesLeft: 17).progress, 0, "Never below nothing")
        let own = BuildingKind.walls.buildWatches(toLevel: 1)
        XCTAssertEqual(Hold.Project(kind: .walls, targetLevel: 1, watchesLeft: 1).progress, 1 - 1 / Double(own), accuracy: 1e-12)
        let older = try JSONDecoder().decode(Hold.Project.self, from: Data(#"{"kind":"walls","targetLevel":1,"watchesLeft":1}"#.utf8))
        XCTAssertNil(older.watches, "Older saves read as they were")
        let kept = try JSONDecoder().decode(Hold.Project.self, from: JSONEncoder().encode(project))
        XCTAssertEqual(kept, project, "Its length kept with it")
    }
}
