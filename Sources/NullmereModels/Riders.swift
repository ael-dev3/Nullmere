import Foundation

/// The parts of a horse and its rider, in the order they are added.
enum Steed {
    static let body: UInt16 = 1
    static let neck: UInt16 = 2
    static let head: UInt16 = 3
    static let tail: UInt16 = 4
    static let foreL: UInt16 = 5
    static let foreShinL: UInt16 = 6
    static let foreR: UInt16 = 7
    static let foreShinR: UInt16 = 8
    static let hindL: UInt16 = 9
    static let hindShinL: UInt16 = 10
    static let hindR: UInt16 = 11
    static let hindShinR: UInt16 = 12
    /// The rider's hips and legs, astride.
    static let seat: UInt16 = 13
    static let torso: UInt16 = 14
    static let riderHead: UInt16 = 15
    static let armL: UInt16 = 16
    static let forearmL: UInt16 = 17
    static let armR: UInt16 = 18
    static let forearmR: UInt16 = 19
    static let heldR: UInt16 = 20
    static let heldL: UInt16 = 21
    /// The cloak; for a rider without one, something else that swings.
    static let cloak: UInt16 = 22
    static let tool: UInt16 = 23
    static let count = 24
}

/// The colours a horse is drawn in, as the models made in Blender colour
/// its coat, socks and mane, and its size against a common horse.
struct Mount {
    /// A common horse against the measures its canter is reckoned in.
    static let common: Float = 1.3
    /// Its size against a common horse.
    var size: Float = 1
    var coat = Palette.horseBay
    var mane = Palette.hair
    /// White about the hooves.
    var socks: Vec3?

    /// Its whole scale against the measures its canter is reckoned in.
    var scale: Float { Mount.common * size }
}

/// The horses a company's riders ride, by tier (the riders themselves made
/// in Blender: Art/blender/rider.py).
enum Riders {
    /// The horse a company's riders ride at a tier: a dun pony, a bay with
    /// white socks, a black, a grey, a pale warhorse. Its cloth and steel
    /// are made with it in Blender; its coat, socks and mane are these.
    static func mount(tier: Int) -> Mount {
        switch tier {
        case 1: return Mount(coat: Palette.horseDun, mane: Palette.hair)
        case 2: return Mount(coat: Palette.horseBay, mane: Palette.horseBlack, socks: Palette.linen)
        case 3: return Mount(coat: Palette.horseBlack, mane: Palette.horseBlack)
        case 4: return Mount(coat: Palette.horseGrey, mane: Palette.woolDark)
        default: return Mount(coat: Palette.horsePale, mane: Palette.horseGrey)
        }
    }
}

/// How fast a horse goes at the canter its clips are keyed for in Blender
/// (Art/blender/horse.py): two strides a march period.
struct Ride: Sendable {
    var mount = Mount()
    /// Gallop strides each march period.
    var strides: Float = 2

    /// The ground covered each second at the canter, for the hooves not to slide.
    var marchSpeed: Float {
        strides * 0.36 * mount.scale / Clip.march.period
    }
}
