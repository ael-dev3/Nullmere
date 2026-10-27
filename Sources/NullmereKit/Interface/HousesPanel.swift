import NullmereCore
import SwiftUI

/// The other Houses around the lake: how they stand with the player, how
/// strong they are, and what can be said to them.
struct HousesPanel: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Houses", subtitle: "\(state.livingHouses.count) still stand around the lake")
                CloseButton { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    RaceTable(session: session)
                    Rule(opacity: 0.18)
                    ForEach(state.houses.filter { $0.id != session.player }) { house in
                        HouseRow(session: session, house: house)
                        Rule(opacity: 0.18)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(width: 360)
        .frame(maxHeight: 620)
        .panelBackground()
    }
}

/// Who is nearest to winning, by either road: holds toward dominion, and
/// stages of the Moonspire toward ascendancy.
struct RaceTable: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caps("The race for the lake", size: 8.5, weight: .medium).foregroundStyle(Palette.ink.opacity(0.7))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)
                Spacer(minLength: 4)
                Caps("Holds of \(state.dominionNeed)", size: 7.5).foregroundStyle(Palette.ink.opacity(0.45))
                    .frame(width: 92, alignment: .leading)
                Caps("Spire", size: 7.5).foregroundStyle(Palette.ink.opacity(0.45))
                    .frame(width: 44, alignment: .leading)
            }
            ForEach(state.standings(), id: \.house) { standing in
                let house = state.houses[standing.house]
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1).fill(Palette.house(house)).frame(width: 3, height: 10)
                    Text(verbatim: standing.house == session.player ? "You" : house.name)
                        .font(.nm(10.5, weight: standing.house == session.player ? .medium : .regular))
                        .foregroundStyle(standing.threat == nil ? Palette.ink.opacity(0.8) : (standing.house == session.player ? Palette.good : Palette.bad))
                        .lineLimit(1)
                    if standing.isVassal {
                        Caps("Sworn", size: 7).foregroundStyle(Palette.ink.opacity(0.4))
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        Meter(fraction: Double(standing.dominionPercent) / 100,
                              colour: standing.threat == .dominion ? Palette.bad : Palette.glow)
                            .frame(width: 60)
                        Text(verbatim: "\(standing.realm)").font(.nm(10).monospacedDigit()).foregroundStyle(Palette.ink.opacity(0.7))
                    }
                    .frame(width: 92, alignment: .leading)
                    LevelPips(level: standing.spire, maximum: BuildingKind.moonspire.maxLevel)
                        .frame(width: 44, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(RaceTable.spoken(standing, in: state, player: session.player))
            }
        }
    }

    static func spoken(_ standing: Standing, in state: GameState, player: Int) -> String {
        let who = standing.house == player ? "You" : state.houses[standing.house].title
        var line = "\(who): \(standing.realm) of \(standing.needed) holds for dominion, Moonspire stage \(standing.spire) of \(BuildingKind.moonspire.maxLevel)"
        if standing.isVassal { line += ", sworn to another" }
        if standing.threat != nil { line += ", near victory" }
        return line + "."
    }
}

struct HouseRow: View {
    @State private var words = ""
    @State private var trading = false
    let session: GameSession
    let house: House

    init(session: GameSession, house: House) {
        self.session = session
        self.house = house
    }

