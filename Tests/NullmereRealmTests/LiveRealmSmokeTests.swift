import Foundation
import NullmereCompanionCore
import NullmereCore
import XCTest
@testable import NullmereRealm
import NullmereTestSupport

/// The realm everyone plays, as two Macs would meet it: set
/// NULLMERE_LIVE_REALM to its address (https://maincloud.spacetimedb.com/nullmere)
/// and two keepers' clients, as shipped, with no token but the identities
/// SpacetimeDB gives them, arrive, see each other in the realm, and hear
/// each other's words; then the first keeper's phone keeps her House
/// beside her Mac, its line cut and mended. Run by the Live realm smoke
/// workflow; it needs no secret, only the realm up and its steward
/// running. The phone takes no seat of its own: it keeps the House of a
/// keeper the test seats already.
final class LiveRealmSmokeTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 120, _ condition: @escaping @MainActor @Sendable () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !MainActor.run(body: condition) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
    }

    func testTwoKeepersMeetInTheLiveRealm() async throws {
        guard let text = ProcessInfo.processInfo.environment["NULLMERE_LIVE_REALM"], let url = URL(string: text),
              let transport = SpacetimeHTTP(address: url) else {
            throw XCTSkip("Set NULLMERE_LIVE_REALM to the live realm's address to meet in it")
        }
        let (a, earA, b, earB) = await MainActor.run { () -> (NetworkRealmLink, Listener, NetworkRealmLink, Listener) in
            let a = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 1)
            let b = NetworkRealmLink(transport: transport, credentials: MemoryStore(), pollInterval: 1)
            let earA = Listener(), earB = Listener()
            earA.listen(to: a)
            earB.listen(to: b)
            a.connect()
            b.connect()
            return (a, earA, b, earB)
        }
        defer { Task { @MainActor in a.close(); b.close() } }
        try await until("the realm's status: is the realm up and its steward running?") { earA.hasStatus && earB.hasStatus }
        let status = try await MainActor.run { try XCTUnwrap(earA.lastStatus) }
        print("LIVE \(status.name), age \(status.age), watch \(status.watch): \(status.keepers) keepers, \(status.freeSeats) seats free")
        let mark = String(KeeperIdentity.make().filter(\.isLetter).prefix(5))
        await MainActor.run {
            a.arrive(name: "Sma" + mark)
            b.arrive(name: "Smb" + mark)
        }
        try await until("both keepers to arrive") { earA.keeper?.house != nil && earB.keeper?.house != nil }
        let (houseA, houseB) = await MainActor.run { (earA.keeper!.house!, earB.keeper!.house!) }
        XCTAssertNotEqual(houseA, houseB, "Two keepers, two Houses")
        try await until("each to see the other's House in the realm") {
            earA.world?.houses.indices.contains(houseB) == true && earB.world?.houses.indices.contains(houseA) == true
        }
        let words = "Well met at " + mark
        await MainActor.run { a.send(.say(words: words, toAlliance: false)) }
        try await until("Ama's words heard by Bel") {
            earB.world?.words(heardBy: houseB).contains { $0.from == houseA && $0.text == words } == true
        }
        print("LIVE two keepers arrived in the live realm and one heard the other speak")
        try await keepByPhone(beside: a, heard: earA, house: houseA, at: url, mark: mark)
    }

    /// Seconds until `condition` holds, on the main actor.
    @MainActor
    private func timed(_ what: String, timeout: Double = 120, _ condition: () -> Bool) async throws -> Double {
        let began = Date()
        while !condition() {
            if Date().timeIntervalSince(began) > timeout { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 50_000_000)
        }
        return Date().timeIntervalSince(began)
    }

    /// The first keeper's phone beside her Mac in the live realm, its own
    /// session as the companion app keeps it: linked by the code her Mac
    /// offers, in as her by a key of its own; words said on it and a
    /// company dug in from it carried out by the realm and seen on her Mac,
    /// and words said on her Mac heard on it. Its line cut, it says the
    /// realm is out of reach and words said on it then wait, her Mac
    /// speaking on; mended, it is in reach by the same key, never linked
    /// again, shown what her Mac said meanwhile, and the words it gave
    /// while cut off are carried out by the realm and heard on her Mac.
    /// The line is cut where the phone's requests leave it, as no network
    /// would cut them: a realm served over TLS far away has no relay
    /// before it to cut (the realm job cuts the socket itself, on a
    /// server of its own: CompanionSpacetimeIntegrationTests).
    @MainActor
    private func keepByPhone(beside mac: NetworkRealmLink, heard ear: Listener, house: Int, at address: URL, mark: String) async throws {
        let key = MemoryStore()
        var line: SeverableLine?
        let phone = CompanionSession(memory: PassingMemory()) { realm in
            guard let http = SpacetimeHTTP(address: realm) else { return nil }
            let severable = SeverableLine(http)
            line = severable
            return NetworkRealmLink(transport: severable, credentials: key, pollInterval: 1)
        }
        defer { phone.pause() }
        let code = LinkCode.make()
        var offered: Result<Int, LinkRefusal>?
        mac.offerLink(code: code) { offered = $0 }
        _ = try await timed("the realm to take the Mac's offer of a link") { offered != nil }
        _ = try XCTUnwrap(offered).get()
        phone.take(try XCTUnwrap(CompanionInvite(realm: address, code: code)))
        let linked = try await timed("the phone in as the keeper") { phone.phase == .keeping && phone.ledger != nil }
        XCTAssertEqual(phone.keeper?.id, ear.keeper?.id, "The same keeper as on the Mac")
        let kept = try XCTUnwrap(key.value, "The phone's own key, kept")
        let cuttable = try XCTUnwrap(line)
        func heard(_ words: String, in world: GameState?) -> Bool {
            world?.words(heardBy: house).contains { $0.from == house && $0.text == words } == true
        }

        // From the phone to the Mac: words, and a company dug in where one may be.
        let fromPhone = "From the phone at " + mark
        phone.say(fromPhone, toAlliance: false)
        let carried = try await timed("the realm's word on the phone's words") { phone.word?.awaited == false }
        XCTAssertEqual(phone.word?.text, "Said to the realm: carried out by the realm.")
        let seen = try await timed("the phone's words heard on the Mac") { heard(fromPhone, in: ear.world) }
        if let company = phone.ledger?.companies.first(where: { $0.orders.contains { $0.title == "Fortify" } }) {
            phone.give(.fortify(unit: company.id), told: "Fortify the \(company.name)")
            _ = try await timed("the realm's word on the company dug in") { phone.word?.awaited == false }
            XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): carried out by the realm.")
            _ = try await timed("the company seen dug in on the Mac") { ear.world?.unit(company.id)?.fortified == true }
        }

        // From the Mac to the phone.
        let fromMac = "From the Mac at " + mark
        mac.send(.say(words: fromMac, toAlliance: false))
        let reached = try await timed("the Mac's words heard on the phone") { heard(fromMac, in: phone.world) }
        print(String(format: "LIVE the keeper's phone linked by her Mac's code in %.2f s; its words carried out by the realm in %.2f s "
                     + "and heard on her Mac %.2f s after; her Mac's words heard on the phone in %.2f s", linked, carried, seen, reached))

        // The phone's line cut: out of reach, said in its own words; words
        // said on it then wait, while the Mac speaks on.
        cuttable.cut()
        let noticed = try await timed("the phone to say the realm is out of reach") { phone.outOfReach != nil }
        XCTAssertEqual(phone.phase, .keeping, "Still in, the House as it last stood")
        let waiting = "Said while cut off at " + mark
        phone.say(waiting, toAlliance: false)
        XCTAssertEqual(phone.word?.text, "Said to the realm: \(CompanionSession.waitsForReach)", "Told it waits, not that it went")
        let meanwhile = "Said on the Mac meanwhile at " + mark
        mac.send(.say(words: meanwhile, toAlliance: false))
        _ = try await timed("the Mac's words said while the phone is cut off") { heard(meanwhile, in: ear.world) }
        XCTAssertFalse(heard(meanwhile, in: phone.world), "Unheard on the phone while its line is down")
        XCTAssertFalse(heard(waiting, in: ear.world), "Its words wait, heard nowhere")

        // Mended, the phone told its network is back, as the app is.
        let mended = Date()
        cuttable.mend()
        phone.networkReturned()
        _ = try await timed("the phone in reach again") { phone.outOfReach == nil }
        let back = Date().timeIntervalSince(mended)
        _ = try await timed("the phone shown what the Mac said meanwhile") { heard(meanwhile, in: phone.world) }
        let caughtUp = Date().timeIntervalSince(mended)
        XCTAssertEqual(phone.phase, .keeping)
        XCTAssertEqual(key.value, kept, "By the same key, never linked again")
        _ = try await timed("the realm's word on the words said while cut off") { phone.word?.awaited == false }
        XCTAssertEqual(phone.word?.text, "Said to the realm: carried out by the realm.")
        _ = try await timed("the words said while cut off heard on the Mac") { heard(waiting, in: ear.world) }
        let delivered = Date().timeIntervalSince(mended)
        print(String(format: "LIVE the phone's line cut: out of reach said in %.2f s; mended, in reach %.2f s after, her Mac's words "
                     + "said meanwhile seen by %.2f s, and its words said while cut off carried out and heard on her Mac by %.2f s",
                     noticed, back, caughtUp, delivered))
    }
}
