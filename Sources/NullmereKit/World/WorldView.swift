import AppKit
import LauncherCore
import LauncherKit
import NullmereCore
import NullmereModels
import NullmereWorld
import SwiftUI

/// The map: the Metal world, with holds, companies and the marching route
/// drawn over it, and pointer input routed to the session.
struct WorldView: View {
    let session: GameSession

    @Environment(\.worldMotion) private var motion
    @Environment(\.worldFrameRate) private var frameRate
    @Environment(\.worldQuality) private var quality
    @State private var metalFailed = false

    var body: some View {
        ZStack {
            if metalFailed || WorldMetalView.systemDevice == nil {
                WorldFallback(session: session)
            } else {
                WorldMetalRepresentable(session: session, motion: motion, frameRate: frameRate, quality: quality) {
                    metalFailed = true
                }
            }
            WorldMarks(session: session, modelsDrawn: !metalFailed && WorldMetalView.systemDevice != nil)
                .allowsHitTesting(false)
            ForecastOverlay(session: session)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("The world map")
        // VoiceOver's rotor goes straight to the keeper's companies, the
        // enemies in sight, or the holds.
        .accessibilityRotor("Your companies", entries: session.mapItems.filter(\.isOwnCompany), entryID: \.id, entryLabel: \.label)
        .accessibilityRotor("Enemies in sight", entries: session.mapItems.filter(\.isFoe), entryID: \.id, entryLabel: \.label)
        .accessibilityRotor("Holds", entries: session.mapItems.filter(\.isHold), entryID: \.id, entryLabel: \.label)
        // VoiceOver reads the map as its holds and companies, each where it
        // lies, so its cursor rings it on the map and a click there chooses
        // it; choosing one selects it, and its panel opens as by a click.
        .accessibilityChildren {
            GeometryReader { proxy in
                let ring = MapAccessibility.ring(at: session.camera.scale)
                ForEach(session.mapItems) { item in
                    Button(item.label) { session.choose(item) }
                        .accessibilityActions {
                            ForEach(item.orders, id: \.self) { order in
                                Button(order.name) { MapAccessibility.carryOut(order, for: item, in: session) }
                            }
                        }
                        .frame(width: ring, height: ring)
                        .position(session.viewPoint(of: item.hex, in: proxy.size))
                }
            }
        }
    }
}

private struct WorldMetalRepresentable: NSViewRepresentable {
    let session: GameSession
    let motion: ResolvedMotion
    let frameRate: FrameRateCap
    let quality: RenderQuality
    let onFailure: () -> Void

    func makeNSView(context: Context) -> WorldMetalView {
        let view = WorldMetalView()
        view.onFailure = onFailure
        view.onHover = { hex in session.hover(hex) }
        view.cursor = { hex in
            switch session.pointerAction(at: hex) {
            case .select: return .pointingHand
            case .strike: return .crosshair
            case .march, .none: return .arrow
            }
        }
        view.onClick = { hex in session.click(hex) }
        view.onSecondaryClick = { hex in session.order(hex) }
        view.onCameraChange = { camera in session.camera = camera }
        // The world's models, posed afresh for every frame.
        view.scene = { [weak session] time in session?.sceneFrame(at: time) ?? SceneFrame() }
        update(view)
        return view
    }

    func updateNSView(_ view: WorldMetalView, context: Context) {
        update(view)
    }

    private func update(_ view: WorldMetalView) {
        view.radius = session.state.map.radius
        view.relief = session.relief
        view.houseColours = WorldView.houseColours
        view.setLand(TerrainMesh.shared(for: session.state.map), for: session.state.map)
        view.camera = session.camera
        view.hovered = session.hovered
        view.selected = session.selectedHex
        view.motion = motion
        view.frameRateCap = frameRate
        view.quality = quality
        view.setTiles(session.tileBytes, side: TileTexture.side(for: session.state.map), version: session.tilesVersion)
    }
}

/// Holds, companies and routes, drawn in one pass over the map.
struct WorldMarks: View {
    let session: GameSession
    /// A moment to draw instead of the clock's, for tests.
    var moment: Date?
    /// Whether the world's models stand beneath: then holds and companies
    /// are drawn there, and only what is read of them here, above them.
    var modelsDrawn = false

    /// How far above its heart a company's marks stand when its figures are
    /// drawn, in world units: over their heads.
    static let companyLift = 0.62
    /// And a field of battle's, over the heads of those fighting in it.
    static let fieldLift = 1.25
    /// And a hold's, over its keep and the seat's banner.
    static func holdLift(seat: Bool) -> Double { seat ? 1.62 : 1.12 }

    @Environment(\.worldMotion) private var motion
    /// Below full motion, marches and blows are shown where they end, not
    /// played out.
    private var reduceMotion: Bool { motion != .full }
    /// With "Differentiate without colour" on, what colour says is said in
    /// shape too.
    private var differentiate: Bool { Contrast.shared.differentiates }

