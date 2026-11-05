import Foundation
import NullmereCore
import NullmereModels

/// A company as a frame draws it: where it stands on the land, which way it
/// faces, what it is doing and how far into it, and how plainly it shows.
public struct CompanyPose: Equatable, Sendable {
    public var unit: Int
    public var key: ModelKey
    public var sigil: Int
    public var health: Int
    public var hex: Hex
    /// Where the company's heart stands, on the land.
    public var position: Vec3
    /// Which way it faces: zero is south, toward the eye; a quarter turn, east.
    public var heading: Float
    public var clip: Clip
    /// Seconds into the clip.
    public var clipTime: Float
    public var opacity: Float
    /// 1 chosen, 0.5 under the pointer.
    public var emphasis: Float
    /// The keeper's own: drawn whatever the keeper knows of its hex.
    public var isOwn: Bool
    /// The commander riding at its head, if one does.
    public var commander: Int?
    /// How much of its formation it shows: 1 in the open, less drawn up
    /// small within a hold's walls.
    public var spread: Float
    /// Its muster in percent of its first: a company drilled beyond it
    /// shows more figures.
    public var muster: Int
    /// The clip it is leaving, as it eases into this one, if it is.
    public var blend: Blend?
    /// Its commander's leading talent tree (0 steel, 1 ward, 2 road) and
    /// the ranks it holds in all; -1 and 0 when it has learned none.
    public var talentTree: Int = -1
    public var talentRanks: Int = 0
    /// Its commander's stars; one, the first, is not drawn.
    public var stars: Int = 1
    /// The figures it shows standing in a field of battle, its troops'
    /// throng (see `Formation.throng`); 0 out of battle.
    public var throng: Int = 0

    /// A clip being left: where it was, and how much of it still shows.
    public struct Blend: Equatable, Sendable {
        public var clip: Clip
        public var time: Float
        /// 1 just left, falling to 0 as the new clip takes over.
        public var weight: Float

        public init(clip: Clip, time: Float, weight: Float) {
            self.clip = clip
            self.time = time
            self.weight = weight
        }
    }

    public init(unit: Int, key: ModelKey, sigil: Int, health: Int, hex: Hex, position: Vec3, heading: Float, clip: Clip = .idle,
                clipTime: Float = 0, opacity: Float = 1, emphasis: Float = 0, isOwn: Bool, commander: Int? = nil, spread: Float = 1,
                muster: Int = 100, blend: Blend? = nil) {
        self.unit = unit
        self.key = key
        self.sigil = sigil
        self.health = health
        self.hex = hex
        self.position = position
        self.heading = heading
        self.clip = clip
        self.clipTime = clipTime
        self.opacity = opacity
        self.emphasis = emphasis
        self.isOwn = isOwn
        self.commander = commander
        self.spread = spread
        self.muster = muster
        self.blend = blend
    }

    /// Which way to face to look from one hex toward another.
    public static func heading(from a: Hex, to b: Hex) -> Float {
        let from = Relief.centre(of: a), to = Relief.centre(of: b)
        let dx = to.x - from.x, dz = to.z - from.z
        return dx == 0 && dz == 0 ? 0 : Float(atan2(Double(dx), Double(dz)))
    }
}

/// A company's march as the map plays it out: from where it stood along
/// its route, hex by hex, easing in and out.
public struct MarchPath: Equatable, Sendable {
    public var path: [Hex]
    public var duration: Double

    public init(path: [Hex], duration: Double) {
        self.path = path
        self.duration = duration
    }

    /// Where along the route it is, `elapsed` seconds in, on the map's
    /// floor, and which way it faces; nil before it sets off or once it is there.
    public func point(after elapsed: Double) -> (x: Float, z: Float, heading: Float)? {
        guard path.count > 1, elapsed >= 0, elapsed < duration else { return nil }
        let t = min(max(elapsed / max(duration, 1e-6), 0), 1)
        let along = t * t * (3 - 2 * t) * Double(path.count - 1)
        let step = min(Int(along), path.count - 2)
        let f = Float(along - Double(step))
        let a = Relief.centre(of: path[step]), b = Relief.centre(of: path[step + 1])
        return (a.x + (b.x - a.x) * f, a.z + (b.z - a.z) * f, CompanyPose.heading(from: path[step], to: path[step + 1]))
    }
}

/// An arrow loosed, or a Mangonel's stone hurled: from where, to where,
/// and how far along its flight.
public struct ArrowFlight: Equatable, Sendable {
    public var from: Vec3
    public var to: Vec3
    public var progress: Float
    /// A stone, flying higher than an arrow.
    public var stone: Bool

    public init(from: Vec3, to: Vec3, progress: Float, stone: Bool = false) {
        self.from = from
        self.to = to
        self.progress = progress
        self.stone = stone
    }

    /// Where it is and how it lies: rising from the bow in an arc, nose
    /// along its flight, and coming down on the mark; a stone's arc the
    /// higher.
    public var transform: Mat4 {
        let t = min(max(progress, 0), 1)
        let span = to - from
        let across = (span.x * span.x + span.z * span.z).squareRoot()
        let height = max(0.35, across * 0.22) * (stone ? 1.8 : 1)
        let flat = from.mix(to, t)
        let at = Vec3(flat.x, flat.y + 4 * t * (1 - t) * height, flat.z)
        let climb = (span.y + 4 * (1 - 2 * t) * height) / max(across, 0.01)
        let pitch = Float(atan(Double(climb)))
        let yaw = Float(atan2(Double(span.x), Double(span.z)))
        return .translation(at) * .rotationY(yaw) * .rotationX(-pitch)
    }
}

/// Smoke rising from a chimney, and the hex it rises in.
public struct Hearth: Equatable, Sendable {
    public var point: Vec3
    public var hex: Hex

    public init(point: Vec3, hex: Hex) {
        self.point = point
        self.hex = hex
    }
}

/// A hold as a frame draws it: its works as the rules keep them, how far
/// a work rising has risen, and its House's colour.
public struct HoldSight: Equatable, Sendable {
    public var hold: Hold
    public var colour: Vec4
    /// How far the work being raised has come, 0 to 1; nil to read it from
    /// the watches left.
    public var progress: Float?
    /// A work finished since it was last seen, rising the rest of the way.
    public var finishing: HoldLayout.Plan.Rising?
    /// The people its House comes of, whose keep it raises.
    public var heritage: Heritage?

    public init(hold: Hold, colour: Vec4, progress: Float? = nil, finishing: HoldLayout.Plan.Rising? = nil, heritage: Heritage? = nil) {
        self.hold = hold
        self.colour = colour
        self.progress = progress
        self.finishing = finishing
        self.heritage = heritage
    }
}

/// An alliance's hall as a frame draws it: where it stands, in its
/// alliance's colour, and how far it has risen.
public struct HallSight: Equatable, Sendable {
    public var hex: Hex
    public var colour: Vec4
    /// How far it has risen, 0 to 1.
    public var progress: Float

    public init(hex: Hex, colour: Vec4, progress: Float = 1) {
        self.hex = hex
        self.colour = colour
        self.progress = progress
    }
}

/// The world's models for a frame, gathered kind by kind for the GPU: the
/// land's furniture, every hold the keeper knows with its works, every
/// company in sight posed at its moment, and what flies over them all.
/// The land's furniture and each hold's pieces are laid out once and
/// again only where something changed.
public final class WorldStage: @unchecked Sendable {
    public let map: WorldMap
    public let relief: Relief
    private var furnitureByHex: [Hex: [Piece]] = [:]
    private var furnished: (occupied: Set<Hex>, holds: Set<Hex>)?
    private var furniture: [ModelBatch] = []
    /// Moves each time the furniture is laid out again.
    public private(set) var furnitureVersion = 0
    /// Where the furniture lies, region by region, so a frame draws only
    /// what its view reaches.
    public private(set) var furnitureRegions: Regions?
    /// The share of the land's growth laid out, from none (0) to all (1),
    /// as the keeper's Detail sets it: the same pieces always kept at the
    /// same share, so nothing flickers as it is laid out again. Its
    /// landmarks, the features and the streams' crossings, are always laid.
    public var furnitureShare: Float = 1 {
        didSet {
            if furnitureShare != oldValue { furnished = nil }
        }
    }

