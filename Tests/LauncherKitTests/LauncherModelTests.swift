import LauncherCore
import XCTest
@testable import LauncherKit

@MainActor
final class LauncherModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var opened: [URL] = []

    override func setUp() async throws {
        suiteName = "LauncherModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        opened = []
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// A model whose outside world is this test: links are recorded, not opened.
    private func makeModel(
        readiness: ModelReadiness = .ready,
        game: URL? = nil,
        news: Data? = nil
    ) -> LauncherModel {
        let environment = LauncherEnvironment(
            modelReadiness: { readiness },
            installedGame: { game },
            openGame: { _ in },
            downloadNews: {
                guard let news else { throw URLError(.notConnectedToInternet) }
                return news
            },
            open: { [weak self] url in
                self?.opened.append(url)
                return true
            }
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
