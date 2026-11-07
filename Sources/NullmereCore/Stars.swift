/// A commander's stars (after Rise of Kingdoms' commander stars and
/// sculptures): every commander comes with one star, and rises to five as
/// its House sets carved likenesses of it, sculptures, at its seat. Each
/// star past the first gives the company it leads more strength in attack
/// and defence, and the commander a talent point more. Sculptures are won
/// where the realm's hardest fights are: a share of every lair a House's
/// companies break, more to the rally's caller, and the Ring's honours.
extension Commander {
    /// The stars it has: one until it is raised.
    public var starCount: Int { stars ?? 1 }

    /// The most stars a commander rises to.
    public static let mostStars = 5

    /// What each star past the first gives the company it leads, in each
    /// of attack and defence, in percent.
    public static let starEdge = 3

    /// Sculptures to raise a commander from `stars` to the next.
    public static func sculpturesToRaise(from stars: Int) -> Int? {
        guard stars < mostStars else { return nil }
        return 10 << (stars - 1)
    }

    /// Its stars as its line tells them on the Mac and the phone: what the
    /// next asks and how many sculptures its House keeps, or all of them.
    public func starsSaid(kept: Int) -> String {
        guard let cost = Commander.sculpturesToRaise(from: starCount) else { return "All \(Commander.mostStars) stars" }
        return "Next star: \(cost) sculptures, \(kept) kept"
    }
}

extension GameState {
    /// The sculptures a House keeps, not yet set.
    public func sculptures(of house: Int) -> Int {
        sculptureCounts?[house] ?? 0
    }

    /// Sculptures for each level of a lair broken, to each House of the
    /// host that struck it; its caller the same again.
    public static let sculpturesPerLairLevel = 2
    /// Sculptures for the Ring's honoured, first to third.
    public static let ringSculptures = [6, 4, 2]

    mutating func giveSculptures(_ count: Int, to house: Int) -> [GameEvent] {
        guard count > 0, houses.indices.contains(house), !houses[house].isEliminated else { return [] }
        var kept = sculptureCounts ?? [:]
        kept[house, default: 0] += count
        sculptureCounts = kept
        return [.sculpturesFound(house: house, count: count)]
    }

    /// Why a House can't raise a commander's stars now, if it can't.
    public func starRefusal(of commanderID: Int, as house: Int) -> RuleError? {
        guard let commander = commander(commanderID), commander.owner == house, commander.captive == nil else { return .unknownCommander }
        guard let cost = Commander.sculpturesToRaise(from: commander.starCount) else { return .starsFull }
        guard sculptures(of: house) >= cost else { return .needsSculptures(cost) }
        return nil
    }

    /// A steward sets its sculptures for its highest commander first, a
    /// star at a time while they last.
    mutating func raiseStars(for house: Int) -> [GameEvent] {
        var events: [GameEvent] = []
        let order = commanders(of: house).sorted { ($0.level, -$0.id) > ($1.level, -$1.id) }.map(\.id)
        for id in order {
            while starRefusal(of: id, as: house) == nil {
                events += (try? raiseStar(of: id, as: house)) ?? []
            }
        }
        return events
    }

    mutating func raiseStar(of commanderID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = starRefusal(of: commanderID, as: house) { throw refusal }
        let index = commanderIndex(commanderID)!
        let cost = Commander.sculpturesToRaise(from: commanders![index].starCount)!
        sculptureCounts![house]! -= cost
        commanders![index].stars = commanders![index].starCount + 1
        let stars = commanders![index].starCount
        record(.commander, [house], "\(houses[house].title) sets \(cost) likenesses of \(commanders![index].name) at its seat: "
            + "\(stars) stars.")
        return [.commanderStarred(commander: commanderID, house: house, stars: stars)]
    }
}
