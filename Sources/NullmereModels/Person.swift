import Foundation

/// The parts of a person's rig, in the order they are added.
enum Limb {
    static let root: UInt16 = 0
    static let hips: UInt16 = 1
    static let torso: UInt16 = 2
    static let head: UInt16 = 3
    static let armL: UInt16 = 4
    static let forearmL: UInt16 = 5
    static let armR: UInt16 = 6
    static let forearmR: UInt16 = 7
    static let thighL: UInt16 = 8
    static let shinL: UInt16 = 9
    static let thighR: UInt16 = 10
    static let shinR: UInt16 = 11
    /// What the right hand holds: a spear, a blade.
    static let heldR: UInt16 = 12
    /// What the left hand holds: a shield, a bow, a lantern's staff.
    static let heldL: UInt16 = 13
    static let cloak: UInt16 = 14
    /// The mattock brought out to gather, put away otherwise.
    static let tool: UInt16 = 15
    /// One thing more, hanging from what `Frame.extraParent` names: an
    /// arrow on the string, a lantern on its hook, a cart behind.
    static let extra: UInt16 = 16
    static let count = 17
}

/// A body's proportions, a unit tall, standing on y = 0 and facing +z; the
/// figure is this scaled by `size`. Left is +x.
struct Frame {
    var size: Float = 0.3
    var knee: Float = 0.27
    var hip: Float = 0.5
    var waist: Float = 0.53
    var shoulder: Float = 0.755
    var elbow: Float = 0.56
    var wrist: Float = 0.4
    var neck: Float = 0.8
    var head: Float = 0.875
    var headRadius: Float = 0.077
    var shoulderX: Float = 0.15
    var hipX: Float = 0.07
    /// How thick the trunk and limbs are.
    var girth: Float = 1
    var extraParent: UInt16 = Limb.heldL
    var extraPivot: Vec3?
    /// Astride a horse: the legs set about its barrel, on the hips.
    var seated = false

    /// Where the hands close, at rest.
    var grip: Float { wrist - 0.045 }
    var handR: Vec3 { Vec3(-shoulderX, grip, 0) }
    var handL: Vec3 { Vec3(shoulderX, grip, 0) }

    /// The rig, its pivots in the model's frame.
    func rig(more: [(name: String, parent: UInt16, pivot: Vec3)] = []) -> Rig {
        let s = size
        var rig = Rig()
        rig.add("hips", pivot: Vec3(0, hip, 0) * s)
        rig.add("torso", parent: Int(Limb.hips), pivot: Vec3(0, waist, 0) * s)
        rig.add("head", parent: Int(Limb.torso), pivot: Vec3(0, neck, 0) * s)
        rig.add("arm left", parent: Int(Limb.torso), pivot: Vec3(shoulderX, shoulder, 0) * s)
        rig.add("forearm left", parent: Int(Limb.armL), pivot: Vec3(shoulderX, elbow, 0) * s)
        rig.add("arm right", parent: Int(Limb.torso), pivot: Vec3(-shoulderX, shoulder, 0) * s)
        rig.add("forearm right", parent: Int(Limb.armR), pivot: Vec3(-shoulderX, elbow, 0) * s)
        rig.add("thigh left", parent: Int(Limb.hips), pivot: Vec3(hipX, hip, 0) * s)
        rig.add("shin left", parent: Int(Limb.thighL), pivot: Vec3(hipX, knee, 0) * s)
        rig.add("thigh right", parent: Int(Limb.hips), pivot: Vec3(-hipX, hip, 0) * s)
        rig.add("shin right", parent: Int(Limb.thighR), pivot: Vec3(-hipX, knee, 0) * s)
        rig.add("held right", parent: Int(Limb.forearmR), pivot: handR * s)
        rig.add("held left", parent: Int(Limb.forearmL), pivot: handL * s)
        rig.add("cloak", parent: Int(Limb.torso), pivot: Vec3(0, shoulder, -0.08) * s)
        rig.add("tool", parent: Int(Limb.forearmR), pivot: handR * s)
        rig.add("extra", parent: Int(extraParent), pivot: (extraPivot ?? handL) * s)
        for part in more {
            rig.add(part.name, parent: Int(part.parent), pivot: part.pivot * s)
        }
        return rig
    }
}

