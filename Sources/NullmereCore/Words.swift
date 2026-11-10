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
    /// Taken away by the realm's steward: it stands where it was, its words gone.
    public let removed: Bool?
    /// A place the keeper shared in these words, its name their words, for
    /// those who hear them to look to; nil for words alone.
    public let place: SharedPlace?

    public init(id: Int, from: Int, watch: Int, text: String, alliance: Int?, removed: Bool? = nil, place: SharedPlace? = nil) {
        self.id = id
        self.from = from
        self.watch = watch
        self.text = text
        self.alliance = alliance
        self.removed = removed
        self.place = place
    }
}

/// A place a keeper shares in their words (Rise of Kingdoms' places
/// shared in the alliance's words): where it lies, and the name they give
/// it, for those who hear them to look to or keep in their own book.
public struct SharedPlace: Codable, Equatable, Sendable {
    public let at: Hex
    public let name: String

    public init(at: Hex, name: String) {
        self.at = at
        self.name = name
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
        let hidden = hiddenHouses(of: house)
        return wordsSaid.filter { ($0.alliance == nil || $0.alliance == sworn) && !hidden.contains($0.from) }
    }

    /// Why a House can't say something now, if it can't.
    public func sayRefusal(_ text: String, toAlliance: Bool, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard Envoy.carried(text) != nil else { return .nothingToSay }
        if let until = barredFromWords(house) { return .barredFromWords(until: until) }
        if toAlliance, alliance(of: house) == nil { return .notInAlliance }
        let said = wordsSaid.lazy.filter { $0.from == house && $0.watch == watch }.count
        guard said < GameState.wordsPerWatch else { return .saidEnough }
        return nil
    }

    /// Why a House can't share a place in its words now, if it can't: as
    /// for any words it says, of a place on the map, by a name.
    public func shareRefusal(_ hex: Hex, named name: String, toAlliance: Bool, as house: Int) -> RuleError? {
        guard map[hex] != nil else { return .outsideTheWorld }
        guard let kept = PlaceBook.kept(name) else { return .nothingToSay }
        return sayRefusal(kept, toAlliance: toAlliance, as: house)
    }

    /// A keeper shares a place in their words, to the realm or to their
    /// alliance alone, by the name they give it: said as their words are,
    /// and counted with them.
    mutating func share(_ hex: Hex, named name: String, toAlliance: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = shareRefusal(hex, named: name, toAlliance: toAlliance, as: house) { throw refusal }
        guard let kept = PlaceBook.kept(name), let said = Envoy.carried(kept) else { throw .nothingToSay }
        let word = Word(id: takeID(), from: house, watch: watch, text: said, alliance: toAlliance ? alliance(of: house)?.id : nil,
                        place: SharedPlace(at: hex, name: said))
        words = Array((wordsSaid + [word]).suffix(GameState.wordsKept))
        return [.said(word)]
    }

    mutating func say(_ text: String, toAlliance: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = sayRefusal(text, toAlliance: toAlliance, as: house) { throw refusal }
        let word = Word(id: takeID(), from: house, watch: watch, text: Envoy.carried(text)!,
                        alliance: toAlliance ? alliance(of: house)?.id : nil)
        words = Array((wordsSaid + [word]).suffix(GameState.wordsKept))
        return [.said(word)]
    }
}

// MARK: Words made safe

/// A line a keeper reported to the realm's steward, kept with what was said
/// round it, for whoever runs the realm to read and judge.
public struct WordReport: Codable, Equatable, Sendable {
    public let word: Int
    /// The House whose keeper reported it.
    public let by: Int
    public let watch: Int
    /// The line and what was said round it in the same hearing: up to three
    /// lines before it and three after, as the realm kept them.
    public let context: [Word]

    public init(word: Int, by: Int, watch: Int, context: [Word]) {
        self.word = word
        self.by = by
        self.watch = watch
        self.context = context
    }
}

