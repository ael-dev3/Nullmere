import NullmereCore
import NullmereWorld
import SwiftUI

/// The keeper's alliance's mark on a stretch of ground or a hold, in its
/// own hue as the world draws it: what it bids in its maker's words, who
/// made it and how long it stands, lifted by the alliance's leader; and,
/// for a keeper leading an alliance, marking the ground for it, folded to
/// one button until asked for: to gather, strike, hold or beware, with a
/// few words of their own if they will.
struct MarkRow: View {
    let session: GameSession
    let hex: Hex
    @State private var open: Bool
    @State private var words: String

    /// `open`: the marking shown unfolded, as a test draws it.
    init(session: GameSession, hex: Hex, open: Bool = false, words: String = "") {
        self.session = session
        self.hex = hex
        _open = State(initialValue: open)
        _words = State(initialValue: words)
    }

    /// Whether there is a mark here to show, or one the keeper may make.
    static func offered(at hex: Hex, in state: GameState, player: Int) -> Bool {
        state.marksSeen(by: player).contains { $0.at == hex } || state.markRefusal(at: hex, as: player) == nil
    }

    /// A mark's hue, as its light in the world.
    static func hue(_ kind: AllianceMark.Kind) -> Color {
        let hue = WorldStage.markHue(kind)
        return Color(red: Double(hue.x), green: Double(hue.y), blue: Double(hue.z))
    }

    var body: some View {
        let state = session.state
        let mark = state.marksSeen(by: session.player).first { $0.at == hex }
        VStack(alignment: .leading, spacing: 6) {
            if let mark {
                HStack(spacing: 6) {
                    Circle().fill(MarkRow.hue(mark.kind)).frame(width: 7, height: 7)
                        .accessibilityHidden(true)
                    Caps(mark.kind.title, size: 9.5, weight: .medium).foregroundStyle(MarkRow.hue(mark.kind))
                    Spacer()
                    if state.unmarkRefusal(mark.id, as: session.player) == nil {
                        QuietButton(title: "Lift", size: 8.5, name: "Lift the alliance's mark here") {
                            session.perform(.unmarkGround(mark.id))
                        }
                    }
                }
                if let said = mark.words {
                    Text(verbatim: "“\(said)”")
                        .font(.nm(11))
                        .foregroundStyle(Palette.glowWords)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Text(verbatim: state.markMaker(mark))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.6))
                    .fixedSize(horizontal: false, vertical: true)
            }
            if state.markRefusal(at: hex, as: session.player) == nil {
                QuietButton(title: open ? "Mark for the alliance" : "Mark for the alliance…", size: 8.5,
                            name: open ? "Fold the alliance's marks away" : "Mark this ground for your alliance") { open.toggle() }
                if open { marking }
            }
        }
    }

    /// What the keeper may bid the alliance here, with words of their own.
    @ViewBuilder
    private var marking: some View {
        Text(verbatim: AllianceMark.explained)
            .font(.nm(10))
            .foregroundStyle(Palette.text(0.55))
            .fixedSize(horizontal: false, vertical: true)
        TextField("Words for the alliance, if any", text: $words)
            .textFieldStyle(.plain)
            .font(.nm(11))
            .foregroundStyle(Palette.ink)
            .padding(.vertical, 3)
            .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
            .accessibilityLabel("Words for the alliance, if any")
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                ForEach(AllianceMark.Kind.allCases, id: \.self) { kind in button(kind) }
            }
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 6) { button(.gather); button(.strike) }
                HStack(spacing: 6) { button(.hold); button(.beware) }
            }
        }
    }

    private func button(_ kind: AllianceMark.Kind) -> some View {
        QuietButton(title: kind.word, size: 8.5, tint: MarkRow.hue(kind), name: "Mark here for the alliance: \(kind.title)") {
            if session.perform(.markGround(hex, kind, words: words.isEmpty ? nil : words)) {
                words = ""
                open = false
            }
        }
    }
}
