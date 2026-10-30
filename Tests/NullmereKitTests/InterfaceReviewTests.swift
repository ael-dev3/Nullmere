import Foundation
import LauncherCore
@testable import LauncherKit
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
        let state = GameState(settings: GameSettings(seedText: "whose House", keepers: 1))
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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "a second age", keepers: 1)), store: second)
        XCTAssertNotNil(session.seatBriefing)
        XCTAssertNil(session.firstSteps, "Done once, not asked again")
    }

    func testAnOfferThatCantBeKeptCantBeAccepted() throws {
        var state = GameState(settings: GameSettings(seedText: "unpayable", keepers: 1))
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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "no pointer", keepers: 1)), store: LocalStore(directory: dir))
        // The seat's briefing, first in an age, keeps the keys until put away.
        XCTAssertFalse(session.handle(.pan(dx: 0, dy: 0)))
        session.dismissSeatBriefing()
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
        session.voiceOverRunning = { true }
        let items = session.mapItems
        let mine = items.filter { !$0.orders.isEmpty }
        XCTAssertFalse(mine.isEmpty)
        XCTAssertTrue(mine.allSatisfy { $0.orders.count <= MapAccessibility.ordersOffered })
        XCTAssertTrue(mine.flatMap(\.orders).contains { $0.name.hasPrefix("March to ") })
        XCTAssertEqual(items, MapAccessibility.items(for: session), "Kept for the world as it is")
    }

    func testVoiceOverOffersAStrikeAtAFoeInReach() throws {
        var state = GameState(settings: GameSettings(seedText: "a strike offered", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player
        let spear = try XCTUnwrap(state.units.first { $0.owner == me && $0.kind == .spear })
        let foe = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        let beside = try XCTUnwrap(state.map.neighbors(of: spear.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        state.units.append(NullmereCore.Unit(id: state.nextID, kind: .spear, owner: foe, position: beside))
        state.nextID += 1
        let index = try XCTUnwrap(state.relations.firstIndex { $0.first == min(me, foe) && $0.second == max(me, foe) })
        state.relations[index].stance = .war
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.voiceOverRunning = { true }
        let item = try XCTUnwrap(session.mapItems.first { $0.selection == .unit(spear.id) })
        let strike = try XCTUnwrap(item.orders.first?.name)
        XCTAssertTrue(strike.hasPrefix("Strike the Spears of \(state.houses[foe].title), beside it, "), strike)
        XCTAssertTrue(strike.contains("they take") && strike.contains("you take"), "With its odds: \(strike)")
        XCTAssertEqual(item.orders.first?.hex, beside)
    }

    func testARefusalFromTheRealmIsTold() throws {
        var realm = RealmState(name: "The Nullmere", seed: "a refusal", seats: 4, radius: 18, watchLength: 600, now: 0)
        let house = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let host = LocalRealm(state: realm)
        let link = host.link(identity: "id-ama")
        let session = GameSession(link: link, house: house, world: try XCTUnwrap(realm.view(for: "id-ama")).world,
                                  store: LocalStore(directory: dir), host: host)
        link.onEvent?(.refused(.noSeat))
        XCTAssertEqual(session.notices.last?.text, RealmError.noSeat.description)
    }

    func testTheFallenKeepWayBackStaysInReachAfterLookingOn() throws {
        var realm = RealmState(name: "The Nullmere", seed: "looking on", seats: 4, radius: 18, watchLength: 600, now: 0)
        let ama = try XCTUnwrap(realm.arrive("id-ama", name: "Ama", now: 1).house)
        let bel = try XCTUnwrap(realm.arrive("id-bel", name: "Bel", now: 1).house)
        for index in realm.world.holds.indices where realm.world.holds[index].owner == bel {
            realm.world.holds[index].owner = ama
            realm.world.holds[index].isSeat = false
        }
        realm.world.units.removeAll { $0.owner == bel }
        realm.world.houses[bel].isEliminated = true
        let host = LocalRealm(state: realm)
        let link = host.link(identity: "id-bel")
        let session = GameSession(link: link, house: bel, world: try XCTUnwrap(realm.view(for: "id-bel")).world,
                                  store: LocalStore(directory: dir), host: host)
        link.connect()
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: "looking on"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        // Listening before anything is drawn, so every button drawn is heard.
        PressableButtons.isListening = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 960, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: FallenOverlay(app: app, session: session))
        window.orderFrontRegardless()
        defer { window.close() }
        var deadline = Date().addingTimeInterval(3)
        while PressableButtons.actions["Look upon the lake"] == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(PressableButtons.press("Look upon the lake"))
        PressableButtons.forget("Take up an open seat")
        deadline = Date().addingTimeInterval(3)
        while PressableButtons.actions["Take up an open seat"] == nil, Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        var seated: Keeper?
        session.onNewAge = { keeper, _ in seated = keeper }
        XCTAssertTrue(PressableButtons.press("Take up an open seat"), "Still in reach while looking on")
        XCTAssertNotNil(seated?.house)
        window.contentView = nil
    }

    func testTheEnvoyCardsButtonsAnswer() throws {
        var state = GameState(settings: GameSettings(seedText: "answered by press", keepers: 1))
        let me = state.player
        let steward = try XCTUnwrap(state.houses.first { !$0.isPlayer }).id
        state.envoys.append(Envoy(id: state.nextID, from: steward, to: me, proposal: .tribute, arrived: state.watch))
        state.nextID += 1
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        PressableButtons.isListening = true
        draw(EnvoyCards(session: session), width: 360, height: 400)
        XCTAssertTrue(PressableButtons.press("Accept"), "Paid, the peace kept")
        XCTAssertTrue(session.state.envoys.isEmpty)
    }

    func testTheMapWithoutMetalStillGivesOrders() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "no metal", keepers: 1)), store: LocalStore(directory: dir))
        let lantern = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .lantern })
        WorldFallback.tap(lantern.position, in: session)
        XCTAssertEqual(session.selection, .unit(lantern.id), "A click selects")
        let target = try XCTUnwrap(session.reach.first { $0.distance(to: lantern.position) == 2 })
        WorldFallback.tap(target, in: session)
        XCTAssertEqual(session.state.unit(lantern.id)?.position, target, "A click where it would march, marches")

        // Dragged and pinched as the Metal map is.
        let before = session.camera
        WorldFallback.drag(by: CGSize(width: 28, height: 0), in: session)
        XCTAssertEqual(session.camera.centerX, before.centerX - 28 / before.scale, accuracy: 1e-9)
        WorldFallback.zoom(by: 1.5, around: CGPoint(x: 480, y: 300), in: CGSize(width: 960, height: 600), session: session)
        XCTAssertEqual(session.camera.scale, before.scale * 1.5, accuracy: 1e-9)
    }

    func testAFallenKeeperIsOfferedOnlyWhatHelps() throws {
        var state = GameState(settings: GameSettings(seedText: "offered what helps", keepers: 1))
        state.houses[state.player].isEliminated = true
        XCTAssertNil(Counsel.advice(for: state, player: state.player))
        let store = LocalStore(directory: dir)
        let session = GameSession(state: state, store: store)
        XCTAssertNil(session.counsel)
        let app = GameApp(store: store, readiness: { .ready }, sound: false, address: .hosted(seed: "offered what helps"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        draw(FallenOverlay(app: app, session: session))
        XCTAssertEqual(OutcomeOverlay.nextAge(secondsLeft: 134), "A new age begins on a fresh lake in 2:14, and keepers are seated anew in the order they first came, as seats allow.")
        XCTAssertEqual(OutcomeOverlay.nextAge(secondsLeft: nil), "A new age begins on a fresh lake when the watch turns, and keepers are seated anew in the order they first came, as seats allow.")
    }

    func testWhatTheBarAndPanelsReadIsTheWorldsOwn() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "kept for the world", keepers: 1)), store: LocalStore(directory: dir))
        XCTAssertEqual(session.standings, session.state.standings())
        XCTAssertNotNil(session.counsel, "The opening has counsel")
        XCTAssertEqual(session.counsel, Counsel.advice(for: session.state, player: session.player))
        XCTAssertEqual(session.counsel, Counsel.advice(for: session.state, player: session.player), "Kept, and kept the same")
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

    /// An amount typed into a trade or a barter is kept within its bounds:
    /// never under one, never over what the stores allow.
    func testAnAmountTypedIsKeptWithinItsBounds() {
        XCTAssertEqual(AmountField.kept(0, most: 40), 1)
        XCTAssertEqual(AmountField.kept(-5, most: 40), 1)
        XCTAssertEqual(AmountField.kept(25, most: 40), 25)
        XCTAssertEqual(AmountField.kept(4_000, most: 40), 40)
        XCTAssertEqual(AmountField.kept(7, most: 0), 1, "Nothing to give still offers one, which the offer then refuses")
    }
}
