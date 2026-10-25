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
            Button("Houses") { toggle(.houses) }
                .disabled(app.session == nil)
            Button("Chronicle") { toggle(.chronicle) }
                .disabled(app.session == nil)
        }
    }

    @MainActor
    private func toggle(_ panel: GameSession.Panel) {
        guard let session = app.session else { return }
        session.panel = session.panel == panel ? nil : panel
    }
}
