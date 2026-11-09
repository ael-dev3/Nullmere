import Foundation
import NullmereCore
import NullmereModels

/// A mote of light, dust or smoke as the GPU draws it: a soft disc facing
/// the eye. Matches `Mote` in `WorldShaders.source`: 32 bytes.
public struct Mote: Equatable, Sendable {
    /// Where it is, and its radius in world units.
    public var place: Vec4
    /// The light it gives, linear and already scaled by how much shows;
    /// and how much of what lies behind it it hides (0 for pure light).
    public var colour: Vec4

    public init(at position: Vec3, size: Float, light: Vec3, cover: Float) {
        place = Vec4(position.x, position.y, position.z, size)
        colour = Vec4(light.x, light.y, light.z, cover)
    }
}

/// The kinds of motes the world throws up.
public enum Effect: String, CaseIterable, Sendable {
    /// Steel on steel: bright, quick, falling.
    case sparks
    /// Kicked up by feet, hooves, blows and falls: brown, slow, settling.
    case dust
    /// From what burns: dark, rising, spreading.
    case smoke
    /// From what burns: orange points rising and winking out.
    case embers
    /// The moment a blow lands: one bright swell of light.
    case flash
    /// Stone and timber knocked from a ward: grey chips thrown and falling.
    case splinters
    /// The night's small lights over reeds and grass, wandering and blinking.
    case fireflies
    /// A commander's skill fired: pale gold rising in a widening ring.
    case fury
    /// A warden's skill fired: a ward of pale light closing over the company.
    case ward
    /// A vanguard's: fire thrown out low from the company as it charges.
    case blaze
    /// An outrider's: shafts of light falling about the company.
    case volley
    /// A wallbreaker's: the ground breaking, dust thrown out in a ring.
    case quake
    /// A hold scouted: the Lanterns' cold light circling it slowly, low
    /// over its walls, then gone.
    case sighting
    /// A commander's skill marked on the ground about the company: two
    /// rings and six spokes between them in the skill's own light,
    /// swelling out as they come and turning as they fade together.
    case sigil
    /// A shaft of a skill's light rising over the company into the sky,
    /// thinning as it climbs.
    case pillar
    /// The blackwood burning: tongues of fire licking up from the wood,
    /// rising fast and narrowing, deep orange at the root, yellow as they
    /// thin.
    case flames
    /// A company springing from the wood where it lay in wait: leaves and
    /// twigs thrown up from among the trees, dark green and brown,
    /// fluttering down as the air slows them.
    case leaves

    /// How long each mote lives, in seconds.
    public var lifetime: Float {
        switch self {
        case .sparks: return 0.45
        case .dust: return 1.4
        case .smoke: return 4.2
        case .embers: return 1.7
        case .flash: return 0.28
        case .splinters: return 0.9
        case .fireflies: return 6
        case .fury: return 1.1
        case .ward: return 1.4
        case .blaze: return 0.8
        case .volley: return 0.7
        case .quake: return 1.1
        case .sighting: return 1.8
        case .sigil: return 2.2
        case .pillar: return 1.5
        case .flames: return 0.55
        case .leaves: return 1.6
        }
    }
}

/// Motes thrown up at one moment and place: a blow's sparks, the dust of
/// a fall, a work's last course set.
public struct Burst: Equatable, Sendable {
    public var effect: Effect
    public var origin: Vec3
    /// When, on the frame's clock, in seconds.
    public var start: Float
    public var count: Int
    public var seed: UInt32
    /// How large and how far it throws: 1 as a company's blow.
    public var scale: Float
    /// The hue of a skill's sigil or shaft of light, its brightest part 1.
    public var tint: Vec3

    public init(_ effect: Effect, at origin: Vec3, start: Float, count: Int, seed: UInt32, scale: Float = 1, tint: Vec3 = Vec3(1, 1, 1)) {
        self.effect = effect
        self.origin = origin
        self.start = start
        self.count = count
        self.seed = seed
        self.scale = scale
        self.tint = tint
    }

    /// Whether any of it is still to be seen at `time`.
    public func isAlive(at time: Float) -> Bool {
        time >= start && time - start < effect.lifetime * (1 + 0.35)
    }
}

/// A steady source of motes: a burning hold's smoke and embers, a march's
/// dust, the fireflies over a reed bed.
public struct Emitter: Equatable, Sendable {
    public var effect: Effect
    public var origin: Vec3
    /// Motes a second.
    public var rate: Float
    /// How far from the origin they rise.
    public var spread: Float
    public var seed: UInt32
    /// How strongly: a fire's height, a dust cloud's thickness.
    public var strength: Float
    /// How the air carries its smoke and embers: nil, the night's own slow
    /// air as ever; otherwise the way and strength the watch's wind bears
    /// them on the ground, zero where none blows and they rise straight.
    public var drift: Vec3?

    public init(_ effect: Effect, at origin: Vec3, rate: Float, spread: Float = 0.1, seed: UInt32, strength: Float = 1, drift: Vec3? = nil) {
        self.effect = effect
        self.origin = origin
        self.rate = rate
        self.spread = spread
        self.seed = seed
        self.strength = strength
        self.drift = drift
    }
}

