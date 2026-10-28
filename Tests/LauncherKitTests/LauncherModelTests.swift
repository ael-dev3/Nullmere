import LauncherCore
import XCTest
@testable import LauncherKit

@MainActor
final class LauncherModelTests: XCTestCase {
    private var defaults: UserDefaults!
    private var suiteName: String!
    private var opened: [URL] = []
    private var crossings = 0
    private var terminated = false

    override func setUp() async throws {
        suiteName = "LauncherModelTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        opened = []
        crossings = 0
        terminated = false
    }

    override func tearDown() async throws {
        defaults.removePersistentDomain(forName: suiteName)
    }

    /// A model whose outside world is this test: links, games and quitting
    /// are recorded, not carried out. `readiness` and `savesEnergy` are read
    /// afresh on every check, so a test can change them along the way. Like
    /// the window appearing, making the model checks both once unless told
    /// not to.
    private func makeModel(
        readiness: @autoclosure @escaping () -> ModelReadiness = .ready,
        savesEnergy: @autoclosure @escaping () -> Bool = false,
        realm: Bool = false,
        news: Data? = nil,
        appeared: Bool = true
    ) -> LauncherModel {
        let environment = LauncherEnvironment(
            modelReadiness: readiness,
            systemSavesEnergy: savesEnergy,
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
        let model = LauncherModel(defaults: defaults, environment: environment)
        if realm {
            model.enterRealm = { [weak self] in self?.crossings += 1 }
        }
        if appeared {
            model.refreshReadiness()
            model.refreshEnergyState()
        }
        return model
    }

    /// Waits for something the launcher does after a delay, such as quitting
    /// once its fade has finished, and fails if it doesn't happen in time.
    private func waitUntil(
        _ condition: @autoclosure () -> Bool,
        timeout: Duration = .seconds(5),
        file: StaticString = #filePath,
        line: UInt = #line
    ) async throws {
        let deadline = ContinuousClock.now + timeout
        while !condition() {
            guard ContinuousClock.now < deadline else {
                XCTFail("Timed out after \(timeout)", file: file, line: line)
                return
            }
            try await Task.sleep(for: .milliseconds(20))
        }
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

    func testAMacWithoutTheModelSeesOnlyWhatIsMissing() async throws {
        let model = makeModel(readiness: .deviceNotEligible, realm: true)
        model.completeIntro()
        XCTAssertTrue(model.isGated)
        XCTAssertNil(model.footerHint)

        // Nothing behind the requirement screen can be reached.
        model.handle(.right)
        model.handle(.down)
        model.activate(.play)
        model.activate(.news)
        model.show(.settings)
        model.openNews()
        XCTAssertEqual(model.screen, .title)
        XCTAssertEqual(model.menuSelection, .play)
        XCTAssertEqual(crossings, 0, "No way into the realm")

        // Quit is all there is.
        XCTAssertEqual(model.readiness.actions, [.quit])
        model.handle(.back)
        XCTAssertFalse(model.isLeaving)
        model.handle(.confirm)
        XCTAssertTrue(model.isLeaving)
        try await waitUntil(self.terminated)
    }

    func testTheLauncherOpensOnceAppleIntelligenceIsOn() {
        var state = ModelReadiness.appleIntelligenceNotEnabled
        let model = makeModel(readiness: state)
        model.completeIntro()
        XCTAssertTrue(model.isGated)
        XCTAssertEqual(model.readiness.actions, [.openSystemSettings, .quit])
        XCTAssertEqual(model.requirementSelection, 0)

        model.handle(.confirm)
        XCTAssertEqual(opened, [Destination.appleIntelligenceSettings])
        model.handle(.right)
        XCTAssertEqual(model.requirementSelection, 1)
        model.handle(.right)
        XCTAssertEqual(model.requirementSelection, 1, "Selection stops at the last action")
        model.handle(.left)
        XCTAssertEqual(model.requirementSelection, 0)

        state = .ready
        model.refreshReadiness()
        XCTAssertFalse(model.isGated, "The launcher opens by itself")
        model.handle(.right)
        XCTAssertEqual(model.menuSelection, .news)
        model.handle(.confirm)
        XCTAssertEqual(model.screen, .news)

        state = .modelNotReady
        model.refreshReadiness()
        XCTAssertTrue(model.isGated, "It closes again if the model goes away")
        XCTAssertEqual(model.readiness.actions, [.quit])
        model.pauseReadinessChecks()
    }

    func testNothingIsOfferedWhileStillChecking() {
        let model = makeModel(appeared: false)
        model.completeIntro()
        XCTAssertEqual(model.readiness, .checking)
        XCTAssertTrue(model.isGated)
        model.handle(.right)
        model.handle(.confirm)
        XCTAssertFalse(model.isLeaving, "A stray key can't quit before the check")
        XCTAssertEqual(model.requirementSelection, 0)
    }

    func testPlayCrossesIntoTheRealmOnAReadyMac() async throws {
        let model = makeModel(readiness: .ready, realm: true)
        model.completeIntro()
        model.activate(.play)
        XCTAssertTrue(model.isLeaving, "The launcher fades out")
        try await waitUntil(self.crossings == 1)
        XCTAssertFalse(terminated, "The app stays: the realm takes the window")
        model.returnFromRealm()
        XCTAssertFalse(model.isLeaving, "Back from the realm, the launcher shows again")
        XCTAssertEqual(model.screen, .title)
    }

    func testQuitFadesThenQuits() async throws {
        let model = makeModel()
        model.completeIntro()
        model.activate(.quit)
        XCTAssertTrue(model.isLeaving)
        model.handle(.confirm)
        XCTAssertFalse(terminated, "Quitting waits for the fade")
        try await waitUntil(self.terminated)
    }

    func testPlayWithNoWayIntoARealmSaysSo() {
        let model = makeModel(readiness: .ready)
        model.completeIntro()
        model.activate(.play)
        XCTAssertEqual(model.screen, .play)
        XCTAssertTrue(model.readiness.allowsPlay)
    }

    func testThePlayPanelLightsWhatReturnDoes() {
        let model = makeModel(readiness: .ready)
        model.completeIntro()
        model.activate(.play)
        XCTAssertEqual(model.playSelection, .back, "The panel opens with Return lit")

        model.handle(.left)
        XCTAssertEqual(model.playSelection, .website)
        model.handle(.left)
        XCTAssertEqual(model.playSelection, .website, "The row doesn't wrap")
        model.handle(.confirm)
        XCTAssertEqual(opened, [Destination.website])
        XCTAssertEqual(model.screen, .play)

        model.handle(.right)
        model.handle(.confirm)
        XCTAssertEqual(model.screen, .title)
        model.activate(.play)
        XCTAssertEqual(model.playSelection, .back, "Return is lit again next time")
    }

    func testReadinessIsReadFromTheSystem() {
        let model = makeModel(readiness: .deviceNotEligible, appeared: false)
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

    func testNewsSaysWhenTheFeedCannotBeRead() async {
        let model = makeModel(news: Data("<html>404: Not Found</html>".utf8))
        await model.refreshNews()
        XCTAssertEqual(model.newsStatus, .unavailable, "Online, but the answer wasn't a feed")
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

    func testAPanelVeilsTheMoonsImage() {
        let model = makeModel()
        func veil() -> Double { model.backdropConfiguration(systemReducesMotion: false).veil }
        XCTAssertEqual(veil(), 0, "The menu leaves the moon's image whole")
        for screen in [LauncherModel.Screen.news, .settings, .play] {
            model.show(screen)
            XCTAssertEqual(veil(), 1, "Under \(screen)")
        }
        model.show(.title)
        XCTAssertEqual(veil(), 0)
        XCTAssertEqual(makeModel(readiness: .appleIntelligenceNotEnabled).backdropConfiguration(systemReducesMotion: false).veil, 1,
                       "Under the requirement")
    }

    func testTheLakeSlowsDownToSaveEnergy() {
        LauncherSettings(motion: .full, frameRate: .oneTwenty).save(to: defaults)
        var lowPowerMode = false
        let model = makeModel(savesEnergy: lowPowerMode)
        func framesPerSecond() -> Int {
            model.backdropConfiguration(systemReducesMotion: false).framesPerSecond
        }
        XCTAssertEqual(framesPerSecond(), 120)

        model.didResignActive()
        XCTAssertEqual(framesPerSecond(), 30, "Behind another app")
        model.didBecomeActive()
        XCTAssertEqual(framesPerSecond(), 120)

        lowPowerMode = true
        model.refreshEnergyState()
        XCTAssertEqual(framesPerSecond(), 30, "In Low Power Mode")
        XCTAssertEqual(model.backdropConfiguration(systemReducesMotion: false).motion, .full, "What moves stays the same")
    }
}
