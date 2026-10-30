import Foundation

/// A host called by a House of an alliance against a hold of a House at
/// war with it. Its allies, and the caller, send companies of war to
/// gather at one of the caller's holds; when the gathering is done, those
/// at the muster set out together, march at the pace of the slowest, and
/// strike the hold together in the one watch, before its ward can mend.
public struct Rally: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    /// The House that called it.
    public let caller: Int
    /// The caller's hold where it gathers.
    public let muster: Int
    /// The hold it marches on.
    public let target: Int
    public let called: Int
    /// The watch it sets out from its muster.
    public let setsOut: Int
    /// The companies sent to it, in the order they were sent.
    public internal(set) var companies: [Int]
    /// Whether the host has set out.
    public internal(set) var marching: Bool

    public init(id: Int, caller: Int, muster: Int, target: Int, called: Int, setsOut: Int) {
        self.id = id
        self.caller = caller
        self.muster = muster
        self.target = target
        self.called = called
        self.setsOut = setsOut
        self.companies = []
        self.marching = false
    }

    /// The watches a rally may gather for.
    public static let gatherings = 1...4
    /// The watches a host marches before it gives up the march.
    public static let marchLimit = 8
    /// The companies a muster takes: two, and two more for each level of
    /// its Muster Hall.
    public static func capacity(musterHall level: Int) -> Int { 2 + 2 * level }
}

extension GameState {
    /// Every rally gathering or on the march.
    public var ralliesStanding: [Rally] { rallies ?? [] }

    public func rally(_ id: Int) -> Rally? {
        rallies?.first { $0.id == id }
    }

    private func rallyIndex(_ id: Int) -> Int? {
        rallies?.firstIndex { $0.id == id }
    }

    /// The companies a rally's muster takes.
    public func capacity(of rally: Rally) -> Int {
        Rally.capacity(musterHall: hold(rally.muster)?.level(.musterHall) ?? 0)
    }

    /// Whether a House is of a rally's side: its caller, or sworn with it.
    public func isOfRally(_ house: Int, _ rally: Rally) -> Bool {
        house == rally.caller || areAllied(house, rally.caller)
    }

    // MARK: Calling and joining

    mutating func callRally(from holdID: Int, against targetID: Int, gathering watches: Int, by house: Int) throws(RuleError) -> [GameEvent] {
        guard alliance(of: house) != nil else { throw .notInAlliance }
        let muster = holds[try ownedHold(holdID, of: house)]
        guard let target = hold(targetID), isExplored(target.position, by: house) else { throw .unknownHold }
        guard isAtWar(house, target.owner) else { throw .notAtWar(target.owner) }
        guard muster.level(.musterHall) >= 1 else { throw .needsMusterHall(1) }
        guard Rally.gatherings.contains(watches) else { throw .rallyWatches }
        guard !ralliesStanding.contains(where: { $0.caller == house }) else { throw .rallyCalled }
        let rally = Rally(id: takeID(), caller: house, muster: holdID, target: targetID, called: watch, setsOut: watch + watches)
        rallies = ralliesStanding + [rally]
        return [.rallyCalled(rally: rally.id, caller: house, target: targetID)]
    }

    mutating func joinRally(_ rallyID: Int, with unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        // Only its own side knows of a rally gathering.
        guard let rallyIndex = rallyIndex(rallyID), isOfRally(house, rallies![rallyIndex]) else { throw .unknownRally }
        let rally = rallies![rallyIndex]
        guard !rally.marching else { throw .rallySetOut }
        let unit = units[index]
        guard unit.kind.isMilitary else { throw .cannotFight }
        guard let target = hold(rally.target) else { throw .unknownHold }
        guard isAtWar(house, target.owner) else { throw .notAtWar(target.owner) }
        guard unit.errand != .rally(rallyID) else { throw .alreadyRallying }
        let sent = rally.companies.filter { self.unit($0)?.errand == .rally(rallyID) }
        guard sent.count < capacity(of: rally) else { throw .rallyFull }
        let muster = hold(rally.muster)!
        if unit.position.distance(to: muster.position) > 1 {
            guard path(for: unit, to: muster.position) != nil else { throw .noPath }
            units[index].destination = muster.position
        } else {
            units[index].destination = nil
        }
        units[index].fortified = false
        units[index].errand = .rally(rallyID)
        rallies![rallyIndex].companies = sent + [unitID]
        return [.rallyJoined(rally: rallyID, unit: unitID, house: house)] + march(unitID)
    }

