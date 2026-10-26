import AppKit
import LauncherCore
import LauncherKit
import NullmereCore
import NullmereRealm
import Observation
import os

/// The whole client: the gate on Apple's on-device model, the realm's front
/// door, and the keeper in the world.
@MainActor
@Observable
public final class GameApp {
    public enum Phase {
        /// Waiting for, or explaining the lack of, the on-device model.
        case gate
        /// The realm's front door: who you are, how the realm stands.
        case frontDoor
        case playing(GameSession)
    }

    /// How the realm looks from its front door.
    public enum Door: Equatable {
        case connecting
        case open(RealmStatus)
        case unreachable(String)
    }

    /// Where the realm is.
    public enum RealmAddress: Equatable {
        /// A realm hosted on this Mac: for development, and for CI.
        case hosted(seed: String)
        /// The realm proper, across the network.
        case network(URL)
    }

    public private(set) var phase: Phase = .gate
    public private(set) var readiness: ModelReadiness = .checking
    public private(set) var door: Door = .connecting
    /// The name this keeper goes by in the realm, once they've arrived.
    public private(set) var keeperName: String?
    /// Why the realm would not take the keeper in.
    public private(set) var arrivalProblem: String?
    public private(set) var isEntering = false
    /// Known to the realm, but every seat is held: the door asks again as
    /// the realm changes, and steps in when a seat falls free.
    public private(set) var isWaitingForSeat = false
    private var seatTimer: Timer?
    /// Back to the launcher, when the app has one.
    public var onLeave: (@MainActor () -> Void)?
    /// The game's settings, shown over the world or the front door.
    public var showsSettings = false

    let store: LocalStore
    let address: RealmAddress
    private let identityStore: any IdentityStore
    private let readModel: () -> ModelReadiness
    public let ambience: Ambience
    private var recheckTask: Task<Void, Never>?
    private var link: (any RealmLink)?
    private var hosted: LocalRealm?
    private var ticker: Timer?

    /// The name of the realm proper.
    public static let realmName = "The Nullmere"

    /// `readiness` answers whether Apple's on-device model can be used; by
    /// default the Foundation Models framework does. Tests supply their own,
    /// with a realm hosted in the test and an identity kept in a file.
    /// `sound` overrides the saved choice; tests keep the game silent.
    public init(
        store: LocalStore = LocalStore(),
        readiness: @escaping () -> ModelReadiness = { OnDeviceModel.current() },
        sound: Bool? = nil,
        address: RealmAddress? = nil,
        identity: (any IdentityStore)? = nil,
        opensAtOnce: Bool = true
    ) {
        self.store = store
        self.readModel = readiness
        self.address = address ?? GameApp.defaultAddress
        self.identityStore = identity ?? GameApp.defaultIdentityStore(for: address ?? GameApp.defaultAddress)
        keeperName = UserDefaults.standard.string(forKey: GameApp.nameKey(for: self.address))
        let soundOn = sound ?? (UserDefaults.standard.object(forKey: "sound.enabled") as? Bool ?? true)
        self.isSoundOn = soundOn
        self.ambience = Ambience(enabled: soundOn)
        ambience.effectsVolume = Float(effectsVolume)
        ambience.ambienceVolume = Float(ambienceVolume)
        ambience.musicVolume = Float(musicVolume)
        if opensAtOnce { checkModel() }
    }

    /// Crossing in from the launcher: the gate, then the realm's front door.
    public func open() {
        if case .frontDoor = phase {
            openDoor()
        } else {
            checkModel()
        }
    }

    /// The name a keeper goes by is remembered for each realm.
    static func nameKey(for address: RealmAddress) -> String {
        switch address {
        case .hosted: return "keeper.name.hosted"
        case .network(let url): return "keeper.name.\(url.host() ?? url.absoluteString)"
        }
    }

    private var enteredByIdentity = false
    private var autoEntered = false

    /// Debug builds may be pointed at another realm: NULLMERE_REALM=local
    /// hosts one on this Mac. The realm proper is the default.
    static var defaultAddress: RealmAddress {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        if environment["NULLMERE_REALM"] == "local" {
            return .hosted(seed: environment["NULLMERE_REALM_SEED"] ?? "the still water")
        }
        if let text = environment["NULLMERE_REALM"], let url = URL(string: text), url.scheme?.hasPrefix("http") == true {
            return .network(url)
        }
        #endif
        return .network(realmURL(in: Bundle.main.infoDictionary))
    }

    /// The realm proper: where the app was built to go (its Info.plist's
    /// NullmereRealm, set by scripts/build-app.sh), or maincloud's.
    static let maincloudURL = URL(string: "https://maincloud.spacetimedb.com/nullmere")!

