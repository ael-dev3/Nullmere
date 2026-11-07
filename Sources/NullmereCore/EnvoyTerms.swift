import Foundation

/// What an envoy waiting on a keeper offers, in the words the keeper is told
/// it, on their Mac and on their phone alike; and whether they can keep it.
extension GameState {
    /// The terms an envoy carries to `player`.
    public func terms(of envoy: Envoy, for player: Int) -> String {
        let house = houses[envoy.from]
        switch envoy.proposal {
        case .trade:
            guard let trade = envoy.trade else { return "\(house.title) would trade, but its terms are lost." }
            var line = "\(house.title) offers \(trade.given) for \(trade.taken) of yours. \(Trade.note(asking: trade.asking))"
            let have = houses[player].stock[trade.take]
            if have < trade.takeAmount { line += " You have only \(have) \(trade.take.title.lowercased())." }
            return line
        case .peace:
            return "\(house.title) asks for peace. Their companies would turn from yours, and yours from theirs."
        case .pact:
            return "\(house.title) offers a pact: shared sight across the water, and no blade between you."
        case .fealty:
            return "\(house.title) is beaten and bends the knee: it would be your vassal, its holds counted with yours, never to raise a blade against you."
        case .tribute:
            let price = tribute(from: player)
            guard !house.isPlayer else {
                return "\(house.title) demands tribute: \(price), a fifth of your stores. Pay, and they can't ask again for \(GameState.tributeRespite) watches. Refuse, or send no answer, and war is theirs to choose."
            }
            return "\(house.title) demands tribute: \(price), a fifth of your stores. Pay, and it keeps the peace for \(GameState.tributeRespite) watches, unless your Moonspire rises. Refuse, or send no answer, and it marches on you."
        }
    }

    /// Whether the keeper can keep the terms: for a trade, what it asks of
    /// them is in their stores. Accepting a trade they can't pay would only
    /// send the envoy away.
    public func canKeepTerms(of envoy: Envoy, for player: Int) -> Bool {
        guard envoy.proposal == .trade, let trade = envoy.trade else { return true }
        return houses[player].stock[trade.take] >= trade.takeAmount
    }

    /// The watches an envoy still waits on its answer, this one among them.
    public func watchesWaiting(of envoy: Envoy) -> Int {
        max(Envoy.patience - (watch - envoy.arrived), 1)
    }

    /// Whether refusing an envoy is war at once: a steward's demand of tribute.
    public func refusingIsWar(_ envoy: Envoy) -> Bool {
        envoy.proposal == .tribute && !houses[envoy.from].isPlayer
    }
}

extension Trade {
    /// How terms weigh, from the side of the House that would get `asking`
    /// percent of what it gives.
    public static func note(asking: Int) -> String {
        switch asking {
        case ..<90: return "Generous: more given than asked, by barter worth."
        case 90...110: return "Even terms, by barter worth."
        default: return "More asked than given, by barter worth."
        }
    }
}

/// Companies of a House at war with another gathered near one of its holds.
public struct Gathering: Equatable, Sendable {
    public let hold: Int
    public let house: Int
    public let companies: Int
}

extension GameState {
    /// How near, in tiles, a gathering is watched for.
    public static let gatheringReach = 3
    /// How many companies of one House make a gathering.
    public static let gatheringCompanies = 2

    /// Each of the House's holds with companies of war of a House at war
    /// with it gathered near, those it `sees`, the largest House's at each.
    public func gatherings(against player: Int, sees: (Hex) -> Bool = { _ in true }) -> [Gathering] {
        var gatherings: [Gathering] = []
        for hold in holds(of: player) {
            var counts: [Int: Int] = [:]
            for unit in units where unit.kind.isMilitary && isAtWar(player, unit.owner)
                && unit.position.distance(to: hold.position) <= GameState.gatheringReach && sees(unit.position) {
                counts[unit.owner, default: 0] += 1
            }
            if let largest = counts.max(by: { ($0.value, -$0.key) < ($1.value, -$1.key) }), largest.value >= GameState.gatheringCompanies {
                gatherings.append(Gathering(hold: hold.id, house: largest.key, companies: largest.value))
            }
        }
        return gatherings
    }

    /// A gathering, as the walls' watchmen tell it.
    public func words(of gathering: Gathering) -> String {
        let hold = hold(gathering.hold)?.name ?? "your hold"
        let house = houses.indices.contains(gathering.house) ? houses[gathering.house].title : "the wilds"
        return "\(gathering.companies) companies of \(house) gather near \(hold)."
    }
}
