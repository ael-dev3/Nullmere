import Foundation

/// Solids the models share, built on the plain ones.
extension MeshBuilder {
    /// A lathe's sides without its ends, for solids whose ends are hidden
    /// in others or come to a point: cheaper by the ends' triangles.
    mutating func tube(_ profile: [(radius: Float, y: Float)], sides: Int, color: Vec3, twist: Float = 0) {
        guard profile.count >= 2, sides >= 3 else { return }
        let step = 2 * Float.pi / Float(sides)
        for band in 0..<(profile.count - 1) {
            let (r0, y0) = profile[band], (r1, y1) = profile[band + 1]
            for side in 0..<sides {
                let a0 = Float(side) * step + twist, a1 = a0 + step
                quad(MeshBuilder.ring(r0, y0, a0), MeshBuilder.ring(r0, y0, a1),
                     MeshBuilder.ring(r1, y1, a1), MeshBuilder.ring(r1, y1, a0), color: color)
            }
        }
    }

    /// A limb or a haft from one point to another, its ends left open for
    /// the joints to hide.
    mutating func limb(from a: Vec3, to b: Vec3, radius: Float, topRadius: Float? = nil, sides: Int = 4, color: Vec3) {
        let length = (b - a).length
        guard length > 0 else { return }
        place(.translation(a) * Mat4.aligningUp(to: b - a)) {
            $0.tube([(radius, 0), (topRadius ?? radius, length)], sides: sides, color: color)
        }
    }

    /// A thin flat thing seen from both sides: a pennant, a blade, a tabard.
    mutating func sheet(_ points: [Vec3], normal: Vec3, thickness: Float = 0.004, color: Vec3, back: Vec3? = nil) {
        let offset = normal.normalized * (thickness / 2)
        face(points.map { $0 + offset }, outward: normal, color: color)
        face(points.map { $0 - offset }, outward: -normal, color: back ?? color)
    }

    /// A box about its centre, turned about the vertical.
    mutating func box(center: Vec3, size: Vec3, turn: Float, color: Vec3) {
        place(.translation(center) * .rotationY(turn)) { $0.box(center: .zero, size: size, color: color) }
    }

    /// A squared timber or stone from one point to another, `width` across
    /// and `depth` through. A level one is `width` across the ground and
    /// `depth` deep; a standing one `width` east to west.
    mutating func beam(from a: Vec3, to b: Vec3, width: Float, depth: Float? = nil, color: Vec3) {
        let along = b - a
        let length = along.length
        guard length > 0 else { return }
        let up = along / length
        let reference: Vec3 = abs(up.y) > 0.95 ? Vec3(0, 0, 1) : .up
        let side = up.cross(reference).normalized
        let front = side.cross(up)
        let frame = Mat4(Vec4(side.x, side.y, side.z, 0), Vec4(up.x, up.y, up.z, 0), Vec4(front.x, front.y, front.z, 0),
                         Vec4(a.x, a.y, a.z, 1))
        let d = depth ?? width
        place(frame) { $0.box(min: Vec3(-width / 2, 0, -d / 2), max: Vec3(width / 2, length, d / 2), color: color) }
    }

    /// A rough lump: a ball of `size` (its half-extents), each point pushed
    /// in or out by up to `jitter` of it, the same for the same seed.
    mutating func rock(center: Vec3, size: Vec3, rings: Int = 3, sides: Int = 6, jitter: Float = 0.2, seed: UInt32,
                       color: Vec3) {
        guard rings >= 2, sides >= 3 else { return }
        var grid: [[Vec3]] = []
        for ring in 0...rings {
            let latitude = Float.pi * Float(ring) / Float(rings) - Float.pi / 2
            let pole = ring == 0 || ring == rings
            grid.append((0..<sides).map { side in
                let longitude = 2 * Float.pi * Float(side) / Float(sides)
                let push = 1 + jitter * (2 * Noise.unit(Int32(ring), Int32(pole ? 0 : side), seed) - 1)
                let direction = Vec3(Float(cos(Double(latitude)) * cos(Double(longitude))), Float(sin(Double(latitude))),
                                     -Float(cos(Double(latitude)) * sin(Double(longitude))))
                return center + direction * size * push
            })
        }
        for ring in 0..<rings {
            for side in 0..<sides {
                let next = (side + 1) % sides
                quad(grid[ring][side], grid[ring][next], grid[ring + 1][next], grid[ring + 1][side], color: color)
            }
        }
    }

    /// A roof of four slopes on a `width` by `depth` floor at `base`, its
    /// ridge east to west; a square one comes to a point.
    mutating func hipRoof(width: Float, depth: Float, base: Float, height: Float, color: Vec3, overhang: Float = 0) {
        let w = width / 2 + overhang, d = depth / 2 + overhang, top = base + height
        let r = max(w - d, 0)
        let p = { (x: Float, y: Float, z: Float) in Vec3(x, y, z) }
        quad(p(-w, base, d), p(w, base, d), p(r, top, 0), p(-r, top, 0), color: color)
        quad(p(w, base, -d), p(-w, base, -d), p(-r, top, 0), p(r, top, 0), color: color)
        triangle(p(w, base, d), p(w, base, -d), p(r, top, 0), color: color)
        triangle(p(-w, base, -d), p(-w, base, d), p(-r, top, 0), color: color)
        quad(p(-w, base, -d), p(w, base, -d), p(w, base, d), p(-w, base, d), color: color)
    }

