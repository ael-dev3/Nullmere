import NullmereCore
import SwiftUI

/// Whatever is selected: a hold with its works and musters, a company with
/// its orders, or a stretch of ground.
struct SelectionPanel: View {
    let session: GameSession

    var body: some View {
        Group {
            if let hold = session.selectedHold {
                if hold.owner == session.player {
                    OwnHoldPanel(session: session, hold: hold)
                } else {
                    ForeignHoldPanel(session: session, hold: hold)
                }
            } else if let unit = session.selectedUnit {
                UnitPanel(session: session, unit: unit)
            } else if case .tile(let hex) = session.selection {
                TilePanel(session: session, hex: hex)
            }
        }
        .frame(width: PanelWidth.record)
    }
}

/// A heading with an optional line beneath.
struct PanelTitle: View {
    let title: String
    var subtitle: String?
    var accent: Color = Palette.ink

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Caps(title, size: 12, weight: .medium, tracking: 0.3)
                .foregroundStyle(accent)
                .accessibilityAddTraits(.isHeader)
            if let subtitle {
                Text(verbatim: subtitle)
                    .font(.nm(11))
                    .foregroundStyle(Palette.text(0.6))
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

struct Meter: View {
    let fraction: Double
    var colour: Color = Palette.glow
    /// What it measures, where it stands alone: to VoiceOver it is then a
    /// level of that name, as full as it is drawn. Within a line that says
    /// it in words already, it has none, and is nothing to VoiceOver.
    var label: String?

    var body: some View {
        let full = min(max(fraction, 0), 1)
        let bar = Rectangle().fill(Palette.line(0.1))
            .overlay(alignment: .leading) {
                Rectangle().fill(colour).scaleEffect(x: full, y: 1, anchor: .leading)
            }
            .frame(height: 3)
        if let label {
            bar.accessibilityRepresentation { ProgressView(label, value: full) }
        } else {
            bar.accessibilityHidden(true)
        }
    }
}

// MARK: Holds

private struct OwnHoldPanel: View {
    let session: GameSession
    let hold: Hold

    var body: some View {
        // A work chosen in the city view: the panel opens on its row.
        ScrollViewReader { reader in
            ScrollView {
                OwnHoldDetails(session: session, hold: hold)
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .selection)
            .onAppear {
                if let work = session.workInFocus { reader.scrollTo(work, anchor: .center) }
            }
            .onChange(of: session.workInFocus) { _, work in
                if let work { withAnimation(.easeOut(duration: 0.3)) { reader.scrollTo(work, anchor: .center) } }
            }
        }
        .panelHeight(ChromeBudget.recordShare)
        .panelBackground()
    }
}

/// What the keeper's own hold panel scrolls through: its ward and yield, its
/// works and musters, and barter. Apart from its scroll view, so it can be
/// drawn on its own.
struct OwnHoldDetails: View {
    let session: GameSession
    let hold: Hold

    /// The works and the companies a hold musters, each folded to a line
    /// until asked for; the keeper's choice kept for every hold.
    @AppStorage(OwnHoldDetails.worksKey) private var worksOpen = false
    @AppStorage(OwnHoldDetails.companiesKey) private var companiesOpen = false
    static let worksKey = "hold.works.open"
    static let companiesKey = "hold.companies.open"
    /// What a hold by the lake does on the water, folded the same way.
    @AppStorage(OwnHoldDetails.waterKey) private var waterOpen = false
    static let waterKey = "hold.water.open"

    /// What a hold does by the water, in a line while it is folded: what
    /// its stone heard, if it heard anything, or what may be done there.
    static func waterSummary(of hold: Hold, in state: GameState, for house: Int) -> String {
        if let stone = state.stones(of: house).first(where: { $0.hold == hold.id }),
           state.soundings(heardBy: house).contains(where: { $0.stone == stone.id }) {
            return StoneRow.line(state, hold: hold, house: house)
        }
        var can: [String] = []
        if state.castingWater(beside: hold) != nil { can.append("words on the water") }
        if state.isShore(hold.position) || hold.position.spiral(1).contains(where: state.isShore) { can.append("a ripple-stone") }
        if state.stoneWater(before: hold) != nil {
            can.append(state.stones(of: house).contains { $0.hold == hold.id } ? "its listening stone" : "a listening stone")
        }
        return can.joined(separator: ", ").prefix(1).uppercased() + can.joined(separator: ", ").dropFirst() + "."
    }

    /// When a hold was raised: with the age, or in which watch since.
    static func raised(_ hold: Hold) -> String {
        hold.foundedWatch <= 1 ? "raised as the age opened" : "raised in the \(SeatBriefing.ordinal(hold.foundedWatch)) watch"
    }

    var body: some View {
        let state = session.state
        let stock = session.playerHouse.stock
        VStack(alignment: .leading, spacing: 14) {
            PanelTitle(
                title: hold.name,
                subtitle: (hold.isSeat ? "Seat of \(session.playerHouse.title)" : "A hold of \(session.playerHouse.title)")
                    + ", " + OwnHoldDetails.raised(hold),
                accent: Palette.houseWords(session.playerHouse)
            )

            VStack(alignment: .leading, spacing: 5) {
                HStack {
                    Caps("Ward", size: 8.5).foregroundStyle(Palette.text(0.5))
                    Spacer()
                    Text(verbatim: "\(hold.ward) / \(hold.maximumWard)")
                        .font(.nm(10.5).monospacedDigit())
                        .foregroundStyle(Palette.text(0.75))
                }
                .accessibilityElement(children: .combine)
                Meter(fraction: Double(hold.ward) / Double(max(hold.maximumWard, 1)), label: "Ward")
                // The House's veil, on its seat's record, or lying, on every hold's.
                if session.playerHouse.isPlayer, hold.isSeat || state.isVeiled(session.player) {
                    VeilLine(session: session)
                }
                HStack {
                    Caps("Yield each watch", size: 8.5).foregroundStyle(Palette.text(0.5))
                    Spacer()
                    CostLine(cost: state.income(of: hold), available: Stock(grain: .max, timber: .max, stone: .max, moonsalt: .max))
                }
                .accessibilityElement(children: .combine)
                // Only while it stands under its alliance's standards.
                if state.isOnAllianceLand(hold), let alliance = state.alliance(of: hold.owner) {
                    Text(verbatim: "On the land of \(alliance.name): +\(Standard.holdYield)% of all it yields")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.6))
                }
            }

            if let project = hold.project {
                ProgressLine(
                    title: "\(project.kind.title) \(Narration.roman(project.targetLevel))",
                    detail: project.watchesLeft == 1 ? "Done next watch" : "\(project.watchesLeft) watches left",
                    fraction: project.progress
                )
            }
            if let training = hold.training {
                // Trained, with no free ground within three tiles to
                // stand on, it waits there, and the hold trains no more.
                ProgressLine(
                    title: training.kind.hasTiers ? "\(training.kind.title) \(Narration.roman(training.tier ?? 1))" : training.kind.title,
                    detail: training.watchesLeft == 0 ? "Trained; waits for room to stand"
                        : training.watchesLeft == 1 ? "Ready next watch" : "\(training.watchesLeft) watches left",
                    fraction: 1 - Double(training.watchesLeft) / Double(max(state.trainingWatches(of: training.kind, tier: training.tier ?? 1, at: hold), 1))
                )
            }

            HoldItems(session: session, hold: hold)

            if hold.beds > 0 {
                InfirmaryRows(session: session, hold: hold, stock: stock)
            }

            Rule()
            // Open on a work chosen in the city view, or a charge's Show me.
            FoldedList(title: "Works", count: OwnHoldDetails.works(of: hold).count,
                       summary: OwnHoldDetails.worksSummary(of: hold, in: state, for: session.player),
                       open: $worksOpen, held: session.workInFocus != nil || session.beckon?.pointsAtWork == true) {
                ForEach(OwnHoldDetails.works(of: hold), id: \.self) { kind in
                    BuildingRow(session: session, hold: hold, kind: kind, stock: stock)
                        .padding(.horizontal, 4)
                        .background(RoundedRectangle(cornerRadius: 4).fill(session.workInFocus == kind ? Palette.line(0.08) : .clear))
                        .id(kind)
                }
            }

            Rule()
            FoldedList(title: "Companies", count: UnitKind.allCases.count,
                       summary: OwnHoldDetails.companiesSummary(of: hold, in: state, for: session.player),
                       open: $companiesOpen, held: session.beckon?.pointsAtTraining == true) {
                ForEach(UnitKind.allCases, id: \.self) { kind in
                    TrainingRow(session: session, hold: hold, kind: kind, stock: stock)
                }
            }

            Rule()
            BarterRow(session: session)
            // The pedlar, while he lies off this hold.
            if let pedlar = state.pedlar(for: session.player), pedlar.hold == hold.id {
                Rule()
                PedlarCard(session: session, pedlar: pedlar)
            }
            // A letter to the age to come, sealed under the hold's stones.
            LetterComposer(session: session, hold: hold)
            // What it does on the water, folded to a line until asked for:
            // what its stone heard, while it heard anything.
            let bottles = state.castingWater(beside: hold) != nil
            let ripples = state.isShore(hold.position) || hold.position.spiral(1).contains(where: state.isShore)
            let stone = state.stoneWater(before: hold) != nil
            let rows = [bottles, ripples, stone, ReflectionRow.shore(near: hold, in: state, for: session.player) != nil].filter { $0 }.count
            if rows > 0 {
                Rule()
                FoldedList(title: "By the water", count: rows, summary: OwnHoldDetails.waterSummary(of: hold, in: state, for: session.player),
                           open: $waterOpen) {
                    // Words set on the water, folded until asked for.
                    if bottles { BottleComposer(session: session, hold: hold) }
                    // A ripple-stone against the next Still Hour.
                    if ripples { RippleRow(session: session, hold: hold) }
                    // A false reflection for the lake to mirror at it.
                    if ReflectionRow.shore(near: hold, in: state, for: session.player) != nil || !state.falseReflections(of: session.player).isEmpty {
                        ReflectionRow(session: session, hold: hold)
                    }
                    // A listening stone in the lake before it, or the means to sink one.
                    if stone { StoneRow(session: session, hold: hold) }
                }
            }
        }
        .padding(16)
    }
}

