import Foundation
@testable import LauncherKit
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
        let address = GameApp.RealmAddress.network(URL(string: "https://realm.test/\(realm)")!)
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

        // The keeper writes a name at the door and presses Enter: one letter
        // is refused, and said so; a good name goes in.
        PressableButtons.isListening = true
        defer { PressableButtons.isListening = false }
        XCTAssertNotNil(RealmState.nameProblem("A"))
        PressableButtons.forget("Enter World")
        draw(FrontDoor(app: app, name: "A"))
        XCTAssertFalse(PressableButtons.press("Enter World"), "Not with a name of one letter")
        draw(FrontDoor(app: app, name: "Ama"))
        XCTAssertTrue(PressableButtons.press("Enter World"))
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
        // The door says every seat is held, and what entering means then.
        draw(FrontDoor(app: second))
        second.enterWorld(name: "Bel")
        try await until("Bel to wait") { second.isWaitingForSeat }
        XCTAssertNil(second.session, "No seat, no world")
        XCTAssertEqual(second.keeperName, "Bel", "Known to the realm all the same")
        // The clock asks again after a seat; none has fallen free.
        XCTAssertNotNil(second.seatTimer)
        second.seatTimer?.fire()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(second.isWaitingForSeat, "Still waiting")
        XCTAssertNil(second.session)
        draw(FrontDoor(app: second))
        second.leaveDoor()
        XCTAssertFalse(second.isWaitingForSeat)
        first.leaveWorld()
        XCTAssertNil(first.session)
    }

    func testTheRealmOutOfReachAtTheDoorAndInTheWorld() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let identity = MemoryStore()
        let app = app(db, identity: identity, realm: "reach")
        await db.setReachable(false)
        app.open()
        try await until("the door to find the realm out of reach") { if case .unreachable = app.door { return true } else { return false } }
        XCTAssertFalse(app.canEnter(with: "Ama"), "No way in to a realm that doesn't answer")
        draw(FrontDoor(app: app))

        // Try Again, once it answers.
        await db.setReachable(true)
        app.openDoor()
        try await until("the realm to answer again") { if case .open = app.door { return true } else { return false } }
        app.enterWorld(name: "Ama")
        try await until("the world") { app.session != nil }
        let session = try XCTUnwrap(app.session)

        // Lost in play: the keeper is told once, and told again when it answers.
        await db.setReachable(false)
        try await until("the keeper to be told") { session.isOutOfReach }
        XCTAssertEqual(session.notices.filter { $0.text.contains("out of reach") }.count, 1)
        draw(GameRootView(app: app))
        await db.setReachable(true)
        try await until("the realm to answer again") { !session.isOutOfReach }
        XCTAssertEqual(session.notices.last?.text, "The realm answers again.")
        app.leaveWorld()
    }

    func testANameAlreadyHeldIsRefused() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let first = app(db, identity: MemoryStore(), realm: "names-first")
        first.open()
        try await until("the realm") { if case .open = first.door { return true } else { return false } }
        first.enterWorld(name: "Ama")
        try await until("Ama's seat") { first.session != nil }

        let second = app(db, identity: MemoryStore(), realm: "names-second")
        second.open()
        try await until("the realm") { if case .open = second.door { return true } else { return false } }
        second.enterWorld(name: "Ama")
        try await until("the refusal") { second.arrivalProblem != nil }
        XCTAssertEqual(second.arrivalProblem, "Another keeper already goes by that name.")
        XCTAssertNil(second.session)
        XCTAssertFalse(second.isEntering, "The door is open to try another name")
        draw(FrontDoor(app: second))
        second.enterWorld(name: "Bel")
        try await until("Bel's seat") { second.session != nil }
        XCTAssertNil(second.arrivalProblem)
        first.leaveWorld()
        second.leaveWorld()
    }

    /// A door tried again lets the old link go, so nothing it still has on
    /// its way can be taken for the new one's; the game's sound is wanted
    /// at the door and let go in the launcher, the score as the keeper left it.
    func testTheDoorLetsGoWhatItLeaves() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let defaults = UserDefaults.standard
        let kept = defaults.object(forKey: "music.enabled")
        defaults.set(false, forKey: "music.enabled")
        defer { kept == nil ? defaults.removeObject(forKey: "music.enabled") : defaults.set(kept, forKey: "music.enabled") }
        let app = app(db, identity: MemoryStore(), realm: "lets go")
        XCTAssertFalse(app.ambience.isMusicOn, "The score stays off from the first")
        app.open()
        XCTAssertTrue(app.ambience.isWanted, "Sound is wanted at the door")
        try await until("the door open") { if case .open = app.door { return true } else { return false } }
        let old = try XCTUnwrap(app.link)
        XCTAssertNotNil(old.onEvent)
        app.openDoor()
        XCTAssertNil(old.onEvent, "The old link is let go")
        XCTAssertFalse(app.link === old)
        try await until("the door open again") { if case .open = app.door { return true } else { return false } }

        app.leaveDoor()
        XCTAssertFalse(app.ambience.isWanted, "Back in the launcher, the game's sound goes")
        XCTAssertFalse(app.ambience.isAtWar)
        app.open()
        XCTAssertTrue(app.ambience.isWanted, "and comes back with the door")
        app.leaveDoor()
    }

    func testAnAddressWithoutADatabaseIsSaidPlainly() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dirs.append(dir)
        let address = GameApp.RealmAddress.network(URL(string: "https://realm.test")!)
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: address,
                          identity: MemoryStore(), opensAtOnce: false, transport: nil, pollInterval: 1)
        app.open()
        XCTAssertEqual(app.door, .unreachable("The realm's address can't be read."))
        XCTAssertFalse(app.canEnter(with: "Ama"))
        draw(FrontDoor(app: app))
    }
}
