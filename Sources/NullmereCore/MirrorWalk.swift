/// Walking the Mirror (an invention of Nullmere's): the Still is a mirror,
/// and a company of war standing on its shore may step into its own
/// reflection for moonsalt. As the watch turns the realm brings it out on
/// the far shore, where the lake would show it: its hex reflected through
/// the lake's deepest water, or the nearest open ground to that. The water
/// stills at the far shore as the walk begins, and every keeper sees it, so
/// the House that will be come upon has a watch to make ready; a false
/// reflection can now feign one. A company walks the mirror once a moon.
public struct MirrorWalk: Codable, Equatable, Sendable {
    public let unit: Int
    public let house: Int
    public let from: Hex
    /// Where it will come out, as the realm reckoned when it stepped in.
    public let to: Hex
    public let watch: Int

    /// What a walk costs the House.
    public static let price = Stock(moonsalt: 15)
    /// How far from the reflected hex the realm looks for open ground.
    public static let reach = 3
}

extension GameState {
    /// The walks under way, to come out as the watch turns.
    public var mirrorWalksUnderWay: [MirrorWalk] { mirrorWalks ?? [] }

    /// The hex the Still shows a hex at: reflected through its deepest
    /// water. Nil on a lake with none.
    public func reflection(of hex: Hex) -> Hex? {
        guard let deep = map.deepestWater()?.hex else { return nil }
        return Hex(2 * deep.q - hex.q, 2 * deep.r - hex.r)
    }

    /// Whether a hex lies on the Still's shore: land beside its shallows
    /// or its open water.
    public func isOnTheStill(_ hex: Hex) -> Bool {
        guard let tile = map[hex], !tile.terrain.isWater else { return false }
        return map.neighbors(of: hex).contains { [.still, .shallows].contains(map[$0]?.terrain) }
    }

    /// Where a walk from a hex would come out: the reflected hex if it is
    /// open shore or land, else the nearest open land within reach of it;
    /// nil if none.
    public func mirrorLanding(from hex: Hex, for unitID: Int? = nil) -> Hex? {
        guard let mirrored = reflection(of: hex) else { return nil }
        let bound = Set(mirrorWalksUnderWay.filter { $0.unit != unitID }.map(\.to))
        for radius in 0...MirrorWalk.reach {
            let ring = radius == 0 ? [mirrored] : mirrored.ring(radius)
            if let open = ring.first(where: { candidate in
                guard let tile = map[candidate], tile.terrain.isPassable, !tile.terrain.isWater else { return false }
                return unit(at: candidate) == nil && hold(at: candidate) == nil && !bound.contains(candidate)
            }) {
                return open
            }
        }
        return nil
    }

    /// The moon a watch falls in, counting from the first.
    static func moon(of watch: Int) -> Int { watch / GameState.lunarMonth }

    /// Why a company can't walk the mirror now, if it can't.
    public func mirrorRefusal(_ unitID: Int, as house: Int) -> RuleError? {
        guard let unit = unit(unitID), unit.owner == house else { return .notYours }
        guard unit.kind.isMilitary else { return .notACompanyOfWar }
        guard isOnTheStill(unit.position) else { return .notOnTheStill }
        if mirrorWalksUnderWay.contains(where: { $0.unit == unitID }) { return .mirrorWalkedThisMoon }
        if let last = mirrorWalked?[unitID], GameState.moon(of: last) == GameState.moon(of: watch) { return .mirrorWalkedThisMoon }
        guard mirrorLanding(from: unit.position, for: unitID) != nil else { return .noFarShore }
        guard houses[house].stock.covers(MirrorWalk.price) else { return .shortOf(houses[house].stock.shortfall(for: MirrorWalk.price)) }
        return nil
    }

    /// A company steps into its reflection: its moonsalt paid, the far
    /// shore stilled for all to see, the company standing in the shallows
    /// with no moves left until the watch turns.
    mutating func walkTheMirror(_ unitID: Int, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = mirrorRefusal(unitID, as: house) { throw refusal }
        let index = unitIndex(unitID)!
        let from = units[index].position
        let to = mirrorLanding(from: from, for: unitID)!
        houses[house].stock.debit(MirrorWalk.price)
        units[index].movesLeft = 0
        units[index].destination = nil
        units[index].fortified = false
        mirrorWalks = mirrorWalksUnderWay + [MirrorWalk(unit: unitID, house: house, from: from, to: to, watch: watch)]
        record(.war, [house], "\(houses[house].title)'s \(units[index].kind.title) walk the mirror.")
        return [.mirrorWalkBegun(unit: unitID, house: house, from: from, to: to)]
    }

    /// As the watch turns: each company that stepped in comes out where the
    /// water stilled, or the nearest open land now, or stays where it stood
    /// if the far shore filled.
    mutating func turnMirrorWalks() -> [GameEvent] {
        guard let walks = mirrorWalks, !walks.isEmpty else { return [] }
        mirrorWalks = nil
        var events: [GameEvent] = []
        var walked = mirrorWalked ?? [:]
        for walk in walks {
            guard let index = unitIndex(walk.unit), units[index].owner == walk.house else { continue }
            walked[walk.unit] = walk.watch
            let open: (Hex) -> Bool = { [self] hex in
                map[hex].map { $0.terrain.isPassable && !$0.terrain.isWater } == true && unit(at: hex) == nil && hold(at: hex) == nil
            }
            let landing = open(walk.to) ? walk.to : walk.to.spiral(MirrorWalk.reach).first(where: open)
            guard let at = landing else {
                events.append(.mirrorWalked(unit: walk.unit, house: walk.house, from: walk.from, to: walk.from))
                continue
            }
            units[index].position = at
            events.append(.mirrorWalked(unit: walk.unit, house: walk.house, from: walk.from, to: at))
        }
        let moon = GameState.moon(of: watch)
        mirrorWalked = walked.filter { GameState.moon(of: $0.value) == moon }.nilIfEmpty
        return events
    }
}

private extension Dictionary {
    var nilIfEmpty: Self? { isEmpty ? nil : self }
}
