/// Alliance land: a House of an alliance raises a standard on open land
/// near the alliance's holds, and the land about it, two tiles each way,
/// is the alliance's. There its companies stand firmer, mend sooner and
/// gather more at the land's sites. A standard has a ward of its own; a
/// House at war with the one that raised it may strike it, and tear it
/// down when its ward breaks. Like Rise of Kingdoms' alliance flags it is
/// not planted whole: it rises over `Standard.raising` watches, its land
/// the alliance's only once it stands, and each other House of the
/// alliance may lend hands and stores to raise it a watch sooner.
public struct Standard: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let alliance: Int
    /// The House that raised it and keeps it.
    public let raisedBy: Int
    public let position: Hex
    public internal(set) var ward: Int
    /// The watch it was raised.
    public let raised: Int
    /// The watches of its raising done (nil: raised whole, before standards rose).
    public internal(set) var built: Int?
    /// The alliance's Houses that lent a hand to its raising.
    public internal(set) var helpers: [Int]?

    public init(id: Int, alliance: Int, raisedBy: Int, position: Hex, raised: Int) {
        self.id = id
        self.alliance = alliance
        self.raisedBy = raisedBy
        self.position = position
        self.ward = Standard.maximumWard
        self.raised = raised
        self.built = 0
    }

    /// Whether it stands whole, its land the alliance's.
    public var isWhole: Bool { (built ?? Standard.raising) >= Standard.raising }

    /// How far its raising has come, 0 to 1.
    public var progress: Double { Double(min(built ?? Standard.raising, Standard.raising)) / Double(Standard.raising) }

    /// The watches it takes to rise whole, alone.
    public static let raising = 3
    /// What a House of the alliance gives to lend a hand: a watch sooner.
    public static let helpCost = Stock(timber: 20, stone: 10)

    /// A standard's ward when whole.
    public static let maximumWard = 60
    /// How far about it its land reaches.
    public static let reach = 2
    /// How near one of the alliance's holds, standards or its hall a new one
    /// must stand.
    public static let tether = 4
    /// How near another House's hold it may stand, and no nearer.
    public static let fromOthers = 3
    /// What raising one costs the House that raises it.
    public static let cost = Stock(timber: 60, stone: 40, moonsalt: 2)
    /// Ward a struck standard mends each watch.
    public static let mending = 10

    /// What raising one does, said beside it on the Mac and the phone.
    public static let raiseSaid = "Raise a standard of your alliance here: the land two tiles about it becomes the alliance's."

    /// How it rises, said beside a hand lent to it on the Mac and the phone.
    public var risingSaid: String {
        let left = Standard.raising - (built ?? Standard.raising)
        return "It rises, whole in \(left) watch\(left == 1 ? "" : "es"); its land is the alliance's only once it stands."
    }

    /// The standards an alliance may keep: one, and one more for each of
    /// its Houses, eight at most.
    public static func allowed(members: Int) -> Int { min(8, 1 + members) }

    /// What alliance land gives the alliance's companies on it: a tenth
    /// more defence, five more health mended each watch, a fifth more
    /// gathered at its sites.
    public static let defence = 10
    public static let mendingOnLand = 5
    public static let gathering = 20
    /// And what it gives the holds of the alliance's Houses on it: a
    /// tenth more of all they yield each watch.
    public static let holdYield = 10
}

extension GameState {
    /// Every standard standing.
    public var standardsStanding: [Standard] { standards ?? [] }

    public func standard(_ id: Int) -> Standard? {
        standards?.first { $0.id == id }
    }

    public func standard(at hex: Hex) -> Standard? {
        standards?.first { $0.position == hex }
    }

    /// The standards of an alliance.
    public func standards(of alliance: Int) -> [Standard] {
        standardsStanding.filter { $0.alliance == alliance }
    }

    /// The alliance whose land a hex is, if any: that of the nearest
    /// standard, or hall standing whole, within its reach.
    public func allianceLand(at hex: Hex) -> Int? {
        var nearest: (distance: Int, id: Int, alliance: Int)?
        func consider(_ position: Hex, reach: Int, id: Int, alliance: Int) {
            let distance = position.distance(to: hex)
            guard distance <= reach else { return }
            if let best = nearest, (best.distance, best.id) <= (distance, id) { return }
            nearest = (distance, id, alliance)
        }
        for standard in standards ?? [] where standard.isWhole {
            consider(standard.position, reach: Standard.reach, id: standard.id, alliance: standard.alliance)
        }
        for hall in halls ?? [] where hall.isWhole {
            consider(hall.position, reach: AllianceHall.reach, id: hall.id, alliance: hall.alliance)
        }
        return nearest?.alliance
    }

