import NullmereModels

/// What every shader of the world knows for a frame. Matches
/// `FrameUniforms` in `WorldShaders.source`, field for field.
public struct FrameUniforms: Equatable, Sendable {
    public var viewProjection: Mat4
    public var inverseViewProjection: Mat4
    /// The eye's position, and the map's clock in seconds.
    public var eye: Vec4
    /// Toward the key light (the sun by day, the moon by night), and how
    /// strongly it lights what faces it.
    public var key: Vec4
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
    /// The world's own lights: four places and reaches, then their four colours.
    public var lights: (Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4, Vec4)
    /// The Still's calm, none to deepest (0 to 1); whether the moon casts
    /// shadows (1) or not (0); and a texel of its shadow map, in world units
    /// and in the map's own (see `MoonShadow`).
    public var still: Vec4 = .zero
    /// The key light's view and projection, from the world to its shadow
    /// map's clip space, where it casts shadows.
    public var shadow: Mat4 = .identity
    /// The hour's light, as `Daylight` has it. The key light's colour, and
    /// how much of the night's own shows (0 to 1).
    public var keyColour: Vec4 = .zero
    /// The sky's light, and how bright the picture stands (`Daylight.level`).
    public var skyLight: Vec4 = .zero
    /// The ground's light, and how much of the filmic curve sets the picture down.
    public var groundLight: Vec4 = .zero
    /// The fill's colour, and how strongly the key light outlines things.
    public var fillColour: Vec4 = .zero
    /// The far air's colour, and the most of it that lies over a thing.
    public var hazeColour: Vec4 = .zero
    /// The cloud's colour over the unknown, and how much of it veils what is remembered.
    public var mistColour: Vec4 = .zero
    /// The key light on the cloud's hollows and on its tops, and how much
    /// of its light what is remembered keeps.
    public var mist: Vec4 = .zero
    /// The sky overhead, and along the horizon.
    public var zenith: Vec4 = .zero
    public var horizon: Vec4 = .zero
    /// Toward the sun, and how much of it shows; toward the moon, and how
    /// much of its face shows.
    public var sun: Vec4 = .zero
    public var moonFace: Vec4 = .zero
    /// Deep water's colour.
    public var water: Vec4 = .zero
    /// How far the land's slopes are stood upright before the key light
    /// falls on them, how much of the key light the land takes, and how
    /// brightly hearths light the ground.
    public var land: Vec4 = .zero
    /// How brightly a lit window shows, and how much it flickers.
    public var glow: Vec4 = .zero

    public static let lightSlots = 4

    public init(viewProjection: Mat4 = .identity, eye: Vec4 = .zero, viewport: Vec4 = .zero,
                world: Vec4 = .zero, highlight: Vec4 = Vec4(999, 999, 999, 999), extent: Vec4 = .zero,
                haze: Vec4 = Vec4(30, 0.02, 1, 0.3), heights: Vec4 = .zero, daylight: Daylight = .night) {
        self.viewProjection = viewProjection
        self.inverseViewProjection = viewProjection.inverse ?? .identity
        self.eye = eye
        self.key = .zero
        self.viewport = viewport
        self.world = world
        self.highlight = highlight
        self.extent = extent
        self.haze = haze
        self.heights = heights
        self.lights = (.zero, .zero, .zero, .zero, .zero, .zero, .zero, .zero)
        light(by: daylight)
    }

    /// The frame lit as an hour of the day has it.
    public mutating func light(by daylight: Daylight) {
        func v(_ a: Vec3, _ w: Float) -> Vec4 { Vec4(a.x, a.y, a.z, w) }
        key = v(daylight.key, daylight.keyStrength)
        keyColour = v(daylight.keyColour, daylight.night)
        skyLight = v(daylight.skyLight, daylight.level)
        groundLight = v(daylight.groundLight, daylight.filmic)
        fillColour = v(daylight.fillColour, daylight.rim)
        hazeColour = v(daylight.hazeColour, daylight.hazeMost)
        mistColour = v(daylight.mistColour, daylight.veil)
        mist = Vec4(daylight.mistHollows, daylight.mistTops, daylight.remembered, 0)
        zenith = v(daylight.zenith, 0)
        horizon = v(daylight.horizon, 0)
        sun = v(daylight.sun, daylight.sunShown)
        moonFace = v(daylight.moon, daylight.moonShown)
        water = v(daylight.water, 0)
        land = Vec4(daylight.landUpright, daylight.landKey, daylight.hearths, 0)
        glow = Vec4(daylight.windows, daylight.flicker, 0, 0)
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

    /// The hour's light as the shaders read it, field by field.
    public var hourValues: [Vec4] {
        [keyColour, skyLight, groundLight, fillColour, hazeColour, mistColour, mist, zenith, horizon, sun, moonFace, water, land, glow]
    }

    /// The lights as the shaders read them.
    public var lightValues: [Vec4] {
        withUnsafeBytes(of: lights) { Array($0.bindMemory(to: Vec4.self)) }
    }

    public static func == (a: FrameUniforms, b: FrameUniforms) -> Bool {
        a.viewProjection == b.viewProjection && a.eye == b.eye && a.key == b.key && a.viewport == b.viewport
            && a.world == b.world && a.highlight == b.highlight && a.extent == b.extent && a.haze == b.haze
            && a.heights == b.heights && a.lightValues == b.lightValues && a.still == b.still
            && a.hourValues == b.hourValues
    }
}

/// Each House's colour as the world's shaders read it, in a square texture
/// of its own rather than among a frame's uniforms: a realm may seat a
/// thousand Houses and more, and a frame's uniforms go to the GPU with every
/// frame. A House's colour is at its sigil plus one, linear; texel zero is
/// no House's, and every texel no House has is grey.
public enum HousePalette {
    /// The texture's side: room for every House a tile can name.
    public static let side = 64
    /// The most Houses a palette holds, the first texel being no House's.
    public static let slots = side * side - 1
    /// A colour for ground no House holds, and for a slot no House has.
    public static let none = Vec4(0.6, 0.6, 0.6, 1)

    /// The texture's texels, four floats each, row by row: the Houses'
    /// colours by sigil, a texel on.
    public static func texels(_ houses: [Vec4]) -> [Float] {
        var texels = [Float](repeating: 0, count: side * side * 4)
        for slot in 0..<(side * side) {
            let colour = slot >= 1 && slot - 1 < houses.count ? houses[slot - 1] : none
            texels[slot * 4] = colour.x
            texels[slot * 4 + 1] = colour.y
            texels[slot * 4 + 2] = colour.z
            texels[slot * 4 + 3] = colour.w
        }
        return texels
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
    /// The first bit: `alwaysShown`. The second byte: one more than the
    /// people whose way a hold's work is built in (`WorldStage.peopleFlags`).
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
