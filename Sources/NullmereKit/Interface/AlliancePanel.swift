import NullmereCore
import SwiftUI

/// The House among the alliances: its own and its fellows, with help to
/// give, gates to keep and rallies to join; or, sworn to none, the
/// invitations it has, the alliances it may ask, and a banner to raise.
struct AlliancePanel: View {
    let session: GameSession
    /// The name of a banner being raised.
    @State private var banner = ""

    var body: some View {
        let board = session.state.allianceBoard(for: session.player)
        let chosen = session.selectedUnit.flatMap { $0.owner == session.player && $0.kind.isMilitary ? $0 : nil }
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Alliance", subtitle: board.alliance.map { "\($0.titled) · \($0.members.count) of \(board.limit) Houses" }
                           ?? "Sworn to none")
                CloseButton(label: "Close the Alliance") { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    // The shares of the alliance's spoils waiting, first, while any wait.
                    SharesOfTheSpoils(session: session)
                    if board.alliance != nil {
                        sworn(board, chosen: chosen)
                    } else {
                        unsworn(board)
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.alliance))
        }
        .padding(16)
        .frame(width: PanelWidth.rail)
        .panelHeight()
        .panelBackground()
    }

    private func title(_ house: Int) -> String {
        session.state.houses.indices.contains(house) ? session.state.houses[house].title : "a fallen House"
    }

    /// The alliance's standards, as many as it may keep, and how to raise
    /// one, in the rules' words.
    static func standardsLine(_ alliance: Alliance, in state: GameState) -> String {
        state.standardsSaid(of: alliance)
    }

    /// The alliance's hall, in the rules' words.
    static func hallLine(_ alliance: Alliance, in state: GameState) -> String {
        state.hallSaid(of: alliance)
    }

    /// The alliance's coffers, in the rules' words.
    static func coffersLine(_ alliance: Alliance, in state: GameState) -> String {
        state.coffersSaid(of: alliance)
    }

    /// The alliance's storehouse, in the rules' words.
    static func storehouseLine(_ alliance: Alliance, in state: GameState) -> String {
        state.storehouseSaid(of: alliance)
    }

    /// The alliance's yards, in the rules' words.
    static func yardsLine(_ alliance: Alliance, in state: GameState) -> String {
        state.yardsSaid(of: alliance)
    }

    /// What a House has laid up in its alliance's storehouse, and its room.
    static func laidUpLine(_ laid: Stock) -> String {
        Storehouse.laidUpSaid(laid)
    }

    /// What a House lays up or takes back at a time.
    static let measures = Storehouse.measures

    // MARK: Sworn

    @ViewBuilder
    private func sworn(_ board: AllianceBoard, chosen: Unit?) -> some View {
        if let alliance = board.alliance {
            Text(verbatim: AlliancePanel.standardsLine(alliance, in: session.state))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            Text(verbatim: AlliancePanel.hallLine(alliance, in: session.state))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
            AllianceMarksList(session: session, alliance: alliance)
            AllianceStores(session: session, alliance: alliance)
            StudiesTogether(session: session, alliance: alliance, isLeader: board.isLeader)
            Rule(opacity: 0.18)
        }
        Caps("Its Houses", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        ForEach(board.members) { member in
            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: member.house == session.player ? "You" : title(member.house))
                        .font(.nm(11, weight: .medium))
                        .foregroundStyle(Palette.text(0.9))
                    if member.isLeader {
                        Caps("Leader", size: 8).foregroundStyle(Palette.glowWords)
                    } else if member.isOfficer {
                        Caps("Officer", size: 8).foregroundStyle(Palette.glowWords.opacity(0.8))
                    }
                    Spacer()
                    Text(verbatim: "Might \(member.might)").font(.nm(10).monospacedDigit()).foregroundStyle(Palette.text(0.55))
                }
                .accessibilityElement(children: .combine)
                if member.house != session.player {
                    HStack(spacing: 4) {
                        QuietButton(title: member.helpable > 0 ? "Help \(member.helpable)" : "Help", size: 8.5, enabled: member.helpable > 0,
                                    name: "Help \(title(member.house))'s works",
                                    why: "Nothing of theirs is under way that you haven't helped.") {
                            session.perform(.help(house: member.house))
                        }
                        if let unit = chosen, let seat = session.state.seat(of: member.house) {
                            QuietButton(title: "Keep their gates", size: 8.5,
                                        name: "Send the chosen \(CommandersPanel.named(unit)) to keep the gates of \(seat.name)") {
                                session.perform(.reinforce(unit: unit.id, hold: seat.id))
                            }
                        }
                        if board.isLeader {
                            // The leader names its officers, who keep the roll and the marks with them.
                            let naming = !member.isOfficer
                            let refusal = session.state.officerRefusal(member.house, named: naming, as: session.player)
                            QuietButton(title: naming ? "Name officer" : "Unname officer", size: 8.5, enabled: refusal == nil,
                                        name: naming ? "Name \(title(member.house)) an officer" : "Name \(title(member.house)) an officer no longer",
                                        why: refusal?.description) {
                                session.perform(.nameOfficer(house: member.house, named: naming))
                            }
                        }
                        // The leader casts out any House; an officer, any not the leader or an officer.
                        if board.isLeader || (board.isOfficer && !member.isLeader && !member.isOfficer) {
                            ConfirmButton(title: "Cast out", confirm: "Cast them out?") { session.perform(.expel(house: member.house)) }
                        }
                    }
                }
            }
        }

        if !board.asking.isEmpty {
            Rule(opacity: 0.18)
            Caps("Asking to join", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
            ForEach(board.asking, id: \.self) { house in
                HStack {
                    Text(verbatim: title(house)).font(.nm(11)).foregroundStyle(Palette.text(0.85))
                    Spacer()
                    QuietButton(title: "Admit", size: 8.5, name: "Admit \(title(house))") {
                        session.perform(.answerRequest(house: house, accept: true))
                    }
                    QuietButton(title: "Refuse", size: 8.5, name: "Refuse \(title(house))") {
                        session.perform(.answerRequest(house: house, accept: false))
                    }
                }
            }
        }

        Rule(opacity: 0.18)
        Caps("Rallies", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        if board.rallies.isEmpty {
            Text(verbatim: "None is called. Choose a hold of a House you are at war with to call one against it.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(board.rallies) { line in
            RallyRow(session: session, line: line, chosen: chosen)
        }

        if !board.invitable.isEmpty {
            Rule(opacity: 0.18)
            Caps("Invite", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
            if board.invitable.count > HouseChoice.shownWhole {
                // A realm of a thousand Houses: those the leader or an officer has reason to invite, and any other found by name.
                HouseChooser(session: session, excluding: [session.player], among: Set(board.invitable)) { house in
                    QuietButton(title: "Invite \(house.title)", size: 8.5) {
                        session.perform(.inviteToAlliance(house: house.id))
                    }
                }
            } else {
                ForEach(board.invitable, id: \.self) { house in
                    HStack {
                        Text(verbatim: title(house)).font(.nm(11)).foregroundStyle(Palette.text(0.8))
                        Spacer()
                        QuietButton(title: "Invite", size: 8.5, name: "Invite \(title(house))") {
                            session.perform(.inviteToAlliance(house: house))
                        }
                    }
                }
            }
        }

        Rule(opacity: 0.18)
        HStack {
            Spacer()
            ConfirmButton(title: "Leave the alliance", confirm: "Leave it?") { session.perform(.leaveAlliance) }
        }
    }

    // MARK: Unsworn

    @ViewBuilder
    private func unsworn(_ board: AllianceBoard) -> some View {
        if !board.invitations.isEmpty {
            Caps("Invitations", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
            ForEach(board.invitations) { alliance in
                HStack {
                    Text(verbatim: "\(alliance.titled), led by \(title(alliance.leader))")
                        .font(.nm(11))
                        .foregroundStyle(Palette.text(0.85))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer()
                    QuietButton(title: "Join", size: 8.5, name: "Join \(alliance.name)") {
                        session.perform(.answerInvitation(alliance: alliance.id, accept: true))
                    }
                    QuietButton(title: "Refuse", size: 8.5, name: "Refuse \(alliance.name)") {
                        session.perform(.answerInvitation(alliance: alliance.id, accept: false))
                    }
                }
            }
            Rule(opacity: 0.18)
        }

        Caps("Raise a banner", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        Text(verbatim: "Allies share their sight, can't make war on each other, hasten each other's works and call rallies together.")
            .font(.nm(10.5))
            .foregroundStyle(Palette.text(0.55))
            .fixedSize(horizontal: false, vertical: true)
        HStack {
            TextField("The alliance's name", text: $banner)
                .textFieldStyle(.plain)
                .font(.nm(11.5))
                .foregroundStyle(Palette.ink)
                .padding(.vertical, 4)
                .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                .onSubmit(raise)
                .accessibilityLabel("The alliance's name")
            QuietButton(title: "Raise", size: 8.5, enabled: Alliance.isValidName(banner), name: "Raise the banner",
                        why: "Two to twenty-four letters, spaces, hyphens or apostrophes.", action: raise)
                .beckoned(session.beckon == .banner)
        }

        if !board.others.isEmpty {
            Rule(opacity: 0.18)
            Caps("Alliances standing", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
            ForEach(board.others) { line in
                HStack(alignment: .firstTextBaseline) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(verbatim: line.alliance.titled).font(.nm(11, weight: .medium)).foregroundStyle(Palette.text(0.85))
                        Text(verbatim: "Led by \(title(line.alliance.leader)) · \(line.alliance.members.count) of \(board.limit) Houses")
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.5))
                    }
                    .accessibilityElement(children: .combine)
                    Spacer()
                    QuietButton(title: "Ask to join", size: 8.5, enabled: line.refusal == nil, name: "Ask to join \(line.alliance.name)",
                                why: line.refusal?.description) {
                        session.perform(.askToJoin(alliance: line.alliance.id))
                    }
                }
            }
        }
    }

    private func raise() {
        if Self.raise(banner, in: session) { banner = "" }
    }

    /// Raises a banner of that name, if the name will do; whether it was raised.
    @discardableResult
    static func raise(_ name: String, in session: GameSession) -> Bool {
        guard Alliance.isValidName(name) else { return false }
        return session.perform(.foundAlliance(name: name))
    }
}

/// A rally of the House's side: where it gathers, against what, how full,
/// and when it sets out; the chosen company sent to it.
/// The shares of the alliance's spoils waiting for the keeper's House: each
/// share's deed, the newest first, what they hold all told and Take them;
/// nothing while none waits.
struct SharesOfTheSpoils: View {
    let session: GameSession

    /// Its title: "A share of the spoils", "3 shares of the spoils".
    static func title(_ count: Int) -> String {
        count == 1 ? "A share of the spoils" : "\(count) shares of the spoils"
    }

    var body: some View {
        let state = session.state
        let shares = state.shares(of: session.player)
        if !shares.isEmpty {
            let refusal = state.takeSharesRefusal(as: session.player)
            let held = state.sharesHeldSaid(by: session.player)
            VStack(alignment: .leading, spacing: 5) {
                Caps(Self.title(shares.count), size: 9, weight: .medium)
                    .foregroundStyle(Palette.glowWords)
                    .accessibilityAddTraits(.isHeader)
                ForEach(Array(state.sharesSaid(shares).enumerated()), id: \.offset) { _, line in
                    Text(verbatim: line)
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                }
                HStack(alignment: .firstTextBaseline) {
                    Text(verbatim: held)
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.8))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 8)
                    QuietButton(title: "Take them", size: 8.5, enabled: refusal == nil, name: "Take your shares of the spoils",
                                why: refusal?.description) {
                        if session.perform(.takeShares) { session.post("Your shares taken: \(held).", tone: .good) }
                    }
                }
                .help(AllianceShare.said)
            }
            .accessibilityElement(children: .contain)
            Rule(opacity: 0.18)
        }
    }
}

