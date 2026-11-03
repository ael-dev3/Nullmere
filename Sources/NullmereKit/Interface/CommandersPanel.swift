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
                    // The commanders of other Houses this House holds prisoner.
                    let prisoners = session.state.prisoners(heldBy: session.player)
                    if !prisoners.isEmpty {
                        Rule(opacity: 0.18)
                        PrisonersSection(session: session, prisoners: prisoners)
                    }
                    Rule(opacity: 0.18)
                    ArmouryView(session: session, commanders: board.lines.map(\.commander))
                    Rule(opacity: 0.18)
                    ForgeView(session: session)
                    if session.playerHouse.isPlayer, !board.lines.isEmpty {
                        Rule(opacity: 0.18)
                        RingSection(session: session)
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.commanders))
        }
        .padding(16)
        .frame(width: PanelWidth.rail)
        .panelHeight()
        .panelBackground()
    }

    /// A company as a commander's row names it: its kind and tier.
    static func named(_ unit: Unit) -> String {
        unit.kind.hasTiers ? "\(unit.kind.title) \(Narration.roman(unit.tier))" : unit.kind.title
    }

    /// Where a commander stands: held prisoner, at the head of a company,
    /// mending, or free.
    static func standing(of line: CommanderLine, in state: GameState? = nil) -> String {
        if let captor = line.heldBy {
            let by = state.flatMap { $0.houses.indices.contains(captor) ? $0.houses[captor].title : nil } ?? "another House"
            return "Held prisoner by \(by)"
        }
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
            HStack(alignment: .center, spacing: 10) {
                Portrait(key: .commander(variant: Archetype.allCases.firstIndex(of: commander.archetype) ?? 0),
                         colour: Portrait.colour(of: commander.owner, in: session.state), size: 44)
                VStack(alignment: .leading, spacing: 3) {
                    Caps(commander.name, size: 10, weight: .medium).foregroundStyle(Palette.ink)
                    Text(verbatim: "\(commander.archetype.title) · level \(line.level)")
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.65))
                }
                Spacer()
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
                Text(verbatim: CommandersPanel.standing(of: line, in: session.state))
                    .font(.nm(10.5))
                    .foregroundStyle(line.woundedFor != nil || line.heldBy != nil ? Palette.bad : Palette.text(0.7))
                Spacer()
                if line.heldBy != nil {
                    // Held prisoner: its House may ransom it.
                    let price = GameState.ransom(for: commander)
                    let refusal = session.state.ransomRefusal(commander.id, as: session.player)
                    QuietButton(title: "Ransom, \(price)", size: 8.5, enabled: refusal == nil, name: "Ransom \(commander.name) for \(price)",
                                why: refusal?.description) {
                        session.perform(.ransom(commander: commander.id))
                    }
                } else if line.leads != nil {
                    QuietButton(title: "Call back", size: 8.5, name: "Call \(commander.name) back") {
                        session.perform(.unassign(commander: commander.id))
                    }
                } else if let unit = chosen, unit.leader != nil {
                    // The company has its leader: this one may ride second,
                    // adding half its edges, more if the two are of a kind.
                    let refusal = session.state.secondRefusal(of: commander.id, to: unit.id, as: session.player)
                    QuietButton(title: "Ride second", size: 8.5, enabled: refusal == nil,
                                name: "Send \(commander.name) to ride second with the \(CommandersPanel.named(unit))",
                                why: refusal?.description) {
                        session.perform(.assignSecond(commander: commander.id, unit: unit.id))
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
            ForEach(session.state.worn(by: commander.id).sorted { $0.slot.rawValue < $1.slot.rawValue }) { piece in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Caps("\(piece.slot.title): \(piece.title)", size: 8.5, weight: .medium)
                            .foregroundStyle(Palette.text(0.85))
                        Text(verbatim: piece.effect)
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    QuietButton(title: "Take off", size: 8.5, name: "Take the \(piece.title) off \(commander.name)") {
                        session.perform(.takeOff(gear: piece.id))
                    }
                }
            }
            StarsLine(session: session, commander: commander)
            TalentsView(session: session, commander: commander)
        }
    }
}

