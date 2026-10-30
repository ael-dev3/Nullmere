import Foundation
import NullmereCore

/// The townsfolk who go about a hold's work, plain folk in linen and wool
/// with a band of their House's colour at the waist: a farmhand with a
/// pitchfork from the granary, carters hauling timber from the sawpit and
/// stone from the quarry, a salter with a basket from the saltworks, and a
/// porter with a sack on their back about the rest. Drawn by the dozen,
/// built as lean as the companies' figures.
enum Folk {
    /// The townsfolk there are, by their work.
    static let variants = 5
    static let farmhand = 0, timberCarter = 1, stoneCarter = 2, salter = 3, porter = 4

    /// A little smaller than a soldier, and an unhurried walk.
    static let size: Float = 0.27
    static let stride: Float = 0.32

    static func build(_ variant: Int, name: String) -> Model {
        switch variant {
        case farmhand: return farmhandModel(name)
        case timberCarter: return carter(name, stone: false)
        case stoneCarter: return carter(name, stone: true)
        case salter: return salterModel(name)
        default: return porterModel(name)
        }
    }

    /// How a townsfolk of a variant walks.
    static func gait(_ variant: Int) -> Gait {
        switch variant {
        case timberCarter, stoneCarter: return Gait(hands: .cart, size: size, stride: stride, parts: Limb.count + 2)
        case salter: return Gait(hands: .lantern, size: size, stride: stride)
        default: return Gait(hands: .spear, size: size, stride: stride)
        }
    }

    private static func frame() -> Frame {
        var f = Frame()
        f.size = size
        f.girth = 0.95
        return f
    }

    /// The band of the House's colour every townsfolk wears at the waist.
    private static func band(_ b: inout MeshBuilder, _ f: Frame) {
        b.with(part: Limb.hips) {
            $0.with(material: .house) {
                $0.box(center: Vec3(0, f.waist - 0.015, 0), size: Vec3(0.2, 0.035, 0.14), color: Palette.house)
            }
        }
    }

    /// A smock and a straw-coloured cap; a pitchfork upright in the right hand.
    static func farmhandModel(_ name: String) -> Model {
        let f = frame()
        var o = Outfit()
        o.tunic = Palette.linen
        o.sleeves = Palette.linen
        o.skirt = (Palette.linen, .plain, 0.34)
        o.head = .cap(Palette.thatch)
        o.belt = nil
        return Figures.model(name, f, gait(farmhand)) { b in
            Person.body(&b, f, o)
            let x = f.handR.x
            b.with(part: Limb.heldR) {
                $0.limb(from: Vec3(x, 0.04, 0), to: Vec3(x, 1.18, 0), radius: 0.015, sides: 4, color: Palette.timberPale)
                $0.with(material: .metal) {
                    $0.beam(from: Vec3(x - 0.05, 1.18, 0), to: Vec3(x + 0.05, 1.18, 0), width: 0.014, color: Palette.iron)
                    for offset in [Float(-0.045), 0, 0.045] {
                        $0.limb(from: Vec3(x + offset, 1.18, 0), to: Vec3(x + offset, 1.33, 0), radius: 0.007, sides: 3, color: Palette.iron)
                    }
                }
            }
            band(&b, f)
        }
    }

