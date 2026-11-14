import Foundation
import NullmereCore
@testable import NullmereLive
@testable import NullmereLiveStage
import NullmereModels
import NullmereRealm
@testable import NullmereWorld
import XCTest

/// A line to no realm at all: it holds the rows a test gives it, tells
/// the session when they change, and keeps what was asked of it.
final class StandInLine: LiveLine, @unchecked Sendable {
    private let lock = NSLock()
    private var rows: [String: [[JSONValue]]] = [:]
    private var told: (@Sendable () -> Void)?
    private var calls: [String] = []
    private var refusal: String?
    private var reachable = true
    private var broken = false

    init(rows: [String: [[JSONValue]]] = [:], reachable: Bool = true) {
        self.rows = rows
        self.reachable = reachable
    }

    private func locked<Value>(_ body: () -> Value) -> Value {
        lock.lock()
        defer { lock.unlock() }
        return body()
    }

    var world: LiveWorld { LiveWorld(snapshot: locked { rows }) }
    var asked: [String] { locked { calls } }

    /// Changes the rows held, and tells whoever watches.
    func change(_ edit: (inout [String: [[JSONValue]]]) -> Void) {
        let tell = locked { () -> (@Sendable () -> Void)? in
            edit(&rows)
            return told
        }
        tell?()
    }

    /// From here on everything asked is refused in these words; nil to
    /// agree again. Or fails as a line that has dropped.
    func refuse(_ words: String?) { locked { refusal = words } }
    func drop() { locked { broken = true } }

    func watch(changed: @escaping @Sendable () -> Void) async -> Bool {
        locked { told = changed }
        return reachable
    }

    func close() { locked { calls.append("close") } }

    private func take(_ call: String) throws {
        let (words, down) = locked { () -> (String?, Bool) in
            calls.append(call)
            return (refusal, broken)
        }
        if down { throw URLError(.notConnectedToInternet) }
        if let words { throw LiveRefusal(words: words) }
    }

    private func listed(_ soldiers: [(kind: Int, tier: Int, count: UInt64)]) -> String {
        soldiers.map { "\($0.count) of \($0.kind).\($0.tier)" }.joined(separator: ", ")
    }

    func join(name: String) async throws { try take("join \(name)") }
    func build(_ kind: Int) async throws { try take("build \(kind)") }
    func upgrade(building: UInt64) async throws { try take("upgrade \(building)") }
    func train(building: UInt64, tier: Int, count: UInt64) async throws { try take("train \(count) of tier \(tier) in \(building)") }
    func gather(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws { try take("gather at \(hex.q), \(hex.r) with \(listed(soldiers))") }
    func hunt(at hex: LiveHex, soldiers: [(kind: Int, tier: Int, count: UInt64)]) async throws { try take("hunt at \(hex.q), \(hex.r) with \(listed(soldiers))") }
    func heal(kind: Int, tier: Int, count: UInt64) async throws { try take("heal \(count) of \(kind).\(tier)") }
    func read(report: UInt64) async throws { try take("read \(report)") }
    func forget(report: UInt64) async throws { try take("forget \(report)") }
    func recall(march: UInt64) async throws { try take("recall \(march)") }
}

/// How many times something has been tried.
final class Tries: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func next() -> Int {
        lock.lock()
        defer { lock.unlock() }
        count += 1
        return count
    }
}

/// A player's session over a line: what it reads, the window it keeps
/// about where the player looks, what it stages, what is chosen, and what
/// it asks. The world is `LiveWindowTests`' own: Ada's city at 10, -4.
@MainActor
final class LiveSessionTests: XCTestCase {
    private func n(_ value: Int) -> JSONValue { .number(Double(value)) }
    private func n(_ value: UInt64) -> JSONValue { .number(Double(value)) }

    /// A session on the stand-in line at a moment of the realm's clock.
    private func session(_ line: StandInLine, at seconds: Double = 2_015) -> LiveSession {
        LiveSession(line: line) { seconds }
    }

