import AppKit
import NullmereCore
import SwiftUI

/// The world's window: the model gate, the realm's front door, or the lake.
public struct GameRootView: View {
    let app: GameApp

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
        .frame(minWidth: 960, minHeight: 620)
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
            MapVignette()
                .ignoresSafeArea()

            VStack(spacing: 0) {
                TopBar(session: session)
                HStack(alignment: .top, spacing: 0) {
                    VStack(alignment: .leading, spacing: 12) {
                        NoticeFeed(session: session)
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

            if let omen = session.state.currentOmen {
                OmenBand(omen: omen, watch: session.state.watch)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 76)
                    .allowsHitTesting(false)
                    .transition(.opacity)
            }

            if let card = session.watchCard {
                // High in the view, above where the seat is centred.
                WatchCard(summary: card.summary)
                    .id(card.id)
                    .frame(maxHeight: .infinity, alignment: .top)
                    .padding(.top, 130)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            HoverLine(session: session)
                .frame(maxHeight: .infinity, alignment: .bottom)
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
        Text(verbatim: "? guide · Tab next company · ⌘↩ ready")
            .font(.nm(10))
            .foregroundStyle(Palette.ink.opacity(0.4))
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
        if !hidden, let advice = Counsel.advice(for: session.state, player: session.player) {
            HStack(alignment: .top, spacing: 10) {
                Caps("Counsel", size: 8, weight: .medium)
                    .foregroundStyle(Palette.glow)
                    .padding(.top, 2)
                Text(verbatim: advice)
                    .font(.nm(11.5, weight: .light))
                    .foregroundStyle(Palette.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
                    .id(advice)
                    .transition(.opacity)
                CloseButton { withAnimation(.easeOut(duration: 0.2)) { hidden = true } }
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
