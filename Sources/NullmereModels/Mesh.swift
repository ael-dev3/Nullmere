/// How a surface takes the light, read by the world's shaders.
public enum Material: UInt8, CaseIterable, Sendable {
    /// Lit by the moon and the sky, nothing more.
    case plain = 0
    /// Its colour is the owning House's: banners, shields, cloaks, roofs.
    case house = 1
    /// Gives light of its own colour: windows, torches, lanterns, braziers.
    /// It flickers.
    case glow = 2
    /// Leaves and grass: it sways in the night wind, more at its tips.
    case foliage = 3
    /// Banners and pennants: they ripple. Their colour is the owning
    /// House's, as `house` is.
    case cloth = 4
    /// Moonsalt: pale, faintly lit from within, glinting.
    case crystal = 5
    /// Blades, helms and mail: they catch the moon sharply.
    case metal = 6
}

/// The grain of a surface, which the world's shaders draw on it: courses
/// of stone, planks of timber, the straws of a thatch, rows of slates,
/// trodden earth. Smooth surfaces show their colour alone.
public enum Surface: UInt8, CaseIterable, Sendable {
    case smooth = 0
    case stone = 1
    case timber = 2
    case thatch = 3
    case slate = 4
    case earth = 5

    /// The grain of the palette's colours: each colour a model is built of
    /// is stone, timber, thatch, slate or earth, or smooth; a colour mixed
    /// between two takes the grain of the nearer.
    private static let grains: [(Vec3, Surface)] = [
        (Palette.stone, .stone), (Palette.stoneDark, .stone), (Palette.stonePale, .stone), (Palette.stoneWhite, .stone),
        (Palette.rock, .stone),
        (Palette.timber, .timber), (Palette.timberDark, .timber), (Palette.timberPale, .timber), (Palette.timberGrey, .timber),
        (Palette.bark, .timber), (Palette.deadWood, .timber),
        (Palette.thatch, .thatch), (Palette.straw, .thatch), (Palette.reed, .thatch),
        (Palette.slate, .slate),
        (Palette.earth, .earth), (Palette.yard, .earth), (Palette.loam, .earth),
        // Smooth, though near some of these: metal, cloth, hide, skin.
        (Palette.iron, .smooth), (Palette.steel, .smooth), (Palette.mail, .smooth), (Palette.bronze, .smooth),
        (Palette.wool, .smooth), (Palette.woolDark, .smooth), (Palette.linen, .smooth), (Palette.leather, .smooth),
        (Palette.leatherDark, .smooth), (Palette.padded, .smooth), (Palette.fur, .smooth), (Palette.canvas, .smooth),
        (Palette.skin, .smooth), (Palette.hair, .smooth), (Palette.ash, .smooth), (Palette.bone, .smooth),
        (Palette.grain, .smooth), (Palette.grass, .smooth), (Palette.moss, .smooth), (Palette.house, .smooth),
        (Palette.houseDark, .smooth), (Palette.shroud, .smooth), (Palette.smoke, .smooth), (Palette.saltCrust, .smooth),
        (Palette.moonsalt, .smooth),
    ]

    /// The grain of a colour: the nearest of the palette's, if it is near;
    /// or, mixed between two colours of one grain, that grain.
    public static func of(_ color: Vec3) -> Surface {
        var best: (distance: Float, surface: Surface)?
        for (known, surface) in grains {
            let distance = (known - color).length
            if distance < (best?.distance ?? 0.035) { best = (distance, surface) }
        }
        if let best { return best.surface }
        for (index, (a, surface)) in grains.enumerated() where surface != .smooth {
            for (b, other) in grains[(index + 1)...] where other == surface {
                let ab = b - a
                let t = min(max((color - a).dot(ab) / max(ab.dot(ab), 1e-6), 0), 1)
                if (a + ab * t - color).length < 0.025 { return surface }
            }
        }
        return .smooth
    }
}

/// One corner of a triangle as it is built.
public struct MeshVertex: Equatable, Sendable {
    public var position: Vec3
    public var normal: Vec3
    /// Its colour as it would be seen in plain white light, in sRGB.
    public var color: Vec3
    /// Which part of the model's rig it moves with.
    public var part: UInt16
    public var material: Material
    /// How much it moves in the wind, 0 to 1: a branch's tip, a banner's end.
    public var sway: Float
    /// The grain drawn on it.
    public var surface: Surface

