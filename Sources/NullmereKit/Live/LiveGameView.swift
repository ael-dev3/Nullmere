import Foundation
import NullmereCore
import NullmereLive
import NullmereLiveStage
import SwiftUI

/// The rebuilt realm, played: the world filling the window, and over it
/// only what the moment needs. Along the top, the city's goods and the
/// task the player is on; at the foot, the player's armies out, the
/// doors to everything else, and a card for whatever is chosen; at the
/// side, when asked for, the city, its troops, its studies, the
/// alliance, what is being said, or the reports.
public struct LiveGameView: View {
    /// What the side of the window is given over to.
    enum Panel: Equatable {
        case city
        case troops
        case studies
        case alliance
        case chat
        case reports
    }

    private let session: LiveSession
    @State private var panel: Panel?
    @State private var cannotDraw = false

    public init(session: LiveSession) {
        self.session = session
    }

    public var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            switch session.phase {
            case .opening:
                LiveNotice(title: "Reaching the realm", words: "One moment.", button: nil) {}
            case .lost:
                LiveNotice(title: "The realm can't be reached", words: "Check your connection, then try again.", button: "Try again") {
                    Task { await session.open() }
                }
            case .naming, .playing:
                if cannotDraw {
                    LiveNotice(title: "The world can't be drawn", words: "This Mac's graphics could not draw it.", button: nil) {}
                } else {
                    LiveMapView(session: session, onFailure: { cannotDraw = true })
                        .ignoresSafeArea()
                        .accessibilityLabel("The realm's map")
                }
                if session.phase == .naming {
                    LiveNameCard(session: session)
                } else {
                    LiveHUD(session: session, panel: $panel)
                }
            }
        }
        .task {
            await session.open()
            #if DEBUG
            await LiveGameView.rehearse(session, ProcessInfo.processInfo.environment) { panel = $0 }
            #endif
        }
    }

    #if DEBUG
    /// For the smoke test, which can press nothing: joins under the name
    /// NULLMERE_REBUILT_NAME gives where a name is wanted, then shows what
    /// NULLMERE_REBUILT_SHOW names: the city's buildings, its troops, the
    /// reports, or the nearest barrow or site chosen. It waits on the
    /// realm for as many tenths of a second as it has patience.
    static func rehearse(_ session: LiveSession, _ environment: [String: String], patience: Int = 150, show: (Panel) -> Void) async {
        func wait(until done: () -> Bool) async {
            for _ in 0..<patience where !done() {
                try? await Task.sleep(nanoseconds: 100_000_000)
            }
        }
        if let name = environment["NULLMERE_REBUILT_NAME"], !name.isEmpty {
            await wait { session.phase != .opening }
            if session.phase == .naming { await session.join(name: name) }
        }
        guard let what = environment["NULLMERE_REBUILT_SHOW"], !what.isEmpty else { return }
        await wait { session.phase == .playing }
        guard let home = session.world.city?.hex else { return }
        func nearest(_ hexes: [LiveHex]) -> LiveHex? { hexes.min { $0.distance(to: home) < $1.distance(to: home) } }
        switch what {
        case "city":
            session.selected = home
            show(.city)
        case "troops":
            session.selected = home
            show(.troops)
        case "reports":
            show(.reports)
        case "barrow":
            if let hex = nearest(session.world.barrows.values.map(\.hex)) {
                session.go(to: hex)
                session.selected = hex
            }
        case "site":
            if let hex = nearest(session.world.sites.values.map(\.hex)) {
                session.go(to: hex)
                session.selected = hex
            }
        default: break
        }
    }
    #endif
}

/// A plain notice in the middle of the window, with one thing to do
/// about it where there is one.
struct LiveNotice: View {
    let title: String
    let words: String
    let button: String?
    let action: () -> Void

    var body: some View {
        VStack(spacing: 12) {
            Caps(title, size: 12, weight: .medium, centred: true)
                .foregroundStyle(Palette.ink)
            Text(verbatim: words)
                .font(.nm(13))
                .foregroundStyle(Palette.text(0.75))
            if let button {
                QuietButton(title: button, prominent: true, action: action)
            }
        }
        .padding(24)
        .panelBackground()
    }
}

/// Asks who the player will be in the realm.
struct LiveNameCard: View {
    let session: LiveSession
    @State private var name = ""
    @FocusState private var focused: Bool

    /// Whether the realm would take the name as it stands: three to
    /// sixteen letters once tidied. The realm has the last word.
    static func fits(_ name: String) -> Bool {
        let tidy = name.split(separator: " ").joined(separator: " ")
        return (3...16).contains(tidy.count)
    }

