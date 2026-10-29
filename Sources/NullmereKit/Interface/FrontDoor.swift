import AppKit
import LauncherKit
import NullmereCore
import SwiftUI

/// The realm's front door, set on the moonlit lake as the launcher sets its
/// panels: the name of the game above the far shore and, on the water below
/// it, the realm and how it stands, who you are there, and the way in.
struct FrontDoor: View {
    let app: GameApp

    @State private var name: String
    @State private var appeared = false
    /// The lit choice, the one Return performs.
    @State private var selection = 0
    @FocusState private var nameFocused: Bool
    /// The choice with keyboard focus, when keyboard navigation is on: the
    /// lit choice follows it, and it the lit choice, as in the launcher.
    @FocusState private var focusedChoice: Int?

    /// `name` begins the name field: empty at the door, a name already
    /// written where one is given.
    init(app: GameApp, name: String = "") {
        self.app = app
        _name = State(initialValue: name)
    }

    /// A choice the door offers, in the order it shows them.
    private struct Choice {
        let title: String
        var enabled = true
        let hint: String
        let perform: () -> Void
    }

    private var choices: [Choice] {
        var choices = [Choice(title: enterTitle, enabled: app.canEnter(with: name), hint: enterHint) {
            app.enterWorld(name: name)
        }]
        if isOutOfReach {
            choices.append(Choice(title: "Try again", hint: "Reaches for the realm again") { app.openDoor() })
        }
        choices.append(Choice(title: "Back", hint: "Returns to the launcher") { app.leaveDoor() })
        return choices
    }

