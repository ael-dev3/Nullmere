import Foundation
import NullmereRealm
import NullmereTestSupport
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The app against a realm across the network, as a keeper meets it: the
/// front door reaching the realm, a new keeper entering by name, playing,
/// the realm forgetting this Mac's key, and a keeper waiting for a seat.
/// SpacetimeDB is held in memory, with the realm's own steward beside it.
@MainActor
final class NetworkAppTests: XCTestCase {
    private var dirs: [URL] = []

    override func tearDown() async throws {
        for dir in dirs { try? FileManager.default.removeItem(at: dir) }
    }

    private func until(_ what: String, timeout: Double = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw NSError(domain: "NetworkAppTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(what)"]) }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func steward(_ db: FakeSpacetime, seats: Int) async throws -> Task<Void, Never> {
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "network app",
                                             seats: seats, watchLength: 600, now: 0)
        return Task { await steward.run(clock: { 1 }) }
    }

    private func app(_ db: FakeSpacetime, identity: MemoryStore, realm: String) -> GameApp {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dirs.append(dir)
        let address = RealmAddress.network(URL(string: "https://realm.test/\(realm)")!)
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: address))
        return GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: address, identity: identity,
                       opensAtOnce: false, transport: db, pollInterval: 0.05)
    }

    private func draw(_ view: some View) {
        let renderer = ImageRenderer(content: view.frame(width: 1100, height: 720).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    func testAKeeperEntersPlaysAndIsForgotten() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let identity = MemoryStore()
        let app = app(db, identity: identity, realm: "enters")
        app.open()
        guard case .frontDoor = app.phase else { return XCTFail("A ready model opens the front door") }
        draw(FrontDoor(app: app))
        try await until("the realm's status") { if case .open = app.door { return true } else { return false } }
        guard case .open(let status) = app.door else { return }
        XCTAssertEqual(status.freeSeats, 4)
        XCTAssertFalse(app.canEnter(with: "A"), "A name of one letter won't do")
        XCTAssertTrue(app.canEnter(with: "Ama"))
        draw(FrontDoor(app: app))

        app.enterWorld(name: "Ama")
        XCTAssertTrue(app.isEntering)
        draw(FrontDoor(app: app))
        try await until("the world") { app.session != nil }
        let session = try XCTUnwrap(app.session)
        XCTAssertEqual(app.keeperName, "Ama")
        XCTAssertEqual(session.playerHouse.title, "House Ama")
        draw(GameRootView(app: app))

        // An order goes across, and the realm's answer comes back.
        let spear = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .spear })
        XCTAssertTrue(session.perform(.fortify(unit: spear.id)))
        var handled = 0
        for _ in 0..<500 where handled < 1 {
            handled = await db.handled(kind: "order")
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertGreaterThanOrEqual(handled, 1, "The steward carried the order out")

        // The realm is begun anew and forgets this Mac's key: back to the
        // door, to choose a name again.
        let credentials = try JSONDecoder().decode(SpacetimeCredentials.self, from: Data(try XCTUnwrap(identity.value).utf8))
        await db.forget(token: credentials.token)
        try await until("the realm to forget the keeper") { app.session == nil && app.arrivalProblem != nil }
        XCTAssertNil(app.keeperName)
        XCTAssertTrue(app.arrivalProblem?.contains("no longer knows") == true, app.arrivalProblem ?? "")
        draw(FrontDoor(app: app))
        app.leaveDoor()
    }

    func testAKeeperWaitsForASeat() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 2)
        defer { running.cancel() }
        var seated: [GameApp] = []
        for (index, name) in ["Ama", "Cor"].enumerated() {
            let keeper = app(db, identity: MemoryStore(), realm: "full-\(index)")
            keeper.open()
            try await until("the realm") { if case .open = keeper.door { return true } else { return false } }
            keeper.enterWorld(name: name)
            try await until("\(name)'s seat") { keeper.session != nil }
            seated.append(keeper)
        }
        let first = seated[0]

        let second = app(db, identity: MemoryStore(), realm: "full-second")
        second.open()
        try await until("the realm, full") { if case .open(let status) = second.door { return status.freeSeats == 0 } else { return false } }
        second.enterWorld(name: "Bel")
        try await until("Bel to wait") { second.isWaitingForSeat }
        XCTAssertNil(second.session, "No seat, no world")
        XCTAssertEqual(second.keeperName, "Bel", "Known to the realm all the same")
        draw(FrontDoor(app: second))
        second.leaveDoor()
        XCTAssertFalse(second.isWaitingForSeat)
        first.leaveWorld()
        XCTAssertNil(first.session)
    }
}
