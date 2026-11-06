import Foundation
import NullmereCore

/// The town about a hold: its lanes, its well, its homes, its fields and,
/// at a seat, its market, filling the hold's land as its works rise.
///
/// Twelve lanes run out from the keep's door, one toward each of the works'
/// slots, and where the hold is walled a ring lane runs round outside its
/// walls from the gate; its townsfolk and carts keep to them, so nothing of
/// the town stands on them. Lanes are laid where they lead somewhere: out
/// through the gate, and to each work standing or rising. The homes stand
/// on the lots between, in the ward within the walls first and then out
/// beyond the works, each facing the lane nearest it. Nothing of the town
/// stands where a work stands or could, on the walls' ground whether they
/// are built or not, on the hearts of the hexes about the hold where
/// companies stand, or off the hold's land. The same hold always gives the
/// same town, and a home once standing stays as more are built.
extension HoldLayout {
    /// Lanes from the keep, one every twelfth of a turn from the gate's way.
    public static let lanes = 12
    /// Half a lane's width: nothing of the town stands nearer its line.
    public static let laneHalfWidth: Float = 0.06
    /// The ring lane round outside the walls, from the gate to the works.
    public static let ringLane: Float = 0.98
    /// Where the lanes begin, at the keep's door.
    public static let door: Float = 0.42
    /// How near the heart of a hex about the hold the town comes: a company
    /// standing there keeps its ground.
    static let heartClear: Float = 0.34
    /// The ward's lots end short of the walls' inner face.
    static let wardEdge: Float = 0.68
    /// The longest piece of lane laid in one.
    static let laneStep: Float = 0.3
    /// The fields a granary's levels work, at most.
    public static let fieldsMost = 3
    /// The stalls of a seat's market.
    public static let stalls = 3

    /// How many homes a hold has: a few about a bare keep, three more for
    /// every level of its works, more at a seat; at most 44, a seat's 64.
    /// Fewer stand where the land is short.
    public static func homes(_ plan: Plan) -> Int {
        let levels = plan.levels.values.reduce(0, +)
        return min(4 + 3 * levels + (plan.isSeat ? 6 : 0), plan.isSeat ? 64 : 44)
    }

    /// The fields a hold works: one for each level of its granary, to three.
    public static func fields(_ plan: Plan) -> Int {
        min(plan.levels[.building(.granary)] ?? 0, fieldsMost)
    }

    /// The ways the lanes run from the keep, radians from +x toward +z,
    /// the gate's first.
    public static func laneAngles(of hex: Hex) -> [Float] {
        let front = frontAngle(of: hex)
        return (0..<lanes).map { front + Float($0) * 2 * .pi / Float(lanes) }
    }

    /// The town of a hold as the rules keep it.
    public static func town(hold: Hold, relief: Relief, heritage: Heritage? = nil) -> [Piece] {
        town(Plan(hold: hold, heritage: heritage), relief: relief)
    }

    /// Its lanes, then its well, the seat's stalls, its fields and its homes.
    public static func town(_ plan: Plan, relief: Relief) -> [Piece] {
        var pieces = lanePieces(plan, relief: relief)
        let layout = HexLayout(size: 1)
        for lot in lots(plan, relief: relief) {
            let y = lowest(relief, around: lot.position, radius: lot.piece.footprint * 0.7)
            let at = Vec3(lot.position.x, y, lot.position.z)
            pieces.append(Piece(key: .town(lot.piece), transform: .translation(at) * .rotationY(lot.facing),
                                hex: layout.hex(atX: Double(at.x), y: Double(at.z))))
        }
        return pieces
    }

    // MARK: The lots

    /// A lot of the town: what stands on it, where on the ground plane,
    /// and the way it faces.
    struct Lot {
        var piece: Town
        var position: Vec3
        var facing: Float
    }

