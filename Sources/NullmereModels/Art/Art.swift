import Foundation

/// The models made in Blender (each by its script in Art/blender), written
/// into the package by Art/embed.py, and read by Asset as the world asks for
/// them.
enum Art {
    /// The bones of every figure on foot after its root, in the order the
    /// rig keeps them (Limb), so a figure made in Blender is moved, put
    /// away and drawn as the figures built in code are.
    static let limbs = ["hips", "torso", "head", "armL", "forearmL", "armR", "forearmR", "thighL", "shinL", "thighR", "shinR",
                        "heldR", "heldL", "cloak", "tool", "extra"]
    /// Figures are made 1.8 tall and drawn as tall as those built in code.
    static let figureScale: Float = 0.3 / 1.8
    /// Archers are drawn a twentieth taller: lean and tall, as their kind is.
    static let archerScale: Float = 0.315 / 1.8

    /// A company's figure made in Blender, at its tier, or as a heritage's
    /// own company (its variant) in place of a tier; `more`, the bones of
    /// its own kind it keeps next after the limbs (the archer's string).
    static func figure(_ base64: String, tier: Int, variant: String? = nil, name: String, more: [String] = [],
                       scale: Float = figureScale) -> Model {
        do {
            return try Asset.model(name: name, glb: try Asset.bytes(base64: base64), scale: scale, order: limbs + more, tier: tier,
                                   variant: variant)
        } catch {
            // Written into the package and read by its tests: never a keeper's to meet.
            preconditionFailure("\(name), made in Blender, can't be read: \(error)")
        }
    }
}
