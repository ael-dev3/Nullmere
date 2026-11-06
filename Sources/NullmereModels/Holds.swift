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
}
