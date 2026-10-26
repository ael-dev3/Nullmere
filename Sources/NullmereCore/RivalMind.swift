/// How a rival House decides what to do. It plays by the same rules as the
/// player, through the same commands, and judges others by what it has seen,
/// how strong they are, its temperament, and what it remembers of them.
struct RivalMind {
    let house: Int

    // MARK: Answering offers

    func accepts(_ proposal: Proposal, from proposer: Int, in state: GameState) -> Bool {
        guard let relation = state.relation(house, proposer) else { return false }
        let me = state.houses[house]
        let mine = max(1, state.strength(of: house))
        let theirs = max(1, state.strength(of: proposer))
        let lasted = state.watch - relation.since

        switch proposal {
        case .peace:
            guard lasted >= 3 else { return false }
            // The ambitious and the cunning show no mercy to a House on its
            // last holds when they are clearly the stronger.
            let nearlyFallen = state.holds(of: proposer).count <= 2 && mine * 2 > theirs * 3
            if nearlyFallen, me.temperament == .ambitious || me.temperament == .cunning {
                return false
            }
            // A House far the stronger fights on until the war is long.
            if mine * 2 > theirs * 3, lasted <= 30 { return false }
            switch me.temperament {
            case .ambitious: return mine * 10 < theirs * 11 || lasted > 16
            case .cunning: return mine < theirs || lasted > 10
            case .steadfast: return mine * 2 < theirs * 3 || lasted > 8
            case .wary:
                // A wronged House fights on longer.
                let wronged = relation.aggressor == proposer
                return wronged ? (mine < theirs || lasted > 14) : (mine * 2 < theirs * 3 || lasted > 6)
            }
        case .fealty:
            // Who would refuse a vassal?
            return me.liege == nil
        case .tribute:
            // Pay rather than fight a war it would lose.
            switch me.temperament {
            case .wary, .steadfast: return theirs * 10 > mine * 15
            case .cunning: return theirs * 10 > mine * 18
            case .ambitious: return theirs > mine * 2
            }
        case .pact:
            if relation.betrayals > 0 || relation.aggressor == proposer { return false }
            switch me.temperament {
            case .ambitious: return theirs * 10 > mine * 13
            case .cunning: return true
            case .steadfast: return state.watch >= 6
            case .wary: return state.watch >= 10 && theirs * 2 >= mine
            }
        }
    }

    // MARK: A watch's decisions

    func takeTurn(in state: inout GameState) -> [GameEvent] {
        guard let me = state.house(house), !me.isEliminated else { return [] }
        var events: [GameEvent] = []
        var random = state.random()

        events += conductDiplomacy(in: &state, random: &random)
        events += balanceStores(in: &state)
        for hold in state.holds(of: house).sorted(by: { $0.id < $1.id }) {
            events += manage(hold.id, in: &state, random: &random)
        }
        let garrisons = assignGarrisons(in: state)
        let visible = state.visibility(for: house)
        for unit in state.units(of: house).sorted(by: { $0.id < $1.id }) {
            guard state.unit(unit.id) != nil, state.outcome == nil else { continue }
            events += command(unit.id, garrisonFor: garrisons[unit.id], seeing: visible, in: &state)
        }
        return events
    }

    private func perform(_ command: Command, in state: inout GameState) -> [GameEvent] {
        (try? state.perform(command, as: house)) ?? []
    }

    // MARK: Diplomacy

