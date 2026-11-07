import NullmereCore
import SwiftUI

/// The Houses a composer offers to name, each drawn as the composer draws
/// it: every House of up to ninety-six standing that may be named; past
/// that, the Houses the keeper has reason to name, nearest first, and a
/// field to find any other by its name (`GameState.houseChoice`).
struct HouseChooser<Choice: View>: View {
    let session: GameSession
    let excluding: Set<Int>
    let among: Set<Int>?
    let choice: (House) -> Choice

    @State private var query: String

    /// A chooser of the Houses (of those `among`, where only some may be
    /// named) but those `excluding`, with a name already looked for if one
    /// is given.
    init(session: GameSession, excluding: Set<Int> = [], among: Set<Int>? = nil, query: String = "",
         @ViewBuilder choice: @escaping (House) -> Choice) {
        self.session = session
        self.excluding = excluding
        self.among = among
        self.choice = choice
        _query = State(initialValue: query)
    }

    var body: some View {
        let found = session.state.houseChoice(by: session.player, matching: query, excluding: excluding, among: among,
                                              standings: session.standings)
        VStack(alignment: .leading, spacing: 6) {
            if found.searchable {
                Text(verbatim: HouseChoice.offeredLine)
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                TextField("Find a House by its name", text: $query)
                    .textFieldStyle(.plain)
                    .font(.nm(11))
                    .foregroundStyle(Palette.ink)
                    .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                    .accessibilityLabel("Find a House by its name")
            }
            FlowLayout(spacing: 6, lineSpacing: 4) {
                ForEach(found.offered) { house in
                    choice(house)
                }
            }
            if let line = HouseChoice.foundLine(found, query: query) {
                Text(verbatim: line)
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
