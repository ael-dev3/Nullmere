import AppKit
import Metal
import SwiftUI
import LauncherCore
import LauncherKit
@testable import NullmereCore
import NullmereRealm
import XCTest
@testable import NullmereKit
import NullmereModels
import NullmereWorld

final class WorldShaderTests: XCTestCase {
    /// Every House that may sit around the lake has its colour, the same
    /// in the interface and on the map: the map's are the interface's,
    /// made linear for the shaders.
    func testEachHouseHasOneColourEverywhere() throws {
        XCTAssertEqual(Palette.houses.count, Names.houses.count)
        XCTAssertEqual(Names.houses.count, WorldGenerator.mostHouses)
        XCTAssertEqual(WorldView.houseColours.count, Palette.houseRGB.count)
        for (shader, interface) in zip(WorldView.houseColours, Palette.houseRGB) {
            XCTAssertEqual(Double(shader.x), pow(interface.red, 2.2), accuracy: 1e-5)
            XCTAssertEqual(Double(shader.y), pow(interface.green, 2.2), accuracy: 1e-5)
            XCTAssertEqual(Double(shader.z), pow(interface.blue, 2.2), accuracy: 1e-5)
        }
        // Each a colour of its own: the elder Houses' plainly apart, and
        // every younger House's still apart from any beside it.
        let components = Palette.houses.compactMap { NSColor($0).usingColorSpace(.sRGB) }
        XCTAssertEqual(components.count, Names.houses.count)
        for (index, a) in components.enumerated() {
            for (other, b) in components.enumerated() where other > index {
                let distance = abs(a.redComponent - b.redComponent) + abs(a.greenComponent - b.greenComponent) + abs(a.blueComponent - b.blueComponent)
                let elder = other < Names.elder.count
                XCTAssertGreaterThan(distance, elder ? 0.3 : 0.18, "Houses \(index) and \(other) too alike in colour")
            }
        }
    }

    /// Compiles the world's shaders and builds their pipelines on this Mac's GPU.
    func testShadersCompileAndBuildTheirPipelines() throws {
        guard let device = MTLCreateSystemDefaultDevice() else {
            throw XCTSkip("No Metal device available")
        }
        let library = try device.makeLibrary(source: WorldShaders.source, options: nil)
        for name in WorldShaders.functions {
            XCTAssertNotNil(library.makeFunction(name: name), name)
        }
        XCTAssertNoThrow(try WorldRenderer(device: device, library: library, pixelFormat: .bgra8Unorm))
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

    func testEachRealmKeepsItsOwnBook() throws {
        let store = LocalStore(directory: FileManager.default.temporaryDirectory)
        let addresses: [GameApp.RealmAddress] = [
            .hosted(seed: "x"),
            .network(URL(string: "https://maincloud.spacetimedb.com/nullmere")!),
            .network(URL(string: "https://maincloud.spacetimedb.com/nullmere-two")!),
            .network(URL(string: "http://127.0.0.1:3000/nullmere")!),
        ]
        let folders = Set(addresses.map { store.forAge(1, of: GameApp.storeKey(for: $0)).directory })
        XCTAssertEqual(folders.count, addresses.count, "A realm here and realms across the network never share what this Mac keeps")
    }

    /// Unless told otherwise, the game keeps its words in Application
    /// Support, in a folder of its own.
    func testTheStoreLivesInApplicationSupport() throws {
        let support = try XCTUnwrap(FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first)
        XCTAssertEqual(LocalStore().directory, support.appendingPathComponent("Nullmere Online", isDirectory: true))
    }

    /// Words that can't be kept are let go, said in the log, and nothing
    /// else breaks.
    func testWordsThatCantBeKeptAreLetGo() throws {
        let blocker = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: blocker) }
        // A file where the store's folder would be.
        try Data("not a folder".utf8).write(to: blocker)
        let store = LocalStore(directory: blocker.appendingPathComponent("store", isDirectory: true))
        store.saveVoices(["chronicle-1": "The lake was still."])
        XCTAssertTrue(store.loadVoices().isEmpty)
    }
}

