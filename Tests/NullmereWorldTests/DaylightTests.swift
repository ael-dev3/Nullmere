import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The world's day: the light it is drawn in at each hour, the hours a
/// keeper's clock brings round, and how a frame carries the hour to the
/// shaders.
final class DaylightTests: XCTestCase {
    /// The night is the night as the lake was first made, value for value:
    /// a frame lit by it draws as every frame did before the day was made.
    func testTheNightIsTheNightAsTheLakeWasMade() {
        let night = Daylight.night
        XCTAssertEqual(night.key, Sky.moon)
        XCTAssertEqual(night.keyStrength, Sky.moonStrength)
        XCTAssertEqual(night.keyColour, Vec3(0.56, 0.66, 0.92), "The moon's own colour, as the shaders' kMoonColour")
        XCTAssertTrue(WorldShaders.source.contains("kMoonColour = float3(0.56, 0.66, 0.92);"))
        XCTAssertEqual(night.night, 1)
        XCTAssertEqual(night.level, 1)
        XCTAssertEqual(night.filmic, 0, "Its colours set down as they are")
        XCTAssertEqual(night.rim, 1)
        XCTAssertEqual(night.zenith, .zero, "Its sky is its stars")
        XCTAssertEqual(night.horizon, .zero)
        XCTAssertEqual(night.sunShown, 0)
        XCTAssertEqual(night.moonShown, 1)
        XCTAssertEqual(night.moon, Sky.moon)
        XCTAssertEqual(night.hazeDensity, 1)
        XCTAssertEqual(night.hazeMost, 0.85)
        XCTAssertEqual([night.landUpright, night.landKey, night.hearths, night.windows, night.flicker], [0.7, 0.55, 1, 1.55, 0.35])
        XCTAssertEqual([night.mistHollows, night.mistTops, night.remembered, night.veil], [0.0004, 0.0072, 0.55, 0.25])

        // A frame is lit by the night unless told another hour.
        let terrain = TerrainMesh(relief: Relief(map: WorldMap(radius: 8, fill: Tile(terrain: .greyfield))))
        func frame(_ daylight: Daylight?) -> FrameUniforms {
            let camera = Camera(), size = CGSize(width: 800, height: 600)
            guard let daylight else {
                return FrameUniforms.make(camera: camera, size: size, pixelsPerPoint: 2, time: 0, motion: 1, radius: 8, terrain: terrain,
                                          hovered: nil, selected: nil)
            }
            return FrameUniforms.make(camera: camera, size: size, pixelsPerPoint: 2, time: 0, motion: 1, radius: 8, terrain: terrain,
                                      hovered: nil, selected: nil, daylight: daylight)
        }
        let plain = frame(nil)
        XCTAssertEqual(plain, frame(.night))
        XCTAssertEqual(plain.key, Vec4(Sky.moon.x, Sky.moon.y, Sky.moon.z, Sky.moonStrength))
        XCTAssertEqual(plain.keyColour, Vec4(0.56, 0.66, 0.92, 1))
        XCTAssertEqual(plain.groundLight.w, 0)
        XCTAssertEqual(plain.haze, Sky.haze(eyeDistance: (Camera().eye(in: CGSize(width: 800, height: 600)) - Camera().focus).length,
                                            spacing: terrain.spacing))
        XCTAssertEqual(FrameUniforms().keyColour, Vec4(0.56, 0.66, 0.92, 1), "And a frame made of nothing is the night's too")

        // By day it carries the day: its sun, its sky, its thinner air.
        let day = frame(.day)
        XCTAssertNotEqual(day, plain)
        XCTAssertEqual(day.key, Vec4(Daylight.day.key.x, Daylight.day.key.y, Daylight.day.key.z, Daylight.day.keyStrength))
        XCTAssertEqual(day.keyColour.w, 0, "Nothing of the night")
        XCTAssertEqual(day.skyLight.w, Daylight.day.level)
        XCTAssertEqual(day.groundLight.w, 1, "Set down by the filmic curve")
        XCTAssertEqual(day.sun.w, 1)
        XCTAssertEqual(day.moonFace.w, 0)
        XCTAssertEqual(day.haze.y, plain.haze.y * Daylight.day.hazeDensity, accuracy: 1e-6)
        XCTAssertEqual(day.hourValues.count, 14)
        XCTAssertEqual(MemoryLayout<FrameUniforms>.offset(of: \FrameUniforms.keyColour), 464, "The hour's fields follow the shadow's")
        XCTAssertEqual(MemoryLayout<FrameUniforms>.offset(of: \FrameUniforms.glow), 464 + 13 * 16)
        for name in ["keyColour", "skyLight", "groundLight", "fillColour", "hazeColour", "mistColour", "mist", "zenith", "horizon", "sun",
                     "moonFace", "water", "land", "glow"] {
            XCTAssertTrue(WorldShaders.source.contains("    float4 \(name);"), "\(name) is the shaders' too")
        }
    }

