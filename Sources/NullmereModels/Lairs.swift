import Foundation
import NullmereCore

/// The lairs of the wilds, each filling the heart of its hex: a salt hollow
/// bristling with spars, a stockade of the Reavers round its fire, the hall
/// of a barrow under its mound, a hunters' eyrie on its rock, and a drowned
/// chapel half sunk in the strand. Each has a light of its own that burns
/// all night: firelight for the living, the wilds' pale glow for the rest.
enum Lairs {
    static func build(_ kind: WildKind, name: String) -> Model {
        var b = MeshBuilder()
        switch kind {
        case .saltwights: saltHollow(&b)
        case .reavers: stockade(&b)
        case .barrowkin: barrowHall(&b)
        case .spineHunters: eyrie(&b)
        case .drowned: chapel(&b)
        }
        b.fine { near in
            switch kind {
            case .saltwights: hollowNear(&near)
            case .reavers: stockadeNear(&near)
            case .barrowkin: barrowNear(&near)
            case .spineHunters: eyrieNear(&near)
            case .drowned: chapelNear(&near)
            }
        }
        return Model(name: name, mesh: b.mesh)
    }

    // MARK: A gate of the Crown

    /// A gate of the Marches' Crown as the Spine Hunters hold it: two squat
    /// towers of rough stone either side of the pass, a gate of sharpened
    /// stakes between them under a lintel of logs, hides hung from their
    /// tops, rubble fallen from the peaks about their feet, and the
    /// hunters' fire before it. The way through runs along z.
    static func gatehold(name: String) -> Model {
        var b = MeshBuilder()
        for side in [Float(-1), 1] {
            let x = side * 0.3
            // A tower, a little narrower as it rises, its top ringed with
            // merlons.
            b.place(.translation(Vec3(x, 0, 0)) * .rotationY(side * 0.4)) {
                $0.lathe([(0.13, -0.04), (0.13, 0.0), (0.11, 0.34), (0.12, 0.36), (0.12, 0.38), (0.0, 0.38)], sides: 7,
                         color: Palette.stone, twist: 0.12)
                for index in 0..<4 {
                    let angle = Float(index) * .pi / 2 + 0.3
                    $0.box(center: MeshBuilder.ring(0.095, 0.41, angle), size: Vec3(0.045, 0.06, 0.045), color: Palette.stoneDark)
                }
            }
            // A hide hung from its top, toward the pass.
            b.sheet([Vec3(x - side * 0.1, 0.34, 0.06), Vec3(x - side * 0.1, 0.34, -0.06), Vec3(x - side * 0.12, 0.16, -0.05),
                     Vec3(x - side * 0.12, 0.17, 0.05)], normal: Vec3(-side, 0, 0), color: Palette.leather)
            // Rubble fallen from the peaks.
            b.rock(center: Vec3(x + side * 0.14, 0.03, 0.12), size: Vec3(0.1, 0.07, 0.09), rings: 2, sides: 5, jitter: 0.22,
                   seed: side > 0 ? 41 : 42, color: Palette.rock)
        }
        // The gate of stakes across the pass, and the lintel above it.
        for index in 0..<7 {
            let x = Float(index) * 0.06 - 0.18
            let lean = index % 2 == 0 ? Float(0.02) : -0.02
            b.limb(from: Vec3(x, -0.02, 0), to: Vec3(x + lean, 0.22, 0), radius: 0.016, topRadius: 0.012, color: Palette.timber)
            b.place(.translation(Vec3(x + lean, 0.22, 0))) { $0.cone(sides: 4, radius: 0.012, to: 0.04, color: Palette.timberPale) }
        }
        b.beam(from: Vec3(-0.21, 0.31, 0), to: Vec3(0.21, 0.31, 0), width: 0.03, color: Palette.timberDark)
        b.limb(from: Vec3(-0.19, 0.12, 0.012), to: Vec3(0.19, 0.12, 0.012), radius: 0.01, color: Palette.timberDark)
        // The hunters' fire before the gate, and a spear stood by it.
        fire(&b, at: Vec3(0.12, 0.0, 0.26), size: 0.05)
        b.limb(from: Vec3(-0.08, 0.0, 0.3), to: Vec3(-0.06, 0.34, 0.31), radius: 0.006, color: Palette.timberDark)
        b.with(material: .metal) {
            $0.place(.translation(Vec3(-0.06, 0.34, 0.31))) { $0.cone(sides: 4, radius: 0.012, to: 0.05, color: Palette.iron) }
        }
        b.fine { gateholdNear(&$0) }
        return Model(name: name, mesh: b.mesh)
    }

    /// Where smoke rises from a gatehold's fire, in its own frame.
    static let gateFire = Vec3(0.12, 0.08, 0.26)

    /// Where smoke rises from a lair's fire, in its own frame.
    static func fire(of kind: WildKind) -> Vec3? {
        switch kind {
        case .reavers: return Vec3(0, 0.12, 0.02)
        case .spineHunters: return Vec3(-0.12, 0.32, 0.1)
        case .saltwights, .barrowkin, .drowned: return nil
        }
    }

    /// A fire of logs, its flames leaping.
    static func fire(_ b: inout MeshBuilder, at: Vec3, size: Float) {
        for index in 0..<4 {
            let angle = Float(index) * .pi / 2 + 0.4
            b.log(from: at + MeshBuilder.ring(size, -0.01, angle), to: at + MeshBuilder.ring(size * 0.2, size * 0.6, angle + 0.3),
                  radius: size * 0.16)
        }
        b.with(material: .glow) {
            $0.place(.translation(at)) {
                $0.lathe([(size * 0.55, 0), (size * 0.75, size * 0.5), (size * 0.35, size * 1.1), (0, size * 1.7)], sides: 6, color: Palette.fire)
            }
        }
    }

    /// A light of the wilds, pale and cold.
    static func wildLight(_ b: inout MeshBuilder, at: Vec3, size: Float) {
        b.with(material: .glow) {
            $0.sphere(center: at, radius: size, rings: 3, sides: 6, color: Palette.wildGlow)
        }
    }

    // MARK: The Saltwights' hollow