    /// Whether a piece marks something a keeper looks for on the map.
    static func isLandmark(_ key: ModelKey) -> Bool {
        if case .furnishing(let furnishing) = key { return furnishing.isLandmark }
        return false
    }
    private var laid: [Int: (hold: Hold, progress: Float?, finishing: HoldLayout.Plan.Rising?, heritage: Heritage?, pieces: [Piece])] = [:]
    /// Each hold's pieces as drawn, `HoldLayout.grandeur` times its plan,
    /// kept with the plan they were drawn from: carried out and set on the
    /// land once, not each frame.
    private var drawnPieces: [Int: (plan: [Piece], drawn: [Piece])] = [:]
    /// The folk of each hold's homes out walking, by the town they walk.
    private var strolled: [Int: (plan: HoldLayout.Plan, ways: [Errand])] = [:]
    /// The land's height where figures have stood, by the 64th of a unit:
    /// worked out once, not each frame.
    private var grounds: [SIMD2<Int32>: Float] = [:]

    /// A risen work shows whole.
    public static let whole: Float = 1000
    /// How long a work takes to rise to its new height once a watch turns.
    public static let riseSeconds: Double = 1.6

    public init(map: WorldMap, relief: Relief) {
        self.map = map
        self.relief = relief
    }

    // MARK: The land's furniture

    /// The land's furniture, with the hearts of `occupied` hexes clear and
    /// the ground round `holds` bare; only the hexes whose lot changed are
    /// laid out again.
    public func furnish(occupied: Set<Hex>, holds: Set<Hex>) -> [ModelBatch] {
        if let furnished, furnished.occupied == occupied, furnished.holds == holds { return furniture }
        var changed: Set<Hex>
        if let furnished {
            changed = furnished.occupied.symmetricDifference(occupied)
            for hold in furnished.holds.symmetricDifference(holds) {
                changed.formUnion(hold.spiral(3).filter { map[$0] != nil })
            }
        } else {
            changed = Set(map.hexes)
        }
        for hex in changed {
            furnitureByHex[hex] = Scatter.pieces(in: hex, map: map, relief: relief,
                                                 clearHeart: occupied.contains(hex) || holds.contains(hex), holds: holds)
        }
        var placed: [(ModelKey, ModelInstance)] = []
        let share = min(max(furnitureShare, 0), 1)
        for hex in map.hexes {
            for (index, piece) in (furnitureByHex[hex] ?? []).enumerated()
            where share >= 1 || WorldStage.isLandmark(piece.key)
                || Noise.unit(Int32(truncatingIfNeeded: hex.q), Int32(truncatingIfNeeded: hex.r), UInt32(41 + index)) < share {
                placed.append((piece.key, ModelInstance(model: piece.transform, phase: WorldStage.phase(of: piece.hex, salt: 3),
                                                        hex: SIMD2(Int32(piece.hex.q), Int32(piece.hex.r)))))
            }
        }
        let gathered = Regions.gather(placed, radius: map.radius)
        furniture = gathered.batches
        furnitureRegions = gathered.regions
        furnished = (occupied, holds)
        furnitureVersion += 1
        return furniture
    }

    // MARK: Sites

