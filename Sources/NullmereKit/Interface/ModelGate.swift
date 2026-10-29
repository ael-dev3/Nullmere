import AppKit
import Combine
import LauncherCore
import LauncherKit
import SwiftUI

/// Shown instead of the game until Apple's on-device model is ready: what
/// is missing, and where to fix it, as the launcher shows it on the water.
struct ModelGate: View {
    let app: GameApp

    private static let settingsURL = URL(string: "x-apple.systempreferences:com.apple.Siri-Settings.extension")!

    @State private var appeared = false
    /// The lit choice, the one Return performs.
    @State private var selection = 0

    /// What the gate offers: the requirement's own choices, and, crossed in
    /// from the launcher, the way back to it.
    private var choices: [(title: String, perform: () -> Void)] {
        var choices: [(title: String, perform: () -> Void)] = app.readiness.actions.map { action in
            switch action {
            case .openSystemSettings: return (action.title, { NSWorkspace.shared.open(Self.settingsURL) })
            case .quit: return (action.title, { NSApp.terminate(nil) })
            }
        }
        if app.onLeave != nil {
            choices.append(("Back", { app.leaveDoor() }))
        }
        return choices
    }

    var body: some View {
        let choices = self.choices
        ZStack {
            MoonlitLake(settings: app.displaySettings).ignoresSafeArea()
            GeometryReader { proxy in
                // Below the waterline only, as the launcher darkens it under
                // a panel: the sky and the title stay as bright as ever.
                PanelScrim()
                    .padding(.top, LakeTitle.waterline(for: proxy.size))
                    .allowsHitTesting(false)
                // The name where the launcher sets it, exactly; what is
                // missing on the water below, as the launcher shows it.
                LakeTitle(size: proxy.size, isRevealed: appeared)
                RequirementView(readiness: app.readiness, choices: choices.map(\.title), selection: $selection) { index in
                    choices[index].perform()
                }
                .padding(.top, LakeTitle.waterline(for: proxy.size) + 40 * LakeTitle.unit(for: proxy.size))
                .frame(width: proxy.size.width)
                .environment(\.launcherUnit, LakeTitle.unit(for: proxy.size))
            }
            // Measured over the whole window, as the launcher measures it.
            .ignoresSafeArea()
        }
        // Return performs the lit choice; Esc goes back where it can; the
        // arrows move along the choices, as in the launcher.
        .background {
            Button("") { if choices.indices.contains(selection) { choices[selection].perform() } }
                .keyboardShortcut(.defaultAction)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
            if app.onLeave != nil {
                Button("") { app.leaveDoor() }
                    .keyboardShortcut(.cancelAction)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
        }
        .focusable()
        .focusEffectDisabled()
        .modifier(ChoiceArrows(lit: $selection, count: choices.count))
        .onChange(of: app.readiness) { _, _ in selection = 0 }
        .onAppear {
            withAnimation(.easeOut(duration: LakeTitle.revealSeconds)) { appeared = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            app.checkModel()
        }
    }
}
