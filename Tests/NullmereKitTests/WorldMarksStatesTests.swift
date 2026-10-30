import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit
import NullmereTestSupport

/// The marks on the map in the states a war brings: an arrow in flight and
/// a company falling where it stood, a hold with foes at its gates, a ward
/// broken down, a veteran's chevrons, every kind of company's sign, and the
/// strike forecast against a hold and from beyond the foe's reach.
@MainActor
final class WorldMarksStatesTests: XCTestCase {
    private var dir: URL!

    override func setUp() async throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() async throws {
        try? FileManager.default.removeItem(at: dir)
    }

    private func draw(_ view: some View, width: CGFloat = 1000, height: CGFloat = 700) throws {
        let renderer = ImageRenderer(content: view.frame(width: width, height: height).background(Color.black))
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
    }

    /// A free, passable hex beside a place: no company, no hold.
    private func free(near hex: Hex, in state: GameState, distance: Int = 1) -> Hex? {
        state.map.hexes.first { candidate in
            candidate.distance(to: hex) == distance && state.map[candidate]?.terrain.isPassable == true
                && state.unit(at: candidate) == nil && state.hold(at: candidate) == nil
        }
    }

    func testAWarsMarksAreDrawn() throws {
        var state = GameState(settings: GameSettings(seedText: "a war drawn", houseCount: 3, radius: 18, keepers: 1))
        let me = state.player
        let foe = (me + 1) % state.houses.count
        _ = try state.perform(.declareWar(on: foe), as: me)
        let mine = try XCTUnwrap(state.seat(of: me))
        let theirs = try XCTUnwrap(state.seat(of: foe))
        func place(_ kind: UnitKind, of owner: Int, at hex: Hex, health: Int = 100, experience: Int = 0) -> Int {
            var unit = NullmereCore.Unit(id: state.nextID, kind: kind, owner: owner, position: hex)
            unit.health = health
            unit.experience = experience
            state.units.append(unit)
            state.nextID += 1
            return unit.id
        }
        // Foes gathered at the gates of the keeper's seat.
        for _ in 0..<Sentinel.gathering {
            _ = place(.spear, of: foe, at: try XCTUnwrap(free(near: mine.position, in: state)))
        }
        // A veteran spear at the foe's seat, whose ward is broken down.
        let veteran = place(.spear, of: me, at: try XCTUnwrap(free(near: theirs.position, in: state)), experience: 9)
        let ward = try XCTUnwrap(state.holds.firstIndex { $0.id == theirs.id })
        state.holds[ward].ward = max(1, state.holds[ward].maximumWard / 3)
        // Its gates bare, and the ground around it known: its broken ward in sight.
        state.units.removeAll { $0.position == theirs.position }
        state.reveal(around: theirs.position, range: 2, for: me)
        // A bow two hexes from a foe at death's door; a rider and a founder at home.
        let bowAt = try XCTUnwrap(free(near: mine.position, in: state, distance: 2))
        let bow = place(.bow, of: me, at: bowAt)
        let weak = place(.spear, of: foe, at: try XCTUnwrap(free(near: bowAt, in: state, distance: 2)), health: 1)
        _ = place(.rider, of: me, at: try XCTUnwrap(free(near: mine.position, in: state, distance: 3)))
        _ = place(.founder, of: me, at: try XCTUnwrap(free(near: mine.position, in: state, distance: 4)))

        let session = GameSession(state: state, store: LocalStore(directory: dir))
        session.dismissSeatBriefing()
        session.camera = Camera(scale: 12)
        XCTAssertTrue(session.isExplored(theirs.position) && session.isVisible(theirs.position), "The foe's seat in sight")
        XCTAssertTrue(session.threatened.contains(mine.id), "Foes at the gates")
        XCTAssertEqual(session.state.unit(veteran)?.rank, 3, "A sworn veteran")
        try draw(WorldMarks(session: session))
        try draw(WorldFallback(session: session))

        // A strike against the foe's seat, its ward broken down.
        session.selection = .unit(veteran)
        session.hover(theirs.position)
        let onHold = try XCTUnwrap(session.hoverForecast, "A hold in reach is forecast")
        XCTAssertEqual(onHold.target, .hold(theirs.id), "Its gates bare, the strike falls on its ward")
        try draw(ForecastOverlay(session: session))
        try draw(ForecastCard(forecast: onHold, targetName: theirs.name), width: 300, height: 200)
        // Each way a strike on a ward can go: broken and the hold taken,
        // broken, perhaps broken, or holding.
        for (dealt, ward, capture) in [(9...12, 8, true), (9...12, 8, false), (4...12, 8, false), (2...4, 8, false)] {
            let forecast = Forecast(target: .hold(theirs.id), dealt: dealt, taken: 0...0, defenderHealth: ward, attackerHealth: 100,
                                    couldCapture: capture)
            try draw(ForecastCard(forecast: forecast, targetName: theirs.name), width: 300, height: 200)
        }

        // A bow's shot from beyond the foe's reach.
        let weakAt = try XCTUnwrap(session.state.unit(weak)?.position)
        session.selection = .unit(bow)
        session.hover(weakAt)
        let fromAfar = try XCTUnwrap(session.hoverForecast, "A foe in a bow's reach is forecast")
        XCTAssertEqual(fromAfar.taken.upperBound, 0, "Out of their reach")
        try draw(ForecastCard(forecast: fromAfar, targetName: "Spear"), width: 300, height: 200)
        session.hover(nil)

        // The shot loosed: the arrow in flight, and the foe falling where it stood.
        XCTAssertTrue(session.perform(.attack(unit: bow, target: weakAt)))
        let blow = try XCTUnwrap(session.blows.last)
        XCTAssertTrue(blow.isRanged)
        XCTAssertFalse(blow.fallen.isEmpty, "The foe falls")
        // Drawn at its own moments, whatever the clock says: the arrow
        // crossing the gap, the flash where it lands, then the flash faded.
        let duration = GameSession.Blow.duration
        XCTAssertEqual(GameSession.Blow.flash(at: 0.05), 0, "In flight, nothing has landed")
        XCTAssertGreaterThan(GameSession.Blow.flash(at: 0.1), 0)
        XCTAssertEqual(GameSession.Blow.flash(at: 0.5), 0)
        for share in [0.05, 0.1, 0.5] {
            try draw(WorldMarks(session: session, moment: blow.start.addingTimeInterval(share * duration)))
        }
        try draw(WorldMarks(session: session))
    }
}