    private func conductDiplomacy(in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        let me = state.houses[house]
        let mine = max(1, state.strength(of: house))
        let enemies = state.livingHouses.filter { state.isAtWar(house, $0.id) }.count
        var events: [GameEvent] = []
        var declared = false

        // A rising Moonspire frightens everyone else around the lake.
        if let rising = spireThreat(in: state), state.stance(house, rising) != .war,
           !inTruce(with: rising, in: state),
           mine * 10 > max(1, state.strength(of: rising)) * 6, random.chance(35) {
            if (try? state.declareWar(by: house, on: rising, fearingSpire: true)) != nil {
                events.append(.stanceChanged(first: house, second: rising, stance: .war, by: house))
                declared = true
            }
        }

        for other in state.livingHouses where other.id != house {
            guard let relation = state.relation(house, other.id) else { continue }
            let theirs = max(1, state.strength(of: other.id))
            let lasted = state.watch - relation.since
            let neighbours = knowsHold(of: other.id, within: 14, in: state)

            switch relation.stance {
            case .war:
                let losing = mine * 10 < theirs * 7
                let weary = lasted >= 20 && me.temperament != .ambitious && mine * 2 < theirs * 3
                // A House whose siege is going well fights on.
                let winning = siegePlan(in: state).map { plan in
                    state.hold(at: plan.target).map { $0.owner == other.id && $0.ward * 2 < $0.maximumWard } ?? false
                } ?? false
                // Broken, and against a far stronger House: bend the knee
                // rather than fall.
                let broken = state.watch >= 70 && state.holds(of: house).count <= 3 && mine * 5 < theirs * 2 && me.liege == nil
                    && state.houses[other.id].liege == nil
                if lasted >= 4, broken, random.chance(50) {
                    events += perform(.propose(.fealty, to: other.id), in: &state)
                } else if lasted >= 4, losing || (weary && !winning), random.chance(40) {
                    events += perform(.propose(.peace, to: other.id), in: &state)
                }
            case .peace:
                // The ambitious and the cunning, far the stronger, ask a
                // neighbour for tribute, and march only if refused.
                let greedy = (me.temperament == .ambitious || me.temperament == .cunning) && state.watch >= 20
                    && mine * 100 > theirs * 125 && !state.paidTributeLately(house, other.id)
                    && me.liege != other.id && other.liege != house
                guard !declared, neighbours, !inTruce(with: other.id, in: state) else { break }
                if greedy, random.chance(enemies == 0 ? 10 : 5) {
                    events += perform(.propose(.tribute, to: other.id), in: &state)
                    declared = true
                    break
                }
                guard enemies == 0 else { break }
                let grudge = relation.aggressor == other.id
                var wantsWar: Bool
                switch me.temperament {
                case .ambitious: wantsWar = state.watch >= 12 && mine * 10 > theirs * 12 && random.chance(30)
                case .cunning: wantsWar = state.watch >= 15 && mine * 10 > theirs * 13 && random.chance(25)
                case .wary: wantsWar = grudge && mine * 10 > theirs * 12 && random.chance(15)
                case .steadfast: wantsWar = state.watch >= 30 && mine * 10 > theirs * 16 && random.chance(10)
                }
                // The leading House, once clearly the strongest, presses its
                // advantage toward dominion, whatever its temper.
                let others = state.livingHouses.filter { $0.id != house }.map { state.strength(of: $0.id) }
                let leading = state.watch >= 50 && mine * 10 > (others.max() ?? 0) * 13
                if !wantsWar, leading, mine * 10 > theirs * 15, random.chance(35) {
                    wantsWar = true
                }
                // Tribute paid buys the peace for a while.
                if wantsWar, state.paidTributeLately(house, other.id) { wantsWar = false }
                // Even set on war, the greedy may ask for tribute first.
                let demanding = wantsWar && greedy && random.chance(45)
                if demanding {
                    events += perform(.propose(.tribute, to: other.id), in: &state)
                    declared = true
                } else if wantsWar {
                    events += perform(.declareWar(on: other.id), in: &state)
                    declared = true
                } else if me.temperament != .ambitious, state.watch >= 8, !grudge, relation.betrayals == 0, random.chance(8) {
                    events += perform(.propose(.pact, to: other.id), in: &state)
                }
            case .pact:
                let sworn = me.liege == other.id || state.houses[other.id].liege == house
                if !sworn, me.temperament == .cunning, !declared, enemies == 0, state.watch >= 25,
                   mine * 10 > theirs * 18, neighbours, random.chance(10) {
                    events += perform(.declareWar(on: other.id), in: &state)
                    declared = true
                }
            }
        }
        return events
    }

