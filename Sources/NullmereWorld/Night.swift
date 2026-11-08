import Foundation

/// How much moonlight the world is drawn with, as the keeper chooses it in
/// the realm's Settings: dark, as the lake was made, or lighter for an
/// easier eye. Every pass of the picture takes it alike (the land, the
/// water, what stands on the land, the sky), so the night keeps its look
/// and only its light grows: its darkest colours lifted most, the brighter
/// less and full light not at all (the shaders' `nm_expose`), so the dark
/// ground comes up into sight while a lit window or a fire never burns
/// white. The light of sparks and fires is their own and never lifted.
public enum Night: Int, CaseIterable, Sendable {
    case dark
    case moonlit
    case bright

    /// Where the choice is kept, among the realm's own settings.
    public static let key = "world.night"

    /// The choice kept as `stored`; dark where none is, or none that reads.
    public init(stored: Int) {
        self = Night(rawValue: stored) ?? .dark
    }

    public var title: String {
        switch self {
        case .dark: return "Dark"
        case .moonlit: return "Moonlit"
        case .bright: return "Bright"
        }
    }

    /// How many times the world's darkest colours are lifted as it is
    /// drawn, the brighter ones less and full light kept full: the night as
    /// made is 1, which leaves every colour as it is.
    public var exposure: Float {
        switch self {
        case .dark: return 1
        case .moonlit: return 2
        case .bright: return 3
        }
    }
}
