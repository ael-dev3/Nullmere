/// A ballad of a moment of the age: a few short lines of verse about a
/// deed in the Chronicle, made on the keeper's own Mac by its on-device
/// model and sung to the realm, which keeps it in the songbook for every
/// House to read. No server wrote it, and no other keeper's Mac made it.
public struct Ballad: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    /// The House whose keeper sang it.
    public let house: Int
    public let watch: Int
    /// The Chronicle entry it sings of, by its place in the Chronicle.
    public let entry: Int
    public let lines: [String]

    public init(id: Int, house: Int, watch: Int, entry: Int, lines: [String]) {
        self.id = id
        self.house = house
        self.watch = watch
        self.entry = entry
        self.lines = lines
    }
}

extension GameState {
    /// How many lines a ballad has, at the least and the most.
    public static let balladLines = 2...6
    /// The longest a line of a ballad may be.
    public static let balladLineLimit = 90
    /// The most ballads the songbook keeps, the oldest let go first.
    public static let songsKept = 60
    /// The renown a keeper's ballads bring them as the age ends, each, and
    /// the most ballads that count.
    public static let renownPerBallad = 2
    public static let balladsThatCount = 5

    /// Every ballad sung this age, the latest last.
    public var songbook: [Ballad] { ballads ?? [] }

    /// The kinds of the Chronicle's entries worth a ballad: deeds of arms
    /// and of building, betrayals, and the age's end.
    public static func isWorthABallad(_ kind: ChronicleEntry.Kind) -> Bool {
        switch kind {
        case .war, .betrayal, .capture, .fall, .greatWork, .battle, .ending: return true
        case .beginning, .founding, .peace, .pact, .discovery, .tribute, .omen, .gift, .trade, .seating, .learning,
             .commander, .hunt, .alliance, .rally, .happening: return false
        }
    }

    /// Whether a House may sing of a Chronicle entry: one worth a ballad
    /// that its House had a part in, or the age's end.
    public func isSingable(_ entry: Int, by house: Int) -> Bool {
        guard chronicle.indices.contains(entry) else { return false }
        let found = chronicle[entry]
        return GameState.isWorthABallad(found.kind) && (found.houses.contains(house) || found.kind == .ending)
    }

    /// A ballad's lines as the realm keeps them: each a line of plain words
    /// as an envoy would carry them, cut at `balladLineLimit`; nil when what
    /// is left is no ballad, too few lines or too many.
    public static func sung(_ text: String) -> [String]? {
        let lines = text.split(whereSeparator: \.isNewline).compactMap { line -> String? in
            guard let kept = Envoy.carried(String(line)) else { return nil }
            return String(kept.prefix(balladLineLimit))
        }
        return balladLines.contains(lines.count) ? lines : nil
    }

    /// Why a House can't sing a ballad of an entry now, if it can't.
    public func singRefusal(_ text: String, of entry: Int, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard isSingable(entry, by: house) else { return .notSingable }
        guard GameState.sung(text) != nil else { return .notABallad }
        if songbook.contains(where: { $0.house == house && $0.entry == entry }) { return .sungAlready }
        if songbook.contains(where: { $0.house == house && $0.watch == watch }) { return .sangThisWatch }
        return nil
    }

    mutating func sing(_ text: String, of entry: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = singRefusal(text, of: entry, as: house) { throw refusal }
        let ballad = Ballad(id: takeID(), house: house, watch: watch, entry: entry, lines: GameState.sung(text)!)
        ballads = Array((songbook + [ballad]).suffix(GameState.songsKept))
        return [.sung(ballad)]
    }

    /// The ballads of a House's sung this age that count toward its
    /// keeper's renown as the age ends.
    public func balladsCounted(of house: Int) -> Int {
        min(songbook.filter { $0.house == house }.count, GameState.balladsThatCount)
    }
}
