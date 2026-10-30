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
        default:
            return nil
        }
    }

    /// A study and its grade as the game writes it: "Furrow Lore II", "Drill".
    public static func graded(_ study: Study, _ grade: Int) -> String {
        study.grades > 1 ? "\(study.title) \(BuildingKind.numeral(grade))" : study.title
    }
}
