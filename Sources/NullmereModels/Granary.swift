import Foundation
import NullmereCore

/// The Granary, modelled whole at each level, where the House's grain is
/// threshed, dried and kept; it faces +z, within a work's slot.
///
/// 1. A granary of wattle and daub raised on staddle stones against the
///    rats, under thatch, sacks heaped at its steps.
/// 2. A timber barn beside it, its loft door and the sack hoist over it, a
///    threshing floor of beaten earth before its doors, sheaves stooked.
/// 3. The barn rebuilt in stone under slate, two round grain bins under
///    cones, a winnowing floor of flags.
/// 4. A row of tall silos hooped in iron, drying racks of sheaves, a
///    wain waiting to be loaded.
/// 5. A great tithe barn, buttressed, a louvre on its ridge and a dovecote
///    beside it, the House's banner at its doors.
///
/// The sack hoist swings at the loft door as the grain goes up.
enum Granary {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.yard, sides: 12)
        b.fine { chaff(&$0) }
        var swings: [Machinery.Swing] = []
        switch level {
        case 1:
            staddleGranary(&b, at: Vec3(0, 0, -0.04), thatch: true)
            sacks(&b, at: Vec3(0.12, 0, 0.14), count: 4)
            stooks(&b, at: Vec3(-0.17, 0, 0.14), count: 3)
            swings.append(hoist(&b, &rig, at: Vec3(-0.0, 0.17, 0.035)))
        case 2:
            barn(&b, at: Vec3(-0.06, 0, -0.09), stone: false, width: 0.24, height: 0.13)
            staddleGranary(&b, at: Vec3(0.16, 0, -0.09), thatch: true)
            threshingFloor(&b, at: Vec3(-0.06, 0, 0.12), flags: false)
            stooks(&b, at: Vec3(0.19, 0, 0.16), count: 4)
            swings.append(hoist(&b, &rig, at: Vec3(-0.06, 0.17, -0.007)))
        case 3:
            barn(&b, at: Vec3(-0.05, 0, -0.1), stone: true, width: 0.26, height: 0.14)
            bins(&b, xs: [0.2], z: -0.1, height: 0.15)
            threshingFloor(&b, at: Vec3(-0.05, 0, 0.12), flags: true)
            sacks(&b, at: Vec3(0.17, 0, 0.14), count: 5)
            stooks(&b, at: Vec3(-0.22, 0, 0.17), count: 2)
            swings.append(hoist(&b, &rig, at: Vec3(-0.05, 0.18, -0.017)))
        case 4:
            barn(&b, at: Vec3(-0.07, 0, -0.1), stone: true, width: 0.26, height: 0.15)
            bins(&b, xs: [0.17, 0.25], z: -0.12, height: 0.2)
            dryingRack(&b, at: Vec3(0.2, 0, 0.1))
            wain(&b, at: Vec3(-0.12, 0, 0.17))
            threshingFloor(&b, at: Vec3(0.02, 0, 0.13), flags: true)
            swings.append(hoist(&b, &rig, at: Vec3(-0.07, 0.19, -0.017)))
        default:
            titheBarn(&b, at: Vec3(-0.05, 0, -0.1))
            bins(&b, xs: [0.2, 0.27], z: -0.06, height: 0.22)
            dovecote(&b, at: Vec3(0.2, 0, 0.16))
            sacks(&b, at: Vec3(-0.06, 0, 0.18), count: 4)
            swings.append(hoist(&b, &rig, at: Vec3(-0.05, 0.23, -0.002)))
        }
        let machinery = Machinery(swings: swings, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// A little granary on staddle stones, mushroom-capped against rats,
    /// its walls of wattle under daub, its door at the top of three steps.
    static func staddleGranary(_ b: inout MeshBuilder, at: Vec3, thatch: Bool) {
        for (dx, dz) in [(-0.06, -0.05), (0.06, -0.05), (-0.06, 0.05), (0.06, 0.05), (0, -0.05), (0, 0.05)] as [(Float, Float)] {
            let foot = at + Vec3(dx, 0, dz)
            b.place(.translation(foot)) {
                $0.lathe([(0.012, 0), (0.008, 0.035), (0.0, 0.036)], sides: 6, color: Palette.stone)
                $0.lathe([(0.0, 0.035), (0.02, 0.036), (0.018, 0.046), (0.0, 0.047)], sides: 6, color: Palette.stonePale)
            }
        }
        b.hall(at: at + Vec3(0, 0.047, 0), width: 0.15, depth: 0.12, height: 0.09, wall: Palette.linen.mix(Palette.thatch, 0.4),
               roof: thatch ? Palette.thatch : Palette.slate, pitch: 0.75)
        b.door(at + Vec3(0, 0.09, 0.062), width: 0.035, height: 0.06, facing: 0)
        for step in 0..<3 {
            b.box(center: at + Vec3(0, 0.012 + Float(step) * 0.014, 0.085 - Float(step) * 0.012), size: Vec3(0.05, 0.008, 0.014),
                  color: Palette.timberGrey)
        }
        b.fine { b in
            for x in stride(from: Float(-0.06), through: 0.06, by: 0.03) {
                b.box(center: at + Vec3(x, 0.09, 0.0605), size: Vec3(0.003, 0.08, 0.002), color: Palette.timberDark)
            }
        }
    }

    /// A barn of timber or stone, gabled, its great doors and its loft
    /// door high in the gable over them.
    static func barn(_ b: inout MeshBuilder, at: Vec3, stone: Bool, width: Float, height: Float) {
        let depth: Float = 0.15
        b.hall(at: at, width: width, depth: depth, height: height, wall: stone ? Palette.stonePale : Palette.timber,
               roof: stone ? Palette.slate : Palette.thatch, pitch: 0.75, footing: stone ? Palette.stone : nil)
        b.door(at + Vec3(0, 0.05, depth / 2 + 0.002), width: 0.08, height: 0.1, facing: 0, color: Palette.timberDark)
        b.box(center: at + Vec3(0, height + 0.025, depth / 2 + 0.002), size: Vec3(0.035, 0.035, 0.01), color: Palette.timberDark)
        b.window(at + Vec3(-width * 0.33, height * 0.65, depth / 2 + 0.002), width: 0.02, height: 0.026, facing: 0)
        b.fine { b in
            // The doors' boards and their strap hinges.
            for x in stride(from: Float(-0.035), through: 0.035, by: 0.014) {
                b.box(center: at + Vec3(x, 0.05, depth / 2 + 0.008), size: Vec3(0.003, 0.098, 0.002), color: Palette.timber)
            }
            for y in [Float(0.025), 0.075] {
                b.box(center: at + Vec3(0, y, depth / 2 + 0.009), size: Vec3(0.078, 0.005, 0.002), color: Palette.iron)
            }
            if !stone {
                for x in stride(from: -width / 2 + 0.02, to: width / 2, by: 0.025) {
                    b.box(center: at + Vec3(x, height / 2, -depth / 2 - 0.002), size: Vec3(0.004, height, 0.003), color: Palette.timberDark)
                }
            }
        }
    }

    /// The great tithe barn of the fifth level: long and high, buttressed,
    /// a louvre on its ridge, the House's banners at its doors.
    static func titheBarn(_ b: inout MeshBuilder, at: Vec3) {
        let width: Float = 0.3, depth: Float = 0.17, height: Float = 0.17
        barn(&b, at: at, stone: true, width: width, depth: depth, height: height)
        for x in [-width / 2, -width / 6, width / 6, width / 2] {
            for side in [Float(-1), 1] {
                b.box(center: at + Vec3(x, height * 0.4, side * (depth / 2 + 0.014)), size: Vec3(0.022, height * 0.8 + 0.06, 0.026),
                      color: Palette.stone)
            }
        }
        let ridge = at + Vec3(0, height + depth * 0.75, 0)
        b.box(center: ridge + Vec3(0, 0.02, 0), size: Vec3(0.04, 0.04, 0.04), color: Palette.timberGrey)
        b.place(.translation(ridge + Vec3(0, 0.04, 0))) {
            $0.hipRoof(width: 0.05, depth: 0.05, base: 0, height: 0.04, color: Palette.slate, overhang: 0.006)
        }
        for x in [Float(-0.06), 0.06] {
            b.limb(from: at + Vec3(x, height * 0.85, depth / 2 + 0.01), to: at + Vec3(x, height * 0.85, depth / 2 + 0.06), radius: 0.003,
                   color: Palette.iron)
            b.flag(at: at + Vec3(x, height * 0.85, depth / 2 + 0.058), width: 0.035, height: 0.08, turn: -.pi / 2, tail: true)
        }
    }

    static func barn(_ b: inout MeshBuilder, at: Vec3, stone: Bool, width: Float, depth: Float, height: Float) {
        b.hall(at: at, width: width, depth: depth, height: height, wall: stone ? Palette.stonePale : Palette.timber,
               roof: Palette.slate, pitch: 0.75, footing: Palette.stone)
        b.door(at + Vec3(0, 0.06, depth / 2 + 0.002), width: 0.09, height: 0.12, facing: 0, color: Palette.timberDark)
        b.box(center: at + Vec3(0, height + 0.03, depth / 2 + 0.002), size: Vec3(0.04, 0.04, 0.01), color: Palette.timberDark)
        for x in [-width * 0.36, width * 0.36] {
            b.window(at + Vec3(x, height * 0.6, depth / 2 + 0.002), width: 0.018, height: 0.04, facing: 0)
        }
    }

    /// Round grain bins under cones, hooped, in a row.
    static func bins(_ b: inout MeshBuilder, xs: [Float], z: Float, height: Float) {
        for x in xs {
            b.roundHouse(at: Vec3(x, 0, z), radius: 0.04, height: height, wall: Palette.timberPale, roof: Palette.slate,
                         roofHeight: 0.05, sides: 10)
            b.fine { b in
                for y in stride(from: Float(0.035), to: height, by: 0.06) {
                    b.place(.translation(Vec3(x, y, z))) {
                        $0.lathe([(0.0405, 0), (0.043, 0.002), (0.043, 0.006), (0.0405, 0.008)], sides: 10, color: Palette.iron)
                    }
                }
                b.ladder(from: Vec3(x, 0, z + 0.045), to: Vec3(x, height, z + 0.042), width: 0.016, rungs: Int(height / 0.03),
                         color: Palette.timberDark)
            }
        }
    }

    /// The threshing floor before the doors: beaten earth, or flags laid.
    static func threshingFloor(_ b: inout MeshBuilder, at: Vec3, flags: Bool) {
        b.box(center: at + Vec3(0, 0.005, 0), size: Vec3(0.17, 0.01, 0.09), color: flags ? Palette.stonePale : Palette.earth)
        b.fine { b in
            if flags {
                for x in stride(from: Float(-0.07), through: 0.07, by: 0.035) {
                    for z in [Float(-0.022), 0.022] {
                        b.box(center: at + Vec3(x, 0.0105, z), size: Vec3(0.032, 0.001, 0.04), color: Palette.stone)
                    }
                }
            }
            // Grain spread on it, and two flails laid by.
            b.sphere(center: at + Vec3(0.02, 0.01, 0), radius: 0.04, rings: 2, sides: 7, color: Palette.weld, squash: 0.12)
            for z in [Float(-0.03), 0.03] {
                b.limb(from: at + Vec3(-0.07, 0.012, z), to: at + Vec3(-0.02, 0.012, z + 0.01), radius: 0.003, color: Palette.timberPale)
                b.limb(from: at + Vec3(-0.02, 0.012, z + 0.01), to: at + Vec3(0.0, 0.012, z + 0.02), radius: 0.004, color: Palette.timber)
            }
        }
    }

    /// Sacks of grain heaped.
    static func sacks(_ b: inout MeshBuilder, at: Vec3, count: Int) {
        for index in 0..<count {
            let angle = Float(index) * 1.9
            let p = at + Vec3(0.025 * Float(cos(Double(angle))), Float(index / 3) * 0.022, 0.025 * Float(sin(Double(angle))))
            b.tiedSack(at: p, size: 0.022)
        }
    }

    /// Sheaves stooked in the yard.
    static func stooks(_ b: inout MeshBuilder, at: Vec3, count: Int) {
        for index in 0..<count {
            let p = at + Vec3(Float(index) * 0.035 - Float(count - 1) * 0.0175, 0, 0)
            b.place(.translation(p)) {
                $0.cone(sides: 6, radius: 0.016, from: 0, to: 0.05, color: Palette.weld)
                $0.lathe([(0.014, 0.03), (0.016, 0.032), (0.014, 0.034)], sides: 6, color: Palette.thatch)
            }
        }
    }

    /// A rack where sheaves hang to dry.
    static func dryingRack(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.05), 0.05] {
            b.limb(from: at + Vec3(x, 0, 0), to: at + Vec3(x, 0.12, 0), radius: 0.004, color: Palette.timberDark)
        }
        for y in [Float(0.05), 0.1] {
            b.beam(from: at + Vec3(-0.055, y, 0), to: at + Vec3(0.055, y, 0), width: 0.004, color: Palette.timber)
            for x in stride(from: Float(-0.04), through: 0.04, by: 0.02) {
                b.place(.translation(at + Vec3(x, y - 0.035, 0))) {
                    $0.cone(sides: 5, radius: 0.008, from: 0, to: 0.035, color: Palette.weld)
                }
            }
        }
    }

    /// A wain waiting to be loaded: its bed, four wheels and shafts.
    static func wain(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at) * .rotationY(0.3)) { b in
            b.box(min: Vec3(-0.05, 0.03, -0.025), max: Vec3(0.05, 0.045, 0.025), color: Palette.timber)
            for x in [Float(-0.035), 0.035] {
                for z in [Float(-0.028), 0.028] {
                    b.wheel(center: Vec3(x, 0.02, z), radius: 0.02, width: 0.006, spokes: 4, color: Palette.timberDark)
                }
            }
            b.beam(from: Vec3(0.05, 0.035, -0.012), to: Vec3(0.11, 0.015, -0.012), width: 0.004, color: Palette.timberDark)
            b.beam(from: Vec3(0.05, 0.035, 0.012), to: Vec3(0.11, 0.015, 0.012), width: 0.004, color: Palette.timberDark)
            b.tiedSack(at: Vec3(-0.02, 0.045, 0), size: 0.02)
        }
    }

    /// A dovecote on its post, round, its holes in rows, under a cone.
    static func dovecote(_ b: inout MeshBuilder, at: Vec3) {
        b.limb(from: at, to: at + Vec3(0, 0.12, 0), radius: 0.008, color: Palette.timberDark)
        b.roundHouse(at: at + Vec3(0, 0.12, 0), radius: 0.035, height: 0.05, wall: Palette.stoneWhite, roof: Palette.slate,
                     roofHeight: 0.04, sides: 8)
        b.fine { b in
            for index in 0..<8 {
                let angle = Float(index) / 8 * 2 * .pi
                for y in [Float(0.135), 0.155] {
                    b.box(center: at + MeshBuilder.ring(0.0355, y, angle), size: Vec3(0.008, 0.007, 0.004), turn: -angle,
                          color: Palette.timberDark)
                }
            }
        }
    }

    /// The sack hoist at the loft door: its arm out over the door and a
    /// sack on the rope, swung in as the grain goes up.
    static func hoist(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        let arm = rig.add("sack hoist", pivot: at)
        b.with(part: arm) { b in
            b.beam(from: at, to: at + Vec3(0, 0, 0.07), width: 0.008, color: Palette.timberDark)
            b.limb(from: at + Vec3(0, -0.004, 0.066), to: at + Vec3(0, -0.07, 0.066), radius: 0.0018, color: Palette.linen)
            b.tiedSack(at: at + Vec3(0, -0.095, 0.066), size: 0.02)
        }
        return Machinery.Swing(part: arm, axis: Vec3(0, 1, 0), angle: 0.5)
    }

    /// Chaff and straw strewn about the yard.
    static func chaff(_ b: inout MeshBuilder) {
        for index in 0..<16 {
            let angle = Float(index) * 2.39996
            let r = 0.1 + 0.18 * Float((index * 31) % 13) / 13
            b.beam(from: Vec3(r * Float(cos(Double(angle))), 0.013, r * Float(sin(Double(angle)))),
                   to: Vec3(r * Float(cos(Double(angle))) + 0.02, 0.013, r * Float(sin(Double(angle))) + 0.006),
                   width: 0.003, depth: 0.002, color: index % 2 == 0 ? Palette.weld : Palette.thatch)
        }
    }
}