    static func saltHollow(_ b: inout MeshBuilder) {
        // A pit crusted white, its rim heaped up.
        b.lathe([(0.62, -0.1), (0.62, 0.02), (0.52, 0.09), (0.42, 0.05), (0.3, -0.04), (0.0, -0.06)], sides: 11, color: Palette.saltCrust,
                colors: [Palette.saltCrust, Palette.saltCrust, Palette.saltCrust, Palette.ash, Palette.loam, Palette.loam])
        // Spars of salt leaning out from the rim, the tallest by the pit.
        b.with(material: .crystal) {
            for index in 0..<9 {
                let angle = Float(index) / 9 * 2 * .pi + 0.2
                let lean = Vec3(Float(cos(Double(angle))) * 0.5, 1, -Float(sin(Double(angle))) * 0.5)
                let tall: Float = 0.18 + 0.16 * Noise.unit(Int32(index), 2, 41)
                $0.place(.translation(MeshBuilder.ring(0.47, 0.04, angle)) * Mat4.aligningUp(to: lean)) {
                    $0.prism(sides: 6, radius: 0.035, topRadius: 0.012, from: 0, to: tall, color: Palette.moonsalt)
                    $0.cone(sides: 6, radius: 0.012, from: tall, to: tall + 0.05, color: Palette.moonsalt)
                }
            }
        }
        // Bones about the pit, and its cold heart.
        for index in 0..<5 {
            let angle = Float(index) * 1.3 + 0.5
            let at = MeshBuilder.ring(0.2 + 0.05 * Float(index % 2), -0.03, angle)
            b.limb(from: at, to: at + MeshBuilder.ring(0.09, 0.01, angle + 1.2), radius: 0.008, color: Palette.bone)
        }
        wildLight(&b, at: Vec3(0, 0.0, 0), size: 0.07)
    }

    // MARK: The Reavers' stockade

    static func stockade(_ b: inout MeshBuilder) {
        b.lathe([(0.6, -0.1), (0.6, 0.0), (0.55, 0.012), (0.0, 0.015)], sides: 12, color: Palette.earth)
        // A ring of sharpened stakes, a gap for the gate toward +z.
        for index in 0..<22 {
            let angle = Float(index) / 22 * 2 * .pi
            let gate = abs(angle - 1.5 * .pi) < 0.25
            guard !gate else { continue }
            let foot = MeshBuilder.ring(0.53, -0.04, angle)
            let tall: Float = 0.26 + 0.05 * Noise.unit(Int32(index), 3, 17)
            b.limb(from: foot, to: foot + Vec3(0, tall, 0), radius: 0.022, color: index % 3 == 0 ? Palette.bark : Palette.timberDark)
            b.place(.translation(foot + Vec3(0, tall, 0))) { $0.cone(sides: 4, radius: 0.022, to: 0.06, color: Palette.timberPale) }
        }
        // Two hide tents, and a trophy pole hung with antlers.
        for (at, turn) in [(Vec3(-0.25, 0, -0.18), Float(0.4)), (Vec3(0.24, 0, -0.2), Float(-0.5))] {
            b.place(.translation(at) * .rotationY(turn)) {
                $0.cone(sides: 5, radius: 0.15, to: 0.24, color: Palette.leather)
                $0.box(min: Vec3(-0.03, 0, 0.11), max: Vec3(0.03, 0.08, 0.13), color: Palette.leatherDark)
            }
        }
        b.limb(from: Vec3(0.3, -0.02, 0.22), to: Vec3(0.3, 0.42, 0.22), radius: 0.012, color: Palette.timberDark)
        for side in [Float(-1), 1] {
            b.limb(from: Vec3(0.3, 0.4, 0.22), to: Vec3(0.3 + side * 0.07, 0.48, 0.2), radius: 0.007, color: Palette.bone)
            b.limb(from: Vec3(0.3 + side * 0.04, 0.44, 0.215), to: Vec3(0.3 + side * 0.06, 0.5, 0.25), radius: 0.005, color: Palette.bone)
        }
        // Their fire, ringed with stones.
        for index in 0..<7 {
            let angle = Float(index) / 7 * 2 * .pi
            b.rock(center: MeshBuilder.ring(0.11, 0.015, angle) + Vec3(0, 0, 0.02), size: Vec3(0.03, 0.025, 0.03), rings: 2, sides: 4,
                   jitter: 0.2, seed: UInt32(index + 70), color: Palette.stoneDark)
        }
        fire(&b, at: Vec3(0, 0.01, 0.02), size: 0.07)
    }

    // MARK: The Barrowkin's hall

    static func barrowHall(_ b: inout MeshBuilder) {
        // The mound, long and low, grassed over.
        b.place(.scale(Vec3(1.2, 1, 0.8))) {
            $0.lathe([(0.48, -0.1), (0.48, 0.0), (0.42, 0.12), (0.3, 0.22), (0.15, 0.27), (0.0, 0.28)], sides: 12, color: Palette.moss)
        }
        Land.grass(&b, at: Vec3(-0.2, 0.2, -0.1), tufts: 4, spread: 0.15, seed: 23)
        // Its kerb of stones, and the way in: dark between its posts.
        for index in 0..<10 {
            let angle = Float(index) / 10 * 2 * .pi + 0.15
            let at = Vec3(Float(cos(Double(angle))) * 0.6, 0.0, -Float(sin(Double(angle))) * 0.4)
            b.rock(center: at, size: Vec3(0.05, 0.05, 0.04), rings: 2, sides: 4, jitter: 0.25, seed: UInt32(index + 90), color: Palette.stone)
        }
        b.box(min: Vec3(-0.11, -0.04, 0.24), max: Vec3(-0.07, 0.2, 0.36), color: Palette.stoneDark)
        b.box(min: Vec3(0.07, -0.04, 0.24), max: Vec3(0.11, 0.2, 0.36), color: Palette.stoneDark)
        b.box(min: Vec3(-0.13, 0.2, 0.24), max: Vec3(0.13, 0.25, 0.37), color: Palette.stone)
        b.box(min: Vec3(-0.07, -0.02, 0.25), max: Vec3(0.07, 0.19, 0.27), color: Palette.barkBlack)
        // Standing stones beside it, and the cold light within.
        for (x, z, h) in [(Float(-0.42), Float(0.32), Float(0.32)), (0.45, 0.3, 0.26)] {
            b.place(.translation(Vec3(x, 0, z))) {
                $0.lathe([(0.05, -0.05), (0.055, h * 0.7), (0.0, h)], sides: 4, color: Palette.stoneDark, twist: 0.4)
            }
        }
        wildLight(&b, at: Vec3(0, 0.08, 0.3), size: 0.05)
    }

    // MARK: The Spine Hunters' eyrie

