import Foundation
import NullmereCore

/// What an alliance raises on its land for its stores: a storehouse, and a
/// yard for each store, each with the alliance's colour about it, made in
/// Blender (Art/blender/stores.py). They face +z and fill the heart of
/// their hex; what the world places and lights by is kept here.
enum Stores {
    /// Where the barn stands, a little back from the hex's heart.
    static let barnAt = Vec3(0, 0, -0.08)
    /// The top of its footing, laid before the barn rises.
    static let footing: Float = 0.04
    /// Where smoke rises from the salt works' boiling house.
    static let saltSmoke = Vec3(0.32, 0.36, 0.22)
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
