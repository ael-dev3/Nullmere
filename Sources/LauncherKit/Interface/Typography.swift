import SwiftUI

/// The launcher's few colours: pale, slightly cold type and its glow.
enum Palette {
    static let ink = Color(red: 0.894, green: 0.918, blue: 0.949)
    static let glow = Color(red: 0.588, green: 0.706, blue: 0.882)
}

/// Scale for type and spacing; 1 at the 800-point reference height.
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
/// Tracking also adds space after the last glyph, so the same amount is
/// added before the first one to keep the word optically centred.
struct SpacedText: View {
    private let text: String
    private let size: CGFloat
    private let weight: Font.Weight
    private let tracking: CGFloat

    /// - Parameter tracking: letter spacing in ems.
    init(_ text: String, size: CGFloat, weight: Font.Weight = .light, tracking: CGFloat) {
        self.text = text.uppercased()
        self.size = size
        self.weight = weight
        self.tracking = tracking
    }

    var body: some View {
        Text(verbatim: text)
            .font(.system(size: size, weight: weight))
            .tracking(size * tracking)
            .padding(.leading, size * tracking)
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

/// A short solid rule used to mark the selected item.
struct SelectionTick: View {
    var isVisible: Bool
    var length: CGFloat

    var body: some View {
        Rectangle()
            .frame(width: isVisible ? length : 0, height: 1)
            .opacity(isVisible ? 0.6 : 0)
    }
}