    var body: some View {
        let state = session.state
        let player = session.player
        let stance = state.stance(player, house.id)
        let relation = state.relation(player, house.id)
        let spire = state.seat(of: house.id)?.level(.moonspire) ?? 0
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.house(house))
                    .frame(width: 3, height: 12)
                Caps(house.title, size: 10.5, weight: .medium)
                    .foregroundStyle(house.isEliminated ? Palette.ink.opacity(0.35) : Palette.ink)
                Spacer()
                if house.isEliminated {
                    Caps("Fallen", size: 8.5).foregroundStyle(Palette.ink.opacity(0.4))
                } else {
                    Caps(stance.title, size: 8.5, weight: .medium)
                        .foregroundStyle(stance == .war ? Palette.bad : (stance == .pact ? Palette.good : Palette.ink.opacity(0.65)))
                }
            }
            if !house.isEliminated {
                Text(verbatim: summary(stance: stance, relation: relation, spire: spire))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                if house.isPlayer {
                    // Words for the keeper there, sent with the next offer.
                    TextField("Words to send with an offer", text: $words)
                        .textFieldStyle(.plain)
                        .font(.nm(11, weight: .light))
                        .foregroundStyle(Palette.ink)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) { Rule(opacity: 0.3) }
                        .onChange(of: words) { _, new in
                            if new.count > Envoy.wordsLimit { words = String(new.prefix(Envoy.wordsLimit)) }
                        }
                        .accessibilityLabel("Words for the keeper of \(house.title)")
                }
                HStack(spacing: 14) {
                    Figure(label: "Holds", value: state.holds(of: house.id).count)
                    Figure(label: "Strength", value: state.strength(of: house.id))
                    Figure(label: "Renown", value: state.renown(of: house.id))
                }
                // In a row when they fit, wrapping onto the next when not.
                FlowLayout(spacing: 4, lineSpacing: 2) { actions(stance: stance) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private func actions(stance: Stance) -> some View {
        switch stance {
        case .war:
            QuietButton(title: "Offer peace", size: 8.5) { offer(.peace) }
        case .peace:
            QuietButton(title: "Offer a pact", size: 8.5) { offer(.pact) }
            giftMenu
            tradeButton
            if session.canDemandTribute(from: house.id) {
                QuietButton(title: "Demand tribute", size: 8.5) { offer(.tribute) }
            }
            ConfirmButton(title: "Declare war", confirm: "War on \(house.title)?") { session.perform(.declareWar(on: house.id)) }
        case .pact:
            giftMenu
            tradeButton
            ConfirmButton(title: "Break the pact", confirm: "Betray \(house.title)?") { session.perform(.declareWar(on: house.id)) }
        }
    }

    /// What may be sent, from what the keeper has: a few sizes of each.
    static func giftChoices(from stock: Stock) -> [(resource: Resource, amount: Int)] {
        Resource.allCases.flatMap { resource in
            (resource == .moonsalt ? [2, 5, 10] : [10, 25, 50])
                .filter { $0 <= stock[resource] }
                .map { (resource, $0) }
        }
    }

    @ViewBuilder
    private var giftMenu: some View {
        let choices = HouseRow.giftChoices(from: session.playerHouse.stock)
        if !choices.isEmpty {
            Menu {
                ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                    Button("\(choice.amount) \(choice.resource.title.lowercased())") {
                        session.perform(.gift(to: house.id, resource: choice.resource, amount: choice.amount))
                    }
                }
            } label: {
                // Set as the buttons beside it are.
                Caps("Send a gift", size: 8.5)
                    .foregroundStyle(Palette.ink.opacity(0.72))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
            }
            .menuStyle(.borderlessButton)
            .menuIndicator(.hidden)
            .fixedSize()
            .help("Stores sent now buy goodwill: a steward sees a war as older, and takes a pact from a House that has given enough.")
        }
    }

    private var tradeButton: some View {
        QuietButton(title: "Offer a trade", size: 8.5) { trading = true }
            .help("So much of one store for so much of another.")
            .popover(isPresented: $trading, arrowEdge: .leading) {
                TradeComposer(house: house, stock: session.playerHouse.stock) { trade in
                    session.offerTrade(trade, to: house, words: words)
                    words = ""
                    trading = false
                }
            }
    }

    private func offer(_ proposal: Proposal) {
        session.propose(proposal, to: house, words: words)
        words = ""
    }

    /// Who gives a House its orders: a steward, or a keeper here or away.
    static func keeping(_ house: House, present: [String]?) -> String {
        guard house.isPlayer else { return "A steward gives its orders." }
        if present?.contains(house.name) == true { return "Its keeper is here." }
        return "Its keeper is away; it stands as they left it."
    }

    private func summary(stance: Stance, relation: Relation?, spire: Int) -> String {
        let state = session.state
        var parts = [house.isPlayer ? HouseRow.keeping(house, present: session.realmStatus?.present)
                                    : "\(house.temperament.title). \(HouseRow.keeping(house, present: nil))"]
        if let liege = house.liege {
            parts.append(liege == session.player ? "Sworn to you." : "Sworn to \(state.houses[liege].title).")
        }
        let vassals = state.houses.filter { $0.liege == house.id && !$0.isEliminated }
        if !vassals.isEmpty {
            parts.append("Liege of \(vassals.map(\.title).joined(separator: ", ")).")
        }
        if let relation {
            let watches = max(session.state.watch - relation.since, 0)
            let span = watches == 0 ? "since this watch" : "for \(watches) watch\(watches == 1 ? "" : "es")"
            parts.append("\(stance.title) \(span).")
            if relation.betrayals > 0 {
                parts.append("Pacts broken between you: \(relation.betrayals).")
            }
        }
        if spire > 0 {
            parts.append("Its Moonspire stands at stage \(spire) of \(BuildingKind.moonspire.maxLevel).")
        }
        let goodwill = state.goodwill(from: session.player, to: house.id)
        if goodwill > 0 {
            parts.append("Your gifts lately are worth \(goodwill) to them.")
        }
        return parts.joined(separator: " ")
    }
}

