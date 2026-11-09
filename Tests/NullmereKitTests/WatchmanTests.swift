import AppKit
@testable import LauncherKit
import NullmereRealm
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The watchman on the Mac: what the keeper's watchfire made out marching
/// dark told as the realm words it, and his word on it asked of this Mac's
/// model under its own key, as soon as the session sees it; the ground
/// panel's line saying it plainly, with the model at work, its words, or
/// why it gave none.
@MainActor
final class WatchmanTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    /// A keeper's House with a watchfire on its own land that has made out
    /// a foe's company marching dark beside it.
    private func world() throws -> (GameState, fire: Watchfire, sighting: Watchfire.Sighting, event: GameEvent) {
        var state = GameState(settings: GameSettings(seedText: "the watchman on the Mac", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        state.houses[me].stock.timber = 100
        let owners = state.territory()
        let at = try XCTUnwrap(state.map.hexes.first { hex in
            state.territoryOwner(of: hex, in: owners) == me && state.watchfireRefusal(at: hex, as: me) == nil
        })
        _ = try state.perform(.watchfire(at), as: me)
        let foe = try XCTUnwrap(state.livingHouses.first { $0.id != me && !state.watchers(for: me).contains($0.id) }).id
        let spot = try XCTUnwrap(at.spiral(Watchfire.reach).first { hex in
            guard hex != at, let terrain = state.map[hex]?.terrain else { return false }
            return terrain.isPassable && !terrain.isWater && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        let company = try XCTUnwrap(state.placeUnit(.spear, tier: 1, for: foe, near: spot))
        state.units[try XCTUnwrap(state.unitIndex(company.id))].position = spot
        _ = try state.perform(.torches(unit: company.id, lit: false), as: foe)
        let events = state.keepWatchByFire()
        let event = try XCTUnwrap(events.first)
        let fire = try XCTUnwrap(state.watchfire(at: at))
        return (state, fire, try XCTUnwrap(fire.seen?.last), event)
    }

    func testTheWatchmanIsToldAndAskedForUnderHisOwnKey() throws {
        let (state, fire, sighting, event) = try world()
        let me = state.player
        XCTAssertEqual(GameSession.Spoken.watchman(sighting.key).key, "watchman-\(sighting.key)")
        XCTAssertEqual(GameSession.Spoken(key: "watchman-\(sighting.key)"), .watchman(sighting.key))
        let moment = VoiceFacts.watchman(sighting, fire: fire.at, for: me, in: state)
        XCTAssertEqual(moment.kind, .watchman)
        XCTAssertEqual(moment.facts, state.voiced(sighting, fire: fire.at, for: me).facts)
        XCTAssertTrue(moment.prompt.hasPrefix(Voicing.watchmanTask), moment.prompt)
        // What the fire made out told as the realm words it.
        XCTAssertEqual(Narration.line(for: event, in: state, viewer: me)?.text, state.tidings(of: event, for: me)?.text)
        XCTAssertNil(Narration.line(for: event, in: state, viewer: sighting.owner))
        // A session seeing it asks this Mac's model for the watchman's word.
        let session = GameSession(link: QuietLink(), house: me, world: state.view(for: me),
                                  store: LocalStore(directory: dir.appendingPathComponent(UUID().uuidString)), voice: Slow())
        session.dismissSeatBriefing()
        XCTAssertEqual(session.voicing?.key, .watchman(sighting.key), "Asked as the session sees what the fire made out")
        XCTAssertTrue(session.stillVoiced(.watchman(sighting.key)))
        // The ground panel's line: plainly, and the model at work on the
        // watchman's word, kept with CI's renders.
        XCTAssertTrue(state.view(for: me).sightingSaid(sighting, of: fire).hasPrefix("Made out in watch \(sighting.watch): "))
        try CardShot.keep(WatchmanLine(session: session, fire: fire, sighting: sighting)
            .padding(16).frame(width: PanelWidth.record).panelBackground().padding(20),
                          as: "game-watchman.png")
    }
}

/// Gives words only after a long while, and none once stopped.
private struct Slow: Voice {
    func speak(_ moment: VoiceMoment) async -> String? {
        try? await Task.sleep(for: .seconds(8))
        return Task.isCancelled ? nil : "Spears passed by the fire, keeper, their torches doused."
    }
}

/// A realm that hears nothing it is sent.
private final class QuietLink: RealmLink {
    var onEvent: ((RealmEvent) -> Void)?
    func connect() {}
    func arrive(name: String?) {}
    func send(_ command: Command) {}
    func setReady(_ ready: Bool) {}
    func leave() {}
}
