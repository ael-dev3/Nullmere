import Accessibility
import Charts
import LauncherKit
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
    nonisolated static func points(for state: GameState) -> [Point] {
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

    /// With "Differentiate without colour" on, each House's line is drawn
    /// in a pattern of its own as well as its colour: the keeper's solid.
    static func dash(for house: Int, player: Int, differentiates: Bool) -> [CGFloat] {
        guard differentiates, house != player else { return [] }
        let patterns: [[CGFloat]] = [[5, 2], [1, 2], [7, 2, 1, 2], [3, 3], [1, 4], [9, 3], [4, 1, 1, 1], [2, 5], [6, 2, 2, 2], [12, 3], [1, 1]]
        return patterns[house % patterns.count]
    }

    var body: some View {
        let points = Self.points(for: state)
        let differentiates = Contrast.shared.differentiates
        Chart(points) { point in
            LineMark(x: .value("Watch", point.watch), y: .value("Holds", point.holds), series: .value("House", point.house))
                .foregroundStyle(Palette.house(state.houses[point.house]))
                .lineStyle(StrokeStyle(lineWidth: point.house == player ? 2.2 : 1.2,
                                       dash: Self.dash(for: point.house, player: player, differentiates: differentiates)))
                .interpolationMethod(.monotone)
        }
        .chartXAxis {
            AxisMarks(values: .automatic(desiredCount: 4)) { _ in
                AxisGridLine().foregroundStyle(Palette.line(0.08))
                AxisValueLabel().foregroundStyle(Palette.text(0.45)).font(.nm(9))
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { _ in
                AxisGridLine().foregroundStyle(Palette.line(0.08))
                AxisValueLabel().foregroundStyle(Palette.text(0.45)).font(.nm(9))
            }
        }
        .frame(height: 130)
        .accessibilityLabel(Self.summary(of: state, player: player))
        // VoiceOver's audio graph: every House's line, not the keeper's alone.
        .accessibilityChartDescriptor(self)
    }

    /// How the age left the Houses, most holds first, in words that need
    /// no colour: the foremost five, and the keeper's own wherever it stands.
    nonisolated static func standing(of state: GameState, player: Int) -> String {
        let ranked = state.houses.map { ($0, state.holds(of: $0.id).count) }
            .sorted { ($1.1, $0.0.id) < ($0.1, $1.0.id) }
        let shown = ranked.prefix(5).contains { $0.0.id == player }
            ? Array(ranked.prefix(5)) : Array(ranked.prefix(4)) + ranked.filter { $0.0.id == player }
        let parts = shown.map { entry in
            "\(entry.0.title)\(entry.0.id == player ? " (you)" : ""), \(entry.1) hold\(entry.1 == 1 ? "" : "s")"
        }
        return "At the last: " + parts.joined(separator: "; ") + "."
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

extension StoryChart: AXChartDescriptorRepresentable {
    /// The chart as VoiceOver plays it: each House a series of its holds,
    /// watch by watch.
    nonisolated func makeChartDescriptor() -> AXChartDescriptor {
        let points = Self.points(for: state)
        let first = Double(points.map(\.watch).min() ?? 1)
        let last = max(Double(points.map(\.watch).max() ?? 1), first + 1)
        let most = max(Double(points.map(\.holds).max() ?? 1), 1)
        let watches = AXNumericDataAxisDescriptor(title: "Watch", range: first...last, gridlinePositions: []) { "watch \(Int($0))" }
        let holds = AXNumericDataAxisDescriptor(title: "Holds", range: 0...most, gridlinePositions: []) { "\(Int($0)) holds" }
        let series = state.houses.map { house in
            AXDataSeriesDescriptor(name: house.id == player ? "You, \(house.title)" : house.title, isContinuous: true,
                                   dataPoints: points.filter { $0.house == house.id }.map { AXDataPoint(x: Double($0.watch), y: Double($0.holds)) })
        }
        return AXChartDescriptor(title: "Holds around the lake, watch by watch", summary: Self.standing(of: state, player: player),
                                 xAxis: watches, yAxis: holds, additionalAxes: [], series: series)
    }
}
