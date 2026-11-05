import Foundation

/// A model made in Blender and exported as glTF binary (a .glb): its mesh,
/// the skeleton its skin is weighted to, and its actions, one for each clip
/// and named by it. Read once, it draws and moves as the models built in
/// code do: each vertex with the two bones that weigh on it most, each pose
/// the skeleton's joints at a moment of an action.
///
/// Its materials are named for what they are: the first word one of the
/// world's materials (plain, house, glow, foliage, cloth, crystal, metal),
/// the second, if it is one, the grain drawn on it (stone, timber, thatch,
/// slate, earth); "house_timber_shaft" is timber in the House's colour.
///
/// Its pieces are named for when they are drawn: "helm@3-5" only for the
/// third tier to the fifth, "helm@4" for the fourth alone, "helm@5,saltborn"
/// for the fifth and for the variant named saltborn; "buckle!fine" only
/// near, as the models built in code have their fine work. Cloth and leaves
/// carry how far they move in the wind as an attribute, _SWAY. Its actions
/// are tagged the same way: "attack@warden" is the warden's strike, played
/// by that variant in place of "attack".
public enum Asset {
    public enum Failure: Error, Equatable, CustomStringConvertible {
        /// Not glTF binary at all.
        case notGLB
        /// glTF binary, but not as this reader takes it.
        case malformed(String)

        public var description: String {
            switch self {
            case .notGLB: return "Not a glTF binary file."
            case .malformed(let what): return "A glTF binary file this reader can't take: \(what)."
            }
        }
    }

    /// A model from a .glb's bytes, scaled about its origin by `scale` and
    /// then raised by `lift` (a rider made seated at a man's height, his
    /// horse beneath him, lifted till its hooves stand on the ground): its
    /// rig's bones in `order` (by name) after its root, any others after
    /// them; the pieces of `tier` alone, if it is given.
    /// The pieces of a variant (by its name) in place of a tier's, if one is
    /// given: untagged pieces and those tagged for it. `colours` (sRGB), by
    /// a material's name, in place of the colour it was made in: a horse's
    /// coat as each tier's is.
    public static func model(name: String, glb: Data, scale: Float = 1, lift: Float = 0, order: [String] = [], tier: Int? = nil,
                             variant: String? = nil, colours: [String: Vec3] = [:]) throws -> Model {
        let file = try GLB(glb)
        return try Reader(file: file, scale: scale, lift: lift, order: order, tier: tier, variant: variant, colours: colours)
            .model(name: name)
    }

    /// What a piece's name in the file says of it: its name, the tiers and
    /// variants it is drawn for (none: always), and whether only near.
    struct Tags: Equatable {
        var name: String
        var tiers: [ClosedRange<Int>] = []
        var variants: [String] = []
        var fine = false

        var always: Bool { tiers.isEmpty && variants.isEmpty }

        /// Whether it is drawn for a tier, or for a variant in place of one.
        func drawn(tier: Int?, variant: String?) -> Bool {
            if always { return true }
            if let variant { return variants.contains(variant) }
            guard let tier else { return true }
            return tiers.contains { $0.contains(tier) }
        }
    }

    static func tags(_ name: String) -> Tags {
        var base = name
        var tags = Tags(name: name)
        if base.hasSuffix("!fine") {
            tags.fine = true
            base.removeLast(5)
        }
        if let at = base.lastIndex(of: "@") {
            for item in base[base.index(after: at)...].split(separator: ",") {
                let bounds = item.split(separator: "-").compactMap { Int($0) }
                if bounds.count == 1, !item.contains("-") {
                    tags.tiers.append(bounds[0]...bounds[0])
                } else if bounds.count == 2, bounds[0] <= bounds[1] {
                    tags.tiers.append(bounds[0]...bounds[1])
                } else if !item.isEmpty, item.allSatisfy({ $0.isLetter }) {
                    tags.variants.append(String(item))
                }
            }
            base = String(base[..<at])
        }
        tags.name = base
        return tags
    }