    static func eyrie(_ b: inout MeshBuilder) {
        // The rock it stands on.
        for (at, size, seed) in [(Vec3(0, 0.12, -0.05), Vec3(0.42, 0.24, 0.36), UInt32(5)),
                                 (Vec3(0.28, 0.06, 0.22), Vec3(0.2, 0.12, 0.18), 6), (Vec3(-0.32, 0.05, 0.2), Vec3(0.18, 0.1, 0.16), 7)] {
            b.rock(center: at, size: size, rings: 3, sides: 6, jitter: 0.18, seed: seed, color: Palette.rock)
        }
        // A platform of timber on posts above the rock, and a ladder up.
        let deck: Float = 0.4
        for (x, z) in [(Float(0.04), Float(-0.2)), (0.24, -0.2), (0.04, 0.0), (0.24, 0.0)] {
            b.limb(from: Vec3(x, 0.15, z), to: Vec3(x, deck + 0.12, z), radius: 0.012, color: Palette.timber)
        }
        b.box(min: Vec3(0.0, deck, -0.24), max: Vec3(0.28, deck + 0.02, 0.04), color: Palette.timberPale)
        b.ladder(from: Vec3(0.16, 0.0, 0.2), to: Vec3(0.14, deck, 0.04), width: 0.06, rungs: 5, color: Palette.timber)
        // Hide windbreaks on the deck, and pelts hung to dry.
        b.sheet([Vec3(0.0, deck, -0.24), Vec3(0.28, deck, -0.24), Vec3(0.28, deck + 0.12, -0.24), Vec3(0.0, deck + 0.14, -0.24)],
                normal: Vec3(0, 0, 1), color: Palette.leather)
        for x in [Float(0.06), 0.14, 0.22] {
            b.sheet([Vec3(x, deck + 0.1, 0.04), Vec3(x + 0.05, deck + 0.1, 0.04), Vec3(x + 0.04, deck + 0.02, 0.04), Vec3(x + 0.01, deck + 0.02, 0.04)],
                    normal: Vec3(0, 0, 1), color: Palette.fur)
        }
        // Their fire on the rock, and a spear stood by it.
        fire(&b, at: Vec3(-0.12, 0.25, 0.1), size: 0.05)
        b.limb(from: Vec3(-0.22, 0.2, 0.0), to: Vec3(-0.2, 0.52, 0.02), radius: 0.006, color: Palette.timberDark)
        b.with(material: .metal) {
            $0.place(.translation(Vec3(-0.2, 0.52, 0.02))) { $0.cone(sides: 4, radius: 0.012, to: 0.05, color: Palette.iron) }
        }
    }

    // MARK: The drowned chapel

    static func chapel(_ b: inout MeshBuilder) {
        // Still black water where its floor was.
        b.lathe([(0.6, -0.1), (0.6, -0.005), (0.0, -0.004)], sides: 12, color: Palette.loam)
        b.box(min: Vec3(-0.34, -0.02, -0.2), max: Vec3(0.34, 0.0, 0.26), color: Vec3(0.03, 0.04, 0.05))
        // Two pillars and what is left of their arch, one leaning.
        b.box(min: Vec3(-0.3, -0.05, -0.05), max: Vec3(-0.2, 0.5, 0.05), color: Palette.stonePale)
        b.place(.translation(Vec3(0.25, -0.05, 0)) * .rotationZ(-0.12)) {
            $0.box(min: Vec3(-0.05, 0, -0.05), max: Vec3(0.05, 0.42, 0.05), color: Palette.stonePale)
        }
        for index in 0..<5 {
            let angle = Float.pi - Float(index) * 0.32
            let at = Vec3(Float(cos(Double(angle))) * 0.25, 0.5 + Float(sin(Double(angle))) * 0.18, 0)
            b.box(center: at, size: Vec3(0.08, 0.06, 0.1), turn: 0, color: index % 2 == 0 ? Palette.stone : Palette.stonePale)
        }
        // Fallen stones, reeds through them, and pale lights over the water.
        for (index, at) in [Vec3(0.12, 0.02, 0.32), Vec3(-0.4, 0.02, 0.24), Vec3(0.42, 0.03, -0.22)].enumerated() {
            b.box(center: at, size: Vec3(0.12, 0.06, 0.08), turn: Float(index) * 0.7, color: Palette.stone)
        }
        Land.reeds(&b, at: Vec3(-0.42, 0, -0.3), count: 6, height: 0.2, seed: 31)
        Land.reeds(&b, at: Vec3(0.45, 0, 0.3), count: 5, height: 0.18, seed: 32)
        for (index, at) in [Vec3(-0.1, 0.22, 0.1), Vec3(0.12, 0.3, -0.08), Vec3(0.02, 0.16, 0.18)].enumerated() {
            wildLight(&b, at: at, size: 0.025 + 0.008 * Float(index))
        }
    }

    // MARK: Drawn near

    /// A skull, its face toward `facing` (radians about the vertical, as
    /// the ring's angles run), `size` its half-height.
    static func skull(_ b: inout MeshBuilder, at: Vec3, facing: Float, size: Float, color: Vec3 = Palette.bone) {
        b.place(.translation(at) * .rotationY(facing)) {
            $0.sphere(center: .zero, radius: size, rings: 3, sides: 6, color: color)
            for side in [Float(-1), 1] {
                $0.box(center: Vec3(size * 0.85, size * 0.15, side * size * 0.38), size: Vec3(size * 0.35, size * 0.3, size * 0.3),
                       color: Palette.barkBlack)
            }
            $0.box(center: Vec3(size * 0.5, -size * 0.75, 0), size: Vec3(size * 0.6, size * 0.4, size * 0.9), color: color)
        }
    }

    /// A pair of horns curling up and back from either side of `at`, along
    /// `side` across the head.
    static func horns(_ b: inout MeshBuilder, at: Vec3, side: Vec3, size: Float, color: Vec3) {
        for flank in [Float(-1), 1] {
            let root = at + side * (flank * size * 0.6)
            let bend = root + side * (flank * size * 1.2) + Vec3(0, size * 1.1, 0)
            b.limb(from: root, to: bend, radius: size * 0.28, topRadius: size * 0.18, sides: 4, color: color)
            b.limb(from: bend, to: bend + side * (flank * size * 0.2) + Vec3(0, size * 1.3, 0) - side.cross(.up) * (size * 0.6),
                   radius: size * 0.18, topRadius: size * 0.04, sides: 4, color: color)
        }
    }

