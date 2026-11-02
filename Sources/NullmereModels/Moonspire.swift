import Foundation
import NullmereCore

/// The Moonspire's court, laid about the great work stage by stage in place
/// of a common estate: the processional way of pale flags to its door,
/// obelisks of black stone set round it, moonsalt braziers burning between
/// them, and at the fifth stage a gate arch over the way and the House's
/// banners. The tower itself, its stages, its crane and its turning crystal
/// are `Works.moonspire`.
enum Moonspire {
    static let ceiling = 2_950

    static func model(level: Int, name: String) -> Model {
        let tower = Works.moonspire(level, name)
        var b = MeshBuilder()
        court(&b, level: level)
        let mesh = Estate.layered(tower.mesh, b.mesh)
        guard mesh.triangleCount <= ceiling else { return tower }
        return Model(name: name, mesh: mesh, rig: tower.rig, motion: tower.motion)
    }

    static func court(_ b: inout MeshBuilder, level: Int) {
        // The processional way: flags from the slot's edge to the door.
        for index in 0..<(1 + level) {
            let z = 0.27 - Float(index) * 0.035
            b.box(center: Vec3(0, 0.004, z), size: Vec3(0.07, 0.008, 0.03), color: index % 2 == 0 ? Palette.stoneWhite : Palette.stonePale)
        }
        // Obelisks of black stone round the court, more with each stage.
        let obelisks = min(level + 1, 5)
        for index in 0..<obelisks {
            let angle = Float.pi * (0.62 + 1.76 * Float(index) / Float(max(obelisks - 1, 1)))
            let foot = MeshBuilder.ring(0.27, 0, angle)
            b.box(center: foot + Vec3(0, 0.01, 0), size: Vec3(0.03, 0.02, 0.03), color: Palette.stone)
            b.place(.translation(foot + Vec3(0, 0.02, 0))) {
                $0.tube([(0.011, 0), (0.008, 0.11)], sides: 4, color: Palette.slate)
                $0.cone(sides: 4, radius: 0.008, from: 0.11, to: 0.13, color: Palette.moonsalt)
            }
        }
        // Braziers of moonsalt between them from the third stage.
        if level >= 3 {
            for angle in [Float.pi * 0.85, Float.pi * 2.15] {
                let foot = MeshBuilder.ring(0.23, 0, angle)
                b.place(.translation(foot)) {
                    $0.lathe([(0.012, 0), (0.008, 0.05), (0.02, 0.06), (0.022, 0.07)], sides: 6, color: Palette.bronze)
                }
                b.with(material: .glow) {
                    $0.place(.translation(foot + Vec3(0, 0.07, 0))) {
                        $0.cone(sides: 6, radius: 0.016, from: 0, to: 0.035, color: Palette.moonGlow)
                    }
                }
            }
        }
        // At the fifth stage a gate arch over the way, and banners.
        if level >= 5 {
            for x in [Float(-0.05), 0.05] {
                b.box(center: Vec3(x, 0.07, 0.25), size: Vec3(0.022, 0.14, 0.024), color: Palette.stoneWhite)
                b.flag(at: Vec3(x, 0.2, 0.25), width: 0.03, height: 0.06, turn: -.pi / 2, tail: true)
                b.limb(from: Vec3(x, 0.14, 0.25), to: Vec3(x, 0.205, 0.25), radius: 0.003, color: Palette.gold)
            }
            for index in 0...4 {
                let angle = Float.pi * Float(index) / 4
                b.box(center: Vec3(0.05 * Float(cos(Double(angle))), 0.14 + 0.035 * Float(sin(Double(angle))), 0.25),
                      size: Vec3(0.018, 0.016, 0.024), turn: 0, color: index == 2 ? Palette.moonsalt : Palette.stoneWhite)
            }
        }
    }
}
