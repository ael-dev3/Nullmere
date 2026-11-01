import Foundation
import NullmereCore
import NullmereModels
import NullmereWorld

/// The trailer, shot by shot: the still black lake under the moon, the
/// seats on its shores and their towns at night, the Moonspire crowned and
/// another rising, a host on the march, rain off the water, a battle in
/// the dark, the moon eaten over the still water and the field after under
/// it, the whole lake from on high, and the title. No interface and nothing of the rules: only the world as
/// the game draws it, through moving cameras, and its score.
public struct Trailer {
    /// What a shot shows.
    public enum Look: Equatable, Sendable {
        /// The lake of the title screen, with nothing on it.
        case lake
        /// The lake of the title screen, the title rising over it.
        case title
        /// The lake of the title screen, its moon eaten as the shot goes.
        case eclipse
        /// The world, through the shot's camera.
        case world
    }

    /// What moves in a world shot besides the world's own life.
    public enum Action: Equatable, Sendable {
        case none
        case march
        case battle
        /// The field after: the fallen, the smoke, under the eaten moon.
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
    public static let framesPerSecond = 60

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
        let relief = world.relief
        var shots: [Shot] = []
        var clock = 0.0
        func add(_ name: String, _ length: Double, _ look: Look, action: Action = .none, weather: Weather = .clear, dissolve: Double = 1.2,
                 camera: @escaping @Sendable (Double) -> Camera = { _ in Camera() }) {
            shots.append(Shot(name: name, start: clock, length: length, look: look, action: action, weather: weather,
                              dissolve: shots.isEmpty ? 0 : dissolve, camera: camera))
            clock += length
        }
        // Every camera low and slow, near the water and the holds: at most a
        // few times a keep's height over the ground, leaning toward the
        // horizon but never past it (a tilt of 1.2 and the view's half
        // height, 0.3, stay below it), easing from one framing to the next.
        // Out from the shore hold over the water, toward the lake's heart;
        // and the heading that looks toward the moon, its image on the water.
        let out = (x: (lake.x - shore.x) / max(hypot(lake.x - shore.x, lake.y - shore.y), 1e-6),
                   y: (lake.y - shore.y) / max(hypot(lake.x - shore.x, lake.y - shore.y), 1e-6))
        let toMoon = atan2(-Double(Sky.moon.x), -Double(Sky.moon.z))
        // The still: the lake of the title screen, the moon on the water.
        add("the still", 8, .lake)
        // Low over the black water, coming in to a hold on the shore, the
        // seats' lights beyond it.
        add("the shore", 11, .world, dissolve: 2) { u in
            Trailer.move(relief, u, (shore.x + out.x * 3.1, shore.y + out.y * 3.1, 115, 1.2, toLake + .pi - 0.18),
                 (shore.x + out.x * 0.4, shore.y + out.y * 0.4, 138, 1.17, toLake + .pi + 0.02))
        }
        // About the seat, its Moonspire crowned, close and turning slowly.
        add("the seat", 11, .world) { u in
            Trailer.move(relief, u, (seat.x, seat.y, 175, 1.12, 0.4), (seat.x, seat.y, 195, 1.12, 1.45))
        }
        // Gliding past a great hold, low over its roofs and its folk.
        add("the town", 9, .world) { u in
            Trailer.move(relief, u, (town.x - 0.7, town.y - 0.8, 200, 1.14, 0.9), (town.x + 0.7, town.y + 0.8, 200, 1.14, 1.3))
        }
        // Another House's Moonspire rising, its crane at work.
        add("the rising", 7, .world) { u in
            Trailer.move(relief, u, (rising.x, rising.y, 200, 1.08, -1.95), (rising.x, rising.y, 215, 1.08, -1.6))
        }
        // Alongside a host on the march, at its own pace.
        add("the march", 12, .world, action: .march) { u in
            let middle = march.middle(at: u * 12)
            let h = march.sideHeading
            return Trailer.aimed(relief, x: Double(middle.x), y: Double(middle.z), scale: Trailer.mix(175, 185, u), tilt: 1.18,
                                 heading: h + Trailer.mix(-0.15, 0.15, Trailer.ease(u)))
        }
        // Rain off the lake over the hold on the shore.
        add("the rain", 7, .world, weather: .rain) { u in
            Trailer.move(relief, u, (shore.x, shore.y, 150, 1.16, toLake + 0.05), (shore.x, shore.y, 165, 1.16, toLake + 0.35))
        }
        // Battle in the dark, from the edge of the field in among the lines.
        add("the battle", 16, .world, action: .battle, dissolve: 0.6) { u in
            let c = battle.centre
            let h = battle.sideHeading
            return Trailer.move(relief, min(u / 0.6, 1), (Double(c.x), Double(c.z), 140, 1.18, h - 0.6), (Double(c.x), Double(c.z), 210, 1.12, h - 0.1))
        }
        // The moon eaten over the still water, the world's shadow coming
        // over it until it hangs a dull ember among the stars.
        add("the moon eaten", 6, .eclipse, dissolve: 1)
        // The field after, under the eaten moon.
        add("the field after", 6, .world, action: .aftermath, weather: .eclipse) { u in
            let c = battle.centre
            return Trailer.move(relief, u, (Double(c.x), Double(c.z), 185, 1.12, battle.sideHeading + 0.4), (Double(c.x), Double(c.z), 200, 1.12, battle.sideHeading + 0.7))
        }
        // Out from the shore over the black water to the moon's image on it.
        add("the lake", 9, .world, dissolve: 1.5) { u in
            Trailer.move(relief, u, (shore.x + out.x * 2.6, shore.y + out.y * 2.6, 95, 1.2, toLake + 0.3),
                 (shore.x + out.x * 9, shore.y + out.y * 9, 70, 1.05, toMoon))
        }
        add("the title", 10, .title, dissolve: 2)
        return shots
    }

