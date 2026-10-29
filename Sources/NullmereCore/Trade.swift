/// An exchange one House offers another: so much of one store for so much
/// of another, on whatever terms the two agree. Unlike barter with no one,
/// at three to one, two Houses whose wants meet can trade near even.
public struct Trade: Codable, Equatable, Hashable, Sendable, CustomStringConvertible {
    /// What the House offering gives.
    public let give: Resource
    public let giveAmount: Int
    /// What it asks in return.
    public let take: Resource
    public let takeAmount: Int

    public init(give: Resource, _ giveAmount: Int, for take: Resource, _ takeAmount: Int) {
        self.give = give
        self.giveAmount = giveAmount
        self.take = take
        self.takeAmount = takeAmount
    }

    public var given: Stock {
        var stock = Stock()
        stock[give] = giveAmount
        return stock
    }

    public var taken: Stock {
        var stock = Stock()
        stock[take] = takeAmount
        return stock
    }

    /// What the offering House asks for what it gives, in percent of barter
    /// worth: 100 is even, more asks more than it gives.
    public var asking: Int {
        takeAmount * take.worth * 100 / max(1, giveAmount * give.worth)
    }

    /// Terms the rules allow: two different stores, each a real amount.
    public var isWellFormed: Bool {
        give != take && (1...Stock.cap).contains(giveAmount) && (1...Stock.cap).contains(takeAmount)
    }

    public var description: String { "\(given) for \(taken)" }
}

extension GameState {
    /// A trade worth this much, both ways, goes into the chronicle.
    static let notedTrade = 120

    mutating func offerTrade(_ trade: Trade, from house: Int, to target: Int, words: String? = nil) throws(RuleError) -> [GameEvent] {
        guard target != house, let other = self.house(target), !other.isEliminated else { throw .unknownHouse }
        guard stance(house, target) != .war else { throw .noTradeAcrossWar(target) }
        guard trade.give != trade.take else { throw .sameStore }
        guard trade.isWellFormed else { throw .invalidAmount }
        guard houses[house].stock.covers(trade.given) else { throw .shortOf(houses[house].stock.shortfall(for: trade.given)) }
        guard houses[house].stock[trade.take] + trade.takeAmount <= storage(of: house) else { throw .storageFull }

        if houses[target].isPlayer {
            // One offer of trade at a time waits on a keeper from each House.
            guard !envoys.contains(where: { $0.from == house && $0.to == target && $0.proposal == .trade }) else { throw .envoyWaiting }
            let envoy = Envoy(id: takeID(), from: house, to: target, proposal: .trade, arrived: watch,
                              words: houses[house].isPlayer ? words : nil, trade: trade)
            envoys.append(envoy)
            return [.envoyArrived(envoy)]
        }

        let accepted = RivalMind(house: target).acceptsTrade(trade, from: house, in: self)
            && settleTrade(trade, from: house, to: target)
        return [.tradeAnswered(trade: trade, from: house, to: target, accepted: accepted)]
    }

    /// Whether both sides can still keep a trade's terms: each has what it
    /// gives and room for what it gets.
    func canSettle(_ trade: Trade, from proposer: Int, to other: Int) -> Bool {
        guard trade.isWellFormed, !houses[proposer].isEliminated, !houses[other].isEliminated,
              stance(proposer, other) != .war else { return false }
        return houses[proposer].stock.covers(trade.given) && houses[other].stock.covers(trade.taken)
            && houses[proposer].stock[trade.take] + trade.takeAmount <= storage(of: proposer)
            && houses[other].stock[trade.give] + trade.giveAmount <= storage(of: other)
    }

    /// Carries a trade out, if it still can be. Returns whether it was.
    mutating func settleTrade(_ trade: Trade, from proposer: Int, to other: Int) -> Bool {
        guard canSettle(trade, from: proposer, to: other) else { return false }
        houses[proposer].stock.debit(trade.given)
        houses[other].stock.credit(trade.given)
        houses[other].stock.debit(trade.taken)
        houses[proposer].stock.credit(trade.taken)
        let worth = trade.giveAmount * trade.give.worth + trade.takeAmount * trade.take.worth
        if worth >= GameState.notedTrade {
            record(.trade, [proposer, other], "\(houses[proposer].title) trades \(trade.given) to \(houses[other].title) for \(trade.taken).")
        }
        return true
    }

