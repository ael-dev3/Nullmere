import Foundation
import NullmereCore

/// How a people builds its keep: the stone or timber of its walls, its dark
/// courses, the trim of its parapet and hall, and its roof, each with its
/// grain where its colour alone would not say it. The common keep is dressed
/// grey stone under slate. (The pitch of each people's roof and the crown on
/// it are made with the keep in Blender: Art/blender/keep.py.)
struct KeepStyle {
    var wall = Palette.stone
    var dark = Palette.stoneDark
    var trim = Palette.stonePale
    var roof = Palette.slate
    /// The grain drawn on the walls and on the roof, where their colours
    /// alone would not say it.
    var wallGrain: Surface?
    var roofGrain: Surface?

    static let common = KeepStyle()
    /// The strand's blue-grey slate.
    static let seaSlate = Vec3(0.26, 0.31, 0.37)

    /// Each people's keep: the Saltborn's salt-white stone; the Fenfolk's
    /// weathered timber under reed; the Blackwood Kin's dark timber under
    /// shingle; the Spinewardens' raw rock under slate; the Mound Clans'
    /// pale stone under turf; the Strandfolk's whitewash under sea-slate.
    static func of(_ heritage: Heritage) -> KeepStyle {
        switch heritage {
        case .saltborn:
            return KeepStyle(wall: Palette.saltCrust, dark: Palette.stonePale, trim: Palette.stoneWhite, roof: Palette.stoneWhite,
                             wallGrain: .stone, roofGrain: .slate)
        case .fenfolk:
            return KeepStyle(wall: Palette.timberGrey, dark: Palette.timberDark, trim: Palette.timberPale, roof: Palette.reed)
        case .blackwood:
            return KeepStyle(wall: Palette.timberDark, dark: Palette.bark, trim: Palette.timber, roof: Palette.barkBlack, roofGrain: .timber)
        case .spinewardens:
            return KeepStyle(wall: Palette.rock, dark: Palette.stoneDark, trim: Palette.stone, roof: Palette.slate)
        case .moundClans:
            return KeepStyle(wall: Palette.stonePale, dark: Palette.earth, trim: Palette.stoneWhite, roof: Palette.moss, roofGrain: .earth)
        case .strandfolk:
            return KeepStyle(wall: Palette.linen, dark: Palette.stoneDark, trim: Palette.stoneWhite, roof: KeepStyle.seaSlate,
                             wallGrain: .stone, roofGrain: .slate)
        }
    }
}

/// A hold's walls, the scaffold round a rising work, and where its keep's
/// chimney smokes (the keep made in Blender: Art.keep).
enum Holds {
    // MARK: The keep

    /// The top of the keep's hall chimney, where its smoke rises: the keep
    /// made in Blender (Art/blender/keep.py) builds it there.
    static func chimney(seat: Bool) -> Vec3 {
        let half: Float = seat ? 0.17 : 0.155, front: Float = seat ? 0.34 : 0.3
        return Vec3(0.13, 0.43, (half - 0.06 + front) / 2)
    }

    // MARK: Ivy, on the walls

    /// Ivy grown up a wall from its foot: leaves strewn over a tongue of
    /// growth `width` across at its foot and `height` high, thinning and
    /// narrowing as it climbs, with stems wandering up through it. `spot`
    /// puts a leaf `u` across and `v` up the wall, and says which way the
    /// wall looks there.
    static func ivy(_ b: inout MeshBuilder, leaves: Int, width: Float, height: Float, seed: UInt32,
                    spot: (Float, Float) -> (at: Vec3, out: Vec3)) {
        let greens = [Palette.fern, Palette.leaf, Palette.birchLeaf * 0.75, Palette.fern * 1.3]
        for index in 0..<leaves {
            let i = Int32(index)
            let v = height * Noise.unit(i, 1, seed).squareRoot() * Noise.unit(i, 5, seed).squareRoot()
            let across = width / 2 * (1 - 0.75 * v / height)
            let (at, out) = spot((Noise.unit(i, 2, seed) * 2 - 1) * across, v)
            let size = 0.009 + 0.007 * Noise.unit(i, 3, seed), spin = Noise.unit(i, 4, seed) * .pi
            let side = Vec3.up.cross(out).normalized, up = out.cross(side)
            let a = (side * Float(cos(Double(spin))) + up * Float(sin(Double(spin)))) * size
            let d = (up * Float(cos(Double(spin))) - side * Float(sin(Double(spin)))) * size
            b.face([at - a, at - d, at + a, at + d], outward: out, color: greens[index % greens.count])
        }
        for stem in 0..<2 {
            var last = spot(0, 0).at
            for step in 1...4 {
                let v = height * 0.8 * Float(step) / 4
                let wander = (Noise.unit(Int32(step), Int32(stem), seed &+ 9) * 2 - 1) * width / 2 * (1 - 0.75 * v / height)
                let (at, out) = spot(wander, v)
                b.limb(from: last - out * 0.001, to: at - out * 0.001, radius: 0.002, sides: 3, color: Palette.bark)
                last = at
            }
        }
    }

