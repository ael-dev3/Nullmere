import Foundation

/// Builds a faceted mesh from solids: each face lit flat, as carved wood
/// and cut stone are, which keeps the low moonlight crisp on every edge.
public struct MeshBuilder: Sendable {
    /// What is built so far: its coarse work, then its fine work, drawn
    /// only near enough to see it.
    public var mesh: Mesh {
        guard !fineWork.isEmpty else { return coarse }
        var whole = coarse
        whole.append(fineWork)
        whole.fineFrom = coarse.indices.count
        return whole
    }
    private var coarse = Mesh()
    private var fineWork = Mesh()
    /// Whether the next triangles are fine work.
    private var buildingFine = false
    /// The rig part the next triangles move with.
    public var part: UInt16 = 0
    public var material: Material = .plain
    /// How much the next triangles move in the wind.
    public var sway: Float = 0
    /// When set, sway rises from nothing at the first height to full at the
    /// second, in the solid's own frame before `transform`: a tree's
    /// trunk stands while its crown moves.
    public var swayRange: (low: Float, high: Float)?
    /// Where the next solids go.
    public var transform: Mat4 = .identity
    /// The grain of the next triangles; nil, each takes its colour's, and
    /// a surface that shines or glows is smooth.
    public var surface: Surface?

    public init() {}

    /// Triangles smaller than this are dropped: a cone's point, a pole of a sphere.
    static let degenerateArea: Float = 1e-9

    // MARK: Faces

    /// One triangle, its corners counter-clockwise seen from outside.
    public mutating func triangle(_ a: Vec3, _ b: Vec3, _ c: Vec3, color: Vec3) {
        // A mirroring placement turns the winding inside out: put it back.
        let (b, c) = transform.isMirroring ? (c, b) : (b, c)
        let pa = transform.transformPoint(a), pb = transform.transformPoint(b), pc = transform.transformPoint(c)
        let n = (pb - pa).cross(pc - pa)
        guard n.length > MeshBuilder.degenerateArea else { return }
        let normal = n.normalized
        let grain = surface ?? (material == .plain || material == .foliage ? Surface.of(color) : .smooth)
        let corners = [(a, pa), (b, pb), (c, pc)].map { local, world in
            MeshVertex(position: world, normal: normal, color: color, part: part, material: material, sway: swayAt(local), surface: grain)
        }
        if buildingFine {
            fineWork.add(corners)
        } else {
            coarse.add(corners)
        }
    }

    /// Builds fine work, too small to see from afar: whenever it is built,
    /// it is kept after the rest, for the renderer to leave off far away.
    public mutating func fine(_ body: (inout MeshBuilder) -> Void) {
        let saved = buildingFine
        buildingFine = true
        body(&self)
        buildingFine = saved
    }

    private func swayAt(_ local: Vec3) -> Float {
        guard let range = swayRange, range.high > range.low else { return sway }
        let t = min(max((local.y - range.low) / (range.high - range.low), 0), 1)
        return sway * t * t
    }

    /// A four-cornered face, counter-clockwise seen from outside.
    public mutating func quad(_ a: Vec3, _ b: Vec3, _ c: Vec3, _ d: Vec3, color: Vec3) {
        triangle(a, b, c, color: color)
        triangle(a, c, d, color: color)
    }

    /// A flat convex face, counter-clockwise seen from outside.
    public mutating func polygon(_ points: [Vec3], color: Vec3) {
        guard points.count >= 3 else { return }
        for i in 1..<(points.count - 1) {
            triangle(points[0], points[i], points[i + 1], color: color)
        }
    }

    /// A face turned, if need be, to look along `outward`.
    public mutating func face(_ points: [Vec3], outward: Vec3, color: Vec3) {
        guard points.count >= 3 else { return }
        let n = (points[1] - points[0]).cross(points[2] - points[0])
        polygon(n.dot(outward) >= 0 ? points : points.reversed(), color: color)
    }

    // MARK: Solids

    /// Builds `body` with its solids placed by `placement` within the current transform.
    public mutating func place(_ placement: Mat4, _ body: (inout MeshBuilder) -> Void) {
        let saved = transform
        transform = saved * placement
        body(&self)
        transform = saved
    }

