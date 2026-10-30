import Foundation
import NullmereCore

/// What an alliance raises on its land for its stores: a storehouse, and
/// a yard for each store, each with the alliance's colour about it. They
/// face +z and fill the heart of their hex.
enum Stores {
    // MARK: The storehouse

    /// The barn's walls, from end to end and front to back.
    static let barnWidth: Float = 0.6, barnDepth: Float = 0.28, barnHeight: Float = 0.24
    /// Where the barn stands, a little back from the hex's heart.
    static let barnAt = Vec3(0, 0, -0.08)
    /// The top of its footing, laid before the barn rises.
    static let footing: Float = 0.04

    /// A long barn of timber on a footing of stone, its high roof in the
    /// alliance's colour; great doors in its front strapped with iron, a
    /// hoist at its loft door with a sack on the rope, a lean-to of stone at
    /// its west end; and before it, sacks, barrels, planks, dressed stone
    /// and salt under canvas, lanterns at the door and the alliance's
    /// banner at its corner.
    static func storehouse(name: String) -> Model {
        var b = MeshBuilder()
        b.pad(radius: 0.62, sides: 6)
        let front = barnAt.z + barnDepth / 2, back = barnAt.z - barnDepth / 2
        let east = barnWidth / 2, west = -barnWidth / 2
        b.hall(at: barnAt, width: barnWidth, depth: barnDepth, height: barnHeight, wall: Palette.timber, roof: Palette.house,
               roofMaterial: .house, pitch: 0.75, footing: Palette.stoneDark)
        // Its frame: posts down front and back, a rail between them.
        for z in [front + 0.004, back - 0.004] {
            for x in stride(from: west, through: east, by: barnWidth / 6) {
                b.box(center: Vec3(x, barnHeight / 2 + 0.02, z), size: Vec3(0.024, barnHeight - 0.03, 0.012), color: Palette.timberDark)
            }
            b.box(center: Vec3(0, barnHeight * 0.55, z), size: Vec3(barnWidth, 0.018, 0.012), color: Palette.timberDark)
        }
        // The great doors, two leaves under a lintel, strapped and studded with iron.
        for leaf in [Float(-1), 1] {
            b.door(Vec3(leaf * 0.045, 0.1, front + 0.01), width: 0.085, height: 0.17, facing: 0)
            b.with(material: .metal) {
                for y in [Float(0.05), 0.15] {
                    $0.box(center: Vec3(leaf * 0.045, y, front + 0.022), size: Vec3(0.08, 0.012, 0.006), color: Palette.iron)
                }
                $0.sphere(center: Vec3(leaf * 0.012, 0.1, front + 0.024), radius: 0.008, rings: 2, sides: 4, color: Palette.iron)
            }
        }
        b.box(center: Vec3(0, 0.195, front + 0.012), size: Vec3(0.2, 0.025, 0.02), color: Palette.timberDark)
        // Lit windows either side of the doors.
        for x in [Float(-0.2), 0.2] {
            b.window(Vec3(x, 0.15, front + 0.006), width: 0.04, height: 0.05, facing: 0)
        }
        // The loft door at its east gable, a beam over it with a pulley, a sack on the rope.
        let loft = Vec3(east + 0.006, barnHeight + 0.05, barnAt.z)
        b.door(loft, width: 0.07, height: 0.08, facing: .pi / 2)
        b.beam(from: Vec3(east - 0.02, barnHeight + 0.13, barnAt.z), to: Vec3(east + 0.12, barnHeight + 0.13, barnAt.z), width: 0.022,
               color: Palette.timberDark)
        // Its pulley turns as the sack is hauled, the sack swinging on the rope.
        var rig = Rig()
        let block = Vec3(east + 0.1, barnHeight + 0.105, barnAt.z)
        let pulley = rig.add("pulley", pivot: block)
        b.with(part: pulley, material: .metal) {
            $0.wheel(center: block, radius: 0.018, width: 0.01, spokes: 4, color: Palette.iron)
        }
        let load = rig.add("load", pivot: block)
        b.with(part: load) {
            $0.limb(from: block + Vec3(0, -0.015, 0.018), to: Vec3(block.x, 0.1, barnAt.z + 0.018), radius: 0.003, color: Palette.canvas)
            $0.sack(at: Vec3(block.x, 0.03, barnAt.z + 0.018), size: 0.04, seed: 41)
        }
        // A lean-to of stone at its west end under slate.
        b.hall(at: Vec3(west - 0.075, 0, barnAt.z), width: 0.14, depth: 0.22, height: 0.13, wall: Palette.stone, roof: Palette.slate,
               pitch: 0.45, turn: .pi / 2)
        // The yard before it: sacks of grain, barrels, planks, dressed stone,
        // and moonsalt under a canvas.
        for (index, at) in [Vec3(-0.3, 0, 0.2), Vec3(-0.24, 0, 0.24), Vec3(-0.27, 0.05, 0.22), Vec3(-0.19, 0, 0.19)].enumerated() {
            b.sack(at: at, size: 0.034, seed: UInt32(50 + index))
        }
        for (index, at) in [Vec3(0.2, 0, 0.17), Vec3(0.26, 0, 0.2), Vec3(0.23, 0, 0.26)].enumerated() {
            barrel(&b, at: at, turn: Float(index) * 0.7)
        }
        b.planks(at: Vec3(0.36, 0, 0.0), length: 0.2, layers: 4, turn: .pi / 2)
        b.blocks(at: Vec3(-0.08, 0, 0.32), count: 5, seed: 31)
        b.saltHeap(at: Vec3(0.08, 0, 0.3), radius: 0.045, height: 0.05)
        // Lanterns on posts at the door.
        for x in [Float(-0.13), 0.13] {
            b.limb(from: Vec3(x, 0, front + 0.06), to: Vec3(x, 0.2, front + 0.06), radius: 0.008, color: Palette.timberDark)
            b.with(material: .glow) {
                $0.box(center: Vec3(x, 0.215, front + 0.06), size: Vec3(0.026, 0.034, 0.026), color: Palette.candle)
            }
            b.with(material: .metal) {
                $0.place(.translation(Vec3(x, 0.232, front + 0.06))) { $0.cone(sides: 4, radius: 0.022, to: 0.02, color: Palette.iron) }
            }
        }
        // A ridge beam along its roof, a louvre at its middle where the air goes in and out.
        let ridge = barnHeight + barnDepth * 0.75
        b.beam(from: Vec3(west - 0.02, ridge + 0.006, barnAt.z), to: Vec3(east + 0.02, ridge + 0.006, barnAt.z), width: 0.02,
               color: Palette.timberDark)
        b.box(center: Vec3(0, ridge + 0.03, barnAt.z), size: Vec3(0.08, 0.05, 0.07), color: Palette.timberGrey)
        b.place(.translation(Vec3(0, ridge + 0.055, barnAt.z))) {
            $0.hipRoof(width: 0.11, depth: 0.1, base: 0, height: 0.04, color: Palette.slate)
        }
        // The alliance's banner at its west corner, flying clear of the roof.
        b.banner(at: Vec3(west - 0.16, 0, front + 0.12), height: 0.62, width: 0.16, drop: 0.24, turn: .pi, tail: true)
        return Works.model(name, b, rig: rig, machinery: Machinery(wheels: [.init(part: pulley, axis: Vec3(1, 0, 0), turns: 1)],
                                                                   swings: [.init(part: load, axis: Vec3(1, 0, 0), angle: 0.12)],
                                                                   parts: rig.count))
    }

