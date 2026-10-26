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

    public init(first: Int, second: Int, stance: Stance = .peace, since: Int = 1) {
        self.first = min(first, second)
        self.second = max(first, second)
        self.stance = stance
        self.since = since
        self.aggressor = nil
        self.betrayals = 0
    }

    public func involves(_ house: Int) -> Bool {
        first == house || second == house
    }

    public func other(than house: Int) -> Int {
        first == house ? second : first
    }
}

/// What one House can offer another.
public enum Proposal: String, Codable, CaseIterable, Sendable {
    case peace
    case pact
    /// A beaten House offers to become the other's vassal: a pact it can't
    /// break, and its holds counted toward its liege's dominion.
    case fealty

    public var title: String {
        switch self {
        case .peace: return "Peace"
        case .pact: return "Pact"
        case .fealty: return "Fealty"
        }
    }
}

/// A rival House's offer, waiting for the player's answer.
public struct Envoy: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let from: Int
    public let proposal: Proposal
    public let arrived: Int

    /// Watches an envoy waits for an answer.
    public static let patience = 3
}
