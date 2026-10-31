import NullmereCore
import SwiftUI

/// A House's crest, drawn: its shield of one tincture, edged, bearing its
/// charge in another. Every charge is drawn here, of lines and curves.
struct CrestView: View {
    let crest: Crest
    var size: CGFloat = 24

    var body: some View {
        Canvas { context, area in
            let shield = CrestView.shield(in: CGRect(origin: .zero, size: area))
            context.fill(shield, with: .color(CrestView.colour(crest.field)))
            let inner = CGRect(x: area.width * 0.2, y: area.height * 0.14, width: area.width * 0.6, height: area.height * 0.6)
            context.fill(CrestView.charge(crest.charge, in: inner), with: .color(CrestView.colour(crest.tincture)))
            context.stroke(shield, with: .color(Palette.line(0.55)), lineWidth: max(1, size / 22))
        }
        .frame(width: size, height: size * 1.15)
        .accessibilityElement()
        .accessibilityLabel("Crest: \(crest.blazon)")
        .accessibilityAddTraits(.isImage)
    }

    /// Each tincture's colour.
    static func colour(_ tincture: Crest.Tincture) -> Color {
        switch tincture {
        case .silver: return Color(red: 0.80, green: 0.82, blue: 0.85)
        case .gold: return Color(red: 0.84, green: 0.66, blue: 0.25)
        case .black: return Color(red: 0.10, green: 0.10, blue: 0.12)
        case .blue: return Color(red: 0.20, green: 0.37, blue: 0.67)
        case .red: return Color(red: 0.66, green: 0.20, blue: 0.18)
        case .green: return Color(red: 0.19, green: 0.49, blue: 0.31)
        case .purple: return Color(red: 0.42, green: 0.26, blue: 0.62)
        }
    }

    /// The shield: square-shouldered, curving to a point.
    static func shield(in rect: CGRect) -> Path {
        Path { path in
            let x = rect.minX, y = rect.minY, w = rect.width, h = rect.height
            path.move(to: CGPoint(x: x + w * 0.06, y: y + h * 0.04))
            path.addLine(to: CGPoint(x: x + w * 0.94, y: y + h * 0.04))
            path.addLine(to: CGPoint(x: x + w * 0.94, y: y + h * 0.48))
            path.addQuadCurve(to: CGPoint(x: x + w * 0.5, y: y + h * 0.97), control: CGPoint(x: x + w * 0.92, y: y + h * 0.8))
            path.addQuadCurve(to: CGPoint(x: x + w * 0.06, y: y + h * 0.48), control: CGPoint(x: x + w * 0.08, y: y + h * 0.8))
            path.closeSubpath()
        }
    }

