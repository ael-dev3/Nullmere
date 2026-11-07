import Foundation
@testable import LauncherKit
import NullmereCompanionCore
import NullmereRealm
import NullmereTestSupport
import SwiftUI
import XCTest
@testable import NullmereCore
@testable import NullmereKit

/// The app against a realm across the network, as a keeper meets it: the
/// front door reaching the realm, a new keeper entering by name, playing,
/// the server refusing this Mac's key, which is kept, and a keeper waiting
/// for a seat. SpacetimeDB is held in memory, with the realm's own steward
/// beside it.
@MainActor
final class NetworkAppTests: XCTestCase {
    private var dirs: [URL] = []

    override func tearDown() async throws {
        for dir in dirs { try? FileManager.default.removeItem(at: dir) }
    }

    private func until(_ what: String, timeout: Double = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw NSError(domain: "NetworkAppTests", code: 1, userInfo: [NSLocalizedDescriptionKey: "Timed out waiting for \(what)"]) }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func steward(_ db: FakeSpacetime, seats: Int) async throws -> Task<Void, Never> {
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "network app",
                                             seats: seats, watchLength: 600, now: 0)
        return Task { await steward.run(clock: { 1 }) }
    }

    private func app(_ db: FakeSpacetime, identity: MemoryStore, realm: String, accepted: Bool = true, scheme: String = "https") -> GameApp {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dirs.append(dir)
        let address = GameApp.RealmAddress.network(URL(string: "\(scheme)://realm.test/\(realm)")!)
        UserDefaults.standard.removeObject(forKey: GameApp.nameKey(for: address))
        // A Mac whose keeper has accepted the realm's compact, or, for the
        // compact's own tests, never has.
        if accepted {
            UserDefaults.standard.set(Compact.edition, forKey: GameApp.compactKey)
        } else {
            UserDefaults.standard.removeObject(forKey: GameApp.compactKey)
        }
        return GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: address, identity: identity,
                       opensAtOnce: false, transport: db, pollInterval: 0.05)
    }

    private func draw(_ view: some View) {
        let renderer = ImageRenderer(content: view.frame(width: 1100, height: 720).background(Color.black))
        renderer.scale = 1
        guard let image = renderer.cgImage else { return XCTFail("Nothing drawn") }
        XCTAssertGreaterThanOrEqual(litPixels(image), 20, "Drawn, not blank")
    }

    /// A realm moved on past this build: its door says so and won't open,
    /// nor the compact, and offers the page of the newest build.
    func testARealmMovedOnPastThisBuildIsToldAtItsDoor() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dirs.append(dir)
        UserDefaults.standard.removeObject(forKey: GameApp.compactKey)
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false,
                          address: .network(URL(string: "https://realm.test/moved-on")!), identity: MemoryStore(), opensAtOnce: false)
        var opened: [URL] = []
        app.openURL = { opened.append($0) }
        func status(speech: Int, compact: Int) -> RealmStatus {
            RealmStatus(name: "The Nullmere", age: 1, watch: 3, seats: 4, freeSeats: 2, keepers: 2, online: 1, ready: 0, secondsLeft: 60,
                        isEnding: false, speech: speech, oldestSpeech: speech, compact: compact)
        }
        app.hear(.status(status(speech: Speech.current, compact: Compact.edition)))
        XCTAssertFalse(app.wantsNewerBuild, "A realm of this build")
        XCTAssertTrue(app.canEnter(with: "Ama"))

        app.hear(.status(status(speech: Speech.current + 1, compact: Compact.edition)))
        XCTAssertTrue(app.wantsNewerBuild, "The realm no longer hears this Mac")
        XCTAssertFalse(app.canEnter(with: "Ama"), "No way in from this build")
        PressableButtons.isListening = true
        defer { PressableButtons.isListening = false }
        draw(FrontDoor(app: app, name: "Ama"))
        XCTAssertFalse(PressableButtons.press("Enter the world"))
        XCTAssertTrue(PressableButtons.press("Get the new build"))
        XCTAssertEqual(opened, [URL(string: Speech.newestBuild)!])
        app.enterOrReadCompact(name: "Ama")
        XCTAssertFalse(app.readsCompact, "Nor the compact")
        app.acceptCompact(enteringAs: "Ama")
        XCTAssertNil(app.compactAccepted, "Nothing accepted for a realm that can't be entered")

        app.hear(.status(status(speech: Speech.current, compact: Compact.edition + 1)))
        XCTAssertTrue(app.wantsNewerBuild, "A compact newer than this build can show")
    }

    /// A keeper carries their House to another Mac: the first makes the
    /// words and shows them once, to write down; the second, never having
    /// accepted the compact, reads it, then takes the House up by them. A
    /// Mac may leave its identity for a new one.
    func testAKeeperIsCarriedToAnotherMacByTheirWords() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        PressableButtons.isListening = true
        defer { PressableButtons.isListening = false }

        let first = app(db, identity: MemoryStore(), realm: "carried-first")
        first.open()
        try await until("the first Mac's door") { if case .open = first.door { return true } else { return false } }
        XCTAssertFalse(first.canMakeWords, "No keeper yet, no words")
        first.enterWorld(name: "Ama")
        try await until("Ama in the world") { first.session != nil }
        let house = try XCTUnwrap(first.session?.player)
        first.makeWords()
        XCTAssertTrue(first.isSealing)
        XCTAssertFalse(first.canMakeWords, "One making at a time")
        try await until("the words kept by the realm") { first.carriedWords != nil }
        let words = try XCTUnwrap(first.carriedWords)
        XCTAssertEqual(words.count, KeeperWords.count)
        XCTAssertNil(first.carryProblem)
        draw(FrontDoor(app: first))
        XCTAssertTrue(PressableButtons.press("Written down"))
        XCTAssertNil(first.carriedWords, "Shown only then")

        let identity = MemoryStore()
        let second = app(db, identity: identity, realm: "carried-second", accepted: false)
        defer { UserDefaults.standard.removeObject(forKey: GameApp.compactKey) }
        second.open()
        try await until("the second Mac's door") { if case .open = second.door { return true } else { return false } }
        draw(FrontDoor(app: second))
        second.beginBringingWords()
        XCTAssertTrue(second.isBringingWords)
        draw(FrontDoor(app: second))
        second.bringWords("acorn alder")
        XCTAssertFalse(second.readsCompact, "Two words take up no one")
        second.bringWords(words.joined(separator: " "))
        XCTAssertTrue(second.readsCompact, "The compact first, on a Mac that never accepted it")
        draw(FrontDoor(app: second))
        XCTAssertTrue(PressableButtons.press("Accept and enter"))
        try await until("Ama on the second Mac") { second.session != nil }
        XCTAssertEqual(second.keeperName, "Ama")
        XCTAssertEqual(second.session?.player, house, "Her House with her")
        XCTAssertFalse(second.isBringingWords)

        // Words made again let the first ones go.
        second.makeWords()
        try await until("new words kept") { second.carriedWords != nil }
        XCTAssertNotEqual(second.carriedWords, words)
        second.putWordsAway()

        // The second Mac leaves its identity for a new one.
        let kept = identity.value
        second.leaveIdentity()
        XCTAssertNil(second.keeperName)
        guard case .frontDoor = second.phase else { return XCTFail("Out of the world, at the door") }
        try await until("a new identity made") { identity.value.map { !$0.isEmpty && $0 != kept } ?? false }
        second.stopBringingWords()
        XCTAssertFalse(second.isBringingWords)
    }

    /// The door's ways aside, pressed as a keeper known here presses them:
    /// words asked for while the realm doesn't answer are refused, and the
    /// door says why; words brought that the realm doesn't know take up no
    /// one; leaving this Mac's identity is asked once more first; and Back
    /// goes a step back from each.
    func testTheDoorsWaysAsideArePressed() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        PressableButtons.isListening = true
        defer { PressableButtons.isListening = false }
        defer { UserDefaults.standard.removeObject(forKey: GameApp.compactKey) }
        let identity = MemoryStore()
        let app = app(db, identity: identity, realm: "ways aside", accepted: false)
        func doorOpens() async throws {
            try await until("the door open") { if case .open = app.door { return true } else { return false } }
        }
        app.open()
        try await doorOpens()
        // Ama enters once with the compact carried to the realm, though this
        // Mac keeps no word of it: below, it has never accepted it.
        (app.link as? NetworkRealmLink)?.compactAccepted = Compact.edition
        app.enterWorld(name: "Ama")
        try await until("Ama in the world") { app.session != nil }
        app.leaveWorld()
        try await doorOpens()
        (app.link as? NetworkRealmLink)?.compactAccepted = nil
        XCTAssertEqual(app.keeperName, "Ama", "Known here still")

        // Words asked for while the realm doesn't answer: none are made.
        draw(FrontDoor(app: app))
        await db.setReachable(false)
        XCTAssertTrue(PressableButtons.press("Carry this identity to another Mac"), "Among \(PressableButtons.actions.keys.sorted())")
        try await until("the words refused") { app.carryProblem != nil }
        XCTAssertNil(app.carriedWords)
        draw(FrontDoor(app: app))
        await db.setReachable(true)
        app.openDoor()
        try await doorOpens()

        // Words brought: two take up no one; sixteen the compact first, and
        // Back from it accepts nothing.
        draw(FrontDoor(app: app))
        XCTAssertTrue(PressableButtons.press("Words from another Mac? Bring them"), "Among \(PressableButtons.actions.keys.sorted())")
        XCTAssertTrue(app.isBringingWords)
        PressableButtons.forget("Take it up")
        draw(FrontDoor(app: app, words: "acorn alder"))
        XCTAssertFalse(PressableButtons.press("Take it up"), "Two words take up no one")
        let strange = KeeperWords.make().joined(separator: " ")
        draw(FrontDoor(app: app, words: strange))
        XCTAssertTrue(PressableButtons.press("Take it up"))
        XCTAssertTrue(app.readsCompact, "The compact first, on a Mac that never accepted it")
        draw(FrontDoor(app: app))
        XCTAssertTrue(PressableButtons.press("Back"))
        XCTAssertFalse(app.readsCompact)
        XCTAssertTrue(app.isBringingWords, "Back to the words")

        // This Mac keeps House Ama as itself: leaving its identity is asked
        // once more, then done.
        let kept = identity.value
        draw(FrontDoor(app: app))
        XCTAssertTrue(PressableButtons.press("Leave this identity"), "Among \(PressableButtons.actions.keys.sorted())")
        XCTAssertEqual(app.keeperName, "Ama", "Asked once more, not left")
        draw(FrontDoor(app: app, leaving: true))
        XCTAssertTrue(PressableButtons.press("Leave it for good"))
        XCTAssertNil(app.keeperName)
        try await until("a new identity made") { identity.value.map { !$0.isEmpty && $0 != kept } ?? false }
        try await doorOpens()

        // Words the realm doesn't know are refused at the door once the
        // compact is accepted for them, and again, not asked twice.
        draw(FrontDoor(app: app, words: strange))
        XCTAssertTrue(PressableButtons.press("Take it up"))
        XCTAssertTrue(app.readsCompact)
        draw(FrontDoor(app: app))
        XCTAssertTrue(PressableButtons.press("Accept and enter"), "Among \(PressableButtons.actions.keys.sorted())")
        try await until("the words refused") { app.arrivalProblem != nil && !app.isEntering }
        XCTAssertNil(app.session)
        XCTAssertFalse(app.mustReadCompact)
        draw(FrontDoor(app: app, words: strange))
        XCTAssertTrue(PressableButtons.press("Take it up"))
        XCTAssertFalse(app.readsCompact, "Accepted, not read again")
        try await until("the words refused again") { app.arrivalProblem != nil && !app.isEntering }
        XCTAssertNil(app.session)
        draw(FrontDoor(app: app))
        XCTAssertTrue(PressableButtons.press("Back"))
        XCTAssertFalse(app.isBringingWords, "Back at the door")

        // And in by a new name, the compact already accepted.
        draw(FrontDoor(app: app, name: "Bel"))
        XCTAssertTrue(PressableButtons.press("Enter the world"))
        try await until("Bel in the world") { app.session != nil }
        XCTAssertEqual(app.keeperName, "Bel")
        app.leaveWorld()
    }

    func testAKeeperEntersPlaysAndKeepsTheirKey() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let identity = MemoryStore()
        let app = app(db, identity: identity, realm: "enters", accepted: false)
        app.open()
        guard case .frontDoor = app.phase else { return XCTFail("A ready model opens the front door") }
        draw(FrontDoor(app: app))
        try await until("the realm's status") { if case .open = app.door { return true } else { return false } }
        guard case .open(let status) = app.door else { return }
        XCTAssertEqual(status.freeSeats, 4)
        XCTAssertFalse(app.canEnter(with: "A"), "A name of one letter won't do")
        XCTAssertTrue(app.canEnter(with: "Ama"))
        draw(FrontDoor(app: app))

        // The keeper writes a name at the door and presses Enter: one letter
        // is refused, and said so; a good name goes in.
        PressableButtons.isListening = true
        defer { PressableButtons.isListening = false }
        XCTAssertNotNil(RealmState.nameProblem("A"))
        PressableButtons.forget("Enter the world")
        draw(FrontDoor(app: app, name: "A"))
        XCTAssertFalse(PressableButtons.press("Enter the world"), "Not with a name of one letter")
        draw(FrontDoor(app: app, name: "Ama"))
        // Never accepted on this Mac: the realm's compact first, and Back
        // goes back to the door with nothing accepted.
        XCTAssertTrue(app.mustReadCompact)
        XCTAssertTrue(PressableButtons.press("Enter the world"))
        XCTAssertTrue(app.readsCompact, "The compact, to read and accept")
        XCTAssertFalse(app.isEntering, "Not before it is accepted")
        draw(FrontDoor(app: app, name: "Ama"))
        XCTAssertTrue(PressableButtons.press("Back"))
        XCTAssertFalse(app.readsCompact)
        XCTAssertNil(app.compactAccepted, "Nothing accepted")
        app.enterOrReadCompact(name: "Ama")
        draw(FrontDoor(app: app, name: "Ama"))
        XCTAssertTrue(PressableButtons.press("Accept and enter"))
        defer { UserDefaults.standard.removeObject(forKey: GameApp.compactKey) }
        XCTAssertEqual(app.compactAccepted, Compact.edition)
        XCTAssertEqual(UserDefaults.standard.object(forKey: GameApp.compactKey) as? Int, Compact.edition, "Kept on this Mac")
        XCTAssertFalse(app.mustReadCompact, "Not asked again until its words change")
        XCTAssertTrue(app.isEntering)
        draw(FrontDoor(app: app))
        try await until("the world") { app.session != nil }
        let session = try XCTUnwrap(app.session)
        XCTAssertEqual(app.keeperName, "Ama")
        XCTAssertEqual(session.playerHouse.title, "House Ama")
        draw(GameRootView(app: app))

        // An order goes across, and the realm's answer comes back.
        let spear = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .spear })
        XCTAssertTrue(session.perform(.fortify(unit: spear.id)))
        var handled = 0
        for _ in 0..<500 where handled < 1 {
            handled = await db.handled(kind: "order")
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertGreaterThanOrEqual(handled, 1, "The steward carried the order out")

        // The server stops taking this Mac's key: the keeper is told, and
        // the key is kept, never erased, in case the server takes it again.
        let key = try XCTUnwrap(identity.value)
        let credentials = try JSONDecoder().decode(SpacetimeCredentials.self, from: Data(key.utf8))
        await db.forget(token: credentials.token)
        try await until("the keeper to be told") { session.isOutOfReach }
        XCTAssertEqual(identity.value, key, "The key is kept")
        XCTAssertTrue(app.session === session, "and the keeper stays in the world while the realm is asked again")
        XCTAssertEqual(app.keeperName, "Ama")
        draw(GameRootView(app: app))
        app.leaveWorld()
    }

    func testAKeeperWaitsForASeat() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 2)
        defer { running.cancel() }
        var seated: [GameApp] = []
        for (index, name) in ["Ama", "Cor"].enumerated() {
            let keeper = app(db, identity: MemoryStore(), realm: "full-\(index)")
            keeper.open()
            try await until("the realm") { if case .open = keeper.door { return true } else { return false } }
            keeper.enterWorld(name: name)
            try await until("\(name)'s seat") { keeper.session != nil }
            seated.append(keeper)
        }
        let first = seated[0]

        let second = app(db, identity: MemoryStore(), realm: "full-second")
        second.open()
        try await until("the realm, full") { if case .open(let status) = second.door { return status.freeSeats == 0 } else { return false } }
        // The door says every seat is held, and what entering means then.
        draw(FrontDoor(app: second))
        second.enterWorld(name: "Bel")
        try await until("Bel to wait") { second.isWaitingForSeat }
        XCTAssertNil(second.session, "No seat, no world")
        XCTAssertEqual(second.keeperName, "Bel", "Known to the realm all the same")
        // The clock asks again after a seat; none has fallen free.
        XCTAssertNotNil(second.seatTimer)
        second.seatTimer?.fire()
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(second.isWaitingForSeat, "Still waiting")
        XCTAssertNil(second.session)
        draw(FrontDoor(app: second))
        second.leaveDoor()
        XCTAssertFalse(second.isWaitingForSeat)
        first.leaveWorld()
        XCTAssertNil(first.session)
    }

    /// A new age begun without a seat for the keeper: back to the front door,
    /// to wait there for one, not left in an age that is gone.
    func testANewAgeWithoutASeatGoesBackToTheDoor() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let app = app(db, identity: MemoryStore(), realm: "seatless")
        app.open()
        try await until("the realm") { if case .open = app.door { return true } else { return false } }
        app.enterWorld(name: "Ama")
        try await until("the world") { app.session != nil }
        let session = try XCTUnwrap(app.session)
        let seatless = Keeper(id: "seatless", name: "Ama", house: nil, isReady: false, isOnline: true, arrival: 0)
        session.onNewAge?(seatless, session.state)
        XCTAssertNil(app.session, "Not left in the age gone")
        guard case .frontDoor = app.phase else { return XCTFail("At the door") }
        XCTAssertTrue(app.isWaitingForSeat, "waiting there for a seat")
        XCTAssertNotNil(app.seatTimer)
        app.leaveDoor()
    }

    func testTheRealmOutOfReachAtTheDoorAndInTheWorld() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let identity = MemoryStore()
        let app = app(db, identity: identity, realm: "reach")
        await db.setReachable(false)
        app.open()
        try await until("the door to find the realm out of reach") { if case .unreachable = app.door { return true } else { return false } }
        XCTAssertFalse(app.canEnter(with: "Ama"), "No way in to a realm that doesn't answer")
        draw(FrontDoor(app: app))

        // Try again, once it answers.
        await db.setReachable(true)
        app.openDoor()
        try await until("the realm to answer again") { if case .open = app.door { return true } else { return false } }
        app.enterWorld(name: "Ama")
        try await until("the world") { app.session != nil }
        let session = try XCTUnwrap(app.session)

        // Lost in play: the keeper is told once, and told again when it answers.
        await db.setReachable(false)
        try await until("the keeper to be told") { session.isOutOfReach }
        XCTAssertEqual(session.notices.filter { $0.text.contains("out of reach") }.count, 1)
        draw(GameRootView(app: app))
        await db.setReachable(true)
        try await until("the realm to answer again") { !session.isOutOfReach }
        XCTAssertEqual(session.notices.last?.text, "The realm answers again.")
        app.leaveWorld()
    }

    func testANameAlreadyHeldIsRefused() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let first = app(db, identity: MemoryStore(), realm: "names-first")
        first.open()
        try await until("the realm") { if case .open = first.door { return true } else { return false } }
        first.enterWorld(name: "Ama")
        try await until("Ama's seat") { first.session != nil }

        let second = app(db, identity: MemoryStore(), realm: "names-second")
        second.open()
        try await until("the realm") { if case .open = second.door { return true } else { return false } }
        second.enterWorld(name: "Ama")
        try await until("the refusal") { second.arrivalProblem != nil }
        XCTAssertEqual(second.arrivalProblem, "A keeper or a House already goes by that name.")
        XCTAssertNil(second.session)
        XCTAssertFalse(second.isEntering, "The door is open to try another name")
        draw(FrontDoor(app: second))
        second.enterWorld(name: "Bel")
        try await until("Bel's seat") { second.session != nil }
        XCTAssertNil(second.arrivalProblem)
        first.leaveWorld()
        second.leaveWorld()
    }

    /// A door tried again lets the old link go, so nothing it still has on
    /// its way can be taken for the new one's; the game's sound is wanted
    /// at the door and let go in the launcher, the score as the keeper left it.
    func testTheDoorLetsGoWhatItLeaves() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let defaults = UserDefaults.standard
        let kept = defaults.object(forKey: "music.enabled")
        defaults.set(false, forKey: "music.enabled")
        defer { kept == nil ? defaults.removeObject(forKey: "music.enabled") : defaults.set(kept, forKey: "music.enabled") }
        let app = app(db, identity: MemoryStore(), realm: "lets go")
        XCTAssertFalse(app.ambience.isMusicOn, "The score stays off from the first")
        app.open()
        XCTAssertTrue(app.ambience.isWanted, "Sound is wanted at the door")
        try await until("the door open") { if case .open = app.door { return true } else { return false } }
        let old = try XCTUnwrap(app.link)
        XCTAssertNotNil(old.onEvent)
        app.openDoor()
        XCTAssertNil(old.onEvent, "The old link is let go")
        XCTAssertFalse(app.link === old)
        try await until("the door open again") { if case .open = app.door { return true } else { return false } }

        app.leaveDoor()
        XCTAssertFalse(app.ambience.isWanted, "Back in the launcher, the game's sound goes")
        XCTAssertFalse(app.ambience.isAtWar)
        app.open()
        XCTAssertTrue(app.ambience.isWanted, "and comes back with the door")
        app.leaveDoor()
    }

    func testAnAddressWithoutADatabaseIsSaidPlainly() {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dirs.append(dir)
        let address = GameApp.RealmAddress.network(URL(string: "https://realm.test")!)
        let app = GameApp(store: LocalStore(directory: dir), readiness: { .ready }, sound: false, address: address,
                          identity: MemoryStore(), opensAtOnce: false, transport: nil, pollInterval: 1)
        app.open()
        XCTAssertEqual(app.door, .unreachable("The realm's address can't be read."))
        XCTAssertFalse(app.canEnter(with: "Ama"))
        draw(FrontDoor(app: app))
    }

    /// Quitting just after an order the realm can't be reached for: the app
    /// waits a moment for it, no longer, then lets the keeper go; the order
    /// is kept, and goes once the realm answers again.
    func testAnOrderThatCantGoHoldsTheQuitOnlyAMoment() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        let app = app(db, identity: MemoryStore(), realm: "quits")
        app.open()
        try await until("the realm's status") { if case .open = app.door { return true } else { return false } }
        app.enterWorld(name: "Ama")
        try await until("the world") { app.session != nil }
        let session = try XCTUnwrap(app.session)
        try await until("nothing left to send") { app.ordersWaiting == 0 }

        await db.setReachable(false)
        let spear = try XCTUnwrap(session.state.units(of: session.player).first { $0.kind == .spear })
        XCTAssertTrue(session.perform(.fortify(unit: spear.id)))
        XCTAssertGreaterThan(app.ordersWaiting, 0, "The order waits for the realm")
        let quit = expectation(description: "let go")
        let start = Date()
        app.sendWaiting(within: 0.6) { quit.fulfill() }
        await fulfillment(of: [quit], timeout: 5)
        XCTAssertGreaterThanOrEqual(Date().timeIntervalSince(start), 0.5, "It waited for the order")
        XCTAssertGreaterThan(app.ordersWaiting, 0, "and let the keeper go without it")

        await db.setReachable(true)
        try await until("the order gone to the realm") { app.ordersWaiting == 0 }
        app.leaveWorld()
    }

    /// A keeper links their phone from the realm's door: the Mac shows a
    /// code in three fours with the QR code carrying it and the realm, the
    /// realm keeping only its digest; a phone bringing it comes in as the
    /// keeper; a code offered again says how many devices speak for them;
    /// the code put away, and every phone let go. A realm out of reach is
    /// told so, and one reached in the clear links no phone. In debug, the
    /// link and what this Mac sees are written where the smoke test of the
    /// phone reads them.
    func testAKeepersPhoneIsLinkedFromTheDoor() async throws {
        let db = FakeSpacetime()
        let running = try await steward(db, seats: 4)
        defer { running.cancel() }
        PressableButtons.isListening = true
        defer { PressableButtons.isListening = false }
        let mac = app(db, identity: MemoryStore(), realm: "phone-link")
        mac.open()
        try await until("the door") { if case .open = mac.door { return true } else { return false } }
        XCTAssertFalse(mac.canLinkPhone, "No keeper yet, no phone")
        XCTAssertFalse(mac.offersPhoneLink)
        mac.enterWorld(name: "Ama")
        try await until("Ama in the world") { mac.session != nil }
        XCTAssertTrue(mac.offersPhoneLink)
        XCTAssertTrue(mac.canLinkPhone)
        draw(FrontDoor(app: mac))
        XCTAssertTrue(PressableButtons.press("Link your phone"))
        XCTAssertTrue(mac.isAskingForLink)
        XCTAssertFalse(mac.canLinkPhone, "One asking at a time")
        try await until("the code shown") { mac.phoneLink != nil }
        let invite = try XCTUnwrap(mac.phoneLink)
        XCTAssertEqual(invite.realm.absoluteString, "https://realm.test/phone-link")
        XCTAssertEqual(CompanionInvite(url: invite.url), invite, "The QR code's link, read back whole")
        XCTAssertEqual(mac.phonesLinked, 0)
        XCTAssertNotNil(mac.phoneLinkLapses)
        let code = try XCTUnwrap(FrontDoor.qrCode(for: invite.url))
        XCTAssertGreaterThan(code.width, 20, "A QR code drawn")
        draw(FrontDoor(app: mac))

        // A phone, by its own identity, brings the code and comes in as Ama.
        let phone = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        var arrived: Keeper?
        phone.onEvent = { if case .arrived(let keeper, _) = $0 { arrived = keeper } }
        phone.connect()
        phone.takeLink(code: invite.code)
        try await until("the phone in as Ama") { arrived != nil }
        XCTAssertEqual(arrived?.name, "Ama")
        defer { phone.close() }

        // Put away, then offered again: one device speaks for her.
        XCTAssertTrue(PressableButtons.press("Done"))
        XCTAssertNil(mac.phoneLink)
        mac.linkPhone()
        try await until("a second code") { mac.phoneLink != nil }
        XCTAssertNotEqual(mac.phoneLink?.code, invite.code)
        XCTAssertEqual(mac.phonesLinked, 1)
        draw(FrontDoor(app: mac))
        XCTAssertTrue(PressableButtons.press("Let every phone go"))
        try await until("every phone let go") { mac.phonesLinked == 0 && !mac.isAskingForLink }
        XCTAssertNil(mac.phoneLink)
        XCTAssertNil(mac.phoneProblem)

        // In debug: the link, and what this Mac sees, written for the smoke test.
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        dirs.append(dir)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let linkFile = dir.appendingPathComponent("link").path, reportFile = dir.appendingPathComponent("report").path
        GameApp.tellLink(invite, to: nil)
        GameApp.tellLink(invite, to: linkFile)
        XCTAssertEqual(try String(contentsOfFile: linkFile, encoding: .utf8), invite.url.absoluteString)
        let company = try XCTUnwrap(mac.session?.state.units(of: mac.session?.player ?? -1).first { $0.kind.isMilitary })
        XCTAssertTrue(mac.session?.perform(.fortify(unit: company.id)) == true)
        // A work raised at the seat, and words said to the realm: the phone's smoke test sets both from the phone.
        let seat = try XCTUnwrap(mac.session?.state.seat(of: mac.session?.player ?? -1))
        let raised = try XCTUnwrap(BuildingKind.allCases.first { mac.session?.perform(.build(hold: seat.id, kind: $0)) == true })
        XCTAssertTrue(mac.session?.perform(.say(words: "Heard on the Mac", toAlliance: false)) == true)
        let sworn = mac.session?.state.alliance(of: mac.session?.player ?? -1)
        mac.linkFromEnvironment(["NULLMERE_OFFER_LINK": linkFile, "NULLMERE_LINK_REPORT": reportFile, "NULLMERE_FOUND_ALLIANCE": "The Linked Accord"],
                                every: 0.05)
        try await until("the code offered from the environment") { mac.phoneLink != nil }
        let banner = try XCTUnwrap(mac.session?.state.alliance(of: mac.session?.player ?? -1), "An alliance for the phone to speak to")
        XCTAssertEqual(banner.name, sworn?.name ?? "The Linked Accord", "Raised, unless the House was sworn to one already")
        XCTAssertTrue(mac.session?.perform(.say(words: "Heard by the accord", toAlliance: true)) == true)
        try await until("this Mac's House reported") {
            let report = (try? String(contentsOfFile: reportFile, encoding: .utf8)) ?? ""
            return report.contains("\(company.id)") && report.contains("\(seat.id):\(raised.rawValue)") && report.contains("said: Heard on the Mac")
                && report.contains("alliance said: Heard by the accord")
        }
        mac.stopLinkReport()
        let report = try String(contentsOfFile: reportFile, encoding: .utf8).split(separator: "\n").map(String.init)
        XCTAssertTrue(report[0].hasPrefix("dug in: "), "\(report)")
        XCTAssertTrue(report[1].hasPrefix("at work: ") && report[1].split(separator: " ").contains("\(seat.id):\(raised.rawValue)"), "\(report)")
        XCTAssertEqual(report[2], "watch: \(mac.session?.state.watch ?? -1)")
        XCTAssertEqual(report[3], "alliance: \(banner.name)")
        XCTAssertEqual(Array(report.suffix(2)), ["said: Heard on the Mac", "alliance said: Heard by the accord"])

        // Out of reach: told so, both the offer and the letting go.
        mac.putPhoneLinkAway()
        await db.setReachable(false)
        mac.linkPhone()
        try await until("the offer told out of reach", timeout: 40) { mac.phoneProblem != nil && !mac.isAskingForLink }
        draw(FrontDoor(app: mac))
        mac.unlinkPhones()
        XCTAssertFalse(mac.canLinkPhone, "Asking")
        try await until("the letting go told out of reach", timeout: 40) { mac.phoneProblem != nil && !mac.isAskingForLink }
        await db.setReachable(true)
        mac.leaveWorld()

        // A realm reached in the clear links no phone.
        let clear = app(db, identity: MemoryStore(), realm: "in-the-clear", scheme: "http")
        clear.open()
        try await until("the clear realm's door") { if case .open = clear.door { return true } else { return false } }
        clear.enterWorld(name: "Bel")
        try await until("Bel in the world") { clear.session != nil }
        clear.linkPhone()
        XCTAssertEqual(clear.phoneProblem, GameApp.phoneNeedsHTTPS)
        XCTAssertNil(clear.phoneLink)
        clear.leaveWorld()
    }
}
