import Charts
import NullmereCore
import SwiftUI

/// The story of a game: every House's holds, watch by watch.
struct StoryChart: View {
    let state: GameState
    let player: Int

    struct Point: Identifiable {
        let house: Int
        let watch: Int
        let holds: Int
        var id: String { "\(house)-\(watch)" }
    }

    /// The points to draw, the lake as it stands now ending each line.
    static func points(for state: GameState) -> [Point] {
        var history = state.history
        if history.last?.watch != state.watch {
            history.append(Snapshot(watch: state.watch, holds: state.houses.map { state.holds(of: $0.id).count }, strength: []))
        }
        var points: [Point] = []
        for house in state.houses {
            for snapshot in history where house.id < snapshot.holds.count {
                points.append(Point(house: house.id, watch: snapshot.watch, holds: snapshot.holds[house.id]))
                // A fallen House's line ends where it fell.
                if snapshot.holds[house.id] == 0, snapshot.watch > 1 { break }
            }
        }
        return points
    }

    var body: some View {
        let points = Self.points(for: state)
        Chart(points) { point in
            LineMark(x: .value("Watch", point.watch), y: .value("Holds", point.holds), series: .value("House", point.house))
                .foregroundStyle(Palette.house(state.houses[point.house]))
                .lineStyle(StrokeStyle(lineWidth: point.house == player ? 2.2 : 1.2))
                .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.text(0.08))
                AxisValueLabel().foregroundStyle(Palette.text(0.45)).font(.nm(9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Palette.text(0.08))
                AxisValueLabel().foregroundStyle(Palette.text(0.45)).font(.nm(9))
            }
        }
        .frame(height: 130)
        .accessibilityLabel(Self.summary(of: state, player: player))
    }

    /// The player's own tally of the game, in words.
    static func summary(of state: GameState, player: Int) -> String {
        let captures = state.chronicle.filter { $0.kind == .capture }
        let taken = captures.filter { $0.houses.first == player }.count
        let lost = captures.filter { $0.houses.dropFirst().first == player }.count
        let founded = state.chronicle.filter { $0.kind == .founding && $0.houses.first == player }.count
        let peak = state.history.map { $0.holds.indices.contains(player) ? $0.holds[player] : 0 }.max() ?? state.holds(of: player).count
        return "Over \(state.watch) watches you founded \(founded) hold\(founded == 1 ? "" : "s"), took \(taken) and lost \(lost); at your height you held \(peak)."
    }
}
