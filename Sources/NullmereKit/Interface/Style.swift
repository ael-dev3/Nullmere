import NullmereCore
import SwiftUI

/// Nullmere's few colours: pale, cold type over the dark, and the colours
/// of the Houses (matching the world shader).
enum Palette {
    static let ink = Color(red: 0.894, green: 0.918, blue: 0.949)
    static let glow = Color(red: 0.588, green: 0.706, blue: 0.882)
    static let good = Color(red: 0.58, green: 0.80, blue: 0.66)
    static let bad = Color(red: 0.90, green: 0.52, blue: 0.48)
    static let panel = Color(red: 0.02, green: 0.025, blue: 0.035)

    /// One colour for each House that may sit around the lake, in the order
    /// of their names; WorldShader's nm_houseColour holds the same.
    static let houses: [Color] = [
        Color(red: 0.86, green: 0.74, blue: 0.47),
        Color(red: 0.70, green: 0.27, blue: 0.25),
        Color(red: 0.30, green: 0.60, blue: 0.60),
        Color(red: 0.58, green: 0.44, blue: 0.74),
        Color(red: 0.78, green: 0.80, blue: 0.84),
        Color(red: 0.86, green: 0.50, blue: 0.26),
        Color(red: 0.46, green: 0.68, blue: 0.38),
        Color(red: 0.80, green: 0.56, blue: 0.68),
        Color(red: 0.36, green: 0.48, blue: 0.84),
        Color(red: 0.55, green: 0.52, blue: 0.22),
        Color(red: 0.40, green: 0.78, blue: 0.86),
        Color(red: 0.88, green: 0.36, blue: 0.50),
    ]

    static func house(_ house: House) -> Color {
        houses[house.sigil % houses.count]
    }

    static func tone(_ tone: GameSession.Notice.Tone) -> Color {
        switch tone {
        case .neutral: return ink.opacity(0.8)
        case .good: return good
        case .bad: return bad
        }
    }
}

/// Uppercase, widely tracked type, as in the launcher.
struct Caps: View {
    let text: String
    var size: CGFloat = 10
    var weight: Font.Weight = .regular
    var tracking: CGFloat = 0.28

    init(_ text: String, size: CGFloat = 10, weight: Font.Weight = .regular, tracking: CGFloat = 0.28) {
        self.text = text
        self.size = size
        self.weight = weight
        self.tracking = tracking
    }

    var body: some View {
        Text(verbatim: text.uppercased())
            .font(.nm(size, weight: weight))
            .tracking(size * TextSize.shared.scale * tracking)
    }
}

/// A thin rule that fades at both ends.
struct Rule: View {
    var opacity: Double = 0.3

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        LinearGradient(colors: [.clear, Palette.ink.opacity(opacity), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1 / displayScale)
    }
}

/// The dark glass behind panels.
struct PanelBackground: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            .background(Palette.panel.opacity(contrast == .increased ? 0.95 : 0.82))
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Palette.ink.opacity(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
    }
}

extension View {
    func panelBackground() -> some View {
        modifier(PanelBackground())
    }
}

/// A quiet text button: spaced capitals that brighten on hover.
/// The actions of the buttons drawn while a test listens, by their
/// titles, so a test can press a panel's buttons as a keeper would and run
/// their own actions. Nothing is kept unless a test turns it on.
@MainActor
enum PressableButtons {
    static var isListening = false {
        didSet { actions = [:] }
    }
    private(set) static var actions: [String: () -> Void] = [:]

    static func note(_ title: String, enabled: Bool, _ action: @escaping () -> Void) {
        guard isListening, enabled else { return }
        actions[title] = action
    }

    /// Presses the button drawn with that title; false if none was drawn,
    /// or it was drawn disabled.
    @discardableResult
    static func press(_ title: String) -> Bool {
        guard let action = actions[title] else { return false }
        action()
        return true
    }
}

struct QuietButton: View {
    let title: String
    var size: CGFloat = 10
    var prominent = false
    var enabled = true
    /// A colour for the words, for a button that asks twice.
    var tint: Color?
    /// Whether a listening test may press it; a button that asks twice is
    /// pressed by its own action instead.
    var pressable = true
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let _ = pressable ? PressableButtons.note(title, enabled: enabled, action) : ()
        Button(action: action) {
            Caps(title, size: size, weight: prominent ? .medium : .regular)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle((tint ?? Palette.ink).opacity(enabled ? (hovering || prominent || tint != nil ? 1 : 0.72) : 0.3))
                .padding(.horizontal, prominent ? 16 : 8)
                .padding(.vertical, prominent ? 9 : 5)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.glow.opacity(prominent ? (hovering ? 0.22 : 0.14) : (hovering && enabled ? 0.08 : 0)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Palette.ink.opacity(prominent ? 0.35 : 0), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!enabled)
        .onHover { hovering = $0 }
        .accessibilityLabel(title)
    }
}

/// A resource amount, with what is missing shown in the warning colour.
struct CostLine: View {
    let cost: Stock
    let available: Stock

