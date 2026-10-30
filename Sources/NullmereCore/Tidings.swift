/// What a keeper is told of the realm's deeper doings, in the game's own
/// words: a line, and whether it is good news, bad or neither. Nil when the
/// event is nothing to them.
public struct Tidings: Equatable, Sendable {
    public enum Tone: String, Equatable, Sendable {
        case good, bad, neutral
    }

    public let text: String
    public let tone: Tone

    public init(_ text: String, _ tone: Tone) {
        self.text = text
        self.tone = tone
    }
}

extension GameState {
    /// The line a keeper of `viewer`'s House reads for an event of the
    /// realm's deeper systems, read against the world after it.
    public func tidings(of event: GameEvent, for viewer: Int) -> Tidings? {
        switch event {
        case .studyBegun(let house, let study, let grade):
            guard house == viewer else { return nil }
            return Tidings("Your Archive takes up \(GameState.graded(study, grade)).", .neutral)
        case .studyCompleted(let house, let study, let grade):
            guard house == viewer else { return nil }
            return Tidings("Your House masters \(GameState.graded(study, grade)): \(study.effect.prefix(1).lowercased() + study.effect.dropFirst()).", .good)
        case .commanderJoined(let id, let house):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name), \(commander.archetype.named), joins your House.", .good)
        case .commanderAssigned(let id, let unitID):
            guard let commander = commander(id), commander.owner == viewer, let unit = unit(unitID) else { return nil }
            return Tidings("\(commander.name) takes command of your \(unit.kind.title).", .neutral)
        case .commanderReleased(let id):
            guard let commander = commander(id), commander.owner == viewer else { return nil }
            return Tidings("\(commander.name) rides home to your seat.", .neutral)
        case .commanderRose(let id, let house, let level):
            guard house == viewer, let commander = commander(id) else { return nil }
            let gained = commander.archetype.skills.first { $0.unlock == level }
            return Tidings("\(commander.name) rises to level \(level)" + (gained.map { ", and with it \($0.title)." } ?? "."), .good)
        case .commanderWounded(let id, let house):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name) is carried home wounded; whole again in \(GameState.woundWatches) watches.", .bad)
        case .talentLearned(let id, let house, let talent, let rank):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name) learns \(talent.title)" + (talent.ranks > 1 ? " \(BuildingKind.numeral(rank))." : "."), .good)
        case .talentsForgotten(let id, let house):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name) forgets their talents, to learn them anew.", .neutral)
        case .gearFound(let house, let piece, let wild):
            guard house == viewer else { return nil }
            return Tidings("Among the fallen \(wild.title.hasPrefix("the ") ? String(wild.title.dropFirst(4)) : wild.title), your company finds a \(piece.title).", .good)
        case .gearWorn(let id, let house, let gearID):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name) takes up the \(gear(gearID)?.title ?? "gear").", .neutral)
        case .gearTakenOff(let id, let house, let gearID):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name) lays down the \(gear(gearID)?.title ?? "gear").", .neutral)
        case .gearScrapped(let house, _, let moonsalt):
            guard house == viewer else { return nil }
            return Tidings("A piece of gear is broken up for \(moonsalt) moonsalt.", .neutral)
        case .skillFired(let id, let house, let skill, _):
            guard let commander = commander(id) else { return nil }
            if house == viewer { return Tidings("\(commander.name) calls \(skill.title).", .good) }
            return Tidings("\(commander.name) of \(houses[house].title) calls \(skill.title).", .bad)
        case .hunted(let hunt):
            let prey = "\(hunt.wildKind.title) of level \(hunt.level)"
            guard hunt.attackerOwner == viewer else {
                let felled = hunt.wildFell ? ", and they fall" : ""
                return Tidings("\(houses[hunt.attackerOwner].title)'s \(hunt.attackerKind.title) strike \(prey)\(felled).", .neutral)
            }
            let fall = hunt.wildFell ? (hunt.spoils.isZero ? "; they fall" : "; they fall, and leave \(hunt.spoils)") : ""
            let lost = hunt.attackerFell ? "; your company is lost" : ""
            return Tidings("Your \(hunt.attackerKind.title) strike \(prey) for \(hunt.damageDealt)\(fall)\(lost).", hunt.attackerFell ? .bad : .good)
        case .sentToGather(let unitID, let siteID):
            guard let unit = unit(unitID), unit.owner == viewer else { return nil }
            let place = site(siteID).map { "the \($0.title.lowercased())" } ?? "the site"
            return Tidings("Your \(unit.kind.title) set out to work \(place).", .neutral)
        case .gathered(let unitID, let owner, let load):
            guard owner == viewer else { return nil }
            let who = unit(unitID).map { "Your \($0.kind.title)" } ?? "Your gatherers"
            return Tidings("\(who) turn for home with \(load).", .neutral)
        case .delivered(_, let owner, let holdID, let load):
            guard owner == viewer else { return nil }
            return Tidings("\(load.description.prefix(1).uppercased() + load.description.dropFirst()) brought home to \(hold(holdID)?.name ?? "your hold").", .good)
        case .siteWorkedOut(_, let store, _):
            return Tidings("The \(Site.title(of: store).lowercased()) is worked out.", .neutral)
        case .allianceFounded(let id, let house):
            let name = alliance(id)?.name ?? "a new alliance"
            return house == viewer ? Tidings("You raise a banner: \(name).", .good) : Tidings("\(houses[house].title) raises a banner: \(name).", .neutral)
        case .allianceInvited(let id, let house):
            guard let alliance = alliance(id) else { return nil }
            if house == viewer { return Tidings("\(houses[alliance.leader].title) invites you into \(alliance.name).", .neutral) }
            return Tidings("\(houses[house].title) is invited into \(alliance.name).", .neutral)
        case .allianceAsked(let id, let house):
            guard let alliance = alliance(id) else { return nil }
            if house == viewer { return Tidings("You ask to join \(alliance.name).", .neutral) }
            return Tidings("\(houses[house].title) asks to join \(alliance.name).", .neutral)
        case .allianceAnswered(let id, let house, let accepted):
            // A House taken in is told by its joining.
            guard !accepted, let alliance = alliance(id) else { return nil }
            if house == viewer { return Tidings("There is no place for you in \(alliance.name) now.", .bad) }
            return Tidings("\(houses[house].title) stays outside \(alliance.name).", .neutral)
        case .allianceJoined(let id, let house):
            let name = alliance(id)?.name ?? "the alliance"
            if house == viewer { return Tidings("You are sworn to \(name).", .good) }
            let ours = alliance(id)?.members.contains(viewer) == true
            return Tidings("\(houses[house].title) joins \(name).", ours ? .good : .neutral)
        case .allianceLeft(let id, let house, let expelled):
            let name = alliance(id)?.name ?? "its alliance"
            if house == viewer { return expelled ? Tidings("You are cast out of \(name).", .bad) : Tidings("You leave \(name).", .neutral) }
            return Tidings("\(houses[house].title) \(expelled ? "is cast out of" : "leaves") \(name).", .neutral)
        case .allianceLed(let id, let house):
            let name = alliance(id)?.name ?? "the alliance"
            return house == viewer ? Tidings("The banner of \(name) passes to you.", .good)
                : Tidings("\(houses[house].title) takes up the banner of \(name).", .neutral)
        case .allianceDisbanded(_, let name):
            return Tidings("\(name) is no more.", .neutral)
        case .helpGiven(let by, let to, let count):
            let works = count == 1 ? "work" : "works"
            if to == viewer { return Tidings("\(houses[by].title) helps \(count) of your \(works).", .good) }
            if by == viewer { return Tidings("You help \(count) of \(houses[to].title)'s \(works).", .neutral) }
            return nil
        case .rallyCalled(let id, let caller, let targetID):
            guard let rally = rally(id), let muster = hold(rally.muster), let target = hold(targetID) else { return nil }
            if caller == viewer { return Tidings("You call a rally at \(muster.name) against \(target.name).", .neutral) }
            let watches = rally.setsOut - watch
            return Tidings("\(houses[caller].title) calls a rally at \(muster.name) against \(target.name); "
                + "it sets out in \(watches) watch\(watches == 1 ? "" : "es").", .neutral)
        case .rallyJoined(let id, let unitID, let owner):
            guard let rally = rally(id), let muster = hold(rally.muster), let unit = unit(unitID) else { return nil }
            if owner == viewer { return Tidings("Your \(unit.kind.title) march to the rally at \(muster.name).", .neutral) }
            return Tidings("\(houses[owner].title) sends \(unit.kind.title) to the rally at \(muster.name).", .neutral)
        case .rallySetOut(_, let caller, let targetID, let defender, let companies):
            let target = hold(targetID)?.name ?? "their hold"
            let host = "\(companies) compan\(companies == 1 ? "y" : "ies")"
            if defender == viewer { return Tidings("A host of \(host) marches on \(target)!", .bad) }
            let whose = caller == viewer ? "Your" : "\(houses[caller].title)'s"
            return Tidings("\(whose) host of \(host) sets out for \(target).", .neutral)
        case .rallyStruck(_, _, let targetID, let defender, let taken):
            let target = hold(targetID)?.name ?? "the hold"
            if defender == viewer {
                return taken ? Tidings("The host takes \(target).", .bad) : Tidings("\(target) holds against the host.", .good)
            }
            return taken ? Tidings("The host takes \(target)!", .good) : Tidings("The host falls upon \(target), but it holds.", .neutral)
        case .rallyDispersed(_, let caller):
            return caller == viewer ? Tidings("Your rally comes to nothing.", .bad) : Tidings("\(houses[caller].title)'s rally comes to nothing.", .neutral)
        case .sentToReinforce(let unitID, let owner, let holdID):
            guard let hold = hold(holdID), let unit = unit(unitID) else { return nil }
            if owner == viewer { return Tidings("Your \(unit.kind.title) march to keep the gates of \(hold.name).", .neutral) }
            return Tidings("\(houses[owner].title)'s \(unit.kind.title) come to keep the gates of \(hold.name).", .good)
        case .happeningBegun(let kind, let ends):
            return Tidings("\(kind.title) begins: \(kind.goal), until the \(ordinal(ends)) watch.", .neutral)
        case .happeningMark(let house, let kind, let mark, let reward):
            guard house == viewer else { return nil }
            return Tidings("Your House passes the \(ordinal(mark)) mark of \(kind.title): \(reward).", .good)
        case .happeningEnded(let kind, let leaders):
            if let place = leaders.firstIndex(of: viewer) {
                return Tidings("\(kind.title) ends: your House stands \(ordinal(place + 1)), and is honoured.", .good)
            }
            guard let first = leaders.first else { return Tidings("\(kind.title) ends with no House to honour.", .neutral) }
            return Tidings("\(kind.title) ends: \(houses[first].title) takes the honours.", .neutral)
        case .deedDone(let house, let deed):
            guard house == viewer else { return nil }
            return Tidings("A deed of your House, \(deed.title): it has \(deed.deed).", .good)
        case .said(let word):
            guard word.from != viewer, houses.indices.contains(word.from) else { return nil }
            let channel = word.alliance == nil ? "" : " to your alliance"
            return Tidings("\(houses[word.from].title)\(channel): “\(word.text)”", .neutral)
        case .chargeDone(let house, let charge, let reward):
            guard house == viewer else { return nil }
            let next = self.charge(of: viewer).map { " Next: \($0.title.prefix(1).lowercased() + $0.title.dropFirst())." } ?? ""
            return Tidings("Charge done: \(charge.title.prefix(1).lowercased() + charge.title.dropFirst()), and \(reward) given.\(next)", .good)
        default:
            return nil
        }
    }

    /// A study and its grade as the game writes it: "Furrow Lore II", "Drill".
    public static func graded(_ study: Study, _ grade: Int) -> String {
        study.grades > 1 ? "\(study.title) \(BuildingKind.numeral(grade))" : study.title
    }
}