/// The motes of a frame, worked out afresh from what threw them up and
/// how long ago: nothing is kept from frame to frame, so a moment drawn
/// twice is drawn alike, and a frame skipped is no loss.
public enum Effects {
    /// No more than this many in a frame: the oldest emitters' last motes go first.
    public static let most = 4_000
    /// How the night's own slow air leans smoke when no wind is told.
    public static let nightAir = Vec3(0.09, 0, -0.05)

    /// Every mote alive at `time`.
    public static func motes(bursts: [Burst], emitters: [Emitter], at time: Float) -> [Mote] {
        var motes: [Mote] = []
        for burst in bursts where burst.isAlive(at: time) {
            for index in 0..<burst.count {
                if let mote = mote(burst.effect, index: UInt32(index), seed: burst.seed, origin: burst.origin,
                                   age: time - burst.start, scale: burst.scale, tint: burst.tint) {
                    motes.append(mote)
                }
            }
        }
        for emitter in emitters where emitter.rate > 0 {
            let life = emitter.effect.lifetime
            // The motes born in the last lifetime, each at its own moment.
            let first = Int(((time - life) * emitter.rate).rounded(.up))
            let last = Int((time * emitter.rate).rounded(.down))
            guard last >= first else { continue }
            for born in first...last {
                let birth = Float(born) / emitter.rate
                let seed = emitter.seed &+ UInt32(truncatingIfNeeded: born) &* 0x9E37_79B9
                let spot = Vec3(unit(seed, 1) * 2 - 1, 0, unit(seed, 2) * 2 - 1) * emitter.spread
                if let mote = mote(emitter.effect, index: 0, seed: seed, origin: emitter.origin + spot, age: time - birth,
                                   scale: emitter.strength, drift: emitter.drift) {
                    motes.append(mote)
                }
            }
            if motes.count >= most { break }
        }
        return Array(motes.prefix(most))
    }

