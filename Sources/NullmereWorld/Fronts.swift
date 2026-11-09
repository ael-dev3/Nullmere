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
