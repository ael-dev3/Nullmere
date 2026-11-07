import NullmereCore
import NullmereCounsel
import SwiftUI

/// Counsel with one of the keeper's commanders, spoken by Apple's on-device
/// model on this Mac: the conversation as it goes, each answer appearing as
/// it is spoken; the looks the commander takes as they answer; the orders
/// they put forward, which the keeper gives or sets aside; and, plainly, why
/// no counsel comes when none can. Nothing here is ever answered for the
/// model: a commander who can't speak says nothing at all.
struct CounselSheet: View {
    let session: GameSession
    @ObservedObject var counsel: CommanderCounselSession
    @State private var words = ""
    @FocusState private var typing: Bool

    var body: some View {
        let commander = counsel.counsel.commander
        let unavailable = counsel.unavailable
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .center, spacing: 10) {
                Portrait(key: .commander(variant: Archetype.allCases.firstIndex(of: commander.archetype) ?? 0),
                         colour: Portrait.colour(of: commander.owner, in: session.state), size: 44)
                PanelTitle(title: commander.name, subtitle: "\(commander.archetype.title) · level \(commander.level) · \(leads)")
                Spacer()
                CloseButton(label: "End counsel with \(commander.name)") { session.closeCounsel() }
            }
            if let unavailable {
                Text(verbatim: unavailable.said)
                    .font(.nm(11))
                    .foregroundStyle(Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("Counsel unavailable: \(unavailable.said)")
            }
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 9) {
                        if counsel.lines.isEmpty && unavailable == nil {
                            Text(verbatim: "Ask \(commander.name) what they see, what they would do, or how the House stands.")
                                .font(.nm(10.5))
                                .foregroundStyle(Palette.text(0.5))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        ForEach(counsel.lines) { line in
                            CounselLineView(line: line, commander: commander.name)
                                .id(line.id)
                        }
                        if let partial = counsel.partial {
                            CounselLineView(line: .init(id: -1, kind: .commander, text: partial.isEmpty ? "…" : partial), commander: commander.name)
                                .id(-1)
                        }
                        ForEach(counsel.offers) { offer in
                            OfferCard(offer: offer, give: { session.give(offer) }, setAside: { counsel.setAside(offer) })
                        }
                    }
                    .padding(.vertical, 4)
                }
                .onChange(of: counsel.lines.count) {
                    if let last = counsel.lines.last { proxy.scrollTo(last.id, anchor: .bottom) }
                }
                .onChange(of: counsel.partial) {
                    if counsel.partial != nil { proxy.scrollTo(-1, anchor: .bottom) }
                }
            }
            HStack(spacing: 8) {
                TextField("Ask \(commander.name)…", text: $words)
                    .textFieldStyle(.plain)
                    .font(.nm(11.5))
                    .foregroundStyle(Palette.ink)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(RoundedRectangle(cornerRadius: 6).fill(Palette.line(0.08)))
                    .focused($typing)
                    .disabled(unavailable != nil)
                    .onSubmit(ask)
                    .accessibilityLabel("Your words to \(commander.name)")
                if counsel.answering {
                    QuietButton(title: "Stop", size: 9.5, name: "Stop \(commander.name)'s answer") { counsel.stop() }
                } else {
                    QuietButton(title: "Ask", size: 9.5, prominent: true,
                                enabled: unavailable == nil && !words.trimmingCharacters(in: .whitespaces).isEmpty,
                                name: "Ask \(commander.name)", why: unavailable?.said, action: ask)
                }
            }
            Text(verbatim: footer)
                .font(.nm(9.5).monospacedDigit())
                .foregroundStyle(Palette.text(0.45))
        }
        .padding(18)
        .frame(width: 480, height: 580)
        .background(Palette.panel)
        .onAppear { typing = unavailable == nil }
    }

    private var leads: String {
        counsel.counsel.company.map { "leads the \(SpokenOrders.named($0, in: counsel.counsel.state))" } ?? "leads no company"
    }

    /// Who answers, and how long they took: Apple's on-device model, here.
    private var footer: String {
        var said = "Spoken by Apple's on-device model on this Mac"
        if let timing = counsel.timing {
            said += String(format: " · first words %.1f s, all of it %.1f s", timing.firstWords, timing.whole)
        }
        return said
    }

    private func ask() {
        let asked = words
        guard !asked.trimmingCharacters(in: .whitespaces).isEmpty, !counsel.answering else { return }
        words = ""
        counsel.ask(asked)
    }
}

/// A line of counsel: the keeper's words, the commander's, a look they took,
/// or why no answer came.
struct CounselLineView: View {
    let line: CommanderCounselSession.Line
    let commander: String

    var body: some View {
        switch line.kind {
        case .keeper:
            HStack {
                Spacer(minLength: 40)
                Text(verbatim: line.text)
                    .font(.nm(11))
                    .foregroundStyle(Palette.text(0.75))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(RoundedRectangle(cornerRadius: 7).fill(Palette.line(0.1)))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You: \(line.text)")
        case .commander:
            Text(verbatim: line.text)
                .font(.nm(11.5))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 30)
                .accessibilityLabel("\(commander): \(line.text)")
        case .look:
            Text(verbatim: line.text)
                .font(.nm(9.5).italic())
                .foregroundStyle(Palette.text(0.45))
                .fixedSize(horizontal: false, vertical: true)
        case .trouble:
            Text(verbatim: line.text)
                .font(.nm(10.5))
                .foregroundStyle(Palette.bad)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// An order the commander put forward: given by the keeper, or set aside.
struct OfferCard: View {
    let offer: CommanderCounselSession.Offer
    let give: () -> Void
    let setAside: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Caps("Put forward", size: 8.5).foregroundStyle(Palette.text(0.5))
            Text(verbatim: offer.proposal.told)
                .font(.nm(11))
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            switch offer.state {
            case .waiting:
                HStack(spacing: 8) {
                    QuietButton(title: "Give the order", size: 9, prominent: true, name: "Give the order: \(offer.proposal.told)", action: give)
                    QuietButton(title: "Set aside", size: 9, name: "Set aside: \(offer.proposal.told)", action: setAside)
                }
            case .given:
                Text(verbatim: "Given. The realm's word follows.")
                    .font(.nm(10))
                    .foregroundStyle(Palette.good)
            case .setAside:
                Text(verbatim: "Set aside.")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.5))
            }
        }
        .padding(10)
        .background(RoundedRectangle(cornerRadius: 8).stroke(Palette.line(0.18)))
        .accessibilityElement(children: .contain)
    }
}