    // MARK: The walls

    /// The walls' ring: corners on this radius, flats facing ±z with the
    /// gate in the +z flat. Turned 30° (and any sixth), it sits within a
    /// hex with its gate toward a neighbour.
    static let wallRadius: Float = 0.84

    static func wallCorner(_ index: Int) -> Vec3 {
        let angle = Float(index) * .pi / 3
        return Vec3(wallRadius * Float(cos(Double(angle))), 0, wallRadius * Float(sin(Double(angle))))
    }

    /// From a palisade of stakes to high walls with round towers roofed in
    /// the House's colour and a gatehouse flying its banner.
    static func walls(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        let height: [Float] = [0.2, 0.17, 0.22, 0.27, 0.32]
        let h = height[min(max(level, 1), 5) - 1]
        let thick: Float = level == 1 ? 0.035 : 0.05 + 0.006 * Float(level)
        let gateHalf: Float = 0.085
        // Each side between corners; the gate's side (corners 1 and 2) is split by the gate.
        var runs: [(Vec3, Vec3)] = []
        for index in 0..<6 {
            let a = wallCorner(index), c = wallCorner(index + 1)
            if index == 1 {
                runs.append((a, Vec3(gateHalf, 0, a.z)))
                runs.append((Vec3(-gateHalf, 0, a.z), c))
            } else {
                runs.append((a, c))
            }
        }
        if level == 1 {
            // A palisade of sharpened stakes.
            for (a, c) in runs {
                let count = max(Int(((c - a).length / 0.055).rounded()), 2)
                for index in 0..<count {
                    let t = (Float(index) + 0.5) / Float(count)
                    let at = a.mix(c, t)
                    let tall = h * (0.9 + 0.2 * Noise.unit(Int32(index), Int32(at.x * 100), 7))
                    b.place(.translation(at + Vec3(0, -0.3, 0))) {
                        $0.tube([(0.02, 0), (0.02, tall + 0.3)], sides: 3, color: Palette.timber, twist: Float(index))
                        $0.cone(sides: 3, radius: 0.02, from: tall + 0.3, to: tall + 0.35, color: Palette.timberPale,
                                twist: Float(index))
                    }
                }
            }
            // A walkway of planks behind the gate and a lintel over it.
            b.beam(from: Vec3(-gateHalf - 0.03, h + 0.03, wallCorner(1).z), to: Vec3(gateHalf + 0.03, h + 0.03, wallCorner(1).z),
                   width: 0.04, depth: 0.035, color: Palette.timber)
            for x in [-gateHalf - 0.01, gateHalf + 0.01] {
                b.limb(from: Vec3(x, -0.3, wallCorner(1).z), to: Vec3(x, h + 0.06, wallCorner(1).z), radius: 0.024, color: Palette.timberDark)
            }
        } else {
            for (a, c) in runs {
                b.beam(from: a + Vec3(0, (h - 0.3) / 2, 0), to: c + Vec3(0, (h - 0.3) / 2, 0), width: thick, depth: h + 0.3,
                       color: level == 2 ? Palette.stoneDark : Palette.stone)
                if level >= 3 {
                    let count = max(Int(((c - a).length / 0.075).rounded()), 1)
                    b.merlons(from: a + Vec3(0, h, 0), to: c + Vec3(0, h, 0), count: count, size: Vec3(0.04, 0.045, thick * 0.9),
                              color: Palette.stonePale)
                }
            }
            // A low wall's corners stand on squat piers of dressed stone.
            if level == 2 {
                for index in 0..<6 {
                    let at = wallCorner(index)
                    b.box(center: at + Vec3(0, (h - 0.25) / 2, 0), size: Vec3(0.11, h + 0.35, 0.11), turn: Float(index) * .pi / 3,
                          color: Palette.stone)
                    b.box(center: at + Vec3(0, h + 0.045, 0), size: Vec3(0.13, 0.02, 0.13), turn: Float(index) * .pi / 3,
                          color: Palette.stonePale)
                }
            }
        }
        // Corner towers from the third level: square, then round and roofed.
        if level >= 3 {
            let towerHeight = h + 0.12 + 0.05 * Float(level - 3)
            let radius: Float = 0.075 + 0.012 * Float(level - 3)
            for index in 0..<6 {
                let at = wallCorner(index)
                b.place(.translation(at + Vec3(0, -0.1, 0))) {
                    if level == 3 {
                        $0.lathe([(radius * 1.3, -0.2), (radius * 1.25, towerHeight + 0.1)], sides: 4, color: Palette.stone, twist: .pi / 4)
                        $0.merlonRing(radius: radius * 0.95, base: towerHeight + 0.1, count: 4, size: Vec3(0.04, 0.04, 0.03),
                                      color: Palette.stonePale)
                    } else {
                        $0.lathe([(radius * 1.08, -0.2), (radius, towerHeight + 0.1), (radius * 1.12, towerHeight + 0.12),
                                  (radius * 1.12, towerHeight + 0.15)], sides: 8, color: Palette.stone)
                        $0.with(material: level == 5 ? .house : .plain) {
                            $0.cone(sides: 8, radius: radius * 1.16, from: towerHeight + 0.15, to: towerHeight + 0.15 + radius * 2.6,
                                    color: level == 5 ? Palette.house : Palette.slate)
                        }
                    }
                }
            }
        }
        dressWalls(&b, level: level, height: h, thick: thick, runs: runs, half: gateHalf)
        gate(&b, level: level, height: h, half: gateHalf)
        b.fine { detailWalls(&$0, level: level, height: h, thick: thick, runs: runs, half: gateHalf) }
        return Model(name: name, mesh: b.mesh)
    }

