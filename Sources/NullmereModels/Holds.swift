import Foundation
import NullmereCore

/// How a people builds its keep: the stone or timber of its walls, the trim
/// of its parapet and hall, its roof and how steep, and what crowns the
/// tower. The common keep is dressed grey stone under slate.
struct KeepStyle {
    enum Crown {
        case none
        /// Moonsalt grown about the tower's peak.
        case crystals
        /// A beacon burning on the parapet, for boats on the dark water.
        case beacon
    }

    var wall = Palette.stone
    var dark = Palette.stoneDark
    var trim = Palette.stonePale
    var roof = Palette.slate
    /// The grain drawn on the walls and on the roof, where their colours
    /// alone would not say it.
    var wallGrain: Surface?
    var roofGrain: Surface?
    /// The tower roof's height against the common keep's.
    var pitch: Float = 1
    var crown = Crown.none

    static let common = KeepStyle()
    /// The strand's blue-grey slate.
    static let seaSlate = Vec3(0.26, 0.31, 0.37)

    /// Each people's keep: the Saltborn's salt-white stone crowned with
    /// moonsalt; the Fenfolk's weathered timber under steep reed; the
    /// Blackwood Kin's dark timber under steeper shingle; the Spinewardens'
    /// raw rock under a low slate roof; the Mound Clans' pale stone under
    /// turf; the Strandfolk's whitewash under sea-slate, a beacon burning.
    static func of(_ heritage: Heritage) -> KeepStyle {
        switch heritage {
        case .saltborn:
            return KeepStyle(wall: Palette.saltCrust, dark: Palette.stonePale, trim: Palette.stoneWhite, roof: Palette.stoneWhite,
                             wallGrain: .stone, roofGrain: .slate, crown: .crystals)
        case .fenfolk:
            return KeepStyle(wall: Palette.timberGrey, dark: Palette.timberDark, trim: Palette.timberPale, roof: Palette.reed,
                             pitch: 1.5)
        case .blackwood:
            return KeepStyle(wall: Palette.timberDark, dark: Palette.bark, trim: Palette.timber, roof: Palette.barkBlack,
                             roofGrain: .timber, pitch: 1.7)
        case .spinewardens:
            return KeepStyle(wall: Palette.rock, dark: Palette.stoneDark, trim: Palette.stone, roof: Palette.slate, pitch: 0.7)
        case .moundClans:
            return KeepStyle(wall: Palette.stonePale, dark: Palette.earth, trim: Palette.stoneWhite, roof: Palette.moss,
                             roofGrain: .earth, pitch: 0.6)
        case .strandfolk:
            return KeepStyle(wall: Palette.linen, dark: Palette.stoneDark, trim: Palette.stoneWhite, roof: KeepStyle.seaSlate,
                             wallGrain: .stone, roofGrain: .slate, crown: .beacon)
        }
    }
}

/// A hold's keep and walls, and the scaffold round a rising work.
enum Holds {
    // MARK: The keep

