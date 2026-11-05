import Foundation
import NullmereCore

/// How a people builds its keep: the stone or timber of its walls, its dark
/// courses, the trim of its parapet and hall, and its roof, each with its
/// grain where its colour alone would not say it. The common keep is dressed
/// grey stone under slate. (The pitch of each people's roof and the crown on
/// it are made with the keep in Blender: Art/blender/keep.py.)
struct KeepStyle {
    var wall = Palette.stone
    var dark = Palette.stoneDark
    var trim = Palette.stonePale
    var roof = Palette.slate
    /// The grain drawn on the walls and on the roof, where their colours
    /// alone would not say it.
    var wallGrain: Surface?
    var roofGrain: Surface?

    static let common = KeepStyle()
    /// The strand's blue-grey slate.
    static let seaSlate = Vec3(0.26, 0.31, 0.37)

    /// Each people's keep: the Saltborn's salt-white stone; the Fenfolk's
    /// weathered timber under reed; the Blackwood Kin's dark timber under
    /// shingle; the Spinewardens' raw rock under slate; the Mound Clans'
    /// pale stone under turf; the Strandfolk's whitewash under sea-slate.
    static func of(_ heritage: Heritage) -> KeepStyle {
        switch heritage {
        case .saltborn:
            return KeepStyle(wall: Palette.saltCrust, dark: Palette.stonePale, trim: Palette.stoneWhite, roof: Palette.stoneWhite,
                             wallGrain: .stone, roofGrain: .slate)
        case .fenfolk:
            return KeepStyle(wall: Palette.timberGrey, dark: Palette.timberDark, trim: Palette.timberPale, roof: Palette.reed)
        case .blackwood:
            return KeepStyle(wall: Palette.timberDark, dark: Palette.bark, trim: Palette.timber, roof: Palette.barkBlack, roofGrain: .timber)
        case .spinewardens:
            return KeepStyle(wall: Palette.rock, dark: Palette.stoneDark, trim: Palette.stone, roof: Palette.slate)
        case .moundClans:
            return KeepStyle(wall: Palette.stonePale, dark: Palette.earth, trim: Palette.stoneWhite, roof: Palette.moss, roofGrain: .earth)
        case .strandfolk:
            return KeepStyle(wall: Palette.linen, dark: Palette.stoneDark, trim: Palette.stoneWhite, roof: KeepStyle.seaSlate,
                             wallGrain: .stone, roofGrain: .slate)
        }
    }
}

/// Where a hold's keep smokes and its walls stand, and the scaffold round a
/// rising work (the keep and the walls made in Blender: Art.keep, Art.walls).
enum Holds {
    // MARK: The keep

    /// The top of the keep's hall chimney, where its smoke rises: the keep
    /// made in Blender (Art/blender/keep.py) builds it there.
    static func chimney(seat: Bool) -> Vec3 {
        let half: Float = seat ? 0.17 : 0.155, front: Float = seat ? 0.34 : 0.3
        return Vec3(0.13, 0.43, (half - 0.06 + front) / 2)
    }

    // MARK: The walls

    /// The walls' ring: corners on this radius, flats facing ±z with the
    /// gate in the +z flat. Turned 30° (and any sixth), it sits within a
    /// hex with its gate toward a neighbour.
    static let wallRadius: Float = 0.84

    static func wallCorner(_ index: Int) -> Vec3 {
        let angle = Float(index) * .pi / 3
        return Vec3(wallRadius * Float(cos(Double(angle))), 0, wallRadius * Float(sin(Double(angle))))
    }

    // MARK: The scaffold

    /// A frame of poles, ledgers, braces and boards round a work as it
    /// rises: a unit wide, deep and high, x and z from -0.5 to 0.5, for its
    /// piece to stretch to the work.
    static func scaffold() -> Mesh {
        var b = MeshBuilder()
        let pole: Float = 0.022, wood = Palette.timberPale
        let posts = [Vec3(-0.5, 0, -0.5), Vec3(0, 0, -0.52), Vec3(0.5, 0, -0.5), Vec3(0.52, 0, 0), Vec3(0.5, 0, 0.5), Vec3(0, 0, 0.52),
                     Vec3(-0.5, 0, 0.5), Vec3(-0.52, 0, 0)]
        for post in posts {
            b.limb(from: post - Vec3(0, 0.05, 0), to: post + Vec3(0, 1.06, 0), radius: pole, color: wood)
        }
        for level in [Float(0.34), 0.68, 1.0] {
            for index in 0..<posts.count {
                let a = posts[index] + Vec3(0, level, 0), c = posts[(index + 1) % posts.count] + Vec3(0, level, 0)
                b.limb(from: a, to: c, radius: pole * 0.8, color: wood)
            }
        }
        // Braces across each face, and boards to walk on along two sides.
        for (a, c) in [(posts[0], posts[2]), (posts[2], posts[4]), (posts[4], posts[6]), (posts[6], posts[0])] {
            b.limb(from: a, to: c + Vec3(0, 0.68, 0), radius: pole * 0.7, color: Palette.timber)
        }
        for level in [Float(0.34), 0.68] {
            b.box(min: Vec3(-0.5, level, 0.44), max: Vec3(0.5, level + 0.02, 0.56), color: Palette.timberGrey)
            b.box(min: Vec3(0.44, level, -0.5), max: Vec3(0.56, level + 0.02, 0.5), color: Palette.timberGrey)
        }
        b.ladder(from: Vec3(-0.3, 0, 0.62), to: Vec3(-0.3, 0.7, 0.53), width: 0.12, rungs: 4, color: Palette.timber)
        // Near: rope lashed round every joint of post and ledger, rails along
        // the boards, a second ladder up the side and a hoist's beam out
        // from a corner post, its rope hanging to the ground.
        b.fine {
            for post in posts {
                for level in [Float(0.34), 0.68, 1.0] {
                    $0.place(.translation(post + Vec3(0, level - 0.02, 0))) {
                        $0.tube([(pole * 1.3, 0), (pole * 1.3, 0.04)], sides: 4, color: Palette.canvas, twist: .pi / 4)
                    }
                }
            }
            for level in [Float(0.34), 0.68] {
                $0.limb(from: Vec3(-0.5, level + 0.16, 0.53), to: Vec3(0.5, level + 0.16, 0.53), radius: pole * 0.6, color: Palette.timber)
                $0.limb(from: Vec3(0.535, level + 0.16, -0.5), to: Vec3(0.535, level + 0.16, 0.5), radius: pole * 0.6, color: Palette.timber)
            }
            $0.ladder(from: Vec3(0.62, 0, -0.25), to: Vec3(0.53, 0.36, -0.25), width: 0.12, rungs: 3, color: Palette.timber)
            $0.limb(from: Vec3(0.5, 0.98, 0.5), to: Vec3(0.68, 1.03, 0.68), radius: pole * 0.8, color: Palette.timberDark)
            $0.limb(from: Vec3(0.66, 1.02, 0.66), to: Vec3(0.66, 0.12, 0.66), radius: 0.004, sides: 3, color: Palette.linen)
        }
        return b.mesh
    }
}
