/// How a rival House decides what to do. It plays by the same rules as the
/// player, through the same commands, and judges others by what it has seen,
/// how strong they are, its temperament, and what it remembers of them.
struct RivalMind {
    let house: Int
    /// Keeping a House for its keeper while they are away: it answers
    /// envoys, tends the holds and defends them, and sues for peace in a
    /// war going badly, but begins nothing the keeper would have to undo:
    /// no war, no demand, no pact, no bending the knee; nor does it swear
    /// a pact offered, which would lend the keeper's sight to another.
    var caretaking = false
    /// Every House's strength as the pace began, as it is known round the
    /// lake: weighed once for all the stewards of a pace. Without it, a
    /// steward weighs every House as it stands.
    var known: [Int]?

    // MARK: Answering offers

    func accepts(_ proposal: Proposal, from proposer: Int, in state: GameState) -> Bool {
        guard let relation = state.relation(house, proposer) else { return false }
        let me = state.houses[house]
        let mine = max(1, state.strength(of: house))
        let theirs = max(1, state.strength(of: proposer))
        // Gifts lately sent soften a steward: the war seems older, the
        // giver more worth a pact. No gift softens it toward a House whose
        // rising Moonspire it fears.
        let goodwill = spireThreats(in: state).contains(proposer) ? 0 : state.goodwill(from: proposer, to: house)
        // Watches the stance has truly stood, and as the gifts make it seem.
        let stood = state.watch - relation.since
        let lasted = stood + goodwill / 10

        switch proposal {
        case .peace:
            // Never before it has had a watch of its own at war: a war
            // begun and ended between two of its watches is one it never
            // had the chance to fight.
            guard stood >= 1, lasted >= 3 else { return false }
            // The ambitious and the cunning show no mercy to a House on its
            // last holds when they are clearly the stronger.
            let nearlyFallen = state.holds(of: proposer).count <= 2 && mine * 2 > theirs * 3
            if nearlyFallen, me.temperament == .ambitious || me.temperament == .cunning {
                return false
            }
            // A House far the stronger fights on until the war is long, and
            // no gift makes it seem so.
            if mine * 2 > theirs * 3, stood <= 30 { return false }
            switch me.temperament {
            case .ambitious: return mine * 10 < theirs * 11 || lasted > 16
            case .cunning: return mine < theirs || lasted > 10
            case .steadfast: return mine * 2 < theirs * 3 || lasted > 8
            case .wary:
                // A wronged House fights on longer.
                let wronged = relation.aggressor == proposer
                return wronged ? (mine < theirs || lasted > 14) : (mine * 2 < theirs * 3 || lasted > 6)
            }
        case .fealty:
            // Who would refuse a vassal?
            return me.liege == nil
        case .trade:
            // Trade is weighed on its terms, by `acceptsTrade`.
            return false
        case .tribute:
            // Pay rather than fight a war it would lose.
            switch me.temperament {
            case .wary, .steadfast: return theirs * 10 > mine * 15
            case .cunning: return theirs * 10 > mine * 18
            case .ambitious: return theirs > mine * 2
            }
        case .pact:
            if relation.betrayals > 0 || relation.aggressor == proposer { return false }
            if goodwill >= GameState.pactGoodwill { return true }
            switch me.temperament {
            case .ambitious: return theirs * 10 > mine * 13
            case .cunning: return true
            case .steadfast: return state.watch >= 6
            case .wary: return state.watch >= 10 && theirs * 2 >= mine
            }
        }
    }

    // MARK: A watch's decisions

    func takeTurn(in state: inout GameState) -> [GameEvent] {
        guard let me = state.house(house), !me.isEliminated else { return [] }
        var events: [GameEvent] = []
        var random = state.random()

        events += caretaking ? keepThePeace(in: &state, random: &random) : conductDiplomacy(in: &state, random: &random)
        events += tendAlliance(in: &state, random: &random)
        if !caretaking {
            events += studyTogether(in: &state)
            events += raiseStandard(in: &state)
            events += helpStandards(in: &state)
            events += sitTheLyceum(in: &state)
            events += raiseHall(in: &state)
            events += raiseStorehouse(in: &state)
            events += raiseYard(in: &state)
            events += callRally(in: &state, random: &random)
            events += sendToRallies(in: &state)
            events += keepAlliesGates(in: &state)
            if RivalMind.massing { events += musterToTheGates(in: &state) }
        }
        events += stirTheWater(in: &state, random: &random)
        events += sinkAListeningStone(in: &state)
        events += walkTheMirror(in: &state)
        events += balanceStores(in: &state)
        // The land's territory, found once: no work or muster begun changes
        // it, nor whom the House is at war with; whether a site for a new
        // hold is known is found the first time a hold asks.
        let owners = state.territory()
        let warring = state.isAtWarWithAny(house)
        var siteKnown: Bool?
        for hold in state.holds(of: house).sorted(by: { $0.id < $1.id }) {
            events += manage(hold.id, owners: owners, atWar: warring, siteKnown: &siteKnown, in: &state, random: &random)
        }
        events += pursueStudies(in: &state)
        if !caretaking {
            events += useItems(in: &state)
            events += forgeGear(in: &state)
            events += keepStorehouse(in: &state)
        }
        if !caretaking { events += ransomCaptives(in: &state) }
        events += appointCommanders(in: &state)
        events += state.raiseStars(for: house)
        events += state.growTalents(for: house)
        events += state.armCommanders(for: house)
        let garrisons = assignGarrisons(in: state)
        let visible = state.visibility(for: house)
        // A keeper's standing orders keeping every company on its own land.
        let home = caretaking && state.standingOrders(of: house).home == true ? owners : nil
        // Its companies' orders don't change whom it is at war with.
        let atWar = state.isAtWarWithAny(house)
        // The Heartstone is sought at war too, the Frontier's prize.
        if !atWar || state.heartstone != nil { events += seekHolySite(garrisons: garrisons, in: &state) }
        events += breakTheCrown(garrisons: garrisons, in: &state)
        if home == nil { events += seekDrownedCrown(garrisons: garrisons, in: &state) }
        for unit in state.units(of: house).sorted(by: { $0.id < $1.id }) {
            guard state.unit(unit.id) != nil else { continue }
            events += command(unit.id, garrisonFor: garrisons[unit.id], seeing: visible, atWar: atWar, home: home, in: &state)
        }
        events += drill(owners: owners, in: &state)
        return events
    }

    /// Grain a steward keeps in store before it drills.
    static let drillReserve = 120

    /// Its companies of war waiting beside its holds with a Muster Hall
    /// drill there, while its grain grows faster than its companies eat and
    /// it has grain in store: the hall drills no more than the House can
    /// feed. A caretaker spends no keeper's grain on it, and a builder
    /// raising its Moonspire none of the tower's, but at war.
    private func drill(owners: [Int?], in state: inout GameState) -> [GameEvent] {
        guard !caretaking, state.houses[house].stock.grain >= RivalMind.drillReserve,
              state.income(of: house, territory: owners).grain - state.upkeep(of: house) > 2 else { return [] }
        let builder = state.houses[house].temperament == .steadfast || state.houses[house].temperament == .wary
        let atWar = state.isAtWarWithAny(house)
        if builder, !atWar, (state.seat(of: house)?.level(.moonspire) ?? 0) > 0 { return [] }
        var events: [GameEvent] = []
        for unit in state.units(of: house).sorted(by: { $0.id < $1.id })
            where unit.destination == nil && unit.errand == nil && unit.drillAt == nil && state.drillRefusal(of: unit) == nil {
            events += perform(.drill(unit: unit.id), in: &state)
        }
        return events
    }

    /// How near its holds a holy site lies for a steward to send for it.
    static let holySiteReach = 8
    /// The watch from which stewards raise their alliances' standards.
    static let standardsFrom = 25

    /// How often a steward's scholars answer the Lyceum rightly.
    static let lyceumWisdom = 60

    /// While the Lyceum sits the steward's scholars answer every question
    /// set, right three times in five, wrong otherwise.
    private func sitTheLyceum(in state: inout GameState) -> [GameEvent] {
        guard let questions = state.lyceumNow else { return [] }
        // A draw of its own, so its answers leave the steward's other choices as they were.
        var random = SeededRandom(seed: Seed.mix(state.settings.seed, 8_801, UInt64(state.watch), UInt64(house)))
        var events: [GameEvent] = []
        for (index, question) in questions.enumerated() where state.lyceumAnswers(of: house)[index] == nil {
            let wrong = (0..<question.choices.count).filter { $0 != question.answer }
            let choice = random.chance(RivalMind.lyceumWisdom) || wrong.isEmpty ? question.answer : wrong[random.int(in: 0...(wrong.count - 1))]
            events += perform(.answerLyceum(question: index, choice: choice), in: &state)
        }
        return events
    }

    private func helpStandards(in state: inout GameState) -> [GameEvent] {
        // A hand to the alliance's rising standards, with stores to spare.
        guard let sworn = state.alliance(of: house), state.purse(of: house).covers(Standard.helpCost * 3) else { return [] }
        guard let rising = state.standards(of: sworn.id).first(where: { state.helpStandardRefusal($0.id, by: house) == nil }) else { return [] }
        return perform(.helpStandard(standard: rising.id), in: &state)
    }

    /// A House of an alliance with stores to spare raises a standard one
    /// watch in six, where its land would take in the most sites of the
    /// land, the nearer its holds the better; never where it would take
    /// in none.
    private func raiseStandard(in state: inout GameState) -> [GameEvent] {
        guard state.watch >= RivalMind.standardsFrom, (state.watch + house) % 6 == 0, let sworn = state.alliance(of: house),
              state.standards(of: sworn.id).count < state.standardsAllowed(for: sworn),
              state.purse(of: house).covers(Standard.cost * 2) else { return [] }
        let mine = state.holds(of: house).map(\.position)
        let sites = state.sitesInLand.map(\.position)
        let spots = Set(mine.flatMap { $0.spiral(Standard.tether) }).filter { state.standardRefusal(at: $0, by: house) == nil }
        let best = spots.map { hex in
            (hex: hex, sites: sites.filter { $0.distance(to: hex) <= Standard.reach }.count, near: mine.map { $0.distance(to: hex) }.min() ?? 99)
        }.max { a, b in (a.sites, -a.near, b.hex) < (b.sites, -b.near, a.hex) }
        guard let best, best.sites > 0 else { return [] }
        return perform(.raiseStandard(at: best.hex), in: &state)
    }

    /// The watch from which stewards raise their alliances' halls.
    static let hallsFrom = 40
    /// The watch from which stewards raise a Forge.
    static let forgeFrom = 24

    /// A steward with a Forge forges the set that suits its foremost
    /// commander, a piece at a time: the first it lacks, as fine as its
    /// Forge, makings and moonsalt allow, and no less fine than what that
    /// commander wears in its place; a piece it can't yet forge, it waits for.
    private func forgeGear(in state: inout GameState) -> [GameEvent] {
        guard state.forgeLevel(of: house) > 0,
              let lead = state.commanders(of: house).max(by: { ($0.level, -$0.id) < ($1.level, -$1.id) }) else { return [] }
        let held = Set(state.gear(of: house).map(\.kind))
        guard let kind = GearSet.suiting(lead.archetype).pieces.first(where: { !held.contains($0) }) else { return [] }
        let worn = state.worn(by: lead.id).first { $0.slot == kind.slot }?.quality ?? .plain
        guard let quality = GearQuality.allCases.reversed().first(where: { $0 >= worn && state.forgeRefusal(kind, $0, by: house) == nil })
        else { return [] }
        return perform(.forge(kind, quality: quality), in: &state)
    }
    /// What a steward keeps back beyond a hall's cost before it begins one.
    static let hallReserve = Stock(grain: 100, timber: 100, stone: 100, moonsalt: 10)

    /// An alliance's leader with stores to spare begins the alliance's hall
    /// one watch in four, on the alliance's land nearest its own holds.
    private func raiseHall(in state: inout GameState) -> [GameEvent] {
        guard state.watch >= RivalMind.hallsFrom, (state.watch + house) % 4 == 0, let sworn = state.alliance(of: house),
              sworn.leader == house, state.hall(of: sworn.id) == nil,
              state.purse(of: house).covers(AllianceHall.cost + RivalMind.hallReserve) else { return [] }
        let mine = state.holds(of: house).map(\.position)
        let spots = Set(state.standards(of: sworn.id).flatMap { $0.position.spiral(Standard.reach) })
            .filter { state.hallRefusal(at: $0, by: house) == nil }
        let best = spots.map { hex in (hex: hex, near: mine.map { $0.distance(to: hex) }.min() ?? 99) }
            .min { a, b in (a.near, a.hex) < (b.near, b.hex) }
        guard let best else { return [] }
        return perform(.raiseAllianceHall(at: best.hex), in: &state)
    }