/// The House's armoury: the gear its commanders don't wear, each piece
/// with what it gives, a button to arm the commander chosen with it, and
/// one to break it up for moonsalt.
struct ArmouryView: View {
    let session: GameSession
    let commanders: [Commander]
    /// The commander the next piece goes to; the first, until one is chosen.
    @State private var chosen: Int?

    var body: some View {
        let held = session.state.gear(of: session.player)
        let kept = held.filter { $0.wornBy == nil }
        let wearer = commanders.first { $0.id == chosen } ?? commanders.first
        VStack(alignment: .leading, spacing: 6) {
            Caps("Armoury · \(held.count) of \(GameState.armouryLimit)", size: 9, weight: .medium)
                .foregroundStyle(Palette.text(0.7))
                .accessibilityAddTraits(.isHeader)
            if kept.isEmpty {
                Text(verbatim: ArmouryView.empty)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            } else if commanders.count > 1 {
                Picker("Arm", selection: Binding(get: { wearer?.id ?? 0 }, set: { chosen = $0 })) {
                    ForEach(commanders) { commander in
                        Text(verbatim: commander.name).tag(commander.id)
                    }
                }
                .pickerStyle(.menu)
                .font(.nm(10.5))
                .accessibilityLabel("The commander to arm")
            }
            ForEach(kept) { piece in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    VStack(alignment: .leading, spacing: 1) {
                        Caps("\(piece.title) · \(piece.slot.title.lowercased())", size: 8.5, weight: .medium)
                            .foregroundStyle(Palette.text(0.85))
                        Text(verbatim: piece.effect)
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    QuietButton(title: "Arm", size: 8.5, enabled: wearer != nil,
                                name: "Arm \(wearer?.name ?? "a commander") with the \(piece.title)",
                                why: "No commander serves your House.") {
                        if let wearer { session.perform(.wear(gear: piece.id, commander: wearer.id)) }
                    }
                    ConfirmButton(title: "Break up", confirm: "For \(piece.scrap) moonsalt?") {
                        session.perform(.breakUp(gear: piece.id))
                    }
                }
            }
        }
    }

    static let empty = "Gear falls with the wilds struck down: weapons, armour and charms for your commanders, finer from the higher levels."
}

/// The House's Forge: the makings it keeps, how fine its Forge works, and
/// each piece of the three sets, what forging it takes and gives, with a
/// button to forge it.
struct ForgeView: View {
    let session: GameSession
    /// How fine to forge; the finest the Forge makes, until another is chosen.
    @State private var chosen: GearQuality?

