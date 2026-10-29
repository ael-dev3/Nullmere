import Foundation
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The game near its end and at it: counsel when the keeper is close to
/// winning, a rival's dominion told to a keeper still standing and to one
/// fallen, the story's line running to a watch not yet recorded; a foreign
/// hold in sight; and the app as it starts, its sound off.
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

        // Houses sworn to the keeper, until the realm is two holds short.
        state.holds[seat].levels[.moonspire] = 0
        for other in state.houses.map(\.id) where other != me {
            if state.standings().first(where: { $0.house == me })?.threat == .dominion { break }
            state.houses[other].liege = me
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