    // MARK: Keeping an ally's gates

    mutating func reinforce(_ holdID: Int, with unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        let index = try ownedUnit(unitID, of: house)
        guard units[index].kind.isMilitary else { throw .cannotFight }
        guard let hold = hold(holdID) else { throw .unknownHold }
        guard areAllied(house, hold.owner) else { throw .notAnAllysHold }
        let unit = units[index]
        if unit.position.distance(to: hold.position) > 1 {
            guard path(for: unit, to: hold.position) != nil else { throw .noPath }
            units[index].destination = hold.position
        } else {
            guard unit.errand != .reinforce(hold: holdID) else { throw .alreadyThere }
            units[index].destination = nil
        }
        units[index].fortified = false
        units[index].errand = .reinforce(hold: holdID)
        return [.sentToReinforce(unit: unitID, owner: house, hold: holdID)] + march(unitID)
    }

    /// The companies keeping a hold's gates now.
    public func keepers(of holdID: Int) -> [Unit] {
        guard let hold = hold(holdID) else { return [] }
        return units.filter { $0.errand == .reinforce(hold: holdID) && $0.position.distance(to: hold.position) <= 1 }
    }

    // MARK: The watch

    /// Each watch, after the marches: a rally whose cause is gone comes to
    /// nothing; a gathering done sets out with the companies at its muster;
    /// a host marches together, at the pace of its slowest, and once all of
    /// it is in reach of its hold, or it can come no nearer, strikes it
    /// together. Companies keeping the gates of a hold no longer an ally's
    /// go back to their House's orders.
    mutating func advanceRallies() -> [GameEvent] {
        var events: [GameEvent] = []
        for rally in ralliesStanding.sorted(by: { $0.id < $1.id }) {
            events += advance(rally.id)
        }
        for index in units.indices {
            guard case .reinforce(let holdID)? = units[index].errand else { continue }
            if hold(holdID).map({ !areAllied(units[index].owner, $0.owner) }) ?? true {
                units[index].errand = nil
                units[index].destination = nil
            }
        }
        return events
    }

    private mutating func advance(_ rallyID: Int) -> [GameEvent] {
        guard let index = rallyIndex(rallyID) else { return [] }
        let rally = rallies![index]
        // Its cause: a caller standing and sworn, its muster still its own,
        // its target still a foe's.
        guard !houses[rally.caller].isEliminated, alliance(of: rally.caller) != nil,
              let muster = hold(rally.muster), muster.owner == rally.caller,
              let target = hold(rally.target), isAtWar(rally.caller, target.owner) else {
            return disperse(rallyID)
        }
        // Its companies: those still sent to it, of its side, and at war
        // with the hold's House.
        let host = rally.companies.filter { id in
            guard let unit = unit(id), unit.errand == .rally(rallyID) else { return false }
            return isOfRally(unit.owner, rally) && isAtWar(unit.owner, target.owner)
        }
        release(rally.companies.filter { !host.contains($0) }, from: rallyID)
        rallies![index].companies = host
        var events: [GameEvent] = []
        if !rally.marching {
            guard watch >= rally.setsOut else { return [] }
            let ready = host.filter { unit($0)!.position.distance(to: muster.position) <= 1 }
            release(host.filter { !ready.contains($0) }, from: rallyID)
            guard !ready.isEmpty else { return disperse(rallyID) }
            rallies![index].companies = ready
            rallies![index].marching = true
            for id in ready {
                units[unitIndex(id)!].destination = nil
            }
            events.append(.rallySetOut(rally: rallyID, caller: rally.caller, target: target.id, defender: target.owner, companies: ready.count))
        } else if host.isEmpty || watch - rally.setsOut > Rally.marchLimit {
            return disperse(rallyID)
        }
        return events + marchHost(rallyID, on: target)
    }

