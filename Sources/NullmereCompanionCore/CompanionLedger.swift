import NullmereCore

/// What a keeper's phone shows of their House, read from the view the
/// realm gave them, as the phone's screens list it: its companies and what
/// each is about, with the orders each may be given now; its holds and what
/// they raise; its stores; its alliance and the words said there and to
/// the whole realm; and the realm's chronicle. Each order is offered where
/// it would do something, as cheaply as the screen is drawn; the session
/// holds the one given to the rules before it goes, and the realm, which
/// sees all, decides.
public struct CompanionLedger: Equatable, Sendable {
    /// A company of the House.
    public struct Company: Equatable, Identifiable, Sendable {
        public let id: Int
        /// As the order book names it: kind, tier and where it stands.
        public let name: String
        public let troops: String
        /// Its commander, if one leads it.
        public let leader: String?
        /// What it is about, in a few words.
        public let doing: String
        /// The orders it may be given now, each the realm would take.
        public let orders: [Order]
        /// The holds of the House it may march to now.
        public let marches: [Order]
        /// What it may strike from where it stands: the wilds, and the
        /// companies and holds of Houses at war with this one, in its reach.
        public let strikes: [Order]
        /// The nearest sites of the land it may be sent to gather at.
        public let gathers: [Order]
        /// The rallies of the House's side it may be sent to now.
        public let rallies: [Order]
        /// The nearest of its allies' seats whose gates it may keep.
        public let gates: [Order]
    }

    /// An order offered: what it says, and the command it gives.
    public struct Order: Equatable, Identifiable, Sendable {
        public let title: String
        public let command: Command
        public var id: String { title }
    }

    /// A hold of the House.
    public struct Hold: Equatable, Identifiable, Sendable {
        public let id: Int
        public let name: String
        public let isSeat: Bool
        /// What it raises and musters, and how long each has to go.
        public let work: [String]
        /// The companies it may muster now, at the first tier, the House
        /// able to pay for them.
        public let musters: [Order]
        /// The works it may raise a level now, the House able to pay.
        public let works: [Order]
    }

    /// A line said in the alliance or to the realm.
    public struct Said: Equatable, Identifiable, Sendable {
        public let id: Int
        public let from: String
        public let text: String
        public let watch: Int
        /// Said by this keeper's own House.
        public let isOwn: Bool
    }

    /// One of the House's commanders, who may be asked for counsel: free,
    /// at the head of a company, wounded or held prisoner, as the Mac's
    /// commanders board orders them.
    public struct Commander: Equatable, Identifiable, Sendable {
        public let id: Int
        public let name: String
        /// Their kind and level.
        public let title: String
        /// How they stand: the company they lead, their wound or their captor.
        public let standing: String
        /// A commander held by another House speaks only to their captors.
        public let canCounsel: Bool
    }

    /// An envoy waiting on the keeper's answer: whose, what it offers in
    /// the words the Mac tells it, the words its House sent with it, how
    /// long it waits, and the answers the rules take.
    public struct Envoy: Equatable, Identifiable, Sendable {
        public let id: Int
        public let from: String
        public let offer: String
        public let terms: String
        public let words: String?
        public let waits: String
        /// Nil while the keeper hasn't what it asks.
        public let accept: Order?
        public let refuse: Order
        /// A steward's demand of tribute, refused, is war at once.
        public let refusingIsWar: Bool
    }

    public let house: String
    public let watch: Int
    /// Envoys waiting on the keeper, the first come first.
    public let envoys: [Envoy]
    /// Companies of Houses at war gathered near the House's holds, as the
    /// walls' watchmen tell it.
    public let gatherings: [String]
    public let companies: [Company]
    public let commanders: [Commander]
    /// Help for each ally with works, musters or study under way the
    /// House hasn't helped yet.
    public let helps: [Order]
    public let holds: [Hold]
    public let stores: [(resource: Resource, amount: Int)]
    /// The alliance, by name, and its Houses, the leader first.
    public let alliance: String?
    public let allies: [String]
    public let allianceWords: [Said]
    public let realmWords: [Said]
    /// The realm's chronicle, the latest first.
    public let chronicle: [String]

