import NullmereCore

/// The House's land as the phone's Land tab draws it, read from the
/// keeper's view of the world as the ledger is: the ground about its seat
/// as far as its holds and companies reach, as the House knows it, and what
/// stands there that the House knows of (every hold of the realm, the
/// companies and wilds it sees, the lairs and sites on ground it has
/// explored, the holy sites); and for a hex chosen there, what lies on it
/// and the orders the rules would take there.
public struct CompanionChart: Equatable, Sendable {
    /// A hex of the chart, as the House knows it.
    public struct Cell: Equatable, Sendable {
        public let hex: Hex
        /// Its ground as the keeper's view holds it: where the House hasn't
        /// explored, its water as it is and its land plain.
        public let terrain: Terrain
        /// Explored by the House.
        public let explored: Bool
        /// Seen by the House now, from its holds and companies.
        public let seen: Bool
    }

    /// Whose a mark is, as the chart colours it.
    public enum Side: String, CaseIterable, Equatable, Sendable {
        case own, ally, foe, other, wilds
    }

    /// What a mark stands for.
    public enum Thing: String, CaseIterable, Equatable, Sendable {
        case seat, hold, company, wild, lair, site, shrine
    }

    /// Something on the chart.
    public struct Mark: Equatable, Identifiable, Sendable {
        public let id: String
        public let hex: Hex
        public let thing: Thing
        public let side: Side
        /// What it is, as a keeper would say it.
        public let name: String
        /// What the chart writes beside it, close enough: a hold's name.
        public var label: String? = nil
    }

    /// What lies at a hex of the chart, and what the House may do there.
    public struct Place: Equatable, Sendable {
        public let hex: Hex
        /// Where it is: a hold's name, or its ground and the hold it lies by.
        public let title: String
        /// What lies there, or what the House knows of the ground.
        public let lines: [String]
        /// The House's own companies there, whose orders the Army tab lists.
        public let companies: [Int]
        /// The House's own hold there, whose works the House tab lists.
        public let hold: Int?
        /// The House's companies that may strike what lies there, by the
        /// rules' own reach.
        public let strikes: [CompanionLedger.Order]
        /// A rally of the House's alliance called on what lies there.
        public let calls: [CompanionLedger.Order]
        /// The House's companies of war sent to gather there, the nearest first.
        public let gathers: [CompanionLedger.Order]
        /// The House's companies marched there, the nearest first.
        public let marches: [CompanionLedger.Order]

        /// Every order the rules would take there, each as offered.
        public var orders: [CompanionLedger.Order] { strikes + calls + gathers + marches }
    }

    /// The hex at its heart: the House's seat, or where the House has
    /// anything at all.
    public let center: Hex
    /// How far the chart reaches from its heart.
    public let radius: Int
    /// Every hex of the world within its reach, spiralling out from its heart.
    public let cells: [Cell]
    /// The holds first, then the sites, holy sites and lairs, and what
    /// stands in the field over them.
    public let marks: [Mark]
    /// The regions of the shores whose hearts lie on the chart, by name, as
    /// every keeper's map writes them, fog or none.
    public let regions: [(name: String, hex: Hex)]

    public static func == (a: CompanionChart, b: CompanionChart) -> Bool {
        a.center == b.center && a.radius == b.radius && a.cells == b.cells && a.marks == b.marks
            && a.regions.map(\.name) == b.regions.map(\.name) && a.regions.map(\.hex) == b.regions.map(\.hex)
    }

    /// The least reach of a chart, and the most: a House whose companies
    /// march further sees them on the Army tab.
    public static let leastRadius = 6
    public static let mostRadius = 18
    /// The ground shown past the House's farthest hold or company.
    public static let margin = 3
    /// The most of the House's companies offered to march to a hex, or to
    /// gather there: the nearest.
    public static let offered = 6

