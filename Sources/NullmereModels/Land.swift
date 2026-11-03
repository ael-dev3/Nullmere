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
        var rig = Rig()
        var wheels: [Machinery.Wheel] = []
        var flames: [UInt16] = []
        // Lintels laid across the ring's stones, pair by pair, the gap at
        // its east left open for the way in.
        for index in 0..<6 where index != 2 {
            let a = MeshBuilder.ring(0.36, 0.285, Float(index) / 7 * 2 * .pi + 0.3)
            let c = MeshBuilder.ring(0.36, 0.285, Float(index + 1) / 7 * 2 * .pi + 0.3)
            b.beam(from: a, to: c, width: 0.045, depth: 0.04, color: index % 2 == 0 ? Palette.stone : Palette.stoneDark)
        }
        // The way in: two lines of lesser stones outside the ring's gap, and
        // a brazier burning at either side of the gap.
        let gap = (Float(2.5) / 7 * 2 * .pi) + 0.3
        for step in 1...3 {
            for side in [Float(-1), 1] {
                let at = MeshBuilder.ring(0.36 + Float(step) * 0.07, 0, gap + side * 0.12)
                b.place(.translation(at)) {
                    $0.lathe([(0.025, -0.02), (0.022, 0.07 - Float(step) * 0.01), (0.0, 0.085 - Float(step) * 0.01)], sides: 5,
                             color: Palette.stoneDark, twist: 0.4)
                }
            }
        }
        for side in [Float(-1), 1] {
            let at = MeshBuilder.ring(0.43, 0, gap + side * 0.25)
            b.place(.translation(at)) {
                $0.lathe([(0.025, 0), (0.014, 0.08), (0.03, 0.1), (0.034, 0.115)], sides: 7, color: Palette.bronze)
            }
            flames.append(Beacon.flame(&b, &rig, at: at + Vec3(0, 0.115, 0), size: 0.03))
        }
        // The ring.
        for index in 0..<7 {
            let angle = Float(index) / 7 * 2 * .pi + 0.3
            b.place(.translation(MeshBuilder.ring(0.36, 0, angle)) * .rotationY(angle) * .rotationZ(index % 2 == 0 ? 0.05 : -0.04)) {
                $0.lathe([(0.05, -0.06), (0.05, 0.17), (0.035, 0.27), (0.0, 0.29)], sides: 6,
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
            // Motes of moonlight circling slowly over the water.
            wheels.append(motes(&b, &rig, at: Vec3(0, 0.14, 0), radius: 0.08, count: 5, color: Palette.moonGlow))
        case .stillStone:
            b.place(.rotationY(0.4)) {
                $0.lathe([(0.11, 0.0), (0.12, 0.12), (0.08, 0.3), (0.0, 0.33)], sides: 5, color: Palette.slate, twist: 0.1)
            }
            // Its stillness: a ring of black water-drops held in the air
            // about it, turning so slowly it seems to stand.
            wheels.append(motes(&b, &rig, at: Vec3(0, 0.2, 0), radius: 0.17, count: 7, color: Palette.slate))
        case .saltAltar:
            b.box(center: Vec3(0, 0.05, 0), size: Vec3(0.2, 0.1, 0.13), color: Palette.stonePale)
            b.material = .crystal
            for (x, z, h) in [(Float(-0.05), Float(0.0), Float(0.09)), (0.02, 0.02, 0.13), (0.06, -0.02, 0.07)] {
                b.place(.translation(Vec3(x, 0, z))) { $0.cone(sides: 5, radius: 0.025, from: 0.1, to: 0.1 + h, color: Palette.moonsalt) }
            }
            b.material = .plain
            // A crown of salt crystals turning over the altar.
            wheels.append(motes(&b, &rig, at: Vec3(0, 0.3, 0), radius: 0.06, count: 6, color: Palette.moonsalt))
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
            // The shards of its crown, still turning where it broke.
            wheels.append(motes(&b, &rig, at: Vec3(0.09, 0.78, 0), radius: 0.1, count: 4, color: Palette.stonePale))
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
            // Its halo: moonsalt motes circling its crown.
            wheels.append(motes(&b, &rig, at: Vec3(0, 0.6, 0), radius: 0.12, count: 8, color: Palette.moonGlow))
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
        let machinery = Machinery(wheels: wheels, flames: flames, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// Motes held in the air in a ring about a holy site's heart, turning
    /// as one; returns their turning.
    static func motes(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3, radius: Float, count: Int, color: Vec3) -> Machinery.Wheel {
        let part = rig.add("holy motes", pivot: at)
        b.with(part: part, material: .crystal) {
            for index in 0..<count {
                let angle = Float(index) / Float(count) * 2 * .pi
                $0.place(.translation(at + MeshBuilder.ring(radius, 0.02 * Float(index % 2), angle))) {
                    $0.lathe([(0.0, -0.014), (0.01, 0.0), (0.0, 0.016)], sides: 5, color: color)
                }
            }
        }
        return .init(part: part, axis: Vec3(0, 1, 0), turns: 1)
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
            b.tiedSack(at: Vec3(-0.17, 0.012, 0.135), size: 1)
            b.tiedSack(at: Vec3(-0.13, 0.012, 0.185), size: 0.85)
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

    static func site(_ resource: Resource, name: String) -> Model {
        var b = MeshBuilder()
        switch resource {
        case .grain: grainField(&b)
        case .timber: timberStand(&b)
        case .stone: outcrop(&b)
        case .moonsalt: moonsaltPan(&b)
        }
        b.fine { near in
            switch resource {
            case .grain: grainNear(&near)
            case .timber: timberNear(&near)
            case .stone: outcropNear(&near)
            case .moonsalt: saltPanNear(&near)
            }
        }
        return Model(name: name, mesh: b.mesh)
    }

    /// A grain field drawn near: a scarecrow between its rows, a handcart of
    /// sheaves at its edge with a jug by it, a scythe against a stook, and
    /// crows come for the grain.
    static func grainNear(_ b: inout MeshBuilder) {
        // The scarecrow, a sack for its head and a hat on that.
        let post = Vec3(0.1, 0, 0)
        b.limb(from: post, to: post + Vec3(0, 0.3, 0), radius: 0.006, color: Palette.timberDark)
        b.limb(from: post + Vec3(-0.07, 0.245, 0), to: post + Vec3(0.07, 0.245, 0), radius: 0.005, color: Palette.timberDark)
        b.box(center: post + Vec3(0, 0.21, 0), size: Vec3(0.06, 0.075, 0.028), color: Palette.woolDark)
        for side in [Float(-1), 1] {
            b.limb(from: post + Vec3(side * 0.028, 0.243, 0), to: post + Vec3(side * 0.062, 0.238, 0), radius: 0.011, sides: 5,
                   color: Palette.woolDark)
            b.place(.translation(post + Vec3(side * 0.062, 0.238, 0)) * .rotationZ(-side * .pi / 2)) {
                $0.cone(sides: 4, radius: 0.009, to: 0.02, color: Palette.straw)
            }
        }
        b.sphere(center: post + Vec3(0, 0.272, 0), radius: 0.02, rings: 3, sides: 6, color: Palette.linen)
        b.place(.translation(post + Vec3(0, 0.286, 0))) {
            $0.lathe([(0.034, 0), (0.034, 0.004), (0.016, 0.006), (0.014, 0.03), (0.0, 0.032)], sides: 7, color: Palette.leatherDark)
        }
        // The handcart, turned along the field's edge, its handles west.
        b.place(.translation(Vec3(-0.05, 0, 0.51)) * .rotationY(.pi / 2)) {
            $0.box(min: Vec3(-0.06, 0.055, -0.07), max: Vec3(0.06, 0.085, 0.07), color: Palette.timberPale)
            for x in [Float(-0.075), 0.075] {
                $0.wheel(center: Vec3(x, 0.045, 0), radius: 0.045, width: 0.012, spokes: 3, color: Palette.timber, rim: Palette.timberDark)
                $0.limb(from: Vec3(x * 0.6, 0.075, -0.07), to: Vec3(x * 0.6, 0.04, -0.17), radius: 0.005, color: Palette.timberDark)
            }
            $0.limb(from: Vec3(0, 0.06, 0.065), to: Vec3(0, 0, 0.07), radius: 0.005, color: Palette.timberDark)
            for (index, x) in [Float(-0.035), 0.0, 0.035].enumerated() {
                let y: Float = index == 1 ? 0.125 : 0.1
                $0.beam(from: Vec3(x, y, -0.06), to: Vec3(x, y, 0.06), width: 0.034, depth: 0.03, color: Palette.straw)
            }
        }
        b.place(.translation(Vec3(0.08, 0, 0.53))) {
            $0.lathe([(0.0, 0.0), (0.018, 0.002), (0.022, 0.025), (0.012, 0.045), (0.008, 0.055), (0.01, 0.06), (0.0, 0.059)], sides: 7,
                     color: Palette.earth.mix(Palette.madder, 0.3))
        }
        // A scythe against a stook, its blade by the stubble.
        b.limb(from: Vec3(0.36, 0.01, 0.56), to: Vec3(0.43, 0.24, 0.5), radius: 0.004, color: Palette.timber)
        for t in [Float(0.35), 0.7] {
            let at = Vec3(0.36, 0.01, 0.56) + (Vec3(0.43, 0.24, 0.5) - Vec3(0.36, 0.01, 0.56)) * t
            b.limb(from: at, to: at + Vec3(0.0, 0.006, 0.025), radius: 0.003, sides: 3, color: Palette.timber)
        }
        b.with(material: .metal) {
            $0.sheet([Vec3(0.36, 0.014, 0.56), Vec3(0.3, 0.012, 0.552), Vec3(0.26, 0.008, 0.535), Vec3(0.31, 0.018, 0.559)],
                     normal: Vec3(0.05, 1, 0.2), thickness: 0.002, color: Palette.steel)
        }
        // Crows come for the grain.
        Lairs.raven(&b, at: Vec3(-0.3, 0.09, -0.165), facing: 0.8, seed: 281)
        Lairs.raven(&b, at: Vec3(0.33, 0.004, 0.47), facing: 2.6, seed: 282)
    }

    /// A stand of firs drawn near: the stubs of branches lopped from its
    /// felled trunk and their greenery heaped, chips about its stumps, a
    /// sawhorse with a log in it and a saw in its cut, sawdust under it,
    /// and a maul by the log pile.
    static func timberNear(_ b: inout MeshBuilder) {
        let from = Vec3(-0.05, 0.03, 0.12), to = Vec3(0.38, 0.03, 0.42)
        for (index, t) in [Float(0.2), 0.42, 0.6, 0.8].enumerated() {
            let flank: Float = index % 2 == 0 ? 1 : -1
            let at = from + (to - from) * t
            let out = (to - from).normalized.cross(.up) * (0.028 * flank) + Vec3(0, 0.012, 0)
            b.limb(from: at, to: at + out * 1.6, radius: 0.007, topRadius: 0.006, sides: 4, color: Palette.bark)
        }
        for (index, angle) in [Float(0.2), 1.4, 2.5, 3.5, 4.6].enumerated() {
            let at = Vec3(0.15, 0.008, -0.11) + MeshBuilder.ring(0.012 * Float(index % 3), 0, angle)
            b.limb(from: at, to: at + MeshBuilder.ring(0.07, 0.03, angle), radius: 0.014, topRadius: 0.002, sides: 4,
                   color: index % 2 == 0 ? Palette.fir : Palette.firDark)
        }
        for (stump, at) in [Vec3(-0.08, 0, -0.08), Vec3(0.18, 0, 0.0), Vec3(-0.22, 0, 0.22)].enumerated() {
            for chip in 0..<6 {
                let angle = Float(chip) * 1.05 + Float(stump) * 0.7
                let centre = at + MeshBuilder.ring(0.055 + 0.015 * Noise.unit(Int32(chip), Int32(stump), 293), 0.003, angle)
                let a = MeshBuilder.ring(0.008, 0, angle + 0.4), c = MeshBuilder.ring(0.006, 0, angle + 2.1)
                b.face([centre + a, centre + c, centre - a, centre - c], outward: .up, color: Palette.timberPale)
            }
        }
        // The sawhorse and its log, the saw standing in its cut.
        let horse = Vec3(0.0, 0, 0.47)
        for x in [Float(-0.05), 0.05] {
            for z in [Float(-0.04), 0.04] {
                b.limb(from: horse + Vec3(x, 0, z), to: horse + Vec3(x, 0.09, -z * 0.75), radius: 0.005, sides: 3, color: Palette.timber)
            }
        }
        b.log(from: horse + Vec3(-0.12, 0.085, 0), to: horse + Vec3(0.13, 0.085, 0.005), radius: 0.022)
        b.with(material: .metal) {
            $0.sheet([horse + Vec3(0.08, 0.075, -0.06), horse + Vec3(0.08, 0.075, 0.06), horse + Vec3(0.08, 0.1, 0.06),
                      horse + Vec3(0.08, 0.1, -0.06)], normal: Vec3(1, 0, 0), thickness: 0.002, color: Palette.steel)
        }
        for z in [Float(-0.075), 0.075] {
            b.limb(from: horse + Vec3(0.08, 0.075, z), to: horse + Vec3(0.08, 0.125, z), radius: 0.005, sides: 4, color: Palette.timberDark)
        }
        b.place(.translation(horse)) { $0.lathe([(0.055, 0.0), (0.0, 0.012)], sides: 7, color: Palette.timberPale) }
        // A maul by the log pile.
        b.limb(from: Vec3(-0.38, 0.012, 0.24), to: Vec3(-0.29, 0.012, 0.245), radius: 0.005, color: Palette.timber)
        b.with(material: .metal) {
            $0.box(center: Vec3(-0.39, 0.016, 0.24), size: Vec3(0.02, 0.026, 0.04), color: Palette.iron)
        }
    }

    /// An outcrop drawn near: the marks of the chisel down its cut faces,
    /// wedges driven along a split in its lowest step with the hammer that
    /// drove them, a pick, rubble at its foot, a bucket, and a rope coiled
    /// and a bar on the sledge.
    static func outcropNear(_ b: inout MeshBuilder) {
        for step in 0..<3 {
            let front = -0.02 - Float(step) * 0.05 + 0.0012, top = Float(step) * 0.07 + 0.06
            let left = -0.28 + Float(step) * 0.04, right = 0.2 - Float(step) * 0.04
            for index in 0..<5 {
                let x = left + (right - left) * (Float(index) + 0.5) / 5 + 0.01 * (Noise.unit(Int32(index), Int32(step), 301) - 0.5)
                b.quad(Vec3(x - 0.0015, top - 0.075, front), Vec3(x + 0.0015, top - 0.075, front), Vec3(x + 0.0015, top - 0.005, front),
                       Vec3(x - 0.0015, top - 0.005, front), color: Palette.stone)
            }
        }
        // The split along the lowest step's top, its wedges and their hammer.
        b.quad(Vec3(-0.24, 0.0602, -0.052), Vec3(-0.24, 0.0602, -0.048), Vec3(0.16, 0.0602, -0.048), Vec3(0.16, 0.0602, -0.052),
               color: Palette.barkBlack)
        b.with(material: .metal) {
            for x in [Float(-0.16), -0.06, 0.04, 0.12] {
                $0.box(center: Vec3(x, 0.068, -0.05), size: Vec3(0.012, 0.018, 0.008), color: Palette.iron)
            }
            $0.box(center: Vec3(-0.3, 0.012, 0.0), size: Vec3(0.045, 0.024, 0.026), color: Palette.iron)
            $0.place(.translation(Vec3(0.24, 0.0, 0.06)) * .rotationZ(0.5)) {
                $0.box(center: Vec3(0, 0.15, 0), size: Vec3(0.09, 0.012, 0.012), color: Palette.iron)
            }
        }
        b.limb(from: Vec3(-0.3, 0.012, 0.0), to: Vec3(-0.27, 0.11, -0.06), radius: 0.005, color: Palette.timber)
        b.place(.translation(Vec3(0.24, 0.0, 0.06)) * .rotationZ(0.5)) {
            $0.limb(from: .zero, to: Vec3(0, 0.15, 0), radius: 0.005, color: Palette.timber)
        }
        // Rubble at the face's foot, a bucket by it.
        for (index, at) in [Vec3(-0.22, 0.01, 0.03), Vec3(-0.12, 0.01, 0.05), Vec3(0.05, 0.01, 0.04), Vec3(0.12, 0.01, 0.06)].enumerated() {
            b.rock(center: at, size: Vec3(0.022, 0.012, 0.018), rings: 2, sides: 5, jitter: 0.25, seed: UInt32(index + 305),
                   color: index % 2 == 0 ? Palette.stonePale : Palette.stone)
        }
        b.place(.translation(Vec3(0.02, 0, 0.12))) {
            $0.lathe([(0.0, 0.0), (0.02, 0.0), (0.024, 0.04), (0.0, 0.041)], sides: 7, color: Palette.timberPale)
            $0.with(material: .metal) { $0.tube([(0.025, 0.032), (0.025, 0.037)], sides: 7, color: Palette.iron) }
        }
        // A rope coiled on the sledge and a bar laid by it.
        b.place(.translation(Vec3(0.38, 0, 0.32)) * .rotationY(0.6)) {
            $0.place(.translation(Vec3(0.01, 0.034, 0.01))) {
                $0.tube([(0.024, -0.007), (0.03, 0.0), (0.024, 0.007)], sides: 9, color: Palette.straw)
            }
            $0.with(material: .metal) {
                $0.limb(from: Vec3(-0.035, 0.03, -0.05), to: Vec3(0.03, 0.03, -0.045), radius: 0.004, color: Palette.iron)
            }
        }
    }

    /// The moonsalt pans drawn near: baskets of salt, a wheelbarrow, a
    /// shovel standing in a heap, sacks filled from it, and a pusher laid
    /// across a pan.
    static func saltPanNear(_ b: inout MeshBuilder) {
        for (index, x) in [Float(0.04), 0.1].enumerated() {
            b.place(.translation(Vec3(x, 0.004, 0.37 + 0.03 * Float(index)))) {
                $0.lathe([(0.0, 0.0), (0.022, 0.003), (0.027, 0.035)], sides: 7, color: Palette.straw)
                $0.with(material: .crystal) { $0.cone(sides: 6, radius: 0.024, from: 0.03, to: 0.05, color: Palette.moonsalt) }
            }
        }
        b.place(.translation(Vec3(-0.25, 0.004, 0.37))) {
            $0.lathe([(0.03, 0.03), (0.05, 0.07), (0.0, 0.07)], sides: 4, color: Palette.timber, twist: .pi / 4)
            $0.with(material: .crystal) { $0.cone(sides: 6, radius: 0.04, from: 0.065, to: 0.085, color: Palette.moonsalt) }
            $0.wheel(center: Vec3(0, 0.025, 0.07), radius: 0.025, width: 0.01, spokes: 2, color: Palette.timberDark)
            for x in [Float(-0.022), 0.022] {
                $0.limb(from: Vec3(x, 0.05, 0.06), to: Vec3(x, 0.06, -0.11), radius: 0.004, color: Palette.timberDark)
                $0.limb(from: Vec3(x, 0.035, -0.02), to: Vec3(x, 0, -0.03), radius: 0.004, color: Palette.timberDark)
            }
        }
        b.limb(from: Vec3(0.2, 0.03, 0.32), to: Vec3(0.24, 0.2, 0.36), radius: 0.004, color: Palette.timber)
        b.with(material: .metal) {
            $0.sheet([Vec3(0.185, 0.0, 0.31), Vec3(0.215, 0.0, 0.33), Vec3(0.21, 0.045, 0.335), Vec3(0.19, 0.045, 0.32)],
                     normal: Vec3(0.6, 0.2, -0.7), thickness: 0.003, color: Palette.iron)
        }
        b.tiedSack(at: Vec3(0.3, 0.004, 0.4), size: 0.9)
        b.tiedSack(at: Vec3(0.33, 0.004, 0.35), size: 0.8)
        b.beam(from: Vec3(0.0, 0.035, 0.12), to: Vec3(0.11, 0.035, 0.12), width: 0.018, depth: 0.012, color: Palette.timberPale)
        b.limb(from: Vec3(0.055, 0.04, 0.12), to: Vec3(0.12, 0.08, 0.22), radius: 0.004, color: Palette.timber)
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
        // The ears standing thick above the rows, swaying.
        b.with(material: .foliage, sway: 1) {
            $0.swayRange = (0.02, 0.14)
            for index in 0..<40 {
                let row = index % 8, along = Float(index / 8) / 5
                let x = -0.5 + along + 0.04 * Noise.unit(Int32(index), 2, 93)
                let z = Float(row) * 0.11 - 0.385 + 0.03 * (Noise.unit(Int32(index), 3, 93) - 0.5)
                $0.limb(from: Vec3(x, 0.06, z), to: Vec3(x + 0.006, 0.11, z), radius: 0.003, sides: 3, color: Palette.straw)
                $0.place(.translation(Vec3(x + 0.006, 0.11, z))) {
                    $0.lathe([(0.004, 0), (0.007, 0.012), (0.0, 0.028)], sides: 4, color: Palette.grain)
                }
            }
        }
        // Stooks of sheaves on the stubble at the field's edge, in a row.
        for index in 0..<7 {
            let at = Vec3(-0.45 + Float(index) * 0.15, 0, 0.52 + 0.02 * Noise.unit(Int32(index), 4, 95))
            b.place(.translation(at) * .rotationY(Float(index))) {
                $0.lathe([(0.05, -0.01), (0.04, 0.08), (0.06, 0.1), (0.03, 0.13), (0, 0.15)], sides: 7, color: Palette.straw)
                $0.lathe([(0.042, 0.075), (0.045, 0.085)], sides: 7, color: Palette.timberPale)
            }
        }
        // A hedge of thorn along its western side, a gate in it, and an
        // oak spreading over the corner where the reapers rest.
        for index in 0..<9 {
            let z = -0.42 + Float(index) * 0.1
            guard index != 6 else { continue }
            b.rock(center: Vec3(-0.6, 0.05, z), size: Vec3(0.04, 0.06, 0.055), rings: 3, sides: 6, jitter: 0.35, seed: UInt32(150 + index),
                   color: index % 2 == 0 ? Palette.leaf : Palette.moss)
        }
        for z in [Float(0.15), 0.25] {
            b.limb(from: Vec3(-0.6, 0, z), to: Vec3(-0.6, 0.08, z), radius: 0.006, color: Palette.timberDark)
        }
        for y in [Float(0.025), 0.05, 0.075] {
            b.beam(from: Vec3(-0.6, y, 0.155), to: Vec3(-0.55, y, 0.24), width: 0.005, color: Palette.timberPale)
        }
        b.place(.translation(Vec3(0.55, 0, -0.42)) * .scale(0.75)) { elderTree(&$0) }
        // A field shelter of poles under thatch where the tools are kept.
        let shed = Vec3(0.58, 0, 0.18)
        for x in [Float(-0.05), 0.05] {
            for z in [Float(-0.05), 0.05] {
                b.limb(from: shed + Vec3(x, 0, z), to: shed + Vec3(x, 0.1, z), radius: 0.005, color: Palette.timberDark)
            }
        }
        b.place(.translation(shed)) {
            $0.gableRoof(width: 0.13, depth: 0.13, base: 0.1, height: 0.06, color: Palette.thatch, overhang: 0.008)
        }
    }

    /// A stand of timber at a hex's heart: tall firs in tiers of drooping
    /// boughs on their spread roots, two birches at its edge and the young
    /// firs coming up between, ferns and heather under them; the
    /// woodcutters' work along its front: stumps, a felled trunk, the log
    /// pile, an axe in a stump, their shelter of poles and bark, a sledge
    /// for hauling and a charcoal clamp smoking under its turf.
    static func timberStand(_ b: inout MeshBuilder) {
        let standing: [(Vec3, Float)] = [(Vec3(-0.3, 0, -0.25), 1.25), (Vec3(0.05, 0, -0.4), 1.4), (Vec3(0.35, 0, -0.22), 1.2),
                                         (Vec3(-0.46, 0, 0.08), 1.1), (Vec3(0.44, 0, 0.16), 1.15),
                                         (Vec3(0.3, 0, -0.48), 0.95)]
        for (index, tree) in standing.enumerated() {
            tallFir(&b, at: tree.0, scale: tree.1, seed: UInt32(500 + index))
        }
        for (index, at) in [Vec3(-0.08, 0, -0.26), Vec3(0.2, 0, -0.3), Vec3(-0.36, 0, -0.06)].enumerated() {
            fir(&b, at: at, scale: 0.45 + 0.1 * Float(index))
        }
        for at in [Vec3(0.5, 0, -0.06), Vec3(-0.52, 0, 0.3)] {
            b.place(.translation(at) * .scale(0.9)) { birch(&$0) }
        }
        for (index, at) in [Vec3(-0.2, 0, -0.12), Vec3(0.12, 0, -0.16), Vec3(0.4, 0, 0.0), Vec3(-0.4, 0, -0.38), Vec3(0.2, 0, -0.5)]
            .enumerated() {
            b.place(.translation(at)) { index % 2 == 0 ? fern(&$0, seed: UInt32(520 + index)) : heather(&$0, seed: UInt32(520 + index)) }
        }
        // Stumps, a felled trunk, a pile of logs and an axe left in a stump.
        for at in [Vec3(-0.08, 0, -0.08), Vec3(0.18, 0, 0.0), Vec3(-0.22, 0, 0.22)] {
            b.place(.translation(at)) {
                $0.lathe([(0.05, -0.04), (0.042, 0.0), (0.036, 0.04)], sides: 7, color: Palette.bark, colors: [Palette.bark, Palette.bark, Palette.timberPale])
            }
            for root in 0..<3 {
                let angle = Float(root) * 2.1 + at.x * 9
                b.limb(from: at + Vec3(0, 0.01, 0), to: at + MeshBuilder.ring(0.075, -0.01, angle), radius: 0.012, topRadius: 0.004,
                       sides: 4, color: Palette.bark)
            }
        }
        b.log(from: Vec3(-0.05, 0.03, 0.12), to: Vec3(0.38, 0.03, 0.42), radius: 0.03)
        for index in 0..<8 {
            let layer = Float(index < 4 ? 0 : (index < 7 ? 1 : 2)), slot = Float(index < 4 ? index : (index < 7 ? index - 4 : 0))
            let y = 0.025 + layer * 0.042
            let z = 0.28 + slot * 0.05 + layer * 0.025
            b.log(from: Vec3(-0.45, y, z), to: Vec3(-0.15, y, z), radius: 0.024)
        }
        for z in [Float(0.26), 0.45] {
            b.limb(from: Vec3(-0.47, 0, z), to: Vec3(-0.47, 0.1, z), radius: 0.008, color: Palette.timberDark)
        }
        b.beam(from: Vec3(0.18, 0.04, 0.0), to: Vec3(0.24, 0.13, 0.05), width: 0.012, color: Palette.timberPale)
        b.with(material: .metal) {
            $0.box(center: Vec3(0.185, 0.045, 0.004), size: Vec3(0.012, 0.03, 0.05), turn: 0.6, color: Palette.iron)
        }
        // The woodcutters' shelter: poles leant to a ridge, roofed in bark.
        let hut = Vec3(0.3, 0, 0.12)
        for x in [Float(-0.06), 0.06] {
            for z in [Float(-0.05), 0.05] {
                b.limb(from: hut + Vec3(x, 0, z), to: hut + Vec3(x * 0.9, 0.12, 0), radius: 0.005, color: Palette.timberDark)
            }
        }
        b.place(.translation(hut)) {
            $0.gableRoof(width: 0.15, depth: 0.11, base: 0.0, height: 0.12, color: Palette.bark, overhang: 0.006)
        }
        // A sledge for hauling, a log chained on it.
        b.place(.translation(Vec3(0.1, 0, 0.32)) * .rotationY(0.5)) {
            for z in [Float(-0.03), 0.03] {
                $0.box(min: Vec3(-0.08, 0, z - 0.005), max: Vec3(0.08, 0.012, z + 0.005), color: Palette.timberDark)
            }
            $0.box(min: Vec3(-0.06, 0.012, -0.035), max: Vec3(0.06, 0.02, 0.035), color: Palette.timber)
            $0.log(from: Vec3(-0.07, 0.04, 0), to: Vec3(0.07, 0.04, 0), radius: 0.02)
        }
        // A charcoal clamp under its turf, smoke seeping from its crown.
        b.place(.translation(Vec3(-0.36, 0, -0.34))) {
            $0.lathe([(0.1, 0), (0.09, 0.04), (0.05, 0.08), (0.0, 0.095)], sides: 9, color: Palette.loam)
            $0.lathe([(0.012, 0.09), (0.0, 0.1)], sides: 5, color: Palette.barkBlack)
        }
    }

    /// A tall fir of the stand: a trunk flaring at its roots, five tiers of
    /// boughs drooping at their tips, each tier twisted from the last.
    static func tallFir(_ b: inout MeshBuilder, at: Vec3, scale: Float, seed: UInt32) {
        let lean = (Noise.unit(Int32(seed), 3, 41) - 0.5) * 0.06
        b.place(.translation(at) * .scale(scale) * .rotationZ(lean)) {
            $0.lathe([(0.05, -0.04), (0.034, 0.02), (0.026, 0.3), (0.012, 0.56)], sides: 6, color: Palette.bark)
            for root in 0..<4 {
                let angle = Float(root) * .pi / 2 + Float(seed % 7) * 0.3
                $0.limb(from: Vec3(0, 0.02, 0), to: MeshBuilder.ring(0.07, -0.01, angle), radius: 0.014, topRadius: 0.004, sides: 3,
                        color: Palette.bark)
            }
            $0.with(material: .foliage, sway: 1) {
                $0.swayRange = (0.1, 0.62)
                for tier in 0..<4 {
                    let base = 0.1 + Float(tier) * 0.11
                    let radius = 0.18 - Float(tier) * 0.035
                    $0.lathe([(radius * 0.85, base - 0.02), (radius, base), (radius * 0.55, base + 0.07), (0, base + 0.15)], sides: 6,
                             color: tier % 2 == 0 ? Palette.firDark : Palette.fir, twist: Float(tier) * 0.4)
                }
            }
        }
    }

    /// A stone outcrop at a hex's heart: a ridge of grey rock in three
    /// masses, its strata lying in bands, the quarrymen's faces cut back in
    /// steps into the greatest; blocks squared and stacked on the floor
    /// before it, a sledge to drag them, a sheerlegs over the cut, the
    /// quarrymen's lean-to, scree and boulders tumbled about its flanks
    /// with heather rooted between.
    static func outcrop(_ b: inout MeshBuilder) {
        b.rock(center: Vec3(0, 0.12, -0.24), size: Vec3(0.44, 0.3, 0.24), rings: 8, sides: 16, jitter: 0.18, seed: 101, color: Palette.rock)
        b.rock(center: Vec3(-0.38, 0.08, -0.12), size: Vec3(0.18, 0.18, 0.2), rings: 6, sides: 12, jitter: 0.22, seed: 103,
               color: Palette.stoneDark)
        b.rock(center: Vec3(0.36, 0.06, -0.02), size: Vec3(0.17, 0.13, 0.16), rings: 6, sides: 12, jitter: 0.25, seed: 102,
               color: Palette.stoneDark)
        // Strata in bands along the ridge's face.
        for band in 0..<4 {
            let y = 0.08 + Float(band) * 0.055
            b.box(center: Vec3(-0.02, y, -0.24 + 0.2 - Float(band) * 0.025), size: Vec3(0.56 - Float(band) * 0.1, 0.012, 0.03),
                  color: band % 2 == 0 ? Palette.stone : Palette.slate)
        }
        // Faces cut back in steps.
        for step in 0..<3 {
            let y = Float(step) * 0.07
            b.box(min: Vec3(-0.28 + Float(step) * 0.04, -0.04, -0.08 - Float(step) * 0.05),
                  max: Vec3(0.2 - Float(step) * 0.04, y + 0.06, -0.02 - Float(step) * 0.05), color: Palette.stonePale)
        }
        b.blocks(at: Vec3(-0.15, 0, 0.2), count: 8, seed: 17)
        b.blocks(at: Vec3(0.15, 0, 0.28), count: 6, seed: 18)
        b.blocks(at: Vec3(-0.34, 0, 0.3), count: 4, seed: 19)
        b.place(.translation(Vec3(0.38, 0, 0.32)) * .rotationY(0.6)) {
            for x in [Float(-0.035), 0.035] {
                $0.box(min: Vec3(x - 0.008, 0, -0.07), max: Vec3(x + 0.008, 0.016, 0.07), color: Palette.timberDark)
            }
            $0.box(min: Vec3(-0.05, 0.016, -0.06), max: Vec3(0.05, 0.026, 0.06), color: Palette.timber)
            $0.box(center: Vec3(0, 0.05, 0), size: Vec3(0.06, 0.045, 0.05), color: Palette.stonePale)
        }
        // Sheerlegs over the cut, a block slung from them.
        let head = Vec3(-0.04, 0.34, -0.02)
        for (x, z) in [(Float(-0.14), Float(0.06)), (0.06, 0.06), (-0.04, -0.12)] {
            b.limb(from: Vec3(x, 0, z), to: head, radius: 0.007, color: Palette.timberGrey)
        }
        b.limb(from: head, to: head + Vec3(0, -0.18, 0), radius: 0.002, color: Palette.linen)
        b.box(center: head + Vec3(0, -0.2, 0), size: Vec3(0.05, 0.035, 0.035), color: Palette.stonePale)
        // The quarrymen's lean-to against the eastern mass.
        let lean = Vec3(0.3, 0, 0.14)
        for x in [Float(-0.06), 0.06] {
            b.limb(from: lean + Vec3(x, 0, 0.05), to: lean + Vec3(x, 0.1, 0.05), radius: 0.005, color: Palette.timberDark)
        }
        b.quad(lean + Vec3(-0.08, 0.1, 0.07), lean + Vec3(0.08, 0.1, 0.07), lean + Vec3(0.08, 0.14, -0.06), lean + Vec3(-0.08, 0.14, -0.06),
               color: Palette.slate)
        b.quad(lean + Vec3(-0.08, 0.135, -0.06), lean + Vec3(0.08, 0.135, -0.06), lean + Vec3(0.08, 0.095, 0.07),
               lean + Vec3(-0.08, 0.095, 0.07), color: Palette.timberDark)
        // Scree and boulders tumbled about its flanks, heather between.
        for index in 0..<26 {
            let angle = Float.pi * (0.85 + 1.3 * Float(index) / 25)
            let at = Vec3(0, 0, -0.18) + MeshBuilder.ring(0.4 + 0.06 * Noise.unit(Int32(index), 5, 107), 0, angle)
            let size = 0.02 + 0.03 * Noise.unit(Int32(index), 9, 107)
            b.rock(center: at + Vec3(0, size * 0.4, 0), size: Vec3(size, size * 0.7, size), rings: 3, sides: 7, jitter: 0.3,
                   seed: UInt32(110 + index), color: index % 3 == 0 ? Palette.stonePale : Palette.rock)
        }
        for (index, at) in [Vec3(-0.46, 0, 0.08), Vec3(0.48, 0, 0.14), Vec3(-0.2, 0, -0.5), Vec3(0.24, 0, -0.46)].enumerated() {
            b.place(.translation(at)) { heather(&$0, seed: UInt32(130 + index)) }
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
        // Walkways of planks between the pans, the rakers' hut of driftwood
        // and its barrow, rakes leant against it, and sluice boards holding
        // back the brine at the shore's edge.
        for z in [Float(-0.03), 0.27] {
            for index in 0..<6 {
                b.box(center: Vec3(-0.4 + Float(index) * 0.15, 0.01, z), size: Vec3(0.13, 0.008, 0.035), turn: 0.03 * Float(index % 2),
                      color: index % 2 == 0 ? Palette.timberPale : Palette.timberGrey)
            }
        }
        let hut = Vec3(-0.4, 0, -0.3)
        b.box(min: hut + Vec3(-0.07, 0, -0.05), max: hut + Vec3(0.07, 0.08, 0.05), color: Palette.timberGrey)
        b.place(.translation(hut)) {
            $0.gableRoof(width: 0.16, depth: 0.12, base: 0.08, height: 0.05, color: Palette.reed, overhang: 0.01)
        }
        b.box(center: hut + Vec3(0.02, 0.035, 0.051), size: Vec3(0.03, 0.06, 0.003), color: Palette.timberDark)
        for (index, x) in [Float(-0.05), -0.035].enumerated() {
            b.limb(from: hut + Vec3(x, 0, 0.07), to: hut + Vec3(x + 0.01, 0.13, 0.052), radius: 0.003, color: Palette.timberPale)
            b.box(center: hut + Vec3(x, 0.006, 0.075), size: Vec3(0.04, 0.008, 0.006), turn: Float(index) * 0.2, color: Palette.timberDark)
        }
        b.place(.translation(Vec3(-0.22, 0, 0.36)) * .rotationY(0.8)) {
            $0.box(min: Vec3(-0.03, 0.02, -0.022), max: Vec3(0.035, 0.05, 0.022), color: Palette.timberGrey)
            $0.wheel(center: Vec3(0.045, 0.018, 0), radius: 0.018, width: 0.006, spokes: 3, color: Palette.timber, rim: Palette.timberDark)
            for z in [Float(-0.018), 0.018] {
                $0.beam(from: Vec3(0.04, 0.03, z), to: Vec3(-0.08, 0.04, z), width: 0.004, color: Palette.timberDark)
            }
            $0.saltHeap(at: Vec3(0, 0.05, 0), radius: 0.025, height: 0.02)
        }
        for index in 0..<5 {
            let x = -0.45 + Float(index) * 0.22
            b.limb(from: Vec3(x, -0.02, -0.43), to: Vec3(x, 0.05, -0.43), radius: 0.008, color: Palette.timberDark)
            if index < 4 {
                b.box(center: Vec3(x + 0.11, 0.025, -0.43), size: Vec3(0.21, 0.04, 0.008), color: Palette.timberGrey)
            }
        }
        crystals(&b, at: Vec3(0.44, 0, -0.34), count: 6, height: 0.1, seed: 25)
        crystals(&b, at: Vec3(-0.1, 0, -0.33), count: 4, height: 0.08, seed: 26)
        for index in 0..<5 {
            Land.reeds(&b, at: Vec3(-0.5 + Float(index) * 0.25, 0, -0.5), count: 5, height: 0.1, seed: UInt32(160 + index))
        }
    }
}

extension Land {
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
    /// The sigil of a commander's leading talent tree, a thin ring of
    /// light laid on the ground: steel's crossed blades in ember, ward's
    /// nested rings and shield in pale blue, road's chevrons pointing the
    /// march in green-silver. Glowing, never lit; its forward along z.
    static func talentSigil(_ tree: Int, name: String) -> Model {
        var b = MeshBuilder()
        let colour: Vec3
        switch tree {
        case 0: colour = Vec3(0.95, 0.42, 0.18)
        case 1: colour = Vec3(0.45, 0.68, 1.0)
        default: colour = Vec3(0.55, 0.9, 0.62)
        }
        let y: Float = 0.006
        b.with(material: .glow) {
            // The outer ring.
            $0.tube([(0.5, y), (0.5, y + 0.004)], sides: 24, color: colour)
            $0.lathe([(0.46, y), (0.5, y)], sides: 24, color: colour)
            switch tree {
            case 0:
                for angle: Float in [0.6, -0.6, Float.pi - 0.6, Float.pi + 0.6] {
                    let tip = Vec3(Float(sin(Double(angle))) * 0.42, y, Float(cos(Double(angle))) * 0.42)
                    $0.beam(from: Vec3(0, y, 0), to: tip, width: 0.03, depth: 0.004, color: colour)
                }
                for index in 0..<8 {
                    let a = Float(index) / 8 * 2 * .pi
                    $0.box(center: Vec3(Float(sin(Double(a))) * 0.48, y, Float(cos(Double(a))) * 0.48), size: Vec3(0.05, 0.004, 0.05), color: colour)
                }
            case 1:
                $0.lathe([(0.3, y), (0.33, y)], sides: 20, color: colour)
                $0.lathe([(0.14, y), (0.17, y)], sides: 16, color: colour)
                $0.sheet([Vec3(-0.1, y, 0.08), Vec3(0.1, y, 0.08), Vec3(0.1, y, -0.04), Vec3(0, y, -0.14), Vec3(-0.1, y, -0.04)],
                         normal: Vec3(0, 1, 0), thickness: 0.003, color: colour)
            default:
                for z in [Float(-0.24), -0.04, 0.16] {
                    $0.beam(from: Vec3(-0.22, y, z), to: Vec3(0, y, z + 0.18), width: 0.035, depth: 0.004, color: colour)
                    $0.beam(from: Vec3(0.22, y, z), to: Vec3(0, y, z + 0.18), width: 0.035, depth: 0.004, color: colour)
                }
            }
        }
        return Model(name: name, mesh: b.mesh)
    }
}

extension Land {
    /// One ally's help over a hold: a small lantern of light, a glowing
    /// lozenge in a thin ring of gold.
    static func helpLight(name: String) -> Model {
        var b = MeshBuilder()
        b.with(material: .glow) {
            $0.lathe([(0.0, -0.05), (0.03, 0.0), (0.0, 0.05)], sides: 6, color: Vec3(1.0, 0.86, 0.55))
        }
        b.with(material: .metal) {
            $0.tube([(0.042, -0.004), (0.042, 0.004)], sides: 10, color: Palette.gold)
        }
        return Model(name: name, mesh: b.mesh)
    }
}

extension Land {
    /// A boundary stone where an alliance's land ends: a squared stone,
    /// weathered, its cap banded in the alliance's colour and a notch cut
    /// in its face toward the land beyond.
    static func borderStone(name: String) -> Model {
        var b = MeshBuilder()
        b.lathe([(0.05, -0.04), (0.05, 0.0), (0.042, 0.16), (0.032, 0.2), (0.0, 0.215)], sides: 4, color: Palette.stonePale)
        b.with(material: .house) {
            $0.lathe([(0.044, 0.14), (0.04, 0.17)], sides: 4, color: Palette.house)
        }
        b.box(center: Vec3(0, 0.1, 0.047), size: Vec3(0.03, 0.03, 0.008), color: Palette.stoneDark)
        b.rock(center: Vec3(0.05, 0.0, -0.03), size: Vec3(0.03, 0.02, 0.025), rings: 2, sides: 4, jitter: 0.25, seed: 410, color: Palette.stone)
        return Model(name: name, mesh: b.mesh)
    }
}

extension Land {
    /// Where a crest's shield hangs on its board, its face toward +z.
    static let crestFace = Vec3(0, 0.42, 0.014)

    /// A House's crest at a hold's gate: a post with a crossbar and the
    /// shield hanging from it on two chains, square-shouldered and coming
    /// to a point, its field in the House's field tincture.
    static func crestBoard(name: String) -> Model {
        var b = MeshBuilder()
        b.limb(from: Vec3(-0.14, 0, -0.02), to: Vec3(-0.14, 0.62, -0.02), radius: 0.012, color: Palette.timberDark)
        b.beam(from: Vec3(-0.15, 0.58, -0.02), to: Vec3(0.06, 0.58, -0.02), width: 0.014, color: Palette.timber)
        for x in [Float(-0.05), 0.05] {
            b.limb(from: Vec3(x, 0.58, -0.01), to: Vec3(x, 0.52, 0.005), radius: 0.003, sides: 3, color: Palette.iron)
        }
        let c = crestFace
        b.with(material: .house) {
            $0.sheet([Vec3(c.x - 0.08, c.y + 0.1, c.z), Vec3(c.x + 0.08, c.y + 0.1, c.z), Vec3(c.x + 0.08, c.y - 0.02, c.z),
                      Vec3(c.x + 0.05, c.y - 0.08, c.z), Vec3(c.x, c.y - 0.11, c.z), Vec3(c.x - 0.05, c.y - 0.08, c.z),
                      Vec3(c.x - 0.08, c.y - 0.02, c.z)], normal: Vec3(0, 0, 1), thickness: 0.012, color: Palette.house)
        }
        // The shield's rim, iron.
        b.with(material: .metal) {
            for (a, z) in [(Vec3(-0.08, 0.1, 0), Vec3(0.08, 0.1, 0)), (Vec3(0.08, 0.1, 0), Vec3(0.08, -0.02, 0)),
                           (Vec3(-0.08, 0.1, 0), Vec3(-0.08, -0.02, 0)), (Vec3(0.08, -0.02, 0), Vec3(0, -0.11, 0)),
                           (Vec3(-0.08, -0.02, 0), Vec3(0, -0.11, 0))] {
                $0.beam(from: c + a + Vec3(0, 0, 0.002), to: c + z + Vec3(0, 0, 0.002), width: 0.008, depth: 0.004, color: Palette.iron)
            }
        }
        return Model(name: name, mesh: b.mesh)
    }

    /// A crest's charge, laid in relief on its shield's face, in the
    /// House's charge tincture: moon, tower, heron, star, oar, key, wave,
    /// flame, antler, bell.
    static func crestCharge(_ charge: Int, name: String) -> Model {
        var b = MeshBuilder()
        let c = crestFace + Vec3(0, 0.0, 0.01)
        let n = Vec3(0, 0, 1)
        func line(_ a: Vec3, _ z: Vec3, _ w: Float = 0.012) {
            b.beam(from: c + a, to: c + z, width: w, depth: 0.004, color: Palette.house)
        }
        func plate(_ points: [Vec3]) { b.sheet(points.map { c + $0 }, normal: n, thickness: 0.004, color: Palette.house) }
        b.material = .house
        switch charge {
        case 0: // a crescent moon
            for index in 0..<6 {
                let a0 = Float(index) / 6 * 3.6 - 1.8, a1 = Float(index + 1) / 6 * 3.6 - 1.8
                line(Vec3(Float(sin(Double(a0))) * 0.045, Float(cos(Double(a0))) * 0.045, 0),
                     Vec3(Float(sin(Double(a1))) * 0.045, Float(cos(Double(a1))) * 0.045, 0), 0.016)
            }
        case 1: // a tower
            plate([Vec3(-0.03, -0.06, 0), Vec3(0.03, -0.06, 0), Vec3(0.03, 0.04, 0), Vec3(-0.03, 0.04, 0)])
            for x in [Float(-0.025), 0, 0.025] { plate([Vec3(x - 0.008, 0.04, 0), Vec3(x + 0.008, 0.04, 0), Vec3(x + 0.008, 0.06, 0), Vec3(x - 0.008, 0.06, 0)]) }
        case 2: // a heron
            line(Vec3(0, -0.06, 0), Vec3(0, -0.01, 0), 0.006)
            plate([Vec3(-0.03, -0.01, 0), Vec3(0.03, -0.02, 0), Vec3(0.01, 0.02, 0)])
            line(Vec3(0.01, 0.02, 0), Vec3(0.0, 0.06, 0), 0.006)
            line(Vec3(0.0, 0.06, 0), Vec3(0.04, 0.05, 0), 0.006)
        case 3: // a star
            for index in 0..<3 {
                let a = Float(index) * .pi / 3
                line(Vec3(Float(sin(Double(a))) * 0.055, Float(cos(Double(a))) * 0.055, 0),
                     Vec3(-Float(sin(Double(a))) * 0.055, -Float(cos(Double(a))) * 0.055, 0), 0.014)
            }
        case 4: // an oar
            line(Vec3(-0.04, 0.06, 0), Vec3(0.02, -0.03, 0), 0.008)
            plate([Vec3(0.01, -0.02, 0), Vec3(0.04, -0.03, 0), Vec3(0.045, -0.07, 0), Vec3(0.025, -0.07, 0)])
        case 5: // a key
            line(Vec3(-0.03, 0.04, 0), Vec3(-0.01, 0.06, 0)); line(Vec3(-0.01, 0.06, 0), Vec3(0.01, 0.04, 0))
            line(Vec3(0.01, 0.04, 0), Vec3(-0.01, 0.02, 0)); line(Vec3(-0.01, 0.02, 0), Vec3(-0.03, 0.04, 0))
            line(Vec3(-0.01, 0.02, 0), Vec3(-0.01, -0.06, 0), 0.01)
            line(Vec3(-0.01, -0.06, 0), Vec3(0.02, -0.06, 0), 0.01); line(Vec3(-0.01, -0.04, 0), Vec3(0.015, -0.04, 0), 0.01)
        case 6: // waves
            for y in [Float(-0.03), 0.02] {
                for index in 0..<4 {
                    let x0 = -0.06 + Float(index) * 0.03
                    line(Vec3(x0, y, 0), Vec3(x0 + 0.015, y + 0.015, 0), 0.01)
                    line(Vec3(x0 + 0.015, y + 0.015, 0), Vec3(x0 + 0.03, y, 0), 0.01)
                }
            }
        case 7: // a flame
            plate([Vec3(0, -0.06, 0), Vec3(0.035, -0.03, 0), Vec3(0.02, 0.02, 0), Vec3(0.005, 0.065, 0), Vec3(-0.02, 0.02, 0), Vec3(-0.035, -0.03, 0)])
        case 8: // an antler
            line(Vec3(0, -0.06, 0), Vec3(0, 0.06, 0), 0.01)
            for (y, side) in [(Float(-0.02), Float(-1)), (0.01, 1), (0.04, -1)] { line(Vec3(0, y, 0), Vec3(side * 0.04, y + 0.03, 0), 0.008) }
        default: // a bell
            plate([Vec3(-0.012, 0.05, 0), Vec3(0.012, 0.05, 0), Vec3(0.03, 0.0, 0), Vec3(0.045, -0.045, 0), Vec3(-0.045, -0.045, 0), Vec3(-0.03, 0.0, 0)])
            line(Vec3(0, 0.05, 0), Vec3(0, 0.065, 0), 0.01)
        }
        return Model(name: name, mesh: b.mesh)
    }
}

extension Land {
    /// A barge of the Still: a broad, flat-bottomed punt of tarred timber,
    /// its ends raked up, thwarts across it and a low rail; a ferryman at
    /// its stern leaning on his pole, and a lantern on a crook at its prow.
    /// Forward along +z; its deck at the waterline.
    static func barge(name: String) -> Model {
        var b = MeshBuilder()
        let tar = Palette.timberDark.mix(Vec3(0.05, 0.05, 0.06), 0.55)
        // The hull: a flat bottom and sides, the ends raked up.
        b.box(center: Vec3(0, -0.01, 0), size: Vec3(0.34, 0.03, 0.62), color: tar)
        for x in [Float(-0.17), 0.17] {
            b.box(center: Vec3(x, 0.03, 0), size: Vec3(0.02, 0.07, 0.62), color: tar)
        }
        for z in [Float(-0.31), 0.31] {
            let sign: Float = z > 0 ? 1 : -1
            b.sheet([Vec3(-0.17, -0.02, z), Vec3(0.17, -0.02, z), Vec3(0.17, 0.08, z + sign * 0.07), Vec3(-0.17, 0.08, z + sign * 0.07)],
                    normal: Vec3(0, -sign * 0.6, sign), thickness: 0.02, color: tar)
        }
        // Thwarts and the rail.
        for z in [Float(-0.18), 0.0, 0.18] { b.beam(from: Vec3(-0.16, 0.05, z), to: Vec3(0.16, 0.05, z), width: 0.025, color: Palette.timber) }
        for x in [Float(-0.17), 0.17] { b.beam(from: Vec3(x, 0.075, -0.3), to: Vec3(x, 0.075, 0.3), width: 0.012, color: Palette.timber) }
        // The ferryman at the stern, leaning on his pole.
        let at = Vec3(0.05, 0.0, -0.25)
        b.place(.translation(at)) { $0.lathe([(0.05, 0.0), (0.06, 0.1), (0.045, 0.2), (0.02, 0.24), (0.0, 0.25)], sides: 7, color: Palette.leatherDark) }
        b.place(.translation(at + Vec3(0, 0.29, 0))) { $0.lathe([(0.0, -0.04), (0.035, -0.02), (0.03, 0.02), (0.0, 0.04)], sides: 6, color: Palette.linen.mix(Palette.leather, 0.6)) }
        b.limb(from: at + Vec3(0.03, 0.2, 0.02), to: at + Vec3(0.2, -0.35, -0.12), radius: 0.008, color: Palette.timber)
        // The lantern on its crook at the prow.
        b.limb(from: Vec3(0, 0.05, 0.33), to: Vec3(0, 0.26, 0.36), radius: 0.008, color: Palette.timberDark)
        b.beam(from: Vec3(0, 0.26, 0.36), to: Vec3(0, 0.26, 0.42), width: 0.008, color: Palette.timberDark)
        b.with(material: .glow) {
            $0.place(.translation(Vec3(0, 0.2, 0.42))) {
                $0.lathe([(0.0, -0.03), (0.022, -0.02), (0.022, 0.02), (0.0, 0.03)], sides: 6, color: Palette.fire)
            }
        }
        return Model(name: name, mesh: b.mesh)
    }

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
