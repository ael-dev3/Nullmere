import Foundation

/// Words a keeper says to the whole realm, or to their alliance alone:
/// one line of plain speech, kept a while for those it was said to.
public struct Word: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    /// The House whose keeper said it.
    public let from: Int
    public let watch: Int
    public let text: String
    /// The alliance it was said within; nil, to the whole realm.
    public let alliance: Int?

    public init(id: Int, from: Int, watch: Int, text: String, alliance: Int?) {
        self.id = id
        self.from = from
        self.watch = watch
        self.text = text
        self.alliance = alliance
    }
}

extension GameState {
    /// The most words the realm keeps, the oldest let go first.
    public static let wordsKept = 80
    /// The most lines a keeper says in a watch, so no one drowns the rest.
    public static let wordsPerWatch = 20

    /// Every word kept, the latest last; in a keeper's view, those they heard.
    public var wordsSaid: [Word] { words ?? [] }

    /// What a House hears: the realm's words, and its own alliance's.
    public func words(heardBy house: Int) -> [Word] {
        let sworn = alliance(of: house)?.id
        return wordsSaid.filter { $0.alliance == nil || $0.alliance == sworn }
    }

    /// Why a House can't say something now, if it can't.
    public func sayRefusal(_ text: String, toAlliance: Bool, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard Envoy.carried(text) != nil else { return .nothingToSay }
        if toAlliance, alliance(of: house) == nil { return .notInAlliance }
        let said = wordsSaid.lazy.filter { $0.from == house && $0.watch == watch }.count
        guard said < GameState.wordsPerWatch else { return .saidEnough }
        return nil
    }

    mutating func say(_ text: String, toAlliance: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = sayRefusal(text, toAlliance: toAlliance, as: house) { throw refusal }
        let word = Word(id: takeID(), from: house, watch: watch, text: Envoy.carried(text)!,
                        alliance: toAlliance ? alliance(of: house)?.id : nil)
        words = Array((wordsSaid + [word]).suffix(GameState.wordsKept))
        return [.said(word)]
    }
}