    /// The walls' finer work: a palisade's lashings; a stone wall's
    /// arrow loops between its buttresses, and from the third level a
    /// string course along its face and a wall-walk behind its merlons;
    /// slits and a course round each round corner tower and a finial on its
    /// roof; iron bands across the gate's leaves.
    static func detailWalls(_ b: inout MeshBuilder, level: Int, height h: Float, thick: Float, runs: [(Vec3, Vec3)], half: Float) {
        for (a, c) in runs {
            let along = c - a
            let turn = Float(atan2(Double(along.x), Double(along.z))) - .pi / 2
            let middle = (a + c) * 0.5
            let out = Vec3(middle.x, 0, middle.z).normalized
            if level == 1 {
                // Lashings binding the stakes, twice up.
                for y in [h * 0.35, h * 0.75] {
                    b.beam(from: a + Vec3(0, y, 0) + out * 0.021, to: c + Vec3(0, y, 0) + out * 0.021, width: 0.006, depth: 0.012,
                           color: Palette.leatherDark)
                }
                continue
            }
            let face = out * (thick / 2 + 0.002)
            // Arrow loops midway between the buttresses.
            let count = max(Int((along.length / 0.2).rounded()) - 1, 1)
            for index in stride(from: 1, to: count, by: 1) {
                let at = a.mix(c, (Float(index) + 0.5) / Float(count + 1)) + face
                b.box(center: at + Vec3(0, h * 0.55, 0), size: Vec3(0.012, 0.055, 0.012), turn: turn, color: Palette.timberDark)
            }
            if level <= 3 {
                // Putlog holes the masons' scaffolds left, in two rows.
                let side = along.normalized * 0.005, up = Vec3(0, 0.005, 0)
                for (row, y) in [Float(0.3), 0.66].enumerated() {
                    for index in stride(from: row, to: count + 1, by: 2) {
                        let at = a.mix(c, (Float(index) + 0.3) / Float(count + 1)) + face + Vec3(0, h * y, 0)
                        b.face([at - side - up, at + side - up, at + side + up, at - side + up], outward: out, color: Palette.barkBlack)
                    }
                }
            }
            if level == 2 {
                // A string course along the low wall's face, and stones
                // patched in it, paler than the rest.
                b.beam(from: a + Vec3(0, h * 0.5, 0) + face, to: c + Vec3(0, h * 0.5, 0) + face, width: 0.01, depth: 0.008,
                       color: Palette.stonePale)
                for t in [Float(0.22), 0.71] {
                    let at = a.mix(c, t) + face + Vec3(0, h * (0.2 + 0.5 * t), 0)
                    b.box(center: at, size: Vec3(0.032, 0.018, 0.006), turn: turn, color: Palette.stonePale.mix(Palette.stone, 0.4))
                }
            }
            if level >= 3 {
                b.beam(from: a + Vec3(0, h * 0.82, 0) + face, to: c + Vec3(0, h * 0.82, 0) + face, width: 0.012, depth: 0.012,
                       color: Palette.stonePale)
                // The wall-walk's boards behind the merlons.
                let walk = out * -(thick / 2 + 0.012)
                b.beam(from: a + Vec3(0, h - 0.012, 0) + walk, to: c + Vec3(0, h - 0.012, 0) + walk, width: 0.024, depth: 0.008,
                       color: Palette.timber)
            }
        }
        if (2...3).contains(level) {
            // Ivy up the stone either side of the gate's flanks.
            for (index, run) in [runs[0], runs[3]].enumerated() {
                let (a, c) = run
                let middle = (a + c) * 0.5, out = Vec3(middle.x, 0, middle.z).normalized
                let base = a.mix(c, index == 0 ? 0.38 : 0.62) + out * (thick / 2 + 0.003), along = (c - a).normalized
                ivy(&b, leaves: 48, width: 0.16, height: h * 0.9, seed: UInt32(31 + index)) { u, v in
                    (base + along * u + Vec3(0, v, 0), out)
                }
            }
        }
        if level >= 4 {
            let towerHeight = h + 0.12 + 0.05 * Float(level - 3)
            let radius: Float = 0.075 + 0.012 * Float(level - 3)
            for index in 0..<6 {
                let at = wallCorner(index)
                let outward = Float(atan2(Double(-at.z), Double(at.x)))
                b.place(.translation(at + Vec3(0, -0.1, 0))) {
                    for spread in [Float(-0.5), 0.5] {
                        let angle = outward + spread
                        $0.place(.translation(MeshBuilder.ring(radius * 1.04, towerHeight * 0.62, angle)) * .rotationY(angle + .pi / 2)) {
                            $0.box(center: .zero, size: Vec3(0.012, 0.05, 0.016), color: Palette.timberDark)
                        }
                    }
                    let course = towerHeight * 0.45
                    $0.lathe([(radius * 0.98, course), (radius * 1.1, course + 0.005), (radius * 1.1, course + 0.015),
                              (radius * 0.98, course + 0.02)], sides: 8, color: Palette.stonePale)
                    let top = towerHeight + 0.15 + radius * 2.6
                    $0.limb(from: Vec3(0, top - 0.015, 0), to: Vec3(0, top + 0.05, 0), radius: 0.006, topRadius: 0.002, color: Palette.iron)
                }
            }
        }
        // Iron bands across the gate's open leaves.
        let z = wallCorner(1).z
        for side in [Float(1), -1] {
            for y in [Float(0.05), min(h, 0.2) - 0.05] {
                b.box(center: Vec3(side * half * 0.72, y, z + 0.035), size: Vec3(0.016, 0.01, 0.078), turn: side * 0.9, color: Palette.iron)
            }
        }
    }

