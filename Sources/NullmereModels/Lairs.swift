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
        return Model(name: name, mesh: b.mesh)
    }

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
}
