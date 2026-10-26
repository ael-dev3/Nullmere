import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereRealm

/// Two keepers in one realm, each with their own session.
@MainActor
final class RealmClientTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A keeper's session, the way the app makes one when they arrive.
    private func enter(_ realm: LocalRealm, as identity: String, name: String) throws -> GameSession {
        let link = realm.link(identity: identity)
        var arrived: (Keeper, GameState)?
        link.onEvent = { event in
            if case .arrived(let keeper, let world) = event { arrived = (keeper, world) }
        }
        link.arrive(name: name)
        let (keeper, world) = try XCTUnwrap(arrived)
        return GameSession(link: link, house: try XCTUnwrap(keeper.house), world: world,
                           store: LocalStore(directory: dir.appendingPathComponent(identity)), host: realm)
    }

    private func realm() -> LocalRealm {
        LocalRealm(state: RealmState(name: "The Nullmere", seed: "two keepers", seats: 4, radius: 18, watchLength: 120, now: 0),
                   clock: { 0 })
    }

    func testKeepersShareOneWorld() throws {
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let bel = try enter(realm, as: "b", name: "Bel")
        XCTAssertNotEqual(ama.player, bel.player)
        XCTAssertEqual(ama.playerHouse.title, "House Ama")
        XCTAssertEqual(bel.realmStatus?.online, 2)

        let spear = try XCTUnwrap(ama.state.units(of: ama.player).first { $0.kind == .spear })
        XCTAssertTrue(ama.perform(.fortify(unit: spear.id)))
        XCTAssertTrue(bel.state.unit(spear.id)?.fortified ?? false, "Bel's copy of the world hears Ama's order")
        XCTAssertFalse(bel.perform(.fortify(unit: spear.id)), "No one gives orders to another's company")
    }

    func testTheWatchWaitsForEveryKeeperThere() throws {
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let bel = try enter(realm, as: "b", name: "Bel")
        ama.endWatch()
        XCTAssertTrue(ama.isReady)
        XCTAssertEqual(ama.state.watch, 1, "Bel isn't ready yet")
        XCTAssertEqual(bel.realmStatus?.ready, 1)
        XCTAssertEqual(EndWatchButton.realmLine(status: bel.realmStatus, secondsLeft: 95), "Turns in 1:35 · 1 of 2 ready")

        ama.cancelReady()
        XCTAssertFalse(ama.isReady)
        XCTAssertEqual(bel.realmStatus?.ready, 0)

        ama.endWatch()
        bel.endWatch()
        XCTAssertEqual(ama.state.watch, 2)
        XCTAssertEqual(bel.state.watch, 2)
        XCTAssertFalse(ama.isReady || bel.isReady)
        XCTAssertNotNil(ama.watchCard, "Each keeper sees the watch turn")
        XCTAssertNotNil(bel.watchCard)
    }

    func testKeepersTreatWithEachOtherThroughEnvoys() throws {
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let bel = try enter(realm, as: "b", name: "Bel")
        XCTAssertTrue(ama.perform(.propose(.pact, to: bel.player)))
        let envoy = try XCTUnwrap(bel.envoys.first)
        XCTAssertEqual(envoy.from, ama.player)
        XCTAssertTrue(ama.envoys.isEmpty, "The envoy waits on Bel, not Ama")
        XCTAssertTrue(bel.perform(.answer(envoy: envoy.id, accept: true)))
        XCTAssertEqual(ama.state.stance(ama.player, bel.player), .pact)
    }

    func testTheRealmLineShowsOnlyWhatMatters() {
        let alone = RealmStatus(name: "R", age: 1, watch: 3, seats: 4, freeSeats: 3, keepers: 1, online: 1, ready: 0,
                                secondsLeft: 999_999_999, isEnding: false)
        XCTAssertNil(EndWatchButton.realmLine(status: alone, secondsLeft: 999_999_999), "Alone, with no clock: nothing to say")
        XCTAssertEqual(EndWatchButton.realmLine(status: alone, secondsLeft: 61), "Turns in 1:01")
        XCTAssertEqual(RealmLine.describe(alone), "Age 1, watch 3 · 1 keeper there · 3 seats free of 4.")
    }
}
