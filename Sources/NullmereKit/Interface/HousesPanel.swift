import AppKit
import NullmereCore
import LauncherKit
import Observation
import SwiftUI

/// The other Houses around the lake: how they stand with the player, how
/// strong they are, and what can be said to them.
struct HousesPanel: View {
    let session: GameSession
    /// What the keeper is putting together for each House, kept while the
    /// panel is open.
    @State private var drafts = OfferDrafts()
    /// The House opened to what may be said to it: one at a time, the rest
    /// each a line.
    @State private var open: Int?

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                PanelTitle(title: "Houses", subtitle: "\(state.livingHouses.count) still stand around the lake")
                CloseButton(label: "Close the Houses") { session.panel = nil }
            }
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    EdictsSection(session: session)
                    Rule(opacity: 0.18)
                    RaceTable(session: session)
                    Rule(opacity: 0.18)
                    ForEach(state.houses.filter { $0.id != session.player }) { house in
                        HouseRow(session: session, house: house, draft: drafts.draft(for: house), expanded: open == house.id) {
                            withAnimation(.easeOut(duration: 0.2)) { open = open == house.id ? nil : house.id }
                        }
                        Rule(opacity: 0.18)
                    }
                }
            }
            .scrollEdgeFade()
            .scrollIndicators(.never)
            .pagedByKeys(session, as: .panel(.houses))
        }
        .padding(16)
        .frame(width: 360)
        .frame(maxHeight: 620)
        .panelBackground()
    }
}

/// Who is nearest to winning, by either road: holds toward dominion, and
/// stages of the Moonspire toward ascendancy.
struct RaceTable: View {
    let session: GameSession
    /// With "Differentiate without colour" on, what colour says is said in
    /// shape too.
    private var differentiate: Bool { Contrast.shared.differentiates }

    /// The columns' widths, which grow with Larger type as their words do.
    static var holdsColumn: CGFloat { 96 * TextSize.shared.scale }
    static var spireColumn: CGFloat { 84 * TextSize.shared.scale }

    var body: some View {
        let state = session.state
        VStack(alignment: .leading, spacing: 8) {
            // Its name on a line of its own, and its columns' words at the
            // size of the rest: nothing shrunk below what reads.
            Caps("The race for the lake", size: 9, weight: .medium).foregroundStyle(Palette.text(0.7))
            HStack {
                Spacer(minLength: 4)
                Caps("Holds of \(state.dominionNeed)", size: 9).foregroundStyle(Palette.text(0.6))
                    .frame(width: Self.holdsColumn, alignment: .leading)
                Caps("Moonspire", size: 9).foregroundStyle(Palette.text(0.6))
                    .frame(width: Self.spireColumn, alignment: .leading)
            }
            ForEach(session.standings, id: \.house) { standing in
                let house = state.houses[standing.house]
                HStack(spacing: 8) {
                    RoundedRectangle(cornerRadius: 1).fill(Palette.house(house)).frame(width: 3, height: 12)
                    Text(verbatim: standing.house == session.player ? "You" : house.name)
                        .font(.nm(10.5, weight: standing.house == session.player ? .medium : .regular))
                        .foregroundStyle(standing.threat == nil ? Palette.text(0.8) : (standing.house == session.player ? Palette.good : Palette.bad))
                        .lineLimit(1)
                    if standing.isVassal {
                        Caps("Vassal", size: 9).foregroundStyle(Palette.text(0.6))
                    }
                    if standing.threat != nil, differentiate {
                        // Near the end of a road, said in words, not colour alone.
                        Caps("Near", size: 9).foregroundStyle(Palette.text(0.75))
                    }
                    Spacer(minLength: 4)
                    HStack(spacing: 5) {
                        Meter(fraction: Double(standing.dominionPercent) / 100,
                              colour: standing.threat == .dominion ? Palette.bad : Palette.glow)
                            .frame(width: 60)
                        Text(verbatim: "\(standing.realm)").font(.nm(10).monospacedDigit()).foregroundStyle(Palette.text(0.7))
                    }
                    .frame(width: Self.holdsColumn, alignment: .leading)
                    LevelPips(level: standing.spire, maximum: BuildingKind.moonspire.maxLevel)
                        .frame(width: Self.spireColumn, alignment: .leading)
                }
                .accessibilityElement(children: .ignore)
                .accessibilityLabel(RaceTable.spoken(standing, in: state, player: session.player))
                .accessibilityAddTraits(.isStaticText)
            }
        }
    }

    static func spoken(_ standing: Standing, in state: GameState, player: Int) -> String {
        let who = standing.house == player ? "You" : state.houses[standing.house].title
        var line = "\(who): \(standing.realm) of \(standing.needed) holds for dominion, Moonspire stage \(standing.spire) of \(BuildingKind.moonspire.maxLevel)"
        if standing.isVassal { line += ", sworn to another" }
        if standing.threat != nil { line += ", near victory" }
        return line + "."
    }
}

