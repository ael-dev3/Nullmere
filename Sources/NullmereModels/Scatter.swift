import Foundation
import NullmereCore

/// The land's furniture over the whole map, by each hex's terrain and
/// feature: firs in the blackwood, crags on the Spine, mounds and stones on
/// the barrows, crystals on the flats, reeds and driftwood on the strand.
/// The same map always gives the same pieces. Each hex's pieces stand
/// within it and never reach a neighbour's heart, so a hex can be laid out
/// again alone when a company comes or goes; where a company stands its
/// heart is left clear, and round a hold the ground its works stand on.
public enum Scatter {
    /// The radius of a hex's heart, left clear where a company stands.
    public static let heart: Float = 0.62
    /// How far each piece is sunk below the ground at its foot.
    public static let sink: Float = 0.01

    /// Every hex's furnishings. `occupied` names the hexes where a company
    /// or hold stands; `holds` the hexes of holds, whose works' ground,
    /// within `HoldLayout.reach` of their hearts, is left bare.
    public static func pieces(map: WorldMap, relief: Relief, occupied: Set<Hex> = [], holds: Set<Hex> = []) -> [Piece] {
        map.hexes.flatMap {
            pieces(in: $0, map: map, relief: relief, clearHeart: occupied.contains($0) || holds.contains($0), holds: holds)
        }
    }

    /// One hex's furnishings.
    public static func pieces(in hex: Hex, map: WorldMap, relief: Relief, clearHeart: Bool = false, holds: Set<Hex> = []) -> [Piece] {
        guard let tile = map[hex] else { return [] }
        let centre = Relief.centre(of: hex)
        let heartPoint = (x: centre.x, z: centre.z)
        let nearHolds = holds.filter { $0.distance(to: hex) <= 2 }.map { Relief.centre(of: $0) }
        let neighbours = hex.neighbors.map { Relief.centre(of: $0) }
        let layout = HexLayout(size: 1)
        var placed: [(x: Float, z: Float, radius: Float)] = []
        var pieces: [Piece] = []
        for (number, recipe) in recipes(tile).enumerated() {
            let roll = { (salt: Int32) in Noise.unit(Int32(hex.q) &* 31 &+ Int32(number), Int32(hex.r) &* 17 &+ salt, 0x5CA7) }
            guard roll(1) < recipe.chance else { continue }
            let span = recipe.count.upperBound - recipe.count.lowerBound + 1
            let count = recipe.count.lowerBound + min(Int(roll(2) * Float(span)), span - 1)
            for item in 0..<count {
                let draw = { (salt: Int32) in roll(100 &+ Int32(item) &* 13 &+ salt) }
                let scale = recipe.scale.lowerBound + (recipe.scale.upperBound - recipe.scale.lowerBound) * draw(0)
                let radius = footprint(recipe.furnishing) * scale
                for attempt in 0..<14 {
                    // A feature tries the heart first; the rest anywhere in the hex.
                    let x: Float, z: Float
                    if attempt == 0 && recipe.central {
                        (x, z) = (centre.x, centre.z)
                    } else {
                        x = centre.x + (draw(Int32(attempt) * 2 + 1) * 2 - 1) * Relief.hexSpacing / 2
                        z = centre.z + (draw(Int32(attempt) * 2 + 2) * 2 - 1)
                    }
                    guard layout.hex(atX: Double(x), y: Double(z)) == hex else { continue }
                    func distance(_ p: (x: Float, z: Float)) -> Float { ((x - p.x) * (x - p.x) + (z - p.z) * (z - p.z)).squareRoot() }
                    if clearHeart && distance(heartPoint) < heart + radius { continue }
                    if neighbours.contains(where: { distance($0) < heart + radius }) { continue }
                    if nearHolds.contains(where: { distance($0) < HoldLayout.reach + radius }) { continue }
                    if placed.contains(where: { distance(($0.x, $0.z)) < ($0.radius + radius) * recipe.closeness }) { continue }
                    placed.append((x, z, radius))
                    let y = relief.height(atX: x, z: z) - sink
                    let turn = draw(99) * 2 * .pi
                    pieces.append(Piece(key: .furnishing(recipe.furnishing),
                                        transform: .translation(Vec3(x, y, z)) * .rotationY(turn) * .scale(scale), hex: hex))
                    break
                }
            }
        }
        return pieces
    }

    struct Recipe {
        var furnishing: Furnishing
        var count: ClosedRange<Int>
        var scale: ClosedRange<Float>
        /// The chance it is there at all.
        var chance: Float = 1
        /// Whether it tries the hex's heart first.
        var central = false
        /// How near to others it may stand, against both their reaches.
        var closeness: Float = 0.8
    }

