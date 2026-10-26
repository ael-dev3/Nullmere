import AppKit
import MetalKit
import NullmereCore
import os

/// Draws the world with Metal and turns the pointer into map input: hover,
/// click to select, right-click (or two-finger click) to order, drag or
/// two-finger scroll to pan, and pinch, Command-scroll or the mouse wheel
/// to zoom.
final class WorldMetalView: MTKView {
    static let systemDevice: (any MTLDevice)? = MTLCreateSystemDefaultDevice()
    private static let logger = Logger(subsystem: "online.nullmere.game", category: "world")

    var camera = Camera() {
        didSet {
            if camera != oldValue {
                if Self.renderScale(forCameraScale: camera.scale) != Self.renderScale(forCameraScale: oldValue.scale) {
                    updateDrawableSize()
                }
                redraw()
            }
        }
    }

    /// The fraction of native pixels the world is drawn at. Close in, a hex
    /// spans so many points that drawing it at three quarters of native
    /// resolution looks the same and keeps the frame well inside its budget.
    static func renderScale(forCameraScale scale: Double) -> Double {
        scale >= 44 ? 0.75 : 1
    }
    var hovered: Hex? {
        didSet { if hovered != oldValue { redraw() } }
    }
    var selected: Hex? {
        didSet { if selected != oldValue { redraw() } }
    }
    var radius = 24
    /// The moon in the water, placed for the map's lake.
    var moon = SIMD4<Float>(0, -2.2, 1.05, 1)
    var animates = true {
        didSet { if animates != oldValue { updatePausing() } }
    }

    var onHover: ((Hex?) -> Void)?
    var onClick: ((Hex) -> Void)?
    var onSecondaryClick: ((Hex) -> Void)?
    var onCameraChange: ((Camera) -> Void)?
    var onFailure: (() -> Void)?

    private var renderer: WorldRenderer?
    private var isLoadingRenderer = false
    private var pendingTiles: (bytes: [UInt8], side: Int)?
    private var tilesVersion = -1
    private var isWindowVisible = false
    private var occlusionObserver: (any NSObjectProtocol)?
    private var trackingArea: NSTrackingArea?
    private var appObservers: [any NSObjectProtocol] = []
    private var dragOrigin: CGPoint?
    private var dragged = false
    private let started = CACurrentMediaTime()

    init() {
        super.init(frame: .zero, device: WorldMetalView.systemDevice)
        colorPixelFormat = .bgra8Unorm
        colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        clearColor = MTLClearColor(red: 0, green: 0, blue: 0, alpha: 1)
        framebufferOnly = true
        autoResizeDrawable = false
        updateFrameRate()
        updatePausing()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    deinit {
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
        }
        for observer in appObservers {
            NotificationCenter.default.removeObserver(observer)
        }
    }

    override func setFrameSize(_ newSize: NSSize) {
        super.setFrameSize(newSize)
        updateDrawableSize()
    }

    override func viewDidChangeBackingProperties() {
        super.viewDidChangeBackingProperties()
        updateDrawableSize()
    }

