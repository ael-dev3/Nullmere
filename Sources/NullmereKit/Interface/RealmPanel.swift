import NullmereCore
import SwiftUI

/// The realm's course as the House stands in it: the happening under way
/// and the foremost in it, or the next to come; the charge set it; what
/// its satchel holds; the people it comes of; its deeds; its might among
/// the Houses; and the keeper's favour with the lake and renown over ages.
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
            Text(verbatim: RealmPanel.armyLine(state, player: session.player))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
            Text(verbatim: RealmPanel.sunderingLine(state, player: session.player))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    happening(board)
                    Rule(opacity: 0.18)
                    charge(board)
                    Rule(opacity: 0.18)
                    satchel(state)
                    Rule(opacity: 0.18)
                    heritage(state)
                    Rule(opacity: 0.18)
                    deeds(board)
                    if !state.holySites.isEmpty {
                        Rule(opacity: 0.18)
                        shrines(state)
                    }
                    if !state.lairsStanding.isEmpty {
                        Rule(opacity: 0.18)
                        lairs(state)
                    }
                    if let keeper = session.keeper {
                        Rule(opacity: 0.18)
                        favour(keeper)
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

    /// The lairs of the wilds the House has found: each one's level, what
    /// stands of it, and where.
    @ViewBuilder
    private func lairs(_ state: GameState) -> some View {
        Caps("Lairs of the wilds", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        ForEach(state.lairsStanding) { lair in
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: "The \(lair.title) \(Narration.roman(lair.level))").font(.nm(11, weight: .medium)).foregroundStyle(Palette.text(0.85))
                    Spacer()
                    Text(verbatim: RealmPanel.standing(lair)).font(.nm(10.5)).foregroundStyle(Palette.text(0.6))
                }
                Text(verbatim: "Breaks for \(lair.spoils); \(state.placeName(of: lair.position))")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
        Text(verbatim: "Only a rally's host breaks a lair: select its ground and call one against it.")
            .font(.nm(10))
            .foregroundStyle(Palette.text(0.55))
            .fixedSize(horizontal: false, vertical: true)
    }

    /// What the House keeps in its satchel, and what each does: what is
    /// used on the House is used from here, what is used on a hold from
    /// that hold's panel.
    @ViewBuilder
    private func satchel(_ state: GameState) -> some View {
        let stacks = state.satchel(of: session.player)
        Caps("Satchel", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        if stacks.isEmpty {
            Text(verbatim: "Empty. Charges kept, a happening's marks and lairs broken fill it.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(stacks, id: \.kind) { stack in
            SatchelRow(session: session, stack: stack)
        }
    }

    /// The people the House comes of and what that gives it, and the others
    /// it may take up instead.
    @ViewBuilder
    private func heritage(_ state: GameState) -> some View {
        let mine = state.heritage(of: session.player)
        Caps("Heritage", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        VStack(alignment: .leading, spacing: 3) {
            Text(verbatim: mine.name).font(.nm(11, weight: .medium)).foregroundStyle(Palette.glowWords)
            Text(verbatim: "\(mine.origin). " + RealmPanel.heritageLine(mine))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
        Text(verbatim: RealmPanel.heritageChange(state, player: session.player))
            .font(.nm(10))
            .foregroundStyle(Palette.text(0.55))
            .fixedSize(horizontal: false, vertical: true)
        ForEach(Heritage.allCases.filter { $0 != mine }, id: \.self) { other in
            HeritageRow(session: session, heritage: other)
        }
    }

    /// What a heritage gives, and its own company.
    static func heritageLine(_ heritage: Heritage) -> String {
        let first = heritage.strengths[0].prefix(1).uppercased() + heritage.strengths[0].dropFirst()
        return "\(first); \(heritage.strengths[1]). Its own company: the \(heritage.signatureTitle), "
            + "\(heritage.signature.title) of the fifth tier."
    }

    /// What taking up another heritage asks of the House.
    static func heritageChange(_ state: GameState, player: Int) -> String {
        state.houses[player].heritage == nil ? "Take up another instead, the first time freely:"
            : "Take up another instead, for \(Heritage.changeCost):"
    }

    /// The order that uses an item on the House itself; none for one used
    /// only on a hold.
    static func use(_ kind: ItemKind) -> Command? {
        kind.needsHold ? nil : .useItem(kind, hold: nil)
    }

    /// What an item does, and where it is used.
    static func about(_ kind: ItemKind) -> String {
        let effect = kind.effect.prefix(1).uppercased() + kind.effect.dropFirst()
        switch kind {
        case .hourglass: return "\(effect). Use it from a hold's panel, or here on your study."
        case .wardStone: return "\(effect). Use it from the hold's panel."
        default: return "\(effect)."
        }
    }

    /// The title of an item's use here.
    static func useTitle(_ kind: ItemKind) -> String {
        switch kind {
        case .hourglass: return "Hasten your study"
        case .mendingDraught: return "Share it out"
        default: return "Open"
        }
    }

    /// What stands of a lair, as the panel says it.
    static func standing(_ lair: Lair) -> String {
        lair.strength == lair.might ? "Whole, \(lair.might)" : "\(lair.strength) of \(lair.might) standing"
    }

    /// Who holds a holy site, as the panel says it.
    static func held(_ shrine: Shrine, in state: GameState, player: Int) -> String {
        guard let holder = shrine.holder, state.houses.indices.contains(holder) else { return "Held by none" }
        if holder == player { return "Yours" }
        return "Held by \(state.houses[holder].title)"
    }

    /// The keeper's favour: its level, what they have won, and what the
    /// next level asks.
    static func favourLine(_ keeper: Keeper) -> String {
        let favour = keeper.favour ?? 0
        let level = Favour.level(of: favour)
        let standing = level > 0 ? "Favour \(BuildingKind.numeral(level))" : "No favour yet"
        let next = Favour.next(after: favour).map { "; \($0 - favour) more to \(BuildingKind.numeral(level + 1))" } ?? ", the highest there is"
        return "\(standing): \(favour) won\(next)."
    }

    /// How far the keeper's favour has come toward its next level, 0 to 1.
    static func favourProgress(_ favour: Int) -> Double {
        guard let next = Favour.next(after: favour) else { return 1 }
        let level = Favour.level(of: favour)
        let from = level > 0 ? Favour.levels[level - 1] : 0
        return Double(favour - from) / Double(next - from)
    }

    /// The watches the keeper has kept unbroken: what the next brings, and
    /// when the next favour chest comes.
    static func streakLine(_ keeper: Keeper) -> String {
        let streak = keeper.streak ?? 0
        let chest = Favour.chestEvery - streak % Favour.chestEvery
        return "\(streak) watch\(streak == 1 ? "" : "es") kept unbroken: the next brings \(Favour.earned(streak: streak)) favour, "
            + "and a favour chest comes in \(chest) watch\(chest == 1 ? "" : "es")."
    }

    /// The Sundering: under way, how the shores stand and where the House
    /// stands; settled, how the last ended; or when the next comes.
    static func sunderingLine(_ state: GameState, player: Int) -> String {
        guard let sundering = state.sundering else {
            return "The Sundering comes at the \(SeatBriefing.ordinal(Sundering.next(from: state.watch))) watch: the shores war as kingdoms."
        }
        let east = sundering.score(of: .eastern), west = sundering.score(of: .western)
        guard !sundering.settled else {
            let next = "the next at the \(SeatBriefing.ordinal(Sundering.next(from: state.watch + 1))) watch"
            guard let winner = sundering.leading else { return "The last Sundering ended with neither shore ahead; \(next)." }
            return "The last Sundering: \(winner.title) prevailed, \(max(east, west)) to \(min(east, west)); \(next)."
        }
        let stands = "the Eastern Shore \(east), the Western \(west), until the \(SeatBriefing.ordinal(sundering.ends)) watch"
        guard let shore = sundering.shore(of: player) else { return "The Sundering: \(stands)." }
        return "The Sundering: you stand with \(shore.title), your House \(sundering.points[player]) points; \(stands)."
    }

    /// The House's army: its troops, and the companies of war they stand in.
    static func armyLine(_ state: GameState, player: Int) -> String {
        let companies = state.units(of: player).filter(\.kind.isMilitary).count
        return "Your army: \(GameState.counted(state.army(of: player))) troops in \(companies) compan\(companies == 1 ? "y" : "ies") of war."
    }

    static func mightLine(_ board: RealmBoard, standing: Int) -> String {
        guard let place = board.mightPlace else { return "Might \(board.might)" }
        return "Might \(board.might) · \(SeatBriefing.ordinal(place)) of \(standing) Houses"
    }

    /// The keeper's favour with the lake, won by keeping the watches.
    @ViewBuilder
    private func favour(_ keeper: Keeper) -> some View {
        let level = Favour.level(of: keeper.favour ?? 0)
        Caps("Your favour", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: RealmPanel.favourLine(keeper))
                .font(.nm(11, weight: .medium))
                .foregroundStyle(Palette.ink)
            Meter(fraction: RealmPanel.favourProgress(keeper.favour ?? 0), label: "Toward the next")
            Text(verbatim: "It gives your House \(Favour.effect(level: level)).")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: RealmPanel.streakLine(keeper))
                .font(.nm(10))
                .foregroundStyle(Palette.text(0.5))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .combine)
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

/// One kind of item in the House's satchel: how many, what it does, and
/// its use from here when it is used on the House.
private struct SatchelRow: View {
    let session: GameSession
    let stack: ItemStack

    var body: some View {
        let kind = stack.kind
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: "\(kind.title) × \(stack.count)").font(.nm(11, weight: .medium)).foregroundStyle(Palette.text(0.85))
                Text(verbatim: RealmPanel.about(kind))
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if let command = RealmPanel.use(kind) {
                let refusal = session.state.refusal(of: command, as: session.player)
                QuietButton(title: RealmPanel.useTitle(kind), size: 8.5, enabled: refusal == nil,
                            name: kind == .hourglass ? "Use a Salt Hourglass on your study" : "Use a \(kind.title)", why: refusal?.description) {
                    session.perform(command)
                }
            }
        }
    }
}

/// A heritage the House may take up instead of its own: what it gives,
/// and the order that takes it up, asked twice.
private struct HeritageRow: View {
    let session: GameSession
    let heritage: Heritage

    var body: some View {
        let command = Command.takeHeritage(heritage)
        let refusal = session.state.refusal(of: command, as: session.player)
        let title = "Take up \(heritage.title)"
        VStack(alignment: .leading, spacing: 3) {
            VStack(alignment: .leading, spacing: 2) {
                Text(verbatim: heritage.name).font(.nm(10.5, weight: .medium)).foregroundStyle(Palette.text(0.8))
                Text(verbatim: RealmPanel.heritageLine(heritage))
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            HStack {
                Spacer()
                if let refusal {
                    QuietButton(title: title, size: 8.5, enabled: false, why: refusal.description) {}
                } else {
                    ConfirmButton(title: title, confirm: "\(title)?") { session.perform(command) }
                }
            }
        }
    }
}
