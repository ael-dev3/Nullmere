import Foundation
import LauncherKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The world's interface as a fresh review found it wanting, put right: the
/// away report knows whose House it tells of, the first steps are taken
/// once, offers that can't be kept can't be accepted, a barter says why it
/// would be refused, the tally counts only holds founded, a company can be
/// ordered without a pointer, a fallen keeper is offered only what helps,
/// and what the bar and panels read is worked out once for each world.
@MainActor
final class InterfaceReviewTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 960, height: CGFloat = 600) {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    func testTheAwayReportTellsOnlyOfTheHouseLastSeen() throws {
        let state = GameState(settings: GameSettings(seedText: "whose House"))
        let store = LocalStore(directory: dir)
        let other = (state.player + 1) % state.houses.count
        store.saveLastSeen(LastSeen(watch: 0, stock: .zero, holds: 9, house: other))
        let elsewhere = GameSession(state: state, store: store)
        XCTAssertNil(elsewhere.awayReport, "Another House's figures are not this one's")
        XCTAssertNotNil(elsewhere.seatBriefing, "A House new to the keeper is briefed")

        store.saveLastSeen(LastSeen(watch: 0, stock: .zero, holds: 9, house: state.player))
        let back = GameSession(state: state, store: store)
        XCTAssertNotNil(back.awayReport)
        XCTAssertNil(back.seatBriefing)
    }

