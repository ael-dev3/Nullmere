import AppKit
import LauncherKit
import NullmereRealm
import Observation
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The panels' buttons' own actions, run through PressableButtons: each
/// panel is drawn while the test listens, each button leaves its action
/// under its title as it is drawn, and running it must reach the session
/// and send the order it names to the realm. This covers what the buttons
/// do, not a click on them: hit-testing and the mouse are ClickTests'.
@MainActor
final class PressTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        PressableButtons.isListening = true
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    /// Draws the view afresh, so its buttons are those it shows now.
    private func draw(_ view: some View, width: CGFloat = 360, height: CGFloat = 700) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    private func session(_ state: GameState) -> (GameSession, RecordingLink) {
        let link = RecordingLink()
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()
        return (session, link)
    }

    func testAHousesActionsSendTheirOffers() throws {
        let state = GameState(settings: GameSettings(seedText: "pressed offers", houseCount: 4, radius: 18))
        let (session, link) = session(state)
        let other = try XCTUnwrap(session.state.houses.first { $0.id != session.player && !$0.isEliminated })
        XCTAssertEqual(session.state.stance(session.player, other.id), .peace)
        let draft = OfferDraft(for: other)
        draw(HouseRow(session: session, house: other, draft: draft))
        XCTAssertTrue(PressableButtons.press("Offer a pact"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .propose(.pact, to: other.id))
        let gift = try XCTUnwrap(shown.first { $0.hasPrefix("Send ") }, "A gift to send, among \(shown)")
        XCTAssertTrue(PressableButtons.press(gift))
        guard case .gift(let to, _, _)? = link.sent.last else { return XCTFail("The gift is sent: \(link.sent)") }
        XCTAssertEqual(to, other.id)
        XCTAssertTrue(PressableButtons.press("Offer a trade"))
        XCTAssertTrue(draft.isComposingTrade, "The trade opens to be composed")
        XCTAssertTrue(PressableButtons.press("Declare war"))
        XCTAssertEqual(link.sent.last, .declareWar(on: other.id))

        // At war, peace may be offered.
        draw(HouseRow(session: session, house: session.state.houses[other.id], draft: draft))
        XCTAssertTrue(PressableButtons.press("Offer peace"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .propose(.peace, to: other.id))
        draw(HousesPanel(session: session), height: 900)
        XCTAssertFalse(shown.isEmpty)
    }

    private func spin(until what: String, timeout: Double = 5, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "Waited for \(what)")
    }

    /// A House held by another keeper, so words may go with what is offered;
    /// the last in the Houses panel, if asked, so its buttons' actions are
    /// the last left under their titles as the panel is drawn.
    private func keepersHouse(_ seed: String, lastInThePanel: Bool = false) -> (GameSession, RecordingLink, House) {
        var state = GameState(settings: GameSettings(seedText: seed, houseCount: 4, radius: 18))
        let others = state.houses.map(\.id).filter { $0 != state.player }
        let other = lastInThePanel ? others[others.count - 1] : (state.player + 1) % state.houses.count
        state.houses[other].isPlayer = true
        let (session, link) = session(state)
        return (session, link, session.state.houses[other])
    }

    private func offers(_ link: RecordingLink) -> Int {
        link.sent.filter { if case .offerTrade = $0 { return true } else { return false } }.count
    }

    func testTheWordsAreKeptToWhatAnEnvoyCarriesAndGoWithWhatIsOffered() throws {
        let (session, link, house) = keepersHouse("words with an offer")
        let draft = OfferDraft(for: house)
        let long = String(repeating: "Grain for stone. ", count: 12)

        // Typed past what an envoy carries: kept to it, and every keystroke is
        // told to whoever shows the words, even one that leaves them as they were.
        let heard = Heard()
        withObservationTracking { _ = draft.words } onChange: { heard.count += 1 }
        draft.words = long
        XCTAssertEqual(draft.words, String(long.prefix(Envoy.wordsLimit)))
        withObservationTracking { _ = draft.words } onChange: { heard.count += 1 }
        draft.words += "and more"
        XCTAssertEqual(draft.words.count, Envoy.wordsLimit, "No further")
        XCTAssertEqual(heard.count, 2, "The field hears of the keystroke it must take back")

        // A pact, by the pact button's own action: the words go with it.
        draw(HouseRow(session: session, house: house, draft: draft))
        XCTAssertTrue(PressableButtons.press("Offer a pact"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .proposeWithWords(.pact, to: house.id, words: String(long.prefix(Envoy.wordsLimit))))
        XCTAssertEqual(draft.words, "")

        // The trade button's action opens the trade; the action of the
        // composer the popover holds offers it, with the words, and puts it away.
        draft.words = "Grain for stone, as before."
        XCTAssertTrue(PressableButtons.press("Offer a trade"))
        XCTAssertTrue(draft.isComposingTrade)
        // Put away unoffered, as the popover's binding puts it when the popover
        // is dismissed (a real dismissal is in testATradePutAwayUnofferedKeepsItsWords).
        draft.isComposingTrade = false
        XCTAssertEqual(draft.words, "Grain for stone, as before.", "The words wait for the next offer")
        XCTAssertTrue(PressableButtons.press("Offer a trade"))
        draw(TradeOffer(session: session, house: house, draft: draft), width: 300, height: 320)
        XCTAssertTrue(PressableButtons.press("Offer"), "Among \(shown)")
        guard case .offerTrade(_, let to, let words)? = link.sent.last else { return XCTFail("The trade is offered: \(link.sent)") }
        XCTAssertEqual(to, house.id)
        XCTAssertEqual(words, "Grain for stone, as before.")
        XCTAssertEqual(draft.words, "", "The words go with it")
        XCTAssertFalse(draft.isComposingTrade, "and the trade is put away")
    }

    func testAHouseKeptByAnotherStartsAfreshAndNothingComesBack() {
        var state = GameState(settings: GameSettings(seedText: "a seat changes hands", houseCount: 4, radius: 18))
        let other = (state.player + 1) % state.houses.count
        state.houses[other].isPlayer = true
        state.houses[other].name = "Ama"
        let drafts = OfferDrafts()
        let first = drafts.draft(for: state.houses[other])
        first.words = "For Ama alone."
        first.isComposingTrade = true
        XCTAssertTrue(drafts.draft(for: state.houses[other]) === first, "Ama's draft, while Ama keeps the House")
        XCTAssertFalse(drafts.draft(for: state.houses[(other + 1) % state.houses.count]) === first, "Each House its own")

        // Ama, then Bel: Ama's words and trade are gone, and Bel's begin afresh.
        state.houses[other].name = "Bel"
        let bel = drafts.draft(for: state.houses[other])
        XCTAssertFalse(bel === first)
        XCTAssertTrue(first.isRetired)
        XCTAssertEqual(first.words, "", "Ama's words are gone")
        XCTAssertFalse(first.isComposingTrade, "and her trade put away")
        XCTAssertEqual(bel.words, "")
        XCTAssertFalse(bel.isComposingTrade)
        bel.words = "For Bel."

        // Then Ama again: nothing of hers, or of Bel's, comes back.
        state.houses[other].name = "Ama"
        let ama = drafts.draft(for: state.houses[other])
        XCTAssertFalse(ama === first, "Not her first draft")
        XCTAssertTrue(bel.isRetired)
        XCTAssertEqual(ama.words, "", "Ama's old words aren't restored")

        // The stewards, then the same name again: still nothing restored.
        ama.words = "Again, for Ama."
        state.houses[other].isPlayer = false
        let stewards = drafts.draft(for: state.houses[other])
        XCTAssertTrue(ama.isRetired)
        state.houses[other].isPlayer = true
        let returned = drafts.draft(for: state.houses[other])
        XCTAssertFalse(returned === ama)
        XCTAssertFalse(returned === stewards)
        XCTAssertEqual(returned.words, "", "Kept again under the same name, the House starts afresh")

        // A retired draft takes nothing more.
        first.words = "Late words."
        first.isComposingTrade = true
        XCTAssertEqual(first.words, "")
        XCTAssertFalse(first.isComposingTrade)
    }

    func testAComposerDrawnBeforeTheSeatChangedSendsNothing() throws {
        let (session, link, house) = keepersHouse("a composer drawn before")
        let drafts = OfferDrafts()
        let draft = drafts.draft(for: house)
        draft.words = "For the keeper there."
        draft.isComposingTrade = true
        draw(TradeOffer(session: session, house: house, draft: draft), width: 300, height: 320)
        let staleOffer = try XCTUnwrap(PressableButtons.actions["Offer"], "The composer's action, among \(shown)")
        draw(HouseRow(session: session, house: house, draft: draft))
        let stalePact = try XCTUnwrap(PressableButtons.actions["Offer a pact"], "Among \(shown)")
        let sent = link.sent.count

        // The seat passes to another keeper at the realm's word, before the
        // panel is drawn again: what was drawn for the last keeper sends nothing.
        var handed = session.state
        handed.houses[house.id].name = "Bel"
        link.onEvent?(.changed(handed))
        staleOffer()
        stalePact()
        XCTAssertEqual(link.sent.count, sent, "Nothing for the last keeper goes to the next")

        // Drawn again, the panel retires that draft and begins the next keeper's.
        let next = drafts.draft(for: session.state.houses[house.id])
        XCTAssertFalse(next === draft)
        XCTAssertTrue(draft.isRetired)
        XCTAssertEqual(draft.words, "")
        XCTAssertFalse(draft.isComposingTrade)
        staleOffer()
        XCTAssertEqual(link.sent.count, sent, "Nor once it is retired")
    }

    func testInAWindowTheRowsButtonOpensTheTradeInItsPopover() throws {
        let (session, link, house) = keepersHouse("a trade in a window")
        let draft = OfferDraft(for: house)
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 380, height: 460), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: HouseRow(session: session, house: house, draft: draft)
            .frame(width: 340).padding(20).background(Color.black))
        window.orderFrontRegardless()
        defer { window.close() }
        spin(until: "the row drawn") { PressableButtons.actions["Offer a trade"] != nil }

        // The composer's action is there to run only once the popover draws it.
        XCTAssertNil(PressableButtons.actions["Offer"])
        XCTAssertTrue(PressableButtons.press("Offer a trade"))
        spin(until: "the popover's composer") { PressableButtons.actions["Offer"] != nil }
        draft.words = "Timber for grain."
        XCTAssertTrue(PressableButtons.press("Offer"))
        guard case .offerTrade(_, let to, let words)? = link.sent.last else { return XCTFail("The trade is offered: \(link.sent)") }
        XCTAssertEqual(to, house.id)
        XCTAssertEqual(words, "Timber for grain.")
        XCTAssertFalse(draft.isComposingTrade, "The popover is put away")
    }

    /// The windows showing now, by identity.
    private var windowsShowing: Set<ObjectIdentifier> { Set(NSApp.windows.filter(\.isVisible).map(ObjectIdentifier.init)) }

    /// The window that has come to show since `before`, the one attached to
    /// `window` if AppKit attached it: the popover. Nil if none did, or if
    /// more than one could be it. A window shown again counts as well as a new one.
    private func windowShown(since before: Set<ObjectIdentifier>, over window: NSWindow) -> NSWindow? {
        let shown = NSApp.windows.filter { $0.isVisible && !before.contains(ObjectIdentifier($0)) }
        let attached = shown.filter { $0.parent === window }
        if attached.count == 1 { return attached[0] }
        return attached.isEmpty && shown.count == 1 ? shown[0] : nil
    }

    /// A window hosting a view, for typing into.
    private func window(hosting view: some View, width: CGFloat, height: CGFloat) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.autorecalculatesKeyViewLoop = true
        window.contentView = NSHostingView(rootView: view)
        window.orderFrontRegardless()
        window.makeKey()
        return window
    }

    /// Tabs to the first field that takes text, as a keeper would, once the
    /// window has laid out what it hosts, and returns AppKit's own editor for
    /// it: through the window's key view loop, or failing that, Tab pressed
    /// in what the window hosts, which SwiftUI's focus answers.
    private func tabToTextField(in window: NSWindow) -> NSTextView? {
        let tab = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: window.windowNumber,
                                   context: nil, characters: "\t", charactersIgnoringModifiers: "\t", isARepeat: false, keyCode: 48)!
        func editor() -> NSTextView? {
            guard let editor = window.firstResponder as? NSTextView, editor.isEditable else { return nil }
            return editor
        }
        let deadline = Date().addingTimeInterval(5)
        repeat {
            window.contentView?.layoutSubtreeIfNeeded()
            window.displayIfNeeded()
            _ = window.makeFirstResponder(nil)
            for _ in 0..<12 {
                window.selectNextKeyView(nil)
                if let editor = editor() { return editor }
            }
            if let host = window.contentView, window.makeFirstResponder(host) {
                for _ in 0..<12 {
                    window.sendEvent(tab)
                    if let editor = editor() { return editor }
                }
            }
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        } while Date() < deadline
        return nil
    }

    /// Types, as the text system delivers each keystroke to what is being typed in.
    private func type(_ text: String, into editor: NSTextView) {
        for character in text {
            editor.insertText(String(character), replacementRange: NSRange(location: NSNotFound, length: 0))
        }
    }

    /// Runs the row's trade button's own action, waits for the popover's
    /// window to come to show and for its composer to be drawn there, and
    /// returns that window. Its actions run through PressableButtons: this
    /// covers what they do, not a click on them.
    private func openTheTrade(over window: NSWindow) -> NSWindow? {
        let before = windowsShowing
        spin(until: "the row's trade button") { PressableButtons.actions["Offer a trade"] != nil }
        XCTAssertTrue(PressableButtons.press("Offer a trade"))
        // From here, only what is drawn anew can be run: the popover's composer.
        PressableButtons.isListening = false
        PressableButtons.isListening = true
        spin(until: "the popover's composer") { PressableButtons.actions["Offer"] != nil }
        spin(until: "the popover's window") { windowShown(since: before, over: window) != nil }
        return windowShown(since: before, over: window)
    }

    /// Opens the trade, offers it by the action of the composer its popover
    /// holds, and waits for that popover's window to go.
    private func offerATrade(_ draft: OfferDraft, over window: NSWindow) {
        weak var popover = openTheTrade(over: window)
        XCTAssertNotNil(popover, "The popover's window")
        XCTAssertTrue(PressableButtons.press("Offer"))
        XCTAssertFalse(draft.isComposingTrade)
        spin(until: "the popover put away") { popover?.isVisible != true }
    }

    func testWhatIsTypedAndPastedInTheWordsFieldIsWhatIsOffered() throws {
        let (session, link, house) = keepersHouse("words typed in a window")
        let draft = OfferDraft(for: house)
        let window = window(hosting: HouseRow(session: session, house: house, draft: draft)
            .frame(width: 340).padding(20).background(Color.black), width: 380, height: 460)
        defer { window.close() }
        let board = NSPasteboard(name: NSPasteboard.Name("online.nullmere.tests.\(UUID().uuidString)"))
        defer { board.releaseGlobally() }
        func offered() -> (to: Int, words: String?)? {
            guard case .offerTrade(_, let to, let words)? = link.sent.last else { return nil }
            return (to, words)
        }

        // Pasted past what an envoy carries: the field shows, and the draft
        // keeps, what it carries, and the field is still being typed in.
        let editor = try XCTUnwrap(tabToTextField(in: window), "The words' field; the window's first responder is \(String(describing: window.firstResponder))")
        let long = String(repeating: "Grain for stone. ", count: 12)
        let kept = String(long.prefix(Envoy.wordsLimit))
        _ = board.clearContents()
        XCTAssertTrue(board.setString(long, forType: .string))
        XCTAssertTrue(editor.readSelection(from: board, type: .string), "Pasted")
        spin(until: "the paste cut to what an envoy carries") { editor.string == kept && draft.words == kept }
        XCTAssertTrue(window.firstResponder === editor, "Still being typed in")

        // Typed further, each keystroke is taken back.
        type("More", into: editor)
        spin(until: "the keystrokes taken back") { editor.string == kept && draft.words == kept }

        // Offered from the trade's own popover: to that keeper, with those
        // words; the popover goes and the words with it.
        offerATrade(draft, over: window)
        XCTAssertEqual(offered()?.to, house.id)
        XCTAssertEqual(offered()?.words, kept)
        XCTAssertEqual(draft.words, "")

        // Again: the field starts empty, and the new words go, not the old.
        let again = try XCTUnwrap(tabToTextField(in: window), "The words' field, a second time")
        XCTAssertEqual(again.string, "", "No stale words in the field")
        type("Timber for grain.", into: again)
        spin(until: "the new words") { again.string == "Timber for grain." && draft.words == "Timber for grain." }
        offerATrade(draft, over: window)
        XCTAssertEqual(offered()?.to, house.id)
        XCTAssertEqual(offered()?.words, "Timber for grain.")
        XCTAssertEqual(offers(link), 2, "Two offers, each once")
        let last = try XCTUnwrap(tabToTextField(in: window))
        XCTAssertEqual(last.string, "", "Nothing stale after the second offer either")
    }

    func testATradePutAwayUnofferedKeepsItsWords() throws {
        let (session, link, house) = keepersHouse("a trade put away unoffered")
        let draft = OfferDraft(for: house)
        let window = window(hosting: HouseRow(session: session, house: house, draft: draft)
            .frame(width: 340).padding(20).background(Color.black), width: 380, height: 460)
        defer { window.close() }
        let editor = try XCTUnwrap(tabToTextField(in: window), "The words' field")
        type("Hear us out.", into: editor)
        spin(until: "the words kept") { draft.words == "Hear us out." }

        // Put away as Escape puts a popover away: its command, cancelOperation,
        // taken along the responder chain of the popover's window. The
        // popover's binding must write back that the trade is put away.
        weak var popover = openTheTrade(over: window)
        let shown = try XCTUnwrap(popover, "The popover's window")
        let focus: NSResponder = shown.firstResponder ?? shown
        XCTAssertTrue(focus.tryToPerform(#selector(NSResponder.cancelOperation(_:)), with: nil), "Escape's command taken")
        spin(until: "the popover put away") { popover?.isVisible != true }
        spin(until: "the binding written back") { !draft.isComposingTrade }
        XCTAssertEqual(draft.words, "Hear us out.", "The words wait for the next offer")
        XCTAssertEqual(offers(link), 0, "Nothing offered")
    }

    func testTheHousesPanelLetsItsWordsGoWhenItCloses() throws {
        let (session, _, _) = keepersHouse("words let go")
        session.panel = .houses
        let window = window(hosting: HousesPanelHost(session: session), width: 420, height: 760)
        defer { window.close() }

        let editor = try XCTUnwrap(tabToTextField(in: window), "The words' field in the open panel")
        type("Hear us.", into: editor)
        spin(until: "the words shown") { editor.string == "Hear us." }

        // Closed, then opened again: the panel's words went with it.
        session.panel = nil
        spin(until: "the field gone with the panel") { !(window.firstResponder is NSTextView) }
        session.panel = .houses
        let again = try XCTUnwrap(tabToTextField(in: window), "The words' field once the panel is open again")
        XCTAssertEqual(again.string, "", "Opened again, the panel starts afresh")
    }

    func testAHouseThatChangesHandsWhileATradeIsComposedSendsNothingStale() throws {
        let (session, link, house) = keepersHouse("hands change mid-trade", lastInThePanel: true)
        session.panel = .houses
        let window = window(hosting: HousesPanelHost(session: session), width: 420, height: 760)
        defer { window.close() }

        // Words for the keeper there, typed into the field.
        let editor = try XCTUnwrap(tabToTextField(in: window), "The words' field in the open panel")
        type("For the keeper there.", into: editor)
        spin(until: "the words shown") { editor.string == "For the keeper there." }

        // The trade open in its popover, and the action of the composer it
        // holds kept, as a click already on its way would be.
        weak var popover = openTheTrade(over: window)
        XCTAssertNotNil(popover, "The popover's window")
        let staleOffer = try XCTUnwrap(PressableButtons.actions["Offer"])
        let before = offers(link)

        // The seat passes to another keeper at the realm's word: the old
        // trade's popover goes, and what it holds sends nothing.
        var handed = session.state
        handed.houses[house.id].name = "Bel"
        link.onEvent?(.changed(handed))
        spin(until: "the old trade's popover gone") { popover?.isVisible != true }
        staleOffer()
        XCTAssertEqual(offers(link), before, "Nothing for the last keeper goes to the next")
        let forBel = try XCTUnwrap(tabToTextField(in: window), "The words' field for the next keeper")
        XCTAssertEqual(forBel.string, "", "The next keeper's field starts empty")

        // The first keeper's name again: nothing comes back.
        var back = session.state
        back.houses[house.id].name = house.name
        link.onEvent?(.changed(back))
        let again = try XCTUnwrap(tabToTextField(in: window), "The words' field, the first name again")
        XCTAssertEqual(again.string, "", "Nothing restored")

        // The stewards, then the same name kept again: still nothing restored.
        type("Once more.", into: again)
        spin(until: "the words shown") { again.string == "Once more." }
        var stewards = session.state
        stewards.houses[house.id].isPlayer = false
        link.onEvent?(.changed(stewards))
        spin(until: "the field gone with its keeper") { !(window.firstResponder is NSTextView) }
        var kept = session.state
        kept.houses[house.id].isPlayer = true
        link.onEvent?(.changed(kept))
        let last = try XCTUnwrap(tabToTextField(in: window), "The words' field, kept again")
        XCTAssertEqual(last.string, "", "Kept again under the same name, the House starts afresh")
    }

    func testATradeBeingComposedGoesWithItsButton() throws {
        let (session, link, house) = keepersHouse("a trade put away")
        let draft = OfferDraft(for: house)
        let window = window(hosting: HouseRow(session: session, house: house, draft: draft)
            .frame(width: 340).padding(20).background(Color.black), width: 380, height: 460)
        defer { window.close() }
        weak var popover = openTheTrade(over: window)
        XCTAssertNotNil(popover, "The popover's window")

        // War, at the realm's word: the row offers only peace, and the trade
        // being composed goes with the button that opened it.
        let peace = session.state
        var war = peace
        _ = try war.declareWar(by: house.id, on: session.player)
        link.onEvent?(.changed(war))
        spin(until: "the trade put away") { !draft.isComposingTrade && popover?.isVisible != true }

        // Peace again: the button returns, and no trade opens by itself.
        let quiet = windowsShowing
        PressableButtons.isListening = false
        PressableButtons.isListening = true
        link.onEvent?(.changed(peace))
        spin(until: "the trade button back") { PressableButtons.actions["Offer a trade"] != nil }
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertFalse(draft.isComposingTrade)
        XCTAssertNil(windowShown(since: quiet, over: window), "No popover opens by itself")
    }

    func testATradeIsComposedAndOffered() throws {
        let state = GameState(settings: GameSettings(seedText: "pressed trade", houseCount: 4, radius: 18))
        let (session, link) = session(state)
        let other = try XCTUnwrap(session.state.houses.first { $0.id != session.player })
        var offered: Trade?
        draw(TradeComposer(house: other, stock: session.playerHouse.stock) { offered = $0 }, width: 300, height: 320)
        XCTAssertTrue(PressableButtons.press("Offer"), "Among \(shown)")
        let trade = try XCTUnwrap(offered)
        session.offerTrade(trade, to: other, words: "")
        guard case .offerTrade(let sent, to: let to, words: _)? = link.sent.last else { return XCTFail("The trade is sent") }
        XCTAssertEqual(sent, trade)
        XCTAssertEqual(to, other.id)
    }

    func testAHoldsWorksMustersAndBarterAreOrdered() throws {
        var state = GameState(settings: GameSettings(seedText: "pressed works", houseCount: 4, radius: 18))
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == state.player && $0.isSeat })
        // Stores full of grain and stone, with room left for timber bought by barter.
        let room = state.storage(of: state.player)
        state.houses[state.player].stock = Stock(grain: room, timber: room / 4, stone: room, moonsalt: 60)
        state.holds[seat].project = nil
        state.holds[seat].training = nil
        let (session, link) = session(state)
        session.selection = .hold(state.holds[seat].id)
        draw(SelectionPanel(session: session), height: 1400)
        XCTAssertTrue(PressableButtons.press("Build I"), "Among \(shown)")
        XCTAssertTrue(link.sent.contains { if case .build = $0 { return true } else { return false } })
        XCTAssertTrue(PressableButtons.press("Train"))
        XCTAssertTrue(link.sent.contains { if case .train = $0 { return true } else { return false } })
        XCTAssertTrue(PressableButtons.press("Barter"))
        XCTAssertTrue(link.sent.contains { if case .barter = $0 { return true } else { return false } })
    }

    func testACompanysOrders() throws {
        var state = GameState(settings: GameSettings(seedText: "pressed company", houseCount: 4, radius: 18))
        let me = state.player
        // A lantern made a founder where a hold may rise.
        let lantern = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind == .lantern })
        state.units[lantern].kind = .founder
        let site = try XCTUnwrap(state.map.hexes.first { hex in state.unit(at: hex) == nil && state.canFound(at: hex, for: me) == nil })
        state.units[lantern].position = site
        let (session, link) = session(state)
        let spear = try XCTUnwrap(session.state.units(of: me).first { $0.kind == .spear })
        session.selection = .unit(spear.id)
        draw(SelectionPanel(session: session), height: 600)
        XCTAssertTrue(PressableButtons.press("Fortify"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .fortify(unit: spear.id))
        XCTAssertTrue(PressableButtons.press("Disband"))
        XCTAssertEqual(link.sent.last, .disband(unit: spear.id))

        let founder = state.units[lantern].id
        session.selection = .unit(founder)
        draw(SelectionPanel(session: session), height: 600)
        XCTAssertTrue(PressableButtons.press("Found Hold"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .found(unit: founder))

        // A company on the march may be halted.
        guard let walker = session.state.units(of: me).first(where: { $0.kind != .founder && $0.movesLeft > 0 }),
              let far = session.state.map.hexes.first(where: { hex in
                  hex.distance(to: walker.position) >= 8 && session.state.path(for: walker, to: hex) != nil
              })
        else { return }
        XCTAssertTrue(session.perform(.move(unit: walker.id, to: far)))
        session.selection = .unit(walker.id)
        draw(SelectionPanel(session: session), height: 600)
        if session.state.unit(walker.id)?.destination != nil {
            XCTAssertTrue(PressableButtons.press("Halt"), "Among \(shown)")
            XCTAssertEqual(link.sent.last, .halt(unit: walker.id))
        }
    }

    func testTheTopBarsPanelsAndReady() throws {
        let state = GameState(settings: GameSettings(seedText: "pressed bar", houseCount: 4, radius: 18))
        let (session, link) = session(state)
        draw(TopBar(session: session), width: 1200, height: 90)
        for (label, panel) in [("Houses", GameSession.Panel.houses), ("Chronicle", .chronicle), ("Guide", .guide)] {
            XCTAssertTrue(PressableButtons.press(label), "Among \(shown)")
            XCTAssertEqual(session.panel, panel)
            XCTAssertTrue(PressableButtons.press(label))
            XCTAssertNil(session.panel, "Pressed again, it closes")
        }
        XCTAssertTrue(PressableButtons.press("Ready"))
        XCTAssertTrue(session.isReady)
        XCTAssertEqual(link.readies.last, true)
        draw(TopBar(session: session), width: 1200, height: 90)
        XCTAssertTrue(PressableButtons.press("Waiting"), "Among \(shown)")
        XCTAssertFalse(session.isReady)
        XCTAssertEqual(link.readies.last, false)
    }
}

