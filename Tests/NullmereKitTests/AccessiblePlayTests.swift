import AppKit
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
@testable import NullmereRealm

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
    }

    private func world(_ seed: String) -> GameState {
        GameState(settings: GameSettings(seedText: seed, houseCount: 3, radius: 16))
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
        let explore = try XCTUnwrap(lanternOrders.first { $0.name.hasPrefix("Explore toward the unknown") }, "\(lanternOrders.map(\.name))")
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

    func testAConfirmationWaitsLongerForVoiceOver() {
        let start = Date()
        var spoken = Confirmation(span: Confirmation.spokenWindow)
        XCTAssertFalse(spoken.press(at: start))
        XCTAssertTrue(spoken.press(at: start.addingTimeInterval(Confirmation.window + 4)), "Long after three seconds, still armed")
        var quick = Confirmation()
        XCTAssertFalse(quick.press(at: start))
        XCTAssertFalse(quick.press(at: start.addingTimeInterval(Confirmation.window + 4)))
    }

    func testIncreasedContrastRaisesFaintText() {
        XCTAssertEqual(Palette.text(0.4), Palette.ink.opacity(0.4))
        Contrast.shared.isIncreased = true
        XCTAssertEqual(Palette.text(0.4), Palette.ink.opacity(0.85), "Faint text, made legible")
        XCTAssertEqual(Palette.text(0.95), Palette.ink.opacity(0.95), "Bright text, as it was")
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
        let done = expectation(description: "quit")
        let start = Date()
        app.sendWaiting(within: 3) { done.fulfill() }
        await fulfillment(of: [done], timeout: 2)
        XCTAssertLessThan(Date().timeIntervalSince(start), 1, "Nothing to wait for")
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
        XCTAssertNil(SingleInstance.other(among: [42], current: 42), "Alone: it stays")
        XCTAssertEqual(SingleInstance.other(among: [42, 7], current: 42), 7, "Another running: that one comes forward")
        XCTAssertNil(SingleInstance.other(among: [], current: 42))
    }
}
