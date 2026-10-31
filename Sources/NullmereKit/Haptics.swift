import AppKit

/// The trackpad's taps, where the Mac has a trackpad that gives them and a
/// finger is on it: a light one as an order is given, a firmer one as the
/// rules refuse it. Nothing for the rest; the sounds say enough.
enum Haptics {
    /// What the trackpad does for a cue, if anything.
    static func pattern(for cue: Ambience.Cue) -> NSHapticFeedbackManager.FeedbackPattern? {
        switch cue {
        case .order, .ride: return .alignment
        case .deny: return .levelChange
        default: return nil
        }
    }

    static func tap(for cue: Ambience.Cue) {
        guard let pattern = pattern(for: cue) else { return }
        NSHapticFeedbackManager.defaultPerformer.perform(pattern, performanceTime: .now)
    }
}
