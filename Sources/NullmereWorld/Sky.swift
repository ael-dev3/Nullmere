import NullmereModels

/// The night over the Nullmere: where the moon hangs and how strongly it
/// lights the land.
public enum Sky {
    /// Toward the moon: a touch east of north, two fifths of the way up
    /// the sky, so a view across the lake toward the north holds it in the
    /// water.
    public static let moon = Vec3(0.103, 0.669, -0.736).normalized
    public static let moonStrength: Float = 1.5

    /// The night's haze for a view: it begins a little past the middle of
    /// the view and thickens beyond.
    public static func haze(eyeDistance: Float, exposure: Float = 1, spacing: Float) -> Vec4 {
        Vec4(eyeDistance * 0.9, 0.9 / max(eyeDistance, 1), exposure, spacing)
    }
}
