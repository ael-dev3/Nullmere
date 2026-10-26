import Metal
import QuartzCore

/// Per-frame values for the world shader. Matches `WorldUniforms` in `WorldShader`.
struct WorldUniforms {
    /// Viewport width and height in pixels, pixels per world unit, time.
    var view: SIMD4<Float>
    /// World x and y at the viewport centre, world radius, pixels per point.
    var camera: SIMD4<Float>
    /// Hovered q and r, selected q and r; 999 for none.
    var highlight: SIMD4<Float>
}

/// Encodes the world: one full-screen triangle reading the tile texture.
final class WorldRenderer {
    enum Failure: Error {
        case missingFunction(String)
        case noCommandQueue
        case noTexture
    }

    private let device: any MTLDevice
    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState
    private var tiles: (any MTLTexture)?

    init(device: any MTLDevice, library: any MTLLibrary, pixelFormat: MTLPixelFormat) throws {
        guard let vertexFunction = library.makeFunction(name: WorldShader.vertexFunction) else {
            throw Failure.missingFunction(WorldShader.vertexFunction)
        }
        guard let fragmentFunction = library.makeFunction(name: WorldShader.fragmentFunction) else {
            throw Failure.missingFunction(WorldShader.fragmentFunction)
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw Failure.noCommandQueue
        }
        commandQueue.label = "Nullmere world"
        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Nullmere world"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat
        self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        self.commandQueue = commandQueue
        self.device = device
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

    func draw(_ uniforms: WorldUniforms, in pass: MTLRenderPassDescriptor, to drawable: any CAMetalDrawable) {
        guard let commandBuffer = encode(uniforms, in: pass) else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encode(_ uniforms: WorldUniforms, in pass: MTLRenderPassDescriptor) -> (any MTLCommandBuffer)? {
        guard let tiles,
              let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else { return nil }
        var uniforms = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<WorldUniforms>.stride, index: 0)
        encoder.setFragmentTexture(tiles, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return commandBuffer
    }

    /// Renders one frame into a texture and returns how long the GPU spent
    /// on it, in milliseconds: for measuring, not for showing.
    func measureFrame(_ uniforms: WorldUniforms, into target: any MTLTexture) -> Double? {
        let pass = MTLRenderPassDescriptor()
        pass.colorAttachments[0].texture = target
        pass.colorAttachments[0].loadAction = .dontCare
        pass.colorAttachments[0].storeAction = .store
        guard let commandBuffer = encode(uniforms, in: pass) else { return nil }
        commandBuffer.commit()
        commandBuffer.waitUntilCompleted()
        return (commandBuffer.gpuEndTime - commandBuffer.gpuStartTime) * 1000
    }
}