    /// Each hour's light is a light to see by: the key light up in the sky,
    /// the day brighter than the dusk and the dusk than the night, and the
    /// day's land lit on its own slopes.
    func testEachHourIsLitFromAboveTheDayBrightest() {
        func brightness(_ light: Daylight) -> Float {
            // What ground facing straight up takes, in all: key, fill and sky.
            let key = light.keyColour * (max(light.key.y, 0) * light.keyStrength * light.landKey)
            let all = key + light.fillColour * 0.53 + light.skyLight
            return 0.2126 * all.x + 0.7152 * all.y + 0.0722 * all.z
        }
        for hour in stride(from: Float(0), to: 24, by: 0.05) {
            let light = Daylight.at(hour: hour)
            XCTAssertEqual(light.key.length, 1, accuracy: 1e-4, "\(hour)")
            XCTAssertGreaterThan(light.key.y, 0.2, "\(hour): the key light stands above the land")
            XCTAssertGreaterThanOrEqual(light.keyStrength, 0, "\(hour)")
            XCTAssertGreaterThan(brightness(light), 0.03, "\(hour): never dark")
        }
        XCTAssertGreaterThan(brightness(.day), 2 * brightness(.dusk))
        XCTAssertGreaterThan(brightness(.dusk), 1.2 * brightness(.night))
        XCTAssertGreaterThan(brightness(.dawn), 1.2 * brightness(.night))
        // The night is one of bright moonlight, read by: a quarter of the
        // day's light at the most, never a tenth of a tenth.
        XCTAssertGreaterThan(brightness(.day), 4 * brightness(.night), "The day is read in full light")
        XCTAssertLessThan(brightness(.day), 40 * brightness(.night), "and the night by the moon's")
        XCTAssertLessThan(Daylight.day.landUpright, Daylight.night.landUpright, "The day's sun falls on the land's own slopes")
        XCTAssertEqual(Daylight.day.hearths, 0, "No hearth glows on the ground under the sun")
        XCTAssertGreaterThan(Daylight.night.windows, Daylight.day.windows, "Windows are brightest at night")
        XCTAssertGreaterThan(Daylight.day.level, 4, "What marks the land is lit to stand out against the day")
    }

    /// The hours run into one another: nothing of the light jumps as the
    /// day goes round, and where the sun gives way to the moon each is
    /// faint as it does, so no shadow swings across the land.
    func testTheHoursRunIntoOneAnother() {
        XCTAssertEqual(Daylight.at(hour: 12), .day)
        XCTAssertEqual(Daylight.at(hour: 0), .night)
        XCTAssertEqual(Daylight.at(hour: 24), .night)
        XCTAssertEqual(Daylight.at(hour: 26), .night, "Round again")
        XCTAssertEqual(Daylight.at(hour: -1), .night)
        XCTAssertEqual(Daylight.at(hour: 18.3), .dusk)
        XCTAssertEqual(Daylight.at(hour: 5.7), .dawn)
        let step: Float = 0.01
        var before = Daylight.at(hour: 0)
        for index in 1...2400 {
            let hour = Float(index) * step
            let now = Daylight.at(hour: hour)
            XCTAssertEqual(now.level, before.level, accuracy: 0.2, "\(hour)")
            XCTAssertEqual(now.night, before.night, accuracy: 0.03, "\(hour)")
            XCTAssertEqual(now.filmic, before.filmic, accuracy: 0.03, "\(hour)")
            XCTAssertLessThan((now.skyLight - before.skyLight).length, 0.02, "\(hour)")
            XCTAssertLessThan((now.hazeColour - before.hazeColour).length, 0.03, "\(hour)")
            XCTAssertLessThan((now.zenith - before.zenith).length, 0.03, "\(hour)")
            // The key light's own light on the land never jumps, though the
            // light may change hands.
            let lit = now.keyColour * now.keyStrength, was = before.keyColour * before.keyStrength
            XCTAssertLessThan((lit - was).length, 0.12, "\(hour)")
            if (now.key - before.key).length > 0.1 {
                XCTAssertLessThan(now.keyStrength, 0.1, "\(hour): the key light changes hands only while faint")
                XCTAssertLessThan(before.keyStrength, 0.1, "\(hour)")
            }
            before = now
        }
    }

    /// The world's day is two hours long, the same for every keeper, and
    /// most of it is daylight.
    func testMostOfTheWorldsDayIsDaylight() {
        XCTAssertEqual(Daylight.dayLength, 7200)
        XCTAssertEqual(Daylight.hour(at: 0), 7.5, accuracy: 1e-4, "The day begins with the morning")
        XCTAssertEqual(Daylight.hour(at: Daylight.dayLength), 7.5, accuracy: 1e-4, "and comes round")
        XCTAssertEqual(Daylight.hour(at: 2400), 12, accuracy: 1e-3, "Noon, forty minutes in")
        XCTAssertEqual(Daylight.hour(at: -4800), Daylight.hour(at: 2400), accuracy: 1e-3, "Before the reference date as after it")
        var day = 0, night = 0, hours: [Float] = []
        for second in stride(from: 0, to: 7200, by: 10) {
            let hour = Daylight.hour(at: Double(second))
            XCTAssertTrue((0..<24).contains(hour), "\(second)")
            hours.append(hour)
            let light = Daylight.at(seconds: Double(second))
            if light == .day { day += 1 }
            if light == .night { night += 1 }
        }
        XCTAssertEqual(Double(day) / 720, 80.0 / 120, accuracy: 0.01, "Two thirds of it full day")
        XCTAssertEqual(Double(night) / 720, 24.0 / 120, accuracy: 0.01, "A fifth of it night")
        // The hours only go forward, but for the once they pass midnight.
        XCTAssertEqual(zip(hours, hours.dropFirst()).filter { $1 < $0 }.count, 1)
    }
}
