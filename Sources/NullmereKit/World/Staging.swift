import Foundation
import NullmereCore
import NullmereModels
import NullmereWorld

/// The world's models as the session sees them at a moment: the holds it
/// knows with their works rising, the land's furniture, its companies where
/// their marches have brought them, striking, struck or falling, and what
/// flies over them all.
extension GameSession {
    /// A work rising to its new height: from where it stood toward where
    /// the watch has brought it, over a moment.
    struct Rising: Equatable {
        let kind: BuildingKind
        let level: Int
        let from: Float
        let to: Float
        let start: Date

        /// How high it stands at `now`, eased in and out.
        func shown(at now: Date) -> Float { GameSession.eased(from: from, to: to, since: start, at: now) }

        func isDone(at now: Date) -> Bool { now.timeIntervalSince(start) >= WorldStage.riseSeconds }
    }

    /// An alliance's hall rising a watch further: from where it stood
    /// toward where the watch has brought it, over a moment.
    struct HallRising: Equatable {
        let from: Float
        let to: Float
        let start: Date

        func shown(at now: Date) -> Float { GameSession.eased(from: from, to: to, since: start, at: now) }
    }

    /// From one height toward another over a rise's moment, eased in and out.
    nonisolated static func eased(from: Float, to: Float, since start: Date, at now: Date) -> Float {
        let t = Float(min(max(now.timeIntervalSince(start) / WorldStage.riseSeconds, 0), 1))
        return from + (to - from) * t * t * (3 - 2 * t)
    }

    /// How fast a company's feet go on the march, strides a second.
    static let marchStrides: Float = 2.2
    /// How long a company takes to ease from one clip into the next.
    static let easing = 0.25

    /// A company's clip as last drawn: since when, and the clip it left.
    struct ClipShown: Equatable {
        var clip: Clip
        var time: Float
        var since: Date
        var from: Clip?
        var fromTime: Float
    }

    /// A work finished: where, and when its last course was set.
    struct Completion: Equatable {
        let hold: Int
        let kind: BuildingKind
        let level: Int
        let at: Date
    }

