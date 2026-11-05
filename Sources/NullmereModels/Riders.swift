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

    /// A person's part as the rider's.
    static func rider(_ limb: UInt16) -> UInt16 {
        switch limb {
        case Limb.torso: return torso
        case Limb.head: return riderHead
        case Limb.armL: return armL
        case Limb.forearmL: return forearmL
        case Limb.armR: return armR
        case Limb.forearmR: return forearmR
        case Limb.heldR: return heldR
        case Limb.heldL: return heldL
        case Limb.cloak, Limb.extra: return cloak
        case Limb.tool: return tool
        default: return seat
        }
    }
}

/// How a horse stands and what it wears.
struct Mount {
    /// A common horse against the measures it is built in.
    static let common: Float = 1.3
    /// Its size against a common horse.
    var size: Float = 1
    var coat = Palette.horseBay
    var mane = Palette.hair
    /// White about the hooves.
    var socks: Vec3?
    /// The House's cloth: none, a saddle cloth, a short caparison, a long one.
    var cloth = 1
    /// Steel on the face, the chest, and from the fifth tier the neck.
    var barding = 0

    /// Its whole scale against the measures it is built in.
    var scale: Float { Mount.common * size }

    /// Where the rider's hips sit, in the model's frame.
    var seat: Vec3 { Vec3(0, 0.232, -0.015) * scale }
}

/// Riders, from a padded rider on a dun pony to a crested knight on a
/// barded warhorse, and the six commanders who ride at a company's head.
enum Riders {
    // MARK: The horse