    /// A keeper's answer to an offer of trade.
    mutating func answerTrade(_ envoy: Envoy, accept: Bool, as house: Int) -> [GameEvent] {
        guard let trade = envoy.trade else { return [] }
        let accepted = accept && settleTrade(trade, from: envoy.from, to: house)
        return [.tradeAnswered(trade: trade, from: envoy.from, to: house, accepted: accepted)]
    }
}

extension RivalMind {
    /// Whether a steward takes an offer of trade. It weighs what it gets
    /// against what it gives by barter worth, asking more the shrewder its
    /// temperament, and less from an ally, a giver of gifts, or when the
    /// offer brings what it lacks for what it has in plenty. It never trades
    /// away the grain its companies need.
    func acceptsTrade(_ trade: Trade, from proposer: Int, in state: GameState) -> Bool {
        guard trade.isWellFormed, state.stance(house, proposer) != .war else { return false }
        let me = state.houses[house]
        let room = state.storage(of: house)
        let left = me.stock[trade.take] - trade.takeAmount
        guard left >= 0, me.stock[trade.give] + trade.giveAmount <= room else { return false }
        if trade.take == .grain, left < state.upkeep(of: house) * 3 { return false }

        var margin: Int
        switch me.temperament {
        case .cunning: margin = 130
        case .ambitious: margin = 120
        case .wary: margin = 110
        case .steadfast: margin = 100
        }
        if state.stance(house, proposer) == .pact { margin -= 10 }
        margin -= min(20, state.goodwill(from: proposer, to: house) / 5)
        if me.stock[trade.give] < room / 5 { margin -= 15 }
        if me.stock[trade.take] > room * 3 / 5 { margin -= 15 }
        let received = trade.giveAmount * trade.give.worth
        let paid = trade.takeAmount * trade.take.worth
        return received * 100 >= paid * max(100, margin)
    }

    /// Terms a steward offers for what it lacks: a little over even, so
    /// a fair partner takes them. Nil if it can't spare enough.
    func terms(giving high: Resource, for low: Resource, amount: Int, in state: GameState) -> Trade? {
        let stock = state.houses[house].stock
        let give = (amount * low.worth * 11 + high.worth * 10 - 1) / (high.worth * 10)
        guard amount >= 10, give >= 1, give <= stock[high] / 2 else { return nil }
        return Trade(give: high, give, for: low, amount)
    }

    /// Before bartering at three to one, a steward looks for a House to
    /// trade with near even: other stewards answer at once; a keeper, now
    /// and then, gets an envoy. Returns what came of it, and whether its
    /// want was met.
    func seekTrade(giving high: Resource, for low: Resource, amount: Int, in state: inout GameState) -> (events: [GameEvent], met: Bool) {
        guard let trade = terms(giving: high, for: low, amount: amount, in: state) else { return ([], false) }
        let partners = state.livingHouses
            .filter { $0.id != house && state.stance(house, $0.id) != .war }
            .sorted { ($0.stock[low], tieBreak($0.id, in: state)) > ($1.stock[low], tieBreak($1.id, in: state)) }
        var events: [GameEvent] = []
        for partner in partners.prefix(3) where !partner.isPlayer {
            guard state.canSettle(trade, from: house, to: partner.id),
                  RivalMind(house: partner.id).acceptsTrade(trade, from: house, in: state) else { continue }
            events += (try? state.offerTrade(trade, from: house, to: partner.id)) ?? []
            return (events, true)
        }
        // A keeper with plenty hears an offer now and then, never twice at once.
        if let keeper = partners.first(where: { $0.isPlayer && $0.stock[low] >= amount * 2 }),
           (state.watch + house) % 5 == 0,
           !state.envoys.contains(where: { $0.from == house && $0.to == keeper.id }) {
            events += (try? state.offerTrade(trade, from: house, to: keeper.id)) ?? []
        }
        return (events, false)
    }
}
