import NullmereCore
import SwiftUI

/// Whether the keeper's book keeps this place (RoK's bookmarks), by what
/// name, to forget it; or else to keep it, by the name it goes by or one of
/// their own, folded to one button until asked for.
struct KeepPlaceRow: View {
    let session: GameSession
    let hex: Hex
    @State private var open: Bool
    @State private var name: String

    /// `open`: the keeping shown unfolded, as a test draws it.
    init(session: GameSession, hex: Hex, open: Bool = false, name: String = "") {
        self.session = session
        self.hex = hex
        _open = State(initialValue: open)
        _name = State(initialValue: name)
    }

    /// Why the book can't keep another place, while it can't.
    static func refusal(_ book: PlaceBook) -> String? {
        book.isFull ? "Your book keeps \(PlaceBook.limit) places: forget one to keep another." : nil
    }

    var body: some View {
        let book = session.placeBook
        VStack(alignment: .leading, spacing: 6) {
            if let kept = book.place(at: hex) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Caps("Among your places", size: 8.5).foregroundStyle(Palette.text(0.5))
                    Spacer()
                    QuietButton(title: "Forget", size: 8.5, name: "Forget \(kept.name) from your places") {
                        session.forgetPlace(hex)
                    }
                }
                Text(verbatim: kept.name)
                    .font(.nm(11))
                    .foregroundStyle(Palette.text(0.8))
                    .fixedSize(horizontal: false, vertical: true)
            } else {
                let called = session.state.keptName(of: hex)
                QuietButton(title: open ? "Keep this place" : "Keep this place…", size: 8.5,
                            name: open ? "Fold the keeping of this place away" : "Keep this place among your places") { open.toggle() }
                if open {
                    TextField(called, text: $name)
                        .textFieldStyle(.plain)
                        .font(.nm(11))
                        .foregroundStyle(Palette.ink)
                        .padding(.vertical, 3)
                        .overlay(alignment: .bottom) { Rule(opacity: 0.5) }
                        .accessibilityLabel("A name for this place, if not \(called)")
                    QuietButton(title: "Keep", size: 8.5, enabled: !book.isFull,
                                name: "Keep this place as \(PlaceBook.kept(name) ?? called)", why: KeepPlaceRow.refusal(book)) {
                        if session.keepPlace(hex, named: name) {
                            name = ""
                            open = false
                        }
                    }
                }
            }
        }
    }
}

/// The places the keeper keeps in their book, folded to how many and the
/// newest until asked for: each by its name, what stands there now and
/// since when it is kept, with Go to bring the view there and Forget to
/// let it go.
struct PlacesSection: View {
    let session: GameSession
    @State private var open: Bool

    init(session: GameSession, open: Bool = false) {
        self.session = session
        _open = State(initialValue: open)
    }

    /// The book in a line, while it is folded.
    static func summary(_ book: PlaceBook) -> String {
        guard let newest = book.places.first else {
            return "No places kept. Keep one from a hold or the ground to come back to it."
        }
        let count = book.places.count == 1 ? "1 place kept" : "\(book.places.count) places kept"
        return "\(count), the newest \(newest.name)."
    }

    /// What stands at a kept place now, if it goes by another name than it
    /// was kept by, and since when it is kept.
    static func line(_ place: KeptPlace, in state: GameState) -> String {
        let now = state.keptName(of: place.at)
        let since = "kept at watch \(place.kept)"
        return now == place.name ? since.prefix(1).uppercased() + since.dropFirst() : "\(now), \(since)"
    }

    var body: some View {
        let book = session.placeBook
        let shown = open && !book.places.isEmpty
        VStack(alignment: .leading, spacing: shown ? 8 : 4) {
            HStack(alignment: .firstTextBaseline) {
                Caps("Places", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
                Spacer()
                if !book.places.isEmpty {
                    QuietButton(title: shown ? "Fold places" : "Show places", size: 8.5,
                                name: shown ? "Fold your places away" : "Show your places") { open.toggle() }
                }
            }
            if shown {
                ForEach(book.places) { place in
                    HStack(alignment: .firstTextBaseline, spacing: 8) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(verbatim: place.name).font(.nm(10.5)).foregroundStyle(Palette.text(0.85))
                            Text(verbatim: PlacesSection.line(place, in: session.state))
                                .font(.nm(9.5))
                                .foregroundStyle(Palette.text(0.5))
                        }
                        .accessibilityElement(children: .combine)
                        Spacer()
                        QuietButton(title: "Go", size: 8.5, name: "Go to \(place.name)") { session.goToPlace(place.at) }
                        QuietButton(title: "Forget", size: 8.5, name: "Forget \(place.name)") { session.forgetPlace(place.at) }
                    }
                }
            } else {
                Text(verbatim: PlacesSection.summary(book))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
