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
                               "DRILL <company>", "KINDLE <company>", "DOUSE <company>", "LIGHT <company>", "WAIT <company>", "SEEK <company>",
                               "BURY <company>",
                               "BUILD <work> AT <hold>", "TRAIN <kind> AT <hold>",
                               "OFFER PEACE TO <house>", "OFFER A PACT TO <house>", "DEMAND TRIBUTE FROM <house>", "DECLARE WAR ON <house>",
                               "GIVE <amount> <store> TO <house>", "TRADE <amount> <store> FOR <amount> <store> WITH <house>",
                               "SWEAR PEACE WITH <house> FOR <watches> WATCHES",
                               "SWEAR TO SEND <amount> <store> TO <house> EACH WATCH FOR <watches> WATCHES",
                               "RENOUNCE THE OATH TO <house>",
                               "WHILE AWAY MUSTER <kind>", "WHILE AWAY RAISE <work> FIRST", "WHILE AWAY KEEP HOME",
                               "WHILE AWAY MAKE PEACE", "WHILE AWAY MAKE NO PEACE", "WHILE AWAY PAY TRIBUTE", "WHILE AWAY PAY NO TRIBUTE",
                               "WHILE AWAY AS YOU SEE FIT"]
    /// The most lines read at once.
    public static let most = 6
    /// The most companies and places the briefing names, the nearest the
    /// seat first, so it stays within what the model reads at once.
    public static let briefedCompanies = 40
    public static let briefedPlaces = 80

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
                         + Self.burySaid(unit, in: state, player: player)
                         + (state.isUnlit(unit.id) ? ", marching dark, its torches doused (LIGHT)" : ""))
        }
        lines.append("This watch \(state.windSaid).")
        let holds = state.holds(of: player)
        lines.append("Your holds: " + holds.map(\.name).joined(separator: ", "))
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
        lines.append("Stores: " + Resource.allCases.map(\.title).joined(separator: ", "))
        let sworn = state.oaths(by: player)
        if !sworn.isEmpty {
            lines.append("Your House's oaths: " + sworn.map { state.terms(of: $0) }.joined(separator: "; "))
        }
        return lines.joined(separator: "\n")
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
        case "FORTIFY", "HALT", "DRILL", "KINDLE", "DOUSE", "LIGHT", "WAIT", "SEEK", "BURY":
            let handle = rest.joined(separator: " ")
            guard let unit = company(handle, in: state, player: player) else { return refused(text, "Your House has no company \(handle).") }
            switch verb {
            case "FORTIFY": return given(.fortify(unit: unit.id), "Your \(named(unit, in: state)) dig in.")
            case "HALT": return given(.halt(unit: unit.id), "Your \(named(unit, in: state)) halt.")
            case "KINDLE": return given(.kindle(unit: unit.id), "Your \(named(unit, in: state)) set the wood alight.")
            case "DOUSE": return given(.torches(unit: unit.id, lit: false), "Your \(named(unit, in: state)) douse their torches and march dark.")
            case "LIGHT": return given(.torches(unit: unit.id, lit: true), "Your \(named(unit, in: state)) light their torches again.")
            case "WAIT": return given(.lieInWait(unit: unit.id, waiting: true), "Your \(named(unit, in: state)) lie in wait in the wood.")
            case "BURY": return given(.bury(unit: unit.id), "Your \(named(unit, in: state)) bury the dead that lie there under a barrow.")
            case "SEEK":
                guard let find = state.findToSeek(by: unit, as: player) else {
                    return refused(text, "Your \(named(unit, in: state)) stand by no hamlet or barrow your House has yet to seek.")
                }
                return given(.seek(unit: unit.id, find: find.id), find.kind == .hamlet
                    ? "Your \(named(unit, in: state)) seek out \(find.named)." : "Your \(named(unit, in: state)) go down into \(find.named).")
            default: return given(.drill(unit: unit.id), "Your \(named(unit, in: state)) drill.")
            }
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

    /// Another House a line names, by its title or its name alone; one
    /// standing before one fallen.
    static func house(_ name: String, in state: GameState, player: Int) -> Int? {
        state.houses.filter { $0.id != player && [plain($0.title), plain($0.name)].contains(plain(name)) }
            .min { ($0.isEliminated ? 1 : 0, $0.id) < ($1.isEliminated ? 1 : 0, $1.id) }?.id
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