/// A hold's Infirmary: its beds, the companies lying in them, and the
/// healing of those still waiting, for half what mustering them anew costs.
struct InfirmaryRows: View {
    let session: GameSession
    let hold: Hold
    let stock: Stock

    var body: some View {
        let wounded = hold.wounded ?? []
        let waiting = wounded.filter { !$0.healing }.count
        let refusal = session.state.refusal(of: .heal(hold: hold.id), as: session.player)
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Caps("Infirmary", size: 8.5).foregroundStyle(Palette.text(0.5))
                Spacer()
                Text(verbatim: "\(wounded.count) of \(hold.beds) beds")
                    .font(.nm(10.5).monospacedDigit())
                    .foregroundStyle(Palette.text(0.75))
            }
            .accessibilityElement(children: .combine)
            if !wounded.isEmpty {
                Text(verbatim: InfirmaryRows.lying(wounded))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.65))
                HStack(spacing: 10) {
                    if waiting > 0 {
                        CostLine(cost: session.state.healingCost(at: hold), available: stock)
                    }
                    Spacer()
                    QuietButton(title: waiting > 0 ? "Heal \(waiting)" : "Healing", size: 8.5, enabled: refusal == nil,
                                name: "Heal the wounded at \(hold.name)", why: refusal?.description) {
                        session.perform(.heal(hold: hold.id))
                    }
                }
            }
        }
    }

    /// Who lies in the beds, each with its tier, and those being healed,
    /// in the words the phone tells it in too.
    static func lying(_ wounded: [Wounded]) -> String { Wounded.lying(wounded) }
}

private struct ProgressLine: View {
    let title: String
    let detail: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Caps(title, size: 9.5, weight: .medium).foregroundStyle(Palette.glowWords)
                Spacer()
                Text(verbatim: detail).font(.nm(10.5)).foregroundStyle(Palette.text(0.65))
            }
            Meter(fraction: fraction)
        }
        .accessibilityElement(children: .combine)
    }
}

private struct BuildingRow: View {
    let session: GameSession
    let hold: Hold
    let kind: BuildingKind
    let stock: Stock

    var body: some View {
        let level = hold.level(kind)
        let next = level + 1
        HStack(alignment: .top, spacing: 8) {
            // The work as it stands, or as its next stage will.
            Portrait(key: .work(kind, level: min(max(level, next), kind.maxLevel)),
                     colour: Portrait.colour(of: hold.owner, in: session.state), size: 34)
            details(level: level, next: next)
        }
        .padding(.vertical, 2)
    }

    @ViewBuilder
    private func details(level: Int, next: Int) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                // The work and how far it stands, read as one.
                HStack(alignment: .firstTextBaseline) {
                    Caps(kind.title, size: 9.5, weight: .medium).foregroundStyle(Palette.text(0.9))
                    LevelPips(level: level, maximum: kind.maxLevel)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                if next <= kind.maxLevel {
                    let cost = session.state.buildCost(of: kind, toLevel: next, for: session.player)
                    QuietButton(title: "Build \(Narration.roman(next))", size: 8.5,
                                enabled: hold.project == nil && stock.covers(cost),
                                name: "Build \(kind.title) \(Narration.roman(next))",
                                why: hold.project != nil ? "A work is already rising here."
                                    : CostLine.shortfall(of: cost, from: stock).map { "You are \($0)." }) {
                        session.perform(.build(hold: hold.id, kind: kind))
                    }
                    .beckoned(session.beckon == .work(kind))
                }
            }
            if next <= kind.maxLevel {
                // What the next stage does, costs and takes, read as one.
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: kind.effect(atLevel: next, isSeat: hold.isSeat))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.55))
                    FlowLayout(spacing: 10, lineSpacing: 3) {
                        CostLine(cost: session.state.buildCost(of: kind, toLevel: next, for: session.player), available: stock)
                        Text(verbatim: "\(session.state.buildWatches(of: kind, toLevel: next, for: session.player)) watches")
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.45))
                    }
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(verbatim: "Complete").font(.nm(10.5)).foregroundStyle(Palette.text(0.45))
            }
        }
    }
}

struct LevelPips: View {
    let level: Int
    let maximum: Int

    var body: some View {
        HStack(spacing: 3) {
            ForEach(0..<maximum, id: \.self) { index in
                Circle()
                    .fill(index < level ? Palette.glow : Palette.line(0.15))
                    .frame(width: 4, height: 4)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Level \(level) of \(maximum)")
        .accessibilityAddTraits(.isStaticText)
    }
}

private struct TrainingRow: View {
    let session: GameSession
    let hold: Hold
    let kind: UnitKind
    let stock: Stock
    /// The tier asked for, if not the highest the hold can muster.
    @State private var chosen: Int?

    var body: some View {
        let state = session.state
        let highest = state.highestTier(of: kind, at: hold, for: session.player)
        let tier = min(chosen ?? highest, highest)
        let allowed = hold.level(.musterHall) >= kind.requiredMuster
        let cost = state.trainingCost(of: kind, tier: tier, for: session.player)
        let named = kind.hasTiers ? "\(kind.title) \(Narration.roman(tier))" : kind.title
        HStack(alignment: .top, spacing: 8) {
            Portrait(key: .company(kind, tier: tier, heritage: state.heritage(of: hold.owner)), colour: Portrait.colour(of: hold.owner, in: state), size: 34)
            details(state: state, highest: highest, tier: tier, allowed: allowed, cost: cost, named: named)
        }
    }

    @ViewBuilder
    private func details(state: GameState, highest: Int, tier: Int, allowed: Bool, cost: Stock, named: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                // The company and what it is worth, read as one.
                HStack(alignment: .firstTextBaseline) {
                    Caps(named, size: 9.5, weight: .medium).foregroundStyle(Palette.text(allowed ? 0.9 : 0.4))
                    Text(verbatim: kind.isMilitary ? "\(kind.attack(tier: tier)) attack · \(kind.defense(tier: tier)) defence · \(kind.movement) moves"
                         : "\(kind.movement) moves")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.45))
                }
                .accessibilityElement(children: .combine)
                Spacer()
                if allowed, highest > 1 {
                    // The tiers its Muster Hall and studies open, the highest first chosen.
                    Picker("Tier of \(kind.title)", selection: Binding(get: { tier }, set: { chosen = $0 })) {
                        ForEach(1...highest, id: \.self) { Text(verbatim: "Tier \(Narration.roman($0))").tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 84)
                }
                QuietButton(title: "Train", size: 8.5, enabled: allowed && hold.training == nil && stock.covers(cost),
                            name: "Train \(named)",
                            why: !allowed ? "Needs a Muster Hall \(Narration.roman(kind.requiredMuster))."
                                : hold.training != nil ? "A company is already training here."
                                : CostLine.shortfall(of: cost, from: stock).map { "You are \($0)." }) {
                    session.perform(.train(hold: hold.id, kind: kind, tier: tier > 1 ? tier : nil))
                }
                .beckoned(session.beckon == .train(kind) || (session.beckon == .train(nil) && kind.isMilitary))
            }
            if allowed {
                // What training it costs and takes, read as one.
                HStack(spacing: 10) {
                    CostLine(cost: cost, available: stock)
                    let watches = state.trainingWatches(of: kind, tier: tier, at: hold)
                    Text(verbatim: "\(watches) watch\(watches == 1 ? "" : "es")")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.45))
                }
                .accessibilityElement(children: .combine)
            } else {
                Text(verbatim: "Needs a Muster Hall \(Narration.roman(kind.requiredMuster))")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.4))
            }
        }
    }
}

