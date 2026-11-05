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
        case .mangonel: return Engine.mangonel(tier: tier, name: name)
        case .lantern: return Art.figure(Art.lantern, tier: 1, name: name, scale: Art.lanternScale)
        case .founder: return founder(name: name)
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

    // MARK: Founders

    /// A settler's walk, leaning into the shafts.
    static let founderGait = Gait.paced(.cart, .stocky, parts: Limb.count + 2)

    /// How the far country's things move: a slow stooped glide, a long
    /// prowl, a heavy tread.
    static func wildGait(_ tier: Int) -> Gait {
        switch tier {
        case 1: return Gait(hands: .wild, size: 0.34, stoop: 0.12, stride: 0.38)
        case 2: return Gait(hands: .wild, size: 0.37, stoop: 0.3, stride: 0.5)
        default: return Gait(hands: .club, size: 0.56, stoop: 0.22, stride: 0.32)
        }
    }

    /// How fast a model goes on the march, its feet or hooves holding the
    /// ground; nil for what does not march.
    static func marchSpeed(_ key: ModelKey) -> Float? {
        switch key.canonical {
        case .signature(let heritage): return marchSpeed(.figure(heritage.signature, tier: ModelKey.tiers(of: heritage.signature)))
        // Every tier's horse made in Blender the one size, its canter keyed for the common horse's pace.
        case .figure(.rider, _): return Ride(arms: .lance).marchSpeed
        case .figure(.founder, _): return founderGait.marchSpeed
        case .figure(.mangonel, _): return Engine.gait.marchSpeed
        case .figure, .prop(.cart): return Gait(hands: .spear).marchSpeed
        case .wild(let tier): return wildGait(tier).marchSpeed
        case .commander(let variant): return commanderRide(variant).marchSpeed
        case .folk(let variant): return Folk.gait(variant).marchSpeed
        default: return nil
        }
    }

    /// The handcart's wheels' radius, in the body's units: one turn of
    /// them is one period's march.
    static func cartWheel(_ gait: Gait) -> Float {
        gait.marchSpeed * Clip.march.period / (2 * .pi * gait.size)
    }

    /// A settler between the shafts of a handcart piled with bundles under
    /// the House's canvas.
    static func founder(name: String) -> Model {
        var f = Frame.stocky
        f.extraParent = Limb.root
        let gait = founderGait
        let wheel = cartWheel(gait)
        let axle = Vec3(0, wheel, -0.62)
        f.extraPivot = axle
        var o = Outfit()
        o.tunic = Palette.linen
        o.sleeves = Palette.linen
        o.skirt = (Palette.wool, .plain, 0.3)
        o.head = .hood(Palette.wool, .plain)
        o.mantle = (Palette.canvas, .plain)
        let more: [(name: String, parent: UInt16, pivot: Vec3)] = [
            ("wheel left", Cart.body, axle + Vec3(0.27, 0, 0)), ("wheel right", Cart.body, axle + Vec3(-0.27, 0, 0)),
        ]
        return model(name, f, gait, more: more) { b in
            Person.body(&b, f, o)
            Person.mattock(&b, f)
            let grip = f.grip
            b.with(part: Cart.body) {
                // Shafts from the hands back to the bed.
                for side in [Float(1), -1] {
                    $0.beam(from: Vec3(side * f.shoulderX, grip, 0.05), to: Vec3(side * 0.22, wheel + 0.2, -0.95), width: 0.03,
                            color: Palette.timber)
                }
                $0.box(min: Vec3(-0.24, wheel + 0.13, -0.95), max: Vec3(0.24, wheel + 0.19, -0.33), color: Palette.timberPale)
                $0.box(min: Vec3(-0.25, wheel + 0.19, -0.95), max: Vec3(-0.21, wheel + 0.27, -0.33), color: Palette.timber)
                $0.box(min: Vec3(0.21, wheel + 0.19, -0.95), max: Vec3(0.25, wheel + 0.27, -0.33), color: Palette.timber)
                // The load: a barrel, sacks, and the House's canvas over the rest.
                $0.prism(sides: 6, radius: 0.08, from: wheel + 0.19, to: wheel + 0.4, color: Palette.timber)
                $0.place(.translation(Vec3(0.12, 0, -0.42))) {
                    $0.prism(sides: 6, radius: 0.075, from: wheel + 0.19, to: wheel + 0.38, color: Palette.timber)
                }
                $0.rock(center: Vec3(-0.1, wheel + 0.27, -0.42), size: Vec3(0.09, 0.08, 0.09), rings: 2, sides: 5, jitter: 0.15,
                        seed: 3, color: Palette.canvas)
                $0.with(material: .house) {
                    $0.place(.translation(Vec3(0, wheel + 0.19, -0.74))) {
                        $0.lathe([(0.26, 0), (0.25, 0.14), (0.16, 0.24), (0, 0.27)], sides: 6, color: Palette.house)
                    }
                }
                $0.beam(from: Vec3(-0.18, wheel + 0.15, -0.9), to: Vec3(-0.18, 0, -0.93), width: 0.025, color: Palette.timber)
            }
            for (part, x) in [(Cart.wheelL, Float(0.27)), (Cart.wheelR, -0.27)] {
                b.with(part: part) {
                    $0.wheel(center: axle + Vec3(x, 0, 0), radius: wheel, width: 0.04, spokes: 3, color: Palette.timber)
                }
            }
        }
    }

    // MARK: The far country

    /// What comes out of the far country, answering to no House: tall
    /// shrouded things with blank pale faces; stooped bark-black things
    /// crowned with dead antlers; and a great stone colossus grown over
    /// with moonsalt, a cold light where its heart should be.
    static func wild(tier: Int, name: String) -> Model {
        switch tier {
        case 1: return hollow(name: name)
        case 2: return thornwight(name: name)
        default: return colossus(name: name)
        }
    }

    /// Two cold eyes in a blank face.
    static func eyes(_ b: inout MeshBuilder, _ f: Frame, spread: Float = 0.026, forward: Float) {
        b.with(part: Limb.head, material: .glow) {
            for side in [Float(1), -1] {
                $0.box(center: Vec3(side * spread, f.head + 0.008, forward), size: Vec3(0.024, 0.013, 0.012), color: Palette.wildGlow)
            }
        }
    }

    static func hollow(name: String) -> Model {
        var f = Frame()
        f.size = 0.34
        f.elbow = 0.5
        f.wrist = 0.27
        f.headRadius = 0.066
        f.girth = 0.72
        f.shoulderX = 0.135
        f.hipX = 0.06
        var o = Outfit()
        o.skin = Palette.ash
        o.hands = Palette.bone
        o.tunic = Palette.shroud
        o.sleeves = Palette.ash
        o.hose = Palette.ash
        o.shins = Palette.ash
        o.boots = Palette.ash
        o.skirt = (Palette.woolDark, .plain, 0.08)
        o.belt = nil
        o.head = .hood(Palette.woolDark, .plain)
        o.mantle = (Palette.woolDark, .plain)
        let gait = wildGait(1)
        return model(name, f, gait) { b in
            Person.body(&b, f, o)
            // A blank pale mask in the dark of the hood.
            b.with(part: Limb.head) {
                $0.box(center: Vec3(0, f.head - 0.01, 0.068), size: Vec3(0.11, 0.15, 0.024), color: Palette.bone)
            }
            eyes(&b, f, forward: 0.082)
            // Rags hanging from the arms.
            for (part, x) in [(Limb.forearmL, f.shoulderX), (Limb.forearmR, -f.shoulderX)] {
                b.with(part: part, sway: 0.5) {
                    $0.sheet([Vec3(x, f.elbow, -0.03), Vec3(x, f.elbow, -0.075), Vec3(x, f.wrist - 0.16, -0.06),
                              Vec3(x, f.wrist - 0.05, -0.03)], normal: Vec3(1, 0, 0), color: Palette.shroud)
                }
            }
            // A crooked staff with a charm of bone hung from it.
            let hand = f.handR
            b.with(part: Limb.heldR) {
                $0.beam(from: Vec3(hand.x, 0.02, 0.02), to: Vec3(hand.x - 0.02, 0.62, 0.0), width: 0.022, color: Palette.deadWood)
                $0.beam(from: Vec3(hand.x - 0.02, 0.62, 0.0), to: Vec3(hand.x + 0.05, 0.9, 0.06), width: 0.02, color: Palette.deadWood)
                $0.beam(from: Vec3(hand.x + 0.05, 0.9, 0.06), to: Vec3(hand.x + 0.1, 0.84, 0.12), width: 0.016, color: Palette.deadWood)
                $0.with(material: .glow) {
                    $0.box(center: Vec3(hand.x + 0.1, 0.78, 0.12), size: Vec3(0.03, 0.05, 0.03), color: Palette.wildGlow)
                }
            }
            Person.mattock(&b, f)
        }
    }

    static func thornwight(name: String) -> Model {
        var f = Frame()
        f.size = 0.37
        f.elbow = 0.52
        f.wrist = 0.3
        f.headRadius = 0.07
        f.girth = 0.88
        var o = Outfit()
        o.skin = Palette.barkBlack
        o.hands = Palette.bone
        o.tunic = Palette.barkBlack
        o.sleeves = Palette.barkBlack
        o.hose = Palette.barkBlack
        o.shins = Palette.barkBlack
        o.boots = Palette.bark
        o.skirt = (Palette.moss, .plain, 0.2)
        o.belt = nil
        o.hair = Palette.barkBlack
        o.mantle = (Palette.moss, .plain)
        let gait = wildGait(2)
        return model(name, f, gait) { b in
            Person.body(&b, f, o)
            eyes(&b, f, spread: 0.03, forward: 0.072)
            // A crown of dead antlers.
            b.with(part: Limb.head) {
                for side in [Float(1), -1] {
                    let root = Vec3(side * 0.04, f.head + 0.05, -0.01)
                    let knee = root + Vec3(side * 0.09, 0.12, -0.02)
                    let tip = knee + Vec3(side * 0.05, 0.13, -0.05)
                    $0.beam(from: root, to: knee, width: 0.022, color: Palette.deadWood)
                    $0.beam(from: knee, to: tip, width: 0.016, color: Palette.deadWood)
                    $0.beam(from: knee, to: knee + Vec3(side * 0.1, 0.03, 0.04), width: 0.014, color: Palette.deadWood)
                    $0.beam(from: root.mix(knee, 0.5), to: root.mix(knee, 0.5) + Vec3(-side * 0.01, 0.1, 0.04), width: 0.014,
                            color: Palette.deadWood)
                }
            }
            // Claws of bone.
            for (part, x) in [(Limb.forearmL, f.shoulderX), (Limb.forearmR, -f.shoulderX)] {
                b.with(part: part) {
                    for finger in [Float(-1), 0, 1] {
                        let base = Vec3(x + finger * 0.015, f.grip - 0.03, 0.01)
                        $0.beam(from: base, to: base + Vec3(finger * 0.01, -0.11, 0.04), width: 0.012, color: Palette.bone)
                    }
                }
            }
            Person.mattock(&b, f)
        }
    }

    static func colossus(name: String) -> Model {
        var f = Frame()
        f.size = 0.56
        f.headRadius = 0.06
        f.girth = 1.35
        f.shoulderX = 0.18
        f.hipX = 0.085
        f.wrist = 0.34
        var o = Outfit()
        o.skin = Palette.stonePale
        o.hands = Palette.stone
        o.tunic = Palette.stonePale
        o.sleeves = Palette.stone
        o.hose = Palette.stoneDark
        o.shins = Palette.stoneDark
        o.boots = Palette.rock
        o.belt = nil
        o.hair = Palette.stonePale
        let gait = wildGait(3)
        return model(name, f, gait) { b in
            Person.body(&b, f, o)
            // Moonsalt grown through the stone: on the shoulders, the back and the brow.
            let growths: [(part: UInt16, at: Vec3, lean: Vec3, length: Float)] = [
                (Limb.armL, Vec3(0.19, 0.78, 0), Vec3(0.5, 1, -0.2), 0.16),
                (Limb.armL, Vec3(0.2, 0.74, -0.05), Vec3(0.8, 0.5, 0.1), 0.11),
                (Limb.armR, Vec3(-0.19, 0.78, 0), Vec3(-0.5, 1, -0.1), 0.18),
                (Limb.torso, Vec3(0.05, 0.72, -0.1), Vec3(0.2, 0.7, -1), 0.17),
                (Limb.torso, Vec3(-0.07, 0.64, -0.11), Vec3(-0.3, 0.5, -1), 0.13),
                (Limb.torso, Vec3(0.02, 0.58, -0.11), Vec3(0.1, 0.3, -1), 0.1),
                (Limb.head, Vec3(0.03, 0.93, -0.01), Vec3(0.3, 1, -0.2), 0.12),
                (Limb.head, Vec3(-0.03, 0.92, 0.0), Vec3(-0.4, 1, 0.1), 0.1),
            ]
            for growth in growths {
                b.with(part: growth.part, material: .crystal) {
                    $0.place(.translation(growth.at) * Mat4.aligningUp(to: growth.lean)) {
                        $0.prism(sides: 4, radius: growth.length * 0.22, from: -0.02, to: growth.length * 0.7, color: Palette.moonsalt)
                        $0.cone(sides: 4, radius: growth.length * 0.22, from: growth.length * 0.7, to: growth.length,
                                color: Palette.moonsalt)
                    }
                }
            }
            // The cold light in the cracked chest.
            b.with(part: Limb.torso, material: .glow) {
                $0.box(center: Vec3(0.02, 0.66, 0.095), size: Vec3(0.07, 0.1, 0.03), color: Palette.wildGlow)
            }
            eyes(&b, f, spread: 0.022, forward: 0.058)
            // A slab of stone for a club, salt crusted on its head.
            let hand = f.handR
            b.with(part: Limb.heldR) {
                $0.beam(from: hand + Vec3(0, 0.06, 0), to: hand + Vec3(0, -0.2, 0.02), width: 0.04, color: Palette.stoneDark)
                $0.rock(center: hand + Vec3(0, -0.29, 0.03), size: Vec3(0.07, 0.11, 0.08), rings: 3, sides: 5, jitter: 0.2,
                        seed: 9, color: Palette.rock)
                $0.with(material: .crystal) {
                    $0.place(.translation(hand + Vec3(0.02, -0.3, 0.09)) * .rotationX(1.2)) {
                        $0.cone(sides: 4, radius: 0.03, to: 0.1, color: Palette.moonsalt)
                    }
                }
            }
            Person.mattock(&b, f)
        }
    }
}
