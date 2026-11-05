import Foundation

/// A person as they are seen close: fine work over the lean body that
/// stands for them far off, kept after it in the mesh for the renderer to
/// leave off at a distance. Rounded shells a hair outside the faceted
/// trunk, limbs and head give them a true silhouette; then the face, hands
/// with their thumbs, shaped boots with soles and cuffs, the joints, a
/// belt's buckle and gear, and the work of each kind of helm.
extension Person {
    /// How far a shell stands outside the solid it rounds.
    static let shell: Float = 1.06

    static func detail(_ b: inout MeshBuilder, _ f: Frame, _ o: Outfit) {
        b.fine {
            limbs(&$0, f, o)
            trunk(&$0, f, o)
            head(&$0, f, o)
            helm(&$0, f, o)
        }
    }

    /// Thighs, shins, arms and forearms rounded; knees, elbows and
    /// shoulders filled; boots shaped and soled; hands with fingers and thumbs.
    static func limbs(_ b: inout MeshBuilder, _ f: Frame, _ o: Outfit) {
        let g = f.girth, s = shell
        if f.seated {
            for side in [Float(1), -1] {
                let hip = Vec3(f.hipX * side, f.hip, 0), knee = Vec3(0.2 * side, f.hip - 0.07, 0.17)
                let ankle = Vec3(0.21 * side, f.hip - 0.36, 0.07)
                b.with(part: Limb.hips) {
                    $0.limb(from: hip, to: knee, radius: 0.058 * g * s, topRadius: 0.05 * g * s, sides: 8, color: o.hose)
                    $0.sphere(center: knee, radius: 0.052 * g, rings: 3, sides: 8, color: o.hose)
                    $0.with(material: o.shinsMaterial) {
                        $0.limb(from: knee, to: ankle, radius: 0.048 * g * s, topRadius: 0.04 * g * s, sides: 8, color: o.shins)
                    }
                    boot(&$0, at: ankle + Vec3(0, -0.04, 0.025), toward: Vec3(0, 0, 1), g: g, o: o)
                    // The iron stirrup under the boot.
                    $0.with(material: .metal) {
                        $0.box(center: ankle + Vec3(0, -0.05, 0.02), size: Vec3(0.07, 0.008, 0.05), color: Palette.iron)
                        $0.limb(from: ankle + Vec3(0.03 * side, -0.05, 0.02), to: ankle + Vec3(0.02 * side, 0.05, 0.01), radius: 0.005,
                                sides: 3, color: Palette.iron)
                    }
                }
            }
        } else {
            for side in [Float(1), -1] {
                let x = f.hipX * side
                b.with(part: side > 0 ? Limb.thighL : Limb.thighR) {
                    $0.limb(from: Vec3(x, f.hip + 0.03, 0), to: Vec3(x, f.knee - 0.01, 0), radius: 0.06 * g * s, topRadius: 0.05 * g * s,
                            sides: 8, color: o.hose)
                }
                b.with(part: side > 0 ? Limb.shinL : Limb.shinR, material: o.shinsMaterial) {
                    $0.sphere(center: Vec3(x, f.knee + 0.005, 0.004), radius: 0.052 * g, rings: 3, sides: 8, color: o.shins)
                    $0.limb(from: Vec3(x, f.knee + 0.02, 0), to: Vec3(x, 0.06, 0), radius: 0.049 * g * s, topRadius: 0.041 * g * s,
                            sides: 8, color: o.shins)
                    if o.shinsMaterial == .metal {
                        // A knee cop with its wing, and the greave's ridge down the shin.
                        $0.place(.translation(Vec3(x, f.knee + 0.01, 0.045 * g)) * .rotationX(.pi / 2)) {
                            $0.cone(sides: 8, radius: 0.04 * g, to: 0.025, color: o.shins)
                        }
                        $0.box(center: Vec3(x, (f.knee + 0.06) / 2, 0.047 * g), size: Vec3(0.012, f.knee - 0.08, 0.01), color: o.shins * 1.15)
                    }
                }
                b.with(part: side > 0 ? Limb.shinL : Limb.shinR) {
                    boot(&$0, at: Vec3(x, 0, 0.02), toward: Vec3(0, 0, 1), g: g, o: o)
                }
            }
        }
        for side in [Float(1), -1] {
            let x = f.shoulderX * side
            b.with(part: side > 0 ? Limb.armL : Limb.armR, material: o.sleevesMaterial) {
                $0.sphere(center: Vec3(x, f.shoulder, 0), radius: 0.056 * g, rings: 4, sides: 8, color: o.sleeves)
                $0.limb(from: Vec3(x, f.shoulder + 0.03, 0), to: Vec3(x, f.elbow - 0.01, 0), radius: 0.05 * g * s, topRadius: 0.043 * g * s,
                        sides: 8, color: o.sleeves)
            }
            b.with(part: side > 0 ? Limb.forearmL : Limb.forearmR, material: o.sleevesMaterial) {
                $0.sphere(center: Vec3(x, f.elbow + 0.004, 0), radius: 0.046 * g, rings: 3, sides: 8, color: o.sleeves)
                $0.limb(from: Vec3(x, f.elbow + 0.015, 0), to: Vec3(x, f.wrist + 0.01, 0), radius: 0.043 * g * s, topRadius: 0.036 * g * s,
                        sides: 8, color: o.sleeves)
                if o.sleevesMaterial == .metal {
                    // The couter over the elbow, and a cuffed gauntlet.
                    $0.place(.translation(Vec3(x, f.elbow, -0.04 * g)) * .rotationX(-.pi / 2)) {
                        $0.cone(sides: 8, radius: 0.036 * g, to: 0.022, color: o.sleeves * 1.1)
                    }
                    $0.place(.translation(Vec3(x, 0, 0))) {
                        $0.tube([(0.046 * g, f.wrist + 0.04), (0.04 * g, f.wrist - 0.002)], sides: 8, color: o.sleeves)
                    }
                } else {
                    // A turned-back cuff at the wrist.
                    $0.place(.translation(Vec3(x, 0, 0))) {
                        $0.tube([(0.045 * g, f.wrist + 0.03), (0.042 * g, f.wrist + 0.004)], sides: 8, color: o.sleeves * 0.82)
                    }
                }
            }
            b.with(part: side > 0 ? Limb.forearmL : Limb.forearmR) {
                // The hand: palm and fingers closed about a grip, the thumb across them.
                let hand = Vec3(x, f.wrist - 0.04, 0.008)
                $0.place(.translation(hand) * .scale(Vec3(0.036, 0.048, 0.034))) {
                    $0.sphere(center: .zero, radius: 1, rings: 3, sides: 8, color: o.hands)
                }
                $0.box(center: hand + Vec3(0, -0.012, 0.028), size: Vec3(0.05, 0.03, 0.016), color: o.hands * 0.94)
                $0.limb(from: hand + Vec3(-0.022 * side, 0.02, 0.012), to: hand + Vec3(-0.018 * side, -0.012, 0.036), radius: 0.009,
                        sides: 5, color: o.hands)
            }
        }
    }

