import NullmereCore
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
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        try draw(TopBar(session: session), width: 1200)
        try draw(GameSettingsView(app: app), width: 480, height: 520)
    }
}