    /// A barrel of timber hooped with iron.
    static func barrel(_ b: inout MeshBuilder, at: Vec3, turn: Float) {
        b.place(.translation(at) * .rotationY(turn)) {
            $0.lathe([(0.026, 0), (0.032, 0.035), (0.026, 0.07)], sides: 7, color: Palette.timberPale)
            $0.with(material: .metal) {
                for y in [Float(0.012), 0.058] {
                    $0.lathe([(0.03, y - 0.004), (0.031, y + 0.004)], sides: 7, color: Palette.iron)
                }
            }
        }
    }

    // MARK: Yards

    /// An alliance's yard of a store.
    static func yard(_ store: Resource, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        let machinery: Machinery?
        switch store {
        case .grain:
            tilledAcre(&b)
            machinery = nil
        case .timber: machinery = timberYard(&b, rig: &rig)
        case .stone: machinery = quarry(&b, rig: &rig)
        case .moonsalt: machinery = saltWorks(&b, rig: &rig)
        }
        return Works.model(name, b, rig: rig, machinery: machinery)
    }

    /// A pennant on a pole in the alliance's colour, set where a yard's
    /// gate would be.
    static func pennant(_ b: inout MeshBuilder, at foot: Vec3) {
        b.place(.translation(foot)) {
            $0.lathe([(0.04, -0.03), (0.035, 0.02), (0.0, 0.035)], sides: 5, color: Palette.stoneDark)
        }
        b.banner(at: foot, height: 0.5, width: 0.13, drop: 0.08, turn: 0, tail: true)
    }

