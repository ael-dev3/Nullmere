import AppKit
import LauncherCore
import MetalKit
import os

/// What the backdrop should draw and how often.
struct LakeConfiguration: Equatable {
    var motion: ResolvedMotion
    /// Fraction of the display's native resolution to render at.
    var renderScale: Double
    var framesPerSecond: Int
    var horizon: Double
}

/// Draws the lake with Metal.
///
/// The view animates only while its window is visible and motion is allowed;
/// with motion set to still it renders a single frame per size change.
final class LakeMetalView: MTKView {
    static let systemDevice: (any MTLDevice)? = {
        let device = MTLCreateSystemDefaultDevice()
        if device == nil {
            LakeMetalView.logger.error("No Metal device is available; the lake is drawn as a still painting.")
        }
        return device
    }()

    var configuration: LakeConfiguration {
        didSet {
            if configuration != oldValue { applyConfiguration() }
        }
    }

    /// Called once if the shader cannot be compiled or the pipeline cannot be built.
    var onFailure: (() -> Void)?

    private static let logger = Logger(subsystem: "online.nullmere.launcher", category: "backdrop")

    private(set) var renderer: LakeRenderer?
    private var isLoadingRenderer = false
    private var clock = SceneClock()
    private var isWindowVisible = false
    private var occlusionObserver: (any NSObjectProtocol)?

    init(configuration: LakeConfiguration) {
        self.configuration = configuration
        super.init(frame: .zero, device: LakeMetalView.systemDevice)
        colorPixelFormat = .bgra8Unorm
        colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        framebufferOnly = true
        autoResizeDrawable = false
        applyConfiguration()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
    }

    override var isOpaque: Bool { true }

    /// The title bar is hidden, so the lake itself moves the window.
    override var mouseDownCanMoveWindow: Bool { true }

    // MARK: Lifecycle

    override func viewDidMoveToWindow() {
        super.viewDidMoveToWindow()
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
        }
        if let window {
            occlusionObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didChangeOcclusionStateNotification,
                object: window,
                queue: .main
            ) { [weak self] _ in
                guard let self else { return }
                MainActor.assumeIsolated { self.updateWindowVisibility() }
            }
            loadRendererIfNeeded()
        }
        updateWindowVisibility()
        updateDrawableSize()
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let renderer,
              bounds.width > 0, bounds.height > 0,
              let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable
        else { return }

        let time = clock.advance(to: CACurrentMediaTime(), rate: configuration.motion.clockRate)
        let uniforms = LakeUniforms(
            sizeAndPixels: SIMD4(
                Float(bounds.width), Float(bounds.height),
                Float(drawableSize.width), Float(drawableSize.height)
            ),
            params: SIMD4(Float(time), configuration.motion.activity, Float(configuration.horizon), 0)
        )
        renderer.draw(uniforms, in: pass, to: drawable)
    }

    // MARK: Configuration

    private func applyConfiguration() {
        preferredFramesPerSecond = configuration.framesPerSecond
        updateDrawableSize()
        updatePausing()
    }

    private func updateWindowVisibility() {
        isWindowVisible = window?.occlusionState.contains(.visible) ?? false
        updatePausing()
    }

    /// Runs the display link only while there is something to animate.
    private func updatePausing() {
        let animates = renderer != nil && isWindowVisible && configuration.motion != .still
        isPaused = !animates
        enableSetNeedsDisplay = !animates
        if !animates {
            clock.resetInterval()
            needsDisplay = true
        }
    }

    private func updateDrawableSize() {
        let backingScale = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let scale = backingScale * configuration.renderScale
        let size = CGSize(
            width: max(1, (bounds.width * scale).rounded()),
            height: max(1, (bounds.height * scale).rounded())
        )
        if drawableSize != size {
            drawableSize = size
        }
        if isPaused {
            needsDisplay = true
        }
    }

    // MARK: Shader

    private func loadRendererIfNeeded() {
        guard renderer == nil, !isLoadingRenderer else { return }
        guard let device else {
            reportFailure("No Metal device is available.")
            return
        }
        isLoadingRenderer = true
        let pixelFormat = colorPixelFormat
        device.makeLibrary(source: LakeShader.source, options: nil) { [weak self] library, error in
            DispatchQueue.main.async { [weak self] in
                self?.finishLoading(device: device, library: library, error: error, pixelFormat: pixelFormat)
            }
        }
    }

    func finishLoading(
        device: any MTLDevice,
        library: (any MTLLibrary)?,
        error: (any Error)?,
        pixelFormat: MTLPixelFormat
    ) {
        isLoadingRenderer = false
        guard let library else {
            reportFailure("The lake shader did not compile: \(error?.localizedDescription ?? "unknown error")")
            return
        }
        do {
            renderer = try LakeRenderer(device: device, library: library, pixelFormat: pixelFormat)
            Self.logger.notice("The lake renders with Metal on \(device.name, privacy: .public).")
            Reporting.say("The lake renders with Metal on \(device.name).")
            clock.resetInterval()
            updateWindowVisibility()
        } catch {
            reportFailure("The lake pipeline could not be built: \(error)")
        }
    }

    private func reportFailure(_ message: String) {
        Self.logger.error("\(message, privacy: .public)")
        onFailure?()
        onFailure = nil
    }
}
