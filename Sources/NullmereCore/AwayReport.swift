import Foundation

/// A store's change, for those that moved.
public struct StockChange: Hashable, Sendable {
    public let resource: Resource
    public let delta: Int

    public init(resource: Resource, delta: Int) {
        self.resource = resource
        self.delta = delta
    }
}

/// What a keeper last saw of their House, kept on their Mac or their phone.
public struct LastSeen: Codable, Equatable, Sendable {
    public let watch: Int
    public let stock: Stock
    public let holds: Int
    /// The House it was: absent in what was kept before it was noted.
    public var house: Int?

    public init(watch: Int, stock: Stock, holds: Int, house: Int? = nil) {
        self.watch = watch
        self.stock = stock
        self.holds = holds
        self.house = house
    }

    /// What a House is seen to be in a world.
    public init(of house: Int, in world: GameState) {
        self.init(watch: world.watch, stock: world.houses[house].stock, holds: world.holds(of: house).count, house: house)
    }
}

/// What happened while the keeper was away: how many watches passed, how
/// their stores and holds changed, and the news that touched them.
public struct AwayReport: Equatable, Sendable {
    public let watches: Int
    public let changes: [StockChange]
    public let holdsChange: Int
    /// At most `lines` entries of the chronicle, oldest first: what touched
    /// the keeper's House before what the whole lake heard (a fall, the end
    /// of an age), and of the omens, only the latest.
    public let news: [String]
    /// How many more of those the Chronicle holds than are told here.
    public let more: Int
    /// That a caretaker kept the House by the keeper's standing orders,
    /// where it kept it and they had given any.
    public let standing: String?
    /// The watch the keeper came back to.
    public let watch: Int

    public static let lines = 8

    /// Nil when nothing passed worth telling.
    public init?(since seen: LastSeen, now world: GameState, player: Int) {
        guard world.watch > seen.watch, world.houses.indices.contains(player) else { return nil }
        watch = world.watch
        watches = world.watch - seen.watch
        let stock = world.houses[player].stock
        changes = Resource.allCases.compactMap { resource in
            let delta = stock[resource] - seen.stock[resource]
            return delta == 0 ? nil : StockChange(resource: resource, delta: delta)
        }
        holdsChange = world.holds(of: player).count - seen.holds
        let chronicle = world.chronicle
        let since = chronicle.indices.filter { chronicle[$0].watch > seen.watch }
        let theirs = since.filter { chronicle[$0].houses.contains(player) }
        let lakes = since.filter { !chronicle[$0].houses.contains(player) && [.fall, .ending].contains(chronicle[$0].kind) }
        let omen = since.last { !chronicle[$0].houses.contains(player) && chronicle[$0].kind == .omen }
        var told = Array(theirs.suffix(AwayReport.lines))
        for index in (lakes + [omen].compactMap { $0 }).sorted().reversed() where told.count < AwayReport.lines {
            told.append(index)
        }
        let title = world.houses[player].title
        news = told.sorted().map { AwayReport.told(chronicle[$0].text, to: title) }
        more = theirs.count + lakes.count + (omen == nil ? 0 : 1) - told.count
        let orders = world.standingOrders(of: player)
        standing = watches >= RealmState.caretakerAfter && !orders.isEmpty
            ? "A caretaker kept your House by your standing orders, which still stand." : nil
    }

    /// A chronicle line as the keeper it is told to reads it: their own
    /// House named as theirs, "Your House founds Dremmarch", "refuses
    /// tribute to your House"; the Chronicle itself names every House alike.
    public static func told(_ line: String, to title: String) -> String {
        guard !title.isEmpty else { return line }
        var said = ""
        var rest = Substring(line)
        while let found = rest.range(of: title) {
            let before = rest[..<found.lowerBound]
            let lastBefore = before.last ?? said.last
            let after = found.upperBound < rest.endIndex ? rest[found.upperBound] : nil
            // Only the whole name: not "House Aurel" within "House Aurelin".
            guard !(after?.isLetter ?? false), !(lastBefore?.isLetter ?? false) else {
                said += rest[..<found.upperBound]
                rest = rest[found.upperBound...]
                continue
            }
            said += before
            let opening = said.isEmpty || [". ", "! ", "? "].contains { said.hasSuffix($0) }
            said += opening ? "Your House" : "your House"
            rest = rest[found.upperBound...]
        }
        return said + rest
    }

    /// The Chronicle's share of the rest, when there is more than is told.
    public var moreLine: String? {
        switch more {
        case ..<1: return nil
        case 1: return "And one more in the Chronicle."
        default: return "And \(more) more in the Chronicle."
        }
    }

    public var title: String {
        watches == 1 ? "While you were away, a watch passed" : "While you were away, \(watches) watches passed"
    }

    public var holdsLine: String? {
        switch holdsChange {
        case 0: return nil
        case 1: return "You hold one more hold."
        case -1: return "You lost a hold."
        case let n where n > 0: return "You hold \(n) more holds."
        default: return "You lost \(-holdsChange) holds."
        }
    }
}

extension Voicing {
    /// What the model is asked for the caretaker's word to a keeper come
    /// back to their House (`AwayReport.voiced(house:)`).
    public static let caretakerTask = "Speak as the caretaker who kept the keeper's House while they were away, greeting them on their return "
        + "and telling them plainly what passed, the gravest first, keeping every number, name and event as given. Two or three sentences, "
        + "at most 60 words."
}

extension AwayReport {
    /// The news told the caretaker gives words to, at most.
    public static let caretakerTells = 5

    /// What passed while the keeper was away, as the caretaker who kept
    /// their House tells it on their return, for a device's own model to
    /// voice: how long they were gone, how the stores and holds stand
    /// changed, the news that touched the House, and whether its standing
    /// orders were kept.
    public func voiced(house title: String) -> Voicing.Moment {
        let gone = watches == 1 ? "one watch" : "\(watches) watches"
        var facts = ["The caretaker kept \(title.isEmpty ? "the House" : title) while its keeper was away \(gone)."]
        let gained = changes.filter { $0.delta > 0 }.map { "\($0.delta) \($0.resource.title.lowercased())" }
        let lost = changes.filter { $0.delta < 0 }.map { "\(-$0.delta) \($0.resource.title.lowercased())" }
        if !gained.isEmpty { facts.append("The stores grew by \(gained.joined(separator: ", ")).") }
        if !lost.isEmpty { facts.append("The stores fell by \(lost.joined(separator: ", ")).") }
        if let holds = holdsLine { facts.append(holds) }
        facts += news.suffix(AwayReport.caretakerTells)
        if let standing { facts.append(standing) }
        if news.count > AwayReport.caretakerTells || more > 0 { facts.append("More of it stands in the Chronicle.") }
        return Voicing.Moment(task: Voicing.caretakerTask, facts: facts)
    }
}
