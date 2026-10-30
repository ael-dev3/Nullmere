import Foundation

/// The six heroes who ride at a company's head, each told apart at a
/// glance: the Warden with a greatsword and a tall plume; the Lamplighter,
/// robed, a moon-pale lantern on a staff; the Salt Crown, crowned in
/// moonsalt with a crystal-tipped lance; the Horned Axe in fur under a
/// horned helm; the Standard, a great banner on its pole; and the Tide
/// Heir in sea-dark scale with a trident.
extension Figures {
    static func commander(_ variant: Int, name: String) -> Model {
        switch variant {
        case 0: return warden(name: name)
        case 1: return lamplighter(name: name)
        case 2: return saltCrown(name: name)
        case 3: return hornedAxe(name: name)
        case 4: return standard(name: name)
        default: return tideHeir(name: name)
        }
    }

    static func plate(_ o: inout Outfit) {
        o.tunic = Palette.steel
        o.tunicMaterial = .metal
        o.sleeves = Palette.mail
        o.sleevesMaterial = .metal
        o.hands = Palette.iron
        o.shins = Palette.steel
        o.shinsMaterial = .metal
        o.pauldrons = (Palette.steel, .metal)
        o.belt = (Palette.leatherDark, .plain)
    }

    static func warden(name: String) -> Model {
        let m = Mount(size: 1.12, coat: Palette.horseBlack, mane: Palette.horseBlack, cloth: 3, barding: 2)
        var o = Outfit()
        plate(&o)
        o.tabard = true
        o.head = .crested
        o.cloak = 0.34
        return Riders.model(name, m, Ride(arms: .chop, shield: true, mount: m)) { b, f in
            Person.body(&b, f, o)
            // A taller plume than any knight's.
            b.with(part: Limb.head, material: .house, sway: 0.5) {
                $0.swayRange = (f.head + 0.1, f.head + 0.3)
                $0.box(min: Vec3(-0.022, f.head + 0.12, -0.16), max: Vec3(0.022, f.head + 0.3, -0.02), color: Palette.house)
            }
            // A greatsword upright in the right hand.
            let hand = f.handR
            b.with(part: Limb.heldR) {
                $0.beam(from: hand - Vec3(0, 0.1, 0), to: hand + Vec3(0, 0.06, 0), width: 0.03, color: Palette.leatherDark)
                $0.with(material: .metal) {
                    $0.box(center: hand + Vec3(0, 0.07, 0), size: Vec3(0.17, 0.025, 0.03), color: Palette.gold)
                    $0.beam(from: hand + Vec3(0, 0.08, 0), to: hand + Vec3(0, 0.9, 0), width: 0.055, depth: 0.014, color: Palette.steel)
                    $0.place(.translation(hand + Vec3(0, 0.9, 0))) {
                        $0.cone(sides: 4, radius: 0.028, to: 0.06, color: Palette.steel, twist: .pi / 4)
                    }
                }
            }
            Person.shield(&b, f, tier: 5)
            Person.mattock(&b, f)
        }
    }

    static func lamplighter(name: String) -> Model {
        let m = Mount(size: 1.08, coat: Palette.horsePale, mane: Palette.horseGrey, socks: Palette.horseGrey, cloth: 3)
        var o = Outfit()
        o.tunic = Palette.woolDark
        o.sleeves = Palette.woolDark
        o.hands = Palette.skin
        o.skirt = (Palette.woolDark, .plain, 0.42)
        o.head = .hood(Palette.house, .house)
        o.mantle = (Palette.house, .house)
        o.belt = (Palette.gold, .metal)
        var f = Frame()
        f.seated = true
        let top = Vec3(f.shoulderX, f.grip + 1.25, 0.03)
        return Riders.model(name, m, Ride(arms: .raise, mount: m), swing: (Steed.heldL, top)) { b, f in
            Person.body(&b, f, o)
            let hand = f.handL
            b.with(part: Limb.heldL) {
                $0.strut(from: hand - Vec3(0, 0.3, 0), to: top, radius: 0.02, sides: 5, color: Palette.timberDark)
                // A crescent of silver cradling the light.
                $0.with(material: .metal) {
                    for index in 0..<4 {
                        let a = Float(index) / 4 * 2.6 - 1.3, c = Float(index + 1) / 4 * 2.6 - 1.3
                        let p0 = top + Vec3(0, 0.1 + 0.11 * Float(cos(Double(a))), 0.11 * Float(sin(Double(a))))
                        let p1 = top + Vec3(0, 0.1 + 0.11 * Float(cos(Double(c))), 0.11 * Float(sin(Double(c))))
                        $0.beam(from: p0, to: p1, width: 0.024, color: Palette.steel)
                    }
                }
            }
            b.with(part: Limb.extra, material: .glow) {
                $0.sphere(center: top + Vec3(0, 0.1, 0), radius: 0.06, rings: 3, sides: 6, color: Palette.moonGlow)
            }
            Person.mattock(&b, f)
        }
    }