    /// Watches a House keeps a fresh peace before it would break it.
    static let truce = 10

    private func inTruce(with other: Int, in state: GameState) -> Bool {
        guard let relation = state.relation(house, other), relation.stance != .war else { return false }
        return relation.aggressor != nil && state.watch - relation.since < RivalMind.truce
    }

    /// Another House whose Moonspire has reached its third stage, if any.
    func spireThreat(in state: GameState) -> Int? {
        state.holds
            .filter { $0.owner != house && $0.isSeat && $0.level(.moonspire) >= 3 }
            .max { ($0.level(.moonspire), $0.id) < ($1.level(.moonspire), $1.id) }?
            .owner
    }

    private func knowsHold(of other: Int, within distance: Int, in state: GameState) -> Bool {
        let explored = state.houses[house].explored
        let mine = state.holds(of: house)
        return state.holds(of: other).contains { theirs in
            guard let index = state.map.index(of: theirs.position), explored[index] else { return false }
            return mine.contains { $0.position.distance(to: theirs.position) <= distance }
        }
    }

    // MARK: Barter

    /// Trades from whatever is near the storage limit into whatever is short.
    private func balanceStores(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        let room = state.storage(of: house)
        for _ in 0..<2 {
            let stock = state.houses[house].stock
            let common: [Resource] = [.grain, .timber, .stone]
            guard let low = common.min(by: { (stock[$0], $0.rawValue) < (stock[$1], $1.rawValue) }),
                  let high = Resource.allCases.max(by: { (stock[$0] * $0.worth, $0.rawValue) < (stock[$1] * $1.worth, $1.rawValue) }),
                  low != high,
                  stock[low] < room / 5,
                  stock[high] * high.worth > room * 3 / 5
            else { break }
            let affordable = stock[high] / 2 * high.worth / 3
            let amount = min(room / 4 - stock[low], affordable)
            guard amount >= 10 else { break }
            events += perform(.barter(give: high, take: low, amount: amount), in: &state)
        }
        return events
    }

    // MARK: Holds

    private func manage(_ holdID: Int, in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        var events: [GameEvent] = []
        guard let hold = state.hold(holdID) else { return events }
        if hold.project == nil, let kind = chooseBuilding(for: hold, in: state) {
            events += perform(.build(hold: holdID, kind: kind), in: &state)
        }
        if let hold = state.hold(holdID), hold.training == nil, let kind = chooseTraining(for: hold, in: state, random: &random) {
            events += perform(.train(hold: holdID, kind: kind), in: &state)
        }
        return events
    }

    private func chooseBuilding(for hold: Hold, in state: GameState) -> BuildingKind? {
        let me = state.houses[house]
        let stock = me.stock
        let atWar = state.livingHouses.contains { state.isAtWar(house, $0.id) }
        let threatened = atWar && enemyMilitary(near: hold.position, within: 5, in: state)
        var wishes: [BuildingKind] = []

        if threatened, hold.level(.walls) < 3 { wishes.append(.walls) }
        if hold.isSeat, hold.level(.musterHall) == 0, state.watch >= 3 { wishes.append(.musterHall) }

        let income = state.income(of: hold)
        let net = state.income(of: house).grain - state.upkeep(of: house)
        if net < 4 { wishes.append(.granary) }
        let economy: [BuildingKind] = [.granary, .sawpit, .quarry, .saltworks]
            .filter { kind in
                guard let resource = kind.boostedResource else { return false }
                return income[resource] >= (resource == .moonsalt ? 2 : 4)
            }
            .sorted { (hold.level($0), $0.rawValue) < (hold.level($1), $1.rawValue) }
        if let first = economy.first { wishes.append(first) }

        if hold.isSeat {
            let spireFrom = me.temperament == .steadfast ? 20 : 34
            if state.watch >= spireFrom, !threatened { wishes.append(.moonspire) }
            if me.temperament == .ambitious, hold.level(.musterHall) < 3 { wishes.append(.musterHall) }
            if hold.level(.musterHall) < 2, state.watch >= 14 { wishes.append(.musterHall) }
        }
        if hold.level(.walls) < 1, state.watch >= 10 { wishes.append(.walls) }
        if hold.level(.beacon) < 1, state.watch >= 18 { wishes.append(.beacon) }
        wishes += economy.dropFirst()

        for kind in wishes {
            if kind.requiresSeat, !hold.isSeat { continue }
            guard let cost = state.nextLevelCost(of: kind, in: hold) else { continue }
            if stock.covers(cost) { return kind }
            // Save for the Moonspire rather than spending on lesser works.
            if kind == .moonspire { return nil }
        }
        return nil
    }