    var body: some View {
        if let moment {
            marks(at: moment)
        } else {
            TimelineView(.animation(paused: (session.marches.isEmpty && session.blows.isEmpty) || reduceMotion)) { timeline in
                marks(at: timeline.date)
            }
        }
    }

    /// Where a company is drawn: along its march, leaning into a blow it
    /// strikes, shaken by one it takes.
    private func position(of unit: NullmereCore.Unit, at date: Date, camera: Camera, size: CGSize) -> CGPoint {
        var point = marchPoint(of: unit, at: date, camera: camera, size: size)
        guard !reduceMotion else { return point }
        for blow in session.blows where blow.attacker == unit.id || blow.defender == unit.id {
            let age = date.timeIntervalSince(blow.start) / GameSession.Blow.duration
            if blow.attacker == unit.id, !blow.isRanged {
                let foe = session.viewPoint(of: blow.at, in: size)
                let lean = CGFloat(GameSession.Blow.lunge(at: age))
                point = CGPoint(x: point.x + (foe.x - point.x) * lean, y: point.y + (foe.y - point.y) * lean)
            } else if blow.defender == unit.id {
                point.x += CGFloat(GameSession.Blow.shake(at: age))
            }
        }
        return point
    }

    private func marchPoint(of unit: NullmereCore.Unit, at date: Date, camera: Camera, size: CGSize) -> CGPoint {
        guard !reduceMotion, let march = session.marches[unit.id], march.path.count > 1 else {
            return session.viewPoint(of: unit.position, in: size)
        }
        let progress = min(max(date.timeIntervalSince(march.start) / march.duration, 0), 1)
        let eased = progress * progress * (3 - 2 * progress)
        let along = eased * Double(march.path.count - 1)
        let step = min(Int(along), march.path.count - 2)
        let a = session.viewPoint(of: march.path[step], in: size)
        let b = session.viewPoint(of: march.path[step + 1], in: size)
        let f = along - Double(step)
        return CGPoint(x: a.x + (b.x - a.x) * f, y: a.y + (b.y - a.y) * f)
    }