    /// Where each alliance's land ends: every hex of it beside one that is
    /// not its land, with the way out, once for each such side, in a
    /// steady order.
    public func allianceBorders() -> [(hex: Hex, outward: Hex, alliance: Int)] {
        var sources: [Hex: Int] = [:]
        for standard in standards ?? [] where standard.isWhole { sources[standard.position] = Standard.reach }
        for hall in halls ?? [] where hall.isWhole { sources[hall.position] = max(sources[hall.position] ?? 0, AllianceHall.reach) }
        var seen = Set<Hex>()
        var borders: [(hex: Hex, outward: Hex, alliance: Int)] = []
        for (source, reach) in sources.sorted(by: { ($0.key.q, $0.key.r) < ($1.key.q, $1.key.r) }) {
            for hex in source.spiral(reach) where seen.insert(hex).inserted && map[hex] != nil {
                guard let alliance = allianceLand(at: hex) else { continue }
                for direction in Hex.directions {
                    let out = Hex(hex.q + direction.q, hex.r + direction.r)
                    if allianceLand(at: out) != alliance { borders.append((hex, direction, alliance)) }
                }
            }
        }
        return borders
    }

    /// Whether a hold stands on its own House's alliance's land.
    public func isOnAllianceLand(_ hold: Hold) -> Bool {
        guard let alliance = alliance(of: hold.owner)?.id, !standardsStanding.isEmpty || wholeHall(for: hold.owner) != nil else { return false }
        return allianceLand(at: hold.position) == alliance
    }

    /// Whether a company stands on its own alliance's land.
    func isOnOwnLand(_ unit: Unit) -> Bool {
        guard let land = allianceLand(at: unit.position) else { return false }
        return alliance(of: unit.owner)?.id == land
    }

    /// Why a House can't raise a standard at a hex, if it can't.
    public func standardRefusal(at hex: Hex, by house: Int) -> RuleError? {
        guard let sworn = alliance(of: house) else { return .notInAlliance }
        guard let tile = map[hex] else { return .outsideTheWorld }
        guard isExplored(hex, by: house) else { return .unexplored }
        guard tile.terrain.isPassable, !tile.terrain.isWater else { return .impassable(tile.terrain) }
        guard !isOccupied(hex), site(at: hex) == nil, shrine(at: hex) == nil, standard(at: hex) == nil else { return .standardGround }
        // The alliance's own ground near, and no other's: its holds looked
        // at in place, none copied, for every hex a steward weighs.
        var tethered = false, foreign = false
        for index in holds.indices {
            let distance = holds[index].position.distance(to: hex)
            if sworn.members.contains(holds[index].owner) {
                if distance <= Standard.tether { tethered = true }
            } else if distance <= Standard.fromOthers {
                foreign = true
            }
        }
        if !tethered {
            tethered = standards(of: sworn.id).contains { $0.position.distance(to: hex) <= Standard.tether }
                || hall(of: sworn.id).map { $0.position.distance(to: hex) <= Standard.tether } == true
        }
        guard tethered else { return .standardTooFar }
        guard !foreign,
              standardsStanding.allSatisfy({ $0.alliance == sworn.id || $0.position.distance(to: hex) > 2 * Standard.reach }),
              hallsStanding.allSatisfy({ $0.alliance == sworn.id || $0.position.distance(to: hex) > AllianceHall.reach + Standard.reach }) else {
            return .foreignTerritory
        }
        guard standards(of: sworn.id).count < standardsAllowed(for: sworn) else { return .standardsEnough }
        let purse = purse(of: house)
        guard purse.covers(Standard.cost) else { return .shortOf(purse.shortfall(for: Standard.cost)) }
        return nil
    }

    /// A House of an alliance raises a standard at a hex, for its
    /// alliance's coffers and its stores.
    mutating func raiseStandard(at hex: Hex, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = standardRefusal(at: hex, by: house) { throw refusal }
        let sworn = alliance(of: house)!
        spend(Standard.cost, by: house)
        let standard = Standard(id: takeID(), alliance: sworn.id, raisedBy: house, position: hex, raised: watch)
        standards = standardsStanding + [standard]
        return [.standardRaised(standard: standard.id, alliance: sworn.id, house: house, at: hex)]
    }