    /// A square tower over a hall, its roofs and pennant the House's; a
    /// seat's tower stands higher between two round towers and flies the
    /// House's great banner. Its walls, roof and crown are its people's. It
    /// faces +z.
    static func keep(seat: Bool, name: String, style: KeepStyle = .common) -> Model {
        var b = MeshBuilder()
        let towerHeight: Float = seat ? 0.92 : 0.6
        let half: Float = seat ? 0.17 : 0.155
        let parapet = half + 0.025
        let roofHeight: Float = (seat ? 0.3 : 0.22) * style.pitch
        b.with(surface: style.wallGrain) { b in
            // A plinth of dressed stone, deep enough to stand on a slope.
            b.lathe([(0.37, -0.3), (0.37, 0.025), (0.34, 0.045)], sides: 8, color: style.dark, twist: .pi / 8)
            // The tower, buttressed at its corners, its parapet corbelled out.
            b.box(min: Vec3(-half, 0.03, -half - 0.05), max: Vec3(half, towerHeight, half - 0.05), color: style.wall)
            for x in [-half, half] {
                for z in [-half - 0.05, half - 0.05] {
                    b.place(.translation(Vec3(x, 0.03, z))) {
                        $0.lathe([(0.045, 0), (0.035, towerHeight * 0.55), (0.0, towerHeight * 0.62)], sides: 4, color: style.dark,
                                 twist: .pi / 4)
                    }
                }
            }
            b.box(min: Vec3(-parapet, towerHeight - 0.01, -parapet - 0.05), max: Vec3(parapet, towerHeight + 0.06, parapet - 0.05),
                  color: style.trim)
            let corners = [Vec3(-parapet, 0, -parapet), Vec3(parapet, 0, -parapet), Vec3(parapet, 0, parapet), Vec3(-parapet, 0, parapet)]
            for index in 0..<4 {
                let a = corners[index] + Vec3(0, towerHeight + 0.06, -0.05), c = corners[(index + 1) % 4] + Vec3(0, towerHeight + 0.06, -0.05)
                b.merlons(from: a, to: c, count: 3, size: Vec3(0.06, 0.05, 0.035), color: style.trim)
            }
        }
        b.with(surface: style.roofGrain) {
            $0.place(.translation(Vec3(0, 0, -0.05))) {
                $0.hipRoof(width: half * 1.7, depth: half * 1.7, base: towerHeight + 0.04, height: roofHeight, color: style.roof)
            }
        }
        switch style.crown {
        case .none:
            break
        case .crystals:
            // Moonsalt grown about the peak, round the banner's pole.
            let peak = towerHeight + 0.04 + roofHeight
            b.with(material: .crystal) {
                for (index, offset) in [Vec3(0.03, 0, -0.03), Vec3(-0.032, 0, -0.06), Vec3(0.006, 0, -0.088)].enumerated() {
                    let tall = 0.07 + 0.025 * Float(index)
                    $0.place(.translation(offset + Vec3(0, peak - 0.05, 0))) {
                        $0.cone(sides: 5, radius: 0.016, to: tall, color: Palette.moonsalt, twist: Float(index))
                    }
                }
            }
        case .beacon:
            // A brazier on the parapet's seaward corner, burning.
            let corner = Vec3(parapet - 0.03, towerHeight + 0.06, parapet - 0.08)
            b.box(min: corner + Vec3(-0.025, 0, -0.025), max: corner + Vec3(0.025, 0.035, 0.025), color: style.dark)
            b.with(material: .glow) {
                $0.box(min: corner + Vec3(-0.018, 0.035, -0.018), max: corner + Vec3(0.018, 0.07, 0.018), color: Palette.fire)
            }
        }
        // Lit windows high on the tower, on every face.
        for window in towerWindows(seat: seat, half: half) {
            b.window(window.at, width: 0.035, height: 0.07, facing: window.facing)
        }
        // The hall before it, roofed in the House's colour.
        let hallFront: Float = seat ? 0.34 : 0.3
        b.with(surface: style.wallGrain) {
            $0.box(min: Vec3(-0.2, 0.03, half - 0.06), max: Vec3(0.2, 0.25, hallFront), color: style.trim)
        }
        b.with(material: .house) {
            $0.place(.translation(Vec3(0, 0, (half - 0.06 + hallFront) / 2)) * .rotationY(.pi / 2)) {
                $0.gableRoof(width: hallFront - half + 0.06, depth: 0.4, base: 0.25, height: 0.13, color: Palette.house, overhang: 0.025)
            }
        }
        let flue = chimney(seat: seat)
        b.with(surface: style.wallGrain) {
            $0.box(min: Vec3(flue.x - 0.026, 0.22, flue.z - 0.026), max: Vec3(flue.x + 0.026, flue.y - 0.01, flue.z + 0.026),
                   color: style.dark)
        }
        b.door(Vec3(0, 0.1, hallFront), width: 0.07, height: 0.13, facing: 0)
        for x in [Float(-0.12), 0.12] {
            b.window(Vec3(x, 0.15, hallFront), width: 0.03, height: 0.05, facing: 0)
        }
        // The House's pennant over the tower.
        let poleTop = towerHeight + (seat ? 0.62 : 0.42)
        b.limb(from: Vec3(0, towerHeight + 0.1, -0.05), to: Vec3(0, poleTop, -0.05), radius: 0.008, sides: 4, color: Palette.timberDark)
        b.flag(at: Vec3(0, poleTop - 0.01, -0.05), width: seat ? 0.34 : 0.18, height: seat ? 0.22 : 0.08, turn: .pi / 2,
               tail: !seat)
        if seat {
            // Two round towers flanking the keep, their cones the House's.
            for x in [Float(-0.26), 0.26] {
                b.place(.translation(Vec3(x, 0.03, -0.08))) {
                    $0.with(surface: style.wallGrain) {
                        $0.lathe([(0.09, 0), (0.085, 0.62), (0.105, 0.64), (0.105, 0.7)], sides: 8, color: style.wall)
                        $0.merlonRing(radius: 0.098, base: 0.7, count: 6, size: Vec3(0.04, 0.045, 0.03), color: style.trim)
                    }
                    $0.with(material: .house) {
                        $0.cone(sides: 8, radius: 0.1, from: 0.69, to: 0.98, color: Palette.house)
                    }
                    $0.window(Vec3(0, 0.45, 0.087), width: 0.03, height: 0.06, facing: 0)
                }
            }
            // A curtain between them behind the keep.
            b.with(surface: style.wallGrain) {
                $0.box(min: Vec3(-0.26, 0.03, -0.17), max: Vec3(0.26, 0.4, -0.08), color: style.dark)
            }
        }
        dress(&b, seat: seat, style: style, half: half, towerHeight: towerHeight, hallFront: hallFront, roofHeight: roofHeight)
        b.fine { detail(&$0, seat: seat, style: style, half: half, towerHeight: towerHeight, hallFront: hallFront, roofHeight: roofHeight) }
        return Model(name: name, mesh: b.mesh)
    }

    /// Where the tower's lit windows are, and which way each faces: on
    /// every face, twice up a seat's taller tower, but where its banner
    /// hangs down the front.
    static func towerWindows(seat: Bool, half: Float) -> [(facing: Float, at: Vec3)] {
        let faces: [(Float, Vec3)] = [(0, Vec3(0, 0, half - 0.05)), (.pi, Vec3(0, 0, -half - 0.05)), (.pi / 2, Vec3(half, 0, -0.05)),
                                      (-.pi / 2, Vec3(-half, 0, -0.05))]
        return faces.dropFirst(seat ? 1 : 0).flatMap { facing, offset in
            (seat ? [Float(0.45), 0.72] : [Float(0.42)]).map { (facing, offset + Vec3(0, $0, 0)) }
        }
    }

