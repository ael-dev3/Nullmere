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
    /// Struck and still standing: a blow taken on the shield or the body,
    /// a stagger back and a recovery to guard, a beat at a time, as a rank
    /// at the front of a battle takes it again and again.
    case hit
    /// Working a site: reaping, felling, cutting, raking salt.
    case gather
}

/// A model and how it moves: made in Blender, by its skeleton's actions;
/// one that never moves (a mesh made for a preview) stands as it is.
public struct Model: Sendable {
    public let name: String
    public let mesh: Mesh
    public let rig: Rig
    /// For a model made in Blender: the skeleton its skin is weighted to,
    /// and its actions, which move it.
    public let skeleton: Skeleton?

    /// A model that never moves.
    public init(name: String, mesh: Mesh) {
        self.name = name
        self.mesh = mesh
        rig = Rig()
        skeleton = nil
    }

    /// A model made in Blender, moved by its skeleton's actions.
    public init(name: String, mesh: Mesh, rig: Rig, skeleton: Skeleton) {
        self.name = name
        self.mesh = mesh
        self.rig = rig
        self.skeleton = skeleton
    }

    /// Each part's transform at a moment of a clip: a model that never
    /// moves stands at rest.
    public func pose(_ clip: Clip, at time: Float) -> [Mat4] {
        skeleton?.pose(clip, at: time) ?? [Mat4](repeating: .identity, count: rig.count)
    }
}