    /// One mote of an effect, `age` seconds after it was thrown, or nil if
    /// it is not yet, or no longer, to be seen.
    static func mote(_ effect: Effect, index: UInt32, seed: UInt32, origin: Vec3, age: Float, scale: Float,
                     tint: Vec3 = Vec3(1, 1, 1), drift: Vec3? = nil) -> Mote? {
        // Each mote lives a little more or less than its kind; a sigil's
        // fade together.
        let life = effect == .sigil ? effect.lifetime : effect.lifetime * (0.65 + 0.7 * unit(seed &+ index, 3))
        guard age >= 0, age < life else { return nil }
        let t = age / life
        let a = unit(seed &+ index, 5), b = unit(seed &+ index, 7), c = unit(seed &+ index, 11)
        let angle = a * 2 * .pi
        let around = Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle))))
        switch effect {
        case .sparks:
            // Thrown out and up, then falling.
            let speed = (1.6 + 1.6 * b) * scale
            let velocity = around * speed + Vec3(0, (0.8 + 1.4 * c) * scale, 0)
            let at = origin + velocity * age + Vec3(0, -4.5 * age * age, 0)
            let heat = (1 - t) * (1 - t)
            return Mote(at: at, size: 0.022 * scale * (1 - 0.5 * t), light: Vec3(2.6, 1.7, 0.75) * heat, cover: 0)
        case .dust:
            // Rolling out low, slowing, rising a little, thinning.
            let reach = (0.25 + 0.45 * b) * scale * (1 - Float(exp(-Double(age) * 2.6)))
            let at = origin + around * reach + Vec3(0, 0.05 + 0.18 * c * scale * t, 0)
            let show = 0.42 * (1 - t) * min(age * 8, 1)
            return Mote(at: at, size: (0.07 + 0.16 * t) * scale, light: Vec3(0.050, 0.044, 0.036) * show, cover: show)
        case .smoke:
            // Rising and leaning with the night's air, or borne on the
            // watch's wind, spreading as it goes.
            let rise = (0.32 + 0.18 * b) * age * scale
            let lean = (drift ?? Effects.nightAir) * age * age
            let curl = around * (0.05 + 0.08 * t) * scale
            let show = 0.6 * Float(sin(Double(t) * .pi)) * (0.6 + 0.4 * c)
            // Lit from below by its fire while it is low.
            let glow = Vec3(0.09, 0.045, 0.018) * max(0, 1 - t * 3)
            return Mote(at: origin + Vec3(0, rise, 0) + lean + curl, size: (0.1 + 0.36 * t) * scale,
                        light: (Vec3(0.03, 0.028, 0.03) + glow) * show, cover: show)
        case .embers:
            // Points rising unevenly from a fire, winking as they go out.
            let rise = (0.45 + 0.5 * b) * age * scale
            let sway = around * 0.12 * Float(sin(Double(age * (3 + 4 * c))))
            let wink = 0.55 + 0.45 * Float(sin(Double(age * (17 + 13 * a))))
            let heat = (1 - t) * wink
            // Borne off on the watch's wind, where one blows.
            let carried = (drift ?? Vec3(0, 0, 0)) * (0.6 * age * age)
            return Mote(at: origin + Vec3(0, rise, 0) + sway + carried, size: 0.016 * scale, light: Vec3(2.2, 0.95, 0.28) * heat, cover: 0)
        case .flash:
            // One swell of light where the blow lands, quick to come and go.
            let swell = Float(sin(Double(min(t, 1)) * .pi))
            return Mote(at: origin + Vec3(0, 0.06 * scale, 0), size: (0.09 + 0.1 * t) * scale,
                        light: Vec3(1.5, 1.05, 0.6) * swell * 0.55, cover: 0)
        case .splinters:
            // Chips of stone and timber knocked from a ward, thrown and falling.
            let speed = (0.8 + 1.1 * b) * scale
            let velocity = around * speed + Vec3(0, (1.1 + 1.2 * c) * scale, 0)
            var at = origin + velocity * age + Vec3(0, -5.5 * age * age, 0)
            at.y = max(at.y, origin.y - 0.02)
            let show = 0.9 * (1 - t * t)
            return Mote(at: at, size: 0.03 * scale, light: Vec3(0.055, 0.052, 0.05) * show, cover: show)
        case .leaves:
            // Thrown up and out from among the trees, slowed by the air as
            // they rise, then fluttering down, swaying as they fall; never
            // through the ground beneath the wood.
            let speed = (0.4 + 0.8 * b) * scale
            let thrown = around * speed + Vec3(0, (1.0 + 0.9 * c) * scale, 0)
            let slowed = (1 - Float(exp(-Double(age) * 2.4))) / 2.4
            let sway = Vec3(Float(sin(Double(age * (6 + 5 * a)))), 0, Float(cos(Double(age * (5 + 4 * b))))) * (0.05 * scale * t)
            var at = origin + thrown * slowed + Vec3(0, -0.5 * age * age, 0) + sway
            at.y = max(at.y, origin.y - 0.3)
            let show = 0.95 * (1 - t * t) * min(age * 12, 1)
            // Dark green and brown by turns, as the wood's own leaves.
            let leaf = c < 0.55 ? Vec3(0.020, 0.036, 0.016) : Vec3(0.036, 0.027, 0.014)
            return Mote(at: at, size: (0.02 + 0.016 * b) * scale, light: leaf * show, cover: show)
        case .fireflies:
            // Wandering over the reeds in slow loops, blinking on and off.
            let east: Float = Float(sin(Double(age * (0.6 + 0.5 * a) + Float(index)))) * 0.35
            let up: Float = 0.25 + 0.12 * Float(sin(Double(age * (0.9 + b))))
            let south: Float = Float(cos(Double(age * (0.5 + 0.4 * b) + 2 * a))) * 0.35
            let wander = Vec3(east, up, south) * scale
            let phase = Double(age * (1.1 + 1.3 * c)) + Double(a) * 6
            let blink = Float(pow(max(0, sin(phase)), 6))
            let show = blink * Float(sin(Double(t) * .pi))
            return Mote(at: origin + wander, size: 0.014, light: Vec3(0.75, 1.3, 0.45) * show, cover: 0)
        case .fury:
            // A ring of pale gold round the company, rising and widening as it fades.
            let ring = (0.25 + 0.55 * t) * scale
            let rise = (0.08 + 0.9 * t * (0.6 + 0.4 * b)) * scale
            let show = Float(sin(Double(t) * .pi)) * (0.7 + 0.3 * c)
            return Mote(at: origin + around * ring + Vec3(0, rise, 0), size: (0.024 + 0.02 * t) * scale,
                        light: Vec3(2.0, 1.75, 0.95) * show, cover: 0)
        case .ward:
            // Points of pale light on a dome over the company, swelling a
            // little as they come and go.
            let rise = Double(b) * .pi / 2 * 0.95
            let shell = Vec3(Float(cos(rise)) * around.x, Float(sin(rise)), Float(cos(rise)) * around.z) * (0.52 + 0.1 * t) * scale
            let show = Float(sin(Double(t) * .pi)) * (0.6 + 0.4 * c)
            return Mote(at: origin + shell + Vec3(0, 0.02, 0), size: 0.02 * scale, light: Vec3(0.9, 1.3, 2.1) * show, cover: 0)
        case .flames:
            // Licking up fast from the wood and narrowing as it climbs, deep
            // orange at the root and yellow as it thins, swaying as it goes.
            let rise = (0.16 + 0.34 * b) * t * scale
            let sway = around * (0.03 * Float(sin(Double(age * (9 + 7 * c))))) * scale
            let heat = min(age * 24, 1) * (1 - t)
            return Mote(at: origin + Vec3(0, rise, 0) + sway, size: (0.055 - 0.035 * t) * scale,
                        light: Vec3(2.6, 0.85 + 0.75 * t, 0.22) * heat, cover: 0)
        case .blaze:
            // Fire thrown out low from the company, slowing, rising a little, burning out.
            let reach = (0.3 + 0.7 * b) * scale * (1 - Float(exp(-Double(age) * 4)))
            let heat = (1 - t) * (1 - t * 0.5)
            return Mote(at: origin + around * reach + Vec3(0, (0.05 + 0.35 * c * t) * scale, 0), size: (0.018 + 0.022 * t) * scale,
                        light: Vec3(2.8, 1.1, 0.3) * heat, cover: 0)
        case .volley:
            // Shafts of light falling from on high about the company, each to the ground.
            let high = (1.2 + 0.6 * b) * scale
            let spot = around * (0.15 + 0.55 * c) * scale
            let show = t < 0.85 ? Float(1) : (1 - t) / 0.15
            return Mote(at: origin + spot + Vec3(0, high * (1 - t), 0), size: 0.018 * scale, light: Vec3(2.2, 1.9, 1.2) * show, cover: 0)
        case .quake:
            // The ground broken in a ring that runs out fast, dust thrown up and settling.
            let ring = (0.2 + 1.3 * Float(pow(Double(t), 0.6))) * scale
            let up = (0.03 + 0.12 * c * Float(sin(Double(t) * .pi))) * scale
            let show = 0.5 * (1 - t)
            return Mote(at: origin + around * ring + Vec3(0, up, 0), size: (0.06 + 0.12 * t) * scale,
                        light: Vec3(0.06, 0.05, 0.04) * show, cover: show)
        case .sighting:
            // Points of cold light going round the hold a third of the way,
            // low over its walls, waxing and waning as they pass.
            let turn = Double(angle) + Double(t) * 2.1 * (b > 0.5 ? 1 : -1)
            let path = Vec3(Float(cos(turn)), 0, Float(sin(turn))) * (0.55 + 0.15 * c) * scale
            let bob = Float(sin(Double(age) * 5 + Double(a) * 6)) * 0.03 * scale
            let show = Float(sin(Double(t) * .pi)) * (0.6 + 0.4 * c)
            return Mote(at: origin + path + Vec3(0, (0.22 + 0.12 * b) * scale + bob, 0), size: 0.02 * scale,
                        light: Vec3(0.9, 1.25, 1.9) * show, cover: 0)
        case .sigil:
            // Half on the outer ring, a quarter on the inner turning the
            // other way, a quarter on the spokes between.
            let swell = min(t / 0.12, 1)
            let spin = age * 0.4
            let radius: Float, turn: Float
            switch index % 4 {
            case 0, 1: (radius, turn) = (1, a * 2 * .pi + spin)
            case 2: (radius, turn) = (Effects.sigilInner, a * 2 * .pi - spin)
            default: (radius, turn) = (Effects.sigilInner + (1 - Effects.sigilInner) * b, Float(Int(a * 6)) * .pi / 3 + .pi / 6 + spin)
            }
            let way = Vec3(Float(cos(Double(turn))), 0, Float(sin(Double(turn))))
            let shimmer = 0.75 + 0.25 * Float(sin(Double(age * 9 + a * 20)))
            return Mote(at: origin + way * (radius * scale * (0.7 + 0.3 * swell)) + Vec3(0, Effects.sigilLift, 0), size: 0.03 * scale,
                        light: tint * (1.5 * swell * (1 - t) * shimmer), cover: 0)
        case .pillar:
            let up = (b + age * 0.7).truncatingRemainder(dividingBy: 1)
            let show = Float(sin(Double(t) * .pi)) * (1 - up)
            return Mote(at: origin + around * (0.13 * scale * (1 - 0.6 * up) * c) + Vec3(0, 2.4 * scale * up, 0), size: 0.028 * scale,
                        light: tint * (1.8 * show), cover: 0)
        }
    }

    /// Where a sigil's inner ring lies, as a share of its outer.
    public static let sigilInner: Float = 0.62
    /// How high over the ground a sigil is laid.
    public static let sigilLift: Float = 0.04

    /// A steady number from 0 up to 1 for a seed and a salt.
    static func unit(_ seed: UInt32, _ salt: UInt32) -> Float {
        var x = seed &* 0x85EB_CA6B ^ salt &* 0xC2B2_AE35
        x ^= x >> 16
        x = x &* 0x7FEB_352D
        x ^= x >> 15
        x = x &* 0x846C_A68B
        x ^= x >> 16
        return Float(x >> 8) / Float(1 << 24)
    }
}

