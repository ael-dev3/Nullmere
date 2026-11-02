import Foundation
import NullmereCore

/// What turns, swings and flickers on a work, the same in every clip: a
/// wheel turns once a period, a crane slews and comes back, a fire leaps.
struct Machinery: Sendable {
    struct Wheel: Sendable {
        var part: UInt16
        var axis: Vec3
        var turns: Float
    }

    struct Swing: Sendable {
        var part: UInt16
        var axis: Vec3
        var angle: Float
    }

    var wheels: [Wheel] = []
    var swings: [Swing] = []
    var flames: [UInt16] = []
    var parts: Int

    func joints(_ clip: Clip, _ time: Float) -> [Joint] {
        var p = Pose(count: parts)
        let u = clip.progress(at: time)
        for wheel in wheels {
            let angle = 2 * Float.pi * wheel.turns * u
            p.turn(wheel.part, x: wheel.axis.x * angle, y: wheel.axis.y * angle, z: wheel.axis.z * angle)
        }
        for swing in swings {
            let angle = swing.angle * Motion.key(u, [(0, 0), (0.3, 1), (0.5, 1), (0.8, -0.4), (1, 0)])
            p.turn(swing.part, x: swing.axis.x * angle, y: swing.axis.y * angle, z: swing.axis.z * angle)
        }
        for flame in flames {
            let leap = 0.6 * Motion.wave(u, cycles: 5) + 0.4 * Motion.wave(u, cycles: 7, phase: 0.3)
            p.stretch(flame, Vec3(1 + 0.08 * leap, 1 + 0.22 * leap, 1 + 0.08 * leap))
        }
        return p.joints
    }
}

extension MeshBuilder {
    /// Packed ground a work stands on, sunk deep enough to sit on a slope.
    mutating func pad(radius: Float, color: Vec3 = Palette.yard, sides: Int = 8) {
        lathe([(radius, -0.14), (radius, 0.0), (radius * 0.95, 0.012)], sides: sides, color: color, twist: .pi / Float(sides))
    }

    /// A building with a gable roof, its ridge along x, standing at `at`
    /// and turned about the vertical; its walls on a footing of stone.
    mutating func hall(at: Vec3, width: Float, depth: Float, height: Float, wall: Vec3, roof: Vec3,
                       roofMaterial: Material = .plain, pitch: Float = 0.55, turn: Float = 0, footing: Vec3? = nil) {
        place(.translation(at) * .rotationY(turn)) {
            if let footing {
                $0.box(min: Vec3(-width / 2 - 0.012, -0.08, -depth / 2 - 0.012), max: Vec3(width / 2 + 0.012, 0.04, depth / 2 + 0.012),
                       color: footing)
            }
            $0.box(min: Vec3(-width / 2, -0.04, -depth / 2), max: Vec3(width / 2, height, depth / 2), color: wall)
            $0.with(material: roofMaterial) {
                $0.gableRoof(width: width, depth: depth, base: height, height: depth * pitch, color: roof, overhang: 0.022)
            }
            // Its frame: posts at the corners, boards along the eaves and a
            // beam along the ridge, dark against walls and roof.
            let post = Palette.timberDark, w = width / 2, d = depth / 2
            for x in [-w, w] {
                for z in [-d, d] {
                    $0.box(center: Vec3(x, height / 2 - 0.02, z), size: Vec3(0.014, height + 0.04, 0.014), color: post)
                }
            }
            for z in [-d - 0.02, d + 0.02] {
                $0.box(center: Vec3(0, height + 0.004, z), size: Vec3(width + 0.044, 0.01, 0.008), color: post)
            }
            $0.box(center: Vec3(0, height + depth * pitch + 0.004, 0), size: Vec3(width + 0.05, 0.012, 0.014), color: post)
            // Its fine work: two courses across each slope of the roof,
            // boards along the gables and a vent high in each.
            $0.fine { b in
                let eave = d + 0.022, end = w + 0.022, rise = depth * pitch
                b.with(material: roofMaterial) { b in
                    for t in [Float(0.3), 0.62] {
                        for side in [Float(1), -1] {
                            let z = side * eave * (1 - t)
                            b.beam(from: Vec3(-end, height + rise * t, z), to: Vec3(end, height + rise * t, z), width: 0.008, depth: 0.008,
                                   color: roof * 0.78)
                        }
                    }
                }
                for x in [-end + 0.003, end - 0.003] {
                    for side in [Float(1), -1] {
                        b.beam(from: Vec3(x, height + rise * 0.05, side * eave * 0.95), to: Vec3(x, height + rise + 0.006, 0), width: 0.012,
                               depth: 0.012, color: post)
                    }
                    b.box(center: Vec3(x + (x > 0 ? 0.002 : -0.002), height + rise * 0.38, 0), size: Vec3(0.006, 0.022, 0.026),
                          color: Palette.timberDark)
                }
                // The rafters' ends out under the eaves.
                let rafters = max(Int((width / 0.06).rounded()), 2)
                for index in 0...rafters {
                    let x = -w + width * Float(index) / Float(rafters)
                    for side in [Float(1), -1] {
                        b.limb(from: Vec3(x, height - 0.006, side * (d - 0.004)), to: Vec3(x, height + 0.006, side * (d + 0.02)),
                               radius: 0.006, color: post)
                    }
                }
            }
        }
    }

    /// A round bin or tower under a cone.
    mutating func roundHouse(at: Vec3, radius: Float, height: Float, wall: Vec3, roof: Vec3, roofMaterial: Material = .plain,
                             roofHeight: Float? = nil, sides: Int = 8) {
        let rise = roofHeight ?? radius * 1.5
        place(.translation(at)) {
            $0.lathe([(radius, -0.06), (radius, height)], sides: sides, color: wall)
            $0.with(material: roofMaterial) {
                $0.cone(sides: sides, radius: radius * 1.18, from: height, to: height + rise, color: roof)
            }
            // Its fine work: a stone one's string courses, or a timber one's
            // hoops; a ring round its roof and a finial on its point.
            $0.fine { b in
                let band = Surface.of(wall) == .stone ? Palette.stonePale : Palette.timberDark
                for y in [height * 0.3, height * 0.72] {
                    b.lathe([(radius * 0.98, y), (radius * 1.05, y + 0.004), (radius * 1.05, y + 0.013), (radius * 0.98, y + 0.017)],
                            sides: sides, color: band)
                }
                b.with(material: roofMaterial) { b in
                    let r = radius * 1.18 * 0.55, y = height + rise * 0.45
                    b.lathe([(r * 0.97, y - 0.006), (r * 1.04, y), (r * 0.97, y + 0.008)], sides: sides, color: roof * 0.78)
                }
                b.limb(from: Vec3(0, height + rise - 0.012, 0), to: Vec3(0, height + rise + 0.035, 0), radius: 0.006, topRadius: 0.002,
                       color: Palette.timberDark)
            }
        }
    }

    /// A log lying from one end to the other, its cut ends pale.
    mutating func log(from a: Vec3, to c: Vec3, radius: Float) {
        place(.translation(a) * Mat4.aligningUp(to: c - a)) {
            let length = (c - a).length, step = 2 * Float.pi / 5
            $0.tube([(radius, 0), (radius, length)], sides: 5, color: Palette.bark)
            $0.polygon((0..<5).reversed().map { MeshBuilder.ring(radius, 0, Float($0) * step) }, color: Palette.timberPale)
            $0.polygon((0..<5).map { MeshBuilder.ring(radius, length, Float($0) * step) }, color: Palette.timberPale)
        }
    }

    /// A stack of sawn planks.
    mutating func planks(at: Vec3, length: Float, layers: Int, turn: Float = 0) {
        place(.translation(at) * .rotationY(turn)) {
            for layer in 0..<layers {
                let y = Float(layer) * 0.022
                let shift = Float(layer % 2) * 0.01
                $0.box(min: Vec3(-length / 2 + shift, y, -0.05), max: Vec3(length / 2 + shift, y + 0.02, 0.05),
                       color: layer % 2 == 0 ? Palette.timberPale : Palette.timberGrey)
            }
        }
    }

    /// A sack of grain or salt.
    mutating func sack(at: Vec3, size: Float, seed: UInt32, color: Vec3 = Palette.canvas) {
        rock(center: at + Vec3(0, size * 0.8, 0), size: Vec3(size, size * 0.85, size * 0.9), rings: 2, sides: 5, jitter: 0.12,
             seed: seed, color: color)
    }

    /// A sack tied at its neck, sat up, `size` times one a hand high.
    mutating func tiedSack(at: Vec3, size: Float, color: Vec3 = Palette.canvas) {
        place(.translation(at) * .scale(Vec3(size, size, size))) {
            $0.lathe([(0.0, 0.0), (0.022, 0.004), (0.027, 0.02), (0.021, 0.036), (0.008, 0.044), (0.011, 0.05), (0.0, 0.052)], sides: 6,
                     color: color)
        }
    }

    /// A pole with the House's banner.
    mutating func banner(at foot: Vec3, height: Float, width: Float, drop: Float, turn: Float = .pi / 2, tail: Bool = false) {
        limb(from: foot, to: foot + Vec3(0, height, 0), radius: 0.009, color: Palette.timberDark)
        flag(at: foot + Vec3(0, height - 0.01, 0), width: width, height: drop, turn: turn, tail: tail)
    }

    /// A shallow pan of moonsalt in a rim of stone.
    mutating func saltPan(at: Vec3, size: Float, crust: Float = 1) {
        place(.translation(at)) {
            let h = size / 2, rim: Float = 0.016
            for (a, c) in [(Vec3(-h, 0, -h), Vec3(h, 0, -h)), (Vec3(h, 0, -h), Vec3(h, 0, h)), (Vec3(h, 0, h), Vec3(-h, 0, h)),
                           (Vec3(-h, 0, h), Vec3(-h, 0, -h))] {
                $0.beam(from: a + Vec3(0, 0.008, 0), to: c + Vec3(0, 0.008, 0), width: rim, depth: 0.04, color: Palette.stonePale)
            }
            $0.box(min: Vec3(-h, -0.02, -h), max: Vec3(h, 0.006, h), color: Palette.loam)
            // The crust stands a little proud of a work's pad, so a yard's
            // odds and ends are never set down in the brine.
            $0.with(material: .crystal) {
                $0.box(min: Vec3(-h * 0.92 * crust, 0.008, -h * 0.92 * crust), max: Vec3(h * 0.92 * crust, 0.016, h * 0.92 * crust),
                       color: Palette.saltCrust)
            }
        }
    }

    /// A heap of white salt.
    mutating func saltHeap(at: Vec3, radius: Float, height: Float) {
        with(material: .crystal) {
            $0.place(.translation(at)) {
                $0.lathe([(radius, -0.01), (radius * 0.75, height * 0.5), (0, height)], sides: 6, color: Palette.moonsalt)
            }
        }
    }

    /// Cut stone blocks.
    mutating func blocks(at: Vec3, count: Int, seed: UInt32) {
        for index in 0..<count {
            let jitter = Noise.unit(Int32(index), 3, seed)
            let row = index % 3, layer = index / 3
            let at = at + Vec3(Float(row) * 0.062 - 0.062, Float(layer) * 0.042, Float(layer) * 0.012)
            box(center: at + Vec3(0, 0.021, 0), size: Vec3(0.056, 0.04, 0.05), turn: (jitter - 0.5) * 0.3,
                color: Palette.stonePale.mix(Palette.stone, jitter))
        }
    }
}

/// Every work at every level, standing on y = 0 and facing +z toward the
/// keep, each level grander than the last. Each fits within
/// `HoldLayout.workRadius` of its foot.
enum Works {
    static func build(_ kind: BuildingKind, level: Int, name: String) -> Model {
        Estate.dress(trade(kind, level: level, name: name), kind, level: level)
    }

    /// The work itself, before its estate.
    static func trade(_ kind: BuildingKind, level: Int, name: String) -> Model {
        switch kind {
        case .granary: return Granary.model(level: level, name: name)
        case .sawpit: return sawpit(level, name)
        case .quarry: return Quarry.model(level: level, name: name)
        case .saltworks: return Saltworks.model(level: level, name: name)
        case .musterHall: return MusterHall.model(level: level, name: name)
        case .walls: return WallWork.dress(Holds.walls(level: level, name: name), level: level)
        case .beacon: return Beacon.model(level: level, name: name)
        case .infirmary: return infirmary(level, name)
        case .moonspire: return moonspire(level, name)
        case .archive: return study(level: level, name: name)
        case .forge: return forge(level, name)
        case .wayhouse: return wayhouse(level, name)
        case .lodge: return Lodge.model(level: level, name: name)
        }
    }

    // MARK: The Wayhouse

