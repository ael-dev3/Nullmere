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
}

/// The launcher's moonlit lake, for the game to stand its title screen on.
public struct MoonlitLake: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    public init() {}

    public var body: some View {
        let motion: ResolvedMotion = reduceMotion ? .reduced : .full
        LakeBackdrop(configuration: LakeConfiguration(
            motion: motion,
            renderScale: 1,
            framesPerSecond: 60,
            horizon: LakeComposition.horizon
        ))
    }
}