    static func horse(_ b: inout MeshBuilder, _ m: Mount) {
        b.place(.scale(m.scale)) {
            $0.with(part: Steed.body) {
                // The barrel, rump to chest, a flat along the back for the saddle.
                $0.place(.translation(Vec3(0, 0.165, 0)) * .rotationX(.pi / 2) * .scale(Vec3(0.85, 1, 1.12))) {
                    $0.tube([(0, -0.156), (0.046, -0.13), (0.056, -0.06), (0.056, 0.05), (0.047, 0.104), (0, 0.13)], sides: 6,
                            color: m.coat)
                }
                $0.box(min: Vec3(-0.03, 0.214, -0.055), max: Vec3(0.03, 0.234, 0.03), color: Palette.leatherDark)
                $0.with(material: .house) {
                    if m.cloth <= 1 {
                        // A saddle cloth on the flanks.
                        $0.place(.translation(Vec3(0, 0, -0.012)) * .scale(Vec3(1, 1, 1.15))) {
                            $0.tube([(0.066, 0.15), (0.058, 0.216)], sides: 8, color: Palette.house, twist: .pi / 8)
                        }
                    } else {
                        // A caparison draped from the saddle, to the knees or near the ground.
                        let hem: Float = m.cloth == 2 ? 0.11 : 0.07
                        $0.with(material: .cloth, sway: 0.12) {
                            $0.place(.translation(Vec3(0, 0, -0.015)) * .scale(Vec3(1, 1, 2.15))) {
                                $0.tube([(0.068, hem), (0.06, 0.2), (0.025, 0.222)], sides: 8, color: Palette.house, twist: .pi / 8)
                            }
                        }
                    }
                }
                if m.barding >= 1 {
                    // A steel collar round the breast, under the caparison.
                    $0.with(material: .metal) {
                        $0.place(.translation(Vec3(0, 0.165, 0)) * .rotationX(.pi / 2) * .scale(Vec3(0.9, 1, 1.18))) {
                            $0.tube([(0.058, 0.035), (0.05, 0.1)], sides: 6, color: Palette.steel)
                        }
                    }
                }
            }
            $0.with(part: Steed.neck) {
                $0.limb(from: Vec3(0, 0.18, 0.075), to: Vec3(0, 0.282, 0.152), radius: 0.034, topRadius: 0.023, color: m.coat)
                if m.barding >= 2 {
                    // Plates along the crest of the neck where the mane would be.
                    $0.with(material: .metal) {
                        $0.limb(from: Vec3(0, 0.212, 0.062), to: Vec3(0, 0.298, 0.138), radius: 0.02, topRadius: 0.015, sides: 3,
                                color: Palette.steel)
                    }
                } else {
                    $0.limb(from: Vec3(0, 0.215, 0.062), to: Vec3(0, 0.302, 0.14), radius: 0.013, sides: 3, color: m.mane)
                }
            }
            $0.with(part: Steed.head) {
                $0.place(.translation(Vec3(0, 0.29, 0.147)) * Mat4.aligningUp(to: Vec3(0, -0.055, 0.075))) {
                    $0.lathe([(0.025, 0), (0.017, 0.093)], sides: 4, color: m.coat, twist: .pi / 4)
                }
                for side in [Float(1), -1] {
                    $0.place(.translation(Vec3(side * 0.011, 0.297, 0.143))) {
                        $0.cone(sides: 3, radius: 0.008, to: 0.026, color: m.coat)
                    }
                }
                if m.barding >= 1 {
                    // A chanfron down the face.
                    let up = Vec3(0, 0.81, 0.59) * 0.016
                    $0.with(material: .metal) {
                        $0.beam(from: Vec3(0, 0.29, 0.147) + up, to: Vec3(0, 0.239, 0.217) + up * 0.6, width: 0.03, depth: 0.012,
                                color: Palette.steel)
                    }
                }
            }
            $0.with(part: Steed.tail) {
                $0.limb(from: Vec3(0, 0.2, -0.138), to: Vec3(0, 0.09, -0.185), radius: 0.017, topRadius: 0.006, sides: 3, color: m.mane)
            }
            let legs: [(upper: UInt16, lower: UInt16, top: Vec3, joint: Vec3, foot: Vec3, thick: Float)] = [
                (Steed.foreL, Steed.foreShinL, Vec3(0.032, 0.155, 0.075), Vec3(0.032, 0.085, 0.08), Vec3(0.032, 0.022, 0.076), 0.018),
                (Steed.foreR, Steed.foreShinR, Vec3(-0.032, 0.155, 0.075), Vec3(-0.032, 0.085, 0.08), Vec3(-0.032, 0.022, 0.076), 0.018),
                (Steed.hindL, Steed.hindShinL, Vec3(0.033, 0.168, -0.095), Vec3(0.033, 0.085, -0.118), Vec3(0.033, 0.022, -0.102), 0.023),
                (Steed.hindR, Steed.hindShinR, Vec3(-0.033, 0.168, -0.095), Vec3(-0.033, 0.085, -0.118), Vec3(-0.033, 0.022, -0.102), 0.023),
            ]
            for leg in legs {
                $0.with(part: leg.upper) {
                    $0.limb(from: leg.top, to: leg.joint, radius: leg.thick, topRadius: 0.012, color: m.coat)
                }
                $0.with(part: leg.lower) {
                    $0.limb(from: leg.joint, to: leg.foot, radius: 0.011, topRadius: 0.009, sides: 3, color: m.socks ?? m.coat)
                    $0.place(.translation(leg.foot - Vec3(0, 0.022, 0))) {
                        $0.lathe([(0.014, 0), (0.011, 0.024)], sides: 3, color: Palette.hoof)
                    }
                }
            }
            detail(&$0, m)
        }
    }

