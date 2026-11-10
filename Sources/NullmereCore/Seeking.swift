/// What a keeper seeks on the land, as Rise of Kingdoms' search on its map
/// finds the barbarians and the resource points: the wilds to strike, a
/// site of a store to work, a lair to rally on, a holy site to take, a
/// hamlet or barrow the House's Lanterns have yet to seek; among what the
/// House has seen, the nearest first.
public enum Seeking: String, CaseIterable, Codable, Sendable {
    case wilds, grain, timber, stone, moonsalt, lairs, shrines, finds

    /// Its name on the keeper's search: "Wilds", "Holy sites".
    public var title: String {
        switch self {
        case .wilds: return "Wilds"
        case .grain: return "Grain"
        case .timber: return "Timber"
        case .stone: return "Stone"
        case .moonsalt: return "Moonsalt"
        case .lairs: return "Lairs"
        case .shrines: return "Holy sites"
        case .finds: return "Finds"
        }
    }

    /// What is sought, in the midst of a line: "the wilds", "a site of
    /// timber", "a holy site".
    public var sought: String {
        switch self {
        case .wilds: return "the wilds"
        case .grain, .timber, .stone, .moonsalt: return "a site of \(rawValue)"
        case .lairs: return "a lair of the wilds"
        case .shrines: return "a holy site"
        case .finds: return "a hamlet or barrow"
        }
    }

    /// When the House has seen none: "Your House has seen no site of
    /// timber to work."
    public var noneSeen: String {
        switch self {
        case .wilds: return "Your House has seen none of the wilds standing."
        case .grain, .timber, .stone, .moonsalt: return "Your House has seen no site of \(rawValue) to work."
        case .lairs: return "Your House has seen no lair of the wilds standing."
        case .shrines: return "Your House has seen no holy site it does not hold."
        case .finds: return "Your House has seen no hamlet or barrow its Lanterns have yet to seek."
        }
    }

    /// The store a site sought yields.
    public var store: Resource? {
        switch self {
        case .grain: return .grain
        case .timber: return .timber
        case .stone: return .stone
        case .moonsalt: return .moonsalt
        case .wilds, .lairs, .shrines, .finds: return nil
        }
    }
}

extension GameState {
    /// The places of a kind a House has seen, the nearest to `here` first
    /// (then by place, so a search always finds them in the same order):
    /// the wilds standing on ground it has explored (a keeper's view holds
    /// only those in its sight, so on the Mac and the phone, those); sites of a store on
    /// such ground, the land's own or its own alliance's yards, not another
    /// alliance's, which only that alliance may work; lairs standing there;
    /// holy sites it does not hold; and the hamlets and barrows its Lanterns
    /// have yet to seek.
    public func seek(_ seeking: Seeking, from here: Hex, by house: Int) -> [Hex] {
        let seen: [Hex]
        switch seeking {
        case .wilds:
            seen = wildsStanding.map(\.position).filter { isExplored($0, by: house) }
        case .grain, .timber, .stone, .moonsalt:
            let ours = alliance(of: house)?.id
            seen = sitesInLand.filter { $0.store == seeking.store && ($0.alliance == nil || $0.alliance == ours) && $0.remaining > 0 }
                .map(\.position).filter { isExplored($0, by: house) }
        case .lairs:
            seen = lairsStanding.map(\.position).filter { isExplored($0, by: house) }
        case .shrines:
            seen = holySites.filter { $0.holder != house }.map(\.position).filter { isExplored($0, by: house) }
        case .finds:
            seen = findsKnown(by: house).filter { !hasSought($0.id, by: house) }.map(\.position)
        }
        return seen.sorted { ($0.distance(to: here), $0.q, $0.r) < ($1.distance(to: here), $1.q, $1.r) }
    }
}