private struct RallyRow: View {
    let session: GameSession
    let line: RallyLine
    let chosen: Unit?

    var body: some View {
        let state = session.state
        let rally = line.rally
        let target = state.targetName(rally.target) ?? "a hold"
        let muster = state.hold(rally.muster)?.name ?? "a hold"
        VStack(alignment: .leading, spacing: 4) {
            Text(verbatim: "Against \(target), gathering at \(muster)")
                .font(.nm(11, weight: .medium))
                .foregroundStyle(Palette.text(0.85))
                .fixedSize(horizontal: false, vertical: true)
            HStack(alignment: .firstTextBaseline) {
                Text(verbatim: AlliancePanel.when(line) + " · \(line.companies) of \(line.capacity) companies")
                    .font(.nm(10.5))
                    .foregroundStyle(rally.marching ? Palette.glowWords : Palette.text(0.6))
                Spacer()
                if let unit = chosen, !rally.marching {
                    let refusal = state.refusal(of: .joinRally(rally: rally.id, unit: unit.id), as: session.player)
                    QuietButton(title: "Send the chosen", size: 8.5, enabled: refusal == nil,
                                name: "Send the chosen \(CommandersPanel.named(unit)) to the rally against \(target)",
                                why: refusal?.description) {
                        session.perform(.joinRally(rally: rally.id, unit: unit.id))
                    }
                }
            }
        }
        .accessibilityElement(children: .contain)
    }
}

