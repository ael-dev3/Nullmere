import Observation
import SwiftUI

/// The launcher's few colours: pale, slightly cold type and its glow. The
/// realm's interface takes its own from here, so the two are one.
public enum Palette {
    public static let ink = Color(red: inkRGB.red, green: inkRGB.green, blue: inkRGB.blue)
    public static let glow = Color(red: 0.588, green: 0.706, blue: 0.882)

    static let inkRGB = (red: 0.894, green: 0.918, blue: 0.949)
    /// The dark the interface lies on: the night water, and the panels over it.
    static let nightRGB = (red: 0.016, green: 0.020, blue: 0.030)

    /// How much of the ink a text shows at the strength the design asks,
    /// made to read: never under nine tenths, so that even a full stop or a
    /// middle dot, whose few pixels are never wholly covered at a 1x
    /// display's size, still stands well clear of the dark; with Increase
    /// Contrast on, the full ink. What the design asks fainter is fainter
    /// still, by a little: the type's size and weight carry the rest.
    public static let textFloor = 0.9

    public static func textStrength(_ opacity: Double) -> Double {
        if Contrast.shared.isIncreased { return 1 }
        return textFloor + (1 - textFloor) * Swift.min(Swift.max(opacity, 0), 1)
    }

    /// The pale type at that strength, and solid: mixed from the dark to the
    /// ink rather than laid over what lies beneath, so it reads the same
    /// over the water, the map or a panel, and measures as it looks. The
    /// launcher's type and the realm's follow this one rule.
    public static func text(_ opacity: Double) -> Color {
        let strength = textStrength(opacity)
        func mixed(_ dark: Double, _ light: Double) -> Double { dark + (light - dark) * strength }
        return Color(red: mixed(nightRGB.red, inkRGB.red), green: mixed(nightRGB.green, inkRGB.green),
                     blue: mixed(nightRGB.blue, inkRGB.blue))
    }

    /// A line, a track or a mark that isn't type, at the opacity the design
    /// asks: with Increase Contrast on, twice as plain, up to 0.4, so it
    /// shows clearly and an empty meter still can't be taken for a full one.
    public static func line(_ opacity: Double) -> Color {
        ink.opacity(Contrast.shared.isIncreased ? Swift.max(opacity, Swift.min(opacity * 2, 0.4)) : opacity)
    }
}

/// Whether the Mac asks for more contrast, and for what colour says to be
/// said in shape too: read as the launcher and the realm draw, set where
/// each window begins, from its environment, on the main thread.
@Observable
public final class Contrast: @unchecked Sendable {
    public static let shared = Contrast()
    public var isIncreased = false
    /// "Differentiate without colour".
    public var differentiates = false
}

/// Scale for type and spacing; 1 at the reference window size.
private struct LauncherUnitKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension CGFloat {
    /// A size of the launcher's type: scaled with the window, by the
    /// reader's Larger type too (one setting with the realm's), and never
    /// under the least that reads, however small the window.
    @MainActor
    public static func launcherType(_ size: CGFloat, unit: CGFloat) -> CGFloat {
        let text = TextSize.shared
        return Swift.max(size * unit * text.scale, text.isLarger ? TextSize.smallestLarger : TextSize.smallestLauncher)
    }
}

extension Font {
    /// The launcher's type at a size from `launcherType`, at a weight that
    /// holds its contrast there (see `TextSize.readable`).
    public static func launcher(_ size: CGFloat, weight: Font.Weight) -> Font {
        .system(size: size, weight: TextSize.readable(weight, at: size))
    }
}

extension EnvironmentValues {
    public var launcherUnit: CGFloat {
        get { self[LauncherUnitKey.self] }
        set { self[LauncherUnitKey.self] = newValue }
    }
}

/// Uppercase, widely tracked type.
///
/// Tracking also adds space after the last glyph. Centred text gets the same
/// space before the first glyph, so the word stays optically centred;
/// left-aligned text doesn't, so it lines up with the text around it.
public struct SpacedText: View {
    private let text: String
    /// The words as written, for VoiceOver: it reads them as words, not as
    /// capitals to be spelled.
    private let spoken: String
    private let size: CGFloat
    private let weight: Font.Weight
    private let tracking: CGFloat
    private let balanced: Bool

    /// - Parameters:
    ///   - tracking: letter spacing in ems.
    ///   - balanced: whether to pad the leading edge to match the trailing tracking.
    public init(_ text: String, size: CGFloat, weight: Font.Weight = .light, tracking: CGFloat, balanced: Bool = true) {
        self.text = text.uppercased()
        self.spoken = text
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.balanced = balanced
    }

    public var body: some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: TextSize.readable(weight, at: size)))
            .tracking(size * tracking)
            .padding(.leading, balanced ? size * tracking : 0)
            .fixedSize()
            .accessibilityLabel(Text(verbatim: spoken))
    }
}

/// The title word. Its tracking is animatable so the letters can settle
/// together as the title fades in.
struct TitleWord: View, Animatable {
    var text: String
    var size: CGFloat
    /// Letter spacing in ems.
    var tracking: CGFloat

    var animatableData: CGFloat {
        get { tracking }
        set { tracking = newValue }
    }

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: .thin))
            .tracking(size * tracking)
            .padding(.leading, size * tracking)
            .fixedSize()
    }
}

/// A horizontal hairline that fades out at both ends.
struct Hairline: View {
    var width: CGFloat
    var opacity: Double = 0.45

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        LinearGradient(
            colors: [.clear, Palette.line(opacity), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width, height: 1 / displayScale)
    }
}

/// A hairline as wide as the space it is given, brightest in the middle.
public struct Underline: View {
    var opacity: Double = 0.75

    @Environment(\.displayScale) private var displayScale

    public init(opacity: Double = 0.75) {
        self.opacity = opacity
    }

    public var body: some View {
        LinearGradient(
            colors: [.clear, Palette.line(opacity), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(height: 1 / displayScale)
    }
}

/// A short solid rule used to mark the focused row.
struct SelectionTick: View {
    var isVisible: Bool
    var length: CGFloat

    var body: some View {
        Rectangle()
            .frame(width: isVisible ? length : 0, height: 1)
            .opacity(isVisible ? 0.6 : 0)
    }
}

/// A small dot: lit and glowing when something is ready, a faint ring when
/// not. The realm's front door shows the realm's state with it too.
public struct StatusDot: View {
    var isLit: Bool

    @Environment(\.launcherUnit) private var unit

    public init(isLit: Bool) {
        self.isLit = isLit
    }

    public var body: some View {
        Circle()
            .fill(Palette.glow.opacity(isLit ? 0.95 : 0))
            .overlay {
                Circle().strokeBorder(Palette.line(isLit ? 0 : 0.5), lineWidth: 1)
            }
            .frame(width: 5 * unit, height: 5 * unit)
            .shadow(color: Palette.glow.opacity(isLit ? 0.8 : 0), radius: 4 * unit)
            .accessibilityHidden(true)
    }
}

/// A panel's heading: spaced capitals over a short hairline.
public struct PanelHeader: View {
    let title: String

    @Environment(\.launcherUnit) private var unit

    public init(title: String) {
        self.title = title
    }

    public var body: some View {
        VStack(spacing: 14 * unit) {
            SpacedText(title, size: .launcherType(12, unit: unit), weight: .regular, tracking: 0.6)
                .foregroundStyle(Palette.text(0.86))
                .accessibilityAddTraits(.isHeader)
            Hairline(width: 64 * unit)
        }
        .padding(.bottom, 20 * unit)
    }
}
