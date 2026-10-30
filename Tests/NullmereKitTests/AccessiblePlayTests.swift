import AppKit
import LauncherKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
@testable import NullmereRealm
import NullmereWorld

/// The game played without sight or pointer: VoiceOver is offered every
/// order a company has (to found, to explore, to strike with its odds, each
/// with its way and distance), cards before the world keep the keys and
/// VoiceOver to themselves, a watch is said whole in one announcement, a
/// confirmation waits long enough to be heard, and the realm's word on
/// readiness and on watches missed reaches the keeper.
@MainActor
final class AccessiblePlayTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
        Contrast.shared.isIncreased = false
        Contrast.shared.differentiates = false
    }

    private func draw(_ view: some View, width: CGFloat = 900, height: CGFloat = 600) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        XCTAssertNotNil(renderer.cgImage)
    }

    /// A world with a foe's spear beside the keeper's, at war.
    private func atWar(_ seed: String) throws -> (GameState, spear: Int, foe: Hex) {
        var state = world(seed)
        let me = state.player
        let foe = (me + 1) % state.houses.count
        _ = try state.perform(.declareWar(on: foe), as: me)
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let beside = try XCTUnwrap(state.map.neighbors(of: spear.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        state.units.append(NullmereCore.Unit(id: state.nextID, kind: .spear, owner: foe, position: beside))
        state.nextID += 1
        return (state, spear.id, beside)
    }

    private func world(_ seed: String) -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: 3, radius: 16, keepers: 1))
    }

    func testDirectionsAreTheCompasss() {
        let origin = Hex(0, 0)
        let layout = HexLayout(size: 1)
        let neighbours = origin.neighbors
        let east = neighbours.max { layout.center(of: $0).x < layout.center(of: $1).x }!
        let west = neighbours.min { layout.center(of: $0).x < layout.center(of: $1).x }!
        let north = neighbours.min { layout.center(of: $0).y < layout.center(of: $1).y }!
        XCTAssertEqual(MapAccessibility.direction(from: origin, to: east), "east")
        XCTAssertEqual(MapAccessibility.direction(from: origin, to: west), "west")
        XCTAssertTrue(MapAccessibility.direction(from: origin, to: north).contains("north"))
        XCTAssertEqual(MapAccessibility.way(from: origin, to: east), "beside it, east")
        XCTAssertTrue(MapAccessibility.way(from: origin, to: Hex(0, 0).neighbors[0].neighbors[0]).hasSuffix(MapAccessibility.direction(from: origin, to: Hex(0, 0).neighbors[0].neighbors[0])))
    }

    func testVoiceOverIsOfferedEveryOrderACompanyHas() throws {
        var state = world("orders for voiceover")
        let me = state.player
        // A founder where a hold may be founded.
        let site = try XCTUnwrap(state.map.hexes.first { hex in
            state.canFound(at: hex, for: me) == nil && state.isExplored(hex, by: me) && state.unit(at: hex) == nil
        })
        var settler = NullmereCore.Unit(id: state.nextID, kind: .founder, owner: me, position: site)
        settler.movesLeft = UnitKind.founder.movement
        state.units.append(settler)
        let founder = state.nextID
        state.nextID += 1
        // A foe beside the keeper's spear, at war.
        let foe = (me + 1) % state.houses.count
        _ = try state.perform(.declareWar(on: foe), as: me)
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let beside = try XCTUnwrap(state.map.neighbors(of: spear.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        state.units.append(NullmereCore.Unit(id: state.nextID, kind: .spear, owner: foe, position: beside))
        state.nextID += 1
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        // Without VoiceOver, no orders are worked out: nothing to pay for.
        session.voiceOverRunning = { false }
        XCTAssertTrue(session.mapItems.allSatisfy(\.orders.isEmpty))
        session.voiceOverRunning = { true }
        let items = session.mapItems

        let founderOrders = try XCTUnwrap(items.first { $0.selection == .unit(founder) }).orders
        let found = try XCTUnwrap(founderOrders.first { $0.founds }, "\(founderOrders.map(\.name))")
        XCTAssertEqual(found.name, "Found a hold here")

        let spearOrders = try XCTUnwrap(items.first { $0.selection == .unit(spear.id) }).orders
        let strike = try XCTUnwrap(spearOrders.first { $0.name.hasPrefix("Strike") }, "\(spearOrders.map(\.name))")
        XCTAssertTrue(strike.name.contains("beside it"), strike.name)
        XCTAssertTrue(strike.name.contains("they take") && strike.name.contains("you take"), "With its odds: \(strike.name)")

        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        let lanternOrders = try XCTUnwrap(items.first { $0.selection == .unit(lantern.id) }).orders
        let explore = try XCTUnwrap(lanternOrders.first { $0.name.hasPrefix("Explore towards the unknown") }, "\(lanternOrders.map(\.name))")
        XCTAssertTrue(["east", "west", "north", "south"].contains { explore.name.contains($0) }, explore.name)
        XCTAssertTrue(session.isExplored(explore.hex))
        XCTAssertTrue(state.map.neighbors(of: explore.hex).contains { !session.isExplored($0) }, "At the edge of what is known")

        // Founding by VoiceOver's action founds.
        session.selection = .unit(founder)
        let holds = session.state.holds(of: me).count
        session.perform(.found(unit: founder))
        XCTAssertEqual(session.state.holds(of: me).count, holds + 1)
    }

    func testACardBeforeTheWorldKeepsTheKeys() throws {
        let session = GameSession(state: world("a card first"), store: LocalStore(directory: dir))
        XCTAssertNotNil(session.seatBriefing, "The first time in: the seat's briefing")
        XCTAssertTrue(session.isShowingCard)
        XCTAssertFalse(session.handle(.nextUnit), "Nothing reaches the map behind the card")
        XCTAssertFalse(session.handle(.pan(dx: 90, dy: 0)))
        XCTAssertFalse(session.handle(.houses))
        XCTAssertNil(session.panel)
        XCTAssertTrue(session.handle(.escape), "Escape puts the card away")
        XCTAssertNil(session.seatBriefing)
        XCTAssertFalse(session.isShowingCard)
        XCTAssertTrue(session.handle(.houses), "and the keys are the game's again")
        XCTAssertEqual(session.panel, .houses)
    }

    func testTheEndingKeepsEscapeForItsOwnWayOut() throws {
        var state = world("the end")
        state.outcome = Outcome(winner: state.player, kind: .ascendancy, watch: state.watch)
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.panel = .houses
        XCTAssertFalse(session.handle(.escape), "Escape is the ending's, not a panel's")
        XCTAssertEqual(session.panel, .houses)
    }

    func testAWatchIsSaidWholeWithWhatTheStoresDid() {
        var before = world("said whole")
        let me = before.player
        var after = before
        after.watch += 1
        after.houses[me].stock.grain += 12
        after.houses[me].stock.timber -= 3
        before.houses[me].stock.stone += 0
        let summary = WatchSummary(before: before, after: after, events: [], player: me)
        XCTAssertTrue(summary.spoken.hasPrefix("Watch \(after.watch)."), summary.spoken)
        XCTAssertTrue(summary.spoken.contains("Grain up 12"), summary.spoken)
        XCTAssertTrue(summary.spoken.contains("Timber down 3"), summary.spoken)
    }

    func testTheRealmsWordOnReadinessAndOnWatchesMissedReachesTheKeeper() throws {
        let link = SilentLink()
        let state = world("readiness and absence")
        let me = state.player
        let session = GameSession(link: link, house: me, world: state.view(for: me), store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        session.endWatch()
        XCTAssertTrue(session.isReady)
        link.onEvent?(.readiness(false))
        XCTAssertFalse(session.isReady, "Lost while away: shown lost")
        XCTAssertTrue(session.notices.contains { $0.text.contains("lost your readiness") })

        // Five watches at once, as after the Mac slept: what passed is told.
        var later = state
        later.watch += 5
        link.onEvent?(.watchTurned(later.view(for: me), []))
        let report = try XCTUnwrap(session.awayReport)
        XCTAssertEqual(report.watches, 5)
        // One watch at a time tells no such thing.
        session.dismissAwayReport()
        var next = later
        next.watch += 1
        link.onEvent?(.watchTurned(next.view(for: me), []))
        XCTAssertNil(session.awayReport)
    }

    /// One rule for every text, the launcher's and the realm's: never under
    /// nine tenths of the ink, so a full stop or a middle dot still stands
    /// clear of the dark at a 1x display's size; what is asked fainter a
    /// little fainter still; solid, mixed from the dark to the ink rather
    /// than laid over what lies beneath; with Increase Contrast, the full
    /// ink. Lines and meters by a rule of their own, so an empty one is
    /// never taken for a full one.
    func testOneRuleOfContrastForEveryText() {
        func resolved(_ colour: Color) -> Color.Resolved { colour.resolve(in: EnvironmentValues()) }
        func drawn(_ colour: Color) -> Double { Double(resolved(colour).opacity) }
        let asked = stride(from: 0.0, through: 1.0, by: 0.05).map { $0 }
        for opacity in asked {
            XCTAssertEqual(LauncherKit.Palette.textStrength(opacity), 0.9 + 0.1 * opacity, accuracy: 0.0001, "At \(opacity)")
            XCTAssertEqual(drawn(NullmereKit.Palette.text(opacity)), 1, accuracy: 0.0001, "Solid at \(opacity)")
            XCTAssertEqual(resolved(NullmereKit.Palette.text(opacity)), resolved(LauncherKit.Palette.text(opacity)),
                           "The launcher's rule and the realm's are one")
        }
        let greens = asked.map { Double(resolved(NullmereKit.Palette.text($0)).green) }
        XCTAssertEqual(greens, greens.sorted(), "What is asked fainter is fainter")
        XCTAssertGreaterThanOrEqual(LauncherKit.Palette.textStrength(-1), 0.9, "But never under the floor")
        let full = resolved(NullmereKit.Palette.text(1)), ink = resolved(NullmereKit.Palette.ink)
        XCTAssertEqual(full.red, ink.red, accuracy: 0.002, "At full strength, the ink")
        XCTAssertEqual(full.blue, ink.blue, accuracy: 0.002)
        XCTAssertEqual(drawn(NullmereKit.Palette.line(0.1)), 0.1, accuracy: 0.001, "A line as faint as it is drawn")

        Contrast.shared.isIncreased = true
        defer { Contrast.shared.isIncreased = false }
        XCTAssertTrue(asked.allSatisfy { LauncherKit.Palette.textStrength($0) == 1 }, "With Increase Contrast, every text the full ink")
        XCTAssertEqual(drawn(NullmereKit.Palette.line(0.1)), 0.2, accuracy: 0.001, "A track twice as plain")
        XCTAssertEqual(drawn(NullmereKit.Palette.line(0.3)), 0.4, accuracy: 0.001, "But no brighter than 0.4")
        XCTAssertEqual(drawn(NullmereKit.Palette.line(0.7)), 0.7, accuracy: 0.001, "A bright line as it was")
    }

    /// No type too small or too thin to hold its contrast on a 1x display:
    /// words never under eleven points and capitals never under nine and a
    /// half, nothing below fourteen points thinner than regular, nothing
    /// below twelve lighter than medium; Larger type larger still.
    func testNoTypeIsTooSmallOrTooThin() {
        TextSize.shared.isLarger = false
        defer { TextSize.shared.isLarger = false }
        XCTAssertEqual(TextSize.shared.size(7.5), 9.5, "Capitals")
        XCTAssertEqual(TextSize.shared.size(9, words: true), 11, "Words")
        XCTAssertEqual(TextSize.shared.size(13, words: true), 13)
        XCTAssertEqual(CGFloat.launcherType(9.5, unit: 0.72), 11, "The launcher's, in a small window, the realm's least for words")
        XCTAssertEqual(TextSize.readable(.regular, at: 11), .medium)
        XCTAssertEqual(TextSize.readable(.light, at: 12.5), .regular)
        XCTAssertEqual(TextSize.readable(.semibold, at: 9.5), .semibold, "Heavier, as asked")
        XCTAssertEqual(TextSize.readable(.thin, at: 26), .thin, "Display sizes keep their thin type")
        TextSize.shared.isLarger = true
        XCTAssertEqual(TextSize.shared.size(7.5), 12.5)
        XCTAssertEqual(TextSize.shared.size(9, words: true), 12.5)
    }

    /// A House's colour, colouring words (a hold's name, the land it holds),
    /// reads as plainly as the rest of the type, ten to one on a panel's
    /// dark, keeping its own hue; with Increase Contrast, plainer still.
    func testAHousesColourReadsWhenItColoursWords() {
        typealias Palette = NullmereKit.Palette
        /// Where a colour lies round the colour wheel, in degrees; a grey has
        /// no hue to keep.
        func hue(_ colour: Palette.RGB) -> Double? {
            let most = max(colour.red, colour.green, colour.blue), least = min(colour.red, colour.green, colour.blue)
            let spread = most - least
            guard spread > 0.08 else { return nil }
            let turn: Double
            if most == colour.red { turn = (colour.green - colour.blue) / spread }
            else if most == colour.green { turn = 2 + (colour.blue - colour.red) / spread }
            else { turn = 4 + (colour.red - colour.green) / spread }
            return (turn * 60 + 360).truncatingRemainder(dividingBy: 360)
        }
        for index in Palette.houseRGB.indices {
            let words = Palette.houseWordsRGB(index)
            XCTAssertGreaterThanOrEqual(words.contrast(with: Palette.panelRGB), 10, "House colour \(index)")
            if let own = hue(Palette.houseRGB[index]), let lifted = hue(words) {
                let apart = abs(own - lifted)
                XCTAssertLessThan(min(apart, 360 - apart), 30, "Its own hue, lifted: House colour \(index)")
            }
        }
        XCTAssertLessThan(Palette.houseRGB[1].contrast(with: Palette.panelRGB), 4.5, "The darkest House's colour needs the lift")
        Contrast.shared.isIncreased = true
        defer { Contrast.shared.isIncreased = false }
        XCTAssertGreaterThanOrEqual(Palette.houseWordsRGB(1).contrast(with: Palette.panelRGB), 13)
    }

    /// VoiceOver's cursor rings a hold or a company where it lies, about a
    /// hex across, and never smaller than a click can find.
    func testVoiceOversCursorRingsAHex() {
        XCTAssertEqual(MapAccessibility.ring(at: 30), 48, accuracy: 0.001)
        XCTAssertEqual(MapAccessibility.ring(at: Camera.minimumScale), 24, "Never smaller than a click's target")
        XCTAssertEqual(MapAccessibility.ring(at: Camera.maximumScale), Camera.maximumScale * 1.6, accuracy: 0.001, "A hex across")
    }

    func testWhatColourSaysIsSaidInShape() throws {
        XCTAssertFalse(WorldMarks.ownership(.own, at: .zero, radius: 10).isEmpty, "A bar over the keeper's own")
        XCTAssertFalse(WorldMarks.ownership(.foe, at: .zero, radius: 10).isEmpty, "A cross on a foe's")
        XCTAssertTrue(WorldMarks.ownership(.other, at: .zero, radius: 10).isEmpty, "Nothing for others")
        let (state, spear, _) = try atWar("shapes, not colours")
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.camera.focus(on: try XCTUnwrap(session.state.unit(spear)).position)
        Contrast.shared.differentiates = true
        try draw(WorldMarks(session: session))
        try draw(WorldMarks(session: session, modelsDrawn: true))
        for tone in [GameSession.Notice.Tone.good, .bad, .neutral] {
            try draw(ToneMark(tone: tone), width: 20, height: 20)
        }
        try draw(RaceTable(session: session).frame(width: 360), width: 400, height: 300)
    }

    func testVoiceOverOrdersAreCarriedOutAndSaid() throws {
        var state = world("orders carried out")
        let me = state.player
        let site = try XCTUnwrap(state.map.hexes.first { hex in
            state.canFound(at: hex, for: me) == nil && state.isExplored(hex, by: me) && state.unit(at: hex) == nil
        })
        state.units.append(NullmereCore.Unit(id: state.nextID, kind: .founder, owner: me, position: site))
        let founder = state.nextID
        state.nextID += 1
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.voiceOverRunning = { true }
        let founderItem = try XCTUnwrap(session.mapItems.first { $0.selection == .unit(founder) })
        let found = try XCTUnwrap(founderItem.orders.first { $0.founds })
        MapAccessibility.carryOut(found, for: founderItem, in: session)
        XCTAssertEqual(session.lastSaid, "Done: Found a hold here.")
        XCTAssertNotNil(session.state.hold(at: site))

        let lantern = try XCTUnwrap(session.state.units(of: me).first { $0.kind == .lantern })
        let lanternItem = try XCTUnwrap(session.mapItems.first { $0.selection == .unit(lantern.id) })
        let explore = try XCTUnwrap(lanternItem.orders.first { $0.name.hasPrefix("Explore") })
        MapAccessibility.carryOut(explore, for: lanternItem, in: session)
        XCTAssertEqual(session.lastSaid, "Done: Explore towards the unknown.")
        XCTAssertNotEqual(session.state.unit(lantern.id), lantern, "On its way")
    }

    func testThePannedCentreIsSaid() throws {
        let (state, spear, foe) = try atWar("the middle said")
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        session.camera.focus(on: seat.position)
        let ground = try XCTUnwrap(session.centreWords)
        XCTAssertTrue(ground.contains(seat.name), ground)
        XCTAssertFalse(ground.contains(" · "), "Said as a sentence, not a line of dots")
        // A spear chosen, a foe in the middle: the odds.
        session.selection = .unit(spear)
        session.camera.focus(on: foe)
        session.hover(foe)
        let strike = try XCTUnwrap(session.centreWords)
        XCTAssertTrue(strike.hasPrefix("Strike: they take"), strike)
        session.sayNow(strike)
        XCTAssertEqual(session.lastSaid, strike)
        // Who stands there, and how far it lies from the company chosen.
        session.hover(nil)
        session.camera.focus(on: seat.position)
        let there = try XCTUnwrap(session.centreWords)
        XCTAssertTrue(there.contains("of your Spears"), there)
    }

    /// A strike by the keyboard asks first, as Declare war does: M shows the
    /// odds, M again strikes; a march by M is said once it is under way.
    func testAStrikeByKeyAsksFirst() throws {
        let (state, spear, foe) = try atWar("asked first")
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        session.voiceOverRunning = { true }
        session.selection = .unit(spear)
        session.camera.focus(on: foe)
        let before = session.state.unit(at: foe)
        XCTAssertTrue(session.handle(.orderAtCentre))
        XCTAssertEqual(session.state.unit(at: foe), before, "The first M only shows the odds")
        XCTAssertTrue(session.notices.last?.text.hasPrefix("Strike? ") ?? false, session.notices.last?.text ?? "")
        XCTAssertTrue(session.handle(.orderAtCentre))
        XCTAssertNotEqual(session.state.unit(at: foe), before, "M again strikes")
    }

    func testAStrikeOnAHoldIsSaidAsItsWard() {
        let odds = MapAccessibility.odds(Forecast(target: .hold(1), dealt: 30...30, taken: 0...0, defenderHealth: 30,
                                                  attackerHealth: 100, couldCapture: true))
        XCTAssertEqual(odds, "the ward loses 30 of 30; out of their reach; the hold is taken")
    }

    func testTheDoorSaysWhenTheRealmIsOutOfReach() {
        XCTAssertEqual(FrontDoor.spokenState(of: .unreachable("No answer.")), "The realm is out of reach. No answer.")
        XCTAssertNil(FrontDoor.spokenState(of: .connecting))
    }
}

/// A link that sends nothing: the test speaks for the realm.
private final class SilentLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}

/// Quitting just after an order: what waits is given a moment to go.
@MainActor
final class QuittingTests: XCTestCase {
    func testNothingWaitingLetsTheAppQuitAtOnce() async {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: nil, identity: MemoryIdentity(),
                          opensAtOnce: false, transport: nil, pollInterval: 1)
        XCTAssertTrue(GameApp.current === app)
        XCTAssertEqual(app.ordersWaiting, 0)
        // The Mac waking is heard (with no realm across the network to ask).
        NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
        try? await Task.sleep(for: .milliseconds(100))
        let done = expectation(description: "quit")
        let start = Date()
        app.sendWaiting(within: 3) { done.fulfill() }
        await fulfillment(of: [done], timeout: 3)
        // Well within the three seconds it would wait for orders, on however
        // busy a runner.
        XCTAssertLessThan(Date().timeIntervalSince(start), 1.5, "Nothing to wait for")
    }
}

private final class MemoryIdentity: IdentityStore, @unchecked Sendable {
    var value: String?
    func load() -> String? { value }
    func save(_ identity: String) throws { value = identity }
}

/// One copy of the game at a time.
final class SingleInstanceTests: XCTestCase {
    func testASecondCopyHandsOverToTheFirst() {
        var brought: [pid_t] = []
        XCTAssertFalse(SingleInstance.handOver(to: [(42, { brought.append(42) })], current: 42), "Alone: it stays")
        XCTAssertTrue(SingleInstance.handOver(to: [(42, { brought.append(42) }), (7, { brought.append(7) })], current: 42))
        XCTAssertEqual(brought, [7], "The first copy comes forward")
        XCTAssertNil(SingleInstance.other(among: [42], current: 42), "Alone: it stays")
        XCTAssertEqual(SingleInstance.other(among: [42, 7], current: 42), 7, "Another running: that one comes forward")
        XCTAssertNil(SingleInstance.other(among: [], current: 42))
    }
}
