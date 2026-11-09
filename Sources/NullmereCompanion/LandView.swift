import Foundation
import NullmereCompanionCore
import NullmereCore
import SwiftUI

/// The House's land from the phone: the chart of the ground about its seat
/// as the House knows it, read from the keeper's view as the Mac's map is;
/// a hex chosen there, what lies on it, the orders the rules would take
/// there, and the House's own companies and hold there with their orders,
/// as the Army and House tabs give them.
struct LandTab: View {
    let session: CompanionSession
    @State private var chosen: Hex?
    @State private var recentred = 0

    var body: some View {
        NavigationStack {
            Group {
                if let world = session.world, let house = session.keeper?.house {
                    let chart = CompanionChart(world: world, player: house)
                    VStack(spacing: 0) {
                        ChartView(chart: chart, chosen: $chosen, recentred: recentred)
                            .frame(maxWidth: .infinity)
                            .frame(height: 330)
                        List {
                            if session.linkTold {
                                Section {
                                    ReachLine(session: session)
                                }
                            }
                            if let hex = chosen, chart.contains(hex) {
                                PlaceSections(session: session, place: chart.place(at: hex, in: world, player: house))
                            } else {
                                Section {
                                    Text(verbatim: "Choose a hex of the chart: what lies there, and your companies sent there.")
                                        .font(Night.small)
                                        .foregroundStyle(Night.ink.opacity(0.7))
                                }
                            }
                        }
                        .scrollContentBackground(.hidden)
                    }
                    .toolbar {
                        Button("Your seat") {
                            chosen = chart.center
                            recentred += 1
                        }
                        .font(Night.small)
                        .accessibilityHint("Turns the chart back to your seat and chooses it")
                    }
                }
            }
            .background(Night.background)
            .navigationTitle("Land")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
        }
        .onAppear {
            #if DEBUG
            // Seen by the smoke test with the House's first company chosen.
            if CompanionCheck.tabShown == .land, chosen == nil, let world = session.world, let house = session.keeper?.house {
                chosen = world.units(of: house).first?.position ?? world.seat(of: house)?.position
            }
            #endif
        }
    }
}

/// What lies at the hex chosen and what the House may do there: what may
/// strike it, a rally called on it, companies sent to gather and marched
/// there; then the House's own companies and hold there, as their tabs
/// give them.
struct PlaceSections: View {
    let session: CompanionSession
    let place: CompanionChart.Place

    var body: some View {
        Section {
            ForEach(Array(place.lines.enumerated()), id: \.offset) { line in
                Text(verbatim: line.element)
                    .font(Night.body)
                    .fixedSize(horizontal: false, vertical: true)
            }
            // What the House's watchfire here made out, and its watchman's
            // word, in this phone's model's words.
            if let watchman = place.watchman {
                VStack(alignment: .leading, spacing: 4) {
                    Text(verbatim: watchman.said)
                        .font(Night.small)
                        .fixedSize(horizontal: false, vertical: true)
                    VoicedWords(key: watchman.voice, who: "the watchman")
                }
            }
            ForEach(Array((place.strikes + place.calls).enumerated()), id: \.offset) { order in
                Button(order.element.title) {
                    session.give(order.element.command, told: order.element.title)
                }
                .font(Night.small)
                .foregroundStyle(Night.bad)
            }
            ForEach(Array(place.scouts.enumerated()), id: \.offset) { order in
                Button(order.element.title) {
                    session.give(order.element.command, told: order.element.title)
                }
                .font(Night.small)
            }
            if !place.gathers.isEmpty || !place.marches.isEmpty {
                HStack(spacing: 10) {
                    ListedOrdersMenu(title: "Gather here", orders: place.gathers, label: "Send a company to gather here") { order in
                        session.give(order.command, told: order.title)
                    }
                    ListedOrdersMenu(title: "March here", orders: place.marches, label: "March a company here") { order in
                        session.give(order.command, told: order.title)
                    }
                }
                .font(Night.small)
            }
        } header: {
            Text(verbatim: place.title)
        }
        // What may be raised here, as the Mac's ground panel offers it:
        // what raising it does, and the orders the rules would take.
        if !place.raisings.isEmpty {
            Section("To raise here") {
                ForEach(Array(place.raisings.enumerated()), id: \.offset) { raising in
                    VStack(alignment: .leading, spacing: 6) {
                        Text(verbatim: raising.element.said)
                            .font(Night.small)
                            .foregroundStyle(Night.ink.opacity(0.75))
                            .fixedSize(horizontal: false, vertical: true)
                        FlowOrders(session: session, orders: raising.element.orders)
                    }
                }
            }
        }
        // The alliance's mark here lifted, or the ground marked for it, as
        // the Mac offers its leader.
        if let marking = place.marking {
            Section("For the alliance") {
                VStack(alignment: .leading, spacing: 6) {
                    Text(verbatim: marking.said)
                        .font(Night.small)
                        .foregroundStyle(Night.ink.opacity(0.75))
                        .fixedSize(horizontal: false, vertical: true)
                    FlowOrders(session: session, orders: marking.orders)
                }
            }
        }
        if let ledger = session.ledger {
            ForEach(ledger.companies.filter { place.companies.contains($0.id) }) { company in
                Section {
                    CompanyRows(session: session, company: company)
                }
            }
            if let id = place.hold, let hold = ledger.holds.first(where: { $0.id == id }) {
                Section {
                    HoldRows(session: session, hold: hold)
                }
            }
        }
    }
}