/// Who an offer's words are for: a House, and the keeper holding it, if one
/// does. Others are told nothing of a keeper but the name, and the realm
/// gives a name to one keeper only, for as long as it stands
/// (`RealmState.arrive`), so the name is all there is to tell keepers apart.
struct OfferRecipient: Hashable {
    let house: Int
    let keeper: String?

    init(_ house: House) {
        self.house = house.id
        keeper = house.isPlayer ? house.name : nil
    }
}

/// What the keeper is putting together for another House: the words to
/// send with the next offer, never longer than an envoy carries, and
/// whether a trade is being composed. A draft is for one recipient. Once
/// the House is kept by another, the draft is retired: its words read
/// empty, its trade put away, and nothing it holds is sent, not even by a
/// button drawn before.
@MainActor
@Observable
final class OfferDraft {
    let recipient: OfferRecipient
    /// Retired drafts are no longer drawn, so no one need hear of it.
    @ObservationIgnored private(set) var isRetired = false
    private var typed = ""
    private var composing = false
    /// How many offers have gone from this draft, its words with them or
    /// none. Each is a boundary for the field being typed in, even one
    /// that leaves the words as empty as they were: the words alone can't
    /// tell it went.
    private(set) var sent = 0

    init(for house: House) {
        recipient = OfferRecipient(house)
    }

    /// Taken as typed, then cut to what an envoy carries. Taking it first
    /// tells whoever shows the words of every keystroke, even one that
    /// leaves them as they were. The field being typed in takes back what
    /// is cut itself (`EnvoyWordsField`).
    var words: String {
        get { isRetired ? "" : typed }
        set {
            guard !isRetired else { return }
            typed = newValue
            if typed.count > Envoy.wordsLimit { typed = String(typed.prefix(Envoy.wordsLimit)) }
        }
    }

    var isComposingTrade: Bool {
        get { !isRetired && composing }
        set { if !isRetired { composing = newValue } }
    }

    /// The House is kept by another now. Marked, not emptied: this happens
    /// while the panel is being drawn, where what is drawn mustn't change.
    func retire() {
        isRetired = true
    }

    /// Offers a proposal with the words, which go with it.
    func propose(_ proposal: Proposal, through session: GameSession) {
        guard let house = currentHouse(in: session) else { return }
        session.propose(proposal, to: house, words: words)
        words = ""
        sent += 1
    }

    /// Offers a trade with the words, which go with it, and puts the trade away.
    func offer(_ trade: Trade, through session: GameSession) {
        guard let house = currentHouse(in: session) else { return }
        session.offerTrade(trade, to: house, words: words)
        words = ""
        sent += 1
        isComposingTrade = false
    }

    /// The House as the session knows it now, while this draft is still for
    /// whoever keeps it: the world may have moved on before the panel is
    /// drawn again.
    private func currentHouse(in session: GameSession) -> House? {
        guard !isRetired, session.state.houses.indices.contains(recipient.house) else { return nil }
        let house = session.state.houses[recipient.house]
        return OfferRecipient(house) == recipient ? house : nil
    }
}

/// The Houses panel's drafts: one for each House, for whoever keeps it now.
/// A House seen kept by another than its draft was begun for has that draft
/// retired and a fresh one begun, so nothing comes back if the first keeper
/// does. A change made and undone between two looks at the world can't be
/// seen here.
@MainActor
final class OfferDrafts {
    private var current: [Int: OfferDraft] = [:]

    func draft(for house: House) -> OfferDraft {
        let recipient = OfferRecipient(house)
        if let draft = current[house.id], draft.recipient == recipient { return draft }
        current[house.id]?.retire()
        let draft = OfferDraft(for: house)
        current[house.id] = draft
        return draft
    }
}

/// The words for a keeper, in AppKit's own text field. What is typed or
/// pasted goes to the draft as it is entered; when the draft keeps less,
/// the rest is taken back in the field at once, while it is still being
/// typed in, so the field shows what will be sent. SwiftUI's text field,
/// told of the cut while it was being typed in, went on showing what had
/// been cut.
struct EnvoyWordsField: NSViewRepresentable {
    let draft: OfferDraft
    /// What the draft keeps now, read where the row is drawn, so the field
    /// hears when it changes from outside: sent, or the House kept by another.
    let words: String
    /// How many offers have gone from the draft, read there too, so the
    /// field hears of each, even one that left the words as empty as before.
    let sent: Int
    let placeholder: String
    let label: String
    let size: CGFloat

    func makeCoordinator() -> Coordinator {
        Coordinator(draft: draft)
    }

    func makeNSView(context: Context) -> NSTextField {
        let field = NSTextField(string: words)
        field.isBordered = false
        field.isBezeled = false
        field.drawsBackground = false
        // The system's ring, so one typing (or moving by Tab) sees where.
        field.focusRingType = .exterior
        field.cell?.isScrollable = true
        field.cell?.wraps = false
        // Typing is undone as in any field, within one draft; what came
        // before a boundary is forgotten there (`Coordinator.startAfresh`).
        field.cell?.allowsUndo = true
        field.delegate = context.coordinator
        context.coordinator.field = field
        style(field)
        return field
    }

