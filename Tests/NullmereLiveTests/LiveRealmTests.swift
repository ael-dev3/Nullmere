import Foundation
@testable import NullmereLive
import NullmereRealm
import XCTest

/// Two clients on a real SpacetimeDB server with the realm (realm/)
/// published: each joins, is founded a city, and builds on the database's
/// own timers, the rows pushed to them as they change. Set
/// NULLMERE_REALM_CHECK to the database's address (http://host:port/name);
/// in a realm its owner has set to thirty times the written pace or more,
/// troops are trained and an army sent to gather as well.
final class LiveRealmTests: XCTestCase {
    private func realm() throws -> (server: URL, database: String) {
        guard let text = ProcessInfo.processInfo.environment["NULLMERE_REALM_CHECK"], let url = URL(string: text),
              var parts = URLComponents(url: url, resolvingAgainstBaseURL: false), url.pathComponents.count >= 2 else {
            throw XCTSkip("Set NULLMERE_REALM_CHECK to test against a SpacetimeDB server with the realm published")
        }
        let database = url.lastPathComponent
        parts.path = ""
        return (try XCTUnwrap(parts.url), database)
    }

    /// Waits for something the realm will push.
    private func eventually(_ what: String, within seconds: Double = 30, file: StaticString = #filePath, line: UInt = #line,
                            _ holds: () -> Bool) async {
        let deadline = Date().addingTimeInterval(seconds)
        while Date() < deadline {
            if holds() { return }
            try? await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTFail("\(what): not within \(Int(seconds)) seconds", file: file, line: line)
    }

    private func refusal(_ ask: () async throws -> Void) async -> String? {
        do {
            try await ask()
            return nil
        } catch let refusal as LiveRefusal {
            return refusal.words
        } catch {
            return "error: \(error)"
        }
    }

    func testTwoPlayersJoinBuildAndSeeEachOther() async throws {
        let (server, database) = try realm()
        let ada = try await LiveClient.open(server: server, database: database)
        let bryn = try await LiveClient.open(server: server, database: database)
        defer {
            ada.close()
            bryn.close()
        }
        let watched = await ada.watch()
        let alsoWatched = await bryn.watch()
        XCTAssertTrue(watched && alsoWatched, "Each opens a subscription")
        await eventually("the subscriptions take") { ada.isLive && bryn.isLive }
        XCTAssertNotNil(ada.world.realm, "The realm's own row")
        XCTAssertGreaterThan(ada.world.land.count, 50, "The land, in chunks")
        XCTAssertNotNil(ada.world.blueprint(1, level: 25), "The catalogue")
        XCTAssertNil(ada.world.me, "Not a player yet")
        XCTAssertNil(ada.world.city)

        // Joining founds a city, pushed with what stands in it.
        let tag = String(UInt32.random(in: 0..<1_000_000), radix: 36)
        try await ada.join(name: "Ada \(tag)")
        await eventually("Ada's city is pushed to her") {
            let world = ada.world
            return world.me != nil && world.city != nil && world.buildings.count == 3 && world.stock != nil
        }
        let world = ada.world
        let city = try XCTUnwrap(world.city)
        XCTAssertEqual(world.me?.name, "Ada \(tag)")
        XCTAssertEqual(city.name, "Ada \(tag)")
        XCTAssertEqual(city.keep, 1)
        XCTAssertEqual(world.buildings.map(\.kind), [1, 2, 3], "A Keep, a Farm and a Sawmill")
        XCTAssertEqual(world.places[city.hex]?.kind, LivePlace.city)
        XCTAssertNotNil(world.ground(at: city.hex), "Its ground is among the land read")
        let stock = try XCTUnwrap(world.stock)
        XCTAssertTrue(stock.goods.covers(LiveGoods(grain: 6_000, timber: 8_000, stone: 6_000)))
        XCTAssertGreaterThan(stock.goods(at: Double(stock.asOf) + 3_600).grain, stock.goods.grain, "Goods come in by the hour")

        // The realm refuses in its own words.
        let again = await refusal { try await ada.join(name: "Ada once more") }
        XCTAssertEqual(again, "You have already joined the realm.")
        let taken = await refusal { try await bryn.join(name: "ADA \(tag.uppercased())") }
        XCTAssertEqual(taken, "Another player has that name.")
        let farm = try XCTUnwrap(world.building(2))
        let tooSoon = await refusal { try await ada.upgrade(building: farm.id) }
        XCTAssertEqual(tooSoon, "Raise your Keep to level 2 first.")

        // The other player sees her city, and nothing of what is hers alone.
        try await bryn.join(name: "Bryn \(tag)")
        await eventually("Bryn sees both cities") { bryn.world.cities.count >= 2 && bryn.world.city != nil }
        XCTAssertEqual(bryn.world.cities[city.id]?.name, "Ada \(tag)")
        XCTAssertNotEqual(bryn.world.city?.id, city.id)
        XCTAssertTrue(bryn.world.buildings.allSatisfy { $0.city == bryn.world.city?.id }, "Only his own buildings")
        let notHis = await refusal { try await bryn.upgrade(building: farm.id) }
        XCTAssertEqual(notHis, "That is not yours.")

        // Raising the Keep: paid at once, done by the database's own timer, pushed as it happens.
        let keep = try XCTUnwrap(world.building(1))
        let cost = try XCTUnwrap(world.blueprint(1, level: 2))
        try await ada.upgrade(building: keep.id)
        await eventually("the job is pushed") { ada.world.jobs.count == 1 }
        let job = try XCTUnwrap(ada.world.jobs.first)
        XCTAssertEqual([job.kind, Int(job.subject), job.level], [LiveJob.raise, Int(keep.id), 2])
        XCTAssertEqual(job.ends - job.started, cost.seconds)
        XCTAssertLessThanOrEqual(try XCTUnwrap(ada.world.stock).goods.timber, stock.goods(at: Double(job.started)).timber - cost.cost.timber + 5)
        await eventually("the Keep reaches level 2") { ada.world.building(1)?.level == 2 && ada.world.jobs.isEmpty }
        await eventually("and everyone sees it") { bryn.world.cities[city.id]?.keep == 2 }

        // Read afresh without the subscription, it is the same world.
        let read = try await ada.read()
        XCTAssertEqual(read.city, ada.world.city)
        XCTAssertEqual(read.buildings, ada.world.buildings)
        XCTAssertEqual(read.cities.count, ada.world.cities.count)
        XCTAssertEqual(read.me?.name, ada.world.me?.name)
        let him = try XCTUnwrap(bryn.world.me).id
        XCTAssertEqual(read.players[him]?.name, "Bryn \(tag)")
        // Here while his subscription is open, whatever else he asks meanwhile.
        await eventually("Bryn is seen to be here") { ada.world.players[him]?.online == true }

        // In a fast realm: a Barracks, a batch of spearmen, and an army out to gather and home again.
        guard let pace = ada.world.realm?.pace, pace >= 30 else {
            print("LIVE the realm runs at its written pace: troops and marches are left to realm/check.sh")
            return
        }
        try await ada.build(7)
        await eventually("the Barracks stands") { ada.world.building(7)?.level == 1 }
        let barracks = try XCTUnwrap(ada.world.building(7))
        let tooMany = await refusal { try await ada.train(building: barracks.id, tier: 1, count: 500) }
        XCTAssertEqual(tooMany, "At most 50 at once.")
        try await ada.train(building: barracks.id, tier: 1, count: 20)
        await eventually("twenty spearmen stand ready") { ada.world.troops.first { $0.kind == 1 && $0.tier == 1 }?.ready == 20 }

        let sites = ada.world.sites.values.sorted { ($0.hex.distance(to: city.hex), $0.id) < ($1.hex.distance(to: city.hex), $1.id) }
        XCTAssertGreaterThan(sites.count, 100, "Sites scattered over the land")
        var sent: LiveSite?
        for site in sites.prefix(20) where site.gatherer == 0 {
            let why = await refusal { try await ada.gather(at: site.hex, soldiers: [(kind: 1, tier: 1, count: 20)]) }
            if why == nil {
                sent = site
                break
            }
            XCTAssertEqual(why, "There is no way there over open ground.", "The only reason a near site can't be reached")
        }
        let site = try XCTUnwrap(sent, "An army set out for a site nearby")
        await eventually("the march is on the map for everyone") { bryn.world.marches.values.contains { $0.target == site.id } }
        let march = try XCTUnwrap(ada.world.myMarches.first)
        XCTAssertEqual(march.route.first, city.hex)
        XCTAssertEqual(march.route.last, site.hex)
        XCTAssertEqual(march.soldiers, 20)
        XCTAssertEqual(ada.world.squads.map(\.count), [20])
        XCTAssertTrue(bryn.world.squads.isEmpty, "What it is made of is hers alone to read")
        let before = try XCTUnwrap(ada.world.stock)
        await eventually("it works the site", within: 60) { ada.world.myMarches.first?.state == LiveMarch.working }
        await eventually("it turns for home with its load", within: 60) { ada.world.myMarches.first?.state == LiveMarch.returning }
        XCTAssertEqual(ada.world.hauls.first.map { $0.goods.parts.reduce(0, +) }, 240, "What twenty spearmen carry")
        await eventually("and comes home", within: 60) { ada.world.myMarches.isEmpty && ada.world.troops.first { $0.kind == 1 }?.ready == 20 }
        await eventually("its load in the stock") {
            guard let now = ada.world.stock else { return false }
            return now.goods.parts.reduce(0, +) >= before.goods.parts.reduce(0, +) + 240
        }

        // Gone when his subscription closes; his city stays.
        XCTAssertEqual(ada.world.players[him]?.online, true, "Still here, after all he asked")
        bryn.close()
        await eventually("Bryn is seen to be gone") { ada.world.players[him]?.online == false }
        XCTAssertNotNil(ada.world.cities.values.first { $0.owner == him })
    }
}
