import NullmereCore
import SwiftUI

/// The Lyceum, while it sits and the keeper has a question left: one
/// question at a time in the left column, its four answers to choose from,
/// gone once the last is given. Nothing of it shows otherwise.
struct LyceumCard: View {
    let session: GameSession

    /// The next question the keeper's House has not answered, by its index.
    static func next(_ session: GameSession) -> (index: Int, question: LyceumQuestion)? {
        guard let questions = session.state.lyceumNow else { return nil }
        let given = session.state.lyceumAnswers(of: session.player)
        guard let index = given.indices.first(where: { given[$0] == nil }), questions.indices.contains(index) else { return nil }
        return (index, questions[index])
    }

    var body: some View {
        if let (index, question) = Self.next(session) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Caps("The Lyceum", size: 8, weight: .medium)
                        .foregroundStyle(Palette.glowWords)
                    Spacer()
                    Caps("\(index + 1) of \(Lyceum.questions)", size: 8)
                        .foregroundStyle(Palette.text(0.6))
                }
                Text(verbatim: question.text)
                    .font(.nm(11.5, weight: .light))
                    .foregroundStyle(Palette.text(0.9))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(Array(question.choices.enumerated()), id: \.offset) { choice, title in
                    QuietButton(title: title, size: 9, name: "Answer \(title)") {
                        _ = session.perform(.answerLyceum(question: index, choice: choice))
                    }
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: PanelWidth.record, alignment: .leading)
            .panelBackground()
            .accessibilityElement(children: .contain)
            .accessibilityLabel("The Lyceum, question \(index + 1) of \(Lyceum.questions)")
        }
    }
}
