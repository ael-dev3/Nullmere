import NullmereCompanionCore
import NullmereCore
import NullmereCounsel
import SwiftUI

/// Counsel with one of the keeper's commanders from the phone, spoken by
/// Apple's on-device model on this iPhone, as it is on the keeper's Mac:
/// the conversation as it goes, each answer appearing as it is spoken; the
/// looks the commander takes as they answer; the orders they put forward,
/// which the keeper gives or sets aside, the realm deciding each; and,
/// plainly, why no counsel comes when none can. Nothing here is ever
/// answered for the model: a commander who can't speak says nothing.
struct CounselView: View {
    let session: CompanionSession
    @ObservedObject var counsel: CommanderCounselSession
    let close: () -> Void
    @State private var words = ""

    var body: some View {
        let commander = counsel.counsel.commander
        let unavailable = counsel.unavailable
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                Text(verbatim: "\(commander.archetype.title) · level \(commander.level) · \(leads)")
                    .font(Night.small)
                    .foregroundStyle(Night.moon)
                // The battles they led that they remember, as the Mac says it.
                if let remembers = counsel.counsel.remembersSaid {
                    Text(verbatim: remembers)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let unavailable {
                    Text(verbatim: unavailable.said)
                        .font(Night.body)
                        .foregroundStyle(Night.bad)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Counsel unavailable: \(unavailable.said)")
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if counsel.lines.isEmpty && unavailable == nil {
                                Text(verbatim: "Ask \(commander.name) what they see, what they would do, or how the House stands.")
                                    .font(Night.small)
                                    .foregroundStyle(Night.ink.opacity(0.55))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(counsel.lines) { line in
                                CounselLine(line: line, commander: commander.name)
                                    .id(line.id)
                            }
                            if let partial = counsel.partial {
                                CounselLine(line: .init(id: -1, kind: .commander, text: partial.isEmpty ? "…" : partial), commander: commander.name)
                                    .id(-1)
                            }
                            ForEach(counsel.offers) { offer in
                                OfferCard(offer: offer, give: { give(offer) }, setAside: { counsel.setAside(offer) })
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: counsel.lines.count) {
                        if let last = counsel.lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onChange(of: counsel.partial) {
                        if counsel.partial != nil { proxy.scrollTo(-1, anchor: .bottom) }
                    }
                }
                WordLine(session: session)
                HStack(spacing: 10) {
                    TextField("Ask \(commander.name)…", text: $words)
                        .font(Night.body)
                        .submitLabel(.send)
                        .disabled(unavailable != nil)
                        .onSubmit(ask)
                        .accessibilityLabel("Your words to \(commander.name)")
                    if counsel.answering {
                        Button("Stop") { counsel.stop() }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Stop \(commander.name)'s answer")
                    } else {
                        Button("Ask", action: ask)
                            .buttonStyle(.borderedProminent)
                            .disabled(unavailable != nil || words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Ask \(commander.name)")
                    }
                }
                Text(verbatim: footer(canAsk: unavailable == nil))
                    .font(Night.small.monospacedDigit())
                    .foregroundStyle(Night.ink.opacity(0.45))
            }
            .padding()
            .background(Night.background)
            .navigationTitle(commander.name)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: close)
                        .accessibilityLabel("End counsel with \(commander.name)")
                }
            }
        }
        .tint(Night.moon)
        // The commander's looks tell the realm as it now stands.
        .onChange(of: session.ledger) {
            if let fresh = session.counsel(of: counsel.id) { counsel.renew(fresh.counsel) }
        }
        .onDisappear { counsel.stop() }
        .onAppear {
            #if DEBUG
            // The smoke test's question, asked as the keeper would ask it.
            if CompanionCheck.counselAsked, counsel.lines.isEmpty, counsel.unavailable == nil {
                words = CompanionCheck.counselQuestion
                ask()
            }
            #endif
        }
    }

    private var leads: String {
        counsel.counsel.company.map { "leads the \(SpokenOrders.named($0, in: counsel.counsel.state))" } ?? "leads no company"
    }

    /// Who answers, and how long they took: Apple's on-device model, here,
    /// or, where it can't be asked, nothing in its place.
    private func footer(canAsk: Bool) -> String {
        CommanderCounsel.foot(on: "iPhone", canAsk: canAsk, firstWords: counsel.timing?.firstWords, whole: counsel.timing?.whole)
    }

    private func ask() {
        let asked = words
        guard !asked.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !counsel.answering else { return }
        words = ""
        counsel.ask(asked)
    }

    /// An order the commander put forward, given as any order the phone
    /// gives: refused here if the rules wouldn't take it, else sent, the
    /// realm's word to follow.
    private func give(_ offer: CommanderCounselSession.Offer) {
        guard let command = counsel.give(offer) else { return }
        session.give(command, told: offer.proposal.told.prefix(1).uppercased() + offer.proposal.told.dropFirst())
    }
}

