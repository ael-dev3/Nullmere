@testable import NullmereCore
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereKit

/// Every panel a keeper sees draws, over a game well under way, at the
/// sizes a Mac shows it and with larger text: a panel that can't lay out
/// its world is caught here, not by a player.
@MainActor
final class PanelRenderTests: XCTestCase {
    private var dir: URL!

    override func setUp() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: dir)
        TextSize.shared.isLarger = false
    }

    private func busySession() -> GameSession {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "panels")), store: LocalStore(directory: dir))
        session.autoplay(watches: 40)
        return session
    }

    @discardableResult
    private func draw(_ view: some View, width: CGFloat, height: CGFloat? = nil) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(CGFloat(image.width), width)
        return image
    }

    func testThePanelsDrawAGameUnderWay() throws {
        let session = busySession()
        for larger in [false, true] {
            TextSize.shared.isLarger = larger
            try draw(ChroniclePanel(session: session), width: 360, height: 700)
            try draw(GuidePanel(session: session), width: 360, height: 700)
            try draw(HousesPanel(session: session), width: 360, height: 700)
            try draw(RaceTable(session: session), width: 360)
            try draw(StoryChart(state: session.state, player: session.player), width: 360, height: 180)
            for width in [960.0, 1512.0] {
                try draw(TopBar(session: session), width: width)
            }
            try draw(TopBar(session: session, compact: true), width: 760)
        }
    }

    func testTheSelectionPanelDrawsWhateverIsChosen() throws {
        let session = busySession()
        let state = session.state
        var choices: [GameSession.Selection] = [.none]
        if let unit = state.units.first(where: { $0.owner == session.player }) { choices.append(.unit(unit.id)) }
        if let unit = state.units.first(where: { $0.owner != session.player }) { choices.append(.unit(unit.id)) }
        if let hold = state.holds.first(where: { $0.owner == session.player }) { choices.append(.hold(hold.id)) }
        if let hold = state.holds.first(where: { $0.owner != session.player }) { choices.append(.hold(hold.id)) }
        if let hold = state.holds.first { choices.append(.tile(hold.position)) }
        // A company of every kind there is, and ground of every kind.
        for kind in UnitKind.allCases {
            if let unit = state.units.first(where: { $0.kind == kind }) { choices.append(.unit(unit.id)) }
        }
        for terrain in Terrain.allCases {
            if let hex = state.map.hexes.first(where: { state.map[$0]?.terrain == terrain && session.isExplored($0) }) {
                choices.append(.tile(hex))
            }
        }
        // A hold of the keeper's with works and a company under way.
        if let hold = state.holds.first(where: { $0.owner == session.player }) {
            _ = BuildingKind.allCases.contains { session.perform(.build(hold: hold.id, kind: $0)) }
            _ = UnitKind.allCases.contains { session.perform(.train(hold: hold.id, kind: $0)) }
            choices.append(.hold(hold.id))
        }
        XCTAssertGreaterThanOrEqual(choices.count, 4, "A game under way has companies and holds of its own and others'")
        for choice in choices {
            session.selection = choice
            try draw(SelectionPanel(session: session), width: 320, height: 600)
        }
    }

    func testEachStoreHasAnAccountToShow() throws {
        let session = busySession()
        for resource in Resource.allCases {
            let breakdown = IncomeBreakdown(state: session.state, house: session.player, resource: resource, territory: session.territory)
            try draw(IncomeCard(breakdown: breakdown), width: 300)
        }
    }

    func testTheFrontDoorAndSettingsDraw() throws {
        let identity = FileIdentityStore(url: dir.appendingPathComponent("identity"))
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: "front door")))
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false,
                          address: .hosted(seed: "front door"), identity: identity)
        app.checkModel()
        guard case .frontDoor = app.phase else { return XCTFail("A ready model opens the front door") }
        for width in [960.0, 1512.0] {
            try draw(FrontDoor(app: app), width: width, height: 700)
        }
        try draw(GameSettingsView(app: app), width: 480, height: 520)
        // Every way the realm can look from its door.
        let full = RealmStatus(name: "The Nullmere", age: 2, watch: 40, seats: 12, freeSeats: 0, keepers: 12, online: 9, ready: 3,
                               secondsLeft: 75, isEnding: false, present: ["Ama", "Bel", "Cor"], lake: "Twin")
        let ending = RealmStatus(name: "The Nullmere", age: 2, watch: 90, seats: 12, freeSeats: 4, keepers: 8, online: 1, ready: 0,
                                 secondsLeft: 5, isEnding: true)
        for door in [GameApp.Door.connecting, .unreachable("No answer from the server."), .open(full), .open(ending)] {
            try draw(RealmLine(door: door), width: 600)
        }
        try draw(Wordmark(), width: 600)
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        try draw(TopBar(session: session), width: 1200)
        try draw(GameSettingsView(app: app), width: 480, height: 520)
    }

    func testEveryStanceAndEveryEnvoyDraws() throws {
        var state = GameState(settings: GameSettings(seedText: "every stance", houseCount: 6, radius: 22))
        let me = state.player
        let others = state.houses.indices.filter { $0 != me }
        state.setStance(.war, between: me, and: others[0], by: me)
        state.setStance(.pact, between: me, and: others[1], by: me)
        state.houses[others[2]].isPlayer = true
        state.houses[others[3]].liege = me
        for (index, proposal) in Proposal.allCases.enumerated() {
            let trade = proposal == .trade ? Trade(give: .timber, 20, for: .grain, 15) : nil
            state.envoys.append(Envoy(id: 900 + index, from: others[index % others.count], to: me, proposal: proposal,
                                      arrived: state.watch, words: index == 0 ? "Hear us." : nil, trade: trade))
        }
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        for larger in [false, true] {
            TextSize.shared.isLarger = larger
            try draw(HousesPanel(session: session), width: 360, height: 900)
            for house in session.state.houses where house.id != me {
                try draw(HouseRow(session: session, house: house), width: 340)
            }
            try draw(EnvoyCards(session: session), width: 360)
        }
        for envoy in session.envoys {
            let line = EnvoyCards.words(for: envoy, from: session.state.houses[envoy.from], in: session.state, player: me)
            XCTAssertFalse(line.isEmpty, "\(envoy.proposal)")
        }
        XCTAssertEqual(HouseRow.keeping(session.state.houses[others[2]], present: ["Someone"]), "Its keeper is away; it stands as they left it.")
        XCTAssertEqual(HouseRow.keeping(session.state.houses[others[0]], present: nil), "A steward gives its orders.")
    }

    func testTheTopBarInEveryStateOfTheRealm() throws {
        let link = SilentLink()
        let state = GameState(settings: GameSettings(seedText: "top bar states", houseCount: 4, radius: 18))
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player), store: LocalStore(directory: dir))
        let status = RealmStatus(name: "The Nullmere", age: 1, watch: 3, seats: 4, freeSeats: 1, keepers: 3, online: 3, ready: 1,
                                 secondsLeft: 134, isEnding: false)
        link.onEvent?(.status(status))
        XCTAssertEqual(EndWatchButton.realmLine(status: status, secondsLeft: session.secondsLeft()), "Turns in 2:14 · 1 of 3 ready")
        XCTAssertNil(EndWatchButton.realmLine(status: nil, secondsLeft: 10))
        try draw(TopBar(session: session), width: 1200)
        try draw(WatchClock(session: session), width: 400)
        session.endWatch()
        XCTAssertTrue(session.isReady)
        try draw(EndWatchButton(session: session), width: 200)
        session.cancelReady()
        link.onEvent?(.unreachable("No answer."))
        XCTAssertTrue(session.isOutOfReach)
        try draw(WatchClock(session: session), width: 400)
        try draw(TopBar(session: session, compact: true), width: 800)
        try draw(NoticeFeed(session: session), width: 400)
        let empty = IncomeBreakdown(state: state, house: state.player, resource: .moonsalt)
        try draw(IncomeCard(breakdown: empty), width: 260)
    }
}

/// A link that tells only what a test makes it.
@MainActor
private final class SilentLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}

final class FlowLayoutTests: XCTestCase {
    func testViewsWrapIntoRows() {
        let sizes = [CGSize(width: 80, height: 20), CGSize(width: 70, height: 24), CGSize(width: 90, height: 20), CGSize(width: 400, height: 22)]
        let rows = FlowLayout.rows(of: sizes, width: 200, spacing: 4)
        XCTAssertEqual(rows.map(\.indices), [[0, 1], [2], [3]], "Two fit, the third wraps, an over-wide one stands alone")
        XCTAssertEqual(rows[0].width, 154)
        XCTAssertEqual(rows[0].height, 24)
        XCTAssertEqual(FlowLayout.rows(of: sizes, width: .infinity, spacing: 4).count, 1, "Unbounded, all in one row")
        XCTAssertTrue(FlowLayout.rows(of: [], width: 100, spacing: 4).isEmpty)
    }
}