    /// A charge, filling `rect`.
    static func charge(_ charge: Crest.Charge, in rect: CGRect) -> Path {
        func p(_ u: CGFloat, _ v: CGFloat) -> CGPoint { CGPoint(x: rect.minX + rect.width * u, y: rect.minY + rect.height * v) }
        let line = rect.width * 0.11
        func stroked(_ path: Path, _ width: CGFloat = line) -> Path {
            path.strokedPath(StrokeStyle(lineWidth: width, lineCap: .round, lineJoin: .round))
        }
        switch charge {
        case .moon:
            let outer = Path(ellipseIn: CGRect(origin: p(0.12, 0.1), size: CGSize(width: rect.width * 0.76, height: rect.height * 0.8)))
            let inner = Path(ellipseIn: CGRect(origin: p(0.32, 0.02), size: CGSize(width: rect.width * 0.7, height: rect.height * 0.74)))
            return outer.subtracting(inner)
        case .star:
            return Path { path in
                for index in 0..<10 {
                    let angle = Double(index) * .pi / 5 - .pi / 2
                    let reach = index.isMultiple(of: 2) ? 0.48 : 0.2
                    let point = p(0.5 + CGFloat(cos(angle) * reach), 0.53 + CGFloat(sin(angle) * reach))
                    if index == 0 { path.move(to: point) } else { path.addLine(to: point) }
                }
                path.closeSubpath()
            }
        case .tower:
            return Path { path in
                path.addRect(CGRect(origin: p(0.26, 0.3), size: CGSize(width: rect.width * 0.48, height: rect.height * 0.66)))
                for merlon in 0..<3 {
                    path.addRect(CGRect(origin: p(0.26 + CGFloat(merlon) * 0.18, 0.12), size: CGSize(width: rect.width * 0.12, height: rect.height * 0.2)))
                }
            }.subtracting(Path(roundedRect: CGRect(origin: p(0.42, 0.66), size: CGSize(width: rect.width * 0.16, height: rect.height * 0.3)),
                               cornerRadius: rect.width * 0.08))
        case .wave:
            return stroked(Path { path in
                for crest in 0..<2 {
                    let v = 0.36 + CGFloat(crest) * 0.32
                    path.move(to: p(0.04, v))
                    path.addCurve(to: p(0.5, v), control1: p(0.16, v - 0.2), control2: p(0.38, v + 0.2))
                    path.addCurve(to: p(0.96, v), control1: p(0.62, v - 0.2), control2: p(0.84, v + 0.2))
                }
            })
        case .flame:
            return Path { path in
                path.move(to: p(0.5, 0.02))
                path.addQuadCurve(to: p(0.84, 0.66), control: p(0.86, 0.36))
                path.addQuadCurve(to: p(0.5, 0.98), control: p(0.8, 0.96))
                path.addQuadCurve(to: p(0.16, 0.66), control: p(0.2, 0.96))
                path.addQuadCurve(to: p(0.5, 0.02), control: p(0.12, 0.4))
                path.closeSubpath()
            }
        case .key:
            let bow = Path(ellipseIn: CGRect(origin: p(0.08, 0.06), size: CGSize(width: rect.width * 0.36, height: rect.height * 0.36)))
                .subtracting(Path(ellipseIn: CGRect(origin: p(0.17, 0.15), size: CGSize(width: rect.width * 0.18, height: rect.height * 0.18))))
            let shaft = stroked(Path { path in
                path.move(to: p(0.38, 0.38))
                path.addLine(to: p(0.9, 0.9))
                path.move(to: p(0.74, 0.74))
                path.addLine(to: p(0.62, 0.86))
                path.move(to: p(0.86, 0.86))
                path.addLine(to: p(0.74, 0.98))
            })
            return bow.union(shaft)
        case .bell:
            return Path { path in
                path.move(to: p(0.5, 0.06))
                path.addQuadCurve(to: p(0.76, 0.42), control: p(0.76, 0.06))
                path.addQuadCurve(to: p(0.94, 0.8), control: p(0.76, 0.72))
                path.addLine(to: p(0.06, 0.8))
                path.addQuadCurve(to: p(0.24, 0.42), control: p(0.24, 0.72))
                path.addQuadCurve(to: p(0.5, 0.06), control: p(0.24, 0.06))
                path.closeSubpath()
                path.addEllipse(in: CGRect(origin: p(0.4, 0.82), size: CGSize(width: rect.width * 0.2, height: rect.height * 0.16)))
            }
        case .oar:
            let shaft = stroked(Path { path in
                path.move(to: p(0.12, 0.06))
                path.addLine(to: p(0.66, 0.66))
            })
            let blade = Path(ellipseIn: CGRect(x: -rect.width * 0.12, y: -rect.height * 0.24, width: rect.width * 0.24, height: rect.height * 0.48))
                .applying(CGAffineTransform(rotationAngle: -.pi / 4).concatenating(CGAffineTransform(translationX: p(0.76, 0.78).x, y: p(0.76, 0.78).y)))
            return shaft.union(blade)
        case .antler:
            return stroked(Path { path in
                for side in [-1.0, 1.0] as [CGFloat] {
                    let x = { (u: CGFloat) in 0.5 + side * u }
                    path.move(to: p(x(0.04), 0.96))
                    path.addQuadCurve(to: p(x(0.36), 0.08), control: p(x(0.12), 0.4))
                    path.move(to: p(x(0.1), 0.64))
                    path.addLine(to: p(x(0.36), 0.52))
                    path.move(to: p(x(0.19), 0.38))
                    path.addLine(to: p(x(0.44), 0.3))
                }
            }, line * 0.9)
        case .heron:
            let lines = stroked(Path { path in
                // The neck rising to the head, the beak, and the legs.
                path.move(to: p(0.42, 0.56))
                path.addCurve(to: p(0.5, 0.12), control1: p(0.26, 0.38), control2: p(0.66, 0.3))
                path.move(to: p(0.5, 0.12))
                path.addLine(to: p(0.86, 0.2))
                path.move(to: p(0.52, 0.72))
                path.addLine(to: p(0.46, 0.98))
                path.move(to: p(0.6, 0.72))
                path.addLine(to: p(0.66, 0.98))
            }, line * 0.8)
            let body = Path(ellipseIn: CGRect(origin: p(0.32, 0.5), size: CGSize(width: rect.width * 0.46, height: rect.height * 0.26)))
            return lines.union(body)
        }
    }
}

