import Foundation

/// The clips of the townsfolk built in code, keyed by hand, each kind its
/// own: how an elder walks with a staff, a salter picks a careful way with
/// a lantern, a carter leans into the shafts, folk stroll the lanes; how
/// each strikes, how each takes a blow, and how each falls. (Every
/// company's and wild's clips are keyed in Blender, in Art/blender.)
enum FootClips {
    /// A track that holds one value through the clip.
    static func hold(_ part: UInt16, _ x: Float, _ y: Float = 0, _ z: Float = 0) -> Track { Track(part, [k(0, x, y, z)]) }

    // MARK: Standing

    /// Three breaths a period, the chest rising and falling.
    static func breathing(_ depth: Float) -> Track {
        Track(Limb.torso, .stretch, (0..<6).map { index in
            let full = index % 2 == 0
            return k(Float(index) / 6 + 1 / 12, 0.012 * depth * (full ? 1 : -1), 0.01 * depth * (full ? 1 : -1), 0.025 * depth * (full ? 1 : -1))
        })
    }

    /// Each kind at rest, keyed through a long, slow period.
    static func idle(_ hands: Gait.Hands) -> Keyed {
        switch hands {
        case .spear:
            // Planted square, the weight moved once from foot to foot, a long look along the line.
            return Keyed(loops: true, [
                breathing(1),
                Track(Limb.hips, .shift, scale: .size, [k(0, 0), k(0.25, 0.01), k(0.5, 0), k(0.75, -0.01)]),
                Track(Limb.hips, [k(0, 0), k(0.25, 0, 0, 0.03), k(0.5, 0), k(0.75, 0, 0, -0.03)]),
                Track(Limb.torso, [k(0, 0), k(0.25, 0, 0, -0.04), k(0.5, 0), k(0.75, 0, 0, 0.04)]),
                Track(Limb.thighL, [k(0, 0), k(0.25, 0, 0, -0.03), k(0.5, 0), k(0.75, 0, 0, 0.03)]),
                Track(Limb.thighR, [k(0, 0), k(0.25, 0, 0, -0.03), k(0.5, 0), k(0.75, 0, 0, 0.03)]),
                Track(Limb.head, [k(0, 0), k(0.18, 0), k(0.3, 0.02, 0.5), k(0.46, 0.02, 0.5), k(0.58, -0.02, -0.35), k(0.72, -0.02, -0.35),
                                  k(0.84, 0)]),
                Track(Limb.armR, [k(0, 0), k(0.33, 0.03), k(0.66, -0.02)]),
            ])
        case .lantern:
            // Wary: the lantern held out and turned, the head searching the dark all round.
            return Keyed(loops: true, [
                breathing(0.9),
                Track(Limb.torso, [k(0, 0.06), k(0.25, 0.06, 0.15), k(0.5, 0.06), k(0.75, 0.06, -0.15)]),
                Track(Limb.head, [k(0, -0.05, 0), k(0.12, -0.08, 0.6), k(0.3, -0.08, 0.6), k(0.42, 0.05, 0), k(0.55, -0.08, -0.6),
                                  k(0.72, -0.08, -0.6), k(0.86, -0.12, 0)]),
                Track(Limb.armL, [k(0, 0), k(0.25, -0.15, 0, -0.05), k(0.5, 0), k(0.75, -0.15, 0, 0.05)]),
                Track(Limb.extra, [k(0, 0, 0, 0.12), k(0.25, 0, 0, -0.12), k(0.5, 0, 0, 0.12), k(0.75, 0, 0, -0.12)]),
                Track(Limb.armR, [k(0, 0), k(0.33, 0.04), k(0.66, -0.03)]),
            ])
        case .cart:
            // Resting on the shafts, breathing hard, wiping the brow once.
            return Keyed(loops: true, [
                breathing(1.5),
                Track(Limb.torso, [k(0, 0.06), k(0.5, 0.1)]),
                Track(Limb.head, [k(0, 0), k(0.25, 0, 0.3), k(0.5, 0), k(0.75, 0, -0.25)]),
                Track(Limb.armR, [k(0, 0), k(0.6, 0), k(0.68, -1.6, 0, 0.2), k(0.76, -1.6, 0, 0.35), k(0.84, 0)]),
                Track(Limb.forearmR, [k(0, 0), k(0.6, 0), k(0.68, -1.1), k(0.76, -1.1), k(0.84, 0)]),
            ])
        case .free:
            return Keyed(loops: true, [
                breathing(1),
                Track(Limb.hips, .shift, scale: .size, [k(0, 0), k(0.25, 0.012), k(0.5, 0), k(0.75, -0.012)]),
                Track(Limb.hips, [k(0, 0), k(0.25, 0, 0, 0.035), k(0.5, 0), k(0.75, 0, 0, -0.035)]),
                Track(Limb.head, [k(0, 0), k(0.18, 0), k(0.3, 0, 0.55), k(0.46, 0, 0.55), k(0.58, 0, -0.4), k(0.72, 0, -0.4), k(0.84, 0)]),
            ])
        }
    }

