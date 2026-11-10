import AppKit
import LauncherCore
import LauncherKit
import NullmereCore
import NullmereWorld
import Observation
import SwiftUI

/// Nullmere's few colours: pale, cold type over the dark, the launcher's
/// own, and the colours of the Houses (matching the world shader).
enum Palette {
    static let ink = LauncherKit.Palette.ink
    static let glow = LauncherKit.Palette.glow
    static let good = Color(red: 0.62, green: 0.84, blue: 0.70)
    /// Warning red, pale enough to read as words, a dot or a comma and all.
    static let bad = Color(red: 0.95, green: 0.64, blue: 0.60)
    /// The glow, as words: lifted toward the ink so small type in it reads.
    static let glowWords = Color(red: 0.74, green: 0.82, blue: 0.94)
    static let panel = Color(red: 0.02, green: 0.025, blue: 0.035)

    /// One colour for each House that may sit around the lake, in the order
    /// of their names: the twelve elder Houses' first, each plainly apart,
    /// then the younger Houses' of lakes of up to ninety-six seats, each
    /// still its own beside any other, then the widest lakes' (see
    /// `HousePalette.widestLakes`). The world's shaders take the same, made
    /// linear.
    static let houseRGB: [RGB] = [
        RGB(0.86, 0.74, 0.47),
        RGB(0.70, 0.27, 0.25),
        RGB(0.30, 0.60, 0.60),
        RGB(0.58, 0.44, 0.74),
        RGB(0.78, 0.80, 0.84),
        RGB(0.86, 0.50, 0.26),
        RGB(0.46, 0.68, 0.38),
        RGB(0.80, 0.56, 0.68),
        RGB(0.36, 0.48, 0.84),
        RGB(0.55, 0.52, 0.22),
        RGB(0.40, 0.78, 0.86),
        RGB(0.88, 0.36, 0.50),
        RGB(0.690, 0.900, 0.270),
        RGB(0.847, 0.270, 0.900),
        RGB(0.192, 0.640, 0.192),
        RGB(0.540, 0.900, 0.630),
        RGB(0.270, 0.900, 0.322),
        RGB(0.280, 0.200, 0.660),
        RGB(0.630, 0.630, 0.900),
        RGB(0.640, 0.464, 0.448),
        RGB(0.270, 0.900, 0.742),
        RGB(0.900, 0.900, 0.630),
        RGB(0.165, 0.550, 0.422),
        RGB(0.511, 0.694, 0.730),
        RGB(0.730, 0.639, 0.365),
        RGB(0.900, 0.540, 0.900),
        RGB(0.410, 0.820, 0.512),
        RGB(0.495, 0.360, 0.900),
        RGB(0.717, 0.820, 0.574),
        RGB(0.270, 0.638, 0.900),
        RGB(0.321, 0.550, 0.275),
        RGB(0.485, 0.820, 0.246),
        RGB(0.900, 0.795, 0.270),
        RGB(0.385, 0.440, 0.550),
        RGB(0.697, 0.328, 0.820),
        RGB(0.219, 0.517, 0.730),
        RGB(0.630, 0.900, 0.877),
        RGB(0.219, 0.730, 0.517),
        RGB(0.820, 0.246, 0.390),
        RGB(0.900, 0.360, 0.765),
        RGB(0.602, 0.730, 0.511),
        RGB(0.645, 0.730, 0.219),
        RGB(0.730, 0.438, 0.608),
        RGB(0.347, 0.730, 0.219),
        RGB(0.787, 0.900, 0.450),
        RGB(0.900, 0.600, 0.540),
        RGB(0.448, 0.544, 0.640),
        RGB(0.550, 0.385, 0.522),
        RGB(0.365, 0.730, 0.669),
        RGB(0.730, 0.395, 0.365),
        RGB(0.750, 0.450, 0.900),
        RGB(0.540, 0.900, 0.360),
        RGB(0.574, 0.820, 0.779),
        RGB(0.450, 0.562, 0.900),
        RGB(0.649, 0.820, 0.410),
        RGB(0.900, 0.630, 0.742),
        RGB(0.900, 0.323, 0.270),
        RGB(0.320, 0.640, 0.427),
        RGB(0.820, 0.547, 0.410),
        RGB(0.640, 0.379, 0.192),
        RGB(0.820, 0.676, 0.246),
        RGB(0.717, 0.574, 0.820),
        RGB(0.453, 0.640, 0.192),
        RGB(0.730, 0.560, 0.219),
        RGB(0.640, 0.320, 0.587),
        RGB(0.900, 0.270, 0.637),
        RGB(0.246, 0.820, 0.629),
        RGB(0.219, 0.730, 0.304),
        RGB(0.730, 0.292, 0.474),
        RGB(0.450, 0.900, 0.787),
        RGB(0.550, 0.403, 0.330),
        RGB(0.540, 0.750, 0.900),
        RGB(0.270, 0.848, 0.900),
        RGB(0.730, 0.566, 0.511),
        RGB(0.536, 0.550, 0.385),
        RGB(0.219, 0.730, 0.730),
        RGB(0.365, 0.578, 0.730),
        RGB(0.779, 0.820, 0.328),
        RGB(0.360, 0.900, 0.585),
        RGB(0.220, 0.495, 0.550),
        RGB(0.270, 0.428, 0.900),
        RGB(0.820, 0.492, 0.793),
        RGB(0.448, 0.640, 0.528),
        RGB(0.637, 0.270, 0.900),
        RGB(0.328, 0.697, 0.820),
        RGB(0.900, 0.675, 0.360),
        RGB(0.900, 0.900, 0.360),
        RGB(0.820, 0.492, 0.547),
        RGB(0.385, 0.550, 0.468),
        RGB(0.246, 0.820, 0.437),
        RGB(0.820, 0.246, 0.724),
        RGB(0.620, 0.292, 0.730),
        RGB(0.519, 0.492, 0.820),
        RGB(0.820, 0.676, 0.574),
        RGB(0.900, 0.450, 0.360),
        RGB(0.587, 0.640, 0.320),
    ] + HousePalette.widestLakes.map(RGB.init(hex:))
    static let houses: [Color] = houseRGB.map(\.colour)

