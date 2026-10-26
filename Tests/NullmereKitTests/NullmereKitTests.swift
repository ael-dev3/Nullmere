import AppKit
import Metal
import SwiftUI
import LauncherCore
import NullmereCore
import NullmereRealm
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
        XCTAssertEqual(bytes[offset + 1] & TileTexture.holdFlag, TileTexture.holdFlag, "the seat is lit")
        let explored = state.houses[state.player].explored
        for hold in state.holds where hold.owner != state.player {
            let index = try! XCTUnwrap(state.map.index(of: hold.position))
            let o = ((hold.position.r + 14) * side + (hold.position.q + 14)) * 4
            XCTAssertEqual(bytes[o + 1] & TileTexture.holdFlag != 0, explored[index], "only known holds are lit")
        }
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

final class LocalStoreTests: XCTestCase {
    func testWordsAreKeptForEachAgeOfEachRealm() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directory: directory)
        let first = store.forAge(1, of: "The Nullmere"), second = store.forAge(2, of: "The Nullmere")
        first.saveVoices(["chronicle-3": "The lake was still."])
        XCTAssertEqual(first.loadVoices(), ["chronicle-3": "The lake was still."])
        XCTAssertTrue(second.loadVoices().isEmpty, "A new age, a new book")
        XCTAssertFalse(first.directory.path.contains(" "), "A folder name the realm's name can't break")
    }
}

@MainActor
final class GameSessionTests: XCTestCase {
    private func session() -> (GameSession, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let state = GameState(settings: GameSettings(seedText: "session", houseCount: 3, radius: 16))
        return (GameSession(state: state, store: LocalStore(directory: directory)), directory)
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

    func testBeingReadyTurnsTheWatchInTheRealm() {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        XCTAssertEqual(session.realmStatus?.watch, 1, "The realm answered at once")
        session.endWatch()
        XCTAssertEqual(session.state.watch, 2, "The only keeper there was ready, so the watch turned")
        XCTAssertFalse(session.isReady, "A new watch, not yet ready")
        XCTAssertEqual(session.realmStatus?.watch, 2)
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
    func testTheRealmOpensOnlyOnceTheModelIsReady() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var state = ModelReadiness.modelNotReady
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: "gate")))
        let app = GameApp(store: LocalStore(directory: directory), readiness: { state }, sound: false,
                          address: .hosted(seed: "gate"), identity: FileIdentityStore(url: directory.appendingPathComponent("identity")))

        for blocked in [ModelReadiness.modelNotReady, .appleIntelligenceNotEnabled, .deviceNotEligible, .unavailable] {
            state = blocked
            app.checkModel()
            XCTAssertEqual(app.readiness, blocked)
            guard case .gate = app.phase else { return XCTFail("\(blocked) must keep the realm closed") }
            XCTAssertFalse(app.canEnter(with: "Ama"), "No way in behind the gate")
        }

        state = .ready
        app.checkModel()
        guard case .frontDoor = app.phase else { return XCTFail("A ready model opens the realm's front door") }
        guard case .open(let status) = app.door else { return XCTFail("The realm is reached: \(app.door)") }
        XCTAssertEqual(status.watch, 1)
        app.enterWorld(name: "Ama")
        let session = try XCTUnwrap(app.session)
        XCTAssertEqual(session.playerHouse.title, "House Ama")
    }

    func testAKeeperWaitsAtTheDoorForASeat() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directory: directory)
        // Both seats held; Ama's keeper left almost a week ago.
        let away = Date().timeIntervalSince1970 - RealmState.seatHeldFor + 1.5
        var clock = away
        let before = LocalRealm.open(at: store.hostedRealmURL, name: "x", seed: "seats", seats: 2, clock: { clock })
        before.link(identity: "a").arrive(name: "Ama")
        before.link(identity: "b").arrive(name: "Bel")
        before.link(identity: "a").leave()
        clock = away + 60
        before.link(identity: "b").leave()

        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: "seats")))
        let app = GameApp(store: store, readiness: { .ready }, sound: false, address: .hosted(seed: "seats"),
                          identity: FileIdentityStore(url: directory.appendingPathComponent("identity")))
        guard case .open(let status) = app.door else { return XCTFail("The realm is reached") }
        XCTAssertEqual(status.freeSeats, 0)
        XCTAssertTrue(app.canEnter(with: "Cor"), "A full realm still lets a keeper in to wait")
        XCTAssertNil(RealmState.nameProblem("Cor"))
        app.enterWorld(name: "Cor")
        XCTAssertTrue(app.isWaitingForSeat)
        XCTAssertNil(app.session)
        XCTAssertNil(app.arrivalProblem)
        XCTAssertFalse(app.canEnter(with: "Cor"), "Already at the door")

        // The week runs out; the door asks again and steps in.
        try await Task.sleep(for: .seconds(2))
        app.askForSeat()
        XCTAssertFalse(app.isWaitingForSeat)
        let session = try XCTUnwrap(app.session)
        XCTAssertEqual(session.playerHouse.title, "House Cor")
        app.leaveWorld()
        XCTAssertFalse(app.isWaitingForSeat)
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: .hosted(seed: "seats")))
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
final class BlowTests: XCTestCase {
    func testTheBlowsThePlayerSeesAreShownThenForgotten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = GameState(settings: GameSettings(seedText: "blows", houseCount: 3, radius: 16))
        let session = GameSession(state: state, store: LocalStore(directory: directory))
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



final class GuideTests: XCTestCase {
    func testTheGuideCoversTheGameAndItsKeys() {
        let titles = Guide.sections.map(\.title)
        XCTAssertEqual(titles, ["The watch", "The land", "Holds", "Companies", "Houses", "Winning", "Keys"])
        XCTAssertTrue(Guide.sections.allSatisfy { !$0.lines.isEmpty && $0.lines.allSatisfy { $0.count > 10 } })
        let keys = Guide.sections.last!.lines.joined(separator: " ")
        for key in ["Tab", "H:", "F:", "B:", "Esc", "1:", "2:", "?:", "⌘↩", "⇧⌘↩", "⇧⌘W"] {
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
                                  store: LocalStore(directory: dir))
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

@MainActor
final class ReachDisplayTests: XCTestCase {
    func testSelectingACompanyShowsItsReach() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "range", houseCount: 3, radius: 16)),
                                  store: LocalStore(directory: dir))
        XCTAssertTrue(session.reach.isEmpty)
        let lantern = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .lantern })
        session.click(lantern.position)
        XCTAssertEqual(session.reach, Set(session.state.reach(of: lantern).keys))
        XCTAssertFalse(session.reach.isEmpty)
        session.selection = .none
        XCTAssertTrue(session.reach.isEmpty, "Nothing selected, nothing shown")
    }
}