/// Trade a surplus for what is lacking, three to one, moonsalt counted as
/// three of any other store.
struct BarterRow: View {
    let session: GameSession

    @State private var give: Resource = .grain
    @State private var take: Resource = .timber
    @State private var amount = 20

    /// Why a barter would be refused, as the realm would refuse it; nil when
    /// it would be carried out.
    static func problem(give: Resource, take: Resource, amount: Int, stock: Stock, room: Int) -> String? {
        GameState.barterProblem(give: give, take: take, amount: amount, stock: stock, room: room)
    }

    var body: some View {
        let price = take.barterCost(of: amount, paidIn: give)
        let stock = session.playerHouse.stock
        let problem = BarterRow.problem(give: give, take: take, amount: amount, stock: stock, room: session.ledger.room)
        VStack(alignment: .leading, spacing: 8) {
            Caps("Barter", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
            HStack(spacing: 8) {
                Picker("Take", selection: $take) {
                    ForEach(Resource.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 96)
                AmountField(name: "Amount to take", amount: $amount, most: Stock.cap, step: 10)
                Text(verbatim: "for").font(.nm(10.5)).foregroundStyle(Palette.text(0.5))
                Picker("Give", selection: $give) {
                    ForEach(Resource.allCases, id: \.self) { Text($0.title).tag($0) }
                }
                .labelsHidden()
                .frame(width: 96)
            }
            HStack {
                Text(verbatim: problem ?? "Costs \(price) \(give.title.lowercased())")
                    .font(.nm(10.5))
                    .foregroundStyle(problem == nil ? Palette.text(0.6) : Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
                Spacer()
                QuietButton(title: "Barter", size: 8.5, enabled: problem == nil) {
                    session.perform(.barter(give: give, take: take, amount: amount))
                }
            }
        }
    }
}

struct ForeignHoldPanel: View {
    let session: GameSession
    let hold: Hold
    /// Watches a rally called against it gathers before it sets out.
    @State private var gathering = 2

    var body: some View {
        let owner = session.state.houses[hold.owner]
        let stance = session.state.stance(session.player, owner.id)
        VStack(alignment: .leading, spacing: 10) {
            PanelTitle(title: hold.name, subtitle: (hold.isSeat ? "Seat of " : "A hold of ") + owner.title + ", " + OwnHoldDetails.raised(hold),
                       accent: Palette.houseWords(owner))
            HStack {
                Caps(stance.title, size: 9, weight: .medium).foregroundStyle(stance == .war ? Palette.bad : Palette.text(0.7))
                Spacer()
                if session.isVisible(hold.position) {
                    Text(verbatim: "Ward \(hold.ward) / \(hold.maximumWard)").font(.nm(10.5)).foregroundStyle(Palette.text(0.6))
                } else {
                    Text(verbatim: "Out of sight").font(.nm(10.5)).foregroundStyle(Palette.text(0.45))
                }
            }
            if session.state.isVeiled(owner.id), let veil = session.state.veil(of: owner.id) {
                Text(verbatim: "Veiled until watch \(veil.until): none may strike, rally on or scout its holds.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.glowWords)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if hold.level(.moonspire) > 0 {
                Text(verbatim: "Its Moonspire rises: stage \(hold.level(.moonspire)) of \(BuildingKind.moonspire.maxLevel).")
                    .font(.nm(11))
                    .foregroundStyle(Palette.glowWords)
            }
            Text(verbatim: stance == .war
                 ? "Break its ward with Spears, Riders or Bows; Spears or Riders take it once the ward falls."
                 : "You are not at war. Declare war in Houses to march on it.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
            if stance == .war, session.state.alliance(of: session.player) != nil {
                rally
            }
            scouting
        }
        .padding(16)
        .panelBackground()
    }

    /// The nearest of the keeper's Lanterns within reach of it with moves
    /// left, which would scout it.
    static func scout(for hold: Hold, in state: GameState, player: Int) -> Unit? {
        state.units(of: player)
            .filter { $0.kind == .lantern && $0.movesLeft > 0 && $0.position.distance(to: hold.position) <= GameState.scoutReach }
            .min { ($0.position.distance(to: hold.position), $0.id) < ($1.position.distance(to: hold.position), $1.id) }
    }

    /// Scouting it with Lanterns near it, and what they last saw there.
    @ViewBuilder
    private var scouting: some View {
        let scout = ForeignHoldPanel.scout(for: hold, in: session.state, player: session.player)
        Rule(opacity: 0.18)
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: scout == nil ? "Lanterns within two tiles of it can scout it." : "Your Lanterns stand near enough to scout it.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            QuietButton(title: "Scout", size: 8.5, enabled: scout != nil, name: "Scout \(hold.name)",
                        why: scout == nil ? "No Lanterns of yours stand within two tiles of it with moves left." : nil) {
                if let scout { session.perform(.scout(unit: scout.id, hold: hold.id)) }
            }
        }
        if let seen = session.scoutings[hold.id],
           let report = session.state.report(of: seen, id: 0, for: session.player) {
            VStack(alignment: .leading, spacing: 3) {
                Caps("Scouted at watch \(seen.watch)", size: 8.5, weight: .medium).foregroundStyle(Palette.text(0.6))
                ForEach(report.lines, id: \.self) { line in
                    Text(verbatim: line).font(.nm(10.5)).foregroundStyle(Palette.text(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .accessibilityElement(children: .combine)
        }
    }

    /// A rally against it: the alliance's companies gather at the keeper's
    /// hold with a Muster Hall nearest it, and strike it together.
    @ViewBuilder
    private var rally: some View {
        let state = session.state
        let muster = state.holds(of: session.player).filter { $0.level(.musterHall) >= 1 }
            .min { ($0.position.distance(to: hold.position), $0.id) < ($1.position.distance(to: hold.position), $1.id) }
        Rule(opacity: 0.18)
        if let muster {
            let command = Command.callRally(from: muster.id, against: hold.id, watches: gathering)
            let refusal = state.refusal(of: command, as: session.player)
            Text(verbatim: "Call your alliance to gather at \(muster.name) and strike \(hold.name) together.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Picker("Watches to gather", selection: $gathering) {
                    ForEach(Array(Rally.gatherings), id: \.self) { Text(verbatim: "Gather \($0) watch\($0 == 1 ? "" : "es")").tag($0) }
                }
                .labelsHidden()
                .frame(width: 140)
                Spacer()
                QuietButton(title: "Call a rally", size: 8.5, enabled: refusal == nil, name: "Call a rally against \(hold.name)",
                            why: refusal?.description) {
                    session.perform(command)
                }
            }
        } else {
            Text(verbatim: "A rally gathers at a hold of yours with a Muster Hall.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.5))
        }
    }
}

// MARK: Units

struct UnitPanel: View {
    let session: GameSession
    let unit: Unit

    /// Where a company marches, as a keeper would say it: to a hold by its
    /// name, into ground not yet seen, or simply on, and how far; and when
    /// it should be there, when the realm has worked it out.
    static func march(of unit: Unit, in state: GameState, viewer: Int) -> String? {
        guard let destination = unit.destination else { return nil }
        let distance = unit.position.distance(to: destination)
        let away = "\(distance) tile\(distance == 1 ? "" : "s")"
        let there = arrival(of: unit, in: state).map { ", there \($0)" } ?? ""
        if let hold = state.hold(at: destination) {
            return "Marching to \(hold.name), \(away) away\(there)."
        }
        let explored = state.houses.indices.contains(viewer) ? state.houses[viewer].explored : []
        if let index = state.map.index(of: destination), explored.indices.contains(index), !explored[index] {
            return "Marching into the dark, \(away) away\(there)."
        }
        return "Marching, \(away) to go\(there)."
    }

    /// When a company on the march should be where it is bound, as the
    /// realm worked it out for the keeper: "as the watch turns", or "in 3
    /// watches"; nil when it isn't known.
    static func arrival(of unit: Unit, in state: GameState) -> String? {
        guard unit.destination != nil, let arrives = state.marches?.first(where: { $0.unit == unit.id })?.arrives else { return nil }
        let watches = arrives - state.watch
        return watches <= 1 ? "as the watch turns" : "in \(watches) watches"
    }

    var body: some View {
        let state = session.state
        let owner = state.houses[unit.owner]
        let mine = unit.owner == session.player
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(
                title: unit.rank > 0 ? "\(Unit.rankTitles[unit.rank]) \(state.title(of: unit))" : state.title(of: unit),
                subtitle: mine ? (unit.kind.isMilitary ? veterancy(of: unit) : nil) : owner.title,
                accent: Palette.houseWords(owner)
            )
            HStack(spacing: 14) {
                Stat(label: "Health", value: "\(unit.health)")
                if unit.kind.isMilitary {
                    Stat(label: "Attack", value: "\(unit.kind.attack * state.attackPercent(of: unit) / 100)")
                    Stat(label: "Defence", value: "\(unit.kind.defense * state.defensePercent(of: unit) / 100)")
                }
                if unit.kind.hasTiers {
                    Stat(label: "Tier", value: Narration.roman(unit.tier))
                }
                if mine {
                    Stat(label: "Moves", value: "\(unit.movesLeft)/\(state.movement(of: unit))")
                }
            }
            Meter(fraction: Double(unit.health) / 100, colour: unit.health > 50 ? Palette.good : Palette.bad, label: "Health")
            Text(verbatim: UnitPanel.troopsLine(unit, in: state))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
            if mine, let drill = UnitPanel.drillLine(unit, in: state) {
                Text(verbatim: drill)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }

            if let words = UnitPanel.leader(of: unit, in: state) {
                Text(verbatim: words)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.glowWords)
                    .fixedSize(horizontal: false, vertical: true)
            }
            if mine, let errand = UnitPanel.errand(of: unit, in: state) {
                Text(verbatim: errand)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.75))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if mine {
                if let hint = hint(for: unit) {
                    Text(verbatim: hint)
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.55))
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Its orders wrap rather than run off the panel.
                FlowLayout(spacing: 4) {
                    if unit.kind == .founder {
                        let problem = state.canFound(at: unit.position, for: session.player)
                        QuietButton(title: "Found a hold", prominent: problem == nil, enabled: problem == nil) {
                            session.perform(.found(unit: unit.id))
                        }
                        .beckoned(session.beckon == .found)
                        .help(problem.map { String(describing: $0) } ?? "Raise a new hold here")
                    }
                    if unit.kind == .lantern, let target = UnitPanel.scoutable(by: unit, in: state, player: session.player) {
                        QuietButton(title: "Scout", prominent: unit.movesLeft > 0, enabled: unit.movesLeft > 0, name: "Scout \(target.name)",
                                    why: unit.movesLeft > 0 ? nil : "They have no moves left this watch.") {
                            session.perform(.scout(unit: unit.id, hold: target.id))
                        }
                    }
                    // Only on the Still's shore, and only for a company of war.
                    if unit.kind.isMilitary, state.isOnTheStill(unit.position) {
                        let refusal = state.mirrorRefusal(unit.id, as: session.player)
                        QuietButton(title: "Walk the mirror", enabled: refusal == nil, name: "Walk the mirror with \(unit.kind.title)",
                                    why: refusal?.description) {
                            session.perform(.walkTheMirror(unit: unit.id))
                        }
                        .help(UnitPanel.mirrorHelp(state.mirrorLanding(from: unit.position, for: unit.id)))
                    }
                    QuietButton(title: unit.fortified ? "Fortified" : "Fortify", enabled: !unit.fortified && unit.movesLeft > 0) {
                        session.perform(.fortify(unit: unit.id))
                    }
                    if unit.kind.hasTiers {
                        let drilling = state.isDrilling(unit), refusal = state.drillRefusal(of: unit)
                        QuietButton(title: drilling ? "Drilling" : "Drill", enabled: !drilling && refusal == nil,
                                    name: drilling ? "Drilling at the Muster Hall" : "Drill at the Muster Hall",
                                    why: drilling ? nil : refusal.map { String(describing: $0) }) {
                            session.perform(.drill(unit: unit.id))
                        }
                        .beckoned(session.beckon == .drill && refusal == nil && !drilling)
                    }
                    if unit.destination != nil {
                        QuietButton(title: "Halt") { session.perform(.halt(unit: unit.id)) }
                    }
                    // Out at the land's work: home with what it carries, or every gatherer at once.
                    if state.isOutGathering(unit) {
                        QuietButton(title: "Bring home", name: "Bring them home with what they carry") {
                            session.perform(.recall(unit: unit.id))
                        }
                        if state.units(of: session.player).filter(state.isOutGathering).count > 1 {
                            QuietButton(title: "All home", name: "Bring every gatherer home") { session.perform(.recallAll) }
                        }
                    }
                    if unit.kind.isMilitary {
                        QuietButton(title: unit.leader == nil ? "Commander" : "Commanders",
                                    name: unit.leader == nil ? "Set a commander at their head" : "Open the Commanders") {
                            session.panel = .commanders
                        }
                    }
                    ConfirmButton(title: "Disband", confirm: "Disband them?", size: 10) { session.perform(.disband(unit: unit.id)) }
                }
                // At a shore hold of the House's: across the lake by barge
                // to another, offered only where it may be.
                let landings = state.ferryLandings(for: unit.id, as: session.player)
                if !landings.isEmpty || state.crossing(of: unit.id) != nil {
                    FerryLine(session: session, unit: unit, landings: landings)
                }
                // How long it works its site, chosen as it was sent, or again.
                if case .gather? = unit.errand {
                    GatheringLength(session: session, unit: unit)
                }
                // The House's other gatherers, folded until asked for.
                if state.isOutGathering(unit) {
                    GathererList(session: session)
                }
            }
        }
        .padding(16)
        .panelBackground()
    }

    /// The nearest hold of another House within a Lantern's reach, which it
    /// would scout.
    static func scoutable(by unit: Unit, in state: GameState, player: Int) -> Hold? {
        state.holds.filter { $0.owner != player && $0.position.distance(to: unit.position) <= GameState.scoutReach }
            .min { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
    }

    /// Its troops: how many stand of its whole muster.
    static func troopsLine(_ unit: Unit, in state: GameState) -> String {
        "\(GameState.counted(state.troops(of: unit))) of \(GameState.counted(state.fullMuster(of: unit))) troops standing"
    }

    /// How its drill stands: what the hall drills into it as each watch
    /// turns, and for what, or how many it may lead.
    static func drillLine(_ unit: Unit, in state: GameState) -> String? {
        guard unit.kind.hasTiers else { return nil }
        let capacity = GameState.counted(state.drillCapacity(of: unit))
        if state.isDrilling(unit), let hold = state.drillHold(for: unit) {
            let troops = min(state.drillCapacity(of: unit) - state.fullMuster(of: unit), state.drillRate(of: unit, hall: hold.level(.musterHall)))
            return "Drilling: \(GameState.counted(troops)) more as the watch turns, for \(state.drillCost(of: unit, troops: troops)); it may lead \(capacity)."
        }
        if state.fullMuster(of: unit) >= state.drillCapacity(of: unit) {
            return "It musters as many as it may lead, \(capacity); a higher Muster Hall or a commander would lead more."
        }
        return "It may lead \(capacity), drilled at or beside one of your holds with a Muster Hall."
    }

    /// The commander at a company's head, as its panel says it.
    static func leader(of unit: Unit, in state: GameState) -> String? {
        guard let id = unit.leader, let commander = state.commander(id) else { return nil }
        return "Led by \(commander.name), \(commander.archetype.named) of level \(commander.level)"
    }

    /// What a company has been sent to do beyond its march, and what it carries.
    static func errand(of unit: Unit, in state: GameState) -> String? {
        // In a field of battle: it fights on at every pace where it stands.
        if let field = state.field(of: unit.id), let fighter = field.fighter(unit.id) {
            let foe = fighter.foe.flatMap { state.unit($0) }
            let whose = foe.map { state.houses.indices.contains($0.owner) ? "\(state.houses[$0.owner].title)'s \($0.kind.title)" : $0.kind.title }
            func side(_ side: Int) -> String {
                let (companies, troops) = field.inField(side)
                return "\(companies == 1 ? "1 company" : "\(companies) companies"), \(GameState.counted(troops)) troops"
            }
            return "In battle \(state.placeName(of: field.at)) against \(whose ?? "the foe"): its side \(side(fighter.side)), "
                + "the other \(side(1 - fighter.side)). It fights on at every pace until it draws off."
        }
        let load = unit.load.flatMap { carried -> String? in
            guard let store = Resource.allCases.first(where: { carried[$0] > 0 }) else { return nil }
            return "\(carried[store]) \(store.title.lowercased())"
        }
        switch unit.errand {
        case .gather(let siteID)?:
            let site = state.site(siteID).map { "the \(HoverInfo.named($0, in: state))" } ?? "a site of the land"
            let carrying = load.map { ", carrying \($0)" } ?? ""
            // At its site, when it will be full; on its way, bound there.
            if let left = state.watchesToFill(unit) {
                // Sent for fewer watches than would fill it, it turns for home first.
                let ends = unit.gatherFor.map { $0 <= left } == true ? "home" : "full"
                return "Gathering at \(site)\(carrying): \(ends) " + (left <= 1 ? "as the watch turns." : "in \(left) watches.")
            }
            return (unit.destination == nil ? "Gathering at " : "Bound to gather at ") + site + carrying + "."
        case .homeward?:
            return "Bringing \(load ?? "its load") home."
        case .rally(let id)?:
            let target = state.rally(id).flatMap { state.targetName($0.target) }.map { " against \($0)" } ?? ""
            return "Sent to the rally\(target)."
        case .reinforce(let holdID)?:
            return "Keeping the gates of \(state.hold(holdID)?.name ?? "an ally's hold")."
        case nil:
            return load.map { "Carrying \($0)." }
        }
    }

    private func veterancy(of unit: Unit) -> String {
        let next = Unit.rankThresholds.first { $0 > unit.experience }
        let bonus = unit.rank * Unit.rankBonus
        let now = bonus > 0 ? "+\(bonus)% attack and defence" : "Untried"
        guard let next else { return now + " · the highest rank" }
        let left = next - unit.experience
        return now + " · \(left) more battle\(left == 1 ? "" : "s") to rise"
    }

    /// Where it marches, and while the first steps are taught, how to order
    /// it; the Guide keeps the how after.
    private func hint(for unit: Unit) -> String? {
        let teaching = session.firstSteps != nil
        if let march = UnitPanel.march(of: unit, in: session.state, viewer: session.player) {
            return march + (teaching ? " Right-click elsewhere to change course." : "")
        }
        guard teaching else { return nil }
        switch unit.kind {
        case .founder: return "Right-click to march. Found a hold on open land three tiles from any other."
        case .lantern: return "Right-click to march into the dark and reveal it. Lanterns see far, and scout another House's hold from two tiles."
        case .bow: return "Right-click to march, to strike an enemy or the wilds up to two tiles away, or to gather at a site."
        case .mangonel: return "Right-click to march, or to hurl stones at an enemy hold, standard or hall up to two tiles away: thrice as hard on walls and wards as any other company."
        default: return "Right-click to march, to strike an enemy or the wilds beside you, or to gather at a site."
        }
    }
}

private struct Stat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(verbatim: value).font(.nm(14, weight: .light).monospacedDigit()).foregroundStyle(Palette.ink)
            Caps(label, size: 7.5).foregroundStyle(Palette.text(0.45))
        }
        .accessibilityElement(children: .combine)
    }
}

// MARK: Ground

/// A lair of the wilds on the map: what still stands of it, what falls
/// with it, and a rally called against it from the keeper's hold with a
/// Muster Hall nearest it.
struct LairRally: View {
    let session: GameSession
    let lair: Lair
    /// Watches the rally gathers before it sets out.
    @State private var gathering = 2