/// A light of the world's own, beside the moon's: a fire burning, a blow
/// landing. The land and the models it falls on take it up.
public struct PointLight: Equatable, Sendable {
    public var position: Vec3
    /// How far it reaches, in world units.
    public var reach: Float
    /// Its colour, linear, times its strength.
    public var colour: Vec3

    public init(at position: Vec3, reach: Float, colour: Vec3) {
        self.position = position
        self.reach = reach
        self.colour = colour
    }

    /// The four the frame lights with: the strongest near the eye's mark.
    public static func strongest(_ lights: [PointLight], near focus: Vec3, count: Int = FrameUniforms.lightSlots) -> [PointLight] {
        func weight(_ light: PointLight) -> Float {
            let strength = max(light.colour.x, max(light.colour.y, light.colour.z)) * light.reach
            let away = (light.position - focus).length
            return strength / (1 + away * away * 0.02)
        }
        return Array(lights.filter { weight($0) > 0 }.sorted { weight($0) > weight($1) }.prefix(count))
    }
}

/// What happens in sight that throws up motes or gives light, each where
/// and when on the frame's clock; the stage turns them into the frame's
/// motes and lights.
public struct Happenings: Equatable, Sendable {
    /// A blow struck: from where, at where, when it began, and how.
    public struct Strike: Equatable, Sendable {
        public var from: Vec3
        public var at: Vec3
        public var start: Float
        public var ranged: Bool
        /// It fell on a hold's ward rather than on a company.
        public var onWard: Bool
        public var seed: UInt32

