import Foundation
@testable import LauncherKit
import NullmereRealm
import NullmereTestSupport
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The Frontier as a keeper meets it in the app: their realm's word of the
/// season open there on the Realm screen, Cross to the Frontier sending
/// their crossing home and taking them across to the Frontier's own
/// database by the same identity, seated there with their levy, and Return
/// Home bringing them back. Two SpacetimeDB databases are held in memory,
/// each with its own steward, the stewards reading each other's status.
@MainActor
final class FrontierAppTests: XCTestCase {
    private var dirs: [URL] = []

    override func tearDown() async throws {
        for dir in dirs { try? FileManager.default.removeItem(at: dir) }
    }

    private func until(_ what: String, timeout: Double = 20, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw NSError(domain: "FrontierAppTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(what)"]) }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func draw(_ view: some View) {
        let renderer = ImageRenderer(content: view.frame(width: 1100, height: 720).background(Color.black))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return XCTFail("Nothing drawn") }
        XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
    }

    func testAKeeperCrossesToTheFrontierWithTheirLevyAndComesHome() async throws {
        let home = FakeSpacetime(), lost = FakeSpacetime()
        let homeKey = try await home.createIdentity(), lostKey = try await lost.createIdentity()
        // One server: the stewards know each other.
        await home.remember(lostKey)
        await lost.remember(homeKey)
        let homeURL = URL(string: "https://realm.test/crossing")!, lostURL = URL(string: "https://realm.test/frontier")!
        let start = Date().timeIntervalSince1970
        let clock: @Sendable () -> Double = { Date().timeIntervalSince1970 - start }
        let realm = try await RealmSteward(transport: home, token: homeKey.token, name: "The Nullmere", seed: "crossing home", seats: 4,
                                           watchLength: 600, now: 0)
        let frontier = try await RealmSteward(transport: lost, token: lostKey.token, name: "The Lost Shore", seed: "crossing frontier",
                                              seats: 4, watchLength: 600, frontier: true, now: 0)
        await realm.border(lost, at: lostURL.absoluteString)
        await frontier.border(home, at: homeURL.absoluteString)
        let running = [Task { await realm.run(clock: clock) }, Task { await frontier.run(clock: clock) }]
        defer { running.forEach { $0.cancel() } }

        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dirs.append(dir)
        let address = GameApp.RealmAddress.network(homeURL)
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: address))
        let identity = MemoryStore()
        // A keeper who has accepted the realm's compact.
        UserDefaults.standard.set(Compact.edition, forKey: GameApp.compactKey)
        defer { UserDefaults.standard.removeObject(forKey: GameApp.compactKey) }
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: address, identity: identity,
                          opensAtOnce: false, transport: home, pollInterval: 0.05)
        app.transports[lostURL] = lost
        app.journeyWait = 0.6
        XCTAssertFalse(app.isSameServer(URL(string: "https://elsewhere.test/frontier")!), "Never to another server, with this one's key")
        XCTAssertFalse(app.isSameServer(URL(string: "https://realm.test")!))
        XCTAssertTrue(app.isSameServer(lostURL))
        app.open()
        try await until("the realm's status") { if case .open = app.door { return true } else { return false } }
        app.enterWorld(name: "Ama")
        try await until("the world") { app.session != nil }
        let session = try XCTUnwrap(app.session)
        // The keeper's key, known to every database on the server.
        let key = try XCTUnwrap(identity.value)
        await lost.remember(try JSONDecoder().decode(SpacetimeCredentials.self, from: Data(key.utf8)))

        try await until("word of the Frontier") { session.canCross }
        XCTAssertEqual(session.realmStatus?.frontier?.address, lostURL.absoluteString)
        XCTAssertNil(session.onReturnHome, "At home")
        draw(RealmPanel(session: session))
        app.travel(to: URL(string: "https://elsewhere.test/frontier")!)
        XCTAssertNil(app.home, "Not taken to another server")

        session.crossToFrontier()
        try await until("the keeper across at the Frontier", timeout: 30) { app.home != nil && app.session?.onReturnHome != nil }
        let there = try XCTUnwrap(app.session)
        XCTAssertEqual(app.address, .network(lostURL))
        XCTAssertEqual(app.home, address)
        XCTAssertFalse(there.canCross, "Not from the Frontier")
        XCTAssertTrue(there.state.units(of: there.player).contains { $0.kind.isMilitary }, "Their levy with them")
        let kingdom = await frontier.state.frontier?.kingdom(of: there.player)
        XCTAssertEqual(kingdom, "The Nullmere")
        draw(RealmPanel(session: there))

        there.onReturnHome?()
        try await until("home again") { app.home == nil && app.session != nil && app.session?.onReturnHome == nil && app.session !== there }
        XCTAssertEqual(app.address, address)
        let crossing = await realm.state.keeper(try XCTUnwrap(app.session?.keeper?.id))?.crossing
        XCTAssertEqual(crossing, 1, "Still crossed for the season, until it is told home")
        app.leaveWorld()
    }

    func testTheRealmScreenSaysHowTheFrontierStands() {
        let last = FrontierResult(season: 1, standings: [], prevailed: "The Farmere", honours: [])
        let open = FrontierNews(address: "https://realm.test/frontier", season: 2, watch: 3, lasts: 24, open: true,
                                standings: [KingdomStanding(realm: "The Farmere", points: 40, keepers: 3),
                                            KingdomStanding(realm: "The Nullmere", points: 12, keepers: 1)], last: last)
        let home = RealmPanel.frontierLine(open, atFrontier: false, levy: 9)
        XCTAssertTrue(home.hasPrefix("The Frontier's second season is open, until the 24th watch"), home)
        XCTAssertTrue(home.contains("your 6 strongest companies"), "Six at most: \(home)")
        XCTAssertTrue(home.hasSuffix("Its last: The Farmere prevailed."), home)
        XCTAssertTrue(RealmPanel.frontierLine(open, atFrontier: false, levy: 1).contains("one company"))
        XCTAssertTrue(RealmPanel.frontierLine(open, atFrontier: false, levy: 0).contains("no company"))
        XCTAssertTrue(RealmPanel.frontierLine(open, atFrontier: true, levy: 3).contains("you stand here for your realm's kingdom"))
        let closed = FrontierNews(address: "", season: 2, watch: 24, lasts: 24, open: false, standings: [], last: nil)
        XCTAssertEqual(RealmPanel.frontierLine(closed, atFrontier: false, levy: 3), "The Frontier's second season is ending; the next opens as it does.")
        XCTAssertEqual(RealmPanel.kingdomsLine(open.standings), "The Farmere 40 (3 keepers) · The Nullmere 12 (1 keeper)")
        let there = RealmPanel.frontierLine(open, atFrontier: true, levy: 3)
        XCTAssertTrue(there.contains("a gate of the Crown broken, \(FrontierState.gatePoints)"), there)
        XCTAssertTrue(there.contains("the Heartstone in its heart, \(FrontierState.heartPoints) for every watch your House holds it"), there)
    }

    /// The Crown's gates as the app tells them: any company may strike one,
    /// where a lair needs a rally's host.
    func testTheCrownsGatesAreToldAsAnyCompanysToStrike() throws {
        let state = GameState(settings: GameSettings(seedText: "a crowned app", houseCount: 4, radius: 18, keepers: 1, lake: .marches))
        let gate = try XCTUnwrap(state.gatesStanding.first)
        let lair = Lair(id: 999, kind: .reavers, level: 2, position: Hex(3, 3), raised: 1)
        let about = LairRally.about(gate)
        XCTAssertTrue(about.hasPrefix("A gate of the Crown, held by Spine Hunters: any company of war may strike it"), about)
        XCTAssertTrue(about.hasSuffix("counts \(FrontierState.gatePoints) for your kingdom at the Frontier."), about)
        XCTAssertTrue(LairRally.about(lair).hasPrefix("A lair of Blackwood Reavers, too strong for any company alone"))
        XCTAssertEqual(RealmPanel.lairsLine([gate]), "Any company of war may strike a gate of the Crown; broken, it lies open to all for the season.")
        XCTAssertEqual(RealmPanel.lairsLine([lair]), "Only a rally's host breaks a lair: select its ground and call one against it.")
        XCTAssertEqual(RealmPanel.lairsLine([lair, gate]), RealmPanel.lairsLine([lair]) + " " + RealmPanel.lairsLine([gate]))
        XCTAssertTrue(HoverInfo.named(gate).hasPrefix("the South-East Gate of the Crown, held by the wilds, \(gate.might) of \(gate.might) standing"))
        XCTAssertTrue(HoverInfo.named(lair).hasSuffix("only a rally's host breaks it"))
    }

    /// One of the Drowned an eclipse raised is named under the pointer
    /// with the keepsake it bears; and while they walk, the moon's light
    /// all but goes from the world.
    @MainActor
    func testTheEclipseIsToldAndSeen() throws {
        let drowned = Wild(id: 7, kind: .drowned, level: 3, position: Hex(2, 2), raised: 60, keepsake: "Dunmere")
        XCTAssertEqual(HoverInfo.named(drowned), "The Drowned, level III, bearing a keepsake of Dunmere")
        XCTAssertEqual(HoverInfo.named(Wild(id: 8, kind: .drowned, level: 3, position: Hex(2, 2), raised: 60)), "The Drowned, level III")
        XCTAssertEqual(GameSession.cue(forDepth: .eclipse(risen: 3), in: nil, player: 0), .dread)
        var state = GameState(settings: GameSettings(seedText: "an eaten moon in the app", houseCount: 4, radius: 18, keepers: 1))
        let session = GameSession(state: state, store: LocalStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("eclipse-\(UUID().uuidString)")))
        XCTAssertNotEqual(session.sceneFrame(at: 1).weather, .eclipse)
        // The moon eaten, though none of the Drowned is in the keeper's sight.
        state.wilds = [drowned]
        state.eclipse = state.watch
        let eaten = GameSession(state: state, store: LocalStore(directory: FileManager.default.temporaryDirectory
            .appendingPathComponent("eclipse-\(UUID().uuidString)")))
        XCTAssertEqual(eaten.sceneFrame(at: 1).weather, .eclipse)
    }
}