    func updateNSView(_ field: NSTextField, context: Context) {
        style(field)
        context.coordinator.drawn(field, with: draft, words: words, sent: sent)
    }

    static func dismantleNSView(_ field: NSTextField, coordinator: Coordinator) {
        field.delegate = nil
    }

    func sizeThatFits(_ proposal: ProposedViewSize, nsView field: NSTextField, context: Context) -> CGSize? {
        CGSize(width: proposal.width ?? field.intrinsicContentSize.width, height: field.intrinsicContentSize.height)
    }

    /// Set as the row's other words are: the interface's type at the
    /// reader's size, in ink, the hint dimmer.
    private func style(_ field: NSTextField) {
        let font = NSFont.systemFont(ofSize: size, weight: .light)
        if field.font != font || field.placeholderAttributedString?.string != placeholder {
            field.font = font
            field.textColor = NSColor(Palette.ink)
            field.placeholderAttributedString = NSAttributedString(string: placeholder, attributes: [
                .font: font, .foregroundColor: NSColor(Palette.ink).withAlphaComponent(0.4),
            ])
        }
        // Setting the label and placeholder through the accessibility API
        // leaves the role unresolved (AXUnknown); say it is a text field, so
        // assistive technologies read it as one.
        if field.accessibilityRole() != .textField { field.setAccessibilityRole(.textField) }
        if field.accessibilityLabel() != label { field.setAccessibilityLabel(label) }
        if field.accessibilityPlaceholderValue() != placeholder { field.setAccessibilityPlaceholderValue(placeholder) }
    }

    @MainActor
    final class Coordinator: NSObject, NSTextFieldDelegate {
        let sync: EnvoyWordsSync
        /// The field typed in, to follow undo and redo in it.
        weak var field: NSTextField?
        private var replays: [any NSObjectProtocol] = []

        init(draft: OfferDraft) {
            sync = EnvoyWordsSync(draft: draft)
            super.init()
            // Undo and redo, as the undo manager announces them once done,
            // by the notices' own names: the field's change notice isn't
            // sent for them, and the draft must still hold what is shown.
            for name in ["NSUndoManagerDidUndoChangeNotification", "NSUndoManagerDidRedoChangeNotification"] {
                replays.append(NotificationCenter.default.addObserver(forName: NSNotification.Name(name), object: nil, queue: nil) { [weak self] notice in
                    // Any undo manager's, on whatever thread it works: this
                    // field's undoes on the main thread, so others are not
                    // its concern.
                    guard Thread.isMainThread else { return }
                    let history = notice.object as? UndoManager
                    MainActor.assumeIsolated { self?.replayed(history) }
                })
            }
        }

        isolated deinit {
            for replay in replays {
                NotificationCenter.default.removeObserver(replay)
            }
        }

        /// Undo or redo has put back, in an editor, what was there before:
        /// if it is this field's, the draft takes what the field shows now,
        /// as it would a keystroke, taking nothing back while it replays.
        private func replayed(_ history: UndoManager?) {
            guard let history, let editor = field?.currentEditor() as? NSTextView, editor.undoManager === history else { return }
            _ = sync.entered(editor.string, composing: editor.hasMarkedText(), replaying: true)
        }

        /// The row drawn again: at a boundary the editor starts afresh;
        /// otherwise it, and any composition in it, is left alone.
        func drawn(_ field: NSTextField, with draft: OfferDraft, words: String, sent: Int) {
            sync.drawn(with: draft, words: words, sent: sent) { words in
                Coordinator.startAfresh(field, showing: words)
            }
        }

        /// The editor shows the words the field types for now, and nothing
        /// from before lingers there: a composition under way is dropped, the
        /// input method told, and the history of what was typed forgotten,
        /// so neither can bring words sent, or meant for another keeper,
        /// back into the field or its draft.
        private static func startAfresh(_ field: NSTextField, showing words: String) {
            guard let editor = field.currentEditor() as? NSTextView else {
                field.stringValue = words
                // Not being typed in: unless another field of the window is,
                // whose history it is now, the history goes too.
                if !(field.window?.firstResponder is NSText) { forgetHistory(field.window?.undoManager) }
                return
            }
            if editor.hasMarkedText() {
                editor.inputContext?.discardMarkedText()
                editor.unmarkText()
            }
            editor.string = words
            editor.setSelectedRange(NSRange(location: (words as NSString).length, length: 0))
            forgetHistory(editor.undoManager)
        }

        /// The window's history holds only what was typed in fields (the
        /// game registers no undo of its own), so all of it goes. If the
        /// event under way is still gathering an undo group, it goes once
        /// the undo manager has closed that group: emptied with the group
        /// open, the manager would be left to close a group no longer there.
        private static func forgetHistory(_ history: UndoManager?) {
            guard let history else { return }
            guard history.groupingLevel > 0 else { return history.removeAllActions() }
            RunLoop.main.perform(#selector(UndoManager.removeAllActions as (UndoManager) -> () -> Void), target: history,
                                 argument: nil, order: Int.max, modes: history.runLoopModes)
        }

