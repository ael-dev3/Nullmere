import Foundation
import NullmereCore

/// The land's furniture, and the sites where companies gather its stores.
enum Land {
    static func furnishing(_ furnishing: Furnishing) -> Mesh {
        var b = MeshBuilder()
        switch furnishing {
        case .fir: fir(&b)
        case .elderTree: elderTree(&b)
        case .deadTree: deadTree(&b)
        case .crag: crag(&b)
        case .boulder: b.rock(center: Vec3(0, 0.035, 0), size: Vec3(0.09, 0.07, 0.075), rings: 3, sides: 6, jitter: 0.2, seed: 31,
                              color: Palette.rock)
        case .reeds: reeds(&b, at: .zero, count: 9, height: 0.2, seed: 5)
        case .saltCrystals: crystals(&b, at: .zero, count: 6, height: 0.13, seed: 8)
        case .barrowMound: barrowMound(&b)
        case .standingStone: standingStone(&b)
        case .ruin: ruin(&b)
        case .grass: grass(&b, at: .zero, tufts: 5, spread: 0.07, seed: 2)
        case .driftwood: driftwood(&b)
        case .furrows: furrows(&b)
        case .stoneFace: stoneFace(&b)
        case .heather: heather(&b, seed: 21)
        case .fern: fern(&b, seed: 23)
        case .pebbles: pebbles(&b, seed: 27)
        case .birch: birch(&b)
        case .steppingStones: steppingStones(&b)
        }
        return b.mesh
    }

    // MARK: Trees

    /// A dark fir in three tiers, its crown moving in the wind.
    static func fir(_ b: inout MeshBuilder, at: Vec3 = .zero, scale: Float = 1) {
        b.place(.translation(at) * .scale(scale)) {
            $0.lathe([(0.03, -0.06), (0.022, 0.16)], sides: 4, color: Palette.bark)
            $0.with(material: .foliage, sway: 1) {
                $0.swayRange = (0.08, 0.6)
                for (index, base) in [Float(0.1), 0.26, 0.4].enumerated() {
                    let radius = 0.17 - Float(index) * 0.04
                    $0.lathe([(radius, base), (0, base + 0.25 - Float(index) * 0.02)], sides: 6,
                             color: index == 1 ? Palette.fir : Palette.firDark, twist: Float(index) * 0.5)
                }
            }
        }
    }

    /// An elder grove's vast old tree: a gnarled trunk on spread roots,
    /// a broad crown of heavy masses.
    static func elderTree(_ b: inout MeshBuilder) {
        b.lathe([(0.12, -0.08), (0.085, 0.06), (0.07, 0.22), (0.08, 0.34), (0.05, 0.42)], sides: 6, color: Palette.bark)
        for index in 0..<5 {
            let angle = Float(index) * 2 * .pi / 5 + 0.3
            let out = MeshBuilder.ring(0.2, -0.01, angle)
            b.limb(from: Vec3(0, 0.07, 0), to: out, radius: 0.035, topRadius: 0.012, sides: 3, color: Palette.bark)
        }
        for index in 0..<3 {
            let angle = Float(index) * 2 * .pi / 3 + 0.8
            b.limb(from: Vec3(0, 0.3, 0), to: MeshBuilder.ring(0.2, 0.52, angle), radius: 0.035, topRadius: 0.02, sides: 4,
                   color: Palette.bark)
        }
        b.with(material: .foliage, sway: 0.7) {
            $0.swayRange = (0.4, 0.95)
            let masses: [(Vec3, Vec3)] = [
                (Vec3(0, 0.66, 0), Vec3(0.26, 0.18, 0.26)), (Vec3(0.17, 0.56, 0.09), Vec3(0.18, 0.13, 0.17)),
                (Vec3(-0.15, 0.58, 0.12), Vec3(0.17, 0.13, 0.16)), (Vec3(0.02, 0.57, -0.19), Vec3(0.2, 0.13, 0.15)),
                (Vec3(0.04, 0.82, 0.02), Vec3(0.16, 0.12, 0.16)),
            ]
            for (index, mass) in masses.enumerated() {
                $0.rock(center: mass.0, size: mass.1, rings: 3, sides: 6, jitter: 0.15, seed: UInt32(40 + index),
                        color: index % 2 == 0 ? Palette.leaf : Palette.fir)
            }
        }
    }

    /// A birch at the forest's edge: a slim pale trunk banded dark, two
    /// thin boughs and a light crown that moves in the wind.
    static func birch(_ b: inout MeshBuilder) {
        b.lathe([(0.022, -0.05), (0.018, 0.25), (0.01, 0.5)], sides: 5, color: Palette.birchBark)
        for (index, height) in [Float(0.08), 0.17, 0.29, 0.38].enumerated() {
            let width = 0.044 - 0.006 * Float(index)
            b.box(center: Vec3(0, height, 0), size: Vec3(width, 0.012, width), turn: Float(index) * 0.7, color: Palette.barkBlack)
        }
        b.with(sway: 0.3) {
            $0.swayRange = (0.2, 0.5)
            $0.limb(from: Vec3(0, 0.3, 0), to: Vec3(0.09, 0.44, 0.02), radius: 0.008, topRadius: 0.003, sides: 3, color: Palette.birchBark)
            $0.limb(from: Vec3(0, 0.36, 0), to: Vec3(-0.07, 0.5, -0.03), radius: 0.007, topRadius: 0.003, sides: 3, color: Palette.birchBark)
        }
        b.with(material: .foliage, sway: 0.9) {
            $0.swayRange = (0.3, 0.7)
            let masses: [(Vec3, Vec3)] = [(Vec3(0, 0.52, 0), Vec3(0.11, 0.13, 0.1)), (Vec3(0.07, 0.43, 0.03), Vec3(0.08, 0.09, 0.07)),
                                          (Vec3(-0.06, 0.46, -0.03), Vec3(0.08, 0.09, 0.08))]
            for (index, mass) in masses.enumerated() {
                $0.rock(center: mass.0, size: mass.1, rings: 3, sides: 6, jitter: 0.2, seed: UInt32(60 + index),
                        color: index == 0 ? Palette.birchLeaf : Palette.leaf)
            }
        }
    }

    /// A dead tree bleached pale, its branches bare.
    static func deadTree(_ b: inout MeshBuilder) {
        b.lathe([(0.04, -0.05), (0.03, 0.2), (0.016, 0.45)], sides: 5, color: Palette.deadWood)
        let branches: [(Float, Vec3)] = [(0.18, Vec3(0.13, 0.3, 0.03)), (0.24, Vec3(-0.11, 0.38, -0.04)), (0.33, Vec3(0.05, 0.46, -0.1)),
                                         (0.36, Vec3(-0.06, 0.5, 0.09))]
        b.with(sway: 0.25) {
            $0.swayRange = (0.15, 0.5)
            for (height, tip) in branches {
                $0.limb(from: Vec3(0, height, 0), to: tip, radius: 0.013, topRadius: 0.004, sides: 3, color: Palette.deadWood)
            }
        }
    }

