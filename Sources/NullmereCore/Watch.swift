extension GameState {
    /// Ends the current watch: rival Houses act, then the world turns. Holds
    /// bring in their yield, armies eat, works and training advance, wards
    /// mend, the wounded heal, marches continue, and the chronicle notes
    /// whether anyone has won.
    @discardableResult
    public mutating func endWatch() -> [GameEvent] {
        guard outcome == nil else { return [] }
        var events: [GameEvent] = []

        for house in houses where !house.isPlayer && !house.isEliminated {
            events += RivalMind(house: house.id).takeTurn(in: &self)
            if outcome != nil { return events }
        }

        let owners = territory()
        for house in houses where !house.isEliminated {
            events += harvest(for: house.id, territory: owners)
        }
        events += advanceWorks()
        mendAndHeal(territory: owners)

        for index in units.indices {
            units[index].movesLeft = units[index].kind.movement
            units[index].acted = false
        }
        watch += 1
        envoys.removeAll { watch - $0.arrived >= Envoy.patience }

        for unit in units.sorted(by: { $0.id < $1.id }) where unit.destination != nil {
            events += march(unit.id)
        }
        refreshSight()
        events += checkForEnd()
        return events
    }

    /// Lets a House's steward play its watch, deciding as the rival Houses
    /// do: what to build and train, where to march, whom to fight.
    @discardableResult
    public mutating func stewardTurn(for house: Int) -> [GameEvent] {
        guard outcome == nil else { return [] }
        return RivalMind(house: house).takeTurn(in: &self)
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
        let hungry = units(of: house).filter { $0.kind.upkeep > 0 }.sorted { $0.id > $1.id }
        for unit in hungry.prefix(max(1, hungry.count / 2)) {
            guard let index = unitIndex(unit.id) else { continue }
            units[index].health -= 20
            if units[index].health <= 0 {
                let lost = units.remove(at: index)
                events.append(.unitLost(unit: lost.id, kind: lost.kind, owner: lost.owner, at: lost.position))
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
                            ? "completes the Moonspire. Its white light falls across the whole of the Nullmere."
                            : "raises the Moonspire at \(holds[index].name) to its \(ordinal(project.targetLevel)) stage."
                        record(.greatWork, [owner], "\(houses[owner].title) \(words)")
                    }
                } else {
                    holds[index].project = project
                }
            }
            if var training = holds[index].training {
                training.watchesLeft -= 1
                if training.watchesLeft <= 0 {
                    let hold = holds[index]
                    if let unit = placeUnit(training.kind, for: hold.owner, near: hold.position) {
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
                holds[index].ward = min(holds[index].maximumWard, holds[index].ward + Hold.wardRecovery)
            }
            holds[index].struck = false
        }
        for index in units.indices where !units[index].acted && units[index].health < 100 {
            let unit = units[index]
            var amount = 10
            if let tile = map.index(of: unit.position), let holdID = owners[tile], hold(holdID)?.owner == unit.owner {
                amount += 10
            }
            if hold(at: unit.position)?.owner == unit.owner {
                amount += 10
            }
            units[index].health = min(100, unit.health + amount)
        }
    }

    private mutating func checkForEnd() -> [GameEvent] {
        guard outcome == nil else { return [] }
        let living = livingHouses
        if let builder = holds.first(where: { $0.level(.moonspire) >= BuildingKind.moonspire.maxLevel }) {
            let result = Outcome(winner: builder.owner, kind: .ascendancy, watch: watch)
            outcome = result
            record(.ending, [builder.owner], "The Moonspire of \(houses[builder.owner].title) stands complete. The lake is theirs.")
            return [.gameEnded(result)]
        }
        if living.count == 1, let last = living.first {
            let result = Outcome(winner: last.id, kind: .dominion, watch: watch)
            outcome = result
            record(.ending, [last.id], "\(last.title) alone remains on the shores of the Nullmere.")
            return [.gameEnded(result)]
        }
        if houses[player].isEliminated {
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
    default: return "\(number)th"
    }
}