    /// The watch from which stewards raise their alliances' storehouses.
    static let storehousesFrom = 44
    /// The watch from which stewards raise their alliances' yards.
    static let yardsFrom = 30
    /// What a steward keeps back beyond a storehouse's or a yard's cost.
    static let worksReserve = Stock(grain: 80, timber: 80, stone: 80, moonsalt: 5)

    /// An alliance's leader with stores to spare begins its storehouse one
    /// watch in four, on the alliance's land nearest its own holds.
    private func raiseStorehouse(in state: inout GameState) -> [GameEvent] {
        guard state.watch >= RivalMind.storehousesFrom, (state.watch + house) % 4 == 1, let sworn = state.alliance(of: house),
              sworn.leader == house, state.storehouse(of: sworn.id) == nil,
              state.purse(of: house).covers(Storehouse.cost + RivalMind.worksReserve),
              let spot = allianceSpot(in: state, where: { state.storehouseRefusal(at: $0, by: house) == nil }) else { return [] }
        return perform(.raiseStorehouse(at: spot), in: &state)
    }

    /// An alliance's leader with stores to spare raises a yard one watch in
    /// five: of the first store its alliance has none of, on ground that
    /// would yield that store if there is any, nearest its own holds.
    private func raiseYard(in state: inout GameState) -> [GameEvent] {
        guard state.watch >= RivalMind.yardsFrom, (state.watch + house) % 5 == 2, let sworn = state.alliance(of: house),
              sworn.leader == house, state.purse(of: house).covers(Yard.cost + RivalMind.worksReserve) else { return [] }
        let raised = Set(state.yards(of: sworn.id).map(\.store))
        guard let store = Resource.allCases.first(where: { !raised.contains($0) }),
              let spot = allianceSpot(in: state, preferring: { state.map[$0].flatMap { Site.store(of: $0.terrain) } == store },
                                      where: { state.yardRefusal(store, at: $0, by: house) == nil }) else { return [] }
        return perform(.raiseYard(store, at: spot), in: &state)
    }

    /// The ground of a steward's alliance's land, nearest its own holds,
    /// where something of the alliance's may stand: the ground it prefers,
    /// if any will do.
    private func allianceSpot(in state: GameState, preferring liked: (Hex) -> Bool = { _ in false }, where allowed: (Hex) -> Bool) -> Hex? {
        guard let sworn = state.alliance(of: house) else { return nil }
        let mine = state.holds(of: house).map(\.position)
        var land = Set(state.standards(of: sworn.id).flatMap { $0.position.spiral(Standard.reach) })
        if let hall = state.hall(of: sworn.id), hall.isWhole { land.formUnion(hall.position.spiral(AllianceHall.reach)) }
        return land.filter(allowed)
            .map { hex in (hex: hex, liked: liked(hex) ? 0 : 1, near: mine.map { $0.distance(to: hex) }.min() ?? 99) }
            .min { a, b in (a.liked, a.near, a.hex) < (b.liked, b.near, b.hex) }?.hex
    }

    /// A steward lays up in its alliance's storehouse what it holds beyond
    /// seven tenths of its room, out of a taker's reach and past its cap,
    /// and takes back what it laid up when a store falls under four tenths.
    private func keepStorehouse(in state: inout GameState) -> [GameEvent] {
        guard let storehouse = state.wholeStorehouse(for: house) else { return [] }
        let room = state.storage(of: house)
        let stock = state.houses[house].stock
        let laid = storehouse.laidUp(by: house)
        var up = Stock.zero
        var back = Stock.zero
        for resource in Resource.allCases {
            let high = room * 7 / 10
            let low = room * 4 / 10
            if stock[resource] > high {
                up[resource] = max(0, min(stock[resource] - high, Storehouse.room[resource] - laid[resource]))
            } else if stock[resource] < low {
                back[resource] = min(low - stock[resource], laid[resource])
            }
        }
        var events: [GameEvent] = []
        if !up.isZero { events += perform(.layUp(up), in: &state) }
        if !back.isZero { events += perform(.takeBack(back), in: &state) }
        return events
    }

    /// What a steward holds of each store before it gives to its alliance's
    /// study: plenty, and no less.
    static let plenty = Stock(grain: 300, timber: 250, stone: 250, moonsalt: 20)

    /// The studies a steward's alliance pursues, by its leader's temper.
    static func allianceStudyOrder(for temperament: Temperament) -> [AllianceStudy] {
        switch temperament {
        case .ambitious: return [.oathOfSteel, .drillYards, .shieldOath, .fieldcraft, .masonsCompact, .sharedScrolls]
        case .steadfast: return [.shieldOath, .masonsCompact, .fieldcraft, .drillYards, .sharedScrolls, .oathOfSteel]
        case .wary: return [.shieldOath, .fieldcraft, .masonsCompact, .sharedScrolls, .drillYards, .oathOfSteel]
        case .cunning: return [.fieldcraft, .sharedScrolls, .masonsCompact, .drillYards, .oathOfSteel, .shieldOath]
        }
    }

    /// A steward studies with its alliance: as its leader it sets a study to
    /// pursue when none is, by its temper; and one watch in three it gives
    /// a tenth of whatever it holds beyond plenty.
    private func studyTogether(in state: inout GameState) -> [GameEvent] {
        guard let sworn = state.alliance(of: house) else { return [] }
        var events: [GameEvent] = []
        let lore = sworn.lore ?? AllianceLore()
        if sworn.leader == house, lore.pursuit == nil,
           let study = RivalMind.allianceStudyOrder(for: state.houses[house].temperament).first(where: { lore.grade(of: $0) < AllianceStudy.grades }) {
            events += perform(.pursueAllianceStudy(study), in: &state)
        }
        guard (state.watch + house) % 3 == 0, state.alliance(of: house)?.lore?.pursuit != nil else { return events }
        let stock = state.houses[house].stock
        var gift = Stock.zero
        for resource in Resource.allCases where stock[resource] > RivalMind.plenty[resource] {
            gift[resource] = (stock[resource] - RivalMind.plenty[resource]) / 10
        }
        if !gift.isZero { events += perform(.giveToAlliance(gift), in: &state) }
        return events
    }

    /// How many of its companies must be hurt for a steward to share out a
    /// mending draught, and how hurt.
    static let draughtWhen = (companies: 3, health: 60)

    /// A steward uses what its satchel holds: a ward stone on its hold
    /// whose ward is lowest, under half; an hourglass a watch on its holds'
    /// work and muster, its seat's first, or else on its study; a cache
    /// whose stores all fit; a draught when enough of its companies are hurt.
    private func useItems(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        if state.items(.wardStone, of: house) > 0,
           let low = state.holds(of: house).filter({ $0.ward * 2 < $0.maximumWard }).min(by: { ($0.ward, $0.id) < ($1.ward, $1.id) }) {
            events += perform(.useItem(.wardStone, hold: low.id), in: &state)
        }
        if state.items(.hourglass, of: house) > 0 {
            let holds = state.holds(of: house).sorted { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }
            if let hold = holds.first(where: { ($0.project?.watchesLeft ?? 0) > 1 || ($0.training?.watchesLeft ?? 0) > 1 }) {
                events += perform(.useItem(.hourglass, hold: hold.id), in: &state)
            } else if (state.houses[house].research.pursuit?.watchesLeft ?? 0) > 1 {
                events += perform(.useItem(.hourglass, hold: nil), in: &state)
            }
        }
        let room = state.storage(of: house)
        for kind in Resource.allCases.map(ItemKind.cache(of:)) where state.items(kind, of: house) > 0 {
            let stock = state.houses[house].stock
            if Resource.allCases.allSatisfy({ stock[$0] + kind.stores[$0] <= room }) {
                events += perform(.useItem(kind, hold: nil), in: &state)
            }
        }
        if state.items(.mendingDraught, of: house) > 0,
           state.units(of: house).filter({ $0.health < RivalMind.draughtWhen.health }).count >= RivalMind.draughtWhen.companies {
            events += perform(.useItem(.mendingDraught, hold: nil), in: &state)
        }
        return events
    }

    /// A steward's Lantern within reach of a foe's hold scouts it one
    /// watch in this many.
    static let scoutEvery = 4

    /// At peace, a steward sends one company of war it doesn't need to the
    /// nearest holy site near its holds that its side doesn't hold, with
    /// none of its own already bound there.
    private func seekHolySite(garrisons: [Int: Hex], in state: inout GameState) -> [GameEvent] {
        let holds = state.holds(of: house).map(\.position)
        let side = Set([house] + (state.alliance(of: house)?.members ?? []))
        let mine = state.units(of: house)
        // No way into the Crown's heart while every gate stands.
        let crowned = state.gatesStanding.count == Lair.gateQuarters.count
        let wanted = state.holySites.filter { shrine in
            !(shrine.holder.map(side.contains) ?? false) && !(crowned && shrine.kind == .heartstone)
                && holds.contains { $0.distance(to: shrine.position) <= RivalMind.holySiteReach }
                && !mine.contains { $0.position == shrine.position || $0.destination == shrine.position }
                && state.unit(at: shrine.position) == nil
        }
        guard !wanted.isEmpty else { return [] }
        let gates = state.gatesStanding
        let idle = mine.filter { unit in
            unit.kind.isMilitary && unit.errand == nil && unit.destination == nil && garrisons[unit.id] == nil && unit.movesLeft > 0
                && !atTheCrown(unit, gates)
        }
        let choice = idle.flatMap { unit in wanted.map { (unit: unit, shrine: $0) } }.min { a, b in
            (a.unit.position.distance(to: a.shrine.position), a.unit.id) < (b.unit.position.distance(to: b.shrine.position), b.unit.id)
        }
        guard let choice else { return [] }
        return perform(.move(unit: choice.unit.id, to: choice.shrine.position), in: &state)
    }

    /// How far from its holds a steward goes for the Drowned Crown.
    static let drownedCrownReach = 10

    /// While the Drowned Crown lies on the ford unborne by its side, a
    /// steward with holds near sends its nearest idle company of war for
    /// it, one at a time; at war or at peace, for the crown is fought over.
    private func seekDrownedCrown(garrisons: [Int: Hex], in state: inout GameState) -> [GameEvent] {
        guard let crown = state.crown else { return [] }
        if let bearer = crown.bearer.flatMap(state.unit), state.crownSide(of: bearer.owner) == state.crownSide(of: house) { return [] }
        let mine = state.units(of: house)
        guard !mine.contains(where: { $0.destination == crown.hex }),
              state.holds(of: house).contains(where: { $0.position.distance(to: crown.hex) <= RivalMind.drownedCrownReach }) else { return [] }
        let gates = state.gatesStanding
        let idle = mine.filter { unit in
            unit.kind.isMilitary && unit.errand == nil && unit.destination == nil && garrisons[unit.id] == nil && unit.movesLeft > 0
                && !atTheCrown(unit, gates) && unit.position != crown.hex
        }
        guard let choice = idle.min(by: { ($0.position.distance(to: crown.hex), $0.id) < ($1.position.distance(to: crown.hex), $1.id) })
        else { return [] }
        return perform(.move(unit: choice.id, to: crown.hex), in: &state)
    }

    /// How far from its holds a steward goes to break a gate of the Crown.
    static let crownReach = 12
    /// The least health a steward's company strikes a gate from beside it
    /// with, taking its blow back.
    static let gateHealth = 50

    /// Whether a company is busy at the Crown: at a gate it can strike, or
    /// bound before one, and fit to take the gate's blow back if it must
    /// stand beside it.
    private func atTheCrown(_ unit: Unit, _ gates: [Lair]) -> Bool {
        guard unit.kind.range > 1 || unit.health >= RivalMind.gateHealth else { return false }
        return gates.contains { gate in
            unit.position.distance(to: gate.position) <= unit.kind.range || unit.destination.map { $0.distance(to: gate.position) <= 1 } == true
        }
    }

    /// On the Marches, a steward sends one company of war it doesn't need
    /// to stand before a gate of the Crown near its holds, the most broken
    /// first, then the nearest, with none of its own there or bound there
    /// already; there, it strikes it as it campaigns. Only the Marches have
    /// a Crown.
    private func breakTheCrown(garrisons: [Int: Hex], in state: inout GameState) -> [GameEvent] {
        let gates = state.gatesStanding
        guard !gates.isEmpty else { return [] }
        let holds = state.holds(of: house).map(\.position)
        let mine = state.units(of: house).filter(\.kind.isMilitary)
        let near = gates.filter { gate in
            holds.contains { $0.distance(to: gate.position) <= RivalMind.crownReach }
                && !mine.contains { unit in
                    unit.position.distance(to: gate.position) <= unit.kind.range || unit.destination.map { $0.distance(to: gate.position) <= 1 } == true
                }
        }
        let idle = mine.filter {
            $0.errand == nil && $0.destination == nil && garrisons[$0.id] == nil && $0.movesLeft > 0 && $0.health >= RivalMind.gateHealth
                && !atTheCrown($0, gates)
        }
        // Before the gate, outside the Crown, on open ground.
        let choices = idle.flatMap { unit in
            near.compactMap { gate -> (unit: Unit, at: Hex, standing: Int)? in
                gate.position.neighbors
                    .filter { $0.length > gate.position.length && state.map[$0]?.terrain.isPassable == true && !state.isOccupied($0) }
                    .min { ($0.distance(to: unit.position), $0) < ($1.distance(to: unit.position), $1) }
                    .map { (unit, $0, gate.strength) }
            }
        }
        guard let choice = choices.min(by: { a, b in
            (a.standing, a.unit.position.distance(to: a.at), a.unit.id) < (b.standing, b.unit.position.distance(to: b.at), b.unit.id)
        }) else { return [] }
        return perform(.move(unit: choice.unit.id, to: choice.at), in: &state)
    }

