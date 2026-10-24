import AppKit
import LauncherCore
import Observation
import SwiftUI

/// State and actions for the launcher window.
@MainActor
@Observable
public final class LauncherModel {
    public enum Screen: Equatable {
        case title
        case play
        case news
        case settings
    }

    /// Where the news on show came from.
    enum NewsStatus: Equatable {
        /// The news the launcher shipped with, or a copy saved on an earlier visit.
        case saved
        case updating
        /// Just downloaded from the repository.
        case current
        /// The download failed; the saved news is still shown.
        case offline
    }

    /// The opening sequence: the lake surfaces from black, then the title, then the menu.
    struct Intro: Equatable {
        var showsScene = false
        var showsTitle = false
        var showsMenu = false

        static let complete = Intro(showsScene: true, showsTitle: true, showsMenu: true)
    }

    /// How many headlines the news panel lists.
    static let visibleNewsCount = 3
    /// How long downloaded news counts as fresh.
    static let newsRefreshInterval: TimeInterval = 10 * 60
    static let newsCacheKey = "launcher.news.feed"

    public private(set) var screen: Screen = .title
    private(set) var settings: LauncherSettings
    var menuSelection: MenuItem = .play
    var settingsSelection: SettingsRow = .motion
    var newsSelection = 0
    private(set) var intro = Intro()
    /// Fading to black, to quit or to hand over to the game.
    private(set) var isLeaving = false
    private(set) var readiness: ModelReadiness = .checking
    private(set) var news: NewsFeed
    private(set) var newsStatus: NewsStatus = .saved
    private(set) var gameFailedToOpen = false

    private let defaults: UserDefaults
    private let environment: LauncherEnvironment
    @ObservationIgnored private var introTask: Task<Void, Never>?
    @ObservationIgnored private var readinessTask: Task<Void, Never>?
    @ObservationIgnored private var newsFetchedAt: Date?
    @ObservationIgnored private var isFetchingNews = false

    public convenience init(defaults: UserDefaults = .standard) {
        self.init(defaults: defaults, environment: .live)
    }

    init(defaults: UserDefaults, environment: LauncherEnvironment) {
        self.defaults = defaults
        self.environment = environment
        self.settings = LauncherSettings(defaults: defaults)
        if let data = defaults.data(forKey: Self.newsCacheKey), let saved = try? NewsFeed(json: data) {
            self.news = saved
        } else {
            self.news = .builtIn
        }
    }

    /// The marketing version from the app bundle, or "dev" when run with `swift run`.
    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var footerHint: String? {
        switch screen {
        case .title, .play: return nil
        case .news: return "↑ ↓ choose  ·  return open  ·  esc back"
        case .settings: return "← → change  ·  esc back"
        }
    }

    func backdropConfiguration(systemReducesMotion: Bool) -> LakeConfiguration {
        LakeConfiguration(
            motion: settings.motion.resolved(systemReducesMotion: systemReducesMotion),
            renderScale: settings.quality.scale,
            framesPerSecond: settings.frameRate.rawValue,
            horizon: LakeComposition.horizon
        )
    }

    // MARK: Intro