    // MARK: Stone

    /// The Spine's broken rock: a tall jagged shard with a lesser beside it.
    static func crag(_ b: inout MeshBuilder) {
        b.rock(center: Vec3(0, 0.18, 0), size: Vec3(0.16, 0.34, 0.13), rings: 4, sides: 6, jitter: 0.3, seed: 51, color: Palette.rock)
        b.rock(center: Vec3(0.15, 0.06, 0.08), size: Vec3(0.09, 0.14, 0.08), rings: 3, sides: 5, jitter: 0.3, seed: 52,
               color: Palette.stoneDark)
        b.rock(center: Vec3(-0.12, 0.03, -0.08), size: Vec3(0.07, 0.07, 0.06), rings: 2, sides: 5, jitter: 0.2, seed: 53,
               color: Palette.rock)
    }

    /// A tall slab set upright long ago, leaning a little.
    static func standingStone(_ b: inout MeshBuilder) {
        b.place(.rotationZ(0.06) * .rotationX(-0.04)) {
            $0.lathe([(0.075, -0.08), (0.07, 0.2), (0.045, 0.34), (0.0, 0.37)], sides: 4, color: Palette.stoneDark, twist: 0.2)
        }
        b.rock(center: Vec3(0.08, 0.0, 0.06), size: Vec3(0.04, 0.025, 0.035), rings: 2, sides: 4, jitter: 0.2, seed: 61,
               color: Palette.stone)
    }

    /// A grassed burial mound with a doorway of three stones in its front.
    static func barrowMound(_ b: inout MeshBuilder) {
        let rings: [(radius: Float, y: Float)] = [(0.34, -0.06), (0.32, 0.04), (0.25, 0.13), (0.13, 0.19), (0, 0.21)]
        b.lathe(rings, sides: 9, color: Palette.grass.mix(Palette.earth, 0.3))
        b.box(min: Vec3(-0.07, -0.02, 0.25), max: Vec3(0.07, 0.11, 0.3), color: Palette.loam)
        for x in [Float(-0.065), 0.065] {
            b.box(center: Vec3(x, 0.05, 0.29), size: Vec3(0.035, 0.13, 0.035), color: Palette.stoneDark)
        }
        b.box(center: Vec3(0, 0.125, 0.29), size: Vec3(0.17, 0.03, 0.045), color: Palette.stone)
        for index in 0..<5 {
            let angle = Float(index) * 0.7 + 2.2
            b.box(center: MeshBuilder.ring(0.33, 0.015, angle), size: Vec3(0.04, 0.04, 0.035), turn: angle, color: Palette.stoneDark)
        }
    }

    /// A half-sunken ruin: broken walls, a stump of a column, a fallen arch.
    static func ruin(_ b: inout MeshBuilder) {
        let walls: [(Vec3, Vec3, Float)] = [(Vec3(-0.2, 0, -0.15), Vec3(0.15, 0, -0.15), 0.2), (Vec3(-0.2, 0, -0.15), Vec3(-0.2, 0, 0.12), 0.13),
                                            (Vec3(0.15, 0, -0.15), Vec3(0.2, 0, 0.0), 0.08)]
        for (index, wall) in walls.enumerated() {
            let pieces = 3
            for piece in 0..<pieces {
                let t0 = Float(piece) / Float(pieces), t1 = Float(piece + 1) / Float(pieces) - 0.02
                let tall = wall.2 * (0.5 + Noise.unit(Int32(index), Int32(piece), 71))
                let a = wall.0.mix(wall.1, t0), c = wall.0.mix(wall.1, t1)
                b.beam(from: a + Vec3(0, (tall - 0.08) / 2, 0), to: c + Vec3(0, (tall - 0.08) / 2, 0), width: 0.045, depth: tall + 0.08,
                       color: piece % 2 == 0 ? Palette.stone : Palette.stoneDark)
            }
        }
        b.lathe([(0.04, -0.05), (0.04, 0.16), (0.05, 0.17), (0.05, 0.2)], sides: 6, color: Palette.stonePale)
        b.place(.translation(Vec3(0.08, 0.02, 0.12)) * .rotationZ(.pi / 2) * .rotationX(0.3)) {
            $0.lathe([(0.035, -0.12), (0.035, 0.12)], sides: 6, color: Palette.stonePale)
        }
        b.rock(center: Vec3(-0.05, 0.0, 0.05), size: Vec3(0.12, 0.03, 0.1), rings: 2, sides: 5, jitter: 0.2, seed: 72,
               color: Palette.grass.mix(Palette.earth, 0.4))
    }

    /// A seam's face cut flat, the blocks taken from it lying by.
    static func stoneFace(_ b: inout MeshBuilder) {
        b.rock(center: Vec3(0, 0.1, -0.08), size: Vec3(0.24, 0.17, 0.12), rings: 3, sides: 6, jitter: 0.2, seed: 81, color: Palette.rock)
        b.box(min: Vec3(-0.15, -0.02, -0.06), max: Vec3(0.13, 0.19, 0.0), color: Palette.stonePale)
        for x in [Float(-0.08), 0.0, 0.07] {
            b.box(center: Vec3(x, 0.09, 0.001), size: Vec3(0.004, 0.2, 0.004), color: Palette.stone)
        }
        b.box(center: Vec3(-0.1, 0.02, 0.09), size: Vec3(0.07, 0.045, 0.05), turn: 0.3, color: Palette.stonePale)
        b.box(center: Vec3(0.06, 0.02, 0.1), size: Vec3(0.06, 0.045, 0.05), turn: -0.2, color: Palette.stone)
    }

    // MARK: Small things

    /// Reeds: thin blades rising from one root, bending in the wind.
    static func reeds(_ b: inout MeshBuilder, at: Vec3, count: Int, height: Float, seed: UInt32) {
        b.with(material: .foliage, sway: 1) {
            $0.swayRange = (0, height)
            for index in 0..<count {
                let u = Noise.unit(Int32(index), 1, seed), v = Noise.unit(Int32(index), 2, seed)
                let foot = at + Vec3((u - 0.5) * 0.12, -0.03, (v - 0.5) * 0.12)
                let tip = foot + Vec3((u - 0.5) * 0.08, height * (0.7 + 0.5 * v), (v - 0.5) * 0.08)
                $0.place(.translation(foot) * Mat4.aligningUp(to: tip - foot)) {
                    $0.cone(sides: 3, radius: 0.009, to: (tip - foot).length, color: index % 3 == 0 ? Palette.reed : Palette.grass,
                            twist: u * 3)
                }
            }
        }
    }