@MainActor
final class PointerTests: XCTestCase {
    func testThePointerSaysWhatAClickWouldDo() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "pointer", houseCount: 3, radius: 16)),
                                  store: LocalStore(directory: dir))
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        let lantern = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .lantern })
        XCTAssertEqual(session.pointerAction(at: seat.position), .select)
        XCTAssertEqual(session.pointerAction(at: Hex(999, 0)), .none)

        session.selection = .unit(lantern.id)
        let open = try XCTUnwrap(session.reach.first { session.state.unit(at: $0) == nil && session.state.hold(at: $0) == nil })
        XCTAssertEqual(session.pointerAction(at: open), .march)
        let far = try XCTUnwrap(session.state.map.hexes.first {
            $0.distance(to: lantern.position) > 8 && session.state.unit(at: $0) == nil && session.state.hold(at: $0) == nil
        })
        XCTAssertEqual(session.pointerAction(at: far), .none)
    }
}

final class TokenArtTests: XCTestCase {
    func testPiecesStayWithinTheirBounds() {
        let c = CGPoint(x: 100, y: 100)
        for r in [7.0, 12.0, 18.0] as [CGFloat] {
            let keep = TokenArt.keep(at: c, radius: r, seat: false).boundingRect
            let seat = TokenArt.keep(at: c, radius: r, seat: true).boundingRect
            XCTAssertLessThan(seat.minY, keep.minY, "A seat stands taller")
            XCTAssertEqual(keep.midX, c.x, accuracy: 0.01, "Keeps stand on their centre")
            XCTAssertLessThanOrEqual(keep.width, 1.6 * r)
            let shield = TokenArt.shield(at: c, radius: r).boundingRect
            XCTAssertEqual(shield.midX, c.x, accuracy: 0.01)
            XCTAssertLessThanOrEqual(shield.height, 2 * r)
            XCTAssertTrue(keep.contains(TokenArt.window(at: c, radius: r).boundingRect), "The window is in the keep")
            let banner = TokenArt.banner(at: c, radius: r)
            XCTAssertLessThan(banner.pennant.boundingRect.maxY, seat.minY + 0.01, "The banner flies above the keep")
        }
    }
}

@MainActor
final class MapAccessibilityTests: XCTestCase {
    func testVoiceOverReadsTheMapAsItsHoldsAndCompanies() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "voiceover", houseCount: 3, radius: 16)),
                                  store: LocalStore(directory: dir))
        let items = MapAccessibility.items(for: session)
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        XCTAssertEqual(items.first?.selection, .hold(seat.id), "The player's seat comes first")
        XCTAssertTrue(items.first!.label.hasPrefix("\(seat.name), seat, yours"))
        let own = session.state.units(of: session.player)
        for unit in own {
            let item = try XCTUnwrap(items.first { $0.selection == .unit(unit.id) }, "Every company of the player's is there")
            XCTAssertTrue(item.label.contains("health \(unit.health)"))
            XCTAssertTrue(item.label.contains("awaiting orders"))
        }
        // Nothing the player can't see is read out.
        for unit in session.state.units where unit.owner != session.player && !session.isVisible(unit.position) {
            XCTAssertNil(items.first { $0.selection == .unit(unit.id) })
        }
        XCTAssertEqual(Set(items.map(\.id)).count, items.count)
    }
}

