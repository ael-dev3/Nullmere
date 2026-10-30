import Foundation
import NullmereCore

/// Where a hold's keep, walls and works stand. The keep stands on the
/// hold's heart and its walls ring it within the hex, the gate toward the
/// lake's heart; the works stand round them on the hold's land neighbours,
/// each facing the keep, in a slot of their own. A work being raised is
/// drawn rising inside a scaffold.
public enum HoldLayout {
    /// A work stands within this radius of its foot.
    public static let workRadius: Float = 0.33
    /// The ring of slots round the keep, twelve to it: six toward the
    /// neighbours' hearts and six between them.
    public static let innerRing: Float = 1.3
    /// Six more beyond, toward the neighbours' far sides, used when the
    /// inner ring is short of land.
    public static let outerRing: Float = 2.05
    /// How far from its heart a hold's pieces can reach.
    public static let reach: Float = outerRing + workRadius

    /// A work a hold can raise beside its keep.
    public enum Work: Hashable, Sendable {
        case building(BuildingKind)
        /// Where its scholars study.
        case study

        public func key(level: Int) -> ModelKey {
            switch self {
            case .building(.walls): return .walls(level: level)
            case .building(let kind): return .work(kind, level: level)
            case .study: return .study(level: level)
            }
        }

        /// The order slots are given in: the great work first, then the
        /// muster hall by the gate, the beacon on the heights, the study,
        /// and the works that draw on the land, each toward its own ground.
        static let order: [Work] = [.building(.moonspire), .building(.musterHall), .building(.beacon), .study,
                                    .building(.granary), .building(.sawpit), .building(.quarry), .building(.saltworks)]
    }

    /// What a hold has, for its pieces to be laid out.
    public struct Plan: Sendable, Equatable {
        public struct Rising: Sendable, Equatable {
            public var work: Work
            /// The level it rises to.
            public var level: Int
            /// How far along, 0 to 1.
            public var progress: Float

            public init(work: Work, level: Int, progress: Float) {
                self.work = work
                self.level = level
                self.progress = progress
            }
        }

        public var hex: Hex
        public var isSeat: Bool
        /// Each work that stands, walls among them, at its level.
        public var levels: [Work: Int]
        public var rising: Rising?

        public init(hex: Hex, isSeat: Bool, levels: [Work: Int] = [:], rising: Rising? = nil) {
            self.hex = hex
            self.isSeat = isSeat
            self.levels = levels
            self.rising = rising
        }

        /// A hold as the rules keep it: its works, its project with how far
        /// along it is (from the watches left unless `progress` is given),
        /// and its study's level, which the rules do not yet keep.
        public init(hold: Hold, study: Int = 0, progress: Float? = nil) {
            var levels: [Work: Int] = [:]
            for (kind, level) in hold.levels where level > 0 {
                levels[.building(kind)] = level
            }
            if study > 0 {
                levels[.study] = study
            }
            var rising: Rising?
            if let project = hold.project {
                let watches = Float(project.kind.buildWatches(toLevel: project.targetLevel))
                let done = progress ?? (1 - Float(project.watchesLeft) / max(watches, 1))
                rising = Rising(work: .building(project.kind), level: project.targetLevel, progress: min(max(done, 0), 1))
            }
            self.init(hex: hold.position, isSeat: hold.isSeat, levels: levels, rising: rising)
        }
    }

    /// The pieces of a hold as the rules keep it.
    public static func pieces(hold: Hold, relief: Relief, study: Int = 0, progress: Float? = nil) -> [Piece] {
        pieces(Plan(hold: hold, study: study, progress: progress), relief: relief)
    }

