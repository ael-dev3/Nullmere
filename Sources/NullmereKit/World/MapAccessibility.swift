import Foundation
import NullmereCore

/// The map as VoiceOver reads it: one element for each hold the player
/// knows of and each company they can see, the player's own first, each
/// saying what it is, whose, and its state, and selecting it when chosen.
enum MapAccessibility {
    struct Item: Identifiable, Equatable {
        let id: String
        let label: String
        let selection: GameSession.Selection
        /// Where it lies: VoiceOver's cursor rings it there.
        let hex: Hex
        /// For a company of the player's: where VoiceOver can send it, each
        /// as an action on it, as a right-click would.
        var orders: [Order] = []
        /// What VoiceOver's rotors find it as: the keeper's own company, a
        /// foe's (at war), or a hold.
        var isOwnCompany = false
        var isFoe = false
        var isHold = false
    }

    struct Order: Equatable, Hashable {
        let name: String
        let hex: Hex
        /// Found a hold where the company stands, rather than go to `hex`.
        var founds = false
    }

    /// The most orders offered for one company.
    static let ordersOffered = 8

    /// How wide VoiceOver's cursor rings a hold or a company: about a hex,
    /// and never less than can be clicked.
    static func ring(at scale: Double) -> CGFloat {
        CGFloat(max(scale * 1.6, 24))
    }

    /// Which way one hex lies from another, as a compass would say it:
    /// north is up the map.
    static func direction(from origin: Hex, to target: Hex) -> String {
        let layout = HexLayout(size: 1)
        let a = layout.center(of: origin), b = layout.center(of: target)
        let angle = atan2(-(b.y - a.y), b.x - a.x) * 180 / .pi
        let names = ["east", "north-east", "north", "north-west", "west", "south-west", "south", "south-east"]
        let sector = Int(((angle + 360 + 22.5).truncatingRemainder(dividingBy: 360)) / 45)
        return names[sector % 8]
    }

    /// "3 tiles north-east"; "beside it, south".
    static func way(from origin: Hex, to target: Hex) -> String {
        let distance = origin.distance(to: target)
        let direction = direction(from: origin, to: target)
        return distance == 1 ? "beside it, \(direction)" : "\(distance) tiles \(direction)"
    }

    /// An order chosen from VoiceOver's actions on a company: given as a
    /// right-click would give it, and, carried out, said so. (A refusal
    /// says itself, as a notice.)
    @MainActor
    static func carryOut(_ order: Order, for item: Item, in session: GameSession) {
        session.selection = item.selection
        let before = session.selectedUnit
        if order.founds, case .unit(let id) = item.selection {
            session.perform(.found(unit: id))
        } else {
            session.order(order.hex)
        }
        let after = session.selectedUnit
        if before != after || (order.founds && after == nil) {
            session.sayNow("Done: \(order.name.prefix { $0 != "," && $0 != ":" }).")
        }
    }

    /// What a strike would do, as the forecast card says it.
    static func odds(_ forecast: Forecast) -> String {
        func range(_ r: ClosedRange<Int>) -> String { r.lowerBound == r.upperBound ? "\(r.lowerBound)" : "\(r.lowerBound) to \(r.upperBound)" }
        var parts: [String] = []
        if case .hold = forecast.target {
            parts.append("the ward loses \(range(forecast.dealt)) of \(forecast.defenderHealth)")
        } else {
            parts.append("they take \(range(forecast.dealt)) of \(forecast.defenderHealth)")
        }
        parts.append(forecast.taken.upperBound > 0 ? "you take \(range(forecast.taken)) of \(forecast.attackerHealth)" : "out of their reach")
        if case .hold = forecast.target {
            if forecast.surelyFinishes { parts.append(forecast.couldCapture ? "the hold is taken" : "the ward breaks") }
            else if forecast.mayFinish { parts.append("the ward may break") }
        } else if forecast.surelyFinishes {
            parts.append(forecast.couldCapture ? "they fall and the hold is taken" : forecast.takesTheField ? "they fall and you take their ground" : "they fall")
        } else if forecast.mayFinish {
            parts.append("they may fall")
        }
        if forecast.mayFall { parts.append("you may fall") }
        return parts.joined(separator: "; ")
    }

