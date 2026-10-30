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
        func shown(at now: Date) -> Float {
            let t = Float(min(max(now.timeIntervalSince(start) / WorldStage.riseSeconds, 0), 1))
            return from + (to - from) * t * t * (3 - 2 * t)
        }

        func isDone(at now: Date) -> Bool { now.timeIntervalSince(start) >= WorldStage.riseSeconds }
    }

    /// How fast a company's feet go on the march, strides a second.
    static let marchStrides: Float = 2.2

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
        let t = Float(time)

        // The holds the keeper knows of, each with its works.
        var sights: [HoldSight] = []
        for hold in state.holds where isExplored(hold.position) {
            let colour = WorldStage.colour(houses, sigil: state.houses[hold.owner].sigil)
            let (progress, finishing) = rising(of: hold, at: now, animated: full)
            sights.append(HoldSight(hold: hold, colour: colour, progress: progress, finishing: finishing))
        }
        let (holds, hearths) = stage.holds(sights, time: t, into: &frame)

        // The companies in sight, and the fallen.
        let poses = companyPoses(at: now, animated: full, time: time)
        let companies = stage.companies(poses, houses: houses, into: &frame)

        // The land's furniture, cleared where companies and holds stand.
        let standing = Set(poses.filter { $0.unit >= 0 }.map(\.hex))
        let furniture = stage.furnish(occupied: standing, holds: Set(sights.map(\.hold.position)))

        // Arrows in flight, birds over the water, smoke from the hearths in sight.
        let lake = Relief.centre(of: Hex(0, 0))
        let flights = WorldStage.flights(arrows: full ? arrows(at: now) : [],
                                         birdsOver: full ? Vec3(lake.x, Relief.waterline, lake.z) : nil,
                                         hearths: full ? hearths.filter { isVisible($0.hex) } : [], time: t, into: &frame)
        frame.batches = furniture + holds + companies + flights
        return frame
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
            risings[hold.id] = nil
            return (nil, nil)
        }
        return (nil, HoldLayout.Plan.Rising(work: .building(rising.kind), level: rising.level, progress: rising.shown(at: now)))
    }

    // MARK: Companies

    /// Every company in sight as a frame drawn at `now` shows it: marching,
    /// striking, at rest, drawn up small within its hold's walls; and the
    /// fallen of the blows still being drawn.
    func companyPoses(at now: Date, animated: Bool, time: Double) -> [CompanyPose] {
        var poses: [CompanyPose] = []
        let resting = Float(time.truncatingRemainder(dividingBy: Double(Clip.idle.period) * 64))
        for unit in state.units where unit.owner == player || isVisible(unit.position) {
            let key = ModelKey.figure(unit.kind, tier: min(1 + unit.rank, ModelKey.tiers(of: unit.kind)))
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
            } else if holdsByPosition[unit.position] != nil {
                // Within the walls, between the keep and the gate, facing out.
                let front = HoldLayout.frontAngle(of: unit.position)
                position += Vec3(Float(cos(Double(front))), 0, Float(sin(Double(front)))) * 0.5
                heading = .pi / 2 - front
                spread = 0.3
            }
            if animated {
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
                                     spread: spread))
        }
        // The fallen lie where they fell, then fade.
        for blow in blows {
            let age = Float(now.timeIntervalSince(blow.start))
            for (index, fell) in blow.fallen.enumerated() {
                let fade = animated ? max(0, 1 - max(age - Clip.death.period - 0.3, 0) / 0.5) : 1
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
