import AppKit
import Foundation
import NullmereCore
import NullmereRealm
import Observation
import SwiftUI

/// A keeper in the world, and everything the interface needs: what is
/// selected, where the camera looks, what just happened. The realm holds the
/// world; the session holds the keeper's copy of it, carries out their
/// orders at once as the realm will, and takes the realm's word as final.
@MainActor
@Observable
public final class GameSession {
    public enum Selection: Equatable {
        case none
        case unit(Int)
        case hold(Int)
        case tile(Hex)
    }

    public enum Panel: Equatable {
        case houses
        case chronicle
        case guide
    }

    /// A short line of news for the feed under the top bar.
    public struct Notice: Identifiable, Equatable {
        public enum Tone: Equatable {
            case neutral
            case good
            case bad
        }

        public let id: Int
        public let text: String
        public let tone: Tone
    }

    public private(set) var state: GameState
    public var camera: Camera
    public var hovered: Hex?
    public var selection: Selection = .none {
        didSet {
            if selection != oldValue {
                refreshReach()
                refreshPathPreview()
            }
        }
    }
    public var panel: Panel?
    public private(set) var notices: [Notice] = []
    public private(set) var pathPreview: [Hex] = []
    /// Where the selected company could march this watch, and what it could strike.
    public private(set) var reach: Set<Hex> = []
    public private(set) var strikeTargets: [Hex] = []
    /// What attacking the hovered hex with the selected company would do.
    public private(set) var hoverForecast: Forecast?
    public private(set) var tileBytes: [UInt8] = []
    public private(set) var tilesVersion = 0
    /// Which hold's land each tile is, by map index.
    public private(set) var territory: [Int?] = []
    /// The texture's unchanging ground, made again only when the map changes.
    @ObservationIgnored private var ground: TileTexture.Ground?
    /// Holds and units the player can see right now, by map index.
    public private(set) var visible: [Bool] = []
    public private(set) var isEndingWatch = false

    /// What a character has said about something, once the on-device model
    /// has put it into words.
    public enum Spoken: Hashable, Sendable {
        case envoy(Int)
        case chronicle(Int)

        var key: String {
            switch self {
            case .envoy(let id): return "envoy-\(id)"
            case .chronicle(let index): return "chronicle-\(index)"
            }
        }

        init?(key: String) {
            let parts = key.split(separator: "-")
            guard parts.count == 2, let number = Int(parts[1]) else { return nil }
            switch parts[0] {
            case "envoy": self = .envoy(number)
            case "chronicle": self = .chronicle(number)
            default: return nil
            }
        }
    }

    public private(set) var spoken: [Spoken: String] = [:]

    /// The keeper's line to the realm.
    private let link: any RealmLink
    /// A realm hosted in this process, kept alive while the session lives.
    private let host: LocalRealm?
    /// The House the keeper holds.
    public let player: Int
    /// How the realm stands, as last heard, and when.
    public private(set) var realmStatus: RealmStatus?
    /// The realm couldn't be reached when last asked; the link keeps trying.
    public private(set) var isOutOfReach = false
    private var statusHeard = Date()
    /// The keeper has given their orders and waits for the watch to turn.
    public private(set) var isReady = false
    /// Watches still to pass while nothing needs the keeper, and passed so far.
    private var quietLeft = 0
    private var quietPassed = 0
    private var isAutoplaying = false
    /// Called when a new age begins and the keeper is seated afresh.
    public var onNewAge: ((Keeper, GameState) -> Void)?

    /// A company's march being shown, from where it stood along the route.
    public struct March: Equatable {
        public let path: [Hex]
        public let start: Date

        public static let secondsPerStep = 0.16

        public var duration: Double { Double(max(path.count - 1, 1)) * March.secondsPerStep }
    }

    /// Called with each sound the game makes.
    public var onCue: ((Ambience.Cue) -> Void)?
    /// Called when the player goes to war, or the last of their wars ends.
    public var onWarChanged: ((Bool) -> Void)? {
        didSet { onWarChanged?(isAtWar) }
    }
    public private(set) var isAtWar = false