    /// The whole rig: the horse, then its rider on the saddle. `swing` names
    /// what part 22 is, and where it turns, when it is not a cloak.
    static func rig(_ m: Mount, _ f: Frame, swing: (parent: UInt16, pivot: Vec3)? = nil) -> Rig {
        let h = m.scale
        var rig = Rig()
        rig.add("body", pivot: Vec3(0, 0.165, -0.01) * h)
        rig.add("neck", parent: Int(Steed.body), pivot: Vec3(0, 0.2, 0.085) * h)
        rig.add("horse head", parent: Int(Steed.neck), pivot: Vec3(0, 0.285, 0.15) * h)
        rig.add("tail", parent: Int(Steed.body), pivot: Vec3(0, 0.2, -0.138) * h)
        for x in [Float(0.032), -0.032] {
            let upper = rig.add("fore leg", parent: Int(Steed.body), pivot: Vec3(x, 0.155, 0.075) * h)
            rig.add("fore shin", parent: Int(upper), pivot: Vec3(x, 0.085, 0.08) * h)
        }
        for x in [Float(0.033), -0.033] {
            let upper = rig.add("hind leg", parent: Int(Steed.body), pivot: Vec3(x, 0.168, -0.095) * h)
            rig.add("hind shin", parent: Int(upper), pivot: Vec3(x, 0.085, -0.118) * h)
        }
        let s = f.size, lift = lift(m, f)
        rig.add("seat", parent: Int(Steed.body), pivot: Vec3(0, f.hip, 0) * s + lift)
        rig.add("torso", parent: Int(Steed.seat), pivot: Vec3(0, f.waist, 0) * s + lift)
        rig.add("head", parent: Int(Steed.torso), pivot: Vec3(0, f.neck, 0) * s + lift)
        rig.add("arm left", parent: Int(Steed.torso), pivot: Vec3(f.shoulderX, f.shoulder, 0) * s + lift)
        rig.add("forearm left", parent: Int(Steed.armL), pivot: Vec3(f.shoulderX, f.elbow, 0) * s + lift)
        rig.add("arm right", parent: Int(Steed.torso), pivot: Vec3(-f.shoulderX, f.shoulder, 0) * s + lift)
        rig.add("forearm right", parent: Int(Steed.armR), pivot: Vec3(-f.shoulderX, f.elbow, 0) * s + lift)
        rig.add("held right", parent: Int(Steed.forearmR), pivot: f.handR * s + lift)
        rig.add("held left", parent: Int(Steed.forearmL), pivot: f.handL * s + lift)
        if let swing {
            rig.add("swing", parent: Int(swing.parent), pivot: swing.pivot * s + lift)
        } else {
            rig.add("cloak", parent: Int(Steed.torso), pivot: Vec3(0, f.shoulder, -0.08) * s + lift)
        }
        rig.add("tool", parent: Int(Steed.forearmR), pivot: f.handR * s + lift)
        return rig
    }

    /// From the rider's own frame to the saddle.
    static func lift(_ m: Mount, _ f: Frame) -> Vec3 {
        m.seat - Vec3(0, f.hip * f.size, 0)
    }

    /// A horse and its rider: the rider built as a person astride, its
    /// parts taken over as the rider's.
    static func model(_ name: String, _ m: Mount, _ ride: Ride, swing: (parent: UInt16, pivot: Vec3)? = nil, frame: Frame = .horseman,
                      rider: (inout MeshBuilder, Frame) -> Void) -> Model {
        var f = frame
        f.seated = true
        var b = MeshBuilder()
        horse(&b, m)
        var person = MeshBuilder()
        person.place(.scale(f.size)) { rider(&$0, f) }
        var mesh = person.mesh
        for index in mesh.vertices.indices {
            mesh.vertices[index].part = Steed.rider(mesh.vertices[index].part)
            mesh.vertices[index].part2 = Steed.rider(mesh.vertices[index].part2)
        }
        var whole = b.mesh
        whole.append(mesh, transform: .translation(lift(m, f)))
        return Model(name: name, mesh: whole, rig: rig(m, f, swing: swing)) { clip, time in ride.joints(clip, time) }
    }

    // MARK: Riders by tier

    static func mount(tier: Int) -> Mount {
        switch tier {
        case 1: return Mount(size: 0.9, coat: Palette.horseDun, mane: Palette.hair, cloth: 1)
        case 2: return Mount(size: 0.96, coat: Palette.horseBay, mane: Palette.horseBlack, socks: Palette.linen, cloth: 1)
        case 3: return Mount(coat: Palette.horseBlack, mane: Palette.horseBlack, cloth: 2)
        case 4: return Mount(size: 1.03, coat: Palette.horseGrey, mane: Palette.woolDark, cloth: 2, barding: 1)
        default: return Mount(size: 1.06, coat: Palette.horsePale, mane: Palette.horseGrey, cloth: 3, barding: 2)
        }
    }

