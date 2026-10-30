import Metal
import NullmereCore
import NullmereModels
import NullmereWorld
import QuartzCore

/// Draws the world in three dimensions from the camera's eye: the land
/// and the mist over what the keeper has never seen, the models standing
/// on it, and the still water over the lake. The land is sent to the GPU
/// once for a map and each model's mesh once; a frame sends only its
/// uniforms, where each model stands and how its parts are posed.
final class WorldRenderer {
    enum Failure: Error, Equatable {
        case missingFunction(String)
        case noCommandQueue
        case noTexture
        case noBuffer
        case noDepthState
    }

    /// One map's land, as the GPU holds it.
    struct Land {
        let map: WorldMap
        let terrain: TerrainMesh
        let vertices: any MTLBuffer
        let indices: any MTLBuffer
        let indexCount: Int
        /// The land's heights, for the water to know how deep it lies.
        let heights: any MTLTexture
    }

    /// One model's mesh, as the GPU holds it.
    struct GPUMesh {
        let vertices: any MTLBuffer
        let indices: any MTLBuffer
        let indexCount: Int
    }

    /// What a frame is drawn into away from the screen: for measuring and
    /// for looking at.
    struct Target {
        let colour: any MTLTexture
        let resolved: any MTLTexture
        let depth: any MTLTexture

        var pass: MTLRenderPassDescriptor {
            let pass = MTLRenderPassDescriptor()
            pass.colorAttachments[0].texture = colour
            pass.colorAttachments[0].resolveTexture = resolved
            pass.colorAttachments[0].loadAction = .clear
            pass.colorAttachments[0].clearColor = WorldRenderer.night
            pass.colorAttachments[0].storeAction = .multisampleResolve
            pass.depthAttachment.texture = depth
            pass.depthAttachment.loadAction = .clear
            pass.depthAttachment.clearDepth = 1
            pass.depthAttachment.storeAction = .dontCare
            return pass
        }
    }

    static let depthFormat = MTLPixelFormat.depth32Float
    /// Each pixel sampled four times, so edges against the night are clean.
    static let sampleCount = 4
    /// What lies past the land: the dark.
    static let night = MTLClearColor(red: 0.035, green: 0.04, blue: 0.055, alpha: 1)

    let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let landPipeline: any MTLRenderPipelineState
    private let modelPipeline: any MTLRenderPipelineState
    private let waterPipeline: any MTLRenderPipelineState
    private let solid: any MTLDepthStencilState
    private let glassy: any MTLDepthStencilState
    private let pixelFormat: MTLPixelFormat
    private var tiles: (any MTLTexture)?
    private(set) var land: Land?
    private var meshes: [ModelKey: GPUMesh] = [:]
    /// Where a model's mesh comes from: the library, unless a test says otherwise.
    var meshSource: (ModelKey) -> NullmereModels.Mesh? = { _ in nil }

    init(device: any MTLDevice, library: any MTLLibrary, pixelFormat: MTLPixelFormat) throws {
        func function(_ name: String) throws -> any MTLFunction {
            guard let found = library.makeFunction(name: name) else { throw Failure.missingFunction(name) }
            return found
        }
        func pipeline(_ label: String, _ vertex: String, _ fragment: String, blends: Bool) throws -> any MTLRenderPipelineState {
            let descriptor = MTLRenderPipelineDescriptor()
            descriptor.label = label
            descriptor.vertexFunction = try function(vertex)
            descriptor.fragmentFunction = try function(fragment)
            descriptor.colorAttachments[0].pixelFormat = pixelFormat
            descriptor.depthAttachmentPixelFormat = WorldRenderer.depthFormat
            descriptor.rasterSampleCount = WorldRenderer.sampleCount
            if blends {
                descriptor.colorAttachments[0].isBlendingEnabled = true
                descriptor.colorAttachments[0].sourceRGBBlendFactor = .sourceAlpha
                descriptor.colorAttachments[0].destinationRGBBlendFactor = .oneMinusSourceAlpha
                descriptor.colorAttachments[0].sourceAlphaBlendFactor = .one
                descriptor.colorAttachments[0].destinationAlphaBlendFactor = .oneMinusSourceAlpha
            }
            return try device.makeRenderPipelineState(descriptor: descriptor)
        }
        landPipeline = try pipeline("Nullmere land", WorldShaders.landVertex, WorldShaders.landFragment, blends: false)
        waterPipeline = try pipeline("Nullmere water", WorldShaders.waterVertex, WorldShaders.waterFragment, blends: true)
        modelPipeline = try pipeline("Nullmere models", WorldShaders.modelVertex, WorldShaders.modelFragment, blends: false)
        guard let commandQueue = device.makeCommandQueue() else { throw Failure.noCommandQueue }
        commandQueue.label = "Nullmere world"
        let solidDescriptor = MTLDepthStencilDescriptor()
        solidDescriptor.depthCompareFunction = .lessEqual
        solidDescriptor.isDepthWriteEnabled = true
        let glassyDescriptor = MTLDepthStencilDescriptor()
        glassyDescriptor.depthCompareFunction = .lessEqual
        glassyDescriptor.isDepthWriteEnabled = false
        guard let solid = device.makeDepthStencilState(descriptor: solidDescriptor),
              let glassy = device.makeDepthStencilState(descriptor: glassyDescriptor)
        else { throw Failure.noDepthState }
        self.solid = solid
        self.glassy = glassy
        self.commandQueue = commandQueue
        self.device = device
        self.pixelFormat = pixelFormat
    }

