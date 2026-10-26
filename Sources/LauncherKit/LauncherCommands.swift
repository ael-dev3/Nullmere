import SwiftUI

/// Menu bar commands: Settings… opens the in-window panel, and Help links to
/// the website and the source repository. The launcher has a single window,
/// so New Window is removed. While the window shows only the requirement
/// screen, Settings… and Nullmere News are unavailable there too.
public struct LauncherCommands: Commands {
    private let model: LauncherModel

    @FocusedValue(\.launcherIsGated) private var isGated

    public init(model: LauncherModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                model.show(.settings)
            }
            .keyboardShortcut(",", modifiers: .command)
            .disabled(isGated != false)
        }
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .help) {
            Button("Nullmere News") {
                model.openNews()
            }
            .disabled(isGated != false)
            Button("Nullmere Website") {
                model.openWebsite()
            }
            Button("Source Repository") {
                model.openRepository()
            }
        }
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
