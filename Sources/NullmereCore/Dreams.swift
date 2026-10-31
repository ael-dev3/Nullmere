import Foundation

/// Dreams of the Still: at the dark of each moon the lake shows every
/// keeper's House, in a dream, one true thing it cannot see: the greatest
/// host on the lake and where it stands, the fullest stores and whose they
/// are, or a drowned ruin no company has searched. The realm chooses what
/// is shown, by the moon and the House, with no chance in it; the keeper's
/// own Mac puts it in the Still's words. Stewards dream nothing, so a world
/// of stewards goes as it always did.
public struct Dream: Codable, Equatable, Sendable {
    /// What the Still shows.
    public enum Sight: Codable, Equatable, Sendable {
        /// The greatest host on the lake not the dreamer's: whose, how many
        /// troops, and where its largest company stands.
        case host(house: Int, troops: Int, at: Hex)
        /// The fullest stores on the lake not the dreamer's: whose, and what
        /// they hold.
        case hoard(house: Int, stock: Stock)
        /// A drowned ruin no company has searched, where the dreamer has
        /// never been.
        case ruin(at: Hex)
    }

    /// The House that dreamed.
    public let house: Int
    /// The watch it woke to.
    public let watch: Int
    public let sight: Sight

    public init(house: Int, watch: Int, sight: Sight) {
        self.house = house
        self.watch = watch
        self.sight = sight
    }
}

extension GameState {
    /// The moon's age at which the Still dreams: its dark.
    public static let dreamingMoon = lunarMonth / 2
    /// The dreams a House keeps: its last few.
    public static let dreamsKept = 4

    /// A House's dreams, the latest last.
    public func dreams(of house: Int) -> [Dream] {
        (dreams ?? []).filter { $0.house == house }
    }

    /// What the Still would show a House now, if anything: the sight of
    /// this moon's turn among the three, or the next that has something to
    /// show.
    public func sight(for house: Int) -> Dream.Sight? {
        let others = livingHouses.map(\.id).filter { $0 != house }
        let turn = watch / GameState.lunarMonth + house
        for step in 0..<3 {
            switch (turn + step) % 3 {
            case 0:
                let hosts = others.map { other in (other, units(of: other).reduce(0) { $0 + troops(of: $1) }) }
                if let (other, troops) = hosts.max(by: { ($0.1, $1.0) < ($1.1, $0.0) }), troops > 0,
                   let largest = units(of: other).max(by: { (self.troops(of: $0), $1.id) < (self.troops(of: $1), $0.id) }) {
                    return .host(house: other, troops: troops, at: largest.position)
                }
            case 1:
                func worth(_ stock: Stock) -> Int { Resource.allCases.reduce(0) { $0 + stock[$1] * $1.worth } }
                let hoards = others.map { ($0, houses[$0].stock) }
                if let (other, stock) = hoards.max(by: { (worth($0.1), $1.0) < (worth($1.1), $0.0) }), worth(stock) > 0 {
                    return .hoard(house: other, stock: stock)
                }
            default:
                let explored = houses.indices.contains(house) ? houses[house].explored : []
                let unseen = map.hexes.indices.filter { index in
                    map[index].feature == .drownedRuin && !(explored.indices.contains(index) && explored[index])
                }
                if let index = unseen.first {
                    return .ruin(at: map.hexes[index])
                }
            }
        }
        return nil
    }

    /// At the dark of the moon, every keeper's House dreams.
    mutating func dream() -> [GameEvent] {
        guard GameState.moonAge(at: watch) == GameState.dreamingMoon else { return [] }
        var events: [GameEvent] = []
        for house in houses where house.isPlayer && !house.isEliminated {
            guard let sight = sight(for: house.id) else { continue }
            let dream = Dream(house: house.id, watch: watch, sight: sight)
            var kept = dreams ?? []
            kept.append(dream)
            let theirs = kept.filter { $0.house == house.id }
            if theirs.count > GameState.dreamsKept, let oldest = kept.firstIndex(of: theirs[0]) {
                kept.remove(at: oldest)
            }
            dreams = kept
            events.append(.dreamt(dream))
        }
        return events
    }

    /// A dream told plainly: what the Still showed, true to the word.
    public func told(_ dream: Dream) -> String {
        func whose(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "a fallen House" }
        switch dream.sight {
        case .host(let house, let troops, let at):
            return "The Still showed you the greatest host on the lake: \(whose(house))'s, \(GameState.counted(troops)) troops, "
                + "its largest company \(whereabouts(of: at))."
        case .hoard(let house, let stock):
            return "The Still showed you the fullest stores on the lake: \(whose(house))'s, \(stock)."
        case .ruin(let at):
            return "The Still showed you a drowned ruin no company has searched, \(whereabouts(of: at))."
        }
    }

    /// Where a hex lies, as a dream would say it: in its region of the
    /// shores where the world has them, or by the lake's quarter.
    public func whereabouts(of hex: Hex) -> String {
        if let region = region(of: hex) { return "in \(region.name)" }
        let centre = HexLayout().center(of: hex)
        let quarters = ["east", "south-east", "south", "south-west", "west", "north-west", "north", "north-east"]
        let angle = atan2(centre.y, centre.x)
        let quarter = Int(((angle < 0 ? angle + 2 * .pi : angle) / (2 * .pi) * 8).rounded()) % 8
        return "on the lake's \(quarters[quarter]) shore"
    }
}