    var body: some View {
        VStack(spacing: 14) {
            Caps("Your name in the realm", size: 12, weight: .medium, centred: true)
                .foregroundStyle(Palette.ink)
            TextField("Three to sixteen letters", text: $name)
                .textFieldStyle(.plain)
                .font(.nm(16))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.ink)
                .focused($focused)
                .frame(width: 260)
                .padding(.vertical, 6)
                .overlay(alignment: .bottom) {
                    Rectangle().fill(Palette.line(focused ? 0.7 : 0.35)).frame(height: 1)
                }
                .onSubmit(join)
                .accessibilityLabel("Your name in the realm")
            if let said = session.said {
                Text(verbatim: said)
                    .font(.nm(12))
                    .foregroundStyle(Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
            }
            QuietButton(title: "Found your city", prominent: true, enabled: Self.fits(name) && session.asking == 0,
                        why: "A name needs at least 3 letters and at most 16.", action: join)
        }
        .padding(24)
        .frame(width: 340)
        .panelBackground()
        .onAppear { focused = true }
    }

    private func join() {
        guard Self.fits(name) else { return }
        session.said = nil
        Task { await session.join(name: name) }
    }
}

/// What lies over the world while it is played.
struct LiveHUD: View {
    let session: LiveSession
    @Binding var panel: LiveGameView.Panel?

    var body: some View {
        // Counted afresh each second: goods grow and timers run down
        // between the realm's own words.
        TimelineView(.periodic(from: .now, by: 1)) { _ in
            let seconds = session.now
            HStack(alignment: .top, spacing: 12) {
                VStack(spacing: 10) {
                    LiveTopBar(session: session, seconds: seconds)
                    HStack(alignment: .top, spacing: 12) {
                        LiveTaskChip(session: session)
                        Spacer(minLength: 0)
                    }
                    if let said = session.said {
                        LiveSaid(words: said) { session.said = nil }
                    }
                    Spacer(minLength: 0)
                    HStack(alignment: .bottom, spacing: 12) {
                        LiveArmies(session: session, seconds: seconds)
                        Spacer(minLength: 0)
                        LiveDock(session: session, panel: $panel)
                    }
                    if let selection = session.selection {
                        LiveCardView(session: session, card: session.card(for: selection), panel: $panel)
                    }
                }
                if let panel {
                    LiveSidePanel(session: session, seconds: seconds, panel: panel) { self.panel = nil }
                }
            }
            .padding(12)
        }
    }
}

/// Along the top: whose city, its goods as they stand this second, and
/// the player's energy.
struct LiveTopBar: View {
    let session: LiveSession
    let seconds: Double

    private static let stores: [Resource] = [.grain, .timber, .stone, .moonsalt]

    var body: some View {
        HStack(spacing: 14) {
            if let city = session.world.city {
                Button {
                    session.go(to: city.hex)
                    session.selected = city.hex
                } label: {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: city.name)
                            .font(.nm(13, weight: .medium))
                            .foregroundStyle(Palette.ink)
                        Text(verbatim: "Keep \(city.keep) · Power \(LiveWords.grouped(city.power))")
                            .font(.nm(11))
                            .foregroundStyle(Palette.text(0.7))
                    }
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\(city.name), your city: go to it")
            }
            Spacer(minLength: 0)
            if let stock = session.world.stock {
                let goods = stock.goods(at: seconds).parts
                ForEach(Array(Self.stores.enumerated()), id: \.offset) { index, store in
                    HStack(spacing: 5) {
                        ResourceGlyph(resource: store, size: 11)
                        Text(verbatim: LiveWords.grouped(goods[index]))
                            .font(.nm(12, weight: .medium))
                            .monospacedDigit()
                            .foregroundStyle(goods[index] >= stock.holds ? Palette.bad : Palette.ink)
                    }
                    .accessibilityElement(children: .ignore)
                    .accessibilityLabel("\(LiveWords.grouped(goods[index])) \(LiveWords.goods[index])")
                }
            }
            if let hunt = session.world.hunt {
                Text(verbatim: "Energy \(LiveWords.grouped(UInt64(hunt.energy(at: seconds))))")
                    .font(.nm(12))
                    .monospacedDigit()
                    .foregroundStyle(Palette.text(0.8))
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .panelBackground()
    }
}

/// The task the player is on: what it asks, what it gives, and a way to
/// claim it once it is done.
struct LiveTaskChip: View {
    let session: LiveSession

