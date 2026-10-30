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
        .frame(width: 330)
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
        ScrollView {
            OwnHoldDetails(session: session, hold: hold)
        }
        .scrollEdgeFade()
        .scrollIndicators(.never)
        .pagedByKeys(session, as: .selection)
        .frame(maxHeight: 640)
        .panelBackground()
    }
}

/// What the keeper's own hold panel scrolls through: its ward and yield, its
/// works and musters, and barter. Apart from its scroll view, so it can be
/// drawn on its own.
struct OwnHoldDetails: View {
    let session: GameSession
    let hold: Hold

    var body: some View {
        let state = session.state
        let stock = session.playerHouse.stock
        VStack(alignment: .leading, spacing: 14) {
            PanelTitle(
                title: hold.name,
                subtitle: hold.isSeat ? "Seat of \(session.playerHouse.title)" : "A hold of \(session.playerHouse.title)",
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
                HStack {
                    Caps("Yield each watch", size: 8.5).foregroundStyle(Palette.text(0.5))
                    Spacer()
                    CostLine(cost: state.income(of: hold), available: Stock(grain: .max, timber: .max, stone: .max, moonsalt: .max))
                }
                .accessibilityElement(children: .combine)
            }

            if let project = hold.project {
                ProgressLine(
                    title: "\(project.kind.title) \(Narration.roman(project.targetLevel))",
                    detail: project.watchesLeft == 1 ? "Done next watch" : "\(project.watchesLeft) watches left",
                    fraction: 1 - Double(project.watchesLeft) / Double(project.kind.buildWatches(toLevel: project.targetLevel))
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

            if hold.beds > 0 {
                InfirmaryRows(session: session, hold: hold, stock: stock)
            }

            Rule()
            Caps("Works", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
            ForEach(BuildingKind.allCases, id: \.self) { kind in
                if !kind.requiresSeat || hold.isSeat {
                    BuildingRow(session: session, hold: hold, kind: kind, stock: stock)
                }
            }

            Rule()
            Caps("Companies", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
            ForEach(UnitKind.allCases, id: \.self) { kind in
                TrainingRow(session: session, hold: hold, kind: kind, stock: stock)
            }

            Rule()
            BarterRow(session: session)
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

    /// Who lies in the beds, each with its tier, and those being healed.
    static func lying(_ wounded: [Wounded]) -> String {
        wounded.map { company in
            let tier = company.kind.hasTiers ? " \(Narration.roman(company.tier))" : ""
            return company.kind.title + tier + (company.healing ? ", healing" : "")
        }.joined(separator: " · ")
    }
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
                    HStack(spacing: 10) {
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
            Portrait(key: .figure(kind, tier: tier), colour: Portrait.colour(of: hold.owner, in: state), size: 34)
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
        if give == take { return "Choose two different stores." }
        let price = take.barterCost(of: amount, paidIn: give)
        if stock[give] < price { return "You have only \(stock[give]) \(give.title.lowercased())." }
        if stock[take] + amount > room { return "No room to store that much \(take.title.lowercased())." }
        return nil
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
            PanelTitle(title: hold.name, subtitle: (hold.isSeat ? "Seat of " : "A hold of ") + owner.title, accent: Palette.houseWords(owner))
            HStack {
                Caps(stance.title, size: 9, weight: .medium).foregroundStyle(stance == .war ? Palette.bad : Palette.text(0.7))
                Spacer()
                if session.isVisible(hold.position) {
                    Text(verbatim: "Ward \(hold.ward) / \(hold.maximumWard)").font(.nm(10.5)).foregroundStyle(Palette.text(0.6))
                } else {
                    Text(verbatim: "Out of sight").font(.nm(10.5)).foregroundStyle(Palette.text(0.45))
                }
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
    /// name, into ground not yet seen, or simply on, and how far.
    static func march(of unit: Unit, in state: GameState, viewer: Int) -> String? {
        guard let destination = unit.destination else { return nil }
        let distance = unit.position.distance(to: destination)
        let away = "\(distance) tile\(distance == 1 ? "" : "s")"
        if let hold = state.hold(at: destination) {
            return "Marching to \(hold.name), \(away) away."
        }
        let explored = state.houses.indices.contains(viewer) ? state.houses[viewer].explored : []
        if let index = state.map.index(of: destination), explored.indices.contains(index), !explored[index] {
            return "Marching into the dark, \(away) away."
        }
        return "Marching, \(away) to go."
    }

    var body: some View {
        let state = session.state
        let owner = state.houses[unit.owner]
        let mine = unit.owner == session.player
        VStack(alignment: .leading, spacing: 12) {
            PanelTitle(
                title: unit.rank > 0 ? "\(Unit.rankTitles[unit.rank]) \(unit.kind.title)" : unit.kind.title,
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
                Text(verbatim: hint(for: unit))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 4) {
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
                    QuietButton(title: unit.fortified ? "Fortified" : "Fortify", enabled: !unit.fortified && unit.movesLeft > 0) {
                        session.perform(.fortify(unit: unit.id))
                    }
                    if unit.destination != nil {
                        QuietButton(title: "Halt") { session.perform(.halt(unit: unit.id)) }
                    }
                    if unit.kind.isMilitary {
                        QuietButton(title: unit.leader == nil ? "Commander" : "Commanders",
                                    name: unit.leader == nil ? "Set a commander at their head" : "Open the Commanders") {
                            session.panel = .commanders
                        }
                    }
                    ConfirmButton(title: "Disband", confirm: "Disband them?", size: 10) { session.perform(.disband(unit: unit.id)) }
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

    /// The commander at a company's head, as its panel says it.
    static func leader(of unit: Unit, in state: GameState) -> String? {
        guard let id = unit.leader, let commander = state.commander(id) else { return nil }
        return "Led by \(commander.name), \(commander.archetype.named) of level \(commander.level)"
    }

    /// What a company has been sent to do beyond its march, and what it carries.
    static func errand(of unit: Unit, in state: GameState) -> String? {
        // Locked in battle: it fights on through the watch where it stands.
        if let battle = state.battlesJoined.first(where: { $0.attacker == unit.id || $0.defender == unit.id }) {
            let foe = state.unit(battle.attacker == unit.id ? battle.defender : battle.attacker)
            let whose = foe.map { state.houses.indices.contains($0.owner) ? "\(state.houses[$0.owner].title)'s \($0.kind.title)" : $0.kind.title }
            let blows = battle.rounds == 1 ? "one more exchange" : "\(battle.rounds) more exchanges"
            return "Locked in battle with \(whose ?? "the foe"): \(blows) of blows this watch, unless one side draws off."
        }
        let load = unit.load.flatMap { carried -> String? in
            guard let store = Resource.allCases.first(where: { carried[$0] > 0 }) else { return nil }
            return "\(carried[store]) \(store.title.lowercased())"
        }
        switch unit.errand {
        case .gather(let siteID)?:
            let site = state.site(siteID).map { "the \(HoverInfo.named($0))" } ?? "a site of the land"
            return "Gathering at \(site)" + (load.map { ", carrying \($0)" } ?? "") + "."
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

    private func hint(for unit: Unit) -> String {
        if let march = UnitPanel.march(of: unit, in: session.state, viewer: session.player) {
            return march + " Right-click elsewhere to change course."
        }
        switch unit.kind {
        case .founder: return "Right-click to march. Found a hold on open land three tiles from any other."
        case .lantern: return "Right-click to march into the dark and reveal it. Lanterns see far, and scout another House's hold from two tiles."
        case .bow: return "Right-click to march, to strike an enemy or the wilds up to two tiles away, or to gather at a site."
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

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 6) {
            Caps("The \(lair.title) \(Narration.roman(lair.level))", size: 9.5, weight: .medium).foregroundStyle(Palette.bad)
            Text(verbatim: "A lair of \(lair.kind.title.hasPrefix("the ") ? String(lair.kind.title.dropFirst(4)) : lair.kind.title), "
                 + "too strong for any company alone; a rally's host, striking together, can break it. Broken, it gives up "
                 + "\(lair.spoils), shared by the companies each House brought, and gear for the rally's caller.")
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
                CostLine(cost: Standard.cost, available: state.houses[session.player].stock)
                Spacer()
                QuietButton(title: "Raise a standard", size: 8.5, enabled: refusal == nil, name: "Raise a standard of your alliance here",
                            why: refusal?.description) {
                    session.perform(.raiseStandard(at: hex))
                }
            }
        }
    }
}

private struct TilePanel: View {
    let session: GameSession
    let hex: Hex

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 10) {
            if session.isExplored(hex), let tile = state.map[hex] {
                PanelTitle(title: tile.terrain.title, subtitle: tile.feature?.title)
                let yield = tile.yield
                if yield.isZero {
                    Text(verbatim: tile.terrain == .still ? "Nothing lives in the Still, and nothing grows."
                                   : tile.terrain == .shallows ? "Nothing lives in the shallows, and nothing grows; they can be waded." : "Bare ground.")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.55))
                } else {
                    HStack {
                        Caps("Yields", size: 8.5).foregroundStyle(Palette.text(0.5))
                        Spacer()
                        CostLine(cost: yield, available: Stock(grain: .max, timber: .max, stone: .max, moonsalt: .max))
                    }
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
                if let standard = state.standard(at: hex) {
                    Rule(opacity: 0.18)
                    Caps("A standard of \(state.alliance(standard.alliance)?.name ?? "a fallen alliance")", size: 9.5, weight: .medium)
                        .foregroundStyle(Palette.glowWords)
                    Text(verbatim: "Raised by \(state.houses.indices.contains(standard.raisedBy) ? state.houses[standard.raisedBy].title : "a fallen House"); "
                         + "its ward \(standard.ward) of \(Standard.maximumWard). The land two tiles about it is the alliance's: its companies "
                         + "there stand a tenth firmer, mend sooner and gather a fifth more.")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                } else if state.alliance(of: session.player) != nil {
                    Rule(opacity: 0.18)
                    StandardRow(session: session, hex: hex)
                }
                if let site = state.site(at: hex) {
                    Rule(opacity: 0.18)
                    Caps(site.title + " " + Narration.roman(site.level), size: 9.5, weight: .medium).foregroundStyle(Palette.glowWords)
                    Text(verbatim: "\(site.remaining) \(site.store.title.lowercased()) left to gather. "
                         + "Choose a company of war and right-click here to send it.")
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
