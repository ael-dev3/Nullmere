import NullmereCore

/// The estate about every work, raised with it level by level: what tells a
/// work of the fifth level from one of the first at a glance across the
/// lake. Each family keeps its own stone, timber and roof, and its own
/// trade's mark on its banners and its lamps:
///
/// 1. a yard fenced at the back, a woodstack and a water butt;
/// 2. a lean-to store against one side, its door and a lit window;
/// 3. a kerb of dressed stone round the whole, two lamp posts at the front;
/// 4. a second house at the other side under a dormered roof, its chimney
///    stack and two banners of the House on their poles;
/// 5. a corner tower with lit windows under a cone, a gilt finial and the
///    House's flag over it, and a gate of two piers and a lintel.
///
/// Each part is laid only while the whole keeps under its budget.
enum Estate {
    /// Families modelled whole at each level, with no shared estate.
    static let bespoke: Set<BuildingKind> = [.walls, .lodge, .beacon, .granary, .quarry, .saltworks, .musterHall, .infirmary, .archive, .moonspire, .forge, .wayhouse, .sawpit]

    /// The most triangles a work may come to with its estate.
    static let ceiling = 2950

    /// A family's look: its stone and timber, its roofs, and its trade's
    /// colour on banners and lamps.
    struct Style {
        var wall: Vec3
        var roof: Vec3
        var trim: Vec3
        var mark: Vec3
        var stone: Bool
    }

    static func style(_ kind: BuildingKind) -> Style {
        switch kind {
        case .granary: return Style(wall: Palette.timberPale, roof: Palette.thatch, trim: Palette.timberDark, mark: Palette.weld, stone: false)
        case .sawpit: return Style(wall: Palette.timber, roof: Palette.slate, trim: Palette.timberDark, mark: Palette.timberPale, stone: false)
        case .quarry: return Style(wall: Palette.stone, roof: Palette.slate, trim: Palette.stoneDark, mark: Palette.stonePale, stone: true)
        case .saltworks: return Style(wall: Palette.stonePale, roof: Palette.slate, trim: Palette.timberDark, mark: Palette.moonsalt, stone: true)
        case .musterHall: return Style(wall: Palette.stoneDark, roof: Palette.slate, trim: Palette.iron, mark: Palette.madder, stone: true)
        case .walls: return Style(wall: Palette.stone, roof: Palette.slate, trim: Palette.stoneDark, mark: Palette.madder, stone: true)
        case .beacon: return Style(wall: Palette.stone, roof: Palette.slate, trim: Palette.iron, mark: Palette.fire, stone: true)
        case .infirmary: return Style(wall: Palette.stoneWhite, roof: Palette.slate, trim: Palette.timberDark, mark: Palette.linen, stone: true)
        case .archive: return Style(wall: Palette.stonePale, roof: Palette.slate, trim: Palette.bronze, mark: Palette.seaWool, stone: true)
        case .moonspire: return Style(wall: Palette.stoneWhite, roof: Palette.slate, trim: Palette.gold, mark: Palette.moonsalt, stone: true)
        case .forge: return Style(wall: Palette.stoneDark, roof: Palette.slate, trim: Palette.iron, mark: Palette.fire, stone: true)
        case .wayhouse: return Style(wall: Palette.timber, roof: Palette.slate, trim: Palette.timberDark, mark: Palette.weld, stone: false)
        case .lodge: return Style(wall: Palette.stonePale, roof: Palette.slate, trim: Palette.stoneDark, mark: Palette.bronze, stone: true)
        }
    }

    /// A work's model with its estate laid round it, as far as its budget
    /// allows: the work's own fine work kept fine, the estate's too.
    static func dress(_ model: Model, _ kind: BuildingKind, level: Int) -> Model {
        // The walls ring the whole hold: their estate is their own towers.
        guard !Estate.bespoke.contains(kind) else { return model }
        var mesh = model.mesh
        let style = Estate.style(kind)
        for stage in 1...max(1, min(level, 5)) {
            for part in parts(stage, kind) {
                var b = MeshBuilder()
                part(&b, style)
                let laid = Estate.layered(mesh, b.mesh)
                guard laid.triangleCount <= ceiling else { continue }
                mesh = laid
            }
        }
        return Model(name: model.name, mesh: mesh, rig: model.rig, motion: model.motion)
    }

    /// One mesh after another, each one's far work before either's fine.
    static func layered(_ a: Mesh, _ b: Mesh) -> Mesh {
        guard !b.isEmpty else { return a }
        var whole = Mesh()
        whole.vertices = a.vertices + b.vertices
        let offset = UInt32(a.vertices.count)
        let aCoarse = a.indices[0..<a.coarseIndexCount], aFine = a.indices[a.coarseIndexCount...]
        let bCoarse = b.indices[0..<b.coarseIndexCount].map { $0 + offset }
        let bFine = b.indices[b.coarseIndexCount...].map { $0 + offset }
        whole.indices = Array(aCoarse) + bCoarse + Array(aFine) + bFine
        if !aFine.isEmpty || !bFine.isEmpty { whole.fineFrom = aCoarse.count + bCoarse.count }
        return whole
    }

