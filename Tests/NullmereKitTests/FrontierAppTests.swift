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
    }
}