/// The front door's, an ending's and the first cards' buttons, pressed.
@MainActor
final class PressDoorTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 1100, height: CGFloat = 720) {
        PressableButtons.isListening = true
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    private var shown: [String] { PressableButtons.actions.keys.sorted() }

    private func app(_ seed: String) -> GameApp {
        let address = GameApp.RealmAddress.hosted(seed: seed)
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: address))
        return GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: address,
                       identity: FileIdentityStore(url: dir.appendingPathComponent("identity")), opensAtOnce: false)
    }

    func testTheFrontDoorsButtons() throws {
        let app = app("door buttons")
        var left = 0
        app.onLeave = { left += 1 }
        app.checkModel()
        draw(FrontDoor(app: app))
        XCTAssertTrue(PressableButtons.press("Back"), "Among \(shown)")
        XCTAssertEqual(left, 1, "Back to the launcher")

        // A realm out of reach: Try Again reaches for it once more.
        app.hear(.unreachable("No answer from the realm's server."))
        draw(FrontDoor(app: app))
        XCTAssertTrue(PressableButtons.press("Try Again"), "Among \(shown)")
        XCTAssertNotEqual(app.door, .unreachable("No answer from the realm's server."))
    }

    func testAnEndingsButtons() throws {
        let app = app("ending buttons")
        app.checkModel()
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        let outcome = Outcome(winner: session.player, kind: .dominion, watch: session.state.watch)
        draw(OutcomeOverlay(app: app, session: session, outcome: outcome))
        XCTAssertTrue(PressableButtons.press("Look upon the lake"), "Among \(shown)")
        XCTAssertTrue(PressableButtons.press("Leave the world"))
        XCTAssertNil(app.session, "Back at the front door")
    }

    func testTheFirstCardsButtons() throws {
        let state = GameState(settings: GameSettings(seedText: "first cards", houseCount: 4, radius: 18))
        var begun = 0, back = 0
        draw(SeatBriefingCard(briefing: SeatBriefing(world: state, player: state.player), colour: .white) { begun += 1 }, width: 600, height: 500)
        XCTAssertTrue(PressableButtons.press("Begin"), "Among \(shown)")
        XCTAssertEqual(begun, 1)
        var later = state
        for _ in 0..<4 {
            _ = later.stewardTurn(for: later.player)
            _ = later.endWatch()
        }
        let seen = LastSeen(watch: state.watch, stock: state.houses[state.player].stock, holds: state.holds(of: state.player).count)
        let report = try XCTUnwrap(AwayReport(since: seen, now: later, player: state.player))
        draw(AwayCard(report: report) { back += 1 }, width: 600, height: 500)
        XCTAssertTrue(PressableButtons.press("Back to It"), "Among \(shown)")
        XCTAssertEqual(back, 1)
    }
}

