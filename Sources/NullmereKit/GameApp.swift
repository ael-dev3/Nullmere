import AppKit
import LauncherCore
import LauncherKit
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
    /// What happened to the saved game, when the player should know.
    public private(set) var saveNotice: String?

    let store: SaveStore
    private let readModel: () -> ModelReadiness
    public let ambience: Ambience
    private var recheckTask: Task<Void, Never>?

    /// `readiness` answers whether Apple's on-device model can be used; by
    /// default the Foundation Models framework does. Tests supply their own.
    /// `sound` overrides the saved choice; tests keep the game silent.
    public init(
        store: SaveStore = SaveStore(),
        readiness: @escaping () -> ModelReadiness = { OnDeviceModel.current() },
        sound: Bool? = nil
    ) {
        self.store = store
        self.readModel = readiness
        self.hasSave = store.hasSave
        let soundOn = sound ?? (UserDefaults.standard.object(forKey: "sound.enabled") as? Bool ?? true)
        self.isSoundOn = soundOn
        self.ambience = Ambience(enabled: soundOn)
        checkModel()
        startFromEnvironment()
        // Whatever was ordered since the last watch is kept if the game is
        // put behind another app or quit.
        for name in [NSApplication.willResignActiveNotification, NSApplication.willTerminateNotification] {
            lifecycleObservers.append(NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.saveNow() }
            })
        }
    }

    @ObservationIgnored private var lifecycleObservers: [any NSObjectProtocol] = []

    /// Saves the game in progress, if there is one that hasn't ended.
    public func saveNow() {
        guard let session, session.state.outcome == nil else { return }
        session.save(quietly: true)
        hasSave = store.hasSave
    }

    public var session: GameSession? {
        if case .playing(let session) = phase { return session }
        return nil
    }

    // MARK: The on-device model

    /// Reads the model's state, and opens the title screen once it is ready.
    public func checkModel() {
        readiness = readModel()
        if readiness.allowsPlay {
            recheckTask?.cancel()
            recheckTask = nil
            if case .gate = phase {
                phase = .title
                ambience.start()
            }
        } else if readiness.needsRecheck, recheckTask == nil {
            recheckTask = Task { [weak self] in
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    guard let self, !Task.isCancelled else { return }
                    if NSApplication.shared.isActive { self.checkModel() }
                }
            }
        }
    }

    /// Debug builds can open straight into a new game on a given seed.
    private func startFromEnvironment() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if readiness.allowsPlay, let seed = environment["NULLMERE_NEW_GAME"], !seed.isEmpty {
            begin(GameSettings(seedText: seed))
            if let watches = environment["NULLMERE_AUTOPLAY"].flatMap(Int.init), watches > 0 {
                session?.autoplay(watches: watches)
            }
            // NULLMERE_SHOW=seat,houses selects the seat and opens a panel,
            // for screenshots of the interface.
            let show = Set((environment["NULLMERE_SHOW"] ?? "").split(separator: ",").map(String.init))
            if show.contains("seat") { session?.focusOnSeat() }
            if show.contains("houses") { session?.panel = .houses }
            if show.contains("chronicle") { session?.panel = .chronicle }
            if show.contains("guide") { session?.panel = .guide }
            // "watch" ends a watch a little before CI photographs the screen,
            // so the watch's card is on it.
            if show.contains("watch"), let delay = Double(environment["NULLMERE_WATCH_AFTER"] ?? "12.5") {
                Task { [weak self] in
                    try? await Task.sleep(for: .seconds(delay))
                    self?.session?.endWatch()
                }
            }
        }
        #endif
    }

    // MARK: Sound

    public var isSoundOn: Bool {
        didSet {
            ambience.isEnabled = isSoundOn
            UserDefaults.standard.set(isSoundOn, forKey: "sound.enabled")
        }
    }

    private func play(_ session: GameSession) {
        session.onCue = { [weak self] cue in self?.ambience.play(cue) }
        ambience.start()
        phase = .playing(session)
    }

    // MARK: Games

    /// Characters speak through the on-device model whenever it can be used.
    static func voice() -> (any Voice)? {
        OnDeviceVoice.isAvailable ? OnDeviceVoice() : nil
    }

    public func begin(_ settings: GameSettings) {
        guard readiness.allowsPlay else { return }
        let session = GameSession(state: GameState(settings: settings), store: store, voice: Self.voice())
        store.save(session.state)
        hasSave = true
        play(session)
    }

    public func continueSaved() {
        guard readiness.allowsPlay else { return }
        switch store.open() {
        case .game(let state):
            saveNotice = nil
            play(GameSession(state: state, store: store, voice: Self.voice()))
        case .recovered(let state):
            saveNotice = nil
            let session = GameSession(state: state, store: store, voice: Self.voice())
            session.post("The last save could not be read; the game goes on from the one before it.", tone: .bad)
            play(session)
        case .unreadable(let aside):
            saveNotice = "The saved game could not be read. It was kept as \(aside.lastPathComponent) in Application Support › Nullmere."
        case .none:
            break
        }
        hasSave = store.hasSave
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