    /// What it is, and how it breaks: a lair of the wilds, too strong for
    /// any company alone; or a gate of the Crown, which any company may
    /// strike.
    static func about(_ lair: Lair) -> String {
        let wilds = lair.kind.title.hasPrefix("the ") ? String(lair.kind.title.dropFirst(4)) : lair.kind.title
        guard lair.gate == nil else {
            return "A gate of the Crown, held by \(wilds): any company of war may strike it, from beside it or with arrows from its reach, "
                + "or a rally's host together. Broken, it lies open to all for the season, gives up \(lair.spoils), and counts "
                + "\(FrontierState.gatePoints) for your kingdom at the Frontier."
        }
        return "A lair of \(wilds), too strong for any company alone; a rally's host, striking together, can break it. Broken, it gives up "
            + "\(lair.spoils), shared by the companies each House brought, and gear for the rally's caller."
    }

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 6) {
            Caps(lair.gate == nil ? "The \(lair.title) \(Narration.roman(lair.level))" : "The \(lair.title) of the Crown", size: 9.5,
                 weight: .medium).foregroundStyle(Palette.bad)
            Text(verbatim: LairRally.about(lair))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Caps("Standing", size: 8.5).foregroundStyle(Palette.text(0.5))
                Spacer()
                Text(verbatim: "\(lair.strength) / \(lair.might)").font(.nm(10.5).monospacedDigit()).foregroundStyle(Palette.text(0.75))
            }
            .accessibilityElement(children: .combine)
            Meter(fraction: Double(lair.strength) / Double(max(lair.might, 1)), label: "What stands of it")
            if let muster = LairRally.muster(for: lair, in: state, player: session.player) {
                let command = Command.callRally(from: muster.id, against: lair.id, watches: gathering)
                let refusal = state.refusal(of: command, as: session.player)
                Text(verbatim: "Call your alliance to gather at \(muster.name) and break it together.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Picker("Watches to gather", selection: $gathering) {
                        ForEach(Array(Rally.gatherings), id: \.self) { Text(verbatim: "Gather \($0) watch\($0 == 1 ? "" : "es")").tag($0) }
                    }
                    .labelsHidden()
                    .frame(width: 140)
                    Spacer()
                    QuietButton(title: "Call a rally", size: 8.5, enabled: refusal == nil, name: "Call a rally against the \(lair.title)",
                                why: refusal?.description) {
                        session.perform(command)
                    }
                }
            } else {
                Text(verbatim: "A rally gathers at a hold of yours with a Muster Hall.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.5))
            }
        }
    }

    /// The keeper's hold with a Muster Hall nearest a lair, where a rally
    /// against it would gather.
    static func muster(for lair: Lair, in state: GameState, player: Int) -> Hold? {
        state.holds(of: player).filter { $0.level(.musterHall) >= 1 }
            .min { ($0.position.distance(to: lair.position), $0.id) < ($1.position.distance(to: lair.position), $1.id) }
    }
}