    /// The slots a work may ever stand in: when there are slots for every
    /// work the hold could raise, each work's own; otherwise every slot.
    /// And where the granary stands once all are raised.
    static func reservedSlots(_ plan: Plan, relief: Relief) -> (slots: [Slot], granary: Slot?) {
        let all = slots(plan, relief: relief)
        let possible = Work.order.filter { $0 != .building(.moonspire) || plan.isSeat }
        var full = plan
        full.levels = Dictionary(uniqueKeysWithValues: possible.map { ($0, 1) })
        full.rising = nil
        let assigned = assign(full, relief: relief)
        let granary = assigned.first { $0.0 == .building(.granary) }?.1
        guard all.count >= possible.count else { return (all, granary) }
        let used = Set(assigned.map(\.1.index))
        return (all.filter { used.contains($0.index) }, granary)
    }

    /// What the town keeps clear of about a hold: the keep, the lanes'
    /// lines, the ground a work may ever stand on, the hearts of the hexes
    /// about the hold where companies stand, the walls' ground and the edge
    /// of the hold's land.
    struct Ground {
        let heart: Vec3
        let angles: [Float]
        let reserved: [Slot]
        /// Where the granary stands once all are raised.
        let granary: Slot?
        let hearts: [Vec3]
        let keepClear: Float
        let land: Set<Hex>

        init(_ plan: Plan, relief: Relief) {
            let centre = Relief.centre(of: plan.hex)
            heart = Vec3(centre.x, 0, centre.z)
            angles = laneAngles(of: plan.hex)
            (reserved, granary) = reservedSlots(plan, relief: relief)
            hearts = plan.hex.neighbors.map { hex -> Vec3 in
                let c = Relief.centre(of: hex)
                return Vec3(c.x, 0, c.z)
            }
            let keep = Library.model(plan.heritage.map { ModelKey.keepOf($0, seat: plan.isSeat) } ?? .keep(seat: plan.isSeat)).mesh.bounds
            keepClear = max(-keep.min.x, keep.max.x, -keep.min.z, keep.max.z) + 0.03
            land = HoldLayout.land(of: plan.hex, relief: relief)
        }