/// The House's crest, as the lake gave it or as its keeper took it: shown
/// with what it is, and, until the keeper has taken their own this age,
/// folded until asked for, a shield drawn as they choose its field, its
/// charge and its tincture, taken with a press asked twice.
struct CrestSection: View {
    let session: GameSession

    @AppStorage(CrestSection.choosingKey) private var choosing = false
    static let choosingKey = "crest.open"
    @State private var draft: Crest?

    /// What the House bears, in a line.
    static func line(_ crest: Crest, chosen: Bool) -> String {
        chosen ? "Your House bears \(crest.blazon), its own until the age ends."
            : "Your House bears \(crest.blazon), as the lake gave it. Take your own once this age."
    }

    var body: some View {
        let state = session.state, me = session.player
        let mine = state.crest(of: me)
        let chosen = state.houses.indices.contains(me) && state.houses[me].crest != nil
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Caps("Crest", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                Spacer()
                if !chosen {
                    QuietButton(title: choosing ? "Fold the crest" : "Take your own…", size: 8.5,
                                name: choosing ? "Fold the crest away" : "Choose your House's crest") { choosing.toggle() }
                }
            }
            HStack(spacing: 10) {
                CrestView(crest: mine, size: 30)
                Text(verbatim: CrestSection.line(mine, chosen: chosen))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.7))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if choosing, !chosen {
                let draft = self.draft ?? mine
                choices("Field", Crest.Tincture.allCases.map(\.title), chosen: Crest.Tincture.allCases.firstIndex(of: draft.field)) {
                    self.draft = Crest(field: Crest.Tincture.allCases[$0], charge: draft.charge, tincture: draft.tincture)
                }
                choices("Charge", Crest.Charge.allCases.map(\.title), chosen: Crest.Charge.allCases.firstIndex(of: draft.charge)) {
                    self.draft = Crest(field: draft.field, charge: Crest.Charge.allCases[$0], tincture: draft.tincture)
                }
                choices("Its tincture", Crest.Tincture.allCases.map(\.title), chosen: Crest.Tincture.allCases.firstIndex(of: draft.tincture)) {
                    self.draft = Crest(field: draft.field, charge: draft.charge, tincture: Crest.Tincture.allCases[$0])
                }
                HStack(alignment: .center, spacing: 10) {
                    CrestView(crest: draft, size: 44)
                    Text(verbatim: draft.blazon.prefix(1).uppercased() + draft.blazon.dropFirst())
                        .font(.nm(11, weight: .medium))
                        .foregroundStyle(Palette.ink)
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    let refusal = state.crestRefusal(draft, as: me)
                    if let refusal {
                        QuietButton(title: "Take this crest", size: 8.5, enabled: false, why: refusal.description) {}
                    } else {
                        ConfirmButton(title: "Take this crest", confirm: "Bear it all this age?") {
                            session.perform(.takeCrest(draft))
                        }
                    }
                }
            }
        }
    }

    /// A row of choices under its name, the one chosen lit.
    private func choices(_ title: String, _ options: [String], chosen: Int?, choose: @escaping (Int) -> Void) -> some View {
        VStack(alignment: .leading, spacing: 3) {
            Caps(title, size: 8, weight: .medium).foregroundStyle(Palette.text(0.55))
            FlowLayout(spacing: 4, lineSpacing: 2) {
                ForEach(options.indices, id: \.self) { index in
                    QuietButton(title: options[index], size: 8.5, prominent: index == chosen, pressable: false,
                                name: "\(title): \(options[index])") { choose(index) }
                }
            }
        }
    }
}