/// The House's items that work on a hold, offered on its own panel: an
/// hourglass while it has work or a muster under way, a ward stone while
/// its ward is broken.
struct HoldItems: View {
    let session: GameSession
    let hold: Hold

    var body: some View {
        let hourglasses = session.state.items(.hourglass, of: session.player)
        let stones = session.state.items(.wardStone, of: session.player)
        if hourglasses > 0, hold.project != nil || hold.training != nil {
            row(.hourglass, title: "Hasten",
                text: "\(ItemKind.hourglass.counted(hourglasses)) in your satchel: one brings this hold's work and muster a watch nearer.")
        }
        if stones > 0, hold.ward < hold.maximumWard {
            row(.wardStone, title: "Make the ward whole",
                text: "\(ItemKind.wardStone.counted(stones)) in your satchel: one makes this hold's ward whole.")
        }
    }

    private func row(_ kind: ItemKind, title: String, text: String) -> some View {
        let command = Command.useItem(kind, hold: hold.id)
        let refusal = session.state.refusal(of: command, as: session.player)
        return HStack(alignment: .firstTextBaseline) {
            Text(verbatim: text)
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            QuietButton(title: title, size: 8.5, enabled: refusal == nil, name: "Use a \(kind.title) at \(hold.name)", why: refusal?.description) {
                session.perform(command)
            }
        }
    }
}