    private func perform(_ command: Command, in state: inout GameState) -> [GameEvent] {
        (try? state.perform(command, as: house)) ?? []
    }

    // MARK: Diplomacy

    private func conductDiplomacy(in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        let me = state.houses[house]
        // Every other House's strength as it is known, its own as it
        // stands: nothing said or sworn here changes either.
        let all = known.flatMap { $0.count == state.houses.count ? $0 : nil } ?? state.strengths()
        var strengths = state.houses.map { $0.isEliminated ? 0 : all[$0.id] }
        if known != nil { strengths[house] = state.strength(of: house) }
        let mine = max(1, strengths[house])
        let strongestOther = state.livingIDs.filter { $0 != house }.map { strengths[$0] }.max() ?? 0
        let enemies = state.livingIDs.filter { state.isAtWar(house, $0) }.count
        var events: [GameEvent] = []
        var declared = false
        // Whose holds it knows near its own, found from its holds and each
        // other House's, gathered once: nothing said here moves a hold.
        let explored = state.houses[house].explored
        let ownHolds = state.holds(of: house).map(\.position)
        // By owner in a list, each House's room made at once, its holds
        // read where they stand rather than copied.
        var counts = [Int](repeating: 0, count: state.houses.count)
        for index in state.holds.indices { counts[state.holds[index].owner] += 1 }
        var holdsOf = counts.map { count -> [Hex] in
            var positions: [Hex] = []
            positions.reserveCapacity(count)
            return positions
        }
        for index in state.holds.indices { holdsOf[state.holds[index].owner].append(state.holds[index].position) }
        func knowsHold(of other: Int, within distance: Int) -> Bool {
            holdsOf[other].contains { theirs in
                guard let index = state.map.index(of: theirs), explored[index] else { return false }
                return ownHolds.contains { $0.distance(to: theirs) <= distance }
            }
        }
        // The siege it would lay, found once, the first time a war asks: no
        // proposal made here moves a company or a hold.
        var siege: Siege??
        func plannedSiege() -> Siege? {
            if let siege { return siege }
            let planned = siegePlan(in: state)
            siege = .some(planned)
            return planned
        }

        // A rising Moonspire frightens everyone else around the lake.
        // Every one of them, not only the highest: the House it can best
        // stand against.
        if let rising = spireThreats(in: state).first(where: { rising in
            state.stance(house, rising) != .war && !inTruce(with: rising, in: state)
                && mine * 10 > max(1, strengths[rising]) * 6
        }), random.chance(35) {
            if (try? state.declareWar(by: house, on: rising, fearingSpire: true)) != nil {
                events.append(.stanceChanged(first: house, second: rising, stance: .war, by: house))
                declared = true
            }
        }

        // Each other House weighed in an order of no one's seat number: the
        // first a House sets on is no likelier to be one numbered low.
        // Each House's place in the order found once, not at every comparison.
        // By id, the Houses standing not copied for it, and each one's liege
        // as the turn began.
        let order = state.livingIDs.map { (key: tieBreak($0, in: state), id: $0) }.sorted { $0.key < $1.key }.map(\.id)
        let lieges = state.houses.map(\.liege)
        for other in order where other != house {
            // Its own alliance's Houses are no one to war on or make demands of.
            guard let relation = state.relation(house, other), !state.areAllied(house, other) else { continue }
            let theirs = max(1, strengths[other])
            let lasted = state.watch - relation.since
            let neighbours = knowsHold(of: other, within: 14)

            switch relation.stance {
            case .war:
                let losing = mine * 10 < theirs * 7
                let weary = lasted >= 20 && me.temperament != .ambitious && mine * 2 < theirs * 3
                // A House whose siege is going well fights on.
                let winning = plannedSiege().map { plan in
                    state.hold(at: plan.target).map { $0.owner == other && $0.ward * 2 < $0.maximumWard } ?? false
                } ?? false
                // Broken, and against a far stronger House: bend the knee
                // rather than fall.
                let broken = state.watch >= 70 && state.holds(of: house).count <= 3 && mine * 5 < theirs * 2 && me.liege == nil
                    && state.houses[other].liege == nil
                if lasted >= 4, broken, random.chance(50) {
                    events += perform(.propose(.fealty, to: other), in: &state)
                } else if lasted >= 4, losing || (weary && !winning), random.chance(40) {
                    events += perform(.propose(.peace, to: other), in: &state)
                }
            case .peace:
                // The ambitious and the cunning, far the stronger, ask a
                // neighbour for tribute, and march only if refused.
                let greedy = (me.temperament == .ambitious || me.temperament == .cunning) && state.watch >= 20
                    && mine * 100 > theirs * 125 && !state.paidTributeLately(house, other)
                    && me.liege != other && lieges[other] != house
                guard !declared, neighbours, !inTruce(with: other, in: state) else { break }
                if greedy, random.chance(enemies == 0 ? 10 : 5) {
                    events += perform(.propose(.tribute, to: other), in: &state)
                    declared = true
                    break
                }
                guard enemies == 0 else { break }
                let grudge = relation.aggressor == other
                var wantsWar: Bool
                switch me.temperament {
                case .ambitious: wantsWar = state.watch >= 12 && mine * 10 > theirs * 12 && random.chance(30)
                case .cunning: wantsWar = state.watch >= 15 && mine * 10 > theirs * 13 && random.chance(25)
                case .wary: wantsWar = grudge && mine * 10 > theirs * 12 && random.chance(15)
                case .steadfast: wantsWar = state.watch >= 30 && mine * 10 > theirs * 16 && random.chance(10)
                }
                // The leading House, once clearly the strongest, presses its
                // advantage toward dominion, whatever its temper.
                let leading = state.watch >= 50 && mine * 10 > strongestOther * 13
                if !wantsWar, leading, mine * 10 > theirs * 15, random.chance(35) {
                    wantsWar = true
                }
                // Tribute paid buys the peace for a while.
                if wantsWar, state.paidTributeLately(house, other) { wantsWar = false }
                // Even set on war, the greedy may ask for tribute first.
                let demanding = wantsWar && greedy && random.chance(45)
                if demanding {
                    events += perform(.propose(.tribute, to: other), in: &state)
                    declared = true
                } else if wantsWar {
                    events += perform(.declareWar(on: other), in: &state)
                    declared = true
                } else if me.temperament != .ambitious, state.watch >= 8, !grudge, relation.betrayals == 0, random.chance(8) {
                    events += perform(.propose(.pact, to: other), in: &state)
                }
            case .pact:
                let sworn = me.liege == other || state.houses[other].liege == house
                if !sworn, me.temperament == .cunning, !declared, enemies == 0, state.watch >= 25,
                   mine * 10 > theirs * 18, neighbours, random.chance(10) {
                    events += perform(.declareWar(on: other), in: &state)
                    declared = true
                }
            }
        }
        return events
    }

    /// A caretaker's diplomacy: the envoys waiting on the House answered as
    /// a steward would (peace to end a war, a House offering fealty taken
    /// as a vassal), but for a pact: one shares the keeper's sight, which
    /// is theirs alone to give, so it is refused. A war going badly is
    /// ended if it can be. It offers nothing itself, so it never bends the
    /// knee for its keeper.
    private func keepThePeace(in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        var events: [GameEvent] = []
        // The keeper's standing orders on peace and tribute, where they gave any.
        let standing = state.standingOrders(of: house)
        for envoy in state.envoys where envoy.to == house {
            let accept: Bool
            switch envoy.proposal {
            case .trade: accept = envoy.trade.map { acceptsTrade($0, from: envoy.from, in: state) } ?? false
            case .pact: accept = false
            case .peace where standing.peace != nil: accept = standing.peace == true
            case .tribute where standing.tribute != nil: accept = standing.tribute == true
            default: accept = accepts(envoy.proposal, from: envoy.from, in: state)
            }
            events += perform(.answer(envoy: envoy.id, accept: accept), in: &state)
        }
        let mine = max(1, state.strength(of: house))
        // The Houses standing as the look begins, by their places, none
        // copied out.
        let living = state.houses.indices.filter { !state.houses[$0].isEliminated }
        for other in living where state.isAtWar(house, other) {
            guard let relation = state.relation(house, other) else { continue }
            switch standing.peace {
            case false?:
                continue
            case true?:
                // Sued for in every war, whoever is the stronger.
                events += perform(.propose(.peace, to: other), in: &state)
            case nil:
                guard state.watch - relation.since >= 4 else { continue }
                if mine * 10 < max(1, state.strength(of: other)) * 9, random.chance(40) {
                    events += perform(.propose(.peace, to: other), in: &state)
                }
            }
        }
        return events
    }

    /// A tie broken by no one's seat or hold number: the same for the same
    /// House, watch and choice, and no likelier low than high.
    func tieBreak(_ id: Int, in state: GameState) -> UInt64 {
        Seed.mix(UInt64(id), UInt64(house), UInt64(state.watch))
    }

    /// Watches a House keeps a fresh peace before it would break it.
    static let truce = 10

    private func inTruce(with other: Int, in state: GameState) -> Bool {
        guard let relation = state.relation(house, other), relation.stance != .war else { return false }
        // A House that sends this one goods by oath is left in peace while it does.
        if state.sendsByOath(other, to: house) { return true }
        return relation.aggressor != nil && state.watch - relation.since < RivalMind.truce
    }

    /// Another House whose Moonspire has reached its third stage, if any:
    /// the highest.
    func spireThreat(in state: GameState) -> Int? {
        spireThreats(in: state).first
    }

    /// Every other House whose Moonspire has reached its third stage, the
    /// highest first: never a vassal's, which can't rise while it serves.
    func spireThreats(in state: GameState) -> [Int] {
        // By index, the seats alone weighed: asked for each company's
        // siege, and a holds' list copied whole for it each time.
        // Each one's tie-break drawn once, not at each comparison, where
        // the closure asking it copied the whole realm.
        var rising: [(key: (stage: Int, tie: UInt64), owner: Int)] = []
        for index in state.holds.indices where state.holds[index].isSeat && state.holds[index].owner != house {
            let stage = state.holds[index].level(.moonspire), owner = state.holds[index].owner
            guard stage >= 3, state.houses[owner].liege == nil else { continue }
            rising.append(((stage, tieBreak(owner, in: state)), owner))
        }
        return rising.sorted { $0.key > $1.key }.map(\.owner)
    }

    /// The first House at war with this one among `spireThreats`, found
    /// without ranking all the rest: of the seats of those at war, the
    /// Moonspire highest at its third stage or above, then the higher
    /// tie-break, the first in the holds' order where both are even.
    func risingFoe(in state: GameState) -> Int? {
        // The seats of the Houses it is at war with that bend the knee to
        // none, found among each one's own holds rather than sought through
        // every hold of the realm, and looked at in the realm's order.
        var seats: [Int] = []
        for owner in state.houses.indices where state.isAtWar(house, owner) && state.houses[owner].liege == nil {
            for index in state.holds.places(of: owner) where state.holds[index].isSeat { seats.append(index) }
        }
        seats.sort()
        var best: (key: (stage: Int, tie: UInt64), owner: Int)?
        for index in seats {
            let owner = state.holds[index].owner
            let stage = state.holds[index].level(.moonspire)
            guard stage >= 3 else { continue }
            let key = (stage, tieBreak(owner, in: state))
            if best.map({ key > $0.key }) ?? true { best = (key, owner) }
        }
        return best?.owner
    }

    // MARK: Barter

    /// Trades from whatever is near the storage limit into whatever is short.
    private func balanceStores(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        let room = state.storage(of: house)
        for _ in 0..<2 {
            let stock = state.houses[house].stock
            let common: [Resource] = [.grain, .timber, .stone]
            guard let low = common.min(by: { (stock[$0], $0.rawValue) < (stock[$1], $1.rawValue) }),
                  let high = Resource.allCases.max(by: { (stock[$0] * $0.worth, $0.rawValue) < (stock[$1] * $1.worth, $1.rawValue) }),
                  low != high,
                  stock[low] < room / 5,
                  stock[high] * high.worth > room * 3 / 5
            else { break }
            let affordable = stock[high] / 2 * high.worth / 3
            let amount = min(room / 4 - stock[low], affordable)
            guard amount >= 10 else { break }
            // A House to trade with near even first; barter only if none will.
            let sought = seekTrade(giving: high, for: low, amount: amount, in: &state)
            events += sought.events
            if sought.met { continue }
            events += perform(.barter(give: high, take: low, amount: amount), in: &state)
        }
        return events
    }

