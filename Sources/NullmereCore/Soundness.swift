/// What must always hold of a world, however long it runs: the realm's
/// steward and the tests ask, and a world that answers anything is wrong.
extension GameState {
    public func problems() -> [String] {
        var found: [String] = []
        let houseIDs = houses.indices
        for (index, house) in houses.enumerated() {
            if house.id != index { found.append("House \(house.name) has id \(house.id) at \(index)") }
            if house.explored.count != map.count { found.append("\(house.title) has explored \(house.explored.count) of \(map.count) tiles") }
            for resource in Resource.allCases where house.stock[resource] < 0 {
                found.append("\(house.title) has \(house.stock[resource]) \(resource.title)")
            }
            if let liege = house.liege, !houseIDs.contains(liege) || liege == house.id {
                found.append("\(house.title) is sworn to \(liege)")
            }
        }
        var unitIDs: Set<Int> = []
        for unit in units {
            if !unitIDs.insert(unit.id).inserted { found.append("Two companies share id \(unit.id)") }
            guard houseIDs.contains(unit.owner) else {
                found.append("Company \(unit.id) belongs to no House (\(unit.owner))")
                continue
            }
            if houses[unit.owner].isEliminated { found.append("Company \(unit.id) of fallen \(houses[unit.owner].title) still stands") }
            guard let tile = map[unit.position] else {
                found.append("Company \(unit.id) stands outside the world at \(unit.position)")
                continue
            }
            if !tile.terrain.isPassable { found.append("Company \(unit.id) stands on \(tile.terrain.title)") }
            if !(1...100).contains(unit.health) { found.append("Company \(unit.id) has \(unit.health) health") }
            if !(1...unit.kind.highestTier).contains(unit.tier) { found.append("Company \(unit.id) has tier \(unit.tier)") }
            if unit.movesLeft < 0 { found.append("Company \(unit.id) has \(unit.movesLeft) moves") }
        }
        var holdIDs: Set<Int> = [], places: Set<Hex> = []
        for hold in holds {
            if !holdIDs.insert(hold.id).inserted { found.append("Two holds share id \(hold.id)") }
            if !places.insert(hold.position).inserted { found.append("Two holds stand at \(hold.position)") }
            if !houseIDs.contains(hold.owner) { found.append("\(hold.name) belongs to no House (\(hold.owner))") }
            if map[hold.position]?.terrain.isSettleable != true { found.append("\(hold.name) stands on ground no hold can") }
            if hold.ward < 0 || hold.ward > hold.maximumWard { found.append("\(hold.name) has ward \(hold.ward) of \(hold.maximumWard)") }
            for (kind, level) in hold.levels where level < 0 || level > kind.maxLevel {
                found.append("\(hold.name) has \(kind) at level \(level)")
            }
        }
        if !unitIDs.isDisjoint(with: holdIDs) { found.append("A company and a hold share an id") }
        if let highest = (unitIDs.union(holdIDs).union(envoys.map(\.id))).max(), highest >= nextID {
            found.append("Id \(highest) was given out before the next id \(nextID)")
        }
        for envoy in envoys where !houseIDs.contains(envoy.from) || !houseIDs.contains(envoy.to) || envoy.from == envoy.to {
            found.append("Envoy \(envoy.id) runs from \(envoy.from) to \(envoy.to)")
        }
        var wildIDs: Set<Int> = []
        for wild in wildsStanding {
            if !wildIDs.insert(wild.id).inserted || unitIDs.contains(wild.id) || holdIDs.contains(wild.id) {
                found.append("The wilds' id \(wild.id) is given twice")
            }
            if wild.id >= nextID { found.append("The wilds' id \(wild.id) was given out before the next id \(nextID)") }
            guard let tile = map[wild.position], tile.terrain.isPassable, !tile.terrain.isWater else {
                found.append("Wilds \(wild.id) stand where none can, at \(wild.position)")
                continue
            }
            if unit(at: wild.position) != nil || hold(at: wild.position) != nil || !places.insert(wild.position).inserted {
                found.append("Wilds \(wild.id) share their ground at \(wild.position)")
            }
            if !(1...100).contains(wild.health) { found.append("Wilds \(wild.id) have \(wild.health) health") }
            if !(1...Wild.highestLevel).contains(wild.level) { found.append("Wilds \(wild.id) are of level \(wild.level)") }
        }
        var siteIDs: Set<Int> = [], siteSpots: Set<Hex> = []
        for site in sitesInLand {
            if !siteIDs.insert(site.id).inserted || unitIDs.contains(site.id) || holdIDs.contains(site.id) || wildIDs.contains(site.id) {
                found.append("Site \(site.id) is numbered twice")
            }
            if site.id >= nextID { found.append("Site \(site.id) was given out before the next id \(nextID)") }
            if map[site.position]?.terrain.isPassable != true { found.append("Site \(site.id) lies where none can go") }
            if hold(at: site.position) != nil || wild(at: site.position) != nil || !siteSpots.insert(site.position).inserted {
                found.append("Site \(site.id) lies under something else at \(site.position)")
            }
            if site.remaining <= 0 { found.append("Site \(site.id) is worked out but still there") }
        }
        for unit in units {
            guard let load = unit.load else { continue }
            if Resource.allCases.contains(where: { load[$0] < 0 }) { found.append("Company \(unit.id) carries \(load)") }
            if !unit.kind.isMilitary, !load.isZero { found.append("Company \(unit.id) of \(unit.kind.title) carries stores") }
        }
        for (index, commander) in roster.enumerated() {
            if commander.id != index + 1 { found.append("Commander \(commander.id) stands numbered \(index + 1)") }
            if !houseIDs.contains(commander.owner) { found.append("Commander \(commander.name) serves no House (\(commander.owner))") }
        }
        var led: Set<Int> = []
        for unit in units {
            guard let leader = unit.leader else { continue }
            if !led.insert(leader).inserted { found.append("Commander \(leader) leads two companies") }
            guard let commander = commander(leader) else {
                found.append("Company \(unit.id) is led by no commander (\(leader))")
                continue
            }
            if commander.owner != unit.owner { found.append("Company \(unit.id) is led by another House's commander") }
        }
        let pairs = Set(relations.map { [$0.first, $0.second] })
        if pairs.count != relations.count { found.append("Two Houses have more than one standing") }
        for relation in relations where !houseIDs.contains(relation.first) || !houseIDs.contains(relation.second) || relation.first == relation.second {
            found.append("A standing between \(relation.first) and \(relation.second)")
        }
        return found
    }
}
