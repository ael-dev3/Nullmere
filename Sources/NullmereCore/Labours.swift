/// The watch's labours (after Rise of Kingdoms' daily objectives): each
/// watch a keeper's House is set three labours of the five, each with its
/// measure: strike down companies of the wilds, bring stores home, muster
/// companies, raise works, learn grades of study. What the House does as
/// the watch turns counts toward them, the realm keeping the tally; each
/// labour done is worth vigour, and the vigour of a moon opens three
/// chests as it passes its marks. The moon's new, it begins again.
public enum LabourKind: String, Codable, CaseIterable, Sendable, PlainCases {
    case hunt, gather, muster, raise, study

    public var title: String {
        switch self {
        case .hunt: return "Strike down companies of the wilds"
        case .gather: return "Bring stores home from the land's sites"
        case .muster: return "Muster companies"
        case .raise: return "Raise works"
        case .study: return "Learn grades of study"
        }
    }

    /// How much of it a labour asks.
    public var measure: Int {
        switch self {
        case .hunt: return 2
        case .gather: return 150
        case .muster: return 1
        case .raise: return 1
        case .study: return 1
        }
    }
}

public struct Labour: Codable, Equatable, Sendable {
    public let kind: LabourKind
    public internal(set) var done: Int

    public var isDone: Bool { done >= kind.measure }
}

/// A keeper's House's labours for a watch, and its vigour this moon.
public struct Labours: Codable, Equatable, Sendable {
    public let watch: Int
    public internal(set) var tasks: [Labour]
    public internal(set) var vigour: Int
    /// The chests of this moon already opened.
    public internal(set) var opened: Int

    /// Vigour a labour done is worth.
    public static let vigourPerLabour = 10
    /// The vigour at which the moon's chests open.
    public static let chests = [20, 50, 90]
    /// What each chest holds.
    public static let chestStores = [Stock(grain: 80, timber: 80), Stock(timber: 60, stone: 80, moonsalt: 4), Stock(grain: 120, stone: 120, moonsalt: 10)]
    public static let chestItems: [[ItemKind]] = [[.hourglass], [.hourglass, .mendingDraught], [.wardStone, .hourglass, .hourglass]]
}

extension Labours {
    /// How the watch's labours stand, in a line, as the Mac and the phone
    /// tell it: "1 of 3 done this watch · vigour 10 of 20 for the next chest".
    public var summary: String {
        let done = tasks.filter(\.isDone).count
        let next = Labours.chests.dropFirst(opened).first
        return "\(done) of \(tasks.count) done this watch · vigour \(vigour)" + (next.map { " of \($0) for the next chest" } ?? ", every chest opened")
    }

    /// What a labour done is worth, and when the moon's chests open.
    public static var worth: String {
        "Each done is \(vigourPerLabour) vigour as the watch turns; the moon's chests open at \(chests.map(String.init).joined(separator: ", "))."
    }
}

extension Labour {
    /// A labour as it stands: "Raise works: 1 of 1".
    public var line: String {
        "\(kind.title): \(min(done, kind.measure)) of \(kind.measure)"
    }
}

extension LabourKind {
    /// How much of it an event does, for which House.
    func share(of event: GameEvent, in state: GameState) -> (house: Int, amount: Int)? {
        switch (self, event) {
        case (.hunt, .hunted(let hunt)) where hunt.wildFell: return (hunt.attackerOwner, 1)
        case (.gather, .delivered(_, let owner, _, let load)): return (owner, load.grain + load.timber + load.stone + 4 * load.moonsalt)
        case (.muster, .unitTrained(_, let hold)): return state.hold(hold).map { ($0.owner, 1) }
        case (.raise, .buildingCompleted(let hold, _, _)): return state.hold(hold).map { ($0.owner, 1) }
        case (.study, .studyCompleted(let house, _, _)): return (house, 1)
        default: return nil
        }
    }
}

extension GameState {
    /// A House's labours as they stand.
    public func labours(of house: Int) -> Labours? {
        labourBook?[house]
    }

    /// The three labours of the five a House is set at a watch: always the
    /// same for the same House and watch.
    static func labourKinds(for house: Int, at watch: Int) -> [LabourKind] {
        let all = LabourKind.allCases
        let skip = (watch * 7 + house * 3) % all.count
        let skipToo = (skip + 1 + (watch + house) % (all.count - 1)) % all.count
        return all.enumerated().filter { $0.offset != skip && $0.offset != skipToo }.map(\.element)
    }

    /// What a House does counts toward its watch's labours as it is done:
    /// its orders, its marches' paces and the watch's turn alike.
    mutating func countLabours(_ events: [GameEvent]) {
        guard var book = labourBook, !book.isEmpty, !events.isEmpty else { return }
        // Each event's share reckoned once for each kind of labour, by the
        // House it falls to, not once for every House's every labour: a
        // realm of many keepers has as many events as it has Houses.
        var shares: [LabourKind: [Int: Int]] = [:]
        for kind in LabourKind.allCases {
            for event in events {
                guard let share = kind.share(of: event, in: self), share.amount > 0 else { continue }
                shares[kind, default: [:]][share.house, default: 0] += share.amount
            }
        }
        guard !shares.isEmpty else { return }
        var changed = false
        for (house, var kept) in book {
            for index in kept.tasks.indices where !kept.tasks[index].isDone {
                guard let amount = shares[kept.tasks[index].kind]?[house] else { continue }
                kept.tasks[index].done += amount
                changed = true
            }
            book[house] = kept
        }
        if changed { labourBook = book }
    }

    /// As the watch turns, after all it brought is counted: each labour
    /// done is worth its vigour, chests open at their marks; then the new
    /// watch's labours are set, the vigour kept through the moon and begun
    /// again at its new.
    mutating func turnLabours() -> [GameEvent] {
        var events: [GameEvent] = []
        var book = labourBook ?? [:]
        for house in houses.indices where houses[house].isPlayer && !houses[house].isEliminated {
            var vigour = 0, opened = 0
            if var kept = book[house] {
                for task in kept.tasks where task.isDone {
                    kept.vigour += Labours.vigourPerLabour
                    events.append(.labourDone(house: house, kind: task.kind))
                }
                while kept.opened < Labours.chests.count, kept.vigour >= Labours.chests[kept.opened] {
                    store(Labours.chestStores[kept.opened], for: house)
                    events += give(Labours.chestItems[kept.opened], to: house)
                    kept.opened += 1
                    events.append(.chestOpened(house: house, chest: kept.opened))
                }
                vigour = kept.vigour
                opened = kept.opened
            }
            if GameState.moonAge(at: watch) == 0 { vigour = 0; opened = 0 }
            book[house] = Labours(watch: watch, tasks: GameState.labourKinds(for: house, at: watch).map { Labour(kind: $0, done: 0) },
                                  vigour: vigour, opened: opened)
        }
        labourBook = book.isEmpty ? nil : book
        return events
    }
}
