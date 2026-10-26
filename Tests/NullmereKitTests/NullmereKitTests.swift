import AppKit
import Metal
import LauncherCore
import NullmereCore
import XCTest
@testable import NullmereKit

final class WorldShaderTests: XCTestCase {
    func testUniformsAreThreeFloat4s() {
        XCTAssertEqual(MemoryLayout<WorldUniforms>.stride, 48)
        XCTAssertEqual(MemoryLayout<WorldUniforms>.alignment, 16)
    }

    /// Compiles the world shader and builds its pipeline on this Mac's GPU.
    func testShaderCompilesAndBuildsAPipeline() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        let library = try device.makeLibrary(source: WorldShader.source, options: nil)
        XCTAssertNoThrow(try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm))
    }
}

final class TileTextureTests: XCTestCase {
    func testEachTileLandsAtItsAxialTexel() {
        let state = GameState(settings: GameSettings(seedText: "tile texture", houseCount: 3, radius: 14))
        let side = TileTexture.side(for: state.map)
        let bytes = TileTexture.bytes(for: state, viewer: state.player)
        XCTAssertEqual(side, 29)
        XCTAssertEqual(bytes.count, side * side * 4)
        let visible = state.visibility(for: state.player)
        for (index, hex) in state.map.hexes.enumerated() {
            let offset = ((hex.r + 14) * side + (hex.q + 14)) * 4
            XCTAssertEqual(Int(bytes[offset]), Terrain.allCases.firstIndex(of: state.map[index].terrain))
            if visible[index] {
                XCTAssertEqual(bytes[offset + 3] / 16, 2)
            }
        }
        let seat = try! XCTUnwrap(state.seat(of: state.player))
        let offset = ((seat.position.r + 14) * side + (seat.position.q + 14)) * 4
        XCTAssertEqual(Int(bytes[offset + 3] % 16), state.playerHouse.sigil + 1, "the seat is in its House's colour")
    }
}

private extension GameState {
    var playerHouse: House { houses[player] }
}

final class CameraTests: XCTestCase {
    func testPointsAndHexesRoundTrip() {
        var camera = Camera(centerX: 3, centerY: -2, scale: 30)
        let size = CGSize(width: 1200, height: 800)
        for hex in Hex(1, -1).spiral(6) {
            XCTAssertEqual(camera.hex(at: camera.viewPoint(of: hex, in: size), in: size), hex)
        }
        let anchor = CGPoint(x: 300, y: 200)
        let before = camera.world(at: anchor, in: size)
        camera.zoom(by: 1.7, around: anchor, in: size)
        let after = camera.world(at: anchor, in: size)
        XCTAssertEqual(before.x, after.x, accuracy: 1e-9)
        XCTAssertEqual(before.y, after.y, accuracy: 1e-9)
        camera.zoom(by: 1000, around: anchor, in: size)
        XCTAssertEqual(camera.scale, Camera.maximumScale)
        camera.pan(dx: 1e7, dy: -1e7)
        camera.clamp(toRadius: 20)
        XCTAssertLessThanOrEqual(abs(camera.centerX), 3.0.squareRoot() * 20)
        XCTAssertLessThanOrEqual(abs(camera.centerY), 30)
    }
}

final class SaveStoreTests: XCTestCase {
    func testSavesAndLoadsTheWholeGame() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = SaveStore(directory: directory)
        XCTAssertFalse(store.hasSave)
        XCTAssertNil(store.load())
        var state = GameState(settings: GameSettings(seedText: "saved water", houseCount: 3, radius: 14))
        _ = state.endWatch()
        store.save(state)
        XCTAssertTrue(store.hasSave)
        XCTAssertEqual(store.load(), state)
        store.delete()
        XCTAssertFalse(store.hasSave)
    }
}

@MainActor
final class GameSessionTests: XCTestCase {
    private func session() -> (GameSession, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let state = GameState(settings: GameSettings(seedText: "session", houseCount: 3, radius: 16))
        return (GameSession(state: state, store: SaveStore(directory: directory)), directory)
    }

    func testClickingSelectsOwnCompaniesThenTheGroundBeneath() throws {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        let unit = try XCTUnwrap(session.state.units(of: session.player).first)
        session.click(unit.position)
        XCTAssertEqual(session.selection, .unit(unit.id))
        XCTAssertEqual(session.selectedUnit?.id, unit.id)
        session.click(unit.position)
        XCTAssertNotEqual(session.selection, .unit(unit.id))
    }

    func testRefusedOrdersBecomeNoticesAndChangeNothing() throws {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = session.state
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        XCTAssertFalse(session.perform(.build(hold: seat.id, kind: .moonspire)))
        XCTAssertEqual(session.state, before)
        XCTAssertEqual(session.notices.last?.tone, .bad)
    }

