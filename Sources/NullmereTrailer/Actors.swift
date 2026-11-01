import Foundation
import NullmereCore
import NullmereModels
import NullmereWorld

/// The ground along a run of hexes: their hearts, one after another.
struct Run: Sendable {
    let points: [Vec3]
    let lengths: [Float]

    init(_ points: [Vec3]) {
        self.points = points
        var lengths: [Float] = [0]
        for index in points.indices.dropFirst() {
            let a = points[index - 1], b = points[index]
            lengths.append(lengths[index - 1] + Vec3(b.x - a.x, 0, b.z - a.z).length)
        }
        self.lengths = lengths
    }

    var length: Float { lengths.last ?? 0 }

    /// Where along it a distance lies, on the map's floor, and which way
    /// along it is: before its start or past its end, on along its first
    /// or last stretch.
    func point(at distance: Float) -> (x: Float, z: Float, along: Vec3) {
        guard points.count > 1 else { return (points.first?.x ?? 0, points.first?.z ?? 0, Vec3(0, 0, 1)) }
        var stretch = 0
        while stretch < points.count - 2, lengths[stretch + 1] < distance { stretch += 1 }
        let a = points[stretch], b = points[stretch + 1]
        let span = max(lengths[stretch + 1] - lengths[stretch], 1e-4)
        let f = (distance - lengths[stretch]) / span
        let along = Vec3(b.x - a.x, 0, b.z - a.z).normalized
        return (a.x + (b.x - a.x) * f, a.z + (b.z - a.z) * f, along)
    }
}

/// Which way a company faces to look along a direction on the map.
func facing(_ direction: Vec3) -> Float {
    Float(atan2(Double(direction.x), Double(direction.z)))
}

/// A host on the march: a column of a House's companies along a straight
/// run of open land near the trailer's heart, commanders riding at the
/// head of two, the dust of the march about them.
public struct March: Sendable {
    let run: Run
    let column: [(kind: UnitKind, tier: Int, commander: Int?)]
    let sigil: Int
    let heritage: Heritage
    let owner: Int
    let heights: [Float]
    /// Units a company covers in a second, and the room each takes.
    static let pace: Float = 0.5
    static let spacing: Float = 1.2
    /// How far along the run the head stands as the march is first seen.
    let opening: Float

    init(world: TrailerWorld) {
        let seat = world.seat
        // The longest straight run of open ground from a hex near the seat.
        var best: [Hex] = []
        for hex in seat.position.spiral(6) where world.isOpen(hex) {
            for direction in 0..<6 {
                var line = [hex]
                var next = hex
                while line.count < 12 {
                    next = next.neighbors[direction]
                    guard world.isOpen(next) else { break }
                    line.append(next)
                }
                if line.count > best.count { best = line }
            }
        }
        if best.count < 2 { best = [seat.position, seat.position.neighbors[0]] }
        let points = best.map { world.ground($0) }
        run = Run(points)
        heights = points.map(\.y)
        column = [(.rider, 4, 2), (.spear, 4, nil), (.spear, 3, nil), (.bow, 3, nil), (.spear, 4, 5), (.bow, 2, nil), (.mangonel, 2, nil)]
        owner = seat.owner
        sigil = world.state.houses[seat.owner].sigil
        heritage = world.state.heritage(of: seat.owner)
        // The column's tail at the run's start as it is first seen, its
        // head as far on as the column is long.
        opening = min(March.spacing * Float(column.count - 1), max(run.length - March.pace * 12, 0))
    }

    /// Where the head of the column is, seconds into its shot.
    public func head(at elapsed: Double) -> Vec3 {
        let p = run.point(at: opening + March.pace * Float(elapsed))
        return Vec3(p.x, 0, p.z)
    }

    /// The camera's heading to watch the column pass across the view.
    public var sideHeading: Double {
        let along = run.point(at: run.length / 2).along
        return Double(facing(Vec3(-along.z, 0, along.x)))
    }

