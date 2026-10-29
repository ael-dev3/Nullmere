import AppKit
import SwiftUI
import XCTest
import NullmereRealm
@testable import NullmereCore
@testable import NullmereKit

@MainActor
final class RaceTests: XCTestCase {
    private func game() -> GameState {
        GameState(settings: GameSettings(seedText: "race", houseCount: 3, radius: 16, keepers: 1))
    }

    func testARivalNearingTheSpireIsAnnouncedOnce() throws {
        let before = game()
        var after = before
        let rival = 1
        let seat = try XCTUnwrap(after.seat(of: rival))
        after.holds[after.holdIndex(seat.id)!].levels[.moonspire] = 4
        let warnings = Race.warnings(before: before, after: after, player: after.player)
        XCTAssertEqual(warnings.count, 1)
        XCTAssertEqual(warnings.first?.tone, .bad)
        XCTAssertTrue(warnings.first?.text.contains("fourth stage") ?? false)
        XCTAssertTrue(Race.warnings(before: after, after: after, player: after.player).isEmpty, "Said once, not every watch")
    }

    func testThePlayerHearsTheyAreNearDominion() {
        let before = game()
        var after = before
        // Give the player's House holds enough to stand two short of dominion.
        let need = after.dominionNeed
        var id = 80_000
        for hex in after.map.hexes where after.holds(of: after.player).count < need - 2 {
            guard after.map[hex]?.terrain.isSettleable == true, after.holds.allSatisfy({ $0.position.distance(to: hex) >= 3 }) else { continue }
            after.holds.append(Hold(id: id, name: "Hold \(id)", owner: after.player, position: hex, isSeat: false, foundedWatch: 1))
            id += 1
        }
        let warnings = Race.warnings(before: before, after: after, player: after.player)
        XCTAssertEqual(warnings.map(\.tone), [.good])
        XCTAssertTrue(warnings.first?.text.contains("dominion needs") ?? false)
    }

    func testCounselTurnsToTheRace() throws {
        var state = game()
        for _ in 0..<45 {
            state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        let rival = try XCTUnwrap(state.livingHouses.first { !$0.isPlayer })
        let seat = try XCTUnwrap(state.seat(of: rival.id))
        let spire = try XCTUnwrap(state.holdIndex(seat.id))
        state.holds[spire].levels[.moonspire] = 4
        let advice = try XCTUnwrap(Counsel.advice(for: state, player: state.player))
        XCTAssertTrue(advice.contains(seat.name), "Counsel names the seat to march on")
    }

    func testTributeIsOfferedOnlyToTheClearlyWeaker() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        var state = game()
        XCTAssertFalse(GameSession(state: state, store: LocalStore(directory: dir)).canDemandTribute(from: 1), "Not of an equal")
        state.units.removeAll { $0.owner == 1 }
        let seat = try XCTUnwrap(state.seat(of: state.player))
        for _ in 0..<4 { state.placeUnit(.spear, for: state.player, near: seat.position) }
        XCTAssertTrue(GameSession(state: state, store: LocalStore(directory: dir)).canDemandTribute(from: 1))
    }

    func testTheRaceTableReadsEachHouse() {
        let state = game()
        let line = RaceTable.spoken(state.standing(of: state.player), in: state, player: state.player)
        XCTAssertEqual(line, "You: 1 of \(state.dominionNeed) holds for dominion, Moonspire stage 0 of 5.")
    }
}

@MainActor
final class EndingTests: XCTestCase {
    /// Writes a rendered view where CI prints its screenshots.
    private func keep(_ view: some View, as name: String, size: CGSize) throws {
        let renderer = ImageRenderer(content: view.frame(width: size.width, height: size.height).background(Color.black))
        renderer.scale = 2
        let image = try XCTUnwrap(renderer.cgImage)
        // CI asks for the renders, to print them with its screenshots.
        guard let path = ProcessInfo.processInfo.environment["NULLMERE_KEEP_RENDERS"] else { return }
        let build = URL(fileURLWithPath: path)
        try FileManager.default.createDirectory(at: build, withIntermediateDirectories: true)
        let png = try XCTUnwrap(NSBitmapImageRep(cgImage: image).representation(using: .png, properties: [:]))
        try png.write(to: build.appendingPathComponent(name))
    }

