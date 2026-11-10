import Foundation

// The Rankings, as Rise of Kingdoms keeps its boards of power and of kill
// points: every House, and every alliance by its Houses, ranked by its might
// as the realm reckons it, or by the troops of other Houses it has slain this
// age. Known to every keeper, as the realm tells every House's might.

/// What a ranking ranks by.
public enum RankedBy: String, CaseIterable, Codable, Sendable, Identifiable {
    /// Might, as the realm reckons it (`GameState.might(of:)`).
    case might
    /// The troops of other Houses slain this age (`GameState.slain(by:)`).
    case slain

    public var id: String { rawValue }

    /// On its button: "Might", "Foes slain".
    public var title: String {
        switch self {
        case .might: return "Might"
        case .slain: return "Foes slain"
        }
    }

    /// As a line says it: "by might", "by foes slain".
    public var said: String { "by \(title.lowercased())" }
}

/// A line of a ranking: its place, whose it is and its figure.
public struct RankingLine: Equatable, Sendable, Identifiable {
    /// The House's id, or the alliance's.
    public let id: Int
    /// Its place, the foremost first.
    public let place: Int
    /// The House's title, or the alliance's name.
    public let name: String
    /// Its might, or the foes it has slain.
    public let figure: Int
    /// The keeper's own House, or their alliance.
    public let isOwn: Bool
    /// Beneath its name: the alliance a House is sworn to, or how many
    /// Houses an alliance has; nil for a House sworn to none.
    public let note: String?

    /// As VoiceOver says it: "4th, House Orren, of the Salt Pact: might
    /// 1,240".
    public func said(_ by: RankedBy) -> String {
        let of = note.map { ", \($0)" } ?? ""
        let figure = by == .might ? "might \(GameState.counted(self.figure))" : "\(GameState.counted(self.figure)) foes slain"
        return "\(place)\(ordinalEnding(place)), \(name)\(of): \(figure)"
    }
}

/// A ranking as the Rankings show it: the foremost, and the keeper's own
/// line beneath them where it stands lower.
public struct Ranking: Equatable, Sendable, Identifiable {
    public var id: String { "\(alliances ? "alliances" : "houses").\(by.rawValue)" }
    public let by: RankedBy
    /// Alliances ranked, not Houses.
    public let alliances: Bool
    /// The foremost, in their places.
    public let lines: [RankingLine]
    /// The keeper's own line, where it stands below the foremost shown;
    /// nil where it is among them or not ranked.
    public let own: RankingLine?
    /// How many are ranked: those with any might, or any foes slain.
    public let count: Int
    /// The keeper's own place, its House's or its alliance's; nil where it
    /// is not ranked.
    public let place: Int?
    /// Where the keeper's own stands, in a line: "Your House stands fourth
    /// of 12 by might." Nil for a keeper of no House.
    public let standing: String?

    /// Its title: "Houses by might", "Alliances by foes slain".
    public var title: String { "\(alliances ? "Alliances" : "Houses") \(by.said)" }

    /// What it says while none is ranked.
    public var none: String {
        switch (alliances, by) {
        case (false, .might): return "No House stands."
        case (false, .slain): return "No House has slain a foe this age."
        case (true, .might): return "No alliance stands."
        case (true, .slain): return "No alliance's Houses have slain a foe this age."
        }
    }
}

extension GameState {
    /// The most lines a ranking shows above the keeper's own.
    public static let rankingShown = 10

    // MARK: Foes slain

    /// The troops of other Houses a House has slain this age.
    public func slain(by house: Int) -> Int {
        guard let foesSlain, foesSlain.indices.contains(house) else { return 0 }
        return foesSlain[house]
    }

    /// Each House's foes slain counted from what was done: a blow on
    /// another House's company counts what it felled to its striker's
    /// House, and what that company slew of its striker in return to its
    /// own; a hold's walls count what they slew of those striking them to
    /// the hold's House. Only blows between two Houses count: the wilds
    /// count for none, as Rise of Kingdoms' kill points count no
    /// barbarian, and nothing a House does to itself.
    mutating func countSlain(_ events: [GameEvent]) {
        for case .battle(let battle) in events where battle.attackerOwner != battle.defenderOwner
            && houses.indices.contains(battle.attackerOwner) && houses.indices.contains(battle.defenderOwner) {
            if battle.defender != nil { countSlain(battle.slain ?? 0, by: battle.attackerOwner) }
            countSlain(battle.lost ?? 0, by: battle.defenderOwner)
        }
    }

    private mutating func countSlain(_ troops: Int, by house: Int) {
        guard troops > 0, houses.indices.contains(house) else { return }
        var counts = foesSlain ?? []
        if counts.count < houses.count { counts += [Int](repeating: 0, count: houses.count - counts.count) }
        counts[house] += troops
        foesSlain = counts
    }

