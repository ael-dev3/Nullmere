import Foundation
import XCTest
@testable import NullmereCore

/// A keeper's favour with the lake: earned each watch they keep, the more
/// for each kept unbroken, carried across ages; it raises their House by
/// levels and brings it a chest every tenth watch kept unbroken.
final class FavourTests: XCTestCase {
    private func realm() -> RealmState {
        RealmState(name: "The Nullmere", seed: "favour test", seats: 4, radius: 18, watchLength: 60, now: 0)
    }

    func testFavourStandsAtLevelsAndGivesItsPerks() {
        XCTAssertEqual(Favour.level(of: 0), 0)
        XCTAssertEqual(Favour.level(of: 59), 0)
        XCTAssertEqual(Favour.level(of: 60), 1)
        XCTAssertEqual(Favour.level(of: 399), 2)
        XCTAssertEqual(Favour.level(of: 9_000), 10)
        XCTAssertEqual(Favour.level(of: 1_000_000), Favour.highest)
        XCTAssertEqual(Favour.next(after: 0), 60)
        XCTAssertEqual(Favour.next(after: 60), 180)
        XCTAssertNil(Favour.next(after: 9_000), "None past the tenth")
        XCTAssertEqual(Favour.earned(streak: 0), 10)
        XCTAssertEqual(Favour.earned(streak: 3), 16)
        XCTAssertEqual(Favour.earned(streak: 50), 30, "The streak counts ten watches at most")
        XCTAssertEqual(Favour.earned(streak: -4), 10)
        XCTAssertEqual(Favour.bonus(.gathering, level: 3), 6)
        XCTAssertEqual(Favour.bonus(.buildSpeed, level: 3), 6)
        XCTAssertEqual(Favour.bonus(.studySpeed, level: 3), 6)
        XCTAssertEqual(Favour.bonus(.trainingSpeed, level: 3), 3)
        XCTAssertEqual(Favour.bonus(.storage, level: 3), 0)
        XCTAssertEqual(Favour.effect(level: 0), "nothing yet")
        XCTAssertEqual(Favour.effect(level: 4), "8% more gathered, works and studies 8% sooner, companies mustered 4% sooner")
        XCTAssertTrue(Favour.chest(level: 0).isEmpty)
        XCTAssertEqual(Favour.chest(level: 1).map(\.kind), [.hourglass])
        XCTAssertEqual(Favour.chest(level: 4).map(\.kind), [.hourglass, .grainCache, .timberCache])
        XCTAssertEqual(Favour.chest(level: 7).map(\.kind), [.hourglass, .grainCache, .timberCache, .stoneCache, .mendingDraught])
        XCTAssertEqual(Favour.chest(level: 10).map(\.kind),
                       [.hourglass, .grainCache, .timberCache, .stoneCache, .mendingDraught, .wardStone, .moonsaltCache])
        XCTAssertTrue(Favour.chest(level: 10).allSatisfy { $0.count == 1 })
    }

