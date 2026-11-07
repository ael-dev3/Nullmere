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
                            // What still waits for orders, as the Mac's top bar says it.
                            if let waiting = ledger.waiting {
                                Text(verbatim: waiting)
                                    .font(Night.small)
                                    .foregroundStyle(Night.moon)
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
                    // The walls: foes gathered near the House's holds, and the veil
                    // of the Still, how it stands, drawn from here before a blow.
                    Section("On the walls") {
                        ForEach(ledger.gatherings, id: \.self) { gathering in
                            Text(verbatim: gathering)
                                .font(Night.body)
                                .foregroundStyle(Night.bad)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        Text(verbatim: ledger.veil)
                            .font(Night.small)
                            .foregroundStyle(ledger.drawVeil == nil ? Night.moon : Night.ink.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                        if let draw = ledger.drawVeil {
                            Button(draw.title) { session.give(draw.command, told: draw.title) }
                                .buttonStyle(.bordered)
                                .font(Night.small)
                                .accessibilityLabel("Draw the veil of the Still over your holds")
                        }
                    }
                    if !ledger.envoys.isEmpty {
                        Section("Envoys waiting") {
                            ForEach(ledger.envoys) { envoy in
                                EnvoyRow(session: session, envoy: envoy)
                            }
                        }
                    }
                    // The Lyceum, while it sits and a question is left: one at a time.
                    if let asked = ledger.lyceum {
                        Section("The Lyceum · \(asked.place)") {
                            Text(verbatim: asked.text)
                                .font(Night.body)
                                .fixedSize(horizontal: false, vertical: true)
                            ForEach(asked.answers) { answer in
                                Button(answer.title) {
                                    session.give(answer.command, told: "Answered the Lyceum: \(answer.title)")
                                }
                                .buttonStyle(.bordered)
                                .font(Night.small)
                                .accessibilityLabel("Answer \(answer.title)")
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
                        StoresRow(stores: ledger.stores, room: ledger.storage)
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
/// The House's four stores side by side, as the Mac's top bar shows them:
/// each figure, what it gains or loses as the watch turns, and its name,
/// full where the holds can keep no more of it; two by two where the type
/// is too large for four abreast.
struct StoresRow: View {
    typealias Store = (resource: Resource, amount: Int, gain: Int)
    let stores: [Store]
    let room: Int

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(alignment: .top, spacing: 10) {
                ForEach(stores, id: \.resource) { cell($0) }
            }
            Grid(alignment: .leading, horizontalSpacing: 16, verticalSpacing: 10) {
                ForEach(Array(stride(from: 0, to: stores.count, by: 2)), id: \.self) { first in
                    GridRow {
                        ForEach(stores[first..<min(first + 2, stores.count)], id: \.resource) { cell($0) }
                    }
                }
            }
        }
        .padding(.vertical, 2)
    }

    private func cell(_ store: Store) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            Text(verbatim: "\(store.amount)")
                .font(Night.figures)
                .foregroundStyle(store.amount >= room ? Night.ink : Night.moon)
            Text(verbatim: Resource.gainSaid(store.gain))
                .font(Night.small.monospacedDigit())
                .foregroundStyle(store.gain < 0 ? Night.bad : Night.good)
            Text(verbatim: store.resource.storeName(store.amount, room: room))
                .font(Night.small)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .fixedSize()
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(store.resource.storeSaid(store.amount, gain: store.gain, room: room))
    }
}

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

/// The Ring, the Spine and the Forge, a page of their own off the Army tab:
/// where the House stands in the Ring and its bouts, its line to stand and
/// the other keepers' lines to challenge; the Spine's next stage, with a
/// line or one commander to send up it; and the House's Forge, each set
/// folded until asked for, every piece with what it gives and takes.
struct VenturesPage: View {
    let session: CompanionSession

    /// The Army tab's way to it.
    static let way = "The Ring, the Spine and the Forge"

    var body: some View {
        List {
            if let ledger = session.ledger {
                if session.word != nil || session.outOfReach != nil {
                    Section {
                        WordLine(session: session)
                    }
                }
                Section("The Ring") {
                    RingRows(session: session, ring: ledger.ring)
                }
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
                Section(ledger.forge.heading) {
                    ForgeRows(session: session, forge: ledger.forge)
                }
                // The armoury, as the Mac's Commanders tell it: what is kept
                // there, each piece to arm a commander with or break up.
                Section(ledger.armoury.heading) {
                    ArmouryRows(session: session, armoury: ledger.armoury)
                }
            }
        }
        .scrollContentBackground(.hidden)
        .background(Night.background)
        .navigationTitle("Ring, Spine and Forge")
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
    @State private var venturesOpen = false

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
                    // The commanders of other Houses the House holds prisoner,
                    // as the Mac's Commanders list them: questioned once a
                    // watch for one true thing of their House, or let go.
                    if !ledger.prisoners.isEmpty {
                        Section("Prisoners") {
                            ForEach(ledger.prisoners) { prisoner in
                                PrisonerRows(session: session, prisoner: prisoner)
                            }
                        }
                    }
                    // The Ring and the Spine on a page of their own, the way to
                    // it saying what waits there.
                    if !ledger.commanders.isEmpty {
                        Section {
                            NavigationLink {
                                VenturesPage(session: session)
                            } label: {
                                VStack(alignment: .leading, spacing: 3) {
                                    Text(verbatim: VenturesPage.way)
                                        .font(Night.body)
                                    ForEach(ledger.venturesWaiting, id: \.self) { waiting in
                                        Text(verbatim: waiting)
                                            .font(Night.small)
                                            .foregroundStyle(Night.moon)
                                            .fixedSize(horizontal: false, vertical: true)
                                    }
                                }
                                .padding(.vertical, 2)
                                .accessibilityElement(children: .combine)
                            }
                        }
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(Night.background)
            .navigationTitle("Army")
            .navigationDestination(isPresented: $venturesOpen) { VenturesPage(session: session) }
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
            if CompanionCheck.venturesShown { venturesOpen = true }
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
                            // Every ally helped at once, each help the realm's to answer.
                            if ledger.helps.count > 1 {
                                Button("Help all \(ledger.helps.count)") {
                                    for help in ledger.helps { session.give(help.command, told: help.title) }
                                }
                                .buttonStyle(.bordered)
                                .font(Night.small)
                                .accessibilityLabel("Help every ally with work under way")
                            }
                        } else {
                            Text(verbatim: "Your House is in no alliance.")
                                .font(Night.small)
                                .foregroundStyle(Night.ink.opacity(0.75))
                        }
                    }
                    // The realm's law, as the Mac's Houses tell it: the edict
                    // before the realm and the House's vote, those holding it,
                    // and, folded, the edicts the House may put.
                    if !ledger.law.isEmpty {
                        Section("The realm's law") {
                            LawRows(session: session, law: ledger.law)
                        }
                    }
                    // Oaths, as the Mac's Houses tell them: the House's own,
                    // each renounced with notice, and those sworn to it.
                    if !ledger.oathsSworn.isEmpty || !ledger.oathsToUs.isEmpty {
                        Section("Oaths") {
                            OathRows(session: session, oaths: ledger.oathsSworn + ledger.oathsToUs)
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
        // What they wear, slot by slot, as the Mac's Commanders tell it,
        // each piece taken off back to the armoury.
        ForEach(commander.worn) { piece in
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                GearLines(piece: piece)
                Spacer()
                if let takeOff = piece.takeOff {
                    Button("Take off") { session.give(takeOff.command, told: takeOff.title) }
                        .buttonStyle(.bordered)
                        .font(Night.small)
                        .accessibilityLabel(takeOff.title)
                }
            }
        }
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
        // Held prisoner by another House: ransomed home, where the stores pay it.
        if let ransom = commander.ransom {
            Button(ransom.title) { session.give(ransom.command, told: "\(commander.name): \(ransom.title)") }
                .buttonStyle(.bordered)
                .font(Night.small)
                .accessibilityLabel("Ransom \(commander.name) home, for \(ransom.title.replacingOccurrences(of: "Ransom for ", with: ""))")
        }
    }
}

/// The oaths between the House and others, as the Mac's Houses tell them,
/// each of the House's own renounced with notice once the keeper says so,
/// as the Mac asks first.
struct OathRows: View {
    let session: CompanionSession
    let oaths: [CompanionLedger.SwornOath]

    var body: some View {
        ForEach(oaths) { oath in
            OathRow(session: session, oath: oath)
        }
    }
}

/// An oath in a line, with Renounce where it is the House's to renounce,
/// asked first.
private struct OathRow: View {
    let session: CompanionSession
    let oath: CompanionLedger.SwornOath
    @State private var renouncing = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(verbatim: oath.terms)
                .font(Night.small)
                .fixedSize(horizontal: false, vertical: true)
            if let renounce = oath.renounce {
                Button(renounce.title, role: .destructive) { renouncing = true }
                    .buttonStyle(.bordered)
                    .font(Night.small)
                    .accessibilityHint(GameState.renounceSaid)
                    .confirmationDialog("\(renounce.title)?", isPresented: $renouncing, titleVisibility: .visible) {
                        Button(renounce.title, role: .destructive) { session.give(renounce.command, told: renounce.title) }
                    } message: {
                        Text(verbatim: GameState.renounceSaid)
                    }
            }
        }
    }
}

/// The realm's law, as the Mac's Houses tell it: the edict before the
/// realm, its tally and the House's vote, or Aye and Nay while it may vote;
/// the edicts holding the realm; and, folded until asked for, the edicts the
/// House may put, each with what it would forbid and its cost.
struct LawRows: View {
    let session: CompanionSession
    let law: CompanionLedger.Law

    /// Aye or Nay, as a vote's button says it.
    static func label(of vote: CompanionLedger.Order) -> String {
        if case .voteEdict(_, let aye) = vote.command { return aye ? "Aye" : "Nay" }
        return vote.title
    }

    var body: some View {
        if let before = law.before {
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: before)
                    .font(Night.body)
                    .fixedSize(horizontal: false, vertical: true)
                if let tally = law.tally {
                    Text(verbatim: tally)
                        .font(Night.small.monospacedDigit())
                        .foregroundStyle(Night.ink.opacity(0.7))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let voted = law.voted {
                    Text(verbatim: voted)
                        .font(Night.small)
                        .foregroundStyle(Night.moon)
                }
            }
            .accessibilityElement(children: .combine)
            if !law.votes.isEmpty {
                HStack(spacing: 10) {
                    ForEach(law.votes) { vote in
                        Button(LawRows.label(of: vote)) { session.give(vote.command, told: vote.title) }
                            .accessibilityLabel(vote.title)
                    }
                }
                .buttonStyle(.bordered)
                .font(Night.small)
            }
        }
        ForEach(law.inForce, id: \.self) { line in
            Text(verbatim: line)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.8))
                .fixedSize(horizontal: false, vertical: true)
        }
        if law.before == nil && law.inForce.isEmpty {
            Text(verbatim: CompanionLedger.Law.none)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.6))
        }
        if !law.proposals.isEmpty {
            DisclosureGroup("Put an edict to the realm") {
                ForEach(law.proposals) { proposal in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(verbatim: proposal.heading)
                            .font(Night.body)
                        Text(verbatim: proposal.law)
                            .font(Night.small)
                            .foregroundStyle(Night.ink.opacity(0.7))
                            .fixedSize(horizontal: false, vertical: true)
                        Button(proposal.order.title) { session.give(proposal.order.command, told: proposal.order.title) }
                            .buttonStyle(.bordered)
                            .font(Night.small)
                    }
                    .padding(.vertical, 2)
                }
            }
            .font(Night.small)
        }
    }
}