    /// The keep's dressing: courses of dressed stone girdling the tower,
    /// corbels under its parapet and slits for its bows; dormers lit in its
    /// roof; at a seat, the House's banner hung down the tower's face; and
    /// before the hall, steps up to its door, posts framing it, a lantern
    /// either side and the hall's stores in barrels and crates.
    static func dress(_ b: inout MeshBuilder, seat: Bool, style: KeepStyle, half: Float, towerHeight: Float, hallFront: Float,
                      roofHeight: Float) {
        let back = -half - 0.05, front = half - 0.05
        b.with(surface: style.wallGrain) { b in
            for level in [towerHeight * 0.36, towerHeight * 0.7] {
                b.box(min: Vec3(-half - 0.008, level, back - 0.008), max: Vec3(half + 0.008, level + 0.016, front + 0.008), color: style.trim)
            }
            // Three corbels to a face under the parapet.
            let y = towerHeight - 0.045
            for index in 0..<3 {
                let t = (Float(index) - 1) * half * 0.62
                b.box(center: Vec3(t, y, front + 0.012), size: Vec3(0.026, 0.03, 0.024), color: style.trim)
                b.box(center: Vec3(t, y, back - 0.012), size: Vec3(0.026, 0.03, 0.024), color: style.trim)
                b.box(center: Vec3(half + 0.012, y, -0.05 + t), size: Vec3(0.024, 0.03, 0.026), color: style.trim)
                b.box(center: Vec3(-half - 0.012, y, -0.05 + t), size: Vec3(0.024, 0.03, 0.026), color: style.trim)
            }
        }
        // Slits for its bows, on the back and the sides between the courses.
        let slit = towerHeight * 0.53
        b.box(center: Vec3(0, slit, back - 0.004), size: Vec3(0.012, 0.07, 0.01), color: Palette.timberDark)
        for x in [half + 0.004, -half - 0.004] {
            b.box(center: Vec3(x, slit, -0.05), size: Vec3(0.01, 0.07, 0.012), color: Palette.timberDark)
        }
        // Dormers lit in the roof, front and back.
        let roofBase = towerHeight + 0.04
        for side in [Float(1), -1] {
            let at = Vec3(0, roofBase + roofHeight * 0.3, -0.05 + side * half * 0.36)
            b.place(.translation(at) * .rotationY(side > 0 ? 0 : .pi)) {
                $0.with(surface: style.wallGrain) {
                    $0.box(min: Vec3(-0.026, -0.02, -0.03), max: Vec3(0.026, 0.035, 0.012), color: style.wall)
                }
                $0.with(surface: style.roofGrain) {
                    $0.place(.translation(Vec3(0, 0, -0.009)) * .rotationY(.pi / 2)) {
                        $0.gableRoof(width: 0.042, depth: 0.056, base: 0.035, height: 0.028, color: style.roof, overhang: 0.006)
                    }
                }
                $0.window(Vec3(0, 0.008, 0.013), width: 0.022, height: 0.026, facing: 0)
            }
        }
        // A seat's banner, hung down the tower's face above the hall roof.
        if seat {
            let top = Vec3(0, towerHeight - 0.08, front + 0.006), drop = towerHeight - 0.08 - 0.44
            b.with(material: .cloth, sway: 0.35) {
                $0.swayRange = (0, drop)
                $0.place(.translation(top) * .rotationZ(.pi)) {
                    $0.sheet([Vec3(-0.045, 0, 0), Vec3(0.045, 0, 0), Vec3(0.045, drop, 0), Vec3(0, drop + 0.03, 0), Vec3(-0.045, drop, 0)],
                             normal: Vec3(0, 0, 1), thickness: 0.004, color: Palette.house)
                }
            }
            b.beam(from: top + Vec3(-0.055, 0.004, 0.004), to: top + Vec3(0.055, 0.004, 0.004), width: 0.01, depth: 0.012, color: Palette.timberDark)
        }
        // Steps up to the hall's door, posts framing its front, a lantern either side.
        b.with(surface: style.wallGrain) {
            $0.box(min: Vec3(-0.06, 0.0, hallFront), max: Vec3(0.06, 0.045, hallFront + 0.025), color: style.trim)
            $0.box(min: Vec3(-0.045, 0.0, hallFront + 0.025), max: Vec3(0.045, 0.025, hallFront + 0.045), color: style.trim)
        }
        for x in [Float(-0.2), -0.055, 0.055, 0.2] {
            b.box(center: Vec3(x, 0.14, hallFront + 0.004), size: Vec3(0.014, 0.22, 0.012), color: Palette.timberDark)
        }
        for x in [Float(-0.075), 0.075] {
            b.beam(from: Vec3(x, 0.17, hallFront + 0.005), to: Vec3(x, 0.17, hallFront + 0.03), width: 0.006, color: Palette.iron)
            b.with(material: .glow) {
                $0.box(center: Vec3(x, 0.152, hallFront + 0.03), size: Vec3(0.014, 0.022, 0.014), color: Palette.candle)
            }
        }
        // The hall's stores beside it.
        for (index, at) in [Vec3(-0.25, 0.03, 0.17), Vec3(-0.25, 0.03, 0.23), Vec3(0.27, 0.03, 0.2)].enumerated() {
            b.place(.translation(at)) {
                $0.lathe([(0.022, 0), (0.026, 0.024), (0.022, 0.048)], sides: 6, color: index == 2 ? Palette.timberPale : Palette.timber)
            }
        }
        b.box(center: Vec3(0.24, 0.05, 0.25), size: Vec3(0.04, 0.04, 0.04), turn: 0.3, color: Palette.timberGrey)
    }

