import Foundation

// What a House's screens show of the realm's depth, worked out from the
// rules alone: the interface draws each board as it is, and every line of
// it is tried here. Asked of a keeper's view, a board rests only on what
// their House knows.

// MARK: The Archive

/// A study as the Archive's board shows it to a House.
public struct StudyLine: Equatable, Sendable, Identifiable {
    /// Where a study stands for the House.
    public enum Standing: Equatable, Sendable {
        /// Known to its last grade.
        case mastered
        /// The House's study under way, toward its next grade.
        case underWay(watchesLeft: Int)
        /// Could be begun now.
        case open
        /// Could be begun but for stores: what they lack.
        case short(Stock)
        /// Could be begun once the study under way is done.
        case waiting
        /// Not yet: why not.
        case locked(RuleError)
    }

    public var id: Study { study }
    public let study: Study
    /// The grade known; zero if none.
    public let grade: Int
    /// What the next grade costs and takes; nil once the study is mastered.
    public let price: Stock?
    public let watches: Int?
    public let standing: Standing

    /// The grade it would reach next, if there is one.
    public var next: Int? { grade < study.grades ? grade + 1 : nil }
}

/// A branch of the tree, its studies in the tree's order.
public struct StudyShelf: Equatable, Sendable, Identifiable {
    public var id: Branch { branch }
    public let branch: Branch
    public let lines: [StudyLine]
}

/// What a House's Archive shows: the tree of studies, each as it stands.
public struct ArchiveBoard: Equatable, Sendable {
    /// The House's highest Archive; studies of a circle need one as high.
    public let archive: Int
    /// The study under way, if any.
    public let pursuit: Pursuit?
    public let shelves: [StudyShelf]
    /// Grades learned, in all.
    public let learned: Int

    /// Grades there are to learn, in all.
    public static let gradesInAll = Study.allCases.reduce(0) { $0 + $1.grades }

    /// A study's line.
    public func line(_ study: Study) -> StudyLine? {
        shelves.lazy.flatMap(\.lines).first { $0.study == study }
    }
}

extension GameState {
    /// A House's tree of studies, each as it stands for the House.
    public func archiveBoard(for house: Int) -> ArchiveBoard {
        let known = houses.indices.contains(house)
        let research = known ? houses[house].research : Research()
        let stock = known ? houses[house].stock : .zero
        let archive = archiveLevel(of: house)
        func line(_ study: Study) -> StudyLine {
            let grade = research.grade(of: study)
            guard grade < study.grades else {
                return StudyLine(study: study, grade: grade, price: nil, watches: nil, standing: .mastered)
            }
            let price = studyPrice(of: study, grade: grade + 1, for: house)
            let standing: StudyLine.Standing
            if let pursuit = research.pursuit, pursuit.study == study {
                standing = .underWay(watchesLeft: pursuit.watchesLeft)
            } else if archive < study.circle {
                standing = .locked(.needsArchive(study.circle))
            } else if let missing = study.needs.first(where: { research.grade(of: $0.study) < $0.grade }) {
                standing = .locked(.needsStudy(missing.study, missing.grade))
            } else if research.pursuit != nil {
                standing = .waiting
            } else if !stock.covers(price) {
                standing = .short(stock.shortfall(for: price))
            } else {
                standing = .open
            }
            return StudyLine(study: study, grade: grade, price: price,
                             watches: studyWatches(of: study, grade: grade + 1, for: house), standing: standing)
        }
        return ArchiveBoard(archive: archive, pursuit: research.pursuit,
                            shelves: Branch.allCases.map { StudyShelf(branch: $0, lines: Study.of($0).map(line)) },
                            learned: research.known.reduce(0) { $0 + $1.grade })
    }
}

// MARK: Commanders

/// One of a commander's four skills, and whether it has come to it yet.
public struct SkillLine: Equatable, Sendable, Identifiable {
    public var id: Skill { skill }
    public let skill: Skill
    public let isKnown: Bool
}