    /// The keep, the walls and every work, each on the land.
    public static func pieces(_ plan: Plan, relief: Relief) -> [Piece] {
        let centre = Relief.centre(of: plan.hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let front = frontAngle(of: plan.hex)
        let turn = Float.pi / 2 - front
        var pieces: [Piece] = []
        // The keep, on the lowest of the ground under it.
        let keepY = lowest(relief, around: heart, radius: 0.3)
        pieces.append(Piece(key: .keep(seat: plan.isSeat), transform: .translation(Vec3(heart.x, keepY, heart.z)) * .rotationY(turn),
                            hex: plan.hex))
        // The walls, at the ring's mean height, their footings reaching below its lowest.
        let wallsLevel = plan.levels[.building(.walls)] ?? 0
        let risingWalls = plan.rising.flatMap { $0.work == .building(.walls) ? $0 : nil }
        if wallsLevel > 0 || risingWalls != nil {
            let level = risingWalls?.level ?? wallsLevel
            let progress = risingWalls.map { shown(.building(.walls), from: wallsLevel, to: $0.level, progress: $0.progress) } ?? 1
            pieces.append(Piece(key: .walls(level: level), transform: .translation(Vec3(heart.x, wallsHeight(relief, at: heart), heart.z))
                                * .rotationY(turn), hex: plan.hex, progress: progress))
        }
        // The works in their slots.
        for (work, slot) in assign(plan, relief: relief) {
            let standing = plan.levels[work] ?? 0
            let rising = plan.rising.flatMap { $0.work == work ? $0 : nil }
            let level = rising?.level ?? standing
            let y = lowest(relief, around: slot.position, radius: workRadius * 0.9)
            let at = Vec3(slot.position.x, y, slot.position.z)
            // Facing the keep.
            let facing = Mat4.rotationY(-Float.pi / 2 - slot.angle)
            let hex = HexLayout(size: 1).hex(atX: Double(at.x), y: Double(at.z))
            let key = work.key(level: level)
            if let rising {
                let progress = shown(work, from: standing, to: rising.level, progress: rising.progress)
                pieces.append(Piece(key: key, transform: .translation(at) * facing, hex: hex, progress: progress))
                let height = Library.model(key).mesh.bounds.max.y
                let tall = max(height * min(progress + 0.12, 1), 0.2)
                pieces.append(Piece(key: .scaffold, transform: .translation(at) * facing * .scale(Vec3(scaffoldWidth, tall, scaffoldWidth)),
                                    hex: hex))
            } else {
                pieces.append(Piece(key: key, transform: .translation(at) * facing, hex: hex))
            }
        }
        return pieces
    }

    /// A scaffold's width and depth: a square within a work's slot.
    public static let scaffoldWidth: Float = 0.46

    /// How much of a rising work to draw: an upgrade starts from the height
    /// of the level it stands at.
    static func shown(_ work: Work, from standing: Int, to level: Int, progress: Float) -> Float {
        let new = Library.model(work.key(level: level)).mesh.bounds
        var start: Float = 0
        if standing > 0 {
            let old = Library.model(work.key(level: standing)).mesh.bounds
            start = min(max((old.max.y - new.min.y) / max(new.max.y - new.min.y, 1e-3), 0), 1)
        }
        return start + (1 - start) * min(max(progress, 0), 1)
    }

    // MARK: The lie of the hold

    /// The direction its gate faces: toward the neighbour nearest the way
    /// to the lake's heart, radians from +x toward +z.
    public static func frontAngle(of hex: Hex) -> Float {
        let centre = Relief.centre(of: hex)
        var best: (angle: Float, score: Float) = (0, -.infinity)
        for index in 0..<6 {
            let angle = Float(index) * .pi / 3
            let score = -(Float(cos(Double(angle))) * centre.x + Float(sin(Double(angle))) * centre.z)
            if score > best.score + 1e-4 {
                best = (angle, score)
            }
        }
        return best.angle
    }

    /// Whether works may stand on a hex: land of the map, neither water
    /// nor the Spine.
    static func isLand(_ hex: Hex, _ relief: Relief) -> Bool {
        guard let tile = relief.map[hex] else { return false }
        return tile.terrain.isPassable && !tile.terrain.isWater
    }

    /// The hold's hex and its land neighbours.
    public static func land(of hex: Hex, relief: Relief) -> Set<Hex> {
        Set([hex] + hex.neighbors.filter { isLand($0, relief) })
    }

    static func points(around centre: Vec3, radius: Float, count: Int = 8) -> [Vec3] {
        [centre] + (0..<count).map { centre + MeshBuilder.ring(radius, 0, Float($0) * 2 * .pi / Float(count)) }
    }

    /// The lowest ground under a footprint, for a piece to stand on without
    /// floating.
    static func lowest(_ relief: Relief, around centre: Vec3, radius: Float) -> Float {
        points(around: centre, radius: radius).map { relief.height(atX: $0.x, z: $0.z) }.min() ?? 0
    }

    static func wallsHeight(_ relief: Relief, at heart: Vec3) -> Float {
        let ring = points(around: heart, radius: Holds.wallRadius, count: 12).dropFirst()
        return ring.map { relief.height(atX: $0.x, z: $0.z) }.reduce(0, +) / Float(ring.count)
    }

    struct Slot {
        var index: Int
        var angle: Float
        var position: Vec3
        var inner: Bool
    }

    /// Every slot round a hold whose ground is all the hold's land.
    static func slots(_ plan: Plan, relief: Relief) -> [Slot] {
        let centre = Relief.centre(of: plan.hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let front = frontAngle(of: plan.hex)
        let land = land(of: plan.hex, relief: relief)
        let layout = HexLayout(size: 1)
        var slots: [Slot] = []
        let rings: [(radius: Float, count: Int, inner: Bool)] = [(innerRing, 12, true), (outerRing, 6, false)]
        for ring in rings {
            for step in 0..<ring.count {
                let angle = front + Float(step) * 2 * .pi / Float(ring.count)
                let position = heart + Vec3(Float(cos(Double(angle))), 0, Float(sin(Double(angle)))) * ring.radius
                let ground = points(around: position, radius: workRadius).map { layout.hex(atX: Double($0.x), y: Double($0.z)) }
                if ground.allSatisfy(land.contains) {
                    slots.append(Slot(index: slots.count, angle: angle, position: position, inner: ring.inner))
                }
            }
        }
        return slots
    }

    /// Each work's slot. When there are slots for every work the hold could
    /// raise, each is kept for its work whether raised or not, so a work
    /// never moves when another is built; otherwise those standing share
    /// what there is, in `Work.order`.
    static func assign(_ plan: Plan, relief: Relief) -> [(Work, Slot)] {
        let slots = slots(plan, relief: relief)
        let possible = Work.order.filter { $0 != .building(.moonspire) || plan.isSeat }
        let present = Set(plan.levels.filter { $0.value > 0 }.map(\.key) + (plan.rising.map { [$0.work] } ?? []))
        let wanted = slots.count >= possible.count ? possible : possible.filter(present.contains)
        let front = frontAngle(of: plan.hex)
        var free = slots
        var assigned: [(Work, Slot)] = []
        for work in wanted {
            guard let best = free.max(by: { score(work, $0, front, relief) < score(work, $1, front, relief) }) else { break }
            free.removeAll { $0.index == best.index }
            if present.contains(work) {
                assigned.append((work, best))
            }
        }
        return assigned
    }

    /// How well a slot suits a work; the higher the better, the earlier
    /// slot winning a tie.
    static func score(_ work: Work, _ slot: Slot, _ front: Float, _ relief: Relief) -> Float {
        // How far round from the gate, 0 to π.
        var around = abs(slot.angle - front).truncatingRemainder(dividingBy: 2 * .pi)
        if around > .pi { around = 2 * .pi - around }
        let hex = HexLayout(size: 1).hex(atX: Double(slot.position.x), y: Double(slot.position.z))
        let tile = relief.map[hex]
        var score: Float = slot.inner ? 100 : 0
        score -= Float(slot.index) * 0.001
        switch work {
        case .building(.musterHall): score += 10 - around
        case .building(.moonspire): score += around
        case .building(.beacon): score += 4 * relief.height(atX: slot.position.x, z: slot.position.z) + around * 0.1
        case .study: score += 10 - abs(around - 2.5)
        case .building(let kind):
            score += affinity(kind, tile) * 10 + around * 0.2
        }
        return score
    }

    /// How much a work that draws on the land likes the ground it stands on.
    static func affinity(_ kind: BuildingKind, _ tile: Tile?) -> Float {
        guard let tile else { return 0 }
        switch kind {
        case .granary:
            return (tile.terrain == .greyfield ? 1 : 0) + (tile.feature == .darkLoam ? 1 : 0) + (tile.terrain == .strand ? 0.3 : 0)
        case .sawpit:
            return (tile.terrain == .blackwood ? 1 : 0) + (tile.feature == .elderGrove ? 1 : 0)
        case .quarry:
            return (tile.terrain == .barrow ? 1 : 0) + (tile.feature == .stoneSeam ? 1 : 0)
        case .saltworks:
            return (tile.terrain == .saltFlat ? 1 : 0) + (tile.feature == .moonsaltBed ? 1 : 0) + (tile.terrain == .strand ? 0.3 : 0)
        default:
            return 0
        }
    }
}