    /// A blow the player saw land: a ring and the damage, briefly, where it fell.
    public struct Blow: Equatable, Identifiable {
        public let id: Int
        public let at: Hex
        public let damage: Int
        /// Whether it fell on the player's side.
        public let againstPlayer: Bool
        public let start: Date
        /// Where the attacker struck from.
        public var from: Hex
        public var attacker: Int = 0
        public var defender: Int?
        /// Companies that fell in it, drawn fading where they stood.
        public var fallen: [Fallen] = []

        public struct Fallen: Equatable {
            public let kind: UnitKind
            public let owner: Int
            public let at: Hex
        }

        public static let duration = 1.4

        /// A blow from beyond the next tile is a bow's.
        public var isRanged: Bool { from.distance(to: at) > 1 }

        /// How far toward its foe an attacker leans, as a share of the way,
        /// at `age` (a share of the blow's duration): in and back quickly.
        public static func lunge(at age: Double) -> Double {
            guard age > 0, age < 0.3 else { return 0 }
            return 0.38 * sin(Double.pi * age / 0.3)
        }

        /// How far the struck company shakes, in points, once the blow lands.
        public static func shake(at age: Double) -> Double {
            guard age > 0.1, age < 0.45 else { return 0 }
            let t = (age - 0.1) / 0.35
            return sin(t * Double.pi * 6) * 3 * (1 - t)
        }

        /// The flash where it lands: bright at the moment of the blow, gone
        /// a moment later.
        public static func flash(at age: Double) -> Double {
            guard age >= 0.08, age < 0.3 else { return 0 }
            return 1 - (age - 0.08) / 0.22
        }
    }

    /// The card marking the watch that just began, while it shows.
    private(set) var watchCard: (id: Int, summary: WatchSummary)?
    /// What happened while the keeper was away, until they have read it.
    private(set) var awayReport: AwayReport?
    /// The first time in an age: the House the keeper takes up.
    private(set) var seatBriefing: SeatBriefing?
    /// The Dock's count of watches turned while the keeper was elsewhere.
    private(set) var attention = Attention()
    /// Whether the keeper is looking, and how the Dock is told; tests
    /// supply their own.
    var isLooking: () -> Bool = { NSApplication.shared.isActive }
    var signal: (Attention.Signal) -> Void = { Attention.show($0) }
    private var watchCardCounter = 0
    /// Keeps the watch's card on screen, for photographs.
    var keepsWatchCard = false

    /// Blows still being drawn.
    public private(set) var blows: [Blow] = []
    /// The player's holds with enemy companies gathering near them.
    public private(set) var threatened: Set<Int> = []
    private var blowCounter = 0

    /// Marches still being drawn, by unit.
    public private(set) var marches: [Int: March] = [:]

    private var noticeCounter = 0
    private let store: LocalStore
    private let voice: (any Voice)?
    private var voiceQueue: [(Spoken, VoiceMoment)] = []
    private var asked: Set<Spoken> = []
    private var isSpeaking = false

    /// Whether any character is still to speak, or speaking.
    var voicesPending: Bool { isSpeaking || !voiceQueue.isEmpty }

    /// A keeper's session in a realm, as they arrive in it.
    public init(link: any RealmLink, house: Int, world: GameState, store: LocalStore = LocalStore(), voice: (any Voice)? = nil,
                host: LocalRealm? = nil) {
        self.link = link
        self.host = host
        self.player = house
        self.state = world
        self.store = store
        self.voice = voice
        var camera = Camera(scale: 28)
        if let seat = world.seat(of: house) {
            camera.focus(on: seat.position)
        }
        self.camera = camera
        // A game picked up again keeps what was said, and doesn't retell
        // the rest of its history.
        asked = Set(state.chronicle.indices.map { Spoken.chronicle($0) })
        for (key, words) in store.loadVoices() {
            if let spoken = Spoken(key: key) {
                self.spoken[spoken] = words
                asked.insert(spoken)
            }
        }
        refreshWorld()
        if let seen = store.loadLastSeen() {
            awayReport = AwayReport(since: seen, now: world, player: house)
        } else if world.houses.indices.contains(house) {
            seatBriefing = SeatBriefing(world: world, player: house)
        }
        rememberSeen()
        link.onEvent = { [weak self] event in self?.hear(event) }
        link.connect()
    }

