import Foundation

/// How far a walker goes on the march: how tall they are and how far each
/// leg swings, which make the pace their walk, keyed in Blender, holds the
/// ground at.
struct Gait: Sendable {
    /// The walker's height in world units.
    var size: Float = 0.3
    /// How far each leg swings on the march, in radians.
    var stride: Float = 0.45
    /// How long the legs are, a share of the height.
    var leg: Float = 0.46

    /// The ground covered each second on the march, for the feet not to slide.
    var marchSpeed: Float {
        2 * 2 * leg * Float(sin(Double(stride))) * size / Clip.march.period
    }
}

/// The parts a handcart adds to the one pulling or pushing it: the cart
/// itself, which is their extra part, and its wheels after the body's.
enum Cart {
    static let body = Limb.extra
    static let wheelL: UInt16 = 17
    static let wheelR: UInt16 = 18
}
