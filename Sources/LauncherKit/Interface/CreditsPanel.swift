import LauncherCore
import SwiftUI

/// Who made Nullmere Online, rolled slowly up through a window on the
/// water, round again at the end; with motion reduced, or still chosen in
/// the settings, the credits stand still and scroll by hand.
struct CreditsPanel: View {
    let model: LauncherModel

    @Environment(\.launcherUnit) private var unit
    @Environment(\.launcherRhythm) private var rhythm
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var isReturnHovered = false
    @State private var rollHeight: CGFloat = 0
    @State private var began = Date()

    /// Whether the credits roll: only in full motion.
    private var rolls: Bool {
        model.settings.motion.resolved(systemReducesMotion: reduceMotion) == .full
    }

    var body: some View {
        let window = 300 * unit * rhythm
        VStack(spacing: 0) {
            PanelHeader(title: "Credits")
            Group {
                if rolls {
                    TimelineView(.animation) { context in
                        let rolled = Credits.offset(at: context.date.timeIntervalSince(began), rollHeight: Double(rollHeight),
                                                    windowHeight: Double(window), unit: Double(unit))
                        roll
                            .offset(y: window - CGFloat(rolled))
                            .frame(height: window, alignment: .top)
                    }
                    .clipped()
                    .mask(fade)
                } else {
                    ScrollView {
                        roll
                    }
                    .scrollIndicators(.never)
                    .frame(height: window)
                    .mask(fade)
                }
            }
            .frame(width: 520 * unit)
            .accessibilityElement(children: .combine)
            .accessibilityLabel(Credits.lines.map(\.text).joined(separator: ". "))

            MenuButton(title: "Back", isSelected: isReturnHovered) {
                model.returnToTitle()
            }
            .onPointer { isReturnHovered = $0 }
            .padding(.top, 16 * unit * rhythm)
        }
        .onAppear { began = Date() }
    }

    /// Every line of the credits, top to bottom, measured as it is laid out.
    private var roll: some View {
        VStack(spacing: 0) {
            ForEach(Array(Credits.lines.enumerated()), id: \.offset) { _, line in
                text(for: line)
            }
        }
        .frame(maxWidth: .infinity)
        .background {
            GeometryReader { proxy in
                Color.clear.onAppear { rollHeight = proxy.size.height }
            }
        }
    }

    @ViewBuilder
    private func text(for line: Credits.Line) -> some View {
        switch line.kind {
        case .title:
            SpacedText(line.text, size: .launcherType(16, unit: unit), weight: .light, tracking: 0.5)
                .foregroundStyle(Palette.text(0.96))
                .padding(.bottom, 26 * unit * rhythm)
        case .heading:
            SpacedText(line.text, size: .launcherType(9.5, unit: unit), weight: .regular, tracking: 0.42)
                .foregroundStyle(Palette.glow)
                .padding(.top, 18 * unit * rhythm)
                .padding(.bottom, 6 * unit * rhythm)
        case .entry:
            Text(verbatim: line.text)
                .font(.launcher(.launcherType(13, unit: unit), weight: .regular))
                .foregroundStyle(Palette.text(0.82))
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.vertical, 2 * unit)
        }
    }

    /// The window's edges fade into the water.
    private var fade: some View {
        LinearGradient(stops: [.init(color: .clear, location: 0), .init(color: .black, location: 0.12),
                               .init(color: .black, location: 0.88), .init(color: .clear, location: 1)],
                       startPoint: .top, endPoint: .bottom)
    }
}
