import Foundation

/// Tokens drawn for any realm on any thread, each unlike any drawn before
/// it: whatever keeps one (the holds' claims, where the companies stand)
/// knows that two of its kind holding the same token are the same, however
/// either came by it.
enum Tokens {
    private static let drawn = Drawn()

    /// A token none drawn before it shares.
    static func next() -> UInt64 {
        drawn.next()
    }

    private final class Drawn: @unchecked Sendable {
        private let lock = NSLock()
        private var last: UInt64 = 0

        func next() -> UInt64 {
            lock.lock()
            defer { lock.unlock() }
            last += 1
            return last
        }
    }
}
