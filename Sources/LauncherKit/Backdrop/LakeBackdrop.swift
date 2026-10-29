import LauncherCore
import SwiftUI

/// The lake behind the launcher: the Metal scene, or a static painting of it
/// when Metal is unavailable or the shader fails to build.
struct LakeBackdrop: View {
    var configuration: LakeConfiguration

    @State private var metalFailed = false

    var body: some View {
        if metalFailed || LakeMetalView.systemDevice == nil {
            LakeFallbackView(horizon: configuration.horizon)
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

/// The launcher's moonlit lake, for the game to stand its title screen on.
public struct MoonlitLake: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        LakeBackdrop(configuration: MoonlitLake.configuration(systemReducesMotion: reduceMotion))
    }

    /// The game's title screens, the realm's door and the model's gate, each
    /// stand a panel on the water, so the moon's image lies sunk beneath it
    /// as under the launcher's own panels.
    static func configuration(systemReducesMotion: Bool) -> LakeConfiguration {
        LakeConfiguration(
            motion: systemReducesMotion ? .reduced : .full,
            renderScale: 1,
            framesPerSecond: 60,
            horizon: LakeComposition.horizon,
            veil: 1
        )
    }
}
