/// Lying in wait (an invention of Nullmere's own, the march in the dark's
/// own blow). A keeper's company of war marching dark, its torches doused,
/// that stands in the blackwood and is not on the march may lie in wait
/// there: the first company of a House at war with its own that comes
/// within its reach, at any pace of the watch or as it turns, it springs
/// upon at once, striking as an order to strike would, and the waiting is
/// done. It waits no longer once it marches, lights its torches or the
/// wood about it is burnt. Only its own House knows it waits; a watchfire's
/// light makes it out like any company marching dark. Stewards lie in wait
/// for none, so a world they play alone is the same with this as without
/// it.
extension GameState {
    /// Whether a company lies in wait.
    public func isWaiting(_ id: Int) -> Bool {
        guard let waiting, !waiting.isEmpty else { return false }
        return GameState.sortedContains(waiting, id)
    }

    /// Whether a company may hide in the wood at `hex`: the blackwood,
    /// not burnt to ash.
    public func isCover(_ hex: Hex) -> Bool {
        isBlackwood(hex) && !ash.contains(hex)
    }

    /// Why a company can't lie in wait (`waiting` true) or give it up
    /// (`waiting` false), if it can't: only its own House orders it, only
    /// a company of war marching dark in the blackwood and not on the
    /// march lies in wait, and only to change what it does.
    public func waitRefusal(_ id: Int, waiting: Bool, as house: Int) -> RuleError? {
        guard outcome == nil else { return .gameOver }
        guard let unit = unit(id) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard isWaiting(id) != waiting else { return .waitingAlready(waiting) }
        guard waiting else { return nil }
        guard unit.kind.isMilitary else { return .cannotFight }
        guard isUnlit(id) else { return .notMarchingDark }
        guard isCover(unit.position) else { return .notInTheWood }
        guard unit.destination == nil else { return .onTheMarch }
        return nil
    }

    /// A company lies in wait where it stands, or gives it up.
    mutating func setWaiting(_ id: Int, waiting lying: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = waitRefusal(id, waiting: lying, as: house) { throw refusal }
        var list = waiting ?? []
        if lying {
            list.append(id)
            list.sort()
        } else {
            list.removeAll { $0 == id }
        }
        waiting = list.isEmpty ? nil : list
        return [.waitSet(unit: id, waiting: lying, owner: house)]
    }

    /// A company ordered on or carrying its torches again waits no more.
    mutating func stopWaiting(_ id: Int) {
        guard let list = waiting, GameState.sortedContains(list, id) else { return }
        let kept = list.filter { $0 != id }
        waiting = kept.isEmpty ? nil : kept
    }

    /// The companies of Houses at war with `unit`'s within its reach, out
    /// on the land rather than behind a hold's walls, the nearest first.
    func foesInReach(of unit: Unit) -> [Unit] {
        var found: [Unit] = []
        for hex in unit.position.spiral(max(unit.kind.range, 1)) where hex != unit.position && hold(at: hex) == nil {
            for id in units.ids(at: hex) {
                guard let other = self.unit(id), other.owner != unit.owner, houses.indices.contains(other.owner),
                      isAtWar(unit.owner, other.owner) else { continue }
                found.append(other)
            }
        }
        return found.sorted {
            ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id)
        }
    }

    /// Each company lying in wait springs upon the first foe within its
    /// reach that its House makes out (one marching dark only close by, as
    /// its House sees it), as an order to strike would, and waits no more;
    /// one that marches, carries its torches again or stands in wood burnt
    /// to ash waits no more either. At each pace of the watch and as it
    /// turns.
    mutating func springAmbushes() -> [GameEvent] {
        guard let lying = waiting, !lying.isEmpty else { return [] }
        var events: [GameEvent] = []
        var still: [Int] = []
        // What each House makes out marching dark, worked out once it is asked.
        var close: [Int: [Bool]] = [:]
        for id in lying {
            guard let unit = unit(id), unit.kind.isMilitary, isUnlit(id), isCover(unit.position), unit.destination == nil else { continue }
            let foe = foesInReach(of: unit).first { foe in
                guard isUnlit(foe.id) else { return true }
                if close[unit.owner] == nil { close[unit.owner] = closeSight(for: unit.owner) }
                return map.index(of: foe.position).map { close[unit.owner]?[$0] ?? false } ?? false
            }
            guard let foe, let struck = try? carryOutAmbush(id, at: foe.position, owner: unit.owner) else {
                still.append(id)
                continue
            }
            events.append(.ambushSprung(unit: id, owner: unit.owner, at: unit.position, struck: foe.id, struckOwner: foe.owner))
            events += struck
        }
        waiting = still.isEmpty ? nil : still
        return events
    }

    /// The blow an ambush strikes: the order to strike the House would
    /// give, held to the same rules.
    private mutating func carryOutAmbush(_ id: Int, at target: Hex, owner: Int) throws(RuleError) -> [GameEvent] {
        try perform(.attack(unit: id, target: target), as: owner)
    }
}
