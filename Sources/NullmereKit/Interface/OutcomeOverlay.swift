import NullmereCore
import SwiftUI

/// The end of a game: who holds the lake now, and how.
struct OutcomeOverlay: View {
    let app: GameApp
    let session: GameSession
    let outcome: Outcome

    @State private var dismissed = false

    var body: some View {
        let state = session.state
        let winner = state.houses[outcome.winner]
        let won = outcome.winner == session.player
        if !dismissed {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    Caps(won ? "The lake is yours" : "The lake is lost", size: 26, weight: .thin, tracking: 0.4)
                        .foregroundStyle(won ? Palette.ink : Palette.bad.opacity(0.9))
                        .accessibilityAddTraits(.isHeader)
                    Rule(opacity: 0.4).frame(width: 280)
                    Text(verbatim: description(winner: winner, won: won))
                        .font(.system(size: 13, weight: .light))
                        .foregroundStyle(Palette.ink.opacity(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        QuietButton(title: "Look upon the lake", size: 10) {
                            withAnimation(.easeOut(duration: 0.3)) { dismissed = true }
                        }
                        QuietButton(title: "A new world", size: 10, prominent: true) { app.abandonFinishedGame() }
                    }
                    .padding(.top, 6)
                }
                .padding(36)
                .panelBackground()
            }
            .transition(.opacity)
        }
    }

    private func description(winner: House, won: Bool) -> String {
        let span = "after \(outcome.watch) watches"
        switch (outcome.kind, won) {
        case (.ascendancy, true):
            return "Your Moonspire stands complete \(span). Its light lies on the still water, and every House around the lake bends to it."
        case (.ascendancy, false):
            return "The Moonspire of \(winner.title) stands complete \(span). The lake will remember them, and not you."
        case (.dominion, true):
            return "Your realm holds \(session.state.realm(of: winner.id)) of the \(session.state.holds.count) holds around the lake \(span). Every shore of the Nullmere answers to \(winner.title)."
        case (.dominion, false):
            if session.playerHouse.isEliminated {
                return "Your last hold has fallen \(span). \(winner.title) is the greatest House left on the shore, and the water closes over your name."
            }
            return "\(winner.title) rules \(session.state.realm(of: winner.id)) of the \(session.state.holds.count) holds around the lake \(span), and the shores answer to it, not to you."
        }
    }
}