    func testASessionOpensOnTheRealmAndAsksANameOfWhoHasNone() async throws {
        // A realm that can't be reached.
        let nowhere = session(StandInLine(reachable: false))
        XCTAssertEqual(nowhere.phase, .opening)
        await nowhere.open()
        XCTAssertEqual(nowhere.phase, .lost)
        XCTAssertNil(nowhere.window)

        // A door that won't open: the same, and asking says so; tried
        // again once it will, the session is in.
        let tries = Tries()
        let shut = LiveSession(opening: {
            guard tries.next() > 1 else { throw URLError(.cannotConnectToHost) }
            return StandInLine(rows: LiveWindowTests.rows())
        }, clock: { 2_015 })
        await shut.open()
        XCTAssertEqual(shut.phase, .lost)
        await shut.build(2)
        XCTAssertEqual(shut.said, LiveSession.unreached)
        shut.refresh()
        XCTAssertEqual(shut.phase, .lost)
        await shut.open()
        XCTAssertEqual(shut.phase, .playing)
        XCTAssertEqual(shut.world.me?.name, "Ada")

        // A realm whose rows have not come yet; then they come, and the
        // player has no city there: a name is wanted.
        var rows = LiveWindowTests.rows()
        let (me, city) = (rows.removeValue(forKey: "me"), rows.removeValue(forKey: "my_city"))
        rows["my_buildings"] = []
        let line = StandInLine()
        let session = session(line)
        await session.open()
        XCTAssertEqual(session.phase, .opening)
        XCTAssertNil(session.window, "nothing to draw of a realm not yet read")
        line.change { $0 = rows }
        session.refresh()
        XCTAssertEqual(session.phase, .naming)
        XCTAssertEqual(session.window?.centre, LiveHex(q: 0, r: 0), "the lake, until they have a city to look at")
        XCTAssertEqual(session.windowVersion, 1)

        // They join: the realm's rows bring their city, and the look goes to it.
        await session.join(name: "Ada")
        XCTAssertEqual(line.asked, ["join Ada"])
        line.change {
            $0["me"] = me
            $0["my_city"] = city
        }
        session.refresh()
        XCTAssertEqual(session.phase, .playing)
        XCTAssertEqual(session.look, LiveHex(q: 10, r: -4))
        XCTAssertEqual(session.window?.centre, LiveHex(q: 10, r: -4))
        XCTAssertEqual(session.window?.radius, LiveSession.reach)
        XCTAssertEqual(session.windowVersion, 2)
        XCTAssertEqual(session.world.me?.name, "Ada")
        XCTAssertNil(session.said)

        // What the line is told, the session is told: rows pushed reach it.
        line.change { $0["city"]?.append([self.n(9), self.n(3), self.n(LiveHex(q: 12, r: -6).packed), .string("Cato"), self.n(1), self.n(140), self.n(1_000), self.n(1)]) }
        for _ in 0..<50 where session.world.cities.count < 3 { try await Task.sleep(nanoseconds: 10_000_000) }
        XCTAssertEqual(session.world.cities.count, 3, "pushed, with no one asking")
        session.close()
        XCTAssertEqual(line.asked.last, "close")
    }

