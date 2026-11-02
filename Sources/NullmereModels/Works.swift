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
        case .sawpit: return Sawpit.model(level: level, name: name)
        case .quarry: return Quarry.model(level: level, name: name)
        case .saltworks: return Saltworks.model(level: level, name: name)
        case .musterHall: return MusterHall.model(level: level, name: name)
        case .walls: return WallWork.dress(Holds.walls(level: level, name: name), level: level)
        case .beacon: return Beacon.model(level: level, name: name)
        case .infirmary: return Infirmary.model(level: level, name: name)
        case .moonspire: return Moonspire.model(level: level, name: name)
        case .archive: return Archive.model(level: level, name: name)
        case .forge: return Forge.model(level: level, name: name)
        case .wayhouse: return Wayhouse.model(level: level, name: name)
        case .lodge: return Lodge.model(level: level, name: name)
        }
    }

    // MARK: Shared

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

    // MARK: Forge

    /// How high a Forge's chimney stands at a level.
    static func forgeChimneyHeight(_ level: Int) -> Float {
        [0.3, 0.36, 0.42, 0.5, 0.56][min(max(level, 1), 5) - 1]
    }

    /// Where smoke rises from a Forge's chimney.
    static func forgeChimney(_ level: Int) -> Vec3 {
        Vec3(-0.13, forgeChimneyHeight(level), -0.12)
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