    /// A camera whose view's middle falls on the ground at a point of the
    /// map, as high as the land stands there, rather than on the water's
    /// face beneath it.
    static func aimed(_ relief: Relief, x: Double, y: Double, scale: Double, tilt: Double, heading: Double) -> Camera {
        let height = Double(max(relief.height(atX: Float(x), z: Float(y)), Relief.waterline))
        let back = height * tan(tilt)
        return Camera(centerX: x - sin(heading) * back, centerY: y - cos(heading) * back, scale: scale, tilt: tilt, heading: heading)
    }

    /// A camera easing from one framing to another as `u` goes from 0 to 1,
    /// each aimed at the ground beneath it.
    static func move(_ relief: Relief, _ u: Double, _ from: (x: Double, y: Double, scale: Double, tilt: Double, heading: Double),
                     _ to: (x: Double, y: Double, scale: Double, tilt: Double, heading: Double)) -> Camera {
        let e = Trailer.ease(u)
        return Trailer.aimed(relief, x: Trailer.mix(from.x, to.x, e), y: Trailer.mix(from.y, to.y, e), scale: Trailer.mix(from.scale, to.scale, e),
                             tilt: Trailer.mix(from.tilt, to.tilt, e), heading: Trailer.mix(from.heading, to.heading, e))
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

    /// How far the moon is eaten in a shot at a moment: 0 whole, rising to
    /// 1 through the first three quarters of the eclipse's shot and held
    /// there as it dissolves away; whole in every other shot.
    public func eaten(of shot: Shot, at time: Double) -> Double {
        guard shot.look == .eclipse else { return 0 }
        let u = min(max((time - shot.start - 0.4) / (shot.length * 0.7), 0), 1)
        return u * u * (3 - 2 * u)
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

    /// The kinds of mote a shot leaves out: whatever would read as a mark
    /// laid over the picture rather than a thing in the world, as the game
    /// marks it for its keepers: a skill's ring, sigil and shafts, a blow's
    /// flash, the dust of feet and blows hanging in the air, the fireflies.
    public static let leftOut: Set<Effect> = [.flash, .dust, .fireflies, .fury, .sigil, .pillar, .ward, .blaze, .volley, .quake,
                                              .sighting]

    /// The models a world shot draws at a moment: the holds and their
    /// towns, the land's furniture and sites, the hearths' smoke and the
    /// birds over the water, the weather, and the shot's own host or
    /// battle; nothing the game lays over its world for its keepers.
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
        frame.fixed = world.furniture
        frame.fixedVersion = world.stage.furnitureVersion
        frame.fixedRegions = world.stage.furnitureRegions
        // The towns without their lanes, which from above read as lines laid
        // over the land, a ring round each walled hold.
        frame.batches = (holds + folk + sites + lairs.batches + companies + flights).filter { $0.key != .town(.lane) }
        (frame.motes, frame.lights) = happenings.effects(at: t, leaving: Trailer.leftOut)
        frame.weather = shot.weather
        let extent = Float(min(max(600 / max(camera.scale, 1), 3), 14))
        frame.motes += shot.weather.motes(around: camera.focus, extent: extent, time: t)
        return frame
    }
}

/// A frame's pixels as the film takes them: four bytes each, blue, green,
/// red and alpha, row by row from the top.
public enum Pixels {
    /// One picture dissolving into another: `weight` of `into`, the rest of
    /// `from`, written over `from`.
    public static func dissolve(_ from: inout [UInt8], into: [UInt8], weight: Double) {
        let w = UInt32(min(max(weight, 0), 1) * 256)
        let count = min(from.count, into.count)
        from.withUnsafeMutableBufferPointer { a in
            into.withUnsafeBufferPointer { b in
                let keep = 256 - w
                for index in 0..<count {
                    let mixed: UInt32 = UInt32(a[index]) * keep + UInt32(b[index]) * w + 128
                    a[index] = UInt8(truncatingIfNeeded: mixed >> 8)
                }
            }
        }
    }