    /// One House's game in a realm hosted here, its keeper holding the
    /// world's first kept House: for tests, and for rehearsing on one Mac.
    public convenience init(state: GameState, store: LocalStore = LocalStore(), voice: (any Voice)? = nil) {
        let identity = "rehearsal"
        let realm = LocalRealm(state: RealmState(name: "Rehearsal", world: state, keeper: identity, now: Date().timeIntervalSince1970))
        self.init(link: realm.link(identity: identity), house: state.player, world: state.view(for: state.player), store: store,
                  voice: voice, host: realm)
    }

    public var playerHouse: House { state.houses[player] }

    /// Envoys waiting on this keeper's answer.
    public var envoys: [Envoy] { state.envoys.filter { $0.to == player } }

    /// Seconds until the watch turns of its own accord, counting down from
    /// what the realm last said.
    public func secondsLeft(at date: Date = Date()) -> Int? {
        guard let status = realmStatus else { return nil }
        return max(0, status.secondsLeft - Int(date.timeIntervalSince(statusHeard)))
    }

    // MARK: Reading

    public var selectedUnit: NullmereCore.Unit? {
        if case .unit(let id) = selection { return state.unit(id) }
        return nil
    }

    public var selectedHold: Hold? {
        if case .hold(let id) = selection { return state.hold(id) }
        return nil
    }

    public var selectedHex: Hex? {
        switch selection {
        case .none: return nil
        case .unit(let id): return state.unit(id)?.position
        case .hold(let id): return state.hold(id)?.position
        case .tile(let hex): return hex
        }
    }

    public func isVisible(_ hex: Hex) -> Bool {
        guard let index = state.map.index(of: hex), visible.indices.contains(index) else { return false }
        return visible[index]
    }

    public func isExplored(_ hex: Hex) -> Bool {
        guard let index = state.map.index(of: hex) else { return false }
        return playerHouse.explored[index]
    }

    /// Units of the player's that can still act this watch.
    public var readyUnits: [NullmereCore.Unit] {
        state.units(of: player).filter { $0.movesLeft > 0 && $0.destination == nil && !$0.fortified }
    }

    /// Holds of the player's with nothing being built.
    public var idleHolds: [Hold] {
        state.holds(of: player).filter { $0.project == nil }
    }

    // MARK: Pointer

    /// What a click or right-click on a hex would do, for the pointer's shape
    /// and the marks under it.
    public enum PointerAction: Equatable {
        case none
        /// Selects one of the player's companies or holds, or looks at another's.
        case select
        /// The selected company would march here this watch.
        case march
        /// The selected company would strike here.
        case strike
    }

    public func pointerAction(at hex: Hex) -> PointerAction {
        guard state.map.contains(hex) else { return .none }
        if strikeTargets.contains(hex) { return .strike }
        if let unit = state.unit(at: hex), unit.owner == player { return .select }
        if let hold = state.hold(at: hex), hold.owner == player || isExplored(hex) { return .select }
        if let unit = state.unit(at: hex), isVisible(hex), unit.owner != player { return .select }
        if reach.contains(hex) { return .march }
        return .none
    }

    public func hover(_ hex: Hex?) {
        guard hex != hovered else { return }
        hovered = hex
        refreshPathPreview()
    }