    // MARK: Holds

    /// A hold's work and muster chosen and begun. `owners` is the land's
    /// territory and `atWar` whether the House is at war with any, which
    /// nothing done here changes.
    private func manage(_ holdID: Int, owners: [Int?], atWar: Bool, siteKnown: inout Bool?, in state: inout GameState,
                        random: inout SeededRandom) -> [GameEvent] {
        var events: [GameEvent] = []
        // The fallen in its beds healed first, for half what mustering them
        // anew would cost.
        if state.hold(holdID)?.wounded?.contains(where: { !$0.healing }) == true {
            events += perform(.heal(hold: holdID), in: &state)
        }
        guard let hold = state.hold(holdID) else { return events }
        if hold.project == nil,
           let kind = standingWork(at: hold, in: state) ?? chooseBuilding(for: hold, owners: owners, atWar: atWar, in: state) {
            events += perform(.build(hold: holdID, kind: kind), in: &state)
        }
        if let hold = state.hold(holdID), hold.training == nil,
           let kind = chooseTraining(for: hold, owners: owners, atWar: atWar, siteKnown: &siteKnown, in: state, random: &random) {
            let tier = chooseTier(of: kind, at: hold, owners: owners, in: state)
            events += perform(.train(hold: holdID, kind: kind, tier: tier > 1 ? tier : nil), in: &state)
        }
        return events
    }

    /// The work a keeper's standing orders have their caretaker raise
    /// first, where the hold can raise it now.
    private func standingWork(at hold: Hold, in state: GameState) -> BuildingKind? {
        guard caretaking, let kind = state.standingOrders(of: house).raise,
              state.refusal(of: .build(hold: hold.id, kind: kind), as: house) == nil else { return nil }
        return kind
    }

    private func chooseBuilding(for hold: Hold, owners: [Int?], atWar: Bool, in state: GameState) -> BuildingKind? {
        let me = state.houses[house]
        let stock = me.stock
        let threatened = atWar && enemyMilitary(near: hold.position, within: 5, in: state)
        var wishes: [BuildingKind] = []

        if threatened, hold.level(.walls) < 3 { wishes.append(.walls) }
        if hold.isSeat, hold.level(.musterHall) == 0, state.watch >= 3 { wishes.append(.musterHall) }
        // Beyond the seat, a muster hall where there's war or stores to spare,
        // so a great House's wealth becomes companies, not idle stores.
        let room = state.storage(of: house)
        let plenty = stock.grain > room * 3 / 5 && stock.timber > room * 3 / 5
        if !hold.isSeat, hold.level(.musterHall) == 0, state.watch >= 20, atWar || plenty { wishes.append(.musterHall) }

        let income = state.income(of: hold, territory: owners)
        let net = state.income(of: house, territory: owners).grain - state.upkeep(of: house)
        if net < 4 { wishes.append(.granary) }
        let economy: [BuildingKind] = [.granary, .sawpit, .quarry, .saltworks]
            .filter { kind in
                guard let resource = kind.boostedResource else { return false }
                return income[resource] >= (resource == .moonsalt ? 2 : 4)
            }
            .sorted { (hold.level($0), $0.rawValue) < (hold.level($1), $1.rawValue) }
        if let first = economy.first { wishes.append(first) }

        if hold.isSeat {
            // Only a House that can see it through: one of holds enough to
            // store its last stage, or the most renowned on the lake, and
            // never a vassal, which raises none while it serves.
            // The builders begin early, the wary soon after, behind walls;
            // the warlike first take the land.
            let spireFrom: Int
            switch me.temperament {
            case .steadfast: spireFrom = 20
            case .wary: spireFrom = 24
            case .ambitious, .cunning: spireFrom = 34
            }
            // Its first Archive before it saves for the Moonspire, which
            // would starve every lesser work: a House that never studies
            // never opens its higher tiers. Whether it is the most renowned
            // is asked last, of every House in one pass.
            if state.watch >= spireFrom, !threatened, me.liege == nil,
               hold.level(.moonspire) > 0 || state.holds(of: house).count >= 4 || state.isForemost(house) {
                if hold.level(.archive) < min(1, RivalMind.archiveWanted(at: state.watch)) { wishes.append(.archive) }
                wishes.append(.moonspire)
            }
            if me.temperament == .ambitious, hold.level(.musterHall) < 3 { wishes.append(.musterHall) }
            if hold.level(.musterHall) < 2, state.watch >= 14 { wishes.append(.musterHall) }
            // Riders, for a House at war or with stores to spare.
            if hold.level(.musterHall) < 3, state.watch >= 40, atWar || plenty { wishes.append(.musterHall) }
            // A rising Moonspire draws every army on the lake: wall it, the
            // builders (who raise theirs first, and draw the lake first)
            // to the last stone.
            let builder = me.temperament == .steadfast || me.temperament == .wary
            if hold.level(.moonspire) >= 2, hold.level(.walls) < (builder ? 5 : 4) { wishes.append(.walls) }
        }
        if hold.level(.walls) < 1, state.watch >= 10 { wishes.append(.walls) }
        // A hold on the border, another House's hold near, walls itself.
        if hold.level(.walls) < 2, state.watch >= 30, bordersAnother(hold, in: state) { wishes.append(.walls) }
        if hold.level(.beacon) < 1, state.watch >= 18 { wishes.append(.beacon) }
        // With stores to spare, beacons for the land (and the yield) they claim.
        if plenty, hold.level(.beacon) < (state.watch >= 60 ? 3 : 2), state.watch >= 35 { wishes.append(.beacon) }
        // An Infirmary at the seat once it musters, a larger one at war, so
        // its fallen are healed rather than lost.
        if hold.isSeat, hold.level(.musterHall) > 0, state.watch >= 16, hold.level(.infirmary) < (atWar ? 2 : 1) {
            wishes.append(.infirmary)
        }
        // A Forge at the seat for its commanders' gear, finer as the age goes on.
        if hold.isSeat, state.watch >= RivalMind.forgeFrom, hold.level(.forge) < (state.watch >= 70 ? 3 : 1) { wishes.append(.forge) }
        if hold.isSeat {
            // An Archive at the seat, the deeper as the age goes on, for
            // its studies; and a hall as high as the tiers they open.
            if hold.level(.archive) < RivalMind.archiveWanted(at: state.watch) { wishes.append(.archive) }
            let studied = state.studiedTier(for: house)
            if hold.level(.musterHall) >= Hold.fasterTrainingAt, hold.level(.musterHall) < studied { wishes.append(.musterHall) }
        }
        wishes += economy.dropFirst()

        for kind in wishes {
            if kind.requiresSeat, !hold.isSeat { continue }
            guard let cost = state.nextLevelCost(of: kind, in: hold) else { continue }
            if stock.covers(cost) { return kind }
            // A stage it hasn't the storage for is no use saving for.
            if kind == .moonspire, [cost.grain, cost.timber, cost.stone, cost.moonsalt].contains(where: { $0 > room }) { continue }
            // Save for the Moonspire rather than spending on lesser works.
            if kind == .moonspire { return nil }
        }
        return nil
    }

    // MARK: Alliances

    /// The watch from which stewards found and seek alliances.
    static let alliancesFrom = 15

    /// Whether a steward takes an invitation into an alliance: none with a
    /// House whose rising Moonspire it fears, or that has wronged it; the
    /// wary and the steadfast gladly, the cunning into a strong one, the
    /// ambitious only into one far stronger than itself. A caretaker swears
    /// its keeper to none.
    func acceptsInvitation(to alliance: Alliance, in state: GameState) -> Bool {
        guard !caretaking, state.joinRefusal(of: house, to: alliance) == nil else { return false }
        let feared = spireThreats(in: state)
        guard !alliance.members.contains(where: feared.contains) else { return false }
        let wronged = alliance.members.contains { member in
            guard let relation = state.relation(house, member) else { return false }
            return relation.aggressor == member || relation.betrayals > 0
        }
        guard !wronged else { return false }
        let mine = max(1, state.strength(of: house))
        let theirs = alliance.members.reduce(0) { $0 + state.strength(of: $1) }
        switch state.houses[house].temperament {
        case .wary, .steadfast: return true
        case .cunning: return theirs * 10 >= mine * 15
        // The ambitious weigh all a House is, not its arms alone.
        case .ambitious: return alliance.members.reduce(0) { $0 + state.might(of: $1) } >= max(1, state.might(of: house)) * 2
        }
    }

    /// Whether a steward leading an alliance takes a House asking to join:
    /// none it fears, nor one that has wronged any of its Houses; the wary
    /// only a House it is in a pact with, the ambitious only one no
    /// stronger than itself.
    func acceptsMember(_ asker: Int, to alliance: Alliance, in state: GameState) -> Bool {
        guard state.joinRefusal(of: asker, to: alliance) == nil, !spireThreats(in: state).contains(asker) else { return false }
        let wrongdoer = alliance.members.contains { member in
            guard let relation = state.relation(asker, member) else { return false }
            return relation.aggressor == asker || relation.betrayals > 0
        }
        guard !wrongdoer else { return false }
        switch state.houses[house].temperament {
        case .wary: return state.stance(house, asker) == .pact
        case .ambitious: return state.might(of: asker) <= state.might(of: house)
        case .steadfast, .cunning: return true
        }
    }

    /// A steward's alliance, tended each watch: its allies' works helped;
    /// as leader, Houses asking answered and now and then a House it would
    /// stand beside invited; free, an alliance it would take asked, or now
    /// and then a banner raised. A caretaker only helps.
    func tendAlliance(in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        var events: [GameEvent] = []
        if let sworn = state.alliance(of: house) {
            for ally in sworn.members where ally != house && state.helpable(by: house, for: ally) > 0 {
                events += perform(.help(house: ally), in: &state)
            }
        }
        guard !caretaking else { return events }
        // A banner taken up from a keeper may find Houses asking: answered.
        if let sworn = state.alliance(of: house), sworn.leader == house {
            for asker in sworn.asking {
                let accept = state.alliance(of: house).map { acceptsMember(asker, to: $0, in: state) } ?? false
                events += perform(.answerRequest(house: asker, accept: accept), in: &state)
            }
        }
        guard state.watch >= RivalMind.alliancesFrom else { return events }
        let feared = spireThreats(in: state)
        if let sworn = state.alliance(of: house) {
            guard sworn.leader == house, sworn.members.count < state.allianceLimit, random.chance(15) else { return events }
            let candidates = state.livingHouses.filter { other in
                other.id != house && !sworn.invited.contains(other.id) && !feared.contains(other.id)
                    && state.stance(house, other.id) != .war && state.joinRefusal(of: other.id, to: sworn) == nil
            }
            let pick = candidates.min { a, b in
                (state.stance(house, a.id) == .pact ? 0 : 1, tieBreak(a.id, in: state)) < (state.stance(house, b.id) == .pact ? 0 : 1, tieBreak(b.id, in: state))
            }
            if let pick { events += perform(.inviteToAlliance(house: pick.id), in: &state) }
            return events
        }
        for alliance in state.alliancesStanding.sorted(by: { tieBreak($0.id, in: state) < tieBreak($1.id, in: state) })
            where !alliance.asking.contains(house) && acceptsInvitation(to: alliance, in: state) {
            guard random.chance(20) else { continue }
            events += perform(.askToJoin(alliance: alliance.id), in: &state)
            if state.alliance(of: house) != nil { return events }
        }
        let temper = state.houses[house].temperament
        if random.chance(temper == .wary || temper == .steadfast ? 6 : 3),
           let name = Alliance.stewardNames.first(where: { name in !state.alliancesStanding.contains { $0.name.lowercased() == name.lowercased() } }) {
            events += perform(.foundAlliance(name: name), in: &state)
        }
        return events
    }

    // MARK: Rallies

    /// How far from a hold of its own with a Muster Hall a steward calls a
    /// rally, and from how far it sends companies to one.
    static let rallyReach = 12