    static func saltCrown(name: String) -> Model {
        let m = Mount(size: 1.1, coat: Palette.horsePale, mane: Palette.moonsalt, cloth: 3, barding: 1)
        var o = Outfit()
        plate(&o)
        o.tunic = Palette.stoneWhite
        o.pauldrons = (Palette.moonsalt, .crystal)
        o.cloak = 0.3
        o.hair = Palette.stonePale
        return Riders.model(name, m, Ride(arms: .lance, mount: m)) { b, f in
            Person.body(&b, f, o)
            // A crown of moonsalt spikes.
            b.with(part: Limb.head, material: .crystal) {
                for index in 0..<7 {
                    let angle = 2 * Float.pi * Float(index) / 7
                    let at = MeshBuilder.ring(f.headRadius * 0.95, f.head + 0.04, angle)
                    $0.place(.translation(at) * Mat4.aligningUp(to: Vec3(at.x, 0.12, at.z))) {
                        $0.cone(sides: 3, radius: 0.02, to: index % 2 == 0 ? 0.11 : 0.07, color: Palette.moonsalt)
                    }
                }
            }
            Riders.lance(&b, f, tier: 3)
            b.with(part: Limb.heldR, material: .crystal) {
                $0.place(.translation(Vec3(f.handR.x, f.grip + 1.5, 0))) {
                    $0.prism(sides: 4, radius: 0.04, from: 0, to: 0.08, color: Palette.moonsalt)
                    $0.cone(sides: 4, radius: 0.04, from: 0.08, to: 0.26, color: Palette.moonsalt)
                }
            }
            Person.mattock(&b, f)
        }
    }

    static func hornedAxe(name: String) -> Model {
        let m = Mount(size: 1.14, coat: Palette.horseBay, mane: Palette.horseBlack, cloth: 2)
        var o = Outfit()
        o.tunic = Palette.leatherDark
        o.sleeves = Palette.mail
        o.sleevesMaterial = .metal
        o.hands = Palette.leather
        o.skirt = (Palette.mail, .metal, 0.44)
        o.mantle = (Palette.fur, .plain)
        o.head = .nasal
        return Riders.model(name, m, Ride(arms: .chop, shield: true, mount: m)) { b, f in
            var big = f
            big.girth = 1.12
            Person.body(&b, big, o)
            // Horns curling from the helm.
            b.with(part: Limb.head) {
                for side in [Float(1), -1] {
                    let root = Vec3(side * 0.07, f.head + 0.04, 0)
                    let bend = root + Vec3(side * 0.08, 0.05, 0.02)
                    let tip = bend + Vec3(side * 0.01, 0.09, 0.06)
                    $0.beam(from: root, to: bend, width: 0.034, color: Palette.bone)
                    $0.beam(from: bend, to: tip, width: 0.022, color: Palette.bone)
                }
            }
            // A great axe, its haft long and its blade a broad crescent.
            let hand = f.handR
            b.with(part: Limb.heldR) {
                $0.beam(from: hand - Vec3(0, 0.25, 0), to: hand + Vec3(0, 0.95, 0), width: 0.03, color: Palette.timberDark)
                $0.with(material: .metal) {
                    $0.face([hand + Vec3(0.012, 0.95, 0.0), hand + Vec3(0.012, 0.66, 0.0), hand + Vec3(0.012, 0.6, 0.22),
                             hand + Vec3(0.012, 0.8, 0.27), hand + Vec3(0.012, 1.0, 0.2)], outward: Vec3(1, 0, 0), color: Palette.steel)
                    $0.face([hand + Vec3(-0.012, 0.95, 0.0), hand + Vec3(-0.012, 0.66, 0.0), hand + Vec3(-0.012, 0.6, 0.22),
                             hand + Vec3(-0.012, 0.8, 0.27), hand + Vec3(-0.012, 1.0, 0.2)], outward: Vec3(-1, 0, 0), color: Palette.iron)
                }
            }
            Person.shield(&b, f, tier: 3)
            Person.mattock(&b, f)
        }
    }

