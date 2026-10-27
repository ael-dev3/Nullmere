import LauncherCore
@testable import LauncherKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The whole window, as each phase shows it: the model gate for every way
/// the model can be missing, the front door, and a game at its start and
/// well under way, with its cards and panels open; and every line the
/// lake's news can be told in.
@MainActor
final class RootRenderTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    @discardableResult
    private func draw(_ view: some View, width: CGFloat = 1200, height: CGFloat = 780) throws -> CGImage {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertEqual(CGFloat(image.width), width)
        return image
    }

    private func app(_ readiness: @escaping () -> ModelReadiness, seed: String) -> GameApp {
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: seed)))
        return GameApp(store: LocalStore(directory: dir), readiness: readiness, sound: false, address: .hosted(seed: seed),
                       identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
    }

    func testEveryPhaseOfTheWindowDraws() throws {
        var readiness = ModelReadiness.modelNotReady
        let app = app({ readiness }, seed: "every phase")
        for missing in [ModelReadiness.modelNotReady, .appleIntelligenceNotEnabled, .deviceNotEligible, .unavailable, .checking] {
            readiness = missing
            app.checkModel()
            try draw(GameRootView(app: app))
            try draw(ModelGate(app: app))
        }
        readiness = .ready
        app.checkModel()
        guard case .frontDoor = app.phase else { return XCTFail("A ready model opens the front door") }
        try draw(GameRootView(app: app))
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        // The first moments: the seat's briefing, then the first steps.
        try draw(GameRootView(app: app))
        session.dismissSeatBriefing()
        try draw(PlayView(app: app, session: session))
        app.showsSettings = true
        try draw(GameRootView(app: app))
        app.showsSettings = false

        // Well under way: counsel, a watch's card, a company chosen.
        session.dismissFirstSteps()
        session.autoplay(watches: 30)
        session.selectNextReadyUnit()
        try draw(PlayView(app: app, session: session), width: 1512, height: 982)
        session.endWatch()
        XCTAssertNotNil(session.watchCard, "The watch's card shows")
        try draw(PlayView(app: app, session: session))
        if let card = session.watchCard {
            try draw(WatchCard(summary: card.summary), width: 700, height: 300)
        }
        try draw(MapVignette(), width: 400, height: 300)
    }

    func testTheOneWindowShowsTheLauncherThenTheRealm() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: "root-render-\(UUID().uuidString)"))
        let environment = LauncherEnvironment(
            modelReadiness: { .ready },
            systemSavesEnergy: { false },
            downloadNews: { throw URLError(.notConnectedToInternet) },
            open: { _ in true },
            terminate: {}
        )
        let launcher = LauncherModel(defaults: defaults, environment: environment)
        let shell = OnlineShell(launcher: launcher, app: app({ .ready }, seed: "one window"))
        try draw(NullmereOnlineView(shell: shell))
        shell.showSettings()
        shell.enterRealm()
        XCTAssertTrue(shell.inRealm)
        try draw(NullmereOnlineView(shell: shell))
        shell.showSettings()
        XCTAssertTrue(shell.app.showsSettings, "In the realm, Settings is the game's")
        shell.leaveRealm()
        XCTAssertFalse(shell.inRealm)
    }

    func testEveryKindOfNewsCanBeTold() {
        // A long age among stewards brings every kind of event the rules
        // make; each is told from every House's side, or kept from it.
        var state = GameState(settings: GameSettings(seedText: "all the news", houseCount: 6, radius: 22, keepers: 0))
        var events: [GameEvent] = []
        for _ in 0..<120 where state.outcome == nil {
            for house in state.livingHouses { events += state.stewardTurn(for: house.id) }
            events += state.endWatch()
        }
        // And what a keeper alone gives rise to.
        let envoy = Envoy(id: 1, from: 1, to: 0, proposal: .trade, arrived: state.watch, trade: Trade(give: .grain, 5, for: .stone, 5))
        events += [.envoyArrived(envoy), .envoyArrived(Envoy(id: 2, from: 1, to: 0, proposal: .tribute, arrived: state.watch)),
                   .tradeAnswered(trade: Trade(give: .grain, 5, for: .stone, 5), from: 0, to: 1, accepted: false),
                   .tradeAnswered(trade: Trade(give: .grain, 5, for: .stone, 5), from: 1, to: 0, accepted: true),
                   .gifted(from: 0, to: 1, gift: Stock(grain: 5)), .gifted(from: 1, to: 0, gift: Stock(grain: 5))]
        var told = 0, kinds = Set<String>()
        for event in events {
            kinds.insert(String(describing: event).prefix { $0 != "(" }.description)
            for viewer in state.houses.indices {
                if let line = Narration.line(for: event, in: state, viewer: viewer) {
                    XCTAssertFalse(line.text.isEmpty)
                    XCTAssertFalse(line.text.contains("Optional"), line.text)
                    told += 1
                }
            }
        }
        print("NEWS \(events.count) events of \(kinds.count) kinds, \(told) lines told")
        XCTAssertGreaterThan(kinds.count, 12, "\(kinds.sorted())")
    }
}
