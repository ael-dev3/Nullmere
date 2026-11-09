/// What a keeper may know of the world. The realm sends each keeper this,
/// never the whole world: their own House in full, the political map
/// (every House, every hold and its works, wars and pacts, the chronicle),
/// and of the rest only what their House can see or has explored.
extension GameState {
    /// The ground a keeper hasn't explored, as their copy of the world
    /// holds it: plain land, so a march into the unknown can be ordered
    /// and the realm finds the true way.
    public static let unknownGround = Tile(terrain: .greyfield)

    /// What a keeper's copy holds of a tile they haven't explored. The lake
    /// itself lies open to every shore, as the lie of the land does under a
    /// map's fog: its water is the water it is, and the land keeps its
    /// rise and fall, but what grows or stands on the land is unknown,
    /// and the ford and the shoals are for the explorer to find.
    public static func unknown(_ tile: Tile) -> Tile {
        [.still, .shallows, .stream].contains(tile.terrain) ? Tile(terrain: tile.terrain, relief: tile.relief) : Tile(terrain: .greyfield, relief: tile.relief)
    }

    /// What every keeper's view takes alike from the world as it stands,
    /// worked out once for all of them: the way of every company on the
    /// march, every House's strength and might as all are told them, the
    /// map as one who has explored none of it knows it, and the ground no
    /// House is known by another to have explored.
    public struct ViewCommons: Sendable {
        let ways: [Int: [Hex]]?
        let reputed: [Int]
        let reputedMight: [Int]
        let unexplored: WorldMap
        let unknown: Explored
    }

    /// `ways`, the way of every company on the march as `ways()` finds
    /// them, found once for many views; found as needed without.
    public func viewCommons(ways: [Int: [Hex]]? = nil) -> ViewCommons {
        ViewCommons(ways: ways, reputed: strengths(), reputedMight: houses.map { might(of: $0.id) },
                    unexplored: map.unexplored, unknown: Explored.unknown(count: map.count))
    }

    /// `ways`, the way of every company on the march as `ways()` finds
    /// them, found once for many views; found as needed without.
    public func view(for house: Int, ways: [Int: [Hex]]? = nil) -> GameState {
        view(for: house, commons: viewCommons(ways: ways))
    }

