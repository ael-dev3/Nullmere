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
        for index in view.houses.indices where view.houses[index].id != house {
            view.houses[index].stock = .zero
            view.houses[index].explored = Array(repeating: false, count: map.count)
        }
        for index in view.holds.indices where view.holds[index].owner != house {
            view.holds[index].project = nil
            view.holds[index].training = nil
        }
        view.envoys = envoys.filter { $0.from == house || $0.to == house }
        view.reputed = houses.map { strength(of: $0.id) }
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
        return events.filter { event in
            switch event {
            case .moved(let id, let path):
                return unit(id)?.owner == house || path.contains(where: visible)
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
            case .bartered(let owner, _, _), .starving(let owner):
                return owner == house
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