    /// The models a frame draws at `time` on the map's clock.
    func sceneFrame(at time: Double, now: Date = Date()) -> SceneFrame {
        // Laid out afresh with each new map, as the land's relief is.
        if stage == nil {
            stage = WorldStage(map: state.map, relief: relief)
        }
        guard let stage else { return SceneFrame() }
        let houses = WorldView.houseColours
        let full = motion == .full
        var frame = SceneFrame()
        frame.fine = camera.scale >= GameSession.fineScale
        let t = Float(time)

        // The holds the keeper knows of, each with its works.
        var sights: [HoldSight] = []
        for hold in state.holds where isExplored(hold.position) {
            let colour = WorldStage.colour(houses, sigil: state.houses[hold.owner].sigil)
            let (progress, finishing) = rising(of: hold, at: now, animated: full)
            sights.append(HoldSight(hold: hold, colour: colour, progress: progress, finishing: finishing,
                                    heritage: state.heritage(of: hold.owner)))
        }
        let (holds, hearths) = stage.holds(sights, time: t, into: &frame)
        // Their townsfolk about their works, in sight and in full motion,
        // and carts on the ways between them.
        let townsfolk = full ? stage.townsfolk(sights.filter { isVisible($0.hold.position) }, time: t, into: &frame)
            + stage.traffic(ways, time: t, into: &frame) : []
        // The alliances' halls the keeper knows of, each in its leader's
        // colour, one rising easing up a watch's height as the watch turns.
        let hallSights = state.hallsStanding.filter { isExplored($0.position) }.map { hall in
            HallSight(hex: hall.position, colour: allianceColour(hall.alliance, else: hall.raisedBy, houses),
                      progress: risen(hall, at: now, animated: full))
        }
        let (halls, hallHearths) = stage.halls(hallSights)
        // Their storehouses, rising as their halls do.
        let storehouseSights = state.storehousesStanding.filter { isExplored($0.position) }.map { storehouse in
            HallSight(hex: storehouse.position, colour: allianceColour(storehouse.alliance, else: storehouse.raisedBy, houses),
                      progress: risen(storehouse.id, to: Float(storehouse.progress), at: now, animated: full))
        }
        let storehouses = stage.storehouses(storehouseSights, time: t, into: &frame)

        // The companies in sight, and the fallen.
        let poses = companyPoses(at: now, animated: full, time: time)
        let companies = stage.companies(poses, houses: houses, into: &frame)

        // The land's sites the keeper knows, its holy sites and the lairs of
        // the wilds, and its furniture, cleared where companies, sites,
        // lairs and holds stand.
        let sites = state.sitesInLand.filter { isExplored($0.position) }
        let siteBatches = stage.sites(sites.filter { !$0.isYard }.map { ($0.store, $0.position) })
            + stage.shrines(state.holySites.filter { isExplored($0.position) }.map { shrine in
                (shrine.kind, shrine.position, shrine.holder.flatMap { holder in
                    state.houses.indices.contains(holder) ? WorldStage.colour(houses, sigil: state.houses[holder].sigil) : nil
                })
            })
        // The alliances' yards among them, each in its alliance's colour.
        let yardSights: [(store: Resource, hex: Hex, colour: Vec4)] = sites.compactMap { site in
            guard let alliance = site.alliance else { return nil }
            return (store: site.store, hex: site.position, colour: allianceColour(alliance, else: -1, houses))
        }
        let yards = stage.yards(yardSights, time: t, into: &frame)
        let found = state.lairsStanding.filter { isExplored($0.position) }
        let lairs = stage.lairs(found.map { ($0.kind, $0.position) })
        // The alliances' standards, each in its leader's colour.
        let flags = state.standardsStanding.filter { isExplored($0.position) }
        let standards = stage.standards(flags.map { ($0.position, allianceColour($0.alliance, else: $0.raisedBy, houses)) })
        let standing = Set(poses.filter { $0.unit >= 0 }.map(\.hex) + sites.map(\.position) + found.map(\.position) + flags.map(\.position))
        let furniture = stage.furnish(occupied: standing,
                                      holds: Set(sights.map(\.hold.position) + hallSights.map(\.hex) + storehouseSights.map(\.hex)))

        // Arrows in flight, birds over the water, smoke from the hearths in sight.
        let lake = Relief.centre(of: Hex(0, 0))
        let flights = WorldStage.flights(arrows: full ? arrows(at: now) : [],
                                         birdsOver: full ? Vec3(lake.x, Relief.waterline, lake.z) : nil,
                                         hearths: full ? (hearths + lairs.hearths + hallHearths + yards.hearths).filter { isVisible($0.hex) } : [],
                                         time: t,
                                         into: &frame)
        frame.fixed = furniture
        frame.fixedVersion = stage.furnitureVersion
        frame.batches = holds + townsfolk + halls + storehouses + siteBatches + yards.batches + lairs.batches + standards + companies + flights
        if full {
            (frame.motes, frame.lights) = happenings(poses: poses, sights: sights, halls: hallSights + storehouseSights, stage: stage, at: now,
                                                     time: time)
                .effects(at: t)
        }
        // The omen's weather: rain or mist about the middle of the view.
        frame.weather = Weather.of(state.currentOmen?.kind)
        if full {
            let extent = Float(min(max(600 / max(camera.scale, 1), 3), 14))
            frame.motes += frame.weather.motes(around: camera.focus, extent: extent, time: t)
        }
        // The sound of the fields in sight follows the picture of them.
        hearBattles()
        return frame
    }

    /// An alliance's colour: its leader's House's, or else the given
    /// House's; grey for none.
    func allianceColour(_ alliance: Int, else house: Int, _ houses: [Vec4]) -> Vec4 {
        let leader = state.alliance(alliance)?.leader ?? house
        return state.houses.indices.contains(leader) ? WorldStage.colour(houses, sigil: state.houses[leader].sigil) : Vec4(0.6, 0.6, 0.6, 1)
    }

