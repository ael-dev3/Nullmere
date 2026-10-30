import Foundation

/// Houses sworn together under one banner and one leader: they can't make
/// war on each other, they see what each other sees, and they hasten each
/// other's works.
public struct Alliance: Codable, Equatable, Identifiable, Sendable {
    public let id: Int
    public let name: String
    public internal(set) var leader: Int
    /// Its Houses, in the order they joined: the leader among them.
    public internal(set) var members: [Int]
    public let founded: Int
    /// Houses its leader has invited, awaiting their answer.
    public internal(set) var invited: [Int]
    /// Houses asking to join, awaiting its leader's answer.
    public internal(set) var asking: [Int]
    /// What it has learned together, and what its Houses have given toward
    /// what it pursues; absent before its leader chose a study.
    public internal(set) var lore: AllianceLore?
    /// What it keeps of its own, filled by its land and its yards and spent
    /// first on what its Houses raise for it; absent before it had any.
    public internal(set) var coffers: Stock?

    public init(id: Int, name: String, leader: Int, founded: Int) {
        self.id = id
        self.name = name
        self.leader = leader
        self.members = [leader]
        self.founded = founded
        self.invited = []
        self.asking = []
    }

    /// Whether a name will do for an alliance: two to twenty-four letters,
    /// spaces, hyphens or apostrophes, beginning and ending with a letter.
    public static func isValidName(_ name: String) -> Bool {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        guard (2...24).contains(trimmed.count), trimmed.unicodeScalars.count <= 48,
              trimmed.first?.isLetter == true, trimmed.last?.isLetter == true else { return false }
        return trimmed.allSatisfy { $0.isLetter || $0 == " " || $0 == "-" || $0 == "'" }
    }

    /// Names the stewards raise their banners under.
    static let stewardNames = [
        "the Still Accord", "the Pale Compact", "the Moonward League", "the Ninefold Oath", "the Grey Covenant",
        "the Saltbound Pact", "the Lantern Concord", "the Barrow Fellowship", "the Shorewatch", "the Quiet Banner",
    ]
}

extension GameState {
    /// Every alliance standing.
    public var alliancesStanding: [Alliance] { alliances ?? [] }

    public func alliance(_ id: Int) -> Alliance? {
        alliances?.first { $0.id == id }
    }

    /// The alliance a House is sworn to, if any.
    public func alliance(of house: Int) -> Alliance? {
        alliances?.first { $0.members.contains(house) }
    }

    /// Whether two Houses are sworn to the same alliance.
    public func areAllied(_ a: Int, _ b: Int) -> Bool {
        a != b && alliance(of: a).map { $0.members.contains(b) } == true
    }

    /// The most Houses an alliance takes: a third of the lake's seats, and
    /// never fewer than two.
    public var allianceLimit: Int { max(2, houses.count / 3) }

    private func allianceIndex(_ id: Int) -> Int? {
        alliances?.firstIndex { $0.id == id }
    }

    /// Why a House can't join an alliance now, if it can't.
    func joinRefusal(of house: Int, to alliance: Alliance) -> RuleError? {
        if self.alliance(of: house) != nil { return .inAnAlliance }
        if let foe = alliance.members.first(where: { isAtWar(house, $0) }) { return .atWarWithAMember(foe) }
        if alliance.members.count >= allianceLimit { return .allianceFull }
        return nil
    }

    // MARK: Founding, joining, leaving

    mutating func foundAlliance(named name: String, by house: Int) throws(RuleError) -> [GameEvent] {
        guard alliance(of: house) == nil else { throw .inAnAlliance }
        let chosen = name.trimmingCharacters(in: .whitespaces)
        guard Alliance.isValidName(chosen) else { throw .allianceNameInvalid }
        guard !alliancesStanding.contains(where: { $0.name.lowercased() == chosen.lowercased() }) else { throw .allianceNameTaken }
        let alliance = Alliance(id: takeID(), name: chosen, leader: house, founded: watch)
        alliances = alliancesStanding + [alliance]
        // A House asking elsewhere asks no longer.
        withdrawAsking(of: house)
        record(.alliance, [house], "\(houses[house].title) raises a banner: \(chosen).")
        return [.allianceFounded(alliance: alliance.id, house: house)]
    }