        /// Each change, as it is entered: the draft takes it, and whatever
        /// the draft doesn't keep is taken back from the field, through the
        /// editor as a keystroke would be.
        func controlTextDidChange(_ notification: Notification) {
            guard let field = notification.object as? NSTextField,
                  let editor = field.currentEditor() as? NSTextView
            else { return }
            let history = editor.undoManager
            guard let change = sync.entered(editor.string, composing: editor.hasMarkedText(),
                                            replaying: history?.isUndoing == true || history?.isRedoing == true),
                  editor.shouldChangeText(in: change.range, replacementString: change.replacement)
            else { return }
            editor.replaceCharacters(in: change.range, with: change.replacement)
            editor.didChangeText()
        }
    }
}

/// What the words field decides, apart from AppKit, so it can be checked
/// anywhere: the draft it types for, what it last knew that draft to hold,
/// and when its editor starts afresh.
@MainActor
final class EnvoyWordsSync {
    private(set) var draft: OfferDraft
    /// What the field last gave its draft, or found in it starting afresh.
    private(set) var known: String
    /// How many offers the field last knew to have gone from its draft.
    private(set) var sent: Int
    /// While the editor starts afresh, what it reports is the field's own
    /// doing: none of it is typing, for either draft.
    private(set) var isStartingAfresh = false

    init(draft: OfferDraft) {
        self.draft = draft
        known = draft.words
        sent = draft.sent
    }

    /// The row drawn again, with a draft, the words it holds and how many
    /// offers have gone from it. Another draft (the House kept by another),
    /// words changed from outside, or another offer gone (with its words,
    /// or none) is a boundary: `startAfresh` puts the editor right while the
    /// field still types for the draft before and takes nothing the editor
    /// reports meanwhile, and only then does the field type for this draft.
    /// Anything else leaves the editor alone, so a composition goes on.
    func drawn(with draft: OfferDraft, words: String, sent: Int, startAfresh: (String) -> Void) {
        guard draft !== self.draft || words != known || sent != self.sent else { return }
        isStartingAfresh = true
        defer { isStartingAfresh = false }
        startAfresh(words)
        self.draft = draft
        known = words
        self.sent = sent
    }

    /// The editor holds `text` now. The draft takes it, unless it is still
    /// being composed or the editor is starting afresh. Returns the change
    /// that leaves the editor with what the draft keeps, if it keeps less;
    /// none while undo or redo puts back, step by step, what was there.
    func entered(_ text: String, composing: Bool, replaying: Bool) -> (range: NSRange, replacement: String)? {
        guard !isStartingAfresh, !composing else { return nil }
        draft.words = text
        known = draft.words
        return replaying ? nil : EnvoyWordsSync.correction(of: text, keeping: known)
    }

    /// The change that makes what was entered into what the draft kept, in
    /// the editor's own measure (UTF-16): what follows what was kept, taken
    /// out. A draft keeps the start of what was entered, or nothing; were it
    /// ever otherwise, the whole is replaced. Nil if it kept it all.
    static func correction(of entered: String, keeping kept: String) -> (range: NSRange, replacement: String)? {
        guard kept != entered else { return nil }
        let whole = NSRange(location: 0, length: entered.utf16.count)
        guard entered.utf16.starts(with: kept.utf16) else { return (whole, kept) }
        return (NSRange(location: kept.utf16.count, length: whole.length - kept.utf16.count), "")
    }
}

/// What the trade popover holds: the composer, offering through the draft.
struct TradeOffer: View {
    let session: GameSession
    let house: House
    let draft: OfferDraft

    var body: some View {
        TradeComposer(house: house, stock: session.playerHouse.stock) { trade in
            draft.offer(trade, through: session)
        }
    }
}

struct HouseRow: View {
    let session: GameSession
    let house: House
    let draft: OfferDraft
    /// Whether its figures and what may be said to it are shown, or the
    /// House is a line of the list, opened by choosing it.
    let expanded: Bool
    let toggle: (() -> Void)?
    /// The gifts on offer, shown.
    @State private var choosingGift = false

    init(session: GameSession, house: House, draft: OfferDraft, expanded: Bool = true, toggle: (() -> Void)? = nil) {
        self.session = session
        self.house = house
        self.draft = draft
        self.expanded = expanded
        self.toggle = toggle
    }