    /// Selects what stands on a hex: the player's unit, then any hold, then
    /// any visible unit, then the tile itself.
    public func click(_ hex: Hex) {
        guard state.map.contains(hex) else {
            selection = .none
            return
        }
        defer { if selection != Selection.none { onCue?(.select) } }
        if let unit = state.unit(at: hex), unit.owner == player {
            selection = selection == .unit(unit.id) ? holdOrTile(at: hex) : .unit(unit.id)
        } else if let hold = state.hold(at: hex), isExplored(hex) {
            selection = .hold(hold.id)
        } else if let unit = state.unit(at: hex), isVisible(hex) {
            selection = .unit(unit.id)
        } else {
            selection = .tile(hex)
        }
    }

    private func holdOrTile(at hex: Hex) -> Selection {
        if let hold = state.hold(at: hex) { return .hold(hold.id) }
        return .tile(hex)
    }

    /// The order a right-click gives: the selected unit marches, or strikes
    /// an enemy it can reach.
    public func order(_ hex: Hex) {
        guard let unit = selectedUnit, unit.owner == player else { return }
        let foe = (state.unit(at: hex).map { $0.owner != player } ?? false)
            || (state.hold(at: hex).map { $0.owner != player } ?? false)
        if foe, unit.kind.isMilitary, unit.position.distance(to: hex) <= unit.kind.range {
            perform(.attack(unit: unit.id, target: hex))
        } else {
            perform(.move(unit: unit.id, to: hex))
        }
    }

    // MARK: Orders

    /// Carries out a command for the player. A refusal becomes a notice.
    @discardableResult
    public func perform(_ command: Command) -> Bool {
        do {
            let before = positions()
            // Carried out here at once, as the realm will; its word follows.
            let events = try state.perform(command, as: player)
            link.send(command)
            showMarches(events, from: before)
            showBlows(events, from: before)
            report(events)
            sound(for: command, events: events)
            if case .found = command, let hold = events.compactMap(holdFounded).first {
                selection = .hold(hold)
            }
            refreshWorld()
            return true
        } catch {
            post(String(describing: error), tone: .bad)
            return false
        }
    }

    private func holdFounded(_ event: GameEvent) -> Int? {
        if case .holdFounded(let id) = event { return id }
        return nil
    }

    /// The keeper is done with this watch's orders. The watch turns when
    /// every keeper there is ready, or when its time runs out.
    public func endWatch() {
        guard state.outcome == nil, !isReady else { return }
        isReady = true
        link.setReady(true)
    }

    /// Takes back being ready, while the watch hasn't turned.
    public func cancelReady() {
        guard isReady else { return }
        isReady = false
        quietLeft = 0
        quietPassed = 0
        link.setReady(false)
    }

    /// Most watches that pass at once while nothing needs the player.
    public static let quietWatchLimit = 10

    /// Stays ready, watch after watch, until something needs the player:
    /// news worth hearing, an envoy, a threat, a company or a hold without
    /// orders, the end of the age; at most `quietWatchLimit` watches.
    public func endWatchesUntilNeeded() {
        guard state.outcome == nil, !isReady else { return }
        quietLeft = Self.quietWatchLimit - 1
        quietPassed = 0
        endWatch()
    }

    /// Whether, after a watch, the player has something to see to.
    static func needsPlayer(after watch: [GameEvent], from before: GameState, to after: GameState, player: Int,
                            threatened: Set<Int>) -> Bool {
        if after.outcome != nil { return true }
        if watch.contains(where: { if case .envoyArrived(let envoy) = $0 { return envoy.to == player } else { return false } }) { return true }
        if watch.contains(where: { Narration.line(for: $0, in: after, viewer: player).map { $0.tone != .neutral } ?? false }) {
            return true
        }
        if !Race.warnings(before: before, after: after, player: player).isEmpty { return true }
        let threats = Sentinel.threats(in: after, player: player, visible: after.visibility(for: player))
        if threats.contains(where: { !threatened.contains($0.hold) }) { return true }
        if after.units(of: player).contains(where: { $0.movesLeft > 0 && $0.destination == nil && !$0.fortified }) { return true }
        return after.holds(of: player).contains { $0.project == nil }
    }

