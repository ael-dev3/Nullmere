import NullmereCore
import NullmereLive
import NullmereLiveStage
import SwiftUI

/// The side of the window, given over to the city's buildings, its
/// troops, or the reports, for as long as the player wants it.
struct LiveSidePanel: View {
    let session: LiveSession
    let seconds: Double
    let panel: LiveGameView.Panel
    let close: () -> Void

    private var title: String {
        switch panel {
        case .city: return "Buildings"
        case .troops: return "Troops"
        case .studies: return "Studies"
        case .alliance: return "Alliance"
        case .chat: return "Chat"
        case .reports: return "Reports"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Caps(title, size: 11, weight: .medium)
                    .foregroundStyle(Palette.ink)
                Spacer(minLength: 0)
                QuietButton(title: "Close", action: close)
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    switch panel {
                    case .city: LiveBuildings(session: session, seconds: seconds)
                    case .troops:
                        LiveCommanders(session: session, seconds: seconds)
                        LiveTroops(session: session, seconds: seconds)
                    case .studies: LiveStudies(session: session, seconds: seconds)
                    case .alliance: LiveAlliancePanel(session: session)
                    case .chat: LiveChatPanel(session: session)
                    case .reports: LiveReports(session: session, seconds: seconds)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        }
        .padding(14)
        .frame(width: 340)
        .frame(maxHeight: .infinity, alignment: .top)
        .panelBackground()
    }
}

/// Small words under a line: what it costs, or why not.
private struct LiveSmall: View {
    let words: String
    var dim = false

    var body: some View {
        Text(verbatim: words)
            .font(.nm(11))
            .foregroundStyle(Palette.text(dim ? 0.55 : 0.75))
            .fixedSize(horizontal: false, vertical: true)
    }
}

/// How far along something is, and how long it has to go.
private struct LiveProgress: View {
    let part: Double
    let left: Int

    var body: some View {
        HStack(spacing: 8) {
            ProgressView(value: min(max(part, 0), 1))
                .progressViewStyle(.linear)
                .tint(Palette.glow)
            Text(verbatim: LiveWords.clock(left))
                .font(.nm(11, weight: .medium))
                .monospacedDigit()
                .foregroundStyle(Palette.glowWords)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(LiveWords.spoken(left)) left")
    }
}

/// Every building of the catalogue: those the city has, with what the
/// next level costs and a way to raise it, then those it could build.
struct LiveBuildings: View {
    let session: LiveSession
    let seconds: Double

