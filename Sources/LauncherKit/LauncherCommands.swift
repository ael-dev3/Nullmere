import SwiftUI

/// What the launcher's menus offer: each item's title, key, whether it can
/// be chosen, and what it does, apart from SwiftUI's menus so each can be
/// tried.
@MainActor
enum LauncherMenu: CaseIterable {
    case settings, news, website, repository

    var title: String {
        switch self {
        case .settings: return "Settings…"
        case .news: return "Nullmere News"
        case .website: return "Nullmere Website"
        case .repository: return "Source Repository"
        }
    }

    var shortcut: KeyboardShortcut? {
        self == .settings ? KeyboardShortcut(",", modifiers: .command) : nil
    }

    /// While the window shows only the requirement screen, Settings… and
    /// the news wait; the links don't.
    func isEnabled(gated: Bool?) -> Bool {
        switch self {
        case .settings, .news: return gated == false
        case .website, .repository: return true
        }
    }

    func perform(model: LauncherModel, settings: (@MainActor () -> Void)?) {
        switch self {
        case .settings:
            if let settings { settings() } else { model.show(.settings) }
        case .news: model.openNews()
        case .website: model.openWebsite()
        case .repository: model.openRepository()
        }
    }
}

/// Menu bar commands: Settings… opens the in-window panel, and Help links to
/// the website and the source repository. The app has a single window, so
/// New Window is removed. While the window shows only the requirement
/// screen, Settings… and Nullmere News are unavailable there too.
public struct LauncherCommands: Commands {
    private let model: LauncherModel
    private let settings: (@MainActor () -> Void)?

    @FocusedValue(\.launcherIsGated) private var isGated

    /// `settings`, when given, decides what Settings… opens: the launcher's
    /// panel, or the settings of whatever has the window.
    public init(model: LauncherModel, settings: (@MainActor () -> Void)? = nil) {
        self.model = model
        self.settings = settings
    }

    public var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            item(.settings)
        }
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .help) {
            item(.news)
            item(.website)
            item(.repository)
        }
    }

    @MainActor
    private func item(_ item: LauncherMenu) -> some View {
        Button(item.title) { item.perform(model: model, settings: settings) }
            .keyboardShortcut(item.shortcut)
            .disabled(!item.isEnabled(gated: isGated))
    }
}

/// Whether the launcher window in front shows only the requirement screen.
struct LauncherIsGatedKey: FocusedValueKey {
    typealias Value = Bool
}

extension FocusedValues {
    var launcherIsGated: Bool? {
        get { self[LauncherIsGatedKey.self] }
        set { self[LauncherIsGatedKey.self] = newValue }
    }
}
