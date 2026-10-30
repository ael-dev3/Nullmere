import Foundation
import XCTest
@testable import NullmereCore

/// Scenes staged for the tests of the realm's deeper systems: a small lake,
/// a company put where it is wanted, stores to spend.
enum Scene {
    /// A small lake of a few Houses, the first a keeper's.
    static func world(_ seed: String, houses: Int = 3, radius: Int = 16) -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: houses, radius: radius, keepers: 1))
    }

    static let encoder: JSONEncoder = {
        let encoder = JSONEncoder()
        encoder.outputFormatting = .sortedKeys
        return encoder
    }()

    /// A value's JSON with the named keys taken out wherever they are, as
    /// a save from before they were kept would have it.
    static func without<T: Encodable>(_ keys: Set<String>, in value: T) throws -> Data {
        let object = try JSONSerialization.jsonObject(with: encoder.encode(value))
        return try JSONSerialization.data(withJSONObject: stripped(object, keys))
    }

    private static func stripped(_ value: Any, _ keys: Set<String>) -> Any {
        if let object = value as? [String: Any] {
            var kept: [String: Any] = [:]
            for (key, inner) in object where !keys.contains(key) {
                kept[key] = stripped(inner, keys)
            }
            return kept
        }
        if let array = value as? [Any] {
            return array.map { stripped($0, keys) }
        }
        return value
    }
}

extension GameState {
    /// A passable hex at a distance from `hex` with no company, hold or
    /// anything else standing on it.
    func freeHex(near hex: Hex, within distances: ClosedRange<Int> = 1...1, avoiding terrains: Set<Terrain> = []) -> Hex? {
        hex.spiral(distances.upperBound).first { candidate in
            guard distances.contains(candidate.distance(to: hex)), let tile = map[candidate], tile.terrain.isPassable,
                  !terrains.contains(tile.terrain) else { return false }
            return isClear(candidate)
        }
    }

    /// Whether nothing stands on a hex.
    func isClear(_ hex: Hex) -> Bool {
        unit(at: hex) == nil && hold(at: hex) == nil
    }

    /// Puts a company of a kind and tier for a House at a hex; its id.
    @discardableResult
    mutating func put(_ kind: UnitKind, tier: Int = 1, of house: Int, at hex: Hex, health: Int = 100) -> Int {
        var unit = Unit(id: takeID(), kind: kind, owner: house, position: hex, tier: tier)
        unit.health = health
        units.append(unit)
        return unit.id
    }

    /// Fills a House's stores to what it can keep.
    mutating func richen(_ house: Int) {
        let room = storage(of: house)
        houses[house].stock = Stock(grain: room, timber: room, stone: room, moonsalt: room)
    }

    /// Plays watches, the keeper's House by its steward too.
    mutating func play(_ watches: Int) {
        for _ in 0..<watches where outcome == nil {
            _ = stewardTurn(for: player)
            _ = endWatch()
        }
    }
}