    // MARK: Walking

    static func walk(_ hands: Gait.Hands, shield: Bool) -> Keyed {
        switch hands {
        case .spear: return spearWalk(shield: shield)
        case .lantern: return lanternWalk
        case .cart: return cartWalk
        case .free: return freeWalk
        }
    }

    /// The spearman's march: heavy and measured, the weight set down hard
    /// on each heel, the trunk upright and rolling a little over the hips,
    /// the spear arm steady and the shield kept close.
    static func spearWalk(shield: Bool) -> Keyed {
        Keyed(loops: true, [
            Track(Limb.thighL, scale: .stride, [k(0, 0.05), k(0.22, -1), k(0.5, 0), k(0.75, 0.95)]),
            Track(Limb.thighR, scale: .stride, [k(0, -0.05), k(0.25, 0.95), k(0.5, 0.05), k(0.72, -1)]),
            Track(Limb.shinL, [k(0, 0.95), k(0.12, 0.55), k(0.25, 0.1), k(0.5, 0.14), k(0.75, 0.06), k(0.9, 0.5)]),
            Track(Limb.shinR, [k(0, 0.14), k(0.25, 0.06), k(0.4, 0.5), k(0.5, 0.95), k(0.62, 0.55), k(0.75, 0.1)]),
            Track(Limb.hips, .shift, scale: .size, [k(0, 0, 0.012), k(0.25, 0, -0.01), k(0.5, 0, 0.012), k(0.75, 0, -0.01)]),
            Track(Limb.hips, [k(0, 0, 0, 0.02), k(0.25, 0, -0.08, 0), k(0.5, 0, 0, -0.02), k(0.75, 0, 0.08, 0)]),
            Track(Limb.torso, [k(0, 0.04, 0, -0.03), k(0.25, 0.05, 0.1, 0), k(0.5, 0.04, 0, 0.03), k(0.75, 0.05, -0.1, 0)]),
            Track(Limb.head, [k(0, 0, 0), k(0.25, 0.02, -0.06), k(0.5, 0, 0), k(0.75, 0.02, 0.06)]),
            Track(Limb.armL, [k(0, 0), k(0.25, shield ? 0.06 : 0.14), k(0.5, 0), k(0.75, shield ? -0.06 : -0.14)]),
            Track(Limb.armR, [k(0, 0), k(0.25, -0.1), k(0.5, 0), k(0.75, 0.1)]),
        ])
    }

