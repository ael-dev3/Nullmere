import NullmereCore
import SwiftUI

/// A letter to the age to come, sealed under a hold's stones, folded on the
/// hold's record until asked for: the words, and the letter sealed. Once a
/// House has sealed its letter, the hold that keeps it says so and the
/// others offer none, one an age.
struct LetterComposer: View {
    let session: GameSession
    let hold: Hold

    @State private var open: Bool
    @State private var draft: String

    /// `open` and `draft` begin the composer: folded and empty on a hold's
    /// record, or open with words already written where they are given.
    init(session: GameSession, hold: Hold, open: Bool = false, draft: String = "") {
        self.session = session
        self.hold = hold
        _open = State(initialValue: open)
        _draft = State(initialValue: draft)
    }

    /// What the hold that keeps the House's letter says of it.
    static func kept(_ letter: Letter) -> String {
        "Your letter to the age to come lies under these stones: “\(letter.words)”"
    }

    var body: some View {
        let state = session.state
        if let sealed = state.letter(sealedBy: session.player) {
            if sealed.holdID == hold.id {
                Text(verbatim: Self.kept(sealed))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.glowWords)
                    .fixedSize(horizontal: false, vertical: true)
            }
        } else {
            let refusal = state.sealRefusal(draft, in: hold.id, as: session.player)
            VStack(alignment: .leading, spacing: 6) {
                QuietButton(title: open ? "A letter to the age to come" : "A letter to the age to come…", size: 8.5,
                            name: open ? "Fold the letter away" : "Write a letter to the age to come") { open.toggle() }
                if open {
                    Text(verbatim: "Sealed under these stones, it goes down with them when the age drowns; whoever searches "
                         + "their ruin in the age after finds it, and every House reads it. It costs \(GameState.letterCost), one an age.")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                    TextField("Words for the age to come", text: $draft)
                        .textFieldStyle(.plain)
                        .font(.nm(11))
                        .foregroundStyle(Palette.ink)
                        .padding(.vertical, 3)
                        .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                        .accessibilityLabel("Words for the age to come")
                    HStack {
                        Spacer()
                        QuietButton(title: "Seal", size: 8.5, enabled: refusal == nil, name: "Seal the letter under these stones",
                                    why: draft.isEmpty ? "Write something to seal." : refusal?.description) {
                            if session.perform(.sealLetter(words: draft, hold: hold.id)) {
                                draft = ""
                                open = false
                            }
                        }
                    }
                }
            }
        }
    }
}