@MainActor
final class CueMappingTests: XCTestCase {
    func testEachMomentHasItsOwnSound() {
        let player = 0
        let envoy = Envoy(id: 1, from: 2, proposal: .peace, arrived: 3)
        XCTAssertEqual(GameSession.cues(for: [], player: player), [.watch])
        XCTAssertEqual(GameSession.cues(for: [.envoyArrived(envoy)], player: player), [.watch, .envoy])
        XCTAssertEqual(GameSession.cues(for: [.holdCaptured(hold: 1, from: 2, by: player)], player: player), [.watch, .triumph])
        XCTAssertEqual(GameSession.cues(for: [.holdCaptured(hold: 1, from: player, by: 2)], player: player), [.watch, .dread])
        XCTAssertEqual(GameSession.cues(for: [.houseFell(3), .houseFell(4)], player: player), [.watch, .toll], "Each sound once")
        XCTAssertEqual(GameSession.cues(for: [.stanceChanged(first: 0, second: 2, stance: .war, by: 2)], player: player), [.watch, .dread])
        XCTAssertEqual(GameSession.cues(for: [.stanceChanged(first: 0, second: 2, stance: .peace, by: 2)], player: player), [.watch, .accord])
        XCTAssertEqual(GameSession.cues(for: [.stanceChanged(first: 1, second: 2, stance: .war, by: 2)], player: player), [.watch],
                       "Others' wars are silent")
    }
}

@MainActor
final class TextSizeTests: XCTestCase {
    override func tearDown() {
        TextSize.shared.isLarger = false
        super.tearDown()
    }

    private func size(of view: some View) throws -> CGSize {
        let renderer = ImageRenderer(content: view)
        renderer.scale = 1
        let image = try XCTUnwrap(renderer.cgImage)
        return CGSize(width: image.width, height: image.height)
    }

    func testTheChoiceIsRemembered() {
        TextSize.shared.isLarger = true
        XCTAssertTrue(UserDefaults.standard.bool(forKey: "text.larger"))
        XCTAssertEqual(TextSize.shared.scale, TextSize.largerScale)
        TextSize.shared.isLarger = false
        XCTAssertFalse(UserDefaults.standard.bool(forKey: "text.larger"))
        XCTAssertEqual(TextSize.shared.scale, 1)
    }

    func testLargerTextEnlargesTheType() throws {
        TextSize.shared.isLarger = false
        let standard = try size(of: Caps("The Moonspire rises", size: 10).fixedSize())
        TextSize.shared.isLarger = true
        let larger = try size(of: Caps("The Moonspire rises", size: 10).fixedSize())
        XCTAssertGreaterThan(larger.width, standard.width * 1.15)
        XCTAssertGreaterThan(larger.height, standard.height)
    }

    /// The panels keep their width and grow downward: nothing is cut off.
    func testThePanelsGrowWithTheType() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "larger text")), store: LocalStore(directory: dir))
        session.selectNextReadyUnit()
        XCTAssertNotNil(session.selectedUnit)

        TextSize.shared.isLarger = false
        let standard = try size(of: SelectionPanel(session: session).fixedSize(horizontal: false, vertical: true))
        TextSize.shared.isLarger = true
        let larger = try size(of: SelectionPanel(session: session).fixedSize(horizontal: false, vertical: true))
        XCTAssertEqual(larger.width, standard.width, "The panel keeps its width")
        XCTAssertGreaterThan(larger.height, standard.height, "and grows to hold the larger type")
    }

    /// The top bar fits the narrowest window, and the larger type a wide one,
    /// without squeezing the House, the clock or Ready.
    func testTheTopBarFitsTheWindow() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "top bar")), store: LocalStore(directory: dir))
        TextSize.shared.isLarger = false
        let standard = try size(of: TopBar(session: session).fixedSize())
        TextSize.shared.isLarger = true
        let larger = try size(of: TopBar(session: session).fixedSize())
        print("LAYOUT top bar \(Int(standard.width)) wide, \(Int(larger.width)) with the larger type")
        XCTAssertLessThanOrEqual(standard.width, 960)
        let narrow = try size(of: TopBar(session: session).frame(width: 960).fixedSize(horizontal: false, vertical: true))
        XCTAssertEqual(narrow.height, standard.height, "Nothing wraps in the narrowest window")
        XCTAssertLessThanOrEqual(larger.width, 1280)
        let watch = try size(of: WatchClock(session: session))
        XCTAssertGreaterThan(watch.width, 40, "The watch is never squeezed")
        XCTAssertLessThan(watch.height, 30, "and stays on one line")
    }

    /// A hold's long panel scrolls within its height rather than run off the window.
    func testTheHoldPanelScrollsWithinItsHeight() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "larger text")), store: LocalStore(directory: dir))
        session.focusOnSeat()
        XCTAssertNotNil(session.selectedHold)
        TextSize.shared.isLarger = true
        let larger = try size(of: SelectionPanel(session: session).fixedSize(horizontal: false, vertical: true))
        XCTAssertLessThanOrEqual(larger.height, 640)
    }
}
