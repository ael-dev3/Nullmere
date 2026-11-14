import Foundation
import NullmereRealm

/// The realm as one client knows it at a moment: what everyone may read
/// (the land, who plays, where cities, sites and the Unquiet's barrows
/// stand, the armies on the map, the game's numbers) and what is the
/// player's own (their city, its buildings, work under way, goods, troops
/// and armies, their energy, and the reports of what their armies did).
public struct LiveWorld: Equatable, Sendable {
    public var realm: LiveRealm?
    public var players: [UInt64: LivePlayer] = [:]
    public var cities: [UInt64: LiveCity] = [:]
    public var places: [LiveHex: LivePlace] = [:]
    public var sites: [UInt64: LiveSite] = [:]
    public var barrows: [UInt64: LiveBarrow] = [:]
    public var marches: [UInt64: LiveMarch] = [:]
    public var alliances: [UInt64: LiveAlliance] = [:]
    /// Each player's place in an alliance, by the player's number.
    public var members: [UInt64: LiveMember] = [:]
    /// What has been said in the realm, the oldest first.
    public var realmChat: [LiveSaying] = []
    /// The land's chunks, sixteen hexes by sixteen, a byte a hex.
    public var land: [UInt64: [UInt8]] = [:]
    /// The players' first tasks, by their place in the order.
    public var tasks: [Int: LiveTask] = [:]
    var studies: [UInt64: LiveStudy] = [:]
    var blueprints: [UInt64: LiveBlueprint] = [:]
    var soldiers: [UInt64: LiveSoldier] = [:]

    public var me: LivePlayer?
    public var city: LiveCity?
    public var buildings: [LiveBuilding] = []
    public var jobs: [LiveJob] = []
    public var stock: LiveStock?
    public var troops: [LiveTroop] = []
    public var squads: [LiveSquad] = []
    public var hauls: [LiveHaul] = []
    public var hunt: LiveHunt?
    /// The player's reports, the latest first.
    public var reports: [LiveReport] = []
    /// The player's commanders, in the order they came.
    public var commanders: [LiveCommander] = []
    /// What the player's city has learnt: each topic's level, by the topic.
    public var lore: [Int: Int] = [:]
    /// The task the player is on, by its place in the order; one past the
    /// last when they have done them all.
    public var step: Int?
    /// What has been said within the player's alliance, the oldest first.
    public var allianceChat: [LiveSaying] = []
    /// Who has asked to join the player's alliance, for its officers; or
    /// the player's own asking, while they are in none.
    public var applicants: [LiveApplicant] = []

    public init() {}

