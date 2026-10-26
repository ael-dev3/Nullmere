import AppKit
import NullmereCore
import SwiftUI

/// The map: the Metal world, with holds, companies and the marching route
/// drawn over it, and pointer input routed to the session.
struct WorldView: View {
    let session: GameSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var metalFailed = false

    var body: some View {
        ZStack {
            if metalFailed || WorldMetalView.systemDevice == nil {
                WorldFallback(session: session)
            } else {
                WorldMetalRepresentable(session: session, animates: !reduceMotion) {
                    metalFailed = true
                }
            }
            WorldMarks(session: session)
                .allowsHitTesting(false)
            ForecastOverlay(session: session)
                .allowsHitTesting(false)
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("The world map")
    }
}

private struct WorldMetalRepresentable: NSViewRepresentable {
    let session: GameSession
    let animates: Bool
    let onFailure: () -> Void

    func makeNSView(context: Context) -> WorldMetalView {
        let view = WorldMetalView()
        view.onFailure = onFailure
        view.onHover = { hex in session.hover(hex) }
        view.onClick = { hex in session.click(hex) }
        view.onSecondaryClick = { hex in session.order(hex) }
        view.onCameraChange = { camera in session.camera = camera }
        update(view)
        return view
    }

    func updateNSView(_ view: WorldMetalView, context: Context) {
        update(view)
    }

