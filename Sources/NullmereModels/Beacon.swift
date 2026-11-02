import Foundation
import NullmereCore

/// The Beacon, modelled whole at each of its three levels: the hold's fire
/// on a height, lit to warn its House and its allies. It faces +z.
///
/// 1. A tower of four timber legs braced in two stages, a ladder to its
///    platform, an iron basket of fire on it, a woodpile and a horn hung
///    on a post at its foot.
/// 2. A taller tower on a footing of stone, its platform roofed in slate
///    over the fire, a gallery round it, and the beacon-keeper's hut at
///    its foot with its door and window lit.
/// 3. A round tower of stone with a stair round its outside, battlements,
///    and a great brazier on its crown under a ring of iron; the keeper's
///    house of stone below, the alarm bell on its frame.
///
/// Its fire leaps in the night.
enum Beacon {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.29, color: Palette.stoneDark, sides: 12)
        b.fine { scree(&$0) }
        let fire: UInt16
        switch level {
        case 1:
            fire = timberTower(&b, &rig, height: 0.3, footing: false, roofed: false)
            woodpile(&b, at: Vec3(0.17, 0, 0.13))
            horn(&b, at: Vec3(-0.17, 0, 0.14))
            cairn(&b, at: Vec3(-0.16, 0, -0.15))
        case 2:
            fire = timberTower(&b, &rig, height: 0.42, footing: true, roofed: true)
            woodpile(&b, at: Vec3(0.19, 0, 0.12))
            woodpile(&b, at: Vec3(0.16, 0, -0.17))
            hut(&b, at: Vec3(-0.18, 0, 0.1), stone: false)
            horn(&b, at: Vec3(0.02, 0, 0.23))
            Lodge.boundary(&b, courses: 1)
        default:
            fire = stoneTower(&b, &rig)
            hut(&b, at: Vec3(-0.19, 0, 0.1), stone: true)
            Works.beaconBell(&b, at: Vec3(0.18, 0, 0.13))
            woodpile(&b, at: Vec3(0.17, 0, -0.16))
            Lodge.boundary(&b, courses: 2)
            cairn(&b, at: Vec3(-0.05, 0, -0.22))
        }
        let machinery = Machinery(flames: [fire], parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// The fire itself, its own part to leap: tongues of flame over coals.
    static func flame(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3, size: Float) -> UInt16 {
        let part = rig.add("beacon fire", pivot: at)
        b.with(part: part) { b in
            b.with(material: .glow) { b in
                b.place(.translation(at)) {
                    $0.lathe([(size * 0.9, 0), (size, size * 0.3), (size * 0.6, size * 0.9), (size * 0.25, size * 1.5), (0, size * 2.1)],
                             sides: 7, color: Palette.fire)
                }
                for index in 0..<4 {
                    let angle = Float(index) * 1.6
                    let side = Vec3(size * 0.55 * Float(cos(Double(angle))), 0, size * 0.55 * Float(sin(Double(angle))))
                    b.place(.translation(at + side)) {
                        $0.cone(sides: 4, radius: size * 0.35, from: 0, to: size * 1.3, color: Palette.candle)
                    }
                }
            }
        }
        return part
    }

    /// An iron fire basket: a ring and its bars on a stem.
    static func basket(_ b: inout MeshBuilder, at: Vec3, radius: Float) {
        b.with(material: .metal) { b in
            b.place(.translation(at)) { b in
                b.lathe([(radius * 0.4, -0.02), (radius, 0.01), (radius * 1.05, 0.05)], sides: 8, color: Palette.iron)
                for index in 0..<8 {
                    let angle = Float(index) / 8 * 2 * .pi
                    let p = Vec3(radius * Float(cos(Double(angle))), 0, radius * Float(sin(Double(angle))))
                    b.limb(from: p * 0.95 + Vec3(0, 0.01, 0), to: p * 1.12 + Vec3(0, 0.075, 0), radius: 0.0035, color: Palette.iron)
                }
            }
        }
        b.place(.translation(at + Vec3(0, 0.015, 0))) {
            $0.lathe([(radius * 0.9, 0), (radius * 0.7, 0.02), (0, 0.025)], sides: 8, color: Palette.timberDark)
        }
    }

    /// A tower of four timber legs braced in stages, its platform and
    /// ladder, the fire basket on top; on stone and roofed at the second.
    static func timberTower(_ b: inout MeshBuilder, _ rig: inout Rig, height: Float, footing: Bool, roofed: Bool) -> UInt16 {
        let base: Float = 0.09, top: Float = 0.055
        if footing {
            b.box(center: Vec3(0, 0.025, 0), size: Vec3(0.24, 0.05, 0.24), color: Palette.stone)
            b.fine { b in
                for index in 0..<12 {
                    let x: Float = -0.11 + Float(index % 4) * 0.073
                    let z: Float = index < 4 ? -0.121 : 0.121
                    if index < 8 { b.box(center: Vec3(x, 0.025, z), size: Vec3(0.06, 0.042, 0.003), color: Palette.stonePale) }
                }
            }
        }
        let foot: Float = footing ? 0.05 : 0
        let corners: [(Float, Float)] = [(-1, -1), (1, -1), (1, 1), (-1, 1)]
        for (sx, sz) in corners {
            b.limb(from: Vec3(sx * base, foot - 0.02, sz * base), to: Vec3(sx * top, height, sz * top), radius: 0.011, color: Palette.timber)
        }
        // Braces in stages: rails round, and crossed struts on each face.
        let stages = roofed ? 3 : 2
        for stage in 0...stages {
            let t = Float(stage) / Float(stages)
            let y = foot + (height - foot) * t, r = base + (top - base) * t
            for index in 0..<4 {
                let (ax, az) = corners[index], (cx, cz) = corners[(index + 1) % 4]
                b.beam(from: Vec3(ax * r, y, az * r), to: Vec3(cx * r, y, cz * r), width: 0.007, color: Palette.timberDark)
                if stage < stages {
                    let t2 = Float(stage + 1) / Float(stages)
                    let y2 = foot + (height - foot) * t2, r2 = base + (top - base) * t2
                    b.fine { $0.beam(from: Vec3(ax * r, y, az * r), to: Vec3(cx * r2, y2, cz * r2), width: 0.004, color: Palette.timberDark) }
                }
            }
        }
        // The platform and its rail.
        b.box(center: Vec3(0, height + 0.006, 0), size: Vec3(0.15, 0.012, 0.15), color: Palette.timberPale)
        for index in 0..<4 {
            let (ax, az) = corners[index], (cx, cz) = corners[(index + 1) % 4]
            b.beam(from: Vec3(ax * 0.072, height + 0.05, az * 0.072), to: Vec3(cx * 0.072, height + 0.05, cz * 0.072), width: 0.005, color: Palette.timber)
            b.limb(from: Vec3(ax * 0.072, height, az * 0.072), to: Vec3(ax * 0.072, height + 0.05, az * 0.072), radius: 0.004, color: Palette.timber)
        }
        b.ladder(from: Vec3(0.02, foot, 0.13), to: Vec3(0.02, height, 0.075), width: 0.04, rungs: Int(height / 0.035), color: Palette.timberPale)
        basket(&b, at: Vec3(0, height + 0.03, 0), radius: 0.045)
        if roofed {
            for (sx, sz) in corners {
                b.limb(from: Vec3(sx * 0.07, height, sz * 0.07), to: Vec3(sx * 0.07, height + 0.17, sz * 0.07), radius: 0.006, color: Palette.timberDark)
            }
            b.place(.translation(Vec3(0, height + 0.17, 0))) {
                $0.hipRoof(width: 0.2, depth: 0.2, base: 0, height: 0.09, color: Palette.slate, overhang: 0.01)
            }
            b.fine { b in
                b.limb(from: Vec3(0, height + 0.26, 0), to: Vec3(0, height + 0.31, 0), radius: 0.004, color: Palette.iron)
            }
            b.flag(at: Vec3(0, height + 0.31, 0), width: 0.06, height: 0.035, turn: 0.4)
        }
        return flame(&b, &rig, at: Vec3(0, height + 0.05, 0), size: 0.03)
    }

    /// The round stone tower of the third level: coursed, a stair winding
    /// round its outside, battlements, the great brazier on its crown.
    static func stoneTower(_ b: inout MeshBuilder, _ rig: inout Rig) -> UInt16 {
        let height: Float = 0.56, radius: Float = 0.085
        b.lathe([(radius + 0.025, -0.06), (radius + 0.02, 0.04), (radius, 0.06), (radius * 0.92, height)], sides: 12, color: Palette.stone)
        b.lathe([(radius * 0.92, height), (radius * 1.12, height + 0.012), (radius * 1.12, height + 0.03), (radius * 0.9, height + 0.03)],
                sides: 12, color: Palette.stonePale)
        b.place(.translation(Vec3(0, 0, 0))) {
            $0.merlonRing(radius: radius * 1.06, base: height + 0.03, count: 8, size: Vec3(0.026, 0.035, 0.018), color: Palette.stone)
        }
        b.fine { b in
            for y in stride(from: Float(0.1), to: height, by: 0.07) {
                b.lathe([(radius * 0.93 + 0.002, y), (radius * 0.95 + 0.004, y + 0.004), (radius * 0.93 + 0.002, y + 0.008)],
                        sides: 12, color: Palette.stonePale)
            }
        }
        // Slit windows lit, a door at the foot.
        for (index, y) in [Float(0.16), 0.3, 0.42].enumerated() {
            b.window(onRound: radius * 0.94, y: y, angle: Float(index) * 2.2 + 0.4, width: 0.01, height: 0.035)
        }
        b.door(Vec3(0, 0.05, radius + 0.022), width: 0.04, height: 0.08, facing: 0)
        // The stair winding round its outside: steps on corbels.
        let steps = 22
        for index in 0..<steps {
            let t = Float(index) / Float(steps)
            let angle = Float.pi * 0.6 + t * Float.pi * 2.2
            let y = 0.06 + t * (height - 0.1)
            let out = Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle))))
            b.box(center: out * (radius + 0.02) + Vec3(0, y, 0), size: Vec3(0.04, 0.008, 0.022), turn: -angle, color: Palette.stonePale)
        }
        // The great brazier under its ring of iron on four arms.
        basket(&b, at: Vec3(0, height + 0.04, 0), radius: 0.06)
        b.with(material: .metal) { b in
            for index in 0..<4 {
                let angle = Float(index) / 4 * 2 * .pi + .pi / 4
                let p = Vec3(0.07 * Float(cos(Double(angle))), 0, 0.07 * Float(sin(Double(angle))))
                b.limb(from: p + Vec3(0, height + 0.03, 0), to: p * 0.6 + Vec3(0, height + 0.2, 0), radius: 0.004, color: Palette.iron)
            }
            b.place(.translation(Vec3(0, height + 0.2, 0))) {
                $0.lathe([(0.044, -0.004), (0.048, 0), (0.044, 0.004)], sides: 10, color: Palette.iron)
            }
        }
        return flame(&b, &rig, at: Vec3(0, height + 0.06, 0), size: 0.042)
    }

    /// Cut wood stacked for the fire, the axe in the block beside it.
    static func woodpile(_ b: inout MeshBuilder, at: Vec3) {
        for row in 0..<3 {
            for index in 0..<(4 - row) {
                let z = -0.03 + Float(index) * 0.02 + Float(row) * 0.01
                b.log(from: at + Vec3(-0.04, 0.012 + Float(row) * 0.018, z), to: at + Vec3(0.04, 0.012 + Float(row) * 0.018, z), radius: 0.009)
            }
        }
        b.fine { b in
            b.place(.translation(at + Vec3(0.06, 0, 0.03))) {
                $0.lathe([(0.016, 0), (0.016, 0.03)], sides: 6, color: Palette.timber)
            }
            b.beam(from: at + Vec3(0.06, 0.03, 0.03), to: at + Vec3(0.08, 0.06, 0.04), width: 0.004, color: Palette.timberPale)
        }
    }

    /// A horn of warning hung on a post.
    static func horn(_ b: inout MeshBuilder, at: Vec3) {
        b.limb(from: at, to: at + Vec3(0, 0.13, 0), radius: 0.006, color: Palette.timberDark)
        b.beam(from: at + Vec3(0, 0.12, 0), to: at + Vec3(0.03, 0.12, 0), width: 0.005, color: Palette.timberDark)
        b.place(.translation(at + Vec3(0.03, 0.095, 0)) * .rotationZ(1.2)) {
            $0.lathe([(0.004, -0.03), (0.008, 0.0), (0.016, 0.025)], sides: 6, color: Palette.padded)
        }
    }

    /// The beacon-keeper's hut: timber under thatch at the second level,
    /// stone under slate at the third; its door and a window lit.
    static func hut(_ b: inout MeshBuilder, at: Vec3, stone: Bool) {
        b.hall(at: at, width: 0.1, depth: 0.12, height: 0.075, wall: stone ? Palette.stone : Palette.timber,
               roof: stone ? Palette.slate : Palette.thatch, pitch: 0.65, turn: .pi / 2, footing: stone ? Palette.stoneDark : nil)
        b.door(at + Vec3(0.061, 0.035, 0.015), width: 0.028, height: 0.055, facing: .pi / 2)
        b.window(at + Vec3(0.061, 0.05, -0.03), width: 0.016, height: 0.018, facing: .pi / 2)
        b.box(min: at + Vec3(-0.04, 0.07, 0.025), max: at + Vec3(-0.018, 0.15, 0.047), color: Palette.stoneDark)
    }

    /// Loose stones about the height.
    static func scree(_ b: inout MeshBuilder) {
        for index in 0..<10 {
            let angle = Float(index) * 2.39996
            let r = 0.14 + 0.12 * Float((index * 29) % 7) / 7
            b.rock(center: Vec3(r * Float(cos(Double(angle))), 0.01, r * Float(sin(Double(angle)))), size: Vec3(0.02, 0.012, 0.016),
                   seed: UInt32(index + 101), color: index % 2 == 0 ? Palette.rock : Palette.stoneDark)
        }
    }

    /// A cairn of piled stones, a waymark for those climbing to the fire.
    static func cairn(_ b: inout MeshBuilder, at: Vec3) {
        for index in 0..<9 {
            let ring = index < 5 ? 0 : (index < 8 ? 1 : 2)
            let angle = Float(index) * 1.9
            let r: Float = ring == 0 ? 0.03 : (ring == 1 ? 0.018 : 0)
            b.rock(center: at + Vec3(r * Float(cos(Double(angle))), 0.012 + Float(ring) * 0.022, r * Float(sin(Double(angle)))),
                   size: Vec3(0.022, 0.016, 0.02), seed: UInt32(index + 211), color: index % 2 == 0 ? Palette.stone : Palette.rock)
        }
    }
}