private struct Figure: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Caps(label, size: 7.5).foregroundStyle(Palette.ink.opacity(0.45))
            Text(verbatim: "\(value)").font(.nm(10.5).monospacedDigit()).foregroundStyle(Palette.ink.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }
}

struct CloseButton: View {
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.nm(9, weight: .light))
                .foregroundStyle(Palette.ink.opacity(hovering ? 0.95 : 0.5))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Close")
    }
}

/// Envoys waiting on the player's answer, one card each.
struct EnvoyCards: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(session.envoys) { envoy in
                let house = state.houses[envoy.from]
                let left = max(Envoy.patience - (state.watch - envoy.arrived), 1)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1).fill(Palette.house(house)).frame(width: 3, height: 12)
                        Caps("An envoy of \(house.title)", size: 9, weight: .medium).foregroundStyle(Palette.ink)
                    }
                    if let spoken = session.spoken[.envoy(envoy.id)] {
                        Text(verbatim: "“\(spoken)”")
                            .font(.nm(12, weight: .light).italic())
                            .foregroundStyle(Palette.ink.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                    if let words = session.words(of: envoy) {
                        Text(verbatim: "“\(words)”")
                            .font(.nm(12, weight: .light).italic())
                            .foregroundStyle(Palette.ink.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("\(house.name) writes: \(words)")
                    }
                    Text(verbatim: EnvoyCards.words(for: envoy, from: house, in: state, player: session.player))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.ink.opacity(session.spoken[.envoy(envoy.id)] == nil ? 0.7 : 0.5))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text(verbatim: left == 1 ? "Leaves after this watch" : "Waits \(left) watches")
                            .font(.nm(10))
                            .foregroundStyle(Palette.ink.opacity(0.4))
                        Spacer()
                        if envoy.words != nil {
                            let muted = session.mutedHouses.contains(house.name)
                            QuietButton(title: muted ? "Show Words" : "Hide Words", size: 8.5) { session.setMuted(!muted, house: house) }
                                .help(muted ? "Read \(house.name)'s words again." : "Hide \(house.name)'s words from now on, on this Mac.")
                        }
                        QuietButton(title: "Refuse", size: 8.5) { session.perform(.answer(envoy: envoy.id, accept: false)) }
                        QuietButton(title: "Accept", size: 8.5, prominent: true) { session.perform(.answer(envoy: envoy.id, accept: true)) }
                    }
                }
                .padding(14)
                .frame(width: 320)
                .panelBackground()
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }
        }
    }

    static func words(for envoy: Envoy, from house: House, in state: GameState, player: Int) -> String {
        switch envoy.proposal {
        case .trade:
            guard let trade = envoy.trade else { return "\(house.title) would trade, but its terms are lost." }
            var line = "\(house.title) offers \(trade.given) for \(trade.taken) of yours. \(TradeComposer.note(asking: trade.asking))"
            let have = state.houses[player].stock[trade.take]
            if have < trade.takeAmount { line += " You have only \(have) \(trade.take.title.lowercased())." }
            return line
        case .peace:
            return "\(house.title) asks for peace. Their armies would turn from yours, and yours from theirs."
        case .pact:
            return "\(house.title) offers a pact: shared sight across the water, and no blade between you."
        case .fealty:
            return "\(house.title) is beaten and bends the knee: it would be your vassal, its holds counted in your realm, never to raise a blade against you."
        case .tribute:
            let price = state.tribute(from: player)
            return "\(house.title) demands tribute: \(price), a fifth of your stores. Pay, and it keeps the peace for \(GameState.tributeRespite) watches. Refuse, or send no answer, and it marches on you."
        }
    }
}