    /// A colour as its three parts, for working out how it reads.
    struct RGB: Equatable {
        let red, green, blue: Double

        init(_ red: Double, _ green: Double, _ blue: Double) {
            self.red = red
            self.green = green
            self.blue = blue
        }

        /// A colour from its bytes of red, green and blue, as 0xRRGGBB.
        init(hex: UInt32) {
            self.init(Double(hex >> 16 & 0xFF) / 255, Double(hex >> 8 & 0xFF) / 255, Double(hex & 0xFF) / 255)
        }

        var colour: Color { Color(red: red, green: green, blue: blue) }

        /// How bright it is to the eye, by the measure contrast is reckoned in.
        var luminance: Double {
            func linear(_ value: Double) -> Double { value <= 0.04045 ? value / 12.92 : pow((value + 0.055) / 1.055, 2.4) }
            return 0.2126 * linear(red) + 0.7152 * linear(green) + 0.0722 * linear(blue)
        }

        func contrast(with other: RGB) -> Double {
            let (light, dark) = (max(luminance, other.luminance), min(luminance, other.luminance))
            return (light + 0.05) / (dark + 0.05)
        }

        /// Part of the way to another colour.
        func toward(_ other: RGB, by amount: Double) -> RGB {
            RGB(red + (other.red - red) * amount, green + (other.green - green) * amount, blue + (other.blue - blue) * amount)
        }
    }

    /// The panels' own dark, and the pale type's ink, as parts.
    static let panelRGB = RGB(0.02, 0.025, 0.035)
    static let inkRGB = RGB(0.894, 0.918, 0.949)

