import LauncherKit
import NullmereCore
import SwiftUI

/// The House, the watch, each resource with what it brings in and how much
/// can be stored, and the end of the watch. Where the window is too narrow
/// for it all (larger type in a small window), the resources lose their
/// names, which their glyphs and tooltips still give.
struct TopBar: View {
    let session: GameSession
    /// Nil: whichever fits.
    var compact: Bool?

    var body: some View {
        if let compact {
            bar(compact: compact)
        } else {
            ViewThatFits(in: .horizontal) {
                bar(compact: false)
                bar(compact: true)
            }
        }
    }

    @ViewBuilder
    private func bar(compact: Bool) -> some View {
        let state = session.state
        let house = session.playerHouse
        let ledger = session.ledger
        let income = ledger.income
        let upkeep = ledger.upkeep
        let room = ledger.room

        HStack(spacing: 0) {
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.house(house))
                    .frame(width: 3, height: 22)
                VStack(alignment: .leading, spacing: 2) {
                    Caps(house.title, size: 11, weight: .medium, tracking: 0.32)
                        .foregroundStyle(Palette.ink)
                    WatchClock(session: session)
                }
            }
            .fixedSize()
            .layoutPriority(1)
            .accessibilityElement(children: .combine)

            Spacer(minLength: compact ? 12 : 24)

            HStack(spacing: compact ? 14 : 22) {
                ForEach(Resource.allCases, id: \.self) { resource in
                    let net = income[resource] - (resource == .grain ? upkeep : 0)
                    ResourceReadout(resource: resource, amount: house.stock[resource], net: net, room: room, named: !compact,
                                    summary: ledger.summaries[resource] ?? "",
                                    breakdown: { IncomeBreakdown(state: state, house: house.id, resource: resource, territory: session.territory) })
                }
            }
            .fixedSize()

            Spacer(minLength: compact ? 12 : 24)

            HStack(spacing: compact ? 2 : 6) {
                QuietButton(title: "Houses", action: { toggle(.houses) })
                QuietButton(title: "Chronicle", action: { toggle(.chronicle) })
                QuietButton(title: "Guide", action: { toggle(.guide) })
                EndWatchButton(session: session, compact: compact)
                    .padding(.leading, 8)
            }
            // Only the space between gives way; nothing in the bar wraps.
            .fixedSize()
        }
        .padding(.horizontal, 18)
        .padding(.vertical, 10)
        .background(
            LinearGradient(colors: [Color.black.opacity(0.88), Color.black.opacity(0.55)], startPoint: .top, endPoint: .bottom)
        )
        .overlay(alignment: .bottom) { Rule(opacity: 0.25) }
    }

    private func toggle(_ panel: GameSession.Panel) {
        withAnimation(.easeOut(duration: 0.2)) {
            session.panel = session.panel == panel ? nil : panel
        }
    }
}

private struct ResourceReadout: View {
    let resource: Resource
    let amount: Int
    let net: Int
    let room: Int
    var named = true
    /// Where it comes from, in a line, for the tooltip.
    let summary: String
    /// Where it comes from, in full, worked out when asked.
    let breakdown: () -> IncomeBreakdown

    @State private var showing = false

    var body: some View {
        Button { showing.toggle() } label: { readout }
            .buttonStyle(.plain)
            .popover(isPresented: $showing, arrowEdge: .bottom) { IncomeCard(breakdown: breakdown()) }
            .help(summary)
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(resource.title) \(amount), \(net >= 0 ? "gaining" : "losing") \(abs(net)) each watch, storage \(room)")
            .accessibilityHint("Shows where it comes from.")
    }

    private var readout: some View {
        HStack(spacing: 6) {
            ResourceGlyph(resource: resource, size: 8)
            VStack(alignment: .leading, spacing: 1) {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(verbatim: "\(amount)")
                        .font(.nm(13, weight: .regular).monospacedDigit())
                        .foregroundStyle(amount >= room ? Palette.glow : Palette.ink)
                    Text(verbatim: net >= 0 ? "+\(net)" : "−\(-net)")
                        .font(.nm(10, weight: .regular).monospacedDigit())
                        .foregroundStyle(net < 0 ? Palette.bad : Palette.good.opacity(0.85))
                }
                if named {
                    Caps(amount >= room ? "\(resource.title) · full" : resource.title, size: 7.5, tracking: 0.26)
                        .foregroundStyle(Palette.text(0.45))
                }
            }
        }
        // A resource's name is never broken across lines.
        .fixedSize()
        .contentShape(Rectangle())
    }
}