    /// A cloth hanging from the top of a pole: it runs `width` out along
    /// +x (turned about the vertical by `turn`) and `height` down, moving
    /// more toward its free end. House-coloured unless told otherwise.
    mutating func flag(at top: Vec3, width: Float, height: Float, turn: Float = 0, color: Vec3 = Palette.house,
                       material: Material = .cloth, tail: Bool = false) {
        with(material: material, sway: 1) {
            // Built along its own y, from the pole outward, for the sway to rise along it.
            $0.swayRange = (0, width)
            $0.place(.translation(top) * .rotationY(turn) * .rotationZ(-.pi / 2)) {
                let t: Float = max(width * 0.03, 0.004)
                // Swallow-tailed: a notch cut into the free end.
                let outline = tail
                    ? [Vec3(0, 0, 0), Vec3(0, width, 0), Vec3(height / 2, width * 0.72, 0), Vec3(height, width, 0), Vec3(height, 0, 0)]
                    : [Vec3(0, 0, 0), Vec3(0, width, 0), Vec3(height, width, 0), Vec3(height, 0, 0)]
                $0.sheet(outline, normal: Vec3(0, 0, 1), thickness: t, color: color)
            }
        }
    }

    /// A lit window: a shallow block of light set into a wall at `center`,
    /// whose outside faces along `facing` (radians about the vertical, from
    /// +z toward +x). It shows a little either side of the wall's face, so
    /// it reads on the flats of a round tower as on a straight wall.
    mutating func window(_ center: Vec3, width: Float, height: Float, facing: Float, color: Vec3 = Palette.candle) {
        with(material: .glow) {
            $0.place(.translation(center) * .rotationY(facing)) {
                $0.box(center: .zero, size: Vec3(width, height, 0.024), color: color)
            }
        }
    }

    /// A lit window on a round wall of `radius`, at `angle` round it (as
    /// `ring` counts) and `y` high.
    mutating func window(onRound radius: Float, y: Float, angle: Float, width: Float, height: Float, color: Vec3 = Palette.candle) {
        window(MeshBuilder.ring(radius, y, angle), width: width, height: height, facing: angle + .pi / 2, color: color)
    }

    /// A door: a dark slab set into a wall.
    mutating func door(_ center: Vec3, width: Float, height: Float, facing: Float, color: Vec3 = Palette.timberDark) {
        place(.translation(center) * .rotationY(facing)) {
            $0.box(center: .zero, size: Vec3(width, height, 0.02), color: color)
        }
    }

    /// Merlons along a wall's top from `a` to `b`: `count` blocks with gaps.
    mutating func merlons(from a: Vec3, to b: Vec3, count: Int, size: Vec3, color: Vec3) {
        guard count > 0 else { return }
        let along = b - a
        let turn = Float(atan2(Double(along.x), Double(along.z))) - .pi / 2
        for index in 0..<count {
            let t = (Float(index) + 0.5) / Float(count)
            box(center: a + along * t + Vec3(0, size.y / 2, 0), size: size, turn: turn, color: color)
        }
    }

    /// A round tower's crown of merlons on a ring.
    mutating func merlonRing(radius: Float, base: Float, count: Int, size: Vec3, color: Vec3) {
        for index in 0..<count {
            let angle = 2 * Float.pi * Float(index) / Float(count)
            let at = MeshBuilder.ring(radius, base + size.y / 2, angle)
            box(center: at, size: size, turn: angle + .pi / 2, color: color)
        }
    }

    /// A spoked wheel standing in the y-z plane about `center`, its axle
    /// along x.
    mutating func wheel(center: Vec3, radius: Float, width: Float, spokes: Int = 4, color: Vec3, rim: Vec3? = nil) {
        place(.translation(center) * .rotationZ(.pi / 2)) {
            let w = width / 2
            $0.lathe([(radius, -w), (radius, w)], sides: 8, color: rim ?? color)
        }
        for index in 0..<spokes {
            let angle = Float.pi * Float(index) / Float(spokes)
            let d = Vec3(0, Float(cos(Double(angle))), Float(sin(Double(angle)))) * radius * 0.95
            beam(from: center - d, to: center + d, width: width * 0.6, color: color)
        }
    }

    /// A ladder leaning from its foot to its top.
    mutating func ladder(from a: Vec3, to b: Vec3, width: Float, rungs: Int, color: Vec3) {
        let along = b - a
        let side = along.cross(.up).normalized * (width / 2)
        let rail = width * 0.12
        beam(from: a + side, to: b + side, width: rail, color: color)
        beam(from: a - side, to: b - side, width: rail, color: color)
        for index in 1...max(rungs, 1) {
            let t = Float(index) / Float(rungs + 1)
            beam(from: a + along * t - side, to: a + along * t + side, width: rail * 0.8, color: color)
        }
    }
}