    func testEndingTheWatchAdvancesAndSaves() {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        session.endWatch()
        XCTAssertEqual(session.state.watch, 2)
        XCTAssertEqual(SaveStore(directory: directory).load()?.watch, 2)
    }

    func testMarchesAreShownFromWhereTheCompanyStood() throws {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        let lantern = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .lantern })
        let target = try XCTUnwrap(lantern.position.spiral(3).first {
            $0.distance(to: lantern.position) == 2 && session.state.map[$0]?.terrain.isPassable == true
                && session.state.unit(at: $0) == nil && session.state.path(for: lantern, to: $0) != nil
        })
        XCTAssertTrue(session.perform(.move(unit: lantern.id, to: target)))
        let march = try XCTUnwrap(session.marches[lantern.id])
        XCTAssertEqual(march.path.first, lantern.position)
        XCTAssertEqual(march.path.last, session.state.unit(lantern.id)?.position)
    }

    func testAutoplayPlaysWholeWatches() {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        session.autoplay(watches: 12)
        XCTAssertEqual(session.state.watch, 13)
        XCTAssertGreaterThan(session.playerHouse.explored.filter { $0 }.count, 91)
        XCTAssertEqual(session.selection, .none)
    }

    func testNextUnitCyclesThroughReadyCompanies() {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        let ready = session.readyUnits.map(\.id).sorted()
        XCTAssertFalse(ready.isEmpty)
        var seen: [Int] = []
        for _ in ready {
            session.selectNextReadyUnit()
            if case .unit(let id) = session.selection { seen.append(id) }
        }
        XCTAssertEqual(seen, ready)
    }
}

final class NarrationTests: XCTestCase {
    func testRomanNumerals() {
        XCTAssertEqual(Narration.roman(1), "I")
        XCTAssertEqual(Narration.roman(5), "V")
        XCTAssertEqual(Narration.roman(9), "VI")
    }
}

final class CounselTests: XCTestCase {
    func testCounselGuidesTheOpeningAndThenFallsSilent() {
        var state = GameState(settings: GameSettings(seedText: "counsel", houseCount: 3, radius: 16))
        let first = Counsel.advice(for: state, player: state.player)
        XCTAssertNotNil(first)
        XCTAssertTrue(first!.contains("Lantern"))
        var said: Set<String> = []
        for _ in 0..<Counsel.lastWatch + 1 {
            if let advice = Counsel.advice(for: state, player: state.player) { said.insert(advice) }
            _ = state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        XCTAssertGreaterThan(said.count, 2, "the advice changes as the House grows")
        XCTAssertNil(Counsel.advice(for: state, player: state.player), "and stops after the opening")
    }
}

@MainActor
final class GameGateTests: XCTestCase {
    func testTheGameOpensOnlyOnceTheModelIsReady() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var state = ModelReadiness.modelNotReady
        let app = GameApp(store: SaveStore(directory: directory), readiness: { state }, sound: false)

        for blocked in [ModelReadiness.modelNotReady, .appleIntelligenceNotEnabled, .deviceNotEligible, .unavailable] {
            state = blocked
            app.checkModel()
            XCTAssertEqual(app.readiness, blocked)
            guard case .gate = app.phase else { return XCTFail("\(blocked) must keep the game closed") }
            app.begin(GameSettings(seedText: "too soon", houseCount: 3, radius: 14))
            XCTAssertNil(app.session, "No game begins behind the gate")
        }

        state = .ready
        app.checkModel()
        guard case .title = app.phase else { return XCTFail("A ready model opens the title screen") }
        app.begin(GameSettings(seedText: "now", houseCount: 3, radius: 14))
        XCTAssertNotNil(app.session)
    }
}

final class HoverInfoTests: XCTestCase {
    func testTheLineDescribesTheGroundUnderThePointer() throws {
        let state = GameState(settings: GameSettings(seedText: "hover", houseCount: 3, radius: 16))
        let territory = state.territory()
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let line = try XCTUnwrap(HoverInfo.line(for: seat.position, in: state, explored: true, territory: territory))
        XCTAssertTrue(line.contains(seat.name))
        XCTAssertTrue(line.contains("land of \(state.houses[state.player].title)"))
        XCTAssertEqual(HoverInfo.line(for: seat.position, in: state, explored: false, territory: territory), "Unknown country · send a Lantern")
        XCTAssertNil(HoverInfo.line(for: Hex(999, 0), in: state, explored: true, territory: territory))

        let still = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain == .still })
        XCTAssertTrue(HoverInfo.line(for: still, in: state, explored: true, territory: territory)!.contains("impassable"))
        let wood = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain == .blackwood })
        let woodLine = HoverInfo.line(for: wood, in: state, explored: true, territory: territory)!
        XCTAssertTrue(woodLine.contains("2 moves") && woodLine.contains("+25% defence"), woodLine)
    }
}

