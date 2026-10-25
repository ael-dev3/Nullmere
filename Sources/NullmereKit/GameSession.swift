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
    public private(set) var tileBytes: [UInt8] = []
    public private(set) var tilesVersion = 0
    /// Holds and units the player can see right now, by map index.
    public private(set) var visible: [Bool] = []
    public private(set) var isEndingWatch = false

    private var noticeCounter = 0
    private let store: SaveStore

    public init(state: GameState, store: SaveStore = SaveStore()) {
        self.state = state
        self.store = store
        var camera = Camera(scale: 28)
        if let seat = state.seat(of: state.player) {
            camera.focus(on: seat.position)
        }
        self.camera = camera
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
            let events = try state.perform(command, as: player)
            report(events)
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
        let events = state.endWatch()
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
        tileBytes = TileTexture.bytes(for: state, viewer: player)
        tilesVersion += 1
        refreshPathPreview()
    }

    private func refreshPathPreview() {
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
