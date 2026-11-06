import Foundation
@testable import NullmereRealm
import NullmereTestSupport
import XCTest

/// The realm's word pushed as it happens: SpacetimeDB's subscription
/// protocol, a WebSocket of our own where the system has none, and the
/// link reading at once what it is told has changed.
final class RealmWatchTests: XCTestCase {
    func testTheSubscriptionIsAskedAndHeardAsSpacetimeDBSaysIt() throws {
        let subscribe = SpacetimeSubscription.subscribe(["SELECT * FROM status"])
        let object = try XCTUnwrap(try JSONSerialization.jsonObject(with: Data(subscribe.utf8)) as? [String: Any])
        let body = try XCTUnwrap(object["Subscribe"] as? [String: Any])
        XCTAssertEqual(body["query_strings"] as? [String], ["SELECT * FROM status"])
        XCTAssertEqual(body["request_id"] as? Int, 1)
        for kind in ["InitialSubscription", "TransactionUpdate", "TransactionUpdateLight", "SubscribeApplied", "SubscribeMultiApplied"] {
            XCTAssertEqual(SpacetimeSubscription.heard("{\"\(kind)\": {}}"), .changed, kind)
        }
        XCTAssertEqual(SpacetimeSubscription.heard("{\"IdentityToken\": {\"token\": \"x\"}}"), .other)
        XCTAssertEqual(SpacetimeSubscription.heard("not json"), .other)
        XCTAssertEqual(SpacetimeSubscription.heard("{\"SubscriptionError\": {\"error\": \"no such table\"}}"), .refused("no such table"))
        XCTAssertEqual(SpacetimeSubscription.heard("{\"SubscriptionError\": {}}"), .refused("The realm refused the subscription."))
        XCTAssertEqual(SpacetimeSubscription.address(server: URL(string: "http://127.0.0.1:3000")!, database: "nullmere")?.absoluteString,
                       "ws://127.0.0.1:3000/v1/database/nullmere/subscribe?compression=None")
        XCTAssertEqual(SpacetimeSubscription.address(server: URL(string: "https://maincloud.spacetimedb.com")!, database: "nullmere")?.scheme,
                       "wss")
        XCTAssertNil(SpacetimeSubscription.address(server: URL(string: "ftp://x")!, database: "y"))
    }

    func testFramesGoOutMaskedAndComeBackWhole() throws {
        for count in [0, 5, 125, 126, 300, 70_000] {
            let payload = (0..<count).map { UInt8(truncatingIfNeeded: $0 * 7) }
            let frame = PlainWebSocket.frame(opcode: 0x1, payload: payload, mask: [9, 8, 7, 6])
            XCTAssertEqual(frame[0], 0x81)
            XCTAssertNotEqual(frame[1] & 0x80, 0, "a client's frames are masked")
            let parsed = try XCTUnwrap(try PlainWebSocket.parse(frame))
            XCTAssertEqual(parsed.payload, payload, "\(count) bytes")
            XCTAssertEqual(parsed.length, frame.count)
            XCTAssertTrue(parsed.final)
            XCTAssertNil(try PlainWebSocket.parse(Array(frame.dropLast())), "a frame half here waits")
        }
        XCTAssertNil(try PlainWebSocket.parse([0x81]))
        XCTAssertThrowsError(try PlainWebSocket.parse([0x81, 127, 0xFF, 0, 0, 0, 0, 0, 0, 0]))
        XCTAssertEqual(PlainWebSocket.headEnd(Array("HTTP/1.1 101 OK\r\nA: b\r\n\r\nrest".utf8)), 21)
        XCTAssertNil(PlainWebSocket.headEnd(Array("HTTP/1.1".utf8)))
    }