/// The Houses panel as the game shows it: there while the session says so.
private struct HousesPanelHost: View {
    let session: GameSession

    var body: some View {
        ZStack(alignment: .top) {
            Color.black
            if session.panel == .houses {
                HousesPanel(session: session)
            }
        }
        .frame(width: 400, height: 740)
    }
}

/// How many changes an observer heard. Observers are told on the thread
/// that makes the change, here the test's own.
private final class Heard: @unchecked Sendable {
    var count = 0
}

private final class RecordingLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    private(set) var sent: [Command] = []
    private(set) var readies: [Bool] = []
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) { sent.append(command) }
    func setReady(_ ready: Bool) { readies.append(ready) }
    func leave() {}
}

/// The panels' buttons clicked with the mouse in a real window: a click
/// reaches a button's action, a disabled button ignores it, and a button
/// that asks twice acts only on the second click.
@MainActor
final class ClickTests: XCTestCase {
    private var window: NSWindow?

    override func tearDown() async throws {
        window?.close()
        window = nil
    }

    private func spin(_ seconds: Double = 0.15) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    private func host(_ view: some View) -> NSWindow {
        let window = NSWindow(contentRect: NSRect(x: 200, y: 200, width: 240, height: 80), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view.frame(width: 240, height: 80).background(Color.black))
        window.makeKeyAndOrderFront(nil)
        window.orderFrontRegardless()
        window.contentView?.layoutSubtreeIfNeeded()
        self.window = window
        spin()
        return window
    }