    /// The lantern-bearer's careful way into the dark: stooped, short
    /// steps, the head turning to look one side and then the other, the
    /// lantern swinging on its hook.
    static let lanternWalk = Keyed(loops: true, [
        Track(Limb.thighL, scale: .stride, [k(0, 0), k(0.25, -0.9), k(0.5, 0), k(0.75, 0.85)]),
        Track(Limb.thighR, scale: .stride, [k(0, 0), k(0.25, 0.85), k(0.5, 0), k(0.75, -0.9)]),
        Track(Limb.shinL, [k(0, 0.85), k(0.12, 0.5), k(0.25, 0.12), k(0.5, 0.15), k(0.75, 0.1), k(0.88, 0.45)]),
        Track(Limb.shinR, [k(0, 0.15), k(0.25, 0.1), k(0.38, 0.45), k(0.5, 0.85), k(0.62, 0.5), k(0.75, 0.12)]),
        Track(Limb.hips, .shift, scale: .size, [k(0, 0, 0.008), k(0.25, 0, -0.008), k(0.5, 0, 0.008), k(0.75, 0, -0.008)]),
        Track(Limb.torso, [k(0, 0.12, 0.05), k(0.25, 0.11, 0.08), k(0.5, 0.12, -0.05), k(0.75, 0.11, -0.08)]),
        Track(Limb.head, [k(0, -0.1, 0.3), k(0.25, -0.12, 0.2), k(0.5, -0.1, -0.3), k(0.75, -0.12, -0.2)]),
        Track(Limb.armR, [k(0, 0), k(0.25, -0.12), k(0.5, 0), k(0.75, 0.12)]),
        Track(Limb.extra, [k(0, 0.18), k(0.25, -0.12), k(0.5, 0.18), k(0.75, -0.12)]),
    ])

    /// A carter leaning into the shafts: the trunk and hips bent to the
    /// load, short pushing strides, the arms set on the shafts.
    static let cartWalk = Keyed(loops: true, [
        Track(Limb.thighL, scale: .stride, [k(0, 0), k(0.25, -1), k(0.5, 0), k(0.75, 0.9)]),
        Track(Limb.thighR, scale: .stride, [k(0, 0), k(0.25, 0.9), k(0.5, 0), k(0.75, -1)]),
        Track(Limb.shinL, [k(0, 0.9), k(0.12, 0.5), k(0.25, 0.15), k(0.5, 0.2), k(0.75, 0.15), k(0.88, 0.45)]),
        Track(Limb.shinR, [k(0, 0.2), k(0.25, 0.15), k(0.38, 0.45), k(0.5, 0.9), k(0.62, 0.5), k(0.75, 0.15)]),
        Track(Limb.hips, .shift, scale: .size, [k(0, 0, 0.01), k(0.25, 0, -0.01), k(0.5, 0, 0.01), k(0.75, 0, -0.01)]),
        Track(Limb.hips, [k(0, 0.06), k(0.25, 0.06, -0.08), k(0.5, 0.06), k(0.75, 0.06, 0.08)]),
        Track(Limb.torso, [k(0, 0.13), k(0.25, 0.12, 0.08), k(0.5, 0.13), k(0.75, 0.12, -0.08)]),
        Track(Limb.head, [k(0, -0.1), k(0.5, -0.12)]),
    ])

    /// Folk about the lanes: an easy walk, the arms swinging free.
    static let freeWalk = Keyed(loops: true, [
        Track(Limb.thighL, scale: .stride, [k(0, 0), k(0.25, -1), k(0.5, 0), k(0.75, 1)]),
        Track(Limb.thighR, scale: .stride, [k(0, 0), k(0.25, 1), k(0.5, 0), k(0.75, -1)]),
        Track(Limb.shinL, [k(0, 1.0), k(0.12, 0.55), k(0.25, 0.06), k(0.5, 0.12), k(0.75, 0.06), k(0.88, 0.5)]),
        Track(Limb.shinR, [k(0, 0.12), k(0.25, 0.06), k(0.38, 0.5), k(0.5, 1.0), k(0.62, 0.55), k(0.75, 0.06)]),
        Track(Limb.hips, .shift, scale: .size, [k(0, 0, 0.014), k(0.25, 0, -0.01), k(0.5, 0, 0.014), k(0.75, 0, -0.01)]),
        Track(Limb.hips, [k(0, 0), k(0.25, 0, -0.1), k(0.5, 0), k(0.75, 0, 0.1)]),
        Track(Limb.torso, [k(0, 0.06), k(0.25, 0.06, 0.14), k(0.5, 0.06), k(0.75, 0.06, -0.14)]),
        Track(Limb.head, [k(0, 0), k(0.25, 0, -0.06), k(0.5, 0), k(0.75, 0, 0.06)]),
        Track(Limb.armL, [k(0, 0), k(0.25, 0.32), k(0.5, 0), k(0.75, -0.32)]),
        Track(Limb.armR, [k(0, 0), k(0.25, -0.32), k(0.5, 0), k(0.75, 0.32)]),
    ])

