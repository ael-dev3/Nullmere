import Foundation
import NullmereCore
import NullmereModels
@testable import NullmereWorld
import XCTest

/// The motes the world throws up and the lights it gives: worked out
/// afresh each frame from what threw them and when, so a moment drawn
/// twice is drawn alike; each kind moving as it should, and gone in time.
final class EffectsTests: XCTestCase {
    private func positions(_ motes: [Mote]) -> [Vec3] { motes.map { Vec3($0.place.x, $0.place.y, $0.place.z) } }

    func testAMomentIsDrawnAlikeEveryTime() {
        let bursts = Effect.allCases.enumerated().map { Burst($1, at: Vec3(Float($0), 0, 0), start: 1, count: 6, seed: 42) }
        let emitters = [Emitter(.smoke, at: .zero, rate: 5, seed: 7), Emitter(.fireflies, at: Vec3(2, 0, 2), rate: 0.6, seed: 9)]
        let a = Effects.motes(bursts: bursts, emitters: emitters, at: 1.2)
        let b = Effects.motes(bursts: bursts, emitters: emitters, at: 1.2)
        XCTAssertEqual(a, b)
        XCTAssertFalse(a.isEmpty)
        XCTAssertNotEqual(a, Effects.motes(bursts: bursts, emitters: emitters, at: 1.25), "and moves on")
    }

    func testABurstIsGoneOnceItsMotesAreSpent() {
        for effect in Effect.allCases {
            let burst = Burst(effect, at: .zero, start: 10, count: 20, seed: 3)
            XCTAssertTrue(Effects.motes(bursts: [burst], emitters: [], at: 9.9).isEmpty, "\(effect): nothing before it begins")
            XCTAssertFalse(Effects.motes(bursts: [burst], emitters: [], at: 10.05).isEmpty, "\(effect): seen as it begins")
            XCTAssertTrue(Effects.motes(bursts: [burst], emitters: [], at: 10 + effect.lifetime * 1.36).isEmpty, "\(effect): gone after")
            XCTAssertFalse(burst.isAlive(at: 10 + effect.lifetime * 1.36))
        }
    }

    func testEachKindMovesAsItShould() {
        let origin = Vec3(1, 0.5, -2)
        // Sparks fly up and out, then fall.
        let sparks = Burst(.sparks, at: origin, start: 0, count: 30, seed: 5)
        let early = positions(Effects.motes(bursts: [sparks], emitters: [], at: 0.08))
        let late = positions(Effects.motes(bursts: [sparks], emitters: [], at: 0.28))
        XCTAssertGreaterThan(early.map(\.y).max() ?? 0, origin.y, "up")
        XCTAssertGreaterThan(early.map { ($0 - origin).length }.max() ?? 0, 0.1, "and out")
        let peak = (0..<20).map { step in positions(Effects.motes(bursts: [sparks], emitters: [], at: Float(step) * 0.02)).map(\.y).reduce(0, +) }
        XCTAssertLessThan(peak.last ?? 0, peak.max() ?? 0, "then falling")
        XCTAssertTrue(Effects.motes(bursts: [sparks], emitters: [], at: 0.1).allSatisfy { $0.colour.w == 0 }, "sparks are light, hiding nothing")
        _ = late
        // Smoke rises and spreads; dust settles low and hides what is behind it.
        let smoke = Emitter(.smoke, at: origin, rate: 6, seed: 2)
        let plume = Effects.motes(bursts: [], emitters: [smoke], at: 20)
        XCTAssertGreaterThan(plume.map(\.place.y).max() ?? 0, origin.y + 0.8, "risen high")
        XCTAssertGreaterThan(plume.map(\.place.w).max() ?? 0, plume.map(\.place.w).min() ?? 1, "the oldest the widest")
        let dust = Effects.motes(bursts: [Burst(.dust, at: origin, start: 0, count: 12, seed: 8)], emitters: [], at: 0.6)
        XCTAssertTrue(dust.allSatisfy { $0.place.y < origin.y + 0.4 && $0.colour.w > 0 }, "dust keeps low and hides")
        // Splinters never fall through the ground they were knocked onto.
        let chips = Effects.motes(bursts: [Burst(.splinters, at: origin, start: 0, count: 16, seed: 4)], emitters: [], at: 0.7)
        XCTAssertTrue(chips.allSatisfy { $0.place.y >= origin.y - 0.021 })
        // A flash: one swell of light where the blow lands.
        let flash = Effects.motes(bursts: [Burst(.flash, at: origin, start: 0, count: 1, seed: 1)], emitters: [], at: 0.12)
        XCTAssertEqual(flash.count, 1)
        XCTAssertGreaterThan(flash[0].colour.x, 0.5)
        // Embers rise from their fire.
        let embers = Effects.motes(bursts: [], emitters: [Emitter(.embers, at: origin, rate: 20, seed: 6)], at: 30)
        XCTAssertGreaterThan(embers.map(\.place.y).reduce(0, +) / Float(max(embers.count, 1)), origin.y)
    }