/// Raising a standard of the keeper's alliance on open ground, for its
/// cost, or why it can't be raised there.
struct StandardRow: View {
    let session: GameSession
    let hex: Hex

    var body: some View {
        let state = session.state
        let refusal = state.refusal(of: .raiseStandard(at: hex), as: session.player)
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "Raise a standard of your alliance here: the land two tiles about it becomes the alliance's.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                CostLine(cost: Standard.cost, available: state.purse(of: session.player))
                Spacer()
                QuietButton(title: "Raise a standard", size: 8.5, enabled: refusal == nil, name: "Raise a standard of your alliance here",
                            why: refusal?.description) {
                    session.perform(.raiseStandard(at: hex))
                }
            }
        }
    }
}

/// Lending a hand to the keeper's alliance's rising standard: a watch
/// sooner, for timber and stone, once each House; or why it can't.
struct StandardHelpRow: View {
    let session: GameSession
    let standard: Standard

    var body: some View {
        let state = session.state
        let refusal = state.refusal(of: .helpStandard(standard: standard.id), as: session.player)
        let left = Standard.raising - (standard.built ?? Standard.raising)
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "It rises, whole in \(left) watch\(left == 1 ? "" : "es"); its land is the alliance's only once it stands.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                CostLine(cost: Standard.helpCost, available: state.purse(of: session.player))
                Spacer()
                QuietButton(title: "Lend a hand", size: 8.5, enabled: refusal == nil, name: "Lend a hand to raise this standard a watch sooner",
                            why: refusal?.description) {
                    session.perform(.helpStandard(standard: standard.id))
                }
            }
        }
    }
}

/// Beginning the keeper's alliance's hall on its land, for its cost, or
/// why it can't be begun there: offered to the alliance's leader on the
/// alliance's land while it has none.
struct HallRow: View {
    let session: GameSession
    let hex: Hex

    /// Whether the row is offered on a hex: to the leader, on the
    /// alliance's land, while the alliance has no hall.
    static func offered(at hex: Hex, to house: Int, of alliance: Alliance, in state: GameState) -> Bool {
        alliance.leader == house && state.hall(of: alliance.id) == nil && state.allianceLand(at: hex) == alliance.id
    }

    var body: some View {
        let state = session.state
        let refusal = state.refusal(of: .raiseAllianceHall(at: hex), as: session.player)
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "Begin your alliance's hall here. It rises over \(AllianceHall.raising) watches; whole, the land "
                 + "\(AllianceHall.reach) tiles about it is the alliance's, its keepers stand a quarter firmer, your alliance's rallies "
                 + "take \(AllianceHall.rallyCompanies) more companies and it may keep \(AllianceHall.standards) more standards.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                CostLine(cost: AllianceHall.cost, available: state.purse(of: session.player))
                Spacer()
                QuietButton(title: "Begin the hall", size: 8.5, enabled: refusal == nil, name: "Begin your alliance's hall here",
                            why: refusal?.description) {
                    session.perform(.raiseAllianceHall(at: hex))
                }
            }
        }
    }
}

/// Raising the keeper's alliance's storehouse on its land, for its cost,
/// or why it can't be raised there: offered to the alliance's leader on
/// the alliance's land while it has none.
struct StorehouseRow: View {
    let session: GameSession
    let hex: Hex

    /// Whether the row is offered on a hex: to the leader, on the
    /// alliance's land, while the alliance has no storehouse.
    static func offered(at hex: Hex, to house: Int, of alliance: Alliance, in state: GameState) -> Bool {
        alliance.leader == house && state.storehouse(of: alliance.id) == nil && state.allianceLand(at: hex) == alliance.id
    }

    var body: some View {
        let state = session.state
        let refusal = state.refusal(of: .raiseStorehouse(at: hex), as: session.player)
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "Raise your alliance's storehouse here. It rises over \(Storehouse.raising) watches; whole, each of its Houses "
                 + "may lay up to \(Storehouse.room) there, beyond its own storage and out of any taker's reach.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                CostLine(cost: Storehouse.cost, available: state.purse(of: session.player))
                Spacer()
                QuietButton(title: "Raise the storehouse", size: 8.5, enabled: refusal == nil, name: "Raise your alliance's storehouse here",
                            why: refusal?.description) {
                    session.perform(.raiseStorehouse(at: hex))
                }
            }
        }
    }
}

/// Raising a yard of the keeper's alliance on its land, of a store it has
/// none of yet, for its cost, or why it can't be raised there: offered to
/// the alliance's leader on the alliance's land.
struct YardRow: View {
    let session: GameSession
    let hex: Hex
    /// The stores the alliance has no yard of.
    let stores: [Resource]

    /// The stores a yard may be raised of on a hex: to the leader, on the
    /// alliance's land, those it has none of.
    static func stores(at hex: Hex, for house: Int, of alliance: Alliance, in state: GameState) -> [Resource] {
        guard alliance.leader == house, state.allianceLand(at: hex) == alliance.id else { return [] }
        let raised = Set(state.yards(of: alliance.id).map(\.store))
        return Resource.allCases.filter { !raised.contains($0) }
    }

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "Raise a yard here: your alliance's companies alone work it, \(Yard.gathering)% faster, and its coffers take a "
                 + "tithe of what they gather.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            CostLine(cost: Yard.cost, available: state.purse(of: session.player))
            FlowLayout(spacing: 4) {
                ForEach(stores, id: \.self) { store in
                    let refusal = state.refusal(of: .raiseYard(store, at: hex), as: session.player)
                    let yard = Yard.title(of: store).lowercased()
                    QuietButton(title: "A \(yard)", size: 8.5, enabled: refusal == nil, name: "Raise a \(yard) here", why: refusal?.description) {
                        session.perform(.raiseYard(store, at: hex))
                    }
                }
            }
        }
    }
}

struct TilePanel: View {
    let session: GameSession
    let hex: Hex

    /// What the record says of ground that yields nothing.
    static func bare(_ terrain: Terrain, river: Atlas.River?) -> String {
        switch terrain {
        case .still: return "Nothing lives in the Still, and nothing grows."
        case .shallows: return "Nothing lives in the shallows, and nothing grows; they can be waded."
        case .ford:
            return "The lake's bed, laid bare along the moon's road while the moon is full: walked a step a move, "
                + "and nothing raised on it. The water comes back over it as the moon wanes, and carries whoever stands on it ashore."
        case .stream: return stream(river, cold: true)
        case .shoal: return stream(river, cold: false)
        case .strand, .saltFlat, .greyfield, .blackwood, .barrow, .spine: return "Bare ground."
        }
    }