    /// How plainly a House's colour reads when it colours words: ten to one
    /// on a panel's dark, so its smallest strokes read too.
    static let houseWordsContrast = 10.0

    /// The pale type, by the launcher's one rule: as faint as the design
    /// asks, but never too faint to read, and plainer with Increase Contrast.
    static func text(_ opacity: Double) -> Color {
        LauncherKit.Palette.text(opacity)
    }

    /// A line, a track or a mark that isn't type, by the launcher's rule.
    static func line(_ opacity: Double) -> Color {
        LauncherKit.Palette.line(opacity)
    }

    static func house(_ house: House) -> Color {
        houses[house.sigil % houses.count]
    }

    /// A House's colour for its words (a name, the land it holds): its own
    /// hue, lifted toward the ink until it reads as plainly as the rest of
    /// the type, never left to read as a mark does.
    static func houseWords(_ house: House) -> Color {
        houseWordsRGB(house.sigil % houseRGB.count).colour
    }

    static func houseWordsRGB(_ index: Int) -> RGB {
        let own = houseRGB[index]
        let wanted = houseWordsContrast + (Contrast.shared.isIncreased ? 3 : 0)
        var amount = 0.0
        while own.toward(inkRGB, by: amount).contrast(with: panelRGB) < wanted, amount < 1 { amount += 0.05 }
        return own.toward(inkRGB, by: min(amount, 1))
    }

    static func tone(_ tone: GameSession.Notice.Tone) -> Color {
        switch tone {
        case .neutral: return text(0.8)
        case .good: return good
        case .bad: return bad
        }
    }
}

/// Uppercase, widely tracked type, as in the launcher. Tracking adds
/// space after the last letter; centred capitals take the same before the
/// first, as the launcher's do, so they sit centred over what lies beneath.
struct Caps: View {
    let text: String
    var size: CGFloat = 10
    var weight: Font.Weight = .regular
    var tracking: CGFloat = 0.28
    var centred = false

    init(_ text: String, size: CGFloat = 10, weight: Font.Weight = .regular, tracking: CGFloat = 0.28, centred: Bool = false) {
        self.text = text
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.centred = centred
    }

    var body: some View {
        // Spaced by the size the letters are drawn at, Larger type and all.
        let drawn = TextSize.shared.size(size)
        Text(verbatim: text.uppercased())
            .font(.nmCaps(size, weight: weight))
            .tracking(drawn * tracking)
            .padding(.leading, centred ? drawn * tracking : 0)
            // Read as words, not as capitals to be spelled.
            .accessibilityLabel(Text(verbatim: text))
    }
}

extension Font {
    /// The interface's words at a size, scaled by the reader's choice, and
    /// never under the least that reads: eleven points, whose full stops
    /// and dots still cover whole pixels; and at a weight that holds its
    /// contrast at the size drawn.
    @MainActor
    static func nm(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let drawn = TextSize.shared.size(size, words: true)
        return .system(size: drawn, weight: Font.readable(weight, at: drawn))
    }

    /// The interface's spaced capitals, whose strokes are all full height:
    /// never under nine and a half points.
    @MainActor
    static func nmCaps(_ size: CGFloat, weight: Font.Weight = .regular) -> Font {
        let drawn = TextSize.shared.size(size)
        return .system(size: drawn, weight: Font.readable(weight, at: drawn))
    }

    static func readable(_ weight: Font.Weight, at size: CGFloat) -> Font.Weight {
        TextSize.readable(weight, at: size)
    }
}

/// A thin rule that fades at both ends.
struct Rule: View {
    var opacity: Double = 0.3

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        LinearGradient(colors: [.clear, Palette.line(opacity), .clear], startPoint: .leading, endPoint: .trailing)
            .frame(height: 1 / displayScale)
    }
}

/// The dark glass behind panels.
struct PanelBackground: ViewModifier {
    @Environment(\.colorSchemeContrast) private var contrast