    /// The keep's finer work: quoins up the tower's corners above its
    /// buttresses; its windows framed, a sill under each and a lintel over
    /// it, the shutters thrown back in the House's colour; ribs down the
    /// roof's hips and courses across it; the hall's frame of rails, posts
    /// and braces, lit windows down its sides and its chimney capped with
    /// two pots; at a seat, a string course and slits round each round
    /// tower and a pennant over its cone; and a pile of logs and a handcart
    /// beside the tower.
    static func detail(_ b: inout MeshBuilder, seat: Bool, style: KeepStyle, half: Float, towerHeight: Float, hallFront: Float,
                       roofHeight: Float) {
        let back = -half - 0.05, front = half - 0.05, middle: Float = -0.05
        b.with(surface: style.wallGrain) { b in
            var y = towerHeight * 0.6, course = 0
            while y + 0.036 <= towerHeight - 0.07 {
                let along: Float = course % 2 == 0 ? 0.07 : 0.042, across: Float = course % 2 == 0 ? 0.042 : 0.07
                for x in [-half, half] {
                    for z in [back, front] {
                        let sx: Float = x > 0 ? 1 : -1, sz: Float = z > middle ? 1 : -1
                        b.box(center: Vec3(x + sx * (0.006 - along / 2), y + 0.018, z + sz * (0.006 - across / 2)),
                              size: Vec3(along, 0.036, across), color: style.trim)
                    }
                }
                y += 0.042
                course += 1
            }
        }
        for window in towerWindows(seat: seat, half: half) {
            b.place(.translation(window.at) * .rotationY(window.facing)) {
                $0.with(surface: style.wallGrain) {
                    $0.box(center: Vec3(0, -0.041, 0.006), size: Vec3(0.054, 0.012, 0.026), color: style.trim)
                    $0.box(center: Vec3(0, 0.042, 0.004), size: Vec3(0.05, 0.014, 0.02), color: style.trim)
                }
                $0.with(material: .house) {
                    for side in [Float(-1), 1] {
                        $0.box(center: Vec3(side * 0.03, 0, 0.007), size: Vec3(0.017, 0.068, 0.006), color: Palette.house)
                    }
                }
            }
        }
        // The tower roof's hips ribbed and two courses across it.
        let base = towerHeight + 0.04, reach = half * 0.85, rib = style.roof * 0.7
        let apex = Vec3(0, base + roofHeight, middle)
        b.with(surface: style.roofGrain) { b in
            for (x, z) in [(-reach, -reach), (reach, -reach), (reach, reach), (-reach, reach)] {
                b.beam(from: Vec3(x, base, middle + z), to: apex, width: 0.012, color: rib)
            }
            for t in [Float(0.22), 0.58] {
                let r = reach * (1 - t), y = base + roofHeight * t
                let corners = [Vec3(-r, y, middle - r), Vec3(r, y, middle - r), Vec3(r, y, middle + r), Vec3(-r, y, middle + r)]
                for index in 0..<4 {
                    b.beam(from: corners[index], to: corners[(index + 1) % 4], width: 0.009, color: rib)
                }
            }
        }
        // The hall's frame: rails across its front either side of the door,
        // braces in the outer bays, and rails and a post down each side,
        // where two windows are lit.
        let hallMiddle = (half - 0.06 + hallFront) / 2, face = hallFront + 0.004
        for side in [Float(-1), 1] {
            b.beam(from: Vec3(side * 0.193, 0.205, face), to: Vec3(side * 0.062, 0.205, face), width: 0.012, depth: 0.012,
                   color: Palette.timberDark)
            b.beam(from: Vec3(side * 0.19, 0.045, face), to: Vec3(side * 0.143, 0.198, face), width: 0.01, depth: 0.01,
                   color: Palette.timberDark)
            let wall = side * 0.204
            for y in [Float(0.07), 0.205] {
                b.beam(from: Vec3(wall, y, front), to: Vec3(wall, y, hallFront), width: 0.012, depth: 0.012, color: Palette.timberDark)
            }
            b.box(center: Vec3(wall, 0.14, hallMiddle), size: Vec3(0.012, 0.22, 0.014), color: Palette.timberDark)
            for z in [hallMiddle - 0.06, hallMiddle + 0.06] {
                b.window(Vec3(side * 0.2, 0.15, z), width: 0.03, height: 0.05, facing: side * .pi / 2)
            }
        }
        // The chimney capped, two pots on it.
        let flue = chimney(seat: seat)
        b.with(surface: style.wallGrain) {
            $0.box(center: Vec3(flue.x, 0.415, flue.z), size: Vec3(0.066, 0.016, 0.066), color: style.trim)
        }
        for dx in [Float(-0.014), 0.014] {
            b.place(.translation(Vec3(flue.x + dx, 0.423, flue.z))) {
                $0.lathe([(0.009, 0), (0.0075, 0.022)], sides: 5, color: Palette.earth)
            }
        }
        if seat {
            for x in [Float(-0.26), 0.26] {
                b.place(.translation(Vec3(x, 0.03, -0.08))) {
                    $0.with(surface: style.wallGrain) {
                        $0.lathe([(0.086, 0.36), (0.097, 0.366), (0.097, 0.38), (0.086, 0.386)], sides: 8, color: style.trim)
                    }
                    let outward: [Float] = x < 0 ? [.pi, .pi * 0.75, .pi * 1.25] : [0, .pi * 0.25, -.pi * 0.25]
                    for angle in outward {
                        $0.place(.translation(MeshBuilder.ring(0.087, 0.24, angle)) * .rotationY(angle + .pi / 2)) {
                            $0.box(center: .zero, size: Vec3(0.012, 0.06, 0.016), color: Palette.timberDark)
                        }
                    }
                    $0.limb(from: Vec3(0, 0.95, 0), to: Vec3(0, 1.08, 0), radius: 0.006, color: Palette.timberDark)
                    $0.flag(at: Vec3(0, 1.075, 0), width: 0.075, height: 0.032, turn: x < 0 ? .pi : 0, tail: true)
                }
            }
        }
        // Logs stacked by the tower's flank, and a handcart on its other
        // side, clear of a seat's round towers.
        let logs: (Float, Float) = seat ? (0.035, 0.13) : (-0.06, 0.06)
        for (x, y) in [(Float(-0.222), Float(0.047)), (-0.256, 0.047), (-0.239, 0.075)] {
            b.log(from: Vec3(x, y, logs.0), to: Vec3(x, y, logs.1), radius: 0.016)
        }
        b.place(.translation(Vec3(0.27, 0.03, seat ? 0.065 : -0.03))) {
            $0.box(min: Vec3(-0.032, 0.05, -0.05), max: Vec3(0.032, 0.062, 0.05), color: Palette.timberPale)
            for side in [Float(-1), 1] {
                $0.box(min: Vec3(side * 0.032 - 0.004, 0.062, -0.05), max: Vec3(side * 0.032 + 0.004, 0.085, 0.05), color: Palette.timber)
                $0.beam(from: Vec3(side * 0.024, 0.056, 0.05), to: Vec3(side * 0.024, 0.012, 0.1), width: 0.008, color: Palette.timber)
                $0.wheel(center: Vec3(side * 0.044, 0.04, 0), radius: 0.038, width: 0.008, color: Palette.timberDark)
            }
        }
    }

