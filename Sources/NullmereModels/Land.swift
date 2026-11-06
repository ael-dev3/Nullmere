import Foundation
import NullmereCore

/// What the world sets over the land that a company can't take: an
/// alliance's standard, a rally's war camp, a host's banner, and the
/// tokens of the land's other marks.
enum Land {
    // MARK: Sites of the land

    /// An alliance's standard: a tall pole on a cairn, a crossbar and a long
    /// swallow-tailed banner in the alliance's colour, braziers at its foot.
    static func standard(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        var flames: [UInt16] = []
        // A stepped plinth of dressed stone under the cairn, the alliance's
        // shield carved on its face, and a guard post either side of the way.
        b.lathe([(0.3, -0.06), (0.3, 0.0), (0.26, 0.005), (0.26, 0.03), (0.22, 0.035)], sides: 10, color: Palette.stonePale)
        b.place(.translation(Vec3(0, 0.02, 0.27))) {
            $0.with(material: .house) {
                $0.lathe([(0.04, -0.003), (0.04, 0.003)], sides: 8, color: Palette.house)
            }
        }
        // A stele of dark stone behind the pole, the alliance's oath cut in
        // panels down its face and its shield above them.
        b.box(center: Vec3(0, 0.22, -0.2), size: Vec3(0.16, 0.44, 0.05), color: Palette.slate)
        b.place(.translation(Vec3(0, 0.44, -0.2))) { $0.gableRoof(width: 0.18, depth: 0.07, base: 0.0, height: 0.05, color: Palette.stoneDark) }
        for row in 0..<5 {
            b.box(center: Vec3(0, 0.08 + Float(row) * 0.06, -0.174), size: Vec3(0.12, 0.03, 0.004), color: Palette.stoneDark)
        }
        b.place(.translation(Vec3(0, 0.39, -0.172)) * .rotationX(.pi / 2)) {
            $0.with(material: .house) { $0.lathe([(0.035, -0.003), (0.035, 0.003)], sides: 10, color: Palette.house) }
        }
        // Torches on posts round the ring's edge, burning.
        for index in 0..<4 {
            let angle = Float(index) / 4 * 2 * .pi + 0.9
            let foot = MeshBuilder.ring(0.33, 0, angle)
            b.limb(from: foot, to: foot + Vec3(0, 0.2, 0), radius: 0.006, color: Palette.timberDark)
            b.place(.translation(foot + Vec3(0, 0.2, 0))) { $0.lathe([(0.008, 0), (0.016, 0.03)], sides: 6, color: Palette.iron) }
            flames.append(Beacon.flame(&b, &rig, at: foot + Vec3(0, 0.23, 0), size: 0.022))
        }
        // The war horn on its post, to call the alliance to the standard.
        b.limb(from: Vec3(0.2, 0, 0.08), to: Vec3(0.2, 0.18, 0.08), radius: 0.007, color: Palette.timberDark)
        b.place(.translation(Vec3(0.2, 0.19, 0.08)) * .rotationZ(-1.2)) {
            $0.lathe([(0.004, 0.0), (0.012, 0.08), (0.03, 0.13)], sides: 8, color: Palette.bone)
        }
        // Lesser banners of the alliance's Houses set in a ring about it.
        for index in 0..<6 {
            let angle = Float(index) / 6 * 2 * .pi + 0.5
            let foot = MeshBuilder.ring(0.4, 0, angle)
            b.rock(center: foot + Vec3(0, 0.015, 0), size: Vec3(0.03, 0.025, 0.03), rings: 2, sides: 5, jitter: 0.2, seed: UInt32(140 + index),
                   color: Palette.stoneDark)
            b.limb(from: foot, to: foot + Vec3(0, 0.42, 0), radius: 0.006, color: Palette.timberDark)
            b.flag(at: foot + Vec3(0, 0.41, 0), width: 0.1, height: 0.14, turn: -angle, tail: index % 2 == 0)
        }
        for x in [Float(-0.26), 0.26] {
            b.box(center: Vec3(x, 0.08, 0.2), size: Vec3(0.05, 0.16, 0.05), color: Palette.stone)
            b.place(.translation(Vec3(x, 0.16, 0.2))) { $0.cone(sides: 4, radius: 0.04, to: 0.05, color: Palette.slate) }
            b.limb(from: Vec3(x + 0.04, 0, 0.24), to: Vec3(x + 0.03, 0.3, 0.24), radius: 0.004, color: Palette.timber)
            b.with(material: .metal) {
                $0.place(.translation(Vec3(x + 0.03, 0.3, 0.24))) { $0.cone(sides: 4, radius: 0.008, to: 0.03, color: Palette.iron) }
            }
        }
        // The cairn, stones heaped about the pole's foot.
        b.lathe([(0.2, -0.08), (0.2, 0.0), (0.16, 0.06), (0.08, 0.11), (0.0, 0.12)], sides: 7, color: Palette.stoneDark)
        for index in 0..<6 {
            let angle = Float(index) / 6 * 2 * .pi + 0.3
            b.rock(center: MeshBuilder.ring(0.17, 0.03, angle), size: Vec3(0.05, 0.04, 0.045), rings: 2, sides: 4, jitter: 0.25,
                   seed: UInt32(index + 120), color: index % 2 == 0 ? Palette.stone : Palette.stonePale)
        }
        // The pole and its crossbar, a finial of iron at its head.
        b.limb(from: Vec3(0, 0.05, 0), to: Vec3(0, 1.0, 0), radius: 0.016, topRadius: 0.011, color: Palette.timberDark)
        b.beam(from: Vec3(-0.02, 0.92, 0), to: Vec3(0.32, 0.92, 0), width: 0.014, color: Palette.timber)
        b.with(material: .metal) {
            $0.place(.translation(Vec3(0, 1.0, 0))) { $0.cone(sides: 4, radius: 0.02, to: 0.07, color: Palette.iron) }
        }
        // The banner, hanging from the crossbar, in the alliance's colour.
        b.flag(at: Vec3(0.01, 0.91, 0), width: 0.3, height: 0.42, tail: true)
        b.fine { standardNear(&$0) }
        // Braziers at its foot, burning.
        for x in [Float(-0.14), 0.14] {
            b.limb(from: Vec3(x, 0.0, 0.16), to: Vec3(x, 0.12, 0.16), radius: 0.008, color: Palette.iron)
            b.lathe([(0.0, 0.11), (0.035, 0.12), (0.04, 0.15)], sides: 6, color: Palette.iron)
            flames.append(Beacon.flame(&b, &rig, at: Vec3(x, 0.14, 0.16), size: 0.035))
        }
        let machinery = Machinery(flames: flames, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// A standard drawn near: guy ropes from its pole to pegs, its banner
    /// bound to its crossbar, shields in the alliance's colour against its
    /// cairn, two spears crossed behind its pole and its braziers on three
    /// legs each.
    static func standardNear(_ b: inout MeshBuilder) {
        for angle in [Float(1.6), 3.3, 4.9] {
            let peg = MeshBuilder.ring(0.44, 0, angle)
            b.limb(from: Vec3(0, 0.72, 0), to: peg + Vec3(0, 0.03, 0), radius: 0.002, sides: 3, color: Palette.linen.mix(Palette.leather, 0.5))
            b.limb(from: peg - Vec3(0, 0.01, 0), to: peg + MeshBuilder.ring(0.01, 0.04, angle), radius: 0.004, sides: 3,
                   color: Palette.timberDark)
        }
        for x in [Float(0.06), 0.16, 0.26] {
            b.place(.translation(Vec3(x, 0.92, 0)) * .rotationZ(.pi / 2)) {
                $0.tube([(0.012, -0.004), (0.012, 0.004)], sides: 4, color: Palette.leatherDark)
            }
        }
        for angle in [Float(0.82), 2.92, 5.01] {
            b.place(.translation(MeshBuilder.ring(0.235, 0.045, angle)) * .rotationY(angle) * .rotationZ(-1.15)) {
                $0.with(material: .house) { $0.lathe([(0.045, -0.005), (0.045, 0.003), (0.0, 0.008)], sides: 8, color: Palette.house) }
                $0.with(material: .metal) { $0.cone(sides: 5, radius: 0.011, from: 0.007, to: 0.018, color: Palette.iron) }
            }
        }
        for (foot, top) in [(MeshBuilder.ring(0.3, 0, 1.25), Vec3(-0.06, 0.5, -0.02)), (MeshBuilder.ring(0.3, 0, 1.9), Vec3(0.06, 0.5, -0.02))] {
            b.limb(from: foot, to: top, radius: 0.005, color: Palette.timberDark)
            b.with(material: .metal) {
                $0.place(.translation(top) * Mat4.aligningUp(to: top - foot)) { $0.cone(sides: 4, radius: 0.011, to: 0.045, color: Palette.iron) }
            }
        }
        for x in [Float(-0.14), 0.14] {
            for leg in 0..<3 {
                let angle = Float(leg) * 2 * .pi / 3 + 0.3
                b.limb(from: Vec3(x, 0.1, 0.16) + MeshBuilder.ring(0.012, 0, angle), to: Vec3(x, 0, 0.16) + MeshBuilder.ring(0.045, 0, angle),
                       radius: 0.004, sides: 3, color: Palette.iron)
            }
        }
    }

    /// Where a rally camp's fire burns, in its own frame.
    static let rallyFire = Vec3(0.24, 0.135, 0.2)

    /// A rally's war camp, raised by the muster's gate while its host
    /// gathers: a tall war pole flying a long swallow-tailed banner in the
    /// caller's colour over a shorter pennon, a great war drum on its
    /// trestle with its beaters across it, a horn on a post, a rack of
    /// spears and shields, and a fire in a ring of stones.
    static func rallyCamp(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        // The host's tents pitched about the camp's edge, each with its pole
        // and pennon, and horse lines along its back.
        for (index, angle) in [Float(0.9), 1.6, 2.3, 3.7, 4.4, 5.1].enumerated() {
            let at = MeshBuilder.ring(0.36, 0, angle)
            b.place(.translation(at) * .rotationY(-angle)) {
                $0.cone(sides: 8, radius: 0.09, to: 0.16, color: index % 2 == 0 ? Palette.canvas : Palette.linen)
                $0.limb(from: Vec3(0, 0.15, 0), to: Vec3(0, 0.24, 0), radius: 0.004, color: Palette.timberDark)
                $0.with(material: .house) {
                    $0.box(center: Vec3(0.025, 0.225, 0), size: Vec3(0.045, 0.025, 0.003), color: Palette.house)
                }
                $0.box(center: Vec3(0.088, 0.04, 0), size: Vec3(0.004, 0.07, 0.045), color: Palette.barkBlack)
            }
        }
        let line = Vec3(0.0, 0, -0.38)
        for x in [Float(-0.16), 0.16] {
            b.limb(from: line + Vec3(x, 0, 0), to: line + Vec3(x, 0.08, 0), radius: 0.005, color: Palette.timberDark)
        }
        b.limb(from: line + Vec3(-0.16, 0.075, 0), to: line + Vec3(0.16, 0.075, 0), radius: 0.002, color: Palette.linen)
        for (index, x) in [Float(-0.09), 0.0, 0.09].enumerated() {
            Wayhouse.horse(&b, at: line + Vec3(x, 0, 0.04), turn: -.pi / 2,
                           coat: [Palette.horseBay, Palette.horseGrey, Palette.horseBlack][index])
        }
        // A rack of spears and shields by the drum.
        let rack = Vec3(-0.34, 0, -0.08)
        b.beam(from: rack + Vec3(0, 0.12, -0.07), to: rack + Vec3(0, 0.12, 0.07), width: 0.006, color: Palette.timberDark)
        for z in [Float(-0.07), 0.07] {
            b.limb(from: rack + Vec3(0, 0, z), to: rack + Vec3(0, 0.13, z), radius: 0.004, color: Palette.timberDark)
        }
        for index in 0..<5 {
            let z = -0.05 + Float(index) * 0.025
            b.limb(from: rack + Vec3(0.02, 0, z), to: rack + Vec3(-0.01, 0.24, z), radius: 0.0025, color: Palette.timber)
        }
        // Trodden ground, the camp's floor.
        b.lathe([(0.46, -0.05), (0.46, 0.0), (0.4, 0.012), (0.0, 0.014)], sides: 9, color: Palette.earth)
        // The war pole, its finial and crossbar, and its banners.
        b.limb(from: Vec3(0, 0.0, 0), to: Vec3(0, 1.45, 0), radius: 0.02, topRadius: 0.013, color: Palette.timberDark)
        b.beam(from: Vec3(-0.02, 1.36, 0), to: Vec3(0.4, 1.36, 0), width: 0.016, color: Palette.timber)
        b.with(material: .metal) {
            $0.place(.translation(Vec3(0, 1.45, 0))) { $0.cone(sides: 4, radius: 0.026, to: 0.1, color: Palette.gold, twist: .pi / 4) }
        }
        b.flag(at: Vec3(0.01, 1.35, 0), width: 0.38, height: 0.62, tail: true)
        b.flag(at: Vec3(0, 0.98, 0), width: 0.22, height: 0.12, turn: .pi / 2)
        for angle in [Float(0.5), 2.6, 4.7] {
            let foot = MeshBuilder.ring(0.12, 0, angle)
            b.limb(from: foot, to: Vec3(0, 0.3, 0), radius: 0.008, color: Palette.timberDark)
        }
        // The war drum on its trestle, skin up, beaters across it.
        let drum = Vec3(-0.26, 0, 0.12)
        for x in [Float(-0.07), 0.07] {
            b.limb(from: drum + Vec3(x, 0, -0.06), to: drum + Vec3(x * 0.6, 0.16, 0), radius: 0.008, color: Palette.timberDark)
            b.limb(from: drum + Vec3(x, 0, 0.06), to: drum + Vec3(x * 0.6, 0.16, 0), radius: 0.008, color: Palette.timberDark)
        }
        b.place(.translation(drum + Vec3(0, 0.16, 0))) {
            $0.lathe([(0.0, 0.0), (0.1, 0.0), (0.115, 0.06), (0.1, 0.12), (0.0, 0.12)], sides: 10, color: Palette.leatherDark)
            $0.with(material: .house) { $0.lathe([(0.117, 0.05), (0.118, 0.07)], sides: 10, color: Palette.house) }
            $0.lathe([(0.0, 0.121), (0.098, 0.121)], sides: 10, color: Palette.linen)
        }
        // The drummer's beaters, rising and falling on the skin.
        let beat = rig.add("war drum beaters", pivot: drum + Vec3(-0.12, 0.29, 0))
        b.with(part: beat) {
            for z in [Float(-0.03), 0.03] {
                $0.limb(from: drum + Vec3(-0.12, 0.29, z), to: drum + Vec3(0.02, 0.3, z * 2), radius: 0.006, color: Palette.timber)
            }
        }
        // The fire in its ring of stones.
        let fire = rallyFire
        for index in 0..<7 {
            b.rock(center: Vec3(fire.x, 0.01, fire.z) + MeshBuilder.ring(0.07, 0, Float(index) / 7 * 2 * .pi),
                   size: Vec3(0.03, 0.025, 0.03), rings: 2, sides: 4, jitter: 0.2, seed: UInt32(index + 300), color: Palette.stoneDark)
        }
        let flame = Beacon.flame(&b, &rig, at: Vec3(fire.x, 0.0, fire.z), size: 0.06)
        b.fine { rallyCampNear(&$0) }
        let machinery = Machinery(swings: [.init(part: beat, axis: Vec3(0, 0, 1), angle: 0.35)], flames: [flame], parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// A rally camp drawn near: a horn on its post, a rack of spears with
    /// shields in the caller's colour against it, logs by the fire and
    /// guy ropes on the war pole.
    static func rallyCampNear(_ b: inout MeshBuilder) {
        for angle in [Float(1.2), 3.4, 5.4] {
            let peg = MeshBuilder.ring(0.42, 0, angle)
            b.limb(from: Vec3(0, 1.05, 0), to: peg + Vec3(0, 0.03, 0), radius: 0.0025, sides: 3, color: Palette.linen.mix(Palette.leather, 0.5))
            b.limb(from: peg - Vec3(0, 0.01, 0), to: peg + Vec3(0, 0.04, 0), radius: 0.005, sides: 3, color: Palette.timberDark)
        }
        // The horn on its post.
        let post = Vec3(0.1, 0, -0.3)
        b.limb(from: post, to: post + Vec3(0, 0.28, 0), radius: 0.012, color: Palette.timberDark)
        b.place(.translation(post + Vec3(0.02, 0.26, 0)) * .rotationZ(-1.2)) {
            $0.tube([(0.012, 0), (0.018, 0.06), (0.03, 0.12), (0.042, 0.15)], sides: 6, color: Palette.linen.mix(Palette.leather, 0.3))
        }
        // The rack of spears, shields against it.
        let rack = Vec3(-0.22, 0, -0.22)
        b.beam(from: rack + Vec3(-0.12, 0.2, 0), to: rack + Vec3(0.12, 0.2, 0), width: 0.012, color: Palette.timber)
        for x in [Float(-0.12), 0.12] { b.limb(from: rack + Vec3(x, 0, 0), to: rack + Vec3(x, 0.22, 0), radius: 0.008, color: Palette.timberDark) }
        for x in stride(from: Float(-0.09), through: 0.09, by: 0.045) {
            b.limb(from: rack + Vec3(x, 0, 0.03), to: rack + Vec3(x, 0.5, -0.02), radius: 0.004, sides: 3, color: Palette.timberDark)
            b.with(material: .metal) {
                $0.place(.translation(rack + Vec3(x, 0.5, -0.02))) { $0.cone(sides: 4, radius: 0.009, to: 0.04, color: Palette.iron) }
            }
        }
        for x in [Float(-0.07), 0.07] {
            b.place(.translation(rack + Vec3(x, 0.07, 0.05)) * .rotationX(-1.3)) {
                $0.with(material: .house) { $0.lathe([(0.055, -0.005), (0.055, 0.004), (0.0, 0.01)], sides: 8, color: Palette.house) }
                $0.with(material: .metal) { $0.cone(sides: 5, radius: 0.013, from: 0.008, to: 0.02, color: Palette.iron) }
            }
        }
        // Logs stacked by the fire.
        for (index, z) in [Float(-0.03), 0.0, 0.03].enumerated() {
            let y = index == 1 ? Float(0.035) : 0.012
            b.limb(from: rallyFire + Vec3(0.12, y - 0.135, z), to: rallyFire + Vec3(0.26, y - 0.135, z), radius: 0.013, sides: 5, color: Palette.timber)
        }
    }
}

extension Land {
    /// A rally host's war banner: a tall staff rising from among the troops
    /// at the host's head, a gilt finial over a long swallow-tailed banner
    /// in the caller's colour and two streamers under it.
    static func hostBanner(name: String) -> Model {
        var b = MeshBuilder()
        b.limb(from: Vec3(0, 0.0, 0), to: Vec3(0, 1.25, 0), radius: 0.012, topRadius: 0.009, color: Palette.timberDark)
        b.beam(from: Vec3(-0.01, 1.17, 0), to: Vec3(0.3, 1.17, 0), width: 0.012, color: Palette.timber)
        b.with(material: .metal) {
            $0.place(.translation(Vec3(0, 1.25, 0))) { $0.cone(sides: 4, radius: 0.02, to: 0.08, color: Palette.gold, twist: .pi / 4) }
        }
        b.flag(at: Vec3(0.005, 1.16, 0), width: 0.3, height: 0.5, tail: true)
        b.flag(at: Vec3(0, 0.62, 0), width: 0.16, height: 0.05, turn: .pi / 2)
        return Model(name: name, mesh: b.mesh)
    }
}

extension Land {
    /// Where a crest's shield hangs on its board, its face toward +z.
    static let crestFace = Vec3(0, 0.42, 0.014)
}

extension Land {
    /// The Drowned Crown: a broad band of tarnished gold, green with the
    /// lake's weed, seven tines rising from it each set with a stone of
    /// moonsalt lit from within, a circlet of pearls at its brow and the
    /// weed trailing from its rim.
    static func drownedCrown(name: String) -> Model {
        var b = MeshBuilder()
        let gold = Palette.gold.mix(Palette.bronze, 0.35)
        let verdigris = Palette.bronze.mix(Vec3(0.24, 0.45, 0.38), 0.6)
        let weed = Vec3(0.13, 0.24, 0.17)
        // The band, a little flared, and its rolled lip.
        b.lathe([(0.15, 0.0), (0.155, 0.02), (0.15, 0.05), (0.158, 0.08), (0.162, 0.09)], sides: 18, color: gold)
        b.place(.translation(Vec3(0, 0.005, 0))) {
            $0.lathe([(0.152, 0.0), (0.165, 0.01), (0.152, 0.02)], sides: 18, color: verdigris)
        }
        // Seven tines, each a leaf of gold rising to a point.
        for index in 0..<7 {
            let angle = Float(index) / 7 * 2 * .pi
            let out = Vec3(Float(sin(Double(angle))), 0, Float(cos(Double(angle))))
            let foot = out * 0.155 + Vec3(0, 0.085, 0)
            let tip = out * 0.17 + Vec3(0, 0.2, 0)
            let side = Vec3(out.z, 0, -out.x) * 0.03
            b.sheet([foot - side, foot + side, tip], normal: out, thickness: 0.012, color: index % 2 == 0 ? gold : verdigris)
            // Its stone of moonsalt, lit from within.
            b.with(material: .glow) {
                $0.sphere(center: out * 0.165 + Vec3(0, 0.13, 0), radius: 0.018, rings: 3, sides: 6, color: Palette.moonsalt)
            }
        }
        // A second circlet of pearls along its lower lip.
        for index in 0..<18 {
            let angle = Float(index) / 18 * 2 * .pi
            b.sphere(center: Vec3(0.166 * Float(sin(Double(angle))), 0.012, 0.166 * Float(cos(Double(angle)))),
                     radius: 0.008, rings: 3, sides: 5, color: Palette.stoneWhite.mix(Palette.moonGlow, 0.2))
        }
        // A circlet of pearls at the brow.
        for index in 0..<14 {
            let angle = (Float(index) + 0.5) / 14 * 2 * .pi
            b.sphere(center: Vec3(0.163 * Float(sin(Double(angle))), 0.045, 0.163 * Float(cos(Double(angle)))),
                     radius: 0.009, rings: 2, sides: 5, color: Palette.stoneWhite)
        }
        // The lake's weed trailing from its rim, in strands that sway.
        b.with(material: .foliage, sway: 1) {
            $0.swayRange = (-0.12, 0.03)
            for index in 0..<9 {
                let angle = Float(index) * 0.73
                let out = Vec3(Float(sin(Double(angle))), 0, Float(cos(Double(angle))))
                var at = out * 0.16 + Vec3(0, 0.02, 0)
                for step in 0..<3 {
                    let next = at + out * 0.016 + Vec3(0.006 * Float(step % 2 == 0 ? 1 : -1), -0.04, 0)
                    $0.limb(from: at, to: next, radius: 0.006 - Float(step) * 0.0015, topRadius: 0.005 - Float(step) * 0.0015, sides: 4,
                            color: index % 3 == 0 ? weed.mix(Palette.moss, 0.4) : weed)
                    at = next
                }
            }
        }
        // Filigree along the band: studs between the pearls, and a chased
        // line of verdigris round its middle.
        for index in 0..<21 {
            let angle = Float(index) / 21 * 2 * .pi
            b.sphere(center: Vec3(0.158 * Float(sin(Double(angle))), 0.068, 0.158 * Float(cos(Double(angle)))),
                     radius: 0.005, rings: 2, sides: 4, color: index % 3 == 0 ? Palette.moonsalt : gold)
        }
        b.place(.translation(Vec3(0, 0.03, 0))) {
            $0.tube([(0.1565, 0), (0.1575, 0.006)], sides: 18, color: verdigris)
        }
        // The rotted velvet of its cap within, and a great stone at its heart.
        b.lathe([(0.145, 0.02), (0.12, 0.09), (0.06, 0.15), (0.0, 0.17)], sides: 14, color: Palette.madder.mix(Palette.barkBlack, 0.55))
        b.with(material: .glow) {
            $0.place(.translation(Vec3(0, 0.17, 0))) {
                $0.lathe([(0.0, 0.0), (0.03, 0.025), (0.0, 0.07)], sides: 7, color: Palette.moonsalt)
            }
        }
        // Barnacles and shells on its lower rim.
        for index in 0..<10 {
            let angle = Float(index) * 2.39
            b.rock(center: Vec3(0.16 * Float(sin(Double(angle))), 0.008, 0.16 * Float(cos(Double(angle)))), size: Vec3(0.012, 0.008, 0.011),
                   rings: 2, sides: 5, jitter: 0.3, seed: UInt32(800 + index), color: index % 2 == 0 ? Palette.stonePale : Palette.bone)
        }
        // About it, slowly turning, a halo of moonlight; and the lake's water
        // still dripping from its tines.
        var rig = Rig()
        let halo = rig.add("crown halo", pivot: Vec3(0, 0.14, 0))
        b.with(part: halo, material: .glow) {
            for index in 0..<12 {
                let angle = Float(index) / 12 * 2 * .pi
                $0.place(.translation(Vec3(0.24 * Float(sin(Double(angle))), 0.14 + 0.02 * Float(index % 2), 0.24 * Float(cos(Double(angle)))))) {
                    $0.lathe([(0.0, -0.01), (0.008, 0.0), (0.0, 0.012)], sides: 5, color: Palette.moonGlow)
                }
            }
        }
        let drips = rig.add("crown drips", pivot: Vec3(0, 0.0, 0))
        b.with(part: drips, material: .crystal) {
            for index in 0..<7 {
                let angle = Float(index) / 7 * 2 * .pi
                let out = Vec3(Float(sin(Double(angle))), 0, Float(cos(Double(angle))))
                $0.place(.translation(out * 0.172 + Vec3(0, 0.08, 0))) {
                    $0.lathe([(0.0, -0.012), (0.004, -0.004), (0.0, 0.006)], sides: 4, color: Palette.slate.mix(Palette.moonGlow, 0.4))
                }
            }
        }
        let machinery = Machinery(wheels: [.init(part: halo, axis: Vec3(0, 1, 0), turns: 1)],
                                  swings: [.init(part: drips, axis: Vec3(1, 0, 0), angle: 0.05)], parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }
}

extension Land {
    /// A listening stone sunk in the black lake: a rough standing stone
    /// rising from the water on a cairn of smaller stones, veined with
    /// moonsalt that glows faintly, a ring of salt-white cord about its
    /// waist, and rings of ripple turning slowly out about it on the water.
    static func listeningStone(name: String) -> Model {
        var b = MeshBuilder()
        // The cairn it stands on, half under the water.
        for index in 0..<6 {
            let angle = Float(index) / 6 * 2 * .pi + 0.4
            let out = Vec3(Float(sin(Double(angle))), 0, Float(cos(Double(angle))))
            b.rock(center: out * 0.06 + Vec3(0, -0.01, 0), size: Vec3(0.035, 0.02, 0.03), rings: 2, sides: 5, jitter: 0.3,
                   seed: 900 + UInt32(index), color: index % 2 == 0 ? Palette.stoneDark : Palette.slate)
        }
        // The stone itself, leaning a little, its faces rough.
        b.rock(center: Vec3(0.005, 0.11, 0), size: Vec3(0.034, 0.13, 0.026), rings: 5, sides: 6, jitter: 0.18, seed: 917, color: Palette.slate)
        // Its veins of moonsalt.
        b.with(material: .crystal) {
            for (index, y) in [Float(0.05), 0.1, 0.16].enumerated() {
                let tilt = Float(index) * 0.7
                $0.beam(from: Vec3(-0.03 * cos(tilt), y, 0.026), to: Vec3(0.03 * cos(tilt), y + 0.02, 0.022), width: 0.005, depth: 0.004,
                        color: Palette.moonGlow)
            }
        }
        // The cord bound about its waist.
        b.tube([(0.038, 0.072), (0.038, 0.08)], sides: 10, color: Palette.stonePale)
        // A glow at its crown, where it listens.
        b.with(material: .glow) {
            $0.lathe([(0.0, 0.225), (0.012, 0.235), (0.0, 0.25)], sides: 6, color: Palette.moonGlow)
        }
        // Rings of ripple on the water about it, turning out slowly.
        var rig = Rig()
        let rings = rig.add("listening rings", pivot: Vec3(0, 0, 0))
        b.with(part: rings, material: .glow) {
            for (radius, segments) in [(Float(0.12), 18), (0.18, 24), (0.25, 30)] {
                for index in 0..<segments where index % 3 != 2 {
                    let a0 = Float(index) / Float(segments) * 2 * .pi, a1 = Float(index + 1) / Float(segments) * 2 * .pi
                    $0.beam(from: Vec3(radius * sin(a0), 0.004, radius * cos(a0)), to: Vec3(radius * sin(a1), 0.004, radius * cos(a1)),
                            width: 0.006, depth: 0.002, color: Palette.moonGlow.mix(Palette.slate, 0.5))
                }
            }
        }
        let machinery = Machinery(wheels: [.init(part: rings, axis: Vec3(0, 1, 0), turns: 1)], parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }
}

extension Land {
    /// The Pedlar of the Still's skiff: a narrow hull of tarred planks with
    /// a high carved prow, a patched awning on four poles hung with three
    /// lanterns, crates, jars, a chest bound in iron and bolts of dyed
    /// cloth, and the pedlar in his hooded cloak at the stern leaning on
    /// his pole, which works him slowly along; the lanterns flicker.
    static func pedlarSkiff(name: String) -> Model {
        var b = MeshBuilder()
        let tar = Palette.timberDark.mix(Vec3(0.05, 0.05, 0.06), 0.6)
        // The hull, narrower than a barge, its sides flaring.
        b.box(center: Vec3(0, -0.012, 0), size: Vec3(0.22, 0.03, 0.7), color: tar)
        for x in [Float(-0.11), 0.11] {
            b.sheet([Vec3(x, -0.02, -0.34), Vec3(x, -0.02, 0.34), Vec3(x * 1.25, 0.07, 0.3), Vec3(x * 1.25, 0.07, -0.3)],
                    normal: Vec3(x > 0 ? 1 : -1, 0.3, 0), thickness: 0.016, color: tar)
            b.beam(from: Vec3(x * 1.25, 0.075, -0.3), to: Vec3(x * 1.25, 0.075, 0.3), width: 0.012, color: Palette.timber)
        }
        // The stern board, and the high prow rising in a curl.
        b.sheet([Vec3(-0.14, -0.02, -0.34), Vec3(0.14, -0.02, -0.34), Vec3(0.14, 0.08, -0.37), Vec3(-0.14, 0.08, -0.37)],
                normal: Vec3(0, 0, -1), thickness: 0.016, color: tar)
        var prow = Vec3(0, -0.02, 0.34)
        for step in 0..<6 {
            let t = Float(step + 1) / 6
            let next = Vec3(0, -0.02 + 0.24 * t, 0.34 + 0.09 * sin(t * 2.6))
            b.limb(from: prow, to: next, radius: 0.016 - 0.0015 * Float(step), sides: 5, color: tar)
            prow = next
        }
        b.with(material: .crystal) {
            $0.sphere(center: prow + Vec3(0, 0.012, -0.01), radius: 0.012, rings: 2, sides: 5, color: Palette.moonGlow)
        }
        // The awning on its four poles, patched.
        for x in [Float(-0.1), 0.1] {
            for z in [Float(-0.12), 0.2] {
                b.limb(from: Vec3(x, 0.02, z), to: Vec3(x, 0.24, z), radius: 0.006, sides: 4, color: Palette.timber)
            }
        }
        b.sheet([Vec3(-0.13, 0.24, -0.14), Vec3(0.13, 0.24, -0.14), Vec3(0.13, 0.26, 0.04), Vec3(-0.13, 0.26, 0.04)],
                normal: Vec3(0, 1, -0.1), thickness: 0.006, color: Palette.linen.mix(Palette.leather, 0.45))
        b.sheet([Vec3(-0.13, 0.26, 0.04), Vec3(0.13, 0.26, 0.04), Vec3(0.13, 0.24, 0.22), Vec3(-0.13, 0.24, 0.22)],
                normal: Vec3(0, 1, 0.1), thickness: 0.006, color: Palette.linen.mix(Vec3(0.45, 0.16, 0.18), 0.35))
        // The wares: crates, a bound chest, jars and bolts of cloth.
        b.box(center: Vec3(-0.05, 0.05, 0.08), size: Vec3(0.08, 0.06, 0.08), color: Palette.timber)
        b.box(center: Vec3(0.05, 0.045, 0.12), size: Vec3(0.07, 0.05, 0.06), color: Palette.timber.mix(Palette.timberDark, 0.4))
        b.box(center: Vec3(0.0, 0.05, -0.04), size: Vec3(0.12, 0.06, 0.07), color: Palette.leatherDark)
        b.with(material: .metal) {
            for x in [Float(-0.04), 0.04] { $0.box(center: Vec3(x, 0.05, -0.04), size: Vec3(0.01, 0.064, 0.074), color: Palette.iron) }
        }
        for (index, at) in [Vec3(0.06, 0.02, 0.0), Vec3(0.075, 0.02, 0.04), Vec3(-0.07, 0.02, -0.08)].enumerated() {
            b.place(.translation(at)) {
                $0.lathe([(0.0, 0.0), (0.02, 0.01), (0.022, 0.04), (0.01, 0.06), (0.012, 0.07)], sides: 6,
                         color: index == 1 ? Palette.slate : Palette.leather)
            }
        }
        for (index, z) in [Float(0.16), 0.2].enumerated() {
            b.limb(from: Vec3(-0.08, 0.03 + 0.02 * Float(index), z), to: Vec3(0.08, 0.03 + 0.02 * Float(index), z), radius: 0.014, sides: 6,
                   color: index == 0 ? Vec3(0.45, 0.16, 0.18) : Palette.moonGlow.mix(Palette.slate, 0.6))
        }
        var rig = Rig()
        // The lanterns under the awning, flickering.
        var flames: [UInt16] = []
        for (index, at) in [Vec3(-0.1, 0.19, 0.2), Vec3(0.1, 0.19, 0.2), Vec3(0.0, 0.2, -0.13)].enumerated() {
            b.limb(from: at + Vec3(0, 0.05, 0), to: at + Vec3(0, 0.025, 0), radius: 0.002, sides: 3, color: Palette.iron)
            let part = rig.add("pedlar lantern \(index)", pivot: at)
            b.with(part: part, material: .glow) {
                $0.lathe([(0.0, -0.022), (0.016, -0.014), (0.016, 0.014), (0.0, 0.022)], sides: 6, color: Palette.fire.mix(Palette.gold, 0.3))
            }
            flames.append(part)
        }
        // The pedlar at the stern, hooded, his pole working him along.
        let stern = Vec3(0.0, 0.0, -0.27)
        let pedlar = rig.add("pedlar", pivot: stern)
        b.with(part: pedlar) {
            $0.place(.translation(stern)) {
                $0.lathe([(0.055, 0.0), (0.06, 0.08), (0.045, 0.17), (0.03, 0.22), (0.0, 0.23)], sides: 8, color: Vec3(0.12, 0.11, 0.14))
            }
            $0.place(.translation(stern + Vec3(0, 0.255, 0))) {
                $0.lathe([(0.0, -0.035), (0.034, -0.015), (0.03, 0.025), (0.012, 0.045), (0.0, 0.05)], sides: 7, color: Vec3(0.1, 0.09, 0.12))
            }
            $0.limb(from: stern + Vec3(0.04, 0.24, 0.02), to: stern + Vec3(0.16, -0.32, -0.1), radius: 0.007, color: Palette.timber)
        }
        let machinery = Machinery(swings: [.init(part: pedlar, axis: Vec3(1, 0, 0), angle: 0.12)], flames: flames, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }
}
