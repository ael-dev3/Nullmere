import AppKit
import NullmereCore
import SwiftUI

/// The whole lake in the corner: the country the House has found, the
/// holds it knows in their Houses' colours, its own companies, and where
/// the view looks; a click there carries the view to it.
struct MiniMap: View {
    let session: GameSession

    static let side: CGFloat = 148

    /// Where the keeper's choice to show it is kept: hidden until asked for.
    static let shownKey = "minimap.shown"

    /// The hexes' layout in the map's square, the lake's width filling it.
    static func layout(radius: Int, side: CGFloat = side) -> HexLayout {
        HexLayout(size: Double(side) / (3.0.squareRoot() * Double(2 * radius + 1)))
    }

    /// Where a hex lies in the map's square.
    static func point(of hex: Hex, radius: Int, side: CGFloat = side) -> CGPoint {
        let centre = layout(radius: radius, side: side).center(of: hex)
        return CGPoint(x: Double(side) / 2 + centre.x, y: Double(side) / 2 + centre.y)
    }

    /// The hex at a point of the map's square.
    static func hex(at point: CGPoint, radius: Int, side: CGFloat = side) -> Hex {
        layout(radius: radius, side: side).hex(atX: Double(point.x) - Double(side) / 2, y: Double(point.y) - Double(side) / 2)
    }

    /// Carries the view to the hex at a point of the map, if it is the lake's.
    @MainActor
    static func look(at point: CGPoint, in session: GameSession) {
        let hex = hex(at: point, radius: session.state.map.radius)
        guard session.state.map[hex] != nil else { return }
        session.glide(to: hex)
    }

    /// What the map shows, in words.
    @MainActor
    static func spoken(_ session: GameSession) -> String {
        let state = session.state
        let holds = state.holds(of: session.player).count
        let known = state.holds.filter { $0.owner != session.player && session.isExplored($0.position) }.count
        let companies = state.units(of: session.player).count
        return "\(holds) hold\(holds == 1 ? "" : "s") of yours, \(known) of other Houses known, \(companies) compan\(companies == 1 ? "y" : "ies") of yours"
    }

    var body: some View {
        let state = session.state
        let radius = state.map.radius
        let side = Self.side
        ZStack {
            if let ground = session.miniMapGround(side: side) {
                Image(decorative: ground, scale: 2)
                    .resizable()
                    .interpolation(.medium)
                    .frame(width: side, height: side)
            }
            Canvas { context, size in
                let mark = max(2.5, size.width / CGFloat(2 * radius + 1))
                for hold in state.holds where hold.owner == session.player || session.isExplored(hold.position) {
                    let p = Self.point(of: hold.position, radius: radius, side: size.width)
                    let square = CGRect(x: p.x - mark, y: p.y - mark, width: mark * 2, height: mark * 2)
                    context.fill(Path(square), with: .color(Palette.house(state.houses[hold.owner])))
                    if hold.isSeat { context.stroke(Path(square.insetBy(dx: -1, dy: -1)), with: .color(Palette.ink.opacity(0.7)), lineWidth: 0.8) }
                }
                for unit in state.units(of: session.player) {
                    let p = Self.point(of: unit.position, radius: radius, side: size.width)
                    context.fill(Path(ellipseIn: CGRect(x: p.x - 1.6, y: p.y - 1.6, width: 3.2, height: 3.2)), with: .color(Palette.ink))
                }
                // Where the view looks.
                let centre = Self.point(of: session.camera.centreHex, radius: radius, side: size.width)
                context.stroke(Path(ellipseIn: CGRect(x: centre.x - 7, y: centre.y - 7, width: 14, height: 14)),
                               with: .color(Palette.glow), lineWidth: 1.2)
            }
            .frame(width: side, height: side)
        }
        .contentShape(Rectangle())
        .onTapGesture { location in Self.look(at: location, in: session) }
        .padding(6)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 3))
        // One element, saying what the map shows. VoiceOver walks the lake
        // itself by the map's own elements, every hold and company, and
        // pans to them as they are chosen. No tooltip: AppKit's tooltip
        // host stands outside these words and showed as an unnamed image.
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("The whole lake")
        .accessibilityValue(Self.spoken(session))
        .accessibilityAddTraits(.isImage)
    }
}

extension GameSession {
    /// The small map's ground, the country the House has found: drawn
    /// once each time the world changes, not at every pan of the view.
    func miniMapGround(side: CGFloat) -> CGImage? {
        let pixels = Int(side * 2)
        if let kept = miniGround, kept.version == tilesVersion, kept.image.width == pixels { return kept.image }
        guard let context = CGContext(data: nil, width: pixels, height: pixels, bitsPerComponent: 8, bytesPerRow: 0,
                                      space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
        else { return nil }
        let map = state.map
        let radius = map.radius
        let explored = state.houses.indices.contains(player) ? state.houses[player].explored : []
        let cell = CGFloat(pixels) / CGFloat(2 * radius + 1) * 1.08
        var colours: [Terrain: CGColor] = [:]
        // Drawn top down, as the view is.
        context.translateBy(x: 0, y: CGFloat(pixels))
        context.scaleBy(x: 1, y: -1)
        for index in 0..<map.count where explored.indices.contains(index) && explored[index] {
            let terrain = map[index].terrain
            let colour = colours[terrain] ?? NSColor(WorldFallback.colour(for: terrain)).cgColor
            colours[terrain] = colour
            let p = MiniMap.point(of: map.hex(at: index), radius: radius, side: CGFloat(pixels))
            context.setFillColor(colour)
            context.fillEllipse(in: CGRect(x: p.x - cell / 2, y: p.y - cell / 2, width: cell, height: cell))
        }
        guard let image = context.makeImage() else { return nil }
        miniGround = (tilesVersion, image)
        return image
    }
}

/// The camera's buttons, under the small map while it is shown: nearer and
/// further, turned either way, and the view set back to take in the whole
/// House. The keys, the trackpad and the mouse do all of it as well.
struct CameraButtons: View {
    let session: GameSession

    var body: some View {
        HStack(spacing: 2) {
            QuietButton(title: "−", size: 11, name: "Zoom out") { session.camera.zoom(by: 0.8) }
            QuietButton(title: "+", size: 11, name: "Zoom in") { session.camera.zoom(by: 1.25) }
            QuietButton(title: "⟲", size: 11, name: "Turn left") { session.camera.turn(by: -.pi / 6) }
            QuietButton(title: "⟳", size: 11, name: "Turn right") { session.camera.turn(by: .pi / 6) }
            QuietButton(title: "Reset", size: 8.5, name: "Reset View") { session.resetView() }
                .help("Take in the whole House, north up (⌘0)")
        }
        .padding(.horizontal, 6)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 3))
    }
}