    // MARK: Striking

    /// The thrust: drawn back, the spear levelled and driven forward with
    /// the weight behind it, held at full reach, and recovered.
    static let thrust = Keyed(loops: true, [
        Track(Limb.armR, [k(0, -0.45, 0, 0.05), k(0.3, -0.05, 0, 0.05), k(0.45, -0.85, 0, 0.05), k(0.62, -0.85, 0, 0.05), k(0.85, -0.5, 0, 0.05)]),
        Track(Limb.forearmR, [k(0, -0.55), k(0.3, -0.55), k(0.45, -0.1), k(0.62, -0.1), k(0.85, -0.5)]),
        Track(Limb.torso, [k(0, 0.1), k(0.3, -0.02, -0.28), k(0.45, 0.22, 0.28), k(0.62, 0.22, 0.28), k(0.85, 0.12, 0.05)]),
        Track(Limb.hips, .shift, scale: .size, [k(0, 0, -0.02, 0), k(0.3, 0, -0.02, -0.04), k(0.45, 0, -0.025, 0.045), k(0.62, 0, -0.025, 0.04)]),
        Track(Limb.head, [k(0, 0), k(0.3, 0, 0.2), k(0.45, 0, -0.2), k(0.62, 0, -0.2)]),
        hold(Limb.thighL, -0.45), hold(Limb.shinL, 0.35), hold(Limb.thighR, 0.35), hold(Limb.shinR, 0.25),
    ])

    /// The lantern lifted high, flaring, and lowered.
    static let lift: [(Float, Float)] = [(0, 0), (0.3, 1), (0.72, 1), (1, 0)]
    static let raiseLantern = Keyed(loops: true, [
        Track(Limb.armL, [k(0, 0), k(0.3, -2.35, 0, -0.1), k(0.72, -2.35, 0, -0.1)]),
        Track(Limb.forearmL, [k(0, 0), k(0.3, 0.4), k(0.72, 0.4)]),
        Track(Limb.armR, [k(0, 0), k(0.3, -0.9, 0, -0.2), k(0.72, -0.9, 0, -0.2)]),
        Track(Limb.forearmR, [k(0, 0), k(0.3, -0.6), k(0.72, -0.6)]),
        Track(Limb.torso, [k(0, 0), k(0.3, -0.08), k(0.72, -0.08)]),
        Track(Limb.head, [k(0, 0), k(0.3, -0.25), k(0.72, -0.25)]),
    ])

    /// The mattock over and down, one stroke a half-period, its moment `v`
    /// within the stroke: for gathering, and for a carter at bay.
    static func stroke(stoop: Float, high: Bool) -> Keyed {
        let lean: Float = (high ? 0.05 : 0.2) + stoop
        return Keyed(loops: true, [
            Track(Limb.armR, [k(0, -0.6, 0, 0.15), k(0.4, -2.8, 0, 0.15), k(0.55, -0.27, 0, 0.15), k(0.75, -0.27, 0, 0.15)]),
            Track(Limb.armL, [k(0, -0.6, 0, -0.35), k(0.4, -2.8, 0, -0.35), k(0.55, -0.27, 0, -0.35), k(0.75, -0.27, 0, -0.35)]),
            hold(Limb.forearmR, -0.3), hold(Limb.forearmL, -0.45),
            Track(Limb.torso, [k(0, lean), k(0.4, lean - 0.25), k(0.55, lean + 0.04), k(0.75, lean + 0.04)]),
            Track(Limb.hips, .shift, scale: .size, [k(0, 0, -0.015), k(0.4, 0, 0), k(0.55, 0, -0.017), k(0.75, 0, -0.017)]),
            hold(Limb.thighL, -0.25), hold(Limb.shinL, 0.3), hold(Limb.thighR, 0.15), hold(Limb.shinR, 0.2),
        ])
    }