    /// A raven perched, looking along `facing`.
    static func raven(_ b: inout MeshBuilder, at: Vec3, facing: Float, seed: UInt32) {
        b.place(.translation(at) * .rotationY(facing)) {
            $0.rock(center: Vec3(0, 0.016, 0), size: Vec3(0.021, 0.013, 0.012), rings: 3, sides: 5, jitter: 0.06, seed: seed,
                    color: Palette.barkBlack)
            $0.sphere(center: Vec3(0.018, 0.03, 0), radius: 0.009, rings: 3, sides: 5, color: Palette.barkBlack)
            $0.place(.translation(Vec3(0.025, 0.029, 0)) * .rotationZ(-.pi / 2)) {
                $0.cone(sides: 4, radius: 0.0035, to: 0.014, color: Palette.ash)
            }
            $0.sheet([Vec3(-0.017, 0.014, -0.007), Vec3(-0.017, 0.014, 0.007), Vec3(-0.042, 0.006, 0.006), Vec3(-0.042, 0.006, -0.006)],
                     normal: .up, color: Palette.barkBlack)
            for z in [Float(-0.004), 0.004] {
                $0.limb(from: Vec3(0.002, 0.006, z), to: Vec3(0.004, 0.0, z), radius: 0.0012, sides: 3, color: Palette.ash)
            }
        }
    }

    /// A headstone leaning in the grass, moss on its face.
    static func headstone(_ b: inout MeshBuilder, at: Vec3, turn: Float, lean: Float) {
        b.place(.translation(at) * .rotationY(turn) * .rotationX(lean)) {
            $0.box(center: Vec3(0, 0.035, 0), size: Vec3(0.05, 0.08, 0.014), color: Palette.stone)
            $0.place(.translation(Vec3(0, 0.075, 0)) * .rotationX(.pi / 2)) {
                $0.lathe([(0.025, -0.007), (0.025, 0.007)], sides: 6, color: Palette.stone)
            }
            $0.box(center: Vec3(-0.01, 0.012, 0.0075), size: Vec3(0.02, 0.016, 0.002), color: Palette.moss.mix(Palette.grass, 0.4))
        }
    }

    /// The Saltwights' hollow drawn near: a great beast's bones half sunk in
    /// its salt, the husks the wights crawl out of, moonsalt grown on its
    /// floor, skulls by its cold heart, and the arms of those who came for
    /// them, crusted white.
    static func hollowNear(_ b: inout MeshBuilder) {
        // The hollow's floor at a distance from its heart.
        func floor(_ radius: Float) -> Float {
            let profile: [(radius: Float, y: Float)] = [(0, -0.06), (0.3, -0.04), (0.42, 0.05), (0.52, 0.09), (0.62, 0.02)]
            for index in 1..<profile.count where radius <= profile[index].radius {
                let (low, high) = (profile[index - 1], profile[index])
                return low.y + (high.y - low.y) * (radius - low.radius) / (high.radius - low.radius)
            }
            return 0.02
        }
        func ground(_ x: Float, _ z: Float) -> Vec3 { Vec3(x, floor((x * x + z * z).squareRoot()), z) }
        let bone = Palette.bone.mix(Palette.saltCrust, 0.35)
        // The beast, slid into the hollow head first: its spine along the
        // floor, its ribs rising from it and curling in, its horned skull
        // at the head.
        let head = ground(-0.29, -0.23), tail = ground(-0.235, -0.02)
        let along = (tail - head).normalized
        let side = along.cross(.up).normalized
        for index in 0..<8 {
            let at = head + (tail - head) * (0.1 + 0.115 * Float(index)) + Vec3(0, 0.006, 0)
            b.rock(center: at, size: Vec3(0.013, 0.011, 0.013), rings: 2, sides: 4, jitter: 0.15, seed: UInt32(index + 200), color: bone)
        }
        for index in 0..<5 {
            let at = head + (tail - head) * (0.22 + 0.11 * Float(index)) + Vec3(0, 0.006, 0)
            let reach: Float = 0.085 - 0.008 * Float(index)
            for flank in [Float(-1), 1] {
                let out = side * flank
                let middle = at + out * (reach * 0.8) + Vec3(0, reach * 0.7, 0)
                b.limb(from: at + out * 0.01, to: middle, radius: 0.006, topRadius: 0.005, sides: 3, color: bone)
                b.limb(from: middle, to: at + out * (reach * 0.45) + Vec3(0, reach * 1.35, 0), radius: 0.005, topRadius: 0.003, sides: 3,
                       color: bone)
            }
        }
        let snout = Float(atan2(Double(along.z), Double(-along.x)))
        let crown = head - along * 0.03 + Vec3(0, 0.02, 0)
        b.place(.translation(crown) * .rotationY(snout)) {
            $0.rock(center: Vec3(0.012, 0, 0), size: Vec3(0.045, 0.024, 0.028), rings: 3, sides: 6, jitter: 0.08, seed: 211, color: bone)
            for flank in [Float(-1), 1] {
                $0.box(center: Vec3(0.018, 0.01, flank * 0.022), size: Vec3(0.012, 0.009, 0.006), color: Palette.barkBlack)
            }
        }
        horns(&b, at: crown + Vec3(0, 0.012, 0) + along * 0.012, side: side, size: 0.035, color: Palette.bone.mix(Palette.barkBlack, 0.35))
        // Husks the wights crawl out of, one split open along its back.
        let husk = Palette.bone.mix(Palette.shroud, 0.5)
        for (index, (x, z, turn)) in [(Float(0.08), Float(0.17), Float(0.4)), (0.22, -0.02, 0.6), (-0.25, 0.17, 2.4)].enumerated() {
            b.place(.translation(ground(x, z) + Vec3(0, 0.018, 0)) * .rotationY(turn) * .rotationZ(-.pi / 2 + 0.08)) {
                $0.lathe([(0.0, -0.055), (0.02, -0.045), (0.027, -0.01), (0.022, 0.03), (0.012, 0.05), (0.0, 0.058)], sides: 6, color: husk)
                if index == 0 {
                    $0.box(center: Vec3(-0.024, 0, 0), size: Vec3(0.008, 0.07, 0.01), color: Palette.barkBlack)
                }
            }
        }
        // Moonsalt grown in two clusters on the floor.
        b.with(material: .crystal) {
            for (cluster, centre) in [ground(0.1, -0.125), ground(0.022, 0.118)].enumerated() {
                for index in 0..<4 {
                    let angle = Float(index) * 1.9 + Float(cluster)
                    let tall = 0.035 + 0.025 * Noise.unit(Int32(index), Int32(cluster), 219)
                    let foot = centre + MeshBuilder.ring(index == 0 ? 0 : 0.022, -0.012, angle)
                    $0.place(.translation(foot) * Mat4.aligningUp(to: MeshBuilder.ring(index == 0 ? 0.1 : 0.45, 1, angle))) {
                        $0.prism(sides: 6, radius: 0.011, from: 0, to: tall * 0.75, color: Palette.moonsalt)
                        $0.cone(sides: 6, radius: 0.011, from: tall * 0.75, to: tall, color: Palette.moonsalt)
                    }
                }
            }
        }
        // Skulls by its cold heart.
        skull(&b, at: ground(0.115, -0.035) + Vec3(0, 0.012, 0), facing: 2.6, size: 0.016, color: bone)
        skull(&b, at: ground(-0.108, 0.053) + Vec3(0, 0.012, 0), facing: 5.2, size: 0.016, color: bone)
        // The arms of those who came for them: a spear stuck in the slope,
        // a shield sunk in it and a helm on the floor, all crusted white.
        let foot = MeshBuilder.ring(0.4, floor(0.4) - 0.01, 5.44), top = MeshBuilder.ring(0.33, floor(0.4) + 0.25, 5.44)
        b.limb(from: foot, to: top, radius: 0.006, color: Palette.timberGrey.mix(Palette.saltCrust, 0.4))
        b.place(.translation(top) * Mat4.aligningUp(to: top - foot)) {
            $0.cone(sides: 4, radius: 0.012, to: 0.045, color: Palette.iron.mix(Palette.saltCrust, 0.5))
        }
        b.place(.translation(MeshBuilder.ring(0.37, floor(0.37) + 0.008, 3.34)) * .rotationY(3.34) * .rotationZ(0.65)) {
            $0.lathe([(0.045, -0.004), (0.045, 0.004), (0.0, 0.009)], sides: 8, color: Palette.madder.mix(Palette.saltCrust, 0.6))
        }
        b.place(.translation(MeshBuilder.ring(0.33, floor(0.33) - 0.004, 5.0)) * .rotationZ(0.5)) {
            $0.lathe([(0.03, 0.0), (0.03, 0.012), (0.024, 0.03), (0.0, 0.036)], sides: 7, color: Palette.iron.mix(Palette.saltCrust, 0.5))
        }
    }