    /// The top of the keep's hall chimney.
    static func chimney(seat: Bool) -> Vec3 {
        let half: Float = seat ? 0.17 : 0.155, front: Float = seat ? 0.34 : 0.3
        return Vec3(0.13, 0.43, (half - 0.06 + front) / 2)
    }

    // MARK: The walls

    /// The walls' ring: corners on this radius, flats facing ±z with the
    /// gate in the +z flat. Turned 30° (and any sixth), it sits within a
    /// hex with its gate toward a neighbour.
    static let wallRadius: Float = 0.84

    static func wallCorner(_ index: Int) -> Vec3 {
        let angle = Float(index) * .pi / 3
        return Vec3(wallRadius * Float(cos(Double(angle))), 0, wallRadius * Float(sin(Double(angle))))
    }

    /// From a palisade of stakes to high walls with round towers roofed in
    /// the House's colour and a gatehouse flying its banner.
    static func walls(level: Int, name: String) -> Model {
        var b = MeshBuilder()
        let height: [Float] = [0.2, 0.17, 0.22, 0.27, 0.32]
        let h = height[min(max(level, 1), 5) - 1]
        let thick: Float = level == 1 ? 0.035 : 0.05 + 0.006 * Float(level)
        let gateHalf: Float = 0.085
        // Each side between corners; the gate's side (corners 1 and 2) is split by the gate.
        var runs: [(Vec3, Vec3)] = []
        for index in 0..<6 {
            let a = wallCorner(index), c = wallCorner(index + 1)
            if index == 1 {
                runs.append((a, Vec3(gateHalf, 0, a.z)))
                runs.append((Vec3(-gateHalf, 0, a.z), c))
            } else {
                runs.append((a, c))
            }
        }
        if level == 1 {
            // A palisade of sharpened stakes.
            for (a, c) in runs {
                let count = max(Int(((c - a).length / 0.055).rounded()), 2)
                for index in 0..<count {
                    let t = (Float(index) + 0.5) / Float(count)
                    let at = a.mix(c, t)
                    let tall = h * (0.9 + 0.2 * Noise.unit(Int32(index), Int32(at.x * 100), 7))
                    b.place(.translation(at + Vec3(0, -0.3, 0))) {
                        $0.tube([(0.02, 0), (0.02, tall + 0.3)], sides: 3, color: Palette.timber, twist: Float(index))
                        $0.cone(sides: 3, radius: 0.02, from: tall + 0.3, to: tall + 0.35, color: Palette.timberPale,
                                twist: Float(index))
                    }
                }
            }
            // A walkway of planks behind the gate and a lintel over it.
            b.beam(from: Vec3(-gateHalf - 0.03, h + 0.03, wallCorner(1).z), to: Vec3(gateHalf + 0.03, h + 0.03, wallCorner(1).z),
                   width: 0.04, depth: 0.035, color: Palette.timber)
            for x in [-gateHalf - 0.01, gateHalf + 0.01] {
                b.limb(from: Vec3(x, -0.3, wallCorner(1).z), to: Vec3(x, h + 0.06, wallCorner(1).z), radius: 0.024, color: Palette.timberDark)
            }
        } else {
            for (a, c) in runs {
                b.beam(from: a + Vec3(0, (h - 0.3) / 2, 0), to: c + Vec3(0, (h - 0.3) / 2, 0), width: thick, depth: h + 0.3,
                       color: level == 2 ? Palette.stoneDark : Palette.stone)
                if level >= 3 {
                    let count = max(Int(((c - a).length / 0.075).rounded()), 1)
                    b.merlons(from: a + Vec3(0, h, 0), to: c + Vec3(0, h, 0), count: count, size: Vec3(0.04, 0.045, thick * 0.9),
                              color: Palette.stonePale)
                }
            }
            // A low wall's corners stand on squat piers of dressed stone.
            if level == 2 {
                for index in 0..<6 {
                    let at = wallCorner(index)
                    b.box(center: at + Vec3(0, (h - 0.25) / 2, 0), size: Vec3(0.11, h + 0.35, 0.11), turn: Float(index) * .pi / 3,
                          color: Palette.stone)
                    b.box(center: at + Vec3(0, h + 0.045, 0), size: Vec3(0.13, 0.02, 0.13), turn: Float(index) * .pi / 3,
                          color: Palette.stonePale)
                }
            }
        }
        // Corner towers from the third level: square, then round and roofed.
        if level >= 3 {
            let towerHeight = h + 0.12 + 0.05 * Float(level - 3)
            let radius: Float = 0.075 + 0.012 * Float(level - 3)
            for index in 0..<6 {
                let at = wallCorner(index)
                b.place(.translation(at + Vec3(0, -0.1, 0))) {
                    if level == 3 {
                        $0.lathe([(radius * 1.3, -0.2), (radius * 1.25, towerHeight + 0.1)], sides: 4, color: Palette.stone, twist: .pi / 4)
                        $0.merlonRing(radius: radius * 0.95, base: towerHeight + 0.1, count: 4, size: Vec3(0.04, 0.04, 0.03),
                                      color: Palette.stonePale)
                    } else {
                        $0.lathe([(radius * 1.08, -0.2), (radius, towerHeight + 0.1), (radius * 1.12, towerHeight + 0.12),
                                  (radius * 1.12, towerHeight + 0.15)], sides: 8, color: Palette.stone)
                        $0.with(material: level == 5 ? .house : .plain) {
                            $0.cone(sides: 8, radius: radius * 1.16, from: towerHeight + 0.15, to: towerHeight + 0.15 + radius * 2.6,
                                    color: level == 5 ? Palette.house : Palette.slate)
                        }
                    }
                }
            }
        }
        dressWalls(&b, level: level, height: h, thick: thick, runs: runs, half: gateHalf)
        gate(&b, level: level, height: h, half: gateHalf)
        b.fine { detailWalls(&$0, level: level, height: h, thick: thick, runs: runs, half: gateHalf) }
        return Model(name: name, mesh: b.mesh)
    }

