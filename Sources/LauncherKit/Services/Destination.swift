import Foundation

/// Places outside the window that the launcher opens.
enum Destination {
    static let website = URL(string: "https://nullmere.online")!
    static let repository = URL(string: "https://github.com/ael-dev3/Nullmere")!
    /// System Settings, at Apple Intelligence & Siri.
    static let appleIntelligenceSettings = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!
    static let systemSettings = URL(fileURLWithPath: "/System/Applications/System Settings.app")
}