    func beginIntro(systemReducesMotion: Bool) {
        guard introTask == nil, intro != .complete else { return }
        guard settings.motion.resolved(systemReducesMotion: systemReducesMotion) == .full else {
            withAnimation(.easeOut(duration: 0.8)) { intro = .complete }
            return
        }
        introTask = Task { [weak self] in
            guard let self else { return }
            withAnimation(.easeInOut(duration: 2.4)) { self.intro.showsScene = true }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 2.8)) { self.intro.showsTitle = true }
            try? await Task.sleep(for: .milliseconds(1700))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 1.4)) { self.intro.showsMenu = true }
        }
    }

    /// Skips the rest of the opening sequence.
    func completeIntro() {
        introTask?.cancel()
        guard intro != .complete else { return }
        withAnimation(.easeOut(duration: 0.6)) { intro = .complete }
    }

    // MARK: Apple Intelligence

    /// Reads whether the on-device model is available, and keeps checking
    /// every few seconds while the answer can still change: while the model
    /// downloads, or until Apple Intelligence is turned on.
    func refreshReadiness() {
        apply(environment.modelReadiness())
        guard readiness.needsRecheck, readinessTask == nil else { return }
        readinessTask = Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(4))
                guard let self, !Task.isCancelled else { return }
                self.apply(self.environment.modelReadiness())
                if !self.readiness.needsRecheck {
                    self.readinessTask = nil
                    return
                }
            }
        }
    }

    /// Stops checking while the launcher is in the background. Coming back
    /// to the front calls `refreshReadiness()` again.
    func pauseReadinessChecks() {
        readinessTask?.cancel()
        readinessTask = nil
    }

    private func apply(_ current: ModelReadiness) {
        guard current != readiness else { return }
        let becameReady = current.allowsPlay && !readiness.allowsPlay
        withAnimation(.easeInOut(duration: 0.4)) { readiness = current }
        // Someone waiting on the Play panel crosses as soon as the model is
        // ready. Without a game client the panel simply says so.
        if becameReady, screen == .play, let game = environment.installedGame() {
            launchGame(at: game)
        }
    }

    // MARK: Navigation

    public func show(_ screen: Screen) {
        completeIntro()
        if screen == .settings, self.screen != .settings {
            settingsSelection = .motion
        }
        self.screen = screen
    }

    func returnToTitle() {
        show(.title)
    }

    func activate(_ item: MenuItem) {
        menuSelection = item
        switch item {
        case .play: play()
        case .news: openNews()
        case .settings: show(.settings)
        case .repository: openRepository()
        case .quit: quit()
        }
    }

    func choose(_ index: Int, for row: SettingsRow) {
        settingsSelection = row
        updateSettings { $0.select(index, for: row) }
    }

    /// Responds to a key press in the launcher window.
    func handle(_ key: KeyCommand) {
        guard !isLeaving else { return }
        guard intro == .complete else {
            completeIntro()
            return
        }
        switch screen {
        case .title: handleOnTitle(key)
        case .news: handleInNews(key)
        case .settings: handleInSettings(key)
        case .play: handleInPlay(key)
        }
    }

    private func handleOnTitle(_ key: KeyCommand) {
        switch key {
        case .left, .up: menuSelection = menuSelection.moved(by: -1)
        case .right, .down: menuSelection = menuSelection.moved(by: 1)
        case .confirm: activate(menuSelection)
        case .back: break
        }
    }

    private func handleInNews(_ key: KeyCommand) {
        switch key {
        case .up: newsSelection = max(newsSelection - 1, 0)
        case .down: newsSelection = min(newsSelection + 1, max(visibleNews.count - 1, 0))
        case .confirm: openNewsLink()
        case .back: returnToTitle()
        case .left, .right: break
        }
    }

    private func handleInSettings(_ key: KeyCommand) {
        switch key {
        case .up: settingsSelection = settingsSelection.moved(by: -1)
        case .down: settingsSelection = settingsSelection.moved(by: 1)
        case .left: updateSettings { $0.step(settingsSelection, by: -1) }
        case .right: updateSettings { $0.step(settingsSelection, by: 1) }
        case .confirm: updateSettings { $0.step(settingsSelection, by: 1, wrapping: true) }
        case .back: returnToTitle()
        }
    }

    private func handleInPlay(_ key: KeyCommand) {
        switch key {
        case .confirm, .back: returnToTitle()
        case .up, .down, .left, .right: break
        }
    }

    // MARK: Play

    /// Opens the game when this Mac is ready and the game is installed;
    /// otherwise explains what is missing.
    func play() {
        menuSelection = .play
        refreshReadiness()
        let game = readiness.allowsPlay ? environment.installedGame() : nil
        switch PlayOutcome(readiness: readiness, isGameInstalled: game != nil) {
        case .launchGame:
            if let game { launchGame(at: game) }
        case .explainRequirement, .awaitFirstRealm:
            gameFailedToOpen = false
            show(.play)
        }
    }

    private func launchGame(at url: URL) {
        guard !isLeaving else { return }
        completeIntro()
        withAnimation(.easeIn(duration: 0.8)) { isLeaving = true }
        Task {
            do {
                try await environment.openGame(url)
                try? await Task.sleep(for: .milliseconds(850))
                environment.terminate()
            } catch {
                gameFailedToOpen = true
                show(.play)
                withAnimation(.easeOut(duration: 0.6)) { isLeaving = false }
            }
        }
    }

    // MARK: News

    var visibleNews: [NewsItem] {
        Array(news.items.prefix(Self.visibleNewsCount))
    }

    func selectNews(_ item: NewsItem) {
        if let index = visibleNews.firstIndex(of: item) {
            newsSelection = index
        }
    }

    var selectedNews: NewsItem? {
        let items = visibleNews
        return items.indices.contains(newsSelection) ? items[newsSelection] : items.first
    }

    func openNews() {
        menuSelection = .news
        newsSelection = 0
        show(.news)
        Task { await refreshNews() }
    }

    /// Downloads the latest news unless it was fetched a few minutes ago,
    /// keeping a copy for the next launch. Saved news stays on show if the
    /// download fails.
    func refreshNews() async {
        guard !isFetchingNews else { return }
        if let fetched = newsFetchedAt, Date().timeIntervalSince(fetched) < Self.newsRefreshInterval {
            return
        }
        isFetchingNews = true
        defer { isFetchingNews = false }
        newsStatus = .updating
        do {
            let data = try await environment.downloadNews()
            let feed = try NewsFeed(json: data)
            withAnimation(.easeInOut(duration: 0.4)) {
                news = feed
                newsStatus = .current
            }
            newsFetchedAt = Date()
            defaults.set(data, forKey: Self.newsCacheKey)
            newsSelection = min(newsSelection, max(visibleNews.count - 1, 0))
        } catch {
            newsStatus = .offline
        }
    }

    func openNewsLink() {
        guard let link = selectedNews?.link else { return }
        _ = environment.open(link)
    }

    // MARK: Outside the window

    func openWebsite() {
        _ = environment.open(Destination.website)
    }

    func openRepository() {
        _ = environment.open(Destination.repository)
    }

    /// Opens System Settings at Apple Intelligence & Siri. If the settings
    /// link can't be opened at all, opens System Settings itself.
    func openAppleIntelligenceSettings() {
        if !environment.open(Destination.appleIntelligenceSettings) {
            _ = environment.open(Destination.systemSettings)
        }
    }

    /// Fades to black, then quits.
    func quit() {
        guard !isLeaving else { return }
        introTask?.cancel()
        withAnimation(.easeIn(duration: 0.6)) { isLeaving = true }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            environment.terminate()
        }
    }

    private func updateSettings(_ change: (inout LauncherSettings) -> Void) {
        var updated = settings
        change(&updated)
        guard updated != settings else { return }
        settings = updated
        settings.save(to: defaults)
    }
}
