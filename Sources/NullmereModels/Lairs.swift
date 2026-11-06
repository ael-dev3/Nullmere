import Foundation
import NullmereCore

/// The lairs of the wilds, each filling the heart of its hex: a salt hollow
/// bristling with spars, a stockade of the Reavers round its fire, the hall
/// of a barrow under its mound, a hunters' eyrie on its rock, and a drowned
/// chapel half sunk in the strand; and the gatehold the wilds keep at each
/// gate of the Crown. Each has a light of its own that burns all night:
/// firelight for the living, the wilds' pale glow for the rest. They are
/// made in Blender (Art/blender/lairs.py); where their fires smoke is kept
/// here.
enum Lairs {
    /// Where smoke rises from a gatehold's fire, in its own frame.
    static let gateFire = Vec3(0.12, 0.08, 0.26)

    /// Where smoke rises from a lair's fire, in its own frame.
    static func fire(of kind: WildKind) -> Vec3? {
        switch kind {
        case .reavers: return Vec3(0, 0.12, 0.02)
        case .spineHunters: return Vec3(-0.12, 0.32, 0.1)
        case .saltwights, .barrowkin, .drowned: return nil
        }
    }
}