    private func chooseTraining(for hold: Hold, in state: GameState, random: inout SeededRandom) -> UnitKind? {
        let me = state.houses[house]
        let units = state.units(of: house)
        let lanterns = units.filter { $0.kind == .lantern }.count
        let founders = units.filter { $0.kind == .founder }.count
        let military = units.filter { $0.kind.isMilitary }.count
        let holds = state.holds(of: house).count
        let atWar = state.livingHouses.contains { state.isAtWar(house, $0.id) }
        let netGrain = state.income(of: house).grain - state.upkeep(of: house)

        let wantedHolds: Int
        switch me.temperament {
        case .ambitious: wantedHolds = 6
        case .cunning: wantedHolds = 5
        case .steadfast, .wary: wantedHolds = 4
        }
        let wealthy = me.stock.grain > 250 && me.stock.timber > 150 ? holds : 0
        let wantedArmy = holds * 2 + 1 + (atWar ? 3 + holds : 0) + (me.temperament == .ambitious ? 2 : 0) + wealthy

        var choice: UnitKind?
        if lanterns < (state.watch < 20 ? 2 : 1), hold.isSeat {
            choice = .lantern
        } else if holds + founders < wantedHolds, founders == 0, military >= 2, netGrain > 2,
                  bestSite(from: hold.position, in: state) != nil {
            choice = .founder
        } else if military < wantedArmy, netGrain > 1 || atWar {
            let muster = hold.level(.musterHall)
            if muster >= 3, random.chance(35) {
                choice = .rider
            } else if muster >= 2, random.chance(35) {
                choice = .bow
            } else if muster >= 1 {
                choice = .spear
            }
        }
        guard let kind = choice, hold.level(.musterHall) >= kind.requiredMuster, me.stock.covers(state.trainingCost(of: kind, for: house)) else { return nil }
        return kind
    }

    // MARK: Units

    /// Picks a defender for every hold that has none standing on it.
    private func assignGarrisons(in state: GameState) -> [Int: Hex] {
        var result: [Int: Hex] = [:]
        var free = state.units(of: house).filter { $0.kind.isMilitary }
        for hold in state.holds(of: house).sorted(by: { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }) {
            if let standing = free.firstIndex(where: { $0.position == hold.position }) {
                result[free[standing].id] = hold.position
                free.remove(at: standing)
                continue
            }
            guard let nearest = free.indices.min(by: { a, b in
                (free[a].position.distance(to: hold.position), free[a].id) < (free[b].position.distance(to: hold.position), free[b].id)
            }), free[nearest].position.distance(to: hold.position) <= 8 else { continue }
            result[free[nearest].id] = hold.position
            free.remove(at: nearest)
        }
        return result
    }

    private func command(_ unitID: Int, garrisonFor post: Hex?, seeing visible: [Bool], in state: inout GameState) -> [GameEvent] {
        guard let unit = state.unit(unitID) else { return [] }
        switch unit.kind {
        case .lantern:
            return explore(with: unit, in: &state)
        case .founder:
            return settle(with: unit, in: &state)
        case .spear, .bow, .rider:
            if let post {
                if unit.position == post {
                    if let target = foeInReach(of: unit, in: state) {
                        return perform(.attack(unit: unitID, target: target), in: &state)
                    }
                    return unit.fortified ? [] : perform(.fortify(unit: unitID), in: &state)
                }
                return perform(.move(unit: unitID, to: post), in: &state)
            }
            return campaign(with: unit, seeing: visible, in: &state)
        }
    }

