import Foundation
import NullmereCore

/// The lake heard at its edge near the view: where its own water, the open
/// Still and the shallows, meets the land, about the view's middle as far
/// as the view reaches, each stretch the nearer the louder and from where it
/// lies across the view; heard only as the view comes down to the land, and
/// never water the House has not seen. Out on the open lake, far from any
/// strand, the Still is silent.
public enum ShoreSound {
    /// How near the view must come for the shore to be heard at all, and
    /// how near before it is heard at its fullest: from the lake's own view
    /// a whisper, a hold's land close by in full.
    public static let faintest = 24.0
    public static let fullest = 64.0
    /// How many hexes of strand about the view's middle sound as loud as the
    /// shore gets.
    static let full: Float = 6

    /// The lake's own water: the open Still and the shallows by its shore,
    /// not a stream, nor the Moonford laid bare.
    public static func isLake(_ terrain: Terrain) -> Bool {
        terrain == .still || terrain == .shallows
    }

    /// How far from the view's middle, in hexes, the lake's edge is looked
    /// for: about half the view's width at this nearness.
    public static func reach(at scale: Double) -> Int {
        Int(min(max((600 / max(scale, 1) / 1.5).rounded(.up), 3), 12))
    }

    /// The lake's hexes at the land's edge within `reach` of `centre`, those
    /// `known` says the House has seen, nearest first.
    public static func edges(about centre: Hex, reach: Int, in map: WorldMap, known: (Hex) -> Bool) -> [Hex] {
        var found: [Hex] = []
        for hex in centre.spiral(reach) {
            guard let tile = map[hex], isLake(tile.terrain), known(hex) else { continue }
            if hex.neighbors.contains(where: { map[$0].map { !$0.terrain.isWater } ?? false }) {
                found.append(hex)
            }
        }
        return found
    }

    /// The shore as heard from `camera`: how loud, 0 to 1, and from where
    /// across the view, -1 (left) to 1 (right); nil where none is heard.
    public static func heard(_ edges: [Hex], from camera: Camera) -> (level: Float, pan: Float)? {
        let near = Float(min(max((camera.scale - faintest) / (fullest - faintest), 0), 1))
        guard near > 0 else { return nil }
        var total: Float = 0, panned: Float = 0
        for hex in edges {
            let heard = camera.hearing(of: hex)
            // The hearing's floor is for cues far off; strand so far is silent.
            let nearby = (heard.gain - 0.3) / 0.7
            guard nearby > 0.01 else { continue }
            total += nearby
            panned += nearby * heard.pan
        }
        guard total > 0.001 else { return nil }
        return (min(total / full, 1) * near, min(max(panned / total, -1), 1))
    }

    /// How much quieter the shore laps as the Still lies calmer: its calm,
    /// zero to ten, stilling it to a whisper at the calmest.
    public static func stilled(by calm: Int) -> Float {
        1 - 0.075 * Float(min(max(calm, 0), Calm.deepest))
    }
}