    private func marks(at date: Date) -> some View {
        Canvas { context, size in
            let camera = session.camera
            let state = session.state
            let scale = camera.scale
            let player = session.player

            // The route the selected company would march.
            if !session.pathPreview.isEmpty, let unit = session.selectedUnit {
                var moves = unit.movesLeft
                var watch = 0
                var previous = session.viewPoint(of: unit.position, in: size)
                for hex in session.pathPreview {
                    let cost = state.map[hex]?.terrain.moveCost ?? 1
                    if moves < cost && moves < unit.kind.movement {
                        watch += 1
                        moves = unit.kind.movement
                    }
                    moves = max(0, moves - cost)
                    let point = session.viewPoint(of: hex, in: size)
                    var line = Path()
                    line.move(to: previous)
                    line.addLine(to: point)
                    context.stroke(line, with: .color(Palette.line(watch == 0 ? 0.55 : 0.28)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    previous = point
                }
                let end = session.viewPoint(of: session.pathPreview.last!, in: size)
                let ring = Path(ellipseIn: CGRect(x: end.x - 6, y: end.y - 6, width: 12, height: 12))
                context.stroke(ring, with: .color(Palette.line(0.7)), lineWidth: 1.2)
                if watch > 0 {
                    context.draw(
                        Text(verbatim: "\(watch + 1)").font(.nm(10, weight: .medium)).foregroundStyle(Palette.text(0.85)),
                        at: CGPoint(x: end.x, y: end.y - 14)
                    )
                }
            }

            // Where the selected company could march this watch: a faint
            // wash with an edge, and a red ring on what it could strike.
            if !session.reach.isEmpty || !session.strikeTargets.isEmpty {
                let layout = HexLayout(size: 1)
                var area = Path()
                for hex in session.reach {
                    let corners = layout.corners(of: hex).map { session.viewPoint(worldX: $0.x, worldY: $0.y, onHex: hex, in: size) }
                    guard let first = corners.first else { continue }
                    area.move(to: first)
                    for corner in corners.dropFirst() { area.addLine(to: corner) }
                    area.closeSubpath()
                }
                context.fill(area, with: .color(Palette.glow.opacity(0.09)))
                context.stroke(area, with: .color(Palette.glow.opacity(0.22)), lineWidth: 0.6)
                for hex in session.strikeTargets {
                    let point = session.viewPoint(of: hex, in: size)
                    let r = scale * 0.62
                    let ring = Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
                    context.stroke(ring, with: .color(Palette.bad.opacity(0.85)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
                }
            }

            // The flashes where blows land, the world's own where it is
            // drawn: a glow fading to its edge, with no filter to pay for.
            if !reduceMotion, !modelsDrawn {
                for blow in session.blows {
                    let flash = GameSession.Blow.flash(at: min(max(date.timeIntervalSince(blow.start) / GameSession.Blow.duration, 0), 1))
                    guard flash > 0 else { continue }
                    let point = session.viewPoint(of: blow.at, in: size)
                    let glow = scale * 0.4 * CGFloat(1.6 - flash * 0.6)
                    let disc = Path(ellipseIn: CGRect(x: point.x - glow, y: point.y - glow, width: glow * 2, height: glow * 2))
                    let warm = Color(red: 1, green: 0.88, blue: 0.68)
                    context.fill(disc, with: .radialGradient(Gradient(colors: [warm.opacity(0.7 * flash), warm.opacity(0)]),
                                                             center: point, startRadius: 0, endRadius: glow))
                }
            }

            // Blows: a ring spreading from where each fell, and the damage
            // rising and fading above it. Still, under Reduce Motion.
            for blow in session.blows {
                let age = reduceMotion ? 0.5 : min(max(date.timeIntervalSince(blow.start) / GameSession.Blow.duration, 0), 1)
                let point = session.viewPoint(of: blow.at, in: size)
                let fade = 1 - age
                // A bow's shot crossing the gap; the models loose their own arrows.
                if blow.isRanged, !reduceMotion, !modelsDrawn, age < 0.1 {
                    let origin = session.viewPoint(of: blow.from, in: size)
                    let t = CGFloat(age / 0.1)
                    let head = CGPoint(x: origin.x + (point.x - origin.x) * t, y: origin.y + (point.y - origin.y) * t)
                    let tail = CGPoint(x: origin.x + (point.x - origin.x) * max(t - 0.35, 0), y: origin.y + (point.y - origin.y) * max(t - 0.35, 0))
                    var shot = Path()
                    shot.move(to: tail)
                    shot.addLine(to: head)
                    context.stroke(shot, with: .color(Color(red: 1, green: 0.9, blue: 0.7).opacity(0.85)), lineWidth: 1.4)
                }
                // The fallen fade and sink where they stood; the models fall themselves.
                for fell in blow.fallen where !modelsDrawn {
                    let at = session.viewPoint(of: fell.at, in: size)
                    let r = min(max(scale * 0.34, 7), 16) * CGFloat(1 - 0.25 * age)
                    let sunk = CGPoint(x: at.x, y: at.y + CGFloat(8 * age))
                    let colour = Palette.house(state.houses[fell.owner]).opacity(0.8 * fade)
                    context.stroke(TokenArt.shield(at: sunk, radius: r), with: .color(colour), lineWidth: 1.2)
                    context.stroke(glyph(for: fell.kind, at: sunk, radius: r * 0.55), with: .color(colour), lineWidth: 1.1)
                }
                let colour = blow.againstPlayer ? Palette.bad : Color(red: 0.95, green: 0.93, blue: 0.86)
                if !modelsDrawn {
                    let radius = scale * (0.35 + 0.55 * age)
                    let ring = Path(ellipseIn: CGRect(x: point.x - radius, y: point.y - radius, width: radius * 2, height: radius * 2))
                    context.stroke(ring, with: .color(colour.opacity(0.75 * fade)), lineWidth: 1.6)
                }
                context.draw(
                    Text(verbatim: "−\(blow.damage)")
                        .font(.nm(12, weight: .semibold).monospacedDigit())
                        .foregroundStyle(colour.opacity(fade)),
                    at: CGPoint(x: point.x, y: point.y - scale * 0.6 - 18 * age)
                )
            }

            // Holds the player knows of; their names drawn after them, over
            // a dark shadow a hair below, unblurred.
            var names: [(text: Text, at: CGPoint, opacity: Double)] = []
            for hold in state.holds where session.isExplored(hold.position) {
                let point = session.viewPoint(of: hold.position, in: size)
                guard point.x > -80, point.y > -80, point.x < size.width + 80, point.y < size.height + 80 else { continue }
                let colour = Palette.house(state.houses[hold.owner])
                let r = min(max(scale * 0.36, 7), 18)
                // Enemies gather near it: a red ring, broken like a warning.
                if session.threatened.contains(hold.id) {
                    let ring = Path(ellipseIn: CGRect(x: point.x - r * 1.9, y: point.y - r * 1.9, width: r * 3.8, height: r * 3.8))
                    context.stroke(ring, with: .color(Palette.bad.opacity(0.6)), style: StrokeStyle(lineWidth: 1.4, dash: [4, 3]))
                }
                // Its marks stand under the token, or over the keep where it is drawn.
                var marks = point.y + r * 1.15
                if modelsDrawn {
                    marks = session.viewPoint(of: hold.position, in: size, lift: WorldMarks.holdLift(seat: hold.isSeat)).y
                } else {
                    token(of: hold, at: point, radius: r, colour: colour, in: &context)
                }
                // With "Differentiate without colour" on, whose it is is
                // said in shape too, as over a company: a bar over the
                // keeper's own, a cross by a foe's.
                if differentiate {
                    context.stroke(WorldMarks.ownership(hold.owner == player ? .own : state.isAtWar(player, hold.owner) ? .foe : .other,
                                                        at: modelsDrawn ? CGPoint(x: point.x, y: marks - r * 0.9) : point, radius: r * 1.6),
                                   with: .color(Palette.ink), lineWidth: 1.4)
                }
                if session.isVisible(hold.position), hold.ward < hold.maximumWard {
                    let width = r * 2
                    let fraction = CGFloat(hold.ward) / CGFloat(max(hold.maximumWard, 1))
                    let bar = CGRect(x: point.x - width / 2, y: marks, width: width, height: 2)
                    context.fill(Path(bar), with: .color(Color.black.opacity(0.7)))
                    context.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: width * fraction, height: 2)), with: .color(colour))
                }
                if scale >= 18 {
                    let name = Text(verbatim: hold.name.uppercased())
                        .font(.nm(min(max(scale * 0.3, 8.5), 12), weight: .medium))
                        .tracking(1.6)
                    // Below the token; over the keep, above its ward.
                    names.append((text: name, at: CGPoint(x: point.x, y: modelsDrawn ? marks - 10 : marks + 11),
                                  opacity: hold.owner == player ? 0.92 : 0.7))
                }
            }
            for name in names {
                // Laid out once, drawn twice.
                var resolved = context.resolve(name.text)
                resolved.shading = .color(Color.black.opacity(0.85))
                context.draw(resolved, at: CGPoint(x: name.at.x + 0.9, y: name.at.y + 0.9))
                resolved.shading = .color(Palette.text(name.opacity))
                context.draw(resolved, at: name.at)
            }

            // Companies the player can see.
            let fighting = Set(state.fieldsOfBattle.flatMap { $0.fighters.filter(\.standing).map(\.unit) })
            for unit in state.units where unit.owner == player || session.isVisible(unit.position) {
                var point = position(of: unit, at: date, camera: camera, size: size)
                guard point.x > -40, point.y > -40, point.x < size.width + 40, point.y < size.height + 40 else { continue }
                let colour = Palette.house(state.houses[unit.owner])
                // A company in a hold stands at its foot, smaller, so the hold
                // stays legible; drawn, it stands within the walls.
                let inHold = session.holdsByPosition[unit.position] != nil && session.marches[unit.id] == nil
                let r = min(max(scale * 0.34, 7), 16) * (inHold && !modelsDrawn ? 0.62 : 1)
                if modelsDrawn {
                    // Its marks over its figures' heads.
                    let ground = session.viewPoint(of: unit.position, in: size)
                    let lifted = session.viewPoint(of: unit.position, in: size, lift: WorldMarks.companyLift)
                    point = CGPoint(x: point.x + lifted.x - ground.x, y: point.y + lifted.y - ground.y - r - 4)
                } else {
                    if inHold {
                        point = CGPoint(x: point.x + r * 1.9, y: point.y + r * 0.9)
                    }
                    let isSelected = session.selectedUnit?.id == unit.id
                    let isHovered = session.hovered == unit.position && !inHold
                    token(of: unit, at: point, radius: r, colour: colour, selected: isSelected, hovered: isHovered, in: &context)
                }
                if differentiate {
                    context.stroke(WorldMarks.ownership(unit.owner == player ? .own : state.isAtWar(player, unit.owner) ? .foe : .other,
                                                        at: point, radius: r),
                                   with: .color(Palette.ink), lineWidth: 1.4)
                }
                // Rank: a small chevron for each, beneath the token.
                for chevron in 0..<unit.rank {
                    var mark = Path()
                    let y = point.y + r + 7 + CGFloat(chevron) * 3
                    mark.move(to: CGPoint(x: point.x - 4, y: y))
                    mark.addLine(to: CGPoint(x: point.x, y: y + 2.5))
                    mark.addLine(to: CGPoint(x: point.x + 4, y: y))
                    context.stroke(mark, with: .color(colour), lineWidth: 1.1)
                }
                if unit.owner == player, unit.movesLeft > 0, unit.destination == nil, !unit.fortified {
                    let dot = Path(ellipseIn: CGRect(x: point.x + r * 0.62, y: point.y - r * 1.02, width: 4, height: 4))
                    context.fill(dot, with: .color(Palette.ink))
                }
                if unit.health < 100 {
                    let fraction = CGFloat(unit.health) / 100
                    let bar = CGRect(x: point.x - r, y: point.y + r + 3, width: r * 2, height: 2)
                    context.fill(Path(bar), with: .color(Color.black.opacity(0.7)))
                    context.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: bar.width * fraction, height: 2)),
                                 with: .color(fraction > 0.5 ? Palette.good : Palette.bad))
                }
                // In a field of battle, its troops beneath it.
                if fighting.contains(unit.id) {
                    var troops = context.resolve(Text(verbatim: GameState.counted(state.troops(of: unit))).font(.nm(8.5, weight: .medium)))
                    let at = CGPoint(x: point.x, y: point.y + r + 11)
                    troops.shading = .color(Color.black.opacity(0.85))
                    context.draw(troops, at: CGPoint(x: at.x + 0.7, y: at.y + 0.7))
                    troops.shading = .color(Palette.text(0.9))
                    context.draw(troops, at: at)
                }
            }