    /// The walls' dressing: from the second level, buttresses along their
    /// outer face and, on a low wall, a coping of pale stone; torches
    /// burning either side of the gate at every level; and from the fourth,
    /// the House's banners hung either side of it.
    static func dressWalls(_ b: inout MeshBuilder, level: Int, height h: Float, thick: Float, runs: [(Vec3, Vec3)], half: Float) {
        if level >= 2 {
            for (a, c) in runs {
                let along = c - a
                let turn = Float(atan2(Double(along.x), Double(along.z))) - .pi / 2
                let middle = (a + c) * 0.5
                let out = Vec3(middle.x, 0, middle.z).normalized
                if level == 2 {
                    b.beam(from: a + Vec3(0, h, 0), to: c + Vec3(0, h, 0), width: thick + 0.024, depth: 0.022, color: Palette.stonePale)
                }
                let count = max(Int((along.length / 0.2).rounded()) - 1, 1)
                for index in 1...count {
                    let at = a.mix(c, Float(index) / Float(count + 1)) + out * (thick / 2 + 0.014)
                    b.box(center: at + Vec3(0, (h * 0.8 - 0.3) / 2, 0), size: Vec3(0.036, h * 0.8 + 0.3, 0.028), turn: turn,
                          color: Palette.stoneDark)
                }
            }
        }
        // Torches either side of the gate, out before it.
        let z = wallCorner(1).z + 0.09
        for side in [Float(1), -1] {
            let x = side * (half + 0.012)
            b.limb(from: Vec3(x, -0.05, z), to: Vec3(x, 0.15, z), radius: 0.006, sides: 4, color: Palette.timberDark)
            b.box(center: Vec3(x, 0.155, z), size: Vec3(0.02, 0.012, 0.02), color: Palette.iron)
            b.with(material: .glow) {
                $0.box(center: Vec3(x, 0.175, z), size: Vec3(0.014, 0.028, 0.014), color: Palette.fire)
            }
        }
        // The House's banners down the walls either side of the gate.
        if level >= 4 {
            for (a, c) in runs where a.z > 0.5 && c.z > 0.5 {
                let middle = (a + c) * 0.5, top = middle + Vec3(0, h - 0.03, thick / 2 + 0.006)
                b.with(material: .cloth, sway: 0.3) {
                    $0.swayRange = (0, 0.14)
                    $0.place(.translation(top) * .rotationZ(.pi)) {
                        $0.sheet([Vec3(-0.03, 0, 0), Vec3(0.03, 0, 0), Vec3(0.03, 0.14, 0), Vec3(0, 0.16, 0), Vec3(-0.03, 0.14, 0)],
                                 normal: Vec3(0, 0, 1), thickness: 0.004, color: Palette.house)
                    }
                }
            }
        }
    }

