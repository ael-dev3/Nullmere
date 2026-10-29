import AppKit
import LauncherCore
import SwiftUI

/// The lake behind the launcher: the Metal scene, or a static painting of it
/// when Metal is unavailable or the shader fails to build.
struct LakeBackdrop: View {
    var configuration: LakeConfiguration

    @State private var metalFailed = false

    var body: some View {
        if metalFailed || LakeMetalView.systemDevice == nil {
            LakeFallbackView(horizon: configuration.horizon, veil: configuration.veil)
        } else {
            LakeMetalRepresentable(configuration: configuration) {
                metalFailed = true
            }
        }
    }
}

private struct LakeMetalRepresentable: NSViewRepresentable {
    var configuration: LakeConfiguration
    var onFailure: () -> Void

    func makeNSView(context: Context) -> LakeMetalView {
        let view = LakeMetalView(configuration: configuration)
        view.onFailure = onFailure
        return view
    }

    func updateNSView(_ view: LakeMetalView, context: Context) {
        view.configuration = configuration
    }

    /// Taken out of the window with the launcher as it crosses to the realm:
    /// leave the view tree here too, so nothing detached keeps the lake alive.
    static func dismantleNSView(_ view: LakeMetalView, coordinator: ()) {
        view.removeFromSuperview()
    }
}

/// The launcher's moonlit lake, for the game to stand its title screen on:
/// drawn as the launcher's settings say, and slowed as the launcher's is
/// while another app is in front or the Mac saves energy.
public struct MoonlitLake: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isInFront = true
    @State private var savesEnergy = LauncherEnvironment.live.systemSavesEnergy()
    private let settings: LauncherSettings

    public init(defaults: UserDefaults = .standard) {
        settings = LauncherSettings(defaults: defaults)
    }

    public var body: some View {
        LakeBackdrop(configuration: MoonlitLake.configuration(settings: settings, systemReducesMotion: reduceMotion,
                                                              isSavingEnergy: !isInFront || savesEnergy))
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
                isInFront = true
            }
            .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
                isInFront = false
            }
            .onReceive(LauncherRootView.energyStateChanges) { _ in
                savesEnergy = LauncherEnvironment.live.systemSavesEnergy()
            }
    }

    /// The game's title screens, the realm's door and the model's gate, each
    /// stand a panel on the water, so the moon's image lies sunk beneath it
    /// as under the launcher's own panels.
    static func configuration(settings: LauncherSettings = LauncherSettings(), systemReducesMotion: Bool,
                              isSavingEnergy: Bool = false) -> LakeConfiguration {
        let motion = settings.motion.resolved(systemReducesMotion: systemReducesMotion)
        return LakeConfiguration(
            motion: motion,
            renderScale: settings.quality.scale,
            framesPerSecond: settings.frameRate.framesPerSecond(motion: motion, isSavingEnergy: isSavingEnergy),
            horizon: LakeComposition.horizon,
            veil: 1
        )
    }
}