    func testTheWindowFollowsTheLookOnceItStrays() async throws {
        let line = StandInLine(rows: LiveWindowTests.rows())
        let session = session(line)
        await session.open()
        XCTAssertEqual(session.phase, .playing)
        XCTAssertEqual([session.windowVersion, session.standingVersion], [1, 1])
        let land = try XCTUnwrap(session.land())
        XCTAssertEqual(land.map.radius, LiveSession.reach)
        XCTAssertEqual(land.map[Hex(0, 0)]?.terrain, .greyfield)
        XCTAssertEqual(land.terrain.columns > 10, true)

        // A little way: the same window, the same land.
        session.look(at: LiveHex(q: 15, r: -4))
        XCTAssertEqual(session.look, LiveHex(q: 15, r: -4))
        XCTAssertEqual(session.window?.centre, LiveHex(q: 10, r: -4))
        XCTAssertEqual(session.windowVersion, 1)
        // Past eight hexes from its heart: another, about where they look.
        session.look(at: LiveHex(q: 19, r: -4))
        XCTAssertEqual(session.window?.centre, LiveHex(q: 19, r: -4))
        XCTAssertEqual([session.windowVersion, session.standingVersion], [2, 2])
        XCTAssertEqual(try XCTUnwrap(session.land()).map[Hex(0, 0)]?.terrain, .blackwood, "the wood east of the sixteenth column")
        session.look(at: LiveHex(q: 19, r: -4))
        XCTAssertEqual(session.windowVersion, 2, "looking where they look already changes nothing")

        // What stands in the window: a city founded in it is noted, one far off is not.
        line.change { $0["city"]?.append([self.n(9), self.n(3), self.n(LiveHex(q: 20, r: -6).packed), .string("Cato"), self.n(1), self.n(140), self.n(1_000), self.n(1)]) }
        session.refresh()
        XCTAssertEqual([session.windowVersion, session.standingVersion], [2, 3])
        line.change { $0["city"]?.append([self.n(10), self.n(4), self.n(LiveHex(q: -30, r: 0).packed), .string("Dara"), self.n(1), self.n(140), self.n(1_000), self.n(1)]) }
        session.refresh()
        XCTAssertEqual([session.windowVersion, session.standingVersion], [2, 3])
        // An army on the move changes nothing that stands.
        line.change { $0["march"]?.removeLast() }
        session.refresh()
        XCTAssertEqual([session.windowVersion, session.standingVersion], [2, 3])
    }

    func testARealmsAddressIsReadAndItsPlayerKept() async throws {
        let read = try XCTUnwrap(LiveDoor.address(" https://maincloud.spacetimedb.com/nullmere-online\n"))
        XCTAssertEqual(read.server.absoluteString, "https://maincloud.spacetimedb.com")
        XCTAssertEqual(read.database, "nullmere-online")
        let local = try XCTUnwrap(LiveDoor.address("http://127.0.0.1:3000/nullmere_check/"))
        XCTAssertEqual([local.server.absoluteString, local.database], ["http://127.0.0.1:3000", "nullmere_check"])
        for text in ["", "nullmere-online", "https://maincloud.spacetimedb.com", "https://maincloud.spacetimedb.com/", "ftp://example.com/realm",
                     "https://example.com/a/b", "https://example.com/a b", "https:///realm", "https://example.com/realm;drop"] {
            XCTAssertNil(LiveDoor.address(text), text)
        }

        // The player a store keeps is the player the door opens as.
        let file = FileManager.default.temporaryDirectory.appendingPathComponent("nullmere-door-\(UUID().uuidString)").appendingPathComponent("key")
        defer { try? FileManager.default.removeItem(at: file.deletingLastPathComponent()) }
        let store = FileIdentityStore(url: file)
        XCTAssertNil(LiveDoor.kept(in: store), "no one yet")
        let credentials = SpacetimeCredentials(identity: "c200ab", token: "a.token")
        try store.save(String(decoding: try JSONEncoder().encode(credentials), as: UTF8.self))
        XCTAssertEqual(LiveDoor.kept(in: store), credentials)
        let client = try await LiveDoor.open(server: local.server, database: local.database, keeping: store)
        XCTAssertEqual(client.credentials, credentials, "opened as the one kept, with no word to the server")
        try store.save("not a key")
        XCTAssertNil(LiveDoor.kept(in: store))
    }

