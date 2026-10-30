import NullmereCore
import SwiftUI

/// A new keeper's first steps, ticked as they're done.
struct FirstStepsCard: View {
    let steps: FirstSteps
    let dismiss: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Caps("First steps", size: 8.5, weight: .medium).foregroundStyle(Palette.glowWords)
                Spacer()
                CloseButton(label: "Hide first steps", action: dismiss)
            }
            ForEach(FirstSteps.Step.allCases, id: \.self) { step in
                let done = steps.done.contains(step)
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Image(systemName: done ? "checkmark.circle.fill" : "circle")
                        .font(.nm(10))
                        .foregroundStyle(done ? Palette.good : Palette.text(0.45))
                    Text(verbatim: step.title)
                        .font(.nm(11.5, weight: .light))
                        .foregroundStyle(Palette.text(done ? 0.7 : 0.9))
                        .strikethrough(done, color: Palette.line(0.35))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("\(step.title), \(done ? "done" : "to do")")
                .accessibilityAddTraits(.isStaticText)
            }
        }
        .padding(14)
        .frame(width: 330)
        .panelBackground()
    }
}