    var body: some View {
        let state = session.state, house = session.player
        let level = state.forgeLevel(of: house)
        let quality = ForgeView.quality(chosen, atLevel: level)
        VStack(alignment: .leading, spacing: 6) {
            Caps(level > 0 ? "Forge · level \(Narration.roman(level))" : "Forge", size: 9, weight: .medium)
                .foregroundStyle(Palette.text(0.7))
                .accessibilityAddTraits(.isHeader)
            Text(verbatim: ForgeView.makingsLine(state, house))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            if level == 0 {
                Text(verbatim: ForgeView.noForge)
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                Picker("How fine", selection: Binding(get: { quality }, set: { chosen = $0 })) {
                    ForEach(GearQuality.allCases.filter { $0.forgeLevel <= level }, id: \.self) { quality in
                        Text(verbatim: quality.title).tag(quality)
                    }
                }
                .pickerStyle(.segmented)
                .accessibilityLabel("How fine to forge")
                ForEach(GearSet.allCases, id: \.self) { set in
                    VStack(alignment: .leading, spacing: 4) {
                        Caps(set.name, size: 8.5, weight: .medium).foregroundStyle(Palette.glowWords)
                        Text(verbatim: set.effect.prefix(1).uppercased() + set.effect.dropFirst() + ".")
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.55))
                            .fixedSize(horizontal: false, vertical: true)
                        ForEach(set.pieces, id: \.self) { kind in
                            ForgeRow(session: session, kind: kind, quality: quality)
                        }
                    }
                }
            }
        }
    }

    /// The quality chosen, held to the finest a Forge of a level makes.
    static func quality(_ chosen: GearQuality?, atLevel level: Int) -> GearQuality {
        let finest = GearQuality.forged(atLevel: level) ?? .plain
        return chosen.map { min($0, finest) } ?? finest
    }

    /// What the House keeps of each making.
    static func makingsLine(_ state: GameState, _ house: Int) -> String {
        "Makings: " + Making.allCases.map { "\(state.makings($0, of: house)) \($0.title.lowercased())" }.joined(separator: ", ") + "."
    }

    /// What forging a piece this fine takes, in words.
    static func recipeLine(_ kind: GearKind, _ quality: GearQuality, in state: GameState, for house: Int) -> String {
        let recipe = state.recipe(kind, quality, for: house)
        let makings = Making.allCases.compactMap { making in recipe[making].map { "\($0) \(making.title.lowercased())" } }
        return (makings + ["\(GameState.forgingCost(quality).moonsalt) moonsalt"]).joined(separator: ", ")
    }

    static let noForge = "Raise a Forge at one of your holds to forge gear of three sets from the makings your companies bring in: "
        + "hide, iron, heartwood and moonglass, from the wilds they strike down and the land's sites they gather at."
}

/// A piece of a set: what it gives at the quality chosen, what forging it
/// takes, and the button that forges it.
private struct ForgeRow: View {
    let session: GameSession
    let kind: GearKind
    let quality: GearQuality

    var body: some View {
        let state = session.state
        let piece = Gear(id: 0, kind: kind, quality: quality, owner: session.player)
        let refusal = state.refusal(of: .forge(kind, quality: quality), as: session.player)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            VStack(alignment: .leading, spacing: 1) {
                Caps("\(kind.title) · \(kind.slot.title.lowercased())", size: 8.5, weight: .medium)
                    .foregroundStyle(Palette.text(0.85))
                Text(verbatim: "\(piece.effect). Takes \(ForgeView.recipeLine(kind, quality, in: state, for: session.player)).")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            Spacer()
            QuietButton(title: "Forge", size: 8.5, enabled: refusal == nil, name: "Forge a \(piece.title)", why: refusal?.description) {
                session.perform(.forge(kind, quality: quality))
            }
        }
    }
}

/// A commander's talents: its three trees, each talent's rank and what a
/// rank does, a button to learn the next, and one to forget them all and
/// learn anew. Shown of itself while points wait to be spent.
/// A commander's stars, as pips, and the sculptures its next would take:
/// the button sets them when the House keeps enough.
struct StarsLine: View {
    let session: GameSession
    let commander: Commander

    static func line(_ commander: Commander, kept: Int) -> String {
        guard let cost = Commander.sculpturesToRaise(from: commander.starCount) else { return "All \(Commander.mostStars) stars" }
        return "Next star: \(cost) sculptures, \(kept) kept"
    }

