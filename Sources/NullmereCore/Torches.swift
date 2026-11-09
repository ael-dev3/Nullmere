/// Torches on the march (an invention of Nullmere's own). Every company
/// carries its torches through the night, and every House whose sight
/// reaches it sees it. Its keeper may have it douse them: it marches dark, a
/// tile less each watch (never fewer than one), and another House sees it
/// only close by, within a tile of a company or hold that House or its
/// allies have; its own House and its allies see it as ever, and its moves
/// are told to another House only where it is seen so. The dark hides it
/// from eyes, not ears: a Beacon still warns of it bound for its hold, and
/// listening stones still hear it. Its keeper lights the torches again with
/// a word. Stewards march with their torches lit, so a world they play
/// alone is the same with this as without it.
extension GameState {
    /// How close another House must be to see a company marching dark: a
    /// tile from what it sees from.
    public static let darkSight = 1

    /// Whether the company marches dark, its torches doused.
    public func isUnlit(_ id: Int) -> Bool {
        guard let unlit, !unlit.isEmpty else { return false }
        return GameState.sortedContains(unlit, id)
    }

    /// Whether an ordered list holds a number, by halving.
    static func sortedContains(_ list: [Int], _ value: Int) -> Bool {
        var low = 0, high = list.count
        while low < high {
            let middle = (low + high) / 2
            if list[middle] < value { low = middle + 1 } else { high = middle }
        }
        return low < list.count && list[low] == value
    }

    /// Why a company can't douse its torches (`lit` false) or light them
    /// (`lit` true), if it can't: only its own House orders it, and only
    /// to change what it does.
    public func torchRefusal(_ id: Int, lit: Bool, as house: Int) -> RuleError? {
        guard outcome == nil else { return .gameOver }
        guard let unit = unit(id) else { return .unknownUnit }
        guard unit.owner == house else { return .notYours }
        guard isUnlit(id) == lit else { return .torchesAlready(lit: lit) }
        return nil
    }

    /// A company douses its torches, its moves this watch no more than a
    /// company marching dark has; or lights them again, for the watches
    /// after.
    mutating func setTorches(_ id: Int, lit: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = torchRefusal(id, lit: lit, as: house) { throw refusal }
        guard let index = unitIndex(id) else { throw .unknownUnit }
        var dark = unlit ?? []
        if lit {
            dark.removeAll { $0 == id }
        } else {
            dark.append(id)
            dark.sort()
        }
        unlit = dark.isEmpty ? nil : dark
        // Its torches lit, it lies in wait no more.
        if lit { stopWaiting(id) }
        if !lit { units[index].movesLeft = min(units[index].movesLeft, movement(of: units[index])) }
        return [.torchesSet(unit: id, lit: lit, owner: house)]
    }

    /// As the watch turns, the companies gone from the realm are forgotten
    /// among those marching dark.
    mutating func forgetTheUnlitGone() {
        guard let dark = unlit else { return }
        let kept = dark.filter { unitIndex($0) != nil }
        unlit = kept.isEmpty ? nil : kept
    }

    /// Each tile a House sees close enough to make out a company marching
    /// dark, by its index: within `darkSight` of a company or hold of its
    /// own or its allies', or lit by one of their watchfires.
    func closeSight(for house: Int) -> [Bool] {
        var close = [Bool](repeating: false, count: map.count)
        for watcher in watchers(for: house) {
            for index in units.places(of: watcher) {
                map.forEachIndex(within: GameState.darkSight, of: units[index].position) { close[$0] = true }
            }
            for index in holds.places(of: watcher) {
                map.forEachIndex(within: GameState.darkSight, of: holds[index].position) { close[$0] = true }
            }
        }
        // And all the ground each of their watchfires lights.
        for fire in watchfiresLighting(for: house) {
            map.forEachIndex(within: Watchfire.reach, of: fire.at) { close[$0] = true }
        }
        return close
    }

    /// The companies of the Houses whose sight a House doesn't share that
    /// march dark: those it sees only close by.
    func darkTo(_ house: Int) -> Set<Int> {
        guard let dark = unlit, !dark.isEmpty else { return [] }
        let watching = Set(watchers(for: house))
        return Set(dark.filter { id in unit(id).map { !watching.contains($0.owner) } ?? false })
    }
}
