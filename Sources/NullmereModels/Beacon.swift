import Foundation
import NullmereCore

/// What of the Beacon other models still build from in code: its leaping
/// fire, for the shrines, standards and rally camps of the land, and its
/// woodpile, for the Forge. The Beacon itself is made in Blender
/// (Art/blender/beacon.py).
enum Beacon {
    /// The fire itself, its own part to leap: tongues of flame over coals.
    static func flame(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3, size: Float) -> UInt16 {
        let part = rig.add("beacon fire", pivot: at)
        b.with(part: part) { b in
            b.with(material: .glow) { b in
                b.place(.translation(at)) {
                    $0.lathe([(size * 0.9, 0), (size, size * 0.3), (size * 0.6, size * 0.9), (size * 0.25, size * 1.5), (0, size * 2.1)],
                             sides: 7, color: Palette.fire)
                }
                for index in 0..<4 {
                    let angle = Float(index) * 1.6
                    let side = Vec3(size * 0.55 * Float(cos(Double(angle))), 0, size * 0.55 * Float(sin(Double(angle))))
                    b.place(.translation(at + side)) {
                        $0.cone(sides: 4, radius: size * 0.35, from: 0, to: size * 1.3, color: Palette.candle)
                    }
                }
            }
        }
        return part
    }

    /// Cut wood stacked for the fire, the axe in the block beside it.
    static func woodpile(_ b: inout MeshBuilder, at: Vec3) {
        for row in 0..<3 {
            for index in 0..<(4 - row) {
                let z = -0.03 + Float(index) * 0.02 + Float(row) * 0.01
                b.log(from: at + Vec3(-0.04, 0.012 + Float(row) * 0.018, z), to: at + Vec3(0.04, 0.012 + Float(row) * 0.018, z), radius: 0.009)
            }
        }
        b.fine { b in
            b.place(.translation(at + Vec3(0.06, 0, 0.03))) {
                $0.lathe([(0.016, 0), (0.016, 0.03)], sides: 6, color: Palette.timber)
            }
            b.beam(from: at + Vec3(0.06, 0.03, 0.03), to: at + Vec3(0.08, 0.06, 0.04), width: 0.004, color: Palette.timberPale)
        }
    }
}
