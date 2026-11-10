import NullmereCore
import SwiftUI

/// On returning: what happened to the keeper's House while they were away.
struct AwayCard: View {
    let report: AwayReport
    /// The session whose caretaker greets the keeper in its own words,
    /// where this Mac's model gives them; none, the report alone.
    var session: GameSession? = nil
    let dismiss: () -> Void

    /// VoiceOver goes to the card as it appears, its title first.
    @AccessibilityFocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Caps(report.title, size: 11, weight: .medium, tracking: 0.3)
                    .accessibilityAddTraits(.isHeader)
                    .accessibilityFocused($focused)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Rule(opacity: 0.3)
            // The caretaker's word, in their own voice.
            if let session {
                let word = GameSession.Spoken.caretaker(report.watch)
                VoicingLine(session: session, key: word, who: "the caretaker")
                if let spoken = session.spoken[word] {
                    Text(verbatim: "\"\(spoken)\"")
                        .font(.nm(12, weight: .light).italic())
                        .foregroundStyle(Palette.text(0.88))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                }
            }
            if !report.changes.isEmpty || report.holdsLine != nil {
                HStack(spacing: 14) {
                    ForEach(report.changes, id: \.self) { change in
                        HStack(spacing: 4) {
                            ResourceGlyph(resource: change.resource)
                            Text(verbatim: change.delta > 0 ? "+\(change.delta)" : "−\(-change.delta)")
                                .font(.nm(12).monospacedDigit())
                                .foregroundStyle(change.delta > 0 ? Palette.good : Palette.bad)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(change.resource.title) \(change.delta > 0 ? "up" : "down") \(abs(change.delta))")
                        .accessibilityAddTraits(.isStaticText)
                    }
                    if let holds = report.holdsLine {
                        Text(verbatim: holds)
                            .font(.nm(11))
                            .foregroundStyle(report.holdsChange > 0 ? Palette.good : Palette.bad)
                    }
                }
            }
            if let standing = report.standing {
                Text(verbatim: standing)
                    .font(.nm(11))
                    .foregroundStyle(Palette.text(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if report.news.isEmpty {
                Text(verbatim: "Your House stood quiet; nothing touched it.")
                    .font(.nm(12, weight: .light))
                    .foregroundStyle(Palette.text(0.75))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(report.news.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(Palette.line(0.4)).frame(width: 3, height: 3)
                            Text(verbatim: line)
                                .font(.nm(12, weight: .light))
                                .foregroundStyle(Palette.text(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    if let more = report.moreLine {
                        Text(verbatim: more)
                            .font(.nm(11))
                            .foregroundStyle(Palette.text(0.7))
                    }
                }
            }
            HStack {
                Spacer()
                QuietButton(title: "Back to it", size: 10.5, prominent: true, action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440)
        .panelBackground()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
        .onAppear { focused = true }
    }
}