    // MARK: Struck

    /// The beat of a blow taken: struck at once, worst a moment after, the
    /// recovery to guard, and at guard well before the next.
    static let recoil: [(Float, Float)] = [(0, 0), (0.06, 0.15), (0.14, 1), (0.32, 0.7), (0.55, 0.25), (0.72, 0.05), (0.8, 0), (0.85, 0),
                                           (0.9, 0), (0.95, 0)]
    static let recoilTrack = Track(0, recoil.map { k($0.0, $0.1) })

    /// Tracks for a part keyed on the blow's beat, as far as it goes at worst.
    static func struck(_ part: UInt16, scale: Track.Scale = .none, _ worst: Vec3) -> Track {
        struck(part, .turn, scale: scale, worst)
    }

    static func struck(_ part: UInt16, _ kind: Track.Kind, scale: Track.Scale = .none, _ worst: Vec3) -> Track {
        Track(part, kind, scale: scale, recoil.map { ($0.0, worst * $0.1) })
    }

    /// Each kind takes a blow its own way.
    static func hit(_ hands: Gait.Hands, shield: Bool) -> Keyed {
        switch hands {
        case .spear:
            // Braced behind the shield: the shield takes it, the body gives a little.
            return Keyed(loops: true, [
                struck(Limb.torso, Vec3(-0.24, 0.16, 0.06)), struck(Limb.head, Vec3(-0.2, -0.25, 0.08)),
                struck(Limb.hips, .shift, scale: .size, Vec3(0, -0.03, -0.05)),
                struck(Limb.thighR, Vec3(0.34, 0, 0)), struck(Limb.shinR, Vec3(0.25, 0, 0)),
                struck(Limb.thighL, Vec3(-0.22, 0, 0)), struck(Limb.shinL, Vec3(0.4, 0, 0)),
                struck(Limb.armL, shield ? Vec3(-0.6, 0, -0.12) : Vec3(-1.1, 0, -0.35)),
                struck(Limb.forearmL, shield ? Vec3(-0.38, 0, 0) : Vec3(-1.0, 0, 0)),
                struck(Limb.armR, Vec3(0.3, 0, -0.22)),
            ])
        case .lantern:
            // Flinching from it, the lantern held away, the free arm across the face.
            return Keyed(loops: true, [
                struck(Limb.torso, Vec3(-0.3, -0.35, 0.12)), struck(Limb.head, Vec3(-0.3, 0.5, 0)),
                struck(Limb.hips, .shift, scale: .size, Vec3(0.02, -0.03, -0.06)),
                struck(Limb.thighR, Vec3(0.4, 0, 0)), struck(Limb.shinR, Vec3(0.3, 0, 0)), struck(Limb.shinL, Vec3(0.4, 0, 0)),
                struck(Limb.armR, Vec3(-1.3, 0, 0.4)), struck(Limb.forearmR, Vec3(-1.2, 0, 0)),
                struck(Limb.armL, Vec3(0.2, 0, 0.5)),
            ])
        case .cart:
            // Ducking down behind the cart.
            return Keyed(loops: true, [
                struck(Limb.torso, Vec3(0.55, 0.15, 0)), struck(Limb.head, Vec3(0.4, -0.2, 0)),
                struck(Limb.hips, .shift, scale: .size, Vec3(0, -0.06, -0.04)),
                struck(Limb.thighR, Vec3(-0.4, 0, 0)), struck(Limb.shinR, Vec3(0.8, 0, 0)),
                struck(Limb.thighL, Vec3(-0.5, 0, 0)), struck(Limb.shinL, Vec3(0.9, 0, 0)),
                struck(Limb.armL, Vec3(-0.9, 0, -0.3)), struck(Limb.forearmL, Vec3(-0.9, 0, 0)),
            ])
        case .free:
            return Keyed(loops: true, [
                struck(Limb.torso, Vec3(-0.38, 0.22, 0.08)), struck(Limb.head, Vec3(-0.32, -0.35, 0.1)),
                struck(Limb.hips, .shift, scale: .size, Vec3(0, -0.035, -0.07)),
                struck(Limb.thighR, Vec3(0.42, 0, 0)), struck(Limb.shinR, Vec3(0.3, 0, 0)),
                struck(Limb.thighL, Vec3(-0.25, 0, 0)), struck(Limb.shinL, Vec3(0.45, 0, 0)),
                struck(Limb.armL, Vec3(-1.1, 0, -0.35)), struck(Limb.forearmL, Vec3(-1.0, 0, 0)),
            ])
        }
    }