    /// The most lines of words and of the chronicle shown.
    public static let linesShown = 30

    public static func == (a: CompanionLedger, b: CompanionLedger) -> Bool {
        a.house == b.house && a.watch == b.watch && a.envoys == b.envoys && a.gatherings == b.gatherings
            && a.companies == b.companies && a.commanders == b.commanders && a.helps == b.helps
            && a.holds == b.holds
            && a.stores.map(\.amount) == b.stores.map(\.amount) && a.alliance == b.alliance && a.allies == b.allies
            && a.allianceWords == b.allianceWords && a.realmWords == b.realmWords && a.chronicle == b.chronicle
    }

    /// The ledger of `player`'s House in their view of the world.
    public init(world: GameState, player: Int) {
        let houses = world.houses
        func title(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "The wilds" }
        house = title(player)
        watch = world.watch
        envoys = world.envoys.filter { $0.to == player }.sorted { ($0.arrived, $0.id) < ($1.arrived, $1.id) }.map { envoy in
            let left = world.watchesWaiting(of: envoy)
            return Envoy(id: envoy.id, from: title(envoy.from), offer: envoy.proposal.title, terms: world.terms(of: envoy, for: player),
                         words: envoy.words, waits: left == 1 ? "Leaves after this watch" : "Waits \(left) watches",
                         accept: world.canKeepTerms(of: envoy, for: player)
                            ? Order(title: "Accept", command: .answer(envoy: envoy.id, accept: true)) : nil,
                         refuse: Order(title: "Refuse", command: .answer(envoy: envoy.id, accept: false)),
                         refusingIsWar: world.refusingIsWar(envoy))
        }
        gatherings = world.gatherings(against: player).map(world.words(of:))
        let holds = world.holds(of: player).sorted { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }
        companies = SpokenOrders.companies(in: world, player: player).map { unit in
            // Each order where it would do something: dig in a company of war
            // not dug in, halt one on the march, call home one gathering or
            // carrying, drill one the rules would drill, and march to the
            // House's other holds.
            let gathering: Bool = { if case .gather? = unit.errand { return true }; return unit.load != nil }()
            let offered: [(String, Command, Bool)] = [
                ("Fortify", .fortify(unit: unit.id), unit.kind.isMilitary && !unit.fortified && unit.destination == nil && unit.errand == nil),
                ("Halt", .halt(unit: unit.id), unit.destination != nil),
                ("Recall", .recall(unit: unit.id), gathering),
                ("Drill", .drill(unit: unit.id), unit.kind.isMilitary && unit.drillAt == nil && world.drillRefusal(of: unit) == nil),
            ]
            let orders = offered.filter(\.2).map { Order(title: $0.0, command: $0.1) }
            let marches = holds.filter { $0.position != unit.position && unit.destination != $0.position }.map { hold in
                Order(title: "March to \(hold.name)", command: .move(unit: unit.id, to: hold.position))
            }
            return Company(id: unit.id, name: SpokenOrders.named(unit, in: world), troops: GameState.counted(world.troops(of: unit)),
                           leader: unit.leader.flatMap { world.commander($0)?.name }, doing: CompanionLedger.doing(unit, in: world),
                           orders: orders, marches: marches, strikes: CompanionLedger.strikes(for: unit, in: world, player: player),
                           gathers: CompanionLedger.gathers(for: unit, in: world, player: player),
                           rallies: CompanionLedger.rallies(for: unit, in: world, player: player),
                           gates: CompanionLedger.gates(for: unit, in: world, player: player))
        }
        commanders = world.commandersBoard(for: player).lines.map { line in
            let standing: String
            if let captor = line.heldBy {
                standing = "Held prisoner by \(title(captor))"
            } else if let wounded = line.woundedFor {
                standing = wounded == 1 ? "Wounded: whole again next watch" : "Wounded: whole again in \(wounded) watches"
            } else if let unit = line.leads {
                standing = "Leads the \(SpokenOrders.named(unit, in: world))"
            } else {
                standing = "Free to lead a company of war"
            }
            return Commander(id: line.commander.id, name: line.commander.name, title: "\(line.commander.archetype.title) · level \(line.level)",
                             standing: standing, canCounsel: line.heldBy == nil)
        }
        self.holds = holds.map { hold in
            var work: [String] = []
            if let project = hold.project {
                work.append("Raising \(project.kind.title) \(BuildingKind.numeral(project.targetLevel)), "
                    + CompanionLedger.watches(project.watchesLeft))
            }
            if let training = hold.training {
                work.append("Mustering \(training.kind.title) \(BuildingKind.numeral(training.musteredTier)), "
                    + CompanionLedger.watches(training.watchesLeft))
            }
            return Hold(id: hold.id, name: hold.name, isSeat: hold.isSeat, work: work,
                        musters: CompanionLedger.musters(at: hold, in: world, player: player),
                        works: CompanionLedger.works(at: hold, in: world, player: player))
        }
        let stock = houses.indices.contains(player) ? houses[player].stock : .zero
        stores = Resource.allCases.map { ($0, stock[$0]) }
        let allied = world.alliance(of: player)
        alliance = allied?.name
        let sworn = allied.map { [$0.leader] + $0.members.filter { $0 != allied?.leader } } ?? []
        allies = sworn.map(title)
        helps = sworn.filter { $0 != player }.compactMap { ally in
            let count = world.helpable(by: player, for: ally)
            return count > 0 ? Order(title: "Help \(title(ally)), \(count) under way", command: .help(house: ally)) : nil
        }
        let said = world.wordsSaid.filter { $0.removed != true }
        func lines(_ words: [Word]) -> [Said] {
            words.suffix(CompanionLedger.linesShown).map { Said(id: $0.id, from: title($0.from), text: $0.text, watch: $0.watch, isOwn: $0.from == player) }
        }
        allianceWords = allied.map { alliance in lines(said.filter { $0.alliance == alliance.id }) } ?? []
        realmWords = lines(said.filter { $0.alliance == nil })
        chronicle = world.chronicle.suffix(CompanionLedger.linesShown).reversed().map(\.text)
    }

