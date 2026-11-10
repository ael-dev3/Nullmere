import NullmereCore
import NullmereCounsel
import SwiftUI

/// A parley with an envoy waiting on the keeper, spoken by Apple's on-device
/// model on this Mac: who sent it and what it carries; the conversation as it
/// goes, each answer appearing as it is spoken; the answers the envoy puts to
/// the keeper, which the keeper gives or sets aside, the realm deciding each;
/// and, plainly, why no parley comes when none can. Nothing here is ever
/// answered for the model: an envoy the model can't speak for says nothing.
struct ParleySheet: View {
    let session: GameSession
    @ObservedObject var parley: EnvoyParleySession
    @State private var words = ""
    @FocusState private var typing: Bool

    var body: some View {
        let grounded = parley.parley
        let speaker = grounded.speaker
        let unavailable = parley.unavailable
        let canSpeak = unavailable == nil && !parley.gone
        // Where the model can't speak and nothing has been said, there is no
        // conversation to show: the sheet keeps to what it tells.
        let quiet = unavailable != nil && parley.lines.isEmpty && parley.partial == nil && parley.offers.isEmpty
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                // The House the envoy comes from, its seat painted in its people's way and colours.
                Portrait(key: .keepOf(grounded.state.heritage(of: grounded.envoy.from), seat: true),
                         colour: Portrait.colour(of: grounded.envoy.from, in: grounded.state), size: 44)
                PanelTitle(title: speaker, subtitle: "\(grounded.envoy.proposal.title) · \(grounded.house.temperament.title.lowercased())")
                Spacer()
                CloseButton(label: "End the parley with the envoy of \(grounded.house.title)") { session.closeParley() }
            }
            // What it carries, as its card tells it.
            Text(verbatim: grounded.state.terms(of: grounded.envoy, for: grounded.player))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            if let unavailable {
                Text(verbatim: unavailable.said)
                    .font(.nm(11))
                    .foregroundStyle(Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Parley unavailable: \(unavailable.said)")
            }
            if !quiet {
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 9) {
                            if parley.lines.isEmpty && canSpeak {
                                Text(verbatim: grounded.opening)
                                    .font(.nm(10.5))
                                    .foregroundStyle(Palette.text(0.5))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(parley.lines) { line in
                                CounselLineView(line: line, commander: speaker)
                                    .id(line.id)
                            }
                            if let partial = parley.partial {
                                CounselLineView(line: .init(id: -1, kind: .commander, text: partial.isEmpty ? "…" : partial), commander: speaker)
                                    .id(-1)
                            }
                            ForEach(parley.offers) { offer in
                                OfferCard(offer: offer, give: { session.giveAnswer(offer) }, setAside: { parley.setAside(offer) },
                                          giving: "Give the answer")
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: parley.lines.count) {
                        if let last = parley.lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                    }
                    .onChange(of: parley.partial) {
                        if parley.partial != nil { proxy.scrollTo(-1, anchor: .bottom) }
                    }
                }
            }
            HStack(spacing: 8) {
                TextField("Speak to the envoy…", text: $words)
                    .textFieldStyle(.plain)
                    .font(.nm(11.5))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Palette.line(0.08)))
                    .focused($typing)
                    .disabled(!canSpeak)
                    .onSubmit(speak)
                    .accessibilityLabel("Your words to the envoy of \(grounded.house.title)")
                if parley.answering {
                    QuietButton(title: "Stop", size: 9.5, name: "Stop the envoy's answer") { parley.stop() }
                } else {
                    QuietButton(title: "Speak", size: 9.5, prominent: true,
                                enabled: canSpeak && !words.trimmingCharacters(in: .whitespaces).isEmpty,
                                name: "Speak to the envoy of \(grounded.house.title)",
                                why: unavailable?.said ?? (parley.gone ? "\(speaker) has gone." : nil), action: speak)
                }
            }
            Text(verbatim: EnvoyParley.foot(on: "Mac", canAsk: unavailable == nil, firstWords: parley.timing?.firstWords,
                                            whole: parley.timing?.whole))
                .font(.nm(9.5).monospacedDigit())
                .foregroundStyle(Palette.text(0.45))
        }
        .padding(18)
        .frame(width: 480, height: quiet ? nil : 540)
        .background(Palette.panel)
        .onAppear { typing = canSpeak }
    }

    private func speak() {
        let said = words
        guard !said.trimmingCharacters(in: .whitespaces).isEmpty, !parley.answering, !parley.gone else { return }
        words = ""
        parley.ask(said)
    }
}