    func body(content: Content) -> some View {
        content
            // Wholly dark: what lies beneath, the salt flats by moonlight or
            // a token, never shows through behind the type.
            .background(Palette.panel)
            .overlay(
                RoundedRectangle(cornerRadius: 3)
                    .strokeBorder(Palette.line(0.12), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 3))
            .chrome("panel")
    }
}

/// What of the window the interface takes, piece by piece: each piece
/// notes where it lies as it is laid out, while a test listens, so the
/// world's share of the screen can be held to a budget.
@MainActor
enum ChromeLedger {
    static var isListening = false {
        didSet { frames = [:] }
    }
    /// Where each kind of piece lies, in the window's points.
    private(set) static var frames: [String: [CGRect]] = [:]

    static func note(_ name: String, _ frame: CGRect) {
        guard isListening, frame.width > 0, frame.height > 0, frames[name]?.contains(frame) != true else { return }
        frames[name, default: []].append(frame)
    }

    /// The share of a window of `size` the pieces cover, sampled every
    /// four points.
    static func covered(of size: CGSize) -> Double {
        let pieces = frames.values.flatMap { $0 }
        var covered = 0, all = 0
        for y in stride(from: 2.0, to: size.height, by: 4) {
            for x in stride(from: 2.0, to: size.width, by: 4) {
                all += 1
                if pieces.contains(where: { $0.contains(CGPoint(x: x, y: y)) }) { covered += 1 }
            }
        }
        return all == 0 ? 0 : Double(covered) / Double(all)
    }
}

extension EnvironmentValues {
    /// Within a card held to a height, its pieces are noted once, by the
    /// card's own frame: what scrolls out of sight is not on the screen.
    @Entry var chromeNotedByCard = false
}

/// Notes where a piece of the interface lies, unless the card it is in
/// notes it.
private struct ChromeNote: ViewModifier {
    let name: String
    @Environment(\.chromeNotedByCard) private var notedByCard

    func body(content: Content) -> some View {
        content.background(GeometryReader { proxy in
            let _ = notedByCard ? () : ChromeLedger.note(name, proxy.frame(in: .global))
            Color.clear
        })
    }
}

extension View {
    /// Notes where this piece of the interface lies, for the budget the
    /// world's share of the screen is held to.
    func chrome(_ name: String) -> some View {
        modifier(ChromeNote(name: name))
    }
}

extension View {
    /// A panel's scrolling body held to the height the play view gives
    /// panels, so the world keeps the screen: a share of it, for a record
    /// that stands beside the map and the rail.
    func panelHeight(_ share: CGFloat = 1) -> some View {
        modifier(PanelHeight(share: share))
    }
}

/// The height the play view gives a panel's scrolling body.
private struct PanelHeight: ViewModifier {
    let share: CGFloat
    @Environment(\.panelMaxHeight) private var maxHeight

    func body(content: Content) -> some View {
        content.frame(maxHeight: max(maxHeight * share, ChromeBudget.leastHeight))
    }
}

extension EnvironmentValues {
    /// How tall a panel's scrolling body may stand: set by the play view
    /// from its window, 620 points where none is set.
    @Entry var panelMaxHeight: CGFloat = 620
}

/// How much of the window's height a card or panel may take: the world is
/// the screen, the interface a little of its edges.
enum ChromeBudget {
    /// The share of the window's height a panel's body may stand to.
    static let cardShare: CGFloat = 0.46
    /// But never less than this, so a small window's panels still serve.
    static let leastHeight: CGFloat = 360
    /// A hold's record, beside the map and the rail, stands a little lower.
    static let recordShare: CGFloat = 0.85

    /// The height a panel's body may stand to in a window this tall.
    static func panelHeight(in window: CGFloat) -> CGFloat {
        max(window * cardShare, leastHeight)
    }
    /// The share of the window the world keeps, on every screen.
    static let worldShare: Double = 0.85
}

extension View {
    func panelBackground() -> some View {
        modifier(PanelBackground())
    }
}