    var body: some View {
        ForEach(session.world.buildingLines(at: seconds)) { line in
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: line.name)
                        .font(.nm(13, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text(verbatim: line.building == nil ? "Not built" : "Level \(line.level)")
                        .font(.nm(11))
                        .foregroundStyle(Palette.text(0.65))
                    Spacer(minLength: 0)
                    if line.job == nil, line.next != nil {
                        QuietButton(title: line.building == nil ? "Build" : "Upgrade", prominent: line.block == nil,
                                    enabled: line.block == nil && session.asking == 0,
                                    name: "\(line.building == nil ? "Build" : "Upgrade") \(line.name)", why: line.block?.words) {
                            Task {
                                if let building = line.building {
                                    await session.upgrade(building: building.id)
                                } else {
                                    await session.build(line.kind)
                                }
                            }
                        }
                    }
                }
                if let job = line.job {
                    LiveProgress(part: job.progress(at: seconds), left: Int(job.left(at: seconds).rounded(.up)))
                } else if let next = line.next {
                    LiveSmall(words: "\(next.cost.sentence), \(LiveWords.spoken(next.seconds))")
                    if let block = line.block {
                        LiveSmall(words: block.words, dim: true)
                    }
                } else if let block = line.block {
                    LiveSmall(words: block.words, dim: true)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// Those who lead the city's armies: each with their way of war, their
/// level and where they are, and a way to take on another.
struct LiveCommanders: View {
    let session: LiveSession
    let seconds: Double

    var body: some View {
        let world = session.world
        ForEach(world.commanders) { commander in
            VStack(alignment: .leading, spacing: 2) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: commander.name)
                        .font(.nm(13, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text(verbatim: "\(commander.wayName), level \(commander.level)")
                        .font(.nm(11))
                        .foregroundStyle(Palette.text(0.65))
                    Spacer(minLength: 0)
                    LiveSmall(words: commander.isFree ? "In the city" : "Out with an army", dim: true)
                }
                LiveSmall(words: commander.wayWords)
            }
            .accessibilityElement(children: .combine)
        }
        let block = world.hireBlock(at: seconds)
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            LiveSmall(words: block?.words ?? "Another commander: \(LiveWorld.hireCost(have: world.commanders.count).words).", dim: block != nil)
            Spacer(minLength: 0)
            QuietButton(title: "Take on", prominent: block == nil, enabled: block == nil && session.asking == 0, name: "Take on another commander",
                        why: block?.words) {
                Task { await session.hire() }
            }
        }
        Rectangle()
            .fill(Palette.line(0.12))
            .frame(height: 1)
    }
}

/// What the Academy studies: each topic with what the city has of it,
/// what its next level costs, and a way to study it.
struct LiveStudies: View {
    let session: LiveSession
    let seconds: Double

    var body: some View {
        let lines = session.world.studyLines(at: seconds)
        if lines.isEmpty {
            LiveSmall(words: "Nothing to study has been told of yet.")
        }
        ForEach(lines) { line in
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: line.name)
                        .font(.nm(13, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text(verbatim: line.soFar)
                        .font(.nm(11))
                        .foregroundStyle(Palette.text(0.65))
                    Spacer(minLength: 0)
                    if line.job == nil, line.next != nil {
                        QuietButton(title: "Study", prominent: line.block == nil, enabled: line.block == nil && session.asking == 0,
                                    name: "Study \(line.name)", why: line.block?.words) {
                            Task { await session.learn(topic: line.topic) }
                        }
                    }
                }
                LiveSmall(words: line.words)
                if let job = line.job {
                    LiveProgress(part: job.progress(at: seconds), left: Int(job.left(at: seconds).rounded(.up)))
                } else if let next = line.next {
                    LiveSmall(words: "\(next.cost.sentence), \(LiveWords.spoken(next.seconds))", dim: true)
                    if let block = line.block, block != .studying {
                        LiveSmall(words: block.words, dim: true)
                    }
                } else if let block = line.block {
                    LiveSmall(words: block.words, dim: true)
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// The city's soldiers, what each training building can train, and the
/// wounded to be healed.
struct LiveTroops: View {
    let session: LiveSession
    let seconds: Double

    var body: some View {
        let world = session.world
        let troops = world.troopLines()
        if troops.isEmpty {
            LiveSmall(words: "Your city has no soldiers yet. Build a Barracks to train some.")
        }
        ForEach(troops) { troop in
            VStack(alignment: .leading, spacing: 3) {
                Text(verbatim: "\(troop.name), tier \(troop.tier)")
                    .font(.nm(13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                LiveSmall(words: Self.counts(troop))
                if troop.wounded > 0 {
                    QuietButton(title: "Heal \(LiveWords.grouped(troop.wounded))", enabled: session.asking == 0,
                                name: "Heal \(LiveWords.grouped(troop.wounded)) \(troop.name)") {
                        Task { await session.heal(kind: troop.kind, tier: troop.tier, count: troop.wounded) }
                    }
                }
            }
        }
        if let healing = world.jobs.first(where: { $0.kind == LiveJob.heal }) {
            LiveSmall(words: "Healing \(LiveWords.grouped(healing.amount))")
            LiveProgress(part: healing.progress(at: seconds), left: Int(healing.left(at: seconds).rounded(.up)))
        }
        LiveSmall(words: "Room to tend \(LiveWords.grouped(world.roomForWounded)) more wounded.", dim: true)

        ForEach(world.trainLines(at: seconds)) { line in
            VStack(alignment: .leading, spacing: 5) {
                Text(verbatim: "\(line.name), level \(line.building.level)")
                    .font(.nm(13, weight: .medium))
                    .foregroundStyle(Palette.ink)
                if let job = line.job {
                    LiveSmall(words: "Training \(LiveWords.grouped(job.amount)) of tier \(job.level)")
                    LiveProgress(part: job.progress(at: seconds), left: Int(job.left(at: seconds).rounded(.up)))
                } else {
                    ForEach(line.tiers, id: \.tier) { tier in
                        let most = world.mostTrainable(line, tier: tier.tier, at: seconds)
                        HStack(alignment: .firstTextBaseline, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                LiveSmall(words: "Tier \(tier.tier): \(tier.soldier.cost.words) each")
                                if let block = tier.block {
                                    LiveSmall(words: block.words, dim: true)
                                }
                            }
                            Spacer(minLength: 0)
                            QuietButton(title: most > 0 ? "Train \(LiveWords.grouped(most))" : "Train", prominent: tier.block == nil && most > 0,
                                        enabled: tier.block == nil && most > 0 && session.asking == 0,
                                        name: "Train \(LiveWords.grouped(most)) tier \(tier.tier) \(tier.soldier.name)", why: tier.block?.words) {
                                Task { await session.train(building: line.building.id, tier: tier.tier, count: most) }
                            }
                        }
                    }
                }
            }
            .padding(.top, 6)
        }
    }

    /// A troop line's numbers in words: "40 ready, 6 wounded, 20 out".
    static func counts(_ troop: LiveTroopLine) -> String {
        var parts = ["\(LiveWords.grouped(troop.ready)) ready"]
        if troop.wounded > 0 { parts.append("\(LiveWords.grouped(troop.wounded)) wounded") }
        if troop.out > 0 { parts.append("\(LiveWords.grouped(troop.out)) out") }
        return parts.joined(separator: ", ")
    }
}

/// What the player's armies did, the latest first, in the realm's words.
struct LiveReports: View {
    let session: LiveSession
    let seconds: Double

    var body: some View {
        let reports = session.world.reports
        if reports.isEmpty {
            LiveSmall(words: "No reports yet. Send an army against a barrow and what happens is told here.")
        }
        ForEach(reports) { report in
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: report.words)
                    .font(.nm(12, weight: report.read ? .regular : .medium))
                    .foregroundStyle(report.read ? Palette.text(0.75) : Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                HStack(spacing: 8) {
                    LiveSmall(words: "\(LiveWords.spoken(max(Int(seconds) - report.at, 0))) ago", dim: true)
                    Spacer(minLength: 0)
                    QuietButton(title: "Show", name: "Show where this happened") {
                        session.go(to: report.hex)
                        session.selected = report.hex
                    }
                    if !report.read {
                        QuietButton(title: "Read", enabled: session.asking == 0, name: "Mark this report read") {
                            Task { await session.read(report: report.id) }
                        }
                    }
                    QuietButton(title: "Forget", enabled: session.asking == 0, name: "Throw this report away") {
                        Task { await session.forget(report: report.id) }
                    }
                }
            }
            .accessibilityElement(children: .contain)
        }
    }
}

/// A line of typing with a rule under it, as the interface takes words.
private struct LiveField: View {
    let prompt: String
    @Binding var text: String
    var width: CGFloat?
    let submit: () -> Void

    var body: some View {
        TextField(prompt, text: $text)
            .textFieldStyle(.plain)
            .font(.nm(12))
            .foregroundStyle(Palette.ink)
            .frame(width: width)
            .padding(.vertical, 4)
            .overlay(alignment: .bottom) {
                Rectangle().fill(Palette.line(0.35)).frame(height: 1)
            }
            .onSubmit(submit)
            .accessibilityLabel(prompt)
    }
}

/// The player's alliance, with its members and those asking to join; and
/// every alliance of the realm, to join one or found another.
struct LiveAlliancePanel: View {
    let session: LiveSession
    @State private var name = ""
    @State private var tag = ""

    var body: some View {
        let world = session.world
        if let mine = world.myAlliance {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "[\(mine.tag)] \(mine.name)")
                    .font(.nm(14, weight: .medium))
                    .foregroundStyle(Palette.ink)
                LiveSmall(words: "\(mine.members) of \(LiveWorld.allianceMost) members. \(mine.open ? "Anyone may join." : "Joining is by asking.")")
                if !mine.words.isEmpty {
                    LiveSmall(words: mine.words)
                }
            }
            ForEach(world.roster(of: mine.id)) { member in
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: world.players[member.player]?.name ?? "Someone")
                        .font(.nm(12, weight: member.player == world.me?.id ? .medium : .regular))
                        .foregroundStyle(Palette.ink)
                    LiveSmall(words: member.title, dim: true)
                    Spacer(minLength: 0)
                    if world.isLeader, member.player != world.me?.id {
                        QuietButton(title: member.rank == LiveMember.officer ? "Make member" : "Make officer", enabled: session.asking == 0) {
                            Task { await session.setRank(of: member.player, to: member.rank == LiveMember.officer ? LiveMember.member : LiveMember.officer) }
                        }
                    }
                    if world.isOfficer, member.rank < (world.myMembership?.rank ?? 0) {
                        QuietButton(title: "Put out", enabled: session.asking == 0, name: "Put \(world.players[member.player]?.name ?? "them") out of the alliance") {
                            Task { await session.expel(member.player) }
                        }
                    }
                }
            }
            if world.isOfficer, !world.applicants.isEmpty {
                Caps("Asking to join", size: 10)
                    .foregroundStyle(Palette.text(0.7))
                ForEach(world.applicants) { asked in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        Text(verbatim: asked.name)
                            .font(.nm(12))
                            .foregroundStyle(Palette.ink)
                        Spacer(minLength: 0)
                        QuietButton(title: "Let in", prominent: true, enabled: session.asking == 0, name: "Let \(asked.name) in") {
                            Task { await session.answer(applicant: asked.player, admit: true) }
                        }
                        QuietButton(title: "Turn away", enabled: session.asking == 0, name: "Turn \(asked.name) away") {
                            Task { await session.answer(applicant: asked.player, admit: false) }
                        }
                    }
                }
            }
            QuietButton(title: "Leave the alliance", enabled: session.asking == 0) {
                Task { await session.leaveAlliance() }
            }
        } else {
            LiveSmall(words: "You are in no alliance. Join one below, or found your own.")
        }

        let others = world.allianceLines().filter { $0.standing != "Your alliance" }
        if !others.isEmpty {
            Caps("Alliances of the realm", size: 10)
                .foregroundStyle(Palette.text(0.7))
        }
        ForEach(others) { line in
            VStack(alignment: .leading, spacing: 3) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: "[\(line.alliance.tag)] \(line.alliance.name)")
                        .font(.nm(12, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Spacer(minLength: 0)
                    if let offer = line.offer {
                        QuietButton(title: offer, prominent: line.why == nil, enabled: line.why == nil && session.asking == 0,
                                    name: "\(offer): \(line.alliance.name)", why: line.why) {
                            Task { await session.joinAlliance(line.alliance.id) }
                        }
                    }
                }
                LiveSmall(words: "\(line.alliance.members) members\(line.standing.map { ". \($0)." } ?? "")", dim: true)
                if !line.alliance.words.isEmpty {
                    LiveSmall(words: line.alliance.words)
                }
            }
        }

        if world.myAlliance == nil {
            Caps("Found an alliance", size: 10)
                .foregroundStyle(Palette.text(0.7))
            if let block = world.foundingBlock {
                LiveSmall(words: block, dim: true)
            } else {
                HStack(spacing: 10) {
                    LiveField(prompt: "Its name", text: $name, width: nil, submit: found)
                    LiveField(prompt: "Tag", text: $tag, width: 56, submit: found)
                }
                QuietButton(title: "Found it", prominent: true,
                            enabled: LiveWorld.allianceNameFits(name) && LiveWorld.tagFits(tag) && session.asking == 0,
                            why: "A name of 3 to 20 letters, and a tag of 3 or 4.", action: found)
            }
        }
    }

