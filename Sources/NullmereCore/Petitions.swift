/// Petitions at the gate: the folk of a keeper's hold come to its keeper
/// with a plea of their own, grounded in how the hold stands. Its ward
/// broken, its masons would mend it whole, for stone; the blackwood on its
/// land alight, its woodwards would beat the fire out, for grain; a company of the
/// House lying hurt at its gates, its healers would tend it, for grain; a
/// work or a muster under way, its reeve would lend the folk's hands to
/// bring it a watch nearer, for grain; at the full moon, the seat's
/// brewers would hold a feast, for grain, and the folk give the House a
/// Salt Hourglass in thanks. The keeper grants a plea, paying what the folk
/// ask, or turns it away; a plea left unanswered three watches is turned
/// away by silence. Turned away, the folk go back to their work grudging:
/// what the hold has under way is set back a watch. A plea whose need has
/// passed is withdrawn, owing nothing. Only keepers' Houses are petitioned,
/// one plea at a time and the next some watches after; the keeper's
/// device gives the petitioner words of their own through its on-device
/// model, from the plea's facts (`GameState.voiced(_:)`), the realm's
/// rules deciding everything.
public struct Petition: Codable, Equatable, Sendable, Identifiable {
    public enum Plea: String, Codable, CaseIterable, Sendable, PlainCases {
        /// The hold's ward under half: its masons would mend it whole.
        case mend
        /// The blackwood burning on the hold's land: its woodwards would
        /// beat the fire out.
        case douse
        /// A company of the House hurt at the hold: its healers would tend it.
        case tend
        /// A work or a muster two watches or more from done: the folk would
        /// lend their hands to bring it a watch nearer.
        case hands
        /// The full moon at the seat: its brewers would hold a feast.
        case feast

        /// Who brings a plea of this kind.
        public var trade: String {
            switch self {
            case .mend: return "a mason"
            case .douse: return "a woodward"
            case .tend: return "a healer"
            case .hands: return "the reeve"
            case .feast: return "a brewer"
            }
        }
    }

    public let id: Int
    public let house: Int
    public let hold: Int
    public let plea: Plea
    /// The watch it was brought.
    public let arrived: Int
    /// The petitioner's own name.
    public let name: String
    /// What the folk ask of the House's stores.
    public let price: Stock
    /// The company a healer would tend.
    public let unit: Int?

    public init(id: Int, house: Int, hold: Int, plea: Plea, arrived: Int, name: String, price: Stock, unit: Int? = nil) {
        self.id = id
        self.house = house
        self.hold = hold
        self.plea = plea
        self.arrived = arrived
        self.name = name
        self.price = price
        self.unit = unit
    }

    /// Watches a plea waits for its answer before silence turns it away.
    public static let patience = 3
    /// Watches between one plea brought to a House and the next.
    public static let every = 8
    /// The first watch a plea may come.
    public static let from = 6
    /// A company below so much of its strength is hurt enough to be tended.
    public static let hurt = 70

    /// The names the folk go by.
    static let names = ["Edda", "Osric", "Wenna", "Brand", "Hild", "Corwin", "Ysolde", "Tam", "Maud", "Alder", "Rowan", "Gisla",
                        "Aldous", "Bryony", "Cuthbert", "Elspeth"]
}

extension GameState {
    /// The plea waiting on a House's answer, if one is.
    public func petition(of house: Int) -> Petition? {
        petitions?.first { $0.house == house }
    }

    /// Who brings a plea, as the House hears it: "Edda, a mason of Wenholme".
    public func petitioner(of petition: Petition) -> String {
        "\(petition.name), \(petition.plea.trade) of \(hold(petition.hold)?.name ?? "a hold")"
    }

    /// What a plea asks, as the House hears it, and what granting it does.
    public func asked(by petition: Petition) -> String {
        let place = hold(petition.hold)?.name ?? "the hold"
        let price = "For \(petition.price)"
        switch petition.plea {
        case .mend:
            let ward = hold(petition.hold).map { " (\($0.ward) of \($0.maximumWard))" } ?? ""
            return "\(place)'s ward is broken\(ward). \(price), its masons will mend it whole."
        case .douse:
            let alight = hold(petition.hold).map { burningLand(of: $0).count } ?? 0
            guard alight > 0 else { return "The blackwood on \(place)'s land burns no longer." }
            let tiles = alight == 1 ? "a tile" : "\(GameState.counted(alight)) tiles"
            return "Fire burns in the blackwood on \(tiles) of \(place)'s land, and \(windSaid). \(price), its woodwards will beat it out."
        case .tend:
            let company = petition.unit.flatMap { unit($0) }.map { "your \(named($0.kind, tier: $0.tier, of: $0.owner))" } ?? "your company"
            let strength = petition.unit.flatMap { unit($0) }.map { ", at \($0.health) of its strength," } ?? ""
            return "\(company.lineBegun) lies hurt at \(place)'s gates\(strength). \(price), its healers will tend it by \(GameState.draughtMending)."
        case .hands:
            return "\(place)'s folk would lend their hands to what it has under way. \(price), it comes a watch nearer."
        case .feast:
            return "The moon is full over \(place), and its folk would feast. \(price), they give your House a \(ItemKind.hourglass.title) in thanks."
        }
    }