/// How wide the interface's pieces lie over the map: narrow, so the world
/// keeps the screen. A panel on the rail; one read at length, the
/// Chronicle and the Guide, a little wider; and the column at the foot of
/// the map that holds what is chosen, the charge and counsel.
enum PanelWidth {
    static let rail: CGFloat = 328
    static let reading: CGFloat = 344
    static let record: CGFloat = 312
}

/// A quiet text button: spaced capitals that brighten on hover.
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
    /// What VoiceOver and Voice Control call it, where the words shown lean
    /// on what stands beside them: "Build II" in the row of the Walls is
    /// "Build Walls II".
    var name: String?
    /// Why it can't be pressed now, said with it while it can't.
    var why: String?
    let action: () -> Void

    /// The least a button is, either way, so it is easy to hit.
    static let least: CGFloat = 24

    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        let _ = pressable ? PressableButtons.note(title, enabled: enabled, action) : ()
        Button(action: action) {
            Caps(title, size: size, weight: prominent ? .medium : .regular)
                .lineLimit(1)
                .fixedSize()
                .foregroundStyle(enabled ? (tint ?? Palette.text(hovering || prominent ? 1 : 0.72)) : (tint ?? Palette.ink).opacity(0.3))
                .padding(.horizontal, prominent ? 16 : 8)
                .padding(.vertical, prominent ? 9 : 5)
                .frame(minWidth: Self.least, minHeight: Self.least)
                .background(
                    RoundedRectangle(cornerRadius: 2)
                        .fill(Palette.glow.opacity(prominent ? (hovering ? 0.22 : 0.14) : (hovering && enabled ? 0.08 : 0)))
                )
                .overlay(
                    RoundedRectangle(cornerRadius: 2)
                        .strokeBorder(Palette.line(prominent ? 0.35 : 0), lineWidth: 1)
                )
                .overlay(FocusRing(isFocused: focused))
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .focused($focused)
        .disabled(!enabled)
        .onPointer { hovering = $0 }
        .accessibilityLabel(name ?? title)
        .accessibilityHint(enabled ? "" : why ?? "")
    }
}

/// The ring a control with the keyboard wears, as the plain button style
/// leaves none: for those who move by Tab rather than pointer.
struct FocusRing: View {
    let isFocused: Bool

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(Palette.glow, lineWidth: 1.5)
            .padding(-2)
            .opacity(isFocused ? 1 : 0)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
    }
}

/// A resource amount, with what is missing shown in the warning colour,
/// and, with "Differentiate without colour" on, marked "short"; said in
/// words, with what is short.
struct CostLine: View {
    let cost: Stock
    let available: Stock

    /// What the stores lack to pay it: "short of 20 timber", or nil; in
    /// the words of the realm's own refusal (`Stock.listedSaid`).
    static func shortfall(of cost: Stock, from available: Stock) -> String? {
        let short = available.shortfall(for: cost)
        return short == Stock() ? nil : "short of " + short.listedSaid
    }

