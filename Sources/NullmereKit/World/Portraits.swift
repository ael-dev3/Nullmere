import CoreGraphics
import Foundation
import Metal
import NullmereCore
import NullmereModels
import NullmereWorld

/// Portraits of the world's own models for the interface: a commander, a
/// company, a work, each drawn by the world's renderer on a small stage of
/// open ground under the moon, framed by its size, painted, and kept once
/// drawn.
/// Nil where Metal can't draw, and the interface does without.
@MainActor
@Observable
final class Portraits {
    static let shared = Portraits()

    /// Pixels a side.
    static let side = 112

    /// The stage is built: portraits asked for now are drawn. Watched, so
    /// a panel drawn before is drawn again with them.
    private(set) var isReady = false

    @ObservationIgnored private var stage: (renderer: WorldRenderer, target: WorldRenderer.Target)?
    @ObservationIgnored private var failed = false
    @ObservationIgnored private var compiling = false
    @ObservationIgnored private var kept: [String: CGImage] = [:]
    @ObservationIgnored private var vistaTarget: WorldRenderer.Target?

    /// Pixels across and down a hold's vista.
    static let vistaWidth = 360, vistaHeight = 150

    /// A model's portrait, its House's colour on what wears it; nil until
    /// the stage is built, which asking begins.
    func image(of key: ModelKey, colour: Vec4? = nil) -> CGImage? {
        let name = key.canonical.description + (colour.map { " \($0.x) \($0.y) \($0.z)" } ?? "")
        if let image = kept[name] { return image }
        guard stage != nil else {
            warm()
            return nil
        }
        guard let image = draw(key.canonical, colour: colour) else { return nil }
        kept[name] = image
        return image
    }

    /// A hold seen whole under the moon, from before its gate: its keep in
    /// its people's way, its walls and its works as they stand, in its
    /// House's colour. The head of its panel; nil until the stage is built.
    func vista(of hold: Hold, heritage: Heritage?, colour: Vec4) -> CGImage? {
        let levels = hold.levels.filter { $0.value > 0 }.map { "\($0.key.rawValue) \($0.value)" }.sorted().joined(separator: ",")
        let name = "vista \(hold.isSeat) \(levels) \(heritage?.rawValue ?? "-") \(colour.x) \(colour.y) \(colour.z)"
        if let image = kept[name] { return image }
        guard stage != nil else {
            warm()
            return nil
        }
        guard let image = drawVista(of: hold, heritage: heritage, colour: colour) else { return nil }
        kept[name] = image
        return image
    }

    /// Where to look from, to see a hold of these bounds whole in a picture
    /// wider than it is tall: from before it, a little to one side and above.
    static func vistaFraming(low: Vec3, high: Vec3, aspect: Float) -> (eye: Vec3, target: Vec3) {
        let target = (low + high) / 2
        let fov = Float(Camera.fieldOfView)
        let wide = 2 * atan(tan(fov / 2) * aspect)
        let across = max(high.x - low.x, high.z - low.z), tall = high.y - low.y
        let distance = max(across / 2 / tan(wide / 2), tall / 2 / tan(fov / 2)) * 1.05
        let direction = Vec3(sin(0.45) * cos(0.6), sin(0.6), cos(0.45) * cos(0.6))
        return (target + direction * distance, target)
    }

