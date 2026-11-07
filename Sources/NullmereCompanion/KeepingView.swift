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
    /// The realm's word on the last order, while it is news: held at the
    /// foot of every tab a few seconds as it comes, wherever the keeper has
    /// scrolled to give it.
    @State private var news: CompanionSession.Word?

    var body: some View {
        TabView(selection: $tab) {
            HouseTab(session: session)
                .safeAreaInset(edge: .bottom) { WordBanner(word: news) }
                .tabItem { Label("House", systemImage: "house") }
                // What waits on the keeper there: envoys, foes gathering.
                .badge(session.ledger?.houseWaiting ?? 0)
                .tag(CompanionTab.house)
            LandTab(session: session)
                .safeAreaInset(edge: .bottom) { WordBanner(word: news) }
                .tabItem { Label("Land", systemImage: "map") }
                .tag(CompanionTab.land)
            ArmyTab(session: session)
                .safeAreaInset(edge: .bottom) { WordBanner(word: news) }
                .tabItem { Label("Army", systemImage: "shield") }
                // Commanders with a talent to learn, the Spine's venture to make.
                .badge(session.ledger?.armyWaiting ?? 0)
                .tag(CompanionTab.army)
            AllianceTab(session: session)
                .safeAreaInset(edge: .bottom) { WordBanner(word: news) }
                .tabItem { Label("Alliance", systemImage: "flag") }
                // Invitations and asks to answer, allies to help.
                .badge(session.ledger?.allianceWaiting ?? 0)
                .tag(CompanionTab.alliance)
        }
        .tint(Night.moon)
        .task(id: session.word) {
            news = session.word
            guard let word = session.word, !word.awaited else { return }
            try? await Task.sleep(for: WordBanner.held)
            if session.word == word { news = nil }
        }
        .onAppear {
            #if DEBUG
            if let shown = CompanionCheck.tabShown { tab = shown }
            #endif
        }
    }
}

enum CompanionTab: String, Hashable {
    case house, land, army, alliance
}

/// The realm's word on the last order, at the foot of a tab while it is
/// news: awaited, carried out (with what came of it), or refused.
struct WordBanner: View {
    let word: CompanionSession.Word?

    /// How long a word the realm has given stays at the foot of the tabs.
    static let held: Duration = .seconds(6)

