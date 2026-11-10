/// What a commander knows of themself in counsel, and what they may put
/// forward for themself: their level and how far to the next, their stars
/// and what the next asks, the talents learned and the points yet to
/// spend, the talents they may learn now and what each gives, the gear
/// they wear and what the armoury holds unworn. Told as the Mac's
/// Commanders board and the phone's Army tab tell it; and what they put
/// forward is weighed by the rules as every order is, the keeper deciding.
extension CommanderCounsel {
    /// The most talents a look names that the commander may learn now.
    public static let talentsTold = 6
    /// The most of the armoury's unworn pieces a look names.
    public static let piecesTold = 6

    /// What a commander may put forward for themself.
    public static let ownActions = ["learn", "wear", "star", "read"]

    /// Why a commander can't put forward anything else for themself.
    public static let onlyTheseForSelf = "A commander may propose for themself only to learn a talent (by its name), to wear a piece "
        + "of your House's gear (by its name), to raise a star with your House's sculptures, or to read one of its tomes."

    /// A talent as its next rank is named, as the phone offers it: "Thick
    /// Hide II", or "Moonsteel" where it has one rank.
    func nextRankSaid(of talent: Talent) -> String {
        talent.ranks > 1 ? "\(talent.title) \(BuildingKind.numeral(commander.rank(of: talent) + 1))" : talent.title
    }

    /// A talent learned, as its rank stands: "Thick Hide II".
    func learnedSaid(_ talent: Talent) -> String {
        talent.ranks > 1 ? "\(talent.title) \(BuildingKind.numeral(commander.rank(of: talent)))" : talent.title
    }

    /// The commander's standing in a line, for the briefing: "You are of
    /// level 7, 180 experience from level 8, with 2 stars; 1 talent point
    /// yet to spend."
    public var standingSaid: String {
        let level = commander.level
        var told = "You are of level \(level)"
        if level < Commander.highestLevel {
            let more = Commander.experience(forLevel: level + 1) - commander.experience
            told += ", \(GameState.counted(more)) experience from level \(level + 1)"
        }
        told += commander.starCount == 1 ? ", with 1 star" : ", with \(commander.starCount) stars"
        let points = commander.pointsLeft
        return told + (points == 0 ? "; no talent point yet to spend." : points == 1 ? "; 1 talent point yet to spend."
            : "; \(points) talent points yet to spend.")
    }

    /// What the commander knows of themself when they look: their
    /// standing, their next star, their talents and what they may learn
    /// now, what they wear and what the armoury holds unworn.
    public var selfReport: String {
        var lines = [standingSaid]
        // As the phone's line for them says it: "Stars: 2 of 5 · Next star: 20 sculptures, 12 kept".
        lines.append("Stars: \(commander.starCount) of \(Commander.mostStars) · \(commander.starsSaid(kept: state.sculptures(of: player))).")
        let learned = (commander.talents ?? []).reduce(into: [Talent]()) { if !$0.contains($1) { $0.append($1) } }
        lines.append(learned.isEmpty ? "You have learned no talent yet."
            : "Your talents: " + learned.map(learnedSaid).joined(separator: ", ") + ".")
        let open = Talent.allCases.filter { commander.learnRefusal(of: $0) == nil }
        if !open.isEmpty {
            let named = open.prefix(CommanderCounsel.talentsTold).map { "\(nextRankSaid(of: $0)) (\(commander.effectSaid(of: $0)))" }
            lines.append("Talents you may learn now: " + named.joined(separator: "; ")
                         + (open.count > CommanderCounsel.talentsTold ? "; and \(open.count - CommanderCounsel.talentsTold) more." : "."))
        }
        let worn = state.worn(by: commander.id).sorted { $0.slot.rawValue < $1.slot.rawValue }
        lines.append(worn.isEmpty ? "You wear no gear."
            : "You wear: " + worn.map { "\($0.wornSaid) (\($0.effect))" }.joined(separator: "; ") + ".")
        let unworn = state.gear(of: player).filter { $0.wornBy == nil }
            .sorted { ($0.quality.rawValue, -$0.id) > ($1.quality.rawValue, -$1.id) }
        // The House's tomes, while it keeps any: what reading one would bring.
        let tomes = state.items(.tome, of: player)
        if tomes > 0 {
            lines.append("Your House keeps \(ItemKind.tome.counted(tomes)); reading one gives \(GameState.tomeExperience) experience.")
        }
        if unworn.isEmpty {
            lines.append("Your House's armoury holds no piece unworn.")
        } else {
            let named = unworn.prefix(CommanderCounsel.piecesTold).map { "\($0.keptSaid) (\($0.effect))" }
            lines.append("Your House's armoury holds, unworn: " + named.joined(separator: "; ")
                         + (unworn.count > CommanderCounsel.piecesTold ? "; and \(unworn.count - CommanderCounsel.piecesTold) more." : "."))
        }
        return lines.joined(separator: " ")
    }

