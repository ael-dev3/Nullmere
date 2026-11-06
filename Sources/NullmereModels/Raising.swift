import Foundation
import NullmereCore

/// How a work is raised: the rig its builders work beside it while it
/// rises in its scaffold, each family's own, each moving as they work, made
/// in Blender (Art/blender/raising.py).
///
/// - The sawpit's: shear legs over the pit, a log swung up on their tackle
///   and lowered again onto the trestle.
/// - The lodge's: a crane on its treadwheel, the wheel walked round and a
///   squared block slewed up to the wall.
/// - The muster hall's: a roof truss swung up between two shear legs onto
///   the barracks' walls.
/// - The beacon's: a gin pole guyed to the ground, its fire basket hauled
///   up the pole and let down.
/// - The granary's: a thatchers' derrick, its jib swung round to the roof
///   with a bundle of straw on its rope, and a ladder up to the eaves.
/// - The quarry's: a tripod over the footings, a windlass wound and a
///   squared stone gripped by its lewis swinging on the rope.
/// - The saltworks': a beam pile-engine driving piles into the shore mud,
///   its ram lifted on the beam's long arm and dropped.
enum Raising {
    /// The families that have a rig of their own while they rise.
    static let families: [BuildingKind] = [.sawpit, .lodge, .beacon, .musterHall, .archive, .granary, .quarry, .saltworks]
}
