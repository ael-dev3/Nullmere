import NullmereCore
import SwiftUI

/// A vigil for the House's fallen kept from a hold on the shore, folded on
/// the hold's record until asked for: offered only while the House has
/// companies lost in battle it has not yet kept a vigil for.
struct VigilComposer: View {
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

    /// Whether a hold's record offers a vigil: beside the water, while the
    /// House has fallen to keep one for.
    static func offered(at hold: Hold, in state: GameState, for house: Int) -> Bool {
        state.castingWater(beside: hold) != nil && state.unmourned(by: house) > 0
    }

    var body: some View {
        let state = session.state
        let refusal = state.vigilRefusal(draft, from: hold.id, as: session.player)
        let fallen = GameState.companies(state.unmourned(by: session.player))
        VStack(alignment: .leading, spacing: 6) {
            QuietButton(title: open ? "A vigil for the fallen" : "A vigil for \(fallen) fallen…", size: 8.5,
                        name: open ? "Fold the vigil away" : "Keep a vigil on the water for your House's fallen") { open.toggle() }
            if open {
                Text(verbatim: GameState.vigilSaid)
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Words for your dead", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.nm(11))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 3)
                    .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                    .accessibilityLabel("Words for your dead")
                VigilWordingLine(session: session)
                HStack {
                    Spacer()
                    QuietButton(title: "Set the light", size: 8.5, enabled: refusal == nil, name: "Set the vigil's light on the water",
                                why: draft.isEmpty ? "Write your words for them." : refusal?.description) {
                        if session.perform(.keepVigil(words: draft, hold: hold.id)) {
                            draft = ""
                            open = false
                            session.letVigilWordsBe()
                        }
                    }
                }
            }
        }
        // The model's words, once written, are the keeper's to keep or change.
        .onChange(of: session.vigilWords) { _, written in
            if let written { draft = written.words }
        }
    }
}

/// Words for the House's dead from this Mac's own model, beside the vigil's
/// words: asked for, the model shown at work with its seconds and a Stop;
/// written, in how long; not written, or no model on this Mac, why not.
struct VigilWordingLine: View {
    let session: GameSession

    /// While the model writes: "Apple's on-device model writes words for
    /// your dead… 1.4 s".
    static func atWork(began: Date, now: Date) -> String {
        "Apple's on-device model writes words for your dead… " + String(format: "%.1f s", max(0, now.timeIntervalSince(began)))
    }

    /// Once written: "Written by Apple's on-device model in 2.4 s: keep them
    /// or change them."
    static func written(in seconds: Double) -> String {
        "Written by Apple's on-device model in " + String(format: "%.1f s", seconds) + ": keep them or change them."
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            if session.makesBallads {
                if let began = session.vigilWording {
                    HStack(spacing: 6) {
                        TimelineView(.periodic(from: .now, by: 0.1)) { context in
                            Text(verbatim: Self.atWork(began: began, now: context.date))
                                .font(.nm(10, weight: .light).monospacedDigit())
                                .foregroundStyle(Palette.text(0.5))
                        }
                        Spacer()
                        QuietButton(title: "Stop", size: 8.5, name: "Stop the model writing words for your dead") { session.stopWordingVigil() }
                    }
                } else {
                    QuietButton(title: "Words from your Mac's model", size: 8.5,
                                name: "Ask Apple's on-device model for words for your dead") { session.wordVigil() }
                    if let written = session.vigilWords {
                        note(Self.written(in: written.seconds))
                    } else if let why = session.vigilUnworded {
                        note(why)
                    }
                }
            } else if let why = session.vigilWordsUnwritten {
                note(why)
            }
        }
    }

    private func note(_ text: String) -> some View {
        Text(verbatim: text)
            .font(.nm(10, weight: .light))
            .foregroundStyle(Palette.text(0.5))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// A vigil's light burning on the water, as the water's record tells it:
/// whose it is, its keeper's words, the companies it was lit for, who has
/// honoured it and until when it burns; and, to another keeper, the
/// honouring of it, with what that binds their House to.
struct VigilCard: View {
    let session: GameSession
    let vigil: Vigil

    var body: some View {
        let state = session.state
        let refusal = state.honourRefusal(vigil.id, as: session.player)
        VStack(alignment: .leading, spacing: 6) {
            Caps(state.vigilTitle(vigil, for: session.player), size: 9.5, weight: .medium).foregroundStyle(Palette.glowWords)
            Text(verbatim: state.vigilLine(vigil, for: session.player))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            // Another keeper's, not yet honoured: what honouring binds them to.
            if vigil.house != session.player, !vigil.honouredBy.contains(session.player) {
                Text(verbatim: state.honourSaid(vigil))
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.5))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Spacer()
                    QuietButton(title: "Honour it", size: 8.5, enabled: refusal == nil, name: "Honour this vigil", why: refusal?.description) {
                        session.perform(.honourVigil(vigil.id))
                    }
                }
            }
        }
    }
}
