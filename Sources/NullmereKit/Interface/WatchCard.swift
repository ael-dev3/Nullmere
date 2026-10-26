import NullmereCore
import SwiftUI

/// The turning of a watch: its number, large and thin, over the map, with
/// what it brought. It fades by itself and never takes a click.
struct WatchCard: View {
    let summary: WatchSummary

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var risen = false

    var body: some View {
        VStack(spacing: 10) {
            Caps("Watch \(summary.watch)", size: 26, weight: .thin, tracking: 0.45)
                .foregroundStyle(Palette.ink)
                .shadow(color: .black.opacity(0.9), radius: 12)
            Rule(opacity: 0.4).frame(width: 220)
            if !summary.changes.isEmpty {
                HStack(spacing: 14) {
                    ForEach(summary.changes, id: \.self) { change in
                        HStack(spacing: 4) {
                            ResourceGlyph(resource: change.resource)
                            Text(verbatim: change.delta > 0 ? "+\(change.delta)" : "\(change.delta)")
                                .font(.system(size: 12).monospacedDigit())
                                .foregroundStyle(change.delta > 0 ? Palette.good : Palette.bad)
                        }
                    }
                }
            }
            if !summary.events.isEmpty {
                Text(verbatim: summary.events.joined(separator: "  ·  "))
                    .font(.system(size: 12, weight: .light))
                    .foregroundStyle(Palette.ink.opacity(0.85))
            }
        }
        .padding(.horizontal, 30)
        .padding(.vertical, 18)
        // A soft pool of dark, wider than the card, with no edge.
        .background(
            EllipticalGradient(colors: [.black.opacity(0.72), .black.opacity(0.35), .clear], center: .center,
                               startRadiusFraction: 0, endRadiusFraction: 0.5)
                .frame(width: 720, height: 240)
                .allowsHitTesting(false)
        )
        .offset(y: risen || reduceMotion ? 0 : 10)
        .onAppear { withAnimation(.easeOut(duration: 0.7)) { risen = true } }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Watch \(summary.watch). \(summary.events.joined(separator: ". "))")
    }
}

/// A soft darkening at the map's edges, so the eye rests on the middle.
struct MapVignette: View {
    var body: some View {
        RadialGradient(
            colors: [.clear, .clear, .black.opacity(0.45)],
            center: .center,
            startRadius: 0,
            endRadius: 900
        )
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }
}
