import Foundation
import LauncherCore
import LauncherKit
import NullmereLiveStage
import NullmereRealm
import Observation
import SwiftUI

/// Which of its two faces the window shows.
@MainActor
@Observable
public final class OnlineShell {
    public private(set) var inRealm = false

    public let launcher: LauncherModel
    public let app: GameApp
    /// A player's session in the rebuilt realm, where this run was told
    /// of one: played in the window in place of the launcher, while the
    /// rebuilt realm is grown beside the realm the launcher opens.
    public private(set) var rebuilt: LiveSession?

    public convenience init() {
        self.init(launcher: LauncherModel(), app: GameApp(opensAtOnce: false))
        #if DEBUG
        rebuilt = OnlineShell.session(in: ProcessInfo.processInfo.environment)
        #endif
        // The app as a keeper opens it: its world keeps its own day.
        app.keepsDay = true
        // The last run, if it stopped on a fault: the launcher opens on its
        // page.
        launcher.open(on: RunLedger.shared.atLaunch)
    }

    public init(launcher: LauncherModel, app: GameApp) {
        self.launcher = launcher
        self.app = app
        launcher.enterRealm = { [weak self] in self?.enterRealm() }
        app.onLeave = { [weak self] in self?.leaveRealm() }
        app.display = launcher
        // The launcher's Music and the realm's are one choice.
        launcher.onMusicChanged = { [weak app] on in app?.isMusicOn = on }
    }

    /// A session in the rebuilt realm an environment names with
    /// NULLMERE_REBUILT_REALM (a server and, as its path, the database's
    /// name). The player is kept in the keychain, one for each realm, or
    /// for a test in the file NULLMERE_IDENTITY_FILE names.
    static func session(in environment: [String: String]) -> LiveSession? {
        guard let text = environment["NULLMERE_REBUILT_REALM"], let address = LiveDoor.address(text) else { return nil }
        let (server, database) = (address.server, address.database)
        let file = environment["NULLMERE_IDENTITY_FILE"] ?? ""
        return LiveSession(opening: {
            if !file.isEmpty {
                return try await LiveDoor.open(server: server, database: database, keeping: FileIdentityStore(url: URL(fileURLWithPath: file)))
            }
            let realm = "rebuilt \(server.host() ?? server.absoluteString)/\(database)"
            return try await LiveDoor.open(server: server, database: database, keeping: KeychainIdentityStore(realm: realm))
        })
    }

    /// Over the launcher, the title theme of the lake the keeper's realm
    /// last lay on, with the night about it.
    func playTitle() {
        app.ambience.titleLake = GameApp.lastLake
        app.ambience.start()
    }

    func enterRealm() {
        inRealm = true
        RunLedger.shared.note(.door)
        // The realm's own score, at peace or at war, from its door on.
        app.ambience.titleLake = nil
        app.open()
    }

    func leaveRealm() {
        inRealm = false
        RunLedger.shared.note(.launcher)
        launcher.returnFromRealm()
        playTitle()
    }

    /// What Settings… opens: the launcher's panel, or the game's settings.
    public func showSettings() {
        if inRealm {
            app.showsSettings = true
        } else {
            launcher.show(.settings)
        }
    }
}

/// The one window of Nullmere Online: the launcher on the moonlit lake, and
/// through Play, the realm.
public struct NullmereOnlineView: View {
    private let shell: OnlineShell

    public init(shell: OnlineShell) {
        self.shell = shell
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            if let rebuilt = shell.rebuilt {
                LiveGameView(session: rebuilt)
            } else if shell.inRealm {
                GameRootView(app: shell.app)
                    .transition(.opacity)
            } else {
                LauncherRootView(model: shell.launcher)
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: shell.inRealm)
        .background(WindowFitter())
        .onAppear { if !shell.inRealm, shell.rebuilt == nil { shell.playTitle() } }
    }
}