/// A piece of gear in two lines: what it is, and what it gives.
struct GearLines: View {
    let piece: CompanionLedger.GearPiece

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: piece.title)
                .font(Night.small)
            Text(verbatim: piece.effect)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
    }
}

/// The House's armoury, as the Mac's Commanders tell it: each piece no
/// commander wears, to arm one of them with or break up for its moonsalt,
/// asked first as the Mac asks; or, with none kept, how gear comes.
struct ArmouryRows: View {
    let session: CompanionSession
    let armoury: CompanionLedger.Armoury

    var body: some View {
        if let none = armoury.none {
            Text(verbatim: none)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(armoury.kept) { piece in
            KeptPieceRow(session: session, piece: piece)
        }
    }
}

/// A piece kept in the armoury: Arm, for each commander free to take it
/// up, and Break up, asked first.
private struct KeptPieceRow: View {
    let session: CompanionSession
    let piece: CompanionLedger.GearPiece
    @State private var breaking = false

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            GearLines(piece: piece)
            HStack(spacing: 10) {
                ListedOrdersMenu(title: "Arm", orders: piece.arm, label: "Arm a commander with it") { order in
                    session.give(order.command, told: order.title)
                }
                if let breakUp = piece.breakUp {
                    Button("Break up", role: .destructive) { breaking = true }
                        .buttonStyle(.bordered)
                        .accessibilityLabel(breakUp.title)
                        .confirmationDialog("\(breakUp.title)?", isPresented: $breaking, titleVisibility: .visible) {
                            Button(breakUp.title, role: .destructive) { session.give(breakUp.command, told: breakUp.title) }
                        }
                }
            }
            .font(Night.small)
        }
    }
}