    /// Bytes written in Swift as base64, as the models made in Blender are
    /// kept in the package (Sources/NullmereModels/Art).
    public static func bytes(base64: String) throws -> Data {
        guard let data = Data(base64Encoded: base64, options: .ignoreUnknownCharacters) else { throw Failure.malformed("its base64") }
        return data
    }
}

/// How one joint stands: moved, turned (a unit quaternion, x y z w) and
/// scaled, from its parent.
public struct JointPose: Equatable, Sendable {
    public var translation: Vec3
    public var rotation: Vec4
    public var scale: Vec3

    public static let rest = JointPose(translation: .zero, rotation: Vec4(0, 0, 0, 1), scale: Vec3(1, 1, 1))

    public var matrix: Mat4 {
        .translation(translation) * Skeleton.rotation(rotation) * .scale(scale)
    }

    /// A share of the way to another: moved and scaled straight, turned on
    /// the sphere.
    public func mixed(_ other: JointPose, _ t: Float) -> JointPose {
        // Exact at both ends: all of one is that one.
        if t <= 0 { return self }
        if t >= 1 { return other }
        return JointPose(translation: translation + (other.translation - translation) * t,
                  rotation: Skeleton.slerp(rotation, other.rotation, t),
                  scale: scale + (other.scale - scale) * t)
    }
}

/// The skeleton a model made in Blender is skinned to, and its actions:
/// every node of its scene, the joints among them in the order of the
/// model's rig, and how each action moves them.
public struct Skeleton: Sendable {
    struct Node: Sendable {
        let name: String
        let parent: Int?
        /// As it stands at rest; nil for a node given as a fixed matrix.
        let rest: JointPose?
        let matrix: Mat4
    }

    enum Path: Sendable { case translation, rotation, scale }

    struct Channel: Sendable {
        let node: Int
        let path: Path
        let times: [Float]
        /// Three or four values a key, or nine or twelve for a cubic
        /// spline's in-tangent, value and out-tangent (whose values alone
        /// are taken, straight between keys).
        let values: [Float]
        let width: Int
        let step: Bool
        let cubic: Bool
    }

    struct Action: Sendable {
        let start: Float
        let duration: Float
        let channels: [Channel]
    }

    let nodes: [Node]
    /// The nodes that are joints, in the order of the rig's bones after its
    /// root.
    let joints: [Int]
    let inverseBinds: [Mat4]
    let actions: [Clip: Action]
    /// Where the model stands from where it was made: scaled about its
    /// origin and lifted; and back.
    let up: Mat4
    let down: Mat4

    /// The clips it has actions for.
    public var clips: Set<Clip> { Set(actions.keys) }

    /// How long its action for a clip runs, in seconds of the action as made.
    public func duration(of clip: Clip) -> Float? { actions[clip]?.duration }

    /// Every node as it stands at a moment of a clip: a share of the way
    /// through the clip's period is the same share through its action, so
    /// a clip plays in its own time whatever the action's length.
    public func locals(_ clip: Clip, at time: Float) -> [JointPose] {
        var poses = nodes.map { $0.rest ?? .rest }
        guard let action = actions[clip] ?? actions[.idle] else { return poses }
        let played = actions[clip] == nil ? Clip.idle : clip
        let at = action.start + played.progress(at: time) * action.duration
        for channel in action.channels {
            let value = Skeleton.sample(channel, at: at)
            switch channel.path {
            case .translation: poses[channel.node].translation = Vec3(value.x, value.y, value.z)
            case .rotation: poses[channel.node].rotation = Skeleton.normalized(value)
            case .scale: poses[channel.node].scale = Vec3(value.x, value.y, value.z)
            }
        }
        return poses
    }

    /// Each bone's transform, the root's first, from every node's pose.
    public func palette(_ locals: [JointPose]) -> [Mat4] {
        var globals = [Mat4?](repeating: nil, count: nodes.count)
        func global(_ index: Int) -> Mat4 {
            if let known = globals[index] { return known }
            let node = nodes[index]
            let local = node.rest == nil ? node.matrix : locals[index].matrix
            let value = node.parent.map { global($0) * local } ?? local
            globals[index] = value
            return value
        }
        return [.identity] + joints.indices.map { j in
            up * global(joints[j]) * inverseBinds[j] * down
        }
    }

