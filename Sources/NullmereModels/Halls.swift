import Foundation
import NullmereCore

/// An alliance's hall: a great timbered hall on a platform of dressed
/// stone, its roof in the alliance's colour with carved horns at its
/// gables; a round tower behind it flying the alliance's great banner;
/// banners hanging at the platform's corners and braziers burning at its
/// door. It faces +z, its platform a hexagon with flats to ±z, and fills
/// the heart of its hex.
enum Halls {
    /// The platform's corners lie on this radius.
    static let platformRadius: Float = 0.64
    /// Where the hall's floor stands.
    static let floor: Float = 0.07
    /// The hall's walls, from front to back and side to side.
    static let front: Float = 0.3, back: Float = -0.24, side: Float = 0.17
    static let eaves: Float = 0.27, ridge: Float = 0.47

    static func hall(name: String) -> Model {
        var b = MeshBuilder()
        b.with(surface: .stone) {
            // The platform, deep enough to stand on a slope, a step about its rim.
            $0.lathe([(platformRadius, -0.3), (platformRadius, floor - 0.025), (platformRadius - 0.04, floor - 0.02),
                      (platformRadius - 0.04, floor)], sides: 6, color: Palette.stoneDark)
            // Steps down from the door to the ground.
            for (index, z) in [Float(0.56), 0.6].enumerated() {
                $0.box(min: Vec3(-0.11, -0.3, z), max: Vec3(0.11, floor - 0.03 - 0.025 * Float(index), z + 0.06), color: Palette.stone)
            }
            // The hall's footing of stone.
            $0.box(min: Vec3(-side - 0.012, floor, back - 0.012), max: Vec3(side + 0.012, floor + 0.05, front + 0.012), color: Palette.stone)
        }
        b.with(surface: .timber) {
            // Its timbered walls, posts at the corners and between.
            $0.box(min: Vec3(-side, floor + 0.05, back), max: Vec3(side, eaves, front), color: Palette.timber)
            for x in [-side, side] {
                for z in stride(from: back, through: front, by: (front - back) / 4) {
                    $0.box(center: Vec3(x, (floor + eaves) / 2 + 0.025, z), size: Vec3(0.028, eaves - floor - 0.05, 0.028),
                           color: Palette.timberDark)
                }
            }
            // A porch before the door on two posts.
            for x in [Float(-0.08), 0.08] {
                $0.limb(from: Vec3(x, floor, front + 0.1), to: Vec3(x, eaves - 0.04, front + 0.1), radius: 0.014, color: Palette.timberDark)
            }
        }
        // The roof, steep and high, in the alliance's colour, over the
        // porch too; a louvre on its ridge where the smoke goes out.
        b.with(material: .house) {
            $0.place(.translation(Vec3(0, 0, (front + back) / 2 + 0.03)) * .rotationY(.pi / 2)) {
                $0.gableRoof(width: front - back + 0.1, depth: 2 * side, base: eaves, height: ridge - eaves, color: Palette.house,
                             overhang: 0.035)
            }
        }
        b.with(surface: .slate) {
            $0.box(center: Vec3(0, ridge + 0.02, -0.02), size: Vec3(0.07, 0.05, 0.09), color: Palette.slate)
            $0.place(.translation(Vec3(0, ridge + 0.045, -0.02))) {
                $0.hipRoof(width: 0.1, depth: 0.12, base: 0, height: 0.04, color: Palette.slate)
            }
        }
        // Carved horns crossed at each gable's peak.
        for z in [back - 0.05, front + 0.1] {
            for lean in [Float(-1), 1] {
                b.beam(from: Vec3(-lean * 0.06, ridge - 0.07, z), to: Vec3(lean * 0.07, ridge + 0.09, z), width: 0.02, depth: 0.016,
                       color: Palette.timberDark)
            }
        }
        // The great door, lit windows down both sides and either side of the door.
        b.door(Vec3(0, floor + 0.09, front + 0.002), width: 0.1, height: 0.17, facing: 0)
        for z in [Float(-0.12), 0.0, 0.12, 0.22] {
            b.window(Vec3(side + 0.002, 0.19, z), width: 0.035, height: 0.05, facing: .pi / 2)
            b.window(Vec3(-side - 0.002, 0.19, z), width: 0.035, height: 0.05, facing: -.pi / 2)
        }
        for x in [Float(-0.11), 0.11] {
            b.window(Vec3(x, 0.19, front + 0.002), width: 0.03, height: 0.05, facing: 0)
        }
        // The alliance's shields hung down both sides between the windows,
        // each with its boss of iron.
        for out in [Float(-1), 1] {
            for z in [Float(-0.06), 0.06, 0.17] {
                b.place(.translation(Vec3(out * (side + 0.004), 0.165, z)) * .rotationZ(-out * .pi / 2)) {
                    $0.with(material: .house) {
                        $0.lathe([(0.0, -0.002), (0.03, 0.0), (0.03, 0.006), (0.0, 0.01)], sides: 8, color: Palette.house)
                    }
                    $0.with(material: .metal) {
                        $0.sphere(center: Vec3(0, 0.01, 0), radius: 0.009, rings: 2, sides: 4, color: Palette.iron)
                    }
                }
            }
        }
        // Bollards of stone at the platform's corners.
        b.with(surface: .stone) {
            for index in 0..<6 {
                let angle = Float(index) * .pi / 3
                $0.box(center: MeshBuilder.ring(platformRadius - 0.05, floor + 0.035, angle), size: Vec3(0.05, 0.07, 0.05),
                       turn: angle, color: Palette.stonePale)
            }
        }
        tower(&b)
        // Banners hanging from crossbars at the platform's corners.
        for corner in [Vec3(-0.44, 0, 0.3), Vec3(0.44, 0, 0.3), Vec3(-0.44, 0, -0.3), Vec3(0.44, 0, -0.3)] {
            let out: Float = corner.x < 0 ? -1 : 1
            b.limb(from: corner + Vec3(0, floor - 0.02, 0), to: corner + Vec3(0, 0.62, 0), radius: 0.011, topRadius: 0.008,
                   color: Palette.timberDark)
            b.beam(from: corner + Vec3(-out * 0.01, 0.58, 0), to: corner + Vec3(out * 0.13, 0.58, 0), width: 0.012,
                   color: Palette.timber)
            b.with(material: .metal) {
                $0.place(.translation(corner + Vec3(0, 0.62, 0))) { $0.cone(sides: 4, radius: 0.016, to: 0.05, color: Palette.iron) }
            }
            b.flag(at: corner + Vec3(out * 0.005, 0.575, 0), width: 0.12, height: 0.28, turn: out < 0 ? .pi : 0, tail: true)
        }
        // Braziers either side of the steps, burning.
        for x in [Float(-0.17), 0.17] {
            b.limb(from: Vec3(x, floor - 0.02, 0.5), to: Vec3(x, floor + 0.12, 0.5), radius: 0.009, color: Palette.iron)
            b.lathe([(0.0, floor + 0.11), (0.04, floor + 0.12), (0.045, floor + 0.15)], sides: 6, color: Palette.iron)
            b.with(material: .glow) {
                $0.place(.translation(Vec3(x, floor + 0.14, 0.5))) {
                    $0.lathe([(0.034, 0), (0.04, 0.028), (0.0, 0.08)], sides: 5, color: Palette.fire)
                }
            }
        }
        b.fine { hallNear(&$0) }
        return Model(name: name, mesh: b.mesh)
    }

