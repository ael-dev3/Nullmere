import Foundation
import LauncherCore
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereWorld

/// What the keys choose and do, as VoiceOver hears it, and what they say
/// when there is nothing for them to do: ground no lantern has seen,
/// chosen, is said as the map reads it; an order given by a key is said
/// done; a founder where no hold may stand is told why at once and offered
/// the way to a site; a keeper with no companies is told so; and what is
/// chosen on VoiceOver's map is brought into view.
@MainActor
final class KeysSpokenTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func session(_ state: GameState) -> GameSession {
        let session = GameSession(state: state, store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)))
        session.dismissSeatBriefing()
        return session
    }

    func testWhatTheKeysChooseAndDoIsSaidToVoiceOver() throws {
        let session = self.session(GameState(settings: GameSettings(seedText: "said to VoiceOver", houseCount: 4, radius: 18, keepers: 1)))
        session.voiceOverRunning = { true }

        // Space where the view is centred, over ground no lantern has seen:
        // the ground is chosen, and said as the map's line reads it.
        let unseen = try XCTUnwrap(session.state.map.hexes.first { !session.isExplored($0) })
        session.camera.focus(on: unseen)
        XCTAssertTrue(session.handle(.chooseAtCentre))
        XCTAssertEqual(session.selection, .tile(unseen))
        XCTAssertEqual(session.lastSaid, "Chosen: Unknown country, send Lanterns.")

        // F fortifies the chosen company, and VoiceOver hears it done.
        let spear = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .spear && !$0.fortified })
        session.selection = .unit(spear.id)
        XCTAssertTrue(session.handle(.fortify))
        XCTAssertEqual(session.state.unit(spear.id)?.fortified, true)
        XCTAssertEqual(session.lastSaid, "Done: \(spear.kind.title) fortified.")

        // Without VoiceOver, nothing is said at once.
        session.voiceOverRunning = { false }
        let said = session.lastSaid
        XCTAssertTrue(session.handle(.chooseAtCentre))
        XCTAssertEqual(session.lastSaid, said)
    }

    func testAFounderWhereNoHoldMayStandIsToldWhyAndOfferedTheWayToASite() throws {
        var state = GameState(settings: GameSettings(seedText: "too close to found", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let seat = try XCTUnwrap(state.seat(of: me))
        // The ground around the seat known, so a site to found on is too.
        state.reveal(around: seat.position, range: 6, for: me)
        let beside = try XCTUnwrap(state.map.neighbors(of: seat.position).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let founder = state.nextID
        state.units.append(NullmereCore.Unit(id: founder, kind: .founder, owner: me, position: beside))
        state.nextID += 1
        let session = self.session(state)
        session.voiceOverRunning = { true }
        let problem = try XCTUnwrap(session.state.canFound(at: beside, for: me), "Beside the seat no hold may stand")

        // B says why not at once, and asks nothing, however often pressed.
        session.selection = .unit(founder)
        XCTAssertTrue(session.handle(.found))
        XCTAssertEqual(session.notices.last?.text, String(describing: problem))
        XCTAssertTrue(session.handle(.found))
        XCTAssertNil(session.state.hold(at: beside), "Nothing is founded")
        XCTAssertFalse(session.notices.contains { $0.text.hasPrefix("Found a hold here?") }, "Nor asked")

        // VoiceOver's actions on it offer the way to the best site it knows
        // of instead of founding where it stands.
        let site = try XCTUnwrap(session.state.bestFoundingSite(for: me, from: beside))
        XCTAssertNotEqual(site, beside)
        let item = try XCTUnwrap(MapAccessibility.items(for: session).first { $0.selection == .unit(founder) })
        let march = try XCTUnwrap(item.orders.first { $0.name.hasPrefix("March to a site to found a hold, ") },
                                  "Among \(item.orders.map(\.name))")
        XCTAssertEqual(march.hex, site)
        XCTAssertTrue(march.name.contains(MapAccessibility.way(from: beside, to: site)), march.name)
        XCTAssertFalse(item.orders.contains { $0.founds }, "Not founding where no hold may stand")
    }

    func testAKeeperWithNoCompaniesIsToldSo() throws {
        var state = GameState(settings: GameSettings(seedText: "no companies left", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.units.removeAll { $0.owner == me }
        let session = self.session(state)
        session.selection = .none
        XCTAssertTrue(session.handle(.anyUnit(forward: true)))
        XCTAssertEqual(session.notices.last?.text, "You have no companies.")
        XCTAssertEqual(session.selection, .none, "Nothing chosen")
        XCTAssertTrue(session.handle(.anyUnit(forward: false)))
        XCTAssertEqual(session.notices.filter { $0.text == "You have no companies." }.count, 2, "Said each time")
    }

    /// What VoiceOver chooses on the map is chosen, and the view brought to
    /// it, at once below full motion, so the keys that act where the view is
    /// centred start from there.
    func testWhatVoiceOverChoosesIsBroughtIntoView() throws {
        let session = self.session(GameState(settings: GameSettings(seedText: "chosen by VoiceOver", houseCount: 4, radius: 18, keepers: 1)))
        session.motion = .still
        let seat = try XCTUnwrap(MapAccessibility.items(for: session).first { $0.isHold })
        let away = try XCTUnwrap(session.state.map.hexes.first { $0.distance(to: seat.hex) > 6 })
        session.camera.focus(on: away)
        XCTAssertNotEqual(session.camera.centreHex, seat.hex)
        session.choose(seat)
        XCTAssertEqual(session.selection, seat.selection)
        XCTAssertEqual(session.camera.centreHex, seat.hex, "The view brought to it")
    }

    /// A strike's odds as VoiceOver says them, for every way a blow on a
    /// company can go.
    func testAStrikesOddsAreSaidAsTheForecastCardShowsThem() {
        let sure = Forecast(target: .unit(.spear), dealt: 50...60, taken: 0...0, defenderHealth: 40, attackerHealth: 100, couldCapture: false)
        XCTAssertEqual(MapAccessibility.odds(sure), "they take 50 to 60 of 40; out of their reach; they fall")
        let taken = Forecast(target: .unit(.spear), dealt: 45...45, taken: 10...14, defenderHealth: 45, attackerHealth: 100, couldCapture: true)
        XCTAssertEqual(MapAccessibility.odds(taken), "they take 45 of 45; you take 10 to 14 of 100; they fall and the hold is taken")
        let ground = Forecast(target: .unit(.bow), dealt: 50...55, taken: 8...8, defenderHealth: 30, attackerHealth: 60, couldCapture: false,
                              takesTheField: true)
        XCTAssertEqual(MapAccessibility.odds(ground), "they take 50 to 55 of 30; you take 8 of 60; they fall and you take their ground")
        let close = Forecast(target: .unit(.rider), dealt: 20...50, taken: 50...70, defenderHealth: 40, attackerHealth: 60, couldCapture: false)
        XCTAssertEqual(MapAccessibility.odds(close), "they take 20 to 50 of 40; you take 50 to 70 of 60; they may fall; you may fall")
    }
}
