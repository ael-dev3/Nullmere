import NullmereCore
import SwiftUI

/// The first time in an age: the House the keeper takes up, and what to do
/// first.
struct SeatBriefingCard: View {
    let briefing: SeatBriefing
    let colour: Color
    /// The session whose steward welcomes the keeper, in their own words
    /// where this Mac's model gave them; none, the card's facts alone.
    var session: GameSession? = nil
    let begin: () -> Void

    /// VoiceOver goes to the card as it appears, its title first.
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1).fill(colour).frame(width: 3, height: 16)
                Caps(briefing.title, size: 12, weight: .medium, tracking: 0.3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focused)
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Rule(opacity: 0.3)
            // The steward who kept the House, welcoming its keeper in their
            // own voice: this Mac's model at work, or why it gave none.
            if let session {
                let welcome = GameSession.Spoken.steward(briefing.watch)
                VoicingLine(session: session, key: welcome, who: "the steward")
                if let words = session.spoken[welcome] {
                    Text(verbatim: "\"\(words)\"")
                        .font(.nm(12.5, weight: .light).italic())
                        .foregroundStyle(Palette.text(0.9))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                        .accessibilityLabel("The steward says: \(words)")
                }
            }
            VStack(alignment: .leading, spacing: 5) {
                ForEach(Array(briefing.facts.enumerated()), id: \.offset) { _, fact in
                    Text(verbatim: fact)
                        .font(.nm(12, weight: .light))
                        .foregroundStyle(Palette.text(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Caps("First", size: 8.5, weight: .medium).foregroundStyle(Palette.text(0.55))
                .padding(.top, 4)
            VStack(alignment: .leading, spacing: 6) {
                ForEach(Array(briefing.steps.enumerated()), id: \.offset) { index, step in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: "\(index + 1)")
                            .font(.nm(12, weight: .semibold).monospacedDigit())
                            .foregroundStyle(Palette.ink)
                        Text(verbatim: step)
                            .font(.nm(12, weight: .light))
                            .foregroundStyle(Palette.text(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }
            }
            HStack {
                Text(verbatim: "The Guide (?) holds the rest.")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.45))
                Spacer()
                QuietButton(title: "Begin", size: 10.5, prominent: true, action: begin)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 460)
        .panelBackground()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear { focused = true }
    }
}
