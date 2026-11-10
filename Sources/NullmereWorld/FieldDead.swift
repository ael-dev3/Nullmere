import Foundation
import NullmereCore
import NullmereModels

/// A blow the keeper saw struck, kept so the dead it left lie on the field
/// after it (`WorldStage.fieldDead`): from where and at where it was
/// struck, each side's dead (of what kind, in what colour, how many
/// troops), whether it was loosed from afar, and in which watch.
public struct FieldBlow: Equatable, Sendable {
    /// The dead of one side of a blow: who they were and how many troops.
    public struct Side: Equatable, Sendable {
        public var kind: ModelKey
        public var colour: Vec4
        public var troops: Int

        public init(kind: ModelKey, colour: Vec4, troops: Int) {
            self.kind = kind
            self.colour = colour
            self.troops = troops
        }
    }

    public var from: Hex
    public var at: Hex
    /// The struck company's dead; nil where a hold's ward was struck.
    public var struck: Side?
    /// The striker's dead, to the blow struck back.
    public var striker: Side?
    public var watch: Int
    public var seed: Int

    public init(from: Hex, at: Hex, struck: Side?, striker: Side?, watch: Int, seed: Int) {
        self.from = from
        self.at = at
        self.struck = struck
        self.striker = striker
        self.watch = watch
        self.seed = seed
    }

    /// Loosed from afar, by bows or an engine: no line where two fronts met.
    public var isRanged: Bool { from.distance(to: at) > 1 }

    /// The blow as its field keeps it once the dead lying on `hex` are
    /// buried: those who fell there laid in the barrow, the side that fell
    /// elsewhere still lying where it fell; nil once none of its dead lie
    /// on the field at all.
    public func buried(at hex: Hex) -> FieldBlow? {
        var kept = self
        if at == hex { kept.struck = nil }
        if from == hex { kept.striker = nil }
        return kept.struck == nil && kept.striker == nil ? nil : kept
    }
}

extension WorldStage {
    /// How many watches a field keeps its dead: the watch it was fought in
    /// and the next two, fewer each, as they are carried off.
    public static let deadKept = 3
    /// How many troops fallen one man lying stands for.
    public static let troopsPerDead = 400
    /// The most men one side of a blow leaves lying.
    public static let deadMost = 5
    /// The most dead a frame draws, the newest first.
    public static let deadDrawnMost = 240
    /// How far either side of the line where two fronts met their dead lie,
    /// and how far along it, as shares of the way between the two hexes'
    /// hearts.
    public static let deadNear: Float = 0.06
    public static let deadDeep: Float = 0.22
    public static let deadAlong: Float = 0.36
    /// How far about the struck the dead of a blow from afar lie.
    public static let deadAbout: Float = 0.45
    /// How much wider the dead of a heavy kind lie, a horse beside its
    /// rider or an engine by its crew.
    public static let heavyDeadWider: Float = 1.4
    /// How far either way from facing the foe a man lies as he fell.
    public static let deadTurned: Float = 1.5
    /// How many arrows stand in the ground about each man a volley felled.
    public static let arrowsPerDead = 3
    /// How long the birds come to a field: the watch it was fought in and
    /// the next.
    public static let birdsKept = 2
    public static let birdsOver: Float = 0.95

    /// A chance from 0 up to 1 for one of a blow's dead and what is asked
    /// of him, the same every frame and well stirred (a split-mix of the
    /// blow, the man, his side and what is asked), so neighbours in a row
    /// neither lie alike nor fall alike.
    static func deadChance(_ blow: FieldBlow, _ index: Int, _ struck: Bool, _ salt: UInt64) -> Float {
        let side: UInt64 = struck ? 1 : 2
        var stirred = UInt64(bitPattern: Int64(blow.seed)) &* 0x9E37_79B9_7F4A_7C15
        stirred = stirred &+ UInt64(bitPattern: Int64(index)) &* 0xBF58_476D_1CE4_E5B9
        stirred = stirred &+ side &* 0x94D0_49BB_1331_11EB &+ salt
        stirred = (stirred ^ (stirred >> 30)) &* 0xBF58_476D_1CE4_E5B9
        stirred = (stirred ^ (stirred >> 27)) &* 0x94D0_49BB_1331_11EB
        stirred ^= stirred >> 31
        return Float(stirred >> 40) / Float(1 << 24)
    }

