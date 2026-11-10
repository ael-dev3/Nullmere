import Foundation

/// What a commander knows of the House's holds in counsel, and what they
/// may put forward there: each hold's work and muster under way, its works,
/// and what it may raise or muster now and for what, told as the holds'
/// panels tell the keeper; a work raised a level or a company mustered put
/// forward as the order book reads BUILD <work> AT <hold> and TRAIN <kind>
/// AT <hold>, weighed by the rules as every order is, the keeper deciding.
extension CommanderCounsel {
    /// The most holds a look tells, the seat first, then the rest as the
    /// House came by them.
    public static let holdsTold = 4

    /// What a commander may put forward at a hold of the House.
    public static let holdActions = ["raise", "muster"]

    /// Why a commander can't put forward anything else at a hold.
    public static let onlyTheseForHolds = "A commander may propose at a hold of your House only to raise a work there a level "
        + "(raise, naming the work) or to muster a company there (muster, naming its kind), naming the hold."

    /// What the House's holds are about, as their panels tell the keeper:
    /// each by its name, the seat first; what it raises and musters now and
    /// how long each has to go; its works at their levels; and the works it
    /// may raise a level now and the companies it may muster now, each for
    /// what it costs, as the rules would take them.
    public var holdsReport: String {
        guard state.houses.indices.contains(player), !state.houses[player].isEliminated else { return "Your House has fallen." }
        let holds = state.holds(of: player).sorted { ($0.isSeat ? 0 : 1, $0.id) < ($1.isSeat ? 0 : 1, $1.id) }
        guard !holds.isEmpty else { return "Your House holds no hold." }
        var lines = holds.prefix(Self.holdsTold).map(holdSaid)
        let more = holds.count - Self.holdsTold
        if more > 0 { lines.append(more == 1 ? "And 1 more hold besides." : "And \(GameState.counted(more)) more holds besides.") }
        return lines.joined(separator: "\n")
    }

    /// A hold as a look tells it: "Wenholme, your seat: raising its Archive
    /// to II, 2 watches to go. Its works: Granary I, Archive I. It may
    /// muster now: Spears I (40 grain, 10 timber)."
    func holdSaid(_ hold: Hold) -> String {
        let head = hold.isSeat ? "\(hold.name), your seat" : hold.name
        var doing: [String] = []
        if let project = hold.project {
            doing.append("raising its \(project.kind.title) to \(BuildingKind.numeral(project.targetLevel)), "
                         + "\(GameState.watches(project.watchesLeft)) to go")
        }
        if let training = hold.training {
            doing.append("mustering \(state.named(training.kind, tier: training.musteredTier, of: player)), "
                         + "\(GameState.watches(training.watchesLeft)) to go")
        }
        var said = doing.isEmpty ? "\(head), idle." : "\(head): " + doing.joined(separator: "; ") + "."
        let works = BuildingKind.allCases.filter { hold.level($0) > 0 }.map { "\($0.title) \(BuildingKind.numeral(hold.level($0)))" }
        said += works.isEmpty ? " No works yet." : " Its works: " + works.joined(separator: ", ") + "."
        if hold.project == nil {
            let raisable = BuildingKind.allCases.filter { state.refusal(of: .build(hold: hold.id, kind: $0), as: player) == nil }.map { kind in
                let level = hold.level(kind) + 1
                return "\(kind.title) \(BuildingKind.numeral(level)) (\(state.buildCost(of: kind, toLevel: level, for: player).description))"
            }
            said += raisable.isEmpty ? " It may raise nothing now." : " It may raise now: " + raisable.joined(separator: ", ") + "."
        }
        if hold.training == nil {
            // Each kind at the tier it would be mustered at now, as the phone offers it.
            let musters = UnitKind.allCases.compactMap { kind -> String? in
                guard let tier = state.musterTier(of: kind, at: hold, for: player) else { return nil }
                return "\(state.named(kind, tier: tier, of: player)) (\(state.trainingCost(of: kind, tier: tier, for: player).description))"
            }
            said += musters.isEmpty ? " It may muster nothing now." : " It may muster now: " + musters.joined(separator: ", ") + "."
        }
        return said
    }

    /// A work raised a level or a company mustered at a hold of the House,
    /// put to the keeper, read and weighed as the order book weighs a line.
    public func proposeForAHold(_ action: String, hold: String, what: String) -> CounselProposal {
        let verb = action.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let at = hold.trimmingCharacters(in: .whitespacesAndNewlines)
        let named = what.trimmingCharacters(in: .whitespacesAndNewlines)
        let line: String
        switch verb {
        case "raise", "build": line = "BUILD \(named) AT \(at)"
        case "muster", "train": line = "TRAIN \(named) AT \(at)"
        default:
            let said = "\(action) \(named) at \(at)"
            return CounselProposal(line: said, told: said, command: nil, why: CommanderCounsel.onlyTheseForHolds)
        }
        guard !at.isEmpty, !named.isEmpty else {
            return CounselProposal(line: line, told: line, command: nil,
                                   why: "That wants the hold, and the work to raise or the kind of company to muster there.")
        }
        guard let read = SpokenOrders.read(line: line, in: state, player: player) else {
            return CounselProposal(line: line, told: line, command: nil, why: "The order book has no such line.")
        }
        return CounselProposal(line: line, told: read.told, command: read.command, why: read.why)
    }
}
