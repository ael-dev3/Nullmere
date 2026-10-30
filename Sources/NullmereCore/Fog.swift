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
        // The realm's words would grow the whole map again.
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
        view.envoys = envoys.filter { $0.from == house || $0.to == house }
        // Gifts too small for the chronicle are known only to the two Houses.
        view.gifts = gifts?.filter { $0.from == house || $0.to == house }
        view.reputed = houses.map { strength(of: $0.id) }
        view.reputedMight = houses.map { might(of: $0.id) }
        // Its own commanders, and of others only those at the head of a
        // company in sight.
        let leading = Set(view.units.compactMap(\.leader))
        view.commanders = commanders?.filter { $0.owner == house || leading.contains($0.id) }
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
                 .talentLearned(_, let owner, _, _), .talentsForgotten(_, let owner):
                return owner == house
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
            case .happeningBegun, .happeningEnded:
                return true
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
            case .holdCaptured, .seatMoved, .holdFounded, .buildingCompleted, .stanceChanged, .houseFell, .gameEnded:
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