/// The House's Forge, as the Mac's Commanders tell it: the makings it keeps,
/// how to come by a Forge where it has none, and each set at the finest the
/// Forge makes, folded until asked for, every piece with what it gives and
/// takes, and Forge where the rules would forge it now.
struct ForgeRows: View {
    let session: CompanionSession
    let forge: CompanionLedger.Forge

    var body: some View {
        Text(verbatim: forge.makings)
            .font(Night.small)
            .foregroundStyle(Night.ink.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
        if let none = forge.none {
            Text(verbatim: none)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(forge.sets) { line in
            DisclosureGroup(line.name) {
                Text(verbatim: line.effect)
                    .font(Night.small)
                    .foregroundStyle(Night.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
                ForEach(line.pieces) { piece in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: piece.title)
                                .font(Night.small)
                            Text(verbatim: piece.said)
                                .font(Night.small)
                                .foregroundStyle(Night.ink.opacity(0.65))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        .accessibilityElement(children: .combine)
                        Spacer()
                        if let order = piece.forge {
                            Button("Forge") { session.give(order.command, told: order.title) }
                                .buttonStyle(.bordered)
                                .font(Night.small)
                                .accessibilityLabel(order.title)
                        }
                    }
                }
            }
            .font(Night.body)
        }
    }
}

/// The Ring, as the Mac's Commanders tell it: where the House stands and the
/// challenges left it, its last bouts, and, folded until asked for, its
/// heaviest commanders to stand as its line and the other keepers' lines,
/// each with its standing and weight, to challenge where the rules would.
struct RingRows: View {
    let session: CompanionSession
    let ring: CompanionLedger.TheRing