    /// A fence of posts and two rails from one post to the next.
    static func fence(_ b: inout MeshBuilder, _ posts: [Vec3]) {
        for post in posts {
            b.box(center: post + Vec3(0, 0.04, 0), size: Vec3(0.016, 0.1, 0.016), color: Palette.timberDark)
        }
        for (a, c) in zip(posts, posts.dropFirst()) {
            for y in [Float(0.035), 0.07] {
                b.beam(from: a + Vec3(0, y, 0), to: c + Vec3(0, y, 0), width: 0.008, depth: 0.012, color: Palette.timberGrey)
            }
        }
    }

    /// A tilled acre: furrows of dark earth fenced about, half grown with
    /// grain, half in stooks; a granary on staddle stones roofed in the
    /// alliance's colour, and a scarecrow keeping the birds off.
    static func tilledAcre(_ b: inout MeshBuilder) {
        b.box(min: Vec3(-0.52, -0.08, -0.42), max: Vec3(0.52, 0.006, 0.42), color: Palette.loam)
        // Furrows ridged across it.
        for row in 0..<9 {
            let z = Float(row) * 0.09 - 0.36
            b.beam(from: Vec3(-0.46, 0.012, z), to: Vec3(0.12, 0.012, z), width: 0.04, depth: 0.03, color: Palette.earth)
        }
        // Grain standing in the near half, swaying.
        b.with(material: .foliage, sway: 0.8) {
            $0.swayRange = (0.0, 0.1)
            for row in 0..<5 {
                let z = Float(row) * 0.09 - 0.36
                let jitter = Noise.unit(Int32(row), 5, 77)
                $0.beam(from: Vec3(-0.44, 0.04, z), to: Vec3(-0.06, 0.04, z), width: 0.06, depth: 0.08 + 0.02 * jitter,
                        color: row % 2 == 0 ? Palette.grain : Palette.straw)
            }
        }
        // Stooks of sheaves in the reaped half.
        for (index, at) in [Vec3(-0.36, 0, 0.12), Vec3(-0.22, 0, 0.18), Vec3(-0.08, 0, 0.1), Vec3(-0.3, 0, 0.3)].enumerated() {
            b.place(.translation(at) * .rotationY(Float(index) * 0.9)) {
                $0.lathe([(0.045, -0.01), (0.036, 0.07), (0.052, 0.09), (0, 0.14)], sides: 5, color: Palette.straw)
            }
        }
        // The granary on its staddle stones.
        let granary = Vec3(0.3, 0, -0.16)
        for x in [Float(-0.07), 0.07] {
            for z in [Float(-0.05), 0.05] {
                b.place(.translation(granary + Vec3(x, 0, z))) {
                    $0.lathe([(0.02, 0), (0.013, 0.045), (0.032, 0.052), (0.032, 0.064)], sides: 5, color: Palette.stone)
                }
            }
        }
        b.hall(at: granary + Vec3(0, 0.064, 0), width: 0.2, depth: 0.15, height: 0.11, wall: Palette.timber, roof: Palette.house,
               roofMaterial: .house, pitch: 0.8)
        b.door(granary + Vec3(0, 0.12, 0.077), width: 0.045, height: 0.07, facing: 0)
        b.sack(at: Vec3(0.24, 0, 0.0), size: 0.032, seed: 61)
        b.sack(at: Vec3(0.3, 0, 0.03), size: 0.028, seed: 62)
        // A scarecrow in the standing grain, ragged and leaning.
        b.place(.translation(Vec3(-0.22, 0, -0.18)) * .rotationZ(0.08)) {
            $0.limb(from: Vec3(0, 0, 0), to: Vec3(0, 0.2, 0), radius: 0.006, color: Palette.timberDark)
            $0.beam(from: Vec3(-0.06, 0.15, 0), to: Vec3(0.06, 0.15, 0), width: 0.008, color: Palette.timberDark)
            $0.with(sway: 0.6) {
                $0.box(center: Vec3(0, 0.135, 0), size: Vec3(0.1, 0.06, 0.02), color: Palette.wool)
            }
            $0.sphere(center: Vec3(0, 0.205, 0), radius: 0.02, rings: 2, sides: 5, color: Palette.straw)
            $0.place(.translation(Vec3(0, 0.22, 0))) { $0.cone(sides: 5, radius: 0.03, to: 0.03, color: Palette.leatherDark) }
        }
        // Fenced on three sides, open toward its gate.
        fence(&b, [Vec3(-0.5, 0, 0.4), Vec3(-0.5, 0, -0.4), Vec3(0.5, 0, -0.4), Vec3(0.5, 0, 0.4)])
        pennant(&b, at: Vec3(0.44, 0, 0.36))
    }

