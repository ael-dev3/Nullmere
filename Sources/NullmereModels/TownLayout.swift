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

    /// The town's lots as they are taken: the well, the seat's stalls, the
    /// fields the granary works, and the homes from the keep outward. The
    /// fields' ground is kept whether worked or not, so no home stands
    /// where a field is to come.
    static func lots(_ plan: Plan, relief: Relief) -> [Lot] {
        let centre = Relief.centre(of: plan.hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let front = frontAngle(of: plan.hex)
        let land = land(of: plan.hex, relief: relief)
        let layout = HexLayout(size: 1)
        let angles = laneAngles(of: plan.hex)
        let (reserved, granary) = reservedSlots(plan, relief: relief)
        let hearts = plan.hex.neighbors.map { hex -> Vec3 in
            let c = Relief.centre(of: hex)
            return Vec3(c.x, 0, c.z)
        }
        let keep = Library.model(plan.heritage.map { ModelKey.keepOf($0, seat: plan.isSeat) } ?? .keep(seat: plan.isSeat)).mesh.bounds
        let keepClear = max(-keep.min.x, keep.max.x, -keep.min.z, keep.max.z) + 0.03
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
        func fits(_ p: Vec3, _ piece: Town) -> Bool {
            let footprint = piece.footprint
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
            if taken.contains(where: { ($0.position - p).length < footprint + $0.piece.footprint + 0.02 }) { return false }
            return points(around: p, radius: footprint).allSatisfy { land.contains(layout.hex(atX: Double($0.x), y: Double($0.z))) }
        }
        func take(_ piece: Town, at p: Vec3) -> Bool {
            guard fits(p, piece) else { return false }
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
        let walled = (plan.levels[.building(.walls)] ?? 0) > 0 || plan.rising?.work == .building(.walls)
        func way(_ angle: Float) -> Vec3 { Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle)))) }
        // How far out each lane runs: the gate's to the edge, a work's to its foot.
        var ends: [Int: Float] = [0: reach - 0.08]
        for (_, slot) in assign(plan, relief: relief) {
            let offset = slot.position - heart
            let turn = Float(atan2(Double(offset.z), Double(offset.x))) - angles[0]
            let index = (Int((turn / (2 * .pi / Float(lanes))).rounded()) % lanes + lanes) % lanes
            ends[index] = max(ends[index] ?? 0, offset.length - workRadius + 0.04)
        }
        var lines: [[Vec3]] = []
        for (index, end) in ends.sorted(by: { $0.key < $1.key }) {
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
}