    // MARK: While away

    /// Keeps what the keeper has now seen of their House, for the report
    /// when they return.
    private func rememberSeen() {
        guard state.houses.indices.contains(player) else { return }
        store.saveLastSeen(LastSeen(watch: state.watch, stock: state.houses[player].stock, holds: state.holds(of: player).count))
    }

    // MARK: Keepers' words

    /// Houses whose keepers' words this keeper would rather not read,
    /// kept on this Mac by House name.
    public private(set) var mutedHouses: Set<String> = Set(UserDefaults.standard.stringArray(forKey: GameSession.mutedKey) ?? [])
    static let mutedKey = "words.muted"

    public func setMuted(_ muted: Bool, house: House) {
        if muted { mutedHouses.insert(house.name) } else { mutedHouses.remove(house.name) }
        UserDefaults.standard.set(mutedHouses.sorted(), forKey: Self.mutedKey)
    }

    /// The words an envoy carries, if any and not silenced.
    public func words(of envoy: Envoy) -> String? {
        guard let words = envoy.words, state.houses.indices.contains(envoy.from),
              !mutedHouses.contains(state.houses[envoy.from].name) else { return nil }
        return words
    }

    /// An offer, with words when there are any for a House a keeper holds.
    public func propose(_ proposal: Proposal, to house: House, words: String) {
        if house.isPlayer, let carried = Envoy.carried(words) {
            perform(.proposeWithWords(proposal, to: house.id, words: carried))
        } else {
            perform(.propose(proposal, to: house.id))
        }
    }

    /// The keeper came back to the app.
    public func keeperReturned() {
        if let call = attention.returned() { signal(call) }
    }

    public func dismissSeatBriefing() {
        withAnimation(.easeOut(duration: 0.3)) { seatBriefing = nil }
    }

    public func dismissAwayReport() {
        withAnimation(.easeOut(duration: 0.3)) { awayReport = nil }
    }

    // MARK: The realm's word

    private func hear(_ event: RealmEvent) {
        if case .unreachable(let reason) = event {
            // Said once, however often the link tries again.
            if !isOutOfReach {
                isOutOfReach = true
                post("The realm is out of reach: \(reason) Orders given now wait, and go when it answers.", tone: .bad)
            }
            return
        }
        if isOutOfReach {
            isOutOfReach = false
            post("The realm answers again.", tone: .good)
        }
        switch event {
        case .status(let status):
            realmStatus = status
            statusHeard = Date()
        case .settled(let world, _), .changed(let world):
            adopt(world)
        case .orderRefused(let error, let world):
            adopt(world)
            post(error.description, tone: .bad)
        case .watchTurned(let world, let events):
            watchTurned(to: world, events: events)
        case .unreachable:
            break
        case .arrived(let keeper, let world):
            // Only a new age seats a keeper already in the world.
            onNewAge?(keeper, world)
        case .refused:
            break
        }
    }

    /// Takes the realm's world as it is, where it differs from ours.
    private func adopt(_ world: GameState) {
        guard world != state else { return }
        state = world
        if case .unit(let id) = selection, state.unit(id) == nil { selection = .none }
        if case .hold(let id) = selection, state.hold(id) == nil { selection = .none }
        refreshWorld()
    }

