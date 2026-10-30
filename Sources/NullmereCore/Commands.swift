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
    /// Muster a company at a hold, of a tier from I to V; absent, the first
    /// (an order from before tiers reads so).
    case train(hold: Int, kind: UnitKind, tier: Int? = nil)
    /// Trade a surplus away for something lacking, at three to one,
    /// moonsalt counted as three of any other store.
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
    /// Begin the next grade of a study at the House's Archive.
    case study(Study)
    /// A commander takes up a company of war standing at or beside one of
    /// the House's holds.
    case assign(commander: Int, unit: Int)
    /// A commander leaves its company, wherever it is, and rides home.
    case unassign(commander: Int)
    /// A company of war marches to a site of the land and works it until
    /// it carries all it can, then brings it home to the nearest hold.
    case gather(unit: Int, site: Int)
    /// Raise a banner: found an alliance of this name, and lead it.
    case foundAlliance(name: String)
    /// Its leader invites a House into the alliance.
    case inviteToAlliance(house: Int)
    /// Ask to join an alliance; its leader answers.
    case askToJoin(alliance: Int)
    /// An invited House answers its invitation.
    case answerInvitation(alliance: Int, accept: Bool)
    /// An alliance's leader answers a House asking to join.
    case answerRequest(house: Int, accept: Bool)
    case leaveAlliance
    /// Its leader casts a House out of the alliance.
    case expel(house: Int)
    /// Help every work, muster and study of an ally's not helped yet.
    case help(house: Int)
    /// Call a rally at one of the House's holds against a hold of a House
    /// at war with it: its alliance's companies gather there for one to
    /// four watches, then march on the hold together and strike it together.
    case callRally(from: Int, against: Int, watches: Int)
    /// Send a company of war to a rally of the House's alliance.
    case joinRally(rally: Int, unit: Int)
    /// Send a company of war to keep the gates of an ally's hold.
    case reinforce(unit: Int, hold: Int)
    /// A keeper's words, to the whole realm or to their alliance alone.
    case say(words: String, toAlliance: Bool)
    /// A commander learns the next rank of a talent, for a talent point.
    case learnTalent(commander: Int, talent: Talent)
    /// A commander forgets every talent it has learned, its points given
    /// back to learn anew, for moonsalt.
    case forgetTalents(commander: Int)
    /// A commander takes up a piece of the House's gear, in its slot.
    case wear(gear: Int, commander: Int)
    /// A piece of gear taken off, back to the armoury.
    case takeOff(gear: Int)
    /// A piece of gear broken up for its moonsalt.
    case breakUp(gear: Int)
    /// Pay for the healing of the companies lying in a hold's Infirmary,
    /// as many as the House's stores cover; they rise as the watch turns.
    case heal(hold: Int)
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
    /// A tier beyond the first, for a kind that musters in one.
    case oneTierOnly(UnitKind)
    /// A tier that isn't one of I to V.
    case noSuchTier
    /// A study begun while another is under way.
    case studyUnderWay(Study)
    /// A study already known to its last grade.
    case studiedFully
    /// A study, or a tier, that needs an Archive of this level.
    case needsArchive(Int)
    /// A study, or a tier, that needs another study first, to this grade.
    case needsStudy(Study, Int)
    /// No commander of the House's by that id.
    case unknownCommander
    /// A commander still mending, for so many watches.
    case commanderWounded(Int)
    /// A commander already at the head of a company.
    case commanderLeads
    /// A company with a commander already.
    case alreadyLed
    /// A kind of company no commander leads.
    case cannotLead(UnitKind)
    /// A company too far from its House's holds to take up a commander.
    case awayFromHolds
    /// A commander at the head of no company.
    case notLeading
    /// A site the House doesn't know of, or no longer there.
    case unknownSite
    /// A kind of company that gathers nothing.
    case cannotGather(UnitKind)
    /// A company carrying all it can, or another store than the site's.
    case loadFull
    /// A House sworn to an alliance already.
    case inAnAlliance
    /// A House sworn to no alliance.
    case notInAlliance
    /// What only an alliance's leader may do.
    case notAllianceLeader
    case allianceNameInvalid
    case allianceNameTaken
    case unknownAlliance
    /// A House at war with one of the alliance's: no alliance takes in a war.
    case atWarWithAMember(Int)
    case allianceFull
    case alreadyInvited
    case alreadyAsked
    case noInvitation
    case noRequest
    case notAMember
    /// Help for a House not of one's alliance.
    case notAnAlly
    case nothingToHelp
    /// War, or a demand, on a House of one's own alliance.
    case allyInAlliance(Int)
    /// A rally no longer gathering, or not of the House's alliance.
    case unknownRally
    /// A House that has called a rally already, still gathering or marching.
    case rallyCalled
    /// A gathering of other than one to four watches.
    case rallyWatches
    /// A host already on the march.
    case rallySetOut
    /// A rally with all the companies its muster can take.
    case rallyFull
    /// A company already sent to that rally.
    case alreadyRallying
    /// A hold not of an ally's to keep.
    case notAnAllysHold
    /// A commander with no talent point left to spend.
    case noTalentPoints
    /// A talent learned to its last rank.
    case talentMastered
    /// A talent opened only by another, learned first.
    case needsTalent(Talent)
    /// Talents forgotten by a commander that has learned none.
    case nothingToForget
    /// Gear the House doesn't hold.
    case unknownGear
    /// Gear the commander wears already.
    case alreadyWorn
    /// Gear no commander wears.
    case notWorn
    /// A hold founded on a holy site.
    case holySite
    /// Healing for a hold with no company in its beds waiting for it.
    case noneWounded
    /// Words from a House no keeper holds.
    case notAKeeper
    /// Words that say nothing an envoy, or the realm, would carry.
    case nothingToSay
    /// As many words as a watch allows, said.
    case saidEnough

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
            // Whoever's bound it is: a trade between keepers may fill the
            // asker's own.
            return left == 0 ? "No more gifts can be taken in this watch." : "Gifts worth only \(left) more can be taken in this watch; moonsalt counts four."
        case .atWarWith: return "A gift across a war is no gift."
        case .noTradeAcrossWar: return "No trade crosses a war."
        case .oneTierOnly(let kind): return "\(kind.title) muster in one tier only."
        case .noSuchTier: return "Companies muster in tiers I to V."
        case .studyUnderWay(let study): return "Your House already studies \(study.title); one study at a time."
        case .studiedFully: return "That study is known to its last grade."
        case .needsArchive(let level): return "Needs an Archive \(BuildingKind.numeral(level))."
        case .needsStudy(let study, let grade):
            return "Needs the study of \(study.title)" + (study.grades > 1 ? " \(BuildingKind.numeral(grade))." : ".")
        case .unknownCommander: return "No such commander serves your House."
        case .commanderWounded(let watches): return "That commander is wounded; whole again in \(watches) watch\(watches == 1 ? "" : "es")."
        case .commanderLeads: return "That commander already leads a company."
        case .alreadyLed: return "That company already has a commander."
        case .cannotLead(let kind): return "\(kind.title) take no commander."
        case .awayFromHolds: return "A commander takes up a company at or beside one of your holds."
        case .notLeading: return "That commander leads no company."
        case .unknownSite: return "Your House knows of no such site."
        case .cannotGather(let kind): return "\(kind.title) gather nothing."
        case .loadFull: return "It carries all it can; bring it home first."
        case .inAnAlliance: return "That House is sworn to an alliance already."
        case .notInAlliance: return "Your House is sworn to no alliance."
        case .notAllianceLeader: return "Only the alliance's leader can do that."
        case .allianceNameInvalid: return "An alliance's name is two to twenty-four letters, spaces, hyphens or apostrophes."
        case .allianceNameTaken: return "An alliance already goes by that name."
        case .unknownAlliance: return "No such alliance stands."
        case .atWarWithAMember: return "No alliance takes in a House at war with one of its own."
        case .allianceFull: return "The alliance is full."
        case .alreadyInvited: return "That House is already invited."
        case .alreadyAsked: return "Your House has already asked."
        case .noInvitation: return "No such invitation waits for you."
        case .noRequest: return "That House hasn't asked to join."
        case .notAMember: return "That House isn't of your alliance."
        case .notAnAlly: return "Only an ally can be helped."
        case .nothingToHelp: return "Your ally has nothing under way you haven't helped."
        case .allyInAlliance: return "Your House is sworn to the same alliance as theirs."
        case .unknownRally: return "No such rally gathers for your alliance."
        case .rallyCalled: return "Your House has called a rally already; one at a time."
        case .rallyWatches: return "A rally gathers for one to four watches."
        case .rallySetOut: return "That host has already set out."
        case .rallyFull: return "That rally's muster can take no more companies."
        case .alreadyRallying: return "That company is already sent to that rally."
        case .noTalentPoints: return "That commander has no talent point left; it gains one at each level."
        case .talentMastered: return "That talent is learned to its last rank."
        case .needsTalent(let talent): return "Needs \(talent.title) first."
        case .nothingToForget: return "That commander has learned no talents."
        case .unknownGear: return "Your House holds no such gear."
        case .alreadyWorn: return "That commander wears it already."
        case .notWorn: return "No commander wears it."
        case .holySite: return "No hold is raised on a holy site."
        case .noneWounded: return "No company lies in that hold's Infirmary waiting to be healed."
        case .notAnAllysHold: return "Only an ally's hold can be kept."
        case .notAKeeper: return "Only a keeper's words are carried."
        case .nothingToSay: return "Those words say nothing the realm can carry: plain words, with no addresses."
        case .saidEnough: return "You have said all a watch allows; say more as the watch turns."
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
    /// A House begins a grade of a study.
    case studyBegun(house: Int, study: Study, grade: Int)
    /// A House learns a grade of a study.
    case studyCompleted(house: Int, study: Study, grade: Int)
    /// A commander comes to a House.
    case commanderJoined(commander: Int, house: Int)
    /// A commander takes up a company.
    case commanderAssigned(commander: Int, unit: Int)
    /// A commander leaves its company and rides home.
    case commanderReleased(commander: Int)
    /// A commander rises to a level.
    case commanderRose(commander: Int, house: Int, level: Int)
    /// A commander whose company fell is carried home wounded.
    case commanderWounded(commander: Int, house: Int)
    /// A commander's active skill fires in a battle.
    case skillFired(commander: Int, house: Int, skill: Skill, at: Hex)
    /// A commander learns a rank of a talent.
    case talentLearned(commander: Int, house: Int, talent: Talent, rank: Int)
    /// A commander forgets its talents, to learn anew.
    case talentsForgotten(commander: Int, house: Int)
    /// A House finds a piece of gear on the wilds it struck down.
    case gearFound(house: Int, gear: Gear, from: WildKind)
    /// A commander takes up a piece of gear.
    case gearWorn(commander: Int, house: Int, gear: Int)
    /// A piece of gear taken off, back to the armoury.
    case gearTakenOff(commander: Int, house: Int, gear: Int)
    /// A piece of gear broken up for moonsalt.
    case gearScrapped(house: Int, gear: Int, moonsalt: Int)
    /// A House takes a holy site, from another or from none.
    case shrineTaken(shrine: Int, house: Int, from: Int?)
    /// A company of war that fell is carried to a hold's Infirmary.
    case carriedToInfirmary(kind: UnitKind, owner: Int, hold: Int)
    /// A House pays for the healing of companies in a hold's Infirmary.
    case healingBegun(hold: Int, house: Int, count: Int)
    /// A company healed rises whole beside its hold.
    case unitHealed(unit: Int, hold: Int)
    /// A hold taken with companies in its beds: they are lost with it.
    case woundedLost(hold: Int, house: Int, count: Int)
    /// A company strikes a company of the wilds.
    case hunted(Hunt)
    /// A company sets out to work a site.
    case sentToGather(unit: Int, site: Int)
    /// A company carries all it can, or its site is worked out: it turns
    /// for home with its load.
    case gathered(unit: Int, owner: Int, load: Stock)
    /// A company gives up its load at one of its House's holds.
    case delivered(unit: Int, owner: Int, hold: Int, load: Stock)
    /// A site is worked out and gone.
    case siteWorkedOut(site: Int, store: Resource, at: Hex)
    /// A House raises a banner.
    case allianceFounded(alliance: Int, house: Int)
    /// An alliance's leader invites a House.
    case allianceInvited(alliance: Int, house: Int)
    /// A House asks to join an alliance.
    case allianceAsked(alliance: Int, house: Int)
    /// An invitation, or a request to join, answered.
    case allianceAnswered(alliance: Int, house: Int, accepted: Bool)
    case allianceJoined(alliance: Int, house: Int)
    /// A House leaves an alliance, or is cast out of it.
    case allianceLeft(alliance: Int, house: Int, expelled: Bool)
    /// A House takes up an alliance's banner as its leader.
    case allianceLed(alliance: Int, house: Int)
    /// An alliance left with no House is no more.
    case allianceDisbanded(alliance: Int, name: String)
    /// A House helps an ally's works, musters and study.
    case helpGiven(by: Int, to: Int, count: Int)
    /// A House calls a rally at one of its holds against a hold.
    case rallyCalled(rally: Int, caller: Int, target: Int)
    /// A company is sent to a rally.
    case rallyJoined(rally: Int, unit: Int, house: Int)
    /// A rally's host sets out from its muster against a House's hold.
    case rallySetOut(rally: Int, caller: Int, target: Int, defender: Int, companies: Int)
    /// A host strikes its hold together; whether it took it.
    case rallyStruck(rally: Int, caller: Int, target: Int, defender: Int, taken: Bool)
    /// A rally comes to nothing.
    case rallyDispersed(rally: Int, caller: Int)
    /// A company is sent to keep the gates of an ally's hold.
    case sentToReinforce(unit: Int, owner: Int, hold: Int)
    /// A happening of the realm begins, to end as the watch named begins.
    case happeningBegun(kind: HappeningKind, ends: Int)
    /// A House passes a mark of a happening's points, and is given stores.
    case happeningMark(house: Int, kind: HappeningKind, mark: Int, reward: Stock)
    /// A happening ends; its foremost Houses, first first.
    case happeningEnded(kind: HappeningKind, leaders: [Int])
    /// A House's deed, told as the watch turns after it was done.
    case deedDone(house: Int, deed: Deed)
    /// A House has done its charge, and is given stores.
    case chargeDone(house: Int, charge: Charge, reward: Stock)
    /// A keeper's words, said to the realm or to their alliance.
    case said(Word)
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
