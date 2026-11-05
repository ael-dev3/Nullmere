import Foundation

/// How a person on foot moves through each clip.
struct Gait: Sendable {
    /// What the hands are busy with, which shapes every clip.
    enum Hands: Sendable {
        /// A spear upright in the right hand.
        case spear
        /// A bow in the left hand.
        case bow
        /// A lantern's staff in the left hand.
        case lantern
        /// A handcart's shafts in both.
        case cart
        /// Long arms of the far country, empty or clawed.
        case wild
        /// A great club in the right hand, dragged.
        case club
        /// Nothing in either: the arms swing free.
        case free
    }

    var hands: Hands
    /// A shield carried before the left side.
    var shield = false
    /// The figure's height in world units, for its shifts.
    var size: Float = 0.3
    /// How far forward it stoops, in radians.
    var stoop: Float = 0
    /// How far each leg swings on the march, in radians.
    var stride: Float = 0.45
    /// How long the legs are, in the body's units, for its pace.
    var leg: Float = 0.46
    /// How high the hips stand, in the body's units.
    var hip: Float = 0.5
    var parts = Limb.count
    /// Turns of the cart's wheels each march period.
    var wheelTurns: Float = 1

    /// The ground covered each second on the march, for the feet not to slide.
    var marchSpeed: Float {
        2 * 2 * leg * Float(sin(Double(stride))) * size / Clip.march.period
    }

    /// A walker of this body, its stride set so it keeps the one pace
    /// every company on foot marches at, the feet holding the ground.
    static func paced(_ hands: Hands, _ f: Frame, shield: Bool = false, stoop: Float = 0, parts: Int = Limb.count) -> Gait {
        let base = Gait(hands: .spear).marchSpeed
        var gait = Gait(hands: hands, shield: shield, size: f.size, stoop: stoop, leg: f.hip - 0.04, hip: f.hip, parts: parts)
        let reach = 4 * gait.leg * f.size / Clip.march.period
        gait.stride = Float(asin(Double(min(base / reach, 0.95))))
        return gait
    }

    func joints(_ clip: Clip, _ time: Float) -> [Joint] {
        var p = Pose(count: parts)
        let u = clip.progress(at: time)
        p.hide(Limb.tool)
        if hands == .bow {
            p.hide(Limb.extra)
        }
        switch clip {
        case .idle: idle(&p, u)
        case .march: march(&p, u)
        case .attack: attack(&p, u)
        case .death: death(&p, u)
        case .gather: gather(&p, u)
        case .hit: hit(&p, u)
        }
        return p.joints
    }

    // MARK: Postures

    /// How the arms hold what they carry, standing.
    func carry(_ p: inout Pose) {
        switch hands {
        case .spear:
            p.turn(Limb.armR, x: -0.12, z: -0.05)
            p.turn(Limb.forearmR, x: -0.5)
        case .bow:
            // The bow held before the left hip, slanting across the body.
            p.turn(Limb.armL, x: -0.3, z: 0.05)
            p.turn(Limb.forearmL, x: -0.75)
            p.turn(Limb.heldL, z: 0.35)
            p.turn(Limb.armR, z: -0.06)
            p.turn(Limb.forearmR, x: -0.2)
        case .lantern:
            p.turn(Limb.armL, x: -0.25, z: 0.08)
            p.turn(Limb.forearmL, x: -0.55)
            p.turn(Limb.forearmR, x: -0.25)
        case .cart:
            break
        case .wild:
            p.turn(Limb.armL, x: -0.15, z: 0.12)
            p.turn(Limb.armR, x: -0.15, z: -0.12)
            p.turn(Limb.forearmL, x: -0.35)
            p.turn(Limb.forearmR, x: -0.35)
        case .club:
            p.turn(Limb.armR, x: 0.1, z: -0.15)
            p.turn(Limb.armL, x: -0.1, z: 0.15)
            p.turn(Limb.forearmL, x: -0.4)
        case .free:
            p.turn(Limb.forearmL, x: -0.15)
            p.turn(Limb.forearmR, x: -0.15)
        }
        if shield {
            p.turn(Limb.armL, x: -0.3, z: 0.05)
            p.turn(Limb.forearmL, x: -1.15)
        }
        if stoop > 0 {
            p.turn(Limb.torso, x: stoop)
            p.turn(Limb.head, x: -stoop * 0.7)
        }
    }

    /// Keeps what is held at its angle however the arm stands: a spear
    /// upright, a bow upright, a lantern hanging.
    func level(_ p: inout Pose, spear: Float = 0, bow: Float = 0) {
        switch hands {
        case .spear:
            p.turn(Limb.heldR, x: spear - p.pitch(through: [Limb.hips, Limb.torso, Limb.armR, Limb.forearmR]))
        case .bow:
            p.turn(Limb.heldL, x: bow - p.pitch(through: [Limb.hips, Limb.torso, Limb.armL, Limb.forearmL]))
        case .lantern:
            p.turn(Limb.heldL, x: -p.pitch(through: [Limb.hips, Limb.torso, Limb.armL, Limb.forearmL]))
            p.turn(Limb.extra, x: -p.pitch(through: [Limb.root, Limb.hips, Limb.torso, Limb.armL, Limb.forearmL, Limb.heldL]))
        case .cart, .wild, .club, .free:
            break
        }
    }

    // MARK: Clips

