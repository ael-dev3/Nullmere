import Foundation
import NullmereCore

/// What a model shows.
public enum ModelKey: Hashable, Sendable, CustomStringConvertible {
    /// One of a company: a soldier, a scout, a settler. A company is drawn
    /// as several, fewer as it is worn down (see `Formation`).
    case figure(UnitKind, tier: Int)
    /// One of a House's own company: its heritage's kind at the fifth
    /// tier, in that people's own gear.
    case signature(Heritage)
    /// A hold's keep; a seat's stands taller and flies the House's banner.
    case keep(seat: Bool)
    /// A hold's keep as its House's people build one: their walls, roof
    /// and crown (see `KeepStyle`).
    case keepOf(Heritage, seat: Bool)
    /// A hold's walls at their level.
    case walls(level: Int)
    /// A work at its level. A hold's walls are `walls(level:)`.
    case work(BuildingKind, level: Int)
    /// The scaffolding round a work while it rises: a frame one unit wide,
    /// deep and high, stretched to the work it stands round.
    case scaffold
    /// The land's own furniture.
    case furnishing(Furnishing)
    /// What moves through the world: arrows, birds, banners, carts.
    case prop(Prop)
    /// Where a company gathers a resource: a grain field, a timber stand, a
    /// stone outcrop, a moonsalt pan. It fills a hex's heart.
    case site(Resource)
    /// A hostile company of the far country, from the least, 1, to the
    /// worst, 3. They answer to no House.
    case wild(tier: Int)
    /// One of six heroes, 0 to 5, who ride at a company's head.
    case commander(variant: Int)
    /// Where a House's scholars study the lake's lore, levels 1 to 5: a
    /// scriptorium that grows into an observatory.
    case study(level: Int)
    /// A holy site of the lake: a ring of standing stones about its heart,
    /// a pennant in its holder's colour.
    case shrine(ShrineKind)
    /// A lair of the wilds, one for each kind of them.
    case lair(WildKind)
    /// An alliance's standard, its banner in the alliance's colour.
    case standard
    /// An alliance's hall, its roof, cone and banners in the alliance's
    /// colour.
    case allianceHall

    public var description: String {
        switch self {
        case .figure(let kind, let tier): return "\(kind.rawValue) \(tier)"
        case .signature(let heritage): return "\(heritage.rawValue) own"
        case .keep(let seat): return seat ? "seat keep" : "keep"
        case .keepOf(let heritage, let seat): return "\(heritage.rawValue) \(seat ? "seat keep" : "keep")"
        case .walls(let level): return "walls \(level)"
        case .work(let kind, let level): return "\(kind.rawValue) \(level)"
        case .scaffold: return "scaffold"
        case .furnishing(let furnishing): return furnishing.rawValue
        case .prop(let prop): return prop.rawValue
        case .site(let resource): return "\(resource.rawValue) site"
        case .wild(let tier): return "wild \(tier)"
        case .commander(let variant): return "commander \(variant)"
        case .study(let level): return "study \(level)"
        case .shrine(let kind): return "\(kind.rawValue) shrine"
        case .lair(let kind): return "\(kind.rawValue) lair"
        case .standard: return "standard"
        case .allianceHall: return "alliance hall"
        }
    }

    /// The tiers a kind of company is drawn in: Spears, Bows and Riders
    /// from 1 to 5; Lanterns and Founders have one look.
    public static func tiers(of kind: UnitKind) -> Int {
        switch kind {
        case .spear, .bow, .rider: return 5
        case .lantern, .founder: return 1
        }
    }

    /// The model a company is drawn as: its House's own company, at its
    /// heritage's kind and the highest tier, in that people's gear; else its
    /// kind's at its tier.
    public static func company(_ kind: UnitKind, tier: Int, heritage: Heritage) -> ModelKey {
        kind == heritage.signature && tier >= tiers(of: kind) ? .signature(heritage) : .figure(kind, tier: tier)
    }

    public static let wildTiers = 3
    public static let commanderVariants = 6
    public static let wallLevels = 5
    public static let studyLevels = 5

