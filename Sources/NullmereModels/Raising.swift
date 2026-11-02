import Foundation
import NullmereCore

/// How a work is raised: the rig its builders work beside it while it
/// rises in its scaffold, each family's own, each moving as they work.
///
/// - The sawpit's: shear legs over the pit, a log swung up on their tackle
///   and lowered again onto the trestle.
/// - The lodge's: a crane on its treadwheel, the wheel walked round and a
///   squared block slewed up to the wall.
/// - The muster hall's: a roof truss swung up between two shear legs onto
///   the barracks' walls.
/// - The beacon's: a gin pole guyed to the ground, its fire basket hauled
///   up the pole and let down.
/// - The granary's: a thatchers' derrick, its jib swung round to the roof
///   with a bundle of straw on its rope, and a ladder up to the eaves.
/// - The quarry's: a tripod over the footings, a windlass wound and a
///   squared stone gripped by its lewis swinging on the rope.
/// - The saltworks': a beam pile-engine driving piles into the shore mud,
///   its ram lifted on the beam's long arm and dropped.
enum Raising {
    /// The families that have a rig of their own while they rise.
    static let families: [BuildingKind] = [.sawpit, .lodge, .beacon, .musterHall, .archive, .granary, .quarry, .saltworks]

    static func model(_ kind: BuildingKind, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        var machinery = Machinery(parts: 1)
        switch kind {
        case .lodge:
            machinery = crane(&b, &rig)
        case .archive:
            machinery = crane(&b, &rig)
            // The scholars' archive rises in dressed stone: a ladder up the
            // scaffold beside the crane for the masons who set it.
            b.ladder(from: Vec3(-0.1, 0, 0.04), to: Vec3(-0.09, 0.26, 0.0), width: 0.03, rungs: 8, color: Palette.timberPale)
        case .beacon:
            machinery = ginPole(&b, &rig)
        case .musterHall:
            machinery = trussLift(&b, &rig)
        case .granary:
            machinery = thatchDerrick(&b, &rig)
        case .quarry:
            machinery = lewisTripod(&b, &rig)
        case .saltworks:
            machinery = pileEngine(&b, &rig)
        default:
            machinery = shearLegs(&b, &rig)
        }
        machinery.parts = rig.count
        let moves = machinery
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in moves.joints(clip, time) }
    }

    /// Shear legs over the sawpit: two poles lashed at their heads, a block
    /// hanging, the log on its rope swinging up and down.
    static func shearLegs(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery {
        let head = Vec3(0, 0.3, 0)
        for x in [Float(-0.07), 0.07] {
            b.limb(from: Vec3(x, 0, 0.02), to: head, radius: 0.008, color: Palette.timberGrey)
        }
        b.limb(from: Vec3(0, 0, -0.12), to: head, radius: 0.006, color: Palette.timberGrey)
        b.box(center: head + Vec3(0, -0.015, 0), size: Vec3(0.02, 0.026, 0.016), color: Palette.iron)
        let load = rig.add("raised log", pivot: head)
        b.with(part: load) { b in
            b.limb(from: head + Vec3(0, -0.03, 0), to: head + Vec3(0, -0.17, 0), radius: 0.0025, color: Palette.linen)
            b.log(from: head + Vec3(-0.08, -0.18, 0), to: head + Vec3(0.08, -0.18, 0), radius: 0.02)
        }
        b.fine { b in
            for x in [Float(-0.07), 0.07] {
                b.box(center: Vec3(x, 0.006, 0.02), size: Vec3(0.022, 0.012, 0.022), color: Palette.stoneDark)
            }
        }
        return Machinery(swings: [Machinery.Swing(part: load, axis: Vec3(1, 0, 0), angle: 0.35)], parts: rig.count)
    }

    /// A builder's crane: a treadwheel in its frame and a jib above it,
    /// the wheel turning and the jib slewing a block up to the wall.
    static func crane(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery {
        let hub = Vec3(0, 0.075, 0)
        for z in [Float(-0.03), 0.03] {
            b.beam(from: Vec3(-0.05, 0, z), to: hub + Vec3(0, 0, z), width: 0.008, color: Palette.timberDark)
            b.beam(from: Vec3(0.05, 0, z), to: hub + Vec3(0, 0, z), width: 0.008, color: Palette.timberDark)
        }
        let wheel = rig.add("raising treadwheel", pivot: hub)
        b.with(part: wheel) {
            $0.wheel(center: hub, radius: 0.07, width: 0.05, spokes: 6, color: Palette.timber, rim: Palette.timberDark)
        }
        b.limb(from: Vec3(-0.04, 0, 0), to: Vec3(-0.04, 0.26, 0), radius: 0.008, color: Palette.timberDark)
        let jib = rig.add("raising jib", pivot: Vec3(-0.04, 0.24, 0))
        b.with(part: jib) { b in
            b.beam(from: Vec3(-0.04, 0.24, 0), to: Vec3(0.1, 0.27, 0), width: 0.009, color: Palette.timber)
            b.limb(from: Vec3(0.095, 0.265, 0), to: Vec3(0.095, 0.16, 0), radius: 0.002, color: Palette.linen)
            b.box(center: Vec3(0.095, 0.145, 0), size: Vec3(0.032, 0.028, 0.03), color: Palette.stonePale)
        }
        return Machinery(wheels: [Machinery.Wheel(part: wheel, axis: Vec3(0, 0, 1), turns: 1)],
                         swings: [Machinery.Swing(part: jib, axis: Vec3(0, 1, 0), angle: 0.7)], parts: rig.count)
    }

    /// A gin pole guyed to pegs, its fire basket hauled up the pole and let
    /// down as the beacon's crown is raised.
    static func ginPole(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery {
        let top = Vec3(0, 0.36, 0)
        b.limb(from: Vec3(0, 0, 0), to: top, radius: 0.008, color: Palette.timberGrey)
        for angle in [Float(0.4), 2.5, 4.4] {
            let peg = Vec3(0.14 * Float(cos(Double(angle))), 0, 0.14 * Float(sin(Double(angle))))
            b.limb(from: top, to: peg, radius: 0.0018, color: Palette.linen)
            b.box(center: peg + Vec3(0, 0.008, 0), size: Vec3(0.01, 0.016, 0.01), color: Palette.timberDark)
        }
        let load = rig.add("raised basket", pivot: top)
        b.with(part: load) { b in
            b.limb(from: top, to: top + Vec3(0.03, -0.14, 0), radius: 0.002, color: Palette.linen)
            b.with(material: .metal) {
                $0.place(.translation(top + Vec3(0.03, -0.17, 0))) {
                    $0.lathe([(0.012, -0.02), (0.035, 0.0), (0.038, 0.03)], sides: 8, color: Palette.iron)
                }
            }
        }
        return Machinery(swings: [Machinery.Swing(part: load, axis: Vec3(0, 0, 1), angle: 0.3)], parts: rig.count)
    }

    /// Shear legs at each end of a span, a roof truss hanging between them,
    /// swung up onto the walls and let down to be pinned.
    static func trussLift(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery {
        for x in [Float(-0.1), 0.1] {
            for z in [Float(-0.05), 0.05] {
                b.limb(from: Vec3(x, 0, z), to: Vec3(x, 0.3, 0), radius: 0.006, color: Palette.timberGrey)
            }
        }
        let truss = rig.add("raised truss", pivot: Vec3(0, 0.29, 0))
        b.with(part: truss) { b in
            b.limb(from: Vec3(-0.1, 0.29, 0), to: Vec3(-0.06, 0.2, 0), radius: 0.0018, color: Palette.linen)
            b.limb(from: Vec3(0.1, 0.29, 0), to: Vec3(0.06, 0.2, 0), radius: 0.0018, color: Palette.linen)
            b.beam(from: Vec3(-0.08, 0.17, 0), to: Vec3(0.08, 0.17, 0), width: 0.008, color: Palette.timber)
            b.beam(from: Vec3(-0.08, 0.17, 0), to: Vec3(0, 0.23, 0), width: 0.008, color: Palette.timber)
            b.beam(from: Vec3(0.08, 0.17, 0), to: Vec3(0, 0.23, 0), width: 0.008, color: Palette.timber)
            b.beam(from: Vec3(0, 0.17, 0), to: Vec3(0, 0.23, 0), width: 0.006, color: Palette.timberDark)
        }
        return Machinery(swings: [Machinery.Swing(part: truss, axis: Vec3(1, 0, 0), angle: 0.3)], parts: rig.count)
    }

    /// A thatchers' derrick: a pole stepped in a block with its jib, a
    /// bundle of straw on the rope swung round to the roof; a ladder to the
    /// eaves with a bundle laid on its rungs.
    static func thatchDerrick(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery {
        let foot = Vec3(0.08, 0, 0.04)
        b.box(center: foot + Vec3(0, 0.012, 0), size: Vec3(0.04, 0.024, 0.04), color: Palette.timberDark)
        b.limb(from: foot, to: foot + Vec3(0, 0.3, 0), radius: 0.008, color: Palette.timberGrey)
        for angle in [Float(0.6), 2.6, 4.6] {
            let peg = foot + Vec3(0.11 * Float(cos(Double(angle))), 0, 0.11 * Float(sin(Double(angle))))
            b.limb(from: foot + Vec3(0, 0.3, 0), to: peg, radius: 0.0016, color: Palette.linen)
        }
        let jib = rig.add("thatch derrick", pivot: foot + Vec3(0, 0.22, 0))
        b.with(part: jib) { b in
            b.beam(from: foot + Vec3(0, 0.22, 0), to: foot + Vec3(-0.15, 0.27, 0), width: 0.008, color: Palette.timber)
            b.beam(from: foot + Vec3(0, 0.29, 0), to: foot + Vec3(-0.15, 0.27, 0), width: 0.004, color: Palette.timberDark)
            b.limb(from: foot + Vec3(-0.145, 0.265, 0), to: foot + Vec3(-0.145, 0.17, 0), radius: 0.002, color: Palette.linen)
            b.place(.translation(foot + Vec3(-0.145, 0.15, 0)) * .rotationZ(.pi / 2)) {
                $0.lathe([(0.012, -0.04), (0.018, -0.02), (0.016, 0.03), (0.008, 0.045)], sides: 6, color: Palette.straw)
            }
        }
        b.ladder(from: Vec3(-0.12, 0, 0.08), to: Vec3(-0.1, 0.2, 0.02), width: 0.03, rungs: 7, color: Palette.timberPale)
        b.fine { b in
            b.place(.translation(Vec3(-0.11, 0.11, 0.055)) * .rotationZ(.pi / 2)) {
                $0.lathe([(0.01, -0.03), (0.014, 0.0), (0.008, 0.03)], sides: 5, color: Palette.straw)
            }
            for (index, x) in [Float(0.0), 0.03].enumerated() {
                b.place(.translation(Vec3(x, 0.012, 0.12)) * .rotationZ(.pi / 2) * .rotationX(Float(index) * 0.4)) {
                    $0.lathe([(0.01, -0.035), (0.013, 0.0), (0.008, 0.035)], sides: 5, color: Palette.straw)
                }
            }
        }
        return Machinery(swings: [Machinery.Swing(part: jib, axis: Vec3(0, 1, 0), angle: 0.9)], parts: rig.count)
    }

    /// A tripod over the footings, its windlass wound by a handle and a
    /// squared stone gripped by its lewis swinging on the rope beneath.
    static func lewisTripod(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery {
        let head = Vec3(0, 0.32, 0)
        for angle in [Float(0.5), 2.6, 4.7] {
            let foot = Vec3(0.12 * Float(cos(Double(angle))), 0, 0.12 * Float(sin(Double(angle))))
            b.limb(from: foot, to: head, radius: 0.0075, color: Palette.timberGrey)
            b.box(center: foot + Vec3(0, 0.006, 0), size: Vec3(0.02, 0.012, 0.02), color: Palette.stoneDark)
        }
        b.with(material: .metal) {
            $0.box(center: head + Vec3(0, -0.012, 0), size: Vec3(0.018, 0.02, 0.018), color: Palette.iron)
        }
        let hub = Vec3(0.07, 0.08, 0.04)
        b.beam(from: Vec3(0.07, 0.0, 0.0), to: hub + Vec3(0, 0, -0.04), width: 0.008, color: Palette.timberDark)
        b.beam(from: Vec3(0.07, 0.0, 0.08), to: hub + Vec3(0, 0, 0.04), width: 0.008, color: Palette.timberDark)
        let windlass = rig.add("windlass", pivot: hub)
        b.with(part: windlass) {
            $0.limb(from: hub + Vec3(0, 0, -0.04), to: hub + Vec3(0, 0, 0.04), radius: 0.012, sides: 6, color: Palette.timber)
            $0.beam(from: hub + Vec3(0, 0, 0.042), to: hub + Vec3(0.035, 0.0, 0.042), width: 0.005, color: Palette.timberDark)
            $0.beam(from: hub + Vec3(0, 0, -0.042), to: hub + Vec3(-0.035, 0.0, -0.042), width: 0.005, color: Palette.timberDark)
        }
        b.limb(from: hub, to: head, radius: 0.0018, color: Palette.linen)
        let stone = rig.add("lewis stone", pivot: head)
        b.with(part: stone) {
            $0.limb(from: head + Vec3(0, -0.02, 0), to: head + Vec3(0, -0.16, 0), radius: 0.002, color: Palette.linen)
            $0.with(material: .metal) {
                $0.box(center: head + Vec3(0, -0.165, 0), size: Vec3(0.01, 0.014, 0.006), color: Palette.iron)
            }
            $0.box(center: head + Vec3(0, -0.195, 0), size: Vec3(0.06, 0.04, 0.04), color: Palette.stonePale)
        }
        return Machinery(wheels: [Machinery.Wheel(part: windlass, axis: Vec3(0, 0, 1), turns: 1)],
                         swings: [Machinery.Swing(part: stone, axis: Vec3(1, 0, 0), angle: 0.2)], parts: rig.count)
    }

    /// A beam pile-engine: a long beam pivoted on an A-frame, the iron-shod
    /// ram hung from its short arm lifted as the long arm is hauled down and
    /// dropped on the pile; piles already driven stand in a row beside it.
    static func pileEngine(_ b: inout MeshBuilder, _ rig: inout Rig) -> Machinery {
        let pivot = Vec3(0, 0.2, 0)
        for x in [Float(-0.05), 0.05] {
            for z in [Float(-0.04), 0.04] {
                b.limb(from: Vec3(x * 1.6, 0, z), to: pivot + Vec3(x * 0.2, 0, z * 0.5), radius: 0.006, color: Palette.timberGrey)
            }
        }
        b.box(center: pivot, size: Vec3(0.02, 0.02, 0.05), color: Palette.timberDark)
        let beam = rig.add("pile engine", pivot: pivot)
        b.with(part: beam) { b in
            b.beam(from: pivot + Vec3(-0.08, 0.02, 0), to: pivot + Vec3(0.17, -0.04, 0), width: 0.012, color: Palette.timber)
            b.limb(from: pivot + Vec3(-0.075, 0.015, 0), to: pivot + Vec3(-0.075, -0.08, 0), radius: 0.002, color: Palette.linen)
            b.with(material: .metal) {
                $0.place(.translation(pivot + Vec3(-0.075, -0.12, 0))) {
                    $0.lathe([(0.02, 0), (0.022, 0.04), (0.012, 0.045)], sides: 7, color: Palette.iron)
                }
            }
            for dz in [Float(-0.02), 0.0, 0.02] {
                b.limb(from: pivot + Vec3(0.16, -0.035, dz), to: Vec3(0.2, 0.0, dz * 2), radius: 0.0016, color: Palette.linen)
            }
        }
        // The pile under the ram, and the row already driven.
        b.limb(from: Vec3(-0.075, -0.02, 0), to: Vec3(-0.075, 0.06, 0), radius: 0.012, color: Palette.bark)
        for index in 0..<5 {
            let x = -0.16 + Float(index) * 0.04
            b.limb(from: Vec3(x, -0.02, 0.1), to: Vec3(x, 0.02 + Float(index % 2) * 0.008, 0.1), radius: 0.011, color: Palette.bark)
        }
        b.fine { b in
            for index in 0..<3 {
                b.log(from: Vec3(0.06 + Float(index) * 0.02, 0.01, -0.12), to: Vec3(0.06 + Float(index) * 0.02, 0.01, -0.02), radius: 0.009)
            }
        }
        return Machinery(swings: [Machinery.Swing(part: beam, axis: Vec3(0, 0, 1), angle: 0.25)], parts: rig.count)
    }
}