    /// A steward at war beside an ally of its alliance at war with the same
    /// House calls a rally against the hold its siege would take, from its
    /// own hold with a Muster Hall nearest it: the ambitious most often,
    /// the wary least.
    func callRally(in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        guard !state.ralliesStanding.contains(where: { $0.caller == house }) else { return [] }
        // A great army is led as one host on the foe, alliance or none.
        if let host = greatHost(in: state, random: &random) {
            // Rallies are an alliance's: a House sworn to none raises its own banner to lead it.
            var events: [GameEvent] = []
            if state.alliance(of: house) == nil {
                events += perform(.foundAlliance(name: "The Host of \(state.houses[house].name)"), in: &state)
            }
            return events + perform(host, in: &state)
        }
        guard state.watch >= RivalMind.alliancesFrom, let sworn = state.alliance(of: house) else { return [] }
        guard let plan = siegePlan(in: state), let target = state.hold(at: plan.target),
              RivalMind.massing || sworn.members.contains(where: { $0 != house && state.isAtWar($0, target.owner) }) else {
            return rallyOnALair(in: &state, random: &random)
        }
        // While the Moon's Peace holds, no host is called on a hold, nor
        // on one under its House's veil.
        if state.edictsInForce.contains(where: { $0.kind == .moonPeace }) || state.isVeiled(target.owner) { return [] }
        let musters = state.holds(of: house).filter { $0.level(.musterHall) >= 1 && $0.position.distance(to: target.position) <= RivalMind.rallyReach }
        guard let muster = musters.min(by: { a, b in
            (a.position.distance(to: target.position), a.id) < (b.position.distance(to: target.position), b.id)
        }) else { return [] }
        let chance: Int
        switch state.houses[house].temperament {
        case .ambitious: chance = 40
        case .cunning: chance = 30
        case .steadfast: chance = 20
        case .wary: chance = 10
        }
        guard random.chance(chance) else { return [] }
        return perform(.callRally(from: muster.id, against: target.id, watches: 2), in: &state)
    }

    /// The least a House's free companies of war must number, and the
    /// troops they must hold between them, for it to lead them as one
    /// great host.
    static let greatHostCompanies = 6
    static let greatHostTroops = 150_000

    /// The free companies of war a House would lead as a great host.
    func greatHostCompanies(in state: GameState) -> [Unit] {
        state.units(of: house).filter { $0.kind.isMilitary && $0.errand == nil && state.field(of: $0.id) == nil }
    }

    /// A House at war whose free companies make a great army, at least
    /// `greatHostCompanies` holding `greatHostTroops` troops, calls them as
    /// one host on the foe's hold its siege is set on, from its Muster Hall
    /// nearest it, gathering two watches; every company it can spare then
    /// joins (`sendToRallies`), so its army meets the foe whole.
    func greatHost(in state: GameState, random: inout SeededRandom) -> Command? {
        let free = greatHostCompanies(in: state)
        guard free.count >= RivalMind.greatHostCompanies,
              free.reduce(0, { $0 + state.troops(of: $1) }) >= RivalMind.greatHostTroops,
              let plan = siegePlan(in: state), let target = state.hold(at: plan.target), state.isAtWar(house, target.owner),
              !state.edictsInForce.contains(where: { $0.kind == .moonPeace }), !state.isVeiled(target.owner) else { return nil }
        let musters = state.holds(of: house).filter { $0.level(.musterHall) >= 1 && $0.position.distance(to: target.position) <= RivalMind.rallyReach }
        guard let muster = musters.min(by: { a, b in
            (a.position.distance(to: target.position), a.id) < (b.position.distance(to: target.position), b.id)
        }) else { return nil }
        // A great army is never left to march off company by company: it is led out as one, whatever the temper.
        let command = Command.callRally(from: muster.id, against: target.id, watches: 2)
        // Sworn to no alliance, it may still found one to call it; any other refusal stands.
        if state.alliance(of: house) == nil, state.refusal(of: .foundAlliance(name: "The Host"), as: house) == nil { return command }
        return state.refusal(of: command, as: house) == nil ? command : nil
    }

    /// At peace with every House, a House rallies on a lair of the wilds it
    /// knows near a hold of its with a Muster Hall, the lowest first, if it
    /// has companies enough to spare to hope to break it.
    private func rallyOnALair(in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        guard !state.isAtWarWithAny(house) else { return [] }
        let free = state.units(of: house).filter { $0.kind.isMilitary && $0.errand == nil }.count
        let spare = free - state.holds(of: house).count
        guard spare >= 3 else { return [] }
        let musters = state.holds(of: house).filter { $0.level(.musterHall) >= 1 }
        let choices = state.lairsStanding
            .filter { state.isExplored($0.position, by: house) && $0.level <= max(1, spare / 2) && $0.level <= state.lairRung(of: house) + 1 }
            .flatMap { lair in musters.filter { $0.position.distance(to: lair.position) <= RivalMind.rallyReach }.map { (lair: lair, muster: $0) } }
        guard let choice = choices.min(by: { a, b in
            (a.lair.level, a.muster.position.distance(to: a.lair.position), a.lair.id)
                < (b.lair.level, b.muster.position.distance(to: b.lair.position), b.lair.id)
        }) else { return [] }
        let chance: Int
        switch state.houses[house].temperament {
        case .ambitious: chance = 25
        case .steadfast: chance = 20
        case .cunning: chance = 15
        case .wary: chance = 10
        }
        guard random.chance(chance) else { return [] }
        return perform(.callRally(from: choice.muster.id, against: choice.lair.id, watches: 2), in: &state)
    }

    /// Companies it can spare sent to the rallies of its side whose war it
    /// shares, or against a lair: none standing in a hold or away on an errand, none from far
    /// off, and never so many that a hold of its own would go without a
    /// garrison. To an ally's rally, as many as its temper gives.
    func sendToRallies(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        for rally in state.ralliesStanding.sorted(by: { $0.id < $1.id }) where !rally.marching && state.isOfRally(house, rally) {
            guard let target = state.target(of: rally), state.mayStrike(house, target), let muster = state.hold(rally.muster) else { continue }
            let free = state.units(of: house).filter { $0.kind.isMilitary && $0.errand == nil }
            let spare = free.count - state.holds(of: house).count
            let given: Int
            switch state.houses[house].temperament {
            case .ambitious, .steadfast: given = RivalMind.massing ? 6 : 3
            case .cunning: given = RivalMind.massing ? 4 : 2
            case .wary: given = RivalMind.massing ? 3 : 1
            }
            var left = rally.caller == house ? spare : min(spare, given)
            let near = free.filter { state.hold(at: $0.position) == nil && $0.position.distance(to: muster.position) <= RivalMind.rallyReach }
                .sorted { ($0.position.distance(to: muster.position), $0.id) < ($1.position.distance(to: muster.position), $1.id) }
            for unit in near where left > 0 {
                let sent = perform(.joinRally(rally: rally.id, unit: unit.id), in: &state)
                if !sent.isEmpty { left -= 1 }
                events += sent
            }
        }
        return events
    }

    /// An ally's hold with companies of a House at war with them both near
    /// its gates gets a company of its own to keep them, one it can spare
    /// from near enough; gates no longer threatened are left.
    func keepAlliesGates(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        // The companies of war of the Houses this one is at war with, found
        // once, each by its place and its House alone: nothing here moves a
        // company or makes or ends a war.
        var foes: [(position: Hex, owner: Int)] = []
        for index in state.units.indices where state.units[index].kind.isMilitary && state.isAtWar(house, state.units[index].owner) {
            foes.append((state.units[index].position, state.units[index].owner))
        }
        // Sorted along the map's columns, so a hold looks only at the foes
        // within three columns of it: none further can be within three
        // hexes.
        foes.sort { $0.position.q < $1.position.q }
        func threatened(_ at: Hex, owner: Int) -> Bool {
            var low = 0, high = foes.count
            while low < high {
                let middle = (low + high) / 2
                if foes[middle].position.q < at.q - 3 { low = middle + 1 } else { high = middle }
            }
            for foe in foes[low...] {
                guard foe.position.q <= at.q + 3 else { break }
                if foe.position.distance(to: at) <= 3 && state.isAtWar(owner, foe.owner) { return true }
            }
            return false
        }
        func keptBy(_ holdID: Int) -> Bool {
            for index in state.units.places(of: house) {
                if case .reinforce(let kept)? = state.units[index].errand, kept == holdID { return true }
            }
            return false
        }
        for unit in state.units(of: house) {
            guard case .reinforce(let holdID)? = unit.errand, let hold = state.hold(holdID),
                  !threatened(hold.position, owner: hold.owner) else { continue }
            events += perform(.halt(unit: unit.id), in: &state)
        }
        guard let sworn = state.alliance(of: house) else { return events }
        // The allies' holds by their id, place and House, not copied whole.
        var allied: [(id: Int, position: Hex, owner: Int)] = []
        for index in state.holds.indices where state.holds[index].owner != house && sworn.members.contains(state.holds[index].owner) {
            allied.append((state.holds[index].id, state.holds[index].position, state.holds[index].owner))
        }
        for hold in allied.sorted(by: { $0.id < $1.id }) {
            guard threatened(hold.position, owner: hold.owner), !keptBy(hold.id) else { continue }
            let free = state.units(of: house).filter { $0.kind.isMilitary && $0.errand == nil }
            guard free.count > state.holds(of: house).count else { break }
            let near = free.filter { state.hold(at: $0.position) == nil && $0.position.distance(to: hold.position) <= 8 }
            guard let pick = near.min(by: { a, b in
                (a.position.distance(to: hold.position), a.id) < (b.position.distance(to: hold.position), b.id)
            }) else { continue }
            events += perform(.reinforce(unit: pick.id, hold: hold.id), in: &state)
        }
        return events
    }

    /// Whether the stewards mass their armies: siege rallies called by any
    /// House of an alliance at war, allies sending as many as their temper
    /// gives, and a House's free companies brought to its own holds' gates
    /// when a foe's companies stand near them, so that whole armies meet.
    nonisolated(unsafe) static var massing = false

    /// Whether the members of an alliance go for the hold their leader
    /// goes for, so their armies meet the foe as one front.
    nonisolated(unsafe) static var fronts = false

    /// A hold of its own with a foe's companies near its gates draws the
    /// House's free companies from within a rally's reach to keep them,
    /// as many as its temper gives, nearest first; gates no longer
    /// threatened are left, as an ally's are.
    func musterToTheGates(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        let foes = state.units.filter { $0.kind.isMilitary && state.isAtWar(house, $0.owner) }
        guard !foes.isEmpty else { return events }
        let mine = state.holds(of: house).filter { hold in foes.contains { $0.position.distance(to: hold.position) <= 3 } }
        let wanted: Int
        switch state.houses[house].temperament {
        case .steadfast, .wary: wanted = 6
        case .ambitious: wanted = 3
        case .cunning: wanted = 4
        }
        for hold in mine.sorted(by: { $0.id < $1.id }) {
            var keeping = state.units(of: house).filter {
                if case .reinforce(let kept)? = $0.errand { return kept == hold.id }
                return false
            }.count
            let free = state.units(of: house).filter { $0.kind.isMilitary && $0.errand == nil && state.hold(at: $0.position) == nil }
            let near = free.filter { $0.position.distance(to: hold.position) <= RivalMind.rallyReach }
                .sorted { ($0.position.distance(to: hold.position), $0.id) < ($1.position.distance(to: hold.position), $1.id) }
            for unit in near where keeping < wanted {
                let sent = perform(.reinforce(unit: unit.id, hold: hold.id), in: &state)
                if !sent.isEmpty { keeping += 1 }
                events += sent
            }
        }
        return events
    }

    /// On the watch before the Still Hour, a House at war with companies
    /// of war on the shore casts a ripple-stone from a hold on the shore,
    /// if it can spare the moonsalt: the wary and the cunning always, the
    /// others now and then.
    func stirTheWater(in state: inout GameState, random: inout SeededRandom) -> [GameEvent] {
        guard GameState.isStillHour(at: state.watch + 1), !state.hasRippled(house), state.isAtWarWithAny(house) else { return [] }
        guard state.units(of: house).contains(where: { $0.kind.isMilitary && state.isShore($0.position) }) else { return [] }
        guard state.houses[house].stock.moonsalt >= GameState.rippleCost.moonsalt * 3 else { return [] }
        let chance: Int
        switch state.houses[house].temperament {
        case .wary, .cunning: chance = 100
        case .steadfast: chance = 40
        case .ambitious: chance = 20
        }
        guard random.chance(chance),
              let hold = state.holds(of: house).sorted(by: { $0.id < $1.id }).first(where: { state.rippleRefusal(from: $0.id, as: house) == nil })
        else { return [] }
        return perform(.castRipple(hold: hold.id), in: &state)
    }

    /// A wary House at war, with moonsalt to spare, sinks a listening stone
    /// before its seat, or another hold by the water, to hear what comes
    /// at it unseen: one stone, never more, and no chance drawn for it.
    func sinkAListeningStone(in state: inout GameState) -> [GameEvent] {
        guard state.houses[house].temperament == .wary, state.isAtWarWithAny(house), state.stones(of: house).isEmpty,
              state.houses[house].stock.moonsalt >= GameState.stoneCost.moonsalt * 4 else { return [] }
        let holds = state.holds(of: house).sorted { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }
        guard let hold = holds.first(where: { state.stoneRefusal(before: $0.id, as: house) == nil }) else { return [] }
        return perform(.sinkStone(hold: hold.id), in: &state)
    }

