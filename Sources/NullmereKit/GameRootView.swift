import AppKit
import LauncherCore
import LauncherKit
import NullmereCore
import SwiftUI

/// The world's window: the model gate, the realm's front door, or the lake.
public struct GameRootView: View {
    let app: GameApp
    @Environment(\.colorSchemeContrast) private var contrast
    @Environment(\.accessibilityDifferentiateWithoutColor) private var differentiate

    public init(app: GameApp) {
        self.app = app
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch app.phase {
            case .gate:
                ModelGate(app: app)
                    .transition(.opacity)
            case .frontDoor:
                FrontDoor(app: app)
                    .transition(.opacity)
            case .playing(let session):
                PlayView(app: app, session: session)
                    .id(ObjectIdentifier(session))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: phaseKey)
        .sheet(isPresented: Binding(get: { app.showsSettings }, set: { app.showsSettings = $0 })) {
            VStack(spacing: 0) {
                GameSettingsView(app: app)
                HStack {
                    Spacer()
                    QuietButton(title: "Done", size: 10, prominent: true) { app.showsSettings = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding([.horizontal, .bottom], 22)
            }
            // On the realm's own dark, as its panels are.
            .background(Palette.panel)
            .preferredColorScheme(.dark)
            // One sheet, named to VoiceOver for what it holds.
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Settings")
        }
        .preferredColorScheme(.dark)
        .onChange(of: contrast, initial: true) { _, contrast in
            Contrast.shared.isIncreased = contrast == .increased
        }
        .onChange(of: differentiate, initial: true) { _, differentiate in
            Contrast.shared.differentiates = differentiate
        }
        .frame(minWidth: 960, minHeight: 600)
    }

    private var phaseKey: Int {
        switch app.phase {
        case .gate: return 0
        case .frontDoor: return 1
        case .playing(let session): return 2 + ObjectIdentifier(session).hashValue
        }
    }
}

/// A game in progress: the map, with the interface laid over its edges.
struct PlayView: View {
    let app: GameApp
    let session: GameSession
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    /// VoiceOver's cursor, carried into a panel as it opens, by its key or
    /// a button alike.
    @AccessibilityFocusState private var panelFocused: Bool
    /// The small map of the lake, shown only when asked for on the rail.
    @AppStorage(MiniMap.shownKey) private var mapShown = false
    /// The charges put away: counsel may speak in their place.
    @AppStorage("charges.hidden") private var chargesHidden = false

    /// The display settings' Motion, the launcher's, with the system's
    /// Reduce Motion where it says to follow it.
    private var motion: ResolvedMotion {
        app.displaySettings.motion.resolved(systemReducesMotion: reduceMotion)
    }

    /// Panels slide in at full motion; below it they only fade in.
    private var panelTransition: AnyTransition {
        motion == .full ? .move(edge: .trailing).combined(with: .opacity) : .opacity
    }

    var body: some View {
        ZStack {
            WorldView(session: session)
                .ignoresSafeArea()
                .accessibilityHidden(session.isShowingCard)
            MapVignette()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(session: session)
                // The omen under the bar, in the flow, so nothing sits beneath it.
                if let omen = session.state.currentOmen {
                    OmenBand(omen: omen, watch: session.state.watch)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                // The moon's ford, only about the full.
                if let line = MoonBand.line(watch: session.state.watch, open: session.state.ford != nil) {
                    MoonBand(line: line)
                        .padding(.top, 8)
                        .allowsHitTesting(false)
                        .transition(.opacity)
                }
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoticeFeed(session: session)
                            .layoutPriority(-1)
                        Spacer(minLength: 0)
                        // The briefing says it first; then the first steps,
                        // and counsel once they're done.
                        if session.seatBriefing == nil {
                            if let steps = session.firstSteps {
                                FirstStepsCard(steps: steps) { session.dismissFirstSteps() }
                                    .transition(.opacity)
                            } else if !chargesHidden, session.state.realmBoard(for: session.player).charge != nil {
                                // The first hour's charges; counsel when none is before the House.
                                ChargeCard(session: session)
                            } else {
                                CounselCard(session: session)
                            }
                        }
                        SelectionPanel(session: session)
                            .transition(.opacity)
                    }
                    Spacer(minLength: 16)
                    VStack(alignment: .trailing, spacing: 12) {
                        switch session.panel {
                        case .houses?:
                            opened(HousesPanel(session: session), named: "Houses")
                        case .chronicle?:
                            opened(ChroniclePanel(session: session), named: "Chronicle")
                        case .guide?:
                            opened(GuidePanel(session: session), named: "Guide")
                        case .archive?:
                            opened(ArchivePanel(session: session), named: "Archive")
                        case .commanders?:
                            opened(CommandersPanel(session: session), named: "Commanders")
                        case .alliance?:
                            opened(AlliancePanel(session: session), named: "Alliance")
                        case .realm?:
                            opened(RealmPanel(session: session), named: "The Realm")
                        case .words?:
                            opened(WordsPanel(session: session), named: "Words")
                        case nil:
                            EmptyView()
                        }
                        Spacer(minLength: 0)
                        EnvoyCards(session: session)
                        // With a panel open, its keys and its close button
                        // serve, and the panel keeps the column's height.
                        if session.panel == nil {
                            if mapShown {
                                MiniMap(session: session)
                                    .transition(.opacity)
                            }
                            PanelRail(session: session)
                                .transition(.opacity)
                        }
                        // The keys, while the first steps are taught; the
                        // Guide and each button's tooltip keep them after.
                        if session.firstSteps != nil {
                            KeyHints()
                        }
                    }
                }
                .padding(16)
                .animation(.easeOut(duration: 0.2), value: session.panel)
                .animation(.easeOut(duration: 0.3), value: session.envoys)
            }
            // A card before the world: VoiceOver reads the card alone.
            .accessibilityHidden(session.isShowingCard)

            if let card = session.watchCard {
                // High in the view, above where the seat is centred.
                WatchCard(summary: card.summary)
                    .id(card.id)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 130)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            // Between the selection panel on the left and the hints on the
            // right, so it never lies over either.
            HoverLine(session: session)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
                .padding(.leading, 362)
                .padding(.trailing, 240)
                .padding(.bottom, 18)
                .allowsHitTesting(false)

            if let briefing = session.seatBriefing, session.state.outcome == nil {
                SeatBriefingCard(briefing: briefing, colour: Palette.house(session.playerHouse)) { session.dismissSeatBriefing() }
                    .transition(.opacity)
            }

            if let report = session.awayReport, session.state.outcome == nil {
                AwayCard(report: report) { session.dismissAwayReport() }
                    .transition(.opacity)
            }

            if let outcome = session.state.outcome {
                OutcomeOverlay(app: app, session: session, outcome: outcome)
            } else if session.playerHouse.isEliminated {
                FallenOverlay(app: app, session: session)
            }
        }
        .background(KeyBridge { key in session.handle(key) })
        .environment(\.worldMotion, motion)
        .environment(\.worldFrameRate, app.displaySettings.frameRate)
        .environment(\.worldQuality, app.displaySettings.quality)
        .onChange(of: motion, initial: true) { _, motion in session.motion = motion }
        .onChange(of: session.panel) { _, panel in
            if panel != nil { panelFocused = true }
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            session.keeperReturned()
        }
        .onDisappear { session.keeperReturned() }
    }
}

