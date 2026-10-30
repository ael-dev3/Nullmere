import Foundation
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

    public init(_ effect: Effect, at origin: Vec3, start: Float, count: Int, seed: UInt32, scale: Float = 1) {
        self.effect = effect
        self.origin = origin
        self.start = start
        self.count = count
        self.seed = seed
        self.scale = scale
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

    public init(_ effect: Effect, at origin: Vec3, rate: Float, spread: Float = 0.1, seed: UInt32, strength: Float = 1) {
        self.effect = effect
        self.origin = origin
        self.rate = rate
        self.spread = spread
        self.seed = seed
        self.strength = strength
    }
}

/// The motes of a frame, worked out afresh from what threw them up and
/// how long ago: nothing is kept from frame to frame, so a moment drawn
/// twice is drawn alike, and a frame skipped is no loss.
public enum Effects {
    /// No more than this many in a frame: the oldest emitters' last motes go first.
    public static let most = 4_000

    /// Every mote alive at `time`.
    public static func motes(bursts: [Burst], emitters: [Emitter], at time: Float) -> [Mote] {
        var motes: [Mote] = []
        for burst in bursts where burst.isAlive(at: time) {
            for index in 0..<burst.count {
                if let mote = mote(burst.effect, index: UInt32(index), seed: burst.seed, origin: burst.origin,
                                   age: time - burst.start, scale: burst.scale) {
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
                                   scale: emitter.strength) {
                    motes.append(mote)
                }
            }
            if motes.count >= most { break }
        }
        return Array(motes.prefix(most))
    }

    /// One mote of an effect, `age` seconds after it was thrown, or nil if
    /// it is not yet, or no longer, to be seen.
    static func mote(_ effect: Effect, index: UInt32, seed: UInt32, origin: Vec3, age: Float, scale: Float) -> Mote? {
        // Each mote lives a little more or less than its kind.
        let life = effect.lifetime * (0.65 + 0.7 * unit(seed &+ index, 3))
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
            // Rising and leaning with the night's air, spreading as it goes.
            let rise = (0.32 + 0.18 * b) * age * scale
            let lean = Vec3(0.09, 0, -0.05) * age * age
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
            return Mote(at: origin + Vec3(0, rise, 0) + sway, size: 0.016 * scale, light: Vec3(2.2, 0.95, 0.28) * heat, cover: 0)
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
        }
    }

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
    /// Where the night's fireflies wander.
    public var fireflies: [Spot] = []
    /// Where commanders' skills fired, and when.
    public var furies: [Spot] = []

    public init() {}

    /// When a blow lands after it begins, in seconds: a thrust's reach, or
    /// an arrow's flight.
    public static let landing: Float = 0.14
    public static let arrowFlight: Float = 0.38
    /// When a falling company meets the ground.
    public static let fallen: Float = 0.85
    /// How long a commander's fury lights the ground.
    public static let furyGlow: Float = 0.9

    /// The frame's motes and its own lights at `time`.
    public func effects(at time: Float) -> (motes: [Mote], lights: [PointLight]) {
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
        for march in marching {
            emitters.append(Emitter(.dust, at: march.at, rate: 9 * march.strength, spread: 0.22, seed: march.seed, strength: 0.6))
        }
        for work in rising {
            emitters.append(Emitter(.dust, at: work.at, rate: 2, spread: 0.16, seed: work.seed, strength: 0.55))
        }
        for work in finished {
            bursts.append(Burst(.dust, at: work.at, start: work.start, count: 20, seed: work.seed, scale: 1.25))
        }
        for blaze in blazes {
            let top = blaze.at + Vec3(0, 0.75, 0)
            emitters.append(Emitter(.embers, at: top, rate: 16 * blaze.strength, spread: 0.18, seed: blaze.seed, strength: 1))
            emitters.append(Emitter(.smoke, at: top + Vec3(0, 0.1, 0), rate: 5 * blaze.strength, spread: 0.14, seed: blaze.seed &+ 7,
                                    strength: 0.8 + 0.6 * blaze.strength))
            // Firelight, flickering.
            let flicker = 0.75 + 0.25 * Float(sin(Double(time * 11 + Float(blaze.seed % 97)))) * Float(sin(Double(time * 7.3)))
            lights.append(PointLight(at: top, reach: 2.6, colour: Vec3(2.2, 1.0, 0.35) * blaze.strength * flicker))
        }
        for spot in fireflies {
            emitters.append(Emitter(.fireflies, at: spot.at, rate: 0.6, spread: 0.3, seed: spot.seed, strength: 1))
        }
        for fury in furies {
            // A ring of gold round the company, a flash above it, and its light a moment on the ground.
            bursts.append(Burst(.fury, at: fury.at + Vec3(0, 0.05, 0), start: fury.start, count: 28, seed: fury.seed, scale: 1.2))
            bursts.append(Burst(.flash, at: fury.at + Vec3(0, 0.45, 0), start: fury.start, count: 1, seed: fury.seed &+ 3, scale: 1.6))
            let age = time - fury.start
            if age >= 0, age < Happenings.furyGlow {
                let fade = 1 - age / Happenings.furyGlow
                lights.append(PointLight(at: fury.at + Vec3(0, 0.6, 0), reach: 2.8, colour: Vec3(2.0, 1.8, 1.1) * fade))
            }
        }
        return (Effects.motes(bursts: bursts, emitters: emitters, at: time), lights)
    }
}
