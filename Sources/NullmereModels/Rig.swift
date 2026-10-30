/// The parts of a model that move, each turning about its own pivot and
/// carried by the part it hangs from: a figure's arm swings at the
/// shoulder and its blade goes with it.
public struct Rig: Equatable, Sendable {
    public struct Bone: Equatable, Sendable {
        public let name: String
        public let parent: Int?
        /// Where it turns, in the model's frame at rest.
        public let pivot: Vec3
    }

    public private(set) var bones: [Bone] = [Bone(name: "root", parent: nil, pivot: .zero)]

    public init() {}

    public var count: Int { bones.count }

    /// Adds a part hanging from `parent`, turning about `pivot`; returns
    /// its index, for the mesh's vertices to name.
    @discardableResult
    public mutating func add(_ name: String, parent: Int = 0, pivot: Vec3) -> UInt16 {
        precondition(parent < bones.count, "a part hangs from one before it")
        bones.append(Bone(name: name, parent: parent, pivot: pivot))
        return UInt16(bones.count - 1)
    }

    public func index(of name: String) -> Int? {
        bones.firstIndex { $0.name == name }
    }

    /// Each part's transform in the model's frame, given how each stands;
    /// parts without a joint given stand at rest.
    public func pose(_ joints: [Joint]) -> [Mat4] {
        var transforms: [Mat4] = []
        transforms.reserveCapacity(bones.count)
        for (index, bone) in bones.enumerated() {
            let joint = index < joints.count ? joints[index] : .rest
            let local = Mat4.translation(bone.pivot + joint.offset) * Mat4.rotation(joint.rotation)
                * Mat4.scale(joint.scale) * Mat4.translation(-bone.pivot)
            transforms.append(bone.parent.map { transforms[$0] * local } ?? local)
        }
        return transforms
    }
}

/// How one part stands at a moment: turned about its pivot (radians about
/// x, then y, then z), shifted, and scaled about the pivot.
public struct Joint: Equatable, Sendable {
    public var rotation: Vec3
    public var offset: Vec3
    public var scale: Vec3

    public init(rotation: Vec3 = .zero, offset: Vec3 = .zero, scale: Vec3 = Vec3(1, 1, 1)) {
        self.rotation = rotation
        self.offset = offset
        self.scale = scale
    }

    public static let rest = Joint()
}

/// What a model is doing, for its parts to show.
public enum Clip: String, CaseIterable, Sendable {
    /// Standing at rest: breathing, shifting weight, a banner stirring.
    case idle
    /// On the march.
    case march
    /// Striking: a thrust, a loosed arrow, a charge.
    case attack
    /// Struck and falling; it ends lying still.
    case death
    /// Working a site: reaping, felling, cutting, raking salt.
    case gather
}

/// A model and how it moves.
public struct Model: Sendable {
    public let name: String
    public let mesh: Mesh
    public let rig: Rig
    /// The joints at a moment of a clip, in seconds; a model that never
    /// moves has none.
    public let motion: (@Sendable (Clip, Float) -> [Joint])?

    public init(name: String, mesh: Mesh, rig: Rig = Rig(), motion: (@Sendable (Clip, Float) -> [Joint])? = nil) {
        self.name = name
        self.mesh = mesh
        self.rig = rig
        self.motion = motion
    }

    /// Each part's transform at a moment of a clip.
    public func pose(_ clip: Clip, at time: Float) -> [Mat4] {
        rig.pose(motion?(clip, time) ?? [])
    }
}
