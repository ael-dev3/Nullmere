import Foundation

/// Counsel taken of a House's commander: who they are, what they know and
/// what they may put to the keeper, all of it from the keeper's own view of
/// the realm. A commander knows what their House knows and no more: the
/// view the realm sends a keeper is already fogged (Fog.swift), so nothing
/// here can tell of a company the House cannot see. The words are Apple's
/// on-device model's (NullmereCounsel); the facts and the orders are the
/// realm's, and an order the commander puts forward is only ever proposed:
/// the keeper gives it or not, and the realm decides what comes of it.
public struct CommanderCounsel: Sendable {
    public let state: GameState
    public let player: Int
    public let commander: Commander
    /// The battles the commander led the House's companies in lately, as
    /// their reports read, the latest first: what they remember of them.
    public let battles: [BattleReport]

    /// Counsel of one of the keeper's own commanders, or nil if the House
    /// has no such commander; `reports` the House's reports as the Mac or
    /// the phone keeps them, the latest first, of which the commander
    /// remembers the battles they led in.
    public init?(state: GameState, player: Int, commander id: Int, reports: [BattleReport] = []) {
        guard let commander = state.commander(id), commander.owner == player else { return nil }
        self.state = state
        self.player = player
        self.commander = commander
        self.battles = state.battles(ledBy: commander, in: reports)
    }

    /// The keeper's question of a battle the commander led in, as put to
    /// them from its report: "How went the fight at Wenholme in watch 12?"
    public static func askedOf(_ report: BattleReport) -> String {
        "How went the fight \(report.place) in watch \(report.watch)?"
    }

    /// A battle as the commander remembers it: when and where, how it came
    /// out, each side as it came and left, and the report's own lines.
    func remembered(_ report: BattleReport) -> String {
        var told = "In watch \(report.watch), \(report.place): \(report.title)."
        for side in report.sides { told += " \(side.said)." }
        for line in report.lines.prefix(CommanderCounsel.linesRemembered) { told += " \(line)." }
        return told
    }

    /// The most of a report's own lines a commander remembers of it.
    static let linesRemembered = 4

    /// The battles the commander remembers, in a line for counsel on the
    /// Mac and the phone alike: "Remembers the fight at Wenholme in watch
    /// 12, won."; nil for none.
    public var remembersSaid: String? {
        guard !battles.isEmpty else { return nil }
        let told = battles.map { "\($0.place) in watch \($0.watch), \($0.outcome.said.lowercased())" }
        let list = told.count == 1 ? told[0] : told.dropLast().joined(separator: "; ") + "; and " + told[told.count - 1]
        return (told.count == 1 ? "Remembers the fight " : "Remembers the fights ") + list + "."
    }

    /// The company the commander leads, if any.
    public var company: Unit? {
        state.units(of: player).first { $0.leader == commander.id || $0.second == commander.id }
    }

    /// A company of the House by its handle, C1, C2 and on, as the order
    /// book numbers them.
    public func company(_ handle: String) -> Unit? {
        SpokenOrders.company(handle, in: state, player: player)
    }

    /// A company's handle as the order book numbers it.
    public func handle(of unit: Unit) -> String? {
        SpokenOrders.companies(in: state, player: player).firstIndex { $0.id == unit.id }.map { "C\($0 + 1)" }
    }

    /// How the commander's kind counsels.
    var bent: String {
        switch commander.archetype {
        case .warden: return "You hold the line and the walls: you counsel patience, digging in and keeping the holds."
        case .vanguard: return "You strike first and hardest: you counsel the bold stroke, but never a hopeless one."
        case .outrider: return "You see far and ride fast: you counsel scouting, harrying and hunting the wilds."
        case .gleaner: return "You work the land's sites and bring the stores home: you counsel gathering and good husbandry."
        case .wallbreaker: return "You break wards and walls: you counsel sieges, and the engines and the patience they want."
        }
    }

    /// What the model speaks by: who the commander is, how they speak, and
    /// what they must hold to.
    public var instructions: String {
        """
        You are \(commander.name), \(commander.archetype.named) of the House of \(houseTitle), a commander of \
        level \(commander.level), counselling your keeper in Nullmere Online, a realm of great Houses about a \
        vast black lake of still water under the moon. \(bent) Speak as yourself to your keeper: grave, spare \
        and plain, as an old soldier speaks, in at most three sentences and seventy words, with no exclamation \
        marks and no modern words. Know only what you are told here and what your looks tell you: never invent \
        a number, a name, a place or an event. To learn more, look: at a company, about your own company, at \
        your House's affairs, at its holds, at your alliance, at yourself (your talents, stars and gear), or at another House by its name. You \
        may put an order to your keeper only by proposing it, for a company, for a hold of your House, for yourself, for your House's \
        alliance, toward another House or in answer to an envoy waiting on your House, and you never give one yourself: say that you \
        have put it forward, and \
        that the keeper decides. Name companies by their \
        handles and names as given. Never speak of games, players, turns, rules, models or tools.
        """
    }

    var houseTitle: String {
        state.houses.indices.contains(player) ? state.houses[player].title : "your House"
    }

    /// What the commander knows as counsel begins: themself and their
    /// company, their House's standing, and the watch.
    public var briefing: String {
        var lines = ["It is watch \(state.watch)."]
        if commander.isWounded(at: state.watch) {
            lines.append("You are wounded, and lead no company until you mend.")
        }
        if let unit = company, let handle = handle(of: unit) {
            lines.append("You lead \(handle), \(described(unit)).")
        } else {
            lines.append("You lead no company now.")
        }
        lines.append("Your skills: " + commander.skills.map(\.title).joined(separator: ", ") + ".")
        // Where they stand themself, as their line on the Commanders board
        // tells it: what more they may look at, and put forward, of it.
        lines.append(standingSaid)
        if !battles.isEmpty {
            lines.append("Battles you led your House's companies in lately, as their reports read to your keeper, the latest first:")
            lines += battles.map(remembered)
        }
        lines.append(affairs)
        return lines.joined(separator: "\n")
    }