    private func foeInReach(of unit: Unit, in state: GameState) -> Hex? {
        guard unit.movesLeft > 0 else { return nil }
        return unit.position.spiral(unit.kind.range).dropFirst().first { hex in
            if let other = state.unit(at: hex), other.owner != house, state.isAtWar(house, other.owner) { return true }
            if let hold = state.hold(at: hex), hold.owner != house, state.isAtWar(house, hold.owner) { return true }
            return false
        }
    }

    private func campaign(with unit: Unit, seeing visible: [Bool], in state: inout GameState) -> [GameEvent] {
        if let target = foeInReach(of: unit, in: state) {
            return perform(.attack(unit: unit.id, target: target), in: &state)
        }
        // Meet enemies who come close.
        let skirmish = state.units
            .filter { $0.owner != house && state.isAtWar(house, $0.owner) && $0.position.distance(to: unit.position) <= 3 }
            .filter { state.map.index(of: $0.position).map { visible[$0] } ?? false }
            .min { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
        if let skirmish {
            return perform(.move(unit: unit.id, to: skirmish.position), in: &state)
        }
        if let siege = siegePlan(in: state) {
            let near = unit.position.distance(to: siege.target) <= RivalMind.siegeReach
            if siege.ready || (near && unit.position.distance(to: siege.target) <= unit.kind.range + 1) {
                return perform(.move(unit: unit.id, to: siege.target), in: &state)
            }
            if unit.position.distance(to: siege.muster) > 1 {
                return perform(.move(unit: unit.id, to: siege.muster), in: &state)
            }
            return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
        }
        // At peace: wait near the nearest hold.
        if let home = state.holds(of: house).min(by: { $0.position.distance(to: unit.position) < $1.position.distance(to: unit.position) }),
           home.position.distance(to: unit.position) > 2 {
            return perform(.move(unit: unit.id, to: home.position), in: &state)
        }
        return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
    }

    /// How close to a besieged hold the army gathers before it goes in.
    static let siegeReach = 4

    struct Siege {
        let target: Hex
        let muster: Hex
        /// Whether enough companies have gathered to go in together.
        let ready: Bool
    }

    /// One enemy hold to take, the place to gather before it, and whether
    /// the army has gathered. A rising Moonspire is always the target;
    /// otherwise the nearest known enemy hold to this House's seat.
    func siegePlan(in state: GameState) -> Siege? {
        guard let seat = state.seat(of: house) else { return nil }
        let explored = state.houses[house].explored
        let enemyHolds = state.holds.filter { hold in
            hold.owner != house && state.isAtWar(house, hold.owner)
                && (state.map.index(of: hold.position).map { explored[$0] } ?? false)
        }
        let target: Hold?
        if let rising = spireThreat(in: state), state.isAtWar(house, rising), let spire = state.seat(of: rising) {
            target = spire
        } else {
            // Go for the weakest House within reach, to finish it, then
            // its nearest hold; and once far the stronger, for its seat,
            // whose fall shakes all the rest.
            let mine = state.strength(of: house)
            func cost(_ hold: Hold) -> Int {
                var cost = hold.position.distance(to: seat.position) + 4 * state.holds(of: hold.owner).count
                if hold.isSeat, mine * 10 > state.strength(of: hold.owner) * 18 { cost -= 8 }
                return cost
            }
            target = enemyHolds.min { (cost($0), $0.id) < (cost($1), $1.id) }
        }
        guard let target else { return nil }

        // Gather a few tiles short of it, on the way from home.
        let line = target.position.line(to: seat.position)
        let ideal = line[min(3, line.count - 1)]
        let muster = ideal.spiral(2).first { hex in
            guard let tile = state.map[hex], tile.terrain.isPassable else { return false }
            return state.hold(at: hex) == nil
        } ?? ideal

        let garrisons = Set(assignGarrisons(in: state).keys)
        let army = state.units(of: house).filter { $0.kind.isMilitary && !garrisons.contains($0.id) }
        let gathered = army.filter { $0.position.distance(to: target.position) <= RivalMind.siegeReach + 1 }.count
        let defenders = state.units.filter { $0.owner == target.owner && $0.kind.isMilitary && $0.position.distance(to: target.position) <= 2 }.count
        let needed = max(3, defenders + 2)
        let ready = target.ward == 0 || gathered >= needed || (gathered >= 2 && gathered == army.count && army.count >= defenders + 2)
        return Siege(target: target.position, muster: muster, ready: ready)
    }

    private func explore(with unit: Unit, in state: inout GameState) -> [GameEvent] {
        guard unit.destination == nil else { return [] }
        let explored = state.houses[house].explored
        let map = state.map
        let occupied = Set(state.units.map(\.position))
        // Known ruins first, then the nearest edge of the unknown.
        var seen: Set<Hex> = [unit.position]
        var queue = [unit.position]
        var head = 0
        var frontier: Hex?
        while head < queue.count, head < 2_500 {
            let hex = queue[head]
            head += 1
            if hex != unit.position, !occupied.contains(hex) {
                if map[hex]?.feature == .drownedRuin {
                    frontier = hex
                    break
                }
                if frontier == nil, map.neighbors(of: hex).contains(where: { !explored[map.index(of: $0)!] }) {
                    frontier = hex
                }
            }
            for next in map.neighbors(of: hex) where !seen.contains(next) {
                guard let tile = map[next], tile.terrain.isPassable else { continue }
                seen.insert(next)
                queue.append(next)
            }
            if frontier != nil, head > 400 { break }
        }
        if let frontier {
            return perform(.move(unit: unit.id, to: frontier), in: &state)
        }
        return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
    }

    private func settle(with unit: Unit, in state: inout GameState) -> [GameEvent] {
        if state.canFound(at: unit.position, for: house) == nil,
           let best = bestSite(from: unit.position, in: state),
           siteScore(unit.position, in: state) * 10 >= siteScore(best, in: state) * 8 {
            return perform(.found(unit: unit.id), in: &state)
        }
        guard let site = bestSite(from: unit.position, in: state) else { return [] }
        return perform(.move(unit: unit.id, to: site), in: &state)
    }

    /// The most promising place to found a hold that this House knows of.
    private func bestSite(from origin: Hex, in state: GameState) -> Hex? {
        let explored = state.houses[house].explored
        let owners = state.territory()
        let anchors = state.holds(of: house).map(\.position)
        var best: (score: Int, hex: Hex)?
        for anchor in anchors {
            for hex in anchor.spiral(9) {
                guard let index = state.map.index(of: hex), explored[index] else { continue }
                guard let tile = state.map[hex], tile.terrain.isSettleable else { continue }
                if owners[index].map({ state.hold($0)?.owner != house }) ?? false { continue }
                if state.holds.contains(where: { $0.position.distance(to: hex) < 4 }) { continue }
                if let other = state.unit(at: hex), other.owner != house { continue }
                let score = siteScore(hex, in: state) * 3 - hex.distance(to: origin)
                if best == nil || (score, hex) > (best!.score, best!.hex) {
                    best = (score, hex)
                }
            }
        }
        return best.map(\.hex)
    }

    private func siteScore(_ hex: Hex, in state: GameState) -> Int {
        hex.spiral(1).reduce(0) { total, cell in
            guard let tile = state.map[cell] else { return total }
            let yield = tile.yield
            return total + yield.grain + yield.timber + yield.stone + yield.moonsalt * 3
        }
    }

    private func enemyMilitary(near hex: Hex, within distance: Int, in state: GameState) -> Bool {
        state.units.contains { other in
            other.owner != house && other.kind.isMilitary && state.isAtWar(house, other.owner)
                && other.position.distance(to: hex) <= distance
        }
    }
}