    /// What the record says of a stream, or of a shoal across it: its name,
    /// how far it runs and where it is crossed.
    static func stream(_ river: Atlas.River?, cold: Bool) -> String {
        let name = river.map { $0.name.prefix(1).uppercased() + $0.name.dropFirst() } ?? "The stream"
        let steps = river?.course.count ?? 0
        let run = steps > 0 ? ", \(steps) steps from the Spine to the lake," : ""
        return cold ? "\(name) runs cold and quick between steep banks\(run) and no company wades it: it is crossed at its shoals."
            : "\(name) runs wide and shallow over stones here: a ford, waded a step at two moves, and a poor place to stand and fight."
    }

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 10) {
            if session.isExplored(hex), let tile = state.map[hex] {
                PanelTitle(title: tile.terrain.title, subtitle: tile.feature?.title)
                let yield = tile.yield
                if yield.isZero {
                    Text(verbatim: TilePanel.bare(tile.terrain, river: state.atlas?.river(at: hex)))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.55))
                } else {
                    HStack {
                        Caps("Yields", size: 8.5).foregroundStyle(Palette.text(0.5))
                        Spacer()
                        CostLine(cost: yield, available: Stock(grain: .max, timber: .max, stone: .max, moonsalt: .max))
                    }
                }
                // A hold of an age before, drowned here.
                if let drowned = state.drowned(at: hex) {
                    Text(verbatim: drowned.told(searched: tile.feature != .drownedRuin))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.glowWords)
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Letters of the age before that lie here, unread or found.
                ForEach(state.lettersOfOld.filter { $0.at == hex }, id: \.id) { letter in
                    Text(verbatim: letter.told(in: state))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.glowWords)
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack {
                    Caps("Moves", size: 8.5).foregroundStyle(Palette.text(0.5))
                    Spacer()
                    Text(verbatim: tile.terrain.isPassable ? "\(tile.terrain.moveCost)" : "Impassable")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.7))
                }
                if tile.terrain.defenseBonus != 0 {
                    HStack {
                        Caps("Defence", size: 8.5).foregroundStyle(Palette.text(0.5))
                        Spacer()
                        Text(verbatim: "\(tile.terrain.defenseBonus > 0 ? "+" : "")\(tile.terrain.defenseBonus)%")
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.7))
                    }
                }
                if let owner = state.territoryOwner(of: hex) {
                    Text(verbatim: "Land of \(state.houses[owner].title)")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.houseWords(state.houses[owner]))
                }
                if let wild = state.wild(at: hex) {
                    Rule(opacity: 0.18)
                    Caps(HoverInfo.named(wild), size: 9.5, weight: .medium).foregroundStyle(Palette.bad)
                    Text(verbatim: "A company of the wilds, every House's foe. Strike it with a company of war beside it; "
                         + "struck down, it gives up \(wild.spoils.description).")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                if let lair = state.lair(at: hex) {
                    Rule(opacity: 0.18)
                    LairRally(session: session, lair: lair)
                }
                if let hall = state.hall(at: hex) {
                    Rule(opacity: 0.18)
                    Caps("The hall of \(state.alliance(hall.alliance)?.name ?? "a fallen alliance")", size: 9.5, weight: .medium)
                        .foregroundStyle(Palette.glowWords)
                    Text(verbatim: HoverInfo.described(hall, in: state))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                } else if let storehouse = state.storehouse(at: hex) {
                    Rule(opacity: 0.18)
                    Caps("The storehouse of \(state.alliance(storehouse.alliance)?.name ?? "a fallen alliance")", size: 9.5, weight: .medium)
                        .foregroundStyle(Palette.glowWords)
                    Text(verbatim: HoverInfo.described(storehouse, in: state))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                } else if let standard = state.standard(at: hex) {
                    Rule(opacity: 0.18)
                    Caps("A standard of \(state.alliance(standard.alliance)?.name ?? "a fallen alliance")", size: 9.5, weight: .medium)
                        .foregroundStyle(Palette.glowWords)
                    Text(verbatim: "Raised by \(state.houses.indices.contains(standard.raisedBy) ? state.houses[standard.raisedBy].title : "a fallen House"); "
                         + (standard.isWhole ? "" : "rising, ") + "its ward \(standard.ward) of \(Standard.maximumWard). The land two tiles about it is the alliance's: its companies "
                         + "there stand a tenth firmer, mend sooner and gather a fifth more.")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    // Rising: a hand from the keeper's House, if it can give one.
                    if !standard.isWhole, state.alliance(of: session.player)?.id == standard.alliance {
                        StandardHelpRow(session: session, standard: standard)
                    }
                } else if let sworn = state.alliance(of: session.player) {
                    Rule(opacity: 0.18)
                    StandardRow(session: session, hex: hex)
                    if HallRow.offered(at: hex, to: session.player, of: sworn, in: state) {
                        HallRow(session: session, hex: hex)
                    }
                    if StorehouseRow.offered(at: hex, to: session.player, of: sworn, in: state) {
                        StorehouseRow(session: session, hex: hex)
                    }
                    let stores = YardRow.stores(at: hex, for: session.player, of: sworn, in: state)
                    if !stores.isEmpty, state.site(at: hex) == nil {
                        YardRow(session: session, hex: hex, stores: stores)
                    }
                }
                // The House's own land: its seat may be raised anew here.
                if SeatMoveRow.offered(at: hex, in: state, player: session.player) {
                    Rule(opacity: 0.18)
                    SeatMoveRow(session: session, hex: hex)
                }
                if let site = state.site(at: hex) {
                    Rule(opacity: 0.18)
                    Caps(SelectionPanel.siteTitle(site, in: state), size: 9.5, weight: .medium).foregroundStyle(Palette.glowWords)
                    Text(verbatim: SelectionPanel.siteLine(site, in: state))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            } else {
                PanelTitle(title: "Unknown", subtitle: "Send Lanterns to see what lies here.")
            }
        }
        .padding(16)
        .panelBackground()
    }
}

extension SelectionPanel {
    /// A site's name in its panel: the land's, with its level; an
    /// alliance's yard, with whose it is.
    static func siteTitle(_ site: Site, in state: GameState) -> String {
        guard let yard = site.alliance else { return site.title + " " + Narration.roman(site.level) }
        return "\(site.title) of \(state.alliance(yard)?.name ?? "an alliance")"
    }

    /// What is left in a site, and who may work it.
    static func siteLine(_ site: Site, in state: GameState) -> String {
        let left = "\(site.remaining) \(site.store.title.lowercased()) left to gather."
        guard site.isYard else { return left + " Choose a company of war and right-click here to send it." }
        return left + " Only its alliance's companies work it, \(Yard.gathering)% faster than anywhere else, and its coffers take a "
            + "tithe besides. Choose a company of war of the alliance and right-click here to send it."
    }
}

/// A keeper's veil of the Still, on the seat's record: lying, and until
/// when; resting, and when it may be drawn again; or to draw, for moonsalt.
struct VeilLine: View {
    let session: GameSession

    /// How the House's veil stands, in a line, in the words the phone tells
    /// it in too.
    static func words(_ state: GameState, house: Int) -> String { state.veilSaid(of: house) }

    var body: some View {
        let state = session.state, me = session.player
        let refusal = state.veilRefusal(as: me)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Text(verbatim: VeilLine.words(state, house: me))
                .font(.nm(10))
                .foregroundStyle(state.isVeiled(me) ? Palette.glowWords : Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 4)
            if !state.isVeiled(me) {
                QuietButton(title: "Draw the veil", size: 8.5, enabled: refusal == nil, name: "Draw the veil of the Still over your holds",
                            why: refusal?.description) {
                    session.perform(.drawVeil)
                }
            }
        }
        .padding(.top, 2)
    }
}

/// Raising the keeper's seat anew on a tile of the House's own land, for
/// its cost, or why it can't be raised there: Rise of Kingdoms' teleport,
/// within the House's land.
struct SeatMoveRow: View {
    let session: GameSession
    let hex: Hex

    /// Offered to a keeper on settleable ground of their House's own land
    /// that no hold stands on.
    static func offered(at hex: Hex, in state: GameState, player: Int) -> Bool {
        guard state.houses.indices.contains(player), state.houses[player].isPlayer, state.hold(at: hex) == nil,
              state.map[hex]?.terrain.isSettleable == true else { return false }
        return state.territoryOwner(of: hex) == player
    }

