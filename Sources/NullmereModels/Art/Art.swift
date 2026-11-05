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
    /// Lantern-bearers a thirtieth shorter: slight and wiry.
    static let lanternScale: Float = 0.29 / 1.8
    /// The bones of a horse and its rider after its root, in the order the
    /// rig every horse and rider keeps them (Steed): the horse's, then the
    /// rider's astride.
    static let steed = ["body", "neck", "horseHead", "tail", "foreLegL", "foreShinL", "foreLegR", "foreShinR", "hindLegL", "hindShinL",
                        "hindLegR", "hindShinR", "hips", "torso", "head", "armL", "forearmL", "armR", "forearmR", "heldR", "heldL", "cloak",
                        "tool"]
    /// A rider is made seated at a man's height, his horse's hooves this far
    /// below the ground (Art/blender/rider.py), and lifted till they stand on it.
    static let riderLift: Float = 0.56 * figureScale

    /// A company's figure made in Blender, at its tier, or as a heritage's
    /// own company (its variant) in place of a tier; `more`, the bones of
    /// its own kind it keeps next after the limbs (the archer's string).
    static func figure(_ base64: String, tier: Int, variant: String? = nil, name: String, more: [String] = [],
                       scale: Float = figureScale) -> Model {
        model(base64, tier: tier, variant: variant, name: name, order: limbs + more, scale: scale)
    }

    /// A rider and his horse made in Blender, at the rider's tier or as a
    /// heritage's own riders (its variant), the horse's coat, socks and mane
    /// the colours of `mount`'s.
    static func rider(tier: Int, variant: String? = nil, name: String, mount: Mount) -> Model {
        model(horseman, tier: tier, variant: variant, name: name, order: steed, lift: riderLift,
              colours: ["plain_coat": mount.coat, "plain_socks": mount.socks ?? mount.coat, "plain_mane": mount.mane])
    }

    /// A model made in Blender, its bones in `order` after its root.
    static func model(_ base64: String, tier: Int, variant: String? = nil, name: String, order: [String], scale: Float = figureScale,
                      lift: Float = 0, colours: [String: Vec3] = [:]) -> Model {
        do {
            return try Asset.model(name: name, glb: try Asset.bytes(base64: base64), scale: scale, lift: lift, order: order, tier: tier,
                                   variant: variant, colours: colours)
        } catch {
            // Written into the package and read by its tests: never a keeper's to meet.
            preconditionFailure("\(name), made in Blender, can't be read: \(error)")
        }
    }
}