    /// A company as the commander would tell it: its kind, troops, where it
    /// stands, and what it is about.
    func described(_ unit: Unit) -> String {
        var told = "\(SpokenOrders.named(unit, in: state)), \(GameState.counted(state.troops(of: unit))) troops"
        // What it has been sent to do: out at the land's work, at a rally or
        // keeping a hold's gates, as the order book's briefing tells it.
        // Out gathering, its way to its site or home is told with it.
        told += SpokenOrders.errandSaid(unit, in: state)
        if state.gatheringSaid(of: unit) == nil {
            if let march = state.marchSaid(of: unit, for: player) {
                // As its keeper is told it, never "marching to on the barrows".
                told += ", " + march.prefix(1).lowercased() + march.dropFirst()
            } else if unit.fortified {
                told += ", dug in"
            }
        }
        if unit.health < 100 { told += ", at \(unit.health) of its strength in a hundred" }
        // A tier higher where it stands, by its House's Muster Hall, and for what.
        if state.raiseRefusal(of: unit, as: player) == nil {
            told += ", which may be raised to \(state.raisedName(of: unit)) where it stands for \(state.raiseCost(of: unit).listedSaid)"
        }
        // The fire it may set where it stands, and which way it would run.
        if state.isBlackwood(unit.position) && state.kindleRefusal(unit.id, as: player) == nil {
            told += ", standing in blackwood it may set alight (\(state.windSaid))"
        }
        // Lying in wait in the wood, or where it may.
        if state.isWaiting(unit.id) {
            told += ", lying in wait in the wood"
        } else if state.waitRefusal(unit.id, waiting: true, as: player) == nil {
            told += ", in the blackwood where it may lie in wait"
        }
        // What its Lanterns may seek or scout, and the dead it may bury, as
        // the order book's briefing tells them.
        told += SpokenOrders.seekSaid(unit, in: state, player: player)
        told += SpokenOrders.scoutSaid(unit, in: state, player: player)
        told += SpokenOrders.burySaid(unit, in: state, player: player)
        // Its torches doused: a tile slower, and seen by other Houses only close by.
        if state.isUnlit(unit.id) { told += ", marching dark, its torches doused" }
        // On the water, or at a shore hold whence it may cross the lake.
        told += SpokenOrders.ferrySaid(unit, in: state, player: player)
        return told
    }

    // MARK: What the commander may look at

    /// A company of the House, told by its handle.
    public func report(on handle: String) -> String {
        guard let unit = company(handle) else {
            return "Your House has no company \(handle.trimmingCharacters(in: .whitespaces))."
        }
        var told = "\(self.handle(of: unit) ?? handle): \(described(unit))."
        if let leader = unit.leader, let led = state.commander(leader) {
            told += " \(led.name) leads it."
        }
        return told
    }

    /// The most of anything a look tells, the nearest first.
    public static let mostSeen = 12

    /// What lies about the commander's company within some tiles, as their
    /// House sees it: the companies of other Houses, the holds, the holy
    /// sites and lairs, and the hamlets and barrows the House has found,
    /// each said sought or not, the nearest first, each with which way and
    /// how far as every line says it ("2 tiles north-east", "here").
    public func lookAround(within radius: Int) -> String {
        guard let unit = company else { return "You lead no company to look out from." }
        let reach = min(max(radius, 1), 8)
        let place = state.placeName(of: unit.position), within = reach == 1 ? "1 tile" : "\(reach) tiles"
        let nearest = seen(about: unit, within: reach).prefix(CommanderCounsel.mostSeen)
        guard !nearest.isEmpty else { return "Within \(within) of your company, \(place), your House sees nothing but the land." }
        return "Within \(within) of your company, \(place), your House sees: " + nearest.joined(separator: "; ") + "."
    }

    /// What the House sees within some tiles of a company, the nearest
    /// first: the companies of other Houses and the wilds, the holds, the
    /// holy sites and lairs, and the hamlets and barrows the House has
    /// found, each with which way and how far as every line says it.
    func seen(about unit: Unit, within reach: Int) -> [String] {
        state.seen(around: unit.position, by: player, within: reach)
    }

