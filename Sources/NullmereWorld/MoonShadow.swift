import Foundation
import NullmereModels

/// The moon's shadows over what the view sees close by. Whatever stands on
/// the land (keeps, walls, works, trees, companies, townsfolk) is drawn once
/// more from the moon, into a map of how near to the moon each point of the
/// ground in view is first met; the land and the models then take the moon's
/// light only where nothing nearer to it stands between. The fill and the
/// sky still light what lies in shadow, as they light faces turned from the
/// moon.
public enum MoonShadow {
    /// The map's side, in texels.
    public static let side = 2048
    /// Nearer than this, in pixels to a world unit, the moon casts shadows;
    /// further out, what stands on the land is too small for them to be
    /// seen, and the frame is spared drawing it twice.
    public static let nearest = 40.0
    /// The tallest thing that stands on the land, in world units, the
    /// Moonspire's crown with room over it: the map holds all of it.
    public static let tallest: Float = 6
    /// How far from the middle of the view the shadows reach, in eye
    /// distances: as the view leans toward the horizon it reaches far past
    /// where a shadow could be told apart, and the map would spread thin.
    public static let reach: Float = 2.6

    /// The moon's view and projection over the ground a camera sees, from the
    /// world to the map's clip space (x and y from -1 to 1, depth from 0 at
    /// the moon's side to 1 beyond), or nil where the camera is too far out
    /// for shadows. The map is a square about the middle of the view, as wide
    /// as the furthest ground in view lies from it whichever way the view
    /// turns, and moved only by whole texels as the view pans, so its edges
    /// neither swim as the view turns nor crawl as it pans.
    public static func matrix(camera: Camera, size: CGSize, moon: Vec3 = Sky.moon) -> Mat4? {
        guard camera.scale >= nearest else { return nil }
        let focus = camera.focus
        let distance = Float(camera.distance(in: size))
        // The ground in view: where the view's corners meet the water's
        // level, held within the reach.
        var furthest: Float = 0
        for corner in [CGPoint.zero, CGPoint(x: size.width, y: 0), CGPoint(x: 0, y: size.height), CGPoint(x: size.width, y: size.height)] {
            let ground = camera.world(at: corner, in: size)
            furthest = max(furthest, (Vec3(Float(ground.x), 0, Float(ground.y)) - focus).length)
        }
        let half = min(furthest, distance * reach) + tallest
        // The moon's view of the world, the same wherever the view looks:
        // the square is laid out in it, so it moves by its own texels.
        let toward = moon.normalized
        let view = Mat4.lookAt(eye: .zero, target: -toward, up: .up)
        // The middle of the view in the moon's view, moved to a whole texel,
        // and as deep as the tallest thing on the land, either way.
        let texel = 2 * half / Float(side)
        let middle = view.transformPoint(focus)
        let x = (middle.x / texel).rounded(.down) * texel
        let y = (middle.y / texel).rounded(.down) * texel
        let deep = half + tallest + 1
        let projection = Mat4.orthographic(left: x - half, right: x + half, bottom: y - half, top: y + half,
                                           near: -(middle.z + deep), far: -(middle.z - deep))
        return projection * view
    }

    /// The width of one of the map's texels, in world units, for a moon's
    /// matrix: what the shaders feel the shadow's edge across.
    public static func texel(of matrix: Mat4) -> Float {
        let across = (matrix.c0.x * matrix.c0.x + matrix.c1.x * matrix.c1.x + matrix.c2.x * matrix.c2.x).squareRoot()
        return 2 / Float(side) / max(across, 1e-6)
    }
}
