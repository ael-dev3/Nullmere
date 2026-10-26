import NullmereCore
import SwiftUI

/// One line about the ground under the pointer: what it is, what it
/// yields, whose land it is, and what it costs to cross.
enum HoverInfo {
    static func line(for hex: Hex, in state: GameState, explored: Bool, territory: [Int?]) -> String? {
        guard let index = state.map.index(of: hex) else { return nil }
        guard explored else { return "Unknown country · send a Lantern" }
        let tile = state.map[index]
        var parts = [tile.terrain.title]
        if let feature = tile.feature { parts.append(feature.title) }
        if let hold = state.hold(at: hex) {
            parts.append(hold.name)
        }
        if tile.terrain.isWater, tile.terrain != .shallows {
            parts.append("dead water, impassable")
            return parts.joined(separator: " · ")
        }
        if !tile.yield.isZero { parts.append(tile.yield.description) }
        if territory.indices.contains(index), let holdID = territory[index], let hold = state.hold(holdID) {
            parts.append("land of \(state.houses[hold.owner].title)")
        }
        if tile.terrain.isPassable {
            parts.append(tile.terrain.moveCost == 1 ? "1 move" : "\(tile.terrain.moveCost) moves")
        } else {
            parts.append("impassable")
        }
        if tile.terrain.defenseBonus != 0 {
            parts.append("\(tile.terrain.defenseBonus > 0 ? "+" : "")\(tile.terrain.defenseBonus)% defence")
        }
        return parts.joined(separator: " · ")
    }
}

struct HoverLine: View {
    let session: GameSession

    var body: some View {
        if session.hoverForecast == nil, let hex = session.hovered,
           let line = HoverInfo.line(for: hex, in: session.state, explored: session.isExplored(hex), territory: session.territory) {
            Text(verbatim: line)
                .font(.system(size: 11, weight: .light))
                .foregroundStyle(Palette.ink.opacity(0.85))
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.black.opacity(0.55), in: RoundedRectangle(cornerRadius: 3))
                .accessibilityHidden(true)
        }
    }
}