    /// The hall drawn near: a crenellated parapet round its platform, open
    /// at the steps; iron bands and a ring on its great door and lanterns
    /// under its porch; a rack of spears with shields in the alliance's
    /// colour, the alliance's stores stacked and a well in its court; and
    /// slits, a string course and a door on its tower.
    static func hallNear(_ b: inout MeshBuilder) {
        // The parapet, a little inside the rim, clear of the banners'
        // poles; its front edge leaves the steps and the braziers open.
        let rim: Float = 0.57, wall: Float = 0.045
        b.with(surface: .stone) {
            for index in 0..<6 {
                let from = MeshBuilder.ring(rim, floor, Float(index) * .pi / 3), to = MeshBuilder.ring(rim, floor, Float(index + 1) * .pi / 3)
                let runs = index == 4 ? [(from, Vec3(-0.22, floor, from.z)), (Vec3(0.22, floor, to.z), to)] : [(from, to)]
                for (start, end) in runs {
                    let lift = Vec3(0, wall / 2, 0)
                    $0.beam(from: start + lift, to: end + lift, width: 0.024, depth: wall, color: Palette.stone)
                    let count = max(1, Int(((end - start).length / 0.1).rounded()))
                    $0.merlons(from: start + Vec3(0, wall, 0), to: end + Vec3(0, wall, 0), count: count, size: Vec3(0.032, 0.024, 0.026),
                               color: Palette.stonePale)
                }
            }
        }
        // The great door's iron bands and ring.
        b.with(material: .metal) {
            for y in [Float(0.11), 0.16, 0.21] {
                $0.box(center: Vec3(0, y, front + 0.0135), size: Vec3(0.104, 0.008, 0.003), color: Palette.iron)
            }
            $0.place(.translation(Vec3(0.026, 0.15, front + 0.016)) * .rotationX(.pi / 2)) {
                $0.tube([(0.009, -0.002), (0.009, 0.002)], sides: 6, color: Palette.iron)
            }
        }
        // Lanterns hung under the porch's eave.
        for x in [Float(-0.12), 0.12] {
            b.limb(from: Vec3(x, eaves - 0.004, 0.37), to: Vec3(x, 0.235, 0.37), radius: 0.0018, sides: 3, color: Palette.iron)
            b.box(center: Vec3(x, 0.232, 0.37), size: Vec3(0.026, 0.006, 0.026), color: Palette.iron)
            b.with(material: .glow) {
                $0.box(center: Vec3(x, 0.214, 0.37), size: Vec3(0.02, 0.03, 0.02), color: Palette.candle)
            }
            b.box(center: Vec3(x, 0.197, 0.37), size: Vec3(0.024, 0.005, 0.024), color: Palette.iron)
        }
        // A rack of spears in the court, shields in the alliance's colour
        // against its foot.
        let rack = Vec3(-0.36, floor, 0.12)
        for x in [Float(-0.07), 0.07] {
            for z in [Float(-0.025), 0.025] {
                b.limb(from: rack + Vec3(x, 0, z), to: rack + Vec3(x, 0.13, 0), radius: 0.005, sides: 3, color: Palette.timberDark)
            }
        }
        b.limb(from: rack + Vec3(-0.08, 0.125, 0), to: rack + Vec3(0.08, 0.125, 0), radius: 0.005, color: Palette.timber)
        for x in [Float(-0.05), -0.017, 0.017, 0.05] {
            let foot = rack + Vec3(x, 0, 0.05), top = rack + Vec3(x + 0.004, 0.23, -0.012)
            b.limb(from: foot, to: top, radius: 0.0035, color: Palette.timberDark)
            b.with(material: .metal) {
                $0.place(.translation(top) * Mat4.aligningUp(to: top - foot)) { $0.cone(sides: 4, radius: 0.008, to: 0.03, color: Palette.iron) }
            }
        }
        for x in [Float(-0.035), 0.035] {
            b.place(.translation(rack + Vec3(x, 0.035, 0.075)) * .rotationX(1.25)) {
                $0.with(material: .house) { $0.lathe([(0.032, -0.004), (0.032, 0.003), (0.0, 0.007)], sides: 8, color: Palette.house) }
                $0.with(material: .metal) { $0.cone(sides: 5, radius: 0.008, from: 0.006, to: 0.014, color: Palette.iron) }
            }
        }
        // The alliance's stores stacked on the other side.
        Stores.barrel(&b, at: Vec3(0.32, floor, 0.06), turn: 0.2)
        Stores.barrel(&b, at: Vec3(0.385, floor, 0.1), turn: 1.0)
        Stores.barrel(&b, at: Vec3(0.35, floor + 0.07, 0.08), turn: 0.6)
        b.box(center: Vec3(0.34, floor + 0.025, -0.05), size: Vec3(0.06, 0.05, 0.055), turn: 0.3, color: Palette.timberPale)
        b.box(center: Vec3(0.4, floor + 0.022, -0.02), size: Vec3(0.05, 0.044, 0.05), turn: -0.2, color: Palette.timber)
        b.tiedSack(at: Vec3(0.3, floor, 0.16), size: 0.9)
        // A well at the back of the court.
        let well = Vec3(0.3, floor, -0.22)
        b.with(surface: .stone) {
            $0.place(.translation(well)) {
                $0.lathe([(0.045, 0), (0.045, 0.05), (0.036, 0.055), (0.036, 0.02)], sides: 8, color: Palette.stone)
            }
        }
        b.place(.translation(well)) {
            $0.lathe([(0.036, 0.035), (0.0, 0.036)], sides: 8, color: Vec3(0.05, 0.07, 0.09))
            for x in [Float(-0.05), 0.05] {
                $0.limb(from: Vec3(x, 0.0, 0), to: Vec3(x, 0.15, 0), radius: 0.005, color: Palette.timberDark)
            }
            $0.limb(from: Vec3(-0.06, 0.14, 0), to: Vec3(0.06, 0.14, 0), radius: 0.006, color: Palette.timber)
            $0.limb(from: Vec3(0, 0.14, 0), to: Vec3(0, 0.08, 0), radius: 0.0015, sides: 3, color: Palette.linen)
            $0.lathe([(0.0, 0.06), (0.014, 0.062), (0.016, 0.082)], sides: 6, color: Palette.timberPale)
        }
        // The tower's door toward the court, its slits and a string course.
        b.place(.translation(towerAt)) {
            $0.place(.rotationY(-.pi / 8)) {
                $0.door(Vec3(0.1128, floor + 0.055, 0), width: 0.05, height: 0.1, facing: .pi / 2)
            }
            for quarter in 0..<4 {
                $0.place(.rotationY(-.pi / 8 + Float(quarter) * .pi / 2)) {
                    $0.box(center: Vec3(0.1086, 0.3, 0), size: Vec3(0.006, 0.05, 0.012), color: Palette.barkBlack)
                }
            }
            $0.with(surface: .stone) {
                $0.tube([(0.1148, 0.41), (0.1208, 0.415), (0.1208, 0.425), (0.1148, 0.43)], sides: 8, color: Palette.stonePale)
            }
        }
    }