    func testTheFirstStepsAreTakenOnceAcrossAges() throws {
        let root = LocalStore(directory: dir)
        var steps = FirstSteps()
        for step in FirstSteps.Step.allCases { steps.mark(step) }
        root.forAge(1, of: "a realm").saveFirstSteps(steps)
        let second = root.forAge(2, of: "a realm")
        XCTAssertEqual(second.loadFirstSteps(), steps, "Kept across ages")
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "a second age")), store: second)
        XCTAssertNotNil(session.seatBriefing)
        XCTAssertNil(session.firstSteps, "Done once, not asked again")
    }

    func testAnOfferThatCantBeKeptCantBeAccepted() throws {
        var state = GameState(settings: GameSettings(seedText: "unpayable"))
        let me = state.player
        let other = (me + 1) % state.houses.count
        let trade = Trade(give: .grain, 10, for: .moonsalt, 40)
        let envoy = Envoy(id: 90, from: other, to: me, proposal: .trade, arrived: 1, trade: trade)
        state.houses[me].stock.moonsalt = 39
        XCTAssertFalse(EnvoyCards.canAccept(envoy, in: state, player: me))
        state.houses[me].stock.moonsalt = 40
        XCTAssertTrue(EnvoyCards.canAccept(envoy, in: state, player: me))
        XCTAssertTrue(EnvoyCards.canAccept(Envoy(id: 91, from: other, to: me, proposal: .tribute, arrived: 1), in: state, player: me))
    }

    func testABarterSaysWhyItWouldBeRefused() {
        let stock = Stock(grain: 90, timber: 290, stone: 0, moonsalt: 0)
        XCTAssertEqual(BarterRow.problem(give: .grain, take: .grain, amount: 10, stock: stock, room: 300), "Choose two different stores.")
        XCTAssertEqual(BarterRow.problem(give: .stone, take: .grain, amount: 10, stock: stock, room: 300), "You have only 0 stone.")
        XCTAssertEqual(BarterRow.problem(give: .grain, take: .timber, amount: 20, stock: stock, room: 300), "No room to store that much timber.")
        XCTAssertNil(BarterRow.problem(give: .grain, take: .timber, amount: 10, stock: stock, room: 300))
    }

    func testTheTallyCountsOnlyHoldsFounded() throws {
        var realm = RealmState(name: "The Nullmere", seed: "a tally", seats: 4, radius: 18, watchLength: 600, now: 0)
        let house = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        XCTAssertTrue(realm.world.chronicle.contains { $0.kind == .seating && $0.houses.first == house })
        XCTAssertTrue(StoryChart.summary(of: realm.world, player: house).contains("you founded 0 holds"))
    }

    func testACompanyIsOrderedWithoutAPointer() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "no pointer")), store: LocalStore(directory: dir))
        XCTAssertEqual(KeyBridgeView.key(for: NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                                                  context: nil, characters: "m", charactersIgnoringModifiers: "m",
                                                                  isARepeat: false, keyCode: 46)!), .orderAtCentre)
        XCTAssertFalse(session.handle(.orderAtCentre), "Nothing chosen, nothing ordered")
        let spear = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .spear })
        session.selection = .unit(spear.id)
        let target = try XCTUnwrap(session.reach.first { $0.distance(to: spear.position) == 1 })
        // Panned there: the view's middle is where it would go, as a pointer shows.
        session.camera.focus(on: target)
        XCTAssertTrue(session.handle(.pan(dx: 0, dy: 0)))
        XCTAssertEqual(session.hovered, session.camera.centreHex)
        XCTAssertTrue(session.handle(.orderAtCentre))
        XCTAssertEqual(session.state.unit(spear.id)?.position, target)

        // VoiceOver offers the same, as actions on each company.
        let items = session.mapItems
        let mine = items.filter { !$0.orders.isEmpty }
        XCTAssertFalse(mine.isEmpty)
        XCTAssertTrue(mine.allSatisfy { $0.orders.count <= MapAccessibility.ordersOffered })
        XCTAssertTrue(mine.flatMap(\.orders).contains { $0.name.hasPrefix("March to ") })
        XCTAssertEqual(items, MapAccessibility.items(for: session), "Kept for the world as it is")
    }

    func testTheMapWithoutMetalStillGivesOrders() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "no metal")), store: LocalStore(directory: dir))
        let lantern = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .lantern })
        WorldFallback.tap(lantern.position, in: session)
        XCTAssertEqual(session.selection, .unit(lantern.id), "A click selects")
        let target = try XCTUnwrap(session.reach.first { $0.distance(to: lantern.position) == 2 })
        WorldFallback.tap(target, in: session)
        XCTAssertEqual(session.state.unit(lantern.id)?.position, target, "A click where it would march, marches")
    }

    func testAFallenKeeperIsOfferedOnlyWhatHelps() throws {
        var state = GameState(settings: GameSettings(seedText: "offered what helps"))
        state.houses[state.player].isEliminated = true
        XCTAssertNil(Counsel.advice(for: state, player: state.player))
        let store = LocalStore(directory: dir)
        let app = GameApp(store: store, readiness: { .ready }, sound: false, address: .hosted(seed: "offered what helps"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        app.open()
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        XCTAssertTrue(GameMenu.stayReady.isEnabled(in: app))
        draw(FallenOverlay(app: app, session: session))
        XCTAssertEqual(OutcomeOverlay.nextAge(secondsLeft: 134), "A new age begins on a fresh lake in 2:14, and every keeper is seated anew.")
        XCTAssertEqual(OutcomeOverlay.nextAge(secondsLeft: nil), "A new age begins on a fresh lake when the watch turns, and every keeper is seated anew.")
        app.leaveWorld()
        app.leaveDoor()
    }

    func testWhatTheBarAndPanelsReadIsTheWorldsOwn() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "kept for the world")), store: LocalStore(directory: dir))
        XCTAssertEqual(session.standings, session.state.standings())
        XCTAssertEqual(session.counsel, Counsel.advice(for: session.state, player: session.player))
        for hold in session.state.holds {
            XCTAssertEqual(session.holdsByPosition[hold.position]?.id, hold.id)
        }
        // The world changes: the ledger follows.
        let before = session.ledger.income
        let spear = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .spear })
        session.perform(.disband(unit: spear.id))
        XCTAssertEqual(session.ledger.upkeep, session.state.upkeep(of: session.player))
        XCTAssertEqual(session.ledger.income, before)
    }

    func testTheGateLeadsBackToTheLauncher() throws {
        var readiness = ModelReadiness.modelNotReady
        let app = GameApp(store: LocalStore(directory: dir), readiness: { readiness }, sound: false, address: .hosted(seed: "the gate"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        var left = false
        app.onLeave = { left = true }
        app.open()
        PressableButtons.isListening = true
        draw(ModelGate(app: app))
        XCTAssertTrue(PressableButtons.press("Back"))
        XCTAssertTrue(left)
        readiness = .ready
        XCTAssertFalse(ModelReadiness.modelNotReady.explanation.contains("launcher"), "Said as true in the game as in the launcher")
    }
}
