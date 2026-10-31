import AppKit
import LauncherCore
import MetalKit
import NullmereCore
import NullmereModels
import NullmereWorld
import os

/// Draws the world with Metal and turns the pointer into map input: hover,
/// click to select, right-click (or two-finger click) to order, drag or
/// two-finger scroll to pan, pinch, Command-scroll or the mouse wheel to
/// zoom, and a two-finger twist or an Option-drag to turn and lean the view.
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
    /// The land under the view, for finding the hex under the pointer.
    var relief: Relief?
    /// The models standing in the world at a moment of the map's clock.
    var scene: ((Double, CGSize) -> SceneFrame)?
    /// Each House's colour by its sigil, linear.
    var houseColours: [Vec4] = []
    /// How much the map moves: still, it is drawn only when something
    /// changes; reduced, its clock runs slower, at 30 frames a second.
    var motion: ResolvedMotion = .full {
        didSet {
            guard motion != oldValue else { return }
            updateFrameRate()
            updatePausing()
        }
    }
    /// The display settings' frame rate cap.
    var frameRateCap: FrameRateCap = .sixty {
        didSet { if frameRateCap != oldValue { updateFrameRate() } }
    }
    /// The display settings' resolution: the most of the screen's pixels
    /// the map is drawn at.
    var quality: RenderQuality = .native {
        didSet { if quality != oldValue { updateDrawableSize() } }
    }
    /// The map's time, advanced at the motion's pace: it never jumps as
    /// motion slows or stops, a paused map redrawn shows the same moment,
    /// and it starts over on a whole number of the shader's cycles.
    private var clock = SceneClock()

    var onHover: ((Hex?) -> Void)?
    var onClick: ((Hex) -> Void)?
    var onSecondaryClick: ((Hex) -> Void)?
    var onCameraChange: ((Camera) -> Void)?
    var onFailure: (() -> Void)?

    private(set) var renderer: WorldRenderer?
    private var isLoadingRenderer = false
    private var pendingTiles: (bytes: [UInt8], side: Int)?
    private var pendingLand: (terrain: TerrainMesh, map: WorldMap)?
    private var landMap: WorldMap?
    private var tilesVersion = -1
    private var isWindowVisible = false
    private var occlusionObserver: (any NSObjectProtocol)?
    private var trackingArea: NSTrackingArea?
    private var appObservers: [any NSObjectProtocol] = []
    private var dragOrigin: CGPoint?
    private var dragged = false

    init() {
        super.init(frame: .zero, device: WorldMetalView.systemDevice)
        colorPixelFormat = .bgra8Unorm
        depthStencilPixelFormat = WorldRenderer.depthFormat
        sampleCount = WorldRenderer.sampleCount
        clearDepth = 1
        colorspace = CGColorSpace(name: CGColorSpace.sRGB)
        clearColor = WorldRenderer.night
        framebufferOnly = true
        autoResizeDrawable = false
        updateFrameRate()
        updatePausing()
    }

    required init(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    isolated deinit {
        stopWatchingWindow()
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
        let factor = backing * min(Self.renderScale(forCameraScale: camera.scale), quality.scale)
        let size = CGSize(width: max(1, (bounds.width * factor).rounded()), height: max(1, (bounds.height * factor).rounded()))
        if drawableSize != size {
            drawableSize = size
        }
        redraw()
    }

    override var isOpaque: Bool { true }
    override var acceptsFirstResponder: Bool { true }

    /// The land of the map, sent to the GPU once for each map.
    func setLand(_ terrain: TerrainMesh, for map: WorldMap) {
        guard map != landMap else { return }
        landMap = map
        if let renderer {
            do {
                try renderer.setLand(terrain, for: map)
            } catch {
                reportFailure("The world's land could not be sent to the GPU: \(error)")
            }
        } else {
            pendingLand = (terrain, map)
        }
        redraw()
    }

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
        stopWatchingWindow()
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

    /// The display settings' frame rate while the game is in front at full
    /// motion; 30 below full motion, behind another app, in Low Power Mode,
    /// or while the Mac runs hot: as the launcher's lake.
    func updateFrameRate() {
        let info = ProcessInfo.processInfo
        let savesEnergy = info.isLowPowerModeEnabled || [.serious, .critical].contains(info.thermalState)
        let inFront = NSApplication.shared.isActive
        let rate = frameRateCap.framesPerSecond(motion: motion, isSavingEnergy: !inFront || savesEnergy)
        if preferredFramesPerSecond != rate {
            preferredFramesPerSecond = rate
        }
    }

    private func updatePausing() {
        let running = renderer != nil && isWindowVisible && motion != .still
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

    private func stopWatchingWindow() {
        if let occlusionObserver {
            NotificationCenter.default.removeObserver(occlusionObserver)
            self.occlusionObserver = nil
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
        device.makeLibrary(source: WorldShaders.source, options: nil) { [weak self] library, error in
            DispatchQueue.main.async { [weak self] in
                self?.finishLoading(device: device, library: library, error: error, pixelFormat: pixelFormat)
            }
        }
    }

    func finishLoading(device: any MTLDevice, library: (any MTLLibrary)?, error: (any Error)?, pixelFormat: MTLPixelFormat) {
        isLoadingRenderer = false
        guard let library else {
            reportFailure("The world shader did not compile: \(error?.localizedDescription ?? "unknown error")")
            return
        }
        do {
            let renderer = try WorldRenderer(device: device, library: library, pixelFormat: pixelFormat)
            renderer.meshSource = WorldMetalView.meshSource
            if let pendingTiles {
                try renderer.updateTiles(pendingTiles.bytes, side: pendingTiles.side)
                self.pendingTiles = nil
            }
            if let pendingLand {
                try renderer.setLand(pendingLand.terrain, for: pendingLand.map)
                self.pendingLand = nil
            }
            self.renderer = renderer
            WorldMetalView.logger.notice("The world renders with Metal on \(device.name, privacy: .public).")
            Reporting.say("The world renders with Metal on \(device.name).")
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

    /// Where models' meshes come from: the library, each built once.
    static var meshSource: (ModelKey) -> NullmereModels.Mesh? = { Library.model($0).mesh }

    override func draw(_ dirtyRect: NSRect) {
        guard let renderer, renderer.hasTiles, let land = renderer.land,
              bounds.width > 0, bounds.height > 0,
              let pass = currentRenderPassDescriptor,
              let drawable = currentDrawable
        else { return }
        let pixelsPerPoint = drawableSize.width / bounds.width
        let time = clock.advance(to: CACurrentMediaTime(), rate: motion.clockRate)
        var frame = FrameUniforms.make(camera: camera, size: bounds.size, pixelsPerPoint: pixelsPerPoint, time: Float(time),
                                       motion: Float(motion.clockRate), radius: radius, terrain: land.terrain,
                                       hovered: hovered, selected: selected, houses: houseColours)
        let staged = scene?(time, bounds.size) ?? SceneFrame()
        frame.light(with: PointLight.strongest(staged.lights, near: camera.focus))
        frame.weather(staged.weather)
        renderer.draw(frame, scene: staged, in: pass, to: drawable)
    }

    // MARK: Input

    /// A point in the view, measured from the top left as the camera expects.
    private func point(of event: NSEvent) -> CGPoint {
        let local = convert(event.locationInWindow, from: nil)
        return CGPoint(x: local.x, y: bounds.height - local.y)
    }

    private func hex(of event: NSEvent) -> Hex {
        guard let relief else { return camera.hex(at: point(of: event), in: bounds.size) }
        return camera.hex(at: point(of: event), in: bounds.size, relief: relief)
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
            if event.modifierFlags.contains(.option) {
                // Option-drag turns the view across, and leans it up and down.
                moved.turn(by: -Double(event.deltaX) * 0.008)
                moved.lean(by: Double(event.deltaY) * 0.006)
            } else {
                moved.pan(dx: event.deltaX, dy: event.deltaY, in: bounds.size)
                moved.clamp(toRadius: radius)
            }
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
        if event.modifierFlags.contains(.option) {
            moved.lean(by: -Double(event.scrollingDeltaY) * (event.hasPreciseScrollingDeltas ? 0.004 : 0.04))
        } else if event.hasPreciseScrollingDeltas, !event.modifierFlags.contains(.command) {
            moved.pan(dx: event.scrollingDeltaX, dy: event.scrollingDeltaY, in: bounds.size)
        } else {
            let delta = event.hasPreciseScrollingDeltas ? event.scrollingDeltaY * 0.01 : event.scrollingDeltaY * 0.08
            moved.zoom(by: exp(delta), around: point(of: event), in: bounds.size)
        }
        moved.clamp(toRadius: radius)
        camera = moved
        onCameraChange?(moved)
    }

    override func magnify(with event: NSEvent) {
        pinch(by: 1 + event.magnification, around: point(of: event))
    }

    /// A twist of two fingers on the trackpad turns the world with them.
    override func rotate(with event: NSEvent) {
        twist(by: Double(event.rotation) * .pi / 180)
    }

    func twist(by angle: Double) {
        var moved = camera
        moved.turn(by: -angle)
        camera = moved
        onCameraChange?(moved)
    }

    /// A pinch on the trackpad: zooms about the point between the fingers.
    func pinch(by factor: Double, around point: CGPoint) {
        var moved = camera
        moved.zoom(by: factor, around: point, in: bounds.size)
        moved.clamp(toRadius: radius)
        camera = moved
        onCameraChange?(moved)
    }
}