        public init(from: Vec3, at: Vec3, start: Float, ranged: Bool, onWard: Bool = false, seed: UInt32) {
            self.from = from
            self.at = at
            self.start = start
            self.ranged = ranged
            self.onWard = onWard
            self.seed = seed
        }
    }

    /// Something that throws up motes from one place, from a moment on or
    /// steadily: a company falling, a march, a work rising or finished, a
    /// hold burning.
    public struct Spot: Equatable, Sendable {
        public var at: Vec3
        /// When, for what happens once; how strongly, for what goes on.
        public var start: Float
        public var strength: Float
        public var seed: UInt32

        public init(at: Vec3, start: Float = 0, strength: Float = 1, seed: UInt32) {
            self.at = at
            self.start = start
            self.strength = strength
            self.seed = seed
        }
    }

    public var strikes: [Strike] = []
    public var falls: [Spot] = []
    public var marching: [Spot] = []
    public var rising: [Spot] = []
    public var finished: [Spot] = []
    /// Holds burning, as strongly as their wards are broken.
    public var blazes: [Spot] = []
    /// The blackwood burning (`Wildfire`): a few spots to each tile
    /// alight, each its own fire among the trees.
    public var woodFires: [Spot] = []
    /// Blackwood that has just caught alight, the fire leaping to it as the
    /// watch turned: when, and where; a tongue of flame flares up from it,
    /// embers flying, and its light flashes over the wood a moment.
    public var catching: [Spot] = []
    /// Watchfires burning (`Watchfire`), each at the top of its brazier: a
    /// tall flame, embers and a thread of smoke, and its light on the
    /// ground about it.
    public var watchfires: [Spot] = []
    /// How far a watchfire's light reaches on the ground: about the two
    /// tiles its House sees by it.
    public static let watchfireReach: Float = 3.2
    /// How the air bears the smoke and embers of what burns: nil, the
    /// night's own slow air, where the watch's wind is not told; zero on a
    /// still night, the smoke rising straight; otherwise the wind's way on
    /// the ground (`WorldStage.windward`) at its strength
    /// (`Happenings.windCarries`), so the smoke shows where a fire will run.
    public var air: Vec3?
    /// Where the night's fireflies wander.
    public var fireflies: [Spot] = []
    /// Where commanders' skills fired, when, and how each looks.
    public var furies: [Fury] = []
    /// Companies springing from the wood where they lay in wait: leaves
    /// and twigs thrown up from among the trees, and the dust of the rush.
    public var springs: [Spot] = []

    /// A commander's skill fired: where, when, and how it looks.
    public struct Fury: Equatable, Sendable {
        public var at: Vec3
        public var start: Float
        public var look: FuryLook
        public var seed: UInt32

        public init(at: Vec3, start: Float, look: FuryLook = .ring, seed: UInt32) {
            self.at = at
            self.start = start
            self.look = look
            self.seed = seed
        }
    }
    /// Holds scouted, and when.
    public var sightings: [Spot] = []
    /// Fields of battle going on, as strongly as companies stand in them.
    public var battles: [Spot] = []
    /// Where two throngs meet in a field of battle: steel flashing and
    /// sparks thrown all along it, the faster the more troops are there.
    public var fronts: [Front] = []
    public struct Front: Equatable, Sendable {
        public var from: Vec3
        public var to: Vec3
        /// 1 for a front of two companies' worth; more for greater throngs.
        public var strength: Float
        public var seed: UInt32
        public init(from: Vec3, to: Vec3, strength: Float = 1, seed: UInt32) {
            self.from = from
            self.to = to
            self.strength = strength
            self.seed = seed
        }
    }
    /// How often each front throws a clash of steel, in seconds.
    public static let clashEvery: Float = 0.22
    /// How far before or behind the line where two throngs meet a clash
    /// falls, as a share of the way between the two companies' hearts;
    /// and how far along that line either side of its middle, in the
    /// world's units: across most of a company's front.
    public static let clashAlong: Float = 0.12
    public static let clashAcross: Float = 0.45
    /// How strongly the watch's wind bears smoke off, a unit a second each
    /// second: a plume leaning well over, three tiles downwind before it is
    /// gone, against the night's own air, a third as strong.
    public static let windCarries: Float = 0.2
    /// How tall the flame that leaps up from wood as it catches stands,
    /// against a fire's own among the trees; and how long its light lasts.
    public static let flare: Float = 2.2
    public static let flareLight: Float = 1.2
    /// Where a struck throng's ranks take the foe's blows, beat on beat, in
    /// time with their figures reeling (`Clip.hit`): steel on shields and
    /// mail, dust kicked from the staggering feet, timber split from an
    /// engine's frame.
    public var impacts: [Impact] = []
    public struct Impact: Equatable, Sendable {
        /// At the struck company's front.
        public var at: Vec3
        /// Moments, on the effects' clock, when a blow lands, every `every` seconds.
        public var phase: Float
        public var every: Float
        /// Its frame is timber: splinters, not sparks.
        public var timber: Bool
        public var seed: UInt32
        public init(at: Vec3, phase: Float, every: Float, timber: Bool = false, seed: UInt32) {
            self.at = at
            self.phase = phase
            self.every = every
            self.timber = timber
            self.seed = seed
        }
    }
    /// How far into a hit's beat its blow lands: where the recoil peaks.
    public static let impactAt: Float = 0.1

