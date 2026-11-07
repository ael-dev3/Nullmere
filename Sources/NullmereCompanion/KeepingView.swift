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
                if let away = session.away {
                    AwaySection(session: session, away: away)
                }
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
                                Text(verbatim: "\(status.online) \(status.online == 1 ? "keeper" : "keepers") there, \(status.ready) ready")
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
                    if !ledger.gatherings.isEmpty {
                        Section("On the walls") {
                            ForEach(ledger.gatherings, id: \.self) { gathering in
                                Text(verbatim: gathering)
                                    .font(Night.body)
                                    .foregroundStyle(Night.bad)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                    if !ledger.envoys.isEmpty {
                        Section("Envoys waiting") {
                            ForEach(ledger.envoys) { envoy in
                                EnvoyRow(session: session, envoy: envoy)
                            }
                        }
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
                    // The Archive's studies: the one under way, or those the House may begin.
                    if ledger.studying != nil || !ledger.studies.isEmpty {
                        Section("Studies") {
                            if let studying = ledger.studying {
                                Text(verbatim: studying)
                                    .font(Night.body)
                            } else {
                                OrdersMenu(title: "Begin a study", orders: ledger.studies, label: "Begin a study at the Archive") { order in
                                    session.give(order.command, told: order.title)
                                }
                                .font(Night.small)
                            }
                        }
                    }
                    BarterSection(session: session, ledger: ledger)
                    // The satchel: each item, how many, what one does, and its uses now.
                    if !ledger.satchel.isEmpty {
                        Section("Satchel") {
                            ForEach(ledger.satchel) { item in
                                SatchelRow(session: session, item: item)
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
                            if !company.rallies.isEmpty || !company.gates.isEmpty {
                                HStack(spacing: 10) {
                                    OrdersMenu(title: "Rally", orders: company.rallies, label: "Send the \(company.name) to a rally") { rally in
                                        session.give(rally.command, told: "\(rally.title), the \(company.name)")
                                    }
                                    OrdersMenu(title: "Keep gates", orders: company.gates,
                                               label: "Send the \(company.name) to keep an ally's gates") { gates in
                                        session.give(gates.command, told: "\(gates.title), the \(company.name)")
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
/// a line to say; what waits on the keeper's answer among the alliances,
/// and, as on the Mac, joining one or raising a banner, inviting Houses to
/// the one they lead, and leaving.
struct AllianceTab: View {
    let session: CompanionSession
    @State private var words = ""
    @State private var toAlliance = true
    @State private var banner = ""
    @State private var leaving = false

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
                            // Alliance help: each of an ally's works, musters
                            // and study helped once, every second help taking
                            // a watch off it, four at most.
                            ForEach(ledger.helps) { help in
                                Button(help.title) { session.give(help.command, told: help.title) }
                                    .buttonStyle(.bordered)
                                    .font(Night.small)
                            }
                        } else {
                            Text(verbatim: "Your House is in no alliance.")
                                .font(Night.small)
                                .foregroundStyle(Night.ink.opacity(0.75))
                        }
                    }
                    if !ledger.invitations.isEmpty || !ledger.requests.isEmpty {
                        Section("Awaiting your answer") {
                            ForEach(ledger.invitations + ledger.requests) { answer in
                                AnswerRow(session: session, answer: answer)
                            }
                        }
                    }
                    if ledger.alliance == nil {
                        Section("Join an alliance, or raise one") {
                            ForEach(ledger.asks) { ask in
                                Button(ask.title) { session.give(ask.command, told: ask.title) }
                                    .buttonStyle(.bordered)
                                    .font(Night.small)
                            }
                            TextField("A name for your banner", text: $banner)
                                .font(Night.body)
                            Button("Raise a banner") {
                                let name = banner.trimmingCharacters(in: .whitespaces)
                                session.give(.foundAlliance(name: name), told: "Raise the banner of \(name)")
                                banner = ""
                            }
                            .disabled(!Alliance.isValidName(banner.trimmingCharacters(in: .whitespaces)))
                        }
                    } else {
                        if !ledger.invites.isEmpty {
                            Section("Invite a House") {
                                ForEach(ledger.invites) { invite in
                                    Button(invite.title) { session.give(invite.command, told: invite.title) }
                                        .buttonStyle(.bordered)
                                        .font(Night.small)
                                }
                            }
                        }
                        if let leave = ledger.leave {
                            Section {
                                Button(leave.title, role: .destructive) { leaving = true }
                                    .confirmationDialog("\(leave.title)?", isPresented: $leaving, titleVisibility: .visible) {
                                        Button(leave.title, role: .destructive) { session.give(leave.command, told: leave.title) }
                                    }
                            }
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

/// What happened to the House while the phone was set aside, as the Mac
/// tells a keeper come back to it, until put away.
struct AwaySection: View {
    let session: CompanionSession
    let away: AwayReport

    var body: some View {
        Section {
            VStack(alignment: .leading, spacing: 6) {
                Text(verbatim: away.title)
                    .font(Night.heading)
                if !away.changes.isEmpty {
                    Text(verbatim: away.changes.map { "\($0.resource.title) \($0.delta > 0 ? "+" : "\u{2212}")\(abs($0.delta))" }
                        .joined(separator: "   "))
                        .font(Night.figures)
                        .foregroundStyle(Night.moon)
                }
                if let holds = away.holdsLine {
                    Text(verbatim: holds)
                        .font(Night.body)
                        .foregroundStyle(away.holdsChange > 0 ? Night.good : Night.bad)
                }
                ForEach(Array(away.news.enumerated()), id: \.offset) { line in
                    Text(verbatim: line.element)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let more = away.moreLine {
                    Text(verbatim: more)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.55))
                }
                if let standing = away.standing {
                    Text(verbatim: standing)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding(.vertical, 4)
            .accessibilityElement(children: .combine)
            Button("Done") { session.dismissAway() }
                .accessibilityLabel("Put away what happened while you were away")
        }
    }
}

/// An invitation to the House, or a House asking to join the alliance it
/// leads, and the keeper's answer, which the realm carries out.
struct AnswerRow: View {
    let session: CompanionSession
    let answer: CompanionLedger.Answer

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: answer.question)
                .font(Night.body)
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 10) {
                if let accept = answer.accept {
                    Button(accept.title) { session.give(accept.command, told: accept.title) }
                        .buttonStyle(.borderedProminent)
                } else if let unable = answer.unable {
                    Text(verbatim: unable)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                Button(answer.refuse.title) { session.give(answer.refuse.command, told: answer.refuse.title) }
                    .buttonStyle(.bordered)
            }
            .font(Night.small)
        }
        .padding(.vertical, 4)
    }
}

/// An envoy waiting on the keeper: its offer as the Mac words it, the words
/// its House sent, and the keeper's answer, which the realm carries out.
struct EnvoyRow: View {
    let session: CompanionSession
    let envoy: CompanionLedger.Envoy
    @State private var askingWar = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: "\(envoy.offer) from \(envoy.from)")
                .font(Night.heading)
            Text(verbatim: envoy.terms)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
            if let words = envoy.words {
                Text(verbatim: "\u{201C}\(words)\u{201D}")
                    .font(Night.small.italic())
                    .foregroundStyle(Night.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityLabel("\(envoy.from) writes: \(words)")
            }
            Text(verbatim: envoy.waits)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.5))
            HStack(spacing: 10) {
                if let accept = envoy.accept {
                    Button(accept.title) { session.give(accept.command, told: "Accept the \(envoy.offer.lowercased()) of \(envoy.from)") }
                        .buttonStyle(.borderedProminent)
                        .accessibilityLabel("Accept the \(envoy.offer.lowercased()) of \(envoy.from)")
                } else {
                    Text(verbatim: "You haven't what it asks.")
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.5))
                }
                Button(envoy.refuse.title, role: envoy.refusingIsWar ? .destructive : nil) {
                    if envoy.refusingIsWar { askingWar = true } else { refuse() }
                }
                .buttonStyle(.bordered)
                .accessibilityLabel("Refuse the \(envoy.offer.lowercased()) of \(envoy.from)")
            }
            .font(Night.small)
        }
        .padding(.vertical, 4)
        .confirmationDialog("Refuse, and war?", isPresented: $askingWar, titleVisibility: .visible) {
            Button("Refuse, and war", role: .destructive, action: refuse)
            Button("Not yet", role: .cancel) {}
        } message: {
            Text(verbatim: "\(envoy.from) marches on a House that refuses its demand.")
        }
    }

    private func refuse() {
        session.give(envoy.refuse.command, told: "Refuse the \(envoy.offer.lowercased()) of \(envoy.from)")
    }
}

/// A menu of orders of one kind, shown only when there are any.
/// A store bartered for another, three to one and moonsalt counted as three
/// of any other, as on the Mac: what it costs, or why the realm would
/// refuse it (`GameState.barterProblem`, one wording for both).
struct BarterSection: View {
    let session: CompanionSession
    let ledger: CompanionLedger
    @State private var take: Resource = .timber
    @State private var give: Resource = .grain
    @State private var amount = 20

    var body: some View {
        let price = take.barterCost(of: amount, paidIn: give)
        let problem = GameState.barterProblem(give: give, take: take, amount: amount, stock: ledger.stock, room: ledger.storage)
        Section("Barter") {
            Picker("Take", selection: $take) {
                ForEach(Resource.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
            }
            Stepper(value: $amount, in: 10...500, step: 10) {
                Text(verbatim: "\(amount) \(take.title.lowercased())")
                    .font(Night.figures)
            }
            Picker("For", selection: $give) {
                ForEach(Resource.allCases, id: \.self) { Text(verbatim: $0.title).tag($0) }
            }
            Text(verbatim: problem ?? "Costs \(price) \(give.title.lowercased())")
                .font(Night.small)
                .foregroundStyle(problem == nil ? Night.ink.opacity(0.75) : Night.bad)
                .fixedSize(horizontal: false, vertical: true)
            Button("Barter") {
                session.give(.barter(give: give, take: take, amount: amount),
                             told: "Barter \(price) \(give.title.lowercased()) for \(amount) \(take.title.lowercased())")
            }
            .disabled(problem != nil)
        }
        .font(Night.body)
    }
}

/// An item of the House's satchel: how many, what one does, and its uses
/// now, one at a press or a menu of where.
struct SatchelRow: View {
    let session: CompanionSession
    let item: CompanionLedger.Item

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: item.count)
                .font(Night.body)
            Text(verbatim: item.effect)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.75))
                .fixedSize(horizontal: false, vertical: true)
            if item.uses.count == 1, let use = item.uses.first {
                Button(use.title) { session.give(use.command, told: "\(use.title): a \(item.kind.title)") }
                    .buttonStyle(.bordered)
                    .font(Night.small)
            } else {
                OrdersMenu(title: "Use one", orders: item.uses, label: "Use a \(item.kind.title)") { order in
                    session.give(order.command, told: "\(order.title): a \(item.kind.title)")
                }
                .font(Night.small)
            }
        }
        .padding(.vertical, 2)
    }
}

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
