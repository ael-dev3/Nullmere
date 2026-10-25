import NullmereCore

/// Turns what happened into short lines for the player, from the player's
/// side: only what they did, what was done to them, and what the whole
/// lake would hear of.
enum Narration {
    struct Line {
        let text: String
        let tone: GameSession.Notice.Tone
    }

    static func roman(_ number: Int) -> String {
        ["", "I", "II", "III", "IV", "V", "VI"][min(max(number, 0), 6)]
    }

    static func line(for event: GameEvent, in state: GameState, viewer: Int) -> Line? {
        func house(_ id: Int) -> String { state.houses[id].title }
        func holdName(_ id: Int) -> String { state.hold(id)?.name ?? "a hold" }

        switch event {
        case .moved, .trainingStarted:
            return nil
        case .battle(let battle):
            guard battle.attackerOwner == viewer || battle.defenderOwner == viewer else { return nil }
            let target = battle.defenderKind.map { "\(house(battle.defenderOwner))'s \($0.title)" }
                ?? (battle.hold.map(holdName) ?? "the hold")
            if battle.attackerOwner == viewer {
                let outcome = battle.defenderFell ? (battle.defenderKind == nil ? "; its ward breaks" : "; they fall") : ""
                return Line(text: "Your \(battle.attackerKind.title) strike \(target) for \(battle.damageDealt)\(outcome).", tone: battle.attackerFell ? .bad : .good)
            }
            let what = battle.defenderKind.map { "your \($0.title)" } ?? (battle.hold.map(holdName) ?? "your hold")
            return Line(text: "\(house(battle.attackerOwner))'s \(battle.attackerKind.title) strike \(what) for \(battle.damageDealt).", tone: .bad)
        case .unitLost(_, let kind, let owner, _):
            guard owner == viewer else { return nil }
            return Line(text: "Your \(kind.title) are lost.", tone: .bad)
        case .holdStruck:
            return nil
        case .holdCaptured(let hold, let from, let by):
            if by == viewer { return Line(text: "You take \(holdName(hold)) from \(house(from)).", tone: .good) }
            if from == viewer { return Line(text: "\(house(by)) takes \(holdName(hold)).", tone: .bad) }
            return Line(text: "\(house(by)) takes \(holdName(hold)) from \(house(from)).", tone: .neutral)
        case .seatMoved(let owner, let hold):
            guard owner == viewer else { return nil }
            return Line(text: "Your seat moves to \(holdName(hold)).", tone: .bad)
        case .holdFounded(let hold):
            guard state.hold(hold)?.owner == viewer else { return nil }
            return Line(text: "Your Founders raise \(holdName(hold)).", tone: .good)
        case .buildingStarted(let hold, let kind, let level):
            guard state.hold(hold)?.owner == viewer else { return nil }
            return Line(text: "Work begins on \(kind.title) \(roman(level)) at \(holdName(hold)).", tone: .neutral)
        case .buildingCompleted(let hold, let kind, let level):
            guard state.hold(hold)?.owner == viewer else { return nil }
            return Line(text: "\(kind.title) \(roman(level)) stands complete at \(holdName(hold)).", tone: .good)
        case .unitTrained(let unit, let hold):
            guard let made = state.unit(unit), made.owner == viewer else { return nil }
            return Line(text: "\(made.kind.title) muster at \(holdName(hold)).", tone: .good)
        case .bartered(let owner, let gave, let took):
            guard owner == viewer else { return nil }
            return Line(text: "Bartered \(gave) for \(took).", tone: .neutral)
        case .ruinSearched(_, let by, let reward):
            guard by == viewer else { return nil }
            return Line(text: "A drowned ruin gives up \(reward).", tone: .good)
        case .stanceChanged(let first, let second, let stance, let by):
            let other = first == by ? second : first
            if other == viewer, stance == .war { return Line(text: "\(house(by)) declares war on you.", tone: .bad) }
            if by == viewer { return Line(text: "You are at \(stance.title.lowercased()) with \(house(other)).", tone: .neutral) }
            if stance == .war { return Line(text: "\(house(by)) goes to war with \(house(other)).", tone: .neutral) }
            return nil
        case .envoyArrived(let envoy):
            return Line(text: "An envoy from \(house(envoy.from)) offers \(envoy.proposal.title.lowercased()).", tone: .neutral)
        case .proposalAnswered(let proposal, let from, let to, let accepted):
            if from == viewer {
                return Line(text: "\(house(to)) \(accepted ? "accepts" : "refuses") your offer of \(proposal.title.lowercased()).", tone: accepted ? .good : .bad)
            }
            if to == viewer, accepted {
                return Line(text: "You and \(house(from)) agree to \(proposal.title.lowercased()).", tone: .good)
            }
            return nil
        case .starving(let owner):
            guard owner == viewer else { return nil }
            return Line(text: "Your granaries are empty; your companies go hungry.", tone: .bad)
        case .houseFell(let fallen):
            return Line(text: fallen == viewer ? "Your House has fallen." : "\(house(fallen)) has fallen.", tone: fallen == viewer ? .bad : .neutral)
        case .gameEnded(let outcome):
            return Line(text: outcome.winner == viewer ? "The Nullmere is yours." : "\(house(outcome.winner)) is ascendant.", tone: outcome.winner == viewer ? .good : .bad)
        }
    }
}
