import AppKit
import LauncherCore

/// What the launcher asks of the world outside its window. Tests supply
/// their own.
struct LauncherEnvironment {
    /// Whether Apple's on-device model can be used right now.
    var modelReadiness: () -> ModelReadiness
    /// Whether macOS asks apps to save energy: Low Power Mode is on, or the
    /// Mac is running hot.
    var systemSavesEnergy: () -> Bool
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

    /// Debug builds can report the model as ready with
    /// NULLMERE_SKIP_MODEL_CHECK=1, so the menu can be opened and
    /// photographed on a machine without Apple Intelligence, such as CI.
    /// Release builds always ask the Foundation Models framework.
    static var debugReadiness: ModelReadiness? {
        #if DEBUG
        return ProcessInfo.processInfo.environment["NULLMERE_SKIP_MODEL_CHECK"] == "1" ? .ready : nil
        #else
        return nil
        #endif
    }

    /// Debug builds can open straight onto a screen with
    /// NULLMERE_LAUNCHER_SCREEN=play, news or settings.
    static var debugScreen: MenuItem? {
        #if DEBUG
        switch ProcessInfo.processInfo.environment["NULLMERE_LAUNCHER_SCREEN"] {
        case "play": return .play
        case "news": return .news
        case "settings": return .settings
        default: return nil
        }
        #else
        return nil
        #endif
    }

    static let live = LauncherEnvironment(
        modelReadiness: { LauncherEnvironment.debugReadiness ?? OnDeviceModel.readiness() },
        systemSavesEnergy: {
            let info = ProcessInfo.processInfo
            return info.isLowPowerModeEnabled || [.serious, .critical].contains(info.thermalState)
        },
        installedGame: { GameClient.installedURL() },
        openGame: { try await GameClient.open($0) },
        downloadNews: { try await NewsDownloader.download() },
        open: { NSWorkspace.shared.open($0) },
        terminate: { NSApp.terminate(nil) }
    )
}
