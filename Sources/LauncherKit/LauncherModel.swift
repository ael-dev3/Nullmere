import AppKit
import LauncherCore
import Observation
import SwiftUI
import os

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
        /// The Mac couldn't reach the repository; the saved news is still shown.
        case offline
        /// The repository answered, but not with a feed; the saved news is still shown.
        case unavailable
    }

    /// The choices on the Play panel, left to right.
    enum PlayChoice: CaseIterable, Equatable {
        case website
        case back
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
    var playSelection: PlayChoice = .back
    /// The chosen action on the requirement screen, an index into `readiness.actions`.
    var requirementSelection = 0
    private(set) var intro = Intro()
    /// Fading to black, to quit or to hand over to the game.
    private(set) var isLeaving = false
    private(set) var readiness: ModelReadiness = .checking
    private(set) var news: NewsFeed
    private(set) var newsStatus: NewsStatus = .saved
    /// Set by the app: crosses from the launcher to the realm's front door.
    public var enterRealm: (@MainActor () -> Void)?
    /// Whether the launcher is the app in front.
    private(set) var isInFront = true
    /// Whether macOS asks apps to save energy (see `LauncherEnvironment`).
    private(set) var systemSavesEnergy = false

    private let defaults: UserDefaults
    private let environment: LauncherEnvironment
    @ObservationIgnored private var introTask: Task<Void, Never>?
    @ObservationIgnored private var readinessTask: Task<Void, Never>?
    @ObservationIgnored private var newsFetchedAt: Date?
    @ObservationIgnored private var isFetchingNews = false
    private static let logger = Logger(subsystem: "online.nullmere.launcher", category: "news")
    @ObservationIgnored private var pendingDebugKeys: [KeyCommand] = LauncherEnvironment.debugKeys

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

    /// Nullmere is usable only where Apple's on-device model is. Until it is
    /// ready, the launcher shows nothing but the requirement screen: what is
    /// missing, a way to fix it where there is one, and Quit.
    var isGated: Bool {
        !readiness.allowsPlay
    }

    var footerHint: String? {
        guard !isGated else { return nil }
        switch screen {
        case .title, .play: return nil
        // Return opens a story's page; a story without one has none to open.
        case .news: return selectedNews?.link == nil ? "↑ ↓ choose  ·  esc back" : "↑ ↓ choose  ·  return open  ·  esc back"
        case .settings: return "← → change  ·  esc back"
        }
    }

    func backdropConfiguration(systemReducesMotion: Bool) -> LakeConfiguration {
        let motion = settings.motion.resolved(systemReducesMotion: systemReducesMotion)
        return LakeConfiguration(
            motion: motion,
            renderScale: settings.quality.scale,
            framesPerSecond: settings.frameRate.framesPerSecond(motion: motion, isSavingEnergy: isSavingEnergy),
            horizon: LakeComposition.horizon,
            veil: screen == .title && !isGated ? 0 : 1
        )
    }

    /// The lake renders at a lower rate while another app is in front, in
    /// Low Power Mode, and while the Mac runs hot.
    var isSavingEnergy: Bool {
        !isInFront || systemSavesEnergy
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
        if !isGated, !pendingDebugKeys.isEmpty {
            let keys = pendingDebugKeys
            pendingDebugKeys = []
            Task { [weak self] in
                // Let the opening play out, then type.
                try? await Task.sleep(for: .seconds(6))
                for key in keys {
                    self?.handle(key)
                    try? await Task.sleep(for: .milliseconds(700))
                }
            }
        }
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
        Self.logger.notice("On-device model: \(current.status, privacy: .public).")
        Reporting.say("On-device model: \(current.status).")
        // The requirement screen gives way to the launcher as soon as the
        // model is ready, and comes back if it stops being available.
        withAnimation(.easeInOut(duration: 0.6)) {
            readiness = current
            requirementSelection = 0
        }
    }

    // MARK: In front and behind

    /// The launcher came to the front: the lake runs at its full rate
    /// again, and Apple Intelligence may have been turned on meanwhile.
    func didBecomeActive() {
        isInFront = true
        refreshReadiness()
    }

    /// Another app came to the front: the lake slows down, and readiness
    /// checks wait until the launcher is back.
    func didResignActive() {
        isInFront = false
        pauseReadinessChecks()
    }

    /// Reads Low Power Mode and the Mac's thermal state again.
    func refreshEnergyState() {
        let savesEnergy = environment.systemSavesEnergy()
        if savesEnergy != systemSavesEnergy {
            systemSavesEnergy = savesEnergy
        }
    }

    // MARK: Navigation

    public func show(_ screen: Screen) {
        completeIntro()
        guard !isGated else { return }
        if screen == .settings, self.screen != .settings {
            settingsSelection = .motion
        }
        self.screen = screen
    }

    func returnToTitle() {
        show(.title)
    }

    func activate(_ item: MenuItem) {
        guard !isGated else { return }
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
        guard !isGated else {
            handleOnRequirement(key)
            return
        }
        switch screen {
        case .title: handleOnTitle(key)
        case .news: handleInNews(key)
        case .settings: handleInSettings(key)
        case .play: handleInPlay(key)
        }
    }

    private func handleOnRequirement(_ key: KeyCommand) {
        let actions = readiness.actions
        switch key {
        case .left, .up: requirementSelection = max(requirementSelection - 1, 0)
        case .right, .down: requirementSelection = max(min(requirementSelection + 1, actions.count - 1), 0)
        case .confirm:
            if actions.indices.contains(requirementSelection) {
                perform(actions[requirementSelection])
            }
        case .back: break
        }
    }

    func perform(_ action: RequirementAction) {
        switch action {
        case .openSystemSettings: openAppleIntelligenceSettings()
        case .quit: quit()
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
        case .left: playSelection = playSelection.moved(by: -1, wrapping: false)
        case .right: playSelection = playSelection.moved(by: 1, wrapping: false)
        case .confirm: choose(playSelection)
        case .back: returnToTitle()
        case .up, .down: break
        }
    }

    func choose(_ choice: PlayChoice) {
        playSelection = choice
        switch choice {
        case .website: openWebsite()
        case .back: returnToTitle()
        }
    }

    // MARK: Play

    /// Crosses into the realm: the launcher fades, and the realm's front
    /// door takes the window.
    func play() {
        menuSelection = .play
        refreshReadiness()
        switch PlayOutcome(readiness: readiness, canEnterRealm: enterRealm != nil) {
        case .enterRealm:
            crossToRealm()
        case .awaitFirstRealm:
            playSelection = .back
            show(.play)
        case .explainRequirement:
            // The model just became unavailable; the requirement screen shows why.
            break
        }
    }

    private func crossToRealm() {
        guard !isLeaving else { return }
        completeIntro()
        withAnimation(.easeIn(duration: 0.8)) { isLeaving = true }
        Self.logger.notice("Crossing into the realm.")
        Task {
            try? await Task.sleep(for: .milliseconds(850))
            enterRealm?()
        }
    }

    /// Back from the realm's front door: the launcher shows again.
    public func returnFromRealm() {
        screen = .title
        withAnimation(.easeOut(duration: 0.8)) { isLeaving = false }
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
        guard !isGated else { return }
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
            Self.logger.notice("News updated: \(feed.items.count, privacy: .public) stories.")
            newsSelection = min(newsSelection, max(visibleNews.count - 1, 0))
        } catch {
            newsStatus = Self.isConnectionFailure(error) ? .offline : .unavailable
            Self.logger.notice("News not updated: \(String(describing: error), privacy: .public)")
        }
    }

    /// Whether a download failed because the Mac couldn't reach the server,
    /// rather than because the server's answer wasn't a feed.
    private static func isConnectionFailure(_ error: any Error) -> Bool {
        guard let error = error as? URLError else { return false }
        switch error.code {
        case .notConnectedToInternet, .networkConnectionLost, .timedOut, .cannotFindHost,
             .cannotConnectToHost, .dnsLookupFailed, .internationalRoamingOff, .dataNotAllowed:
            return true
        default:
            return false
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