    /// The watch turned in the realm: show what it brought.
    private func watchTurned(to world: GameState, events: [GameEvent]) {
        let previous = state
        let before = positions()
        state = world
        rememberSeen()
        isReady = false
        guard !isAutoplaying else { return }
        isEndingWatch = true
        quietPassed += 1
        showWatchCard(WatchSummary(before: previous, after: state, events: events, player: player))
        showMarches(events, from: before)
        showBlows(events, from: before)
        for cue in Self.cues(for: events, player: player) {
            onCue?(cue)
        }
        notices.removeAll()
        report(events)
        var warnings = Race.warnings(before: previous, after: state, player: player)
        let threats = Sentinel.threats(in: state, player: player, visible: state.visibility(for: player))
        warnings += threats.filter { !threatened.contains($0.hold) }.map { Sentinel.line(for: $0, in: state) }
        for warning in warnings {
            post(warning.text, tone: warning.tone)
        }
        if warnings.contains(where: { $0.tone == .bad }), !Self.cues(for: events, player: player).contains(.dread) {
            onCue?(.dread)
        }
        let needed = Self.needsPlayer(after: events, from: previous, to: state, player: player, threatened: threatened)
        if case .unit(let id) = selection, state.unit(id) == nil {
            selection = .none
        }
        refreshWorld()
        isEndingWatch = false
        if let call = attention.watchTurned(isActive: isLooking(), needsKeeper: needed) {
            signal(call)
        }
        if quietLeft > 0, !needed {
            quietLeft -= 1
            endWatch()
        } else {
            if quietPassed > 1 {
                post("\(quietPassed) quiet watches pass.", tone: .neutral)
            }
            quietLeft = 0
            quietPassed = 0
        }
    }

    /// Selects the next unit that's waiting for orders.
    public func selectNextReadyUnit() {
        let ready = readyUnits.sorted { $0.id < $1.id }
        guard !ready.isEmpty else {
            post("Every company has its orders.", tone: .neutral)
            return
        }
        let current = selectedUnit?.id ?? -1
        let next = ready.first { $0.id > current } ?? ready[0]
        selection = .unit(next.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            camera.focus(on: next.position)
        }
    }

    public func focusOnSeat() {
        guard let seat = state.seat(of: player) else { return }
        selection = .hold(seat.id)
        withAnimation(.easeInOut(duration: 0.4)) {
            camera.focus(on: seat.position)
        }
    }

    /// Lets a steward play the player's watches in a realm hosted here,
    /// the watch turning after each: for screenshots and tests of a game
    /// well under way.
    func autoplay(watches: Int) {
        guard let host, let identity = (link as? LocalLink)?.identity else { return }
        isAutoplaying = true
        host.autoplay(identity, watches: watches)
        isAutoplaying = false
        notices.removeAll()
        selection = .none
        refreshWorld()
        if let seat = state.seat(of: player) {
            camera.focus(on: seat.position)
        }
    }

    // MARK: Bookkeeping

    private func refreshWorld() {
        visible = state.visibility(for: player)
        threatened = Set(Sentinel.threats(in: state, player: player, visible: visible).map(\.hold))
        territory = state.territory()
        refreshReach()
        let atWar = state.livingHouses.contains { state.isAtWar(player, $0.id) }
        if atWar != isAtWar {
            isAtWar = atWar
            onWarChanged?(atWar)
        }
        if ground?.map != state.map { ground = TileTexture.Ground(map: state.map) }
        tileBytes = TileTexture.bytes(for: state, viewer: player, visible: visible, owners: territory, ground: ground)
        tilesVersion += 1
        refreshPathPreview()
        askVoices()
    }

    // MARK: Sound

    private func sound(for command: Command, events: [GameEvent]) {
        for cue in Self.cues(for: command, events: events, in: state, player: player) {
            onCue?(cue)
        }
    }

    /// The sounds an order makes: each kind of company its own.
    static func cues(for command: Command, events: [GameEvent], in state: GameState, player: Int) -> [Ambience.Cue] {
        switch command {
        case .attack:
            let ranged = events.contains { if case .battle(let battle) = $0 { return battle.attackerKind == .bow } else { return false } }
            var cues: [Ambience.Cue] = [ranged ? .loose : .clash]
            if events.contains(where: { if case .holdCaptured(_, _, let by) = $0 { return by == player } else { return false } }) {
                cues.append(.triumph)
            }
            return cues
        case .move(let unit, _):
            return [state.unit(unit)?.kind == .rider ? .ride : .order]
        default:
            return [plainCue(for: command, events: events)]
        }
    }

