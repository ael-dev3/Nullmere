/// What an alliance keeps of its own. Its coffers fill each watch from its
/// land, its standards and its hall, and from a tithe on what its yards
/// yield; whatever its Houses raise for it, standards, hall, storehouse and
/// yards, the coffers pay for first, and the House raising it the rest.
extension Alliance {
    /// The most its coffers keep of each store.
    public static let coffersKept = Stock(grain: 2000, timber: 2000, stone: 2000, moonsalt: 100)

    /// What its coffers hold.
    public var stores: Stock { coffers ?? .zero }
}

extension Standard {
    /// What a standard's land yields its alliance's coffers each watch.
    public static let yield = Stock(grain: 5, timber: 5, stone: 5)
}

extension AllianceHall {
    /// What a hall standing whole yields its alliance's coffers each watch.
    public static let yield = Stock(grain: 15, timber: 15, stone: 15, moonsalt: 1)
}

/// An alliance's storehouse: a long barn of stone and timber its leader
/// raises on the alliance's land over two watches. Whole, each of its
/// Houses may lay up stores in it, beyond its own storage and out of any
/// taker's reach, and take them back when it will; a House that leaves the
/// alliance takes back all it laid up. Only the alliance's companies enter
/// it. A House at war with one of the alliance's may strike it when none
/// keeps it, and tear it down when its ward breaks: it carries off what
/// was laid up there, as much as it can keep.
public struct Storehouse: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let alliance: Int
    /// The House that raised it: its alliance's leader then.
    public let raisedBy: Int
    public let position: Hex
    public internal(set) var ward: Int
    /// The watches of its raising done: whole at `Storehouse.raising`.
    public internal(set) var built: Int
    /// The watch its raising began.
    public let begun: Int
    /// What its Houses have laid up in it.
    public internal(set) var laidUp: [LaidUp]

    /// What a House has laid up in a storehouse.
    public struct LaidUp: Codable, Equatable, Sendable {
        public let house: Int
        public internal(set) var stock: Stock

        public init(house: Int, stock: Stock) {
            self.house = house
            self.stock = stock
        }
    }

    public init(id: Int, alliance: Int, raisedBy: Int, position: Hex, begun: Int) {
        self.id = id
        self.alliance = alliance
        self.raisedBy = raisedBy
        self.position = position
        self.ward = Storehouse.maximumWard
        self.built = 0
        self.begun = begun
        self.laidUp = []
    }

    /// Whether it has risen whole.
    public var isWhole: Bool { built >= Storehouse.raising }

    /// How far its raising has come, 0 to 1.
    public var progress: Double { Double(min(built, Storehouse.raising)) / Double(Storehouse.raising) }

    /// What a House has laid up in it.
    public func laidUp(by house: Int) -> Stock {
        laidUp.first { $0.house == house }?.stock ?? .zero
    }

    /// What its Houses have laid up in it together.
    public var held: Stock { laidUp.reduce(.zero) { $0 + $1.stock } }

    /// Its ward, from the first.
    public static let maximumWard = 120
    /// The watches it takes to rise.
    public static let raising = 2
    /// What raising it costs.
    public static let cost = Stock(grain: 100, timber: 250, stone: 250, moonsalt: 5)
    /// Ward it mends each watch.
    public static let mending = 10
    /// The most each House may lay up in it of each store.
    public static let room = Stock(grain: 600, timber: 600, stone: 600, moonsalt: 50)
    /// How near another House's hold it may stand, and no nearer.
    public static let fromOthers = 3
}

/// The yards an alliance raises on its land: sites of its own that never
/// come up of themselves, richer than the land's, that its companies alone
/// work, a quarter faster than any other; a tenth more of what they yield
/// goes to the alliance's coffers besides.
public enum Yard {
    /// What raising one costs.
    public static let cost = Stock(grain: 80, timber: 150, stone: 150)
    /// How much faster its alliance's companies work it, in percent.
    public static let gathering = 25
    /// The share of what is worked at it the coffers gain besides, in percent.
    public static let tithe = 10

    /// What a yard of a store holds when raised.
    public static func richness(of store: Resource) -> Int {
        store == .moonsalt ? 300 : 1500
    }

    /// Its name on the map.
    public static func title(of store: Resource) -> String {
        switch store {
        case .grain: return "Tilled Acre"
        case .timber: return "Timber Yard"
        case .stone: return "Quarry"
        case .moonsalt: return "Salt Works"
        }
    }
}

extension GameState {
    // MARK: The coffers

    /// What an alliance's land yields its coffers each watch: something for
    /// each of its standards, more for its hall standing whole.
    public func coffersYield(of allianceID: Int) -> Stock {
        Standard.yield * standards(of: allianceID).count + (hall(of: allianceID)?.isWhole == true ? AllianceHall.yield : .zero)
    }