    /// Tufts of grey grass, each a few blades leaning out from its root.
    static func grass(_ b: inout MeshBuilder, at: Vec3, tufts: Int, spread: Float, seed: UInt32) {
        b.with(material: .foliage, sway: 0.8) {
            for index in 0..<tufts {
                let u = Noise.unit(Int32(index), 5, seed), v = Noise.unit(Int32(index), 6, seed)
                let root = at + Vec3((u - 0.5) * 2 * spread, -0.015, (v - 0.5) * 2 * spread)
                for blade in 0..<4 {
                    let angle = Float(blade) * 1.7 + u * 6
                    let tip = root + MeshBuilder.ring(0.035, 0.07 + 0.04 * Noise.unit(Int32(index), Int32(blade), seed), angle)
                    $0.swayRange = (0, 0.1)
                    $0.place(.translation(root) * Mat4.aligningUp(to: tip - root)) {
                        $0.cone(sides: 3, radius: 0.011, to: (tip - root).length, color: blade % 2 == 0 ? Palette.grass : Palette.reed,
                                twist: angle)
                    }
                }
            }
        }
    }

    /// Heather: low clumps of dark mauve, each with a few sprigs in bloom.
    static func heather(_ b: inout MeshBuilder, seed: UInt32) {
        b.with(material: .foliage, sway: 0.35) {
            $0.swayRange = (0, 0.06)
            for clump in 0..<4 {
                let u = Noise.unit(Int32(clump), 11, seed), v = Noise.unit(Int32(clump), 12, seed)
                let at = Vec3((u - 0.5) * 0.16, 0.012, (v - 0.5) * 0.16)
                let size = 0.028 + 0.018 * Noise.unit(Int32(clump), 13, seed)
                $0.rock(center: at, size: Vec3(size * 1.3, size * 0.7, size * 1.2), rings: 2, sides: 5, jitter: 0.25,
                        seed: seed &+ UInt32(clump), color: clump % 2 == 0 ? Palette.heather : Palette.heatherDark)
                for sprig in 0..<3 {
                    let angle = Float(sprig) * 2.1 + u * 5
                    let tip = at + MeshBuilder.ring(size * 0.9, size * 1.4, angle)
                    $0.place(.translation(at) * Mat4.aligningUp(to: tip - at)) {
                        $0.cone(sides: 3, radius: 0.006, to: (tip - at).length, color: Palette.heatherBloom, twist: angle)
                    }
                }
            }
        }
    }

    /// Ferns under the firs: fronds arching out from one crown and down
    /// again, each in two lengths.
    static func fern(_ b: inout MeshBuilder, seed: UInt32) {
        b.with(material: .foliage, sway: 0.6) {
            $0.swayRange = (0, 0.12)
            for frond in 0..<7 {
                let angle = Float(frond) * 2 * .pi / 7 + Noise.unit(Int32(frond), 14, seed) * 0.5
                let reach = 0.09 + 0.04 * Noise.unit(Int32(frond), 15, seed)
                let middle = MeshBuilder.ring(reach * 0.5, 0.07, angle), tip = MeshBuilder.ring(reach, 0.035, angle)
                $0.limb(from: Vec3(0, 0.005, 0), to: middle, radius: 0.012, topRadius: 0.009, sides: 3,
                        color: frond % 2 == 0 ? Palette.fern : Palette.leaf)
                $0.limb(from: middle, to: tip, radius: 0.009, topRadius: 0.002, sides: 3, color: Palette.fern)
            }
        }
    }

    /// Stones laid across a shoal, a stride apart along its ford: broad,
    /// flat-topped and worn, each its own shape, the water round their feet.
    static func steppingStones(_ b: inout MeshBuilder) {
        for index in 0..<5 {
            let x = (Float(index) - 2) * 0.13
            let wander = (Noise.unit(Int32(index), 41, 7) - 0.5) * 0.05
            let size = 0.045 + 0.012 * Noise.unit(Int32(index), 42, 7)
            b.rock(center: Vec3(x, 0.012, wander), size: Vec3(size * 1.2, 0.022, size), rings: 2, sides: 6, jitter: 0.12,
                   seed: 61 &+ UInt32(index), color: index % 2 == 0 ? Palette.stonePale : Palette.stone)
        }
    }

    /// Pebbles washed up and left: small, smooth, of the lake's two stones.
    static func pebbles(_ b: inout MeshBuilder, seed: UInt32) {
        for index in 0..<6 {
            let u = Noise.unit(Int32(index), 16, seed), v = Noise.unit(Int32(index), 17, seed)
            let size = 0.012 + 0.012 * Noise.unit(Int32(index), 18, seed)
            b.rock(center: Vec3((u - 0.5) * 0.18, size * 0.4, (v - 0.5) * 0.18), size: Vec3(size * 1.3, size * 0.8, size), rings: 2,
                   sides: 5, jitter: 0.15, seed: seed &+ UInt32(index), color: index % 3 == 0 ? Palette.stonePale : Palette.stone)
        }
    }

    /// Moonsalt grown in clustered six-sided spars.
    static func crystals(_ b: inout MeshBuilder, at: Vec3, count: Int, height: Float, seed: UInt32) {
        b.with(material: .crystal) {
            for index in 0..<count {
                let u = Noise.unit(Int32(index), 7, seed), v = Noise.unit(Int32(index), 8, seed)
                let foot = at + Vec3((u - 0.5) * 0.12, -0.02, (v - 0.5) * 0.12)
                let lean = Vec3((u - 0.5) * 0.8, 1, (v - 0.5) * 0.8)
                let tall = height * (0.45 + 0.7 * Noise.unit(Int32(index), 9, seed))
                $0.place(.translation(foot) * Mat4.aligningUp(to: lean)) {
                    $0.prism(sides: 6, radius: 0.018 + 0.012 * u, from: 0, to: tall * 0.75, color: Palette.moonsalt)
                    $0.cone(sides: 6, radius: 0.018 + 0.012 * u, from: tall * 0.75, to: tall, color: Palette.moonsalt)
                }
            }
        }
    }

    /// A pale log thrown up on the strand, its broken branches up.
    static func driftwood(_ b: inout MeshBuilder) {
        b.place(.rotationY(0.4)) {
            $0.limb(from: Vec3(-0.17, 0.02, 0), to: Vec3(0.17, 0.025, 0.01), radius: 0.028, topRadius: 0.018, sides: 5,
                    color: Palette.deadWood)
            $0.limb(from: Vec3(-0.06, 0.03, 0), to: Vec3(-0.1, 0.1, 0.05), radius: 0.012, topRadius: 0.005, sides: 3, color: Palette.deadWood)
            $0.limb(from: Vec3(0.08, 0.03, 0), to: Vec3(0.13, 0.07, -0.06), radius: 0.01, topRadius: 0.004, sides: 3, color: Palette.deadWood)
            $0.limb(from: Vec3(-0.17, 0.02, 0), to: Vec3(-0.22, 0.05, -0.03), radius: 0.015, topRadius: 0.006, sides: 3,
                    color: Palette.deadWood)
        }
    }

