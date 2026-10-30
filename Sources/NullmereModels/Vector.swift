import Foundation

/// A point or direction in the world's three dimensions: x east, y up, z
/// south, so the map's own x and y lie along x and z. One unit is a hex's
/// corner radius.
public typealias Vec3 = SIMD3<Float>
public typealias Vec4 = SIMD4<Float>

public extension SIMD3 where Scalar == Float {
    static let up = Vec3(0, 1, 0)

    func dot(_ other: Vec3) -> Float { (self * other).sum() }

    func cross(_ other: Vec3) -> Vec3 {
        Vec3(y * other.z - z * other.y, z * other.x - x * other.z, x * other.y - y * other.x)
    }

    var length: Float { dot(self).squareRoot() }

    /// This direction at unit length; the zero vector stays zero.
    var normalized: Vec3 {
        let l = length
        return l > 0 ? self / l : self
    }

    /// The point a fraction `t` of the way to `other`.
    func mix(_ other: Vec3, _ t: Float) -> Vec3 { self + (other - self) * t }
}

/// A 4×4 transform, column by column, laid out as Metal's `float4x4` and
/// simd's `simd_float4x4` are, so it goes to the GPU as it is.
public struct Mat4: Equatable, Sendable {
    public var c0: Vec4
    public var c1: Vec4
    public var c2: Vec4
    public var c3: Vec4

    public init(_ c0: Vec4, _ c1: Vec4, _ c2: Vec4, _ c3: Vec4) {
        self.c0 = c0
        self.c1 = c1
        self.c2 = c2
        self.c3 = c3
    }

    public static let identity = Mat4(Vec4(1, 0, 0, 0), Vec4(0, 1, 0, 0), Vec4(0, 0, 1, 0), Vec4(0, 0, 0, 1))

    public static func translation(_ t: Vec3) -> Mat4 {
        Mat4(Vec4(1, 0, 0, 0), Vec4(0, 1, 0, 0), Vec4(0, 0, 1, 0), Vec4(t.x, t.y, t.z, 1))
    }

    public static func scale(_ s: Vec3) -> Mat4 {
        Mat4(Vec4(s.x, 0, 0, 0), Vec4(0, s.y, 0, 0), Vec4(0, 0, s.z, 0), Vec4(0, 0, 0, 1))
    }

    public static func scale(_ s: Float) -> Mat4 { scale(Vec3(repeating: s)) }

    /// A turn of `angle` radians about the x axis: a positive angle tips +y toward +z.
    public static func rotationX(_ angle: Float) -> Mat4 {
        let c = Float(cos(Double(angle))), s = Float(sin(Double(angle)))
        return Mat4(Vec4(1, 0, 0, 0), Vec4(0, c, s, 0), Vec4(0, -s, c, 0), Vec4(0, 0, 0, 1))
    }

    /// A turn about the vertical: a positive angle turns +z toward +x.
    public static func rotationY(_ angle: Float) -> Mat4 {
        let c = Float(cos(Double(angle))), s = Float(sin(Double(angle)))
        return Mat4(Vec4(c, 0, -s, 0), Vec4(0, 1, 0, 0), Vec4(s, 0, c, 0), Vec4(0, 0, 0, 1))
    }

    /// A turn about the z axis: a positive angle tips +x toward +y.
    public static func rotationZ(_ angle: Float) -> Mat4 {
        let c = Float(cos(Double(angle))), s = Float(sin(Double(angle)))
        return Mat4(Vec4(c, s, 0, 0), Vec4(-s, c, 0, 0), Vec4(0, 0, 1, 0), Vec4(0, 0, 0, 1))
    }

    /// Turns about x, then y, then z (applied in that order to a point).
    public static func rotation(_ euler: Vec3) -> Mat4 {
        rotationZ(euler.z) * rotationY(euler.y) * rotationX(euler.x)
    }

    public static func * (a: Mat4, b: Mat4) -> Mat4 {
        Mat4(a.apply(b.c0), a.apply(b.c1), a.apply(b.c2), a.apply(b.c3))
    }

