/// What an alliance keeps of its own, in one wording for the Mac's
/// Alliance panel and the phone: its standards, hall, coffers, storehouse
/// and yards, and what a House has laid up in the storehouse.
extension GameState {
    /// The alliance's standards, as many as it may keep, and how to raise one.
    public func standardsSaid(of alliance: Alliance) -> String {
        let raised = standards(of: alliance.id).count
        let allowed = standardsAllowed(for: alliance)
        return "Standards: \(raised) of \(allowed). Raise one on open ground near your alliance's holds, chosen on the map; "
            + "the land about it is the alliance's."
    }

    /// The alliance's hall: none yet and how one is begun, rising, or
    /// whole, with its ward.
    public func hallSaid(of alliance: Alliance) -> String {
        guard let hall = hall(of: alliance.id) else {
            return "Hall: none yet. Its leader begins it on the alliance's land, chosen on the map, for \(AllianceHall.cost); "
                + "it rises over \(AllianceHall.raising) watches."
        }
        let place = placeName(of: hall.position)
        guard hall.isWhole else {
            return "Hall: rising \(place), \(hall.built) of \(AllianceHall.raising) watches done; its ward \(hall.ward) of \(hall.wardLimit)."
        }
        return "Hall: standing \(place), its ward \(hall.ward) of \(AllianceHall.maximumWard). Its land reaches \(AllianceHall.reach) tiles, "
            + "your rallies take \(AllianceHall.rallyCompanies) more companies, and the alliance may keep \(AllianceHall.standards) more standards."
    }

    /// The alliance's coffers: what they hold, what its land yields them
    /// each watch, and what they pay for.
    public func coffersSaid(of alliance: Alliance) -> String {
        let yield = coffersYield(of: alliance.id)
        return "Coffers: \(alliance.stores.isZero ? "nothing yet" : alliance.stores.description). Its land yields them "
            + "\(yield.isZero ? "nothing yet" : yield.description) a watch, and its yards a tithe; they pay first for its standards, "
            + "hall, storehouse and yards, its Houses the rest."
    }

    /// The alliance's storehouse: none yet and how one is raised, rising,
    /// or standing with its ward.
    public func storehouseSaid(of alliance: Alliance) -> String {
        guard let storehouse = storehouse(of: alliance.id) else {
            return "Storehouse: none yet. Its leader raises it on the alliance's land, chosen on the map, for \(Storehouse.cost); "
                + "it rises over \(Storehouse.raising) watches."
        }
        let place = placeName(of: storehouse.position)
        guard storehouse.isWhole else {
            return "Storehouse: rising \(place), \(storehouse.built) of \(Storehouse.raising) watches done; "
                + "its ward \(storehouse.ward) of \(Storehouse.maximumWard)."
        }
        return "Storehouse: standing \(place), its ward \(storehouse.ward) of \(Storehouse.maximumWard). What you lay up there is beyond "
            + "your own storage and out of any taker's reach, unless a foe tears it down."
    }

    /// The alliance's yards, with what is left in each, or how one is raised.
    public func yardsSaid(of alliance: Alliance) -> String {
        let yards = yards(of: alliance.id)
        guard !yards.isEmpty else {
            return "Yards: none yet. Its leader raises one of each store on the alliance's land, chosen on the map, for "
                + "\(Yard.cost); its companies alone work them, \(Yard.gathering)% faster."
        }
        return "Yards: " + yards.map { "the \($0.title), \($0.remaining) \($0.store.title.lowercased()) left" }.joined(separator: "; ") + "."
    }
}

extension Storehouse {
    /// What a House has laid up in its alliance's storehouse, and its room.
    public static func laidUpSaid(_ laid: Stock) -> String {
        let room = "as much as \(Storehouse.room)"
        return laid.isZero ? "You have laid up nothing yet: \(room), out of any taker's reach." : "You have laid up \(laid), of \(room)."
    }

    /// What a House lays up or takes back at a time.
    public static let measures = [Stock(grain: 100), Stock(timber: 100), Stock(stone: 100), Stock(moonsalt: 10)]
}