    /// How many men lie for `troops` fallen `since` watches after the blow:
    /// one for any fallen, one more for every `troopsPerDead`, at most
    /// `deadMost`; fewer each watch after, and none once `deadKept` have
    /// passed.
    public static func deadCount(troops: Int, since: Int) -> Int {
        guard troops > 0, (0..<deadKept).contains(since) else { return 0 }
        let full = min(deadMost, 1 + troops / troopsPerDead)
        return max(1, (full * (deadKept - since) + deadKept - 1) / deadKept)
    }

    /// How many of a man on foot one of a kind's dead stands for: a horse
    /// fallen with its rider, or an engine broken by its crew, two.
    public static func deadWeight(of kind: ModelKey) -> Int {
        switch kind {
        case .figure(.rider, _), .figure(.mangonel, _), .commander: return 2
        case .signature(let heritage): return heritage.signature == .rider || heritage.signature == .mangonel ? 2 : 1
        default: return 1
        }
    }

    /// How many of a kind lie for `troops` fallen `since` watches after the
    /// blow: as many as `deadCount` men on foot, a heavy kind half as many.
    public static func deadLying(_ kind: ModelKey, troops: Int, since: Int) -> Int {
        let weight = deadWeight(of: kind)
        return (deadCount(troops: troops, since: since) + weight - 1) / weight
    }

    /// Where a side's dead lie and which way each faces, on the ground
    /// (only x and z are kept): where two fronts met, along the line
    /// between the two hexes, each side's on its own side of it, facing
    /// the foe as they fell or near it; for a blow from afar, about the
    /// struck. The same for a blow each frame, the first of a side's dead
    /// the last carried off.
    public static func deadPlaces(of blow: FieldBlow, struck: Bool, count: Int, wide: Float = 1) -> [(at: Vec3, heading: Float)] {
        let home = struck ? blow.at : blow.from, foe = struck ? blow.from : blow.at
        let (here, there) = (Relief.centre(of: home), Relief.centre(of: foe))
        let centre = Vec3(here.x, 0, here.z), facing = Vec3(there.x, 0, there.z)
        let toward = CompanyPose.heading(from: home, to: foe)
        return (0..<max(count, 0)).map { index in
            func unit(_ salt: UInt64) -> Float { WorldStage.deadChance(blow, index, struck, salt) }
            let heading = toward + (unit(31) - 0.5) * 2 * WorldStage.deadTurned
            if blow.isRanged || home == foe {
                let radius = WorldStage.deadAbout * wide * (0.25 + 0.75 * unit(37).squareRoot())
                let angle = unit(41) * 2 * .pi
                return (Vec3(centre.x + radius * Float(cos(Double(angle))), 0, centre.z + radius * Float(sin(Double(angle)))), heading)
            }
            let way = facing - centre
            let middle = centre + way * 0.5
            let across = Vec3(way.z, 0, -way.x)
            let deep = WorldStage.deadNear + WorldStage.deadDeep * wide * unit(43)
            let along = (unit(47) - 0.5) * 2 * WorldStage.deadAlong * min(wide, 1.2)
            let at = middle - way * deep + across * along
            return (Vec3(at.x, 0, at.z), heading)
        }
    }

