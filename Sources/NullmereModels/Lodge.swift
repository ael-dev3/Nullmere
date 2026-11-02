import Foundation
import NullmereCore

/// The Masons' Lodge, modelled whole at each level, where the House's
/// masons learn to cut and lay stone; it faces +z, within a work's slot.
///
/// 1. An open shed of timber under thatch over a banker where a block is
///    dressed, a jib on its post to lift stone, rough blocks heaped.
/// 2. The shed walled in planks on two sides under slate, a rack of the
///    masons' tools, a second banker and squared blocks stacked.
/// 3. A hall of white stone, gabled and slated, its door and lit windows,
///    a tracing floor of pale slabs before it where a work is drawn out
///    full size, the jib beside.
/// 4. A treadwheel crane in its frame at the hall's side, turning, a block
///    swinging from its jib; buttresses and a chimney on the hall.
/// 5. A carved arch over the yard's way in, a moonsalt finial on the ridge,
///    a dormer on each slope and the House's banners at the door.
///
/// The jib slews its stone round and back as the masons work; the
/// treadwheel turns.
enum Lodge {
    static func model(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        var rig = Rig()
        b.pad(radius: 0.31, sides: 12)
        b.fine { yardStones(&$0) }
        boundary(&b, courses: min(level, 3))
        barrow(&b, at: Vec3(-0.12, 0, 0.21))
        limeTrough(&b, at: Vec3(0.11, 0, 0.23))
        var swings: [Machinery.Swing] = []
        var wheels: [Machinery.Wheel] = []

        switch level {
        case 1:
            shed(&b, walled: false, roof: Palette.thatch)
            banker(&b, at: Vec3(0.02, 0, 0.0), block: true)
            heap(&b, at: Vec3(0.2, 0, 0.12), rough: true)
            heap(&b, at: Vec3(0.05, 0, 0.2), rough: true)
            toolRack(&b, at: Vec3(0.19, 0, -0.15))
            swings.append(jib(&b, &rig, at: Vec3(-0.2, 0, 0.14)))
        case 2:
            shed(&b, walled: true, roof: Palette.slate)
            banker(&b, at: Vec3(-0.04, 0, 0.0), block: true)
            banker(&b, at: Vec3(0.09, 0, 0.0), block: false)
            toolRack(&b, at: Vec3(0.2, 0, -0.14))
            heap(&b, at: Vec3(0.21, 0, 0.13), rough: false)
            heap(&b, at: Vec3(-0.07, 0, 0.22), rough: true)
            swings.append(jib(&b, &rig, at: Vec3(-0.21, 0, 0.12)))
        default:
            hall(&b, level: level)
            tracingFloor(&b, at: Vec3(0, 0, 0.17))
            heap(&b, at: Vec3(0.22, 0, 0.17), rough: false)
            ashlar(&b, at: Vec3(-0.03, 0, -0.1), width: level >= 4 ? 0.3 : 0.26, depth: 0.15, height: level >= 5 ? 0.17 : 0.14)
            if level == 3 { scaffold(&b, at: Vec3(0.13, 0, -0.1)) }
            if level >= 4 {
                wheels.append(treadwheel(&b, &rig, at: Vec3(0.21, 0, -0.03)))
                swings.append(jib(&b, &rig, at: Vec3(-0.23, 0, 0.12)))
            } else {
                swings.append(jib(&b, &rig, at: Vec3(-0.23, 0, 0.12)))
                banker(&b, at: Vec3(0.17, 0, 0.04), block: true)
            }
            if level >= 5 {
                arch(&b, at: Vec3(0, 0, 0.27))
            }
        }
        let machinery = Machinery(wheels: wheels, swings: swings, parts: rig.count)
        return Model(name: name, mesh: b.mesh, rig: rig) { clip, time in machinery.joints(clip, time) }
    }

    // MARK: Pieces

