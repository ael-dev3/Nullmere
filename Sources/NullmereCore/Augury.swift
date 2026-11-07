/// The Augury: a keeper foretells a turn of the realm's course, a House
/// fallen, a hold taken, a war, a Moonspire risen, by a watch to come, and
/// stakes moonsalt on it; other keepers back it or stand against it while
/// the first half of its span lasts; and the realm judges it as the
/// watches turn, by what has come to pass, the side that saw true sharing
/// every stake laid, each by its own. No odds are set and no keeper judges:
/// the realm keeps the book. Stewards foretell and stake nothing, so a world
/// of stewards goes as it always did.
public struct Prophecy: Codable, Equatable, Identifiable, Sendable {
    /// What a prophecy foretells.
    public enum Claim: Codable, Equatable, Hashable, Sendable {
        /// A House falls.
        case falls(house: Int)
        /// A House takes a hold of another's.
        case takesAHold(house: Int)
        /// Two Houses are at war.
        case war(Int, Int)
        /// A House's Moonspire rises to a stage.
        case spireRises(house: Int, stage: Int)
    }

    /// A House's stake: whether it backs the prophecy or stands against
    /// it, and the moonsalt laid; once judged, what each of the side that
    /// saw true took.
    public struct Stake: Codable, Equatable, Sendable {
        public let house: Int
        public let backs: Bool
        public let moonsalt: Int

        public init(house: Int, backs: Bool, moonsalt: Int) {
            self.house = house
            self.backs = backs
            self.moonsalt = moonsalt
        }
    }

    public let id: Int
    /// The House that foretold it.
    public let by: Int
    public let claim: Claim
    /// The watch it was spoken.
    public let spoken: Int
    /// The watch by which it comes to pass, or fails.
    public let until: Int
    public internal(set) var stakes: [Stake]
    /// Whether it came to pass, once judged; nil while it is open.
    public internal(set) var cameToPass: Bool?

    public init(id: Int, by: Int, claim: Claim, spoken: Int, until: Int, stakes: [Stake], cameToPass: Bool? = nil) {
        self.id = id
        self.by = by
        self.claim = claim
        self.spoken = spoken
        self.until = until
        self.stakes = stakes
        self.cameToPass = cameToPass
    }

    public var isOpen: Bool { cameToPass == nil }

    /// The moonsalt of a stake laid from the Mac's Augury or the phone.
    public static let stakeLaid = 10

    /// How it stands, in a line, on the Mac and the phone: what is laid on
    /// each side, and until when; or how the realm judged it.
    public func standingSaid(at watch: Int) -> String {
        let laid = "\(laid(backing: true)) moonsalt backing it, \(laid(backing: false)) against"
        switch cameToPass {
        case true?: return "Came to pass. \(laid)."
        case false?: return "Failed. \(laid)."
        case nil: return watch <= stakesClose ? "\(laid); stakes close at watch \(stakesClose)." : "\(laid); stakes are closed."
        }
    }
    /// The last watch a stake may be laid on it: halfway through its span.
    public var stakesClose: Int { spoken + (until - spoken) / 2 }
    /// Every stake laid on it.
    public var pool: Int { stakes.reduce(0) { $0 + $1.moonsalt } }
    /// The moonsalt laid on one side.
    public func laid(backing: Bool) -> Int {
        stakes.filter { $0.backs == backing }.reduce(0) { $0 + $1.moonsalt }
    }
}

extension GameState {
    /// How many watches ahead a prophecy may look.
    public static let prophecySpan = 6...30
    /// The moonsalt a stake may be.
    public static let stakeBounds = 5...50
    /// The judged prophecies the realm keeps, the latest.
    public static let propheciesKept = 12

    /// The realm's prophecies, open and lately judged, the earliest first.
    public var prophecies: [Prophecy] { auguries ?? [] }

    /// The prophecies not yet judged.
    public var openProphecies: [Prophecy] { prophecies.filter(\.isOpen) }

    /// Whether what a prophecy foretells has come to pass, since a watch.
    func hasComeToPass(_ claim: Prophecy.Claim, since spoken: Int) -> Bool {
        switch claim {
        case .falls(let house):
            return houses.indices.contains(house) && houses[house].isEliminated
        case .takesAHold(let house):
            return chronicle.contains { $0.kind == .capture && $0.watch >= spoken && $0.houses.first == house }
        case .war(let first, let second):
            return houses.indices.contains(first) && houses.indices.contains(second) && stance(first, second) == .war
        case .spireRises(let house, let stage):
            return highest(.moonspire, of: house) >= stage
        }
    }

    private func isLiving(_ house: Int) -> Bool {
        houses.indices.contains(house) && !houses[house].isEliminated
    }

    private func keeperRefusal(_ house: Int) -> RuleError? {
        guard isLiving(house), houses[house].isPlayer else { return .notAKeeper }
        return nil
    }

    /// Why a House can't foretell this now, if it can't: a keeper's, with
    /// no prophecy of its own still open, looking six to thirty watches
    /// ahead, staking five to fifty moonsalt it has, of living Houses, and
    /// of what has not come to pass already.
    public func prophecyRefusal(_ claim: Prophecy.Claim, until: Int, moonsalt: Int, as house: Int) -> RuleError? {
        if let refusal = keeperRefusal(house) { return refusal }
        guard !openProphecies.contains(where: { $0.by == house }) else { return .prophecyOpen }
        guard GameState.prophecySpan.contains(until - watch), GameState.stakeBounds.contains(moonsalt) else { return .invalidAmount }
        guard houses[house].stock.moonsalt >= moonsalt else { return .shortOf(Stock(moonsalt: moonsalt - houses[house].stock.moonsalt)) }
        switch claim {
        case .falls(let other), .takesAHold(let other):
            guard isLiving(other) else { return .notApplicable }
        case .war(let first, let second):
            guard first != second, isLiving(first), isLiving(second) else { return .notApplicable }
        case .spireRises(let other, let stage):
            guard isLiving(other), (1...BuildingKind.moonspire.maxLevel).contains(stage) else { return .notApplicable }
        }
        guard !hasComeToPass(claim, since: watch) else { return .comeToPassAlready }
        return nil
    }