    func testAnEmitterKeepsAsteadyCountAndFirefliesStayByTheirReeds() {
        let smoke = Emitter(.smoke, at: .zero, rate: 5, seed: 11)
        let counts = stride(from: Float(30), to: 40, by: 0.7).map { Effects.motes(bursts: [], emitters: [smoke], at: $0).count }
        // Each lives 0.65 to 1.35 of its kind's life, so the count varies about rate × life.
        XCTAssertTrue(counts.allSatisfy { $0 >= 8 && $0 <= 30 }, "\(counts)")
        let reeds = Vec3(4, 0.1, 4)
        let flies = Emitter(.fireflies, at: reeds, rate: 0.6, spread: 0.3, seed: 12)
        for moment in stride(from: Float(100), to: 110, by: 1.3) {
            for mote in Effects.motes(bursts: [], emitters: [flies], at: moment) {
                let p = Vec3(mote.place.x, mote.place.y, mote.place.z)
                XCTAssertLessThan(Vec3(p.x - reeds.x, 0, p.z - reeds.z).length, 0.8)
                XCTAssertGreaterThan(p.y, reeds.y, "over them")
            }
        }
        XCTAssertTrue(Effects.motes(bursts: [], emitters: [Emitter(.dust, at: .zero, rate: 0, seed: 1)], at: 5).isEmpty)
        // However many burn at once, the frame keeps to its most.
        let many = (0..<400).map { Emitter(.embers, at: Vec3(Float($0), 0, 0), rate: 30, seed: UInt32($0)) }
        XCTAssertLessThanOrEqual(Effects.motes(bursts: [], emitters: many, at: 50).count, Effects.most)
    }

    func testWhatHappensInSightThrowsUpMotesAndLight() {
        var happenings = Happenings()
        happenings.strikes = [Happenings.Strike(from: Vec3(0, 0, 0), at: Vec3(1.7, 0, 0), start: 10, ranged: false, seed: 1),
                              Happenings.Strike(from: Vec3(0, 0, 3), at: Vec3(3.4, 0, 3), start: 10, ranged: true, seed: 2),
                              Happenings.Strike(from: Vec3(0, 0, 6), at: Vec3(1.7, 0, 6), start: 10, ranged: false, onWard: true, seed: 3)]
        happenings.falls = [Happenings.Spot(at: Vec3(5, 0, 5), start: 10, seed: 4)]
        happenings.marching = [Happenings.Spot(at: Vec3(-3, 0, 0), seed: 5)]
        happenings.rising = [Happenings.Spot(at: Vec3(-5, 0, 0), seed: 6)]
        happenings.finished = [Happenings.Spot(at: Vec3(-7, 0, 0), start: 10, seed: 7)]
        happenings.blazes = [Happenings.Spot(at: Vec3(8, 0.2, 8), strength: 0.8, seed: 8)]
        happenings.fireflies = [Happenings.Spot(at: Vec3(-9, 0.1, -9), seed: 9)]
        happenings.furies = [Happenings.Spot(at: Vec3(12, 0, 12), start: 10, seed: 10)]
        let landing = 10 + Happenings.landing + 0.05
        let (motes, lights) = happenings.effects(at: landing)
        XCTAssertFalse(motes.isEmpty)
        // The blows on companies and the ward light the ground, a commander's fury too, and the fire burns.
        XCTAssertEqual(lights.count, 4)
        // The fury's ring of gold round its company.
        let ring = motes.filter { Vec3($0.place.x, 0, $0.place.z).length > 15 && $0.colour.w == 0 }
        XCTAssertGreaterThan(ring.count, 10)
        XCTAssertTrue(ring.allSatisfy { $0.place.y > -0.01 }, "over the ground")
        XCTAssertTrue(motes.contains { $0.colour.w == 0 && $0.colour.x > 1 }, "sparks")
        // Near the fire: embers above it.
        XCTAssertTrue(motes.contains { $0.place.x > 7.5 && $0.place.y > 0.9 })
        // A moment later the blows' and the fury's light is gone; the fire's is not.
        XCTAssertEqual(happenings.effects(at: landing + 1).lights.count, 1)
        // The arrows' dust comes down after their flight.
        let flight = Happenings(strikes: [happenings.strikes[1]])
        XCTAssertTrue(flight.effects(at: 10.2).motes.isEmpty)
        XCTAssertFalse(flight.effects(at: 10 + Happenings.arrowFlight + 0.1).motes.isEmpty)
        // The fallen raise their dust as they meet the ground.
        let fall = Happenings(falls: happenings.falls)
        XCTAssertTrue(fall.effects(at: 10.3).motes.isEmpty)
        XCTAssertFalse(fall.effects(at: 10 + Happenings.fallen + 0.1).motes.isEmpty)
    }