    var body: some View {
        Group {
            if let word {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    if word.awaited { ProgressView().controlSize(.small).tint(Night.moon) }
                    Text(verbatim: word.text)
                        .font(Night.small)
                        .foregroundStyle(word.refused ? Night.bad : Night.ink)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 12))
                .padding(.horizontal, 12)
                .padding(.bottom, 6)
                .transition(.move(edge: .bottom).combined(with: .opacity))
                .accessibilityElement(children: .combine)
                .accessibilityLabel(word.refused ? "Refused: \(word.text)" : word.text)
            }
        }
        .animation(.easeOut(duration: 0.25), value: word)
    }
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
    /// The page of barter, the Inn and the satchel, opened for the smoke
    /// test to see (the keeper opens it by its way beneath the stores).
    @State private var marketOpen = false

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
                    // The watch's labours, folded beneath how they stand, and the
                    // happening under way or the next, as the Mac's Realm panel tells them.
                    if ledger.course.labours != nil || ledger.course.happening != nil {
                        Section("Labours and happenings") {
                            if let labours = ledger.course.labours {
                                DisclosureGroup {
                                    ForEach(Array(ledger.course.tasks.enumerated()), id: \.offset) { task in
                                        Label {
                                            Text(verbatim: task.element.text)
                                        } icon: {
                                            Image(systemName: task.element.done ? "checkmark.circle.fill" : "circle")
                                        }
                                        .font(Night.small)
                                        .foregroundStyle(task.element.done ? Night.good : Night.ink.opacity(0.85))
                                        .accessibilityLabel(task.element.done ? "Done: \(task.element.text)" : task.element.text)
                                    }
                                } label: {
                                    Text(verbatim: labours)
                                        .font(Night.small)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            if let happening = ledger.course.happening {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(verbatim: happening)
                                        .font(Night.small)
                                        .foregroundStyle(Night.ink.opacity(0.85))
                                        .fixedSize(horizontal: false, vertical: true)
                                    if let standing = ledger.course.standing {
                                        Text(verbatim: standing)
                                            .font(Night.small)
                                            .foregroundStyle(Night.moon)
                                    }
                                }
                                .accessibilityElement(children: .combine)
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
                        // Barter, the pedlar, the Lantern Inn and the satchel on a
                        // page of their own, the way to it saying what waits there.
                        NavigationLink {
                            MarketPage(session: session)
                        } label: {
                            VStack(alignment: .leading, spacing: 3) {
                                Text(verbatim: MarketPage.way)
                                    .font(Night.body)
                                ForEach(ledger.errands, id: \.self) { errand in
                                    Text(verbatim: errand)
                                        .font(Night.small)
                                        .foregroundStyle(Night.moon)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }
                            .padding(.vertical, 2)
                            .accessibilityElement(children: .combine)
                        }
                    }
                    Section("Holds") {
                        ForEach(ledger.holds) { hold in
                            HoldRows(session: session, hold: hold)
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
                    // While the keeper is away: the caretaker's standing orders,
                    // and the orders that would change them.
                    Section("While you are away") {
                        Text(verbatim: ledger.standing.said)
                            .font(Night.small)
                            .foregroundStyle(Night.ink.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        HStack(spacing: 14) {
                            ListedOrdersMenu(title: "Muster", orders: ledger.standing.musters,
                                             label: "The one kind of company your caretaker musters") { order in
                                session.give(order.command, told: order.title)
                            }
                            ListedOrdersMenu(title: "Raise first", orders: ledger.standing.raises,
                                             label: "The work your caretaker raises first") { order in
                                session.give(order.command, told: order.title)
                            }
                            ListedOrdersMenu(title: "More", orders: ledger.standing.others,
                                             label: "Your caretaker's other standing orders") { order in
                                session.give(order.command, told: order.title)
                            }
                        }
                        .font(Night.small)
                    }
                    // The chronicle, the latest first: three lines open, the
                    // earlier folded beneath them, the world first.
                    Section("The chronicle") {
                        ForEach(Array(ledger.chronicle.prefix(CompanionLedger.reportsOpen).enumerated()), id: \.offset) { line in
                            ChronicleLine(text: line.element)
                        }
                        if ledger.chronicle.count > CompanionLedger.reportsOpen {
                            DisclosureGroup("\(ledger.chronicle.count - CompanionLedger.reportsOpen) earlier") {
                                ForEach(Array(ledger.chronicle.dropFirst(CompanionLedger.reportsOpen).enumerated()), id: \.offset) { line in
                                    ChronicleLine(text: line.element)
                                }
                            }
                            .font(Night.small)
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
            .navigationDestination(isPresented: $marketOpen) { MarketPage(session: session) }
        }
        .onAppear {
            #if DEBUG
            if CompanionCheck.marketShown { marketOpen = true }
            #endif
        }
    }

    static func clock(_ seconds: Int) -> String {
        String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

/// Barter, the pedlar, the Lantern Inn and the satchel, a page of their
/// own off the House tab's stores: the pedlar while he lies off one of the
/// House's holds, the Inn's keys and the chests it may open (what one held
/// told in the realm's word on it), barter, and each item of the satchel
/// with its uses now.
struct MarketPage: View {
    let session: CompanionSession

    /// The House tab's way to it.
    static let way = "Barter, the Inn and the satchel"

    var body: some View {
        List {
            if let ledger = session.ledger {
                if session.word != nil || session.outOfReach != nil {
                    Section {
                        WordLine(session: session)
                    }
                }
                if let pedlar = ledger.pedlar {
                    Section("The Pedlar of the Still") {
                        Text(verbatim: pedlar.said)
                            .font(Night.small)
                            .foregroundStyle(Night.ink.opacity(0.8))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(pedlar.wares) { ware in
                            WareRow(session: session, ware: ware)
                        }
                    }
                }
                Section("The Lantern Inn") {
                    Text(verbatim: ledger.inn.keys)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    ForEach(Array(ledger.inn.opens.enumerated()), id: \.offset) { open in
                        Button(open.element.title) { session.give(open.element.command, told: open.element.title) }
                            .font(Night.body)
                    }
                }
                BarterSection(session: session, ledger: ledger)
                if !ledger.satchel.isEmpty {
                    Section("Satchel") {
                        ForEach(ledger.satchel) { item in
                            SatchelRow(session: session, item: item)
                        }
                    }
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Night.background)
        .navigationTitle("Market and Inn")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }
}

/// The House's companies: what each is about and the orders it may be
/// given, each the realm's to decide; and its commanders, each of whom may
/// be asked for counsel, spoken by Apple's on-device model on this phone.
struct ArmyTab: View {
    let session: CompanionSession
    @State private var counselling: Counselling?
    @State private var wording = false

    var body: some View {
        NavigationStack {
            List {
                if let ledger = session.ledger {
                    Section {
                        WordLine(session: session)
                        Button("Orders in your own words") { wording = true }
                            .font(Night.body)
                            .accessibilityHint("Read by Apple's on-device model on this phone into the order book's lines; nothing is given until you give it")
                    }
                    // A rally called from the phone, as on the Mac: on a lair
                    // found or a hold of a House at war, gathering two watches.
                    if !ledger.calls.isEmpty {
                        Section("Call a rally") {
                            OrdersMenu(title: "Call a rally", orders: ledger.calls, label: "Call a rally of your alliance") { order in
                                session.give(order.command, told: order.title)
                            }
                            .font(Night.body)
                        }
                    }
                    if ledger.companies.isEmpty {
                        Text(verbatim: "Your House has no companies.")
                            .font(Night.body)
                            .foregroundStyle(Night.ink.opacity(0.7))
                    }
                    ForEach(ledger.companies) { company in
                        Section {
                            CompanyRows(session: session, company: company)
                        }
                    }
                    // The House's reports, as the Mac files them: battles,
                    // hunts, fields of battle, scoutings and lairs assaulted.
                    if !session.reports.isEmpty {
                        Section("Reports") {
                            ForEach(session.reports.prefix(CompanionLedger.reportsOpen)) { report in
                                ReportRow(report: report)
                            }
                            if session.reports.count > CompanionLedger.reportsOpen {
                                DisclosureGroup("Earlier reports (\(session.reports.count - CompanionLedger.reportsOpen))") {
                                    ForEach(session.reports.dropFirst(CompanionLedger.reportsOpen)) { report in
                                        ReportRow(report: report)
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
                                CommanderOrders(session: session, commander: commander)
                            }
                        }
                    }
                    // The Spine: its next stage, and a line or one commander sent up it.
                    if !ledger.commanders.isEmpty {
                        Section("The Spine") {
                            Text(verbatim: ledger.spine.said)
                                .font(Night.small)
                                .foregroundStyle(Night.ink.opacity(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                            ListedOrdersMenu(title: "Send up the Spine", orders: ledger.spine.ventures,
                                             label: "Send your commanders up the Spine") { order in
                                session.give(order.command, told: order.title)
                            }
                            .font(Night.body)
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Night.background)
            .navigationTitle("Army")
            .sheet(isPresented: $wording) {
                OrdersInWordsView(session: session) { wording = false }
            }
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
            if CompanionCheck.wordsShown { wording = true }
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
    @State private var letter = ""
    @State private var writingTo: Int?

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
                        // The alliance's studies: the one pursued and what
                        // is still to give, its leader choosing the next.
                        Section("Studies together") {
                            ForEach(ledger.allianceLore, id: \.self) { line in
                                Text(verbatim: line)
                                    .font(Night.small)
                                    .foregroundStyle(Night.ink.opacity(0.8))
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            if !ledger.allianceGifts.isEmpty || !ledger.pursuits.isEmpty {
                                HStack(spacing: 10) {
                                    ListedOrdersMenu(title: "Give", orders: ledger.allianceGifts, label: "Give toward the alliance's study") { order in
                                        session.give(order.command, told: order.title)
                                    }
                                    ListedOrdersMenu(title: "Pursue", orders: ledger.pursuits, label: "Set your alliance to pursue a study") { order in
                                        session.give(order.command, told: order.title)
                                    }
                                }
                                .font(Night.small)
                            }
                        }
                        // The Houses the alliance may invite, nearest first, in one
                        // menu rather than a button each down the tab.
                        if !ledger.invites.isEmpty {
                            Section {
                                ListedOrdersMenu(title: "Invite a House…", orders: ledger.invites,
                                                 label: "Invite a House to your alliance") { invite in
                                    session.give(invite.command, told: invite.title)
                                }
                                .font(Night.body)
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
                    // The Houses nearest, how each stands with the keeper's,
                    // and envoys or war sent from the phone.
                    if !ledger.dealings.isEmpty {
                        Section {
                            // Folded behind a line, the world first: opened
                            // when the keeper would deal with a House.
                            DisclosureGroup {
                                ForEach(ledger.dealings) { dealing in
                                    DealingRow(session: session, dealing: dealing)
                                }
                            } label: {
                                Text(verbatim: CompanionLedger.dealingsLine(ledger.dealings))
                                    .font(Night.body)
                            }
                        }
                    }
                    // Letters to one keeper alone, read by them and the keeper:
                    // the latest three, the earlier folded beneath them.
                    if !ledger.letters.isEmpty || !ledger.correspondents.isEmpty {
                        Section("Letters") {
                            ForEach(ledger.letters.prefix(CompanionLedger.reportsOpen)) { letter in
                                LetterLine(letter: letter)
                            }
                            if ledger.letters.count > CompanionLedger.reportsOpen {
                                DisclosureGroup("\(ledger.letters.count - CompanionLedger.reportsOpen) earlier") {
                                    ForEach(ledger.letters.dropFirst(CompanionLedger.reportsOpen)) { letter in
                                        LetterLine(letter: letter)
                                    }
                                }
                                .font(Night.small)
                            }
                            if let first = ledger.correspondents.first {
                                let reader = writingTo.flatMap { id in ledger.correspondents.first { $0.id == id } } ?? first
                                Picker("To", selection: Binding(get: { reader.id }, set: { writingTo = $0 })) {
                                    ForEach(ledger.correspondents) { Text(verbatim: $0.name).tag($0.id) }
                                }
                                .font(Night.body)
                                TextField("A letter for \(reader.name)", text: $letter, axis: .vertical)
                                    .font(Night.body)
                                    .lineLimit(1...4)
                                Button("Send the letter") {
                                    session.give(.writeLetter(to: reader.id, words: letter), told: "A letter to \(reader.name)")
                                    letter = ""
                                }
                                .disabled(letter.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                            }
                        }
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

/// A company of the House, as the Army tab and the Land tab list it: what
/// it is about, and the orders it may be given now, each the realm's to
/// decide.
struct CompanyRows: View {
    let session: CompanionSession
    let company: CompanionLedger.Company

    var body: some View {
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

/// A report of a battle, a hunt, a field of battle, a scouting or a lair
/// assaulted: how it went, where and when, and each side's part when opened.
struct ReportRow: View {
    let report: BattleReport

    var body: some View {
        DisclosureGroup {
            ForEach(Array(report.lines.enumerated()), id: \.offset) { line in
                Text(verbatim: line.element)
                    .font(Night.small)
                    .foregroundStyle(Night.ink.opacity(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            }
        } label: {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: report.title)
                    .font(Night.body)
                    .fixedSize(horizontal: false, vertical: true)
                Text(verbatim: "\(outcome) · \(report.place) · watch \(report.watch)")
                    .font(Night.small)
                    .foregroundStyle(tint)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private var outcome: String {
        switch report.outcome {
        case .won: return "Won"
        case .lost: return "Lost"
        case .held: return "Both stood"
        case .scouted: return "Scouted"
        }
    }

    private var tint: Color {
        switch report.outcome {
        case .won: return Night.good
        case .lost: return Night.bad
        case .held, .scouted: return Night.ink.opacity(0.7)
        }
    }
}

/// Another House and the keeper's dealings with it: its stance, Send an
/// envoy, and war, asked once more before it is declared.
struct DealingRow: View {
    let session: CompanionSession
    let dealing: CompanionLedger.Dealing
    @State private var declaring = false

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: dealing.name)
                .font(Night.body)
            Text(verbatim: dealing.stance)
                .font(Night.small)
                .foregroundStyle(dealing.stance.hasPrefix("At war") ? Night.bad : Night.ink.opacity(0.7))
        }
        .accessibilityElement(children: .combine)
        if !dealing.envoys.isEmpty || !dealing.gifts.isEmpty || dealing.war != nil {
            HStack(spacing: 10) {
                ListedOrdersMenu(title: "Send an envoy", orders: dealing.envoys, label: "Send an envoy to \(dealing.name)") { order in
                    session.give(order.command, told: order.title)
                }
                ListedOrdersMenu(title: "Send a gift", orders: dealing.gifts, label: "Send a gift to \(dealing.name)") { order in
                    session.give(order.command, told: order.title)
                }
                if let war = dealing.war {
                    Button("Declare war", role: .destructive) { declaring = true }
                        .accessibilityLabel(war.title)
                        .confirmationDialog("\(war.title)?", isPresented: $declaring, titleVisibility: .visible) {
                            Button(war.title, role: .destructive) { session.give(war.command, told: war.title) }
                        }
                }
            }
            .font(Night.small)
        }
    }
}

/// What a commander may be ordered to now, each the rules would take: to
/// take up a company of war, ride second beside its leader or ride home;
/// to learn a talent's next rank; to wear a piece of the armoury.
struct CommanderOrders: View {
    let session: CompanionSession
    let commander: CompanionLedger.Commander

    var body: some View {
        if !commander.leads.isEmpty || !commander.seconds.isEmpty || commander.home != nil {
            HStack(spacing: 10) {
                ListedOrdersMenu(title: "Lead", orders: commander.leads, label: "Give \(commander.name) a company to lead") { order in
                    session.give(order.command, told: "\(commander.name): \(order.title)")
                }
                ListedOrdersMenu(title: "Ride second", orders: commander.seconds, label: "Send \(commander.name) to ride second") { order in
                    session.give(order.command, told: "\(commander.name): \(order.title)")
                }
                if let home = commander.home {
                    Button(home.title) { session.give(home.command, told: "\(commander.name): \(home.title)") }
                        .accessibilityLabel("\(commander.name) rides home")
                }
            }
            .font(Night.small)
        }
        if !commander.talents.isEmpty || !commander.gear.isEmpty {
            HStack(spacing: 10) {
                ListedOrdersMenu(title: "Learn", orders: commander.talents, label: "\(commander.name) learns a talent") { order in
                    session.give(order.command, told: "\(commander.name): \(order.title)")
                }
                ListedOrdersMenu(title: "Wear", orders: commander.gear, label: "\(commander.name) wears a piece of the armoury") { order in
                    session.give(order.command, told: "\(commander.name): \(order.title)")
                }
            }
            .font(Night.small)
        }
    }
}

/// A hold of the House, as the House tab and the Land tab list it: what it
/// raises and musters, and the works and companies it may raise and muster
/// now.
struct HoldRows: View {
    let session: CompanionSession
    let hold: CompanionLedger.Hold

    var body: some View {
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
        // The latest three open, the earlier folded beneath them, as the
        // chronicle, the letters and the reports are.
        let latest = Array(lines.reversed())
        ForEach(latest.prefix(CompanionLedger.reportsOpen)) { said in
            SaidLine(said: said)
        }
        if latest.count > CompanionLedger.reportsOpen {
            DisclosureGroup("\(latest.count - CompanionLedger.reportsOpen) earlier") {
                ForEach(latest.dropFirst(CompanionLedger.reportsOpen)) { said in
                    SaidLine(said: said)
                }
            }
            .font(Night.small)
        }
    }
}

/// A line said, who said it and when, the keeper's own brighter.
struct SaidLine: View {
    let said: CompanionLedger.Said

    var body: some View {
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

/// A letter as the phone lists it, those written to the House brighter.
struct LetterLine: View {
    let letter: CompanionLedger.Letter

    var body: some View {
        Text(verbatim: letter.line)
            .font(Night.small)
            .foregroundStyle(Night.ink.opacity(letter.incoming ? 0.9 : 0.65))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// One of the pedlar's wares: what it is and what he asks, Buy where the
/// realm would sell it, or why not in its words.
struct WareRow: View {
    let session: CompanionSession
    let ware: CompanionLedger.Ware

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: ware.title)
                    .font(Night.body)
                    .foregroundStyle(Night.ink.opacity(ware.buy == nil && ware.why == nil ? 0.5 : 0.9))
                if let why = ware.why {
                    Text(verbatim: why)
                        .font(Night.small)
                        .foregroundStyle(Night.bad)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if let buy = ware.buy {
                Button("Buy") { session.give(buy.command, told: buy.title) }
                    .buttonStyle(.bordered)
                    .font(Night.body)
                    .accessibilityLabel(buy.title)
            }
        }
    }
}

/// A line of the realm's chronicle as the House tab lists it.
struct ChronicleLine: View {
    let text: String

    var body: some View {
        Text(verbatim: text)
            .font(Night.small)
            .foregroundStyle(Night.ink.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
    }
}