    /// Stores into an alliance's coffers, each kept up to what they keep.
    mutating func fill(coffersOf allianceID: Int, with income: Stock) {
        guard !income.isZero, let index = alliances?.firstIndex(where: { $0.id == allianceID }) else { return }
        var coffers = alliances![index].stores
        coffers.credit(income)
        for resource in Resource.allCases {
            coffers[resource] = min(coffers[resource], Alliance.coffersKept[resource])
        }
        alliances![index].coffers = coffers
    }

    /// What a House may spend on its alliance's works: its alliance's
    /// coffers and its own stores together.
    public func purse(of house: Int) -> Stock {
        houses[house].stock + (alliance(of: house)?.stores ?? .zero)
    }

    /// A cost borne by a House's alliance's coffers as far as they go, and
    /// by the House the rest; the purse must cover it.
    mutating func spend(_ cost: Stock, by house: Int) {
        var fromHouse = cost
        if let sworn = alliance(of: house), let coffers = sworn.coffers, let index = alliances?.firstIndex(where: { $0.id == sworn.id }) {
            var left = coffers
            for resource in Resource.allCases {
                let paid = min(left[resource], cost[resource])
                left[resource] -= paid
                fromHouse[resource] -= paid
            }
            alliances![index].coffers = left
        }
        houses[house].stock.debit(fromHouse)
    }

    // MARK: The storehouse

    /// Every alliance's storehouse standing or rising.
    public var storehousesStanding: [Storehouse] { storehouses ?? [] }

    public func storehouse(_ id: Int) -> Storehouse? {
        storehouses?.first { $0.id == id }
    }

    public func storehouse(at hex: Hex) -> Storehouse? {
        storehouses?.first { $0.position == hex }
    }

    /// An alliance's storehouse, standing or rising.
    public func storehouse(of alliance: Int) -> Storehouse? {
        storehouses?.first { $0.alliance == alliance }
    }

    /// The storehouse a House lays up its stores in: its alliance's,
    /// standing whole.
    public func wholeStorehouse(for house: Int) -> Storehouse? {
        guard let storehouses, !storehouses.isEmpty, let sworn = alliance(of: house) else { return nil }
        return storehouses.first { $0.alliance == sworn.id && $0.isWhole }
    }

    /// What a House has laid up in its alliance's storehouse.
    public func laidUp(by house: Int) -> Stock {
        guard let sworn = alliance(of: house) else { return .zero }
        return storehouse(of: sworn.id)?.laidUp(by: house) ?? .zero
    }

    /// Whether a House is of an alliance, and may enter its works.
    public func isOf(_ allianceID: Int, _ house: Int) -> Bool {
        alliance(allianceID)?.members.contains(house) == true
    }

    /// Whether a House may strike an alliance's works: at war with one of
    /// its Houses.
    public func isFoe(_ house: Int, ofAlliance allianceID: Int) -> Bool {
        guard let sworn = alliance(allianceID), !sworn.members.contains(house) else { return false }
        return sworn.members.contains { isAtWar(house, $0) }
    }

    /// Why a House can't raise its alliance's storehouse at a hex, if it can't.
    func storehouseRefusal(at hex: Hex, by house: Int) -> RuleError? {
        guard let sworn = alliance(of: house) else { return .notInAlliance }
        guard sworn.leader == house else { return .notAllianceLeader }
        guard storehouse(of: sworn.id) == nil else { return .storehouseStanding }
        if let refusal = allianceWorkGround(at: hex, for: sworn, by: house) { return refusal }
        guard holds.allSatisfy({ sworn.members.contains($0.owner) || $0.position.distance(to: hex) > Storehouse.fromOthers }) else {
            return .foreignTerritory
        }
        let purse = purse(of: house)
        guard purse.covers(Storehouse.cost) else { return .shortOf(purse.shortfall(for: Storehouse.cost)) }
        return nil
    }

    /// Why an alliance's work can't stand at a hex: off its land, or where
    /// something stands already.
    private func allianceWorkGround(at hex: Hex, for sworn: Alliance, by house: Int) -> RuleError? {
        guard let tile = map[hex] else { return .outsideTheWorld }
        guard isExplored(hex, by: house) else { return .unexplored }
        guard tile.terrain.isPassable, !tile.terrain.isWater else { return .impassable(tile.terrain) }
        guard !isOccupied(hex), site(at: hex) == nil, shrine(at: hex) == nil else { return .openGroundOnly }
        guard allianceLand(at: hex) == sworn.id else { return .notAllianceLand }
        return nil
    }