    /// How much of each pixel a picture keeps under its vignette, out of
    /// 256: all of it about the middle, a little less toward the edges and
    /// a quarter less in the corners, as a lens darkens them.
    public static func vignette(width: Int, height: Int) -> [UInt16] {
        var keep = [UInt16](repeating: 256, count: width * height)
        let cx = Double(width) / 2, cy = Double(height) / 2
        for y in 0..<height {
            for x in 0..<width {
                let dx = (Double(x) + 0.5 - cx) / cx, dy = (Double(y) + 0.5 - cy) / cy
                let r = min((dx * dx + dy * dy).squareRoot() / 2.0.squareRoot(), 1)
                let u = min(max((r - 0.45) / 0.55, 0), 1)
                keep[y * width + x] = UInt16((256 * (1 - 0.26 * u * u * (3 - 2 * u))).rounded())
            }
        }
        return keep
    }

    /// A picture under a vignette (see `vignette(width:height:)`): its
    /// colours dimmed by it, its alpha left.
    public static func vignette(_ pixels: inout [UInt8], keeping keep: [UInt16]) {
        let count = min(pixels.count / 4, keep.count)
        pixels.withUnsafeMutableBufferPointer { p in
            keep.withUnsafeBufferPointer { k in
                for index in 0..<count {
                    let factor = UInt32(k[index])
                    for channel in 0..<3 {
                        let at = index * 4 + channel
                        let dimmed: UInt32 = UInt32(p[at]) * factor
                        p[at] = UInt8(truncatingIfNeeded: dimmed >> 8)
                    }
                }
            }
        }
    }

    /// A picture darkened toward black: `brightness` 1 leaves it as it is.
    public static func darken(_ pixels: inout [UInt8], to brightness: Double) {
        guard brightness < 1 else { return }
        let b = UInt32(min(max(brightness, 0), 1) * 256)
        pixels.withUnsafeMutableBufferPointer { p in
            for index in p.indices {
                let dimmed: UInt32 = UInt32(p[index]) * b
                p[index] = UInt8(truncatingIfNeeded: dimmed >> 8)
            }
        }
    }
}
