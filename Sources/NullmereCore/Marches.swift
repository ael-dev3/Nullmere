import Foundation

/// A company's march as a keeper may know it: the way it goes, as far as
/// they may see it, and where it is bound and when it should be there,
/// when that is theirs to know.
public struct March: Codable, Equatable, Sendable {
    public let unit: Int
    public let owner: Int
    /// The hexes it will pass, from the next step on: the whole way for a
    /// company of the keeper's own House, or of a host they know of; for
    /// another House's, only as far as the keeper sees it go.
    public let route: [Hex]
    /// Where it is bound: for the keeper's own companies, and for a host of
    /// their side or marching on a hold of theirs, the hold it marches on.
    public let destination: Hex?
    /// The watch it should be there, for a march the keeper knows the end
    /// of that outlasts this watch.
    public let arrives: Int?

    public init(unit: Int, owner: Int, route: [Hex], destination: Hex?, arrives: Int?) {
        self.unit = unit
        self.owner = owner
        self.route = route
        self.destination = destination
        self.arrives = arrives
    }

    // A way travels as its first hex and a digit for each step after, the
    // direction it goes: a keeper's view goes across the network whenever
    // it changes, and a hex written out whole is a dozen bytes.
    private enum CodingKeys: String, CodingKey {
        case unit, owner, route, way, destination, arrives
    }

    public init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        unit = try container.decode(Int.self, forKey: .unit)
        owner = try container.decode(Int.self, forKey: .owner)
        if let way = try container.decodeIfPresent(String.self, forKey: .way) {
            guard let route = March.route(fromWay: way) else {
                throw DecodingError.dataCorruptedError(forKey: .way, in: container, debugDescription: "Unreadable way")
            }
            self.route = route
        } else {
            route = try container.decode([Hex].self, forKey: .route)
        }
        destination = try container.decodeIfPresent(Hex.self, forKey: .destination)
        arrives = try container.decodeIfPresent(Int.self, forKey: .arrives)
    }

    public func encode(to encoder: any Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(unit, forKey: .unit)
        try container.encode(owner, forKey: .owner)
        if let way = March.way(of: route) {
            try container.encode(way, forKey: .way)
        } else {
            try container.encode(route, forKey: .route)
        }
        try container.encodeIfPresent(destination, forKey: .destination)
        try container.encodeIfPresent(arrives, forKey: .arrives)
    }

    /// A route as "q,r" and a digit for each step after, from 0 for east
    /// clockwise; nil for none, or for one that leaps.
    static func way(of route: [Hex]) -> String? {
        guard let first = route.first else { return nil }
        var digits = ""
        for (from, to) in zip(route, route.dropFirst()) {
            guard let direction = Hex.directions.firstIndex(of: to - from) else { return nil }
            digits.append(Character(String(direction)))
        }
        return "\(first.q),\(first.r)" + (digits.isEmpty ? "" : ":" + digits)
    }

    /// The route a way writes; nil for one unreadable.
    static func route(fromWay way: String) -> [Hex]? {
        let parts = way.split(separator: ":", maxSplits: 1, omittingEmptySubsequences: false)
        let start = parts[0].split(separator: ",", omittingEmptySubsequences: false)
        guard start.count == 2, let q = Int(start[0]), let r = Int(start[1]) else { return nil }
        var route = [Hex(q, r)]
        for digit in parts.count > 1 ? parts[1] : "" {
            guard let direction = digit.wholeNumberValue, Hex.directions.indices.contains(direction) else { return nil }
            route.append(route[route.count - 1] + Hex.directions[direction])
        }
        return route
    }
}

extension GameState {
    /// The watches a company takes to walk a route at a pace, the way a
    /// march goes as each watch turns: none for no route.
    public func watchesToWalk(_ route: [Hex], pace: Int) -> Int {
        guard !route.isEmpty else { return 0 }
        var watches = 1
        var left = pace
        for hex in route {
            let cost = map[hex]?.terrain.moveCost ?? 1
            // A company with all its moves takes a step however dear;
            // with fewer, none it can't pay for.
            if left == 0 || (left < cost && left < pace) {
                watches += 1
                left = pace
            }
            left = max(0, left - cost)
        }
        return watches
    }

    /// The marches the keeper of a House may know of now, worked out on
    /// their own view of the world, so no way bends round what they can't
    /// see: every march of their own companies, with where it ends and
    /// when; each company of a host of their side, or of one marching on a
    /// hold of theirs, with the hold and when it should be in reach; and of
    /// any other company in their sight that is on the march, the way it
    /// goes as far as they see it.
    public func marches(seenBy house: Int) -> [March] {
        view(for: house).marches ?? []
    }

    func marches(seenBy house: Int, in view: GameState) -> [March] {
        let seen = visibility(for: house)
        func inSight(_ hex: Hex) -> Bool { map.index(of: hex).map { seen[$0] } ?? false }
        var found: [March] = []
        var hosted: Set<Int> = []
        for rally in ralliesStanding where rally.marching {
            guard let target = hold(rally.target), isOfRally(house, rally) || target.owner == house else { continue }
            let walkers = rally.companies.compactMap { view.unit($0) }
            guard let pace = walkers.map({ view.movement(of: $0) }).min() else { continue }
            for unit in walkers {
                hosted.insert(unit.id)
                guard unit.position.distance(to: target.position) > unit.kind.range,
                      let way = view.path(for: unit, to: target.position) else { continue }
                let end = way.firstIndex { $0.distance(to: target.position) <= unit.kind.range } ?? way.count - 1
                let route = Array(way[...end])
                found.append(March(unit: unit.id, owner: unit.owner, route: route, destination: target.position,
                                   arrives: watch + view.watchesToWalk(route, pace: pace)))
            }
        }
        for unit in view.units.sorted(by: { $0.id < $1.id }) where !hosted.contains(unit.id) {
            guard let destination = self.unit(unit.id)?.destination else { continue }
            let way = view.path(for: unit, to: destination) ?? []
            if unit.owner == house {
                let watches = view.watchesToWalk(way, pace: view.movement(of: unit))
                found.append(March(unit: unit.id, owner: house, route: way, destination: destination,
                                   arrives: watches > 0 ? watch + watches : nil))
            } else {
                let shown = Array(way.prefix(while: inSight))
                guard !shown.isEmpty else { continue }
                found.append(March(unit: unit.id, owner: unit.owner, route: shown, destination: nil, arrives: nil))
            }
        }
        return found
    }
}