    var body: some View {
        Text(verbatim: ring.standing)
            .font(Night.small)
            .foregroundStyle(Night.ink.opacity(0.8))
            .fixedSize(horizontal: false, vertical: true)
        ForEach(ring.bouts, id: \.self) { bout in
            Text(verbatim: bout)
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        if ring.stand != nil || !ring.rivals.isEmpty {
            DisclosureGroup("Enter the Ring") {
                if let stand = ring.stand {
                    Button(stand.title) { session.give(stand.command, told: stand.title) }
                        .buttonStyle(.bordered)
                        .font(Night.small)
                }
                ForEach(ring.rivals) { rival in
                    HStack(alignment: .firstTextBaseline, spacing: 10) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: rival.name)
                                .font(Night.body)
                            Text(verbatim: rival.line)
                                .font(Night.small.monospacedDigit())
                                .foregroundStyle(Night.ink.opacity(0.65))
                        }
                        .accessibilityElement(children: .combine)
                        Spacer()
                        if let challenge = rival.challenge {
                            Button("Challenge") { session.give(challenge.command, told: challenge.title) }
                                .buttonStyle(.bordered)
                                .font(Night.small)
                                .accessibilityLabel(challenge.title)
                        }
                    }
                }
            }
            .font(Night.small)
        }
    }
}

/// A commander the House holds prisoner, as the Mac's Commanders list them:
/// whose they are, how long until they slip away, the last true thing they
/// told, plainly, and Question, once a watch, and Let go.
struct PrisonerRows: View {
    let session: CompanionSession
    let prisoner: CompanionLedger.Prisoner

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: prisoner.name)
                .font(Night.heading)
            Text(verbatim: "\(prisoner.of) · \(prisoner.held)")
                .font(Night.small)
                .foregroundStyle(Night.ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            if let told = prisoner.told {
                Text(verbatim: told)
                    .font(Night.small)
                    .foregroundStyle(Night.moon)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        HStack(spacing: 10) {
            if let question = prisoner.question {
                Button("Question") { session.give(question.command, told: question.title) }
                    .accessibilityLabel(question.title)
            }
            Button("Let go") { session.give(prisoner.release.command, told: prisoner.release.title) }
                .accessibilityLabel(prisoner.release.title)
        }
        .buttonStyle(.bordered)
        .font(Night.small)
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
            // Its Infirmary, while any lie in its beds.
            if let infirmary = hold.infirmary {
                Text(verbatim: infirmary)
                    .font(Night.small)
                    .foregroundStyle(Night.ink.opacity(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .accessibilityElement(children: .combine)
        if let heal = hold.heal {
            Button(heal.title) { session.give(heal.command, told: "\(heal.title) at \(hold.name)") }
                .buttonStyle(.bordered)
                .font(Night.small)
                .accessibilityLabel("\(heal.title) at \(hold.name)")
        }
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
