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

    /// Debug builds can be driven by keys, as if typed once the opening is
    /// over: NULLMERE_LAUNCHER_KEYS=right,return presses → then Return.
    /// The keys take the same path as the window's.
    static var debugKeys: [KeyCommand] {
        #if DEBUG
        let words = (ProcessInfo.processInfo.environment["NULLMERE_LAUNCHER_KEYS"] ?? "").split(separator: ",")
        return words.compactMap { word in
            switch word.trimmingCharacters(in: .whitespaces).lowercased() {
            case "up": return .up
            case "down": return .down
            case "left": return .left
            case "right": return .right
            case "return", "enter", "space": return .confirm
            case "escape", "esc": return .back
            default: return nil
            }
        }
        #else
        return []
        #endif
    }

    static let live = LauncherEnvironment(
        modelReadiness: { OnDeviceModel.current() },
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
