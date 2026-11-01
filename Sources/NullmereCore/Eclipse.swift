/// The Eclipse: at the full moon of the sixtieth watch, and of every
/// ninetieth after, the moon is eaten, and the age drowned beneath this one
/// walks. From each of its greatest holds, six at most, rises a company of
/// the Drowned bearing a keepsake of that hold, its level as the works the
/// hold had. For five watches they walk the shore as the wilds do, every
/// House's foe; struck down, each gives up its keepsake with its spoils,
/// moonsalt for the House that laid it to rest, and the Chronicle names
/// the hold. Then the moon comes back and those still walking sink again.
/// Only an age with an age drowned beneath it has an eclipse, so a world's
/// first age goes as it always did.
extension GameState {
    /// The first eclipse's watch, and the watches between eclipses.
    public static let firstEclipse = 60
    public static let eclipseEvery = 90
    /// The most of the Drowned an eclipse raises, and the watches they walk.
    public static let eclipseRisen = 6
    public static let eclipseLasts = 5

    /// Whether the moon is eaten at a watch.
    public static func isEclipse(at watch: Int) -> Bool {
        watch >= firstEclipse && (watch - firstEclipse) % eclipseEvery == 0
    }

    /// The watches until the next eclipse; 0 at one.
    public static func watchesToEclipse(from watch: Int) -> Int {
        guard watch > firstEclipse else { return firstEclipse - watch }
        let since = (watch - firstEclipse) % eclipseEvery
        return since == 0 ? 0 : eclipseEvery - since
    }

    /// What a keepsake of the drowned age brings, for each level of the
    /// company that bore it.
    public static let keepsake = Stock(moonsalt: 6)

    /// The Drowned of the eclipse walking now, each with the name of the
    /// hold whose keepsake it bears.
    public var drownedWalking: [Wild] { wildsStanding.filter { $0.keepsake != nil } }

    /// As the watch turns: at an eclipse, the Drowned rise from the drowned
    /// age's greatest holds, on their ground or the nearest open ground
    /// within two tiles; and those an eclipse raised sink again once they
    /// have walked their watches.
    mutating func turnTheEclipse() -> [GameEvent] {
        var events: [GameEvent] = []
        if let walking = wilds, walking.contains(where: { $0.keepsake != nil && watch - $0.raised >= GameState.eclipseLasts }) {
            let sinking = walking.filter { $0.keepsake != nil && watch - $0.raised >= GameState.eclipseLasts }
            wilds = walking.filter { wild in !sinking.contains { $0.id == wild.id } }
            events.append(.eclipseEnded(sank: sinking.count))
        }
        guard GameState.isEclipse(at: watch), !drownedHolds.isEmpty else { return events }
        let greatest = drownedHolds.sorted { ($0.works, $0.spire, $1.name) > ($1.works, $1.spire, $0.name) }.prefix(GameState.eclipseRisen)
        var risen = 0
        if wilds == nil { wilds = [] }
        for hold in greatest {
            guard let at = hold.position.spiral(2).first(where: { hex in
                guard let tile = map[hex], tile.terrain.isPassable, !tile.terrain.isWater else { return false }
                return !isOccupied(hex) && shrine(at: hex) == nil
            }) else { continue }
            let level = min(Wild.highestLevel, max(1, 1 + hold.works / 3))
            wilds!.append(Wild(id: takeID(), kind: .drowned, level: level, position: at, raised: watch, keepsake: hold.name))
            risen += 1
        }
        guard risen > 0 else { return events }
        record(.happening, [], "The moon is eaten. From the drowned holds of the age before, \(risen == 1 ? "a company" : "\(risen) companies") "
               + "of the Drowned rise, each bearing a keepsake of its hold, until the moon comes back.")
        return events + [.eclipse(risen: risen)]
    }
}