    /// The walls' finer work: a palisade's lashings; a stone wall's
    /// arrow loops between its buttresses, and from the third level a
    /// string course along its face and a wall-walk behind its merlons;
    /// slits and a course round each round corner tower and a finial on its
    /// roof; iron bands across the gate's leaves.
    static func detailWalls(_ b: inout MeshBuilder, level: Int, height h: Float, thick: Float, runs: [(Vec3, Vec3)], half: Float) {
        for (a, c) in runs {
            let along = c - a
            let turn = Float(atan2(Double(along.x), Double(along.z))) - .pi / 2
            let middle = (a + c) * 0.5
            let out = Vec3(middle.x, 0, middle.z).normalized
            if level == 1 {
                // Lashings binding the stakes, twice up.
                for y in [h * 0.35, h * 0.75] {
                    b.beam(from: a + Vec3(0, y, 0) + out * 0.021, to: c + Vec3(0, y, 0) + out * 0.021, width: 0.006, depth: 0.012,
                           color: Palette.leatherDark)
                }
                continue
            }
            let face = out * (thick / 2 + 0.002)
            // Arrow loops midway between the buttresses.
            let count = max(Int((along.length / 0.2).rounded()) - 1, 1)
            for index in stride(from: 1, to: count, by: 1) {
                let at = a.mix(c, (Float(index) + 0.5) / Float(count + 1)) + face
                b.box(center: at + Vec3(0, h * 0.55, 0), size: Vec3(0.012, 0.055, 0.012), turn: turn, color: Palette.timberDark)
            }
            if level >= 3 {
                b.beam(from: a + Vec3(0, h * 0.82, 0) + face, to: c + Vec3(0, h * 0.82, 0) + face, width: 0.012, depth: 0.012,
                       color: Palette.stonePale)
                // The wall-walk's boards behind the merlons.
                let walk = out * -(thick / 2 + 0.012)
                b.beam(from: a + Vec3(0, h - 0.012, 0) + walk, to: c + Vec3(0, h - 0.012, 0) + walk, width: 0.024, depth: 0.008,
                       color: Palette.timber)
            }
        }
        if level >= 4 {
            let towerHeight = h + 0.12 + 0.05 * Float(level - 3)
            let radius: Float = 0.075 + 0.012 * Float(level - 3)
            for index in 0..<6 {
                let at = wallCorner(index)
                let outward = Float(atan2(Double(-at.z), Double(at.x)))
                b.place(.translation(at + Vec3(0, -0.1, 0))) {
                    for spread in [Float(-0.5), 0.5] {
                        let angle = outward + spread
                        $0.place(.translation(MeshBuilder.ring(radius * 1.04, towerHeight * 0.62, angle)) * .rotationY(angle + .pi / 2)) {
                            $0.box(center: .zero, size: Vec3(0.012, 0.05, 0.016), color: Palette.timberDark)
                        }
                    }
                    let course = towerHeight * 0.45
                    $0.lathe([(radius * 0.98, course), (radius * 1.1, course + 0.005), (radius * 1.1, course + 0.015),
                              (radius * 0.98, course + 0.02)], sides: 8, color: Palette.stonePale)
                    let top = towerHeight + 0.15 + radius * 2.6
                    $0.limb(from: Vec3(0, top - 0.015, 0), to: Vec3(0, top + 0.05, 0), radius: 0.006, topRadius: 0.002, color: Palette.iron)
                }
            }
        }
        // Iron bands across the gate's open leaves.
        let z = wallCorner(1).z
        for side in [Float(1), -1] {
            for y in [Float(0.05), min(h, 0.2) - 0.05] {
                b.box(center: Vec3(side * half * 0.72, y, z + 0.035), size: Vec3(0.016, 0.01, 0.078), turn: side * 0.9, color: Palette.iron)
            }
        }
    }