    /// Where the tower stands, behind the hall.
    static let towerAt = Vec3(0, 0, -0.38)
    static let towerTop: Float = 0.8

    /// A round tower of stone behind the hall, crowned, its cone the
    /// alliance's, the great banner over it.
    static func tower(_ b: inout MeshBuilder) {
        b.place(.translation(towerAt)) {
            $0.with(surface: .stone) {
                $0.lathe([(0.12, floor - 0.02), (0.11, towerTop - 0.04), (0.135, towerTop - 0.02), (0.135, towerTop + 0.04)], sides: 8,
                         color: Palette.stone)
                $0.merlonRing(radius: 0.128, base: towerTop + 0.04, count: 8, size: Vec3(0.045, 0.045, 0.03), color: Palette.stonePale)
            }
            $0.with(material: .house) {
                $0.cone(sides: 8, radius: 0.12, from: towerTop + 0.03, to: towerTop + 0.34, color: Palette.house)
            }
            for angle in [Float.pi / 2, .pi / 6, 5 * .pi / 6] {
                $0.window(onRound: 0.112, y: 0.52, angle: -angle, width: 0.028, height: 0.06)
            }
            let top = towerTop + 0.66
            $0.limb(from: Vec3(0, towerTop + 0.3, 0), to: Vec3(0, top, 0), radius: 0.009, color: Palette.timberDark)
            $0.flag(at: Vec3(0, top - 0.01, 0), width: 0.36, height: 0.22, tail: true)
        }
    }

