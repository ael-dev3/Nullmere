import AppKit

/// The Nullmere game client, once there is one: a separate app that the
/// launcher finds by its bundle identifier and opens.
enum GameClient {
    static let bundleIdentifier = "online.nullmere.game"

    static func installedURL() -> URL? {
        NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleIdentifier)
    }

    static func open(_ url: URL) async throws {
        let configuration = NSWorkspace.OpenConfiguration()
        configuration.activates = true
        _ = try await NSWorkspace.shared.openApplication(at: url, configuration: configuration)
    }
}