    func testAFinishedGameTellsItsStory() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = LocalStore(directory: dir)
        // A world that ends within 260 watches, found as the rules play it.
        let seed = try XCTUnwrap((13..<33).map { "siege check \($0)" }.first { text in
            var world = GameState(settings: GameSettings(seedText: text, keepers: 1))
            while world.outcome == nil, world.watch < 260 {
                _ = world.stewardTurn(for: world.player)
                _ = world.endWatch()
            }
            return world.outcome != nil
        })
        let session = GameSession(state: GameState(settings: GameSettings(seedText: seed, keepers: 1)), store: store)
        session.autoplay(watches: 100)
        // Offscreen rendering leaves a scroll view empty: draw the table alone.
        try keep(RaceTable(session: session).padding(20).frame(width: 360).panelBackground(), as: "game-race.png",
                 size: CGSize(width: 400, height: 260))

        session.autoplay(watches: 160)
        let outcome = try XCTUnwrap(session.state.outcome)
        let points = StoryChart.points(for: session.state)
        let mine = points.filter { $0.house == session.player }
        if !session.playerHouse.isEliminated {
            XCTAssertEqual(mine.map(\.watch), Array(1...session.state.watch), "A line for the whole game, a point a watch, to the end")
        } else {
            XCTAssertEqual(mine.last?.holds, 0, "A fallen House's line ends where it fell")
        }
        XCTAssertTrue(StoryChart.summary(of: session.state, player: session.player).hasPrefix("Over \(session.state.watch) watches"))

        let app = GameApp(store: store, readiness: { .ready }, sound: false, address: .hosted(seed: "ending"),
                          identity: FileIdentityStore(url: dir.appendingPathComponent("identity")))
        try keep(OutcomeOverlay(app: app, session: session, outcome: outcome), as: "game-ending.png", size: CGSize(width: 1100, height: 760))
    }

    func testTheEndHasItsSound() {
        let won = Outcome(winner: 0, kind: .dominion, watch: 90)
        XCTAssertEqual(GameSession.cues(for: [.gameEnded(won)], player: 0), [.watch, .triumph])
        XCTAssertEqual(GameSession.cues(for: [.gameEnded(won)], player: 1), [.watch, .toll])
    }
}

@MainActor
final class CombatFeelTests: XCTestCase {
    func testABlowLeansInFlashesAndShakesThenSettles() {
        typealias Blow = GameSession.Blow
        XCTAssertEqual(Blow.lunge(at: 0), 0)
        XCTAssertEqual(Blow.lunge(at: 0.15), 0.38, accuracy: 0.001, "Halfway in at the height of the lunge")
        XCTAssertEqual(Blow.lunge(at: 0.3), 0, accuracy: 0.001)
        XCTAssertEqual(Blow.lunge(at: 0.8), 0)
        XCTAssertEqual(Blow.flash(at: 0.08), 1, accuracy: 0.001, "The flash comes as the blow lands")
        XCTAssertEqual(Blow.flash(at: 0.5), 0)
        XCTAssertEqual(Blow.shake(at: 0.05), 0, "No shaking before the blow lands")
        XCTAssertGreaterThan((0..<20).map { abs(Blow.shake(at: 0.1 + Double($0) * 0.0175)) }.max() ?? 0, 1)
        XCTAssertEqual(Blow.shake(at: 0.6), 0)
    }

    func testTheFallenAndTheBowsAreShown() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "blows", houseCount: 3, radius: 16, keepers: 1)),
                                  store: LocalStore(directory: dir))
        let mine = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind.isMilitary })
        let target = try XCTUnwrap(mine.position.ring(2).first)
        let shot = Battle(attacker: mine.id, attackerOwner: session.player, attackerKind: .bow,
                          defender: 999, defenderOwner: 1, defenderKind: .rider, hold: nil, at: target,
                          damageDealt: 40, damageTaken: 0, attackerFell: false, defenderFell: true)
        session.showBlows([.battle(shot)], from: [mine.id: mine.position])
        let blow = try XCTUnwrap(session.blows.first)
        XCTAssertTrue(blow.isRanged)
        XCTAssertEqual(blow.attacker, mine.id)
        XCTAssertEqual(blow.defender, 999)
        XCTAssertEqual(blow.fallen, [GameSession.Blow.Fallen(kind: .rider, owner: 1, at: target)])
    }
}