    typealias Part = (inout MeshBuilder, Style) -> Void

    /// The parts each level adds for a family, in the order they are laid:
    /// a family's own where it has them, the shared ones otherwise.
    static func parts(_ stage: Int, _ kind: BuildingKind) -> [Part] {
        switch (kind, stage) {
        default: return parts(stage)
        }
    }

    /// The parts each level adds, in the order they are laid.
    static func parts(_ stage: Int) -> [Part] {
        switch stage {
        case 1: return [fence, woodstack]
        case 2: return [leanTo]
        case 3: return [kerb, lamps]
        case 4: return [annex, banners]
        default: return [tower, gate]
        }
    }

    // MARK: The parts

    /// A wattle fence round the back of the yard: posts and two rails.
    static func fence(_ b: inout MeshBuilder, _ style: Style) {
        let posts = 9
        var last: Vec3?
        for index in 0..<posts {
            let angle = Float.pi * 0.62 + Float(index) / Float(posts - 1) * Float.pi * 0.76
            let foot = MeshBuilder.ring(0.31, 0, angle)
            b.limb(from: foot, to: foot + Vec3(0, 0.055, 0), radius: 0.005, color: Palette.timberDark)
            if let last {
                for y in [Float(0.022), 0.045] {
                    b.beam(from: last + Vec3(0, y, 0), to: foot + Vec3(0, y, 0), width: 0.006, depth: 0.004, color: Palette.timber)
                }
            }
            last = foot
        }
    }

    /// A stack of cut wood and a water butt by the fence.
    static func woodstack(_ b: inout MeshBuilder, _ style: Style) {
        b.fine { b in
            for row in 0..<3 {
                for index in 0..<(3 - row) {
                    let x = -0.27 + Float(index) * 0.024 + Float(row) * 0.012
                    b.log(from: Vec3(x, 0.012 + Float(row) * 0.02, -0.1), to: Vec3(x, 0.012 + Float(row) * 0.02, -0.04), radius: 0.01)
                }
            }
            b.place(.translation(Vec3(0.27, 0, -0.06))) {
                $0.lathe([(0.022, 0), (0.026, 0.025), (0.022, 0.05)], sides: 7, color: Palette.timber)
                $0.lathe([(0.0265, 0.012), (0.028, 0.016), (0.0265, 0.02)], sides: 7, color: Palette.iron)
            }
        }
    }

    /// A store under a lean-to roof against the left side.
    static func leanTo(_ b: inout MeshBuilder, _ style: Style) {
        let at = Vec3(-0.24, 0, 0.02)
        b.box(min: at + Vec3(-0.05, -0.03, -0.06), max: at + Vec3(0.04, 0.075, 0.06), color: style.wall)
        b.sheet([at + Vec3(-0.065, 0.06, -0.075), at + Vec3(-0.065, 0.06, 0.075), at + Vec3(0.05, 0.1, 0.075), at + Vec3(0.05, 0.1, -0.075)],
                normal: Vec3(-0.35, 1, 0), thickness: 0.008, color: style.roof)
        b.door(at + Vec3(-0.051, 0.03, 0.02), width: 0.032, height: 0.055, facing: -.pi / 2)
        b.window(at + Vec3(-0.051, 0.05, -0.03), width: 0.018, height: 0.02, facing: -.pi / 2)
        b.fine { b in
            for z in [Float(-0.06), 0.06] {
                b.box(center: at + Vec3(-0.05, 0.02, z), size: Vec3(0.01, 0.1, 0.01), color: style.trim)
            }
            b.beam(from: at + Vec3(-0.066, 0.064, -0.077), to: at + Vec3(-0.066, 0.064, 0.077), width: 0.008, color: style.trim)
        }
    }

    /// A kerb of dressed stone round the whole yard.
    static func kerb(_ b: inout MeshBuilder, _ style: Style) {
        b.lathe([(0.3, 0.0), (0.325, 0.004), (0.325, 0.022), (0.31, 0.026), (0.3, 0.026)], sides: 16, color: style.stone ? style.wall : Palette.stone)
    }

    /// Two lamp posts at the front, their lanterns lit.
    static func lamps(_ b: inout MeshBuilder, _ style: Style) {
        for x in [Float(-0.17), 0.17] {
            let foot = Vec3(x, 0.02, 0.2)
            b.limb(from: foot, to: foot + Vec3(0, 0.15, 0), radius: 0.006, topRadius: 0.004, color: style.trim)
            b.beam(from: foot + Vec3(0, 0.15, 0), to: foot + Vec3(0, 0.15, 0.025), width: 0.005, color: style.trim)
            b.with(material: .glow) {
                $0.place(.translation(foot + Vec3(0, 0.13, 0.03))) {
                    $0.lathe([(0.0, -0.014), (0.012, -0.008), (0.012, 0.01), (0.0, 0.016)], sides: 6, color: Palette.candle.mix(style.mark, 0.2))
                }
            }
            b.fine { b in
                b.place(.translation(foot + Vec3(0, 0.148, 0.03))) {
                    $0.cone(sides: 6, radius: 0.016, from: 0, to: 0.016, color: style.trim)
                }
            }
        }
    }