    /// How far a hall has risen at `now`: eased toward the share of its
    /// raising done, a watch's height at a time.
    func risen(_ hall: AllianceHall, at now: Date, animated: Bool) -> Float {
        risen(hall.id, to: Float(hall.progress), at: now, animated: animated)
    }

    /// How far an alliance's work, a hall or a storehouse, has risen at
    /// `now`: eased toward `target`, a watch's height at a time.
    func risen(_ id: Int, to target: Float, at now: Date, animated: Bool) -> Float {
        guard animated else {
            hallRisings[id] = nil
            return target
        }
        if let kept = hallRisings[id] {
            if kept.to != target {
                hallRisings[id] = HallRising(from: kept.shown(at: now), to: target, start: now)
            }
        } else {
            hallRisings[id] = HallRising(from: target, to: target, start: now)
        }
        return hallRisings[id]!.shown(at: now)
    }

    // MARK: Works rising

    /// How far a hold's work has risen at `now`: its project eased toward
    /// the share of its watches done, or a work just finished rising its last.
    func rising(of hold: Hold, at now: Date, animated: Bool) -> (progress: Float?, finishing: HoldLayout.Plan.Rising?) {
        if let project = hold.project {
            let total = Float(project.kind.buildWatches(toLevel: project.targetLevel))
            let target = min(max(1 - Float(project.watchesLeft) / max(total, 1), 0), 1)
            guard animated else {
                risings[hold.id] = nil
                return (target, nil)
            }
            if let kept = risings[hold.id], kept.kind == project.kind, kept.level == project.targetLevel {
                if kept.to != target {
                    risings[hold.id] = Rising(kind: project.kind, level: project.targetLevel, from: kept.shown(at: now), to: target, start: now)
                }
            } else {
                risings[hold.id] = Rising(kind: project.kind, level: project.targetLevel, from: target, to: target, start: now)
            }
            return (risings[hold.id]?.shown(at: now), nil)
        }
        // Finished since it was last seen rising: it rises the rest of the way.
        guard animated, let kept = risings[hold.id], hold.level(kept.kind) == kept.level else {
            risings[hold.id] = nil
            return (nil, nil)
        }
        if kept.to < 1 {
            risings[hold.id] = Rising(kind: kept.kind, level: kept.level, from: kept.shown(at: now), to: 1, start: now)
        }
        guard let rising = risings[hold.id], !rising.isDone(at: now) else {
            if let done = risings[hold.id] {
                completions.append(Completion(hold: hold.id, kind: done.kind, level: done.level, at: now))
            }
            risings[hold.id] = nil
            return (nil, nil)
        }
        return (nil, HoldLayout.Plan.Rising(work: HoldLayout.Work(rising.kind), level: rising.level, progress: rising.shown(at: now)))
    }

    // MARK: Companies

