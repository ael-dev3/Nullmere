import Foundation
import NullmereCore
import NullmereTestSupport
import XCTest
@testable import NullmereRealm

/// Realms meeting at the Frontier through their stewards alone: each reads
/// the others' status as any keeper may. A home realm hears the Frontier
/// and lists its keepers crossing; the Frontier seats only those listed,
/// for their realm's kingdom; and the season's end is told home.
final class FrontierStewardTests: XCTestCase {
    private func order(_ command: Command) throws -> ReducerArgument {
        .string(String(decoding: try JSONEncoder().encode(command), as: UTF8.self))
    }

    func testKeepersCrossFromTheirRealmsMeetThereAndAreToldHomeOfTheSeason() async throws {
        let west = FakeSpacetime(), east = FakeSpacetime(), lost = FakeSpacetime()
        let westKey = try await west.createIdentity(), eastKey = try await east.createIdentity(), lostKey = try await lost.createIdentity()
        let ilsen = try await west.createIdentity(), orla = try await east.createIdentity(), stranger = try await lost.createIdentity()
        // One server: every identity is known to every database on it.
        for db in [west, east, lost] {
            for key in [westKey, eastKey, lostKey, ilsen, orla, stranger] { await db.remember(key) }
        }
        let home = try await RealmSteward(transport: west, token: westKey.token, name: "The Nullmere", seed: "west", seats: 4,
                                          watchLength: 600, now: 0)
        let away = try await RealmSteward(transport: east, token: eastKey.token, name: "The Farmere", seed: "east", seats: 4,
                                          watchLength: 600, now: 0)
        let frontier = try await RealmSteward(transport: lost, token: lostKey.token, name: "The Lost Shore", seed: "lost", seats: 4,
                                              watchLength: 600, frontier: true, now: 0)
        await home.border(lost, at: "http://server/lost")
        await away.border(lost, at: "http://server/lost")
        await frontier.border(west, at: "http://server/west")
        await frontier.border(east, at: "http://server/east")

        try await west.call("arrive", [.string("i1"), .string("Ilsen")], token: ilsen.token)
        try await east.call("arrive", [.string("o1"), .string("Orla")], token: orla.token)
        try await frontier.step(now: 1)
        try await home.step(now: 1)
        try await away.step(now: 1)
        let heard = await home.state.frontierNews
        XCTAssertEqual(heard?.address, "http://server/lost", "Where to cross to, as the realm's steward reads it")
        XCTAssertEqual(heard?.season, 1)
        XCTAssertEqual(heard?.open, true)

        // Each crosses from home, by an order.
        try await west.call("order", [.string("i2"), try order(.crossToFrontier)], token: ilsen.token)
        try await east.call("order", [.string("o2"), try order(.crossToFrontier)], token: orla.token)
        try await home.step(now: 2)
        try await away.step(now: 2)
        let listed = await home.state.status(now: 2).crossings?.map(\.keeper)
        XCTAssertEqual(listed, [ilsen.identity])
        // The Frontier reads them in its time, and seats them; a stranger, never.
        try await lost.call("arrive", [.string("s1"), .string("Stranger")], token: stranger.token)
        try await frontier.step(now: 3)
        let early = await frontier.state.frontier?.admitted.count
        XCTAssertEqual(early, 0, "Read every few seconds, not every round")
        try await frontier.step(now: 1 + RealmSteward.bordersEvery)
        let admitted = await frontier.state.frontier?.admitted.keys.sorted()
        XCTAssertEqual(admitted, [ilsen.identity, orla.identity].sorted())
        let unseated = await frontier.state.keeper(stranger.identity)
        XCTAssertNil(unseated)
        try await lost.call("arrive", [.string("i3"), .string("Ilsen")], token: ilsen.token)
        try await lost.call("arrive", [.string("o3"), .string("Orla")], token: orla.token)
        try await frontier.step(now: 7)
        let seated = await (frontier.state.keeper(ilsen.identity)?.house, frontier.state.keeper(orla.identity)?.house)
        let mine = try XCTUnwrap(seated.0), theirs = try XCTUnwrap(seated.1)
        let kingdoms = await (frontier.state.frontier?.kingdom(of: mine), frontier.state.frontier?.kingdom(of: theirs))
        XCTAssertEqual(kingdoms.0, "The Nullmere")
        XCTAssertEqual(kingdoms.1, "The Farmere")
        let atWar = await frontier.state.world.isAtWar(mine, theirs)
        XCTAssertTrue(atWar)

        // The season runs its watches while they keep it, and ends.
        var now = 7.0
        var rounds = 0
        while await frontier.state.frontier?.season == 1, rounds < FrontierState.lasts + 4 {
            now += 601
            rounds += 1
            try await lost.call("here", [.string("ih\(rounds)")], token: ilsen.token)
            try await lost.call("here", [.string("oh\(rounds)")], token: orla.token)
            try await frontier.step(now: now)
        }
        let season = await frontier.state.frontier?.season
        XCTAssertEqual(season, 2)
        let report = await frontier.state.frontierReport
        let result = try XCTUnwrap(report?.last)
        XCTAssertEqual(Set(result.honours.map(\.keeper)), [ilsen.identity, orla.identity])

        // Home hears it, once, and its keeper is home.
        try await home.step(now: now)
        let told = await home.state.frontierNews?.last?.season
        XCTAssertEqual(told, 1)
        let crossing = await home.state.keeper(ilsen.identity)?.crossing
        XCTAssertNil(crossing, "Home again")
        let chronicle = await home.state.world.chronicle.map(\.text)
        XCTAssertTrue(chronicle.contains { $0.contains("comes home from the Frontier's first season") })
        let lines = chronicle.count
        try await home.step(now: now + RealmSteward.bordersEvery)
        let again = await home.state.world.chronicle.count
        XCTAssertEqual(again, lines, "Told once")
    }
}