    /// A timber yard: logs stacked in tiers, a sawpit with a trunk across
    /// its trestles and the long saw in it, sheerlegs lifting a log, stumps
    /// and sawn planks, and a woodshed roofed in the alliance's colour.
    static func timberYard(_ b: inout MeshBuilder, rig: inout Rig) -> Machinery {
        b.box(min: Vec3(-0.5, -0.08, -0.42), max: Vec3(0.5, 0.004, 0.42), color: Palette.yard)
        // Logs stacked three tiers high, held by stakes.
        for tier in 0..<3 {
            for index in 0..<(4 - tier) {
                let y = 0.03 + Float(tier) * 0.05
                let z = -0.34 + Float(index) * 0.06 + Float(tier) * 0.03
                b.log(from: Vec3(-0.46, y, z), to: Vec3(-0.08, y, z), radius: 0.028)
            }
        }
        for x in [Float(-0.44), -0.1] {
            b.box(center: Vec3(x, 0.08, -0.4), size: Vec3(0.014, 0.18, 0.014), color: Palette.timberDark)
        }
        // The sawpit: a trunk on two trestles over a pit, the saw standing in its cut.
        b.box(min: Vec3(0.02, -0.05, -0.04), max: Vec3(0.34, 0.002, 0.06), color: Palette.loam)
        for x in [Float(0.06), 0.3] {
            for z in [Float(-0.05), 0.07] {
                b.limb(from: Vec3(x, 0, z), to: Vec3(x, 0.09, 0.01), radius: 0.008, color: Palette.timberDark)
            }
        }
        b.log(from: Vec3(-0.02, 0.1, 0.01), to: Vec3(0.4, 0.1, 0.01), radius: 0.03)
        b.with(material: .metal) {
            $0.box(center: Vec3(0.2, 0.08, 0.01), size: Vec3(0.008, 0.2, 0.05), color: Palette.steel)
        }
        b.box(center: Vec3(0.2, 0.19, 0.01), size: Vec3(0.012, 0.012, 0.08), color: Palette.timberPale)
        // Sheerlegs over a log, the log hanging from its rope.
        let apex = Vec3(0.3, 0.42, -0.26)
        for foot in [Vec3(0.18, 0, -0.34), Vec3(0.42, 0, -0.34), Vec3(0.3, 0, -0.1)] {
            b.limb(from: foot, to: apex, radius: 0.01, color: Palette.timber)
        }
        let hanging = rig.add("hanging", pivot: apex)
        b.with(part: hanging) {
            $0.limb(from: apex, to: apex - Vec3(0, 0.26, 0), radius: 0.003, color: Palette.canvas)
            $0.log(from: Vec3(0.18, 0.15, -0.26), to: Vec3(0.42, 0.15, -0.26), radius: 0.024)
        }
        // Stumps and sawn planks.
        for at in [Vec3(-0.36, 0, 0.18), Vec3(-0.18, 0, 0.3)] {
            b.place(.translation(at)) {
                $0.lathe([(0.035, -0.04), (0.03, 0.035)], sides: 5, color: Palette.bark, colors: [Palette.bark, Palette.timberPale])
            }
        }
        b.planks(at: Vec3(0.05, 0, 0.28), length: 0.24, layers: 3)
        // A woodshed against the yard's back, open to the front.
        b.hall(at: Vec3(0.3, 0, 0.26), width: 0.2, depth: 0.14, height: 0.12, wall: Palette.timberGrey, roof: Palette.house,
               roofMaterial: .house, pitch: 0.7, turn: .pi / 2)
        b.with(material: .metal) {
            $0.box(center: Vec3(-0.17, 0.05, 0.31), size: Vec3(0.012, 0.03, 0.05), turn: 0.6, color: Palette.iron)
        }
        b.beam(from: Vec3(-0.18, 0.035, 0.3), to: Vec3(-0.12, 0.13, 0.35), width: 0.01, color: Palette.timberPale)
        pennant(&b, at: Vec3(0.44, 0, 0.38))
        return Machinery(swings: [.init(part: hanging, axis: Vec3(1, 0, 0), angle: 0.18)], parts: rig.count)
    }