    /// A second house at the right under a dormered roof, its chimney stack.
    static func annex(_ b: inout MeshBuilder, _ style: Style) {
        let at = Vec3(0.23, 0, 0.0)
        b.hall(at: at, width: 0.1, depth: 0.12, height: 0.085, wall: style.wall, roof: style.roof, pitch: 0.6, turn: .pi / 2,
               footing: style.stone ? style.trim : nil)
        b.door(at + Vec3(0.061, 0.035, 0.0), width: 0.03, height: 0.06, facing: .pi / 2)
        for z in [Float(-0.03), 0.03] {
            b.window(at + Vec3(0.061, 0.065, z), width: 0.016, height: 0.022, facing: .pi / 2)
        }
        // The dormer, its window lit.
        b.box(min: at + Vec3(0.02, 0.1, -0.02), max: at + Vec3(0.05, 0.13, 0.02), color: style.wall)
        b.place(.translation(at + Vec3(0.035, 0.13, 0))) {
            $0.gableRoof(width: 0.03, depth: 0.05, base: 0, height: 0.02, color: style.roof, overhang: 0.006)
        }
        b.window(at + Vec3(0.051, 0.115, 0), width: 0.014, height: 0.016, facing: .pi / 2)
        // The chimney stack, its cap.
        b.box(min: at + Vec3(-0.035, 0.08, -0.04), max: at + Vec3(-0.01, 0.17, -0.015), color: Palette.stoneDark)
        b.fine { b in
            b.box(min: at + Vec3(-0.039, 0.17, -0.044), max: at + Vec3(-0.006, 0.18, -0.011), color: Palette.stone)
        }
    }

    /// Two banners of the House on their poles, either side of the front.
    static func banners(_ b: inout MeshBuilder, _ style: Style) {
        for x in [Float(-0.27), 0.27] {
            let foot = Vec3(x, 0.02, 0.1)
            b.limb(from: foot, to: foot + Vec3(0, 0.24, 0), radius: 0.005, color: style.trim)
            b.flag(at: foot + Vec3(0, 0.235, 0), width: 0.05, height: 0.1, turn: x > 0 ? .pi : 0, tail: true)
            b.fine { b in
                b.sphere(center: foot + Vec3(0, 0.248, 0), radius: 0.008, rings: 2, sides: 5, color: style.mark)
                b.beam(from: foot + Vec3(0, 0.23, 0), to: foot + Vec3(x > 0 ? -0.05 : 0.05, 0.23, 0), width: 0.004, color: style.trim)
            }
        }
    }

    /// A corner tower at the back right, its windows lit, under a cone with
    /// a gilt finial and the House's flag.
    static func tower(_ b: inout MeshBuilder, _ style: Style) {
        let at = Vec3(0.15, 0, -0.17)
        let height: Float = 0.3
        b.roundHouse(at: at, radius: 0.045, height: height, wall: style.stone ? style.wall : Palette.stone, roof: style.roof,
                     roofHeight: 0.1, sides: 8)
        for (index, y) in [Float(0.12), 0.22].enumerated() {
            let angle = Float(index) * 2.1 + 0.6
            b.window(at + MeshBuilder.ring(0.045, y, angle), width: 0.014, height: 0.024, facing: angle + .pi / 2)
        }
        b.place(.translation(at)) {
            $0.merlonRing(radius: 0.05, base: height - 0.01, count: 6, size: Vec3(0.016, 0.02, 0.012), color: style.wall)
        }
        b.limb(from: at + Vec3(0, height + 0.09, 0), to: at + Vec3(0, height + 0.2, 0), radius: 0.004, color: style.trim)
        b.flag(at: at + Vec3(0, height + 0.195, 0), width: 0.06, height: 0.035, turn: .pi * 0.8)
        b.fine { b in
            b.sphere(center: at + Vec3(0, height + 0.105, 0), radius: 0.01, rings: 3, sides: 6, color: Palette.gold)
        }
    }

    /// A gate at the front: two piers, a lintel and its capstones.
    static func gate(_ b: inout MeshBuilder, _ style: Style) {
        let wall = style.stone ? style.wall : Palette.stone
        for x in [Float(-0.075), 0.075] {
            b.box(min: Vec3(x - 0.02, 0, 0.25), max: Vec3(x + 0.02, 0.15, 0.29), color: wall)
            b.box(min: Vec3(x - 0.026, 0.15, 0.244), max: Vec3(x + 0.026, 0.162, 0.296), color: style.trim)
        }
        b.box(min: Vec3(-0.1, 0.162, 0.253), max: Vec3(0.1, 0.19, 0.287), color: wall)
        b.fine { b in
            b.box(min: Vec3(-0.03, 0.19, 0.258), max: Vec3(0.03, 0.215, 0.282), color: style.mark)
            for x in [Float(-0.075), 0.075] {
                b.sphere(center: Vec3(x, 0.175, 0.27), radius: 0.012, rings: 2, sides: 6, color: style.trim)
            }
        }
    }
}
