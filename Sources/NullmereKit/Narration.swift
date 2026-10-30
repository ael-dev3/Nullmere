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
        BuildingKind.numeral(number)
    }

    /// Where something happened, as a keeper would say it: at a hold, or
    /// on its ground by the nearest hold within a few tiles.
    static func place(of hex: Hex, in state: GameState) -> String {
        if let hold = state.hold(at: hex) { return "at \(hold.name)" }
        let ground = state.map[hex].map { "on the \($0.terrain.title.lowercased())" } ?? "in the field"
        let near = state.holds.filter { $0.position.distance(to: hex) <= 4 }
            .min { ($0.position.distance(to: hex), $0.id) < ($1.position.distance(to: hex), $1.id) }
        return near.map { "\(ground) by \($0.name)" } ?? ground
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
        case .unitLost(_, let kind, let owner, let at):
            guard owner == viewer else { return nil }
            return Line(text: "Your \(kind.title) are lost \(place(of: at, in: state)).", tone: .bad)
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
            return Line(text: "Your Founders found \(holdName(hold)).", tone: .good)
        case .buildingStarted(let hold, let kind, let level):
            guard state.hold(hold)?.owner == viewer else { return nil }
            return Line(text: "Work begins on \(kind.title) \(roman(level)) at \(holdName(hold)).", tone: .neutral)
        case .buildingCompleted(let hold, let kind, let level):
            guard state.hold(hold)?.owner == viewer else { return nil }
            return Line(text: "\(kind.title) \(roman(level)) stands complete at \(holdName(hold)).", tone: .good)
        case .unitTrained(let unit, let hold):
            guard let made = state.unit(unit), made.owner == viewer else { return nil }
            return Line(text: "\(made.kind.title) muster at \(holdName(hold)).", tone: .good)
        case .promoted(_, let owner, let rank):
            guard owner == viewer, Unit.rankTitles.indices.contains(rank) else { return nil }
            return Line(text: "A company of yours comes through the fighting \(Unit.rankTitles[rank]).", tone: .good)
        case .gifted(let from, let to, let gift):
            if from == viewer { return Line(text: "You send \(house(to)) a gift of \(gift).", tone: .neutral) }
            if to == viewer { return Line(text: "\(house(from)) sends you a gift of \(gift).", tone: .good) }
            return nil
        case .bartered(let owner, let gave, let took):
            guard owner == viewer else { return nil }
            return Line(text: "Bartered \(gave) for \(took).", tone: .neutral)
        case .ruinSearched(_, let by, let reward):
            guard by == viewer else { return nil }
            return Line(text: "A drowned ruin gives up \(reward).", tone: .good)
        case .stanceChanged(let first, let second, let stance, let by):
            let other = first == by ? second : first
            if other == viewer, stance == .war { return Line(text: "\(house(by)) declares war on you.", tone: .bad) }
            if by == viewer { return Line(text: "You are \(stance.standing) with \(house(other)).", tone: .neutral) }
            if stance == .war { return Line(text: "\(house(by)) goes to war with \(house(other)).", tone: .neutral) }
            return nil
        case .envoyArrived(let envoy):
            if let trade = envoy.trade {
                if envoy.from == viewer { return Line(text: "Your envoy takes \(house(envoy.to)) an offer: \(trade).", tone: .neutral) }
                return Line(text: "An envoy from \(house(envoy.from)) offers a trade: \(trade.given) for \(trade.taken) of yours.", tone: .neutral)
            }
            if envoy.from == viewer {
                let errand = envoy.proposal == .tribute ? "a demand for tribute" : "an offer of \(envoy.proposal.offered)"
                return Line(text: "Your envoy takes \(house(envoy.to)) \(errand).", tone: .neutral)
            }
            if envoy.proposal == .tribute {
                // A steward refused marches; a keeper refused may only choose war.
                let threat = state.houses[envoy.from].isPlayer ? "" : ", or war"
                return Line(text: "An envoy from \(house(envoy.from)) demands tribute\(threat).", tone: .bad)
            }
            return Line(text: "An envoy from \(house(envoy.from)) offers \(envoy.proposal.offered).", tone: .neutral)
        case .proposalAnswered(.tribute, let from, let to, let accepted):
            if from == viewer {
                return Line(text: accepted ? "\(house(to)) pays you tribute." : "\(house(to)) refuses your demand for tribute.",
                            tone: accepted ? .good : .bad)
            }
            if to == viewer {
                return Line(text: accepted ? "You pay tribute to \(house(from)); it keeps the peace." : "You refuse \(house(from)) its tribute.",
                            tone: accepted ? .neutral : .bad)
            }
            return nil
        case .proposalAnswered(let proposal, let from, let to, let accepted):
            if from == viewer {
                return Line(text: "\(house(to)) \(accepted ? "accepts" : "refuses") your offer of \(proposal.offered).", tone: accepted ? .good : .bad)
            }
            if to == viewer, accepted {
                switch proposal {
                case .peace: return Line(text: "You and \(house(from)) make peace.", tone: .good)
                case .pact: return Line(text: "You and \(house(from)) swear a pact.", tone: .good)
                case .fealty: return Line(text: "\(house(from)) swears you fealty.", tone: .good)
                case .trade, .tribute: return Line(text: "You and \(house(from)) agree to \(proposal.offered).", tone: .good)
                }
            }
            return nil
        case .tradeAnswered(let trade, let from, let to, let accepted):
            if from == viewer {
                return accepted ? Line(text: "\(house(to)) takes your trade: \(trade.given) for \(trade.taken).", tone: .good)
                                : Line(text: "\(house(to)) won't trade \(trade.taken) for \(trade.given).", tone: .bad)
            }
            if to == viewer {
                return accepted ? Line(text: "You trade \(trade.taken) to \(house(from)) for \(trade.given).", tone: .good)
                                : Line(text: "No trade with \(house(from)): \(trade.given) for \(trade.taken).", tone: .neutral)
            }
            return nil
        case .starving(let owner):
            guard owner == viewer else { return nil }
            return Line(text: "Your grain has run out; your companies go hungry.", tone: .bad)
        case .houseFell(let fallen):
            return Line(text: fallen == viewer ? "Your House has fallen." : "\(house(fallen)) has fallen.", tone: fallen == viewer ? .bad : .neutral)
        case .gameEnded(let outcome):
            if outcome.winner == viewer { return Line(text: "\(state.settings.lake.title.prefix(1).uppercased() + state.settings.lake.title.dropFirst()) is yours.", tone: .good) }
            switch outcome.kind {
            case .ascendancy: return Line(text: "\(house(outcome.winner)) is ascendant.", tone: .bad)
            case .dominion: return Line(text: "\(house(outcome.winner)) holds dominion over the lake.", tone: .bad)
            }
        case .studyBegun, .studyCompleted, .commanderJoined, .commanderAssigned, .commanderReleased, .commanderRose,
             .commanderWounded, .skillFired, .hunted, .sentToGather, .gathered, .delivered, .siteWorkedOut,
             .allianceFounded, .allianceInvited, .allianceAsked, .allianceAnswered, .allianceJoined, .allianceLeft, .allianceLed,
             .allianceDisbanded, .helpGiven, .rallyCalled, .rallyJoined, .rallySetOut, .rallyStruck, .rallyDispersed, .sentToReinforce,
             .happeningBegun, .happeningMark, .happeningEnded:
            // The deeper systems' words are the rules' own.
            return state.tidings(of: event, for: viewer).map { Line(text: $0.text, tone: Narration.tone($0.tone)) }
        }
    }

    /// A tidings' tone as a notice's.
    static func tone(_ tone: Tidings.Tone) -> GameSession.Notice.Tone {
        switch tone {
        case .good: return .good
        case .bad: return .bad
        case .neutral: return .neutral
        }
    }
}
