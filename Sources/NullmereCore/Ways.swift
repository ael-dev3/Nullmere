import Foundation

/// A march keeps its way: found when the company sets out, and walked pace
/// by pace from then on, not sought anew at every step. It is sought again
/// only when the next step of it is shut, by a company come to stand in
/// it, a hold fallen to another House, or the wilds, and so on: then the
/// company goes round, as a march always has.
extension GameState {
    /// A company's way as kept from its last steps, if it still leads from
    /// where it stands to where it is bound.
    func keptWay(of unit: Unit) -> [Hex]? {
        guard let way = unit.way, let first = way.first, let destination = unit.destination,
              way.last == destination, first.distance(to: unit.position) == 1 else { return nil }
        return way
    }

    /// The way a company keeps to `target`, if it keeps one there and its
    /// next step is open.
    func keptWay(of unit: Unit, to target: Hex) -> [Hex]? {
        guard unit.destination == target, let way = keptWay(of: unit) else { return nil }
        return way[0] == target || !isShut(way[0], for: unit) ? way : nil
    }

    /// Whether a hex is shut to a company's march, as the search for a way
    /// goes round it: ground none may enter, another company, another
    /// House's hold, the wilds or their lair, or another alliance's hall or
    /// storehouse.
    func isShut(_ hex: Hex, for unit: Unit) -> Bool {
        guard let tile = map.index(of: hex), map.steps[tile] != 0 else { return true }
        if let other = self.unit(at: hex), other.id != unit.id { return true }
        if let hold = hold(at: hex), hold.owner != unit.owner { return true }
        if wild(at: hex) != nil || lair(at: hex) != nil { return true }
        if let hall = hall(at: hex), !isOfHall(unit.owner, hall) { return true }
        if let storehouse = storehouse(at: hex), !isOf(storehouse.alliance, unit.owner) { return true }
        return false
    }
}
