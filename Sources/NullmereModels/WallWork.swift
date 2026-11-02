import Foundation

/// The walls' own work at their first two levels, where they stood plainest:
/// the palisade's walkway on its posts behind the stakes, braced, its gate
/// hung with two leaves strapped in iron and two watch platforms under
/// thatch; the low stone wall's coping, its buttresses, its gate under a
/// roofed gatehouse with torches lit either side.
enum WallWork {
    static func dress(_ model: Model, level: Int) -> Model {
        guard level <= 2 else { return model }
        var b = MeshBuilder()
        if level == 1 { palisade(&b) } else { lowWall(&b) }
        let laid = Estate.layered(model.mesh, b.mesh)
        guard laid.triangleCount <= Estate.ceiling else { return model }
        return Model(name: model.name, mesh: laid, rig: model.rig, motion: model.motion)
    }

    /// The runs of the wall, corner to corner, the gate's side split.
    static func runs(gateHalf: Float) -> [(Vec3, Vec3)] {
        var runs: [(Vec3, Vec3)] = []
        for index in 0..<6 {
            let a = Holds.wallCorner(index), c = Holds.wallCorner(index + 1)
            if index == 1 {
                runs.append((a, Vec3(gateHalf, 0, a.z)))
                runs.append((Vec3(-gateHalf, 0, a.z), c))
            } else {
                runs.append((a, c))
            }
        }
        return runs
    }

    /// Toward the hold's heart from a point on the wall, by `by`.
    static func inward(_ p: Vec3, _ by: Float) -> Vec3 {
        let flat = Vec3(p.x, 0, p.z)
        return p - flat.normalized * by
    }

    static func palisade(_ b: inout MeshBuilder) {
        let h: Float = 0.2
        for (a, c) in runs(gateHalf: 0.085) {
            let posts = max(Int(((c - a).length / 0.2).rounded()), 2)
            var last: Vec3?
            for index in 0...posts {
                let at = inward(a.mix(c, Float(index) / Float(posts)), 0.04)
                b.limb(from: at + Vec3(0, -0.05, 0), to: at + Vec3(0, h * 0.72, 0), radius: 0.008, sides: 3, color: Palette.timberDark)
                if let last {
                    b.beam(from: last + Vec3(0, h * 0.72, 0), to: at + Vec3(0, h * 0.72, 0), width: 0.03, depth: 0.008, color: Palette.timber)
                    b.fine { b in
                        b.beam(from: last + Vec3(0, 0.01, 0), to: at + Vec3(0, h * 0.68, 0), width: 0.006, color: Palette.timberDark)
                    }
                }
                last = at
            }
        }
        // The gate's two leaves, strapped in iron.
        let z = Holds.wallCorner(1).z
        for side in [Float(-1), 1] {
            b.box(min: Vec3(side < 0 ? -0.075 : 0.004, -0.02, z - 0.012), max: Vec3(side < 0 ? -0.004 : 0.075, h * 0.85, z + 0.004),
                  color: Palette.timber)
            for y in [Float(0.04), 0.12] {
                b.box(min: Vec3(side < 0 ? -0.072 : 0.007, y, z + 0.003), max: Vec3(side < 0 ? -0.007 : 0.072, y + 0.012, z + 0.008),
                      color: Palette.iron)
            }
        }
        // Two watch platforms under thatch, at the far corners.
        for corner in [0, 3] {
            let at = inward(Holds.wallCorner(corner), 0.06)
            for (dx, dz) in [(-0.035, -0.035), (0.035, -0.035), (-0.035, 0.035), (0.035, 0.035)] as [(Float, Float)] {
                b.limb(from: at + Vec3(dx, -0.05, dz), to: at + Vec3(dx, 0.36, dz), radius: 0.007, color: Palette.timberDark)
            }
            b.box(min: at + Vec3(-0.045, 0.24, -0.045), max: at + Vec3(0.045, 0.255, 0.045), color: Palette.timber)
            b.place(.translation(at)) {
                $0.hipRoof(width: 0.11, depth: 0.11, base: 0.36, height: 0.07, color: Palette.thatch, overhang: 0.01)
            }
            b.fine { b in
                for (p, q) in [(Vec3(-0.045, 0.29, -0.045), Vec3(0.045, 0.29, -0.045)), (Vec3(0.045, 0.29, -0.045), Vec3(0.045, 0.29, 0.045)),
                               (Vec3(0.045, 0.29, 0.045), Vec3(-0.045, 0.29, 0.045)), (Vec3(-0.045, 0.29, 0.045), Vec3(-0.045, 0.29, -0.045))] {
                    b.beam(from: at + p, to: at + q, width: 0.006, color: Palette.timber)
                }
                b.ladder(from: at + Vec3(0.06, 0, 0.06), to: at + Vec3(0.04, 0.25, 0.04), width: 0.03, rungs: 5, color: Palette.timberPale)
            }
        }
    }

