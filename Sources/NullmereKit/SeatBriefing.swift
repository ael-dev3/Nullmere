import Foundation
import NullmereCore

/// The first time a keeper takes up their House in an age: what they hold,
/// where they stand, and what to do first. The stewards may have kept the
/// House for many watches, at war or in pacts the keeper never chose.
struct SeatBriefing: Equatable {
    let title: String
    /// What the House is and has, a line each.
    let facts: [String]
    /// The first things to do, in order.
    let steps: [String]

    init(world: GameState, player: Int) {
        let house = world.houses[player]
        title = "You take up \(house.title)"
        var facts: [String] = []
        let holds = world.holds(of: player)
        if let seat = world.seat(of: player) {
            let others = holds.count - 1
            facts.append(others == 0 ? "Your seat is \(seat.name), by the still water."
                                     : "Your seat is \(seat.name), with \(others == 1 ? "one hold" : "\(others) holds") besides.")
        }
        if world.watch > 1 {
            facts.append("The age is at watch \(world.watch); the stewards kept your House until now.")
        }
        let living = world.livingHouses
        let mine = world.strength(of: player)
        let stronger = living.filter { world.strength(of: $0.id) > mine }.count
        let even = living.filter { $0.id != player && world.strength(of: $0.id) == mine }.count
        facts.append(stronger == 0 && even > 0
            ? "Of \(living.count) Houses around the lake, none is stronger than yours."
            : "Of \(living.count) Houses around the lake, yours is \(SeatBriefing.ordinal(stronger + 1)) in strength.")
        let wars = living.filter { $0.id != player && world.stance(player, $0.id) == .war }.map(\.title)
        let pacts = living.filter { $0.id != player && world.stance(player, $0.id) == .pact }.map(\.title)
        facts.append(wars.isEmpty ? "You are at war with no one." : "You are at war with \(SeatBriefing.list(wars)).")
        if !pacts.isEmpty { facts.append("You stand in a pact with \(SeatBriefing.list(pacts)).") }
        if let omen = world.currentOmen {
            facts.append("An omen lies on the realm, \(omen.kind.title): \(omen.kind.effect)")
        }
        self.facts = facts

        var steps: [String] = []
        let idle = holds.filter { $0.project == nil }.count
        if idle > 0 {
            steps.append(idle == 1 ? "Give your hold a work to build: select it, and choose one." : "Give each of your \(idle) idle holds a work to build.")
        }
        steps.append("Select a company (Tab), then right-click where it should go. Lanterns find what lies in the mist.")
        steps.append("When your orders are given, say you're ready (⌘↩). The watch turns when every keeper is ready, or when its time runs out.")
        self.steps = steps
    }

    static func ordinal(_ n: Int) -> String {
        let words = ["first", "second", "third", "fourth", "fifth", "sixth", "seventh", "eighth", "ninth", "tenth", "eleventh", "twelfth"]
        return n >= 1 && n <= words.count ? words[n - 1] : "\(n)th"
    }

    static func list(_ names: [String]) -> String {
        switch names.count {
        case 0: return ""
        case 1: return names[0]
        default: return names.dropLast().joined(separator: ", ") + " and " + names.last!
        }
    }
}