@MainActor
final class UndoTests: XCTestCase {
    private func session() -> (GameSession, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let state = GameState(settings: GameSettings(seedText: "undo", houseCount: 3, radius: 16))
        return (GameSession(state: state, store: SaveStore(directory: directory)), directory)
    }

    func testABuildingCanBeTakenBack() throws {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        let before = session.state
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        XCTAssertFalse(session.canUndo)
        XCTAssertTrue(session.perform(.build(hold: seat.id, kind: .granary)))
        XCTAssertTrue(session.canUndo)
        session.undo()
        XCTAssertEqual(session.state, before, "Everything is as it was, resources included")
        XCTAssertFalse(session.canUndo)
    }

    func testWhatChanceOrDiscoveryDecidedStays() throws {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        let lantern = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .lantern })
        // March the lantern somewhere it will see new country.
        let far = try XCTUnwrap(lantern.position.ring(4).first {
            session.state.map[$0]?.terrain.isPassable == true && session.state.path(for: lantern, to: $0) != nil
        })
        let explored = session.playerHouse.explored.filter { $0 }.count
        XCTAssertTrue(session.perform(.move(unit: lantern.id, to: far)))
        if session.playerHouse.explored.filter({ $0 }).count > explored {
            XCTAssertFalse(session.canUndo, "A march that revealed country can't be taken back")
        }
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        XCTAssertTrue(session.perform(.build(hold: seat.id, kind: .granary)))
        XCTAssertTrue(session.canUndo)
        session.endWatch()
        XCTAssertFalse(session.canUndo, "A new watch starts with nothing to take back")
    }
}

@MainActor
final class BlowTests: XCTestCase {
    func testTheBlowsThePlayerSeesAreShownThenForgotten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = GameState(settings: GameSettings(seedText: "blows", houseCount: 3, radius: 16))
        let session = GameSession(state: state, store: SaveStore(directory: directory))
        let mine = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind.isMilitary })
        let near = Battle(attacker: mine.id, attackerOwner: session.player, attackerKind: mine.kind,
                          defender: 999, defenderOwner: 1, defenderKind: .spear, hold: nil, at: mine.position,
                          damageDealt: 23, damageTaken: 9, attackerFell: false, defenderFell: false)
        let hidden = try XCTUnwrap(session.state.map.hexes.first { !session.isVisible($0) })
        let unseen = Battle(attacker: 998, attackerOwner: 1, attackerKind: .spear,
                            defender: 997, defenderOwner: 2, defenderKind: .spear, hold: nil, at: hidden,
                            damageDealt: 30, damageTaken: 20, attackerFell: false, defenderFell: false)
        session.showBlows([.battle(near), .battle(unseen)])
        XCTAssertEqual(session.blows.map(\.damage), [23], "Only blows the player could see")
        XCTAssertFalse(session.blows[0].againstPlayer)
        try await Task.sleep(for: .seconds(GameSession.Blow.duration + 0.3))
        XCTAssertTrue(session.blows.isEmpty)
    }
}

final class SaveRobustnessTests: XCTestCase {
    private func directory() -> URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    func testEachSaveKeepsTheOneBeforeAsABackup() throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        var state = GameState(settings: GameSettings(seedText: "backup", houseCount: 3, radius: 14))
        store.save(state)
        XCTAssertFalse(FileManager.default.fileExists(atPath: store.backupURL.path))
        let first = state
        _ = state.endWatch()
        store.save(state)
        XCTAssertEqual(store.open(), .game(state))
        let backup = try JSONDecoder().decode(GameState.self, from: Data(contentsOf: store.backupURL))
        XCTAssertEqual(backup, first)
    }

    func testABrokenSaveFallsBackToTheBackupAndIsSetAside() throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        var state = GameState(settings: GameSettings(seedText: "broken", houseCount: 3, radius: 14))
        store.save(state)
        let good = state
        _ = state.endWatch()
        store.save(state)
        try Data("{ not a game".utf8).write(to: store.autosaveURL)

        XCTAssertEqual(store.open(), .recovered(good))
        let names = try FileManager.default.contentsOfDirectory(atPath: dir.path)
        XCTAssertTrue(names.contains { $0.hasPrefix("autosave-unreadable-") }, "The broken save is kept, not lost")
        XCTAssertEqual(store.open(), .game(good), "The recovered game is the autosave again")
    }

    func testAnUnreadableSaveWithNoBackupIsKeptAndReported() throws {
        let dir = directory()
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("{ \"formatVersion\": 999 }".utf8).write(to: store.autosaveURL)
        guard case .unreadable(let aside) = store.open() else { return XCTFail("It must be reported") }
        XCTAssertTrue(FileManager.default.fileExists(atPath: aside.path))
        XCTAssertFalse(store.hasSave, "A new game won't overwrite it: it has moved aside")
        XCTAssertEqual(store.open(), .none)
    }
}

