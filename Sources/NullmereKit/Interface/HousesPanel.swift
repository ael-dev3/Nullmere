import NullmereCore
import SwiftUI

/// The other Houses around the lake: how they stand with the player, how
/// strong they are, and what can be said to them.
struct HousesPanel: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Houses", subtitle: "\(state.livingHouses.count) still stand · your realm \(state.realm(of: session.player)) of \(state.holds.count) holds; \(GameState.supremacyShare)% and \(GameState.supremacyMinimum) win dominion")
                CloseButton { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    ForEach(state.houses.filter { $0.id != session.player }) { house in
                        HouseRow(session: session, house: house)
                        Rule(opacity: 0.18)
                    }
                }
            }
            .scrollIndicators(.never)
        }
        .padding(16)
        .frame(width: 360)
        .frame(maxHeight: 620)
        .panelBackground()
    }
}

private struct HouseRow: View {
    let session: GameSession
    let house: House

    var body: some View {
        let state = session.state
        let player = session.player
        let stance = state.stance(player, house.id)
        let relation = state.relation(player, house.id)
        let spire = state.seat(of: house.id)?.level(.moonspire) ?? 0
        VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.house(house))
                    .frame(width: 3, height: 12)
                Caps(house.title, size: 10.5, weight: .medium)
                    .foregroundStyle(house.isEliminated ? Palette.ink.opacity(0.35) : Palette.ink)
                Spacer()
                if house.isEliminated {
                    Caps("Fallen", size: 8.5).foregroundStyle(Palette.ink.opacity(0.4))
                } else {
                    Caps(stance.title, size: 8.5, weight: .medium)
                        .foregroundStyle(stance == .war ? Palette.bad : (stance == .pact ? Palette.good : Palette.ink.opacity(0.65)))
                }
            }
            if !house.isEliminated {
                Text(verbatim: summary(stance: stance, relation: relation, spire: spire))
                    .font(.system(size: 10.5))
                    .foregroundStyle(Palette.ink.opacity(0.55))
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 14) {
                    Figure(label: "Holds", value: state.holds(of: house.id).count)
                    Figure(label: "Strength", value: state.strength(of: house.id))
                    Figure(label: "Renown", value: state.renown(of: house.id))
                }
                HStack(spacing: 4) {
                    switch stance {
                    case .war:
                        QuietButton(title: "Offer peace", size: 8.5) { session.perform(.propose(.peace, to: house.id)) }
                    case .peace:
                        QuietButton(title: "Offer a pact", size: 8.5) { session.perform(.propose(.pact, to: house.id)) }
                        QuietButton(title: "Declare war", size: 8.5) { session.perform(.declareWar(on: house.id)) }
                    case .pact:
                        QuietButton(title: "Break the pact", size: 8.5) { session.perform(.declareWar(on: house.id)) }
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }

    private func summary(stance: Stance, relation: Relation?, spire: Int) -> String {
        var parts = ["\(house.temperament.title)."]
        let state = session.state
        if let liege = house.liege {
            parts.append(liege == session.player ? "Sworn to you." : "Sworn to \(state.houses[liege].title).")
        }
        let vassals = state.houses.filter { $0.liege == house.id && !$0.isEliminated }
        if !vassals.isEmpty {
            parts.append("Liege of \(vassals.map(\.title).joined(separator: ", ")).")
        }
        if let relation {
            let watches = max(session.state.watch - relation.since, 0)
            let span = watches == 0 ? "since this watch" : "for \(watches) watch\(watches == 1 ? "" : "es")"
            parts.append("\(stance.title) \(span).")
            if relation.betrayals > 0 {
                parts.append("Pacts broken between you: \(relation.betrayals).")
            }
        }
        if spire > 0 {
            parts.append("Its Moonspire stands at stage \(spire) of \(BuildingKind.moonspire.maxLevel).")
        }
        return parts.joined(separator: " ")
    }
}

private struct Figure: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Caps(label, size: 7.5).foregroundStyle(Palette.ink.opacity(0.45))
            Text(verbatim: "\(value)").font(.system(size: 10.5).monospacedDigit()).foregroundStyle(Palette.ink.opacity(0.8))
        }
        .accessibilityElement(children: .combine)
    }
}

struct CloseButton: View {
    let action: () -> Void

    @State private var hovering = false

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.system(size: 9, weight: .light))
                .foregroundStyle(Palette.ink.opacity(hovering ? 0.95 : 0.5))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .onHover { hovering = $0 }
        .accessibilityLabel("Close")
    }
}

/// Envoys waiting on the player's answer, one card each.
struct EnvoyCards: View {
    let session: GameSession

    var body: some View {
        let state = session.state
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(state.envoys) { envoy in
                let house = state.houses[envoy.from]
                let left = max(Envoy.patience - (state.watch - envoy.arrived), 1)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1).fill(Palette.house(house)).frame(width: 3, height: 12)
                        Caps("An envoy of \(house.title)", size: 9, weight: .medium).foregroundStyle(Palette.ink)
                    }
                    if let spoken = session.spoken[.envoy(envoy.id)] {
                        Text(verbatim: "“\(spoken)”")
                            .font(.system(size: 12, weight: .light).italic())
                            .foregroundStyle(Palette.ink.opacity(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                    Text(verbatim: words(for: envoy.proposal, from: house))
                        .font(.system(size: 10.5))
                        .foregroundStyle(Palette.ink.opacity(session.spoken[.envoy(envoy.id)] == nil ? 0.7 : 0.5))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text(verbatim: left == 1 ? "Leaves after this watch" : "Waits \(left) watches")
                            .font(.system(size: 10))
                            .foregroundStyle(Palette.ink.opacity(0.4))
                        Spacer()
                        QuietButton(title: "Refuse", size: 8.5) { session.perform(.answer(envoy: envoy.id, accept: false)) }
                        QuietButton(title: "Accept", size: 8.5, prominent: true) { session.perform(.answer(envoy: envoy.id, accept: true)) }
                    }
                }
                .padding(14)
                .frame(width: 320)
                .panelBackground()
                .transition(.move(edge: .trailing).combined(with: .opacity))
                .accessibilityElement(children: .contain)
            }
        }
    }

    private func words(for proposal: Proposal, from house: House) -> String {
        switch proposal {
        case .peace:
            return "\(house.title) asks for peace. Their armies would turn from yours, and yours from theirs."
        case .pact:
            return "\(house.title) offers a pact: shared sight across the water, and no blade between you."
        case .fealty:
            return "\(house.title) is beaten and bends the knee: it would be your vassal, its holds counted in your realm, never to raise a blade against you."
        }
    }
}
