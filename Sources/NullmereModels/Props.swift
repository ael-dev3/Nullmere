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
        }
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
