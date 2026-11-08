import Foundation

/// How much moonlight the world is drawn with, as the keeper chooses it in
/// the realm's Settings: dark, as the lake was made, or lighter for an
/// easier eye. Every pass of the picture takes it alike (the land, the
/// water, what stands on the land, the sky), so the night keeps its look
/// and only its light grows.
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

    /// What every colour of the world is multiplied by as it is drawn.
    public var exposure: Float {
        switch self {
        case .dark: return 1
        case .moonlit: return 1.35
        case .bright: return 1.75
        }
    }
}