    /// The House's affairs: its holds and companies, its stores, how it
    /// stands with the Houses it is at war with or sworn to, where it and its
    /// alliance stand in the Rankings, the fire on its land, and its
    /// watchfires and what they lately made out marching dark.
    public var affairs: String {
        guard state.houses.indices.contains(player) else { return "Your House has fallen." }
        let house = state.houses[player]
        let holds = state.holds(of: player).count
        var lines = ["Your House holds \(holds == 1 ? "1 hold" : "\(holds) holds") and \(GameState.companies(state.units(of: player).count))."]
        lines.append("Its stores: " + Resource.allCases.map { "\(house.stock[$0]) \($0.title.lowercased())" }.joined(separator: ", ") + ".")
        let others = state.livingHouses.filter { $0.id != player }
        let wars = others.filter { state.stance(player, $0.id) == .war }.map(\.title)
        let pacts = others.filter { state.stance(player, $0.id) == .pact }.map(\.title)
        lines.append(wars.isEmpty ? "It is at war with no House." : "It is at war with " + wars.prefix(8).joined(separator: ", ") + ".")
        if !pacts.isEmpty { lines.append("It has pacts with " + pacts.prefix(8).joined(separator: ", ") + ".") }
        // Where it stands, as the Rankings tell its keeper: by might and by
        // foes slain, its alliance among the alliances, the mightiest House,
        // and the mightiest of those at war with it.
        let standing = state.rankingsSaid(for: player)
        if !standing.isEmpty { lines.append(standing) }
        let byMight = state.ranking(.might, for: player, most: state.houses.count)
        if let first = byMight.lines.first, first.id != player {
            lines.append("The mightiest House is \(first.name), with might \(GameState.counted(first.figure)).")
        }
        if let foe = byMight.lines.first(where: { state.stance(player, $0.id) == .war }) {
            lines.append("Of the Houses at war with it, \(foe.name) stands highest by might, \(briefOrdinal(foe.place)) of \(GameState.counted(byMight.count)).")
        }
        if state.alliance(of: player) != nil, let alliance = state.ranking(.might, alliances: true, for: player, most: 0).standing {
            lines.append(alliance)
        }
        // The envoys waiting on its keeper's answer: what each carries, how
        // the House it comes from is reputed in arms beside it, and where a
        // steward's demand may be bargained down, what half would pay.
        let waiting = state.envoys.filter { $0.to == player && state.houses.indices.contains($0.from) }
            .sorted { ($0.arrived, $0.id) < ($1.arrived, $1.id) }
        for envoy in waiting.prefix(CommanderCounsel.envoysTold) {
            let title = state.houses[envoy.from].title
            var line = "An envoy of \(title) waits on your keeper's answer: \(state.terms(of: envoy, for: player)) "
                + "\(title)'s companies are reputed \(GameState.counted(state.strength(of: envoy.from))) strong "
                + "to your House's \(GameState.counted(state.strength(of: player)))."
            if state.bargainRefusal(envoy.id, as: player) == nil {
                line += " Half its demand may be offered instead, \(state.halfTribute(from: player)). \(GameState.bargainRule)"
            } else if envoy.bargained == true {
                line += " Offered half, its steward held to the whole."
            }
            lines.append(line)
        }
        // The blackwood burning on its land, or lying there as ash.
        let fires = state.firesAndAsh
        if !fires.isEmpty {
            let owners = state.territory()
            let ours = fires.filter { state.territoryOwner(of: $0.at, in: owners) == player }
            func tiles(_ count: Int) -> String { count == 1 ? "1 tile" : "\(GameState.counted(count)) tiles" }
            let burning = ours.filter { $0.isBurning(at: state.watch) }.count
            if burning > 0 { lines.append("Fire burns in the blackwood on \(tiles(burning)) of its land; \(state.windSaid).") }
            if ours.count > burning { lines.append("Ash lies on \(tiles(ours.count - burning)) of its land, yielding nothing.") }
        }
        // Its dead lying unburied, and what comes of them at the dark of the moon.
        let unburied = state.fieldsOfDead.filter { $0.houses.contains(player) }
        if !unburied.isEmpty {
            lines.append("Its dead lie unburied: " + unburied.prefix(4).map { field in
                "\(GameState.counted(field.troops)) troops \(state.placeName(of: field.at))"
                    + (field.troops >= GameState.unquietAt ? ", who rise as Barrowkin at the dark of the moon unless buried" : "")
            }.joined(separator: "; ") + "; the dark of the moon comes in \(GameState.watches(state.watchesToTheDark(from: state.watch) == 0 ? GameState.lunarMonth : state.watchesToTheDark(from: state.watch))).")
        }
        // Its watchfires, and the latest their light made out marching dark.
        let watchfires = state.watchfiresBurning.filter { $0.by == player }
        if !watchfires.isEmpty {
            lines.append("Its watchfires burn " + watchfires.map { state.placeName(of: $0.at) }.joined(separator: ", ") + ".")
            let made = watchfires.flatMap { fire in (fire.seen ?? []).map { (fire: fire.at, sighting: $0) } }
                .sorted { ($0.sighting.watch, $0.sighting.unit) > ($1.sighting.watch, $1.sighting.unit) }
            for seen in made.prefix(CommanderCounsel.sightingsTold) where state.houses.indices.contains(seen.sighting.owner) {
                let sighting = seen.sighting
                lines.append("In watch \(sighting.watch) its watchfire \(state.placeName(of: seen.fire)) made out "
                             + "\(state.houses[sighting.owner].title)'s \(state.named(sighting.kind, tier: sighting.tier, of: sighting.owner)), "
                             + "\(GameState.counted(sighting.troops)) troops, marching dark \(state.placeName(of: sighting.at)).")
            }
        }
        return lines.joined(separator: " ")
    }

    /// What the House knows of another House, asked for by its name: where
    /// it stands by might and by foes slain, its alliance, how it stands with
    /// the commander's House, its holds and its seat, all as the keeper's
    /// view tells them. Found by its title or its name, case aside, else by
    /// a title holding the words asked; the commander's own House, a name
    /// the realm doesn't know and no name at all each said so.
    public func report(onHouse asked: String) -> String {
        let given = asked.trimmingCharacters(in: .whitespacesAndNewlines)
        let wanted = given.lowercased()
        guard !wanted.isEmpty else { return "Name the House to look at." }
        let living = state.livingHouses
        guard let house = living.first(where: { $0.title.lowercased() == wanted || $0.name.lowercased() == wanted })
                ?? living.first(where: { $0.title.lowercased().contains(wanted) }) else {
            return "Your House knows of no House called \(given)."
        }
        guard house.id != player else { return "That is your own House: look at its affairs." }
        var lines: [String] = []
        let might = state.ranking(.might, for: house.id, most: 0)
        if let place = might.place {
            lines.append("\(house.title) stands \(briefOrdinal(place)) of \(GameState.counted(might.count)) by might, "
                         + "with might \(GameState.counted(state.might(of: house.id))).")
        }
        let slain = state.ranking(.slain, for: house.id, most: 0)
        if let place = slain.place {
            lines.append("It has slain \(GameState.counted(state.slain(by: house.id))) foes this age, "
                         + "\(briefOrdinal(place)) of \(GameState.counted(slain.count)) by foes slain.")
        } else {
            lines.append("It has slain no foe this age.")
        }
        lines.append(state.alliance(of: house.id).map { "It is sworn to \($0.name)." } ?? "It is sworn to no alliance.")
        switch state.stance(player, house.id) {
        case .war: lines.append("Your House is at war with it.")
        case .peace: lines.append("Your House is at peace with it.")
        case .pact: lines.append("Your House has a pact with it.")
        }
        let holds = state.holds(of: house.id).count
        lines.append("It holds \(holds == 1 ? "1 hold" : "\(holds) holds").")
        if let seat = state.seat(of: house.id) { lines.append("Its seat is \(seat.name).") }
        return lines.joined(separator: " ")
    }

