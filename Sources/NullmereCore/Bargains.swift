/// Bargaining with a steward's demand of tribute: rather than pay the fifth
/// it asks or refuse it and face its march, a keeper may offer half of it,
/// a tenth of their stores. The steward weighs the offer at once, by the
/// realm's true reckoning of both Houses' might: it takes half where its
/// House is less than half again as strong as the keeper's (a cunning one,
/// a third again), and half the tribute keeps the peace half as long. Else
/// it holds to the whole, and its envoy waits on the keeper's answer as it
/// did, never to be bargained with again. A keeper's own demand is theirs
/// to bargain over in words; no other offer has a price to halve.
extension GameState {
    /// Watches half a tribute keeps the peace: half as long as the whole.
    public static let halfTributeRespite = tributeRespite / 2

    /// What half a demand of tribute comes to: a tenth of the House's stores.
    public func halfTribute(from payer: Int) -> Stock {
        houses[payer].stock.share(1, of: 10)
    }

    /// The rule a steward weighs half its demand by, as the Mac's help and
    /// the phone tell it.
    public static let bargainRule = "Their steward takes half where its House is less than half again as strong as yours "
        + "(a cunning one, a third again), and keeps the peace \(halfTributeRespite) watches; else it holds to the whole."

    /// Why a House can't offer an envoy half its demand now, if it can't:
    /// the envoy is gone or another's, it isn't a steward's demand of
    /// tribute, its steward held to the whole once already, or the demand
    /// no longer stands.
    public func bargainRefusal(_ envoyID: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer,
              let envoy = envoys.first(where: { $0.id == envoyID && $0.to == house }) else { return .unknownEnvoy }
        guard envoy.proposal == .tribute, houses.indices.contains(envoy.from), !houses[envoy.from].isPlayer else { return .notBargained }
        guard envoy.bargained != true else { return .bargainedAlready }
        guard stance(house, envoy.from) == .peace, !houses[envoy.from].isEliminated else { return .notApplicable }
        return nil
    }

    /// What offering half would pay, as its button says it: "Offer half: 12
    /// grain, 6 timber".
    public func bargainSaid(for house: Int) -> String {
        "Offer half: \(halfTribute(from: house))"
    }

    /// Whether a steward takes half its demand: its House less than half
    /// again as strong as the keeper's, or for a cunning one a third again.
    func takesHalf(_ envoy: Envoy) -> Bool {
        let theirs = max(1, strength(of: envoy.from)), yours = max(1, strength(of: envoy.to))
        if houses[envoy.from].temperament == .cunning { return theirs * 3 < yours * 4 }
        return theirs * 2 < yours * 3
    }

    /// A keeper offers a steward's envoy half its demand of tribute. Taken,
    /// the tenth is paid, the peace kept half the respite and the envoy goes
    /// home; held to, the envoy stays with its demand whole.
    mutating func bargain(_ envoyID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = bargainRefusal(envoyID, as: house) { throw refusal }
        guard let index = envoys.firstIndex(where: { $0.id == envoyID }) else { throw .unknownEnvoy }
        let envoy = envoys[index]
        guard takesHalf(envoy) else {
            envoys[index].bargained = true
            return [.tributeBargained(from: envoy.from, to: house, paid: nil)]
        }
        envoys.remove(at: index)
        let paid = halfTribute(from: house)
        houses[house].stock.debit(paid)
        // What the steward has no room for is lost on the road.
        store(paid, for: envoy.from)
        if let relation = keptRelationIndex(envoy.from, house) {
            // Counted as paid so long ago that the respite has half of it to run.
            relations[relation].tributePaid = watch - (GameState.tributeRespite - GameState.halfTributeRespite)
        }
        remember(.tribute, from: envoy.from, to: house, answer: .halved)
        record(.tribute, [house, envoy.from], "\(houses[house].title) pays \(houses[envoy.from].title) half the tribute it demanded: \(paid).")
        return [.tributeBargained(from: envoy.from, to: house, paid: paid)]
    }
}
