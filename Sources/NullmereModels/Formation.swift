import Foundation
import NullmereCore

/// How a company is drawn in its hex: how many figures it shows by its
/// health, and where each stands. Offsets are from the hex's heart in the
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

    /// The most figures a company of this kind shows, whole: a figure's
    /// key for a House's company, a wild one's for the far country; one
    /// for anything else.
    public static func strength(_ key: ModelKey) -> Int {
        ranks(key)?.strength ?? 1
    }

    /// How many figures a company shows at a health from 0 to 100: none
    /// once it is gone, at least one while it stands, all of them whole,
    /// and fewer as it is worn down.
    public static func count(_ key: ModelKey, health: Int) -> Int {
        guard health > 0 else { return 0 }
        let full = strength(key)
        return min(full, max(1, Int((Float(full) * Float(min(health, 100)) / 100).rounded(.up))))
    }

    /// Where each figure the company shows stands. A company led by a
    /// commander falls back to leave the front to its leader.
    public static func offsets(_ key: ModelKey, health: Int, led: Bool = false) -> [Vec3] {
        let shown = count(key, health: health)
        guard shown > 0 else { return [] }
        guard let ranks = ranks(key) else { return [.zero] }
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
    public static func commander(_ key: ModelKey, health: Int = 100) -> Vec3 {
        guard let ranks = ranks(key) else { return .zero }
        let rankCount = (max(count(key, health: health), 1) + ranks.file - 1) / ranks.file
        return Vec3(0, 0, ranks.lead - middle(ranks, rankCount: rankCount, led: true))
    }

    /// The middle of the company from its back rank to its front, or to
    /// its commander when it is led.
    static func middle(_ ranks: Ranks, rankCount: Int, led: Bool) -> Float {
        let back = -Float(rankCount - 1) * ranks.depth
        return (back + (led ? ranks.lead : 0)) / 2
    }
}
