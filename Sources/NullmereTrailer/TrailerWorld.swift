import Foundation
import NullmereCore
import NullmereModels
import NullmereWorld

/// The world the trailer is shot in: a realm of twelve Houses played on by
/// their stewards until its holds have grown towns and works, all of it
/// seen, so nothing lies under mist. One seat is shown raised whole, its
/// Moonspire crowned, for the trailer's heart; another's Moonspire at its
/// third stage, its crane at work; and a hold of another House walled in
/// stone, for the heart's House to besiege. The realm itself is left as its
/// stewards made it: those three are dressed only as the trailer draws them.
public struct TrailerWorld {
    public let state: GameState
    /// Every hold as the trailer draws it, the two seats dressed.
    public let holds: [Hold]
    public let relief: Relief
    public let terrain: TerrainMesh
    public let stage: WorldStage
    /// The Houses' colours by sigil, as the renderer reads them.
    public let houses: [Vec4]
    /// The seat at the trailer's heart, every work raised whole.
    public let seat: Hold
    /// Another House's seat, its Moonspire rising.
    public let rising: Hold
    /// A great hold for the town's shot, and one on the shore for the rain.
    public let town: Hold
    public let shore: Hold
    /// A hold of another House near the heart, walled in stone, under siege.
    public let besieged: Hold
    /// The land's furniture, laid out once.
    public let furniture: [ModelBatch]
    /// The ways the carts go between each House's holds.
    public let ways: [WorldStage.Way]

    public init(houses: [Vec4], seed: String = "the still black water", watches: Int = 72) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 12, radius: 26, keepers: 1))
        for _ in 0..<watches where state.outcome == nil {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }

        // The heart: the seat of the House with the most holds, every work
        // raised whole and its Moonspire crowned.
        let living = state.houses.indices.filter { !state.houses[$0].isEliminated && state.seat(of: $0) != nil }
        let greatest = living.max { (state.holds(of: $0).count, -$0) < (state.holds(of: $1).count, -$1) } ?? state.player
        var heart = state.seat(of: greatest) ?? state.holds[0]
        for kind in BuildingKind.allCases {
            heart.levels[kind] = kind.maxLevel
        }
        heart.project = nil
        heart.training = nil
        // Another House's seat, as near the heart as any, its Moonspire at
        // its third stage and its works well raised.
        let others = state.holds.filter { $0.isSeat && $0.owner != heart.owner }
        var second = others.min { ($0.position.distance(to: heart.position), $0.id) < ($1.position.distance(to: heart.position), $1.id) } ?? heart
        if second.id != heart.id {
            for kind in BuildingKind.allCases where kind != .moonspire {
                second.levels[kind] = max(second.level(kind), min(kind.maxLevel, 3))
            }
            second.levels[.moonspire] = 3
            second.project = nil
        }
        var dressed = [heart.id: heart, second.id: second]
        let drawn = state.holds.map { dressed[$0.id] ?? $0 }
        self.state = state
        self.houses = houses
        relief = Relief(map: state.map)
        terrain = TerrainMesh.shared(for: state.map)
        stage = WorldStage(map: state.map, relief: relief)
        seat = heart
        rising = second
        // The town: the hold with the most raised, other than the two seats.
        let rest = drawn.filter { $0.id != heart.id && $0.id != second.id }
        func raised(_ hold: Hold) -> Int { hold.levels.values.reduce(0, +) }
        let great = rest.max { (raised($0), -$0.id) < (raised($1), -$1.id) } ?? heart
        town = great
        // The shore: a hold with still water beside it, nearest the heart.
        let map = state.map
        let onShore = rest.filter { hold in hold.position.neighbors.contains { map[$0]?.terrain.isWater == true } }
        let still = onShore.min { ($0.position.distance(to: heart.position), $0.id) < ($1.position.distance(to: heart.position), $1.id) } ?? great
        shore = still
        // The besieged: of the other Houses' holds, neither the town's nor
        // the shore's, the nearest the heart with open ground before its
        // gate for the besiegers to stand on, its walls raised in stone.
        let besiegers = heart.owner
        func standing(_ hex: Hex) -> Bool {
            guard let tile = map[hex] else { return false }
            return tile.terrain.isPassable && !tile.terrain.isWater && state.hold(at: hex) == nil
        }
        func room(_ hold: Hold) -> Int {
            let centre = Relief.centre(of: hold.position), gate = HoldLayout.gate(of: hold.position)
            let out = Vec3(gate.x - centre.x, 0, gate.z - centre.z).normalized
            return hold.position.spiral(3).filter { hex in
                guard hex.distance(to: hold.position) >= 2, standing(hex) else { return false }
                let c = Relief.centre(of: hex)
                let along = Vec3(c.x - centre.x, 0, c.z - centre.z).normalized
                return along.x * out.x + along.z * out.z > 0.5
            }.count
        }
        let candidates = rest.filter { $0.owner != besiegers && $0.id != great.id && $0.id != still.id && room($0) >= 4 }
        var walled = candidates.min { ($0.position.distance(to: heart.position), $0.id) < ($1.position.distance(to: heart.position), $1.id) } ?? second
        walled.levels[.walls] = max(walled.level(.walls), 4)
        walled.project = nil
        besieged = walled
        dressed[walled.id] = walled
        holds = state.holds.map { dressed[$0.id] ?? $0 }
        let all = holds
        furniture = stage.furnish(occupied: Set(state.sitesInLand.map(\.position) + state.lairsStanding.map(\.position)),
                                  holds: Set(all.map(\.position)))
        var ways: [WorldStage.Way] = []
        var joined: Set<[Int]> = []
        for hold in all {
            let near = all.filter { $0.owner == hold.owner && $0.id != hold.id && $0.position.distance(to: hold.position) <= 7 }
            guard let other = near.min(by: { ($0.position.distance(to: hold.position), $0.id) < ($1.position.distance(to: hold.position), $1.id) }),
                  joined.insert([min(hold.id, other.id), max(hold.id, other.id)]).inserted else { continue }
            let line = hold.position.line(to: other.position)
            guard line.allSatisfy({ map[$0].map { $0.terrain.isPassable && !$0.terrain.isWater } ?? false }) else { continue }
            ways.append(WorldStage.Way(hexes: line, colour: WorldStage.colour(houses, sigil: state.houses[hold.owner].sigil),
                                       salt: hold.id &* 7 &+ other.id))
        }
        self.ways = ways
    }

    /// Where a hex's heart lies on the land.
    public func ground(_ hex: Hex) -> Vec3 {
        let centre = Relief.centre(of: hex)
        return Vec3(centre.x, max(relief.height(of: hex), Relief.waterline), centre.z)
    }

    /// Where a point of the map lies on the land, or on the water's face.
    public func ground(x: Float, z: Float) -> Vec3 {
        Vec3(x, max(relief.height(atX: x, z: z), Relief.waterline), z)
    }

    /// A House's colour, as the renderer reads it.
    public func colour(of house: Int) -> Vec4 {
        WorldStage.colour(houses, sigil: state.houses[house].sigil)
    }

    /// Whether a hex is open ground a company could stand on.
    public func isOpen(_ hex: Hex) -> Bool {
        guard let tile = state.map[hex] else { return false }
        return tile.terrain.isPassable && !tile.terrain.isWater && state.hold(at: hex) == nil
    }
}