    public init(position: Vec3, normal: Vec3, color: Vec3, part: UInt16 = 0, material: Material = .plain, sway: Float = 0,
                surface: Surface = .smooth) {
        self.position = position
        self.normal = normal
        self.color = color
        self.part = part
        self.material = material
        self.sway = sway
        self.surface = surface
    }
}

/// A vertex as the GPU reads it: 24 bytes, matching `ModelVertex` in the
/// world's shaders (`packed_float3 position; char4 normalMaterial;
/// uchar4 colorSway; ushort part; ushort surface;`).
public struct PackedVertex: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var z: Float
    /// The normal as three signed bytes, then the material.
    public var normalMaterial: UInt32
    /// The colour as three bytes of sRGB, then the sway.
    public var colorSway: UInt32
    public var part: UInt16
    /// The grain drawn on it, as `Surface`'s raw value.
    public var surfaceCode: UInt16

    public init(_ vertex: MeshVertex) {
        x = vertex.position.x
        y = vertex.position.y
        z = vertex.position.z
        let n = vertex.normal.normalized
        func signedByte(_ value: Float) -> UInt32 {
            UInt32(UInt8(bitPattern: Int8(clamping: Int((min(max(value, -1), 1) * 127).rounded()))))
        }
        func byte(_ value: Float) -> UInt32 {
            UInt32(UInt8(clamping: Int((min(max(value, 0), 1) * 255).rounded())))
        }
        normalMaterial = signedByte(n.x) | signedByte(n.y) << 8 | signedByte(n.z) << 16 | UInt32(vertex.material.rawValue) << 24
        colorSway = byte(vertex.color.x) | byte(vertex.color.y) << 8 | byte(vertex.color.z) << 16 | byte(vertex.sway) << 24
        part = vertex.part
        surfaceCode = UInt16(vertex.surface.rawValue)
    }

    public var position: Vec3 { Vec3(x, y, z) }

    public var normal: Vec3 {
        func value(_ shift: UInt32) -> Float { Float(Int8(bitPattern: UInt8(truncatingIfNeeded: normalMaterial >> shift))) / 127 }
        return Vec3(value(0), value(8), value(16))
    }

    public var material: Material? { Material(rawValue: UInt8(truncatingIfNeeded: normalMaterial >> 24)) }

    public var color: Vec3 {
        func value(_ shift: UInt32) -> Float { Float(UInt8(truncatingIfNeeded: colorSway >> shift)) / 255 }
        return Vec3(value(0), value(8), value(16))
    }

    public var sway: Float { Float(UInt8(truncatingIfNeeded: colorSway >> 24)) / 255 }

    public var surface: Surface? { Surface(rawValue: UInt8(truncatingIfNeeded: surfaceCode)) }
}

/// Triangles: three indices into the vertices for each, wound
/// counter-clockwise seen from outside.
public struct Mesh: Equatable, Sendable {
    public var vertices: [MeshVertex]
    public var indices: [UInt32]

    public init(vertices: [MeshVertex] = [], indices: [UInt32] = []) {
        self.vertices = vertices
        self.indices = indices
    }

    public var triangleCount: Int { indices.count / 3 }
    public var isEmpty: Bool { indices.isEmpty }

    /// The smallest box holding every vertex.
    public var bounds: (min: Vec3, max: Vec3) {
        guard let first = vertices.first?.position else { return (.zero, .zero) }
        var low = first, high = first
        for vertex in vertices {
            low = pointwiseMin(low, vertex.position)
            high = pointwiseMax(high, vertex.position)
        }
        return (low, high)
    }

    /// Adds another mesh's triangles, moved by `transform`.
    public mutating func append(_ other: Mesh, transform: Mat4 = .identity) {
        let base = UInt32(vertices.count)
        let normals = transform.normalMatrix
        vertices.reserveCapacity(vertices.count + other.vertices.count)
        for var vertex in other.vertices {
            vertex.position = transform.transformPoint(vertex.position)
            vertex.normal = normals.transformDirection(vertex.normal).normalized
            vertices.append(vertex)
        }
        indices.append(contentsOf: other.indices.map { $0 + base })
    }

    /// The vertices as the GPU reads them.
    public var packed: [PackedVertex] { vertices.map(PackedVertex.init) }

    /// Each triangle's three corners.
    public var triangles: [(MeshVertex, MeshVertex, MeshVertex)] {
        stride(from: 0, to: indices.count - 2, by: 3).map {
            (vertices[Int(indices[$0])], vertices[Int(indices[$0 + 1])], vertices[Int(indices[$0 + 2])])
        }
    }

    /// Every part the triangles move with.
    public var parts: Set<UInt16> { Set(vertices.map(\.part)) }
}