    /// What the House knows of its alliance, as its keeper's Alliance panel
    /// tells it: who leads it and who keeps its roll beside them, its
    /// Houses, where it stands, the ground it has marked, its side's rallies
    /// still gathering, its study, its works and coffers, the allies' works
    /// the House may yet help and the shares of spoils waiting for it; or,
    /// sworn to none, the alliances that have invited it and those it has
    /// asked to join.
    public var allianceReport: String {
        guard state.houses.indices.contains(player), !state.houses[player].isEliminated else { return "Your House has fallen." }
        let board = state.allianceBoard(for: player)
        let most = CommanderCounsel.mostSeen
        func title(_ house: Int) -> String { state.houses.indices.contains(house) ? state.houses[house].title : "a fallen House" }
        guard let alliance = board.alliance else {
            var lines = ["Your House is sworn to no alliance."]
            if !board.invitations.isEmpty {
                lines.append("It is invited to join " + board.invitations.prefix(most).map(\.name).joined(separator: ", ") + ".")
            }
            let asked = state.alliancesStanding.filter { $0.asking.contains(player) }
            if !asked.isEmpty {
                lines.append("It has asked to join " + asked.prefix(most).map(\.name).joined(separator: ", ") + ".")
            }
            return lines.joined(separator: " ")
        }
        var lines: [String] = []
        // Who leads it, and who keeps its roll and marks beside them.
        if board.isLeader {
            lines.append("Your House leads \(alliance.name).")
        } else {
            lines.append("Your House is sworn to \(alliance.name), led by \(title(alliance.leader))"
                         + (board.isOfficer ? "; your House is one of its officers." : "."))
        }
        let officers = alliance.officersNamed.filter { $0 != player }.map(title)
        if !officers.isEmpty {
            lines.append((board.isOfficer ? "Its other officers: " : "Its officers: ") + officers.joined(separator: ", ") + ".")
        } else if !board.isOfficer {
            lines.append("It has no officers.")
        }
        // Its Houses, the leader first, then its officers, then the rest.
        let shown = board.members.prefix(most).map { "\(title($0.house)), might \(GameState.counted($0.might))" }
        lines.append("Its Houses, \(board.members.count) of the \(board.limit) it may take: " + shown.joined(separator: "; ")
                     + (board.members.count > shown.count ? "; and \(board.members.count - shown.count) more" : "") + ".")
        // Where it stands among the alliances, as the Rankings tell it.
        for by in RankedBy.allCases {
            if let standing = state.ranking(by, alliances: true, for: player, most: 0).standing { lines.append(standing) }
        }
        // What it bids its Houses on the land, and its side's rallies.
        let marks = state.marksSaid(of: alliance.id)
        lines.append(marks.isEmpty ? "It has marked no ground." : "Ground it has marked: " + marks.joined(separator: " "))
        let rallies = SpokenOrders.ralliesGathering(in: state, player: player)
        lines.append(rallies.isEmpty ? "No rally of your side is gathering."
                     : "Rallies of your side gathering: " + rallies.prefix(most).map { SpokenOrders.rallySaid($0, in: state) }.joined(separator: "; ") + ".")
        // What it studies together, and what it has learned.
        let lore = alliance.lore ?? AllianceLore()
        if let next = lore.next {
            let still = lore.given.shortfall(for: next.study.cost(grade: next.grade))
            lines.append("It pursues \(next.study.title) \(BuildingKind.numeral(next.grade)) (\(next.study.effect(grade: next.grade)))"
                         + (still.isZero ? ", all it needs given." : "; still to give: \(still)."))
        } else {
            lines.append("It pursues no study.")
        }
        let learned = AllianceStudy.allCases.filter { lore.grade(of: $0) > 0 }.map { "\($0.title) \(BuildingKind.numeral(lore.grade(of: $0)))" }
        if !learned.isEmpty { lines.append("It has learned together " + learned.joined(separator: ", ") + ".") }
        // Its works on its land, and its coffers.
        lines.append("It keeps \(state.standards(of: alliance.id).count) of the \(state.standardsAllowed(for: alliance)) standards it may.")
        if let hall = state.hall(of: alliance.id) {
            lines.append(hall.isWhole ? "Its hall stands \(state.placeName(of: hall.position)), its ward \(hall.ward) of \(AllianceHall.maximumWard)."
                         : "Its hall is rising \(state.placeName(of: hall.position)), \(hall.built) of \(AllianceHall.raising) watches done.")
        } else {
            lines.append("It has no hall.")
        }
        if let storehouse = state.storehouse(of: alliance.id) {
            lines.append(storehouse.isWhole
                         ? "Its storehouse stands \(state.placeName(of: storehouse.position)), its ward \(storehouse.ward) of \(Storehouse.maximumWard)."
                         : "Its storehouse is rising \(state.placeName(of: storehouse.position)), \(storehouse.built) of \(Storehouse.raising) watches done.")
        }
        let yards = state.yards(of: alliance.id)
        if !yards.isEmpty {
            lines.append("Its yards: " + yards.map { "the \($0.title), \($0.remaining) \($0.store.title.lowercased()) left" }.joined(separator: "; ") + ".")
        }
        let yield = state.coffersYield(of: alliance.id)
        lines.append((alliance.stores.isZero ? "Its coffers are empty" : "Its coffers hold \(alliance.stores)")
                     + (yield.isZero ? "." : "; its land yields them \(yield) a watch."))
        // What the House may do for it now: its allies' works to help,
        // Houses to answer, and its shares of the spoils to take.
        let helpable = board.members.filter { $0.helpable > 0 }
        if !helpable.isEmpty {
            lines.append("Your House may yet help its allies' works, musters and studies: "
                         + helpable.prefix(most).map { "\(title($0.house)), \($0.helpable)" }.joined(separator: "; ") + ".")
        }
        if !board.asking.isEmpty {
            lines.append("Houses asking to join it: " + board.asking.prefix(most).map(title).joined(separator: ", ") + ".")
        }
        // Said as the Mac's Alliance panel and the phone say what they hold.
        let shares = state.shares(of: player)
        if !shares.isEmpty {
            lines.append("\(shares.count == 1 ? "A share" : "\(shares.count) shares") of the alliance's spoils "
                         + "\(shares.count == 1 ? "waits" : "wait") for your House to take, holding \(state.sharesHeldSaid(by: player)).")
        }
        // The House's merit with it, as its stall reckons it.
        if let merit = state.meritSaid(of: player) {
            let affordable = GameState.stall.filter { state.stallRefusal($0, as: player) == nil }.map(\.title)
            lines.append(merit + (affordable.isEmpty ? " It reaches nothing at the alliance's stall yet."
                                  : " At the alliance's stall it would take any of: " + affordable.joined(separator: ", ") + "."))
        }
        return lines.joined(separator: " ")
    }