@MainActor
final class GameSessionTests: XCTestCase {
    private func session() -> (GameSession, URL) {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        let state = GameState(settings: GameSettings(seedText: "session", houseCount: 3, radius: 16, keepers: 1))
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

    func testSoundsAreHeardFromWhereTheyHappen() throws {
        let (session, directory) = session()
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = session.state
        let seat = try XCTUnwrap(state.seat(of: session.player))
        let unit = try XCTUnwrap(state.units(of: session.player).first)
        // Each sound placed by the first event that made it; the bell in the middle.
        let battle = Battle(attacker: unit.id, attackerOwner: 1, attackerKind: .spear, defender: unit.id, defenderOwner: session.player,
                            defenderKind: unit.kind, hold: nil, at: unit.position, damageDealt: 10, damageTaken: 4,
                            attackerFell: false, defenderFell: false)
        let placed = GameSession.placedCues(for: [.battle(battle), .buildingCompleted(hold: seat.id, kind: .granary, level: 1)],
                                            in: state, player: session.player)
        XCTAssertEqual(placed.map(\.cue), [.watch, .clash, .complete])
        XCTAssertEqual(placed.map(\.at), [nil, unit.position, seat.position])
        XCTAssertNil(GameSession.place(of: .houseFell(2), in: state))
        XCTAssertEqual(GameSession.place(of: .moved(unit: unit.id, path: [seat.position, unit.position]), in: state), unit.position)
        XCTAssertEqual(GameSession.target(of: .attack(unit: unit.id, target: seat.position)), seat.position)
        XCTAssertNil(GameSession.target(of: .fortify(unit: unit.id)))

        // Heard from the view as it stands: the middle of the view in the middle.
        session.glide(to: seat.position)
        XCTAssertEqual(session.soundPlace(of: nil), .middle)
        let here = session.soundPlace(of: session.camera.centreHex)
        XCTAssertEqual(here.pan, 0, accuracy: 0.2)
        let far = Hex(session.camera.centreHex.q + 40, session.camera.centreHex.r)
        XCTAssertLessThan(session.soundPlace(of: far).gain, 1)

        var heard: [(Ambience.Cue, SoundPlace)] = []
        session.onPlacedCue = { heard.append(($0, $1)) }
        session.click(unit.position)
        XCTAssertEqual(heard.first?.0, .select)
        XCTAssertEqual(heard.first?.1, .middle, "A choice is heard in the middle")
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

    func testEachNewChargeIsCounselled() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        var state = GameState(settings: GameSettings(seedText: "counselled", houseCount: 3, radius: 16, keepers: 1))
        // The first charge kept already: it is done as the watch turns.
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == state.player && $0.isSeat })
        state.holds[seat].levels[.granary] = 1
        let session = GameSession(state: state, store: LocalStore(directory: directory))
        var said: [String] = []
        session.onCounsel = { said.append($0) }
        XCTAssertEqual(said, [], "Nothing said before the keeper is in the world")
        session.dismissSeatBriefing()
        XCTAssertEqual(said, [ChargeGuide.counsel(.raiseGranary)])
        XCTAssertEqual(said.first, "A new charge, keeper. Raise a Granary at your seat. Choose your seat and build a Granary: it keeps more of every store.")
        session.endWatch()
        XCTAssertEqual(said.count, 2, "The next charge, counselled as it comes")
        let next = try XCTUnwrap(session.state.charge(of: session.player))
        XCTAssertNotEqual(next, .raiseGranary)
        XCTAssertEqual(said.last, ChargeGuide.counsel(next))
        session.endWatch()
        XCTAssertEqual(said.count, 2, "The same charge isn't said again")
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
        XCTAssertEqual(Narration.roman(9), "IX", "The wilds and favour run to X")
        XCTAssertEqual(Narration.roman(10), "X")
        XCTAssertEqual(Narration.roman(14), "X")
        XCTAssertEqual(Narration.roman(-1), "")
    }

    /// A seat moved and empty granaries are told to their own House alone.
    func testTheKeepersOwnTroublesAreToldToThemAlone() throws {
        let state = GameState(settings: GameSettings(seedText: "troubles", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player, other = (state.player + 1) % state.houses.count
        let hold = try XCTUnwrap(state.holds.first { $0.owner == me })
        let moved = try XCTUnwrap(Narration.line(for: .seatMoved(house: me, to: hold.id), in: state, viewer: me))
        XCTAssertEqual(moved.text, "Your seat moves to \(hold.name).")
        XCTAssertEqual(moved.tone, .bad)
        XCTAssertNil(Narration.line(for: .seatMoved(house: other, to: hold.id), in: state, viewer: me))
        let hungry = try XCTUnwrap(Narration.line(for: .starving(house: me), in: state, viewer: me))
        XCTAssertEqual(hungry.text, "Your grain has run out; your companies go hungry.")
        XCTAssertEqual(hungry.tone, .bad)
        XCTAssertNil(Narration.line(for: .starving(house: other), in: state, viewer: me))
    }

    /// The keeper's own envoys are told as theirs, going out; another's as
    /// coming in. An age is won by ascendancy or by dominion, each named.
    func testEnvoysAndEndingsAreToldAsTheyAre() throws {
        let state = GameState(settings: GameSettings(seedText: "envoys", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player, other = (state.player + 1) % state.houses.count
        let them = state.houses[other].title
        func said(_ event: GameEvent) throws -> Narration.Line { try XCTUnwrap(Narration.line(for: event, in: state, viewer: me)) }

        let pact = try said(.envoyArrived(Envoy(id: 1, from: me, to: other, proposal: .pact, arrived: 1)))
        XCTAssertEqual(pact.text, "Your envoy takes \(them) an offer of a pact.")
        XCTAssertEqual(pact.tone, .neutral)
        let demand = try said(.envoyArrived(Envoy(id: 2, from: me, to: other, proposal: .tribute, arrived: 1)))
        XCTAssertEqual(demand.text, "Your envoy takes \(them) a demand for tribute.")
        XCTAssertEqual(demand.tone, .neutral, "Their own demand is no threat to them")
        let theirs = try said(.envoyArrived(Envoy(id: 3, from: other, to: me, proposal: .tribute, arrived: 1)))
        XCTAssertEqual(theirs.text, "An envoy from \(them) demands tribute, or war.", "A steward's demand: refused, it marches")
        var kept = state
        kept.houses[other].isPlayer = true
        let keepers = try XCTUnwrap(Narration.line(for: .envoyArrived(Envoy(id: 4, from: other, to: me, proposal: .tribute, arrived: 1)), in: kept, viewer: me))
        XCTAssertEqual(keepers.text, "An envoy from \(them) demands tribute.", "A keeper refused may only choose war")
        let offered = try XCTUnwrap(Narration.line(for: .envoyArrived(Envoy(id: 5, from: other, to: me, proposal: .pact, arrived: 1)), in: state, viewer: me))
        XCTAssertEqual(offered.text, "An envoy from \(them) offers a pact.")
        let sworn = try XCTUnwrap(Narration.line(for: .proposalAnswered(proposal: .fealty, from: other, to: me, accepted: true), in: state, viewer: me))
        XCTAssertEqual(sworn.text, "\(them) swears you fealty.")
        let allied = try XCTUnwrap(Narration.line(for: .proposalAnswered(proposal: .pact, from: other, to: me, accepted: true), in: state, viewer: me))
        XCTAssertEqual(allied.text, "You and \(them) swear a pact.")

        // A company lost is told with where it fell: at a hold, or on its
        // ground by the nearest hold.
        let seat = try XCTUnwrap(state.seat(of: me))
        XCTAssertEqual(try said(.unitLost(unit: 9, kind: .spear, owner: me, at: seat.position)).text, "Your Spears are lost at \(seat.name).")
        let beside = try XCTUnwrap(state.map.neighbors(of: seat.position).first { state.hold(at: $0) == nil })
        let ground = try XCTUnwrap(state.map[beside]).terrain.title.lowercased()
        XCTAssertEqual(try said(.unitLost(unit: 9, kind: .spear, owner: me, at: beside)).text, "Your Spears are lost on the \(ground) by \(seat.name).")
        XCTAssertNil(Narration.line(for: .unitLost(unit: 9, kind: .spear, owner: other, at: beside), in: state, viewer: me))

        XCTAssertEqual(try said(.gameEnded(Outcome(winner: other, kind: .ascendancy, watch: 9))).text, "\(them) is ascendant.")
        XCTAssertEqual(try said(.gameEnded(Outcome(winner: other, kind: .dominion, watch: 9))).text, "\(them) holds dominion over the lake.")
        XCTAssertEqual(try said(.gameEnded(Outcome(winner: me, kind: .dominion, watch: 9))).text, "The Nullmere is yours.")
        // Another age's lake is named as its own.
        var sickle = state
        sickle.settings.lake = .crescent
        XCTAssertEqual(try XCTUnwrap(Narration.line(for: .gameEnded(Outcome(winner: me, kind: .dominion, watch: 9)), in: sickle, viewer: me)).text, "The Sickle is yours.")
    }
}

final class WatchSummaryTests: XCTestCase {
    /// A battle the keeper fought heads the card; a hold lost and gone from
    /// the world since is still named, as a hold.
    func testTheCardNamesWhatTheWatchBrought() throws {
        let state = GameState(settings: GameSettings(seedText: "card", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player
        let mine = try XCTUnwrap(state.units(of: me).first)
        let fought = Battle(attacker: mine.id, attackerOwner: me, attackerKind: mine.kind, defender: nil, defenderOwner: 1,
                            defenderKind: nil, hold: nil, at: mine.position, damageDealt: 5, damageTaken: 2,
                            attackerFell: false, defenderFell: false)
        let summary = WatchSummary(before: state, after: state, events: [.battle(fought), .holdCaptured(hold: 9999, from: me, by: 1)],
                                   player: me)
        XCTAssertEqual(summary.events.first, "A battle")
        XCTAssertTrue(summary.events.contains("a hold is lost"), "\(summary.events)")
    }
}

final class CounselTests: XCTestCase {
    func testCounselGuidesTheOpeningAndThenFallsSilent() {
        var state = GameState(settings: GameSettings(seedText: "counsel", houseCount: 3, radius: 16, keepers: 1))
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

    func testTheAppGoesToTheRealmItWasBuiltFor() {
        let own = URL(string: "https://maincloud.spacetimedb.com/nullmere-online")!
        XCTAssertEqual(GameApp.realmURL(in: ["NullmereRealm": own.absoluteString]), own)
        for unset in [nil, [:], ["NullmereRealm": "__REALM__"], ["NullmereRealm": "ftp://x/y"], ["NullmereRealm": "https://host"]] as [[String: Any]?] {
            XCTAssertEqual(GameApp.realmURL(in: unset), GameApp.maincloudURL)
        }
    }

    func testAKeeperWaitsAtTheDoorForASeat() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let store = LocalStore(directory: directory)
        // Both seats held; Ama's keeper took a seat almost a day ago, never
        // played, and left.
        let away = Date().timeIntervalSince1970 - RealmState.unplayedSeatHeldFor + 1.5
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

        // The day runs out; the door asks again and steps in.
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
        let state = GameState(settings: GameSettings(seedText: "hover", houseCount: 3, radius: 16, keepers: 1))
        let territory = state.territory()
        let seat = try XCTUnwrap(state.seat(of: state.player))
        let line = try XCTUnwrap(HoverInfo.line(for: seat.position, in: state, explored: true, territory: territory))
        XCTAssertTrue(line.contains(seat.name))
        XCTAssertTrue(line.contains("land of \(state.houses[state.player].title)"))
        XCTAssertEqual(HoverInfo.line(for: seat.position, in: state, explored: false, territory: territory), "Unknown country · send Lanterns")
        XCTAssertNil(HoverInfo.line(for: Hex(999, 0), in: state, explored: true, territory: territory))

        let still = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain == .still })
        XCTAssertTrue(HoverInfo.line(for: still, in: state, explored: true, territory: territory)!.contains("impassable"))
        let wood = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain == .blackwood })
        let woodLine = HoverInfo.line(for: wood, in: state, explored: true, territory: territory)!
        XCTAssertTrue(woodLine.contains("2 moves") && woodLine.contains("+25% defence"), woodLine)

        // The Spine walls the world: dry land no one crosses, not the Still.
        let spine = try XCTUnwrap(state.map.hexes.first { state.map[$0]?.terrain == .spine })
        let spineLine = try XCTUnwrap(HoverInfo.line(for: spine, in: state, explored: true, territory: territory))
        XCTAssertTrue(spineLine.hasPrefix("The Spine") && spineLine.hasSuffix("impassable"), spineLine)
        XCTAssertFalse(spineLine.contains("yields nothing"), spineLine)
    }
}

/// The line under the map says what lies under the pointer, and only then.
@MainActor
final class HoverLineTests: XCTestCase {
    func testTheLineShowsWhileThePointerRestsOnTheMap() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "hover line", keepers: 1)), store: LocalStore(directory: directory))
        let seat = try XCTUnwrap(session.state.seat(of: session.player))
        func drawn() throws -> CGImage {
            let renderer = ImageRenderer(content: HoverLine(session: session).frame(width: 600, height: 40).background(Color.black))
            renderer.scale = 1
            return try XCTUnwrap(renderer.cgImage)
        }
        func lit(_ image: CGImage) -> Int {
            let context = CGContext(data: nil, width: image.width, height: image.height, bitsPerComponent: 8, bytesPerRow: image.width * 4,
                                    space: CGColorSpaceCreateDeviceRGB(), bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
            context.draw(image, in: CGRect(x: 0, y: 0, width: image.width, height: image.height))
            let bytes = context.data!.assumingMemoryBound(to: UInt8.self)
            return (0..<(image.width * image.height)).filter { Int(bytes[$0 * 4]) + Int(bytes[$0 * 4 + 1]) + Int(bytes[$0 * 4 + 2]) > 300 }.count
        }
        session.hovered = nil
        XCTAssertEqual(lit(try drawn()), 0, "Nothing under the pointer, nothing said")
        session.hovered = seat.position
        XCTAssertTrue(session.isExplored(seat.position))
        XCTAssertGreaterThan(lit(try drawn()), 50, "Its own seat, named under the map")
    }
}


