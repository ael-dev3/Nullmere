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
        default:
            return nil
        }
    }

    /// A study and its grade as the game writes it: "Furrow Lore II", "Drill".
    public static func graded(_ study: Study, _ grade: Int) -> String {
        study.grades > 1 ? "\(study.title) \(BuildingKind.numeral(grade))" : study.title
    }
}
