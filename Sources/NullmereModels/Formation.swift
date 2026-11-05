import Foundation
import NullmereCore

/// How a company is drawn in its hex: how many figures it shows by its
/// health and its muster, and where each stands. Offsets are from the hex's heart in the
/// company's own frame, facing +z, front rank first; the renderer turns
/// them to the company's heading. Every figure stands within the hex
/// whichever way it is turned, and the company, with its commander when it
/// is led, is centred on the heart.
public enum Formation {
    /// The inner radius of a hex: the farthest a figure may reach from the
    /// heart, turned any way, and stay within it.
    public static let hexInner: Float = Relief.hexSpacing / 2

    struct Ranks {
        /// Figures shown whole.
        var strength: Int
        /// Figures to a rank.
        var file: Int
        /// Between figures in a rank.
        var spacing: Float
        /// Between ranks.
        var depth: Float
        /// Every other rank shifted half a place.
        var staggered = false
        /// From a commander to the front rank it leads.
        var lead: Float = 0.42
    }

    static func ranks(_ key: ModelKey) -> Ranks? {
        switch key.canonical {
        case .signature(let heritage):
            return ranks(.figure(heritage.signature, tier: ModelKey.tiers(of: heritage.signature)))
        case .figure(let kind, _):
            switch kind {
            case .spear: return Ranks(strength: 9, file: 3, spacing: 0.2, depth: 0.2)
            case .bow: return Ranks(strength: 8, file: 4, spacing: 0.18, depth: 0.22, staggered: true)
            case .rider: return Ranks(strength: 3, file: 3, spacing: 0.27, depth: 0.6, lead: 0.58)
            case .mangonel: return Ranks(strength: 2, file: 2, spacing: 0.32, depth: 0.5, lead: 0.62)
            case .lantern: return Ranks(strength: 3, file: 2, spacing: 0.28, depth: 0.26, staggered: true)
            case .founder: return Ranks(strength: 3, file: 3, spacing: 0.27, depth: 0.42, lead: 0.36)
            }
        case .wild(let tier):
            switch tier {
            case 1: return Ranks(strength: 5, file: 3, spacing: 0.24, depth: 0.26, staggered: true)
            case 2: return Ranks(strength: 4, file: 2, spacing: 0.3, depth: 0.3, staggered: true)
            default: return Ranks(strength: 2, file: 2, spacing: 0.42, depth: 0.42)
            }
        default:
            return nil
        }
    }

    /// The most figures a company drilled beyond its first muster shows,
    /// in ranks of how many: as many more as still stand within the hex,
    /// with its commander at its head. Lanterns and Founders drill none.
    static func drilled(_ kind: UnitKind) -> (most: Int, file: Int)? {
        switch kind {
        case .spear: return (16, 4)
        case .bow: return (16, 6)
        case .rider: return (4, 4)
        case .mangonel: return (2, 2)
        case .lantern, .founder: return nil
        }
    }

    /// How much of the more a drilled company shows, by its muster in
    /// percent of its first: none undrilled, half at twice its first muster,
    /// all of it at four times.
    public static func drilledShare(muster: Int) -> Float {
        muster <= 100 ? 0 : min(1, log2(Float(muster) / 100) / 2)
    }

    /// Its ranks as drilled: the more figures, in wider ranks once there
    /// are more than at first. Only a House's companies drill; the wilds
    /// stand as they are.
    static func ranks(_ key: ModelKey, muster: Int) -> Ranks? {
        guard var ranks = ranks(key) else { return nil }
        let kind: UnitKind
        switch key.canonical {
        case .figure(let figure, _): kind = figure
        case .signature(let heritage): kind = heritage.signature
        default: return ranks
        }
        guard let drilled = drilled(kind) else { return ranks }
        let more = Int((Float(drilled.most - ranks.strength) * drilledShare(muster: muster)).rounded())
        guard more > 0 else { return ranks }
        ranks.strength += more
        ranks.file = drilled.file
        return ranks
    }

    /// The most figures a company of this kind shows, whole: a figure's
    /// key for a House's company, a wild one's for the far country; one
    /// for anything else. More for a company drilled beyond its first
    /// muster, its muster in percent of its first.
    public static func strength(_ key: ModelKey, muster: Int = 100) -> Int {
        ranks(key, muster: muster)?.strength ?? 1
    }