/// Orders side by side, each its own bordered button, wrapping onto the
/// next line where they don't fit.
struct FlowOrders: View {
    let session: CompanionSession
    let orders: [CompanionLedger.Order]

    var body: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) { buttons }
            VStack(alignment: .leading, spacing: 6) { buttons }
        }
        .font(Night.small)
    }

    private var buttons: some View {
        ForEach(Array(orders.enumerated()), id: \.offset) { order in
            Button(order.element.title) { session.give(order.element.command, told: order.element.title) }
                .buttonStyle(.bordered)
        }
    }
}

/// A menu of orders whose titles may be alike (two companies of one kind
/// by the same hold), each told apart by its place in the list.
struct ListedOrdersMenu: View {
    let title: String
    let orders: [CompanionLedger.Order]
    let label: String
    let give: (CompanionLedger.Order) -> Void

    var body: some View {
        if !orders.isEmpty {
            Menu(title) {
                ForEach(Array(orders.enumerated()), id: \.offset) { order in
                    Button(order.element.title) { give(order.element) }
                }
            }
            // Bordered, so that two or three side by side in a list's row
            // each answer only to their own touch, not the row's.
            .buttonStyle(.bordered)
            .accessibilityLabel(label)
        }
    }
}

/// The chart drawn: each hex in its ground's colour as the House knows it,
/// under fog where it hasn't explored; the marks in the colours of whose
/// they are, the House's own in moonlight, its allies' green, its foes'
/// red, the wilds' violet; the hex chosen ringed. Dragged to look about,
/// pinched to look closer, a hex tapped to choose it; VoiceOver reads each
/// mark and chooses it.
struct ChartView: View {
    let chart: CompanionChart
    @Binding var chosen: Hex?
    /// Changed to turn the chart back to its heart.
    let recentred: Int
    /// How far the chart is moved from its heart, in hexes' sizes, so it
    /// holds the same ground as it is pinched.
    @State private var pan = CGSize.zero
    @State private var panned = CGSize.zero
    @State private var zoom: CGFloat = 1
    @State private var zoomed: CGFloat = 1

    /// A hex's size at the chart's opening closeness, in points: some
    /// fourteen hexes across a phone.
    static let opening: Double = 16
    /// The closest the chart is pinched.
    static let closest: CGFloat = 3