    // MARK: What the commander may put to the keeper

    /// How many of what its House's watchfires made out a commander is told
    /// of, the latest first.
    public static let sightingsTold = 3

    /// What a commander may propose a company does.
    public static let actions = ["march", "strike", "fortify", "halt", "drill", "raise", "kindle", "douse", "light", "wait", "bury", "gather",
                                 "recall", "scout", "seek", "reinforce", "rally", "ferry"]

    /// Why a commander can't put forward anything else.
    public static let onlyThese = "A commander may propose only that a company march, strike, fortify, halt, drill, "
        + "raise (a tier, by a Muster Hall of your House where it stands), kindle (set the wood alight), "
        + "douse (its torches, to march dark), light (its torches again), wait (lie in wait in the blackwood, marching dark), "
        + "bury (the dead lying unburied where it stands), gather (a store, at the nearest site of it the company may work), "
        + "recall (from the land's work, home with its load), scout (another House's hold, with Lanterns near it), "
        + "seek (a hamlet or barrow its Lanterns stand by, found but not yet sought), "
        + "reinforce (keep the gates of a hold of your House or an ally's), rally (join a rally of your side still gathering) "
        + "or ferry (across the lake by barge, from a shore hold of your House's to another)."

    /// An order put to the keeper, read and weighed as the order book weighs
    /// a line: given if the realm would take it, or told why not. For
    /// gather, the place is the store to gather, or its sites' name, and
    /// empty for the nearest site of any store; for scout and reinforce,
    /// the hold; for rally, the rally's target, or empty for the one
    /// setting out soonest; for ferry, the hold to land at.
    public func propose(_ action: String, company handle: String, place: String) -> CounselProposal {
        let verb = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let line: String
        switch verb {
        case "march": line = "MARCH \(handle) TO \(place)"
        case "strike": line = "STRIKE \(place) WITH \(handle)"
        case "gather": line = place.isEmpty ? "GATHER \(handle)" : "GATHER \(place) WITH \(handle)"
        case "scout", "reinforce": line = "\(verb.uppercased()) \(place) WITH \(handle)"
        case "rally": line = place.isEmpty ? "RALLY \(handle)" : "RALLY AGAINST \(place) WITH \(handle)"
        case "ferry": line = "FERRY \(handle) TO \(place)"
        case "fortify", "halt", "drill", "raise", "kindle", "douse", "light", "wait", "bury", "recall", "seek": line = "\(verb.uppercased()) \(handle)"
        default:
            return CounselProposal(line: "\(action) \(handle) \(place)", told: "\(action) \(handle)", command: nil,
                                   why: CommanderCounsel.onlyThese)
        }
        if (verb == "march" || verb == "strike") && place.isEmpty {
            return CounselProposal(line: line, told: line, command: nil, why: "A march or a strike wants a place to go to.")
        }
        if (verb == "scout" || verb == "reinforce") && place.isEmpty {
            return CounselProposal(line: line, told: line, command: nil, why: "Scouting or keeping a hold's gates wants the hold's name.")
        }
        if verb == "ferry" && place.isEmpty {
            return CounselProposal(line: line, told: line, command: nil, why: "A crossing of the lake wants the hold to land at.")
        }
        guard let read = SpokenOrders.read(line: line, in: state, player: player) else {
            return CounselProposal(line: line, told: line, command: nil, why: "The order book has no such line.")
        }
        return CounselProposal(line: line, told: read.told, command: read.command, why: read.why)
    }

    /// What a commander may put forward for the House's alliance.
    public static let allianceActions = ["help", "shares", "give", "take"]

    /// Why a commander can't put forward anything else for the alliance.
    public static let onlyTheseForAlliance = "A commander may propose for the alliance only to help an ally's works (help, naming the House), "
        + "to take up the shares of its spoils (shares), to give stores toward its study (give, such as 50 grain), "
        + "or to take a thing from its stall for your House's merit (take, naming the thing)."

