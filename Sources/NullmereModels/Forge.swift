import Foundation
import NullmereCore

/// The Forge, modelled whole at each level, where the House's smiths work
/// its makings into gear; it faces +z, within a work's slot, its chimney
/// always where `Works.forgeChimney` says smoke rises.
///
/// 1. A bloomery of clay smoking in a ring of stones, a smith's anvil on its
///    stump under a thatched lean-to, bellows heaving, charcoal heaped.
/// 2. A timber smithy with a stone chimney, its hearth glowing through the
///    open front, a quench barrel, a hitching rail with shoes hung on it.
/// 3. A smithy of dark stone, a trip hammer beating at the anvil, the
///    bloomery rebuilt in stone, a rack of blades by the door.
/// 4. An armourer's shop beside it, a stand of mail, a grindstone turning,
///    bar iron stacked in the yard.
/// 5. A great forge hall under a tall chimney flying the House's banner,
///    a furnace of moonglass burning cold and bright before it.
enum Forge {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.stoneDark, sides: 12)
        b.fine { cinders(&$0) }
        let flue = Works.forgeChimney(level)
        var wheels: [Machinery.Wheel] = []
        var swings: [Machinery.Swing] = []
        var flames: [UInt16] = []
        if level >= 2 { Lodge.boundary(&b, courses: min(level - 1, 3)) }
        if level >= 3 { oreCart(&b, at: Vec3(level == 3 ? -0.08 : 0.18, 0, level == 3 ? 0.22 : 0.0)) }
        if level >= 4 { Beacon.woodpile(&b, at: Vec3(-0.26, 0, -0.02)) }
        switch level {
        case 1:
            flames.append(bloomery(&b, &rig, at: Vec3(flue.x, 0, flue.z), height: flue.y, stone: false))
            leanTo(&b, at: Vec3(0.09, 0, 0.02), roof: Palette.thatch)
            anvil(&b, at: Vec3(0.09, 0, 0.04))
            swings.append(bellows(&b, &rig, at: Vec3(-0.21, 0, 0.0)))
            charcoal(&b, at: Vec3(0.2, 0, 0.17))
            bars(&b, at: Vec3(-0.06, 0, 0.18), count: 4)
        case 2:
            flames.append(smithy(&b, &rig, flue: flue, stone: false, width: 0.3))
            anvil(&b, at: Vec3(0.02, 0, 0.1))
            barrel(&b, at: Vec3(0.12, 0, 0.08))
            rail(&b, at: Vec3(0.12, 0, 0.21))
            swings.append(bellows(&b, &rig, at: Vec3(-0.22, 0, 0.06)))
            charcoal(&b, at: Vec3(-0.17, 0, 0.19))
        case 3:
            flames.append(smithy(&b, &rig, flue: flue, stone: true, width: 0.3))
            swings.append(tripHammer(&b, &rig, at: Vec3(0.05, 0, 0.1)))
            flames.append(bloomery(&b, &rig, at: Vec3(-0.2, 0, 0.14), height: 0.16, stone: true))
            blades(&b, at: Vec3(0.21, 0, -0.03))
            barrel(&b, at: Vec3(0.19, 0, 0.13))
            rail(&b, at: Vec3(0.02, 0, 0.24))
        case 4:
            flames.append(smithy(&b, &rig, flue: flue, stone: true, width: 0.24))
            armoury(&b, at: Vec3(0.17, 0, -0.1))
            swings.append(tripHammer(&b, &rig, at: Vec3(-0.06, 0, 0.1)))
            flames.append(bloomery(&b, &rig, at: Vec3(-0.18, 0, 0.12), height: 0.16, stone: true))
            wheels.append(grindstone(&b, &rig, at: Vec3(0.15, 0, 0.11)))
            mail(&b, at: Vec3(0.24, 0, 0.06))
            bars(&b, at: Vec3(0.06, 0, 0.22), count: 6)
        default:
            flames.append(greatHall(&b, &rig, flue: flue))
            armoury(&b, at: Vec3(0.18, 0, -0.1))
            swings.append(tripHammer(&b, &rig, at: Vec3(-0.08, 0, 0.11)))
            wheels.append(grindstone(&b, &rig, at: Vec3(0.16, 0, 0.12)))
            furnace(&b, at: Vec3(0.04, 0, 0.2))
            barrel(&b, at: Vec3(0.1, 0, 0.24))
            charcoal(&b, at: Vec3(-0.06, 0, 0.25))
            mail(&b, at: Vec3(0.25, 0, 0.07))
            bars(&b, at: Vec3(-0.2, 0, 0.2), count: 6)
            b.limb(from: flue + Vec3(0.04, -0.1, 0), to: flue + Vec3(0.04, 0.1, 0), radius: 0.005, color: Palette.timberDark)
            b.flag(at: flue + Vec3(0.04, 0.095, 0), width: 0.1, height: 0.07, tail: true)
        }
        let machinery = Machinery(wheels: wheels, swings: swings, flames: flames, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// Cinders and slag trodden into the yard.
    static func cinders(_ b: inout MeshBuilder) {
        for index in 0..<9 {
            let angle = Float(index) * 2.4
            let at = MeshBuilder.ring(0.12 + 0.015 * Float(index % 4), 0, angle)
            b.rock(center: at, size: Vec3(0.012, 0.005, 0.01), rings: 2, sides: 4, jitter: 0.35, seed: UInt32(300 + index),
                   color: index % 3 == 0 ? Palette.slate : Palette.barkBlack)
        }
    }

    /// A bloomery: a shaft of clay (or coursed stone) in a ring of stones,
    /// its mouth glowing; returns the glowing part.
    static func bloomery(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3, height: Float, stone: Bool) -> UInt16 {
        let clay = stone ? Palette.stoneDark : Palette.earth
        b.place(.translation(at)) {
            $0.lathe([(0.05, 0), (0.052, 0.04), (0.042, height * 0.5), (0.03, height * 0.9), (0.032, height), (0.024, height)],
                     sides: 9, color: clay)
        }
        for index in 0..<8 {
            let foot = at + MeshBuilder.ring(0.065, 0, Float(index) * .pi / 4)
            b.rock(center: foot, size: Vec3(0.018, 0.014, 0.016), rings: 2, sides: 5, jitter: 0.3, seed: UInt32(320 + index),
                   color: Palette.stone)
        }
        if stone {
            b.fine {
                for y in stride(from: Float(0.04), to: height - 0.01, by: 0.035) {
                    let r: Float = 0.052 - 0.02 * (y / height)
                    $0.place(.translation(at)) {
                        $0.tube([(r + 0.002, y), (r + 0.003, y + 0.006)], sides: 9, color: Palette.stone)
                    }
                }
            }
        }
        let glow = rig.add("bloom \(rig.count)", pivot: at + Vec3(0, 0.03, 0.05))
        b.with(part: glow, material: .glow) {
            $0.box(center: at + Vec3(0, 0.03, 0.048), size: Vec3(0.03, 0.026, 0.01), color: Palette.fire)
            $0.place(.translation(at + Vec3(0, height, 0))) {
                $0.cone(sides: 6, radius: 0.02, from: 0, to: 0.02, color: Palette.fire)
            }
        }
        return glow
    }

    /// A lean-to on four posts, its roof falling toward the yard.
    static func leanTo(_ b: inout MeshBuilder, at: Vec3, roof: Vec3) {
        let high: Float = 0.17, low: Float = 0.12
        for (x, z) in [(Float(-0.09), Float(-0.08)), (0.09, -0.08), (-0.09, 0.08), (0.09, 0.08)] {
            b.limb(from: at + Vec3(x, 0, z), to: at + Vec3(x, z < 0 ? high : low, z), radius: 0.007, color: Palette.timberDark)
        }
        b.quad(at + Vec3(-0.11, low, 0.1), at + Vec3(0.11, low, 0.1), at + Vec3(0.11, high, -0.1), at + Vec3(-0.11, high, -0.1),
               color: roof)
        b.quad(at + Vec3(-0.11, high - 0.01, -0.1), at + Vec3(0.11, high - 0.01, -0.1), at + Vec3(0.11, low - 0.01, 0.1),
               at + Vec3(-0.11, low - 0.01, 0.1), color: Palette.timberDark)
        b.fine {
            for x in stride(from: Float(-0.1), through: 0.1, by: 0.04) {
                $0.beam(from: at + Vec3(x, low + 0.003, 0.1), to: at + Vec3(x, high + 0.003, -0.1), width: 0.006, color: Palette.straw)
            }
        }
    }

    /// An anvil on its stump, a hammer and tongs laid by it.
    static func anvil(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.lathe([(0.028, 0), (0.03, 0.045), (0.026, 0.05)], sides: 8, color: Palette.timberDark)
        }
        b.with(material: .metal) {
            $0.box(center: at + Vec3(0, 0.058, 0), size: Vec3(0.022, 0.016, 0.02), color: Palette.iron)
            $0.box(center: at + Vec3(0, 0.072, 0), size: Vec3(0.064, 0.014, 0.028), color: Palette.iron)
            $0.place(.translation(at + Vec3(-0.032, 0.074, 0)) * .rotationZ(.pi / 2)) {
                $0.cone(sides: 4, radius: 0.01, to: 0.028, color: Palette.iron)
            }
        }
        b.fine {
            $0.with(material: .metal) {
                $0.box(center: at + Vec3(0.012, 0.082, 0.004), size: Vec3(0.012, 0.008, 0.008), color: Palette.steel)
                $0.beam(from: at + Vec3(0.032, 0, 0.03), to: at + Vec3(0.026, 0.05, 0.02), width: 0.003, color: Palette.iron)
                $0.beam(from: at + Vec3(0.038, 0, 0.026), to: at + Vec3(0.026, 0.05, 0.02), width: 0.003, color: Palette.iron)
            }
            $0.beam(from: at + Vec3(0.012, 0.082, 0.004), to: at + Vec3(0.012, 0.082, 0.04), width: 0.004, color: Palette.timber)
        }
    }

    /// Bellows on a frame, the smith's helper's lever above them; returns
    /// the lever's swing.
    static func bellows(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.box(center: at + Vec3(0, 0.02, 0), size: Vec3(0.06, 0.04, 0.05), color: Palette.timberDark)
        b.place(.translation(at + Vec3(0, 0.05, 0))) {
            $0.box(center: .zero, size: Vec3(0.07, 0.022, 0.06), color: Palette.leatherDark)
        }
        b.with(material: .metal) {
            $0.place(.translation(at + Vec3(0.035, 0.05, 0)) * .rotationZ(-.pi / 2)) {
                $0.cone(sides: 4, radius: 0.008, to: 0.04, color: Palette.iron)
            }
        }
        b.limb(from: at + Vec3(-0.04, 0, 0), to: at + Vec3(-0.04, 0.12, 0), radius: 0.005, color: Palette.timberDark)
        let pivot = at + Vec3(-0.04, 0.12, 0)
        let lever = rig.add("bellows", pivot: pivot)
        b.with(part: lever) {
            $0.beam(from: pivot + Vec3(-0.03, 0, 0), to: pivot + Vec3(0.05, -0.04, 0), width: 0.006, color: Palette.timber)
            $0.limb(from: pivot + Vec3(0.04, -0.035, 0), to: at + Vec3(0.0, 0.062, 0), radius: 0.002, sides: 3, color: Palette.linen)
        }
        return .init(part: lever, axis: Vec3(0, 0, 1), angle: 0.25)
    }

    /// A smithy of timber or dark stone, its front open on the glowing
    /// hearth, its chimney at the flue; returns the hearth's glow.
    static func smithy(_ b: inout MeshBuilder, _ rig: inout Rig, flue: Vec3, stone: Bool, width: Float) -> UInt16 {
        let at = Vec3(flue.x + width / 2 - 0.04, 0, -0.13)
        let wall = stone ? Palette.stoneDark : Palette.timber
        b.hall(at: at, width: width, depth: 0.13, height: stone ? 0.14 : 0.12, wall: wall, roof: Palette.slate, pitch: 0.6,
               footing: stone ? Palette.stone : Palette.stoneDark)
        chimney(&b, flue: flue, stone: stone)
        // The open front: a dark mouth over the hearth.
        b.box(center: Vec3(flue.x, 0.05, at.z + 0.066), size: Vec3(0.08, 0.08, 0.004), color: Palette.barkBlack)
        b.door(at + Vec3(width / 2 - 0.05, 0.045, 0.066), width: 0.035, height: 0.075, facing: 0)
        b.window(at + Vec3(0.0, 0.08, 0.066), width: 0.022, height: 0.028, facing: 0)
        let glow = rig.add("hearth", pivot: Vec3(flue.x, 0.04, at.z + 0.06))
        b.with(part: glow, material: .glow) {
            $0.box(center: Vec3(flue.x, 0.035, at.z + 0.07), size: Vec3(0.06, 0.02, 0.008), color: Palette.fire)
        }
        b.fine {
            $0.box(center: Vec3(flue.x, 0.095, at.z + 0.07), size: Vec3(0.1, 0.012, 0.012), color: stone ? Palette.stonePale : Palette.timberDark)
            if !stone {
                for x in stride(from: at.x - width / 2 + 0.02, to: at.x + width / 2, by: 0.05) {
                    $0.beam(from: Vec3(x, 0, at.z + 0.067), to: Vec3(x, 0.12, at.z + 0.067), width: 0.006, color: Palette.timberDark)
                }
            }
        }
        return glow
    }

    /// A chimney stack up to the flue, coursed and sooted.
    static func chimney(_ b: inout MeshBuilder, flue: Vec3, stone: Bool) {
        b.box(min: Vec3(flue.x - 0.032, 0, flue.z - 0.032), max: Vec3(flue.x + 0.032, flue.y, flue.z + 0.032), color: Palette.stoneDark)
        b.fine {
            for y in stride(from: Float(0.16), to: flue.y - 0.01, by: 0.07) {
                $0.box(min: Vec3(flue.x - 0.035, y, flue.z - 0.035), max: Vec3(flue.x + 0.035, y + 0.012, flue.z + 0.035),
                       color: Palette.stonePale)
            }
            $0.box(center: flue + Vec3(0, 0.002, 0), size: Vec3(0.044, 0.002, 0.044), color: Palette.barkBlack)
        }
    }

    /// A trip hammer: a beam on its post beating an anvil; returns its swing.
    static func tripHammer(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        anvil(&b, at: at)
        let pivot = at + Vec3(0.15, 0.13, 0)
        b.limb(from: at + Vec3(0.15, 0, 0), to: pivot, radius: 0.011, color: Palette.timber)
        b.limb(from: at + Vec3(0.13, 0, 0.03), to: pivot + Vec3(0, -0.02, 0), radius: 0.005, color: Palette.timberDark)
        let hammer = rig.add("hammer", pivot: pivot)
        b.with(part: hammer) {
            $0.beam(from: pivot + Vec3(0.03, 0.01, 0), to: at + Vec3(0, 0.125, 0), width: 0.015, color: Palette.timber)
            $0.with(material: .metal) {
                $0.box(center: at + Vec3(0, 0.108, 0), size: Vec3(0.03, 0.028, 0.028), color: Palette.iron)
                $0.box(center: pivot + Vec3(0, 0.0, 0), size: Vec3(0.014, 0.022, 0.03), color: Palette.iron)
            }
        }
        return .init(part: hammer, axis: Vec3(0, 0, -1), angle: 0.3)
    }

    /// A quench barrel, hooped.
    static func barrel(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.lathe([(0.024, 0), (0.028, 0.03), (0.024, 0.06), (0.02, 0.058)], sides: 8, color: Palette.timber)
        }
        b.fine {
            $0.with(material: .metal) {
                for y in [Float(0.008), 0.046] {
                    $0.place(.translation(at)) { $0.tube([(0.026, y), (0.0275, y + 0.006)], sides: 8, color: Palette.iron) }
                }
            }
        }
    }

    /// A hitching rail with horseshoes hung on it.
    static func rail(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.06), 0.06] {
            b.limb(from: at + Vec3(x, 0, 0), to: at + Vec3(x, 0.07, 0), radius: 0.005, color: Palette.timberDark)
        }
        b.beam(from: at + Vec3(-0.07, 0.066, 0), to: at + Vec3(0.07, 0.066, 0), width: 0.008, color: Palette.timber)
        b.fine {
            $0.with(material: .metal) {
                for x in [Float(-0.03), -0.005, 0.03] {
                    $0.box(center: at + Vec3(x - 0.005, 0.054, 0.006), size: Vec3(0.003, 0.016, 0.003), color: Palette.iron)
                    $0.box(center: at + Vec3(x + 0.005, 0.054, 0.006), size: Vec3(0.003, 0.016, 0.003), color: Palette.iron)
                    $0.box(center: at + Vec3(x, 0.046, 0.006), size: Vec3(0.013, 0.003, 0.003), color: Palette.iron)
                }
            }
        }
    }

    /// A heap of charcoal and its basket.
    static func charcoal(_ b: inout MeshBuilder, at: Vec3) {
        b.rock(center: at, size: Vec3(0.05, 0.03, 0.04), rings: 3, sides: 7, jitter: 0.3, seed: 341, color: Palette.barkBlack)
        b.place(.translation(at + Vec3(-0.05, 0, 0.02))) {
            $0.lathe([(0.016, 0), (0.022, 0.03), (0.0, 0.031)], sides: 7, color: Palette.thatch)
        }
    }

    /// Bar iron stacked crosswise.
    static func bars(_ b: inout MeshBuilder, at: Vec3, count: Int) {
        b.with(material: .metal) {
            for index in 0..<count {
                let layer = Float(index / 3), cross = index / 3 % 2 == 1
                let offset = Float(index % 3 - 1) * 0.014
                $0.box(center: at + Vec3(cross ? offset : 0, 0.004 + layer * 0.008, cross ? 0 : offset),
                       size: cross ? Vec3(0.007, 0.007, 0.07) : Vec3(0.07, 0.007, 0.007), color: index % 2 == 0 ? Palette.iron : Palette.mail)
            }
        }
    }

    /// A rack of blades.
    static func blades(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.045), 0.045] {
            b.limb(from: at + Vec3(x, 0, 0), to: at + Vec3(x, 0.11, 0), radius: 0.005, color: Palette.timberDark)
        }
        b.beam(from: at + Vec3(-0.05, 0.1, 0), to: at + Vec3(0.05, 0.1, 0), width: 0.008, color: Palette.timber)
        b.with(material: .metal) {
            for index in 0..<4 {
                let x = -0.03 + Float(index) * 0.02
                $0.box(center: at + Vec3(x, 0.055, 0.006), size: Vec3(0.006, 0.085, 0.003), color: Palette.steel)
                $0.box(center: at + Vec3(x, 0.092, 0.006), size: Vec3(0.016, 0.004, 0.005), color: Palette.gold)
            }
        }
    }

    /// An armourer's shop of stone, shields hung on its front.
    static func armoury(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.14, depth: 0.12, height: 0.12, wall: Palette.stone, roof: Palette.slate, pitch: 0.65,
               footing: Palette.stoneDark)
        b.door(at + Vec3(-0.03, 0.04, 0.062), width: 0.03, height: 0.07, facing: 0)
        for x in [Float(0.02), 0.05] {
            b.place(.translation(at + Vec3(x, 0.075, 0.064)) * .rotationX(.pi / 2)) {
                $0.lathe([(0.013, -0.002), (0.013, 0.002)], sides: 8, color: Palette.madder)
            }
            b.with(material: .metal) {
                $0.sphere(center: at + Vec3(x, 0.075, 0.068), radius: 0.004, rings: 2, sides: 4, color: Palette.iron, squash: 0.6)
            }
        }
    }

    /// A grindstone turning in its frame; returns its wheel.
    static func grindstone(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        let hub = at + Vec3(0, 0.06, 0)
        for z in [Float(-0.02), 0.02] {
            b.limb(from: at + Vec3(0, 0, z), to: hub + Vec3(0, 0, z), radius: 0.006, color: Palette.timberDark)
        }
        b.box(center: at + Vec3(0, 0.012, 0), size: Vec3(0.08, 0.024, 0.05), color: Palette.timber)
        let wheel = rig.add("grindstone", pivot: hub)
        b.with(part: wheel) {
            $0.wheel(center: hub, radius: 0.042, width: 0.018, spokes: 2, color: Palette.stone, rim: Palette.stonePale)
            $0.beam(from: hub + Vec3(0, 0, 0.022), to: hub + Vec3(0.03, 0, 0.03), width: 0.005, color: Palette.iron)
        }
        return .init(part: wheel, axis: Vec3(0, 0, 1), turns: 2)
    }

    /// A stand of mail with a helm on it.
    static func mail(_ b: inout MeshBuilder, at: Vec3) {
        b.limb(from: at, to: at + Vec3(0, 0.15, 0), radius: 0.005, color: Palette.timberDark)
        b.beam(from: at + Vec3(-0.03, 0.13, 0), to: at + Vec3(0.03, 0.13, 0), width: 0.006, color: Palette.timberDark)
        b.with(material: .metal) {
            $0.box(center: at + Vec3(0, 0.1, 0), size: Vec3(0.055, 0.065, 0.026), color: Palette.mail)
            $0.sphere(center: at + Vec3(0, 0.155, 0), radius: 0.016, rings: 3, sides: 6, color: Palette.steel, squash: 1.1)
        }
    }

    /// The great forge hall: a long hall of dark stone with buttresses,
    /// three glowing hearth mouths and the tall chimney; returns the glow.
    static func greatHall(_ b: inout MeshBuilder, _ rig: inout Rig, flue: Vec3) -> UInt16 {
        let at = Vec3(-0.06, 0, -0.13)
        b.hall(at: at, width: 0.3, depth: 0.14, height: 0.17, wall: Palette.stoneDark, roof: Palette.slate, pitch: 0.6,
               footing: Palette.stone)
        chimney(&b, flue: flue, stone: true)
        for x in [Float(-0.135), -0.045, 0.045, 0.135] {
            b.box(center: at + Vec3(x, 0.06, 0.076), size: Vec3(0.016, 0.12, 0.016), color: Palette.stone)
        }
        let glow = rig.add("hearth", pivot: at + Vec3(0, 0.04, 0.07))
        for x in [Float(-0.1), 0.0, 0.1] {
            b.box(center: at + Vec3(x, 0.05, 0.072), size: Vec3(0.06, 0.08, 0.004), color: Palette.barkBlack)
            b.with(part: glow, material: .glow) {
                $0.box(center: at + Vec3(x, 0.03, 0.076), size: Vec3(0.045, 0.018, 0.006), color: Palette.fire)
            }
        }
        b.fine {
            for x in [Float(-0.1), 0.0, 0.1] {
                $0.box(center: at + Vec3(x, 0.096, 0.077), size: Vec3(0.074, 0.012, 0.01), color: Palette.stonePale)
            }
            for x in stride(from: Float(-0.13), through: 0.08, by: 0.06) {
                $0.window(at + Vec3(x + 0.03, 0.14, 0.072), width: 0.014, height: 0.02, facing: 0)
            }
        }
        return glow
    }

    /// A furnace of moonglass burning cold and bright on a stone footing.
    static func furnace(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.lathe([(0.05, 0), (0.05, 0.02), (0.04, 0.025)], sides: 8, color: Palette.stone)
        }
        b.with(material: .crystal) {
            $0.place(.translation(at + Vec3(0, 0.025, 0))) {
                $0.lathe([(0.035, 0.0), (0.04, 0.05), (0.02, 0.1), (0.0, 0.12)], sides: 6, color: Palette.moonsalt)
            }
        }
    }

    /// A cart of ore brought up from the diggings, its shafts down.
    static func oreCart(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at) * .rotationY(0.5)) { cart in
            cart.box(min: Vec3(-0.045, 0.025, -0.03), max: Vec3(0.045, 0.06, 0.03), color: Palette.timberPale)
            for z in [Float(-0.034), 0.034] {
                cart.wheel(center: Vec3(0, 0.026, z), radius: 0.026, width: 0.006, spokes: 4, color: Palette.timber, rim: Palette.timberDark)
                cart.limb(from: Vec3(0.045, 0.04, z * 0.7), to: Vec3(0.11, 0.0, z * 0.6), radius: 0.003, sides: 3, color: Palette.timberDark)
            }
            for index in 0..<5 {
                let at = Vec3(Float(index % 3 - 1) * 0.026, 0.066, Float(index / 3) * 0.022 - 0.01)
                cart.rock(center: at, size: Vec3(0.02, 0.014, 0.018), rings: 2, sides: 5, jitter: 0.35, seed: UInt32(360 + index),
                          color: index % 2 == 0 ? Palette.rock : Palette.madder)
            }
        }
    }
}