    private static func plainCue(for command: Command, events: [GameEvent]) -> Ambience.Cue {
        switch command {
        case .found, .build, .train: return .rise
        case .declareWar: return .dread
        case .answer(_, true) where events.contains(where: { if case .proposalAnswered(_, _, _, true) = $0 { return true } else { return false } }):
            return .accord
        default: return .select
        }
    }

    /// The sounds a watch's turning makes for the player, the watch's bell
    /// first and each other sound once.
    static func cues(for events: [GameEvent], player: Int) -> [Ambience.Cue] {
        var cues: [Ambience.Cue] = [.watch]
        func add(_ cue: Ambience.Cue) { if !cues.contains(cue) { cues.append(cue) } }
        for event in events {
            switch event {
            case .houseFell: add(.toll)
            case .gameEnded(let outcome): add(outcome.winner == player ? .triumph : .toll)
            case .holdCaptured(_, let from, let by):
                if by == player { add(.triumph) } else if from == player { add(.dread) }
            case .stanceChanged(let first, let second, let stance, let by) where (first == player || second == player) && by != player:
                add(stance == .war ? .dread : .accord)
            case .proposalAnswered(_, let from, let to, true) where from == player || to == player:
                add(.accord)
            case .envoyArrived:
                add(.envoy)
            default:
                break
            }
        }
        return cues
    }


    /// Whether the player may demand tribute of a House now: at peace,
    /// neither sworn to the other, no tribute paid between them lately, and
    /// the player clearly the stronger, as a rival would need to be.
    public func canDemandTribute(from house: Int) -> Bool {
        guard let other = state.house(house), !other.isEliminated, house != player else { return false }
        return state.stance(player, house) == .peace && other.liege != player && playerHouse.liege != house
            && !state.paidTributeLately(player, house)
            && state.strength(of: player) * 100 > state.strength(of: house) * 125
    }

    // MARK: The watch's card

    static let watchCardDuration = 2.6