    /// A deed for the House's alliance put to the keeper, read and weighed
    /// as the order book weighs a line: an ally's works helped, the shares
    /// of the spoils taken up, stores given toward its study, or a thing
    /// taken from its stall.
    public func proposeForAlliance(_ action: String, what: String) -> CounselProposal {
        let verb = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let what = what.trimmingCharacters(in: .whitespacesAndNewlines)
        let line: String
        switch verb {
        case "help": line = "HELP \(what)"
        case "shares", "take the shares": line = "TAKE THE SHARES"
        case "give": line = "GIVE \(what) TO THE STUDY"
        case "take", "stall": line = "TAKE \(what) FROM THE STALL"
        default:
            return CounselProposal(line: "\(action) \(what)", told: "\(action) \(what)", command: nil, why: CommanderCounsel.onlyTheseForAlliance)
        }
        guard !what.isEmpty || line == "TAKE THE SHARES" else {
            return CounselProposal(line: line, told: line, command: nil, why: "That wants a name: the House to help, the stores to give or the thing to take.")
        }
        guard let read = SpokenOrders.read(line: line, in: state, player: player) else {
            return CounselProposal(line: line, told: line, command: nil, why: "The order book has no such line.")
        }
        return CounselProposal(line: line, told: read.told, command: read.command, why: read.why)
    }

    /// What a commander may put forward of an envoy waiting on the House.
    public static let envoyActions = ["accept", "refuse", "bargain"]

    /// The most envoys waiting the House's affairs tell, the first come
    /// first, so the briefing leaves the model room to recall.
    public static let envoysTold = 3

    /// Why a commander can't put forward any other answer to an envoy.
    public static let onlyTheseForEnvoys = "A commander may propose only that your keeper accept an envoy's offer, refuse it, "
        + "or offer half a steward's demand of tribute (bargain), naming the House the envoy comes from."

    /// An answer to an envoy put to the keeper, read and weighed as the
    /// order book weighs a line: its offer accepted or refused, or half a
    /// steward's demand of tribute offered.
    public func proposeAnswer(_ action: String, house: String) -> CounselProposal {
        let verb = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = house.trimmingCharacters(in: .whitespacesAndNewlines)
        let line: String
        switch verb {
        case "accept", "pay": line = "ACCEPT THE ENVOY OF \(name)"
        case "refuse": line = "REFUSE THE ENVOY OF \(name)"
        case "bargain", "half", "offer half": line = "OFFER HALF THE TRIBUTE TO \(name)"
        default:
            return CounselProposal(line: "\(action) \(name)", told: "\(action) \(name)", command: nil, why: CommanderCounsel.onlyTheseForEnvoys)
        }
        guard !name.isEmpty else {
            return CounselProposal(line: line, told: line, command: nil, why: "An answer to an envoy wants the House it comes from.")
        }
        guard let read = SpokenOrders.read(line: line, in: state, player: player) else {
            return CounselProposal(line: line, told: line, command: nil, why: "The order book has no such line.")
        }
        return CounselProposal(line: line, told: read.told, command: read.command, why: read.why)
    }

    /// What a commander may put forward of the House's dealings with
    /// another House.
    public static let dealingActions = ["peace", "pact", "tribute", "war"]

    /// Why a commander can't put forward any other dealing.
    public static let onlyTheseForDealings = "A commander may propose only that your keeper send an envoy to another House "
        + "offering peace (peace) or a pact (pact), or demanding tribute (tribute), or declare war on it (war), naming the House."

    /// A dealing with another House put to the keeper, read and weighed as
    /// the order book weighs a line: an envoy sent offering peace or a pact
    /// or demanding tribute, or war declared. War is asked of the keeper
    /// again before it is given, as the Houses panel asks it.
    public func proposeDealing(_ action: String, house: String) -> CounselProposal {
        let verb = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let name = house.trimmingCharacters(in: .whitespacesAndNewlines)
        let line: String
        switch verb {
        case "peace", "offer peace": line = "OFFER PEACE TO \(name)"
        case "pact", "a pact", "offer a pact": line = "OFFER A PACT TO \(name)"
        case "tribute", "demand tribute": line = "DEMAND TRIBUTE FROM \(name)"
        case "war", "declare war": line = "DECLARE WAR ON \(name)"
        default:
            return CounselProposal(line: "\(action) \(name)", told: "\(action) \(name)", command: nil, why: CommanderCounsel.onlyTheseForDealings)
        }
        guard !name.isEmpty else {
            return CounselProposal(line: line, told: line, command: nil, why: "A dealing with another House wants the House's name.")
        }
        guard let read = SpokenOrders.read(line: line, in: state, player: player) else {
            return CounselProposal(line: line, told: line, command: nil, why: "The order book has no such line.")
        }
        var asked: String?
        if case let .declareWar(on: other)? = read.command, read.why == nil, state.houses.indices.contains(other) {
            asked = Self.warAsked(on: state.houses[other].title, pact: state.stance(player, other) == .pact)
        }
        return CounselProposal(line: line, told: read.told, command: read.command, why: read.why, askedFirst: asked)
    }

    /// What the keeper is asked before war is given, as the Houses panel
    /// asks it: a pact betrayed, or war.
    public static func warAsked(on title: String, pact: Bool) -> String {
        pact ? "Betray \(title)?" : "War on \(title)?"
    }
}

/// An order a commander put to the keeper, as the realm would take it.
public struct CounselProposal: Equatable, Sendable {
    /// The order book's line.
    public let line: String
    /// What it orders, in the realm's words.
    public let told: String
    /// The order it makes, if it makes one.
    public let command: Command?
    /// Why it can't be given, if it can't.
    public let why: String?
    /// What the keeper is asked again before it is given, for an order not
    /// to be taken back: war on a House.
    public let askedFirst: String?