        /// Whether something `footprint` about its middle at `p` stands
        /// clear of all of it.
        func clear(_ p: Vec3, footprint: Float) -> Bool {
            let offset = p - heart
            let r = (offset.x * offset.x + offset.z * offset.z).squareRoot()
            guard r - footprint >= keepClear, r + footprint <= reach - 0.02,
                  r + footprint <= wardEdge || r - footprint >= ringLane + laneHalfWidth else { return false }
            for angle in angles {
                let way = Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle))))
                let along = offset.dot(way)
                let off = along > 0 ? (offset - way * along).length : r
                if off < footprint + laneHalfWidth { return false }
            }
            if reserved.contains(where: { ($0.position - p).length < footprint + workRadius + 0.02 }) { return false }
            if hearts.contains(where: { ($0 - p).length < footprint + heartClear }) { return false }
            let layout = HexLayout(size: 1)
            return points(around: p, radius: footprint).allSatisfy { land.contains(layout.hex(atX: Double($0.x), y: Double($0.z))) }
        }
    }

    /// The town's lots as they are taken: the well, the seat's stalls, the
    /// fields the granary works, and the homes from the keep outward. The
    /// fields' ground is kept whether worked or not, so no home stands
    /// where a field is to come.
    static func lots(_ plan: Plan, relief: Relief) -> [Lot] {
        let ground = Ground(plan, relief: relief)
        let heart = ground.heart, angles = ground.angles, granary = ground.granary
        let front = frontAngle(of: plan.hex)
        var taken: [Lot] = []

        func polar(_ r: Float, _ angle: Float) -> Vec3 {
            heart + Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle)))) * r
        }
        /// The way a lot faces: toward the line of the lane nearest it.
        func facing(_ p: Vec3) -> Float {
            let offset = p - heart
            var best: (off: Float, toward: Vec3) = (.infinity, Vec3(0, 0, 1))
            for angle in angles {
                let way = Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle))))
                let along = offset.dot(way)
                guard along > 0 else { continue }
                let toward = way * along - offset
                if toward.length < best.off { best = (toward.length, toward) }
            }
            return Float(atan2(Double(best.toward.x), Double(best.toward.z)))
        }
        func take(_ piece: Town, at p: Vec3) -> Bool {
            guard !taken.contains(where: { ($0.position - p).length < piece.footprint + $0.piece.footprint + 0.02 }),
                  ground.clear(p, footprint: piece.footprint) else { return false }
            taken.append(Lot(piece: piece, position: p, facing: facing(p)))
            return true
        }
        let salt = { (a: Int, b: Int, c: UInt32) in
            Noise.unit(Int32(truncatingIfNeeded: plan.hex.q) &* 31 &+ Int32(a), Int32(truncatingIfNeeded: plan.hex.r) &* 17 &+ Int32(b), c)
        }

        // The well, in the ward beside the way to the gate.
        let step = Float.pi / 6
        for angle in [front + step / 2, front - step / 2, front + step * 1.5, front - step * 1.5] where take(.well, at: polar(0.55, angle)) {
            break
        }
        // A seat's market about the well.
        if plan.isSeat {
            var stood = 0
            for index in 0..<(lanes * 2) where stood < stalls {
                let angle = front + step / 2 + Float(index / 2 + 1) * step * (index % 2 == 0 ? 1 : -1)
                if take(.stall, at: polar(0.56, angle)) { stood += 1 }
            }
        }
        // The fields' ground, out at the edge, toward where the granary
        // stands or is to, else away from the gate.
        let toward = granary?.angle ?? front + .pi
        var fields = 0
        for index in 0..<90 where fields < fieldsMost {
            let angle = toward + Float((index + 1) / 2) * 0.07 * (index % 2 == 0 ? 1 : -1)
            for r in [Float(2.08), 1.95] where take(.field, at: polar(r, angle)) {
                fields += 1
                break
            }
        }
        // The homes, ring by ring from the keep outward, each way from the gate.
        var homes = 0
        let wanted = HoldLayout.homes(plan)
        for (ring, radius) in [Float(0.55), 1.08, 1.3, 1.52, 1.74, 1.94, 2.12, 2.26].enumerated() where homes < wanted {
            let spacing = 0.24 / radius
            let count = Int(2 * Float.pi / spacing)
            for index in 0..<count where homes < wanted {
                let k = Float((index + 1) / 2) * (index % 2 == 0 ? 1 : -1)
                let angle = front + spacing / 2 + k * spacing + (salt(ring, index, 0x70E5) - 0.5) * 0.3 * spacing
                let r = radius + (salt(ring, index, 0x70E6) - 0.5) * 0.05
                let roll = salt(ring, index, 0x70E7)
                let first: Town = radius < 1 ? (roll < 0.6 ? .townhouse : .cottage)
                    : roll < 0.4 ? .cottage : roll < 0.65 ? .longhouse : roll < 0.85 ? .roundhouse : .townhouse
                for piece in [first, .roundhouse] where take(piece, at: polar(r, angle)) {
                    homes += 1
                    break
                }
            }
        }
        // Drawn: all but the fields lying fallow, beyond those the granary works.
        let worked = HoldLayout.fields(plan)
        var fieldIndex = 0
        return taken.filter { lot in
            guard lot.piece == .field else { return true }
            fieldIndex += 1
            return fieldIndex <= worked
        }
    }

    // MARK: The lanes

    /// The lanes as laid: out through the gate to the hold's edge, to each
    /// work standing or rising, and round the walls where they stand; each
    /// in lengths of at most `laneStep`, lying along the ground.
    static func lanePieces(_ plan: Plan, relief: Relief) -> [Piece] {
        let centre = Relief.centre(of: plan.hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let angles = laneAngles(of: plan.hex)
        let walled = isWalled(plan)
        func way(_ angle: Float) -> Vec3 { Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle)))) }
        var lines: [[Vec3]] = []
        for (index, end) in laneEnds(plan, relief: relief).sorted(by: { $0.key < $1.key }) {
            // Within the walls only the way to the gate; the rest from the ring lane.
            let start = walled && index != 0 ? ringLane : door
            guard end > start + 0.05 else { continue }
            lines.append([heart + way(angles[index]) * start, heart + way(angles[index]) * end])
        }
        if walled {
            lines.append((0...24).map { heart + way(angles[0] + Float($0) * 2 * .pi / 24) * ringLane })
        }
        var pieces: [Piece] = []
        let layout = HexLayout(size: 1)
        for line in lines {
            for (a, b) in zip(line, line.dropFirst()) {
                let flat = b - a
                let count = max(Int((flat.length / laneStep).rounded(.up)), 1)
                for part in 0..<count {
                    var from = a + flat * (Float(part) / Float(count)), to = a + flat * (Float(part + 1) / Float(count))
                    from.y = relief.height(atX: from.x, z: from.z)
                    to.y = relief.height(atX: to.x, z: to.z)
                    let run = Vec3(to.x - from.x, 0, to.z - from.z).length
                    let mid = (from + to) * 0.5
                    let heading = Float(atan2(Double(-(to.z - from.z)), Double(to.x - from.x)))
                    let pitch = Float(atan2(Double(to.y - from.y), Double(run)))
                    let length = (to - from).length
                    pieces.append(Piece(key: .town(.lane),
                                        transform: .translation(mid) * .rotationY(heading) * .rotationZ(pitch) * .scale(Vec3(length, 1, 1)),
                                        hex: layout.hex(atX: Double(mid.x), y: Double(mid.z))))
                }
            }
        }
        return pieces
    }

    /// Whether the hold's walls stand, or are rising.
    static func isWalled(_ plan: Plan) -> Bool {
        (plan.levels[.building(.walls)] ?? 0) > 0 || plan.rising?.work == .building(.walls)
    }

    /// How far out each lane laid runs, by its place from the gate's: the
    /// gate's to the hold's edge, a work's to its foot.
    static func laneEnds(_ plan: Plan, relief: Relief) -> [Int: Float] {
        let centre = Relief.centre(of: plan.hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let front = frontAngle(of: plan.hex)
        var ends: [Int: Float] = [0: reach - 0.08]
        for (_, slot) in assign(plan, relief: relief) {
            let offset = slot.position - heart
            let turn = Float(atan2(Double(offset.z), Double(offset.x))) - front
            let index = (Int((turn / (2 * .pi / Float(lanes))).rounded()) % lanes + lanes) % lanes
            ends[index] = max(ends[index] ?? 0, offset.length - workRadius + 0.04)
        }
        return ends
    }

    // MARK: The strolls

    /// The most of a hold's folk out and about its lanes; a seat's.
    public static let strollsMost = 14
    public static let seatStrollsMost = 24
    /// One of the town's folk is out for every so many of its homes.
    public static let homesPerStroll = 2
    /// How far to one side of a lane's line its folk keep, the one way or
    /// the other, so those going out and those coming back pass.
    public static let keepSide: Float = 0.03
    /// How far out along the way to the gate the market by the keep's door
    /// runs, where folk set out from.
    public static let marketReach: Float = 0.12

    /// The ways the town's folk walk out and about its lanes, on the ground
    /// plane: one for every two of its homes, to the most a hold or a
    /// seat has, each there and back along the lanes, keeping to one side
    /// of them. One in four goes from the market by the keep's door out
    /// along the way to the gate, through it where the hold is walled, as
    /// far as their errand takes them short of the ground beyond where
    /// companies stand; the rest go to the feet of the works in turn, from
    /// the keep's door, or where the hold is walled from along the ring lane
    /// outside its walls, round it.
    public static func strolls(_ plan: Plan, relief: Relief) -> [[Vec3]] {
        let centre = Relief.centre(of: plan.hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let angles = laneAngles(of: plan.hex)
        let walled = isWalled(plan)
        let ends = laneEnds(plan, relief: relief)
        let homes = lots(plan, relief: relief).filter { Town.homes.contains($0.piece) }.count
        let count = min(homes / homesPerStroll, plan.isSeat ? seatStrollsMost : strollsMost)
        func way(_ angle: Float) -> Vec3 { Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle)))) }
        let gate = way(angles[0])
        // Out through the gate as far as short of the heart of the hex
        // before it, where a company may stand, and of any work on the way.
        var farthest = ends[0] ?? reach
        for hex in plan.hex.neighbors {
            let c = Relief.centre(of: hex)
            let offset = Vec3(c.x, 0, c.z) - heart, along = offset.dot(gate)
            if along > 0, (offset - gate * along).length < heartClear { farthest = min(farthest, along - heartClear - 0.05) }
        }
        for (_, slot) in assign(plan, relief: relief) {
            let offset = Vec3(slot.position.x, 0, slot.position.z) - heart, along = offset.dot(gate)
            if along > 0, (offset - gate * along).length < workRadius { farthest = min(farthest, along - workRadius - 0.05) }
        }
        let nearest = walled ? ringLane : door + 0.3
        let works = ends.keys.filter { $0 != 0 }.sorted()
        var strolls: [[Vec3]] = []
        // How many are out on each lane: those on the same lane keep to its
        // sides in turn.
        var out: [Int: Int] = [:]
        for k in 0..<count {
            let roll = { (salt: UInt32) in
                Noise.unit(Int32(truncatingIfNeeded: plan.hex.q) &* 13 &+ Int32(k), Int32(truncatingIfNeeded: plan.hex.r), salt)
            }
            var path: [Vec3]
            let lane = k % 4 == 0 || works.isEmpty ? 0 : works[(k - k / 4 - 1) % works.count]
            if lane == 0 {
                path = [heart + gate * (door + marketReach * roll(0x5702)), heart + gate * (nearest + max(farthest - nearest, 0) * roll(0x5701))]
            } else {
                let end = ends[lane] ?? ringLane, toward = way(angles[lane])
                if walled {
                    // From a way along the ring, the one way round or the other.
                    let turn = (Float.pi / 6 + Float.pi / 2 * roll(0x5703)) * (k % 2 == 0 ? 1 : -1)
                    let steps = Int((abs(turn) / (Float.pi / 12)).rounded(.up))
                    path = (0...steps).map { heart + way(angles[lane] - turn + turn * Float($0) / Float(steps)) * ringLane }
                    if end > ringLane + 1e-3 { path.append(heart + toward * end) }
                } else {
                    path = [heart + toward * door, heart + toward * end]
                }
            }
            strolls.append(keeping((out[lane] ?? 0) % 2 == 0 ? keepSide : -keepSide, to: path))
            out[lane, default: 0] += 1
        }
        return strolls
    }

    // MARK: The gatherings

    /// One of the town's folk standing where its life gathers: who they
    /// are, where on the ground plane, and the way they face.
    public struct Gathered: Equatable, Sendable {
        public var key: ModelKey
        public var position: Vec3
        public var facing: Float
    }

    /// Half the ground one of the town's folk takes, standing.
    public static let standing: Float = 0.025
    /// How far beyond what they stand at the gathered keep.
    static let standOff: Float = 0.004
    /// The well's ring of stone about its middle, and a stall's counter
    /// (half its length, half its depth) and awning (half its length), as
    /// made (Art/blender/town.py).
    static let wellRing: Float = 0.042
    static let counter = (half: Float(0.05), depth: Float(0.028)), awning: Float = 0.06
    /// The most of the town's folk at its well: two drawing water, and one
    /// more for every so many of its homes.
    public static let wellMost = 4
    public static let homesPerWellFolk = 12
    /// The folk at each of a seat's stalls besides its stallholder.
    public static let stallFolk = 2

    /// The town's folk gathered where its life is, standing about what
    /// they gathered at and facing it: two water-carriers crouched at the
    /// well's rim drawing water, and more of the town's folk there for
    /// every twelve of its homes, to four; at a seat, a stallholder behind
    /// each stall's counter and two of the market's folk at its ends. Each
    /// stands clear of the lanes, where the town's folk walk, of every work,
    /// of every lot but the one it stands at, of the companies' ground and
    /// of each other; where there is no room, fewer gather. The same town
    /// always gathers the same folk in the same places.
    public static func gatherings(_ plan: Plan, relief: Relief) -> [Gathered] {
        let ground = Ground(plan, relief: relief)
        let lots = lots(plan, relief: relief)
        let homes = lots.filter { Town.homes.contains($0.piece) }.count
        var gathered: [Gathered] = []
        func roll(_ k: Int, _ salt: UInt32) -> Float {
            Noise.unit(Int32(truncatingIfNeeded: plan.hex.q) &* 19 &+ Int32(k), Int32(truncatingIfNeeded: plan.hex.r), salt)
        }
        /// One of the folk stood `away` from a lot's middle at `angle` from
        /// the way it faces, facing its middle, if there is room for them.
        func stand(_ key: ModelKey, at lot: Lot, away: Float, angle: Float) -> Bool {
            let heading = lot.facing + angle
            let p = lot.position + Vec3(Float(sin(Double(heading))), 0, Float(cos(Double(heading)))) * away
            guard ground.clear(p, footprint: standing),
                  !lots.contains(where: { $0.position != lot.position && ($0.position - p).length < $0.piece.footprint + standing }),
                  !gathered.contains(where: { ($0.position - p).length < 2 * standing }) else { return false }
            gathered.append(Gathered(key: key, position: p, facing: heading + .pi))
            return true
        }
        // At the well's rim, round it from a way of its own.
        if let well = lots.first(where: { $0.piece == .well }) {
            let count = min(2 + homes / homesPerWellFolk, wellMost)
            let start = roll(0, 0x3E11) * 2 * .pi
            var stood = 0
            for index in 0..<12 where stood < count {
                let key: ModelKey = stood < 2 ? .folk(variant: Folk.waterCarrier) : .folk(ofHome: roll(stood, 0x3E12))
                if stand(key, at: well, away: wellRing + standing + standOff, angle: start + Float(index) * .pi / 6) { stood += 1 }
            }
        }
        // At each stall: its holder behind the counter, its folk at its ends.
        for (index, stall) in lots.filter({ $0.piece == .stall }).enumerated() {
            _ = stand(.folk(variant: Folk.householder), at: stall, away: counter.depth + standing + standOff, angle: .pi)
            var stood = 0
            let ends: [Float] = [.pi / 2, -.pi / 2, 1.2, -1.2, 1.95, -1.95]
            for angle in ends where stood < stallFolk {
                if stand(.folk(ofHome: roll(index * 8 + stood, 0x3E13)), at: stall, away: awning + standing + standOff, angle: angle) { stood += 1 }
            }
        }
        return gathered
    }

    /// A way kept to one side of its lanes: each point of it moved `side`
    /// across the way's course there.
    static func keeping(_ side: Float, to path: [Vec3]) -> [Vec3] {
        path.indices.map { index in
            let a = path[max(index - 1, 0)], b = path[min(index + 1, path.count - 1)]
            let run = Vec3(b.x - a.x, 0, b.z - a.z), length = run.length
            guard length > 1e-5 else { return path[index] }
            return path[index] + Vec3(-run.z, 0, run.x) * (side / length)
        }
    }
}