    /// A boot that fits the foot: a rounded toe, a heel, a sole of darker
    /// leather under it all, and a cuff turned down at the top.
    static func boot(_ b: inout MeshBuilder, at foot: Vec3, toward: Vec3, g: Float, o: Outfit) {
        b.place(.translation(foot + Vec3(0, 0.03, 0.035)) * .scale(Vec3(0.045 * g, 0.032, 0.058))) {
            $0.sphere(center: .zero, radius: 1, rings: 3, sides: 8, color: o.boots)
        }
        b.box(center: foot + Vec3(0, 0.035, -0.045), size: Vec3(0.08 * g, 0.06, 0.03), color: o.boots)
        b.box(center: foot + Vec3(0, 0.005, 0.02), size: Vec3(0.094 * g, 0.012, 0.15), color: Palette.leatherDark * 0.6)
        b.place(.translation(Vec3(foot.x, foot.y, foot.z - 0.02))) {
            $0.tube([(0.054 * g, 0.068), (0.058 * g, 0.1)], sides: 8, color: o.boots * 1.12)
        }
    }

    /// The trunk rounded, the coat's skirt and the hips with it; the
    /// tabard laid over the rounding with the House's charge on it; the
    /// mantle, the collar, and the belt's buckle, purse and knife.
    static func trunk(_ b: inout MeshBuilder, _ f: Frame, _ o: Outfit) {
        let g = f.girth, s: Float = 1.035
        b.with(part: Limb.hips) {
            $0.place(.scale(Vec3(1, 1, 0.78))) {
                $0.tube([(0.1 * g * s, f.hip - 0.07), (0.12 * g * s, f.hip), (0.113 * g * s, f.waist + 0.03)], sides: 12, color: o.hose)
            }
            if let skirt = o.skirt {
                $0.with(material: skirt.material) {
                    $0.place(.scale(Vec3(1, 1, 0.82))) {
                        $0.tube([(0.122 * g * s, f.waist + 0.02), (0.14 * g * s, f.hip - 0.05), (0.168 * g * s, skirt.hem)], sides: 14,
                                color: skirt.color)
                        // A hem of darker cloth, or the mail's rings closing.
                        $0.tube([(0.17 * g * s, skirt.hem + 0.022), (0.171 * g * s, skirt.hem - 0.002)], sides: 14, color: skirt.color * 0.72)
                    }
                }
            }
            if let belt = o.belt {
                $0.with(material: belt.material) {
                    $0.place(.scale(Vec3(1, 1, 0.8))) {
                        $0.tube([(0.134 * g, f.waist - 0.024), (0.134 * g, f.waist + 0.018)], sides: 14, color: belt.color)
                    }
                }
                let front = 0.134 * g * 0.8
                $0.with(material: .metal) {
                    $0.box(center: Vec3(0, f.waist - 0.003, front + 0.004), size: Vec3(0.04, 0.036, 0.01), color: Palette.bronze)
                }
                // A purse at the left hip, a knife in its sheath at the right.
                $0.box(center: Vec3(0.1 * g, f.waist - 0.05, 0.05 * g), size: Vec3(0.045, 0.055, 0.03), color: Palette.leather)
                $0.box(center: Vec3(0.1 * g, f.waist - 0.02, 0.05 * g), size: Vec3(0.05, 0.012, 0.034), color: Palette.leatherDark)
                $0.limb(from: Vec3(-0.11 * g, f.waist - 0.02, 0.045 * g), to: Vec3(-0.125 * g, f.waist - 0.15, 0.065 * g), radius: 0.012,
                        topRadius: 0.006, sides: 5, color: Palette.leatherDark)
                $0.with(material: .metal) {
                    $0.limb(from: Vec3(-0.11 * g, f.waist - 0.02, 0.045 * g), to: Vec3(-0.106 * g, f.waist + 0.03, 0.04 * g), radius: 0.007,
                            sides: 5, color: Palette.timberDark)
                    $0.sphere(center: Vec3(-0.106 * g, f.waist + 0.035, 0.04 * g), radius: 0.011, rings: 2, sides: 5, color: Palette.bronze)
                }
            }
        }
        b.with(part: Limb.torso, material: o.tunicMaterial) {
            $0.place(.scale(Vec3(1, 1, 0.74))) {
                $0.tube([(0.113 * g * s, f.waist), (0.128 * g * s, f.waist + 0.1), (0.143 * g * s, f.shoulder - 0.04),
                         (0.118 * g * s, f.shoulder + 0.02), (0.05 * g, f.neck - 0.01)], sides: 14, color: o.tunic)
            }
            if o.tunicMaterial == .metal {
                // A breastplate's ridge, and the lames of the fauld below it.
                $0.box(center: Vec3(0, f.waist + 0.12, 0.143 * g * 0.74 * s + 0.002), size: Vec3(0.012, 0.16, 0.012), color: o.tunic * 1.15)
                for lame in 0..<2 {
                    let y = f.waist + 0.012 - Float(lame) * 0.03
                    $0.place(.scale(Vec3(1, 1, 0.76))) {
                        $0.tube([(0.125 * g * s, y + 0.02), (0.13 * g * s, y - 0.01)], sides: 14, color: o.tunic * (lame == 0 ? 1.05 : 0.92))
                    }
                }
            }
        }
        b.with(part: Limb.torso) {
            // The collar, turned about the neck.
            $0.tube([(0.07 * g, f.shoulder + 0.01), (0.056 * g, f.neck - 0.005)], sides: 12, color: o.tunic * 0.8)
        }
        if o.tabard {
            b.with(part: Limb.torso, material: .house) {
                let w: Float = 0.092 * g, z = 0.143 * g * 0.74 * s + 0.006
                $0.sheet([Vec3(-w, f.hip - 0.1, z), Vec3(w, f.hip - 0.1, z), Vec3(w * 1.05, f.shoulder - 0.03, z),
                          Vec3(-w * 1.05, f.shoulder - 0.03, z)], normal: Vec3(0, 0, 1), thickness: 0.006, color: Palette.house)
                $0.face([Vec3(w, f.hip - 0.06, -z), Vec3(-w, f.hip - 0.06, -z), Vec3(-w, f.shoulder - 0.03, -z), Vec3(w, f.shoulder - 0.03, -z)],
                        outward: Vec3(0, 0, -1), color: Palette.house)
                // The House's charge, a lozenge on the breast, and the tabard's hem.
                let c = Vec3(0, f.waist + 0.12, z + 0.005)
                $0.face([c + Vec3(0, 0.055, 0), c + Vec3(-0.04, 0, 0), c + Vec3(0, -0.055, 0), c + Vec3(0.04, 0, 0)], outward: Vec3(0, 0, 1),
                        color: Palette.houseDark)
                $0.box(center: Vec3(0, f.hip - 0.09, z), size: Vec3(2 * w, 0.014, 0.008), color: Palette.gold * 0.8)
            }
        }
        if let mantle = o.mantle {
            b.with(part: Limb.torso, material: mantle.material) {
                $0.place(.scale(Vec3(1, 1, 0.8))) {
                    $0.tube([(0.196 * g, f.shoulder - 0.1), (0.158 * g, f.shoulder + 0.01), (0.06 * g, f.neck + 0.01)], sides: 14,
                            color: mantle.color)
                    $0.tube([(0.196 * g, f.shoulder - 0.098), (0.19 * g, f.shoulder - 0.12)], sides: 14, color: mantle.color * 0.75)
                }
            }
        }
        if let pauldron = o.pauldrons {
            for side in [Float(1), -1] {
                let x = f.shoulderX * side
                b.with(part: side > 0 ? Limb.armL : Limb.armR, material: pauldron.material) {
                    $0.place(.translation(Vec3(x + 0.012 * side, f.shoulder - 0.05, 0))) {
                        $0.tube([(0.07 * g, 0), (0.068 * g, 0.05), (0.036 * g, 0.1), (0, 0.108)], sides: 10, color: pauldron.color)
                        // The lames below it.
                        $0.tube([(0.062 * g, -0.03), (0.066 * g, 0.004)], sides: 10, color: pauldron.color * 0.88)
                    }
                }
            }
        }
        if o.cloak != nil {
            // The cloak's clasps at the shoulders, and a fold along its fall.
            b.with(part: Limb.torso, material: .metal) {
                for side in [Float(1), -1] {
                    $0.sphere(center: Vec3(0.085 * side * g, f.shoulder + 0.01, 0.06 * g), radius: 0.016, rings: 2, sides: 6, color: Palette.gold)
                }
            }
        }
    }