    /// Where smoke rises from the hall's louvre.
    static let smoke = Vec3(0, ridge + 0.09, -0.02)
}

extension HoldLayout {
    /// An alliance's hall on its hex: on the lowest of the ground under its
    /// platform, facing the lake's heart as a hold's gate does. While it
    /// rises its platform stands from the first, the hall drawn up above it
    /// as far as `progress` (0 to 1) has come, within a scaffold.
    public static func hall(at hex: Hex, progress: Float, relief: Relief) -> [Piece] {
        let centre = Relief.centre(of: hex)
        let heart = Vec3(centre.x, 0, centre.z)
        let y = lowest(relief, around: heart, radius: Halls.platformRadius)
        let transform = Mat4.translation(Vec3(heart.x, y, heart.z)) * .rotationY(Float.pi / 2 - frontAngle(of: hex))
        let bounds = Library.model(.allianceHall).mesh.bounds
        let platform = (Halls.floor - bounds.min.y) / (bounds.max.y - bounds.min.y)
        let done = min(max(progress, 0), 1)
        var pieces = [Piece(key: .allianceHall, transform: transform, hex: hex, progress: done < 1 ? platform + (1 - platform) * done : 1)]
        if done < 1 {
            let tall = max(bounds.max.y * min(done + 0.12, 1), 0.2)
            pieces.append(Piece(key: .scaffold, transform: transform * .scale(Vec3(hallScaffold, tall, hallScaffold)), hex: hex))
        }
        return pieces
    }

    /// A rising hall's scaffold's width and depth, about the hall and its tower.
    public static let hallScaffold: Float = 0.9
}
