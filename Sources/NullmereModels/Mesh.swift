/// How a surface takes the light, read by the world's shaders.
public enum Material: UInt8, CaseIterable, Sendable {
    /// Lit by the moon and the sky, nothing more.
    case plain = 0
    /// Its colour is the owning House's: banners, shields, cloaks, roofs.
    /// Its vertices' colour is a grey the House's colour tints; its banners
    /// and cloaks move in the wind by their sway.
    case house = 1
    /// Gives light of its own colour: windows, torches, lanterns, braziers.
    /// It flickers.
    case glow = 2
    /// Leaves and grass: it sways in the night wind, more at its tips.
    case foliage = 3
    /// Banners and pennants: they ripple. Cloth in no House's colours: the
    /// far country's shrouds and rags.
    case cloth = 4
    /// Moonsalt: pale, faintly lit from within, glinting.
    case crystal = 5
    /// Blades, helms and mail: they catch the moon sharply.
    case metal = 6
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

    public init(position: Vec3, normal: Vec3, color: Vec3, part: UInt16 = 0, material: Material = .plain, sway: Float = 0) {
        self.position = position
        self.normal = normal
        self.color = color
        self.part = part
        self.material = material
        self.sway = sway
    }
}

/// A vertex as the GPU reads it: 24 bytes, matching `ModelVertex` in the
/// world's shaders (`packed_float3 position; char4 normalMaterial;
/// uchar4 colorSway; ushort part; ushort spare;`).
public struct PackedVertex: Equatable, Sendable {
    public var x: Float
    public var y: Float
    public var z: Float
    /// The normal as three signed bytes, then the material.
    public var normalMaterial: UInt32
    /// The colour as three bytes of sRGB, then the sway.
    public var colorSway: UInt32
    public var part: UInt16
    public var spare: UInt16

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
        spare = 0
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