@MainActor
final class BlowTests: XCTestCase {
    func testTheBlowsThePlayerSeesAreShownThenForgotten() async throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: directory) }
        let state = GameState(settings: GameSettings(seedText: "blows", houseCount: 3, radius: 16, keepers: 1))
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
        try await Task.sleep(for: .seconds(GameSession.Blow.lingers + 0.3))
        XCTAssertTrue(session.blows.isEmpty)
    }
}



final class GuideTests: XCTestCase {
    func testTheGuideCoversTheGameAndItsKeys() {
        let titles = Guide.sections.map(\.title)
        XCTAssertEqual(titles, ["The watch", "The land", "Holds", "Companies", "Tiers and studies", "Commanders", "The wilds and the sites",
                                "Houses", "Alliances and rallies", "Happenings and charges", "Omens", "Winning", "Keys"])
        XCTAssertTrue(Guide.sections.allSatisfy { !$0.lines.isEmpty && $0.lines.allSatisfy { $0.count > 10 } })
        let keys = Guide.sections.last!.lines.joined(separator: " ")
        for key in ["Tab", "H:", "C:", "F:", "B:", "Esc", "1:", "2:", "3:", "4:", "5:", "6:", "7:", "?:", "⌘↩", "⇧⌘↩", "⇧⌘W", "⇧⌘M", "⇧⌘U", "⇧⌘+",
                    "] and [", "Space or Return", "Page Up", "With ⌥"] {
            XCTAssertTrue(keys.contains(key), "The guide names \(key)")
        }
        // The Moonspire's last stage, and the holds it takes to store for it.
        XCTAssertEqual(Guide.holdsForTheLastSpire, 4)
        let winning = Guide.sections.first { $0.title == "Winning" }?.lines.joined(separator: " ") ?? ""
        XCTAssertTrue(winning.contains("960 stone, more than a House of fewer than 4 holds can keep"), winning)
        XCTAssertTrue(winning.contains("nor win, nor raise its Moonspire while it serves"), winning)
        // The rules said as they stand.
        let all = Guide.sections.flatMap(\.lines).joined(separator: " ")
        XCTAssertTrue(all.contains("From the tenth watch, a happening comes round every thirty, for ten watches"), all)
        XCTAssertEqual([Happening.first, Happening.every, Happening.lasts], [10, 30, 10])
        XCTAssertEqual(Happening.marks, [10, 25, 50])
        XCTAssertEqual(GameState.rosterLimit, 5, "up to five commanders")
        XCTAssertEqual(GameState.captainsAt, [3, 5])
        XCTAssertEqual(GameState.woundWatches, 4)
        XCTAssertTrue(all.contains("a Mending Draught mends every hurt company of yours by \(GameState.draughtMending)"), all)
        XCTAssertTrue(all.contains("a twentieth stronger and firmer than others of its kind. Take up another in the Realm (6): the first time freely, then for 30 moonsalt."), all)
        XCTAssertEqual(Heritage.signatureEdge, 5)
        XCTAssertTrue(all.contains("every 300 given, in barter worth, brings the giver a Salt Hourglass"), all)
        XCTAssertTrue(all.contains("Its companies alone work them, a quarter faster than anywhere else"), all)
        XCTAssertTrue(all.contains("wins you favour with the lake, the more for every watch kept unbroken"), all)
        XCTAssertTrue(all.contains("From the fifty-fifth watch, and every ninety after, comes the Sundering: for twelve watches"), all)
        XCTAssertEqual([Sundering.first, Sundering.every, Sundering.lasts], [55, 90, 12])
        XCTAssertTrue(all.contains("About each full moon from the fifty-fifth watch, for ten watches, the tide lays bare the Moonford"), all)
        XCTAssertEqual([GameState.lunarMonth, GameState.fordLasts, GameState.tideToll], [30, 10, 20])
        XCTAssertTrue(all.contains("Sing it, and the realm keeps it in its songbook, Songs in the Chronicle, for every House to read: two to six short lines"), all)
        XCTAssertEqual([GameState.balladLines.lowerBound, GameState.balladLines.upperBound, GameState.renownPerBallad, GameState.balladsThatCount],
                       [2, 6, 2, 5])
        XCTAssertTrue(all.contains("Spears 1,200 at I to 2,400 at V, Bows 1,000 to 2,000, Riders 800 to 1,600"), all)
        XCTAssertEqual([UnitKind.spear, .bow, .rider].map { [$0.troops(tier: 1), $0.troops(tier: 5)] }, [[1_200, 2_400], [1_000, 2_000], [800, 1_600]])
        XCTAssertEqual([Favour.chestEvery, Favour.highest], [10, 10])
        XCTAssertEqual(Yard.gathering, 25)
        XCTAssertEqual(AllianceStudy.grades, 3)
        XCTAssertTrue(all.contains("it rises over four watches. Whole, the land three tiles about it is the alliance's"), all)
        XCTAssertEqual([AllianceHall.raising, AllianceHall.reach, AllianceHall.rallyCompanies, AllianceHall.standards, AllianceHall.garrison],
                       [4, 3, 2, 2, 25])
        XCTAssertTrue(all.contains("as fine as your highest Forge allows: plain at level I, fine at II, masterwork at IV, fabled at V"), all)
        XCTAssertEqual(GearQuality.allCases.map(\.forgeLevel), [1, 2, 4, 5])
        XCTAssertEqual(Heritage.allCases.map(\.name), ["The Saltborn", "The Fenfolk", "The Blackwood Kin", "The Spinewardens", "The Mound Clans", "The Strandfolk"])
        XCTAssertEqual(Rally.gatherings, 1...4)
        XCTAssertEqual(Study.opening(tier: 2), .drill)
        XCTAssertEqual(Study.opening(tier: 5), .moonsteel)
        XCTAssertTrue(all.contains("gifts worth \(GameState.giftsTakenPerWatch) a watch at most"), all)
        XCTAssertTrue(all.contains("swears you no pact"), all)
        // Barter as the rules price it: three to one, but moonsalt costs
        // nine and fetches one.
        XCTAssertEqual(Resource.moonsalt.barterCost(of: 1, paidIn: .grain), 9)
        XCTAssertEqual(Resource.grain.barterCost(of: 1, paidIn: .moonsalt), 1)
        XCTAssertTrue(all.contains("three to one. Moonsalt counts as three of any other store, so one costs nine of them, and fetches one."), all)
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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "card", houseCount: 3, radius: 16, keepers: 1)),
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
        var state = GameState(settings: GameSettings(seedText: "summary", houseCount: 3, radius: 16, keepers: 1))
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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "range", houseCount: 3, radius: 16, keepers: 1)),
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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "pointer", houseCount: 3, radius: 16, keepers: 1)),
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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "voiceover", houseCount: 3, radius: 16, keepers: 1)),
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

    /// Whatever befalls the keeper's House, or comes of its doings at the
    /// watch's turning, is heard: none of it passes in silence.
    func testNothingThatConcernsTheKeeperIsSilent() throws {
        let state = GameState(settings: GameSettings(seedText: "nothing silent", keepers: 1))
        let player = state.player
        let seat = try XCTUnwrap(state.seat(of: player))
        let unit = try XCTUnwrap(state.units(of: player).first)
        let foe = (player + 1) % state.houses.count
        let trade = Trade(give: .grain, 10, for: .stone, 5)
        let struck = Battle(attacker: 90, attackerOwner: foe, attackerKind: .spear, defender: unit.id, defenderOwner: player,
                            defenderKind: unit.kind, hold: nil, at: unit.position, damageDealt: 10, damageTaken: 4,
                            attackerFell: false, defenderFell: false)
        let concerning: [(GameEvent, Ambience.Cue)] = [
            (.moved(unit: unit.id, path: [unit.position]), .order),
            (.battle(struck), .clash),
            (.unitLost(unit: unit.id, kind: unit.kind, owner: player, at: unit.position), .dread),
            (.holdStruck(hold: seat.id, ward: 3), .batter),
            (.holdCaptured(hold: seat.id, from: player, by: foe), .dread),
            (.seatMoved(house: player, to: 9), .dread),
            (.holdFounded(hold: seat.id), .rise),
            (.buildingStarted(hold: seat.id, kind: .granary, level: 1), .rise),
            (.buildingCompleted(hold: seat.id, kind: .granary, level: 1), .complete),
            (.trainingStarted(hold: seat.id, kind: .spear), .rise),
            (.bartered(house: player, gave: Stock(grain: 5), took: Stock(stone: 2)), .coin),
            (.gifted(from: foe, to: player, gift: Stock(grain: 5)), .accord),
            (.tradeAnswered(trade: trade, from: player, to: foe, accepted: false), .refusal),
            (.tradeAnswered(trade: trade, from: player, to: foe, accepted: true), .accord),
            (.unitTrained(unit: unit.id, hold: seat.id), .muster),
            (.promoted(unit: unit.id, owner: player, rank: 1), .rise),
            (.ruinSearched(at: unit.position, by: player, reward: Stock(grain: 5)), .rise),
            (.stanceChanged(first: player, second: foe, stance: .war, by: foe), .dread),
            (.envoyArrived(Envoy(id: 1, from: foe, proposal: .peace, arrived: 3)), .envoy),
            (.proposalAnswered(proposal: .peace, from: player, to: foe, accepted: false), .refusal),
            (.proposalAnswered(proposal: .peace, from: player, to: foe, accepted: true), .accord),
            (.starving(house: player), .dread),
            (.houseFell(foe), .toll),
        ]
        for (event, cue) in concerning {
            XCTAssertEqual(GameSession.cues(for: [event], in: state, player: player), [.watch, cue], "\(event)")
        }
        // Others' doings among themselves pass quietly.
        let others = (foe + 1) % state.houses.count
        XCTAssertEqual(GameSession.cues(for: [.proposalAnswered(proposal: .peace, from: foe, to: others, accepted: false),
                                              .bartered(house: foe, gave: Stock(grain: 5), took: Stock(stone: 2))],
                                        in: state, player: player), [.watch])
    }

    /// The realm's depth is heard as its plainer doings are: studies,
    /// commanders, the wilds, gathering, alliances, rallies, happenings,
    /// deeds and charges, each as it concerns the keeper; and every new
    /// order has its sound.
    func testTheRealmsDepthIsHeard() throws {
        var state = GameState(settings: GameSettings(seedText: "depth heard", houseCount: 12, radius: 36, keepers: 1))
        let player = state.player
        _ = try state.perform(.foundAlliance(name: "The Grey Hand"), as: player)
        let alliance = try XCTUnwrap(state.alliance(of: player)).id
        let seat = try XCTUnwrap(state.seat(of: player))
        let unit = try XCTUnwrap(state.units(of: player).first)
        let commander = try XCTUnwrap(state.commanders(of: player).first).id
        let foe = (player + 1) % state.houses.count
        func hunt(by owner: Int, _ kind: UnitKind) -> GameEvent {
            .hunted(Hunt(attacker: unit.id, attackerOwner: owner, attackerKind: kind, wild: 900, wildKind: .saltwights, level: 2,
                         at: unit.position, damageDealt: 12, damageTaken: 3, attackerFell: false, wildFell: false, spoils: Stock()))
        }
        state.standards = [Standard(id: 82, alliance: alliance, raisedBy: player, position: unit.position, raised: 0)]
        func field(held: Int?, _ first: Int, _ second: Int) -> Field {
            var field = Field(id: 98, at: unit.position, joined: 1, first: first, second: second)
            field.held = held
            return field
        }
        let concerning: [(GameEvent, Ambience.Cue)] = [
            (.fieldJoined(field: 98, at: unit.position, first: player, second: foe), .horn),
            (.fieldJoined(field: 98, at: unit.position, first: foe, second: player), .horn),
            (.fieldEnded(field(held: 0, player, foe)), .triumph),
            (.fieldEnded(field(held: 1, player, foe)), .dread),
            (.fieldEnded(field(held: nil, player, foe)), .stand),
            (.standardRaised(standard: 80, alliance: alliance, house: player, at: unit.position), .banner),
            (.standardStruck(standard: 82, ward: 30, by: foe, at: unit.position), .batter),
            (.standardTorn(standard: 80, alliance: 77, by: player, at: unit.position), .triumph),
            (.standardTorn(standard: 81, alliance: alliance, by: foe, at: unit.position), .dread),
            (.itemsGiven(house: player, kind: .hourglass, count: 2), .coin),
            (.heritageTaken(house: player, heritage: .fenfolk), .banner),
            (.allianceStudied(alliance: alliance, study: .fieldcraft, grade: 1), .lore),
            (.allianceGift(house: player, alliance: alliance, stock: Stock(grain: 50), study: .fieldcraft, grade: 1), .coin),
            (.allianceStudyChosen(alliance: alliance, study: .fieldcraft), .banner),
            (.hallRaised(hall: 90, alliance: alliance, house: foe, at: unit.position), .rise),
            (.hallRisen(hall: 90, alliance: alliance, at: unit.position), .complete),
            (.hallStruck(hall: 90, alliance: alliance, ward: 30, by: foe, at: unit.position), .batter),
            (.hallTorn(hall: 91, alliance: 77, by: player, at: unit.position), .triumph),
            (.hallTorn(hall: 90, alliance: alliance, by: foe, at: unit.position), .dread),
            (.storehouseRaised(storehouse: 93, alliance: alliance, house: foe, at: unit.position), .rise),
            (.storehouseRisen(storehouse: 93, alliance: alliance, at: unit.position), .complete),
            (.storehouseStruck(storehouse: 93, alliance: alliance, ward: 30, by: foe, at: unit.position), .batter),
            (.storehouseTorn(storehouse: 94, alliance: 77, by: player, at: unit.position, carried: Stock(grain: 40)), .triumph),
            (.storehouseTorn(storehouse: 93, alliance: alliance, by: foe, at: unit.position, carried: .zero), .dread),
            (.laidUp(house: player, stock: Stock(grain: 100)), .coin),
            (.tookBack(house: player, stock: Stock(grain: 100)), .coin),
            (.yardRaised(site: 95, alliance: alliance, house: foe, store: .timber, at: unit.position), .rise),
            (.favourRose(house: player, level: 2), .honour),
            (.sunderingBegun(ends: 67), .herald),
            (.sunderingEnded(winner: .eastern, eastern: 5, western: 2, hailed: nil), .herald),
            (.gearForged(house: player, gear: Gear(id: 72, kind: .wardensBlade, quality: .plain, owner: player)), .anvil),
            (.itemUsed(house: player, kind: .hourglass, hold: seat.id), .sift),
            (.itemUsed(house: player, kind: .mendingDraught, hold: nil), .tend),
            (.studyBegun(house: player, study: .furrowLore, grade: 1), .rise),
            (.studyCompleted(house: player, study: .furrowLore, grade: 1), .lore),
            (.commanderJoined(commander: commander, house: player), .honour),
            (.commanderAssigned(commander: commander, unit: unit.id), .order),
            (.commanderReleased(commander: commander), .stand),
            (.commanderRose(commander: commander, house: player, level: 2), .honour),
            (.commanderWounded(commander: commander, house: player), .dread),
            (.skillFired(commander: commander, house: player, skill: .shieldwall, at: unit.position), .horn),
            (.talentLearned(commander: commander, house: player, talent: .keenEdge, rank: 1), .lore),
            (.talentsForgotten(commander: commander, house: player), .stand),
            (.gearFound(house: player, gear: Gear(id: 70, kind: .saltGlaive, quality: .fine, owner: player), from: .saltwights), .honour),
            (.gearWorn(commander: commander, house: player, gear: 70), .order),
            (.gearTakenOff(commander: commander, house: player, gear: 70), .stand),
            (.gearScrapped(house: player, gear: 70, moonsalt: 10), .coin),
            (.shrineTaken(shrine: 1, house: player, from: nil), .banner),
            (.shrineTaken(shrine: 1, house: foe, from: player), .dread),
            (.carriedToInfirmary(kind: .spear, owner: player, hold: seat.id), .tend),
            (.healingBegun(hold: seat.id, house: player, count: 2), .tend),
            (.unitHealed(unit: unit.id, hold: seat.id), .muster),
            (.woundedLost(hold: seat.id, house: player, count: 1), .dread),
            (.holdScouted(ScoutReport(hold: 40, owner: foe, by: player, watch: 1, garrison: [], ward: 30, maximumWard: 30,
                                      project: nil, training: nil, spoils: .zero, wounded: 0)), .lore),
            (.scoutSeen(hold: seat.id, by: foe), .envoy),
            (.lairAssaulted(LairAssault(rally: 1, caller: player, lair: 60, kind: .reavers, level: 1, at: unit.position, strikes: [],
                                        before: 200, strength: 0, might: 200, shares: [.init(house: player, spoils: .zero)])), .triumph),
            (.lairAssaulted(LairAssault(rally: 1, caller: foe, lair: 60, kind: .reavers, level: 2, at: unit.position, strikes: [],
                                        before: 450, strength: 300, might: 450,
                                        shares: [.init(house: foe, spoils: .zero), .init(house: player, spoils: .zero)])), .batter),
            (hunt(by: player, .spear), .clash),
            (hunt(by: player, .bow), .loose),
            (.sentToGather(unit: unit.id, site: 1), .order),
            (.gathered(unit: unit.id, owner: player, load: Stock(grain: 20)), .dig),
            (.delivered(unit: unit.id, owner: player, hold: seat.id, load: Stock(grain: 20)), .coin),
            (.siteWorkedOut(site: 1, store: .grain, at: unit.position), .stand),
            (.allianceFounded(alliance: alliance, house: player), .banner),
            (.allianceInvited(alliance: 77, house: player), .envoy),
            (.allianceAsked(alliance: alliance, house: foe), .envoy),
            (.allianceAnswered(alliance: alliance, house: foe, accepted: true), .banner),
            (.allianceAnswered(alliance: 77, house: player, accepted: false), .refusal),
            (.allianceJoined(alliance: alliance, house: foe), .banner),
            (.allianceLeft(alliance: alliance, house: player, expelled: false), .stand),
            (.allianceLeft(alliance: alliance, house: player, expelled: true), .dread),
            (.allianceLed(alliance: alliance, house: player), .banner),
            (.helpGiven(by: foe, to: player, count: 2), .accord),
            (.helpGiven(by: player, to: foe, count: 1), .rise),
            (.rallyCalled(rally: 1, caller: player, target: 40), .horn),
            (.rallyJoined(rally: 1, unit: unit.id, house: player), .order),
            (.rallySetOut(rally: 1, caller: player, target: 40, defender: foe, companies: 3), .horn),
            (.rallySetOut(rally: 2, caller: foe, target: seat.id, defender: player, companies: 3), .dread),
            (.rallyStruck(rally: 1, caller: player, target: 40, defender: foe, taken: true), .triumph),
            (.rallyStruck(rally: 1, caller: player, target: 40, defender: foe, taken: false), .clash),
            (.rallyStruck(rally: 2, caller: foe, target: seat.id, defender: player, taken: true), .dread),
            (.rallyStruck(rally: 2, caller: foe, target: seat.id, defender: player, taken: false), .batter),
            (.rallyDispersed(rally: 1, caller: player), .stand),
            (.sentToReinforce(unit: unit.id, owner: player, hold: 40), .order),
            (.happeningBegun(kind: .longHunt, ends: 30), .herald),
            (.happeningMark(house: player, kind: .longHunt, mark: 1, reward: Stock(grain: 50)), .honour),
            (.happeningEnded(kind: .longHunt, leaders: [player]), .triumph),
            (.happeningEnded(kind: .longHunt, leaders: [foe]), .herald),
            (.deedDone(house: player, deed: .founder), .honour),
            (.chargeDone(house: player, charge: .raiseGranary, reward: Stock(grain: 50)), .honour),
            (.said(Word(id: 5, from: foe, watch: 1, text: "Well met", alliance: nil)), .parley),
        ]
        for (event, cue) in concerning {
            XCTAssertEqual(GameSession.cues(for: [event], in: state, player: player), [.watch, cue], "\(event)")
        }
        // Others' doings among themselves pass quietly.
        let others = (foe + 1) % state.houses.count
        let quiet: [GameEvent] = [
            .studyCompleted(house: foe, study: .furrowLore, grade: 1), .commanderJoined(commander: 99, house: foe),
            hunt(by: foe, .spear), .gathered(unit: 500, owner: foe, load: Stock(grain: 5)),
            .allianceFounded(alliance: 77, house: foe), .allianceJoined(alliance: 77, house: others),
            .allianceDisbanded(alliance: 77, name: "The Salt Oath"), .helpGiven(by: foe, to: others, count: 1),
            .rallyCalled(rally: 3, caller: foe, target: 41), .rallyStruck(rally: 3, caller: foe, target: 41, defender: others, taken: true),
            .happeningMark(house: foe, kind: .longHunt, mark: 1, reward: Stock(grain: 5)), .deedDone(house: foe, deed: .founder),
            .chargeDone(house: foe, charge: .raiseGranary, reward: Stock(grain: 5)),
            .said(Word(id: 6, from: player, watch: 1, text: "My own words", alliance: nil)),
            .talentLearned(commander: 99, house: foe, talent: .keenEdge, rank: 1), .talentsForgotten(commander: 99, house: foe),
            .gearFound(house: foe, gear: Gear(id: 71, kind: .reaverAxe, quality: .plain, owner: foe), from: .reavers),
            .gearWorn(commander: 99, house: foe, gear: 71), .gearScrapped(house: foe, gear: 71, moonsalt: 5),
            .shrineTaken(shrine: 1, house: foe, from: others),
            .carriedToInfirmary(kind: .bow, owner: foe, hold: 41), .healingBegun(hold: 41, house: foe, count: 1),
            .woundedLost(hold: 41, house: foe, count: 2),
            .holdScouted(ScoutReport(hold: seat.id, owner: player, by: foe, watch: 1, garrison: [], ward: 30, maximumWard: 30,
                                     project: nil, training: nil, spoils: .zero, wounded: 0)),
            .scoutSeen(hold: 41, by: others),
            .lairAssaulted(LairAssault(rally: 3, caller: foe, lair: 61, kind: .drowned, level: 1, at: unit.position, strikes: [],
                                       before: 200, strength: 0, might: 200, shares: [.init(house: foe, spoils: .zero)])),
            .standardRaised(standard: 83, alliance: 77, house: foe, at: unit.position),
            .standardTorn(standard: 84, alliance: 77, by: others, at: unit.position),
            .itemsGiven(house: foe, kind: .wardStone, count: 1), .itemUsed(house: foe, kind: .hourglass, hold: 41),
            .heritageTaken(house: foe, heritage: .moundClans),
            .allianceStudied(alliance: 77, study: .drillYards, grade: 2), .allianceStudyChosen(alliance: 77, study: .drillYards),
            .allianceGift(house: foe, alliance: 77, stock: Stock(stone: 5), study: .drillYards, grade: 2),
            .hallRaised(hall: 92, alliance: 77, house: foe, at: unit.position), .hallRisen(hall: 92, alliance: 77, at: unit.position),
            .hallStruck(hall: 92, alliance: 77, ward: 10, by: others, at: unit.position),
            .hallTorn(hall: 92, alliance: 77, by: others, at: unit.position),
            .storehouseRaised(storehouse: 96, alliance: 77, house: foe, at: unit.position),
            .storehouseRisen(storehouse: 96, alliance: 77, at: unit.position),
            .storehouseStruck(storehouse: 96, alliance: 77, ward: 10, by: others, at: unit.position),
            .storehouseTorn(storehouse: 96, alliance: 77, by: others, at: unit.position, carried: .zero),
            .laidUp(house: foe, stock: Stock(grain: 5)), .tookBack(house: foe, stock: Stock(grain: 5)),
            .yardRaised(site: 97, alliance: 77, house: foe, store: .stone, at: unit.position),
            .favourRose(house: foe, level: 2),
            .fieldJoined(field: 99, at: unit.position, first: foe, second: others), .fieldEnded(field(held: 0, foe, others)),
            .gearForged(house: foe, gear: Gear(id: 73, kind: .raidersHorn, quality: .fine, owner: foe)),
            .makingsFound(house: player, making: .iron, count: 2), .makingsFound(house: foe, making: .hide, count: 1),
        ]
        XCTAssertEqual(GameSession.cues(for: quiet, in: state, player: player), [.watch])
        // Every new order has its own sound, not the plain click.
        let orders: [(Command, Ambience.Cue)] = [
            (.study(.furrowLore), .rise), (.help(house: foe), .rise),
            (.assign(commander: commander, unit: unit.id), .order), (.gather(unit: unit.id, site: 1), .order),
            (.joinRally(rally: 1, unit: unit.id), .order), (.reinforce(unit: unit.id, hold: 40), .order),
            (.unassign(commander: commander), .stand), (.leaveAlliance, .stand),
            (.foundAlliance(name: "The Grey Hand"), .banner), (.inviteToAlliance(house: foe), .envoy),
            (.askToJoin(alliance: 77), .envoy), (.answerInvitation(alliance: 77, accept: true), .banner),
            (.answerInvitation(alliance: 77, accept: false), .refusal), (.answerRequest(house: foe, accept: true), .banner),
            (.answerRequest(house: foe, accept: false), .refusal), (.expel(house: foe), .refusal),
            (.callRally(from: seat.id, against: 40, watches: 2), .horn),
            (.learnTalent(commander: commander, talent: .keenEdge), .lore), (.forgetTalents(commander: commander), .stand),
            (.wear(gear: 70, commander: commander), .order), (.takeOff(gear: 70), .stand), (.breakUp(gear: 70), .coin),
            (.say(words: "Well met", toAlliance: false), .parley), (.heal(hold: seat.id), .tend),
            (.scout(unit: unit.id, hold: 40), .ride), (.raiseStandard(at: unit.position), .banner),
            (.useItem(.hourglass, hold: seat.id), .sift), (.useItem(.hourglass, hold: nil), .sift), (.useItem(.grainCache, hold: nil), .coin),
            (.useItem(.moonsaltCache, hold: nil), .coin), (.useItem(.wardStone, hold: seat.id), .complete),
            (.useItem(.mendingDraught, hold: nil), .tend), (.takeHeritage(.strandfolk), .banner),
            (.pursueAllianceStudy(.shieldOath), .lore), (.giveToAlliance(Stock(grain: 50)), .coin),
            (.raiseAllianceHall(at: unit.position), .rise), (.forge(.wardensBlade, quality: .plain), .anvil),
            (.raiseStorehouse(at: unit.position), .rise), (.layUp(Stock(grain: 100)), .coin), (.takeBack(Stock(grain: 100)), .coin),
            (.raiseYard(.timber, at: unit.position), .rise),
        ]
        for (command, cue) in orders {
            XCTAssertEqual(GameSession.cues(for: command, events: [], in: state, player: player), [cue], "\(command)")
        }
    }

    /// Blows taken are heard as blows dealt are, losses and hunger as
    /// dread, and works and companies finished as they were begun.
    func testWhatBefallsTheKeepersHouseIsHeard() throws {
        let state = GameState(settings: GameSettings(seedText: "heard", keepers: 1))
        let player = state.player
        func struck(by kind: UnitKind) -> GameEvent {
            .battle(Battle(attacker: 90, attackerOwner: 2, attackerKind: kind, defender: 91, defenderOwner: player, defenderKind: .spear,
                           hold: nil, at: Hex(0, 0), damageDealt: 10, damageTaken: 4, attackerFell: false, defenderFell: false))
        }
        XCTAssertEqual(GameSession.cues(for: [struck(by: .spear)], player: player), [.watch, .clash])
        XCTAssertEqual(GameSession.cues(for: [struck(by: .bow)], player: player), [.watch, .loose])
        XCTAssertEqual(GameSession.cues(for: [.unitLost(unit: 91, kind: .spear, owner: player, at: Hex(0, 0))], player: player), [.watch, .dread])
        XCTAssertEqual(GameSession.cues(for: [.starving(house: player)], player: player), [.watch, .dread])
        // A gift received, a company risen in rank, a seat lost: each heard.
        XCTAssertEqual(GameSession.cues(for: [.gifted(from: 2, to: player, gift: Stock(grain: 10))], player: player), [.watch, .accord])
        XCTAssertEqual(GameSession.cues(for: [.gifted(from: player, to: 2, gift: Stock(grain: 10))], player: player), [.watch],
                       "A gift sent sounds as the order sending it")
        XCTAssertEqual(GameSession.cues(for: [.promoted(unit: 91, owner: player, rank: 1)], player: player), [.watch, .rise])
        XCTAssertEqual(GameSession.cues(for: [.seatMoved(house: player, to: 3)], player: player), [.watch, .dread])
        XCTAssertEqual(GameSession.cues(for: [.seatMoved(house: 2, to: 3)], player: player), [.watch])
        XCTAssertEqual(GameSession.cues(for: [.unitLost(unit: 92, kind: .spear, owner: 2, at: Hex(0, 0)), .starving(house: 2)], player: player), [.watch],
                       "Others' losses are silent")
        let seat = try XCTUnwrap(state.seat(of: player))
        let done = GameEvent.buildingCompleted(hold: seat.id, kind: .granary, level: 1)
        XCTAssertEqual(GameSession.cues(for: [done], in: state, player: player), [.watch, .complete])
        let theirs = try XCTUnwrap(state.holds.first { $0.owner != player })
        XCTAssertEqual(GameSession.cues(for: [.buildingCompleted(hold: theirs.id, kind: .granary, level: 1)], in: state, player: player), [.watch])
        let unit = try XCTUnwrap(state.units(of: player).first)
        XCTAssertEqual(GameSession.cues(for: [.unitTrained(unit: unit.id, hold: seat.id)], in: state, player: player), [.watch, .muster])
        // Refusing a steward's tribute begins a war, and sounds as war does.
        let refusal = GameSession.cues(for: .answer(envoy: 1, accept: false),
                                       events: [.stanceChanged(first: player, second: 2, stance: .war, by: 2)], in: state, player: player)
        XCTAssertEqual(refusal, [.dread])
        XCTAssertEqual(GameSession.cues(for: .answer(envoy: 1, accept: false), events: [], in: state, player: player), [.refusal])
        // Every other order has a sound of its own: earth, coin, a call, a drum.
        let mine = try XCTUnwrap(state.units(of: player).first).id
        let heard: [(Command, Ambience.Cue)] = [
            (.fortify(unit: mine), .dig),
            (.barter(give: .grain, take: .stone, amount: 10), .coin),
            (.gift(to: 2, resource: .grain, amount: 10), .coin),
            (.offerTrade(Trade(give: .grain, 10, for: .stone, 5), to: 2, words: nil), .coin),
            (.propose(.peace, to: 2), .parley),
            (.proposeWithWords(.peace, to: 2, words: "Enough."), .parley),
            (.halt(unit: mine), .stand),
            (.disband(unit: mine), .stand),
        ]
        for (command, cue) in heard {
            XCTAssertEqual(GameSession.cues(for: command, events: [], in: state, player: player), [cue], "\(command)")
        }
        XCTAssertEqual(Set(heard.map(\.1)).count, 4)
        XCTAssertEqual(Ambience.Cue.all.count, Set(Ambience.Cue.all.map { "\($0)" }).count, "Every cue listed once")
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

    /// Thin type only at display sizes: small text is never thinner than
    /// regular, and the smallest never lighter than medium, so its strokes
    /// hold their contrast.
    func testSmallTypeIsNeverThin() {
        XCTAssertEqual(Font.readable(.light, at: 12.5), .regular)
        XCTAssertEqual(Font.readable(.thin, at: 9), .medium)
        XCTAssertEqual(Font.readable(.light, at: 11.5), .medium)
        XCTAssertEqual(Font.readable(.semibold, at: 9), .semibold, "Heavier than medium, as asked")
        XCTAssertEqual(Font.readable(.thin, at: 26), .thin, "Display sizes keep their thin type")
    }

    /// The panels keep their width and grow downward: nothing is cut off.
    func testThePanelsGrowWithTheType() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "larger text", keepers: 1)), store: LocalStore(directory: dir))
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
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "top bar", keepers: 1)), store: LocalStore(directory: dir))
        TextSize.shared.isLarger = false
        let standard = try size(of: TopBar(session: session, compact: false).fixedSize())
        TextSize.shared.isLarger = true
        let larger = try size(of: TopBar(session: session, compact: false).fixedSize())
        let compact = try size(of: TopBar(session: session, compact: true).fixedSize())
        print("LAYOUT top bar \(Int(standard.width)) wide, \(Int(larger.width)) with the larger type, \(Int(compact.width)) compact")
        XCTAssertLessThanOrEqual(standard.width, 960)
        XCTAssertLessThanOrEqual(compact.width, 960, "The larger type fits the narrowest window, its resources unnamed")
        TextSize.shared.isLarger = false
        let narrow = try size(of: TopBar(session: session).frame(width: 960).fixedSize(horizontal: false, vertical: true))
        // In a frame the bar may stand a few points taller; a wrapped line
        // of its smallest type would add ten or more.
        XCTAssertLessThan(narrow.height, standard.height + 10, "Nothing wraps in the narrowest window")
        XCTAssertLessThanOrEqual(larger.width, 1280)
        TextSize.shared.isLarger = true
        let watch = try size(of: WatchClock(session: session))
        XCTAssertGreaterThan(watch.width, 40, "The watch is never squeezed")
        XCTAssertLessThan(watch.height, 30, "and stays on one line")
    }

    /// The camera glides to the seat, eased; at once where motion is
    /// reduced; and a pan by the keeper on the way has the last word.
    @MainActor
    func testTheCameraGlidesAndGivesWayToThePlayer() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "a glide", keepers: 1)), store: LocalStore(directory: dir))
        let seat = try XCTUnwrap(session.state.seat(of: session.player)).position
        var target = session.camera
        target.focus(on: seat)
        let far = Camera(centerX: target.centerX + 40, centerY: target.centerY - 30, scale: target.scale)

        session.camera = far
        session.glide(to: seat, reducesMotion: true)
        XCTAssertEqual(session.camera, target, "At once")

        session.camera = far
        session.glide(to: seat, reducesMotion: false)
        XCTAssertEqual(session.camera, far, "Not yet")
        let deadline = Date().addingTimeInterval(3)
        while session.camera != target, Date() < deadline { try await Task.sleep(nanoseconds: 20_000_000) }
        XCTAssertEqual(session.camera, target, "There after a moment")

        session.camera = far
        session.glide(to: seat, reducesMotion: false)
        try await Task.sleep(nanoseconds: 60_000_000)
        var panned = session.camera
        panned.centerX += 5
        session.camera = panned
        try await Task.sleep(nanoseconds: 600_000_000)
        XCTAssertEqual(session.camera, panned, "The keeper's pan stands")
    }

    /// The top bar's ledger is the world's own, and kept until it changes.
    @MainActor
    func testTheLedgerIsTheWorldsOwn() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "a ledger", keepers: 1)), store: LocalStore(directory: dir))
        let state = session.state, me = session.player
        let ledger = session.ledger
        XCTAssertEqual(ledger.income, state.income(of: me))
        XCTAssertEqual(ledger.upkeep, state.upkeep(of: me))
        XCTAssertEqual(ledger.room, state.storage(of: me))
        for resource in Resource.allCases {
            XCTAssertEqual(ledger.summaries[resource],
                           IncomeBreakdown(state: state, house: me, resource: resource, territory: session.territory).summary)
        }
        let version = session.tilesVersion
        _ = session.ledger
        XCTAssertEqual(session.tilesVersion, version)
    }

    /// A company's march is told in words, never in coordinates.
    func testAMarchIsToldInWords() throws {
        var state = GameState(settings: GameSettings(seedText: "a march told", houseCount: 3, radius: 16, keepers: 1))
        let me = state.player
        let index = try XCTUnwrap(state.units.firstIndex { $0.owner == me })
        XCTAssertNil(UnitPanel.march(of: state.units[index], in: state, viewer: me))
        let seat = try XCTUnwrap(state.seat(of: me))
        state.units[index].destination = seat.position
        let distance = state.units[index].position.distance(to: seat.position)
        XCTAssertEqual(UnitPanel.march(of: state.units[index], in: state, viewer: me),
                       "Marching to \(seat.name), \(distance) tile\(distance == 1 ? "" : "s") away.")
        // When the realm has worked out when it should be there, that too.
        let id = state.units[index].id
        state.marches = [March(unit: id, owner: me, route: [seat.position], destination: seat.position, arrives: state.watch + 3)]
        XCTAssertEqual(UnitPanel.march(of: state.units[index], in: state, viewer: me),
                       "Marching to \(seat.name), \(distance) tile\(distance == 1 ? "" : "s") away, there in 3 watches.")
        state.marches = [March(unit: id, owner: me, route: [seat.position], destination: seat.position, arrives: state.watch + 1)]
        XCTAssertEqual(UnitPanel.arrival(of: state.units[index], in: state), "as the watch turns")
        state.units[index].errand = .homeward
        state.units[index].load = Stock(grain: 40)
        let homeward = GathererList.line(for: state.units[index], in: state)
        XCTAssertTrue(homeward.hasPrefix(state.title(of: state.units[index])) && homeward.hasSuffix(" home with 40 grain, there as the watch turns"),
                      homeward)
        state.units[index].errand = nil
        state.units[index].load = nil
        state.marches = nil
        let dark = try XCTUnwrap(state.map.hexes.first { hex in
            state.map.index(of: hex).map { !state.houses[me].explored[$0] } ?? false
        })
        state.units[index].destination = dark
        XCTAssertTrue(try XCTUnwrap(UnitPanel.march(of: state.units[index], in: state, viewer: me)).hasPrefix("Marching into the dark, "))
        let open = try XCTUnwrap(state.map.hexes.first { hex in
            state.hold(at: hex) == nil && (state.map.index(of: hex).map { state.houses[me].explored[$0] } ?? false)
        })
        state.units[index].destination = open
        let words = try XCTUnwrap(UnitPanel.march(of: state.units[index], in: state, viewer: me))
        XCTAssertTrue(words.hasPrefix("Marching, ") && words.hasSuffix(" to go."), words)
        XCTAssertFalse(words.contains("("), "No coordinates")
    }

    /// A hold's long panel scrolls within its height rather than run off the window.
    func testTheHoldPanelScrollsWithinItsHeight() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let session = GameSession(state: GameState(settings: GameSettings(seedText: "larger text", keepers: 1)), store: LocalStore(directory: dir))
        session.focusOnSeat()
        XCTAssertNotNil(session.selectedHold)
        TextSize.shared.isLarger = true
        let larger = try size(of: SelectionPanel(session: session).fixedSize(horizontal: false, vertical: true))
        XCTAssertLessThanOrEqual(larger.height, 640)
    }
}