    static func realmURL(in info: [String: Any]?) -> URL {
        if let text = info?["NullmereRealm"] as? String, let url = URL(string: text),
           url.scheme == "https" || url.scheme == "http", url.host() != nil, url.path().count > 1 {
            return url
        }
        return maincloudURL
    }

    /// Each realm knows the keeper by its own identity, kept in the keychain.
    static func defaultIdentityStore(for address: RealmAddress) -> any IdentityStore {
        #if DEBUG
        if let path = ProcessInfo.processInfo.environment["NULLMERE_IDENTITY_FILE"], !path.isEmpty {
            return FileIdentityStore(url: URL(fileURLWithPath: path))
        }
        #endif
        switch address {
        case .hosted: return KeychainIdentityStore(realm: "hosted")
        case .network(let url): return KeychainIdentityStore(realm: url.host() ?? url.absoluteString)
        }
    }

    public var session: GameSession? {
        if case .playing(let session) = phase { return session }
        return nil
    }

    // MARK: The on-device model

    /// Reads the model's state, and opens the realm's front door once it is ready.
    public func checkModel() {
        readiness = readModel()
        if readiness.allowsPlay {
            recheckTask?.cancel()
            recheckTask = nil
            if case .gate = phase {
                phase = .frontDoor
                ambience.start()
                openDoor()
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

    // MARK: The front door

    /// Reaches for the realm and asks how it stands.
    public func openDoor() {
        door = .connecting
        arrivalProblem = nil
        isEntering = false
        stopWaiting()
        let link: any RealmLink
        switch address {
        case .hosted(let seed):
            let realm = hosted ?? LocalRealm.open(at: store.hostedRealmURL, name: "This Mac's realm", seed: seed)
            hosted = realm
            link = realm.link(identity: identityStore.identity())
            startTicking(realm)
        case .network(let url):
            guard let transport = SpacetimeHTTP(address: url) else {
                door = .unreachable("The realm's address can't be read.")
                return
            }
            link = NetworkRealmLink(transport: transport, credentials: identityStore)
        }
        self.link = link
        link.onEvent = { [weak self] event in self?.hear(event) }
        link.connect()
    }

    /// A realm hosted here turns its watch on time, as a server would.
    private func startTicking(_ realm: LocalRealm) {
        guard ticker == nil else { return }
        ticker = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak realm] _ in
            MainActor.assumeIsolated { realm?.tick() }
        }
    }

    /// Whether the keeper can step in: the realm is open, and they're known
    /// to it or have a name ready.
    public func canEnter(with name: String) -> Bool {
        guard case .open = door, !isEntering, !isWaitingForSeat else { return false }
        return keeperName != nil || RealmState.isValidName(name)
    }

    /// Steps into the world: a returning keeper by their identity, a new one
    /// with the name they chose.
    public func enterWorld(name: String) {
        guard canEnter(with: name), let link else { return }
        isEntering = true
        arrivalProblem = nil
        enteredByIdentity = keeperName != nil
        link.arrive(name: keeperName == nil ? name : nil)
    }

    private func hear(_ event: RealmEvent) {
        switch event {
        case .status(let status):
            door = .open(status)
            if isWaitingForSeat {
                // Only when a seat stands free: asking changes the status.
                if status.freeSeats > 0, !status.isEnding { askForSeat() }
            } else if !autoEntered {
                autoEntered = true
                enterFromEnvironment()
            }
        case .arrived(let keeper, let world):
            arrived(keeper, in: world)
        case .refused(let error):
            Self.logger.notice("The realm refused the keeper: \(error.description, privacy: .public)")
            isEntering = false
            if enteredByIdentity, error == .nameInvalid || error == .unknownKeeper {
                // The realm has forgotten this keeper: they choose a name anew.
                keeperName = nil
                UserDefaults.standard.removeObject(forKey: Self.nameKey(for: address))
                arrivalProblem = "The realm doesn't know you yet. Choose the name you'll go by."
            } else {
                arrivalProblem = error.description
            }
        case .unreachable(let reason):
            if door != .unreachable(reason) {
                Self.logger.notice("The realm is unreachable: \(reason, privacy: .public)")
            }
            isEntering = false
            door = .unreachable(reason)
        case .settled, .orderRefused, .changed, .watchTurned:
            break
        }
    }

    private static let logger = Logger(subsystem: "online.nullmere.game", category: "realm")

    private func arrived(_ keeper: Keeper, in world: GameState) {
        Self.logger.notice("Entered the realm as \(keeper.name, privacy: .public), watch \(world.watch).")
        isEntering = false
        keeperName = keeper.name
        UserDefaults.standard.set(keeper.name, forKey: Self.nameKey(for: address))
        guard let house = keeper.house, let link else {
            startWaiting()
            return
        }
        stopWaiting()
        let doorAge: Int? = { if case .open(let status) = self.door { return status.age } else { return nil } }()
        let age = session?.realmStatus?.age ?? doorAge ?? 1
        let session = GameSession(link: link, house: house, world: world, store: store.forAge(age, of: Self.realmName),
                                  voice: Self.voice(), host: hosted)
        session.onNewAge = { [weak self] keeper, world in self?.arrived(keeper, in: world) }
        play(session)
        showFromEnvironment()
    }

    private func startWaiting() {
        guard !isWaitingForSeat else { return }
        isWaitingForSeat = true
        arrivalProblem = nil
        // A seat can fall free with the clock alone, when its keeper has
        // been away a week.
        seatTimer = Timer.scheduledTimer(withTimeInterval: 30, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.askForSeat() }
        }
    }

