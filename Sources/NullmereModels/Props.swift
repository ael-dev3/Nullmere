import Foundation

/// What moves through the world apart from companies.
enum Props {
    static func build(_ prop: Prop, name: String) -> Model {
        switch prop {
        case .arrow: return Model(name: name, mesh: arrow())
        case .banner: return banner(name: name)
        case .bird: return bird(name: name)
        case .cart: return cart(name: name)
        case .brazier: return brazier(name: name)
        case .puff: return puff(name: name)
        case .stone: return Model(name: name, mesh: stone())
        case .boat: return boat(name: name)
        case .materials: return Model(name: name, mesh: materials())
        }
    }

    /// A Mangonel's stone in flight, rough-hewn, its middle at the origin.
    static func stone() -> Mesh {
        var b = MeshBuilder()
        b.rock(center: .zero, size: Vec3(0.03, 0.027, 0.03), rings: 3, sides: 6, jitter: 0.15, seed: 11, color: Palette.stone)
        return b.mesh
    }

    /// An arrow in flight, its middle at the origin, pointing along +z.
    static func arrow() -> Mesh {
        var b = MeshBuilder()
        b.limb(from: Vec3(0, 0, -0.13), to: Vec3(0, 0, 0.11), radius: 0.006, sides: 3, color: Palette.timberPale)
        b.with(material: .metal) {
            $0.place(.translation(Vec3(0, 0, 0.1)) * .rotationX(.pi / 2)) {
                $0.cone(sides: 3, radius: 0.014, to: 0.045, color: Palette.steel)
            }
        }
        for angle in [Float(0), 2 * .pi / 3, 4 * .pi / 3] {
            b.place(.rotationZ(angle)) {
                $0.sheet([Vec3(0, 0.004, -0.13), Vec3(0, 0.022, -0.125), Vec3(0, 0.012, -0.08), Vec3(0, 0.004, -0.085)],
                         normal: Vec3(1, 0, 0), thickness: 0.002, color: Palette.linen)
            }
        }
        return b.mesh
    }

    /// A House's banner on a pole, stirring at idle.
    static func banner(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.lathe([(0.03, -0.05), (0.03, 0.02)], sides: 5, color: Palette.stoneDark)
        b.limb(from: Vec3(0, 0, 0), to: Vec3(0, 0.62, 0), radius: 0.011, sides: 5, color: Palette.timberDark)
        b.with(material: .metal) {
            $0.place(.translation(Vec3(0, 0.62, 0))) {
                $0.cone(sides: 4, radius: 0.018, to: 0.05, color: Palette.gold)
            }
        }
        let cloth = rig.add("cloth", pivot: Vec3(0, 0.6, 0))
        b.with(part: cloth) {
            $0.beam(from: Vec3(0, 0.6, 0), to: Vec3(0, 0.6, -0.2), width: 0.012, color: Palette.timberDark)
            $0.flag(at: Vec3(0, 0.595, -0.005), width: 0.2, height: 0.28, turn: .pi / 2)
        }
        let motion = Machinery(swings: [.init(part: cloth, axis: Vec3(0, 1, 0), angle: 0.22)], parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in motion.joints(clip, time) }
    }

