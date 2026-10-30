import Foundation
import NullmereCore
import NullmereModels

/// The weather over the lake: what the realm's omen brings, seen in the
/// world. A lean watch comes with cold rain; Rising Mist lies in banks on
/// every shore; a still night is clearer than most; a moonsalt bloom
/// brightens the moon. Otherwise the night is as ever.
public enum Weather: String, CaseIterable, Sendable {
    case clear, rain, mist, still, bloom

    /// The weather an omen brings.
    public static func of(_ omen: OmenKind?) -> Weather {
        switch omen {
        case .leanWatch?: return .rain
        case .risingMist?: return .mist
        case .stillNight?: return .still
        case .moonsaltBloom?: return .bloom
        case nil: return .clear
        }
    }

    /// How much thicker the haze lies.
    public var hazeFactor: Float {
        switch self {
        case .mist: return 2.6
        case .rain: return 1.6
        case .still: return 0.85
        case .clear, .bloom: return 1
        }
    }

    /// How much of the moon's light comes through.
    public var moonFactor: Float {
        switch self {
        case .rain: return 0.55
        case .mist: return 0.75
        case .still: return 1.08
        case .bloom: return 1.06
        case .clear: return 1
        }
    }

    /// Rain falls this many drops about the middle of the view.
    public static let drops = 360
    /// Mist drifts in this many banks.
    public static let banks = 36
    /// Seconds a drop takes to fall from the top of the rain to the ground.
    public static let fall: Float = 0.9
    /// How high above the water the rain begins.
    public static let rainTop: Float = 2.4

    /// The weather's motes about a point at a moment, within `extent` world
    /// units of it each way: rain falling in streaks of drops, mist drifting
    /// in banks low over the land. Stateless: the same moment, the same motes.
    public func motes(around focus: Vec3, extent: Float, time: Float) -> [Mote] {
        switch self {
        case .rain:
            return (0..<Weather.drops).flatMap { index -> [Mote] in
                let seed = Float(index)
                let phase = Weather.hash(seed, 1.3)
                let cycle = floor(time / Weather.fall + phase)
                let progress = time / Weather.fall + phase - cycle
                let x = focus.x + (Weather.hash(seed, cycle + 7.1) * 2 - 1) * extent
                let z = focus.z + (Weather.hash(seed, cycle + 3.7) * 2 - 1) * extent
                let y = Relief.waterline + Weather.rainTop * (1 - progress)
                // A drop and its streak behind it, the streak fainter.
                let light = Vec3(0.012, 0.014, 0.02)
                return [Mote(at: Vec3(x, y, z), size: 0.012, light: light, cover: 0.05),
                        Mote(at: Vec3(x, y + 0.05, z), size: 0.009, light: light * 0.6, cover: 0.03)]
            }
        case .mist:
            return (0..<Weather.banks).map { index in
                let seed = Float(index)
                let span = 2 * extent
                // Each bank drifts slowly east, wrapping round the view.
                let drift = (Weather.hash(seed, 2.9) * span + time * (0.05 + 0.05 * Weather.hash(seed, 5.3)))
                    .truncatingRemainder(dividingBy: span)
                let x = focus.x - extent + drift
                let z = focus.z + (Weather.hash(seed, 8.2) * 2 - 1) * extent
                let y = Relief.waterline + 0.08 + 0.2 * Weather.hash(seed, 4.4)
                let size = 0.7 + 0.8 * Weather.hash(seed, 6.6)
                return Mote(at: Vec3(x, y, z), size: size, light: Vec3(0.0045, 0.005, 0.0065), cover: 0.22)
            }
        case .clear, .still, .bloom:
            return []
        }
    }

    /// A number from 0 to 1 for two others, the same for the same.
    static func hash(_ a: Float, _ b: Float) -> Float {
        let value = sin(a * 12.9898 + b * 78.233) * 43758.5453
        return value - floor(value)
    }
}

extension FrameUniforms {
    /// The frame under the weather: the haze thicker or thinner, the moon dimmer or brighter.
    public mutating func weather(_ weather: Weather) {
        haze.y *= weather.hazeFactor
        moon.w *= weather.moonFactor
    }
}