    /// A post-house where the House's roads begin: a timber hall with its
    /// stable under a lean-to, a signpost and a trough by the road; from
    /// the second level a second bay and a rick of hay; from the third, a
    /// hall of pale stone and a dovecote for the post-birds; then a gate
    /// over the road with its lantern lit; at the fifth, a waymark pillar
    /// crowned with a moonsalt lamp that burns through the night.
    static func wayhouse(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31)
        let height = wardHeight(level)
        let stone = level >= 3
        b.hall(at: Vec3(-0.07, 0, -0.11), width: 0.24, depth: 0.14, height: height,
               wall: stone ? Palette.stonePale : Palette.timber, roof: level == 1 ? Palette.thatch : Palette.slate,
               pitch: 0.65, footing: level >= 2 ? Palette.stone : nil)
        b.door(Vec3(-0.06, 0.05, -0.039), width: 0.05, height: 0.09, facing: 0)
        b.window(Vec3(-0.15, height * 0.62, -0.039), width: 0.024, height: 0.034, facing: 0)
        // The stable under its lean-to: a bay, two from the second level,
        // a horse's head over each half-door.
        for bay in 0..<(level >= 2 ? 2 : 1) {
            let x = 0.1 + Float(bay) * 0.09
            for post in [Float(-0.042), 0.042] {
                b.limb(from: Vec3(x + post, 0, -0.04), to: Vec3(x + post, 0.1, -0.04), radius: 0.006, color: Palette.timberDark)
            }
            b.box(min: Vec3(x - 0.05, 0.1, -0.18), max: Vec3(x + 0.05, 0.112, -0.035), color: level == 1 ? Palette.thatch : Palette.slate)
            b.box(min: Vec3(x - 0.042, 0, -0.17), max: Vec3(x + 0.042, 0.1, -0.16), color: Palette.timberDark)
            b.box(min: Vec3(x - 0.036, 0, -0.045), max: Vec3(x + 0.036, 0.045, -0.04), color: Palette.timber)
            b.place(.translation(Vec3(x, 0.06, -0.06))) {
                $0.limb(from: Vec3(0, 0, 0), to: Vec3(0, 0.02, 0.035), radius: 0.011, topRadius: 0.008,
                        color: bay == 0 ? Palette.horseBay : Palette.horseGrey)
            }
        }
        // The signpost by the road, and the trough for the post-horses.
        b.limb(from: Vec3(0.2, 0, 0.12), to: Vec3(0.2, 0.16, 0.12), radius: 0.006, color: Palette.timberDark)
        for (y, turn) in [(Float(0.14), Float(0.5)), (0.115, -0.7)] {
            b.box(center: Vec3(0.2, y, 0.12), size: Vec3(0.075, 0.016, 0.006), turn: turn, color: Palette.timberPale)
        }
        b.box(min: Vec3(0.05, 0, 0.08), max: Vec3(0.14, 0.03, 0.11), color: Palette.timberDark)
        b.box(min: Vec3(0.056, 0.02, 0.086), max: Vec3(0.134, 0.028, 0.104), color: Palette.slate)
        if level >= 2 {
            // A rick of hay for the horses.
            b.place(.translation(Vec3(0.25, 0, 0.0))) {
                $0.lathe([(0.04, 0), (0.044, 0.04), (0.03, 0.075), (0.0, 0.095)], sides: 7, color: Palette.straw)
            }
        }
        if stone {
            // The dovecote for the post-birds, round, its holes in rows.
            b.roundHouse(at: Vec3(-0.21, 0, 0.06), radius: 0.045, height: 0.17, wall: Palette.stonePale, roof: Palette.slate)
            b.place(.translation(Vec3(-0.21, 0, 0.06))) {
                for row in 0..<2 {
                    for angle in [Float(0.3), 1.2, 2.1] {
                        $0.window(onRound: 0.046, y: 0.11 + Float(row) * 0.03, angle: angle, width: 0.012, height: 0.012,
                                  color: Palette.timberDark)
                    }
                }
            }
        }
        if level >= 4 {
            // The gate over the road, a lantern lit beneath its beam.
            for x in [Float(0.02), 0.16] {
                b.limb(from: Vec3(x, 0, 0.24), to: Vec3(x, 0.17, 0.24), radius: 0.009, color: stone ? Palette.stone : Palette.timberDark)
            }
            b.beam(from: Vec3(0.005, 0.17, 0.24), to: Vec3(0.175, 0.17, 0.24), width: 0.016, color: Palette.timberDark)
            b.limb(from: Vec3(0.09, 0.17, 0.24), to: Vec3(0.09, 0.14, 0.24), radius: 0.002, color: Palette.iron)
            b.with(material: .glow) {
                $0.box(center: Vec3(0.09, 0.128, 0.24), size: Vec3(0.016, 0.022, 0.016), color: Palette.candle)
            }
        }
        if level >= 5 {
            // The waymark: a pillar of pale stone, a moonsalt lamp on it.
            b.place(.translation(Vec3(-0.17, 0, 0.19))) {
                $0.prism(sides: 4, radius: 0.022, topRadius: 0.016, to: 0.24, color: Palette.stoneWhite)
            }
            b.with(material: .crystal) {
                $0.place(.translation(Vec3(-0.17, 0.24, 0.19))) {
                    $0.lathe([(0.0, 0.0), (0.02, 0.03), (0.0, 0.07)], sides: 6, color: Palette.moonsalt)
                }
            }
        }
        b.banner(at: Vec3(-0.17, height + 0.06, -0.11), height: 0.12, width: 0.05, drop: 0.07)
        // Near, the post-house's ways: saddles on a rail by the door, the
        // post's bags against the wall and a spare wheel leaning by them, a
        // bucket at the trough and a milestone by the road; from the
        // third, the post-birds down from their cote, pecking.
        b.fine { near in
            for x in [Float(-0.025), 0.035] {
                near.limb(from: Vec3(x, 0, -0.02), to: Vec3(x, 0.05, -0.02), radius: 0.004, color: Palette.timberDark)
            }
            near.beam(from: Vec3(-0.03, 0.05, -0.02), to: Vec3(0.04, 0.05, -0.02), width: 0.006, color: Palette.timber)
            for x in [Float(-0.008), 0.018] {
                near.box(center: Vec3(x, 0.056, -0.02), size: Vec3(0.02, 0.012, 0.03), color: Palette.leatherDark)
                near.box(center: Vec3(x, 0.046, -0.004), size: Vec3(0.018, 0.016, 0.003), color: Palette.leather)
            }
            for (index, at) in [Vec3(-0.1, 0, -0.022), Vec3(-0.118, 0, -0.012)].enumerated() {
                near.sack(at: at, size: 0.014, seed: UInt32(60 + index), color: Palette.leather)
            }
            near.place(.translation(Vec3(-0.168, 0.033, -0.028)) * .rotationX(-0.22) * .rotationY(.pi / 2)) {
                $0.wheel(center: .zero, radius: 0.032, width: 0.008, spokes: 3, color: Palette.timber, rim: Palette.timberDark)
            }
            near.place(.translation(Vec3(0.15, 0, 0.125))) {
                $0.lathe([(0.011, 0), (0.014, 0.022)], sides: 6, color: Palette.timberDark)
            }
            near.box(center: Vec3(0.24, 0.0175, 0.17), size: Vec3(0.022, 0.035, 0.014), color: Palette.stonePale)
            near.limb(from: Vec3(0.24, 0.035, 0.163), to: Vec3(0.24, 0.035, 0.177), radius: 0.011, sides: 6, color: Palette.stonePale)
            if stone {
                for (index, at) in [Vec3(-0.15, 0, 0.1), Vec3(-0.128, 0, 0.128), Vec3(-0.162, 0, 0.138)].enumerated() {
                    let facing = Float(index) * 2.1 + 0.4
                    let ahead = Vec3(Float(cos(Double(facing))), 0, -Float(sin(Double(facing))))
                    near.sphere(center: at + Vec3(0, 0.006, 0), radius: 0.006, rings: 3, sides: 5, color: Palette.stoneWhite, squash: 0.8)
                    near.sphere(center: at + ahead * 0.006 + Vec3(0, 0.0105, 0), radius: 0.0038, rings: 2, sides: 5, color: Palette.stoneWhite)
                }
            }
        }
        return model(name, b)
    }


    static func model(_ name: String, _ b: MeshBuilder, rig: Rig = Rig(), machinery: Machinery? = nil) -> Model {
        var b = b
        b.fine { yard(&$0, seed: seed(of: name), count: 4) }
        guard let machinery else { return Model(name: name, mesh: b.mesh) }
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    /// A seed from a work's name, the same in every run.
    static func seed(of name: String) -> UInt32 {
        name.utf8.reduce(2_166_136_261) { ($0 ^ UInt32($1)) &* 16_777_619 }
    }

    // MARK: The yard

    /// Where a work's pieces stand on its pad, seen from above: a grid of
    /// cells a hundredth across, each taken where anything rises from the
    /// pad over it.
    struct Footprint {
        static let cell: Float = 0.01, reach: Float = 0.34
        static let cells = Int(2 * reach / cell)
        var taken = [Bool](repeating: false, count: cells * cells)

        init(_ mesh: Mesh) {
            for (a, b, c) in mesh.triangles where max(a.position.y, b.position.y, c.position.y) > 0.015 {
                let low = pointwiseMin(pointwiseMin(a.position, b.position), c.position)
                let high = pointwiseMax(pointwiseMax(a.position, b.position), c.position)
                for row in Footprint.index(low.z)...Footprint.index(high.z) {
                    for column in Footprint.index(low.x)...Footprint.index(high.x) {
                        taken[row * Footprint.cells + column] = true
                    }
                }
            }
        }

        static func index(_ value: Float) -> Int {
            min(max(Int(((value + reach) / cell).rounded(.down)), 0), cells - 1)
        }

        /// Whether nothing stands within `radius` of a spot on the pad.
        func isFree(_ at: Vec3, radius: Float) -> Bool {
            for row in Footprint.index(at.z - radius)...Footprint.index(at.z + radius) {
                for column in Footprint.index(at.x - radius)...Footprint.index(at.x + radius) where taken[row * Footprint.cells + column] {
                    return false
                }
            }
            return true
        }
    }

    /// The odds and ends of a working yard: barrels, crates, sacks, a
    /// bucket, a bench and a stack of logs, set down on the pad where
    /// nothing of the work stands, apart from each other and clear of the
    /// way to its door, the same for the same work each time. The spots
    /// they were set on.
    @discardableResult
    static func yard(_ b: inout MeshBuilder, seed: UInt32, count: Int) -> [Vec3] {
        let footprint = Footprint(b.mesh)
        var spots: [Vec3] = []
        for step in 0..<64 where spots.count < count {
            let angle = Float(step) * 2.39996 + Noise.unit(Int32(step), 31, seed) * 0.5
            let radius = 0.17 + 0.1 * Noise.unit(Int32(step), 32, seed)
            let at = Vec3(radius * cos(angle), 0.012, radius * sin(angle))
            guard !(abs(at.x) < 0.08 && at.z > 0), footprint.isFree(at, radius: 0.035),
                  spots.allSatisfy({ ($0 - at).length > 0.075 }) else { continue }
            spots.append(at)
            let turn = Noise.unit(Int32(step), 33, seed) * 2 * .pi
            switch Int(Noise.unit(Int32(step), 34, seed) * 6) {
            case 0:
                // A barrel, hooped.
                b.place(.translation(at)) {
                    $0.lathe([(0.021, 0), (0.025, 0.026), (0.021, 0.052)], sides: 7, color: Palette.timber)
                    $0.lathe([(0.0235, 0.012), (0.0255, 0.015), (0.0235, 0.018)], sides: 7, color: Palette.iron)
                }
            case 1:
                // Two crates, one on the other.
                b.box(center: at + Vec3(0, 0.02, 0), size: Vec3(0.04, 0.04, 0.04), turn: turn, color: Palette.timberPale)
                b.box(center: at + Vec3(0, 0.054, 0), size: Vec3(0.03, 0.028, 0.03), turn: turn + 0.4, color: Palette.timberGrey)
            case 2:
                // Sacks, leaning together.
                b.sack(at: at + Vec3(-0.012, 0, 0), size: 0.022, seed: seed &+ UInt32(step))
                b.sack(at: at + Vec3(0.014, 0, 0.006), size: 0.019, seed: seed &+ UInt32(step) &+ 1)
            case 3:
                // A bucket with its handle.
                b.place(.translation(at)) {
                    $0.lathe([(0.013, 0), (0.016, 0.026)], sides: 6, color: Palette.timberDark)
                    $0.limb(from: Vec3(-0.015, 0.026, 0), to: Vec3(0, 0.04, 0), radius: 0.002, sides: 3, color: Palette.iron)
                    $0.limb(from: Vec3(0, 0.04, 0), to: Vec3(0.015, 0.026, 0), radius: 0.002, sides: 3, color: Palette.iron)
                }
            case 4:
                // A bench of one plank on two trestles.
                b.place(.translation(at) * .rotationY(turn)) {
                    $0.box(center: Vec3(0, 0.026, 0), size: Vec3(0.06, 0.006, 0.016), color: Palette.timberPale)
                    for x in [Float(-0.022), 0.022] {
                        $0.box(center: Vec3(x, 0.012, 0), size: Vec3(0.006, 0.024, 0.014), color: Palette.timber)
                    }
                }
            default:
                // A stack of logs.
                b.place(.translation(at) * .rotationY(turn)) {
                    for (x, y) in [(Float(-0.01), Float(0.009)), (0.01, 0.009), (0, 0.025)] {
                        $0.log(from: Vec3(x, y, -0.026), to: Vec3(x, y, 0.026), radius: 0.009)
                    }
                }
            }
        }
        return spots
    }

    // MARK: Sawpit

    static func sawpit(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31)
        // The saw pit itself, and a trestle with a log on it.
        func trestle(_ b: inout MeshBuilder, at: Vec3) {
            b.box(min: at + Vec3(-0.12, -0.03, -0.035), max: at + Vec3(0.12, 0.004, 0.035), color: Palette.loam)
            for x in [Float(-0.1), 0.1] {
                for z in [Float(-0.04), 0.04] {
                    b.limb(from: at + Vec3(x, 0, z), to: at + Vec3(x, 0.12, 0), radius: 0.009, color: Palette.timber)
                }
            }
            b.log(from: at + Vec3(-0.15, 0.135, 0), to: at + Vec3(0.15, 0.135, 0), radius: 0.03)
        }
        // Near, at the first levels: the pit-saw standing through the log,
        // its tiller above and its box in the pit, wedges in the kerf behind
        // it and its sawdust heaped by the pit.
        func pitSaw(_ b: inout MeshBuilder, at: Vec3, part: UInt16 = 0) {
            b.with(part: part) { b in b.fine {
                $0.with(material: .metal) {
                    $0.beam(from: at + Vec3(0.04, 0.008, 0), to: at + Vec3(0.04, 0.27, 0), width: 0.014, depth: 0.002, color: Palette.steel)
                    for x in [Float(0.062), 0.078] {
                        $0.box(center: at + Vec3(x, 0.167, 0), size: Vec3(0.007, 0.01, 0.006), color: Palette.iron)
                    }
                }
                $0.beam(from: at + Vec3(0.04, 0.27, -0.026), to: at + Vec3(0.04, 0.27, 0.026), width: 0.006, color: Palette.timberPale)
                $0.box(center: at + Vec3(0.04, 0.014, 0), size: Vec3(0.008, 0.012, 0.03), color: Palette.timberPale)
                $0.sphere(center: at + Vec3(0.03, 0.0, 0.07), radius: 0.03, rings: 2, sides: 6, color: Palette.straw, squash: 0.35)
            } }
        }
        /// The pit-saw rocks in its cut while the sawyers work it.
        func sawing(_ rig: inout Rig, at: Vec3) -> (UInt16, Machinery.Swing) {
            let part = rig.add("pit-saw", pivot: at + Vec3(0.04, 0.135, 0))
            return (part, Machinery.Swing(part: part, axis: Vec3(0, 0, 1), angle: 0.14))
        }
        // And at every level a chopping block, an axe bitten into it.
        func block(_ b: inout MeshBuilder, at: Vec3) {
            b.fine {
                $0.place(.translation(at)) {
                    $0.lathe([(0.026, 0), (0.026, 0.044)], sides: 7, color: Palette.timber)
                    $0.lathe([(0.025, 0.044), (0.025, 0.046)], sides: 7, color: Palette.timberPale)
                    $0.beam(from: Vec3(0.004, 0.05, 0.002), to: Vec3(0.042, 0.088, 0.02), width: 0.005, color: Palette.timberPale)
                    $0.with(material: .metal) {
                        $0.box(center: Vec3(0.0, 0.05, 0.0), size: Vec3(0.018, 0.012, 0.004), turn: -0.45, color: Palette.iron)
                    }
                }
            }
        }
        var rig = Rig()
        var machinery: Machinery?
        block(&b, at: level <= 2 ? Vec3(-0.2, 0, 0.17) : Vec3(0.2, 0, -0.17))
        switch level {
        case 1:
            trestle(&b, at: Vec3(0, 0, 0.04))
            let (saw, swing) = sawing(&rig, at: Vec3(0, 0, 0.04))
            pitSaw(&b, at: Vec3(0, 0, 0.04), part: saw)
            machinery = Machinery(swings: [swing], parts: rig.count)
            // A lean-to of planks against the weather.
            for x in [Float(-0.14), 0.14] {
                b.limb(from: Vec3(x, 0, -0.12), to: Vec3(x, 0.2, -0.12), radius: 0.012, color: Palette.timber)
            }
            b.place(.translation(Vec3(0, 0.21, -0.14)) * .rotationX(0.5)) {
                $0.box(min: Vec3(-0.17, 0, -0.08), max: Vec3(0.17, 0.014, 0.1), color: Palette.timberGrey)
            }
            b.planks(at: Vec3(-0.08, 0, -0.2), length: 0.24, layers: 3)
            // Near: logs waiting on their chocks, the beetle and wedges that
            // split them, and a lantern on the lean-to's western post.
            b.fine {
                for (index, z) in [Float(0.17), 0.215].enumerated() {
                    $0.box(center: Vec3(0.13, 0.008, z), size: Vec3(0.014, 0.016, 0.03), color: Palette.timberDark)
                    $0.log(from: Vec3(0.06 + Float(index) * 0.01, 0.03, z), to: Vec3(0.2, 0.028, z), radius: 0.022)
                }
                $0.log(from: Vec3(0.075, 0.068, 0.192), to: Vec3(0.19, 0.066, 0.192), radius: 0.02)
                sawpitBeetle(&$0, at: Vec3(-0.04, 0, 0.2), turn: 0.4)
                $0.beam(from: Vec3(-0.14, 0.165, -0.114), to: Vec3(-0.14, 0.165, -0.085), width: 0.004, color: Palette.iron)
                $0.with(material: .glow) {
                    $0.place(.translation(Vec3(-0.14, 0.138, -0.087))) {
                        $0.lathe([(0.0, 0.0), (0.009, 0.009), (0.0, 0.021)], sides: 5, color: Palette.candle)
                    }
                }
            }
        case 2:
            trestle(&b, at: Vec3(0, 0, 0.02))
            let (saw, swing) = sawing(&rig, at: Vec3(0, 0, 0.02))
            pitSaw(&b, at: Vec3(0, 0, 0.02), part: saw)
            machinery = Machinery(swings: [swing], parts: rig.count)
            for x in [Float(-0.16), 0.16] {
                for z in [Float(-0.1), 0.12] {
                    b.limb(from: Vec3(x, -0.02, z), to: Vec3(x, 0.22, z), radius: 0.013, color: Palette.timber)
                }
            }
            b.gableRoof(width: 0.34, depth: 0.24, base: 0.22, height: 0.12, color: Palette.thatch, overhang: 0.02)
            for index in 0..<3 {
                let z = Float(index) * 0.045 - 0.2
                b.log(from: Vec3(-0.19, 0.03 + Float(index % 2) * 0.01, z), to: Vec3(0.1, 0.03, z), radius: 0.025)
            }
            b.planks(at: Vec3(0.12, 0, 0.15), length: 0.16, layers: 4, turn: 0.3)
            // Near: the shed's posts tied at the eaves and braced at their
            // heads, a lantern hung over the saw; before it a sawhorse, a
            // board half sawn on it and the handsaw left in the cut; and by
            // the logs the beetle and wedges that split them.
            b.fine {
                for z in [Float(-0.1), 0.12] {
                    $0.beam(from: Vec3(-0.17, 0.212, z), to: Vec3(0.17, 0.212, z), width: 0.012, color: Palette.timberDark)
                    for x in [Float(-0.16), 0.16] {
                        $0.beam(from: Vec3(x, 0.15, z), to: Vec3(x * 0.7, 0.207, z), width: 0.008, color: Palette.timberDark)
                    }
                }
                $0.limb(from: Vec3(-0.08, 0.206, 0.12), to: Vec3(-0.08, 0.178, 0.12), radius: 0.0015, sides: 3, color: Palette.iron)
                $0.with(material: .glow) {
                    $0.place(.translation(Vec3(-0.08, 0.152, 0.12))) {
                        $0.lathe([(0.0, 0.0), (0.011, 0.011), (0.0, 0.026)], sides: 5, color: Palette.candle)
                    }
                }
                $0.place(.translation(Vec3(-0.07, 0, 0.215)) * .rotationY(0.15)) { horse in
                    for x in [Float(-0.045), 0.045] {
                        for z in [Float(-0.022), 0.022] {
                            horse.limb(from: Vec3(x, 0, z), to: Vec3(x, 0.056, -z * 0.3), radius: 0.003, sides: 3, color: Palette.timber)
                        }
                    }
                    horse.beam(from: Vec3(-0.06, 0.058, 0), to: Vec3(0.06, 0.058, 0), width: 0.008, color: Palette.timber)
                    horse.box(center: Vec3(0, 0.065, 0), size: Vec3(0.15, 0.005, 0.032), color: Palette.timberPale)
                    horse.with(material: .metal) {
                        $0.place(.translation(Vec3(0.022, 0.08, 0)) * .rotationZ(0.35)) {
                            $0.box(center: .zero, size: Vec3(0.046, 0.022, 0.0015), color: Palette.steel)
                        }
                    }
                    horse.place(.translation(Vec3(0.047, 0.094, 0)) * .rotationZ(0.35)) {
                        $0.box(center: .zero, size: Vec3(0.014, 0.012, 0.005), color: Palette.timberDark)
                    }
                }
                sawpitBeetle(&$0, at: Vec3(0.165, 0, -0.18), turn: -0.5)
            }
        default:
            // A saw-house, its saw driven by a great treadwheel at its side.
            let radius: Float = 0.1 + 0.015 * Float(level - 3)
            let houseWidth: Float = 0.22 + 0.03 * Float(level - 3)
            let storeys: Float = level >= 5 ? 0.3 : 0.2
            b.hall(at: Vec3(-0.07, 0, -0.04), width: houseWidth, depth: 0.2, height: storeys, wall: Palette.timber,
                   roof: level >= 4 ? Palette.slate : Palette.thatch, pitch: 0.7, footing: Palette.stoneDark)
            b.door(Vec3(-0.07, 0.08, 0.062), width: 0.07, height: 0.13, facing: 0)
            if level >= 5 {
                b.window(Vec3(-0.12, 0.23, 0.062), width: 0.03, height: 0.04, facing: 0)
                b.window(Vec3(-0.02, 0.23, 0.062), width: 0.03, height: 0.04, facing: 0)
            }
            let hub = Vec3(houseWidth / 2 - 0.03 + 0.035, radius + 0.015, -0.04)
            let wheel = rig.add("wheel", pivot: hub)
            b.with(part: wheel) {
                $0.wheel(center: hub, radius: radius, width: 0.05, spokes: 4, color: Palette.timber, rim: Palette.timberDark)
            }
            b.beam(from: hub + Vec3(-0.045, -radius - 0.015, 0.04), to: hub + Vec3(-0.045, 0.02, 0.0), width: 0.02,
                   color: Palette.timberDark)
            b.beam(from: hub + Vec3(-0.045, -radius - 0.015, -0.04), to: hub + Vec3(-0.045, 0.02, 0.0), width: 0.02,
                   color: Palette.timberDark)
            machinery = Machinery(wheels: [.init(part: wheel, axis: Vec3(1, 0, 0), turns: 1)], parts: rig.count)
            for index in 0..<(level >= 4 ? 4 : 3) {
                let z = Float(index) * 0.04 + 0.1
                b.log(from: Vec3(-0.18, 0.028 + Float(index % 2) * 0.008, z), to: Vec3(0.04, 0.028, z), radius: 0.024)
            }
            b.planks(at: Vec3(0.13, 0, 0.14), length: 0.15, layers: level, turn: 0.4)
            if level >= 4 {
                b.planks(at: Vec3(-0.16, 0, -0.17), length: 0.12, layers: 3, turn: 1.4)
                // Near: the saw-house's frame braced across its front either
                // side of the door, and the sawdust heaped by it.
                b.fine {
                    let front: Float = 0.064, left = -0.07 - houseWidth / 2 + 0.015, right = -0.07 + houseWidth / 2 - 0.015
                    for (foot, head) in [(Vec3(left, 0.02, front), Vec3(-0.115, storeys - 0.02, front)),
                                         (Vec3(right, 0.02, front), Vec3(-0.025, storeys - 0.02, front))] {
                        $0.beam(from: foot, to: head, width: 0.012, depth: 0.008, color: Palette.timberDark)
                    }
                    for x in [left, right] {
                        $0.beam(from: Vec3(x, 0.0, front), to: Vec3(x, storeys, front), width: 0.014, depth: 0.008, color: Palette.timberDark)
                    }
                    $0.beam(from: Vec3(left, storeys * 0.55, front), to: Vec3(-0.11, storeys * 0.55, front), width: 0.01, depth: 0.008,
                            color: Palette.timberDark)
                    $0.beam(from: Vec3(-0.03, storeys * 0.55, front), to: Vec3(right, storeys * 0.55, front), width: 0.01, depth: 0.008,
                            color: Palette.timberDark)
                    $0.sphere(center: Vec3(0.075, 0.0, 0.075), radius: 0.035, rings: 2, sides: 6, color: Palette.straw, squash: 0.4)
                }
            }
            if level >= 5 {
                b.banner(at: Vec3(-0.07, storeys + 0.1, -0.04), height: 0.2, width: 0.13, drop: 0.08)
                // A hoist beam out of the gable over the door, its rope and hook.
                b.beam(from: Vec3(-0.07, storeys + 0.05, -0.02), to: Vec3(-0.07, storeys + 0.05, 0.12), width: 0.018, color: Palette.timberDark)
                b.fine {
                    $0.limb(from: Vec3(-0.07, storeys + 0.04, 0.115), to: Vec3(-0.07, storeys - 0.08, 0.115), radius: 0.002, sides: 3,
                            color: Palette.linen)
                    $0.with(material: .metal) {
                        $0.box(center: Vec3(-0.07, storeys - 0.085, 0.115), size: Vec3(0.012, 0.016, 0.006), color: Palette.iron)
                    }
                }
            }
        }
        b.fine { sawpitNear(&$0, level: level) }
        return model(name, b, rig: rig, machinery: machinery)
    }

    /// A beetle, the great mallet that splits the logs, laid down with its
    /// iron wedges by it.
    static func sawpitBeetle(_ b: inout MeshBuilder, at: Vec3, turn: Float) {
        b.place(.translation(at) * .rotationY(turn)) { beetle in
            beetle.place(.translation(Vec3(0, 0.016, 0)) * .rotationZ(.pi / 2)) {
                $0.lathe([(0.016, -0.022), (0.016, 0.022)], sides: 6, color: Palette.timberGrey)
            }
            beetle.beam(from: Vec3(0, 0.016, 0.012), to: Vec3(0, 0.008, 0.09), width: 0.005, color: Palette.timberPale)
            beetle.with(material: .metal) {
                for (index, x) in [Float(0.036), 0.052].enumerated() {
                    $0.box(center: Vec3(x, 0.004, 0.03 + Float(index) * 0.02), size: Vec3(0.008, 0.008, 0.022),
                           turn: Float(index) * 0.7, color: Palette.iron)
                }
            }
        }
    }

    /// The sawpit drawn nearer still: at every level a grindstone on its
    /// frame over a trough, its crank turned, for the saws and axes; at its
    /// first two, the bark and chips of the logs strewn about the trestle,
    /// sawn boards leaning by the shelter and a bow saw hung on its post.
    static func sawpitNear(_ b: inout MeshBuilder, level: Int) {
        b.place(.translation(Vec3(0.245, 0, -0.03)) * .rotationY(0.4)) { b in
            for x in [Float(-0.03), 0.03] {
                for z in [Float(-0.035), 0.035] {
                    b.limb(from: Vec3(x, 0, z), to: Vec3(x, 0.05, z * 0.6), radius: 0.004, sides: 3, color: Palette.timberDark)
                }
                b.beam(from: Vec3(x, 0.05, -0.03), to: Vec3(x, 0.05, 0.03), width: 0.007, color: Palette.timber)
            }
            b.box(center: Vec3(0, 0.03, 0), size: Vec3(0.05, 0.016, 0.05), color: Palette.timberGrey)
            b.with(surface: .stone) {
                $0.place(.translation(Vec3(0, 0.058, 0)) * .rotationZ(.pi / 2)) {
                    $0.lathe([(0.034, -0.008), (0.034, 0.008)], sides: 8, color: Palette.stonePale)
                }
            }
            b.with(material: .metal) {
                $0.beam(from: Vec3(-0.042, 0.058, 0), to: Vec3(0.045, 0.058, 0), width: 0.004, color: Palette.iron)
                $0.beam(from: Vec3(0.045, 0.058, 0), to: Vec3(0.045, 0.04, 0.012), width: 0.004, color: Palette.iron)
            }
            b.beam(from: Vec3(0.045, 0.04, 0.012), to: Vec3(0.06, 0.04, 0.012), width: 0.005, color: Palette.timberPale)
        }
        guard level <= 2 else { return }
        for (index, at) in [Vec3(-0.07, 0.002, 0.11), Vec3(0.09, 0.002, 0.1), Vec3(0.12, 0.002, -0.02), Vec3(-0.15, 0.002, 0.06)]
            .enumerated() {
            b.box(center: at, size: Vec3(0.04, 0.004, 0.012), turn: Float(index) * 1.3 + 0.4,
                  color: index % 2 == 0 ? Palette.bark : Palette.timberPale)
        }
        // Boards leaning by the shelter's western post.
        let post = level == 1 ? Vec3(-0.14, 0, -0.12) : Vec3(-0.16, 0, -0.1)
        for index in 0..<3 {
            let shift = Float(index) * 0.022
            b.place(.translation(post + Vec3(-0.05 - shift, 0, 0.02 + shift * 0.3)) * .rotationZ(-0.26 - shift)) {
                $0.box(center: Vec3(0, 0.085, 0), size: Vec3(0.018, 0.17, 0.006), color: index == 1 ? Palette.timberGrey : Palette.timberPale)
            }
        }
        // A bow saw hung on the eastern post.
        let hook = (level == 1 ? Vec3(0.14, 0, -0.12) : Vec3(0.16, 0, -0.1)) + Vec3(0, 0.15, 0.014)
        b.beam(from: hook + Vec3(-0.035, 0, 0), to: hook + Vec3(0.035, 0, 0), width: 0.004, color: Palette.timber)
        for x in [Float(-0.03), 0.03] {
            b.beam(from: hook + Vec3(x, 0.022, 0), to: hook + Vec3(x * 1.1, -0.05, 0), width: 0.004, color: Palette.timber)
        }
        b.with(material: .metal) {
            $0.beam(from: hook + Vec3(-0.033, -0.046, 0), to: hook + Vec3(0.033, -0.046, 0), width: 0.002, depth: 0.006, color: Palette.steel)
        }
        b.limb(from: hook + Vec3(-0.03, 0.02, 0), to: hook + Vec3(0.03, 0.02, 0), radius: 0.0012, sides: 3, color: Palette.linen)
    }

    // MARK: Infirmary

    /// How high an Infirmary's ward stands at a level.
    static func wardHeight(_ level: Int) -> Float {
        level >= 4 ? 0.16 : (level >= 2 ? 0.14 : 0.12)
    }

    /// Where smoke rises from an Infirmary's chimney, from its second level:
    /// the healers' fire under their kettles.
    static func infirmaryChimney(_ level: Int) -> Vec3 {
        Vec3(-0.15, wardHeight(level) + 0.13, -0.135)
    }

    /// An infirmary's yard drawn near: until the walk's lanterns hang, a
    /// lantern by the door; and at the first, before a chimney carries the
    /// kettles' fire indoors, the healers' hearth in the open, a ring of
    /// stones round its embers, a kettle on a tripod over it and a log to
    /// sit by it.
    static func infirmaryHearth(_ b: inout MeshBuilder, level: Int) {
        if level <= 3 {
            b.beam(from: Vec3(0.108, 0.13, -0.018), to: Vec3(0.108, 0.13, 0.004), width: 0.004, color: Palette.iron)
            b.with(material: .glow) {
                $0.place(.translation(Vec3(0.108, 0.1, 0.002))) {
                    $0.lathe([(0.0, 0.0), (0.009, 0.009), (0.0, 0.021)], sides: 5, color: Palette.candle)
                }
            }
        }
        guard level == 1 else { return }
        let fire = Vec3(0.16, 0, 0.16)
        for index in 0..<7 {
            let at = fire + MeshBuilder.ring(0.034, 0.006, Float(index) * 2 * .pi / 7)
            b.rock(center: at, size: Vec3(0.011, 0.008, 0.01), rings: 2, sides: 4, jitter: 0.25, seed: UInt32(91 + index), color: Palette.stoneDark)
        }
        b.with(material: .glow) {
            $0.place(.translation(fire)) {
                $0.lathe([(0.0, 0.002), (0.024, 0.004), (0.0, 0.014)], sides: 6, color: Palette.fire)
            }
        }
        for index in 0..<3 {
            let foot = fire + MeshBuilder.ring(0.05, 0, Float(index) * 2 * .pi / 3 + 0.4)
            b.limb(from: foot, to: fire + Vec3(0, 0.1, 0), radius: 0.0028, sides: 3, color: Palette.timberDark)
        }
        b.limb(from: fire + Vec3(0, 0.1, 0), to: fire + Vec3(0, 0.068, 0), radius: 0.0012, sides: 3, color: Palette.iron)
        b.with(material: .metal) {
            $0.place(.translation(fire + Vec3(0, 0.038, 0))) {
                $0.lathe([(0.008, 0), (0.016, 0.01), (0.015, 0.024), (0.009, 0.03)], sides: 7, color: Palette.iron)
            }
        }
        b.log(from: Vec3(0.09, 0.016, 0.225), to: Vec3(0.2, 0.016, 0.245), radius: 0.016)
    }

    /// A long, low ward where the fallen lie, lamplit, with its herb garden
    /// before it: thatch and timber at first, then a footing of stone and a
    /// chimney for the kettles, linen drying on a line; from the third, a
    /// ward of pale stone with a round apse and a well; then a covered walk
    /// and lanterns; at the fifth, a bell-cote and a moonsalt lamp over the
    /// apse, burning through the night.
    static func infirmary(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31)
        let height = wardHeight(level)
        let stone = level >= 3
        b.hall(at: Vec3(-0.02, 0, -0.1), width: 0.38, depth: 0.16, height: height,
               wall: stone ? Palette.stonePale : (level == 2 ? Palette.timberGrey : Palette.timber),
               roof: level == 1 ? Palette.thatch : Palette.slate, pitch: level == 1 ? 0.75 : 0.6,
               footing: level >= 2 ? Palette.stone : nil)
        b.door(Vec3(0.07, 0.055, -0.018), width: 0.05, height: 0.1, facing: 0)
        // Its lamps never go out.
        for x in [Float(-0.06), -0.15] {
            b.window(Vec3(x, height * 0.62, -0.018), width: 0.026, height: 0.038, facing: 0)
        }
        if level >= 2 {
            // The chimney for the healers' fire, rising above the ridge.
            let top = infirmaryChimney(level)
            b.box(min: Vec3(top.x - 0.028, height - 0.02, top.z - 0.025), max: Vec3(top.x + 0.028, top.y, top.z + 0.025),
                  color: Palette.stoneDark)
        }
        if stone {
            // The apse at its east end, round under a cone of slate.
            b.roundHouse(at: Vec3(0.17, 0, -0.1), radius: 0.065, height: height + 0.03, wall: Palette.stonePale, roof: Palette.slate)
            b.place(.translation(Vec3(0.17, 0, -0.1))) {
                for angle in [Float(0), -.pi / 2] {
                    $0.window(onRound: 0.066, y: height * 0.7, angle: angle, width: 0.022, height: 0.04)
                }
            }
        }
        if level >= 5 {
            // A bell-cote on the ridge, and a moonsalt lamp over the apse.
            let ridge = height + 0.16 * 0.6
            for x in [Float(-0.05), -0.01] {
                b.limb(from: Vec3(x, ridge - 0.01, -0.1), to: Vec3(x, ridge + 0.07, -0.1), radius: 0.006, color: Palette.stone)
            }
            b.box(min: Vec3(-0.058, ridge + 0.07, -0.112), max: Vec3(-0.002, ridge + 0.08, -0.088), color: Palette.slate)
            b.with(material: .metal) {
                $0.place(.translation(Vec3(-0.03, ridge + 0.025, -0.1))) {
                    $0.lathe([(0.0, 0.045), (0.012, 0.04), (0.018, 0.012), (0.02, 0.0)], sides: 6, color: Palette.bronze)
                }
            }
            let apseTop = height + 0.03 + 0.065 * 1.5
            b.with(material: .crystal) {
                $0.place(.translation(Vec3(0.17, apseTop - 0.01, -0.1))) {
                    $0.lathe([(0.0, 0.0), (0.02, 0.03), (0.0, 0.07)], sides: 6, color: Palette.moonsalt)
                }
            }
        }
        // The herb garden before it: beds of leaf in rows, more at each level.
        let rows = min(level + 1, 4)
        for row in 0..<rows {
            let z = Float(0.065) + Float(row) * 0.045
            b.box(min: Vec3(-0.23, -0.02, z - 0.017), max: Vec3(-0.03, 0.012, z + 0.017), color: Palette.loam)
            b.with(material: .foliage, sway: 0.6) {
                $0.swayRange = (0, 0.06)
                for plant in 0..<5 {
                    let x = -0.21 + Float(plant) * 0.042
                    let tall = 0.03 + 0.02 * Noise.unit(Int32(plant), Int32(row), 31)
                    $0.place(.translation(Vec3(x, 0.01, z))) {
                        $0.lathe([(0.016, 0), (0.02, tall * 0.5), (0.0, tall)], sides: 5,
                                 color: (plant + row) % 3 == 0 ? Palette.moss : ((plant + row) % 3 == 1 ? Palette.leaf : Palette.grass),
                                 twist: Float(plant))
                    }
                }
            }
        }
        if level >= 2 {
            // Linen drying on a line between two poles, stirring in the wind.
            let left = Vec3(0.04, 0, 0.12), right = Vec3(0.24, 0, 0.12)
            for pole in [left, right] {
                b.limb(from: pole - Vec3(0, 0.03, 0), to: pole + Vec3(0, 0.15, 0), radius: 0.007, color: Palette.timberDark)
            }
            b.beam(from: left + Vec3(0, 0.145, 0), to: right + Vec3(0, 0.145, 0), width: 0.003, color: Palette.timberPale)
            for x in [Float(0.07), 0.15] {
                b.flag(at: Vec3(x, 0.145, 0.12), width: 0.06, height: 0.08, color: Palette.linen, material: .foliage)
            }
        }
        if stone {
            // A well for the healers' water, roofed.
            let well = Vec3(0.13, 0, 0.23)
            b.place(.translation(well)) {
                $0.lathe([(0.04, -0.03), (0.04, 0.05), (0.032, 0.05), (0.032, 0.02)], sides: 8, color: Palette.stone)
                $0.box(min: Vec3(-0.03, 0.02, -0.03), max: Vec3(0.03, 0.03, 0.03), color: Palette.loam)
                for x in [Float(-0.035), 0.035] {
                    $0.limb(from: Vec3(x, 0.03, 0), to: Vec3(x, 0.12, 0), radius: 0.005, color: Palette.timberDark)
                }
                $0.gableRoof(width: 0.09, depth: 0.06, base: 0.12, height: 0.035, color: Palette.slate, overhang: 0.008)
            }
        } else {
            // A water butt by the door.
            b.place(.translation(Vec3(0.13, 0, 0.0))) {
                $0.lathe([(0.022, -0.02), (0.026, 0.03), (0.022, 0.06)], sides: 7, color: Palette.timber)
            }
        }
        if level >= 4 {
            // A covered walk along the ward's front, lanterns at its ends.
            b.box(min: Vec3(-0.22, height * 0.75, -0.02), max: Vec3(0.14, height * 0.75 + 0.012, 0.035), color: Palette.slate)
            for x in [Float(-0.2), -0.06, 0.12] {
                b.limb(from: Vec3(x, -0.02, 0.03), to: Vec3(x, height * 0.75, 0.03), radius: 0.006, color: Palette.timberDark)
            }
            for x in [Float(-0.2), 0.12] {
                b.with(material: .glow) {
                    $0.place(.translation(Vec3(x, height * 0.75 - 0.03, 0.04))) {
                        $0.lathe([(0.0, 0.0), (0.012, 0.012), (0.0, 0.026)], sides: 5, color: Palette.candle)
                    }
                }
            }
        }
        b.fine { infirmaryHearth(&$0, level: level) }
        // Near, the healers' work: a litter leaning by the door, on which
        // the fallen were carried home, and a basket of herbs cut from the
        // garden; from the second level bundles of herbs hung to dry and a
        // bench for those mending; from the third a table of the healers'
        // jars and a bucket on the well's rim.
        b.fine { near in
            for x in [Float(-0.02), 0.02] {
                near.limb(from: Vec3(x, 0, 0.012), to: Vec3(x, 0.11, -0.014), radius: 0.003, color: Palette.timber)
            }
            near.beam(from: Vec3(0, 0.015, 0.009), to: Vec3(0, 0.09, -0.009), width: 0.036, depth: 0.003, color: Palette.canvas)
            near.place(.translation(Vec3(-0.008, 0, 0.075))) {
                $0.lathe([(0.012, 0), (0.016, 0.022)], sides: 7, color: Palette.straw)
                $0.lathe([(0.015, 0.02), (0, 0.032)], sides: 7, color: Palette.leaf)
            }
            if level >= 2 {
                let hang: (y: Float, z: Float) = level >= 4 ? (height * 0.75, 0.012) : (height - 0.008, -0.01)
                let herbs = [Palette.moss, Palette.heatherBloom, Palette.leaf, Palette.fern, Palette.weld]
                for (index, x) in [Float(-0.2), -0.11, -0.098, -0.025, 0.12].enumerated() {
                    near.limb(from: Vec3(x, hang.y, hang.z), to: Vec3(x, hang.y - 0.012, hang.z), radius: 0.001, sides: 3,
                              color: Palette.linen)
                    near.place(.translation(Vec3(x, hang.y - 0.012, hang.z))) {
                        $0.lathe([(0.0055, 0), (0.002, -0.022)], sides: 5, color: herbs[index])
                    }
                }
                near.box(center: Vec3(-0.14, 0.024, 0.02), size: Vec3(0.08, 0.006, 0.018), color: Palette.timberPale)
                for x in [Float(-0.172), -0.108] {
                    near.box(center: Vec3(x, 0.0105, 0.02), size: Vec3(0.006, 0.021, 0.014), color: Palette.timber)
                }
            }
            if stone {
                let table = Vec3(0.2, 0, 0.03)
                near.box(center: table + Vec3(0, 0.04, 0), size: Vec3(0.052, 0.005, 0.03), color: Palette.timberPale)
                for (x, z) in [(Float(-0.021), Float(-0.011)), (0.021, -0.011), (-0.021, 0.011), (0.021, 0.011)] {
                    near.limb(from: table + Vec3(x, 0, z), to: table + Vec3(x, 0.038, z), radius: 0.0025, color: Palette.timber)
                }
                for (index, x) in [Float(-0.014), 0.0, 0.015].enumerated() {
                    let jar = [Palette.weld, Palette.madder, Palette.seaWool][index]
                    near.place(.translation(table + Vec3(x, 0.0425, Float(index % 2) * 0.006 - 0.003))) {
                        $0.lathe([(0.004, 0), (0.0055, 0.008), (0.003, 0.014), (0.003, 0.017)], sides: 6, color: jar)
                    }
                }
                near.place(.translation(Vec3(0.13, 0.05, 0.262))) {
                    $0.lathe([(0.009, 0), (0.012, 0.018)], sides: 6, color: Palette.timberDark)
                }
            }
        }
        return model(name, b)
    }

    // MARK: Forge

    /// How high a Forge's chimney stands at a level.
    static func forgeChimneyHeight(_ level: Int) -> Float {
        [0.3, 0.36, 0.42, 0.5, 0.56][min(max(level, 1), 5) - 1]
    }

    /// Where smoke rises from a Forge's chimney.
    static func forgeChimney(_ level: Int) -> Vec3 {
        Vec3(-0.13, forgeChimneyHeight(level), -0.12)
    }

    /// A forge's yard drawn near: a hitching rail for the horses brought to
    /// be shod, shoes hung on it, and a barrow of charcoal for the hearth;
    /// at the first level, before the smithy stands there, a swage block on
    /// its stump and bar iron stacked by it.
    static func forgeYard(_ b: inout MeshBuilder, level: Int) {
        for x in [Float(0.07), 0.19] {
            b.limb(from: Vec3(x, 0, 0.205), to: Vec3(x, 0.078, 0.205), radius: 0.006, color: Palette.timberDark)
        }
        b.beam(from: Vec3(0.06, 0.072, 0.205), to: Vec3(0.2, 0.072, 0.205), width: 0.009, color: Palette.timber)
        b.with(material: .metal) {
            for (index, x) in [Float(0.1), 0.118, 0.155].enumerated() {
                $0.place(.translation(Vec3(x, 0.058, 0.211)) * .rotationZ(Float(index) * 0.2 - 0.2)) {
                    $0.box(center: Vec3(-0.006, 0, 0), size: Vec3(0.003, 0.018, 0.003), color: Palette.iron)
                    $0.box(center: Vec3(0.006, 0, 0), size: Vec3(0.003, 0.018, 0.003), color: Palette.iron)
                    $0.box(center: Vec3(0, -0.009, 0), size: Vec3(0.015, 0.003, 0.003), color: Palette.iron)
                }
            }
        }
        b.place(.translation(Vec3(-0.1, 0, 0.205)) * .rotationY(0.35)) { barrow in
            barrow.box(min: Vec3(-0.035, 0.022, -0.026), max: Vec3(0.04, 0.05, 0.026), color: Palette.timberPale)
            barrow.wheel(center: Vec3(0.052, 0.018, 0), radius: 0.018, width: 0.006, spokes: 3, color: Palette.timber, rim: Palette.timberDark)
            for z in [Float(-0.02), 0.02] {
                barrow.limb(from: Vec3(0.045, 0.03, z * 0.6), to: Vec3(-0.085, 0.04, z), radius: 0.003, sides: 3, color: Palette.timberDark)
                barrow.limb(from: Vec3(-0.025, 0.022, z), to: Vec3(-0.03, 0, z), radius: 0.003, sides: 3, color: Palette.timberDark)
            }
            for (index, at) in [Vec3(-0.012, 0.054, -0.008), Vec3(0.014, 0.056, 0.007), Vec3(0.002, 0.06, 0.0)].enumerated() {
                barrow.rock(center: at, size: Vec3(0.016, 0.01, 0.013), rings: 2, sides: 5, jitter: 0.3, seed: UInt32(88 + index),
                            color: Palette.barkBlack)
            }
        }
        guard level == 1 else { return }
        let stump = Vec3(0.13, 0, -0.18)
        b.place(.translation(stump)) {
            $0.lathe([(0.024, 0), (0.024, 0.04)], sides: 7, color: Palette.timberDark)
            $0.lathe([(0.023, 0.04), (0.0, 0.041)], sides: 7, color: Palette.timberPale)
        }
        b.with(material: .metal) {
            $0.box(center: stump + Vec3(0, 0.052, 0), size: Vec3(0.03, 0.022, 0.03), color: Palette.iron)
            for index in 0..<4 {
                $0.box(center: Vec3(0.2, 0.004 + Float(index / 2) * 0.008, -0.13 + Float(index % 2) * 0.012), size: Vec3(0.007, 0.007, 0.1),
                       turn: 0.1, color: index % 2 == 0 ? Palette.iron : Palette.mail)
            }
        }
    }

    /// Where a House's smiths work its makings into gear: an open hearth
    /// under a lean-to with its anvil and a trip hammer beating on it, the
    /// hearth's coals glowing; then a timber smithy behind it and a rack of
    /// blades; from the third, a smithy of pale stone with bellows and a
    /// quench trough; then a second hearth and a stand of mail; at the
    /// fifth, a furnace of moonglass burning cold and bright, a grindstone
    /// turning and the House's banner on the chimney.
    static func forge(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, color: Palette.stoneDark)
        let stone = level >= 3
        if level >= 2 {
            // The smithy behind the hearth.
            b.hall(at: Vec3(0.05, 0, -0.17), width: 0.26, depth: 0.12, height: stone ? 0.15 : 0.13,
                   wall: stone ? Palette.stonePale : Palette.timber, roof: Palette.slate, pitch: 0.6,
                   footing: Palette.stoneDark)
            b.door(Vec3(0.1, 0.055, -0.108), width: 0.045, height: 0.09, facing: 0)
            b.window(Vec3(0.0, 0.09, -0.108), width: 0.026, height: 0.034, facing: 0)
        }
        // The lean-to over the hearth: four posts and a roof falling toward the keep.
        let leanTop: Float = 0.2, leanLow: Float = 0.15
        for (x, z) in [(Float(-0.24), Float(-0.1)), (-0.02, -0.1), (-0.24, 0.06), (-0.02, 0.06)] {
            b.limb(from: Vec3(x, -0.02, z), to: Vec3(x, z < 0 ? leanTop : leanLow, z), radius: 0.008, color: Palette.timberDark)
        }
        b.quad(Vec3(-0.27, leanLow, 0.09), Vec3(0.01, leanLow, 0.09), Vec3(0.01, leanTop, -0.13), Vec3(-0.27, leanTop, -0.13),
               color: level == 1 ? Palette.thatch : Palette.slate)
        b.quad(Vec3(-0.27, leanTop - 0.012, -0.13), Vec3(0.01, leanTop - 0.012, -0.13), Vec3(0.01, leanLow - 0.012, 0.09),
               Vec3(-0.27, leanLow - 0.012, 0.09), color: Palette.timberDark)
        // The hearth of stone and its chimney, its coals glowing.
        b.box(min: Vec3(-0.2, -0.03, -0.1), max: Vec3(-0.06, 0.07, 0.0), color: Palette.stoneDark)
        let flue = forgeChimney(level)
        b.box(min: Vec3(flue.x - 0.03, 0.0, flue.z - 0.03), max: Vec3(flue.x + 0.03, flue.y, flue.z + 0.03), color: Palette.stoneDark)
        let coals = rig.add("coals", pivot: Vec3(-0.13, 0.07, -0.05))
        b.with(part: coals, material: .glow) {
            $0.box(center: Vec3(-0.13, 0.08, -0.05), size: Vec3(0.08, 0.02, 0.06), color: Palette.fire)
        }
        // The anvil on its stump.
        let anvil = Vec3(0.07, 0, 0.06)
        b.place(.translation(anvil)) {
            $0.lathe([(0.03, -0.02), (0.032, 0.05), (0.028, 0.055)], sides: 7, color: Palette.timberDark)
        }
        b.with(material: .metal) {
            $0.box(center: anvil + Vec3(0, 0.068, 0), size: Vec3(0.07, 0.026, 0.034), color: Palette.iron)
            $0.place(.translation(anvil + Vec3(-0.035, 0.074, 0)) * .rotationZ(.pi / 2)) {
                $0.cone(sides: 4, radius: 0.012, to: 0.03, color: Palette.iron)
            }
        }
        // The trip hammer: a beam on a post, its iron head beating on the anvil.
        let pivot = Vec3(0.22, 0.13, 0.06)
        b.limb(from: Vec3(0.22, -0.02, 0.06), to: pivot, radius: 0.012, color: Palette.timber)
        let hammer = rig.add("hammer", pivot: pivot)
        b.with(part: hammer) {
            $0.beam(from: pivot, to: Vec3(0.07, 0.125, 0.06), width: 0.016, color: Palette.timber)
            $0.with(material: .metal) {
                $0.box(center: Vec3(0.07, 0.11, 0.06), size: Vec3(0.032, 0.03, 0.03), color: Palette.iron)
            }
        }
        let swings = [Machinery.Swing(part: hammer, axis: Vec3(0, 0, -1), angle: 0.32)]
        var wheels: [Machinery.Wheel] = []
        // A barrel of water for the quench.
        b.place(.translation(Vec3(0.16, 0, -0.04))) {
            $0.lathe([(0.026, -0.02), (0.03, 0.035), (0.026, 0.065)], sides: 7, color: Palette.timber)
        }
        if level >= 2 {
            // A rack of blades by the smithy door.
            b.beam(from: Vec3(0.19, 0.11, -0.095), to: Vec3(0.27, 0.11, -0.095), width: 0.008, color: Palette.timberDark)
            b.with(material: .metal) {
                for index in 0..<3 {
                    let x = 0.2 + Float(index) * 0.03
                    $0.box(center: Vec3(x, 0.07, -0.09), size: Vec3(0.006, 0.08, 0.004), color: Palette.steel)
                }
            }
        }
        if stone {
            // Bellows beside the hearth, and a quench trough before it.
            b.place(.translation(Vec3(-0.24, 0.03, -0.05)) * .rotationZ(0.3)) {
                $0.box(center: .zero, size: Vec3(0.05, 0.03, 0.06), color: Palette.leatherDark)
            }
            b.box(min: Vec3(-0.2, -0.02, 0.03), max: Vec3(-0.08, 0.035, 0.08), color: Palette.stone)
            b.box(min: Vec3(-0.19, 0.02, 0.04), max: Vec3(-0.09, 0.033, 0.07), color: Palette.slate)
        }
        if level >= 4 {
            // A second hearth by the first, and a stand of mail.
            b.box(min: Vec3(-0.2, -0.03, 0.1), max: Vec3(-0.1, 0.06, 0.17), color: Palette.stoneDark)
            b.with(part: coals, material: .glow) {
                $0.box(center: Vec3(-0.15, 0.067, 0.135), size: Vec3(0.06, 0.016, 0.045), color: Palette.fire)
            }
            b.limb(from: Vec3(0.25, -0.02, 0.15), to: Vec3(0.25, 0.16, 0.15), radius: 0.006, color: Palette.timberDark)
            b.with(material: .metal) {
                $0.box(center: Vec3(0.25, 0.115, 0.15), size: Vec3(0.06, 0.07, 0.03), color: Palette.mail)
            }
        }
        if level >= 5 {
            // A furnace of moonglass burning cold and bright, a grindstone
            // turning, and the House's banner from the chimney.
            b.with(material: .crystal) {
                $0.place(.translation(Vec3(0.0, 0.0, 0.18))) {
                    $0.lathe([(0.035, 0.0), (0.04, 0.05), (0.02, 0.1), (0.0, 0.12)], sides: 6, color: Palette.moonsalt)
                }
            }
            let hub = Vec3(0.13, 0.07, 0.19)
            let grindstone = rig.add("grindstone", pivot: hub)
            b.with(part: grindstone) {
                $0.wheel(center: hub, radius: 0.045, width: 0.02, spokes: 2, color: Palette.stone, rim: Palette.stonePale)
            }
            for z in [Float(0.17), 0.21] {
                b.limb(from: Vec3(0.13, -0.02, z), to: Vec3(0.13, 0.07, z), radius: 0.006, color: Palette.timberDark)
            }
            wheels.append(.init(part: grindstone, axis: Vec3(1, 0, 0), turns: 2))
            b.limb(from: flue + Vec3(0.035, -0.08, 0), to: flue + Vec3(0.035, 0.1, 0), radius: 0.005, color: Palette.timberDark)
            b.flag(at: flue + Vec3(0.035, 0.095, 0), width: 0.1, height: 0.07, tail: true)
        }
        b.fine { forgeYard(&$0, level: level) }
        // Near, the smith's gear: the chimney coursed and its flue sooted,
        // tongs and a hammer on the hearth's lip and tongs against the
        // anvil's stump, horseshoes hung on a post, the barrel hooped and
        // charcoal heaped; from the second, tools hung by the smithy door
        // and bar iron stood by it; from the third, the bellows' boards and
        // nozzle and a blade cooling on the trough; from the fourth, a helm
        // and a shield on the stand of mail.
        b.fine {
            let low = flue - Vec3(0.034, 0, 0.034), high = flue + Vec3(0.034, 0, 0.034)
            var courses: [Float] = [0.25, flue.y - 0.014]
            if flue.y >= 0.42 { courses.insert(flue.y - 0.09, at: 1) }
            for y in courses {
                $0.box(min: Vec3(low.x, y, low.z), max: Vec3(high.x, y + 0.014 + (y == courses.last ? 0.004 : 0), high.z),
                       color: Palette.stonePale)
            }
            $0.box(center: flue + Vec3(0, 0.0048, 0), size: Vec3(0.042, 0.0016, 0.042), color: Palette.barkBlack)
            $0.with(material: .metal) {
                for (a, c) in [(Vec3(-0.195, 0.072, -0.004), Vec3(-0.115, 0.072, -0.014)),
                               (Vec3(-0.195, 0.072, -0.015), Vec3(-0.115, 0.072, -0.005))] {
                    $0.beam(from: a, to: c, width: 0.004, depth: 0.003, color: Palette.iron)
                }
                $0.box(center: Vec3(-0.1, 0.077, -0.009), size: Vec3(0.012, 0.01, 0.022), color: Palette.iron)
                for x in [Float(0.066), 0.074] {
                    $0.beam(from: Vec3(x + 0.006, 0, 0.118), to: Vec3(x, 0.052, 0.093), width: 0.004, depth: 0.003, color: Palette.iron)
                }
                for y in [Float(0.1), 0.068] {
                    for x in [Float(-0.028), -0.012] {
                        $0.box(center: Vec3(x, y, 0.07), size: Vec3(0.004, 0.02, 0.003), color: Palette.iron)
                    }
                    $0.box(center: Vec3(-0.02, y - 0.009, 0.07), size: Vec3(0.02, 0.004, 0.003), color: Palette.iron)
                }
                for y in [Float(0.0), 0.044] {
                    $0.place(.translation(Vec3(0.16, 0, -0.04))) {
                        $0.tube([(0.0285, y), (0.0305, y + 0.004), (0.0305, y + 0.01), (0.0285, y + 0.014)], sides: 7, color: Palette.iron)
                    }
                }
            }
            $0.beam(from: Vec3(-0.1, 0.073, -0.008), to: Vec3(-0.066, 0.073, -0.003), width: 0.005, color: Palette.timber)
            $0.rock(center: Vec3(-0.245, 0, 0.12), size: Vec3(0.034, 0.028, 0.03), rings: 2, sides: 6, jitter: 0.3, seed: 43,
                    color: Palette.barkBlack)
            for (index, at) in [Vec3(-0.212, 0.004, 0.098), Vec3(-0.222, 0.004, 0.158), Vec3(-0.272, 0.004, 0.156)].enumerated() {
                $0.rock(center: at, size: Vec3(0.008, 0.006, 0.007), rings: 2, sides: 4, jitter: 0.3, seed: UInt32(44 + index),
                        color: Palette.barkBlack)
            }
            if level >= 2 {
                $0.box(min: Vec3(0.026, 0.035, -0.11), max: Vec3(0.07, 0.1, -0.106), color: Palette.timberPale)
                $0.with(material: .metal) {
                    for x in [Float(0.034), 0.042] {
                        $0.box(center: Vec3(x, 0.07, -0.104), size: Vec3(0.003, 0.05, 0.003), color: Palette.iron)
                    }
                    $0.box(center: Vec3(0.058, 0.088, -0.103), size: Vec3(0.018, 0.009, 0.007), color: Palette.iron)
                    for index in 0..<4 {
                        let x = 0.138 + Float(index) * 0.011
                        $0.beam(from: Vec3(x, 0, -0.086), to: Vec3(x + 0.002, 0.1, -0.107), width: 0.005, depth: 0.004, color: Palette.iron)
                    }
                }
                $0.beam(from: Vec3(0.058, 0.084, -0.103), to: Vec3(0.058, 0.05, -0.103), width: 0.004, color: Palette.timber)
            }
            if stone {
                $0.place(.translation(Vec3(-0.24, 0.03, -0.05)) * .rotationZ(0.3)) {
                    for y in [Float(-0.017), 0.017] {
                        $0.box(center: Vec3(0, y, 0), size: Vec3(0.056, 0.005, 0.064), color: Palette.timberPale)
                    }
                    $0.limb(from: Vec3(-0.02, 0.02, 0), to: Vec3(-0.05, 0.07, 0), radius: 0.004, color: Palette.timber)
                    $0.with(material: .metal) {
                        $0.place(.translation(Vec3(0.026, 0, 0)) * .rotationZ(-.pi / 2)) {
                            $0.cone(sides: 4, radius: 0.008, to: 0.03, color: Palette.iron)
                        }
                    }
                }
                $0.with(material: .metal) {
                    $0.box(center: Vec3(-0.13, 0.038, 0.055), size: Vec3(0.08, 0.003, 0.008), turn: 0.15, color: Palette.steel)
                }
                $0.box(center: Vec3(-0.085, 0.038, 0.06), size: Vec3(0.022, 0.005, 0.007), turn: 0.15, color: Palette.leatherDark)
            }
            if level >= 4 {
                $0.with(material: .metal) {
                    $0.sphere(center: Vec3(0.25, 0.16, 0.15), radius: 0.017, rings: 3, sides: 6, color: Palette.steel, squash: 1.1)
                }
                $0.place(.translation(Vec3(0.215, 0.045, 0.15)) * .rotationZ(.pi / 2 + 0.2)) {
                    $0.lathe([(0.036, -0.003), (0.036, 0.003)], sides: 8, color: Palette.timber)
                    $0.with(material: .metal) {
                        $0.sphere(center: Vec3(0, 0.004, 0), radius: 0.008, rings: 2, sides: 5, color: Palette.iron, squash: 0.6)
                    }
                }
            }
        }
        return model(name, b, rig: rig, machinery: Machinery(wheels: wheels, swings: swings, flames: [coals], parts: rig.count))
    }

    // MARK: Beacon

    /// A beacon's alarm bell: two posts and a beam, the bell hung from it
    /// and its rope down to a cleat on a post.
    static func beaconBell(_ b: inout MeshBuilder, at: Vec3) {
        for z in [Float(-0.026), 0.026] {
            b.limb(from: at + Vec3(0, 0, z), to: at + Vec3(0, 0.1, z), radius: 0.004, sides: 4, color: Palette.timberDark)
        }
        b.beam(from: at + Vec3(0, 0.1, -0.034), to: at + Vec3(0, 0.1, 0.034), width: 0.008, color: Palette.timberDark)
        b.with(material: .metal) {
            $0.place(.translation(at + Vec3(0, 0.058, 0))) {
                $0.lathe([(0.017, 0), (0.013, 0.012), (0.009, 0.034), (0.0, 0.038)], sides: 7, color: Palette.bronze)
            }
        }
        b.limb(from: at + Vec3(0.004, 0.06, 0), to: at + Vec3(0.004, 0.035, 0.022), radius: 0.0012, sides: 3, color: Palette.linen)
    }


    // MARK: Moonspire

    /// The great work, a white tower of moonsalt and stone raised in five
    /// stages: its foundations, then a drum, a tapering stage with a
    /// gallery, a slender upper stage ribbed in moonsalt, and its spire
    /// crowned with a great crystal that turns, lit from within. Until it
    /// is crowned a crane works from the top of the stage last raised.
    static func moonspire(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.lathe([(0.31, -0.14), (0.31, 0.04), (0.28, 0.06)], sides: 10, color: Palette.stonePale)
        var rig = Rig()
        var machinery: Machinery?
        if level == 1 {
            // Foundations: the drum's first courses of white blocks laid
            // round, open at its door, each course shorter than the one
            // below as the masons work their way round; more blocks waiting.
            for (course, laid) in [18, 12, 6].enumerated() {
                for slot in 1...laid {
                    let angle = -Float.pi / 2 + (Float(slot) + 0.5 + 0.5 * Float(course % 2)) * .pi / 10
                    b.box(center: MeshBuilder.ring(0.222, 0.0775 + 0.035 * Float(course), angle), size: Vec3(0.068, 0.034, 0.05),
                          turn: angle + .pi / 2, color: course == 1 ? Palette.stonePale : Palette.stoneWhite)
                }
            }
            b.blocks(at: Vec3(0.09, 0.06, -0.02), count: 6, seed: 11)
            b.saltHeap(at: Vec3(-0.11, 0.06, 0.03), radius: 0.05, height: 0.06)
            b.fine {
                // A banker where a block is dressed, a mallet laid on it,
                // and a coil of rope at the crane's foot.
                $0.box(center: Vec3(-0.08, 0.085, -0.12), size: Vec3(0.06, 0.05, 0.035), color: Palette.timberDark)
                $0.box(center: Vec3(-0.08, 0.124, -0.12), size: Vec3(0.04, 0.028, 0.028), color: Palette.stoneWhite)
                $0.limb(from: Vec3(-0.055, 0.112, -0.1), to: Vec3(-0.035, 0.112, -0.085), radius: 0.0025, sides: 3, color: Palette.timber)
                $0.box(center: Vec3(-0.058, 0.114, -0.102), size: Vec3(0.014, 0.012, 0.012), turn: 0.65, color: Palette.timberDark)
                $0.place(.translation(Vec3(0.065, 0.06, -0.125))) {
                    $0.lathe([(0.012, 0), (0.026, 0), (0.026, 0.012), (0.012, 0.012)], sides: 8, color: Palette.linen)
                }
            }
        } else {
            // The drum, buttressed and crowned with a parapet.
            b.lathe([(0.23, 0.04), (0.21, 0.4), (0.235, 0.42), (0.235, 0.45)], sides: 10, color: Palette.stoneWhite)
            if level == 2 {
                b.merlonRing(radius: 0.225, base: 0.45, count: 10, size: Vec3(0.04, 0.04, 0.025), color: Palette.stonePale)
            }
            for index in 0..<5 {
                let angle = Float(index) * 2 * .pi / 5 + .pi / 10
                b.place(.rotationY(angle)) {
                    $0.lathe([(0.04, 0.0), (0.03, 0.34), (0, 0.4)], sides: 4, color: Palette.stonePale, twist: .pi / 4)
                    $0.place(.translation(Vec3(0, 0, 0.215))) {
                        $0.lathe([(0.04, 0.0), (0.03, 0.34), (0, 0.4)], sides: 4, color: Palette.stonePale, twist: .pi / 4)
                    }
                }
            }
            b.window(Vec3(0, 0.1, 0.225), width: 0.06, height: 0.12, facing: 0, color: Palette.moonGlow)
            for angle in [Float(-0.4), -2.74, 0.9, 2.24] {
                b.window(onRound: 0.215, y: 0.28, angle: angle, width: 0.025, height: 0.06, color: Palette.moonGlow)
            }
            b.fine {
                spireNear(&$0, roundels: level < 4)
            }
        }
        if level >= 3 {
            b.lathe([(0.17, 0.44), (0.14, 0.82), (0.175, 0.84), (0.175, 0.87)], sides: 10, color: Palette.stoneWhite)
            b.merlonRing(radius: 0.17, base: 0.87, count: 10, size: Vec3(0.03, 0.035, 0.02), color: Palette.stonePale)
            b.with(material: .crystal) {
                for index in 0..<5 {
                    let angle = Float(index) * 2 * .pi / 5
                    let foot = MeshBuilder.ring(0.17, 0.45, angle), head = MeshBuilder.ring(0.142, 0.8, angle)
                    $0.limb(from: foot, to: head, radius: 0.016, sides: 3, color: Palette.moonsalt)
                }
            }
            b.window(MeshBuilder.ring(0.152, 0.65, .pi / 2 * -1), width: 0.03, height: 0.07, facing: 0, color: Palette.moonGlow)
            // Near, the gallery's balustrade round the drum's top.
            b.fine {
                $0.merlonRing(radius: 0.228, base: 0.45, count: 20, size: Vec3(0.008, 0.03, 0.008), color: Palette.stonePale)
                $0.lathe([(0.222, 0.48), (0.234, 0.48), (0.234, 0.488), (0.222, 0.488)], sides: 20, color: Palette.stonePale)
            }
        }
        if level >= 4 {
            b.lathe([(0.12, 0.86), (0.09, 1.28), (0.115, 1.3), (0.115, 1.33)], sides: 8, color: Palette.stoneWhite)
            b.with(material: .crystal) {
                for index in 0..<4 {
                    let angle = Float(index) * .pi / 2 + .pi / 4
                    let foot = MeshBuilder.ring(0.12, 0.87, angle), head = MeshBuilder.ring(0.092, 1.27, angle)
                    $0.limb(from: foot, to: head, radius: 0.014, sides: 3, color: Palette.moonsalt)
                }
            }
            b.window(MeshBuilder.ring(0.1, 1.08, -.pi / 2), width: 0.025, height: 0.06, facing: 0, color: Palette.moonGlow)
            wonder(&b)
        }
        if level <= 4 {
            // Until the spire is crowned the work goes on from the top of
            // the stage last raised.
            let (foot, height, reach, wheel): (Vec3, Float, Float, Float) = switch level {
            case 1: (Vec3(0, 0.06, -0.04), 0.32, 0.17, 0.05)
            case 2: (Vec3(0, 0.45, 0), 0.3, 0.295, 0.05)
            case 3: (Vec3(0, 0.87, 0), 0.26, 0.26, 0.045)
            default: (Vec3(0, 1.33, 0), 0.24, 0.2, 0.035)
            }
            machinery = spireCrane(&b, rig: &rig, at: foot, height: height, reach: reach, wheel: wheel)
        }
        if level >= 5 {
            b.cone(sides: 8, radius: 0.1, from: 1.32, to: 1.62, color: Palette.stoneWhite)
            b.banner(at: Vec3(0.0, 1.33, 0.1), height: 0.18, width: 0.12, drop: 0.07, tail: true)
            // The crown: a great moonsalt crystal round a light, turning slowly.
            let crown = rig.add("crown", pivot: Vec3(0, 1.62, 0))
            b.with(part: crown, material: .crystal) {
                $0.place(.translation(Vec3(0, 1.6, 0))) {
                    $0.lathe([(0.0, 0), (0.07, 0.1), (0.06, 0.24), (0, 0.36)], sides: 6, color: Palette.moonsalt)
                }
                for index in 0..<3 {
                    let angle = Float(index) * 2 * .pi / 3
                    $0.place(.translation(MeshBuilder.ring(0.06, 1.66, angle)) * Mat4.aligningUp(to: MeshBuilder.ring(0.6, 1, angle))) {
                        $0.prism(sides: 4, radius: 0.022, from: 0, to: 0.08, color: Palette.moonsalt)
                        $0.cone(sides: 4, radius: 0.022, from: 0.08, to: 0.13, color: Palette.moonsalt)
                    }
                }
            }
            b.with(part: crown, material: .glow) {
                $0.sphere(center: Vec3(0, 1.76, 0), radius: 0.03, rings: 2, sides: 4, color: Palette.moonGlow)
            }
            // A halo of moonsalt shards about the spire below the crown,
            // turning the other way; and moonsalt grown out of the plinth
            // at the buttresses' feet.
            let halo = rig.add("halo", pivot: Vec3(0, 1.48, 0))
            b.with(part: halo, material: .crystal) {
                for index in 0..<8 {
                    let angle = Float(index) * .pi / 4
                    $0.place(.translation(MeshBuilder.ring(0.16, 1.48 + (index % 2 == 0 ? 0.02 : -0.02), angle))) {
                        $0.lathe([(0, -0.045), (0.013, 0), (0, 0.055)], sides: 4, color: Palette.moonsalt)
                    }
                }
            }
            b.with(material: .crystal) {
                for index in 0..<5 {
                    let angle = Float(index) * 2 * .pi / 5
                    for (shard, lean) in [(0, Float(0.35)), (1, -0.2), (2, 0.05)] {
                        let at = MeshBuilder.ring(0.284, 0.04, angle + Float(shard - 1) * 0.07)
                        let out = MeshBuilder.ring(1, 0, angle + lean)
                        $0.place(.translation(at) * Mat4.aligningUp(to: Vec3(out.x * 0.12, 1, out.z * 0.12))) {
                            $0.prism(sides: 4, radius: 0.014, from: 0, to: 0.06 + 0.025 * Float(shard), color: Palette.moonsalt)
                            $0.cone(sides: 4, radius: 0.014, from: 0.06 + 0.025 * Float(shard), to: 0.09 + 0.025 * Float(shard),
                                    color: Palette.moonsalt)
                        }
                    }
                }
            }
            machinery = Machinery(wheels: [.init(part: crown, axis: Vec3(0, 1, 0), turns: 1), .init(part: halo, axis: Vec3(0, 1, 0), turns: -1)],
                                  parts: rig.count)
        }
        return model(name, b, rig: rig, machinery: machinery)
    }

    /// Where the Moonspire's colonnade stands about its drum.
    static let colonnade: Float = 0.265

    /// The Moonspire's dress once it rises past its third stage, a wonder
    /// of the age: a colonnade about the drum's foot under a ring of stone,
    /// a string course round the drum, the House's banners hung between
    /// its buttresses, and a balustrade round the drum's top.
    static func wonder(_ b: inout MeshBuilder) {
        for index in 0..<10 {
            let angle = Float(index) * .pi / 5 + .pi / 10
            let foot = MeshBuilder.ring(colonnade, 0.06, angle)
            b.box(center: foot + Vec3(0, 0.012, 0), size: Vec3(0.03, 0.024, 0.03), turn: angle, color: Palette.stonePale)
            b.place(.translation(foot)) { $0.prism(sides: 6, radius: 0.011, from: 0.024, to: 0.25, color: Palette.stoneWhite) }
            b.box(center: foot + Vec3(0, 0.259, 0), size: Vec3(0.032, 0.018, 0.032), turn: angle, color: Palette.stonePale)
        }
        b.lathe([(0.248, 0.268), (0.282, 0.268), (0.282, 0.292), (0.248, 0.292)], sides: 20, color: Palette.stonePale)
        b.lathe([(0.218, 0.19), (0.229, 0.196), (0.229, 0.21), (0.217, 0.216)], sides: 10, color: Palette.stonePale)
        b.with(material: .house) {
            for index in 0..<5 {
                let angle = Float(index) * 2 * .pi / 5 + .pi / 5
                let out = MeshBuilder.ring(1, 0, angle), across = Vec3(-out.z, 0, out.x)
                let middle = out * 0.222
                $0.sheet([middle + across * 0.026 + Vec3(0, 0.405, 0), middle - across * 0.026 + Vec3(0, 0.405, 0),
                          middle - across * 0.026 + Vec3(0, 0.312, 0), middle + Vec3(0, 0.296, 0), middle + across * 0.026 + Vec3(0, 0.312, 0)],
                         normal: out, color: Palette.house)
            }
        }
    }

    /// The Moonspire's carved work near, once its drum stands: an arch of
    /// voussoirs about its door, its keystone and a step before it, a
    /// brazier burning at either hand, a spout under the parapet between
    /// each pair of buttresses, and, until banners hang there, a moon
    /// carved in moonsalt on the drum.
    static func spireNear(_ b: inout MeshBuilder, roundels: Bool) {
        for index in 0...6 {
            let angle = Float(index) * .pi / 6
            let at = Vec3(0.037 * Float(cos(Double(angle))), 0.16 + 0.037 * Float(sin(Double(angle))), 0.232)
            b.box(center: at, size: Vec3(0.016, 0.014, 0.014), turn: 0, color: Palette.stonePale)
        }
        b.box(center: Vec3(0, 0.2, 0.234), size: Vec3(0.016, 0.02, 0.016), color: Palette.stoneWhite)
        for x in [Float(-0.037), 0.037] {
            b.box(center: Vec3(x, 0.105, 0.232), size: Vec3(0.014, 0.11, 0.014), color: Palette.stonePale)
        }
        b.box(center: Vec3(0, 0.067, 0.252), size: Vec3(0.1, 0.014, 0.04), color: Palette.stonePale)
        for x in [Float(-0.075), 0.075] {
            b.place(.translation(Vec3(x, 0.06, 0.262))) {
                $0.prism(sides: 4, radius: 0.005, to: 0.07, color: Palette.iron)
                $0.lathe([(0.004, 0.068), (0.016, 0.078), (0.018, 0.088), (0.012, 0.088)], sides: 6, color: Palette.iron)
                $0.with(material: .glow) {
                    $0.cone(sides: 4, radius: 0.012, from: 0.086, to: 0.122, color: Palette.fire, twist: 0.3)
                }
            }
        }
        for index in 0..<5 {
            let angle = Float(index) * 2 * .pi / 5 + .pi / 5
            let out = MeshBuilder.ring(1, 0, angle)
            b.beam(from: out * 0.205 + Vec3(0, 0.425, 0), to: out * 0.262 + Vec3(0, 0.418, 0), width: 0.012, depth: 0.012,
                   color: Palette.stonePale)
            guard roundels else { continue }
            b.with(material: .crystal) {
                $0.place(.translation(out * 0.214 + Vec3(0, 0.33, 0)) * Mat4.aligningUp(to: out)) {
                    $0.lathe([(0.022, 0), (0.022, 0.004), (0.014, 0.008)], sides: 8, color: Palette.moonsalt)
                }
            }
        }
    }

    /// The crane the Moonspire's masons work from on the stage they last
    /// raised, until its spire is crowned: a mast and a jib slewing a white
    /// block round over the stage's edge and back, wound up by a treadwheel
    /// at its foot.
    static func spireCrane(_ b: inout MeshBuilder, rig: inout Rig, at foot: Vec3, height: Float, reach: Float, wheel radius: Float)
        -> Machinery {
        let crane = rig.add("crane", pivot: foot)
        let tip = foot + Vec3(0, height * 0.8, reach), drop = height * 0.55
        b.with(part: crane) {
            $0.limb(from: foot, to: foot + Vec3(0, height, 0), radius: 0.011, color: Palette.timberDark)
            $0.beam(from: foot + Vec3(0, height * 0.55, -0.03), to: tip, width: 0.012, color: Palette.timber)
            $0.limb(from: foot + Vec3(0, height, 0), to: tip, radius: 0.0025, sides: 3, color: Palette.linen)
            $0.limb(from: tip, to: tip - Vec3(0, drop, 0), radius: 0.0025, sides: 3, color: Palette.linen)
            $0.box(center: tip - Vec3(0, drop + 0.017, 0), size: Vec3(0.045, 0.034, 0.04), color: Palette.stoneWhite)
        }
        let hub = foot + Vec3(0, radius + 0.006, -(radius + 0.02))
        let treadwheel = rig.add("treadwheel", pivot: hub)
        b.with(part: treadwheel) {
            $0.wheel(center: hub, radius: radius, width: 0.03, spokes: 3, color: Palette.timber, rim: Palette.timberDark)
        }
        for x in [Float(-0.022), 0.022] {
            b.limb(from: foot + Vec3(x, 0, -(radius + 0.02)), to: hub + Vec3(x, 0, 0), radius: 0.004, color: Palette.timberDark)
        }
        return Machinery(wheels: [.init(part: treadwheel, axis: Vec3(1, 0, 0), turns: 1)],
                         swings: [.init(part: crane, axis: Vec3(0, 1, 0), angle: 0.9)], parts: rig.count)
    }

    // MARK: Study

    /// A study's physic garden: two raised beds of boards filled with dark
    /// earth, herbs in rows in each, swaying in the night wind, and a
    /// watering can between them.
    static func studyGarden(_ b: inout MeshBuilder, at: Vec3, turn: Float) {
        b.place(.translation(at) * .rotationY(turn)) { garden in
            for (bed, z) in [Float(-0.032), 0.032].enumerated() {
                garden.box(min: Vec3(-0.06, 0, z - 0.022), max: Vec3(0.06, 0.016, z + 0.022), color: Palette.timberGrey)
                garden.box(min: Vec3(-0.056, 0.016, z - 0.018), max: Vec3(0.056, 0.018, z + 0.018), color: Palette.loam)
                garden.with(material: .foliage) {
                    for index in 0..<5 {
                        let x = -0.044 + Float(index) * 0.022
                        let colour = [Palette.leaf, Palette.fern, Palette.heatherBloom, Palette.moss][(index + bed) % 4]
                        $0.sphere(center: Vec3(x, 0.026, z + (index % 2 == 0 ? -0.006 : 0.006)), radius: 0.011, rings: 2, sides: 5,
                                  color: colour, squash: 0.8)
                    }
                }
            }
            garden.with(material: .metal) {
                $0.place(.translation(Vec3(0.075, 0, 0))) {
                    $0.lathe([(0.009, 0), (0.009, 0.018), (0.006, 0.02)], sides: 6, color: Palette.iron)
                }
                $0.beam(from: Vec3(0.083, 0.012, 0), to: Vec3(0.098, 0.024, 0), width: 0.003, color: Palette.iron)
            }
        }
    }

    /// Where a House's scholars study the lake's lore: a scriptorium, then
    /// a domed library with a lantern on its crown, a tower with an
    /// armillary on its roof, an observatory with a glass, and a great
    /// observatory between two wings. A sundial stands in every court.
    static func study(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31, color: Palette.stoneDark)
        var rig = Rig()
        var machinery: Machinery?
        switch level {
        case 1:
            b.hall(at: Vec3(0, 0, -0.04), width: 0.24, depth: 0.18, height: 0.16, wall: Palette.stone, roof: Palette.slate,
                   footing: Palette.stoneDark)
            b.door(Vec3(0.05, 0.07, 0.052), width: 0.05, height: 0.1, facing: 0)
            b.window(Vec3(-0.06, 0.1, 0.052), width: 0.035, height: 0.05, facing: 0)
            // A bell-cote on the gable.
            b.box(min: Vec3(0.1, 0.16, -0.06), max: Vec3(0.13, 0.27, -0.02), color: Palette.stonePale)
            b.gableRoof(width: 0.05, depth: 0.06, base: 0.27, height: 0.03, color: Palette.slate)
        case 2:
            b.hall(at: Vec3(-0.06, 0, -0.04), width: 0.3, depth: 0.19, height: 0.18, wall: Palette.stone, roof: Palette.slate,
                   footing: Palette.stoneDark)
            dome(&b, at: Vec3(0.14, 0, -0.04), radius: 0.095, wall: 0.2, color: Palette.slate)
            b.place(.translation(Vec3(0.14, 0.29, -0.04))) {
                $0.lathe([(0.022, 0), (0.022, 0.035), (0.028, 0.04), (0, 0.075)], sides: 6, color: Palette.stonePale)
            }
            b.window(Vec3(0.14, 0.307, -0.017), width: 0.012, height: 0.02, facing: 0)
            for x in [Float(-0.16), -0.06, 0.04] {
                b.window(Vec3(x, 0.11, 0.057), width: 0.03, height: 0.06, facing: 0)
            }
            b.door(Vec3(-0.01, 0.05, 0.057), width: 0.04, height: 0.09, facing: 0)
        default:
            // A library hall, and a tower with an armillary turning on its roof.
            let tower: Float = level == 3 ? 0.5 : 0.62
            b.hall(at: Vec3(0.06, 0, -0.06), width: 0.3, depth: 0.18, height: 0.18, wall: Palette.stone, roof: Palette.slate,
                   footing: Palette.stoneDark)
            for x in [Float(-0.02), 0.08, 0.18] {
                b.window(Vec3(x, 0.11, 0.032), width: 0.03, height: 0.06, facing: 0)
            }
            b.door(Vec3(0.03, 0.05, 0.032), width: 0.036, height: 0.09, facing: 0)
            let towerAt = Vec3(-0.16, 0, 0.0)
            b.place(.translation(towerAt)) {
                $0.lathe([(0.11, -0.06), (0.1, tower), (0.12, tower + 0.02), (0.12, tower + 0.04)], sides: 8, color: Palette.stonePale)
                $0.window(Vec3(0, tower * 0.55, 0.1), width: 0.03, height: 0.06, facing: 0)
                $0.window(Vec3(0, tower * 0.8, 0.098), width: 0.03, height: 0.06, facing: 0)
                $0.door(Vec3(0, 0.05, 0.108), width: 0.042, height: 0.09, facing: 0)
            }
            // Courses round the tower, near.
            b.fine {
                for y in [tower * 0.36, tower * 0.68] {
                    let r = 0.11 - 0.01 * (y + 0.06) / (tower + 0.06)
                    $0.place(.translation(towerAt)) {
                        $0.lathe([(r, y), (r + 0.008, y + 0.004), (r + 0.008, y + 0.016), (r, y + 0.02)], sides: 8, color: Palette.stone)
                    }
                }
            }
            if level == 3 {
                let centre = towerAt + Vec3(0, tower + 0.16, 0)
                b.limb(from: towerAt + Vec3(0, tower + 0.03, 0), to: centre, radius: 0.012, color: Palette.bronze)
                let sphere = rig.add("armillary", pivot: centre)
                armillary(&b, part: sphere, at: centre, radius: 0.09)
                machinery = Machinery(wheels: [.init(part: sphere, axis: Vec3(0, 1, 0), turns: 1)], parts: rig.count)
            } else {
                // An observatory dome with its shutter open and a glass looking out.
                dome(&b, at: towerAt + Vec3(0, tower + 0.03, 0), radius: 0.12, wall: 0.0, color: Palette.slate)
                let glass = rig.add("glass", pivot: towerAt + Vec3(0, tower + 0.1, 0))
                b.with(part: glass, material: .metal) {
                    $0.limb(from: towerAt + Vec3(0, tower + 0.1, -0.02), to: towerAt + Vec3(0, tower + 0.23, 0.17), radius: 0.024,
                            topRadius: 0.03, sides: 6, color: Palette.bronze)
                }
                var swings: [Machinery.Swing] = [.init(part: glass, axis: Vec3(0, 1, 0), angle: 0.5)]
                if level >= 5 {
                    // Two wings and an armillary on the court before them.
                    b.hall(at: Vec3(0.1, 0, 0.15), width: 0.16, depth: 0.1, height: 0.14, wall: Palette.stone, roof: Palette.slate)
                    b.window(Vec3(0.1, 0.08, 0.2), width: 0.025, height: 0.045, facing: 0)
                    b.banner(at: Vec3(0.2, 0.18, -0.06), height: 0.22, width: 0.12, drop: 0.08, tail: true)
                    let centre = Vec3(-0.07, 0.17, 0.2)
                    b.limb(from: Vec3(-0.07, 0, 0.2), to: centre, radius: 0.014, color: Palette.stonePale)
                    let sphere = rig.add("armillary", pivot: centre)
                    armillary(&b, part: sphere, at: centre, radius: 0.07)
                    swings.append(.init(part: sphere, axis: Vec3(0, 1, 0), angle: 1.4))
                }
                machinery = Machinery(swings: swings, parts: rig.count)
            }
        }
        // Near, the court's furniture: a sundial on its plinth, its gnomon
        // to the north; by the scriptorium's door a lectern with a book open
        // on it; by the library a bench of books; before the tower's door a
        // chest with scrolls laid on it, and a bench by the hall.
        b.fine { near in
            let dial = level == 1 ? Vec3(-0.16, 0, 0.17) : level == 2 ? Vec3(0.19, 0, 0.17) : Vec3(0.24, 0, 0.13)
            near.box(min: dial + Vec3(-0.018, 0, -0.018), max: dial + Vec3(0.018, 0.055, 0.018), color: Palette.stonePale)
            near.box(min: dial + Vec3(-0.024, 0.055, -0.024), max: dial + Vec3(0.024, 0.062, 0.024), color: Palette.stone)
            near.with(material: .metal) {
                $0.place(.translation(dial + Vec3(0, 0.062, 0))) {
                    $0.lathe([(0.02, 0), (0.02, 0.003)], sides: 10, color: Palette.bronze)
                }
                $0.sheet([dial + Vec3(0, 0.065, 0.012), dial + Vec3(0, 0.065, -0.016), dial + Vec3(0, 0.088, -0.016)],
                         normal: Vec3(1, 0, 0), thickness: 0.003, color: Palette.bronze)
            }
            func books(at: Vec3, count: Int, turn: Float) {
                let covers = [Palette.madder, Palette.seaWool, Palette.leather, Palette.weld]
                for index in 0..<count {
                    near.box(center: at + Vec3(0, 0.005 + Float(index) * 0.009, 0), size: Vec3(0.026, 0.008, 0.019),
                             turn: turn + Float(index) * 0.35, color: covers[index % covers.count])
                }
            }
            func bench(at: Vec3, length: Float) {
                near.box(center: at + Vec3(0, 0.024, 0), size: Vec3(length, 0.006, 0.02), color: Palette.stonePale)
                for x in [-length / 2 + 0.008, length / 2 - 0.008] {
                    near.box(center: at + Vec3(x, 0.0105, 0), size: Vec3(0.008, 0.021, 0.016), color: Palette.stone)
                }
            }
            // At the first two levels, the scholars' physic garden: herbs in
            // raised beds of boards.
            if level <= 2 {
                studyGarden(&near, at: level == 1 ? Vec3(0.215, 0, -0.1) : Vec3(0.0, 0, 0.2), turn: level == 1 ? .pi / 2 : 0)
            }
            switch level {
            case 1:
                let lectern = Vec3(0.11, 0, 0.13)
                // A candle burning by the open book, for the night's reading.
                near.place(.translation(lectern + Vec3(0.017, 0.081, -0.008))) {
                    $0.lathe([(0.0035, 0), (0.0035, 0.014)], sides: 5, color: Palette.linen)
                }
                near.with(material: .glow) {
                    $0.place(.translation(lectern + Vec3(0.017, 0.095, -0.008))) {
                        $0.lathe([(0.0, 0.0), (0.003, 0.003), (0.0, 0.01)], sides: 4, color: Palette.candle)
                    }
                }
                near.box(center: lectern + Vec3(0, 0.003, 0), size: Vec3(0.03, 0.006, 0.026), color: Palette.timberDark)
                near.limb(from: lectern, to: lectern + Vec3(0, 0.066, 0), radius: 0.005, color: Palette.timberDark)
                near.place(.translation(lectern + Vec3(0, 0.072, 0)) * .rotationX(0.45)) {
                    $0.box(center: .zero, size: Vec3(0.042, 0.005, 0.032), color: Palette.timber)
                    $0.box(center: Vec3(0, 0.004, 0), size: Vec3(0.036, 0.004, 0.026), color: Palette.madder)
                    for x in [Float(-0.0085), 0.0085] {
                        $0.box(center: Vec3(x, 0.0065, 0), size: Vec3(0.016, 0.002, 0.024), color: Palette.linen)
                    }
                }
            case 2:
                bench(at: Vec3(-0.15, 0, 0.13), length: 0.09)
                books(at: Vec3(-0.17, 0.027, 0.13), count: 3, turn: 0.1)
                // A lantern on its bracket by the library's door.
                near.beam(from: Vec3(0.022, 0.12, 0.058), to: Vec3(0.022, 0.12, 0.08), width: 0.004, color: Palette.iron)
                near.with(material: .glow) {
                    $0.place(.translation(Vec3(0.022, 0.092, 0.078))) {
                        $0.lathe([(0.0, 0.0), (0.009, 0.009), (0.0, 0.021)], sides: 5, color: Palette.candle)
                    }
                }
            default:
                bench(at: Vec3(0.13, 0, 0.055), length: 0.08)
                books(at: Vec3(0.15, 0.027, 0.055), count: 2, turn: -0.2)
                let chest = Vec3(-0.07, 0, 0.09)
                near.box(center: chest + Vec3(0, 0.014, 0), size: Vec3(0.042, 0.028, 0.026), color: Palette.timber)
                near.with(material: .metal) {
                    for x in [Float(-0.012), 0.012] {
                        $0.box(center: chest + Vec3(x, 0.014, 0), size: Vec3(0.004, 0.03, 0.028), color: Palette.iron)
                    }
                }
                for (index, z) in [Float(-0.006), 0.006].enumerated() {
                    near.limb(from: chest + Vec3(-0.018, 0.034 + Float(index) * 0.002, z), to: chest + Vec3(0.018, 0.034, z), radius: 0.005,
                              sides: 5, color: Palette.linen)
                }
            }
        }
        return model(name, b, rig: rig, machinery: machinery)
    }

    /// A dome on a short drum, an open slit facing +z.
    static func dome(_ b: inout MeshBuilder, at: Vec3, radius: Float, wall: Float, color: Vec3) {
        b.place(.translation(at)) {
            if wall > 0 {
                $0.lathe([(radius, -0.06), (radius, wall)], sides: 8, color: Palette.stonePale)
            }
            let rings: [(radius: Float, y: Float)] = (0...3).map { ring in
                let angle = Float(ring) / 3 * .pi / 2
                return (radius * 1.05 * Float(cos(Double(angle))), wall + radius * Float(sin(Double(angle))))
            }
            $0.tube(rings, sides: 8, color: color)
            $0.box(min: Vec3(-0.018, wall + radius * 0.2, radius * 0.75), max: Vec3(0.018, wall + radius * 1.02, radius * 1.02),
                   color: Palette.timberDark)
        }
    }

    /// Three bronze rings crossed about a point: the heavens' wheels.
    static func armillary(_ b: inout MeshBuilder, part: UInt16, at centre: Vec3, radius: Float) {
        b.with(part: part, material: .metal) {
            for (index, tilt) in [Mat4.identity, .rotationX(.pi / 2), .rotationZ(.pi / 2) * .rotationX(0.4)].enumerated() {
                $0.place(.translation(centre) * tilt) {
                    let r = radius * (1 - 0.08 * Float(index))
                    $0.tube([(r, -0.006), (r, 0.006)], sides: 10, color: index == 0 ? Palette.gold : Palette.bronze)
                    $0.tube([(r * 0.9, 0.006), (r * 0.9, -0.006)], sides: 10, color: Palette.bronze)
                }
            }
            $0.sphere(center: centre, radius: radius * 0.22, rings: 2, sides: 5, color: Palette.gold)
        }
    }
}
