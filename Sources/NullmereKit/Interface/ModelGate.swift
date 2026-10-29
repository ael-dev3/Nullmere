import AppKit
import Combine
import LauncherCore
import LauncherKit
import SwiftUI

/// Shown instead of the game until Apple's on-device model is ready: what
/// is missing, and where to fix it.
struct ModelGate: View {
    let app: GameApp

    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!

    var body: some View {
        ZStack {
            MoonlitLake().ignoresSafeArea()
            // Darken the water beneath the words, as the launcher does.
            EllipticalGradient(
                colors: [.black.opacity(0.75), .black.opacity(0.45), .clear],
                center: UnitPoint(x: 0.5, y: 0.62),
                startRadiusFraction: 0,
                endRadiusFraction: 0.6
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)
            // The name where the launcher sets it, exactly; what is missing
            // on the water below, as the launcher shows it.
            GeometryReader { proxy in
                LakeTitle(size: proxy.size)
                VStack(spacing: 18) {
                    Spacer(minLength: 0)
                        .frame(height: LakeTitle.waterline(for: proxy.size) + 12)
                    Caps(app.readiness.headline, size: 12, weight: .medium)
                        .foregroundStyle(Palette.ink)
                        .accessibilityAddTraits(.isHeader)
                    Text(verbatim: app.readiness.explanation)
                        .font(.nm(13, weight: .light))
                        .foregroundStyle(Palette.text(0.7))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                    if app.readiness == .checking {
                        ProgressView().controlSize(.small).tint(Palette.ink)
                    }
                    HStack(spacing: 8) {
                        ForEach(app.readiness.actions, id: \.title) { action in
                            switch action {
                            case .openSystemSettings:
                                QuietButton(title: action.title, size: 10, prominent: true) {
                                    NSWorkspace.shared.open(Self.settingsURL)
                                }
                            case .quit:
                                QuietButton(title: action.title, size: 10) { NSApp.terminate(nil) }
                            }
                        }
                        // Crossed in from the launcher: the way back to it.
                        if app.onLeave != nil {
                            QuietButton(title: "Back", size: 10) { app.leaveDoor() }
                                .keyboardShortcut(.cancelAction)
                        }
                    }
                    .padding(.top, 6)
                    Spacer(minLength: 0)
                }
                .padding(.horizontal, 40)
                .frame(width: proxy.size.width)
            }
            // Measured over the whole window, as the launcher measures it.
            .ignoresSafeArea()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            app.checkModel()
        }
    }
}