    func testABattleGoingOnRaisesItsDustOverItsField() {
        let heart = Vec3(2, 0.1, -3)
        let thick = Happenings(battles: [Happenings.Spot(at: heart, strength: 8, seed: 31)]).effects(at: 20).motes
        XCTAssertGreaterThan(thick.count, 10)
        XCTAssertTrue(thick.allSatisfy { Vec3($0.place.x - heart.x, 0, $0.place.z - heart.z).length < 2 }, "Over its field")
        XCTAssertTrue(thick.allSatisfy { $0.place.y >= heart.y - 0.01 }, "Raised from the ground")
        let thin = Happenings(battles: [Happenings.Spot(at: heart, strength: 1, seed: 31)]).effects(at: 20).motes
        XCTAssertLessThan(thin.count, thick.count, "The thicker the more companies stand in it")
        XCTAssertTrue(Happenings(battles: [Happenings.Spot(at: heart, strength: 8, seed: 31)]).effects(at: 20).lights.isEmpty)
    }

    func testAScoutedHoldIsCircledByItsLanternsLight() {
        var happenings = Happenings()
        happenings.sightings = [Happenings.Spot(at: Vec3(4, 0.3, -2), start: 10, seed: 21)]
        XCTAssertTrue(happenings.effects(at: 9.5).motes.isEmpty, "Not before it is scouted")
        let (motes, lights) = happenings.effects(at: 10.6)
        XCTAssertGreaterThan(motes.count, 8)
        for mote in motes {
            let off = Vec3(mote.place.x - 4, 0, mote.place.z + 2).length
            XCTAssertTrue((0.3...0.9).contains(off), "Round the hold, not on it: \(off)")
            XCTAssertGreaterThan(mote.place.y, 0.3 + 0.15, "Over its walls")
            XCTAssertGreaterThan(mote.colour.z, mote.colour.x, "A cold light")
            XCTAssertEqual(mote.colour.w, 0)
        }
        XCTAssertEqual(lights.count, 1)
        XCTAssertGreaterThan(lights[0].colour.z, lights[0].colour.x)
        XCTAssertTrue(happenings.effects(at: 10 + Happenings.sightingGlow + 0.05).lights.isEmpty, "Its glow gone")
        XCTAssertTrue(happenings.effects(at: 10 + Effect.sighting.lifetime * 1.4).motes.isEmpty, "And its motes")
    }

    func testTheStrongestLightsNearTheEyeAreTheFramesFour() {
        let lights = (0..<9).map { PointLight(at: Vec3(Float($0) * 3, 0, 0), reach: 2, colour: Vec3(1, 0.5, 0.2)) }
        let chosen = PointLight.strongest(lights, near: .zero)
        XCTAssertEqual(chosen.count, FrameUniforms.lightSlots)
        XCTAssertEqual(chosen.first?.position, .zero, "the nearest first")
        XCTAssertTrue(PointLight.strongest([PointLight(at: .zero, reach: 2, colour: .zero)], near: .zero).isEmpty, "a dark one is none")
        var frame = FrameUniforms()
        frame.light(with: chosen)
        XCTAssertEqual(frame.lightValues.count, 8)
        XCTAssertEqual(frame.lightValues[1], Vec4(3, 0, 0, 2))
        XCTAssertEqual(frame.lightValues[4], Vec4(1, 0.5, 0.2, 0))
        XCTAssertNotEqual(frame, FrameUniforms(), "lights tell frames apart")
        frame.light(with: [])
        XCTAssertEqual(frame.lightValues, [Vec4](repeating: .zero, count: 8))
    }

