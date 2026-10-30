import Foundation
import NullmereCore
import NullmereModels

/// Every model drawn of one kind in a frame.
public struct ModelBatch: Equatable, Sendable {
    public var key: ModelKey
    public var instances: [ModelInstance]

    public init(key: ModelKey, instances: [ModelInstance]) {
        self.key = key
        self.instances = instances
    }
}

/// What a frame draws besides the land and the water: its models, kind by
/// kind, and the poses of their parts, the first of them standing still.
public struct SceneFrame: Equatable, Sendable {
    public var batches: [ModelBatch]
    public var palette: [Mat4]

    public init(batches: [ModelBatch] = [], palette: [Mat4] = [.identity]) {
        self.batches = batches
        self.palette = palette.isEmpty ? [.identity] : palette
    }

    public var instanceCount: Int { batches.reduce(0) { $0 + $1.instances.count } }

    /// Adds a model's pose to the palette and returns where it begins.
    public mutating func add(pose: [Mat4]) -> UInt32 {
        guard pose.count > 1 || pose.first != .identity else { return 0 }
        let start = UInt32(palette.count)
        palette.append(contentsOf: pose)
        return start
    }
}

extension FrameUniforms {
    /// A frame's uniforms for a camera over a map's land, at a moment.
    /// `houses` are the Houses' colours by sigil, linear; the shaders find
    /// them a slot on, slot zero being no House's.
    public static func make(camera: Camera, size: CGSize, pixelsPerPoint: Double, time: Float, motion: Float,
                            radius: Int, terrain: TerrainMesh, hovered: Hex?, selected: Hex?, houses: [Vec4],
                            exposure: Float = 1) -> FrameUniforms {
        let eye = camera.eye(in: size)
        let low = terrain.mesh.bounds.min, high = terrain.mesh.bounds.max
        return FrameUniforms(
            viewProjection: camera.viewProjection(in: size),
            eye: Vec4(eye.x, eye.y, eye.z, time),
            moon: Vec4(Sky.moon.x, Sky.moon.y, Sky.moon.z, Sky.moonStrength),
            viewport: Vec4(Float(size.width * pixelsPerPoint), Float(size.height * pixelsPerPoint),
                           1 / Float(max(size.width * pixelsPerPoint, 1)), 1 / Float(max(size.height * pixelsPerPoint, 1))),
            world: Vec4(Float(radius), Float(2 * radius + 1), Float(camera.scale * pixelsPerPoint), motion),
            highlight: Vec4(Float(hovered?.q ?? 999), Float(hovered?.r ?? 999), Float(selected?.q ?? 999), Float(selected?.r ?? 999)),
            extent: Vec4(low.x, low.z, high.x, high.z),
            haze: Sky.haze(eyeDistance: (eye - camera.focus).length, exposure: exposure, spacing: terrain.spacing),
            heights: Vec4(terrain.originX, terrain.originZ, Float(terrain.columns), Float(terrain.rows)),
            houses: [Vec4(0.6, 0.6, 0.6, 1)] + houses)
    }
}
