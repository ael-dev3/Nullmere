import Foundation
import NullmereCore
import NullmereModels
import NullmereWorld

/// The trailer, shot by shot: the still black lake under the moon, the
/// seats on its shores and their towns at night, the Moonspire crowned and
/// another rising, a host on the march, rain off the water, a battle in
/// the dark, the moon eaten over the field, the whole lake from on high,
/// and the title. No interface and nothing of the rules: only the world as
/// the game draws it, through moving cameras, and its score.
public struct Trailer {
    /// What a shot shows.
    public enum Look: Equatable, Sendable {
        /// The lake of the title screen, with nothing on it.
        case lake
        /// The lake of the title screen, the title rising over it.
        case title
        /// The world, through the shot's camera.
        case world
    }

    /// What moves in a world shot besides the world's own life.
    public enum Action: Equatable, Sendable {
        case none
        case march
        case battle
        /// The field after: the fallen, the smoke, the moon eaten.
        case aftermath
    }

    public struct Shot: Sendable {
        public let name: String
        public let start: Double
        public let length: Double
        public let look: Look
        public let action: Action
        public let weather: Weather
        /// Seconds over which it dissolves in from the shot before.
        public let dissolve: Double
        /// The camera, a quarter of the way through the shot at 0.25.
        public let camera: @Sendable (Double) -> Camera

        public var end: Double { start + length }
    }

    /// The frame drawn: 1920 by 1080 pixels, a view of 960 by 540 points
    /// at two pixels to the point, as on a Retina Mac.
    public static let width = 1920
    public static let height = 1080
    public static let viewSize = CGSize(width: 960, height: 540)
    public static let pixelsPerPoint = 2.0
    public static let framesPerSecond = 30

    public let world: TrailerWorld
    public let shots: [Shot]
    public let march: March
    public let battle: Battle

    public var duration: Double { shots.last?.end ?? 0 }
    public var frameCount: Int { Int((duration * Double(Trailer.framesPerSecond)).rounded()) }

    /// When the title begins to show, and when the picture begins to go.
    public var titleRises: Double { (shots.last?.start ?? 0) + 2 }
    public var fadesOut: Double { duration - 2.5 }

    public init(houses: [Vec4]) {
        let world = TrailerWorld(houses: houses)
        self.world = world
        let march = March(world: world)
        let battle = Battle(world: world)
        self.march = march
        self.battle = battle
        shots = Trailer.shots(world: world, march: march, battle: battle)
    }

    // MARK: The shots

