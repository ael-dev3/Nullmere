import Accessibility
import AppKit
import LauncherCore
@testable import LauncherKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The small things the realm draws and says, each as it should be: what
/// is short marked in words where colour alone can't say it; a row of
/// actions spaced as its layout means; the away card's word on what more
/// the Chronicle holds; the age's chart as VoiceOver's audio graph reads
/// it; the sound faded fast for quitting; the settings' own choices; a
/// panel opened by its key over the map in a window; and one copy of the
/// game at a time.
@MainActor
final class DetailsDrawnTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        PressableButtons.isListening = false
        Contrast.shared.differentiates = false
        try? FileManager.default.removeItem(at: dir)
    }

    private func render(_ view: some View) throws -> CGImage {
        let renderer = ImageRenderer(content: view.background(Color.black))
        renderer.scale = 1
        return try XCTUnwrap(renderer.cgImage)
    }

    /// The image's pixels, its top row first.
    private func pixels(of image: CGImage) -> [UInt8] {
        let width = image.width, height = image.height
        var bytes = [UInt8](repeating: 0, count: width * height * 4)
        bytes.withUnsafeMutableBytes { raw in
            guard let context = CGContext(data: raw.baseAddress, width: width, height: height, bitsPerComponent: 8, bytesPerRow: width * 4,
                                          space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return }
            context.draw(image, in: CGRect(x: 0, y: 0, width: width, height: height))
        }
        return bytes
    }

    private func spin(until what: String, timeout: Double = 5, _ condition: () -> Bool) {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition(), Date() < deadline {
            RunLoop.main.run(until: Date().addingTimeInterval(0.05))
        }
        XCTAssertTrue(condition(), "Waited for \(what)")
    }

    private func hostedApp(_ seed: String) -> GameApp {
        GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: .hosted(seed: seed),
                identity: FileIdentityStore(url: dir.appendingPathComponent("identity")), opensAtOnce: false)
    }

    func testWhatIsShortIsMarkedInWordsWithDifferentiateWithoutColour() throws {
        let cost = Stock(grain: 20, timber: 30)
        let stores = Stock(grain: 50, timber: 10)
        XCTAssertEqual(CostLine.shortfall(of: cost, from: stores), "short of 20 timber")
        XCTAssertNil(CostLine.shortfall(of: cost, from: Stock(grain: 20, timber: 30)), "Enough of each")
        Contrast.shared.differentiates = false
        let coloured = try render(CostLine(cost: cost, available: stores))
        Contrast.shared.differentiates = true
        let worded = try render(CostLine(cost: cost, available: stores))
        XCTAssertGreaterThan(worded.width, coloured.width, "The word beside what is short, not its colour alone")
        let enough = try render(CostLine(cost: cost, available: Stock(grain: 50, timber: 50)))
        XCTAssertEqual(enough.width, coloured.width, "Nothing short: nothing marked")
    }

    /// Left to its own spacing, a flow keeps four points between its views
    /// and two between its rows, starting a row afresh when the next view
    /// would overflow.
    func testAFlowSpacesItsViewsFourApartAndItsRowsTwo() throws {
        let flow = FlowLayout {
            Color.white.frame(width: 50, height: 10)
            Color.white.frame(width: 50, height: 10)
            Color.white.frame(width: 50, height: 10)
        }
        .frame(width: 108, height: 30, alignment: .topLeading)
        let image = try render(flow)
        XCTAssertEqual(image.width, 108)
        let bytes = pixels(of: image)
        func lit(_ x: Int, _ y: Int) -> Bool {
            let index = (y * image.width + x) * 4
            return Int(bytes[index]) + Int(bytes[index + 1]) + Int(bytes[index + 2]) > 384
        }
        XCTAssertTrue(lit(25, 5), "The first view")
        XCTAssertFalse(lit(52, 5), "Four points between it and the next")
        XCTAssertTrue(lit(79, 5), "The second beside it")
        XCTAssertFalse(lit(106, 5), "The third doesn't fit beside them")
        XCTAssertFalse(lit(25, 11), "Two points between the rows")
        XCTAssertTrue(lit(25, 16), "The third starts the next row")
        XCTAssertFalse(lit(79, 16), "alone in it")
    }

    func testTheAwayCardSaysHowManyMoreTheChronicleHolds() throws {
        var state = GameState(settings: GameSettings(seedText: "more than is told", houseCount: 4, radius: 16, keepers: 1))
        let me = state.player
        let other = (me + 1) % state.houses.count
        let watch = state.watch
        let seen = LastSeen(watch: watch - 1, stock: state.houses[me].stock, holds: state.holds(of: me).count)
        let mine = (1...10).map { ChronicleEntry(watch: watch, kind: .war, houses: [me, other], text: "Entry \($0).") }
        let fall = ChronicleEntry(watch: watch, kind: .fall, houses: [other], text: "\(state.houses[other].title) has fallen.")
        let omens = [ChronicleEntry(watch: watch, kind: .omen, houses: [], text: "A first omen."),
                     ChronicleEntry(watch: watch, kind: .omen, houses: [], text: "A second omen.")]

        // More than the card has lines for: what touched the House told, the
        // rest counted.
        state.chronicle = mine + [fall] + omens
        let crowded = try XCTUnwrap(AwayReport(since: seen, now: state, player: me))
        XCTAssertEqual(crowded.news, mine.suffix(AwayReport.lines).map(\.text), "What touched the House first")
        XCTAssertEqual(crowded.more, 4, "Two of the House's, the fall and the latest omen")
        XCTAssertEqual(crowded.moreLine, "And 4 more in the Chronicle.")

        // One more than the lines, said as one; none more, nothing said.
        state.chronicle = Array(mine.prefix(AwayReport.lines)) + [fall]
        let one = try XCTUnwrap(AwayReport(since: seen, now: state, player: me))
        XCTAssertEqual(one.moreLine, "And one more in the Chronicle.")
        state.chronicle = Array(mine.prefix(AwayReport.lines))
        let all = try XCTUnwrap(AwayReport(since: seen, now: state, player: me))
        XCTAssertNil(all.moreLine)
        XCTAssertEqual(all.news.count, one.news.count)
        let withMore = try render(AwayCard(report: one) {})
        let without = try render(AwayCard(report: all) {})
        XCTAssertGreaterThan(withMore.height, without.height, "The card says there is more, in a line of its own")
    }

    /// The age's chart as VoiceOver's audio graph plays it: each point a
    /// watch and a number of holds, in words.
    func testTheAudioGraphSaysEachPointInWords() throws {
        let state = GameState(settings: GameSettings(seedText: "an audio graph", houseCount: 4, radius: 16, keepers: 1))
        let chart = StoryChart(state: state, player: state.player).makeChartDescriptor()
        XCTAssertEqual(chart.title, "Holds around the lake, watch by watch")
        let watches = try XCTUnwrap(chart.xAxis as? AXNumericDataAxisDescriptor)
        XCTAssertEqual(watches.valueDescriptionProvider(7), "watch 7")
        let holds = try XCTUnwrap(chart.yAxis)
        XCTAssertEqual(holds.valueDescriptionProvider(3), "3 holds")
        XCTAssertEqual(chart.series.first { $0.name?.hasPrefix("You, ") == true }?.name, "You, \(state.houses[state.player].title)")
    }

    /// Quitting fades the sound fast and says how long to wait for it: a
    /// hard stop clicks. Nothing to wait for while silent, or already fading.
    func testQuittingFadesTheSoundFastAndSaysHowLongToWait() async throws {
        let ambience = Ambience(enabled: true)
        XCTAssertEqual(ambience.fadeForQuitting(), 0, "Silent: nothing to wait for")
        ambience.start()
        // Whether this Mac has an output to play on: CI's may not.
        let hasOutput = ambience.isPlaying
        XCTAssertEqual(ambience.fadeForQuitting(), hasOutput ? Ambience.quitFadeSeconds : 0)
        ambience.isEnabled = false
        XCTAssertEqual(ambience.fadeForQuitting(), 0, "Already fading out: nothing more to wait for")
        ambience.stop()
        try await Task.sleep(for: .seconds(Ambience.fadeOutSeconds + 0.6))
        XCTAssertFalse(ambience.isRunning, "Faded out, stopped")
    }

    /// The Settings' Off and On for the score are the score's alone, and can
    /// be pressed only while there is sound; with none, Off and On are the
    /// sound's own.
    func testTheScoresChoiceIsItsOwnAndWaitsForTheSound() throws {
        let defaults = UserDefaults.standard
        let keys = ["sound.enabled", "music.enabled"]
        let kept = keys.map { defaults.object(forKey: $0) }
        defer {
            for (key, value) in zip(keys, kept) {
                if let value { defaults.set(value, forKey: key) } else { defaults.removeObject(forKey: key) }
            }
        }
        let app = hostedApp("the settings pressed")
        app.isSoundOn = true
        app.isMusicOn = true
        PressableButtons.isListening = true
        XCTAssertNotNil(ImageRenderer(content: GameSettingsView(app: app).background(Color.black)).cgImage)
        XCTAssertTrue(PressableButtons.press("Off"), "Among \(PressableButtons.actions.keys.sorted())")
        XCTAssertFalse(app.isMusicOn, "The score turned off")
        XCTAssertFalse(app.ambience.isMusicOn)
        XCTAssertTrue(app.isSoundOn, "The rest of the sound left as it was")
        XCTAssertTrue(PressableButtons.press("On"))
        XCTAssertTrue(app.isMusicOn)

        // With the sound off, the score's choice can't be pressed.
        app.isSoundOn = false
        PressableButtons.isListening = true
        XCTAssertNotNil(ImageRenderer(content: GameSettingsView(app: app).background(Color.black)).cgImage)
        XCTAssertTrue(PressableButtons.press("On"))
        XCTAssertTrue(app.isSoundOn, "On is the sound's own")
        XCTAssertTrue(app.isMusicOn, "and the score as it was")
        app.isSoundOn = false
    }

    /// A panel opened by its key comes over the map in the window, and its
    /// key puts it away again.
    func testAPanelOpenedByItsKeyComesOverTheMap() throws {
        let app = hostedApp("a panel over the map")
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "a panel over the map", houseCount: 4, radius: 18, keepers: 1)),
                                  store: LocalStore(directory: dir.appendingPathComponent("world")))
        session.dismissSeatBriefing()
        PressableButtons.isListening = true
        let window = NSWindow(contentRect: NSRect(x: 0, y: 0, width: 1100, height: 720), styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: PlayView(app: app, session: session).frame(width: 1100, height: 720))
        window.orderFrontRegardless()
        defer { window.close() }
        RunLoop.main.run(until: Date().addingTimeInterval(0.5))
        XCTAssertNil(PressableButtons.actions["Offer a pact"], "No House's offers while the Houses are shut")
        XCTAssertTrue(session.handle(.houses))
        spin(until: "the Houses over the map") { PressableButtons.actions["Offer a pact"] != nil }
        XCTAssertTrue(session.handle(.houses))
        XCTAssertNil(session.panel, "Put away by its key")
    }

    /// The copy under test is the only one running: it carries on, with no
    /// other to hand over to.
    func testTheOnlyCopyRunningCarriesOn() {
        XCTAssertFalse(SingleInstance.handOver())
    }
}
