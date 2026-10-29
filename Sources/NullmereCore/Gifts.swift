/// A gift one House sent another, kept a while for the goodwill it buys.
public struct Gift: Codable, Equatable, Sendable {
    public let from: Int
    public let to: Int
    /// Its worth, in stores counted as grain (moonsalt weighs more).
    public let worth: Int
    public let watch: Int
}

extension GameState {
    /// Watches a gift is remembered.
    static let giftMemory = 20
    /// Goodwill a steward takes a pact for, whatever its temperament.
    static let pactGoodwill = 60
    /// A gift worth this much goes into the chronicle.
    static let notedGift = 40

    /// How a resource weighs in goodwill.
    static func worth(of resource: Resource, amount: Int) -> Int {
        resource == .moonsalt ? amount * 4 : amount
    }

    /// The worth of what one House gave another in the last watches.
    public func goodwill(from giver: Int, to receiver: Int) -> Int {
        (gifts ?? []).filter { $0.from == giver && $0.to == receiver && watch - $0.watch < GameState.giftMemory }
            .reduce(0) { $0 + $1.worth }
    }

    mutating func give(_ resource: Resource, amount: Int, from house: Int, to target: Int) throws(RuleError) -> [GameEvent] {
        guard target != house, let receiver = self.house(target), !receiver.isEliminated else { throw .unknownHouse }
        guard stance(house, target) != .war else { throw .atWarWith(target) }
        guard amount > 0, amount <= Stock.cap else { throw .invalidAmount }
        var gift = Stock()
        gift[resource] = amount
        guard houses[house].stock.covers(gift) else { throw .shortOf(houses[house].stock.shortfall(for: gift)) }
        guard houses[target].stock[resource] + amount <= storage(of: target) else { throw .storageFull }
        houses[house].stock.debit(gift)
        houses[target].stock.credit(gift)
        let worth = GameState.worth(of: resource, amount: amount)
        // One gift between two Houses a watch goes into the chronicle, so
        // gifts sent back and forth can't fill it.
        let notedAlready = (gifts ?? []).contains { gift in
            gift.watch == watch && gift.worth >= GameState.notedGift
                && Set([gift.from, gift.to]) == Set([house, target])
        }
        gifts = (gifts ?? []) + [Gift(from: house, to: target, worth: worth, watch: watch)]
        if worth >= GameState.notedGift, !notedAlready {
            record(.gift, [house, target], "\(houses[house].title) sends \(houses[target].title) a gift of \(gift).")
        }
        return [.gifted(from: house, to: target, gift: gift)]
    }

    mutating func forgetOldGifts() {
        guard let kept = gifts else { return }
        let recent = kept.filter { watch - $0.watch < GameState.giftMemory }
        gifts = recent.isEmpty ? nil : recent
    }
}
