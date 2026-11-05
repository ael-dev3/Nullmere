import Foundation
import NullmereCore

/// What of the Wayhouse other models still build from in code: its horse,
/// for the yards' wains and the rally camp's horse lines. The Wayhouse
/// itself is made in Blender (Art/blender/wayhouse.py).
enum Wayhouse {
    /// A horse standing, head down a little.
    static func horse(_ b: inout MeshBuilder, at: Vec3, turn: Float, coat: Vec3) {
        b.place(.translation(at) * .rotationY(turn)) {
            $0.limb(from: Vec3(-0.025, 0.05, 0), to: Vec3(0.025, 0.05, 0), radius: 0.014, color: coat)
            for (x, z) in [(Float(-0.02), Float(-0.008)), (-0.02, 0.008), (0.02, -0.008), (0.02, 0.008)] {
                $0.limb(from: Vec3(x, 0.045, z), to: Vec3(x, 0, z), radius: 0.004, color: coat)
            }
            $0.limb(from: Vec3(-0.025, 0.055, 0), to: Vec3(-0.04, 0.075, 0), radius: 0.008, topRadius: 0.006, color: coat)
            $0.limb(from: Vec3(-0.04, 0.075, 0), to: Vec3(-0.055, 0.065, 0), radius: 0.006, topRadius: 0.004, color: coat)
            $0.limb(from: Vec3(0.028, 0.055, 0), to: Vec3(0.034, 0.025, 0), radius: 0.003, color: Palette.hair)
            $0.box(center: Vec3(0, 0.066, 0), size: Vec3(0.02, 0.004, 0.03), color: Palette.leatherDark)
        }
    }
}