    /// The walls' dressing: from the second level, buttresses along their
    /// outer face and, on a low wall, a coping of pale stone; torches
    /// burning either side of the gate at every level; and from the fourth,
    /// the House's banners hung either side of it.
    static func dressWalls(_ b: inout MeshBuilder, level: Int, height h: Float, thick: Float, runs: [(Vec3, Vec3)], half: Float) {
        if level >= 2 {
            for (a, c) in runs {
                let along = c - a
                let turn = Float(atan2(Double(along.x), Double(along.z))) - .pi / 2
                let middle = (a + c) * 0.5
                let out = Vec3(middle.x, 0, middle.z).normalized
                if level == 2 {
                    b.beam(from: a + Vec3(0, h, 0), to: c + Vec3(0, h, 0), width: thick + 0.024, depth: 0.022, color: Palette.stonePale)
                }
                let count = max(Int((along.length / 0.2).rounded()) - 1, 1)
                for index in 1...count {
                    let at = a.mix(c, Float(index) / Float(count + 1)) + out * (thick / 2 + 0.014)
                    b.box(center: at + Vec3(0, (h * 0.8 - 0.3) / 2, 0), size: Vec3(0.036, h * 0.8 + 0.3, 0.028), turn: turn,
                          color: Palette.stoneDark)
                }
            }
        }
        // Torches either side of the gate, out before it.
        let z = wallCorner(1).z + 0.09
        for side in [Float(1), -1] {
            let x = side * (half + 0.012)
            b.limb(from: Vec3(x, -0.05, z), to: Vec3(x, 0.15, z), radius: 0.006, sides: 4, color: Palette.timberDark)
            b.box(center: Vec3(x, 0.155, z), size: Vec3(0.02, 0.012, 0.02), color: Palette.iron)
            b.with(material: .glow) {
                $0.box(center: Vec3(x, 0.175, z), size: Vec3(0.014, 0.028, 0.014), color: Palette.fire)
            }
        }
        // The House's banners down the walls either side of the gate.
        if level >= 4 {
            for (a, c) in runs where a.z > 0.5 && c.z > 0.5 {
                let middle = (a + c) * 0.5, top = middle + Vec3(0, h - 0.03, thick / 2 + 0.006)
                b.with(material: .cloth, sway: 0.3) {
                    $0.swayRange = (0, 0.14)
                    $0.place(.translation(top) * .rotationZ(.pi)) {
                        $0.sheet([Vec3(-0.03, 0, 0), Vec3(0.03, 0, 0), Vec3(0.03, 0.14, 0), Vec3(0, 0.16, 0), Vec3(-0.03, 0.14, 0)],
                                 normal: Vec3(0, 0, 1), thickness: 0.004, color: Palette.house)
                    }
                }
            }
        }
    }