    /// Every company in sight as a frame drawn at `now` shows it: marching,
    /// striking, at rest, drawn up small within its hold's walls; and the
    /// fallen of the blows still being drawn.
    func companyPoses(at now: Date, animated: Bool, time: Double) -> [CompanyPose] {
        var poses: [CompanyPose] = []
        let resting = Float(time.truncatingRemainder(dividingBy: Double(Clip.idle.period) * 64))
        for unit in state.units where unit.owner == player || isVisible(unit.position) {
            let key = ModelKey.company(unit.kind, tier: unit.tier, heritage: state.heritage(of: unit.owner))
            let centre = Relief.centre(of: unit.position)
            var position = Vec3(centre.x, Float(groundHeight(of: unit.position)), centre.z)
            var heading = headings[unit.id] ?? 0
            var clip = Clip.idle
            var clipTime = resting
            var spread: Float = 1
            if animated, let march = marches[unit.id],
               let point = MarchPath(path: march.path, duration: march.duration).point(after: now.timeIntervalSince(march.start)) {
                position = Vec3(point.x, max(relief.height(atX: point.x, z: point.z), Relief.waterline), point.z)
                heading = point.heading
                clip = .march
                clipTime = Float(now.timeIntervalSince(march.start)) * GameSession.marchStrides
            } else if case .gather(let site) = unit.errand, state.site(at: unit.position)?.id == site {
                // Working the site: reaping, felling, cutting, raking.
                clip = .gather
            } else if holdsByPosition[unit.position] != nil {
                // Within the walls, between the keep and the gate, facing out.
                let front = HoldLayout.frontAngle(of: unit.position)
                position += Vec3(Float(cos(Double(front))), 0, Float(sin(Double(front)))) * 0.5
                heading = .pi / 2 - front
                spread = 0.3
            }
            if animated {
                // Struck: jolted back from the blow, and shaken.
                for blow in blows where blow.defender == unit.id && blow.from != unit.position {
                    let age = now.timeIntervalSince(blow.start) - Double(Happenings.landing)
                    guard age > 0, age < 0.4 else { continue }
                    let from = Relief.centre(of: blow.from)
                    let away = Vec3(centre.x - from.x, 0, centre.z - from.z).normalized
                    let jolt = Float(sin(Double.pi * age / 0.4)) * 0.07
                    let shake = Float(sin(age * 70)) * 0.012 * Float(1 - age / 0.4)
                    position += away * jolt + Vec3(-away.z, 0, away.x) * shake
                }
                for blow in blows where blow.attacker == unit.id {
                    let age = now.timeIntervalSince(blow.start)
                    guard age < GameSession.Blow.duration else { continue }
                    clip = .attack
                    clipTime = Float(age)
                    heading = CompanyPose.heading(from: unit.position, to: blow.at)
                    if !blow.isRanged {
                        // Into the foe's ground and back.
                        let foe = Relief.centre(of: blow.at)
                        let lean = Float(GameSession.Blow.lunge(at: age / GameSession.Blow.duration)) * 0.6
                        position.x += (foe.x - centre.x) * lean
                        position.z += (foe.z - centre.z) * lean
                    }
                }
            }
            let chosen = selectedUnit?.id == unit.id
            poses.append(CompanyPose(unit: unit.id, key: key, sigil: state.houses[unit.owner].sigil, health: unit.health,
                                     hex: unit.position, position: position, heading: heading, clip: clip, clipTime: clipTime,
                                     emphasis: chosen ? 1 : (hovered == unit.position ? 0.5 : 0), isOwn: unit.owner == player,
                                     commander: unit.leader.flatMap(commanderLook), spread: spread,
                                     blend: animated ? easing(unit.id, into: clip, at: clipTime, now: now) : nil))
        }
        // The far country's companies in sight, no House's, watching.
        for wild in state.wildsStanding where isVisible(wild.position) {
            let centre = Relief.centre(of: wild.position)
            poses.append(CompanyPose(unit: GameSession.wildPoseBase - wild.id, key: .wild(tier: GameSession.wildTier(of: wild.level)),
                                     sigil: 0, health: wild.health, hex: wild.position,
                                     position: Vec3(centre.x, Float(groundHeight(of: wild.position)), centre.z),
                                     heading: headings[GameSession.wildPoseBase - wild.id] ?? Float(wild.id % 6) * .pi / 3,
                                     clipTime: resting, emphasis: hovered == wild.position ? 0.5 : 0, isOwn: false))
        }
        // The fallen lie where they fell, then fade.
        for blow in blows {
            let age = Float(now.timeIntervalSince(blow.start))
            for (index, fell) in blow.fallen.enumerated() {
                // Lying still a moment, then fading, gone well before the blow is forgotten.
                let fade = animated ? max(0, 1 - max(age - Clip.death.period - 0.2, 0) / 0.45) : 1
                guard fade > 0 else { continue }
                let centre = Relief.centre(of: fell.at)
                poses.append(CompanyPose(unit: -1 - index - blow.id * 16, key: .figure(fell.kind, tier: 1),
                                         sigil: state.houses[fell.owner].sigil, health: 60, hex: fell.at,
                                         position: Vec3(centre.x, Float(groundHeight(of: fell.at)), centre.z),
                                         heading: CompanyPose.heading(from: fell.at, to: fell.at == blow.at ? blow.from : blow.at),
                                         clip: .death, clipTime: animated ? age : Clip.death.period, opacity: fade,
                                         isOwn: fell.owner == player))
            }
        }
        return poses
    }