    static func shots(world: TrailerWorld, march: March, battle: Battle) -> [Shot] {
        let layout = HexLayout(size: 1)
        func at(_ hex: Hex) -> (x: Double, y: Double) {
            let c = layout.center(of: hex)
            return (c.x, c.y)
        }
        let seat = at(world.seat.position), rising = at(world.rising.position)
        let town = at(world.town.position), shore = at(world.shore.position)
        let lake = (x: 0.0, y: 0.0)
        // The shore hold looks out over the water: its heading puts the
        // lake's heart beyond it.
        let toLake = atan2(shore.x - lake.x, shore.y - lake.y)
        var shots: [Shot] = []
        var clock = 0.0
        func add(_ name: String, _ length: Double, _ look: Look, action: Action = .none, weather: Weather = .clear, dissolve: Double = 1.2,
                 camera: @escaping @Sendable (Double) -> Camera = { _ in Camera() }) {
            shots.append(Shot(name: name, start: clock, length: length, look: look, action: action, weather: weather,
                              dissolve: shots.isEmpty ? 0 : dissolve, camera: camera))
            clock += length
        }
        // The still: the lake of the title screen, the moon on the water.
        add("the still", 9, .lake)
        // Down out of the night to the seat on the shore.
        add("the descent", 10, .world, dissolve: 2) { u in
            let e = Trailer.ease(u)
            return Camera(centerX: Trailer.mix(lake.x, seat.x, e), centerY: Trailer.mix(lake.y, seat.y, e), scale: Trailer.mix(10, 46, e * e),
                          tilt: Trailer.mix(0.42, 0.86, e), heading: Trailer.mix(-0.6, 0.35, e))
        }
        // About the seat, its Moonspire crowned and turning.
        add("the seat", 11, .world) { u in
            Camera(centerX: seat.x, centerY: seat.y, scale: Trailer.mix(92, 118, u), tilt: Trailer.mix(0.98, 1.06, u), heading: Trailer.mix(0.35, 1.75, Trailer.ease(u)))
        }
        // Along the lanes of a great hold, its folk about their work.
        add("the town", 9, .world) { u in
            let h = 2.4
            let side = (x: cos(h), y: -sin(h))
            return Camera(centerX: town.x + side.x * Trailer.mix(-0.9, 0.9, u), centerY: town.y + side.y * Trailer.mix(-0.9, 0.9, u), scale: 150,
                          tilt: 1.04, heading: h)
        }
        // Another House's Moonspire rising, its crane at work.
        add("the rising", 7, .world) { u in
            Camera(centerX: rising.x, centerY: rising.y, scale: Trailer.mix(104, 126, u), tilt: 1.0, heading: Trailer.mix(-2.2, -1.5, u))
        }
        // A host on the march along the way between two holds.
        add("the march", 12, .world, action: .march) { u in
            let head = march.head(at: u * 12)
            let h = march.sideHeading
            return Camera(centerX: Double(head.x), centerY: Double(head.z), scale: Trailer.mix(118, 96, u), tilt: Trailer.mix(1.02, 0.96, u), heading: h + Trailer.mix(-0.25, 0.15, u))
        }
        // Rain off the lake over a hold on the shore.
        add("the rain", 7, .world, weather: .rain) { u in
            Camera(centerX: shore.x, centerY: shore.y, scale: Trailer.mix(62, 74, u), tilt: 0.96, heading: toLake + .pi + Trailer.mix(-0.2, 0.2, u))
        }
        // Battle in the dark.
        add("the battle", 16, .world, action: .battle, dissolve: 0.6) { u in
            let c = battle.centre
            let h = battle.sideHeading
            let push = Trailer.ease(min(u / 0.55, 1))
            return Camera(centerX: Double(c.x), centerY: Double(c.z), scale: Trailer.mix(58, 128, push), tilt: Trailer.mix(0.9, 1.06, push),
                          heading: h + Trailer.mix(-0.5, 0.35, Trailer.ease(u)))
        }
        // The field after, the moon eaten.
        add("the eaten moon", 6, .world, action: .aftermath, weather: .eclipse) { u in
            let c = battle.centre
            return Camera(centerX: Double(c.x), centerY: Double(c.z), scale: Trailer.mix(128, 52, Trailer.ease(u)), tilt: Trailer.mix(1.05, 0.82, u),
                          heading: battle.sideHeading + 0.35 + 0.2 * u)
        }
        // The whole lake from on high, the holds about the black water.
        add("the lake", 7, .world, dissolve: 1.5) { u in
            let e = Trailer.ease(u)
            return Camera(centerX: Trailer.mix(seat.x * 0.6, lake.x, e), centerY: Trailer.mix(seat.y * 0.6, lake.y, e), scale: Trailer.mix(30, 9.6, e),
                          tilt: Trailer.mix(0.8, 0.36, e), heading: Trailer.mix(0.6, 1.1, u))
        }
        // The title.
        add("the title", 10, .title, dissolve: 2)
        return shots
    }

    static func ease(_ u: Double) -> Double { u * u * (3 - 2 * u) }
    static func mix(_ a: Double, _ b: Double, _ u: Double) -> Double { a + (b - a) * u }

    /// The shot at a moment, and the one it is dissolving in from, if it is.
    public func shot(at time: Double) -> (shot: Shot, from: Shot?, weight: Double) {
        let index = shots.lastIndex { $0.start <= time } ?? 0
        let shot = shots[index]
        guard index > 0, shot.dissolve > 0, time < shot.start + shot.dissolve else { return (shot, nil, 1) }
        let u = (time - shot.start) / shot.dissolve
        return (shot, shots[index - 1], u * u * (3 - 2 * u))
    }

