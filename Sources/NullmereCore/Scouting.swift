/// What a House's Lanterns saw of another House's hold from close by: the
/// companies at its gates, its ward, what it has under way, the stores its
/// taking would carry off, and how many lie in its beds.
public struct ScoutReport: Codable, Equatable, Sendable {
    /// A company of war seen at the hold's gates.
    public struct Company: Codable, Equatable, Sendable {
        public let kind: UnitKind
        public let tier: Int
        public let health: Int
        public let rank: Int
        public let owner: Int
        /// The name of the commander leading it, if one does.
        public let commander: String?

        public init(kind: UnitKind, tier: Int, health: Int, rank: Int, owner: Int, commander: String?) {
            self.kind = kind
            self.tier = tier
            self.health = health
            self.rank = rank
            self.owner = owner
            self.commander = commander
        }
    }

    public let hold: Int
    public let owner: Int
    /// The House whose Lanterns scouted it.
    public let by: Int
    public let watch: Int
    public let garrison: [Company]
    public let ward: Int
    public let maximumWard: Int
    public let project: Hold.Project?
    public let training: Hold.Training?
    /// What its taking would carry off of its House's stores.
    public let spoils: Stock
    /// The companies lying in its Infirmary's beds.
    public let wounded: Int

    public init(hold: Int, owner: Int, by: Int, watch: Int, garrison: [Company], ward: Int, maximumWard: Int,
                project: Hold.Project?, training: Hold.Training?, spoils: Stock, wounded: Int) {
        self.hold = hold
        self.owner = owner
        self.by = by
        self.watch = watch
        self.garrison = garrison
        self.ward = ward
        self.maximumWard = maximumWard
        self.project = project
        self.training = training
        self.spoils = spoils
        self.wounded = wounded
    }
}

extension GameState {
    /// How near another House's hold a Lantern must stand to scout it.
    public static let scoutReach = 2

    /// What taking a hold would carry off of its House's stores: half of
    /// them from its seat, its share from another hold.
    public func spoils(ofTaking hold: Hold) -> Stock {
        guard houses.indices.contains(hold.owner) else { return .zero }
        return houses[hold.owner].stock.share(1, of: hold.isSeat ? 2 : max(holds(of: hold.owner).count, 1))
    }

    /// Lanterns standing within reach of another House's hold scout it, for
    /// all their moves: what they see is their House's report, and the
    /// hold's House hears that it was watched. At peace or at war alike.
    mutating func scout(_ holdID: Int, with unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        let unit = units[index]
        guard unit.kind == .lantern else { throw .notAScout }
        guard let hold = hold(holdID) else { throw .unknownHold }
        guard hold.owner != house else { throw .ownHold }
        guard unit.position.distance(to: hold.position) <= GameState.scoutReach else { throw .outOfReach }
        guard unit.movesLeft > 0 else { throw .noMovesLeft }
        units[index].movesLeft = 0
        units[index].acted = true
        units[index].destination = nil
        // Its own companies at its gates, and its allies' keeping them.
        let side = Set([hold.owner] + (alliance(of: hold.owner)?.members ?? []))
        let garrison = units
            .filter { $0.kind.isMilitary && side.contains($0.owner) && $0.position.distance(to: hold.position) <= 1 }
            .sorted { $0.id < $1.id }
            .map { company in
                ScoutReport.Company(kind: company.kind, tier: company.tier, health: company.health, rank: company.rank,
                                    owner: company.owner, commander: company.leader.flatMap { commander($0)?.name })
            }
        let report = ScoutReport(hold: hold.id, owner: hold.owner, by: house, watch: watch, garrison: garrison, ward: hold.ward,
                                 maximumWard: hold.maximumWard, project: hold.project, training: hold.training,
                                 spoils: spoils(ofTaking: hold), wounded: hold.wounded?.count ?? 0)
        return [.holdScouted(report), .scoutSeen(hold: hold.id, by: house)]
    }
}
