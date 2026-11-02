import Foundation
import NullmereCore

/// The Saltworks, modelled whole at each level, where the black lake's
/// brine is dried to moonsalt; it faces +z, within a work's slot.
///
/// 1. Shallow pans in the shore mud, a crust of salt in each, a rake on its
///    frame and the salt-maker's hut under thatch.
/// 2. Pans in a grid on timber walkways, a shaduf dipping brine from its
///    trough, cones of raked salt.
/// 3. A boiling house of stone with its furnace and chimney, lead pans
///    steaming beside it, the salt packed in sacks.
/// 4. A brine wheel of buckets turning in its race, racks of salt cakes
///    drying, the store under slate.
/// 5. A refinery tower of white stone where moonsalt is crystallised, its
///    crystals lit from within, terraced pans about it, banners.
///
/// The shaduf dips and the brine wheel turns.
enum Saltworks {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.loam.mix(Palette.yard, 0.4), sides: 12)
        b.fine { crust(&$0) }
        // A dyke of stones round the back of the pans, rising as they grow,
        // salt heaped in cones along the bank, a sluice to let the brine in.
        Lodge.boundary(&b, courses: min(level, 3))
        cones(&b, at: Vec3(-0.05, 0, 0.22), count: min(level + 1, 4))
        sluice(&b, at: Vec3(-0.25, 0, 0.06))
        var wheels: [Machinery.Wheel] = []
        var swings: [Machinery.Swing] = []
        switch level {
        case 1:
            pans(&b, columns: 2, rows: 2, origin: Vec3(-0.02, 0, 0.0), walkways: false)
            hut(&b, at: Vec3(-0.19, 0, -0.12), stone: false)
            b.saltHeap(at: Vec3(0.16, 0, 0.16), radius: 0.04, height: 0.04)
            swings.append(shaduf(&b, &rig, at: Vec3(0.17, 0, -0.12)))
        case 2:
            pans(&b, columns: 3, rows: 2, origin: Vec3(0.02, 0, 0.02), walkways: true)
            hut(&b, at: Vec3(-0.19, 0, -0.11), stone: false)
            cones(&b, at: Vec3(-0.15, 0, 0.17), count: 3)
            swings.append(shaduf(&b, &rig, at: Vec3(0.19, 0, -0.15)))
        case 3:
            boilingHouse(&b, at: Vec3(-0.12, 0, -0.12))
            pans(&b, columns: 3, rows: 2, origin: Vec3(0.06, 0, 0.08), walkways: true)
            sacks(&b, at: Vec3(-0.2, 0, 0.12))
            swings.append(shaduf(&b, &rig, at: Vec3(0.2, 0, -0.14)))
        case 4:
            boilingHouse(&b, at: Vec3(-0.12, 0, -0.12))
            pans(&b, columns: 3, rows: 2, origin: Vec3(0.04, 0, 0.1), walkways: true)
            wheels.append(brineWheel(&b, &rig, at: Vec3(0.17, 0, -0.12)))
            racks(&b, at: Vec3(-0.21, 0, 0.13))
        default:
            refinery(&b, at: Vec3(-0.13, 0, -0.12))
            pans(&b, columns: 4, rows: 2, origin: Vec3(0.02, 0, 0.11), walkways: true)
            wheels.append(brineWheel(&b, &rig, at: Vec3(0.18, 0, -0.12)))
            banners(&b)
        }
        let machinery = Machinery(wheels: wheels, swings: swings, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// Pans in a grid, each a shallow bed of crusted brine, with timber
    /// walkways between them from the second level.
    static func pans(_ b: inout MeshBuilder, columns: Int, rows: Int, origin: Vec3, walkways: Bool) {
        let size: Float = 0.075, gap: Float = 0.012
        let width = Float(columns) * (size + gap), depth = Float(rows) * (size + gap)
        for column in 0..<columns {
            for row in 0..<rows {
                let at = origin + Vec3(-width / 2 + (Float(column) + 0.5) * (size + gap), 0, -depth / 2 + (Float(row) + 0.5) * (size + gap))
                b.saltPan(at: at, size: size, crust: Float((column + row) % 3) / 2)
            }
        }
        guard walkways else { return }
        for column in 1..<columns {
            let x = origin.x - width / 2 + Float(column) * (size + gap) - gap / 2
            b.box(center: Vec3(x, 0.016, origin.z), size: Vec3(gap * 0.9, 0.006, depth), color: Palette.timberGrey)
        }
        b.box(center: Vec3(origin.x, 0.016, origin.z + depth / 2 + 0.006), size: Vec3(width, 0.006, 0.012), color: Palette.timberGrey)
    }

    /// The salt-maker's hut, its door and its window lit.
    static func hut(_ b: inout MeshBuilder, at: Vec3, stone: Bool) {
        b.hall(at: at, width: 0.11, depth: 0.09, height: 0.075, wall: stone ? Palette.stonePale : Palette.timber,
               roof: stone ? Palette.slate : Palette.thatch, pitch: 0.7)
        b.door(at + Vec3(0.02, 0.035, 0.046), width: 0.026, height: 0.055, facing: 0)
        b.window(at + Vec3(-0.03, 0.05, 0.046), width: 0.016, height: 0.018, facing: 0)
        b.fine { b in
            b.limb(from: at + Vec3(0.06, 0, 0.05), to: at + Vec3(0.07, 0.11, 0.05), radius: 0.003, color: Palette.timberPale)
            b.box(center: at + Vec3(0.07, 0.11, 0.05), size: Vec3(0.004, 0.006, 0.05), color: Palette.timberPale)
        }
    }

    /// A shaduf: a pole on its post weighted at one end, a bucket on the
    /// other, dipping brine from a trough and lifting it to the pans.
    static func shaduf(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.limb(from: at, to: at + Vec3(0, 0.13, 0), radius: 0.008, color: Palette.timberDark)
        b.box(min: at + Vec3(-0.05, 0, 0.03), max: at + Vec3(0.05, 0.025, 0.07), color: Palette.timberDark)
        b.box(min: at + Vec3(-0.046, 0.02, 0.034), max: at + Vec3(0.046, 0.022, 0.066), color: Palette.seaWool)
        let pivot = at + Vec3(0, 0.13, 0)
        let pole = rig.add("shaduf", pivot: pivot)
        b.with(part: pole) { b in
            b.beam(from: pivot + Vec3(0, 0, -0.08), to: pivot + Vec3(0, 0.03, 0.12), width: 0.006, color: Palette.timber)
            b.sphere(center: pivot + Vec3(0, -0.005, -0.08), radius: 0.018, rings: 3, sides: 6, color: Palette.stone)
            b.limb(from: pivot + Vec3(0, 0.03, 0.12), to: pivot + Vec3(0, -0.04, 0.12), radius: 0.0015, color: Palette.linen)
            b.place(.translation(pivot + Vec3(0, -0.055, 0.12))) {
                $0.lathe([(0.01, -0.012), (0.013, 0.01)], sides: 6, color: Palette.timberDark)
            }
        }
        return Machinery.Swing(part: pole, axis: Vec3(1, 0, 0), angle: 0.35)
    }

    /// Cones of raked salt drying on the bank.
    static func cones(_ b: inout MeshBuilder, at: Vec3, count: Int) {
        for index in 0..<count {
            b.saltHeap(at: at + Vec3(Float(index) * 0.045, 0, Float(index % 2) * 0.02), radius: 0.022, height: 0.035)
        }
    }

    /// A sluice gate in the bank: two posts, a board raised in its slots.
    static func sluice(_ b: inout MeshBuilder, at: Vec3) {
        for z in [Float(-0.025), 0.025] {
            b.limb(from: at + Vec3(0, -0.01, z), to: at + Vec3(0, 0.08, z), radius: 0.005, color: Palette.timberDark)
        }
        b.box(center: at + Vec3(0, 0.05, 0), size: Vec3(0.008, 0.04, 0.05), color: Palette.timber)
        b.beam(from: at + Vec3(0, 0.08, -0.03), to: at + Vec3(0, 0.08, 0.03), width: 0.006, color: Palette.timberDark)
        b.box(min: at + Vec3(0.005, 0, -0.02), max: at + Vec3(0.08, 0.004, 0.02), color: Palette.seaWool)
    }

    /// Sacks of salt packed by the boiling house.
    static func sacks(_ b: inout MeshBuilder, at: Vec3) {
        for index in 0..<5 {
            let angle = Float(index) * 1.7
            b.tiedSack(at: at + Vec3(0.025 * Float(cos(Double(angle))), Float(index / 3) * 0.02, 0.025 * Float(sin(Double(angle)))),
                       size: 0.02, color: Palette.linen)
        }
    }

    /// The boiling house: stone under slate, its furnace mouth glowing and
    /// its chimney, lead pans steaming beside it.
    static func boilingHouse(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.16, depth: 0.12, height: 0.1, wall: Palette.stone, roof: Palette.slate, pitch: 0.65, footing: Palette.stoneDark)
        b.door(at + Vec3(-0.035, 0.045, 0.061), width: 0.03, height: 0.07, facing: 0)
        b.with(material: .glow) {
            $0.box(center: at + Vec3(0.04, 0.025, 0.062), size: Vec3(0.03, 0.022, 0.006), color: Palette.fire)
        }
        b.box(min: at + Vec3(0.045, 0.09, -0.04), max: at + Vec3(0.075, 0.24, -0.01), color: Palette.stoneDark)
        b.fine { b in
            b.box(min: at + Vec3(0.041, 0.24, -0.044), max: at + Vec3(0.079, 0.25, -0.006), color: Palette.stone)
            for x in [Float(-0.05), 0.01] {
                b.box(min: at + Vec3(x, 0.0, 0.07), max: at + Vec3(x + 0.05, 0.02, 0.1), color: Palette.iron)
                b.box(min: at + Vec3(x + 0.003, 0.016, 0.073), max: at + Vec3(x + 0.047, 0.019, 0.097), color: Palette.moonsalt)
            }
        }
    }

    /// Where the boiling house's chimney smokes, at the levels that have one.
    static func chimney(_ level: Int) -> Vec3? {
        guard (3...4).contains(level) else { return nil }
        return Vec3(-0.12, 0, -0.12) + Vec3(0.06, 0.25, -0.025)
    }

    /// A brine wheel: buckets on a wheel turning in its race, lifting brine
    /// into the trough that feeds the pans.
    static func brineWheel(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        let hub = at + Vec3(0, 0.08, 0)
        b.box(min: at + Vec3(-0.035, -0.02, -0.06), max: at + Vec3(0.035, 0.01, 0.06), color: Palette.stoneDark)
        b.box(min: at + Vec3(-0.03, 0.002, -0.055), max: at + Vec3(0.03, 0.006, 0.055), color: Palette.seaWool)
        for z in [Float(-0.035), 0.035] {
            b.box(center: hub + Vec3(0, -0.04, z), size: Vec3(0.012, 0.1, 0.01), color: Palette.timberDark)
        }
        b.beam(from: hub + Vec3(0, 0.08, 0), to: hub + Vec3(-0.12, 0.05, 0), width: 0.02, depth: 0.012, color: Palette.timber)
        let wheel = rig.add("brine wheel", pivot: hub)
        b.with(part: wheel) { b in
            b.wheel(center: hub, radius: 0.075, width: 0.05, spokes: 6, color: Palette.timber, rim: Palette.timberDark)
            for index in 0..<8 {
                let angle = Float(index) / 8 * 2 * .pi
                let p = hub + Vec3(0.075 * Float(cos(Double(angle))), 0.075 * Float(sin(Double(angle))), 0)
                b.box(center: p, size: Vec3(0.018, 0.018, 0.04), color: Palette.timberDark)
            }
        }
        return Machinery.Wheel(part: wheel, axis: Vec3(0, 0, 1), turns: 1)
    }

    /// Racks where cakes of salt dry.
    static func racks(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.04), 0.04] {
            b.limb(from: at + Vec3(x, 0, 0), to: at + Vec3(x, 0.1, 0), radius: 0.004, color: Palette.timberDark)
        }
        for y in [Float(0.035), 0.07, 0.1] {
            b.box(center: at + Vec3(0, y, 0), size: Vec3(0.09, 0.004, 0.035), color: Palette.timberGrey)
            for x in stride(from: Float(-0.03), through: 0.03, by: 0.02) {
                b.box(center: at + Vec3(x, y + 0.008, 0), size: Vec3(0.014, 0.012, 0.02), color: Palette.saltCrust)
            }
        }
    }

    /// The refinery tower of the fifth level: white stone, its crystals of
    /// moonsalt lit from within, a lantern room on its crown.
    static func refinery(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at + Vec3(0.04, 0, 0.02), width: 0.15, depth: 0.12, height: 0.11, wall: Palette.stoneWhite, roof: Palette.slate,
               pitch: 0.65, footing: Palette.stone)
        b.door(at + Vec3(0.04, 0.05, 0.081), width: 0.03, height: 0.07, facing: 0)
        b.roundHouse(at: at + Vec3(-0.04, 0, -0.04), radius: 0.045, height: 0.28, wall: Palette.stoneWhite, roof: Palette.slate,
                     roofHeight: 0.08, sides: 10)
        for (index, y) in [Float(0.12), 0.2].enumerated() {
            let angle = Float(index) * 2.4 + 0.5
            b.window(at + Vec3(-0.04, 0, -0.04) + MeshBuilder.ring(0.045, y, angle), width: 0.014, height: 0.03, facing: angle + .pi / 2,
                     color: Palette.moonGlow)
        }
        b.with(material: .glow) { b in
            for index in 0..<5 {
                let angle = Float(index) * 1.25
                let p = at + Vec3(0.1 + 0.03 * Float(cos(Double(angle))), 0, 0.12 + 0.03 * Float(sin(Double(angle))))
                b.place(.translation(p) * .rotationZ(0.2 * Float(index % 2 == 0 ? 1 : -1))) {
                    $0.lathe([(0.0, 0), (0.008, 0.01), (0.005, 0.04), (0.0, 0.05)], sides: 5, color: Palette.moonsalt)
                }
            }
        }
    }

    /// The House's banners at the pans.
    static func banners(_ b: inout MeshBuilder) {
        for x in [Float(-0.24), 0.24] {
            let foot = Vec3(x, 0, 0.16)
            b.limb(from: foot, to: foot + Vec3(0, 0.2, 0), radius: 0.005, color: Palette.timberDark)
            b.flag(at: foot + Vec3(0, 0.195, 0), width: 0.045, height: 0.085, turn: x > 0 ? .pi : 0, tail: true)
        }
    }

    /// Flecks of salt and the lake's weed strewn on the mud.
    static func crust(_ b: inout MeshBuilder) {
        for index in 0..<16 {
            let angle = Float(index) * 2.39996
            let r = 0.12 + 0.17 * Float((index * 17) % 9) / 9
            b.box(center: Vec3(r * Float(cos(Double(angle))), 0.0125, r * Float(sin(Double(angle)))), size: Vec3(0.012, 0.002, 0.009),
                  turn: angle, color: index % 3 == 0 ? Palette.moss : Palette.saltCrust)
        }
    }
}
