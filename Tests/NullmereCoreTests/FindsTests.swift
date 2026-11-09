import XCTest
@testable import NullmereCore

/// The hamlets and barrows the mist hides (Rise of Kingdoms' tribal
/// villages and caves): found as the world is made, apart from its other
/// draws; known to a House once it has seen their ground; sought once by
/// each House's Lanterns, on or beside them, for a hamlet's gift and the
/// land about it, or a barrow's grave goods.
final class FindsTests: XCTestCase {
    private func world(_ seed: String = "found in the mist") -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
    }

    func testTheLandHoldsHamletsAndBarrowsAwayFromEveryHoldAndEachOther() throws {
        let state = world()
        let finds = state.findsInLand
        let hamlets = finds.filter { $0.kind == .hamlet }, barrows = finds.filter { $0.kind == .barrow }
        XCTAssertEqual(hamlets.count, 6, "three for every two seats")
        XCTAssertGreaterThanOrEqual(barrows.count, 2)
        XCTAssertLessThanOrEqual(barrows.count, 4, "one for each seat at most")
        XCTAssertEqual(finds.map(\.id), Array(1...finds.count), "numbered apart, from one")
        XCTAssertEqual(Set(finds.map(\.name)).count, finds.count, "each its own name")
        for find in finds {
            let tile = try XCTUnwrap(state.map[find.position])
            XCTAssertTrue(tile.terrain.isPassable && !tile.terrain.isWater)
            XCTAssertNil(tile.feature)
            XCTAssertTrue(state.holds.allSatisfy { $0.position.distance(to: find.position) >= GameState.findsFromHolds }, find.name)
            XCTAssertTrue(finds.allSatisfy { $0.id == find.id || $0.position.distance(to: find.position) >= GameState.findsApart })
            XCTAssertNil(state.lair(at: find.position))
            XCTAssertNil(state.shrine(at: find.position))
            XCTAssertNil(state.unit(at: find.position))
            if find.kind == .barrow { XCTAssertEqual(tile.terrain, .barrow, "a barrow on the barrows' ground") }
            XCTAssertEqual(state.find(at: find.position), find)
            XCTAssertEqual(state.find(find.id), find)
        }
        XCTAssertTrue(hamlets.allSatisfy { $0.named.hasPrefix("the hamlet of ") })
        XCTAssertTrue(barrows.allSatisfy { $0.named.hasPrefix("the ") })
        // The same world finds them the same; the rest of the world is as it
        // was, its other draws and numbers untouched.
        XCTAssertEqual(world().findsInLand, finds)
        var without = world()
        without.finds = nil
        var again = without
        again.raiseFinds()
        XCTAssertEqual(again.findsInLand, finds)
        without.finds = finds
        XCTAssertEqual(without, state)
        XCTAssertEqual(state.problems(), [])
        // Wider realms hold more of them.
        let wide = GameState(settings: GameSettings(seedText: "found in the mist", houseCount: 12, radius: 30, keepers: 1))
        XCTAssertEqual(wide.findsInLand.filter { $0.kind == .hamlet }.count, 18)
    }

    /// A House's Lanterns beside a hamlet its House knows of.
    private func lanternBeside(_ kind: Find.Kind, in state: inout GameState, for house: Int) throws -> (lantern: NullmereCore.Unit, find: Find) {
        let lantern = try XCTUnwrap(state.units(of: house).first { $0.kind == .lantern })
        let find = try XCTUnwrap(state.findsInLand.first { find in
            find.kind == kind && find.position.neighbors.contains { hex in
                state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil
            }
        })
        let beside = try XCTUnwrap(find.position.neighbors.first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil
        })
        state.units[try XCTUnwrap(state.unitIndex(lantern.id))].position = beside
        state.refreshSight()
        return (try XCTUnwrap(state.unit(lantern.id)), find)
    }

    func testLanternsSeekAHamletOnceForItsGiftAndTheLandAboutIt() throws {
        var state = world()
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        let unseen = try XCTUnwrap(state.findsInLand.first { !state.isExplored($0.position, by: me) })
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        XCTAssertEqual(state.seekRefusal(spear.id, find: unseen.id, as: me), .notAScout)
        let (lantern, hamlet) = try lanternBeside(.hamlet, in: &state, for: me)
        XCTAssertTrue(state.isExplored(hamlet.position, by: me), "seen from beside it")
        XCTAssertEqual(state.seekRefusal(lantern.id, find: hamlet.id, as: other), .notYours)
        XCTAssertEqual(state.seekRefusal(lantern.id, find: 999, as: me), .unknownFind)
        XCTAssertEqual(state.findsKnown(by: me, near: lantern.position).first, hamlet)
        if unseen.id != hamlet.id, !state.isExplored(unseen.position, by: me) {
            XCTAssertEqual(state.seekRefusal(lantern.id, find: unseen.id, as: me), .unknownFind, "ground it hasn't seen")
        }
        // The gift: of what its ground grows, and the same however asked.
        let gift = state.gift(of: hamlet, to: me)
        XCTAssertEqual(gift, state.gift(of: hamlet, to: me))
        XCTAssertGreaterThan(gift.grain + gift.timber + gift.stone, 50)
        XCTAssertNil(state.graveGoods(of: hamlet, for: me))
        let before = state.houses[me].stock
        let unknown = hamlet.position.spiral(GameState.hamletTells).filter { !state.isExplored($0, by: me) }
        let events = try state.perform(.seek(unit: lantern.id, find: hamlet.id), as: me)
        XCTAssertEqual(events, [.findSought(find: hamlet.id, by: me, gift: gift, item: nil)])
        for resource in Resource.allCases {
            XCTAssertEqual(state.houses[me].stock[resource], min(before[resource] + gift[resource], state.storage(of: me)), "\(resource)")
        }
        XCTAssertTrue(unknown.allSatisfy { state.isExplored($0, by: me) }, "its folk tell of the land about it")
        XCTAssertTrue(state.hasSought(hamlet.id, by: me))
        XCTAssertEqual(state.unit(lantern.id)?.movesLeft, 0, "for all their moves")
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me))
        XCTAssertTrue(told.text.hasPrefix("Your Lanterns come to \(hamlet.named)"), told.text)
        XCTAssertTrue(told.text.contains("its folk give you \(gift)"), told.text)
        XCTAssertEqual(told.tone, .good)
        XCTAssertNil(state.tidings(of: events[0], for: other), "no other House is told")
        XCTAssertFalse(state.view(for: other).hasSought(hamlet.id, by: me))
        XCTAssertEqual(state.events(events, heardBy: other), [])
        XCTAssertEqual(state.events(events, heardBy: me), events)
        // Once: the next watch it may not seek it again.
        _ = state.endWatch()
        XCTAssertEqual(state.seekRefusal(lantern.id, find: hamlet.id, as: me), .soughtAlready)
        XCTAssertThrowsError(try state.perform(.seek(unit: lantern.id, find: hamlet.id), as: me))
        // Another House's Lanterns seek it for a gift of their own.
        var theirs = state
        let (otherLantern, _) = try lanternNear(hamlet, in: &theirs, for: other)
        let given = try theirs.perform(.seek(unit: otherLantern.id, find: hamlet.id), as: other)
        XCTAssertEqual(given, [.findSought(find: hamlet.id, by: other, gift: theirs.gift(of: hamlet, to: other), item: nil)])
        XCTAssertEqual(theirs.problems(), [])
    }

    private func lanternNear(_ find: Find, in state: inout GameState, for house: Int) throws -> (lantern: NullmereCore.Unit, find: Find) {
        let lantern = try XCTUnwrap(state.units(of: house).first { $0.kind == .lantern })
        let beside = try XCTUnwrap(([find.position] + find.position.neighbors).first { hex in
            state.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && state.unit(at: hex) == nil
        })
        state.units[try XCTUnwrap(state.unitIndex(lantern.id))].position = beside
        state.refreshSight()
        return (try XCTUnwrap(state.unit(lantern.id)), find)
    }

    func testLanternsBringUpABarrowsGraveGoodsAndNoneFarOffOrSpent() throws {
        var state = world("the old graves")
        let me = state.player
        let (lantern, barrow) = try lanternBeside(.barrow, in: &state, for: me)
        let goods = try XCTUnwrap(state.graveGoods(of: barrow, for: me))
        XCTAssertEqual(state.gift(of: barrow, to: me), .zero)
        // Out of reach, or spent, it can't.
        var far = state
        let away = try XCTUnwrap(far.map.hexes.first { hex in
            hex.distance(to: barrow.position) > GameState.seekReach + 1 && far.map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true
                && far.unit(at: hex) == nil
        })
        far.units[try XCTUnwrap(far.unitIndex(lantern.id))].position = away
        XCTAssertEqual(far.seekRefusal(lantern.id, find: barrow.id, as: me), .outOfReach)
        var spent = state
        spent.units[try XCTUnwrap(spent.unitIndex(lantern.id))].movesLeft = 0
        XCTAssertEqual(spent.seekRefusal(lantern.id, find: barrow.id, as: me), .noMovesLeft)
        let held = state.items(goods, of: me)
        let events = try state.perform(.seek(unit: lantern.id, find: barrow.id), as: me)
        XCTAssertEqual(events.first, .findSought(find: barrow.id, by: me, gift: .zero, item: goods))
        XCTAssertTrue(events.contains(.itemsGiven(house: me, kind: goods, count: 1)))
        XCTAssertEqual(state.items(goods, of: me), held + 1)
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.hasPrefix("Your Lanterns go down into \(barrow.named)"), told)
        XCTAssertTrue(told.hasSuffix("bring up \(goods.counted(1)) from among the old bones."), told)
        // Grave goods of every kind lie in the barrows of the realm.
        let kinds = Set((1...60).compactMap { id in state.graveGoods(of: Find(id: id, kind: .barrow, position: barrow.position, name: "x"), for: me) })
        XCTAssertTrue(kinds.isSuperset(of: [.hourglass, .wardStone, .mendingDraught]), "\(kinds)")
    }

    func testAHoldRaisedOverAFindTakesItAndViewsShowOnlyWhatTheirHouseHasSeen() throws {
        var state = world()
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        let (_, hamlet) = try lanternBeside(.hamlet, in: &state, for: me)
        // What a House's view holds: the finds on ground it has seen.
        let view = state.view(for: me)
        XCTAssertEqual(view.findsInLand, state.findsInLand.filter { state.isExplored($0.position, by: me) })
        XCTAssertTrue(view.findsInLand.contains(hamlet))
        XCTAssertFalse(state.view(for: other).findsInLand.contains { !state.isExplored($0.position, by: other) })
        // And its own seeking alone, through the realm's parts.
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        _ = try state.perform(.seek(unit: lantern.id, find: hamlet.id), as: me)
        XCTAssertEqual(state.view(for: me).sought, [me: [hamlet.id]])
        XCTAssertNil(state.view(for: other).sought)
        // A hold over it, and it is gone.
        var taken = state
        taken.holds.append(Hold(id: taken.takeID(), name: "Overholm", owner: other, position: hamlet.position, isSeat: false, foundedWatch: 0))
        XCTAssertNil(taken.find(at: hamlet.position))
        XCTAssertNil(taken.find(hamlet.id))
        XCTAssertFalse(taken.findsKnown(by: me).contains(hamlet))
        // The realm keeps them, and who has sought what.
        var realm = RealmState(name: "The Nullmere", seed: "found in the realm", seats: 6, radius: 18, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        let ama = try XCTUnwrap(realm.world.houses.first { $0.isPlayer }).id
        let (lanternOfAma, found) = try lanternBeside(.hamlet, in: &realm.world, for: ama)
        _ = try realm.world.perform(.seek(unit: lanternOfAma.id, find: found.id), as: ama)
        let parts = try realm.parts(using: Scene.encoder)
        let kept = try RealmState(parts: parts)
        XCTAssertEqual(kept, realm, "The realm keeps its hamlets and barrows, and who sought them")
        XCTAssertTrue(kept.world.hasSought(found.id, by: ama))
        // Saved and read back, every find and every House's seeking kept.
        let data = try JSONEncoder().encode(state)
        let read = try JSONDecoder().decode(GameState.self, from: data)
        XCTAssertEqual(read.findsInLand, state.findsInLand)
        XCTAssertTrue(read.hasSought(hamlet.id, by: me))
    }

    /// What came of a seeking is kept in the chronicle as the realm wrote
    /// it, and a hamlet's folk or a barrow's stones are given to the
    /// device's model from it: the gift or the goods, where it lies, and for
    /// a hamlet the holds within the reach of what its folk told. Nothing
    /// for a find the House hasn't sought, nor for another House.
    func testWhatASeekingBroughtIsVoicedFromTheChronicle() throws {
        var state = world()
        let me = state.player
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        let (lantern, hamlet) = try lanternBeside(.hamlet, in: &state, for: me)
        XCTAssertNil(state.discovery(of: hamlet, by: me), "Not sought yet")
        XCTAssertNil(state.voiced(hamlet, by: me))
        let gift = state.gift(of: hamlet, to: me)
        _ = try state.perform(.seek(unit: lantern.id, find: hamlet.id), as: me)
        let entry = try XCTUnwrap(state.discovery(of: hamlet, by: me))
        XCTAssertEqual(entry.text, "\(state.houses[me].title)'s Lanterns come to \(hamlet.named), whose folk give them \(gift).")
        XCTAssertEqual(entry.watch, state.watch)
        XCTAssertNil(state.discovery(of: hamlet, by: other), "Another House never sought it")
        XCTAssertNil(state.voiced(hamlet, by: other))
        let folk = try XCTUnwrap(state.voiced(hamlet, by: me))
        XCTAssertEqual(folk.task, Voicing.hamletTask)
        XCTAssertEqual(folk.facts.count, 3, "\(folk.facts)")
        XCTAssertEqual(folk.facts[0], entry.text)
        XCTAssertEqual(folk.facts[1], "The hamlet of \(hamlet.name) lies \(state.placeName(of: hamlet.position)).")
        let near = state.holds.filter { $0.position.distance(to: hamlet.position) <= GameState.hamletTells }
        if let nearest = near.min(by: { ($0.position.distance(to: hamlet.position), $0.id) < ($1.position.distance(to: hamlet.position), $1.id) }) {
            XCTAssertTrue(folk.facts[2].hasPrefix("Within 3 tiles of it stand"), folk.facts[2])
            XCTAssertTrue(folk.facts[2].contains("\(nearest.name), a hold of \(state.houses[nearest.owner].title)"), folk.facts[2])
        } else {
            XCTAssertEqual(folk.facts[2], "No hold stands within 3 tiles of it.")
        }
        // Asked as every voice is asked: the task, then each fact.
        let asked = Voicing.asking(folk.task, facts: folk.facts)
        XCTAssertTrue(folk.facts.allSatisfy { asked.contains("- \($0)") })
        // Among the moments a keeper's device gives words to, by the find's
        // key: the latest three the House sought, never another House's.
        XCTAssertEqual(state.voicedMoments(for: me).filter { $0.key.hasPrefix("find-") }.map(\.key), ["find-\(hamlet.id)"])
        XCTAssertTrue(state.voicedMoments(for: other).allSatisfy { !$0.key.hasPrefix("find-") })

        // A barrow: what it gave up, and where it lies.
        var graves = world("the old graves")
        let keeper = graves.player
        let (digger, barrow) = try lanternBeside(.barrow, in: &graves, for: keeper)
        let goods = try XCTUnwrap(graves.graveGoods(of: barrow, for: keeper))
        _ = try graves.perform(.seek(unit: digger.id, find: barrow.id), as: keeper)
        let stones = try XCTUnwrap(graves.voiced(barrow, by: keeper))
        XCTAssertEqual(stones.task, Voicing.barrowTask)
        XCTAssertEqual(stones.facts, [
            "\(graves.houses[keeper].title)'s Lanterns go down into \(barrow.named) and bring up \(goods.counted(1)).",
            "\(barrow.named.lineBegun) lies \(graves.placeName(of: barrow.position)).",
        ])
    }
}
