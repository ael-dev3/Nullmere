import Foundation

/// A horse as it is seen close, fine work over the lean one that stands
/// for it far off: its barrel, neck and legs rounded, the chest and the
/// quarters filled, a mane along its crest and a forelock, the head with
/// its jaw, muzzle, eyes and nostrils, a bridle and reins, the saddle's
/// pommel and cantle, its girth and breast strap, joints and hooves, and
/// a tail falling in strands.
extension Riders {
    static func detail(_ b: inout MeshBuilder, _ m: Mount) {
        b.fine {
            $0.with(part: Steed.body) {
                $0.place(.translation(Vec3(0, 0.165, 0)) * .rotationX(.pi / 2) * .scale(Vec3(0.85, 1, 1.12))) {
                    $0.tube([(0, -0.16), (0.03, -0.152), (0.048, -0.13), (0.058, -0.06), (0.058, 0.05), (0.049, 0.104), (0.03, 0.124), (0, 0.133)],
                            sides: 12, color: m.coat)
                }
                // The breast and the quarters, full and round.
                $0.place(.translation(Vec3(0, 0.168, 0.092)) * .scale(Vec3(0.042, 0.05, 0.035))) {
                    $0.sphere(center: .zero, radius: 1, rings: 4, sides: 10, color: m.coat)
                }
                for side in [Float(1), -1] {
                    $0.place(.translation(Vec3(0.022 * side, 0.18, -0.112)) * .scale(Vec3(0.032, 0.05, 0.045))) {
                        $0.sphere(center: .zero, radius: 1, rings: 4, sides: 10, color: m.coat)
                    }
                }
                // The saddle: pommel and cantle, the seat between, its girth and breast strap.
                $0.box(center: Vec3(0, 0.243, 0.03), size: Vec3(0.044, 0.024, 0.014), color: Palette.leatherDark)
                $0.box(center: Vec3(0, 0.246, -0.058), size: Vec3(0.054, 0.032, 0.012), color: Palette.leatherDark)
                $0.box(center: Vec3(0, 0.236, -0.013), size: Vec3(0.052, 0.008, 0.08), color: Palette.leather)
                for side in [Float(1), -1] {
                    $0.box(center: Vec3(0.051 * side, 0.165, 0.0), size: Vec3(0.006, 0.12, 0.016), color: Palette.leatherDark)
                    $0.beam(from: Vec3(0.045 * side, 0.21, 0.06), to: Vec3(0.012 * side, 0.168, 0.124), width: 0.012, depth: 0.005,
                            color: Palette.leatherDark)
                }
                $0.with(material: .metal) {
                    $0.sphere(center: Vec3(0, 0.168, 0.126), radius: 0.008, rings: 2, sides: 5, color: Palette.bronze)
                }
            }
            $0.with(part: Steed.neck) {
                $0.limb(from: Vec3(0, 0.178, 0.072), to: Vec3(0, 0.282, 0.152), radius: 0.037, topRadius: 0.024, sides: 10, color: m.coat)
                $0.place(.translation(Vec3(0, 0.196, 0.082)) * .scale(Vec3(0.034, 0.04, 0.04))) {
                    $0.sphere(center: .zero, radius: 1, rings: 3, sides: 8, color: m.coat)
                }
                if m.barding < 2 {
                    // The mane along the crest, lying a little to one side, in locks.
                    $0.with(sway: 0.25) {
                        for lock in 0..<6 {
                            let t = Float(lock) / 5
                            let at = Vec3(0, 0.215, 0.062) + (Vec3(0, 0.302, 0.14) - Vec3(0, 0.215, 0.062)) * t
                            $0.beam(from: at + Vec3(0, 0.008, 0), to: at + Vec3(0.012, -0.03, -0.008), width: 0.016, depth: 0.007, color: m.mane)
                        }
                    }
                }
                // The reins, from the bit back to the rider's hands.
                for side in [Float(1), -1] {
                    $0.limb(from: Vec3(0.016 * side, 0.24, 0.21), to: Vec3(0.02 * side, 0.252, 0.04), radius: 0.0025, sides: 3,
                            color: Palette.leatherDark)
                }
            }
            $0.with(part: Steed.head) {
                let at = Vec3(0, 0.29, 0.147), along = Vec3(0, -0.055, 0.075).normalized
                $0.place(.translation(at) * Mat4.aligningUp(to: along)) {
                    $0.lathe([(0.028, -0.004), (0.026, 0.03), (0.02, 0.07), (0.018, 0.09), (0.012, 0.097)], sides: 10, color: m.coat)
                }
                // The broad cheeks, the soft muzzle and its nostrils, the eyes.
                for side in [Float(1), -1] {
                    $0.place(.translation(at + along * 0.022 + Vec3(0.015 * side, -0.008, 0)) * .scale(Vec3(0.014, 0.022, 0.024))) {
                        $0.sphere(center: .zero, radius: 1, rings: 3, sides: 8, color: m.coat)
                    }
                    $0.box(center: at + along * 0.02 + Vec3(0.024 * side, 0.01, -0.004), size: Vec3(0.004, 0.009, 0.012), color: Palette.barkBlack)
                    $0.box(center: at + along * 0.096 + Vec3(0.008 * side, 0.004, 0), size: Vec3(0.006, 0.006, 0.004), color: Palette.barkBlack)
                }
                $0.place(.translation(at + along * 0.088) * .scale(Vec3(0.019, 0.018, 0.018))) {
                    $0.sphere(center: .zero, radius: 1, rings: 3, sides: 8, color: m.coat * 0.85)
                }
                // Its forelock, and the bridle: brow band, noseband and the bit's rings.
                $0.box(center: at + Vec3(0, 0.018, 0.0), size: Vec3(0.012, 0.012, 0.022), color: m.mane)
                $0.place(.translation(at + along * 0.062) * Mat4.aligningUp(to: along)) {
                    $0.tube([(0.023, -0.004), (0.023, 0.004)], sides: 10, color: Palette.leatherDark)
                }
                $0.place(.translation(at + along * 0.0) * Mat4.aligningUp(to: along)) {
                    $0.tube([(0.03, 0.0), (0.03, 0.007)], sides: 10, color: Palette.leatherDark)
                }
                $0.with(material: .metal) {
                    for side in [Float(1), -1] {
                        $0.sphere(center: at + along * 0.08 + Vec3(0.02 * side, -0.006, 0), radius: 0.005, rings: 2, sides: 5, color: Palette.steel)
                    }
                }
                for side in [Float(1), -1] {
                    $0.place(.translation(Vec3(side * 0.011, 0.297, 0.143))) {
                        $0.cone(sides: 5, radius: 0.0085, to: 0.028, color: m.coat)
                    }
                }
            }
            $0.with(part: Steed.tail, sway: 0.5) {
                for strand in 0..<3 {
                    let x = Float(strand - 1) * 0.008
                    $0.limb(from: Vec3(x, 0.2, -0.14), to: Vec3(x * 2.5, 0.075, -0.19 + Float(strand) * 0.006), radius: 0.011, topRadius: 0.004,
                            sides: 5, color: m.mane)
                }
            }
            let legs: [(upper: UInt16, lower: UInt16, top: Vec3, joint: Vec3, foot: Vec3, thick: Float)] = [
                (Steed.foreL, Steed.foreShinL, Vec3(0.032, 0.155, 0.075), Vec3(0.032, 0.085, 0.08), Vec3(0.032, 0.022, 0.076), 0.018),
                (Steed.foreR, Steed.foreShinR, Vec3(-0.032, 0.155, 0.075), Vec3(-0.032, 0.085, 0.08), Vec3(-0.032, 0.022, 0.076), 0.018),
                (Steed.hindL, Steed.hindShinL, Vec3(0.033, 0.168, -0.095), Vec3(0.033, 0.085, -0.118), Vec3(0.033, 0.022, -0.102), 0.023),
                (Steed.hindR, Steed.hindShinR, Vec3(-0.033, 0.168, -0.095), Vec3(-0.033, 0.085, -0.118), Vec3(-0.033, 0.022, -0.102), 0.023),
            ]
            for leg in legs {
                $0.with(part: leg.upper) {
                    $0.limb(from: leg.top, to: leg.joint, radius: leg.thick * 1.12, topRadius: 0.013, sides: 8, color: m.coat)
                }
                $0.with(part: leg.lower) {
                    $0.sphere(center: leg.joint, radius: 0.0135, rings: 2, sides: 6, color: m.coat)
                    $0.limb(from: leg.joint, to: leg.foot, radius: 0.0115, topRadius: 0.0095, sides: 6, color: m.socks ?? m.coat)
                    $0.sphere(center: leg.foot + Vec3(0, 0.002, 0.002), radius: 0.012, rings: 2, sides: 6, color: m.socks ?? m.coat)
                    $0.place(.translation(leg.foot - Vec3(0, 0.022, -0.002))) {
                        $0.lathe([(0.016, 0), (0.015, 0.006), (0.012, 0.024)], sides: 8, color: Palette.hoof)
                    }
                }
            }
        }
    }
}