    func testTheCameraKeepsItsPlaceAsTheWindowMoves() async throws {
        let line = StandInLine(rows: LiveWindowTests.rows())
        let session = session(line)
        await session.open()
        XCTAssertEqual([session.camera.centerX, session.camera.centerY], [0, 0], "opened on her city, at the window's heart")
        XCTAssertEqual(session.camera.scale, LiveSession.openingScale)

        // Panned four hexes east: the look follows, the window stays.
        var camera = session.camera
        camera.centerX = 4 * 3.0.squareRoot()
        session.moved(camera)
        XCTAssertEqual(session.look, LiveHex(q: 14, r: -4))
        XCTAssertEqual(session.windowVersion, 1)
        XCTAssertEqual(session.camera.centerX, 4 * 3.0.squareRoot(), accuracy: 1e-9)

        // Ten hexes east: the window is taken afresh about the look, and
        // the camera is at that window's heart: the same place in the world.
        camera.centerX = 10 * 3.0.squareRoot()
        session.moved(camera)
        XCTAssertEqual(session.look, LiveHex(q: 20, r: -4))
        XCTAssertEqual(session.window?.centre, LiveHex(q: 20, r: -4))
        XCTAssertEqual(session.windowVersion, 2)
        XCTAssertEqual(session.camera.centerX, 0, accuracy: 1e-9)
        XCTAssertEqual(session.camera.centerY, 0, accuracy: 1e-9)
        // A little south-east in the new window: no new window, the camera as it was put.
        camera = session.camera
        (camera.centerX, camera.centerY) = (3.0.squareRoot() / 2, 1.5)
        session.moved(camera)
        XCTAssertEqual(session.look, LiveHex(q: 20, r: -3))
        XCTAssertEqual(session.windowVersion, 2)
        XCTAssertEqual(session.camera.centerY, 1.5, accuracy: 1e-9)

        // Drawn back no further than keeps the window's rim out of sight.
        camera.scale = 5
        session.moved(camera)
        XCTAssertEqual(session.camera.scale, LiveSession.furthestScale)

        // Turned to a hex far off: a window about it, the camera on it.
        session.go(to: LiveHex(q: -20, r: 9))
        XCTAssertEqual(session.window?.centre, LiveHex(q: -20, r: 9))
        XCTAssertEqual([session.camera.centerX, session.camera.centerY], [0, 0])
        // And to one nearby: the same window, the camera moved over it.
        session.go(to: LiveHex(q: -18, r: 9))
        XCTAssertEqual(session.window?.centre, LiveHex(q: -20, r: 9))
        XCTAssertEqual(session.camera.centerX, 2 * 3.0.squareRoot(), accuracy: 1e-9)

        // A hex of the window chosen is a hex of the world.
        session.choose(local: Hex(3, -1))
        XCTAssertEqual(session.selected, LiveHex(q: -17, r: 8))
        XCTAssertEqual(session.selectedLocal, Hex(3, -1))
        session.go(to: LiveHex(q: 10, r: -4))
        XCTAssertNil(session.selectedLocal, "chosen still, but out of the window now")
        XCTAssertEqual(session.selected, LiveHex(q: -17, r: 8))
        session.choose(local: nil)
        XCTAssertNil(session.selected)
    }

    func testTheWindowIsStagedForTheRendererAtAMoment() async throws {
        let line = StandInLine(rows: LiveWindowTests.rows())
        let session = session(line)
        XCTAssertEqual(session.frame(time: 0).instanceCount, 0, "nothing before the realm is read")
        XCTAssertNil(session.tiles())
        await session.open()
        let frame = session.frame(time: 20)
        XCTAssertGreaterThan(frame.fixed.reduce(0) { $0 + $1.instances.count }, 100, "the land's own furniture")
        XCTAssertTrue(frame.batches.contains { if case .keep = $0.key { return true } else { return false } }, "a Keep")
        XCTAssertTrue(frame.batches.contains { $0.key == .figure(.rider, tier: 2) }, "Ada's riders on the road")
        XCTAssertTrue(frame.batches.contains { $0.key == .site(.timber) }, "the grove")
        XCTAssertTrue(frame.batches.contains { $0.key == .lair(.barrowkin) }, "the barrow")
        XCTAssertEqual(frame.fixedVersion, 100_001)
        // The next frame keeps the furniture as it is: the GPU is sent it once.
        let next = session.frame(time: 20.1)
        XCTAssertEqual(next.fixedVersion, frame.fixedVersion)
        XCTAssertEqual(next.fixed, frame.fixed)
        // A new window, new furniture.
        session.look(at: LiveHex(q: 19, r: -4))
        XCTAssertEqual(session.frame(time: 20.2).fixedVersion, 200_002)

        // The tiles: all of the window watched, a hold where each city stands.
        let tiles = try XCTUnwrap(session.tiles())
        let side = 2 * LiveSession.reach + 1
        XCTAssertEqual(tiles.count, side * side * 4)
        let cityAt = ((0 + LiveSession.reach) * side + (-9 + LiveSession.reach)) * 4
        XCTAssertEqual(tiles[cityAt + 1] & TileTexture.holdFlag, TileTexture.holdFlag, "Ada's city, nine hexes west of the window's heart")
        XCTAssertEqual(LiveSession.colours.count, 24)
        XCTAssertEqual(Set(LiveSession.colours.map { [$0.x, $0.y, $0.z] }).count, 24, "no two alike")
    }

