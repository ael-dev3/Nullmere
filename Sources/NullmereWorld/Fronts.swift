import Foundation
import NullmereCore
import NullmereModels

/// Where two hosts meet in a field of battle. A company standing in a
/// field stood on the heart of its own hex, the foremost of its throng
/// about half a tile short of the foe's, so the two struck at the air
/// between them. Now a company that fights hand to hand presses toward
/// the foe beside it until its foremost man stands just short of the line
/// midway between their two hexes, the foe pressing the same way from
/// the other side, so the two fronts meet on that line, where their
/// steel flashes; it eases forward as it comes to the fight and back to
/// its own ground as it leaves it.
extension WorldStage {
    /// The room left between two fronts that meet, in the world's units:
    /// a man's breadth, so the ranks meet and do not pass through each other.
    public static let frontGap: Float = 0.06
    /// The most of the way toward the foe's heart a company presses.
    public static let pressMost: Float = 0.4
    /// Seconds a company takes to press up to the foe, or to draw back.
    public static let pressTime: Float = 0.7
    /// How far toward the foe a company's blow carries it while it is
    /// pressed up to the foe's front, against `blowReach` on open ground:
    /// a shove into the foe's front ranks, not on through them.
    public static let pressedBlowReach: Float = 0.3
    public static let blowReach: Float = 0.6

    /// The whole way a company standing at the foe presses toward it from
    /// its own heart: until its foremost man, `front` ahead of its heart,
    /// stands half of `frontGap` short of the line midway between the two
    /// hearts, and never more than `pressMost` of the way; none where its
    /// ranks already reach the line, or where the two stand on one hex.
    public static func pressWay(from heart: Vec3, toward foe: Vec3, front: Float) -> Vec3 {
        let way = Vec3(foe.x - heart.x, 0, foe.z - heart.z)
        let length = way.length
        guard length > 0.0001 else { return Vec3(0, 0, 0) }
        let room = min(length / 2 - front - frontGap / 2, length * pressMost)
        guard room > 0 else { return Vec3(0, 0, 0) }
        return way * (room / length)
    }

    /// How far before its heart a company's foremost man stands, in the
    /// world's units, its throng drawn as `companies(_:houses:into:)` draws it.
    public static func frontReach(throng: Int, unit: Int, spread: Float) -> Float {
        (Formation.throng(count: throng, seed: unit).map(\.z).max() ?? 0) * spread * figureScale
    }

    /// Where the foe stands that each company standing in a field of
    /// battle fights hand to hand, by the company's id: the one it fights
    /// (`Fighter.foe`) where that one still stands in the field beside it,
    /// or else the foe beside it with the lowest id. A company that fights
    /// at a distance, bows and engines, presses no foe; nor one with none
    /// beside it.
    public static func handToHand(in state: GameState) -> [Int: Hex] {
        var found: [Int: Hex] = [:]
        for field in state.fieldsOfBattle {
            let standing = field.fighters.filter(\.standing).compactMap { fighter in
                state.unit(fighter.unit).map { (fighter: fighter, at: $0.position) }
            }
            guard standing.count > 1 else { continue }
            for (fighter, at) in standing where fighter.kind.isMilitary && fighter.kind.range <= 1 {
                let beside = standing.filter { $0.fighter.side != fighter.side && $0.at.distance(to: at) == 1 }
                let foe = beside.first { $0.fighter.unit == fighter.foe }
                    ?? beside.min { $0.fighter.unit < $1.fighter.unit }
                if let foe { found[fighter.unit] = foe.at }
            }
        }
        return found
    }
}

/// A company's press toward the foe it stands at in a field of battle,
/// as far as it has come: kept from frame to frame, so it eases up to the
/// foe and back.
public struct FrontPress: Equatable, Sendable {
    /// The whole way to the front, from its heart (`WorldStage.pressWay`).
    public var way: Vec3
    /// How much of the way it has come, from none to all.
    public var amount: Float
    /// The world's time it was last stepped, in seconds.
    public var at: Double

    public init(way: Vec3, amount: Float, at: Double) {
        self.way = way
        self.amount = amount
        self.at = at
    }

    /// Where it stands from its heart: slow to start and slow to stop.
    public var offset: Vec3 {
        let t = max(0, min(amount, 1))
        return way * (t * t * (3 - 2 * t))
    }

    /// The press stepped on to `time`: toward `way` while the company
    /// stands at the foe, back to its own ground once it no longer does,
    /// nil once it is back. A company first seen already at the foe, when
    /// the keeper's eye first falls on a fight under way, stands at the
    /// front at once; one that comes to the fight eases up to it.
    public static func step(_ kept: FrontPress?, toward way: Vec3?, at time: Double, firstSeen: Bool = false) -> FrontPress? {
        let elapsed = Float(max(time - (kept?.at ?? time), 0)) / WorldStage.pressTime
        if let way {
            let start = kept?.amount ?? (firstSeen ? 1 : 0)
            return FrontPress(way: way, amount: min(start + elapsed, 1), at: time)
        }
        guard var press = kept else { return nil }
        press.amount = max(press.amount - elapsed, 0)
        press.at = time
        return press.amount > 0 ? press : nil
    }
}

/// A hold's walls answering a blow struck on their ward: the rules strike
/// back at a company that strikes a ward from beside it, the harder the
/// higher its walls (`GameState.strike(hold:with:)`); its bowmen loose a
/// flight of arrows from the battlements that face the striker, a beat
/// after the blow lands, one after another along the wall, coming down
/// about the striker; from the keep's height where the hold has no walls.
extension WorldStage {
    /// How high on its walls, and on its keep, a hold's bowmen loose from.
    public static let wallWalk: Float = 0.24
    public static let keepLoft: Float = 0.4
    /// How long after a blow on a ward begins the walls answer it.
    public static let wallAnswer: Float = 0.18
    /// How many arrows the walls loose at a blow, and how far apart along them.
    public static let wallArrows = 4
    public static let wallArrowsApart: Float = 0.16

    /// The walls' arrows in flight `age` seconds after a blow on their ward
    /// began, from the hold's heart `hold` at the striker standing at
    /// `striker`: none before the walls answer or once the last has come
    /// down, nor at a striker on the hold's own hex.
    public static func wallVolley(from hold: Vec3, at striker: Vec3, walled: Bool, age: Float, seed: Int) -> [ArrowFlight] {
        var way = Vec3(striker.x - hold.x, 0, striker.z - hold.z)
        let length = way.length
        guard length > 0.0001 else { return [] }
        way = way * (1 / length)
        let side = Vec3(-way.z, 0, way.x)
        let reach = walled ? HoldLayout.wallRadius * 0.9 : 0.25
        let loft = walled ? wallWalk : keepLoft
        var flights: [ArrowFlight] = []
        for shaft in 0..<wallArrows {
            let s = Float(shaft)
            let progress = (age - wallAnswer - s * 0.06) / Happenings.arrowFlight
            guard progress >= 0, progress <= 1 else { continue }
            let along = (s - Float(wallArrows - 1) / 2) * wallArrowsApart
            let wobble = 0.08 * Float(sin(Double(seed % 977) * 1.7 + Double(s) * 2.3))
            let from = hold + way * reach + side * along + Vec3(0, loft, 0)
            let to = striker + side * (along * 0.7 + wobble) + Vec3(0, 0.05, 0)
            flights.append(ArrowFlight(from: from, to: to, progress: progress))
        }
        return flights
    }
}
