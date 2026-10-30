import NullmereModels

/// What every shader of the world knows for a frame. Matches
/// `FrameUniforms` in `WorldShaders.source`, field for field.
public struct FrameUniforms: Equatable, Sendable {
    public var viewProjection: Mat4
    public var inverseViewProjection: Mat4
    /// The eye's position, and the map's clock in seconds.
    public var eye: Vec4
    /// Toward the moon, and how strongly it lights the land.
    public var moon: Vec4
    /// The drawable's width and height in pixels, and their reciprocals.
    public var viewport: Vec4
    /// The map's radius, the tile texture's side, pixels per world unit at
    /// the middle of the view, and how much the world moves (0 still, 1 full).
    public var world: Vec4
    /// The hovered hex's q and r, the chosen hex's; 999 for none.
    public var highlight: Vec4
    /// The terrain mesh's corner (x, z) and its far corner (x, z), for the water.
    public var extent: Vec4
    /// Where the night's haze begins (distance from the eye), how thick it
    /// grows, the exposure, and the heights grid's spacing.
    public var haze: Vec4
    /// The heights grid's corner (x, z) and its columns and rows.
    public var heights: Vec4
    /// Each House's colour, by its sigil plus one, linear.
    public var houses: (Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4)
    /// The world's own lights: four places and reaches, then their four colours.
    public var lights: (Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4)

    public static let houseSlots = 16
    public static let lightSlots = 4

    public init(viewProjection: Mat4 = .identity, eye: Vec4 = .zero, moon: Vec4 = .zero, viewport: Vec4 = .zero,
                world: Vec4 = .zero, highlight: Vec4 = Vec4(999, 999, 999, 999), extent: Vec4 = .zero,
                haze: Vec4 = Vec4(30, 0.02, 1, 0.3), heights: Vec4 = .zero, houses: [Vec4] = []) {
        self.viewProjection = viewProjection
        self.inverseViewProjection = viewProjection.inverse ?? .identity
        self.eye = eye
        self.moon = moon
        self.viewport = viewport
        self.world = world
        self.highlight = highlight
        self.extent = extent
        self.haze = haze
        self.heights = heights
        var slots = [Vec4](repeating: Vec4(0.6, 0.6, 0.6, 1), count: FrameUniforms.houseSlots)
        for (index, colour) in houses.prefix(FrameUniforms.houseSlots).enumerated() { slots[index] = colour }
        self.houses = (slots[0], slots[1], slots[2], slots[3], slots[4], slots[5], slots[6], slots[7],
                       slots[8], slots[9], slots[10], slots[11], slots[12], slots[13], slots[14], slots[15])
        self.lights = (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
    }

    /// Lit by up to four of the world's own lights; the rest dark.
    public mutating func light(with lights: [PointLight]) {
        var slots = [Vec4](repeating: .zero, count: 2 * FrameUniforms.lightSlots)
        for (index, light) in lights.prefix(FrameUniforms.lightSlots).enumerated() {
            slots[index] = Vec4(light.position.x, light.position.y, light.position.z, light.reach)
            slots[index + FrameUniforms.lightSlots] = Vec4(light.colour.x, light.colour.y, light.colour.z, 0)
        }
        self.lights = (slots[0], slots[1], slots[2], slots[3], slots[4], slots[5], slots[6], slots[7])
    }

    /// The lights as the shaders read them.
    public var lightValues: [Vec4] {
        withUnsafeBytes(of: lights) { Array($0.bindMemory(to: Vec4.self)) }
    }

    public static func == (a: FrameUniforms, b: FrameUniforms) -> Bool {
        a.viewProjection == b.viewProjection && a.eye == b.eye && a.moon == b.moon && a.viewport == b.viewport
            && a.world == b.world && a.highlight == b.highlight && a.extent == b.extent && a.haze == b.haze
            && a.heights == b.heights && a.houseColours == b.houseColours && a.lightValues == b.lightValues
    }

    public var houseColours: [Vec4] {
        withUnsafeBytes(of: houses) { Array($0.bindMemory(to: Vec4.self)) }
    }
}

/// One model drawn in the world. Matches `ModelInstance` in
/// `WorldShaders.source`: 112 bytes.
public struct ModelInstance: Equatable, Sendable {
    public var model: Mat4
    /// The owning House's colour, linear; alpha 1 if it has one.
    public var colour: Vec4
    /// How far it has risen (1 whole), how much it shows (1 fully), when
    /// its sway and flicker begin, and how it is singled out (1 chosen,
    /// 0.5 under the pointer).
    public var params: Vec4
    /// The hex it stands in, for what the keeper knows of it.
    public var hex: SIMD2<Int32>
    /// Where its parts' transforms begin in the frame's palette.
    public var palette: UInt32
    public var flags: UInt32

    /// Shown whatever the keeper knows of its hex: the keeper's own.
    public static let alwaysShown: UInt32 = 1

    public init(model: Mat4, colour: Vec4 = .zero, rise: Float = 1, opacity: Float = 1, phase: Float = 0, emphasis: Float = 0,
                hex: SIMD2<Int32> = .zero, palette: UInt32 = 0, flags: UInt32 = 0) {
        self.model = model
        self.colour = colour
        self.params = Vec4(rise, opacity, phase, emphasis)
        self.hex = hex
        self.palette = palette
        self.flags = flags
    }
}
