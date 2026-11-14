import Foundation
import NullmereModels

/// The sky over the Nullmere: where the moon hangs, and the haze of a view.
public enum Sky {
    /// Toward the moon: a touch east of north, two fifths of the way up
    /// the sky, so a view across the lake toward the north holds it in the
    /// water.
    public static let moon = Vec3(0.103, 0.669, -0.736).normalized
    public static let moonStrength: Float = 1.5

    /// The haze for a view: it begins a little past the middle of the view
    /// and thickens beyond, as thick as the hour's air (`density`, 1 for
    /// the night's).
    public static func haze(eyeDistance: Float, exposure: Float = 1, spacing: Float, density: Float = 1) -> Vec4 {
        Vec4(eyeDistance * 0.9, 0.9 / max(eyeDistance, 1) * density, exposure, spacing)
    }
}

/// The light the world is drawn in at an hour of its day: the sun or the
/// moon as its key light, the sky's and the ground's own light, the air
/// between the eye and what lies far off, the cloud over what has never
/// been seen, the sky itself, and how the picture is set down.
///
/// The world keeps a day of its own, most of it daylight: the land read in
/// full colour under a high sun, a short dusk, a night of bright moonlight
/// over the black lake, and a dawn. `night` is the night as the lake was
/// first made, value for value; every other hour is blended from the four
/// below.
public struct Daylight: Equatable, Sendable {
    /// Toward the key light, the sun by day and the moon by night, how
    /// strongly it lights what faces it, and its colour.
    public var key: Vec3
    public var keyStrength: Float
    public var keyColour: Vec3
    /// How much of the night's own is shown, 0 by day to 1 at night: the
    /// stars, the moon's face and its glow.
    public var night: Float
    /// The sky's light on what faces up, and the ground's on what faces
    /// down.
    public var skyLight: Vec3
    public var groundLight: Vec3
    /// The fill from the south-east on faces turned from the key light.
    public var fillColour: Vec3
    /// How bright the picture stands, 1 at night: what is lit of itself to
    /// mark something (a chosen hex's ring, a border, a chosen model's
    /// edge) is lit this many times over, to stand out by day as by night.
    public var level: Float
    /// How much of the filmic curve the picture is set down by: none at
    /// night, whose colours are kept as they are; all of it by day, whose
    /// sunlit whites would otherwise burn out.
    public var filmic: Float
    /// How strongly the key light outlines what stands against it.
    public var rim: Float
    /// The far air's colour, the most of it that ever lies over a thing,
    /// and how thick it lies, the night's being 1.
    public var hazeColour: Vec3
    public var hazeMost: Float
    public var hazeDensity: Float
    /// The cloud over what has never been seen: its own colour, and how
    /// much of the key light its hollows and its tops take.
    public var mistColour: Vec3
    public var mistHollows: Float
    public var mistTops: Float
    /// What is remembered but not watched: how much of its light it keeps,
    /// and how much of the cloud's colour lies over it.
    public var remembered: Float
    public var veil: Float
    /// The sky's colour overhead and along the horizon; black at night,
    /// whose sky is its stars.
    public var zenith: Vec3
    public var horizon: Vec3
    /// Toward the sun and how much of it shows in the sky; toward the moon
    /// and how much of its face shows.
    public var sun: Vec3
    public var sunShown: Float
    public var moon: Vec3
    public var moonShown: Float
    /// The colour of deep water looked straight down into.
    public var water: Vec3
    /// How far the land's slopes are stood upright before the key light
    /// falls on them (the low moon lit whole hillsides pale), and how much
    /// of the key light the land takes.
    public var landUpright: Float
    public var landKey: Float
    /// How brightly a hold's hearths light the ground about it.
    public var hearths: Float
    /// How brightly a lit window shows, and how much it flickers.
    public var windows: Float
    public var flicker: Float

    /// The night as the lake was made: the moon low in the north, the land
    /// dim and blue under it, a black sky full of stars.
    public static let night = Daylight(
        key: Sky.moon, keyStrength: Sky.moonStrength, keyColour: Vec3(0.56, 0.66, 0.92), night: 1,
        skyLight: Vec3(0.034, 0.044, 0.085), groundLight: Vec3(0.012, 0.013, 0.018), fillColour: Vec3(0.050, 0.062, 0.100),
        level: 1, filmic: 0, rim: 1,
        hazeColour: Vec3(0.0040, 0.0050, 0.0095), hazeMost: 0.85, hazeDensity: 1,
        mistColour: Vec3(0.0026, 0.0031, 0.0050), mistHollows: 0.0004, mistTops: 0.0072, remembered: 0.55, veil: 0.25,
        zenith: .zero, horizon: .zero,
        sun: Vec3(-0.62, -0.3, 0.35).normalized, sunShown: 0, moon: Sky.moon, moonShown: 1,
        water: Vec3(0.0004, 0.0006, 0.0012),
        landUpright: 0.7, landKey: 0.55, hearths: 1, windows: 1.55, flicker: 0.35)