    public init(line: String, told: String, command: Command?, why: String?, askedFirst: String? = nil) {
        self.line = line
        self.told = told
        self.command = command
        self.why = why
        self.askedFirst = askedFirst
    }

    /// Whether the keeper may give it as it stands.
    public var isGiven: Bool { command != nil && why == nil }

    /// What the commander is told of it.
    public var answer: String {
        isGiven ? "Put forward to your keeper: \(told) The keeper decides." : "That cannot be ordered: \(why ?? "the realm would not take it.")"
    }
}

/// What a commander remembers of earlier counsel with their keeper: the
/// last few things asked and answered, and when, kept on the keeper's own
/// Mac for the age.
public struct CounselMemory: Codable, Equatable, Sendable {
    public struct Exchange: Codable, Equatable, Sendable {
        public let watch: Int
        public let asked: String
        public let answered: String

        public init(watch: Int, asked: String, answered: String) {
            self.watch = watch
            self.asked = asked
            self.answered = answered
        }
    }

    public let commander: Int
    public let age: Int
    public private(set) var exchanges: [Exchange]

    /// The most exchanges remembered: the oldest are let go.
    public static let kept = 12

    public init(commander: Int, age: Int, exchanges: [Exchange] = []) {
        self.commander = commander
        self.age = age
        self.exchanges = Array(exchanges.suffix(CounselMemory.kept))
    }

    public mutating func remember(_ asked: String, _ answered: String, at watch: Int) {
        exchanges.append(Exchange(watch: watch, asked: asked, answered: answered))
        if exchanges.count > CounselMemory.kept { exchanges.removeFirst(exchanges.count - CounselMemory.kept) }
    }

    /// What the commander recalls of earlier counsel, the latest kept
    /// whole, within some characters; nil when there is none.
    public func recalled(within characters: Int) -> String? {
        var told: [String] = []
        var used = 0
        for exchange in exchanges.reversed() {
            let line = "At watch \(exchange.watch) your keeper said: \(exchange.asked) You answered: \(exchange.answered)"
            guard used + line.count <= characters else { break }
            told.insert(line, at: 0)
            used += line.count + 1
        }
        return told.isEmpty ? nil : told.joined(separator: "\n")
    }
}

/// Why a commander gave no counsel, in words the keeper is owed: never a
/// made-up answer in its place.
public enum CounselTrouble: Equatable, Sendable, Error {
    /// The model can't be asked on this Mac or this phone.
    case unavailable(Unavailability)
    /// The model would not speak of it.
    case refused
    /// The keeper wrote in a language the model doesn't speak here.
    case language
    /// The model is answering another; ask again shortly.
    case busy
    /// The counsel has grown longer than the model can hold, even condensed.
    case tooLong
    /// The model's answer came out in no shape to use.
    case garbled
    /// The model's files are not yet on this device.
    case assetsMissing
    /// No answer came in time.
    case slow
    /// No answer came, and the system said nothing of why: only its stock
    /// words for an error, which name a type and a code.
    case silent
    /// Anything else, as the system told it.
    case failed(String)

    /// A failure as the system described it: its own words where it said
    /// something a keeper can read, or silent where it gave only its stock
    /// words, "The operation couldn't be completed (… error -1.)", which
    /// are never shown.
    public static func told(_ described: String) -> CounselTrouble {
        let stock = (described.hasPrefix("The operation couldn’t be completed") || described.hasPrefix("The operation couldn't be completed"))
        return stock || described.isEmpty ? .silent : .failed(described)
    }

    public enum Unavailability: Equatable, Sendable {
        case deviceNotEligible, appleIntelligenceOff, modelNotReady, systemTooOld

        /// How the voices stand where the model can't be asked, as the Mac's
        /// settings tell it: who falls silent, and what reads in their place.
        public var voicesSaid: String {
            let silent = "the envoys and the chronicle go unvoiced, your commanders give no counsel, and the order book reads your words as they are written"
            switch self {
            case .deviceNotEligible: return "This Mac can't run Apple's on-device model, so \(silent)."
            case .appleIntelligenceOff: return "Apple Intelligence is turned off in System Settings, so \(silent) until it is turned on."
            case .modelNotReady: return "Apple's on-device model is still downloading or preparing; until it is ready, \(silent)."
            case .systemTooOld: return "Apple's on-device model needs a newer system than this one, so \(silent)."
            }
        }
    }

    /// How the voices stand where the model can be asked.
    public static let voicesReady = "Apple's on-device model on this Mac gives the envoys, the chronicle and your commanders their words, and reads yours into orders; nothing they say leaves the Mac."

    /// The words the keeper is shown.
    public var said: String {
        switch self {
        case .unavailable(.deviceNotEligible):
            return "This device can't run Apple's on-device model, so your commanders can't take counsel here. Everything else plays as ever."
        case .unavailable(.appleIntelligenceOff):
            #if os(iOS)
            return "Apple Intelligence is turned off in Settings, so your commanders can't take counsel until it is turned on."
            #else
            return "Apple Intelligence is turned off in System Settings, so your commanders can't take counsel until it is turned on."
            #endif
        case .unavailable(.modelNotReady):
            return "Apple's on-device model is still downloading or preparing. Your commanders can take counsel once it is ready."
        case .unavailable(.systemTooOld):
            return "Counsel needs Apple's on-device model, which needs a newer system than this one."
        case .refused: return "The commander will not speak of that. Ask another way."
        case .language: return "The commander can't make out that language here. Ask in one Apple's model speaks on this device."
        case .busy: return "The commander is answering another. Ask again in a moment."
        case .tooLong: return "The counsel has run too long to hold. Start it afresh."
        case .garbled: return "The commander's answer came out garbled. Ask again."
        case .assetsMissing: return "Apple's on-device model isn't ready on this device yet. Try again once it has finished downloading."
        case .slow: return "No answer came in time. Ask again, or more simply."
        case .silent: return "The commander gave no counsel, and Apple's on-device model said nothing of why. Ask again in a while."
        case .failed(let reason): return "The commander gave no counsel: \(reason)"
        }
    }
}

