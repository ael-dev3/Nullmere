import AppKit

/// The Nullmere game: a separate app that the launcher finds beside itself,
/// or anywhere macOS knows it by its bundle identifier, and opens.
enum GameClient {
    static let bundleIdentifier = "online.nullmere.game"

    static func installedURL() -> URL? {
        #if DEBUG
        // Debug builds can be pointed at a built game, such as CI's.
        if let path = ProcessInfo.processInfo.environment["NULLMERE_GAME_APP"], !path.isEmpty {
            let url = URL(fileURLWithPath: path)
            return Bundle(url: url)?.bundleIdentifier == bundleIdentifier ? url : nil
        }
        #endif
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