    /// The land's sites the keeper knows, each filling its hex's heart: a
    /// grain field, a timber stand, a stone outcrop, a moonsalt pan.
    public func sites(_ sites: [(store: Resource, hex: Hex)]) -> [ModelBatch] {
        WorldStage.batches(sites.map { site in
            let centre = Relief.centre(of: site.hex)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) - Scatter.sink, centre.z)
            let turn = WorldStage.phase(of: site.hex, salt: 7) * .pi / 10
            return (.site(site.store), ModelInstance(model: .translation(at) * .rotationY(turn), phase: WorldStage.phase(of: site.hex, salt: 11),
                                                     hex: SIMD2(Int32(site.hex.q), Int32(site.hex.r))))
        })
    }

    /// The holy sites the keeper has found, each its pennant in its
    /// holder's colour, or grey while none holds it.
    public func shrines(_ shrines: [(kind: ShrineKind, hex: Hex, colour: Vec4?)]) -> [ModelBatch] {
        WorldStage.batches(shrines.map { shrine in
            let centre = Relief.centre(of: shrine.hex)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) - Scatter.sink, centre.z)
            var instance = ModelInstance(model: .translation(at) * .rotationY(WorldStage.phase(of: shrine.hex, salt: 13) * .pi / 4),
                                         phase: WorldStage.phase(of: shrine.hex, salt: 17),
                                         hex: SIMD2(Int32(shrine.hex.q), Int32(shrine.hex.r)))
            if let colour = shrine.colour { instance.colour = colour }
            return (.shrine(shrine.kind), instance)
        })
    }

    /// The lairs of the wilds the keeper has found, each filling its hex's
    /// heart, and where their fires smoke.
    public func lairs(_ lairs: [(kind: WildKind, hex: Hex)]) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var hearths: [Hearth] = []
        let batches = WorldStage.batches(lairs.map { lair in
            let centre = Relief.centre(of: lair.hex)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) - Scatter.sink, centre.z)
            let transform = Mat4.translation(at) * .rotationY(WorldStage.phase(of: lair.hex, salt: 19) * .pi / 6)
            hearths += Library.smoke(of: .lair(lair.kind)).map { Hearth(point: transform.transformPoint($0), hex: lair.hex) }
            return (.lair(lair.kind), ModelInstance(model: transform, phase: WorldStage.phase(of: lair.hex, salt: 23),
                                                    hex: SIMD2(Int32(lair.hex.q), Int32(lair.hex.r))))
        })
        return (batches, hearths)
    }

    /// The Crown's gates the keeper has found, each held across its pass,
    /// its way through turned toward the Crown's heart, and where their
    /// fires smoke.
    public func gates(_ gates: [Hex]) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var hearths: [Hearth] = []
        let batches = WorldStage.batches(gates.map { hex in
            let centre = Relief.centre(of: hex)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) - Scatter.sink, centre.z)
            let transform = Mat4.translation(at) * .rotationY(CompanyPose.heading(from: Hex.origin, to: hex))
            hearths += Library.smoke(of: .gatehold).map { Hearth(point: transform.transformPoint($0), hex: hex) }
            return (.gatehold, ModelInstance(model: transform, phase: WorldStage.phase(of: hex, salt: 23),
                                             hex: SIMD2(Int32(hex.q), Int32(hex.r))))
        })
        return (batches, hearths)
    }

    /// The companies the lake mirrored at its Still Hour that the keeper
    /// cannot otherwise see: each drawn faint where it stood, in its House's
    /// colour, a reflection more than a company.
    public func mirrored(_ glimpses: [(kind: UnitKind, hex: Hex, colour: Vec4)]) -> [ModelBatch] {
        WorldStage.batches(glimpses.map { glimpse in
            let centre = Relief.centre(of: glimpse.hex)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z), centre.z)
            return (.figure(glimpse.kind, tier: 1),
                    ModelInstance(model: .translation(at) * .rotationY(WorldStage.phase(of: glimpse.hex, salt: 61) * .pi * 2), colour: glimpse.colour,
                                  opacity: 0.35, phase: WorldStage.phase(of: glimpse.hex, salt: 67),
                                  hex: SIMD2(Int32(glimpse.hex.q), Int32(glimpse.hex.r)), flags: ModelInstance.alwaysShown))
        })
    }

    /// A standard still rising stands within a scaffold this wide.
    public static let standardScaffold: Float = 0.3

    /// The alliances' standards the keeper knows of, each in its alliance's
    /// colour; one still rising drawn up its pole as far as it has come
    /// (`progress`, 0 to 1) within a narrow scaffold, its land not yet its
    /// alliance's.
    public func standards(_ standards: [(hex: Hex, colour: Vec4, progress: Float)]) -> [ModelBatch] {
        let bounds = Library.model(.standard).mesh.bounds
        var placed: [(ModelKey, ModelInstance)] = []
        for standard in standards {
            let centre = Relief.centre(of: standard.hex)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) - Scatter.sink, centre.z)
            let cell = SIMD2(Int32(standard.hex.q), Int32(standard.hex.r))
            let turn = Mat4.translation(at) * .rotationY(WorldStage.phase(of: standard.hex, salt: 29) * .pi / 3)
            let done = min(max(standard.progress, 0), 1)
            // Its pole set from the first, the rest drawn up as it rises.
            let rise = done < 1 ? bounds.min.y + (0.2 + 0.8 * done) * (bounds.max.y - bounds.min.y) : WorldStage.whole
            placed.append((.standard, ModelInstance(model: turn, colour: standard.colour, rise: rise,
                                                    phase: WorldStage.phase(of: standard.hex, salt: 31), hex: cell)))
            if done < 1 {
                let tall = max(bounds.max.y * min(done + 0.15, 1), 0.12)
                placed.append((.scaffold, ModelInstance(model: turn * .scale(Vec3(WorldStage.standardScaffold, tall, WorldStage.standardScaffold)),
                                                        hex: cell)))
            }
        }
        return WorldStage.batches(placed)
    }

    /// How far from its muster's heart a rally camp stands: past the walls,
    /// toward the march.
    public static let rallyCampReach: Float = 0.62

    /// The war camps of rallies gathering at holds the keeper sees, each
    /// just past its muster's walls on the side of its target, its banner
    /// in its caller's colour; and where their fires smoke.
    public func rallyCamps(_ camps: [(muster: Hex, target: Hex, colour: Vec4)]) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var hearths: [Hearth] = []
        let batches = WorldStage.batches(camps.map { camp in
            let from = Relief.centre(of: camp.muster), to = Relief.centre(of: camp.target)
            var way = Vec3(to.x - from.x, 0, to.z - from.z)
            if way.length < 0.001 { way = Vec3(0, 0, 1) }
            way = way * (1 / way.length)
            let x = from.x + way.x * WorldStage.rallyCampReach, z = from.z + way.z * WorldStage.rallyCampReach
            let at = Vec3(x, ground(atX: x, z: z) - Scatter.sink, z)
            let transform = Mat4.translation(at) * .rotationY(Float(atan2(Double(way.x), Double(way.z))))
            hearths += Library.smoke(of: .rallyCamp).map { Hearth(point: transform.transformPoint($0), hex: camp.muster) }
            return (.rallyCamp, ModelInstance(model: transform, colour: camp.colour, phase: WorldStage.phase(of: camp.muster, salt: 41),
                                              hex: SIMD2(Int32(camp.muster.q), Int32(camp.muster.r))))
        })
        return (batches, hearths)
    }

    /// The war banners of rally hosts on the march, each borne among the
    /// troops of its company nearest the target, in its caller's colour.
    public func hostBanners(_ hosts: [(lead: CompanyPose, colour: Vec4)]) -> [ModelBatch] {
        WorldStage.batches(hosts.map { host in
            let at = host.lead.position
            return (.hostBanner, ModelInstance(model: .translation(at) * .rotationY(host.lead.heading), colour: host.colour,
                                               phase: WorldStage.phase(of: host.lead.hex, salt: 43),
                                               hex: SIMD2(Int32(host.lead.hex.q), Int32(host.lead.hex.r))))
        })
    }

    /// The alliances' halls the keeper has found, each in its alliance's
    /// colour, one rising drawn up as far as it has come within its
    /// scaffold; and where the whole ones' louvres smoke.
    public func halls(_ halls: [HallSight]) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var placed: [(ModelKey, ModelInstance)] = []
        var hearths: [Hearth] = []
        for sight in halls {
            let phase = WorldStage.phase(of: sight.hex, salt: 37)
            for piece in HoldLayout.hall(at: sight.hex, progress: sight.progress, relief: relief) {
                placed.append((piece.key, ModelInstance(model: piece.transform, colour: sight.colour, rise: piece.risen ?? WorldStage.whole,
                                                        phase: phase, hex: SIMD2(Int32(piece.hex.q), Int32(piece.hex.r)))))
                if piece.progress >= 1 {
                    hearths += piece.smoke.map { Hearth(point: $0, hex: piece.hex) }
                }
            }
        }
        return (WorldStage.batches(placed), hearths)
    }

    /// The alliances' storehouses the keeper knows of, each in its
    /// alliance's colour, one rising drawn up as far as it has come within
    /// its scaffold. Their sights are a hall's: where, whose, how far risen.
    public func storehouses(_ storehouses: [HallSight], time: Float, into frame: inout SceneFrame) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        var poses: [PoseKey: UInt32] = [:]
        for sight in storehouses {
            let phase = WorldStage.phase(of: sight.hex, salt: 41)
            for piece in HoldLayout.storehouse(at: sight.hex, progress: sight.progress, relief: relief) {
                // Its hoist works while it stands whole, and rests while it rises.
                let palette = Library.model(piece.key).rig.count > 1
                    ? WorldStage.pose(piece.key, .idle, at: sight.progress >= 1 ? time + phase : 0, shared: &poses, into: &frame) : 0
                placed.append((piece.key, ModelInstance(model: piece.transform, colour: sight.colour, rise: piece.risen ?? WorldStage.whole,
                                                        phase: phase, hex: SIMD2(Int32(piece.hex.q), Int32(piece.hex.r)), palette: palette)))
            }
        }
        return WorldStage.batches(placed)
    }

    /// The alliances' yards the keeper knows, each filling its hex's heart
    /// in its alliance's colour, and where the salt works' fires smoke.
    public func yards(_ yards: [(store: Resource, hex: Hex, colour: Vec4)], time: Float,
                      into frame: inout SceneFrame) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var hearths: [Hearth] = []
        var placed: [(ModelKey, ModelInstance)] = []
        var poses: [PoseKey: UInt32] = [:]
        for yard in yards {
            let centre = Relief.centre(of: yard.hex)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) - Scatter.sink, centre.z)
            let transform = Mat4.translation(at) * .rotationY(Float.pi / 2 - HoldLayout.frontAngle(of: yard.hex))
            let key = ModelKey.yard(yard.store)
            let phase = WorldStage.phase(of: yard.hex, salt: 43)
            hearths += Library.smoke(of: key).map { Hearth(point: transform.transformPoint($0), hex: yard.hex) }
            // Its machinery works: a derrick slewing, a windlass turning, a fire leaping.
            let palette = Library.model(key).rig.count > 1 ? WorldStage.pose(key, .idle, at: time + phase, shared: &poses, into: &frame) : 0
            placed.append((key, ModelInstance(model: transform, colour: yard.colour, phase: phase,
                                              hex: SIMD2(Int32(yard.hex.q), Int32(yard.hex.r)), palette: palette)))
        }
        return (WorldStage.batches(placed), hearths)
    }

    /// Where each hall being raised stands, for the dust of its building.
    public func risingHalls(_ halls: [HallSight]) -> [Vec3] {
        halls.filter { $0.progress < 1 }.map { sight in
            let centre = Relief.centre(of: sight.hex)
            return Vec3(centre.x, ground(atX: centre.x, z: centre.z), centre.z)
        }
    }

    // MARK: Where the night's small lights wander

    /// Reed beds and tall grass near a point, the keeper's nearest: where
    /// fireflies wander at night.
    public func fireflySpots(near focus: Vec3, within reach: Int = 4, most: Int = 10) -> [Vec3] {
        let middle = HexLayout(size: 1).hex(atX: Double(focus.x), y: Double(focus.z))
        var spots: [Vec3] = []
        for hex in middle.spiral(reach) {
            for piece in furnitureByHex[hex] ?? [] {
                guard case .furnishing(let kind) = piece.key, kind == .reeds || kind == .grass else { continue }
                spots.append(piece.position)
                break
            }
            if spots.count >= most { break }
        }
        return spots
    }

    /// Where each work being raised stands, for the dust of its building.
    public func risingWorks(_ sights: [HoldSight]) -> [Vec3] {
        sights.flatMap { sight in
            pieces(of: sight.hold, progress: sight.progress, finishing: sight.finishing, heritage: sight.heritage)
                .filter { $0.progress < 1 && $0.key != .scaffold }.map(\.position)
        }
    }

    // MARK: Holds

    /// A hold's pieces, laid out again only when it, its rising or its
    /// House's people change. A work `finishing` stands at the level below
    /// it until it has risen.
    public func pieces(of hold: Hold, progress: Float?, finishing: HoldLayout.Plan.Rising? = nil, heritage: Heritage? = nil) -> [Piece] {
        if let kept = laid[hold.id], kept.hold == hold, kept.progress == progress, kept.finishing == finishing, kept.heritage == heritage {
            return kept.pieces
        }
        let plan = WorldStage.plan(of: hold, progress: progress, finishing: finishing, heritage: heritage)
        let made = HoldLayout.pieces(plan, relief: relief) + HoldLayout.town(plan, relief: relief)
        laid[hold.id] = (hold, progress, finishing, heritage, made)
        return made
    }

    /// A hold's pieces as they are drawn: its plan carried out about its
    /// middle, again only when the plan is laid out again.
    func drawn(_ sight: HoldSight) -> [Piece] {
        let plan = pieces(of: sight.hold, progress: sight.progress, finishing: sight.finishing, heritage: sight.heritage)
        if let kept = drawnPieces[sight.hold.id], kept.plan == plan { return kept.drawn }
        let middle = Relief.centre(of: sight.hold.position)
        let made = plan.map { grand($0, about: middle) }
        drawnPieces[sight.hold.id] = (plan, made)
        return made
    }

    /// How a hold is laid out: as the rules keep it, or with the work
    /// `finishing` still rising as the watch's turn eases it up.
    static func plan(of hold: Hold, progress: Float?, finishing: HoldLayout.Plan.Rising?, heritage: Heritage?) -> HoldLayout.Plan {
        var plan = HoldLayout.Plan(hold: hold, progress: progress, heritage: heritage)
        if let finishing, plan.rising == nil {
            plan.levels[finishing.work] = finishing.level > 1 ? finishing.level - 1 : nil
            plan.rising = finishing
        }
        return plan
    }

    /// A point of a hold's plan where the hold is drawn: pushed out from
    /// its middle by `HoldLayout.grandeur` on the ground plane, its height
    /// as it was (a path's points lie on the plane; the land is found
    /// under them as they are walked).
    static func grand(_ point: Vec3, about middle: (x: Float, z: Float)) -> Vec3 {
        let k = HoldLayout.grandeur
        return Vec3(middle.x + (point.x - middle.x) * k, point.y, middle.z + (point.z - middle.z) * k)
    }

    /// A piece of a hold's plan as the hold is drawn: carried out from its
    /// middle and made as much larger, set down on the land where it now
    /// stands.
    func grand(_ piece: Piece, about middle: (x: Float, z: Float)) -> Piece {
        let at = piece.position
        let out = WorldStage.grand(at, about: middle)
        let rise = relief.height(atX: out.x, z: out.z) - relief.height(atX: at.x, z: at.z)
        var grand = piece
        grand.transform = .translation(Vec3(out.x, at.y + rise, out.z)) * .scale(HoldLayout.grandeur) * .translation(Vec3(-at.x, -at.y, -at.z))
            * piece.transform
        return grand
    }

    /// The flags that mark a hold's works as its House's people build them:
    /// in the second byte, one more than the people's place among them; the
    /// shader gives their slates, stone and timber that people's colours.
    public static func peopleFlags(_ heritage: Heritage?) -> UInt32 {
        guard let heritage, let index = Heritage.allCases.firstIndex(of: heritage) else { return 0 }
        return UInt32(index + 1) << 8
    }

    /// Whether a piece of a hold is built the way its House's people build:
    /// its works, walls and town; the keep is its people's already, and a
    /// scaffold is a scaffold anywhere.
    public static func isPeoples(_ key: ModelKey) -> Bool {
        switch key {
        case .work, .study, .walls, .town: return true
        default: return false
        }
    }

    /// The holds in sight, their keeps, walls and works each in its House's
    /// colour and its people's way, a work rising under its scaffold; and
    /// where their hearths smoke.
    public func holds(_ sights: [HoldSight], time: Float, into frame: inout SceneFrame) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var placed: [(ModelKey, ModelInstance)] = []
        var hearths: [Hearth] = []
        var poses: [PoseKey: UInt32] = [:]
        for sight in sights {
            let phase = WorldStage.phase(of: sight.hold.position, salt: sight.hold.id)
            let people = WorldStage.peopleFlags(sight.heritage)
            for piece in drawn(sight) {
                let model = Library.model(piece.key)
                let palette = model.rig.count > 1
                    ? WorldStage.pose(piece.key, .idle, at: time + phase, shared: &poses, into: &frame) : 0
                placed.append((piece.key, ModelInstance(model: piece.transform, colour: sight.colour, rise: piece.risen ?? WorldStage.whole,
                                                        phase: phase, hex: SIMD2(Int32(piece.hex.q), Int32(piece.hex.r)),
                                                        palette: palette, flags: WorldStage.isPeoples(piece.key) ? people : 0)))
                if piece.progress >= 1 {
                    hearths += piece.smoke.map { Hearth(point: $0, hex: piece.hex) }
                }
            }
        }
        return (WorldStage.batches(placed), hearths)
    }

    // MARK: Townsfolk

    /// A townsfolk's errand in a hold: who goes, the way from the keep's
    /// door to before the work (through the gate, where the hold is
    /// walled), and a salt to set them out of step with the rest.
    public struct Errand: Equatable, Sendable {
        public var key: ModelKey
        public var path: [Vec3]
        public var salt: Int

        /// The way's length, on the ground plane.
        public var length: Float {
            zip(path, path.dropFirst()).reduce(0) { total, leg in
                let dx = leg.1.x - leg.0.x, dz = leg.1.z - leg.0.z
                return total + (dx * dx + dz * dz).squareRoot()
            }
        }
    }

    /// The most townsfolk about one hold's works.
    public static let townsfolkMost = 6
    /// How long one stands at the keep's door, or at its work, before walking on.
    public static let townsfolkPause: Float = 2.4

    /// Where a hold's townsfolk go: one for each work standing whole, up to
    /// `townsfolkMost`, each between the keep's door and the front of its
    /// work, the folk of that work's kind, along the lanes of the town:
    /// straight out along the work's own lane, or where the hold is walled
    /// out through the gate, round the ring lane outside the walls and out
    /// along the work's lane.
    public func errands(of sight: HoldSight) -> [Errand] {
        let pieces = pieces(of: sight.hold, progress: sight.progress, finishing: sight.finishing, heritage: sight.heritage)
        guard let keep = pieces.first(where: { piece in
            switch piece.key {
            case .keep, .keepOf: return true
            default: return false
            }
        }) else { return [] }
        let heart = Vec3(keep.position.x, 0, keep.position.z)
        func toward(_ point: Vec3, from origin: Vec3) -> Vec3 {
            let dx = point.x - origin.x, dz = point.z - origin.z
            let length = max((dx * dx + dz * dz).squareRoot(), 1e-4)
            return Vec3(dx / length, 0, dz / length)
        }
        let walled = pieces.contains { if case .walls = $0.key { return true } else { return false } }
        let gate = HoldLayout.gate(of: sight.hold.position)
        let out = toward(gate, from: heart)
        var errands: [Errand] = []
        for (index, piece) in pieces.enumerated() where piece.progress >= 1 && errands.count < WorldStage.townsfolkMost {
            let key: ModelKey
            switch piece.key {
            case .work(let kind, _): key = .folk(of: kind)
            case .study: key = .folk(of: .archive)
            default: continue
            }
            let at = Vec3(piece.position.x, 0, piece.position.z)
            let way = toward(at, from: heart)
            let reach = ((at.x - heart.x) * (at.x - heart.x) + (at.z - heart.z) * (at.z - heart.z)).squareRoot() - HoldLayout.workRadius - 0.05
            var path = [heart + way * HoldLayout.door]
            if walled {
                path += [gate - out * 0.12, gate + out * 0.12]
                let from = Float(atan2(Double(out.z), Double(out.x))), to = Float(atan2(Double(way.z), Double(way.x)))
                let turn = Float(remainder(Double(to - from), 2 * .pi))
                let steps = Int((abs(turn) / (Float.pi / 12)).rounded(.up))
                path += (0...steps).map { step in
                    let angle = Double(from + turn * Float(step) / Float(steps))
                    return heart + Vec3(Float(cos(angle)), 0, Float(sin(angle))) * HoldLayout.ringLane
                }
                path[0] = heart + out * HoldLayout.door
                if reach > HoldLayout.ringLane + 1e-3 { path.append(heart + way * reach) }
            } else {
                path.append(heart + way * reach)
            }
            let middle = Relief.centre(of: sight.hold.position)
            errands.append(Errand(key: key, path: path.map { WorldStage.grand($0, about: middle) }, salt: sight.hold.id &* 31 &+ index))
        }
        return errands
    }

    /// Where a townsfolk is on its errand, `time` seconds in, and what it
    /// does: walking out from the door, standing at its work, walking back,
    /// standing at the door, round and round at its own pace.
    public static func walk(_ errand: Errand, at time: Float) -> (position: Vec3, heading: Float, clip: Clip) {
        let length = errand.length
        guard let first = errand.path.first, let last = errand.path.last, length > 1e-3 else {
            return (errand.path.first ?? .zero, 0, .idle)
        }
        let walking = length / (errand.key.marchSpeed ?? 0.15), pause = WorldStage.townsfolkPause
        let round = 2 * walking + 2 * pause
        var t = (time + Noise.unit(Int32(truncatingIfNeeded: errand.salt), 7, 11) * round).truncatingRemainder(dividingBy: round)
        if t < 0 { t += round }
        /// The point so far along the way, and which way that leg runs.
        func along(_ distance: Float) -> (Vec3, Float) {
            var left = distance
            for (a, b) in zip(errand.path, errand.path.dropFirst()) {
                let dx = b.x - a.x, dz = b.z - a.z
                let leg = (dx * dx + dz * dz).squareRoot()
                let heading = Float(atan2(Double(dx), Double(dz)))
                if left <= leg || b == last { return (a + (b - a) * min(left / max(leg, 1e-4), 1), heading) }
                left -= leg
            }
            return (last, 0)
        }
        let outward = along(0).1, arrived = along(length).1
        if t < walking {
            let (at, heading) = along(length * t / walking)
            return (at, heading, .march)
        }
        if t < walking + pause { return (last, arrived, .idle) }
        if t < 2 * walking + pause {
            let (at, heading) = along(length * (1 - (t - walking - pause) / walking))
            return (at, heading + .pi, .march)
        }
        return (first, outward, .idle)
    }

    /// A hold's townsfolk out and about its lanes (see
    /// `HoldLayout.strolls`), there and back: each a householder, a
    /// water-carrier, an elder or a child, by a roll of its own. Laid out
    /// again only as the town changes, not as a work rises.
    public func strolls(of sight: HoldSight) -> [Errand] {
        var plan = WorldStage.plan(of: sight.hold, progress: sight.progress, finishing: sight.finishing, heritage: sight.heritage)
        plan.rising?.progress = 0
        if let kept = strolled[sight.hold.id], kept.plan == plan { return kept.ways }
        let middle = Relief.centre(of: sight.hold.position)
        let ways = HoldLayout.strolls(plan, relief: relief).enumerated().map { index, path in
            Errand(key: .folk(ofHome: Noise.unit(Int32(truncatingIfNeeded: sight.hold.id), Int32(index), 0xF01C)),
                   path: path.map { WorldStage.grand($0, about: middle) },
                   salt: sight.hold.id &* 53 &+ 7 &+ index)
        }
        strolled[sight.hold.id] = (plan, ways)
        return ways
    }

    /// The townsfolk who keep the holds' works and, with `crowds`, as the
    /// view comes down close, the rest of their folk out about the lanes, as
    /// a frame at `time` sees them: each on the land under it, posed as it
    /// walks or stands. None about a hold whose ward is broken below half:
    /// they keep within.
    public func townsfolk(_ sights: [HoldSight], time: Float, crowds: Bool = false, into frame: inout SceneFrame) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        var shared: [PoseKey: UInt32] = [:]
        for sight in sights where sight.hold.ward * 2 >= sight.hold.maximumWard {
            let hex = SIMD2(Int32(sight.hold.position.q), Int32(sight.hold.position.r))
            for errand in errands(of: sight) + (crowds ? strolls(of: sight) : []) {
                let (at, heading, clip) = WorldStage.walk(errand, at: time)
                let start = WorldStage.pose(errand.key, clip, at: time + Float(errand.salt % 13) * 0.29, shared: &shared, into: &frame)
                placed.append((errand.key, ModelInstance(model: .translation(Vec3(at.x, ground(atX: at.x, z: at.z), at.z)) * .rotationY(heading),
                                                         colour: sight.colour, phase: Float(errand.salt % 17) * 0.31, hex: hex,
                                                         palette: start)))
            }
        }
        return WorldStage.batches(placed)
    }

    // MARK: Traffic

    /// A way between two of a House's holds, as its carts go: the hexes it
    /// runs through, end to end, and the House's colour.
    public struct Way: Equatable, Sendable {
        public var hexes: [Hex]
        public var colour: Vec4
        public var salt: Int

        public init(hexes: [Hex], colour: Vec4, salt: Int) {
            self.hexes = hexes
            self.colour = colour
            self.salt = salt
        }
    }

    /// How far from a hold's heart its carts set out and come in: beyond its walls.
    public static let wayFromHold: Float = 1.05

    /// The errand of a way's cart: a carter of timber or of stone by turns,
    /// from beyond one hold's walls to beyond the other's, through the
    /// heart of every hex between. None for holds side by side.
    public static func errand(along way: Way) -> Errand? {
        guard way.hexes.count >= 3 else { return nil }
        var path = way.hexes.map { hex -> Vec3 in
            let centre = Relief.centre(of: hex)
            return Vec3(centre.x, 0, centre.z)
        }
        func off(_ from: Vec3, toward to: Vec3) -> Vec3 {
            let dx = to.x - from.x, dz = to.z - from.z
            let length = max((dx * dx + dz * dz).squareRoot(), 1e-4)
            return from + Vec3(dx, 0, dz) * (wayFromHold / length)
        }
        path[0] = off(path[0], toward: path[1])
        path[path.count - 1] = off(path[path.count - 1], toward: path[path.count - 2])
        return Errand(key: way.salt % 2 == 0 ? .folk(of: .sawpit) : .folk(of: .quarry), path: path, salt: way.salt)
    }

    /// The carts on the ways between holds, as a frame at `time` sees them:
    /// one to a way, going from one hold to the other, a while at each, and
    /// back; each in the hex it is in, for what the keeper sees of it.
    public func traffic(_ ways: [Way], time: Float, into frame: inout SceneFrame) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        var shared: [PoseKey: UInt32] = [:]
        let layout = HexLayout(size: 1)
        for way in ways {
            guard let errand = WorldStage.errand(along: way) else { continue }
            let (at, heading, clip) = WorldStage.walk(errand, at: time)
            let hex = layout.hex(atX: Double(at.x), y: Double(at.z))
            let start = WorldStage.pose(errand.key, clip, at: time, shared: &shared, into: &frame)
            placed.append((errand.key, ModelInstance(model: .translation(Vec3(at.x, ground(atX: at.x, z: at.z), at.z)) * .rotationY(heading),
                                                     colour: way.colour, phase: Float(errand.salt % 17) * 0.31,
                                                     hex: SIMD2(Int32(hex.q), Int32(hex.r)), palette: start)))
        }
        return WorldStage.batches(placed)
    }

    // MARK: Companies

    /// What a pose is shared by: figures of one kind at one moment of a clip.
    struct PoseKey: Hashable {
        let key: ModelKey
        let clip: Clip
        let frame: Int
        var from: Clip?
        var fromFrame = 0
        var weight = 0
    }

    /// A moment of a clip in thirtieths of a second, taken round a looping
    /// clip and held at the ends of the death.
    static func frame(of clip: Clip, at time: Float) -> Int {
        let rate: Float = 30
        var moment = (time * rate).rounded()
        if clip.loops {
            let round = (clip.period * rate).rounded()
            moment -= (moment / round).rounded(.down) * round
        } else {
            moment = min(max(moment, 0), (clip.period * rate).rounded())
        }
        return Int(moment)
    }

    /// A model's pose partway from one clip into another: each part's turn,
    /// shift and size eased between the two, so no limb snaps.
    public static func blendedPose(_ key: ModelKey, _ clip: Clip, at time: Float, from blend: CompanyPose.Blend) -> [Mat4] {
        let model = Library.model(key)
        guard let motion = model.motion else { return model.pose(clip, at: time) }
        let into = motion(clip, time), out = motion(blend.clip, blend.time)
        guard into.count == out.count else { return model.pose(clip, at: time) }
        let w = min(max(blend.weight, 0), 1)
        let joints = zip(into, out).map { a, b in
            Joint(rotation: a.rotation + (b.rotation - a.rotation) * w, offset: a.offset + (b.offset - a.offset) * w,
                  scale: a.scale + (b.scale - a.scale) * w)
        }
        return model.rig.pose(joints)
    }

    /// A model's pose at a moment, added to the frame's palette once for
    /// every figure that stands so then; returns where it begins. Moments
    /// are taken to the thirtieth of a second, and round a looping clip.
    static func pose(_ key: ModelKey, _ clip: Clip, at time: Float, blend: CompanyPose.Blend? = nil, shared: inout [PoseKey: UInt32],
                     into frame: inout SceneFrame) -> UInt32 {
        let moment = WorldStage.frame(of: clip, at: time)
        var name = PoseKey(key: key.canonical, clip: clip, frame: moment)
        // Easing out of another clip, in tenths.
        let weight = blend.map { Int((min(max($0.weight, 0), 1) * 10).rounded()) } ?? 0
        if let blend, weight > 0 {
            name.from = blend.clip
            name.fromFrame = WorldStage.frame(of: blend.clip, at: blend.time)
            name.weight = weight
        }
        if let kept = shared[name] { return kept }
        let start: UInt32
        if let from = name.from {
            start = frame.add(pose: blendedPose(key, clip, at: Float(moment) / 30,
                                                from: CompanyPose.Blend(clip: from, time: Float(name.fromFrame) / 30,
                                                                        weight: Float(weight) / 10)))
        } else {
            start = frame.add(pose: Library.model(key).pose(clip, at: Float(moment) / 30))
        }
        shared[name] = start
        return start
    }

    /// The land under a point, or the water's face over the lake.
    func ground(atX x: Float, z: Float) -> Float {
        let key = SIMD2(Int32((x * 64).rounded()), Int32((z * 64).rounded()))
        if let kept = grounds[key] { return kept }
        if grounds.count > 60_000 { grounds.removeAll(keepingCapacity: true) }
        let made = max(relief.height(atX: x, z: z), Relief.waterline)
        grounds[key] = made
        return made
    }

    /// The companies, each figure on the land under it and posed at its
    /// moment, a commander at the head of the company it leads.
    public func companies(_ poses: [CompanyPose], houses: [Vec4], into frame: inout SceneFrame) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        var shared: [PoseKey: UInt32] = [:]
        for company in poses {
            let colour = WorldStage.colour(houses, sigil: company.sigil)
            let turn = Mat4.rotationY(company.heading)
            let flags = company.isOwn ? ModelInstance.alwaysShown : 0
            let hex = SIMD2(Int32(company.hex.q), Int32(company.hex.r))
            // Each company a little out of step with the next, and each figure with its neighbour.
            let offset = Float(company.unit % 7) * 0.53
            func stand(_ key: ModelKey, _ place: Vec3, _ index: Int) {
                let at = company.position + turn.transformDirection(place * (company.spread * WorldStage.figureScale))
                let ground = ground(atX: at.x, z: at.z)
                // A throng's figures share a few steps between them, each step's
                // pose worked out once, not one pose for every man in it.
                let step = company.throng > 0 ? index % WorldStage.throngSteps : index
                let lag = company.clip.loops ? offset + Float(step) * 0.137 * company.clip.period : Float(step) * 0.05
                var blend = company.blend
                if let leaving = company.blend {
                    blend?.time += leaving.clip.loops ? offset + Float(step) * 0.137 * leaving.clip.period : Float(step) * 0.05
                }
                let start = WorldStage.pose(key, company.clip, at: company.clipTime + lag, blend: blend, shared: &shared, into: &frame)
                placed.append((key, ModelInstance(model: .translation(Vec3(at.x, ground, at.z)) * turn * .scale(WorldStage.figureScale), colour: colour,
                                                  opacity: company.opacity, phase: Float(company.unit % 17) * 0.31,
                                                  emphasis: company.emphasis, hex: hex, palette: start, flags: flags)))
            }
            let led = company.commander != nil
            let places = company.throng > 0 ? Formation.throng(count: company.throng, seed: company.unit)
                : Formation.offsets(company.key, health: company.health, led: led, muster: company.muster)
            for (index, place) in places.enumerated() {
                stand(company.key, place, index)
            }
            if let commander = company.commander, !places.isEmpty {
                let head = Formation.commander(company.key, health: company.health, muster: company.muster)
                stand(.commander(variant: commander), head, places.count)
                // Its stars past the first, in an arc over its head, turning
                // slowly as one.
                if company.stars > 1 {
                    let over = company.position + turn.transformDirection(head * (company.spread * WorldStage.figureScale))
                    let lift = ground(atX: over.x, z: over.z) + WorldStage.starHeight * WorldStage.figureScale
                    let count = company.stars
                    for index in 0..<count {
                        let angle = (Float(index) - Float(count - 1) / 2) * 0.55 + Float(sin(Double(company.clipTime * 0.7))) * 0.15
                        let at = Vec3(over.x + 0.09 * sin(angle), lift + 0.03 * cos(angle), over.z + 0.09 * cos(angle))
                        placed.append((.commanderStar, ModelInstance(model: .translation(at) * .rotationY(angle + company.clipTime * 0.5),
                                                                     opacity: company.opacity, hex: hex, flags: flags)))
                    }
                }
                // On the march, its leading talents' sigil glows on the
                // ground beneath it, wider the more ranks it holds, breathing.
                if company.clip == .march, company.talentTree >= 0 {
                    let at = company.position + turn.transformDirection(head * (company.spread * WorldStage.figureScale))
                    let breath = 1 + 0.06 * Float(sin(Double(company.clipTime * 2.4)))
                    let size = WorldStage.sigilScale(ranks: company.talentRanks) * breath
                    placed.append((.talentSigil(tree: company.talentTree),
                                   ModelInstance(model: .translation(Vec3(at.x, ground(atX: at.x, z: at.z), at.z)) * turn * .scale(Vec3(size, 1, size)),
                                                 opacity: company.opacity, phase: Float(company.unit % 17) * 0.31, hex: hex, flags: flags)))
                }
            }
        }
        return WorldStage.batches(placed)
    }

    /// How high over the ground a commander's stars are carried.
    public static let starHeight: Float = 0.42
    /// How much larger than life a company's figures stand against the
    /// hexes, and how much wider they spread, as a map of war draws its
    /// hosts: big enough to read a company's kind and size at a glance.
    public static let figureScale: Float = 1.6

    /// How wide a commander's talent sigil spreads: from a third of a tile
    /// for a first rank to over half a tile with every rank learned.
    public static func sigilScale(ranks: Int) -> Float {
        0.32 + 0.016 * Float(min(max(ranks, 1), 30))
    }

    /// How high over a hold's heart its allies' help lights circle, and how
    /// wide.
    public static let helpHeight: Float = 1.15
    public static let helpRadius: Float = 0.28

    /// The help a hold's allies have given its work being raised, its
    /// muster and its House's study, as lights circling over its keep, one
    /// for each ally that helped, turning slowly. A House sees only its own
    /// holds' and its allies' help: the realm tells no one else of it.
    public func helpLights(_ sights: [HoldSight], time: Float) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        for sight in sights {
            let helpers = Set((sight.hold.project?.helpers ?? []) + (sight.hold.training?.helpers ?? []))
            guard !helpers.isEmpty else { continue }
            let centre = Relief.centre(of: sight.hold.position)
            let y = ground(atX: centre.x, z: centre.z) + WorldStage.helpHeight
            let hex = SIMD2(Int32(sight.hold.position.q), Int32(sight.hold.position.r))
            for (index, _) in helpers.sorted().enumerated() {
                let angle = time * 0.5 + Float(index) / Float(helpers.count) * 2 * .pi
                let bob = 0.03 * Float(sin(Double(time * 1.7 + Float(index))))
                let at = Vec3(centre.x + WorldStage.helpRadius * Float(sin(Double(angle))), y + bob,
                              centre.z + WorldStage.helpRadius * Float(cos(Double(angle))))
                placed.append((.helpLight, ModelInstance(model: .translation(at) * .rotationY(angle), colour: sight.colour,
                                                         phase: Float(index) * 0.7, hex: hex)))
            }
        }
        return WorldStage.batches(placed)
    }

    /// How far a field's banners stand from its heart.
    public static let fieldBannerSpread: Float = 0.3

    /// How far a side's banner leans from upright with its share of the
    /// troops still standing in the field: upright at even or better, more
    /// the fewer it has, and laid flat when it has none.
    public static func bannerLean(share: Float) -> Float {
        if share <= 0 { return 1.45 }
        return min(max(0.5 - share, 0), 0.5) * 1.6
    }

    /// Each field of battle in sight with both its sides' war banners
    /// planted at its heart, a little apart along the line between them,
    /// each in its side's foremost House's colour and leaning as its side
    /// gives ground, stirring.
    public func fieldBanners(_ fields: [(at: Hex, colours: [Vec4], shares: [Float])], time: Float) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        for field in fields where field.colours.count == 2 && field.shares.count == 2 {
            let centre = Relief.centre(of: field.at)
            let across = WorldStage.phase(of: field.at, salt: 47) * 2 * .pi
            let hex = SIMD2(Int32(field.at.q), Int32(field.at.r))
            for side in 0..<2 {
                let sign: Float = side == 0 ? -1 : 1
                let x = centre.x + sign * WorldStage.fieldBannerSpread * Float(sin(Double(across)))
                let z = centre.z + sign * WorldStage.fieldBannerSpread * Float(cos(Double(across)))
                let stir = field.shares[side] > 0 ? 0.04 * Float(sin(Double(time * 1.3 + Float(side) * 2))) : 0
                let lean = WorldStage.bannerLean(share: field.shares[side]) + stir
                let model = Mat4.translation(Vec3(x, ground(atX: x, z: z), z)) * .rotationY(across + (side == 0 ? 0 : .pi))
                    * .rotationX(-lean)
                placed.append((.hostBanner, ModelInstance(model: model, colour: field.colours[side], phase: Float(side) * 0.5, hex: hex)))
            }
        }
        return WorldStage.batches(placed)
    }

    /// How far toward a side of its hex a border stone stands.
    public static let borderInset: Float = 0.38

    /// Boundary stones where alliances' land ends, one at each side of a
    /// hex of it beside land not its own, turned to face out, in the
    /// alliance's colour.
    public func borderStones(_ borders: [(hex: Hex, outward: Hex, colour: Vec4)]) -> [ModelBatch] {
        WorldStage.batches(borders.map { border in
            let centre = Relief.centre(of: border.hex)
            let beyond = Relief.centre(of: Hex(border.hex.q + border.outward.q, border.hex.r + border.outward.r))
            var way = Vec3(beyond.x - centre.x, 0, beyond.z - centre.z)
            way = way * (1 / max(way.length, 0.0001))
            let x = centre.x + way.x * WorldStage.borderInset, z = centre.z + way.z * WorldStage.borderInset
            let model = Mat4.translation(Vec3(x, ground(atX: x, z: z) - Scatter.sink, z)) * .rotationY(Float(atan2(Double(way.x), Double(way.z))))
            return (.borderStone, ModelInstance(model: model, colour: border.colour, phase: WorldStage.phase(of: border.hex, salt: 53),
                                                hex: SIMD2(Int32(border.hex.q), Int32(border.hex.r))))
        })
    }

    /// A company drawing off from a field goes in broken order, its ranks
    /// spread wide, and in haste, its stride quicker.
    public static let routSpread: Float = 1.45
    /// The steps a throng's figures are spread across, out of step with each other.
    public static let throngSteps = 5
    /// A side in a field of battle breaks and runs once fewer than this
    /// share of the troops it brought still stand.
    public static let routBelow: Float = 0.35
    public static let routPace: Float = 1.6

    /// Each tincture's colour, as the interface paints it.
    public static func colour(of tincture: Crest.Tincture) -> Vec4 {
        switch tincture {
        case .silver: return Vec4(0.80, 0.82, 0.85, 1)
        case .gold: return Vec4(0.84, 0.66, 0.25, 1)
        case .black: return Vec4(0.10, 0.10, 0.12, 1)
        case .blue: return Vec4(0.20, 0.37, 0.67, 1)
        case .red: return Vec4(0.66, 0.20, 0.18, 1)
        case .green: return Vec4(0.19, 0.49, 0.31, 1)
        case .purple: return Vec4(0.42, 0.26, 0.62, 1)
        }
    }

    /// How far out from a hold's heart its crest hangs, and how far to the
    /// side of its gate.
    public static let crestReach: Float = 0.56
    public static let crestAside: Float = 0.2

    /// Each hold's House crest hung on a board beside its gate, facing out:
    /// the shield in its field tincture, its charge laid on it in its own.
    public func crestBoards(_ boards: [(hex: Hex, crest: Crest)]) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        for board in boards {
            let centre = Relief.centre(of: board.hex)
            let front = HoldLayout.frontAngle(of: board.hex)
            let out = Vec3(Float(cos(Double(front))), 0, Float(sin(Double(front))))
            let side = Vec3(-out.z, 0, out.x)
            let x = centre.x + out.x * WorldStage.crestReach + side.x * WorldStage.crestAside
            let z = centre.z + out.z * WorldStage.crestReach + side.z * WorldStage.crestAside
            let model = Mat4.translation(Vec3(x, ground(atX: x, z: z) - Scatter.sink, z)) * .rotationY(Float(atan2(Double(out.x), Double(out.z))))
            let hex = SIMD2(Int32(board.hex.q), Int32(board.hex.r))
            let charge = Crest.Charge.allCases.firstIndex(of: board.crest.charge) ?? 0
            placed.append((.crestBoard, ModelInstance(model: model, colour: WorldStage.colour(of: board.crest.field), hex: hex)))
            placed.append((.crestCharge(charge), ModelInstance(model: model, colour: WorldStage.colour(of: board.crest.tincture), hex: hex)))
        }
        return WorldStage.batches(placed)
    }

    /// Where a barge rides on the still water and which way it heads: from
    /// the water it pushed off from toward the water it makes for, eased in
    /// and out, as far as the watch has gone.
    public static func bargePlace(from: Hex, to: Hex, progress: Float) -> (at: Vec3, heading: Float) {
        let a = Relief.centre(of: from), b = Relief.centre(of: to)
        let t = min(max(progress, 0), 1), eased = t * t * (3 - 2 * t)
        let at = Vec3(a.x + (b.x - a.x) * eased, Relief.waterline, a.z + (b.z - a.z) * eased)
        return (at, Float(atan2(Double(b.x - a.x), Double(b.z - a.z))))
    }

    /// The barges out on the water, each where the watch has brought it,
    /// rocking gently, its lantern lit.
    public func barges(_ barges: [(from: Hex, to: Hex, progress: Float)], time: Float) -> [ModelBatch] {
        WorldStage.batches(barges.enumerated().map { index, barge in
            let place = WorldStage.bargePlace(from: barge.from, to: barge.to, progress: barge.progress)
            let rock = 0.03 * Float(sin(Double(time * 1.1 + Float(index))))
            let model = Mat4.translation(place.at) * .rotationY(place.heading) * .rotationZ(rock)
            return (.barge, ModelInstance(model: model, phase: Float(index) * 0.6, hex: SIMD2(Int32(barge.from.q), Int32(barge.from.r)),
                                          flags: ModelInstance.alwaysShown))
        })
    }

    /// How high the Drowned Crown floats above the ground where it lies,
    /// and above its bearer.
    public static let crownLying: Float = 0.12
    public static let crownBorne: Float = 0.62

    /// The Drowned Crown: turning slowly just above the ford where it lies,
    /// or high over the company that bears it, bobbing as it goes.
    public func drownedCrown(at hex: Hex, borne: Bool, time: Float) -> [ModelBatch] {
        let centre = Relief.centre(of: hex)
        let rise = borne ? WorldStage.crownBorne : WorldStage.crownLying
        let bob = (borne ? 0.04 : 0.015) * Float(sin(Double(time * 1.3)))
        let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) + rise + bob, centre.z)
        let model = Mat4.translation(at) * .rotationY(time * 0.4) * .scale(Vec3(repeating: borne ? 0.8 : 1))
        return WorldStage.batches([(.drownedCrown, ModelInstance(model: model, hex: SIMD2(Int32(hex.q), Int32(hex.r)),
                                                                   flags: ModelInstance.alwaysShown))])
    }

    /// How the Lyceum's scholars' lights circle its dome while it sits.
    public static let lyceumLightHeight: Float = 0.62
    public static let lyceumLightRadius: Float = 0.36

    /// The Lyceum's hall on its open ground. While its scholars sit the
    /// orrery over its dome turns and their lights circle it, one for each
    /// of the questions set; between sittings it stands dark and still.
    public func lyceum(at hex: Hex, lit: Bool, time: Float) -> [ModelBatch] {
        let centre = Relief.centre(of: hex)
        let base = Vec3(centre.x, ground(atX: centre.x, z: centre.z), centre.z)
        let cell = SIMD2(Int32(hex.q), Int32(hex.r))
        var placed: [(ModelKey, ModelInstance)] = [(.lyceumHall, ModelInstance(model: .translation(base), hex: cell,
                                                                                flags: ModelInstance.alwaysShown))]
        guard lit else { return WorldStage.batches(placed) }
        placed.append((.lyceumOrrery, ModelInstance(model: .translation(base + LyceumHall.orreryAt) * .rotationY(time * 0.6), hex: cell,
                                                    flags: ModelInstance.alwaysShown)))
        let lights = Lyceum.questions
        for index in 0..<lights {
            let angle = -time * 0.35 + Float(index) / Float(lights) * 2 * .pi
            let bob = 0.025 * Float(sin(Double(time * 1.4 + Float(index))))
            let at = base + Vec3(WorldStage.lyceumLightRadius * sin(angle), WorldStage.lyceumLightHeight + bob,
                                 WorldStage.lyceumLightRadius * cos(angle))
            placed.append((.helpLight, ModelInstance(model: .translation(at) * .rotationY(angle), colour: Vec4(1.0, 0.82, 0.55, 1),
                                                     phase: Float(index) * 0.9, hex: cell, flags: ModelInstance.alwaysShown)))
        }
        return WorldStage.batches(placed)
    }

    /// A House's listening stones, standing in the water where they were
    /// sunk, their ripples turning out; one that heard a march last watch
    /// turns them faster.
    public func listeningStones(_ stones: [(at: Hex, heard: Bool)]) -> [ModelBatch] {
        WorldStage.batches(stones.enumerated().map { index, stone in
            let centre = Relief.centre(of: stone.at)
            let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z), centre.z)
            return (.listeningStone, ModelInstance(model: .translation(at) * .rotationY(Float(index) * 1.3), phase: stone.heard ? 2.1 : 0.7,
                                                   hex: SIMD2(Int32(stone.at.q), Int32(stone.at.r)), flags: ModelInstance.alwaysShown))
        })
    }

    /// The pedlar's skiff lying off a hold, rocking a little on the still
    /// water, its prow toward the shore.
    public func pedlarSkiff(at hex: Hex, toward shore: Hex, time: Float) -> [ModelBatch] {
        let centre = Relief.centre(of: hex), land = Relief.centre(of: shore)
        let heading = atan2(land.x - centre.x, land.z - centre.z)
        let at = Vec3(centre.x, ground(atX: centre.x, z: centre.z) + 0.005 * Float(sin(Double(time * 0.9))), centre.z)
        let model = Mat4.translation(at) * .rotationY(heading) * .rotationZ(0.03 * Float(sin(Double(time * 0.7))))
        return WorldStage.batches([(.pedlarSkiff, ModelInstance(model: model, phase: 0.4, hex: SIMD2(Int32(hex.q), Int32(hex.r)),
                                                                flags: ModelInstance.alwaysShown))])
    }

    // MARK: What flies

    /// The veil of the Still about a hold: six banks of low mist ringing
    /// its walls, on the ground at `height`.
    public static func mist(about hex: Hex, height: Float) -> [Hearth] {
        let centre = Relief.centre(of: hex)
        return (0..<6).map { index in
            let angle = Double(index) * .pi / 3
            return Hearth(point: Vec3(centre.x + 0.42 * Float(cos(angle)), height + 0.04, centre.z + 0.42 * Float(sin(angle))), hex: hex)
        }
    }

    /// Arrows in flight, the night's birds wheeling over the lake, the
    /// smoke of the holds' hearths and the mist of the veils, as a frame at
    /// `time` sees them.
    public static func flights(arrows: [ArrowFlight], birdsOver lake: Vec3?, hearths: [Hearth], mists: [Hearth] = [], time: Float,
                               into frame: inout SceneFrame) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        for arrow in arrows where (0...1).contains(arrow.progress) {
            placed.append((.prop(arrow.stone ? .stone : .arrow), ModelInstance(model: arrow.transform, flags: ModelInstance.alwaysShown)))
        }
        var shared: [PoseKey: UInt32] = [:]
        if let lake {
            for bird in 0..<5 {
                let b = Float(bird)
                let radius = 2.6 + b * 0.9
                let way: Float = bird % 2 == 0 ? 1 : -1
                let angle = time * (0.16 + b * 0.02) * way + b * 1.3
                let at = Vec3(lake.x + radius * Float(cos(Double(angle))), lake.y + 1.9 + 0.35 * Float(sin(Double(angle * 2 + b))),
                              lake.z + radius * Float(sin(Double(angle))))
                // Along its circle: the way it goes, a quarter turn from where it is.
                let heading = Float(atan2(Double(-Float(sin(Double(angle))) * way), Double(Float(cos(Double(angle))) * way)))
                let pose = pose(.prop(.bird), .idle, at: time + b * 0.7, shared: &shared, into: &frame)
                placed.append((.prop(.bird), ModelInstance(model: .translation(at) * .rotationY(heading), phase: b * 0.7,
                                                           palette: pose, flags: ModelInstance.alwaysShown)))
            }
        }
        for (index, hearth) in hearths.enumerated() {
            // Each hearth's smoke rises and thins once a period, out of step with the next.
            let local = time + Float(index) * 0.53
            let progress = Clip.idle.progress(at: local)
            let pose = pose(.prop(.puff), .idle, at: local, shared: &shared, into: &frame)
            placed.append((.prop(.puff), ModelInstance(model: .translation(hearth.point), opacity: 0.85 * (1 - progress),
                                                       hex: SIMD2(Int32(hearth.hex.q), Int32(hearth.hex.r)), palette: pose)))
        }
        for (index, mist) in mists.enumerated() {
            // Low banks of the lake's mist, wide and flat, breathing slowly in
            // and out of sight but never rising: a breath over the black
            // ground, never a bank of cotton before a low eye.
            let pose = pose(.prop(.puff), .idle, at: Float(index % 6) * 0.11, shared: &shared, into: &frame)
            let breath = 0.5 + 0.5 * Float(sin(Double(time * 0.45 + Float(index) * 1.3)))
            placed.append((.prop(.puff), ModelInstance(model: .translation(mist.point) * .scale(Vec3(3.2, 0.55, 3.2)), opacity: 0.05 + 0.05 * breath,
                                                       hex: SIMD2(Int32(mist.hex.q), Int32(mist.hex.r)), palette: pose)))
        }
        return batches(placed)
    }

    // MARK: Helpers

    /// Instances gathered by their model's key, in a steady order.
    /// Batches of the land's pieces set working: each instance of a model
    /// with a rig posed at one of four moments of its idle clip, its fires
    /// leaping and its holy motes turning; still models left as they are.
    public func animate(_ batches: [ModelBatch], time: Float, into frame: inout SceneFrame) -> [ModelBatch] {
        var poses: [PoseKey: UInt32] = [:]
        return batches.map { batch in
            guard Library.model(batch.key).rig.count > 1 else { return batch }
            var batch = batch
            // Each instance at one of four moments of its idle clip, by its
            // phase, so instances share their poses: at most four a model a
            // frame, however many stand.
            for index in batch.instances.indices {
                let phase = Float(Int(batch.instances[index].params.z) % 4) * 0.7
                batch.instances[index].palette = WorldStage.pose(batch.key, .idle, at: time + phase, shared: &poses, into: &frame)
            }
            return batch
        }
    }

    static func batches(_ placed: [(ModelKey, ModelInstance)]) -> [ModelBatch] {
        var order: [ModelKey] = []
        var byKey: [ModelKey: [ModelInstance]] = [:]
        for (key, instance) in placed {
            let canonical = key.canonical
            if byKey[canonical] == nil { order.append(canonical) }
            byKey[canonical, default: []].append(instance)
        }
        return order.map { ModelBatch(key: $0, instances: byKey[$0] ?? []) }
    }

    /// A House's colour by its sigil, grey if there are none.
    public static func colour(_ houses: [Vec4], sigil: Int) -> Vec4 {
        houses.isEmpty ? Vec4(0.6, 0.6, 0.6, 1) : houses[(sigil % houses.count + houses.count) % houses.count]
    }

    /// A steady phase for what sways or flickers, so no two neighbours move as one.
    static func phase(of hex: Hex, salt: Int) -> Float {
        Noise.unit(Int32(truncatingIfNeeded: hex.q), Int32(truncatingIfNeeded: hex.r), UInt32(truncatingIfNeeded: salt)) * 20
    }
}
