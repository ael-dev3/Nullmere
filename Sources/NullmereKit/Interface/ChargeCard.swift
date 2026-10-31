import NullmereCore
import SwiftUI

/// The first hour, taught in play: the charges set a House one after
/// another, each with how to keep it, a way to be shown, and its reward.
/// Raise a Granary, muster, raise an Archive and study, found a hold, set
/// a commander at a company's head, gather, hunt the wilds, swear to an
/// alliance, raise a Muster Hall, and drill a company there: every system,
/// in the order a keeper meets it.
enum ChargeGuide {
    /// How to keep a charge, in a line.
    static func how(_ charge: Charge) -> String {
        switch charge {
        case .raiseGranary:
            return "Choose your seat (H) and build a Granary: it keeps more of every store."
        case .musterCompany:
            return "At your seat, train Spears, Bows or Riders: companies of war defend, strike and gather."
        case .raiseArchive:
            return "Build an Archive at your seat. Studies are learned there, one at a time."
        case .learnStudy:
            return "Open the Archive (3) and begin a study. Close Order opens companies of the second tier."
        case .foundHold:
            return "Train Founders, march them three tiles from any hold, and found a hold there (B)."
        case .leadCompany:
            return "Choose a company of war, open Commanders (4), and set a commander at its head."
        case .gatherSite:
            return "Choose a company of war and right-click a site of the land: it gathers there and brings the stores home."
        case .huntWild:
            return "March a company of war beside a company of the wilds and strike it. The greater the wild, the richer the spoils."
        case .swearBanner:
            return "Open Alliance (5): raise a banner of your own, or ask to join one that stands."
        case .raiseMusterHall:
            return "Build your seat's Muster Hall to III: higher tiers muster there, and a captain comes to lead them."
        case .drillCompany:
            return "Choose a company of war beside your seat and Drill it: the Muster Hall drills troops into it as each watch turns while it stays."
        }
    }

    /// The advisor's words for a charge as it comes: what it is, and how.
    static func counsel(_ charge: Charge) -> String {
        "A new charge, keeper. \(charge.title). \(how(charge).replacingOccurrences(of: " (H)", with: "").replacingOccurrences(of: " (B)", with: ""))"
    }

    /// What "Show me" does for a charge: the panel it is kept in opened,
    /// or what keeps it chosen and brought into view.
    @MainActor
    static func show(_ charge: Charge, in session: GameSession) {
        let state = session.state
        let player = session.player
        let war = state.units(of: player).filter(\.kind.isMilitary).sorted { $0.id < $1.id }
        session.beckon = beckon(for: charge, in: state, player: player)
        switch charge {
        case .raiseGranary, .musterCompany, .raiseArchive, .raiseMusterHall:
            session.panel = nil
            session.focusOnSeat()
        case .learnStudy:
            session.panel = .archive
        case .foundHold:
            if let founder = state.units(of: player).first(where: { $0.kind == .founder }) {
                session.panel = nil
                session.selection = .unit(founder.id)
                session.glide(to: founder.position)
            } else {
                session.panel = nil
                session.focusOnSeat()
            }
        case .leadCompany:
            if let company = war.first {
                session.selection = .unit(company.id)
                session.glide(to: company.position)
            }
            session.panel = .commanders
        case .gatherSite:
            choose(war.first, toward: state.sitesInLand.map(\.position), in: session)
        case .huntWild:
            choose(war.first, toward: state.wildsStanding.map(\.position), in: session)
        case .swearBanner:
            session.panel = .alliance
        case .drillCompany:
            // The company of war nearest the seat, chosen where it stands.
            let seat = state.seat(of: player)?.position
            let company = seat.flatMap { home in war.min { ($0.position.distance(to: home), $0.id) < ($1.position.distance(to: home), $1.id) } }
            session.panel = nil
            if let company {
                session.selection = .unit(company.id)
                session.glide(to: company.position)
            } else {
                session.focusOnSeat()
            }
        }
        // Said, for those who can't see where the ring went.
        AccessibilityNotification.Announcement(how(charge)).post()
    }

    /// The control Show me rings for a charge, if one keeps it.
    static func beckon(for charge: Charge, in state: GameState, player: Int) -> GameSession.Beckon? {
        switch charge {
        case .raiseGranary: return .work(.granary)
        case .musterCompany: return .train(nil)
        case .raiseArchive: return .work(.archive)
        case .learnStudy: return .study
        case .foundHold:
            return state.units(of: player).contains { $0.kind == .founder } ? .found : .train(.founder)
        case .leadCompany: return .lead
        case .gatherSite, .huntWild: return nil
        case .swearBanner: return .banner
        case .raiseMusterHall: return .work(.musterHall)
        case .drillCompany: return .drill
        }
    }

    /// Chooses a company and carries the view to the nearest of some places
    /// from it: a site to gather, a company of the wilds to strike.
    @MainActor
    private static func choose(_ company: Unit?, toward places: [Hex], in session: GameSession) {
        guard let company else {
            session.focusOnSeat()
            return
        }
        session.selection = .unit(company.id)
        let nearest = places.min { $0.distance(to: company.position) < $1.distance(to: company.position) }
        session.glide(to: nearest ?? company.position)
    }
}

/// The charge before the House, in the corner, as the first steps give way:
/// what it is, in a line, and Show me; how to keep it and what it brings
/// when the keeper asks for more. The advisor says it all as it comes.
struct ChargeCard: View {
    let session: GameSession

    @AppStorage("charges.hidden") private var hidden = false
    /// Whether the keeper asked for more than the charge's name.
    @AppStorage("charges.open") private var open = false