            // Fields of battle: crossed blades over each one's heart, and
            // either side of them the troops each side has standing there,
            // in the colours of the House that leads it.
            for field in state.fieldsOfBattle {
                let point = session.viewPoint(of: field.at, in: size, lift: modelsDrawn ? WorldMarks.fieldLift : 0)
                guard point.x > -80, point.y > -80, point.x < size.width + 80, point.y < size.height + 80 else { continue }
                let y = point.y - (modelsDrawn ? 0 : min(max(scale * 0.34, 7), 16) * 2.4)
                let blade = min(max(scale * 0.2, 5), 9)
                var blades = Path()
                blades.move(to: CGPoint(x: point.x - blade, y: y - blade))
                blades.addLine(to: CGPoint(x: point.x + blade, y: y + blade))
                blades.move(to: CGPoint(x: point.x + blade, y: y - blade))
                blades.addLine(to: CGPoint(x: point.x - blade, y: y + blade))
                context.stroke(blades, with: .color(Color.black.opacity(0.6)), lineWidth: 3.4)
                context.stroke(blades, with: .color(Color(red: 1, green: 0.9, blue: 0.7)), lineWidth: 1.6)
                for side in field.sides.indices {
                    let leader = field.sides[side][0]
                    let colour = state.houses.indices.contains(leader) ? Palette.house(state.houses[leader]) : Palette.text(0.8)
                    let troops = Text(verbatim: GameState.counted(field.inField(side).troops)).font(.nm(10.5, weight: .medium))
                    let at = CGPoint(x: point.x + (side == 0 ? -1 : 1) * (blade + 5), y: y)
                    let anchor: UnitPoint = side == 0 ? .trailing : .leading
                    context.draw(troops.foregroundStyle(Color.black.opacity(0.85)), at: CGPoint(x: at.x + 0.8, y: at.y + 0.8), anchor: anchor)
                    context.draw(troops.foregroundStyle(colour), at: at, anchor: anchor)
                }
            }
        }
    }

    /// A hold drawn flat, where no models stand: its keep, its walls and
    /// towers as its walls rise, a warm window, the seat's banner, and the
    /// moonspire's needle.
    private func token(of hold: Hold, at point: CGPoint, radius r: CGFloat, colour: Color, in context: inout GraphicsContext) {
        let towers = TokenArt.towerCount(for: hold)
        if towers > 0 {
            let flanks = TokenArt.towers(at: point, radius: r, count: towers)
            context.fill(flanks, with: .color(Color(red: 0.04, green: 0.045, blue: 0.06).opacity(0.92)))
            context.stroke(flanks, with: .color(colour.opacity(0.8)), lineWidth: 1)
        }
        let keep = TokenArt.keep(at: point, radius: r, seat: hold.isSeat)
        if hold.level(.walls) > 0 {
            let walls = TokenArt.walls(at: point, radius: r)
            context.fill(walls, with: .color(Color.black.opacity(0.55)))
            context.stroke(walls, with: .color(colour.opacity(0.7)), lineWidth: CGFloat(hold.level(.walls)) * 0.5 + 0.6)
        }
        context.fill(keep, with: .color(Color(red: 0.04, green: 0.045, blue: 0.06).opacity(0.92)))
        context.stroke(keep, with: .color(colour), lineWidth: hold.isSeat ? 1.6 : 1.2)
        // One warm window: someone keeps the lamp lit.
        context.fill(TokenArt.window(at: point, radius: r), with: .color(Color(red: 1.0, green: 0.76, blue: 0.45)))
        if hold.isSeat {
            let banner = TokenArt.banner(at: point, radius: r)
            context.stroke(banner.pole, with: .color(colour), lineWidth: 1.1)
            context.fill(banner.pennant, with: .color(colour))
        }
        if hold.level(.moonspire) > 0 {
            let spire = CGFloat(hold.level(.moonspire))
            let top = TokenArt.keepTop(at: point, radius: r, seat: hold.isSeat)
            var needle = Path()
            needle.move(to: CGPoint(x: point.x - r * 0.35, y: top))
            needle.addLine(to: CGPoint(x: point.x - r * 0.35, y: top - r * 0.45 * spire))
            context.stroke(needle, with: .color(Color(red: 0.86, green: 0.9, blue: 1.0)), lineWidth: 1.6)
        }
    }

    /// A company drawn flat, where no models stand: a shield with its
    /// kind's glyph, bolder dug in, and a halo chosen or under the pointer.
    private func token(of unit: NullmereCore.Unit, at point: CGPoint, radius r: CGFloat, colour: Color, selected: Bool, hovered: Bool,
                       in context: inout GraphicsContext) {
        let disc = TokenArt.shield(at: point, radius: r)
        context.fill(disc, with: .color(Color(red: 0.03, green: 0.035, blue: 0.05).opacity(0.9)))
        context.stroke(disc, with: .color(colour), lineWidth: unit.fortified ? 2.2 : 1.3)
        // The chosen company wears a bright halo; the one under the
        // pointer a faint one.
        if selected || hovered {
            let halo = Path(ellipseIn: CGRect(x: point.x - r - 3, y: point.y - r - 3, width: (r + 3) * 2, height: (r + 3) * 2))
            context.stroke(halo, with: .color(Palette.line(selected ? 0.9 : 0.4)), lineWidth: selected ? 1.4 : 1)
        }
        context.stroke(glyph(for: unit.kind, at: point, radius: r * 0.55), with: .color(colour), lineWidth: 1.3)
    }

    enum Ownership { case own, foe, other }

    /// The mark that says whose a company is without colour: a bar above
    /// the keeper's own, a cross at a foe's shoulder, nothing for others.
    static func ownership(_ whose: Ownership, at c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        switch whose {
        case .own:
            p.move(to: CGPoint(x: c.x - r * 0.5, y: c.y - r - 4))
            p.addLine(to: CGPoint(x: c.x + r * 0.5, y: c.y - r - 4))
        case .foe:
            let x = c.x - r * 0.95, y = c.y - r * 0.95, d: CGFloat = 3.5
            p.move(to: CGPoint(x: x - d, y: y - d))
            p.addLine(to: CGPoint(x: x + d, y: y + d))
            p.move(to: CGPoint(x: x + d, y: y - d))
            p.addLine(to: CGPoint(x: x - d, y: y + d))
        case .other:
            break
        }
        return p
    }

    /// A simple line drawing for each kind of company.
    private func glyph(for kind: UnitKind, at c: CGPoint, radius r: CGFloat) -> Path {
        var p = Path()
        switch kind {
        case .lantern:
            p.move(to: CGPoint(x: c.x, y: c.y - r))
            p.addLine(to: CGPoint(x: c.x + r * 0.7, y: c.y))
            p.addLine(to: CGPoint(x: c.x, y: c.y + r))
            p.addLine(to: CGPoint(x: c.x - r * 0.7, y: c.y))
            p.closeSubpath()
        case .spear:
            p.move(to: CGPoint(x: c.x, y: c.y + r))
            p.addLine(to: CGPoint(x: c.x, y: c.y - r))
            p.move(to: CGPoint(x: c.x - r * 0.4, y: c.y - r * 0.45))
            p.addLine(to: CGPoint(x: c.x, y: c.y - r))
            p.addLine(to: CGPoint(x: c.x + r * 0.4, y: c.y - r * 0.45))
        case .bow:
            p.addArc(center: CGPoint(x: c.x - r * 0.3, y: c.y), radius: r, startAngle: .degrees(-60), endAngle: .degrees(60), clockwise: false)
            p.move(to: CGPoint(x: c.x + r * 0.2, y: c.y - r * 0.87))
            p.addLine(to: CGPoint(x: c.x + r * 0.2, y: c.y + r * 0.87))
        case .rider:
            p.move(to: CGPoint(x: c.x - r, y: c.y + r * 0.2))
            p.addLine(to: CGPoint(x: c.x, y: c.y - r * 0.6))
            p.addLine(to: CGPoint(x: c.x + r, y: c.y + r * 0.2))
            p.move(to: CGPoint(x: c.x - r, y: c.y + r * 0.8))
            p.addLine(to: CGPoint(x: c.x, y: c.y))
            p.addLine(to: CGPoint(x: c.x + r, y: c.y + r * 0.8))
        case .founder:
            p.move(to: CGPoint(x: c.x - r * 0.75, y: c.y + r * 0.7))
            p.addLine(to: CGPoint(x: c.x - r * 0.75, y: c.y - r * 0.1))
            p.addLine(to: CGPoint(x: c.x, y: c.y - r * 0.8))
            p.addLine(to: CGPoint(x: c.x + r * 0.75, y: c.y - r * 0.1))
            p.addLine(to: CGPoint(x: c.x + r * 0.75, y: c.y + r * 0.7))
            p.closeSubpath()
        }
        return p
    }
}