    public func pose(_ clip: Clip, at time: Float) -> [Mat4] {
        palette(locals(clip, at: time))
    }

    /// Easing out of another clip into this one: `weight` is the share the
    /// other clip, at its own moment, still holds; nothing of it, this clip
    /// exactly.
    public func pose(_ clip: Clip, at time: Float, from other: Clip, at otherTime: Float, weight: Float) -> [Mat4] {
        let into = locals(clip, at: time), out = locals(other, at: otherTime)
        let w = min(max(weight, 0), 1)
        return palette(zip(into, out).map { $0.mixed($1, w) })
    }

    // MARK: Sampling

    static func sample(_ channel: Channel, at time: Float) -> Vec4 {
        let keys = channel.times
        func value(_ key: Int) -> Vec4 {
            let width = channel.width
            let stride = channel.cubic ? width * 3 : width
            let base = key * stride + (channel.cubic ? width : 0)
            return Vec4(channel.values[base], channel.values[base + 1], channel.values[base + 2],
                        width > 3 ? channel.values[base + 3] : 0)
        }
        guard let first = keys.first, let last = keys.last else { return Vec4(0, 0, 0, 1) }
        if time <= first || keys.count == 1 { return value(0) }
        if time >= last { return value(keys.count - 1) }
        var low = 0, high = keys.count - 1
        while high - low > 1 {
            let middle = (low + high) / 2
            if keys[middle] <= time { low = middle } else { high = middle }
        }
        if channel.step { return value(low) }
        let span = keys[high] - keys[low]
        let t = span > 0 ? (time - keys[low]) / span : 0
        let a = value(low), b = value(high)
        if channel.path == .rotation { return slerp(a, b, t) }
        return a + (b - a) * t
    }

    static func normalized(_ q: Vec4) -> Vec4 {
        let length = (q * q).sum().squareRoot()
        return length > 0 ? q / length : Vec4(0, 0, 0, 1)
    }

    static func slerp(_ a: Vec4, _ b0: Vec4, _ t: Float) -> Vec4 {
        var b = b0
        var d = (a * b).sum()
        if d < 0 {
            b = -b
            d = -d
        }
        if d > 0.9995 { return normalized(a + (b - a) * t) }
        let theta = acos(min(d, 1))
        let s = sin(theta)
        return normalized((a * sin((1 - t) * theta) + b * sin(t * theta)) / s)
    }

    /// A unit quaternion's rotation, column by column.
    static func rotation(_ q: Vec4) -> Mat4 {
        let x = q.x, y = q.y, z = q.z, w = q.w
        return Mat4(Vec4(1 - 2 * (y * y + z * z), 2 * (x * y + w * z), 2 * (x * z - w * y), 0),
                    Vec4(2 * (x * y - w * z), 1 - 2 * (x * x + z * z), 2 * (y * z + w * x), 0),
                    Vec4(2 * (x * z + w * y), 2 * (y * z - w * x), 1 - 2 * (x * x + y * y), 0),
                    Vec4(0, 0, 0, 1))
    }
}

// MARK: Reading

/// A .glb's two chunks: its JSON and its binary buffer.
private struct GLB {
    let json: GLTF
    let bin: Data

    init(_ data: Data) throws {
        func word(_ at: Int) -> UInt32 {
            data.withUnsafeBytes { $0.loadUnaligned(fromByteOffset: at, as: UInt32.self) }.littleEndian
        }
        guard data.count >= 20, word(0) == 0x4654_6C67, word(4) == 2 else { throw Asset.Failure.notGLB }
        var offset = 12
        var json: Data?, bin = Data()
        while offset + 8 <= data.count {
            let length = Int(word(offset)), kind = word(offset + 4)
            let start = offset + 8
            guard start + length <= data.count else { throw Asset.Failure.malformed("a chunk past its end") }
            let chunk = data.subdata(in: start..<(start + length))
            if kind == 0x4E4F_534A { json = chunk } else if kind == 0x004E_4942 { bin = chunk }
            offset = start + length
        }
        guard let json else { throw Asset.Failure.malformed("no JSON chunk") }
        do {
            self.json = try JSONDecoder().decode(GLTF.self, from: json)
        } catch {
            throw Asset.Failure.malformed("its JSON (\(error))")
        }
        self.bin = bin
    }
}

