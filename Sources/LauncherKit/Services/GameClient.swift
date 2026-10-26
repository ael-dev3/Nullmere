import AppKit

/// The Nullmere game: a separate app that the launcher finds beside itself,
/// or anywhere macOS knows it by its bundle identifier, and opens.
enum GameClient {
    static let bundleIdentifier = "online.nullmere.game"

    static func installedURL() -> URL? {
        let sibling = Bundle.main.bundleURL.deletingLastPathComponent().appendingPathComponent("Nullmere.app")
        if Bundle(url: sibling)?.bundleIdentifier == bundleIdentifier {
            return sibling
        }
        return NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static func open(_ url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
