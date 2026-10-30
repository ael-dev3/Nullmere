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
        case .cart, .wild, .club:
            break
        }
    }

    // MARK: Clips

    func idle(_ p: inout Pose, _ u: Float) {
        carry(&p)
        let breath = Motion.wave(u, cycles: 3)
        p.stretch(Limb.torso, Vec3(1 + 0.012 * breath, 1 + 0.01 * breath, 1 + 0.025 * breath))
        let shift = Motion.wave(u, cycles: 1)
        p.shift(Limb.hips, Vec3(0.012 * size * shift, 0, 0))
        p.turn(Limb.hips, z: 0.035 * shift)
        p.turn(Limb.torso, z: -0.045 * shift)
        p.turn(Limb.thighL, z: -0.035 * shift)
        p.turn(Limb.thighR, z: -0.035 * shift)
        let look = Motion.key(u, [(0, 0), (0.18, 0), (0.3, 0.55), (0.46, 0.55), (0.58, -0.4), (0.72, -0.4), (0.84, 0), (1, 0)])
        p.turn(Limb.head, x: 0.04 * Motion.wave(u, cycles: 2), y: look)
        if hands == .wild || hands == .club {
            // A slow, wrong tilt of the head, and fingers that will not keep still.
            p.turn(Limb.head, z: 0.35 * Motion.wave(u, cycles: 1, phase: 0.25))
            p.turn(Limb.forearmL, x: 0.15 * Motion.wave(u, cycles: 4))
            p.turn(Limb.forearmR, x: 0.15 * Motion.wave(u, cycles: 4, phase: 0.5))
        } else if hands != .cart {
            p.turn(Limb.armR, x: 0.03 * Motion.wave(u, cycles: 3, phase: 0.2))
        }
        if hands == .lantern {
            p.turn(Limb.extra, z: 0.12 * Motion.wave(u, cycles: 2))
        }
        level(&p)
    }

    func march(_ p: inout Pose, _ u: Float) {
        carry(&p)
        let s = Motion.wave(u), c = Motion.cosine(u)
        p.turn(Limb.thighL, x: -stride * s)
        p.turn(Limb.thighR, x: stride * s)
        p.turn(Limb.shinL, x: 1.0 * max(0, c) * max(0, c) + 0.05)
        p.turn(Limb.shinR, x: 1.0 * max(0, -c) * max(0, -c) + 0.05)
        p.shift(Limb.hips, Vec3(0, 0.014 * size * Motion.cosine(u, cycles: 2), 0))
        p.turn(Limb.hips, y: -0.1 * s)
        p.turn(Limb.torso, x: 0.06, y: 0.14 * s)
        p.turn(Limb.head, y: -0.06 * s)
        let swing: Float
        switch hands {
        case .spear, .lantern: swing = 0.12
        case .bow: swing = 0.3
        case .cart: swing = 0
        case .wild: swing = 0.5
        case .club: swing = 0.25
        }
        p.turn(Limb.armL, x: (shield ? 0.1 : swing) * s)
        p.turn(Limb.armR, x: -swing * s)
        switch hands {
        case .cart:
            // Leaning into the shafts; the wheels roll.
            p.turn(Limb.torso, x: 0.12)
            p.turn(Limb.hips, x: 0.06)
            p.turn(Cart.wheelL, x: 2 * .pi * wheelTurns * u)
            p.turn(Cart.wheelR, x: 2 * .pi * wheelTurns * u)
        case .wild, .club:
            p.turn(Limb.head, z: 0.2 * Motion.wave(u, phase: 0.1))
            p.turn(Limb.torso, z: 0.06 * s)
        case .lantern:
            p.turn(Limb.extra, x: 0.18 * Motion.wave(u, cycles: 2))
        case .spear, .bow:
            break
        }
        level(&p)
    }

    func attack(_ p: inout Pose, _ u: Float) {
        carry(&p)
        switch hands {
        case .spear: thrust(&p, u)
        case .bow: loose(&p, u)
        case .lantern: raise(&p, u)
        case .cart: swing(&p, u, high: true)
        case .wild: rake(&p, u)
        case .club: slam(&p, u)
        }
    }

    /// A spear levelled and driven forward, the weight behind it.
    func thrust(_ p: inout Pose, _ u: Float) {
        let drive = Motion.key(u, [(0, 0), (0.3, -1), (0.45, 1), (0.62, 1), (1, 0)])
        p.turn(Limb.armR, x: -0.45 - 0.4 * drive, z: 0.05)
        p.turn(Limb.forearmR, x: -0.55 + 0.45 * max(drive, 0))
        p.turn(Limb.torso, x: 0.1 + 0.12 * drive, y: 0.28 * drive)
        p.shift(Limb.hips, Vec3(0, -0.02 * size, 0.04 * size * drive))
        p.turn(Limb.thighL, x: -0.45)
        p.turn(Limb.shinL, x: 0.35)
        p.turn(Limb.thighR, x: 0.35)
        p.turn(Limb.shinR, x: 0.25)
        p.turn(Limb.head, y: -0.2 * drive)
        level(&p, spear: .pi / 2)
    }

    /// A bow raised, drawn to the cheek, loosed, and lowered half-way.
    func loose(_ p: inout Pose, _ u: Float) {
        let raise = Motion.key(u, [(0, 0.35), (0.15, 1), (0.78, 1), (1, 0.35)])
        let draw = Motion.key(u, [(0, 0), (0.15, 0.1), (0.5, 1), (0.6, 1), (0.63, 0), (1, 0)])
        p.joints[Int(Limb.heldL)].rotation.z = 0.35 * (1 - raise)
        p.turn(Limb.torso, y: -0.45 * raise)
        p.turn(Limb.head, y: 0.4 * raise)
        p.turn(Limb.armL, x: -1.45 * raise, y: 0.45 * raise)
        p.turn(Limb.forearmL, x: 0.35 * raise)
        // The draw: the elbow swung out to the right, the forearm folded back to the cheek.
        p.turn(Limb.armR, x: -1.5 * raise, y: (-0.25 - 1.0 * draw) * raise)
        p.turn(Limb.forearmR, z: (0.5 + 2.1 * draw) * raise)
        p.turn(Limb.thighL, x: -0.2)
        p.turn(Limb.thighR, x: 0.2)
        if u > 0.12 && u < 0.62 {
            p.joints[Int(Limb.extra)].scale = Vec3(1, 1, 0.35 + 0.65 * draw)
            p.hide(Bowman.string)
        }
        level(&p, bow: 0)
    }

    /// A lantern lifted high, flaring, and lowered.
    func raise(_ p: inout Pose, _ u: Float) {
        let lift = Motion.key(u, [(0, 0), (0.3, 1), (0.72, 1), (1, 0)])
        p.turn(Limb.armL, x: -2.35 * lift, z: -0.1 * lift)
        p.turn(Limb.forearmL, x: 0.4 * lift)
        p.turn(Limb.armR, x: -0.9 * lift, z: -0.2 * lift)
        p.turn(Limb.forearmR, x: -0.6 * lift)
        p.turn(Limb.torso, x: -0.08 * lift)
        p.turn(Limb.head, x: -0.25 * lift)
        level(&p)
        let flare = 1 + 0.3 * lift * (0.6 + 0.4 * Motion.wave(u, cycles: 6))
        p.stretch(Limb.extra, flare)
    }

    /// The long arms flung back and raked forward, the head thrust after them.
    func rake(_ p: inout Pose, _ u: Float) {
        let lunge = Motion.key(u, [(0, 0), (0.35, -0.7), (0.5, 1), (0.66, 1), (1, 0)])
        for arm in [Limb.armL, Limb.armR] {
            p.turn(arm, x: -0.5 - 1.3 * lunge)
        }
        p.turn(Limb.forearmL, x: -0.3 - 0.4 * max(-lunge, 0))
        p.turn(Limb.forearmR, x: -0.3 - 0.4 * max(-lunge, 0))
        p.turn(Limb.torso, x: 0.25 * lunge)
        p.turn(Limb.head, x: -0.3 * lunge, z: 0.2 * lunge)
        p.shift(Limb.hips, Vec3(0, -0.03 * size * abs(lunge), 0.06 * size * lunge))
        p.turn(Limb.thighL, x: -0.5)
        p.turn(Limb.shinL, x: 0.4)
        p.turn(Limb.thighR, x: 0.4)
        p.turn(Limb.shinR, x: 0.3)
    }

    /// A great club heaved overhead and brought down.
    func slam(_ p: inout Pose, _ u: Float) {
        let heave = Motion.key(u, [(0, 0), (0.42, 1), (0.55, -0.35), (0.75, -0.35), (1, 0)])
        p.turn(Limb.armR, x: -0.6 - 2.1 * heave, z: 0.15)
        p.turn(Limb.armL, x: -0.6 - 2.1 * heave, z: -0.35)
        p.turn(Limb.forearmR, x: -0.3)
        p.turn(Limb.forearmL, x: -0.3)
        p.turn(Limb.torso, x: 0.2 - 0.3 * heave)
        p.shift(Limb.hips, Vec3(0, -0.03 * size * max(-heave, 0), 0))
        p.turn(Limb.thighL, x: -0.35)
        p.turn(Limb.shinL, x: 0.3)
        p.turn(Limb.thighR, x: 0.3)
    }

    /// The mattock swung over and down, twice a period.
    func swing(_ p: inout Pose, _ u: Float, high: Bool) {
        let v = u * 2 - (u * 2).rounded(.down)
        let s = Motion.key(v, [(0, 0), (0.4, 1), (0.55, -0.15), (0.75, -0.15), (1, 0)])
        p.joints[Int(Limb.tool)].scale = Vec3(1, 1, 1)
        p.hide(Limb.heldR)
        if hands != .lantern && hands != .cart {
            p.hide(Limb.heldL)
        }
        if hands == .bow {
            p.hide(Bowman.string)
        }
        for joint in [Limb.armR, Limb.armL, Limb.forearmR, Limb.forearmL, Limb.torso] {
            p.joints[Int(joint)].rotation = .zero
        }
        p.turn(Limb.armR, x: -0.6 - 2.2 * s, z: 0.15)
        p.turn(Limb.armL, x: -0.6 - 2.2 * s, z: -0.35)
        p.turn(Limb.forearmR, x: -0.3)
        p.turn(Limb.forearmL, x: -0.45)
        p.turn(Limb.torso, x: (high ? 0.05 : 0.2) - 0.25 * s + stoop)
        p.shift(Limb.hips, Vec3(0, -0.015 * size * (1 - s), 0))
        p.turn(Limb.thighL, x: -0.25)
        p.turn(Limb.shinL, x: 0.3)
        p.turn(Limb.thighR, x: 0.15)
        p.turn(Limb.shinR, x: 0.2)
    }

    func gather(_ p: inout Pose, _ u: Float) {
        carry(&p)
        swing(&p, u, high: false)
        if hands == .lantern {
            p.hide(Limb.heldL)
            p.hide(Limb.extra)
        }
    }

    /// Struck: the knees go, and it falls and lies still. The far
    /// country's fall forward; so do founders, away from their cart, which
    /// hangs from the root and stays where it was let go.
    func death(_ p: inout Pose, _ u: Float) {
        carry(&p)
        let fall = Motion.key(u, [(0, 0), (0.25, 0.06), (0.8, 1), (1, 1)])
        let buckle = Motion.key(u, [(0, 0), (0.3, 1), (0.75, 0.45), (1, 0.4)])
        let forward = hands == .wild || hands == .club || hands == .cart
        let lying = Float.pi / 2 * fall
        // Turned about the hips and lowered till the back, or the chest, lies on the ground.
        let drop = (hip - 0.1) * size * fall
        if forward {
            p.turn(Limb.hips, x: lying)
            p.shift(Limb.hips, Vec3(0, -drop, 0.06 * size * fall))
            p.turn(Limb.armL, x: -2.4 * fall, z: 0.3 * fall)
            p.turn(Limb.armR, x: -2.4 * fall, z: -0.3 * fall)
        } else {
            p.turn(Limb.hips, x: -lying)
            p.shift(Limb.hips, Vec3(0, -drop, -0.06 * size * fall))
            p.turn(Limb.armL, z: 1.0 * fall)
            p.turn(Limb.armR, z: -1.0 * fall)
            p.turn(Limb.head, x: -0.25 * fall)
        }
        p.turn(Limb.thighL, x: -0.6 * buckle)
        p.turn(Limb.shinL, x: 0.9 * buckle)
        p.turn(Limb.thighR, x: -0.45 * buckle)
        p.turn(Limb.shinR, x: 0.8 * buckle)
        p.turn(Limb.forearmL, x: -0.4 * fall)
        p.turn(Limb.forearmR, x: -0.4 * fall)
    }
}

/// The parts a founder's handcart adds.
enum Cart {
    /// The cart itself, which is the founder's extra part.
    static let body = Limb.extra
    static let wheelL: UInt16 = 17
    static let wheelR: UInt16 = 18
}