    /// A quarry: a face cut back in benches, a derrick swinging a block
    /// on its rope, dressed blocks stacked for carting, rubble, a sledge
    /// with a block on it, and the masons' lodge roofed in the alliance's
    /// colour.
    static func quarry(_ b: inout MeshBuilder, rig: inout Rig) -> Machinery {
        b.box(min: Vec3(-0.5, -0.08, -0.42), max: Vec3(0.5, 0.004, 0.42), color: Palette.stoneDark.mix(Palette.yard, 0.5))
        // The face, cut back in benches toward the back of the hex.
        for bench in 0..<4 {
            let y = Float(bench) * 0.07
            let z = -0.18 - Float(bench) * 0.055
            b.box(min: Vec3(-0.46 + Float(bench) * 0.03, -0.04, -0.42), max: Vec3(0.2 - Float(bench) * 0.02, y + 0.07, z),
                  color: bench % 2 == 0 ? Palette.stonePale : Palette.stone)
        }
        b.rock(center: Vec3(-0.36, 0.26, -0.38), size: Vec3(0.14, 0.12, 0.08), rings: 3, sides: 6, jitter: 0.2, seed: 141, color: Palette.rock)
        // The derrick: a mast, a boom out over the yard, a block on its rope.
        let mast = Vec3(0.3, 0, -0.22)
        b.limb(from: mast, to: mast + Vec3(0, 0.5, 0), radius: 0.013, color: Palette.timber)
        for stay in [Vec3(0.44, 0, -0.36), Vec3(0.46, 0, -0.06)] {
            b.limb(from: mast + Vec3(0, 0.5, 0), to: stay, radius: 0.002, color: Palette.canvas)
        }
        let boom = rig.add("boom", pivot: mast)
        b.with(part: boom) {
            $0.limb(from: mast + Vec3(0, 0.08, 0), to: mast + Vec3(-0.26, 0.42, 0.12), radius: 0.009, color: Palette.timber)
            let end = mast + Vec3(-0.26, 0.42, 0.12)
            $0.limb(from: end, to: end - Vec3(0, 0.26, 0), radius: 0.003, color: Palette.canvas)
            $0.box(center: end - Vec3(0, 0.29, 0), size: Vec3(0.07, 0.05, 0.06), color: Palette.stonePale)
        }
        let hub = mast + Vec3(0.04, 0.12, 0)
        let windlass = rig.add("windlass", pivot: hub)
        b.with(part: windlass) {
            $0.wheel(center: hub, radius: 0.05, width: 0.012, spokes: 6, color: Palette.timberDark)
        }
        // Dressed blocks stacked for carting, and rubble.
        b.blocks(at: Vec3(-0.25, 0, 0.12), count: 9, seed: 151)
        b.blocks(at: Vec3(0.02, 0, 0.22), count: 6, seed: 152)
        for index in 0..<5 {
            let jitter = Noise.unit(Int32(index), 9, 153)
            b.rock(center: Vec3(-0.42 + Float(index) * 0.05, 0.02, -0.08 + jitter * 0.06), size: Vec3(0.035, 0.025, 0.03), rings: 2, sides: 4,
                   jitter: 0.3, seed: UInt32(160 + index), color: Palette.rock)
        }
        // A sledge with a block on it.
        b.place(.translation(Vec3(0.24, 0, 0.12)) * .rotationY(0.5)) {
            for x in [Float(-0.04), 0.04] {
                $0.box(min: Vec3(x - 0.008, 0, -0.09), max: Vec3(x + 0.008, 0.018, 0.09), color: Palette.timberDark)
            }
            $0.box(min: Vec3(-0.055, 0.018, -0.075), max: Vec3(0.055, 0.028, 0.075), color: Palette.timber)
            $0.box(center: Vec3(0, 0.06, 0), size: Vec3(0.08, 0.06, 0.1), color: Palette.stonePale)
        }
        // The masons' lodge.
        b.hall(at: Vec3(0.36, 0, 0.3), width: 0.18, depth: 0.13, height: 0.11, wall: Palette.stone, roof: Palette.house,
               roofMaterial: .house, pitch: 0.65)
        b.door(Vec3(0.36, 0.06, 0.367), width: 0.04, height: 0.07, facing: 0)
        pennant(&b, at: Vec3(-0.44, 0, 0.36))
        return Machinery(wheels: [.init(part: windlass, axis: Vec3(1, 0, 0), turns: 1)],
                         swings: [.init(part: boom, axis: Vec3(0, 1, 0), angle: 0.5)], parts: rig.count)
    }

