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
        a number, a name, a place or an event. To learn more, look: at a company, about your own company, or \
        at your House's affairs. You may put an order to your keeper only by proposing it, and you never give \
        one yourself: say that you have put it forward, and that the keeper decides. Name companies by their \
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
        if let march = state.marchSaid(of: unit, for: player) {
            // As its keeper is told it, never "marching to on the barrows".
            told += ", " + march.prefix(1).lowercased() + march.dropFirst()
        } else if unit.fortified {
            told += ", dug in"
        }
        if unit.health < 100 { told += ", at \(unit.health) of its strength in a hundred" }
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
        // Its torches doused: a tile slower, and seen by other Houses only close by.
        if state.isUnlit(unit.id) { told += ", marching dark, its torches doused" }
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
    /// stands with the Houses it is at war with or sworn to, the fire on its
    /// land, and its watchfires and what they lately made out marching dark.
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

    // MARK: What the commander may put to the keeper

    /// How many of what its House's watchfires made out a commander is told
    /// of, the latest first.
    public static let sightingsTold = 3

    /// What a commander may propose a company does.
    public static let actions = ["march", "strike", "fortify", "halt", "drill", "kindle", "douse", "light", "wait", "bury"]

    /// Why a commander can't put forward anything else.
    public static let onlyThese = "A commander may propose only that a company march, strike, fortify, halt, drill, kindle (set the wood "
        + "alight), douse (its torches, to march dark), light (its torches again), wait (lie in wait in the blackwood, marching dark) "
        + "or bury (the dead lying unburied where it stands)."

    /// An order put to the keeper, read and weighed as the order book weighs
    /// a line: given if the realm would take it, or told why not.
    public func propose(_ action: String, company handle: String, place: String) -> CounselProposal {
        let verb = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let handle = handle.trimmingCharacters(in: .whitespacesAndNewlines)
        let place = place.trimmingCharacters(in: .whitespacesAndNewlines)
        let line: String
        switch verb {
        case "march": line = "MARCH \(handle) TO \(place)"
        case "strike": line = "STRIKE \(place) WITH \(handle)"
        case "fortify", "halt", "drill", "kindle", "douse", "light", "wait", "bury": line = "\(verb.uppercased()) \(handle)"
        default:
            return CounselProposal(line: "\(action) \(handle) \(place)", told: "\(action) \(handle)", command: nil,
                                   why: CommanderCounsel.onlyThese)
        }
        if (verb == "march" || verb == "strike") && place.isEmpty {
            return CounselProposal(line: line, told: line, command: nil, why: "A march or a strike wants a place to go to.")
        }
        guard let read = SpokenOrders.read(line: line, in: state, player: player) else {
            return CounselProposal(line: line, told: line, command: nil, why: "The order book has no such line.")
        }
        return CounselProposal(line: line, told: read.told, command: read.command, why: read.why)
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

    public init(line: String, told: String, command: Command?, why: String?) {
        self.line = line
        self.told = told
        self.command = command
        self.why = why
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
