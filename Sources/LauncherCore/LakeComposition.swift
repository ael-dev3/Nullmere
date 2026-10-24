/// Geometry shared by the Metal scene and the interface laid over it.
///
/// The moon constants mirror `NM_MOON_*` in the lake shader; a test keeps
/// the two in step.
public enum LakeComposition {
    /// Height of the waterline above the bottom edge, as a fraction of the view height.
    public static let horizon = 0.45

    /// Moon centre as a fraction of the view width, and of the height above the bottom edge.
    public static let moonX = 0.705
    public static let moonY = 0.805
    /// Moon radius as a fraction of the view height.
    public static let moonRadius = 0.027

    /// The height type and spacing are designed at.
    public static let referenceHeight = 800.0

    /// Scale for type and spacing: 1 at the reference height, clamped so the
    /// interface stays legible in small windows and calm on large displays.
    public static func unit(forHeight height: Double) -> Double {
        min(max(height / referenceHeight, 0.72), 1.7)
    }

    /// Distance from the top edge to the waterline, in points.
    public static func waterline(forHeight height: Double) -> Double {
        height * (1 - horizon)
    }
}
