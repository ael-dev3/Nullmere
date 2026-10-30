extension GameState {
    /// Carries out a House's command, or explains why it can't be done. A
    /// refused command changes nothing.
    @discardableResult
    public mutating func perform(_ command: Command, as house: Int) throws(RuleError) -> [GameEvent] {
        guard outcome == nil else { throw .gameOver }
        guard let actor = self.house(house), !actor.isEliminated else { throw .unknownHouse }
        let events = try carryOut(command, as: house)
        // What it did counts to the happening under way, and may be a deed.
        tally(events)
        noteDeeds(events)
        return events
    }

    private mutating func carryOut(_ command: Command, as house: Int) throws(RuleError) -> [GameEvent] {
        switch command {
        case let .move(unitID, target):
            return try move(unitID, to: target, as: house)
        case let .attack(unitID, target):
            return try attack(with: unitID, at: target, as: house)
        case let .found(unitID):
            return try found(with: unitID, as: house)
        case let .build(holdID, kind):
            return try build(kind, in: holdID, as: house)
        case let .train(holdID, kind, tier):
            return try train(kind, tier: tier ?? 1, in: holdID, as: house)
        case let .barter(give, take, amount):
            return try barter(give: give, take: take, amount: amount, as: house)
        case let .fortify(unitID):
            let index = try ownedUnit(unitID, of: house)
            units[index].fortified = true
            units[index].movesLeft = 0
            units[index].destination = nil
            // Digging in at an ally's gates is keeping them still.
            if case .reinforce? = units[index].errand {} else { units[index].errand = nil }
            return []
        case let .disband(unitID):
            let index = try ownedUnit(unitID, of: house)
            let unit = units.remove(at: index)
            return [.unitLost(unit: unit.id, kind: unit.kind, owner: house, at: unit.position)]
        case let .halt(unitID):
            let index = try ownedUnit(unitID, of: house)
            units[index].destination = nil
            units[index].errand = nil
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
        case let .study(study):
            return try beginStudy(study, as: house)
        case let .assign(commanderID, unitID):
            return try assign(commanderID, to: unitID, as: house)
        case let .unassign(commanderID):
            return try unassign(commanderID, as: house)
        case let .gather(unitID, siteID):
            return try gather(unitID, at: siteID, as: house)
        case let .foundAlliance(name):
            return try foundAlliance(named: name, by: house)
        case let .say(words, toAlliance):
            return try say(words, toAlliance: toAlliance, as: house)
        case let .learnTalent(commanderID, talent):
            return try learn(talent, by: commanderID, as: house)
        case let .forgetTalents(commanderID):
            return try forgetTalents(of: commanderID, as: house)
        case let .wear(gearID, commanderID):
            return try wear(gearID, on: commanderID, as: house)
        case let .takeOff(gearID):
            return try takeOff(gearID, as: house)
        case let .breakUp(gearID):
            return try breakUp(gearID, as: house)
        case let .heal(holdID):
            return try heal(at: holdID, as: house)
        case let .scout(unitID, holdID):
            return try scout(holdID, with: unitID, as: house)
        case let .raiseStandard(hex):
            return try raiseStandard(at: hex, by: house)
        case let .useItem(kind, holdID):
            return try use(kind, on: holdID, as: house)
        case let .takeHeritage(heritage):
            return try takeUp(heritage, as: house)
        case let .pursueAllianceStudy(study):
            return try pursue(study, by: house)
        case let .giveToAlliance(stock):
            return try giveToAlliance(stock, by: house)
        case let .raiseAllianceHall(hex):
            return try raiseHall(at: hex, by: house)
        case let .forge(kind, quality):
            return try forge(kind, quality, by: house)
        case let .raiseStorehouse(hex):
            return try raiseStorehouse(at: hex, by: house)
        case let .layUp(stock):
            return try layUp(stock, by: house)
        case let .takeBack(stock):
            return try takeBack(stock, by: house)
        case let .raiseYard(store, hex):
            return try raiseYard(store, at: hex, by: house)
        case let .inviteToAlliance(target):
            return try invite(target, by: house)
        case let .askToJoin(allianceID):
            return try askToJoin(allianceID, by: house)
        case let .answerInvitation(allianceID, accept):
            return try answerInvitation(allianceID, accept: accept, as: house)
        case let .answerRequest(asker, accept):
            return try answerRequest(of: asker, accept: accept, as: house)
        case .leaveAlliance:
            return try leaveAlliance(as: house)
        case let .expel(target):
            return try expel(target, by: house)
        case let .help(ally):
            return try help(ally, by: house)
        case let .callRally(holdID, targetID, watches):
            return try callRally(from: holdID, against: targetID, gathering: watches, by: house)
        case let .joinRally(rallyID, unitID):
            return try joinRally(rallyID, with: unitID, as: house)
        case let .reinforce(unitID, holdID):
            return try reinforce(holdID, with: unitID, as: house)
        }
    }

    // MARK: Units

    func ownedUnit(_ id: Int, of house: Int) throws(RuleError) -> Int {
        guard let index = unitIndex(id) else { throw .unknownUnit }
        guard units[index].owner == house else { throw .notYours }
        return index
    }

    func ownedHold(_ id: Int, of house: Int) throws(RuleError) -> Int {
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

        // Marching onto an enemy within reach is an attack, and onto the wilds.
        if unit.kind.isMilitary, unit.position.distance(to: target) <= unit.kind.range,
           wild(at: target) != nil || lair(at: target) != nil || foe(at: target, for: house).map({ isAtWar(house, $0.owner) }) == true
            || (self.unit(at: target) == nil && standard(at: target).map { isAtWar(house, $0.raisedBy) } == true)
            || (self.unit(at: target) == nil && hall(at: target).map { isFoe(house, of: $0) } == true)
            || (self.unit(at: target) == nil && storehouse(at: target).map { isFoe(house, ofAlliance: $0.alliance) } == true) {
            return try attack(with: unitID, at: target, as: house)
        }
        guard unknown || path(for: unit, to: target) != nil else { throw .noPath }
        units[index].destination = target
        units[index].fortified = false
        // A new march is a new order: whatever errand it was on is done with.
        units[index].errand = nil
        return march(unitID)
    }

    /// Moves a unit along its route as far as its moves allow this watch,
    /// or, at a pace, keeping back so many of them for the paces to come.
    /// The route is planned once: it steers round every other company, so
    /// only its end, the destination itself, can be held by another.
    mutating func march(_ unitID: Int, keeping reserve: Int? = nil) -> [GameEvent] {
        guard var index = unitIndex(unitID) else { return [] }
        var steps: [Hex] = []
        var events: [GameEvent] = []
        var route: [Hex] = []
        while let destination = units[index].destination, units[index].movesLeft > max(reserve ?? 0, 0) {
            let unit = units[index]
            if route.isEmpty {
                // No way there: into ground still unknown to its House, it
                // goes as near as it can; known ground unreachable ends it,
                // as the watch turns. At a pace, a way shut for a while
                // (a company standing in a pass) is waited out.
                let way = path(for: unit, to: destination)
                    ?? (isExplored(destination, by: unit.owner) ? nil : approach(for: unit, toward: destination))
                guard let planned = way, !planned.isEmpty else {
                    if reserve == nil { units[index].destination = nil }
                    break
                }
                route = planned
            }
            let next = route[0]
            // Another company holds the destination, or the wilds or their lair: wait beside it.
            if self.unit(at: next) != nil || wild(at: next) != nil || lair(at: next) != nil { break }
            if let hold = hold(at: next), hold.owner != unit.owner {
                units[index].destination = nil
                break
            }
            // Only its alliance's companies enter a hall, or a storehouse.
            if let hall = hall(at: next), !isOfHall(unit.owner, hall) {
                units[index].destination = nil
                break
            }
            if let storehouse = storehouse(at: next), !isOf(storehouse.alliance, unit.owner) {
                units[index].destination = nil
                break
            }
            let cost = map[next]!.terrain.moveCost
            if unit.movesLeft < cost, unit.movesLeft < movement(of: unit) { break }
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
        // A lair stands against any company alone.
        if lair(at: target) != nil { throw .lairNeedsRally }
        // A standard of a House at war, with no company standing on it.
        if unit(at: target) == nil, let standard = standard(at: target), standard.raisedBy != house {
            guard isAtWar(house, standard.raisedBy) else { throw .notAtWar(standard.raisedBy) }
            guard attacker.position.distance(to: target) <= attacker.kind.range else { throw .outOfReach }
            return strike(standard: standard.id, with: unitID)
        }
        // An alliance's hall with no company keeping it.
        if unit(at: target) == nil, let hall = hall(at: target), !isOfHall(house, hall) {
            guard isFoe(house, of: hall) else { throw .notAtWar(alliance(hall.alliance)?.leader ?? hall.raisedBy) }
            guard attacker.position.distance(to: target) <= attacker.kind.range else { throw .outOfReach }
            return strike(hall: hall.id, with: unitID)
        }
        // An alliance's storehouse with no company keeping it.
        if unit(at: target) == nil, let storehouse = storehouse(at: target), !isOf(storehouse.alliance, house) {
            guard isFoe(house, ofAlliance: storehouse.alliance) else {
                throw .notAtWar(alliance(storehouse.alliance)?.leader ?? storehouse.raisedBy)
            }
            guard attacker.position.distance(to: target) <= attacker.kind.range else { throw .outOfReach }
            return strike(storehouse: storehouse.id, with: unitID)
        }
        // The wilds are every House's foe: no war is needed to strike them.
        if let wild = wild(at: target) {
            guard attacker.position.distance(to: target) <= attacker.kind.range else { throw .outOfReach }
            units[index].movesLeft = 0
            units[index].acted = true
            units[index].fortified = false
            units[index].destination = nil
            units[index].errand = nil
            return strike(wild: wild.id, with: unitID)
        }
        guard let foe = foe(at: target, for: house) else { throw .nothingToAttack }
        guard isAtWar(house, foe.owner) else { throw .notAtWar(foe.owner) }
        guard attacker.position.distance(to: target) <= attacker.kind.range else { throw .outOfReach }
        return assault(with: unitID, at: target)
    }

    /// A company strikes the foe at a hex, its moves spent and whatever it
    /// was about done with: the company standing there, or else the hold's
    /// ward. Companies keeping the gates of a hold struck strike back.
    mutating func assault(with unitID: Int, at target: Hex) -> [GameEvent] {
        guard let index = unitIndex(unitID), let foe = foe(at: target, for: units[index].owner) else { return [] }
        units[index].movesLeft = 0
        units[index].acted = true
        units[index].fortified = false
        units[index].destination = nil
        units[index].errand = nil

        var events: [GameEvent]
        if let defenderID = foe.unit {
            events = fight(attacker: unitID, defender: defenderID, at: target)
            // In a realm, the battle goes on through the watch while both stand.
            if let attacker = unit(unitID), let defender = unit(defenderID) { join(attacker, against: defender) }
        } else {
            events = strike(hold: foe.hold!, with: unitID)
        }
        if let held = foe.hold {
            events += sally(against: unitID, striking: held)
        }
        return events
    }

    /// Companies keeping the gates of a hold for an ally strike back, from
    /// where they stand, at a company of a House at war with their own
    /// that strikes it, while it still stands and the hold is still their
    /// ally's.
    private mutating func sally(against strikerID: Int, striking holdID: Int) -> [GameEvent] {
        guard let hold = hold(holdID) else { return [] }
        let keepers = units.filter { $0.errand == .reinforce(hold: holdID) && $0.position.distance(to: hold.position) <= 1 }
            .map(\.id).sorted()
        var events: [GameEvent] = []
        for id in keepers {
            guard let striker = unit(strikerID), let keeper = unit(id), let held = self.hold(holdID), areAllied(keeper.owner, held.owner),
                  isAtWar(keeper.owner, striker.owner), keeper.position.distance(to: striker.position) <= keeper.kind.range else { continue }
            events += fight(attacker: id, defender: strikerID, at: striker.position, holdingGround: true)
        }
        return events
    }

    /// Another exchange of blows in a battle going on.
    mutating func exchange(attacker attackerID: Int, defender defenderID: Int, at hex: Hex) -> [GameEvent] {
        fight(attacker: attackerID, defender: defenderID, at: hex)
    }

    /// Two units exchange blows. A company holding its ground never steps
    /// onto the fallen's.
    private mutating func fight(attacker attackerID: Int, defender defenderID: Int, at hex: Hex, holdingGround: Bool = false) -> [GameEvent] {
        var random = random()
        let attacker = unit(attackerID)!
        let defender = unit(defenderID)!
        let ranged = attacker.position.distance(to: hex) > 1
        let (attack, defense) = strengths(of: attacker, against: defender, at: hex)
        // A commander whose fury is ready fires its skill in this battle.
        let attackerFired = furyReady(of: attacker), defenderFired = furyReady(of: defender)
        let attackerFury = fury(of: attacker), defenderFury = fury(of: defender)

        let dealt = bodily(GameState.furious(max(5, 70 * attack / (attack + defense) * random.int(in: 80...120) / 100),
                                             dealtBy: attackerFury, takenBy: defenderFury), on: defender)
        let taken = ranged ? 0 : bodily(GameState.furious(70 * defense / (attack + defense) * random.int(in: 80...120) / 100,
                                                          dealtBy: defenderFury, takenBy: attackerFury), on: attacker)

        var events: [GameEvent] = []
        let defenderFell = applyDamage(dealt, to: defenderID, events: &events)
        let attackerFell = taken > 0 && applyDamage(taken, to: attackerID, events: &events)
        // A company that falls carrying the land's stores leaves half of
        // them to its foe, if its foe lives.
        if defenderFell, !attackerFell, let load = defender.load, !load.isZero {
            store(load.share(1, of: 2), for: attacker.owner)
        }
        // Those who live through a battle learn from it.
        events += gainExperience(attackerID)
        events += gainExperience(defenderID)
        events += stirCommanders([
            Stir(unit: attacker, fired: attackerFired, fell: attackerFell, experience: GameState.battleExperience(dealt: dealt, felled: defenderFell)),
            Stir(unit: defender, fired: defenderFired, fell: defenderFell, experience: GameState.battleExperience(dealt: taken, felled: attackerFell)),
        ], at: hex)
        events.insert(.battle(Battle(
            attacker: attackerID, attackerOwner: attacker.owner, attackerKind: attacker.kind,
            defender: defenderID, defenderOwner: defender.owner, defenderKind: defender.kind,
            hold: nil, at: hex, damageDealt: dealt, damageTaken: taken,
            attackerFell: attackerFell, defenderFell: defenderFell
        )), at: 0)

        // The victor in close combat takes the field, unless a hold's ward
        // still stands, or it fought from within its own hold.
        if defenderFell, !attackerFell, !ranged, !holdingGround, let index = unitIndex(attackerID) {
            if let hold = hold(at: hex) {
                if hold.ward == 0, attacker.kind.canCapture {
                    events += capture(hold: hold.id, with: attackerID)
                }
            } else if unit(at: hex) == nil, takesTheField(attacker, at: hex) {
                units[index].position = hex
                reveal(around: hex, range: omen?.kind == .risingMist ? max(1, attacker.kind.sight - 1) : attacker.kind.sight, for: attacker.owner)
            }
        }
        return events
    }

    /// Whether a company that wins a close fight here steps onto the
    /// fallen's ground: only out in the field. A garrison holds its
    /// ground, so no foe dying at its gates can empty its hold.
    func takesTheField(_ attacker: Unit, at hex: Hex) -> Bool {
        attacker.position.distance(to: hex) == 1 && hold(at: attacker.position) == nil && hold(at: hex) == nil
            && hall(at: hex).map { isOfHall(attacker.owner, $0) } != false
            && storehouse(at: hex).map { isOf($0.alliance, attacker.owner) } != false
    }

    /// Attack and defence in a fight between two units, before chance.
    func strengths(of attacker: Unit, against defender: Unit, at hex: Hex) -> (attack: Int, defense: Int) {
        var attack = attacker.kind.attack * (50 + attacker.health / 2) * (100 + Unit.rankBonus * attacker.rank) / 100
        attack = attack * attackPercent(of: attacker) / 100
        if defender.kind == .rider {
            attack = attack * (100 + attacker.kind.bonusAgainstRiders) / 100
        }
        var defenseBonus = 100 + (map[hex]?.terrain.defenseBonus ?? 0) + (defender.fortified ? 25 : 0)
            + (isOnOwnLand(defender) ? Standard.defence : 0)
        if let hold = hold(at: hex), hold.owner == defender.owner {
            defenseBonus += Hold.garrisonBonus(wallLevel: hold.level(.walls)) + bonus(.garrison, for: defender)
        }
        if let hall = hall(at: hex), hall.isWhole, isOfHall(defender.owner, hall) {
            defenseBonus += AllianceHall.garrison
        }
        if attacker.kind == .rider {
            defenseBonus += defender.kind.bonusAgainstRiders
        }
        let defense = max(1, defender.kind.defense * (50 + defender.health / 2) * defenseBonus / 100 * (100 + Unit.rankBonus * defender.rank) / 100
            * defensePercent(of: defender) / 100)
        return (attack, defense)
    }

    mutating func gainExperience(_ unitID: Int) -> [GameEvent] {
        guard let index = unitIndex(unitID) else { return [] }
        let rank = units[index].rank
        units[index].experience += 1
        guard units[index].rank > rank else { return [] }
        return [.promoted(unit: unitID, owner: units[index].owner, rank: units[index].rank)]
    }

    /// Returns whether the unit fell.
    mutating func applyDamage(_ damage: Int, to unitID: Int, events: inout [GameEvent]) -> Bool {
        guard let index = unitIndex(unitID) else { return false }
        units[index].health -= damage
        guard units[index].health <= 0 else { return false }
        let unit = units.remove(at: index)
        events.append(.unitLost(unit: unit.id, kind: unit.kind, owner: unit.owner, at: unit.position))
        events += woundCommander(of: unit)
        events += carryToInfirmary(unit)
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
        let fired = furyReady(of: attacker)
        let furyOf = fury(of: attacker)

        let damage = GameState.furious(wardDamage(by: attacker) * random.int(in: 80...120) / 100, dealtBy: furyOf, takenBy: GameState.calm)
        holds[holdIndex].ward = max(0, hold.ward - damage)
        holds[holdIndex].struck = true
        var events: [GameEvent] = [.holdStruck(hold: holdID, ward: holds[holdIndex].ward)]

        let returned = ranged ? 0 : GameState.furious(bodily(5 + 4 * hold.level(.walls), on: attacker), dealtBy: GameState.calm, takenBy: furyOf)
        let attackerFell = returned > 0 && applyDamage(returned, to: unitID, events: &events)
        events += stirCommanders([Stir(unit: attacker, fired: fired, fell: attackerFell,
                                       experience: GameState.battleExperience(dealt: damage, felled: holds[holdIndex].ward == 0))], at: hold.position)
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
        let plunder = spoils(ofTaking: holds[holdIndex])
        houses[previous].stock.debit(plunder)
        store(plunder, for: taker)

        var events = loseTheWounded(at: holdIndex, from: previous)
        holds[holdIndex].owner = taker
        holds[holdIndex].isSeat = false
        holds[holdIndex].project = nil
        holds[holdIndex].training = nil
        holds[holdIndex].levels[.moonspire] = nil
        holds[holdIndex].ward = holds[holdIndex].maximumWard / 4
        units[unitIndex].position = holds[holdIndex].position
        reveal(around: holds[holdIndex].position, range: sight(of: holds[holdIndex]), for: taker)

        events.insert(.holdCaptured(hold: holdID, from: previous, by: taker), at: 0)
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
        var events: [GameEvent] = [.houseFell(house)]
        // Its alliance goes on without it, and no alliance waits on it.
        if let sworn = alliance(of: house) {
            events += part(house, from: sworn.id)
        }
        forgetInvitations(of: house)
        return events
    }

    // MARK: Holds

    /// Whether a hold can be founded at a hex by a House, or why not.
    public func canFound(at hex: Hex, for house: Int) -> RuleError? {
        guard let tile = map[hex] else { return .outsideTheWorld }
        guard tile.terrain.isSettleable else { return .cannotSettle(tile.terrain) }
        if holds.contains(where: { $0.position.distance(to: hex) < 3 }) { return .tooCloseToHold }
        if let owner = territoryOwner(of: hex), owner != house { return .foreignTerritory }
        if shrine(at: hex) != nil { return .holySite }
        if standard(at: hex) != nil || hall(at: hex) != nil || storehouse(at: hex) != nil || site(at: hex)?.isYard == true {
            return .allianceGround
        }
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
        // A site under a new hold is settled ground now.
        sites?.removeAll { $0.position == hold.position }
        reveal(around: hold.position, range: sight(of: hold), for: house)
        record(.founding, [house], "\(houses[house].title) founds \(name) on the \(map[hold.position]!.terrain.title.lowercased()).")
        return [.holdFounded(hold: hold.id)]
    }

    /// The cost of raising a building one level in a hold, or nil at its top:
    /// its price, lessened by its House's studies.
    public func nextLevelCost(of kind: BuildingKind, in hold: Hold) -> Stock? {
        let next = hold.level(kind) + 1
        guard next <= kind.maxLevel else { return nil }
        return buildCost(of: kind, toLevel: next, for: hold.owner)
    }

    /// What raising a work to a level costs a House.
    public func buildCost(of kind: BuildingKind, toLevel level: Int, for house: Int) -> Stock {
        GameState.lessened(kind.cost(toLevel: level), by: bonus(.buildCost, for: house))
    }

    /// Watches raising a work to a level takes a House.
    public func buildWatches(of kind: BuildingKind, toLevel level: Int, for house: Int) -> Int {
        GameState.hastened(kind.buildWatches(toLevel: level), by: bonus(.buildSpeed, for: house))
    }

    private mutating func build(_ kind: BuildingKind, in holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedHold(holdID, of: house)
        let hold = holds[index]
        guard hold.project == nil else { throw .busy }
        if kind.requiresSeat, !hold.isSeat { throw .seatOnly }
        // A vassal raises no Moonspire while it serves.
        if kind == .moonspire, houses[house].liege != nil { throw .notApplicable }
        let level = hold.level(kind) + 1
        guard level <= kind.maxLevel else { throw .maxLevel }
        let cost = buildCost(of: kind, toLevel: level, for: house)
        guard houses[house].stock.covers(cost) else { throw .shortOf(houses[house].stock.shortfall(for: cost)) }

        houses[house].stock.debit(cost)
        holds[index].project = Hold.Project(kind: kind, targetLevel: level, watchesLeft: buildWatches(of: kind, toLevel: level, for: house))
        return [.buildingStarted(hold: holdID, kind: kind, level: level)]
    }

    /// What a company costs this House to muster, at a tier. Founders cost
    /// half as much again for every hold the House has beyond its seat, and
    /// every Founder already on the march or mustering, so each new hold is
    /// dearer than the last and a realm can't sprawl for nothing.
    public func trainingCost(of kind: UnitKind, tier: Int = 1, for house: Int) -> Stock {
        let discount = bonus(.trainingCost, for: house)
        guard kind == .founder else { return GameState.lessened(kind.cost(tier: tier), by: discount) }
        let mustering = holds.filter { $0.owner == house && $0.training?.kind == .founder }.count
        let marching = units.filter { $0.owner == house && $0.kind == .founder }.count
        let extra = max(0, holds(of: house).count - 1) + mustering + marching
        return GameState.lessened(kind.cost.scaled(percent: 100 + 50 * extra), by: discount)
    }

    /// Watches a company of a tier takes to muster at a hold.
    public func trainingWatches(of kind: UnitKind, tier: Int = 1, at hold: Hold) -> Int {
        GameState.hastened(hold.trainingWatches(for: kind, tier: tier), by: bonus(.trainingSpeed, for: hold.owner))
    }

    private mutating func train(_ kind: UnitKind, tier: Int, in holdID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedHold(holdID, of: house)
        let hold = holds[index]
        guard hold.training == nil else { throw .busy }
        if let refusal = tierRefusal(of: kind, tier: tier, at: hold, for: house) { throw refusal }
        let cost = trainingCost(of: kind, tier: tier, for: house)
        guard houses[house].stock.covers(cost) else { throw .shortOf(houses[house].stock.shortfall(for: cost)) }

        houses[house].stock.debit(cost)
        holds[index].training = Hold.Training(kind: kind, watchesLeft: trainingWatches(of: kind, tier: tier, at: hold), tier: tier)
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
        // No House makes war on one sworn to its own alliance.
        guard !areAllied(house, target) else { throw .allyInAlliance(target) }
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
            guard !areAllied(house, target) else { throw .allyInAlliance(target) }
            guard mayDemandTribute(by: house, of: target) else { throw .notApplicable }
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
            // A vassal raises no Moonspire: the works on its tower stop.
            for index in holds.indices where holds[index].owner == proposer && holds[index].project?.kind == .moonspire {
                holds[index].project = nil
            }
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

    /// Whether one House may demand tribute of another now: both standing,
    /// at peace, neither sworn to the other nor to the same alliance, and no
    /// demand paid or refused between them lately.
    public func mayDemandTribute(by demander: Int, of target: Int) -> Bool {
        guard demander != target, let me = house(demander), let other = house(target), !me.isEliminated, !other.isEliminated else { return false }
        return stance(demander, target) == .peace && me.liege != target && other.liege != demander && !areAllied(demander, target)
            && !paidTributeLately(demander, target) && !refusedTributeLately(demander, target)
    }

    /// A refused demand: the demander marches, as a steward always does,
    /// and as a keeper must when a steward refuses them, for a steward
    /// answers a demand as it makes one. Only a keeper refused by a keeper
    /// is left to choose war or not, and can't demand again for a while.
    mutating func refuseTribute(demandedBy demander: Int, of refuser: Int) -> [GameEvent] {
        if let index = relations.firstIndex(where: { $0.first == min(demander, refuser) && $0.second == max(demander, refuser) }) {
            relations[index].tributeRefused = watch
        }
        record(.tribute, [refuser, demander], "\(houses[refuser].title) refuses tribute to \(houses[demander].title).")
        guard !houses[demander].isPlayer || !houses[refuser].isPlayer else { return [] }
        return (try? declareWar(by: demander, on: refuser)) ?? []
    }
}