    private func updateDrawableSize() {
        let backing = window?.backingScaleFactor ?? NSScreen.main?.backingScaleFactor ?? 2
        let factor = backing * Self.renderScale(forCameraScale: camera.scale)
        let size = CGSize(width: max(1, (bounds.width * factor).rounded()), height: max(1, (bounds.height * factor).rounded()))
        if drawableSize != size {
            drawableSize = size
        }
        redraw()
    }

    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// New tile data; ignored when the version hasn't changed.
    func setTiles(_ bytes: [UInt8], side: Int, version: Int) {
        guard version != tilesVersion else { return }
        tilesVersion = version
        if let renderer {
            do {
                try renderer.updateTiles(bytes, side: side)
            } catch {
                reportFailure("The world's tile texture could not be made: \(error)")
            }
        } else {
            pendingTiles = (bytes, side)
        }
        redraw()
    }

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
        if appObservers.isEmpty {
            let names: [Notification.Name] = [
                NSApplication.didBecomeActiveNotification,
                NSApplication.didResignActiveNotification,
                .NSProcessInfoPowerStateDidChange,
                ProcessInfo.thermalStateDidChangeNotification,
            ]
            appObservers = names.map { name in
                NotificationCenter.default.addObserver(forName: name, object: nil, queue: .main) { [weak self] _ in
                    guard let self else { return }
                    MainActor.assumeIsolated { self.updateFrameRate() }
                }
            }
        }
        updateWindowVisibility()
    }

    private func updateWindowVisibility() {
        isWindowVisible = window?.occlusionState.contains(.visible) ?? false
        updateFrameRate()
        updatePausing()
    }

    /// 60 frames a second while the game is in front; 30 behind another
    /// app, in Low Power Mode, or while the Mac runs hot.
    func updateFrameRate() {
        let info = ProcessInfo.processInfo
        let savesEnergy = info.isLowPowerModeEnabled || [.serious, .critical].contains(info.thermalState)
        let inFront = NSApplication.shared.isActive
        let rate = inFront && !savesEnergy ? 60 : 30
        if preferredFramesPerSecond != rate {
            preferredFramesPerSecond = rate
        }
    }

    private func updatePausing() {
        let running = renderer != nil && isWindowVisible && animates
        isPaused = !running
        enableSetNeedsDisplay = !running
        if !running {
            needsDisplay = true
        }
    }

    private func redraw() {
        if isPaused {
            needsDisplay = true
        }
    }

    private func loadRendererIfNeeded() {
        guard renderer == nil, !isLoadingRenderer else { return }
        guard let device else {
            reportFailure("No Metal device is available.")
            return
        }
        isLoadingRenderer = true
        let pixelFormat = colorPixelFormat
        device.makeLibrary(source: WorldShader.source, options: nil) { [weak self] library, error in
            DispatchQueue.main.async { [weak self] in
                self?.finishLoading(device: device, library: library, error: error, pixelFormat: pixelFormat)
            }
        }
    }

    private func finishLoading(device: any MTLDevice, library: (any MTLLibrary)?, error: (any Error)?, pixelFormat: MTLPixelFormat) {
        isLoadingRenderer = false
        guard let library else {
            reportFailure("The world shader did not compile: \(error?.localizedDescription ?? "unknown error")")
            return
        }
        do {
            let renderer = try WorldRenderer(device: device, library: library, pixelFormat: pixelFormat)
            if let pendingTiles {
                try renderer.updateTiles(pendingTiles.bytes, side: pendingTiles.side)
                self.pendingTiles = nil
            }
            self.renderer = renderer
            WorldMetalView.logger.notice("The world renders with Metal on \(device.name, privacy: .public).")
            updatePausing()
        } catch {
            reportFailure("The world pipeline could not be built: \(error)")
        }
    }

    private func reportFailure(_ message: String) {
        WorldMetalView.logger.error("\(message, privacy: .public)")
        onFailure?()
        onFailure = nil
    }

    // MARK: Drawing

    override func draw(_ dirtyRect: NSRect) {
        guard let renderer, renderer.hasTiles,
              bounds.width > 0, bounds.height > 0,
              let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable
        else { return }
        let pixelsPerPoint = drawableSize.width / bounds.width
        let time = (CACurrentMediaTime() - started).truncatingRemainder(dividingBy: 3600)
        let uniforms = WorldUniforms(
            view: SIMD4(Float(drawableSize.width), Float(drawableSize.height), Float(camera.scale * pixelsPerPoint), Float(time)),
            camera: SIMD4(Float(camera.centerX), Float(camera.centerY), Float(radius), Float(pixelsPerPoint)),
            highlight: SIMD4(
                Float(hovered?.q ?? 999), Float(hovered?.r ?? 999),
                Float(selected?.q ?? 999), Float(selected?.r ?? 999)
            ),
            moon: moon
        )
        renderer.draw(uniforms, in: pass, to: drawable)
    }

    // MARK: Input

    /// A point in the view, measured from the top left as the camera expects.
    private func point(of event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        return CGPoint(x: local.x, y: bounds.height - local.y)
    }

    private func hex(of event: NSEvent) -> Hex {
        camera.hex(at: point(of: event), in: bounds.size)
    }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let trackingArea {
            removeTrackingArea(trackingArea)
        }
        let area = NSTrackingArea(
            rect: bounds,
            options: [.mouseMoved, .mouseEnteredAndExited, .activeInKeyWindow, .inVisibleRect],
            owner: self,
            userInfo: nil
        )
        addTrackingArea(area)
        trackingArea = area
    }

    override func mouseMoved(with event: NSEvent) {
        let hex = hex(of: event)
        onHover?(hex)
        (cursor?(hex) ?? .arrow).set()
    }

    /// The pointer's shape over a hex: a hand over what can be chosen, a
    /// crosshair over what can be struck.
    var cursor: ((Hex) -> NSCursor)?

    override func mouseExited(with event: NSEvent) {
        onHover?(nil)
    }

    override func mouseDown(with event: NSEvent) {
        window?.makeFirstResponder(self)
        dragOrigin = point(of: event)
        dragged = false
    }

    override func mouseDragged(with event: NSEvent) {
        let now = point(of: event)
        if let origin = dragOrigin, !dragged, hypot(now.x - origin.x, now.y - origin.y) > 4 {
            dragged = true
        }
        if dragged {
            var moved = camera
            moved.pan(dx: event.deltaX, dy: event.deltaY)
            moved.clamp(toRadius: radius)
            camera = moved
            onCameraChange?(moved)
        }
    }

    override func mouseUp(with event: NSEvent) {
        if !dragged {
            onClick?(hex(of: event))
        }
        dragOrigin = nil
        dragged = false
    }

    override func rightMouseDown(with event: NSEvent) {
        onSecondaryClick?(hex(of: event))
    }

    override func scrollWheel(with event: NSEvent) {
        var moved = camera
        if event.hasPreciseScrollingDeltas, !event.modifierFlags.contains(.command) {
            moved.pan(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY)
        } else {
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.01 : event.scrollingDeltaY * 0.08
            moved.zoom(by: exp(delta), around: point(of: event), in: bounds.size)
        }
        moved.clamp(toRadius: radius)
        camera = moved
        onCameraChange?(moved)
    }

    override func magnify(with event: NSEvent) {
        var moved = camera
        moved.zoom(by: 1 + event.magnification, around: point(of: event), in: bounds.size)
        moved.clamp(toRadius: radius)
        camera = moved
        onCameraChange?(moved)
    }
}