    func testWhatLiesAtAHexIsChosen() async throws {
        let line = StandInLine(rows: LiveWindowTests.rows())
        let session = session(line)
        await session.open()
        XCTAssertNil(session.selection)

        guard case .home(let home) = session.selection(at: LiveHex(q: 10, r: -4)) else { return XCTFail("her own city") }
        XCTAssertEqual(home.id, 7)
        guard case .city(let other, let owner) = session.selection(at: LiveHex(q: 14, r: -4)) else { return XCTFail("another's city") }
        XCTAssertEqual([String(other.id), owner], ["8", "Bryn"])
        guard case .site(let site) = session.selection(at: LiveHex(q: 12, r: -2)) else { return XCTFail("the grove, though an army works it") }
        XCTAssertEqual(site.kind, 2)
        guard case .barrow(let barrow) = session.selection(at: LiveHex(q: 8, r: -2)) else { return XCTFail("the barrow, though an army fights there") }
        XCTAssertEqual(barrow.level, 2)
        // Ada's army, fifteen seconds along: between 11, -3 and 11, -2, nearer neither; a second on, past the middle.
        let later = self.session(line, at: 2_017)
        await later.open()
        guard case .army(let march, let own) = later.selection(at: LiveHex(q: 11, r: -2)) else { return XCTFail("her army on the road") }
        XCTAssertEqual(march.id, 3)
        XCTAssertTrue(own)
        guard case .land(let hex, let ground) = session.selection(at: LiveHex(q: 5, r: 5)) else { return XCTFail("bare land") }
        XCTAssertEqual([hex.q, hex.r], [5, 5])
        XCTAssertEqual(ground, 4)
        guard case .land(_, let unknown) = session.selection(at: LiveHex(q: 500, r: 0)) else { return XCTFail("land never told") }
        XCTAssertNil(unknown)

        session.selected = LiveHex(q: 12, r: -2)
        XCTAssertEqual(session.selection, .site(site))
        XCTAssertEqual(session.everyoneReady.count, 0, "no one stands ready in these rows")
    }

