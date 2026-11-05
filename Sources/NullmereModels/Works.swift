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
        trade(kind, level: level, name: name)
    }

    /// The work itself, its family's own at its level.
    static func trade(_ kind: BuildingKind, level: Int, name: String) -> Model {
        switch kind {
        case .granary: return Art.work(Art.granaryFile, level: level, name: name)
        case .sawpit: return Art.work(Art.sawpitFile, level: level, name: name)
        case .quarry: return Art.work(Art.quarryFile, level: level, name: name)
        case .saltworks: return Art.work(Art.saltworksFile, level: level, name: name)
        case .musterHall: return Art.work(Art.musterHallFile, level: level, name: name)
        case .walls: return Art.walls(level: level, name: name)
        case .beacon: return Art.work(Art.beaconFile, level: level, name: name)
        case .infirmary: return Art.work(Art.infirmaryFile, level: level, name: name)
        case .moonspire: return Art.work(Art.moonspireFile, level: level, name: name)
        case .archive: return Art.work(Art.archiveFile, level: level, name: name)
        case .forge: return Art.work(Art.forgeFile, level: level, name: name)
        case .wayhouse: return Art.work(Art.wayhouseFile, level: level, name: name)
        case .lodge: return Art.work(Art.lodgeFile, level: level, name: name)
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

    // MARK: Infirmary

    /// Where the Infirmary's ward smokes, from the second level
    /// (Art/blender/infirmary.py builds its chimney there).
    static func infirmaryChimney(_ level: Int) -> Vec3? {
        switch level {
        case 2, 3: return Vec3(0.05, 0.22, -0.135)
        case 4: return Vec3(0.08, 0.22, -0.175)
        case 5: return Vec3(0.09, 0.24, -0.16)
        default: return nil
        }
    }

    // MARK: Saltworks

    /// Where the Saltworks' boiling house smokes, at the levels that have one
    /// (Art/blender/saltworks.py builds its chimney there).
    static func saltworksChimney(_ level: Int) -> Vec3? {
        guard (3...4).contains(level) else { return nil }
        return Vec3(-0.06, 0.25, -0.145)
    }
}
