/// One line of the lake's history. The chronicle keeps what mattered:
/// foundings, wars, pacts and their breaking, sieges, falls, great works.
public struct ChronicleEntry: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        case beginning
        case founding
        case war
        case peace
        case pact
        case betrayal
        case capture
        case fall
        case greatWork
        case discovery
        case ending
    }

    public let watch: Int
    public let kind: Kind
    /// The Houses involved, for filtering and colour.
    public let houses: [Int]
    public let text: String
}

/// How a game ends.
public struct Outcome: Codable, Equatable, Sendable {
    public enum Kind: String, Codable, Sendable {
        /// Every other House has fallen.
        case dominion
        /// The Moonspire stands complete.
        case ascendancy
    }

    public let winner: Int
    public let kind: Kind
    public let watch: Int
}
