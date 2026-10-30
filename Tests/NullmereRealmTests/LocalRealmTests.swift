import Foundation
import NullmereCore
import XCTest
@testable import NullmereRealm

/// Linux's XCTest can't run main-actor test classes, so each test runs its
/// body on the main actor, where the realm lives.
final class LocalRealmTests: XCTestCase {
    private var now = 0.0

    @MainActor
    private func realm(watchLength: Double = 60, storeURL: URL? = nil) -> LocalRealm {
        LocalRealm(state: RealmState(name: "The Nullmere", seed: "link test", seats: 4, radius: 18, watchLength: watchLength, now: 0),
                   clock: { [unowned self] in self.now }, storeURL: storeURL)
    }

    /// Everything a link hears.
    private final class Ear {
        var events: [RealmEvent] = []
        var lastStatus: RealmStatus? {
            events.reversed().lazy.compactMap { if case .status(let status) = $0 { return status } else { return nil } }.first
        }
        var world: GameState? {
            for event in events.reversed() {
                switch event {
                case .arrived(_, let world), .settled(let world, _), .orderRefused(_, let world), .changed(let world), .watchTurned(let world, _):
                    return world
                default: continue
                }
            }
            return nil
        }
    }

    @MainActor
    private func listen(_ link: LocalLink) -> Ear {
        let ear = Ear()
        link.onEvent = { ear.events.append($0) }
        return ear
    }

    func testAKeeperConnectsArrivesAndGivesOrders() throws {
        try MainActor.assumeIsolated {
            let realm = realm()
            let link = realm.link(identity: "a")
            let ear = listen(link)
            link.connect()
            XCTAssertEqual(ear.lastStatus?.freeSeats, 4)
            link.arrive(name: "Ama")
            guard case .arrived(let keeper, let world)? = ear.events.first(where: { if case .arrived = $0 { return true } else { return false } }) else {
                return XCTFail("Not arrived: \(ear.events)")
            }
            let house = try XCTUnwrap(keeper.house)
            XCTAssertEqual(world.houses[house].title, "House Ama")
            XCTAssertEqual(ear.lastStatus?.online, 1)

            let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
            link.send(.fortify(unit: spear.id))
            guard case .settled(let after, _)? = ear.events.dropLast().last else { return XCTFail("\(ear.events.suffix(2))") }
            XCTAssertTrue(after.unit(spear.id)!.fortified)
            guard case .answered([])? = ear.events.last else { return XCTFail("Each order carried out is answered: \(String(describing: ear.events.last))") }

            link.send(.fortify(unit: 999_999))
            guard case .orderRefused(.rule, _)? = ear.events.last else { return XCTFail("\(String(describing: ear.events.last))") }
        }
    }

    func testABadNameIsRefused() {
        MainActor.assumeIsolated {
            let realm = realm()
            let link = realm.link(identity: "a")
            let ear = listen(link)
            link.arrive(name: "x")
            guard case .refused(.nameInvalid)? = ear.events.last else { return XCTFail("\(String(describing: ear.events.last))") }
        }
    }

    func testKeepersSeeEachOthersOrdersAndTheWatchTurnsForAll() throws {
        try MainActor.assumeIsolated {
            let realm = realm()
            let a = realm.link(identity: "a"), b = realm.link(identity: "b")
            let earA = listen(a), earB = listen(b)
            a.arrive(name: "Ama")
            b.arrive(name: "Bel")
            let world = try XCTUnwrap(earA.world)
            let bels = try XCTUnwrap(realm.state.keeper("b")?.house)
            XCTAssertEqual(world.houses[bels].title, "House Bel", "Ama hears that Bel took a seat")
            XCTAssertTrue(world.houses[bels].isPlayer)
            let house = try XCTUnwrap(realm.state.keeper("a")?.house)
            let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
            a.send(.fortify(unit: spear.id))
            guard case .changed(let seen)? = earB.events.last else { return XCTFail("\(String(describing: earB.events.last))") }
            XCTAssertNil(seen.unit(spear.id), "B hears the world changed, but A's company is out of B's sight")
            XCTAssertEqual(seen.houses[house].stock, .zero, "nor are A's stores B's to know")

            a.setReady(true)
            XCTAssertEqual(earB.lastStatus?.ready, 1)
            b.setReady(true)
            XCTAssertTrue(earA.events.contains { if case .watchTurned = $0 { return true } else { return false } })
            XCTAssertTrue(earB.events.contains { if case .watchTurned = $0 { return true } else { return false } })
            XCTAssertEqual(realm.state.world.watch, 2)
        }
    }

    func testTheWatchTurnsOnTimeAndALeaverHoldsNoOneUp() {
        MainActor.assumeIsolated {
            let realm = realm(watchLength: 60)
            let a = realm.link(identity: "a"), b = realm.link(identity: "b")
            let earA = listen(a)
            a.arrive(name: "Ama")
            b.arrive(name: "Bel")
            now = 30
            realm.tick()
            XCTAssertEqual(realm.state.world.watch, 1)
            now = 61
            realm.tick()
            XCTAssertEqual(realm.state.world.watch, 2)
            XCTAssertTrue(earA.events.contains { if case .watchTurned = $0 { return true } else { return false } })
            // Bel leaves: Ama's readiness doesn't wait for Bel, but can't
            // hurry the watch past Bel's House before a third of it is gone.
            b.leave()
            a.setReady(true)
            XCTAssertEqual(realm.state.world.watch, 2)
            now = 61 + 20
            realm.tick()
            XCTAssertEqual(realm.state.world.watch, 3)
        }
    }

    func testTheRealmIsKeptAndReopened() {
        MainActor.assumeIsolated {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: dir) }
            let url = dir.appendingPathComponent("realm.json")
            do {
                let realm = LocalRealm.open(at: url, name: "The Nullmere", seed: "kept", seats: 3, clock: { 0 })
                let link = realm.link(identity: "a")
                link.arrive(name: "Ama")
                link.setReady(true)
                XCTAssertEqual(realm.state.world.watch, 2)
            }
            let reopened = LocalRealm.open(at: url, name: "ignored", seed: "ignored", clock: { 0 })
            XCTAssertEqual(reopened.state.world.watch, 2)
            XCTAssertEqual(reopened.state.keeper("a")?.name, "Ama")
            XCTAssertEqual(reopened.state.name, "The Nullmere")
        }
    }

    func testAnIdentityIsMadeOnceAndKept() {
        MainActor.assumeIsolated {
            let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer { try? FileManager.default.removeItem(at: dir) }
            let store = FileIdentityStore(url: dir.appendingPathComponent("identity"))
            XCTAssertNil(store.load())
            let first = store.identity()
            XCTAssertTrue(KeeperIdentity.isWellFormed(first))
            XCTAssertEqual(store.identity(), first, "The same keeper next time")
            XCTAssertNotEqual(KeeperIdentity.make(), KeeperIdentity.make())
        }
    }
}