/// A still painting of the map, for when Metal can't run: the ground the
/// keeper knows, each hold's land washed in its House's colour, the moon in
/// the water, and the tile under the pointer and the one chosen outlined,
/// so the game plays as it does on the full map.
struct WorldFallback: View {
    let session: GameSession

    /// How far the current drag, or pinch, has gone already.
    @State private var dragged: CGSize = .zero
    @State private var pinched: CGFloat = 1

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                WorldFallback.paint(session, in: &context, size: size)
            }
            .contentShape(Rectangle())
            // Without Metal there is no right-click: a click where the
            // chosen company would march or strike gives that order, as
            // the pointer shows; anywhere else it selects. The keys pan and
            // zoom as on the full map.
            .gesture(SpatialTapGesture().onEnded { value in
                WorldFallback.tap(session.camera.hex(at: value.location, in: proxy.size), in: session)
            })
            // Dragged and pinched, as the Metal map is.
            .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                WorldFallback.drag(by: CGSize(width: value.translation.width - dragged.width,
                                              height: value.translation.height - dragged.height), in: session)
                dragged = value.translation
            }.onEnded { _ in dragged = .zero })
            .simultaneousGesture(MagnifyGesture().onChanged { value in
                WorldFallback.zoom(by: value.magnification / pinched, around: value.startLocation, in: proxy.size, session: session)
                pinched = value.magnification
            }.onEnded { _ in pinched = 1 })
            .onContinuousHover { phase in
                switch phase {
                case .active(let point): session.hover(session.camera.hex(at: point, in: proxy.size))
                case .ended: session.hover(nil)
                }
            }
        }
    }

    static let water = Color(red: 0.004, green: 0.006, blue: 0.012)
    /// The unknown, as the Metal map's mist: paler than the black water.
    static let mist = Color(red: 0.030, green: 0.034, blue: 0.048)
    /// The moon's light, and its face in the water, as the Metal map has them.
    static let moonlight = Color(red: 0.58, green: 0.68, blue: 0.86)

    static func paint(_ session: GameSession, in context: inout GraphicsContext, size: CGSize) {
        context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(mist))
        let camera = session.camera
        let state = session.state
        let territory = session.territory
        for (index, hex) in state.map.hexes.enumerated() where session.playerHouse.explored[index] {
            guard let hexagon = path(of: hex, camera: camera, in: size) else { continue }
            let terrain = state.map[index].terrain
            let tint = colour(for: terrain)
            let seen = session.visible.indices.contains(index) && session.visible[index]
            context.fill(hexagon, with: .color(seen ? tint : tint.opacity(0.5)))
            // Stars held in the still water, warm and cold, as the Metal map
            // gives them back: one now and then, where it falls in the hex.
            if terrain == .still {
                let chance = ((hex.q &* 73_856_093) ^ (hex.r &* 19_349_663)) & 1023
                if chance < 260 {
                    let centre = HexLayout(size: 1).center(of: hex)
                    let spot = camera.viewPoint(worldX: centre.x + Double(chance % 7) / 10 - 0.3,
                                                worldY: centre.y + Double(chance % 5) / 8 - 0.25, in: size)
                    let warm = Double(chance % 11) / 10
                    let star = Color(red: 0.76 + 0.24 * warm * warm, green: 0.85 + 0.07 * warm * warm, blue: 1.0 - 0.18 * warm * warm)
                    let radius = chance % 3 == 0 ? 1.2 : 0.7
                    context.fill(Path(ellipseIn: CGRect(x: spot.x - radius, y: spot.y - radius, width: radius * 2, height: radius * 2)),
                                 with: .color(star.opacity(0.35 + Double(chance % 13) / 26)))
                }
            }
            // Whose land it is, as a faint wash of the House's colour.
            if territory.indices.contains(index), let holdID = territory[index], let owner = state.hold(holdID)?.owner,
               state.houses.indices.contains(owner) {
                context.fill(hexagon, with: .color(Palette.house(state.houses[owner]).opacity(seen ? 0.16 : 0.08)))
            }
        }
        // The moon, lying in the still water, where the keeper knows it: its
        // halo the Metal map's, layer by layer, and its face darker at the rim.
        let moon = session.moon
        let moonHex = HexLayout(size: 1).hex(atX: Double(moon.x), y: Double(moon.y))
        let moonKnown = state.map.index(of: moonHex).map { session.playerHouse.explored[$0] } ?? false
        if moon.w > 0, moonKnown {
            let centre = camera.viewPoint(worldX: Double(moon.x), worldY: Double(moon.y), in: size)
            let radius = max(Double(moon.z) * camera.scale, 2)
            let reach = radius * 20
            context.fill(Path(ellipseIn: CGRect(x: centre.x - reach, y: centre.y - reach, width: reach * 2, height: reach * 2)),
                         with: .radialGradient(Gradient(stops: [
                             .init(color: moonlight.opacity(0.44), location: 0.05),
                             .init(color: moonlight.opacity(0.11), location: 0.1),
                             .init(color: moonlight.opacity(0.05), location: 0.2),
                             .init(color: moonlight.opacity(0.018), location: 0.45),
                             .init(color: .clear, location: 1),
                         ]), center: centre, startRadius: 0, endRadius: reach))
            context.fill(Path(ellipseIn: CGRect(x: centre.x - radius, y: centre.y - radius, width: radius * 2, height: radius * 2)),
                         with: .radialGradient(Gradient(colors: [Color(red: 0.80, green: 0.82, blue: 0.84), Color(red: 0.70, green: 0.72, blue: 0.74)]),
                                               center: centre, startRadius: 0, endRadius: radius))
        }
        if let hovered = session.hovered, let outline = path(of: hovered, camera: camera, in: size) {
            context.stroke(outline, with: .color(Palette.line(0.45)), lineWidth: 1)
        }
        if let selected = session.selectedHex, let outline = path(of: selected, camera: camera, in: size) {
            context.stroke(outline, with: .color(Palette.glow), lineWidth: 2)
        }
    }

    /// A hex's outline on screen, if any of it is.
    static func path(of hex: Hex, camera: Camera, in size: CGSize) -> Path? {
        let corners = HexLayout(size: 1).corners(of: hex).map { camera.viewPoint(worldX: $0.x, worldY: $0.y, in: size) }
        guard let first = corners.first,
              corners.contains(where: { $0.x > 0 && $0.y > 0 && $0.x < size.width && $0.y < size.height })
        else { return nil }
        var hexagon = Path()
        hexagon.move(to: first)
        for corner in corners.dropFirst() { hexagon.addLine(to: corner) }
        hexagon.closeSubpath()
        return hexagon
    }

    static func drag(by step: CGSize, in session: GameSession) {
        session.camera.pan(dx: step.width, dy: step.height)
        session.camera.clamp(toRadius: session.state.map.radius)
    }

    static func zoom(by factor: CGFloat, around anchor: CGPoint, in size: CGSize, session: GameSession) {
        session.camera.zoom(by: factor, around: anchor, in: size)
        session.camera.clamp(toRadius: session.state.map.radius)
    }

    static func tap(_ hex: Hex, in session: GameSession) {
        switch session.pointerAction(at: hex) {
        case .march, .strike: session.order(hex)
        case .select, .none: session.click(hex)
        }
    }

    static func colour(for terrain: Terrain) -> Color {
        switch terrain {
        case .still: return water
        case .shallows: return Color(red: 0.022, green: 0.029, blue: 0.037)
        case .strand: return Color(red: 0.36, green: 0.355, blue: 0.34)
        case .saltFlat: return Color(red: 0.71, green: 0.745, blue: 0.80)
        case .greyfield: return Color(red: 0.21, green: 0.23, blue: 0.21)
        case .blackwood: return Color(red: 0.058, green: 0.076, blue: 0.07)
        case .barrow: return Color(red: 0.22, green: 0.2, blue: 0.18)
        case .spine: return Color(red: 0.14, green: 0.14, blue: 0.16)
        }
    }
}