    /// How many figures a company shows at a health from 0 to 100: none
    /// once it is gone, at least one while it stands, all of them whole,
    /// and fewer as it is worn down.
    public static func count(_ key: ModelKey, health: Int, muster: Int = 100) -> Int {
        guard health > 0 else { return 0 }
        let full = strength(key, muster: muster)
        return min(full, max(1, Int((Float(full) * Float(min(health, 100)) / 100).rounded(.up))))
    }

    /// Where each figure the company shows stands. A company led by a
    /// commander falls back to leave the front to its leader.
    public static func offsets(_ key: ModelKey, health: Int, led: Bool = false, muster: Int = 100) -> [Vec3] {
        let shown = count(key, health: health, muster: muster)
        guard shown > 0 else { return [] }
        guard let ranks = ranks(key, muster: muster) else { return [.zero] }
        var offsets: [Vec3] = []
        var rank = 0
        while offsets.count < shown {
            let inRank = min(ranks.file, shown - offsets.count)
            let stagger: Float = ranks.staggered ? (rank % 2 == 0 ? -0.25 : 0.25) * ranks.spacing : 0
            for slot in 0..<inRank {
                let x = (Float(slot) - Float(inRank - 1) / 2) * ranks.spacing + stagger
                offsets.append(Vec3(x, 0, -Float(rank) * ranks.depth))
            }
            rank += 1
        }
        let middle = middle(ranks, rankCount: rank, led: led)
        return offsets.map { $0 - Vec3(0, 0, middle) }
    }

    /// Where a commander rides, at the head of the company it leads.
    public static func commander(_ key: ModelKey, health: Int = 100, muster: Int = 100) -> Vec3 {
        guard let ranks = ranks(key, muster: muster) else { return .zero }
        let rankCount = (max(count(key, health: health, muster: muster), 1) + ranks.file - 1) / ranks.file
        return Vec3(0, 0, ranks.lead - middle(ranks, rankCount: rankCount, led: true))
    }

    /// The middle of the company from its back rank to its front, or to
    /// its commander when it is led.
    static func middle(_ ranks: Ranks, rankCount: Int, led: Bool) -> Float {
        let back = -Float(rankCount - 1) * ranks.depth
        return (back + (led ? ranks.lead : 0)) / 2
    }

    /// Troops a figure stands for in a field of battle's throng.
    public static let troopsPerThrongFigure = 500
    /// The most figures one company shows in a field of battle.
    public static let throngMost = 36

    /// How many figures a company shows in a field of battle with so many
    /// troops standing: at least its formation whole, one more for every
    /// `troopsPerThrongFigure`, up to `throngMost`; none once none stand.
    public static func throngCount(_ key: ModelKey, troops: Int, muster: Int = 100) -> Int {
        guard troops > 0 else { return 0 }
        return min(throngMost, max(strength(key, muster: muster), troops / troopsPerThrongFigure))
    }

    /// Where a throng's figures stand: rank after rank of eight pressed
    /// toward the company's front (+z) and filling its hex back to the
    /// rear, each nudged off the line so the mass reads as men, not a grid;
    /// every figure within the hex.
    public static func throng(count: Int, seed: Int) -> [Vec3] {
        guard count > 0 else { return [] }
        let file = 8, spacing: Float = 0.105, depth: Float = 0.11
        let ranks = (count + file - 1) / file
        let front = min(Float(ranks - 1) * depth / 2 + 0.06, hexInner * 0.8)
        var offsets: [Vec3] = []
        for index in 0..<count {
            let rank = index / file, place = index % file
            let inRank = min(file, count - rank * file)
            var x = (Float(place) - Float(inRank - 1) / 2) * spacing + (rank % 2 == 1 ? spacing / 2 : 0)
            var z = front - Float(rank) * depth
            // A little out of line, the same each time it is drawn.
            let h = UInt32(truncatingIfNeeded: seed &* 7_919 &+ index &* 104_729)
            // A battle's ranks are broken: each man well off his place, and
            // the front ranks surging forward unevenly where the press is.
            x += (Float(h % 97) / 97 - 0.5) * spacing * 0.95
            z += (Float((h / 97) % 89) / 89 - 0.5) * depth * 0.9
            if rank < 2 { z += Float((h / 8_633) % 61) / 61 * depth * 0.8 }
            let reach = (x * x + z * z).squareRoot(), most = hexInner - 0.05
            if reach > most { x *= most / reach; z *= most / reach }
            offsets.append(Vec3(x, 0, z))
        }
        return offsets
    }
}