    /// The open shed of the first two levels: six posts, braced, under a
    /// gable; walled at the back and the west in planks at the second.
    static func shed(_ b: inout MeshBuilder, walled: Bool, roof: Vec3) {
        let w: Float = 0.3, d: Float = 0.2, h: Float = 0.15
        for x in [-w / 2, 0, w / 2] {
            for z in [-d / 2, d / 2] {
                b.limb(from: Vec3(x, -0.02, z), to: Vec3(x, h, z), radius: 0.009, color: Palette.timber)
                b.fine { $0.beam(from: Vec3(x, h * 0.65, z), to: Vec3(x + (x <= 0 ? 0.04 : -0.04), h, z), width: 0.005, color: Palette.timberDark) }
            }
        }
        for z in [-d / 2, d / 2] {
            b.beam(from: Vec3(-w / 2 - 0.01, h, z), to: Vec3(w / 2 + 0.01, h, z), width: 0.012, color: Palette.timberDark)
        }
        b.with(material: roof == Palette.thatch ? .plain : .plain) {
            $0.gableRoof(width: w, depth: d, base: h, height: 0.08, color: roof, overhang: 0.025)
        }
        b.beam(from: Vec3(-w / 2 - 0.03, h + 0.083, 0), to: Vec3(w / 2 + 0.03, h + 0.083, 0), width: 0.01, color: Palette.timberDark)
        if walled {
            let boards = 9
            for index in 0..<boards {
                let x = -w / 2 + w * (Float(index) + 0.5) / Float(boards)
                b.box(center: Vec3(x, h / 2 - 0.01, -d / 2), size: Vec3(w / Float(boards) - 0.003, h + 0.02, 0.012),
                      color: index % 2 == 0 ? Palette.timberGrey : Palette.timber)
            }
            for index in 0..<6 {
                let z = -d / 2 + d * (Float(index) + 0.5) / 6
                b.box(center: Vec3(-w / 2, h / 2 - 0.01, z), size: Vec3(0.012, h + 0.02, d / 6 - 0.003),
                      color: index % 2 == 0 ? Palette.timber : Palette.timberGrey)
            }
            b.window(Vec3(-w / 2 - 0.007, h * 0.6, 0.02), width: 0.03, height: 0.025, facing: -.pi / 2)
        }
    }

    /// A banker: a mason's bench of two stone legs and a slab, a block on
    /// it half dressed, a mallet and chisel laid by.
    static func banker(_ b: inout MeshBuilder, at: Vec3, block: Bool) {
        for x in [Float(-0.035), 0.035] {
            b.box(center: at + Vec3(x, 0.03, 0), size: Vec3(0.022, 0.06, 0.05), color: Palette.stoneDark)
        }
        b.box(center: at + Vec3(0, 0.066, 0), size: Vec3(0.1, 0.012, 0.06), color: Palette.stone)
        if block {
            b.box(center: at + Vec3(0, 0.094, 0), size: Vec3(0.06, 0.044, 0.04), turn: 0.15, color: Palette.stonePale)
        }
        b.fine { b in
            b.box(center: at + Vec3(0.012, 0.118, 0), size: Vec3(0.036, 0.004, 0.026), turn: 0.15, color: Palette.stoneWhite)
            b.limb(from: at + Vec3(0.04, 0.074, 0.02), to: at + Vec3(0.07, 0.074, 0.025), radius: 0.003, color: Palette.timberPale)
            b.box(center: at + Vec3(0.036, 0.078, 0.02), size: Vec3(0.012, 0.01, 0.01), color: Palette.timberDark)
            b.with(material: .metal) {
                $0.beam(from: at + Vec3(-0.045, 0.074, 0.02), to: at + Vec3(-0.015, 0.074, 0.022), width: 0.004, color: Palette.steel)
            }
            b.sphere(center: at + Vec3(0, 0.005, 0.045), radius: 0.025, rings: 2, sides: 6, color: Palette.stonePale, squash: 0.25)
        }
    }