/// The voices' queue: stewards' envoys spoken one at a time, an envoy
/// answered before its turn passed over, and what was said kept.
@MainActor
final class VoiceQueueTests: XCTestCase {
    func testEnvoysAreSpokenInTurnAndAnAnsweredOneIsPassedOver() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = GameState(settings: GameSettings(seedText: "voices in turn", houseCount: 4, radius: 18, keepers: 1))
        let me = state.player
        let stewards = state.houses.indices.filter { $0 != me && !state.houses[$0].isPlayer }
        state.envoys.append(Envoy(id: 801, from: stewards[0], to: me, proposal: .pact, arrived: state.watch))
        state.envoys.append(Envoy(id: 802, from: stewards[1], to: me, proposal: .peace, arrived: state.watch))
        let voice = SlowVoice()
        let session = GameSession(state: state, store: LocalStore(directory: dir), voice: voice)

        // The first is spoken; while it is, the second is answered.
        XCTAssertTrue(session.perform(.answer(envoy: 802, accept: false)))
        let deadline = Date().addingTimeInterval(5)
        while session.spoken[.envoy(801)] == nil, Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertEqual(session.spoken[.envoy(801)], "The water is still between our Houses.")
        try await Task.sleep(nanoseconds: 400_000_000)
        XCTAssertNil(session.spoken[.envoy(802)], "An envoy answered before its turn isn't spoken")
        let asked = await voice.asked
        XCTAssertFalse(asked.contains { $0.kind == .envoy(proposal: .peace) }, "Not even asked for")
        XCTAssertTrue(asked.contains { $0.kind == .envoy(proposal: .pact) })
        XCTAssertEqual(LocalStore(directory: dir).loadVoices()[GameSession.Spoken.envoy(801).key], "The water is still between our Houses.",
                       "What was said is kept")
    }
}

private actor SlowVoice: Voice {
    private(set) var asked: [VoiceMoment] = []

    func speak(_ moment: VoiceMoment) async -> String? {
        asked.append(moment)
        try? await Task.sleep(nanoseconds: 200_000_000)
        return "The water is still between our Houses."
    }
}
