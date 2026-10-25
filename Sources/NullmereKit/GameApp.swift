import AppKit
import FoundationModels
import LauncherCore
import NullmereCore
import Observation

/// The whole app: the gate on Apple's on-device model, the title screen,
/// and the game in progress.
@MainActor
@Observable
public final class GameApp {
    public enum Phase {
        /// Waiting for, or explaining the lack of, the on-device model.
        case gate
        case title
        case playing(GameSession)
    }

    public private(set) var phase: Phase = .gate
    public private(set) var readiness: ModelReadiness = .checking
    public private(set) var hasSave: Bool

    let store: SaveStore
    private var recheckTask: Task<Void, Never>?

    public init(store: SaveStore = SaveStore()) {
        self.store = store
        self.hasSave = store.hasSave
        checkModel()
        startFromEnvironment()
    }

    public var session: GameSession? {
        if case .playing(let session) = phase { return session }
        return nil
    }

    // MARK: The on-device model

    /// Reads the model's state, and opens the title screen once it is ready.
    public func checkModel() {
        readiness = Self.skipsModelCheck ? .ready : Self.readModel()
        if readiness.allowsPlay {
            recheckTask?.cancel()
            recheckTask = nil
            if case .gate = phase { phase = .title }
        } else if readiness.needsRecheck, recheckTask == nil {
            recheckTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    guard let self, !Task.isCancelled else { return }
                    if NSApp.isActive { self.checkModel() }
                }
            }
        }
    }

    static func readModel() -> ModelReadiness {
        switch SystemLanguageModel.default.availability {
        case .available:
            return .ready
        case .unavailable(.deviceNotEligible):
            return .deviceNotEligible
        case .unavailable(.appleIntelligenceNotEnabled):
            return .appleIntelligenceNotEnabled
        case .unavailable(.modelNotReady):
            return .modelNotReady
        case .unavailable:
            return .unavailable
        }
    }

    /// Debug builds can skip the model check, so the game can be opened and
    /// photographed on a machine without Apple Intelligence, such as CI.
    static var skipsModelCheck: Bool {
        #if DEBUG
        return ProcessInfo.processInfo.environment["NULLMERE_SKIP_MODEL_CHECK"] == "1"
        #else
        return false
        #endif
    }

    /// Debug builds can open straight into a new game on a given seed.
    private func startFromEnvironment() {
        #if DEBUG
        if readiness.allowsPlay, let seed = ProcessInfo.processInfo.environment["NULLMERE_NEW_GAME"], !seed.isEmpty {
            begin(GameSettings(seedText: seed))
        }
        #endif
    }

    // MARK: Games

    public func begin(_ settings: GameSettings) {
        guard readiness.allowsPlay else { return }
        let session = GameSession(state: GameState(settings: settings), store: store)
        store.save(session.state)
        hasSave = true
        phase = .playing(session)
    }

    public func continueSaved() {
        guard readiness.allowsPlay, let state = store.load() else {
            hasSave = store.hasSave
            return
        }
        phase = .playing(GameSession(state: state, store: store))
    }

    /// Saves and goes back to the title screen.
    public func leaveGame() {
        session?.save(quietly: true)
        hasSave = store.hasSave
        phase = .title
    }

    /// Forgets a finished game and goes back to the title screen.
    public func abandonFinishedGame() {
        store.delete()
        hasSave = false
        phase = .title
    }
}