    /// The head rounded under its hair or helm, and the face: brow, eyes,
    /// nose, mouth and ears; a beard on some.
    static func head(_ b: inout MeshBuilder, _ f: Frame, _ o: Outfit) {
        let h = f.head, r = f.headRadius
        b.with(part: Limb.head) {
            $0.limb(from: Vec3(0, f.neck - 0.04, 0), to: Vec3(0, h - r * 0.5, 0.004), radius: 0.037 * f.girth, topRadius: 0.033 * f.girth,
                    sides: 8, color: o.skin)
            $0.place(.translation(Vec3(0, h, 0.006)) * .scale(Vec3(0.97, 1.06, 1))) {
                $0.sphere(center: .zero, radius: r * 1.04, rings: 6, sides: 10, color: o.skin)
            }
            switch o.head {
            case .greatHelm, .crested:
                return
            default:
                break
            }
            let front = r * 1.02 + 0.006
            // The brow, and the eyes under it.
            $0.box(center: Vec3(0, h + 0.02, front - 0.004), size: Vec3(0.066, 0.011, 0.012), color: o.hair * 0.85)
            for side in [Float(1), -1] {
                $0.box(center: Vec3(0.022 * side, h + 0.006, front - 0.003), size: Vec3(0.017, 0.009, 0.006), color: Palette.barkBlack)
                $0.box(center: Vec3(r * 1.0 * side, h - 0.002, 0), size: Vec3(0.012, 0.032, 0.022), color: o.skin * 0.92)
            }
            // The nose, its ridge and tip.
            $0.place(.translation(Vec3(0, h - 0.006, front)) * .rotationX(.pi / 2 + 0.35)) {
                $0.cone(sides: 4, radius: 0.012, to: 0.026, color: o.skin * 0.96)
            }
            $0.box(center: Vec3(0, h - 0.034, front - 0.006), size: Vec3(0.028, 0.006, 0.006), color: o.skin * 0.7)
            // A beard on the hard-bitten, in their hair's colour.
            if o.hair != Palette.hair || o.shinsMaterial == .metal {
                $0.place(.translation(Vec3(0, h - 0.04, front - 0.022)) * .scale(Vec3(0.05, 0.036, 0.03))) {
                    $0.sphere(center: .zero, radius: 1, rings: 3, sides: 8, color: o.hair)
                }
            }
        }
    }