    public func apply(_ v: Vec4) -> Vec4 {
        c0 * v.x + c1 * v.y + c2 * v.z + c3 * v.w
    }

    public func transformPoint(_ p: Vec3) -> Vec3 {
        let v = apply(Vec4(p.x, p.y, p.z, 1))
        return Vec3(v.x, v.y, v.z) / (v.w == 0 ? 1 : v.w)
    }

    /// A direction moved by this transform's turn and stretch, without its shift.
    public func transformDirection(_ d: Vec3) -> Vec3 {
        let v = apply(Vec4(d.x, d.y, d.z, 0))
        return Vec3(v.x, v.y, v.z)
    }

    /// The matrix that carries normals as this carries points: the inverse
    /// transpose of its upper 3×3.
    public var normalMatrix: Mat4 {
        guard let inverse = inverse else { return self }
        return Mat4(Vec4(inverse.c0.x, inverse.c1.x, inverse.c2.x, 0),
                    Vec4(inverse.c0.y, inverse.c1.y, inverse.c2.y, 0),
                    Vec4(inverse.c0.z, inverse.c1.z, inverse.c2.z, 0),
                    Vec4(0, 0, 0, 1))
    }

    public var transposed: Mat4 {
        Mat4(Vec4(c0.x, c1.x, c2.x, c3.x), Vec4(c0.y, c1.y, c2.y, c3.y), Vec4(c0.z, c1.z, c2.z, c3.z), Vec4(c0.w, c1.w, c2.w, c3.w))
    }

    /// The inverse, or nil if this flattens space.
    public var inverse: Mat4? {
        let m = [c0.x, c0.y, c0.z, c0.w, c1.x, c1.y, c1.z, c1.w, c2.x, c2.y, c2.z, c2.w, c3.x, c3.y, c3.z, c3.w].map(Double.init)
        var inv = [Double](repeating: 0, count: 16)
        inv[0] = m[5] * m[10] * m[15] - m[5] * m[11] * m[14] - m[9] * m[6] * m[15] + m[9] * m[7] * m[14] + m[13] * m[6] * m[11] - m[13] * m[7] * m[10]
        inv[4] = -m[4] * m[10] * m[15] + m[4] * m[11] * m[14] + m[8] * m[6] * m[15] - m[8] * m[7] * m[14] - m[12] * m[6] * m[11] + m[12] * m[7] * m[10]
        inv[8] = m[4] * m[9] * m[15] - m[4] * m[11] * m[13] - m[8] * m[5] * m[15] + m[8] * m[7] * m[13] + m[12] * m[5] * m[11] - m[12] * m[7] * m[9]
        inv[12] = -m[4] * m[9] * m[14] + m[4] * m[10] * m[13] + m[8] * m[5] * m[14] - m[8] * m[6] * m[13] - m[12] * m[5] * m[10] + m[12] * m[6] * m[9]
        inv[1] = -m[1] * m[10] * m[15] + m[1] * m[11] * m[14] + m[9] * m[2] * m[15] - m[9] * m[3] * m[14] - m[13] * m[2] * m[11] + m[13] * m[3] * m[10]
        inv[5] = m[0] * m[10] * m[15] - m[0] * m[11] * m[14] - m[8] * m[2] * m[15] + m[8] * m[3] * m[14] + m[12] * m[2] * m[11] - m[12] * m[3] * m[10]
        inv[9] = -m[0] * m[9] * m[15] + m[0] * m[11] * m[13] + m[8] * m[1] * m[15] - m[8] * m[3] * m[13] - m[12] * m[1] * m[11] + m[12] * m[3] * m[9]
        inv[13] = m[0] * m[9] * m[14] - m[0] * m[10] * m[13] - m[8] * m[1] * m[14] + m[8] * m[2] * m[13] + m[12] * m[1] * m[10] - m[12] * m[2] * m[9]
        inv[2] = m[1] * m[6] * m[15] - m[1] * m[7] * m[14] - m[5] * m[2] * m[15] + m[5] * m[3] * m[14] + m[13] * m[2] * m[7] - m[13] * m[3] * m[6]
        inv[6] = -m[0] * m[6] * m[15] + m[0] * m[7] * m[14] + m[4] * m[2] * m[15] - m[4] * m[3] * m[14] - m[12] * m[2] * m[7] + m[12] * m[3] * m[6]
        inv[10] = m[0] * m[5] * m[15] - m[0] * m[7] * m[13] - m[4] * m[1] * m[15] + m[4] * m[3] * m[13] + m[12] * m[1] * m[7] - m[12] * m[3] * m[5]
        inv[14] = -m[0] * m[5] * m[14] + m[0] * m[6] * m[13] + m[4] * m[1] * m[14] - m[4] * m[2] * m[13] - m[12] * m[1] * m[6] + m[12] * m[2] * m[5]
        inv[3] = -m[1] * m[6] * m[11] + m[1] * m[7] * m[10] + m[5] * m[2] * m[11] - m[5] * m[3] * m[10] - m[9] * m[2] * m[7] + m[9] * m[3] * m[6]
        inv[7] = m[0] * m[6] * m[11] - m[0] * m[7] * m[10] - m[4] * m[2] * m[11] + m[4] * m[3] * m[10] + m[8] * m[2] * m[7] - m[8] * m[3] * m[6]
        inv[11] = -m[0] * m[5] * m[11] + m[0] * m[7] * m[9] + m[4] * m[1] * m[11] - m[4] * m[3] * m[9] - m[8] * m[1] * m[7] + m[8] * m[3] * m[5]
        inv[15] = m[0] * m[5] * m[10] - m[0] * m[6] * m[9] - m[4] * m[1] * m[10] + m[4] * m[2] * m[9] + m[8] * m[1] * m[6] - m[8] * m[2] * m[5]
        let det = m[0] * inv[0] + m[1] * inv[4] + m[2] * inv[8] + m[3] * inv[12]
        guard abs(det) > 1e-12 else { return nil }
        let f = inv.map { Float($0 / det) }
        return Mat4(Vec4(f[0], f[1], f[2], f[3]), Vec4(f[4], f[5], f[6], f[7]), Vec4(f[8], f[9], f[10], f[11]), Vec4(f[12], f[13], f[14], f[15]))
    }

