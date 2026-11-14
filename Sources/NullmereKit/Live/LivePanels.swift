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
                    case .troops: LiveTroops(session: session, seconds: seconds)
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
