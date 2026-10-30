extension GameState {
    /// Ends the current watch: rival Houses act, then the world turns. Holds
    /// bring in their yield, armies eat, works and training advance, wards
    /// mend, the wounded heal, marches continue, and the chronicle notes
    /// whether anyone has won.
    /// `keptFor` names kept Houses whose keepers are away, which a
    /// caretaker plays in their turn among the stewards.
    @discardableResult
    public mutating func endWatch(keptFor absent: Set<Int> = []) -> [GameEvent] {
        guard outcome == nil else { return [] }
        var events: [GameEvent] = []
        // A world from before commanders takes them up now.
        if commanders == nil { raiseFirstCommanders() }

        // Rivals act first; whether anyone has won is weighed once the
        // watch has turned (checkForEnd), never partway through. Who goes
        // first goes round the lake, watch by watch: no seat always first
        // to a site, a march or a trade.
        for house in stewardOrder(keptFor: absent) {
            events += RivalMind(house: house, caretaking: houses[house].isPlayer).takeTurn(in: &self)
        }

        let owners = territory()
        for house in houses where !house.isEliminated {
            events += harvest(for: house.id, territory: owners)
        }
        events += advanceWorks()
        events += advanceStudies()
        mendAndHeal(territory: owners)

        for index in units.indices {
            units[index].movesLeft = movement(of: units[index])
            units[index].acted = false
        }
        watch += 1
        turnOmens()
        forgetOldGifts()
        // An envoy unanswered is an envoy refused.
        let unanswered = envoys.filter { watch - $0.arrived >= Envoy.patience }
        envoys.removeAll { watch - $0.arrived >= Envoy.patience }
        for envoy in unanswered where envoy.proposal == .tribute && !houses[envoy.from].isEliminated
            && !houses[envoy.to].isEliminated && stance(envoy.from, envoy.to) == .peace {
            events += refuseTribute(demandedBy: envoy.from, of: envoy.to)
        }

        for unit in units.sorted(by: { $0.id < $1.id }) where unit.destination != nil {
            events += march(unit.id)
        }
        raiseWilds()
        refreshSight()
        events += checkForEnd()
        takeSnapshot()
        return events
    }

    /// The Houses the stewards play, and those kept for keepers away, in
    /// the order they act this watch: starting one seat further round the
    /// lake each watch.
    func stewardOrder(keptFor absent: Set<Int> = []) -> [Int] {
        houses.indices.map { (watch + $0) % houses.count }
            .filter { !houses[$0].isEliminated && (!houses[$0].isPlayer || absent.contains($0)) }
    }

    /// Lets a House's steward play its watch, deciding as the rival Houses
    /// do: what to build and train, where to march, whom to fight.
    @discardableResult
    public mutating func stewardTurn(for house: Int, caretaking: Bool = false) -> [GameEvent] {
        guard outcome == nil else { return [] }
        return RivalMind(house: house, caretaking: caretaking).takeTurn(in: &self)
    }

    private mutating func harvest(for house: Int, territory owners: [Int?]) -> [GameEvent] {
        var income = Stock.zero
        for hold in holds(of: house) {
            income = income + self.income(of: hold, territory: owners)
        }
        store(income, for: house)

        let upkeep = self.upkeep(of: house)
        if houses[house].stock.grain >= upkeep {
            houses[house].stock.grain -= upkeep
            return []
        }
        // Hunger: the grain runs out and the newest companies suffer first.
        houses[house].stock.grain = 0
        var events: [GameEvent] = [.starving(house: house)]
        let hungry = units(of: house).filter { self.upkeep(of: $0) > 0 }.sorted { $0.id > $1.id }
        for unit in hungry.prefix(max(1, hungry.count / 2)) {
            guard let index = unitIndex(unit.id) else { continue }
            units[index].health -= 20
            if units[index].health <= 0 {
                let lost = units.remove(at: index)
                events.append(.unitLost(unit: lost.id, kind: lost.kind, owner: lost.owner, at: lost.position))
                events += woundCommander(of: lost)
            }
        }
        return events
    }

    private mutating func advanceWorks() -> [GameEvent] {
        var events: [GameEvent] = []
        for index in holds.indices {
            if var project = holds[index].project {
                project.watchesLeft -= 1
                if project.watchesLeft <= 0 {
                    holds[index].levels[project.kind] = project.targetLevel
                    holds[index].project = nil
                    if project.kind == .walls {
                        holds[index].ward = holds[index].maximumWard
                    }
                    events.append(.buildingCompleted(hold: holds[index].id, kind: project.kind, level: project.targetLevel))
                    if project.kind == .moonspire {
                        let owner = holds[index].owner
                        let words = project.targetLevel == BuildingKind.moonspire.maxLevel
                            ? "completes the Moonspire. Its white light falls across the whole of \(settings.lake.title)."
                            : "raises the Moonspire at \(holds[index].name) to its \(ordinal(project.targetLevel)) stage."
                        record(.greatWork, [owner], "\(houses[owner].title) \(words)")
                    }
                    // A seat's third and fifth halls raise a captain from the ranks.
                    if project.kind == .musterHall, holds[index].isSeat, GameState.captainsAt.contains(project.targetLevel) {
                        events += commanderJoins(holds[index].owner, why: "rises from the ranks of")
                    }
                } else {
                    holds[index].project = project
                }
            }
            if var training = holds[index].training {
                training.watchesLeft -= 1
                if training.watchesLeft <= 0 {
                    let hold = holds[index]
                    if let unit = placeUnit(training.kind, tier: training.musteredTier, for: hold.owner, near: hold.position) {
                        holds[index].training = nil
                        events.append(.unitTrained(unit: unit.id, hold: hold.id))
                    } else {
                        training.watchesLeft = 0
                        holds[index].training = training
                    }
                } else {
                    holds[index].training = training
                }
            }
        }
        return events
    }

    private mutating func mendAndHeal(territory owners: [Int?]) {
        for index in holds.indices {
            // A ward can't be mended while it is struck, or while an enemy
            // army stands at its walls.
            let hold = holds[index]
            let besieged = units.contains { unit in
                unit.kind.isMilitary && unit.owner != hold.owner && isAtWar(unit.owner, hold.owner)
                    && unit.position.distance(to: hold.position) == 1
            }
            if !hold.struck && !besieged {
                holds[index].ward = min(holds[index].maximumWard, holds[index].ward + wardMending(for: hold.owner))
            }
            holds[index].struck = false
        }
        for index in units.indices where !units[index].acted && units[index].health < 100 {
            let unit = units[index]
            var amount = 10 + bonus(.healing, for: unit)
            if let tile = map.index(of: unit.position), let holdID = owners[tile], hold(holdID)?.owner == unit.owner {
                amount += 10
            }
            if hold(at: unit.position)?.owner == unit.owner {
                amount += 10
            }
            units[index].health = min(100, unit.health + amount)
        }
    }

    /// Share of all holds, in percent, and the least number of holds, that
    /// win by dominion without destroying every rival.
    public static let supremacyShare = 25
    public static let supremacyMinimum = 10

    /// Holds a House rules: its own and its vassals'.
    public func realm(of house: Int) -> Int {
        holds(of: house).count + houses.filter { $0.liege == house && !$0.isEliminated }.reduce(0) { $0 + holds(of: $1.id).count }
    }

    /// Whether a House rules enough of the lake to win by dominion.
    public func isSupreme(_ house: Int) -> Bool {
        guard houses[house].liege == nil else { return false }
        let mine = realm(of: house)
        return mine >= GameState.supremacyMinimum && mine * 100 >= holds.count * GameState.supremacyShare
    }

    private mutating func checkForEnd() -> [GameEvent] {
        guard outcome == nil else { return [] }
        let living = livingHouses
        // Two Moonspires finished in one watch: as with dominion, the
        // greater realm, then the greater renown, not the earlier seat. A
        // vassal can't win while it serves.
        let builders = Set(holds.filter { $0.level(.moonspire) >= BuildingKind.moonspire.maxLevel }.map(\.owner))
            .filter { houses[$0].liege == nil }
        if let builder = builders.max(by: { a, b in (realm(of: a), renown(of: a), -a) < (realm(of: b), renown(of: b), -b) }) {
            let result = Outcome(winner: builder, kind: .ascendancy, watch: watch)
            outcome = result
            record(.ending, [builder], "The Moonspire of \(houses[builder].title) stands complete. The lake is theirs.")
            return [.gameEnded(result)]
        }
        // Supremacy: a House ruling most of the lake's holds holds the lake.
        // Two at once: the greater realm, then the greater renown.
        if let ruler = living.filter({ isSupreme($0.id) }).max(by: { a, b in
            (realm(of: a.id), renown(of: a.id), -a.id) < (realm(of: b.id), renown(of: b.id), -b.id)
        }) {
            let result = Outcome(winner: ruler.id, kind: .dominion, watch: watch)
            outcome = result
            record(.ending, [ruler.id], "\(ruler.title) rules \(realm(of: ruler.id)) of the \(holds.count) holds around \(settings.lake.title). The others bend the knee.")
            return [.gameEnded(result)]
        }
        if living.count == 1, let last = living.first {
            let result = Outcome(winner: last.id, kind: .dominion, watch: watch)
            outcome = result
            record(.ending, [last.id], "\(last.title) alone remains on the shores of \(settings.lake.title).")
            return [.gameEnded(result)]
        }
        // A House's own game ends with its House. A realm's age goes on
        // while any keeper's House stands; once every one has fallen, the
        // greatest House left holds the lake and a new age begins.
        let kept = houses.filter(\.isPlayer)
        let keepersAllFallen = settings.keepers > 0 ? houses[player].isEliminated : (!kept.isEmpty && kept.allSatisfy(\.isEliminated))
        if keepersAllFallen {
            let strongest = living.max { renown(of: $0.id) < renown(of: $1.id) }!
            let result = Outcome(winner: strongest.id, kind: .dominion, watch: watch)
            outcome = result
            return [.gameEnded(result)]
        }
        return []
    }
}

func ordinal(_ number: Int) -> String {
    switch number {
    case 1: return "first"
    case 2: return "second"
    case 3: return "third"
    case 4: return "fourth"
    case 5: return "fifth"
    case 6: return "sixth"
    case 7: return "seventh"
    case 8: return "eighth"
    case 9: return "ninth"
    case 10: return "tenth"
    default: return "\(number)th"
    }
}
