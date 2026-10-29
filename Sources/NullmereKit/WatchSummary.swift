import NullmereCore

/// What a watch brought the player, in a few words, for the card that
/// marks its turning.
struct WatchSummary: Equatable {
    let watch: Int
    struct Change: Hashable {
        let resource: Resource
        let delta: Int
    }

    /// Each resource's change in store, after upkeep, for those that moved.
    let changes: [Change]
    /// At most three of the watch's events that touched the player.
    let events: [String]

    /// The card as VoiceOver says it: the watch, what the stores did, and
    /// what happened.
    var spoken: String {
        let stores = changes.map { "\($0.resource.title) \($0.delta > 0 ? "up" : "down") \(abs($0.delta))" }
        return (["Watch \(watch)."] + (stores.isEmpty ? [] : [stores.joined(separator: ", ") + "."]) + events.map { $0 + "." })
            .joined(separator: " ")
    }

    init(before: GameState, after: GameState, events: [GameEvent], player: Int) {
        watch = after.watch
        let was = before.houses[player].stock
        let now = after.houses[player].stock
        changes = Resource.allCases.compactMap { resource in
            let delta = now[resource] - was[resource]
            return delta == 0 ? nil : Change(resource: resource, delta: delta)
        }

        var battles = 0
        var notes: [String] = []
        for event in events {
            switch event {
            case .battle(let battle) where battle.attackerOwner == player || battle.defenderOwner == player:
                battles += 1
            case .holdCaptured(let hold, let from, let by) where from == player || by == player:
                let name = after.hold(hold)?.name ?? "a hold"
                notes.append(from == player ? "\(name) is lost" : "\(name) is taken")
            case .buildingCompleted(let hold, let kind, _) where after.hold(hold)?.owner == player:
                notes.append("\(kind.title) completed")
            case .unitTrained(let unit, _) where after.unit(unit)?.owner == player:
                notes.append("\(after.unit(unit)?.kind.title ?? "Company") mustered")
            case .envoyArrived(let envoy):
                notes.append("An envoy of \(after.houses[envoy.from].title)")
            case .stanceChanged(let first, let second, let stance, let by) where (first == player || second == player) && by != player:
                notes.append("\(after.houses[by].title): \(stance.title.lowercased())")
            case .houseFell(let house):
                notes.append("\(after.houses[house].title) has fallen")
            default:
                break
            }
        }
        if battles > 0 {
            notes.insert(battles == 1 ? "A battle" : "\(battles) battles", at: 0)
        }
        self.events = Array(notes.prefix(3))
    }
}