/// What a person wears, from the boots up.
struct Outfit {
    enum Headgear {
        case bare
        /// A close cap of leather or cloth.
        case cap(Vec3)
        /// A hood falling to the shoulders.
        case hood(Vec3, Material)
        /// A brimmed iron hat.
        case kettle
        /// A pointed helm with a nose guard.
        case nasal
        /// A barrel helm with a slit to see by.
        case greatHelm
        /// A barrel helm with the House's plume along its crown.
        case crested
    }

    var skin = Palette.skin
    var hands = Palette.skin
    var tunic = Palette.wool
    var tunicMaterial = Material.plain
    var sleeves = Palette.wool
    var sleevesMaterial = Material.plain
    var hose = Palette.woolDark
    var shins = Palette.leatherDark
    var shinsMaterial = Material.plain
    var boots = Palette.leatherDark
    /// A coat's skirt to the knee: its colour, material, and how low it hangs.
    var skirt: (color: Vec3, material: Material, hem: Float)?
    var belt: (color: Vec3, material: Material)? = (Palette.leather, .plain)
    var head = Headgear.bare
    var hair = Palette.hair
    /// Plates on the shoulders.
    var pauldrons: (color: Vec3, material: Material)?
    /// The House's tabard over the chest and back.
    var tabard = false
    /// A mantle over the shoulders: its colour and material.
    var mantle: (color: Vec3, material: Material)?
    /// The House's cloak, hanging to this height.
    var cloak: Float?
}