    mutating func invite(_ target: Int, by house: Int) throws(RuleError) -> [GameEvent] {
        guard let alliance = alliance(of: house) else { throw .notInAlliance }
        guard alliance.leader == house else { throw .notAllianceLeader }
        guard target != house, let other = self.house(target), !other.isEliminated else { throw .unknownHouse }
        if let refusal = joinRefusal(of: target, to: alliance) { throw refusal }
        guard !alliance.invited.contains(target) else { throw .alreadyInvited }
        var events: [GameEvent] = [.allianceInvited(alliance: alliance.id, house: target)]
        if houses[target].isPlayer {
            alliances![allianceIndex(alliance.id)!].invited.append(target)
            return events
        }
        let accepted = RivalMind(house: target).acceptsInvitation(to: alliance, in: self)
        events.append(.allianceAnswered(alliance: alliance.id, house: target, accepted: accepted))
        if accepted { events += join(target, to: alliance.id) }
        return events
    }

    mutating func askToJoin(_ allianceID: Int, by house: Int) throws(RuleError) -> [GameEvent] {
        guard let alliance = alliance(allianceID) else { throw .unknownAlliance }
        if let refusal = joinRefusal(of: house, to: alliance) { throw refusal }
        guard !alliance.asking.contains(house) else { throw .alreadyAsked }
        var events: [GameEvent] = [.allianceAsked(alliance: allianceID, house: house)]
        if houses[alliance.leader].isPlayer {
            alliances![allianceIndex(allianceID)!].asking.append(house)
            return events
        }
        let accepted = RivalMind(house: alliance.leader).acceptsMember(house, to: alliance, in: self)
        events.append(.allianceAnswered(alliance: allianceID, house: house, accepted: accepted))
        if accepted { events += join(house, to: allianceID) }
        return events
    }

    /// An invited House answers its invitation.
    mutating func answerInvitation(_ allianceID: Int, accept: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let index = allianceIndex(allianceID), alliances![index].invited.contains(house) else { throw .noInvitation }
        alliances![index].invited.removeAll { $0 == house }
        let alliance = alliances![index]
        let accepted = accept && joinRefusal(of: house, to: alliance) == nil
        var events: [GameEvent] = [.allianceAnswered(alliance: allianceID, house: house, accepted: accepted)]
        if accepted { events += join(house, to: allianceID) }
        return events
    }

    /// An alliance's leader answers a House asking to join.
    mutating func answerRequest(of asker: Int, accept: Bool, as house: Int) throws(RuleError) -> [GameEvent] {
        guard let alliance = alliance(of: house), alliance.leader == house, alliance.asking.contains(asker),
              let index = allianceIndex(alliance.id) else { throw .noRequest }
        alliances![index].asking.removeAll { $0 == asker }
        let accepted = accept && joinRefusal(of: asker, to: alliances![index]) == nil
        var events: [GameEvent] = [.allianceAnswered(alliance: alliance.id, house: asker, accepted: accepted)]
        if accepted { events += join(asker, to: alliance.id) }
        return events
    }

    private mutating func join(_ house: Int, to allianceID: Int) -> [GameEvent] {
        guard let index = allianceIndex(allianceID) else { return [] }
        alliances![index].members.append(house)
        alliances![index].invited.removeAll { $0 == house }
        alliances![index].asking.removeAll { $0 == house }
        withdrawAsking(of: house)
        // No other alliance waits on it, nor it on another.
        for other in alliances!.indices where other != index {
            alliances![other].invited.removeAll { $0 == house }
        }
        let name = alliances![index].name
        record(.alliance, [house, alliances![index].leader], "\(houses[house].title) joins \(name).")
        return [.allianceJoined(alliance: allianceID, house: house)]
    }

    private mutating func withdrawAsking(of house: Int) {
        guard alliances != nil else { return }
        for index in alliances!.indices {
            alliances![index].asking.removeAll { $0 == house }
        }
    }

    /// A fallen House is invited nowhere and asks nowhere.
    mutating func forgetInvitations(of house: Int) {
        guard alliances != nil else { return }
        for index in alliances!.indices {
            alliances![index].invited.removeAll { $0 == house }
            alliances![index].asking.removeAll { $0 == house }
        }
    }