/// A parley with an envoy waiting on the keeper or a commander the keeper's
/// House holds prisoner, from the phone, spoken by Apple's on-device model
/// on this iPhone, as it is on the keeper's Mac: what the envoy carries, or
/// how long the prisoner is held and what they last told; the conversation
/// as it goes, each answer appearing as it is spoken; what is put to the
/// keeper, which the keeper gives or sets aside, the realm deciding each;
/// and, plainly, why no parley comes when none can. Nothing here is ever
/// answered for the model: one the model can't speak for says nothing.
struct ParleyView: View {
    let session: CompanionSession
    @ObservedObject var parley: ParleySession
    let close: () -> Void
    @State private var words = ""

    var body: some View {
        let grounded = parley.parley
        let unavailable = parley.unavailable
        let canSpeak = unavailable == nil && !parley.gone
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                // What the envoy carries, or how long the prisoner is held
                // and what they last told, as their row tells it.
                Text(verbatim: grounded.summary)
                    .font(Night.small)
                    .foregroundStyle(Night.moon)
                    .fixedSize(horizontal: false, vertical: true)
                if let unavailable {
                    Text(verbatim: unavailable.said)
                        .font(Night.body)
                        .foregroundStyle(Night.bad)
                        .fixedSize(horizontal: false, vertical: true)
                        .accessibilityLabel("Parley unavailable: \(unavailable.said)")
                }
                ScrollViewReader { proxy in
                    ScrollView {
                        LazyVStack(alignment: .leading, spacing: 10) {
                            if parley.lines.isEmpty && canSpeak {
                                Text(verbatim: grounded.opening)
                                    .font(Night.small)
                                    .foregroundStyle(Night.ink.opacity(0.55))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            ForEach(parley.lines) { line in
                                CounselLine(line: line, commander: grounded.speaker)
                                    .id(line.id)
                            }
                            if let partial = parley.partial {
                                CounselLine(line: .init(id: -1, kind: .commander, text: partial.isEmpty ? "…" : partial), commander: grounded.speaker)
                                    .id(-1)
                            }
                            ForEach(parley.offers) { offer in
                                OfferCard(offer: offer, give: { give(offer) }, setAside: { parley.setAside(offer) }, giving: parley.subject.giving)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                    .onChange(of: parley.lines.count) {
                        if let last = parley.lines.last { withAnimation { proxy.scrollTo(last.id, anchor: .bottom) } }
                    }
                    .onChange(of: parley.partial) {
                        if parley.partial != nil { proxy.scrollTo(-1, anchor: .bottom) }
                    }
                }
                WordLine(session: session)
                HStack(spacing: 10) {
                    TextField("Speak to \(grounded.addressed)…", text: $words)
                        .font(Night.body)
                        .submitLabel(.send)
                        .disabled(!canSpeak)
                        .onSubmit(speak)
                        .accessibilityLabel("Your words to \(grounded.named)")
                    if parley.answering {
                        Button("Stop") { parley.stop() }
                            .buttonStyle(.bordered)
                            .accessibilityLabel("Stop \(grounded.addressed)'s answer")
                    } else {
                        Button("Speak", action: speak)
                            .buttonStyle(.borderedProminent)
                            .disabled(!canSpeak || words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            .accessibilityLabel("Speak to \(grounded.named)")
                    }
                }
                Text(verbatim: Parleys.foot(on: "iPhone", canAsk: unavailable == nil, for: grounded.spokenFor,
                                            firstWords: parley.timing?.firstWords, whole: parley.timing?.whole))
                    .font(Night.small.monospacedDigit())
                    .foregroundStyle(Night.ink.opacity(0.45))
            }
            .padding()
            .background(Night.background)
            .navigationTitle(grounded.speaker)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done", action: close)
                        .accessibilityLabel("End the parley with \(grounded.named)")
                }
            }
        }
        .tint(Night.moon)
        // The one parleyed with told what changed as the realm moves on, or
        // the parley ended with them gone: as the realm tells each world,
        // never on the phone's guess at an answer given here; nothing
        // renewed while the phone keeps no House.
        .onChange(of: session.heard) {
            if session.phase == .keeping { parley.renew(session.parley(with: parley.subject)) }
        }
        .onDisappear { parley.stop() }
    }

    private func speak() {
        let said = words
        guard !said.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty, !parley.answering, !parley.gone else { return }
        words = ""
        parley.ask(said)
    }

    /// What was put to the keeper, given as any order the phone gives:
    /// refused here if the rules wouldn't take it, else sent, the realm's
    /// word to follow.
    private func give(_ offer: ParleySession.Offer) {
        guard let command = parley.give(offer) else { return }
        session.give(command, told: offer.proposal.told.prefix(1).uppercased() + offer.proposal.told.dropFirst())
    }
}

/// A parley opened from an envoy's or a prisoner's row: the session, known
/// by whom it is with.
struct Parleying: Identifiable {
    let id: ParleySubject
    let parley: ParleySession
}

/// Counsel opened from the Army tab: the session, known by its commander.
struct Counselling: Identifiable {
    let id: Int
    let counsel: CommanderCounselSession
}

/// A line of counsel: the keeper's words, the commander's, a look they took,
/// or why no answer came.
private struct CounselLine: View {
    let line: CommanderCounselSession.Line
    let commander: String

