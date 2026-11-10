import Foundation

/// Orders in a keeper's own words. Their Mac's model reads what they write
/// into the plain lines of the realm's order book, given a briefing of what
/// their House has and knows; each line is read here against the keeper's
/// own view into the order the realm would take, or why it wouldn't. The
/// book has lines for the House's companies and holds, and for its dealings
/// with the other Houses: envoys of peace, of a pact or demanding tribute,
/// gifts, offers of trade and war, and oaths the realm holds the House to;
/// and standing orders for the caretaker that keeps the House while its
/// keeper is away.
/// Nothing is given until the keeper has seen the orders and gives them:
/// the model only reads, and the realm judges every order as it always
/// does. Without the model, the order book's lines may be written as they
/// are.
public enum SpokenOrders {
    /// One line of the order book, read.
    public struct Line: Equatable, Sendable {
        /// The line as it was written.
        public let text: String
        /// The order it makes, if the realm would take it.
        public let command: Command?
        /// What it orders, in the realm's words.
        public let told: String
        /// Why it can't be given, if it can't.
        public let why: String?

        public init(text: String, command: Command?, told: String, why: String?) {
            self.text = text
            self.command = command
            self.told = told
            self.why = why
        }
    }

    /// The forms of the order book's lines.
    public static let forms = ["MARCH <company> TO <place>", "STRIKE <place> WITH <company>", "FORTIFY <company>", "HALT <company>",
                               "DRILL <company>", "RAISE <company>", "KINDLE <company>", "DOUSE <company>", "LIGHT <company>", "WAIT <company>",
                               "SEEK <company>", "BURY <company>", "GATHER <store> WITH <company>", "RECALL <company>",
                               "SCOUT <hold> WITH <company>", "REINFORCE <hold> WITH <company>", "RALLY AGAINST <target> WITH <company>",
                               "BUILD <work> AT <hold>", "TRAIN <kind> AT <hold>",
                               "OFFER PEACE TO <house>", "OFFER A PACT TO <house>", "DEMAND TRIBUTE FROM <house>", "DECLARE WAR ON <house>",
                               "ACCEPT THE ENVOY OF <house>", "REFUSE THE ENVOY OF <house>", "OFFER HALF THE TRIBUTE TO <house>",
                               "GIVE <amount> <store> TO <house>", "TRADE <amount> <store> FOR <amount> <store> WITH <house>",
                               "SWEAR PEACE WITH <house> FOR <watches> WATCHES",
                               "SWEAR TO SEND <amount> <store> TO <house> EACH WATCH FOR <watches> WATCHES",
                               "RENOUNCE THE OATH TO <house>",
                               "HELP <house>", "TAKE THE SHARES", "MARK <mark> AT <place> SAYING <words>",
                               "WHILE AWAY MUSTER <kind>", "WHILE AWAY RAISE <work> FIRST", "WHILE AWAY KEEP HOME",
                               "WHILE AWAY MAKE PEACE", "WHILE AWAY MAKE NO PEACE", "WHILE AWAY PAY TRIBUTE", "WHILE AWAY PAY NO TRIBUTE",
                               "WHILE AWAY AS YOU SEE FIT"]
    /// The most lines read at once.
    public static let most = 6
    /// The most companies and places the briefing names, the nearest the
    /// seat first, so it stays within what the model reads at once.
    public static let briefedCompanies = 40
    public static let briefedPlaces = 80
    /// The most sites to gather at the briefing names, the nearest the
    /// seat first.
    public static let briefedSites = 8

    /// The House's companies, in the order the briefing numbers them.
    public static func companies(in state: GameState, player: Int) -> [Unit] {
        state.units(of: player).sorted { $0.id < $1.id }
    }

    /// A company lying in wait, or one that may (WAIT), as the briefing
    /// tells it: marching dark in the blackwood and not on the march.
    static func waitSaid(_ unit: Unit, in state: GameState, player: Int) -> String {
        if state.isWaiting(unit.id) { return ", lying in wait in the wood" }
        return state.waitRefusal(unit.id, waiting: true, as: player) == nil ? ", in the blackwood where it may lie in wait (WAIT)" : ""
    }

    /// A hamlet or barrow a company stands on or beside that its House has
    /// yet to seek (SEEK), as the briefing tells it.
    static func seekSaid(_ unit: Unit, in state: GameState, player: Int) -> String {
        guard unit.kind == .lantern, let find = state.findToSeek(by: unit, as: player) else { return "" }
        return ", by \(find.named), which it may seek (SEEK)"
    }

    /// Dead lying unburied where a company of war stands that it may bury
    /// (BURY), as the briefing tells it.
    static func burySaid(_ unit: Unit, in state: GameState, player: Int) -> String {
        guard let field = state.fieldOfDead(at: unit.position), state.burialRefusal(by: unit.id, as: player) == nil else { return "" }
        return ", where \(GameState.counted(field.troops)) troops' dead lie unburied, which it may bury (BURY)"
    }