/// The ground the alliance's leader has marked for it, each in its hue as
/// the world lights it and said as the Houses' ledgers say it, with the
/// view carried there on asking; nothing while it has none.
private struct AllianceMarksList: View {
    let session: GameSession
    let alliance: Alliance

    var body: some View {
        let state = session.state
        let marks = state.marks(of: alliance.id)
        if !marks.isEmpty {
            Caps("Its marks", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
            let said = state.marksSaid(of: alliance.id)
            ForEach(Array(marks.enumerated()), id: \.element.id) { index, mark in
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Circle().fill(MarkRow.hue(mark.kind)).frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Text(verbatim: said[index])
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(0.65))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    QuietButton(title: "Look", size: 8.5, name: "Look at the alliance's mark: \(mark.kind.title)") {
                        session.glide(to: mark.at)
                    }
                }
            }
        }
    }
}

/// What the alliance keeps of its own: its coffers, its storehouse with
/// what the House has laid up there and the stores to lay up or take back,
/// and its yards.
private struct AllianceStores: View {
    let session: GameSession
    let alliance: Alliance

    var body: some View {
        let state = session.state
        Caps("Its stores", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        ForEach([AlliancePanel.coffersLine(alliance, in: state), AlliancePanel.storehouseLine(alliance, in: state),
                 AlliancePanel.yardsLine(alliance, in: state)], id: \.self) { line in
            Text(verbatim: line)
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.6))
                .fixedSize(horizontal: false, vertical: true)
        }
        if state.wholeStorehouse(for: session.player) != nil {
            let laid = state.laidUp(by: session.player)
            Text(verbatim: AlliancePanel.laidUpLine(laid))
                .font(.nm(10.5, weight: .medium))
                .foregroundStyle(Palette.text(0.8))
                .fixedSize(horizontal: false, vertical: true)
            FlowLayout(spacing: 4) {
                ForEach(AlliancePanel.measures, id: \.self) { measure in
                    let refusal = state.refusal(of: .layUp(measure), as: session.player)
                    QuietButton(title: "Lay up \(measure)", size: 8.5, enabled: refusal == nil, name: "Lay up \(measure) in the storehouse",
                                why: refusal?.description) {
                        session.perform(.layUp(measure))
                    }
                }
            }
            FlowLayout(spacing: 4) {
                ForEach(AlliancePanel.measures, id: \.self) { measure in
                    let refusal = state.refusal(of: .takeBack(measure), as: session.player)
                    QuietButton(title: "Take back \(measure)", size: 8.5, enabled: refusal == nil,
                                name: "Take back \(measure) from the storehouse", why: refusal?.description) {
                        session.perform(.takeBack(measure))
                    }
                }
                if !laid.isZero {
                    let refusal = state.refusal(of: .takeBack(laid), as: session.player)
                    QuietButton(title: "Take back all", size: 8.5, enabled: refusal == nil, name: "Take back all you laid up",
                                why: refusal?.description) {
                        session.perform(.takeBack(laid))
                    }
                }
            }
        }
        Rule(opacity: 0.18)
    }
}