    static func riderOutfit(_ tier: Int) -> Outfit {
        var o = Figures.spearOutfit(tier)
        o.skirt = o.skirt.map { ($0.color, $0.material, 0.44) }
        if tier == 1 {
            o.head = .cap(Palette.wool)
        }
        return o
    }

    static func rider(tier: Int, name: String, outfit: Outfit? = nil, mount chosen: Mount? = nil) -> Model {
        let m = chosen ?? mount(tier: tier)
        let ride = Ride(arms: .lance, shield: tier >= 2, mount: m)
        return model(name, m, ride) { b, f in
            Person.body(&b, f, outfit ?? riderOutfit(tier))
            lance(&b, f, tier: tier)
            if tier >= 2 {
                Person.shield(&b, f, tier: tier)
            }
            Person.mattock(&b, f)
        }
    }

    /// A rider's spear, then lance: upright at rest, couched to charge.
    static func lance(_ b: inout MeshBuilder, _ f: Frame, tier: Int) {
        let x = f.handR.x, butt = f.grip - 0.42, top = f.grip + 1.2 + 0.1 * Float(tier)
        b.with(part: Limb.heldR) {
            $0.limb(from: Vec3(x, butt, 0), to: Vec3(x, top, 0), radius: tier >= 3 ? 0.022 : 0.017, topRadius: 0.014,
                    color: tier >= 4 ? Palette.timberDark : Palette.timber)
            if tier >= 3 {
                $0.place(.translation(Vec3(x, f.grip + 0.08, 0))) {
                    $0.cone(sides: 6, radius: 0.05, to: 0.13, color: tier >= 4 ? Palette.steel : Palette.iron)
                }
            }
            $0.with(material: .metal) {
                $0.place(.translation(Vec3(x, top, 0))) {
                    $0.lathe([(0.012, 0), (0.03, 0.05), (0, 0.16)], sides: 4, color: Palette.steel)
                }
            }
            if tier >= 4 {
                $0.flag(at: Vec3(x - 0.01, top - 0.02, 0), width: tier >= 5 ? 0.3 : 0.22, height: tier >= 5 ? 0.14 : 0.08,
                        turn: .pi / 2, tail: true)
            }
        }
    }
}

/// How a horse and its rider move through each clip.
struct Ride: Sendable {
    enum Arms: Sendable {
        /// A spear or lance, couched to charge.
        case lance
        /// A blade or an axe, swung down at the side.
        case chop
        /// A staff lifted high, its light flaring.
        case raise
        /// A standard swept from side to side.
        case wave
    }

    var arms: Arms
    var shield = false
    var mount = Mount()
    /// The rider's height in world units.
    var size: Float = 0.3
    /// Gallop strides each march period.
    var strides: Float = 2

    /// The ground covered each second at the canter, for the hooves not to slide.
    var marchSpeed: Float {
        strides * 0.36 * mount.scale / Clip.march.period
    }

    func joints(_ clip: Clip, _ time: Float) -> [Joint] {
        var p = Pose(count: Steed.count)
        let u = clip.progress(at: time)
        p.hide(Steed.tool)
        switch clip {
        case .idle: idle(&p, u)
        case .march: canter(&p, u * strides, speed: 1)
        case .attack: charge(&p, u)
        case .death: fall(&p, u)
        case .gather: graze(&p, u)
        case .hit: shy(&p, u)
        }
        return p.joints
    }

    // MARK: The rider's arms