    /// Builds `body` as another part of the rig, with another material.
    /// Draws with a grain of its own where colours alone would not say it;
    /// none given, as the colours say.
    public mutating func with(surface: Surface?, _ body: (inout MeshBuilder) -> Void) {
        let saved = self.surface
        if let surface { self.surface = surface }
        body(&self)
        self.surface = saved
    }

    public mutating func with(part: UInt16? = nil, material: Material? = nil, sway: Float? = nil,
                              _ body: (inout MeshBuilder) -> Void) {
        let saved = (self.part, self.material, self.sway, self.swayRange)
        if let part { self.part = part }
        if let material { self.material = material }
        if let sway { self.sway = sway }
        body(&self)
        (self.part, self.material, self.sway, self.swayRange) = saved
    }

    /// A box between two corners.
    public mutating func box(min low: Vec3, max high: Vec3, color: Vec3) {
        let p = { (x: Float, y: Float, z: Float) in Vec3(x, y, z) }
        let (x0, y0, z0, x1, y1, z1) = (low.x, low.y, low.z, high.x, high.y, high.z)
        quad(p(x1, y0, z1), p(x1, y0, z0), p(x1, y1, z0), p(x1, y1, z1), color: color) // east
        quad(p(x0, y0, z0), p(x0, y0, z1), p(x0, y1, z1), p(x0, y1, z0), color: color) // west
        quad(p(x0, y1, z1), p(x1, y1, z1), p(x1, y1, z0), p(x0, y1, z0), color: color) // top
        quad(p(x0, y0, z0), p(x1, y0, z0), p(x1, y0, z1), p(x0, y0, z1), color: color) // bottom
        quad(p(x0, y0, z1), p(x1, y0, z1), p(x1, y1, z1), p(x0, y1, z1), color: color) // south
        quad(p(x1, y0, z0), p(x0, y0, z0), p(x0, y1, z0), p(x1, y1, z0), color: color) // north
    }

    /// A box about a point.
    public mutating func box(center: Vec3, size: Vec3, color: Vec3) {
        box(min: center - size / 2, max: center + size / 2, color: color)
    }

    /// A point on a ring about the vertical axis: angle zero due east,
    /// rising counter-clockwise seen from above.
    static func ring(_ radius: Float, _ y: Float, _ angle: Float) -> Vec3 {
        Vec3(radius * Float(cos(Double(angle))), y, -radius * Float(sin(Double(angle))))
    }

    /// A solid turned about the vertical axis from its profile, bottom to
    /// top: a tower, a trunk, a cone, a dome. Ends with a radius are
    /// capped. `colors`, if given, colours each band between two rings.
    public mutating func lathe(_ profile: [(radius: Float, y: Float)], sides: Int, color: Vec3, colors: [Vec3]? = nil,
                               twist: Float = 0) {
        guard profile.count >= 2, sides >= 3 else { return }
        let step = 2 * Float.pi / Float(sides)
        for band in 0..<(profile.count - 1) {
            let (r0, y0) = profile[band], (r1, y1) = profile[band + 1]
            let shade = colors.map { $0[min(band, $0.count - 1)] } ?? color
            for side in 0..<sides {
                let a0 = Float(side) * step + twist, a1 = a0 + step
                quad(MeshBuilder.ring(r0, y0, a0), MeshBuilder.ring(r0, y0, a1),
                     MeshBuilder.ring(r1, y1, a1), MeshBuilder.ring(r1, y1, a0), color: shade)
            }
        }
        if let bottom = profile.first, bottom.radius > 0 {
            let points = (0..<sides).reversed().map { MeshBuilder.ring(bottom.radius, bottom.y, Float($0) * step + twist) }
            polygon(points, color: colors?.first ?? color)
        }
        if let top = profile.last, top.radius > 0 {
            let points = (0..<sides).map { MeshBuilder.ring(top.radius, top.y, Float($0) * step + twist) }
            polygon(points, color: colors?.last ?? color)
        }
    }