/// What the alliance learns together: the study it pursues and how much of
/// its next grade its Houses have paid for, the House's gifts toward it,
/// and every study's grade, its leader choosing which to pursue.
private struct StudiesTogether: View {
    let session: GameSession
    let alliance: Alliance
    let isLeader: Bool

    var body: some View {
        let lore = alliance.lore ?? AllianceLore()
        Caps("Studies together", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7)).accessibilityAddTraits(.isHeader)
        if let next = lore.next {
            let cost = next.study.cost(grade: next.grade)
            VStack(alignment: .leading, spacing: 4) {
                Text(verbatim: "\(next.study.title) \(Narration.roman(next.grade)): \(next.study.effect(grade: next.grade))")
                    .font(.nm(11, weight: .medium))
                    .foregroundStyle(Palette.ink)
                    .fixedSize(horizontal: false, vertical: true)
                Meter(fraction: AlliancePanel.paid(lore.given, of: cost), label: "Paid for")
                Text(verbatim: "Given \(AlliancePanel.given(lore.given, of: cost)).")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .combine)
            FlowLayout(spacing: 4) {
                ForEach(AlliancePanel.gifts, id: \.self) { gift in
                    let refusal = session.state.refusal(of: .giveToAlliance(gift), as: session.player)
                    QuietButton(title: "Give \(gift)", size: 8.5, enabled: refusal == nil,
                                name: "Give \(gift) toward \(next.study.title)", why: refusal?.description) {
                        session.perform(.giveToAlliance(gift))
                    }
                }
            }
            Text(verbatim: "Every \(GameState.givenPerHourglass) given, in barter worth, brings you a Salt Hourglass.")
                .font(.nm(10))
                .foregroundStyle(Palette.text(0.5))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            Text(verbatim: isLeader ? "Choose a study below for the alliance to pursue." : "Its leader chooses what the alliance studies.")
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.55))
                .fixedSize(horizontal: false, vertical: true)
        }
        ForEach(AllianceStudy.allCases, id: \.self) { study in
            let grade = lore.grade(of: study)
            HStack(alignment: .firstTextBaseline) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(verbatim: "\(study.title) · \(grade) of \(AllianceStudy.grades)")
                        .font(.nm(10.5, weight: lore.pursuit == study ? .medium : .regular))
                        .foregroundStyle(Palette.text(grade > 0 ? 0.85 : 0.6))
                    Text(verbatim: grade > 0 ? study.effect(grade: grade) : "Not yet learned: \(study.effect(grade: 1)) at its first grade")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.5))
                        .fixedSize(horizontal: false, vertical: true)
                }
                .accessibilityElement(children: .combine)
                Spacer()
                if isLeader, grade < AllianceStudy.grades, lore.pursuit != study {
                    QuietButton(title: "Pursue", size: 8.5, name: "Pursue \(study.title)") {
                        session.perform(.pursueAllianceStudy(study))
                    }
                }
            }
        }
    }
}

