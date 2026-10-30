/// An alliance's hall: the fortress its leader raises on the alliance's
/// own land, for stores. It rises over four watches, its ward growing as it
/// does; whole, the land three tiles about it is the alliance's, the
/// alliance's companies that keep it stand a quarter firmer, the rallies
/// its Houses call take two more companies, and the alliance may keep two
/// more standards. Only the alliance's companies may enter it. Its ward
/// mends each watch; a House at war with one of the alliance's may strike
/// it when none keeps it, and tear it down when its ward breaks.
public struct AllianceHall: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let alliance: Int
    /// The House that raised it: its alliance's leader then.
    public let raisedBy: Int
    public let position: Hex
    public internal(set) var ward: Int
    /// The watches of its raising done: whole at `AllianceHall.raising`.
    public internal(set) var built: Int
    /// The watch its raising began.
    public let begun: Int

    public init(id: Int, alliance: Int, raisedBy: Int, position: Hex, begun: Int) {
        self.id = id
        self.alliance = alliance
        self.raisedBy = raisedBy
        self.position = position
        self.ward = AllianceHall.firstWard
        self.built = 0
        self.begun = begun
    }

    /// Whether it has risen whole.
    public var isWhole: Bool { built >= AllianceHall.raising }

    /// How far its raising has come, 0 to 1.
    public var progress: Double { Double(min(built, AllianceHall.raising)) / Double(AllianceHall.raising) }

    /// The most its ward may be as it stands: it grows as the hall rises.
    public var wardLimit: Int {
        AllianceHall.firstWard + (AllianceHall.maximumWard - AllianceHall.firstWard) * min(built, AllianceHall.raising) / AllianceHall.raising
    }

    /// Its ward when whole.
    public static let maximumWard = 240
    /// Its ward as its raising begins.
    public static let firstWard = 40
    /// The watches it takes to rise.
    public static let raising = 4
    /// How far about it its land reaches, once whole.
    public static let reach = 3
    /// What raising it costs the leader who raises it.
    public static let cost = Stock(grain: 200, timber: 400, stone: 400, moonsalt: 20)
    /// Ward it mends each watch.
    public static let mending = 15
    /// How much firmer the alliance's companies keeping it stand, in percent.
    public static let garrison = 25
    /// The more companies each rally its alliance's Houses call takes.
    public static let rallyCompanies = 2
    /// The more standards its alliance may keep.
    public static let standards = 2
    /// How near another House's hold it may stand, and no nearer.
    public static let fromOthers = 3
}

extension GameState {
    /// Every alliance's hall standing or rising.
    public var hallsStanding: [AllianceHall] { halls ?? [] }

    public func hall(_ id: Int) -> AllianceHall? {
        halls?.first { $0.id == id }
    }

    public func hall(at hex: Hex) -> AllianceHall? {
        halls?.first { $0.position == hex }
    }

    /// An alliance's hall, standing or rising.
    public func hall(of alliance: Int) -> AllianceHall? {
        halls?.first { $0.alliance == alliance }
    }

    /// The hall of a House's alliance, if it stands whole.
    func wholeHall(for house: Int) -> AllianceHall? {
        guard let halls, !halls.isEmpty, let sworn = alliance(of: house) else { return nil }
        return halls.first { $0.alliance == sworn.id && $0.isWhole }
    }

    /// Whether a House is of a hall's alliance, and may enter it.
    public func isOfHall(_ house: Int, _ hall: AllianceHall) -> Bool {
        alliance(hall.alliance)?.members.contains(house) == true
    }

    /// Whether a House may strike a hall: at war with one of its alliance's
    /// Houses.
    public func isFoe(_ house: Int, of hall: AllianceHall) -> Bool {
        guard let sworn = alliance(hall.alliance), !sworn.members.contains(house) else { return false }
        return sworn.members.contains { isAtWar(house, $0) }
    }

    /// The standards an alliance may keep: one, and one more for each of
    /// its Houses, eight at most; two more while its hall stands whole.
    public func standardsAllowed(for alliance: Alliance) -> Int {
        Standard.allowed(members: alliance.members.count) + (hall(of: alliance.id)?.isWhole == true ? AllianceHall.standards : 0)
    }