    /// The chart of `player`'s House in their view of the world.
    public init(world: GameState, player: Int) {
        let houses = world.houses
        let holds = world.holds(of: player)
        let companies = world.units(of: player)
        let center = (world.seat(of: player) ?? holds.first)?.position ?? companies.first?.position ?? .origin
        let farthest = (holds.map(\.position) + companies.map(\.position)).map { $0.distance(to: center) }.max() ?? 0
        let radius = min(max(farthest + CompanionChart.margin, CompanionChart.leastRadius), CompanionChart.mostRadius)
        self.center = center
        self.radius = radius
        let seen = world.visibility(for: player)
        let explored = houses.indices.contains(player) ? houses[player].explored : Explored()
        cells = center.spiral(radius).compactMap { hex in
            guard let index = world.map.index(of: hex) else { return nil }
            return Cell(hex: hex, terrain: world.map[index].terrain, explored: explored.indices.contains(index) && explored[index],
                        seen: seen.indices.contains(index) && seen[index])
        }
        func reached(_ hex: Hex) -> Bool { hex.distance(to: center) <= radius }
        func side(_ house: Int) -> Side {
            guard houses.indices.contains(house) else { return .other }
            if house == player { return .own }
            if world.areAllied(player, house) { return .ally }
            return world.isAtWar(player, house) ? .foe : .other
        }
        func whose(_ house: Int) -> String {
            house == player ? "your" : houses.indices.contains(house) ? "\(houses[house].title)'s" : "a fallen House's"
        }
        var marks: [Mark] = []
        for hold in world.holds where reached(hold.position) {
            marks.append(Mark(id: "hold \(hold.id)", hex: hold.position, thing: hold.isSeat ? .seat : .hold, side: side(hold.owner),
                              name: "\(hold.name), \(whose(hold.owner)) \(hold.isSeat ? "seat" : "hold")", label: hold.name))
        }
        for site in world.sitesInLand where reached(site.position) {
            marks.append(Mark(id: "site \(site.id)", hex: site.position, thing: .site, side: .other,
                              name: "\(site.title) \(BuildingKind.numeral(site.level)), \(site.store.title.lowercased()) to gather"))
        }
        for shrine in world.holySites where reached(shrine.position) {
            marks.append(Mark(id: "shrine \(shrine.id)", hex: shrine.position, thing: .shrine, side: .other, name: shrine.title))
        }
        for lair in world.lairsStanding where reached(lair.position) {
            marks.append(Mark(id: "lair \(lair.id)", hex: lair.position, thing: .lair, side: .wilds, name: CompanionChart.capitalized(lair.named)))
        }
        for wild in world.wildsStanding where reached(wild.position) {
            marks.append(Mark(id: "wild \(wild.id)", hex: wild.position, thing: .wild, side: .wilds,
                              name: "\(CompanionChart.capitalized(wild.kind.title)) of the \(ordinal(wild.level)) level"))
        }
        for unit in world.units where reached(unit.position) {
            marks.append(Mark(id: "company \(unit.id)", hex: unit.position, thing: .company, side: side(unit.owner),
                              name: "\(CompanionChart.capitalized(whose(unit.owner))) \(unit.kind.title) \(BuildingKind.numeral(unit.tier)), "
                                + "\(GameState.counted(world.troops(of: unit))) troops"))
        }
        self.marks = marks
        regions = (world.atlas?.regions ?? []).filter { reached($0.heart) }.map { ($0.name, $0.heart) }
    }

    /// Whether a hex lies on the chart.
    public func contains(_ hex: Hex) -> Bool {
        hex.distance(to: center) <= radius && cells.contains { $0.hex == hex }
    }

