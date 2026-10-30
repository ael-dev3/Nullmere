import Foundation
import NullmereCore

/// What a model shows.
public enum ModelKey: Hashable, Sendable, CustomStringConvertible {
    /// One of a company: a soldier, a scout, a settler. A company is drawn
    /// as several, fewer as it is worn down.
    case figure(UnitKind, tier: Int)
    /// A hold's keep; a seat's stands taller and flies the House's banner.
    case keep(seat: Bool)
    /// A hold's walls at their level.
    case walls(level: Int)
    /// A work at its level.
    case work(BuildingKind, level: Int)
    /// The scaffolding round a work while it rises.
    case scaffold
    /// The land's own furniture.
    case furnishing(Furnishing)
    /// What moves through the world: arrows, birds, banners, carts.
    case prop(Prop)

    public var description: String {
        switch self {
        case .figure(let kind, let tier): return "\(kind.rawValue) \(tier)"
        case .keep(let seat): return seat ? "seat keep" : "keep"
        case .walls(let level): return "walls \(level)"
        case .work(let kind, let level): return "\(kind.rawValue) \(level)"
        case .scaffold: return "scaffold"
        case .furnishing(let furnishing): return furnishing.rawValue
        case .prop(let prop): return prop.rawValue
        }
    }
}

/// The land's furniture, scattered by its terrain and features.
public enum Furnishing: String, CaseIterable, Sendable {
    /// Blackwood's dark firs.
    case fir
    /// An elder grove's vast old tree.
    case elderTree
    /// A dead, pale tree on the strand or the flats.
    case deadTree
    /// The Spine's broken rock.
    case crag
    case boulder
    /// Reeds in the shallows and along the strand.
    case reeds
    /// Moonsalt crystals on the flats; a moonsalt bed's are taller.
    case saltCrystals
    /// A grassed burial mound.
    case barrowMound
    case standingStone
    /// A half-sunken ruin.
    case ruin
    /// Tufts of grey grass on the greyfields.
    case grass
    case driftwood
    /// Furrows of dark loam.
    case furrows
    /// A stone seam's cut face.
    case stoneFace
}

/// What moves through the world, apart from companies.
public enum Prop: String, CaseIterable, Sendable {
    case arrow
    case banner
    /// A night bird circling.
    case bird
    case cart
    case brazier
    /// A puff of chimney smoke or dust, drawn many times.
    case puff
}

/// One model placed in the world.
public struct Piece: Equatable, Sendable {
    public var key: ModelKey
    public var transform: Mat4
    /// The hex it stands in, for what the keeper knows of it.
    public var hex: Hex

    public init(key: ModelKey, transform: Mat4, hex: Hex) {
        self.key = key
        self.transform = transform
        self.hex = hex
    }
}

/// A model's mesh and rig as JSON, for previews in a browser
/// (Tools/model-preview).
public enum PreviewExport {
    public static func json(_ models: [(name: String, model: Model)], clip: Clip = .idle, time: Float = 0) throws -> Data {
        func round(_ value: Float) -> Float { (value * 10_000).rounded() / 10_000 }
        let entries: [[String: Any]] = models.map { name, model in
            let mesh = model.mesh
            let bounds = mesh.bounds
            return [
                "name": name,
                "positions": mesh.vertices.flatMap { [round($0.position.x), round($0.position.y), round($0.position.z)] },
                "normals": mesh.vertices.flatMap { [round($0.normal.x), round($0.normal.y), round($0.normal.z)] },
                "colors": mesh.vertices.flatMap { [round($0.color.x), round($0.color.y), round($0.color.z)] },
                "materials": mesh.vertices.map { Int($0.material.rawValue) },
                "parts": mesh.vertices.map { Int($0.part) },
                "indices": mesh.indices.map { Int($0) },
                "bounds": [[bounds.min.x, bounds.min.y, bounds.min.z], [bounds.max.x, bounds.max.y, bounds.max.z]],
                "pose": model.pose(clip, at: time).map { m in
                    [m.c0.x, m.c0.y, m.c0.z, m.c0.w, m.c1.x, m.c1.y, m.c1.z, m.c1.w,
                     m.c2.x, m.c2.y, m.c2.z, m.c2.w, m.c3.x, m.c3.y, m.c3.z, m.c3.w]
                },
            ]
        }
        return try JSONSerialization.data(withJSONObject: ["models": entries])
    }
}