    /// A company its House may raise a tier where it stands (RAISE), as
    /// the briefing tells it, with what it would cost.
    static func raisableSaid(_ unit: Unit, in state: GameState, player: Int) -> String {
        guard state.raiseRefusal(of: unit, as: player) == nil else { return "" }
        return ", which may be raised to \(state.raisedName(of: unit)) where it stands for \(state.raiseCost(of: unit).listedSaid) (RAISE)"
    }

    /// What a company has been sent to do beyond a march, as the briefing
    /// and counsel tell it: out at the land's work (at its site, bound for
    /// it, or home with its load, as its keeper is told it), sent to a
    /// rally, or keeping the gates of a hold.
    static func errandSaid(_ unit: Unit, in state: GameState) -> String {
        if let work = state.gatheringSaid(of: unit) { return ", out gathering: \(work)" }
        switch unit.errand {
        case .rally(let id)?:
            let said = state.rallySaid(id)
            return ", " + said.prefix(1).lowercased() + said.dropFirst()
        case .reinforce(let hold)?:
            return ", keeping the gates of \(state.hold(hold)?.name ?? "a hold")"
        case .gather?, .homeward?, nil:
            return ""
        }
    }

    /// Another House's hold within reach of Lanterns that they may scout
    /// now (SCOUT), the nearest, as the briefing tells it.
    static func scoutSaid(_ unit: Unit, in state: GameState, player: Int) -> String {
        guard unit.kind == .lantern else { return "" }
        let near = state.holds.filter { $0.owner != player && $0.position.distance(to: unit.position) <= GameState.scoutReach }
            .sorted { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
        guard let hold = near.first(where: { state.refusal(of: .scout(unit: unit.id, hold: $0.id), as: player) == nil }) else { return "" }
        return ", near \(hold.name), which it may scout (SCOUT)"
    }

    /// The rallies of the House's side still gathering, the soonest to set
    /// out first, as the briefing tells them: "against Tirford, mustering at
    /// Wenholme, setting out in 2 watches".
    static func ralliesGathering(in state: GameState, player: Int) -> [Rally] {
        state.ralliesStanding.filter { state.isOfRally(player, $0) && !$0.marching }.sorted { ($0.setsOut, $0.id) < ($1.setsOut, $1.id) }
    }

    static func rallySaid(_ rally: Rally, in state: GameState) -> String {
        let watches = rally.setsOut - state.watch
        return "against \(state.targetName(rally.target) ?? "a hold"), mustering at \(state.hold(rally.muster)?.name ?? "a hold"), "
            + (watches <= 1 ? "setting out as the watch turns" : "setting out in \(watches) watches")
    }

    /// The sites of the land the House knows and may send its companies
    /// to gather at (GATHER), the nearest its seat first, each with its
    /// store and which way and how far from the seat: "the Deadfall II
    /// (timber), 3 tiles north-east"; an alliance's yards only for its own.
    static func sitesKnown(in state: GameState, player: Int) -> [String] {
        let home = state.seat(of: player)?.position ?? .origin
        let ours = state.alliance(of: player)?.id
        return state.sitesInLand.filter { state.isExplored($0.position, by: player) && ($0.alliance == nil || $0.alliance == ours) }
            .sorted { ($0.position.distance(to: home), $0.id) < ($1.position.distance(to: home), $1.id) }
            .prefix(briefedSites)
            .map { "\(state.siteSaid($0)) (\($0.store.title.lowercased())), \(GameState.waySaid(to: $0.position, from: home))" }
    }

    /// A company as the briefing and the orders name it.
    public static func named(_ unit: Unit, in state: GameState) -> String {
        "\(state.named(unit)) \(state.placeName(of: unit.position))"
    }

    /// Each of a House's companies by name, told apart where two would be
    /// named alike (the same kind and tier about the same place): numbered
    /// in the order they were raised, "Spears I at Tirford (1)" and "Spears
    /// I at Tirford (2)"; a name no other shares, as it is.
    public static func distinctNames(in state: GameState, player: Int) -> [Int: String] {
        let named = state.units(of: player).sorted { $0.id < $1.id }.map { (id: $0.id, name: Self.named($0, in: state)) }
        var count: [String: Int] = [:]
        for company in named { count[company.name, default: 0] += 1 }
        var seen: [String: Int] = [:]
        var names: [Int: String] = [:]
        for company in named {
            guard count[company.name, default: 0] > 1 else {
                names[company.id] = company.name
                continue
            }
            seen[company.name, default: 0] += 1
            names[company.id] = "\(company.name) (\(seen[company.name, default: 1]))"
        }
        return names
    }

    /// The places a keeper may name: the holds their House knows, the holy
    /// sites, the lairs and the Crown's gates, and the shores' regions.
    public static func places(in state: GameState) -> [(name: String, at: Hex)] {
        var places: [(name: String, at: Hex)] = state.holds.map { ($0.name, $0.position) }
        places += state.holySites.map { ($0.title, $0.position) }
        places += state.lairsStanding.map { ($0.gate == nil ? $0.title : "\($0.title) of the Crown", $0.position) }
        places += (state.atlas?.regions ?? []).map { ($0.name, $0.heart) }
        return places
    }

    /// What the model is told: the order book's forms, and what the House
    /// has and knows, its companies numbered C1, C2 and on.
    public static func briefing(for state: GameState, player: Int) -> String {
        var lines = ["The order book's lines, one order to a line:"] + forms
        lines.append("Your companies:")
        for (index, unit) in companies(in: state, player: player).prefix(briefedCompanies).enumerated() {
            // A company that may set the blackwood where it stands alight
            // is told so, the wind with it, so the model knows the fire is
            // there to order and which way it would run.
            let alight = state.isBlackwood(unit.position) && state.kindleRefusal(unit.id, as: player) == nil
            lines.append("C\(index + 1): \(named(unit, in: state)), \(GameState.counted(state.troops(of: unit))) troops"
                         + (alight ? ", in blackwood it may set alight (KINDLE)" : "")
                         + Self.waitSaid(unit, in: state, player: player)
                         + Self.seekSaid(unit, in: state, player: player)
                         + Self.scoutSaid(unit, in: state, player: player)
                         + Self.burySaid(unit, in: state, player: player)
                         + Self.raisableSaid(unit, in: state, player: player)
                         + (state.isUnlit(unit.id) ? ", marching dark, its torches doused (LIGHT)" : "")
                         + Self.errandSaid(unit, in: state))
        }
        let rallies = ralliesGathering(in: state, player: player)
        if !rallies.isEmpty {
            lines.append("Rallies of your side gathering (RALLY): " + rallies.map { rallySaid($0, in: state) }.joined(separator: "; "))
        }
        lines.append("This watch \(state.windSaid).")
        let holds = state.holds(of: player)
        lines.append("Your holds: " + holds.map(\.name).joined(separator: ", "))
        // Where the land's stores lie to be worked: a company sent to gather
        // a store goes to the nearest site of it that it may work.
        let sites = sitesKnown(in: state, player: player)
        lines.append(sites.isEmpty ? "Sites to gather at: none your House knows of."
                     : "Sites to gather at, the nearest your seat first: " + sites.joined(separator: "; "))
        // Each name once, the nearest the seat first.
        let home = state.seat(of: player)?.position ?? .origin
        var named = Set(holds.map(\.name))
        let others = places(in: state).sorted { ($0.at.distance(to: home), $0.name) < ($1.at.distance(to: home), $1.name) }
            .filter { named.insert($0.name).inserted }.prefix(briefedPlaces)
        lines.append("Places you know: " + others.map(\.name).joined(separator: ", "))
        lines.append("Works: " + BuildingKind.allCases.map(\.title).joined(separator: ", "))
        lines.append("Kinds of company: " + UnitKind.allCases.map(\.title).joined(separator: ", "))
        // The other Houses standing, each with the House's stance toward it.
        let houses = state.livingHouses.filter { $0.id != player }
            .map { "\($0.title) (\(state.stance(player, $0.id).standing))" }
        lines.append("Houses: " + houses.joined(separator: ", "))
        lines += envoysSaid(in: state, player: player)
        lines.append("Stores: " + Resource.allCases.map(\.title).joined(separator: ", "))
        let sworn = state.oaths(by: player)
        if !sworn.isEmpty {
            lines.append("Your House's oaths: " + sworn.map { state.terms(of: $0) }.joined(separator: "; "))
        }
        lines += alliance(in: state, player: player)
        return lines.joined(separator: "\n")
    }

    /// What the House may do for its alliance, as the briefing tells it:
    /// its allies' works it may still help (HELP), the shares of the spoils
    /// waiting for it (TAKE THE SHARES), and, for its leader or an officer,
    /// ground it may mark (MARK). Nothing where there is nothing to do.
    static func alliance(in state: GameState, player: Int) -> [String] {
        guard let sworn = state.alliance(of: player) else { return [] }
        var lines: [String] = []
        let allies = sworn.members.filter { $0 != player && state.houses.indices.contains($0) }
            .compactMap { ally -> String? in
                let count = state.helpable(by: player, for: ally)
                return count > 0 ? "\(state.houses[ally].title), \(count) under way" : nil
            }
        if !allies.isEmpty { lines.append("Allies' works, musters and studies your House may help (HELP): " + allies.joined(separator: "; ")) }
        let shares = state.shares(of: player)
        if !shares.isEmpty {
            lines.append("Shares of the alliance's spoils waiting for your House (TAKE THE SHARES): \(shares.count), holding \(state.sharesHeldSaid(by: player))")
        }
        if sworn.manages(player) {
            lines.append("Your House may mark ground for its alliance (MARK): "
                         + AllianceMark.Kind.allCases.map(\.word).joined(separator: ", ")
                         + ", at a place you know, SAYING a few words if you will")
        }
        return lines
    }

    /// A name as it is matched: in small letters, without "the" before it.
    static func plain(_ name: String) -> String {
        var name = name.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        for article in ["the ", "a ", "an "] where name.hasPrefix(article) { name.removeFirst(article.count) }
        return name.trimmingCharacters(in: CharacterSet(charactersIn: " .,;:!"))
    }

    /// The model's answer read line by line, at most `most` orders; a line
    /// of none of the forms is passed over, as is "NONE".
    public static func read(_ answer: String, in state: GameState, player: Int) -> [Line] {
        let written = answer.split(whereSeparator: \.isNewline).map(unmarked).filter { !$0.isEmpty && plain($0) != "none" }
        return written.prefix(most).compactMap { read(line: $0, in: state, player: player) }
    }

    /// A line without what a model likes to set about it: "1." or "-"
    /// before it, quotes, backticks or stars around it.
    static func unmarked(_ line: Substring) -> String {
        let marks = CharacterSet(charactersIn: "\"“”'‘’`*_").union(.whitespaces)
        var line = line.trimmingCharacters(in: marks)
        if let space = line.firstIndex(of: " "), line[..<space].allSatisfy({ $0.isNumber || ".)-•*".contains($0) }) {
            line = line[space...].trimmingCharacters(in: marks)
        }
        return line
    }

    /// One line of the order book read, if it is of one of its forms.
    static func read(line text: String, in state: GameState, player: Int) -> Line? {
        let words = text.split(separator: " ").map(String.init)
        guard let verb = words.first?.uppercased() else { return nil }
        let rest = Array(words.dropFirst())
        func split(_ word: String) -> (String, String)? {
            guard let at = rest.firstIndex(where: { $0.uppercased() == word }), at > 0, at < rest.count - 1 else { return nil }
            return (rest[..<at].joined(separator: " "), rest[(at + 1)...].joined(separator: " "))
        }
        func refused(_ told: String, _ why: String) -> Line { Line(text: text, command: nil, told: told, why: why) }
        func given(_ command: Command, _ told: String) -> Line {
            Line(text: text, command: command, told: told, why: state.refusal(of: command, as: player)?.description)
        }
        switch verb {
        case "MARCH", "STRIKE":
            guard let (first, second) = split(verb == "MARCH" ? "TO" : "WITH") else { return nil }
            let (handle, target) = verb == "MARCH" ? (first, second) : (second, first)
            guard let unit = company(handle, in: state, player: player) else { return refused(text, "Your House has no company \(handle).") }
            guard let place = place(target, near: unit.position, in: state) else {
                return refused("\(named(unit, in: state)) to \(target)", "Your House knows no place by the name \(target).")
            }
            return verb == "MARCH"
                ? given(.move(unit: unit.id, to: place.at), "Your \(named(unit, in: state)) march to \(place.name).")
                : given(.attack(unit: unit.id, target: place.at), "Your \(named(unit, in: state)) strike \(place.name).")
        case "FORTIFY", "HALT", "DRILL", "RAISE", "KINDLE", "DOUSE", "LIGHT", "WAIT", "SEEK", "BURY", "RECALL":
            let handle = rest.joined(separator: " ")
            guard let unit = company(handle, in: state, player: player) else { return refused(text, "Your House has no company \(handle).") }
            switch verb {
            case "FORTIFY": return given(.fortify(unit: unit.id), "Your \(named(unit, in: state)) dig in.")
            case "RECALL": return given(.recall(unit: unit.id), "Your \(named(unit, in: state)) are called home from the land's work with what they carry.")
            case "HALT": return given(.halt(unit: unit.id), "Your \(named(unit, in: state)) halt.")
            case "KINDLE": return given(.kindle(unit: unit.id), "Your \(named(unit, in: state)) set the wood alight.")
            case "DOUSE": return given(.torches(unit: unit.id, lit: false), "Your \(named(unit, in: state)) douse their torches and march dark.")
            case "LIGHT": return given(.torches(unit: unit.id, lit: true), "Your \(named(unit, in: state)) light their torches again.")
            case "WAIT": return given(.lieInWait(unit: unit.id, waiting: true), "Your \(named(unit, in: state)) lie in wait in the wood.")
            case "BURY": return given(.bury(unit: unit.id), "Your \(named(unit, in: state)) bury the dead that lie there under a barrow.")
            case "RAISE":
                // Named for the tier it would be, where there is one above it.
                let raised = unit.kind.hasTiers && unit.tier < unit.kind.highestTier
                return given(.raiseTier(unit: unit.id), raised ? "Your \(named(unit, in: state)) are raised to \(state.raisedName(of: unit))."
                                                                : "Your \(named(unit, in: state)) are raised a tier.")
            case "SEEK":
                guard let find = state.findToSeek(by: unit, as: player) else {
                    return refused(text, "Your \(named(unit, in: state)) stand by no hamlet or barrow your House has yet to seek.")
                }
                return given(.seek(unit: unit.id, find: find.id), find.kind == .hamlet
                    ? "Your \(named(unit, in: state)) seek out \(find.named)." : "Your \(named(unit, in: state)) go down into \(find.named).")
            default: return given(.drill(unit: unit.id), "Your \(named(unit, in: state)) drill.")
            }
        case "GATHER":
            // GATHER <store> WITH <company>: the nearest site of the store the
            // company may work, as the rules would send it; GATHER <company>,
            // the nearest of any store.
            let asked: String, handle: String
            if let (first, second) = split("WITH") {
                (asked, handle) = (first, second)
            } else {
                (asked, handle) = (rest.dropLast().joined(separator: " "), rest.last ?? "")
            }
            guard let unit = company(handle, in: state, player: player) else { return refused(text, "Your House has no company \(handle).") }
            var store: Resource?
            if !asked.isEmpty {
                guard let named = Self.store(asked) else { return refused(text, "No store goes by the name \(asked).") }
                store = named
            }
            guard let site = state.sitesToGather(by: unit, as: player, store: store, most: 1).first else {
                return refused(text, gatherRefused(unit, store: store, in: state, player: player))
            }
            return given(.gather(unit: unit.id, site: site.id),
                         "Your \(named(unit, in: state)) gather \(site.store.title.lowercased()) at \(state.siteSaid(site)), "
                            + "\(GameState.waySaid(to: site.position, from: unit.position)).")
        case "SCOUT", "REINFORCE":
            // Lanterns sent to scout another House's hold within their reach;
            // a company of war sent to keep the gates of a hold of its own
            // House or an ally's. A hold by its name, the nearest of it.
            guard let (target, handle) = split("WITH") else { return nil }
            guard let unit = company(handle, in: state, player: player) else { return refused(text, "Your House has no company \(handle).") }
            guard let hold = state.holds.filter({ plain($0.name) == plain(target) })
                .min(by: { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }) else {
                return refused("\(named(unit, in: state)) to \(target)", "Your House knows no hold by the name \(target).")
            }
            return verb == "SCOUT"
                ? given(.scout(unit: unit.id, hold: hold.id), "Your \(named(unit, in: state)) scout \(hold.name).")
                : given(.reinforce(unit: unit.id, hold: hold.id), "Your \(named(unit, in: state)) go to keep the gates of \(hold.name).")
        case "RALLY":
            // RALLY AGAINST <target> WITH <company>: a rally of the House's
            // side still gathering against that hold or lair; RALLY <company>,
            // the one setting out soonest that the company may join.
            var asked: String?, handle = rest.joined(separator: " ")
            if let (first, second) = split("WITH") {
                asked = first.uppercased().hasPrefix("AGAINST ") ? String(first.dropFirst("AGAINST ".count)) : first
                handle = second
            }
            guard let unit = company(handle, in: state, player: player) else { return refused(text, "Your House has no company \(handle).") }
            let gathering = ralliesGathering(in: state, player: player)
            let matching = asked.map { against in gathering.filter { state.targetName($0.target).map(plain) == plain(against) } } ?? gathering
            guard let rally = matching.first(where: { state.joinRallyRefusal($0.id, with: unit.id, as: player) == nil }) ?? matching.first else {
                return refused(text, asked.map { "Your side has no rally gathering against \($0)." } ?? "Your side has no rally gathering.")
            }
            return given(.joinRally(rally: rally.id, unit: unit.id), "Your \(named(unit, in: state)) go to the rally \(rallySaid(rally, in: state)).")
        case "BUILD", "TRAIN":
            guard let (what, at) = split("AT") else { return nil }
            guard let hold = state.holds(of: player).first(where: { plain($0.name) == plain(at) }) else {
                return refused(text, "Your House holds no hold by the name \(at).")
            }
            if verb == "BUILD" {
                guard let kind = work(what) else { return refused(text, "No work goes by the name \(what).") }
                return given(.build(hold: hold.id, kind: kind), "\(hold.name) raises its \(kind.title).")
            }
            guard let kind = Self.kind(what) else { return refused(text, "No company goes by the name \(what).") }
            return given(.train(hold: hold.id, kind: kind), "\(hold.name) musters a company of \(kind.title).")
        case "ACCEPT", "REFUSE":
            // An answer to the envoy another House sent: its offer taken, or
            // turned away.
            let said = rest.joined(separator: " ")
            guard let lead = ["THE ENVOY OF ", "ENVOY OF "].first(where: { said.uppercased().hasPrefix($0) }) else { return nil }
            let name = String(said.dropFirst(lead.count))
            guard let other = house(name, in: state, player: player) else { return refused(text, "No House goes by the name \(name).") }
            let title = state.houses[other].title
            guard let envoy = envoy(from: other, in: state, player: player) else {
                return refused(text, "No envoy of \(title) waits on your answer.")
            }
            return given(.answer(envoy: envoy.id, accept: verb == "ACCEPT"), answerTold(envoy, accept: verb == "ACCEPT", in: state, player: player))
        case "OFFER" where ["HALF THE TRIBUTE TO ", "HALF TO "].contains(where: { rest.joined(separator: " ").uppercased().hasPrefix($0) }):
            // Half a steward's demand of tribute offered in its place.
            let said = rest.joined(separator: " ")
            let lead = said.uppercased().hasPrefix("HALF TO ") ? "HALF TO " : "HALF THE TRIBUTE TO "
            let name = String(said.dropFirst(lead.count))
            guard let other = house(name, in: state, player: player) else { return refused(text, "No House goes by the name \(name).") }
            let title = state.houses[other].title
            guard let envoy = envoy(from: other, in: state, player: player) else {
                return refused(text, "No envoy of \(title) waits on your answer.")
            }
            return given(.bargain(envoy: envoy.id), "Your House offers \(title) half its demand: \(state.halfTribute(from: player)), "
                         + "for \(GameState.halfTributeRespite) watches' peace.")
        case "OFFER", "DEMAND", "DECLARE":
            // An envoy to another House, or war on it.
            let said = rest.joined(separator: " ")
            let leads: [(verb: String, lead: String, proposal: Proposal?)] = [
                ("OFFER", "PEACE TO ", .peace), ("OFFER", "A PACT TO ", .pact), ("OFFER", "PACT TO ", .pact),
                ("DEMAND", "TRIBUTE FROM ", .tribute), ("DECLARE", "WAR ON ", nil),
            ]
            guard let form = leads.first(where: { $0.verb == verb && said.uppercased().hasPrefix($0.lead) }) else { return nil }
            let name = String(said.dropFirst(form.lead.count))
            guard let other = house(name, in: state, player: player) else { return refused(text, "No House goes by the name \(name).") }
            let title = state.houses[other].title
            switch form.proposal {
            case nil: return given(.declareWar(on: other), "War on \(title).")
            case .tribute?: return given(.propose(.tribute, to: other), "An envoy to \(title), demanding tribute.")
            case .pact?: return given(.propose(.pact, to: other), "An envoy to \(title), offering a pact.")
            case let proposal?: return given(.propose(proposal, to: other), "An envoy to \(title), offering peace.")
            }
        case "GIVE":
            guard let (what, to) = split("TO") else { return nil }
            guard let (amount, store) = stores(what) else { return nil }
            guard let resource = resource(store) else { return refused(text, "No store goes by the name \(store).") }
            guard let other = house(to, in: state, player: player) else { return refused(text, "No House goes by the name \(to).") }
            return given(.gift(to: other, resource: resource, amount: amount),
                         "\(GameState.counted(amount)) \(resource.title.lowercased()) sent to \(state.houses[other].title).")
        case "TRADE":
            guard let (terms, with) = split("WITH") else { return nil }
            let words = terms.split(separator: " ").map(String.init)
            guard let at = words.firstIndex(where: { $0.uppercased() == "FOR" }),
                  let (giving, given1) = stores(words[..<at].joined(separator: " ")),
                  let (taking, taken1) = stores(words[(at + 1)...].joined(separator: " ")) else { return nil }
            guard let give = resource(given1) else { return refused(text, "No store goes by the name \(given1).") }
            guard let take = resource(taken1) else { return refused(text, "No store goes by the name \(taken1).") }
            guard let other = house(with, in: state, player: player) else { return refused(text, "No House goes by the name \(with).") }
            return given(.offerTrade(Trade(give: give, giving, for: take, taking), to: other, words: nil),
                         "\(GameState.counted(giving)) \(give.title.lowercased()) offered to \(state.houses[other].title) "
                            + "for \(GameState.counted(taking)) \(take.title.lowercased()).")
        case "SWEAR":
            // An oath, which the realm will hold the House to, read word by word.
            let upper = rest.map { $0.uppercased() }
            func span(after at: Int) -> Int? {
                upper.indices.contains(at + 1) ? Int(upper[at + 1]) : nil
            }
            if upper.count >= 5, upper[0] == "PEACE", upper[1] == "WITH", let forAt = upper.lastIndex(of: "FOR"), forAt > 2 {
                let name = rest[2..<forAt].joined(separator: " ")
                guard let other = house(name, in: state, player: player) else { return refused(text, "No House goes by the name \(name).") }
                guard let watches = span(after: forAt) else { return nil }
                return given(.swear(.peace, to: other, watches: watches),
                             "Your House swears peace with \(state.houses[other].title) for \(GameState.watches(watches)); the realm will hold it to its word.")
            }
            if upper.count >= 10, upper[0] == "TO", upper[1] == "SEND", let toAt = upper[3...].firstIndex(of: "TO"),
               let eachAt = upper.lastIndex(of: "EACH"), toAt + 1 < eachAt, eachAt + 2 < upper.count,
               upper[eachAt + 1].hasPrefix("WATCH"), upper[eachAt + 2] == "FOR" {
                guard let (amount, store) = stores(rest[2..<toAt].joined(separator: " ")) else { return nil }
                let name = rest[(toAt + 1)..<eachAt].joined(separator: " ")
                guard let resource = resource(store) else { return refused(text, "No store goes by the name \(store).") }
                guard let other = house(name, in: state, player: player) else { return refused(text, "No House goes by the name \(name).") }
                guard let watches = span(after: eachAt + 2) else { return nil }
                return given(.swear(.send(resource, amount), to: other, watches: watches),
                             "Your House swears to send \(GameState.counted(amount)) \(resource.title.lowercased()) to \(state.houses[other].title) "
                                + "each watch for \(GameState.watches(watches)).")
            }
            return nil
        case "RENOUNCE":
            let said = rest.joined(separator: " ")
            let leads = ["THE OATH TO ", "OUR OATH TO ", "THE OATHS TO ", "OATH TO "]
            guard let lead = leads.first(where: { said.uppercased().hasPrefix($0) }) else { return nil }
            let name = String(said.dropFirst(lead.count))
            guard let other = house(name, in: state, player: player) else { return refused(text, "No House goes by the name \(name).") }
            guard let oath = state.oaths(by: player).first(where: { $0.to == other && $0.renounced == nil }) else {
                return refused(text, "Your House is sworn to no oath to \(state.houses[other].title) it has not renounced.")
            }
            return given(.renounce(oath: oath.id),
                         "Your House renounces its oath to \(state.houses[other].title): \(state.terms(of: oath)); it binds three watches more.")
        case "HELP":
            // A hand lent to every work, muster and study of an ally's under
            // way that the House has yet to help.
            let name = rest.joined(separator: " ")
            guard !name.isEmpty else { return nil }
            guard let other = house(name, in: state, player: player) else { return refused(text, "No House goes by the name \(name).") }
            return given(.help(house: other), "Your House lends a hand to the works, musters and study of \(state.houses[other].title) under way.")
        case "TAKE":
            guard ["THE SHARES", "SHARES", "THE SPOILS", "THE SHARES OF THE SPOILS"].contains(rest.joined(separator: " ").uppercased()) else {
                return nil
            }
            let waiting = state.shares(of: player)
            return given(.takeShares, "Your House takes up the shares of the alliance's spoils"
                         + (waiting.isEmpty ? "." : ", holding \(state.sharesHeldSaid(by: player))."))
        case "MARK":
            // MARK <mark> AT <place> SAYING <words>: ground marked for the
            // alliance, the nearest place of that name to the seat.
            let upper = rest.map { $0.uppercased() }
            guard upper.count >= 3, upper[1] == "AT",
                  let kind = AllianceMark.Kind.allCases.first(where: { $0.word.uppercased() == upper[0] }) else { return nil }
            let saying = upper.indices.dropFirst(2).first { upper[$0] == "SAYING" }
            let named = rest[2..<(saying ?? rest.count)].joined(separator: " ")
            guard !named.isEmpty else { return nil }
            let words = GameState.markWords(saying.map { rest[($0 + 1)...].joined(separator: " ") })
            guard let place = place(named, near: state.seat(of: player)?.position ?? .origin, in: state) else {
                return refused(text, "Your House knows no place by the name \(named).")
            }
            return given(.markGround(place.at, kind, words: words),
                         "\(kind.title), marked at \(place.name) for your alliance" + (words.map { ": “\($0)”." } ?? "."))
        case "WHILE":
            // A standing order, for the caretaker that keeps the House while
            // its keeper is away.
            guard rest.count >= 2, rest[0].uppercased() == "AWAY" else { return nil }
            let said = rest.dropFirst().joined(separator: " ")
            let asked = plain(said).uppercased()
            func standing(_ order: StandingOrder) -> Line {
                var told = StandingOrders(house: player)
                told.take(order)
                return given(.stand(order), told.said)
            }
            if asked.hasPrefix("MUSTER ") {
                let what = String(said.dropFirst("MUSTER ".count))
                guard let kind = Self.kind(what) else { return refused(text, "No company goes by the name \(what).") }
                return standing(.muster(kind))
            }
            if asked.hasPrefix("RAISE ") {
                var what = String(said.dropFirst("RAISE ".count)).trimmingCharacters(in: CharacterSet(charactersIn: " .,;:!"))
                if what.uppercased().hasSuffix(" FIRST") { what = String(what.dropLast(" FIRST".count)) }
                guard let kind = work(what) else { return refused(text, "No work goes by the name \(what).") }
                return standing(.raise(kind))
            }
            switch asked {
            case "KEEP HOME", "KEEP EVERY COMPANY HOME": return standing(.home)
            case "MAKE PEACE": return standing(.peace(true))
            case "MAKE NO PEACE": return standing(.peace(false))
            case "PAY TRIBUTE": return standing(.tribute(true))
            case "PAY NO TRIBUTE": return standing(.tribute(false))
            case "AS YOU SEE FIT": return given(.standDown, StandingOrders(house: player).said)
            default: return nil
            }
        default:
            return nil
        }
    }

    /// The kind of company a line names, by its title or one less its last
    /// letter: "Spears" or "Spear".
    static func kind(_ name: String) -> UnitKind? {
        UnitKind.allCases.first { [plain($0.title), String(plain($0.title).dropLast())].contains(plain(name)) }
    }

    /// The work a line names.
    static func work(_ name: String) -> BuildingKind? {
        BuildingKind.allCases.first { plain($0.title) == plain(name) }
    }

    /// An amount of a store as a line gives it: "50 timber", "1,000 grain".
    static func stores(_ words: String) -> (amount: Int, store: String)? {
        let words = words.split(separator: " ").map(String.init)
        guard words.count >= 2, let amount = Int(words[0].filter { $0 != "," }), amount > 0 else { return nil }
        return (amount, words.dropFirst().joined(separator: " "))
    }

    /// The store a line names.
    static func resource(_ name: String) -> Resource? {
        Resource.allCases.first { plain($0.title) == plain(name) }
    }

    /// The store a GATHER line names: by its own name, or by the name of
    /// its sites or its alliance's yards, as a look tells them ("Deadfall",
    /// "the Deadfall II", "the Timber Yard").
    static func store(_ name: String) -> Resource? {
        let asked = plain(name)
        return resource(name) ?? Resource.allCases.first { store in
            [Site.title(of: store), Yard.title(of: store)].map(plain).contains { asked == $0 || asked.hasPrefix($0 + " ") }
        }
    }

    /// Why a company can't be sent to gather, as the nearest site of the
    /// store asked that the House knows tells it, or that the House knows
    /// of none.
    static func gatherRefused(_ unit: Unit, store: Resource?, in state: GameState, player: Int) -> String {
        let known = state.sitesInLand.filter { (store == nil || $0.store == store) && state.isExplored($0.position, by: player) }
            .min { ($0.position.distance(to: unit.position), $0.id) < ($1.position.distance(to: unit.position), $1.id) }
        if let known, let refusal = state.gatherRefusal(unit.id, at: known.id, as: player) { return refusal.description }
        return "Your House knows of no site of \(store.map { $0.title.lowercased() } ?? "any store") to gather at."
    }

    /// Another House a line names, by its title or its name alone; one
    /// standing before one fallen.
    static func house(_ name: String, in state: GameState, player: Int) -> Int? {
        state.houses.filter { $0.id != player && [plain($0.title), plain($0.name)].contains(plain(name)) }
            .min { ($0.isEliminated ? 1 : 0, $0.id) < ($1.isEliminated ? 1 : 0, $1.id) }?.id
    }

    /// The envoy of another House waiting on the House's answer, the one
    /// that came first where several did.
    static func envoy(from other: Int, in state: GameState, player: Int) -> Envoy? {
        state.envoys.filter { $0.from == other && $0.to == player }.min { ($0.arrived, $0.id) < ($1.arrived, $1.id) }
    }

    /// What answering an envoy orders, in the realm's words.
    static func answerTold(_ envoy: Envoy, accept: Bool, in state: GameState, player: Int) -> String {
        let title = state.houses[envoy.from].title
        switch (envoy.proposal, accept) {
        case (.tribute, true): return "Your House pays \(title) its tribute: \(state.tribute(from: player))."
        case (.tribute, false):
            return state.refusingIsWar(envoy) ? "Your House refuses \(title) its tribute, and it marches on you."
                : "Your House refuses \(title) its tribute."
        case (.trade, true): return "Your House takes \(title)'s trade" + (envoy.trade.map { ": \($0.taken) of yours for \($0.given)." } ?? ".")
        case (let proposal, true): return "Your House takes \(title)'s offer of \(proposal.offered)."
        case (let proposal, false): return "Your House turns away \(title)'s offer of \(proposal.offered)."
        }
    }

    /// The envoys waiting on the House's answer, as the briefing tells
    /// them: what each carries, and where a steward's demand may be
    /// bargained down, what half would pay.
    static func envoysSaid(in state: GameState, player: Int) -> [String] {
        let waiting = state.envoys.filter { $0.to == player && state.houses.indices.contains($0.from) }
            .sorted { ($0.arrived, $0.id) < ($1.arrived, $1.id) }
        guard !waiting.isEmpty else { return [] }
        return ["Envoys waiting on your answer (ACCEPT or REFUSE THE ENVOY OF <house>): " + waiting.prefix(4).map { envoy in
            state.terms(of: envoy, for: player)
                + (state.bargainRefusal(envoy.id, as: player) == nil
                    ? " Half may be offered (OFFER HALF THE TRIBUTE TO \(state.houses[envoy.from].title)): \(state.halfTribute(from: player))."
                    : "")
        }.joined(separator: " ")]
    }

    /// The company a line names: C and its number in the briefing, the
    /// last word of what names it.
    static func company(_ handle: String, in state: GameState, player: Int) -> Unit? {
        let handle = plain(handle).split(separator: " ").last.map { $0.uppercased() } ?? ""
        guard handle.hasPrefix("C"), let number = Int(handle.dropFirst()) else { return nil }
        let all = companies(in: state, player: player)
        return all.indices.contains(number - 1) ? all[number - 1] : nil
    }

    /// The place a line names, the nearest of that name if several go by it.
    static func place(_ name: String, near hex: Hex, in state: GameState) -> (name: String, at: Hex)? {
        places(in: state).filter { plain($0.name) == plain(name) }
            .min { ($0.at.distance(to: hex), $0.at) < ($1.at.distance(to: hex), $1.at) }
    }
}
