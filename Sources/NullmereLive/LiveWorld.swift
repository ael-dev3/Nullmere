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
    }

    private static func key(_ kind: Int, _ level: Int) -> UInt64 { UInt64(kind) << 32 | UInt64(level) }

    /// What a building costs and gives at a level.
    public func blueprint(_ building: Int, level: Int) -> LiveBlueprint? { blueprints[LiveWorld.key(building, level)] }

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
