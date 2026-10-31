import LauncherKit
import NullmereCore
import SwiftUI

/// The keepers' words: what was said to the whole realm and within the
/// keeper's alliance, the latest last, and a line to say more to either.
struct WordsPanel: View {
    let session: GameSession
    @State private var draft = ""
    @State private var toAlliance = false

    var body: some View {
        let state = session.state
        let sworn = state.alliance(of: session.player)
        let words = session.wordsHeard
        let alliance = toAlliance && sworn != nil
        let refusal = state.sayRefusal(draft, toAlliance: alliance, as: session.player)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Words", subtitle: sworn.map { "To the realm, or to \($0.name)" } ?? "To every keeper of the realm")
                CloseButton(label: "Close the Words") { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 8) {
                    if words.isEmpty {
                        Text(verbatim: "No keeper has said anything yet. Words said here reach every keeper of the realm, or your alliance alone.")
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(words) { word in
                        // Another's line may be reported to the realm's steward.
                        let reportable = state.reportRefusal(word.id, as: session.player) == nil
                        WordLine(state: state, word: word, player: session.player,
                                 report: reportable ? { session.perform(.reportWord(word: word.id)) } : nil)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .defaultScrollAnchor(.bottom)
            .pagedByKeys(session, as: .panel(.words))
            .onAppear { session.markWordsRead() }
            .onChange(of: words.count) { session.markWordsRead() }
            Rule(opacity: 0.18)
            if sworn != nil {
                Picker("Say it to", selection: $toAlliance) {
                    Text(verbatim: "The realm").tag(false)
                    Text(verbatim: "Your alliance").tag(true)
                }
                .pickerStyle(.segmented)
                .labelsHidden()
                .accessibilityLabel("Say it to")
            }
            HStack {
                TextField(alliance ? "Words for your alliance" : "Words for the realm", text: $draft)
                    .textFieldStyle(.plain)
                    .font(.nm(11.5))
                    .foregroundStyle(Palette.ink)
                    .padding(.vertical, 4)
                    .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                    .onSubmit(say)
                    .accessibilityLabel(alliance ? "Words for your alliance" : "Words for the realm")
                QuietButton(title: "Say", size: 8.5, enabled: refusal == nil, name: alliance ? "Say it to your alliance" : "Say it to the realm",
                            why: draft.isEmpty ? "Write something to say." : refusal?.description, action: say)
            }
            Text(verbatim: "\(Envoy.wordsLimit) letters at most, plain words with no addresses; \(GameState.wordsPerWatch) lines a watch.")
                .font(.nm(9.5))
                .foregroundStyle(Palette.text(0.45))
        }
        .padding(16)
        .frame(width: PanelWidth.rail)
        .frame(maxHeight: 620)
        .panelBackground()
    }

    private func say() {
        if Self.say(draft, toAlliance: toAlliance, in: session) { draft = "" }
    }

    /// Says the words to the realm, or to the keeper's alliance if they are
    /// sworn to one and asked it; whether they were said.
    @discardableResult
    static func say(_ draft: String, toAlliance: Bool, in session: GameSession) -> Bool {
        let alliance = toAlliance && session.state.alliance(of: session.player) != nil
        guard session.state.sayRefusal(draft, toAlliance: alliance, as: session.player) == nil else { return false }
        return session.perform(.say(words: draft, toAlliance: alliance))
    }
}

/// One line said: who said it, when, to whom, and the words; a line taken
/// away by the realm's steward, as taken away; and, for another's line,
/// reporting it to the realm's steward from its menu.
struct WordLine: View {
    let state: GameState
    let word: Word
    let player: Int
    /// Reports it to the realm's steward; nil where it can't be reported.
    var report: (() -> Void)?

    /// The words shown: the line's, or that it was taken away.
    static func shown(_ word: Word) -> String {
        word.removed == true ? GameState.removedWords : word.text
    }

    var body: some View {
        let reported = state.wordReports.contains { $0.word == word.id && $0.by == player }
        let _ = report.map { PressableButtons.note("Report line \(word.id)", enabled: true, $0) }
        VStack(alignment: .leading, spacing: 2) {
            HStack(spacing: 6) {
                Caps(WordLine.speaker(word, in: state, player: player), size: 8.5, weight: .medium)
                    .foregroundStyle(word.from == player ? Palette.glowWords : Palette.text(0.75))
                if word.alliance != nil {
                    Caps("Alliance", size: 8).foregroundStyle(Palette.good)
                }
                Spacer()
                if reported {
                    Caps("Reported", size: 8).foregroundStyle(Palette.text(0.5))
                }
                Text(verbatim: "Watch \(word.watch)").font(.nm(9.5).monospacedDigit()).foregroundStyle(Palette.text(0.45))
            }
            Text(verbatim: WordLine.shown(word))
                .font(.nm(11))
                .italic(word.removed == true)
                .foregroundStyle(Palette.text(word.removed == true ? 0.5 : 0.9))
                .fixedSize(horizontal: false, vertical: true)
                .textSelection(.enabled)
        }
        .contextMenu {
            if let report {
                Button("Report to the realm's steward", action: report)
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityActions {
            if let report {
                Button("Report to the realm's steward", action: report)
            }
        }
    }

    /// Who said it, as the line names them: you, or the keeper's House.
    static func speaker(_ word: Word, in state: GameState, player: Int) -> String {
        guard word.from != player else { return "You" }
        return state.houses.indices.contains(word.from) ? state.houses[word.from].title : "A keeper gone"
    }
}
