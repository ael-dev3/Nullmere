import NullmereCore
import SwiftUI

/// The first time in an age: the House the keeper takes up, and what to do
/// first.
struct SeatBriefingCard: View {
    let briefing: SeatBriefing
    let colour: Color
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
                            .font(.nm(11, weight: .medium).monospacedDigit())
                            .foregroundStyle(Palette.glowWords)
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
