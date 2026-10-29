import Foundation
import NullmereRealm
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The session at its edges: what a click chooses, what a right-click
/// orders, a refused order told, a founding that chooses its new hold,
/// a keeper whose companies all have their orders, and the notices kept.
@MainActor
final class GameSessionEdgeTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A world at war with a foe's spear beside the keeper's own.
    private func warWorld() throws -> (GameState, spear: NullmereCore.Unit, beside: Hex, foe: Int) {
        var state = GameState(settings: GameSettings(seedText: "edges of a session", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let foe = (me + 1) % state.houses.count
        _ = try state.perform(.declareWar(on: foe), as: me)
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        let beside = try XCTUnwrap(state.map.neighbors(of: spear.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && !state.units.contains { $0.position == hex } && state.hold(at: hex) == nil
        })
        let enemy = try XCTUnwrap(state.units.firstIndex { $0.owner == foe && $0.kind.isMilitary })
        state.units[enemy].position = beside
        return (state, spear, beside, foe)
    }

    func testAClickChoosesWhatIsThere() throws {
        var (state, spear, beside, foe) = try warWorld()
        let theirs = try XCTUnwrap(state.holds.first { $0.owner == foe })
        state.houses[state.player].explored[try XCTUnwrap(state.map.index(of: theirs.position))] = true
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        var cues: [Ambience.Cue] = []
        session.onCue = { cues.append($0) }

        session.click(Hex(999, 999))
        XCTAssertEqual(session.selection, .none, "Beyond the world, nothing")
        session.click(spear.position)
        XCTAssertEqual(session.selection, .unit(spear.id), "The keeper's own company")
        session.click(spear.position)
        XCTAssertNotEqual(session.selection, .unit(spear.id), "Clicked again: what lies under it")
        session.click(theirs.position)
        XCTAssertEqual(session.selection, .hold(theirs.id), "A foreign hold the keeper knows of")
        session.click(beside)
        if case .unit(let id) = session.selection {
            XCTAssertNotEqual(id, spear.id, "A foe's company in sight")
        } else {
            XCTFail("A foe's company in sight is chosen")
        }
        let empty = try XCTUnwrap(session.state.map.hexes.first { hex in
            session.state.unit(at: hex) == nil && session.state.hold(at: hex) == nil
        })
        session.click(empty)
        XCTAssertEqual(session.selection, .tile(empty))
        XCTAssertTrue(cues.contains(.select))
    }

    func testARightClickStrikesAFoeInReachAndARefusalIsTold() throws {
        let (state, spear, beside, _) = try warWorld()
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.selection = .unit(spear.id)
        session.order(beside)
        XCTAssertFalse(session.blows.isEmpty, "A foe in reach is struck")

        // An order the rules refuse: the keeper is told why, in a notice.
        let before = session.notices.count
        XCTAssertFalse(session.perform(.move(unit: 987_654, to: beside)))
        XCTAssertEqual(session.notices.count, before + 1)
        XCTAssertEqual(session.notices.last?.tone, .bad)
    }

    func testAFoundingChoosesItsNewHold() throws {
        var state = GameState(settings: GameSettings(seedText: "a founding", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        // A keeper's lantern made a founder, standing where a hold may rise.
        let founder = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind == .lantern })
        state.units[founder].kind = .founder
        let site = try XCTUnwrap(state.map.hexes.first { hex in
            state.unit(at: hex) == nil && state.canFound(at: hex, for: me) == nil
        })
        state.units[founder].position = site
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        XCTAssertTrue(session.perform(.found(unit: state.units[founder].id)))
        guard case .hold(let id) = session.selection else { return XCTFail("The new hold is chosen") }
        XCTAssertEqual(session.state.hold(id)?.position, site)
    }

    func testWhenEveryCompanyHasItsOrdersTheKeeperIsTold() throws {
        var state = GameState(settings: GameSettings(seedText: "all ordered", houseCount: 4, radius: 18, keepers: 1))
        for index in state.units.indices where state.units[index].owner == state.player {
            state.units[index].fortified = true
        }
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        XCTAssertTrue(session.readyUnits.isEmpty)
        session.selectNextReadyUnit()
        XCTAssertEqual(session.notices.last?.text, "Every company has its orders.")
    }

    func testNoticesKeepTheLatestSix() {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "notices", houseCount: 3, radius: 16, keepers: 1)),
                                  store: LocalStore(directory: dir))
        for index in 1...9 { session.post("Notice \(index)", tone: .neutral) }
        XCTAssertEqual(session.notices.count, 6)
        XCTAssertEqual(session.notices.first?.text, "Notice 4")
        XCTAssertEqual(session.notices.last?.text, "Notice 9")
    }

    func testARefusedOrderFromTheRealmIsToldAndTheWorldKept() {
        let link = QuietLink()
        let state = GameState(settings: GameSettings(seedText: "refused by the realm", houseCount: 3, radius: 16, keepers: 1))
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player), store: LocalStore(directory: dir))
        link.onEvent?(.orderRefused(.refused("The ford is held."), session.state))
        XCTAssertEqual(session.notices.last?.text, "The ford is held.")
        XCTAssertEqual(session.notices.last?.tone, .bad)
        link.onEvent?(.unreachable("No answer."))
        XCTAssertTrue(session.isOutOfReach)
    }

    func testAWatchThatBringsFoesToTheGatesIsWarnedOfAndTheWelcomeWaitsForIt() throws {
        var world = GameState(settings: GameSettings(seedText: "foes at the gates", houseCount: 3, radius: 18, keepers: 1))
        let me = world.player
        let foe = (me + 1) % world.houses.count
        _ = try world.perform(.declareWar(on: foe), as: me)
        let store = LocalStore(directory: dir)
        _ = GameSession(link: QuietLink(), house: me, world: world.view(for: me), store: store)
        // Back again with all but the last first step taken.
        var steps = FirstSteps()
        steps.mark(.work)
        steps.mark(.march)
        store.saveFirstSteps(steps)
        let link = QuietLink()
        let session = GameSession(link: link, house: me, world: world.view(for: me), store: store)
        var cues: [Ambience.Cue] = []
        session.onCue = { cues.append($0) }
        XCTAssertNotNil(session.firstSteps)
        let spear = try XCTUnwrap(world.units(of: me).first { $0.kind == .spear })
        session.selection = .unit(spear.id)

        session.endWatch()
        XCTAssertNil(session.firstSteps, "The last step taken")
        XCTAssertFalse(session.notices.contains { $0.text == GameSession.welcome }, "The welcome waits for the watch to turn")

        // The watch turns: foes gather near the seat, and the chosen spear is gone.
        var next = world
        next.units.removeAll { $0.id == spear.id }
        let seat = try XCTUnwrap(next.seat(of: me))
        let spots = next.map.hexes.filter { hex in
            hex.distance(to: seat.position) == 2 && next.map[hex]?.terrain.isPassable == true
                && next.unit(at: hex) == nil && next.hold(at: hex) == nil
        }
        XCTAssertGreaterThanOrEqual(spots.count, Sentinel.gathering)
        for spot in spots.prefix(Sentinel.gathering) {
            next.units.append(NullmereCore.Unit(id: next.nextID, kind: .spear, owner: foe, position: spot))
            next.nextID += 1
        }
        next.watch += 1
        link.onEvent?(.watchTurned(next.view(for: me), []))
        XCTAssertTrue(session.notices.contains { $0.text == GameSession.welcome }, "Said once the watch turns")
        XCTAssertTrue(session.notices.contains { $0.text.contains("gather near") && $0.tone == .bad })
        XCTAssertTrue(cues.contains(.dread))
        XCTAssertEqual(session.selection, .none, "A company that is gone is chosen no longer")
    }

    /// The last first step taken by an order, not by saying ready: the
    /// welcome is said at once, with no watch to wait for.
    func testTheWelcomeIsSaidAtOnceWhenAnOrderTakesTheLastStep() throws {
        let world = GameState(settings: GameSettings(seedText: "a last march", houseCount: 3, radius: 18, keepers: 1))
        let me = world.player
        let store = LocalStore(directory: dir)
        _ = GameSession(link: QuietLink(), house: me, world: world.view(for: me), store: store)
        var steps = FirstSteps()
        steps.mark(.work)
        steps.mark(.ready)
        store.saveFirstSteps(steps)
        let session = GameSession(link: QuietLink(), house: me, world: world.view(for: me), store: store)
        XCTAssertNotNil(session.firstSteps)
        let lantern = try XCTUnwrap(world.units(of: me).first { $0.kind == .lantern })
        let step = try XCTUnwrap(world.map.neighbors(of: lantern.position).first { hex in
            world.map[hex]?.terrain.isPassable == true && world.unit(at: hex) == nil && world.hold(at: hex) == nil
        })
        XCTAssertTrue(session.perform(.move(unit: lantern.id, to: step)))
        XCTAssertNil(session.firstSteps, "The last step taken")
        XCTAssertTrue(session.notices.contains { $0.text == GameSession.welcome }, "and the welcome said at once")
    }

    /// A new age seats the keeper afresh: the session hands the new world to
    /// the app, which begins it.
    func testANewAgeIsHandedToTheApp() throws {
        var realm = RealmState(name: "The Nullmere", seed: "a new age", seats: 4, radius: 18, watchLength: 60, now: 0)
        let keeper = try realm.arrive("a", name: "Ama", now: 0)
        let world = try XCTUnwrap(realm.view(for: "a")).world
        let link = QuietLink()
        let session = GameSession(link: link, house: try XCTUnwrap(keeper.house), world: world, store: LocalStore(directory: dir))
        var handed: (Keeper, GameState)?
        session.onNewAge = { handed = ($0, $1) }
        link.onEvent?(.arrived(keeper, world))
        XCTAssertEqual(handed?.0, keeper)
        XCTAssertEqual(handed?.1, world)
    }

    func testATakenHoldIsATriumphAndAFallenAttackerIsDrawnWhereItStood() throws {
        let (state, spear, beside, foe) = try warWorld()
        let me = state.player
        let taken = GameSession.cues(for: .attack(unit: spear.id, target: beside),
                                     events: [.holdCaptured(hold: 1, from: foe, by: me)], in: state, player: me)
        XCTAssertEqual(taken, [.clash, .triumph])
        let lost = GameSession.cues(for: .attack(unit: spear.id, target: beside),
                                    events: [.holdCaptured(hold: 1, from: me, by: foe)], in: state, player: me)
        XCTAssertEqual(lost, [.clash])

        let session = GameSession(state: state, store: LocalStore(directory: dir))
        let enemy = try XCTUnwrap(state.unit(at: beside))
        session.showBlows([.battle(Battle(
            attacker: spear.id, attackerOwner: me, attackerKind: .spear,
            defender: enemy.id, defenderOwner: foe, defenderKind: enemy.kind,
            hold: nil, at: beside, damageDealt: 10, damageTaken: 120, attackerFell: true, defenderFell: false
        ))])
        let blow = try XCTUnwrap(session.blows.last)
        XCTAssertEqual(blow.fallen, [GameSession.Blow.Fallen(kind: .spear, owner: me, at: spear.position)])
        XCTAssertEqual(blow.attacker, spear.id)
        XCTAssertEqual(blow.defender, enemy.id)
    }
}

private final class QuietLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