/// Builds people: their bodies in their dress, and what they carry. Built
/// lean, for figures are drawn by the hundred: limbs of four faces, joints
/// left open where another solid hides them.
enum Person {
    /// The body in a unit's height, each piece on its part of the rig.
    static func body(_ b: inout MeshBuilder, _ f: Frame, _ o: Outfit) {
        let g = f.girth
        if f.seated {
            // Astride, the legs go out round the horse's barrel and down its flanks.
            for side in [Float(1), -1] {
                let hip = Vec3(f.hipX * side, f.hip, 0), knee = Vec3(0.2 * side, f.hip - 0.07, 0.17)
                let ankle = Vec3(0.21 * side, f.hip - 0.36, 0.07)
                b.with(part: Limb.hips) {
                    $0.limb(from: hip, to: knee, radius: 0.058 * g, topRadius: 0.05 * g, color: o.hose)
                    $0.with(material: o.shinsMaterial) {
                        $0.limb(from: knee, to: ankle, radius: 0.048 * g, topRadius: 0.04 * g, color: o.shins)
                    }
                    $0.box(min: ankle + Vec3(-0.035, -0.04, -0.04), max: ankle + Vec3(0.035, 0.02, 0.09), color: o.boots)
                }
            }
        } else {
            for side in [Float(1), -1] {
                let x = f.hipX * side
                b.with(part: side > 0 ? Limb.thighL : Limb.thighR) {
                    $0.limb(from: Vec3(x, f.hip + 0.03, 0), to: Vec3(x, f.knee - 0.01, 0), radius: 0.06 * g, topRadius: 0.05 * g,
                            color: o.hose)
                }
                b.with(part: side > 0 ? Limb.shinL : Limb.shinR, material: o.shinsMaterial) {
                    $0.limb(from: Vec3(x, f.knee + 0.02, 0), to: Vec3(x, 0.05, 0), radius: 0.049 * g, topRadius: 0.041 * g,
                            color: o.shins)
                }
                b.with(part: side > 0 ? Limb.shinL : Limb.shinR) {
                    $0.box(min: Vec3(x - 0.042 * g, 0, -0.045), max: Vec3(x + 0.042 * g, 0.065, 0.088), color: o.boots)
                }
            }
        }
        // The hips and the coat's skirt.
        b.with(part: Limb.hips) {
            $0.place(.scale(Vec3(1, 1, 0.78))) {
                $0.tube([(0.1 * g, f.hip - 0.07), (0.12 * g, f.hip), (0.113 * g, f.waist + 0.03)], sides: 5, color: o.hose)
            }
            if let skirt = o.skirt {
                $0.with(material: skirt.material) {
                    $0.place(.scale(Vec3(1, 1, 0.82))) {
                        $0.tube([(0.122 * g, f.waist + 0.02), (0.14 * g, f.hip - 0.05), (0.168 * g, skirt.hem)], sides: 6,
                                color: skirt.color)
                    }
                }
            }
            if let belt = o.belt {
                $0.with(material: belt.material) {
                    $0.place(.scale(Vec3(1, 1, 0.8))) {
                        $0.tube([(0.13 * g, f.waist - 0.022), (0.13 * g, f.waist + 0.016)], sides: 6, color: belt.color)
                    }
                }
            }
        }
        // The trunk, closing to the neck.
        b.with(part: Limb.torso, material: o.tunicMaterial) {
            $0.place(.scale(Vec3(1, 1, 0.74))) {
                $0.tube([(0.113 * g, f.waist), (0.128 * g, f.waist + 0.1), (0.143 * g, f.shoulder - 0.04),
                         (0.118 * g, f.shoulder + 0.02), (0, f.neck + 0.01)], sides: 6, color: o.tunic)
            }
        }
        if o.tabard {
            b.with(part: Limb.torso, material: .house) {
                let w = 0.088 * g
                $0.sheet([Vec3(-w, f.hip - 0.1, 0.098 * g), Vec3(w, f.hip - 0.1, 0.098 * g), Vec3(w, f.shoulder - 0.03, 0.098 * g),
                          Vec3(-w, f.shoulder - 0.03, 0.098 * g)], normal: Vec3(0, 0, 1), thickness: 0.01, color: Palette.house)
                $0.face([Vec3(w, f.hip - 0.06, -0.098 * g), Vec3(-w, f.hip - 0.06, -0.098 * g),
                         Vec3(-w, f.shoulder - 0.03, -0.098 * g), Vec3(w, f.shoulder - 0.03, -0.098 * g)], outward: Vec3(0, 0, -1),
                        color: Palette.house)
            }
        }
        if let mantle = o.mantle {
            b.with(part: Limb.torso, material: mantle.material) {
                $0.place(.scale(Vec3(1, 1, 0.8))) {
                    $0.tube([(0.195 * g, f.shoulder - 0.1), (0.155 * g, f.shoulder + 0.01), (0, f.neck + 0.02)], sides: 6,
                            color: mantle.color)
                }
            }
        }
        if let hem = o.cloak {
            b.with(part: Limb.cloak, material: .house, sway: 0.6) {
                $0.swayRange = (0, f.shoulder - hem)
                $0.beam(from: Vec3(0, f.shoulder + 0.02, -0.088 * g), to: Vec3(0, hem, -0.175 * g), width: 0.31 * g, depth: 0.025,
                        color: Palette.house)
            }
        }
        // Arms: sleeve, forearm, hand.
        for side in [Float(1), -1] {
            let x = f.shoulderX * side
            b.with(part: side > 0 ? Limb.armL : Limb.armR, material: o.sleevesMaterial) {
                $0.limb(from: Vec3(x, f.shoulder + 0.03, 0), to: Vec3(x, f.elbow - 0.01, 0), radius: 0.05 * g, topRadius: 0.043 * g,
                        color: o.sleeves)
            }
            b.with(part: side > 0 ? Limb.forearmL : Limb.forearmR, material: o.sleevesMaterial) {
                $0.limb(from: Vec3(x, f.elbow + 0.015, 0), to: Vec3(x, f.wrist, 0), radius: 0.043 * g, topRadius: 0.036 * g,
                        color: o.sleeves)
            }
            b.with(part: side > 0 ? Limb.forearmL : Limb.forearmR) {
                $0.place(.translation(Vec3(x, f.wrist + 0.01, 0.005)) * .rotationX(.pi)) {
                    $0.cone(sides: 3, radius: 0.04, to: 0.09, color: o.hands)
                }
            }
            if let pauldron = o.pauldrons {
                b.with(part: side > 0 ? Limb.armL : Limb.armR, material: pauldron.material) {
                    $0.place(.translation(Vec3(x + 0.012 * side, f.shoulder - 0.05, 0))) {
                        $0.tube([(0.078 * g, 0), (0.074 * g, 0.05), (0, 0.105)], sides: 5, color: pauldron.color)
                    }
                }
            }
        }
        b.with(part: Limb.head) {
            $0.sphere(center: Vec3(0, f.head, 0.006), radius: f.headRadius, rings: 3, sides: 5, color: o.skin)
        }
        headgear(&b, f, o)
    }

