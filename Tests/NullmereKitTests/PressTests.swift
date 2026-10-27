import AppKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The panels' buttons pressed as VoiceOver presses them, in a real
/// window: each reaches the session and sends the order it names.
@MainActor
final class PressTests: XCTestCase {
    private var dir: URL!
    private var windows: [NSWindow] = []

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        windows.forEach { $0.close() }
        windows = []
        try? FileManager.default.removeItem(at: dir)
    }

    private func spin(_ seconds: Double = 0.15) {
        RunLoop.main.run(until: Date().addingTimeInterval(seconds))
    }

    /// The view in a window of its own, laid out.
    @discardableResult
    private func host(_ view: some View, width: CGFloat = 360, height: CGFloat = 700) -> NSView {
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: width, height: height), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        let hosting = NSHostingView(rootView: view.frame(width: width, height: height).background(Color.black))
        window.contentView = hosting
        window.orderFrontRegardless()
        windows.append(window)
        hosting.layoutSubtreeIfNeeded()
        spin()
        return hosting
    }

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
        let row = host(HouseRow(session: session, house: other))
        XCTAssertTrue(Accessibility.press("Offer a pact", in: row), "Found among \(Accessibility.labels(in: row))")
        XCTAssertEqual(link.sent.last, .propose(.pact, to: other.id))

        // War asks twice before it is declared.
        XCTAssertTrue(Accessibility.press("Declare war", in: row))
        XCTAssertFalse(link.sent.contains(.declareWar(on: other.id)), "Once arms it")
        spin()
        XCTAssertTrue(Accessibility.press("War on \(other.title)?", in: row), "Armed, it asks: \(Accessibility.labels(in: row))")
        XCTAssertEqual(link.sent.last, .declareWar(on: other.id))

        // At war, peace may be offered.
        spin()
        XCTAssertTrue(Accessibility.press("Offer peace", in: row), "\(Accessibility.labels(in: row))")
        XCTAssertEqual(link.sent.last, .propose(.peace, to: other.id))
    }

    func testATradeIsComposedAndOffered() throws {
        let state = GameState(settings: GameSettings(seedText: "pressed trade", houseCount: 4, radius: 18))
        let (session, link) = session(state)
        let other = try XCTUnwrap(session.state.houses.first { $0.id != session.player })
        var offered: Trade?
        let composer = host(TradeComposer(house: other, stock: session.playerHouse.stock) { offered = $0 }, width: 300, height: 320)
        XCTAssertTrue(Accessibility.press("Offer", in: composer), "\(Accessibility.labels(in: composer))")
        let trade = try XCTUnwrap(offered)
        session.offerTrade(trade, to: other, words: "")
        guard case .offerTrade(let sent, to: let to, words: _)? = link.sent.last else { return XCTFail("The trade is sent") }
        XCTAssertEqual(sent, trade)
        XCTAssertEqual(to, other.id)
    }

    func testAHoldsWorksAndMustersAreOrdered() throws {
        var state = GameState(settings: GameSettings(seedText: "pressed works", houseCount: 4, radius: 18))
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == state.player && $0.isSeat })
        state.houses[state.player].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 200)
        state.holds[seat].project = nil
        state.holds[seat].training = nil
        let (session, link) = session(state)
        session.selection = .hold(state.holds[seat].id)
        let panel = host(SelectionPanel(session: session), height: 1000)
        XCTAssertTrue(Accessibility.press("Build I", in: panel), "\(Accessibility.labels(in: panel))")
        XCTAssertTrue(link.sent.contains { if case .build = $0 { return true } else { return false } })
        XCTAssertTrue(Accessibility.press("Train", in: panel))
        XCTAssertTrue(link.sent.contains { if case .train = $0 { return true } else { return false } })
        XCTAssertTrue(Accessibility.press("Barter", in: panel))
        XCTAssertTrue(link.sent.contains { if case .barter = $0 { return true } else { return false } })
    }

    func testACompanysOrdersAndTheTopBar() throws {
        let state = GameState(settings: GameSettings(seedText: "pressed company", houseCount: 4, radius: 18))
        let (session, link) = session(state)
        let spear = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .spear })
        session.selection = .unit(spear.id)
        let panel = host(SelectionPanel(session: session), height: 600)
        XCTAssertTrue(Accessibility.press("Fortify", in: panel), "\(Accessibility.labels(in: panel))")
        XCTAssertEqual(link.sent.last, .fortify(unit: spear.id))

        let bar = host(TopBar(session: session), width: 1200, height: 90)
        for (label, panel) in [("Houses", GameSession.Panel.houses), ("Chronicle", .chronicle), ("Guide", .guide)] {
            XCTAssertTrue(Accessibility.press(label, in: bar), "\(Accessibility.labels(in: bar))")
            XCTAssertEqual(session.panel, panel)
        }
        XCTAssertTrue(Accessibility.press("Ready", in: bar))
        XCTAssertTrue(session.isReady)
        XCTAssertEqual(link.readies.last, true)
        spin()
        XCTAssertTrue(Accessibility.press("Waiting", in: bar), "\(Accessibility.labels(in: bar))")
        XCTAssertFalse(session.isReady)
    }
}

/// Finds what VoiceOver would find in a view, by its label, and presses
/// it. SwiftUI's elements are reached through the Objective-C runtime, as
/// the accessibility system reaches them.
@MainActor
enum Accessibility {
    private static func value(_ key: String, of element: AnyObject) -> Any? {
        guard let object = element as? NSObject, object.responds(to: Selector(key)) else { return nil }
        return object.value(forKey: key)
    }

    private static func elements(in root: NSView) -> [AnyObject] {
        var found: [AnyObject] = []
        var queue: [AnyObject] = [root]
        var seen = Set<ObjectIdentifier>()
        while !queue.isEmpty, found.count < 5000 {
            let element = queue.removeFirst()
            guard seen.insert(ObjectIdentifier(element)).inserted else { continue }
            found.append(element)
            let children = (value("accessibilityChildren", of: element) as? [Any]) ?? []
            queue += children.map { $0 as AnyObject }
        }
        return found
    }

    static func labels(in root: NSView) -> [String] {
        elements(in: root).compactMap { value("accessibilityLabel", of: $0) as? String }.filter { !$0.isEmpty }
    }

    /// Presses the first element labelled so; false if none was found or
    /// it wouldn't be pressed.
    @discardableResult
    static func press(_ label: String, in root: NSView) -> Bool {
        for element in elements(in: root) {
            guard let named = value("accessibilityLabel", of: element) as? String,
                  named.caseInsensitiveCompare(label) == .orderedSame else { continue }
            if let pressed = value("accessibilityPerformPress", of: element) as? Bool, pressed {
                RunLoop.main.run(until: Date().addingTimeInterval(0.1))
                return true
            }
        }
        return false
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