    /// The key whose model is drawn: tiers and levels held to those there
    /// are, a commander's variant taken round the six, a work's walls as
    /// the walls.
    public var canonical: ModelKey {
        func clamp(_ value: Int, _ top: Int) -> Int { min(max(value, 1), top) }
        switch self {
        case .figure(let kind, let tier): return .figure(kind, tier: clamp(tier, ModelKey.tiers(of: kind)))
        case .walls(let level), .work(.walls, let level): return .walls(level: clamp(level, ModelKey.wallLevels))
        // The Archive is where a House's scholars study: its models are the study's.
        case .work(.archive, let level): return .study(level: clamp(level, ModelKey.studyLevels))
        case .work(let kind, let level): return .work(kind, level: clamp(level, kind.maxLevel))
        case .wild(let tier): return .wild(tier: clamp(tier, ModelKey.wildTiers))
        case .commander(let variant):
            let count = ModelKey.commanderVariants
            return .commander(variant: (variant % count + count) % count)
        case .study(let level): return .study(level: clamp(level, ModelKey.studyLevels))
        case .keep, .keepOf, .scaffold, .furnishing, .prop, .site, .shrine, .lair, .standard, .allianceHall, .signature: return self
        }
    }

    /// How fast its model goes on the march, in units a second, for its
    /// feet or hooves to hold the ground as the renderer moves it; nil for
    /// what does not march.
    public var marchSpeed: Float? { Figures.marchSpeed(self) }