    static func headgear(_ b: inout MeshBuilder, _ f: Frame, _ o: Outfit) {
        let h = f.head, r = f.headRadius
        b.with(part: Limb.head) {
            switch o.head {
            case .bare:
                $0.place(.translation(Vec3(0, 0, -0.014))) {
                    $0.tube([(r * 1.08, h - 0.012), (r * 0.96, h + 0.045), (0, h + r * 1.08)], sides: 5, color: o.hair)
                }
            case .cap(let color):
                $0.tube([(r * 1.12, h + 0.004), (r * 1.03, h + 0.05), (0, h + r * 1.2)], sides: 6, color: color)
            case .hood(let color, let material):
                $0.with(material: material) {
                    $0.place(.translation(Vec3(0, 0, -0.024))) {
                        $0.tube([(r * 1.36, h - 0.08), (r * 1.3, h + 0.02), (r * 0.9, h + 0.078), (0, h + r * 1.5)], sides: 6,
                                color: color)
                    }
                }
            case .kettle:
                $0.with(material: .metal) {
                    $0.lathe([(r * 1.8, h + 0.014), (r * 1.06, h + 0.032), (r * 0.98, h + 0.072), (0, h + r * 1.34)], sides: 7,
                             color: Palette.iron)
                }
            case .nasal:
                $0.with(material: .metal) {
                    $0.tube([(r * 1.13, h - 0.006), (r * 1.09, h + 0.04), (0, h + r * 1.8)], sides: 6, color: Palette.mail)
                    $0.box(center: Vec3(0, h - 0.02, r * 1.07), size: Vec3(0.02, 0.06, 0.016), color: Palette.mail)
                }
            case .greatHelm, .crested:
                $0.with(material: .metal) {
                    $0.tube([(r * 1.2, h - 0.085), (r * 1.24, h + 0.035), (r * 1.08, h + 0.078), (0, h + r * 1.3)], sides: 6,
                            color: Palette.steel)
                }
                $0.box(center: Vec3(0, h + 0.004, r * 1.14), size: Vec3(0.11, 0.016, 0.02), color: Palette.timberDark)
                if case .crested = o.head {
                    $0.with(material: .house, sway: 0.4) {
                        $0.swayRange = (h + 0.05, h + 0.2)
                        $0.box(min: Vec3(-0.02, h + 0.06, -0.15), max: Vec3(0.02, h + 0.18, 0.07), color: Palette.house)
                    }
                }
            }
        }
    }

    // MARK: What they carry

