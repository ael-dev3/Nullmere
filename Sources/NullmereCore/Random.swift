/// Deterministic randomness. Every random choice in the rules flows from the
/// world seed through these functions, so a world and its history replay
/// exactly on any machine. Only integer operations are used.
public struct SeededRandom: RandomNumberGenerator, Codable, Sendable, Equatable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    /// SplitMix64 (Steele, Lea and Flood).
    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        return Seed.finalize(state)
    }

    /// A uniformly distributed integer in `0..<bound`, without modulo bias.
    public mutating func int(below bound: Int) -> Int {
        precondition(bound > 0, "bound must be positive")
        let bound = UInt64(bound)
        let threshold = (0 &- bound) % bound
        while true {
            let value = next()
            let product = value.multipliedFullWidth(by: bound)
            if product.low >= threshold {
                return Int(product.high)
            }
        }
    }

    public mutating func int(in range: ClosedRange<Int>) -> Int {
        range.lowerBound + int(below: range.count)
    }

    /// True with the given chance, in percent.
    public mutating func chance(_ percent: Int) -> Bool {
        int(below: 100) < percent
    }

    /// A value in 0..<1 with 53 bits of precision.
    public mutating func unit() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }

    public mutating func pick<T>(_ items: [T]) -> T {
        items[int(below: items.count)]
    }

    public mutating func shuffle<T>(_ items: inout [T]) {
        guard items.count > 1 else { return }
        for index in stride(from: items.count - 1, to: 0, by: -1) {
            items.swapAt(index, int(below: index + 1))
        }
    }
}

public enum Seed {
    /// A 64-bit seed from text, with FNV-1a over its UTF-8 bytes.
    public static func from(_ text: String) -> UInt64 {
        var hash: UInt64 = 0xCBF2_9CE4_8422_2325
        for byte in text.utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x0000_0100_0000_01B3
        }
        return finalize(hash)
    }

    /// Combines values into one well-mixed seed.
    public static func mix(_ values: UInt64...) -> UInt64 {
        var hash: UInt64 = 0x243F_6A88_85A3_08D3
        for value in values {
            hash = finalize(hash ^ (value &+ 0x9E37_79B9_7F4A_7C15 &+ (hash << 6) &+ (hash >> 2)))
        }
        return hash
    }

    static func finalize(_ value: UInt64) -> UInt64 {
        var z = value
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A stable value in 0..<1 for a lattice point, for noise.
    static func lattice(_ x: Int, _ y: Int, _ seed: UInt64) -> Double {
        let hashed = mix(seed, UInt64(bitPattern: Int64(x)), UInt64(bitPattern: Int64(y)))
        return Double(hashed >> 11) * 0x1.0p-53
    }
}

/// Smooth value noise built from `Seed.lattice`, using only arithmetic, so it
/// gives identical results everywhere.
public struct ValueNoise: Sendable {
    public let seed: UInt64

    public init(seed: UInt64) {
        self.seed = seed
    }

    /// Noise in 0...1 at a point.
    public func value(_ x: Double, _ y: Double) -> Double {
        let x0 = x.rounded(.down)
        let y0 = y.rounded(.down)
        let fx = x - x0
        let fy = y - y0
        let ix = Int(x0)
        let iy = Int(y0)
        let ux = fx * fx * (3 - 2 * fx)
        let uy = fy * fy * (3 - 2 * fy)
        let a = Seed.lattice(ix, iy, seed)
        let b = Seed.lattice(ix + 1, iy, seed)
        let c = Seed.lattice(ix, iy + 1, seed)
        let d = Seed.lattice(ix + 1, iy + 1, seed)
        let top = a + (b - a) * ux
        let bottom = c + (d - c) * ux
        return top + (bottom - top) * uy
    }

    /// Several octaves of noise, normalised to 0...1.
    public func fractal(_ x: Double, _ y: Double, octaves: Int = 4) -> Double {
        var total = 0.0
        var amplitude = 1.0
        var frequency = 1.0
        var weight = 0.0
        for octave in 0..<octaves {
            let shifted = ValueNoise(seed: Seed.mix(seed, UInt64(octave)))
            total += amplitude * shifted.value(x * frequency, y * frequency)
            weight += amplitude
            amplitude *= 0.5
            frequency *= 2
        }
        return total / weight
    }
}