    var body: some View {
        GeometryReader { proxy in
            let frame = proxy.size
            let size = Self.opening * Double(zoom)
            Canvas { context, canvas in
                draw(in: &context, canvas: canvas, size: size)
            }
            .contentShape(Rectangle())
            .gesture(
                DragGesture(minimumDistance: 6)
                    .onChanged { value in
                        let width = Double(panned.width) + Double(value.translation.width) / size
                        let height = Double(panned.height) + Double(value.translation.height) / size
                        pan = bounded(CGSize(width: width, height: height))
                    }
                    .onEnded { _ in panned = pan }
                    .simultaneously(with: MagnifyGesture()
                        .onChanged { value in zoom = min(max(zoomed * value.magnification, farthest(in: frame)), Self.closest) }
                        .onEnded { _ in zoomed = zoom })
            )
            .onTapGesture(coordinateSpace: .local) { location in
                let tapped = self.hex(at: location, canvas: frame, size: size)
                if chart.contains(tapped) { chosen = tapped }
            }
        }
        .background(Night.background)
        .clipped()
        .onChange(of: recentred) {
            pan = .zero
            panned = .zero
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel("The land about your seat")
        .accessibilityHint("Drag to look about, pinch to look closer, and tap a hex to choose it")
        .accessibilityChildren {
            ForEach(chart.marks) { mark in
                Rectangle()
                    .accessibilityLabel(mark.name)
                    .accessibilityAddTraits(mark.hex == chosen ? [.isButton, .isSelected] : .isButton)
                    .accessibilityAction { chosen = mark.hex }
            }
        }
    }

    /// The least closeness: the whole chart in the frame.
    private func farthest(in frame: CGSize) -> CGFloat {
        let across = 3.0.squareRoot() * Double(2 * chart.radius + 1)
        let down = 1.5 * Double(2 * chart.radius) + 2
        let fit = min(Double(frame.width) / across, Double(frame.height) / down) / Self.opening
        return CGFloat(min(1, max(fit, 0.1)))
    }

    /// The chart held over the frame: moved no further than its reach.
    private func bounded(_ pan: CGSize) -> CGSize {
        let most = 1.8 * Double(chart.radius)
        return CGSize(width: min(max(Double(pan.width), -most), most), height: min(max(Double(pan.height), -most), most))
    }

    /// Where a hex's centre lies in the frame.
    private func point(of hex: Hex, canvas: CGSize, size: Double) -> CGPoint {
        let layout = HexLayout(size: size)
        let heart = layout.center(of: chart.center)
        let at = layout.center(of: hex)
        let x: Double = Double(canvas.width) / 2 + Double(pan.width) * size + at.x - heart.x
        let y: Double = Double(canvas.height) / 2 + Double(pan.height) * size + at.y - heart.y
        return CGPoint(x: x, y: y)
    }

    /// The hex under a point of the frame.
    private func hex(at point: CGPoint, canvas: CGSize, size: Double) -> Hex {
        let layout = HexLayout(size: size)
        let heart = layout.center(of: chart.center)
        let x: Double = Double(point.x) - Double(canvas.width) / 2 - Double(pan.width) * size + heart.x
        let y: Double = Double(point.y) - Double(canvas.height) / 2 - Double(pan.height) * size + heart.y
        return layout.hex(atX: x, y: y)
    }

    private func draw(in context: inout GraphicsContext, canvas: CGSize, size: Double) {
        let unit = HexLayout(size: size).corners(of: .origin)
        let cell = Path { path in
            path.move(to: CGPoint(x: unit[0].x, y: unit[0].y))
            for corner in unit.dropFirst() { path.addLine(to: CGPoint(x: corner.x, y: corner.y)) }
            path.closeSubpath()
        }
        let margin = CGFloat(size * 2)
        let shown = CGRect(origin: .zero, size: canvas).insetBy(dx: -margin, dy: -margin)
        for each in chart.cells {
            let at = point(of: each.hex, canvas: canvas, size: size)
            guard shown.contains(at) else { continue }
            let shade = CompanionChart.shade(of: each)
            let placed = cell.offsetBy(dx: at.x, dy: at.y)
            context.fill(placed, with: .color(Color(red: shade.red, green: shade.green, blue: shade.blue)))
            // The House's own land lit faintly, as its claims reach.
            if each.land == .own { context.fill(placed, with: .color(Night.moon.opacity(0.08))) }
            context.stroke(placed, with: .color(Night.background.opacity(0.55)), lineWidth: 0.5)
        }
        // Whose land is whose: each land's edge where it meets another's or
        // no one's, in the colour of whose it is.
        for border in chart.borders {
            let at = point(of: border.hex, canvas: canvas, size: size)
            guard shown.contains(at) else { continue }
            let beyond = point(of: border.beyond, canvas: canvas, size: size)
            let middle = CGPoint(x: (at.x + beyond.x) / 2, y: (at.y + beyond.y) / 2)
            func far(_ corner: CGPoint) -> CGFloat {
                (corner.x - middle.x) * (corner.x - middle.x) + (corner.y - middle.y) * (corner.y - middle.y)
            }
            // The two corners nearest the midpoint between the two hexes: their shared edge.
            let corners = unit.map { CGPoint(x: Double(at.x) + $0.x, y: Double(at.y) + $0.y) }.sorted { far($0) < far($1) }
            var edge = Path()
            edge.move(to: corners[0])
            edge.addLine(to: corners[1])
            let own = border.side == .own
            context.stroke(edge, with: .color(Self.colour(of: border.side).opacity(own ? 0.95 : 0.7)), lineWidth: own ? 1.8 : 1.1)
        }
        // The House's marches: a line from each company to where it is bound.
        for mark in chart.marks {
            guard let bound = mark.bound else { continue }
            let from = point(of: mark.hex, canvas: canvas, size: size)
            let to = point(of: bound, canvas: canvas, size: size)
            var march = Path()
            march.move(to: from)
            march.addLine(to: to)
            context.stroke(march, with: .color(Night.moon.opacity(0.7)), style: StrokeStyle(lineWidth: 1.5, dash: [4, 3]))
            let ring = CGFloat(size * 0.35)
            context.stroke(Path(ellipseIn: CGRect(x: to.x - ring, y: to.y - ring, width: ring * 2, height: ring * 2)),
                           with: .color(Night.moon.opacity(0.7)), lineWidth: 1)
        }
        // The regions' names, faint beneath what stands on the land.
        for region in chart.regions {
            let at = point(of: region.hex, canvas: canvas, size: size)
            guard shown.contains(at) else { continue }
            context.draw(Text(verbatim: region.name.uppercased())
                            .font(.system(size: 9, weight: .regular, design: .serif).italic())
                            .foregroundStyle(Night.ink.opacity(0.45)),
                         at: at)
        }
        for mark in chart.marks {
            let at = point(of: mark.hex, canvas: canvas, size: size)
            guard shown.contains(at) else { continue }
            Self.draw(mark, at: at, size: size, in: &context)
        }
        if let chosen, chart.contains(chosen) {
            let at = point(of: chosen, canvas: canvas, size: size)
            context.stroke(cell.offsetBy(dx: at.x, dy: at.y), with: .color(Night.moon), lineWidth: 2.5)
        }
        // The holds' names, once the chart is close enough to read them.
        guard size >= Self.opening * 0.9 else { return }
        for mark in chart.marks {
            guard let label = mark.label else { continue }
            let at = point(of: mark.hex, canvas: canvas, size: size)
            guard shown.contains(at) else { continue }
            context.draw(Text(verbatim: label)
                            .font(.system(size: 10, weight: mark.thing == .seat ? .semibold : .regular, design: .serif))
                            .foregroundStyle(Self.colour(of: mark.side)),
                         at: CGPoint(x: Double(at.x), y: Double(at.y) + size * 1.05))
        }
    }

    /// The colour of whose a mark is.
    static func colour(of side: CompanionChart.Side) -> Color {
        switch side {
        case .own: return Night.moon
        case .ally: return Night.good
        case .foe: return Night.bad
        case .other: return Color(white: 0.78)
        case .wilds: return Color(red: 0.72, green: 0.58, blue: 0.88)
        }
    }

    private static func draw(_ mark: CompanionChart.Mark, at: CGPoint, size: Double, in context: inout GraphicsContext) {
        let tint = Self.colour(of: mark.side)
        let edge = Color.black.opacity(0.7)
        let x = Double(at.x)
        let y = Double(at.y)
        func square(_ half: Double) -> Path { Path(CGRect(x: x - half, y: y - half, width: half * 2, height: half * 2)) }
        func circle(_ radius: Double) -> Path {
            Path(ellipseIn: CGRect(x: x - radius, y: y - radius, width: radius * 2, height: radius * 2))
        }
        func triangle(_ half: Double, up: Bool) -> Path {
            Path { path in
                let tip = up ? -half : half
                path.move(to: CGPoint(x: x, y: y + tip))
                path.addLine(to: CGPoint(x: x + half, y: y - tip * 0.8))
                path.addLine(to: CGPoint(x: x - half, y: y - tip * 0.8))
                path.closeSubpath()
            }
        }
        switch mark.thing {
        case .seat:
            let keep = square(size * 0.5)
            context.fill(keep, with: .color(tint))
            context.stroke(keep, with: .color(edge), lineWidth: 1)
            context.fill(square(size * 0.2), with: .color(edge))
        case .hold:
            let keep = square(size * 0.36)
            context.fill(keep, with: .color(tint))
            context.stroke(keep, with: .color(edge), lineWidth: 1)
        case .company:
            let body = circle(size * 0.3)
            if mark.dark {
                // Marching dark, its torches doused: a hollow ring in its
                // side's colour, as the world shows it without its torches.
                context.fill(body, with: .color(edge))
                context.stroke(circle(size * 0.25), with: .color(tint), lineWidth: 1.6)
            } else {
                context.fill(body, with: .color(tint))
                context.stroke(body, with: .color(edge), lineWidth: 1)
            }
        case .wild:
            let wild = triangle(size * 0.3, up: false)
            context.fill(wild, with: .color(tint))
            context.stroke(wild, with: .color(edge), lineWidth: 1)
        case .lair:
            let lair = triangle(size * 0.45, up: true)
            context.fill(lair, with: .color(tint))
            context.stroke(lair, with: .color(edge), lineWidth: 1)
        case .site:
            let site = Path { path in
                let half = size * 0.28
                path.move(to: CGPoint(x: x, y: y - half))
                path.addLine(to: CGPoint(x: x + half, y: y))
                path.addLine(to: CGPoint(x: x, y: y + half))
                path.addLine(to: CGPoint(x: x - half, y: y))
                path.closeSubpath()
            }
            context.fill(site, with: .color(tint.opacity(0.85)))
        case .shrine:
            context.stroke(circle(size * 0.4), with: .color(Night.moon.opacity(0.9)), lineWidth: 1.5)
        case .watchfire:
            // A watchfire's flame in the light it keeps, ringed in its House's colour.
            context.fill(circle(size * 0.44), with: .color(Self.flame.opacity(0.16)))
            context.fill(circle(size * 0.15), with: .color(Self.flame))
            context.stroke(circle(size * 0.2), with: .color(tint), lineWidth: 1.5)
        case .vigil:
            // A small flame on the black water in its warm glow, whoever's it is.
            context.fill(circle(size * 0.34), with: .color(Self.flame.opacity(0.22)))
            context.fill(circle(size * 0.13), with: .color(Self.flame))
        case .plea:
            // The petitioner's lantern at the hold's gate, below and beside its keep.
            let lantern = CGRect(x: x + size * 0.32, y: y + size * 0.22, width: size * 0.2, height: size * 0.2)
            context.fill(Path(ellipseIn: lantern.insetBy(dx: -size * 0.08, dy: -size * 0.08)), with: .color(Self.flame.opacity(0.25)))
            context.fill(Path(ellipseIn: lantern), with: .color(Self.flame))
        case .fire:
            // The blackwood burning: three tongues of flame in their glow.
            context.fill(circle(size * 0.46), with: .color(Self.flame.opacity(0.2)))
            for (offset, height) in [(-0.2, 0.34), (0.0, 0.46), (0.2, 0.3)] {
                let base = CGPoint(x: x + size * offset, y: y + size * 0.22)
                let flame = Path { path in
                    path.move(to: CGPoint(x: base.x - size * 0.09, y: base.y))
                    path.addQuadCurve(to: CGPoint(x: base.x, y: base.y - size * height),
                                      control: CGPoint(x: base.x - size * 0.11, y: base.y - size * height * 0.5))
                    path.addQuadCurve(to: CGPoint(x: base.x + size * 0.09, y: base.y),
                                      control: CGPoint(x: base.x + size * 0.11, y: base.y - size * height * 0.5))
                    path.closeSubpath()
                }
                context.fill(flame, with: .color(Self.flame))
            }
        case .ash:
            // Burnt ground: grey ash, and the dead trees standing in it.
            context.fill(circle(size * 0.42), with: .color(Color.gray.opacity(0.3)))
            for (offset, rise) in [(-0.18, 0.05), (0.12, -0.1), (0.05, 0.16)] {
                let trunk = CGRect(x: x + size * offset - 1, y: y + size * rise - size * 0.14, width: 2, height: size * 0.18)
                context.fill(Path(trunk), with: .color(edge))
            }
        case .allianceMark:
            // The alliance's pennant at the hex's upper left, clear of a
            // keep, in its mark's hue as the world lights it.
            let hue = mark.bids.map(Self.hue) ?? Night.good
            let foot = CGPoint(x: x - size * 0.4, y: y + size * 0.1)
            let top = CGPoint(x: foot.x, y: foot.y - size * 0.75)
            var pole = Path()
            pole.move(to: foot)
            pole.addLine(to: top)
            context.stroke(pole, with: .color(edge), lineWidth: 1.6)
            let pennant = Path { path in
                path.move(to: top)
                path.addLine(to: CGPoint(x: top.x + size * 0.46, y: top.y + size * 0.15))
                path.addLine(to: CGPoint(x: top.x, y: top.y + size * 0.3))
                path.closeSubpath()
            }
            context.fill(Path(ellipseIn: CGRect(x: top.x - size * 0.2, y: top.y - size * 0.12, width: size * 0.7, height: size * 0.54)),
                         with: .color(hue.opacity(0.22)))
            context.fill(pennant, with: .color(hue))
            context.stroke(pennant, with: .color(edge), lineWidth: 0.8)
        }
    }

    /// A mark's hue, as the world lights it.
    static func hue(_ kind: AllianceMark.Kind) -> Color {
        Color(red: Double(kind.hue.red), green: Double(kind.hue.green), blue: Double(kind.hue.blue))
    }

    /// A vigil's flame, as the world draws it.
    static let flame = Color(red: 1.0, green: 0.74, blue: 0.40)
}