    /// A cunning or ambitious House at war walks the mirror with one
    /// company that stands on the Still's shore, where the far shore it
    /// would come out on lies within three tiles of a hold of a House it is
    /// at war with: the nearest such hold first, one walk a watch at most,
    /// and moonsalt kept for more than the walk alone.
    func walkTheMirror(in state: inout GameState) -> [GameEvent] {
        guard [.cunning, .ambitious].contains(state.houses[house].temperament), state.isAtWarWithAny(house),
              state.houses[house].stock.moonsalt >= MirrorWalk.price.moonsalt * 2 else { return [] }
        let foes = state.holds.filter { $0.owner != house && state.isAtWar(house, $0.owner) }
        guard !foes.isEmpty else { return [] }
        var best: (unit: Int, reach: Int)?
        for unit in state.units where unit.owner == house && unit.kind.isMilitary
            && state.mirrorRefusal(unit.id, as: house) == nil {
            guard let landing = state.mirrorLanding(from: unit.position, for: unit.id),
                  let reach = foes.map({ $0.position.distance(to: landing) }).min(), reach <= 3 else { continue }
            if best == nil || (reach, unit.id) < (best!.reach, best!.unit) { best = (unit.id, reach) }
        }
        guard let chosen = best else { return [] }
        return perform(.walkTheMirror(unit: chosen.unit), in: &state)
    }

    /// The Archive a steward wants at its seat as the age goes on.
    static func archiveWanted(at watch: Int) -> Int {
        switch watch {
        case ..<12: return 0
        case ..<40: return 1
        case ..<70: return 2
        case ..<100: return 3
        default: return 4
        }
    }

    /// The branches of study in the order a temper pursues them.
    static func studyOrder(for temperament: Temperament) -> [Branch] {
        switch temperament {
        case .steadfast: return [.husbandry, .masonry, .lore, .arms]
        case .wary: return [.masonry, .husbandry, .lore, .arms]
        case .ambitious: return [.arms, .husbandry, .masonry, .lore]
        case .cunning: return [.husbandry, .lore, .arms, .masonry]
        }
    }

    /// With no study under way and an Archive to pursue one at, the first
    /// study open to it in its temper's order whose price it could pay
    /// twice over.
    func pursueStudies(in state: inout GameState) -> [GameEvent] {
        guard state.houses[house].research.pursuit == nil, state.archiveLevel(of: house) > 0 else { return [] }
        let stock = state.houses[house].stock
        for branch in RivalMind.studyOrder(for: state.houses[house].temperament) {
            for study in Study.of(branch) where state.studyRefusal(of: study, for: house) == nil {
                let grade = state.houses[house].research.grade(of: study) + 1
                guard stock.covers(state.studyPrice(of: study, grade: grade, for: house) * 2) else { continue }
                return perform(.study(study), in: &state)
            }
        }
        return []
    }

    /// A steward ransoms its commanders a keeper's House holds prisoner,
    /// when it has the moonsalt twice over. A caretaker leaves the keeper's
    /// moonsalt to the keeper.
    func ransomCaptives(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        for commander in state.commanders(of: house) where commander.captive != nil {
            let price = GameState.ransom(for: commander)
            guard state.houses[house].stock.moonsalt >= price.moonsalt * 2 else { continue }
            events += perform(.ransom(commander: commander.id), in: &state)
        }
        return events
    }

    /// Each commander free and whole to the head of a company of war at or
    /// beside one of its holds: a warden to a garrison, the others to a
    /// company outside the walls; of those, the strongest.
    func appointCommanders(in state: inout GameState) -> [GameEvent] {
        var events: [GameEvent] = []
        let holds = state.holds(of: house).map(\.position)
        for commander in state.commanders(of: house)
        where commander.captive == nil && !commander.isWounded(at: state.watch) && state.company(ledBy: commander.id) == nil {
            let candidates = state.units(of: house).filter { unit in
                unit.kind.isMilitary && unit.leader == nil && holds.contains { $0.distance(to: unit.position) <= 1 }
            }
            func fits(_ unit: Unit) -> Int {
                (commander.archetype == .warden) == holds.contains(unit.position) ? 1 : 0
            }
            if let best = candidates.max(by: { a, b in
                (fits(a), state.strength(of: a), -a.id) < (fits(b), state.strength(of: b), -b.id)
            }) {
                events += perform(.assign(commander: commander.id, unit: best.id), in: &state)
                continue
            }
            // No company left to lead: ride second with the strongest led
            // company beside a hold, one whose leader is of its own kind
            // first.
            let led = state.units(of: house).filter { unit in
                unit.leader != nil && unit.second == nil && holds.contains { $0.distance(to: unit.position) <= 1 }
            }
            func kin(_ unit: Unit) -> Int { state.commander(unit.leader ?? -1)?.archetype == commander.archetype ? 1 : 0 }
            guard let pair = led.max(by: { a, b in
                (kin(a), state.strength(of: a), -a.id) < (kin(b), state.strength(of: b), -b.id)
            }) else { continue }
            events += perform(.assignSecond(commander: commander.id, unit: pair.id), in: &state)
        }
        return events
    }

    /// Whether another House's hold stands within eight tiles of this one.
    private func bordersAnother(_ hold: Hold, in state: GameState) -> Bool {
        state.holds.contains { $0.owner != house && $0.position.distance(to: hold.position) <= 8 }
    }

    private func chooseTraining(for hold: Hold, owners: [Int?], atWar: Bool, siteKnown: inout Bool?, in state: GameState,
                                random: inout SeededRandom) -> UnitKind? {
        let me = state.houses[house]
        // Its companies counted by kind where they stand, in one pass, not
        // copied out and sifted four times.
        var lanterns = 0, founders = 0, military = 0, engines = 0
        for index in state.units.places(of: house) {
            let kind = state.units[index].kind
            if kind == .lantern { lanterns += 1 }
            if kind == .founder { founders += 1 }
            if kind.isMilitary { military += 1 }
            if kind == .mangonel { engines += 1 }
        }
        let holds = state.holds(of: house).count
        let netGrain = state.income(of: house, territory: owners).grain - state.upkeep(of: house)

        let wantedHolds: Int
        switch me.temperament {
        // Every temper reaches for the four holds whose storage the last
        // stage of a Moonspire needs, and one more: the ambitious further.
        case .ambitious: wantedHolds = 6
        case .cunning, .steadfast, .wary: wantedHolds = 5
        }
        let wealthy = me.stock.grain > 250 && me.stock.timber > 150 ? holds : 0
        // A builder with its Moonspire risen keeps a guard to match.
        let spire = state.seat(of: house)?.level(.moonspire) ?? 0
        let guardsSpire = (me.temperament == .steadfast || me.temperament == .wary) && spire >= 2 ? 2 + spire : 0
        let wantedArmy = holds * 2 + 1 + (atWar ? 3 + holds : 0) + (me.temperament == .ambitious ? 2 : 0) + wealthy + guardsSpire

        var choice: UnitKind?
        if lanterns < (state.watch < 20 ? 2 : 1), hold.isSeat {
            choice = .lantern
        } else if holds + founders < wantedHolds, founders == 0, military >= 2, netGrain > 2,
                  knowsSite(&siteKnown, from: hold.position, owners: owners, in: state) {
            choice = .founder
        } else if military < wantedArmy, netGrain > 1 || atWar {
            let muster = hold.level(.musterHall)
            // At war, engines to break walls with: Mangonels, a sixth of
            // the army and three at the most.
            if atWar, muster >= UnitKind.mangonel.requiredMuster, engines < min(RivalMind.mostEngines, 1 + military / 6),
               random.chance(30) {
                choice = .mangonel
            // Riders, fast and the hardest-hitting, the more so at war,
            // when holds must be taken.
            } else if muster >= 3, random.chance(atWar ? 50 : 35) {
                choice = .rider
            } else if muster >= 2, random.chance(35) {
                choice = .bow
            } else if muster >= 1 {
                choice = .spear
            }
        }
        // A House that can muster its own company, at the fifth tier, reaches
        // for it more often than not.
        let own = state.heritage(of: house).signature
        if choice?.isMilitary == true, choice != .mangonel, state.highestTier(of: own, at: hold, for: house) == Unit.highestTier,
           random.chance(60) {
            choice = own
        }
        // A keeper's standing orders: the one kind of company of war their
        // caretaker musters, and none where the hold can't muster it.
        if caretaking, choice?.isMilitary == true, let told = state.standingOrders(of: house).muster {
            return state.refusal(of: .train(hold: hold.id, kind: told), as: house) == nil ? told : nil
        }
        guard var kind = choice, hold.level(.musterHall) >= kind.requiredMuster else { return nil }
        // Riders, bows or engines it can't pay for: spears, rather than nothing.
        if !me.stock.covers(state.trainingCost(of: kind, for: house)), [.rider, .bow, .mangonel].contains(kind) { kind = .spear }
        guard me.stock.covers(state.trainingCost(of: kind, for: house)) else { return nil }
        return kind
    }

    /// The tier to muster a company at: the highest the hold can, whose
    /// price the House could pay twice over and whose hunger its grain can
    /// bear; else the first.
    func chooseTier(of kind: UnitKind, at hold: Hold, owners: [Int?]? = nil, in state: GameState) -> Int {
        let highest = state.highestTier(of: kind, at: hold, for: house)
        guard highest > 1 else { return 1 }
        let stock = state.houses[house].stock
        let netGrain = state.income(of: house, territory: owners ?? state.territory()).grain - state.upkeep(of: house)
        for tier in stride(from: highest, to: 1, by: -1) {
            let cost = state.trainingCost(of: kind, tier: tier, for: house)
            if stock.covers(cost * 2), netGrain > kind.upkeep(tier: tier) + 1 { return tier }
        }
        return 1
    }

    // MARK: Units

    /// Picks a defender for every hold that has none standing on it, of the
    /// companies not away on an errand.
    private func assignGarrisons(in state: GameState) -> [Int: Hex] {
        var result: [Int: Hex] = [:]
        // None busy at the Crown's gates. Each company and hold by its id
        // and place alone, not copied whole: asked for every siege plan.
        let gates = state.gatesStanding
        var free: [(id: Int, position: Hex)] = []
        for index in state.units.places(of: house) where state.units[index].kind.isMilitary
            && state.units[index].errand == nil && (gates.isEmpty || !atTheCrown(state.units[index], gates)) {
            free.append((state.units[index].id, state.units[index].position))
        }
        var posts: [(order: (seat: Int, id: Int), position: Hex)] = []
        for index in state.holds.places(of: house) {
            posts.append(((state.holds[index].isSeat ? 0 : 1, state.holds[index].id), state.holds[index].position))
        }
        for post in posts.sorted(by: { $0.order < $1.order }) {
            if let standing = free.firstIndex(where: { $0.position == post.position }) {
                result[free[standing].id] = post.position
                free.remove(at: standing)
                continue
            }
            guard let nearest = free.indices.min(by: { a, b in
                (free[a].position.distance(to: post.position), free[a].id) < (free[b].position.distance(to: post.position), free[b].id)
            }), free[nearest].position.distance(to: post.position) <= 8 else { continue }
            result[free[nearest].id] = post.position
            free.remove(at: nearest)
        }
        return result
    }

    /// `home`, the land's territory where a keeper's standing orders keep
    /// every company on its House's own land.
    private func command(_ unitID: Int, garrisonFor post: Hex?, seeing visible: [Bool], atWar: Bool, home: [Int?]? = nil,
                         in state: inout GameState) -> [GameEvent] {
        guard let unit = state.unit(unitID) else { return [] }
        switch unit.kind {
        case .lantern:
            // At war, a Lantern within reach of a foe's hold scouts it now
            // and then, before going on its way.
            if atWar, (state.watch + unit.id) % RivalMind.scoutEvery == 0, unit.movesLeft > 0,
               let hold = state.holds.filter({ state.isAtWar(house, $0.owner) && $0.position.distance(to: unit.position) <= GameState.scoutReach })
                   .min(by: { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }) {
                return perform(.scout(unit: unit.id, hold: hold.id), in: &state)
            }
            return explore(with: unit, in: &state)
        case .founder:
            return settle(with: unit, in: &state)
        case .spear, .bow, .rider, .mangonel:
            // A company sent to a rally, or keeping an ally's gates, is the
            // rally's or the gates' until it is done.
            switch unit.errand {
            case .rally?, .reinforce?: return []
            default: break
            }
            if let post {
                if unit.position == post {
                    // A garrison strikes only companies of war in its reach:
                    // a scout or Founders at the gates are no reason to give
                    // up its guard.
                    if let target = foeInReach(of: unit, companiesOfWarOnly: true, in: state) {
                        return perform(.attack(unit: unitID, target: target), in: &state)
                    }
                    return unit.fortified ? [] : perform(.fortify(unit: unitID), in: &state)
                }
                return perform(.move(unit: unitID, to: post), in: &state)
            }
            if let home { return keepHome(unit, territory: home, atWar: atWar, in: &state) }
            return campaign(with: unit, seeing: visible, atWar: atWar, in: &state)
        }
    }