    var body: some View {
        let choices = self.choices
        GeometryReader { proxy in
            let unit = LakeTitle.unit(for: proxy.size)
            let waterline = LakeTitle.waterline(for: proxy.size)
            ZStack(alignment: .top) {
                MoonlitLake(settings: app.displaySettings)
                // Below the waterline only, as the launcher darkens the water
                // under a panel: the sky and the title stay as bright as ever.
                PanelScrim()
                    .padding(.top, waterline)
                    .allowsHitTesting(false)
                // The name rests where the launcher sets it, to the point, so
                // it doesn't move as the keeper steps from one to the other.
                LakeTitle(size: proxy.size, isRevealed: appeared)
                VStack(spacing: 0) {
                    // At the depth the launcher's panels lie where there's
                    // room; where there isn't (a small window, larger text,
                    // a note or a problem to tell), the door rises rather
                    // than its choices run off the window.
                    Spacer(minLength: 0)
                        .frame(minHeight: 24, maxHeight: waterline + 34 * unit)
                    door(choices, unit: unit)
                    Spacer(minLength: 16)
                }
                .frame(width: proxy.size.width)
            }
            .frame(width: proxy.size.width, height: proxy.size.height)
            .environment(\.launcherUnit, unit)
        }
        // Measured over the whole window, title bar and all, as the
        // launcher measures it, so the title rests at the same height.
        .ignoresSafeArea()
        // Return performs the lit choice; Esc goes back; the arrows move
        // along the choices, as in the launcher. In the name field, Return
        // is the field's own, and the arrows move through the name.
        .background {
            if !nameFocused {
                Button("") { perform(selection, of: choices) }
                    .keyboardShortcut(.defaultAction)
                    .opacity(0)
                    .allowsHitTesting(false)
                    .accessibilityHidden(true)
            }
            Button("") { app.leaveDoor() }
                .keyboardShortcut(.cancelAction)
                .opacity(0)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
        .focusable()
        .focusEffectDisabled()
        .modifier(ChoiceArrows(lit: $selection, count: choices.count))
        .onAppear {
            // As the launcher's title shows when its opening is past.
            withAnimation(.easeOut(duration: LakeTitle.revealSeconds)) { appeared = true }
            nameFocused = app.keeperName == nil
        }
        // Writing a name means to enter with it: Enter is lit again. Out of
        // reach, Try again is lit, the one way forward; Enter again once
        // the realm answers.
        .onChange(of: name) { _, _ in selection = 0 }
        .onChange(of: isOutOfReach, initial: true) { _, out in selection = out ? 1 : 0 }
        .onChange(of: focusedChoice) { _, choice in if let choice { selection = choice } }
        .onChange(of: selection) { _, choice in if focusedChoice != nil { focusedChoice = choice } }
        // What the door has to tell, said as it changes: a problem at the
        // door, the realm out of reach, the wait for a seat.
        .onChange(of: app.arrivalProblem) { _, problem in
            if let problem { AccessibilityNotification.Announcement(problem).post() }
        }
        .onChange(of: Self.spokenState(of: app.door)) { _, words in
            if let words { AccessibilityNotification.Announcement(words).post() }
        }
        .onChange(of: app.isWaitingForSeat) { _, waiting in
            if waiting, let note = seatNote { AccessibilityNotification.Announcement(note).post() }
        }
    }

    /// Everything on the water, centred under the title as the launcher's
    /// panels are.
    private func door(_ choices: [Choice], unit: CGFloat) -> some View {
        VStack(spacing: 0) {
            RealmLine(door: app.door)

            keeper(unit: unit)
                .padding(.top, 26 * unit)

            if let note = seatNote {
                Text(verbatim: note)
                    .font(.system(size: .launcherType(11, unit: unit), weight: .light))
                    .lineSpacing(4 * unit)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.text(0.72))
                    .frame(maxWidth: 460 * unit)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 16 * unit)
            }
            if let problem = app.arrivalProblem {
                Text(verbatim: problem)
                    .font(.system(size: .launcherType(11, unit: unit), weight: .regular))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.bad)
                    .frame(maxWidth: 460 * unit)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 14 * unit)
                    .accessibilityLabel("Problem: \(problem)")
            }

            // One choice is lit at a time, and it is the one Return performs:
            // the pointer chooses by resting on a word, the arrows by moving.
            HStack(spacing: 48 * unit) {
                ForEach(choices.indices, id: \.self) { index in
                    MenuButton(title: choices[index].title, isSelected: index == min(selection, choices.count - 1),
                               enabled: choices[index].enabled) {
                        perform(index, of: choices)
                    }
                    .focused($focusedChoice, equals: index)
                    .onPointer { inside in
                        if inside { selection = index }
                    }
                    .accessibilityHint(choices[index].hint)
                }
            }
            .padding(.top, 24 * unit)

            // The note on identity goes first when room is short.
            ViewThatFits(in: .vertical) {
                Text(verbatim: "Your identity is a random key kept in this Mac's keychain. The realm knows you by it and by the name you choose; nothing else.")
                    .font(.system(size: .launcherType(10, unit: unit), weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.text(0.5))
                    .frame(maxWidth: 420 * unit)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.top, 22 * unit)
                Color.clear.frame(height: 0)
            }
        }
        .padding(.horizontal, 24)
    }

    private func perform(_ index: Int, of choices: [Choice]) {
        let index = min(index, choices.count - 1)
        guard choices.indices.contains(index), choices[index].enabled else { return }
        choices[index].perform()
    }

    /// The door's state worth saying aloud when it changes: out of reach,
    /// and why; nothing for the ordinary comings and goings.
    static func spokenState(of door: GameApp.Door) -> String? {
        if case .unreachable(let reason) = door { return "The realm is out of reach. \(reason)" }
        return nil
    }

    private var isOutOfReach: Bool {
        if case .unreachable = app.door { return true }
        return false
    }

    private var enterTitle: String {
        if app.isWaitingForSeat { return "Waiting for a seat…" }
        return app.isEntering ? "Entering…" : "Enter the world"
    }

    private var enterHint: String {
        if app.keeperName != nil { return "Takes up your seat in the realm" }
        return "Takes a seat in the realm under the name you wrote"
    }

    /// When no seat is open: why, and what waiting means.
    private var seatNote: String? {
        if app.isWaitingForSeat {
            return "\(Self.noSeatOpen) Stay at the door: you'll step in the moment one opens. A seat left a week goes to whoever waits."
        }
        if case .open(let status) = app.door, status.freeSeats == 0, !status.isEnding {
            return "\(Self.noSeatOpen) Enter to wait for the next to open."
        }
        return nil
    }

    /// Why no seat is open: each House is a keeper's, sworn to another, or
    /// leading or near the end of the age, which no newcomer may take up.
    static let noSeatOpen = "No seat is open now: every House is held by a keeper, sworn to another, or leading the lake or near winning it."

    /// Who you are on the lake: the name the realm knows you by, or the
    /// field to write one in, on a hairline as the launcher underlines.
    @ViewBuilder
    private func keeper(unit: CGFloat) -> some View {
        if let known = app.keeperName {
            Text(verbatim: "You are known here as \(known), of House \(known).")
                .font(.system(size: .launcherType(14, unit: unit), weight: .light))
                .multilineTextAlignment(.center)
                .foregroundStyle(Palette.text(0.9))
                .fixedSize(horizontal: false, vertical: true)
        } else {
            VStack(spacing: 10 * unit) {
                TextField("The name you'll go by", text: $name)
                    .textFieldStyle(.plain)
                    .font(.system(size: .launcherType(16, unit: unit), weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.ink)
                    .focused($nameFocused)
                    .padding(.vertical, 6 * unit)
                    .frame(width: 320 * unit)
                    .overlay(alignment: .bottom) { Underline(opacity: nameFocused ? 0.75 : 0.4) }
                    .onSubmit { app.enterWorld(name: name) }
                    .accessibilityLabel("Your name on the lake")
                    // What's wrong with the name, or what it must be, read
                    // with the field.
                    .accessibilityHint(RealmState.nameProblem(name) ?? Self.nameRule)
                Text(verbatim: RealmState.nameProblem(name) ?? Self.nameRule)
                    .font(.system(size: .launcherType(10, unit: unit), weight: .light))
                    .multilineTextAlignment(.center)
                    .foregroundStyle(RealmState.nameProblem(name) == nil ? Palette.text(0.55) : Palette.bad)
                    .fixedSize(horizontal: false, vertical: true)
                    .accessibilityHidden(true)
            }
        }
    }

    private static let nameRule = "Two to twenty letters. It names you and the House you'll hold."
}

