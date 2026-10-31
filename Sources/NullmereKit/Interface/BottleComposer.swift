import NullmereCore
import SwiftUI

/// Words sealed in a bottle and set on the water from a hold on the shore,
/// folded on the hold's record until asked for: the words, whether to sign
/// them, and the bottle cast.
struct BottleComposer: View {
    let session: GameSession
    let hold: Hold

    @State private var open = false
    @State private var draft = ""
    @State private var signed = true

    var body: some View {
        let state = session.state
        let refusal = state.castRefusal(draft, from: hold.id, as: session.player)
        VStack(alignment: .leading, spacing: 6) {
            QuietButton(title: open ? "A bottle on the water" : "A bottle…", size: 8.5,
                        name: open ? "Fold the bottle away" : "Set words in a bottle on the water") { open.toggle() }
            if open {
                Text(verbatim: "Sealed and set on the water, the current carries it where it will; whoever finds it washed up reads it. "
                     + "It costs \(GameState.bottleCost), one a watch.")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Words for a stranger", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.nm(11))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 3)
                    .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                    .accessibilityLabel("Words for a stranger")
                HStack(spacing: 6) {
                    Toggle("Sign it", isOn: $signed)
                        .toggleStyle(.checkbox)
                        .font(.nm(10))
                    Spacer()
                    QuietButton(title: "Cast", size: 8.5, enabled: refusal == nil, name: "Set the bottle on the water",
                                why: draft.isEmpty ? "Write something to seal in it." : refusal?.description) {
                        if session.perform(.castBottle(words: draft, from: hold.id, signed: signed)) {
                            draft = ""
                            open = false
                        }
                    }
                }
            }
        }
    }
}
