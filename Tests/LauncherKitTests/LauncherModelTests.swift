import LauncherCore
import XCTest
@testable import LauncherKit

@MainActor
final class LauncherModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var opened: [URL] = []
    private var launchedGames: [URL] = []
    private var terminated = false

    override func setUp() async throws {
        suiteName = "LauncherModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        opened = []
        launchedGames = []
        terminated = false
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// A model whose outside world is this test: links, games and quitting
    /// are recorded, not carried out. `readiness` is read afresh on every
    /// check, so a test can change it along the way.
    private func makeModel(
        readiness: @autoclosure @escaping () -> ModelReadiness = .ready,
        game: URL? = nil,
        news: Data? = nil
    ) -> LauncherModel {
        let environment = LauncherEnvironment(
            modelReadiness: readiness,
            installedGame: { game },
            openGame: { [weak self] url in self?.launchedGames.append(url) },
            downloadNews: {
                guard let news else { throw URLError(.notConnectedToInternet) }
                return news
            },
            open: { [weak self] url in
                self?.opened.append(url)
                return true
            },
            terminate: { [weak self] in self?.terminated = true }
        )
        return LauncherModel(defaults: defaults, environment: environment)
    }

    func testFirstKeySkipsTheIntro() {
        let model = makeModel()
        model.handle(.right)
        XCTAssertEqual(model.intro, .complete)
        XCTAssertEqual(model.menuSelection, .play, "The skipping key press should not also navigate")
    }

    func testTheMenuRunsAlongTheWater() {
        let model = makeModel()
        model.completeIntro()

        model.handle(.right)
        XCTAssertEqual(model.menuSelection, .news)
        model.handle(.right)
        XCTAssertEqual(model.menuSelection, .settings)
        model.handle(.confirm)
        XCTAssertEqual(model.screen, .settings)
        model.handle(.back)
        XCTAssertEqual(model.screen, .title)
        XCTAssertEqual(model.menuSelection, .settings, "Returning keeps the place in the menu")

        model.handle(.down)
        XCTAssertEqual(model.menuSelection, .repository)
        model.handle(.confirm)
        XCTAssertEqual(opened, [Destination.repository])
        XCTAssertEqual(model.screen, .title)

        model.handle(.right)
        XCTAssertEqual(model.menuSelection, .quit)
        model.handle(.right)
        XCTAssertEqual(model.menuSelection, .play, "The row wraps around")
        model.handle(.left)
        XCTAssertEqual(model.menuSelection, .quit)
    }

    func testPlayExplainsWhatThisMacIsMissing() {
        let model = makeModel(readiness: .appleIntelligenceNotEnabled, game: URL(fileURLWithPath: "/Applications/Nullmere.app"))
        model.completeIntro()
        model.activate(.play)
        XCTAssertEqual(model.screen, .play, "An installed game still needs the on-device model")
        XCTAssertEqual(model.readiness, .appleIntelligenceNotEnabled)
        XCTAssertFalse(model.isLeaving)

        model.openAppleIntelligenceSettings()
        XCTAssertEqual(opened, [Destination.appleIntelligenceSettings])

        model.handle(.confirm)
        XCTAssertEqual(model.screen, .title)
    }

    func testPlayOpensAnInstalledGameOnAReadyMac() async throws {
        let game = URL(fileURLWithPath: "/Applications/Nullmere.app")
        let model = makeModel(readiness: .ready, game: game)
        model.completeIntro()
        model.activate(.play)
        XCTAssertTrue(model.isLeaving, "The launcher fades out")
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertEqual(launchedGames, [game])
        XCTAssertTrue(terminated, "The launcher hands over to the game and quits")
    }

    func testWaitingOnPlayContinuesOnceTheModelIsReady() async throws {
        var state = ModelReadiness.modelNotReady
        let game = URL(fileURLWithPath: "/Applications/Nullmere.app")
        let model = makeModel(readiness: state, game: game)
        model.completeIntro()
        model.activate(.play)
        XCTAssertEqual(model.screen, .play)
        XCTAssertFalse(model.isLeaving)

        state = .ready
        model.refreshReadiness()
        XCTAssertEqual(model.readiness, .ready)
        XCTAssertTrue(model.isLeaving)
        try await Task.sleep(for: .milliseconds(1100))
        XCTAssertEqual(launchedGames, [game])
    }

    func testTheModelBecomingReadyElsewhereDoesNotLaunchTheGame() {
        var state = ModelReadiness.appleIntelligenceNotEnabled
        let model = makeModel(readiness: state, game: URL(fileURLWithPath: "/Applications/Nullmere.app"))
        model.completeIntro()
        model.refreshReadiness()
        state = .ready
        model.refreshReadiness()
        XCTAssertEqual(model.readiness, .ready)
        XCTAssertFalse(model.isLeaving, "Only someone waiting on the Play panel crosses by themselves")
        model.pauseReadinessChecks()
    }

    func testQuitFadesThenQuits() async throws {
        let model = makeModel()
        model.completeIntro()
        model.activate(.quit)
        XCTAssertTrue(model.isLeaving)
        model.handle(.confirm)
        XCTAssertFalse(terminated, "Quitting waits for the fade")
        try await Task.sleep(for: .milliseconds(900))
        XCTAssertTrue(terminated)
    }

    func testPlayOnAReadyMacWaitsForTheFirstRealm() {
        let model = makeModel(readiness: .ready, game: nil)
        model.completeIntro()
        model.activate(.play)
        XCTAssertEqual(model.screen, .play)
        XCTAssertTrue(model.readiness.allowsPlay)
        XCTAssertFalse(model.gameFailedToOpen)
    }

    func testReadinessIsReadFromTheSystem() {
        let model = makeModel(readiness: .deviceNotEligible)
        XCTAssertEqual(model.readiness, .checking)
        model.refreshReadiness()
        XCTAssertEqual(model.readiness, .deviceNotEligible)
    }

    func testNewsKeysChooseAStoryAndOpenItsLink() throws {
        let model = makeModel()
        model.completeIntro()
        model.show(.news)
        XCTAssertEqual(model.visibleNews, Array(NewsFeed.builtIn.items.prefix(LauncherModel.visibleNewsCount)))

        model.handle(.down)
        XCTAssertEqual(model.newsSelection, 1)
        for _ in 0..<5 { model.handle(.down) }
        XCTAssertEqual(model.newsSelection, model.visibleNews.count - 1, "Selection stops at the last story")
        for _ in 0..<5 { model.handle(.up) }
        XCTAssertEqual(model.newsSelection, 0)

        let link = try XCTUnwrap(model.visibleNews[0].link)
        model.handle(.confirm)
        XCTAssertEqual(opened, [link])
        model.handle(.back)
        XCTAssertEqual(model.screen, .title)
    }

    func testNewsUpdatesFromTheRepositoryAndIsSaved() async throws {
        let feed = Data(#"{"items": [{"id": "tide", "date": "2026-11-02", "title": "Tide", "body": "Fresh from the feed."}]}"#.utf8)
        let model = makeModel(news: feed)
        XCTAssertEqual(model.news, NewsFeed.builtIn)

        await model.refreshNews()
        XCTAssertEqual(model.newsStatus, .current)
        XCTAssertEqual(model.news.items.map(\.title), ["Tide"])

        let reopened = makeModel()
        XCTAssertEqual(reopened.news.items.map(\.title), ["Tide"], "The next launch starts from the saved copy")
    }

    func testNewsStaysOnShowWhenOffline() async {
        let model = makeModel(news: nil)
        await model.refreshNews()
        XCTAssertEqual(model.newsStatus, .offline)
        XCTAssertEqual(model.news, NewsFeed.builtIn)
    }

    func testSettingsChangesArePersisted() {
        let model = makeModel()
        model.show(.settings)

        model.handle(.right) // Motion: System → Full
        model.handle(.down)
        model.handle(.down)
        model.handle(.left) // Frame rate: 60 → 30
        model.choose(1, for: .startsInFullScreen)

        let stored = LauncherSettings(defaults: defaults)
        XCTAssertEqual(stored.motion, .full)
        XCTAssertEqual(stored.frameRate, .thirty)
        XCTAssertTrue(stored.startsInFullScreen)
        XCTAssertEqual(makeModel().settings, stored)
    }

    func testBackdropFollowsSettings() {
        LauncherSettings(motion: .still, quality: .efficient, frameRate: .thirty).save(to: defaults)
        let configuration = makeModel().backdropConfiguration(systemReducesMotion: false)
        XCTAssertEqual(configuration.motion, .still)
        XCTAssertEqual(configuration.renderScale, 0.5)
        XCTAssertEqual(configuration.framesPerSecond, 30)
        XCTAssertEqual(configuration.horizon, LakeComposition.horizon)
    }
}