    /// The most sites a company is offered to gather at: the nearest.
    public static let sitesOffered = 3

    /// What a company may strike now from where it stands, by the rules'
    /// own reach: the wilds, which any House may strike, and the companies
    /// and holds of Houses at war with this one.
    static func strikes(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.movesLeft > 0 else { return [] }
        let reach = unit.kind.range
        func near(_ hex: Hex) -> Bool { hex != unit.position && hex.distance(to: unit.position) <= reach }
        let houses = world.houses
        func title(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "the wilds" }
        var strikes: [Order] = []
        for wild in world.wildsStanding where near(wild.position) {
            strikes.append(Order(title: "Strike the \(wild.kind.title)", command: .attack(unit: unit.id, target: wild.position)))
        }
        for other in world.units where other.owner != player && houses.indices.contains(other.owner)
            && world.isAtWar(player, other.owner) && near(other.position) {
            strikes.append(Order(title: "Strike \(title(other.owner))'s \(SpokenOrders.named(other, in: world))",
                                 command: .attack(unit: unit.id, target: other.position)))
        }
        for hold in world.holds where hold.owner != player && houses.indices.contains(hold.owner)
            && world.isAtWar(player, hold.owner) && near(hold.position) {
            strikes.append(Order(title: "Strike \(hold.name)", command: .attack(unit: unit.id, target: hold.position)))
        }
        return strikes
    }

