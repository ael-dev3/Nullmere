import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// What the server says of a keeper's view, bent as a test needs: a row
/// that can't be read, a view never shown, or the realm in a new age.
actor ViewTamper {
    var malformed = false
    var newAge = false

    func set(malformed: Bool = false, newAge: Bool = false) {
        self.malformed = malformed
        self.newAge = newAge
    }

    func bend(_ rows: [[JSONValue]]) throws -> [[JSONValue]] {
        if malformed { return [[.string("keeper"), .string("not a version")]] }
        guard newAge, let row = rows.first, row.count == 4, let number = row[1].number, let text = row[2].string else { return rows }
        let view = try JSONDecoder().decode(RealmView.self, from: Data(text.utf8))
        let aged = RealmView(keeper: view.keeper, age: view.age + 1, world: view.world)
        return [[row[0], .number(number + 1_000), .string(String(decoding: try JSONEncoder().encode(aged), as: UTF8.self)), row[3]]]
    }
}

struct TamperedSpacetime: SpacetimeTransport {
    let inner: FakeSpacetime
    let tamper: ViewTamper

    func createIdentity() async throws -> SpacetimeCredentials { try await inner.createIdentity() }

    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws {
        try await inner.call(reducer, arguments, token: token)
    }

    func query(_ sql: String, token: String) async throws -> [[JSONValue]] {
        let rows = try await inner.query(sql, token: token)
        return sql == "SELECT * FROM my_view" ? try await tamper.bend(rows) : rows
    }

    func queryDated(_ sql: String, token: String) async throws -> (rows: [[JSONValue]], date: Date?) {
        (try await query(sql, token: token), try await inner.queryDated(sql, token: token).date)
    }
}

/// The keeper's view as the link reads it: a row it can't read is passed
/// over, a realm that takes a keeper in but never shows them the world is
/// said so, a new age is a new arrival, and an order kept through an
/// outage is carried once the realm answers again.
@MainActor
final class LinkViewTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 20, _ condition: () async -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !(await condition()) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    private func realm(_ seed: String) async throws -> (FakeSpacetime, ViewTamper, NetworkRealmLink, Listener, Task<Void, Never>) {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: seed,
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        let tamper = ViewTamper()
        let link = NetworkRealmLink(transport: TamperedSpacetime(inner: db, tamper: tamper), credentials: MemoryStore(),
                                    pollInterval: 0.05, retryDelay: 0.05)
        let ear = Listener()
        ear.listen(to: link)
        return (db, tamper, link, ear, running)
    }

    private func arrivals(_ ear: Listener) -> Int {
        ear.events.filter { if case .arrived = $0 { return true } else { return false } }.count
    }

    func testAViewThatCantBeReadIsNeverShown() async throws {
        let (_, tamper, link, ear, running) = try await realm("a view unread")
        defer { running.cancel(); link.leave() }
        await tamper.set(malformed: true)
        link.arrive(name: "Ama")
        try await until("the refusal") { !ear.refusals.isEmpty }
        XCTAssertEqual(ear.refusals.first, "The realm took you in, but hasn't shown you the world yet. Try again.")
        XCTAssertNil(ear.keeper)

        // Once the view can be read, the keeper comes in.
        await tamper.set()
        link.arrive(name: nil)
        try await until("arrival") { ear.keeper != nil }
    }

    func testAnUnreadableViewInPlayIsPassedOver() async throws {
        let (_, tamper, link, ear, running) = try await realm("a view passed over")
        defer { running.cancel(); link.leave() }
        link.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        let world = try XCTUnwrap(ear.world)
        await tamper.set(malformed: true)
        link.connect()
        let reads = link.viewReads
        try await until("the view to be read again") { link.viewReads > reads }
        XCTAssertEqual(ear.world, world, "Nothing unreadable is taken for the world")
        XCTAssertFalse(ear.events.contains { if case .unreachable = $0 { return true } else { return false } })
    }

    /// What a keeper heard is carried with their view a while; the link
    /// tells it once, though their own next order brings the view again.
    func testWhatIsHeardIsToldOnce() async throws {
        let (db, _, link, ear, running) = try await realm("told once")
        defer { running.cancel(); link.leave() }
        link.connect()
        link.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        let ama = try XCTUnwrap(ear.keeper?.house)
        let bel = try await db.createIdentity()
        try await db.call("arrive", [.string("b1"), .string("Bel")], token: bel.token)
        let gift = Command.gift(to: ama, resource: .grain, amount: 5)
        try await db.call("order", [.string("b2"), .string(String(decoding: try JSONEncoder().encode(gift), as: UTF8.self))], token: bel.token)
        func gifts() -> Int {
            ear.events.reduce(0) { count, event in
                switch event {
                case .heard(let events), .watchTurned(_, let events), .answered(let events):
                    return count + events.filter { if case .gifted = $0 { return true } else { return false } }.count
                default: return count
                }
            }
        }
        try await until("the gift heard") { gifts() == 1 }
        // Her own order: the realm shows her view again, the gift with it.
        let world = try XCTUnwrap(ear.world)
        let spear = try XCTUnwrap(world.units(of: ama).first { $0.kind == .spear })
        let answered = ear.events.count
        link.send(.fortify(unit: spear.id))
        try await until("the order answered") {
            ear.events.dropFirst(answered).contains { if case .answered = $0 { return true } else { return false } }
        }
        // However often the realm is read after.
        try await db.waitFor(6, more: FakeSpacetime.statusPoll, by: try XCTUnwrap(link.credentials?.token))
        XCTAssertEqual(gifts(), 1, "Told once")
    }

    /// Left while an order's answer is on its way: the link drops the
    /// errand rather than tripping over it.
    func testALinkLeftWithAnAnswerOnItsWayDropsTheErrand() async throws {
        let (db, _, link, ear, running) = try await realm("left mid-answer")
        defer { running.cancel() }
        link.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })
        for _ in 0..<5 {
            link.send(.fortify(unit: spear.id))
            try await Task.sleep(nanoseconds: 30_000_000)
            link.leave()
            XCTAssertEqual(link.waiting, 0)
        }
        // The answers come, to no one: the steward's rounds go by.
        try await db.waitFor(6, more: FakeSpacetime.stewardRound)
        XCTAssertEqual(link.waiting, 0)
    }

    func testANewAgeIsANewArrival() async throws {
        let (_, tamper, link, ear, running) = try await realm("a new age")
        defer { running.cancel(); link.leave() }
        link.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })

        await tamper.set(newAge: true)
        link.send(.fortify(unit: spear.id))
        try await until("the new age") { self.arrivals(ear) == 2 }
    }

    func testAnOrderKeptThroughAnOutageIsCarried() async throws {
        let (db, _, link, ear, running) = try await realm("an outage")
        defer { running.cancel(); link.leave() }
        link.arrive(name: "Ama")
        try await until("arrival") { ear.keeper != nil }
        let world = try XCTUnwrap(ear.world)
        let house = try XCTUnwrap(world.houses.first { $0.title == "House Ama" }?.id)
        let spear = try XCTUnwrap(world.units(of: house).first { $0.kind == .spear })

        await db.setReachable(false)
        link.send(.fortify(unit: spear.id))
        try await until("the realm out of reach") {
            ear.events.contains { if case .unreachable = $0 { return true } else { return false } }
        }
        XCTAssertEqual(link.waiting, 1, "Kept, not lost")
        await db.setReachable(true)
        try await until("the order carried") { await db.handled(kind: "order") == 1 }
        try await until("the outbox empty") { link.waiting == 0 }
        try await until("the answer") { ear.events.contains { if case .answered = $0 { return true } else { return false } } }
    }
}