/// A commander as its House's board shows it.
public struct CommanderLine: Equatable, Sendable, Identifiable {
    public var id: Int { commander.id }
    public let commander: Commander
    public let level: Int
    /// Experience gained since its level began, and what the next level
    /// asks in all from there; nil at the highest level.
    public let progress: Int
    public let span: Int?
    public let skills: [SkillLine]
    /// The company it leads, if it leads one.
    public let leads: Unit?
    /// Watches before it is whole again, if it is wounded.
    public let woundedFor: Int?
    /// Its active skill fires in its company's next battle.
    public let furyReady: Bool
}

/// A House's commanders, the most it keeps, and when another comes.
public struct CommandersBoard: Equatable, Sendable {
    public let lines: [CommanderLine]
    public let limit: Int

    public func line(_ commander: Int) -> CommanderLine? {
        lines.first { $0.commander.id == commander }
    }
}

extension GameState {
    /// A House's commanders: the free ones first, then those at the head
    /// of a company, then the wounded; each in the order it came.
    public func commandersBoard(for house: Int) -> CommandersBoard {
        let lines = commanders(of: house).map { commander -> CommanderLine in
            let level = commander.level
            let floor = Commander.experience(forLevel: level)
            let leads = company(ledBy: commander.id)
            let wounded = commander.isWounded(at: watch) ? (commander.woundedUntil ?? watch) - watch : nil
            return CommanderLine(
                commander: commander, level: level, progress: commander.experience - floor,
                span: level < Commander.highestLevel ? Commander.experience(forLevel: level + 1) - floor : nil,
                skills: commander.archetype.skills.map { SkillLine(skill: $0, isKnown: $0.unlock <= level) },
                leads: leads, woundedFor: wounded, furyReady: leads.flatMap { furyReady(of: $0) } != nil)
        }
        func rank(_ line: CommanderLine) -> Int { line.woundedFor != nil ? 2 : line.leads != nil ? 1 : 0 }
        let ordered = lines.enumerated().sorted { (rank($0.element), $0.offset) < (rank($1.element), $1.offset) }.map(\.element)
        return CommandersBoard(lines: ordered, limit: GameState.rosterLimit)
    }
}

// MARK: Alliances

/// A House of the alliance, as its fellows see it.
public struct AllyLine: Equatable, Sendable, Identifiable {
    public var id: Int { house }
    public let house: Int
    public let isLeader: Bool
    public let might: Int
    /// Its works, musters and study the viewing House could still help.
    public let helpable: Int
}

/// Another alliance, and why the House couldn't ask to join it, if it couldn't.
public struct AllianceLine: Equatable, Sendable, Identifiable {
    public var id: Int { alliance.id }
    public let alliance: Alliance
    public let refusal: RuleError?
}

/// A rally of the House's side, gathering or on the march.
public struct RallyLine: Equatable, Sendable, Identifiable {
    public var id: Int { rally.id }
    public let rally: Rally
    /// Watches before it sets out; zero once it has.
    public let watchesLeft: Int
    /// Companies sent to it, and the most it takes.
    public let companies: Int
    public let capacity: Int
    /// The House called it.
    public let isCaller: Bool
}

/// A House's standing among the alliances: its own and its fellows, what
/// awaits an answer, and its side's rallies.
public struct AllianceBoard: Equatable, Sendable {
    /// The alliance it is sworn to, if any.
    public let alliance: Alliance?
    public let isLeader: Bool
    /// The alliance's Houses, the leader first, then in the order they joined.
    public let members: [AllyLine]
    /// Alliances that have invited the House.
    public let invitations: [Alliance]
    /// The other alliances standing.
    public let others: [AllianceLine]
    /// Houses asking to join, for the leader to answer.
    public let asking: [Int]
    /// Houses the leader could invite.
    public let invitable: [Int]
    public let rallies: [RallyLine]
    /// The most Houses an alliance takes.
    public let limit: Int
}

