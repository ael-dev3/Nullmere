import Foundation

/// A star for the static fallback backdrop, in unit coordinates.
public struct Star: Equatable, Sendable {
    /// Horizontal position, 0 at the left edge and 1 at the right.
    public var x: Double
    /// Height above the waterline, 0 at the waterline and 1 at the top edge.
    public var altitude: Double
    /// Relative brightness, 0...1.
    public var brightness: Double
    /// Radius in points.
    public var radius: Double
}

/// Deterministic star fields, so the fallback sky is the same on every launch.
public enum StarCatalog {
    public static func stars(count: Int, seed: UInt64) -> [Star] {
        var generator = SplitMix64(seed: seed)
        return (0..<count).map { _ in
            let x = generator.nextUnit()
            let altitude = 0.04 + 0.96 * generator.nextUnit().squareRoot()
            let magnitude = pow(generator.nextUnit(), 3)
            return Star(x: x, altitude: altitude, brightness: 0.12 + 0.88 * magnitude, radius: 0.45 + 0.85 * magnitude)
        }
    }
}

/// A small, fast, seedable generator (Steele, Lea and Flood's SplitMix64).
public struct SplitMix64: RandomNumberGenerator, Sendable {
    private var state: UInt64

    public init(seed: UInt64) {
        state = seed
    }

    public mutating func next() -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return z ^ (z >> 31)
    }

    /// A uniformly distributed value in 0..<1.
    public mutating func nextUnit() -> Double {
        Double(next() >> 11) * 0x1.0p-53
    }
}
