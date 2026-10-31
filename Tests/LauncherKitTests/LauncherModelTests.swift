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
        XCTAssertEqual(model.menuSelection, .credits)
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
        XCTAssertEqual(model.footerHint, "↑ ↓ choose  ·  Return open  ·  Esc back")
        model.handle(.confirm)
        XCTAssertEqual(opened, [link])

        // A story without a page offers none to open, and Return opens nothing.
        let bare = try XCTUnwrap(model.visibleNews.firstIndex { $0.link == nil })
        model.newsSelection = bare
        XCTAssertEqual(model.footerHint, "↑ ↓ choose  ·  Esc back")
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
        model.handle(.down) // Quality
        model.handle(.down) // Detail
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
        for screen in [LauncherModel.Screen.news, .settings] {
            model.show(screen)
            XCTAssertEqual(veil(), 1, "Under \(screen)")
        }
        model.show(.title)
        XCTAssertEqual(veil(), 0)
        XCTAssertEqual(makeModel(readiness: .appleIntelligenceNotEnabled).backdropConfiguration(systemReducesMotion: false).veil, 1,
                       "Under the requirement")
    }

    func testTheLakeSlowsDownToSaveEnergy() throws {
        LauncherSettings(motion: .system, frameRate: .oneTwenty).save(to: defaults)
        var lowPowerMode = false
        let model = makeModel(savesEnergy: lowPowerMode)
        func framesPerSecond() -> Int {
            model.backdropConfiguration(systemReducesMotion: false).framesPerSecond
        }
        XCTAssertEqual(framesPerSecond(), 120)
        XCTAssertNil(model.frameRateNote(systemReducesMotion: false), "As chosen: nothing to say")
        XCTAssertEqual(model.frameRateNote(systemReducesMotion: true), "Held to 30 while motion is reduced")
        model.choose(try XCTUnwrap(MotionPreference.allCases.firstIndex(of: .full)), for: .motion)
        XCTAssertNil(model.frameRateNote(systemReducesMotion: true), "Full motion chosen outright: the system's wish doesn't hold it")
        model.choose(try XCTUnwrap(MotionPreference.allCases.firstIndex(of: .system)), for: .motion)

        model.didResignActive()
        XCTAssertEqual(framesPerSecond(), 30, "Behind another app")
        XCTAssertEqual(model.frameRateNote(systemReducesMotion: false), "Held to 30 behind another app")
        model.didBecomeActive()
        XCTAssertEqual(framesPerSecond(), 120)

        lowPowerMode = true
        model.refreshEnergyState()
        XCTAssertEqual(framesPerSecond(), 30, "In Low Power Mode")
        XCTAssertEqual(model.frameRateNote(systemReducesMotion: false), "Held to 30 while this Mac saves energy")
        XCTAssertEqual(model.backdropConfiguration(systemReducesMotion: false).motion, .full, "What moves stays the same")
    }

    /// The realm's Settings show and set the launcher's own display
    /// settings: one Motion, Resolution and Frame rate for the lake and the
    /// map, kept where the launcher keeps them.
    func testTheRealmsSettingsSetTheLaunchersDisplay() {
        let model = makeModel()
        model.setDisplay(.motion, to: MotionPreference.allCases.firstIndex(of: .still)!)
        model.setDisplay(.frameRate, to: 0)
        XCTAssertEqual(model.displaySettings.motion, .still)
        XCTAssertEqual(model.displaySettings, model.settings, "One set of settings, not two")
        XCTAssertEqual(LauncherSettings(defaults: defaults).motion, .still, "Kept for the next launch")
        XCTAssertEqual(model.backdropConfiguration(systemReducesMotion: false).motion, .still, "The launcher's lake keeps still too")
        model.setDisplay(.motion, to: 99)
        XCTAssertEqual(model.displaySettings.motion, .still, "No such choice: nothing changes")
    }

    /// The type's size is one setting wherever it is set: the launcher's
    /// Text row sets Larger Text, and Larger Text set elsewhere (⇧⌘+, the
    /// realm's Settings) shows in the row at once.
    func testTheTextRowIsLargerText() {
        let model = makeModel()
        defer { TextSize.shared.isLarger = false }
        TextSize.shared.isLarger = false
        model.choose(1, for: .text)
        XCTAssertTrue(TextSize.shared.isLarger, "The launcher's row sets the type's size")
        XCTAssertTrue(LauncherSettings(defaults: defaults).largerText, "Kept with the other settings")
        TextSize.shared.isLarger = false
        XCTAssertFalse(model.settings.largerText, "Set elsewhere, the row follows")
        XCTAssertEqual(model.settings.selectedIndex(for: .text), 0)
    }

    /// After a run that stopped on a fault, the launcher opens on its page:
    /// the arrows choose, Report it writes the report as a new issue for
    /// the keeper to read before sending, Back or Esc goes to the menu, and
    /// Open the world again crosses into the realm; going on or back puts
    /// the page away.
    func testARunThatStoppedOpensOnItsPage() async throws {
        let model = makeModel(realm: true)
        let mishap = Mishap(mark: RunMark(version: "1.2.0", began: 0, place: .world, since: 0, realm: "The Nullmere", watch: 23),
                            cause: "SIGSEGV")
        model.open(on: nil)
        XCTAssertEqual(model.screen, .title, "Nothing to tell")
        model.open(on: mishap)
        model.completeIntro()
        XCTAssertEqual(model.screen, .mishap)
        XCTAssertEqual(model.mishap, mishap)
        XCTAssertEqual(model.footerHint, "← → choose  ·  Esc back")
        model.handle(.right)
        XCTAssertEqual(model.mishapSelection, 1)
        model.handle(.confirm)
        XCTAssertEqual(opened.count, 1)
        XCTAssertTrue(opened.first?.absoluteString.hasPrefix("https://github.com/ael-dev3/Nullmere/issues/new?") == true)
        XCTAssertEqual(model.screen, .mishap, "Still on the page, to go on from")
        model.handle(.right)
        model.handle(.right)
        XCTAssertEqual(model.mishapSelection, 2, "Never past the end")
        model.handle(.back)
        XCTAssertEqual(model.screen, .title)
        XCTAssertNil(model.mishap, "Put away")

        // Again, and into the world.
        model.open(on: mishap)
        XCTAssertEqual(model.mishapSelection, 0, "Open the world again lit first")
        model.handle(.confirm)
        XCTAssertNil(model.mishap)
        try await waitUntil(self.crossings == 1)
    }

    /// The launcher's Music and the realm's are one choice: chosen here, it
    /// is told to whoever plays the score; chosen in the realm, it shows
    /// here without being told back.
    func testMusicIsOneChoiceWithTheRealms() {
        let model = makeModel()
        var heard: [Bool] = []
        model.onMusicChanged = { heard.append($0) }
        XCTAssertTrue(model.settings.music)
        model.choose(0, for: .music)
        XCTAssertFalse(model.settings.music)
        XCTAssertEqual(heard, [false])
        XCTAssertEqual(defaults.object(forKey: "music.enabled") as? Bool, false)
        model.choose(0, for: .music)
        XCTAssertEqual(heard, [false], "Nothing changed, nothing told")
        model.noteMusic(true)
        XCTAssertTrue(model.settings.music)
        XCTAssertEqual(heard, [false], "From the realm, not told back")
        XCTAssertEqual(defaults.object(forKey: "music.enabled") as? Bool, true)
        model.noteMusic(true)
        XCTAssertEqual(heard, [false])
    }

    /// Reset puts every display setting back as it first was, the type's
    /// size, the music and full screen at launch kept as chosen.
    func testResetPutsTheDisplayBack() {
        let model = makeModel()
        model.choose(3, for: .motion)
        model.choose(2, for: .quality)
        model.choose(3, for: .detail)
        model.choose(1, for: .startsInFullScreen)
        XCTAssertEqual(model.settings.detail, .low)
        model.resetDisplay()
        XCTAssertEqual(model.settings.motion, .system)
        XCTAssertEqual(model.settings.quality, .native)
        XCTAssertEqual(model.settings.detail, .auto)
        XCTAssertTrue(model.settings.startsInFullScreen, "Full screen at launch kept as chosen")
        XCTAssertEqual(LauncherSettings(defaults: defaults).detail, .auto, "Kept so")
    }
}