    var body: some View {
        let state = session.state
        let refusal = state.seatMoveRefusal(to: hex, as: session.player)
        VStack(alignment: .leading, spacing: 5) {
            Text(verbatim: "Raise your seat anew here: its works, walls and ward as they stand, and the company at its gates with it. "
                 + "Once in \(GameState.seatMoveRest) watches, and never while it is beset.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                CostLine(cost: GameState.seatMoveCost, available: session.playerHouse.stock)
                Spacer()
                QuietButton(title: "Raise the seat here", size: 8.5, enabled: refusal == nil, name: "Raise your seat anew here",
                            why: refusal?.description) {
                    session.perform(.raiseSeat(at: hex))
                }
            }
        }
    }
}


/// A company at a shore hold: poled across the still water to another of
/// the House's shore holds, landing as the watch turns.
struct FerryLine: View {
    let session: GameSession
    let unit: Unit
    let landings: [Hold]

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 5) {
            if let barge = state.crossing(of: unit.id) {
                Text(verbatim: "On the water for \(state.hold(barge.to)?.name ?? "the far shore"); they land as the watch turns.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                HStack {
                    Text(verbatim: "Across the lake")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                    Spacer()
                    CostLine(cost: GameState.ferryCost, available: session.playerHouse.stock)
                }
                ForEach(landings.prefix(4), id: \.id) { hold in
                    let refusal = state.ferryRefusal(unit.id, to: hold.id, as: session.player)
                    QuietButton(title: "To \(hold.name)", size: 8.5, enabled: refusal == nil,
                                name: "Ferry them across the lake to \(hold.name)", why: refusal?.description) {
                        session.perform(.ferry(unit: unit.id, to: hold.id))
                    }
                }
            }
        }
    }
}

/// A listening stone in the lake before a hold: what it heard as the watch
/// last turned, or the button that sinks one. Its House's alone to see.
struct StoneRow: View {
    let session: GameSession
    let hold: Hold

    static func line(_ state: GameState, hold: Hold, house: Int) -> String {
        guard let stone = state.stones(of: house).first(where: { $0.hold == hold.id }) else {
            return "A listening stone, \(GameState.stoneCost), sunk in the lake here hears marches out of sight within \(GameState.stoneReach) tiles."
        }
        let heard = state.soundings(heardBy: house).filter { $0.stone == stone.id }
        guard !heard.isEmpty else {
            return stone.listening ? "The stone in the water here heard nothing move last watch." : "The stone in the water here begins to listen."
        }
        let quarters = Array(Set(heard.map(\.quarter))).sorted().map { Sounding.quarters[$0] }
        return "The stone heard \(heard.count == 1 ? "a march" : "\(heard.count) marches") out of sight, "
            + "\(heard.contains(where: \.near) ? "near" : "far off"), to the \(quarters.joined(separator: " and "))."
    }

    var body: some View {
        let state = session.state
        let sunk = state.stones(of: session.player).contains { $0.hold == hold.id }
        let refusal = state.stoneRefusal(before: hold.id, as: session.player)
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: StoneRow.line(state, hold: hold, house: session.player))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.65))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if !sunk {
                QuietButton(title: "Sink a stone", size: 8.5, enabled: refusal == nil, name: "Sink a listening stone before \(hold.name)",
                            why: refusal?.description) {
                    session.perform(.sinkStone(hold: hold.id))
                }
            }
        }
    }
}

/// A ripple-stone cast from a hold on the shore: at the next Still Hour the
/// lake mirrors none of the House's companies; one a Still Hour.
struct RippleRow: View {
    let session: GameSession
    let hold: Hold

    static func line(_ state: GameState, house: Int) -> String {
        let next = GameState.nextStillHour(from: state.watch + 1) - state.watch
        if state.hasRippled(house) { return "Your stone stirs the water: the next Still Hour, in \(next) watches, mirrors none of yours." }
        return "The lake lies still in \(next) watches and shows all on its shore. A stone, \(GameState.rippleCost), hides yours."
    }

    var body: some View {
        let refusal = session.state.rippleRefusal(from: hold.id, as: session.player)
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: RippleRow.line(session.state, house: session.player))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.65))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if !session.state.hasRippled(session.player) {
                QuietButton(title: "Cast a stone", size: 8.5, enabled: refusal == nil, name: "Cast a ripple-stone from \(hold.name)",
                            why: refusal?.description) {
                    session.perform(.castRipple(hold: hold.id))
                }
            }
        }
    }
}

/// The Pedlar of the Still lying off a hold: his three wares, each with
/// its price and a button to buy it, while it is unsold.
struct PedlarCard: View {
    let session: GameSession
    let pedlar: Pedlar

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Caps("The Pedlar of the Still", size: 9, weight: .medium).foregroundStyle(Palette.text(0.75))
                Spacer()
                Text(verbatim: "Poles away in \(max(1, pedlar.came + Pedlar.stays - state.watch)) watch\(pedlar.came + Pedlar.stays - state.watch == 1 ? "" : "es")")
                    .font(.nm(9.5)).foregroundStyle(Palette.text(0.5))
            }
            ForEach(pedlar.wares) { ware in
                let refusal = state.buyRefusal(ware.id, as: session.player)
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 1) {
                        Text(verbatim: ware.goods.title).font(.nm(10.5)).foregroundStyle(Palette.text(ware.sold ? 0.45 : 0.85))
                        Text(verbatim: ware.sold ? "Sold" : "For \(ware.price)").font(.nm(9.5)).foregroundStyle(Palette.text(0.55))
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    if !ware.sold {
                        QuietButton(title: "Buy", size: 8.5, enabled: refusal == nil, name: "Buy \(ware.goods.title) of the pedlar",
                                    why: refusal?.description) {
                            session.perform(.buyFromPedlar(ware: ware.id))
                        }
                    }
                }
            }
        }
    }
}

/// A false reflection cast from a hold on its nearest free shore: at the
/// next Still Hour the lake mirrors a company of the House's there that
/// is not.
struct ReflectionRow: View {
    let session: GameSession
    let hold: Hold

    /// The nearest shore within reach where none stands and none is cast.
    static func shore(near hold: Hold, in state: GameState, for house: Int) -> Hex? {
        let cast = Set(state.falseReflections(of: house).map(\.at))
        return hold.position.spiral(GameState.falseReflectionReach)
            .filter { state.isShore($0) && state.unit(at: $0) == nil && state.hold(at: $0) == nil && !cast.contains($0) }
            .min { ($0.distance(to: hold.position), $0.q, $0.r) < ($1.distance(to: hold.position), $1.q, $1.r) }
    }

    static func line(_ state: GameState, house: Int) -> String {
        let cast = state.falseReflections(of: house).count
        let next = GameState.nextStillHour(from: state.watch + 1) - state.watch
        if cast > 0 { return "\(cast) false reflection\(cast == 1 ? "" : "s") wait for the Still Hour, in \(next) watches." }
        return "For \(GameState.falseReflectionCost), the lake will mirror a company of yours on this shore at the Still Hour, though none is there."
    }

    var body: some View {
        let state = session.state
        let at = ReflectionRow.shore(near: hold, in: state, for: session.player)
        let refusal = at.map { state.reflectionRefusal(from: hold.id, at: $0, kind: .spear, as: session.player) } ?? .notOnTheShore
        HStack(alignment: .firstTextBaseline) {
            Text(verbatim: ReflectionRow.line(state, house: session.player))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.65))
                .fixedSize(horizontal: false, vertical: true)
            Spacer()
            if let at {
                QuietButton(title: "Cast a reflection", size: 8.5, enabled: refusal == nil, name: "Cast a false reflection on the shore by \(hold.name)",
                            why: refusal?.description) {
                    session.perform(.castReflection(hold: hold.id, at: at, kind: .spear))
                }
            }
        }
    }
}

extension UnitPanel {
    /// What the mirror's button says of where the walk comes out.
    static func mirrorHelp(_ landing: Hex?) -> String {
        guard let landing else { return "The Still shows no open ground on the far shore." }
        return "Step into the Still for \(MirrorWalk.price) and come out at \(landing) as the watch turns; every shore sees the water still there."
    }
}
