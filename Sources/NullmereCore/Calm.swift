/// The Calm of the Still (an invention of Nullmere's): the black lake is a
/// commons every House shares and any one may break. Each watch that no
/// company of war stands on its shore or its water, the Still grows a
/// degree calmer, to ten; its calm lies over every keeper's hold on the
/// shore, which draws a tenth more moonsalt from the lake for each degree.
/// A single company of war at the water's edge as the watch turns breaks it
/// back to nothing, for every House at once, and a calm of five or more
/// broken names the Houses that broke it to the whole realm. No House owns
/// the calm, and none can keep it alone.
public enum Calm {
    /// The calmest the Still lies.
    public static let deepest = 10
    /// The calm whose breaking is told to every House.
    public static let told = 5
    /// In a hundred, the moonsalt a degree of calm adds to a hold on the shore.
    public static let moonsaltPerDegree = 10
}

extension GameState {
    /// How calm the Still lies now: zero to ten.
    public var stillCalm: Int { calm ?? 0 }

    /// Whether a hold stands on the Still's shore, its calm about it.
    public func isOnTheCalmShore(_ hold: Hold) -> Bool {
        isShore(hold.position) || map[hold.position]?.terrain.isWater == true
    }

    /// The Houses whose companies of war break the calm now: standing on
    /// the shore or on the water, or crossing it.
    public func calmBreakers() -> [Int] {
        let houses = units.filter { unit in
            unit.kind.isMilitary && (isShore(unit.position) || map[unit.position]?.terrain.isWater == true
                                     || crossing(of: unit.id) != nil)
        }.map(\.owner)
        return Array(Set(houses)).sorted()
    }

    /// The moonsalt the calm adds to a hold's yield: only a keeper's hold
    /// on the shore, a tenth for each degree.
    func calmMoonsalt(for hold: Hold, from moonsalt: Int) -> Int {
        guard stillCalm > 0, houses.indices.contains(hold.owner), houses[hold.owner].isPlayer,
              isOnTheCalmShore(hold) else { return 0 }
        return max(1, moonsalt) * Calm.moonsaltPerDegree * stillCalm / 100
    }

    /// As the watch turns: calmer by a degree if no company of war is at
    /// the water, else broken back to nothing, told if it ran deep.
    mutating func turnCalm() -> [GameEvent] {
        let breakers = calmBreakers()
        guard !breakers.isEmpty else {
            calm = min(Calm.deepest, stillCalm + 1)
            return []
        }
        let was = stillCalm
        calm = nil
        guard was >= Calm.told else { return [] }
        record(.war, breakers, "The Still's calm of \(was) watches is broken by \(listed(breakers.map { houses[$0].title })).")
        return [.calmBroken(houses: breakers, calm: was)]
    }
}