    private func drawVista(of hold: Hold, heritage: Heritage?, colour: Vec4) -> CGImage? {
        guard let (renderer, _) = stage, let land = renderer.land else { return nil }
        if vistaTarget == nil { vistaTarget = try? renderer.makeTarget(width: Portraits.vistaWidth, height: Portraits.vistaHeight) }
        guard let target = vistaTarget else { return nil }
        // Raised on the stage's own ground, its gate toward the eye.
        var plan = HoldLayout.Plan(hold: hold, heritage: heritage)
        plan.hex = Hex(0, 0)
        plan.rising = nil
        let relief = Relief(map: land.map)
        let pieces = HoldLayout.pieces(plan, relief: relief) + HoldLayout.town(plan, relief: relief)
        var scene = SceneFrame()
        var order: [ModelKey] = []
        var instances: [ModelKey: [ModelInstance]] = [:]
        var low = Vec3(repeating: .greatestFiniteMagnitude), high = Vec3(repeating: -.greatestFiniteMagnitude)
        for piece in pieces {
            let model = Library.model(piece.key)
            let palette = model.rig.count > 1 ? scene.add(pose: model.pose(.idle, at: 0.5)) : 0
            let flags = 1 | (WorldStage.isPeoples(piece.key) ? WorldStage.peopleFlags(heritage) : 0)
            if instances[piece.key] == nil { order.append(piece.key) }
            instances[piece.key, default: []].append(ModelInstance(model: piece.transform, colour: colour, rise: WorldStage.whole,
                                                                   palette: palette, flags: flags))
            for corner in [model.mesh.bounds.min, model.mesh.bounds.max] {
                let at = piece.transform.transformPoint(corner)
                low = pointwiseMin(low, at)
                high = pointwiseMax(high, at)
            }
        }
        guard !order.isEmpty else { return nil }
        scene.batches = order.map { ModelBatch(key: $0, instances: instances[$0] ?? []) }
        let aspect = Float(Portraits.vistaWidth) / Float(Portraits.vistaHeight)
        let (eye, look) = Portraits.vistaFraming(low: low, high: high, aspect: aspect)
        let size = CGSize(width: Portraits.vistaWidth, height: Portraits.vistaHeight)
        var frame = FrameUniforms.make(camera: Camera(), size: size, pixelsPerPoint: 1, time: 2, motion: 0, radius: land.map.radius,
                                       terrain: land.terrain, hovered: nil, selected: nil, houses: [], exposure: 1.5)
        let distance = (eye - look).length
        frame.viewProjection = Mat4.perspective(fovY: Float(Camera.fieldOfView), aspect: aspect, near: distance * 0.05, far: distance * 6)
            * Mat4.lookAt(eye: eye, target: look)
        frame.eye = Vec4(eye.x, eye.y, eye.z, 2)
        frame.haze.y = 0
        guard var bytes = renderer.pixels(frame, scene: scene, into: target) else { return nil }
        Painting.paint(bgra: &bytes, width: Portraits.vistaWidth, height: Portraits.vistaHeight)
        return Portraits.image(bgra: bytes, width: Portraits.vistaWidth, height: Portraits.vistaHeight)
    }

    /// Begins building the stage, its shaders compiled away from the main thread.
    func warm() {
        guard stage == nil, !failed, !compiling else { return }
        guard let device = MTLCreateSystemDefaultDevice() else {
            failed = true
            return
        }
        compiling = true
        device.makeLibrary(source: WorldShaders.source, options: nil) { [weak self] library, _ in
            DispatchQueue.main.async { [weak self] in
                self?.build(device: device, library: library)
            }
        }
    }

    /// Builds the stage at once, its shaders compiled here: for tests, and
    /// for a first look that can wait. Whether it is built.
    @discardableResult
    func prepareNow() -> Bool {
        if stage != nil { return true }
        guard !failed, let device = MTLCreateSystemDefaultDevice() else { return false }
        build(device: device, library: try? device.makeLibrary(source: WorldShaders.source, options: nil))
        return stage != nil
    }

