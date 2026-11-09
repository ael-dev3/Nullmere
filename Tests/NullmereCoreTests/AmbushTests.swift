import Foundation
import XCTest
@testable import NullmereCore

/// Lying in wait: a keeper's company of war marching dark in the blackwood
/// waits there and springs upon the first foe at war that comes within its
/// reach, striking as an order would; only its own House knows; it waits no
/// more once it marches or lights its torches; the realm keeps it.
final class AmbushTests: XCTestCase {
    /// A keeper's spears marching dark in the blackwood beside open ground,
    /// and a House at war with the keeper's.
    private func lyingInWait(_ seed: String = "lying in wait") throws -> (GameState, me: Int, foe: Int, company: NullmereCore.Unit, open: Hex) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let foe = try XCTUnwrap(state.livingHouses.first { $0.id != me }).id
        state.setStance(.war, between: me, and: foe, by: me)
        let company = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        func open(_ hex: Hex) -> Bool {
            guard let terrain = state.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        }
        let wood = try XCTUnwrap(state.map.hexes.first { hex in
            state.isCover(hex) && open(hex) && hex.neighbors.contains { !state.isCover($0) && open($0) }
        }, "Blackwood beside open ground")
        state.units[try XCTUnwrap(state.unitIndex(company.id))].position = wood
        XCTAssertEqual(state.waitRefusal(company.id, waiting: true, as: me), .notMarchingDark, "Torches lit")
        _ = try state.perform(.torches(unit: company.id, lit: false), as: me)
        let beside = try XCTUnwrap(wood.neighbors.first { !state.isCover($0) && open($0) })
        return (state, me, foe, try XCTUnwrap(state.unit(company.id)), beside)
    }

    func testACompanyMarchingDarkLiesInWaitInTheWoodAndOnlyItsHouseKnows() throws {
        var (state, me, foe, company, open) = try lyingInWait()
        XCTAssertEqual(state.waitRefusal(company.id, waiting: true, as: foe), .notYours)
        XCTAssertEqual(state.waitRefusal(company.id, waiting: false, as: me), .waitingAlready(false))
        // Out of the wood, or on the march, it can't.
        var outside = state
        outside.units[try XCTUnwrap(outside.unitIndex(company.id))].position = open
        XCTAssertEqual(outside.waitRefusal(company.id, waiting: true, as: me), .notInTheWood)
        var marching = state
        marching.units[try XCTUnwrap(marching.unitIndex(company.id))].destination = open
        XCTAssertEqual(marching.waitRefusal(company.id, waiting: true, as: me), .onTheMarch)
        XCTAssertEqual(RuleError.notInTheWood.description, "It may lie in wait only in the blackwood, where the wood isn't burnt.")
        // It lies in wait, told to its own House alone.
        let events = try state.perform(.lieInWait(unit: company.id, waiting: true), as: me)
        XCTAssertEqual(events, [.waitSet(unit: company.id, waiting: true, owner: me)])
        XCTAssertTrue(state.isWaiting(company.id))
        XCTAssertEqual(state.waitRefusal(company.id, waiting: true, as: me), .waitingAlready(true))
        XCTAssertTrue(state.view(for: me).isWaiting(company.id))
        XCTAssertFalse(state.view(for: foe).isWaiting(company.id), "Only its own House knows")
        XCTAssertEqual(state.events(events, heardBy: foe), [])
        let told = try XCTUnwrap(state.tidings(of: events[0], for: me)).text
        XCTAssertTrue(told.hasPrefix("Your \(state.named(company)) lie in wait in the wood"), told)
        // Stood down, it waits no more, told so.
        let stood = try state.perform(.lieInWait(unit: company.id, waiting: false), as: me)
        XCTAssertEqual(stood, [.waitSet(unit: company.id, waiting: false, owner: me)])
        XCTAssertFalse(state.isWaiting(company.id))
        XCTAssertNil(state.waiting)
        let toldDown = try XCTUnwrap(state.tidings(of: stood[0], for: me)).text
        XCTAssertTrue(toldDown.hasPrefix("Your \(state.named(company)) no longer lie in wait"), toldDown)
        _ = try state.perform(.lieInWait(unit: company.id, waiting: true), as: me)
        // Its torches lit, it waits no more; nor once ordered on.
        _ = try state.perform(.torches(unit: company.id, lit: true), as: me)
        XCTAssertFalse(state.isWaiting(company.id))
        _ = try state.perform(.torches(unit: company.id, lit: false), as: me)
        _ = try state.perform(.lieInWait(unit: company.id, waiting: true), as: me)
        _ = try state.perform(.move(unit: company.id, to: open), as: me)
        XCTAssertFalse(state.isWaiting(company.id))
        XCTAssertNil(state.waiting)
    }

    func testItSpringsUponTheFirstFoeThatComesWithinItsReach() throws {
        var (state, me, foe, company, open) = try lyingInWait("the ambush")
        _ = try state.perform(.lieInWait(unit: company.id, waiting: true), as: me)
        // Nothing within reach: it waits on.
        XCTAssertEqual(state.springAmbushes(), [])
        XCTAssertTrue(state.isWaiting(company.id))
        // A foe's company comes beside the wood.
        let walker = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: foe, near: open))
        state.units[try XCTUnwrap(state.unitIndex(walker.id))].position = open
        // Behind a hold's walls, it is let be: an ambush falls on the march.
        var walled = state
        walled.holds.append(Hold(id: walled.takeID(), name: "Thornhold", owner: foe, position: open, isSeat: false, foundedWatch: 0))
        XCTAssertEqual(walled.springAmbushes(), [])
        XCTAssertTrue(walled.isWaiting(company.id))
        // Two foes within its reach: the nearest first, and of those as
        // near, the first made.
        var two = state
        let second = try XCTUnwrap(company.position.neighbors.first { hex in
            guard hex != open, let terrain = two.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && two.unit(at: hex) == nil && two.hold(at: hex) == nil
        }, "Ground for a second foe beside the wood")
        let another = try XCTUnwrap(two.placeUnit(.spear, tier: 1, for: foe, near: second))
        two.units[try XCTUnwrap(two.unitIndex(another.id))].position = second
        XCTAssertEqual(two.foesInReach(of: try XCTUnwrap(two.unit(company.id))).map(\.id), [walker.id, another.id].sorted())
        // At peace, it is let pass.
        var peace = state
        peace.setStance(.peace, between: me, and: foe, by: me)
        XCTAssertEqual(peace.springAmbushes(), [])
        XCTAssertTrue(peace.isWaiting(company.id))
        // At war, it springs, strikes as an order would, and waits no more.
        let health = try XCTUnwrap(state.unit(walker.id)).health
        let events = state.springAmbushes()
        let sprung = GameEvent.ambushSprung(unit: company.id, owner: me, at: company.position, struck: walker.id, struckOwner: foe)
        XCTAssertEqual(events.first, sprung, "\(events)")
        XCTAssertGreaterThan(events.count, 1, "and the blow struck")
        XCTAssertLessThan(state.unit(walker.id)?.health ?? 0, health, "struck")
        XCTAssertFalse(state.isWaiting(company.id))
        // Told to both Houses, as each sees it.
        XCTAssertEqual(state.events([sprung], heardBy: foe), [sprung])
        let ours = try XCTUnwrap(state.tidings(of: sprung, for: me))
        XCTAssertEqual(ours.text, "Your \(state.named(company)) spring from the dark of the wood \(state.placeName(of: company.position)) upon "
                       + "\(state.houses[foe].title)'s \(state.named(walker)).")
        XCTAssertEqual(ours.tone, .good)
        let theirs = try XCTUnwrap(state.tidings(of: sprung, for: foe))
        XCTAssertTrue(theirs.text.hasPrefix("\(state.houses[me].title)'s \(state.named(company)) spring upon your"), theirs.text)
        XCTAssertEqual(theirs.tone, .bad)
        let other = try XCTUnwrap(state.livingHouses.first { $0.id != me && $0.id != foe }).id
        XCTAssertNil(state.tidings(of: sprung, for: other))
    }

    /// Bows lying in wait reach two tiles, but a foe marching dark there
    /// their House can't make out, so they let it pass unseen; its torches
    /// lit, they spring upon it.
    func testItLetsPassAFoeMarchingDarkItCannotMakeOut() throws {
        var (state, me, foe, spears, _) = try lyingInWait("bows in the wood")
        let wood = spears.position
        // The spears gone, bows in their place in the wood, marching dark.
        state.units.removeAll { $0.id == spears.id }
        let bows = try XCTUnwrap(state.placeUnit(.bow, tier: 1, for: me, near: wood))
        state.units[try XCTUnwrap(state.unitIndex(bows.id))].position = wood
        _ = try state.perform(.torches(unit: bows.id, lit: false), as: me)
        _ = try state.perform(.lieInWait(unit: bows.id, waiting: true), as: me)
        XCTAssertEqual(NullmereCore.UnitKind.bow.range, 2)
        // A foe two tiles off, beyond any sight of the House's close by.
        let ownGround = state.units(of: me).map(\.position) + state.holds(of: me).map(\.position)
        let far = try XCTUnwrap(wood.spiral(2).first { hex in
            guard hex.distance(to: wood) == 2, let terrain = state.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && state.unit(at: hex) == nil && state.hold(at: hex) == nil
                && ownGround.allSatisfy { $0 == wood || $0.distance(to: hex) > GameState.darkSight }
        }, "Open ground two tiles from the wood")
        let walker = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: foe, near: far))
        state.units[try XCTUnwrap(state.unitIndex(walker.id))].position = far
        _ = try state.perform(.torches(unit: walker.id, lit: false), as: foe)
        XCTAssertEqual(state.springAmbushes(), [], "Marching dark beyond what its House makes out")
        XCTAssertTrue(state.isWaiting(bows.id))
        // Its torches lit, it is seen, and they spring.
        _ = try state.perform(.torches(unit: walker.id, lit: true), as: foe)
        let events = state.springAmbushes()
        XCTAssertEqual(events.first, .ambushSprung(unit: bows.id, owner: me, at: wood, struck: walker.id, struckOwner: foe), "\(events)")
        XCTAssertFalse(state.isWaiting(bows.id))
    }

    func testItSpringsAsTheWatchTurnsAndTheRealmKeepsIt() throws {
        var realm = RealmState(name: "The Nullmere", seed: "waiting kept", seats: 6, radius: 18, watchLength: 600, now: 0)
        _ = try realm.arrive("id-ama", name: "Ama", now: 1)
        let me = try XCTUnwrap(realm.world.houses.first { $0.isPlayer }).id
        let company = try XCTUnwrap(realm.world.units(of: me).first { $0.kind == .spear })
        let wood = try XCTUnwrap(realm.world.map.hexes.first { hex in
            realm.world.isCover(hex) && realm.world.unit(at: hex) == nil && realm.world.hold(at: hex) == nil
        })
        realm.world.units[try XCTUnwrap(realm.world.unitIndex(company.id))].position = wood
        _ = try realm.world.perform(.torches(unit: company.id, lit: false), as: me)
        _ = try realm.world.perform(.lieInWait(unit: company.id, waiting: true), as: me)
        let parts = try realm.parts(using: Scene.encoder)
        XCTAssertEqual(try RealmState(parts: parts), realm, "The realm keeps who lies in wait")
        // A foe at war comes within reach; as the watch turns it springs.
        let foe = try XCTUnwrap(realm.world.livingHouses.first { $0.id != me }).id
        realm.world.setStance(.war, between: me, and: foe, by: me)
        let spot = try XCTUnwrap(wood.neighbors.first { hex in
            guard let terrain = realm.world.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && realm.world.unit(at: hex) == nil && realm.world.hold(at: hex) == nil
        })
        let walker = try XCTUnwrap(realm.world.placeUnit(.spear, tier: 1, for: foe, near: spot))
        realm.world.units[try XCTUnwrap(realm.world.unitIndex(walker.id))].position = spot
        let events = realm.world.endWatch()
        XCTAssertTrue(events.contains { event in
            if case .ambushSprung(company.id, me, _, walker.id, foe) = event { return true }
            return false
        }, "Sprung as the watch turned")
        XCTAssertFalse(realm.world.isWaiting(company.id))
    }
}
