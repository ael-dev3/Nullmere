/// The lake's far shore as its shader draws it, for anything that must draw
/// the same shore without Metal: Nullmere's own hash, value noise built on
/// it, and the mesas and the low bank built from that, in the shader's own
/// scene units (x runs from 0 at the left to the view's aspect at the right;
/// heights are shares of the view's height). Worked in single precision,
/// as the GPU works it.
public enum LakeShore {
    /// The tallest the mesas stand: their body at its highest, and the
    /// most their wear adds.
    public static let tallest: Double = 0.0612

    /// Heights of the far mesas above the horizon at scene `x`, as
    /// `nm_mesas` draws them.
    public static func mesas(_ x: Double) -> Double {
        let x = Float(x)
        let n = fbm(x * 2.2 + 4.0, 11.0)
        let tops = smoothstep(0.50, 0.56, n) * 0.55 + smoothstep(0.60, 0.65, n) * 0.45
        let body = 0.016 + 0.044 * tops
        let wear = 0.0012 * noise(x * 55.0, 1.0)
        let mask = smoothstep(0.15, 0.55, noise(x * 0.9 + 19.0, 4.5))
        return Double((body + wear) * mask)
    }

    /// The low, nearer bank's height at scene `x`, as `nm_bank` draws it.
    public static func bank(_ x: Double) -> Double {
        let x = Float(x)
        let n = fbm(x * 3.1 + 18.75, 8.6)
        return Double(0.0018 + 0.006 * smoothstep(0.35, 0.75, n) + 0.0007 * noise(x * 70.0, 5.0))
    }

    /// `nm_hash12`: a point folded once along each axis, each fold stirred
    /// by the square of the other, and the two drawn together.
    static func hash(_ x: Float, _ y: Float) -> Float {
        var a = fract(x * 0.1137 + 0.4142)
        var b = fract(y * 0.1459 + 0.7320)
        a = fract(a * 51.73 + b * b * 29.17)
        b = fract(b * 43.39 + a * a * 37.61)
        return fract(a * 19.07 + b * 61.13 + a * b * 7.31)
    }

    /// `nm_noise`: value noise, smoothly interpolated between whole points.
    static func noise(_ x: Float, _ y: Float) -> Float {
        let ix = x.rounded(.down), iy = y.rounded(.down)
        let fx = x - ix, fy = y - iy
        let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
        let a = hash(ix, iy), b = hash(ix + 1, iy), c = hash(ix, iy + 1), d = hash(ix + 1, iy + 1)
        return (a + (b - a) * ux) * (1 - uy) + (c + (d - c) * ux) * uy
    }

    /// `nm_fbm`: four octaves of it.
    static func fbm(_ x: Float, _ y: Float) -> Float {
        var value: Float = 0, amplitude: Float = 0.5, x = x, y = y
        for _ in 0..<4 {
            value += amplitude * noise(x, y)
            x = x * 2.03 + 17.1
            y = y * 2.03 + 9.3
            amplitude *= 0.5
        }
        return value
    }

    static func fract(_ value: Float) -> Float {
        value - value.rounded(.down)
    }

    static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
