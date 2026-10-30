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

    var body: some View {
        // What it measures is said beside it in words: to VoiceOver it is
        // nothing.
        Rectangle().fill(Palette.line(0.1))
            .overlay(alignment: .leading) {
                Rectangle().fill(colour).scaleEffect(x: min(max(fraction, 0), 1), y: 1, anchor: .leading)
            }
            .frame(height: 3)
            .accessibilityHidden(true)
    }
}

// MARK: Holds

private struct OwnHoldPanel: View {
    let session: GameSession
    let hold: Hold

    var body: some View {
        let state = session.state
        let stock = session.playerHouse.stock
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                PanelTitle(
                    title: hold.name,
                    subtitle: hold.isSeat ? "Seat of \(session.playerHouse.title)" : "A hold of \(session.playerHouse.title)",
                    accent: Palette.house(session.playerHouse)
                )

                VStack(alignment: .leading, spacing: 5) {
                    HStack {
                        Caps("Ward", size: 8.5).foregroundStyle(Palette.text(0.5))
                        Spacer()
                        Text(verbatim: "\(hold.ward) / \(hold.maximumWard)")
                            .font(.nm(10.5).monospacedDigit())
                            .foregroundStyle(Palette.text(0.75))
                    }
                    Meter(fraction: Double(hold.ward) / Double(max(hold.maximumWard, 1)))
                    HStack {
                        Caps("Yield each watch", size: 8.5).foregroundStyle(Palette.text(0.5))
                        Spacer()
                        CostLine(cost: state.income(of: hold), available: Stock(grain: .max, timber: .max, stone: .max, moonsalt: .max))
                    }
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
                        title: training.kind.title,
                        detail: training.watchesLeft == 0 ? "Trained; waits for room to stand"
                            : training.watchesLeft == 1 ? "Ready next watch" : "\(training.watchesLeft) watches left",
                        fraction: 1 - Double(training.watchesLeft) / Double(training.kind.trainWatches)
                    )
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
        .scrollEdgeFade()
        .scrollIndicators(.never)
        .frame(maxHeight: 640)
        .panelBackground()
    }
}

private struct ProgressLine: View {
    let title: String
    let detail: String
    let fraction: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Caps(title, size: 9.5, weight: .medium).foregroundStyle(Palette.glow)
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
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Caps(kind.title, size: 9.5, weight: .medium).foregroundStyle(Palette.text(0.9))
                LevelPips(level: level, maximum: kind.maxLevel)
                Spacer()
                if next <= kind.maxLevel {
                    QuietButton(title: "Build \(Narration.roman(next))", size: 8.5,
                                enabled: hold.project == nil && stock.covers(kind.cost(toLevel: next))) {
                        session.perform(.build(hold: hold.id, kind: kind))
                    }
                }
            }
            if next <= kind.maxLevel {
                Text(verbatim: kind.effect(atLevel: next, isSeat: hold.isSeat))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                HStack(spacing: 10) {
                    CostLine(cost: kind.cost(toLevel: next), available: stock)
                    Text(verbatim: "\(kind.buildWatches(toLevel: next)) watches")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.45))
                }
            } else {
                Text(verbatim: "Complete").font(.nm(10.5)).foregroundStyle(Palette.text(0.45))
            }
        }
        .padding(.vertical, 2)
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

    var body: some View {
        let allowed = hold.level(.musterHall) >= kind.requiredMuster
        let cost = session.state.trainingCost(of: kind, for: session.player)
        VStack(alignment: .leading, spacing: 4) {
            HStack(alignment: .firstTextBaseline) {
                Caps(kind.title, size: 9.5, weight: .medium).foregroundStyle(Palette.text(allowed ? 0.9 : 0.4))
                Text(verbatim: kind.isMilitary ? "\(kind.attack) attack · \(kind.defense) defence · \(kind.movement) moves" : "\(kind.movement) moves")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.45))
                Spacer()
                QuietButton(title: "Train", size: 8.5, enabled: allowed && hold.training == nil && stock.covers(cost)) {
                    session.perform(.train(hold: hold.id, kind: kind))
                }
            }
            if allowed {
                HStack(spacing: 10) {
                    CostLine(cost: cost, available: stock)
                    let watches = hold.trainingWatches(for: kind)
                    Text(verbatim: "\(watches) watch\(watches == 1 ? "" : "es")")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.45))
                }
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
                Stepper(value: $amount, in: 10...500, step: 10) {
                    Text(verbatim: "\(amount)").font(.nm(11).monospacedDigit())
                }
                .accessibilityLabel("Amount to take")
                .accessibilityValue("\(amount)")
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

private struct ForeignHoldPanel: View {
    let session: GameSession
    let hold: Hold

    var body: some View {
        let owner = session.state.houses[hold.owner]
        let stance = session.state.stance(session.player, owner.id)
        VStack(alignment: .leading, spacing: 10) {
            PanelTitle(title: hold.name, subtitle: (hold.isSeat ? "Seat of " : "A hold of ") + owner.title, accent: Palette.house(owner))
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
                    .foregroundStyle(Palette.glow)
            }
            Text(verbatim: stance == .war
                 ? "Break its ward with Spears, Riders or Bows; Spears or Riders take it once the ward falls."
                 : "You are not at war. Declare war in Houses to march on it.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(16)
        .panelBackground()
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
                accent: Palette.house(owner)
            )
            HStack(spacing: 14) {
                Stat(label: "Health", value: "\(unit.health)")
                if unit.kind.isMilitary {
                    Stat(label: "Attack", value: "\(unit.kind.attack)")
                    Stat(label: "Defence", value: "\(unit.kind.defense)")
                }
                if mine {
                    Stat(label: "Moves", value: "\(unit.movesLeft)/\(unit.kind.movement)")
                }
            }
            Meter(fraction: Double(unit.health) / 100, colour: unit.health > 50 ? Palette.good : Palette.bad)

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
                        .help(problem.map { String(describing: $0) } ?? "Raise a new hold here")
                    }
                    QuietButton(title: unit.fortified ? "Fortified" : "Fortify", enabled: !unit.fortified && unit.movesLeft > 0) {
                        session.perform(.fortify(unit: unit.id))
                    }
                    if unit.destination != nil {
                        QuietButton(title: "Halt") { session.perform(.halt(unit: unit.id)) }
                    }
                    ConfirmButton(title: "Disband", confirm: "Disband them?", size: 10) { session.perform(.disband(unit: unit.id)) }
                }
            }
        }
        .padding(16)
        .panelBackground()
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
        case .lantern: return "Right-click to march into the dark and reveal it. Lanterns see far."
        case .bow: return "Right-click to march, or to strike an enemy up to two tiles away."
        default: return "Right-click to march, or to strike an enemy beside you."
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
                        .foregroundStyle(Palette.house(state.houses[owner]))
                }
            } else {
                PanelTitle(title: "Unknown", subtitle: "Send Lanterns to see what lies here.")
            }
        }
        .padding(16)
        .panelBackground()
    }
}