    /// A spear upright in the right hand, its butt by the foot: plain at
    /// first, then longer-bladed, winged, and pennoned.
    static func spear(_ b: inout MeshBuilder, _ f: Frame, tier: Int) {
        let x = f.handR.x, top: Float = 1.42 + 0.04 * Float(tier)
        b.with(part: Limb.heldR) {
            $0.limb(from: Vec3(x, 0.03, 0), to: Vec3(x, top, 0), radius: 0.018, sides: 4,
                    color: tier >= 3 ? Palette.timberDark : Palette.timber)
            $0.with(material: .metal) {
                let blade: Float = tier == 1 ? 0.12 : 0.15 + 0.012 * Float(tier)
                $0.place(.translation(Vec3(x, top, 0))) {
                    $0.lathe([(0.014, 0), (0.038, blade * 0.3), (0, blade)], sides: 4, color: tier == 1 ? Palette.iron : Palette.steel)
                }
                if tier >= 4 {
                    $0.box(center: Vec3(x, top - 0.01, 0), size: Vec3(0.12, 0.018, 0.02), color: Palette.steel)
                }
            }
            if tier >= 5 {
                $0.flag(at: Vec3(x - 0.01, top - 0.03, 0), width: 0.22, height: 0.1, turn: .pi / 2, tail: true)
            }
        }
    }

    /// A shield on the left arm: it lies flat under the hand at rest and
    /// faces forward once the forearm is raised to carry it.
    static func shield(_ b: inout MeshBuilder, _ f: Frame, tier: Int) {
        let hand = f.handL
        b.with(part: Limb.heldL) {
            // Its face looks down at rest: raising the forearm forward turns it to face the foe.
            $0.place(.translation(hand + Vec3(0.015, -0.045, 0)) * .rotationX(.pi)) {
                switch tier {
                case 2, 3:
                    // Round: of pale planks with the House's rim, then the House's own with an iron boss.
                    $0.with(material: tier == 3 ? .house : .plain) {
                        $0.lathe([(0.16, -0.016), (0.16, 0.014)], sides: 8, color: tier == 3 ? Palette.house : Palette.timberPale)
                    }
                    $0.with(material: tier == 3 ? .metal : .house) {
                        $0.place(.translation(Vec3(0, 0.014, 0))) {
                            if tier == 3 {
                                $0.cone(sides: 5, radius: 0.045, to: 0.04, color: Palette.iron)
                            } else {
                                $0.tube([(0.165, -0.032), (0.165, 0.004)], sides: 8, color: Palette.houseDark)
                            }
                        }
                    }
                default:
                    // Kite-shaped, the House's on a steel ground; its point hangs down once raised.
                    $0.place(.rotationX(-.pi / 2)) {
                        let outline = [Vec3(-0.15, 0.2, 0), Vec3(0, 0.23, 0), Vec3(0.15, 0.2, 0), Vec3(0.15, -0.05, 0), Vec3(0, -0.31, 0),
                                       Vec3(-0.15, -0.05, 0)]
                        $0.with(material: .house) {
                            $0.face(outline.map { $0 * 0.86 + Vec3(0, 0, 0.022) }, outward: Vec3(0, 0, 1), color: Palette.house)
                        }
                        $0.with(material: .metal) {
                            $0.sheet(outline, normal: Vec3(0, 0, 1), thickness: 0.03, color: Palette.steel, back: Palette.iron)
                            if tier >= 5 {
                                $0.place(.translation(Vec3(0, 0.03, 0.022)) * .rotationX(.pi / 2)) {
                                    $0.cone(sides: 4, radius: 0.04, to: 0.03, color: Palette.gold)
                                }
                            }
                        }
                    }
                }
            }
        }
    }

