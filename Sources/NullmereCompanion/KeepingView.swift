import Foundation
import NullmereCompanionCore
import NullmereCore
import NullmereCounsel
import SwiftUI

/// The keeper's House from the phone: how it and the realm stand, its
/// companies and their orders, and its alliance's words.
struct KeepingView: View {
    let session: CompanionSession
    @State private var tab = CompanionTab.house

    var body: some View {
        TabView(selection: $tab) {
            HouseTab(session: session)
                .tabItem { Label("House", systemImage: "house") }
                .tag(CompanionTab.house)
            ArmyTab(session: session)
                .tabItem { Label("Army", systemImage: "shield") }
                .tag(CompanionTab.army)
            AllianceTab(session: session)
                .tabItem { Label("Alliance", systemImage: "flag") }
                .tag(CompanionTab.alliance)
        }
        .tint(Night.moon)
        .onAppear {
            #if DEBUG
            if let shown = CompanionCheck.tabShown { tab = shown }
            #endif
        }
    }
}

enum CompanionTab: String, Hashable {
    case house, army, alliance
}

/// The realm's word on the last order, while it is news.
struct WordLine: View {
    let session: CompanionSession

    var body: some View {
        if let word = session.word {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                if word.awaited { ProgressView().controlSize(.small).tint(Night.moon) }
                Text(verbatim: word.text)
                    .font(Night.small)
                    .foregroundStyle(word.refused ? Night.bad : Night.ink.opacity(0.85))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(word.refused ? "Refused: \(word.text)" : word.text)
        }
        if let reach = session.outOfReach {
            Text(verbatim: reach)
                .font(Night.small)
                .foregroundStyle(Night.bad)
        }
    }
}

/// How the realm and the House stand: the watch and its time, the House's
/// stores and holds, readiness, and the realm's chronicle.
struct HouseTab: View {
    let session: CompanionSession