extension PlayView {
    /// A panel over the map, as it slides or fades in: a group of its name
    /// to VoiceOver, which its cursor enters as it opens.
    private func opened(_ panel: some View, named name: String) -> some View {
        panel
            .transition(panelTransition)
            .accessibilityElement(children: .contain)
            .accessibilityLabel(name)
            .accessibilityFocused($panelFocused)
    }
}

/// The few keys worth knowing, in the corner.
private struct KeyHints: View {
    var body: some View {
        Text(verbatim: "? Guide · 1–7 panels · Tab next company · ⌘↩ ready")
            .font(.nm(10))
            .foregroundStyle(Palette.text(0.75))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            // As dark as a panel, so it reads over the palest ground.
            .background(Palette.panel, in: RoundedRectangle(cornerRadius: 3))
            // Read as VoiceOver says keys, not as marks to spell.
            .accessibilityLabel("Keys: question mark for the Guide, 1 to 7 for the panels, Tab for the next company, Command-Return when you're ready")
    }
}

/// The steward's advice for the opening, at the foot of the map.
private struct CounselCard: View {
    let session: GameSession

    @AppStorage("counsel.hidden") private var hidden = false

    var body: some View {
        if !hidden, let advice = session.counsel {
            HStack(alignment: .top, spacing: 10) {
                Caps("Counsel", size: 8, weight: .medium)
                    .foregroundStyle(Palette.glowWords)
                    .padding(.top, 2)
                Text(verbatim: advice)
                    .font(.nm(11.5, weight: .light))
                    .foregroundStyle(Palette.text(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .id(advice)
                    .transition(.opacity)
                CloseButton(label: "Hide counsel") { withAnimation(.easeOut(duration: 0.2)) { hidden = true } }
                    .help("Hide counsel")
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 330, alignment: .leading)
            .panelBackground()
            .animation(.easeInOut(duration: 0.4), value: advice)
            .accessibilityElement(children: .contain)
        }
    }
}
