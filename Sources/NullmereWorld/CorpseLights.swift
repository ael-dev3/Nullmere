import Foundation
import NullmereCore
import NullmereModels

/// A field where a keeper's dead lie unburied, as the stage is given it:
/// where, how many troops lie there, and how many watches until the dark
/// of the moon, when as many as `GameState.unquietAt` or more rise.
public struct UnburiedSight: Equatable, Sendable {
    public let at: Hex
    public let troops: Int
    public let darkIn: Int

    public init(at: Hex, troops: Int, darkIn: Int) {
        self.at = at
        self.troops = troops
        self.darkIn = darkIn
    }

    /// Whether they will rise as Barrowkin at the dark of the moon, unless
    /// buried; the land takes back fewer.
    public var rises: Bool { troops >= GameState.unquietAt }

    /// Barrowkin risen at `level`, carrying the lights of the field they
    /// rose from: as many as hung over it, as bright as on the eve of the
    /// dark.
    public static func risen(at hex: Hex, level: Int) -> UnburiedSight {
        UnburiedSight(at: hex, troops: GameState.unquietAt + max(level - 1, 0) * GameState.unquietPerLevel, darkIn: 1)
    }

    /// The fields of dead whose lights hang at `watch`, `darkIn` watches from
    /// the dark of the moon: every one given, unless its dead still lie
    /// quiet, as they do the watch the first of them fell and any watch a
    /// blow is struck on the field or from it (`blows`). The lights kindle
    /// once a field falls quiet, so no battle is fought under them.
    public static func kindled(_ fields: [FieldOfDead], watch: Int, darkIn: Int, blows: [FieldBlow] = []) -> [UnburiedSight] {
        let fought = Set(blows.filter { $0.watch >= watch }.flatMap { [$0.at, $0.from] })
        return fields.compactMap { field in
            guard field.since < watch, !fought.contains(field.at) else { return nil }
            return UnburiedSight(at: field.at, troops: field.troops, darkIn: darkIn)
        }
    }
}

extension WorldStage {
    /// The corpse-lights' hue, linear: a cold, pale green no fire, lamp or
    /// mark of the realm burns, so they are never taken for a hearth.
    static let corpseLight = Vec3(0.40, 0.92, 0.80)
    /// The Barrowkin's colour, the dead risen: a pale, cold grey-green, no
    /// House's.
    public static let barrowkinColour = Vec4(0.58, 0.74, 0.70, 1)
    /// Seconds Barrowkin risen this watch take to come up out of the dark,
    /// from unseen to whole.
    public static let risingSeconds: Float = 2.5

    /// How much of Barrowkin risen this watch shows `age` seconds after the
    /// keeper first sees them: from nothing to whole, slow to start and slow
    /// to finish; whole at once where motion is reduced.
    public static func risenShowing(age: Float, still: Bool = false) -> Float {
        guard !still else { return 1 }
        let t = min(max(age / risingSeconds, 0), 1)
        return t * t * (3 - 2 * t)
    }
    /// The most fields lit at once, nearest the view first, and the most
    /// lights over one.
    static let corpseFieldsMost = 24
    static let corpseLightsMost = 6
    /// The smallest a corpse-light and its glow show on the screen, in
    /// points, however far the view; and the least they are across in the
    /// world, close in, where the glow is a halo about its flame: a disc
    /// facing the eye among men seen from steeply above, so it looks larger
    /// beside them than it is.
    static let corpseFlamePoints: Float = 2.0, corpseGlowPoints: Float = 8
    static let corpseFlameNearest: Float = 0.03, corpseGlowNearest: Float = 0.07
    /// How high over the field they hang, the lowest and how much higher
    /// the highest; how far each strays about its own place; and how wide of
    /// the field's heart they gather.
    static let corpseHeight: Float = 0.09, corpseHigher: Float = 0.2, corpseWander: Float = 0.1
    static let corpseNearest: Float = 0.16, corpseFarthest: Float = 0.42

    /// How many lights hang over a field of `troops` unburied: one over a
    /// few, two over three thousand or more; over a field that will rise,
    /// three and one more for every level its Barrowkin would rise at past
    /// the first, at most six.
    public static func corpseLightCount(troops: Int) -> Int {
        guard troops > 0 else { return 0 }
        guard troops >= GameState.unquietAt else { return troops < 3_000 ? 1 : 2 }
        return min(corpseLightsMost, 3 + (troops - GameState.unquietAt) / GameState.unquietPerLevel)
    }

    /// How strongly a field's lights burn: faint a month from the dark of
    /// the moon and full on its eve, over a field that will rise; over one the
    /// land will take back never more than a glimmer, fainter however near
    /// the dark than one that will rise at its faintest. Dead fallen at the
    /// dark itself wait the month round.
    public static func corpseStrength(_ sight: UnburiedSight) -> Float {
        let month = GameState.lunarMonth
        let left = sight.darkIn <= 0 ? month : min(sight.darkIn, month)
        let near = 1 - Float(left - 1) / Float(month - 1)
        return sight.rises ? 0.35 + 0.65 * near : 0.15 + 0.15 * near
    }

    /// Seconds a buried field's lights take to rise from it into the night
    /// and fade.
    public static let releaseSeconds: Float = 6
    /// How high over the field they climb as they go.
    public static let releaseHeight: Float = 1.4

