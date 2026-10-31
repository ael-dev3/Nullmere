/// What a keeper may know of the world. The realm sends each keeper this,
/// never the whole world: their own House in full, the political map
/// (every House, every hold and its works, wars and pacts, the chronicle),
/// and of the rest only what their House can see or has explored.
extension GameState {
    /// The ground a keeper hasn't explored, as their copy of the world
    /// holds it: plain land, so a march into the unknown can be ordered
    /// and the realm finds the true way.
    public static let unknownGround = Tile(terrain: .greyfield)

    public func view(for house: Int) -> GameState {
        var view = self
        // The realm's words would grow the whole map again; where its
        // rounds begin is all the keeper's copy needs of them.
        view.dealing = dealt
        view.settings.seedText = ""
        let explored = houses.indices.contains(house) ? houses[house].explored : []
        for index in 0..<map.count where !(explored.indices.contains(index) && explored[index]) {
            view.map.set(index: index, GameState.unknownGround)
        }
        let seen = visibility(for: house)
        view.units = units.filter { unit in
            unit.owner == house || (map.index(of: unit.position).map { seen[$0] } ?? false)
        }
        // A company in sight shows where it stands, not where it is bound,
        // nor what it is about or carries.
        for index in view.units.indices where view.units[index].owner != house {
            view.units[index].destination = nil
            view.units[index].errand = nil
            view.units[index].load = nil
        }
        // Allies know what each other has under way, for they help it.
        let allies = Set(alliance(of: house)?.members ?? [])
        for index in view.houses.indices where view.houses[index].id != house {
            view.houses[index].stock = .zero
            view.houses[index].explored = Array(repeating: false, count: map.count)
            view.houses[index].research = Research()
            if allies.contains(view.houses[index].id) {
                view.houses[index].research.pursuit = houses[index].research.pursuit
            }
        }
        for index in view.holds.indices where view.holds[index].owner != house && !allies.contains(view.holds[index].owner) {
            view.holds[index].project = nil
            view.holds[index].training = nil
        }
        // Who lies in a hold's beds is its own House's to know.
        for index in view.holds.indices where view.holds[index].owner != house {
            view.holds[index].wounded = nil
        }
        view.envoys = envoys.filter { $0.from == house || $0.to == house }
        // Gifts too small for the chronicle are known only to the two Houses.
        view.gifts = gifts?.filter { $0.from == house || $0.to == house }
        view.reputed = houses.map { strength(of: $0.id) }
        view.reputedMight = houses.map { might(of: $0.id) }
        // Its own commanders, and of others only those at the head of a
        // company in sight.
        let leading = Set(view.units.compactMap(\.leader))
        view.commanders = commanders?.filter { $0.owner == house || leading.contains($0.id) }
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
        // A rally only to its own side; a host on the march, also to the
        // House whose hold it marches on.
        view.rallies = rallies?.filter { rally in
            isOfRally(house, rally) || (rally.marching && hold(rally.target)?.owner == house)
        }
        // The lairs of the wilds on ground they have explored.
        view.lairs = lairs?.filter { map.index(of: $0.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
        // The holy sites on ground they have explored, and who holds them.
        view.shrines = shrines?.filter { map.index(of: $0.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
        // The alliances' standards and halls on ground they have explored.
        view.standards = standards?.filter { map.index(of: $0.position).map { explored.indices.contains($0) && explored[$0] } ?? false }
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
        view.marches = marches(seenBy: house, in: view)
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
            case .gifted(let from, let to, _), .tradeAnswered(_, let from, let to, _):
                return from == house || to == house
            case .bartered(let owner, _, _), .starving(let owner), .studyBegun(let owner, _, _), .studyCompleted(let owner, _, _),
                 .commanderJoined(_, let owner), .commanderRose(_, let owner, _), .commanderWounded(_, let owner),
                 .talentLearned(_, let owner, _, _), .talentsForgotten(_, let owner),
                 .gearFound(let owner, _, _), .gearWorn(_, let owner, _), .gearTakenOff(_, let owner, _), .gearScrapped(let owner, _, _),
                 .carriedToInfirmary(_, let owner, _), .healingBegun(_, let owner, _), .woundedLost(_, let owner, _),
                 .itemsGiven(let owner, _, _), .itemUsed(let owner, _, _), .makingsFound(let owner, _, _), .gearForged(let owner, _),
                 .laidUp(let owner, _), .tookBack(let owner, _), .favourRose(let owner, _),
                 .frontier(.crossed(let owner, _, _)), .frontier(.raised(let owner, _, _)), .frontier(.toldHome(let owner, _, _, _, _)):
                return owner == house
            case .unitHealed(let id, _):
                return unit(id)?.owner == house
            case .holdScouted(let report):
                return report.by == house
            case .scoutSeen(let holdID, _):
                return hold(holdID)?.owner == house
            case .lairAssaulted(let assault):
                return assault.houses.contains(house) || visible(assault.at)
            case .standardRaised(_, let id, _, let at):
                return alliance(id)?.members.contains(house) == true || visible(at)
            case .standardTorn(_, let id, let by, let at):
                return by == house || alliance(id)?.members.contains(house) == true || visible(at)
            case .standardStruck(let id, _, let by, let at):
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
            case .happeningBegun, .happeningEnded, .heritageTaken, .sunderingBegun, .sunderingEnded:
                return true
            case .fieldJoined(_, let at, let first, let second):
                return first == house || second == house || visible(at)
            case .fieldEnded(let field):
                return field.side(of: house) != nil || visible(field.at)
            case .allianceStudyChosen(let id, _), .allianceGift(_, let id, _, _, _), .allianceStudied(let id, _, _):
                return alliance(id)?.members.contains(house) == true
            case .happeningMark(let owner, _, _, _), .deedDone(let owner, _), .chargeDone(let owner, _, _):
                return owner == house
            case .said(let word):
                return word.alliance == nil || word.alliance == alliance(of: house)?.id
            case .promoted(_, let owner, _):
                return owner == house
            case .ruinSearched(let at, let by, _):
                return by == house || visible(at)
            case .envoyArrived(let envoy):
                return envoy.from == house || envoy.to == house
            case .proposalAnswered(_, let from, let to, _):
                return from == house || to == house
            case .holdCaptured, .seatMoved, .holdFounded, .buildingCompleted, .stanceChanged, .houseFell, .gameEnded, .shrineTaken:
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
    public func view(for id: String) -> RealmView? {
        guard let keeper = keeper(id) else { return nil }
        let world = keeper.house.map { self.world.view(for: $0) } ?? self.world.view(for: -1)
        return RealmView(keeper: keeper, age: age, world: world)
    }
}