    func carry(_ p: inout Pose) {
        switch arms {
        case .lance, .chop, .wave:
            p.turn(Steed.armR, x: -0.3, z: -0.08)
            p.turn(Steed.forearmR, x: -0.55)
        case .raise:
            p.turn(Steed.armR, x: -0.35)
            p.turn(Steed.forearmR, x: -0.9)
        }
        if shield {
            p.turn(Steed.armL, x: -0.3, z: 0.05)
            p.turn(Steed.forearmL, x: -1.15)
        } else if arms == .raise {
            p.turn(Steed.armL, x: -0.3, z: 0.1)
            p.turn(Steed.forearmL, x: -0.5)
        } else {
            p.turn(Steed.armL, x: -0.35)
            p.turn(Steed.forearmL, x: -0.95)
        }
    }

    /// Keeps a lance or standard at `angle` from upright, a staff upright.
    func level(_ p: inout Pose, angle: Float = 0) {
        let chain: [UInt16] = [Steed.body, Steed.seat, Steed.torso, Steed.armR, Steed.forearmR]
        switch arms {
        case .lance, .wave, .chop:
            p.turn(Steed.heldR, x: angle - p.pitch(through: chain))
        case .raise:
            p.turn(Steed.heldL, x: -p.pitch(through: [Steed.body, Steed.seat, Steed.torso, Steed.armL, Steed.forearmL]))
        }
    }

    // MARK: Clips

    /// At rest, keyed.
    func idle(_ p: inout Pose, _ u: Float) {
        carry(&p)
        RiderClips.idle.apply(&p, u)
        if arms == .wave {
            RiderClips.standardStirs.apply(&p, u)
        }
        level(&p)
    }

    /// The canter: `v` counts strides, each stride keyed; fast, the horse
    /// reaches further.
    func canter(_ p: inout Pose, _ v: Float, speed: Float) {
        carry(&p)
        RiderClips.canter.apply(&p, v - v.rounded(.down), stride: speed, size: mount.scale)
        level(&p)
    }

    func charge(_ p: inout Pose, _ u: Float) {
        canter(&p, u * 3, speed: 1.3)
        let couch = Motion.key(u, RiderClips.couch)
        switch arms {
        case .lance:
            p.joints[Int(Steed.heldR)].rotation = .zero
            RiderClips.charge(.lance).apply(&p, u)
            level(&p, angle: .pi / 2 * couch)
        case .chop:
            RiderClips.charge(.chop).apply(&p, u)
        case .raise:
            RiderClips.charge(.raise).apply(&p, u)
            p.joints[Int(Steed.heldL)].rotation = .zero
            level(&p)
            p.stretch(Steed.cloak, 1 + 0.35 * couch * (0.6 + 0.4 * Motion.wave(u, cycles: 6)))
        case .wave:
            RiderClips.charge(.wave).apply(&p, u)
            let sweep = p.joints[Int(Steed.heldR)].rotation.z
            p.joints[Int(Steed.heldR)].rotation = .zero
            level(&p, angle: 0)
            p.turn(Steed.heldR, z: sweep * couch)
        }
    }

    /// Struck: the horse shies and half rears, its rider rocked back, and
    /// both come down to the line again.
    func shy(_ p: inout Pose, _ u: Float) {
        carry(&p)
        RiderClips.shy(shield: shield).apply(&p, u)
        level(&p, angle: 0.4 * Gait.recoil(u))
    }

    /// The horse goes down on its side; its rider is thrown and lies by it.
    func fall(_ p: inout Pose, _ u: Float) {
        carry(&p)
        level(&p)
        RiderClips.fall(scale: mount.scale).apply(&p, u)
    }

    /// The horse crops the ground while its rider works a mattock beside it.
    func graze(_ p: inout Pose, _ u: Float) {
        carry(&p)
        level(&p)
        RiderClips.graze.apply(&p, u)
        let v = u * 2 - (u * 2).rounded(.down)
        p.joints[Int(Steed.tool)].scale = Vec3(1, 1, 1)
        p.hide(Steed.heldR)
        p.joints[Int(Steed.armR)].rotation = .zero
        p.joints[Int(Steed.forearmR)].rotation = .zero
        RiderClips.mattock.apply(&p, v)
    }
}