    /// The gate in the +z side: leaves of timber, then a gatehouse of two
    /// towers with a portcullis, then one flying the House's banner.
    static func gate(_ b: inout MeshBuilder, level: Int, height h: Float, half: Float) {
        let z = wallCorner(1).z
        // The leaves, standing open.
        for side in [Float(1), -1] {
            b.beam(from: Vec3(side * half, 0.0, z), to: Vec3(side * half * 0.4, 0.0, z + 0.07), width: 0.012, depth: 0.001,
                   color: Palette.timberDark)
            b.box(center: Vec3(side * half * 0.72, min(h, 0.2) / 2, z + 0.035), size: Vec3(0.012, min(h, 0.2), 0.075),
                  turn: side * 0.9, color: Palette.timberDark)
        }
        guard level >= 3 else { return }
        let towerHalf: Float = 0.06 + 0.008 * Float(level - 3)
        let towerHeight = h + 0.16 + 0.05 * Float(level - 3)
        for side in [Float(1), -1] {
            let x = side * (half + towerHalf)
            b.place(.translation(Vec3(x, -0.1, z + 0.01))) {
                if level == 3 {
                    $0.box(min: Vec3(-towerHalf, -0.2, -towerHalf), max: Vec3(towerHalf, towerHeight + 0.1, towerHalf), color: Palette.stone)
                } else {
                    $0.lathe([(towerHalf * 1.15, -0.2), (towerHalf * 1.05, towerHeight + 0.1)], sides: 8, color: Palette.stone)
                    $0.with(material: level == 5 ? .house : .plain) {
                        $0.cone(sides: 8, radius: towerHalf * 1.25, from: towerHeight + 0.1, to: towerHeight + 0.1 + towerHalf * 2.4,
                                color: level == 5 ? Palette.house : Palette.slate)
                    }
                }
                $0.window(Vec3(0, towerHeight - 0.02 + 0.1, towerHalf + 0.002), width: 0.018, height: 0.05, facing: 0)
            }
        }
        // The arch over the way, and a portcullis from the fourth level.
        b.box(min: Vec3(-half - 0.01, h - 0.02, z - 0.04), max: Vec3(half + 0.01, h + 0.08, z + 0.05), color: Palette.stonePale)
        if level >= 4 {
            b.with(material: .metal) {
                for x in [Float(-0.05), 0, 0.05] {
                    $0.beam(from: Vec3(x, 0.08, z + 0.03), to: Vec3(x, h - 0.02, z + 0.03), width: 0.008, color: Palette.iron)
                }
                $0.beam(from: Vec3(-half, h * 0.6, z + 0.03), to: Vec3(half, h * 0.6, z + 0.03), width: 0.008, depth: 0.008,
                        color: Palette.iron)
            }
        }
        if level >= 5 {
            let top = h + 0.5
            b.limb(from: Vec3(0, h + 0.08, z), to: Vec3(0, top, z), radius: 0.008, color: Palette.timberDark)
            b.flag(at: Vec3(0, top - 0.01, z), width: 0.22, height: 0.15, turn: .pi / 2)
        }
    }

