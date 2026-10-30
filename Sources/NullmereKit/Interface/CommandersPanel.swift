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
                    .beckoned(session.beckon == .lead && refusal == nil)
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
            TalentsView(session: session, commander: commander)
        }
    }
}

/// A commander's talents: its three trees, each talent's rank and what a
/// rank does, a button to learn the next, and one to forget them all and
/// learn anew. Shown of itself while points wait to be spent.
struct TalentsView: View {
    let session: GameSession
    let commander: Commander
    /// Shown or hidden by the keeper; nil, it follows the points waiting.
    @State private var shown: Bool?

    var body: some View {
        let open = shown ?? (commander.pointsLeft > 0)
        VStack(alignment: .leading, spacing: 6) {
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: TalentsView.summary(of: commander))
                    .font(.nm(10.5))
                    .foregroundStyle(commander.pointsLeft > 0 ? Palette.glowWords : Palette.text(0.6))
                Spacer()
                QuietButton(title: open ? "Hide talents" : "Talents", size: 8.5,
                            name: open ? "Hide \(commander.name)'s talents" : "Show \(commander.name)'s talents") {
                    shown = !open
                }
            }
            if open {
                ForEach(commander.talentTrees) { tree in
                    VStack(alignment: .leading, spacing: 3) {
                        Caps("\(tree.tree.title) · \(tree.spent) spent", size: 8.5, weight: .medium)
                            .foregroundStyle(Palette.text(0.7))
                            .accessibilityAddTraits(.isHeader)
                        ForEach(tree.lines) { line in
                            TalentRow(session: session, commander: commander, line: line)
                        }
                    }
                }
                if !(commander.talents ?? []).isEmpty {
                    HStack {
                        Spacer()
                        ConfirmButton(title: TalentsView.forgetting, confirm: "Forget them all?") {
                            session.perform(.forgetTalents(commander: commander.id))
                        }
                    }
                }
            }
        }
    }

    static let forgetting = "Forget all · \(GameState.forgettingCost.moonsalt) moonsalt"

    /// The points it has to spend, or has spent.
    static func summary(of commander: Commander) -> String {
        let left = commander.pointsLeft
        if left > 0 { return "\(left) talent point\(left == 1 ? "" : "s") to spend" }
        let spent = commander.talents?.count ?? 0
        return spent == 0 ? "A talent point comes with each level" : "\(spent) talent point\(spent == 1 ? "" : "s") spent"
    }
}

/// A talent: its rank in pips, what a rank does, and the button that
/// learns the next, or why it can't.
private struct TalentRow: View {
    let session: GameSession
    let commander: Commander
    let line: TalentLine

    var body: some View {
        let talent = line.talent
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 5) {
                    Caps(talent.title, size: 8.5, weight: line.rank > 0 ? .medium : .regular)
                        .foregroundStyle(Palette.text(line.rank > 0 ? 0.85 : 0.6))
                    LevelPips(level: line.rank, maximum: talent.ranks)
                }
                Text(verbatim: talent.effect)
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            if !line.isMastered {
                QuietButton(title: "Learn", size: 8.5, enabled: line.refusal == nil,
                            name: "Learn \(talent.title) \(Narration.roman(line.rank + 1)) for \(commander.name)",
                            why: line.refusal?.description) {
                    session.perform(.learnTalent(commander: commander.id, talent: talent))
                }
            }
        }
    }
}