    /// The world as a subscription's rows tell it, table by table.
    public init(snapshot: [String: [[JSONValue]]]) {
        func rows<Row>(_ table: String, _ make: ([JSONValue]) -> Row?) -> [Row] { (snapshot[table] ?? []).compactMap(make) }
        realm = rows("realm", LiveRealm.init).first
        players = Dictionary(rows("player", LivePlayer.init).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        cities = Dictionary(rows("city", LiveCity.init).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        places = Dictionary(rows("place", LivePlace.init).map { ($0.hex, $0) }, uniquingKeysWith: { _, new in new })
        sites = Dictionary(rows("site", LiveSite.init).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        barrows = Dictionary(rows("barrow", LiveBarrow.init).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        marches = Dictionary(rows("march", LiveMarch.init).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        alliances = Dictionary(rows("alliance", LiveAlliance.init).map { ($0.id, $0) }, uniquingKeysWith: { _, new in new })
        members = Dictionary(rows("member", LiveMember.init).map { ($0.player, $0) }, uniquingKeysWith: { _, new in new })
        realmChat = rows("realm_chat", LiveSaying.init(realm:)).sorted { $0.id < $1.id }
        tasks = Dictionary(rows("task", LiveTask.init).map { ($0.step, $0) }, uniquingKeysWith: { _, new in new })
        studies = Dictionary(rows("study", LiveStudy.init).map { (LiveWorld.key($0.topic, $0.level), $0) }, uniquingKeysWith: { _, new in new })
        for row in snapshot["land"] ?? [] {
            let cells = Cells(row: row)
            if let chunk = cells.unsigned(0), let ground = cells.bytes(1) { land[chunk] = ground }
        }
        blueprints = Dictionary(rows("blueprint", LiveBlueprint.init).map { (LiveWorld.key($0.building, $0.level), $0) },
                                uniquingKeysWith: { _, new in new })
        soldiers = Dictionary(rows("soldier", LiveSoldier.init).map { (LiveWorld.key($0.kind, $0.tier), $0) },
                              uniquingKeysWith: { _, new in new })
        me = rows("me", LivePlayer.init).first
        city = rows("my_city", LiveCity.init).first
        buildings = rows("my_buildings", LiveBuilding.init).sorted { $0.kind < $1.kind }
        jobs = rows("my_jobs", LiveJob.init).sorted { $0.ends < $1.ends }
        stock = rows("my_stock", LiveStock.init).first
        troops = rows("my_troops", LiveTroop.init).sorted { ($0.kind, $0.tier) < ($1.kind, $1.tier) }
        squads = rows("my_squads", LiveSquad.init).sorted { $0.id < $1.id }
        hauls = rows("my_hauls", LiveHaul.init).sorted { $0.march < $1.march }
        hunt = rows("my_hunt", LiveHunt.init).first
        reports = rows("my_reports", LiveReport.init).sorted { $0.id > $1.id }
        allianceChat = rows("my_alliance_chat", LiveSaying.init(alliance:)).sorted { $0.id < $1.id }
        applicants = rows("my_applicants", LiveApplicant.init).sorted { $0.at < $1.at }
        step = (snapshot["my_progress"] ?? []).compactMap { Cells(row: $0).whole(1) }.first
        commanders = rows("my_commanders", LiveCommander.init).sorted { $0.id < $1.id }
        for row in snapshot["my_lore"] ?? [] {
            let cells = Cells(row: row)
            if let topic = cells.whole(2), let level = cells.whole(3) { lore[topic] = level }
        }
    }

    private static func key(_ kind: Int, _ level: Int) -> UInt64 { UInt64(kind) << 32 | UInt64(level) }

    /// What a building costs and gives at a level.
    public func blueprint(_ building: Int, level: Int) -> LiveBlueprint? { blueprints[LiveWorld.key(building, level)] }

    /// What learning a level of a topic costs and gives.
    public func study(_ topic: Int, level: Int) -> LiveStudy? { studies[LiveWorld.key(topic, level)] }

    /// What a soldier of a kind and tier is and costs.
    public func soldier(_ kind: Int, tier: Int) -> LiveSoldier? { soldiers[LiveWorld.key(kind, tier)] }

    /// The player's building of a kind, if their city has one.
    public func building(_ kind: Int) -> LiveBuilding? { buildings.first { $0.kind == kind } }

    /// The barrow at a hex, if one stands there.
    public func barrow(at hex: LiveHex) -> LiveBarrow? {
        guard let place = places[hex], place.kind == LivePlace.barrow else { return nil }
        return barrows[place.id]
    }

    /// The alliance a player is in, if any.
    public func alliance(of player: UInt64) -> LiveAlliance? {
        members[player].flatMap { alliances[$0.alliance] }
    }

    /// The player's own alliance and their place in it.
    public var myAlliance: LiveAlliance? { me.flatMap { alliance(of: $0.id) } }
    public var myMembership: LiveMember? { me.flatMap { members[$0.id] } }

    /// Whether another player is of the player's own alliance.
    public func isAlly(_ player: UInt64) -> Bool {
        guard let mine = myMembership, let theirs = members[player] else { return false }
        return mine.alliance == theirs.alliance && player != mine.player
    }

    /// A player's name as others read it: their alliance's tag before it,
    /// where they are in one.
    public func shownName(of player: UInt64) -> String? {
        guard let name = players[player]?.name else { return nil }
        return alliance(of: player).map { "[\($0.tag)] \(name)" } ?? name
    }

    /// An alliance's members, its leader first, then by rank and by when
    /// they joined.
    public func roster(of alliance: UInt64) -> [LiveMember] {
        members.values.filter { $0.alliance == alliance }.sorted { ($1.rank, $0.joined, $0.player) < ($0.rank, $1.joined, $1.player) }
    }

    /// The task the player is on, if any are left.
    public var task: LiveTask? { step.flatMap { tasks[$0] } }

    /// Whether the player's city has done what a task asks, as far as the
    /// rows tell: the realm has the last word when it is claimed.
    public func isDone(_ task: LiveTask) -> Bool {
        guard let city else { return false }
        switch task.goal {
        case LiveTask.keep: return city.keep >= Int(task.amount)
        case LiveTask.raised: return (building(Int(task.amount))?.level ?? 0) >= task.level
        case LiveTask.soldiers:
            let home = troops.reduce(0) { $0 + $1.ready + $1.wounded }
            return home + squads.reduce(0) { $0 + $1.count + $1.wounded } >= task.amount
        case LiveTask.cleared: return (hunt?.cleared ?? 0) >= Int(task.amount)
        case LiveTask.allied: return myMembership != nil
        case LiveTask.power: return city.power >= task.amount
        default: return false
        }
    }

    /// The commander to lead the next army, where the player has not
    /// said: the highest of those in the city.
    public var freeLeader: LiveCommander? {
        commanders.filter(\.isFree).max { ($0.level, $1.id) < ($1.level, $0.id) }
    }

    /// How many commanders the city keeps, by its Tavern's level, and what
    /// taking on the next costs, as the module's catalogue has them.
    public static func commandersKept(tavern: Int) -> Int { tavern == 0 ? 1 : min(2 + tavern / 5, 6) }
    public static func hireCost(have: Int) -> LiveGoods {
        let n = UInt64(max(have, 1))
        return LiveGoods(grain: 2_000 * n * n, timber: 2_000 * n * n, stone: 1_000 * n * n, moonsalt: n >= 2 ? 50 * n : 0)
    }

    /// Why the player can't take on another commander now; nil where they can.
    public func hireBlock(at seconds: Double) -> LiveBlock? {
        let tavern = building(16)?.level ?? 0
        if tavern == 0 { return .needsOther("Tavern", 1) }
        if commanders.count >= 6 { return .commandersFull }
        if commanders.count >= LiveWorld.commandersKept(tavern: tavern) { return .needsOther("Tavern", (commanders.count - 1) * 5) }
        let have = stock?.goods(at: seconds) ?? LiveGoods()
        let cost = LiveWorld.hireCost(have: commanders.count)
        return have.covers(cost) ? nil : .short(have.short(of: cost))
    }

    /// How many of the player's reports are unread.
    public var unread: Int { reports.filter { !$0.read }.count }

    /// The player's own marches.
    public var myMarches: [LiveMarch] {
        guard let me else { return [] }
        return marches.values.filter { $0.owner == me.id }.sorted { $0.id < $1.id }
    }

    /// The ground at a hex, as the land's chunks have it (the module's
    /// `land::Ground` codes); nil where its chunk is not known.
    public func ground(at hex: LiveHex) -> UInt8? {
        func floored(_ value: Int) -> (Int, Int) {
            let chunk = value >= 0 ? value / 16 : -((-value + 15) / 16)
            return (chunk, value - chunk * 16)
        }
        let (cq, iq) = floored(hex.q), (cr, ir) = floored(hex.r)
        guard let bytes = land[LiveHex(q: cq, r: cr).packed], bytes.count == 256 else { return nil }
        return bytes[ir * 16 + iq]
    }
}