    private func showWatchCard(_ summary: WatchSummary) {
        guard state.outcome == nil else { return }
        watchCardCounter += 1
        let id = watchCardCounter
        withAnimation(.easeOut(duration: 0.5)) { watchCard = (id, summary) }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Self.watchCardDuration))
            guard let self, self.watchCard?.id == id, !self.keepsWatchCard else { return }
            withAnimation(.easeIn(duration: 0.8)) { self.watchCard = nil }
        }
    }

    // MARK: Blows

    /// Draws the blows the player could see, then forgets them.
    func showBlows(_ events: [GameEvent], from before: [Int: Hex] = [:]) {
        let now = Date()
        var shown = false
        for case .battle(let battle) in events {
            let mine = battle.attackerOwner == player || battle.defenderOwner == player
            guard mine || isVisible(battle.at) else { continue }
            blowCounter += 1
            let from = before[battle.attacker] ?? state.unit(battle.attacker)?.position ?? battle.at
            var fallen: [Blow.Fallen] = []
            if battle.defenderFell, battle.hold == nil, let kind = battle.defenderKind {
                fallen.append(.init(kind: kind, owner: battle.defenderOwner, at: battle.at))
            }
            if battle.attackerFell {
                fallen.append(.init(kind: battle.attackerKind, owner: battle.attackerOwner, at: from))
            }
            blows.append(Blow(id: blowCounter, at: battle.at, damage: battle.damageDealt,
                              againstPlayer: battle.defenderOwner == player, start: now,
                              from: from, attacker: battle.attacker, defender: battle.defender, fallen: fallen))
            shown = true
        }
        guard shown else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Blow.duration + 0.05))
            guard let self else { return }
            self.blows.removeAll { Date().timeIntervalSince($0.start) >= Blow.duration }
        }
    }

    // MARK: Marches

    private func positions() -> [Int: Hex] {
        Dictionary(uniqueKeysWithValues: state.units.map { ($0.id, $0.position) })
    }

    /// Draws the marches the player could see, all at once, then forgets them.
    private func showMarches(_ events: [GameEvent], from before: [Int: Hex]) {
        let now = Date()
        var longest = 0.0
        for case .moved(let id, let steps) in events {
            guard let origin = before[id], !steps.isEmpty,
                  state.unit(id)?.owner == player || ([origin] + steps).contains(where: isVisible)
            else { continue }
            let march = March(path: [origin] + steps, start: now)
            marches[id] = march
            longest = max(longest, march.duration)
        }
        guard longest > 0 else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(longest + 0.05))
            guard let self else { return }
            self.marches = self.marches.filter { Date().timeIntervalSince($0.value.start) < $0.value.duration }
        }
    }

    // MARK: Voices

    /// Asks for words for new envoys, and for the moments of the chronicle
    /// that touch the player, one at a time.
    private func askVoices() {
        guard voice != nil else { return }
        // Envoys of stewards speak; a keeper's envoy carries their offer, not
        // words the model would put in a person's mouth.
        for envoy in envoys where !asked.contains(.envoy(envoy.id)) && !state.houses[envoy.from].isPlayer {
            asked.insert(.envoy(envoy.id))
            voiceQueue.append((.envoy(envoy.id), VoiceFacts.envoy(envoy, in: state)))
        }
        for (index, entry) in state.chronicle.enumerated() where !asked.contains(.chronicle(index)) {
            asked.insert(.chronicle(index))
            if VoiceFacts.isVoiced(entry.kind), entry.houses.contains(player) || entry.kind == .ending {
                voiceQueue.append((.chronicle(index), VoiceFacts.chronicle(entry, in: state)))
            }
        }
        speakNext()
    }

    private func speakNext() {
        guard !isSpeaking, let voice, !voiceQueue.isEmpty else { return }
        let (key, moment) = voiceQueue.removeFirst()
        if case .envoy(let id) = key, !state.envoys.contains(where: { $0.id == id }) {
            speakNext()
            return
        }
        isSpeaking = true
        Task { [weak self] in
            let words = await voice.speak(moment)
            guard let self else { return }
            if let words {
                withAnimation(.easeOut(duration: 0.6)) { self.spoken[key] = words }
                self.store.saveVoices(Dictionary(uniqueKeysWithValues: self.spoken.map { ($0.key.key, $0.value) }))
            }
            self.isSpeaking = false
            self.speakNext()
        }
    }

    private func refreshReach() {
        if let unit = selectedUnit, unit.owner == player {
            reach = Set(state.reach(of: unit).keys)
            strikeTargets = unit.kind.isMilitary ? state.strikeTargets(of: unit) : []
        } else {
            reach = []
            strikeTargets = []
        }
    }

    private func refreshPathPreview() {
        hoverForecast = nil
        if let unit = selectedUnit, unit.owner == player, let hovered {
            hoverForecast = state.forecast(unit: unit.id, at: hovered)
            if hoverForecast != nil {
                pathPreview = []
                return
            }
        }
        guard let unit = selectedUnit, unit.owner == player, let hovered, hovered != unit.position,
              state.map[hovered]?.terrain.isPassable == true
        else {
            pathPreview = []
            return
        }
        pathPreview = state.path(for: unit, to: hovered) ?? []
    }

    public func post(_ text: String, tone: Notice.Tone) {
        noticeCounter += 1
        notices.append(Notice(id: noticeCounter, text: text, tone: tone))
        // VoiceOver says what happened, as the notice appears.
        AccessibilityNotification.Announcement(text).post()
        if notices.count > 6 {
            notices.removeFirst(notices.count - 6)
        }
    }

    private func report(_ events: [GameEvent]) {
        for event in events {
            if let line = Narration.line(for: event, in: state, viewer: player) {
                post(line.text, tone: line.tone)
            }
        }
    }
}

/// Foundation also exports a `Unit` (measurement units); in this module the
/// word means a company in the field.
typealias Unit = NullmereCore.Unit