    private func update(_ view: WorldMetalView) {
        view.radius = session.state.map.radius
        view.camera = session.camera
        view.hovered = session.hovered
        view.selected = session.selectedHex
        view.animates = animates
        view.setTiles(session.tileBytes, side: TileTexture.side(for: session.state.map), version: session.tilesVersion)
    }
}

/// Holds, companies and routes, drawn in one pass over the map.
private struct WorldMarks: View {
    let session: GameSession

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(paused: session.marches.isEmpty || reduceMotion)) { timeline in
            marks(at: timeline.date)
        }
    }

    /// Where a company is drawn: along its march while one is shown.
    private func position(of unit: NullmereCore.Unit, at date: Date, camera: Camera, size: CGSize) -> CGPoint {
        guard !reduceMotion, let march = session.marches[unit.id], march.path.count > 1 else {
            return camera.viewPoint(of: unit.position, in: size)
        }
        let progress = min(max(date.timeIntervalSince(march.start) / march.duration, 0), 1)
        let eased = progress * progress * (3 - 2 * progress)
        let along = eased * Double(march.path.count - 1)
        let step = min(Int(along), march.path.count - 2)
        let a = camera.viewPoint(of: march.path[step], in: size)
        let b = camera.viewPoint(of: march.path[step + 1], in: size)
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
                var previous = camera.viewPoint(of: unit.position, in: size)
                for hex in session.pathPreview {
                    let cost = state.map[hex]?.terrain.moveCost ?? 1
                    if moves < cost && moves < unit.kind.movement {
                        watch += 1
                        moves = unit.kind.movement
                    }
                    moves = max(0, moves - cost)
                    let point = camera.viewPoint(of: hex, in: size)
                    var line = Path()
                    line.move(to: previous)
                    line.addLine(to: point)
                    context.stroke(line, with: .color(Palette.ink.opacity(watch == 0 ? 0.55 : 0.28)), style: StrokeStyle(lineWidth: 1.2, dash: [3, 4]))
                    previous = point
                }
                let end = camera.viewPoint(of: session.pathPreview.last!, in: size)
                let ring = Path(ellipseIn: CGRect(x: end.x - 6, y: end.y - 6, width: 12, height: 12))
                context.stroke(ring, with: .color(Palette.ink.opacity(0.7)), lineWidth: 1.2)
                if watch > 0 {
                    context.draw(
                        Text(verbatim: "\(watch + 1)").font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.ink.opacity(0.85)),
                        at: CGPoint(x: end.x, y: end.y - 14)
                    )
                }
            }

            // Holds the player knows of.
            for hold in state.holds where session.isExplored(hold.position) {
                let point = camera.viewPoint(of: hold.position, in: size)
                guard point.x > -80, point.y > -80, point.x < size.width + 80, point.y < size.height + 80 else { continue }
                let colour = Palette.house(state.houses[hold.owner])
                let r = min(max(scale * 0.36, 7), 18)
                var tower = Path()
                tower.move(to: CGPoint(x: point.x, y: point.y - r * 1.25))
                tower.addLine(to: CGPoint(x: point.x + r * 0.8, y: point.y - r * 0.2))
                tower.addLine(to: CGPoint(x: point.x + r * 0.8, y: point.y + r * 0.9))
                tower.addLine(to: CGPoint(x: point.x - r * 0.8, y: point.y + r * 0.9))
                tower.addLine(to: CGPoint(x: point.x - r * 0.8, y: point.y - r * 0.2))
                tower.closeSubpath()
                context.fill(tower, with: .color(Color.black.opacity(0.75)))
                context.stroke(tower, with: .color(colour), lineWidth: hold.isSeat ? 2 : 1.3)
                if hold.isSeat {
                    let crown = Path(ellipseIn: CGRect(x: point.x - r * 0.28, y: point.y - r * 0.05, width: r * 0.56, height: r * 0.56))
                    context.fill(crown, with: .color(colour))
                }
                if hold.level(.moonspire) > 0 {
                    let spire = CGFloat(hold.level(.moonspire))
                    var needle = Path()
                    needle.move(to: CGPoint(x: point.x, y: point.y - r * 1.25))
                    needle.addLine(to: CGPoint(x: point.x, y: point.y - r * (1.25 + 0.5 * spire)))
                    context.stroke(needle, with: .color(Color.white.opacity(0.9)), lineWidth: 1.5)
                }
                if session.isVisible(hold.position), hold.ward < hold.maximumWard {
                    let width = r * 2
                    let fraction = CGFloat(hold.ward) / CGFloat(max(hold.maximumWard, 1))
                    let bar = CGRect(x: point.x - width / 2, y: point.y + r * 1.15, width: width, height: 2)
                    context.fill(Path(bar), with: .color(Color.black.opacity(0.7)))
                    context.fill(Path(CGRect(x: bar.minX, y: bar.minY, width: width * fraction, height: 2)), with: .color(colour))
                }
                if scale >= 18 {
                    let name = Text(verbatim: hold.name.uppercased())
                        .font(.system(size: min(max(scale * 0.3, 8.5), 12), weight: .medium))
                        .tracking(1.6)
                    let at = CGPoint(x: point.x, y: point.y + r * 1.15 + 11)
                    var shadow = context
                    shadow.addFilter(.blur(radius: 3))
                    shadow.draw(name.foregroundStyle(Color.black), at: at)
                    context.draw(name.foregroundStyle(Palette.ink.opacity(hold.owner == player ? 0.92 : 0.7)), at: at)
                }
            }

            // Companies the player can see.
            for unit in state.units where unit.owner == player || session.isVisible(unit.position) {
                var point = position(of: unit, at: date, camera: camera, size: size)
                guard point.x > -40, point.y > -40, point.x < size.width + 40, point.y < size.height + 40 else { continue }
                // A company in a hold stands at its foot, smaller, so the hold stays legible.
                let inHold = state.hold(at: unit.position) != nil && session.marches[unit.id] == nil
                let colour = Palette.house(state.houses[unit.owner])
                let r = min(max(scale * 0.34, 7), 16) * (inHold ? 0.62 : 1)
                if inHold {
                    point = CGPoint(x: point.x + r * 1.9, y: point.y + r * 0.9)
                }
                let disc = Path(ellipseIn: CGRect(x: point.x - r, y: point.y - r, width: r * 2, height: r * 2))
                context.fill(disc, with: .color(Color.black.opacity(0.78)))
                context.stroke(disc, with: .color(colour), lineWidth: unit.fortified ? 2.2 : 1.3)
                context.stroke(glyph(for: unit.kind, at: point, radius: r * 0.55), with: .color(colour), lineWidth: 1.3)
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
            }
        }
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

/// A still painting of the map, for when Metal can't run.
private struct WorldFallback: View {
    let session: GameSession

