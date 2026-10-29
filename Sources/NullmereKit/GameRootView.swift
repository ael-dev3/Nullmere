import AppKit
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
                    Button("Done") { app.showsSettings = false }
                        .keyboardShortcut(.defaultAction)
                }
                .padding([.horizontal, .bottom], 20)
            }
        }
        .preferredColorScheme(.dark)
        .onChange(of: contrast, initial: true) { _, contrast in
            Contrast.shared.isIncreased = contrast == .increased
        }
        .onChange(of: differentiate, initial: true) { _, differentiate in
            Contrast.shared.differentiates = differentiate
        }
        .frame(minWidth: 960, minHeight: 600)
        .background(WindowFitter())
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
                            HousesPanel(session: session).transition(.move(edge: .trailing).combined(with: .opacity))
                        case .chronicle?:
                            ChroniclePanel(session: session).transition(.move(edge: .trailing).combined(with: .opacity))
                        case .guide?:
                            GuidePanel(session: session).transition(.move(edge: .trailing).combined(with: .opacity))
                        case nil:
                            EmptyView()
                        }
                        Spacer(minLength: 0)
                        EnvoyCards(session: session)
                        KeyHints()
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
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            session.keeperReturned()
        }
        .onDisappear { session.keeperReturned() }
    }
}

/// The few keys worth knowing, in the corner.
private struct KeyHints: View {
    var body: some View {
        Text(verbatim: "? Guide · Tab next company · ⌘↩ ready")
            .font(.nm(10))
            .foregroundStyle(Palette.text(0.4))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color.black.opacity(0.35), in: RoundedRectangle(cornerRadius: 3))
            .accessibilityHidden(true)
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
                    .foregroundStyle(Palette.glow)
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