/// A House the realm's steward has barred from the Words, until a watch.
public struct WordsBar: Codable, Equatable, Sendable {
    public let house: Int
    public let until: Int

    public init(house: Int, until: Int) {
        self.house = house
        self.until = until
    }
}

extension GameState {
    /// The most reports the realm keeps for its steward, the oldest let go first.
    public static let reportsKept = 200
    /// The most lines a keeper may report in a watch, so reports cannot
    /// bury the steward.
    public static let reportsPerWatch = 5
    /// What a line taken away by the realm's steward reads, where it stood.
    public static let removedWords = "Taken away by the realm's steward."

    /// The reports kept; in a keeper's view, their own.
    public var wordReports: [WordReport] { reports ?? [] }

    /// The watch a House may speak again, while the realm's steward bars it
    /// from the Words.
    public func barredFromWords(_ house: Int) -> Int? {
        bars?.first { $0.house == house && $0.until > watch }?.until
    }

    /// Why a House can't report a line now, if it can't.
    public func reportRefusal(_ wordID: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard let word = words(heardBy: house).first(where: { $0.id == wordID }), word.removed != true else { return .unknownWord }
        guard word.from != house else { return .ownWord }
        if wordReports.contains(where: { $0.word == wordID && $0.by == house }) { return .reportedAlready }
        guard wordReports.lazy.filter({ $0.by == house && $0.watch == self.watch }).count < GameState.reportsPerWatch else { return .reportedEnough }
        return nil
    }

    mutating func report(_ wordID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = reportRefusal(wordID, as: house) { throw refusal }
        let heard = words(heardBy: house)
        let at = heard.firstIndex { $0.id == wordID }!
        let context = Array(heard[max(at - 3, 0)...min(at + 3, heard.count - 1)])
        reports = Array((wordReports + [WordReport(word: wordID, by: house, watch: watch, context: context)]).suffix(GameState.reportsKept))
        return [.wordReported(word: wordID, by: house)]
    }

    /// The realm's steward takes a line away: it stands where it was, its
    /// words gone. Nothing, for a line not kept.
    mutating func removeWord(_ wordID: Int) -> [GameEvent] {
        guard let index = words?.firstIndex(where: { $0.id == wordID }), words![index].removed != true else { return [] }
        let word = words![index]
        words![index] = Word(id: word.id, from: word.from, watch: word.watch, text: "", alliance: word.alliance, removed: true)
        return [.wordRemoved(word: wordID)]
    }

    /// The realm's steward bars a House from the Words for so many watches.
    mutating func bar(_ house: Int, watches: Int) -> [GameEvent] {
        guard houses.indices.contains(house), watches > 0 else { return [] }
        let until = watch + watches
        bars = (bars ?? []).filter { $0.house != house && $0.until > watch } + [WordsBar(house: house, until: until)]
        return [.barredFromWords(house: house, until: until)]
    }
}

// MARK: Houses hidden

extension GameState {
    /// The Houses a House has hidden from its keeper's hearing.
    public func hiddenHouses(of house: Int) -> Set<Int> {
        Set(hidden?[house] ?? [])
    }

    /// Whether a House hears another's words and envoys.
    public func hears(_ other: Int, as house: Int) -> Bool {
        !hiddenHouses(of: house).contains(other)
    }

    /// A keeper hides another House, or hears it again; kept at the realm,
    /// so their words and envoys are kept from the keeper on every Mac.
    mutating func hide(_ other: Int, hidden: Bool, by house: Int) throws(RuleError) -> [GameEvent] {
        guard houses.indices.contains(house), houses[house].isPlayer else { throw .notAKeeper }
        guard houses.indices.contains(other), other != house else { throw .notYours }
        var set = hiddenHouses(of: house)
        if hidden { set.insert(other) } else { set.remove(other) }
        var book = self.hidden ?? [:]
        book[house] = set.isEmpty ? nil : set.sorted()
        self.hidden = book.isEmpty ? nil : book
        return []
    }
}
