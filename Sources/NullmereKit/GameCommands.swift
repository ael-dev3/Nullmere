import SwiftUI

/// The game's menu commands.
public struct GameCommands: Commands {
    let app: GameApp

    public init(app: GameApp) {
        self.app = app
    }

    public var body: some Commands {
        CommandGroup(replacing: .newItem) {
            Button("Leave to Title") { app.leaveGame() }
                .keyboardShortcut("w", modifiers: [.command, .shift])
                .disabled(app.session == nil)
        }
        CommandGroup(replacing: .undoRedo) {
            Button("Undo Order") { app.session?.undo() }
                .keyboardShortcut("z", modifiers: .command)
                .disabled(!(app.session?.canUndo ?? false))
        }
        CommandGroup(replacing: .saveItem) {
            Button("Save") { app.session?.save() }
                .keyboardShortcut("s", modifiers: .command)
                .disabled(app.session == nil)
        }
        CommandMenu("Watch") {
            Button("End Watch") { app.session?.endWatch() }
                .keyboardShortcut(.return, modifiers: .command)
                .disabled(app.session?.state.outcome != nil || app.session == nil)
            Button("Next Company") { app.session?.selectNextReadyUnit() }
                .disabled(app.session == nil)
            Button("Go to Seat") { app.session?.focusOnSeat() }
                .disabled(app.session == nil)
            Divider()
            Toggle("Sound", isOn: Binding(get: { app.isSoundOn }, set: { app.isSoundOn = $0 }))
                .keyboardShortcut("m", modifiers: [.command, .shift])
            Toggle("Music", isOn: Binding(get: { app.isMusicOn }, set: { app.isMusicOn = $0 }))
                .keyboardShortcut("u", modifiers: [.command, .shift])
            Divider()
            Button("Houses") { toggle(.houses) }
                .disabled(app.session == nil)
            Button("Chronicle") { toggle(.chronicle) }
                .disabled(app.session == nil)
            Button("Guide") { toggle(.guide) }
                .keyboardShortcut("/", modifiers: [.command, .shift])
                .disabled(app.session == nil)
        }
    }

    @MainActor
    private func toggle(_ panel: GameSession.Panel) {
        guard let session = app.session else { return }
        session.panel = session.panel == panel ? nil : panel
    }
}
