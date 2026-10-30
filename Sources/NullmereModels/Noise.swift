import Foundation

/// Smooth, repeatable chance over the plane: the same place always gives
/// the same value, on every Mac, so every keeper sees the same hills.
public enum Noise {
    /// A well-stirred 32 bits from two integers and a seed.
    public static func hash(_ x: Int32, _ y: Int32, _ seed: UInt32 = 0) -> UInt32 {
        var h = UInt32(bitPattern: x) &* 0x8DA6_B343 ^ UInt32(bitPattern: y) &* 0xD816_3841 ^ seed &* 0xCB1A_B31F
        h ^= h >> 13
        h = h &* 0x5BD1_E995
        h ^= h >> 15
        return h
    }

    /// A value from 0 up to 1 for a lattice point.
    public static func unit(_ x: Int32, _ y: Int32, _ seed: UInt32 = 0) -> Float {
        Float(hash(x, y, seed) >> 8) / Float(1 << 24)
    }

    /// Smooth value noise, from 0 up to 1, varying over about a unit.
    public static func value(_ x: Float, _ y: Float, seed: UInt32 = 0) -> Float {
        let fx = x.rounded(.down), fy = y.rounded(.down)
        let ix = Int32(clamping: Int(fx)), iy = Int32(clamping: Int(fy))
        let tx = x - fx, ty = y - fy
        let sx = tx * tx * (3 - 2 * tx), sy = ty * ty * (3 - 2 * ty)
        let a = unit(ix, iy, seed), b = unit(ix &+ 1, iy, seed)
        let c = unit(ix, iy &+ 1, seed), d = unit(ix &+ 1, iy &+ 1, seed)
        return (a + (b - a) * sx) + ((c + (d - c) * sx) - (a + (b - a) * sx)) * sy
    }

    /// Layered value noise, from 0 up to about 1: broad shapes with finer
    /// ones laid over them.
    public static func fractal(_ x: Float, _ y: Float, octaves: Int = 4, seed: UInt32 = 0) -> Float {
        var total: Float = 0, amplitude: Float = 0.5, frequency: Float = 1, norm: Float = 0
        for octave in 0..<octaves {
            total += amplitude * value(x * frequency, y * frequency, seed: seed &+ UInt32(octave) &* 101)
            norm += amplitude
            amplitude *= 0.5
            frequency *= 2.03
        }
        return total / norm
    }

    /// Sharp crests, from 0 up to 1: mountains' ridges.
    public static func ridged(_ x: Float, _ y: Float, octaves: Int = 4, seed: UInt32 = 0) -> Float {
        var total: Float = 0, amplitude: Float = 0.5, frequency: Float = 1, norm: Float = 0, weight: Float = 1
        for octave in 0..<octaves {
            var n = 1 - abs(value(x * frequency, y * frequency, seed: seed &+ UInt32(octave) &* 131) * 2 - 1)
            n *= n * weight
            weight = min(max(n * 1.6, 0), 1)
            total += amplitude * n
            norm += amplitude
            amplitude *= 0.5
            frequency *= 2.11
        }
        return total / norm
    }
}