/// The odds of the attack under the pointer, beside the target.
struct ForecastOverlay: View {
    let session: GameSession

    var body: some View {
        GeometryReader { proxy in
            if let forecast = session.hoverForecast, let hex = session.hovered {
                let point = session.viewPoint(of: hex, in: proxy.size)
                ForecastCard(forecast: forecast, targetName: targetName(forecast))
                    .fixedSize()
                    .position(x: point.x, y: point.y - max(session.camera.scale * 0.9, 26) - 30)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.12), value: session.hoverForecast)
    }

    private func targetName(_ forecast: Forecast) -> String {
        switch forecast.target {
        case .unit(let kind): return kind.title
        case .hold(let id): return session.state.hold(id)?.name ?? "the hold"
        case .wild(let kind, _): return kind.title
        }
    }
}

struct ForecastCard: View {
    let forecast: Forecast
    let targetName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Caps("Strike \(targetName)", size: 8.5, weight: .medium)
                .foregroundStyle(Palette.ink)
            line(isHold ? "Ward" : "They take", range: forecast.dealt, of: forecast.defenderHealth,
                 colour: forecast.mayFinish ? Palette.good : Palette.text(0.8))
            if forecast.taken.upperBound > 0 {
                line("You take", range: forecast.taken, of: forecast.attackerHealth,
                     colour: forecast.mayFall ? Palette.bad : Palette.text(0.8))
            } else {
                Text(verbatim: "Out of their reach").font(.nm(10)).foregroundStyle(Palette.text(0.55))
            }
            if let verdict {
                Text(verbatim: verdict).font(.nm(10, weight: .medium)).foregroundStyle(Palette.glowWords)
            }
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .panelBackground()
        .accessibilityElement(children: .combine)
    }

    private var isHold: Bool {
        if case .hold = forecast.target { return true }
        return false
    }

    private var verdict: String? {
        if isHold {
            if forecast.surelyFinishes { return forecast.couldCapture ? "The ward breaks; the hold is taken" : "The ward breaks" }
            if forecast.mayFinish { return "The ward may break" }
            return nil
        }
        if forecast.surelyFinishes {
            if forecast.couldCapture { return "They fall; the hold is taken" }
            return forecast.takesTheField ? "They fall; you take their ground" : "They fall"
        }
        if forecast.mayFinish { return "They may fall" }
        return nil
    }

    private func line(_ label: String, range: ClosedRange<Int>, of total: Int, colour: Color) -> some View {
        HStack(spacing: 6) {
            Caps(label, size: 7.5).foregroundStyle(Palette.text(0.5))
            Text(verbatim: range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)")
                .font(.nm(11).monospacedDigit())
                .foregroundStyle(colour)
            Text(verbatim: "of \(total)").font(.nm(10)).foregroundStyle(Palette.text(0.45))
        }
    }
}

extension WorldView {
    /// Each House's colour by its sigil, as the world's shaders take it:
    /// the interface's own colours, made linear.
    nonisolated static let houseColours: [Vec4] = Palette.houseRGB.map {
        Vec4(Float(pow($0.red, 2.2)), Float(pow($0.green, 2.2)), Float(pow($0.blue, 2.2)), 1)
    }
}
