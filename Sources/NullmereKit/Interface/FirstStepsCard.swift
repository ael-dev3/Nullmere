import NullmereCore
import SwiftUI

/// A new keeper's first steps, ticked as they're done.
struct FirstStepsCard: View {
    let steps: FirstSteps
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caps("First steps", size: 8.5, weight: .medium).foregroundStyle(Palette.glow)
                Spacer()
                CloseButton(action: dismiss)
            }
            ForEach(FirstSteps.Step.allCases, id: \.self) { step in
                let done = steps.done.contains(step)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.nm(10))
                        .foregroundStyle(done ? Palette.good : Palette.ink.opacity(0.45))
                    Text(verbatim: step.title)
                        .font(.nm(11.5, weight: .light))
                        .foregroundStyle(Palette.ink.opacity(done ? 0.45 : 0.9))
                        .strikethrough(done, color: Palette.ink.opacity(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(step.title), \(done ? "done" : "to do")")
            }
        }
        .padding(14)
        .frame(width: 330)
        .panelBackground()
    }
}
