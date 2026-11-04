import Foundation
import NullmereCore
import NullmereModels
import NullmereWorld

/// The world's models as the session sees them at a moment: the holds it
/// knows with their works rising, the land's furniture, its companies where
/// their marches have brought them, striking, struck or falling, and what
/// flies over them all.
extension GameSession {
    /// How far the watch has gone, 0 to 1: by its paces where the realm
    /// paces it, else half.
    nonisolated static func watchProgress(_ state: GameState) -> Float {
        guard let pacing = state.pacing else { return 0.5 }
        return Float(pacing.walked) / Float(GameState.pacesPerWatch)
    }

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

    /// How far round a hold's heart its works and town can be seen, and a
    /// company's ranks, for leaving those out of view out of a frame.
    static let holdReach: Float = HoldLayout.reach + 1.5
    static let companyReach: Float = 2

    /// The models a frame draws at `time` on the map's clock; for a view of
    /// `size`, only the holds, towns and companies it can show.
    func sceneFrame(at time: Double, now: Date = Date(), in size: CGSize? = nil) -> SceneFrame {
        if let size, size.width > 0, size.height > 0 { viewSize = size }
        // Laid out afresh with each new map, as the land's relief is.
        if stage == nil {
            stage = WorldStage(map: state.map, relief: relief)
            stage?.furnitureShare = detail.furnitureShare
        }
        guard let stage else { return SceneFrame() }
        let houses = WorldView.houseColours
        let full = motion == .full
        var frame = SceneFrame()
        frame.fine = camera.scale >= GameSession.fineScale
        let t = Float(time)
        // What the view takes in, when its size is known: a wide realm's
        // holds and companies beyond it are not staged.
        let view = size.map { ViewFrustum(viewProjection: camera.viewProjection(in: $0)) }
        func inView(_ hex: Hex, within reach: Float) -> Bool { view?.sees(hex, within: reach) ?? true }

        // The holds the keeper knows of, each with its works.
        var sights: [HoldSight] = []
        for hold in state.holds where isExplored(hold.position) {
            let colour = WorldStage.colour(houses, sigil: state.houses[hold.owner].sigil)
            let (progress, finishing) = rising(of: hold, at: now, animated: full)
            sights.append(HoldSight(hold: hold, colour: colour, progress: progress, finishing: finishing,
                                    heritage: state.heritage(of: hold.owner)))
        }
        let shown = sights.filter { inView($0.hold.position, within: GameSession.holdReach) }
        let (holds, hearths) = stage.holds(shown, time: t, into: &frame)
        // The help allies have given the holds' works and musters, circling
        // over their keeps.
        let help = stage.helpLights(shown, time: t)
        // Each hold's House crest hung by its gate: fine work, staged only
        // with the camera near, each House's crest found once.
        var crestOf: [Int: Crest] = [:]
        let crests = frame.fine ? stage.crestBoards(shown.map { sight in
            let owner = sight.hold.owner
            if crestOf[owner] == nil { crestOf[owner] = state.crest(of: owner) }
            return (hex: sight.hold.position, crest: crestOf[owner]!)
        }) : []
        // Their townsfolk about their works, in sight and in full motion,
        // the rest of their folk out about the lanes as the view comes close, and
        // carts on the ways between them.
        let townsfolk = full ? stage.townsfolk(shown.filter { isVisible($0.hold.position) }, time: t, crowds: frame.fine, into: &frame)
            + stage.traffic(ways, time: t, into: &frame) : []
        // The alliances' halls the keeper knows of, each in its leader's
        // colour, one rising easing up a watch's height as the watch turns.
        let hallSights = state.hallsStanding.filter { isExplored($0.position) }.map { hall in
            HallSight(hex: hall.position, colour: allianceColour(hall.alliance, else: hall.raisedBy, houses),
                      progress: risen(hall, at: now, animated: full))
        }
        let (halls, hallHearths) = stage.halls(hallSights.filter { inView($0.hex, within: GameSession.holdReach) })
        // Their storehouses, rising as their halls do.
        let storehouseSights = state.storehousesStanding.filter { isExplored($0.position) }.map { storehouse in
            HallSight(hex: storehouse.position, colour: allianceColour(storehouse.alliance, else: storehouse.raisedBy, houses),
                      progress: risen(storehouse.id, to: Float(storehouse.progress), at: now, animated: full))
        }
        let storehouses = stage.storehouses(storehouseSights.filter { inView($0.hex, within: GameSession.holdReach) }, time: t, into: &frame)

        // The companies in sight, and the fallen.
        let poses = companyPoses(at: now, animated: full, time: time)
        let companies = stage.companies(poses.filter { inView($0.hex, within: GameSession.companyReach) }, houses: houses, into: &frame)

        // The land's sites the keeper knows, its holy sites and the lairs of
        // the wilds, and its furniture, cleared where companies, sites,
        // lairs and holds stand.
        let sites = state.sitesInLand.filter { isExplored($0.position) }
        let siteBatches = stage.sites(sites.filter { !$0.isYard }.map { ($0.store, $0.position) })
            + stage.animate(stage.shrines(state.holySites.filter { isExplored($0.position) }.map { shrine in
                (shrine.kind, shrine.position, shrine.holder.flatMap { holder in
                    state.houses.indices.contains(holder) ? WorldStage.colour(houses, sigil: state.houses[holder].sigil) : nil
                })
            }), time: t, into: &frame)
        // The alliances' yards among them, each in its alliance's colour.
        let yardSights: [(store: Resource, hex: Hex, colour: Vec4)] = sites.compactMap { site in
            guard let alliance = site.alliance else { return nil }
            return (store: site.store, hex: site.position, colour: allianceColour(alliance, else: -1, houses))
        }
        let yards = stage.yards(yardSights, time: t, into: &frame)
        let found = state.lairsStanding.filter { isExplored($0.position) }
        let lairs = stage.lairs(found.filter { $0.gate == nil }.map { ($0.kind, $0.position) })
        // The Crown's gates, each held across its pass.
        let gates = stage.gates(found.filter { $0.gate != nil }.map(\.position))
        let lairBatches: [ModelBatch] = lairs.batches + gates.batches
        let lairHearths: [Hearth] = lairs.hearths + gates.hearths
        // The alliances' standards, each in its leader's colour.
        let flags = state.standardsStanding.filter { isExplored($0.position) }
        let standards = stage.animate(stage.standards(flags.map { ($0.position, allianceColour($0.alliance, else: $0.raisedBy, houses), Float($0.progress)) }),
                                      time: t, into: &frame)
        // The war camps of rallies gathering at holds in sight, in their
        // callers' colours.
        let camps = stage.rallyCamps(state.ralliesStanding.compactMap { rally in
            guard !rally.marching, let muster = state.hold(rally.muster), isVisible(muster.position),
                  let target = state.target(of: rally), state.houses.indices.contains(rally.caller) else { return nil }
            return (muster: muster.position, target: target.position, colour: WorldStage.colour(houses, sigil: state.houses[rally.caller].sigil))
        })
        // Each rally host on the march under its caller's banner, borne at
        // its head: among the company nearest its target.
        let banners = stage.hostBanners(state.ralliesStanding.compactMap { rally in
            guard rally.marching, let target = state.target(of: rally), state.houses.indices.contains(rally.caller) else { return nil }
            let goal = Relief.centre(of: target.position)
            let marching = poses.filter { rally.companies.contains($0.unit) && inView($0.hex, within: GameSession.companyReach) }
            guard let lead = marching.min(by: {
                ($0.position - Vec3(goal.x, $0.position.y, goal.z)).length < ($1.position - Vec3(goal.x, $1.position.y, goal.z)).length
            }) else { return nil }
            return (lead: lead, colour: WorldStage.colour(houses, sigil: state.houses[rally.caller].sigil))
        })
        // Each field of battle in sight with both sides' banners at its
        // heart, leaning as each gives ground.
        let fieldBanners = stage.fieldBanners(state.fieldsOfBattle.filter { isVisible($0.at) }.map { field in
            let troops = (0..<2).map { side in
                Float(field.fighters.filter { $0.side == side && $0.standing }.reduce(0) { $0 + max($1.troops - $1.lost, 0) })
            }
            let total = max(troops.reduce(0, +), 1)
            let colours = (0..<2).map { side -> Vec4 in
                let house = field.sides.indices.contains(side) ? field.sides[side].first : nil
                return house.flatMap { state.houses.indices.contains($0) ? WorldStage.colour(houses, sigil: state.houses[$0].sigil) : nil }
                    ?? Vec4(0.6, 0.6, 0.6, 1)
            }
            return (at: field.at, colours: colours, shares: troops.map { $0 / total })
        }, time: t)
        // Boundary stones round each alliance's land, where it meets land
        // not its own, on ground the keeper knows.
        let borders = stage.borderStones(state.allianceBorders().filter { isExplored($0.hex) }.map { border in
            (hex: border.hex, outward: border.outward,
             colour: allianceColour(border.alliance, else: state.alliance(border.alliance)?.leader ?? -1, houses))
        })
        // Barges on the water, where the watch has brought them.
        let barges = stage.barges(state.crossingsUnderWay.map { barge in
            (from: barge.pushOff, to: barge.landing, progress: GameSession.watchProgress(state))
        }, time: t)
        let standing = Set(poses.filter { $0.unit >= 0 }.map(\.hex) + sites.map(\.position) + found.map(\.position) + flags.map(\.position))
        let furniture = stage.furnish(occupied: standing,
                                      holds: Set(sights.map(\.hold.position) + hallSights.map(\.hex) + storehouseSights.map(\.hex)))

        // Arrows in flight, birds over the water, smoke from the hearths in
        // sight, and the veil of the Still's mist about the veiled holds.
        let lake = Relief.centre(of: Hex(0, 0))
        let veiled = state.veils == nil ? [] : shown.filter { state.isVeiled($0.hold.owner) && isVisible($0.hold.position) }
        let flights = WorldStage.flights(arrows: full ? arrows(at: now) : [],
                                         birdsOver: full ? Vec3(lake.x, Relief.waterline, lake.z) : nil,
                                         hearths: full ? (hearths + lairHearths + hallHearths + yards.hearths + camps.hearths).filter { isVisible($0.hex) } : [],
                                         mists: veiled.flatMap { WorldStage.mist(about: $0.hold.position, height: Float(groundHeight(of: $0.hold.position))) },
                                         time: t,
                                         into: &frame)
        frame.fixed = furniture
        frame.fixedVersion = stage.furnitureVersion
        frame.fixedRegions = stage.furnitureRegions
        let crown = stage.animate(state.crown.map { crown in
            stage.drownedCrown(at: crown.bearer.flatMap(state.unit)?.position ?? crown.hex, borne: crown.bearer != nil, time: t)
        } ?? [], time: t, into: &frame)
        // The Lyceum's hall, lit while its scholars sit.
        let lyceum = stage.animate(state.lyceumHall.map { stage.lyceum(at: $0, lit: state.lyceumHallLit, time: t) } ?? [],
                                   time: t, into: &frame)
        let campBatches = stage.animate(camps.batches, time: t, into: &frame)
        // The pedlar lying off the keeper's hold, while he does.
        let skiff = stage.animate(state.pedlar(for: state.player).map { pedlar in
            stage.pedlarSkiff(at: pedlar.at, toward: state.hold(pedlar.hold)?.position ?? pedlar.at, time: t)
        } ?? [], time: t, into: &frame)
        // The keeper's own listening stones in the lake.
        let heard = Set(state.soundings(heardBy: state.player).map(\.stone))
        let stones = stage.animate(stage.listeningStones(state.stones(of: state.player).map { (at: $0.at, heard: heard.contains($0.id)) }),
                                   time: t, into: &frame)
        // What the lake mirrored at its Still Hour, faint, of companies the
        // keeper does not otherwise see.
        // And where a company walking the mirror will come out: its image
        // already in the stilled water there, seen from every shore.
        let walking: [(kind: UnitKind, hex: Hex, colour: Vec4)] = state.mirrorWalksUnderWay.compactMap { walk in
            guard let unit = state.unit(walk.unit), state.houses.indices.contains(walk.house) else { return nil }
            return (kind: unit.kind, hex: walk.to, colour: WorldStage.colour(houses, sigil: state.houses[walk.house].sigil))
        }
        let mirror = stage.animate(stage.mirrored((state.stillHour?.glimpses ?? []).compactMap { glimpse in
            guard glimpse.owner != state.player, !isVisible(glimpse.at), state.houses.indices.contains(glimpse.owner) else { return nil }
            return (kind: glimpse.kind, hex: glimpse.at, colour: WorldStage.colour(houses, sigil: state.houses[glimpse.owner].sigil))
        } + walking), time: t, into: &frame)
        frame.batches = holds + townsfolk + halls + storehouses + siteBatches + yards.batches + lairBatches + standards + campBatches + mirror + banners + help + crests + fieldBanners + borders + barges + crown + lyceum + stones + skiff + companies + flights
        if full {
            (frame.motes, frame.lights) = happenings(poses: poses, sights: sights, halls: hallSights + storehouseSights, stage: stage, at: now,
                                                     time: time)
                .effects(at: t)
        }
        // The omen's weather: rain or mist about the middle of the view; or,
        // while the drowned age walks, the moon all but gone.
        frame.weather = state.isMoonEaten ? .eclipse : Weather.of(state.currentOmen?.kind)
        frame.calm = state.stillCalm
        if full {
            let extent = Float(min(max(600 / max(camera.scale, 1), 3), 14))
            frame.motes += frame.weather.motes(around: camera.focus, extent: extent, time: t)
        }
        // The sound of the fields in sight, and of the towns near the view,
        // follows the picture of them.
        hearBattles()
        hearTowns()
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
            if let barge = state.crossing(of: unit.id) {
                // Aboard a barge on the still water, crowded on its deck.
                let place = WorldStage.bargePlace(from: barge.pushOff, to: barge.landing, progress: GameSession.watchProgress(state))
                position = place.at + Vec3(0, 0.03, 0)
                heading = place.heading
                spread = 0.3
            } else if animated, let march = marches[unit.id],
               let point = MarchPath(path: march.path, duration: march.duration).point(after: now.timeIntervalSince(march.start)) {
                position = Vec3(point.x, max(relief.height(atX: point.x, z: point.z), Relief.waterline), point.z)
                heading = point.heading
                clip = .march
                clipTime = Float(now.timeIntervalSince(march.start)) * GameSession.marchStrides
                if state.isDrawingOff(unit.id) {
                    // Drawing off from a field: broken order, in haste.
                    spread = WorldStage.routSpread
                    clipTime *= WorldStage.routPace
                }
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
                                     commander: unit.leader.flatMap(commanderLook), spread: spread, muster: state.musterPercent(of: unit),
                                     blend: animated ? easing(unit.id, into: clip, at: clipTime, now: now) : nil))
            if let led = unit.leader.flatMap(state.commander) { poses[poses.count - 1].stars = led.starCount }
            // Standing in a field of battle: its troops' whole throng, its
            // front ranks at it blow after blow, each a beat from the next.
            if let field = state.field(of: unit.id), let fighter = field.fighter(unit.id), fighter.standing {
                let standing = max(fighter.troops - fighter.lost, 0)
                poses[poses.count - 1].throng = Formation.throngCount(key, troops: standing, muster: state.musterPercent(of: unit))
                let side = fighter.side
                if field.troops(of: side) > 0, Float(field.standing(of: side)) / Float(field.troops(of: side)) < WorldStage.routBelow {
                    // Its side broken: it turns its back on the foe and runs, ranks gone.
                    poses[poses.count - 1].clip = .march
                    poses[poses.count - 1].clipTime = Float(time) * GameSession.marchStrides * WorldStage.routPace
                    poses[poses.count - 1].heading = heading + .pi
                    poses[poses.count - 1].spread = WorldStage.routSpread
                    poses[poses.count - 1].blend = nil
                } else if clip == .idle {
                    let beat = Clip.attack.period
                    poses[poses.count - 1].clip = .attack
                    poses[poses.count - 1].clipTime = Float((time + Double(unit.id % 11) * 0.17).truncatingRemainder(dividingBy: Double(beat)))
                    poses[poses.count - 1].blend = nil
                }
            }
            if let leading = unit.leader.flatMap(state.commander)?.leadingTree {
                poses[poses.count - 1].talentTree = TalentTree.allCases.firstIndex(of: leading.tree) ?? -1
                poses[poses.count - 1].talentRanks = leading.ranks
            }
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
        // An expedition's fight on the Spine: the line below the ridge, each
        // commander at the head of a company striking in turn, and the
        // stage's host on the ridge, falling at the last blow if it is won.
        for fight in expeditionFights {
            let age = animated ? Float(now.timeIntervalSince(fight.start)) : 0
            let below = Relief.centre(of: fight.from), ridge = Relief.centre(of: fight.at)
            let toward = CompanyPose.heading(from: fight.from, to: fight.at)
            let across = Vec3(-(ridge.z - below.z), 0, ridge.x - below.x).normalized
            let heritage = state.heritage(of: player)
            for (index, id) in fight.line.enumerated() {
                let side = Float(index) - Float(fight.line.count - 1) / 2
                var position = Vec3(below.x, Float(groundHeight(of: fight.from)), below.z) + across * (side * 0.34)
                let strikeAge = age - Float(index) * 0.35
                var clip = Clip.idle, clipTime = age
                if strikeAge > 0, Double(strikeAge) < GameSession.Blow.duration {
                    clip = .attack
                    clipTime = strikeAge
                    let lean = Float(GameSession.Blow.lunge(at: Double(strikeAge) / GameSession.Blow.duration)) * 0.6
                    position += Vec3(ridge.x - below.x, 0, ridge.z - below.z) * lean
                }
                poses.append(CompanyPose(unit: GameSession.expeditionPoseBase - fight.id * 8 - index,
                                         key: .company(.spear, tier: 2, heritage: heritage), sigil: state.houses[player].sigil,
                                         health: 100, hex: fight.from, position: position, heading: toward, clip: clip,
                                         clipTime: clipTime, isOwn: true, commander: commanderLook(id), spread: 0.55))
            }
            let lastBlow = Float(fight.line.count - 1) * 0.35 + Float(Happenings.landing)
            for index in 0..<fight.hostSize {
                let side = Float(index) - Float(fight.hostSize - 1) / 2
                let position = Vec3(ridge.x, Float(groundHeight(of: fight.at)), ridge.z) + across * (side * 0.3)
                let falling = fight.won && age > lastBlow
                let fade = falling ? max(0, 1 - max(age - lastBlow - Clip.death.period - 0.3, 0) / 0.6) : 1
                guard fade > 0 else { continue }
                poses.append(CompanyPose(unit: GameSession.expeditionPoseBase - fight.id * 8 - 4 - index,
                                         key: .wild(tier: GameSession.wildTier(of: fight.stage)), sigil: 0, health: 100,
                                         hex: fight.at, position: position, heading: toward + .pi,
                                         clip: falling ? .death : (fight.won ? .idle : .attack),
                                         clipTime: falling ? age - lastBlow : age, opacity: fade, isOwn: false))
            }
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
            // Where each company meets the foe nearest it: a front of steel.
            let fighters = field.fighters.filter(\.standing).compactMap { fighter in state.unit(fighter.unit).map { (fighter, $0) } }
            for (fighter, unit) in fighters where fighter.side == 0 {
                guard let (foe, foeUnit) = fighters.filter({ $0.0.side != 0 })
                    .min(by: { $0.1.position.distance(to: unit.position) < $1.1.position.distance(to: unit.position) }),
                      foeUnit.position.distance(to: unit.position) <= max(unit.kind.range, 1) else { continue }
                let troops = max(fighter.troops - fighter.lost, 0) + max(foe.troops - foe.lost, 0)
                happenings.fronts.append(Happenings.Front(from: ground(unit.position), to: ground(foeUnit.position),
                                                          strength: Float(troops) / 25_000,
                                                          seed: UInt32(truncatingIfNeeded: unit.id &* 131 &+ foeUnit.id)))
            }
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
    /// Where an expedition's figures are numbered among the poses: below
    /// the far country's.
    static let expeditionPoseBase = -2_000_000

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
    /// another and coming down about the mark; a Mangonel's, one stone,
    /// slower and higher.
    func arrows(at now: Date) -> [ArrowFlight] {
        var flights: [ArrowFlight] = []
        for blow in blows where blow.isRanged {
            let age = Float(now.timeIntervalSince(blow.start))
            let from = Relief.centre(of: blow.from), to = Relief.centre(of: blow.at)
            let rise = Float(groundHeight(of: blow.from)) + 0.28
            let fall = Float(groundHeight(of: blow.at)) + 0.05
            if blow.hurled {
                // Loosed as the arm reaches its stop bar.
                let progress = (age - 0.12) / 0.6
                if progress >= 0, progress <= 1 {
                    flights.append(ArrowFlight(from: Vec3(from.x, rise, from.z), to: Vec3(to.x, fall, to.z), progress: progress, stone: true))
                }
                continue
            }
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
