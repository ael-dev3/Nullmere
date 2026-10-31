/// The veil of the Still, Rise of Kingdoms' peace shield: a keeper draws
/// the lake's mist over their House's holds for eight watches, for
/// moonsalt. While it lies, no hold of the House may be struck, rallied on
/// or scouted, though its companies abroad may still be met. It lifts at
/// once when the House strikes another House, calls or joins a rally on a
/// hold, or scouts one; and it may be drawn again only ten watches after it
/// last lifted. Stewards draw none, so a world of stewards goes as it
/// always did.
public struct Veil: Codable, Equatable, Sendable {
    public let house: Int
    /// The watch it was drawn.
    public let drawn: Int
    /// The watch it lifts, or lifted.
    public internal(set) var until: Int

    public init(house: Int, drawn: Int, until: Int) {
        self.house = house
        self.drawn = drawn
        self.until = until
    }
}

extension GameState {
    /// How many watches a veil lies.
    public static let veilLasts = 8
    /// How many watches after a veil lifts before another may be drawn.
    public static let veilRest = 10
    /// What a veil costs.
    public static let veilCost = Stock(moonsalt: 30)

    /// The veil a House last drew, lying or lifted, while the House keeps
    /// it in mind.
    public func veil(of house: Int) -> Veil? {
        veils?.first { $0.house == house }
    }

    /// Whether a House's holds lie under its veil now.
    public func isVeiled(_ house: Int) -> Bool {
        guard let veils, !veils.isEmpty else { return false }
        return veils.contains { $0.house == house && watch < $0.until }
    }

    /// Why a House can't draw its veil now, if it can't: a keeper's, with
    /// no veil lying, rested since the last lifted, and moonsalt for it.
    public func veilRefusal(as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer, !houses[house].isEliminated else { return .notAKeeper }
        if let veil = veil(of: house) {
            if watch < veil.until { return .veiledAlready(until: veil.until) }
            if watch < veil.until + GameState.veilRest { return .veilResting(until: veil.until + GameState.veilRest) }
        }
        let stock = houses[house].stock
        guard stock.covers(GameState.veilCost) else { return .shortOf(stock.shortfall(for: GameState.veilCost)) }
        return nil
    }

    /// A keeper draws the veil over their House's holds.
    mutating func drawVeil(as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = veilRefusal(as: house) { throw refusal }
        houses[house].stock.debit(GameState.veilCost)
        let veil = Veil(house: house, drawn: watch, until: watch + GameState.veilLasts)
        veils = (veils ?? []).filter { $0.house != house } + [veil]
        return [.veilDrawn(house: house, until: veil.until)]
    }

    /// Why a House's hold can't be struck, rallied on or scouted, if its
    /// veil keeps it.
    func veiledRefusal(of owner: Int) -> RuleError? {
        guard isVeiled(owner), let veil = veil(of: owner) else { return nil }
        return .veiled(until: veil.until)
    }

    /// A House that strikes another lifts its own veil, at once.
    mutating func liftVeil(of house: Int) -> [GameEvent] {
        guard isVeiled(house), let index = veils?.firstIndex(where: { $0.house == house }) else { return [] }
        veils![index].until = watch
        return [.veilLifted(house: house, struck: true)]
    }

    /// As the watch turns: a veil whose watches are out lifts, and one
    /// rested is forgotten.
    mutating func keepVeils() -> [GameEvent] {
        guard let kept = veils, !kept.isEmpty else { return [] }
        let events: [GameEvent] = kept.filter { $0.until == watch && $0.drawn + GameState.veilLasts == watch }
            .map { .veilLifted(house: $0.house, struck: false) }
        let remembered = kept.filter { watch < $0.until + GameState.veilRest }
        veils = remembered.isEmpty ? nil : remembered
        return events
    }
}