    func testAPlainWebSocketTalksToItsServer() throws {
        let server = try WebSocketServer(replies: ["{\"IdentityToken\": {}}", "{\"InitialSubscription\": {}}"], closesAfter: true)
        defer { server.stop() }
        let socket = try PlainWebSocket.open(server.url, protocols: ["v1.json.spacetimedb"], headers: ["Authorization": "Bearer key"])
        try socket.send(text: "hello")
        XCTAssertEqual(try socket.receive(), "{\"IdentityToken\": {}}", "the ping answered on the way")
        XCTAssertEqual(try socket.receive(), "{\"InitialSubscription\": {}}")
        XCTAssertNil(try socket.receive(), "closed by the server")
        XCTAssertThrowsError(try socket.send(text: "after"))
        XCTAssertTrue(server.head.contains("Authorization: Bearer key"))
        XCTAssertTrue(server.head.contains("Sec-WebSocket-Protocol: v1.json.spacetimedb"))
        XCTAssertTrue(server.head.hasPrefix("GET /v1/database/realm/subscribe?compression=None HTTP/1.1"))
        XCTAssertEqual(server.heard.first, "hello")
        XCTAssertThrowsError(try PlainWebSocket.open(URL(string: "wss://127.0.0.1:1/x")!, protocols: [], headers: [:]))
        XCTAssertThrowsError(try PlainWebSocket.open(URL(string: "ws://127.0.0.1:1/x")!, protocols: [], headers: [:], timeout: 1))
    }

