#if DEBUG
import SwiftUI

/// Debug builds only, and only with NULLMERE_AUDIT_PROBE set: the same few
/// words set on the lake in each of the ways the launcher sets its type, so
/// one run of Xcode's accessibility audit says which of them it finds hard to
/// read. The UI tests read the verdicts; no keeper ever sees this.
struct AuditProbes: View {
    @Environment(\.launcherUnit) private var unit

    static var isShown: Bool {
        ProcessInfo.processInfo.environment["NULLMERE_AUDIT_PROBE"] != nil
    }

    var body: some View {
        let small = CGFloat.launcherType(9.5, unit: unit)
        // Two columns low on the water, either side of the menu.
        ZStack {
        VStack(alignment: .leading, spacing: 9 * unit) {
            // 1: spaced capitals on the water's dark, as the version is.
            SpacedText("Probe one", size: small, weight: .regular, tracking: 0.3)
                .onNight()
                .accessibilityLabel("Probe 1")
            // 2: a dot and capitals as one element, as the model's status is.
            HStack(spacing: 10 * unit) {
                StatusDot(isLit: true)
                SpacedText("Probe two", size: small, weight: .regular, tracking: 0.3)
            }
            .onNight()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Probe 2")
            .accessibilityAddTraits(.isStaticText)
            // 3: capitals as one element, no dot.
            HStack(spacing: 10 * unit) {
                SpacedText("Probe three", size: small, weight: .regular, tracking: 0.3)
            }
            .onNight()
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("Probe 3")
            .accessibilityAddTraits(.isStaticText)
            // 4: capitals with nothing behind them but the lake.
            SpacedText("Probe four", size: small, weight: .regular, tracking: 0.3)
                .accessibilityLabel("Probe 4")
            // 5: capitals on a dark that reaches past them.
            SpacedText("Probe five", size: small, weight: .regular, tracking: 0.3)
                .background { Palette.night.padding(-8 * unit) }
                .accessibilityLabel("Probe 5")
            // 6: words at 12.5 points, as a story's body is.
            Text(verbatim: "Probe six: the lake has gone dead still.")
                .font(.launcher(.launcherType(12.5, unit: unit), weight: .regular))
                .onNight()
                .accessibilityLabel("Probe 6")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomLeading)
        VStack(alignment: .trailing, spacing: 9 * unit) {
            // 7: words at 13 points in a wide frame, as the requirement's are.
            Text(verbatim: "Probe seven: the lake has gone dead still.")
                .font(.launcher(.launcherType(13, unit: unit), weight: .regular))
                .frame(maxWidth: 300 * unit, alignment: .trailing)
                .onNight()
                .accessibilityLabel("Probe 7")
            // 8: words at 12.5 points on a dark that reaches past them.
            Text(verbatim: "Probe eight: the lake has gone dead still.")
                .font(.launcher(.launcherType(12.5, unit: unit), weight: .regular))
                .background { Palette.night.padding(-8 * unit) }
                .accessibilityLabel("Probe 8")
            // 9: the smallest words, as the note on identity is.
            Text(verbatim: "Probe nine: the lake has gone dead still.")
                .font(.launcher(.launcherType(10, unit: unit), weight: .regular))
                .onNight()
                .accessibilityLabel("Probe 9")
            // 10: the smallest words on a dark that reaches past them.
            Text(verbatim: "Probe ten: the lake has gone dead still.")
                .font(.launcher(.launcherType(10, unit: unit), weight: .regular))
                .background { Palette.night.padding(-8 * unit) }
                .accessibilityLabel("Probe 10")
            // 11: capitals on a filled shape rather than a colour.
            SpacedText("Probe eleven", size: small, weight: .regular, tracking: 0.3)
                .background(Rectangle().fill(Palette.night))
                .accessibilityLabel("Probe 11")
            // 12: capitals at eleven points, medium.
            SpacedText("Probe twelve", size: .launcherType(11, unit: unit), weight: .medium, tracking: 0.3)
                .onNight()
                .accessibilityLabel("Probe 12")
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottomTrailing)
        }
        .foregroundStyle(Palette.text(0.8))
        .padding(.horizontal, 30 * unit)
        .padding(.bottom, 70 * unit)
    }
}
#endif