    /// A column of `sides` faces, narrowing or widening from bottom to top.
    public mutating func prism(sides: Int, radius: Float, topRadius: Float? = nil, from bottom: Float = 0, to top: Float,
                               color: Vec3, twist: Float = 0) {
        lathe([(radius, bottom), (topRadius ?? radius, top)], sides: sides, color: color, twist: twist)
    }

    /// A cone from a round base up to a point.
    public mutating func cone(sides: Int, radius: Float, from bottom: Float = 0, to top: Float, color: Vec3, twist: Float = 0) {
        lathe([(radius, bottom), (0, top)], sides: sides, color: color, twist: twist)
    }

    /// A faceted ball.
    public mutating func sphere(center: Vec3, radius: Float, rings: Int = 4, sides: Int = 6, color: Vec3,
                                squash: Float = 1) {
        let profile: [(radius: Float, y: Float)] = (0...rings).map { ring in
            let angle = Float.pi * Float(ring) / Float(rings) - Float.pi / 2
            return (radius * Float(cos(Double(angle))), radius * squash * Float(sin(Double(angle))))
        }
        place(.translation(center)) { $0.lathe(profile, sides: sides, color: color) }
    }

    /// A roof with two slopes, its ridge running east to west, standing on
    /// a `width` by `depth` floor at `base`.
    public mutating func gableRoof(width: Float, depth: Float, base: Float, height: Float, color: Vec3, overhang: Float = 0) {
        let w = width / 2 + overhang, d = depth / 2 + overhang, top = base + height
        let p = { (x: Float, y: Float, z: Float) in Vec3(x, y, z) }
        quad(p(-w, base, d), p(w, base, d), p(w, top, 0), p(-w, top, 0), color: color)   // south slope
        quad(p(w, base, -d), p(-w, base, -d), p(-w, top, 0), p(w, top, 0), color: color) // north slope
        triangle(p(w, base, d), p(w, base, -d), p(w, top, 0), color: color)              // east gable
        triangle(p(-w, base, -d), p(-w, base, d), p(-w, top, 0), color: color)           // west gable
        quad(p(-w, base, -d), p(w, base, -d), p(w, base, d), p(-w, base, d), color: color) // underside
    }

    /// A pole of `sides` faces from one point to another.
    public mutating func strut(from a: Vec3, to b: Vec3, radius: Float, topRadius: Float? = nil, sides: Int = 4, color: Vec3) {
        let length = (b - a).length
        guard length > 0 else { return }
        place(.translation(a) * Mat4.aligningUp(to: b - a)) {
            $0.prism(sides: sides, radius: radius, topRadius: topRadius, from: 0, to: length, color: color)
        }
    }
}

public extension Mat4 {
    /// Whether this turns a shape into its mirror image.
    var isMirroring: Bool {
        let x = Vec3(c0.x, c0.y, c0.z), y = Vec3(c1.x, c1.y, c1.z), z = Vec3(c2.x, c2.y, c2.z)
        return x.cross(y).dot(z) < 0
    }

    /// A turn of `angle` radians about `axis`, right-handed.
    static func rotation(axis: Vec3, angle: Float) -> Mat4 {
        let a = axis.normalized
        let c = Float(cos(Double(angle))), s = Float(sin(Double(angle))), t = 1 - c
        return Mat4(Vec4(t * a.x * a.x + c, t * a.x * a.y + s * a.z, t * a.x * a.z - s * a.y, 0),
                    Vec4(t * a.x * a.y - s * a.z, t * a.y * a.y + c, t * a.y * a.z + s * a.x, 0),
                    Vec4(t * a.x * a.z + s * a.y, t * a.y * a.z - s * a.x, t * a.z * a.z + c, 0),
                    Vec4(0, 0, 0, 1))
    }

    /// The turn that carries straight up onto `direction`.
    static func aligningUp(to direction: Vec3) -> Mat4 {
        let d = direction.normalized
        let axis = Vec3.up.cross(d)
        let cosine = min(max(Vec3.up.dot(d), -1), 1)
        if axis.length < 1e-6 {
            return cosine > 0 ? .identity : .rotationX(.pi)
        }
        return rotation(axis: axis, angle: Float(acos(Double(cosine))))
    }
}