    var body: some View {
        let state = session.state
        let player = session.player
        let stance = state.stance(player, house.id)
        let relation = state.relation(player, house.id)
        let spire = state.seat(of: house.id)?.level(.moonspire) ?? 0
        VStack(alignment: .leading, spacing: 7) {
            // Who the House is and how it stands with you, read as one; in
            // the list, chosen to open it.
            heading(stance: stance, relation: relation, spire: spire)
            if !house.isEliminated, expanded {
                if house.isPlayer {
                    // Words for the keeper there, sent with the next offer.
                    EnvoyWordsField(draft: draft, words: draft.words, sent: draft.sent, placeholder: "Words to send with an offer",
                                    label: "Words for the keeper of \(house.title)", size: 11 * TextSize.shared.scale)
                        .padding(.vertical, 4)
                        .overlay(alignment: .bottom) { Rule(opacity: 0.3) }
                }
                HStack(spacing: 14) {
                    Figure(label: "Holds", value: state.holds(of: house.id).count)
                    Figure(label: "Strength", value: state.strength(of: house.id))
                    Figure(label: "Renown", value: state.renown(of: house.id))
                }
                .accessibilityElement(children: .combine)
                // In a row when they fit, wrapping onto the next when not,
                // far enough apart that one is never pressed for another.
                FlowLayout(spacing: 8, lineSpacing: 6) { actions(stance: stance) }
            }
        }
        .accessibilityElement(children: .contain)
    }

