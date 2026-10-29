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
        XCTAssertTrue(ama.state.unit(spear.id)?.fortified ?? false)
        XCTAssertNil(bel.state.unit(spear.id), "Ama's company is out of Bel's sight, and so out of Bel's copy of the world")
        XCTAssertEqual(bel.state.houses[ama.player].stock, .zero, "Ama's stores are Ama's to know")
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

    func testTheDoorAndTheHousesTellWhoIsThere() throws {
        func status(_ names: [String], online: Int? = nil) -> RealmStatus {
            RealmStatus(name: "R", age: 1, watch: 3, seats: 8, freeSeats: 2, keepers: 9, online: online ?? names.count, ready: 0,
                        secondsLeft: 60, isEnding: false, present: names)
        }
        XCTAssertNil(RealmLine.present(status([])))
        XCTAssertEqual(RealmLine.present(status(["Ama"])), "There now: Ama.")
        XCTAssertEqual(RealmLine.present(status(["Ama", "Bel", "Cor"])), "There now: Ama, Bel and Cor.")
        XCTAssertEqual(RealmLine.present(status(["A", "B", "C", "D", "E", "F", "G"])), "There now: A, B, C, D, E and 2 more.")
        XCTAssertEqual(RealmLine.present(status(Array(repeating: "K", count: 24), online: 30)), "There now: K, K, K, K, K and 25 more.")
        XCTAssertTrue(RealmLine.describe(status(["Ama", "Bel"])).hasSuffix("2 seats free of 8. There now: Ama and Bel."))

        // In the world, each House says who gives its orders.
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let bel = try enter(realm, as: "b", name: "Bel")
        XCTAssertEqual(ama.realmStatus?.present, ["Ama", "Bel"])
        let bels = ama.state.houses[bel.player]
        XCTAssertEqual(bels.title, "House Bel", "Ama's world knows Bel took a seat")
        XCTAssertEqual(HouseRow.keeping(bels, present: ama.realmStatus?.present), "Its keeper is here.")
        realm.link(identity: "b").leave()
        XCTAssertEqual(ama.realmStatus?.present, ["Ama"])
        XCTAssertEqual(HouseRow.keeping(bels, present: ama.realmStatus?.present), "Its keeper is away; after two watches a caretaker keeps it, beginning nothing.")
        let steward = try XCTUnwrap(ama.state.houses.first { !$0.isPlayer })
        XCTAssertEqual(HouseRow.keeping(steward, present: ama.realmStatus?.present), "A steward gives its orders.")
    }

    func testWordsBetweenKeepersCanBeHidden() throws {
        UserDefaults.standard.removeObject(forKey: GameSession.mutedKey)
        defer { UserDefaults.standard.removeObject(forKey: GameSession.mutedKey) }
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let bel = try enter(realm, as: "b", name: "Bel")
        XCTAssertTrue(ama.perform(.declareWar(on: bel.player)))
        let bels = ama.state.houses[bel.player]
        ama.propose(.peace, to: bels, words: "  Enough   blood. ")
        let envoy = try XCTUnwrap(bel.envoys.first)
        XCTAssertEqual(bel.words(of: envoy), "Enough blood.")
        let amas = bel.state.houses[ama.player]
        bel.setMuted(true, house: amas)
        XCTAssertNil(bel.words(of: envoy), "Hidden")
        XCTAssertEqual(UserDefaults.standard.stringArray(forKey: GameSession.mutedKey), ["Ama"], "and remembered on this Mac")
        bel.setMuted(false, house: amas)
        XCTAssertEqual(bel.words(of: envoy), "Enough blood.")

        // Words that can't be carried leave the offer plain.
        XCTAssertTrue(bel.perform(.answer(envoy: envoy.id, accept: false)))
        ama.propose(.peace, to: bels, words: "see www.example.org")
        XCTAssertNil(try XCTUnwrap(bel.envoys.first).words)
    }

    func testKeepersSendEachOtherGifts() throws {
        let realm = realm()
        let ama = try enter(realm, as: "a", name: "Ama")
        let bel = try enter(realm, as: "b", name: "Bel")
        let before = bel.state.houses[bel.player].stock.grain
        XCTAssertTrue(ama.perform(.gift(to: bel.player, resource: .grain, amount: 25)))
        XCTAssertEqual(bel.state.houses[bel.player].stock.grain, before + 25, "Bel's world has the gift at once")
        XCTAssertTrue(bel.notices.contains { $0.text == "House Ama sends you a gift of 25 grain." }, "\(bel.notices.map(\.text))")
        let choices = HouseRow.giftChoices(from: Stock(grain: 30, timber: 9, stone: 50, moonsalt: 4))
        XCTAssertEqual(choices.map { "\($0.amount) \($0.resource.title)" }, ["10 Grain", "25 Grain", "10 Stone", "25 Stone", "50 Stone", "2 Moonsalt"])
    }

    func testTheRealmOutOfReachIsToldOnceAndItsReturnToo() throws {
        let link = StubLink()
        let state = GameState(settings: GameSettings(seedText: "out of reach", houseCount: 3, radius: 16))
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player),
                                  store: LocalStore(directory: dir))
        for _ in 0..<5 { link.onEvent?(.unreachable("No answer from the server.")) }
        XCTAssertTrue(session.isOutOfReach)
        XCTAssertEqual(session.notices.filter { $0.text.contains("out of reach") }.count, 1, "Said once, however often the link tries")
        link.onEvent?(.changed(session.state))
        XCTAssertFalse(session.isOutOfReach)
        XCTAssertEqual(session.notices.last?.text, "The realm answers again.")
    }
}

/// A link that says only what a test tells it to.
@MainActor
private final class StubLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
