import LauncherCore
import XCTest
@testable import LauncherKit

/// The launcher's model over time: the opening playing out, the model
/// checked again until it is ready, keys typed by a test build once the
/// opening is over, news fetched once while fresh, Play with nowhere to
/// go, and the settings link that can't be opened.
@MainActor
final class LauncherModelTimingTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!

    override func setUp() async throws {
        suiteName = "LauncherModelTimingTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    private final class World {
        var readiness = ModelReadiness.ready
        var downloads = 0
        var opened: [URL] = []
        var opens = true
    }

    private func model(_ world: World) -> LauncherModel {
        let environment = LauncherEnvironment(
            modelReadiness: { world.readiness },
            systemSavesEnergy: { false },
            downloadNews: {
                world.downloads += 1
                return try JSONEncoder().encode(["items": [["id": "a", "date": "2026-10-27", "title": "Still water", "body": "The lake lies still."]]])
            },
            open: { url in
                world.opened.append(url)
                return world.opens
            },
            terminate: {}
        )
        return LauncherModel(defaults: defaults, environment: environment)
    }

    private func until(_ what: String, timeout: Double, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { return XCTFail("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
    }

    func testTheOpeningPlaysOutInFullMotion() async throws {
        let model = model(World())
        model.beginIntro(systemReducesMotion: false)
        XCTAssertFalse(model.intro.showsMenu, "The menu waits for the lake and the title")
        try await until("the scene", timeout: 2) { model.intro.showsScene }
        try await until("the title", timeout: 3) { model.intro.showsTitle }
        try await until("the menu", timeout: 4) { model.intro.showsMenu }
        model.beginIntro(systemReducesMotion: false)
        XCTAssertEqual(model.intro, .complete, "Once is enough")

        let reduced = self.model(World())
        reduced.beginIntro(systemReducesMotion: true)
        try await until("the opening, at once", timeout: 1) { reduced.intro == .complete }
    }

    func testTheModelIsCheckedAgainUntilItIsReady() async throws {
        let world = World()
        world.readiness = .modelNotReady
        let model = model(world)
        model.refreshReadiness()
        XCTAssertTrue(model.isGated)
        world.readiness = .ready
        try await until("the model to be found ready", timeout: 7) { !model.isGated }
    }

    func testATestBuildTypesItsKeysOnceTheOpeningIsOver() async throws {
        let key = "NULLMERE_LAUNCHER_KEYS"
        setenv(key, "right", 1)
        defer { unsetenv(key) }
        let model = model(World())
        unsetenv(key)
        model.completeIntro()
        model.refreshReadiness()
        XCTAssertEqual(model.menuSelection, .play)
        try await until("the key", timeout: 9) { model.menuSelection == .news }
    }

    func testNewsIsFetchedOnceWhileFresh() async throws {
        let world = World()
        let model = model(world)
        await model.refreshNews()
        await model.refreshNews()
        XCTAssertEqual(world.downloads, 1, "Fresh news isn't fetched again")
        XCTAssertEqual(model.news.items.first?.title, "Still water")
        let item = try XCTUnwrap(model.visibleNews.first)
        model.newsSelection = 2
        model.selectNews(item)
        XCTAssertEqual(model.newsSelection, 0)
    }

    func testPlayWaitsForTheWayInAndNotAsTheModelGoes() {
        let world = World()
        let model = model(world)
        model.refreshReadiness()
        model.completeIntro()
        model.play()
        XCTAssertEqual(model.screen, .title, "No way into the realm given yet: Play waits")
        XCTAssertFalse(model.isLeaving, "and nothing fades")

        model.enterRealm = {}
        world.readiness = .appleIntelligenceNotEnabled
        model.play()
        XCTAssertTrue(model.isGated, "The model went away: the requirement screen says why")
        XCTAssertFalse(model.isLeaving)
    }

    func testTheSettingsLinkFallsBackToSystemSettings() {
        let world = World()
        world.opens = false
        model(world).openAppleIntelligenceSettings()
        XCTAssertEqual(world.opened.count, 2, "Apple Intelligence's pane, then System Settings itself")
        let live = LauncherModel(defaults: defaults)
        XCTAssertEqual(live.screen, .title)
    }
}