    /// The lights of a field just buried, `age` seconds after the keeper
    /// saw it buried: each corpse-light that hung over it rising from its
    /// place, drawing in toward the barrow's heart as it climbs, slowing
    /// and fading, gone after `releaseSeconds`; as many as hung over the
    /// field, as bright as on the eve of the dark. The dead released. Light
    /// only: they hide nothing.
    public func releasedLights(at hex: Hex, troops: Int, age: Float, scale: Double) -> [Mote] {
        guard age >= 0, age < WorldStage.releaseSeconds else { return [] }
        let count = WorldStage.corpseLightCount(troops: troops)
        guard count > 0 else { return [] }
        let t = age / WorldStage.releaseSeconds
        let climbed = 1 - (1 - t) * (1 - t)
        let fade = min(age * 4, 1) * (1 - t) * (1 - t)
        let points = Float(max(scale, 1))
        let centre = Relief.centre(of: hex)
        let turned = WorldStage.phase(of: hex, salt: 101)
        var motes: [Mote] = []
        for index in 0..<count {
            let off = WorldStage.phase(of: hex, salt: 107 + 7 * index) / 20 - 0.5
            let bearing = turned + (Float(index) + 0.6 * off) * 2 * .pi / Float(count) + t * 1.2
            let reach = (WorldStage.corpseNearest
                + (WorldStage.corpseFarthest - WorldStage.corpseNearest) * (WorldStage.phase(of: hex, salt: 131 + index) / 20)) * (1 - 0.6 * t)
            let height = WorldStage.corpseHeight + WorldStage.corpseHigher * (WorldStage.phase(of: hex, salt: 151 + index) / 20)
            let x = centre.x + reach * Float(cos(Double(bearing))), z = centre.z + reach * Float(sin(Double(bearing)))
            let at = Vec3(x, ground(atX: x, z: z) + height + WorldStage.releaseHeight * climbed, z)
            let light = WorldStage.corpseLight * (1.5 * fade)
            motes.append(Mote(at: at, size: max(WorldStage.corpseFlameNearest, WorldStage.corpseFlamePoints / points), light: light, cover: 0))
            motes.append(Mote(at: at, size: max(WorldStage.corpseGlowNearest, WorldStage.corpseGlowPoints / points), light: light * 0.1, cover: 0))
        }
        return motes
    }

    /// The corpse-lights over the fields where the dead lie unburied, the
    /// nearest `corpseFieldsMost` to `focus`: each a small cold flame hanging
    /// low over the field, spaced about its heart each at its own height so
    /// no two read as a pair, straying slowly about its own place and
    /// breathing in and out in its own time, in a soft glow that keeps its
    /// size on the screen as the view draws away, so a field that will rise
    /// is seen from across the realm; and one light over each field, so the
    /// ground under them lies in their cold light.
    /// The more lie there the more lights, and the nearer the dark of the
    /// moon the brighter (`corpseLightCount`, `corpseStrength`). Where motion
    /// is reduced (`still`) they hang still and steady. Light only: they hide
    /// nothing.
    public func corpseLights(_ sights: [UnburiedSight], near focus: Vec3, scale: Double, time: Float,
                             still: Bool = false) -> (motes: [Mote], lights: [PointLight]) {
        guard !sights.isEmpty else { return ([], []) }
        func far(_ hex: Hex) -> Float {
            let centre = Relief.centre(of: hex)
            return (centre.x - focus.x) * (centre.x - focus.x) + (centre.z - focus.z) * (centre.z - focus.z)
        }
        let nearest = sights.sorted { (far($0.at), $0.at.q, $0.at.r) < (far($1.at), $1.at.q, $1.at.r) }.prefix(WorldStage.corpseFieldsMost)
        let points = Float(max(scale, 1))
        var motes: [Mote] = [], lights: [PointLight] = []
        for sight in nearest {
            let count = WorldStage.corpseLightCount(troops: sight.troops)
            guard count > 0 else { continue }
            let strength = WorldStage.corpseStrength(sight)
            let centre = Relief.centre(of: sight.at)
            // Spaced about the heart, each a little off its place in the ring.
            let turned = WorldStage.phase(of: sight.at, salt: 101)
            for index in 0..<count {
                let own = WorldStage.phase(of: sight.at, salt: 103 + 7 * index)
                let off = WorldStage.phase(of: sight.at, salt: 107 + 7 * index) / 20 - 0.5
                let bearing = turned + (Float(index) + 0.6 * off) * 2 * .pi / Float(count)
                let reach = WorldStage.corpseNearest
                    + (WorldStage.corpseFarthest - WorldStage.corpseNearest) * (WorldStage.phase(of: sight.at, salt: 131 + index) / 20)
                let height = WorldStage.corpseHeight + WorldStage.corpseHigher * (WorldStage.phase(of: sight.at, salt: 151 + index) / 20)
                var x = centre.x + reach * Float(cos(Double(bearing)))
                var z = centre.z + reach * Float(sin(Double(bearing)))
                var rise: Float = 0, life: Float = 1
                if !still {
                    x += WorldStage.corpseWander * Float(cos(Double(time * 0.23 + own)))
                    z += WorldStage.corpseWander * Float(sin(Double(time * 0.19 + 2 * own)))
                    rise = 0.05 * Float(sin(Double(time * 0.9 + own)))
                    life = 0.3 + 0.7 * (0.5 + 0.5 * Float(sin(Double(time * 0.45 + 3 * own))))
                }
                let at = Vec3(x, ground(atX: x, z: z) + height + rise, z)
                let flame = WorldStage.corpseLight * (1.5 * strength * life)
                motes.append(Mote(at: at, size: max(WorldStage.corpseFlameNearest, WorldStage.corpseFlamePoints / points), light: flame, cover: 0))
                motes.append(Mote(at: at, size: max(WorldStage.corpseGlowNearest, WorldStage.corpseGlowPoints / points), light: flame * 0.1, cover: 0))
            }
            let heart = Vec3(centre.x, ground(atX: centre.x, z: centre.z) + 0.25, centre.z)
            lights.append(PointLight(at: heart, reach: 1.1, colour: WorldStage.corpseLight * (1.6 * strength)))
        }
        return (motes, lights)
    }
}
