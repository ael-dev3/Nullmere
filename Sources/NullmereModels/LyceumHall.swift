import Foundation

/// The Lyceum's hall, where the realm's scholars sit: a round house of
/// pale stone on a stepped drum, ten columns about a lit inner wall, a
/// shallow dome of slate with an open eye at its crown, braziers before
/// its four doors and lecterns on its steps. Over the eye an orrery of
/// moonsalt rings turns while the Lyceum sits (`orrery`, drawn apart so
/// it can turn). It fills the heart of its hex, its doors to ±x and ±z.
public enum LyceumHall {
    static let drum: Float = 0.08
    static let columns: Float = 0.3
    static let cella: Float = 0.21
    static let eaves: Float = 0.34
    static let crown: Float = 0.47
    /// Where the orrery turns, over the dome's eye.
    public static let orreryAt = Vec3(0, crown + 0.04, 0)
    /// The braziers before the doors, where smoke goes up.
    static let braziers: [Vec3] = (0..<4).map { MeshBuilder.ring(0.47, drum + 0.13, Float($0) * .pi / 2 + .pi / 4) }

    static func hall(name: String) -> Model {
        var b = MeshBuilder()
        b.with(surface: .stone) {
            // The drum it stands on, deep for a slope, three steps about it.
            $0.lathe([(0.0, -0.3), (0.6, -0.3), (0.6, 0.0), (0.55, 0.0), (0.55, 0.03), (0.5, 0.03), (0.5, 0.055), (0.45, 0.055),
                      (0.45, drum), (0.0, drum)], sides: 20, color: Palette.stonePale)
            // The inner wall, its four doors and lit windows between.
            $0.lathe([(cella, drum), (cella, eaves - 0.02), (0.0, eaves - 0.02)], sides: 16, color: Palette.stone)
            // Ten columns, their bases and capitals.
            for index in 0..<10 {
                let angle = Float(index) * .pi / 5
                let foot = MeshBuilder.ring(columns, drum, angle)
                $0.limb(from: foot, to: foot + Vec3(0, eaves - drum - 0.03, 0), radius: 0.018, topRadius: 0.015, sides: 6,
                        color: Palette.stonePale)
                $0.box(center: foot + Vec3(0, 0.008, 0), size: Vec3(0.045, 0.016, 0.045), turn: angle, color: Palette.stone)
                $0.box(center: foot + Vec3(0, eaves - drum - 0.022, 0), size: Vec3(0.045, 0.016, 0.045), turn: angle,
                       color: Palette.stone)
            }
            // The ring of stone the dome rests on.
            $0.lathe([(columns + 0.035, eaves - 0.03), (columns + 0.035, eaves), (0.0, eaves)], sides: 20, color: Palette.stonePale)
        }
        // The dome of slate, open at its eye.
        b.with(surface: .slate) {
            $0.lathe([(columns + 0.03, eaves), (columns - 0.01, eaves + 0.06), (0.2, eaves + 0.1), (0.1, crown - 0.01),
                      (0.05, crown)], sides: 20, color: Palette.slate)
        }
        b.with(surface: .stone) {
            $0.lathe([(0.06, crown - 0.005), (0.06, crown + 0.012), (0.045, crown + 0.012)], sides: 12, color: Palette.stonePale)
        }
        // The eye's light, and the doors and windows of the lit inner wall.
        b.with(material: .glow) {
            $0.lathe([(0.045, crown), (0.0, crown + 0.006)], sides: 10, color: Palette.candle)
        }
        for index in 0..<4 {
            let angle = Float(index) * .pi / 2
            b.door(MeshBuilder.ring(cella + 0.002, drum + 0.07, angle), width: 0.07, height: 0.13, facing: angle)
            b.window(onRound: cella + 0.002, y: 0.24, angle: angle + .pi / 4, width: 0.035, height: 0.06)
        }
        // Lecterns on the steps before the doors, a book open on each.
        b.with(surface: .timber) {
            for index in 0..<4 {
                let angle = Float(index) * .pi / 2
                let at = MeshBuilder.ring(0.4, drum, angle)
                $0.limb(from: at, to: at + Vec3(0, 0.07, 0), radius: 0.008, color: Palette.timberDark)
                $0.box(center: at + Vec3(0, 0.075, 0), size: Vec3(0.05, 0.008, 0.035), turn: angle, color: Palette.timber)
            }
        }
        b.with(material: .glow) {
            for index in 0..<4 {
                let at = MeshBuilder.ring(0.4, drum + 0.082, Float(index) * .pi / 2)
                $0.box(center: at, size: Vec3(0.04, 0.004, 0.028), turn: Float(index) * .pi / 2, color: Palette.candle * 0.6)
            }
        }
        // Braziers between the doors, burning.
        for at in braziers {
            let foot = Vec3(at.x, drum, at.z)
            b.limb(from: foot, to: foot + Vec3(0, 0.1, 0), radius: 0.008, color: Palette.iron)
            b.place(.translation(foot)) {
                $0.lathe([(0.0, 0.095), (0.035, 0.1), (0.04, 0.125)], sides: 6, color: Palette.iron)
            }
            b.with(material: .glow) {
                $0.place(.translation(foot + Vec3(0, 0.115, 0))) {
                    $0.lathe([(0.03, 0), (0.034, 0.022), (0.0, 0.07)], sides: 5, color: Palette.fire)
                }
            }
        }
        return Model(name: name, mesh: b.mesh)
    }

    /// The orrery over the dome's eye: three rings of moonsalt about a lit
    /// moon, each tilted its own way; the stage turns it about y.
    static func orrery(name: String) -> Model {
        var b = MeshBuilder()
        b.with(material: .metal) {
            $0.limb(from: Vec3(0, -0.02, 0), to: Vec3(0, 0.05, 0), radius: 0.004, color: Palette.iron)
        }
        b.with(material: .glow) {
            $0.sphere(center: Vec3(0, 0.07, 0), radius: 0.018, rings: 3, sides: 6, color: Palette.moonsalt)
        }
        for (index, tilt) in [Float(0.35), -0.6, 1.1].enumerated() {
            let radius = 0.05 + 0.012 * Float(index)
            b.with(material: .metal) {
                $0.place(.translation(Vec3(0, 0.07, 0)) * .rotationY(Float(index) * 1.2) * .rotationX(tilt)) {
                    for step in 0..<12 {
                        let a = Float(step) * .pi / 6, c = Float(step + 1) * .pi / 6
                        $0.beam(from: Vec3(cos(a) * radius, 0, sin(a) * radius), to: Vec3(cos(c) * radius, 0, sin(c) * radius),
                                width: 0.005, color: Palette.moonsalt * 0.8)
                    }
                }
            }
        }
        return Model(name: name, mesh: b.mesh)
    }
}
