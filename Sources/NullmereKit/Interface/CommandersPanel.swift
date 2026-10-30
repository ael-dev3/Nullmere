import NullmereCore
import SwiftUI

/// The House's commanders: each one's level and experience, its four
/// skills as they come with its levels, the company it leads, and the
/// buttons that set it at the head of the company chosen or call it back.
struct CommandersPanel: View {
    let session: GameSession

    var body: some View {
        let board = session.state.commandersBoard(for: session.player)
        let chosen = session.selectedUnit.flatMap { $0.owner == session.player && $0.kind.isMilitary ? $0 : nil }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Commanders", subtitle: "\(board.lines.count) of the \(board.limit) a House keeps")
                CloseButton(label: "Close the Commanders") { session.panel = nil }
            }
            Text(verbatim: chosen.map { "Chosen: \(CommandersPanel.named($0)). A commander set at its head leads it in every battle." }
                 ?? "Choose a company of war on the map to set a commander at its head.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if board.lines.isEmpty {
                        Text(verbatim: "No commander serves your House. One comes with each Muster Hall of III and V, and with Banner Lore.")
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    ForEach(board.lines) { line in
                        Rule(opacity: 0.18)
                        CommanderRow(session: session, line: line, chosen: chosen)
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.commanders))
        }
        .padding(16)
        .frame(width: 360)
        .frame(maxHeight: 620)
        .panelBackground()
    }

    /// A company as a commander's row names it: its kind and tier.
    static func named(_ unit: Unit) -> String {
        unit.kind.hasTiers ? "\(unit.kind.title) \(Narration.roman(unit.tier))" : unit.kind.title
    }

    /// Where a commander stands: at the head of a company, mending, or free.
    static func standing(of line: CommanderLine) -> String {
        if let wounded = line.woundedFor {
            return wounded == 1 ? "Wounded: whole again next watch" : "Wounded: whole again in \(wounded) watches"
        }
        if let unit = line.leads { return "Leads the \(named(unit))" }
        return "Free to lead a company of war"
    }
}

private struct CommanderRow: View {
    let session: GameSession
    let line: CommanderLine
    let chosen: Unit?

    var body: some View {
        let commander = line.commander
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Caps(commander.name, size: 10, weight: .medium).foregroundStyle(Palette.ink)
                Spacer()
                Text(verbatim: "\(commander.archetype.title) · level \(line.level)")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.65))
            }
            .accessibilityElement(children: .combine)
            if let span = line.span {
                HStack(spacing: 8) {
                    Meter(fraction: Double(line.progress) / Double(max(span, 1)))
                    Text(verbatim: "\(line.progress) / \(span)")
                        .font(.nm(9.5).monospacedDigit())
                        .foregroundStyle(Palette.text(0.5))
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel("Experience \(line.progress) of \(span) to level \(line.level + 1)")
                .accessibilityAddTraits(.isStaticText)
            }
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: CommandersPanel.standing(of: line))
                    .font(.nm(10.5))
                    .foregroundStyle(line.woundedFor != nil ? Palette.bad : Palette.text(0.7))
                Spacer()
                if line.leads != nil {
                    QuietButton(title: "Call back", size: 8.5, name: "Call \(commander.name) back") {
                        session.perform(.unassign(commander: commander.id))
                    }
                } else if let unit = chosen {
                    let refusal = session.state.assignRefusal(of: commander.id, to: unit.id, as: session.player)
                    QuietButton(title: "Lead them", size: 8.5, enabled: refusal == nil,
                                name: "Set \(commander.name) at the head of the \(CommandersPanel.named(unit))",
                                why: refusal?.description) {
                        session.perform(.assign(commander: commander.id, unit: unit.id))
                    }
                }
            }
            if line.furyReady {
                Text(verbatim: "\(commander.archetype.active.title) is ready: it fires in the next battle.")
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.glowWords)
            }
            VStack(alignment: .leading, spacing: 3) {
                ForEach(line.skills) { skill in
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Caps(skill.skill.title, size: 8.5, weight: skill.isKnown ? .medium : .regular)
                            .foregroundStyle(Palette.text(skill.isKnown ? 0.85 : 0.4))
                        Text(verbatim: skill.isKnown ? skill.skill.effect : "\(skill.skill.effect) · from level \(skill.skill.unlock)")
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(skill.isKnown ? 0.6 : 0.4))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                }
            }
        }
    }
}