    /// A House's view of the world with what every view takes alike already
    /// worked out (`viewCommons`), of this world as it stands.
    public func view(for house: Int, commons: ViewCommons) -> GameState {
        let ways = commons.ways
        var view = self
        // The realm's words would grow the whole map again; where its
        // rounds begin is all the keeper's copy needs of them.
        view.dealing = dealt
        // A House's false reflections are its secret.
        view.reflections = reflections.map { all in all.filter { $0.house == house } }.flatMap { $0.isEmpty ? nil : $0 }
        // A House's labours are its own.
        view.labourBook = labourBook?[house].map { [house: $0] }
        // What its Beacons warn of: marches bound for its holds, seen or not.
        let warned = marchWarnings(for: house)
        view.warnings = warned.isEmpty ? nil : warned
        // And its keys at the Inn.
        view.innBook = innBook?[house].map { [house: $0] }
        // How far a House has gone up the Spine is its own to know.
        view.expeditions = expeditions?[house].map { [house: $0] }
        view.expeditionBest = expeditionBest?[house].map { [house: $0] }
        // A keeper's letters, and their pedlar, are their own.
        view.mail = mail.map { _ in letters(of: house) }.flatMap { $0.isEmpty ? nil : $0 }
        view.pedlars = pedlar(for: house).map { [$0] }
        // A House's sculptures are its own to count.
        view.sculptureCounts = sculptureCounts?[house].map { [house: $0] }
        // A House's listening stones, and what they hear, are its own.
        view.listeningStones = listeningStones.map { all in all.filter { $0.owner == house } }.flatMap { $0.isEmpty ? nil : $0 }
        let heard = soundings(heardBy: house)
        view.soundings = heard.isEmpty ? nil : heard
        view.listened = nil
        // A keeper's dreams are their own.
        view.dreams = dreams.map { all in all.filter { $0.house == house } }
        view.settings.seedText = ""
        let explored = houses.indices.contains(house) ? houses[house].explored : []
        view.map = map.known(by: explored, from: commons.unexplored)
        let seen = visibility(for: house)
        view.units = Companies(units.filter { unit in
            unit.owner == house || (map.index(of: unit.position).map { seen[$0] } ?? false)
        })
        // A company in sight shows where it stands and how many it is, not
        // where it is bound, nor what it is about or carries, nor whether it
        // drills.
        // The way a company keeps is the realm's: found on the whole map, it
        // would tell what bends it, so no view carries one, the keeper's own
        // companies' included.
        for index in view.units.indices {
            view.units[index].way = nil
        }
        for index in view.units.indices where view.units[index].owner != house {
            view.units[index].destination = nil
            // A keeper knows who keeps her own gates; no one else is told.
            if case .reinforce(let holdID)? = view.units[index].errand, hold(holdID)?.owner == house {
            } else {
                view.units[index].errand = nil
            }
            view.units[index].load = nil
            view.units[index].drillAt = nil
            view.units[index].gatherFor = nil
        }
        // Allies know what each other has under way, for they help it.
        let allies = Set(alliance(of: house)?.members ?? [])
        // Ground no other House is known to have explored: one, shared by
        // every view.
        for index in view.houses.indices where view.houses[index].id != house {
            view.houses[index] = view.houses[index].toldAlike(unknown: commons.unknown)
            if allies.contains(view.houses[index].id) {
                view.houses[index].research.pursuit = houses[index].research.pursuit
            }
        }
        // What a hold raises and trains its House's allies know too; who
        // lies in its beds, its own House alone.
        // Each asked where it lies, and written only if it has anything to
        // hide: most holds are told alike already.
        for index in view.holds.indices where view.holds[index].owner != house {
            if allies.contains(view.holds[index].owner) {
                if view.holds[index].wounded != nil { view.holds.tellAlike(at: index, toAllies: true) }
            } else if !view.holds[index].isToldAlike {
                view.holds.tellAlike(at: index)
            }
        }
        view.envoys = envoys.filter { ($0.from == house || $0.to == house) && hears($0.from, as: house) }
        // A House's answers at the Lyceum are its own until it rises.
        view.lyceumBook = lyceumBook?[house].map { [house: $0] }
        // A House's hidden Houses are its own to know.
        view.hidden = hidden?[house].map { [house: $0] }
        // Gifts too small for the chronicle are known only to the two Houses.
        view.gifts = gifts?.filter { $0.from == house || $0.to == house }
        view.reputed = commons.reputed
        view.reputedMight = commons.reputedMight
        // A House's riddle is its own, and its answer kept until it is answered.
        view.riddles = riddles.map { all in
            all.filter { $0.house == house }.map { riddle in
                var seen = riddle
                if riddle.answered == nil { seen.answer = nil }
                return seen
            }
        }
        // Whose a whisper is, and whether it is true, a keeper knows only of
        // its own, of those its Lanterns have tried, and of those found false.
        view.whispers = whispers?.map { whisper in
            var seen = whisper
            seen.triedBy = whisper.triedBy.filter { $0 == house }
            if !whisper.unmasked {
                if whisper.by != house { seen.by = nil }
                if seen.triedBy.isEmpty { seen.truth = nil }
            }
            return seen
        }
        // Its own commanders, and of others only those at the head of a
        // company in sight, or standing in the Ring, where every line is seen.
        let leading = Set(view.units.compactMap(\.leader)).union(ring?.entries.flatMap(\.line) ?? [])
        view.commanders = commanders?.filter { $0.owner == house || leading.contains($0.id) || $0.captive?.by == house }.map { commander in
            // What a prisoner told is their captor's alone to know.
            guard commander.captive?.told != nil, commander.captive?.by != house else { return commander }
            var kept = commander
            kept.captive?.told = nil
            return kept
        }
        // Its own gear; of others, what those commanders wear.
        view.armoury = armoury?.filter { $0.owner == house || $0.wornBy.map(leading.contains) == true }
        // What is in a House's satchel is its own to know.
        view.satchel = satchel?.filter { $0.house == house }
        view.makings = makings?.filter { $0.house == house }
        // The wilds in sight; the sites on ground the House has explored.
        view.wilds = wilds?.filter { map.index(of: $0.position).map { seen[$0] } ?? false }
        view.sites = sites?.filter { map.index(of: $0.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
        // Alliances are known to all; who is invited, or asking, only to the
        // alliance's own Houses and the House concerned.
        if let alliances {
            view.alliances = alliances.map { alliance in
                guard !alliance.members.contains(house) else { return alliance }
                var known = alliance
                known.invited = alliance.invited.filter { $0 == house }
                known.asking = alliance.asking.filter { $0 == house }
                // What it studies together is its own Houses' to know.
                known.lore = nil
                // And what its coffers hold.
                known.coffers = nil
                return known
            }
        }
        // Words to the realm to all; an alliance's to its own Houses.
        view.words = words.map { _ in words(heardBy: house) }
        // A keeper's reports are theirs alone, and the realm's bar on a House
        // that House's.
        view.reports = reports.map { $0.filter { $0.by == house } }.flatMap { $0.isEmpty ? nil : $0 }
        view.bars = bars.map { $0.filter { $0.house == house } }.flatMap { $0.isEmpty ? nil : $0 }
        // A rally only to its own side; a host on the march, also to the
        // House whose hold it marches on.
        view.rallies = rallies?.filter { rally in
            isOfRally(house, rally) || (rally.marching && hold(rally.target)?.owner == house)
        }
        // The lairs of the wilds on ground they have explored.
        view.lairs = lairs?.filter { map.index(of: $0.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
        // The holy sites on ground they have explored, and who holds them.
        view.shrines = shrines?.filter { map.index(of: $0.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
        // The alliances' standards and halls on ground they have explored;
        // its own alliance's standards wherever they stand, to raise them.
        let sworn = alliance(of: house)?.id
        view.standards = standards?.filter { standard in
            standard.alliance == sworn || map.index(of: standard.position).map { explored.indices.contains($0) && explored[$0] } ?? false
        }
        view.halls = halls?.filter { map.index(of: $0.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
        // Their storehouses too, and its own alliance's wherever it stands;
        // what is laid up in one is each House's own to know.
        view.storehouses = storehouses?.filter { storehouse in
            isOf(storehouse.alliance, house) || map.index(of: storehouse.position).map { explored.indices.contains($0) && explored[$0] } ?? false
        }
            .map { storehouse in
                var known = storehouse
                known.laidUp = storehouse.laidUp.filter { $0.house == house }
                return known
            }
        // The battles going on that they can see a side of.
        view.fields = fields?.filter { field in field.side(of: house) != nil || (map.index(of: field.at).map { seen[$0] } ?? false) }
        // The marches they may know of, worked out on what they see.
        view.marches = marches(seenBy: house, in: view, ways: ways)
        // Barges on the water: their own, and others' where they see the
        // water they put out from or make for.
        view.barges = barges.map { all in
            all.filter { barge in
                barge.owner == house || [barge.pushOff, barge.landing].contains { map.index(of: $0).map { seen[$0] } ?? false }
            }
        }
        // Bottles where they see them; the words only in their own and in
        // those they found.
        view.bottles = bottles.map { all in
            all.compactMap { bottle in
                let theirs = bottle.from == house || bottle.foundBy == house
                guard theirs || (map.index(of: bottle.position).map { seen[$0] } ?? false) else { return nil }
                var shown = bottle
                if !theirs { shown.words = "" }
                return shown
            }
        }
        // Every vigil's light for the fallen, the whole realm sees.
        view.vigils = vigils
        // Every fire in the blackwood, by its smoke, and the ash it leaves,
        // the whole realm sees.
        view.wildfires = wildfires
        // The pleas the House's own folk have brought it, none of another's.
        view.petitions = petitions.map { $0.filter { $0.house == house } }.flatMap { $0.isEmpty ? nil : $0 }
        view.petitioned = nil
        // The ground the House's own alliance has marked, none of another's.
        let ally = alliance(of: house)?.id
        view.allianceMarks = allianceMarks.map { $0.filter { $0.alliance == ally } }.flatMap { $0.isEmpty ? nil : $0 }
        // The holds of the ages before, where they have seen the ground.
        view.drowned = drowned.map { all in
            all.filter { hold in map.index(of: hold.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
        }
        // A House's own letter to the age to come; of those of the age
        // before, the ones on ground it has seen, their words only once found.
        view.letters = letters.flatMap { all in
            let own = all.filter { $0.house == house }
            return own.isEmpty ? nil : own
        }
        // A House's own standing orders; no other's.
        view.standing = standing.flatMap { all in
            let own = all.filter { $0.house == house }
            return own.isEmpty ? nil : own
        }
        view.oldLetters = oldLetters.flatMap { all in
            let seen = all.filter { letter in letter.at.flatMap(map.index(of:)).map { explored.indices.contains($0) && explored[$0] } ?? false }
                .map { letter in
                    var shown = letter
                    if letter.foundBy == nil { shown.words = "" }
                    return shown
                }
            return seen.isEmpty ? nil : seen
        }
        return view
    }
}

extension GameState {
    /// The events a keeper may hear of: their own House's, what happened
    /// where they can see, and the political news everyone hears (wars,
    /// holds taken, Houses fallen). Read against the world after them.
    public func events(_ events: [GameEvent], heardBy house: Int) -> [GameEvent] {
        let seen = visibility(for: house)
        func visible(_ hex: Hex) -> Bool { map.index(of: hex).map { seen[$0] } ?? false }
        // Another House's march is heard only where it is seen.
        let cut = events.compactMap { event -> GameEvent? in
            // What a storehouse torn down gave up is told to its taker and its alliance alone.
            if case .storehouseTorn(let id, let alliance, let by, let at, let carried) = event, !carried.isZero, by != house,
               self.alliance(alliance)?.members.contains(house) != true {
                return .storehouseTorn(storehouse: id, alliance: alliance, by: by, at: at, carried: .zero)
            }
            guard case .moved(let id, let path) = event, unit(id)?.owner != house else { return event }
            let shown = path.filter(visible)
            return shown.isEmpty ? nil : .moved(unit: id, path: shown)
        }
        return cut.filter { event in
            switch event {
            case .moved:
                return true
            case .battle(let battle):
                return battle.attackerOwner == house || battle.defenderOwner == house || visible(battle.at)
            case .unitLost(_, _, let owner, let at):
                return owner == house || visible(at)
            case .holdStruck(let id, _):
                return hold(id).map { $0.owner == house || visible($0.position) } ?? false
            case .buildingStarted(let id, _, _), .trainingStarted(let id, _), .unitTrained(_, let id):
                return hold(id)?.owner == house
            case .buildingCompleted(let id, _, _):
                // A work finished is told its own House, its allies, who know
                // it under way, and whoever sees the hold: every keeper is
                // told every hold's works as they stand, and a far one's
                // finishing is no news to the rest (eighty-five at a turn of
                // a realm of ninety-six seats, heard by every keeper, were
                // nine in ten of what a turn told them).
                guard let hold = hold(id) else { return false }
                return hold.owner == house || visible(hold.position) || (alliance(of: house)?.members.contains(hold.owner) ?? false)
            case .gifted(let from, let to, _), .tradeAnswered(_, let from, let to, _):
                return from == house || to == house
            case .bartered(let owner, _, _), .starving(let owner), .studyBegun(let owner, _, _), .studyCompleted(let owner, _, _),
                 .commanderJoined(_, let owner), .commanderRose(_, let owner, _), .commanderWounded(_, let owner),
                 .talentLearned(_, let owner, _, _), .talentsForgotten(_, let owner),
                 .gearFound(let owner, _, _), .gearWorn(_, let owner, _), .gearTakenOff(_, let owner, _), .gearScrapped(let owner, _, _),
                 .carriedToInfirmary(_, let owner, _), .healingBegun(_, let owner, _), .woundedLost(_, let owner, _),
                 .itemsGiven(let owner, _, _), .itemUsed(let owner, _, _), .makingsFound(let owner, _, _), .gearForged(let owner, _),
                 .laidUp(let owner, _), .tookBack(let owner, _), .favourRose(let owner, _), .drilled(_, let owner, _, _),
                 .frontier(.crossed(let owner, _, _)), .frontier(.raised(let owner, _, _)), .frontier(.toldHome(let owner, _, _, _, _)):
                return owner == house
            case .unitHealed(let id, _):
                return unit(id)?.owner == house
            case .holdScouted(let report):
                return report.by == house
            case .scoutSeen(let holdID, _):
                return hold(holdID)?.owner == house
            case .lairAssaulted(let assault):
                // A gate of the Crown broken, the whole Frontier hears.
                return assault.houses.contains(house) || visible(assault.at) || (assault.gate != nil && assault.broken)
            case .standardRaised(_, let id, _, let at):
                return alliance(id)?.members.contains(house) == true || visible(at)
            case .standardTorn(_, let id, let by, let at):
                return by == house || alliance(id)?.members.contains(house) == true || visible(at)
            case .standardStruck(let id, _, let by, let at):
                return by == house || standard(id).flatMap { alliance($0.alliance) }?.members.contains(house) == true || visible(at)
            case .standardRisen(_, let id, let at):
                return alliance(id)?.members.contains(house) == true || visible(at)
            case .standardHelped(let id, let by, let at):
                return by == house || standard(id).flatMap { alliance($0.alliance) }?.members.contains(house) == true || visible(at)
            case .hallRaised(_, let id, _, let at), .hallRisen(_, let id, let at):
                return alliance(id)?.members.contains(house) == true || visible(at)
            case .hallStruck(_, let id, _, let by, let at):
                return by == house || alliance(id)?.members.contains(house) == true || visible(at)
            case .hallTorn(_, let id, let by, let at):
                return by == house || alliance(id)?.members.contains(house) == true || visible(at)
            case .storehouseRaised(_, let id, _, let at), .storehouseRisen(_, let id, let at), .yardRaised(_, let id, _, _, let at):
                return alliance(id)?.members.contains(house) == true || visible(at)
            case .storehouseStruck(_, let id, _, let by, let at), .storehouseTorn(_, let id, let by?, let at, _):
                return by == house || alliance(id)?.members.contains(house) == true || visible(at)
            case .storehouseTorn(_, let id, nil, let at, _):
                return alliance(id)?.members.contains(house) == true || visible(at)
            case .commanderAssigned(let id, _), .commanderReleased(let id):
                return commander(id)?.owner == house
            case .skillFired(_, let owner, _, let at):
                return owner == house || visible(at)
            case .hunted(let hunt):
                return hunt.attackerOwner == house || visible(hunt.at)
            case .sentToGather(let id, _):
                return unit(id)?.owner == house
            case .gathered(_, let owner, _), .delivered(_, let owner, _, _):
                return owner == house
            case .siteWorkedOut(_, _, let at):
                return visible(at)
            case .allianceFounded, .allianceJoined, .allianceLeft, .allianceLed, .allianceDisbanded:
                return true
            case .allianceInvited(let id, let other), .allianceAsked(let id, let other), .allianceAnswered(let id, let other, _):
                return other == house || alliance(id)?.members.contains(house) == true
            case .helpGiven(let by, let to, _):
                return by == house || to == house
            case .rallyCalled(_, let caller, _), .rallyDispersed(_, let caller):
                return caller == house || areAllied(caller, house)
            case .rallyJoined(let id, _, let owner):
                return owner == house || rally(id).map { isOfRally(house, $0) } == true
            case .rallySetOut(_, let caller, _, let defender, _), .rallyStruck(_, let caller, _, let defender, _):
                return caller == house || defender == house || areAllied(caller, house)
            case .sentToReinforce(_, let owner, let holdID):
                return owner == house || hold(holdID)?.owner == house
            case .happeningBegun, .happeningEnded, .heritageTaken, .crestTaken, .sunderingBegun, .sunderingEnded, .fordOpened, .fordClosed, .crownSurfaced, .crownTaken, .crownFell, .crownSank,
                 .titleBestowed, .titlesLapsed, .prophesied, .staked, .prophecyJudged, .veilDrawn, .veilLifted:
                return true
            case .workPlaced(let holdID, _, _):
                return hold(holdID)?.owner == house
            case .setOnTheWater(_, let owner, let fromID, _):
                return owner == house || (hold(fromID).map { visible($0.position) } ?? false)
            case .ferried(_, let owner, let toID, _):
                return owner == house || (hold(toID).map { visible($0.position) } ?? false)
            case .seatRaisedAnew(_, let owner, let from, let to):
                return owner == house || visible(from) || visible(to)
            case .ringLineStood(let owner, _):
                return owner == house
            case .bout(let bout):
                return bout.challenger == house || bout.defender == house
            case .ringHonoured:
                return true
            case .whispered, .whisperUnmasked:
                return true
            case .whisperLet(_, let teller):
                return teller == house
            case .whisperTried(_, let trier, _):
                return trier == house
            case .riddleSet(let asked), .riddleAnswered(let asked, _, _):
                return asked == house
            case .stillHour:
                return true
            case .rippleCast(let caster, _):
                return caster == house
            case .letterSent(let letter):
                return letter.from == house || letter.to == house
            case .lairRungClimbed(let owner, _):
                return owner == house
            case .reflectionCast(let owner, _):
                return owner == house
            case .mirrorWalkBegun, .mirrorWalked:
                // The water stills for every shore to see.
                return true
            case .calmBroken:
                // The whole lake stirs: every shore sees it.
                return true
            case .lyceumAnswered(let owner, _):
                return owner == house
            case .lyceumJudged, .monumentStoneSet:
                return true
            case .labourDone(let owner, _), .chestOpened(let owner, _), .innChestOpened(let owner, _, _):
                return owner == house
            case .expedition(let result):
                return result.house == house
            case .pedlarCame(let owner, _), .pedlarSold(let owner, _), .pedlarLeft(let owner):
                return owner == house
            case .sculpturesFound(let owner, _), .commanderStarred(_, let owner, _):
                return owner == house
            case .stoneSunk(_, let owner, _), .stoneHeard(_, let owner, _), .stoneLost(_, let owner):
                return owner == house
            case .dreamt(let dream):
                return dream.house == house
            case .carriedAshore(_, let owner, _, let to):
                return owner == house || visible(to)
            case .recalled(_, let owner), .marchHalted(_, let owner, _, _, _):
                return owner == house
            case .fieldJoined(_, let at, let first, let second):
                return first == house || second == house || visible(at)
            case .fieldEnded(let field):
                return field.side(of: house) != nil || visible(field.at)
            case .allianceStudyChosen(let id, _), .allianceGift(_, let id, _, _, _), .allianceStudied(let id, _, _):
                return alliance(id)?.members.contains(house) == true
            case .happeningMark(let owner, _, _, _), .deedDone(let owner, _), .chargeDone(let owner, _, _):
                return owner == house
            case .said(let word):
                return (word.alliance == nil || word.alliance == alliance(of: house)?.id) && hears(word.from, as: house)
            case .sung:
                return true
            case .bottleCast(_, let from, let at):
                return from == house || visible(at)
            case .bottleFound(let bottle, let by):
                return by == house || bottle.from == house
            case .vigilKept, .vigilHonoured:
                // A light for the fallen, and who honours it, the whole realm sees.
                return true
            case .vigilOut(_, let mourner, _):
                return mourner == house
            case .woodKindled, .firesDoused:
                // Smoke rising from the blackwood, and the mist putting out
                // the fires, the whole realm sees.
                return true
            case .fireSpread(let hexes, let by, _):
                // Told to the House whose fire it is, and wherever it is seen
                // spreading (a House sees its own land).
                return by == house || hexes.contains(where: visible)
            case .burnedInFire(_, let owner, let at, _, _):
                return owner == house || visible(at)
            case .petitionBrought(let petition), .petitionAnswered(let petition, _, _), .petitionWithdrawn(let petition):
                // A House's folk speak to their own keeper alone.
                return petition.house == house
            case .groundMarked(let mark), .markLifted(let mark, _), .markHeeded(let mark, _):
                // An alliance's marks are its own Houses' alone.
                return alliance(of: house)?.id == mark.alliance
            case .letterSealed(_, let by):
                return by == house
            case .letterFound:
                // A letter of the age before, found, the whole realm hears.
                return true
            case .standingOrdersGiven(let by):
                return by == house
            case .commanderTaken(_, let owner, let by), .prisonerFreed(_, let owner, let by, _):
                return owner == house || by == house
            case .prisonerQuestioned(_, let by, _):
                return by == house
            case .oathSworn, .oathRenounced:
                // An oath is sworn, and renounced, before the whole realm.
                return true
            case .oathEnded(let oath, let why):
                return why == .broken || oath.by == house || oath.to == house
            case .wordReported(_, let by):
                return by == house
            case .wordRemoved:
                return true
            case .barredFromWords(let barred, _):
                return barred == house
            case .edictProposed, .edictVoted, .edictPassed, .edictFailed, .edictLapsed, .edictBroken:
                // The realm's law is every House's to know.
                return true
            case .eclipse, .eclipseEnded:
                // The moon eaten, and come back, every House sees.
                return true
            case .promoted(_, let owner, _):
                return owner == house
            case .ruinSearched(let at, let by, _):
                return by == house || visible(at)
            case .envoyArrived(let envoy):
                return envoy.from == house || envoy.to == house
            case .proposalAnswered(_, let from, let to, _):
                return from == house || to == house
            case .holdCaptured, .seatMoved, .holdFounded, .stanceChanged, .houseFell, .gameEnded, .shrineTaken:
                return true
            }
        }
    }
}

extension GameState {
    /// Why a House would be refused an order on this world, if it would. Asked
    /// of a keeper's view, the answer rests only on what their House knows.
    public func refusal(of command: Command, as house: Int) -> RuleError? {
        var tried = self
        do {
            try tried.perform(command, as: house)
            return nil
        } catch {
            return error
        }
    }
}

/// A keeper's view of the realm: who they are, the age, and their view of
/// the world.
public struct RealmView: Codable, Equatable, Sendable {
    public let keeper: Keeper
    public let age: Int
    public let world: GameState

    public init(keeper: Keeper, age: Int, world: GameState) {
        self.keeper = keeper
        self.age = age
        self.world = world
    }
}

extension RealmState {
    /// What the realm tells one keeper: their own view of its world.
    public func view(for id: String, ways: [Int: [Hex]]? = nil) -> RealmView? {
        view(for: id, commons: world.viewCommons(ways: ways))
    }

    /// A keeper's view with what every view takes alike already worked out
    /// (`GameState.viewCommons`), of this realm's world as it stands.
    public func view(for id: String, commons: GameState.ViewCommons) -> RealmView? {
        guard let keeper = keeper(id) else { return nil }
        return RealmView(keeper: keeper, age: age, world: world.view(for: keeper.house ?? -1, commons: commons))
    }
}
