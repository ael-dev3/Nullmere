/// Everything a House can order. Commands are validated against the rules
/// before anything changes; a rejected command changes nothing.
public enum Command: Codable, Equatable, Sendable {
    /// March toward a hex, as far as this watch allows, then onward in later watches.
    case move(unit: Int, to: Hex)
    /// Strike an enemy unit or hold in reach.
    case attack(unit: Int, target: Hex)
    /// Founders settle a new hold where they stand.
    case found(unit: Int)
    /// Start raising a building one level.
    case build(hold: Int, kind: BuildingKind)
    case train(hold: Int, kind: UnitKind)
    /// Trade a surplus away for something lacking, at three to one.
    case barter(give: Resource, take: Resource, amount: Int)
    /// Dig in: +25% defence until the unit moves.
    case fortify(unit: Int)
    case disband(unit: Int)
    /// Forget a march in progress.
    case halt(unit: Int)
    case declareWar(on: Int)
    case propose(Proposal, to: Int)
    /// An offer to a House held by a keeper, with a keeper's own words.
    case proposeWithWords(Proposal, to: Int, words: String)
    case answer(envoy: Int, accept: Bool)
    /// Stores sent to another House, not at war with the giver.
    case gift(to: Int, resource: Resource, amount: Int)
    /// An offer of trade, with a keeper's own words if it goes to a keeper.
    case offerTrade(Trade, to: Int, words: String?)
}

/// Why a command was refused, in words the interface can show as they are.
public enum RuleError: Error, Equatable, Sendable, CustomStringConvertible {
    case gameOver
    case unknownUnit
    case unknownHold
    case unknownHouse
    case notYours
    case noMovesLeft
    case alreadyThere
    case outsideTheWorld
    case impassable(Terrain)
    case noPath
    case notAtWar(Int)
    case nothingToAttack
    case outOfReach
    case cannotFight
    case notAFounder
    case cannotSettle(Terrain)
    case tooCloseToHold
    case foreignTerritory
    case busy
    case maxLevel
    case seatOnly
    case needsMusterHall(Int)
    case shortOf(Stock)
    case alreadyStance(Stance)
    case notApplicable
    case unknownEnvoy
    case envoyWaiting
    case invalidAmount
    /// A trade or barter of a store for the same store.
    case sameStore
    case storageFull
    /// A gift the receiving House has no room to keep.
    case noRoomWithThem
    /// A gift beyond what the receiving House may take in this watch, with
    /// the worth it may still take.
    case giftsThisWatch(left: Int)
    case atWarWith(Int)
    /// An offer of trade to a House at war with the trader.
    case noTradeAcrossWar(Int)

    public var description: String {
        switch self {
        case .gameOver: return "The age is over."
        case .unknownUnit: return "That company no longer exists."
        case .unknownHold: return "That hold no longer exists."
        case .unknownHouse: return "No such House."
        case .notYours: return "That isn't yours to command."
        case .noMovesLeft: return "It has no moves left this watch."
        case .alreadyThere: return "It's already there."
        case .outsideTheWorld: return "That lies beyond the Spine."
        case .impassable(let terrain): return "\(terrain.title) can't be crossed."
        case .noPath: return "There's no way there."
        case .notAtWar: return "You're not at war with them."
        case .nothingToAttack: return "There's nothing there to strike."
        case .outOfReach: return "That's out of reach."
        case .cannotFight: return "These aren't fighters."
        case .notAFounder: return "Only Founders can found a hold."
        case .cannotSettle(let terrain): return "A hold can't stand on \(terrain.title)."
        case .tooCloseToHold: return "Too close to another hold; it needs three tiles of room."
        case .foreignTerritory: return "That land belongs to another House."
        case .busy: return "That hold is already busy."
        case .maxLevel: return "It's already at its highest level."
        case .seatOnly: return "Only a House's seat can raise it."
        case .needsMusterHall(let level): return "Needs a Muster Hall \(BuildingKind.numeral(level))."
        case .shortOf(let missing): return "Short of \(missing)."
        case .alreadyStance(let stance): return "Already \(stance.standing)."
        case .notApplicable: return "That isn't possible now."
        case .unknownEnvoy: return "That envoy has gone."
        case .envoyWaiting: return "An envoy with that offer already waits on their answer."
        case .invalidAmount: return "Choose an amount."
        case .sameStore: return "Choose two different stores."
        case .storageFull: return "There's no room to store that much."
        case .noRoomWithThem: return "They have no room to store that much."
        case .giftsThisWatch(let left):
            return left == 0 ? "They can take no more gifts this watch." : "They can take gifts worth only \(left) more this watch; moonsalt counts four."
        case .atWarWith: return "A gift across a war is no gift."
        case .noTradeAcrossWar: return "No trade crosses a war."
        }
    }
}

/// What happened, for the interface to show and animate.
public enum GameEvent: Codable, Equatable, Sendable {
    case moved(unit: Int, path: [Hex])
    case battle(Battle)
    case unitLost(unit: Int, kind: UnitKind, owner: Int, at: Hex)
    case holdStruck(hold: Int, ward: Int)
    case holdCaptured(hold: Int, from: Int, by: Int)
    case seatMoved(house: Int, to: Int)
    case holdFounded(hold: Int)
    case buildingStarted(hold: Int, kind: BuildingKind, level: Int)
    case buildingCompleted(hold: Int, kind: BuildingKind, level: Int)
    case trainingStarted(hold: Int, kind: UnitKind)
    case bartered(house: Int, gave: Stock, took: Stock)
    case gifted(from: Int, to: Int, gift: Stock)
    /// An offer of trade taken or refused, and so carried out or not.
    case tradeAnswered(trade: Trade, from: Int, to: Int, accepted: Bool)
    case unitTrained(unit: Int, hold: Int)
    /// A company rose in rank after a battle.
    case promoted(unit: Int, owner: Int, rank: Int)
    case ruinSearched(at: Hex, by: Int, reward: Stock)
    case stanceChanged(first: Int, second: Int, stance: Stance, by: Int)
    case envoyArrived(Envoy)
    case proposalAnswered(proposal: Proposal, from: Int, to: Int, accepted: Bool)
    case starving(house: Int)
    case houseFell(Int)
    case gameEnded(Outcome)
}

/// One exchange of blows.
public struct Battle: Codable, Equatable, Sendable {
    public let attacker: Int
    public let attackerOwner: Int
    public let attackerKind: UnitKind
    /// The defending unit, or nil when a hold's ward was struck.
    public let defender: Int?
    public let defenderOwner: Int
    public let defenderKind: UnitKind?
    public let hold: Int?
    public let at: Hex
    public let damageDealt: Int
    public let damageTaken: Int
    public let attackerFell: Bool
    public let defenderFell: Bool

    public init(
        attacker: Int, attackerOwner: Int, attackerKind: UnitKind,
        defender: Int?, defenderOwner: Int, defenderKind: UnitKind?,
        hold: Int?, at: Hex, damageDealt: Int, damageTaken: Int,
        attackerFell: Bool, defenderFell: Bool
    ) {
        self.attacker = attacker
        self.attackerOwner = attackerOwner
        self.attackerKind = attackerKind
        self.defender = defender
        self.defenderOwner = defenderOwner
        self.defenderKind = defenderKind
        self.hold = hold
        self.at = at
        self.damageDealt = damageDealt
        self.damageTaken = damageTaken
        self.attackerFell = attackerFell
        self.defenderFell = defenderFell
    }
}
