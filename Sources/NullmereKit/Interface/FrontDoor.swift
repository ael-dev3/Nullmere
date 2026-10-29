import AppKit
import LauncherKit
import NullmereCore
import SwiftUI

/// The realm's front door, on the moonlit lake: the name of the game, who
/// you are on the lake, how the realm stands, and the way in.
struct FrontDoor: View {
    let app: GameApp

    @State private var name: String
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    /// `name` begins the name field: empty at the door, a name already
    /// written where one is given.
    init(app: GameApp, name: String = "") {
        self.app = app
        _name = State(initialValue: name)
    }

    var body: some View {
        ZStack {
            MoonlitLake()
                .ignoresSafeArea()
            // Darken the water beneath the card, as the launcher's panels and
            // the gate do, so the moon's reflection doesn't glow through it.
            EllipticalGradient(
                colors: [.black.opacity(0.8), .black.opacity(0.5), .clear],
                center: UnitPoint(x: 0.5, y: 0.7),
                startRadiusFraction: 0,
                endRadiusFraction: 0.55
            )
            .ignoresSafeArea()
            .allowsHitTesting(false)

            GeometryReader { proxy in
                // The name rests where the launcher sets it, to the point, so it
                // doesn't move as the keeper steps from one to the other.
                LakeTitle(size: proxy.size, isRevealed: appeared)
                    .animation(.easeOut(duration: 0.9), value: appeared)
                VStack(spacing: 0) {
                    // Below the waterline where there's room; where there
                    // isn't (a small window, larger text, a note or a
                    // problem to tell), the card rises rather than its
                    // buttons run off the window.
                    Spacer(minLength: 0)
                        .frame(minHeight: 24, maxHeight: LakeTitle.waterline(for: proxy.size) + 8)
                    VStack(alignment: .leading, spacing: 18) {
                        RealmLine(door: app.door)
                        Rule(opacity: 0.25)
                        keeper
                        if let note = seatNote {
                            Text(verbatim: note)
                                .font(.nm(11))
                                .foregroundStyle(Palette.text(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let problem = app.arrivalProblem {
                            Text(verbatim: problem)
                                .font(.nm(11))
                                .foregroundStyle(Palette.bad)
                                .fixedSize(horizontal: false, vertical: true)
                                .accessibilityLabel("Problem: \(problem)")
                        }
                        HStack(spacing: 10) {
                            QuietButton(title: enterTitle, size: 11, prominent: true,
                                        enabled: app.canEnter(with: name)) {
                                app.enterWorld(name: name)
                            }
                            .keyboardShortcut(.defaultAction)
                            if case .unreachable = app.door {
                                QuietButton(title: "Try again", size: 11) { app.openDoor() }
                            }
                            Spacer()
                            QuietButton(title: "Back", size: 11) { app.leaveDoor() }
                                .keyboardShortcut(.cancelAction)
                        }
                    }
                    .padding(26)
                    .frame(width: 460)
                    .panelBackground()
                    // The note on identity goes first when room is short.
                    ViewThatFits(in: .vertical) {
                        Text(verbatim: "Your identity is a random key kept in this Mac's keychain. The realm knows you by it and by the name you choose; nothing else.")
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.45))
                            .multilineTextAlignment(.center)
                            .frame(width: 420)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 14)
                        Color.clear.frame(height: 0)
                    }
                    Spacer(minLength: 16)
                }
                .frame(width: proxy.size.width)
            }
            // Measured over the whole window, title bar and all, as the
            // launcher measures it, so the title rests at the same height.
            .ignoresSafeArea()
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) { appeared = true }
            nameFocused = app.keeperName == nil
        }
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

    /// The door's state worth saying aloud when it changes: out of reach,
    /// and why; nothing for the ordinary comings and goings.
    static func spokenState(of door: GameApp.Door) -> String? {
        if case .unreachable(let reason) = door { return "The realm is out of reach. \(reason)" }
        return nil
    }

    private var enterTitle: String {
        if app.isWaitingForSeat { return "Waiting for a seat…" }
        return app.isEntering ? "Entering…" : "Enter the world"
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

    @ViewBuilder
    private var keeper: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caps("Keeper", size: 8.5, weight: .medium).foregroundStyle(Palette.text(0.6))
            if let known = app.keeperName {
                Text(verbatim: "You are known here as \(known), of House \(known).")
                    .font(.nm(13, weight: .light))
                    .foregroundStyle(Palette.text(0.9))
            } else {
                TextField("The name you'll go by", text: $name)
                    .textFieldStyle(.plain)
                    .font(.nm(14, weight: .light))
                    .foregroundStyle(Palette.ink)
                    .focused($nameFocused)
                    .padding(.vertical, 6)
                    .overlay(alignment: .bottom) { Rule(opacity: 0.35) }
                    .onSubmit { app.enterWorld(name: name) }
                    .accessibilityLabel("Your name on the lake")
                    // What's wrong with the name, or what it must be, read
                    // with the field.
                    .accessibilityHint(RealmState.nameProblem(name) ?? "Two to twenty letters. It names you and the House you'll hold.")
                if let problem = RealmState.nameProblem(name) {
                    Text(verbatim: problem)
                        .font(.nm(10))
                        .foregroundStyle(Palette.bad)
                } else {
                    Text(verbatim: "Two to twenty letters. It names you and the House you'll hold.")
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.5))
                }
            }
        }
    }
}

/// How the realm stands: open or not, its age and watch, who is there.
struct RealmLine: View {
    let door: GameApp.Door

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Circle().fill(colour).frame(width: 6, height: 6)
                Caps(title, size: 10.5, weight: .medium).foregroundStyle(Palette.ink)
                Spacer()
                Caps(state, size: 8.5).foregroundStyle(colour)
            }
            Text(verbatim: detail)
                .font(.nm(11))
                .foregroundStyle(Palette.text(0.65))
                .fixedSize(horizontal: false, vertical: true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("\(title), \(state). \(detail)")
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

    private var colour: Color {
        switch door {
        case .connecting: return Palette.text(0.5)
        case .open: return Palette.good
        case .unreachable: return Palette.bad
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
