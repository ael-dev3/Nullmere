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
        }
    }

    /// A round bin or tower under a cone.
    mutating func roundHouse(at: Vec3, radius: Float, height: Float, wall: Vec3, roof: Vec3, roofMaterial: Material = .plain,
                             roofHeight: Float? = nil, sides: Int = 8) {
        place(.translation(at)) {
            $0.lathe([(radius, -0.06), (radius, height)], sides: sides, color: wall)
            $0.with(material: roofMaterial) {
                $0.cone(sides: sides, radius: radius * 1.18, from: height, to: height + (roofHeight ?? radius * 1.5), color: roof)
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
            $0.with(material: .crystal) {
                $0.box(min: Vec3(-h * 0.92 * crust, 0.004, -h * 0.92 * crust), max: Vec3(h * 0.92 * crust, 0.012, h * 0.92 * crust),
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
        switch kind {
        case .granary: return granary(level, name)
        case .sawpit: return sawpit(level, name)
        case .quarry: return quarry(level, name)
        case .saltworks: return saltworks(level, name)
        case .musterHall: return musterHall(level, name)
        case .walls: return Holds.walls(level: level, name: name)
        case .beacon: return beacon(level, name)
        case .moonspire: return moonspire(level, name)
        }
    }

    static func model(_ name: String, _ b: MeshBuilder, rig: Rig = Rig(), machinery: Machinery? = nil) -> Model {
        guard let machinery else { return Model(name: name, mesh: b.mesh) }
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    // MARK: Granary

    static func granary(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31)
        switch level {
        case 1:
            // A small barn on staddle stones, against rats and the damp.
            for x in [Float(-0.1), 0.1] {
                for z in [Float(-0.06), 0.06] {
                    b.place(.translation(Vec3(x, 0, z))) {
                        $0.lathe([(0.022, 0), (0.014, 0.05), (0.036, 0.058), (0.036, 0.072)], sides: 5, color: Palette.stone)
                    }
                }
            }
            b.hall(at: Vec3(0, 0.072, 0), width: 0.27, depth: 0.19, height: 0.13, wall: Palette.timber, roof: Palette.thatch, pitch: 0.75)
            b.door(Vec3(0, 0.13, 0.096), width: 0.05, height: 0.08, facing: 0)
            b.beam(from: Vec3(0, 0, 0.2), to: Vec3(0, 0.08, 0.1), width: 0.05, depth: 0.012, color: Palette.timberPale)
            b.sack(at: Vec3(0.17, 0, 0.14), size: 0.035, seed: 1)
            b.sack(at: Vec3(0.21, 0, 0.09), size: 0.03, seed: 2)
        case 2:
            b.hall(at: Vec3(0, 0, -0.03), width: 0.34, depth: 0.21, height: 0.17, wall: Palette.timber, roof: Palette.thatch,
                   pitch: 0.75, footing: Palette.stoneDark)
            b.place(.translation(Vec3(0, 0, -0.17))) {
                $0.box(min: Vec3(-0.12, -0.02, -0.05), max: Vec3(0.12, 0.1, 0.04), color: Palette.timberGrey)
                $0.place(.rotationX(0.35)) {
                    $0.box(min: Vec3(-0.13, 0.1, -0.06), max: Vec3(0.13, 0.115, 0.05), color: Palette.thatch)
                }
            }
            b.door(Vec3(0, 0.08, 0.077), width: 0.07, height: 0.12, facing: 0)
            // A wattle bin under thatch for the overflow.
            b.roundHouse(at: Vec3(0.19, 0, 0.15), radius: 0.06, height: 0.13, wall: Palette.timberGrey, roof: Palette.thatch,
                         roofHeight: 0.09, sides: 7)
            for (index, at) in [Vec3(-0.06, 0, 0.16), Vec3(-0.11, 0, 0.13), Vec3(-0.17, 0, 0.15)].enumerated() {
                b.sack(at: at, size: 0.032, seed: UInt32(index))
            }
        case 3:
            b.hall(at: Vec3(-0.05, 0, -0.03), width: 0.3, depth: 0.21, height: 0.19, wall: Palette.stone, roof: Palette.slate,
                   footing: Palette.stoneDark)
            b.roundHouse(at: Vec3(0.18, 0, 0.12), radius: 0.07, height: 0.2, wall: Palette.timber, roof: Palette.thatch, roofHeight: 0.11)
            b.door(Vec3(-0.05, 0.08, 0.077), width: 0.07, height: 0.12, facing: 0)
            b.window(Vec3(-0.15, 0.13, 0.077), width: 0.03, height: 0.04, facing: 0)
            for (index, at) in [Vec3(-0.2, 0, 0.14), Vec3(-0.15, 0, 0.17), Vec3(0.02, 0, 0.15)].enumerated() {
                b.sack(at: at, size: 0.032, seed: UInt32(index + 4))
            }
        case 4:
            b.hall(at: Vec3(0, 0, -0.07), width: 0.36, depth: 0.2, height: 0.2, wall: Palette.stone, roof: Palette.slate,
                   footing: Palette.stoneDark)
            for x in [Float(-0.18), 0.18] {
                b.roundHouse(at: Vec3(x, 0, 0.15), radius: 0.068, height: 0.24, wall: Palette.stonePale, roof: Palette.slate,
                             roofHeight: 0.12)
            }
            b.door(Vec3(0, 0.08, 0.032), width: 0.07, height: 0.13, facing: 0)
            b.banner(at: Vec3(0.17, 0.2, -0.07), height: 0.2, width: 0.1, drop: 0.07, tail: true)
            b.sack(at: Vec3(0.0, 0, 0.12), size: 0.035, seed: 7)
            b.sack(at: Vec3(0.05, 0, 0.16), size: 0.03, seed: 8)
        default:
            // A granary hall raised above the rest, its bins roofed in the House's colour.
            b.hall(at: Vec3(0, 0, -0.08), width: 0.38, depth: 0.2, height: 0.22, wall: Palette.stonePale, roof: Palette.slate,
                   footing: Palette.stoneDark)
            b.hall(at: Vec3(0, 0.22, -0.08), width: 0.2, depth: 0.12, height: 0.1, wall: Palette.stonePale, roof: Palette.slate)
            for (x, z) in [(Float(-0.19), Float(0.15)), (0, 0.19), (0.19, 0.15)] {
                b.roundHouse(at: Vec3(x, 0, z), radius: 0.07, height: 0.27, wall: Palette.stone, roof: Palette.house,
                             roofMaterial: .house, roofHeight: 0.14)
            }
            for x in [Float(-0.12), 0.12] {
                b.window(Vec3(x, 0.14, 0.022), width: 0.03, height: 0.05, facing: 0)
            }
            b.beam(from: Vec3(0.19, 0.3, -0.08), to: Vec3(0.28, 0.3, -0.08), width: 0.025, color: Palette.timberDark)
            b.limb(from: Vec3(0.27, 0.3, -0.08), to: Vec3(0.27, 0.18, -0.08), radius: 0.003, sides: 3, color: Palette.linen)
            b.sack(at: Vec3(0.27, 0.12, -0.08), size: 0.03, seed: 9)
            b.banner(at: Vec3(0, 0.38, -0.08), height: 0.22, width: 0.14, drop: 0.09)
        }
        return model(name, b)
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
        var rig = Rig()
        var machinery: Machinery?
        switch level {
        case 1:
            trestle(&b, at: Vec3(0, 0, 0.04))
            // A lean-to of planks against the weather.
            for x in [Float(-0.14), 0.14] {
                b.limb(from: Vec3(x, 0, -0.12), to: Vec3(x, 0.2, -0.12), radius: 0.012, color: Palette.timber)
            }
            b.place(.translation(Vec3(0, 0.21, -0.14)) * .rotationX(0.5)) {
                $0.box(min: Vec3(-0.17, 0, -0.08), max: Vec3(0.17, 0.014, 0.1), color: Palette.timberGrey)
            }
            b.planks(at: Vec3(-0.08, 0, -0.2), length: 0.24, layers: 3)
        case 2:
            trestle(&b, at: Vec3(0, 0, 0.02))
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
            }
            if level >= 5 {
                b.banner(at: Vec3(-0.07, storeys + 0.1, -0.04), height: 0.2, width: 0.13, drop: 0.08)
            }
        }
        return model(name, b, rig: rig, machinery: machinery)
    }

    // MARK: Quarry

    static func quarry(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31, color: Palette.stoneDark)
        // The outcrop, cut back in terraces as the quarry deepens.
        let lump = 0.09 + 0.025 * Float(min(level, 3))
        b.rock(center: Vec3(-0.02, 0.02, -0.13), size: Vec3(0.24, lump + 0.06, 0.15), rings: 3, sides: 7, jitter: 0.18, seed: 21,
               color: Palette.rock)
        let terraces = min(level, 3)
        for step in 0..<terraces {
            let y = Float(step) * 0.055
            let z = -0.02 - Float(step) * 0.045
            b.box(min: Vec3(-0.17 + Float(step) * 0.02, -0.02, z - 0.08), max: Vec3(0.15 - Float(step) * 0.02, y + 0.05, z),
                  color: Palette.stonePale)
        }
        b.blocks(at: Vec3(0.02, 0, 0.14), count: 3 + level, seed: 4)
        // A sledge for hauling.
        b.place(.translation(Vec3(-0.19, 0, 0.13)) * .rotationY(0.4)) {
            for x in [Float(-0.035), 0.035] {
                $0.box(min: Vec3(x - 0.008, 0, -0.07), max: Vec3(x + 0.008, 0.016, 0.07), color: Palette.timberDark)
            }
            $0.box(min: Vec3(-0.05, 0.016, -0.06), max: Vec3(0.05, 0.026, 0.06), color: Palette.timber)
        }
        var rig = Rig()
        var machinery: Machinery?
        if level == 2 {
            // Shear legs over the face, a rope to a block.
            let top = Vec3(0.02, 0.32, 0.04)
            for foot in [Vec3(-0.1, 0, 0.12), Vec3(0.14, 0, 0.12), Vec3(0.02, 0.1, -0.12)] {
                b.limb(from: foot, to: top, radius: 0.011, color: Palette.timber)
            }
            b.limb(from: top, to: Vec3(0.02, 0.14, 0.04), radius: 0.003, sides: 3, color: Palette.linen)
            b.box(center: Vec3(0.02, 0.12, 0.04), size: Vec3(0.05, 0.04, 0.045), color: Palette.stonePale)
        } else if level >= 3 {
            // A treadwheel crane that slews to swing the blocks down.
            let mast = Vec3(0.16, 0, 0.0)
            let height: Float = 0.34 + 0.08 * Float(level - 3), reach: Float = 0.2 + 0.03 * Float(level - 3)
            let crane = rig.add("crane", pivot: mast)
            b.with(part: crane) {
                $0.limb(from: mast, to: mast + Vec3(0, height, 0), radius: 0.016, color: Palette.timberDark)
                $0.beam(from: mast + Vec3(0.02, height - 0.1, 0.03), to: mast + Vec3(-reach, height + 0.03, 0.03), width: 0.018,
                        color: Palette.timber)
                $0.limb(from: mast + Vec3(0, height, 0), to: mast + Vec3(-reach * 0.6, height - 0.02, 0.03), radius: 0.006, color: Palette.timber)
                $0.limb(from: mast + Vec3(-reach, height + 0.02, 0.03), to: mast + Vec3(-reach, height - 0.16, 0.03), radius: 0.003,
                        sides: 3, color: Palette.linen)
                $0.box(center: mast + Vec3(-reach, height - 0.18, 0.03), size: Vec3(0.05, 0.04, 0.045), color: Palette.stonePale)
                if level >= 5 {
                    $0.flag(at: mast + Vec3(0, height + 0.12, 0), width: 0.12, height: 0.08, turn: .pi / 2, tail: true)
                    $0.limb(from: mast + Vec3(0, height, 0), to: mast + Vec3(0, height + 0.13, 0), radius: 0.006, color: Palette.timberDark)
                }
            }
            // Its treadwheel, turning.
            let hub = mast + Vec3(0.02, 0.1, -0.12)
            let wheel = rig.add("wheel", pivot: hub)
            b.with(part: wheel) {
                $0.wheel(center: hub, radius: 0.09, width: 0.04, spokes: 3, color: Palette.timber, rim: Palette.timberDark)
            }
            b.limb(from: mast + Vec3(-0.03, 0, -0.12), to: hub, radius: 0.01, color: Palette.timberDark)
            machinery = Machinery(wheels: [.init(part: wheel, axis: Vec3(1, 0, 0), turns: 1)],
                                  swings: [.init(part: crane, axis: Vec3(0, 1, 0), angle: 0.9)], parts: rig.count)
            if level >= 4 {
                // A mason's shed.
                b.hall(at: Vec3(-0.15, 0, 0.14), width: 0.12, depth: 0.1, height: 0.11, wall: Palette.stonePale, roof: Palette.slate,
                       turn: 0.5)
            }
            if level >= 5 {
                b.window(Vec3(-0.125, 0.07, 0.185), width: 0.025, height: 0.035, facing: 0.5)
            }
        }
        return model(name, b, rig: rig, machinery: machinery)
    }

    // MARK: Saltworks

    static func saltworks(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31, color: Palette.saltCrust.mix(Palette.earth, 0.6))
        let pans: [Vec3] = level == 1 ? [Vec3(-0.08, 0, 0.1), Vec3(0.08, 0, 0.1)]
            : [Vec3(-0.09, 0, 0.17), Vec3(0.08, 0, 0.17), Vec3(-0.17, 0, 0.03), Vec3(0.17, 0, 0.03)]
        for (index, pan) in pans.enumerated() {
            b.saltPan(at: pan, size: 0.13, crust: index % 2 == 0 ? 1 : 0.8)
        }
        var rig = Rig()
        var machinery: Machinery?
        switch level {
        case 1:
            b.saltHeap(at: Vec3(0.0, 0, -0.08), radius: 0.07, height: 0.08)
            b.beam(from: Vec3(0.15, 0, -0.12), to: Vec3(0.1, 0.2, -0.05), width: 0.012, color: Palette.timberPale)
            b.box(center: Vec3(0.1, 0.2, -0.05), size: Vec3(0.08, 0.012, 0.02), color: Palette.timberPale)
        default:
            // A boiling house over a furnace whose mouth glows.
            let width: Float = level >= 4 ? 0.26 : 0.18 + 0.04 * Float(level - 2)
            b.hall(at: Vec3(0, 0, -0.14), width: width, depth: 0.13, height: 0.13 + 0.02 * Float(level),
                   wall: level >= 4 ? Palette.stonePale : Palette.timberGrey, roof: Palette.slate, pitch: 0.6,
                   footing: Palette.stoneDark)
            let fire = rig.add("fire", pivot: Vec3(0.04, 0.03, -0.073))
            b.with(part: fire, material: .glow) {
                $0.box(center: Vec3(0.04, 0.035, -0.073), size: Vec3(0.045, 0.045, 0.006), color: Palette.fire)
            }
            machinery = Machinery(flames: [fire], parts: rig.count)
            let flue = saltChimney(level)
            b.box(min: Vec3(flue.x - 0.025, 0, flue.z - 0.025), max: Vec3(flue.x + 0.025, flue.y, flue.z + 0.025), color: Palette.stoneDark)
            b.saltHeap(at: Vec3(0.0, 0, 0.04), radius: 0.06, height: 0.07)
            if level >= 3 {
                b.saltHeap(at: Vec3(0.12, 0, -0.03), radius: 0.05, height: 0.06)
                for index in 0..<3 {
                    b.sack(at: Vec3(-0.06 + Float(index) * 0.04, 0, -0.04), size: 0.022, seed: UInt32(index + 30), color: Palette.linen)
                }
            }
            if level >= 4 {
                // Moonsalt crystals stacked to dry.
                b.with(material: .crystal) {
                    for index in 0..<3 {
                        $0.box(center: Vec3(0.2, 0.025 + Float(index) * 0.045, -0.14), size: Vec3(0.06, 0.04, 0.06), turn: Float(index) * 0.4,
                               color: Palette.moonsalt)
                    }
                }
            }
            if level >= 5 {
                // A pale tower of salt-white stone, a crystal at its crown.
                b.roundHouse(at: Vec3(-0.19, 0, -0.17), radius: 0.06, height: 0.42, wall: Palette.stoneWhite, roof: Palette.house,
                             roofMaterial: .house, roofHeight: 0.1, sides: 6)
                b.with(material: .crystal) {
                    $0.place(.translation(Vec3(-0.19, 0.52, -0.17))) {
                        $0.prism(sides: 6, radius: 0.03, from: 0, to: 0.06, color: Palette.moonsalt)
                        $0.cone(sides: 6, radius: 0.03, from: 0.06, to: 0.14, color: Palette.moonsalt)
                    }
                }
                b.banner(at: Vec3(0.12, 0.2, -0.14), height: 0.16, width: 0.11, drop: 0.07, tail: true)
            }
        }
        return model(name, b, rig: rig, machinery: machinery)
    }

    /// The top of a saltworks' furnace chimney, from its second level.
    static func saltChimney(_ level: Int) -> Vec3 {
        let width: Float = level >= 4 ? 0.26 : 0.18 + 0.04 * Float(level - 2)
        return Vec3(-width / 2 + 0.035, 0.3 + 0.03 * Float(level), -0.16)
    }

    // MARK: Muster hall

    static func musterHall(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.31)
        switch level {
        case 1:
            b.hall(at: Vec3(0, 0, -0.1), width: 0.4, depth: 0.17, height: 0.14, wall: Palette.timber, roof: Palette.thatch, pitch: 0.75)
            b.door(Vec3(0, 0.07, -0.013), width: 0.06, height: 0.1, facing: 0)
        case 2:
            b.hall(at: Vec3(0, 0, -0.1), width: 0.4, depth: 0.18, height: 0.17, wall: Palette.timberGrey, roof: Palette.slate,
                   footing: Palette.stone)
            b.door(Vec3(0, 0.08, -0.008), width: 0.07, height: 0.12, facing: 0)
            b.banner(at: Vec3(0.2, 0, 0.0), height: 0.36, width: 0.12, drop: 0.14)
            // An archery butt.
            b.place(.translation(Vec3(-0.2, 0, 0.16)) * .rotationY(0.5)) {
                $0.beam(from: Vec3(0, 0, -0.03), to: Vec3(0, 0.12, 0), width: 0.012, color: Palette.timber)
                $0.place(.translation(Vec3(0, 0.12, 0.005)) * .rotationX(.pi / 2)) {
                    $0.lathe([(0.055, -0.015), (0.055, 0.015)], sides: 8, color: Palette.straw)
                    $0.with(material: .house) {
                        $0.lathe([(0.025, -0.017), (0.025, 0.017)], sides: 6, color: Palette.house)
                    }
                }
            }
        default:
            b.hall(at: Vec3(0.04, 0, -0.1), width: 0.34, depth: 0.19, height: 0.19, wall: Palette.stone, roof: Palette.slate,
                   footing: Palette.stoneDark)
            // A square tower at its end, flying the House's banner.
            b.box(min: Vec3(-0.22, -0.04, -0.17), max: Vec3(-0.1, 0.42, -0.05), color: Palette.stone)
            b.merlons(from: Vec3(-0.22, 0.42, -0.17), to: Vec3(-0.1, 0.42, -0.17), count: 2, size: Vec3(0.035, 0.04, 0.03), color: Palette.stonePale)
            b.merlons(from: Vec3(-0.22, 0.42, -0.05), to: Vec3(-0.1, 0.42, -0.05), count: 2, size: Vec3(0.035, 0.04, 0.03), color: Palette.stonePale)
            b.banner(at: Vec3(-0.16, 0.42, -0.11), height: 0.24, width: 0.16, drop: 0.11)
            b.window(Vec3(-0.16, 0.3, -0.05), width: 0.025, height: 0.05, facing: 0)
            for x in [Float(-0.04), 0.12] {
                b.window(Vec3(x, 0.12, -0.003), width: 0.03, height: 0.05, facing: 0)
            }
            b.door(Vec3(0.04, 0.08, -0.003), width: 0.07, height: 0.13, facing: 0)
            for x in [Float(-0.06), 0.16] {
                b.banner(at: Vec3(x, 0, 0.06), height: 0.26, width: 0.07, drop: 0.12, turn: 0)
            }
        }
        // The yard: a pell to strike at and a rack of spears.
        b.limb(from: Vec3(0.13, -0.02, 0.15), to: Vec3(0.13, 0.15, 0.15), radius: 0.018, color: Palette.timberDark)
        b.place(.translation(Vec3(-0.08, 0, 0.17))) {
            $0.box(min: Vec3(-0.07, 0.07, -0.01), max: Vec3(0.07, 0.085, 0.01), color: Palette.timber)
            for x in [Float(-0.06), 0.06] {
                $0.limb(from: Vec3(x, 0, 0), to: Vec3(x, 0.09, 0), radius: 0.008, color: Palette.timber)
            }
            for index in 0..<4 {
                let x = Float(index) * 0.035 - 0.052
                $0.limb(from: Vec3(x, 0, -0.012), to: Vec3(x + 0.01, 0.22, 0.01), radius: 0.005, sides: 3, color: Palette.timberDark)
            }
        }
        return model(name, b)
    }

    // MARK: Beacon

    static func beacon(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.2, color: Palette.stoneDark)
        var rig = Rig()
        let top: Float
        switch level {
        case 1:
            // Four posts braced into a tower, a fire basket on top.
            top = 0.5
            let feet = [Vec3(-0.1, 0, -0.1), Vec3(0.1, 0, -0.1), Vec3(0.1, 0, 0.1), Vec3(-0.1, 0, 0.1)]
            for (index, foot) in feet.enumerated() {
                b.limb(from: foot - Vec3(0, 0.05, 0), to: foot * 0.55 + Vec3(0, top, 0), radius: 0.014, color: Palette.timber)
                let next = feet[(index + 1) % 4]
                b.limb(from: foot + Vec3(0, 0.05, 0), to: next * 0.75 + Vec3(0, top * 0.55, 0), radius: 0.007, color: Palette.timberPale)
            }
            b.box(min: Vec3(-0.075, top - 0.012, -0.075), max: Vec3(0.075, top + 0.006, 0.075), color: Palette.timberPale)
            b.with(material: .metal) {
                $0.place(.translation(Vec3(0, top, 0))) {
                    $0.tube([(0.035, 0.0), (0.065, 0.07)], sides: 6, color: Palette.iron)
                }
            }
        case 2:
            top = 0.66
            b.lathe([(0.12, -0.08), (0.1, top), (0.125, top + 0.02), (0.125, top + 0.05)], sides: 8, color: Palette.stone)
            b.merlonRing(radius: 0.115, base: top + 0.05, count: 6, size: Vec3(0.04, 0.045, 0.03), color: Palette.stonePale)
            b.door(Vec3(0, 0.07, 0.11), width: 0.05, height: 0.1, facing: 0)
            b.with(material: .metal) {
                $0.place(.translation(Vec3(0, top + 0.04, 0))) {
                    $0.lathe([(0.012, 0), (0.012, 0.05), (0.04, 0.06), (0.07, 0.1)], sides: 6, color: Palette.iron)
                }
            }
            b.banner(at: Vec3(0.09, top + 0.05, -0.05), height: 0.24, width: 0.11, drop: 0.07, tail: true)
        default:
            // A tall tower with a lantern of moonsalt pillars round a great fire.
            top = 0.9
            b.lathe([(0.15, -0.08), (0.12, 0.12), (0.1, top), (0.135, top + 0.03)], sides: 8, color: Palette.stone)
            for index in 0..<4 {
                let angle = Float(index) * .pi / 2 + .pi / 4
                b.place(.rotationY(angle)) {
                    $0.box(min: Vec3(-0.03, -0.06, 0.1), max: Vec3(0.03, 0.24, 0.17), color: Palette.stoneDark)
                }
            }
            b.door(Vec3(0, 0.08, 0.135), width: 0.055, height: 0.11, facing: 0)
            b.window(Vec3(0, 0.5, 0.106), width: 0.025, height: 0.05, facing: 0)
            b.with(material: .crystal) {
                for index in 0..<6 {
                    let at = MeshBuilder.ring(0.105, top + 0.03, Float(index) * .pi / 3)
                    $0.place(.translation(at)) {
                        $0.prism(sides: 4, radius: 0.022, from: 0, to: 0.15, color: Palette.moonsalt, twist: Float(index))
                    }
                }
                $0.place(.translation(Vec3(0, top + 0.17, 0))) {
                    $0.lathe([(0.13, 0), (0.13, 0.025)], sides: 6, color: Palette.moonsalt)
                }
            }
            b.cone(sides: 6, radius: 0.13, from: top + 0.195, to: top + 0.32, color: Palette.slate)
            b.banner(at: Vec3(0, top + 0.31, 0), height: 0.2, width: 0.16, drop: 0.1)
        }
        // The fire, leaping.
        let flameFoot = Vec3(0, top + (level == 1 ? 0.03 : level == 2 ? 0.1 : 0.04), 0)
        let fire = rig.add("fire", pivot: flameFoot)
        b.with(part: fire, material: .glow) {
            $0.place(.translation(flameFoot)) {
                $0.cone(sides: 5, radius: level == 3 ? 0.065 : 0.055, to: level == 3 ? 0.13 : 0.11, color: Palette.fire)
                $0.cone(sides: 4, radius: 0.03, from: 0.02, to: level == 3 ? 0.17 : 0.15, color: Palette.candle, twist: 0.5)
            }
        }
        return model(name, b, rig: rig, machinery: Machinery(flames: [fire], parts: rig.count))
    }

    // MARK: Moonspire

    /// The great work, a white tower of moonsalt and stone raised in five
    /// stages: its foundations, then a drum, a tapering stage with a
    /// gallery, a slender upper stage ribbed in moonsalt, and its spire
    /// crowned with a great crystal that turns, lit from within.
    static func moonspire(_ level: Int, _ name: String) -> Model {
        var b = MeshBuilder()
        b.lathe([(0.31, -0.14), (0.31, 0.04), (0.28, 0.06)], sides: 10, color: Palette.stonePale)
        var rig = Rig()
        var machinery: Machinery?
        if level == 1 {
            // Foundations: a ring of white blocks set out, more waiting.
            for index in 0..<10 {
                let angle = Float(index) * .pi / 5
                b.box(center: MeshBuilder.ring(0.22, 0.1, angle), size: Vec3(0.07, 0.08, 0.05), turn: angle + .pi / 2,
                      color: Palette.stoneWhite)
            }
            b.blocks(at: Vec3(0.02, 0.06, 0.02), count: 6, seed: 11)
            b.saltHeap(at: Vec3(-0.08, 0.06, -0.06), radius: 0.06, height: 0.07)
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
            machinery = Machinery(wheels: [.init(part: crown, axis: Vec3(0, 1, 0), turns: 1)], parts: rig.count)
        }
        return model(name, b, rig: rig, machinery: machinery)
    }

    // MARK: Study

    /// Where a House's scholars study the lake's lore: a scriptorium, then
    /// a domed library, a tower with an armillary on its roof, an
    /// observatory with a glass, and a great observatory between two wings.
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
            for x in [Float(-0.16), -0.06, 0.04] {
                b.window(Vec3(x, 0.11, 0.057), width: 0.03, height: 0.06, facing: 0)
            }
        default:
            // A library hall, and a tower with an armillary turning on its roof.
            let tower: Float = level == 3 ? 0.5 : 0.62
            b.hall(at: Vec3(0.06, 0, -0.06), width: 0.3, depth: 0.18, height: 0.18, wall: Palette.stone, roof: Palette.slate,
                   footing: Palette.stoneDark)
            for x in [Float(-0.02), 0.08, 0.18] {
                b.window(Vec3(x, 0.11, 0.032), width: 0.03, height: 0.06, facing: 0)
            }
            let towerAt = Vec3(-0.16, 0, 0.0)
            b.place(.translation(towerAt)) {
                $0.lathe([(0.11, -0.06), (0.1, tower), (0.12, tower + 0.02), (0.12, tower + 0.04)], sides: 8, color: Palette.stonePale)
                $0.window(Vec3(0, tower * 0.55, 0.1), width: 0.03, height: 0.06, facing: 0)
                $0.window(Vec3(0, tower * 0.8, 0.098), width: 0.03, height: 0.06, facing: 0)
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
