import AppKit
import LauncherCore

/// What the launcher asks of the world outside its window. Tests supply
/// their own.
struct LauncherEnvironment {
    /// Whether Apple's on-device model can be used right now.
    var modelReadiness: () -> ModelReadiness
    /// Where the game client is installed, if it is.
    var installedGame: () -> URL?
    /// Opens the game client.
    var openGame: (URL) async throws -> Void
    /// Downloads the news feed.
    var downloadNews: () async throws -> Data
    /// Opens a link in the browser or System Settings; false if nothing opened it.
    var open: (URL) -> Bool
    /// Quits the launcher.
    var terminate: @MainActor () -> Void

    static let live = LauncherEnvironment(
        modelReadiness: { OnDeviceModel.readiness() },
        installedGame: { GameClient.installedURL() },
        openGame: { try await GameClient.open($0) },
        downloadNews: { try await NewsDownloader.download() },
        open: { NSWorkspace.shared.open($0) },
        terminate: { NSApp.terminate(nil) }
    )
}
