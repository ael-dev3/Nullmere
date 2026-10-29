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
    /// whether this copy should quit.
    static func handOver(to running: [(pid: pid_t, bringForward: () -> Void)], current: pid_t) -> Bool {
        guard let pid = other(among: running.map(\.pid), current: current),
              let first = running.first(where: { $0.pid == pid }) else { return false }
        first.bringForward()
        return true
    }

    /// The same, for the copies the Mac is running. A bare executable
    /// (`swift run`) has no bundle identifier and is never turned away.
    @MainActor
    public static func handOver() -> Bool {
        guard let identifier = Bundle.main.bundleIdentifier else { return false }
        let running = NSRunningApplication.runningApplications(withBundleIdentifier: identifier)
        return handOver(to: running.map { app in (app.processIdentifier, { app.activate(options: []) }) },
                        current: ProcessInfo.processInfo.processIdentifier)
    }
}
