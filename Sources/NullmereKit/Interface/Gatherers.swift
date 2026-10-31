import LauncherKit
import NullmereCore
import SwiftUI

/// The House's companies out at the land's work, folded away under a
/// gatherer's record until asked for: each in a line, what it is about and
/// when it is done, and a press goes to it.
struct GathererList: View {
    let session: GameSession

    @AppStorage("gatherers.open") private var open = false

    /// Each gatherer of a House's, the first mustered first, in a line.
    static func rows(in state: GameState, of house: Int) -> [(id: Int, line: String)] {
        state.units(of: house).filter(state.isOutGathering).sorted { $0.id < $1.id }.map { ($0.id, line(for: $0, in: state)) }
    }

    /// What a gatherer is about, in short: at its site and when it will be
    /// full, bound for it, or home with its load, and when it will be there.
    static func line(for unit: Unit, in state: GameState) -> String {
        let name = state.title(of: unit) + (unit.kind.hasTiers ? " " + Narration.roman(unit.tier) : "")
        let there = UnitPanel.arrival(of: unit, in: state).map { ", there \($0)" } ?? ""
        let carried = unit.load.flatMap { load in
            Resource.allCases.first { load[$0] > 0 }.map { "\(load[$0]) \($0.title.lowercased())" }
        }
        switch unit.errand {
        case .gather(let siteID)?:
            let site = state.site(siteID).map { "the \(Site.title(of: $0.store)) \(Narration.roman($0.level))" } ?? "a site of the land"
            if let left = state.watchesToFill(unit) {
                return "\(name) at \(site), full " + (left <= 1 ? "as the watch turns" : "in \(left) watches")
            }
            return "\(name) bound for \(site)\(there)"
        case .homeward?:
            return "\(name) home with \(carried ?? "their load")\(there)"
        default:
            return "\(name) carrying \(carried ?? "nothing")"
        }
    }

    var body: some View {
        let rows = GathererList.rows(in: session.state, of: session.player)
        if rows.count > 1 {
            VStack(alignment: .leading, spacing: 4) {
                QuietButton(title: open ? "Gatherers" : "Gatherers (\(rows.count))", size: 8.5,
                            name: open ? "Fold the gatherers away" : "Show your \(rows.count) gatherers") {
                    open.toggle()
                }
                if open {
                    ForEach(rows, id: \.id) { row in
                        GathererRow(line: row.line) {
                            session.selection = .unit(row.id)
                            if let unit = session.state.unit(row.id) { session.glide(to: unit.position) }
                        }
                    }
                }
            }
        }
    }
}

/// A gatherer in a line, pressed to go to it.
private struct GathererRow: View {
    let line: String
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        let _ = PressableButtons.note(line, enabled: true, action)
        Button(action: action) {
            Text(verbatim: line)
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(hovering ? 0.95 : 0.7))
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel(line)
        .accessibilityHint("Go to them")
    }
}