    var body: some View {
        switch line.kind {
        case .keeper:
            HStack {
                Spacer(minLength: 40)
                Text(verbatim: line.text)
                    .font(Night.body)
                    .foregroundStyle(Night.ink.opacity(0.8))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Night.panel))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            .accessibilityLabel("You: \(line.text)")
        case .commander:
            Text(verbatim: line.text)
                .font(Night.body)
                .foregroundStyle(Night.ink)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.trailing, 30)
                .accessibilityLabel("\(commander): \(line.text)")
        case .look:
            Text(verbatim: line.text)
                .font(Night.small.italic())
                .foregroundStyle(Night.ink.opacity(0.5))
                .fixedSize(horizontal: false, vertical: true)
        case .trouble:
            Text(verbatim: line.text)
                .font(Night.small)
                .foregroundStyle(Night.bad)
                .fixedSize(horizontal: false, vertical: true)
        }
    }
}

/// An order the commander put forward, or an answer an envoy put to the
/// keeper: given by the keeper, or set aside.
private struct OfferCard: View {
    let offer: CommanderCounselSession.Offer
    let give: () -> Void
    let setAside: () -> Void
    /// What giving it is called: an order, or an answer.
    var giving = "Give the order"
    /// Asked again before war is given, as the Houses list asks it.
    @State private var asking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(verbatim: "PUT FORWARD")
                .font(Night.small)
                .tracking(1.2)
                .foregroundStyle(Night.ink.opacity(0.5))
            Text(verbatim: offer.proposal.told)
                .font(Night.body)
                .foregroundStyle(Night.ink)
                .fixedSize(horizontal: false, vertical: true)
            switch offer.state {
            case .waiting:
                HStack(spacing: 10) {
                    if let asked = offer.proposal.askedFirst {
                        Button(giving, role: .destructive) { asking = true }
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("\(giving): \(offer.proposal.told)")
                            .confirmationDialog(asked, isPresented: $asking, titleVisibility: .visible) {
                                Button(giving, role: .destructive, action: give)
                            }
                    } else {
                        Button(giving, action: give)
                            .buttonStyle(.borderedProminent)
                            .accessibilityLabel("\(giving): \(offer.proposal.told)")
                    }
                    Button("Set aside", action: setAside)
                        .buttonStyle(.bordered)
                        .accessibilityLabel("Set aside: \(offer.proposal.told)")
                }
                .font(Night.small)
            case .given:
                Text(verbatim: "Given. The realm's word follows.")
                    .font(Night.small)
                    .foregroundStyle(Night.good)
            case .setAside:
                Text(verbatim: "Set aside.")
                    .font(Night.small)
                    .foregroundStyle(Night.ink.opacity(0.5))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).stroke(Night.ink.opacity(0.2)))
        .accessibilityElement(children: .contain)
    }
}
