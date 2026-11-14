import Foundation
import NullmereRealm

/// The realm's tables and views as a client watches them: the module in
/// `realm/` declares them, and each list here gives one's columns in the
/// order the module has them, which is the order a transaction's rows
/// come in. `LiveSchemaTests` holds every list to the module's source.
public enum LiveSchema {
    static let player = ["id", "name_key", "name", "joined", "online", "seen"]
    static let city = ["id", "owner", "hex", "name", "keep", "power", "founded", "builders"]

    /// Every table and view a client reads, with the column that tells
    /// its rows apart. The views show a caller their own rows.
    public static let tables: [String: SubscriptionMirror.Table] = [
        "realm": .init(columns: ["id", "seed", "opened", "pace", "joining_minute", "joined_in_minute", "radius"], key: "id"),
        "player": .init(columns: player, key: "id"),
        "land": .init(columns: ["chunk", "ground"], key: "chunk"),
        "place": .init(columns: ["hex", "kind", "id"], key: "hex"),
        "blueprint": .init(columns: ["id", "building", "level", "name", "grain", "timber", "stone", "moonsalt", "seconds", "grain_hourly",
                                     "timber_hourly", "stone_hourly", "moonsalt_hourly", "opens_at", "needs_building", "needs_level", "power"],
                           key: "id"),
        "soldier": .init(columns: ["id", "kind", "tier", "name", "attack", "defence", "health", "pace", "load", "power", "grain", "timber",
                                   "stone", "moonsalt", "millis", "building", "needs_level"], key: "id"),
        "city": .init(columns: city, key: "id"),
        "site": .init(columns: ["id", "hex", "kind", "level", "left", "gatherer"], key: "id"),
        "march": .init(columns: ["id", "owner", "city", "kind", "state", "from", "to", "target", "departed", "arrives", "soldiers", "route",
                                 "timer"], key: "id"),
        "me": .init(columns: player, key: "id"),
        "my_city": .init(columns: city, key: "id"),
        "my_buildings": .init(columns: ["id", "city", "kind", "level"], key: "id"),
        "my_jobs": .init(columns: ["id", "city", "kind", "subject", "level", "amount", "started", "ends", "timer"], key: "id"),
        "my_stock": .init(columns: ["city", "grain", "timber", "stone", "moonsalt", "as_of", "grain_hourly", "timber_hourly", "stone_hourly",
                                    "moonsalt_hourly", "grain_part", "timber_part", "stone_part", "moonsalt_part", "holds"], key: "city"),
        "my_troops": .init(columns: ["id", "city", "kind", "tier", "ready", "wounded"], key: "id"),
        "my_squads": .init(columns: ["id", "march", "kind", "tier", "count"], key: "id"),
        "my_hauls": .init(columns: ["march", "owner", "grain", "timber", "stone", "moonsalt"], key: "march"),
    ]

    /// The view each of the caller's own tables is read through.
    public static let views: [String: String] = [
        "me": "player", "my_city": "city", "my_buildings": "building", "my_jobs": "job", "my_stock": "stock", "my_troops": "troop",
        "my_squads": "squad", "my_hauls": "haul",
    ]

    /// The queries that watch all of them.
    public static let queries: [String] = tables.keys.sorted().map { "SELECT * FROM \($0)" }
}
