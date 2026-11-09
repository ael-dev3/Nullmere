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

    /// Smoke leans with the night's own slow air where no wind is told,
    /// rises straight where none blows, and is borne off on the watch's wind
    /// where one does, its embers with it, so a fire's smoke shows where it
    /// will run; the wind's way on the ground as the world lies is toward
    /// the neighbouring hex the realm names, and what burns in the world
    /// carries the air it is given.
    func testSmokeIsBorneOnTheWatchsWind() {
        let origin = Vec3(2, 0.5, -1)
        func lean(_ effect: Effect, _ drift: Vec3?) -> Vec3 {
            let emitter = Emitter(effect, at: origin, rate: 20, spread: 0, seed: 9, strength: 1, drift: drift)
            let placed = positions(Effects.motes(bursts: [], emitters: [emitter], at: 30))
            return placed.reduce(Vec3(0, 0, 0)) { $0 + ($1 - origin) } / Float(max(placed.count, 1))
        }
        let east = WorldStage.windward(0) * Happenings.windCarries
        let night = lean(.smoke, nil), still = lean(.smoke, Vec3(0, 0, 0)), windy = lean(.smoke, east)
        XCTAssertGreaterThan(night.x, 0.1, "the night's own air leans it as ever")
        XCTAssertLessThan(abs(still.x) + abs(still.z), (abs(night.x) + abs(night.z)) / 2, "rising straight where no wind blows")
        XCTAssertGreaterThan(windy.x, night.x * 1.5, "borne off downwind, further than the night's air leans it")
        XCTAssertLessThan(abs(windy.z - still.z), 0.05, "and only downwind")
        XCTAssertEqual(windy.y, still.y, accuracy: 0.001, "rising alike")
        XCTAssertGreaterThan(lean(.embers, east).x, lean(.embers, nil).x + 0.05, "its embers with it")
        // The wind's way on the ground: a unit long, toward the hex it
        // names, opposite ways opposite, the first east.
        for way in 0..<6 {
            let wind = WorldStage.windward(way), back = WorldStage.windward(way + 3)
            XCTAssertEqual(wind.length, 1, accuracy: 0.001)
            XCTAssertEqual(wind.y, 0)
            XCTAssertEqual(wind.x, -back.x, accuracy: 0.001)
            XCTAssertEqual(wind.z, -back.z, accuracy: 0.001)
            let toward = Relief.centre(of: Hex.directions[way]), here = Relief.centre(of: Hex(0, 0))
            let dx = toward.x - here.x, dz = toward.z - here.z
            XCTAssertGreaterThan(wind.x * dx + wind.z * dz, 0.999 * (dx * dx + dz * dz).squareRoot(), "toward the hex it names")
        }
        XCTAssertGreaterThan(WorldStage.windward(0).x, 0.9)
        XCTAssertEqual(WorldStage.windward(-1), WorldStage.windward(5))
        // A wood afire's smoke and a burning hold's carry the air given them.
        func smoke(_ air: Vec3?) -> Float {
            var happenings = Happenings()
            happenings.woodFires = [Happenings.Spot(at: origin, strength: 1, seed: 5)]
            happenings.blazes = [Happenings.Spot(at: origin + Vec3(0, 0, 4), strength: 1, seed: 6)]
            happenings.air = air
            let covering = happenings.effects(at: 30).motes.filter { $0.colour.w > 0 }
            return covering.map { $0.place.x - origin.x }.reduce(0, +) / Float(max(covering.count, 1))
        }
        XCTAssertGreaterThan(smoke(east), smoke(nil) + 0.3, "the wind bears it off")
        XCTAssertLessThan(abs(smoke(Vec3(0, 0, 0))), abs(smoke(nil)), "a still night's smoke rising straight")
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

    func testKindsOfMoteCanBeLeftOut() {
        var happenings = Happenings()
        happenings.strikes = [Happenings.Strike(from: Vec3(0, 0, 0), at: Vec3(1.7, 0, 0), start: 10, ranged: false, seed: 1)]
        happenings.fireflies = [Happenings.Spot(at: Vec3(-9, 0.1, -9), seed: 9)]
        let landing = 10 + Happenings.landing + 0.05
        let all = happenings.effects(at: landing)
        XCTAssertEqual(happenings.effects(at: landing, leaving: []).motes, all.motes, "Nothing left out, all of it")
        // The blow's flash and dust and the fireflies left out: only its sparks.
        let sparks = happenings.effects(at: landing, leaving: [.flash, .dust, .fireflies])
        XCTAssertFalse(sparks.motes.isEmpty)
        XCTAssertLessThan(sparks.motes.count, all.motes.count)
        XCTAssertTrue(sparks.motes.allSatisfy { $0.colour.w == 0 && $0.colour.x > 1 }, "Steel's sparks, nothing else")
        XCTAssertEqual(sparks.lights.count, all.lights.count, "The blow still lights the ground")
        XCTAssertTrue(happenings.effects(at: landing, leaving: Set(Effect.allCases)).motes.isEmpty)
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
        happenings.furies = [Happenings.Fury(at: Vec3(12, 0, 12), start: 10, seed: 10)]
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

    func testEachArchetypesSkillFiresInItsOwnLook() {
        // One look to each archetype, by the skill that fires in battle.
        let looks = Archetype.allCases.map { archetype in FuryLook.of(Skill.allCases.first { $0.archetype == archetype }!) }
        XCTAssertEqual(Set(looks), Set(FuryLook.allCases))
        XCTAssertEqual(FuryLook.of(.holdFast), .ward)
        XCTAssertEqual(FuryLook.of(.fellCharge), .blaze)
        XCTAssertEqual(FuryLook.of(.harry), .volley)
        XCTAssertEqual(FuryLook.of(.closeRanks), .ring)
        XCTAssertEqual(FuryLook.of(.breach), .quake)
        let origin = Vec3(3, 0.2, -1)
        func fired(_ look: FuryLook, at time: Float) -> (motes: [Mote], lights: [PointLight]) {
            var happenings = Happenings()
            happenings.furies = [Happenings.Fury(at: origin, start: 10, look: look, seed: 17)]
            return happenings.effects(at: time)
        }
        for look in FuryLook.allCases {
            let (motes, lights) = fired(look, at: 10.3)
            XCTAssertGreaterThan(motes.count, 10, "\(look)")
            XCTAssertEqual(lights.count, 1, "\(look) lights the ground")
            let expected = look.glow * (1 - 0.3 / Happenings.furyGlow)
            XCTAssertEqual(lights.first.map { ($0.colour - expected).length } ?? 1, 0, accuracy: 1e-4, "\(look)")
            XCTAssertTrue(fired(look, at: 12.5).motes.isEmpty, "\(look) is gone")
        }
        XCTAssertNotEqual(Set(FuryLook.allCases.map(\.glow.x)).count, 1, "Each its own light")
        func across(_ p: Vec3) -> Float { Vec3(p.x - origin.x, 0, p.z - origin.z).length }
        // Each lays its sigil on the ground about its company, two rings and
        // the spokes between, in its own light, and fades by the end.
        for look in FuryLook.allCases {
            let ground = fired(look, at: 10.5).motes.filter { abs($0.place.y - origin.y - Effects.sigilLift) < 1e-4 }
            XCTAssertGreaterThan(ground.count, 60, "\(look)'s sigil")
            let reach = positions(ground).map(across)
            XCTAssertLessThanOrEqual(reach.max() ?? 9, Happenings.sigilReach + 1e-3, "\(look)'s sigil about its company")
            XCTAssertGreaterThanOrEqual(reach.min() ?? 0, Happenings.sigilReach * Effects.sigilInner - 1e-3, "\(look)'s, not over it")
            XCTAssertGreaterThan(reach.filter { $0 > Happenings.sigilReach - 0.01 }.count, ground.count / 3, "\(look)'s outer ring")
            let light = ground.reduce(Vec3.zero) { $0 + Vec3($1.colour.x, $1.colour.y, $1.colour.z) }
            let hue = look.glow / max(look.glow.x, max(look.glow.y, look.glow.z))
            XCTAssertEqual((light / max(light.x, max(light.y, light.z)) - hue).length, 0, accuracy: 1e-3, "\(look)'s own light")
            XCTAssertGreaterThan(fired(look, at: 10.3).motes.count, 200, "\(look) as wide as its company")
        }
        XCTAssertLessThan(fired(.ring, at: 10.02).motes.filter { abs($0.place.y - origin.y - Effects.sigilLift) < 1e-4 }.map {
            across(Vec3($0.place.x, $0.place.y, $0.place.z))
        }.max() ?? 0, Happenings.sigilReach * 0.85, "Swelling out as it comes")
        // A ward is a dome of cold light over the company, under a shaft of it.
        let ward = fired(.ward, at: 10.6).motes
        let dome = positions(ward).filter { $0.y > origin.y + 0.1 && across($0) > 0.3 }
        XCTAssertGreaterThan(dome.count, 40)
        XCTAssertTrue(dome.allSatisfy { abs(($0 - origin).length - 0.85) < 0.2 }, "On the dome")
        XCTAssertTrue(ward.allSatisfy { $0.colour.z > $0.colour.x })
        for look in [FuryLook.ward, .ring] {
            XCTAssertTrue(positions(fired(look, at: 10.5).motes).contains { $0.y > origin.y + 1.5 && across($0) < 0.15 }, "\(look)'s shaft of light")
        }
        // Fire is thrown out, warm.
        XCTAssertTrue(fired(.blaze, at: 10.3).motes.contains { $0.colour.x > 1 && $0.colour.x > $0.colour.z * 3 })
        // Light falls: lower as it goes.
        let early = positions(fired(.volley, at: 10.1).motes), late = positions(fired(.volley, at: 10.4).motes)
        XCTAssertGreaterThan(early.map(\.y).reduce(0, +) / Float(early.count), late.map(\.y).reduce(0, +) / Float(late.count))
        // The ground breaks in a ring that runs out, of dust that hides what lies behind.
        let near = positions(fired(.quake, at: 10.15).motes).map { Vec3($0.x - origin.x, 0, $0.z - origin.z).length }.max() ?? 0
        let far = positions(fired(.quake, at: 10.6).motes).map { Vec3($0.x - origin.x, 0, $0.z - origin.z).length }.max() ?? 0
        XCTAssertGreaterThan(far, near)
        XCTAssertTrue(fired(.quake, at: 10.3).motes.contains { $0.colour.w > 0 })
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
                                       hovered: nil, selected: nil)
        let (haze, moon) = (frame.haze.y, frame.moon.w)
        frame.weather(.rain)
        XCTAssertEqual(frame.haze.y, haze * 1.6, accuracy: 1e-6)
        XCTAssertEqual(frame.moon.w, moon * 0.55, accuracy: 1e-6, "The moon dimmed by the rain")
        var misty = frame
        misty.weather(.mist)
        XCTAssertGreaterThan(misty.haze.y, frame.haze.y, "Mist lies thicker still")        // The Still's calm, none to its deepest, read by the water.
        var calm = frame
        XCTAssertEqual(calm.still.x, 0)
        calm.calm(5)
        XCTAssertEqual(calm.still.x, 0.5, accuracy: 1e-6)
        calm.calm(40)
        XCTAssertEqual(calm.still.x, 1, "no calmer than the deepest")
        XCTAssertNotEqual(calm, frame)
        XCTAssertTrue(WorldShaders.source.contains("frame.still.x"))
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
        // The moon eaten: its light all but gone, nothing falling or drifting.
        XCTAssertTrue(Weather.eclipse.motes(around: focus, extent: 5, time: 1).isEmpty)
        XCTAssertLessThan(Weather.eclipse.moonFactor, Weather.allCases.filter { $0 != .eclipse }.map(\.moonFactor).min()!)
    }
}