    /// A keeper foretells, staking moonsalt that it comes to pass.
    mutating func prophesy(_ claim: Prophecy.Claim, until: Int, moonsalt: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = prophecyRefusal(claim, until: until, moonsalt: moonsalt, as: house) { throw refusal }
        houses[house].stock.debit(Stock(moonsalt: moonsalt))
        let prophecy = Prophecy(id: (auguries?.map(\.id).max() ?? 0) + 1, by: house, claim: claim, spoken: watch, until: until,
                                stakes: [Prophecy.Stake(house: house, backs: true, moonsalt: moonsalt)])
        auguries = prophecies + [prophecy]
        record(.augury, [house], "\(houses[house].title) foretells that \(told(claim)) by watch \(until), staking \(moonsalt) moonsalt.")
        return [.prophesied(prophecy)]
    }

    /// Why a House can't lay a stake on a prophecy now, if it can't: a
    /// keeper's, on one still open with stakes not yet closed, once, and
    /// five to fifty moonsalt it has.
    public func stakeRefusal(on id: Int, moonsalt: Int, as house: Int) -> RuleError? {
        if let refusal = keeperRefusal(house) { return refusal }
        guard let prophecy = prophecies.first(where: { $0.id == id }), prophecy.isOpen else { return .unknownProphecy }
        guard !prophecy.stakes.contains(where: { $0.house == house }) else { return .stakedAlready }
        guard watch <= prophecy.stakesClose else { return .stakesClosed(prophecy.stakesClose) }
        guard GameState.stakeBounds.contains(moonsalt) else { return .invalidAmount }
        guard houses[house].stock.moonsalt >= moonsalt else { return .shortOf(Stock(moonsalt: moonsalt - houses[house].stock.moonsalt)) }
        return nil
    }

    /// A keeper backs a prophecy, or stands against it, with moonsalt.
    mutating func stake(on id: Int, backs: Bool, moonsalt: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = stakeRefusal(on: id, moonsalt: moonsalt, as: house) { throw refusal }
        guard let index = auguries?.firstIndex(where: { $0.id == id }) else { throw .unknownProphecy }
        houses[house].stock.debit(Stock(moonsalt: moonsalt))
        auguries![index].stakes.append(Prophecy.Stake(house: house, backs: backs, moonsalt: moonsalt))
        return [.staked(prophecy: id, house: house, backs: backs, moonsalt: moonsalt)]
    }

    /// As the watch turns: each open prophecy that has come to pass is
    /// judged true, and each whose watch has come without it, false; the
    /// side that saw true shares every stake laid, each by its own, and if
    /// none saw true the lake keeps them. The last few judged are kept.
    mutating func judgeProphecies() -> [GameEvent] {
        guard var list = auguries, list.contains(where: \.isOpen) else { return [] }
        var events: [GameEvent] = []
        for index in list.indices where list[index].isOpen {
            let prophecy = list[index]
            let passed = hasComeToPass(prophecy.claim, since: prophecy.spoken)
            guard passed || watch >= prophecy.until else { continue }
            list[index].cameToPass = passed
            let seers = prophecy.stakes.filter { $0.backs == passed }
            let laid = prophecy.laid(backing: passed)
            var paid: [Prophecy.Stake] = []
            for seer in seers where laid > 0 && isLiving(seer.house) {
                let share = prophecy.pool * seer.moonsalt / laid
                store(Stock(moonsalt: share), for: seer.house)
                paid.append(Prophecy.Stake(house: seer.house, backs: passed, moonsalt: share))
            }
            let houses = Array(Set(prophecy.stakes.map(\.house))).sorted()
            record(.augury, houses, "The prophecy of \(self.houses[prophecy.by].title), that \(told(prophecy.claim)) by watch \(prophecy.until), "
                   + (passed ? "comes to pass." : "fails."))
            events.append(.prophecyJudged(prophecy: prophecy.id, cameToPass: passed, paid: paid))
        }
        let judged = list.filter { !$0.isOpen }.map(\.id)
        let forgotten = Set(judged.dropLast(GameState.propheciesKept))
        auguries = list.filter { !forgotten.contains($0.id) }
        return events
    }

    /// What a prophecy foretells, as a sentence says it after "that".
    /// A prophecy as the Mac's Augury and the phone tell it: who foretold
    /// what, and by when.
    public func prophecySaid(_ prophecy: Prophecy, to house: Int) -> String {
        let prophet = prophecy.by == house ? "You foretold"
            : "\(houses.indices.contains(prophecy.by) ? houses[prophecy.by].title : "A fallen House") foretells"
        return "\(prophet) that \(told(prophecy.claim)) by watch \(prophecy.until)."
    }

    public func told(_ claim: Prophecy.Claim) -> String {
        func name(_ house: Int) -> String { houses.indices.contains(house) ? houses[house].title : "a fallen House" }
        switch claim {
        case .falls(let house): return "\(name(house)) will fall"
        case .takesAHold(let house): return "\(name(house)) will take a hold"
        case .war(let first, let second): return "\(name(first)) and \(name(second)) will be at war"
        case .spireRises(let house, let stage): return "the Moonspire of \(name(house)) will rise to its \(ordinal(stage)) stage"
        }
    }
}