    func testARefusedHandshakeAndAClosedSocketAreToldApart() throws {
        let refusing = try WebSocketServer(replies: [], refusal: "HTTP/1.1 401 Unauthorized")
        defer { refusing.stop() }
        XCTAssertThrowsError(try PlainWebSocket.open(refusing.url, protocols: [], headers: [:])) { error in
            XCTAssertEqual(error as? PlainWebSocket.Failure, .refused("HTTP/1.1 401 Unauthorized"))
        }
        // Closed from this side while waiting: the wait ends with nothing.
        let quiet = try WebSocketServer(replies: [])
        defer { quiet.stop() }
        let socket = try PlainWebSocket.open(quiet.url, protocols: [], headers: [:])
        try socket.send(text: "hello")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.3) { socket.close() }
        XCTAssertNil(try socket.receive())
        socket.close()
    }

    /// Closed from this side while a send waits on a peer that has stopped
    /// reading (a line gone quiet, as a realm's can at a client's end): the
    /// close is not held up by the send, and the send that waited ends. A
    /// close that waited on it would hold whoever closed, the main actor
    /// among them, as long as the peer kept still.
    func testClosingIsNotHeldUpByASendThatWaits() throws {
        let deaf = try WebSocketServer(replies: [], deaf: true)
        defer { deaf.stop() }
        let socket = try PlainWebSocket.open(deaf.url, protocols: [], headers: [:])
        try socket.send(text: "hello")
        let ended = DispatchSemaphore(value: 0)
        let sent = SentCount()
        let big = String(repeating: "x", count: 60_000)
        let sender = Thread {
            // Until the line is full and the send waits, then until it ends.
            while (try? socket.send(text: big)) != nil { sent.add() }
            ended.signal()
        }
        sender.start()
        // Until the sends have stopped going out: the line full, one waiting.
        var last = -1
        for _ in 0..<100 where sent.value != last || last <= 0 {
            last = sent.value
            Thread.sleep(forTimeInterval: 0.3)
        }
        XCTAssertGreaterThan(sent.value, 0)
        let closed = DispatchSemaphore(value: 0)
        DispatchQueue.global().async {
            socket.close()
            closed.signal()
        }
        let closing = closed.wait(timeout: .now() + 3)
        XCTAssertEqual(closing, .success, "Closing is not held up by the send")
        XCTAssertEqual(ended.wait(timeout: .now() + 3), .success, "and the send that waited ends")
        // (Were the close held up, a send now would wait on it too.)
        if closing == .success {
            XCTAssertThrowsError(try socket.send(text: "after"), "Nothing goes out once closed")
        }
    }

    func testAWatchTellsOfEachChangeAndKnowsWhenTheLineDrops() throws {
        let server = try WebSocketServer(replies: ["{\"IdentityToken\": {}}", "{\"InitialSubscription\": {}}", "{\"TransactionUpdate\": {}}"],
                                         closesAfter: true)
        defer { server.stop() }
        let told = expectation(description: "told twice")
        told.expectedFulfillmentCount = 2
        let watch = SpacetimeWatch(address: server.url, token: "key", queries: ["SELECT * FROM status"]) { told.fulfill() }
        watch.start()
        wait(for: [told], timeout: 10)
        let deadline = Date().addingTimeInterval(5)
        while watch.isAlive, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        XCTAssertFalse(watch.isAlive, "the server closed: the word has stopped")
        watch.stop()
        XCTAssertTrue(server.heard.first?.contains("SELECT * FROM status") ?? false, "it asked for the status")
    }

    /// The watch keeps the rows its subscription is told, in the order it
    /// is told them, and once the line drops they stand for nothing.
    func testAWatchKeepsTheRowsItIsToldUntilTheLineDrops() throws {
        let first = #"{"InitialSubscription":{"database_update":{"tables":[{"table_id":1,"table_name":"status","num_rows":1,"#
            + #""updates":[{"deletes":[],"inserts":["{\"id\":0,\"version\":7,\"status\":\"{}\"}"]}]}]},"request_id":1}}"#
        let then = #"{"TransactionUpdateLight":{"request_id":0,"update":{"tables":[{"table_id":1,"table_name":"status","num_rows":2,"#
            + #""updates":[{"deletes":["[0,7,\"{}\"]"],"inserts":["[0,8,\"{}\"]"]}]}]}}}"#
        let server = try WebSocketServer(replies: ["{\"IdentityToken\": {}}", first, then], closesAfter: true)
        defer { server.stop() }
        let told = expectation(description: "told twice")
        told.expectedFulfillmentCount = 2
        let watch = SpacetimeWatch(address: server.url, token: "key", queries: SubscriptionMirror.realmQueries) { told.fulfill() }
        watch.start()
        wait(for: [told], timeout: 10)
        XCTAssertEqual(watch.mirror?.rows(of: "status"), [[.number(0), .number(8), .string("{}")]])
        let deadline = Date().addingTimeInterval(5)
        while watch.mirror?.isLive == true, Date() < deadline { Thread.sleep(forTimeInterval: 0.02) }
        XCTAssertEqual(watch.mirror?.isLive, false, "the server closed: the rows are no longer its")
        watch.stop()
        XCTAssertTrue(server.heard.first?.contains("SELECT * FROM my_view_parts") ?? false, "it asked for every table the keeper reads")
    }

    #if canImport(Darwin)
    /// On a Mac, a realm over TLS is heard through the system's WebSockets:
    /// the same subscription, the same word.
    func testTheSystemsWebSocketsHearTheRealmToo() throws {
        let server = try WebSocketServer(replies: ["{\"IdentityToken\": {}}", "{\"TransactionUpdate\": {}}"], closesAfter: true)
        defer { server.stop() }
        let told = expectation(description: "told")
        let watch = SpacetimeWatch(address: server.url, token: "key", queries: ["SELECT * FROM status"], throughTheSystem: true) {
            told.fulfill()
        }
        watch.start()
        wait(for: [told], timeout: 10)
        watch.stop()
        XCTAssertTrue(server.head.contains("Bearer key"))
    }
    #endif

    func testARefusedSubscriptionIsNotKeptAlive() throws {
        let server = try WebSocketServer(replies: ["{\"SubscriptionError\": {\"error\": \"no\"}}"])
        defer { server.stop() }
        let watch = SpacetimeWatch(address: server.url, token: "key", queries: ["SELECT * FROM nothing"]) { XCTFail("nothing changed") }
        watch.start()
        let deadline = Date().addingTimeInterval(5)
        while server.heard.isEmpty, Date() < deadline { Thread.sleep(forTimeInterval: 0.05) }
        Thread.sleep(forTimeInterval: 0.5)
        XCTAssertFalse(watch.isAlive)
        watch.stop()
        // Nothing answers at all: no word, and none pretended.
        let nowhere = SpacetimeWatch(address: URL(string: "ws://127.0.0.1:9/x")!, token: "key", queries: []) {}
        nowhere.start()
        Thread.sleep(forTimeInterval: 0.3)
        XCTAssertFalse(nowhere.isAlive)
        nowhere.stop()
    }

    func testTheHTTPTransportWatchesOverItsOwnSocket() async throws {
        let transport = try XCTUnwrap(SpacetimeHTTP(address: URL(string: "http://127.0.0.1:9/realm")!))
        let watch = await transport.watch(["SELECT * FROM status"], token: "key") {}
        XCTAssertNotNil(watch, "a plain realm is watched")
        XCTAssertEqual(watch?.isAlive, false, "not yet: nothing answers there")
        watch?.stop()
        let ftp = SpacetimeHTTP(server: URL(string: "ftp://127.0.0.1")!, database: "x")
        let none = await ftp.watch([], token: "key") {}
        XCTAssertNil(none)
    }

    private func until(_ what: String, timeout: Double = 15, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !condition() {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// A keeper whose link would read the realm only once a minute on its
    /// own hears another's arrival at once: the realm pushed word of it.
    func testTheLinkReadsAtOnceWhatThePushTellsItOf() async throws {
        let db = FakeSpacetime()
        await db.setPushing(true)
        let credentials = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: credentials.token, name: "The Nullmere", seed: "pushed", seats: 4,
                                             watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        defer { running.cancel() }
        let (ama, bel, earB) = await MainActor.run { () -> (NetworkRealmLink, NetworkRealmLink, Listener) in
            let ama = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
            let bel = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 60)
            let earB = Listener()
            earB.listen(to: bel)
            ama.connect()
            bel.connect()
            return (ama, bel, earB)
        }
        try await until("Bel to hear the realm's status") { await MainActor.run { earB.hasStatus } }
        try await until("the realm watched") { await db.watching == 2 }
        let told = await MainActor.run { earB.events.count }
        await MainActor.run { ama.arrive(name: "Ama") }
        try await until("Bel to hear of Ama's arrival at once") { await MainActor.run { earB.events.count > told } }
        let pushes = await MainActor.run { bel.pushes }
        XCTAssertGreaterThan(pushes, 0)
        // Word pushed while the link is reading is read straight after.
        let heardDuringARead = await MainActor.run { () -> Int in
            var once = false
            earB.listen(to: bel)
            let listen = bel.onEvent
            bel.onEvent = { event in
                listen?(event)
                if !once {
                    once = true
                    bel.pushed()
                }
            }
            return earB.events.count
        }
        let kept = await MainActor.run { bel.credentials?.token }
        let belsToken = try XCTUnwrap(kept)
        let readsBefore = await db.queried(FakeSpacetime.statusPoll, by: belsToken)
        await MainActor.run { ama.setReady(true) }
        try await until("Bel to hear Ama ready") { await MainActor.run { earB.events.count > heardDuringARead } }
        try await until("Bel to read again straight after", timeout: 5) {
            await db.queried(FakeSpacetime.statusPoll, by: belsToken) >= readsBefore + 2
        }
        let next = await MainActor.run { bel.nextPoll }
        XCTAssertEqual(next, 60, "while the word comes, the link's own reads stay as far apart as asked")
        await MainActor.run {
            ama.close()
            bel.close()
        }
        try await until("the watches stopped") { await db.watching == 0 }
    }
}

/// How many frames a sender has put on the line.
private final class SentCount: @unchecked Sendable {
    private let lock = NSLock()
    private var count = 0

    func add() {
        lock.lock()
        count += 1
        lock.unlock()
    }

    var value: Int {
        lock.lock()
        defer { lock.unlock() }
        return count
    }
}