    var body: some View {
        let kept = session.state.sculptures(of: session.player)
        let refusal = session.state.starRefusal(of: commander.id, as: session.player)
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            LevelPips(level: commander.starCount, maximum: Commander.mostStars)
                .accessibilityLabel("\(commander.starCount) of \(Commander.mostStars) stars")
            Text(verbatim: StarsLine.line(commander, kept: kept))
                .font(.nm(10.5))
                .foregroundStyle(refusal == nil ? Palette.glowWords : Palette.text(0.6))
            Spacer()
            if Commander.sculpturesToRaise(from: commander.starCount) != nil, refusal == nil || kept > 0 {
                QuietButton(title: "Raise a star", size: 8.5, enabled: refusal == nil,
                            name: "Raise \(commander.name) to \(commander.starCount + 1) stars", why: refusal?.description) {
                    session.perform(.raiseStar(commander: commander.id))
                }
            }
        }
    }
}

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
                            // Each branch named where it grows from the
                            // root, its talents set in beneath it.
                            if let branch = line.talent.branch, line.talent.place == 1 || line.talent.place == 3 {
                                Text(verbatim: branch == 0 ? tree.tree.branches.0 : tree.tree.branches.1)
                                    .font(.nm(9.5).italic())
                                    .foregroundStyle(Palette.text(0.5))
                                    .padding(.leading, 10)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            TalentRow(session: session, commander: commander, line: line)
                                .padding(.leading, line.talent.branch == nil ? 0 : 10)
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

/// The commanders of other Houses held prisoner: how long they have been
/// held, the last true thing each told, and whether they may be questioned
/// again this watch or let go.
struct PrisonersSection: View {
    let session: GameSession
    let prisoners: [Commander]

    /// How long a prisoner has been held, and how long until they slip away.
    static func held(_ captive: Captivity, at watch: Int) -> String {
        let left = max(0, captive.since + GameState.captivityLasts - watch)
        return left == 1 ? "Slips away as the watch turns" : "Slips away in \(left) watches"
    }

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 10) {
            Caps("Prisoners", size: 8.5, weight: .medium)
                .foregroundStyle(Palette.text(0.6))
            ForEach(prisoners, id: \.id) { prisoner in
                let house = state.houses.indices.contains(prisoner.owner) ? state.houses[prisoner.owner].title : "a House since gone"
                VStack(alignment: .leading, spacing: 4) {
                    HStack(alignment: .firstTextBaseline) {
                        Caps(prisoner.name, size: 9.5, weight: .medium).foregroundStyle(Palette.ink)
                        Text(verbatim: "of \(house), level \(prisoner.level)")
                            .font(.nm(10.5))
                            .foregroundStyle(Palette.text(0.65))
                        Spacer()
                    }
                    if let captive = prisoner.captive {
                        Text(verbatim: PrisonersSection.held(captive, at: state.watch))
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.55))
                        if session.awaitsRealm(.question(commander: prisoner.id)) {
                            // What this copy would guess from what it sees is no true thing.
                            Text(verbatim: "Questioned; their words are on the way.")
                                .font(.nm(10.5, weight: .light))
                                .foregroundStyle(Palette.text(0.6))
                        } else if let last = captive.told?.last {
                            // In the prisoner's voice, where this Mac's model gave it one; the true thing plainly beneath.
                            if let key = GameSession.Spoken.prisonerKey(of: prisoner), let voiced = session.spoken[key] {
                                Text(verbatim: voiced)
                                    .font(.nm(10.5, weight: .light))
                                    .foregroundStyle(Palette.glowWords)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                            Text(verbatim: last)
                                .font(.nm(10.5))
                                .foregroundStyle(Palette.text(0.8))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                    }
                    HStack(spacing: 8) {
                        Spacer()
                        let refusal = state.questionRefusal(prisoner.id, as: session.player)
                        let asking = session.awaitsRealm(.question(commander: prisoner.id))
                        QuietButton(title: "Question", size: 8.5, enabled: refusal == nil && !asking, name: "Question \(prisoner.name)",
                                    why: asking ? "Their words are on the way." : refusal?.description) {
                            session.perform(.question(commander: prisoner.id))
                        }
                        QuietButton(title: "Let go", size: 8.5, name: "Let \(prisoner.name) go home") {
                            session.perform(.release(commander: prisoner.id))
                        }
                    }
                }
                .accessibilityElement(children: .contain)
            }
        }
    }
}
