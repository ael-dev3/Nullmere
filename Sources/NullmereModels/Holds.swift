import Foundation

/// A hold's keep and walls, and the scaffold round a rising work.
enum Holds {
    // MARK: The keep

    /// A square stone tower over a hall, its roofs and pennant the House's;
    /// a seat's tower stands higher between two round towers and flies the
    /// House's great banner. It faces +z.
    static func keep(seat: Bool, name: String) -> Model {
        var b = MeshBuilder()
        let towerHeight: Float = seat ? 0.92 : 0.6
        let half: Float = seat ? 0.17 : 0.155
        // A plinth of dressed stone, deep enough to stand on a slope.
        b.lathe([(0.37, -0.3), (0.37, 0.025), (0.34, 0.045)], sides: 8, color: Palette.stoneDark, twist: .pi / 8)
        // The tower, buttressed at its corners, its parapet corbelled out.
        b.box(min: Vec3(-half, 0.03, -half - 0.05), max: Vec3(half, towerHeight, half - 0.05), color: Palette.stone)
        for x in [-half, half] {
            for z in [-half - 0.05, half - 0.05] {
                b.place(.translation(Vec3(x, 0.03, z))) {
                    $0.lathe([(0.045, 0), (0.035, towerHeight * 0.55), (0.0, towerHeight * 0.62)], sides: 4, color: Palette.stoneDark,
                             twist: .pi / 4)
                }
            }
        }
        let parapet = half + 0.025
        b.box(min: Vec3(-parapet, towerHeight - 0.01, -parapet - 0.05), max: Vec3(parapet, towerHeight + 0.06, parapet - 0.05),
              color: Palette.stonePale)
        let corners = [Vec3(-parapet, 0, -parapet), Vec3(parapet, 0, -parapet), Vec3(parapet, 0, parapet), Vec3(-parapet, 0, parapet)]
        for index in 0..<4 {
            let a = corners[index] + Vec3(0, towerHeight + 0.06, -0.05), c = corners[(index + 1) % 4] + Vec3(0, towerHeight + 0.06, -0.05)
            b.merlons(from: a, to: c, count: 3, size: Vec3(0.06, 0.05, 0.035), color: Palette.stonePale)
        }
        b.place(.translation(Vec3(0, 0, -0.05))) {
            $0.hipRoof(width: half * 1.7, depth: half * 1.7, base: towerHeight + 0.04, height: seat ? 0.3 : 0.22, color: Palette.slate)
        }
        // Lit windows high on the tower, on every face.
        for (facing, offset) in [(Float(0), Vec3(0, 0, half - 0.05)), (.pi, Vec3(0, 0, -half - 0.05)), (.pi / 2, Vec3(half, 0, -0.05)),
                                 (-.pi / 2, Vec3(-half, 0, -0.05))] {
            for level in seat ? [Float(0.45), 0.72] : [Float(0.42)] {
                b.window(offset + Vec3(0, level, 0), width: 0.035, height: 0.07, facing: facing)
            }
        }
        // The hall before it, roofed in the House's colour.
        let hallFront: Float = seat ? 0.34 : 0.3
        b.box(min: Vec3(-0.2, 0.03, half - 0.06), max: Vec3(0.2, 0.25, hallFront), color: Palette.stonePale)
        b.with(material: .house) {
            $0.place(.translation(Vec3(0, 0, (half - 0.06 + hallFront) / 2)) * .rotationY(.pi / 2)) {
                $0.gableRoof(width: hallFront - half + 0.06, depth: 0.4, base: 0.25, height: 0.13, color: Palette.house, overhang: 0.025)
            }
        }
        let flue = chimney(seat: seat)
        b.box(min: Vec3(flue.x - 0.026, 0.22, flue.z - 0.026), max: Vec3(flue.x + 0.026, flue.y - 0.01, flue.z + 0.026),
              color: Palette.stoneDark)
        b.door(Vec3(0, 0.1, hallFront), width: 0.07, height: 0.13, facing: 0)
        for x in [Float(-0.12), 0.12] {
            b.window(Vec3(x, 0.15, hallFront), width: 0.03, height: 0.05, facing: 0)
        }
        // The House's pennant over the tower.
        let poleTop = towerHeight + (seat ? 0.62 : 0.42)
        b.limb(from: Vec3(0, towerHeight + 0.1, -0.05), to: Vec3(0, poleTop, -0.05), radius: 0.008, sides: 4, color: Palette.timberDark)
        b.flag(at: Vec3(0, poleTop - 0.01, -0.05), width: seat ? 0.34 : 0.18, height: seat ? 0.22 : 0.08, turn: .pi / 2,
               tail: !seat)
        if seat {
            // Two round towers flanking the keep, their cones the House's.
            for x in [Float(-0.26), 0.26] {
                b.place(.translation(Vec3(x, 0.03, -0.08))) {
                    $0.lathe([(0.09, 0), (0.085, 0.62), (0.105, 0.64), (0.105, 0.7)], sides: 8, color: Palette.stone)
                    $0.merlonRing(radius: 0.098, base: 0.7, count: 6, size: Vec3(0.04, 0.045, 0.03), color: Palette.stonePale)
                    $0.with(material: .house) {
                        $0.cone(sides: 8, radius: 0.1, from: 0.69, to: 0.98, color: Palette.house)
                    }
                    $0.window(Vec3(0, 0.45, 0.087), width: 0.03, height: 0.06, facing: 0)
                }
            }
            // A curtain between them behind the keep.
            b.box(min: Vec3(-0.26, 0.03, -0.17), max: Vec3(0.26, 0.4, -0.08), color: Palette.stoneDark)
        }
        return Model(name: name, mesh: b.mesh)
    }

    /// The top of the keep's hall chimney.
    static func chimney(seat: Bool) -> Vec3 {
        let half: Float = seat ? 0.17 : 0.155, front: Float = seat ? 0.34 : 0.3
        return Vec3(0.13, 0.43, (half - 0.06 + front) / 2)
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
        gate(&b, level: level, height: h, half: gateHalf)
        return Model(name: name, mesh: b.mesh)
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
        return b.mesh
    }
}
