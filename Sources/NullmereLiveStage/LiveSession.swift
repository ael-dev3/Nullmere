import Foundation
import NullmereCore
import NullmereLive
import NullmereModels
import NullmereWorld
import Observation

/// What a session asks of the realm and reads from it: the client's own
/// calls, named apart from the client so that a session can be tried
/// without a server.
public protocol LiveLine: AnyObject, Sendable {
    var world: LiveWorld { get }
    func watch(changed: @escaping @Sendable () -> Void) async -> Bool
    func close()
    func join(name: String) async throws
    func build(_ kind: Int) async throws
    func upgrade(building: UInt64) async throws
    func train(building: UInt64, tier: Int, count: UInt64) async throws
    func gather(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws
    func hunt(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws
    func heal(kind: Int, tier: Int, count: UInt64) async throws
    func read(report: UInt64) async throws
    func forget(report: UInt64) async throws
    func recall(march: UInt64) async throws
}

extension LiveClient: LiveLine {}

/// What lies at a hex the player has chosen.
public enum LiveSelection: Equatable, Sendable {
    /// The player's own city.
    case home(LiveCity)
    /// Another player's city, and their name.
    case city(LiveCity, of: String)
    case site(LiveSite)
    case barrow(LiveBarrow)
    /// An army there now, and whether it is the player's own.
    case army(LiveMarch, own: Bool)
    /// Bare land: its ground, as the module numbers it, where it is known.
    case land(LiveHex, ground: UInt8?)
}

/// A player in the realm: their line to it, the world as it stands, where
/// they are looking, what they have chosen, and what they ask.
///
/// Everything is the realm's to decide. The session keeps the latest rows,
/// stages the window of the world about where the player looks, and hands
/// what they ask to the line; what the realm refuses comes back in its
/// own words, kept in `said` until it is put away.
@MainActor
@Observable
public final class LiveSession {
    public enum Phase: Equatable, Sendable {
        /// Waiting on the realm's first rows.
        case opening
        /// In the realm, but not yet a player: a name is wanted.
        case naming
        case playing
        /// The realm can't be reached.
        case lost
    }

    /// How far the window reaches about its heart, and how far the look
    /// may stray from that heart before the window is taken afresh.
    public static let reach = 24
    public static let stray = 8

    public private(set) var phase: Phase = .opening
    public private(set) var world = LiveWorld()
    /// What the realm last would not do, in its own words, until put away.
    public var said: String?
    /// How many things asked are still on their way.
    public private(set) var asking = 0
    /// The hex of the world the player has chosen.
    public var selected: LiveHex?
    /// The hex of the world the player is looking at.
    public private(set) var look = LiveHex(q: 0, r: 0)
    /// The window of the world being drawn, and a number that moves each
    /// time another is taken: the land to be drawn has changed.
    public private(set) var window: LiveWindow?
    public private(set) var windowVersion = 0
    /// A number that moves each time what stands still in the window has
    /// changed: its cities, sites and barrows.
    public private(set) var standingVersion = 0

    @ObservationIgnored private let line: any LiveLine
    @ObservationIgnored private let clock: @Sendable () -> Double
    @ObservationIgnored private var staged: (stage: WorldStage, relief: Relief, terrain: TerrainMesh)?
    @ObservationIgnored private var fixed: [ModelBatch] = []
    @ObservationIgnored private var standing: [LiveHex] = []
    @ObservationIgnored private var landCount = 0
    @ObservationIgnored private var placed = false

    /// The colours players' things are drawn in, by their number.
    public static let colours: [Vec4] = (0..<24).map { index in
        // Hues a golden step apart, so neighbours in the list are far
        // apart in colour; three depths of each, so twenty-four differ.
        let hue = (Double(index) * 0.618_033_988_75).truncatingRemainder(dividingBy: 1) * 2 * Double.pi
        let depth = [0.95, 0.72, 0.55][index % 3]
        func part(_ shift: Double) -> Float { Float(depth * (0.55 + 0.42 * cos(hue + shift))) }
        return Vec4(part(0), part(-2.094), part(2.094), 1)
    }

    public init(line: any LiveLine, clock: @escaping @Sendable () -> Double = { Date().timeIntervalSince1970 }) {
        self.line = line
        self.clock = clock
    }

    /// The moment, by the session's clock: seconds as the realm counts them.
    public var now: Double { clock() }

    // MARK: Reading

    /// Begins watching the realm. Its rows come as they change from here on.
    public func open() async {
        let live = await line.watch { [weak self] in
            Task { @MainActor in self?.refresh() }
        }
        guard live else {
            phase = .lost
            return
        }
        refresh()
    }

    /// Stops watching.
    public func close() {
        line.close()
    }

    /// Takes the realm's rows as they now stand.
    public func refresh() {
        let latest = line.world
        guard latest != world || phase == .opening else { return }
        world = latest
        if world.realm == nil {
            phase = .opening
        } else if world.me == nil || world.city == nil {
            phase = .naming
        } else {
            phase = .playing
        }
        // The first sight of the realm is of the player's own city.
        if !placed, let city = world.city {
            placed = true
            look = city.hex
            window = nil
        }
        retake()
    }

    /// The player looks at another hex of the world: the window follows
    /// once the look has strayed far enough from its heart.
    public func look(at hex: LiveHex) {
        guard hex != look else { return }
        look = hex
        retake()
    }

    /// Takes the window afresh where it is wanted: none yet, the look
    /// strayed from its heart, or more of the land known than when it was
    /// made. And notes what stands in it, if that has changed.
    private func retake() {
        guard world.realm != nil else { return }
        let strayed = window.map { $0.centre.distance(to: look) > LiveSession.stray } ?? true
        if strayed || world.land.count != landCount {
            landCount = world.land.count
            let next = LiveWindow(world: world, centre: strayed ? look : (window?.centre ?? look), radius: LiveSession.reach)
            if next.map != window?.map || next.centre != window?.centre {
                window = next
                windowVersion += 1
                staged = nil
                standing = []
            }
        }
        guard let window else { return }
        let stands = (world.cities.values.map(\.hex) + world.sites.values.map(\.hex) + world.barrows.values.map(\.hex))
            .filter { window.local($0) != nil }.sorted { $0.packed < $1.packed }
        if stands != standing || staged == nil {
            standing = stands
            standingVersion += 1
            fixed = []
        }
    }

    /// The window's land as the renderer takes it, made once for a window.
    public func land() -> (map: WorldMap, relief: Relief, terrain: TerrainMesh)? {
        guard let window else { return nil }
        if staged == nil {
            let relief = Relief(map: window.map)
            staged = (WorldStage(map: window.map, relief: relief), relief, TerrainMesh(relief: relief))
        }
        return staged.map { (window.map, $0.relief, $0.terrain) }
    }

    /// The window's tiles as the world's shader takes them.
    public func tiles() -> [UInt8]? {
        guard let window else { return nil }
        return window.tiles(holds: window.holds(in: world, colours: LiveSession.colours, at: now))
    }

    /// What stands and moves in the window at a moment, staged for the
    /// renderer: its cities and their works, the sites and the Unquiet's
    /// barrows, the armies where they are, and the land's own furniture.
    public func frame(time: Double) -> SceneFrame {
        var frame = SceneFrame()
        guard let window, let land = land(), let stage = staged?.stage else { return frame }
        let seconds = now
        let sights = window.holds(in: world, colours: LiveSession.colours, at: seconds)
        let sites = window.sites(in: world), barrows = window.barrows(in: world)
        if fixed.isEmpty {
            fixed = stage.furnish(occupied: Set(sites.map(\.hex) + barrows.map(\.hex)), holds: Set(sights.map(\.hold.position)))
        }
        frame.fixed = fixed
        frame.fixedVersion = windowVersion * 100_000 + standingVersion
        let (holds, _) = stage.holds(sights, time: Float(time), into: &frame)
        let poses = window.companies(in: world, relief: land.relief, at: seconds)
        frame.batches = holds + stage.sites(sites) + stage.lairs(barrows).batches + stage.companies(poses, houses: LiveSession.colours, into: &frame)
        return frame
    }

    // MARK: Choosing

    /// What lies at a hex of the world now: an army standing or passing
    /// there before what stands there, and that before the bare land.
    public func selection(at hex: LiveHex) -> LiveSelection {
        let seconds = now
        let layout = HexLayout(size: 1)
        let there = world.marches.values.sorted { $0.id < $1.id }.first { march in
            let at = march.position(at: seconds)
            let on = layout.hex(atX: at.x, y: at.y)
            return on.q == hex.q && on.r == hex.r
        }
        if let place = world.places[hex] {
            switch place.kind {
            case LivePlace.city:
                if let city = world.cities[place.id] {
                    if city.id == world.city?.id { return .home(city) }
                    return .city(city, of: world.players[city.owner]?.name ?? city.name)
                }
            case LivePlace.site:
                // An army at work on a site is chosen with the site, not for it.
                if let site = world.sites[place.id] { return .site(site) }
            case LivePlace.barrow:
                if let barrow = world.barrows[place.id] { return .barrow(barrow) }
            default: break
            }
        }
        if let there { return .army(there, own: there.owner == world.me?.id) }
        return .land(hex, ground: world.ground(at: hex))
    }

    /// What the player has chosen, if anything.
    public var selection: LiveSelection? { selected.map { selection(at: $0) } }

    /// The player's soldiers standing ready, kind by kind and tier by tier:
    /// all of them, for an army sent with everyone.
    public var everyoneReady: [(kind: Int, tier: Int, count: UInt64)] {
        world.troops.filter { $0.ready > 0 }.map { ($0.kind, $0.tier, $0.ready) }
    }

    // MARK: Asking

    /// Asks something of the realm; its refusal is kept in `said`.
    private func ask(_ work: @Sendable (any LiveLine) async throws -> Void) async {
        asking += 1
        defer { asking -= 1 }
        do {
            try await work(line)
            refresh()
        } catch let refusal as LiveRefusal {
            said = refusal.words
        } catch {
            said = "The realm could not be reached. Try again in a moment."
        }
    }

    public func join(name: String) async { await ask { try await $0.join(name: name) } }
    public func build(_ kind: Int) async { await ask { try await $0.build(kind) } }
    public func upgrade(building: UInt64) async { await ask { try await $0.upgrade(building: building) } }
    public func train(building: UInt64, tier: Int, count: UInt64) async { await ask { try await $0.train(building: building, tier: tier, count: count) } }
    public func heal(kind: Int, tier: Int, count: UInt64) async { await ask { try await $0.heal(kind: kind, tier: tier, count: count) } }
    public func recall(march: UInt64) async { await ask { try await $0.recall(march: march) } }
    public func read(report: UInt64) async { await ask { try await $0.read(report: report) } }
    public func forget(report: UInt64) async { await ask { try await $0.forget(report: report) } }

    /// Sends soldiers to what the player has chosen: to gather at a site,
    /// or to clear a barrow. Elsewhere there is nothing to send them for.
    public func send(_ soldiers: [(kind: Int, tier: Int, count: UInt64)], to hex: LiveHex) async {
        let asked = soldiers.map { (kind: $0.kind, tier: $0.tier, count: $0.count) }
        switch selection(at: hex) {
        case .site(let site): await ask { try await $0.gather(at: site.hex, soldiers: asked) }
        case .barrow(let barrow): await ask { try await $0.hunt(at: barrow.hex, soldiers: asked) }
        default: said = "There is nothing to send an army for there."
        }
    }
}
