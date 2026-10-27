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
        var state = GameState(settings: GameSettings(seedText: "edges of a session", houseCount: 4, radius: 18))
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
        var state = GameState(settings: GameSettings(seedText: "a founding", houseCount: 4, radius: 18))
        let me = state.player
        let founder = try XCTUnwrap(state.units.firstIndex { $0.owner == me && $0.kind == .founder })
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
        var state = GameState(settings: GameSettings(seedText: "all ordered", houseCount: 4, radius: 18))
        for index in state.units.indices where state.units[index].owner == state.player {
            state.units[index].fortified = true
        }
        let session = GameSession(state: state, store: LocalStore(directory: dir))
        XCTAssertTrue(session.readyUnits.isEmpty)
        session.selectNextReadyUnit()
        XCTAssertEqual(session.notices.last?.text, "Every company has its orders.")
    }

    func testNoticesKeepTheLatestSix() {
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "notices", houseCount: 3, radius: 16)),
                                  store: LocalStore(directory: dir))
        for index in 1...9 { session.post("Notice \(index)", tone: .neutral) }
        XCTAssertEqual(session.notices.count, 6)
        XCTAssertEqual(session.notices.first?.text, "Notice 4")
        XCTAssertEqual(session.notices.last?.text, "Notice 9")
    }

    func testARefusedOrderFromTheRealmIsToldAndTheWorldKept() {
        let link = QuietLink()
        let state = GameState(settings: GameSettings(seedText: "refused by the realm", houseCount: 3, radius: 16))
        let session = GameSession(link: link, house: state.player, world: state.view(for: state.player), store: LocalStore(directory: dir))
        link.onEvent?(.orderRefused(.refused("The ford is held."), session.state))
        XCTAssertEqual(session.notices.last?.text, "The ford is held.")
        XCTAssertEqual(session.notices.last?.tone, .bad)
        link.onEvent?(.unreachable("No answer."))
        XCTAssertTrue(session.isOutOfReach)
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