    var body: some View {
        let board = session.state.realmBoard(for: session.player)
        if !hidden, let charge = board.charge {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .center, spacing: 6) {
                    Caps("Charge \(board.chargesKept + 1) of \(Charge.allCases.count)", size: 8, weight: .medium)
                        .foregroundStyle(Palette.glowWords)
                    Spacer()
                    QuietButton(title: "Show me", size: 8.5, name: "Show me how to \(charge.title.lowercased())") {
                        ChargeGuide.show(charge, in: session)
                    }
                    QuietButton(title: open ? "Less" : "More", size: 8.5, name: open ? "Less of this charge" : "More of this charge") {
                        withAnimation(.easeOut(duration: 0.2)) { open.toggle() }
                    }
                    CloseButton(label: "Hide the charges") { withAnimation(.easeOut(duration: 0.2)) { hidden = true } }
                        .help("Hide the charges")
                }
                Text(verbatim: charge.title)
                    .font(.nm(12, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                    .help(ChargeGuide.how(charge))
                if open {
                    Text(verbatim: ChargeGuide.how(charge))
                        .font(.nm(11, weight: .light))
                        .foregroundStyle(Palette.text(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                        .transition(.opacity)
                    HStack(spacing: 8) {
                        Caps("Reward", size: 8).foregroundStyle(Palette.text(0.5))
                        CostLine(cost: charge.reward, available: Stock(grain: .max, timber: .max, stone: .max, moonsalt: .max))
                        Spacer()
                    }
                    .transition(.opacity)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .frame(width: 330, alignment: .leading)
            .panelBackground()
            .id(charge)
            .transition(.opacity)
            .accessibilityElement(children: .contain)
            .accessibilityLabel("Charge \(board.chargesKept + 1) of \(Charge.allCases.count)")
        }
    }
}

/// The ring Show me puts round what keeps a charge: pulsing gently, or
/// still where motion is reduced. Only a mark, never a control.
struct BeckonRing: View {
    @Environment(\.worldMotion) private var motion
    @State private var lit = false

    var body: some View {
        RoundedRectangle(cornerRadius: 3)
            .strokeBorder(Palette.glow.opacity(lit ? 0.95 : 0.45), lineWidth: 1.5)
            .padding(-3)
            .allowsHitTesting(false)
            .accessibilityHidden(true)
            .onAppear {
                guard motion == .full else {
                    lit = true
                    return
                }
                withAnimation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true)) { lit = true }
            }
    }
}

extension View {
    /// Rings the view while Show me points at it.
    func beckoned(_ shown: Bool) -> some View {
        overlay { if shown { BeckonRing() } }
    }
}

/// Every panel, at hand in the corner and nowhere else: each opens and
/// closes as its key (1 to 7, ? for the Guide) does; and the small map of
/// the lake, shown only when asked for.
struct PanelRail: View {
    let session: GameSession

    static let panels: [(title: String, panel: GameSession.Panel, key: String)] = [
        ("Houses", .houses, "1"), ("Chronicle", .chronicle, "2"), ("Archive", .archive, "3"), ("Commanders", .commanders, "4"),
        ("Alliance", .alliance, "5"), ("Realm", .realm, "6"), ("Words", .words, "7"), ("Guide", .guide, "?"),
    ]

    /// Whether the small map of the lake is shown: not until asked for.
    @AppStorage(MiniMap.shownKey) private var mapShown = false

    var body: some View {
        // Two short rows, not one long one: beside a hold's panel in the
        // narrowest window there is room for no more.
        VStack(alignment: .trailing, spacing: 0) {
            HStack(spacing: 2) {
                buttons(Self.panels.prefix(4))
            }
            HStack(spacing: 2) {
                buttons(Self.panels.dropFirst(4))
                Rectangle().fill(Palette.line(0.2)).frame(width: 1, height: 14).padding(.horizontal, 4)
                    .accessibilityHidden(true)
                QuietButton(title: "Map", size: 9, prominent: mapShown, name: mapShown ? "Hide the map of the lake" : "Show the map of the lake") {
                    withAnimation(.easeOut(duration: 0.2)) { mapShown.toggle() }
                }
                .help(mapShown ? "Hide the map of the lake" : "Show the map of the lake")
            }
        }
        .padding(.horizontal, 6)
        .padding(.vertical, 4)
        .background(Palette.panel, in: RoundedRectangle(cornerRadius: 3))
        .accessibilityElement(children: .contain)
        .accessibilityLabel("Panels")
    }

    private func buttons(_ items: ArraySlice<(title: String, panel: GameSession.Panel, key: String)>) -> some View {
        ForEach(items, id: \.key) { item in
            let unread = item.panel == .words ? session.unreadWords : 0
            let vote = item.panel == .houses && session.voteAwaits
            QuietButton(title: item.title, size: 9, prominent: session.panel == item.panel || unread > 0 || vote,
                        name: unread > 0 ? "\(item.title), \(unread) unread" : vote ? "\(item.title), an edict awaits your vote" : nil) {
                withAnimation(.easeOut(duration: 0.2)) {
                    session.panel = session.panel == item.panel ? nil : item.panel
                }
            }
            .help("\(item.title) (\(item.key))")
            // Words said since the keeper last read them; an edict to vote on.
            if unread > 0 {
                Text(verbatim: "\(unread)")
                    .font(.nm(8.5, weight: .medium).monospacedDigit())
                    .foregroundStyle(Palette.glowWords)
                    .accessibilityHidden(true)
            } else if vote {
                Text(verbatim: "•")
                    .font(.nm(8.5, weight: .medium))
                    .foregroundStyle(Palette.glowWords)
                    .accessibilityHidden(true)
            }
        }
    }
}
