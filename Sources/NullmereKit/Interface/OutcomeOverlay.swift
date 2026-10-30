import NullmereCore
import SwiftUI

/// The end of an age: who holds the lake now, and how.
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
                    Caps(won ? "The lake is yours" : "The lake is lost", size: 26, weight: .thin, tracking: 0.4, centred: true)
                        .foregroundStyle(won ? Palette.ink : Palette.bad)
                        .accessibilityAddTraits(.isHeader)
                    Rule(opacity: 0.4).frame(width: 280)
                    Text(verbatim: description(winner: winner, won: won))
                        .font(.nm(13, weight: .light))
                        .foregroundStyle(Palette.text(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                    TimelineView(.periodic(from: .now, by: 1)) { context in
                        Text(verbatim: OutcomeOverlay.nextAge(secondsLeft: session.secondsLeft(at: context.date)))
                            .font(.nm(11).monospacedDigit())
                            .foregroundStyle(Palette.text(0.55))
                            .multilineTextAlignment(.center)
                    }
                    VStack(alignment: .leading, spacing: 8) {
                        Caps("Holds around the lake, watch by watch", size: 8, weight: .medium)
                            .foregroundStyle(Palette.text(0.55))
                        StoryChart(state: state, player: session.player)
                        Text(verbatim: StoryChart.standing(of: state, player: session.player))
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                        Text(verbatim: StoryChart.summary(of: state, player: session.player))
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.6))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(width: 440)
                    .padding(.top, 4)
                    HStack(spacing: 8) {
                        QuietButton(title: "Look upon the lake", size: 10) {
                            withAnimation(.easeOut(duration: 0.3)) { dismissed = true }
                        }
                        .keyboardShortcut(.cancelAction)
                        QuietButton(title: "Leave the world", size: 10, prominent: true) { app.leaveWorld() }
                    }
                    .padding(.top, 6)
                }
                .padding(36)
                .panelBackground()
                .accessibilityAddTraits(.isModal)
            }
            .transition(.opacity)
        }
    }

    /// When the next age begins, as the realm's clock says.
    static func nextAge(secondsLeft: Int?) -> String {
        guard let left = secondsLeft, left < 3_600 else {
            return "A new age begins on a fresh lake when the watch turns, and keepers are seated anew in the order they first came, as seats allow."
        }
        return "A new age begins on a fresh lake in \(left / 60):\(String(format: "%02d", left % 60)), and keepers are seated anew in the order they first came, as seats allow."
    }

    private func description(winner: House, won: Bool) -> String {
        let span = "after \(outcome.watch) watches"
        switch (outcome.kind, won) {
        case (.ascendancy, true):
            return "Your Moonspire stands complete \(span). Its light lies on the still water, and every House around the lake bends to it."
        case (.ascendancy, false):
            return "The Moonspire of \(winner.title) stands complete \(span). The lake will remember them, and not you."
        case (.dominion, true):
            return "You hold \(session.state.realm(of: winner.id)) of the \(session.state.holds.count) holds around the lake \(span), your vassals' counted. Every shore of \(session.state.settings.lake.title) answers to \(winner.title)."
        case (.dominion, false):
            if session.playerHouse.isEliminated {
                return "Your last hold has fallen \(span). \(winner.title) is the greatest House left on the shore, and the water closes over your name."
            }
            return "\(winner.title) rules \(session.state.realm(of: winner.id)) of the \(session.state.holds.count) holds around the lake \(span), and the shores answer to it, not to you."
        }
    }
}

/// A keeper's House fallen while the age goes on for the others: they may
/// look on until it ends, and are seated again when the next begins.
struct FallenOverlay: View {
    let app: GameApp
    let session: GameSession

    @State private var dismissed = false

    var body: some View {
        if !dismissed {
            ZStack {
                Color.black.opacity(0.6).ignoresSafeArea()
                VStack(spacing: 16) {
                    Caps("Your House has fallen", size: 26, weight: .thin, tracking: 0.4, centred: true)
                        .foregroundStyle(Palette.bad)
                        .accessibilityAddTraits(.isHeader)
                    Rule(opacity: 0.4).frame(width: 280)
                    Text(verbatim: FallenOverlay.words(for: session.playerHouse, watch: session.state.watch,
                                                       freeHouse: session.mayTakeUpAFreeHouse))
                        .font(.nm(13, weight: .light))
                        .foregroundStyle(Palette.text(0.75))
                        .multilineTextAlignment(.center)
                        .frame(maxWidth: 440)
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 8) {
                        QuietButton(title: "Look upon the lake", size: 10) {
                            withAnimation(.easeOut(duration: 0.3)) { dismissed = true }
                        }
                        .keyboardShortcut(.cancelAction)
                        QuietButton(title: "Leave the world", size: 10) { app.leaveWorld() }
                        if session.mayTakeUpAFreeHouse {
                            QuietButton(title: "Take up an open seat", size: 10, prominent: true) { session.takeUpAFreeHouse() }
                        }
                    }
                    .padding(.top, 6)
                }
                .padding(36)
                .panelBackground()
                .accessibilityAddTraits(.isModal)
            }
            .transition(.opacity)
        } else if session.mayTakeUpAFreeHouse {
            // Looking on, the way back into play stays in reach.
            HStack(spacing: 10) {
                Text(verbatim: "A seat stands open.")
                    .font(.nm(11))
                    .foregroundStyle(Palette.text(0.75))
                QuietButton(title: "Take up an open seat", size: 9.5, prominent: true) { session.takeUpAFreeHouse() }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .panelBackground()
            .frame(maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 56)
            .transition(.opacity)
        }
    }

    static func words(for house: House, watch: Int, freeHouse: Bool = false) -> String {
        let lost = "The last hold of \(house.title) is lost at watch \(watch). "
        if freeHouse {
            return lost + "A seat still stands open: take it up and play on, or look on until the age ends."
        }
        return lost + "The age goes on for the Houses still standing; when it ends, a new one begins on a fresh lake and you are seated again."
    }
}
