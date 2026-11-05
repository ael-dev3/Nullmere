import Foundation

/// The parts a Mangonel adds to its crewman's, as its model made in Blender
/// keeps them (Art/blender/mangonel.py): the engine itself, which is his
/// extra part at the rig's root, its wheels, its throwing arm and the stone
/// in its cup.
enum Engine {
    static let body = Limb.extra
    static let wheelL = Cart.wheelL
    static let wheelR = Cart.wheelR
    static let arm: UInt16 = 19
    static let stone: UInt16 = 20
}