extension CommanderCounsel {
    /// The foot of a counsel sheet, on the Mac and the phone alike: who
    /// speaks for the commander there, and how long its last answer took;
    /// where Apple's on-device model can't be asked there, not that it
    /// speaks, but that nothing answers in its place.
    public static func foot(on device: String, canAsk: Bool, firstWords: Double? = nil, whole: Double? = nil) -> String {
        guard canAsk else { return "Only Apple's on-device model gives counsel, and nothing answers in its place" }
        let spoken = "Spoken by Apple's on-device model on this \(device)"
        guard let firstWords, let whole else { return spoken }
        return spoken + String(format: " · first words %.1f s, all of it %.1f s", firstWords, whole)
    }
}

/// How much of the model's context counsel may spend on what it brings, in
/// characters, the rest left for the counsel itself.
public enum CounselBudget {
    /// Characters to a token, near enough, for English prose.
    public static let charactersPerToken = 3.6
    /// The share of the context the instructions, the briefing and what is
    /// recalled may take.
    public static let broughtShare = 0.45
    /// The most tokens an answer may run to.
    public static let answerTokens = 220
    /// The share of the context the tools' names and descriptions may take
    /// beside what is brought: what the model reads of its looks and
    /// proposals before a word is asked, the rest left for the asking, the
    /// looks it takes and its answer.
    public static let toolsShare = 0.2

    /// The characters the tools' names and descriptions may run to, in a
    /// context of so many tokens.
    public static func toolWords(context tokens: Int) -> Int {
        Int(Double(tokens) * toolsShare * charactersPerToken)
    }

    /// The characters left for what the commander recalls, given the
    /// context's size in tokens and what else is brought.
    public static func recall(context tokens: Int, instructions: String, briefing: String) -> Int {
        let brought = Int(Double(tokens) * broughtShare * charactersPerToken)
        return max(brought - instructions.count - briefing.count, 0)
    }
}

extension GameState {
    /// What a House sees within some tiles of a place, the nearest first:
    /// the companies of other Houses and the wilds, the holds (but the one
    /// left out), the holy sites and lairs, and the hamlets and barrows the
    /// House has found, each with which way and how far as every line says
    /// it ("2 tiles north-east", "here"); as a commander's look about their
    /// company tells it, and a reeve's about their hold.
    func seen(around here: Hex, by player: Int, within reach: Int, besides left: Int? = nil) -> [String] {
        let ours = houses.indices.contains(player) ? houses[player].title : "your House"
        func way(_ hex: Hex) -> String { GameState.waySaid(to: hex, from: here) }
        var seen: [(distance: Int, told: String)] = []
        for other in units where other.owner != player {
            let distance = other.position.distance(to: here)
            guard distance <= reach else { continue }
            let owner = houses.indices.contains(other.owner) ? houses[other.owner].title : "the wilds"
            let standing = houses.indices.contains(other.owner) ? ", \(stance(player, other.owner).standing)" : ""
            seen.append((distance, "\(owner)'s \(SpokenOrders.named(other, in: self)), \(GameState.counted(troops(of: other))) troops, "
                + "\(way(other.position))\(standing)"))
        }
        for hold in holds where hold.id != left && hold.position.distance(to: here) <= reach {
            let owner = houses.indices.contains(hold.owner) ? houses[hold.owner].title : "no House"
            let distance = hold.position.distance(to: here)
            seen.append((distance, "\(hold.name), a hold of \(owner == ours ? "your House" : owner), \(way(hold.position))"))
        }
        for site in holySites where site.position.distance(to: here) <= reach {
            seen.append((site.position.distance(to: here), "\(site.title), a holy site, \(way(site.position))"))
        }
        for lair in lairsStanding where lair.position.distance(to: here) <= reach {
            seen.append((lair.position.distance(to: here), "\(lair.title), a lair of the wilds, \(way(lair.position))"))
        }
        // The wilds are no House's companies, so they were never among them:
        // those standing on ground the House has seen, as strong as they are.
        for wild in wildsStanding where wild.position.distance(to: here) <= reach && isExplored(wild.position, by: player) {
            let bearing = wild.keepsake.map { ", bearing a keepsake of \($0)" } ?? ""
            seen.append((wild.position.distance(to: here), "a band of \(wild.kind.title) from the wilds, \(wild.strengthSaid)\(bearing), "
                + way(wild.position)))
        }
        for find in findsKnown(by: player) where find.position.distance(to: here) <= reach {
            let what = find.kind == .hamlet ? find.named : "\(find.named), an old barrow"
            let sought = hasSought(find.id, by: player) ? "sought by your Lanterns" : "which your Lanterns have yet to seek"
            seen.append((find.position.distance(to: here), "\(what), \(sought), \(way(find.position))"))
        }
        // What the land offers to work comes after all that stands on it,
        // the nearest first, so a look among many sites still tells its foes.
        let sites = sitesInLand.filter { $0.position.distance(to: here) <= reach && isExplored($0.position, by: player) }.map { site in
            (distance: site.position.distance(to: here),
             told: "\(site.title), \(GameState.counted(site.remaining)) \(site.store.title.lowercased()) to work, \(way(site.position))")
        }
        return (seen.sorted { ($0.distance, $0.told) < ($1.distance, $1.told) } + sites.sorted { ($0.distance, $0.told) < ($1.distance, $1.told) })
            .map(\.told)
    }
}