extension AlliancePanel {
    /// What a House may give toward its alliance's study at a time.
    static let gifts = [Stock(grain: 50), Stock(timber: 50), Stock(stone: 50), Stock(moonsalt: 5)]

    /// How much of a grade's cost is given, by barter worth, 0 to 1.
    static func paid(_ given: Stock, of cost: Stock) -> Double {
        let owed = Resource.allCases.reduce(0) { $0 + cost[$1] * $1.worth }
        let paid = Resource.allCases.reduce(0) { $0 + min(given[$1], cost[$1]) * $1.worth }
        return owed == 0 ? 1 : Double(paid) / Double(owed)
    }

    /// What is given of a grade's cost, store by store: "40 of 160 grain, ...".
    static func given(_ given: Stock, of cost: Stock) -> String {
        Resource.allCases.filter { cost[$0] > 0 }.map { "\(min(given[$0], cost[$0])) of \(cost[$0]) \($0.title.lowercased())" }
            .joined(separator: ", ")
    }

    /// When a rally sets out, or that it has.
    static func when(_ line: RallyLine) -> String {
        if line.rally.marching { return "On the march" }
        switch line.watchesLeft {
        case 0: return "Sets out as the watch turns"
        case 1: return "Sets out next watch"
        default: return "Sets out in \(line.watchesLeft) watches"
        }
    }
}