    // MARK: The Rankings

    /// A ranking for a keeper's House: every House standing, or every
    /// alliance by its Houses standing, by might or by foes slain, those
    /// with none left out; the foremost `most` and the keeper's own beneath
    /// them where it stands lower. Ties go to the lower id.
    public func ranking(_ by: RankedBy, alliances: Bool = false, for house: Int, most: Int = GameState.rankingShown) -> Ranking {
        let figures = rankingFigures(by)
        let sworn = alliance(of: house)
        // Each ranked with its figure, foremost first.
        var ranked: [(id: Int, figure: Int)] = []
        if alliances {
            for alliance in alliancesStanding {
                let figure = alliance.members.reduce(0) { total, member in
                    figures.indices.contains(member) && !houses[member].isEliminated ? total + figures[member] : total
                }
                if figure > 0 { ranked.append((alliance.id, figure)) }
            }
        } else {
            for house in houses where !house.isEliminated && figures[house.id] > 0 {
                ranked.append((house.id, figures[house.id]))
            }
        }
        ranked.sort { ($1.figure, $0.id) < ($0.figure, $1.id) }
        let ownID = alliances ? sworn?.id : (houses.indices.contains(house) ? house : nil)
        func line(_ at: Int) -> RankingLine {
            let (id, figure) = ranked[at]
            if alliances {
                let named = self.alliance(id)
                let count = named?.members.filter { houses.indices.contains($0) && !houses[$0].isEliminated }.count ?? 0
                return RankingLine(id: id, place: at + 1, name: named?.titled ?? "An alliance", figure: figure, isOwn: id == ownID,
                                   note: count == 1 ? "1 House" : "\(count) Houses")
            }
            return RankingLine(id: id, place: at + 1, name: houses[id].title, figure: figure, isOwn: id == ownID,
                               note: alliance(of: id).map { "of \($0.name)" })
        }
        let shown = (0..<min(max(most, 0), ranked.count)).map(line)
        let ownAt = ownID.flatMap { id in ranked.firstIndex { $0.id == id } }
        let own = ownAt.flatMap { $0 >= shown.count ? line($0) : nil }
        let place = ownAt.map { $0 + 1 }
        return Ranking(by: by, alliances: alliances, lines: shown, own: own, count: ranked.count, place: place,
                       standing: rankingStanding(by, alliances: alliances, for: house, place: place, of: ranked.count))
    }

    /// Every ranking for a keeper's House, as the Rankings offer them: the
    /// Houses by might and by foes slain, then the alliances.
    public func rankings(for house: Int, most: Int = GameState.rankingShown) -> [Ranking] {
        [false, true].flatMap { alliances in RankedBy.allCases.map { ranking($0, alliances: alliances, for: house, most: most) } }
    }

    /// Where a keeper's House stands, in a line, as the Rankings fold to:
    /// "Your House stands fourth of 12 by might and second of 5 by foes
    /// slain." Nil for a keeper of no House.
    public func rankingsSaid(for house: Int) -> String? {
        guard houses.indices.contains(house), !houses[house].isEliminated else { return nil }
        let might = ranking(.might, for: house, most: 0), slain = ranking(.slain, for: house, most: 0)
        let byMight = might.place.map { "stands \(briefOrdinal($0)) of \(GameState.counted(might.count)) by might" }
        let bySlain = slain.place.map { "\(briefOrdinal($0)) of \(GameState.counted(slain.count)) by foes slain" }
        switch (byMight, bySlain) {
        case let (might?, slain?): return "Your House \(might) and \(slain)."
        case let (might?, nil): return "Your House \(might) and has slain no foe this age."
        case let (nil, slain?): return "Your House stands \(slain)."
        case (nil, nil): return "Your House is not yet ranked."
        }
    }

    /// Each House's figure by its id: its might, or the foes it has slain.
    private func rankingFigures(_ by: RankedBy) -> [Int] {
        switch by {
        case .might: return houses.map { might(of: $0.id) }
        case .slain: return houses.indices.map { slain(by: $0) }
        }
    }

    /// Where the keeper's own stands in a ranking, in a line.
    private func rankingStanding(_ by: RankedBy, alliances: Bool, for house: Int, place: Int?, of count: Int) -> String? {
        guard houses.indices.contains(house), !houses[house].isEliminated else { return nil }
        let whose = alliances ? "Your alliance" : "Your House"
        if alliances, alliance(of: house) == nil { return "Your House is sworn to no alliance." }
        if let place { return "\(whose) stands \(briefOrdinal(place)) of \(GameState.counted(count)) \(by.said)." }
        switch by {
        case .might: return "\(whose) has no might to rank."
        case .slain: return alliances ? "Your alliance's Houses have slain no foe this age." : "Your House has slain no foe this age."
        }
    }
}
