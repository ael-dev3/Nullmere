import AppKit
import LauncherKit
import NullmereCore
import SwiftUI

/// The realm's front door, on the moonlit lake: the name of the game, who
/// you are on the lake, how the realm stands, and the way in.
struct FrontDoor: View {
    let app: GameApp

    @State private var name = ""
    @State private var appeared = false
    @FocusState private var nameFocused: Bool

    var body: some View {
        ZStack {
            MoonlitLake()
                .ignoresSafeArea()
            LinearGradient(colors: [.clear, .black.opacity(0.55)], startPoint: .center, endPoint: .bottom)
                .ignoresSafeArea()
                .allowsHitTesting(false)

            GeometryReader { proxy in
                VStack(spacing: 0) {
                    // The name rests below the moon, above the far shore, as on
                    // the launcher.
                    Spacer(minLength: 0)
                        .frame(height: proxy.size.height * 0.3)
                    Wordmark(appeared: appeared)
                    Spacer(minLength: 28)
                    VStack(alignment: .leading, spacing: 18) {
                        RealmLine(door: app.door)
                        Rule(opacity: 0.25)
                        keeper
                        if let note = seatNote {
                            Text(verbatim: note)
                                .font(.nm(11))
                                .foregroundStyle(Palette.ink.opacity(0.75))
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        if let problem = app.arrivalProblem {
                            Text(verbatim: problem)
                                .font(.nm(11))
                                .foregroundStyle(Palette.bad)
                                .fixedSize(horizontal: false, vertical: true)
                        }
                        HStack(spacing: 10) {
                            QuietButton(title: enterTitle, size: 11, prominent: true,
                                        enabled: app.canEnter(with: name)) {
                                app.enterWorld(name: name)
                            }
                            .keyboardShortcut(.defaultAction)
                            if case .unreachable = app.door {
                                QuietButton(title: "Try Again", size: 11) { app.openDoor() }
                            }
                            Spacer()
                            QuietButton(title: "Back", size: 11) { app.leaveDoor() }
                                .keyboardShortcut(.cancelAction)
                        }
                    }
                    .padding(26)
                    .frame(width: 460)
                    .panelBackground()
                    Text(verbatim: "Your identity is a random key kept in this Mac's keychain. The realm knows you by it and by the name you choose; nothing else.")
                        .font(.nm(10))
                        .foregroundStyle(Palette.ink.opacity(0.45))
                        .multilineTextAlignment(.center)
                        .frame(width: 420)
                        .padding(.top, 14)
                    Spacer(minLength: 40)
                }
                .frame(width: proxy.size.width)
            }
        }
        .onAppear {
            withAnimation(.easeOut(duration: 1.6)) { appeared = true }
            nameFocused = app.keeperName == nil
        }
    }

    private var enterTitle: String {
        if app.isWaitingForSeat { return "Waiting for a Seat…" }
        return app.isEntering ? "Entering…" : "Enter World"
    }

    /// When every seat is held: what waiting means.
    private var seatNote: String? {
        if app.isWaitingForSeat {
            return "Every seat around the lake is held. Stay at the door: you'll step in the moment one falls free. A seat left a week goes to whoever waits."
        }
        if case .open(let status) = app.door, status.freeSeats == 0, !status.isEnding {
            return "Every seat around the lake is held. Enter to wait for the next that falls free."
        }
        return nil
    }

    @ViewBuilder
    private var keeper: some View {
        VStack(alignment: .leading, spacing: 8) {
            Caps("Keeper", size: 8.5, weight: .medium).foregroundStyle(Palette.ink.opacity(0.6))
            if let known = app.keeperName {
                Text(verbatim: "You are known here as \(known), of House \(known).")
                    .font(.nm(13, weight: .light))
                    .foregroundStyle(Palette.ink.opacity(0.9))
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
                if let problem = RealmState.nameProblem(name) {
                    Text(verbatim: problem)
                        .font(.nm(10))
                        .foregroundStyle(Palette.bad)
                } else {
                    Text(verbatim: "Two to twenty letters. It names you and the House you'll hold.")
                        .font(.nm(10))
                        .foregroundStyle(Palette.ink.opacity(0.5))
                }
            }
        }
    }
}

/// NULLMERE ONLINE, set wide and thin.
struct Wordmark: View {
    var appeared = true

    var body: some View {
        Text(verbatim: "NULLMERE ONLINE")
            .font(.system(size: 54, weight: .thin))
            .tracking(appeared ? 18 : 30)
            .foregroundStyle(Palette.ink)
            .shadow(color: Palette.glow.opacity(0.35), radius: 24)
            .lineLimit(1)
            .minimumScaleFactor(0.5)
            .opacity(appeared ? 1 : 0)
            .accessibilityLabel("Nullmere Online")
            .accessibilityAddTraits(.isHeader)
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
                .foregroundStyle(Palette.ink.opacity(0.65))
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
        case .connecting: return Palette.ink.opacity(0.5)
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
        let seats = status.freeSeats == 1 ? "1 seat free" : "\(status.freeSeats) seats free"
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