/// The realm's name as the launcher heads a panel, and how it stands beneath:
/// lit when open, its age and watch, who is there.
struct RealmLine: View {
    let door: GameApp.Door

    @Environment(\.launcherUnit) private var unit

    var body: some View {
        VStack(spacing: 0) {
            PanelHeader(title: title)
            VStack(spacing: 12 * unit) {
                HStack(spacing: 8 * unit) {
                    StatusDot(isLit: isOpen)
                    SpacedText(state, size: .launcherType(9, unit: unit), weight: .regular, tracking: 0.3)
                        .foregroundStyle(Palette.text(isOpen ? 0.72 : 0.55))
                }
                Text(verbatim: detail)
                    .font(.system(size: .launcherType(13, unit: unit), weight: .light))
                    .lineSpacing(6 * unit)
                    .multilineTextAlignment(.center)
                    .foregroundStyle(Palette.text(0.68))
                    .frame(maxWidth: 460 * unit)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel("\(state). \(detail)")
        }
    }

    private var isOpen: Bool {
        if case .open = door { return true }
        return false
    }

    private var title: String {
        if case .open(let status) = door { return status.name }
        return GameApp.realmName
    }

    private var state: String {
        switch door {
        case .connecting: return "Reaching it…"
        case .open: return "Open"
        case .unreachable: return "Out of reach"
        }
    }

    private var detail: String {
        switch door {
        case .connecting:
            return "Reaching across the water for the realm."
        case .unreachable(let reason):
            return reason
        case .open(let status):
            return RealmLine.describe(status)
        }
    }

    static func describe(_ status: RealmStatus) -> String {
        let there = status.online == 1 ? "1 keeper there" : "\(status.online) keepers there"
        let seats = status.freeSeats == 1 ? "1 seat open" : "\(status.freeSeats) seats open"
        let ending = status.isEnding ? " The age has ended; the next begins when the watch turns." : ""
        let names = present(status).map { " \($0)" } ?? ""
        let age = status.lake.map { "Age \(status.age) on \($0)" } ?? "Age \(status.age)"
        return "\(age), watch \(status.watch) · \(there) · \(seats) of \(status.seats).\(names)\(ending)"
    }

    /// "There now: Ama, Bel and 3 more."
    static func present(_ status: RealmStatus, shown: Int = 5) -> String? {
        guard let names = status.present, !names.isEmpty else { return nil }
        let first = names.prefix(shown)
        let more = status.online - first.count
        if more > 0 {
            return "There now: \(first.joined(separator: ", ")) and \(more) more."
        }
        if first.count == 1 { return "There now: \(first[0])." }
        return "There now: \(first.dropLast().joined(separator: ", ")) and \(first.last!)."
    }
}
