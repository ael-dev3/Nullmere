import Foundation
import NullmereCore

/// A realm hosted in this process: the same authority a realm server
/// runs, with keepers attached by links. Tests use it, and so does
/// development on a single Mac.
@MainActor
public final class LocalRealm {
    public private(set) var state: RealmState
    private let clock: () -> Double
    private let storeURL: URL?
    private var links: [String: WeakLink] = [:]

    private struct WeakLink {
        weak var link: LocalLink?
    }

    public init(state: RealmState, clock: @escaping () -> Double = { Date().timeIntervalSince1970 }, storeURL: URL? = nil) {
        self.state = state
        self.clock = clock
        self.storeURL = storeURL
    }

    /// Opens the realm kept at `url`, or begins a new one there.
    public static func open(at url: URL, name: String, seed: String, seats: Int = RealmState.defaultSeats, watchLength: Double = RealmState.defaultWatchLength,
                            clock: @escaping () -> Double = { Date().timeIntervalSince1970 }) -> LocalRealm {
        if let data = try? Data(contentsOf: url), let state = try? JSONDecoder().decode(RealmState.self, from: data) {
            return LocalRealm(state: state, clock: clock, storeURL: url)
        }
        let realm = LocalRealm(state: RealmState(name: name, seed: seed, seats: seats, watchLength: watchLength, now: clock()),
                               clock: clock, storeURL: url)
        realm.persist()
        return realm
    }

    /// A line to the realm for the keeper with this identity.
    public func link(identity: String) -> LocalLink {
        let link = LocalLink(realm: self, identity: identity)
        links[identity] = WeakLink(link: link)
        return link
    }

    public var status: RealmStatus { state.status(now: clock()) }

    /// Turns the watch if its time has run out.
    public func tick() {
        let age = state.age
        guard let events = state.tick(now: clock()) else { return }
        turned(events, since: age)
    }

    /// A steward plays a keeper's House for some watches, the watch turning
    /// after each: for a game well under way, in tests and development.
    public func autoplay(_ identity: String, watches: Int) {
        for _ in 0..<watches where state.world.outcome == nil {
            state.stewardOrders(for: identity)
            let age = state.age
            guard let events = state.setReady(identity, true, now: clock()) else { return }
            turned(events, since: age)
        }
    }

    // MARK: What links ask

    func connect(_ identity: String) {
        deliver(.status(status), to: identity)
    }

    func arrive(_ identity: String, name: String?) {
        do {
            let keeper = try state.arrive(identity, name: name, now: clock())
            persist()
            deliver(.arrived(keeper, world(for: identity)), to: identity)
            // A seat taken changes the world for everyone: a House is renamed
            // for its keeper, and no steward's any more.
            for other in links.keys where other != identity {
                deliver(.changed(world(for: other)), to: other)
            }
            broadcastStatus()
        } catch {
            deliver(.refused(error), to: identity)
        }
    }

    func send(_ command: Command, from identity: String) {
        do {
            let events = try state.perform(command, by: identity)
            persist()
            let mine = heard(events, by: identity)
            deliver(.settled(world(for: identity), mine), to: identity)
            deliver(.answered(mine), to: identity)
            for other in links.keys where other != identity {
                deliver(.changed(world(for: other)), to: other)
                let news = heard(events, by: other)
                if !news.isEmpty { deliver(.heard(news), to: other) }
            }
        } catch {
            deliver(.orderRefused(error, world(for: identity)), to: identity)
        }
    }

    func setReady(_ ready: Bool, from identity: String) {
        let age = state.age
        if let events = state.setReady(identity, ready, now: clock()) {
            turned(events, since: age)
        } else {
            persist()
            broadcastStatus()
        }
    }

    func leave(_ identity: String) {
        state.depart(identity, now: clock())
        links[identity] = nil
        persist()
        broadcastStatus()
    }

    // MARK: Telling

    private func turned(_ events: [GameEvent], since age: Int) {
        persist()
        broadcastStatus()
        for identity in links.keys {
            if state.age != age, let keeper = state.keeper(identity) {
                // A new age: every keeper is seated afresh.
                deliver(.arrived(keeper, world(for: identity)), to: identity)
            } else {
                deliver(.watchTurned(world(for: identity), heard(events, by: identity)), to: identity)
            }
        }
    }

    /// The world as a keeper may know it.
    private func world(for identity: String) -> GameState {
        state.view(for: identity)?.world ?? state.world.view(for: -1)
    }

    private func heard(_ events: [GameEvent], by identity: String) -> [GameEvent] {
        guard let house = state.keeper(identity)?.house else { return [] }
        return state.world.events(events, heardBy: house)
    }

    private func broadcastStatus() {
        let status = self.status
        for identity in links.keys {
            deliver(.status(status), to: identity)
        }
    }

    private func deliver(_ event: RealmEvent, to identity: String) {
        guard let link = links[identity]?.link else {
            links[identity] = nil
            return
        }
        link.onEvent?(event)
    }

    private func persist() {
        guard let storeURL, let data = try? JSONEncoder().encode(state) else { return }
        try? FileManager.default.createDirectory(at: storeURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: storeURL, options: .atomic)
    }
}

/// A keeper's line to a realm in this process: every answer comes at once.
@MainActor
public final class LocalLink: RealmLink {
    private weak var realm: LocalRealm?
    public let identity: String
    public var onEvent: ((RealmEvent) -> Void)?

    init(realm: LocalRealm, identity: String) {
        self.realm = realm
        self.identity = identity
    }

    public func connect() {
        guard let realm else {
            onEvent?(.unreachable("The realm has closed."))
            return
        }
        realm.connect(identity)
    }

    public func arrive(name: String?) {
        realm?.arrive(identity, name: name)
    }

    public func send(_ command: Command) {
        realm?.send(command, from: identity)
    }

    public func setReady(_ ready: Bool) {
        realm?.setReady(ready, from: identity)
    }

    public func leave() {
        realm?.leave(identity)
    }
}