    /// Where smoke rises from the salt works' boiling house.
    static let saltSmoke = Vec3(0.32, 0.36, 0.22)

    /// Salt works: pans of brine drying to moonsalt in rows, a brine well
    /// under its windlass, a boiling house with its fire under the pan and
    /// its chimney smoking, heaps of moonsalt and sacks of it, and the
    /// alliance's colour on the boiling house's roof.
    static func saltWorks(_ b: inout MeshBuilder, rig: inout Rig) -> Machinery {
        b.box(min: Vec3(-0.5, -0.08, -0.42), max: Vec3(0.5, 0.004, 0.42), color: Palette.saltCrust.mix(Palette.earth, 0.55))
        // Pans in rows, some crusted thick, some still wet.
        for row in 0..<2 {
            for column in 0..<3 {
                let at = Vec3(-0.36 + Float(column) * 0.2, 0, -0.26 + Float(row) * 0.2)
                b.saltPan(at: at, size: 0.17, crust: (row + column) % 2 == 0 ? 0.95 : 0.6)
            }
        }
        // The brine well and its windlass.
        let well = Vec3(0.26, 0, -0.24)
        b.place(.translation(well)) {
            $0.lathe([(0.07, -0.02), (0.07, 0.06), (0.055, 0.065), (0.055, 0.02)], sides: 8, color: Palette.stone)
        }
        for x in [Float(-0.07), 0.07] {
            b.box(center: well + Vec3(x, 0.09, 0), size: Vec3(0.014, 0.18, 0.014), color: Palette.timberDark)
        }
        let axle = well + Vec3(0, 0.16, 0)
        let crank = rig.add("windlass", pivot: axle)
        b.with(part: crank) {
            $0.limb(from: axle - Vec3(0.08, 0, 0), to: axle + Vec3(0.08, 0, 0), radius: 0.012, color: Palette.timber)
            $0.wheel(center: axle + Vec3(0.1, 0, 0), radius: 0.035, width: 0.01, spokes: 4, color: Palette.timberDark)
        }
        b.limb(from: well + Vec3(0, 0.15, 0), to: well + Vec3(0, 0.07, 0), radius: 0.003, color: Palette.canvas)
        b.place(.translation(well + Vec3(0, 0.05, 0))) {
            $0.lathe([(0.018, 0), (0.022, 0.03)], sides: 6, color: Palette.timberPale)
        }
        // The boiling house, its fire under the pan and its chimney.
        let house = Vec3(0.32, 0, 0.18)
        b.hall(at: house, width: 0.18, depth: 0.16, height: 0.13, wall: Palette.stone, roof: Palette.house, roofMaterial: .house, pitch: 0.7)
        b.box(center: Vec3(saltSmoke.x, 0.2, saltSmoke.z), size: Vec3(0.045, 0.32, 0.045), color: Palette.stoneDark)
        let fire = rig.add("fire", pivot: house + Vec3(0, 0.015, 0.083))
        b.with(part: fire, material: .glow) {
            $0.box(center: house + Vec3(0, 0.035, 0.083), size: Vec3(0.07, 0.04, 0.012), color: Palette.fire)
        }
        b.place(.translation(house + Vec3(-0.17, 0, 0.0))) {
            $0.lathe([(0.06, 0.0), (0.06, 0.04), (0.055, 0.045)], sides: 8, color: Palette.iron)
        }
        b.with(material: .crystal) {
            $0.place(.translation(house + Vec3(-0.17, 0.042, 0.0))) {
                $0.lathe([(0.05, 0), (0.0, 0.004)], sides: 8, color: Palette.moonsalt)
            }
        }
        // Heaps of moonsalt and sacks of it ready for carting.
        b.saltHeap(at: Vec3(-0.3, 0, 0.24), radius: 0.07, height: 0.09)
        b.saltHeap(at: Vec3(-0.16, 0, 0.3), radius: 0.055, height: 0.07)
        for (index, at) in [Vec3(0.0, 0, 0.26), Vec3(0.05, 0, 0.3), Vec3(0.02, 0.045, 0.28)].enumerated() {
            b.sack(at: at, size: 0.03, seed: UInt32(170 + index), color: Palette.linen)
        }
        pennant(&b, at: Vec3(-0.44, 0, 0.38))
        return Machinery(wheels: [.init(part: crank, axis: Vec3(1, 0, 0), turns: 1)], flames: [fire], parts: rig.count)
    }
}

