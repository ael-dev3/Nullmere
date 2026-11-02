import Foundation
import NullmereCore

/// The Sawpit, modelled whole at each level, where the House's timber is
/// sawn into boards; it faces +z, within a work's slot.
///
/// 1. A pit dug in the clearing, a log on trestles across it and the
///    pit-saw rocking through it; logs waiting on their chocks, a chopping
///    block with its axe.
/// 2. The pit under an open shed of planks, boards stacked to dry on their
///    sticks, the beetle and wedges by the logs.
/// 3. A saw-house of timber under thatch, its frame saw driven by a horse
///    walking a gin beside it, boards stacked by its door.
/// 4. The saw-house on a stone footing under slate, a drying shed open on
///    its sides, a timber wain loaded with planks.
/// 5. A sawmill of two storeys with a louvre on its ridge and a hoist beam
///    over its loft door, a log pond for seasoning, the House's banner.
enum Sawpit {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.loam, sides: 12)
        b.fine { sawdust(&$0) }
        Lodge.boundary(&b, courses: min(level, 3))
        if level >= 3 { fence(&b, level: level) }
        var wheels: [Machinery.Wheel] = []
        var swings: [Machinery.Swing] = []
        switch level {
        case 1:
            swings.append(pit(&b, &rig, at: Vec3(0.0, 0, -0.04)))
            logs(&b, at: Vec3(-0.18, 0, 0.14), count: 3)
            block(&b, at: Vec3(0.18, 0, 0.14))
            logs(&b, at: Vec3(0.15, 0, -0.15), count: 2)
        case 2:
            swings.append(pit(&b, &rig, at: Vec3(-0.03, 0, -0.06)))
            openShed(&b, at: Vec3(-0.03, 0, -0.06))
            boards(&b, at: Vec3(0.19, 0, 0.06), layers: 4, turn: 0.2)
            logs(&b, at: Vec3(-0.18, 0, 0.15), count: 4)
            beetle(&b, at: Vec3(0.02, 0, 0.17))
            block(&b, at: Vec3(0.2, 0, -0.15))
        case 3:
            swings.append(sawHouse(&b, &rig, at: Vec3(-0.06, 0, -0.1), stone: false))
            wheels.append(gin(&b, &rig, at: Vec3(0.15, 0, 0.0)))
            boards(&b, at: Vec3(-0.12, 0, 0.12), layers: 4, turn: 0)
            logs(&b, at: Vec3(-0.21, 0, 0.0), count: 4, turn: .pi / 2)
            block(&b, at: Vec3(0.02, 0, 0.18))
        case 4:
            swings.append(sawHouse(&b, &rig, at: Vec3(-0.06, 0, -0.1), stone: true))
            wheels.append(gin(&b, &rig, at: Vec3(0.15, 0, 0.0)))
            dryingShed(&b, at: Vec3(-0.12, 0, 0.13))
            wain(&b, at: Vec3(0.11, 0, 0.19))
            logs(&b, at: Vec3(-0.24, 0, -0.02), count: 4, turn: .pi / 2)
            bench(&b, at: Vec3(0.22, 0, 0.12))
            block(&b, at: Vec3(-0.01, 0, 0.22))
        default:
            swings.append(sawHouse(&b, &rig, at: Vec3(-0.06, 0, -0.1), stone: true, storeys: 2))
            wheels.append(gin(&b, &rig, at: Vec3(0.15, 0, 0.0)))
            swings.append(hoistBeam(&b, &rig, at: Vec3(-0.06, 0.2, -0.026)))
            dryingShed(&b, at: Vec3(-0.13, 0, 0.13))
            wain(&b, at: Vec3(0.1, 0, 0.2))
            pond(&b, at: Vec3(-0.23, 0, -0.04))
            bench(&b, at: Vec3(0.23, 0, 0.12))
            logs(&b, at: Vec3(-0.02, 0, 0.22), count: 5)
            b.banner(at: Vec3(0.06, 0.28, -0.1), height: 0.12, width: 0.05, drop: 0.07)
        }
        let machinery = Machinery(wheels: wheels, swings: swings, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// Sawdust trodden pale into the clearing.
    static func sawdust(_ b: inout MeshBuilder) {
        for index in 0..<7 {
            let at = MeshBuilder.ring(0.08 + 0.025 * Float(index % 3), 0, Float(index) * 2.1)
            b.rock(center: at, size: Vec3(0.022, 0.003, 0.018), rings: 2, sides: 6, jitter: 0.3, seed: UInt32(400 + index),
                   color: Palette.timberPale)
        }
    }

    /// The saw pit: its walls shored with planks, a log on trestles across
    /// it and the long saw standing through the log; returns the saw's rock.
    static func pit(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.box(min: at + Vec3(-0.13, -0.03, -0.04), max: at + Vec3(0.13, 0.004, 0.04), color: Palette.barkBlack)
        for z in [Float(-0.042), 0.042] {
            b.box(min: at + Vec3(-0.135, 0, z - 0.004), max: at + Vec3(0.135, 0.012, z + 0.004), color: Palette.timberDark)
        }
        for x in [Float(-0.09), 0.09] {
            for z in [Float(-0.035), 0.035] {
                b.limb(from: at + Vec3(x, 0, z), to: at + Vec3(x, 0.05, z), radius: 0.005, color: Palette.timberDark)
            }
            b.beam(from: at + Vec3(x, 0.05, -0.04), to: at + Vec3(x, 0.05, 0.04), width: 0.01, color: Palette.timber)
        }
        b.log(from: at + Vec3(-0.15, 0.068, 0), to: at + Vec3(0.15, 0.068, 0), radius: 0.017)
        let pivot = at + Vec3(0.04, 0.135, 0)
        let saw = rig.add("pit-saw", pivot: pivot)
        b.with(part: saw) {
            $0.with(material: .metal) {
                $0.box(center: at + Vec3(0.04, 0.07, 0.0), size: Vec3(0.012, 0.15, 0.002), color: Palette.steel)
            }
            $0.beam(from: at + Vec3(0.02, 0.145, 0), to: at + Vec3(0.06, 0.145, 0), width: 0.006, color: Palette.timber)
            $0.beam(from: at + Vec3(0.025, -0.005, 0), to: at + Vec3(0.055, -0.005, 0), width: 0.006, color: Palette.timber)
        }
        b.fine {
            for x in [Float(-0.05), -0.03] {
                $0.with(material: .metal) {
                    $0.place(.translation(at + Vec3(x, 0.088, 0)) * .rotationZ(.pi)) {
                        $0.cone(sides: 4, radius: 0.004, to: 0.014, color: Palette.iron)
                    }
                }
            }
            $0.rock(center: at + Vec3(0.0, -0.02, 0.0), size: Vec3(0.05, 0.012, 0.025), rings: 2, sides: 6, jitter: 0.3, seed: 411,
                    color: Palette.timberPale)
        }
        return .init(part: saw, axis: Vec3(0, 0, 1), angle: 0.12)
    }

    /// Logs on their chocks, waiting for the saw.
    static func logs(_ b: inout MeshBuilder, at: Vec3, count: Int, turn: Float = 0) {
        b.place(.translation(at) * .rotationY(turn)) {
            for x in [Float(-0.05), 0.05] {
                $0.box(center: Vec3(x, 0.006, 0), size: Vec3(0.012, 0.012, Float(count) * 0.032 + 0.01), color: Palette.timberDark)
            }
            for index in 0..<count {
                let row = index < 3 ? 0 : 1
                let z = (Float(index % 3) - 1) * 0.032 + Float(row) * 0.016
                $0.log(from: Vec3(-0.08, 0.026 + Float(row) * 0.028, z), to: Vec3(0.08, 0.026 + Float(row) * 0.028, z), radius: 0.015)
            }
        }
    }

    /// A chopping block, an axe bitten into it.
    static func block(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.lathe([(0.026, 0), (0.026, 0.04)], sides: 7, color: Palette.bark)
            $0.lathe([(0.025, 0.04), (0.0, 0.041)], sides: 7, color: Palette.timberPale)
        }
        b.beam(from: at + Vec3(0.0, 0.045, 0), to: at + Vec3(0.04, 0.09, 0.01), width: 0.005, color: Palette.timber)
        b.with(material: .metal) {
            $0.box(center: at + Vec3(-0.002, 0.046, 0), size: Vec3(0.022, 0.016, 0.004), color: Palette.steel)
        }
        b.fine {
            for index in 0..<3 {
                $0.box(center: at + MeshBuilder.ring(0.045, 0.006, Float(index) * 1.4), size: Vec3(0.02, 0.008, 0.008), turn: Float(index),
                       color: Palette.timberPale)
            }
        }
    }

    /// The beetle and its iron wedges.
    static func beetle(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at) * .rotationY(0.4)) {
            $0.lathe([(0.016, 0), (0.016, 0.045)], sides: 6, color: Palette.timberDark)
            $0.beam(from: Vec3(0, 0.022, 0), to: Vec3(0.08, 0.01, 0), width: 0.006, color: Palette.timber)
            $0.with(material: .metal) {
                for x in [Float(0.03), 0.045] {
                    $0.box(center: Vec3(x, 0.004, 0.03), size: Vec3(0.008, 0.008, 0.02), color: Palette.iron)
                }
            }
        }
    }

    /// An open shed of planks over the pit on six posts.
    static func openShed(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.15), 0.0, 0.15] {
            for z in [Float(-0.08), 0.08] {
                b.limb(from: at + Vec3(x, 0, z), to: at + Vec3(x, 0.19, z), radius: 0.007, color: Palette.timberDark)
            }
            b.beam(from: at + Vec3(x, 0.19, -0.09), to: at + Vec3(x, 0.19, 0.09), width: 0.01, color: Palette.timber)
        }
        b.place(.translation(at)) {
            $0.gableRoof(width: 0.34, depth: 0.2, base: 0.19, height: 0.06, color: Palette.timberGrey, overhang: 0.01)
        }
        b.fine {
            for x in stride(from: Float(-0.16), through: 0.16, by: 0.04) {
                $0.beam(from: at + Vec3(x, 0.192, 0.1), to: at + Vec3(x, 0.252, 0.0), width: 0.004, color: Palette.timberDark)
            }
            $0.with(material: .glow) {
                $0.box(center: at + Vec3(0.0, 0.16, 0.08), size: Vec3(0.012, 0.016, 0.012), color: Palette.candle)
            }
        }
    }

    /// Boards stacked to dry, a stick between each layer.
    static func boards(_ b: inout MeshBuilder, at: Vec3, layers: Int, turn: Float) {
        b.planks(at: at, length: 0.13, layers: layers, turn: turn)
        b.fine {
            $0.place(.translation(at) * .rotationY(turn)) {
                for layer in 1..<layers {
                    for x in [Float(-0.045), 0.045] {
                        $0.box(center: Vec3(x, Float(layer) * 0.022 - 0.001, 0), size: Vec3(0.006, 0.004, 0.104), color: Palette.timberDark)
                    }
                }
            }
        }
    }

    /// The saw-house: timber (or timber on stone), its open saw door, the
    /// frame saw within rising and falling; returns the saw's swing.
    static func sawHouse(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3, stone: Bool, storeys: Int = 1) -> Machinery.Swing {
        let width: Float = 0.24, depth: Float = 0.15, height: Float = storeys == 2 ? 0.22 : 0.14
        b.hall(at: at, width: width, depth: depth, height: height, wall: Palette.timber, roof: stone ? Palette.slate : Palette.thatch,
               pitch: 0.7, footing: stone ? Palette.stoneDark : nil)
        // The saw door, wide open on the frame saw.
        b.box(center: at + Vec3(0.05, 0.05, depth / 2 + 0.002), size: Vec3(0.07, 0.1, 0.004), color: Palette.barkBlack)
        b.window(at + Vec3(-0.07, 0.08, depth / 2 + 0.002), width: 0.022, height: 0.026, facing: 0)
        if storeys == 2 {
            b.window(at + Vec3(-0.07, 0.17, depth / 2 + 0.002), width: 0.02, height: 0.024, facing: 0)
            b.box(center: at + Vec3(0.0, 0.165, depth / 2 + 0.002), size: Vec3(0.04, 0.05, 0.004), color: Palette.timberDark)
            b.place(.translation(at + Vec3(0.0, height + 0.06, 0))) {
                $0.lathe([(0.025, 0), (0.025, 0.04), (0.0, 0.065)], sides: 4, color: Palette.slate)
            }
        }
        // The frame saw at the door: its frame on two posts, the saw blade
        // in a sash that rises and falls on the log fed through.
        let door = at + Vec3(0.05, 0, depth / 2 + 0.03)
        for x in [Float(-0.03), 0.03] {
            b.limb(from: door + Vec3(x, 0, 0), to: door + Vec3(x, 0.13, 0), radius: 0.006, color: Palette.timberDark)
        }
        b.beam(from: door + Vec3(-0.035, 0.13, 0), to: door + Vec3(0.035, 0.13, 0), width: 0.008, color: Palette.timberDark)
        b.log(from: door + Vec3(0, 0.035, -0.05), to: door + Vec3(0, 0.035, 0.09), radius: 0.016)
        let pivot = door + Vec3(0, 0.15, -0.12)
        let sash = rig.add("frame saw", pivot: pivot)
        b.with(part: sash) {
            $0.box(center: door + Vec3(0, 0.07, 0), size: Vec3(0.05, 0.008, 0.008), color: Palette.timber)
            $0.box(center: door + Vec3(0, 0.115, 0), size: Vec3(0.05, 0.008, 0.008), color: Palette.timber)
            $0.with(material: .metal) {
                $0.box(center: door + Vec3(0, 0.092, 0), size: Vec3(0.003, 0.05, 0.004), color: Palette.steel)
            }
            $0.beam(from: door + Vec3(0.02, 0.11, 0), to: door + Vec3(0.1, 0.06, 0), width: 0.005, color: Palette.timberDark)
        }
        b.fine {
            for x in stride(from: -width / 2 + 0.01, through: width / 2, by: 0.06) {
                $0.beam(from: at + Vec3(x, 0, depth / 2 + 0.003), to: at + Vec3(x, height, depth / 2 + 0.003), width: 0.006,
                        color: Palette.timberDark)
            }
            $0.rock(center: door + Vec3(0.02, 0, 0.04), size: Vec3(0.03, 0.01, 0.022), rings: 2, sides: 6, jitter: 0.3, seed: 431,
                    color: Palette.timberPale)
        }
        return .init(part: sash, axis: Vec3(1, 0, 0), angle: 0.1)
    }

    /// The horse gin that drives the saw: an upright with a sweep, a horse
    /// walking its ring, the gear wheel on the upright; returns the turning.
    static func gin(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        b.place(.translation(at)) {
            $0.tube([(0.1, 0.002), (0.085, 0.003)], sides: 14, color: Palette.earth)
        }
        let hub = at + Vec3(0, 0.0, 0)
        let gin = rig.add("gin", pivot: hub)
        b.with(part: gin) {
            $0.limb(from: hub, to: hub + Vec3(0, 0.12, 0), radius: 0.01, color: Palette.timberDark)
            $0.wheel(center: hub + Vec3(0, 0.1, 0), radius: 0.035, width: 0.008, spokes: 4, color: Palette.timber, rim: Palette.timberDark)
            $0.beam(from: hub + Vec3(0, 0.08, 0), to: hub + Vec3(0.09, 0.06, 0), width: 0.01, color: Palette.timber)
            Wayhouse.horse(&$0, at: hub + Vec3(0.092, 0, 0), turn: .pi / 2, coat: Palette.horseDun)
        }
        b.beam(from: at + Vec3(0, 0.1, 0), to: Vec3(-0.0, 0.1, at.z - 0.03), width: 0.008, color: Palette.timberDark)
        return .init(part: gin, axis: Vec3(0, 1, 0), turns: 1)
    }

    /// A drying shed open on its sides, boards racked under its roof.
    static func dryingShed(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.08), 0.08] {
            for z in [Float(-0.05), 0.05] {
                b.limb(from: at + Vec3(x, 0, z), to: at + Vec3(x, 0.13, z), radius: 0.006, color: Palette.timberDark)
            }
        }
        b.place(.translation(at)) {
            $0.gableRoof(width: 0.19, depth: 0.12, base: 0.13, height: 0.045, color: Palette.slate, overhang: 0.008)
        }
        b.planks(at: at, length: 0.15, layers: 4)
        b.fine {
            for layer in 1..<4 {
                for x in [Float(-0.05), 0.05] {
                    $0.box(center: at + Vec3(x, Float(layer) * 0.022 - 0.001, 0), size: Vec3(0.006, 0.004, 0.104), color: Palette.timberDark)
                }
            }
        }
    }

    /// A timber wain loaded with planks.
    static func wain(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at) * .rotationY(-0.15)) { cart in
            cart.box(min: Vec3(-0.06, 0.028, -0.03), max: Vec3(0.06, 0.036, 0.03), color: Palette.timberPale)
            for x in [Float(-0.04), 0.04] {
                for z in [Float(-0.034), 0.034] {
                    cart.wheel(center: Vec3(x, 0.022, z), radius: 0.022, width: 0.005, spokes: 4, color: Palette.timber, rim: Palette.timberDark)
                }
            }
            cart.planks(at: Vec3(0, 0.036, 0), length: 0.12, layers: 2)
            cart.beam(from: Vec3(0.06, 0.03, 0), to: Vec3(0.12, 0.004, 0), width: 0.005, color: Palette.timberDark)
        }
    }

    /// The hoist beam out of the loft door, its rope and a board slung on
    /// it swaying; returns the sway.
    static func hoistBeam(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.beam(from: at + Vec3(0, 0, -0.03), to: at + Vec3(0, 0, 0.05), width: 0.01, color: Palette.timberDark)
        let pivot = at + Vec3(0, 0, 0.045)
        let load = rig.add("hoist", pivot: pivot)
        b.with(part: load) {
            $0.limb(from: pivot, to: pivot + Vec3(0, -0.08, 0), radius: 0.0015, sides: 3, color: Palette.linen)
            $0.box(center: pivot + Vec3(0, -0.085, 0), size: Vec3(0.08, 0.006, 0.02), color: Palette.timberPale)
        }
        return .init(part: load, axis: Vec3(1, 0, 0), angle: 0.15)
    }

    /// A pond where logs season, a few floating in it.
    static func pond(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.lathe([(0.06, 0.0), (0.055, 0.004), (0.0, 0.004)], sides: 10, color: Palette.slate)
        }
        for (index, z) in [Float(-0.025), 0.01].enumerated() {
            b.log(from: at + Vec3(-0.035, 0.008, z), to: at + Vec3(0.035 - Float(index) * 0.01, 0.008, z + 0.01), radius: 0.008)
        }
    }

    /// A post-and-rail fence along the yard's front, a gate left open.
    static func fence(_ b: inout MeshBuilder, level: Int) {
        let posts = 4 + level
        for index in 0..<posts where index != posts / 2 {
            let angle = Float.pi * (0.15 + 0.7 * Float(index) / Float(posts - 1))
            let foot = MeshBuilder.ring(0.29, 0, angle)
            b.limb(from: foot, to: foot + Vec3(0, 0.06, 0), radius: 0.004, sides: 4, color: Palette.timberDark)
            guard index + 1 < posts, index + 1 != posts / 2 else { continue }
            let next = MeshBuilder.ring(0.29, 0, Float.pi * (0.15 + 0.7 * Float(index + 1) / Float(posts - 1)))
            for y in [Float(0.025), 0.05] {
                b.beam(from: foot + Vec3(0, y, 0), to: next + Vec3(0, y, 0), width: 0.004, color: Palette.timber)
            }
        }
    }

    /// The saw-doctor's bench: a trestle bench, a saw blade clamped in its
    /// vice for sharpening, files laid by it.
    static func bench(_ b: inout MeshBuilder, at: Vec3) {
        b.box(center: at + Vec3(0, 0.05, 0), size: Vec3(0.09, 0.008, 0.035), color: Palette.timberPale)
        for x in [Float(-0.035), 0.035] {
            for z in [Float(-0.013), 0.013] {
                b.limb(from: at + Vec3(x, 0, z), to: at + Vec3(x * 0.9, 0.048, z * 0.9), radius: 0.003, sides: 4, color: Palette.timberDark)
            }
        }
        b.box(center: at + Vec3(-0.03, 0.07, 0), size: Vec3(0.012, 0.03, 0.03), color: Palette.timberDark)
        b.with(material: .metal) {
            $0.box(center: at + Vec3(0.005, 0.075, 0), size: Vec3(0.08, 0.016, 0.002), color: Palette.steel)
            $0.box(center: at + Vec3(0.02, 0.056, 0.01), size: Vec3(0.03, 0.003, 0.004), color: Palette.iron)
        }
    }
}