    // MARK: Falling

    /// How far fallen through the death, and how far the knees go, keyed;
    /// still from the last key on.
    static let fall: [(Float, Float)] = [(0, 0), (0.25, 0.06), (0.8, 1), (0.85, 1), (1, 1)]
    static let fallTrack = Track(0, fall.map { k($0.0, $0.1) })

    /// Each kind's fall, as keyed turns through it; the hips' drop to the
    /// ground and the arms' letting go are laid on by the walker.
    static func death(_ hands: Gait.Hands) -> Keyed {
        switch hands {
        case .spear:
            // Struck down backward over the shield, legs folding.
            return Keyed(loops: false, [
                Track(Limb.hips, [k(0, 0), k(0.25, -0.09), k(0.8, -1.571), k(0.85, -1.571)]),
                Track(Limb.hips, .shift, scale: .size, [k(0, 0), k(0.25, 0, 0, -0.004), k(0.8, 0, 0, -0.06), k(0.85, 0, 0, -0.06)]),
                Track(Limb.armL, [k(0, 0), k(0.8, 0, 0, 1.0), k(0.85, 0, 0, 1.0)]),
                Track(Limb.armR, [k(0, 0), k(0.8, 0, 0, -1.0), k(0.85, 0, 0, -1.0)]),
                Track(Limb.head, [k(0, 0), k(0.8, -0.25), k(0.85, -0.25)]),
                Track(Limb.thighL, [k(0, 0), k(0.3, -0.6), k(0.75, -0.24), k(0.85, -0.24)]),
                Track(Limb.shinL, [k(0, 0), k(0.3, 0.9), k(0.75, 0.36), k(0.85, 0.36)]),
                Track(Limb.thighR, [k(0, 0), k(0.3, -0.45), k(0.75, -0.18), k(0.85, -0.18)]),
                Track(Limb.shinR, [k(0, 0), k(0.3, 0.8), k(0.75, 0.32), k(0.85, 0.32)]),
            ])
        case .free:
            // Crumpling to the knees, then turning as it goes down on its back.
            return Keyed(loops: false, [
                Track(Limb.hips, [k(0, 0), k(0.3, -0.12, 0.1), k(0.8, -1.571, 0.4), k(0.85, -1.571, 0.4)]),
                Track(Limb.hips, .shift, scale: .size, [k(0, 0), k(0.3, 0, 0, -0.01), k(0.8, 0, 0, -0.06), k(0.85, 0, 0, -0.06)]),
                Track(Limb.armL, [k(0, 0), k(0.35, -0.5, 0, 0.3), k(0.8, 0, 0, 1.2), k(0.85, 0, 0, 1.2)]),
                Track(Limb.armR, [k(0, 0), k(0.35, -0.5, 0, -0.3), k(0.8, -0.3, 0, -0.9), k(0.85, -0.3, 0, -0.9)]),
                Track(Limb.head, [k(0, 0), k(0.35, 0.3), k(0.8, -0.2, 0.4), k(0.85, -0.2, 0.4)]),
                Track(Limb.thighL, [k(0, 0), k(0.35, -0.9), k(0.75, -0.3), k(0.85, -0.3)]),
                Track(Limb.shinL, [k(0, 0), k(0.35, 1.4), k(0.75, 0.5), k(0.85, 0.5)]),
                Track(Limb.thighR, [k(0, 0), k(0.35, -0.8), k(0.75, -0.2), k(0.85, -0.2)]),
                Track(Limb.shinR, [k(0, 0), k(0.35, 1.3), k(0.75, 0.4), k(0.85, 0.4)]),
            ])
        case .lantern:
            // Spun half round by the blow, and down on the back, the lantern flung out.
            return Keyed(loops: false, [
                Track(Limb.hips, [k(0, 0), k(0.25, -0.08, -0.4), k(0.8, -1.571, -0.7), k(0.85, -1.571, -0.7)]),
                Track(Limb.hips, .shift, scale: .size, [k(0, 0), k(0.8, 0, 0, -0.05), k(0.85, 0, 0, -0.05)]),
                Track(Limb.armL, [k(0, 0), k(0.4, -1.0, 0, 0.6), k(0.8, -0.4, 0, 1.4), k(0.85, -0.4, 0, 1.4)]),
                Track(Limb.armR, [k(0, 0), k(0.8, 0, 0, -1.1), k(0.85, 0, 0, -1.1)]),
                Track(Limb.head, [k(0, 0), k(0.3, 0, 0.4), k(0.8, -0.3, -0.5), k(0.85, -0.3, -0.5)]),
                Track(Limb.thighL, [k(0, 0), k(0.3, -0.5), k(0.75, -0.2), k(0.85, -0.2)]),
                Track(Limb.shinL, [k(0, 0), k(0.3, 0.8), k(0.75, 0.3), k(0.85, 0.3)]),
                Track(Limb.thighR, [k(0, 0), k(0.3, -0.5), k(0.75, -0.3), k(0.85, -0.3)]),
                Track(Limb.shinR, [k(0, 0), k(0.3, 0.9), k(0.75, 0.4), k(0.85, 0.4)]),
            ])
        case .cart:
            // Pitched forward on the face, the arms flung out ahead.
            return Keyed(loops: false, [
                Track(Limb.hips, [k(0, 0), k(0.25, 0.09), k(0.8, 1.571), k(0.85, 1.571)]),
                Track(Limb.hips, .shift, scale: .size, [k(0, 0), k(0.25, 0, 0, 0.004), k(0.8, 0, 0, 0.06), k(0.85, 0, 0, 0.06)]),
                Track(Limb.armL, [k(0, 0), k(0.8, -2.4, 0, 0.3), k(0.85, -2.4, 0, 0.3)]),
                Track(Limb.armR, [k(0, 0), k(0.8, -2.4, 0, -0.3), k(0.85, -2.4, 0, -0.3)]),
                Track(Limb.forearmL, [k(0, 0), k(0.8, -0.4), k(0.85, -0.4)]),
                Track(Limb.forearmR, [k(0, 0), k(0.8, -0.4), k(0.85, -0.4)]),
                Track(Limb.thighL, [k(0, 0), k(0.3, -0.6), k(0.75, -0.24), k(0.85, -0.24)]),
                Track(Limb.shinL, [k(0, 0), k(0.3, 0.9), k(0.75, 0.36), k(0.85, 0.36)]),
                Track(Limb.thighR, [k(0, 0), k(0.3, -0.45), k(0.75, -0.18), k(0.85, -0.18)]),
                Track(Limb.shinR, [k(0, 0), k(0.3, 0.8), k(0.75, 0.32), k(0.85, 0.32)]),
            ])
        }
    }
}
