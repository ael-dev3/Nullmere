import Metal
import QuartzCore

/// Per-frame values for the lake shader. Matches `LakeUniforms` in `LakeShader`.
struct LakeUniforms {
    /// View size in points (x, y) and drawable size in pixels (z, w).
    var sizeAndPixels: SIMD4<Float>
    /// Scene time, activity (see `ResolvedMotion.activity`), horizon height and an unused lane.
    var params: SIMD4<Float>
}

/// Encodes the lake scene: one full-screen triangle per frame.
final class LakeRenderer {
    enum Failure: Error {
        case missingFunction(String)
        case noCommandQueue
    }

    private let commandQueue: any MTLCommandQueue
    private let pipeline: any MTLRenderPipelineState

    init(device: any MTLDevice, library: any MTLLibrary, pixelFormat: MTLPixelFormat) throws {
        guard let vertexFunction = library.makeFunction(name: LakeShader.vertexFunction) else {
            throw Failure.missingFunction(LakeShader.vertexFunction)
        }
        guard let fragmentFunction = library.makeFunction(name: LakeShader.fragmentFunction) else {
            throw Failure.missingFunction(LakeShader.fragmentFunction)
        }
        guard let commandQueue = device.makeCommandQueue() else {
            throw Failure.noCommandQueue
        }
        commandQueue.label = "Nullmere lake"

        let descriptor = MTLRenderPipelineDescriptor()
        descriptor.label = "Nullmere lake"
        descriptor.vertexFunction = vertexFunction
        descriptor.fragmentFunction = fragmentFunction
        descriptor.colorAttachments[0].pixelFormat = pixelFormat

        self.pipeline = try device.makeRenderPipelineState(descriptor: descriptor)
        self.commandQueue = commandQueue
    }

    func draw(_ uniforms: LakeUniforms, in pass: MTLRenderPassDescriptor, to drawable: any CAMetalDrawable) {
        guard let commandBuffer = encode(uniforms, in: pass) else { return }
        commandBuffer.present(drawable)
        commandBuffer.commit()
    }

    private func encode(_ uniforms: LakeUniforms, in pass: MTLRenderPassDescriptor) -> (any MTLCommandBuffer)? {
        guard let commandBuffer = commandQueue.makeCommandBuffer(),
              let encoder = commandBuffer.makeRenderCommandEncoder(descriptor: pass)
        else { return nil }
        var uniforms = uniforms
        encoder.setRenderPipelineState(pipeline)
        encoder.setFragmentBytes(&uniforms, length: MemoryLayout<LakeUniforms>.stride, index: 0)
        encoder.drawPrimitives(type: .triangle, vertexStart: 0, vertexCount: 3)
        encoder.endEncoding()
        return commandBuffer
    }

    /// Renders one frame into a texture and returns how long the GPU spent
    /// on it, in milliseconds: for measuring, not for showing.
    func measureFrame(_ uniforms: LakeUniforms, into target: any MTLTexture) -> Double? {
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