@MainActor
final class SaveLifecycleTests: XCTestCase {
    func testOrdersAreSavedWhenTheGameIsPutAside() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        let app = GameApp(store: store, readiness: { .ready }, sound: false)
        app.begin(GameSettings(seedText: "put aside", houseCount: 3, radius: 14))
        let session = try XCTUnwrap(app.session)
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        XCTAssertTrue(session.perform(.build(hold: seat.id, kind: .granary)))
        XCTAssertNotEqual(store.load(), session.state, "Not saved yet: no watch has ended")

        NotificationCenter.default.post(name: NSApplication.willResignActiveNotification, object: nil)
        XCTAssertEqual(store.load(), session.state, "Another app in front: the orders are kept")
    }

    func testAnUnreadableSaveIsExplainedOnTheTitleScreen() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = SaveStore(directory: dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: store.autosaveURL)
        let app = GameApp(store: store, readiness: { .ready }, sound: false)
        XCTAssertTrue(app.hasSave)
        app.continueSaved()
        XCTAssertNil(app.session)
        XCTAssertNotNil(app.saveNotice)
        XCTAssertFalse(app.hasSave)
    }
}

final class GuideTests: XCTestCase {
    func testTheGuideCoversTheGameAndItsKeys() {
        let titles = Guide.sections.map(\.title)
        XCTAssertEqual(titles, ["The watch", "The land", "Holds", "Companies", "Houses", "Winning", "Keys"])
        XCTAssertTrue(Guide.sections.allSatisfy { !$0.lines.isEmpty && $0.lines.allSatisfy { $0.count > 10 } })
        let keys = Guide.sections.last!.lines.joined(separator: " ")
        for key in ["Tab", "H:", "F:", "B:", "Esc", "1:", "2:", "?:", "⌘Z", "⌘S"] {
            XCTAssertTrue(keys.contains(key), "The guide names \(key)")
        }
    }

    @MainActor
    func testQuestionMarkOpensTheGuide() {
        let event = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: 0,
                                     context: nil, characters: "?", charactersIgnoringModifiers: "?", isARepeat: false, keyCode: 44)
        XCTAssertEqual(event.flatMap(KeyBridgeView.key(for:)), .guide)
    }
}

@MainActor
final class WatchCardTests: XCTestCase {
    func testTheCardTellsWhatTheWatchBroughtThenFades() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "card", houseCount: 3, radius: 16)),
                                  store: SaveStore(directory: dir))
        let before = session.playerHouse.stock
        session.endWatch()
        let card = try XCTUnwrap(session.watchCard)
        XCTAssertEqual(card.summary.watch, 2)
        for change in card.summary.changes {
            XCTAssertEqual(session.playerHouse.stock[change.resource] - before[change.resource], change.delta)
        }
        XCTAssertFalse(card.summary.changes.isEmpty, "The first watch brings something in")
        XCTAssertLessThanOrEqual(card.summary.events.count, 3)
        try await Task.sleep(for: .seconds(GameSession.watchCardDuration + 0.3))
        XCTAssertNil(session.watchCard)
    }

    func testTheSummaryNamesWhatTouchedThePlayer() {
        var state = GameState(settings: GameSettings(seedText: "summary", houseCount: 3, radius: 16))
        let before = state
        _ = state.endWatch()
        let battle = Battle(attacker: 1, attackerOwner: state.player, attackerKind: .spear, defender: 2, defenderOwner: 1,
                            defenderKind: .spear, hold: nil, at: Hex(0, 0), damageDealt: 10, damageTaken: 5,
                            attackerFell: false, defenderFell: false)
        let elsewhere = Battle(attacker: 3, attackerOwner: 1, attackerKind: .spear, defender: 4, defenderOwner: 2,
                               defenderKind: .spear, hold: nil, at: Hex(0, 0), damageDealt: 10, damageTaken: 5,
                               attackerFell: false, defenderFell: false)
        let summary = WatchSummary(before: before, after: state, events: [.battle(battle), .battle(battle), .battle(elsewhere)],
                                   player: state.player)
        XCTAssertEqual(summary.events.first, "2 battles", "Only the player's battles count")
    }
}
