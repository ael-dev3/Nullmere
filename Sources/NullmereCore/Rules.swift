extension GameState {
    /// Carries out a House's command, or explains why it can't be done. A
    /// refused command changes nothing.
    @discardableResult
    public mutating func perform(_ command: Command, as house: Int) throws(RuleError) -> [GameEvent] {
        guard outcome == nil else { throw .gameOver }
        guard let actor = self.house(house), !actor.isEliminated else { throw .unknownHouse }

        switch command {
        case let .move(unitID, target):
            return try move(unitID, to: target, as: house)
        case let .attack(unitID, target):
            return try attack(with: unitID, at: target, as: house)
        case let .found(unitID):
            return try found(with: unitID, as: house)
        case let .build(holdID, kind):
            return try build(kind, in: holdID, as: house)
        case let .train(holdID, kind):
            return try train(kind, in: holdID, as: house)
        case let .barter(give, take, amount):
            return try barter(give: give, take: take, amount: amount, as: house)
        case let .fortify(unitID):
            let index = try ownedUnit(unitID, of: house)
            units[index].fortified = true
            units[index].movesLeft = 0
            units[index].destination = nil
            return []
        case let .disband(unitID):
            let index = try ownedUnit(unitID, of: house)
            let unit = units.remove(at: index)
            return [.unitLost(unit: unit.id, kind: unit.kind, owner: house, at: unit.position)]
        case let .halt(unitID):
            let index = try ownedUnit(unitID, of: house)
            units[index].destination = nil
            return []
        case let .declareWar(target):
            return try declareWar(by: house, on: target)
        case let .propose(proposal, target):
            return try propose(proposal, from: house, to: target)
        case let .proposeWithWords(proposal, target, words):
            return try propose(proposal, from: house, to: target, words: Envoy.carried(words))
        case let .answer(envoyID, accept):
            return try answer(envoyID, accept: accept, as: house)
        case let .gift(target, resource, amount):
            return try give(resource, amount: amount, from: house, to: target)
        case let .offerTrade(trade, target, words):
            return try offerTrade(trade, from: house, to: target, words: words.flatMap(Envoy.carried))
        }
    }

    // MARK: Units

    private func ownedUnit(_ id: Int, of house: Int) throws(RuleError) -> Int {
        guard let index = unitIndex(id) else { throw .unknownUnit }
        guard units[index].owner == house else { throw .notYours }
        return index
    }

    private func ownedHold(_ id: Int, of house: Int) throws(RuleError) -> Int {
        guard let index = holdIndex(id) else { throw .unknownHold }
        guard holds[index].owner == house else { throw .notYours }
        return index
    }

    /// Who stands at a hex for an attacker from `house`: a foreign unit or hold.
    func foe(at hex: Hex, for house: Int) -> (owner: Int, unit: Int?, hold: Int?)? {
        let standing = unit(at: hex).flatMap { $0.owner == house ? nil : $0 }
        let holding = hold(at: hex).flatMap { $0.owner == house ? nil : $0 }
        guard let owner = standing?.owner ?? holding?.owner else { return nil }
        return (owner, standing?.id, holding?.id)
    }

    private mutating func move(_ unitID: Int, to target: Hex, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        guard map.contains(target) else { throw .outsideTheWorld }
        // Ground not yet explored is ordered into as the keeper sees it:
        // the realm says nothing of what lies there, and the march goes as
        // near as it can come.
        let unknown = !isExplored(target, by: house)
        if !unknown {
            guard let tile = map[target], tile.terrain.isPassable else {
                throw .impassable(map[target]?.terrain ?? .spine)
            }
        }
        let unit = units[index]
        guard unit.position != target else { throw .alreadyThere }

        // Marching onto an enemy within reach is an attack.
        if let foe = foe(at: target, for: house), isAtWar(house, foe.owner), unit.kind.isMilitary,
           unit.position.distance(to: target) <= unit.kind.range {
            return try attack(with: unitID, at: target, as: house)
        }
        guard unknown || path(for: unit, to: target) != nil else { throw .noPath }
        units[index].destination = target
        units[index].fortified = false
        return march(unitID)
    }

    /// Moves a unit along its route as far as its moves allow this watch.
    /// The route is planned once: it steers round every other company, so
    /// only its end, the destination itself, can be held by another.
    mutating func march(_ unitID: Int) -> [GameEvent] {
        guard var index = unitIndex(unitID) else { return [] }
        var steps: [Hex] = []
        var events: [GameEvent] = []
        var route: [Hex] = []
        while let destination = units[index].destination, units[index].movesLeft > 0 {
            let unit = units[index]
            if route.isEmpty {
                // No way there: into ground still unknown to its House, it
                // goes as near as it can; known ground unreachable ends it.
                let way = path(for: unit, to: destination)
                    ?? (isExplored(destination, by: unit.owner) ? nil : approach(for: unit, toward: destination))
                guard let planned = way, !planned.isEmpty else {
                    units[index].destination = nil
                    break
                }
                route = planned
            }
            let next = route[0]
            // Another company holds the destination: wait beside it.
            if self.unit(at: next) != nil { break }
            if let hold = hold(at: next), hold.owner != unit.owner {
                units[index].destination = nil
                break
            }
            let cost = map[next]!.terrain.moveCost
            if unit.movesLeft < cost, unit.movesLeft < unit.kind.movement { break }
            route.removeFirst()
            units[index].movesLeft = max(0, unit.movesLeft - cost)
            units[index].position = next
            units[index].acted = true
            steps.append(next)
            reveal(around: next, range: sight(of: units[index]), for: unit.owner)
            if next == destination {
                units[index].destination = nil
            }
            if map[next]?.feature == .drownedRuin {
                events.append(searchRuin(at: next, by: unit.owner))
            }
            index = unitIndex(unitID)!
        }
        if !steps.isEmpty {
            events.insert(.moved(unit: unitID, path: steps), at: 0)
        }
        return events
    }

    /// Whether a House has explored a hex.
    func isExplored(_ hex: Hex, by house: Int) -> Bool {
        guard houses.indices.contains(house), let index = map.index(of: hex) else { return false }
        return houses[house].explored.indices.contains(index) && houses[house].explored[index]
    }

    mutating func reveal(around hex: Hex, range: Int, for house: Int) {
        guard houses.indices.contains(house) else { return }
        for cell in hex.spiral(range) {
            if let tileIndex = map.index(of: cell) {
                houses[house].explored[tileIndex] = true
            }
        }
    }

    private mutating func searchRuin(at hex: Hex, by house: Int) -> GameEvent {
        var random = random()
        let rewards = [
            Stock(moonsalt: 25), Stock(grain: 80), Stock(timber: 70), Stock(stone: 70),
            Stock(grain: 30, timber: 30, stone: 30, moonsalt: 10),
        ]
        let reward = random.pick(rewards)
        store(reward, for: house)
        if var tile = map[hex] {
            tile.feature = nil
            map.set(hex, tile)
        }
        record(.discovery, [house], "\(houses[house].title) searches a drowned ruin and recovers \(reward).")
        return .ruinSearched(at: hex, by: house, reward: reward)
    }

    // MARK: Fighting

    private mutating func attack(with unitID: Int, at target: Hex, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        let attacker = units[index]
        guard attacker.kind.isMilitary else { throw .cannotFight }
        guard attacker.movesLeft > 0 else { throw .noMovesLeft }
        guard let foe = foe(at: target, for: house) else { throw .nothingToAttack }
        guard isAtWar(house, foe.owner) else { throw .notAtWar(foe.owner) }
        guard attacker.position.distance(to: target) <= attacker.kind.range else { throw .outOfReach }

        units[index].movesLeft = 0
        units[index].acted = true
        units[index].fortified = false
        units[index].destination = nil

        if let defenderID = foe.unit {
            return fight(attacker: unitID, defender: defenderID, at: target)
        }
        return strike(hold: foe.hold!, with: unitID)
    }

    /// Two units exchange blows.
    private mutating func fight(attacker attackerID: Int, defender defenderID: Int, at hex: Hex) -> [GameEvent] {
        var random = random()
        let attacker = unit(attackerID)!
        let defender = unit(defenderID)!
        let ranged = attacker.position.distance(to: hex) > 1
        let (attack, defense) = strengths(of: attacker, against: defender, at: hex)

        let dealt = max(5, 70 * attack / (attack + defense) * random.int(in: 80...120) / 100)
        let taken = ranged ? 0 : 70 * defense / (attack + defense) * random.int(in: 80...120) / 100

        var events: [GameEvent] = []
        let defenderFell = applyDamage(dealt, to: defenderID, events: &events)
        let attackerFell = taken > 0 && applyDamage(taken, to: attackerID, events: &events)
        // Those who live through a battle learn from it.
        events += gainExperience(attackerID)
        events += gainExperience(defenderID)
        events.insert(.battle(Battle(
            attacker: attackerID, attackerOwner: attacker.owner, attackerKind: attacker.kind,
            defender: defenderID, defenderOwner: defender.owner, defenderKind: defender.kind,
            hold: nil, at: hex, damageDealt: dealt, damageTaken: taken,
            attackerFell: attackerFell, defenderFell: defenderFell
        )), at: 0)

        // The victor in close combat takes the field, unless a hold's ward still stands.
        if defenderFell, !attackerFell, !ranged, let index = unitIndex(attackerID) {
            if let hold = hold(at: hex) {
                if hold.ward == 0, attacker.kind.canCapture {
                    events += capture(hold: hold.id, with: attackerID)
                }
            } else if unit(at: hex) == nil {
                units[index].position = hex
                reveal(around: hex, range: omen?.kind == .risingMist ? max(1, attacker.kind.sight - 1) : attacker.kind.sight, for: attacker.owner)
            }
        }
        return events
    }

    /// Attack and defence in a fight between two units, before chance.
    func strengths(of attacker: Unit, against defender: Unit, at hex: Hex) -> (attack: Int, defense: Int) {
        var attack = attacker.kind.attack * (50 + attacker.health / 2) * (100 + Unit.rankBonus * attacker.rank) / 100
        if defender.kind == .rider {
            attack = attack * (100 + attacker.kind.bonusAgainstRiders) / 100
        }
        var defenseBonus = 100 + (map[hex]?.terrain.defenseBonus ?? 0) + (defender.fortified ? 25 : 0)
        if let hold = hold(at: hex), hold.owner == defender.owner {
            defenseBonus += Hold.garrisonBonus(wallLevel: hold.level(.walls))
        }
        if attacker.kind == .rider {
            defenseBonus += defender.kind.bonusAgainstRiders
        }
        let defense = max(1, defender.kind.defense * (50 + defender.health / 2) * defenseBonus / 100 * (100 + Unit.rankBonus * defender.rank) / 100)
        return (attack, defense)
    }

    private mutating func gainExperience(_ unitID: Int) -> [GameEvent] {
        guard let index = unitIndex(unitID) else { return [] }
        let rank = units[index].rank
        units[index].experience += 1
        guard units[index].rank > rank else { return [] }
        return [.promoted(unit: unitID, owner: units[index].owner, rank: units[index].rank)]
    }

    /// Returns whether the unit fell.
    private mutating func applyDamage(_ damage: Int, to unitID: Int, events: inout [GameEvent]) -> Bool {
        guard let index = unitIndex(unitID) else { return false }
        units[index].health -= damage
        guard units[index].health <= 0 else { return false }
        let unit = units.remove(at: index)
        events.append(.unitLost(unit: unit.id, kind: unit.kind, owner: unit.owner, at: unit.position))
        return true
    }

    /// A unit strikes an ungarrisoned hold's ward, and takes the hold if the
    /// ward breaks and it can.
    private mutating func strike(hold holdID: Int, with unitID: Int) -> [GameEvent] {
        var random = random()
        let attacker = unit(unitID)!
        let holdIndex = holdIndex(holdID)!
        let hold = holds[holdIndex]
        let ranged = attacker.position.distance(to: hold.position) > 1

        let damage = Hold.strikeDamage(attack: attacker.kind.attack, health: attacker.health) * random.int(in: 80...120) / 100
        holds[holdIndex].ward = max(0, hold.ward - damage)
        holds[holdIndex].struck = true
        var events: [GameEvent] = [.holdStruck(hold: holdID, ward: holds[holdIndex].ward)]

        let returned = ranged ? 0 : 5 + 4 * hold.level(.walls)
        let attackerFell = returned > 0 && applyDamage(returned, to: unitID, events: &events)
        events.insert(.battle(Battle(
            attacker: unitID, attackerOwner: attacker.owner, attackerKind: attacker.kind,
            defender: nil, defenderOwner: hold.owner, defenderKind: nil,
            hold: holdID, at: hold.position, damageDealt: damage, damageTaken: returned,
            attackerFell: attackerFell, defenderFell: holds[holdIndex].ward == 0
        )), at: 0)

        if holds[holdIndex].ward == 0, !attackerFell, !ranged, attacker.kind.canCapture {
            events += capture(hold: holdID, with: unitID)
        }
        return events
    }

    private mutating func capture(hold holdID: Int, with unitID: Int) -> [GameEvent] {
        guard let holdIndex = holdIndex(holdID), let unitIndex = unitIndex(unitID) else { return [] }
        let previous = holds[holdIndex].owner
        let taker = units[unitIndex].owner
        let wasSeat = holds[holdIndex].isSeat
        let name = holds[holdIndex].name
        // The taker carries off the hold's share of its House's stores; a
        // seat holds half of them.
        let plunder = houses[previous].stock.share(1, of: wasSeat ? 2 : max(holds(of: previous).count, 1))
        houses[previous].stock.debit(plunder)
        store(plunder, for: taker)

        holds[holdIndex].owner = taker
        holds[holdIndex].isSeat = false
        holds[holdIndex].project = nil
        holds[holdIndex].training = nil
        holds[holdIndex].levels[.moonspire] = nil
        holds[holdIndex].ward = holds[holdIndex].maximumWard / 4
        units[unitIndex].position = holds[holdIndex].position
        reveal(around: holds[holdIndex].position, range: sight(of: holds[holdIndex]), for: taker)

        var events: [GameEvent] = [.holdCaptured(hold: holdID, from: previous, by: taker)]
        let seatWords = wasSeat ? ", the seat of \(houses[previous].title)," : ""
        let spoils = plunder.isZero ? "" : ", and carries off its stores"
        record(.capture, [taker, previous], "\(houses[taker].title) takes \(name)\(seatWords) from \(houses[previous].title)\(spoils).")

        let remaining = holds(of: previous).sorted { ($0.foundedWatch, $0.id) < ($1.foundedWatch, $1.id) }
        if remaining.isEmpty {
            events += eliminate(previous, by: taker)
        } else if wasSeat, let heir = remaining.first, let heirIndex = self.holdIndex(heir.id) {
            holds[heirIndex].isSeat = true
            // The fall of a seat breaks a House: every hold it has left is
            // shaken, its ward down to a third.
            for hold in remaining {
                if let index = self.holdIndex(hold.id) {
                    holds[index].ward = min(holds[index].ward, holds[index].maximumWard / 3)
                }
            }
            events.append(.seatMoved(house: previous, to: heir.id))
            record(.fall, [previous], "\(houses[previous].title) loses its seat and is shaken; it moves to \(heir.name).")
            // A rival House left with little beyond its lost seat bends the
            // knee to the one that took it, rather than fall.
            if remaining.count <= GameState.brokenAtHolds, !houses[previous].isPlayer,
               houses[previous].liege == nil, houses[taker].liege == nil,
               !houses.contains(where: { $0.liege == previous }) {
                settle(.fealty, between: previous, and: taker, by: previous)
                events.append(.stanceChanged(first: previous, second: taker, stance: .pact, by: previous))
            }
        }
        return events
    }

    /// A rival House that loses its seat with this many holds or fewer
    /// left swears fealty to the House that took it.
    public static let brokenAtHolds = 4

    mutating func eliminate(_ house: Int, by conqueror: Int) -> [GameEvent] {
        guard !houses[house].isEliminated else { return [] }
        houses[house].isEliminated = true
        houses[house].liege = nil
        // Its pacts end with it: a fallen House sees through no ally's eyes.
        for index in relations.indices where relations[index].first == house || relations[index].second == house {
            if relations[index].stance == .pact { relations[index].stance = .peace }
        }
        // A fallen liege's vassals are free again.
        for index in houses.indices where houses[index].liege == house {
            houses[index].liege = nil
        }
        units.removeAll { $0.owner == house }
        envoys.removeAll { $0.from == house || $0.to == house }
        record(.fall, [house, conqueror], "\(houses[house].title) falls to \(houses[conqueror].title). Its name passes into the chronicle.")
        return [.houseFell(house)]
    }

    // MARK: Holds

    /// Whether a hold can be founded at a hex by a House, or why not.
    public func canFound(at hex: Hex, for house: Int) -> RuleError? {
        guard let tile = map[hex] else { return .outsideTheWorld }
        guard tile.terrain.isSettleable else { return .cannotSettle(tile.terrain) }
        if holds.contains(where: { $0.position.distance(to: hex) < 3 }) { return .tooCloseToHold }
        if let owner = territoryOwner(of: hex), owner != house { return .foreignTerritory }
        return nil
    }

    private mutating func found(with unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        let founder = units[index]
        guard founder.kind == .founder else { throw .notAFounder }
        if let problem = canFound(at: founder.position, for: house) { throw problem }

        var random = random()
        let name = Names.hold(using: &random, avoiding: Set(holds.map(\.name)))
        let hold = Hold(id: takeID(), name: name, owner: house, position: founder.position, isSeat: false, foundedWatch: watch)
        holds.append(hold)
        units.remove(at: index)
        reveal(around: hold.position, range: sight(of: hold), for: house)
        record(.founding, [house], "\(houses[house].title) founds \(name) on the \(map[hold.position]!.terrain.title.lowercased()).")
        return [.holdFounded(hold: hold.id)]
    }

    /// The cost of raising a building one level in a hold, or nil at its top.
    public func nextLevelCost(of kind: BuildingKind, in hold: Hold) -> Stock? {
        let next = hold.level(kind) + 1
        guard next <= kind.maxLevel else { return nil }
        return kind.cost(toLevel: next)
    }

    private mutating func build(_ kind: BuildingKind, in holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedHold(holdID, of: house)
        let hold = holds[index]
        guard hold.project == nil else { throw .busy }
        if kind.requiresSeat, !hold.isSeat { throw .seatOnly }
        let level = hold.level(kind) + 1
        guard level <= kind.maxLevel else { throw .maxLevel }
        let cost = kind.cost(toLevel: level)
        guard houses[house].stock.covers(cost) else { throw .shortOf(houses[house].stock.shortfall(for: cost)) }

        houses[house].stock.debit(cost)
        holds[index].project = Hold.Project(kind: kind, targetLevel: level, watchesLeft: kind.buildWatches(toLevel: level))
        return [.buildingStarted(hold: holdID, kind: kind, level: level)]
    }

    /// What a company costs this House to muster. Founders cost half as
    /// much again for every hold the House has beyond its seat, and every
    /// Founder already on the march or mustering, so each new hold is
    /// dearer than the last and a realm can't sprawl for nothing.
    public func trainingCost(of kind: UnitKind, for house: Int) -> Stock {
        guard kind == .founder else { return kind.cost }
        let mustering = holds.filter { $0.owner == house && $0.training?.kind == .founder }.count
        let marching = units.filter { $0.owner == house && $0.kind == .founder }.count
        let extra = max(0, holds(of: house).count - 1) + mustering + marching
        return kind.cost.scaled(percent: 100 + 50 * extra)
    }

    private mutating func train(_ kind: UnitKind, in holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedHold(holdID, of: house)
        let hold = holds[index]
        guard hold.training == nil else { throw .busy }
        guard hold.level(.musterHall) >= kind.requiredMuster else { throw .needsMusterHall(kind.requiredMuster) }
        let cost = trainingCost(of: kind, for: house)
        guard houses[house].stock.covers(cost) else { throw .shortOf(houses[house].stock.shortfall(for: cost)) }

        houses[house].stock.debit(cost)
        holds[index].training = Hold.Training(kind: kind, watchesLeft: hold.trainingWatches(for: kind))
        return [.trainingStarted(hold: holdID, kind: kind)]
    }

    // MARK: Barter

    private mutating func barter(give: Resource, take: Resource, amount: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        guard give != take else { throw .sameStore }
        guard amount > 0, amount <= Stock.cap else { throw .invalidAmount }
        let price = take.barterCost(of: amount, paidIn: give)
        var cost = Stock()
        cost[give] = price
        guard houses[house].stock.covers(cost) else { throw .shortOf(houses[house].stock.shortfall(for: cost)) }
        guard houses[house].stock[take] + amount <= storage(of: house) else { throw .storageFull }
        var gain = Stock()
        gain[take] = amount
        houses[house].stock.debit(cost)
        houses[house].stock.credit(gain)
        return [.bartered(house: house, gave: cost, took: gain)]
    }

    // MARK: Diplomacy

    private func requireRival(_ target: Int, of house: Int) throws(RuleError) {
        guard target != house, let other = self.house(target), !other.isEliminated else { throw .unknownHouse }
    }

    mutating func declareWar(by house: Int, on target: Int, fearingSpire: Bool = false) throws(RuleError) -> [GameEvent] {
        try requireRival(target, of: house)
        let previous = stance(house, target)
        guard previous != .war else { throw .alreadyStance(.war) }
        // A vassal can't turn on its liege; a liege that turns on its
        // vassal frees it.
        guard houses[house].liege != target else { throw .notApplicable }
        if houses[target].liege == house {
            houses[target].liege = nil
        }
        setStance(.war, between: house, and: target, by: house)
        // War throws away what gifts bought: the goodwill of every gift the
        // declarer sent the House it turns on is forfeit.
        if var sent = gifts {
            for index in sent.indices where sent[index].from == house && sent[index].to == target {
                sent[index].forfeit = true
            }
            gifts = sent
        }
        envoys.removeAll { ($0.from == target && $0.to == house) || ($0.from == house && $0.to == target) }
        if fearingSpire {
            record(.war, [house, target], "Fearing the white tower rising at \(seat(of: target)?.name ?? "their seat"), \(houses[house].title) goes to war against \(houses[target].title).")
        } else if previous == .pact {
            record(.betrayal, [house, target], "\(houses[house].title) breaks its pact and turns on \(houses[target].title).")
        } else {
            record(.war, [house, target], "\(houses[house].title) declares war on \(houses[target].title).")
        }
        return [.stanceChanged(first: house, second: target, stance: .war, by: house)]
    }

    mutating func propose(_ proposal: Proposal, from house: Int, to target: Int, words: String? = nil) throws(RuleError) -> [GameEvent] {
        try requireRival(target, of: house)
        let current = stance(house, target)
        switch proposal {
        case .peace:
            guard current == .war else { throw current == .pact ? .alreadyStance(.pact) : .alreadyStance(.peace) }
        case .pact:
            guard current == .peace else { throw current == .pact ? .alreadyStance(.pact) : .notApplicable }
        case .fealty:
            // A liege of others can't bend the knee itself.
            guard houses[house].liege == nil, houses[target].liege == nil, !houses[house].isPlayer,
                  !houses.contains(where: { $0.liege == house }) else { throw .notApplicable }
        case .trade:
            // A trade goes with its terms, by `offerTrade`.
            throw .notApplicable
        case .tribute:
            guard current == .peace else { throw current == .pact ? .alreadyStance(.pact) : .notApplicable }
            guard houses[house].liege != target, houses[target].liege != house, !paidTributeLately(house, target),
                  !refusedTributeLately(house, target) else {
                throw .notApplicable
            }
        }

        if houses[target].isPlayer {
            // One envoy of each kind on the road between two Houses.
            guard !envoys.contains(where: { $0.from == house && $0.to == target && $0.proposal == proposal }) else {
                throw .envoyWaiting
            }
            // Words go only between keepers: a steward has no use for them.
            let envoy = Envoy(id: takeID(), from: house, to: target, proposal: proposal, arrived: watch,
                              words: houses[house].isPlayer ? words : nil)
            envoys.append(envoy)
            return [.envoyArrived(envoy)]
        }

        let accepted = RivalMind(house: target).accepts(proposal, from: house, in: self)
        if accepted {
            settle(proposal, between: house, and: target, by: house)
        }
        var events: [GameEvent] = [.proposalAnswered(proposal: proposal, from: house, to: target, accepted: accepted)]
        if !accepted, proposal == .tribute {
            events += refuseTribute(demandedBy: house, of: target)
        }
        return events
    }

    private mutating func answer(_ envoyID: Int, accept: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let index = envoys.firstIndex(where: { $0.id == envoyID && $0.to == house }), houses[house].isPlayer else { throw .unknownEnvoy }
        let envoy = envoys.remove(at: index)
        if envoy.proposal == .trade { return answerTrade(envoy, accept: accept, as: house) }
        let stillValid: Bool
        switch envoy.proposal {
        case .trade: stillValid = false
        case .peace: stillValid = stance(house, envoy.from) == .war
        case .pact: stillValid = stance(house, envoy.from) == .peace
        // A House a keeper has since taken up never bends the knee for them.
        case .fealty: stillValid = houses[envoy.from].liege == nil && houses[house].liege == nil && !houses[envoy.from].isPlayer
            && !houses.contains(where: { $0.liege == envoy.from })
        case .tribute: stillValid = stance(house, envoy.from) == .peace
        }
        let accepted = accept && stillValid && !houses[envoy.from].isEliminated
        if accepted {
            settle(envoy.proposal, between: envoy.from, and: house, by: envoy.from)
        }
        var events: [GameEvent] = [.proposalAnswered(proposal: envoy.proposal, from: envoy.from, to: house, accepted: accepted)]
        if !accepted, envoy.proposal == .tribute, stillValid, !houses[envoy.from].isEliminated {
            events += refuseTribute(demandedBy: envoy.from, of: house)
        }
        return events
    }

    mutating func settle(_ proposal: Proposal, between proposer: Int, and other: Int, by actor: Int) {
        switch proposal {
        case .trade:
            break
        case .peace:
            setStance(.peace, between: proposer, and: other, by: actor)
            record(.peace, [proposer, other], "\(houses[proposer].title) and \(houses[other].title) make peace.")
        case .pact:
            setStance(.pact, between: proposer, and: other, by: actor)
            record(.pact, [proposer, other], "\(houses[proposer].title) and \(houses[other].title) swear a pact.")
        case .fealty:
            setStance(.pact, between: proposer, and: other, by: actor)
            houses[proposer].liege = other
            record(.pact, [proposer, other], "\(houses[proposer].title) bends the knee and swears fealty to \(houses[other].title).")
        case .tribute:
            let paid = tribute(from: other)
            houses[other].stock.debit(paid)
            // What the demander has no room for is lost on the road.
            store(paid, for: proposer)
            if let index = relations.firstIndex(where: { $0.first == min(proposer, other) && $0.second == max(proposer, other) }) {
                relations[index].tributePaid = watch
            }
            record(.tribute, [other, proposer], "\(houses[other].title) pays tribute to \(houses[proposer].title): \(paid).")
        }
    }

    /// What a House would pay in tribute: a fifth of its stores.
    public func tribute(from payer: Int) -> Stock {
        houses[payer].stock.share(1, of: 5)
    }

    /// Watches a paid tribute keeps the peace.
    public static let tributeRespite = 20

    /// Whether tribute passed between two Houses within the respite.
    public func paidTributeLately(_ a: Int, _ b: Int) -> Bool {
        guard let paid = relation(a, b)?.tributePaid else { return false }
        return watch - paid < GameState.tributeRespite
    }

    /// Watches before a refused demand can be made again.
    public static let tributeRefusedRespite = 5

    /// Whether a demand for tribute between two Houses was refused lately.
    public func refusedTributeLately(_ a: Int, _ b: Int) -> Bool {
        guard let refused = relation(a, b)?.tributeRefused else { return false }
        return watch - refused < GameState.tributeRefusedRespite
    }

    /// A refused demand: a rival that demanded marches; the player who
    /// demanded is only refused, and can't demand again for a while.
    mutating func refuseTribute(demandedBy demander: Int, of refuser: Int) -> [GameEvent] {
        if let index = relations.firstIndex(where: { $0.first == min(demander, refuser) && $0.second == max(demander, refuser) }) {
            relations[index].tributeRefused = watch
        }
        record(.tribute, [refuser, demander], "\(houses[refuser].title) refuses tribute to \(houses[demander].title).")
        guard !houses[demander].isPlayer else { return [] }
        return (try? declareWar(by: demander, on: refuser)) ?? []
    }
}
