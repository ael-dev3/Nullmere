import Foundation

/// The parts every person's rig keeps, in the order of the bones of every
/// figure on foot made in Blender (Art.limbs), after its root.
enum Limb {
    static let root: UInt16 = 0
    static let hips: UInt16 = 1
    static let torso: UInt16 = 2
    static let head: UInt16 = 3
    static let armL: UInt16 = 4
    static let forearmL: UInt16 = 5
    static let armR: UInt16 = 6
    static let forearmR: UInt16 = 7
    static let thighL: UInt16 = 8
    static let shinL: UInt16 = 9
    static let thighR: UInt16 = 10
    static let shinR: UInt16 = 11
    /// What the right hand holds: a spear, a blade.
    static let heldR: UInt16 = 12
    /// What the left hand holds: a shield, a bow, a lantern's staff.
    static let heldL: UInt16 = 13
    static let cloak: UInt16 = 14
    /// The mattock brought out to gather, put away otherwise.
    static let tool: UInt16 = 15
    /// One thing more: what hangs from a hand (a basket, a pail, a lantern
    /// on its hook), or a cart or an engine behind.
    static let extra: UInt16 = 16
    static let count = 17
}

/// The parts an archer adds to a person (made in Blender, its bones kept
/// in this order: Art/blender/archer.py).
enum Bowman {
    /// The bow's string at rest, put away while it is drawn.
    static let string: UInt16 = 17
}
