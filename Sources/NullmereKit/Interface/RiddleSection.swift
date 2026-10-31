import NullmereCore
import SwiftUI

/// The Remembering on the Realm screen: the riddle the lake has set the
/// keeper's House, folded to a line until asked for; open, the line of the
/// realm's past it asks of and the four names to choose from; answered,
/// whether it was rightly remembered.
struct RiddleSection: View {
    let session: GameSession
    let riddle: Riddle

    @State private var open: Bool

    /// The section begins folded, or open with its choices.
    init(session: GameSession, riddle: Riddle, open: Bool = false) {
        self.session = session
        self.riddle = riddle
        _open = State(initialValue: open)
    }

    /// How the riddle stands, in a line.
    static func standing(_ riddle: Riddle) -> String {
        guard let answered = riddle.answered else {
            return "Set at watch \(riddle.set): answer it rightly before the next half moon for \(GameState.riddleReward)."
        }
        // The answer is the realm's to tell; until it does, it weighs.
        guard let answer = riddle.answer else { return "You said \(answered); the lake weighs your answer." }
        if riddle.isRight { return "Rightly remembered: it was \(answered)." }
        return "You said \(answered); it was \(answer)."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Caps("The Remembering", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                Spacer()
                if riddle.answered == nil {
                    QuietButton(title: open ? "Fold the riddle" : "Answer…", size: 8.5,
                                name: open ? "Fold the riddle away" : "Answer the riddle the lake has set your House") {
                        open.toggle()
                    }
                }
            }
            Text(verbatim: RiddleSection.standing(riddle))
                .font(.nm(10.5))
                .foregroundStyle(riddle.answered == nil ? Palette.text(0.7) : riddle.isRight ? Palette.good : Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
            if open || riddle.answered != nil {
                // In the Still's voice where this Mac's model gave it one,
                // keeping its blank, and plainly beneath.
                if let spoken = session.spoken[.riddle(riddle.set)], spoken.contains("———") {
                    Text(verbatim: spoken)
                        .font(.nm(11.5, weight: .light).italic())
                        .foregroundStyle(Palette.glowWords)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(verbatim: riddle.line)
                    .font(.nm(11))
                    .foregroundStyle(Palette.text(0.88))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if open, riddle.answered == nil {
                FlowLayout(spacing: 6, lineSpacing: 4) {
                    ForEach(riddle.choices, id: \.self) { name in
                        QuietButton(title: name, size: 8.5, name: "Answer \(name)") {
                            if session.perform(.answerRiddle(name)) { open = false }
                        }
                    }
                }
            }
        }
    }
}