    /// The Reavers' stockade drawn near: a beast on a spit over the fire,
    /// bedrolls about it, a rack of spears, the plunder of the holds heaped
    /// between the tents, a war drum, a chopping block with its axe, skulls
    /// on the stakes by the gate and the gate's own posts and lintel, a
    /// horned skull over it.
    static func stockadeNear(_ b: inout MeshBuilder) {
        let ground: Float = 0.013
        // The spit on its forked posts, the beast on it, the crank.
        for x in [Float(-0.11), 0.11] {
            b.limb(from: Vec3(x, ground, 0.02), to: Vec3(x, 0.14, 0.02), radius: 0.006, color: Palette.timberDark)
            for z in [Float(-0.015), 0.015] {
                b.limb(from: Vec3(x, 0.13, 0.02), to: Vec3(x, 0.165, 0.02 + z), radius: 0.004, sides: 3, color: Palette.timberDark)
            }
        }
        b.with(material: .metal) {
            $0.limb(from: Vec3(-0.14, 0.146, 0.02), to: Vec3(0.14, 0.146, 0.02), radius: 0.004, color: Palette.iron)
            $0.limb(from: Vec3(0.14, 0.146, 0.02), to: Vec3(0.14, 0.12, 0.03), radius: 0.003, color: Palette.iron)
        }
        b.rock(center: Vec3(0, 0.146, 0.02), size: Vec3(0.055, 0.028, 0.032), rings: 3, sides: 6, jitter: 0.12, seed: 230,
               color: Palette.madder.mix(Palette.leatherDark, 0.55))
        // Bedrolls about the fire.
        for (index, angle) in [Float(1.6), 4.0, 5.3].enumerated() {
            let along = MeshBuilder.ring(1, 0, angle + .pi / 2)
            b.place(.translation(MeshBuilder.ring(0.21, ground + 0.016, angle) - along * 0.045) * Mat4.aligningUp(to: along)) {
                $0.lathe([(0.016, 0), (0.017, 0.045), (0.016, 0.09)], sides: 6, color: index == 1 ? Palette.fur : Palette.leather)
            }
        }
        // A rack of spears by the west tent.
        for x in [Float(-0.4), -0.24] {
            for z in [Float(0.12), 0.18] {
                b.limb(from: Vec3(x, ground, z), to: Vec3(x, 0.15, 0.15), radius: 0.005, sides: 3, color: Palette.timberDark)
            }
        }
        b.limb(from: Vec3(-0.42, 0.14, 0.15), to: Vec3(-0.22, 0.14, 0.15), radius: 0.005, color: Palette.timber)
        for x in [Float(-0.39), -0.35, -0.31, -0.27] {
            let foot = Vec3(x, ground, 0.21), top = Vec3(x + 0.006, 0.26, 0.14)
            b.limb(from: foot, to: top, radius: 0.004, color: Palette.timberDark)
            b.with(material: .metal) {
                $0.place(.translation(top) * Mat4.aligningUp(to: top - foot)) { $0.cone(sides: 4, radius: 0.009, to: 0.035, color: Palette.iron) }
            }
        }
        // The plunder of the holds: barrels, crates, a sack and a chest.
        Stores.barrel(&b, at: Vec3(-0.05, ground, -0.36), turn: 0.3)
        Stores.barrel(&b, at: Vec3(0.02, ground, -0.4), turn: 1.1)
        b.box(center: Vec3(0.07, ground + 0.025, -0.33), size: Vec3(0.06, 0.05, 0.05), turn: 0.4, color: Palette.timberPale)
        b.box(center: Vec3(0.07, ground + 0.07, -0.33), size: Vec3(0.045, 0.04, 0.04), turn: 0.9, color: Palette.timber)
        b.tiedSack(at: Vec3(-0.1, ground, -0.3), size: 1)
        b.box(center: Vec3(0.13, ground + 0.02, -0.41), size: Vec3(0.07, 0.04, 0.045), turn: -0.3, color: Palette.timberDark)
        b.with(material: .metal) {
            for offset in [Float(-0.022), 0.022] {
                $0.place(.translation(Vec3(0.13, ground + 0.02, -0.41)) * .rotationY(-0.3)) {
                    $0.box(center: Vec3(offset, 0, 0), size: Vec3(0.006, 0.042, 0.047), color: Palette.bronze)
                }
            }
        }
        // A war drum by the gate, its sticks across its head.
        b.place(.translation(Vec3(-0.17, ground, 0.36))) {
            $0.lathe([(0.032, 0), (0.04, 0.035), (0.033, 0.07)], sides: 7, color: Palette.timber)
            $0.lathe([(0.034, 0.07), (0.0, 0.072)], sides: 7, color: Palette.leather.mix(Palette.linen, 0.4))
            $0.limb(from: Vec3(-0.03, 0.075, -0.01), to: Vec3(0.03, 0.078, 0.012), radius: 0.003, sides: 3, color: Palette.timberDark)
            $0.limb(from: Vec3(-0.025, 0.075, 0.015), to: Vec3(0.035, 0.078, -0.005), radius: 0.003, sides: 3, color: Palette.timberDark)
        }
        // A chopping block by the east tent, its axe bitten in.
        b.place(.translation(Vec3(0.38, ground, 0.06))) {
            $0.lathe([(0.035, 0), (0.035, 0.05)], sides: 7, color: Palette.bark)
            $0.lathe([(0.035, 0.05), (0.0, 0.0505)], sides: 7, color: Palette.timberPale)
            $0.limb(from: Vec3(0.0, 0.055, 0.0), to: Vec3(0.04, 0.13, 0.01), radius: 0.004, color: Palette.timber)
            $0.with(material: .metal) {
                $0.box(center: Vec3(-0.004, 0.056, -0.001), size: Vec3(0.03, 0.022, 0.005), color: Palette.iron)
            }
        }
        // Skulls on the stakes by the gate and one at the back, the stakes'
        // own heights worked out as the ring's.
        for index in [15, 18, 5] {
            let angle = Float(index) / 22 * 2 * .pi
            let tall: Float = 0.26 + 0.05 * Noise.unit(Int32(index), 3, 17)
            skull(&b, at: MeshBuilder.ring(0.53, -0.04 + tall - 0.012, angle), facing: angle, size: 0.024)
        }
        // The gate's posts, its lintel and the horned skull over it.
        for angle in [Float(-0.25), 0.25].map({ 1.5 * .pi + $0 }) {
            let foot = MeshBuilder.ring(0.53, -0.04, angle)
            b.limb(from: foot, to: foot + Vec3(0, 0.44, 0), radius: 0.022, color: Palette.bark)
        }
        b.beam(from: Vec3(-0.155, 0.37, 0.514), to: Vec3(0.155, 0.37, 0.514), width: 0.035, depth: 0.03, color: Palette.timberDark)
        skull(&b, at: Vec3(0, 0.405, 0.52), facing: 1.5 * .pi, size: 0.02)
        horns(&b, at: Vec3(0, 0.415, 0.512), side: Vec3(1, 0, 0), size: 0.022, color: Palette.bone.mix(Palette.barkBlack, 0.3))
    }