    /// A camera's view: from `eye`, looking at `target`, `up` above.
    /// Right-handed; the camera looks down its own -z.
    public static func lookAt(eye: Vec3, target: Vec3, up: Vec3 = .up) -> Mat4 {
        let f = (target - eye).normalized
        var s = f.cross(up).normalized
        if s.length == 0 { s = Vec3(1, 0, 0) }
        let u = s.cross(f)
        return Mat4(Vec4(s.x, u.x, -f.x, 0), Vec4(s.y, u.y, -f.y, 0), Vec4(s.z, u.z, -f.z, 0),
                    Vec4(-s.dot(eye), -u.dot(eye), f.dot(eye), 1))
    }

    /// A perspective projection to Metal's clip space, depth 0 at `near`
    /// and 1 at `far`. `fovY` is the vertical field of view in radians.
    public static func perspective(fovY: Float, aspect: Float, near: Float, far: Float) -> Mat4 {
        let y = 1 / Float(tan(Double(fovY) / 2))
        let x = y / aspect
        let z = far / (near - far)
        return Mat4(Vec4(x, 0, 0, 0), Vec4(0, y, 0, 0), Vec4(0, 0, z, -1), Vec4(0, 0, z * near, 0))
    }

    /// An orthographic projection to Metal's clip space, for the moon's shadows.
    public static func orthographic(left: Float, right: Float, bottom: Float, top: Float, near: Float, far: Float) -> Mat4 {
        Mat4(Vec4(2 / (right - left), 0, 0, 0), Vec4(0, 2 / (top - bottom), 0, 0), Vec4(0, 0, 1 / (near - far), 0),
             Vec4((left + right) / (left - right), (top + bottom) / (bottom - top), near / (near - far), 1))
    }
}
