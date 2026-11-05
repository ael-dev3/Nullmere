import Foundation

/// The parts a Mangonel adds to its crewman: the engine itself, which is
/// his extra part, its wheels, its throwing arm and the stone in its cup.
enum Engine {
    static let body = Limb.extra
    static let wheelL = Cart.wheelL
    static let wheelR = Cart.wheelR
    static let arm: UInt16 = 19
    static let stone: UInt16 = 20

    /// How the crewman walks behind it, leaning into its shafts.
    static let gait = Gait(hands: .cart, stride: 0.4, parts: Limb.count + 4)
    /// How far the arm swings from where it lies cocked to the stop bar.
    static let throwAngle: Float = 1.75
    /// Where it lies cocked, back over the frame from upright, its cup
    /// above the shafts.
    static let rest: Float = -1.2

    /// A crewman behind a two-wheeled mangonel he pushes like a barrow: a
    /// frame of timber on its wheels, a skein of twisted rope across it, a
    /// long arm lying cocked back with a stone in its cup, and a stop bar
    /// on its posts for the arm to strike. A bed of planks and iron bands
    /// from the second tier, a mantlet before it from the third, in the
    /// House's colours from the fourth; at the fifth a great engine,
    /// longer in the frame and the arm, its stop bar higher, gilt and
    /// flying a pennon.
    static func mangonel(tier: Int, name: String) -> Model {
        var f = Frame()
        f.extraParent = Limb.root
        let great = tier >= 5
        let wheel = Figures.cartWheel(gait)
        // Its measures, in the body's units from the crewman's feet: where
        // the arm turns in its skein, how long it is, where the bar it
        // strikes stands, and where the frame ends before.
        let pivot = Vec3(0, wheel + 0.13, great ? 0.85 : 0.7)
        let length: Float = great ? 0.74 : 0.62
        let front: Float = great ? 1.42 : 1.25
        let axle = Vec3(0, wheel, front - 0.2)
        // The bar stands where the arm, thrown, passes over it.
        let barZ: Float = pivot.z + (great ? 0.32 : 0.25)
        let barY = pivot.y + (barZ - pivot.z) / Float(tan(Double(throwAngle + rest)))
        f.extraPivot = Vec3(0, wheel, pivot.z)
        let cup = pivot + Vec3(0, Float(cos(Double(rest))), Float(sin(Double(rest)))) * length
        let more: [(name: String, parent: UInt16, pivot: Vec3)] = [
            ("wheel left", Engine.body, axle + Vec3(0.26, 0, 0)), ("wheel right", Engine.body, axle + Vec3(-0.26, 0, 0)),
            ("arm", Engine.body, pivot), ("stone", Engine.arm, cup),
        ]
        let timber = tier >= 4 ? Palette.timberDark : Palette.timber
        let band = great ? Palette.gold : Palette.iron
        let rail = wheel + 0.05
        var b = MeshBuilder()
        b.place(.scale(f.size)) { b in
            Person.body(&b, f, crewOutfit(tier))
            Person.mattock(&b, f)
            let grip = f.grip
            b.with(part: Engine.body) {
                // Shafts from the hands forward to the frame's tail.
                for side in [Float(1), -1] {
                    $0.beam(from: Vec3(side * f.shoulderX, grip, 0.05), to: Vec3(side * 0.18, rail + 0.04, 0.36), width: 0.03, color: timber)
                }
                // The frame: two rails and the beams across them.
                for side in [Float(1), -1] {
                    $0.box(min: Vec3(side * 0.2 - 0.03, rail, 0.34), max: Vec3(side * 0.2 + 0.03, rail + 0.07, front), color: timber)
                }
                for z in [Float(0.38), front - 0.05] {
                    $0.box(min: Vec3(-0.17, rail + 0.01, z - 0.03), max: Vec3(0.17, rail + 0.06, z + 0.03), color: Palette.timberPale)
                }
                if tier >= 2 {
                    // A bed of planks for the stones, boarded at its sides.
                    $0.box(min: Vec3(-0.17, rail + 0.02, 0.42), max: Vec3(0.17, rail + 0.04, front - 0.09), color: Palette.timberPale)
                    for side in [Float(1), -1] {
                        $0.box(min: Vec3(side * 0.2 - 0.015, rail + 0.07, 0.4), max: Vec3(side * 0.2 + 0.015, rail + 0.15, front - 0.1),
                               color: Palette.timberPale)
                    }
                }
                // The skein of twisted rope the arm turns in.
                $0.place(.translation(pivot) * .rotationZ(.pi / 2)) {
                    $0.prism(sides: 6, radius: 0.05, from: -0.17, to: 0.17, color: Palette.linen)
                }
                // Posts and the padded stop bar the arm strikes.
                for side in [Float(1), -1] {
                    $0.beam(from: Vec3(side * 0.2, rail + 0.07, barZ + 0.07), to: Vec3(side * 0.17, barY + 0.01, barZ), width: 0.035, color: timber)
                    $0.beam(from: Vec3(side * 0.2, rail + 0.07, pivot.z + 0.02), to: Vec3(side * 0.17, barY - 0.05, barZ - 0.02),
                            width: 0.025, color: timber)
                }
                $0.box(min: Vec3(-0.19, barY - 0.03, barZ - 0.03), max: Vec3(0.19, barY + 0.04, barZ + 0.04), color: Palette.timberPale)
                let padding = { (m: inout MeshBuilder) in
                    m.box(min: Vec3(-0.12, barY - 0.05, barZ - 0.05), max: Vec3(0.12, barY + 0.06, barZ - 0.02),
                          color: tier >= 4 ? Palette.house : Palette.canvas)
                }
                if tier >= 4 { $0.with(material: .house) { padding(&$0) } } else { padding(&$0) }
                if tier >= 2 {
                    // Iron (gilt, at the fifth) bound about the rails.
                    for z in [Float(0.55), front - 0.2] {
                        $0.with(material: .metal) {
                            for side in [Float(1), -1] {
                                $0.box(min: Vec3(side * 0.2 - 0.035, rail - 0.005, z - 0.02),
                                       max: Vec3(side * 0.2 + 0.035, rail + 0.075, z + 0.02), color: band)
                            }
                        }
                    }
                }
                if tier >= 3 {
                    // A mantlet of planks before it, to stand behind under the walls.
                    let mantlet = { (m: inout MeshBuilder) in
                        m.box(min: Vec3(-0.25, rail + 0.07, front + 0.02), max: Vec3(0.25, great ? 0.6 : 0.5, front + 0.06),
                              color: tier >= 4 ? Palette.house : Palette.timberPale)
                    }
                    if tier >= 4 { $0.with(material: .house) { mantlet(&$0) } } else { mantlet(&$0) }
                }
                if great {
                    $0.beam(from: Vec3(0.17, barY + 0.04, barZ), to: Vec3(0.17, barY + 0.32, barZ), width: 0.02, color: Palette.timberDark)
                    $0.flag(at: Vec3(0.17, barY + 0.32, barZ), width: 0.16, height: 0.09, turn: .pi / 2)
                }
            }
            // The arm, lying cocked, its cup at the end.
            b.with(part: Engine.arm) {
                $0.beam(from: pivot, to: cup, width: 0.045, color: timber)
                $0.box(center: cup, size: Vec3(0.11, 0.035, 0.11), color: Palette.leather)
            }
            b.with(part: Engine.stone) {
                $0.rock(center: cup + Vec3(0, 0.05, 0), size: Vec3(0.05, 0.045, 0.05), rings: 2, sides: 5, jitter: 0.12, seed: 7,
                        color: Palette.stone)
            }
            for (part, x) in [(Engine.wheelL, Float(0.26)), (Engine.wheelR, -0.26)] {
                b.with(part: part) {
                    $0.wheel(center: axle + Vec3(x, 0, 0), radius: wheel, width: 0.04, spokes: 2, color: timber,
                             rim: tier >= 4 ? Palette.iron : nil)
                    $0.fine {
                        // Close, a true wheel: eight spokes about a hub, its felloes shod in iron.
                        $0.wheel(center: axle + Vec3(x, 0, 0), radius: wheel * 1.02, width: 0.046, spokes: 4, color: timber, rim: Palette.iron)
                        $0.place(.translation(axle + Vec3(x, 0, 0)) * .rotationZ(.pi / 2)) {
                            $0.lathe([(0.035, -0.04), (0.04, -0.02), (0.04, 0.02), (0.03, 0.045)], sides: 10, color: Palette.timberDark)
                        }
                    }
                }
            }
            detail(&b, tier: tier, pivot: pivot, rail: rail, front: front, barZ: barZ, cup: cup, band: band, timber: timber)
        }
        return Model(name: name, mesh: b.mesh, rig: f.rig(more: more)) { clip, time in joints(clip, time) }
    }

