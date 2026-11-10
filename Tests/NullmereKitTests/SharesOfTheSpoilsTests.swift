import AppKit
import LauncherKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The shares of the alliance's spoils at the head of the Mac's Alliance
/// panel: nothing while none waits; each share's deed and what they hold,
/// and Take them, which sends the order to the realm and takes them in the
/// keeper's copy as the realm will.
@MainActor
final class SharesOfTheSpoilsTests: XCTestCase {
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

    func testTheSharesAreToldAndTakenFromTheAlliancePanel() async throws {
        var state = GameState(settings: GameSettings(seedText: "shares on the Mac", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        _ = try state.perform(.foundAlliance(name: "The Salt Pact"), as: me)
        let link = SharesLink()
        let session = GameSession(link: link, house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()
        PressableButtons.isListening = true
        draw(AlliancePanel(session: session))
        XCTAssertNil(PressableButtons.actions["Take them"], "none waits, none offered")
        XCTAssertEqual(SharesOfTheSpoils.title(1), "A share of the spoils")
        XCTAssertEqual(SharesOfTheSpoils.title(3), "3 shares of the spoils")

        // The realm sets a share aside: told once, as its world comes.
        state.tally([.lairAssaulted(LairAssault(rally: 1, caller: me, lair: 3, kind: .reavers, level: 2, at: Hex(0, 0), strikes: [],
                                                before: 40, strength: 0, might: 30, shares: []))])
        link.onEvent?(.changed(state.view(for: me)))
        XCTAssertEqual(session.state.shares(of: me).count, 1)
        XCTAssertEqual(session.notices.last?.text, "A share of your alliance's spoils waits: Your House broke a lair of the wilds, level II.",
                       "\(session.notices.map(\.text))")
        let told = session.notices.count
        var later = state
        later.houses[me].stock.grain += 1
        link.onEvent?(.changed(later.view(for: me)))
        XCTAssertEqual(session.notices.count, told, "told once, not again with each world")

        // Taken from the panel: the order sent, taken in the keeper's copy as the realm will.
        let hourglasses = session.state.items(.hourglass, of: me)
        PressableButtons.isListening = true
        draw(AlliancePanel(session: session))
        XCTAssertTrue(PressableButtons.press("Take them"), "Among \(PressableButtons.actions.keys.sorted())")
        XCTAssertEqual(link.sent.last, .takeShares)
        XCTAssertTrue(session.state.shares(of: me).isEmpty, "taken")
        XCTAssertEqual(session.state.items(.hourglass, of: me), hourglasses + 1)
        XCTAssertTrue(session.notices.last?.text.hasPrefix("Your shares taken: 60 grain, 60 timber, 40 stone, 2 moonsalt") == true,
                      "\(session.notices.map(\.text))")
    }
}

/// A realm that keeps what it is sent.
private final class SharesLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    private(set) var sent: [Command] = []
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) { sent.append(command) }
    func setReady(_ ready: Bool) {}
    func leave() {}
}
