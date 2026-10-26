import NullmereCore
import SwiftUI

/// The game's window: the model gate, the title screen, or the lake at play.
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
            case .title:
                TitleScreen(app: app)
                    .transition(.opacity)
            case .playing(let session):
                PlayView(app: app, session: session)
                    .id(ObjectIdentifier(session))
                    .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.8), value: phaseKey)
        .preferredColorScheme(.dark)
        .frame(minWidth: 960, minHeight: 620)
        .background(WindowFitter())
    }

    private var phaseKey: Int {
        switch app.phase {
        case .gate: return 0
        case .title: return 1
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
                        CounselCard(session: session)
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
                .animation(.easeOut(duration: 0.3), value: session.state.envoys)
            }

            if let card = session.watchCard {
                WatchCard(summary: card.summary)
                    .id(card.id)
                    .transition(.opacity)
                    .allowsHitTesting(false)
            }

            HoverLine(session: session)
                .frame(maxHeight: .infinity, alignment: .bottom)
                .padding(.bottom, 18)
                .allowsHitTesting(false)

            if let outcome = session.state.outcome {
                OutcomeOverlay(app: app, session: session, outcome: outcome)
            }
        }
        .background(KeyBridge { key in handle(key) })
    }

    private func handle(_ key: GameKey) -> Bool {
        switch key {
        case .nextUnit:
            session.selectNextReadyUnit()
        case .fortify:
            guard let unit = session.selectedUnit, unit.owner == session.player else { return false }
            session.perform(.fortify(unit: unit.id))
        case .found:
            guard let unit = session.selectedUnit, unit.owner == session.player, unit.kind == .founder else { return false }
            session.perform(.found(unit: unit.id))
        case .home:
            session.focusOnSeat()
        case .escape:
            if session.panel != nil {
                session.panel = nil
            } else if session.selection != GameSession.Selection.none {
                session.selection = GameSession.Selection.none
            } else {
                return false
            }
        case .pan(let dx, let dy):
            session.camera.pan(dx: dx, dy: dy)
            session.camera.clamp(toRadius: session.state.map.radius)
        case .zoom(let factor):
            session.camera.zoom(by: factor, around: .zero, in: .zero)
        case .houses:
            session.panel = session.panel == .houses ? nil : .houses
        case .chronicle:
            session.panel = session.panel == .chronicle ? nil : .chronicle
        case .guide:
            session.panel = session.panel == .guide ? nil : .guide
        }
        return true
    }
}

/// The few keys worth knowing, in the corner.
private struct KeyHints: View {
    var body: some View {
        Text(verbatim: "? guide · Tab next company · ⌘↩ end watch")
            .font(.system(size: 10))
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
                    .font(.system(size: 11.5, weight: .light))
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
