import Foundation
import NullmereCore

/// How a work is raised: the rig its builders work beside it while it
/// rises in its scaffold, each family's own, each moving as they work.
///
/// - The sawpit's: shear legs over the pit, a log swung up on their tackle
///   and lowered again onto the trestle.
/// - The lodge's: a crane on its treadwheel, the wheel walked round and a
///   squared block slewed up to the wall.
/// - The beacon's: a gin pole guyed to the ground, its fire basket hauled
///   up the pole and let down.
enum Raising {
    /// The families that have a rig of their own while they rise.
    static let families: [BuildingKind] = [.sawpit, .lodge, .beacon]

    static func model(_ kind: BuildingKind, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        var machinery = Machinery(parts: 1)
        switch kind {
        case .lodge:
            machinery = crane(&b, &rig)
        case .beacon:
            machinery = ginPole(&b, &rig)
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
}