    /// A click at the window's centre, as the mouse makes one.
    private func click(_ window: NSWindow) {
        let centre = NSPoint(x: 120, y: 40)
        for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
            let event = NSEvent.mouseEvent(with: type, location: centre, modifierFlags: [], timestamp: ProcessInfo.processInfo.systemUptime,
                                           windowNumber: window.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
            window.sendEvent(event)
        }
        spin()
    }

    func testAClickReachesAButtonAndADisabledOneIgnoresIt() {
        var pressed = 0
        let enabled = host(QuietButton(title: "Ready", size: 12, prominent: true) { pressed += 1 }.frame(width: 240, height: 80))
        click(enabled)
        XCTAssertEqual(pressed, 1, "The click reaches the button")
        enabled.close()

        let disabled = host(QuietButton(title: "Ready", size: 12, enabled: false) { pressed += 1 }.frame(width: 240, height: 80))
        click(disabled)
        XCTAssertEqual(pressed, 1, "A disabled button ignores the click")
    }

    func testAButtonThatAsksTwiceActsOnTheSecondClick() {
        var acted = 0
        let window = host(ConfirmButton(title: "Declare war", confirm: "War on House Venn?", size: 12) { acted += 1 }.frame(width: 240, height: 80))
        click(window)
        XCTAssertEqual(acted, 0, "The first click asks")
        click(window)
        XCTAssertEqual(acted, 1, "The second acts")
    }
}