    @MainActor
    static func items(for session: GameSession, withOrders: Bool = true) -> [Item] {
        let state = session.state
        let player = session.player
        func whose(_ owner: Int) -> String {
            owner == player ? "yours" : state.houses[owner].title
        }
        func place(_ hex: Hex) -> String {
            if let hold = state.hold(at: hex) { return "at \(hold.name)" }
            if let terrain = state.map[hex]?.terrain { return "on \(terrain.title.lowercased())" }
            return ""
        }

        func orders(for unit: Unit, in session: GameSession) -> [Order] {
            var offered: [Order] = []
            // Foes it can strike now, with the odds the forecast gives.
            for hex in state.strikeTargets(of: unit).sorted(by: { unit.position.distance(to: $0) < unit.position.distance(to: $1) }) {
                let what = state.hold(at: hex).map { $0.name } ?? state.unit(at: hex).map { "the \($0.kind.title) of \(state.houses[$0.owner].title)" }
                    ?? state.wild(at: hex).map { HoverInfo.named($0) } ?? "the enemy"
                let odds = state.forecast(unit: unit.id, at: hex).map { ": " + MapAccessibility.odds($0) } ?? ""
                offered.append(Order(name: "Strike \(what), \(way(from: unit.position, to: hex))\(odds)", hex: hex))
            }
            // A company of war: the nearest site of the land it may work.
            if unit.kind.isMilitary, let site = state.sitesInLand
                .filter({ state.wild(at: $0.position) == nil && state.gatherRefusal(unit.id, at: $0.id, as: player) == nil })
                .min(by: { (unit.position.distance(to: $0.position), $0.id) < (unit.position.distance(to: $1.position), $1.id) }) {
                offered.append(Order(name: "Gather at the \(HoverInfo.named(site, in: state)), \(way(from: unit.position, to: site.position))",
                                     hex: site.position))
            }
            // A founder: found here, or go to the best site it knows of.
            if unit.kind == .founder {
                if state.canFound(at: unit.position, for: player) == nil {
                    offered.append(Order(name: "Found a hold here", hex: unit.position, founds: true))
                } else if let site = state.bestFoundingSite(for: player, from: unit.position), site != unit.position {
                    offered.append(Order(name: "March to a site to found a hold, \(way(from: unit.position, to: site)), \(place(site))", hex: site))
                }
            }
            // Into the unknown: the nearest known ground, a march of one
            // watch or several, that borders country not yet seen.
            let frontier = unit.position.spiral(12).filter { hex in
                hex != unit.position && session.isExplored(hex) && state.map[hex]?.terrain.isPassable == true
                    && state.unit(at: hex) == nil && state.map.neighbors(of: hex).contains { !session.isExplored($0) }
            }.sorted { (unit.position.distance(to: $0), $0) < (unit.position.distance(to: $1), $1) }
            if let edge = frontier.prefix(8).first(where: { state.path(for: unit, to: $0) != nil }) {
                offered.append(Order(name: "Explore towards the unknown, \(way(from: unit.position, to: edge))", hex: edge))
            }
            // The nearest holds it knows of.
            let known = state.holds
                .filter { session.isExplored($0.position) && $0.position != unit.position }
                .sorted { (unit.position.distance(to: $0.position), $0.id) < (unit.position.distance(to: $1.position), $1.id) }
            for hold in known where !offered.contains(where: { $0.hex == hold.position }) {
                offered.append(Order(name: "March to \(hold.name), \(way(from: unit.position, to: hold.position))", hex: hold.position))
            }
            return Array(offered.prefix(ordersOffered))
        }

        var holds: [Item] = []
        for hold in state.holds where session.isExplored(hold.position) {
            var parts = ["\(hold.name), \(hold.isSeat ? "seat" : "hold"), \(whose(hold.owner))"]
            if hold.owner == player || session.isVisible(hold.position) {
                parts.append("ward \(hold.ward) of \(hold.maximumWard)")
            }
            if let project = hold.project, hold.owner == player {
                parts.append("raising \(project.kind.title)")
            } else if hold.owner == player {
                parts.append("idle")
            }
            if hold.level(.moonspire) > 0 { parts.append("Moonspire stage \(hold.level(.moonspire))") }
            holds.append(Item(id: "hold-\(hold.id)", label: parts.joined(separator: ", "), selection: .hold(hold.id), hex: hold.position,
                              isHold: true))
        }

        var companies: [Item] = []
        for unit in state.units where unit.owner == player || session.isVisible(unit.position) {
            let rank = unit.rank > 0 ? "\(Unit.rankTitles[unit.rank]) " : ""
            var parts = ["\(rank)\(unit.kind.title), \(whose(unit.owner)), \(place(unit.position))", "health \(unit.health)"]
            if unit.kind.hasTiers { parts.append("tier \(unit.tier)") }
            if state.field(of: unit.id) != nil { parts.append("in battle") }
            if unit.owner == player {
                if unit.fortified { parts.append("fortified") }
                else if unit.destination != nil { parts.append("marching") }
                else if unit.movesLeft > 0 { parts.append("\(unit.movesLeft) moves left, awaiting orders") }
                else { parts.append("no moves left") }
            }
            companies.append(Item(id: "unit-\(unit.id)", label: parts.joined(separator: ", "), selection: .unit(unit.id), hex: unit.position,
                                  orders: withOrders && unit.owner == player && unit.movesLeft > 0 ? orders(for: unit, in: session) : [],
                                  isOwnCompany: unit.owner == player, isFoe: unit.owner != player && state.isAtWar(player, unit.owner)))
        }

        // The wilds in sight, and the sites of the land the House has found.
        var land: [Item] = []
        for wild in state.wildsStanding where session.isVisible(wild.position) {
            land.append(Item(id: "wild-\(wild.id)", label: "\(HoverInfo.named(wild)), of the wilds, \(place(wild.position))",
                             selection: .tile(wild.position), hex: wild.position, isFoe: true))
        }
        for site in state.sitesInLand where session.isExplored(site.position) && state.wild(at: site.position) == nil {
            land.append(Item(id: "site-\(site.id)", label: "\(HoverInfo.named(site, in: state)), \(place(site.position))",
                             selection: .tile(site.position), hex: site.position))
        }
        // The fields of battle in sight, or that the House fights in.
        for field in state.fieldsOfBattle {
            land.append(Item(id: "field-\(field.id)", label: "\(HoverInfo.named(field, in: state)), \(place(field.at))",
                             selection: .tile(field.at), hex: field.at))
        }
        // The alliances' storehouses on ground it has explored.
        for storehouse in state.storehousesStanding where session.isExplored(storehouse.position) {
            land.append(Item(id: "storehouse-\(storehouse.id)", label: "\(HoverInfo.named(storehouse, in: state)), \(place(storehouse.position))",
                             selection: .tile(storehouse.position), hex: storehouse.position))
        }

        func mineFirst(_ items: [Item]) -> [Item] {
            items.filter { $0.label.contains(", yours") } + items.filter { !$0.label.contains(", yours") }
        }
        return mineFirst(holds) + mineFirst(companies) + land
    }
}
