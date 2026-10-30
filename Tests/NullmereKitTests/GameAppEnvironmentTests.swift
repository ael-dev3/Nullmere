import Foundation
import LauncherCore
import LauncherKit
import NullmereRealm
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// What the app takes from its surroundings: which realm, and where its
/// key is kept; a test build stepping straight in and setting the scene;
/// the realm's refusals at the door; and the model asked after until it
/// is ready.
@MainActor
final class GameAppEnvironmentTests: XCTestCase {
    private var dir: URL!
    private let names = ["NULLMERE_REALM", "NULLMERE_REALM_SEED", "NULLMERE_IDENTITY_FILE", "NULLMERE_KEEPER",
                         "NULLMERE_AUTOPLAY", "NULLMERE_SHOW", "NULLMERE_WATCH_AFTER", "NULLMERE_STORE"]
    private var saved: [String: String] = [:]

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        saved = [:]
        for name in names {
            if let value = ProcessInfo.processInfo.environment[name] { saved[name] = value }
            unsetenv(name)
        }
    }

    override func tearDown() async throws {
        for name in names { unsetenv(name) }
        for (name, value) in saved { setenv(name, value, 1) }
        try? FileManager.default.removeItem(at: dir)
    }

    private func until(_ what: String, timeout: Double = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw NSError(domain: "GameAppEnvironmentTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(what)"]) }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func hostedApp(_ seed: String, readiness: @escaping () -> ModelReadiness = { .ready }) -> GameApp {
        let address = GameApp.RealmAddress.hosted(seed: seed)
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: address))
        return GameApp(store: LocalStore(directory: dir), readiness: readiness, sound: false, address: address,
                       identity: FileIdentityStore(url: dir.appendingPathComponent("identity")), opensAtOnce: false)
    }

    func testByDefaultTheSystemIsAskedAfterTheModel() {
        let app = GameApp(store: LocalStore(directory: dir), sound: false, address: .hosted(seed: "the system asked"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")), opensAtOnce: false)
        app.checkModel()
        XCTAssertEqual(app.readiness, OnDeviceModel.current(), "What Apple's framework says of this Mac")
    }

    func testTheRealmAndTheKeyComeFromTheBuildAndItsSurroundings() {
        XCTAssertEqual(GameApp.defaultAddress, .network(GameApp.maincloudURL), "The realm proper, by default")
        setenv("NULLMERE_REALM", "local", 1)
        XCTAssertEqual(GameApp.defaultAddress, .hosted(seed: "the still water"))
        setenv("NULLMERE_REALM_SEED", "another night", 1)
        XCTAssertEqual(GameApp.defaultAddress, .hosted(seed: "another night"))
        setenv("NULLMERE_REALM", "http://127.0.0.1:3000/nullmere", 1)
        XCTAssertEqual(GameApp.defaultAddress, .network(URL(string: "http://127.0.0.1:3000/nullmere")!))
        setenv("NULLMERE_REALM", "ftp://realm.test/nullmere", 1)
        XCTAssertEqual(GameApp.defaultAddress, .network(GameApp.maincloudURL), "Only a web address names a realm")

        XCTAssertEqual(GameApp.realmURL(in: ["NullmereRealm": "https://realm.test/nullmere"]), URL(string: "https://realm.test/nullmere")!)
        XCTAssertEqual(GameApp.realmURL(in: ["NullmereRealm": "https://realm.test"]), GameApp.maincloudURL, "A server without a database")
        XCTAssertEqual(GameApp.realmURL(in: ["NullmereRealm": "realm"]), GameApp.maincloudURL)
        XCTAssertEqual(GameApp.realmURL(in: nil), GameApp.maincloudURL)

        XCTAssertTrue(GameApp.defaultIdentityStore(for: .hosted(seed: "x")) is KeychainIdentityStore)
        XCTAssertTrue(GameApp.defaultIdentityStore(for: .network(GameApp.maincloudURL)) is KeychainIdentityStore)
        setenv("NULLMERE_IDENTITY_FILE", dir.appendingPathComponent("key").path, 1)
        XCTAssertTrue(GameApp.defaultIdentityStore(for: .network(GameApp.maincloudURL)) is FileIdentityStore)

        XCTAssertEqual(LocalStore().directory.lastPathComponent, "Nullmere Online", "In Application Support, by default")
        setenv("NULLMERE_STORE", dir.path, 1)
        // Compared by path: a folder's URL may or may not end in a slash.
        XCTAssertEqual(LocalStore().directory.path, dir.path, "Or in the UI tests' own folder")
        XCTAssertEqual(LocalStore().hostedRealmURL.deletingLastPathComponent().path, dir.path)
    }

    func testATestBuildStepsInAndSetsTheScene() async throws {
        setenv("NULLMERE_KEEPER", "Ama", 1)
        setenv("NULLMERE_AUTOPLAY", "2", 1)
        setenv("NULLMERE_SHOW", "seat,unit,houses,watch", 1)
        setenv("NULLMERE_WATCH_AFTER", "0.2", 1)
        let app = hostedApp("steps in")
        app.checkModel()
        try await until("the keeper to step in") { app.session != nil }
        let session = try XCTUnwrap(app.session)
        XCTAssertEqual(app.keeperName, "Ama")
        XCTAssertEqual(session.panel, .houses)
        XCTAssertNil(session.seatBriefing, "The briefing is put away unless asked for")
        XCTAssertTrue(session.keepsWatchCard)
        let watch = session.state.watch
        try await until("the watch to turn") { session.state.watch > watch }
        app.leaveWorld()
    }

    func testATestBuildCanKeepTheBriefingAndOpenOtherPanels() async throws {
        setenv("NULLMERE_KEEPER", "Bel", 1)
        setenv("NULLMERE_SHOW", "briefing,chronicle,guide", 1)
        let app = hostedApp("keeps the briefing")
        app.checkModel()
        try await until("the keeper to step in") { app.session != nil }
        let session = try XCTUnwrap(app.session)
        XCTAssertNotNil(session.seatBriefing, "Kept, as asked")
        XCTAssertEqual(session.panel, .guide, "The last panel asked for")
        app.leaveWorld()
    }

    func testTheDoorTellsOfTheRealmsRefusals() throws {
        let app = hostedApp("refusals")
        app.checkModel()
        app.hear(.refused(.unknownKeeper))
        XCTAssertNil(app.keeperName)
        XCTAssertEqual(app.arrivalProblem, "The realm doesn't know you yet. Choose the name you'll go by.")
        XCTAssertFalse(app.isEntering)
        app.hear(.refused(.nameInvalid))
        XCTAssertEqual(app.arrivalProblem, RealmError.nameInvalid.description)
        app.askForSeat()
        XCTAssertFalse(app.isWaitingForSeat, "Not waiting: there's no seat to ask after")
        app.leaveDoor()
    }

    /// The app asks after the model by itself, every few seconds while it is
    /// in front, and opens the door the moment it is ready; never while it is
    /// behind another app.
    func testTheModelIsAskedAfterUntilItIsReady() async throws {
        var readiness = ModelReadiness.modelNotReady
        var inFront = false
        let app = hostedApp("asked after", readiness: { readiness })
        app.recheckSeconds = 0.05
        app.isFrontmost = { inFront }
        app.checkModel()
        guard case .gate = app.phase else { return XCTFail("The gate, while the model downloads") }
        readiness = .ready
        try await Task.sleep(nanoseconds: 400_000_000)
        guard case .gate = app.phase else { return XCTFail("Not asked after while the app is behind another") }
        inFront = true
        try await until("the model asked after, in front") {
            if case .frontDoor = app.phase { return true }
            return false
        }
        app.leaveDoor()
    }
}