    /// A company a keeper's standing orders keep home: it strikes a company
    /// of war in its reach, digs in on its House's own land, and from
    /// anywhere else makes for the nearest open ground of it. Out at the
    /// land's work it is called home with what it carries at war, and sees
    /// its errand through at peace, as one bringing its load home always
    /// does.
    private func keepHome(_ unit: Unit, territory owners: [Int?], atWar: Bool, in state: inout GameState) -> [GameEvent] {
        if let errand = unit.errand {
            if case .gather = errand, atWar { return perform(.recall(unit: unit.id), in: &state) }
            return []
        }
        if let target = foeInReach(of: unit, companiesOfWarOnly: true, in: state) {
            return perform(.attack(unit: unit.id, target: target), in: &state)
        }
        let mine = Set(state.holds(of: house).map(\.id))
        if let index = state.map.index(of: unit.position), let owner = owners[index], mine.contains(owner) {
            return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
        }
        var nearest: Hex?
        for (index, owner) in owners.enumerated() {
            guard let owner, mine.contains(owner) else { continue }
            let hex = state.map.hex(at: index)
            guard state.map[index].terrain.isPassable, !state.isOccupied(hex) else { continue }
            if nearest.map({ (hex.distance(to: unit.position), hex) < ($0.distance(to: unit.position), $0) }) ?? true { nearest = hex }
        }
        guard let nearest else { return [] }
        return perform(.move(unit: unit.id, to: nearest), in: &state)
    }

    private func foeInReach(of unit: Unit, companiesOfWarOnly: Bool = false, in state: GameState) -> Hex? {
        guard unit.movesLeft > 0 else { return nil }
        let range = unit.kind.range
        // What stands within its reach: the companies read off the realm's
        // board hex by hex, the holds in one pass over them, not each sought
        // for every hex; the first on a hex, as `unit(at:)` and `hold(at:)`
        // find it, kept by its owner and kind alone, not copied out whole.
        // Each in its place on a little board about the company, by its
        // offset from it, not hashed.
        let side = 2 * range + 1
        var standing = [(owner: Int, military: Bool)?](repeating: nil, count: side * side)
        var holding = [Int?](repeating: nil, count: side * side)
        let at = unit.position
        func place(_ hex: Hex) -> Int { (hex.q - at.q + range) * side + (hex.r - at.r + range) }
        at.forEach(within: range) { hex in
            if let index = state.units.first(at: hex) {
                standing[place(hex)] = (state.units[index].owner, state.units[index].kind.isMilitary)
            }
        }
        for index in state.holds.indices {
            let position = state.holds[index].position
            guard abs(position.q - at.q) <= range, position.distance(to: at) <= range else { continue }
            let slot = place(position)
            if holding[slot] == nil { holding[slot] = state.holds[index].owner }
        }
        // A steward keeps the realm's edicts: what a strike would break them on, it leaves.
        let lawful = state.edictsInForce.isEmpty
        return unit.position.spiral(range).dropFirst().first { hex in
            let slot = place(hex)
            // A hold under its House's veil, and whoever keeps it, is let be.
            if let owner = holding[slot], state.isVeiled(owner) { return false }
            if let other = standing[slot], other.owner != house, state.isAtWar(house, other.owner) {
                return (other.military || !companiesOfWarOnly) && (lawful || state.edictsBroken(striking: hex, from: unit).isEmpty)
            }
            if let owner = holding[slot], owner != house, state.isAtWar(house, owner) {
                return !companiesOfWarOnly && (lawful || state.edictsBroken(striking: hex, from: unit).isEmpty)
            }
            return false
        }
    }

    private func campaign(with unit: Unit, seeing visible: [Bool], atWar: Bool, in state: inout GameState) -> [GameEvent] {
        if let target = foeInReach(of: unit, in: state) {
            return perform(.attack(unit: unit.id, target: target), in: &state)
        }
        // A foe's standard or hall within reach, with no company on it, is torn down.
        if unit.movesLeft > 0, let flag = unit.position.spiral(unit.kind.range).dropFirst().first(where: { hex in
            // The standards and halls, few, before the companies, many.
            (state.standard(at: hex).map { state.isAtWar(house, $0.raisedBy) } == true
                || state.hall(at: hex).map { state.isFoe(house, of: $0) } == true) && state.unit(at: hex) == nil
        }) {
            return perform(.attack(unit: unit.id, target: flag), in: &state)
        }
        // A gate of the Crown in its reach, it strikes, from beside it only
        // while it can take the gate's blow back; bound before one, it goes on.
        if unit.movesLeft > 0, unit.kind.range > 1 || unit.health >= RivalMind.gateHealth,
           let gate = state.gatesStanding.first(where: { unit.position.distance(to: $0.position) <= unit.kind.range }) {
            return perform(.attack(unit: unit.id, target: gate.position), in: &state)
        }
        if let bound = unit.destination, state.gatesStanding.contains(where: { $0.position.distance(to: bound) <= 1 }) {
            return []
        }
        // On a holy site its side doesn't hold yet, it stands until the
        // watch turns; bound for one, it goes on.
        if let shrine = state.shrine(at: unit.position) ?? unit.destination.flatMap({ state.shrine(at: $0) }),
           !(shrine.holder.map { $0 == house || state.areAllied($0, house) } ?? false) {
            return []
        }
        // Bearing the Drowned Crown, it holds where it stands; bound for it
        // while its side bears it not, it goes on.
        if let crown = state.crown {
            if crown.bearer == unit.id { return [] }
            let ours = crown.bearer.flatMap(state.unit).map { state.crownSide(of: $0.owner) == state.crownSide(of: house) } ?? false
            if unit.destination == crown.hex, !ours { return [] }
        }
        // At peace, a company on an errand sees it through.
        if unit.errand != nil, !atWar { return [] }
        // Meet enemy companies of war who come close: never a scout or
        // Founders, and with a siege to press, only one in the way or at
        // this House's own gates, never one that would lead it off.
        let siege = siegePlan(in: state)
        var gates: [Hex] = []
        for index in state.holds.places(of: house) { gates.append(state.holds[index].position) }
        // An engine meets no one: soft in the field, it keeps to its siege.
        // The companies near read off the realm's board, hex by hex within
        // three, every one on a hex, not sought through all the realm's;
        // through a list held for the look rather than read through the
        // realm handed in to be changed, and let go before it is.
        var skirmish: (key: (Int, Int), position: Hex)?
        if unit.kind != .mangonel {
            let units = state.units
            unit.position.forEach(within: 3) { position in
                for id in units.ids(at: position) {
                    guard let index = units.index(ofID: id) else { continue }
                    let distance = position.distance(to: unit.position), owner = units[index].owner
                    guard owner != house, units[index].kind.isMilitary, state.isAtWar(house, owner) else { continue }
                    if let siege, position.distance(to: siege.target) > unit.position.distance(to: siege.target),
                       !gates.contains(where: { $0.distance(to: position) <= 3 }) {
                        continue
                    }
                    guard let tile = state.map.index(of: position), visible[tile] else { continue }
                    let key = (distance, id)
                    if skirmish.map({ key < $0.key }) ?? true { skirmish = (key, position) }
                }
            }
        }
        if let skirmish {
            return perform(.move(unit: unit.id, to: skirmish.position), in: &state)
        }
        // With no siege to press, to a battle its House fights near, to
        // stand with its side.
        if siege == nil, state.field(of: unit.id) == nil, let field = state.fieldsOfBattle
            .filter({ $0.side(of: house) != nil && (2...RivalMind.battleCall).contains($0.at.distance(to: unit.position)) })
            .min(by: { ($0.at.distance(to: unit.position), $0.id) < ($1.at.distance(to: unit.position), $1.id) }) {
            return perform(.move(unit: unit.id, to: field.at), in: &state)
        }
        if let siege {
            let near = unit.position.distance(to: siege.target) <= RivalMind.siegeReach
            // An engine never goes in: it stands off at its reach, on open
            // ground, and hurls its stones at the walls from there.
            if unit.kind == .mangonel, siege.ready || near {
                if unit.position.distance(to: siege.target) <= unit.kind.range {
                    return unit.movesLeft > 0 ? perform(.attack(unit: unit.id, target: siege.target), in: &state) : []
                }
                if let stand = standoff(for: unit, from: siege.target, in: state) {
                    return perform(.move(unit: unit.id, to: stand), in: &state)
                }
                return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
            }
            if siege.ready || (near && unit.position.distance(to: siege.target) <= unit.kind.range + 1) {
                return perform(.move(unit: unit.id, to: siege.target), in: &state)
            }
            if unit.position.distance(to: siege.muster) > 1 {
                return perform(.move(unit: unit.id, to: siege.muster), in: &state)
            }
            return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
        }
        // Its nearest hold, found where the holds stand and only it copied.
        var nearest: Int?
        for index in state.holds.places(of: house) {
            if let best = nearest, (state.holds[best].position.distance(to: unit.position), state.holds[best].id)
                <= (state.holds[index].position.distance(to: unit.position), state.holds[index].id) { continue }
            nearest = index
        }
        let home = nearest.map { state.holds[$0] }
        // Carrying the land's stores, home with them.
        if let load = unit.load, !load.isZero, let home, home.position.distance(to: unit.position) > 1 {
            return perform(.move(unit: unit.id, to: home.position), in: &state)
        }
        // At peace: hunt the wilds near its land, if the odds are good.
        if let prey = prey(for: unit, in: state) {
            return perform(.move(unit: unit.id, to: prey), in: &state)
        }
        // Or work a site for a store its House runs short of.
        if !atWar, let site = site(for: unit, in: state) {
            return perform(.gather(unit: unit.id, site: site), in: &state)
        }
        // Or wait near the nearest hold: beside it, where its Muster Hall
        // drills those who wait; with no room beside it, near it.
        if let home, home.position.distance(to: unit.position) > (home.level(.musterHall) > 0 ? 1 : 2) {
            let moved = perform(.move(unit: unit.id, to: home.position), in: &state)
            if !moved.isEmpty || home.position.distance(to: unit.position) > 2 { return moved }
        }
        return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
    }

    /// How close to a besieged hold the army gathers before it goes in.
    static let siegeReach = 4
    /// The most Mangonels a steward musters.
    static let mostEngines = 3

    /// Where an engine stands to hurl its stones at a hold: open ground at
    /// its reach from the hold, the nearest the engine; its own ground, if
    /// it stands at its reach already.
    func standoff(for unit: Unit, from target: Hex, in state: GameState) -> Hex? {
        let range = unit.kind.range
        return target.spiral(range).filter { hex in
            guard hex.distance(to: target) == range, let tile = state.map[hex], tile.terrain.isPassable, !tile.terrain.isWater else { return false }
            return hex == unit.position || !state.isOccupied(hex)
        }.min { ($0.distance(to: unit.position), $0) < ($1.distance(to: unit.position), $1) }
    }
    /// How far a steward's company goes to a battle its House fights.
    static let battleCall = 6
    /// How far from its own holds a steward's company goes hunting, or
    /// gathering.
    static let huntingGround = 9

    /// A site for a company at peace to work: the nearest in reach of its
    /// House's land, of a store the House has less than half the room for,
    /// with no company on it or bound for it.
    func site(for unit: Unit, in state: GameState) -> Int? {
        guard unit.load?.isZero ?? true, !state.sitesInLand.isEmpty else { return nil }
        let stock = state.houses[house].stock
        let room = state.storage(of: house)
        // In a Harvest Fair the steadfast and the wary gather any store
        // they have room for.
        let temper = state.houses[house].temperament
        let fair = state.happening?.kind == .harvestFair && (temper == .steadfast || temper == .wary)
        let short = Resource.allCases.filter { stock[$0] < (fair ? room * 9 / 10 : room / 2) }
        guard !short.isEmpty else { return nil }
        // Its holds where they stand, not copied out whole; how far each
        // site lies asked before its tile is sought on the map.
        var holds: [Hex] = []
        for index in state.holds.places(of: house) { holds.append(state.holds[index].position) }
        let explored = state.houses[house].explored
        let sworn = state.alliance(of: house)?.id
        let near = state.sitesInLand.filter { site in
            site.position.distance(to: unit.position) <= RivalMind.huntingGround
                && short.contains(site.store) && (site.alliance == nil || site.alliance == sworn)
                && holds.contains { $0.distance(to: site.position) <= RivalMind.huntingGround }
                && (state.map.index(of: site.position).map { explored[$0] } ?? false)
        }
        guard !near.isEmpty else { return nil }
        // Of these few, those a company works or is bound for, or stands
        // on, found in one pass over the companies.
        var taken = [Bool](repeating: false, count: near.count)
        for index in state.units.indices {
            let position = state.units[index].position
            var bound: Int?
            if case .gather(let site)? = state.units[index].errand { bound = site }
            for (entry, site) in near.enumerated() where site.position == position || site.id == bound { taken[entry] = true }
        }
        return near.indices.filter { !taken[$0] }.map { near[$0] }
            .min { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }?.id
    }