    static func standard(name: String) -> Model {
        let m = Mount(size: 1.1, coat: Palette.horseGrey, mane: Palette.woolDark, cloth: 3, barding: 2)
        var o = Outfit()
        plate(&o)
        o.tabard = true
        o.head = .greatHelm
        return Riders.model(name, m, Ride(arms: .wave, mount: m)) { b, f in
            Person.body(&b, f, o)
            let x = f.handR.x, top = f.grip + 2.1
            b.with(part: Limb.heldR) {
                $0.strut(from: Vec3(x, f.grip - 0.42, 0), to: Vec3(x, top, 0), radius: 0.022, sides: 5, color: Palette.timberDark)
                $0.beam(from: Vec3(x, top - 0.03, 0), to: Vec3(x, top - 0.03, -0.62), width: 0.02, color: Palette.timberDark)
                $0.with(material: .metal) {
                    $0.place(.translation(Vec3(x, top, 0))) {
                        $0.cone(sides: 4, radius: 0.045, to: 0.14, color: Palette.gold, twist: .pi / 4)
                    }
                }
                $0.flag(at: Vec3(x, top - 0.04, -0.01), width: 0.6, height: 0.5, turn: .pi / 2)
            }
            Person.mattock(&b, f)
        }
    }

    static func tideHeir(name: String) -> Model {
        let m = Mount(size: 1.1, coat: Palette.horseBlack, mane: Palette.horsePale, socks: Palette.horsePale, cloth: 2)
        let scale = Vec3(0.30, 0.40, 0.42)
        var o = Outfit()
        plate(&o)
        o.tunic = scale
        o.sleeves = scale
        o.skirt = (scale, .metal, 0.44)
        o.pauldrons = (Palette.steel, .metal)
        o.head = .greatHelm
        o.cloak = 0.3
        return Riders.model(name, m, Ride(arms: .lance, mount: m)) { b, f in
            Person.body(&b, f, o)
            // A crest like a breaking wave.
            b.with(part: Limb.head, material: .metal) {
                $0.face([Vec3(0, f.head + 0.08, 0.08), Vec3(0, f.head + 0.25, -0.02), Vec3(0, f.head + 0.2, -0.12),
                         Vec3(0, f.head + 0.08, -0.08)], outward: Vec3(1, 0, 0), color: Palette.steel)
                $0.face([Vec3(0, f.head + 0.08, 0.08), Vec3(0, f.head + 0.25, -0.02), Vec3(0, f.head + 0.2, -0.12),
                         Vec3(0, f.head + 0.08, -0.08)], outward: Vec3(-1, 0, 0), color: Palette.steel)
            }
            // A trident.
            let x = f.handR.x, top = f.grip + 1.45
            b.with(part: Limb.heldR) {
                $0.strut(from: Vec3(x, f.grip - 0.42, 0), to: Vec3(x, top, 0), radius: 0.02, sides: 4, color: Palette.timberDark)
                $0.with(material: .metal) {
                    $0.box(center: Vec3(x, top, 0), size: Vec3(0.2, 0.03, 0.03), color: Palette.steel)
                    for prong in [Float(-0.09), 0, 0.09] {
                        $0.beam(from: Vec3(x + prong, top, 0), to: Vec3(x + prong, top + (prong == 0 ? 0.24 : 0.18), 0), width: 0.02,
                                color: Palette.steel)
                    }
                }
            }
            Person.mattock(&b, f)
        }
    }
}
