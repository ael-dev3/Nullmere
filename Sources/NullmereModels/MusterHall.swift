import Foundation
import NullmereCore

/// The Muster Hall, modelled whole at each level, where the House's
/// companies are raised and drilled; it faces +z, within a work's slot.
///
/// 1. A drill yard staked about, pells to strike at, a rack of spears and
///    a tent for the drill-master.
/// 2. A timber barracks under thatch, archery butts at the yard's end.
/// 3. Barracks of stone under slate, the armoury beside them, the yard
///    sanded.
/// 4. A drill tower over the yard where the drill-master calls, a parade
///    ground flagged, the House's standard on its staff.
/// 5. A gatehouse of two towers before the hall, the war drum on its stand
///    and banners on the towers.
///
/// At every level a quintain spins on its post as the companies ride at it.
enum MusterHall {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.yard, sides: 12)
        b.fine { scuffs(&$0) }
        stakes(&b, height: level >= 3 ? 0.06 : 0.05)
        var swings = [quintain(&b, &rig, at: Vec3(0.12, 0, 0.13))]
        switch level {
        case 1:
            pells(&b, xs: [-0.08, -0.02], z: 0.12)
            rack(&b, at: Vec3(-0.2, 0, 0.08))
            tent(&b, at: Vec3(-0.08, 0, -0.15))
        case 2:
            barracks(&b, at: Vec3(-0.04, 0, -0.14), stone: false, width: 0.26)
            pells(&b, xs: [-0.12, -0.06], z: 0.14)
            butts(&b, at: Vec3(-0.22, 0, 0.06))
            rack(&b, at: Vec3(0.21, 0, -0.04))
        case 3:
            barracks(&b, at: Vec3(-0.04, 0, -0.14), stone: true, width: 0.27)
            armoury(&b, at: Vec3(0.2, 0, -0.08))
            pells(&b, xs: [-0.14, -0.08, -0.02], z: 0.15)
            butts(&b, at: Vec3(-0.22, 0, 0.05))
        case 4:
            barracks(&b, at: Vec3(-0.06, 0, -0.14), stone: true, width: 0.24)
            drillTower(&b, at: Vec3(0.19, 0, -0.13))
            paradeGround(&b, at: Vec3(-0.06, 0, 0.1))
            standard(&b, at: Vec3(-0.21, 0, 0.17))
            butts(&b, at: Vec3(-0.24, 0, 0.0))
            rack(&b, at: Vec3(0.22, 0, 0.04))
            pells(&b, xs: [0.0, 0.05], z: 0.22)
        default:
            barracks(&b, at: Vec3(-0.0, 0, -0.17), stone: true, width: 0.24)
            gatehouse(&b, at: Vec3(-0.06, 0, 0.02))
            paradeGround(&b, at: Vec3(-0.06, 0, 0.17))
            drum(&b, at: Vec3(0.2, 0, -0.04))
            swings.append(drumstick(&b, &rig, at: Vec3(0.2, 0, -0.04)))
            rack(&b, at: Vec3(-0.22, 0, -0.02))
            pells(&b, xs: [0.18, 0.23], z: 0.05)
            standard(&b, at: Vec3(0.12, 0, 0.24))
            standard(&b, at: Vec3(-0.22, 0, 0.17))
        }
        let machinery = Machinery(swings: swings, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// Stakes round the yard's edge, sharpened, a rope between them.
    static func stakes(_ b: inout MeshBuilder, height: Float) {
        let count = 20
        var last: Vec3?
        for index in 0..<count {
            let angle = Float.pi * (0.15 + 0.7 * Float(index) / Float(count - 1))
            let foot = MeshBuilder.ring(0.3, 0, angle)
            b.place(.translation(foot)) {
                $0.tube([(0.006, -0.02), (0.006, height)], sides: 4, color: Palette.timber)
                $0.cone(sides: 4, radius: 0.006, from: height, to: height + 0.012, color: Palette.timberPale)
            }
            if let last { b.fine { $0.beam(from: last + Vec3(0, height * 0.7, 0), to: foot + Vec3(0, height * 0.7, 0), width: 0.002, color: Palette.linen) } }
            last = foot
        }
    }

    /// Pells: posts to strike at with sword and spear, hacked and scarred.
    static func pells(_ b: inout MeshBuilder, xs: [Float], z: Float) {
        for x in xs {
            b.place(.translation(Vec3(x, 0, z))) {
                $0.lathe([(0.012, 0), (0.011, 0.09), (0.008, 0.1)], sides: 6, color: Palette.timberGrey)
            }
            b.fine { b in
                for y in [Float(0.04), 0.07] {
                    b.box(center: Vec3(x + 0.011, y, z), size: Vec3(0.003, 0.006, 0.01), turn: 0.4, color: Palette.timberPale)
                }
            }
        }
    }

    /// A rack of spears and shields.
    static func rack(_ b: inout MeshBuilder, at: Vec3) {
        for z in [Float(-0.05), 0.05] {
            b.limb(from: at + Vec3(0, 0, z), to: at + Vec3(0, 0.11, z), radius: 0.004, color: Palette.timberDark)
        }
        b.beam(from: at + Vec3(0, 0.1, -0.055), to: at + Vec3(0, 0.1, 0.055), width: 0.005, color: Palette.timber)
        for (index, z) in stride(from: Float(-0.04), through: 0.04, by: 0.016).enumerated() {
            b.limb(from: at + Vec3(0.012, 0, z), to: at + Vec3(-0.004, 0.17, z), radius: 0.0022, color: Palette.timberPale)
            b.with(material: .metal) {
                $0.place(.translation(at + Vec3(-0.004, 0.17, z))) {
                    $0.cone(sides: 4, radius: 0.004, from: 0, to: 0.018, color: Palette.steel)
                }
            }
            if index % 2 == 0 {
                b.place(.translation(at + Vec3(0.016, 0.045, z)) * .rotationZ(.pi / 2)) {
                    $0.lathe([(0.0, 0), (0.016, 0.002), (0.016, 0.006), (0.0, 0.008)], sides: 8, color: Palette.house)
                }
            }
        }
    }

    /// The drill-master's tent: a ridge pole and its canvas.
    static func tent(_ b: inout MeshBuilder, at: Vec3) {
        let w: Float = 0.08, d: Float = 0.11, h: Float = 0.08
        b.sheet([at + Vec3(-w, 0, -d / 2), at + Vec3(-w, 0, d / 2), at + Vec3(0, h, d / 2), at + Vec3(0, h, -d / 2)],
                normal: Vec3(-1, 1, 0), thickness: 0.004, color: Palette.canvas)
        b.sheet([at + Vec3(w, 0, d / 2), at + Vec3(w, 0, -d / 2), at + Vec3(0, h, -d / 2), at + Vec3(0, h, d / 2)],
                normal: Vec3(1, 1, 0), thickness: 0.004, color: Palette.canvas)
        b.limb(from: at + Vec3(0, 0, d / 2 + 0.004), to: at + Vec3(0, h + 0.02, d / 2 + 0.004), radius: 0.003, color: Palette.timberDark)
        b.flag(at: at + Vec3(0, h + 0.02, d / 2 + 0.004), width: 0.03, height: 0.02, turn: 0.3)
    }

    /// The barracks: a long hall, its doors and windows lit, timber under
    /// thatch or stone under slate.
    static func barracks(_ b: inout MeshBuilder, at: Vec3, stone: Bool, width: Float) {
        let depth: Float = 0.12, height: Float = stone ? 0.11 : 0.09
        b.hall(at: at, width: width, depth: depth, height: height, wall: stone ? Palette.stone : Palette.timber,
               roof: stone ? Palette.slate : Palette.thatch, pitch: 0.65, footing: stone ? Palette.stoneDark : nil)
        b.door(at + Vec3(0, 0.045, depth / 2 + 0.002), width: 0.035, height: 0.075, facing: 0)
        for x in stride(from: -width / 2 + 0.035, to: width / 2 - 0.02, by: 0.05) where abs(x) > 0.03 {
            b.window(at + Vec3(x, height * 0.6, depth / 2 + 0.002), width: 0.016, height: 0.024, facing: 0)
        }
        b.fine { b in
            b.box(center: at + Vec3(0, 0.088, depth / 2 + 0.006), size: Vec3(0.05, 0.01, 0.008), color: stone ? Palette.stonePale : Palette.timberDark)
        }
    }

    /// Archery butts: straw boss on a frame, painted rings.
    static func butts(_ b: inout MeshBuilder, at: Vec3) {
        for z in [Float(-0.03), 0.03] {
            b.limb(from: at + Vec3(-0.01, 0, z), to: at + Vec3(0.005, 0.08, z), radius: 0.003, color: Palette.timberDark)
        }
        b.place(.translation(at + Vec3(0, 0.05, 0)) * .rotationZ(.pi / 2 - 0.15)) {
            $0.lathe([(0.0, -0.01), (0.035, -0.008), (0.035, 0.008), (0.0, 0.01)], sides: 10, color: Palette.straw)
        }
        b.fine { b in
            b.place(.translation(at + Vec3(0.012, 0.05, 0)) * .rotationZ(.pi / 2 - 0.15)) {
                $0.lathe([(0.0, 0.0), (0.02, 0.001), (0.02, 0.002), (0.0, 0.003)], sides: 10, color: Palette.madder)
            }
            for (dz, dy) in [(Float(0.008), Float(0.004)), (-0.012, 0.01), (0.004, -0.01)] {
                b.limb(from: at + Vec3(0.01, 0.05 + dy, dz), to: at + Vec3(0.05, 0.055 + dy, dz), radius: 0.0012, color: Palette.timberPale)
            }
        }
    }

    /// The armoury: a small stone house, its door iron-bound.
    static func armoury(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.09, depth: 0.1, height: 0.09, wall: Palette.stoneDark, roof: Palette.slate, pitch: 0.7, turn: .pi / 2,
               footing: Palette.stone)
        b.door(at + Vec3(-0.051, 0.04, 0), width: 0.03, height: 0.06, facing: -.pi / 2, color: Palette.iron)
        b.fine { b in
            for y in [Float(0.02), 0.055] {
                b.box(center: at + Vec3(-0.058, y, 0), size: Vec3(0.002, 0.004, 0.03), color: Palette.steel)
            }
        }
    }

    /// The drill tower: a timber tower on a stone foot, its platform where
    /// the drill-master calls, roofed.
    static func drillTower(_ b: inout MeshBuilder, at: Vec3) {
        b.box(center: at + Vec3(0, 0.03, 0), size: Vec3(0.08, 0.06, 0.08), color: Palette.stone)
        for (sx, sz) in [(-1, -1), (1, -1), (1, 1), (-1, 1)] as [(Float, Float)] {
            b.limb(from: at + Vec3(sx * 0.03, 0.06, sz * 0.03), to: at + Vec3(sx * 0.03, 0.27, sz * 0.03), radius: 0.006, color: Palette.timberDark)
        }
        b.box(center: at + Vec3(0, 0.2, 0), size: Vec3(0.085, 0.01, 0.085), color: Palette.timberPale)
        b.box(center: at + Vec3(0, 0.225, 0.04), size: Vec3(0.08, 0.035, 0.004), color: Palette.timber)
        b.place(.translation(at + Vec3(0, 0.27, 0))) {
            $0.hipRoof(width: 0.1, depth: 0.1, base: 0, height: 0.05, color: Palette.slate, overhang: 0.008)
        }
        b.fine { b in
            b.ladder(from: at + Vec3(0.045, 0.06, 0.0), to: at + Vec3(0.045, 0.2, 0.0), width: 0.025, rungs: 5, color: Palette.timberPale)
        }
    }

    /// The parade ground: flags laid in a broad rectangle.
    static func paradeGround(_ b: inout MeshBuilder, at: Vec3) {
        b.box(center: at + Vec3(0, 0.005, 0), size: Vec3(0.22, 0.01, 0.1), color: Palette.stonePale)
        b.fine { b in
            for x in stride(from: Float(-0.1), through: 0.1, by: 0.04) {
                b.box(center: at + Vec3(x, 0.0105, 0), size: Vec3(0.002, 0.001, 0.1), color: Palette.stone)
            }
        }
    }

    /// The House's standard on its tall staff.
    static func standard(_ b: inout MeshBuilder, at: Vec3) {
        b.box(center: at + Vec3(0, 0.01, 0), size: Vec3(0.03, 0.02, 0.03), color: Palette.stone)
        b.limb(from: at, to: at + Vec3(0, 0.3, 0), radius: 0.004, color: Palette.timberDark)
        b.flag(at: at + Vec3(0, 0.295, 0), width: 0.07, height: 0.05, turn: 0.2, tail: true)
        b.fine { $0.sphere(center: at + Vec3(0, 0.305, 0), radius: 0.007, rings: 2, sides: 5, color: Palette.gold) }
    }

    /// The gatehouse of the fifth level: two round towers, an arch between,
    /// a walk over it, banners on the towers.
    static func gatehouse(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.08), 0.08] {
            b.roundHouse(at: at + Vec3(x, 0, 0), radius: 0.04, height: 0.2, wall: Palette.stone, roof: Palette.slate, roofHeight: 0.07, sides: 10)
            b.window(at + Vec3(x, 0, 0) + MeshBuilder.ring(0.04, 0.13, .pi / 2), width: 0.01, height: 0.026, facing: .pi)
            b.flag(at: at + Vec3(x, 0.3, 0), width: 0.04, height: 0.03, turn: x > 0 ? .pi : 0)
        }
        b.box(min: at + Vec3(-0.05, 0.1, -0.025), max: at + Vec3(0.05, 0.16, 0.025), color: Palette.stone)
        b.place(.translation(at)) {
            $0.merlons(from: Vec3(-0.05, 0.16, 0.02), to: Vec3(0.05, 0.16, 0.02), count: 4, size: Vec3(0.015, 0.02, 0.01), color: Palette.stone)
        }
        b.door(at + Vec3(0, 0.05, 0.026), width: 0.05, height: 0.1, facing: 0, color: Palette.timberDark)
    }

    /// The war drum on its stand.
    static func drum(_ b: inout MeshBuilder, at: Vec3) {
        for (dx, dz) in [(-0.03, -0.03), (0.03, -0.03), (0, 0.035)] as [(Float, Float)] {
            b.limb(from: at + Vec3(dx, 0, dz), to: at + Vec3(0, 0.06, 0), radius: 0.003, color: Palette.timberDark)
        }
        b.place(.translation(at + Vec3(0, 0.06, 0))) {
            $0.lathe([(0.035, 0), (0.038, 0.02), (0.035, 0.04)], sides: 12, color: Palette.madder)
            $0.lathe([(0.0, 0.04), (0.035, 0.041)], sides: 12, color: Palette.linen)
        }
    }

    /// The drumstick, beating the drill.
    static func drumstick(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        let pivot = at + Vec3(0.05, 0.12, 0)
        b.limb(from: at + Vec3(0.05, 0, 0), to: pivot, radius: 0.003, color: Palette.timberDark)
        let stick = rig.add("drumstick", pivot: pivot)
        b.with(part: stick) { b in
            b.limb(from: pivot, to: pivot + Vec3(-0.045, -0.01, 0), radius: 0.0025, color: Palette.timberPale)
            b.sphere(center: pivot + Vec3(-0.047, -0.011, 0), radius: 0.006, rings: 2, sides: 5, color: Palette.leather)
        }
        return Machinery.Swing(part: stick, axis: Vec3(0, 0, 1), angle: 0.4)
    }

    /// The quintain: a post with an arm, a shield at one end and a sandbag
    /// at the other, spinning when struck.
    static func quintain(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.limb(from: at, to: at + Vec3(0, 0.12, 0), radius: 0.006, color: Palette.timberDark)
        let pivot = at + Vec3(0, 0.12, 0)
        let arm = rig.add("quintain", pivot: pivot)
        b.with(part: arm) { b in
            b.beam(from: pivot + Vec3(-0.07, 0, 0), to: pivot + Vec3(0.07, 0, 0), width: 0.006, color: Palette.timber)
            b.place(.translation(pivot + Vec3(-0.07, -0.02, 0)) * .rotationZ(.pi / 2)) {
                $0.lathe([(0.0, 0), (0.02, 0.002), (0.02, 0.006), (0.0, 0.008)], sides: 8, color: Palette.house)
            }
            b.limb(from: pivot + Vec3(0.07, 0, 0), to: pivot + Vec3(0.07, -0.035, 0), radius: 0.0015, color: Palette.linen)
            b.tiedSack(at: pivot + Vec3(0.07, -0.05, 0), size: 0.015)
        }
        return Machinery.Swing(part: arm, axis: Vec3(0, 1, 0), angle: 1.2)
    }

    /// The yard scuffed by feet and hooves.
    static func scuffs(_ b: inout MeshBuilder) {
        for index in 0..<16 {
            let angle = Float(index) * 2.39996
            let r = 0.05 + 0.2 * Float((index * 19) % 11) / 11
            b.box(center: Vec3(r * Float(cos(Double(angle))), 0.0125, r * Float(sin(Double(angle)))), size: Vec3(0.016, 0.002, 0.008),
                  turn: angle, color: index % 2 == 0 ? Palette.earth : Palette.straw)
        }
    }
}