    /// How a company eases out of the clip it was last drawn in, if it
    /// has lately changed clips; nil once the new one has taken over.
    func easing(_ id: Int, into clip: Clip, at time: Float, now: Date) -> CompanyPose.Blend? {
        guard var shown = clipsShown[id] else {
            clipsShown[id] = ClipShown(clip: clip, time: time, since: .distantPast, from: nil, fromTime: 0)
            return nil
        }
        if shown.clip != clip {
            shown = ClipShown(clip: clip, time: time, since: now, from: shown.clip, fromTime: shown.time)
        }
        shown.time = time
        clipsShown[id] = shown
        let left = 1 - now.timeIntervalSince(shown.since) / GameSession.easing
        guard let from = shown.from, left > 0 else { return nil }
        return CompanyPose.Blend(clip: from, time: shown.fromTime, weight: Float(left))
    }

    // MARK: What throws up motes and gives light

    /// What happens in sight at `now`, on the map's clock: blows struck and
    /// companies falling, commanders' furies, holds scouted, marches, works
    /// rising and finished, battles going on, holds burning with their
    /// wards broken, and fireflies over the reeds near the eye.
    func happenings(poses: [CompanyPose], sights: [HoldSight], halls: [HallSight] = [], stage: WorldStage, at now: Date,
                    time: Double) -> Happenings {
        var happenings = Happenings()
        func clock(_ date: Date) -> Float { Float(time - now.timeIntervalSince(date)) }
        func ground(_ hex: Hex) -> Vec3 {
            let centre = Relief.centre(of: hex)
            return Vec3(centre.x, Float(groundHeight(of: hex)), centre.z)
        }
        for blow in blows {
            let onWard = blow.defender == nil && holdsByPosition[blow.at] != nil
            happenings.strikes.append(Happenings.Strike(from: ground(blow.from), at: ground(blow.at), start: clock(blow.start),
                                                        ranged: blow.isRanged, onWard: onWard, seed: UInt32(truncatingIfNeeded: blow.id)))
            for (index, fell) in blow.fallen.enumerated() {
                happenings.falls.append(Happenings.Spot(at: ground(fell.at), start: clock(blow.start),
                                                        seed: UInt32(truncatingIfNeeded: blow.id &* 7 &+ index)))
            }
        }
        for fury in furies {
            happenings.furies.append(Happenings.Fury(at: ground(fury.at), start: clock(fury.start), look: .of(fury.skill),
                                                     seed: UInt32(truncatingIfNeeded: fury.id)))
        }
        for sighting in sightings {
            happenings.sightings.append(Happenings.Spot(at: ground(sighting.at), start: clock(sighting.start),
                                                        seed: UInt32(truncatingIfNeeded: sighting.id)))
        }
        for pose in poses where pose.clip == .march {
            var riders = false
            switch pose.key {
            case .figure(.rider, _): riders = true
            case .signature(let heritage): riders = heritage.signature == .rider
            default: break
            }
            happenings.marching.append(Happenings.Spot(at: pose.position, strength: riders ? 1.4 : 1, seed: UInt32(truncatingIfNeeded: pose.unit)))
        }
        happenings.rising = (stage.risingWorks(sights) + stage.risingHalls(halls)).enumerated().map { Happenings.Spot(at: $1, seed: UInt32($0)) }
        // The dust over every field of battle in sight, the thicker the more companies stand in it.
        for field in state.fieldsOfBattle where isVisible(field.at) {
            let standing = field.fighters.filter(\.standing).count
            happenings.battles.append(Happenings.Spot(at: ground(field.at), strength: Float(min(standing, 12)),
                                                      seed: UInt32(truncatingIfNeeded: field.id)))
        }
        completions.removeAll { now.timeIntervalSince($0.at) > 3 }
        for done in completions {
            guard let hold = state.hold(done.hold) else { continue }
            let key = HoldLayout.Work(done.kind).key(level: done.level).canonical
            if let piece = stage.pieces(of: hold, progress: nil, heritage: state.heritage(of: hold.owner)).first(where: { $0.key.canonical == key }) {
                happenings.finished.append(Happenings.Spot(at: piece.position, start: clock(done.at), seed: UInt32(done.hold)))
            }
        }
        for hold in state.holds where isVisible(hold.position) && hold.ward * 2 < hold.maximumWard {
            let broken = 1 - Float(hold.ward) / Float(max(hold.maximumWard, 1)) * 2
            happenings.blazes.append(Happenings.Spot(at: ground(hold.position), strength: 0.35 + 0.65 * broken, seed: UInt32(hold.id)))
        }
        // A hall struck below half its ward burns as a hold does.
        for hall in state.hallsStanding where isVisible(hall.position) && hall.ward * 2 < hall.wardLimit {
            let broken = 1 - Float(hall.ward) / Float(max(hall.wardLimit, 1)) * 2
            happenings.blazes.append(Happenings.Spot(at: ground(hall.position), strength: 0.35 + 0.65 * broken, seed: UInt32(truncatingIfNeeded: hall.id)))
        }
        // And a storehouse.
        for storehouse in state.storehousesStanding where isVisible(storehouse.position) && storehouse.ward * 2 < Storehouse.maximumWard {
            let broken = 1 - Float(storehouse.ward) / Float(Storehouse.maximumWard) * 2
            happenings.blazes.append(Happenings.Spot(at: ground(storehouse.position), strength: 0.35 + 0.65 * broken,
                                                     seed: UInt32(truncatingIfNeeded: storehouse.id)))
        }
        if camera.scale >= 40 {
            happenings.fireflies = stage.fireflySpots(near: camera.focus).enumerated().map { Happenings.Spot(at: $1, seed: UInt32($0) &+ 17) }
        }
        return happenings
    }