    /// Furrows of dark loam, ploughed in ridges.
    static func furrows(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.26, -0.06, -0.22), max: Vec3(0.26, 0.004, 0.22), color: Palette.loam)
        for index in 0..<6 {
            let z = Float(index) * 0.075 - 0.19
            b.place(.translation(Vec3(0, 0, z)) * .rotationZ(.pi / 2)) {
                $0.lathe([(0.026, -0.25), (0.026, 0.25)], sides: 3, color: Palette.earth, twist: .pi / 2)
            }
        }
    }

    // MARK: Gathering sites

    /// Where a company gathers: a field of grain in rows with its sheaves
    /// stooked; a stand of firs part-felled; a stone outcrop cut in faces
    /// with its blocks; a moonsalt pan crusted white. Each fills a hex's
    /// heart, about 0.6 from its middle.
    /// A holy site: a ring of seven standing stones about its heart (a
    /// well that holds the moon, a still dark stone, an altar crusted with
    /// moonsalt), and a pennant on a pole in its holder's colour.
    static func shrine(_ kind: ShrineKind, name: String) -> Model {
        var b = MeshBuilder()
        // The ring.
        for index in 0..<7 {
            let angle = Float(index) / 7 * 2 * .pi + 0.3
            b.place(.translation(MeshBuilder.ring(0.36, 0, angle)) * .rotationY(angle) * .rotationZ(index % 2 == 0 ? 0.05 : -0.04)) {
                $0.lathe([(0.05, -0.06), (0.05, 0.17), (0.035, 0.27), (0.0, 0.29)], sides: 4,
                         color: index % 3 == 0 ? Palette.stone : Palette.stoneDark, twist: 0.3)
            }
        }
        // A worn floor of flags within it.
        b.lathe([(0.3, -0.03), (0.3, 0.012), (0.0, 0.02)], sides: 9, color: Palette.stonePale.mix(Palette.stone, 0.5))
        // Its heart.
        switch kind {
        case .moonwell:
            b.lathe([(0.13, 0.0), (0.13, 0.07), (0.11, 0.075), (0.11, 0.03), (0.0, 0.03)], sides: 9, color: Palette.stone)
            b.material = .crystal
            b.lathe([(0.105, 0.05), (0.0, 0.052)], sides: 9, color: Palette.moonGlow)
            b.material = .plain
        case .stillStone:
            b.place(.rotationY(0.4)) {
                $0.lathe([(0.11, 0.0), (0.12, 0.12), (0.08, 0.3), (0.0, 0.33)], sides: 5, color: Palette.slate, twist: 0.1)
            }
        case .saltAltar:
            b.box(center: Vec3(0, 0.05, 0), size: Vec3(0.2, 0.1, 0.13), color: Palette.stonePale)
            b.material = .crystal
            for (x, z, h) in [(Float(-0.05), Float(0.0), Float(0.09)), (0.02, 0.02, 0.13), (0.06, -0.02, 0.07)] {
                b.place(.translation(Vec3(x, 0, z))) { $0.cone(sides: 5, radius: 0.025, from: 0.1, to: 0.1 + h, color: Palette.moonsalt) }
            }
            b.material = .plain
        case .brokenSpire:
            // The last age's Moonspire: a tall tapering shaft of pale stone,
            // snapped and leaning, its fallen courses about its foot and
            // moonsalt still glinting where it was set.
            b.place(.rotationZ(0.12) * .rotationX(-0.06)) {
                $0.lathe([(0.12, 0.0), (0.11, 0.18), (0.095, 0.42), (0.08, 0.62), (0.07, 0.7), (0.0, 0.72)], sides: 7,
                         color: Palette.stonePale, twist: 0.15)
            }
            for (x, z, turn) in [(Float(0.2), Float(0.08), Float(0.5)), (-0.17, 0.15, 1.2), (0.06, -0.21, 2.1)] {
                b.place(.translation(Vec3(x, 0.035, z)) * .rotationY(turn)) {
                    $0.box(center: Vec3(0, 0, 0), size: Vec3(0.12, 0.07, 0.08), color: Palette.stone)
                }
            }
            b.material = .crystal
            for (x, z, h) in [(Float(0.1), Float(-0.06), Float(0.06)), (-0.08, -0.1, 0.05)] {
                b.place(.translation(Vec3(x, 0, z))) { $0.cone(sides: 5, radius: 0.02, from: 0.0, to: h, color: Palette.moonsalt) }
            }
            b.material = .plain
        case .heartstone:
            // The stone in the Crown's heart: a tall dark menhir on a
            // stepped plinth, taller than any stone of the ring, veined
            // with moonsalt that glows by night.
            b.lathe([(0.17, 0.0), (0.17, 0.04), (0.13, 0.045), (0.13, 0.08), (0.0, 0.085)], sides: 8, color: Palette.stoneDark)
            b.place(.translation(Vec3(0, 0.08, 0)) * .rotationY(0.3)) {
                $0.lathe([(0.075, 0.0), (0.085, 0.2), (0.065, 0.48), (0.03, 0.6), (0.0, 0.62)], sides: 5, color: Palette.slate, twist: 0.2)
            }
            b.material = .crystal
            // Each vein set in the middle of a face, a little proud of it.
            for (y, radius, turn) in [(Float(0.18), Float(0.071), Float(6.155)), (0.32, 0.0648, 2.385), (0.46, 0.0567, 3.641)] {
                b.place(.translation(Vec3(0, 0.08 + y, 0)) * .rotationY(turn)) {
                    $0.box(center: Vec3(radius, 0, 0), size: Vec3(0.012, 0.07, 0.03), color: Palette.moonGlow)
                }
            }
            b.material = .plain
        }
        b.fine { holyDetail(&$0, kind: kind) }
        // The pole, and its pennant in the holder's colour.
        b.box(center: Vec3(0.2, 0.22, -0.2), size: Vec3(0.012, 0.44, 0.012), color: Palette.timberDark)
        b.material = .cloth
        b.sway = 0.6
        b.quad(Vec3(0.206, 0.43, -0.2), Vec3(0.206, 0.35, -0.2), Vec3(0.34, 0.39, -0.2), Vec3(0.34, 0.43, -0.2), color: Palette.house)
        b.quad(Vec3(0.206, 0.43, -0.2), Vec3(0.34, 0.43, -0.2), Vec3(0.34, 0.39, -0.2), Vec3(0.206, 0.35, -0.2), color: Palette.house)
        b.material = .plain
        b.sway = 0
        return Model(name: name, mesh: b.mesh)
    }

    /// A holy site's work drawn near: its floor's flags, worn, a few lifted
    /// long ago; the socket its pole stands in; grass at its stones' feet;
    /// and about its heart what its keepers raised and its pilgrims left.
    static func holyDetail(_ b: inout MeshBuilder, kind: ShrineKind) {
        // The floor falls from 0.02 at its heart to 0.012 at its edge.
        func floor(_ radius: Float) -> Float { 0.02 - 0.008 * radius / 0.3 }
        let inner: Float
        switch kind {
        case .moonwell: inner = 0.135
        case .stillStone: inner = 0.19
        case .saltAltar: inner = 0.13
        case .brokenSpire: inner = 0.135
        case .heartstone: inner = 0.175
        }
        let middle = (inner + 0.292) / 2
        let courses: [(from: Float, to: Float, count: Int)] = [(inner, middle - 0.004, 9), (middle + 0.004, 0.292, 13)]
        for (course, ring) in courses.enumerated() {
            let step = 2 * Float.pi / Float(ring.count)
            for index in 0..<ring.count {
                let a0 = Float(index) * step + Float(course) * 0.31 + 0.1, a1 = a0 + step - 0.035
                let wear = Noise.unit(Int32(index), Int32(course + 60), 19)
                if wear < 0.1 {
                    // A flag lifted long ago, and grass come up where it lay
                    // if nothing has fallen there since.
                    if kind != .brokenSpire && kind != .heartstone {
                        let at = MeshBuilder.ring((ring.from + ring.to) / 2, floor(ring.to) + 0.01, (a0 + a1) / 2)
                        Land.grass(&b, at: at, tufts: 1, spread: 0.01, seed: UInt32(index + 40 * course))
                    }
                    continue
                }
                let lift = 0.003 + 0.002 * wear
                let (top0, top1) = (floor(ring.from) + lift, floor(ring.to) + lift)
                let (foot0, foot1) = (floor(ring.from) - 0.002, floor(ring.to) - 0.002)
                let colour = wear < 0.4 ? Palette.stonePale
                    : wear < 0.75 ? Palette.stonePale.mix(Palette.stoneWhite, 0.35) : Palette.stonePale.mix(Palette.stone, 0.25)
                let p = { (radius: Float, y: Float, angle: Float) in MeshBuilder.ring(radius, y, angle) }
                b.quad(p(ring.from, top0, a0), p(ring.to, top1, a0), p(ring.to, top1, a1), p(ring.from, top0, a1), color: colour)
                b.quad(p(ring.to, foot1, a0), p(ring.to, foot1, a1), p(ring.to, top1, a1), p(ring.to, top1, a0), color: colour)
                b.quad(p(ring.from, foot0, a1), p(ring.from, foot0, a0), p(ring.from, top0, a0), p(ring.from, top0, a1), color: colour)
                b.quad(p(ring.from, foot0, a0), p(ring.to, foot1, a0), p(ring.to, top1, a0), p(ring.from, top0, a0), color: colour)
                b.quad(p(ring.to, foot1, a1), p(ring.from, foot0, a1), p(ring.from, top0, a1), p(ring.to, top1, a1), color: colour)
            }
        }
        // The pole's socket of stone, and grass at every other stone's foot.
        b.place(.translation(Vec3(0.2, floor(0.283), -0.2))) {
            $0.lathe([(0.024, -0.004), (0.024, 0.022), (0.014, 0.03)], sides: 6, color: Palette.stoneDark)
        }
        for index in stride(from: 0, to: 7, by: 2) {
            let angle = Float(index) / 7 * 2 * .pi + 0.3
            Land.grass(&b, at: MeshBuilder.ring(0.42, 0.012, angle + 0.12), tufts: 2, spread: 0.025, seed: UInt32(index + 7))
        }
        switch kind {
        case .moonwell:
            // Its coping, a lamp burning on every third stone; an arch over
            // it crowned with the crescent, a silver bowl hung from it on a
            // chain to draw the moon's water; stones to kneel on before it.
            for index in 0..<9 {
                let angle = Float(index) / 9 * 2 * .pi + 0.17
                b.box(center: MeshBuilder.ring(0.12, 0.081, angle), size: Vec3(0.028, 0.012, 0.076), turn: angle,
                      color: index % 2 == 0 ? Palette.stonePale : Palette.stone)
                guard index % 3 == 1 else { continue }
                b.place(.translation(MeshBuilder.ring(0.12, 0.087, angle))) {
                    $0.lathe([(0.0, 0.0), (0.011, 0.003), (0.013, 0.012)], sides: 5, color: Palette.earth)
                    $0.with(material: .glow) { $0.cone(sides: 4, radius: 0.005, from: 0.01, to: 0.028, color: Palette.candle) }
                }
            }
            for x in [Float(-0.165), 0.165] {
                b.box(min: Vec3(x - 0.016, 0, -0.018), max: Vec3(x + 0.016, 0.3, 0.018), color: Palette.stonePale)
            }
            b.box(min: Vec3(-0.195, 0.3, -0.024), max: Vec3(0.195, 0.334, 0.024), color: Palette.stone)
            b.with(material: .crystal) {
                for index in 0..<6 {
                    let t = (Float(index) + 0.5) / 6
                    let angle = Float.pi * (1.1 + 0.8 * t)
                    let at = Vec3(Float(cos(Double(angle))), Float(sin(Double(angle))), 0) * 0.05 + Vec3(0, 0.39, 0)
                    $0.place(.translation(at) * .rotationZ(angle)) {
                        $0.box(center: .zero, size: Vec3(0.008 + 0.008 * Float(sin(Double(t) * .pi)), 0.03, 0.012), color: Palette.moonGlow)
                    }
                }
                $0.lathe([(0.027, 0.18), (0.0, 0.181)], sides: 7, color: Palette.moonGlow)
            }
            b.with(material: .metal) {
                $0.limb(from: Vec3(0, 0.3, 0), to: Vec3(0, 0.183, 0), radius: 0.0025, color: Palette.iron)
                $0.tube([(0.0, 0.16), (0.022, 0.165), (0.03, 0.185)], sides: 7, color: Palette.steel)
            }
            for (index, angle) in [Float(4.25), 4.71, 5.17].enumerated() {
                b.rock(center: MeshBuilder.ring(0.205, floor(0.205) + 0.006, angle), size: Vec3(0.034, 0.012, 0.026), rings: 2, sides: 6,
                       jitter: 0.12, seed: UInt32(index + 130), color: Palette.stone)
            }
        case .stillStone:
            // Pilgrims' ribbons tied about the ring's stones, stirring in
            // the wind about the stone that never stirs; a kerb about it,
            // and cairns of flat stones its pilgrims have left.
            let wind = Vec3(0.94, 0, 0.34).normalized
            let colours = [Palette.madder, Palette.weld, Palette.seaWool, Palette.linen]
            for index in 0..<7 {
                let angle = Float(index) / 7 * 2 * .pi + 0.3
                let lean: Float = index % 2 == 0 ? 0.05 : -0.04
                b.place(.translation(MeshBuilder.ring(0.36, 0, angle)) * .rotationY(angle) * .rotationZ(lean)) {
                    $0.tube([(0.054, 0.15), (0.054, 0.168)], sides: 4, color: Palette.leatherDark, twist: 0.3)
                }
                // The cord's corner most downwind, where its ribbons are knotted.
                let corner = (0..<4).map { angle + 0.3 + Float($0) * .pi / 2 }
                    .max { MeshBuilder.ring(1, 0, $0).dot(wind) < MeshBuilder.ring(1, 0, $1).dot(wind) } ?? angle
                let knot = MeshBuilder.ring(0.36 - 0.159 * lean, 0.159, angle) + MeshBuilder.ring(0.054, 0, corner)
                let side = wind.cross(.up).normalized
                for strand in 0..<2 {
                    let long = 0.08 + 0.03 * Float(strand) + 0.02 * Noise.unit(Int32(index), Int32(strand), 77)
                    // Built measuring down from the knot, so the wind stirs
                    // its tail and never the knot; not cloth, which would
                    // take the holder's colour.
                    b.place(.translation(knot + side * (0.007 * Float(strand * 2 - 1))) * .scale(Vec3(1, -1, 1))) {
                        $0.with(sway: 0.9) {
                            $0.swayRange = (0, long)
                            let across = wind * 0.016
                            let tail = wind * (0.03 + 0.03 * Float(strand)) + side * (0.012 * Float(strand * 2 - 1)) + Vec3(0, long, 0)
                            $0.sheet([.zero, across, tail + across, tail], normal: side, thickness: 0.002,
                                     color: colours[(index + strand * 2) % colours.count])
                        }
                    }
                }
            }
            for index in 0..<10 {
                let angle = Float(index) / 10 * 2 * .pi + 0.2
                b.rock(center: MeshBuilder.ring(0.162, floor(0.162) + 0.004, angle), size: Vec3(0.026, 0.014, 0.022), rings: 2, sides: 4,
                       jitter: 0.2, seed: UInt32(index + 170), color: index % 2 == 0 ? Palette.stoneDark : Palette.stone)
            }
            for (index, angle) in [Float(0.2), 2.2, 3.7, 5.2].enumerated() {
                let at = MeshBuilder.ring(0.225, floor(0.225), angle)
                for (layer, size) in [Float(0.028), 0.022, 0.016].enumerated() {
                    b.rock(center: at + Vec3(0.004 * Float(layer), 0.008 + 0.018 * Float(layer), 0), size: Vec3(size, size * 0.4, size * 0.85),
                           rings: 2, sides: 5, jitter: 0.15, seed: UInt32(index * 3 + layer + 150),
                           color: layer % 2 == 0 ? Palette.slate : Palette.stone)
                }
            }
        case .saltAltar:
            // The altar on a step, its top slab overhanging, a crescent cut
            // in its face; bowls of salt and a salt-knife on it, candles
            // either side, sacks of moonsalt brought to it, and moonsalt
            // grown up from the floor behind it.
            b.box(center: Vec3(0, 0.0175, 0.01), size: Vec3(0.3, 0.035, 0.22), color: Palette.stone)
            b.box(center: Vec3(0, 0.012, 0.135), size: Vec3(0.2, 0.024, 0.03), color: Palette.stone)
            b.box(center: Vec3(0, 0.106, 0), size: Vec3(0.23, 0.014, 0.155), color: Palette.stonePale.mix(Palette.stoneWhite, 0.3))
            b.box(center: Vec3(0, 0.06, 0.067), size: Vec3(0.15, 0.05, 0.004), color: Palette.stone)
            b.with(material: .crystal) {
                for index in 0..<4 {
                    let t = (Float(index) + 0.5) / 4
                    let angle = Float.pi * (1.15 + 0.7 * t)
                    let at = Vec3(Float(cos(Double(angle))), Float(sin(Double(angle))), 0) * 0.016 + Vec3(0, 0.07, 0.07)
                    $0.place(.translation(at) * .rotationZ(angle)) {
                        $0.box(center: .zero, size: Vec3(0.005, 0.012, 0.003), color: Palette.moonGlow)
                    }
                }
            }
            for x in [Float(-0.08), 0.08] {
                b.place(.translation(Vec3(x, 0.113, 0.045))) {
                    $0.with(material: .metal) { $0.lathe([(0.0, 0.0), (0.016, 0.004), (0.022, 0.016)], sides: 7, color: Palette.bronze) }
                    $0.with(material: .crystal) { $0.cone(sides: 6, radius: 0.019, from: 0.012, to: 0.03, color: Palette.saltCrust) }
                }
            }
            b.with(material: .metal) {
                $0.sheet([Vec3(-0.005, 0.1135, 0.058), Vec3(0.04, 0.1135, 0.06), Vec3(0.04, 0.1135, 0.064), Vec3(-0.005, 0.1135, 0.067)],
                         normal: .up, thickness: 0.002, color: Palette.steel)
            }
            b.limb(from: Vec3(-0.006, 0.117, 0.0625), to: Vec3(-0.035, 0.117, 0.0625), radius: 0.004, color: Palette.timberDark)
            for x in [Float(-0.19), 0.19] {
                let foot = Vec3(x, floor(0.19), 0.03)
                b.with(material: .metal) {
                    $0.limb(from: foot, to: foot + Vec3(0, 0.22, 0), radius: 0.005, color: Palette.iron)
                    for leg in 0..<3 {
                        let angle = Float(leg) * 2 * .pi / 3 + 0.4
                        $0.limb(from: foot + Vec3(0, 0.05, 0), to: foot + MeshBuilder.ring(0.032, 0, angle), radius: 0.003, sides: 3,
                                color: Palette.iron)
                    }
                    $0.place(.translation(foot + Vec3(0, 0.215, 0))) {
                        $0.lathe([(0.0, 0.0), (0.02, 0.005), (0.022, 0.012)], sides: 6, color: Palette.iron)
                    }
                }
                b.place(.translation(foot + Vec3(0, 0.222, 0))) {
                    $0.prism(sides: 5, radius: 0.008, from: 0, to: 0.04, color: Palette.linen)
                    $0.with(material: .glow) { $0.cone(sides: 4, radius: 0.006, from: 0.04, to: 0.063, color: Palette.candle) }
                }
            }
            for (at, size) in [(Vec3(-0.17, 0.012, 0.135), Float(1)), (Vec3(-0.13, 0.012, 0.185), 0.85)] {
                b.place(.translation(at) * .scale(Vec3(size, size, size))) {
                    $0.lathe([(0.0, 0.0), (0.022, 0.004), (0.027, 0.02), (0.021, 0.036), (0.008, 0.044), (0.011, 0.05), (0.0, 0.052)], sides: 6,
                             color: Palette.canvas)
                }
            }
            b.with(material: .crystal) {
                $0.place(.translation(Vec3(-0.095, 0.012, 0.19))) { $0.cone(sides: 6, radius: 0.026, to: 0.022, color: Palette.saltCrust) }
            }
            Land.crystals(&b, at: Vec3(0.02, 0.015, -0.19), count: 4, height: 0.07, seed: 143)
        case .brokenSpire:
            // Carved bands about the shaft, moonsalt glinting in its seams;
            // its head, snapped off and fallen out between two stones of the
            // ring, the moonsalt it was crowned with lying in the grass; rubble.
            b.place(.rotationZ(0.12) * .rotationX(-0.06)) {
                for (y, radius) in [(Float(0.2), Float(0.109)), (0.44, 0.0935)] {
                    $0.tube([(radius, y - 0.012), (radius + 0.008, y - 0.006), (radius + 0.008, y + 0.006), (radius, y + 0.012)],
                            sides: 7, color: Palette.stone, twist: 0.15)
                }
                $0.with(material: .crystal) {
                    for (y, radius, turn) in [(Float(0.3), Float(0.097), Float(0.6)), (0.53, 0.0824, 2.4), (0.12, 0.1076, 4.4)] {
                        $0.place(.translation(Vec3(0, y, 0)) * .rotationY(turn)) {
                            $0.box(center: Vec3(radius, 0, 0), size: Vec3(0.016, 0.05, 0.022), color: Palette.moonGlow)
                        }
                    }
                }
            }
            let fall: Float = 2.544
            b.place(.translation(MeshBuilder.ring(0.17, 0.06, fall)) * Mat4.aligningUp(to: MeshBuilder.ring(1, -0.06, fall))) {
                $0.lathe([(0.068, 0.0), (0.064, 0.1), (0.055, 0.2), (0.04, 0.28), (0.0, 0.31)], sides: 7, color: Palette.stonePale, twist: 0.4)
                $0.with(material: .crystal) {
                    $0.cone(sides: 6, radius: 0.022, from: 0.27, to: 0.36, color: Palette.moonsalt)
                }
            }
            for (index, at) in [Vec3(0.25, 0.012, -0.05), Vec3(-0.05, 0.012, 0.22), Vec3(0.16, 0.012, 0.18), Vec3(-0.26, 0.012, -0.02),
                                Vec3(0.02, 0.012, 0.25)].enumerated() {
                let size = 0.018 + 0.01 * Noise.unit(Int32(index), 5, 88)
                b.rock(center: at, size: Vec3(size * 1.2, size * 0.8, size), rings: 2, sides: 5, jitter: 0.2, seed: UInt32(index + 180),
                       color: index % 2 == 0 ? Palette.stonePale : Palette.stone)
            }
        case .heartstone:
            // Braziers burning at its four quarters; swords offered point
            // down in the ground about its plinth and shields of fallen
            // Houses laid against it; runes cut in the plinth, glowing.
            for index in 0..<4 {
                let angle = Float(index) * .pi / 2
                let at = MeshBuilder.ring(0.235, floor(0.235), angle)
                b.with(material: .metal) {
                    for leg in 0..<3 {
                        let out = MeshBuilder.ring(0.03, 0, angle + Float(leg) * 2 * .pi / 3 + 0.5)
                        $0.limb(from: at + out, to: at + Vec3(0, 0.125, 0) + out * 0.4, radius: 0.004, sides: 3, color: Palette.iron)
                    }
                    $0.place(.translation(at + Vec3(0, 0.12, 0))) {
                        $0.lathe([(0.0, 0.0), (0.03, 0.012), (0.036, 0.03)], sides: 6, color: Palette.iron)
                    }
                }
                b.with(material: .glow) {
                    $0.place(.translation(at + Vec3(0, 0.12, 0))) {
                        $0.lathe([(0.03, 0.02), (0.033, 0.04), (0.0, 0.09)], sides: 5, color: Palette.fire)
                    }
                }
            }
            for index in 0..<8 {
                let angle = Float(index) * .pi / 4 + .pi / 8
                let tilt = 0.14 * (Noise.unit(Int32(index), 3, 91) - 0.5)
                b.place(.translation(MeshBuilder.ring(0.205, floor(0.205), angle)) * .rotationY(angle) * .rotationZ(tilt)) {
                    $0.with(material: .metal) {
                        $0.sheet([Vec3(0, 0, -0.002), Vec3(0, 0, 0.002), Vec3(0, 0.09, 0.007), Vec3(0, 0.09, -0.007)], normal: Vec3(1, 0, 0),
                                 thickness: 0.002, color: Palette.steel)
                        $0.box(center: Vec3(0, 0.093, 0), size: Vec3(0.008, 0.007, 0.04), color: Palette.iron)
                        $0.box(center: Vec3(0, 0.134, 0), size: Vec3(0.01, 0.01, 0.01), color: Palette.bronze)
                    }
                    $0.limb(from: Vec3(0, 0.096, 0), to: Vec3(0, 0.13, 0), radius: 0.004, color: Palette.leatherDark)
                }
            }
            let shields = [Palette.madder, Palette.seaWool, Palette.weld, Palette.woolDark]
            for (index, angle) in [Float(0.75), 1.25, 1.75, 0.25].map({ $0 * .pi }).enumerated() {
                b.place(.translation(MeshBuilder.ring(0.19, 0.038, angle)) * .rotationY(angle) * .rotationZ(-1.05)) {
                    $0.lathe([(0.04, -0.005), (0.04, 0.003), (0.0, 0.007)], sides: 8, color: shields[index])
                    $0.with(material: .metal) { $0.cone(sides: 5, radius: 0.01, from: 0.006, to: 0.016, color: Palette.iron) }
                }
            }
            b.with(material: .crystal) {
                for index in 0..<8 {
                    let angle = (Float(index) + 0.5) * .pi / 4
                    $0.place(.translation(MeshBuilder.ring(0.1212, 0.0625, angle)) * .rotationY(angle)) {
                        $0.box(center: .zero, size: Vec3(0.003, 0.02, 0.005), color: Palette.moonGlow)
                        $0.box(center: Vec3(0, index % 2 == 0 ? 0.004 : -0.003, 0.005), size: Vec3(0.003, 0.004, 0.008), color: Palette.moonGlow)
                    }
                }
            }
        }
    }

    /// An alliance's standard: a tall pole on a cairn, a crossbar and a long
    /// swallow-tailed banner in the alliance's colour, braziers at its foot.
    static func standard(name: String) -> Model {
        var b = MeshBuilder()
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
        // Braziers at its foot, burning.
        for x in [Float(-0.14), 0.14] {
            b.limb(from: Vec3(x, 0.0, 0.16), to: Vec3(x, 0.12, 0.16), radius: 0.008, color: Palette.iron)
            b.lathe([(0.0, 0.11), (0.035, 0.12), (0.04, 0.15)], sides: 6, color: Palette.iron)
            b.with(material: .glow) {
                $0.place(.translation(Vec3(x, 0.14, 0.16))) {
                    $0.lathe([(0.03, 0), (0.035, 0.025), (0.0, 0.07)], sides: 5, color: Palette.fire)
                }
            }
        }
        return Model(name: name, mesh: b.mesh)
    }

    static func site(_ resource: Resource, name: String) -> Model {
        var b = MeshBuilder()
        switch resource {
        case .grain: grainField(&b)
        case .timber: timberStand(&b)
        case .stone: outcrop(&b)
        case .moonsalt: moonsaltPan(&b)
        }
        return Model(name: name, mesh: b.mesh)
    }

    static func grainField(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.55, -0.08, -0.45), max: Vec3(0.55, 0.006, 0.45), color: Palette.loam)
        // Rows of standing grain, a little ragged, with a few ears above them.
        b.with(material: .foliage, sway: 0.8) {
            $0.swayRange = (0.0, 0.1)
            for row in 0..<8 {
                let z = Float(row) * 0.11 - 0.385
                for length in 0..<3 {
                    let jitter = Noise.unit(Int32(row), Int32(length), 91)
                    let x0 = Float(length) * 0.35 - 0.52, x1 = x0 + 0.33
                    $0.beam(from: Vec3(x0, 0.03 + 0.012 * jitter, z), to: Vec3(x1, 0.03 + 0.012 * jitter, z), width: 0.075,
                            depth: 0.09 + 0.025 * jitter, color: (row + length) % 3 == 0 ? Palette.straw : Palette.grain)
                    $0.place(.translation(Vec3((x0 + x1) / 2 + (jitter - 0.5) * 0.2, 0.05, z))) {
                        $0.cone(sides: 3, radius: 0.02, to: 0.1, color: Palette.straw, twist: jitter * 3)
                    }
                }
            }
        }
        // Stooks of sheaves at the field's edge.
        for (index, at) in [Vec3(0.42, 0, 0.5), Vec3(0.25, 0, 0.55), Vec3(-0.38, 0, 0.52)].enumerated() {
            b.place(.translation(at) * .rotationY(Float(index))) {
                $0.lathe([(0.05, -0.01), (0.04, 0.08), (0.06, 0.1), (0, 0.15)], sides: 5, color: Palette.straw)
            }
        }
    }

    static func timberStand(_ b: inout MeshBuilder) {
        for (index, at) in [Vec3(-0.3, 0, -0.25), Vec3(0.05, 0, -0.38), Vec3(0.35, 0, -0.2), Vec3(-0.45, 0, 0.1), Vec3(0.42, 0, 0.18)]
            .enumerated() {
            fir(&b, at: at, scale: 1.1 + 0.15 * Float(index % 3))
        }
        // Stumps, a felled trunk, a pile of logs and an axe left in a stump.
        for at in [Vec3(-0.08, 0, -0.08), Vec3(0.18, 0, 0.0), Vec3(-0.22, 0, 0.22)] {
            b.place(.translation(at)) {
                $0.lathe([(0.04, -0.04), (0.035, 0.04)], sides: 5, color: Palette.bark, colors: [Palette.bark, Palette.timberPale])
            }
        }
        b.log(from: Vec3(-0.05, 0.03, 0.12), to: Vec3(0.38, 0.03, 0.42), radius: 0.03)
        for index in 0..<5 {
            let layer = Float(index / 3), slot = Float(index % 3)
            let y = 0.025 + layer * 0.042
            let z = 0.3 + slot * 0.05 + layer * 0.025
            b.log(from: Vec3(-0.45, y, z), to: Vec3(-0.15, y, z), radius: 0.024)
        }
        b.beam(from: Vec3(0.18, 0.04, 0.0), to: Vec3(0.24, 0.13, 0.05), width: 0.012, color: Palette.timberPale)
        b.with(material: .metal) {
            $0.box(center: Vec3(0.185, 0.045, 0.004), size: Vec3(0.012, 0.03, 0.05), turn: 0.6, color: Palette.iron)
        }
    }

    static func outcrop(_ b: inout MeshBuilder) {
        b.rock(center: Vec3(0, 0.1, -0.2), size: Vec3(0.42, 0.26, 0.24), rings: 4, sides: 8, jitter: 0.2, seed: 101, color: Palette.rock)
        b.rock(center: Vec3(0.35, 0.05, 0.05), size: Vec3(0.16, 0.12, 0.14), rings: 3, sides: 6, jitter: 0.25, seed: 102,
               color: Palette.stoneDark)
        // Faces cut back in steps.
        for step in 0..<3 {
            let y = Float(step) * 0.07
            b.box(min: Vec3(-0.28 + Float(step) * 0.04, -0.04, -0.08 - Float(step) * 0.05),
                  max: Vec3(0.2 - Float(step) * 0.04, y + 0.06, -0.02 - Float(step) * 0.05), color: Palette.stonePale)
        }
        b.blocks(at: Vec3(-0.15, 0, 0.2), count: 6, seed: 17)
        b.blocks(at: Vec3(0.15, 0, 0.28), count: 4, seed: 18)
        b.place(.translation(Vec3(0.38, 0, 0.32)) * .rotationY(0.6)) {
            for x in [Float(-0.035), 0.035] {
                $0.box(min: Vec3(x - 0.008, 0, -0.07), max: Vec3(x + 0.008, 0.016, 0.07), color: Palette.timberDark)
            }
            $0.box(min: Vec3(-0.05, 0.016, -0.06), max: Vec3(0.05, 0.026, 0.06), color: Palette.timber)
        }
    }

    static func moonsaltPan(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.5, -0.08, -0.4), max: Vec3(0.5, 0.004, 0.4), color: Palette.saltCrust.mix(Palette.earth, 0.5))
        for (index, at) in [Vec3(-0.25, 0, -0.18), Vec3(0.05, 0, -0.18), Vec3(0.35, 0, -0.18), Vec3(-0.25, 0, 0.12),
                            Vec3(0.05, 0, 0.12)].enumerated() {
            b.saltPan(at: at, size: 0.26, crust: index % 2 == 0 ? 0.95 : 0.7)
        }
        crystals(&b, at: Vec3(0.36, 0, 0.14), count: 7, height: 0.17, seed: 23)
        crystals(&b, at: Vec3(-0.42, 0, 0.32), count: 5, height: 0.12, seed: 24)
        b.saltHeap(at: Vec3(0.2, 0, 0.32), radius: 0.08, height: 0.09)
        b.saltHeap(at: Vec3(-0.08, 0, 0.34), radius: 0.06, height: 0.07)
        b.beam(from: Vec3(0.42, 0.0, 0.36), to: Vec3(0.3, 0.2, 0.3), width: 0.012, color: Palette.timberPale)
        b.box(center: Vec3(0.3, 0.2, 0.3), size: Vec3(0.08, 0.012, 0.02), turn: 0.4, color: Palette.timberPale)
    }
}