    /// What turning a plea away costs, as the House hears it.
    public static let turnedAwaySaid = "Turned away, the folk go back to their work grudging: what the hold has under way is set back a watch."

    /// The plea a House's hold would bring now, the most pressing first: a
    /// broken ward, the blackwood alight on its land, a company hurt at its
    /// gates, hands for a work or muster, and at the full moon a feast at
    /// the seat; nil if none.
    func plea(for house: Int) -> (hold: Hold, plea: Petition.Plea, price: Stock, unit: Int?)? {
        let holds = holds(of: house).sorted { $0.id < $1.id }
        if let broken = holds.filter({ $0.ward * 2 < $0.maximumWard })
            .min(by: { ($0.ward * 100 / max($0.maximumWard, 1), $0.id) < ($1.ward * 100 / max($1.maximumWard, 1), $1.id) }) {
            return (broken, .mend, Stock(stone: 10 + 10 * broken.level(.walls)), nil)
        }
        if wildfires?.contains(where: { $0.isBurning(at: watch) }) == true {
            let owners = territory()
            for hold in holds {
                let alight = burningLand(of: hold, territory: owners).count
                if alight > 0 { return (hold, .douse, Stock(grain: min(20 + 5 * alight, 60)), nil) }
            }
        }
        let hurt = units(of: house).filter { $0.health < Petition.hurt }.sorted { ($0.health, $0.id) < ($1.health, $1.id) }
        for unit in hurt {
            if let hold = holds.first(where: { $0.position == unit.position }) { return (hold, .tend, Stock(grain: 30), unit.id) }
        }
        if let busy = holds.first(where: { ($0.project?.watchesLeft ?? 0) > 1 || ($0.training?.watchesLeft ?? 0) > 1 }) {
            return (busy, .hands, Stock(grain: 40), nil)
        }
        if GameState.moonAge(at: watch) == 0, let seat = holds.first(where: \.isSeat) {
            return (seat, .feast, Stock(grain: 60), nil)
        }
        return nil
    }

    /// Whether a plea's need still stands: the ward still broken, the
    /// company still the House's and hurt, something still to bring
    /// nearer; a feast's while its hold is the House's.
    func stillNeeded(_ petition: Petition) -> Bool {
        guard let hold = hold(petition.hold), hold.owner == petition.house else { return false }
        switch petition.plea {
        case .mend: return hold.ward < hold.maximumWard
        case .douse: return !burningLand(of: hold).isEmpty
        case .tend: return petition.unit.flatMap { unit($0) }.map { $0.owner == petition.house && $0.health < 100 } ?? false
        case .hands: return (hold.project?.watchesLeft ?? 0) > 1 || (hold.training?.watchesLeft ?? 0) > 1
        case .feast: return true
        }
    }

    /// As a realm's watch turns (`RealmState`, the Mac's own realm as the
    /// steward's): pleas whose need has passed withdrawn; those unanswered
    /// too long turned away by silence; and a new plea brought to each
    /// keeper's House with none waiting, once enough watches have passed
    /// since its last. A world played wholly by stewards, outside a realm,
    /// has no one to hear them, and none come.
    public mutating func bringPetitions() -> [GameEvent] {
        guard outcome == nil else { return [] }
        var events: [GameEvent] = []
        for petition in petitions ?? [] {
            let keeper = houses.indices.contains(petition.house) && houses[petition.house].isPlayer && !houses[petition.house].isEliminated
            if !keeper || !stillNeeded(petition) {
                petitions?.removeAll { $0.id == petition.id }
                if keeper { events.append(.petitionWithdrawn(petition)) }
            } else if watch - petition.arrived >= Petition.patience {
                events += turnAway(petition, silently: true)
            }
        }
        if petitions?.isEmpty == true { petitions = nil }
        guard watch >= Petition.from else { return events }
        for house in houses where house.isPlayer && !house.isEliminated && petition(of: house.id) == nil {
            if let last = petitioned?[house.id], watch - last < Petition.every { continue }
            guard let (hold, plea, price, unit) = plea(for: house.id) else { continue }
            let id = takeID()
            let name = Petition.names[(id &* 31 &+ house.id &* 7 &+ watch) % Petition.names.count]
            let petition = Petition(id: id, house: house.id, hold: hold.id, plea: plea, arrived: watch, name: name, price: price, unit: unit)
            petitions = (petitions ?? []) + [petition]
            petitioned = (petitioned ?? [:]).merging([house.id: watch]) { $1 }
            events.append(.petitionBrought(petition))
        }
        return events
    }

