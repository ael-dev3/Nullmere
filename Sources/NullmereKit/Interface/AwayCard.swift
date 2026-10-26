import NullmereCore
import SwiftUI

/// On returning: what happened to the keeper's House while they were away.
struct AwayCard: View {
    let report: AwayReport
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Caps(report.title, size: 11, weight: .medium, tracking: 0.3)
                .foregroundStyle(Palette.ink)
                .fixedSize(horizontal: false, vertical: true)
            Rule(opacity: 0.3)
            if !report.changes.isEmpty || report.holdsLine != nil {
                HStack(spacing: 14) {
                    ForEach(report.changes, id: \.self) { change in
                        HStack(spacing: 4) {
                            ResourceGlyph(resource: change.resource)
                            Text(verbatim: change.delta > 0 ? "+\(change.delta)" : "\(change.delta)")
                                .font(.nm(12).monospacedDigit())
                                .foregroundStyle(change.delta > 0 ? Palette.good : Palette.bad)
                        }
                        .accessibilityElement(children: .ignore)
                        .accessibilityLabel("\(change.resource.title) \(change.delta > 0 ? "up" : "down") \(abs(change.delta))")
                    }
                    if let holds = report.holdsLine {
                        Text(verbatim: holds)
                            .font(.nm(11))
                            .foregroundStyle(report.holdsChange > 0 ? Palette.good : Palette.bad)
                    }
                }
            }
            if report.news.isEmpty {
                Text(verbatim: "Your House stood quiet; nothing touched it.")
                    .font(.nm(12, weight: .light))
                    .foregroundStyle(Palette.ink.opacity(0.75))
            } else {
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(Array(report.news.enumerated()), id: \.offset) { _, line in
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            Circle().fill(Palette.ink.opacity(0.4)).frame(width: 3, height: 3)
                            Text(verbatim: line)
                                .font(.nm(12, weight: .light))
                                .foregroundStyle(Palette.ink.opacity(0.88))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                }
            }
            HStack {
                Spacer()
                QuietButton(title: "Back to It", size: 10.5, prominent: true, action: dismiss)
                    .keyboardShortcut(.defaultAction)
            }
        }
        .padding(22)
        .frame(width: 440)
        .panelBackground()
        .accessibilityElement(children: .contain)
        .accessibilityAddTraits(.isModal)
    }
}