    /// The Mangonel close: its skein wound in turns of rope and set in iron
    /// washers, the frame's joints lashed and bolted, the winch at its tail,
    /// the mantlet's planks and battens, the arm banded, its cup laced, the
    /// stone in it rounded.
    static func detail(_ b: inout MeshBuilder, tier: Int, pivot: Vec3, rail: Float, front: Float, barZ: Float, cup: Vec3, band: Vec3,
                       timber: Vec3) {
        let great = tier >= 5
        b.fine {
            $0.with(part: Engine.body) {
                // The skein wound in its turns of rope, and the iron washers it is twisted in.
                $0.place(.translation(pivot) * .rotationZ(.pi / 2)) {
                    for turn in 0..<7 {
                        let y = -0.15 + Float(turn) * 0.05
                        $0.lathe([(0.052, y), (0.058, y + 0.02), (0.052, y + 0.04)], sides: 10, color: Palette.linen * (turn % 2 == 0 ? 1 : 0.85))
                    }
                    $0.with(material: .metal) {
                        for y: Float in [-0.19, 0.17] {
                            $0.lathe([(0.075, y), (0.075, y + 0.02)], sides: 12, color: Palette.iron)
                        }
                    }
                }
                // Rope lashed round the joints of the frame, and the bolts through it.
                for side in [Float(1), -1] {
                    for z in [Float(0.38), front - 0.05, barZ + 0.07] {
                        $0.place(.translation(Vec3(side * 0.2, rail + 0.035, z))) {
                            $0.lathe([(0.04, -0.012), (0.044, 0), (0.04, 0.012)], sides: 8, color: Palette.linen * 0.8)
                        }
                    }
                    $0.with(material: .metal) {
                        for z in stride(from: Float(0.42), to: front - 0.04, by: 0.09) {
                            $0.sphere(center: Vec3(side * 0.232, rail + 0.035, z), radius: 0.009, rings: 2, sides: 5, color: Palette.iron)
                        }
                    }
                }
                // The winch at the tail that winds the arm down: its drum, rope and crank.
                $0.place(.translation(Vec3(0, rail + 0.11, 0.44)) * .rotationZ(.pi / 2)) {
                    $0.lathe([(0.04, -0.16), (0.04, 0.16)], sides: 10, color: Palette.timberPale)
                    $0.lathe([(0.046, -0.08), (0.046, 0.08)], sides: 10, color: Palette.linen * 0.85)
                }
                for side in [Float(1), -1] {
                    $0.beam(from: Vec3(side * 0.18, rail + 0.07, 0.44), to: Vec3(side * 0.18, rail + 0.16, 0.44), width: 0.03, color: timber)
                }
                $0.with(material: .metal) {
                    $0.beam(from: Vec3(0.2, rail + 0.11, 0.44), to: Vec3(0.24, rail + 0.06, 0.44), width: 0.012, color: Palette.iron)
                }
                $0.limb(from: Vec3(0, rail + 0.15, 0.44), to: pivot + Vec3(0, 0.03, 0.06), radius: 0.006, sides: 3, color: Palette.linen)
                if tier >= 3 {
                    // The mantlet's planks and their battens.
                    for x in stride(from: Float(-0.2), through: 0.2, by: 0.1) {
                        $0.box(center: Vec3(x, (rail + 0.07 + (great ? 0.6 : 0.5)) / 2, front + 0.064),
                               size: Vec3(0.004, (great ? 0.6 : 0.5) - rail - 0.09, 0.004), color: Palette.timberDark)
                    }
                    for y: Float in [rail + 0.14, (great ? 0.6 : 0.5) - 0.07] {
                        $0.box(center: Vec3(0, y, front + 0.068), size: Vec3(0.48, 0.03, 0.012), color: timber)
                    }
                }
            }
            $0.with(part: Engine.arm) {
                // The arm's iron bands, and the cup's rope lashing.
                $0.with(material: .metal) {
                    for t in [Float(0.25), 0.55, 0.8] {
                        let at = pivot + (cup - pivot) * t
                        $0.box(center: at, size: Vec3(0.055, 0.055, 0.02), color: band)
                    }
                }
                $0.place(.translation(cup + Vec3(0, 0.01, 0))) {
                    $0.lathe([(0.064, 0), (0.06, 0.03), (0.045, 0.034)], sides: 10, color: Palette.leather)
                }
            }
            $0.with(part: Engine.stone) {
                $0.rock(center: cup + Vec3(0, 0.05, 0), size: Vec3(0.054, 0.05, 0.054), rings: 4, sides: 8, jitter: 0.1, seed: 11,
                        color: Palette.stone)
            }
        }
    }