    /// Why a House can't answer a plea so now, if it can't.
    public func petitionRefusal(_ id: Int, grant: Bool, as house: Int) -> RuleError? {
        guard houses.indices.contains(house), houses[house].isPlayer else { return .notAKeeper }
        guard let petition = petitions?.first(where: { $0.id == id }), petition.house == house else { return .notApplicable }
        guard grant else { return nil }
        guard stillNeeded(petition) else { return .notApplicable }
        guard houses[house].stock.covers(petition.price) else { return .shortOf(houses[house].stock.shortfall(for: petition.price)) }
        return nil
    }

    /// A keeper answers their House's plea: granted, paid for and done;
    /// turned away, the hold set back.
    mutating func answerPetition(_ id: Int, grant: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        if let refusal = petitionRefusal(id, grant: grant, as: house) { throw refusal }
        let petition = petitions!.first { $0.id == id }!
        guard grant else { return turnAway(petition, silently: false) }
        houses[house].stock.debit(petition.price)
        petitions?.removeAll { $0.id == id }
        if petitions?.isEmpty == true { petitions = nil }
        rememberPlea(petition, granted: true, silently: false)
        var events: [GameEvent] = [.petitionAnswered(petition, granted: true, silently: false)]
        switch petition.plea {
        case .mend:
            if let index = holdIndex(petition.hold) { holds[index].ward = holds[index].maximumWard }
        case .douse:
            // Every fire on the hold's land beaten out: the wood it has
            // burnt so far lies as ash, and it spreads no further.
            if let hold = hold(petition.hold) {
                let alight = Set(burningLand(of: hold))
                for index in (wildfires ?? []).indices where alight.contains(wildfires![index].at) && wildfires![index].isBurning(at: watch) {
                    wildfires![index].out = watch
                }
            }
        case .tend:
            if let unit = petition.unit, let index = unitIndex(unit) {
                units[index].health = min(100, units[index].health + GameState.draughtMending)
            }
        case .hands:
            hastenWork(at: petition.hold)
        case .feast:
            events += give(.hourglass, to: house)
        }
        return events
    }

    /// A plea turned away, by the keeper or by silence: what its hold has
    /// under way set back a watch.
    private mutating func turnAway(_ petition: Petition, silently: Bool) -> [GameEvent] {
        petitions?.removeAll { $0.id == petition.id }
        if petitions?.isEmpty == true { petitions = nil }
        rememberPlea(petition, granted: false, silently: silently)
        if let index = holdIndex(petition.hold), holds[index].owner == petition.house {
            holds[index].project?.watchesLeft += 1
            holds[index].training?.watchesLeft += 1
        }
        return [.petitionAnswered(petition, granted: false, silently: silently)]
    }

    /// The tiles of a hold's land where the blackwood burns now.
    func burningLand(of hold: Hold, territory owners: [Int?]? = nil) -> [Hex] {
        guard let fires = wildfires, fires.contains(where: { $0.isBurning(at: watch) }) else { return [] }
        let owners = owners ?? territory()
        return fires.filter { fire in
            fire.isBurning(at: watch) && map.index(of: fire.at).map { owners[$0] == hold.id } == true
        }.map(\.at)
    }

    /// What a hold has under way comes a watch nearer, so long as a watch
    /// is left after: its work and its muster alike.
    private mutating func hastenWork(at holdID: Int) {
        guard let index = holdIndex(holdID) else { return }
        if let left = holds[index].project?.watchesLeft, left > 1 { holds[index].project?.watchesLeft = left - 1 }
        if let left = holds[index].training?.watchesLeft, left > 1 { holds[index].training?.watchesLeft = left - 1 }
    }

    /// A plea as a keeper's device asks its model to voice it: who brings
    /// it, from where, what the hold's folk ask and what the House gets,
    /// and what turning it away would cost.
    public func voiced(_ petition: Petition) -> Voicing.Moment {
        var facts = ["The petitioner is \(petitioner(of: petition)), a hold of \(houses.indices.contains(petition.house) ? houses[petition.house].title : "the keeper's House")."]
        facts.append(asked(by: petition))
        facts.append(GameState.turnedAwaySaid)
        // What came of the hold's last plea, which its folk remember.
        facts += rememberedPleaFacts(petition)
        return Voicing.Moment(task: Voicing.petitionTask, facts: facts)
    }
}
