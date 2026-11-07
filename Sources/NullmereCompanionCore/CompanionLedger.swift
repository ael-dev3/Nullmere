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

    public let house: String
    public let watch: Int
    public let companies: [Company]
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
        a.house == b.house && a.watch == b.watch && a.companies == b.companies && a.holds == b.holds
            && a.stores.map(\.amount) == b.stores.map(\.amount) && a.alliance == b.alliance && a.allies == b.allies
            && a.allianceWords == b.allianceWords && a.realmWords == b.realmWords && a.chronicle == b.chronicle
    }

    /// The ledger of `player`'s House in their view of the world.
    public init(world: GameState, player: Int) {
        let houses = world.houses
        func title(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "The wilds" }
        house = title(player)
        watch = world.watch
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
                           orders: orders, marches: marches)
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
            return Hold(id: hold.id, name: hold.name, isSeat: hold.isSeat, work: work)
        }
        let stock = houses.indices.contains(player) ? houses[player].stock : .zero
        stores = Resource.allCases.map { ($0, stock[$0]) }
        let allied = world.alliance(of: player)
        alliance = allied?.name
        allies = (allied.map { [$0.leader] + $0.members.filter { $0 != allied?.leader } } ?? []).map(title)
        let said = world.wordsSaid.filter { $0.removed != true }
        func lines(_ words: [Word]) -> [Said] {
            words.suffix(CompanionLedger.linesShown).map { Said(id: $0.id, from: title($0.from), text: $0.text, watch: $0.watch, isOwn: $0.from == player) }
        }
        allianceWords = allied.map { alliance in lines(said.filter { $0.alliance == alliance.id }) } ?? []
        realmWords = lines(said.filter { $0.alliance == nil })
        chronicle = world.chronicle.suffix(CompanionLedger.linesShown).reversed().map(\.text)
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
        if let destination = unit.destination { return "Marching to \(world.placeName(of: destination))" }
        if unit.fortified { return "Dug in" }
        return "At rest"
    }

    static func watches(_ count: Int) -> String {
        count == 1 ? "1 watch to go" : "\(count) watches to go"
    }
}