    // MARK: The scaffold

    /// A frame of poles, ledgers, braces and boards round a work as it
    /// rises: a unit wide, deep and high, x and z from -0.5 to 0.5, for its
    /// piece to stretch to the work.
    static func scaffold() -> Mesh {
        var b = MeshBuilder()
        let pole: Float = 0.022, wood = Palette.timberPale
        let posts = [Vec3(-0.5, 0, -0.5), Vec3(0, 0, -0.52), Vec3(0.5, 0, -0.5), Vec3(0.52, 0, 0), Vec3(0.5, 0, 0.5), Vec3(0, 0, 0.52),
                     Vec3(-0.5, 0, 0.5), Vec3(-0.52, 0, 0)]
        for post in posts {
            b.limb(from: post - Vec3(0, 0.05, 0), to: post + Vec3(0, 1.06, 0), radius: pole, color: wood)
        }
        for level in [Float(0.34), 0.68, 1.0] {
            for index in 0..<posts.count {
                let a = posts[index] + Vec3(0, level, 0), c = posts[(index + 1) % posts.count] + Vec3(0, level, 0)
                b.limb(from: a, to: c, radius: pole * 0.8, color: wood)
            }
        }
        // Braces across each face, and boards to walk on along two sides.
        for (a, c) in [(posts[0], posts[2]), (posts[2], posts[4]), (posts[4], posts[6]), (posts[6], posts[0])] {
            b.limb(from: a, to: c + Vec3(0, 0.68, 0), radius: pole * 0.7, color: Palette.timber)
        }
        for level in [Float(0.34), 0.68] {
            b.box(min: Vec3(-0.5, level, 0.44), max: Vec3(0.5, level + 0.02, 0.56), color: Palette.timberGrey)
            b.box(min: Vec3(0.44, level, -0.5), max: Vec3(0.56, level + 0.02, 0.5), color: Palette.timberGrey)
        }
        b.ladder(from: Vec3(-0.3, 0, 0.62), to: Vec3(-0.3, 0.7, 0.53), width: 0.12, rungs: 4, color: Palette.timber)
        // Near: rope lashed round every joint of post and ledger, rails along
        // the boards, a second ladder up the side and a hoist's beam out
        // from a corner post, its rope hanging to the ground.
        b.fine {
            for post in posts {
                for level in [Float(0.34), 0.68, 1.0] {
                    $0.place(.translation(post + Vec3(0, level - 0.02, 0))) {
                        $0.tube([(pole * 1.3, 0), (pole * 1.3, 0.04)], sides: 4, color: Palette.canvas, twist: .pi / 4)
                    }
                }
            }
            for level in [Float(0.34), 0.68] {
                $0.limb(from: Vec3(-0.5, level + 0.16, 0.53), to: Vec3(0.5, level + 0.16, 0.53), radius: pole * 0.6, color: Palette.timber)
                $0.limb(from: Vec3(0.535, level + 0.16, -0.5), to: Vec3(0.535, level + 0.16, 0.5), radius: pole * 0.6, color: Palette.timber)
            }
            $0.ladder(from: Vec3(0.62, 0, -0.25), to: Vec3(0.53, 0.36, -0.25), width: 0.12, rungs: 3, color: Palette.timber)
            $0.limb(from: Vec3(0.5, 0.98, 0.5), to: Vec3(0.68, 1.03, 0.68), radius: pole * 0.8, color: Palette.timberDark)
            $0.limb(from: Vec3(0.66, 1.02, 0.66), to: Vec3(0.66, 0.12, 0.66), radius: 0.004, sides: 3, color: Palette.linen)
        }
        return b.mesh
    }
}
