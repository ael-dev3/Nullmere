import Foundation

/// The moon's face as the lake's shader draws it, worked out on the CPU for
/// the lake without Metal: the same hash, noise and octaves, turn for turn,
/// so its seas, its grain and its one bright crater lie where the shader
/// lays them, and its limb is as much darker than its heart.
enum MoonFace {
    /// How bright the face is at a point of the disc, `x` and `y` from -1 to
    /// 1 with y upward, as a share of the moon's own colour: limb, seas and
    /// grain together.
    static func shade(_ x: Float, _ y: Float) -> Float {
        let limb = max(0, 1 - (x * x + y * y)).squareRoot()
        let maria = smoothstep(0.40, 0.70, fbm(x * 1.6 + 5.2, y * 1.6 + 1.3))
        let grain = fbm(x * 6.0 + 1.7, y * 6.0 + 8.1)
        return (0.80 + 0.20 * limb) * (1 - 0.15 * maria) * (0.93 + 0.12 * grain)
    }

    /// The bright crater's light at a point, added to every channel.
    static func crater(_ x: Float, _ y: Float) -> Float {
        let dx = x + 0.18, dy = y + 0.62
        return 0.06 * exp(-(dx * dx + dy * dy) * 160)
    }

    /// The shader's nm_hash12.
    static func hash(_ x: Float, _ y: Float) -> Float {
        var a = fract(x * 0.1137 + 0.4142)
        var b = fract(y * 0.1459 + 0.7320)
        a = fract(a * 51.73 + b * b * 29.17)
        b = fract(b * 43.39 + a * a * 37.61)
        return fract(a * 19.07 + b * 61.13 + a * b * 7.31)
    }

    /// The shader's nm_noise: the hash at the four corners, smoothly mixed.
    static func noise(_ x: Float, _ y: Float) -> Float {
        let ix = x.rounded(.down), iy = y.rounded(.down)
        let fx = x - ix, fy = y - iy
        let ux = fx * fx * (3 - 2 * fx), uy = fy * fy * (3 - 2 * fy)
        let a = hash(ix, iy), b = hash(ix + 1, iy), c = hash(ix, iy + 1), d = hash(ix + 1, iy + 1)
        let low = a + (b - a) * ux, high = c + (d - c) * ux
        return low + (high - low) * uy
    }

    /// The shader's nm_fbm: four octaves.
    static func fbm(_ x: Float, _ y: Float) -> Float {
        var value: Float = 0, amplitude: Float = 0.5
        var x = x, y = y
        for _ in 0..<4 {
            value += amplitude * noise(x, y)
            x = x * 2.03 + 17.1
            y = y * 2.03 + 9.3
            amplitude *= 0.5
        }
        return value
    }

    private static func fract(_ value: Float) -> Float {
        value - value.rounded(.down)
    }

    private static func smoothstep(_ edge0: Float, _ edge1: Float, _ x: Float) -> Float {
        let t = min(max((x - edge0) / (edge1 - edge0), 0), 1)
        return t * t * (3 - 2 * t)
    }
}