    /// Blocks heaped, rough from the quarry or squared and stacked.
    static func heap(_ b: inout MeshBuilder, at: Vec3, rough: Bool) {
        if rough {
            for index in 0..<5 {
                let angle = Float(index) * 1.3
                b.rock(center: at + Vec3(0.03 * Float(sin(Double(angle))), 0.018 + Float(index / 3) * 0.025, 0.03 * Float(cos(Double(angle)))),
                       size: Vec3(0.032, 0.026, 0.028), seed: UInt32(index + 11), color: Palette.stone)
            }
        } else {
            for course in 0..<3 {
                for index in 0..<(3 - course) {
                    b.box(center: at + Vec3(-0.03 + Float(index) * 0.03 + Float(course) * 0.015, 0.014 + Float(course) * 0.028, 0),
                          size: Vec3(0.028, 0.026, 0.05), color: course % 2 == 0 ? Palette.stonePale : Palette.stone)
                }
            }
        }
    }

    /// The masons' tools on their rack: squares, levels, mallets, chisels.
    static func toolRack(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.04), 0.04] {
            b.limb(from: at + Vec3(x, 0, 0), to: at + Vec3(x, 0.12, 0), radius: 0.005, color: Palette.timberDark)
        }
        b.beam(from: at + Vec3(-0.05, 0.11, 0), to: at + Vec3(0.05, 0.11, 0), width: 0.008, color: Palette.timber)
        b.fine { b in
            for (index, x) in [Float(-0.03), -0.012, 0.006, 0.024].enumerated() {
                let length: Float = 0.04 + Float(index % 2) * 0.02
                b.limb(from: at + Vec3(x, 0.105, 0.006), to: at + Vec3(x, 0.105 - length, 0.008), radius: 0.003,
                       color: index % 2 == 0 ? Palette.timberPale : Palette.iron)
            }
            b.beam(from: at + Vec3(0.032, 0.1, 0.006), to: at + Vec3(0.032, 0.06, 0.006), width: 0.004, color: Palette.iron)
            b.beam(from: at + Vec3(0.032, 0.06, 0.006), to: at + Vec3(0.05, 0.06, 0.006), width: 0.004, color: Palette.iron)
        }
    }

    /// The jib on its post, its arm slewing with a block slung from it.
    static func jib(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Swing {
        b.box(center: at + Vec3(0, 0.012, 0), size: Vec3(0.05, 0.024, 0.05), color: Palette.stone)
        b.limb(from: at, to: at + Vec3(0, 0.24, 0), radius: 0.01, color: Palette.timberDark)
        let arm = rig.add("lodge jib", pivot: at)
        b.with(part: arm) { b in
            b.beam(from: at + Vec3(0, 0.22, 0), to: at + Vec3(0.14, 0.21, 0), width: 0.012, color: Palette.timber)
            b.beam(from: at + Vec3(0, 0.12, 0), to: at + Vec3(0.09, 0.215, 0), width: 0.007, color: Palette.timber)
            b.limb(from: at + Vec3(0.13, 0.205, 0), to: at + Vec3(0.13, 0.12, 0), radius: 0.002, color: Palette.linen)
            b.box(center: at + Vec3(0.13, 0.1, 0), size: Vec3(0.035, 0.03, 0.03), color: Palette.stonePale)
            b.fine { $0.box(center: at + Vec3(0.13, 0.205, 0), size: Vec3(0.014, 0.02, 0.012), color: Palette.iron) }
        }
        return Machinery.Swing(part: arm, axis: Vec3(0, 1, 0), angle: 0.6)
    }

    /// The hall of white stone from the third level: gabled and slated,
    /// courses dressed, door and windows lit; buttressed with a chimney at
    /// the fourth; dormers, a finial and banners at the fifth.
    static func hall(_ b: inout MeshBuilder, level: Int) {
        let at = Vec3(-0.03, 0, -0.1)
        let w: Float = level >= 4 ? 0.3 : 0.26, d: Float = 0.15, h: Float = level >= 5 ? 0.17 : 0.14
        b.hall(at: at, width: w, depth: d, height: h, wall: Palette.stoneWhite, roof: Palette.slate, pitch: 0.7, footing: Palette.stone)
        b.door(at + Vec3(0, 0.055, d / 2 + 0.002), width: 0.045, height: 0.1, facing: 0)
        b.box(center: at + Vec3(0, 0.112, d / 2 + 0.006), size: Vec3(0.06, 0.012, 0.012), color: Palette.stonePale)
        for x in [-w * 0.32, w * 0.32] {
            b.window(at + Vec3(x, h * 0.6, d / 2 + 0.002), width: 0.026, height: 0.04, facing: 0)
        }
        b.fine { b in
            for y in stride(from: Float(0.03), to: h, by: 0.028) {
                b.box(center: at + Vec3(0, y, d / 2 + 0.001), size: Vec3(w - 0.004, 0.003, 0.003), color: Palette.stonePale)
            }
            for x in [-w * 0.32, w * 0.32] {
                b.box(center: at + Vec3(x, h * 0.6 + 0.026, d / 2 + 0.006), size: Vec3(0.036, 0.008, 0.01), color: Palette.stone)
            }
        }
        if level >= 4 {
            for x in [-w / 2, -w / 6, w / 6, w / 2] {
                b.box(center: at + Vec3(x, h * 0.35, -d / 2 - 0.016), size: Vec3(0.022, h * 0.7 + 0.08, 0.03), color: Palette.stone)
            }
            b.box(min: at + Vec3(w / 2 - 0.07, h, -0.04), max: at + Vec3(w / 2 - 0.035, h + 0.15, -0.005), color: Palette.stoneDark)
            b.fine { $0.box(min: at + Vec3(w / 2 - 0.074, h + 0.15, -0.044), max: at + Vec3(w / 2 - 0.031, h + 0.162, -0.001), color: Palette.stone) }
        }
        if level >= 5 {
            for side in [Float(1), -1] {
                let z = side * d * 0.22
                b.box(min: at + Vec3(-0.035, h + 0.02, z - 0.025), max: at + Vec3(0.035, h + 0.065, z + 0.025), color: Palette.stoneWhite)
                b.place(.translation(at + Vec3(0, h + 0.065, z))) {
                    $0.gableRoof(width: 0.07, depth: 0.05, base: 0, height: 0.03, color: Palette.slate, overhang: 0.008)
                }
                b.window(at + Vec3(0, h + 0.045, z + side * 0.026), width: 0.022, height: 0.024, facing: side > 0 ? 0 : .pi)
            }
            b.with(material: .glow) {
                $0.place(.translation(at + Vec3(0, h + d * 0.7 + 0.03, 0))) {
                    $0.lathe([(0, 0), (0.014, 0.012), (0.008, 0.035), (0, 0.06)], sides: 6, color: Palette.moonsalt)
                }
            }
            for x in [Float(-0.05), 0.05] {
                b.limb(from: at + Vec3(x, h * 0.8, d / 2 + 0.01), to: at + Vec3(x, h * 0.8, d / 2 + 0.06), radius: 0.003, color: Palette.iron)
                b.flag(at: at + Vec3(x, h * 0.8, d / 2 + 0.058), width: 0.035, height: 0.08, turn: -.pi / 2, tail: true)
            }
        }
    }

    /// The tracing floor: pale slabs before the hall, a work drawn out on
    /// them full size in scored lines.
    static func tracingFloor(_ b: inout MeshBuilder, at: Vec3) {
        b.box(center: at + Vec3(0, 0.006, 0), size: Vec3(0.22, 0.012, 0.11), color: Palette.stoneWhite)
        b.fine { b in
            for x in stride(from: Float(-0.1), through: 0.1, by: 0.055) {
                b.box(center: at + Vec3(x, 0.0125, 0), size: Vec3(0.002, 0.001, 0.1), color: Palette.stone)
            }
            // An arch drawn out on it, its voussoirs marked.
            for index in 0...8 {
                let angle = Float.pi * Float(index) / 8
                let p = at + Vec3(0.06 * Float(cos(Double(angle))), 0.013, -0.03 + 0.06 * Float(sin(Double(angle))))
                b.box(center: p, size: Vec3(0.008, 0.001, 0.003), turn: angle, color: Palette.slate)
            }
        }
    }

    /// The treadwheel crane: a great wheel in its frame, a jib above with a
    /// block slung; the wheel turns as the masons walk it.
    static func treadwheel(_ b: inout MeshBuilder, _ rig: inout Rig, at: Vec3) -> Machinery.Wheel {
        let hub = at + Vec3(0, 0.085, 0)
        for z in [Float(-0.035), 0.035] {
            b.beam(from: at + Vec3(-0.06, 0, z), to: hub + Vec3(0, 0, z), width: 0.009, color: Palette.timberDark)
            b.beam(from: at + Vec3(0.06, 0, z), to: hub + Vec3(0, 0, z), width: 0.009, color: Palette.timberDark)
        }
        b.limb(from: at + Vec3(-0.04, 0, 0), to: at + Vec3(-0.04, 0.27, 0), radius: 0.009, color: Palette.timberDark)
        b.beam(from: at + Vec3(-0.04, 0.25, 0), to: at + Vec3(0.06, 0.28, 0.08), width: 0.009, color: Palette.timber)
        b.limb(from: at + Vec3(0.055, 0.27, 0.075), to: at + Vec3(0.055, 0.17, 0.075), radius: 0.002, color: Palette.linen)
        b.box(center: at + Vec3(0.055, 0.155, 0.075), size: Vec3(0.03, 0.028, 0.03), color: Palette.stonePale)
        let wheel = rig.add("treadwheel", pivot: hub)
        b.with(part: wheel) { b in
            b.wheel(center: hub, radius: 0.08, width: 0.06, spokes: 6, color: Palette.timber, rim: Palette.timberDark)
            b.fine { b in
                for index in 0..<12 {
                    let angle = Float(index) / 12 * 2 * .pi
                    let p = hub + Vec3(0, 0.074 * Float(sin(Double(angle))), 0) + Vec3(0.074 * Float(cos(Double(angle))), 0, 0)
                    b.box(center: p, size: Vec3(0.008, 0.008, 0.058), turn: 0, color: Palette.timberPale)
                }
            }
        }
        return Machinery.Wheel(part: wheel, axis: Vec3(0, 0, 1), turns: 1)
    }

    /// A carved arch over the yard's way in: two piers, its voussoirs, a
    /// keystone carved with the House's mark.
    static func arch(_ b: inout MeshBuilder, at: Vec3) {
        for x in [Float(-0.07), 0.07] {
            b.box(center: at + Vec3(x, 0.065, 0), size: Vec3(0.028, 0.13, 0.03), color: Palette.stoneWhite)
            b.box(center: at + Vec3(x, 0.006, 0), size: Vec3(0.036, 0.012, 0.038), color: Palette.stone)
        }
        for index in 0...6 {
            let angle = Float.pi * Float(index) / 6
            let p = at + Vec3(0.07 * Float(cos(Double(angle))), 0.13 + 0.06 * Float(sin(Double(angle))), 0)
            b.box(center: p, size: Vec3(0.026, 0.024, 0.03), turn: 0, color: index == 3 ? Palette.stonePale : Palette.stoneWhite)
        }
        b.fine { b in
            b.box(center: at + Vec3(0, 0.2, 0.016), size: Vec3(0.016, 0.018, 0.004), color: Palette.gold)
            for x in [Float(-0.07), 0.07] {
                b.sphere(center: at + Vec3(x, 0.14, 0.016), radius: 0.008, rings: 2, sides: 5, color: Palette.stonePale)
            }
        }
    }

    /// Chips and dust of the work strewn about the yard.
    static func yardStones(_ b: inout MeshBuilder) {
        for index in 0..<14 {
            let angle = Float(index) * 2.39996
            let r = 0.12 + 0.15 * Float((index * 37) % 11) / 11
            b.box(center: Vec3(r * Float(cos(Double(angle))), 0.014, r * Float(sin(Double(angle)))),
                  size: Vec3(0.012, 0.006, 0.009), turn: angle, color: index % 3 == 0 ? Palette.stoneWhite : Palette.stonePale)
        }
    }

    /// A dry-stone wall round the back half of the yard, higher as the
    /// lodge grows: each stone laid by hand.
    static func boundary(_ b: inout MeshBuilder, courses: Int) {
        let stones = 18
        for index in 0..<stones {
            let angle = Float.pi * (1.08 + 0.84 * Float(index) / Float(stones - 1))
            for course in 0..<courses {
                let a = angle + (course % 2 == 0 ? 0 : 0.5 * 0.84 * Float.pi / Float(stones))
                let p = MeshBuilder.ring(0.295, 0.012 + Float(course) * 0.02, a)
                let shade = (index + course) % 3
                b.box(center: p, size: Vec3(0.05, 0.019, 0.026), turn: -a,
                      color: shade == 0 ? Palette.stone : (shade == 1 ? Palette.stonePale : Palette.rock))
            }
        }
    }

    /// A barrow of timber on its iron-shod wheel, a block in it.
    static func barrow(_ b: inout MeshBuilder, at: Vec3) {
        b.place(.translation(at) * .rotationY(0.5)) { b in
            b.box(min: Vec3(-0.03, 0.025, -0.02), max: Vec3(0.03, 0.05, 0.02), color: Palette.timber)
            b.wheel(center: Vec3(0.04, 0.018, 0), radius: 0.018, width: 0.008, spokes: 4, color: Palette.timberDark, rim: Palette.iron)
            for z in [Float(-0.016), 0.016] {
                b.beam(from: Vec3(0.04, 0.02, z), to: Vec3(-0.07, 0.045, z), width: 0.005, color: Palette.timberDark)
                b.limb(from: Vec3(-0.02, 0.025, z), to: Vec3(-0.02, 0, z), radius: 0.003, color: Palette.timberDark)
            }
            b.box(center: Vec3(0, 0.058, 0), size: Vec3(0.03, 0.02, 0.025), color: Palette.stonePale)
        }
    }

    /// A trough of lime mortar, its paddle across it.
    static func limeTrough(_ b: inout MeshBuilder, at: Vec3) {
        b.box(min: at + Vec3(-0.04, 0, -0.02), max: at + Vec3(0.04, 0.03, 0.02), color: Palette.timberDark)
        b.box(min: at + Vec3(-0.036, 0.024, -0.016), max: at + Vec3(0.036, 0.029, 0.016), color: Palette.stoneWhite)
        b.beam(from: at + Vec3(-0.05, 0.034, 0.0), to: at + Vec3(0.04, 0.04, 0.01), width: 0.004, color: Palette.timberPale)
    }

    /// The hall's walls dressed in courses of ashlar, each block proud.
    static func ashlar(_ b: inout MeshBuilder, at: Vec3, width: Float, depth: Float, height: Float) {
        b.fine { b in
            let rows = Int(height / 0.034)
            for row in 0..<rows {
                let y = 0.022 + Float(row) * 0.034
                let offset: Float = row % 2 == 0 ? 0 : 0.03
                for x in stride(from: -width / 2 + 0.03 + offset, to: width / 2 - 0.02, by: 0.06) {
                    b.box(center: at + Vec3(x, y, -depth / 2 - 0.002), size: Vec3(0.056, 0.03, 0.004), color: Palette.stoneWhite * 0.96)
                }
                for z in stride(from: -depth / 2 + 0.03 + offset, to: depth / 2 - 0.02, by: 0.06) {
                    for side in [Float(-1), 1] where width < 0.3 {
                        b.box(center: at + Vec3(side * (width / 2 + 0.002), y, z), size: Vec3(0.004, 0.03, 0.056), color: Palette.stoneWhite * 0.96)
                    }
                }
            }
        }
    }

    /// Scaffold poles lashed against the hall's east gable while it is
    /// still being raised higher: standards, ledgers and two boards.
    static func scaffold(_ b: inout MeshBuilder, at: Vec3) {
        for z in [Float(-0.06), 0.0, 0.06] {
            for x in [Float(0.0), 0.04] {
                b.limb(from: at + Vec3(x, -0.02, z), to: at + Vec3(x, 0.25, z), radius: 0.004, color: Palette.timberGrey)
            }
        }
        for y in [Float(0.08), 0.16, 0.23] {
            for x in [Float(0.0), 0.04] {
                b.beam(from: at + Vec3(x, y, -0.065), to: at + Vec3(x, y, 0.065), width: 0.004, color: Palette.timberGrey)
            }
            b.box(center: at + Vec3(0.02, y + 0.004, 0), size: Vec3(0.045, 0.004, 0.13), color: Palette.timberPale)
        }
    }
}
