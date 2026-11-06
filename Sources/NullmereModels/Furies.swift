import NullmereCore

/// How a commander's skill looks as it fires, by the commander's
/// archetype: a ward of pale light for a warden's, fire thrown out for a
/// vanguard's, shafts of light falling for an outrider's, a ring of gold
/// for a gleaner's, the ground breaking for a wallbreaker's.
public enum FuryLook: String, CaseIterable, Sendable {
    case ward, blaze, volley, ring, quake

    public static func of(_ skill: Skill) -> FuryLook {
        switch skill.archetype {
        case .warden: return .ward
        case .vanguard: return .blaze
        case .outrider: return .volley
        case .gleaner: return .ring
        case .wallbreaker: return .quake
        }
    }

    /// The light it gives the ground about it, at its brightest.
    public var glow: Vec3 {
        switch self {
        case .ward: return Vec3(0.9, 1.3, 2.2)
        case .blaze: return Vec3(2.6, 1.2, 0.4)
        case .volley: return Vec3(2.0, 1.8, 1.3)
        case .ring: return Vec3(2.0, 1.8, 1.1)
        case .quake: return Vec3(1.2, 0.8, 0.5)
        }
    }
}
