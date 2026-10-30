import LauncherKit
import SwiftUI

/// What the game's menus offer, each item's title, key, whether it can be
/// chosen now, and what it does: kept apart from SwiftUI's menus so each
/// can be tried.
@MainActor
enum GameMenu: CaseIterable {
    case leaveWorld
    case ready, stayReady, nextCompany, goToSeat
    case houses, chronicle, guide
    case archive, commanders, alliance, realm

    var title: String {
        switch self {
        case .leaveWorld: return "Leave the World"
        case .ready: return "Ready"
        case .stayReady: return "Stay Ready Until Needed"
        case .nextCompany: return "Next Company"
        case .goToSeat: return "Go to Seat"
        case .houses: return "Houses"
        case .chronicle: return "Chronicle"
        case .guide: return "Guide"
        case .archive: return "Archive"
        case .commanders: return "Commanders"
        case .alliance: return "Alliance"
        case .realm: return "The Realm"
        }
    }

    var shortcut: KeyboardShortcut? {
        switch self {
        case .leaveWorld: return KeyboardShortcut("w", modifiers: [.command, .shift])
        case .ready: return KeyboardShortcut(.return, modifiers: .command)
        case .stayReady: return KeyboardShortcut(.return, modifiers: [.command, .shift])
        case .guide: return KeyboardShortcut("/", modifiers: [.command, .shift])
        case .nextCompany, .goToSeat, .houses, .chronicle, .archive, .commanders, .alliance, .realm: return nil
        }
    }

    func isEnabled(in app: GameApp) -> Bool {
        guard let session = app.session else { return false }
        switch self {
        case .ready: return session.state.outcome == nil
        // A fallen House has no companies, no seat, and nothing to wait on.
        case .stayReady, .nextCompany, .goToSeat: return session.state.outcome == nil && !session.playerHouse.isEliminated
        default: return true
        }
    }

    func perform(in app: GameApp) {
        guard isEnabled(in: app), let session = app.session else { return }
        switch self {
        case .leaveWorld: app.leaveWorld()
        case .ready: session.endWatch()
        case .stayReady: session.endWatchesUntilNeeded()
        case .nextCompany: session.selectNextReadyUnit()
        case .goToSeat: session.focusOnSeat()
        case .houses: toggle(.houses, in: session)
        case .chronicle: toggle(.chronicle, in: session)
        case .guide: toggle(.guide, in: session)
        case .archive: toggle(.archive, in: session)
        case .commanders: toggle(.commanders, in: session)
        case .alliance: toggle(.alliance, in: session)
        case .realm: toggle(.realm, in: session)
        }
    }

    private func toggle(_ panel: GameSession.Panel, in session: GameSession) {
        session.panel = session.panel == panel ? nil : panel
    }
}

/// The game's menu commands.
public struct GameCommands: Commands {
    let app: GameApp

    public init(app: GameApp) {
        self.app = app
    }

    public var body: some Commands {
        CommandGroup(after: .newItem) {
            item(.leaveWorld)
        }
        CommandMenu("Watch") {
            item(.ready)
            item(.stayReady)
            item(.nextCompany)
            item(.goToSeat)
            Divider()
            // The launcher makes no sound: these wait for the realm's face.
            Toggle("Sound", isOn: Binding(get: { app.isSoundOn }, set: { app.isSoundOn = $0 }))
                .keyboardShortcut("m", modifiers: [.command, .shift])
                .disabled(!app.isShowing)
            Toggle("Music", isOn: Binding(get: { app.isMusicOn }, set: { app.isMusicOn = $0 }))
                .keyboardShortcut("u", modifiers: [.command, .shift])
                .disabled(!app.isShowing || !app.isSoundOn)
            Toggle("Larger Text", isOn: Binding(get: { TextSize.shared.isLarger }, set: { TextSize.shared.isLarger = $0 }))
                .keyboardShortcut("+", modifiers: [.command, .shift])
            Divider()
            item(.houses)
            item(.archive)
            item(.commanders)
            item(.alliance)
            item(.realm)
            item(.chronicle)
            item(.guide)
        }
    }

    @MainActor
    private func item(_ item: GameMenu) -> some View {
        Button(item.title) { item.perform(in: app) }
            .keyboardShortcut(item.shortcut)
            .disabled(!item.isEnabled(in: app))
    }
}
