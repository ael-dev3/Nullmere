import Foundation
import NullmereCore

/// The Quarry, modelled whole at each level: a face of rock at the back of
/// its slot, cut down in benches that deepen and widen as it grows; it
/// faces +z, within a work's slot.
///
/// 1. A shallow cut into an outcrop, rough blocks levered out, a windlass
///    turning to drag them, a lean-to for the tools.
/// 2. Two benches cut, a shear-leg derrick swinging a block, rubble heaped.
/// 3. Three benches, a boom derrick on its mast, the stone-cutters' shed,
///    a block on rollers.
/// 4. Four benches, a treadwheel crane, a sledge track down the face and
///    dressed blocks stacked, a trough for the saws.
/// 5. A deep terraced pit, a great gantry over it, the quarry-master's
///    house of stone, the House's banners at the cart road.
///
/// What lifts the stone works: the windlass turns, the derricks and cranes
/// swing, the treadwheel is walked round.
enum Quarry {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.rock.mix(Palette.yard, 0.5), sides: 12)
        b.fine { spoil(&$0) }
        face(&b, benches: min(level, 4) + (level == 5 ? 1 : 0))
        // Rough blocks levered out and waiting, more as the cut deepens.
        blocks(&b, at: Vec3(0.19, 0, -0.02), rows: min(level, 3), dressed: false)
        rubble(&b, at: Vec3(-0.06, 0, 0.21))
        Lodge.limeTrough(&b, at: Vec3(0.08, 0, 0.25))
        var wheels: [Machinery.Wheel] = []
        var swings: [Machinery.Swing] = []
        switch level {
        case 1:
            wheels.append(windlass(&b, &rig, at: Vec3(0.12, 0, 0.1)))
            blocks(&b, at: Vec3(-0.12, 0, 0.12), rows: 1, dressed: false)
            leanTo(&b, at: Vec3(-0.2, 0, 0.0))
        case 2:
            swings.append(shearDerrick(&b, &rig, at: Vec3(0.04, 0, 0.04)))
            blocks(&b, at: Vec3(-0.14, 0, 0.14), rows: 2, dressed: false)
            rubble(&b, at: Vec3(0.18, 0, 0.14))
            leanTo(&b, at: Vec3(-0.21, 0, -0.02))
        case 3:
            swings.append(boomDerrick(&b, &rig, at: Vec3(0.0, 0, 0.06)))
            shed(&b, at: Vec3(-0.19, 0, 0.08))
            rollers(&b, at: Vec3(0.17, 0, 0.15))
            blocks(&b, at: Vec3(0.06, 0, 0.21), rows: 2, dressed: true)
        case 4:
            wheels.append(treadCrane(&b, &rig, at: Vec3(0.18, 0, 0.06), swing: &swings))
            shed(&b, at: Vec3(-0.19, 0, 0.08))
            sledgeTrack(&b)
            blocks(&b, at: Vec3(-0.02, 0, 0.21), rows: 3, dressed: true)
        default:
            swings.append(gantry(&b, &rig))
            masterHouse(&b, at: Vec3(-0.18, 0, 0.09))
            blocks(&b, at: Vec3(0.17, 0, 0.18), rows: 3, dressed: true)
            banners(&b)
        }
        let machinery = Machinery(wheels: wheels, swings: swings, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// The rock face at the back, cut in benches: each bench a step of
    /// stone, its lip ragged with rock; more and deeper as the quarry grows.
    static func face(_ b: inout MeshBuilder, benches: Int) {
        let back: Float = -0.19
        for bench in 0..<benches {
            let depth: Float = 0.04
            let z = back + Float(bench) * depth
            let h = 0.05 + Float(benches - bench) * 0.045
            let w = 0.4 - Float(bench) * 0.035
            b.box(min: Vec3(-w / 2, 0, z - depth), max: Vec3(w / 2, h, z), color: bench % 2 == 0 ? Palette.rock : Palette.stoneDark)
            for index in 0..<9 {
                let x = -w / 2 + w * (Float(index) + 0.5) / 9
                b.rock(center: Vec3(x, h + 0.008, z - depth * 0.5), size: Vec3(0.03, 0.016, 0.028), seed: UInt32(bench * 11 + index + 300),
                       color: index % 2 == 0 ? Palette.rock : Palette.stone)
            }
            b.fine { b in
                for index in 0..<4 {
                    let x = -w / 2 + w * (Float(index) + 0.3) / 4
                    b.box(center: Vec3(x, h * 0.5, z + 0.001), size: Vec3(0.003, h * 0.8, 0.002), color: Palette.stonePale)
                }
            }
        }
    }

    /// Blocks: rough ones as levered out, or dressed and stacked square.
    static func blocks(_ b: inout MeshBuilder, at: Vec3, rows: Int, dressed: Bool) {
        for row in 0..<rows {
            for index in 0..<(3 - min(row, 2)) {
                let p = at + Vec3(Float(index) * 0.034 + Float(row) * 0.017 - 0.034, 0.015 + Float(row) * 0.03, 0)
                if dressed {
                    b.box(center: p, size: Vec3(0.032, 0.028, 0.05), color: (index + row) % 2 == 0 ? Palette.stonePale : Palette.stone)
                } else {
                    b.rock(center: p, size: Vec3(0.032, 0.026, 0.04), seed: UInt32(row * 5 + index + 410), color: Palette.stone)
                }
            }
        }
    }

    /// Rubble heaped where it was thrown.
    static func rubble(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at)) {
            $0.cone(sides: 7, radius: 0.06, from: 0, to: 0.05, color: Palette.rock)
        }
        for index in 0..<5 {
            let angle = Float(index) * 1.4
            b.rock(center: at + Vec3(0.05 * Float(cos(Double(angle))), 0.01, 0.05 * Float(sin(Double(angle)))),
                   size: Vec3(0.016, 0.012, 0.014), seed: UInt32(index + 520), color: Palette.stoneDark)
        }
    }

    /// A lean-to of planks where the picks and bars are kept.
    static func leanTo(_ b: inout MeshBuilder, at: Vec3) {
        for z in [Float(-0.05), 0.05] {
            b.limb(from: at + Vec3(0.03, 0, z), to: at + Vec3(0.03, 0.1, z), radius: 0.006, color: Palette.timberDark)
        }
        b.place(.translation(at + Vec3(0, 0.1, 0)) * .rotationZ(0.35)) {
            $0.box(min: Vec3(-0.05, 0, -0.07), max: Vec3(0.05, 0.008, 0.07), color: Palette.timberGrey)
        }
        b.fine { b in
            for (index, z) in [Float(-0.03), -0.01, 0.01, 0.03].enumerated() {
                b.limb(from: at + Vec3(-0.01, 0, z), to: at + Vec3(0.02, 0.08, z), radius: 0.0025,
                       color: index % 2 == 0 ? Palette.timberPale : Palette.iron)
            }
        }
    }

    /// A windlass on its frame, turned to drag the blocks up the cut.
    static func windlass(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        for x in [Float(-0.04), 0.04] {
            b.box(center: at + Vec3(x, 0.04, 0), size: Vec3(0.01, 0.08, 0.04), color: Palette.timberDark)
        }
        let drum = rig.add("quarry windlass", pivot: at + Vec3(0, 0.07, 0))
        b.with(part: drum) { b in
            b.place(.translation(at + Vec3(0, 0.07, 0)) * .rotationZ(.pi / 2)) {
                $0.lathe([(0.014, -0.04), (0.014, 0.04)], sides: 7, color: Palette.timber)
            }
            for angle in [Float(0), .pi / 2, .pi, 3 * .pi / 2] {
                let spoke = Vec3(0, 0.035 * Float(cos(Double(angle))), 0.035 * Float(sin(Double(angle))))
                b.beam(from: at + Vec3(0.05, 0.07, 0), to: at + Vec3(0.05, 0.07, 0) + spoke, width: 0.005, color: Palette.timberPale)
            }
        }
        b.limb(from: at + Vec3(0, 0.07, -0.01), to: Vec3(at.x - 0.05, 0.02, -0.16), radius: 0.002, color: Palette.linen)
        return Machinery.Wheel(part: drum, axis: Vec3(1, 0, 0), turns: 1)
    }

    /// Shear legs over the cut, a block swinging on their tackle.
    static func shearDerrick(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        let head = at + Vec3(0, 0.28, -0.04)
        for x in [Float(-0.08), 0.08] {
            b.limb(from: at + Vec3(x, 0, 0.04), to: head, radius: 0.008, color: Palette.timberGrey)
        }
        b.limb(from: at + Vec3(0, 0, 0.16), to: head, radius: 0.0018, color: Palette.linen)
        let load = rig.add("quarry tackle", pivot: head)
        b.with(part: load) { b in
            b.limb(from: head, to: head + Vec3(0, -0.15, 0), radius: 0.002, color: Palette.linen)
            b.box(center: head + Vec3(0, -0.17, 0), size: Vec3(0.04, 0.03, 0.035), color: Palette.stonePale)
        }
        return Machinery.Swing(part: load, axis: Vec3(1, 0, 0), angle: 0.3)
    }

    /// A boom derrick: a mast guyed to the ground, its boom slewing round
    /// with a block on its fall.
    static func boomDerrick(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.limb(from: at, to: at + Vec3(0, 0.34, 0), radius: 0.009, color: Palette.timberDark)
        for angle in [Float(0.6), 2.6, 4.6] {
            let peg = at + Vec3(0.15 * Float(cos(Double(angle))), 0, 0.15 * Float(sin(Double(angle))))
            b.limb(from: at + Vec3(0, 0.34, 0), to: peg, radius: 0.0016, color: Palette.linen)
        }
        let boom = rig.add("quarry boom", pivot: at)
        b.with(part: boom) { b in
            b.beam(from: at + Vec3(0, 0.03, 0), to: at + Vec3(0.0, 0.26, -0.16), width: 0.009, color: Palette.timber)
            b.limb(from: at + Vec3(0, 0.26, -0.16), to: at + Vec3(0, 0.14, -0.16), radius: 0.002, color: Palette.linen)
            b.box(center: at + Vec3(0, 0.125, -0.16), size: Vec3(0.04, 0.028, 0.034), color: Palette.stonePale)
        }
        return Machinery.Swing(part: boom, axis: Vec3(0, 1, 0), angle: 0.8)
    }

    /// A treadwheel crane at the cut's edge, its jib slewing.
    static func treadCrane(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3, swing: inout [Machinery.Swing]) -> Machinery.Wheel {
        let hub = at + Vec3(0, 0.08, 0)
        for z in [Float(-0.03), 0.03] {
            b.beam(from: at + Vec3(-0.055, 0, z), to: hub + Vec3(0, 0, z), width: 0.008, color: Palette.timberDark)
            b.beam(from: at + Vec3(0.055, 0, z), to: hub + Vec3(0, 0, z), width: 0.008, color: Palette.timberDark)
        }
        let wheel = rig.add("quarry treadwheel", pivot: hub)
        b.with(part: wheel) {
            $0.wheel(center: hub, radius: 0.075, width: 0.05, spokes: 6, color: Palette.timber, rim: Palette.timberDark)
        }
        b.limb(from: at + Vec3(-0.04, 0, -0.04), to: at + Vec3(-0.04, 0.27, -0.04), radius: 0.008, color: Palette.timberDark)
        let jib = rig.add("quarry jib", pivot: at + Vec3(-0.04, 0.25, -0.04))
        b.with(part: jib) { b in
            b.beam(from: at + Vec3(-0.04, 0.25, -0.04), to: at + Vec3(-0.04, 0.27, -0.18), width: 0.008, color: Palette.timber)
            b.limb(from: at + Vec3(-0.04, 0.27, -0.175), to: at + Vec3(-0.04, 0.17, -0.175), radius: 0.002, color: Palette.linen)
            b.box(center: at + Vec3(-0.04, 0.155, -0.175), size: Vec3(0.034, 0.026, 0.03), color: Palette.stonePale)
        }
        swing.append(Machinery.Swing(part: jib, axis: Vec3(0, 1, 0), angle: 0.6))
        return Machinery.Wheel(part: wheel, axis: Vec3(0, 0, 1), turns: 1)
    }

    /// The great gantry of the fifth level: two A-frames and a beam over
    /// the pit, a trolley swinging its block along it.
    static func gantry(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery.Swing {
        for x in [Float(-0.2), 0.2] {
            for z in [Float(-0.2), 0.0] {
                b.limb(from: Vec3(x, 0, z), to: Vec3(x, 0.32, -0.1), radius: 0.009, color: Palette.timberDark)
            }
            b.beam(from: Vec3(x, 0.12, -0.17), to: Vec3(x, 0.12, -0.03), width: 0.006, color: Palette.timberDark)
        }
        b.beam(from: Vec3(-0.22, 0.32, -0.1), to: Vec3(0.22, 0.32, -0.1), width: 0.014, color: Palette.timber)
        let trolley = rig.add("quarry trolley", pivot: Vec3(0, 0.32, -0.1))
        b.with(part: trolley) { b in
            b.box(center: Vec3(0, 0.305, -0.1), size: Vec3(0.03, 0.02, 0.03), color: Palette.iron)
            b.limb(from: Vec3(0, 0.3, -0.1), to: Vec3(0, 0.16, -0.1), radius: 0.002, color: Palette.linen)
            b.box(center: Vec3(0, 0.14, -0.1), size: Vec3(0.05, 0.035, 0.04), color: Palette.stonePale)
        }
        b.fine { b in
            b.ladder(from: Vec3(0.2, 0, 0.01), to: Vec3(0.2, 0.31, -0.09), width: 0.025, rungs: 9, color: Palette.timberPale)
        }
        return Machinery.Swing(part: trolley, axis: Vec3(1, 0, 0), angle: 0.4)
    }

    /// The stone-cutters' shed: open-fronted under slate, a banker within.
    static func shed(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.11, depth: 0.1, height: 0.08, wall: Palette.timberGrey, roof: Palette.slate, pitch: 0.6, turn: .pi / 2)
        b.box(center: at + Vec3(0.055, 0.03, 0), size: Vec3(0.004, 0.06, 0.07), color: Palette.timberDark)
        Lodge.banker(&b, at: at + Vec3(0.09, 0, 0.0), block: true)
    }

    /// A block on rollers, levered along.
    static func rollers(_ b: inout MeshBuilder, at: Vec3) {
        for z in [Float(-0.025), 0.0, 0.025] {
            b.log(from: at + Vec3(-0.04, 0.008, z), to: at + Vec3(0.04, 0.008, z), radius: 0.007)
        }
        b.box(center: at + Vec3(0, 0.035, 0), size: Vec3(0.06, 0.04, 0.06), color: Palette.stonePale)
        b.limb(from: at + Vec3(0.03, 0.02, 0.04), to: at + Vec3(0.06, 0.09, 0.06), radius: 0.0025, color: Palette.iron)
    }

    /// The sledge track down the face: two timber rails and a sledge on it.
    static func sledgeTrack(_ b: inout MeshBuilder) {
        for x in [Float(-0.03), 0.03] {
            b.beam(from: Vec3(x - 0.06, 0.012, 0.1), to: Vec3(x - 0.06, 0.2, -0.2), width: 0.008, color: Palette.timberDark)
        }
        b.box(center: Vec3(-0.06, 0.06, 0.02), size: Vec3(0.07, 0.012, 0.06), color: Palette.timber)
        b.box(center: Vec3(-0.06, 0.08, 0.02), size: Vec3(0.05, 0.03, 0.04), color: Palette.stonePale)
        b.fine { b in
            b.box(min: Vec3(0.09, 0, 0.17), max: Vec3(0.15, 0.025, 0.21), color: Palette.timberDark)
            b.box(min: Vec3(0.093, 0.02, 0.173), max: Vec3(0.147, 0.024, 0.207), color: Palette.seaWool)
        }
    }

    /// The quarry-master's house of stone, slated, its door and window lit.
    static func masterHouse(_ b: inout MeshBuilder, at: Vec3) {
        b.hall(at: at, width: 0.12, depth: 0.1, height: 0.09, wall: Palette.stone, roof: Palette.slate, pitch: 0.7, turn: .pi / 2,
               footing: Palette.stoneDark)
        b.door(at + Vec3(0.051, 0.04, 0.02), width: 0.03, height: 0.06, facing: .pi / 2)
        b.window(at + Vec3(0.051, 0.06, -0.03), width: 0.018, height: 0.022, facing: .pi / 2)
        b.box(min: at + Vec3(-0.04, 0.08, -0.05), max: at + Vec3(-0.015, 0.16, -0.025), color: Palette.stoneDark)
    }

    /// The House's banners at the cart road.
    static func banners(_ b: inout MeshBuilder) {
        for x in [Float(-0.06), 0.06] {
            let foot = Vec3(x, 0, 0.27)
            b.limb(from: foot, to: foot + Vec3(0, 0.22, 0), radius: 0.005, color: Palette.timberDark)
            b.flag(at: foot + Vec3(0, 0.215, 0), width: 0.045, height: 0.09, turn: x > 0 ? .pi : 0, tail: true)
        }
    }

    /// Chips and spoil strewn over the floor of the cut.
    static func spoil(_ b: inout MeshBuilder) {
        for index in 0..<18 {
            let angle = Float(index) * 2.39996
            let r = 0.06 + 0.2 * Float((index * 23) % 11) / 11
            b.box(center: Vec3(r * Float(cos(Double(angle))), 0.013, r * Float(sin(Double(angle)))), size: Vec3(0.01, 0.006, 0.008),
                  turn: angle, color: index % 3 == 0 ? Palette.stonePale : Palette.rock)
        }
    }
}
