import Foundation
import NullmereCore

/// The Infirmary, modelled whole at each level, where the House's fallen
/// companies are carried and healed; it faces +z, within a work's slot.
///
/// 1. A long tent of canvas on poles, cots within, the healers' fire under
///    a kettle in the open and a well with its windlass.
/// 2. A timber ward under thatch, its chimney smoking, a garden of herbs in
///    raised beds before it.
/// 3. A ward of white stone under slate, a bath-house beside it, a lantern
///    walk to the door.
/// 4. A cloister: the ward and a second wing about a court, a physic
///    garden at its heart, beds laid out to air.
/// 5. The great hospice, its hall crowned with a dome and a lantern of
///    moonsalt, the healers' bell in its cote.
///
/// The well's windlass turns as water is drawn for the ward.
enum Infirmary {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.yard, sides: 12)
        b.fine { petals(&$0) }
        Lodge.boundary(&b, courses: min(level, 3))
        let wheel = well(&b, &rig, at: Vec3(0.2, 0, 0.12))
        switch level {
        case 1:
            tent(&b, at: Vec3(-0.04, 0, -0.08))
            hearth(&b, at: Vec3(-0.17, 0, 0.14))
            herbs(&b, at: Vec3(0.02, 0, 0.17), beds: 1)
        case 2:
            ward(&b, at: Vec3(-0.04, 0, -0.1), stone: false, width: 0.26)
            herbs(&b, at: Vec3(-0.06, 0, 0.13), beds: 3)
            hearth(&b, at: Vec3(-0.2, 0, 0.16))
        case 3:
            ward(&b, at: Vec3(-0.04, 0, -0.1), stone: true, width: 0.26)
            bathHouse(&b, at: Vec3(-0.21, 0, 0.08))
            lanternWalk(&b, z: 0.06)
            herbs(&b, at: Vec3(0.04, 0, 0.17), beds: 2)
        case 4:
            ward(&b, at: Vec3(-0.02, 0, -0.14), stone: true, width: 0.28)
            wing(&b, at: Vec3(-0.19, 0, 0.04))
            herbs(&b, at: Vec3(0.0, 0, 0.06), beds: 3)
            airingBeds(&b, at: Vec3(0.05, 0, 0.2))
        default:
            hospice(&b, at: Vec3(-0.02, 0, -0.12))
            wing(&b, at: Vec3(-0.2, 0, 0.05))
            herbs(&b, at: Vec3(0.0, 0, 0.08), beds: 3)
            bellCote(&b, at: Vec3(0.2, 0, -0.08))
            lanternWalk(&b, z: 0.18)
            airingBeds(&b, at: Vec3(0.06, 0, 0.24))
            hearth(&b, at: Vec3(-0.19, 0, 0.18))
        }
        let machinery = Machinery(wheels: [wheel], parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// Where the ward's chimney smokes, from the second level.
    static func chimney(_ level: Int) -> Vec3? {
        switch level {
        case 2, 3: return Vec3(-0.04, 0, -0.1) + Vec3(0.09, 0.22, -0.035)
        case 4: return Vec3(-0.02, 0, -0.14) + Vec3(0.1, 0.22, -0.035)
        case 5: return Vec3(-0.02, 0, -0.12) + Vec3(0.11, 0.24, -0.04)
        default: return nil
        }
    }

    /// A long tent of canvas on its poles, the cots within seen through its
    /// open end.
    static func tent(_ b: inout MeshBuilder, at: Vec3) {
        let w: Float = 0.11, d: Float = 0.2, h: Float = 0.1
        b.sheet([at + Vec3(-w, 0, -d / 2), at + Vec3(-w, 0, d / 2), at + Vec3(0, h, d / 2), at + Vec3(0, h, -d / 2)],
                normal: Vec3(-1, 1, 0), thickness: 0.004, color: Palette.canvas)
        b.sheet([at + Vec3(w, 0, d / 2), at + Vec3(w, 0, -d / 2), at + Vec3(0, h, -d / 2), at + Vec3(0, h, d / 2)],
                normal: Vec3(1, 1, 0), thickness: 0.004, color: Palette.canvas)
        for z in [-d / 2, 0, d / 2] {
            b.limb(from: at + Vec3(0, 0, z), to: at + Vec3(0, h + 0.01, z), radius: 0.004, color: Palette.timberDark)
        }
        for index in 0..<3 {
            let z = -0.06 + Float(index) * 0.06
            b.box(center: at + Vec3(-0.05, 0.02, z), size: Vec3(0.04, 0.012, 0.025), color: Palette.linen)
            b.box(center: at + Vec3(0.05, 0.02, z), size: Vec3(0.04, 0.012, 0.025), color: Palette.linen)
        }
        b.flag(at: at + Vec3(0, h + 0.01, d / 2), width: 0.03, height: 0.022, turn: 0.4, color: Palette.linen)
    }

    /// The healers' fire in the open, a kettle hung over it on a tripod.
    static func hearth(_ b: inout MeshBuilder, at: Vec3) {
        for index in 0..<6 {
            let angle = Float(index) / 6 * 2 * .pi
            b.rock(center: at + Vec3(0.025 * Float(cos(Double(angle))), 0.006, 0.025 * Float(sin(Double(angle)))),
                   size: Vec3(0.012, 0.01, 0.012), seed: UInt32(index + 600), color: Palette.stoneDark)
        }
        b.with(material: .glow) {
            $0.place(.translation(at)) { $0.cone(sides: 5, radius: 0.015, from: 0, to: 0.03, color: Palette.fire) }
        }
        for angle in [Float(0.3), 2.4, 4.5] {
            b.limb(from: at + Vec3(0.04 * Float(cos(Double(angle))), 0, 0.04 * Float(sin(Double(angle)))), to: at + Vec3(0, 0.08, 0),
                   radius: 0.0025, color: Palette.timberDark)
        }
        b.place(.translation(at + Vec3(0, 0.035, 0))) {
            $0.lathe([(0.012, 0), (0.018, 0.01), (0.015, 0.025)], sides: 8, color: Palette.iron)
        }
    }

    /// The ward: a long hall, timber under thatch or white stone under
    /// slate, its door, its windows lit and its chimney.
    static func ward(_ b: inout MeshBuilder, at: Vec3, stone: Bool, width: Float) {
        let depth: Float = 0.12, height: Float = stone ? 0.12 : 0.1
        b.hall(at: at, width: width, depth: depth, height: height, wall: stone ? Palette.stoneWhite : Palette.timberPale,
               roof: stone ? Palette.slate : Palette.thatch, pitch: 0.65, footing: stone ? Palette.stone : nil)
        b.door(at + Vec3(0, 0.045, depth / 2 + 0.002), width: 0.035, height: 0.075, facing: 0)
        for x in stride(from: -width / 2 + 0.035, to: width / 2 - 0.02, by: 0.05) where abs(x) > 0.03 {
            b.window(at + Vec3(x, height * 0.6, depth / 2 + 0.002), width: 0.016, height: 0.028, facing: 0)
        }
        b.box(min: at + Vec3(0.075, height - 0.01, -0.05), max: at + Vec3(0.105, 0.22, -0.02), color: Palette.stoneDark)
        b.fine { b in
            b.box(min: at + Vec3(0.071, 0.22, -0.054), max: at + Vec3(0.109, 0.23, -0.016), color: Palette.stone)
            // The healers' sign over the door: a cross of linen on a board.
            b.box(center: at + Vec3(0, 0.1, depth / 2 + 0.005), size: Vec3(0.03, 0.022, 0.003), color: Palette.timberDark)
            b.box(center: at + Vec3(0, 0.1, depth / 2 + 0.007), size: Vec3(0.004, 0.016, 0.002), color: Palette.linen)
            b.box(center: at + Vec3(0, 0.1, depth / 2 + 0.007), size: Vec3(0.016, 0.004, 0.002), color: Palette.linen)
        }
    }

    /// A second wing of the cloister, turned to face the court.
    static func wing(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.2, depth: 0.09, height: 0.1, wall: Palette.stoneWhite, roof: Palette.slate, pitch: 0.65, turn: .pi / 2,
               footing: Palette.stone)
        for z in [Float(-0.06), 0.0, 0.06] {
            b.window(at + Vec3(0.046, 0.06, z), width: 0.014, height: 0.024, facing: .pi / 2)
            b.limb(from: at + Vec3(0.065, 0, z + 0.03), to: at + Vec3(0.065, 0.08, z + 0.03), radius: 0.004, color: Palette.stonePale)
        }
        b.box(min: at + Vec3(0.045, 0.08, -0.1), max: at + Vec3(0.075, 0.088, 0.1), color: Palette.slate)
    }

    /// Raised beds of herbs, low timber borders full of green.
    static func herbs(_ b: inout MeshBuilder, at: Vec3, beds: Int) {
        for index in 0..<beds {
            let p = at + Vec3(Float(index) * 0.07 - Float(beds - 1) * 0.035, 0, 0)
            b.box(min: p + Vec3(-0.03, 0, -0.025), max: p + Vec3(0.03, 0.02, 0.025), color: Palette.timberDark)
            b.box(min: p + Vec3(-0.026, 0.02, -0.021), max: p + Vec3(0.026, 0.024, 0.021), color: Palette.loam)
            for (dx, dz) in [(-0.015, -0.01), (0.0, 0.008), (0.015, -0.006), (-0.008, 0.012), (0.012, 0.012)] as [(Float, Float)] {
                b.sphere(center: p + Vec3(dx, 0.03, dz), radius: 0.008, rings: 2, sides: 5,
                         color: index % 2 == 0 ? Palette.moss : Palette.moss.mix(Palette.weld, 0.3))
            }
        }
    }

    /// The well and its windlass, the drum turning as water is drawn.
    static func well(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        b.place(.translation(at)) {
            $0.lathe([(0.03, 0), (0.03, 0.04), (0.034, 0.045), (0.022, 0.045)], sides: 10, color: Palette.stone)
        }
        b.box(min: at + Vec3(-0.018, 0.04, -0.018), max: at + Vec3(0.018, 0.041, 0.018), color: Palette.seaWool)
        for x in [Float(-0.03), 0.03] {
            b.limb(from: at + Vec3(x, 0.04, 0), to: at + Vec3(x, 0.1, 0), radius: 0.004, color: Palette.timberDark)
        }
        b.place(.translation(at + Vec3(0, 0.1, 0))) {
            $0.gableRoof(width: 0.075, depth: 0.05, base: 0.0, height: 0.03, color: Palette.slate, overhang: 0.006)
        }
        let drum = rig.add("well windlass", pivot: at + Vec3(0, 0.085, 0))
        b.with(part: drum) { b in
            b.place(.translation(at + Vec3(0, 0.085, 0)) * .rotationZ(.pi / 2)) {
                $0.lathe([(0.008, -0.028), (0.008, 0.028)], sides: 6, color: Palette.timber)
            }
            b.beam(from: at + Vec3(0.035, 0.085, 0), to: at + Vec3(0.035, 0.11, 0.0), width: 0.003, color: Palette.iron)
        }
        b.limb(from: at + Vec3(0, 0.08, 0), to: at + Vec3(0, 0.05, 0), radius: 0.0012, color: Palette.linen)
        return Machinery.Wheel(part: drum, axis: Vec3(1, 0, 0), turns: 1)
    }

    /// A bath-house of stone with its round roof and a steaming copper.
    static func bathHouse(_ b: inout MeshBuilder, at: Vec3) {
        b.roundHouse(at: at, radius: 0.045, height: 0.07, wall: Palette.stonePale, roof: Palette.slate, roofHeight: 0.05, sides: 10)
        b.door(at + Vec3(0.046, 0.03, 0), width: 0.022, height: 0.045, facing: .pi / 2)
        b.place(.translation(at + Vec3(0.06, 0, -0.04))) {
            $0.lathe([(0.016, 0), (0.02, 0.02), (0.018, 0.03)], sides: 8, color: Palette.bronze)
        }
    }

    /// Lanterns on posts along the walk to the door.
    static func lanternWalk(_ b: inout MeshBuilder, z: Float) {
        for x in [Float(-0.06), 0.06] {
            let foot = Vec3(x, 0, z)
            b.limb(from: foot, to: foot + Vec3(0, 0.1, 0), radius: 0.003, color: Palette.iron)
            b.with(material: .glow) {
                $0.place(.translation(foot + Vec3(0, 0.1, 0))) {
                    $0.lathe([(0.0, -0.01), (0.008, -0.004), (0.008, 0.008), (0.0, 0.012)], sides: 6, color: Palette.candle)
                }
            }
        }
    }

    /// Beds carried out to air on trestles in the sun.
    static func airingBeds(_ b: inout MeshBuilder, at: Vec3) {
        for index in 0..<3 {
            let p = at + Vec3(Float(index) * 0.05 - 0.05, 0, 0)
            for dz in [Float(-0.02), 0.02] {
                b.limb(from: p + Vec3(0, 0, dz), to: p + Vec3(0, 0.025, dz), radius: 0.003, color: Palette.timberDark)
            }
            b.box(center: p + Vec3(0, 0.03, 0), size: Vec3(0.035, 0.008, 0.055), color: Palette.linen)
        }
    }

    /// The great hospice: a hall of white stone crowned with a dome and a
    /// lantern of moonsalt, buttressed.
    static func hospice(_ b: inout MeshBuilder, at: Vec3) {
        ward(&b, at: at, stone: true, width: 0.3)
        b.place(.translation(at + Vec3(-0.04, 0.12, 0))) { b in
            b.lathe([(0.055, 0), (0.055, 0.03)], sides: 12, color: Palette.stoneWhite)
            b.lathe([(0.058, 0.03), (0.052, 0.06), (0.035, 0.09), (0.0, 0.105)], sides: 12, color: Palette.slate)
            b.with(material: .glow) {
                $0.lathe([(0.0, 0.105), (0.012, 0.11), (0.01, 0.13), (0.0, 0.14)], sides: 6, color: Palette.moonsalt)
            }
        }
        for x in [Float(-0.15), -0.05, 0.05, 0.15] {
            b.box(center: at + Vec3(x, 0.05, -0.075), size: Vec3(0.018, 0.12, 0.022), color: Palette.stone)
        }
    }

    /// The healers' bell in its stone cote.
    static func bellCote(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.022), 0.022] {
            b.box(center: at + Vec3(x, 0.08, 0), size: Vec3(0.012, 0.16, 0.03), color: Palette.stonePale)
        }
        b.place(.translation(at + Vec3(0, 0.16, 0))) {
            $0.gableRoof(width: 0.06, depth: 0.04, base: 0, height: 0.025, color: Palette.slate, overhang: 0.006)
        }
        b.place(.translation(at + Vec3(0, 0.115, 0))) {
            $0.lathe([(0.0, 0.03), (0.008, 0.028), (0.013, 0.01), (0.016, 0.0)], sides: 8, color: Palette.bronze)
        }
    }

    /// Fallen petals of the physic garden about the yard.
    static func petals(_ b: inout MeshBuilder) {
        for index in 0..<16 {
            let angle = Float(index) * 2.39996
            let r = 0.08 + 0.18 * Float((index * 13) % 11) / 11
            b.box(center: Vec3(r * Float(cos(Double(angle))), 0.0125, r * Float(sin(Double(angle)))), size: Vec3(0.008, 0.002, 0.008),
                  turn: angle, color: index % 3 == 0 ? Palette.linen : Palette.moss)
        }
    }
}