    /// The Barrowkin's hall drawn near: urns at its door, a shield and a
    /// sword on its threshold, a skull in its passage and bones by it, a
    /// rune glowing on its lintel, a dead tree on its mound with a raven
    /// in it and another on the lintel, headstones leaning before it and a
    /// cairn by its stones.
    static func barrowNear(_ b: inout MeshBuilder) {
        for (x, z) in [(Float(-0.2), Float(0.37)), (0.17, 0.38)] {
            b.place(.translation(Vec3(x, 0, z))) {
                $0.lathe([(0.0, 0.0), (0.02, 0.003), (0.03, 0.025), (0.022, 0.048), (0.013, 0.055), (0.017, 0.062), (0.0, 0.06)], sides: 7,
                         color: Palette.earth.mix(Palette.madder, 0.35))
            }
        }
        b.place(.translation(Vec3(0.04, 0.004, 0.44)) * .rotationX(0.15)) {
            $0.lathe([(0.034, 0), (0.034, 0.005), (0.0, 0.008)], sides: 8, color: Palette.leatherDark)
            $0.with(material: .metal) { $0.cone(sides: 5, radius: 0.009, from: 0.007, to: 0.015, color: Palette.iron) }
        }
        let rust = Palette.iron.mix(Palette.madder, 0.3)
        b.with(material: .metal) {
            $0.sheet([Vec3(-0.12, 0.005, 0.455), Vec3(-0.02, 0.005, 0.445), Vec3(-0.02, 0.005, 0.453), Vec3(-0.12, 0.005, 0.462)],
                     normal: .up, thickness: 0.002, color: rust)
            $0.box(center: Vec3(-0.017, 0.006, 0.449), size: Vec3(0.006, 0.006, 0.04), color: rust)
        }
        b.limb(from: Vec3(-0.014, 0.006, 0.449), to: Vec3(0.012, 0.006, 0.447), radius: 0.004, color: Palette.leatherDark)
        skull(&b, at: Vec3(0.035, 0.016, 0.345), facing: 1.5 * .pi + 0.3, size: 0.016)
        for (from, to) in [(Vec3(0.09, 0.006, 0.47), Vec3(0.14, 0.006, 0.43)), (Vec3(0.1, 0.006, 0.44), Vec3(0.13, 0.008, 0.48))] {
            b.limb(from: from, to: to, radius: 0.005, sides: 3, color: Palette.bone)
        }
        // A rune along the lintel's face, glowing as the light within.
        b.with(material: .glow) {
            $0.box(center: Vec3(0, 0.225, 0.3712), size: Vec3(0.15, 0.006, 0.003), color: Palette.wildGlow)
            for x in [Float(-0.06), -0.02, 0.02, 0.06] {
                $0.box(center: Vec3(x, 0.228, 0.3712), size: Vec3(0.005, 0.018, 0.003), color: Palette.wildGlow)
            }
        }
        // A dead tree on the mound, and the ravens.
        let root = Vec3(0.2, 0.235, -0.12)
        b.limb(from: root, to: root + Vec3(0.02, 0.17, -0.01), radius: 0.016, topRadius: 0.009, sides: 5, color: Palette.deadWood)
        for (from, to) in [(Vec3(0.02, 0.12, -0.01), Vec3(0.08, 0.2, -0.03)), (Vec3(0.02, 0.15, -0.01), Vec3(-0.05, 0.24, 0.02)),
                           (Vec3(0.02, 0.17, -0.01), Vec3(0.04, 0.26, -0.06)), (Vec3(0.01, 0.09, -0.005), Vec3(-0.06, 0.14, -0.04))] {
            b.limb(from: root + from, to: root + to, radius: 0.007, topRadius: 0.002, sides: 3, color: Palette.deadWood)
        }
        raven(&b, at: root + Vec3(0.062, 0.176, -0.024), facing: 0.4, seed: 251)
        raven(&b, at: Vec3(-0.08, 0.25, 0.32), facing: 1.5 * .pi + 0.4, seed: 252)
        // Headstones leaning before it, and a cairn by its western stone.
        headstone(&b, at: Vec3(-0.2, 0, 0.5), turn: 0.2, lean: 0.18)
        headstone(&b, at: Vec3(0.28, 0, 0.47), turn: -0.3, lean: -0.12)
        headstone(&b, at: Vec3(0.12, 0, 0.53), turn: 0.1, lean: 0.25)
        for (layer, size) in [Float(0.03), 0.023, 0.016].enumerated() {
            b.rock(center: Vec3(-0.32 + 0.004 * Float(layer), 0.012 + 0.02 * Float(layer), 0.44), size: Vec3(size, size * 0.45, size * 0.85),
                   rings: 2, sides: 5, jitter: 0.15, seed: UInt32(layer + 260), color: layer % 2 == 0 ? Palette.stone : Palette.stoneDark)
        }
    }

