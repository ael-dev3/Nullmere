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
            if let wounded = hold.wounded {
                if wounded.isEmpty || wounded.count > hold.beds { found.append("\(hold.name) keeps \(wounded.count) wounded in \(hold.beds) beds") }
                for company in wounded where !company.kind.isMilitary || !(1...company.kind.highestTier).contains(company.tier) {
                    found.append("\(hold.name) keeps wounded \(company.kind.title) of tier \(company.tier)")
                }
            }
        }
        if !unitIDs.isDisjoint(with: holdIDs) { found.append("A company and a hold share an id") }
        if let highest = (unitIDs.union(holdIDs).union(envoys.map(\.id))).max(), highest >= nextID {
            found.append("Id \(highest) was given out before the next id \(nextID)")
        }
        for envoy in envoys where !houseIDs.contains(envoy.from) || !houseIDs.contains(envoy.to) || envoy.from == envoy.to {
            found.append("Envoy \(envoy.id) runs from \(envoy.from) to \(envoy.to)")
        }
        var lairSpots: Set<Hex> = []
        for lair in lairsStanding {
            if !(1...Lair.highestLevel).contains(lair.level) || !(1...lair.might).contains(lair.strength) {
                found.append("The \(lair.title) \(lair.id) stands at \(lair.strength) of \(lair.might), level \(lair.level)")
            }
            if unit(at: lair.position) != nil || hold(at: lair.position) != nil || wild(at: lair.position) != nil
                || site(at: lair.position) != nil || !lairSpots.insert(lair.position).inserted {
                found.append("The \(lair.title) \(lair.id) shares its ground at \(lair.position)")
            }
            if map[lair.position]?.terrain.isPassable != true { found.append("The \(lair.title) \(lair.id) stands where none can") }
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
        var slots: Set<String> = []
        for piece in gear {
            if !houseIDs.contains(piece.owner) { found.append("\(piece.title) \(piece.id) is held by no House (\(piece.owner))") }
            guard let wearer = piece.wornBy else { continue }
            if commander(wearer)?.owner != piece.owner { found.append("\(piece.title) \(piece.id) is worn by a commander not of its House") }
            if !slots.insert("\(wearer) \(piece.slot)").inserted { found.append("Commander \(wearer) wears two in its \(piece.slot.title.lowercased()) slot") }
        }
        var sworn: Set<Int> = []
        for alliance in alliancesStanding {
            if alliance.members.isEmpty { found.append("\(alliance.name) has no House") }
            if !alliance.members.contains(alliance.leader) { found.append("\(alliance.name) is led by a House not of it") }
            if alliance.members.count > allianceLimit { found.append("\(alliance.name) has \(alliance.members.count) Houses") }
            for member in alliance.members {
                if !sworn.insert(member).inserted { found.append("House \(member) is sworn to two alliances") }
                if !houseIDs.contains(member) || houses[member].isEliminated { found.append("\(alliance.name) counts a House that isn't standing (\(member))") }
            }
            for (index, first) in alliance.members.enumerated() {
                for second in alliance.members[(index + 1)...] where isAtWar(first, second) {
                    found.append("\(alliance.name) has Houses \(first) and \(second) at war")
                }
            }
            for waiting in alliance.invited + alliance.asking where !houseIDs.contains(waiting) || alliance.members.contains(waiting) {
                found.append("\(alliance.name) waits on House \(waiting)")
            }
            if let lore = alliance.lore {
                for (name, grade) in lore.grades {
                    guard let study = AllianceStudy(rawValue: name) else {
                        found.append("\(alliance.name) knows a study called \(name)")
                        continue
                    }
                    if !(1...AllianceStudy.grades).contains(grade) { found.append("\(alliance.name) knows \(study.title) at grade \(grade)") }
                }
                if let pursuit = lore.pursuit, lore.grade(of: pursuit) >= AllianceStudy.grades {
                    found.append("\(alliance.name) pursues \(pursuit.title), mastered")
                }
            }
        }
        var callers: Set<Int> = []
        var flags: Set<Hex> = []
        for standard in standardsStanding {
            if alliance(standard.alliance) == nil { found.append("Standard \(standard.id) stands for no alliance") }
            if !(0...Standard.maximumWard).contains(standard.ward) { found.append("Standard \(standard.id) has ward \(standard.ward)") }
            if hold(at: standard.position) != nil || wild(at: standard.position) != nil || lair(at: standard.position) != nil
                || !flags.insert(standard.position).inserted {
                found.append("Standard \(standard.id) shares its ground at \(standard.position)")
            }
            if map[standard.position]?.terrain.isPassable != true { found.append("Standard \(standard.id) stands where none can") }
        }
        var halled: Set<Int> = []
        for hall in hallsStanding {
            if alliance(hall.alliance) == nil { found.append("Hall \(hall.id) stands for no alliance") }
            if !halled.insert(hall.alliance).inserted { found.append("Alliance \(hall.alliance) has two halls") }
            if !(0...AllianceHall.raising).contains(hall.built) { found.append("Hall \(hall.id) is built \(hall.built) of \(AllianceHall.raising)") }
            if !(0...hall.wardLimit).contains(hall.ward) { found.append("Hall \(hall.id) has ward \(hall.ward) of \(hall.wardLimit)") }
            if hold(at: hall.position) != nil || wild(at: hall.position) != nil || lair(at: hall.position) != nil
                || !flags.insert(hall.position).inserted {
                found.append("Hall \(hall.id) shares its ground at \(hall.position)")
            }
            if map[hall.position]?.terrain.isPassable != true { found.append("Hall \(hall.id) stands where none can") }
        }
        var storehoused: Set<Int> = []
        for storehouse in storehousesStanding {
            let name = "Storehouse \(storehouse.id)"
            guard let sworn = alliance(storehouse.alliance) else {
                found.append("\(name) stands for no alliance")
                continue
            }
            if !storehoused.insert(storehouse.alliance).inserted { found.append("Alliance \(storehouse.alliance) has two storehouses") }
            if !(0...Storehouse.raising).contains(storehouse.built) { found.append("\(name) is built \(storehouse.built) of \(Storehouse.raising)") }
            if !(0...Storehouse.maximumWard).contains(storehouse.ward) { found.append("\(name) has ward \(storehouse.ward)") }
            if hold(at: storehouse.position) != nil || wild(at: storehouse.position) != nil || lair(at: storehouse.position) != nil
                || site(at: storehouse.position) != nil || !flags.insert(storehouse.position).inserted {
                found.append("\(name) shares its ground at \(storehouse.position)")
            }
            if map[storehouse.position]?.terrain.isPassable != true { found.append("\(name) stands where none can") }
            var layers: Set<Int> = []
            for laid in storehouse.laidUp {
                if !sworn.members.contains(laid.house) { found.append("\(name) keeps stores of House \(laid.house), not of its alliance") }
                if !layers.insert(laid.house).inserted { found.append("\(name) keeps House \(laid.house)'s stores twice") }
                if laid.stock.isZero || !laid.stock.fits(in: Storehouse.room) || !laid.stock.covers(.zero) {
                    found.append("\(name) keeps \(laid.stock) of House \(laid.house)")
                }
            }
        }
        for sworn in alliances ?? [] {
            if let coffers = sworn.coffers, !coffers.covers(.zero) || !coffers.fits(in: Alliance.coffersKept) {
                found.append("The coffers of \(sworn.name) hold \(coffers)")
            }
        }
        if let sundering {
            if sundering.shores.count != houses.count { found.append("The Sundering has shores for \(sundering.shores.count) Houses of \(houses.count)") }
            if sundering.points.count != houses.count { found.append("The Sundering has points for \(sundering.points.count) Houses of \(houses.count)") }
            if sundering.points.contains(where: { $0 < 0 }) { found.append("The Sundering has points below none") }
            if sundering.ends != sundering.begins + Sundering.lasts { found.append("The Sundering lasts \(sundering.ends - sundering.begins) watches") }
        }
        var fighting: Set<Int> = []
        for field in fieldsOfBattle {
            let name = "Field \(field.id)"
            if field.id >= nextID { found.append("\(name) was given out before the next id \(nextID)") }
            if map[field.at] == nil { found.append("\(name) lies off the map") }
            if !(0...Field.longest).contains(field.paces) { found.append("\(name) has gone on \(field.paces) paces") }
            guard field.sides.count == 2, !field.sides.contains(where: \.isEmpty) else {
                found.append("\(name) has sides \(field.sides)")
                continue
            }
            if !Set(field.sides[0]).isDisjoint(with: field.sides[1]) { found.append("A House fights on both sides of \(name)") }
            for fighter in field.fighters {
                if !field.sides.indices.contains(fighter.side) || !field.sides[fighter.side].contains(fighter.owner) {
                    found.append("A company of House \(fighter.owner) fights in \(name) on a side its House is not on")
                }
                if fighter.slain < 0 || fighter.lost < 0 || fighter.lost > fighter.troops { found.append("\(name) counts \(fighter)") }
                if fighter.standing, !fighting.insert(fighter.unit).inserted { found.append("Company \(fighter.unit) stands in two fields") }
                if fighter.standing && fighter.fell { found.append("Company \(fighter.unit) stands in \(name) though it fell") }
            }
        }
        var yarded: Set<String> = []
        for yard in sitesInLand {
            guard let owner = yard.alliance else { continue }
            if alliance(owner) == nil { found.append("Yard \(yard.id) is of no alliance") }
            if !yarded.insert("\(owner) \(yard.store.rawValue)").inserted { found.append("Alliance \(owner) has two yards of \(yard.store.title.lowercased())") }
        }
        var stacks: Set<String> = []
        for stack in satchel ?? [] {
            if !houseIDs.contains(stack.house) { found.append("A satchel is of no House (\(stack.house))") }
            if !(1...GameState.itemsKept).contains(stack.count) { found.append("House \(stack.house) keeps \(stack.count) of \(stack.kind.plural)") }
            if !stacks.insert("\(stack.house) \(stack.kind.rawValue)").inserted { found.append("House \(stack.house) keeps \(stack.kind.plural) twice") }
        }
        var kept: Set<String> = []
        for stack in makings ?? [] {
            let what = stack.making.title.lowercased()
            if !houseIDs.contains(stack.house) { found.append("Makings are of no House (\(stack.house))") }
            if !(1...GameState.makingsKept).contains(stack.count) { found.append("House \(stack.house) keeps \(stack.count) \(what)") }
            if !kept.insert("\(stack.house) \(stack.making.rawValue)").inserted { found.append("House \(stack.house) keeps \(what) twice") }
        }
        for rally in ralliesStanding {
            if !callers.insert(rally.caller).inserted { found.append("House \(rally.caller) has called two rallies") }
            if hold(rally.muster)?.owner != rally.caller { found.append("Rally \(rally.id) gathers at a hold not its caller's") }
            if target(of: rally) == nil { found.append("Rally \(rally.id) marches on no hold or lair") }
            if rally.companies.count > capacity(of: rally) { found.append("Rally \(rally.id) has \(rally.companies.count) companies") }
            // A company fallen since the rally last turned is let be.
            for id in rally.companies where unit(id).map({ $0.errand != .rally(rally.id) }) ?? false {
                found.append("Rally \(rally.id) counts company \(id), not sent to it")
            }
        }
        var deeds: Set<String> = []
        for done in deedsDone ?? [] {
            if !houseIDs.contains(done.house) { found.append("A deed is of no House (\(done.house))") }
            if !deeds.insert("\(done.house) \(done.deed.rawValue)").inserted { found.append("House \(done.house) did \(done.deed.title) twice") }
        }
        if let chargesDone {
            if chargesDone.count > houses.count { found.append("Charges are counted for \(chargesDone.count) Houses") }
            for (house, done) in chargesDone.enumerated() where !(0...Charge.allCases.count).contains(done) {
                found.append("House \(house) has done \(done) charges")
            }
        }
        for unit in units {
            switch unit.errand {
            case .rally(let id)?:
                if rally(id)?.companies.contains(unit.id) != true { found.append("Company \(unit.id) is sent to no rally") }
            case .reinforce(let holdID)?:
                if hold(holdID) == nil { found.append("Company \(unit.id) keeps the gates of no hold") }
            default:
                break
            }
        }
        let pairs = Set(relations.map { [$0.first, $0.second] })
        if pairs.count != relations.count { found.append("Two Houses have more than one standing") }
        for relation in relations where !houseIDs.contains(relation.first) || !houseIDs.contains(relation.second) || relation.first == relation.second {
            found.append("A standing between \(relation.first) and \(relation.second)")
        }
        for bottle in bottlesOnTheLake where map[bottle.position] == nil {
            found.append("Bottle \(bottle.id) lies outside the world at \(bottle.position)")
        }
        // Each report and bar a House's.
        for report in wordReports where !houseIDs.contains(report.by) {
            found.append("A report of line \(report.word) by no House (\(report.by))")
        }
        for bar in bars ?? [] where !houseIDs.contains(bar.house) {
            found.append("A bar from the Words on no House (\(bar.house))")
        }
        // Each edict a House's, voted on once by each House, closed after it was put.
        for edict in edictsOfTheRealm {
            let voters = edict.ayes + edict.nays
            if !houseIDs.contains(edict.proposer) || !voters.allSatisfy({ houseIDs.contains($0) })
                || !edict.breaches.allSatisfy({ houseIDs.contains($0.house) && houseIDs.contains($0.against) }) {
                found.append("Edict \(edict.id) names a House that isn't")
            }
            if Set(voters).count != voters.count { found.append("Edict \(edict.id) counts a House's vote twice") }
            if let closed = edict.closed, closed < edict.proposed { found.append("Edict \(edict.id) closed before it was put") }
        }
        if edictsOfTheRealm.filter({ $0.closed == nil }).count > 1 { found.append("More than one edict is before the realm") }
        if let spire = brokenSpire, map[spire.position] == nil {
            found.append("The broken Spire lies outside the world at \(spire.position)")
        }
        for hold in drownedHolds where map[hold.position] == nil {
            found.append("The drowned hold of \(hold.name) lies outside the world at \(hold.position)")
        }
        // Each ballad a House's, of an entry in the Chronicle, as sung.
        for ballad in songbook {
            if !houseIDs.contains(ballad.house) { found.append("Ballad \(ballad.id) was sung by no House (\(ballad.house))") }
            if !chronicle.indices.contains(ballad.entry) { found.append("Ballad \(ballad.id) sings of no entry (\(ballad.entry))") }
            if GameState.sung(ballad.lines.joined(separator: "\n")) != ballad.lines { found.append("Ballad \(ballad.id) is not as sung") }
        }
        return found
    }
}
