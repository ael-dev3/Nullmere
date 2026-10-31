import AppKit
import LauncherCore
@testable import LauncherKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The world is the screen: the interface keeps to the edges and comes when
/// it is wanted. Laid out in a window of a laptop's size, each piece of the
/// interface notes where it lies, and the world's share of the window is
/// told for each way a keeper most often sees it, and held to a budget.
@MainActor
final class ChromeBudgetTests: XCTestCase {
    private var dir: URL!
    private let size = CGSize(width: 1512, height: 982)

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        ChromeLedger.isListening = false
        try? FileManager.default.removeItem(at: dir)
    }

    /// The world's share of the window as the play view lays it out now.
    private func worldShare(_ app: GameApp, _ session: GameSession) -> Double {
        ChromeLedger.isListening = true
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PlayView(app: app, session: session).frame(width: size.width, height: size.height))
        window.orderFrontRegardless()
        defer { window.close() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.4))
        return 1 - ChromeLedger.covered(of: size)
    }

    func testTheWorldKeepsMostOfTheScreen() throws {
        UserDefaults.standard.removeObject(forKey: MiniMap.shownKey)
        UserDefaults.standard.removeObject(forKey: "charges.open")
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: "the world's share"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        var state = GameState(settings: GameSettings(seedText: "the world's share", houseCount: 6, radius: 20, keepers: 1))
        for _ in 0..<8 {
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent("world")))
        session.dismissSeatBriefing()
        session.dismissFirstSteps()
        session.dismissAwayReport()

        // As a keeper sees it most of the time: nothing chosen, no panel open.
        let plain = worldShare(app, session)
        XCTAssertFalse(ChromeLedger.frames.isEmpty, "The interface notes where it lies")
        let pieces = ChromeLedger.frames.keys.sorted().joined(separator: ", ")
        // A company chosen, its orders beside it.
        session.selectNextReadyUnit()
        let company = worldShare(app, session)
        // The seat chosen, its works and musters.
        session.focusOnSeat()
        let seat = worldShare(app, session)
        // A panel open over the map.
        session.selection = .none
        session.panel = .houses
        let panel = worldShare(app, session)

        func share(_ value: Double) -> String { "\(Int((value * 100).rounded()))%" }
        print("LAYOUT the world's share of a \(Int(size.width))x\(Int(size.height)) window: \(share(plain)) plain, \(share(company)) with a company "
              + "chosen, \(share(seat)) with the seat chosen, \(share(panel)) with the Houses open (pieces: \(pieces))")
        XCTAssertGreaterThan(plain, 0.8, "Nothing chosen, the world is the screen")
        XCTAssertGreaterThan(company, 0.65, "A company's record keeps to its corner")
        XCTAssertGreaterThan(seat, 0.5, "Even a seat's long record leaves half the world")
        XCTAssertGreaterThan(panel, 0.5, "A panel leaves half the world")
    }
}