    func testKeepersThereAsTheWatchTurnsKeepItAndRiseInFavour() throws {
        var realm = realm()
        let ilsen = try realm.arrive("id-ilsen", name: "Ilsen", now: 1)
        let mara = try realm.arrive("id-mara", name: "Mara", now: 1)
        let house = try XCTUnwrap(ilsen.house), other = try XCTUnwrap(mara.house)
        XCTAssertNil(realm.world.houses[house].favour, "None at first")
        // Mara goes; Ilsen stays and keeps the watches.
        realm.depart("id-mara", now: 2)
        var events: [GameEvent] = []
        var now = 2.0
        for _ in 0..<5 {
            now += 61
            events += try XCTUnwrap(realm.tick(now: now))
        }
        // 10 + 12 + 14 + 16 + 18: the first level at the fifth.
        XCTAssertEqual(realm.keeper("id-ilsen")?.favour, 70)
        XCTAssertEqual(realm.keeper("id-ilsen")?.streak, 5)
        XCTAssertNil(realm.keeper("id-mara")?.favour, "Away, none")
        XCTAssertNil(realm.keeper("id-mara")?.streak)
        XCTAssertEqual(realm.world.favour(of: house), 1)
        XCTAssertEqual(realm.world.favour(of: other), 0)
        XCTAssertEqual(events.filter { if case .favourRose = $0 { return true } else { return false } }, [.favourRose(house: house, level: 1)])
        let rose = GameEvent.favourRose(house: house, level: 1)
        XCTAssertEqual(realm.world.tidings(of: rose, for: house)?.text,
                       "Your favour with the lake rises to I: 2% more gathered, works and studies 2% sooner, companies mustered 1% sooner.")
        XCTAssertNil(realm.world.tidings(of: rose, for: other))
        XCTAssertEqual(realm.world.events([rose], heardBy: house), [rose])
        XCTAssertEqual(realm.world.events([rose], heardBy: other), [])
        // Its perks in the rules: more gathered, works, studies and musters sooner.
        var plain = realm.world
        plain.houses[house].favour = nil
        for (bonus, more) in [(Bonus.gathering, 2), (.buildSpeed, 2), (.studySpeed, 2), (.trainingSpeed, 1), (.storage, 0)] {
            XCTAssertEqual(realm.world.bonus(bonus, for: house) - plain.bonus(bonus, for: house), more, "\(bonus)")
        }
        // Seen in every view, as its House's standing.
        XCTAssertEqual(realm.world.view(for: other).houses[house].favour, 1)
        let kept = try JSONDecoder().decode(GameState.self, from: try JSONEncoder().encode(realm.world))
        XCTAssertEqual(kept.houses[house].favour, 1)

        // Away as a watch turns, the streak is broken; back, it begins again.
        realm.depart("id-ilsen", now: now)
        _ = try realm.arrive("id-mara", name: nil, now: now)
        now += 61
        _ = try XCTUnwrap(realm.tick(now: now))
        XCTAssertNil(realm.keeper("id-ilsen")?.streak)
        XCTAssertEqual(realm.keeper("id-ilsen")?.favour, 70, "Nothing earned away")
        XCTAssertEqual(realm.keeper("id-mara")?.favour, 10)
        XCTAssertEqual(realm.world.favour(of: house), 1, "What was won is kept")
    }

    func testEveryTenthWatchKeptUnbrokenBringsAChest() throws {
        var realm = realm()
        let ilsen = try realm.arrive("id-ilsen", name: "Ilsen", now: 1)
        let house = try XCTUnwrap(ilsen.house)
        var events: [GameEvent] = []
        var now = 1.0
        for _ in 0..<Favour.chestEvery {
            now += 61
            events += try XCTUnwrap(realm.tick(now: now))
        }
        let given = events.compactMap { event -> ItemKind? in
            if case .itemsGiven(house, let kind, _) = event { return kind }
            return nil
        }
        XCTAssertEqual(given.filter { $0 == .hourglass }.count, 1, "\(given)")
        XCTAssertEqual(realm.world.favour(of: house), 2, "10 + 12 + ... + 28 = 190")
        XCTAssertGreaterThanOrEqual(realm.world.items(.hourglass, of: house), 1)
        // The next chest at the twentieth.
        events = []
        for _ in 0..<(Favour.chestEvery - 1) {
            now += 61
            events += try XCTUnwrap(realm.tick(now: now))
        }
        XCTAssertFalse(events.contains { if case .itemsGiven(house, .hourglass, _) = $0 { return true } else { return false } })
    }

    func testAKeepersFavourTakesItsSeatWithThemInANewAge() throws {
        var realm = realm()
        _ = try realm.arrive("id-ilsen", name: "Ilsen", now: 1)
        let index = try XCTUnwrap(realm.keepers.firstIndex { $0.id == "id-ilsen" })
        realm.keepers[index].favour = 2_100
        realm.keepers[index].house = nil
        let house = try XCTUnwrap(realm.world.houses.firstIndex { $0.isPlayer })
        realm.world.houses[house].isPlayer = false
        _ = try realm.arrive("id-ilsen", name: nil, now: 2)
        let seat = try XCTUnwrap(realm.keeper("id-ilsen")?.house)
        XCTAssertEqual(realm.world.favour(of: seat), 6, "As high as their favour, from the first")
        // A House fallen stands in no favour.
        var fallen = realm.world
        fallen.houses[seat].isEliminated = true
        XCTAssertEqual(fallen.standInFavour(seat, level: 7, chest: true), [])
        XCTAssertEqual(fallen.standInFavour(99, level: 7, chest: true), [])
        // Its level falls to none only if its keeper's does.
        var steward = realm.world
        XCTAssertEqual(steward.standInFavour(seat, level: 0, chest: false), [])
        XCTAssertNil(steward.houses[seat].favour)
        XCTAssertEqual(steward.favour(of: 99), 0)
    }
}