    /// The host's march this watch, and its strike once it is there.
    private mutating func marchHost(_ rallyID: Int, on target: Hold) -> [GameEvent] {
        let host = rally(rallyID)!.companies
        let pace = host.map { movement(of: unit($0)!) }.min()!
        var events: [GameEvent] = []
        var moved = false
        for id in host {
            guard let index = unitIndex(id) else { continue }
            let unit = units[index]
            guard unit.position.distance(to: target.position) > unit.kind.range,
                  let stop = path(for: unit, to: target.position)?.first(where: { $0.distance(to: target.position) <= unit.kind.range })
            else { continue }
            units[index].movesLeft = min(unit.movesLeft, pace)
            units[index].destination = stop
            let marched = march(id)
            // The host goes where the rally leads, not where it was last sent.
            if let after = unitIndex(id) { units[after].destination = nil }
            moved = moved || marched.contains { if case .moved = $0 { return true } else { return false } }
            events += marched
        }
        let inReach = host.filter { id in unit(id).map { $0.position.distance(to: target.position) <= $0.kind.range } ?? false }
        guard inReach.count == host.count || (!moved && !inReach.isEmpty) else { return events }
        return events + strikeTogether(rallyID, at: target)
    }

    /// The host strikes its hold, every company in reach in turn, arrows
    /// first: then the rally is done, whatever came of it.
    private mutating func strikeTogether(_ rallyID: Int, at target: Hold) -> [GameEvent] {
        let rally = rally(rallyID)!
        let defender = target.owner
        let order = rally.companies.enumerated().sorted { a, b in
            let reachA = unit(a.element)?.kind.range ?? 0, reachB = unit(b.element)?.kind.range ?? 0
            return (-reachA, a.offset) < (-reachB, b.offset)
        }.map(\.element)
        var events: [GameEvent] = []
        var sides: [Int] = [rally.caller]
        for id in order {
            guard let unit = unit(id), unit.position.distance(to: target.position) <= unit.kind.range,
                  hold(target.id)?.owner == defender, isAtWar(unit.owner, defender) else { continue }
            if !sides.contains(unit.owner) { sides.append(unit.owner) }
            events += assault(with: id, at: target.position)
        }
        let taken = hold(target.id).map { $0.owner != defender } ?? false
        events.append(.rallyStruck(rally: rallyID, caller: rally.caller, target: target.id, defender: defender, taken: taken))
        let host = sides.map { houses[$0].title }
        let named = host.count == 1 ? host[0] : host.dropLast().joined(separator: ", ") + " and " + host.last!
        record(.rally, sides + [defender], "A host of \(named) falls upon \(target.name)" + (taken ? " and takes it." : ", but it holds."))
        release(rally.companies, from: rallyID)
        rallies!.removeAll { $0.id == rallyID }
        return events
    }

    private mutating func disperse(_ rallyID: Int) -> [GameEvent] {
        guard let rally = rally(rallyID) else { return [] }
        release(units.filter { $0.errand == .rally(rallyID) }.map(\.id), from: rallyID)
        rallies!.removeAll { $0.id == rallyID }
        return [.rallyDispersed(rally: rallyID, caller: rally.caller)]
    }

    /// Companies sent to a rally go back to their House's orders, where
    /// they stand.
    private mutating func release(_ ids: [Int], from rallyID: Int) {
        for id in ids {
            guard let index = unitIndex(id), units[index].errand == .rally(rallyID) else { continue }
            units[index].errand = nil
            units[index].destination = nil
        }
    }
}