    /// A night bird, black, its wings beating at idle and on the wing; the
    /// renderer flies it round its circle.
    static func bird(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        let colour = Vec3(0.12, 0.12, 0.13)
        b.place(.rotationX(.pi / 2)) {
            $0.lathe([(0, -0.06), (0.016, -0.03), (0.018, 0.0), (0.012, 0.03), (0, 0.05)], sides: 4, color: colour)
        }
        b.sheet([Vec3(0, 0, -0.05), Vec3(0.022, 0, -0.085), Vec3(-0.022, 0, -0.085)], normal: Vec3(0, 1, 0), color: colour)
        b.box(center: Vec3(0, 0.002, 0.058), size: Vec3(0.006, 0.006, 0.014), color: Palette.bone)
        for side in [Float(1), -1] {
            let wing = rig.add(side > 0 ? "wing left" : "wing right", pivot: Vec3(side * 0.012, 0, 0))
            b.with(part: wing) {
                $0.sheet([Vec3(side * 0.012, 0, 0.022), Vec3(side * 0.07, 0, 0.012), Vec3(side * 0.13, 0, -0.03),
                          Vec3(side * 0.06, 0, -0.035), Vec3(side * 0.012, 0, -0.02)], normal: Vec3(0, 1, 0), thickness: 0.003,
                         color: colour)
            }
        }
        let parts = rig.count
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in
            var p = Pose(count: parts)
            let u = clip.progress(at: time)
            // Beats, then a glide, at idle; steady beats on the wing.
            let beats: Float = clip == .idle ? 12 : clip == .march ? 4 : 3
            let glide = clip == .idle ? Motion.key(u, [(0, 1), (0.6, 1), (0.7, 0.15), (0.9, 0.15), (1, 1)]) : 1
            let flap = 0.75 * glide * Motion.wave(u, cycles: beats) + 0.1
            p.turn(1, z: flap)
            p.turn(2, z: -flap)
            return p.joints
        }
    }

    /// The builders' stores: a stack of sawn timber on two bearers and a
    /// pile of squared stone blocks, a mallet laid on top.
    static func materials() -> Mesh {
        var b = MeshBuilder()
        b.with(surface: .timber) {
            for x in [Float(-0.05), 0.05] {
                $0.box(center: Vec3(x, 0.006, 0), size: Vec3(0.02, 0.012, 0.16), color: Palette.timberDark)
            }
            for layer in 0..<3 {
                for plank in 0..<(4 - layer) {
                    let x = (Float(plank) - Float(3 - layer) / 2) * 0.03
                    $0.box(center: Vec3(x - 0.06, 0.02 + Float(layer) * 0.02, 0), size: Vec3(0.026, 0.018, 0.18), color: Palette.timberPale)
                }
            }
        }
        b.with(surface: .stone) {
            let blocks: [Vec3] = [Vec3(0.07, 0.016, -0.04), Vec3(0.11, 0.016, -0.04), Vec3(0.07, 0.016, 0.0), Vec3(0.11, 0.016, 0.0),
                                  Vec3(0.09, 0.048, -0.02), Vec3(0.09, 0.016, 0.04)]
            for at in blocks {
                $0.box(center: at, size: Vec3(0.038, 0.032, 0.036), color: Palette.stonePale)
            }
        }
        b.box(center: Vec3(0.09, 0.07, -0.02), size: Vec3(0.012, 0.012, 0.06), color: Palette.timberDark)
        return b.mesh
    }

    /// A fisher's boat: a clinker hull of dark planks, thwarts and a net
    /// heaped in the stern, its fisher on the middle thwart at the oars, and
    /// a lantern hung from a pole at the bow, lit. Keyed at idle: the hull
    /// rocks and heaves on the swell, the oars dip and pull, the fisher
    /// leans into each stroke, the lantern swings on its hook.
    static func boat(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        let hull = rig.add("hull", pivot: Vec3(0, 0, 0))
        let fisher = rig.add("fisher", parent: Int(hull), pivot: Vec3(0, 0.05, -0.01))
        let oarL = rig.add("oar left", parent: Int(fisher), pivot: Vec3(0.07, 0.06, 0.0))
        let oarR = rig.add("oar right", parent: Int(fisher), pivot: Vec3(-0.07, 0.06, 0.0))
        let lantern = rig.add("lantern", parent: Int(hull), pivot: Vec3(0, 0.2, 0.2))
        b.with(part: hull) {
            // The hull: a long lathe flattened, its strakes darker toward the keel.
            $0.place(.rotationX(.pi / 2) * .scale(Vec3(1, 1, 0.55))) {
                $0.lathe([(0, -0.22), (0.04, -0.2), (0.07, -0.12), (0.08, 0), (0.07, 0.12), (0.045, 0.2), (0, 0.24)], sides: 10,
                         color: Palette.timberDark)
            }
            $0.box(center: Vec3(0, 0.03, 0), size: Vec3(0.11, 0.008, 0.36), color: Palette.timber)
            for z in [Float(-0.1), 0.0, 0.12] {
                $0.box(center: Vec3(0, 0.04, z), size: Vec3(0.13, 0.01, 0.025), color: Palette.timberPale)
            }
            $0.rock(center: Vec3(0, 0.045, -0.15), size: Vec3(0.04, 0.02, 0.035), rings: 2, sides: 5, jitter: 0.2, seed: 3, color: Palette.linen * 0.6)
            $0.limb(from: Vec3(0, 0.03, 0.18), to: Vec3(0, 0.22, 0.22), radius: 0.004, sides: 4, color: Palette.timberDark)
        }
        b.with(part: lantern) {
            $0.limb(from: Vec3(0, 0.22, 0.22), to: Vec3(0, 0.19, 0.22), radius: 0.002, sides: 3, color: Palette.iron)
            $0.box(center: Vec3(0, 0.175, 0.22), size: Vec3(0.022, 0.03, 0.022), color: Palette.iron)
            $0.with(material: .glow) {
                $0.box(center: Vec3(0, 0.175, 0.22), size: Vec3(0.016, 0.022, 0.024), color: Palette.candle)
            }
        }
        b.with(part: fisher) {
            // Hunched in a hooded coat on the thwart.
            $0.place(.translation(Vec3(0, 0.04, -0.01))) {
                $0.tube([(0.035, 0), (0.04, 0.04), (0.03, 0.09), (0, 0.11)], sides: 6, color: Palette.woolDark)
            }
            $0.sphere(center: Vec3(0, 0.165, 0.0), radius: 0.022, rings: 3, sides: 6, color: Palette.skin)
            $0.place(.translation(Vec3(0, 0.15, -0.006))) {
                $0.tube([(0.028, 0), (0.026, 0.03), (0, 0.05)], sides: 6, color: Palette.wool)
            }
            for side in [Float(1), -1] {
                $0.limb(from: Vec3(0.03 * side, 0.12, 0), to: Vec3(0.07 * side, 0.08, 0.04), radius: 0.008, sides: 4, color: Palette.woolDark)
            }
        }
        for (part, side) in [(oarL, Float(1)), (oarR, -1)] {
            b.with(part: part) {
                $0.limb(from: Vec3(0.05 * side, 0.08, 0.04), to: Vec3(0.26 * side, -0.01, 0.0), radius: 0.004, sides: 4, color: Palette.timberPale)
                $0.box(center: Vec3(0.27 * side, -0.012, 0.0), size: Vec3(0.05, 0.004, 0.02), color: Palette.timberPale)
            }
        }
        let parts = rig.count
        let rowing = Keyed(loops: true, [
            // A stroke each half-period: dip, pull, lift, swing forward.
            Track(oarL, [k(0, 0, -0.5, 0.2), k(0.15, 0, 0.0, 0.25), k(0.3, 0, 0.5, 0.15), k(0.4, 0, 0.45, -0.1), k(0.5, 0, -0.5, 0.2),
                         k(0.65, 0, 0.0, 0.25), k(0.8, 0, 0.5, 0.15), k(0.9, 0, 0.45, -0.1)]),
            Track(oarR, [k(0, 0, 0.5, -0.2), k(0.15, 0, 0.0, -0.25), k(0.3, 0, -0.5, -0.15), k(0.4, 0, -0.45, 0.1), k(0.5, 0, 0.5, -0.2),
                         k(0.65, 0, 0.0, -0.25), k(0.8, 0, -0.5, -0.15), k(0.9, 0, -0.45, 0.1)]),
            Track(fisher, [k(0, 0.25), k(0.3, -0.2), k(0.42, -0.1), k(0.5, 0.25), k(0.8, -0.2), k(0.92, -0.1)]),
            // The swell under it: a slow heave, a roll, a pitch.
            Track(hull, .shift, [k(0, 0, 0.006), k(0.25, 0, -0.004), k(0.5, 0, 0.006), k(0.75, 0, -0.004)]),
            Track(hull, [k(0, 0.03, 0, 0.05), k(0.25, -0.02, 0, -0.01), k(0.5, -0.03, 0, -0.05), k(0.75, 0.02, 0, 0.01)]),
            Track(lantern, [k(0, 0.12, 0, -0.08), k(0.25, -0.05, 0, 0.1), k(0.5, -0.12, 0, 0.08), k(0.75, 0.05, 0, -0.1)]),
        ])
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in
            var p = Pose(count: parts)
            rowing.apply(&p, clip.progress(at: time))
            return p.joints
        }
    }

    /// A carter's two-wheeled cart, its load under canvas, its wheels
    /// turning on the march.
    static func cart(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        // One turn of the wheels each march period covers a man's march.
        let radius = Gait(hands: .spear).marchSpeed * Clip.march.period / (2 * .pi)
        let axle = Vec3(0, radius, -0.02)
        b.box(min: Vec3(-0.085, radius + 0.02, -0.15), max: Vec3(0.085, radius + 0.04, 0.12), color: Palette.timberPale)
        for x in [Float(-0.088), 0.088] {
            b.box(min: Vec3(x - 0.006, radius + 0.04, -0.15), max: Vec3(x + 0.006, radius + 0.09, 0.12), color: Palette.timber)
            b.beam(from: Vec3(x * 0.8, radius + 0.03, 0.12), to: Vec3(x * 0.5, radius - 0.01, 0.32), width: 0.012, color: Palette.timber)
        }
        b.with(material: .house) {
            $0.place(.translation(Vec3(0, radius + 0.04, -0.015)) * .scale(Vec3(1, 1, 1.5))) {
                $0.lathe([(0.08, 0), (0.075, 0.05), (0.04, 0.09), (0, 0.1)], sides: 6, color: Palette.house)
            }
        }
        b.prism(sides: 6, radius: 0.03, from: radius + 0.04, to: radius + 0.11, color: Palette.timber)
        for side in [Float(1), -1] {
            let hub = axle + Vec3(side * 0.1, 0, 0)
            let wheel = rig.add(side > 0 ? "wheel left" : "wheel right", pivot: hub)
            b.with(part: wheel) {
                $0.wheel(center: hub, radius: radius, width: 0.018, spokes: 3, color: Palette.timber, rim: Palette.timberDark)
            }
        }
        let parts = rig.count
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in
            var p = Pose(count: parts)
            if clip == .march {
                let angle = 2 * Float.pi * clip.progress(at: time)
                p.turn(1, x: angle)
                p.turn(2, x: angle)
            }
            return p.joints
        }
    }

    /// An iron brazier on three legs, its fire leaping.
    static func brazier(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        for index in 0..<3 {
            let foot = MeshBuilder.ring(0.07, 0, Float(index) * 2 * .pi / 3)
            b.limb(from: foot, to: Vec3(foot.x * 0.4, 0.14, foot.z * 0.4), radius: 0.008, sides: 3, color: Palette.iron)
        }
        b.with(material: .metal) {
            $0.place(.translation(Vec3(0, 0.13, 0))) {
                $0.lathe([(0.03, 0), (0.07, 0.05), (0.075, 0.06)], sides: 7, color: Palette.iron)
            }
        }
        let fire = rig.add("fire", pivot: Vec3(0, 0.17, 0))
        b.with(part: fire, material: .glow) {
            $0.place(.translation(Vec3(0, 0.165, 0))) {
                $0.cone(sides: 5, radius: 0.055, to: 0.12, color: Palette.fire)
                $0.cone(sides: 4, radius: 0.028, from: 0.02, to: 0.17, color: Palette.candle, twist: 0.4)
            }
        }
        let motion = Machinery(flames: [fire], parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in motion.joints(clip, time) }
    }

    /// A puff of smoke: three soft balls that, at idle, rise and spread
    /// once a period, for the renderer to fade as they go.
    static func puff(name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        let cloud = rig.add("cloud", pivot: .zero)
        b.with(part: cloud) {
            $0.sphere(center: Vec3(0, 0.04, 0), radius: 0.045, rings: 3, sides: 5, color: Palette.smoke)
            $0.sphere(center: Vec3(0.035, 0.03, 0.015), radius: 0.032, rings: 2, sides: 5, color: Palette.smoke)
            $0.sphere(center: Vec3(-0.03, 0.055, -0.01), radius: 0.03, rings: 2, sides: 5, color: Palette.smoke)
        }
        let parts = rig.count
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in
            var p = Pose(count: parts)
            let u = clip.progress(at: time)
            // Rises and grows over most of the period; shrinks back to its start at the end, unseen.
            let life = Motion.key(u, [(0, 0), (0.92, 1), (1, 0)])
            p.shift(cloud, Vec3(0.03 * life, 0.35 * life, 0))
            p.stretch(cloud, 0.6 + 1.6 * life)
            return p.joints
        }
    }
}
