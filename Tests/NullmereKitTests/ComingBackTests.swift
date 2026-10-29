import AppKit
import LauncherCore
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The keeper coming back to the app, as AppKit tells it: in the realm,
/// what they missed is cleared from the Dock; at the gate, the on-device
/// model is asked again, as they may have just turned it on.
@MainActor
final class ComingBackTests: XCTestCase {
    private var dir: URL!
    private var window: NSWindow?

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        window?.close()
        window = nil
        try? FileManager.default.removeItem(at: dir)
    }

    private func show(_ view: some View) {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: view)
        window.orderFrontRegardless()
        self.window = window
        RunLoop.main.run(until: Date().addingTimeInterval(0.3))
    }

    private func comeBack() {
        NotificationCenter.default.post(name: NSApplication.didBecomeActiveNotification, object: nil)
        RunLoop.main.run(until: Date().addingTimeInterval(0.2))
    }

    private func app(readiness: @escaping () -> ModelReadiness) -> GameApp {
        GameApp(store: LocalStore(directory: dir), readiness: readiness, sound: false, address: .hosted(seed: "coming back"),
                identity: FileIdentityStore(url: dir.appendingPathComponent("identity")), opensAtOnce: false)
    }

    func testComingBackClearsWhatWasMissed() throws {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "coming back", houseCount: 3, radius: 16)),
                                  store: LocalStore(directory: dir.appendingPathComponent("session")))
        session.dismissSeatBriefing()
        session.isLooking = { false }
        var signals: [Attention.Signal] = []
        session.signal = { signals.append($0) }
        session.endWatch()
        XCTAssertGreaterThan(session.attention.missed, 0, "A watch turned while the keeper was away")
        XCTAssertNotNil(signals.last?.badge)

        show(PlayView(app: app(readiness: { .ready }), session: session))
        comeBack()
        XCTAssertEqual(session.attention.missed, 0, "Back again, nothing is missed")
        XCTAssertEqual(signals.last, Attention.Signal(badge: nil, bounce: false), "and the Dock's badge is cleared")
    }

    func testComingBackToTheGateAsksTheModelAgain() {
        var asked = 0
        // A Mac that can never run it: asked again only when the keeper comes back.
        let app = app(readiness: { asked += 1; return .deviceNotEligible })
        app.checkModel()
        XCTAssertFalse(app.readiness.allowsPlay)
        show(ModelGate(app: app))
        let before = asked
        comeBack()
        XCTAssertEqual(asked, before + 1, "Asked again as the keeper comes back")
    }
}