    /// The Spine Hunters' eyrie drawn near: its deck's planks and rails, a
    /// stag's skull and antlers on its windbreak, a bow and a quiver of
    /// arrows against it, furs to sleep on, a horn by the ladder, a basket
    /// on a rope over the edge, and a hide stretched on its frame at the
    /// rock's foot.
    static func eyrieNear(_ b: inout MeshBuilder) {
        let top: Float = 0.42
        for index in 0..<6 {
            b.box(center: Vec3(0.035 + 0.042 * Float(index), top + 0.0005, -0.1), size: Vec3(0.003, 0.001, 0.276), color: Palette.timberDark)
        }
        for x in [Float(0.04), 0.24] {
            b.limb(from: Vec3(x, 0.5, -0.2), to: Vec3(x, 0.5, 0.0), radius: 0.006, color: Palette.timber)
            b.limb(from: Vec3(x, 0.5, 0.0), to: Vec3(x, 0.502, 0.04), radius: 0.005, color: Palette.timber)
        }
        b.limb(from: Vec3(0.02, 0.502, 0.04), to: Vec3(0.27, 0.502, 0.04), radius: 0.005, color: Palette.timber)
        // The stag's skull and antlers on the windbreak.
        let antler = Palette.bone.mix(Palette.timber, 0.4)
        b.rock(center: Vec3(0.14, 0.49, -0.226), size: Vec3(0.019, 0.026, 0.013), rings: 3, sides: 5, jitter: 0.08, seed: 270, color: Palette.bone)
        for flank in [Float(-1), 1] {
            let root = Vec3(0.14 + flank * 0.012, 0.512, -0.226)
            let beam = root + Vec3(flank * 0.05, 0.085, 0.012)
            b.limb(from: root, to: beam, radius: 0.004, topRadius: 0.0025, sides: 3, color: antler)
            b.limb(from: root + Vec3(flank * 0.022, 0.035, 0.005), to: root + Vec3(flank * 0.018, 0.075, 0.02), radius: 0.0025,
                   topRadius: 0.001, sides: 3, color: antler)
            b.limb(from: beam, to: beam + Vec3(flank * 0.022, 0.025, -0.006), radius: 0.0025, topRadius: 0.001, sides: 3, color: antler)
            b.limb(from: beam, to: beam + Vec3(-flank * 0.008, 0.03, 0.004), radius: 0.0025, topRadius: 0.001, sides: 3, color: antler)
        }
        // A bow strung and leaning, and a quiver of arrows.
        let bow = [Vec3(0.235, top, -0.228), Vec3(0.235, 0.46, -0.21), Vec3(0.235, 0.52, -0.205), Vec3(0.235, 0.565, -0.222)]
        for index in 0..<3 {
            b.limb(from: bow[index], to: bow[index + 1], radius: 0.003, sides: 3, color: Palette.timberDark)
        }
        b.limb(from: bow[0], to: bow[3], radius: 0.0009, sides: 3, color: Palette.linen)
        b.place(.translation(Vec3(0.06, top, -0.215)) * .rotationX(-0.15)) {
            $0.lathe([(0.012, 0), (0.014, 0.07), (0.0, 0.0705)], sides: 6, color: Palette.leather)
            for (x, z) in [(Float(-0.004), Float(0.002)), (0.005, -0.003), (0.0, 0.006)] {
                $0.limb(from: Vec3(x, 0.07, z), to: Vec3(x * 1.5, 0.11, z * 1.5), radius: 0.0015, sides: 3, color: Palette.timberPale)
                $0.box(center: Vec3(x * 1.5, 0.105, z * 1.5), size: Vec3(0.002, 0.012, 0.007), color: Palette.linen)
            }
        }
        // Furs on the deck to sleep on.
        b.rock(center: Vec3(0.1, top + 0.004, -0.13), size: Vec3(0.06, 0.008, 0.045), rings: 2, sides: 6, jitter: 0.15, seed: 271,
               color: Palette.fur)
        b.rock(center: Vec3(0.19, top + 0.004, -0.09), size: Vec3(0.045, 0.007, 0.05), rings: 2, sides: 6, jitter: 0.15, seed: 272,
               color: Palette.leather)
        // A horn hung by the ladder's head.
        b.limb(from: Vec3(0.04, 0.49, 0.006), to: Vec3(0.04, 0.47, 0.014), radius: 0.0012, sides: 3, color: Palette.leatherDark)
        b.limb(from: Vec3(0.055, 0.47, 0.016), to: Vec3(0.03, 0.455, 0.02), radius: 0.008, topRadius: 0.005, sides: 5, color: Palette.bone)
        b.limb(from: Vec3(0.03, 0.455, 0.02), to: Vec3(0.012, 0.468, 0.022), radius: 0.005, topRadius: 0.002, sides: 5, color: Palette.bone)
        // A basket on a rope over the east edge, on a pole across the rail.
        b.limb(from: Vec3(0.2, 0.505, -0.1), to: Vec3(0.36, 0.53, -0.1), radius: 0.006, color: Palette.timberDark)
        b.limb(from: Vec3(0.355, 0.53, -0.1), to: Vec3(0.355, 0.365, -0.1), radius: 0.0015, sides: 3, color: Palette.linen)
        b.place(.translation(Vec3(0.355, 0.33, -0.1))) {
            $0.lathe([(0.0, 0.0), (0.025, 0.005), (0.03, 0.035)], sides: 7, color: Palette.straw)
        }
        // A hide stretched on its frame at the rock's foot.
        for x in [Float(-0.18), -0.02] {
            b.limb(from: Vec3(x, 0, 0.42), to: Vec3(x, 0.2, 0.42), radius: 0.006, color: Palette.timber)
        }
        for y in [Float(0.03), 0.185] {
            b.limb(from: Vec3(-0.19, y, 0.42), to: Vec3(-0.01, y, 0.42), radius: 0.005, color: Palette.timber)
        }
        b.sheet([Vec3(-0.165, 0.045, 0.42), Vec3(-0.035, 0.05, 0.42), Vec3(-0.04, 0.17, 0.42), Vec3(-0.16, 0.172, 0.42)],
                normal: Vec3(0, 0, 1), color: Palette.leather.mix(Palette.linen, 0.3))
    }