extension HoldLayout {
    /// An alliance's storehouse on its hex: on the lowest of the ground
    /// under it, facing the lake's heart as a hold's gate does; while it
    /// rises, drawn up as far as `progress` (0 to 1) has come within a
    /// scaffold.
    public static func storehouse(at hex: Hex, progress: Float, relief: Relief) -> [Piece] {
        let centre = Relief.centre(of: hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let y = lowest(relief, around: heart, radius: 0.5)
        let transform = Mat4.translation(Vec3(heart.x, y, heart.z)) * .rotationY(Float.pi / 2 - frontAngle(of: hex))
        let done = min(max(progress, 0), 1)
        // Its yard and footing are laid from the first; the barn rises above them.
        let bounds = Library.model(.storehouse).mesh.bounds
        let footing = (Stores.footing - bounds.min.y) / (bounds.max.y - bounds.min.y)
        var pieces = [Piece(key: .storehouse, transform: transform, hex: hex, progress: done < 1 ? footing + (1 - footing) * done : 1)]
        if done < 1 {
            let tall = max(bounds.max.y * min(done + 0.15, 1), 0.2)
            pieces.append(Piece(key: .scaffold, transform: transform * .translation(Stores.barnAt)
                                    * .scale(Vec3(storehouseScaffold.x, tall, storehouseScaffold.z)), hex: hex))
        }
        return pieces
    }

    /// A rising storehouse's scaffold's width and depth, about its barn.
    public static let storehouseScaffold = Vec3(0.78, 1, 0.46)
}