    mutating func leaveAlliance(as house: Int) throws(RuleError) -> [GameEvent] {
        guard let alliance = alliance(of: house) else { throw .notInAlliance }
        record(.alliance, [house], "\(houses[house].title) leaves \(alliance.name).")
        return [.allianceLeft(alliance: alliance.id, house: house, expelled: false)] + part(house, from: alliance.id)
    }

    mutating func expel(_ target: Int, by house: Int) throws(RuleError) -> [GameEvent] {
        guard let alliance = alliance(of: house) else { throw .notInAlliance }
        guard alliance.leader == house else { throw .notAllianceLeader }
        guard target != house, alliance.members.contains(target) else { throw .notAMember }
        record(.alliance, [target, house], "\(houses[house].title) casts \(houses[target].title) out of \(alliance.name).")
        return [.allianceLeft(alliance: alliance.id, house: target, expelled: true)] + part(target, from: alliance.id)
    }

    /// A House goes from its alliance, by its will, its leader's, or its
    /// fall: a leader gone leaves the banner to the strongest still sworn,
    /// and an alliance left with none is no more.
    mutating func part(_ house: Int, from allianceID: Int) -> [GameEvent] {
        guard let index = allianceIndex(allianceID) else { return [] }
        // Its rallies lose the room their alliance's hall gave them.
        defer { fitRallies() }
        // What it laid up in the alliance's storehouse goes with it.
        returnLaidUp(of: house, from: allianceID)
        alliances![index].members.removeAll { $0 == house }
        let alliance = alliances![index]
        guard !alliance.members.isEmpty else {
            alliances!.remove(at: index)
            record(.alliance, [], "\(alliance.name) is no more.")
            return [.allianceDisbanded(alliance: allianceID, name: alliance.name)]
        }
        guard alliance.leader == house else { return [] }
        let heir = alliance.members.max { (strength(of: $0), -$0) < (strength(of: $1), -$1) }!
        alliances![index].leader = heir
        alliances![index].invited = []
        record(.alliance, [heir], "\(houses[heir].title) takes up the banner of \(alliance.name).")
        return [.allianceLed(alliance: allianceID, house: heir)]
    }

    // MARK: Help

    /// Helps a work, a muster or a study had of a House: one from each ally.
    public static let helpsPerWatch = 2

    /// The works, musters and study of an ally's a House could still help.
    public func helpable(by helper: Int, for house: Int) -> Int {
        guard areAllied(helper, house) else { return 0 }
        var count = 0
        for hold in holds(of: house) {
            if let project = hold.project, !(project.helpers ?? []).contains(helper) { count += 1 }
            if let training = hold.training, !(training.helpers ?? []).contains(helper) { count += 1 }
        }
        if let pursuit = houses[house].research.pursuit, !(pursuit.helpers ?? []).contains(helper) { count += 1 }
        return count
    }

    /// A House helps every work, muster and study of an ally's it hasn't yet:
    /// every second help on one takes a watch off it, never its last.
    mutating func help(_ ally: Int, by house: Int) throws(RuleError) -> [GameEvent] {
        guard areAllied(house, ally) else { throw .notAnAlly }
        let count = helpable(by: house, for: ally)
        guard count > 0 else { throw .nothingToHelp }
        func hasten(_ helpers: inout [Int]?, _ watchesLeft: inout Int) {
            helpers = (helpers ?? []) + [house]
            if helpers!.count % GameState.helpsPerWatch == 0, watchesLeft > 1 { watchesLeft -= 1 }
        }
        for index in holds.indices where holds[index].owner == ally {
            if var project = holds[index].project, !(project.helpers ?? []).contains(house) {
                hasten(&project.helpers, &project.watchesLeft)
                holds[index].project = project
            }
            if var training = holds[index].training, !(training.helpers ?? []).contains(house) {
                hasten(&training.helpers, &training.watchesLeft)
                holds[index].training = training
            }
        }
        if var pursuit = houses[ally].research.pursuit, !(pursuit.helpers ?? []).contains(house) {
            hasten(&pursuit.helpers, &pursuit.watchesLeft)
            houses[ally].research.pursuit = pursuit
        }
        return [.helpGiven(by: house, to: ally, count: count)]
    }
}
