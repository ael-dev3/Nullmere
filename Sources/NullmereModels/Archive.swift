import Foundation
import NullmereCore

/// The Archive, modelled whole at each level, where the House's scholars
/// keep its records and read the sky; it faces +z, within a work's slot.
///
/// 1. A scholar's cell of timber under thatch, a lectern and chests of
///    scrolls before it, a sundial on its stone.
/// 2. A long library hall, writing desks under an awning before it, a
///    weathervane turning on its ridge.
/// 3. An archive of pale stone with tall lit windows, a scriptorium wing,
///    an armillary sphere turning on its plinth in the court.
/// 4. An observatory tower beside it under a dome with its shutter open.
/// 5. A domed reading hall at the heart, the observatory tower crowned with
///    the great armillary, lanterns along the cloister.
enum Archive {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.yard, sides: 12)
        b.fine { leaves(&$0) }
        Lodge.boundary(&b, courses: min(level, 3))
        var wheels: [Machinery.Wheel] = []
        switch level {
        case 1:
            cell(&b, at: Vec3(-0.05, 0, -0.08))
            lectern(&b, at: Vec3(0.06, 0, 0.12))
            chests(&b, at: Vec3(-0.15, 0, 0.13), count: 2)
            sundial(&b, at: Vec3(0.18, 0, 0.04))
            wheels.append(vane(&b, &rig, at: Vec3(-0.05, 0.16, -0.08)))
        case 2:
            library(&b, at: Vec3(-0.03, 0, -0.12), stone: false, width: 0.28)
            awning(&b, at: Vec3(-0.04, 0, 0.1))
            sundial(&b, at: Vec3(0.2, 0, 0.12))
            chests(&b, at: Vec3(-0.2, 0, 0.15), count: 3)
            wheels.append(vane(&b, &rig, at: Vec3(-0.03, 0.2, -0.12)))
        case 3:
            library(&b, at: Vec3(-0.04, 0, -0.13), stone: true, width: 0.28)
            scriptorium(&b, at: Vec3(-0.21, 0, 0.06))
            wheels.append(sphere(&b, &rig, at: Vec3(0.12, 0, 0.12), radius: 0.06))
            awning(&b, at: Vec3(-0.02, 0, 0.17))
        case 4:
            library(&b, at: Vec3(-0.07, 0, -0.13), stone: true, width: 0.24)
            observatory(&b, at: Vec3(0.18, 0, -0.1), height: 0.28)
            scriptorium(&b, at: Vec3(-0.2, 0, 0.055))
            wheels.append(sphere(&b, &rig, at: Vec3(0.07, 0, 0.14), radius: 0.06))
        default:
            readingHall(&b, at: Vec3(-0.06, 0, -0.08))
            observatory(&b, at: Vec3(0.19, 0, -0.1), height: 0.36)
            wheels.append(sphere(&b, &rig, at: Vec3(0.19, 0.44, -0.1), radius: 0.07, plinth: false))
            lanterns(&b)
            chests(&b, at: Vec3(0.14, 0, 0.18), count: 3)
            sundial(&b, at: Vec3(0.2, 0, 0.08))
            lectern(&b, at: Vec3(-0.21, 0, 0.1))
            lectern(&b, at: Vec3(-0.18, 0, 0.15))
        }
        let machinery = Machinery(wheels: wheels, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// A scholar's cell: timber under thatch, its door and a lit window.
    static func cell(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.16, depth: 0.12, height: 0.09, wall: Palette.timber, roof: Palette.thatch, pitch: 0.7)
        b.door(at + Vec3(-0.03, 0.04, 0.062), width: 0.03, height: 0.065, facing: 0)
        b.window(at + Vec3(0.04, 0.055, 0.062), width: 0.022, height: 0.026, facing: 0)
    }

    /// A long library hall: timber or pale stone, its tall windows lit, its
    /// doors and their carved lintel.
    static func library(_ b: inout MeshBuilder, at: Vec3, stone: Bool, width: Float) {
        let depth: Float = 0.12, height: Float = stone ? 0.13 : 0.1
        b.hall(at: at, width: width, depth: depth, height: height, wall: stone ? Palette.stonePale : Palette.timberPale,
               roof: Palette.slate, pitch: 0.7, footing: stone ? Palette.stone : nil)
        b.door(at + Vec3(0, 0.045, depth / 2 + 0.002), width: 0.035, height: 0.08, facing: 0)
        for x in stride(from: -width / 2 + 0.035, to: width / 2 - 0.02, by: 0.045) where abs(x) > 0.03 {
            b.window(at + Vec3(x, height * 0.55, depth / 2 + 0.002), width: 0.014, height: stone ? 0.05 : 0.03, facing: 0)
        }
        b.fine { b in
            b.box(center: at + Vec3(0, 0.094, depth / 2 + 0.006), size: Vec3(0.05, 0.012, 0.008), color: Palette.bronze)
            if stone {
                for x in stride(from: -width / 2 + 0.035, to: width / 2 - 0.02, by: 0.045) where abs(x) > 0.03 {
                    b.box(center: at + Vec3(x, height * 0.55 + 0.03, depth / 2 + 0.005), size: Vec3(0.02, 0.006, 0.008), color: Palette.stone)
                }
            }
        }
    }

    /// A lectern with a great book open on it.
    static func lectern(_ b: inout MeshBuilder, at: Vec3) {
        b.limb(from: at, to: at + Vec3(0, 0.06, 0), radius: 0.004, color: Palette.timberDark)
        b.place(.translation(at + Vec3(0, 0.065, 0)) * .rotationX(0.5)) {
            $0.box(center: .zero, size: Vec3(0.04, 0.004, 0.03), color: Palette.timber)
            $0.box(center: Vec3(0, 0.004, 0), size: Vec3(0.036, 0.004, 0.026), color: Palette.linen)
        }
    }

    /// Chests of scrolls, iron-bound.
    static func chests(_ b: inout MeshBuilder, at: Vec3, count: Int) {
        for index in 0..<count {
            let p = at + Vec3(Float(index) * 0.04 - Float(count - 1) * 0.02, 0, 0)
            b.box(min: p + Vec3(-0.017, 0, -0.013), max: p + Vec3(0.017, 0.024, 0.013), color: Palette.timberDark)
            b.box(min: p + Vec3(-0.018, 0.024, -0.014), max: p + Vec3(0.018, 0.03, 0.014), color: Palette.timber)
            b.fine { b in
                for x in [Float(-0.01), 0.01] {
                    b.box(center: p + Vec3(x, 0.015, 0), size: Vec3(0.003, 0.03, 0.028), color: Palette.iron)
                }
            }
        }
    }

    /// A sundial on its stone.
    static func sundial(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.lathe([(0.018, 0), (0.014, 0.04), (0.024, 0.045), (0.024, 0.05), (0.0, 0.051)], sides: 10, color: Palette.stonePale)
        }
        b.sheet([at + Vec3(0, 0.05, -0.012), at + Vec3(0, 0.05, 0.012), at + Vec3(0, 0.07, -0.012)], normal: Vec3(1, 0, 0),
                thickness: 0.002, color: Palette.bronze)
    }

    /// A weathervane on the ridge, turning in the night wind.
    static func vane(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        b.limb(from: at, to: at + Vec3(0, 0.05, 0), radius: 0.002, color: Palette.iron)
        let vane = rig.add("archive vane", pivot: at + Vec3(0, 0.05, 0))
        b.with(part: vane) { b in
            b.sheet([at + Vec3(-0.02, 0.05, 0), at + Vec3(0.02, 0.05, 0), at + Vec3(0.012, 0.064, 0)], normal: Vec3(0, 0, 1),
                    thickness: 0.002, color: Palette.bronze)
            b.limb(from: at + Vec3(-0.025, 0.05, 0), to: at + Vec3(0.025, 0.05, 0), radius: 0.0015, color: Palette.iron)
        }
        return Machinery.Wheel(part: vane, axis: Vec3(0, 1, 0), turns: 1)
    }

    /// Writing desks under an awning, ink and pages on them.
    static func awning(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.08), 0.08] {
            for z in [Float(-0.03), 0.03] {
                b.limb(from: at + Vec3(x, 0, z), to: at + Vec3(x, 0.09, z), radius: 0.003, color: Palette.timberDark)
            }
        }
        b.sheet([at + Vec3(-0.09, 0.09, -0.04), at + Vec3(0.09, 0.09, -0.04), at + Vec3(0.09, 0.08, 0.045), at + Vec3(-0.09, 0.08, 0.045)],
                normal: Vec3(0, 1, 0.1), thickness: 0.003, color: Palette.seaWool)
        for x in [Float(-0.05), 0.0, 0.05] {
            b.box(center: at + Vec3(x, 0.03, 0), size: Vec3(0.035, 0.004, 0.025), color: Palette.timber)
            for dx in [Float(-0.014), 0.014] {
                b.limb(from: at + Vec3(x + dx, 0, 0), to: at + Vec3(x + dx, 0.03, 0), radius: 0.002, color: Palette.timberDark)
            }
            b.fine { $0.box(center: at + Vec3(x, 0.033, 0), size: Vec3(0.02, 0.002, 0.016), color: Palette.linen) }
        }
    }

    /// A scriptorium wing turned to face the court, its windows lit.
    static func scriptorium(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.18, depth: 0.09, height: 0.1, wall: Palette.stonePale, roof: Palette.slate, pitch: 0.65, turn: .pi / 2,
               footing: Palette.stone)
        for z in [Float(-0.05), 0.0, 0.05] {
            b.window(at + Vec3(0.046, 0.06, z), width: 0.014, height: 0.034, facing: .pi / 2)
        }
    }

    /// The armillary sphere on its plinth, turning slowly.
    static func sphere(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3, radius: Float, plinth: Bool = true) -> Machinery.Wheel {
        let centre = at + Vec3(0, plinth ? 0.1 + radius : radius, 0)
        if plinth {
            b.place(.translation(at)) {
                $0.lathe([(0.03, 0), (0.024, 0.02), (0.018, 0.08), (0.026, 0.09), (0.026, 0.1)], sides: 8, color: Palette.stonePale)
            }
        }
        let part = rig.add("armillary", pivot: centre)
        Works.armillary(&b, part: part, at: centre, radius: radius)
        return Machinery.Wheel(part: part, axis: Vec3(0, 1, 0), turns: 1)
    }

    /// The observatory tower under its dome, its shutter open on the sky.
    static func observatory(_ b: inout MeshBuilder, at: Vec3, height: Float) {
        b.place(.translation(at)) {
            $0.lathe([(0.065, -0.06), (0.06, height)], sides: 12, color: Palette.stonePale)
        }
        for (index, y) in [Float(0.08), 0.16, height - 0.06].enumerated() {
            b.window(at + MeshBuilder.ring(0.061, y, Float(index) * 2.1 + 0.4), width: 0.012, height: 0.03, facing: Float(index) * 2.1 + 0.4 + .pi / 2)
        }
        Works.dome(&b, at: at + Vec3(0, height, 0), radius: 0.07, wall: 0.0, color: Palette.slate)
        b.fine { b in
            for y in stride(from: Float(0.06), to: height, by: 0.07) {
                b.place(.translation(at)) {
                    $0.lathe([(0.061, y), (0.066, y + 0.004), (0.061, y + 0.008)], sides: 12, color: Palette.stone)
                }
            }
        }
    }

    /// The domed reading hall of the fifth level: a round hall of pale stone
    /// under a great dome with a lantern, a portico of columns before it.
    static func readingHall(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) { b in
            b.lathe([(0.11, -0.06), (0.11, 0.14)], sides: 16, color: Palette.stonePale)
            b.lathe([(0.118, 0.14), (0.118, 0.155)], sides: 16, color: Palette.stone)
            b.lathe([(0.115, 0.155), (0.1, 0.2), (0.07, 0.24), (0.03, 0.26), (0.0, 0.262)], sides: 16, color: Palette.slate)
            b.with(material: .glow) {
                $0.lathe([(0.0, 0.26), (0.018, 0.265), (0.016, 0.29), (0.0, 0.3)], sides: 8, color: Palette.candle)
            }
        }
        for index in 0..<8 {
            let angle = Float(index) / 8 * 2 * .pi + .pi / 8
            b.window(at + MeshBuilder.ring(0.111, 0.09, angle), width: 0.014, height: 0.05, facing: angle + .pi / 2)
        }
        for x in stride(from: Float(-0.07), through: 0.07, by: 0.035) {
            b.place(.translation(at + Vec3(x, 0, 0.13))) {
                $0.lathe([(0.009, 0), (0.007, 0.012), (0.007, 0.11), (0.009, 0.12)], sides: 6, color: Palette.stoneWhite)
            }
        }
        b.box(min: at + Vec3(-0.085, 0.12, 0.115), max: at + Vec3(0.085, 0.135, 0.145), color: Palette.stoneWhite)
        b.place(.translation(at + Vec3(0, 0.135, 0.13))) {
            $0.gableRoof(width: 0.17, depth: 0.03, base: 0, height: 0.025, color: Palette.slate, overhang: 0.006)
        }
        b.door(at + Vec3(0, 0.045, 0.111), width: 0.035, height: 0.08, facing: 0)
    }

    /// Lanterns on posts along the cloister walk.
    static func lanterns(_ b: inout MeshBuilder) {
        for x in [Float(-0.22), -0.15, 0.04, 0.11] {
            let foot = Vec3(x, 0, 0.2)
            b.limb(from: foot, to: foot + Vec3(0, 0.08, 0), radius: 0.003, color: Palette.iron)
            b.with(material: .glow) {
                $0.place(.translation(foot + Vec3(0, 0.085, 0))) {
                    $0.lathe([(0.0, -0.008), (0.007, -0.003), (0.007, 0.006), (0.0, 0.01)], sides: 6, color: Palette.candle)
                }
            }
        }
    }

    /// Leaves fallen in the court.
    static func leaves(_ b: inout MeshBuilder) {
        for index in 0..<16 {
            let angle = Float(index) * 2.39996
            let r = 0.08 + 0.18 * Float((index * 29) % 11) / 11
            b.box(center: Vec3(r * Float(cos(Double(angle))), 0.0125, r * Float(sin(Double(angle)))), size: Vec3(0.008, 0.002, 0.006),
                  turn: angle, color: index % 2 == 0 ? Palette.weld : Palette.madder)
        }
    }
}
