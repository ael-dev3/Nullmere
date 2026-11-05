import Foundation

/// The six heroes who ride at a company's head, made in Blender
/// (Art/blender/commanders.py), each told apart at a glance: the Warden
/// with a greatsword and a tall plume; the Lamplighter, robed, a moon-pale
/// light on a staff; the Salt Crown, crowned in moonsalt with a
/// crystal-tipped lance; the Horned Axe in fur under a horned helm; the
/// Standard under the House's great banner; and the Tide Heir in sea-dark
/// scale with a trident.
extension Figures {
    static func commander(_ variant: Int, name: String) -> Model {
        Art.commander(variant, name: name, mount: commanderMount(variant))
    }

    /// Each commander's horse: the Warden's black, the Lamplighter's pale
    /// with grey socks, the Salt Crown's pale with a moonsalt mane, the
    /// Horned Axe's bay, the Standard's grey, the Tide Heir's black with
    /// pale socks.
    static func commanderMount(_ variant: Int) -> Mount {
        switch variant {
        case 0: return Mount(coat: Palette.horseBlack, mane: Palette.horseBlack)
        case 1: return Mount(coat: Palette.horsePale, mane: Palette.horseGrey, socks: Palette.horseGrey)
        case 2: return Mount(coat: Palette.horsePale, mane: Palette.moonsalt)
        case 3: return Mount(coat: Palette.horseBay, mane: Palette.horseBlack)
        case 4: return Mount(coat: Palette.horseGrey, mane: Palette.woolDark)
        default: return Mount(coat: Palette.horseBlack, mane: Palette.horsePale, socks: Palette.horsePale)
        }
    }

    /// A commander's great horse, drawn a ninth larger than a rider's,
    /// covers a ninth more ground at the same canter.
    static var commanderPace: Float {
        Ride(mount: Mount(size: Art.commanderScale / Art.figureScale)).marchSpeed
    }
}