    /// Why a House can't lend a hand to a standard's raising, if it can't:
    /// one rising, of its own alliance, raised by another, once each.
    public func helpStandardRefusal(_ standardID: Int, by house: Int) -> RuleError? {
        guard let standard = standard(standardID) else { return .noSuchStandard }
        guard alliance(of: house)?.id == standard.alliance else { return .notInAlliance }
        guard !standard.isWhole else { return .standardWhole }
        guard standard.raisedBy != house, standard.helpers?.contains(house) != true else { return .standardHelped }
        let purse = purse(of: house)
        guard purse.covers(Standard.helpCost) else { return .shortOf(purse.shortfall(for: Standard.helpCost)) }
        return nil
    }

    /// A House lends a hand to its alliance's rising standard: a watch of
    /// its raising done now, and whole at once if that was the last.
    mutating func helpStandard(_ standardID: Int, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = helpStandardRefusal(standardID, by: house) { throw refusal }
        let index = standards!.firstIndex { $0.id == standardID }!
        spend(Standard.helpCost, by: house)
        standards![index].helpers = (standards![index].helpers ?? []) + [house]
        standards![index].built = (standards![index].built ?? 0) + 1
        let standard = standards![index]
        var events: [GameEvent] = [.standardHelped(standard: standard.id, by: house, at: standard.position)]
        if standard.isWhole { events += standardRisen(standard) }
        return events
    }

    private mutating func standardRisen(_ standard: Standard) -> [GameEvent] {
        if let alliance = alliance(standard.alliance) {
            record(.alliance, alliance.members, "A standard of \(alliance.name) stands whole \(placeName(of: standard.position)).")
        }
        return [.standardRisen(standard: standard.id, alliance: standard.alliance, at: standard.position)]
    }

    /// A company strikes a standard of a House it is at war with: its ward
    /// broken, the standard is torn down.
    mutating func strike(standard standardID: Int, with unitID: Int) -> [GameEvent] {
        guard let index = standards?.firstIndex(where: { $0.id == standardID }), let unitIndex = unitIndex(unitID) else { return [] }
        let unit = units[unitIndex]
        units[unitIndex].movesLeft = 0
        units[unitIndex].acted = true
        units[unitIndex].fortified = false
        units[unitIndex].destination = nil
        units[unitIndex].errand = nil
        var random = random()
        let damage = wardDamage(by: unit) * random.int(in: 80...120) / 100
        standards![index].ward = max(0, standards![index].ward - damage)
        let standard = standards![index]
        var events: [GameEvent] = [.standardStruck(standard: standardID, ward: standard.ward, by: unit.owner, at: standard.position)]
        events += gainExperience(unitID)
        if standard.ward == 0 {
            standards!.remove(at: index)
            events.append(.standardTorn(standard: standardID, alliance: standard.alliance, by: unit.owner, at: standard.position))
            if let alliance = alliance(standard.alliance), houses.indices.contains(unit.owner) {
                record(.alliance, [unit.owner] + alliance.members,
                       "\(houses[unit.owner].title) tears down a standard of \(alliance.name) \(placeName(of: standard.position)).")
            }
        }
        return events
    }

    /// As the watch turns: standards whose House has left their alliance,
    /// or fallen, come down; struck standards mend.
    mutating func keepStandards() -> [GameEvent] {
        guard var list = standards else { return [] }
        var events: [GameEvent] = []
        list.removeAll { standard in
            let kept = !houses[standard.raisedBy].isEliminated && alliance(of: standard.raisedBy)?.id == standard.alliance
            if !kept { events.append(.standardTorn(standard: standard.id, alliance: standard.alliance, by: nil, at: standard.position)) }
            return !kept
        }
        var risen: [Standard] = []
        for index in list.indices {
            if !list[index].isWhole {
                list[index].built = (list[index].built ?? 0) + 1
                if list[index].isWhole { risen.append(list[index]) }
            }
            list[index].ward = min(Standard.maximumWard, list[index].ward + Standard.mending)
        }
        standards = list
        for standard in risen { events += standardRisen(standard) }
        return events
    }
}