    /// The crew's dress by tier: a padded coat and a hood; leather and a
    /// cap; mail and a helm; plate; plate with gilt on the shoulders.
    static func crewOutfit(_ tier: Int) -> Outfit {
        var o = Outfit()
        o.belt = (Palette.house, .house)
        switch tier {
        case 1:
            o.tunic = Palette.padded
            o.sleeves = Palette.padded
            o.head = .hood(Palette.wool, .plain)
        case 2:
            o.tunic = Palette.leather
            o.sleeves = Palette.padded
            o.head = .cap(Palette.leatherDark)
        case 3:
            o.tunic = Palette.mail
            o.tunicMaterial = .metal
            o.sleeves = Palette.leather
            o.head = .nasal
        default:
            o.tunic = Palette.steel
            o.tunicMaterial = .metal
            o.sleeves = Palette.mail
            o.sleevesMaterial = .metal
            o.head = .kettle
            if tier >= 5 { o.pauldrons = (Palette.gold, .metal) }
        }
        return o
    }

    /// How a Mangonel moves: its crewman walks, works and falls as one at a
    /// cart's shafts does, its wheels rolling on the march. Striking, he
    /// pulls the pin and the arm flies up to the stop bar, its stone gone,
    /// then he winds it back down and lays another stone in its cup; at
    /// rest the arm creaks in its skein. Struck, the engine settles askew
    /// where it stands, its arm slack.
    static func joints(_ clip: Clip, _ time: Float) -> [Joint] {
        let u = clip.progress(at: time)
        var p = Pose(count: gait.parts)
        p.hide(Limb.tool)
        switch clip {
        case .idle:
            gait.idle(&p, u)
            p.turn(arm, x: 0.015 * Motion.wave(u, cycles: 2))
        case .march:
            gait.march(&p, u)
        case .gather:
            gait.gather(&p, u)
        case .death:
            gait.death(&p, u)
            let fall = Motion.key(u, [(0, 0), (0.3, 0), (0.8, 1), (1, 1)])
            p.turn(body, x: -0.05 * fall, z: 0.14 * fall)
            p.shift(body, Vec3(0, -0.012 * gait.size * fall, 0))
            p.turn(arm, x: 0.35 * fall)
        case .hit:
            // A stone or a charge into the frame: it jolts and rocks on its
            // wheels, the arm jumping in its skein, its crewman ducking.
            gait.hit(&p, u)
            let r = Gait.recoil(u)
            p.turn(body, x: 0.08 * r, z: -0.1 * r * Motion.wave(u, cycles: 2))
            p.shift(body, Vec3(0, 0.01 * gait.size * r, -0.02 * gait.size * r))
            p.turn(arm, x: 0.25 * r)
            p.turn(Limb.torso, x: 0.6 * r)
        case .attack:
            gait.idle(&p, u)
            // The pin pulled, the arm flies; then wound back down.
            let fly = Motion.key(u, [(0, 0), (0.22, 0), (0.3, 1), (0.42, 1), (0.9, 0), (1, 0)])
            p.turn(arm, x: throwAngle * fly)
            // The stone goes with the throw, and another is laid in once the arm is down.
            if u > 0.27 && u < 0.92 { p.hide(stone) }
            // The crewman pulls back on the pin, then bends to the winch.
            let pull = Motion.key(u, [(0, 0), (0.16, 1), (0.26, 1), (0.34, 0), (1, 0)])
            let wind = Motion.key(u, [(0, 0), (0.42, 0), (0.5, 1), (0.84, 1), (0.92, 0), (1, 0)])
            let crank = Motion.wave(u, cycles: 6) * wind
            p.turn(Limb.torso, x: 0.3 * wind - 0.1 * pull)
            p.turn(Limb.armR, x: -0.5 * pull - 0.7 * wind - 0.35 * crank)
            p.turn(Limb.armL, x: -0.5 * pull - 0.7 * wind + 0.35 * crank)
            p.turn(Limb.forearmR, x: -0.4 * pull - 0.5 * wind)
            p.turn(Limb.forearmL, x: -0.4 * pull - 0.5 * wind)
            p.turn(Limb.thighL, x: -0.25 * wind)
            p.turn(Limb.shinL, x: 0.35 * wind)
        }
        return p.joints
    }
}
