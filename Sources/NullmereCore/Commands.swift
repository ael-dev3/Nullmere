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
    /// Drill at the Muster Hall of a hold the company stands at or beside:
    /// troops taken on as each watch turns while it stays there, up to as
    /// many as it can lead.
    case drill(unit: Int)
    /// A company raised a tier where it stands, by a Muster Hall of its
    /// House's at or beside it (Rise of Kingdoms' troop upgrade).
    case raiseTier(unit: Int)
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
    /// A second commander sent to ride with a company's leader.
    case assignSecond(commander: Int, unit: Int)
    /// A commander leaves its company, wherever it is, and rides home.
    case unassign(commander: Int)
    /// A company of war marches to a site of the land and works it until
    /// it carries all it can, or for so many watches when they are named,
    /// then brings what it carries home to the nearest hold.
    case gather(unit: Int, site: Int, watches: Int? = nil)
    /// A company gathering, or carrying a load, is called home: it turns
    /// for the nearest of its House's holds with all it carries.
    case recall(unit: Int)
    /// Every company of the House gathering at the land's sites, or
    /// carrying a load, is called home at once.
    case recallAll
    /// Hide another House from this keeper's hearing, or hear it again:
    /// its words and its envoys kept from them at the realm.
    case hideHouse(house: Int, hidden: Bool)
    /// Answer a question of the sitting Lyceum.
    case answerLyceum(question: Int, choice: Int)
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
    /// Its leader, or one of its officers, casts a House out of the alliance.
    case expel(house: Int)
    /// Its leader names one of its Houses an officer, or names them one no
    /// longer.
    case nameOfficer(house: Int, named: Bool)
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
    /// A place shared in a keeper's words, by the name they give it, to the
    /// whole realm or to their alliance alone.
    case sharePlace(at: Hex, named: String, toAlliance: Bool)
    /// A ballad of a Chronicle entry, made on the keeper's Mac, sung to
    /// the realm for its songbook.
    case sing(ballad: String, of: Int)
    /// Words sealed in a bottle and set on the water from a hold on the
    /// shore, signed or not.
    case castBottle(words: String, from: Int, signed: Bool)
    /// A light set on the water from a hold on the shore for the House's
    /// fallen, with the keeper's words for them.
    case keepVigil(words: String, hold: Int)
    /// Another House's vigil honoured: renown to its keeper as the age
    /// ends, and no strike on its House while its light burns.
    case honourVigil(Int)
    /// The keeper's answer to a plea their House's folk brought: granted,
    /// paid for, or turned away.
    case answerPetition(Int, grant: Bool)
    /// An alliance's leader marks ground for its Houses: to gather there,
    /// strike there, hold it or beware it, with a few words if they will.
    case markGround(Hex, AllianceMark.Kind, words: String?)
    /// An alliance's leader lifts one of its marks.
    case unmarkGround(Int)
    /// A keeper's company of war sets the blackwood where it stands alight
    /// (see `Wildfire`).
    case kindle(unit: Int)
    /// A company douses its torches to march dark, or lights them again
    /// (see `GameState.isUnlit`).
    case torches(unit: Int, lit: Bool)
    /// A company marching dark in the blackwood lies in wait there, or
    /// gives it up (see `GameState.isWaiting`).
    case lieInWait(unit: Int, waiting: Bool)
    /// A watchfire lit on open ground of the House's own land
    /// (`Watchfire`), for timber: its House sees about it, and makes out
    /// companies marching dark there.
    case watchfire(Hex)
    /// A company buries the dead lying unburied where it stands under a
    /// barrow, its watch spent (`FieldOfDead`).
    case bury(unit: Int)
    /// Sends the House's Lanterns, on or beside a hamlet or barrow the
    /// House knows of (`Find`), to seek it: a hamlet's gift, a barrow's
    /// grave goods; each House seeks each once.
    case seek(unit: Int, find: Int)
    /// Seals a letter under the stones of a hold, for the age to come.
    case sealLetter(words: String, hold: Int)
    /// A standing order for the caretaker that keeps the House while its
    /// keeper is away; and every standing order cleared.
    case stand(StandingOrder)
    case standDown
    /// A prisoner questioned, ransomed by their House, or let go by their captor.
    case question(commander: Int)
    case ransom(commander: Int)
    case release(commander: Int)
    /// An oath sworn to another House, for so many watches; and one
    /// renounced, with notice.
    case swear(OathTerm, to: Int, watches: Int)
    case renounce(oath: Int)
    /// A line of another keeper's reported to the realm's steward.
    case reportWord(word: Int)
    /// An edict put to the realm, for every House to vote on.
    case proposeEdict(kind: EdictKind)
    /// A House's vote on the edict before the realm: aye or nay.
    case voteEdict(edict: Int, aye: Bool)
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
    /// Lanterns within two tiles of another House's hold scout it, for all
    /// their moves, and bring back what they saw.
    case scout(unit: Int, hold: Int)
    /// A House of an alliance raises a standard on open land near the
    /// alliance's holds, standards or hall: the land about it is the
    /// alliance's.
    case raiseStandard(at: Hex)
    /// Lend a hand to the alliance's rising standard: a watch sooner.
    case helpStandard(standard: Int)
    /// A House uses an item from its satchel: a ward stone, or an hourglass
    /// that hastens a hold's work and muster, on one of its holds; caches,
    /// draughts and an hourglass naming no hold, on the House itself.
    case useItem(ItemKind, hold: Int?)
    /// A commander of the House reads one of its tomes, for experience.
    case readTome(commander: Int)
    /// A House takes up a heritage: the first time freely, after that for
    /// moonsalt.
    case takeHeritage(Heritage)
    /// A House takes its crest, once an age.
    case takeCrest(Crest)
    /// A keeper sets a work of one of its holds in a place of its own round
    /// the keep, one of `Hold.placeCount`; a work set there before takes
    /// the moved work's place.
    case placeWork(hold: Int, kind: BuildingKind, place: Int)
    /// The keeper whose House holds the broken Spire names another House
    /// to one of the realm's titles.
    case bestow(Title, on: Int)
    /// A keeper foretells a turn of the realm's course by a watch to come,
    /// staking moonsalt that it comes to pass.
    case prophesy(Prophecy.Claim, until: Int, moonsalt: Int)
    /// A keeper backs a prophecy, or stands against it, with moonsalt.
    case stake(prophecy: Int, backs: Bool, moonsalt: Int)
    /// A keeper draws the veil of the Still over their House's holds.
    case drawVeil
    /// A keeper takes every share of their alliance's spoils waiting for
    /// their House (`AllianceShare`).
    case takeShares
    /// A keeper raises their House's seat anew on open ground of its own
    /// land, or of its alliance's.
    case raiseSeat(at: Hex)
    /// A keeper sets a company, at a shore hold of theirs, on a barge across
    /// the still water to another of their shore holds.
    case ferry(unit: Int, to: Int)
    /// A keeper stands a line of their House's commanders in the Ring.
    case standInTheRing([Int])
    /// A keeper's line in the Ring challenges another House's.
    case challenge(house: Int)
    /// A keeper lets a whisper loose about another House, unsigned.
    case whisper(Whisper.Claim)
    /// A keeper answers their House's riddle with one of its names.
    case answerRiddle(String)
    /// A ripple-stone cast from a hold on the shore, so the House's
    /// companies are not mirrored at the next Still Hour.
    case castRipple(hold: Int)
    /// A listening stone sunk in the water before a hold on the shore, to
    /// hear marches out of sight.
    case sinkStone(hold: Int)
    /// A commander's stars raised by one, for sculptures set at its seat.
    case raiseStar(commander: Int)
    /// A letter to another House's keeper, for them alone.
    case writeLetter(to: Int, words: String)
    /// A ware bought of the pedlar lying off the House's hold.
    case buyFromPedlar(ware: Int)
    /// A chest opened at the Lantern Inn: with a key, or a gold one for moonsalt.
    case openInnChest(InnChest)
    /// A company of war on the Still's shore steps into its reflection.
    case walkTheMirror(unit: Int)
    /// A commander sent at the House's next stage of the Spine.
    case venture(commander: Int)
    /// A line of up to three commanders sent at a stage of the Spine: the
    /// next, or one won before, to win it with more stars.
    case ventureLine(commanders: [Int], stage: Int?)
    /// A false reflection cast from a hold on a stretch of shore, mirrored
    /// at the next Still Hour as a company of a kind that is not there.
    case castReflection(hold: Int, at: Hex, kind: UnitKind)
    /// An alliance's leader sets it to pursue a study together.
    case pursueAllianceStudy(AllianceStudy)
    /// A House gives stores toward its alliance's study.
    case giveToAlliance(Stock)
    /// An alliance's leader begins its hall on the alliance's own land.
    case raiseAllianceHall(at: Hex)
    /// A House's smiths forge a piece of gear of the Forge's sets, as fine
    /// as its Forge allows, for makings and moonsalt.
    case forge(GearKind, quality: GearQuality)
    /// An alliance's leader begins its storehouse on the alliance's own land.
    case raiseStorehouse(at: Hex)
    /// A House lays up stores in its alliance's storehouse.
    case layUp(Stock)
    /// A House takes back stores it laid up in its alliance's storehouse.
    case takeBack(Stock)
    /// An alliance's leader raises a yard of a store on the alliance's own land.
    case raiseYard(Resource, at: Hex)
    /// A keeper crosses to the Frontier for the season open there, with a
    /// levy of their House's companies of war: a realm's order, not the
    /// lake's (see `RealmState.cross`).
    case crossToFrontier
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
    /// The war is the Sundering's, laid down as it ends, not before.
    case sunderingWar
    case nothingToAttack
    case outOfReach
    case cannotFight
    case notAFounder
    case cannotSettle(Terrain)
    /// Nothing an alliance raises (a standard, its hall, storehouse or
    /// yards) stands on water or the Spine.
    case unfitGround(Terrain)
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
    case needsLeaderFirst
    case alreadyPaired
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
    /// A site another House's company is working: one gatherer at a time.
    case siteTaken
    /// It is neither gathering nor carrying anything home.
    case notGathering
    case noneGathering
    case notSingable
    case notABallad
    case sungAlready
    case sangThisWatch
    case noWaterBeside
    case castThisWatch
    case noneUnmourned
    case noSuchVigil
    case ownVigil
    case honouredAlready
    /// A strike on a House whose vigil the striker honoured, while it burns.
    case mourning(until: Int)
    case letterSealed
    case notACompanyOfWar
    case noStandingOrders
    case notYourPrisoner
    case questionedThisWatch
    case notAPrisoner
    case commanderCaptive
    /// Sworn to peace with a House, by an oath in force.
    case swornToPeace(Int)
    case oathsHeld
    case notYourOath
    /// A line the House never heard, or one taken away.
    case unknownWord
    /// A House's own line, reported.
    case ownWord
    case reportedAlready
    /// A keeper has reported as many lines as the realm hears from one in a watch.
    case reportedEnough
    /// Barred from the Words by the realm's steward, until a watch.
    case barredFromWords(until: Int)
    /// A House of one hold, putting an edict to the realm.
    case tooFewHolds
    /// An edict before the realm already.
    case edictInVote
    /// That edict holds the realm already.
    case edictInForce
    /// A House that put an edict to the realm within its last twenty watches.
    case proposedLately
    case unknownEdict
    case voteClosed
    case votedAlready
    /// A House sworn to an alliance already.
    case inAnAlliance
    /// A House sworn to no alliance.
    case notInAlliance
    /// What only an alliance's leader may do.
    case notAllianceLeader
    /// What only an alliance's leader or one of its officers may do.
    case notAllianceOfficer
    /// A House named an officer already, or not one to unname.
    case alreadyAnOfficer
    case notAnOfficer
    /// An alliance with all the officers it may have.
    case officersFull
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
    /// A talent opened only by points spent in its tree.
    case needsTreePoints(TalentTree, Int)
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
    /// Scouting by a company that isn't Lanterns.
    case notAScout
    /// Scouting a hold of the House's own.
    case ownHold
    /// A lair struck by a company alone.
    case lairNeedsRally
    /// A lair the House hasn't found, or no more.
    case unknownLair
    case lairAboveRung(Int)
    /// Ground the House hasn't seen.
    case unexplored
    /// A standard raised where something stands already.
    case standardGround
    /// A standard raised too far from the alliance's holds and standards.
    case standardTooFar
    /// An alliance with as many standards as it may keep.
    case standardsEnough
    /// No standard stands so.
    case noSuchStandard
    /// A standard stands whole already.
    case standardWhole
    /// A House that raised a standard, or lent a hand already.
    case standardHelped
    /// An item the House has none of.
    case noItem
    /// A tome used as any other item, not read by a commander.
    case readByACommander
    /// An hourglass used where nothing is under way that has a watch to lose.
    case nothingToHasten
    /// A ward stone used on a hold whose ward is whole.
    case wardWhole
    /// A mending draught used when no company of the House is hurt.
    case noneHurt
    /// A company drilled anywhere but at or beside one of its House's holds
    /// with a Muster Hall, or one that isn't a company of war.
    case drillsAtMusterHall
    /// A company that musters as many as it can lead.
    case drilledWhole
    /// A company raised a tier anywhere but at or beside one of its House's
    /// holds with a Muster Hall.
    case raisedAtMusterHall
    /// A company of its kind's highest tier already.
    case atHighestTier
    /// A company raised a tier while it marches or is about an errand.
    case raisedStandingStill
    /// A company raised a tier while it fights in a field of battle.
    case raisedOutOfBattle
    /// A heritage taken up by a House already of it.
    case alreadyOfHeritage
    /// A crest whose charge is of its field's tincture.
    case crestUnreadable
    /// A crest taken by a House that took its own this age.
    case crestChosenAlready
    /// A title named by a House that isn't a keeper's holding the broken Spire.
    case notTheSpiresHolder
    /// A title named anew before it has rested since it was last named.
    case titleResting(until: Int)
    /// A prophecy spoken by a House with one of its own still open.
    case prophecyOpen
    /// A prophecy of what has come to pass already.
    case comeToPassAlready
    /// A stake on a prophecy that isn't open.
    case unknownProphecy
    /// A second stake on a prophecy by the same House.
    case stakedAlready
    /// A stake laid after the watch stakes on it closed.
    case stakesClosed(Int)
    /// A hold struck, rallied on or scouted while its House's veil lies.
    case veiled(until: Int)
    /// A veil drawn by a House whose veil already lies.
    case veiledAlready(until: Int)
    /// A veil drawn before the last has rested.
    case veilResting(until: Int)
    /// A seat raised anew before it has rested since it was last.
    case seatRaisedLately(until: Int)
    /// A company already out on the water.
    case alreadyOnTheWater
    /// A company that has struck, moved or worked this watch.
    case alreadyActed
    /// A company that stands at none of its House's holds.
    case notAtAShoreHold
    /// Ground another House's company stands on.
    case occupiedGround
    /// A seat beset: its ward short of whole, or a foe at war near it.
    case seatBeset
    /// A seat raised anew beyond the House's own land and its alliance's.
    case seatBeyondLand
    /// Shares taken where none waits.
    case noSharesWaiting
    /// A challenge in the Ring by a House with no line standing in it.
    case noLineStanding
    /// A challenge in the Ring past a House's three of the watch.
    case challengesSpent
    /// A whisper let loose before the House's last has rested.
    case whisperedLately(until: Int)
    /// A riddle answered a second time.
    case answeredAlready
    case notOnTheShore
    case alreadyRippled
    case stoneAlreadySunk
    case starsFull
    case noPedlar
    case expeditionsDone
    case lineTooLong(Int)
    case noInnKey(InnChest)
    case notOnTheStill
    case mirrorWalkedThisMoon
    /// The Lyceum does not sit this watch.
    case lyceumNotSitting
    /// No such question or answer.
    case lyceumNoSuchAnswer
    /// The House has answered that question.
    case lyceumAnswered
    case noFarShore
    case reflectionThere
    case tooManyReflections(Int)
    case venturedThisWatch
    case wareSold
    case needsSculptures(Int)
    case tooManyStones(Int)
    /// An alliance study learned to its last grade.
    case allianceStudyMastered
    /// The study the alliance pursues already.
    case alreadyPursued
    /// Stores given when the alliance pursues no study.
    case noAllianceStudy
    /// A gift to the alliance of nothing, or of less than nothing.
    case nothingGiven
    /// A hall begun by an alliance that has one standing or rising.
    case hallStanding
    /// A hall begun where something stands already.
    case hallGround
    /// A hall begun off the alliance's own land.
    case notAllianceLand
    /// A hold founded on a standard's or a hall's ground.
    case allianceGround
    /// Gear the Forge doesn't make: what the wilds leave.
    case notForged
    /// Gear finer than the House's Forge makes.
    case needsForge(Int)
    /// Gear forged into a full armoury.
    case armouryFull
    /// Gear forged without the makings it takes.
    case shortOfMakings(Making, Int)
    /// A storehouse begun by an alliance that has one standing or rising.
    case storehouseStanding
    /// Stores laid up or taken back where the alliance has no storehouse
    /// standing whole.
    case noStorehouse
    /// Stores laid up beyond a House's room in the storehouse.
    case storehouseFull
    /// Stores taken back that were never laid up.
    case notLaidUp
    /// A yard raised by an alliance that has one of that store.
    case yardStanding(Resource)
    /// A yard worked by a company of another alliance, or of none.
    case foreignYard
    /// An alliance's work raised where something stands already.
    case openGroundOnly
    /// Words from a House no keeper holds.
    case notAKeeper
    /// Fire set in anything but the blackwood, or in a hold's heart or a
    /// site's clearing there.
    case onlyBlackwood
    /// Fire set where the wood is burning or lies burnt already.
    case burntGround
    /// Fire set by a company no keeper commands.
    case keepersFire
    /// Torches lit that burn already, or doused that are out.
    case torchesAlready(lit: Bool)
    /// Lying in wait asked of a company already waiting, or given up by
    /// one that isn't.
    case waitingAlready(Bool)
    /// Only a company marching dark lies in wait.
    case notMarchingDark
    /// Only in the blackwood, not burnt, does a company lie in wait.
    case notInTheWood
    /// A company on the march can't lie in wait.
    case onTheMarch
    /// A hamlet or barrow the House knows of no such, or one a hold now
    /// stands over.
    case unknownFind
    /// A hamlet or barrow the House's Lanterns sought already.
    case soughtAlready
    case watchfireBurning
    case watchfiresLit(Int)
    /// No dead lie unburied where the company stands.
    case noDeadHere
    /// A company that has struck or worked this watch.
    case spentThisWatch
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
        case .impassable(let terrain): return terrain.ground.lineBegun + (terrain == .stream ? " can't be crossed but at its shoals." : " can't be crossed.")
        case .noPath: return "There's no way there."
        case .notAtWar: return "You're not at war with them."
        case .sunderingWar: return "This war is the Sundering's: it is laid down as the Sundering ends, not before."
        case .nothingToAttack: return "There's nothing there to strike."
        case .outOfReach: return "That's out of reach."
        case .cannotFight: return "These aren't fighters."
        case .notAFounder: return "Only Founders can found a hold."
        case .cannotSettle(let terrain): return "A hold can't stand \(terrain.place)."
        case .unfitGround(let terrain): return "Nothing can be raised \(terrain.place)."
        case .tooCloseToHold: return "Too close to another hold; it needs three tiles of room."
        case .foreignTerritory: return "That land belongs to another House."
        case .busy: return "That hold is already busy."
        case .maxLevel: return "It's already at its highest level."
        case .seatOnly: return "Only a House's seat can raise it."
        case .needsMusterHall(let level): return "Needs a Muster Hall \(BuildingKind.numeral(level))."
        case .shortOf(let missing): return "Short of \(missing.listedSaid)."
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
        case .needsLeaderFirst: return "A second commander rides only with a company that has a leader."
        case .alreadyPaired: return "That company already has a second commander."
        case .cannotLead(let kind): return "\(kind.title) take no commander."
        case .awayFromHolds: return "A commander takes up a company at or beside one of your holds."
        case .notLeading: return "That commander leads no company."
        case .unknownSite: return "Your House knows of no such site."
        case .cannotGather(let kind): return "\(kind.title) gather nothing."
        case .loadFull: return "It carries all it can; bring it home first."
        case .siteTaken: return "Another House's company is working this site."
        case .notGathering: return "It isn't gathering, and carries nothing home."
        case .noneGathering: return "None of your companies is out gathering."
        case .notSingable: return "That is no deed of your House's to sing of."
        case .notABallad: return "A ballad is two to six short lines of plain words."
        case .sungAlready: return "Your House has sung of that already."
        case .sangThisWatch: return "Your House has sung this watch; sing again at the next."
        case .noWaterBeside: return "No water lies beside this hold to set anything on."
        case .noneUnmourned: return "Your House has lost no company of war in battle since its last vigil."
        case .noSuchVigil: return "That vigil's light has gone out."
        case .ownVigil: return "A House keeps its own vigil; others honour it."
        case .honouredAlready: return "Your House has honoured that vigil already."
        case .mourning(let until):
            return "Your House honoured a vigil of that House's for its fallen: it may not strike them, nor rally on their holds, "
                + "while its light burns, until watch \(until)."
        case .castThisWatch: return "Your House has set a bottle on the water this watch; another at the next."
        case .letterSealed: return "Your House has sealed its letter to the age to come; one an age."
        case .notACompanyOfWar: return "Only a company of war is mustered by a standing order."
        case .noStandingOrders: return "Your House has given no standing orders."
        case .notYourPrisoner: return "Your House holds no such prisoner."
        case .questionedThisWatch: return "You have questioned that prisoner this watch; again at the next."
        case .notAPrisoner: return "That commander of yours is no one's prisoner."
        case .commanderCaptive: return "That commander is held prisoner."
        case .swornToPeace: return "Your House is sworn to peace with that House; renounce the oath first, and wait out its notice."
        case .oathsHeld: return "Your House holds itself to six oaths already."
        case .notYourOath: return "That oath is not your House's to renounce."
        case .unknownWord: return "No such line is in the Words."
        case .ownWord: return "That line is your own."
        case .reportedAlready: return "You have reported that line already."
        case .reportedEnough: return "You have reported as many lines as the realm hears from one keeper in a watch."
        case .barredFromWords(let until): return "The realm's steward has barred your House from the Words until the \(ordinal(until)) watch."
        case .tooFewHolds: return "Only a House of two holds or more may put an edict to the realm."
        case .edictInVote: return "An edict is before the realm already; another when its vote is done."
        case .edictInForce: return "That edict holds the realm already."
        case .proposedLately: return "Your House has put an edict to the realm within the last twenty watches."
        case .unknownEdict: return "No such edict is before the realm."
        case .voteClosed: return "The vote on that edict is over."
        case .votedAlready: return "Your House has voted on that edict."
        case .inAnAlliance: return "That House is sworn to an alliance already."
        case .notInAlliance: return "Your House is sworn to no alliance."
        case .notAllianceLeader: return "Only the alliance's leader can do that."
        case .notAllianceOfficer: return "Only the alliance's leader or one of its officers can do that."
        case .alreadyAnOfficer: return "That House is already an officer."
        case .notAnOfficer: return "That House isn't an officer."
        case .officersFull: return "The alliance has all the officers it may: \(Alliance.mostOfficers)."
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
        case .needsTreePoints(let tree, let points): return "Needs \(points) points spent in \(tree.title) first."
        case .nothingToForget: return "That commander has learned no talents."
        case .unknownGear: return "Your House holds no such gear."
        case .alreadyWorn: return "That commander wears it already."
        case .notWorn: return "No commander wears it."
        case .holySite: return "No hold is raised on a holy site."
        case .noneWounded: return "No company lies in that hold's Infirmary waiting to be healed."
        case .notAScout: return "Only Lanterns scout."
        case .ownHold: return "That hold is your own."
        case .lairNeedsRally: return "Only a rally's host can break a lair: call one against it."
        case .unknownLair: return "No such lair is known to your House."
        case .unexplored: return "Your House hasn't seen that ground."
        case .standardGround: return "A standard stands only on open land, with nothing on it."
        case .standardTooFar: return "A standard stands within four tiles of your alliance's holds, standards or hall."
        case .standardsEnough: return "Your alliance keeps as many standards as it may: one, and one more for each of its Houses, eight at most."
        case .noSuchStandard: return "No standard stands there."
        case .standardWhole: return "That standard stands whole already."
        case .standardHelped: return "Your House has given that standard its hand already."
        case .noItem: return "Your House has none of that."
        case .nothingToHasten: return "Nothing under way there has a watch to spare: what has one left is done as the watch turns."
        case .wardWhole: return "That hold's ward is whole."
        case .noneHurt: return "None of your companies is hurt."
        case .readByACommander: return "A tome is read by one of your commanders: give it to one from their line."
        case .drillsAtMusterHall: return "A company of war drills at or beside one of your holds with a Muster Hall."
        case .drilledWhole: return "That company musters as many as it can lead: raise your Muster Hall, or give it a commander, to drill it further."
        case .raisedAtMusterHall: return "A company of war is raised a tier at or beside one of your holds with a Muster Hall."
        case .atHighestTier: return "That company is of its kind's highest tier already."
        case .raisedStandingStill: return "A company is raised a tier standing still: not on the march, at the land's work, at a rally or keeping a hold's gates."
        case .raisedOutOfBattle: return "A company is raised a tier out of the fighting, not in a field of battle."
        case .alreadyOfHeritage: return "Your House is of that heritage already."
        case .crestUnreadable: return "A charge must be of another tincture than its field, to be seen."
        case .crestChosenAlready: return "Your House took its crest this age; it bears it until the age ends."
        case .notTheSpiresHolder: return "Only the keeper whose House holds the broken Spire names the realm's titles."
        case .titleResting(let until): return "That title was named lately; it may be named anew at watch \(until)."
        case .prophecyOpen: return "Your House's prophecy is still open; it may foretell again once the realm has judged it."
        case .comeToPassAlready: return "That has come to pass already."
        case .unknownProphecy: return "No such prophecy is open."
        case .stakedAlready: return "Your House has laid its stake on that prophecy."
        case .stakesClosed(let watch): return "Stakes on that prophecy closed at watch \(watch)."
        case .veiled(let until): return "The veil of the Still lies over that House's holds until watch \(until): none may strike, rally on or scout them."
        case .veiledAlready(let until): return "Your House's veil lies until watch \(until)."
        case .veilResting(let until): return "The mist gathers again: your House may draw its veil anew at watch \(until)."
        case .alreadyOnTheWater: return "That company is already out on the water."
        case .alreadyActed: return "That company has done what it can this watch; it may board at the next."
        case .notAtAShoreHold: return "A barge takes on a company only at a hold of your House by the water."
        case .seatRaisedLately(let until): return "Your seat was raised anew lately; it may be again at watch \(until)."
        case .occupiedGround: return "Another House's company stands there."
        case .seatBeset: return "Your seat is beset: not while its ward is short of whole, or a foe at war stands within three tiles of it."
        case .noSharesWaiting: return "No share of your alliance's spoils waits for your House."
        case .seatBeyondLand:
            return "Your seat is raised anew only on your own land, or on your alliance's land that no House holds and your House has seen."
        case .noLineStanding: return "Your House stands no line in the Ring: choose up to three of your commanders for it first."
        case .challengesSpent: return "Your House has made its three challenges in the Ring this watch; it may challenge again next watch."
        case .whisperedLately(let until): return "Your House let a whisper loose lately; it may whisper again at watch \(until)."
        case .answeredAlready: return "Your House has answered this riddle; the lake sets another at the next half moon."
        case .notOnTheShore: return "A ripple-stone is cast only from a hold on the lake's shore."
        case .alreadyRippled: return "Your stone already stirs the water against the next Still Hour."
        case .starsFull: return "That commander has all its stars."
        case .lairAboveRung(let most): return "Your hosts must break a lair of each level first: they may march on one of level \(BuildingKind.numeral(most)) at most."
        case .reflectionThere: return "Your false reflection already waits on that shore."
        case .tooManyReflections(let most): return "The lake takes \(most) false reflections of a House to a Still Hour, and no more."
        case .lineTooLong(let most): return "A line up the Spine is one to \(most) commanders, each once."
        case .noInnKey(let chest): return "Your House holds no \(chest.named) key; one comes \(chest == .silver ? "each watch" : "every \(InnKeys.goldEvery) watches")."
        case .notOnTheStill: return "A company walks the mirror from the Still's shore, beside its water."
        case .mirrorWalkedThisMoon: return "That company has walked the mirror this moon."
        case .lyceumNotSitting: return "The Lyceum does not sit this watch."
        case .lyceumNoSuchAnswer: return "The Lyceum set no such question or answer."
        case .lyceumAnswered: return "You have answered that question."
        case .noFarShore: return "The Still shows no open ground on the far shore to come out on."
        case .expeditionsDone: return "Your House has taken every stage of the Spine."
        case .venturedThisWatch: return "Your House has sent an expedition this watch already."
        case .noPedlar: return "No pedlar lies off your holds with that ware."
        case .wareSold: return "The pedlar has sold that already."
        case .needsSculptures(let count): return "Its next star takes \(count) sculptures."
        case .stoneAlreadySunk: return "A listening stone already lies in the water before that hold."
        case .tooManyStones(let most): return "Your House keeps \(most) listening stones in the lake, and no more."
        case .allianceStudyMastered: return "Your alliance has learned that study to its last grade."
        case .alreadyPursued: return "Your alliance pursues that study already."
        case .noAllianceStudy: return "Your alliance pursues no study: its leader chooses one in the Alliance screen."
        case .nothingGiven: return "Give some of your stores, and none of them less than nothing."
        case .hallStanding: return "Your alliance has its hall already: it raises one, and another only once that one falls."
        case .hallGround: return "A hall stands only on open land, with nothing on it."
        case .notAllianceLand: return "It stands only on your alliance's own land, within reach of its standards."
        case .allianceGround: return "An alliance's work stands here: a hold is founded on open land."
        case .notForged: return "That gear is not forged: only the wilds leave it."
        case .needsForge(let level): return "Raise a Forge to level \(BuildingKind.numeral(level)) to forge gear so fine."
        case .armouryFull: return "Your armoury is full: break up a piece to make room."
        case .shortOfMakings(let making, let count): return "You need \(count) more \(making.title.lowercased())."
        case .storehouseStanding: return "Your alliance has its storehouse already: it raises one, and another only once that one falls."
        case .noStorehouse: return "Your alliance has no storehouse standing whole: its leader raises one on its land."
        case .storehouseFull: return "Your room in the storehouse holds no more: \(Storehouse.room.listedSaid) at most."
        case .notLaidUp: return "You haven't laid up so much in the storehouse."
        case .yardStanding(let store): return "Your alliance has its \(Yard.title(of: store).lowercased()) already."
        case .foreignYard: return "Only the companies of the alliance that raised a yard work it."
        case .openGroundOnly: return "It stands only on open land, with nothing on it."
        case .notAnAllysHold: return "Only an ally's hold can be kept."
        case .notAKeeper: return "Only a keeper's words are carried."
        case .onlyBlackwood: return "Only the blackwood burns, and never a hold's heart or a site's clearing in it."
        case .burntGround: return "That wood is burning or lies burnt already."
        case .keepersFire: return "Only a keeper's companies set the wood alight."
        case .torchesAlready(let lit): return lit ? "Its torches burn already." : "It marches dark already."
        case .waitingAlready(let waiting): return waiting ? "It lies in wait already." : "It isn't lying in wait."
        case .notMarchingDark: return "Only a company marching dark may lie in wait: douse its torches first."
        case .notInTheWood: return "It may lie in wait only in the blackwood, where the wood isn't burnt."
        case .onTheMarch: return "It is on the march: halt it first."
        case .unknownFind: return "Your House knows of no such hamlet or barrow."
        case .soughtAlready: return "Your Lanterns have been there already."
        case .watchfireBurning: return "A watchfire burns there already."
        case .noDeadHere: return "No dead lie unburied where that company stands."
        case .spentThisWatch: return "That company has struck or worked this watch; it may bury the dead at the next."
        case .watchfiresLit(let most): return "Your House keeps \(most) watchfires burning already, as many as it may."
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
    /// So many troops drilled into a company as the watch turned; whole
    /// when it musters as many as it can lead.
    case drilled(unit: Int, owner: Int, troops: Int, whole: Bool)
    /// A company raised a tier by its House's Muster Hall.
    case tierRaised(unit: Int, owner: Int, tier: Int)
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
    /// A House's Lanterns scout a hold: what they saw, for that House.
    case holdScouted(ScoutReport)
    /// A hold's House sees another's Lanterns watching it.
    case scoutSeen(hold: Int, by: Int)
    /// A rally's host strikes a lair of the wilds.
    case lairAssaulted(LairAssault)
    /// A House raises a standard of its alliance.
    case standardRaised(standard: Int, alliance: Int, house: Int, at: Hex)
    /// A company strikes a standard's ward.
    case standardStruck(standard: Int, ward: Int, by: Int, at: Hex)
    /// A House lent a hand to its alliance's rising standard.
    case standardHelped(standard: Int, by: Int, at: Hex)
    /// A standard stands whole, its land its alliance's.
    case standardRisen(standard: Int, alliance: Int, at: Hex)
    /// A standard comes down: torn down by a House, or by none, its House
    /// gone from its alliance.
    case standardTorn(standard: Int, alliance: Int, by: Int?, at: Hex)
    /// A House is given items for its satchel.
    case itemsGiven(house: Int, kind: ItemKind, count: Int)
    /// A House uses an item, on one of its holds or on the House.
    case itemUsed(house: Int, kind: ItemKind, hold: Int?)
    /// A commander of a House read one of its tomes.
    case tomeRead(commander: Int, house: Int)
    /// A House takes up a heritage.
    case heritageTaken(house: Int, heritage: Heritage)
    /// A House takes its crest.
    case crestTaken(house: Int, crest: Crest)
    /// A keeper sets a work of a hold in a place of its own.
    case workPlaced(hold: Int, kind: BuildingKind, place: Int)
    /// A keeper's House dreams at the dark of the moon.
    case dreamt(Dream)
    /// The broken Spire's keeper names a House to a title.
    case titleBestowed(title: Title, house: Int, by: Int)
    /// The titles a House named lapse, the Spire no longer its.
    case titlesLapsed(by: Int, titles: [Bestowal])
    /// A keeper foretells.
    case prophesied(Prophecy)
    /// A keeper lays a stake on a prophecy.
    case staked(prophecy: Int, house: Int, backs: Bool, moonsalt: Int)
    /// The realm judges a prophecy: whether it came to pass, and what each
    /// House that saw true took.
    case prophecyJudged(prophecy: Int, cameToPass: Bool, paid: [Prophecy.Stake])
    /// A keeper draws the veil over their House's holds, until a watch.
    case veilDrawn(house: Int, until: Int)
    /// A House's veil lifts: its House struck another, or its watches are out.
    case veilLifted(house: Int, struck: Bool)
    /// A keeper raises their House's seat anew elsewhere on its land.
    case seatRaisedAnew(hold: Int, house: Int, from: Hex, to: Hex)
    /// A company set on the water at one shore hold for another.
    case setOnTheWater(unit: Int, house: Int, from: Int, to: Int)
    /// A barge comes in as the watch turns: landed at the hold it made for,
    /// or turned back, its landing held.
    case ferried(unit: Int, house: Int, to: Int, landed: Bool)
    /// A keeper stands a line of their commanders in the Ring.
    case ringLineStood(house: Int, line: [Int])
    /// A bout in the Ring: one House's line challenges another's.
    case bout(Ring.Bout)
    /// At the moon's turn the Ring honours the three standing highest,
    /// the highest first.
    case ringHonoured(houses: [Int])
    /// A whisper is let loose, unsigned: told to the realm.
    case whispered(id: Int, claim: Whisper.Claim)
    /// The House that let a whisper loose: told to it alone.
    case whisperLet(id: Int, by: Int)
    /// A keeper's Lanterns try a whisper, and learn its truth.
    case whisperTried(id: Int, house: Int, truth: Bool)
    /// A whisper is found false: its teller named, and what it paid the
    /// House it belied.
    case whisperUnmasked(id: Int, teller: Int, belied: Int, paid: Int)
    /// At the half moon the lake sets a keeper's House a riddle.
    case riddleSet(house: Int)
    /// The lake lay still and showed so many companies on its shore, of
    /// these Houses.
    case stillHour(glimpses: Int, houses: [Int])
    /// A House sinks a listening stone before one of its holds.
    case stoneSunk(stone: Int, house: Int, hold: Int)
    /// Sculptures come to a House.
    case sculpturesFound(house: Int, count: Int)
    /// A letter written from one keeper to another.
    case letterSent(Missive)
    /// The pedlar comes to lie off a House's hold.
    case pedlarCame(house: Int, hold: Int)
    /// The pedlar sells a House a ware.
    case pedlarSold(house: Int, ware: Int)
    /// The pedlar poles away.
    case pedlarLeft(house: Int)
    /// A House's commander at a stage of the Spine, and how it went.
    case expedition(ExpeditionResult)
    /// A House has done one of its watch's labours.
    case labourDone(house: Int, kind: LabourKind)
    /// The lake's Houses together set a stone of the Monument.
    case monumentStoneSet(stone: MonumentStone)
    /// A House casts a false reflection on the shore.
    case reflectionCast(house: Int, at: Hex)
    /// A House climbs the ladder of the lairs to a level.
    case lairRungClimbed(house: Int, level: Int)
    /// A House's vigour opens one of the moon's chests, first to third.
    case chestOpened(house: Int, chest: Int)
    /// A House opens a chest at the Lantern Inn, and what it held.
    case innChestOpened(house: Int, chest: InnChest, drew: InnDraw)
    /// A company steps into the Still; the water stills where it will come out.
    case mirrorWalkBegun(unit: Int, house: Int, from: Hex, to: Hex)
    /// It comes out on the far shore as the watch turns (where it stood, if
    /// the far shore filled).
    case mirrorWalked(unit: Int, house: Int, from: Hex, to: Hex)
    /// The Still's calm broken by these Houses' companies at the water.
    case calmBroken(houses: [Int], calm: Int)
    /// A House answered a question of the Lyceum, its answer its own.
    case lyceumAnswered(house: Int, question: Int)
    /// The Lyceum rose and judged: how each House that answered stood.
    case lyceumJudged(standings: [LyceumStanding])
    /// A commander rises a star.
    case commanderStarred(commander: Int, house: Int, stars: Int)
    /// A House's stone heard so many marches out of its sight.
    case stoneHeard(stone: Int, house: Int, marches: Int)
    /// A stone lost with the hold it was sunk before.
    case stoneLost(stone: Int, house: Int)
    /// A House cast a ripple-stone from a hold.
    case rippleCast(house: Int, hold: Int)
    /// A keeper's House answers its riddle, rightly or not, and the name
    /// that was taken out.
    case riddleAnswered(house: Int, right: Bool, answer: String)
    /// The moon is eaten: so many of the Drowned rise from the drowned age's holds.
    case eclipse(risen: Int)
    /// The moon comes back, and so many of the Drowned still walking sink again.
    case eclipseEnded(sank: Int)
    /// An alliance's leader sets it to pursue a study.
    case allianceStudyChosen(alliance: Int, study: AllianceStudy)
    /// A House gives stores toward a grade of its alliance's study.
    case allianceGift(house: Int, alliance: Int, stock: Stock, study: AllianceStudy, grade: Int)
    /// An alliance learns a grade of a study together.
    case allianceStudied(alliance: Int, study: AllianceStudy, grade: Int)
    /// An alliance's leader begins its hall.
    case hallRaised(hall: Int, alliance: Int, house: Int, at: Hex)
    /// An alliance's hall has risen whole.
    case hallRisen(hall: Int, alliance: Int, at: Hex)
    /// A company strikes an alliance's hall.
    case hallStruck(hall: Int, alliance: Int, ward: Int, by: Int, at: Hex)
    /// An alliance's hall comes down: torn down by a House, or by none,
    /// its alliance no more.
    case hallTorn(hall: Int, alliance: Int, by: Int?, at: Hex)
    /// An alliance's leader begins its storehouse.
    case storehouseRaised(storehouse: Int, alliance: Int, house: Int, at: Hex)
    /// An alliance's storehouse has risen whole.
    case storehouseRisen(storehouse: Int, alliance: Int, at: Hex)
    /// A company strikes an alliance's storehouse.
    case storehouseStruck(storehouse: Int, alliance: Int, ward: Int, by: Int, at: Hex)
    /// An alliance's storehouse comes down: torn down by a House, which
    /// carries off what was laid up in it, or by none, its alliance no more.
    case storehouseTorn(storehouse: Int, alliance: Int, by: Int?, at: Hex, carried: Stock)
    /// A House lays up stores in its alliance's storehouse.
    case laidUp(house: Int, stock: Stock)
    /// A House takes back stores it laid up.
    case tookBack(house: Int, stock: Stock)
    /// An alliance's leader raises a yard on its land.
    case yardRaised(site: Int, alliance: Int, house: Int, store: Resource, at: Hex)
    /// A House's favour, its keeper's, rises a level.
    case favourRose(house: Int, level: Int)
    /// The lake's shores stand as kingdoms until a watch.
    case sunderingBegun(ends: Int)
    /// The moon is full: the Moonford lies open across the lake until a watch.
    case fordOpened(closes: Int)
    /// A company is called home from the land's work.
    case recalled(unit: Int, owner: Int)
    /// A march ends short of where it was bound, its way shut: where the
    /// company halted, and where it was going.
    case marchHalted(unit: Int, owner: Int, kind: UnitKind, at: Hex, toward: Hex)
    /// The moon wanes and the water comes back over the Moonford, carrying
    /// so many companies ashore.
    case fordClosed(carried: Int)
    /// The Drowned Crown lies at the ford's heart.
    case crownSurfaced(at: Hex)
    /// A company takes up the crown.
    case crownTaken(unit: Int, house: Int)
    /// Its bearer struck down, the crown lies where it fell.
    case crownFell(at: Hex)
    /// The crown sinks with the ford, given to the side that bore it longest.
    case crownSank(side: Int?, houses: [Int])
    /// The tide carries a company from the Moonford to the nearest shore.
    case carriedAshore(unit: Int, owner: Int, from: Hex, to: Hex)
    /// A Sundering ends: the kingdom that prevailed, if one did, each
    /// kingdom's points, and the House hailed its sword.
    case sunderingEnded(winner: Shore?, eastern: Int, western: Int, hailed: Int?)
    /// Battle is joined where a company of one House strikes another's: a
    /// field of battle, which goes on through the watch.
    case fieldJoined(field: Int, at: Hex, first: Int, second: Int)
    /// A field of battle is over: every company that fought in it, what it
    /// slew and lost, and which side holds the field.
    case fieldEnded(Field)
    /// What happens to a keeper's House about the Frontier: crossing to it,
    /// raised there, a season's end told home.
    case frontier(FrontierTiding)
    /// A House is given makings for its Forge.
    case makingsFound(house: Int, making: Making, count: Int)
    /// A House's smiths forge a piece of gear.
    case gearForged(house: Int, gear: Gear)
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
    /// An alliance's leader names a House of it an officer, or names it one
    /// no longer.
    case officerNamed(alliance: Int, house: Int, named: Bool)
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
    /// A ballad sung to the realm, kept in its songbook.
    case sung(Ballad)
    /// A bottle set on the water.
    case bottleCast(bottle: Int, from: Int, at: Hex)
    /// A bottle washed up and found, with the words in it.
    case bottleFound(bottle: Bottle, by: Int)
    /// A vigil's light set on the water for a House's fallen.
    case vigilKept(Vigil)
    /// A vigil honoured by another House.
    case vigilHonoured(vigil: Int, house: Int, by: Int)
    /// A vigil's light gone out, and how many Houses honoured it.
    case vigilOut(vigil: Int, house: Int, honours: Int)
    /// The folk of a keeper's hold came to its gate with a plea.
    case petitionBrought(Petition)
    /// A plea answered: granted, or turned away by the keeper or by silence.
    case petitionAnswered(Petition, granted: Bool, silently: Bool)
    /// A plea whose need passed before it was answered, withdrawn.
    case petitionWithdrawn(Petition)
    /// Ground marked for an alliance by its leader.
    case groundMarked(AllianceMark)
    /// An alliance's mark lifted by its leader, given way to another, or
    /// lapsed.
    case markLifted(AllianceMark, lapsed: Bool)
    /// A steward sworn to the alliance answering its keeper leader's mark,
    /// told once: its host making for the hold marked to strike, or its
    /// companies for ground marked to gather at or to hold.
    case markHeeded(AllianceMark, by: Int)
    /// A keeper's company set the blackwood alight where it stood.
    case woodKindled(at: Hex, by: Int, unit: Int)
    /// A company doused its torches to march dark, or lit them again.
    case torchesSet(unit: Int, lit: Bool, owner: Int)
    /// A company lay in wait in the blackwood, or gave it up.
    case waitSet(unit: Int, waiting: Bool, owner: Int)
    /// A company lying in wait sprang from the dark of the wood at `at`
    /// upon a company of a House at war with its own.
    case ambushSprung(unit: Int, owner: Int, at: Hex, struck: Int, struckOwner: Int)
    /// A House lit a watchfire on its own land.
    case watchfireLit(at: Hex, by: Int)
    /// A House's company buried the dead lying unburied on a field.
    case buried(FieldOfDead, by: Int)
    /// At the dark of the moon the dead left unburied on a field rose as
    /// a company of Barrowkin, at `at`.
    case unquietRose(FieldOfDead, wild: Int, at: Hex, level: Int)
    /// A House's watchfire at `fire` made out a company of another House
    /// marching dark within its reach.
    case madeOutByWatchfire(Watchfire.Sighting, fire: Hex, by: Int)
    /// A House's Lanterns sought out a hamlet or barrow: what its folk
    /// gave, or what was brought up out of it.
    case findSought(find: Int, by: Int, gift: Stock, item: ItemKind?)
    /// A House's fire caught the blackwood beside it, with the watch's wind
    /// (an index into `Hex.directions`, the way it blows).
    case fireSpread(to: [Hex], by: Int, wind: Int)
    /// A company stood in fire as the watch turned: so many of its troops
    /// lost to it, and whether it was lost whole.
    case burnedInFire(unit: Int, owner: Int, at: Hex, troops: Int, lost: Bool)
    /// Rising Mist lay on every shore, or a Lean Watch's cold rain fell
    /// (`rain`), and put out the fires burning there.
    case firesDoused([Hex], rain: Bool)
    /// A letter sealed in a hold for the age to come.
    case letterSealed(hold: Int, by: Int)
    /// A letter of the age before found in a drowned hold, with its words.
    case letterFound(letter: Letter, by: Int)
    /// A keeper's standing orders given, changed or cleared.
    case standingOrdersGiven(house: Int)
    /// A fallen company's commander taken prisoner by a keeper's House.
    case commanderTaken(commander: Int, house: Int, by: Int)
    /// A prisoner questioned, and the true thing they told.
    case prisonerQuestioned(commander: Int, by: Int, word: String)
    /// A prisoner free again: ransomed, let go, or slipped away.
    case prisonerFreed(commander: Int, house: Int, by: Int, why: Freed)
    /// An oath sworn, renounced with notice, or come to its end.
    case oathSworn(Oath)
    case oathRenounced(Oath)
    case oathEnded(Oath, why: OathEnd)
    /// A line reported to the realm's steward.
    case wordReported(word: Int, by: Int)
    /// A line taken away by the realm's steward.
    case wordRemoved(word: Int)
    /// A House barred from the Words by the realm's steward, until a watch.
    case barredFromWords(house: Int, until: Int)
    /// An edict put to the realm, its vote open.
    case edictProposed(Edict)
    /// A House's vote on an edict before the realm.
    case edictVoted(edict: Int, house: Int, aye: Bool)
    /// An edict's vote closed: passed, holding the realm, or refused.
    case edictPassed(Edict)
    case edictFailed(Edict)
    /// An edict passed whose watches are done.
    case edictLapsed(Edict)
    /// A House broke an edict in force, striking another, and paid it the fine.
    case edictBroken(edict: Int, kind: EdictKind, by: Int, against: Int, fine: Stock)
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
    /// The defender's troops the blow felled; none when a ward was struck.
    public let slain: Int?
    /// The attacker's troops lost to the blow struck back.
    public let lost: Int?
    /// The field of battle it fell in, in a realm's watch.
    public internal(set) var field: Int?

    public init(
        attacker: Int, attackerOwner: Int, attackerKind: UnitKind,
        defender: Int?, defenderOwner: Int, defenderKind: UnitKind?,
        hold: Int?, at: Hex, damageDealt: Int, damageTaken: Int,
        attackerFell: Bool, defenderFell: Bool, slain: Int? = nil, lost: Int? = nil
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
        self.slain = slain
        self.lost = lost
    }
}