/// Where a resource comes from and goes, hold by hold.
struct IncomeCard: View {
    let breakdown: IncomeBreakdown

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                ResourceGlyph(resource: breakdown.resource, size: 8)
                Caps(breakdown.resource.title, size: 9, weight: .medium).foregroundStyle(Palette.ink)
                Spacer()
                Text(verbatim: "\(breakdown.stored) of \(breakdown.room)")
                    .font(.nm(10).monospacedDigit())
                    .foregroundStyle(Palette.text(0.55))
            }
            Rule(opacity: 0.25)
            if breakdown.lines.isEmpty {
                Text(verbatim: "Nothing comes in or goes out.")
                    .font(.nm(11, weight: .light))
                    .foregroundStyle(Palette.text(0.7))
            }
            ForEach(Array(breakdown.lines.enumerated()), id: \.offset) { _, line in
                HStack {
                    Text(verbatim: line.label).font(.nm(11, weight: .light)).foregroundStyle(Palette.text(0.85))
                    Spacer(minLength: 16)
                    Text(verbatim: line.amount >= 0 ? "+\(line.amount)" : "\(line.amount)")
                        .font(.nm(11).monospacedDigit())
                        .foregroundStyle(line.amount < 0 ? Palette.bad : Palette.good.opacity(0.85))
                }
            }
            Rule(opacity: 0.25)
            HStack {
                Caps("Each watch", size: 8).foregroundStyle(Palette.text(0.55))
                Spacer()
                Text(verbatim: breakdown.net >= 0 ? "+\(breakdown.net)" : "\(breakdown.net)")
                    .font(.nm(12, weight: .medium).monospacedDigit())
                    .foregroundStyle(breakdown.net < 0 ? Palette.bad : Palette.ink)
            }
            if let omen = breakdown.omen {
                Text(verbatim: omen).font(.nm(10)).foregroundStyle(Palette.glow)
            }
        }
        .padding(14)
        .frame(width: 240)
        .background(Palette.panel)
    }
}

/// Ready for the watch to turn, and what still waits for orders.
struct EndWatchButton: View {
    let session: GameSession
    /// In the narrow bar, what still waits is a tooltip, not a line.
    var compact = false

    var body: some View {
        let waiting = session.readyUnits.count
        let idle = session.idleHolds.count
        let waits = waiting > 0 || idle > 0 ? waitingText(units: waiting, holds: idle) : nil
        VStack(alignment: .trailing, spacing: 3) {
            if session.isReady {
                QuietButton(title: "Waiting", size: 10.5) { session.cancelReady() }
                    .help("Waiting for the other keepers. Click to take back being ready.")
                    .accessibilityHint("Takes back being ready.")
            } else {
                QuietButton(title: "Ready", size: 10.5, prominent: true, enabled: session.state.outcome == nil) {
                    session.endWatch()
                }
                .keyboardShortcut(.return, modifiers: .command)
                .help(session.playerHouse.isEliminated
                      ? "Your House has fallen: the watch waits on the keepers still standing, and on you only when none is there."
                      : [waits, "Done with this watch's orders. The watch turns when every keeper there is ready, or when its time runs out."]
                        .compactMap { $0 }.joined(separator: ". "))
            }
            if let waits, !compact {
                Text(verbatim: waits)
                    .font(.nm(9))
                    .foregroundStyle(Palette.text(0.5))
                    .lineLimit(1)
                    .fixedSize()
            }
        }
        .fixedSize()
    }

    /// "Turns in 2:14 · 1 of 3 ready": while the watch has a clock worth
    /// showing, and others are there.
    static func realmLine(status: RealmStatus?, secondsLeft: Int?) -> String? {
        guard let status else { return nil }
        var parts: [String] = []
        if let left = secondsLeft, left < 3_600 {
            parts.append("Turns in \(left / 60):\(String(format: "%02d", left % 60))")
        }
        if status.online > 1 {
            parts.append("\(status.ready) of \(status.online) ready")
        }
        return parts.isEmpty ? nil : parts.joined(separator: " · ")
    }

