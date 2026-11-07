import Foundation

/// The Houses a keeper is offered to name in a whisper, a prophecy or a
/// title. In a lake of up to ninety-six seats, every House, in the order of
/// their seats. Past that, a button for each of a thousand Houses would bury
/// the few a keeper means, so they are offered the Houses they have reason
/// to name, nearest their seat first, and may find any other by its name.
public struct HouseChoice: Equatable, Sendable {
    /// The Houses offered.
    public let offered: [House]
    /// Whether the keeper may look for a House by its name: in a realm of
    /// more Houses standing than a chooser offers whole.
    public let searchable: Bool
    /// How many more Houses go by the name looked for than are offered.
    public let more: Int

    /// The most Houses standing a chooser offers whole: every House of a
    /// lake of up to ninety-six seats.
    public static let shownWhole = Standing.shownWhole
    /// The seats nearest a keeper's own that a wider realm's chooser offers.
    public static let nearest = 12
    /// The most Houses a name looked for finds at once.
    public static let found = 24

    /// What a wider realm's chooser says it offers.
    public static let offeredLine = "Your neighbours, your alliance, the Houses you have dealt with and the race's leaders; any other found by its name."

    /// What is said under the Houses a name found: how many more go by it,
    /// or that none the keeper may name does.
    public static func foundLine(_ choice: HouseChoice, query: String) -> String? {
        if choice.more > 0 {
            return choice.more == 1
                ? "1 more House goes by such a name: give more of it to find it."
                : "\(choice.more) more Houses go by such a name: give more of it to find them."
        }
        if choice.offered.isEmpty, !folded(query).isEmpty { return "None of the Houses you may name goes by such a name." }
        return nil
    }

    /// A name as it is looked for: whatever its case and accents, without
    /// the spaces about it, and without "House" before it, since every
    /// House's name is looked for after it.
    static func folded(_ text: String) -> String {
        let plain = text.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard plain.hasPrefix("house") else { return plain }
        let after = plain.dropFirst("house".count)
        return after.isEmpty || after.first == " " ? after.trimmingCharacters(in: .whitespaces) : plain
    }
}

extension GameState {
    /// The Houses a keeper of `house` is offered to name, among those
    /// standing but the `excluding`. In a realm of up to ninety-six Houses
    /// standing, every one, in the order of their seats, whatever is looked
    /// for. Past that, those the keeper has reason to name: their own, if it
    /// is not excluded; their alliance's; their liege and their vassals;
    /// every House they have dealt with; the dozen whose seats are nearest
    /// theirs; and the dozen leading the race; nearest their seat first.
    /// With a name looked for (`query`), the Houses whose name holds it,
    /// among them all, nearest first, two dozen at most. The race is
    /// `standings` where it is already worked out, else worked out here.
    public func houseChoice(by house: Int, matching query: String = "", excluding: Set<Int> = [],
                            standings race: [Standing]? = nil) -> HouseChoice {
        let living = livingIDs
        let candidates = living.filter { !excluding.contains($0) }
        guard living.count > HouseChoice.shownWhole else {
            return HouseChoice(offered: candidates.map { houses[$0] }, searchable: false, more: 0)
        }
        // How far each House's seat lies from the keeper's; a House with no
        // seat, or a keeper without one, after every seat.
        let home = seat(of: house)?.position
        var distance = [Int](repeating: Int.max, count: houses.count)
        if let home {
            for other in candidates { distance[other] = seat(of: other).map { home.distance(to: $0.position) } ?? Int.max }
        }
        let nearestFirst = candidates.sorted { (distance[$0], $0) < (distance[$1], $1) }

        let wanted = HouseChoice.folded(query)
        if !wanted.isEmpty {
            let named = nearestFirst.filter { HouseChoice.folded(houses[$0].name).contains(wanted) }
            return HouseChoice(offered: named.prefix(HouseChoice.found).map { houses[$0] }, searchable: true,
                               more: max(0, named.count - HouseChoice.found))
        }

        var reasons: Set<Int> = [house]
        reasons.formUnion(alliance(of: house)?.members ?? [])
        if houses.indices.contains(house), let liege = houses[house].liege { reasons.insert(liege) }
        for other in living where houses[other].liege == house { reasons.insert(other) }
        for relation in relations where relation.first == house || relation.second == house {
            reasons.insert(relation.other(than: house))
        }
        reasons.formUnion(nearestFirst.lazy.filter { $0 != house }.prefix(HouseChoice.nearest))
        reasons.formUnion((race ?? standings()).prefix(Standing.leaders).map(\.house))
        return HouseChoice(offered: nearestFirst.filter { reasons.contains($0) }.map { houses[$0] }, searchable: true, more: 0)
    }
}
