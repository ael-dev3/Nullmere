import NullmereCore
import SwiftUI

/// The realm's course as the House stands in it: the happening under way
/// and the foremost in it, or the next to come; the charge set it; its
/// deeds; its might among the Houses; and the keeper's renown over ages.
struct RealmPanel: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        let board = state.realmBoard(for: session.player)
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "The Realm", subtitle: RealmPanel.mightLine(board, standing: state.livingHouses.count))
                CloseButton(label: "Close the Realm") { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    happening(board)
                    Rule(opacity: 0.18)
                    charge(board)
                    Rule(opacity: 0.18)
                    deeds(board)
                    if !state.holySites.isEmpty {
                        Rule(opacity: 0.18)
                        shrines(state)
                    }
                    if let keeper = session.keeper, (keeper.renown ?? 0) > 0 || !(keeper.titles ?? []).isEmpty {
                        Rule(opacity: 0.18)
                        Caps("Your renown", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
                        Text(verbatim: "\(keeper.renown ?? 0) renown won over the ages")
                            .font(.nm(11))
                            .foregroundStyle(Palette.text(0.8))
                        ForEach(keeper.titles ?? [], id: \.self) { title in
                            Text(verbatim: title).font(.nm(10.5)).foregroundStyle(Palette.glowWords)
                        }
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.realm))
        }
        .padding(16)
        .frame(width: 360)
        .frame(maxHeight: 620)
        .panelBackground()
    }

    /// The holy sites the House has found, who holds each, and what it gives.
    @ViewBuilder
    private func shrines(_ state: GameState) -> some View {
        Caps("Holy sites", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        ForEach(state.holySites) { shrine in
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: shrine.title).font(.nm(11, weight: .medium)).foregroundStyle(Palette.text(0.85))
                    Spacer()
                    Text(verbatim: RealmPanel.held(shrine, in: state, player: session.player))
                        .font(.nm(10.5))
                        .foregroundStyle(shrine.holder.map { state.areAllied($0, session.player) || $0 == session.player } == true
                                         ? Palette.glowWords : Palette.text(0.6))
                }
                Text(verbatim: "\(shrine.kind.effect); \(state.placeName(of: shrine.position))")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        Text(verbatim: "A company of war standing on a holy site as the watch turns, with no foe beside it, takes it for its House and alliance.")
            .font(.nm(10))
            .foregroundStyle(Palette.text(0.55))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// Who holds a holy site, as the panel says it.
    static func held(_ shrine: Shrine, in state: GameState, player: Int) -> String {
        guard let holder = shrine.holder, state.houses.indices.contains(holder) else { return "Held by none" }
        if holder == player { return "Yours" }
        return "Held by \(state.houses[holder].title)"
    }

    static func mightLine(_ board: RealmBoard, standing: Int) -> String {
        guard let place = board.mightPlace else { return "Might \(board.might)" }
        return "Might \(board.might) · \(SeatBriefing.ordinal(place)) of \(standing) Houses"
    }

    private func title(_ house: Int) -> String {
        guard session.state.houses.indices.contains(house) else { return "a fallen House" }
        return house == session.player ? "You" : session.state.houses[house].title
    }

    @ViewBuilder
    private func happening(_ board: RealmBoard) -> some View {
        if let happening = board.happening {
            let left = max(happening.ends - session.state.watch, 0)
            Caps(happening.kind.title, size: 10, weight: .medium).foregroundStyle(Palette.glowWords).accessibilityAddTraits(.isHeader)
            Text(verbatim: "Until the \(SeatBriefing.ordinal(happening.ends)) watch, \(left) to go: \(happening.kind.goal).")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.65))
                .fixedSize(horizontal: false, vertical: true)
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Caps("Your points", size: 8.5).foregroundStyle(Palette.text(0.5))
                    Spacer()
                    Text(verbatim: board.nextMark.map { "\(board.points) of \($0) for the next mark" } ?? "\(board.points), every mark passed")
                        .font(.nm(10.5).monospacedDigit())
                        .foregroundStyle(Palette.text(0.75))
                }
                Meter(fraction: board.nextMark.map { Double(board.points) / Double(max($0, 1)) } ?? 1)
            }
            .accessibilityElement(children: .combine)
            if !board.foremost.isEmpty {
                VStack(alignment: .leading, spacing: 3) {
                    ForEach(Array(board.foremost.enumerated()), id: \.element.house) { index, placing in
                        HStack {
                            Text(verbatim: "\(index + 1). \(title(placing.house))")
                                .font(.nm(10.5, weight: placing.house == session.player ? .medium : .regular))
                                .foregroundStyle(Palette.text(placing.house == session.player ? 0.95 : 0.7))
                            Spacer()
                            Text(verbatim: "\(placing.points)").font(.nm(10.5).monospacedDigit()).foregroundStyle(Palette.text(0.6))
                        }
                        .accessibilityElement(children: .combine)
                    }
                }
            }
        } else if let next = board.nextBegins {
            Caps("Happenings", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
            Text(verbatim: "\(board.nextKind?.title ?? "The next happening") begins at the \(SeatBriefing.ordinal(next)) watch"
                 + (board.nextKind.map { ": \($0.goal)." } ?? "."))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    @ViewBuilder
    private func charge(_ board: RealmBoard) -> some View {
        Caps("Charges kept: \(board.chargesKept) of \(Charge.allCases.count)", size: 9, weight: .medium)
            .foregroundStyle(Palette.text(0.7))
            .accessibilityAddTraits(.isHeader)
        if let charge = board.charge {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: charge.title).font(.nm(11, weight: .medium)).foregroundStyle(Palette.ink)
                Text(verbatim: ChargeGuide.how(charge)).font(.nm(10.5)).foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
                HStack {
                    Caps("Reward", size: 8.5).foregroundStyle(Palette.text(0.5))
                    CostLine(cost: charge.reward, available: Stock(grain: .max, timber: .max, stone: .max, moonsalt: .max))
                }
            }
            .accessibilityElement(children: .combine)
        } else {
            Text(verbatim: "Every charge kept.").font(.nm(10.5)).foregroundStyle(Palette.text(0.6))
        }
    }

    @ViewBuilder
    private func deeds(_ board: RealmBoard) -> some View {
        Caps("Deeds: \(board.deeds.count) of \(Deed.allCases.count)", size: 9, weight: .medium)
            .foregroundStyle(Palette.text(0.7))
            .accessibilityAddTraits(.isHeader)
        ForEach(board.deeds + board.deedsLeft, id: \.self) { deed in
            let done = board.deeds.contains(deed)
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Caps(deed.title, size: 8.5, weight: done ? .medium : .regular)
                    .foregroundStyle(done ? Palette.good : Palette.text(0.4))
                Text(verbatim: done ? "Done: \(deed.deed)" : "To do: \(deed.deed)")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(done ? 0.65 : 0.4))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }
}