    /// The dead the blows the keeper saw left on their fields, `watch`
    /// being the realm's now: each man lying as he fell (his kind's death
    /// played to its end), in his House's colour, fewer each watch until
    /// none; arrows standing in the ground about those a volley felled;
    /// and, over a field fought this watch or the last, birds come down to
    /// it, wheeling low (with `birds`).
    public func fieldDead(_ blows: [FieldBlow], watch: Int, time: Float, birds: Bool = true,
                          into frame: inout SceneFrame) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        var shared: [PoseKey: UInt32] = [:]
        var drawn = 0
        var wheeledOver = Set<Hex>()
        for blow in blows.sorted(by: { ($0.watch, $0.seed) > ($1.watch, $1.seed) }) {
            let since = watch - blow.watch
            guard drawn < WorldStage.deadDrawnMost, (0..<WorldStage.deadKept).contains(since) else { continue }
            for (struck, side) in [(true, blow.struck), (false, blow.striker)] {
                guard let side else { continue }
                let heavy = WorldStage.deadWeight(of: side.kind) > 1
                let count = min(WorldStage.deadLying(side.kind, troops: side.troops, since: since), WorldStage.deadDrawnMost - drawn)
                guard count > 0 else { continue }
                let home = struck ? blow.at : blow.from
                let hex = SIMD2(Int32(home.q), Int32(home.r))
                let lying = WorldStage.pose(side.kind, .death, at: Clip.death.period, shared: &shared, into: &frame)
                let places = WorldStage.deadPlaces(of: blow, struck: struck, count: count, wide: heavy ? WorldStage.heavyDeadWider : 1)
                for (index, place) in places.enumerated() {
                    let lies = ground(atX: place.at.x, z: place.at.z)
                    placed.append((side.kind, ModelInstance(model: .translation(Vec3(place.at.x, lies, place.at.z)) * .rotationY(place.heading)
                                                               * .scale(WorldStage.figureScale),
                                                             colour: side.colour, phase: Float(index) * 0.31, hex: hex, palette: lying)))
                    // The arrows that felled him standing in the ground about
                    // him, their feathers toward the bows.
                    guard struck, blow.isRanged else { continue }
                    let from = CompanyPose.heading(from: blow.from, to: blow.at)
                    for arrow in 0..<WorldStage.arrowsPerDead {
                        func unit(_ salt: UInt64) -> Float { WorldStage.deadChance(blow, index * 8 + arrow, true, salt &+ 101) }
                        let angle = unit(53) * 2 * .pi, reach = 0.04 + 0.1 * unit(59)
                        let x = place.at.x + reach * Float(cos(Double(angle))), z = place.at.z + reach * Float(sin(Double(angle)))
                        let pitch = 0.95 + 0.4 * unit(61)
                        let yaw = from + (unit(67) - 0.5) * 0.7
                        placed.append((.prop(.arrow), ModelInstance(model: .translation(Vec3(x, ground(atX: x, z: z) + 0.05, z))
                                                                       * .rotationY(yaw) * .rotationX(pitch) * .scale(0.7),
                                                                     hex: hex)))
                    }
                }
                drawn += count
            }
            // Birds come down to a field fought lately, wheeling low over it.
            guard birds, since < WorldStage.birdsKept, blow.struck != nil || blow.striker != nil,
                  wheeledOver.insert(blow.at).inserted else { continue }
            let (struckAt, strikerAt) = (Relief.centre(of: blow.at), Relief.centre(of: blow.from))
            let middle = blow.isRanged ? Vec3(struckAt.x, 0, struckAt.z)
                : Vec3((struckAt.x + strikerAt.x) / 2, 0, (struckAt.z + strikerAt.z) / 2)
            let lift = ground(atX: middle.x, z: middle.z) + WorldStage.birdsOver
            for bird in 0..<3 {
                let b = Float(bird)
                let way: Float = bird % 2 == 0 ? 1 : -1
                let angle = time * (0.45 + b * 0.07) * way + b * 2.1 + WorldStage.phase(of: blow.at, salt: 71)
                let radius = 0.28 + b * 0.09
                let (sine, cosine) = (Float(sin(Double(angle))), Float(cos(Double(angle))))
                let at = Vec3(middle.x + radius * cosine, lift + 0.12 * b + 0.05 * Float(sin(Double(angle * 2 + b))), middle.z + radius * sine)
                // Along its circle: the way it goes, a quarter turn from where it is.
                let heading = Float(atan2(Double(-sine * way), Double(cosine * way)))
                let pose = WorldStage.pose(.prop(.bird), .idle, at: time + b * 0.7, shared: &shared, into: &frame)
                placed.append((.prop(.bird), ModelInstance(model: .translation(at) * .rotationY(heading) * .scale(0.6), phase: b * 0.7,
                                                           hex: SIMD2(Int32(blow.at.q), Int32(blow.at.r)), palette: pose)))
            }
        }
        return WorldStage.batches(placed)
    }
}