    /// The most triangles its model may have: figures are drawn many
    /// times, keeps once a hold.
    public var budget: Int {
        switch self {
        case .figure, .signature, .wild, .commander: return 700
        case .furnishing, .prop: return 300
        case .keep, .keepOf, .allianceHall: return 4500
        case .walls, .work, .scaffold, .site, .study, .shrine, .lair, .standard: return 3000
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
    /// An arrow in flight, pointing along +z.
    case arrow
    /// A House's banner on its pole; it stirs at idle.
    case banner
    /// A night bird circling; its wings beat at idle.
    case bird
    /// A carter's two-wheeled cart; its wheels turn on the march.
    case cart
    case brazier
    /// A puff of chimney smoke or dust, drawn many times; at idle it rises
    /// and spreads once a period, for the renderer to fade.
    case puff
}

/// One model placed in the world.
public struct Piece: Equatable, Sendable {
    public var key: ModelKey
    /// From the model's frame to the world's. A scaffold's stretches it to
    /// its work, wider than it is high or higher than it is wide.
    public var transform: Mat4
    /// The hex it stands in, for what the keeper knows of it.
    public var hex: Hex
    /// How much of a work stands, 0 to 1: a work being raised is drawn up
    /// to this fraction of its height (from its lowest point to its
    /// highest, in its own frame), the rest not yet built. 1 when whole.
    public var progress: Float

    public init(key: ModelKey, transform: Mat4, hex: Hex, progress: Float = 1) {
        self.key = key
        self.transform = transform
        self.hex = hex
        self.progress = progress
    }

    /// Where it stands in the world.
    public var position: Vec3 { Vec3(transform.c3.x, transform.c3.y, transform.c3.z) }
}

/// Every model, built from solids the first time it is asked for and kept.
///
/// To draw one: each vertex moves with its part's matrix from
/// `Model.pose(clip, at:)` (one per part of its rig, at most 24; parts a
/// clip puts away, such as a gathering tool at other times, are shrunk to
/// nearly nothing), then with its piece's transform. Clips loop with
/// `Clip.period`, so figures are phased by adding a fraction of it to the
/// time; the death plays once. A piece's `progress` below 1 is a work
/// rising: draw it up to `Piece.risen` in its own frame. The House's
/// banners, pennants, cloaks and caparisons are `Material.cloth`, its
/// shields, tabards, roofs and plumes `Material.house`: a grey for the
/// House's colour to tint, light or dark. Whatever has `sway` moves in the
/// wind, from a fir's crown to a cloak's hem; the far country's shrouds
/// sway too, but are no House's and plain.
public enum Library {
    /// The model for a key, as its canonical key builds it. Safe to ask
    /// from any thread; each is built once.
    public static func model(_ key: ModelKey) -> Model {
        store.model(for: key.canonical)
    }

    /// Every key with a model of its own, each once: figures, wilds and
    /// commanders, keeps, walls and works, the scaffold, the land's
    /// furnishings, the gathering sites and the props.
    public static let catalogue: [ModelKey] = {
        var keys: [ModelKey] = []
        for kind in UnitKind.allCases {
            keys += (1...ModelKey.tiers(of: kind)).map { .figure(kind, tier: $0) }
        }
        keys += (1...ModelKey.wildTiers).map { .wild(tier: $0) }
        keys += (0..<ModelKey.commanderVariants).map { .commander(variant: $0) }
        keys += [.keep(seat: false), .keep(seat: true)]
        keys += Heritage.allCases.flatMap { [ModelKey.keepOf($0, seat: false), .keepOf($0, seat: true)] }
        keys += (1...ModelKey.wallLevels).map { .walls(level: $0) }
        for kind in BuildingKind.allCases where kind != .walls && kind != .archive {
            keys += (1...kind.maxLevel).map { .work(kind, level: $0) }
        }
        keys += (1...ModelKey.studyLevels).map { .study(level: $0) }
        keys.append(.scaffold)
        keys += Furnishing.allCases.map { .furnishing($0) }
        keys += Resource.allCases.map { .site($0) }
        keys += Prop.allCases.map { .prop($0) }
        keys += ShrineKind.allCases.map { .shrine($0) }
        keys += WildKind.allCases.map { .lair($0) }
        keys.append(.standard)
        keys.append(.allianceHall)
        keys += Heritage.allCases.map { .signature($0) }
        return keys
    }()

    /// Builds a model afresh, without keeping it.
    static func build(_ key: ModelKey) -> Model {
        let mesh: Mesh
        switch key.canonical {
        case .figure(let kind, let tier): return Figures.build(kind, tier: tier, name: key.canonical.description)
        case .signature(let heritage): return Figures.signature(heritage, name: key.canonical.description)
        case .wild(let tier): return Figures.wild(tier: tier, name: key.canonical.description)
        case .commander(let variant): return Figures.commander(variant, name: key.canonical.description)
        case .keep(let seat): return Holds.keep(seat: seat, name: key.canonical.description)
        case .keepOf(let heritage, let seat): return Holds.keep(seat: seat, name: key.canonical.description, style: .of(heritage))
        case .walls(let level): return Holds.walls(level: level, name: key.canonical.description)
        case .work(let kind, let level): return Works.build(kind, level: level, name: key.canonical.description)
        case .study(let level): return Works.study(level: level, name: key.canonical.description)
        case .scaffold: mesh = Holds.scaffold()
        case .furnishing(let furnishing): mesh = Land.furnishing(furnishing)
        case .site(let resource): return Land.site(resource, name: key.canonical.description)
        case .prop(let prop): return Props.build(prop, name: key.canonical.description)
        case .shrine(let kind): return Land.shrine(kind, name: key.canonical.description)
        case .lair(let kind): return Lairs.build(kind, name: key.canonical.description)
        case .standard: return Land.standard(name: key.canonical.description)
        case .allianceHall: return Halls.hall(name: key.canonical.description)
        }
        return Model(name: key.canonical.description, mesh: mesh)
    }

    /// Where smoke rises from a model's chimneys, in its own frame: a keep's
    /// hall, a saltworks' furnace. The renderer sends puffs (`Prop.puff`)
    /// up from them.
    public static func smoke(of key: ModelKey) -> [Vec3] {
        switch key.canonical {
        case .keep(let seat), .keepOf(_, let seat): return [Holds.chimney(seat: seat)]
        case .work(.saltworks, let level) where level >= 2: return [Works.saltChimney(level)]
        case .lair(let kind): return Lairs.fire(of: kind).map { [$0] } ?? []
        case .work(.infirmary, let level) where level >= 2: return [Works.infirmaryChimney(level)]
        case .work(.forge, let level): return [Works.forgeChimney(level)]
        case .allianceHall: return [Halls.smoke]
        default: return []
        }
    }

    private static let store = ModelStore()
}

public extension Piece {
    /// Where smoke rises from it, in the world.
    var smoke: [Vec3] {
        Library.smoke(of: key).map(transform.transformPoint)
    }

    /// How high a work being raised stands, in its model's own frame (as
    /// its posed vertices are, before its transform): it is drawn up to
    /// here, the rest not yet built. Nil when whole.
    var risen: Float? {
        guard progress < 1 else { return nil }
        let bounds = Library.model(key).mesh.bounds
        return bounds.min.y + max(progress, 0) * (bounds.max.y - bounds.min.y)
    }
}

/// The models built so far, behind a lock.
private final class ModelStore: @unchecked Sendable {
    private let lock = NSRecursiveLock()
    private var models: [ModelKey: Model] = [:]

    func model(for key: ModelKey) -> Model {
        lock.lock()
        defer { lock.unlock() }
        if let model = models[key] { return model }
        let model = Library.build(key)
        models[key] = model
        return model
    }
}

/// A model's mesh and rig as JSON, for previews in a browser
/// (Tools/model-preview).
public enum PreviewExport {
    public static func json(_ models: [(name: String, model: Model)], clip: Clip = .idle, time: Float = 0) throws -> Data {
        try json(models.map { (name: $0.name, model: $0.model, clip: clip, time: time) })
    }

    /// Each model posed at its own moment of its own clip.
    public static func json(_ models: [(name: String, model: Model, clip: Clip, time: Float)]) throws -> Data {
        func round(_ value: Float) -> Float { (value * 10_000).rounded() / 10_000 }
        let entries: [[String: Any]] = models.map { name, model, clip, time in
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