    /// What a tile is furnished with: its feature's first, then its terrain's.
    static func recipes(_ tile: Tile) -> [Recipe] {
        var list: [Recipe] = []
        switch tile.feature {
        case .moonsaltBed: list.append(Recipe(furnishing: .saltCrystals, count: 3...5, scale: 1.3...1.8))
        case .elderGrove: list.append(Recipe(furnishing: .elderTree, count: 1...1, scale: 0.9...1.1, central: true))
        case .stoneSeam: list.append(Recipe(furnishing: .stoneFace, count: 1...1, scale: 0.9...1.1, central: true))
        case .darkLoam: list.append(Recipe(furnishing: .furrows, count: 1...2, scale: 0.75...0.9, central: true))
        case .drownedRuin: list.append(Recipe(furnishing: .ruin, count: 1...1, scale: 0.9...1.1, central: true))
        case nil: break
        }
        switch tile.terrain {
        case .still, .ford:
            // Nothing stands on the lake's bed, laid bare a while or not.
            break
        case .shallows:
            list.append(Recipe(furnishing: .reeds, count: 0...2, scale: 0.8...1.2))
        case .strand:
            list += [Recipe(furnishing: .reeds, count: 1...3, scale: 0.8...1.2), Recipe(furnishing: .driftwood, count: 0...2, scale: 0.8...1.3),
                     Recipe(furnishing: .boulder, count: 0...1, scale: 0.6...1.0),
                     Recipe(furnishing: .deadTree, count: 1...1, scale: 0.8...1.1, chance: 0.15),
                     Recipe(furnishing: .pebbles, count: 1...2, scale: 0.8...1.2)]
        case .saltFlat:
            list += [Recipe(furnishing: .saltCrystals, count: 2...4, scale: 0.5...0.9),
                     Recipe(furnishing: .deadTree, count: 1...1, scale: 0.8...1.2, chance: 0.2),
                     Recipe(furnishing: .boulder, count: 0...1, scale: 0.5...0.8),
                     Recipe(furnishing: .pebbles, count: 1...1, scale: 0.7...1.0, chance: 0.5)]
        case .greyfield:
            list += [Recipe(furnishing: .grass, count: 3...6, scale: 0.8...1.4), Recipe(furnishing: .boulder, count: 0...1, scale: 0.6...1.0),
                     Recipe(furnishing: .standingStone, count: 1...1, scale: 0.8...1.0, chance: 0.06),
                     Recipe(furnishing: .heather, count: 1...1, scale: 0.8...1.2, chance: 0.4),
                     Recipe(furnishing: .birch, count: 1...1, scale: 0.8...1.1, chance: 0.06)]
        case .blackwood:
            list += [Recipe(furnishing: .fir, count: 6...9, scale: 0.8...1.35, closeness: 0.7),
                     Recipe(furnishing: .deadTree, count: 1...1, scale: 0.9...1.2, chance: 0.4),
                     Recipe(furnishing: .boulder, count: 0...1, scale: 0.6...1.0),
                     Recipe(furnishing: .birch, count: 1...1, scale: 0.85...1.1, chance: 0.25),
                     Recipe(furnishing: .fern, count: 1...3, scale: 0.8...1.2, closeness: 0.6)]
        case .barrow:
            list += [Recipe(furnishing: .barrowMound, count: 1...1, scale: 0.8...1.0, chance: 0.6, central: true),
                     Recipe(furnishing: .standingStone, count: 1...2, scale: 0.8...1.2, chance: 0.45),
                     Recipe(furnishing: .grass, count: 2...3, scale: 0.8...1.2), Recipe(furnishing: .boulder, count: 0...1, scale: 0.6...1.0),
                     Recipe(furnishing: .heather, count: 1...2, scale: 0.8...1.2)]
        case .spine:
            list += [Recipe(furnishing: .crag, count: 2...3, scale: 0.9...1.5), Recipe(furnishing: .boulder, count: 1...2, scale: 0.8...1.4),
                     Recipe(furnishing: .heather, count: 1...1, scale: 0.7...1.0, chance: 0.3)]
        }
        return list
    }

    /// How far a furnishing reaches from its foot across the ground, at
    /// its own size.
    public static func footprint(_ furnishing: Furnishing) -> Float {
        footprints[furnishing] ?? 0
    }

    private static let footprints: [Furnishing: Float] = Dictionary(uniqueKeysWithValues: Furnishing.allCases.map { furnishing in
        (furnishing, Library.model(.furnishing(furnishing)).mesh.vertices.reduce(0) {
            max($0, ($1.position.x * $1.position.x + $1.position.z * $1.position.z).squareRoot())
        })
    })
}