    /// The House's name, its stance and the line of what it is; a button
    /// that opens or folds it where the list folds Houses.
    @ViewBuilder
    private func heading(stance: Stance, relation: Relation?, spire: Int) -> some View {
        let lines = VStack(alignment: .leading, spacing: 7) {
            HStack(alignment: .firstTextBaseline) {
                RoundedRectangle(cornerRadius: 1)
                    .fill(Palette.house(house))
                    .frame(width: 3, height: 12)
                Caps(house.title, size: 10.5, weight: .medium)
                    .foregroundStyle(house.isEliminated ? Palette.text(0.35) : Palette.ink)
                Spacer()
                if house.isEliminated {
                    Caps("Fallen", size: 8.5).foregroundStyle(Palette.text(0.4))
                } else {
                    Caps(stance.title, size: 8.5, weight: .medium)
                        .foregroundStyle(stance == .war ? Palette.bad : (stance == .pact ? Palette.good : Palette.text(0.65)))
                }
            }
            if !house.isEliminated {
                Text(verbatim: summary(stance: stance, relation: relation, spire: spire))
                    .font(.nm(10.5))
                    .foregroundStyle(Palette.text(0.55))
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        if let toggle {
            let _ = PressableButtons.note(house.title, enabled: true, toggle)
            Button(action: toggle) {
                lines
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityElement(children: .combine)
            .accessibilityIdentifier("house-row")
            .accessibilityHint(expanded ? "Folds them back into the list" : "Shows what may be said to them")
        } else {
            lines.accessibilityElement(children: .combine)
        }
    }

    /// An envoy of the keeper's with this offer is on the road to the House:
    /// one of each kind at a time.
    private func awaits(_ proposal: Proposal) -> Bool {
        session.state.envoys.contains { $0.from == session.player && $0.to == house.id && $0.proposal == proposal }
    }

    @ViewBuilder
    private func actions(stance: Stance) -> some View {
        switch stance {
        case .war:
            QuietButton(title: "Offer peace", size: 8.5) { offer(.peace) }
        case .peace:
            QuietButton(title: "Offer a pact", size: 8.5, enabled: !awaits(.pact)) { offer(.pact) }
                .help(awaits(.pact) ? "Your envoy with a pact waits on their answer." : "Shared sight across the water, and no blade between you.")
            giftMenu
            tradeButton
            if session.canDemandTribute(from: house.id) {
                if house.isPlayer {
                    QuietButton(title: "Demand tribute", size: 8.5) { offer(.tribute) }
                } else {
                    // A steward that refuses is at war with you at once:
                    // asked twice, as war is.
                    ConfirmButton(title: "Demand tribute", confirm: "Tribute, or war?") { offer(.tribute) }
                }
            }
            ConfirmButton(title: "Declare war", confirm: "War on \(house.title)?") { session.perform(.declareWar(on: house.id)) }
        case .pact:
            giftMenu
            tradeButton
            ConfirmButton(title: "Break the pact", confirm: "Betray \(house.title)?") { session.perform(.declareWar(on: house.id)) }
        }
    }

    /// What may be sent, from what the keeper has: a few sizes of each.
    static func giftChoices(from stock: Stock) -> [(resource: Resource, amount: Int)] {
        Resource.allCases.flatMap { resource in
            (resource == .moonsalt ? [2, 5, 10] : [10, 25, 50])
                .filter { $0 <= stock[resource] }
                .map { (resource, $0) }
        }
    }

    @ViewBuilder
    private var giftMenu: some View {
        let choices = HouseRow.giftChoices(from: session.playerHouse.stock)
        if !choices.isEmpty {
            let _ = choices.forEach { choice in
                PressableButtons.note("Send \(choice.amount) \(choice.resource.title.lowercased())", enabled: true) { send(choice) }
            }
            // A button as those beside it, its gifts in a popover: each a
            // button, plain to the pointer, the keys and VoiceOver.
            QuietButton(title: "Send a gift", size: 8.5) { choosingGift.toggle() }
                .popover(isPresented: $choosingGift, arrowEdge: .bottom) {
                    // Headed as the trade's popover is: the popover reads by its heading.
                    VStack(alignment: .leading, spacing: 2) {
                        Caps("Gifts to \(house.title)", size: 9, weight: .medium)
                            .foregroundStyle(Palette.ink)
                            .padding(.bottom, 4)
                        ForEach(Array(choices.enumerated()), id: \.offset) { _, choice in
                            QuietButton(title: "Send \(choice.amount) \(choice.resource.title.lowercased())", size: 9, pressable: false) {
                                choosingGift = false
                                send(choice)
                            }
                        }
                    }
                    .padding(8)
                }
                .help("Stores sent now buy goodwill: a steward sees a war as older, and takes a pact from a House that has given enough, unless that House once made war on it or a pact between them was broken. Making war on it throws the goodwill away. A House takes in gifts worth \(GameState.giftsTakenPerWatch) a watch at most, moonsalt counting four.")
        }
    }

    private var tradeButton: some View {
        QuietButton(title: "Offer a trade", size: 8.5, enabled: !awaits(.trade)) { draft.isComposingTrade = true }
            .help(awaits(.trade) ? "Your envoy with a trade waits on their answer." : "So much of one store for so much of another.")
            .popover(isPresented: Bindable(draft).isComposingTrade, arrowEdge: .leading) {
                TradeOffer(session: session, house: house, draft: draft)
            }
            // When the button goes (war, or the House falls), the trade goes
            // with it, so it doesn't open by itself when the button returns.
            .onDisappear { draft.isComposingTrade = false }
    }

    private func send(_ choice: (resource: Resource, amount: Int)) {
        session.perform(.gift(to: house.id, resource: choice.resource, amount: choice.amount))
    }

    private func offer(_ proposal: Proposal) {
        draft.propose(proposal, through: session)
    }

    /// Who gives a House its orders: a steward, or a keeper here or away.
    static func keeping(_ house: House, present: [String]?) -> String {
        guard house.isPlayer else { return "A steward gives its orders." }
        if present?.contains(house.name) == true { return "Its keeper is here." }
        return "Its keeper is away; after two watches a caretaker keeps it, beginning no war, demand or pact."
    }

    private func summary(stance: Stance, relation: Relation?, spire: Int) -> String {
        let state = session.state
        var parts = [house.isPlayer ? HouseRow.keeping(house, present: session.realmStatus?.present)
                                    : "\(house.temperament.title). \(HouseRow.keeping(house, present: nil))"]
        parts.append("Of \(state.heritage(of: house.id).title).")
        if let liege = house.liege {
            parts.append(liege == session.player ? "Sworn to you." : "Sworn to \(state.houses[liege].title).")
        }
        let vassals = state.houses.filter { $0.liege == house.id && !$0.isEliminated }
        if !vassals.isEmpty {
            parts.append("Liege of \(vassals.map(\.title).joined(separator: ", ")).")
        }
        if let relation {
            let watches = max(session.state.watch - relation.since, 0)
            let span = watches == 0 ? "since this watch" : "for \(watches) watch\(watches == 1 ? "" : "es")"
            parts.append("\(stance.title) \(span).")
            if relation.betrayals > 0 {
                parts.append("Pacts broken between you: \(relation.betrayals).")
            }
        }
        if spire > 0 {
            parts.append("Its Moonspire stands at stage \(spire) of \(BuildingKind.moonspire.maxLevel).")
        }
        let goodwill = state.goodwill(from: session.player, to: house.id)
        if goodwill > 0 {
            parts.append("Your gifts lately are worth \(goodwill) to them.")
        }
        return parts.joined(separator: " ")
    }
}

private struct Figure: View {
    let label: String
    let value: Int

    var body: some View {
        HStack(spacing: 4) {
            Caps(label, size: 7.5).foregroundStyle(Palette.text(0.45))
            Text(verbatim: "\(value)").font(.nm(10.5).monospacedDigit()).foregroundStyle(Palette.text(0.8))
        }
        .accessibilityElement(children: .combine)
    }
}

struct CloseButton: View {
    /// What it closes, as VoiceOver says it: "Close the Houses", "Hide counsel".
    let label: String
    let action: () -> Void

    @State private var hovering = false
    @FocusState private var focused: Bool

    var body: some View {
        Button(action: action) {
            Image(systemName: "xmark")
                .font(.nm(9, weight: .light))
                .foregroundStyle(Palette.text(hovering || focused ? 0.95 : 0.7))
                .frame(width: QuietButton.least, height: QuietButton.least)
                .contentShape(Rectangle())
                .overlay(FocusRing(isFocused: focused))
        }
        .buttonStyle(.plain)
        .focused($focused)
        .onPointer { hovering = $0 }
        .accessibilityLabel(label)
    }
}

/// Envoys waiting on the player's answer: one card at a time, the others
/// waiting behind it a line each, any of them brought forward when chosen.
struct EnvoyCards: View {
    let session: GameSession

    /// The most envoys told a line each behind the one heard.
    static let waitingLines = 3

    @Environment(\.worldMotion) private var motion
    /// The envoy brought forward, if the keeper chose one.
    @State private var forward: Int?

    /// The envoy heard now: the one brought forward while it waits, else
    /// the first to come.
    static func heard(of envoys: [Envoy], forward: Int?) -> Envoy? {
        envoys.first { $0.id == forward } ?? envoys.first
    }

    var body: some View {
        let state = session.state
        let heard = EnvoyCards.heard(of: session.envoys, forward: forward)
        let waiting = session.envoys.filter { $0.id != heard?.id }
        VStack(alignment: .trailing, spacing: 8) {
            ForEach(waiting.prefix(EnvoyCards.waitingLines)) { envoy in
                let house = state.houses[envoy.from]
                Button {
                    withAnimation(.easeOut(duration: 0.2)) { forward = envoy.id }
                } label: {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1).fill(Palette.house(house)).frame(width: 3, height: 12)
                        Caps("An envoy of \(house.title)", size: 8.5, weight: .medium).foregroundStyle(Palette.text(0.85))
                        Spacer(minLength: 8)
                        Caps(envoy.proposal.title, size: 8).foregroundStyle(Palette.text(0.65))
                    }
                    .padding(.horizontal, 12)
                    .frame(width: 320, alignment: .leading)
                    .frame(minHeight: QuietButton.least)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .panelBackground()
                .accessibilityLabel("An envoy of \(house.title), \(envoy.proposal.title.lowercased()), waits")
                .accessibilityHint("Hears it.")
            }
            if waiting.count > EnvoyCards.waitingLines {
                Text(verbatim: "And \(waiting.count - EnvoyCards.waitingLines) more waiting")
                    .font(.nm(10))
                    .foregroundStyle(Palette.text(0.6))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(Palette.panel, in: RoundedRectangle(cornerRadius: 3))
            }
            ForEach(heard.map { [$0] } ?? []) { envoy in
                let house = state.houses[envoy.from]
                let left = max(Envoy.patience - (state.watch - envoy.arrived), 1)
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        RoundedRectangle(cornerRadius: 1).fill(Palette.house(house)).frame(width: 3, height: 12)
                        Caps("An envoy of \(house.title)", size: 9, weight: .medium).foregroundStyle(Palette.ink)
                    }
                    if let spoken = session.spoken[.envoy(envoy.id)] {
                        Text(verbatim: "\"\(spoken)\"")
                            .font(.nm(12, weight: .light).italic())
                            .foregroundStyle(Palette.text(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                            .transition(.opacity)
                    }
                    if let words = session.words(of: envoy) {
                        Text(verbatim: "\"\(words)\"")
                            .font(.nm(12, weight: .light).italic())
                            .foregroundStyle(Palette.text(0.88))
                            .fixedSize(horizontal: false, vertical: true)
                            .accessibilityLabel("\(house.name) writes: \(words)")
                    }
                    Text(verbatim: EnvoyCards.words(for: envoy, from: house, in: state, player: session.player))
                        .font(.nm(10.5))
                        .foregroundStyle(Palette.text(session.spoken[.envoy(envoy.id)] == nil ? 0.7 : 0.5))
                        .fixedSize(horizontal: false, vertical: true)
                    HStack(spacing: 4) {
                        Text(verbatim: left == 1 ? "Leaves after this watch" : "Waits \(left) watches")
                            .font(.nm(10))
                            .foregroundStyle(Palette.text(0.4))
                        Spacer()
                        if envoy.words != nil {
                            let muted = session.mutedHouses.contains(house.name)
                            QuietButton(title: muted ? "Show words" : "Hide words", size: 8.5) { session.setMuted(!muted, house: house) }
                                .help(muted ? "Read \(house.name)'s words again." : "Hide \(house.name)'s words from now on, on this Mac.")
                        }
                        if envoy.proposal == .tribute, !house.isPlayer {
                            // Refusing a steward's demand is war: asked twice, as war is.
                            ConfirmButton(title: "Refuse", confirm: "Refuse, and war?") {
                                session.perform(.answer(envoy: envoy.id, accept: false))
                            }
                        } else {
                            QuietButton(title: "Refuse", size: 8.5) { session.perform(.answer(envoy: envoy.id, accept: false)) }
                        }
                        QuietButton(title: "Accept", size: 8.5, prominent: true, enabled: EnvoyCards.canAccept(envoy, in: state, player: session.player)) {
                            session.perform(.answer(envoy: envoy.id, accept: true))
                        }
                        .help(EnvoyCards.canAccept(envoy, in: state, player: session.player) ? "" : "You haven't what it asks.")
                    }
                }
                .padding(14)
                .frame(width: 320)
                .panelBackground()
                // Below full motion it fades in where it rests.
                .transition(motion == .full ? .move(edge: .trailing).combined(with: .opacity) : .opacity)
                .accessibilityElement(children: .contain)
            }
        }
    }

    /// Whether the keeper can keep the terms: for a trade, what it asks of
    /// them is in their stores. Accepting a trade they can't pay would only
    /// send the envoy away.
    static func canAccept(_ envoy: Envoy, in state: GameState, player: Int) -> Bool {
        guard envoy.proposal == .trade, let trade = envoy.trade else { return true }
        return state.houses[player].stock[trade.take] >= trade.takeAmount
    }

    static func words(for envoy: Envoy, from house: House, in state: GameState, player: Int) -> String {
        switch envoy.proposal {
        case .trade:
            guard let trade = envoy.trade else { return "\(house.title) would trade, but its terms are lost." }
            var line = "\(house.title) offers \(trade.given) for \(trade.taken) of yours. \(TradeComposer.note(asking: trade.asking))"
            let have = state.houses[player].stock[trade.take]
            if have < trade.takeAmount { line += " You have only \(have) \(trade.take.title.lowercased())." }
            return line
        case .peace:
            return "\(house.title) asks for peace. Their companies would turn from yours, and yours from theirs."
        case .pact:
            return "\(house.title) offers a pact: shared sight across the water, and no blade between you."
        case .fealty:
            return "\(house.title) is beaten and bends the knee: it would be your vassal, its holds counted with yours, never to raise a blade against you."
        case .tribute:
            let price = state.tribute(from: player)
            guard !house.isPlayer else {
                return "\(house.title) demands tribute: \(price), a fifth of your stores. Pay, and they can't ask again for \(GameState.tributeRespite) watches. Refuse, or send no answer, and war is theirs to choose."
            }
            return "\(house.title) demands tribute: \(price), a fifth of your stores. Pay, and it keeps the peace for \(GameState.tributeRespite) watches, unless your Moonspire rises. Refuse, or send no answer, and it marches on you."
        }
    }
}

/// Terms of a trade, set by the keeper: what to give, and what to ask.
struct TradeComposer: View {
    let house: House
    let stock: Stock
    let offer: (Trade) -> Void

    @State private var give: Resource = .grain
    @State private var giveAmount = 10
    @State private var take: Resource = .timber
    @State private var takeAmount = 10

    init(house: House, stock: Stock, offer: @escaping (Trade) -> Void) {
        self.house = house
        self.stock = stock
        self.offer = offer
        // Start from what the keeper has most of.
        let most = Resource.allCases.max { stock[$0] * $0.worth < stock[$1] * $1.worth } ?? .grain
        _give = State(initialValue: most)
        _take = State(initialValue: most == .timber ? .stone : .timber)
    }

    var trade: Trade { Trade(give: give, giveAmount, for: take, takeAmount) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Caps("A trade with \(house.title)", size: 9, weight: .medium).foregroundStyle(Palette.ink)
            row("Give", resource: $give, amount: $giveAmount, most: max(1, stock[give]))
            row("For", resource: $take, amount: $takeAmount, most: Stock.cap)
            Text(verbatim: TradeComposer.line(for: trade, stock: stock, keeper: house.isPlayer))
                .font(.nm(10.5))
                .foregroundStyle(Palette.text(0.7))
                .fixedSize(horizontal: false, vertical: true)
            HStack {
                Spacer()
                QuietButton(title: "Offer", size: 9, prominent: true, enabled: TradeComposer.problem(with: trade, stock: stock) == nil) {
                    offer(trade)
                }
            }
        }
        .padding(14)
        .frame(width: 280)
    }

    private func row(_ label: String, resource: Binding<Resource>, amount: Binding<Int>, most: Int) -> some View {
        HStack(spacing: 8) {
            Caps(label, size: 8).foregroundStyle(Palette.text(0.5)).frame(width: 34, alignment: .leading)
            Picker(label, selection: resource) {
                ForEach(Resource.allCases, id: \.self) { Text($0.title).tag($0) }
            }
            .labelsHidden()
            .frame(width: 104)
            AmountField(name: "\(label) amount", amount: amount, most: most, step: resource.wrappedValue == .moonsalt ? 1 : 5)
        }
    }

    /// Why the terms can't be offered, if they can't.
    static func problem(with trade: Trade, stock: Stock) -> String? {
        if trade.give == trade.take { return "Choose two different stores." }
        if !trade.isWellFormed { return "Choose an amount of each." }
        if stock[trade.give] < trade.giveAmount { return "You have only \(stock[trade.give]) \(trade.give.title.lowercased())." }
        return nil
    }

    /// How terms weigh, from the side of the House that would get `asking`
    /// percent of what it gives.
    static func note(asking: Int) -> String {
        switch asking {
        case ..<90: return "Generous: more given than asked, by barter worth."
        case 90...110: return "Even terms, by barter worth."
        default: return "More asked than given, by barter worth."
        }
    }

    static func line(for trade: Trade, stock: Stock, keeper: Bool) -> String {
        if let problem = problem(with: trade, stock: stock) { return problem }
        let who = keeper ? "Their keeper answers by envoy." : "Their steward answers at once; the cunning ask more, allies less."
        return "\(note(asking: trade.asking)) \(who)"
    }
}