    static func lowWall(_ b: inout MeshBuilder) {
        let h: Float = 0.17, thick: Float = 0.062
        for (a, c) in runs(gateHalf: 0.085) {
            // The coping, pale, a little proud of the wall.
            b.beam(from: a + Vec3(0, h + 0.008, 0), to: c + Vec3(0, h + 0.008, 0), width: thick + 0.014, depth: 0.014, color: Palette.stonePale)
            // Buttresses outward every so often.
            let count = max(Int(((c - a).length / 0.16).rounded()), 1)
            for index in 1..<max(count, 2) where count > 1 {
                let at = a.mix(c, Float(index) / Float(count))
                let out = inward(at, -0.045)
                b.box(center: out + Vec3(0, h * 0.4, 0), size: Vec3(0.035, h * 0.8 + 0.2, 0.035),
                      turn: Float(atan2(Double(at.x), Double(at.z))), color: Palette.stoneDark)
            }
            b.fine { b in
                for t in stride(from: Float(0.1), to: 1, by: 0.2) {
                    let at = a.mix(c, t)
                    b.box(center: at + Vec3(0, h * 0.55, 0), size: Vec3(0.03, 0.008, thick + 0.004), turn: Float(atan2(Double(c.x - a.x), Double(c.z - a.z))),
                          color: Palette.stone)
                }
            }
        }
        // The gate: leaves strapped in iron, a gatehouse roofed over it, its torches lit.
        let z = Holds.wallCorner(1).z
        b.box(min: Vec3(-0.08, -0.02, z - 0.012), max: Vec3(0.08, h * 0.9, z + 0.004), color: Palette.timber)
        for y in [Float(0.035), 0.11] {
            b.box(min: Vec3(-0.078, y, z + 0.003), max: Vec3(0.078, y + 0.012, z + 0.008), color: Palette.iron)
        }
        for x in [Float(-0.1), 0.1] {
            b.box(min: Vec3(x - 0.025, -0.05, z - 0.04), max: Vec3(x + 0.025, h + 0.12, z + 0.04), color: Palette.stone)
            b.with(material: .glow) {
                $0.place(.translation(Vec3(x, h + 0.05, z + 0.05))) {
                    $0.lathe([(0, -0.012), (0.01, 0), (0, 0.022)], sides: 5, color: Palette.fire)
                }
            }
            b.fine { b in
                b.limb(from: Vec3(x, h + 0.01, z + 0.04), to: Vec3(x, h + 0.04, z + 0.05), radius: 0.004, color: Palette.iron)
            }
        }
        b.place(.translation(Vec3(0, h + 0.12, z))) {
            $0.box(min: Vec3(-0.13, 0, -0.05), max: Vec3(0.13, 0.06, 0.05), color: Palette.stone)
            $0.gableRoof(width: 0.27, depth: 0.11, base: 0.06, height: 0.07, color: Palette.slate, overhang: 0.012)
        }
        b.window(Vec3(0, h + 0.15, z + 0.051), width: 0.02, height: 0.022, facing: 0)
    }
}