/// The parts of glTF a model of the world is made of.
private struct GLTF: Decodable {
    struct Accessor: Decodable {
        let bufferView: Int?
        let byteOffset: Int?
        let componentType: Int
        let count: Int
        let type: String
        let normalized: Bool?
    }

    struct BufferView: Decodable {
        let byteOffset: Int?
        let byteLength: Int
        let byteStride: Int?
    }

    struct Primitive: Decodable {
        let attributes: [String: Int]
        let indices: Int?
        let material: Int?
        let mode: Int?
    }

    struct Mesh: Decodable {
        let primitives: [Primitive]
    }

    struct Material: Decodable {
        struct PBR: Decodable {
            let baseColorFactor: [Float]?
        }

        let name: String?
        let pbrMetallicRoughness: PBR?
    }

    struct Node: Decodable {
        let name: String?
        let children: [Int]?
        let mesh: Int?
        let skin: Int?
        let translation: [Float]?
        let rotation: [Float]?
        let scale: [Float]?
        let matrix: [Float]?
    }

    struct Skin: Decodable {
        let joints: [Int]
        let inverseBindMatrices: Int?
    }

    struct Animation: Decodable {
        struct Channel: Decodable {
            struct Target: Decodable {
                let node: Int?
                let path: String
            }

            let sampler: Int
            let target: Target
        }

        struct Sampler: Decodable {
            let input: Int
            let output: Int
            let interpolation: String?
        }

        let name: String?
        let channels: [Channel]
        let samplers: [Sampler]
    }

    struct Scene: Decodable {
        let nodes: [Int]?
    }

    let accessors: [Accessor]?
    let bufferViews: [BufferView]?
    let meshes: [Mesh]?
    let materials: [Material]?
    let nodes: [Node]?
    let skins: [Skin]?
    let animations: [Animation]?
    let scenes: [Scene]?
    let scene: Int?
}

private struct Reader {
    let file: GLB
    let scale: Float
    let lift: Float
    let order: [String]
    let tier: Int?
    let variant: String?
    let colours: [String: Vec3]
    var json: GLTF { file.json }
    /// Where the model stands from where it was made, and back.
    var up: Mat4 { .translation(Vec3(0, lift, 0)) * .scale(scale) }
    var down: Mat4 { .scale(1 / scale) * .translation(Vec3(0, -lift, 0)) }

    // MARK: Accessors

    func accessor(_ index: Int) throws -> GLTF.Accessor {
        guard let accessors = json.accessors, accessors.indices.contains(index) else { throw Asset.Failure.malformed("accessor \(index)") }
        return accessors[index]
    }

    static func width(_ type: String) -> Int? {
        ["SCALAR": 1, "VEC2": 2, "VEC3": 3, "VEC4": 4, "MAT4": 16][type]
    }

    /// An accessor's values as floats, normalised integers taken to 0…1
    /// (or −1…1), with how many make one element.
    func floats(_ index: Int) throws -> (values: [Float], width: Int) {
        let accessor = try accessor(index)
        guard let width = Reader.width(accessor.type) else { throw Asset.Failure.malformed("accessor type \(accessor.type)") }
        let normalized = accessor.normalized ?? false
        let raw = try read(accessor, width: width)
        let values: [Float] = raw.map { value in
            guard normalized else { return Float(value) }
            switch accessor.componentType {
            case 5121: return Float(value) / 255
            case 5123: return Float(value) / 65535
            case 5120: return max(Float(value) / 127, -1)
            case 5122: return max(Float(value) / 32767, -1)
            default: return Float(value)
            }
        }
        return (values, width)
    }

