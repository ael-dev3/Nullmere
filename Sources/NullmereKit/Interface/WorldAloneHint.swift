import SwiftUI

/// While the keeper has put the interface away to see the world alone, a
/// word low in the view of how to bring it back, which fades after a few
/// seconds and never takes a click. VoiceOver is told it as the interface
/// goes (`GameSession.toggleInterface()`).
struct WorldAloneHint: View {
    /// How long the word stands before it fades.
    static let stands: Duration = .seconds(3)

    @State private var faded = false

    var body: some View {
        Text(verbatim: GameSession.interfaceHiddenSaid)
            .font(.nm(11, weight: .light))
            .foregroundStyle(Palette.text(0.75))
            .padding(.horizontal, 18)
            .padding(.vertical, 9)
            // A soft pool of dark under it, with no edge, as the watch's card.
            .background(
                Capsule().fill(Color.black.opacity(0.45))
            )
            .opacity(faded ? 0 : 1)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            .padding(.bottom, 28)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .task {
                try? await Task.sleep(for: WorldAloneHint.stands)
                withAnimation(.easeOut(duration: 0.8)) { faded = true }
            }
    }
}