    // MARK: The world's data

    /// Sends a map's land to the GPU; a map already there is kept.
    func setLand(_ terrain: TerrainMesh, for map: WorldMap) throws {
        guard land?.map != map else { return }
        let packed = terrain.mesh.packed
        let indices = terrain.mesh.indices
        guard let vertexBuffer = device.makeBuffer(bytes: packed, length: packed.count * MemoryLayout<PackedVertex>.stride,
                                                   options: .storageModeShared),
              let indexBuffer = device.makeBuffer(bytes: indices, length: indices.count * MemoryLayout<UInt32>.stride,
                                                  options: .storageModeShared)
        else { throw Failure.noBuffer }
        vertexBuffer.label = "Nullmere land"
        let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .r16Float, width: terrain.columns, height: terrain.rows,
                                                                  mipmapped: false)
        descriptor.usage = .shaderRead
        descriptor.storageMode = .shared
        guard let heights = device.makeTexture(descriptor: descriptor) else { throw Failure.noTexture }
        heights.label = "Nullmere heights"
        let halves = terrain.heights.map { Float16($0) }
        halves.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            heights.replace(region: MTLRegionMake2D(0, 0, terrain.columns, terrain.rows), mipmapLevel: 0, withBytes: base,
                            bytesPerRow: terrain.columns * MemoryLayout<Float16>.stride)
        }
        land = Land(map: map, terrain: terrain, vertices: vertexBuffer, indices: indexBuffer, indexCount: indices.count, heights: heights)
    }

    /// Replaces the tile data, creating the texture when the world's size changes.
    func updateTiles(_ bytes: [UInt8], side: Int) throws {
        if tiles == nil || tiles?.width != side {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: .rgba8Unorm, width: side, height: side, mipmapped: false)
            descriptor.usage = .shaderRead
            descriptor.storageMode = .shared
            guard let texture = device.makeTexture(descriptor: descriptor) else { throw Failure.noTexture }
            texture.label = "Nullmere tiles"
            tiles = texture
        }
        guard let tiles, bytes.count == side * side * 4 else { return }
        bytes.withUnsafeBytes { raw in
            guard let base = raw.baseAddress else { return }
            tiles.replace(region: MTLRegionMake2D(0, 0, side, side), mipmapLevel: 0, withBytes: base, bytesPerRow: side * 4)
        }
    }

    var hasTiles: Bool { tiles != nil }

    /// A model's mesh on the GPU, sent the first time it is drawn.
    func mesh(for key: ModelKey) -> GPUMesh? {
        if let kept = meshes[key] { return kept }
        guard let mesh = meshSource(key), !mesh.isEmpty else { return nil }
        let packed = mesh.packed
        guard let vertices = device.makeBuffer(bytes: packed, length: packed.count * MemoryLayout<PackedVertex>.stride,
                                               options: .storageModeShared),
              let indices = device.makeBuffer(bytes: mesh.indices, length: mesh.indices.count * MemoryLayout<UInt32>.stride,
                                              options: .storageModeShared)
        else { return nil }
        vertices.label = key.description
        let made = GPUMesh(vertices: vertices, indices: indices, indexCount: mesh.indices.count)
        meshes[key] = made
        return made
    }

    // MARK: Drawing

    func draw(_ frame: FrameUniforms, scene: SceneFrame, in pass: MTLRenderPassDescriptor, to drawable: any CAMetalDrawable) {
        guard let commandBuffer = encode(frame, scene: scene, in: pass) else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encode(_ frame: FrameUniforms, scene: SceneFrame, in pass: MTLRenderPassDescriptor) -> (any MTLCommandBuffer)? {
        guard let tiles, let land,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else { return nil }
        var uniforms = frame
        let uniformLength = MemoryLayout<FrameUniforms>.stride
        encoder.setCullMode(.none)
        encoder.setDepthStencilState(solid)
        encoder.setVertexBytes(&uniforms, length: uniformLength, index: 3)
        encoder.setFragmentBytes(&uniforms, length: uniformLength, index: 0)
        encoder.setVertexTexture(tiles, index: 0)
        encoder.setFragmentTexture(tiles, index: 0)

        // The land.
        encoder.setRenderPipelineState(landPipeline)
        encoder.setVertexBuffer(land.vertices, offset: 0, index: 0)
        encoder.drawIndexedPrimitives(type: .triangle, indexCount: land.indexCount, indexType: .uint32,
                                      indexBuffer: land.indices, indexBufferOffset: 0)

        // What stands on it, kind by kind.
        let instances = scene.batches.flatMap(\.instances)
        if !instances.isEmpty,
           let instanceBuffer = device.makeBuffer(bytes: instances, length: instances.count * MemoryLayout<ModelInstance>.stride,
                                                  options: .storageModeShared),
           let paletteBuffer = device.makeBuffer(bytes: scene.palette, length: scene.palette.count * MemoryLayout<Mat4>.stride,
                                                 options: .storageModeShared) {
            encoder.setRenderPipelineState(modelPipeline)
            encoder.setVertexBuffer(paletteBuffer, offset: 0, index: 2)
            var first = 0
            for batch in scene.batches {
                defer { first += batch.instances.count }
                guard !batch.instances.isEmpty, let mesh = mesh(for: batch.key) else { continue }
                encoder.setVertexBuffer(mesh.vertices, offset: 0, index: 0)
                encoder.setVertexBuffer(instanceBuffer, offset: first * MemoryLayout<ModelInstance>.stride, index: 1)
                encoder.drawIndexedPrimitives(type: .triangle, indexCount: mesh.indexCount, indexType: .uint32,
                                              indexBuffer: mesh.indices, indexBufferOffset: 0, instanceCount: batch.instances.count)
            }
        }

        // The still water over all, last, so what stands in the shallows
        // stands in it.
        encoder.setRenderPipelineState(waterPipeline)
        encoder.setDepthStencilState(glassy)
        encoder.setFragmentTexture(land.heights, index: 1)
        encoder.drawPrimitives(type: .triangleStrip, vertexStart: 0, vertexCount: 4)
        encoder.endEncoding()
        return commandBuffer
    }

    // MARK: Away from the screen

    /// Somewhere to draw a frame of `width` by `height` pixels away from the
    /// screen; its resolved colour can be read back.
    func makeTarget(width: Int, height: Int) throws -> Target {
        func texture(_ format: MTLPixelFormat, samples: Int, usage: MTLTextureUsage, storage: MTLStorageMode) throws -> any MTLTexture {
            let descriptor = MTLTextureDescriptor.texture2DDescriptor(pixelFormat: format, width: width, height: height, mipmapped: false)
            descriptor.textureType = samples > 1 ? .type2DMultisample : .type2D
            descriptor.sampleCount = samples
            descriptor.usage = usage
            descriptor.storageMode = storage
            guard let made = device.makeTexture(descriptor: descriptor) else { throw Failure.noTexture }
            return made
        }
        return Target(colour: try texture(pixelFormat, samples: WorldRenderer.sampleCount, usage: .renderTarget, storage: .private),
                      resolved: try texture(pixelFormat, samples: 1, usage: [.renderTarget, .shaderRead], storage: .shared),
                      depth: try texture(WorldRenderer.depthFormat, samples: WorldRenderer.sampleCount, usage: .renderTarget,
                                         storage: .private))
    }

    /// Renders one frame into a target and returns how long the GPU spent
    /// on it, in milliseconds: for measuring, not for showing.
    func measureFrame(_ frame: FrameUniforms, scene: SceneFrame = SceneFrame(), into target: Target) -> Double? {
        guard let commandBuffer = encode(frame, scene: scene, in: target.pass) else { return nil }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return (commandBuffer.gpuEndTime - commandBuffer.gpuStartTime) * 1000
    }

    /// A frame's pixels, row by row from the top, four bytes each in the
    /// target's order (blue, green, red, alpha).
    func pixels(_ frame: FrameUniforms, scene: SceneFrame = SceneFrame(), into target: Target) -> [UInt8]? {
        guard measureFrame(frame, scene: scene, into: target) != nil else { return nil }
        let width = target.resolved.width, height = target.resolved.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            guard let base = raw.baseAddress else { return }
            target.resolved.getBytes(base, bytesPerRow: width * 4, from: MTLRegionMake2D(0, 0, width, height), mipmapLevel: 0)
        }
        return bytes
    }
}
