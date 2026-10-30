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
        case tribute
        case ending
        /// An omen falls on the realm, or lifts.
        case omen
        /// One House sends another a generous gift.
        case gift
        /// Two Houses trade stores in quantity.
        case trade
        /// A keeper takes up a House, or a House waits for another keeper.
        case seating
        /// A House masters a study that changes what it can do.
        case learning
        /// A commander comes to a House, or rises to renown.
        case commander
        /// A great company of the wilds falls.
        case hunt
        /// A battle of many companies is fought out.
        case battle
        /// An alliance is founded, joined, left or led anew, or is no more.
        case alliance
        /// A rally's host falls upon a hold.
        case rally
        /// A happening of the realm begins, or ends with its foremost honoured.
        case happening
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