    /// The nearest sites a company of war may be sent to gather at, as the
    /// rules would send it.
    static func gathers(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.errand == nil else { return [] }
        let nearest = world.sitesInLand.sorted { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
        return nearest.lazy.filter { world.gatherRefusal(unit.id, at: $0.id, as: player) == nil }.prefix(sitesOffered).map { site in
            Order(title: "Gather \(site.store.title.lowercased()) at \(world.placeName(of: site.position))",
                  command: .gather(unit: unit.id, site: site.id))
        }
    }

    /// The rallies of the House's side a company of war with no errand may
    /// be sent to now, as the rules would send it.
    static func rallies(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.errand == nil else { return [] }
        return world.ralliesStanding.filter { world.joinRallyRefusal($0.id, with: unit.id, as: player) == nil }.map { rally in
            Order(title: "Join the rally against \(world.targetName(rally.target) ?? "a hold")", command: .joinRally(rally: rally.id, unit: unit.id))
        }
    }

    /// The nearest of the House's allies' seats a company of war with no
    /// errand may be sent to keep the gates of, as the rules would send it.
    static func gates(for unit: Unit, in world: GameState, player: Int) -> [Order] {
        guard unit.kind.isMilitary, unit.errand == nil, let allied = world.alliance(of: player) else { return [] }
        let seats = Set([allied.leader] + allied.members).subtracting([player]).compactMap { world.seat(of: $0) }
        let nearest = seats.sorted { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
        return nearest.lazy.filter { world.reinforceRefusal($0.id, with: unit.id, as: player) == nil }.prefix(sitesOffered).map { seat in
            Order(title: "Keep the gates of \(seat.name)", command: .reinforce(unit: unit.id, hold: seat.id))
        }
    }

    /// The companies a hold may muster now at the first tier: none while it
    /// musters one; those its works allow, the House able to pay.
    static func musters(at hold: NullmereCore.Hold, in world: GameState, player: Int) -> [Order] {
        guard hold.training == nil, world.houses.indices.contains(player) else { return [] }
        let stock = world.houses[player].stock
        return UnitKind.allCases.filter { kind in
            world.tierRefusal(of: kind, tier: 1, at: hold, for: player) == nil && stock.covers(world.trainingCost(of: kind, tier: 1, for: player))
        }.map { kind in
            Order(title: "Muster \(kind.title) I", command: .train(hold: hold.id, kind: kind, tier: 1))
        }
    }

    /// The works a hold may raise a level now: none while it raises one;
    /// each below its last level, the Moonspire at the seat alone and never
    /// by a vassal, the House able to pay.
    static func works(at hold: NullmereCore.Hold, in world: GameState, player: Int) -> [Order] {
        guard hold.project == nil, world.houses.indices.contains(player) else { return [] }
        let house = world.houses[player]
        return BuildingKind.allCases.compactMap { kind -> Order? in
            if kind.requiresSeat, !hold.isSeat { return nil }
            if kind == .moonspire, house.liege != nil { return nil }
            let level = hold.level(kind) + 1
            guard level <= kind.maxLevel, house.stock.covers(world.buildCost(of: kind, toLevel: level, for: player)) else { return nil }
            return Order(title: "Raise \(kind.title) \(BuildingKind.numeral(level))", command: .build(hold: hold.id, kind: kind))
        }
    }

    /// What a company is about, in a few words.
    static func doing(_ unit: Unit, in world: GameState) -> String {
        switch unit.errand {
        case .gather?: return "Gathering"
        case .homeward?: return "Bringing its load home"
        case .rally?: return "With a rally"
        case .reinforce(let hold)?: return "Keeping the gates of \(world.hold(hold)?.name ?? "an ally's hold")"
        case nil: break
        }
        if let destination = unit.destination { return "Marching to " + whither(world.placeName(of: destination)) }
        if unit.fortified { return "Dug in" }
        return "At rest"
    }

    /// A place as a march's end, its own word for where let go: "at
    /// Tirford" is "Tirford", "on the barrows by Tirford" is "the barrows by
    /// Tirford", "in the field" is "the field".
    static func whither(_ place: String) -> String {
        for preposition in ["at ", "on ", "in "] where place.hasPrefix(preposition) { return String(place.dropFirst(preposition.count)) }
        return place
    }

    static func watches(_ count: Int) -> String {
        count == 1 ? "1 watch to go" : "\(count) watches to go"
    }
}