    /// Where the far country's companies are numbered among the poses:
    /// below every company's id and every fallen one's.
    static let wildPoseBase = -1_000_000

    /// A wild's look by its level: the least of them, the worse, the worst.
    static func wildTier(of level: Int) -> Int {
        level <= 3 ? 1 : (level <= 7 ? 2 : 3)
    }

    /// Which of the commanders' looks a commander rides in: one for each archetype.
    func commanderLook(_ id: Int) -> Int? {
        guard let commander = state.commander(id) else { return nil }
        return Archetype.allCases.firstIndex(of: commander.archetype)
    }

    // MARK: Arrows

    /// The arrows of the bows' blows, a few to each, loosed one after
    /// another and coming down about the mark.
    func arrows(at now: Date) -> [ArrowFlight] {
        var flights: [ArrowFlight] = []
        for blow in blows where blow.isRanged {
            let age = Float(now.timeIntervalSince(blow.start))
            let from = Relief.centre(of: blow.from), to = Relief.centre(of: blow.at)
            let rise = Float(groundHeight(of: blow.from)) + 0.28
            let fall = Float(groundHeight(of: blow.at)) + 0.05
            for shaft in 0..<4 {
                let s = Float(shaft)
                let progress = (age - s * 0.05) / 0.38
                guard progress >= 0, progress <= 1 else { continue }
                let spread = Vec3(0.17 * Float(sin(Double(s * 2.4 + Float(blow.id)))), 0, 0.17 * Float(cos(Double(s * 1.7 + Float(blow.id)))))
                flights.append(ArrowFlight(from: Vec3(from.x, rise, from.z) + spread * 0.5, to: Vec3(to.x, fall, to.z) + spread,
                                           progress: progress))
            }
        }
        return flights
    }
}