    /// Full day: the sun high in the south-west, the land in its own
    /// colours, a pale blue air far off, white cloud over the unknown.
    public static let day = Daylight(
        key: Vec3(-0.55, 0.72, 0.42).normalized, keyStrength: 2.5, keyColour: Vec3(1.0, 0.96, 0.88), night: 0,
        skyLight: Vec3(0.30, 0.42, 0.66), groundLight: Vec3(0.20, 0.18, 0.13), fillColour: Vec3(0.16, 0.19, 0.25),
        level: 8, filmic: 1, rim: 0.12,
        hazeColour: Vec3(0.50, 0.66, 0.92), hazeMost: 0.5, hazeDensity: 0.32,
        mistColour: Vec3(0.46, 0.52, 0.64), mistHollows: 0.10, mistTops: 0.38, remembered: 0.72, veil: 0.05,
        zenith: Vec3(0.13, 0.32, 0.78), horizon: Vec3(0.62, 0.78, 1.0),
        sun: Vec3(-0.55, 0.72, 0.42).normalized, sunShown: 1, moon: Sky.moon, moonShown: 0,
        water: Vec3(0.006, 0.014, 0.024),
        landUpright: 0.2, landKey: 1, hearths: 0, windows: 0.8, flicker: 0)

    /// Dusk: the sun low in the west, long warm light and long shadows, a
    /// sky going to rose along the horizon, the first windows lit.
    public static let dusk = Daylight(
        key: Vec3(-0.86, 0.24, 0.12).normalized, keyStrength: 2.3, keyColour: Vec3(1.0, 0.62, 0.36), night: 0.25,
        skyLight: Vec3(0.20, 0.22, 0.36), groundLight: Vec3(0.10, 0.08, 0.07), fillColour: Vec3(0.08, 0.09, 0.15),
        level: 4, filmic: 1, rim: 0.3,
        hazeColour: Vec3(0.56, 0.42, 0.42), hazeMost: 0.5, hazeDensity: 0.4,
        mistColour: Vec3(0.30, 0.26, 0.34), mistHollows: 0.06, mistTops: 0.30, remembered: 0.66, veil: 0.06,
        zenith: Vec3(0.07, 0.11, 0.34), horizon: Vec3(0.95, 0.52, 0.30),
        sun: Vec3(-0.86, 0.24, 0.12).normalized, sunShown: 1, moon: Sky.moon, moonShown: 0.35,
        water: Vec3(0.004, 0.006, 0.014),
        landUpright: 0.35, landKey: 0.9, hearths: 0.6, windows: 1.4, flicker: 0.25)

    /// Dawn: the sun low in the east, the light cool and thin, the last
    /// stars going out.
    public static let dawn = Daylight(
        key: Vec3(0.84, 0.26, 0.2).normalized, keyStrength: 2.0, keyColour: Vec3(1.0, 0.74, 0.56), night: 0.3,
        skyLight: Vec3(0.19, 0.24, 0.38), groundLight: Vec3(0.09, 0.085, 0.08), fillColour: Vec3(0.07, 0.09, 0.14),
        level: 4, filmic: 1, rim: 0.3,
        hazeColour: Vec3(0.52, 0.50, 0.56), hazeMost: 0.5, hazeDensity: 0.45,
        mistColour: Vec3(0.32, 0.32, 0.40), mistHollows: 0.06, mistTops: 0.30, remembered: 0.66, veil: 0.06,
        zenith: Vec3(0.08, 0.14, 0.38), horizon: Vec3(0.92, 0.64, 0.48),
        sun: Vec3(0.84, 0.26, 0.2).normalized, sunShown: 1, moon: Sky.moon, moonShown: 0.3,
        water: Vec3(0.004, 0.007, 0.015),
        landUpright: 0.35, landKey: 0.9, hearths: 0.5, windows: 1.3, flicker: 0.25)

    /// The hours each of the four holds whole, round the dial; between
    /// them one runs into the next.
    static let dial: [(from: Float, to: Float, light: Daylight)] = [
        (from: 7.5, to: 16.5, light: .day), (from: 18, to: 18.6, light: .dusk),
        (from: 20, to: 4, light: .night), (from: 5.4, to: 6, light: .dawn),
    ]

