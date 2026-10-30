import AppKit
import Foundation
import LauncherCore
import NullmereCore
import NullmereModels
import NullmereRealm
import NullmereWorld
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

    /// What a page key is for: the panel open over the map, or else the
    /// panel of the hold chosen.
    enum PageTarget: Equatable {
        case panel(Panel)
        case selection
    }

    struct PageRequest: Equatable {
        var serial = 0
        var direction = 0
        var target = PageTarget.selection
    }

    public enum Panel: Equatable {
        case houses
        case chronicle
        case guide
        /// The House's studies.
        case archive
        case commanders
        case alliance
        /// The happening, the charges, the deeds and might.
        case realm
        /// The keepers' words, to the realm and to the alliance.
        case words
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
    @ObservationIgnored private var glideTask: Task<Void, Never>?
    /// How much the world moves, as the display settings and the system
    /// say: below full motion, the camera goes to its mark at once.
    @ObservationIgnored public var motion: ResolvedMotion = .full
    @ObservationIgnored private var unannounced: [String] = []
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
    /// Page Up and Page Down, as heard: each panel that scrolls pages
    /// itself when one is meant for it.
    var pageRequest = PageRequest()
    /// A founding asked by B, which B again carries out.
    @ObservationIgnored var foundingAsked: Int?
    /// A strike asked by M, which M again carries out.
    @ObservationIgnored var strikeAsked: Hex?
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
    /// The keeper's ledger as the top bar shows it, worked out once for each
    /// change of the world rather than at every redraw.
    @ObservationIgnored private var ledgerKept: (version: Int, ledger: Ledger)?
    /// Other things the interface reads at every redraw, worked out once
    /// for each change of the world.
    @ObservationIgnored private var keptForWorld: (version: Int, values: [String: Any]) = (-1, [:])
    /// The small map's ground, drawn for one change of the world.
    @ObservationIgnored var miniGround: (version: Int, image: CGImage)?
    /// The texture's unchanging ground, made again only when the map changes.
    @ObservationIgnored private var ground: TileTexture.Ground?
    /// Where the moon lies in this lake's water, for the map drawn without Metal.
    private(set) var moon = SIMD4<Float>(0, -2.2, 1.05, 1)
    /// The lie of the land under the map, made again only when the map
    /// changes: where things stand, and the hex under the pointer.
    @ObservationIgnored public private(set) var relief: Relief {
        didSet { heartHeights = [] }
    }
    /// The height of each hex's heart, by map index, worked out when first asked.
    @ObservationIgnored var heartHeights: [Double] = []
    /// The world's models, laid out for the map in play when first drawn.
    @ObservationIgnored var stage: WorldStage?
    /// Which way each company faces: toward where it last marched or struck.
    @ObservationIgnored var headings: [Int: Float] = [:]
    /// Where each company stood before the realm's latest world was taken:
    /// where the steps heard with it set out from.
    @ObservationIgnored var beforeAdopted: [Int: Hex] = [:]
    /// Each hold's work rising, as last drawn.
    @ObservationIgnored var risings: [Int: Rising] = [:]
    /// Each alliance's hall rising, as last drawn, by its id.
    @ObservationIgnored var hallRisings: [Int: HallRising] = [:]
    /// Each company's clip as last drawn, and the one it is easing out of.
    @ObservationIgnored var clipsShown: [Int: ClipShown] = [:]
    /// Works finished lately, for the dust of their last course.
    @ObservationIgnored var completions: [Completion] = []
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
    /// The keeper as the realm last told of them: their renown and titles
    /// over the ages.
    public var keeper: Keeper?

    /// What a charge's Show me points at: the control that keeps it, ringed
    /// until the keeper next gives an order.
    public enum Beckon: Equatable {
        /// A work's Build button at the seat.
        case work(BuildingKind)
        /// The Train buttons: of the companies of war, or of a kind.
        case train(UnitKind?)
        /// The studies that may be begun.
        case study
        /// A commander's Lead them.
        case lead
        /// Founders' Found a hold.
        case found
        /// Raising a banner.
        case banner
    }

    public var beckon: Beckon?

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

        public static let secondsPerStep = 0.4

        public var duration: Double { Double(max(path.count - 1, 1)) * March.secondsPerStep }
    }

    /// Called with each sound the game makes.
    public var onCue: ((Ambience.Cue) -> Void)?
    /// Called with each sound the game makes and where it is heard from.
    public var onPlacedCue: ((Ambience.Cue, SoundPlace) -> Void)?
    /// Called with the advisor's counsel as each new charge comes.
    public var onCounsel: ((String) -> Void)?
    /// The charge last counselled: the one the keeper had as the session
    /// began, so only a new one is spoken unbidden.
    @ObservationIgnored private var counselled: Charge??
    /// Called when the player goes to war, or the last of their wars ends.
    public var onWarChanged: ((Bool) -> Void)? {
        didSet { onWarChanged?(isAtWar) }
    }
    public private(set) var isAtWar = false

    /// A commander's skill the player saw fire: a ring of gold, briefly,
    /// round the company it fired for.
    public struct Fury: Equatable, Identifiable {
        public let id: Int
        public let at: Hex
        public let skill: Skill
        public let start: Date
    }

    /// A hold scouted, by the player's Lanterns or by another's at the
    /// player's own: their light circling it, briefly.
    public struct Sighting: Equatable, Identifiable {
        public let id: Int
        public let at: Hex
        public let start: Date
    }

    /// A blow the player saw land: a ring and the damage, briefly, where it fell.
    public struct Blow: Equatable, Identifiable {
        public let id: Int
        public let at: Hex
        public let damage: Int
        /// Whether it fell on the player's side.
        public let againstPlayer: Bool
        public let start: Date
        /// Where the attacker struck from.
        public let from: Hex
        public let attacker: Int
        public let defender: Int?
        /// Companies that fell in it, drawn fading where they stood.
        public let fallen: [Fallen]

        public struct Fallen: Equatable {
            public let kind: UnitKind
            public let owner: Int
            public let at: Hex
        }

        public static let duration = 1.4
        /// How long it is kept, for the fallen to fall and fade.
        public static let lingers = 2.4

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
    /// The realm forgot this keeper's key; the app takes them to its door.
    var onForgotten: (() -> Void)?
    /// The first time in an age: the House the keeper takes up.
    private(set) var seatBriefing: SeatBriefing?
    /// A new keeper's first steps, until all are done.
    private(set) var firstSteps: FirstSteps?
    /// The last first step was saying ready: the word waits for the watch
    /// to turn, which clears what was said before it.
    private var welcomeAfterWatch = false
    /// An order sent and not yet answered: what it was, where the companies
    /// stood as it was given, and whether all that came of it is the realm's
    /// to tell, as a steward's answer is.
    private struct Awaited {
        let command: Command
        let from: [Int: Hex]
        let decided: Bool
    }
    /// The orders sent and not yet answered, in order: what came of each is
    /// told as the realm decided it, when its answer comes.
    private var answersAwaited: [Awaited] = []
    /// The Dock's count of watches turned while the keeper was elsewhere.
    private(set) var attention = Attention()
    /// Whether the keeper is looking, and how the Dock is told; tests
    /// supply their own.
    var isLooking: () -> Bool = { NSApplication.shared.isActive }
    /// Whether VoiceOver, or Switch Control, is running. Only then are each
    /// company's orders worked out as actions on the map (the way to the
    /// unknown, the odds of each strike): some milliseconds at every change
    /// of the world, for no one without them. Tests say yes.
    @ObservationIgnored var voiceOverRunning: () -> Bool = {
        NSWorkspace.shared.isVoiceOverEnabled || NSWorkspace.shared.isSwitchControlEnabled
    }
    var signal: (Attention.Signal) -> Void = { Attention.show($0) }
    private var watchCardCounter = 0
    /// Keeps the watch's card on screen, for photographs.
    var keepsWatchCard = false

    /// Blows still being drawn.
    public private(set) var blows: [Blow] = []
    /// Commanders' skills fired in sight, while their gold is drawn.
    public private(set) var furies: [Fury] = []
    /// Holds scouted in sight, while their Lanterns' light is drawn.
    public private(set) var sightings: [Sighting] = []
    /// What the House's Lanterns last saw of each hold they scouted, by hold.
    public private(set) var scoutings: [Int: ScoutReport] = [:]
    /// The House's battles and hunts as their reports tell them, the latest first.
    public private(set) var reports: [BattleReport] = []
    @ObservationIgnored private var reportCounter = 0
    /// The most reports kept.
    static let reportsKept = 40
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
    /// Words still to be asked for or spoken: for tests to wait on.
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
        self.relief = Relief(map: world.map)
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
        // Back to the House last seen: what changed while away. A House new
        // to the keeper (a new age, a seat that lapsed, a free House taken
        // up): its briefing, and the first steps if never yet taken.
        if let seen = store.loadLastSeen(), seen.house == nil || seen.house == house {
            awayReport = AwayReport(since: seen, now: world, player: house)
        } else if world.houses.indices.contains(house) {
            seatBriefing = SeatBriefing(world: world, player: house)
            if store.loadFirstSteps() == nil { store.saveFirstSteps(FirstSteps()) }
        }
        firstSteps = store.loadFirstSteps().flatMap { $0.isComplete ? nil : $0 }
        noteStepsInWorld()
        rememberSeen()
        link.onEvent = { [weak self] event in self?.hear(event) }
        link.connect()
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
        defer { if selection != Selection.none { emit(.select) } }
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
        // A company of war sent to a site of the land works it, and brings
        // what it gathers home.
        if unit.kind.isMilitary, let site = state.site(at: hex), state.wild(at: hex) == nil,
           state.gatherRefusal(unit.id, at: site.id, as: player) == nil {
            perform(.gather(unit: unit.id, site: site.id))
            return
        }
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
            let decided = Self.decidedByRealm(command, in: state)
            let events = try state.perform(command, as: player)
            answersAwaited.append(Awaited(command: command, from: before, decided: decided))
            link.send(command)
            // An order given: what Show me pointed at has done its work.
            beckon = nil
            if var steps = firstSteps, steps.note(command) { advance(steps) }
            showMarches(events, from: before)
            // What chance decides, or what turns on what this copy can't
            // see (a strike's blows, a ruin's spoils, a new hold's name, a
            // steward's answer), is told as the realm decided it, when it
            // answers: this copy's guess is never told as what happened.
            let sure = decided ? [] : events.filter { !Self.isRealmsToTell($0) }
            report(sure)
            // A strike sounds as its blow lands, with the realm's answer.
            if !Self.isStrike(command) { sound(for: command, events: sure) }
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
        if var steps = firstSteps, steps.mark(.ready) { advance(steps, waitingForWatch: true) }
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
        // What is newly waiting, not what the keeper left waiting when they
        // chose to stay ready: a company come to the end of its march or
        // newly mustered; a hold whose work is done, or which can now pay
        // for one it couldn't. A hold saving up is no call.
        func awaits(_ unit: NullmereCore.Unit) -> Bool { unit.movesLeft > 0 && unit.destination == nil && !unit.fortified }
        let waitingBefore = Set(before.units(of: player).filter(awaits).map(\.id))
        if after.units(of: player).contains(where: { awaits($0) && !waitingBefore.contains($0.id) }) { return true }
        let holdsBefore = Dictionary(before.holds(of: player).map { ($0.id, $0) }, uniquingKeysWith: { first, _ in first })
        return after.holds(of: player).contains { hold in
            guard hold.project == nil, couldBuild(hold, in: after) else { return false }
            guard let was = holdsBefore[hold.id], was.project == nil else { return true }
            return !couldBuild(was, in: before)
        }
    }

    /// Whether a hold could begin some work with its House's stores.
    static func couldBuild(_ hold: Hold, in state: GameState) -> Bool {
        guard state.houses.indices.contains(hold.owner) else { return false }
        let stock = state.houses[hold.owner].stock
        return BuildingKind.allCases.contains { kind in
            let next = hold.level(kind) + 1
            return next <= kind.maxLevel && (!kind.requiresSeat || hold.isSeat) && stock.covers(kind.cost(toLevel: next))
        }
    }

    // MARK: While away

    /// Keeps what the keeper has now seen of their House, for the report
    /// when they return.
    private func rememberSeen() {
        guard state.houses.indices.contains(player) else { return }
        store.saveLastSeen(LastSeen(watch: state.watch, stock: state.houses[player].stock, holds: state.holds(of: player).count, house: player))
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

    /// Orders whose outcome the keeper's copy can't know, not seeing the
    /// others' stores and companies: an offer to a steward, and taking an
    /// offer of trade.
    static func decidedByRealm(_ command: Command, in state: GameState) -> Bool {
        switch command {
        case .propose(_, let to), .proposeWithWords(_, let to, _), .offerTrade(_, let to, _), .inviteToAlliance(let to):
            return state.house(to).map { !$0.isPlayer } ?? false
        case .askToJoin(let id):
            // A steward leading the alliance answers at once.
            return state.alliance(id).map { !state.houses[$0.leader].isPlayer } ?? false
        case .answer(let id, _):
            return state.envoys.first { $0.id == id }?.proposal == .trade
        default:
            return false
        }
    }

    /// What came of an order that the keeper's copy can only guess at: what
    /// chance decides (a blow, its losses, a company's rise, a ruin's spoils,
    /// a new hold's name), what follows from it (a hold taken, a House
    /// fallen, an age won, the fallen carried to an Infirmary or lost with
    /// it), what turns on what the copy can't see (what Lanterns saw of a
    /// hold), and an answer. Told when the realm answers.
    static func isRealmsToTell(_ event: GameEvent) -> Bool {
        switch event {
        case .battle, .unitLost, .holdStruck, .holdCaptured, .seatMoved, .promoted, .ruinSearched, .holdFounded,
             .houseFell, .gameEnded, .proposalAnswered, .tradeAnswered, .commanderRose, .commanderWounded, .skillFired, .hunted,
             .gearFound, .carriedToInfirmary, .woundedLost, .holdScouted, .scoutSeen, .lairAssaulted, .standardStruck, .standardTorn,
             .hallStruck, .hallTorn, .storehouseStruck, .storehouseTorn:
            return true
        default:
            return false
        }
    }

    static func isStrike(_ command: Command) -> Bool {
        if case .attack = command { return true }
        return false
    }

    /// An offer of trade, with words when it goes to a keeper.
    public func offerTrade(_ trade: Trade, to house: House, words: String) {
        perform(.offerTrade(trade, to: house.id, words: house.isPlayer ? Envoy.carried(words) : nil))
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

    /// A first step done: kept, and when the last is, said and put away.
    private func advance(_ steps: FirstSteps, waitingForWatch: Bool = false) {
        store.saveFirstSteps(steps)
        if steps.isComplete {
            withAnimation(.easeOut(duration: 0.3)) { firstSteps = nil }
            if waitingForWatch {
                welcomeAfterWatch = true
            } else {
                post(Self.welcome, tone: .good)
            }
        } else {
            firstSteps = steps
        }
    }

    /// Ticks the first steps the world already shows taken.
    private func noteStepsInWorld() {
        if var steps = firstSteps, steps.note(world: state, player: player) { advance(steps) }
    }

    static let welcome = "Well begun. The rest is yours; the Guide (?) holds more."

    public func dismissFirstSteps() {
        guard var steps = firstSteps else { return }
        for step in FirstSteps.Step.allCases { steps.mark(step) }
        store.saveFirstSteps(steps)
        withAnimation(.easeOut(duration: 0.3)) { firstSteps = nil }
    }

    public func dismissSeatBriefing() {
        withAnimation(.easeOut(duration: 0.3)) { seatBriefing = nil }
        // Into the world: the charge the keeper begins with, counselled.
        if let charge = state.charge(of: player) {
            counselled = .some(charge)
            onCounsel?(ChargeGuide.counsel(charge))
        }
    }

    /// A new charge come: its counsel, spoken.
    private func counselNewCharge() {
        let charge = state.charge(of: player)
        guard let before = counselled else {
            counselled = .some(charge)
            return
        }
        guard charge != before else { return }
        counselled = .some(charge)
        if let charge { onCounsel?(ChargeGuide.counsel(charge)) }
    }

    /// A card stands before the world, as the keeper enters: their seat's
    /// briefing, or what passed while they were away.
    public var isShowingCard: Bool {
        state.outcome == nil && (seatBriefing != nil || awayReport != nil)
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
                post(reason == NetworkRealmLink.silentSteward ? reason
                     : "The realm is out of reach. \(reason) Orders given now wait for it; any that haven't reached it in five minutes are let go.", tone: .bad)
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
        case .heard(let events):
            // Others' doings, told as they happen, a blow seen as struck,
            // and companies on the march walking on through the watch, from
            // where they stood before the world that came with them.
            report(events)
            showMarches(events, from: beforeAdopted)
            showBlows(events, from: beforeAdopted)
            // A step on the march is seen, not sounded: the order sounded once.
            let sounded = events.filter { if case .moved = $0 { return false } else { return true } }
            for (cue, at) in Self.placedCues(for: sounded, in: state, player: player) where cue != .watch {
                emit(cue, at: at)
            }
        case .answered(let events):
            // What came of the keeper's order, as the realm decided it.
            guard !answersAwaited.isEmpty else { break }
            let awaited = answersAwaited.removeFirst()
            let told = awaited.decided ? events : events.filter(Self.isRealmsToTell)
            showBlows(told, from: awaited.from)
            report(told)
            let struck = Self.target(of: awaited.command)
            var cues = Self.isStrike(awaited.command)
                ? Self.cues(for: awaited.command, events: told, in: state, player: player).map { (cue: $0, at: struck) } : []
            if awaited.decided {
                for (cue, at) in Self.placedCues(for: told, in: state, player: player) where cue != .watch && !cues.contains(where: { $0.cue == cue }) {
                    cues.append((cue, at))
                }
            }
            for (cue, at) in cues {
                emit(cue, at: at)
            }
        case .orderRefused(let error, let world):
            if !answersAwaited.isEmpty { answersAwaited.removeFirst() }
            adopt(world)
            post(error.description, tone: .bad)
        case .watchTurned(let world, let events):
            watchTurned(to: world, events: events)
        case .readiness(let ready):
            // The realm's word on readiness stands: lost while away, it is
            // shown lost, and said so.
            guard ready != isReady else { break }
            isReady = ready
            if !ready { post("The realm lost your readiness while you were away: say ready again when you are.", tone: .neutral) }
        case .unreachable:
            break
        case .arrived(let keeper, let world):
            // A keeper already in the world is seated anew: in a new age, or
            // in a free House taken up after their own fell.
            onNewAge?(keeper, world)
        case .refused(.unknownKeeper):
            // The realm has forgotten this keeper altogether.
            onForgotten?()
        case .refused(let error):
            // In the world, only a free House asked for can be refused.
            post(error.description, tone: .bad)
        }
    }

    /// Takes the realm's world as it is, where it differs from ours.
    private func adopt(_ world: GameState) {
        guard world != state else { return }
        beforeAdopted = positions()
        state = world
        if case .unit(let id) = selection, state.unit(id) == nil { selection = .none }
        if case .hold(let id) = selection, state.hold(id) == nil { selection = .none }
        refreshWorld()
    }

    /// The watch turned in the realm: show what it brought.
    private func watchTurned(to world: GameState, events: [GameEvent]) {
        let previous = state
        let before = positions()
        // Many watches at once (the Mac asleep, the line down a while): what
        // happened while the keeper was away, as on coming back.
        if world.watch - previous.watch > 1, previous.houses.indices.contains(player) {
            let seen = LastSeen(watch: previous.watch, stock: previous.houses[player].stock, holds: previous.holds(of: player).count, house: player)
            awayReport = AwayReport(since: seen, now: world, player: player)
        }
        state = world
        rememberSeen()
        isReady = false
        guard !isAutoplaying else { return }
        isEndingWatch = true
        quietPassed += 1
        showWatchCard(WatchSummary(before: previous, after: state, events: events, player: player))
        showMarches(events, from: before)
        showBlows(events, from: before)
        for (cue, at) in Self.placedCues(for: events, in: state, player: player) {
            emit(cue, at: at)
        }
        notices.removeAll()
        report(events)
        if welcomeAfterWatch {
            welcomeAfterWatch = false
            post(Self.welcome, tone: .good)
        }
        var warnings = Race.warnings(before: previous, after: state, player: player)
        let threats = Sentinel.threats(in: state, player: player, visible: state.visibility(for: player))
        warnings += threats.filter { !threatened.contains($0.hold) }.map { Sentinel.line(for: $0, in: state) }
        for warning in warnings {
            post(warning.text, tone: warning.tone)
        }
        if warnings.contains(where: { $0.tone == .bad }), !Self.cues(for: events, in: state, player: player).contains(.dread) {
            emit(.dread)
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
        glide(to: next.position)
    }

    /// The age in which the keeper took up an open seat after their own
    /// House fell, as the realm last said: once an age.
    public var risenInAge: Int?

    /// The keeper's House has fallen while the age goes on, a House stands
    /// without a keeper, and they haven't taken up one already this age:
    /// they may take it up.
    public var mayTakeUpAFreeHouse: Bool {
        playerHouse.isEliminated && state.outcome == nil && (realmStatus?.freeSeats ?? 0) > 0 && risenInAge != realmStatus?.age
    }

    /// Asks the realm for a free House; it comes as a new arrival.
    public func takeUpAFreeHouse() {
        guard mayTakeUpAFreeHouse else { return }
        link.arrive(name: nil)
    }

    public func focusOnSeat() {
        guard let seat = state.seat(of: player) else { return }
        selection = .hold(seat.id)
        glide(to: seat.position)
    }

    /// Chooses the keeper's next company, or the one before, whatever it is
    /// doing: marching, fortified or spent, as well as awaiting orders, so
    /// none is ever out of the keyboard's reach.
    public func selectNextUnit(forward: Bool = true) {
        let mine = state.units(of: player).sorted { $0.id < $1.id }
        guard let first = mine.first, let last = mine.last else {
            post("You have no companies.", tone: .neutral)
            return
        }
        let next: NullmereCore.Unit
        if let current = selectedUnit, current.owner == player {
            next = forward ? (mine.first { $0.id > current.id } ?? first) : (mine.last { $0.id < current.id } ?? last)
        } else {
            next = forward ? first : last
        }
        selection = .unit(next.id)
        glide(to: next.position)
        sayChosen()
    }

    /// Chooses the keeper's holds in turn, the seat first: pressed again
    /// and again, it goes round them all.
    public func selectNextHold() {
        let holds = state.holds(of: player).sorted { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }
        guard let first = holds.first else { return }
        let next = holds.firstIndex { selection == .hold($0.id) }.map { holds[($0 + 1) % holds.count] } ?? first
        selection = .hold(next.id)
        glide(to: next.position)
        sayChosen()
    }

    /// Chooses what VoiceOver chose on the map, and brings the view to it,
    /// so the keys that act where the view is centred start from there.
    func choose(_ item: MapAccessibility.Item) {
        selection = item.selection
        glide(to: item.hex)
    }

    /// What is chosen, said to VoiceOver as the map reads it, for the keys
    /// that choose where VoiceOver's cursor isn't.
    func sayChosen() {
        guard voiceOverRunning() else { return }
        switch selection {
        case .none:
            return
        case .tile(let hex):
            if let ground = HoverInfo.line(for: hex, in: state, explored: isExplored(hex), territory: territory) {
                sayNow("Chosen: \(ground.replacingOccurrences(of: " · ", with: ", ")).")
            }
        case .unit, .hold:
            if let item = mapItems.first(where: { $0.selection == selection }) { sayNow("Chosen: \(item.label).") }
        }
    }

    /// An order given by a key, said to VoiceOver once it is carried out,
    /// as an order from VoiceOver's own actions is.
    func sayDone(_ what: String) {
        guard voiceOverRunning() else { return }
        sayNow("Done: \(what).")
    }

    /// Carries the camera to a hex over a moment, eased in and out; at once
    /// below full motion. The camera reaches the map as a plain value, so
    /// it is moved step by step here rather than by SwiftUI. A pan or a
    /// zoom by the keeper meanwhile has the last word.
    func glide(to hex: Hex, reducesMotion: Bool? = nil) {
        glideTask?.cancel()
        var target = camera
        target.focus(on: hex)
        guard !(reducesMotion ?? (motion != .full)) else {
            camera = target
            return
        }
        let start = camera
        glideTask = Task { [weak self] in
            let steps = 20
            var placed = start
            for step in 1...steps {
                try? await Task.sleep(nanoseconds: 17_000_000)
                guard let self, !Task.isCancelled, self.camera == placed else { return }
                if step == steps {
                    placed = target
                } else {
                    let t = Double(step) / Double(steps)
                    let eased = t * t * (3 - 2 * t)
                    placed.centerX = start.centerX + (target.centerX - start.centerX) * eased
                    placed.centerY = start.centerY + (target.centerY - start.centerY) * eased
                }
                self.camera = placed
            }
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
        // The steward took the first steps for the keeper.
        if firstSteps != nil { dismissFirstSteps() }
        notices.removeAll()
        selection = .none
        refreshWorld()
        if let seat = state.seat(of: player) {
            camera.focus(on: seat.position)
        }
    }

    // MARK: Bookkeeping

    private func refreshWorld() {
        counselNewCharge()
        visible = state.visibility(for: player)
        threatened = Set(Sentinel.threats(in: state, player: player, visible: visible).map(\.hold))
        territory = state.territory()
        refreshReach()
        let atWar = state.livingHouses.contains { state.isAtWar(player, $0.id) }
        if atWar != isAtWar {
            isAtWar = atWar
            onWarChanged?(atWar)
        }
        if ground?.map != state.map {
            ground = TileTexture.Ground(map: state.map)
            moon = MoonMirror.place(for: state)
            relief = Relief(map: state.map)
            stage = nil
            headings = [:]
            risings = [:]
            hallRisings = [:]
            clipsShown = [:]
            completions = []
        }
        tileBytes = TileTexture.bytes(for: state, viewer: player, visible: visible, owners: territory, ground: ground)
        tilesVersion += 1
        refreshPathPreview()
        askVoices()
        noteStepsInWorld()
    }

    // MARK: Sound

    private func sound(for command: Command, events: [GameEvent]) {
        for cue in Self.cues(for: command, events: events, in: state, player: player) {
            emit(cue, at: Self.target(of: command))
        }
    }

    /// Where an order sends a company: its march's end, or what it strikes.
    static func target(of command: Command) -> Hex? {
        switch command {
        case .move(_, let to): return to
        case .attack(_, let target): return target
        default: return nil
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
            // A drowned ruin searched on the way rises, after the march.
            let ruin = events.contains { if case .ruinSearched(_, let by, _) = $0 { return by == player } else { return false } }
            return [state.unit(unit)?.kind == .rider ? .ride : .order] + (ruin ? [.rise] : [])
        default:
            return [plainCue(for: command, events: events, player: player)]
        }
    }

    private static func plainCue(for command: Command, events: [GameEvent], player: Int) -> Ambience.Cue {
        // Whatever the order, one that begins a war sounds as war: refusing
        // a steward's tribute, too.
        let war = events.contains { event in
            guard case .stanceChanged(let first, let second, .war, _) = event else { return false }
            return first == player || second == player
        }
        if war { return .dread }
        switch command {
        case .found, .build, .train: return .rise
        case .declareWar: return .dread
        case .answer(_, true) where events.contains(where: { if case .proposalAnswered(_, _, _, true) = $0 { return true } else { return false } }):
            return .accord
        case .answer(_, false): return .refusal
        case .fortify: return .dig
        case .barter, .gift, .offerTrade: return .coin
        case .propose, .proposeWithWords: return .parley
        case .halt, .disband: return .stand
        case .study, .help: return .rise
        case .assign, .gather, .joinRally, .reinforce: return .order
        case .unassign, .leaveAlliance: return .stand
        case .foundAlliance: return .banner
        case .inviteToAlliance, .askToJoin: return .envoy
        case .answerInvitation(_, let accept), .answerRequest(_, let accept): return accept ? .banner : .refusal
        case .expel: return .refusal
        case .callRally: return .horn
        case .say: return .parley
        case .learnTalent: return .lore
        case .forgetTalents: return .stand
        case .wear: return .order
        case .takeOff: return .stand
        case .breakUp: return .coin
        case .heal: return .tend
        case .scout: return .ride
        case .raiseStandard: return .banner
        case .useItem(let kind, _): return cue(using: kind)
        case .takeHeritage: return .banner
        case .pursueAllianceStudy: return .lore
        case .giveToAlliance: return .coin
        case .raiseAllianceHall, .raiseStorehouse, .raiseYard: return .rise
        case .forge: return .anvil
        case .layUp, .takeBack: return .coin
        default: return .select
        }
    }

    /// The sound of an item used: salt running for an hourglass, coins for
    /// a cache, a work finished for a ward made whole, the healers for a
    /// draught.
    static func cue(using kind: ItemKind) -> Ambience.Cue {
        switch kind {
        case .hourglass: return .sift
        case .grainCache, .timberCache, .stoneCache, .moonsaltCache: return .coin
        case .wardStone: return .complete
        case .mendingDraught: return .tend
        }
    }

    /// The sound of what the realm's depth brings the keeper: studies,
    /// commanders, the wilds, gathering, alliances, rallies, happenings,
    /// deeds and charges; nil for what doesn't concern them. An alliance
    /// ends only as its last House leaves it, and that leaving is heard.
    static func cue(forDepth event: GameEvent, in state: GameState?, player: Int) -> Ambience.Cue? {
        let alliance = state?.alliance(of: player)?.id
        func ours(_ unit: Int) -> Bool { state?.unit(unit)?.owner == player }
        func allied(_ house: Int) -> Bool { house == player || state?.areAllied(player, house) == true }
        switch event {
        case .studyBegun(let house, _, _) where house == player: return .rise
        case .studyCompleted(let house, _, _) where house == player: return .lore
        case .commanderJoined(_, let house) where house == player: return .honour
        case .commanderRose(_, let house, _) where house == player: return .honour
        case .commanderWounded(_, let house) where house == player: return .dread
        case .commanderAssigned(_, let unit) where ours(unit): return .order
        case .commanderReleased(let commander) where state?.commander(commander)?.owner == player: return .stand
        case .skillFired(_, let house, _, _) where house == player: return .horn
        case .talentLearned(_, let house, _, _) where house == player: return .lore
        case .talentsForgotten(_, let house) where house == player: return .stand
        case .gearFound(let house, _, _) where house == player: return .honour
        case .gearWorn(_, let house, _) where house == player: return .order
        case .gearTakenOff(_, let house, _) where house == player: return .stand
        case .gearScrapped(let house, _, _) where house == player: return .coin
        case .shrineTaken(_, let house, _) where allied(house): return .banner
        case .shrineTaken(_, _, let from) where from == player: return .dread
        case .carriedToInfirmary(_, let owner, _) where owner == player: return .tend
        case .healingBegun(_, let house, _) where house == player: return .tend
        case .unitHealed(let unit, _) where ours(unit): return .muster
        case .woundedLost(_, let house, _) where house == player: return .dread
        case .holdScouted(let report) where report.by == player: return .lore
        case .itemsGiven(let house, _, _) where house == player: return .coin
        case .heritageTaken(let house, _) where house == player: return .banner
        case .allianceStudied(let id, _, _) where state?.alliance(of: player)?.id == id: return .lore
        case .allianceGift(let house, _, _, _, _) where house == player: return .coin
        case .allianceStudyChosen(let id, _) where state?.alliance(of: player)?.id == id: return .banner
        case .itemUsed(let house, let kind, _) where house == player: return cue(using: kind)
        case .lairAssaulted(let assault) where assault.houses.contains(player): return assault.broken ? .triumph : .batter
        case .standardRaised(_, let alliance, _, _) where state?.alliance(of: player)?.id == alliance: return .banner
        case .standardStruck(let standard, _, let by, _) where by != player
            && state?.standard(standard).map({ $0.alliance == state?.alliance(of: player)?.id }) == true: return .batter
        case .standardTorn(_, _, let by, _) where by == player: return .triumph
        case .standardTorn(_, let alliance, _, _) where state?.alliance(of: player)?.id == alliance: return .dread
        case .hallRaised(_, let id, _, _) where alliance == id: return .rise
        case .hallRisen(_, let id, _) where alliance == id: return .complete
        case .hallStruck(_, let id, _, let by, _) where by != player && alliance == id: return .batter
        case .hallTorn(_, _, let by, _) where by == player: return .triumph
        case .hallTorn(_, let id, _, _) where alliance == id: return .dread
        case .storehouseRaised(_, let id, _, _) where alliance == id: return .rise
        case .storehouseRisen(_, let id, _) where alliance == id: return .complete
        case .storehouseStruck(_, let id, _, let by, _) where by != player && alliance == id: return .batter
        case .storehouseTorn(_, _, let by, _, _) where by == player: return .triumph
        case .storehouseTorn(_, let id, _, _, _) where alliance == id: return .dread
        case .laidUp(let house, _) where house == player: return .coin
        case .tookBack(let house, _) where house == player: return .coin
        case .yardRaised(_, let id, _, _, _) where alliance == id: return .rise
        case .favourRose(let house, _) where house == player: return .honour
        case .gearForged(let house, _) where house == player: return .anvil
        case .scoutSeen(let hold, _) where state?.hold(hold)?.owner == player: return .envoy
        case .hunted(let hunt) where hunt.attackerOwner == player: return hunt.attackerKind == .bow ? .loose : .clash
        case .sentToGather(let unit, _) where ours(unit): return .order
        case .gathered(_, let owner, _) where owner == player: return .dig
        case .delivered(_, let owner, _, _) where owner == player: return .coin
        case .siteWorkedOut(_, _, let at) where state?.unit(at: at)?.owner == player: return .stand
        case .allianceFounded(_, let house) where house == player: return .banner
        case .allianceInvited(_, let house) where house == player: return .envoy
        case .allianceAsked(let asked, _) where asked == alliance && state?.alliance(asked)?.leader == player: return .envoy
        case .allianceAnswered(let answered, let house, let accepted) where house == player || answered == alliance:
            return accepted ? .banner : .refusal
        case .allianceJoined(let joined, let house) where house == player || joined == alliance: return .banner
        case .allianceLeft(_, let house, let expelled) where house == player: return expelled ? .dread : .stand
        case .allianceLed(_, let house) where house == player: return .banner
        case .helpGiven(_, let to, _) where to == player: return .accord
        case .helpGiven(let by, _, _) where by == player: return .rise
        case .rallyCalled(_, let caller, _) where allied(caller): return .horn
        case .rallyJoined(_, _, let house) where house == player: return .order
        case .rallySetOut(_, let caller, _, let defender, _) where allied(caller) || defender == player:
            return defender == player ? .dread : .horn
        case .rallyStruck(_, _, _, let defender, let taken) where defender == player: return taken ? .dread : .batter
        case .rallyStruck(_, let caller, _, _, let taken) where allied(caller): return taken ? .triumph : .clash
        case .rallyDispersed(_, let caller) where caller == player: return .stand
        case .sentToReinforce(_, let owner, _) where owner == player: return .order
        case .happeningBegun: return .herald
        case .happeningMark(let house, _, _, _) where house == player: return .honour
        case .happeningEnded(_, let leaders): return leaders.contains(player) ? .triumph : .herald
        case .sunderingBegun: return .herald
        case .sunderingEnded(let winner, _, _, _): return winner != nil && state?.sundering?.shore(of: player) == winner ? .triumph : .herald
        case .deedDone(let house, _) where house == player: return .honour
        case .chargeDone(let house, _, _) where house == player: return .honour
        case .said(let word) where word.from != player: return .parley
        default: return nil
        }
    }

    /// The sounds a watch's turning makes for the player, the watch's bell
    /// first and each other sound once. With the world as it now stands,
    /// the player's works and companies finished sound too.
    static func cues(for events: [GameEvent], in state: GameState? = nil, player: Int) -> [Ambience.Cue] {
        placedCues(for: events, in: state, player: player).map(\.cue)
    }

    /// The sounds events make, each where in the world the first event to
    /// make it happened, if it happened anywhere: the watch's bell first,
    /// in the middle, and each other sound once.
    static func placedCues(for events: [GameEvent], in state: GameState? = nil, player: Int) -> [(cue: Ambience.Cue, at: Hex?)] {
        var cues: [(cue: Ambience.Cue, at: Hex?)] = [(.watch, nil)]
        var here: Hex?
        func add(_ cue: Ambience.Cue) { if !cues.contains(where: { $0.cue == cue }) { cues.append((cue, here)) } }
        for event in events {
            here = state.flatMap { place(of: event, in: $0) }
            switch event {
            case .battle(let battle) where battle.defenderOwner == player:
                // Struck: steel, or arrows, as the blow came.
                add(battle.attackerKind == .bow ? .loose : .clash)
            case .holdStruck(let hold, _) where state?.hold(hold)?.owner == player:
                add(.batter)
            case .unitLost(_, _, let owner, _) where owner == player:
                add(.dread)
            case .starving(let house) where house == player:
                add(.dread)
            case .buildingCompleted(let hold, _, _) where state?.hold(hold)?.owner == player:
                add(.complete)
            case .buildingStarted(let hold, _, _) where state?.hold(hold)?.owner == player:
                add(.rise)
            case .trainingStarted(let hold, _) where state?.hold(hold)?.owner == player:
                add(.rise)
            case .holdFounded(let hold) where state?.hold(hold)?.owner == player:
                add(.rise)
            case .unitTrained(let unit, _) where state?.unit(unit)?.owner == player:
                add(.muster)
            case .moved(let unit, _) where state?.unit(unit)?.owner == player:
                // A march carried on into the new watch.
                add(.order)
            case .ruinSearched(_, let by, _) where by == player:
                // As when found on the march ordered.
                add(.rise)
            case .bartered(let house, _, _) where house == player:
                add(.coin)
            case .houseFell: add(.toll)
            case .gameEnded(let outcome): add(outcome.winner == player ? .triumph : .toll)
            case .holdCaptured(_, let from, let by):
                if by == player { add(.triumph) } else if from == player { add(.dread) }
            case .stanceChanged(let first, let second, let stance, let by) where (first == player || second == player) && by != player:
                add(stance == .war ? .dread : .accord)
            case .proposalAnswered(_, let from, let to, true) where from == player || to == player:
                add(.accord)
            case .proposalAnswered(_, let from, _, false) where from == player:
                add(.refusal)
            case .tradeAnswered(_, let from, let to, true) where from == player || to == player:
                add(.accord)
            case .tradeAnswered(_, let from, _, false) where from == player:
                add(.refusal)
            case .envoyArrived:
                add(.envoy)
            case .gifted(_, let to, _) where to == player:
                add(.accord)
            case .promoted(_, let owner, _) where owner == player:
                add(.rise)
            case .seatMoved(let house, _) where house == player:
                add(.dread)
            default:
                if let cue = Self.cue(forDepth: event, in: state, player: player) { add(cue) }
            }
        }
        return cues
    }

    /// Where in the world an event happened, if it happened anywhere one
    /// place: a battle where it was fought, a work at its hold, a company
    /// where it fell or ended its march.
    static func place(of event: GameEvent, in state: GameState) -> Hex? {
        switch event {
        case .battle(let battle): return battle.at
        case .hunted(let hunt): return hunt.at
        case .unitLost(_, _, _, let at), .ruinSearched(let at, _, _), .skillFired(_, _, _, let at), .siteWorkedOut(_, _, let at):
            return at
        case .moved(_, let path): return path.last
        case .holdStruck(let hold, _), .holdCaptured(let hold, _, _), .buildingCompleted(let hold, _, _), .buildingStarted(let hold, _, _),
             .trainingStarted(let hold, _), .holdFounded(let hold), .unitTrained(_, let hold), .delivered(_, _, let hold, _),
             .carriedToInfirmary(_, _, let hold), .healingBegun(let hold, _, _), .unitHealed(_, let hold), .woundedLost(let hold, _, _),
             .scoutSeen(let hold, _):
            return state.hold(hold)?.position
        case .holdScouted(let report):
            return state.hold(report.hold)?.position
        case .lairAssaulted(let assault):
            return assault.at
        case .standardRaised(_, _, _, let at), .standardStruck(_, _, _, let at), .standardTorn(_, _, _, let at):
            return at
        case .hallRaised(_, _, _, let at), .hallRisen(_, _, let at), .hallStruck(_, _, _, _, let at), .hallTorn(_, _, _, let at):
            return at
        case .storehouseRaised(_, _, _, let at), .storehouseRisen(_, _, let at), .storehouseStruck(_, _, _, _, let at),
             .storehouseTorn(_, _, _, let at, _), .yardRaised(_, _, _, _, let at):
            return at
        case .itemUsed(_, _, let hold):
            return hold.flatMap { state.hold($0)?.position }
        case .rallyStruck(_, _, let target, _, _), .rallySetOut(_, _, let target, _, _):
            return state.hold(target)?.position ?? state.lair(target)?.position
        case .shrineTaken(let shrine, _, _):
            return state.holySites.first { $0.id == shrine }?.position
        case .gathered(let unit, _, _), .sentToGather(let unit, _):
            return state.unit(unit)?.position
        default:
            return nil
        }
    }

    /// Where a sound at a hex is heard from, as the view now stands; the
    /// middle of the view for a sound of no place.
    func soundPlace(of hex: Hex?) -> SoundPlace {
        guard let hex else { return .middle }
        let heard = camera.hearing(of: hex)
        return SoundPlace(pan: heard.pan, gain: heard.gain)
    }

    /// Sounds a cue, from where in the world it happened.
    private func emit(_ cue: Ambience.Cue, at hex: Hex? = nil) {
        onCue?(cue)
        onPlacedCue?(cue, soundPlace(of: hex))
    }


    /// Whether the player may demand tribute of a House now: as the rules
    /// allow (at peace, neither sworn to the other, no demand paid or
    /// refused between them lately), and the player clearly the stronger,
    /// as a rival would need to be.
    public func canDemandTribute(from house: Int) -> Bool {
        state.mayDemandTribute(by: player, of: house)
            && state.strength(of: player) * 100 > state.strength(of: house) * 125
    }

    // MARK: The watch's card

    static let watchCardDuration = 2.6

    private func showWatchCard(_ summary: WatchSummary) {
        guard state.outcome == nil else { return }
        // Said first, with the notices the watch brings, in one
        // announcement, so neither cuts the other off.
        announce(summary.spoken)
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
        fileReports(events)
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
            // Each turns to face the other.
            if from != battle.at {
                headings[battle.attacker] = CompanyPose.heading(from: from, to: battle.at)
                if let defender = battle.defender { headings[defender] = CompanyPose.heading(from: battle.at, to: from) }
            }
            shown = true
        }
        // A host's blows on a lair, each from where it struck.
        for case .lairAssaulted(let assault) in events where assault.houses.contains(player) || isVisible(assault.at) {
            for strike in assault.strikes {
                blowCounter += 1
                let fallen = strike.fell ? [Blow.Fallen(kind: strike.kind, owner: strike.owner, at: strike.from)] : []
                blows.append(Blow(id: blowCounter, at: assault.at, damage: strike.dealt, againstPlayer: false, start: now,
                                  from: strike.from, attacker: strike.unit, defender: nil, fallen: fallen))
                if strike.from != assault.at { headings[strike.unit] = CompanyPose.heading(from: strike.from, to: assault.at) }
            }
            shown = true
        }
        for case .skillFired(_, let house, let skill, let at) in events where house == player || isVisible(at) {
            blowCounter += 1
            furies.append(Fury(id: blowCounter, at: at, skill: skill, start: now))
            shown = true
        }
        for event in events {
            let scouted: Int?
            switch event {
            case .holdScouted(let report) where report.by == player: scouted = report.hold
            case .scoutSeen(let hold, _) where state.hold(hold)?.owner == player: scouted = hold
            default: scouted = nil
            }
            guard let at = scouted.flatMap({ state.hold($0)?.position }) else { continue }
            blowCounter += 1
            sightings.append(Sighting(id: blowCounter, at: at, start: now))
            shown = true
        }
        guard shown else { return }
        Task { [weak self] in
            try? await Task.sleep(for: .seconds(Blow.lingers + 0.05))
            guard let self else { return }
            self.blows.removeAll { Date().timeIntervalSince($0.start) >= Blow.lingers }
            self.furies.removeAll { Date().timeIntervalSince($0.start) >= Blow.lingers }
            self.sightings.removeAll { Date().timeIntervalSince($0.start) >= Blow.lingers }
        }
    }

    /// Files a report of each battle and hunt the House had a part in, and
    /// of each hold its Lanterns scouted.
    func fileReports(_ events: [GameEvent]) {
        var filed: [BattleReport] = []
        for event in events {
            let report: BattleReport?
            switch event {
            case .battle(let battle): report = state.report(of: battle, id: reportCounter + 1, for: player)
            case .hunted(let hunt): report = state.report(of: hunt, id: reportCounter + 1, for: player)
            case .holdScouted(let scouting):
                report = state.report(of: scouting, id: reportCounter + 1, for: player)
                if scouting.by == player { scoutings[scouting.hold] = scouting }
            case .lairAssaulted(let assault): report = state.report(of: assault, id: reportCounter + 1, for: player)
            default: report = nil
            }
            guard let report else { continue }
            reportCounter += 1
            filed.append(report)
        }
        guard !filed.isEmpty else { return }
        reports = Array((filed.reversed() + reports).prefix(Self.reportsKept))
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
            if let last = march.path.last, march.path.count > 1 {
                headings[id] = CompanyPose.heading(from: march.path[march.path.count - 2], to: last)
            }
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
        announce(text)
        if notices.count > 6 {
            notices.removeFirst(notices.count - 6)
        }
    }

    /// Says something to VoiceOver at once, as the keeper moves about the
    /// map: not a notice, and not kept.
    func sayNow(_ text: String) {
        lastSaid = text
        AccessibilityNotification.Announcement(text).post()
    }

    /// What was last said at once, for tests.
    @ObservationIgnored private(set) var lastSaid: String?

    /// VoiceOver says what happened as the notices appear: those posted
    /// together (a watch's worth) in one announcement, not one each.
    private func announce(_ text: String) {
        unannounced.append(text)
        guard unannounced.count == 1 else { return }
        Task { @MainActor [weak self] in
            guard let self else { return }
            AccessibilityNotification.Announcement(self.unannounced.joined(separator: " ")).post()
            self.unannounced = []
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

/// What the top bar shows of the keeper's stores: each resource's income,
/// the companies' upkeep, the room to store, and where each comes from.
struct Ledger {
    let income: Stock
    let upkeep: Int
    let room: Int
    let summaries: [Resource: String]
}

extension GameSession {
    var ledger: Ledger {
        if let kept = ledgerKept, kept.version == tilesVersion { return kept.ledger }
        let house = player
        let income = state.holds(of: house).reduce(Stock.zero) { $0 + state.income(of: $1, territory: territory) }
        var summaries: [Resource: String] = [:]
        for resource in Resource.allCases {
            summaries[resource] = IncomeBreakdown(state: state, house: house, resource: resource, territory: territory).summary
        }
        let ledger = Ledger(income: income, upkeep: state.upkeep(of: house), room: state.storage(of: house), summaries: summaries)
        ledgerKept = (tilesVersion, ledger)
        return ledger
    }
}

extension GameSession {
    /// A value worked out once for each change of the world.
    private func keptForThisWorld<Value>(_ key: String, _ make: () -> Value) -> Value {
        if keptForWorld.version != tilesVersion { keptForWorld = (tilesVersion, [:]) }
        // Kept as it was made, nothing included: counsel may have none to give.
        if let kept = keptForWorld.values[key] { return kept as! Value }
        let value = make()
        keptForWorld.values[key] = value as Any
        return value
    }

    /// Counsel's advice for the world as it stands.
    var counsel: String? {
        keptForThisWorld("counsel") { Counsel.advice(for: state, player: player) }
    }

    /// The race around the lake, House by House.
    var standings: [Standing] {
        keptForThisWorld("standings") { state.standings() }
    }

    /// The holds by where they stand, for the map's marks.
    var holdsByPosition: [Hex: Hold] {
        keptForThisWorld("holds") { Dictionary(state.holds.map { ($0.position, $0) }, uniquingKeysWith: { first, _ in first }) }
    }

    /// The map as VoiceOver reads it.
    var mapItems: [MapAccessibility.Item] {
        let withOrders = voiceOverRunning()
        return keptForThisWorld(withOrders ? "map with orders" : "map") { MapAccessibility.items(for: self, withOrders: withOrders) }
    }
}