    /// Between the shafts of a handcart, as a settler hauls one: piled with
    /// logs from the sawpit, or with dressed stone from the quarry.
    static func carter(_ name: String, stone: Bool) -> Model {
        var f = frame()
        f.extraParent = Limb.root
        let gait = gait(stone ? stoneCarter : timberCarter)
        let wheel = Figures.cartWheel(gait)
        let axle = Vec3(0, wheel, -0.6)
        f.extraPivot = axle
        var o = Outfit()
        o.tunic = stone ? Palette.wool : Palette.padded
        o.sleeves = Palette.linen
        o.skirt = (stone ? Palette.woolDark : Palette.wool, .plain, 0.3)
        o.head = stone ? .bare : .hood(Palette.wool, .plain)
        let more: [(name: String, parent: UInt16, pivot: Vec3)] = [
            ("wheel left", Cart.body, axle + Vec3(0.25, 0, 0)), ("wheel right", Cart.body, axle + Vec3(-0.25, 0, 0)),
        ]
        return Figures.model(name, f, gait, more: more) { b in
            Person.body(&b, f, o)
            let grip = f.grip
            b.with(part: Cart.body) {
                for side in [Float(1), -1] {
                    $0.beam(from: Vec3(side * f.shoulderX, grip, 0.05), to: Vec3(side * 0.2, wheel + 0.18, -0.9), width: 0.028,
                            color: Palette.timber)
                }
                $0.box(min: Vec3(-0.22, wheel + 0.12, -0.9), max: Vec3(0.22, wheel + 0.17, -0.32), color: Palette.timberPale)
                if stone {
                    // Dressed blocks, two below and one across them.
                    $0.box(center: Vec3(-0.1, wheel + 0.23, -0.6), size: Vec3(0.17, 0.12, 0.24), color: Palette.stonePale)
                    $0.box(center: Vec3(0.1, wheel + 0.23, -0.62), size: Vec3(0.16, 0.12, 0.22), color: Palette.stone)
                    $0.box(center: Vec3(0, wheel + 0.34, -0.6), size: Vec3(0.22, 0.1, 0.16), color: Palette.stonePale)
                } else {
                    // Logs laid along it, three below and two above.
                    for (x, y) in [(Float(-0.13), Float(0.23)), (0, 0.23), (0.13, 0.23), (-0.065, 0.34), (0.065, 0.34)] {
                        $0.limb(from: Vec3(x, wheel + y, -0.95), to: Vec3(x, wheel + y, -0.26), radius: 0.055, sides: 5,
                                color: y > 0.3 ? Palette.timberPale : Palette.bark)
                    }
                }
                $0.beam(from: Vec3(-0.16, wheel + 0.14, -0.86), to: Vec3(-0.16, 0, -0.88), width: 0.024, color: Palette.timber)
            }
            for (part, x) in [(Cart.wheelL, Float(0.25)), (Cart.wheelR, -0.25)] {
                b.with(part: part) {
                    $0.wheel(center: axle + Vec3(x, 0, 0), radius: wheel, width: 0.035, spokes: 3, color: Palette.timber)
                }
            }
            band(&b, f)
        }
    }

    /// A hood, and a lidded basket of salt hanging from the left hand.
    static func salterModel(_ name: String) -> Model {
        var f = frame()
        let hook = Vec3(f.shoulderX, f.grip - 0.02, 0.05)
        f.extraPivot = hook
        var o = Outfit()
        o.tunic = Palette.seaWool
        o.sleeves = Palette.seaWool
        o.skirt = (Palette.seaWool, .plain, 0.24)
        o.head = .hood(Palette.linen, .plain)
        return Figures.model(name, f, gait(salter)) { b in
            Person.body(&b, f, o)
            b.with(part: Limb.extra) {
                // The basket hangs below the hand by its handle, salt heaped in it.
                $0.beam(from: hook, to: hook - Vec3(0, 0.06, 0), width: 0.012, color: Palette.timberPale)
                $0.place(.translation(hook - Vec3(0, 0.2, 0))) {
                    $0.lathe([(0.065, 0), (0.09, 0.05), (0.1, 0.14), (0.085, 0.15)], sides: 6, color: Palette.reed)
                }
                $0.sphere(center: hook - Vec3(0, 0.05, 0), radius: 0.065, rings: 2, sides: 5, color: Palette.moonsalt)
            }
            band(&b, f)
        }
    }

    /// A sack on their back, a staff in the right hand.
    static func porterModel(_ name: String) -> Model {
        let f = frame()
        var o = Outfit()
        o.tunic = Palette.wool
        o.sleeves = Palette.woolDark
        o.skirt = (Palette.wool, .plain, 0.3)
        o.head = .cap(Palette.leather)
        return Figures.model(name, f, gait(porter)) { b in
            Person.body(&b, f, o)
            let x = f.handR.x
            b.with(part: Limb.heldR) {
                $0.limb(from: Vec3(x, 0.03, 0), to: Vec3(x, 1.05, 0), radius: 0.014, sides: 4, color: Palette.timber)
            }
            b.with(part: Limb.torso) {
                $0.rock(center: Vec3(0, f.shoulder - 0.05, -0.12), size: Vec3(0.13, 0.15, 0.09), rings: 2, sides: 5, jitter: 0.12,
                        seed: 7, color: Palette.canvas)
                $0.beam(from: Vec3(0.09, f.shoulder + 0.02, 0.06), to: Vec3(-0.09, f.waist + 0.04, 0.07), width: 0.022, color: Palette.leather)
            }
            band(&b, f)
        }
    }
}

extension ModelKey {
    /// The townsfolk who go about a work: the farmhand the granary's, the
    /// carters the sawpit's and the quarry's, the salter the saltworks', a
    /// porter every other's.
    public static func folk(of work: BuildingKind) -> ModelKey {
        switch work {
        case .granary: return .folk(variant: Folk.farmhand)
        case .sawpit: return .folk(variant: Folk.timberCarter)
        case .quarry: return .folk(variant: Folk.stoneCarter)
        case .saltworks: return .folk(variant: Folk.salter)
        default: return .folk(variant: Folk.porter)
        }
    }
}