    /// A name as it is matched: in small letters, without "the" before it
    /// or a rank's numeral after it.
    static func plainName(_ name: String) -> String {
        var words = SpokenOrders.plain(name).split(separator: " ").map(String.init)
        if let last = words.last, words.count > 1, ["i", "ii", "iii", "iv", "v"].contains(last) { words.removeLast() }
        return words.joined(separator: " ")
    }

    /// Something put to the keeper for the commander themself, weighed as
    /// the realm weighs every order: a talent's next rank learned, a piece
    /// of the House's gear taken up (from the armoury, or from another
    /// commander, said so), or a star raised with the House's sculptures;
    /// given if the realm would take it, or told why not.
    public func proposeForSelf(_ action: String, what: String) -> CounselProposal {
        let verb = SpokenOrders.plain(action)
        let asked = what.trimmingCharacters(in: .whitespacesAndNewlines)
        func weighed(_ line: String, _ command: Command, _ told: String) -> CounselProposal {
            CounselProposal(line: line, told: told, command: command, why: state.refusal(of: command, as: player)?.description)
        }
        switch verb {
        case "learn", "learn a talent":
            guard let talent = Talent.allCases.first(where: { CommanderCounsel.plainName($0.title) == CommanderCounsel.plainName(asked) }) else {
                return CounselProposal(line: "LEARN \(asked)", told: "learn \(asked)", command: nil,
                                       why: "No talent goes by the name \(asked).")
            }
            let named = nextRankSaid(of: talent)
            return weighed("LEARN \(named)", .learnTalent(commander: commander.id, talent: talent), "\(commander.name) learns \(named).")
        case "wear", "take up", "arm":
            let wanted = CommanderCounsel.plainName(asked)
            // The finest of that name, unworn before another's; one's own
            // already worn last, for the realm to say so.
            let pieces = state.gear(of: player).filter {
                CommanderCounsel.plainName($0.title) == wanted || CommanderCounsel.plainName($0.kind.title) == wanted
            }
            func rank(_ piece: Gear) -> (Int, Int, Int, Int) {
                (piece.wornBy == commander.id ? 0 : 1, piece.wornBy == nil ? 1 : 0, piece.quality.rawValue, -piece.id)
            }
            guard let piece = pieces.max(by: { rank($0) < rank($1) }) else {
                return CounselProposal(line: "WEAR \(asked)", told: "wear \(asked)", command: nil,
                                       why: "Your House holds no gear by the name \(asked).")
            }
            let from = piece.wornBy.flatMap { $0 == commander.id ? nil : state.commander($0)?.name }.map { ", taken from \($0)" } ?? ""
            return weighed("WEAR \(piece.title)", .wear(gear: piece.id, commander: commander.id),
                           "\(commander.name) takes up the \(piece.title)\(from).")
        case "read", "read a tome", "tome", "read tome":
            return weighed("READ A TOME", .readTome(commander: commander.id),
                           "\(commander.name) reads a \(ItemKind.tome.title): \(GameState.tomeExperience) experience.")
        case "star", "raise a star", "raise", "stars":
            let next = commander.starCount + 1
            let cost = Commander.sculpturesToRaise(from: commander.starCount).map { " for \($0) sculptures" } ?? ""
            return weighed("RAISE A STAR", .raiseStar(commander: commander.id),
                           "\(commander.name) is raised to \(min(next, Commander.mostStars)) stars\(cost).")
        default:
            return CounselProposal(line: "\(action) \(asked)", told: "\(action) \(asked)", command: nil, why: CommanderCounsel.onlyTheseForSelf)
        }
    }
}