extension WorldStage {
    /// How far from a field's heart its barrow is raised, off the ground a
    /// company stands on, and how large it stands for the troops laid in it.
    public static let graveOffset: Float = 0.45
    public static func graveScale(troops: Int) -> Float {
        0.55 + 0.35 * min(Float(max(troops, 0)) / 12_000, 1)
    }

    /// Seconds a barrow the keeper sees raised takes to be heaped up, from
    /// bare ground to its full height, its stone set up at its head as it
    /// ends; while the lights of the dead laid in it rise and fade.
    public static let graveRaisingSeconds: Float = 3

    /// How far a barrow raised `age` seconds ago is heaped up: from nothing
    /// to whole, slow to start and slow to finish; whole at once where
    /// motion is reduced.
    public static func graveRaised(age: Float, still: Bool = false) -> Float {
        guard !still else { return 1 }
        let t = min(max(age / graveRaisingSeconds, 0), 1)
        return t * t * (3 - 2 * t)
    }

    /// Where a barrow raised on `hex` stands: beside the field's heart, off
    /// the ground a company stands on, on the land under it.
    public func gravePlace(_ hex: Hex) -> Vec3 {
        let centre = Relief.centre(of: hex)
        let bearing = WorldStage.phase(of: hex, salt: 83)
        let x = centre.x + WorldStage.graveOffset * Float(cos(Double(bearing)))
        let z = centre.z + WorldStage.graveOffset * Float(sin(Double(bearing)))
        return Vec3(x, ground(atX: x, z: z), z)
    }

    /// The barrows raised over fields of the dead: a low mound beside the
    /// field's heart, each turned its own way, the larger the more laid in
    /// it, with a standing stone at its head. One being raised (`raising`,
    /// how far, 0 to 1, by its hex) is heaped up from the ground as far as
    /// it has come, its top fresh earth, its stone set up over the last
    /// half of it.
    public func graves(_ graves: [(at: Hex, troops: Int)], raising: [Hex: Float] = [:]) -> [ModelBatch] {
        var placed: [(ModelKey, ModelInstance)] = []
        let mound = Library.model(.furnishing(.barrowMound)).mesh.bounds
        let stone = Library.model(.furnishing(.standingStone)).mesh.bounds
        for grave in graves {
            let at = gravePlace(grave.at)
            let bearing = WorldStage.phase(of: grave.at, salt: 83)
            let hex = SIMD2(Int32(grave.at.q), Int32(grave.at.r))
            let scale = WorldStage.graveScale(troops: grave.troops)
            let done = min(max(raising[grave.at] ?? 1, 0), 1)
            var heaped = ModelInstance(model: .translation(at) * .rotationY(bearing) * .scale(scale), hex: hex)
            if done < 1 { heaped.params.x = mound.min.y + done * (mound.max.y - mound.min.y) }
            placed.append((.furnishing(.barrowMound), heaped))
            // Its stone at its head, along the way it is turned, set up
            // once the mound is half heaped.
            let set = min(max(done * 2 - 1, 0), 1)
            guard set > 0 else { continue }
            let head = 0.32 * scale
            let sx = at.x + head * Float(sin(Double(bearing))), sz = at.z + head * Float(cos(Double(bearing)))
            var standing = ModelInstance(model: .translation(Vec3(sx, ground(atX: sx, z: sz), sz)) * .rotationY(bearing) * .scale(0.45), hex: hex)
            if set < 1 { standing.params.x = stone.min.y + set * (stone.max.y - stone.min.y) }
            placed.append((.furnishing(.standingStone), standing))
        }
        return WorldStage.batches(placed)
    }
}