    func testAClipEasesIntoTheNext() {
        let key = ModelKey.figure(.spear, tier: 1)
        let marching = Library.model(key).pose(.march, at: 0.3)
        let resting = Library.model(key).pose(.idle, at: 1.0)
        let leaving = CompanyPose.Blend(clip: .idle, time: 1.0, weight: 1)
        XCTAssertEqual(WorldStage.blendedPose(key, .march, at: 0.3, from: leaving), resting, "all the old clip at first")
        var gone = leaving
        gone.weight = 0
        XCTAssertEqual(WorldStage.blendedPose(key, .march, at: 0.3, from: gone), marching, "all the new at last")
        var half = leaving
        half.weight = 0.5
        let between = WorldStage.blendedPose(key, .march, at: 0.3, from: half)
        XCTAssertNotEqual(between, marching)
        XCTAssertNotEqual(between, resting)
        // A model that never moves stands as it is.
        XCTAssertEqual(WorldStage.blendedPose(.scaffold, .march, at: 0.3, from: half), Library.model(.scaffold).pose(.march, at: 0.3))
        // Figures easing out together share their pose, and the palette holds it once.
        var frame = SceneFrame()
        var shared: [WorldStage.PoseKey: UInt32] = [:]
        let a = WorldStage.pose(key, .march, at: 0.3, blend: half, shared: &shared, into: &frame)
        XCTAssertEqual(WorldStage.pose(key, .march, at: 0.3, blend: half, shared: &shared, into: &frame), a)
        XCTAssertNotEqual(WorldStage.pose(key, .march, at: 0.3, shared: &shared, into: &frame), a, "the plain march is another")
    }
}

extension Happenings {
    init(strikes: [Strike] = [], falls: [Spot] = [], battles: [Spot] = []) {
        self.init()
        self.strikes = strikes
        self.falls = falls
        self.battles = battles
    }
}

/// The weather an omen brings, seen in the world.
final class WeatherTests: XCTestCase {
    func testEachOmenBringsItsWeather() {
        XCTAssertEqual(Weather.of(nil), .clear)
        XCTAssertEqual(Weather.of(.leanWatch), .rain)
        XCTAssertEqual(Weather.of(.risingMist), .mist)
        XCTAssertEqual(Weather.of(.stillNight), .still)
        XCTAssertEqual(Weather.of(.moonsaltBloom), .bloom)
        XCTAssertEqual(Set(OmenKind.allCases.map { Weather.of($0) }).count, OmenKind.allCases.count, "Each omen its own")
        var frame = FrameUniforms.make(camera: Camera(), size: CGSize(width: 800, height: 600), pixelsPerPoint: 2, time: 0, motion: 1,
                                       radius: 8, terrain: TerrainMesh(relief: Relief(map: WorldMap(radius: 8, fill: Tile(terrain: .greyfield)))),
                                       hovered: nil, selected: nil, houses: [])
        let (haze, moon) = (frame.haze.y, frame.moon.w)
        frame.weather(.rain)
        XCTAssertEqual(frame.haze.y, haze * 1.6, accuracy: 1e-6)
        XCTAssertEqual(frame.moon.w, moon * 0.55, accuracy: 1e-6, "The moon dimmed by the rain")
        var misty = frame
        misty.weather(.mist)
        XCTAssertGreaterThan(misty.haze.y, frame.haze.y, "Mist lies thicker still")
    }

    func testRainFallsAndMistDriftsAboutTheView() {
        let focus = Vec3(3, 0, -2)
        let rain = Weather.rain.motes(around: focus, extent: 5, time: 10)
        XCTAssertEqual(rain.count, Weather.drops * 2, "A drop and its streak")
        XCTAssertTrue(rain.allSatisfy { abs($0.place.x - focus.x) <= 5.001 && abs($0.place.z - focus.z) <= 5.001 })
        XCTAssertTrue(rain.allSatisfy { $0.place.y >= Relief.waterline && $0.place.y <= Relief.waterline + Weather.rainTop + 0.06 })
        XCTAssertEqual(rain, Weather.rain.motes(around: focus, extent: 5, time: 10), "The same moment, the same rain")
        // A moment on, each drop lower, unless it has begun again at the top.
        let later = Weather.rain.motes(around: focus, extent: 5, time: 10.1)
        let fell = zip(rain, later).filter { $0.place.y > $1.place.y }.count
        XCTAssertGreaterThan(fell, rain.count * 3 / 4)

        let mist = Weather.mist.motes(around: focus, extent: 5, time: 4)
        XCTAssertEqual(mist.count, Weather.banks)
        XCTAssertTrue(mist.allSatisfy { $0.place.w >= 0.7 && $0.colour.w > 0 }, "Wide, and hiding a little of what lies behind")
        let drifted = Weather.mist.motes(around: focus, extent: 5, time: 6)
        XCTAssertNotEqual(mist, drifted, "It drifts")
        XCTAssertTrue(Weather.clear.motes(around: focus, extent: 5, time: 1).isEmpty)
        XCTAssertTrue(Weather.still.motes(around: focus, extent: 5, time: 1).isEmpty)
        XCTAssertTrue(Weather.allCases.allSatisfy { $0.hazeFactor > 0 && $0.moonFactor > 0 })
    }
}
