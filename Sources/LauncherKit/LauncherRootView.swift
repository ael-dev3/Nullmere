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
                // legible; the lake dims the moon's image under them too.
                PanelScrim()
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .padding(.top, waterline)
                    .opacity(model.screen == .title && !model.isGated ? 0 : 1)
                    .allowsHitTesting(false)
                    .animation(.easeInOut(duration: 0.5), value: model.screen)
                    .animation(.easeInOut(duration: 0.5), value: model.isGated)

                LakeTitle(size: proxy.size, isRevealed: model.intro.showsTitle, settlesLetters: motion == .full)

                // The open screen on the water, the footer beneath it, and
                // never the one run into the other.
                let stage = LauncherStage(depth: waterline, ceiling: LakeTitle.band(for: proxy.size), gap: 14 * unit)
                stage {
                    ScreenContent(model: model)
                        .opacity(model.intro.showsMenu ? 1 : 0)
                        .allowsHitTesting(model.intro.showsMenu)
                        .disabled(!model.intro.showsMenu || model.isLeaving)
                        .frame(maxWidth: .infinity)
                        .animation(.easeInOut(duration: 0.5), value: model.screen)
                        .animation(.easeInOut(duration: 0.6), value: model.isGated)

                    LauncherFooter(version: model.version, readiness: model.readiness, hint: model.footerHint) {
                        model.openWebsite()
                    }
                    .opacity(model.intro.showsMenu ? 1 : 0)
                    .allowsHitTesting(model.intro.showsMenu)
                    .disabled(!model.intro.showsMenu || model.isLeaving)
                    .animation(.easeInOut(duration: 0.5), value: model.footerHint)
                }

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

/// The open screen and the footer beneath it. The screen lies at its depth
/// below the waterline where there's room. Where there isn't (a short
/// window, Larger type), it rises just enough to end a gap above the
/// footer, but no higher than the title's foot; and where even that isn't
/// room enough, it is offered only the room there is, and draws its lines
/// closer to fit it (see `ScreenContent`).
struct LauncherStage: Layout {
    /// Where the screen's top lies when there's room: the waterline.
    var depth: CGFloat
    /// The highest the screen's top may rise: the title's foot.
    var ceiling: CGFloat
    /// The least water between the screen and the footer.
    var gap: CGFloat

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        proposal.replacingUnspecifiedDimensions()
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        guard subviews.count == 2 else { return }
        let screen = subviews[0], footer = subviews[1]
        let footerHeight = footer.sizeThatFits(ProposedViewSize(width: bounds.width, height: nil)).height
        footer.place(at: CGPoint(x: bounds.minX, y: bounds.maxY - footerHeight), anchor: .topLeading,
                     proposal: ProposedViewSize(width: bounds.width, height: footerHeight))
        let floor = bounds.height - footerHeight - gap
        let height = screen.sizeThatFits(ProposedViewSize(width: bounds.width, height: max(floor - ceiling, 0))).height
        let top = LakeComposition.screenTop(depth: Double(depth), ceiling: Double(ceiling), floor: Double(floor), height: Double(height))
        screen.place(at: CGPoint(x: bounds.minX, y: bounds.minY + CGFloat(top)), anchor: .topLeading,
                     proposal: ProposedViewSize(width: bounds.width, height: height))
    }
}

/// The open screen at the launcher's own rhythm where it fits the room the
/// stage offers it; its lines drawn closer, and closer again, where it
/// doesn't. Only the one shown is made: one screen to see, to click and to
/// read with VoiceOver.
private struct ScreenContent: View {
    let model: LauncherModel

    /// The rhythms tried, in turn.
    static let rhythms: [CGFloat] = [1, 0.7, 0.45]

    var body: some View {
        ViewThatFits(in: .vertical) {
            ScreenStack(model: model)
            ScreenStack(model: model).environment(\.launcherRhythm, Self.rhythms[1])
            ScreenStack(model: model).environment(\.launcherRhythm, Self.rhythms[2])
        }
    }
}

/// The menu or the open panel, or the requirement screen until this Mac's
/// on-device model is ready. Each sits at its own depth below the waterline.
private struct ScreenStack: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @Environment(\.launcherRhythm) private var rhythm

    var body: some View {
        ZStack(alignment: .top) {
            if model.isGated {
                RequirementPanel(model: model)
                    .padding(.top, 40 * unit * rhythm)
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
                    .padding(.top, 62 * unit * rhythm)
                    .transition(.opacity)
            case .news:
                NewsPanel(model: model)
                    .padding(.top, 28 * unit * rhythm)
                    .transition(.opacity)
            case .settings:
                SettingsPanel(model: model)
                    .padding(.top, 34 * unit * rhythm)
                    .transition(.opacity)
            case .credits:
                CreditsPanel(model: model)
                    .padding(.top, 28 * unit * rhythm)
                    .transition(.opacity)
            case .mishap:
                MishapPanel(model: model)
                    .padding(.top, 34 * unit * rhythm)
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
