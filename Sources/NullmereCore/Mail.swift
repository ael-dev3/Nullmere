/// Letters between two keepers (after Rise of Kingdoms' mail): one keeper
/// writes to another House's keeper, and only the two of them ever read
/// it. A letter is kept a while for both, its sender and its reader; the
/// realm tells the reader it has come.
public struct Missive: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let from: Int
    public let to: Int
    public let watch: Int
    public let text: String

    public init(id: Int, from: Int, to: Int, watch: Int, text: String) {
        self.id = id
        self.from = from
        self.to = to
        self.watch = watch
        self.text = text
    }
}

extension GameState {
    /// The most letters the realm keeps in all, the oldest let go first.
    public static let lettersKept = 120
    /// The most letters a keeper sends in a watch.
    public static let lettersPerWatch = 5

    /// Every letter kept; in a keeper's view, their own.
    public var lettersSent: [Missive] { mail ?? [] }

    /// The letters a House wrote or was written, the latest last.
    public func letters(of house: Int) -> [Missive] {
        lettersSent.filter { $0.from == house || $0.to == house }
    }

    /// Why a House can't write to another now, if it can't.
    public func letterRefusal(to other: Int, _ text: String, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard houses.indices.contains(other), other != house, !houses[other].isEliminated else { return .unknownHouse }
        guard houses[other].isPlayer else { return .notAKeeper }
        guard Envoy.carried(text) != nil else { return .nothingToSay }
        if let until = barredFromWords(house) { return .barredFromWords(until: until) }
        let sent = lettersSent.lazy.filter { $0.from == house && $0.watch == watch }.count
        guard sent < GameState.lettersPerWatch else { return .saidEnough }
        return nil
    }

    mutating func write(to other: Int, _ text: String, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = letterRefusal(to: other, text, as: house) { throw refusal }
        let letter = Missive(id: takeID(), from: house, to: other, watch: watch, text: Envoy.carried(text)!)
        mail = Array((lettersSent + [letter]).suffix(GameState.lettersKept))
        return [.letterSent(letter)]
    }
}