    private func waitingText(units: Int, holds: Int) -> String {
        var parts: [String] = []
        if units > 0 { parts.append(units == 1 ? "1 company waits" : "\(units) companies wait") }
        if holds > 0 { parts.append(holds == 1 ? "1 hold idle" : "\(holds) holds idle") }
        return parts.joined(separator: " · ")
    }
}

/// The watch, and beside it how long until it turns of itself and who is
/// ready: "Watch 12 · Turns in 2:14 · 1 of 3 ready".
struct WatchClock: View {
    let session: GameSession

    var body: some View {
        // A clock that ticks only while there is a realm's clock to show.
        TimelineView(.periodic(from: .now, by: session.realmStatus == nil ? 3_600 : 1)) { context in
            HStack(spacing: 0) {
                Caps("Watch \(session.state.watch)", size: 8.5, tracking: 0.3)
                    .foregroundStyle(Palette.text(0.55))
                if session.isOutOfReach {
                    Text(verbatim: "  ·  Out of reach, trying again…")
                        .font(.nm(9))
                        .foregroundStyle(Palette.bad)
                } else if let line = EndWatchButton.realmLine(status: session.realmStatus, secondsLeft: session.secondsLeft(at: context.date)) {
                    Text(verbatim: "  ·  " + line)
                        .font(.nm(9).monospacedDigit())
                        .foregroundStyle(Palette.text(0.55))
                }
            }
            .lineLimit(1)
            .fixedSize()
        }
    }
}

/// The last few things that happened, newest last.
struct NoticeFeed: View {
    let session: GameSession

    var body: some View {
        // As many of the latest as the column has room for, after the
        // panels below have theirs.
        ViewThatFits(in: .vertical) {
            feed(session.notices)
            feed(Array(session.notices.suffix(3)))
            feed(Array(session.notices.suffix(1)))
            Color.clear.frame(height: 0)
        }
        .animation(.easeOut(duration: 0.25), value: session.notices)
        .frame(maxWidth: 420, alignment: .leading)
    }

    private func feed(_ notices: [GameSession.Notice]) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            ForEach(notices) { notice in
                HStack(spacing: 8) {
                    ToneMark(tone: notice.tone)
                    Text(verbatim: notice.text)
                        .font(.nm(11.5, weight: .regular))
                        .foregroundStyle(Palette.text(0.88))
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .panelBackground()
                .transition(.opacity.combined(with: .move(edge: .leading)))
            }
        }
    }
}

/// The omen on the realm, under the top bar while it lasts.
struct OmenBand: View {
    let omen: Omen
    let watch: Int

    var body: some View {
        let left = omen.watchesLeft(at: watch)
        HStack(spacing: 8) {
            Circle().fill(Palette.glow).frame(width: 4, height: 4)
            Caps(omen.kind.title, size: 8.5, weight: .medium, tracking: 0.3)
                .foregroundStyle(Palette.glow)
            Text(verbatim: "\(omen.kind.effect) \(OmenBand.lasting(left))")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.75))
        }
        .lineLimit(1)
        .fixedSize()
        .padding(.horizontal, 14)
        .padding(.vertical, 6)
        .background(RoundedRectangle(cornerRadius: 3).fill(Palette.panel.opacity(0.82)))
        .overlay(RoundedRectangle(cornerRadius: 3).strokeBorder(Palette.glow.opacity(0.25), lineWidth: 1))
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Omen: \(omen.kind.title). \(omen.kind.effect) \(OmenBand.lasting(left))")
        .accessibilityAddTraits(.isStaticText)
    }

    static func lasting(_ left: Int) -> String {
        left <= 1 ? "It lifts as the watch turns." : "It lifts in \(left) watches."
    }
}

/// A notice's tone: a coloured dot, or, with "Differentiate without
/// colour" on, a sign that says it in shape: + good, ! bad.
struct ToneMark: View {
    let tone: GameSession.Notice.Tone
    /// With "Differentiate without colour" on, what colour says is said in
    /// shape too.
    private var differentiate: Bool { Contrast.shared.differentiates }

    var body: some View {
        if differentiate, tone != .neutral {
            Text(verbatim: tone == .good ? "+" : "!")
                .font(.nm(10, weight: .medium))
                .foregroundStyle(Palette.tone(tone))
                .frame(width: 8)
                .accessibilityHidden(true)
        } else {
            Circle()
                .fill(Palette.tone(tone))
                .frame(width: 4, height: 4)
                .accessibilityHidden(true)
        }
    }
}