    var body: some View {
        NavigationStack {
            List {
                if let ledger = session.ledger {
                    Section {
                        VStack(alignment: .leading, spacing: 6) {
                            Text(verbatim: ledger.house)
                                .font(Night.title)
                                .foregroundStyle(Night.ink)
                            if let status = session.status {
                                Text(verbatim: "\(status.name) · age \(status.age) · watch \(status.watch)")
                                    .font(Night.body)
                                    .foregroundStyle(Night.moon)
                            }
                            TimelineView(.periodic(from: .now, by: 1)) { context in
                                if let left = session.secondsLeft(at: context.date) {
                                    Text(verbatim: "The watch turns in \(Self.clock(left)), or when every keeper there is ready.")
                                        .font(Night.small)
                                        .foregroundStyle(Night.ink.opacity(0.7))
                                }
                            }
                            if let status = session.status {
                                Text(verbatim: "\(status.online) keepers there, \(status.ready) ready")
                                    .font(Night.small)
                                    .foregroundStyle(Night.ink.opacity(0.7))
                            }
                        }
                        .padding(.vertical, 6)
                        .accessibilityElement(children: .combine)
                        Toggle(isOn: Binding(get: { session.isReady }, set: { session.setReady($0) })) {
                            Text(verbatim: "Ready for the watch to turn")
                                .font(Night.body)
                        }
                        .tint(Night.moon)
                        WordLine(session: session)
                    }
                    Section("Stores") {
                        ForEach(ledger.stores, id: \.resource) { store in
                            HStack {
                                Text(verbatim: store.resource.title)
                                    .font(Night.body)
                                Spacer()
                                Text(verbatim: "\(store.amount)")
                                    .font(Night.figures)
                                    .foregroundStyle(Night.moon)
                            }
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Section("Holds") {
                        ForEach(ledger.holds) { hold in
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: hold.isSeat ? "\(hold.name), the seat" : hold.name)
                                    .font(Night.body)
                                ForEach(hold.work, id: \.self) { work in
                                    Text(verbatim: work)
                                        .font(Night.small)
                                        .foregroundStyle(Night.ink.opacity(0.7))
                                }
                                if hold.work.isEmpty {
                                    Text(verbatim: "Nothing raised or mustered")
                                        .font(Night.small)
                                        .foregroundStyle(Night.ink.opacity(0.5))
                                }
                            }
                            .accessibilityElement(children: .combine)
                            if !hold.works.isEmpty || !hold.musters.isEmpty {
                                HStack(spacing: 10) {
                                    OrdersMenu(title: "Raise", orders: hold.works, label: "Raise a work at \(hold.name)") { order in
                                        session.give(order.command, told: "\(order.title) at \(hold.name)")
                                    }
                                    OrdersMenu(title: "Muster", orders: hold.musters, label: "Muster a company at \(hold.name)") { order in
                                        session.give(order.command, told: "\(order.title) at \(hold.name)")
                                    }
                                }
                                .font(Night.small)
                            }
                        }
                    }
                    Section("The chronicle") {
                        ForEach(Array(ledger.chronicle.enumerated()), id: \.offset) { line in
                            Text(verbatim: line.element)
                                .font(Night.small)
                                .foregroundStyle(Night.ink.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    Section {
                        Button(role: .destructive) {
                            session.unlink()
                        } label: {
                            Text(verbatim: "Let this phone go")
                        }
                        .accessibilityHint("This phone speaks for your House no more; link it again from your Mac")
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Night.background)
            .navigationTitle("House")
        }
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// The House's companies: what each is about and the orders it may be
/// given, each the realm's to decide; and its commanders, each of whom may
/// be asked for counsel, spoken by Apple's on-device model on this phone.
struct ArmyTab: View {
    let session: CompanionSession
    @State private var counselling: Counselling?

    var body: some View {
        NavigationStack {
            List {
                if let ledger = session.ledger {
                    Section {
                        WordLine(session: session)
                    }
                    if ledger.companies.isEmpty {
                        Text(verbatim: "Your House has no companies.")
                            .font(Night.body)
                            .foregroundStyle(Night.ink.opacity(0.7))
                    }
                    ForEach(ledger.companies) { company in
                        Section {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(verbatim: company.name)
                                    .font(Night.heading)
                                Text(verbatim: "\(company.troops) troops\(company.leader.map { ", led by \($0)" } ?? "")")
                                    .font(Night.small)
                                    .foregroundStyle(Night.moon)
                                Text(verbatim: company.doing)
                                    .font(Night.small)
                                    .foregroundStyle(Night.ink.opacity(0.75))
                            }
                            .accessibilityElement(children: .combine)
                            if !company.orders.isEmpty || !company.marches.isEmpty {
                                HStack(spacing: 10) {
                                    ForEach(company.orders) { order in
                                        Button(order.title) {
                                            session.give(order.command, told: "\(order.title) the \(company.name)")
                                        }
                                        .buttonStyle(.bordered)
                                        .accessibilityLabel("\(order.title) the \(company.name)")
                                    }
                                    OrdersMenu(title: "March", orders: company.marches, label: "March the \(company.name) to a hold") { march in
                                        session.give(march.command, told: "\(march.title), the \(company.name)")
                                    }
                                }
                                .font(Night.small)
                            }
                            if !company.strikes.isEmpty || !company.gathers.isEmpty {
                                HStack(spacing: 10) {
                                    OrdersMenu(title: "Strike", orders: company.strikes, label: "Strike with the \(company.name)") { strike in
                                        session.give(strike.command, told: "\(strike.title), the \(company.name)")
                                    }
                                    OrdersMenu(title: "Gather", orders: company.gathers, label: "Send the \(company.name) to gather") { gather in
                                        session.give(gather.command, told: "\(gather.title), the \(company.name)")
                                    }
                                }
                                .font(Night.small)
                            }
                        }
                    }
                    if !ledger.commanders.isEmpty {
                        Section("Commanders") {
                            ForEach(ledger.commanders) { commander in
                                HStack(alignment: .center, spacing: 10) {
                                    VStack(alignment: .leading, spacing: 3) {
                                        Text(verbatim: commander.name)
                                            .font(Night.heading)
                                        Text(verbatim: "\(commander.title) · \(commander.standing)")
                                            .font(Night.small)
                                            .foregroundStyle(commander.canCounsel ? Night.ink.opacity(0.7) : Night.bad)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                    .accessibilityElement(children: .combine)
                                    Spacer()
                                    Button("Counsel") { openCounsel(with: commander.id) }
                                        .buttonStyle(.bordered)
                                        .font(Night.small)
                                        .disabled(!commander.canCounsel)
                                        .accessibilityLabel("Take counsel of \(commander.name)")
                                        .accessibilityHint(commander.canCounsel ? "Spoken by Apple's on-device model on this phone"
                                                                                : "\(commander.name) is held prisoner.")
                                }
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Night.background)
            .navigationTitle("Army")
        }
        .sheet(item: $counselling, onDismiss: { counselling = nil }) { open in
            CounselView(session: session, counsel: open.counsel) { counselling = nil }
        }
        .onChange(of: session.phase) {
            if session.phase != .keeping { counselling = nil }
        }
        .onAppear {
            #if DEBUG
            if CompanionCheck.counselShown, counselling == nil,
               let first = session.ledger?.commanders.first(where: \.canCounsel) {
                openCounsel(with: first.id)
            }
            #endif
        }
    }

    /// Opens counsel with one of the House's commanders, who remembers what
    /// was said in counsel on this phone this age.
    private func openCounsel(with commander: Int) {
        guard let taken = session.counsel(of: commander) else { return }
        let opened = CommanderCounselSession(counsel: taken.counsel, memory: taken.memory)
        opened.onRemember = { [session] in session.remember($0) }
        opened.prewarm()
        counselling = Counselling(id: commander, counsel: opened)
    }
}

/// The alliance and its words, and the words said to the whole realm, with
/// a line to say.
struct AllianceTab: View {
    let session: CompanionSession
    @State private var words = ""
    @State private var toAlliance = true

    var body: some View {
        NavigationStack {
            List {
                if let ledger = session.ledger {
                    Section {
                        if let alliance = ledger.alliance {
                            Text(verbatim: alliance)
                                .font(Night.heading)
                            Text(verbatim: ledger.allies.joined(separator: ", "))
                                .font(Night.small)
                                .foregroundStyle(Night.ink.opacity(0.75))
                        } else {
                            Text(verbatim: "Your House is in no alliance. Raise a banner or ask to join one on your Mac.")
                                .font(Night.small)
                                .foregroundStyle(Night.ink.opacity(0.75))
                        }
                    }
                    Section {
                        TextField("Your words", text: $words, axis: .vertical)
                            .font(Night.body)
                            .lineLimit(1...4)
                        if ledger.alliance != nil {
                            Picker("To", selection: $toAlliance) {
                                Text(verbatim: "Your alliance").tag(true)
                                Text(verbatim: "The realm").tag(false)
                            }
                            .pickerStyle(.segmented)
                        }
                        Button("Say it") {
                            session.say(words, toAlliance: toAlliance && ledger.alliance != nil)
                            words = ""
                        }
                        .disabled(words.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        WordLine(session: session)
                    }
                    if ledger.alliance != nil {
                        Section("Said in the alliance") {
                            SaidLines(lines: ledger.allianceWords)
                        }
                    }
                    Section("Said to the realm") {
                        SaidLines(lines: ledger.realmWords)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Night.background)
            .navigationTitle("Alliance")
        }
    }
}

/// A menu of orders of one kind, shown only when there are any.
struct OrdersMenu: View {
    let title: String
    let orders: [CompanionLedger.Order]
    let label: String
    let give: (CompanionLedger.Order) -> Void

    var body: some View {
        if !orders.isEmpty {
            Menu(title) {
                ForEach(orders) { order in
                    Button(order.title) { give(order) }
                }
            }
            .accessibilityLabel(label)
        }
    }
}

struct SaidLines: View {
    let lines: [CompanionLedger.Said]

    var body: some View {
        if lines.isEmpty {
            Text(verbatim: "Nothing said lately.")
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.5))
        }
        ForEach(lines.reversed()) { said in
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(said.from) · watch \(said.watch)")
                    .font(Night.small)
                    .foregroundStyle(said.isOwn ? Night.moon : Night.ink.opacity(0.6))
                Text(verbatim: said.text)
                    .font(Night.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