    private func found() {
        guard LiveWorld.allianceNameFits(name), LiveWorld.tagFits(tag) else { return }
        Task { await session.foundAlliance(name: name, tag: tag) }
    }
}

/// What is being said: in the realm, or within the player's alliance,
/// the latest first, with a line to say something more.
struct LiveChatPanel: View {
    let session: LiveSession
    @State private var within = false
    @State private var words = ""

    var body: some View {
        let world = session.world
        HStack(spacing: 4) {
            QuietButton(title: "Realm", prominent: !within) { within = false }
            QuietButton(title: "Alliance", prominent: within, enabled: world.myAlliance != nil, why: "You are in no alliance.") { within = true }
        }
        HStack(spacing: 8) {
            LiveField(prompt: within ? "Say to your alliance" : "Say to the realm", text: $words, width: nil, submit: say)
            QuietButton(title: "Say", prominent: true, enabled: LiveWorld.sayingFits(words) && session.asking == 0,
                        why: "Something to say, of 200 letters at most.", action: say)
        }
        let lines = world.chatLines(withinAlliance: within && world.myAlliance != nil)
        if lines.isEmpty {
            LiveSmall(words: "Nothing has been said here yet.", dim: true)
        }
        ForEach(lines.reversed()) { line in
            VStack(alignment: .leading, spacing: 1) {
                Text(verbatim: line.name)
                    .font(.nm(11, weight: .medium))
                    .foregroundStyle(line.own ? Palette.glowWords : Palette.text(0.7))
                Text(verbatim: line.words)
                    .font(.nm(12))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func say() {
        guard LiveWorld.sayingFits(words) else { return }
        let saying = words
        words = ""
        Task { await session.say(saying, withinAlliance: within && session.world.myAlliance != nil) }
    }
}