    func stage(at elapsed: Double, in world: TrailerWorld, poses: inout [CompanyPose], happenings: inout Happenings) {
        let e = Float(elapsed)
        for (index, company) in column.enumerated() {
            let p = run.point(at: opening + March.pace * e - March.spacing * Float(index))
            let ground = world.ground(x: p.x, z: p.z)
            let key = ModelKey.company(company.kind, tier: company.tier, heritage: heritage)
            poses.append(CompanyPose(unit: 9_000 + index, key: key, sigil: sigil, health: 100,
                                     hex: HexLayout(size: 1).hex(atX: Double(p.x), y: Double(p.z)), position: ground,
                                     heading: facing(p.along), clip: .march, clipTime: e * 2.2 + Float(index) * 0.13, isOwn: true,
                                     commander: company.commander, muster: 1_400))
            happenings.marching.append(Happenings.Spot(at: ground, strength: 0.7, seed: UInt32(31 + index)))
        }
    }
}

/// A battle in the dark: two Houses' lines met on open ground between their
/// seats, blows traded along the front, volleys from the bows behind,
/// commanders' skills bursting, companies falling, and a hold of the far
/// side burning beyond.
public struct Battle: Sendable {
    public struct Company: Sendable {
        let kind: UnitKind
        let tier: Int
        let side: Int
        let place: Vec3
        let commander: Int?
        /// When it falls, seconds into the battle.
        let falls: Double?
        /// Whom it strikes, by index, and the first blow and the time between.
        let foe: Int?
        let first: Double
        let every: Double
    }

    /// The field's heart, and the way from the first side toward the other.
    public let centre: Vec3
    let toward: Vec3
    let companies: [Company]
    let sigils: [Int]
    let heritages: [Heritage]
    /// The far side's hold burning beyond the field, if one stands near.
    let blaze: Vec3?
    /// Commanders' skills: when, from which company, and how they look.
    let furies: [(time: Double, company: Int, look: FuryLook)]
    /// How long its blows are thrown, in seconds.
    public static let length = 16.0

    init(world: TrailerWorld) {
        let heart = world.seat, far = world.rising
        let a = world.ground(heart.position), b = world.ground(far.position)
        var toward = Vec3(b.x - a.x, 0, b.z - a.z).normalized
        if !toward.x.isFinite || toward.length < 0.5 { toward = Vec3(1, 0, 0) }
        // Open ground between the two seats, as much of it about as can be found.
        func openness(_ hex: Hex) -> Int { hex.spiral(2).filter { world.isOpen($0) }.count }
        let line = heart.position.line(to: far.position)
        let candidates = (line.count > 4 ? Array(line[2..<(line.count - 2)]) : line) + heart.position.spiral(7)
        let field = candidates.filter { world.isOpen($0) && $0.distance(to: heart.position) >= 3 }
            .max { (openness($0), -$0.distance(to: heart.position)) < (openness($1), -$1.distance(to: heart.position)) } ?? heart.position
        let centre = world.ground(field)
        self.centre = Vec3(centre.x, 0, centre.z)
        self.toward = toward
        let across = Vec3(-toward.z, 0, toward.x)
        func place(_ forward: Float, _ side: Float) -> Vec3 {
            Vec3(centre.x + toward.x * forward + across.x * side, 0, centre.z + toward.z * forward + across.z * side)
        }
        var companies: [Company] = []
        let falls: [Int: Double] = [6: 7.4, 8: 10.1, 4: 12.6]
        // The fronts: five companies a side, face to face.
        for side in 0..<2 {
            let forward: Float = side == 0 ? -0.75 : 0.75
            for k in 0..<5 {
                let index = side * 5 + k
                let kind: UnitKind = k == 2 ? .rider : .spear
                companies.append(Company(kind: kind, tier: side == 0 ? 4 : 3, side: side, place: place(forward, Float(k - 2) * 1.25),
                                         commander: k == 2 ? (side == 0 ? 2 : 6) : nil, falls: falls[index], foe: (1 - side) * 5 + k,
                                         first: 0.5 + Double(k) * 0.31 + Double(side) * 0.85, every: side == 0 ? 1.9 : 2.1))
            }
        }
        // The bows behind each front, loosing over it.
        for side in 0..<2 {
            let forward: Float = side == 0 ? -2.4 : 2.4
            for k in 0..<3 {
                companies.append(Company(kind: .bow, tier: 3, side: side, place: place(forward, Float(k - 1) * 1.7), commander: nil,
                                         falls: nil, foe: (1 - side) * 5 + 1 + k, first: 1.2 + Double(k) * 0.5 + Double(side) * 1.1, every: 3.2))
            }
        }
        self.companies = companies
        sigils = [world.state.houses[heart.owner].sigil, world.state.houses[far.owner].sigil]
        heritages = [world.state.heritage(of: heart.owner), world.state.heritage(of: far.owner)]
        // The far side's hold nearest the field, if it is near enough to be seen burning.
        let theirs = world.state.holds(of: far.owner).filter { $0.position.distance(to: field) <= 6 }
        blaze = theirs.min { ($0.position.distance(to: field), $0.id) < ($1.position.distance(to: field), $1.id) }.map { world.ground($0.position) }
        furies = [(3.6, 2, .blaze), (8.6, 7, .quake), (11.8, 0, .volley), (13.6, 12, .ward)]
    }