    /// What lies at `hex` of `player`'s view of `world`, the world the chart
    /// was read from, and the orders the rules would take there.
    public func place(at hex: Hex, in world: GameState, player: Int) -> Place {
        let cell = cells.first { $0.hex == hex }
        let explored = cell?.explored ?? false
        let hold = world.hold(at: hex)
        let title: String
        if let hold {
            title = hold.name
        } else {
            let ground = cell.map { explored || $0.terrain.isWater ? $0.terrain.title : "Unexplored ground" } ?? "Beyond the chart"
            let near = world.holds.filter { $0.position.distance(to: hex) <= 4 }
                .min { ($0.position.distance(to: hex), $0.id) < ($1.position.distance(to: hex), $1.id) }
            title = near.map { "\(ground) by \($0.name)" } ?? ground
        }
        var lines = marks.filter { $0.hex == hex }.map(\.name)
        if lines.isEmpty {
            lines = [explored ? "Nothing your House knows of stands here." : "Your House hasn't explored this ground."]
        }
        let own = world.units(of: player).sorted { ($0.position.distance(to: hex), $0.id) < ($1.position.distance(to: hex), $1.id) }
        // What may strike what lies here, by the rules' own reach.
        var strikes: [CompanionLedger.Order] = []
        for unit in own {
            for strike in CompanionLedger.strikes(for: unit, in: world, player: player) {
                guard case .attack(_, let target) = strike.command, target == hex else { continue }
                strikes.append(CompanionLedger.Order(title: "\(strike.title) with the \(SpokenOrders.named(unit, in: world))", command: strike.command))
            }
        }
        // The House's companies of war sent to gather here.
        var gathers: [CompanionLedger.Order] = []
        if let site = world.site(at: hex) {
            gathers = own.lazy.filter { world.gatherRefusal($0.id, at: site.id, as: player) == nil }.prefix(CompanionChart.offered).map { unit in
                CompanionLedger.Order(title: "Gather \(site.store.title.lowercased()) here with the \(SpokenOrders.named(unit, in: world))",
                                      command: .gather(unit: unit.id, site: site.id))
            }
        }
        // And marched here, the nearest first, as the realm would march them.
        let marches = own.lazy.filter { $0.position != hex && $0.destination != hex }
            .map { unit in
                CompanionLedger.Order(title: "March the \(SpokenOrders.named(unit, in: world)) here", command: .move(unit: unit.id, to: hex))
            }
            .filter { world.refusal(of: $0.command, as: player) == nil }
            .prefix(CompanionChart.offered)
        return Place(hex: hex, title: title, lines: lines, companies: own.filter { $0.position == hex }.map(\.id),
                     hold: hold.flatMap { $0.owner == player ? $0.id : nil }, strikes: strikes,
                     calls: CompanionLedger.calls(in: world, player: player, holds: world.holds(of: player), at: hex),
                     gathers: gathers, marches: Array(marches))
    }

    /// How a cell is drawn, its red, green and blue from 0 to 1: its
    /// ground's own colour by night, dimmed where the House doesn't see it
    /// now, and under fog where the House hasn't explored it, its water
    /// alone showing through, as every shore knows the lake.
    public static func shade(of cell: Cell) -> (red: Double, green: Double, blue: Double) {
        let ground: (Double, Double, Double)
        switch cell.terrain {
        case .still: ground = (0.02, 0.03, 0.06)
        case .shallows: ground = (0.06, 0.10, 0.16)
        case .stream: ground = (0.10, 0.18, 0.28)
        case .shoal: ground = (0.17, 0.25, 0.31)
        case .ford: ground = (0.30, 0.32, 0.37)
        case .strand: ground = (0.42, 0.40, 0.36)
        case .saltFlat: ground = (0.68, 0.69, 0.66)
        case .greyfield: ground = (0.26, 0.29, 0.25)
        case .blackwood: ground = (0.10, 0.16, 0.12)
        case .barrow: ground = (0.31, 0.27, 0.22)
        case .spine: ground = (0.18, 0.18, 0.21)
        }
        if !cell.explored {
            return cell.terrain.isWater ? (ground.0 * 0.6, ground.1 * 0.6, ground.2 * 0.6) : fog
        }
        let light = cell.seen ? 1 : CompanionChart.unseenLight
        return (ground.0 * light, ground.1 * light, ground.2 * light)
    }

    /// The fog over land the House hasn't explored.
    public static let fog = (red: 0.07, green: 0.08, blue: 0.11)
    /// How bright ground the House has explored but doesn't see now is drawn.
    public static let unseenLight = 0.72

    static func capitalized(_ words: String) -> String {
        words.prefix(1).uppercased() + words.dropFirst()
    }
}
