import Foundation

/// Where two Houses stand with each other.
public enum Stance: String, Codable, CaseIterable, Sendable {
    case war
    /// No fighting; armies keep to themselves.
    case peace
    /// Allies: shared sight, and no fighting.
    case pact

    public var title: String {
        switch self {
        case .war: return "War"
        case .peace: return "Peace"
        case .pact: return "Pact"
        }
    }

    /// How two Houses stand, as a sentence says it: "at war", "in a pact".
    public var standing: String {
        switch self {
        case .war: return "at war"
        case .peace: return "at peace"
        case .pact: return "in a pact"
        }
    }
}

/// The relation between two Houses.
public struct Relation: Codable, Equatable, Sendable {
    public let first: Int
    public let second: Int
    public var stance: Stance
    /// The watch the stance began.
    public var since: Int
    /// The House that last declared war, which the other remembers.
    public var aggressor: Int?
    /// Times either broke a pact with the other.
    public var betrayals: Int
    /// The watch tribute last passed between them.
    public var tributePaid: Int?
    /// The watch a demand for tribute between them was last refused.
    public var tributeRefused: Int?

    public init(first: Int, second: Int, stance: Stance = .peace, since: Int = 1) {
        self.first = min(first, second)
        self.second = max(first, second)
        self.stance = stance
        self.since = since
        self.aggressor = nil
        self.betrayals = 0
        self.tributePaid = nil
        self.tributeRefused = nil
    }

    public func other(than house: Int) -> Int {
        first == house ? second : first
    }

    // A relation travels as one line, "first,second,stance,since", with
    // its aggressor, betrayals and tributes after only as far as it has
    // any: a realm keeps one for every two of its Houses, 1,128 in one of
    // forty-eight seats, and every keeper's view carries them all. One
    // kept field by field, as before, still opens.
    private enum CodingKeys: String, CodingKey {
        case first, second, stance, since, aggressor, betrayals, tributePaid, tributeRefused
    }

    public init(from decoder: any Decoder) throws {
        if let line = try? decoder.singleValueContainer().decode(String.self) {
            let fields = line.split(separator: ",", omittingEmptySubsequences: false).map(String.init)
            func number(_ index: Int) -> Int? { fields.indices.contains(index) ? Int(fields[index]) : nil }
            guard fields.count >= 4, fields.count <= 8, let first = number(0), let second = number(1),
                  let stance = Stance(rawValue: fields[2]), let since = number(3),
                  fields.indices.dropFirst(4).allSatisfy({ fields[$0].isEmpty || Int(fields[$0]) != nil }) else {
                throw DecodingError.dataCorrupted(.init(codingPath: decoder.codingPath, debugDescription: "Not a relation: \(line)"))
            }
            self.first = first
            self.second = second
            self.stance = stance
            self.since = since
            aggressor = number(4)
            betrayals = number(5) ?? 0
            tributePaid = number(6)
            tributeRefused = number(7)
            return
        }
        let container = try decoder.container(keyedBy: CodingKeys.self)
        first = try container.decode(Int.self, forKey: .first)
        second = try container.decode(Int.self, forKey: .second)
        stance = try container.decode(Stance.self, forKey: .stance)
        since = try container.decode(Int.self, forKey: .since)
        aggressor = try container.decodeIfPresent(Int.self, forKey: .aggressor)
        betrayals = try container.decode(Int.self, forKey: .betrayals)
        tributePaid = try container.decodeIfPresent(Int.self, forKey: .tributePaid)
        tributeRefused = try container.decodeIfPresent(Int.self, forKey: .tributeRefused)
    }

    public func encode(to encoder: any Encoder) throws {
        func field(_ value: Int?) -> String { value.map { "\($0)" } ?? "" }
        var fields: [String] = [field(first), field(second), stance.rawValue, field(since)]
        let rest: [String] = [field(aggressor), field(betrayals == 0 ? nil : betrayals), field(tributePaid), field(tributeRefused)]
        if let last = rest.lastIndex(where: { !$0.isEmpty }) { fields += rest[...last] }
        var container = encoder.singleValueContainer()
        try container.encode(fields.joined(separator: ","))
    }
}

/// What one House can offer another.
public enum Proposal: String, Codable, CaseIterable, Sendable {
    case peace
    case pact
    /// A beaten House offers to become the other's vassal: a pact it can't
    /// break, and its holds counted toward its liege's dominion.
    case fealty
    /// A stronger House demands a fifth of the other's stores. A steward
    /// refused marches; paid, it keeps the peace twenty watches.
    case tribute
    /// An exchange of stores, its terms carried by the envoy.
    case trade

    public var title: String {
        switch self {
        case .peace: return "Peace"
        case .pact: return "Pact"
        case .fealty: return "Fealty"
        case .tribute: return "Tribute"
        case .trade: return "Trade"
        }
    }

    /// What an envoy offers, as a sentence says it: "peace", "a pact".
    public var offered: String {
        switch self {
        case .peace: return "peace"
        case .pact: return "a pact"
        case .fealty: return "fealty"
        case .tribute: return "tribute"
        case .trade: return "trade"
        }
    }
}

/// An offer from one House, waiting on the answer of a House held by a
/// keeper.
public struct Envoy: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let from: Int
    /// The kept House it waits on.
    public let to: Int
    public let proposal: Proposal
    public let arrived: Int
    /// A keeper's own words, carried with the offer.
    public let words: String?
    /// The terms of an offer of trade.
    public let trade: Trade?

    public init(id: Int, from: Int, to: Int = 0, proposal: Proposal, arrived: Int, words: String? = nil, trade: Trade? = nil) {
        self.id = id
        self.from = from
        self.to = to
        self.proposal = proposal
        self.arrived = arrived
        self.words = words
        self.trade = trade
    }

    private enum CodingKeys: String, CodingKey {
        case id, from, to, proposal, arrived, words, trade
    }

    /// Longest words an envoy carries.
    public static let wordsLimit = 140

    /// A keeper's words as an envoy will carry them: one line of plain
    /// speech, at most `wordsLimit` characters, with no addresses; nil if
    /// nothing is left to say.
    public static func carried(_ text: String) -> String? {
        let allowed = CharacterSet.letters.union(.decimalDigits).union(CharacterSet(charactersIn: " .,;:!?'’\"“”()-–—…"))
        let kept = String(String.UnicodeScalarView(text.unicodeScalars.map { allowed.contains($0) ? $0 : " " }))
        let line = kept.split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
        let lowered = line.lowercased()
        guard !line.isEmpty, line.contains(where: \.isLetter),
              !lowered.contains("http"), !lowered.contains("www"), !lowered.contains(".com") else { return nil }
        return String(line.prefix(wordsLimit))
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(Int.self, forKey: .id)
        from = try container.decode(Int.self, forKey: .from)
        to = try container.decodeIfPresent(Int.self, forKey: .to) ?? 0
        proposal = try container.decode(Proposal.self, forKey: .proposal)
        arrived = try container.decode(Int.self, forKey: .arrived)
        words = try container.decodeIfPresent(String.self, forKey: .words)
        trade = try container.decodeIfPresent(Trade.self, forKey: .trade)
    }

    /// Watches an envoy waits for an answer.
    public static let patience = 3
}
