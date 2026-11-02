import Foundation
import NullmereCore

/// The Wayhouse, modelled whole at each level: the post-house where the
/// House's roads begin and its riders change horses. It faces +z, the road
/// running past its front, within a work's slot.
///
/// 1. A thatched waystation with a horse tethered at its post, a trough,
///    a signpost at the road and the inn's sign swinging on its bracket.
/// 2. A timber inn hall with a stable range of two bays, a rick of hay.
/// 3. An inn of pale stone, two storeys, a cote for the post-birds with a
///    vane turning on it.
/// 4. A gate over the road with its lantern lit, a post-coach in the yard.
/// 5. A waymark pillar crowned with a moonsalt lamp, a long stable range
///    of three bays and a second coach ready.
enum Wayhouse {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.yard, sides: 12)
        road(&b, level: level)
        var wheels: [Machinery.Wheel] = []
        var swings: [Machinery.Swing] = []
        switch level {
        case 1:
            waystation(&b, at: Vec3(-0.08, 0, -0.1))
            swings.append(sign(&b, &rig, at: Vec3(0.04, 0, 0.0)))
            tether(&b, at: Vec3(0.14, 0, -0.02), coat: Palette.horseBay)
            trough(&b, at: Vec3(0.15, 0, 0.08))
            signpost(&b, at: Vec3(-0.2, 0, 0.14))
        case 2:
            inn(&b, at: Vec3(-0.09, 0, -0.12), stone: false, width: 0.22)
            swings.append(sign(&b, &rig, at: Vec3(0.04, 0, 0.0)))
            stables(&b, at: Vec3(0.18, 0, -0.08), bays: 2)
            rick(&b, at: Vec3(0.22, 0, 0.08))
            trough(&b, at: Vec3(0.07, 0, 0.08))
            signpost(&b, at: Vec3(-0.2, 0, 0.14))
        case 3:
            inn(&b, at: Vec3(-0.08, 0, -0.12), stone: true, width: 0.24)
            swings.append(sign(&b, &rig, at: Vec3(0.06, 0, 0.0)))
            stables(&b, at: Vec3(0.2, 0, -0.08), bays: 2)
            wheels.append(cote(&b, &rig, at: Vec3(-0.21, 0, 0.07)))
            trough(&b, at: Vec3(0.12, 0, 0.08))
            rick(&b, at: Vec3(0.23, 0, 0.1))
            signpost(&b, at: Vec3(-0.08, 0, 0.18))
        case 4:
            inn(&b, at: Vec3(-0.08, 0, -0.12), stone: true, width: 0.24)
            swings.append(sign(&b, &rig, at: Vec3(0.06, 0, 0.0)))
            stables(&b, at: Vec3(0.2, 0, -0.08), bays: 2)
            wheels.append(cote(&b, &rig, at: Vec3(-0.22, 0, 0.06)))
            gate(&b, at: Vec3(0.0, 0, 0.22))
            coach(&b, at: Vec3(0.16, 0, 0.08), turn: 0.3)
            trough(&b, at: Vec3(-0.09, 0, 0.09))
            tether(&b, at: Vec3(0.05, 0, 0.04), coat: Palette.horseGrey)
        default:
            inn(&b, at: Vec3(-0.1, 0, -0.12), stone: true, width: 0.24)
            swings.append(sign(&b, &rig, at: Vec3(0.04, 0, 0.0)))
            stables(&b, at: Vec3(0.17, 0, -0.06), bays: 3)
            wheels.append(cote(&b, &rig, at: Vec3(-0.23, 0, 0.06)))
            gate(&b, at: Vec3(0.0, 0, 0.22))
            coach(&b, at: Vec3(0.12, 0, 0.1), turn: 0.3)
            coach(&b, at: Vec3(-0.12, 0, 0.13), turn: -0.2)
            waymark(&b, at: Vec3(0.2, 0, 0.18))
            for (index, x) in [Float(0.2), 0.235].enumerated() {
                horse(&b, at: Vec3(x, 0, 0.06 + Float(index) * 0.018), turn: .pi + 0.3, coat: index == 0 ? Palette.horseGrey : Palette.horseBay)
            }
            tether(&b, at: Vec3(-0.02, 0, 0.03), coat: Palette.horseDun)
            trough(&b, at: Vec3(-0.2, 0, -0.01))
            signpost(&b, at: Vec3(-0.19, 0, 0.2))
            rick(&b, at: Vec3(-0.24, 0, 0.08))
        }
        let machinery = Machinery(wheels: wheels, swings: swings, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// The road past the front, rutted, cobbled from the third level.
    static func road(_ b: inout MeshBuilder, level: Int) {
        b.box(center: Vec3(0, 0.003, 0.2), size: Vec3(0.4, 0.006, 0.08), color: level >= 3 ? Palette.stone : Palette.loam)
        b.fine {
            for z in [Float(0.185), 0.215] {
                $0.box(center: Vec3(0, 0.0065, z), size: Vec3(0.38, 0.001, 0.008), color: Palette.earth)
            }
            if level >= 3 {
                for index in 0..<10 {
                    let x = -0.18 + Float(index) * 0.04
                    $0.box(center: Vec3(x, 0.007, 0.2 + (index % 2 == 0 ? -0.02 : 0.02)), size: Vec3(0.026, 0.002, 0.02), color: Palette.stonePale)
                }
            }
        }
    }

    /// A thatched waystation: low timber walls, a door and a lit window.
    static func waystation(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.18, depth: 0.12, height: 0.09, wall: Palette.timber, roof: Palette.thatch, pitch: 0.75)
        b.door(at + Vec3(0.02, 0.04, 0.062), width: 0.032, height: 0.07, facing: 0)
        b.window(at + Vec3(-0.05, 0.055, 0.062), width: 0.022, height: 0.024, facing: 0)
        b.place(.translation(at + Vec3(-0.07, 0, -0.02))) {
            $0.prism(sides: 4, radius: 0.016, to: 0.17, color: Palette.stoneDark)
        }
    }

    /// The inn: timber or pale stone, two storeys from the third level,
    /// its door, lit windows above and below, and a chimney.
    static func inn(_ b: inout MeshBuilder, at: Vec3, stone: Bool, width: Float) {
        let depth: Float = 0.13, height: Float = stone ? 0.16 : 0.11
        b.hall(at: at, width: width, depth: depth, height: height, wall: stone ? Palette.stonePale : Palette.timber,
               roof: Palette.slate, pitch: 0.7, footing: Palette.stone)
        b.door(at + Vec3(0.03, 0.045, depth / 2 + 0.002), width: 0.038, height: 0.08, facing: 0)
        for x in [Float(-0.07), -0.025] {
            b.window(at + Vec3(x, 0.055, depth / 2 + 0.002), width: 0.022, height: 0.026, facing: 0)
        }
        if stone {
            for x in [Float(-0.07), 0.0, 0.07] {
                b.window(at + Vec3(x, 0.12, depth / 2 + 0.002), width: 0.02, height: 0.024, facing: 0)
            }
            b.fine {
                $0.box(center: at + Vec3(0, 0.092, depth / 2 + 0.004), size: Vec3(width, 0.008, 0.006), color: Palette.stoneWhite)
            }
        } else {
            b.fine {
                for x in stride(from: -width / 2 + 0.01, through: width / 2, by: 0.055) {
                    $0.beam(from: at + Vec3(x, 0, depth / 2 + 0.003), to: at + Vec3(x, height, depth / 2 + 0.003), width: 0.006,
                            color: Palette.timberDark)
                }
            }
        }
        let flue = at + Vec3(-width / 2 + 0.03, 0, -0.02)
        b.box(min: flue + Vec3(-0.018, 0, -0.018), max: flue + Vec3(0.018, height + 0.11, 0.018), color: Palette.stoneDark)
    }

    /// The inn's sign hung from a bracket on its post; returns its swing.
    static func sign(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.limb(from: at, to: at + Vec3(0, 0.17, 0), radius: 0.006, color: Palette.timberDark)
        b.beam(from: at + Vec3(0, 0.16, 0), to: at + Vec3(0.06, 0.16, 0), width: 0.006, color: Palette.timberDark)
        b.beam(from: at + Vec3(0, 0.12, 0), to: at + Vec3(0.04, 0.16, 0), width: 0.004, color: Palette.timberDark)
        let hinge = at + Vec3(0.045, 0.156, 0)
        let board = rig.add("inn sign", pivot: hinge)
        b.with(part: board) {
            for dx in [Float(-0.012), 0.012] {
                $0.limb(from: hinge + Vec3(dx, 0, 0), to: hinge + Vec3(dx, -0.012, 0), radius: 0.0015, sides: 3, color: Palette.iron)
            }
            $0.box(center: hinge + Vec3(0, -0.035, 0), size: Vec3(0.045, 0.04, 0.005), color: Palette.weld)
            $0.box(center: hinge + Vec3(0, -0.035, 0), size: Vec3(0.022, 0.022, 0.007), color: Palette.horseDun)
        }
        return .init(part: board, axis: Vec3(1, 0, 0), angle: 0.22)
    }

    /// A horse tethered at its post.
    static func tether(_ b: inout MeshBuilder, at: Vec3, coat: Vec3) {
        b.limb(from: at + Vec3(-0.05, 0, 0), to: at + Vec3(-0.05, 0.07, 0), radius: 0.005, color: Palette.timberDark)
        horse(&b, at: at, turn: 0, coat: coat)
        b.limb(from: at + Vec3(-0.05, 0.06, 0), to: at + Vec3(-0.03, 0.065, 0), radius: 0.0015, sides: 3, color: Palette.leather)
    }

    /// A horse standing, head down a little.
    static func horse(_ b: inout MeshBuilder, at: Vec3, turn: Float, coat: Vec3) {
        b.place(.translation(at) * .rotationY(turn)) {
            $0.limb(from: Vec3(-0.025, 0.05, 0), to: Vec3(0.025, 0.05, 0), radius: 0.014, color: coat)
            for (x, z) in [(Float(-0.02), Float(-0.008)), (-0.02, 0.008), (0.02, -0.008), (0.02, 0.008)] {
                $0.limb(from: Vec3(x, 0.045, z), to: Vec3(x, 0, z), radius: 0.004, color: coat)
            }
            $0.limb(from: Vec3(-0.025, 0.055, 0), to: Vec3(-0.04, 0.075, 0), radius: 0.008, topRadius: 0.006, color: coat)
            $0.limb(from: Vec3(-0.04, 0.075, 0), to: Vec3(-0.055, 0.065, 0), radius: 0.006, topRadius: 0.004, color: coat)
            $0.limb(from: Vec3(0.028, 0.055, 0), to: Vec3(0.034, 0.025, 0), radius: 0.003, color: Palette.hair)
            $0.box(center: Vec3(0, 0.066, 0), size: Vec3(0.02, 0.004, 0.03), color: Palette.leatherDark)
        }
    }

    /// A trough of timber, water in it.
    static func trough(_ b: inout MeshBuilder, at: Vec3) {
        b.box(min: at + Vec3(-0.045, 0, -0.016), max: at + Vec3(0.045, 0.03, 0.016), color: Palette.timberDark)
        b.box(min: at + Vec3(-0.04, 0.024, -0.011), max: at + Vec3(0.04, 0.028, 0.011), color: Palette.slate)
        b.fine {
            $0.place(.translation(at + Vec3(0.06, 0, 0))) {
                $0.lathe([(0.012, 0), (0.014, 0.022), (0.013, 0.022)], sides: 6, color: Palette.timber)
            }
        }
    }

    /// A signpost at the road, its arms pointing two ways.
    static func signpost(_ b: inout MeshBuilder, at: Vec3) {
        b.limb(from: at, to: at + Vec3(0, 0.15, 0), radius: 0.005, color: Palette.timberDark)
        for (y, turn) in [(Float(0.135), Float(0.5)), (0.11, -0.7)] {
            b.box(center: at + Vec3(0, y, 0), size: Vec3(0.07, 0.015, 0.005), turn: turn, color: Palette.timberPale)
        }
    }

    /// A stable range under a lean-to slate roof: its bays, half-doors and
    /// a horse looking out of each.
    static func stables(_ b: inout MeshBuilder, at: Vec3, bays: Int) {
        let span: Float = 0.075, width = Float(bays) * span
        let left = at.x - width / 2
        b.box(min: Vec3(left, 0, at.z - 0.06), max: Vec3(left + width, 0.1, at.z - 0.05), color: Palette.timberDark)
        b.quad(Vec3(left - 0.01, 0.09, at.z + 0.05), Vec3(left + width + 0.01, 0.09, at.z + 0.05),
               Vec3(left + width + 0.01, 0.115, at.z - 0.065), Vec3(left - 0.01, 0.115, at.z - 0.065), color: Palette.slate)
        b.quad(Vec3(left - 0.01, 0.105, at.z - 0.065), Vec3(left + width + 0.01, 0.105, at.z - 0.065),
               Vec3(left + width + 0.01, 0.08, at.z + 0.05), Vec3(left - 0.01, 0.08, at.z + 0.05), color: Palette.timberDark)
        let coats = [Palette.horseBay, Palette.horseGrey, Palette.horseBlack]
        for bay in 0...bays {
            let x = left + Float(bay) * span
            b.limb(from: Vec3(x, 0, at.z + 0.045), to: Vec3(x, 0.09, at.z + 0.045), radius: 0.005, color: Palette.timberDark)
            b.box(min: Vec3(x, 0, at.z - 0.05), max: Vec3(x + 0.004, 0.09, at.z + 0.04), color: Palette.timber)
            guard bay < bays else { continue }
            let mid = x + span / 2
            b.box(min: Vec3(mid - 0.03, 0, at.z + 0.036), max: Vec3(mid + 0.03, 0.045, at.z + 0.042), color: Palette.timber)
            b.place(.translation(Vec3(mid, 0.05, at.z + 0.02))) {
                $0.limb(from: .zero, to: Vec3(0, 0.02, 0.035), radius: 0.01, topRadius: 0.007, color: coats[bay % coats.count])
            }
        }
        b.fine {
            for bay in 0..<bays {
                let mid = left + Float(bay) * span + span / 2
                $0.box(center: Vec3(mid, 0.03, at.z + 0.044), size: Vec3(0.05, 0.004, 0.003), color: Palette.timberDark)
                $0.with(material: .metal) {
                    $0.box(center: Vec3(mid + 0.024, 0.024, at.z + 0.045), size: Vec3(0.004, 0.012, 0.003), color: Palette.iron)
                }
            }
        }
    }

    /// A rick of hay under its thatch cap.
    static func rick(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.lathe([(0.038, 0), (0.042, 0.04), (0.032, 0.07), (0.0, 0.09)], sides: 8, color: Palette.straw)
            $0.lathe([(0.034, 0.066), (0.0, 0.095)], sides: 8, color: Palette.thatch)
        }
        b.fine {
            $0.beam(from: at + Vec3(0.045, 0, 0.0), to: at + Vec3(0.02, 0.08, 0.02), width: 0.004, color: Palette.timberPale)
        }
    }

    /// The round cote for the post-birds, its rows of holes, a vane turning
    /// on its cap; returns the vane.
    static func cote(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        b.roundHouse(at: at, radius: 0.045, height: 0.17, wall: Palette.stonePale, roof: Palette.slate)
        b.place(.translation(at)) {
            for row in 0..<2 {
                for angle in [Float(0.3), 1.2, 2.1, 3.0] {
                    $0.window(onRound: 0.046, y: 0.11 + Float(row) * 0.03, angle: angle, width: 0.012, height: 0.012,
                              color: Palette.timberDark)
                }
            }
        }
        let top = at + Vec3(0, 0.25, 0)
        b.limb(from: top - Vec3(0, 0.03, 0), to: top + Vec3(0, 0.02, 0), radius: 0.002, color: Palette.iron)
        let vane = rig.add("post vane", pivot: top)
        b.with(part: vane, material: .metal) {
            $0.box(center: top + Vec3(0.008, 0.02, 0), size: Vec3(0.04, 0.003, 0.002), color: Palette.iron)
            $0.box(center: top + Vec3(-0.01, 0.026, 0), size: Vec3(0.014, 0.012, 0.002), color: Palette.gold)
        }
        b.fine {
            for (index, angle) in [Float(0.4), 1.6, 2.6].enumerated() {
                let foot = at + MeshBuilder.ring(0.07, 0, angle)
                $0.sphere(center: foot + Vec3(0, 0.008, 0), radius: 0.007, rings: 2, sides: 5, color: index == 1 ? Palette.wool : Palette.ash,
                          squash: 0.8)
            }
        }
        return .init(part: vane, axis: Vec3(0, 1, 0), turns: 1)
    }

    /// A gate over the road, a lantern lit beneath its beam.
    static func gate(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.08), 0.08] {
            b.box(center: at + Vec3(x, 0.09, 0), size: Vec3(0.026, 0.18, 0.026), color: Palette.stone)
            b.box(center: at + Vec3(x, 0.185, 0), size: Vec3(0.034, 0.012, 0.034), color: Palette.stonePale)
        }
        b.beam(from: at + Vec3(-0.095, 0.17, 0), to: at + Vec3(0.095, 0.17, 0), width: 0.018, color: Palette.timberDark)
        b.gableRoof(width: 0.2, depth: 0.04, base: 0.18, height: 0.03, color: Palette.slate, overhang: 0.005)
        b.limb(from: at + Vec3(0, 0.16, 0), to: at + Vec3(0, 0.135, 0), radius: 0.002, color: Palette.iron)
        b.with(material: .glow) {
            $0.box(center: at + Vec3(0, 0.124, 0), size: Vec3(0.016, 0.022, 0.016), color: Palette.candle)
        }
    }

    /// A post-coach: its body on four wheels, its pole down, luggage on its roof.
    static func coach(_ b: inout MeshBuilder, at: Vec3, turn: Float) {
        b.place(.translation(at) * .rotationY(turn)) {
            $0.box(min: Vec3(-0.04, 0.03, -0.024), max: Vec3(0.04, 0.08, 0.024), color: Palette.madder)
            $0.box(min: Vec3(-0.043, 0.078, -0.027), max: Vec3(0.043, 0.084, 0.027), color: Palette.timberDark)
            $0.box(center: Vec3(0, 0.055, 0.0245), size: Vec3(0.02, 0.026, 0.002), color: Palette.candle)
            for (x, r) in [(Float(-0.028), Float(0.022)), (0.03, 0.017)] {
                for z in [Float(-0.03), 0.03] {
                    $0.wheel(center: Vec3(x, r, z), radius: r, width: 0.005, spokes: 4, color: Palette.timber, rim: Palette.timberDark)
                }
            }
            $0.beam(from: Vec3(0.045, 0.02, 0), to: Vec3(0.11, 0.004, 0), width: 0.005, color: Palette.timberDark)
            $0.box(center: Vec3(0.0, 0.094, 0), size: Vec3(0.04, 0.016, 0.03), color: Palette.leather)
        }
    }

    /// The waymark: a pillar of pale stone, a moonsalt lamp burning on it.
    static func waymark(_ b: inout MeshBuilder, at: Vec3) {
        b.box(center: at + Vec3(0, 0.01, 0), size: Vec3(0.05, 0.02, 0.05), color: Palette.stone)
        b.place(.translation(at + Vec3(0, 0.02, 0))) {
            $0.prism(sides: 4, radius: 0.02, topRadius: 0.015, to: 0.2, color: Palette.stoneWhite)
        }
        b.with(material: .crystal) {
            $0.place(.translation(at + Vec3(0, 0.22, 0))) {
                $0.lathe([(0.0, 0.0), (0.018, 0.03), (0.0, 0.065)], sides: 6, color: Palette.moonsalt)
            }
        }
    }
}