    /// The camera's heading to look across the fronts from behind the first side.
    public var sideHeading: Double { Double(facing(Vec3(-toward.x, 0, -toward.z))) }

    /// The blows a company throws, by when each begins.
    func blows(of company: Company, until elapsed: Double) -> [Double] {
        guard company.foe != nil else { return [] }
        var times: [Double] = []
        var t = company.first
        while t <= elapsed {
            if let falls = company.falls, t >= falls { break }
            if let foe = company.foe, let theirs = companies[foe].falls, t >= theirs, company.kind != .bow { break }
            times.append(t)
            t += company.every
        }
        return times
    }

    func ground(_ place: Vec3, in world: TrailerWorld) -> Vec3 { world.ground(x: place.x, z: place.z) }

    func stage(at elapsed: Double, in world: TrailerWorld, poses: inout [CompanyPose], arrows: inout [ArrowFlight],
               happenings: inout Happenings) {
        let layout = HexLayout(size: 1)
        for (index, company) in companies.enumerated() {
            var position = ground(company.place, in: world)
            let facingFoe = company.side == 0 ? toward : Vec3(-toward.x, 0, -toward.z)
            var clip = Clip.idle
            var clipTime = Float(elapsed) + Float(index) * 0.7
            var opacity: Float = 1
            if let falls = company.falls, elapsed >= falls {
                clip = .death
                clipTime = Float(elapsed - falls)
                opacity = 1
                if elapsed - falls < 2 {
                    happenings.falls.append(Happenings.Spot(at: position, start: Float(falls), seed: UInt32(400 + index)))
                }
            } else if let last = blows(of: company, until: elapsed).last, elapsed - last < Double(Clip.attack.period) {
                clip = .attack
                clipTime = Float(elapsed - last)
                if company.kind != .bow, let foe = company.foe {
                    let theirs = ground(companies[foe].place, in: world)
                    let lean = Float(sin(Double.pi * (elapsed - last) / Double(Clip.attack.period))) * 0.32
                    position = Vec3(position.x + (theirs.x - position.x) * lean, position.y, position.z + (theirs.z - position.z) * lean)
                }
            }
            poses.append(CompanyPose(unit: 9_100 + index, key: .company(company.kind, tier: company.tier, heritage: heritages[company.side]),
                                     sigil: sigils[company.side], health: 100,
                                     hex: layout.hex(atX: Double(position.x), y: Double(position.z)), position: position,
                                     heading: facing(facingFoe), clip: clip, clipTime: clipTime, opacity: opacity,
                                     isOwn: company.side == 0, commander: company.commander, muster: company.kind == .bow ? 900 : 1_600))
            // Its blows as they land, and its arrows in flight.
            guard let foe = company.foe else { continue }
            let mark = ground(companies[foe].place, in: world)
            for blow in blows(of: company, until: elapsed) where elapsed - blow < 1.6 {
                let seed = UInt32(index * 97 + Int(blow * 10))
                if company.kind == .bow {
                    let flight = (elapsed - blow) / 1.1
                    for arrow in 0..<6 {
                        let spread = Vec3(Float(arrow % 3 - 1) * 0.28, 0, Float(arrow / 3) * 0.3 - 0.15)
                        let from = Vec3(position.x + spread.x * 0.5, position.y + 0.3, position.z + spread.z * 0.5)
                        arrows.append(ArrowFlight(from: from, to: Vec3(mark.x + spread.x, mark.y + 0.1, mark.z + spread.z),
                                                  progress: Float(flight - Double(arrow) * 0.04)))
                    }
                    happenings.strikes.append(Happenings.Strike(from: position, at: mark, start: Float(blow + 0.9), ranged: true, seed: seed))
                } else {
                    happenings.strikes.append(Happenings.Strike(from: position, at: mark, start: Float(blow), ranged: false, seed: seed))
                }
            }
        }
        for fury in furies where elapsed >= fury.time && elapsed - fury.time < 3 {
            happenings.furies.append(Happenings.Fury(at: ground(companies[fury.company].place, in: world), start: Float(fury.time),
                                                     look: fury.look, seed: UInt32(700 + fury.company)))
        }
        if let blaze { happenings.blazes.append(Happenings.Spot(at: blaze, strength: 0.9, seed: 77)) }
    }

