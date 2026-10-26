import AppKit

/// While the keeper is in another app, the Dock keeps count of the watches
/// that turned, and bounces once when something needs them; both clear
/// when they come back.
struct Attention: Equatable {
    /// Watches turned since the keeper last looked.
    private(set) var missed = 0
    /// Bounced already in this absence.
    private(set) var hasCalled = false

    struct Signal: Equatable {
        let badge: String?
        let bounce: Bool
    }

    /// The watch turned; returns what the Dock should show.
    mutating func watchTurned(isActive: Bool, needsKeeper: Bool) -> Signal? {
        guard !isActive else { return nil }
        missed += 1
        let bounce = needsKeeper && !hasCalled
        if bounce { hasCalled = true }
        return Signal(badge: missed > 99 ? "99+" : "\(missed)", bounce: bounce)
    }

    /// The keeper is back.
    mutating func returned() -> Signal? {
        guard missed > 0 || hasCalled else { return nil }
        missed = 0
        hasCalled = false
        return Signal(badge: nil, bounce: false)
    }

    @MainActor
    static func show(_ signal: Signal) {
        NSApplication.shared.dockTile.badgeLabel = signal.badge
        if signal.bounce {
            NSApplication.shared.requestUserAttention(.informationalRequest)
        }
    }
}
