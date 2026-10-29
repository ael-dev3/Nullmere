import AppKit
import Combine
import LauncherCore
import SwiftUI

/// The launcher window: the lake under a full moon, the title resting above
/// the far shore, and the menu or a panel on the water below it.
public struct LauncherRootView: View {
    private let model: LauncherModel

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.colorSchemeContrast) private var contrast

    public init(model: LauncherModel) {
        self.model = model
    }

    public var body: some View {
        GeometryReader { proxy in
            let unit = CGFloat(LakeComposition.unit(width: proxy.size.width, height: proxy.size.height))
            let waterline = CGFloat(LakeComposition.waterline(forHeight: proxy.size.height))
            let motion = model.settings.motion.resolved(systemReducesMotion: reduceMotion)

            ZStack(alignment: .top) {
                LakeBackdrop(configuration: model.backdropConfiguration(systemReducesMotion: reduceMotion))

                // The lake surfaces from black when the launcher opens.
                Color.black
                    .opacity(model.intro.showsScene ? 0 : 1)
                    .allowsHitTesting(false)

                // Panels darken the water beneath them, so their text stays
                // legible; the lake sinks the moon's image under them too.
                PanelScrim()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, waterline)
                    .opacity(model.screen == .title && !model.isGated ? 0 : 1)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.5), value: model.screen)
                    .animation(.easeInOut(duration: 0.5), value: model.isGated)

                LakeTitle(size: proxy.size, isRevealed: model.intro.showsTitle, settlesLetters: motion == .full)

                ScreenContent(model: model)
                    .opacity(model.intro.showsMenu ? 1 : 0)
                    .allowsHitTesting(model.intro.showsMenu)
                    .disabled(!model.intro.showsMenu || model.isLeaving)
                    .frame(maxWidth: .infinity)
                    .padding(.top, waterline)
                    .animation(.easeInOut(duration: 0.5), value: model.screen)
                    .animation(.easeInOut(duration: 0.6), value: model.isGated)

                LauncherFooter(version: model.version, readiness: model.readiness, hint: model.footerHint) {
                    model.openWebsite()
                }
                .opacity(model.intro.showsMenu ? 1 : 0)
                .allowsHitTesting(model.intro.showsMenu)
                .disabled(!model.intro.showsMenu || model.isLeaving)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .animation(.easeInOut(duration: 0.5), value: model.footerHint)

                // Quitting, or crossing into the game, fades everything to black.
                Color.black
                    .opacity(model.isLeaving ? 1 : 0)
                    .allowsHitTesting(model.isLeaving)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.launcherUnit, unit)
        }
        .ignoresSafeArea()
        .frame(minWidth: 960, minHeight: 600)
        .background(Color.black)
        .preferredColorScheme(.dark)
        // The menu bar offers Settings… and News only when the window does.
        .focusedSceneValue(\.launcherIsGated, model.isGated)
        .background(
            WindowBridge(startsInFullScreen: model.settings.startsInFullScreen) { key in
                model.handle(key)
            } onClick: {
                // A click anywhere during the opening skips it.
                model.completeIntro()
            }
        )
        // The launcher's type and the realm's read by one rule of contrast.
        .onChange(of: contrast, initial: true) { _, contrast in
            Contrast.shared.isIncreased = contrast == .increased
        }
        .onAppear {
            model.beginIntro(systemReducesMotion: reduceMotion)
            model.refreshReadiness()
            model.refreshEnergyState()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            model.didBecomeActive()
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didResignActiveNotification)) { _ in
            model.didResignActive()
        }
        .onReceive(Self.energyStateChanges) { _ in
            model.refreshEnergyState()
        }
    }

    /// Low Power Mode turning on or off, or the Mac heating up or cooling
    /// down. macOS announces these on other threads.
    static let energyStateChanges: AnyPublisher<Notification, Never> =
        NotificationCenter.default.publisher(for: .NSProcessInfoPowerStateDidChange)
            .merge(with: NotificationCenter.default.publisher(for: ProcessInfo.thermalStateDidChangeNotification))
            .receive(on: DispatchQueue.main)
            .eraseToAnyPublisher()
}

/// The menu or the open panel, or the requirement screen until this Mac's
/// on-device model is ready. Each sits at its own depth below the waterline.
private struct ScreenContent: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        ZStack(alignment: .top) {
            if model.isGated {
                RequirementPanel(model: model)
                    .padding(.top, 40 * unit)
                    .transition(.opacity)
            } else {
                screen
                    .transition(.opacity)
            }
        }
    }

    @ViewBuilder
    private var screen: some View {
        ZStack(alignment: .top) {
            switch model.screen {
            case .title:
                MainMenu(model: model)
                    .padding(.top, 62 * unit)
                    .transition(.opacity)
            case .news:
                NewsPanel(model: model)
                    .padding(.top, 28 * unit)
                    .transition(.opacity)
            case .settings:
                SettingsPanel(model: model)
                    .padding(.top, 34 * unit)
                    .transition(.opacity)
            }
        }
    }
}

/// A soft darkness on the water under an open panel: below the waterline
/// only, so the sky and the title stay as bright as ever. The realm's door
/// and gate lay the same under theirs.
public struct PanelScrim: View {
    public init() {}

    /// Where the moon's reflection lies, as a fraction of the water's
    /// height below the waterline: the moon stands as far above the
    /// horizon as its image lies below it.
    static var reflectionDepth: Double {
        (LakeComposition.moonY - LakeComposition.horizon) / LakeComposition.horizon
    }

    public var body: some View {
        // Darkest over the moon's reflection, where the panels' text and
        // buttons lie, and clear toward the far edges of the lake.
        EllipticalGradient(
            stops: [
                .init(color: .black.opacity(0.9), location: 0),
                .init(color: .black.opacity(0.86), location: 0.35),
                .init(color: .black.opacity(0.5), location: 0.7),
                .init(color: .clear, location: 1),
            ],
            center: UnitPoint(x: 0.5, y: Self.reflectionDepth - 0.1),
            startRadiusFraction: 0,
            endRadiusFraction: 0.7
        )
    }
}