    /// The wilds a company would hunt: the nearest within its hunting
    /// ground that it would strike down, blow on blow from its reach, with
    /// a tenth of its health to spare. The ambitious and the cunning go
    /// further afield.
    func prey(for unit: Unit, in state: GameState) -> Hex? {
        guard unit.health >= 60, !state.wildsStanding.isEmpty else { return nil }
        let temper = state.houses[house].temperament
        // The ambitious and the cunning go further afield, and further
        // still in a Long Hunt.
        let eager = temper == .ambitious || temper == .cunning
        let hunt = state.happening?.kind == .longHunt
        let ground = RivalMind.huntingGround + (eager ? 3 : 0) + (eager && hunt ? 3 : 0)
        var holds: [Hex] = []
        for index in state.holds.places(of: house) { holds.append(state.holds[index].position) }
        let near = state.wildsStanding.filter { wild in
            wild.position.distance(to: unit.position) <= ground && holds.contains { $0.distance(to: wild.position) <= ground }
        }
        let fit = near.filter { wild in
            let odds = state.forecast(unit, against: wild, fromReach: true)
            // Each blow less what it mends between them.
            let dealt = (odds.dealt.lowerBound + odds.dealt.upperBound) / 2 - GameState.wildsMending
            let taken = (odds.taken.lowerBound + odds.taken.upperBound) / 2
            guard dealt > 0 else { return false }
            let blows = (wild.health + dealt - 1) / dealt
            return taken * blows * 10 < unit.health * 9
        }
        return fit.min { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }?.position
    }

    struct Siege {
        let target: Hex
        let muster: Hex
        /// Whether enough companies have gathered to go in together.
        let ready: Bool
    }

    /// One enemy hold to take, the place to gather before it, and whether
    /// the army has gathered. A rising Moonspire is always the target;
    /// otherwise the nearest known enemy hold to this House's seat.
    func siegePlan(in state: GameState) -> Siege? {
        guard let seat = state.seat(of: house) else { return nil }
        let explored = state.houses[house].explored
        // By index, none copied but the hold taken: each foe's own holds it
        // knows, rather than every hold of the realm sought, in the realm's
        // order.
        var enemyHolds: [Int] = []
        for owner in state.houses.indices where state.isAtWar(house, owner) {
            for index in state.holds.places(of: owner)
                where state.map.index(of: state.holds[index].position).map({ explored[$0] }) ?? false {
                enemyHolds.append(index)
            }
        }
        enemyHolds.sort()
        let target: Hold?
        // An alliance's front: a member goes for the hold its leader goes
        // for, when it is at war with that hold's House and knows it, so
        // the allies' armies meet the foe together on one field.
        let front: Int? = {
            guard RivalMind.fronts, let sworn = state.alliance(of: house), sworn.leader != house else { return nil }
            guard let aim = RivalMind(house: sworn.leader).siegePlan(in: state)?.target else { return nil }
            return enemyHolds.first { state.holds[$0].position == aim }
        }()
        if let rising = risingFoe(in: state), let spire = state.seat(of: rising) {
            target = spire
        } else if let front {
            target = state.holds[front]
        } else {
            // Go for the weakest House within reach, to finish it, then
            // its nearest hold; and once far the stronger, for its seat,
            // whose fall shakes all the rest: its own strength weighed the
            // first time a seat asks.
            var mine: Int?
            // Each House's holds counted as the realm keeps them, and its
            // strength weighed once for the plan, not at every comparison of
            // its holds; each hold's cost reckoned once.
            var strong = [Int?](repeating: nil, count: state.houses.count)
            func cost(_ index: Int) -> Int {
                let owner = state.holds[index].owner
                var cost = state.holds[index].position.distance(to: seat.position) + 4 * state.holds.count(of: owner)
                if state.holds[index].isSeat {
                    let own = mine ?? state.strength(of: house)
                    mine = own
                    let theirs = strong[owner] ?? state.strength(of: owner)
                    strong[owner] = theirs
                    if own * 10 > theirs * 18 { cost -= 8 }
                }
                return cost
            }
            var best: (key: (Int, UInt64), index: Int)?
            for index in enemyHolds {
                let key = (cost(index), tieBreak(state.holds[index].id, in: state))
                if best.map({ key < $0.key }) ?? true { best = (key, index) }
            }
            target = best.map { state.holds[$0.index] }
        }
        guard let target else { return nil }

        // Gather a few tiles short of it, on the way from home.
        let ideal = target.position.step(3, alongLineTo: seat.position)
        let muster = ideal.spiral(2).first { hex in
            guard let tile = state.map[hex], tile.terrain.isPassable else { return false }
            return state.hold(at: hex) == nil
        } ?? ideal

        // The army and the defenders counted where they stand among their
        // Houses' own, not sought through every company of the realm.
        let garrisons = Set(assignGarrisons(in: state).keys)
        var army = 0, gathered = 0, defenders = 0
        for index in state.units.places(of: house) where state.units[index].kind.isMilitary && !garrisons.contains(state.units[index].id) {
            army += 1
            if state.units[index].position.distance(to: target.position) <= RivalMind.siegeReach + 1 { gathered += 1 }
        }
        for index in state.units.places(of: target.owner)
            where state.units[index].kind.isMilitary && state.units[index].position.distance(to: target.position) <= 2 {
            defenders += 1
        }
        let needed = max(3, defenders + 2)
        let ready = target.ward == 0 || gathered >= needed || (gathered >= 2 && gathered == army && army >= defenders + 2)
        return Siege(target: target.position, muster: muster, ready: ready)
    }

    private func explore(with unit: Unit, in state: inout GameState) -> [GameEvent] {
        guard unit.destination == nil, let start = state.map.index(of: unit.position) else { return [] }
        let explored = state.houses[house].explored
        let map = state.map
        // Tiles by their index, not hexes in sets: a scout searches far.
        // What stands on each and which it has reached, in a room kept from
        // one scout's look to the next, not laid out anew for every scout.
        var room = ScoutRoom.take(count: map.count)
        defer { ScoutRoom.give(back: &room) }
        room.ready(in: state)
        // Known ruins first, then the nearest edge of the unknown: tile by
        // tile through the map's neighbours, in the order of the directions.
        let neighbours = map.neighbours
        room.reach(start)
        var queue = [start]
        queue.reserveCapacity(2_600)
        var head = 0
        var frontier: Int?
        while head < queue.count, head < 2_500 {
            let tile = queue[head]
            head += 1
            if tile != start, !room.occupied[tile] {
                if map[tile].feature == .drownedRuin {
                    frontier = tile
                    break
                }
                if frontier == nil, (0..<6).contains(where: { side in
                    let next = Int(neighbours[tile * 6 + side])
                    return next >= 0 && !explored[next]
                }) {
                    frontier = tile
                }
            }
            for side in 0..<6 {
                let next = Int(neighbours[tile * 6 + side])
                guard next >= 0, !room.hasReached(next), map[next].terrain.isPassable else { continue }
                room.reach(next)
                queue.append(next)
            }
            if frontier != nil, head > 400 { break }
        }
        if let frontier {
            return perform(.move(unit: unit.id, to: map.hexes[frontier]), in: &state)
        }
        return unit.fortified ? [] : perform(.fortify(unit: unit.id), in: &state)
    }

    private func settle(with unit: Unit, in state: inout GameState) -> [GameEvent] {
        if state.canFound(at: unit.position, for: house) == nil,
           let best = bestSite(from: unit.position, in: state),
           siteScore(unit.position, in: state) * 10 >= siteScore(best, in: state) * 8 {
            return perform(.found(unit: unit.id), in: &state)
        }
        guard let site = bestSite(from: unit.position, in: state) else { return [] }
        return perform(.move(unit: unit.id, to: site), in: &state)
    }

    /// The most promising place to found a hold that this House knows of.
    func bestSite(from origin: Hex, owners territory: [Int?]? = nil, in state: GameState) -> Hex? {
        let explored = state.houses[house].explored
        let owners = territory ?? state.territory()
        let anchors = state.holds(of: house).map(\.position)
        let map = state.map
        // What rules a tile out, found once by its index: a hold within
        // three, another House's company on it, or the wilds. Only what
        // lies near enough to a hold of the House's own to rule out a tile
        // it would weigh.
        let reach = 9
        // The bounds of its holds, a hex beyond them passed over at a
        // glance, not measured from each of its holds in turn: a realm of
        // many seats has many holds, companies and wilds far from its own.
        var low = (q: Int.max, r: Int.max, s: Int.max), high = (q: Int.min, r: Int.min, s: Int.min)
        for anchor in anchors {
            low = (min(low.q, anchor.q), min(low.r, anchor.r), min(low.s, anchor.s))
            high = (max(high.q, anchor.q), max(high.r, anchor.r), max(high.s, anchor.s))
        }
        func near(_ hex: Hex, within beyond: Int) -> Bool {
            let far = reach + beyond, s = hex.s
            guard hex.q >= low.q - far, hex.q <= high.q + far, hex.r >= low.r - far, hex.r <= high.r + far,
                  s >= low.s - far, s <= high.s + far else { return false }
            return anchors.contains { $0.distance(to: hex) <= far }
        }
        // The holds and companies read where they stand, not copied.
        var ruledOut = [Bool](repeating: false, count: map.count)
        for index in state.holds.indices where near(state.holds[index].position, within: 3) {
            map.forEachIndex(within: 3, of: state.holds[index].position) { ruledOut[$0] = true }
        }
        for index in state.units.indices where state.units[index].owner != house && near(state.units[index].position, within: 0) {
            if let tile = map.index(of: state.units[index].position) { ruledOut[tile] = true }
        }
        for wild in state.wildsStanding where near(wild.position, within: 0) {
            if let index = map.index(of: wild.position) { ruledOut[index] = true }
        }
        // Its own holds by id: land a hold of any other House holds, or of
        // none known, is not to be weighed.
        var mine = Set<Int>()
        for index in state.holds.places(of: house) { mine.insert(state.holds[index].id) }
        var best: (score: Int, hex: Hex)?
        for anchor in anchors {
            for hex in anchor.spiral(reach) {
                guard let index = map.index(of: hex), explored[index] else { continue }
                guard map[index].terrain.isSettleable, !ruledOut[index] else { continue }
                if owners[index].map({ !mine.contains($0) }) ?? false { continue }
                let score = siteScore(hex, in: state) * 3 - hex.distance(to: origin)
                if best == nil || (score, hex) > (best!.score, best!.hex) {
                    best = (score, hex)
                }
            }
        }
        return best.map(\.hex)
    }

    /// Whether the House knows a site for a new hold, from wherever it is
    /// asked: found the first time, then known for the rest of the turn.
    private func knowsSite(_ known: inout Bool?, from origin: Hex, owners: [Int?], in state: GameState) -> Bool {
        if let known { return known }
        let found = bestSite(from: origin, owners: owners, in: state) != nil
        known = found
        return found
    }

    private func siteScore(_ hex: Hex, in state: GameState) -> Int {
        hex.spiral(1).reduce(0) { total, cell in
            guard let tile = state.map[cell] else { return total }
            return total + RivalMind.weight(tile.terrain.yield) + (tile.feature.map { RivalMind.weight($0.yield) } ?? 0)
        }
    }

    /// What a yield weighs toward a site: moonsalt three times over.
    private static func weight(_ yield: Stock) -> Int {
        yield.grain + yield.timber + yield.stone + yield.moonsalt * 3
    }

    private func enemyMilitary(near hex: Hex, within distance: Int, in state: GameState) -> Bool {
        // Each company looked at where it stands, those far along the map's
        // columns passed over at a glance: not each copied out to be asked.
        for index in state.units.indices {
            let position = state.units[index].position
            guard abs(position.q - hex.q) <= distance, position.distance(to: hex) <= distance else { continue }
            let owner = state.units[index].owner
            if owner != house, state.units[index].kind.isMilitary, state.isAtWar(house, owner) { return true }
        }
        return false
    }
}

extension GameState {
    /// The most promising place a House knows of to found a hold, as its
    /// steward would choose it, from where a founder stands: for a keeper
    /// who can't point at the map.
    public func bestFoundingSite(for house: Int, from origin: Hex) -> Hex? {
        RivalMind(house: house).bestSite(from: origin, in: self)
    }
}
