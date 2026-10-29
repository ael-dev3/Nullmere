import Foundation
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The game near its end and at it: counsel when the keeper is close to
/// winning, a rival's dominion told to a keeper still standing and to one
/// fallen, the story's line running to a watch not yet recorded; a foreign
/// hold in sight; a keeper whose House fell looking on; and the app as it
/// starts, its sound off.
@MainActor
final class NearTheEndTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 1100, height: CGFloat = 760) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    /// Counsel warns the keeper of their own near victory, by either road.
    func testCounselSpeaksOfTheKeepersOwnNearVictory() throws {
        var state = GameState(settings: GameSettings(seedText: "near victory"))
        let me = state.player
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.moonspire] = BuildingKind.moonspire.maxLevel - 1
        XCTAssertEqual(Counsel.race(in: state, player: me),
                       "One stage more on your Moonspire and the lake is yours. Every rival will march on your seat: keep its walls manned.")

        // Holds founded, until the realm is two short of dominion (never
        // fewer than ten, so more than a young lake's seats).
        state.holds[seat].levels[.moonspire] = 0
        var free = state.map.hexes.filter { hex in
            state.map[hex]?.terrain.isPassable == true && state.hold(at: hex) == nil && state.unit(at: hex) == nil
        }
        while state.realm(of: me) < state.dominionNeed - 2, let hex = free.popLast() {
            state.holds.append(Hold(id: state.nextID, name: "Hold \(state.nextID)", owner: me, position: hex, isSeat: false, foundedWatch: 1))
            state.nextID += 1
        }
        XCTAssertEqual(state.standings().first { $0.house == me }?.threat, .dominion)
        let line = try XCTUnwrap(Counsel.race(in: state, player: me))
        XCTAssertTrue(line.hasPrefix("Your realm holds "), line)
        XCTAssertTrue(line.hasSuffix("and the lake is yours."), line)
    }

    /// A rival's dominion, told to a keeper whose House still stands and to
    /// one whose last hold has fallen.
    func testARivalsDominionIsToldEachWay() throws {
        for fallen in [false, true] {
            var state = GameState(settings: GameSettings(seedText: "a rival's dominion"))
            let rival = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
            if fallen { state.houses[state.player].isEliminated = true }
            let outcome = Outcome(winner: rival, kind: .dominion, watch: state.watch)
            state.outcome = outcome
            let store = LocalStore(directory: dir.appendingPathComponent("\(fallen)"))
            let session = GameSession(state: state, store: store)
            let app = GameApp(store: store, readiness: { .ready }, sound: false, address: .hosted(seed: "a rival's dominion"),
                              identity: FileIdentityStore(url: dir.appendingPathComponent("identity-\(fallen)")))
            XCTAssertEqual(session.playerHouse.isEliminated, fallen)
            try draw(OutcomeOverlay(app: app, session: session, outcome: outcome))
        }
    }

    /// A keeper whose House falls while the age goes on looks on, and is
    /// told they'll be seated again when the next begins.
    func testAFallenKeeperLooksOnUntilTheAgeEnds() throws {
        var state = GameState(settings: GameSettings(seedText: "fallen, looking on"))
        state.houses[state.player].isEliminated = true
        let store = LocalStore(directory: dir.appendingPathComponent("fallen"))
        let session = GameSession(state: state, store: store)
        let app = GameApp(store: store, readiness: { .ready }, sound: false, address: .hosted(seed: "fallen, looking on"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity-fallen")))
        XCTAssertNil(session.state.outcome)
        let words = FallenOverlay.words(for: session.playerHouse, watch: session.state.watch)
        XCTAssertTrue(words.hasPrefix("The last hold of \(session.playerHouse.title) is lost at watch \(session.state.watch)."), words)
        try draw(FallenOverlay(app: app, session: session))
        try draw(PlayView(app: app, session: session))
    }

    /// A fallen keeper with a House standing free is offered it, takes it
    /// up, and arrives in it, by the realm's own word.
    func testAFallenKeeperTakesUpAFreeHouse() throws {
        var realm = RealmState(name: "The Nullmere", seed: "a free House", seats: 4, radius: 18, watchLength: 600, now: 0)
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        for index in realm.world.holds.indices where realm.world.holds[index].owner == bel {
            realm.world.holds[index].owner = ama
            realm.world.holds[index].isSeat = false
        }
        realm.world.units.removeAll { $0.owner == bel }
        realm.world.houses[bel].isEliminated = true
        let host = LocalRealm(state: realm)
        let link = host.link(identity: "id-bel")
        let session = GameSession(link: link, house: bel, world: try XCTUnwrap(realm.view(for: "id-bel")).world,
                                  store: LocalStore(directory: dir), host: host)
        XCTAssertFalse(session.mayTakeUpAFreeHouse, "Not before the realm has said how it stands")
        link.connect()
        XCTAssertTrue(session.mayTakeUpAFreeHouse)
        XCTAssertTrue(FallenOverlay.words(for: session.playerHouse, watch: 1, freeHouse: true).contains("take it up and play on"))
        try draw(FallenOverlay(app: GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false,
                                            address: .hosted(seed: "a free House"),
                                            identity: FileIdentityStore(url: dir.appendingPathComponent("identity-free"))),
                               session: session))
        var seated: Keeper?
        session.onNewAge = { keeper, _ in seated = keeper }
        session.takeUpAFreeHouse()
        let house = try XCTUnwrap(seated?.house)
        XCTAssertNotEqual(house, bel)
        XCTAssertFalse(host.state.world.houses[house].isEliminated)
    }

    /// The story's line runs to the present watch, recorded or not yet.
    func testTheStoryRunsToTheWatchNotYetRecorded() {
        var state = GameState(settings: GameSettings(seedText: "a story", houseCount: 3, radius: 16))
        state.watch += 1
        XCTAssertNotEqual(state.history.last?.watch, state.watch, "Not yet recorded")
        let points = StoryChart.points(for: state)
        XCTAssertEqual(points.filter { $0.house == state.player }.last?.watch, state.watch)
    }

    /// A foreign hold in sight shows its ward; out of sight, it can't.
    func testAForeignHoldInSightShowsItsWard() throws {
        var state = GameState(settings: GameSettings(seedText: "a ward in sight", houseCount: 3, radius: 18))
        let me = state.player
        let theirs = try XCTUnwrap(state.holds.first { $0.owner != me && $0.isSeat })
        let beside = try XCTUnwrap(state.map.neighbors(of: theirs.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        state.units.append(NullmereCore.Unit(id: state.nextID, kind: .lantern, owner: me, position: beside))
        state.nextID += 1
        state.reveal(around: theirs.position, range: 2, for: me)
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        XCTAssertTrue(session.isVisible(theirs.position))
        session.selection = .hold(theirs.id)
        try draw(SelectionPanel(session: session), width: 360, height: 700)
    }

    /// The app as it starts: the launcher's face shown, the realm's door
    /// not yet opened; with the sound off, as the keeper left it.
    func testTheAppStartsOnTheLauncher() {
        let defaults = UserDefaults.standard
        let kept = defaults.object(forKey: "sound.enabled")
        defaults.set(false, forKey: "sound.enabled")
        defer { kept == nil ? defaults.removeObject(forKey: "sound.enabled") : defaults.set(kept, forKey: "sound.enabled") }
        let shell = OnlineShell()
        XCTAssertFalse(shell.inRealm)
        XCTAssertFalse(shell.app.isSoundOn)
        XCTAssertEqual(shell.launcher.screen, .title)
    }
}