    func testWhatIsChosenIsToldOnACardWithWhatCanBeDone() async throws {
        var rows = LiveWindowTests.rows()
        rows["my_troops"] = [[n(7 << 16 | 1 << 8 | 1), n(7), n(1), n(1), n(40), n(0)]]
        rows["my_hunt"] = [[n(1), n(1_000), n(2_000), n(1_000), n(8_000), n(1)]]
        rows["blueprint"] = [[n(2 << 32 | 1), n(2), n(1), .string("Farm"), n(0), n(100), n(0), n(0), n(10), n(0), n(0), n(0), n(0), n(1), n(0), n(0), n(20)]]
        rows["my_jobs"] = [[n(4), n(7), n(1), n(22), n(3), n(0), n(2_000), n(2_100), n(9)]]
        // A second barrow no one is at, of the fourth level; a second site no one works.
        rows["barrow"]?.append([n(10), n(LiveHex(q: 6, r: -1).packed), n(4), n(0)])
        rows["place"]?.append([n(LiveHex(q: 6, r: -1).packed), n(3), n(10)])
        rows["barrow"]?.append([n(11), n(LiveHex(q: 6, r: 0).packed), n(2), n(0)])
        rows["place"]?.append([n(LiveHex(q: 6, r: 0).packed), n(3), n(11)])
        rows["site"]?.append([n(6), n(LiveHex(q: 7, r: 1).packed), n(1), n(2), n(40_000), n(0)])
        rows["place"]?.append([n(LiveHex(q: 7, r: 1).packed), n(2), n(6)])
        let line = StandInLine(rows: rows)
        let session = session(line)
        await session.open()
        func card(_ q: Int, _ r: Int) -> LiveCard { session.card(for: session.selection(at: LiveHex(q: q, r: r))) }

        // Her city: what it is, what it is raising, and its two doors.
        let home = card(10, -4)
        XCTAssertEqual(home.title, "Ada")
        XCTAssertEqual(home.lines, ["Your city. Keep level 3, power 1,000.", "Farm to level 3: 1:25"])
        XCTAssertEqual(home.buttons.map(\.title), ["Buildings", "Troops"])
        XCTAssertEqual(home.buttons.map(\.act), [.city, .troops])
        // Another's: whose, and that they are here.
        XCTAssertEqual(card(14, -4), LiveCard(title: "Bryn", lines: ["Bryn's city. Keep level 8, power 9,000. They are here now."], buttons: []))

        // Ada has one army out and a Keep of the third level: no second
        // army may go, wherever it is sent.
        let oneOut = "Your one army is out. Raise your Keep to send more."
        XCTAssertEqual(card(7, 1), LiveCard(title: "Grain, level 2", lines: ["40,000 left to gather."],
                                            buttons: [.init(title: "Gather with 40 soldiers", act: .send, why: oneOut)]))
        // The grove Bryn's army works; the barrow his other army fights at.
        let grove = card(12, -2)
        XCTAssertEqual(grove.title, "Timber, level 4")
        XCTAssertEqual(grove.lines, ["80,000 left to gather.", "Another army is gathering here."])
        XCTAssertEqual(grove.buttons.first?.why, "Another army is gathering there.")
        let fought = card(8, -2)
        XCTAssertEqual(fought.title, "Barrow, level 2")
        XCTAssertEqual(fought.lines, ["The Unquiet hold it. An attack takes 50 energy.", "Another army is fighting here."])
        XCTAssertEqual(fought.buttons.first?.why, "Another army is fighting there.")
        // A barrow two levels above the one she has cleared.
        XCTAssertEqual(card(6, -1).buttons.first?.why, "Clear a level 3 barrow first.")
        XCTAssertEqual(card(6, 0).buttons.first, .init(title: "Attack with 40 soldiers", act: .send, why: oneOut))

        // With her army home, both may be sent for; pressed, everyone ready goes.
        line.change { $0["march"]?.removeFirst() }
        session.refresh()
        XCTAssertNil(card(7, 1).buttons.first?.why)
        XCTAssertNil(card(6, 0).buttons.first?.why)
        session.selected = LiveHex(q: 6, r: 0)
        await session.press(card(6, 0).buttons[0])
        XCTAssertEqual(line.asked, ["hunt at 6, 0 with 40 of 1.1"])
        session.selected = LiveHex(q: 7, r: 1)
        await session.press(card(7, 1).buttons[0])
        XCTAssertEqual(line.asked.last, "gather at 7, 1 with 40 of 1.1")
        // A button that can't be pressed says why, and asks nothing.
        await session.press(card(6, -1).buttons[0])
        XCTAssertEqual(session.said, "Clear a level 3 barrow first.")
        XCTAssertEqual(line.asked.count, 2)
        // Too little energy; and no one ready.
        line.change { $0["my_hunt"] = [[self.n(1), self.n(30), self.n(2_015), self.n(1_000), self.n(8_000), self.n(1)]] }
        session.refresh()
        XCTAssertEqual(card(6, 0).buttons.first?.why, "An attack takes 50 energy. You have 30.")
        line.change { $0["my_troops"] = [] }
        session.refresh()
        XCTAssertEqual(card(7, 1).buttons.first, .init(title: "Gather", act: .send, why: "No soldiers stand ready in your city."))

        // Bare land by its ground; land never told.
        XCTAssertEqual(card(5, 5), LiveCard(title: "Plain", lines: [], buttons: []))
        XCTAssertEqual(card(20, -4).title, "Wood")
        XCTAssertEqual(card(-12, 0).title, "Deep water")
        XCTAssertEqual(card(500, 0).title, "Unknown land")
    }