    /// An accessor's values as integers.
    func integers(_ index: Int) throws -> (values: [Int], width: Int) {
        let accessor = try accessor(index)
        guard let width = Reader.width(accessor.type) else { throw Asset.Failure.malformed("accessor type \(accessor.type)") }
        return (try read(accessor, width: width).map { Int($0) }, width)
    }

    private func read(_ accessor: GLTF.Accessor, width: Int) throws -> [Double] {
        guard let viewIndex = accessor.bufferView else { return Array(repeating: 0, count: accessor.count * width) }
        guard let views = json.bufferViews, views.indices.contains(viewIndex) else { throw Asset.Failure.malformed("buffer view \(viewIndex)") }
        let view = views[viewIndex]
        let size: Int
        switch accessor.componentType {
        case 5120, 5121: size = 1
        case 5122, 5123: size = 2
        case 5125, 5126: size = 4
        default: throw Asset.Failure.malformed("component type \(accessor.componentType)")
        }
        let stride = view.byteStride ?? size * width
        let base = (view.byteOffset ?? 0) + (accessor.byteOffset ?? 0)
        let end = base + stride * max(accessor.count - 1, 0) + size * width
        guard accessor.count == 0 || end <= file.bin.count, end <= (view.byteOffset ?? 0) + view.byteLength || accessor.count == 0 else {
            throw Asset.Failure.malformed("an accessor past its buffer")
        }
        var values: [Double] = []
        values.reserveCapacity(accessor.count * width)
        file.bin.withUnsafeBytes { bytes in
            for element in 0..<accessor.count {
                for component in 0..<width {
                    let at = base + element * stride + component * size
                    switch accessor.componentType {
                    case 5120: values.append(Double(bytes.loadUnaligned(fromByteOffset: at, as: Int8.self)))
                    case 5121: values.append(Double(bytes.loadUnaligned(fromByteOffset: at, as: UInt8.self)))
                    case 5122: values.append(Double(Int16(littleEndian: bytes.loadUnaligned(fromByteOffset: at, as: Int16.self))))
                    case 5123: values.append(Double(UInt16(littleEndian: bytes.loadUnaligned(fromByteOffset: at, as: UInt16.self))))
                    case 5125: values.append(Double(UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: at, as: UInt32.self))))
                    default:
                        let bits = UInt32(littleEndian: bytes.loadUnaligned(fromByteOffset: at, as: UInt32.self))
                        values.append(Double(Float(bitPattern: bits)))
                    }
                }
            }
        }
        return values
    }

    // MARK: The model

    func model(name: String) throws -> Model {
        let nodes = json.nodes ?? []
        var parents = [Int?](repeating: nil, count: nodes.count)
        for (index, node) in nodes.enumerated() {
            for child in node.children ?? [] where nodes.indices.contains(child) { parents[child] = index }
        }
        let skeletonNodes: [Skeleton.Node] = nodes.enumerated().map { index, node in
            if let m = node.matrix, m.count == 16 {
                let matrix = Mat4(Vec4(m[0], m[1], m[2], m[3]), Vec4(m[4], m[5], m[6], m[7]),
                                  Vec4(m[8], m[9], m[10], m[11]), Vec4(m[12], m[13], m[14], m[15]))
                return Skeleton.Node(name: node.name ?? "node \(index)", parent: parents[index], rest: nil, matrix: matrix)
            }
            let t = node.translation ?? [0, 0, 0], r = node.rotation ?? [0, 0, 0, 1], s = node.scale ?? [1, 1, 1]
            let rest = JointPose(translation: Vec3(t[0], t[1], t[2]), rotation: Skeleton.normalized(Vec4(r[0], r[1], r[2], r[3])),
                                 scale: Vec3(s[0], s[1], s[2]))
            return Skeleton.Node(name: node.name ?? "node \(index)", parent: parents[index], rest: rest, matrix: rest.matrix)
        }
        func restGlobal(_ index: Int) -> Mat4 {
            let local = skeletonNodes[index].matrix
            return skeletonNodes[index].parent.map { restGlobal($0) * local } ?? local
        }

        // The skin: one, or none for a model that never bends.
        let skins = json.skins ?? []
        guard skins.count <= 1 else { throw Asset.Failure.malformed("\(skins.count) skins; a model has one") }
        let skinJoints = skins.first?.joints ?? []
        guard skinJoints.allSatisfy({ nodes.indices.contains($0) }) else { throw Asset.Failure.malformed("a joint past the nodes") }
        // Joints in the order asked for, the rest parent first after them.
        func depth(_ index: Int) -> Int { parents[index].map { depth($0) + 1 } ?? 0 }
        var named: [Int] = []
        for wanted in self.order {
            guard let joint = skinJoints.indices.first(where: { nodes[skinJoints[$0]].name == wanted }) else {
                throw Asset.Failure.malformed("no bone \(wanted)")
            }
            named.append(joint)
        }
        let rest = skinJoints.indices.filter { !named.contains($0) }
            .sorted { (depth(skinJoints[$0]), $0) < (depth(skinJoints[$1]), $1) }
        let order = named + rest
        var bone = [Int: Int]()  // the skin's joint index to the rig's bone
        for (position, joint) in order.enumerated() { bone[joint] = position + 1 }
        let jointNodes = order.map { skinJoints[$0] }
        var binds: [Mat4]
        if let accessor = skins.first?.inverseBindMatrices {
            let (values, width) = try floats(accessor)
            guard width == 16, values.count == skinJoints.count * 16 else { throw Asset.Failure.malformed("the inverse binds") }
            binds = (0..<skinJoints.count).map { j in
                let m = Array(values[(j * 16)..<(j * 16 + 16)])
                return Mat4(Vec4(m[0], m[1], m[2], m[3]), Vec4(m[4], m[5], m[6], m[7]),
                            Vec4(m[8], m[9], m[10], m[11]), Vec4(m[12], m[13], m[14], m[15]))
            }
        } else {
            binds = skinJoints.map { restGlobal($0).inverse ?? .identity }
        }
        let orderedBinds = order.map { binds[$0] }
        binds = orderedBinds

        var rig = Rig()
        for (position, node) in jointNodes.enumerated() {
            var parent = parents[node]
            while let p = parent, !jointNodes.contains(p) { parent = parents[p] }
            let parentBone = parent.flatMap { p in jointNodes.firstIndex(of: p).map { $0 + 1 } } ?? 0
            guard parentBone <= position else { throw Asset.Failure.malformed("bone \(skeletonNodes[node].name) before its parent") }
            rig.add(skeletonNodes[node].name, parent: parentBone, pivot: up.transformPoint(restGlobal(node).transformPoint(.zero)))
        }
        guard rig.count <= PackedVertex.partsMost else { throw Asset.Failure.malformed("more bones than a vertex can name") }

        // The mesh: every mesh node of the scene.
        var reached: [Int] = []
        var queue = json.scenes?[json.scene ?? 0].nodes ?? Array(nodes.indices.filter { parents[$0] == nil })
        while let next = queue.first {
            queue.removeFirst()
            reached.append(next)
            queue.append(contentsOf: nodes[next].children ?? [])
        }
        var mesh = Mesh(), fine = Mesh()
        for index in reached {
            guard let meshIndex = nodes[index].mesh else { continue }
            let tags = Asset.tags(nodes[index].name ?? "")
            guard tags.drawn(tier: tier, variant: variant) else { continue }
            guard let meshes = json.meshes, meshes.indices.contains(meshIndex) else { throw Asset.Failure.malformed("mesh \(meshIndex)") }
            let skinned = nodes[index].skin != nil
            // A mesh hung from a joint moves with it whole: a spear in the hand.
            var holder = parents[index]
            while let h = holder, bone[skinJoints.firstIndex(of: h) ?? -1] == nil { holder = parents[h] }
            let rigid = holder.flatMap { h in skinJoints.firstIndex(of: h).flatMap { bone[$0] } } ?? 0
            let place = restGlobal(index)
            let boneOf: (Int) -> UInt16 = { joint in skinJoints.indices.contains(joint) ? UInt16(bone[joint] ?? 0) : 0 }
            for primitive in meshes[meshIndex].primitives {
                if tags.fine {
                    try append(primitive, to: &fine, skinned: skinned, rigid: UInt16(rigid), place: place, bone: boneOf)
                } else {
                    try append(primitive, to: &mesh, skinned: skinned, rigid: UInt16(rigid), place: place, bone: boneOf)
                }
            }
        }
        guard !mesh.isEmpty else { throw Asset.Failure.malformed("no triangles") }
        if !fine.isEmpty {
            // Drawn only near: after every coarse triangle.
            fine.fineFrom = 0
            mesh.append(fine)
        }

        // The actions, each a clip by its name; one tagged as a piece is
        // ("attack@warden") played by what it is tagged for in place of the
        // one for all (a commander's own strike).
        var actions: [Clip: Skeleton.Action] = [:]
        var own: Set<Clip> = []
        for animation in json.animations ?? [] {
            let tags = Asset.tags((animation.name ?? "").split(separator: "|").last.map(String.init) ?? "")
            guard let clip = Clip(rawValue: tags.name.lowercased()) else { continue }
            if !tags.always {
                // A variant's own (in place of a tier's, as its pieces are), or a tier's; read as neither, the one for all.
                let mine = variant.map { tags.variants.contains($0) } ?? tier.map { tier in tags.tiers.contains { $0.contains(tier) } }
                guard mine == true else { continue }
            } else if own.contains(clip) {
                continue
            }
            var channels: [Skeleton.Channel] = []
            var start = Float.infinity, end = -Float.infinity
            for channel in animation.channels {
                guard let node = channel.target.node, nodes.indices.contains(node),
                      animation.samplers.indices.contains(channel.sampler) else { continue }
                let path: Skeleton.Path
                switch channel.target.path {
                case "translation": path = .translation
                case "rotation": path = .rotation
                case "scale": path = .scale
                default: continue
                }
                let sampler = animation.samplers[channel.sampler]
                let times = try floats(sampler.input).values
                let (values, width) = try floats(sampler.output)
                let cubic = sampler.interpolation == "CUBICSPLINE"
                guard !times.isEmpty, values.count == times.count * width * (cubic ? 3 : 1) else {
                    throw Asset.Failure.malformed("an action's keys")
                }
                start = min(start, times[0])
                end = max(end, times[times.count - 1])
                channels.append(Skeleton.Channel(node: node, path: path, times: times, values: values, width: width,
                                                 step: sampler.interpolation == "STEP", cubic: cubic))
            }
            guard !channels.isEmpty else { continue }
            actions[clip] = Skeleton.Action(start: start, duration: max(end - start, 0), channels: channels)
            if !tags.always { own.insert(clip) }
        }

        let skeleton = Skeleton(nodes: skeletonNodes, joints: jointNodes, inverseBinds: binds, actions: actions, up: up, down: down)
        return Model(name: name, mesh: mesh, rig: rig, skeleton: skeleton)
    }

    private func append(_ primitive: GLTF.Primitive, to mesh: inout Mesh, skinned: Bool, rigid: UInt16, place: Mat4,
                        bone: (Int) -> UInt16) throws {
        guard (primitive.mode ?? 4) == 4 else { throw Asset.Failure.malformed("a primitive not of triangles") }
        guard let positionAccessor = primitive.attributes["POSITION"] else { throw Asset.Failure.malformed("a primitive without positions") }
        let positions = try floats(positionAccessor).values
        let count = positions.count / 3
        let normals = try primitive.attributes["NORMAL"].map { try floats($0).values }
        let colours = try primitive.attributes["COLOR_0"].map { try floats($0) }
        let joints = skinned ? try primitive.attributes["JOINTS_0"].map { try integers($0).values } : nil
        let weights = skinned ? try primitive.attributes["WEIGHTS_0"].map { try floats($0).values } : nil
        let sway = try primitive.attributes["_SWAY"].map { try floats($0).values }
        let material = primitive.material.flatMap { json.materials?.indices.contains($0) == true ? json.materials?[$0] : nil }
        let (kind, surface) = Reader.kind(of: material?.name)
        let base = material?.pbrMetallicRoughness?.baseColorFactor ?? [1, 1, 1, 1]
        // A colour given for its material, by name, in place of the one it was made in.
        let given = material?.name.flatMap { self.colours[$0] }
        let normalMatrix = place.normalMatrix
        let first = UInt32(mesh.vertices.count)
        for i in 0..<count {
            var p = Vec3(positions[i * 3], positions[i * 3 + 1], positions[i * 3 + 2])
            var n = normals.map { Vec3($0[i * 3], $0[i * 3 + 1], $0[i * 3 + 2]) } ?? .up
            if !skinned {
                p = place.transformPoint(p)
                n = normalMatrix.transformDirection(n)
            }
            var linear = Vec3(base[0], base[1], base[2])
            if let (values, width) = colours, width >= 3 {
                linear *= Vec3(values[i * width], values[i * width + 1], values[i * width + 2])
            }
            var vertex = MeshVertex(position: up.transformPoint(p), normal: n.normalized, color: given ?? Reader.srgb(linear), part: rigid,
                                    material: kind, sway: min(max(sway.map { $0[i] } ?? 0, 0), 1), surface: surface)
            if let joints, let weights, joints.count >= (i + 1) * 4, weights.count >= (i + 1) * 4 {
                var pairs: [(joint: Int, weight: Float)] = []
                for k in 0..<4 {
                    pairs.append((joint: joints[i * 4 + k], weight: weights[i * 4 + k]))
                }
                pairs.sort { (a: (joint: Int, weight: Float), b: (joint: Int, weight: Float)) -> Bool in a.weight > b.weight }
                let total: Float = pairs[0].weight + pairs[1].weight
                vertex.part = bone(pairs[0].joint)
                if total > 0, pairs[1].weight > 0 {
                    vertex.part2 = bone(pairs[1].joint)
                    vertex.blend = pairs[1].weight / total
                }
            }
            mesh.vertices.append(vertex)
        }
        if let indicesAccessor = primitive.indices {
            let indices = try integers(indicesAccessor).values
            guard indices.allSatisfy({ $0 >= 0 && $0 < count }) else { throw Asset.Failure.malformed("an index past its vertices") }
            mesh.indices += indices.map { first + UInt32($0) }
        } else {
            mesh.indices += (0..<UInt32(count)).map { first + $0 }
        }
    }

    /// A material's kind and grain from its name.
    static func kind(of name: String?) -> (Material, Surface) {
        let words = (name ?? "").lowercased().split(whereSeparator: { $0 == "_" || $0 == "." || $0 == "-" || $0 == " " }).map(String.init)
        let kinds: [String: Material] = ["plain": .plain, "house": .house, "glow": .glow, "foliage": .foliage, "cloth": .cloth,
                                         "crystal": .crystal, "metal": .metal]
        let grains: [String: Surface] = ["stone": .stone, "timber": .timber, "thatch": .thatch, "slate": .slate, "earth": .earth]
        let kind = words.first.flatMap { kinds[$0] } ?? .plain
        let grain = words.dropFirst().first.flatMap { grains[$0] } ?? .smooth
        return (kind, grain)
    }

    /// Linear light to sRGB, as the world's colours are given.
    static func srgb(_ linear: Vec3) -> Vec3 {
        func channel(_ c: Float) -> Float {
            let c = min(max(c, 0), 1)
            return c <= 0.003_130_8 ? c * 12.92 : 1.055 * pow(c, 1 / 2.4) - 0.055
        }
        return Vec3(channel(linear.x), channel(linear.y), channel(linear.z))
    }
}