    public init() {}

    /// When a blow lands after it begins, in seconds: a thrust's reach, or
    /// an arrow's flight.
    public static let landing: Float = 0.14
    public static let arrowFlight: Float = 0.38
    /// When a falling company meets the ground.
    public static let fallen: Float = 0.85
    /// How high among the trees the leaves of a company springing from the
    /// wood are thrown from: about the height of the boughs.
    public static let springLeaves: Float = 0.3
    /// How long a commander's fury lights the ground.
    public static let furyGlow: Float = 0.9
    /// How far out a skill's sigil reaches about its company.
    public static let sigilReach: Float = 1.15
    /// How long a scouted hold is lit by its Lanterns' light.
    public static let sightingGlow: Float = 1.6

    /// The frame's motes and its own lights at `time`.
    /// What happens in sight as motes and light at a moment, leaving out
    /// the kinds of mote asked (a film shot of the world leaves out what
    /// would read as a mark laid over it, as a skill's ring or a blow's
    /// flash can). `fireLight`, from 0 to 1, is how much of their own light
    /// the fires in the blackwood and the watchfires cast on the ground:
    /// from afar their glow stands for them (`WorldStage.fireGlows`), and
    /// their light there would only take the frame's few lights from the
    /// lanterns, boats and works in view (`WorldStage.fireLight(at:)`).
    public func effects(at time: Float, leaving omitted: Set<Effect> = [], fireLight: Float = 1) -> (motes: [Mote], lights: [PointLight]) {
        var bursts: [Burst] = []
        var emitters: [Emitter] = []
        var lights: [PointLight] = []
        for strike in strikes {
            if strike.ranged {
                // Dust where the arrows come down about the mark.
                for shaft in 0..<3 {
                    let spot = strike.at + Vec3(0.2 * Effects.unit(strike.seed, UInt32(shaft)) - 0.1, 0,
                                                0.2 * Effects.unit(strike.seed, UInt32(shaft) + 9) - 0.1)
                    bursts.append(Burst(.dust, at: spot, start: strike.start + Happenings.arrowFlight + Float(shaft) * 0.05, count: 4,
                                        seed: strike.seed &+ UInt32(shaft), scale: 0.45))
                }
                continue
            }
            let landed = strike.start + Happenings.landing
            // Where steel meets: at the struck one's front, toward the striker.
            let toward = (strike.from - strike.at)
            let reach = Vec3(toward.x, 0, toward.z).normalized * 0.32
            let contact = strike.at + reach + Vec3(0, 0.16, 0)
            bursts.append(Burst(.flash, at: contact, start: landed, count: 1, seed: strike.seed))
            if strike.onWard {
                bursts.append(Burst(.splinters, at: contact, start: landed, count: 16, seed: strike.seed &+ 1, scale: 1.1))
                bursts.append(Burst(.dust, at: strike.at, start: landed, count: 12, seed: strike.seed &+ 2, scale: 1.4))
            } else {
                bursts.append(Burst(.sparks, at: contact, start: landed, count: 14, seed: strike.seed &+ 1))
                bursts.append(Burst(.dust, at: strike.at + reach, start: landed, count: 8, seed: strike.seed &+ 2, scale: 0.8))
            }
            // The blow lights the ground round it a moment.
            let age = time - landed
            if age >= 0, age < 0.35 {
                let fade = 1 - age / 0.35
                lights.append(PointLight(at: contact + Vec3(0, 0.2, 0), reach: 2.2, colour: Vec3(2.4, 1.7, 0.9) * fade * fade))
            }
        }
        for fall in falls {
            bursts.append(Burst(.dust, at: fall.at, start: fall.start + Happenings.fallen, count: 10, seed: fall.seed, scale: 0.9))
        }
        for spring in springs {
            bursts.append(Burst(.leaves, at: spring.at + Vec3(0, Happenings.springLeaves, 0), start: spring.start, count: 40,
                                seed: spring.seed, scale: 1.1))
            bursts.append(Burst(.dust, at: spring.at, start: spring.start + 0.05, count: 10, seed: spring.seed &+ 1, scale: 1.1))
        }
        for march in marching {
            emitters.append(Emitter(.dust, at: march.at, rate: 9 * march.strength, spread: 0.22, seed: march.seed, strength: 0.6))
        }
        for work in rising {
            emitters.append(Emitter(.dust, at: work.at, rate: 2, spread: 0.16, seed: work.seed, strength: 0.55))
        }
        for front in fronts {
            // Clash on clash where the two throngs meet, midway between
            // them (`WorldStage.pressWay`): each a little before or behind
            // the line, at its own place along it; and the glint of steel.
            let beat = Int(time / Happenings.clashEvery)
            let along = front.to - front.from
            let side = Vec3(-along.z, 0, along.x).normalized
            let clashes = max(1, min(4, Int(front.strength.rounded())))
            for back in 0...2 {
                for clash in 0..<clashes {
                    let n = UInt32(truncatingIfNeeded: beat - back) &* 31 &+ UInt32(clash)
                    let u = Effects.unit(front.seed &+ n, 1) - 0.5, v = Effects.unit(front.seed &+ n, 2) - 0.5
                    let at = front.from + along * (0.5 + u * 2 * Happenings.clashAlong) + side * (v * 2 * Happenings.clashAcross)
                        + Vec3(0, 0.12, 0)
                    let start = Float(beat - back) * Happenings.clashEvery + Effects.unit(front.seed &+ n, 3) * Happenings.clashEvery
                    bursts.append(Burst(.flash, at: at, start: start, count: 1, seed: front.seed &+ n))
                    bursts.append(Burst(.sparks, at: at, start: start, count: 5, seed: front.seed &+ n &+ 5, scale: 0.7))
                }
            }
            let middle = (front.from + front.to) * 0.5 + Vec3(0, 0.25, 0)
            let glint = 0.6 + 0.4 * Float(sin(Double(time * 17 + Float(front.seed % 89))))
            lights.append(PointLight(at: middle, reach: 1.4, colour: Vec3(0.55, 0.6, 0.75) * glint * min(front.strength, 2)))
        }
        for impact in impacts {
            // The blow before this one and this one, each where it landed.
            let beat = ((time - impact.phase) / impact.every).rounded(.down)
            for back in 0...1 {
                let n = UInt32(truncatingIfNeeded: Int(beat) - back)
                let start = (beat - Float(back)) * impact.every + impact.phase
                let seed = impact.seed &* 2_654_435_761 &+ n &* 97
                let jitter = Vec3(0.16 * Effects.unit(seed, 1) - 0.08, 0, 0.16 * Effects.unit(seed, 2) - 0.08)
                let at = impact.at + jitter + Vec3(0, 0.1, 0)
                bursts.append(Burst(.flash, at: at, start: start, count: 1, seed: seed, scale: 0.6))
                bursts.append(Burst(impact.timber ? .splinters : .sparks, at: at, start: start, count: impact.timber ? 9 : 7, seed: seed &+ 1,
                                    scale: 0.75))
                bursts.append(Burst(.dust, at: impact.at + jitter, start: start, count: 4, seed: seed &+ 2, scale: 0.55))
            }
        }
        for battle in battles {
            // The dust a battle throws up over its whole field, the thicker
            // the more companies stand in it.
            emitters.append(Emitter(.dust, at: battle.at, rate: 4 + 2 * battle.strength, spread: 0.8, seed: battle.seed, strength: 0.65))
        }
        for work in finished {
            bursts.append(Burst(.dust, at: work.at, start: work.start, count: 20, seed: work.seed, scale: 1.25))
        }
        for blaze in blazes {
            let top = blaze.at + Vec3(0, 0.75, 0)
            emitters.append(Emitter(.embers, at: top, rate: 16 * blaze.strength, spread: 0.18, seed: blaze.seed, strength: 1, drift: air))
            emitters.append(Emitter(.smoke, at: top + Vec3(0, 0.1, 0), rate: 5 * blaze.strength, spread: 0.14, seed: blaze.seed &+ 7,
                                    strength: 0.8 + 0.6 * blaze.strength, drift: air))
            // Firelight, flickering.
            let flicker = 0.75 + 0.25 * Float(sin(Double(time * 11 + Float(blaze.seed % 97)))) * Float(sin(Double(time * 7.3)))
            lights.append(PointLight(at: top, reach: 2.6, colour: Vec3(2.2, 1.0, 0.35) * blaze.strength * flicker))
        }
        for fire in woodFires {
            // Flames licking up among the trees, embers flying from them and
            // smoke rolling up over all, the firelight flickering on the wood.
            emitters.append(Emitter(.flames, at: fire.at + Vec3(0, 0.03, 0), rate: 30 * fire.strength, spread: 0.2, seed: fire.seed,
                                    strength: 1))
            emitters.append(Emitter(.embers, at: fire.at + Vec3(0, 0.3, 0), rate: 9 * fire.strength, spread: 0.22, seed: fire.seed &+ 3,
                                    strength: 1, drift: air))
            emitters.append(Emitter(.smoke, at: fire.at + Vec3(0, 0.42, 0), rate: 4 * fire.strength, spread: 0.26, seed: fire.seed &+ 7,
                                    strength: 1.2, drift: air))
            let flicker = 0.7 + 0.3 * Float(sin(Double(time * 13 + Float(fire.seed % 89)))) * Float(sin(Double(time * 5.1 + 1)))
            if fireLight > 0 {
                lights.append(PointLight(at: fire.at + Vec3(0, 0.3, 0), reach: 2.0,
                                         colour: Vec3(2.4, 0.95, 0.28) * fire.strength * flicker * fireLight))
            }
        }
        for fire in watchfires {
            // A tall flame in the brazier, embers and a thread of smoke going
            // up, and its light over the ground the watch keeps.
            emitters.append(Emitter(.flames, at: fire.at, rate: 22 * fire.strength, spread: 0.06, seed: fire.seed, strength: 1))
            emitters.append(Emitter(.embers, at: fire.at + Vec3(0, 0.2, 0), rate: 6 * fire.strength, spread: 0.08, seed: fire.seed &+ 3,
                                    strength: 1, drift: air))
            emitters.append(Emitter(.smoke, at: fire.at + Vec3(0, 0.32, 0), rate: 2 * fire.strength, spread: 0.08, seed: fire.seed &+ 7,
                                    strength: 0.8, drift: air))
            let flicker = 0.8 + 0.2 * Float(sin(Double(time * 12 + Float(fire.seed % 83)))) * Float(sin(Double(time * 4.7 + 2)))
            if fireLight > 0 {
                lights.append(PointLight(at: fire.at + Vec3(0, 0.2, 0), reach: Happenings.watchfireReach,
                                         colour: Vec3(2.3, 1.05, 0.34) * fire.strength * flicker * fireLight))
            }
        }
        for caught in catching {
            bursts.append(Burst(.flames, at: caught.at + Vec3(0, 0.05, 0), start: caught.start, count: 48, seed: caught.seed,
                                scale: Happenings.flare))
            bursts.append(Burst(.embers, at: caught.at + Vec3(0, 0.25, 0), start: caught.start, count: 28, seed: caught.seed &+ 1,
                                scale: 1.4))
            bursts.append(Burst(.flash, at: caught.at + Vec3(0, 0.3, 0), start: caught.start, count: 1, seed: caught.seed &+ 2,
                                scale: 1.8))
            let age = time - caught.start
            if age >= 0, age < Happenings.flareLight, fireLight > 0 {
                lights.append(PointLight(at: caught.at + Vec3(0, 0.4, 0), reach: 2.6,
                                         colour: Vec3(2.8, 1.2, 0.35) * (1 - age / Happenings.flareLight) * fireLight))
            }
        }
        for spot in fireflies {
            emitters.append(Emitter(.fireflies, at: spot.at, rate: 0.6, spread: 0.3, seed: spot.seed, strength: 1))
        }
        for fury in furies {
            // Each archetype's skill its own, as wide as its company: its
            // sigil laid on the ground about it in its light; then a ring
            // of gold under a shaft of light, a ward of light under one,
            // fire thrown out and its embers flying, light falling, the
            // ground breaking; and its light a moment on the ground.
            let glow = fury.look.glow, hue = glow / max(glow.x, max(glow.y, glow.z))
            bursts.append(Burst(.sigil, at: fury.at, start: fury.start, count: 120, seed: fury.seed &+ 11, scale: Happenings.sigilReach,
                                tint: hue))
            switch fury.look {
            case .ring:
                bursts.append(Burst(.fury, at: fury.at + Vec3(0, 0.05, 0), start: fury.start, count: 64, seed: fury.seed, scale: 1.7))
                bursts.append(Burst(.pillar, at: fury.at, start: fury.start, count: 56, seed: fury.seed &+ 13, tint: hue))
                bursts.append(Burst(.flash, at: fury.at + Vec3(0, 0.45, 0), start: fury.start, count: 1, seed: fury.seed &+ 3, scale: 2.6))
            case .ward:
                bursts.append(Burst(.ward, at: fury.at, start: fury.start, count: 96, seed: fury.seed, scale: 1.5))
                bursts.append(Burst(.pillar, at: fury.at, start: fury.start, count: 56, seed: fury.seed &+ 13, tint: hue))
            case .blaze:
                bursts.append(Burst(.blaze, at: fury.at + Vec3(0, 0.05, 0), start: fury.start, count: 96, seed: fury.seed, scale: 1.8))
                bursts.append(Burst(.embers, at: fury.at + Vec3(0, 0.1, 0), start: fury.start, count: 48, seed: fury.seed &+ 5, scale: 1.6))
                bursts.append(Burst(.flash, at: fury.at + Vec3(0, 0.3, 0), start: fury.start, count: 1, seed: fury.seed &+ 3, scale: 2.4))
            case .volley:
                bursts.append(Burst(.volley, at: fury.at, start: fury.start, count: 96, seed: fury.seed, scale: 1.6))
            case .quake:
                bursts.append(Burst(.quake, at: fury.at, start: fury.start, count: 80, seed: fury.seed, scale: 1.8))
                bursts.append(Burst(.splinters, at: fury.at, start: fury.start, count: 40, seed: fury.seed &+ 5, scale: 1.6))
                bursts.append(Burst(.dust, at: fury.at, start: fury.start, count: 30, seed: fury.seed &+ 7, scale: 2))
            }
            let age = time - fury.start
            if age >= 0, age < Happenings.furyGlow {
                let fade = 1 - age / Happenings.furyGlow
                lights.append(PointLight(at: fury.at + Vec3(0, 0.6, 0), reach: 4.2, colour: fury.look.glow * fade))
            }
        }
        for sighting in sightings {
            // Lanterns' light circling the hold, and a cold glow over it while they look.
            bursts.append(Burst(.sighting, at: sighting.at, start: sighting.start, count: 18, seed: sighting.seed, scale: 1))
            let age = time - sighting.start
            if age >= 0, age < Happenings.sightingGlow {
                let swell = Float(sin(Double(age / Happenings.sightingGlow) * .pi))
                lights.append(PointLight(at: sighting.at + Vec3(0, 0.5, 0), reach: 2.2, colour: Vec3(0.55, 0.8, 1.4) * swell))
            }
        }
        guard !omitted.isEmpty else { return (Effects.motes(bursts: bursts, emitters: emitters, at: time), lights) }
        return (Effects.motes(bursts: bursts.filter { !omitted.contains($0.effect) }, emitters: emitters.filter { !omitted.contains($0.effect) },
                              at: time), lights)
    }
}