    /// An alliance's leader begins its storehouse at a hex, for its coffers
    /// and stores.
    mutating func raiseStorehouse(at hex: Hex, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = storehouseRefusal(at: hex, by: house) { throw refusal }
        let sworn = alliance(of: house)!
        spend(Storehouse.cost, by: house)
        let storehouse = Storehouse(id: takeID(), alliance: sworn.id, raisedBy: house, position: hex, begun: watch)
        storehouses = storehousesStanding + [storehouse]
        record(.alliance, sworn.members, "\(houses[house].title) begins the storehouse of \(sworn.name) \(placeName(of: hex)).")
        return [.storehouseRaised(storehouse: storehouse.id, alliance: sworn.id, house: house, at: hex)]
    }

    /// Why a House can't lay up so much in its alliance's storehouse, if it can't.
    func layUpRefusal(_ stock: Stock, by house: Int) -> RuleError? {
        guard alliance(of: house) != nil else { return .notInAlliance }
        guard let storehouse = wholeStorehouse(for: house) else { return .noStorehouse }
        guard Resource.allCases.allSatisfy({ stock[$0] >= 0 }), !stock.isZero else { return .nothingGiven }
        guard houses[house].stock.covers(stock) else { return .shortOf(houses[house].stock.shortfall(for: stock)) }
        guard (storehouse.laidUp(by: house) + stock).fits(in: Storehouse.room) else { return .storehouseFull }
        return nil
    }

    /// A House lays up stores in its alliance's storehouse.
    mutating func layUp(_ stock: Stock, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = layUpRefusal(stock, by: house) { throw refusal }
        let index = storehouses!.firstIndex { $0.id == wholeStorehouse(for: house)!.id }!
        houses[house].stock.debit(stock)
        if let entry = storehouses![index].laidUp.firstIndex(where: { $0.house == house }) {
            storehouses![index].laidUp[entry].stock = storehouses![index].laidUp[entry].stock + stock
        } else {
            storehouses![index].laidUp.append(Storehouse.LaidUp(house: house, stock: stock))
        }
        return [.laidUp(house: house, stock: stock)]
    }

    /// Why a House can't take back so much from its alliance's storehouse,
    /// if it can't.
    func takeBackRefusal(_ stock: Stock, by house: Int) -> RuleError? {
        guard alliance(of: house) != nil else { return .notInAlliance }
        guard let storehouse = wholeStorehouse(for: house) else { return .noStorehouse }
        guard Resource.allCases.allSatisfy({ stock[$0] >= 0 }), !stock.isZero else { return .nothingGiven }
        guard storehouse.laidUp(by: house).covers(stock) else { return .notLaidUp }
        let room = storage(of: house)
        guard Resource.allCases.allSatisfy({ houses[house].stock[$0] + stock[$0] <= room || stock[$0] == 0 }) else { return .storageFull }
        return nil
    }

    /// A House takes back stores it laid up in its alliance's storehouse.
    mutating func takeBack(_ stock: Stock, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = takeBackRefusal(stock, by: house) { throw refusal }
        let index = storehouses!.firstIndex { $0.id == wholeStorehouse(for: house)!.id }!
        let entry = storehouses![index].laidUp.firstIndex { $0.house == house }!
        storehouses![index].laidUp[entry].stock.debit(stock)
        if storehouses![index].laidUp[entry].stock.isZero { storehouses![index].laidUp.remove(at: entry) }
        store(stock, for: house)
        return [.tookBack(house: house, stock: stock)]
    }

    /// A House going from its alliance takes back all it laid up in its
    /// storehouse, as much as it can keep.
    mutating func returnLaidUp(of house: Int, from allianceID: Int) {
        guard let index = storehouses?.firstIndex(where: { $0.alliance == allianceID }),
              let entry = storehouses![index].laidUp.firstIndex(where: { $0.house == house }) else { return }
        let stock = storehouses![index].laidUp.remove(at: entry).stock
        if houses.indices.contains(house), !houses[house].isEliminated { store(stock, for: house) }
    }