    /// At rest, as this kind stands, keyed.
    func idle(_ p: inout Pose, _ u: Float) {
        carry(&p)
        FootClips.idle(hands).apply(&p, u, size: size)
        level(&p)
    }

    /// The march, as this kind's walk is keyed; a carter's wheels roll
    /// under it, once a period over the ground walked.
    func march(_ p: inout Pose, _ u: Float) {
        carry(&p)
        FootClips.walk(hands, shield: shield).apply(&p, u, stride: stride, size: size)
        if hands == .cart {
            p.turn(Cart.wheelL, x: 2 * .pi * wheelTurns * u)
            p.turn(Cart.wheelR, x: 2 * .pi * wheelTurns * u)
        }
        level(&p)
    }

    func attack(_ p: inout Pose, _ u: Float) {
        carry(&p)
        switch hands {
        case .spear: thrust(&p, u)
        case .bow: loose(&p, u)
        case .lantern: raise(&p, u)
        case .cart, .free: swing(&p, u, high: true)
        case .wild: rake(&p, u)
        case .club: slam(&p, u)
        }
    }

    /// A spear levelled and driven forward, the weight behind it.
    func thrust(_ p: inout Pose, _ u: Float) {
        FootClips.thrust.apply(&p, u, size: size)
        level(&p, spear: .pi / 2)
    }

    /// A bow raised, drawn to the cheek, loosed, and lowered half-way.
    func loose(_ p: inout Pose, _ u: Float) {
        let raise = FootClips.bowRaise.value(at: u, loops: true).x
        let draw = Motion.key(u, FootClips.bowDraw)
        p.joints[Int(Limb.heldL)].rotation.z = 0.35 * (1 - raise)
        FootClips.loose.apply(&p, u, size: size)
        if u > 0.12 && u < 0.62 {
            p.joints[Int(Limb.extra)].scale = Vec3(1, 1, 0.35 + 0.65 * draw)
            p.hide(Bowman.string)
        }
        level(&p, bow: 0)
    }

    /// A lantern lifted high, flaring, and lowered.
    func raise(_ p: inout Pose, _ u: Float) {
        FootClips.raiseLantern.apply(&p, u, size: size)
        level(&p)
        let lift = Motion.key(u, FootClips.lift)
        p.stretch(Limb.extra, 1 + 0.3 * lift * (0.6 + 0.4 * Motion.wave(u, cycles: 6)))
    }

    /// The long arms flung back and raked forward, the head thrust after them.
    func rake(_ p: inout Pose, _ u: Float) {
        for part in [Limb.armL, Limb.armR, Limb.forearmL, Limb.forearmR] { p.joints[Int(part)].rotation = .zero }
        FootClips.rake.apply(&p, u, size: size)
    }

    /// A great club heaved overhead and brought down.
    func slam(_ p: inout Pose, _ u: Float) {
        for part in [Limb.armL, Limb.armR, Limb.forearmL, Limb.forearmR] { p.joints[Int(part)].rotation = .zero }
        FootClips.slam.apply(&p, u, size: size)
    }

    /// The mattock swung over and down, twice a period.
    func swing(_ p: inout Pose, _ u: Float, high: Bool) {
        let v = u * 2 - (u * 2).rounded(.down)
        p.joints[Int(Limb.tool)].scale = Vec3(1, 1, 1)
        p.hide(Limb.heldR)
        if hands != .cart {
            // What the left hand held is put away, and with it what hangs from it.
            p.hide(Limb.heldL)
            p.joints[Int(Limb.extra)].scale = Vec3(1, 1, 1)
        }
        for joint in [Limb.armR, Limb.armL, Limb.forearmR, Limb.forearmL, Limb.torso] {
            p.joints[Int(joint)].rotation = .zero
        }
        FootClips.stroke(stoop: stoop, high: high).apply(&p, v, size: size)
    }

    func gather(_ p: inout Pose, _ u: Float) {
        carry(&p)
        swing(&p, u, high: false)
    }

    /// How hard a blow lands through a hit's beat, as its keys are set:
    /// struck at once, the stagger at its worst a moment after, the slow
    /// recovery to guard before the next. Every model struck takes it on
    /// this beat.
    static func recoil(_ u: Float) -> Float {
        FootClips.recoilTrack.value(at: u, loops: true).x
    }

    /// Struck and standing, as this kind takes a blow.
    func hit(_ p: inout Pose, _ u: Float) {
        carry(&p)
        FootClips.hit(hands, shield: shield).apply(&p, u, size: size)
        level(&p, spear: 0.5 * Gait.recoil(u))
    }

    /// Struck down, as this kind falls, and lying still: the arms let go of
    /// what they carried as it goes, the hips come down to the ground.
    func death(_ p: inout Pose, _ u: Float) {
        carry(&p)
        let fall = FootClips.fallTrack.value(at: u, loops: false).x
        for part in [Limb.armL, Limb.forearmL, Limb.armR, Limb.forearmR, Limb.heldL, Limb.heldR] {
            p.joints[Int(part)].rotation *= 1 - fall
        }
        FootClips.death(hands).apply(&p, u, size: size)
        p.shift(Limb.hips, Vec3(0, -(hip - 0.1) * size * fall, 0))
    }
}

/// The parts a founder's handcart adds.
enum Cart {
    /// The cart itself, which is the founder's extra part.
    static let body = Limb.extra
    static let wheelL: UInt16 = 17
    static let wheelR: UInt16 = 18
}