    /// Why a House can't raise its alliance's hall at a hex, if it can't.
    func hallRefusal(at hex: Hex, by house: Int) -> RuleError? {
        guard let sworn = alliance(of: house) else { return .notInAlliance }
        guard sworn.leader == house else { return .notAllianceLeader }
        guard hall(of: sworn.id) == nil else { return .hallStanding }
        guard let tile = map[hex] else { return .outsideTheWorld }
        guard isExplored(hex, by: house) else { return .unexplored }
        guard tile.terrain.isPassable, !tile.terrain.isWater else { return .impassable(tile.terrain) }
        guard !isOccupied(hex), site(at: hex) == nil, shrine(at: hex) == nil else { return .hallGround }
        guard allianceLand(at: hex) == sworn.id else { return .notAllianceLand }
        guard holds.allSatisfy({ sworn.members.contains($0.owner) || $0.position.distance(to: hex) > AllianceHall.fromOthers }),
              standardsStanding.allSatisfy({ $0.alliance == sworn.id || $0.position.distance(to: hex) > AllianceHall.reach + Standard.reach }),
              hallsStanding.allSatisfy({ $0.position.distance(to: hex) > 2 * AllianceHall.reach }) else {
            return .foreignTerritory
        }
        guard houses[house].stock.covers(AllianceHall.cost) else { return .shortOf(houses[house].stock.shortfall(for: AllianceHall.cost)) }
        return nil
    }

    /// An alliance's leader begins its hall at a hex, for its stores.
    mutating func raiseHall(at hex: Hex, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = hallRefusal(at: hex, by: house) { throw refusal }
        let sworn = alliance(of: house)!
        houses[house].stock.debit(AllianceHall.cost)
        let hall = AllianceHall(id: takeID(), alliance: sworn.id, raisedBy: house, position: hex, begun: watch)
        halls = hallsStanding + [hall]
        record(.alliance, sworn.members, "\(houses[house].title) begins the hall of \(sworn.name) \(placeName(of: hex)).")
        return [.hallRaised(hall: hall.id, alliance: sworn.id, house: house, at: hex)]
    }

    /// A company strikes the hall of an alliance at war with its House:
    /// its ward broken, the hall is torn down.
    mutating func strike(hall hallID: Int, with unitID: Int) -> [GameEvent] {
        guard let index = halls?.firstIndex(where: { $0.id == hallID }), let unitIndex = unitIndex(unitID) else { return [] }
        let unit = units[unitIndex]
        units[unitIndex].movesLeft = 0
        units[unitIndex].acted = true
        units[unitIndex].fortified = false
        units[unitIndex].destination = nil
        units[unitIndex].errand = nil
        var random = random()
        let damage = wardDamage(by: unit) * random.int(in: 80...120) / 100
        halls![index].ward = max(0, halls![index].ward - damage)
        let hall = halls![index]
        var events: [GameEvent] = [.hallStruck(hall: hallID, alliance: hall.alliance, ward: hall.ward, by: unit.owner, at: hall.position)]
        events += gainExperience(unitID)
        if hall.ward == 0 {
            halls!.remove(at: index)
            fitRallies()
            events.append(.hallTorn(hall: hallID, alliance: hall.alliance, by: unit.owner, at: hall.position))
            if let alliance = alliance(hall.alliance), houses.indices.contains(unit.owner) {
                record(.alliance, [unit.owner] + alliance.members,
                       "\(houses[unit.owner].title) tears down the hall of \(alliance.name) \(placeName(of: hall.position)).")
            }
        }
        return events
    }

    /// As the watch turns: a hall whose alliance is no more comes down; a
    /// hall rising rises a watch further, its ward with it; every hall's
    /// ward mends.
    mutating func keepHalls() -> [GameEvent] {
        guard var list = halls else { return [] }
        var events: [GameEvent] = []
        list.removeAll { hall in
            let kept = alliance(hall.alliance) != nil
            if !kept { events.append(.hallTorn(hall: hall.id, alliance: hall.alliance, by: nil, at: hall.position)) }
            return !kept
        }
        for index in list.indices {
            if !list[index].isWhole {
                let before = list[index].wardLimit
                list[index].built += 1
                list[index].ward += list[index].wardLimit - before
                if list[index].isWhole, let alliance = alliance(list[index].alliance) {
                    events.append(.hallRisen(hall: list[index].id, alliance: alliance.id, at: list[index].position))
                    record(.alliance, alliance.members, "The hall of \(alliance.name) stands whole \(placeName(of: list[index].position)).")
                }
            }
            list[index].ward = min(list[index].wardLimit, list[index].ward + AllianceHall.mending)
        }
        halls = list
        return events
    }
}