    /// How bright the picture is at a moment: up from black as it opens,
    /// down to black as it ends.
    public func brightness(at time: Double) -> Double {
        let opening = min(max(time / 3, 0), 1)
        let closing = min(max((duration - time) / 2.5, 0), 1)
        return opening * opening * (3 - 2 * opening) * closing * closing * (3 - 2 * closing)
    }

    /// How much of the title shows at a moment.
    public func title(at time: Double) -> Double {
        let u = min(max((time - titleRises) / 2.5, 0), 1)
        return u * u * (3 - 2 * u)
    }

    /// A shot's camera at a moment of the trailer, held at the shot's ends
    /// while it dissolves in or out.
    public func camera(of shot: Shot, at time: Double) -> Camera {
        shot.camera(min(max((time - shot.start) / shot.length, 0), 1))
    }

    // MARK: The scene

    /// The models a world shot draws at a moment: the holds and their
    /// towns, the land's furniture and sites, the hearths' smoke and the
    /// birds over the water, the night's fireflies, the weather, and the
    /// shot's own host or battle.
    public func scene(of shot: Shot, at time: Double) -> SceneFrame {
        let world = self.world
        let camera = self.camera(of: shot, at: time)
        let t = Float(time)
        var frame = SceneFrame()
        frame.fine = camera.scale >= 56
        let view = ViewFrustum(viewProjection: camera.viewProjection(in: Trailer.viewSize))
        let sights = world.holds.filter { view.sees($0.position, within: HoldLayout.reach + 1.5) }.map { hold in
            HoldSight(hold: hold, colour: world.colour(of: hold.owner), progress: nil, finishing: nil,
                      heritage: world.state.heritage(of: hold.owner))
        }
        let (holds, hearths) = world.stage.holds(sights, time: t, into: &frame)
        let folk = world.stage.townsfolk(sights, time: t, crowds: frame.fine, into: &frame) + world.stage.traffic(world.ways, time: t, into: &frame)
        let sites = world.stage.sites(world.state.sitesInLand.filter { !$0.isYard }.map { ($0.store, $0.position) })
            + world.stage.shrines(world.state.holySites.map { shrine in
                (shrine.kind, shrine.position, shrine.holder.flatMap { world.state.houses.indices.contains($0) ? world.colour(of: $0) : nil })
            })
        let lairs = world.stage.lairs(world.state.lairsStanding.filter { $0.gate == nil }.map { ($0.kind, $0.position) })
        var poses: [CompanyPose] = []
        var arrows: [ArrowFlight] = []
        var happenings = Happenings()
        let elapsed = time - shot.start
        switch shot.action {
        case .none: break
        case .march: march.stage(at: elapsed, in: world, poses: &poses, happenings: &happenings)
        case .battle: battle.stage(at: elapsed, in: world, poses: &poses, arrows: &arrows, happenings: &happenings)
        case .aftermath: battle.after(at: elapsed, in: world, poses: &poses, happenings: &happenings)
        }
        let companies = world.stage.companies(poses, houses: world.houses, into: &frame)
        let lake = Relief.centre(of: Hex(0, 0))
        let flights = WorldStage.flights(arrows: arrows, birdsOver: Vec3(lake.x, Relief.waterline, lake.z), hearths: hearths + lairs.hearths,
                                         time: t, into: &frame)
        // The night's fireflies about the middle of the view.
        happenings.fireflies += world.stage.fireflySpots(near: camera.focus).enumerated().map { index, at in
            Happenings.Spot(at: at, strength: 1, seed: UInt32(index + 1))
        }
        frame.fixed = world.furniture
        frame.fixedVersion = world.stage.furnitureVersion
        frame.fixedRegions = world.stage.furnitureRegions
        frame.batches = holds + folk + sites + lairs.batches + companies + flights
        (frame.motes, frame.lights) = happenings.effects(at: t)
        frame.weather = shot.weather
        let extent = Float(min(max(600 / max(camera.scale, 1), 3), 14))
        frame.motes += shot.weather.motes(around: camera.focus, extent: extent, time: t)
        return frame
    }
}
