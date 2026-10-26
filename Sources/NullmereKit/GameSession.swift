import AppKit
import Foundation
import NullmereCore
import Observation
import SwiftUI

/// One game in progress, and everything the interface needs about it: what
/// is selected, where the camera looks, what just happened, and saving.
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
        didSet { if selection != oldValue { refreshPathPreview() } }
    }
    public var panel: Panel?
    public private(set) var notices: [Notice] = []
    public private(set) var pathPreview: [Hex] = []
    /// What attacking the hovered hex with the selected company would do.
    public private(set) var hoverForecast: Forecast?
    public private(set) var tileBytes: [UInt8] = []
    public private(set) var tilesVersion = 0
    /// Which hold's land each tile is, by map index.
    public private(set) var territory: [Int?] = []
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

    /// Orders this watch that can be taken back, newest last.
    private var undoStack: [(state: GameState, command: Command)] = []

    public var canUndo: Bool { !undoStack.isEmpty }

    /// A company's march being shown, from where it stood along the route.
    public struct March: Equatable {
        public let path: [Hex]
        public let start: Date

        public static let secondsPerStep = 0.16

        public var duration: Double { Double(max(path.count - 1, 1)) * March.secondsPerStep }
    }

    /// Called with each sound the game makes.
    public var onCue: ((Ambience.Cue) -> Void)?

    /// A blow the player saw land: a ring and the damage, briefly, where it fell.
    public struct Blow: Equatable, Identifiable {
        public let id: Int
        public let at: Hex
        public let damage: Int
        /// Whether it fell on the player's side.
        public let againstPlayer: Bool
        public let start: Date

        public static let duration = 1.4
    }

    /// Blows still being drawn.
    public private(set) var blows: [Blow] = []
    private var blowCounter = 0

    /// Marches still being drawn, by unit.
    public private(set) var marches: [Int: March] = [:]

    private var noticeCounter = 0
    private let store: SaveStore
    private let voice: (any Voice)?
    private var voiceQueue: [(Spoken, VoiceMoment)] = []
    private var asked: Set<Spoken> = []
    private var isSpeaking = false

    public init(state: GameState, store: SaveStore = SaveStore(), voice: (any Voice)? = nil) {
        self.state = state
        self.store = store
        self.voice = voice
        var camera = Camera(scale: 28)
        if let seat = state.seat(of: state.player) {
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
    }

    public var player: Int { state.player }
    public var playerHouse: House { state.houses[state.player] }

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
            let previous = state
            let events = try state.perform(command, as: player)
            if Self.isUndoable(command, events: events, before: previous, after: state, player: player) {
                undoStack.append((previous, command))
            } else {
                // Something learned or left to chance can't be taken back, nor
                // anything before it.
                undoStack.removeAll()
            }
            showMarches(events, from: before)
            showBlows(events)
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

    /// Ends the watch: the rivals move and the world turns.
    public func endWatch() {
        guard state.outcome == nil, !isEndingWatch else { return }
        isEndingWatch = true
        let before = positions()
        undoStack.removeAll()
        let events = state.endWatch()
        showMarches(events, from: before)
        showBlows(events)
        onCue?(.watch)
        if events.contains(where: isDreadful) {
            onCue?(.dread)
        }
        notices.removeAll()
        report(events)
        if case .unit(let id) = selection, state.unit(id) == nil {
            selection = .none
        }
        refreshWorld()
        isEndingWatch = false
        store.save(state)
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

    /// Lets a steward play the player's watches, then ends them: for
    /// screenshots and tests of a game well under way.
    func autoplay(watches: Int) {
        for _ in 0..<watches where state.outcome == nil {
            _ = state.stewardTurn(for: player)
            _ = state.endWatch()
        }
        notices.removeAll()
        selection = .none
        refreshWorld()
        if let seat = state.seat(of: player) {
            camera.focus(on: seat.position)
        }
    }

    public func save(quietly: Bool = false) {
        store.save(state)
        if !quietly { post("Saved.", tone: .neutral) }
    }

    // MARK: Bookkeeping

    private func refreshWorld() {
        visible = state.visibility(for: player)
        territory = state.territory()
        tileBytes = TileTexture.bytes(for: state, viewer: player)
        tilesVersion += 1
        refreshPathPreview()
        askVoices()
    }

    // MARK: Undo

    /// Takes back the last order, if nothing in it was left to chance or
    /// revealed anything new.
    public func undo() {
        guard let last = undoStack.popLast() else { return }
        state = last.state
        if case .unit(let id) = selection, state.unit(id) == nil { selection = .none }
        if case .hold(let id) = selection, state.hold(id)?.owner != player { selection = .none }
        refreshWorld()
        post("Order taken back.", tone: .neutral)
    }

    static func isUndoable(_ command: Command, events: [GameEvent], before: GameState, after: GameState, player: Int) -> Bool {
        switch command {
        case .build, .train, .barter, .fortify, .halt, .disband:
            return true
        case .move:
            // A march may be taken back if it met nothing and saw nothing new.
            let quiet = events.allSatisfy { event in
                if case .moved = event { return true }
                return false
            }
            return quiet && before.houses[player].explored == after.houses[player].explored
        case .attack, .found, .declareWar, .propose, .answer:
            return false
        }
    }

    // MARK: Sound

    private func sound(for command: Command, events: [GameEvent]) {
        switch command {
        case .attack: onCue?(.battle)
        case .move: onCue?(.order)
        case .found, .build, .train: onCue?(.rise)
        case .declareWar: onCue?(.dread)
        default: onCue?(.select)
        }
    }

    /// What should sound like dread to the player: their holds lost, war
    /// declared on them, a House fallen.
    private func isDreadful(_ event: GameEvent) -> Bool {
        switch event {
        case .holdCaptured(_, let from, _): return from == player
        case .stanceChanged(let first, let second, .war, let by): return by != player && (first == player || second == player)
        case .houseFell: return true
        default: return false
        }
    }

    // MARK: Blows

    /// Draws the blows the player could see, then forgets them.
    func showBlows(_ events: [GameEvent]) {
        let now = Date()
        var shown = false
        for case .battle(let battle) in events {
            let mine = battle.attackerOwner == player || battle.defenderOwner == player
            guard mine || isVisible(battle.at) else { continue }
            blowCounter += 1
            blows.append(Blow(id: blowCounter, at: battle.at, damage: battle.damageDealt,
                              againstPlayer: battle.defenderOwner == player, start: now))
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
        for envoy in state.envoys where !asked.contains(.envoy(envoy.id)) {
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