    func testAnArmyChosenIsToldAndCanBeCalledHome() async throws {
        let line = StandInLine(rows: LiveWindowTests.rows())
        // Seventeen seconds along its way of twenty-four: on 11, -2.
        let session = session(line, at: 2_017)
        await session.open()
        let hers = session.card(for: session.selection(at: LiveHex(q: 11, r: -2)))
        XCTAssertEqual(hers.title, "Your army")
        XCTAssertEqual(hers.lines, ["On its way to gather timber: 0:07", "40 soldiers."])
        XCTAssertEqual(hers.buttons, [.init(title: "Call home", act: .recall(3), why: nil)])
        await session.press(hers.buttons[0])
        XCTAssertEqual(line.asked, ["recall 3"])

        // Another's army is told by whose it is and how many march.
        guard let bryns = session.world.marches[4] else { return XCTFail("Bryn's army") }
        XCTAssertEqual(session.card(for: .army(bryns, own: false)), LiveCard(title: "Bryn's army", lines: ["90 soldiers"], buttons: []))
        // Her own in a fight can't be called away, and the card says why.
        guard let fighting = session.world.marches[6] else { return XCTFail("the army at the barrow") }
        line.change { rows in
            rows["march"] = rows["march"]?.map { row in
                var row = row
                if row[0] == .number(6) { row[1] = .number(1) }
                return row
            }
        }
        session.refresh()
        let own = session.card(for: .army(session.world.marches[6] ?? fighting, own: true))
        XCTAssertEqual(own.lines.first, "Fighting at a level 2 barrow: 0:08")
        XCTAssertEqual(own.buttons, [.init(title: "Call home", act: .recall(6), why: "That army is fighting. Wait for the fight to end.")])
    }

    func testWhatIsAskedGoesToTheRealmAndItsRefusalIsKept() async throws {
        var rows = LiveWindowTests.rows()
        rows["my_troops"] = [[n(7 << 16 | 1 << 8 | 1), n(7), n(1), n(1), n(40), n(0)], [n(7 << 16 | 3 << 8 | 2), n(7), n(3), n(2), n(12), n(5)],
                             [n(7 << 16 | 2 << 8 | 1), n(7), n(2), n(1), n(0), n(9)]]
        let line = StandInLine(rows: rows)
        let session = session(line)
        await session.open()
        XCTAssertEqual(session.everyoneReady.map { [$0.kind, $0.tier, Int($0.count)] }, [[1, 1, 40], [3, 2, 12]], "those ready, never the wounded")

        await session.build(2)
        await session.upgrade(building: 21)
        await session.train(building: 24, tier: 1, count: 50)
        await session.heal(kind: 3, tier: 2, count: 5)
        await session.recall(march: 3)
        await session.read(report: 31)
        await session.forget(report: 31)
        // An army is sent for what lies where it is sent: to gather at a
        // site, to fight at a barrow, and nowhere else.
        await session.send(session.everyoneReady, to: LiveHex(q: 12, r: -2))
        await session.send([(kind: 1, tier: 1, count: 30)], to: LiveHex(q: 8, r: -2))
        XCTAssertEqual(line.asked, ["build 2", "upgrade 21", "train 50 of tier 1 in 24", "heal 5 of 3.2", "recall 3", "read 31", "forget 31",
                                    "gather at 12, -2 with 40 of 1.1, 12 of 3.2", "hunt at 8, -2 with 30 of 1.1"])
        XCTAssertNil(session.said)
        XCTAssertEqual(session.asking, 0)
        await session.send([(kind: 1, tier: 1, count: 30)], to: LiveHex(q: 5, r: 5))
        XCTAssertEqual(session.said, "There is nothing to send an army for there.")
        XCTAssertEqual(line.asked.count, 9, "and the realm is not troubled with it")

        // The realm's refusal is kept in its own words until put away.
        session.said = nil
        line.refuse("Your builders are busy. Wait for them to finish.")
        await session.build(4)
        XCTAssertEqual(session.said, "Your builders are busy. Wait for them to finish.")
        session.said = nil
        line.refuse(nil)
        await session.build(4)
        XCTAssertNil(session.said)
        // A line that drops says so plainly.
        line.drop()
        await session.build(4)
        XCTAssertEqual(session.said, "The realm could not be reached. Try again in a moment.")
        XCTAssertEqual(session.asking, 0)
    }
}
