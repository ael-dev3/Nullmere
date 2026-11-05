import Foundation
import NullmereCore

/// An alliance's hall: a great timbered hall on a platform of dressed
/// stone, its roof in the alliance's colour with carved horns at its
/// gables; a round tower behind it flying the alliance's great banner;
/// banners hanging at the platform's corners and braziers burning at its
/// door. It faces +z, its platform a hexagon with flats to ±z, and fills
/// the heart of its hex. It is made in Blender (Art/blender/hall.py, read
/// by `Art.hall`); these are the measures the world places it by.
enum Halls {
    /// The platform's corners lie on this radius.
    static let platformRadius: Float = 0.64
    /// Where the hall's floor stands.
    static let floor: Float = 0.07
    /// The ridge of the hall's roof, its louvre over it.
    static let ridge: Float = 0.47

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
