import Foundation
import NullmereCore

/// The townsfolk who go about a hold's work, plain folk in linen and wool
/// with a band of their House's colour at the waist: a farmhand with a
/// pitchfork from the granary, carters hauling timber from the sawpit and
/// stone from the quarry, a salter with a basket from the saltworks, and a
/// porter with a sack on their back about the rest. And the rest of a
/// town's folk out about its lanes: a householder empty-handed, a
/// water-carrier with a pail from the well, an elder on a stick, and a
/// child. Made in Blender (Art/blender/folk.py, and carters.py for the
/// carters and their handcarts), and drawn by the dozen.
public enum Folk {
    /// The townsfolk there are: the works' folk, then the homes'.
    static let variants = 9
    public static let farmhand = 0, timberCarter = 1, stoneCarter = 2, salter = 3, porter = 4
    static let householder = 5, waterCarrier = 6, elder = 7, child = 8
    /// Each as their file names them, by their number.
    static let names = ["farmhand", "timber", "stone", "salter", "porter", "householder", "waterCarrier", "elder", "child"]

    /// A little smaller than a soldier, and an unhurried walk.
    static let size: Float = 0.27
    static let stride: Float = 0.32
    /// An elder a little bent and shorter in the stride; a child small,
    /// and quick in it.
    static let elderSize: Float = 0.26, elderStride: Float = 0.24
    static let childSize: Float = 0.19, childStride: Float = 0.45
    /// A carter's stride, longer to haul the founder's handcart at the
    /// round of its wheels: a turn of them each march period.
    static let cartStride: Float = 0.49

    static func build(_ variant: Int, name: String) -> Model {
        switch variant {
        case timberCarter, stoneCarter: return Art.carter(stone: variant == stoneCarter, name: name)
        default: return Art.folk(names[variant], name: name, height: gait(variant).size)
        }
    }

    /// How tall a townsfolk of a variant is and how far each stride goes,
    /// which make their pace: their walks are keyed to hold the ground at it.
    static func gait(_ variant: Int) -> Gait {
        switch variant {
        case timberCarter, stoneCarter: return Gait(size: size, stride: cartStride)
        case elder: return Gait(size: elderSize, stride: elderStride)
        case child: return Gait(size: childSize, stride: childStride)
        default: return Gait(size: size, stride: stride)
        }
    }
}

extension ModelKey {
    /// The townsfolk who go about a work: the farmhand the granary's, the
    /// carters the sawpit's and the quarry's, the salter the saltworks', a
    /// porter every other's.
    public static func folk(of work: BuildingKind) -> ModelKey {
        switch work {
        case .granary: return .folk(variant: Folk.farmhand)
        case .sawpit: return .folk(variant: Folk.timberCarter)
        case .quarry: return .folk(variant: Folk.stoneCarter)
        case .saltworks: return .folk(variant: Folk.salter)
        default: return .folk(variant: Folk.porter)
        }
    }

    /// One of a town's folk out about its lanes, chosen by a roll from 0 to
    /// 1: most often a householder, then a water-carrier, an elder, a child.
    public static func folk(ofHome roll: Float) -> ModelKey {
        .folk(variant: roll < 0.4 ? Folk.householder : roll < 0.65 ? Folk.waterCarrier : roll < 0.85 ? Folk.elder : Folk.child)
    }
}
