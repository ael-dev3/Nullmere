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
        case settings
    }

    /// The opening sequence: the lake surfaces from black, then the title, then the menu.
    struct Intro: Equatable {
        var showsScene = false
        var showsTitle = false
        var showsMenu = false

        static let complete = Intro(showsScene: true, showsTitle: true, showsMenu: true)
    }

    public static let website = URL(string: "https://nullmere.online")!

    public private(set) var screen: Screen = .title
    private(set) var settings: LauncherSettings
    var menuSelection: MenuItem = .play
    var settingsSelection: SettingsRow = .motion
    private(set) var intro = Intro()
    private(set) var isQuitting = false

    private let defaults: UserDefaults
    @ObservationIgnored private var introTask: Task<Void, Never>?

    public init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        self.settings = LauncherSettings(defaults: defaults)
    }

    /// The marketing version from the app bundle, or "dev" when run with `swift run`.
    var version: String {
        Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "dev"
    }

    var footerHint: String? {
        switch screen {
        case .title, .play: return nil
        case .settings: return "← → change  ·  esc return"
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
            withAnimation(.easeInOut(duration: 2.4)) { intro.showsScene = true }
            try? await Task.sleep(for: .milliseconds(900))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 2.8)) { intro.showsTitle = true }
            try? await Task.sleep(for: .milliseconds(1700))
            guard !Task.isCancelled else { return }
            withAnimation(.easeOut(duration: 1.4)) { intro.showsMenu = true }
        }
    }

    /// Skips the rest of the opening sequence.
    func completeIntro() {
        introTask?.cancel()
        guard intro != .complete else { return }
        withAnimation(.easeOut(duration: 0.6)) { intro = .complete }
    }

    // MARK: Navigation

    public func show(_ screen: Screen) {
        completeIntro()
        if screen == .settings {
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
        case .play: show(.play)
        case .settings: show(.settings)
        case .quit: quit()
        }
    }

    func choose(_ index: Int, for row: SettingsRow) {
        settingsSelection = row
        updateSettings { $0.select(index, for: row) }
    }

    /// Responds to a key press in the launcher window.
    func handle(_ key: KeyCommand) {
        guard !isQuitting else { return }
        guard intro == .complete else {
            completeIntro()
            return
        }
        switch (screen, key) {
        case (.title, .up):
            menuSelection = menuSelection.moved(by: -1)
        case (.title, .down):
            menuSelection = menuSelection.moved(by: 1)
        case (.title, .confirm):
            activate(menuSelection)
        case (.settings, .up):
            settingsSelection = settingsSelection.moved(by: -1)
        case (.settings, .down):
            settingsSelection = settingsSelection.moved(by: 1)
        case (.settings, .left):
            updateSettings { $0.step(settingsSelection, by: -1) }
        case (.settings, .right):
            updateSettings { $0.step(settingsSelection, by: 1) }
        case (.settings, .confirm):
            updateSettings { $0.step(settingsSelection, by: 1, wrapping: true) }
        case (.settings, .back), (.play, .back), (.play, .confirm):
            returnToTitle()
        case (.title, .left), (.title, .right), (.title, .back), (.play, _):
            break
        }
    }

    // MARK: Outside the window

    func openWebsite() {
        NSWorkspace.shared.open(Self.website)
    }

    /// Fades to black, then quits.
    func quit() {
        guard !isQuitting else { return }
        introTask?.cancel()
        withAnimation(.easeIn(duration: 0.6)) { isQuitting = true }
        Task {
            try? await Task.sleep(for: .milliseconds(650))
            NSApp.terminate(nil)
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