    var body: some View {
        HStack(spacing: 10) {
            ForEach(Resource.allCases, id: \.self) { resource in
                if cost[resource] > 0 {
                    HStack(spacing: 3) {
                        ResourceGlyph(resource: resource)
                        Text(verbatim: "\(cost[resource])")
                            .font(.nm(11, weight: .regular).monospacedDigit())
                    }
                    .foregroundStyle(available[resource] >= cost[resource] ? Palette.ink.opacity(0.75) : Palette.bad)
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Costs \(cost.description)")
    }
}

/// A tiny mark for each resource.
struct ResourceGlyph: View {
    let resource: Resource
    var size: CGFloat = 7

    var body: some View {
        Group {
            switch resource {
            case .grain:
                Circle().fill(Color(red: 0.84, green: 0.76, blue: 0.52))
            case .timber:
                Rectangle().fill(Color(red: 0.42, green: 0.55, blue: 0.44))
            case .stone:
                RoundedRectangle(cornerRadius: 1).fill(Color(red: 0.62, green: 0.60, blue: 0.58)).rotationEffect(.degrees(45))
            case .moonsalt:
                Circle().strokeBorder(Color(red: 0.80, green: 0.86, blue: 1.0), lineWidth: 1.5)
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// A first press that arms, a second within a few seconds that acts: for
/// what can't be taken back, such as war.
struct Confirmation: Equatable {
    static let window = 3.0
    private(set) var armedAt: Date?

    /// Returns whether this press acts.
    mutating func press(at now: Date = Date()) -> Bool {
        if isArmed(at: now) {
            armedAt = nil
            return true
        }
        armedAt = now
        return false
    }

    /// Forgets a press whose time has passed.
    mutating func lapse(at now: Date = Date()) {
        if !isArmed(at: now) { armedAt = nil }
    }

    func isArmed(at now: Date = Date()) -> Bool {
        guard let armedAt else { return false }
        return now.timeIntervalSince(armedAt) <= Confirmation.window
    }
}

/// A quiet button that asks again before doing what can't be undone.
struct ConfirmButton: View {
    let title: String
    /// What it says once armed, such as "War on House Venn?".
    let confirm: String
    var size: CGFloat = 8.5
    let action: () -> Void

    @State private var confirmation = Confirmation()

    var body: some View {
        let armed = confirmation.isArmed()
        let _ = PressableButtons.note(title, enabled: true, action)
        QuietButton(title: armed ? confirm : title, size: size, tint: armed ? Palette.bad : nil, pressable: false) {
            if confirmation.press() {
                action()
            } else {
                // Disarms on its own, unpressed.
                Task { @MainActor in
                    try? await Task.sleep(for: .seconds(Confirmation.window + 0.1))
                    confirmation.lapse()
                }
            }
        }
        .help(armed ? "Press again to confirm." : "Asks again before acting.")
        .accessibilityHint("Press twice to confirm.")
    }
}

/// Lays its views in rows, left to right, starting a row afresh when the
/// next would overflow: a House's actions wrap rather than run off.
struct FlowLayout: Layout {
    var spacing: CGFloat = 4
    var lineSpacing: CGFloat = 2

    struct Row: Equatable {
        var indices: [Int] = []
        var width: CGFloat = 0
        var height: CGFloat = 0
    }

    /// Views of these sizes, in rows no wider than `width`; a view wider
    /// than that has a row to itself.
    static func rows(of sizes: [CGSize], width: CGFloat, spacing: CGFloat) -> [Row] {
        var rows: [Row] = []
        var row = Row()
        for (index, size) in sizes.enumerated() {
            let needed = row.indices.isEmpty ? size.width : row.width + spacing + size.width
            if needed > width, !row.indices.isEmpty {
                rows.append(row)
                row = Row(indices: [index], width: size.width, height: size.height)
            } else {
                row.indices.append(index)
                row.width = needed
                row.height = max(row.height, size.height)
            }
        }
        if !row.indices.isEmpty { rows.append(row) }
        return rows
    }

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        let rows = FlowLayout.rows(of: sizes, width: proposal.width ?? .infinity, spacing: spacing)
        let height = rows.reduce(0) { $0 + $1.height } + lineSpacing * CGFloat(max(rows.count - 1, 0))
        return CGSize(width: rows.map(\.width).max() ?? 0, height: height)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let sizes = subviews.map { $0.sizeThatFits(.unspecified) }
        var y = bounds.minY
        for row in FlowLayout.rows(of: sizes, width: bounds.width, spacing: spacing) {
            var x = bounds.minX
            for index in row.indices {
                subviews[index].place(at: CGPoint(x: x, y: y + (row.height - sizes[index].height) / 2), proposal: ProposedViewSize(sizes[index]))
                x += sizes[index].width + spacing
            }
            y += row.height + lineSpacing
        }
    }
}

extension View {
    /// Fades the last few points of a scrolling panel, so a row cut by its
    /// edge reads as more below rather than as clipped, and leaves as much
    /// room after the last row, so it clears the fade when scrolled to.
    func scrollEdgeFade(_ length: CGFloat = 18) -> some View {
        contentMargins(.bottom, length, for: .scrollContent)
            .mask {
                VStack(spacing: 0) {
                    Rectangle()
                    LinearGradient(colors: [.black, .black.opacity(0)], startPoint: .top, endPoint: .bottom)
                        .frame(height: length)
                }
            }
    }
}