    /// Each helm's work: brims rolled, rivets, a mail curtain about the
    /// neck, breaths in a great helm's face, a hood's fall.
    static func helm(_ b: inout MeshBuilder, _ f: Frame, _ o: Outfit) {
        let h = f.head, r = f.headRadius
        b.with(part: Limb.head) {
            switch o.head {
            case .bare:
                $0.place(.translation(Vec3(0, 0, -0.016))) {
                    $0.tube([(r * 1.16, h - 0.02), (r * 1.13, h + 0.03), (r * 0.98, h + r * 0.86), (r * 0.56, h + r * 1.14), (0, h + r * 1.22)],
                            sides: 10, color: o.hair)
                }
                // Hair to the nape, and over the ears.
                $0.box(center: Vec3(0, h - 0.03, -r * 0.85), size: Vec3(0.09, 0.06, 0.03), color: o.hair)
            case .cap(let color):
                $0.tube([(r * 1.15, h + 0.002), (r * 1.06, h + 0.05), (r * 0.6, h + r * 1.1), (0, h + r * 1.24)], sides: 10, color: color)
                $0.tube([(r * 1.18, h - 0.004), (r * 1.18, h + 0.014)], sides: 10, color: color * 0.75)
            case .hood(let color, let material):
                $0.with(material: material) {
                    $0.place(.translation(Vec3(0, 0, -0.026))) {
                        $0.tube([(r * 1.4, h - 0.08), (r * 1.34, h + 0.02), (r * 0.94, h + 0.08), (0, h + r * 1.54)], sides: 12, color: color)
                    }
                    // Its tail down the back.
                    $0.limb(from: Vec3(0, h + 0.04, -r * 1.3), to: Vec3(0, h - 0.16, -r * 1.6), radius: 0.02, topRadius: 0.008, sides: 5,
                            color: color)
                }
            case .kettle:
                $0.with(material: .metal) {
                    $0.lathe([(r * 1.84, h + 0.012), (r * 1.84, h + 0.02), (r * 1.09, h + 0.034), (r * 1.01, h + 0.074), (r * 0.5, h + r * 1.3),
                              (0, h + r * 1.38)], sides: 14, color: Palette.iron)
                    for index in 0..<8 {
                        let a = Float(index) * .pi / 4
                        $0.sphere(center: Vec3(cos(a) * r * 1.1, h + 0.04, sin(a) * r * 1.1), radius: 0.006, rings: 2, sides: 4, color: Palette.steel)
                    }
                }
            case .nasal:
                $0.with(material: .metal) {
                    $0.tube([(r * 1.16, h - 0.008), (r * 1.12, h + 0.04), (r * 0.6, h + r * 1.5), (0, h + r * 1.84)], sides: 12, color: Palette.mail)
                    $0.tube([(r * 1.2, h - 0.01), (r * 1.2, h + 0.008)], sides: 12, color: Palette.steel)
                    $0.box(center: Vec3(0, h - 0.024, r * 1.12), size: Vec3(0.018, 0.064, 0.012), color: Palette.steel)
                    // The mail curtain to the shoulders.
                    $0.place(.translation(Vec3(0, 0, -0.01))) {
                        $0.tube([(r * 1.18, h - 0.006), (r * 1.34, h - 0.09), (r * 1.6, f.neck - 0.03)], sides: 12, color: Palette.mail * 0.85)
                    }
                }
            case .greatHelm, .crested:
                $0.with(material: .metal) {
                    $0.tube([(r * 1.24, h - 0.088), (r * 1.28, h + 0.035), (r * 1.12, h + 0.08), (r * 0.6, h + r * 1.26), (0, h + r * 1.34)],
                            sides: 14, color: Palette.steel)
                    // The brow band, the cross over the face, and its breaths.
                    $0.tube([(r * 1.3, h + 0.028), (r * 1.3, h + 0.044)], sides: 14, color: o.head == .crested ? Palette.gold : Palette.iron)
                    $0.box(center: Vec3(0, h - 0.03, r * 1.27), size: Vec3(0.014, 0.08, 0.01), color: Palette.iron)
                    for index in 0..<3 {
                        $0.box(center: Vec3(0.03, h - 0.04 - Float(index) * 0.014, r * 1.26), size: Vec3(0.02, 0.005, 0.006), color: Palette.barkBlack)
                    }
                }
                $0.box(center: Vec3(0, h + 0.004, r * 1.2), size: Vec3(0.12, 0.016, 0.016), color: Palette.barkBlack)
            }
        }
    }
}

extension Outfit.Headgear: Equatable {
    static func == (a: Outfit.Headgear, b: Outfit.Headgear) -> Bool {
        switch (a, b) {
        case (.bare, .bare), (.kettle, .kettle), (.nasal, .nasal), (.greatHelm, .greatHelm), (.crested, .crested): return true
        case (.cap(let x), .cap(let y)): return x == y
        case (.hood(let x, let m), .hood(let y, let n)): return x == y && m == n
        default: return false
        }
    }
}