extension GameState {
    /// What the alliances are to a House.
    public func allianceBoard(for house: Int) -> AllianceBoard {
        let own = alliance(of: house)
        let isLeader = own?.leader == house
        let members = own.map { alliance in
            ([alliance.leader] + alliance.members.filter { $0 != alliance.leader }).map { member in
                AllyLine(house: member, isLeader: member == alliance.leader, might: might(of: member),
                         helpable: member == house ? 0 : helpable(by: house, for: member))
            }
        } ?? []
        let others = alliancesStanding.filter { $0.id != own?.id }.map { alliance in
            AllianceLine(alliance: alliance,
                         refusal: joinRefusal(of: house, to: alliance) ?? (alliance.asking.contains(house) ? .alreadyAsked : nil))
        }
        let invitable: [Int] = own.map { (alliance: Alliance) -> [Int] in
            guard isLeader else { return [] }
            return houses.filter { other in
                other.id != house && !other.isEliminated && !alliance.invited.contains(other.id)
                    && joinRefusal(of: other.id, to: alliance) == nil
            }.map(\.id)
        } ?? []
        let rallies = ralliesStanding.filter { isOfRally(house, $0) }.map { rally in
            RallyLine(rally: rally, watchesLeft: max(rally.setsOut - watch, 0),
                      companies: rally.companies.filter { unit($0)?.errand == .rally(rally.id) }.count,
                      capacity: capacity(of: rally), isCaller: rally.caller == house)
        }
        return AllianceBoard(alliance: own, isLeader: isLeader, members: members,
                             invitations: alliancesStanding.filter { $0.invited.contains(house) }, others: others,
                             asking: isLeader ? own?.asking ?? [] : [], invitable: invitable, rallies: rallies,
                             limit: allianceLimit)
    }
}

// MARK: The realm's course

/// A House's place in a happening.
public struct Placing: Equatable, Sendable, Identifiable {
    public var id: Int { house }
    public let house: Int
    public let points: Int
}

/// The realm as a House stands in it: the happening under way or the next
/// to come, the charges set it, its deeds, and its might among the Houses.
public struct RealmBoard: Equatable, Sendable {
    public let happening: Happening?
    /// The House's points in the happening under way, and marks passed.
    public let points: Int
    public let marksPassed: Int
    /// The foremost in it, with their points.
    public let foremost: [Placing]
    /// The House's place among those with points, from one.
    public let place: Int?
    /// When the next happening begins, and what it is, if none is under way.
    public let nextBegins: Int?
    public let nextKind: HappeningKind?
    /// The charge before the House, if any are left, and how many it has kept.
    public let charge: Charge?
    public let chargesKept: Int
    /// Deeds done, in the order they were done, and those still to do.
    public let deeds: [Deed]
    public let deedsLeft: [Deed]
    public let might: Int
    /// The House's place by might among the Houses standing, from one.
    public let mightPlace: Int?

    /// Points at the next mark, if any are left.
    public var nextMark: Int? {
        Happening.marks.indices.contains(marksPassed) ? Happening.marks[marksPassed] : nil
    }
}

extension GameState {
    /// The watch the next happening begins, after this one.
    public var nextHappeningWatch: Int {
        guard watch >= Happening.first else { return Happening.first }
        return Happening.first + ((watch - Happening.first) / Happening.every + 1) * Happening.every
    }

    /// The realm's course as a House stands in it.
    public func realmBoard(for house: Int) -> RealmBoard {
        let points = happening.flatMap { $0.points.indices.contains(house) ? $0.points[house] : nil } ?? 0
        let passed = happening.flatMap { $0.passed.indices.contains(house) ? $0.passed[house] : nil } ?? 0
        let leaderboard = happening?.leaderboard ?? []
        let next = happening == nil ? nextHappeningWatch : nil
        let done = deeds(of: house)
        let current = self.charge(of: house)
        return RealmBoard(
            happening: happening, points: points, marksPassed: passed,
            foremost: leaderboard.prefix(5).map { Placing(house: $0, points: happening!.points[$0]) },
            place: leaderboard.firstIndex(of: house).map { $0 + 1 },
            nextBegins: next,
            nextKind: next.flatMap(Happening.number(beginningAt:)).map { Happening.kind(number: $0, seed: settings.seed) },
            charge: current, chargesKept: current?.rawValue ?? Charge.allCases.count,
            deeds: done, deedsLeft: Deed.allCases.filter { !done.contains($0) },
            might: might(of: house), mightPlace: byMight.firstIndex(of: house).map { $0 + 1 })
    }
}
