import AppKit
import Combine
import LauncherCore
import SwiftUI

/// Shown instead of the game until Apple's on-device model is ready: what
/// is missing, and where to fix it.
struct ModelGate: View {
    let app: GameApp

    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            VStack(spacing: 18) {
                Caps("Nullmere", size: 30, weight: .thin, tracking: 0.5)
                    .foregroundStyle(Palette.ink.opacity(0.9))
                Rule(opacity: 0.4).frame(width: 260)
                Caps(app.readiness.headline, size: 12, weight: .medium)
                    .foregroundStyle(Palette.ink)
                    .accessibilityAddTraits(.isHeader)
                Text(verbatim: app.readiness.explanation)
                    .font(.system(size: 13, weight: .light))
                    .foregroundStyle(Palette.ink.opacity(0.7))
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
                }
                .padding(.top, 6)
            }
            .padding(40)
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            app.checkModel()
        }
    }
}
