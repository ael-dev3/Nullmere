import Foundation
import NullmereCore
import NullmereModels

/// A vigil's light for the fallen as the stage is given it: the water it
/// floats on, the water the lake's current takes it to as the watch turns
/// (none where that is not known), which it is, and how much of its
/// burning is done, 0 just lit to 1 out.
public struct VigilSight: Equatable, Sendable {
    public let at: Hex
    public let next: Hex?
    public let id: Int
    public let burned: Float

    public init(at: Hex, next: Hex?, id: Int, burned: Float) {
        self.at = at
        self.next = next
        self.id = id
        self.burned = burned
    }
}

extension WorldStage {
    /// How high over the water a vigil's flame rides on its float.
    static let vigilFloat: Float = 0.035
    /// A vigil's flame, linear: a candle's gold, little blue in it, so its
    /// core burns pale gold rather than white where its glow and the water
    /// under it add to it.
    static let vigilFlame = Vec3(1.0, 0.64, 0.26)
    /// How far a vigil's light wanders about its way as the water turns it.
    static let vigilWander: Float = 0.09
    /// The smallest a vigil's flame and its glow show on the screen, in
    /// points, however far the view: the lake's lights seen from across it.
    static let vigilFlamePoints: Float = 2.4, vigilGlowPoints: Float = 10

    /// The vigils' lights for the fallen out on the lake, `progress` through
    /// the watch, for a view at `scale`: each a small flame riding the water
    /// in a soft glow of its own, carried on toward the water the current
    /// takes it to as the watch turns, so the light never jumps, wandering a
    /// little about its way and bobbing on the swell, each in its own time;
    /// its flame lowers as its watches run out. Each is a light of its own,
    /// which the water mirrors. From afar each keeps its size on the
    /// screen, so the lake's procession of lights is seen across it. Light
    /// only: they hide nothing.
    public static func vigils(_ sights: [VigilSight], progress: Float, scale: Double, time: Float) -> (motes: [Mote], lights: [PointLight]) {
        var motes: [Mote] = [], lights: [PointLight] = []
        let along = min(max(progress, 0), 1)
        let points = Float(max(scale, 1))
        for sight in sights {
            let from = Relief.centre(of: sight.at)
            let to = sight.next.map { Relief.centre(of: $0) } ?? from
            let own = Float(sight.id % 13) * 0.61
            let x = from.x + (to.x - from.x) * along + vigilWander * Float(cos(Double(time * 0.21 + own)))
            let z = from.z + (to.z - from.z) * along + vigilWander * Float(sin(Double(time * 0.17 + 2 * own)))
            let bob = 0.006 * Float(sin(Double(time * 1.3 + own)))
            let at = Vec3(x, Relief.waterline + vigilFloat + bob, z)
            let flicker = 0.85 + 0.15 * Float(sin(Double(time * 11.3 + own)) * sin(Double(time * 6.1 + 2 * own)))
            let life = 1 - 0.55 * smoothstep(0.6, 1, sight.burned)
            let flame = vigilFlame * (flicker * life)
            motes.append(Mote(at: at, size: max(0.026, vigilFlamePoints / points), light: flame, cover: 0))
            motes.append(Mote(at: at, size: max(0.13, vigilGlowPoints / points), light: flame * 0.08, cover: 0))
            lights.append(PointLight(at: at + Vec3(0, 0.04, 0), reach: 1.2, colour: flame * 2.2))
        }
        return (motes, lights)
    }
}