    /// A bow in the left hand, upright, its string toward the archer; it
    /// grows longer and is tipped with steel from the fourth tier.
    static func bow(_ b: inout MeshBuilder, _ f: Frame, tier: Int) {
        let hand = f.handL
        let half: Float = 0.4 + 0.06 * Float(min(tier, 4))
        let bend: Float = tier >= 5 ? 0.13 : 0.1
        let wood = tier >= 4 ? Palette.timberDark : Palette.timber
        var points: [Vec3] = []
        for index in -3...3 {
            let t = Float(index) / 3
            points.append(hand + Vec3(0.01, t * half, bend * (1 - t * t)))
        }
        if tier >= 5 {
            // Recurved: the tips turn forward.
            points[0] += Vec3(0, 0.02, 0.07)
            points[6] += Vec3(0, -0.02, 0.07)
        }
        b.with(part: Limb.heldL) {
            for index in 0..<(points.count - 1) {
                let thick: Float = abs(Float(index) - 2.5) < 1 ? 0.034 : 0.026
                $0.limb(from: points[index], to: points[index + 1], radius: thick, topRadius: thick, sides: 3, color: wood)
            }
            if tier >= 4 {
                $0.with(material: .metal) {
                    for tip in [points[0], points[6]] {
                        $0.place(.translation(tip - Vec3(0, 0.03, 0))) {
                            $0.cone(sides: 3, radius: 0.03, to: 0.06, color: Palette.steel)
                        }
                    }
                }
            }
        }
        // The string, straight between the tips, set aside while drawn.
        b.with(part: Bowman.string) {
            $0.limb(from: points[0], to: points[6], radius: 0.006, sides: 3, color: Palette.linen)
        }
        // On the string while drawn: the arrow, and the string pulled back to it.
        b.with(part: Limb.extra) {
            let nock = hand + Vec3(0.01, 0, -0.5), head = hand + Vec3(0.01, 0, bend + 0.07)
            $0.limb(from: nock, to: head, radius: 0.01, sides: 3, color: Palette.timberPale)
            $0.with(material: .metal) {
                $0.place(.translation(head) * .rotationX(.pi / 2)) {
                    $0.cone(sides: 3, radius: 0.022, to: 0.06, color: Palette.steel)
                }
            }
            $0.limb(from: nock, to: points[0], radius: 0.006, sides: 3, color: Palette.linen)
            $0.limb(from: nock, to: points[6], radius: 0.006, sides: 3, color: Palette.linen)
        }
    }

    /// A quiver on the back, its arrows' fletchings showing.
    static func quiver(_ b: inout MeshBuilder, _ f: Frame, color: Vec3) {
        b.with(part: Limb.torso) {
            let foot = Vec3(0.08, f.hip - 0.02, -0.12), mouth = Vec3(-0.05, f.shoulder + 0.07, -0.15)
            $0.place(.translation(foot) * Mat4.aligningUp(to: mouth - foot)) {
                $0.lathe([(0.042, 0), (0.046, (mouth - foot).length)], sides: 5, color: color)
            }
            for index in 0..<3 {
                let spread = Vec3(Float(index - 1) * 0.026, 0.08, Float(index % 2) * 0.014)
                $0.sheet([mouth, mouth + spread + Vec3(0.012, 0, 0), mouth + spread + Vec3(0.012, 0.03, 0)], normal: Vec3(0, 0, 1),
                         color: Palette.linen)
            }
        }
    }

    /// The mattock a figure brings out to gather: its haft runs on from
    /// the hand, down and forward at rest, its head across the haft's end.
    static func mattock(_ b: inout MeshBuilder, _ f: Frame) {
        let hand = f.handR
        let along = Vec3(0, -0.6, 0.8), across = Vec3(0, 0.8, 0.6)
        let end = hand + along * 0.5
        b.with(part: Limb.tool) {
            $0.limb(from: hand - along * 0.06, to: end, radius: 0.016, sides: 3, color: Palette.timberPale)
            $0.with(material: .metal) {
                $0.beam(from: end - across * 0.14, to: end + across * 0.1, width: 0.032, depth: 0.04, color: Palette.iron)
            }
        }
    }
}

/// The parts an archer adds to a person.
enum Bowman {
    /// The bow's string at rest, put away while it is drawn.
    static let string: UInt16 = 17
}
