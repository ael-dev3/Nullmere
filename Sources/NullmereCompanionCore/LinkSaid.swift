import Foundation

/// The phone's link to the realm in words, one wording wherever it is told.
public enum LinkSaid {
    /// A span of time as the phone says it: "12 s", "1:05", "14 min".
    public static func span(_ seconds: TimeInterval) -> String {
        let whole = max(0, Int(seconds.rounded(.down)))
        if whole < 60 { return "\(whole) s" }
        if whole < 600 { return String(format: "%d:%02d", whole / 60, whole % 60) }
        return "\(whole / 60) min"
    }

    /// In reach, and when the realm was last heard from.
    public static func inStep(heardAgo seconds: TimeInterval) -> String {
        "In step with the realm, heard from \(span(seconds)) ago."
    }

    /// Out of reach for so long, the phone trying again on its own.
    public static func outOfTouch(for seconds: TimeInterval, tries: Int) -> String {
        let tried = tries == 1 ? "1 try" : "\(tries) tries"
        return "Out of touch for \(span(seconds)), and trying again (\(tried) so far): orders given now go when the realm answers."
    }

    /// In reach again, and how long it was out of touch.
    public static func backInStep(after seconds: TimeInterval) -> String {
        "Back in step with the realm after \(span(seconds)) out of touch."
    }
}
