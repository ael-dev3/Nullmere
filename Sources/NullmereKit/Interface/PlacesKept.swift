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

    /// Why the book can't keep another place, while it can't, as the
    /// phone says it too.
    static func refusal(_ book: PlaceBook) -> String? {
        book.refusal
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

    /// The book in a line, while it is folded, as the phone says it too.
    static func summary(_ book: PlaceBook) -> String {
        book.summary
    }

    /// What stands at a kept place now, if it goes by another name than it
    /// was kept by, and since when it is kept, as the phone says it too.
    static func line(_ place: KeptPlace, in state: GameState) -> String {
        state.keptLine(place)
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

/// The keeper's search on the land, as Rise of Kingdoms' search on its map
/// finds the barbarians and the resource points: a button for each kind of
/// place, bringing the view to the nearest of it the House has seen to
/// where the view looks, and Next for the one after; what was found said
/// beneath, or that the House has seen none.
struct SeekSection: View {
    let session: GameSession

    /// What the last search found, in a line: "Saltwights, level III, 4
    /// tiles north-east of where you looked; 1 of 6 seen", or that the House
    /// has seen none.
    static func line(_ sought: GameSession.Sought?, in state: GameState) -> String? {
        guard let sought else { return nil }
        guard let at = sought.at else { return sought.seeking.noneSeen }
        let way = at == sought.from ? "where you looked" : "\(GameState.waySaid(to: at, from: sought.from)) of where you looked"
        let of = sought.found.count == 1 ? "the only one seen" : "\(sought.index + 1) of \(sought.found.count) seen"
        return "\(named(at, in: state)), \(way); \(of)"
    }

    /// What stands at a place found, as the map names it.
    static func named(_ hex: Hex, in state: GameState) -> String {
        if let wild = state.wild(at: hex) { return HoverInfo.named(wild) }
        if let site = state.site(at: hex) { return HoverInfo.named(site, in: state).lineBegun }
        if let lair = state.lair(at: hex) { return lair.named.lineBegun }
        if let shrine = state.shrine(at: hex) {
            let holder = shrine.holder.flatMap { state.houses.indices.contains($0) ? state.houses[$0].title : nil }
            return "The \(shrine.title), held by \(holder ?? "none")"
        }
        if let find = state.findsInLand.first(where: { $0.position == hex }) {
            return find.kind == .hamlet ? find.named.lineBegun : "\(find.named), an old barrow"
        }
        return state.keptName(of: hex)
    }

    var body: some View {
        let sought = session.sought
        VStack(alignment: .leading, spacing: 6) {
            Caps("Seek on the land", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
            FlowLayout(spacing: 4, lineSpacing: 2) {
                ForEach(Seeking.allCases, id: \.self) { seeking in
                    QuietButton(title: seeking.title, size: 8.5, prominent: sought?.seeking == seeking,
                                name: "Seek \(seeking.sought) your House has seen, the nearest first") {
                        session.seek(seeking)
                    }
                }
            }
            if let line = SeekSection.line(sought, in: session.state) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(verbatim: line)
                        .font(.nm(10))
                        .foregroundStyle(Palette.text(0.6))
                        .fixedSize(horizontal: false, vertical: true)
                    Spacer(minLength: 4)
                    if let sought, sought.found.count > 1 {
                        QuietButton(title: "Next", size: 8.5, name: "Seek the next nearest of \(sought.seeking.sought)") { session.seekNext() }
                    }
                }
            }
        }
    }
}