    /// The field after the battle: the fallen lying still, the living
    /// standing, the far hold still burning.
    func after(at elapsed: Double, in world: TrailerWorld, poses: inout [CompanyPose], happenings: inout Happenings) {
        let layout = HexLayout(size: 1)
        for (index, company) in companies.enumerated() {
            let position = ground(company.place, in: world)
            let fallen = company.falls != nil
            let facingFoe = company.side == 0 ? toward : Vec3(-toward.x, 0, -toward.z)
            poses.append(CompanyPose(unit: 9_100 + index, key: .company(company.kind, tier: company.tier, heritage: heritages[company.side]),
                                     sigil: sigils[company.side], health: 100,
                                     hex: layout.hex(atX: Double(position.x), y: Double(position.z)), position: position,
                                     heading: facing(facingFoe), clip: fallen ? .death : .idle,
                                     clipTime: fallen ? Clip.death.period : Float(elapsed) + Float(index) * 0.7, isOwn: company.side == 0,
                                     commander: company.commander, muster: company.kind == .bow ? 900 : 1_600))
        }
        if let blaze { happenings.blazes.append(Happenings.Spot(at: blaze, strength: 0.6, seed: 77)) }
    }

    /// The moments the battle sounds: each blow as it lands, each volley
    /// loosed, each company falling and each skill fired, seconds into it.
    public var beats: [(time: Double, sound: Beat)] {
        var beats: [(time: Double, sound: Beat)] = []
        for (index, company) in companies.enumerated() {
            for blow in blows(of: company, until: Battle.length) {
                beats.append(company.kind == .bow ? (time: blow, sound: .loose) : (time: blow + 0.35, sound: .clash(across: Float(index % 5 - 2) / 2.5)))
            }
            if let falls = company.falls { beats.append((time: falls, sound: .fall)) }
        }
        for fury in furies { beats.append((time: fury.time, sound: .fury)) }
        return beats.sorted { $0.time < $1.time }
    }

    public enum Beat: Equatable, Sendable {
        case clash(across: Float)
        case loose
        case fall
        case fury
    }
}
