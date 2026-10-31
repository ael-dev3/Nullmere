import NullmereCore
import SwiftUI

/// A record's long list folded to its name and a line of what matters in
/// it now, until the keeper asks for the whole: a record opens on what is
/// worth knowing, not on every row it could show.
struct FoldedList<Content: View>: View {
    let title: String
    /// How many rows it holds, said on the button while it is folded.
    let count: Int
    /// What matters in it, in a line, while it is folded.
    let summary: String
    @Binding var open: Bool
    /// Open whatever the keeper chose: a row in focus, or a charge's Show
    /// me pointing into it.
    var held = false
    @ViewBuilder let content: () -> Content

    var body: some View {
        let shown = open || held
        VStack(alignment: .leading, spacing: shown ? 8 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Caps(title, size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
                Spacer()
                if !held {
                    QuietButton(title: shown ? "Fold \(title.lowercased())" : "All \(count) \(title.lowercased())", size: 8.5,
                                name: shown ? "Fold the \(title.lowercased()) away" : "Show all \(count) \(title.lowercased())") {
                        open.toggle()
                    }
                }
            }
            if shown {
                content()
            } else {
                Text(verbatim: summary)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

extension OwnHoldDetails {
    /// The works a hold may raise: all, but the seat's own at a seat only.
    static func works(of hold: Hold) -> [BuildingKind] {
        BuildingKind.allCases.filter { !$0.requiresSeat || hold.isSeat }
    }

    /// A hold's works in a line: how many are raised, and whether one is
    /// rising or how many the House's stores would raise a stage now.
    static func worksSummary(of hold: Hold, in state: GameState, for house: Int) -> String {
        let works = works(of: hold)
        let raised = works.filter { hold.level($0) > 0 }.count
        let stock = state.houses.indices.contains(house) ? state.houses[house].stock : .zero
        let affordable = works.filter { kind in
            hold.level(kind) < kind.maxLevel && stock.covers(state.buildCost(of: kind, toLevel: hold.level(kind) + 1, for: house))
        }.count
        let now = hold.project != nil ? "a work rising" : affordable == 0 ? "none within your stores" : "\(affordable) may rise now"
        return "\(raised) of \(works.count) raised · \(now)"
    }

    /// The companies a hold musters in a line: how many it may train, and
    /// whether one is training or how many the stores would train now.
    static func companiesSummary(of hold: Hold, in state: GameState, for house: Int) -> String {
        let stock = state.houses.indices.contains(house) ? state.houses[house].stock : .zero
        let allowed = UnitKind.allCases.filter { hold.level(.musterHall) >= $0.requiredMuster }
        let affordable = allowed.filter { kind in
            stock.covers(state.trainingCost(of: kind, tier: state.highestTier(of: kind, at: hold, for: house), for: house))
        }.count
        let now = hold.training != nil ? "one training" : affordable == 0 ? "none within your stores" : "\(affordable) may train now"
        return "\(allowed.count) of \(UnitKind.allCases.count) mustered here · \(now)"
    }
}