    /// The drowned chapel drawn near: its pews drowned in rows, its altar
    /// sunk at the head of them, its bell fallen, a font, steps going down
    /// into the water, lilies on it, and its yard's graves on the bank.
    static func chapelNear(_ b: inout MeshBuilder) {
        let wet = Palette.timberDark.mix(Palette.barkBlack, 0.45)
        for (row, z) in [Float(-0.1), -0.02, 0.06, 0.14].enumerated() {
            for side in [Float(-1), 1] {
                // One rotted quite away.
                guard !(row == 2 && side > 0) else { continue }
                let sink = 0.01 * Noise.unit(Int32(row), side > 0 ? 1 : 2, 263)
                b.place(.translation(Vec3(side * 0.1, -sink, z)) * .rotationZ(0.06 * side * (Float(row % 2) - 0.5))) {
                    $0.box(center: Vec3(0, 0.004, 0), size: Vec3(0.13, 0.01, 0.032), color: wet)
                    $0.box(center: Vec3(0, 0.022, -0.017), size: Vec3(0.13, 0.04, 0.008), color: wet)
                }
            }
        }
        b.box(center: Vec3(0, 0.01, -0.165), size: Vec3(0.14, 0.06, 0.05), color: Palette.stonePale.mix(Palette.moss, 0.25))
        b.with(material: .metal) {
            $0.limb(from: Vec3(-0.04, 0.044, -0.16), to: Vec3(0.03, 0.044, -0.17), radius: 0.003, color: Palette.bronze)
            $0.place(.translation(Vec3(0.24, 0.012, 0.18)) * .rotationY(0.7) * .rotationZ(1.35)) {
                $0.tube([(0.04, 0.0), (0.03, 0.03), (0.022, 0.06), (0.0, 0.07)], sides: 8, color: Palette.bronze.mix(Palette.moss, 0.35))
            }
        }
        b.place(.translation(Vec3(0.24, 0, -0.12))) {
            $0.lathe([(0.02, -0.02), (0.02, 0.05), (0.04, 0.06), (0.046, 0.085)], sides: 7, color: Palette.stonePale)
            $0.lathe([(0.04, 0.08), (0.0, 0.081)], sides: 7, color: Vec3(0.03, 0.04, 0.05))
        }
        b.box(center: Vec3(0, -0.008, 0.29), size: Vec3(0.22, 0.024, 0.05), color: Palette.stonePale)
        b.box(center: Vec3(0, -0.011, 0.252), size: Vec3(0.22, 0.026, 0.035), color: Palette.stone)
        for (index, (x, z)) in [(Float(-0.02), Float(0.21)), (0.08, 0.2), (-0.13, 0.22), (-0.25, -0.14), (0.16, -0.16), (-0.27, 0.15)]
            .enumerated() {
            b.place(.translation(Vec3(x, 0.001, z))) {
                $0.lathe([(0.022, 0.0), (0.022, 0.002), (0.0, 0.0025)], sides: 6, color: Palette.moss.mix(Palette.leaf, 0.5))
                if index % 3 == 0 { $0.cone(sides: 5, radius: 0.008, from: 0.002, to: 0.014, color: Palette.linen) }
            }
        }
        headstone(&b, at: Vec3(-0.2, -0.004, 0.47), turn: 0.3, lean: 0.2)
        headstone(&b, at: Vec3(0.33, -0.004, 0.43), turn: -0.4, lean: -0.22)
        headstone(&b, at: Vec3(-0.47, -0.004, -0.08), turn: 1.4, lean: 0.3)
    }

    /// The gatehold drawn near: slits in its towers toward either way, a
    /// ladder up the west tower, the hunters' hide banner and antlers on a
    /// pole over the east, a fire burning in each tower's top, a horned
    /// skull over the gate, and wood stacked by the hunters' fire.
    static func gateholdNear(_ b: inout MeshBuilder) {
        for side in [Float(-1), 1] {
            // The middle of the tower's face nearest each way.
            let first = side * 0.4 + 0.12 + .pi / 7, step = 2 * Float.pi / 7
            for way in [Float(0.5), 1.5].map({ $0 * .pi }) {
                let face = first + ((way - first) / step).rounded() * step
                b.place(.translation(Vec3(side * 0.3, 0.22, 0)) * .rotationY(face)) {
                    $0.box(center: Vec3(0.1065, 0, 0), size: Vec3(0.006, 0.055, 0.012), color: Palette.barkBlack)
                }
            }
            b.with(material: .glow) {
                $0.place(.translation(Vec3(side * 0.27, 0.38, 0.03))) {
                    $0.lathe([(0.022, 0), (0.026, 0.018), (0.0, 0.055)], sides: 5, color: Palette.fire)
                }
            }
        }
        b.ladder(from: Vec3(-0.3, 0, 0.21), to: Vec3(-0.3, 0.37, 0.118), width: 0.06, rungs: 6, color: Palette.timber)
        b.limb(from: Vec3(0.3, 0.38, -0.02), to: Vec3(0.3, 0.66, -0.02), radius: 0.007, color: Palette.timberDark)
        b.flag(at: Vec3(0.302, 0.64, -0.02), width: 0.1, height: 0.12, color: Palette.leather, material: .plain)
        horns(&b, at: Vec3(0.3, 0.655, -0.02), side: Vec3(1, 0, 0), size: 0.02, color: Palette.bone.mix(Palette.timber, 0.4))
        skull(&b, at: Vec3(0, 0.345, 0.004), facing: 1.5 * .pi, size: 0.02)
        horns(&b, at: Vec3(0, 0.355, -0.004), side: Vec3(1, 0, 0), size: 0.02, color: Palette.bone.mix(Palette.barkBlack, 0.3))
        for (index, (y, z)) in [(Float(0.012), Float(0.33)), (0.012, 0.36), (0.035, 0.345)].enumerated() {
            b.log(from: Vec3(0.2, y, z), to: Vec3(0.3, y, z + 0.01 * Float(index % 2)), radius: 0.012)
        }
    }
}