    /// The light at an hour of the day, 0 to 24 and round again.
    public static func at(hour: Float) -> Daylight {
        let h = hour - 24 * (hour / 24).rounded(.down)
        func within(_ from: Float, _ to: Float) -> Bool { from <= to ? (h >= from && h <= to) : (h >= from || h <= to) }
        for (index, held) in dial.enumerated() {
            if within(held.from, held.to) { return held.light }
            let next = dial[(index + 1) % dial.count]
            if within(held.to, next.from) {
                let span = (next.from - held.to + 24).truncatingRemainder(dividingBy: 24)
                let gone = (h - held.to + 24).truncatingRemainder(dividingBy: 24)
                let t = gone / max(span, 0.0001)
                return held.light.mixed(with: next.light, t * t * (3 - 2 * t))
            }
        }
        return .day
    }

    /// This light run a part of the way (`t`, 0 to 1) into another. By day
    /// the key light is the sun, moving across the sky. Into the night and
    /// out of it the key light is one or the other, never between: the sun
    /// fades to nothing, then the moon comes up from nothing, so no shadow
    /// swings across the land.
    public func mixed(with other: Daylight, _ t: Float) -> Daylight {
        func m(_ a: Float, _ b: Float) -> Float { a + (b - a) * t }
        func m(_ a: Vec3, _ b: Vec3) -> Vec3 { a.mix(b, t) }
        var light = self
        if night >= 0.99 || other.night >= 0.99 {
            // The sun going down as the moon comes up, or the moon giving
            // way to the sun: each faint as it does.
            let first = t < 0.5
            light.key = first ? key : other.key
            light.keyStrength = (first ? keyStrength : other.keyStrength) * abs(1 - 2 * t)
            light.keyColour = first ? keyColour : other.keyColour
        } else {
            // The sun on its way across the sky: one light, moving.
            light.key = m(key, other.key).normalized
            light.keyStrength = m(keyStrength, other.keyStrength)
            light.keyColour = m(keyColour, other.keyColour)
        }
        light.night = m(night, other.night)
        light.skyLight = m(skyLight, other.skyLight)
        light.groundLight = m(groundLight, other.groundLight)
        light.fillColour = m(fillColour, other.fillColour)
        light.level = m(level, other.level)
        light.filmic = m(filmic, other.filmic)
        light.rim = m(rim, other.rim)
        light.hazeColour = m(hazeColour, other.hazeColour)
        light.hazeMost = m(hazeMost, other.hazeMost)
        light.hazeDensity = m(hazeDensity, other.hazeDensity)
        light.mistColour = m(mistColour, other.mistColour)
        light.mistHollows = m(mistHollows, other.mistHollows)
        light.mistTops = m(mistTops, other.mistTops)
        light.remembered = m(remembered, other.remembered)
        light.veil = m(veil, other.veil)
        light.zenith = m(zenith, other.zenith)
        light.horizon = m(horizon, other.horizon)
        light.sun = m(sun, other.sun).normalized
        light.sunShown = m(sunShown, other.sunShown)
        light.moon = other.moon
        light.moonShown = m(moonShown, other.moonShown)
        light.water = m(water, other.water)
        light.landUpright = m(landUpright, other.landUpright)
        light.landKey = m(landKey, other.landKey)
        light.hearths = m(hearths, other.hearths)
        light.windows = m(windows, other.windows)
        light.flicker = m(flicker, other.flicker)
        return light
    }

    /// How long the world's day lasts, in seconds: two hours, the same for
    /// every keeper, counted from the same moment everywhere.
    public static let dayLength: Double = 7200

    /// The hour of the world's day at a moment, in seconds since the
    /// reference date all keepers share. Most of the day is daylight: of
    /// its two hours, an hour and twenty minutes of day, eight minutes of
    /// dusk, twenty-four of night and eight of dawn.
    public static func hour(at seconds: Double) -> Float {
        let part = (seconds / dayLength) - (seconds / dayLength).rounded(.down)
        // Each stretch of the cycle, and the hours of the dial it runs through.
        let stretches: [(share: Double, from: Double, to: Double)] = [
            (share: 80.0 / 120, from: 7.5, to: 16.5), (share: 8.0 / 120, from: 16.5, to: 20),
            (share: 24.0 / 120, from: 20, to: 28), (share: 8.0 / 120, from: 28, to: 31.5),
        ]
        var gone = part
        for stretch in stretches {
            if gone <= stretch.share {
                let hour = stretch.from + (stretch.to - stretch.from) * gone / stretch.share
                return Float(hour.truncatingRemainder(dividingBy: 24))
            }
            gone -= stretch.share
        }
        return 7.5
    }

    /// The light at a moment of the world's day.
    public static func at(seconds: Double) -> Daylight { at(hour: hour(at: seconds)) }
}
