import NullmereCore
import SwiftUI

/// One line about the ground under the pointer: what it is, what it
/// yields, whose land it is, and what it costs to cross.
enum HoverInfo {
    static func line(for hex: Hex, in state: GameState, explored: Bool, territory: [Int?], regions: [Int?] = []) -> String? {
        guard let index = state.map.index(of: hex) else { return nil }
        guard explored else { return "Unknown country · send Lanterns" }
        let tile = state.map[index]
        var parts = [tile.terrain.title]
        if let feature = tile.feature { parts.append(feature.title) }
        // The stream it is, or the region of the shores it lies in.
        if let river = state.atlas?.river(at: hex) {
            parts.append(river.name)
        } else if regions.indices.contains(index), let region = regions[index], let atlas = state.atlas, atlas.regions.indices.contains(region) {
            parts.append(atlas.regions[region].name)
        }
        // A bottle afloat here, or washed up and waiting to be found.
        if let bottle = state.bottlesOnTheLake.first(where: { $0.position == hex && $0.foundBy == nil }) {
            parts.append(bottle.ashore ? "a bottle washed up" : "a bottle afloat")
        }
        // A hold of an age before: drowned here, or, searched, remembered.
        if let drowned = state.drowned(at: hex) {
            parts.append(tile.feature == .drownedRuin ? "the drowned hold of \(drowned.title)" : "where \(drowned.title) stood")
        }
        if let hold = state.hold(at: hex) {
            parts.append(hold.name)
        }
        if let wild = state.wild(at: hex) {
            parts.append(HoverInfo.named(wild) + ", of the wilds")
        }
        if let site = state.site(at: hex) {
            parts.append(HoverInfo.named(site, in: state))
        }
        if let shrine = state.shrine(at: hex) {
            parts.append(HoverInfo.named(shrine, in: state))
        }
        if let lair = state.lair(at: hex) {
            parts.append(HoverInfo.named(lair))
        }
        if let field = state.fieldsOfBattle.first(where: { $0.at == hex }) {
            parts.append(HoverInfo.named(field, in: state))
        }
        if let hall = state.hall(at: hex) {
            parts.append(HoverInfo.named(hall, in: state))
        } else if let storehouse = state.storehouse(at: hex) {
            parts.append(HoverInfo.named(storehouse, in: state))
        } else if let standard = state.standard(at: hex) {
            parts.append(HoverInfo.named(standard, in: state))
        } else if let land = state.allianceLand(at: hex).flatMap({ state.alliance($0) }) {
            parts.append("land of \(land.name)")
        }
        if case .ford = tile.terrain {
            let left = GameState.fordWatchesLeft(at: state.watch)
            parts.append("the moon's road, 1 move, under water again " + (left <= 1 ? "as the watch turns" : "in \(left) watches"))
            return parts.joined(separator: " · ")
        }
        if case .stream = tile.terrain {
            parts.append("yields nothing, crossed only at its shoals")
            return parts.joined(separator: " · ")
        }
        if tile.terrain.isWater, tile.terrain != .shallows, tile.terrain != .shoal {
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

    /// A field of battle as the map names it: each side by the House that
    /// leads it, and the troops it has standing there.
    static func named(_ field: Field, in state: GameState) -> String {
        let leaders = field.sides.map { state.houses.indices.contains($0[0]) ? state.houses[$0[0]].title : "a fallen House" }
        return "a battle, \(leaders[0])'s side \(GameState.counted(field.inField(0).troops)) troops against "
            + "\(leaders[1])'s \(GameState.counted(field.inField(1).troops))"
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

    /// An alliance's hall as the map names it: rising, how far, or whole,
    /// with its ward.
    static func named(_ hall: AllianceHall, in state: GameState) -> String {
        let name = state.alliance(hall.alliance)?.name ?? "a fallen alliance"
        guard hall.isWhole else {
            return "the hall of \(name), rising, \(hall.built) of \(AllianceHall.raising) watches done, ward \(hall.ward) of \(hall.wardLimit)"
        }
        return "the hall of \(name), ward \(hall.ward) of \(AllianceHall.maximumWard): the land \(AllianceHall.reach) tiles about it is the alliance's"
    }

    /// An alliance's hall in words: who began it, how far it has risen,
    /// its ward, and what it gives its alliance.
    static func described(_ hall: AllianceHall, in state: GameState) -> String {
        let raiser = state.houses.indices.contains(hall.raisedBy) ? state.houses[hall.raisedBy].title : "a fallen House"
        let gives = "the land \(AllianceHall.reach) tiles about it is the alliance's, its companies keeping it stand a quarter firmer, "
            + "its Houses' rallies take \(AllianceHall.rallyCompanies) more companies and it may keep \(AllianceHall.standards) more standards. "
            + "Only its companies enter it; a House at war with one of its Houses may strike it when none keeps it."
        guard hall.isWhole else {
            return "Begun by \(raiser); rising, \(hall.built) of \(AllianceHall.raising) watches done, its ward \(hall.ward) of \(hall.wardLimit). "
                + "Whole, " + gives
        }
        return "Raised by \(raiser); its ward \(hall.ward) of \(AllianceHall.maximumWard), mending \(AllianceHall.mending) a watch. "
            + gives.prefix(1).uppercased() + gives.dropFirst()
    }

    /// A site of the land as the map names it, with what is left in it;
    /// an alliance's yard, with whose it is.
    static func named(_ site: Site, in state: GameState? = nil) -> String {
        guard let yard = site.alliance else {
            return "\(site.title) \(Narration.roman(site.level)), \(site.remaining) \(site.store.title.lowercased()) left"
        }
        let name = state?.alliance(yard)?.name ?? "an alliance"
        return "\(site.title) of \(name), \(site.remaining) \(site.store.title.lowercased()) left"
    }

    /// An alliance's storehouse as the map names it: rising, how far, or
    /// whole, with its ward.
    static func named(_ storehouse: Storehouse, in state: GameState) -> String {
        let name = state.alliance(storehouse.alliance)?.name ?? "a fallen alliance"
        guard storehouse.isWhole else {
            return "the storehouse of \(name), rising, \(storehouse.built) of \(Storehouse.raising) watches done, "
                + "ward \(storehouse.ward) of \(Storehouse.maximumWard)"
        }
        return "the storehouse of \(name), ward \(storehouse.ward) of \(Storehouse.maximumWard): its Houses lay up their stores there"
    }

    /// An alliance's storehouse in words: who raised it, how far it has
    /// risen, its ward, and what it keeps for its Houses.
    static func described(_ storehouse: Storehouse, in state: GameState) -> String {
        let raiser = state.houses.indices.contains(storehouse.raisedBy) ? state.houses[storehouse.raisedBy].title : "a fallen House"
        let keeps = "each of its Houses may lay up to \(Storehouse.room) there, beyond its own storage and out of any taker's reach. "
            + "Only its companies enter it; a House at war with one of its Houses may strike it when none keeps it, and carry off "
            + "what was laid up in it."
        guard storehouse.isWhole else {
            return "Begun by \(raiser); rising, \(storehouse.built) of \(Storehouse.raising) watches done, its ward \(storehouse.ward) of "
                + "\(Storehouse.maximumWard). Whole, " + keeps
        }
        return "Raised by \(raiser); its ward \(storehouse.ward) of \(Storehouse.maximumWard), mending \(Storehouse.mending) a watch. "
            + keeps.prefix(1).uppercased() + keeps.dropFirst()
    }
}

struct HoverLine: View {
    let session: GameSession

    var body: some View {
        if session.hoverForecast == nil, let hex = session.hovered,
           let line = HoverInfo.line(for: hex, in: session.state, explored: session.isExplored(hex), territory: session.territory,
                                     regions: session.regions()) {
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