    var body: some View {
        if let task = session.world.task {
            let done = session.world.isDone(task)
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: task.words)
                        .font(.nm(12, weight: .medium))
                        .foregroundStyle(Palette.ink)
                    Text(verbatim: "Gives \(task.gives.words).")
                        .font(.nm(11))
                        .foregroundStyle(Palette.text(0.7))
                }
                QuietButton(title: "Claim", prominent: done, enabled: done && session.asking == 0, name: "Claim what the task gives",
                            why: "Not done yet: \(task.words)") {
                    Task { await session.claimTask() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .panelBackground()
            .accessibilityElement(children: .contain)
        }
    }
}

/// The doors to everything that is not the world: each opens a side of
/// the window, or closes it again.
struct LiveDock: View {
    struct Door: Identifiable {
        let title: String
        let panel: LiveGameView.Panel
        var id: String { title }
    }

    static let doors = [Door(title: "Buildings", panel: .city), Door(title: "Troops", panel: .troops), Door(title: "Studies", panel: .studies),
                        Door(title: "Alliance", panel: .alliance), Door(title: "Chat", panel: .chat), Door(title: "Reports", panel: .reports)]

    let session: LiveSession
    @Binding var panel: LiveGameView.Panel?

    var body: some View {
        HStack(spacing: 2) {
            ForEach(Self.doors) { door in
                let unread = door.panel == .reports ? session.world.unread : 0
                QuietButton(title: unread > 0 ? "\(door.title) \(unread)" : door.title, prominent: panel == door.panel || unread > 0,
                            name: unread > 0 ? "\(door.title), \(unread) unread" : door.title) {
                    panel = panel == door.panel ? nil : door.panel
                }
            }
        }
        .padding(4)
        .panelBackground()
    }
}

/// What the realm last would not do, in its own words, until put away.
struct LiveSaid: View {
    let words: String
    let dismiss: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Text(verbatim: words)
                .font(.nm(12))
                .foregroundStyle(Palette.bad)
                .fixedSize(horizontal: false, vertical: true)
            QuietButton(title: "Close", action: dismiss)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .panelBackground()
        .accessibilityElement(children: .contain)
    }
}

/// The player's armies out of the city: what each is doing and how long
/// it has to go. Pressing one turns the view to it.
struct LiveArmies: View {
    let session: LiveSession
    let seconds: Double

    var body: some View {
        let lines = session.world.marchLines()
        if !lines.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(lines) { line in
                    Button {
                        let place = line.march.stands ? line.march.to : (line.march.route.last ?? line.march.to)
                        session.go(to: place)
                        session.selected = place
                    } label: {
                        HStack(spacing: 8) {
                            Text(verbatim: line.doing)
                                .font(.nm(12))
                                .foregroundStyle(Palette.ink)
                            Text(verbatim: LiveWords.clock(line.march.arrives - Int(seconds)))
                                .font(.nm(12, weight: .medium))
                                .monospacedDigit()
                                .foregroundStyle(Palette.glowWords)
                        }
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .panelBackground()
        }
    }
}

/// The card for what is chosen: its name, a few lines, and what can be
/// done about it.
struct LiveCardView: View {
    let session: LiveSession
    let card: LiveCard
    @Binding var panel: LiveGameView.Panel?

    var body: some View {
        HStack(alignment: .center, spacing: 16) {
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: card.title)
                    .font(.nm(14, weight: .medium))
                    .foregroundStyle(Palette.ink)
                ForEach(card.lines, id: \.self) { line in
                    Text(verbatim: line)
                        .font(.nm(12))
                        .foregroundStyle(Palette.text(0.78))
                        .fixedSize(horizontal: false, vertical: true)
                }
                // Why the first thing that can't be done can't be.
                if let why = card.buttons.compactMap(\.why).first {
                    Text(verbatim: why)
                        .font(.nm(11))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            Spacer(minLength: 0)
            ForEach(card.buttons, id: \.title) { button in
                QuietButton(title: button.title, prominent: true, enabled: button.why == nil && session.asking == 0, why: button.why) {
                    press(button)
                }
            }
            QuietButton(title: "Close") { session.selected = nil }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .frame(maxWidth: 640)
        .panelBackground()
    }

    /// Does what a button says: opens a side of the window, or asks the
    /// realm.
    private func press(_ button: LiveCard.Button) {
        let act = button.act
        if act == .city {
            panel = .city
        } else if act == .troops {
            panel = .troops
        } else {
            Task { await session.press(button) }
        }
    }
}
