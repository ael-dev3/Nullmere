import AppKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The panels' buttons pressed as a keeper presses them: each panel is
/// drawn while the test listens, each button leaves its own action under
/// its title, and pressing it reaches the session and sends the order it
/// names to the realm.
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
        draw(HouseRow(session: session, house: other))
        XCTAssertTrue(PressableButtons.press("Offer a pact"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .propose(.pact, to: other.id))
        let gift = try XCTUnwrap(shown.first { $0.hasPrefix("Send ") }, "A gift to send, among \(shown)")
        XCTAssertTrue(PressableButtons.press(gift))
        guard case .gift(let to, _, _)? = link.sent.last else { return XCTFail("The gift is sent: \(link.sent)") }
        XCTAssertEqual(to, other.id)
        XCTAssertTrue(PressableButtons.press("Offer a trade"), "The trade opens to be composed")
        XCTAssertTrue(PressableButtons.press("Declare war"))
        XCTAssertEqual(link.sent.last, .declareWar(on: other.id))

        // At war, peace may be offered.
        draw(HouseRow(session: session, house: session.state.houses[other.id]))
        XCTAssertTrue(PressableButtons.press("Offer peace"), "Among \(shown)")
        XCTAssertEqual(link.sent.last, .propose(.peace, to: other.id))
        draw(HousesPanel(session: session), height: 900)
        XCTAssertFalse(shown.isEmpty)
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
        state.houses[state.player].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 200)
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