    /// The stage: a renderer with a little land of open ground, all of it
    /// watched, and somewhere away from the screen to draw.
    private func build(device: any MTLDevice, library: (any MTLLibrary)?) {
        compiling = false
        guard stage == nil else { return }
        guard let library else {
            failed = true
            return
        }
        do {
            let renderer = try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm)
            renderer.meshSource = { Library.model($0).mesh }
            let map = WorldMap(radius: 2, fill: Tile(terrain: .greyfield))
            try renderer.setLand(TerrainMesh(relief: Relief(map: map)), for: map)
            let ground = TileTexture.Ground(map: map)
            var bytes = ground.bytes
            for offset in ground.offsets { bytes[offset + 3] = 32 }
            try renderer.updateTiles(bytes, side: TileTexture.side(for: map))
            stage = (renderer, try renderer.makeTarget(width: Portraits.side, height: Portraits.side))
            isReady = true
        } catch {
            failed = true
        }
    }

    /// Where to look from, to frame a model of these bounds standing on
    /// ground at `height`: a little above and to one side, near enough
    /// that it fills most of the picture.
    static func framing(low: Vec3, high: Vec3, ground height: Float) -> (eye: Vec3, target: Vec3) {
        let middle = (low + high) / 2
        let target = Vec3(middle.x, height + middle.y, middle.z)
        let extent = max((high.y - low.y) / 2, max(high.x - low.x, high.z - low.z) / 2, 0.02)
        let distance = extent / tan(Float(Camera.fieldOfView) / 2) * 1.35
        let direction = Vec3(sin(0.6) * cos(0.38), sin(0.38), cos(0.6) * cos(0.38))
        return (target + direction * distance, target)
    }

    private func draw(_ key: ModelKey, colour: Vec4?) -> CGImage? {
        guard let (renderer, target) = stage, let land = renderer.land else { return nil }
        let mesh = Library.model(key).mesh
        guard let first = mesh.vertices.first?.position else { return nil }
        var low = first, high = first
        for vertex in mesh.vertices {
            low = pointwiseMin(low, vertex.position)
            high = pointwiseMax(high, vertex.position)
        }
        let height = Relief(map: land.map).height(atX: 0, z: 0)
        let (eye, look) = Portraits.framing(low: low, high: high, ground: height)
        let size = CGSize(width: Portraits.side, height: Portraits.side)
        var frame = FrameUniforms.make(camera: Camera(), size: size, pixelsPerPoint: 1, time: 2, motion: 0, radius: land.map.radius,
                                       terrain: land.terrain, hovered: nil, selected: nil, houses: [], exposure: 1.5)
        let distance = (eye - look).length
        frame.viewProjection = Mat4.perspective(fovY: Float(Camera.fieldOfView), aspect: 1, near: distance * 0.05, far: distance * 6)
            * Mat4.lookAt(eye: eye, target: look)
        frame.eye = Vec4(eye.x, eye.y, eye.z, 2)
        frame.haze.y = 0
        let instance = ModelInstance(model: .translation(Vec3(0, height, 0)), colour: colour ?? .zero, flags: 1)
        let scene = SceneFrame(batches: [ModelBatch(key: key, instances: [instance])])
        guard var bytes = renderer.pixels(frame, scene: scene, into: target) else { return nil }
        Painting.paint(bgra: &bytes, width: Portraits.side, height: Portraits.side)
        return Portraits.image(bgra: bytes, side: Portraits.side)
    }

    /// An image of pixels in the renderer's order (blue, green, red, alpha).
    static func image(bgra bytes: [UInt8], side: Int) -> CGImage? {
        image(bgra: bytes, width: side, height: side)
    }

    static func image(bgra bytes: [UInt8], width: Int, height: Int) -> CGImage? {
        guard bytes.count == width * height * 4, let provider = CGDataProvider(data: Data(bytes) as CFData) else { return nil }
        return CGImage(width: width, height: height, bitsPerComponent: 8, bitsPerPixel: 32, bytesPerRow: width * 4,
                       space: CGColorSpace(name: CGColorSpace.sRGB) ?? CGColorSpaceCreateDeviceRGB(),
                       bitmapInfo: CGBitmapInfo(rawValue: CGBitmapInfo.byteOrder32Little.rawValue | CGImageAlphaInfo.premultipliedFirst.rawValue),
                       provider: provider, decode: nil, shouldInterpolate: true, intent: .defaultIntent)
    }
}

import SwiftUI

/// A model's portrait in a panel: for the eye alone, the words beside it
/// saying what it is.
struct Portrait: View {
    let key: ModelKey
    var colour: Vec4?
    var size: CGFloat = 40

    var body: some View {
        // Read, so the portrait is drawn again once the stage is built.
        let _ = Portraits.shared.isReady
        ZStack {
            RoundedRectangle(cornerRadius: 3).fill(Palette.panel.opacity(0.6))
            if let image = Portraits.shared.image(of: key, colour: colour) {
                Image(decorative: image, scale: CGFloat(Portraits.side) / size)
                    .resizable()
                    .interpolation(.high)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: 3))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.line(0.25), lineWidth: 0.5))
        .accessibilityHidden(true)
    }

    /// A hold's vista at the head of its panel: for the eye alone.
    struct Vista: View {
        let hold: Hold
        let state: GameState

        var body: some View {
            // Read, so the vista is drawn again once the stage is built.
            let _ = Portraits.shared.isReady
            if let colour = Portrait.colour(of: hold.owner, in: state),
               let image = Portraits.shared.vista(of: hold, heritage: state.heritage(of: hold.owner), colour: colour) {
                Image(decorative: image, scale: 1)
                    .resizable()
                    .interpolation(.high)
                    .aspectRatio(CGFloat(Portraits.vistaWidth) / CGFloat(Portraits.vistaHeight), contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: 5))
                    .overlay(RoundedRectangle(cornerRadius: 5).strokeBorder(Palette.line(0.25), lineWidth: 0.5))
                    .accessibilityHidden(true)
            }
        }
    }

    /// A House's colour as the world draws it.
    @MainActor
    static func colour(of house: Int, in state: GameState) -> Vec4? {
        guard state.houses.indices.contains(house) else { return nil }
        return WorldStage.colour(WorldView.houseColours, sigil: state.houses[house].sigil)
    }
}
