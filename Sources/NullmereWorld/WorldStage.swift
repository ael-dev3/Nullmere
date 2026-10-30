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

    public init(unit: Int, key: ModelKey, sigil: Int, health: Int, hex: Hex, position: Vec3, heading: Float, clip: Clip = .idle,
                clipTime: Float = 0, opacity: Float = 1, emphasis: Float = 0, isOwn: Bool, commander: Int? = nil, spread: Float = 1) {
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

/// An arrow loosed: from where, to where, and how far along its flight.
public struct ArrowFlight: Equatable, Sendable {
    public var from: Vec3
    public var to: Vec3
    public var progress: Float

    public init(from: Vec3, to: Vec3, progress: Float) {
        self.from = from
        self.to = to
        self.progress = progress
    }

    /// Where it is and how it lies: rising from the bow in an arc, nose
    /// along its flight, and coming down on the mark.
    public var transform: Mat4 {
        let t = min(max(progress, 0), 1)
        let span = to - from
        let across = (span.x * span.x + span.z * span.z).squareRoot()
        let height = max(0.35, across * 0.22)
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

    public init(hold: Hold, colour: Vec4, progress: Float? = nil, finishing: HoldLayout.Plan.Rising? = nil) {
        self.hold = hold
        self.colour = colour
        self.progress = progress
        self.finishing = finishing
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
    private var laid: [Int: (hold: Hold, progress: Float?, finishing: HoldLayout.Plan.Rising?, pieces: [Piece])] = [:]
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
                changed.formUnion(hold.spiral(2).filter { map[$0] != nil })
            }
        } else {
            changed = Set(map.hexes)
        }
        for hex in changed {
            furnitureByHex[hex] = Scatter.pieces(in: hex, map: map, relief: relief,
                                                 clearHeart: occupied.contains(hex) || holds.contains(hex), holds: holds)
        }
        var placed: [(ModelKey, ModelInstance)] = []
        for hex in map.hexes {
            for piece in furnitureByHex[hex] ?? [] {
                placed.append((piece.key, ModelInstance(model: piece.transform, phase: WorldStage.phase(of: piece.hex, salt: 3),
                                                        hex: SIMD2(Int32(piece.hex.q), Int32(piece.hex.r)))))
            }
        }
        furniture = WorldStage.batches(placed)
        furnished = (occupied, holds)
        furnitureVersion += 1
        return furniture
    }

    // MARK: Holds

    /// A hold's pieces, laid out again only when it or its rising changes.
    /// A work `finishing` stands at the level below it until it has risen.
    public func pieces(of hold: Hold, progress: Float?, finishing: HoldLayout.Plan.Rising? = nil) -> [Piece] {
        if let kept = laid[hold.id], kept.hold == hold, kept.progress == progress, kept.finishing == finishing { return kept.pieces }
        var plan = HoldLayout.Plan(hold: hold, progress: progress)
        if let finishing, plan.rising == nil {
            plan.levels[finishing.work] = finishing.level > 1 ? finishing.level - 1 : nil
            plan.rising = finishing
        }
        let made = HoldLayout.pieces(plan, relief: relief)
        laid[hold.id] = (hold, progress, finishing, made)
        return made
    }

    /// The holds in sight, their keeps, walls and works each in its House's
    /// colour, a work rising under its scaffold; and where their hearths smoke.
    public func holds(_ sights: [HoldSight], time: Float, into frame: inout SceneFrame) -> (batches: [ModelBatch], hearths: [Hearth]) {
        var placed: [(ModelKey, ModelInstance)] = []
        var hearths: [Hearth] = []
        var poses: [PoseKey: UInt32] = [:]
        for sight in sights {
            let phase = WorldStage.phase(of: sight.hold.position, salt: sight.hold.id)
            for piece in pieces(of: sight.hold, progress: sight.progress, finishing: sight.finishing) {
                let model = Library.model(piece.key)
                let palette = model.rig.count > 1
                    ? WorldStage.pose(piece.key, .idle, at: time + phase, shared: &poses, into: &frame) : 0
                placed.append((piece.key, ModelInstance(model: piece.transform, colour: sight.colour, rise: piece.risen ?? WorldStage.whole,
                                                        phase: phase, hex: SIMD2(Int32(piece.hex.q), Int32(piece.hex.r)),
                                                        palette: palette)))
                if piece.progress >= 1 {
                    hearths += piece.smoke.map { Hearth(point: $0, hex: piece.hex) }
                }
            }
        }
        return (WorldStage.batches(placed), hearths)
    }

    // MARK: Companies

    /// What a pose is shared by: figures of one kind at one moment of a clip.
    struct PoseKey: Hashable {
        let key: ModelKey
        let clip: Clip
        let frame: Int
    }

    /// A model's pose at a moment, added to the frame's palette once for
    /// every figure that stands so then; returns where it begins. Moments
    /// are taken to the thirtieth of a second, and round a looping clip.
    static func pose(_ key: ModelKey, _ clip: Clip, at time: Float, shared: inout [PoseKey: UInt32], into frame: inout SceneFrame) -> UInt32 {
        let rate: Float = 30
        var moment = (time * rate).rounded()
        if clip.loops {
            let round = (clip.period * rate).rounded()
            moment -= (moment / round).rounded(.down) * round
        } else {
            moment = min(max(moment, 0), (clip.period * rate).rounded())
        }
        let name = PoseKey(key: key.canonical, clip: clip, frame: Int(moment))
        if let kept = shared[name] { return kept }
        let start = frame.add(pose: Library.model(key).pose(clip, at: moment / rate))
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
                let at = company.position + turn.transformDirection(place * company.spread)
                let ground = ground(atX: at.x, z: at.z)
                let lag = company.clip.loops ? offset + Float(index) * 0.137 * company.clip.period : Float(index) * 0.05
                let start = WorldStage.pose(key, company.clip, at: company.clipTime + lag, shared: &shared, into: &frame)
                placed.append((key, ModelInstance(model: .translation(Vec3(at.x, ground, at.z)) * turn, colour: colour,
                                                  opacity: company.opacity, phase: Float(company.unit % 17) * 0.31,
                                                  emphasis: company.emphasis, hex: hex, palette: start, flags: flags)))
            }
            let led = company.commander != nil
            let places = Formation.offsets(company.key, health: company.health, led: led)
            for (index, place) in places.enumerated() {
                stand(company.key, place, index)
            }
            if let commander = company.commander, !places.isEmpty {
                stand(.commander(variant: commander), Formation.commander(company.key, health: company.health), places.count)
            }
        }
        return WorldStage.batches(placed)
    }

    // MARK: What flies

    /// Arrows in flight, the night's birds wheeling over the lake, and the
    /// smoke of the holds' hearths, as a frame at `time` sees them.
    public static func flights(arrows: [ArrowFlight], birdsOver lake: Vec3?, hearths: [Hearth], time: Float,
                               into frame: inout SceneFrame) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        for arrow in arrows where (0...1).contains(arrow.progress) {
            placed.append((.prop(.arrow), ModelInstance(model: arrow.transform, flags: ModelInstance.alwaysShown)))
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
        return batches(placed)
    }

    // MARK: Helpers

    /// Instances gathered by their model's key, in a steady order.
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