/// Terms of a trade, set by the keeper: what to give, and what to ask.
struct TradeComposer: View {
    let house: House
    let stock: Stock
    let offer: (Trade) -> Void

    @State private var give: Resource = .grain
    @State private var giveAmount = 10
    @State private var take: Resource = .timber
    @State private var takeAmount = 10

    init(house: House, stock: Stock, offer: @escaping (Trade) -> Void) {
        self.house = house
        self.stock = stock
        self.offer = offer
        // Start from what the keeper has most of.
        let most = Resource.allCases.max { stock[$0] * $0.worth < stock[$1] * $1.worth } ?? .grain
        _give = State(initialValue: most)
        _take = State(initialValue: most == .timber ? .stone : .timber)
    }

    var trade: Trade { Trade(give: give, giveAmount, for: take, takeAmount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caps("A trade with \(house.title)", size: 9, weight: .medium).foregroundStyle(Palette.ink)
            row("Give", resource: $give, amount: $giveAmount, most: max(1, stock[give]))
            row("For", resource: $take, amount: $takeAmount, most: Stock.cap)
            Text(verbatim: TradeComposer.line(for: trade, stock: stock, keeper: house.isPlayer))
                .font(.nm(10.5))
                .foregroundStyle(Palette.ink.opacity(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                QuietButton(title: "Offer", size: 9, prominent: true, enabled: TradeComposer.problem(with: trade, stock: stock) == nil) {
                    offer(trade)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func row(_ label: String, resource: Binding<Resource>, amount: Binding<Int>, most: Int) -> some View {
        HStack(spacing: 8) {
            Caps(label, size: 8).foregroundStyle(Palette.ink.opacity(0.5)).frame(width: 34, alignment: .leading)
            Picker(label, selection: resource) {
                ForEach(Resource.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 104)
            Stepper(value: amount, in: 1...max(1, most), step: resource.wrappedValue == .moonsalt ? 1 : 5) {
                Text(verbatim: "\(amount.wrappedValue)").font(.nm(11).monospacedDigit()).foregroundStyle(Palette.ink)
            }
            .accessibilityLabel("\(label) amount")
        }
    }

    /// Why the terms can't be offered, if they can't.
    static func problem(with trade: Trade, stock: Stock) -> String? {
        if trade.give == trade.take { return "Choose two different stores." }
        if !trade.isWellFormed { return "Choose an amount of each." }
        if stock[trade.give] < trade.giveAmount { return "You have only \(stock[trade.give]) \(trade.give.title.lowercased())." }
        return nil
    }

    /// How terms weigh, from the side of the House that would get `asking`
    /// percent of what it gives.
    static func note(asking: Int) -> String {
        switch asking {
        case ..<90: return "Generous: more given than asked, by barter worth."
        case 90...110: return "Even terms, by barter worth."
        default: return "More asked than given, by barter worth."
        }
    }

    static func line(for trade: Trade, stock: Stock, keeper: Bool) -> String {
        if let problem = problem(with: trade, stock: stock) { return problem }
        let who = keeper ? "Their keeper answers by envoy." : "Their steward answers at once; the shrewd ask more, allies less."
        return "\(note(asking: trade.asking)) \(who)"
    }
}