    var body: some View {
        GeometryReader { proxy in
            Canvas { context, size in
                context.fill(Path(CGRect(origin: .zero, size: size)), with: .color(Color(red: 0.004, green: 0.006, blue: 0.012)))
                let camera = session.camera
                let state = session.state
                let layout = HexLayout(size: 1)
                for (index, hex) in state.map.hexes.enumerated() where session.playerHouse.explored[index] {
                    let corners = layout.corners(of: hex).map { camera.viewPoint(worldX: $0.x, worldY: $0.y, in: size) }
                    guard let first = corners.first,
                          corners.contains(where: { $0.x > 0 && $0.y > 0 && $0.x < size.width && $0.y < size.height })
                    else { continue }
                    var hexagon = Path()
                    hexagon.move(to: first)
                    for corner in corners.dropFirst() { hexagon.addLine(to: corner) }
                    hexagon.closeSubpath()
                    let tint = WorldFallback.colour(for: state.map[index].terrain)
                    context.fill(hexagon, with: .color(session.visible[index] ? tint : tint.opacity(0.5)))
                }
            }
            .contentShape(Rectangle())
            .gesture(SpatialTapGesture().onEnded { value in
                session.click(session.camera.hex(at: value.location, in: proxy.size))
            })
        }
    }

    static func colour(for terrain: Terrain) -> Color {
        switch terrain {
        case .still: return Color(red: 0.004, green: 0.006, blue: 0.012)
        case .shallows: return Color(red: 0.02, green: 0.03, blue: 0.04)
        case .strand: return Color(red: 0.34, green: 0.34, blue: 0.33)
        case .saltFlat: return Color(red: 0.7, green: 0.73, blue: 0.78)
        case .greyfield: return Color(red: 0.2, green: 0.22, blue: 0.2)
        case .blackwood: return Color(red: 0.04, green: 0.06, blue: 0.06)
        case .barrow: return Color(red: 0.22, green: 0.2, blue: 0.18)
        case .spine: return Color(red: 0.1, green: 0.1, blue: 0.12)
        }
    }
}

/// The odds of the attack under the pointer, beside the target.
private struct ForecastOverlay: View {
    let session: GameSession

    var body: some View {
        GeometryReader { proxy in
            if let forecast = session.hoverForecast, let hex = session.hovered {
                let point = session.camera.viewPoint(of: hex, in: proxy.size)
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
        }
    }
}

private struct ForecastCard: View {
    let forecast: Forecast
    let targetName: String

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Caps(isHold ? "Strike \(targetName)" : "Attack \(targetName)", size: 8.5, weight: .medium)
                .foregroundStyle(Palette.ink)
            line(isHold ? "Ward" : "They take", range: forecast.dealt, of: forecast.defenderHealth,
                 colour: forecast.mayFinish ? Palette.good : Palette.ink.opacity(0.8))
            if forecast.taken.upperBound > 0 {
                line("You take", range: forecast.taken, of: forecast.attackerHealth,
                     colour: forecast.mayFall ? Palette.bad : Palette.ink.opacity(0.8))
            } else {
                Text(verbatim: "Out of their reach").font(.system(size: 10)).foregroundStyle(Palette.ink.opacity(0.55))
            }
            if let verdict {
                Text(verbatim: verdict).font(.system(size: 10, weight: .medium)).foregroundStyle(Palette.glow)
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
        if forecast.surelyFinishes { return "They fall" }
        if forecast.mayFinish { return "They may fall" }
        return nil
    }

    private func line(_ label: String, range: ClosedRange<Int>, of total: Int, colour: Color) -> some View {
        HStack(spacing: 6) {
            Caps(label, size: 7.5).foregroundStyle(Palette.ink.opacity(0.5))
            Text(verbatim: range.lowerBound == range.upperBound ? "\(range.lowerBound)" : "\(range.lowerBound)–\(range.upperBound)")
                .font(.system(size: 11).monospacedDigit())
                .foregroundStyle(colour)
            Text(verbatim: "of \(total)").font(.system(size: 10)).foregroundStyle(Palette.ink.opacity(0.45))
        }
    }
}
