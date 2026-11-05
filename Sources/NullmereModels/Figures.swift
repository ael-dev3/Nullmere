import Foundation
import NullmereCore

/// The figures companies are drawn as, by kind and tier, and what walks
/// out of the far country.
enum Figures {
    static func build(_ kind: UnitKind, tier: Int, name: String) -> Model {
        switch kind {
        case .spear: return Art.figure(Art.spearman, tier: tier, name: name)
        case .bow: return Art.figure(Art.archer, tier: tier, name: name, more: ["string"], scale: Art.archerScale)
        case .rider: return Art.rider(tier: tier, name: name, mount: Riders.mount(tier: tier))
        case .mangonel: return Art.mangonel(tier: tier, name: name)
        case .lantern: return Art.figure(Art.lantern, tier: 1, name: name, scale: Art.lanternScale)
        case .founder: return Art.founder(name: name)
        }
    }

    static func model(_ name: String, _ f: Frame, _ gait: Gait, more: [(name: String, parent: UInt16, pivot: Vec3)] = [],
                      _ body: (inout MeshBuilder) -> Void) -> Model {
        var b = MeshBuilder()
        b.place(.scale(f.size)) { body(&$0) }
        return Model(name: name, mesh: b.mesh, rig: f.rig(more: more)) { clip, time in gait.joints(clip, time) }
    }

    // MARK: The heritages' own companies

    /// A House's own company, its heritage's kind at the fifth tier in
    /// that people's gear: the Saltborn in salt-white plate, the
    /// Spinewardens in dark iron under fur, the Fenfolk hooded in reed and
    /// moss, the Strandfolk in sea-grey wool under kettle hats, the
    /// Blackwood Kin cloaked in fir-green on black horses, the Mound Clans
    /// in bone and black on ash-grey ones.
    static func signature(_ heritage: Heritage, name: String) -> Model {
        let tier = ModelKey.tiers(of: heritage.signature)
        switch heritage.signature {
        // The Wood Riders and the Barrow Riders, made in Blender with the rider.
        case .rider: return Art.rider(tier: tier, variant: heritage.rawValue, name: name, mount: signatureMount(heritage))
        // The Reed Bows and the Strand Bows, made in Blender with the archer.
        case .bow: return Art.figure(Art.archer, tier: tier, variant: heritage.rawValue, name: name, more: ["string"],
                                     scale: Art.archerScale)
        // The Salt Wardens and the Spine Guard, made in Blender with the spearman.
        default: return Art.figure(Art.spearman, tier: tier, variant: heritage.rawValue, name: name)
        }
    }

    /// The horses the riders of a heritage ride: the Blackwood Kin's black
    /// with grey socks, under a saddle cloth; the Mound Clans' ash-grey,
    /// caparisoned to the hoof (their cloth made with them in Blender).
    static func signatureMount(_ heritage: Heritage) -> Mount {
        switch heritage {
        case .moundClans: return Mount(coat: Palette.ash, mane: Palette.barkBlack)
        default: return Mount(coat: Palette.horseBlack, mane: Palette.horseBlack, socks: Palette.horseGrey)
        }
    }

    // MARK: The far country's paces

    /// How fast the far country's things go, their walks keyed in Blender
    /// with strides set to keep it: a slow glide, a long prowl, a heavy tread.
    static func wildGait(_ tier: Int) -> Gait {
        switch tier {
        case 1: return Gait(hands: .free, size: 0.34, stride: 0.38)
        case 2: return Gait(hands: .free, size: 0.37, stride: 0.5)
        default: return Gait(hands: .free, size: 0.56, stride: 0.32)
        }
    }

    /// How fast a model goes on the march, its feet or hooves holding the
    /// ground; nil for what does not march.
    static func marchSpeed(_ key: ModelKey) -> Float? {
        switch key.canonical {
        case .signature(let heritage): return marchSpeed(.figure(heritage.signature, tier: ModelKey.tiers(of: heritage.signature)))
        // Every tier's horse made in Blender the one size, its canter keyed for the common horse's pace.
        case .figure(.rider, _): return Ride().marchSpeed
        // His cart's wheels made to turn once a march period at the common pace, his stride lengthened to keep it.
        case .figure(.founder, _): return Gait(hands: .spear).marchSpeed
        // Its wheels made to turn once a march period at the common pace, and its crewman's stride lengthened to keep it.
        case .figure(.mangonel, _): return Gait(hands: .spear).marchSpeed
        case .figure, .prop(.cart): return Gait(hands: .spear).marchSpeed
        case .wild(let tier): return wildGait(tier).marchSpeed
        case .commander: return commanderPace
        case .folk(let variant): return Folk.gait(variant).marchSpeed
        default: return nil
        }
    }

    /// The handcart's wheels' radius, in the body's units: one turn of
    /// them is one period's march.
    static func cartWheel(_ gait: Gait) -> Float {
        gait.marchSpeed * Clip.march.period / (2 * .pi * gait.size)
    }

    // MARK: The far country

    /// What comes out of the far country, answering to no House, made in
    /// Blender (Art/blender/hollow.py, thornwight.py and colossus.py): tall
    /// shrouded things with blank pale faces; stooped bark-black things
    /// crowned with dead antlers; and a great stone colossus grown over
    /// with moonsalt, a cold light where its heart should be.
    static func wild(tier: Int, name: String) -> Model {
        Art.wild(tier: tier, name: name)
    }
}
