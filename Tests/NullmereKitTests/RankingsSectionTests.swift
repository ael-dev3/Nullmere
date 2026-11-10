import AppKit
import LauncherKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The Rankings in the Mac's Realm panel: folded to where the keeper's
/// House stands; open, the Houses or the alliances by might or by foes
/// slain, the foremost and the keeper's own beneath them, each line one
/// thing to VoiceOver.
@MainActor
final class RankingsSectionTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View) {
        let renderer = ImageRenderer(content: view.frame(width: 360, height: 900).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    func testTheRankingsFoldToALineAndOpenToEveryHouseAndAlliance() throws {
        var state = GameState(settings: GameSettings(seedText: "rankings on the Mac", houseCount: 12, radius: 22, keepers: 1))
        let me = state.player
        // Every other House has slain more than the keeper's.
        state.foesSlain = state.houses.indices.map { $0 == me ? 50 : 1_000 + 10 * $0 }
        let session = GameSession(link: RankingsLink(), house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()

        // Folded in the Realm panel, to where the House stands.
        PressableButtons.isListening = true
        draw(RealmPanel(session: session))
        XCTAssertNotNil(PressableButtons.actions["Show the rankings"], "Among \(PressableButtons.actions.keys.sorted())")
        XCTAssertNil(PressableButtons.actions["Foes slain"], "folded")
        XCTAssertTrue(session.state.rankingsSaid(for: me).hasSuffix("twelfth of 12 by foes slain."))

        // Open, by foes slain: the foremost ten and the keeper's own beneath them.
        PressableButtons.isListening = true
        draw(RankingsSection(session: session, open: true, by: .slain))
        for title in ["Houses", "Alliances", "Might", "Foes slain", "Fold the rankings"] {
            XCTAssertNotNil(PressableButtons.actions[title], "\(title) among \(PressableButtons.actions.keys.sorted())")
        }
        let slain = session.state.ranking(.slain, for: me)
        XCTAssertEqual(slain.lines.count, GameState.rankingShown)
        let own = try XCTUnwrap(slain.own)
        XCTAssertEqual(own.place, 12)
        XCTAssertEqual(own.said(.slain), "12th, \(state.houses[me].title): 50 foes slain")
        draw(RankingRow(line: own, by: .slain))

        // A line brings the view to the House's seat, the panel put away.
        let top = try XCTUnwrap(slain.lines.first)
        let seat = try XCTUnwrap(session.state.seat(of: top.id))
        session.panel = .realm
        XCTAssertTrue(PressableButtons.press("Go to \(top.name)"), "Among \(PressableButtons.actions.keys.sorted())")
        XCTAssertNil(session.panel, "the panel put away for the world")
        XCTAssertEqual(session.selection, .hold(seat.id))
        // Kept with CI's screenshots, open as a keeper sees it.
        try CardShot.keep(RankingsSection(session: session, open: true)
            .padding(16).frame(width: PanelWidth.rail).panelBackground().padding(20),
                          as: "game-rankings.png")

        // The alliances, while the House is sworn to none, and by might.
        draw(RankingsSection(session: session, open: true, by: .might, alliances: true))
        XCTAssertEqual(session.state.ranking(.might, alliances: true, for: me).standing, "Your House is sworn to no alliance.")
        draw(RankingsSection(session: session, open: true))
    }
}

/// A realm that hears nothing.
private final class RankingsLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