    var body: some View {
        // On as many lines as the width it is given needs: a long cost in a
        // narrow record, or in larger type, goes on beneath, not cut short.
        FlowLayout(spacing: 10, lineSpacing: 3) {
            ForEach(Resource.allCases, id: \.self) { resource in
                if cost[resource] > 0 {
                    let short = available[resource] < cost[resource]
                    HStack(spacing: 3) {
                        ResourceGlyph(resource: resource)
                        Text(verbatim: "\(cost[resource])")
                            .font(.nm(11, weight: .regular).monospacedDigit())
                        if short, Contrast.shared.differentiates {
                            Text(verbatim: "short").font(.nm(9, weight: .medium))
                        }
                    }
                    .foregroundStyle(short ? Palette.bad : Palette.text(0.75))
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Costs \(cost.description)" + (Self.shortfall(of: cost, from: available).map { "; \($0)" } ?? ""))
        .accessibilityAddTraits(.isStaticText)
    }
}

/// An amount, typed or stepped: a field for the number with the stepper's
/// arrows beside it, never under one nor over `most`; to VoiceOver, its
/// name and its value.
struct AmountField: View {
    let name: String
    @Binding var amount: Int
    let most: Int
    var step = 1

    /// What a typed or stepped amount comes to: within one and `most`.
    static func kept(_ amount: Int, most: Int) -> Int {
        min(max(amount, 1), max(1, most))
    }

    var body: some View {
        let kept = Binding(get: { amount }, set: { amount = Self.kept($0, most: most) })
        HStack(spacing: 4) {
            TextField(name, value: kept, format: .number.grouping(.never))
                .textFieldStyle(.plain)
                .font(.nm(11).monospacedDigit())
                .foregroundStyle(Palette.ink)
                .multilineTextAlignment(.trailing)
                .frame(width: 52)
                .accessibilityLabel(name)
            Stepper(name, value: kept, in: 1...max(1, most), step: step)
                .labelsHidden()
                .accessibilityLabel(name)
                .accessibilityValue("\(amount)")
        }
    }
}

/// A small drawn mark for each resource, in the colour the realm gives it:
/// a sheaf of grain, a fir of the blackwood for timber, a dressed block of
/// stone and a crystal of moonsalt, each lit from above and the left, so
/// each is told by its shape as well as its colour at the size of a word.
struct ResourceGlyph: View {
    let resource: Resource
    var size: CGFloat = 10

    var body: some View {
        DrawnMark(parts: ResourceGlyph.drawing(of: resource), size: size)
    }

    typealias Shade = StoreMarks.Shade

    /// Each resource's colour, as its stores, gains and costs are marked
    /// (`StoreMarks`, which the phone draws from too).
    static func colour(of resource: Resource) -> Shade { StoreMarks.colour(of: resource) }

    /// A resource's mark as filled outlines in a unit square, y down, each
    /// drawn over those before it, with its shade of the resource's colour:
    /// the marks the phone draws, as the rules keep them (`StoreMarks`).
    static func drawing(of resource: Resource) -> [(outline: [CGPoint], colour: Shade)] {
        StoreMarks.drawing(of: resource).map { part in (outline: part.outline.map { CGPoint(x: $0.x, y: $0.y) }, colour: part.colour) }
    }
}

/// A small drawn mark for each thing a satchel may hold: a salt hourglass
/// in its frame, a ward stone cut with its rune, a mending draught in its
/// flask, and a cache by the mark of the store it holds.
struct ItemGlyph: View {
    let kind: ItemKind
    var size: CGFloat = 14

    var body: some View {
        DrawnMark(parts: ItemGlyph.drawing(of: kind), size: size)
    }

    /// An item's mark as filled outlines in a unit square, y down, each
    /// drawn over those before it.
    static func drawing(of kind: ItemKind) -> [(outline: [CGPoint], colour: ResourceGlyph.Shade)] {
        func p(_ x: Double, _ y: Double) -> CGPoint { CGPoint(x: x, y: y) }
        let wood: ResourceGlyph.Shade = (0.55, 0.42, 0.28), glass: ResourceGlyph.Shade = (0.70, 0.75, 0.80)
        switch kind {
        case .grainCache: return ResourceGlyph.drawing(of: .grain)
        case .timberCache: return ResourceGlyph.drawing(of: .timber)
        case .stoneCache: return ResourceGlyph.drawing(of: .stone)
        case .moonsaltCache: return ResourceGlyph.drawing(of: .moonsalt)
        case .hourglass:
            // Two bulbs of glass in a wooden frame, the salt running down.
            let sand: ResourceGlyph.Shade = (0.86, 0.80, 0.62)
            return [([p(0.22, 0.04), p(0.78, 0.04), p(0.78, 0.13), p(0.22, 0.13)], wood),
                    ([p(0.22, 0.87), p(0.78, 0.87), p(0.78, 0.96), p(0.22, 0.96)], wood),
                    ([p(0.28, 0.13), p(0.72, 0.13), p(0.53, 0.5), p(0.47, 0.5)], glass),
                    ([p(0.47, 0.5), p(0.53, 0.5), p(0.72, 0.87), p(0.28, 0.87)], glass),
                    ([p(0.36, 0.26), p(0.64, 0.26), p(0.52, 0.48), p(0.48, 0.48)], sand),
                    ([p(0.4, 0.87), p(0.5, 0.66), p(0.6, 0.87)], sand),
                    ([p(0.25, 0.13), p(0.3, 0.13), p(0.3, 0.87), p(0.25, 0.87)], wood),
                    ([p(0.7, 0.13), p(0.75, 0.13), p(0.75, 0.87), p(0.7, 0.87)], wood)]
        case .wardStone:
            // A standing stone, its far side in shadow, cut with a pale rune.
            let stone: ResourceGlyph.Shade = (0.61, 0.61, 0.63), rune: ResourceGlyph.Shade = (0.70, 0.85, 1.0)
            return [([p(0.3, 0.98), p(0.24, 0.3), p(0.38, 0.06), p(0.62, 0.06), p(0.76, 0.3), p(0.7, 0.98)], stone),
                    ([p(0.5, 0.06), p(0.62, 0.06), p(0.76, 0.3), p(0.7, 0.98), p(0.5, 0.98)], (0.48, 0.48, 0.49)),
                    ([p(0.47, 0.24), p(0.53, 0.24), p(0.53, 0.8), p(0.47, 0.8)], rune),
                    ([p(0.5, 0.36), p(0.66, 0.5), p(0.62, 0.55), p(0.5, 0.45)], rune),
                    ([p(0.5, 0.52), p(0.34, 0.66), p(0.38, 0.71), p(0.5, 0.61)], rune)]
        case .mendingDraught:
            // A round flask stoppered, half full of a red draught, a gleam on it.
            return [([p(0.41, 0.14), p(0.59, 0.14), p(0.59, 0.4), p(0.41, 0.4)], glass),
                    (arc(about: p(0.5, 0.64), radius: 0.32, from: 0, to: 2 * .pi), glass),
                    (arc(about: p(0.5, 0.64), radius: 0.29, from: 0, to: .pi), (0.75, 0.25, 0.30)),
                    ([p(0.38, 0.03), p(0.62, 0.03), p(0.6, 0.16), p(0.4, 0.16)], (0.48, 0.36, 0.24)),
                    (arc(about: p(0.38, 0.5), radius: 0.06, from: 0, to: 2 * .pi), (0.92, 0.94, 0.96))]
        }
    }

    /// The points along a circle's arc about `centre`, from one angle to
    /// another, y down.
    private static func arc(about centre: CGPoint, radius: Double, from start: Double, to end: Double) -> [CGPoint] {
        (0...24).map { index in
            let angle = start + (end - start) * Double(index) / 24
            return CGPoint(x: Double(centre.x) + radius * cos(angle), y: Double(centre.y) + radius * sin(angle))
        }
    }
}

/// Filled outlines in a unit square drawn at `size` points, each in its
/// shade: the store and item marks.
private struct DrawnMark: View {
    let parts: [(outline: [CGPoint], colour: ResourceGlyph.Shade)]
    let size: CGFloat

    var body: some View {
        Canvas { context, canvas in
            for part in parts {
                var path = Path()
                path.addLines(part.outline.map { CGPoint(x: $0.x * canvas.width, y: $0.y * canvas.height) })
                path.closeSubpath()
                context.fill(path, with: .color(Color(red: part.colour.red, green: part.colour.green, blue: part.colour.blue)))
            }
        }
        .frame(width: size, height: size)
        .accessibilityHidden(true)
    }
}

/// Which button, across the realm's panels, has been pressed once and waits
/// for its second, for what can't be taken back, such as war. There is no
/// clock to beat, however long reading or scanning to it takes; arming
/// another, or the button leaving the view, lets it go, so no forgotten
/// one waits armed.
@MainActor
@Observable
final class ArmedPress {
    static let shared = ArmedPress()
    private(set) var armed: UUID?

    /// A press of the button `id`: whether it acts, as its second press.
    func press(_ id: UUID) -> Bool {
        if armed == id {
            armed = nil
            return true
        }
        armed = id
        return false
    }

    func isArmed(_ id: UUID) -> Bool { armed == id }

    func letGo(_ id: UUID) {
        if armed == id { armed = nil }
    }
}

/// The arrows moving the lit choice along a row of choices, by the
/// launcher's rule: left and up step back, right and down on. For the
/// realm's gate and door, where SwiftUI hears the keys.
struct ChoiceArrows: ViewModifier {
    @Binding var lit: Int
    let count: Int

    func body(content: Content) -> some View {
        content.onKeyPress(keys: [.leftArrow, .upArrow, .rightArrow, .downArrow]) { press in
            lit = ChoiceRow.step(lit, by: Self.command(for: press.key), among: count)
            return .handled
        }
    }

    /// The launcher's word for an arrow.
    static func command(for key: KeyEquivalent) -> KeyCommand {
        switch key {
        case .leftArrow: return .left
        case .upArrow: return .up
        case .downArrow: return .down
        default: return .right
        }
    }
}

/// A quiet button that asks again before doing what can't be undone. Its
/// name stays what it does, for VoiceOver and Voice Control alike; the
/// question it asks, armed, is said and shown, and is its value.
struct ConfirmButton: View {
    let title: String
    /// What it says once armed, such as "War on House Venn?".
    let confirm: String
    var size: CGFloat = 8.5
    let action: () -> Void

    @State private var id = UUID()

    var body: some View {
        let armed = ArmedPress.shared.isArmed(id)
        let _ = PressableButtons.note(title, enabled: true, action)
        QuietButton(title: armed ? confirm : title, size: size, tint: armed ? Palette.bad : nil, pressable: false, name: title) {
            if ArmedPress.shared.press(id) {
                action()
            } else {
                // Armed: said, for those who can't see the words change.
                AccessibilityNotification.Announcement("\(confirm) Press again to confirm.").post()
            }
        }
        .help(armed ? "Press again to confirm." : "Asks again before acting.")
        .accessibilityValue(armed ? confirm : "")
        .accessibilityHint("Press twice to confirm.")
        .onDisappear { ArmedPress.shared.letGo(id) }
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

/// A panel's scrolling, paged by the keyboard: Page Up and Page Down, as
/// the session hears them, move it most of its height, when the page is
/// meant for it.
struct PagedByKeys: ViewModifier {
    let request: GameSession.PageRequest
    let target: GameSession.PageTarget

    @State private var position = ScrollPosition(edge: .top)
    @State private var geometry = Extent()

    struct Extent: Equatable {
        var offset: CGFloat = 0
        var visible: CGFloat = 0
        var content: CGFloat = 0
    }

    /// Where a page in `direction` lands: most of a height on, never past
    /// either end.
    static func landing(after extent: Extent, direction: Int) -> CGFloat {
        let step = extent.visible * 0.85 * CGFloat(direction)
        return min(max(extent.offset + step, 0), max(extent.content - extent.visible, 0))
    }

    func body(content: Content) -> some View {
        content
            .scrollPosition($position)
            .onScrollGeometryChange(for: Extent.self) { scroll in
                Extent(offset: scroll.contentOffset.y, visible: scroll.containerSize.height, content: scroll.contentSize.height)
            } action: { _, extent in
                geometry = extent
            }
            .onChange(of: request) { _, request in
                guard request.target == target else { return }
                position.scrollTo(y: Self.landing(after: geometry, direction: request.direction))
            }
    }
}

extension View {
    /// Pages this scrolling panel by Page Up and Page Down.
    func pagedByKeys(_ session: GameSession, as target: GameSession.PageTarget) -> some View {
        modifier(PagedByKeys(request: session.pageRequest, target: target))
    }

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

