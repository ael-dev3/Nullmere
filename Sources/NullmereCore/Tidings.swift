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
        case .makingsFound(let house, let making, let count):
            guard house == viewer else { return nil }
            return Tidings("\(count) \(making.title.lowercased()) for your Forge.", .neutral)
        case .gearForged(let house, let piece):
            guard house == viewer else { return nil }
            return Tidings("Your smiths forge a \(piece.title), of \(piece.kind.set?.title ?? "no set"): \(piece.effect).", .good)
        case .gearWorn(let id, let house, let gearID):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name) takes up the \(gear(gearID)?.title ?? "gear").", .neutral)
        case .gearTakenOff(let id, let house, let gearID):
            guard house == viewer, let commander = commander(id) else { return nil }
            return Tidings("\(commander.name) lays down the \(gear(gearID)?.title ?? "gear").", .neutral)
        case .shrineTaken(let id, let house, let from):
            guard let shrine = holySites.first(where: { $0.id == id }) else { return nil }
            if house == viewer { return Tidings("Your company takes the \(shrine.title): \(shrine.kind.effect).", .good) }
            if from == viewer { return Tidings("\(houses[house].title) takes the \(shrine.title) from you.", .bad) }
            if areAllied(house, viewer) { return Tidings("\(houses[house].title), your ally, takes the \(shrine.title): \(shrine.kind.effect).", .good) }
            return Tidings("\(houses[house].title) takes the \(shrine.title).", .neutral)
        case .gearScrapped(let house, _, let moonsalt):
            guard house == viewer else { return nil }
            return Tidings("A piece of gear is broken up for \(moonsalt) moonsalt.", .neutral)
        case .carriedToInfirmary(let kind, let owner, let holdID):
            guard owner == viewer, let hold = hold(holdID) else { return nil }
            return Tidings("Your fallen \(kind.title) are carried to the Infirmary at \(hold.name), to be healed there.", .neutral)
        case .healingBegun(let holdID, let house, let count):
            guard house == viewer, let hold = hold(holdID) else { return nil }
            let companies = count == 1 ? "a company" : "\(count) companies"
            return Tidings("The healers at \(hold.name) tend \(companies); they rise as the watch turns.", .neutral)
        case .unitHealed(let unitID, let holdID):
            guard let unit = unit(unitID), unit.owner == viewer, let hold = hold(holdID) else { return nil }
            return Tidings("Your \(unit.kind.title) rise healed at \(hold.name).", .good)
        case .holdScouted(let report):
            guard report.by == viewer else { return nil }
            let name = hold(report.hold)?.name ?? "the hold"
            let count = report.garrison.count
            let gates = count == 0 ? "no company" : (count == 1 ? "a company" : "\(count) companies")
            return Tidings("Your Lanterns scout \(name): \(gates) at its gates, its ward \(report.ward) of \(report.maximumWard).", .neutral)
        case .scoutSeen(let holdID, let by):
            guard let hold = hold(holdID), hold.owner == viewer, houses.indices.contains(by) else { return nil }
            return Tidings("Lanterns of \(houses[by].title) watch \(hold.name).", .bad)
        case .standardRaised(_, let id, let house, let at):
            guard let alliance = alliance(id) else { return nil }
            let place = placeName(of: at)
            if house == viewer { return Tidings("You raise a standard of \(alliance.name) \(place); the land about it is your alliance's.", .good) }
            if alliance.members.contains(viewer) {
                return Tidings("\(houses[house].title) raises a standard of \(alliance.name) \(place).", .good)
            }
            return Tidings("\(houses[house].title) raises a standard of \(alliance.name) \(place).", .neutral)
        case .standardStruck(let id, let ward, let by, let at):
            // Its striker is told even of a standard since torn down.
            let sworn = standard(id).flatMap { alliance($0.alliance) }
            if by == viewer {
                return Tidings("Your company strikes a standard\(sworn.map { " of \($0.name)" } ?? ""): its ward \(ward) of \(Standard.maximumWard).",
                               .neutral)
            }
            guard let sworn, sworn.members.contains(viewer), houses.indices.contains(by) else { return nil }
            return Tidings("\(houses[by].title) strikes your alliance's standard \(placeName(of: at)): its ward \(ward) of \(Standard.maximumWard).", .bad)
        case .standardTorn(_, let id, let by, let at):
            let name = alliance(id)?.name ?? "a fallen alliance"
            if let by, by == viewer { return Tidings("Your company tears down a standard of \(name).", .good) }
            guard alliance(id)?.members.contains(viewer) == true else {
                return by.map { Tidings("\(houses[$0].title) tears down a standard of \(name) \(placeName(of: at)).", .neutral) }
            }
            guard let by else { return Tidings("A standard of \(name) \(placeName(of: at)) comes down, its House gone from the alliance.", .neutral) }
            return Tidings("\(houses[by].title) tears down your alliance's standard \(placeName(of: at)).", .bad)
        // An alliance's works are told by its name while it stands, and
        // still to those they concern once it is gone.
        case .hallRaised(_, let id, let house, let at):
            guard houses.indices.contains(house) else { return nil }
            let name = alliance(id)?.name ?? "a fallen alliance", place = placeName(of: at)
            if house == viewer {
                return Tidings("You begin the hall of \(name) \(place): it rises over \(AllianceHall.raising) watches.", .good)
            }
            if alliance(id)?.members.contains(viewer) == true {
                return Tidings("\(houses[house].title) begins your alliance's hall \(place): it rises over \(AllianceHall.raising) watches.", .good)
            }
            return Tidings("\(houses[house].title) begins a hall of \(name) \(place).", .neutral)
        case .hallRisen(_, let id, let at):
            guard alliance(id)?.members.contains(viewer) == true else {
                return Tidings("The hall of \(alliance(id)?.name ?? "a fallen alliance") stands whole \(placeName(of: at)).", .neutral)
            }
            return Tidings("Your alliance's hall stands whole \(placeName(of: at)): its land reaches \(AllianceHall.reach) tiles about it, "
                           + "your rallies take \(AllianceHall.rallyCompanies) more companies, and the alliance may keep "
                           + "\(AllianceHall.standards) more standards.", .good)
        case .hallStruck(_, let id, let ward, let by, let at):
            guard houses.indices.contains(by) else { return nil }
            let whole = hall(at: at)?.wardLimit ?? AllianceHall.maximumWard
            if by == viewer {
                return Tidings("Your company strikes the hall of \(alliance(id)?.name ?? "a fallen alliance"): its ward \(ward) of \(whole).", .neutral)
            }
            guard alliance(id)?.members.contains(viewer) == true else { return nil }
            return Tidings("\(houses[by].title) strikes your alliance's hall \(placeName(of: at)): its ward \(ward) of \(whole).", .bad)
        case .hallTorn(_, let id, let by, let at):
            let name = alliance(id)?.name ?? "a fallen alliance"
            if let by, by == viewer { return Tidings("Your company tears down the hall of \(name).", .good) }
            guard alliance(id)?.members.contains(viewer) == true else {
                guard let by else { return Tidings("A hall \(placeName(of: at)) falls into ruin, its alliance no more.", .neutral) }
                return Tidings("\(houses[by].title) tears down the hall of \(name) \(placeName(of: at)).", .neutral)
            }
            guard let by else { return nil }
            return Tidings("\(houses[by].title) tears down your alliance's hall \(placeName(of: at)).", .bad)
        case .storehouseRaised(_, let id, let house, let at):
            guard houses.indices.contains(house) else { return nil }
            let name = alliance(id)?.name ?? "a fallen alliance", place = placeName(of: at)
            if house == viewer {
                return Tidings("You begin the storehouse of \(name) \(place): it rises over \(Storehouse.raising) watches.", .good)
            }
            if alliance(id)?.members.contains(viewer) == true {
                return Tidings("\(houses[house].title) begins your alliance's storehouse \(place): it rises over \(Storehouse.raising) watches.", .good)
            }
            return Tidings("\(houses[house].title) begins a storehouse of \(name) \(place).", .neutral)
        case .storehouseRisen(_, let id, let at):
            guard alliance(id)?.members.contains(viewer) == true else {
                return Tidings("The storehouse of \(alliance(id)?.name ?? "a fallen alliance") stands whole \(placeName(of: at)).", .neutral)
            }
            return Tidings("Your alliance's storehouse stands whole \(placeName(of: at)): lay up your stores there, out of any taker's reach.", .good)
        case .storehouseStruck(_, let id, let ward, let by, let at):
            guard houses.indices.contains(by) else { return nil }
            if by == viewer {
                return Tidings("Your company strikes the storehouse of \(alliance(id)?.name ?? "a fallen alliance"): its ward \(ward) of "
                               + "\(Storehouse.maximumWard).", .neutral)
            }
            guard alliance(id)?.members.contains(viewer) == true else { return nil }
            return Tidings("\(houses[by].title) strikes your alliance's storehouse \(placeName(of: at)): its ward \(ward) of \(Storehouse.maximumWard).", .bad)
        case .storehouseTorn(_, let id, let by, let at, let carried):
            let name = alliance(id)?.name ?? "a fallen alliance"
            if let by, by == viewer {
                let spoils = carried.isZero ? "" : ", and carries off \(carried)"
                return Tidings("Your company tears down the storehouse of \(name)\(spoils).", .good)
            }
            guard alliance(id)?.members.contains(viewer) == true else {
                guard let by else { return Tidings("A storehouse \(placeName(of: at)) falls into ruin, its alliance no more.", .neutral) }
                return Tidings("\(houses[by].title) tears down the storehouse of \(name) \(placeName(of: at)).", .neutral)
            }
            guard let by else { return nil }
            return Tidings("\(houses[by].title) tears down your alliance's storehouse \(placeName(of: at)), and carries off what was laid up in it.", .bad)
        case .laidUp(let house, let stock):
            guard house == viewer else { return nil }
            return Tidings("You lay up \(stock) in your alliance's storehouse.", .neutral)
        case .tookBack(let house, let stock):
            guard house == viewer else { return nil }
            return Tidings("You take back \(stock) from your alliance's storehouse.", .neutral)
        case .yardRaised(_, let id, let house, let store, let at):
            guard houses.indices.contains(house) else { return nil }
            let name = alliance(id)?.name ?? "a fallen alliance", yard = Yard.title(of: store).lowercased()
            if house == viewer {
                return Tidings("You raise a \(yard) for \(name) \(placeName(of: at)): your alliance's companies work it "
                               + "\(Yard.gathering)% faster, and its coffers take a tithe.", .good)
            }
            guard alliance(id)?.members.contains(viewer) == true else { return Tidings("\(houses[house].title) raises a \(yard) for \(name).", .neutral) }
            return Tidings("\(houses[house].title) raises a \(yard) for your alliance \(placeName(of: at)): its companies alone work it, "
                           + "\(Yard.gathering)% faster.", .good)
        case .allianceStudyChosen(let id, let study):
            guard let alliance = alliance(id), alliance.members.contains(viewer) else { return nil }
            let grade = min((alliance.lore?.grade(of: study) ?? 0) + 1, AllianceStudy.grades)
            return Tidings("Your alliance pursues \(study.title) \(BuildingKind.numeral(grade)): \(study.effect(grade: grade)).", .neutral)
        case .allianceGift(let house, let id, let stock, let study, let grade):
            guard alliance(id)?.members.contains(viewer) == true else { return nil }
            let who = house == viewer ? "You give" : "\(houses[house].title) gives"
            return Tidings("\(who) \(stock) toward \(study.title) \(BuildingKind.numeral(grade)).", house == viewer ? .neutral : .good)
        case .allianceStudied(let id, let study, let grade):
            guard alliance(id)?.members.contains(viewer) == true else { return nil }
            return Tidings("Your alliance learns \(study.title) \(BuildingKind.numeral(grade)): \(study.effect(grade: grade)).", .good)
        case .heritageTaken(let house, let heritage):
            guard house == viewer else { return Tidings("\(houses[house].title) takes up the ways of \(heritage.title).", .neutral) }
            return Tidings("Your House takes up the ways of \(heritage.title): \(heritage.strengths[0]), and \(heritage.strengths[1]).", .good)
        case .itemsGiven(let house, let kind, let count):
            guard house == viewer else { return nil }
            return Tidings("Your House gains \(kind.counted(count)): \(kind.effect).", .good)
        case .itemUsed(let house, let kind, let holdID):
            guard house == viewer else { return nil }
            if let holdID { return Tidings("You use a \(kind.title) at \(hold(holdID)?.name ?? "your hold").", .neutral) }
            switch kind {
            case .hourglass: return Tidings("You use a Salt Hourglass on your House's study.", .neutral)
            case .mendingDraught: return Tidings("You share out a Mending Draught: every hurt company of yours mends.", .good)
            default: return Tidings("You open a \(kind.title): \(kind.stores) to your stores.", .good)
            }
        case .lairAssaulted(let assault):
            let lair = "the \(assault.kind.lairTitle) of the \(ordinal(assault.level)) level"
            if assault.houses.contains(viewer) {
                guard assault.broken else {
                    return Tidings("Your host strikes \(lair) for \(assault.dealt); it holds, \(assault.strength) of \(assault.might) still standing.", .neutral)
                }
                let share = assault.shares.first { $0.house == viewer }?.spoils ?? .zero
                return Tidings("Your host breaks \(lair)" + (share.isZero ? "!" : ", and your House carries off \(share)."), .good)
            }
            let host = houses.indices.contains(assault.caller) ? "A host of \(houses[assault.caller].title)" : "A host"
            return Tidings("\(host) " + (assault.broken ? "breaks \(lair)." : "strikes \(lair), but it holds."), .neutral)
        case .woundedLost(let holdID, let house, let count):
            guard house == viewer, let hold = hold(holdID) else { return nil }
            let companies = count == 1 ? "The company" : "The \(count) companies"
            return Tidings("\(companies) in the Infirmary at \(hold.name) are lost with it.", .bad)
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
            // A House taken in is told by its joining; one turned away is
            // told so even once the alliance is no more.
            guard !accepted else { return nil }
            let name = alliance(id)?.name ?? "the alliance"
            if house == viewer { return Tidings("There is no place for you in \(name) now.", .bad) }
            return Tidings("\(houses[house].title) stays outside \(name).", .neutral)
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
            guard let rally = rally(id), let muster = hold(rally.muster), let target = targetName(targetID) else { return nil }
            if caller == viewer { return Tidings("You call a rally at \(muster.name) against \(target).", .neutral) }
            let watches = rally.setsOut - watch
            return Tidings("\(houses[caller].title) calls a rally at \(muster.name) against \(target); "
                + "it sets out in \(watches) watch\(watches == 1 ? "" : "es").", .neutral)
        case .rallyJoined(let id, let unitID, let owner):
            guard let rally = rally(id), let muster = hold(rally.muster), let unit = unit(unitID) else { return nil }
            if owner == viewer { return Tidings("Your \(unit.kind.title) march to the rally at \(muster.name).", .neutral) }
            return Tidings("\(houses[owner].title) sends \(unit.kind.title) to the rally at \(muster.name).", .neutral)
        case .rallySetOut(_, let caller, let targetID, let defender, let companies):
            let target = targetName(targetID) ?? "their hold"
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