    func askForSeat() {
        guard isWaitingForSeat, case .frontDoor = phase else { return }
        link?.arrive(name: nil)
    }

    private func stopWaiting() {
        isWaitingForSeat = false
        seatTimer?.invalidate()
        seatTimer = nil
    }

    /// Leaves the world for the front door; the keeper's House stands as
    /// they left it.
    public func leaveWorld() {
        link?.leave()
        link = nil
        phase = .frontDoor
        openDoor()
    }

    /// Leaves the front door for the launcher.
    public func leaveDoor() {
        stopWaiting()
        link?.leave()
        link = nil
        onLeave?()
    }

    /// Debug builds can step straight in, and set the scene for screenshots.
    func enterFromEnvironment() {
        #if DEBUG
        if let name = ProcessInfo.processInfo.environment["NULLMERE_KEEPER"], !name.isEmpty {
            enterWorld(name: name)
        }
        #endif
    }

    private func showFromEnvironment() {
        #if DEBUG
        let environment = ProcessInfo.processInfo.environment
        guard environment["NULLMERE_KEEPER"] != nil else { return }
        if let watches = environment["NULLMERE_AUTOPLAY"].flatMap(Int.init), watches > 0 {
            session?.autoplay(watches: watches)
        }
        // NULLMERE_SHOW=seat,houses selects the seat and opens a panel,
        // for screenshots of the interface; "briefing" keeps the card a
        // keeper first meets.
        let show = Set((environment["NULLMERE_SHOW"] ?? "").split(separator: ",").map(String.init))
        // The cards a keeper first meets are shown only when asked for.
        if !show.contains("briefing") {
            session?.dismissSeatBriefing()
            session?.dismissAwayReport()
        }
        if show.contains("seat") { session?.focusOnSeat() }
        if show.contains("unit") { session?.selectNextReadyUnit() }
        if show.contains("houses") { session?.panel = .houses }
        if show.contains("chronicle") { session?.panel = .chronicle }
        if show.contains("guide") { session?.panel = .guide }
        // "watch" makes the keeper ready a little before CI photographs the
        // screen, so the watch's card is on it.
        if show.contains("watch"), let delay = Double(environment["NULLMERE_WATCH_AFTER"] ?? "12.5") {
            session?.keepsWatchCard = true
            Task { [weak self] in
                try? await Task.sleep(for: .seconds(delay))
                self?.session?.endWatch()
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

    public var isMusicOn: Bool = UserDefaults.standard.object(forKey: "music.enabled") as? Bool ?? true {
        didSet {
            ambience.isMusicOn = isMusicOn
            UserDefaults.standard.set(isMusicOn, forKey: "music.enabled")
        }
    }

    /// How loud the cues, the night and the score play, each from 0 to 1.
    public var effectsVolume: Double = GameApp.storedVolume("volume.effects") {
        didSet { ambience.effectsVolume = Float(effectsVolume); UserDefaults.standard.set(effectsVolume, forKey: "volume.effects") }
    }

    public var ambienceVolume: Double = GameApp.storedVolume("volume.ambience") {
        didSet { ambience.ambienceVolume = Float(ambienceVolume); UserDefaults.standard.set(ambienceVolume, forKey: "volume.ambience") }
    }

    public var musicVolume: Double = GameApp.storedVolume("volume.music") {
        didSet { ambience.musicVolume = Float(musicVolume); UserDefaults.standard.set(musicVolume, forKey: "volume.music") }
    }

    static func storedVolume(_ key: String) -> Double {
        min(max(UserDefaults.standard.object(forKey: key) as? Double ?? 1, 0), 1)
    }

    private func play(_ session: GameSession) {
        session.onCue = { [weak self] cue in self?.ambience.play(cue) }
        ambience.isMusicOn = isMusicOn
        session.onWarChanged = { [weak self] atWar in self?.ambience.isAtWar = atWar }
        ambience.start()
        phase = .playing(session)
    }

    /// Characters speak through the on-device model whenever it can be used.
    static func voice() -> (any Voice)? {
        OnDeviceVoice.isAvailable ? OnDeviceVoice() : nil
    }
}