    /// A company strikes the storehouse of an alliance at war with its
    /// House: its ward broken, the storehouse is torn down, and the House
    /// carries off what was laid up in it.
    mutating func strike(storehouse storehouseID: Int, with unitID: Int) -> [GameEvent] {
        guard let index = storehouses?.firstIndex(where: { $0.id == storehouseID }), let unitIndex = unitIndex(unitID) else { return [] }
        let unit = units[unitIndex]
        units[unitIndex].movesLeft = 0
        units[unitIndex].acted = true
        units[unitIndex].fortified = false
        units[unitIndex].destination = nil
        units[unitIndex].errand = nil
        var random = random()
        let damage = wardDamage(by: unit) * random.int(in: 80...120) / 100
        storehouses![index].ward = max(0, storehouses![index].ward - damage)
        let storehouse = storehouses![index]
        var events: [GameEvent] = [.storehouseStruck(storehouse: storehouseID, alliance: storehouse.alliance, ward: storehouse.ward,
                                                     by: unit.owner, at: storehouse.position)]
        events += gainExperience(unitID)
        if storehouse.ward == 0 {
            storehouses!.remove(at: index)
            let carried = storehouse.held
            store(carried, for: unit.owner)
            events.append(.storehouseTorn(storehouse: storehouseID, alliance: storehouse.alliance, by: unit.owner,
                                          at: storehouse.position, carried: carried))
            if let alliance = alliance(storehouse.alliance) {
                let spoils = carried.isZero ? "" : ", and carries off what was laid up in it"
                record(.alliance, [unit.owner] + alliance.members,
                       "\(houses[unit.owner].title) tears down the storehouse of \(alliance.name) \(placeName(of: storehouse.position))\(spoils).")
            }
        }
        return events
    }

    // MARK: Yards

    /// The yards an alliance has raised.
    public func yards(of allianceID: Int) -> [Site] {
        sitesInLand.filter { $0.alliance == allianceID }
    }

    /// Why a House can't raise its alliance a yard of a store at a hex, if
    /// it can't.
    func yardRefusal(_ store: Resource, at hex: Hex, by house: Int) -> RuleError? {
        guard let sworn = alliance(of: house) else { return .notInAlliance }
        guard sworn.leader == house else { return .notAllianceLeader }
        guard !yards(of: sworn.id).contains(where: { $0.store == store }) else { return .yardStanding(store) }
        if let refusal = allianceWorkGround(at: hex, for: sworn, by: house) { return refusal }
        let purse = purse(of: house)
        guard purse.covers(Yard.cost) else { return .shortOf(purse.shortfall(for: Yard.cost)) }
        return nil
    }

    /// An alliance's leader raises a yard of a store on its land, for its
    /// coffers and stores.
    mutating func raiseYard(_ store: Resource, at hex: Hex, by house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = yardRefusal(store, at: hex, by: house) { throw refusal }
        let sworn = alliance(of: house)!
        spend(Yard.cost, by: house)
        let yard = Site(id: takeID(), store: store, level: Site.highestLevel, position: hex, found: watch, alliance: sworn.id)
        sites = sitesInLand + [yard]
        record(.alliance, sworn.members, "\(houses[house].title) raises a \(yard.title.lowercased()) for \(sworn.name) \(placeName(of: hex)).")
        return [.yardRaised(site: yard.id, alliance: sworn.id, house: house, store: store, at: hex)]
    }

    // MARK: The turn of the watch

    /// As the watch turns: a storehouse or yard whose alliance is no more
    /// comes down, what was laid up going back to its Houses; a storehouse
    /// rising rises a watch further; every storehouse's ward mends; and
    /// every alliance's coffers fill from its land.
    mutating func keepAllianceStores() -> [GameEvent] {
        var events: [GameEvent] = []
        if var list = storehouses {
            list.removeAll { storehouse in
                guard alliance(storehouse.alliance) == nil else { return false }
                for laid in storehouse.laidUp where houses.indices.contains(laid.house) && !houses[laid.house].isEliminated {
                    store(laid.stock, for: laid.house)
                }
                events.append(.storehouseTorn(storehouse: storehouse.id, alliance: storehouse.alliance, by: nil,
                                              at: storehouse.position, carried: .zero))
                return true
            }
            for index in list.indices {
                if !list[index].isWhole {
                    list[index].built += 1
                    if list[index].isWhole, let alliance = alliance(list[index].alliance) {
                        events.append(.storehouseRisen(storehouse: list[index].id, alliance: alliance.id, at: list[index].position))
                        record(.alliance, alliance.members, "The storehouse of \(alliance.name) stands whole \(placeName(of: list[index].position)).")
                    }
                }
                list[index].ward = min(Storehouse.maximumWard, list[index].ward + Storehouse.mending)
            }
            storehouses = list
        }
        let gone = Set(sitesInLand.compactMap(\.alliance).filter { alliance($0) == nil })
        if !gone.isEmpty { sites!.removeAll { $0.alliance.map(gone.contains) == true } }
        for sworn in alliances ?? [] {
            fill(coffersOf: sworn.id, with: coffersYield(of: sworn.id))
        }
        return events
    }
}

extension Stock {
    /// Whether every store of it is within a limit's.
    public func fits(in limit: Stock) -> Bool {
        Resource.allCases.allSatisfy { self[$0] <= limit[$0] }
    }
}
