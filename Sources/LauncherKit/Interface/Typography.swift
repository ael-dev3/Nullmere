import SwiftUI

/// The launcher's few colours: pale, slightly cold type and its glow.
enum Palette {
    static let ink = Color(red: 0.894, green: 0.918, blue: 0.949)
    static let glow = Color(red: 0.588, green: 0.706, blue: 0.882)
}

/// Scale for type and spacing; 1 at the reference window size.
private struct LauncherUnitKey: EnvironmentKey {
    static let defaultValue: CGFloat = 1
}

extension EnvironmentValues {
    var launcherUnit: CGFloat {
        get { self[LauncherUnitKey.self] }
        set { self[LauncherUnitKey.self] = newValue }
    }
}

/// Uppercase, widely tracked type.
///
/// Tracking also adds space after the last glyph. Centred text gets the same
/// space before the first glyph, so the word stays optically centred;
/// left-aligned text doesn't, so it lines up with the text around it.
struct SpacedText: View {
    private let text: String
    private let size: CGFloat
    private let weight: Font.Weight
    private let tracking: CGFloat
    private let balanced: Bool

    /// - Parameters:
    ///   - tracking: letter spacing in ems.
    ///   - balanced: whether to pad the leading edge to match the trailing tracking.
    init(_ text: String, size: CGFloat, weight: Font.Weight = .light, tracking: CGFloat, balanced: Bool = true) {
        self.text = text.uppercased()
        self.size = size
        self.weight = weight
        self.tracking = tracking
        self.balanced = balanced
    }

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: weight))
            .tracking(size * tracking)
            .padding(.leading, balanced ? size * tracking : 0)
            .fixedSize()
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
            colors: [.clear, Palette.ink.opacity(opacity), .clear],
            startPoint: .leading,
            endPoint: .trailing
        )
        .frame(width: width, height: 1 / displayScale)
    }
}

/// A hairline as wide as the space it is given, brightest in the middle.
struct Underline: View {
    var opacity: Double = 0.75

    @Environment(\.displayScale) private var displayScale

    var body: some View {
        LinearGradient(
            colors: [.clear, Palette.ink.opacity(opacity), .clear],
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

/// A small dot: lit and glowing when something is ready, a faint ring when not.
struct StatusDot: View {
    var isLit: Bool

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        Circle()
            .fill(Palette.glow.opacity(isLit ? 0.95 : 0))
            .overlay {
                Circle().strokeBorder(Palette.ink.opacity(isLit ? 0 : 0.5), lineWidth: 1)
            }
            .frame(width: 5 * unit, height: 5 * unit)
            .shadow(color: Palette.glow.opacity(isLit ? 0.8 : 0), radius: 4 * unit)
            .accessibilityHidden(true)
    }
}

/// A panel's heading: spaced capitals over a short hairline.
struct PanelHeader: View {
    let title: String

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        VStack(spacing: 14 * unit) {
            SpacedText(title, size: 12 * unit, weight: .regular, tracking: 0.6)
                .foregroundStyle(Palette.ink.opacity(0.86))
                .accessibilityAddTraits(.isHeader)
            Hairline(width: 64 * unit)
        }
        .padding(.bottom, 20 * unit)
    }
}
