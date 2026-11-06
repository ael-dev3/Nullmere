import Foundation
import NullmereCore

/// What the world reads of the land's marks, made in Blender with them
/// (Art/blender/marks.py and tokens.py): where a rally's fire burns, for
/// its smoke, and where a crest's shield hangs on its board.
enum Land {
    /// Where a rally camp's fire burns, in its own frame.
    static let rallyFire = Vec3(0.24, 0.135, 0.2)

    /// Where a crest's shield hangs on its board, its face toward +z.
    static let crestFace = Vec3(0, 0.42, 0.014)
}