    /// The gate in the +z side: leaves of timber, then a gatehouse of two
    /// towers with a portcullis, then one flying the House's banner.
    static func gate(_ b: inout MeshBuilder, level: Int, height h: Float, half: Float) {
        let z = wallCorner(1).z
        // The leaves, standing open.
        for side in [Float(1), -1] {
            b.beam(from: Vec3(side * half, 0.0, z), to: Vec3(side * half * 0.4, 0.0, z + 0.07), width: 0.012, depth: 0.001,
                   color: Palette.timberDark)
            b.box(center: Vec3(side * half * 0.72, min(h, 0.2) / 2, z + 0.035), size: Vec3(0.012, min(h, 0.2), 0.075),
                  turn: side * 0.9, color: Palette.timberDark)
        }
        guard level >= 3 else { return }
        let towerHalf: Float = 0.06 + 0.008 * Float(level - 3)
        let towerHeight = h + 0.16 + 0.05 * Float(level - 3)
        for side in [Float(1), -1] {
            let x = side * (half + towerHalf)
            b.place(.translation(Vec3(x, -0.1, z + 0.01))) {
                if level == 3 {
                    $0.box(min: Vec3(-towerHalf, -0.2, -towerHalf), max: Vec3(towerHalf, towerHeight + 0.1, towerHalf), color: Palette.stone)
                } else {
                    $0.lathe([(towerHalf * 1.15, -0.2), (towerHalf * 1.05, towerHeight + 0.1)], sides: 8, color: Palette.stone)
                    $0.with(material: level == 5 ? .house : .plain) {
                        $0.cone(sides: 8, radius: towerHalf * 1.25, from: towerHeight + 0.1, to: towerHeight + 0.1 + towerHalf * 2.4,
                                color: level == 5 ? Palette.house : Palette.slate)
                    }
                }
                $0.window(Vec3(0, towerHeight - 0.02 + 0.1, towerHalf + 0.002), width: 0.018, height: 0.05, facing: 0)
            }
        }
        // The arch over the way, and a portcullis from the fourth level.
        b.box(min: Vec3(-half - 0.01, h - 0.02, z - 0.04), max: Vec3(half + 0.01, h + 0.08, z + 0.05), color: Palette.stonePale)
        if level >= 4 {
            b.with(material: .metal) {
                for x in [Float(-0.05), 0, 0.05] {
                    $0.beam(from: Vec3(x, 0.08, z + 0.03), to: Vec3(x, h - 0.02, z + 0.03), width: 0.008, color: Palette.iron)
                }
                $0.beam(from: Vec3(-half, h * 0.6, z + 0.03), to: Vec3(half, h * 0.6, z + 0.03), width: 0.008, depth: 0.008,
                        color: Palette.iron)
            }
        }
        if level >= 5 {
            let top = h + 0.5
            b.limb(from: Vec3(0, h + 0.08, z), to: Vec3(0, top, z), radius: 0.008, color: Palette.timberDark)
            b.flag(at: Vec3(0, top - 0.01, z), width: 0.22, height: 0.15, turn: .pi / 2)
        }
    }

    // MARK: The scaffold

    /// A frame of poles, ledgers, braces and boards round a work as it
    /// rises: a unit wide, deep and high, x and z from -0.5 to 0.5, for its
    /// piece to stretch to the work.
    static func scaffold() -> Mesh {
        var b = MeshBuilder()
        let pole: Float = 0.022, wood = Palette.timberPale
        let posts = [Vec3(-0.5, 0, -0.5), Vec3(0, 0, -0.52), Vec3(0.5, 0, -0.5), Vec3(0.52, 0, 0), Vec3(0.5, 0, 0.5), Vec3(0, 0, 0.52),
                     Vec3(-0.5, 0, 0.5), Vec3(-0.52, 0, 0)]
        for post in posts {
            b.limb(from: post - Vec3(0, 0.05, 0), to: post + Vec3(0, 1.06, 0), radius: pole, color: wood)
        }
        for level in [Float(0.34), 0.68, 1.0] {
            for index in 0..<posts.count {
                let a = posts[index] + Vec3(0, level, 0), c = posts[(index + 1) % posts.count] + Vec3(0, level, 0)
                b.limb(from: a, to: c, radius: pole * 0.8, color: wood)
            }
        }
        // Braces across each face, and boards to walk on along two sides.
        for (a, c) in [(posts[0], posts[2]), (posts[2], posts[4]), (posts[4], posts[6]), (posts[6], posts[0])] {
            b.limb(from: a, to: c + Vec3(0, 0.68, 0), radius: pole * 0.7, color: Palette.timber)
        }
        for level in [Float(0.34), 0.68] {
            b.box(min: Vec3(-0.5, level, 0.44), max: Vec3(0.5, level + 0.02, 0.56), color: Palette.timberGrey)
            b.box(min: Vec3(0.44, level, -0.5), max: Vec3(0.56, level + 0.02, 0.5), color: Palette.timberGrey)
        }
        b.ladder(from: Vec3(-0.3, 0, 0.62), to: Vec3(-0.3, 0.7, 0.53), width: 0.12, rungs: 4, color: Palette.timber)
        return b.mesh
    }
}
