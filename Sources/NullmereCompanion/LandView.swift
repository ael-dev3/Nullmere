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
                            Section {
                                WordLine(session: session)
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
            context.stroke(placed, with: .color(Night.background.opacity(0.55)), lineWidth: 0.5)
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
            context.fill(body, with: .color(tint))
            context.stroke(body, with: .color(edge), lineWidth: 1)
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
        }
    }
}
