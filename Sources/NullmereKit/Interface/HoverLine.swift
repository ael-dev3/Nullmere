import NullmereCore
import SwiftUI

/// One line about the ground under the pointer: what it is, what it
/// yields, whose land it is, and what it costs to cross.
enum HoverInfo {
    static func line(for hex: Hex, in state: GameState, explored: Bool, territory: [Int?]) -> String? {
        guard let index = state.map.index(of: hex) else { return nil }
        guard explored else { return "Unknown country · send Lanterns" }
        let tile = state.map[index]
        var parts = [tile.terrain.title]
        if let feature = tile.feature { parts.append(feature.title) }
        if let hold = state.hold(at: hex) {
            parts.append(hold.name)
        }
        if let wild = state.wild(at: hex) {
            parts.append(HoverInfo.named(wild) + ", of the wilds")
        }
        if let site = state.site(at: hex) {
            parts.append(HoverInfo.named(site))
        }
        if let shrine = state.shrine(at: hex) {
            parts.append(HoverInfo.named(shrine, in: state))
        }
        if let lair = state.lair(at: hex) {
            parts.append(HoverInfo.named(lair))
        }
        if let standard = state.standard(at: hex) {
            parts.append(HoverInfo.named(standard, in: state))
        } else if let land = state.allianceLand(at: hex).flatMap({ state.alliance($0) }) {
            parts.append("land of \(land.name)")
        }
        if tile.terrain.isWater, tile.terrain != .shallows {
            parts.append("yields nothing, impassable")
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

    /// A company of the wilds as the map names it: "Barrowkin, level III".
    static func named(_ wild: Wild) -> String {
        let title = wild.kind.title
        return title.prefix(1).uppercased() + title.dropFirst() + ", level \(Narration.roman(wild.level))"
    }

    /// A holy site as the map names it: who holds it, and what it gives.
    static func named(_ shrine: Shrine, in state: GameState) -> String {
        let holder = shrine.holder.flatMap { state.houses.indices.contains($0) ? state.houses[$0].title : nil }
        return "the \(shrine.title), a holy site" + (holder.map { ", held by \($0)" } ?? ", held by none") + ": \(shrine.kind.effect)"
    }

    /// A lair of the wilds as the map names it: its level, what still
    /// stands of it, and what alone breaks it.
    static func named(_ lair: Lair) -> String {
        "the \(lair.title), a lair of the wilds of level \(Narration.roman(lair.level)), \(lair.strength) of \(lair.might) standing; "
            + "only a rally's host breaks it"
    }

    /// An alliance's standard as the map names it, with its ward.
    static func named(_ standard: Standard, in state: GameState) -> String {
        let name = state.alliance(standard.alliance)?.name ?? "a fallen alliance"
        return "a standard of \(name), ward \(standard.ward) of \(Standard.maximumWard): the land about it is the alliance's"
    }

    /// A site of the land as the map names it, with what is left in it.
    static func named(_ site: Site) -> String {
        "\(site.title) \(Narration.roman(site.level)), \(site.remaining) \(site.store.title.lowercased()) left"
    }
}

struct HoverLine: View {
    let session: GameSession

    var body: some View {
        if session.hoverForecast == nil, let hex = session.hovered,
           let line = HoverInfo.line(for: hex, in: session.state, explored: session.isExplored(hex), territory: session.territory) {
            Text(verbatim: line)
                .font(.nm(11, weight: .light))
                .foregroundStyle(Palette.text(0.85))
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                // As dark as a panel, so it reads over the palest ground.
                .background(Palette.panel, in: RoundedRectangle(cornerRadius: 3))
                .accessibilityHidden(true)
        }
    }
}
