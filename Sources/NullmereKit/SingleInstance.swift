import AppKit

/// One copy of the game at a time: two on one Mac would be the same keeper
/// twice, each leaving the realm under the other, their readiness crossed.
/// A second copy opened hands over to the first and quits.
public enum SingleInstance {
    /// The process of another copy already running, if any.
    static func other(among running: [pid_t], current: pid_t) -> pid_t? {
        running.first { $0 != current }
    }

    /// Brings forward the copy already running, if there is one; returns
    /// whether this copy should quit. A bare executable (`swift run`) has
    /// no bundle identifier and is never turned away.
    @MainActor
    public static func handOver() -> Bool {
        guard let identifier = Bundle.main.bundleIdentifier else { return false }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        guard let pid = other(among: running.map(\.processIdentifier), current: ProcessInfo.processInfo.processIdentifier),
              let first = running.first(where: { $0.processIdentifier == pid })
        else { return false }
        first.activate(options: [])
        return true
    }
}
