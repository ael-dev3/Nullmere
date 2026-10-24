import SwiftUI

/// Menu bar commands: Settings… opens the in-window panel, and Help links to
/// the website. The launcher has a single window, so New Window is removed.
public struct LauncherCommands: Commands {
    private let model: LauncherModel

    public init(model: LauncherModel) {
        self.model = model
    }

    public var body: some Commands {
        CommandGroup(replacing: .appSettings) {
            Button("Settings…") {
                model.show(.settings)
            }
            .keyboardShortcut(",", modifiers: .command)
        }
        CommandGroup(replacing: .newItem) {}
        CommandGroup(replacing: .help) {
            Button("Nullmere Website") {
                model.openWebsite()
            }
        }
    }
}
