import Foundation
@testable import NullmereCore
import XCTest
@testable import NullmereRealm
import NullmereTestSupport

/// A keeper's phone on the realm beside their Mac, through SpacetimeDB (in
/// memory) and the steward, each device under its own identity: the Mac
/// offers a link by a code's digest, the phone brings the code and comes in
/// as the keeper, reading their view; an order from either is seen on the
/// other, the phone's readiness counts as the keeper's, one device leaving
/// leaves the keeper there while the other is, and the phone can do nothing
/// only the Mac may. Let go, the phone is told the realm links it to no
/// one; a stranger's code links no one. `SpacetimeIntegrationTests` plays
/// the same on a real server.
/// What a call's `done` heard, kept where the links live.
@MainActor
final class Answered<Value> {
    var value: Value?
}

final class CompanionRealmTests: XCTestCase {

    private func until(_ what: String, timeout: Double = 15, _ condition: @escaping @MainActor @Sendable () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while await !MainActor.run(body: condition) {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    @MainActor
    private func device(_ db: FakeSpacetime, store: MemoryStore = MemoryStore()) -> (NetworkRealmLink, Listener) {
        let link = NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05)
        let listener = Listener()
        listener.listen(to: link)
        link.connect()
        return (link, listener)
    }

    /// What a House's keeper said, as a device heard it: each line with
    /// where it was said, to the realm or to the House's alliance.
    @MainActor
    private static func said(by house: Int, on ear: Listener) -> [String] {
        guard let world = ear.world else { return [] }
        let sworn = world.alliance(of: house)?.id
        return world.wordsSaid.filter { $0.from == house }
            .map { ($0.alliance == nil ? "realm: " : $0.alliance == sworn ? "alliance: " : "elsewhere: ") + $0.text }
    }

    func testAPhoneLinkedByItsKeepersCodePlaysBesideTheirMac() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "companion",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        defer { running.cancel() }

        let macStore = MemoryStore()
        let (mac, macEar) = await MainActor.run { device(db, store: macStore) }
        try await until("the realm's status on the Mac") { macEar.hasStatus }
        await MainActor.run { mac.arrive(name: "Ama") }
        try await until("Ama to arrive") { macEar.keeper != nil }

        // A stranger's code links no one, and a device linked to no one
        // reads no keeper's view.
        let phoneStore = MemoryStore()
        let (phone, phoneEar) = await MainActor.run { device(db, store: phoneStore) }
        try await until("the realm's status on the phone") { phoneEar.hasStatus }
        await MainActor.run { phone.takeLink(code: "ABCD-2345-EFGH") }
        try await until("the wrong code refused") { !phoneEar.refusals.isEmpty }
        let wrong = await MainActor.run { phoneEar.refusals }
        XCTAssertTrue(wrong.contains { $0.contains("No keeper's Mac shows that code") }, "\(wrong)")
        await MainActor.run { phone.accompany() }
        try await until("a device linked to no one told so") { phoneEar.refusals.contains(RealmError.unknownKeeper.description) }

        // The Mac offers a link by the code's digest alone.
        let code = LinkCode.make()
        let offered = await MainActor.run { Answered<Result<Int, LinkRefusal>>() }
        await MainActor.run { mac.offerLink(code: code) { offered.value = $0 } }
        try await until("the realm to take the offer") { offered.value != nil }
        let count = await MainActor.run { try? offered.value?.get() }
        XCTAssertEqual(count, 0, "No device speaks for Ama yet")
        let requests = await db.calls
        XCTAssertTrue(requests.contains("offer_link"))
        let kept = try await db.query("SELECT identity, keeper FROM companion", token: key.token)
        XCTAssertTrue(kept.isEmpty)

        // The phone brings the code and comes in as Ama, reading her view.
        await MainActor.run { phone.takeLink(code: LinkCode.shown(code).lowercased()) }
        try await until("the phone to come in as Ama") { phoneEar.keeper != nil }
        let (macKeeper, phoneKeeper) = await MainActor.run { (macEar.keeper, phoneEar.keeper) }
        XCTAssertEqual(phoneKeeper?.id, macKeeper?.id, "The phone speaks for Ama, not as itself")
        XCTAssertEqual(phoneKeeper?.name, "Ama")
        XCTAssertEqual(phoneKeeper?.house, macKeeper?.house)
        XCTAssertEqual(phoneKeeper?.companions?.count, 1)
        let phoneIdentity = await MainActor.run { phone.credentials?.identity }
        XCTAssertNotEqual(phoneIdentity, macKeeper?.id, "Under its own identity: the Mac's key never leaves the Mac")
        let linked = await db.companions
        XCTAssertEqual(linked, [try XCTUnwrap(phoneIdentity): try XCTUnwrap(macKeeper?.id)])
        // The Mac sees its phone in the realm with Ama.
        try await until("the Mac to see its phone in the realm") { macEar.toldKeeper?.companionsHere == 1 }
        let quietBefore = await MainActor.run { macEar.toldKeeper?.companionLastHeard }
        XCTAssertNil(quietBefore)

        // An order from the phone is seen on the Mac.
        let house = try XCTUnwrap(macKeeper?.house)
        let world = try await MainActor.run { try XCTUnwrap(phoneEar.world) }
        let spears = world.units(of: house).filter { $0.kind == .spear }
        let first = try XCTUnwrap(spears.first)
        await MainActor.run { phone.send(.fortify(unit: first.id)) }
        try await until("the phone's order carried out, on the phone") { phoneEar.world?.unit(first.id)?.fortified == true }
        try await until("and seen on the Mac") { macEar.world?.unit(first.id)?.fortified == true }

        // Words the phone says, to the realm and to the alliance Ama raised
        // on her Mac, are heard on the Mac, each where it was said, as hers.
        await MainActor.run { mac.send(.foundAlliance(name: "The Phone's Accord")) }
        try await until("Ama's alliance, on the phone") { phoneEar.world?.alliance(of: house) != nil }
        await MainActor.run { phone.send(.say(words: "Kept from Ama's phone", toAlliance: false)) }
        try await until("the phone's words to the realm, on the Mac") {
            CompanionRealmTests.said(by: house, on: macEar).contains("realm: Kept from Ama's phone")
        }
        await MainActor.run { phone.send(.say(words: "Sworn, from Ama's phone", toAlliance: true)) }
        try await until("the phone's words to the alliance, on the Mac") {
            CompanionRealmTests.said(by: house, on: macEar).contains("alliance: Sworn, from Ama's phone")
        }
        let onTheMac = await MainActor.run { CompanionRealmTests.said(by: house, on: macEar) }
        XCTAssertEqual(onTheMac, ["realm: Kept from Ama's phone", "alliance: Sworn, from Ama's phone"])

        // And one from the Mac on the phone: stores bartered.
        let stores = await MainActor.run { phoneEar.world?.houses[house].stock }
        await MainActor.run { mac.send(.barter(give: .timber, take: .stone, amount: 3)) }
        try await until("the Mac's order seen on the phone") { phoneEar.world?.houses[house].stock != stores }

        // The phone's readiness is the keeper's: Ama alone in the realm,
        // ready by her phone, the watch turns, on her Mac too.
        let watch = await MainActor.run { macEar.lastStatus?.watch ?? 0 }
        await MainActor.run { phone.setReady(true) }
        try await until("the watch turned by Ama's phone") { (macEar.lastStatus?.watch ?? 0) > watch }
        try await until("and the Mac told of it") { macEar.turned }

        // What only the Mac may do, the phone can't: offer another link,
        // seal the keeper with words, take one up by them, or enter at the door.
        let refused = await MainActor.run { Answered<Result<Int, LinkRefusal>>() }
        await MainActor.run { phone.offerLink(code: LinkCode.make()) { refused.value = $0 } }
        try await until("the phone's offer refused") { refused.value != nil }
        let why = await MainActor.run { () -> String? in
            if case .failure(let why)? = refused.value { return why.words }
            return nil
        }
        XCTAssertEqual(why, RealmSteward.notForCompanions)
        let sealed = await MainActor.run { Answered<String?>() }
        await MainActor.run { phone.seal(proof: String(repeating: "cd", count: 32)) { sealed.value = .some($0) } }
        try await until("the phone's sealing refused") { sealed.value != nil }
        let sealing = await MainActor.run { sealed.value }
        XCTAssertEqual(sealing, .some(RealmSteward.notForCompanions))
        let sealOnTheMac = await MainActor.run { macEar.lastKeeper?.seal }
        XCTAssertNil(sealOnTheMac)

        // The phone leaving leaves Ama there while her Mac is.
        await MainActor.run { phone.leave() }
        for _ in 0..<500 where await db.handled(kind: "leave") < 1 { try await Task.sleep(nanoseconds: 20_000_000) }
        let leavings = await db.handled(kind: "leave")
        XCTAssertEqual(leavings, 1, "The phone's leaving carried out")
        let online = await steward.state.keeper(try XCTUnwrap(macKeeper?.id))?.isOnline
        XCTAssertEqual(online, true, "Ama is still there, on her Mac")
        // And her Mac sees the phone gone, and when it was last in the realm.
        try await until("the Mac to see its phone gone") {
            macEar.toldKeeper?.companionsHere == nil && macEar.toldKeeper?.companionLastHeard == 1
        }

        // Back on the phone, by its own identity kept: in as Ama again, the
        // world as it now stands.
        let (again, againEar) = await MainActor.run { device(db, store: phoneStore) }
        try await until("the phone's status again") { againEar.hasStatus }
        let away = await MainActor.run { macEar.world?.houses[house].stock }
        await MainActor.run { mac.send(.barter(give: .timber, take: .stone, amount: 3)) }
        try await until("the Mac's order while the phone was away") { macEar.world?.houses[house].stock != away }
        let afterwards = await MainActor.run { macEar.world?.houses[house].stock }
        await MainActor.run { again.accompany() }
        try await until("the phone in again as Ama") { againEar.keeper?.name == "Ama" }
        try await until("the Mac to see its phone back") { macEar.toldKeeper?.companionsHere == 1 }
        let caughtUp = await MainActor.run { againEar.world?.houses[house].stock }
        XCTAssertEqual(caughtUp, afterwards, "The phone back sees what was done while it was away")

        // The Mac leaving leaves Ama there while her phone is.
        await MainActor.run { mac.leave() }
        for _ in 0..<500 where await db.handled(kind: "leave") < 2 { try await Task.sleep(nanoseconds: 20_000_000) }
        let macLeft = await db.handled(kind: "leave")
        XCTAssertEqual(macLeft, 2, "The Mac's leaving carried out")
        let stillThere = await steward.state.keeper(try XCTUnwrap(macKeeper?.id))?.isOnline
        XCTAssertEqual(stillThere, true, "Ama is still there, on her phone")

        // The Mac lets every device go: the phone is told the realm links
        // it to no one.
        let (mac2, _) = await MainActor.run { device(db, store: macStore) }
        let unlinked = await MainActor.run { Answered<String?>() }
        await MainActor.run { mac2.unlinkDevices { unlinked.value = .some($0) } }
        try await until("the devices let go") { unlinked.value != nil }
        let unlinking = await MainActor.run { unlinked.value }
        XCTAssertEqual(unlinking, .some(nil))
        let after = await db.companions
        XCTAssertTrue(after.isEmpty, "\(after)")
        await MainActor.run { again.accompany() }
        try await until("the phone told it speaks for no one") {
            againEar.refusals.contains(RealmError.unknownKeeper.description)
        }
        await MainActor.run {
            again.close()
            mac2.close()
        }
    }

    /// The link's edges: the keeper's own Mac doesn't come in as its own
    /// companion, and a stranger has no devices to let go; a companion row
    /// the server turned away is written again with the next round, the
    /// phone in all the same; a phone lets itself go, the others staying;
    /// a keeper whose compact is out of date is asked to accept it on the
    /// Mac; an offer to a realm out of reach is told so; and a realm in this
    /// process links no phones.
    func testTheLinksEdges() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "edges",
                                             seats: 4, watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        defer { running.cancel() }
        let (mac, macEar) = await MainActor.run { device(db) }
        await MainActor.run { mac.arrive(name: "Ama") }
        try await until("Ama to arrive") { macEar.keeper != nil }
        let ama = try await MainActor.run { try XCTUnwrap(macEar.keeper) }

        await MainActor.run { mac.accompany() }
        try await until("the Mac told it is the keeper's own") { macEar.refusals.contains { $0.contains("the keeper's own Mac") } }

        let (stranger, _) = await MainActor.run { device(db) }
        let strangers = await MainActor.run { Answered<String?>() }
        await MainActor.run { stranger.unlinkDevices { strangers.value = .some($0) } }
        try await until("the stranger answered") { strangers.value != nil }
        let told = await MainActor.run { strangers.value }
        XCTAssertEqual(told, .some(RealmError.unknownKeeper.description))

        // The companion row turned away once: written with the next round.
        func linked(_ store: MemoryStore) async throws -> (NetworkRealmLink, Listener) {
            let offered = await MainActor.run { Answered<Result<Int, LinkRefusal>>() }
            let code = LinkCode.make()
            await MainActor.run { mac.offerLink(code: code) { offered.value = $0 } }
            try await until("the offer taken") { offered.value != nil }
            let (phone, ear) = await MainActor.run { device(db, store: store) }
            await MainActor.run { phone.takeLink(code: code) }
            return (phone, ear)
        }
        await db.refuse("link_companions")
        let (first, firstEar) = try await linked(MemoryStore())
        try await until("the first phone in, its row written again") { firstEar.keeper?.id == ama.id }
        let (second, secondEar) = try await linked(MemoryStore())
        try await until("the second phone in") { secondEar.keeper?.id == ama.id }
        let both = await db.companions
        XCTAssertEqual(both.count, 2)

        // The first lets itself go; the second still speaks for Ama.
        let gone = await MainActor.run { Answered<String?>() }
        await MainActor.run { first.unlinkDevices { gone.value = .some($0) } }
        try await until("the first let go") { gone.value != nil }
        let left = await db.companions
        XCTAssertEqual(left.count, 1)
        let secondIdentity = await MainActor.run { second.credentials?.identity }
        XCTAssertEqual(left.keys.first, secondIdentity)
        await MainActor.run { first.accompany() }
        try await until("the first told it speaks for no one") { firstEar.refusals.contains(RealmError.unknownKeeper.description) }

        // A compact out of date: the phone is asked to have it accepted on the Mac.
        await steward.reshape { state in
            if let index = state.keepers.firstIndex(where: { $0.id == ama.id }) { state.keepers[index].compact = 0 }
        }
        await MainActor.run { second.accompany() }
        try await until("the phone asked to have the compact accepted on the Mac") {
            secondEar.refusals.contains(RealmSteward.compactOnTheMac)
        }

        // An offer to a realm out of reach, and a letting go, told so.
        await db.setReachable(false)
        let unreached = await MainActor.run { Answered<Result<Int, LinkRefusal>>() }
        let unlinking = await MainActor.run { Answered<String?>() }
        await MainActor.run {
            mac.offerLink(code: LinkCode.make()) { unreached.value = $0 }
            mac.unlinkDevices { unlinking.value = .some($0) }
        }
        try await until("both told the realm is out of reach", timeout: 40) { unreached.value != nil && unlinking.value != nil }
        let (offerWhy, unlinkWhy) = await MainActor.run { () -> (String?, String?) in
            if case .failure(let why)? = unreached.value { return (why.words, unlinking.value ?? nil) }
            return (nil, unlinking.value ?? nil)
        }
        XCTAssertNotNil(offerWhy)
        XCTAssertNotNil(unlinkWhy)
        await db.setReachable(true)

        // A realm in this process links no phones.
        let local = await MainActor.run { LocalRealm(state: RealmState(name: "Here", seed: "here", seats: 2, now: 0)).link(identity: "mac") }
        let localOffer = await MainActor.run { Answered<Result<Int, LinkRefusal>>() }
        let localUnlink = await MainActor.run { Answered<String?>() }
        await MainActor.run {
            local.offerLink(code: LinkCode.make()) { localOffer.value = $0 }
            local.unlinkDevices { localUnlink.value = .some($0) }
        }
        let localWords = await MainActor.run { () -> (String?, String??) in
            if case .failure(let why)? = localOffer.value { return (why.words, localUnlink.value) }
            return (nil, localUnlink.value)
        }
        XCTAssertEqual(localWords.0, RealmLinkNote.linksNoPhones)
        XCTAssertEqual(localWords.1, .some(RealmLinkNote.linksNoPhones))
        await MainActor.run {
            mac.close()
            first.close()
            second.close()
            stranger.close()
        }
    }

    /// A steward taking up a realm reads who speaks for whom as the server
    /// keeps it, and writes nothing again that is kept: the phone linked
    /// before still comes in as its keeper. A link offered by a digest that
    /// can't be read is refused.
    func testAStewardTakingUpTheRealmKeepsItsLinks() async throws {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let first = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "kept links",
                                           seats: 4, watchLength: 600, now: 0)
        let running = Task { await first.run(clock: { 1 }) }
        let (mac, macEar) = await MainActor.run { device(db) }
        await MainActor.run { mac.arrive(name: "Ama") }
        try await until("Ama to arrive") { macEar.keeper != nil }
        let code = LinkCode.make()
        let offered = await MainActor.run { Answered<Result<Int, LinkRefusal>>() }
        await MainActor.run { mac.offerLink(code: code) { offered.value = $0 } }
        try await until("the offer taken") { offered.value != nil }
        let phoneStore = MemoryStore()
        let (phone, phoneEar) = await MainActor.run { device(db, store: phoneStore) }
        await MainActor.run { phone.takeLink(code: code) }
        try await until("the phone in") { phoneEar.keeper != nil }
        await MainActor.run { phone.close() }

        // A digest that can't be read is no offer.
        let macCredentials = try await MainActor.run { try XCTUnwrap(mac.credentials) }
        try await db.call("offer_link", [.string("bad-digest"), .string("not a digest")], token: macCredentials.token)
        var answer: RealmReply?
        for _ in 0..<500 where answer == nil {
            let rows = try await db.query("SELECT * FROM my_replies WHERE nonce = \(sqlString("bad-digest"))", token: macCredentials.token)
            if let text = rows.first?[2].string { answer = try JSONDecoder().decode(RealmReply.self, from: Data(text.utf8)) }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
        XCTAssertEqual(answer?.ok, false)
        XCTAssertEqual(answer?.refusal, "The link's digest couldn't be read.")

        // Another steward takes up the realm, the first's hold let lapse.
        running.cancel()
        await running.value
        await db.advance(FakeSpacetime.leaseSeconds + 1)
        let linksWritten = await db.calls.filter { $0 == "link_companions" }.count
        let second = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "kept links",
                                            seats: 4, watchLength: 600, now: 2)
        let again = Task { await second.run(clock: { 2 }) }
        defer { again.cancel() }
        let (back, backEar) = await MainActor.run { device(db, store: phoneStore) }
        try await until("the phone's status") { backEar.hasStatus }
        await MainActor.run { back.accompany() }
        try await until("the phone in again as Ama, under the second steward") { backEar.keeper?.name == "Ama" }
        let written = await db.calls.filter { $0 == "link_companions" }.count
        XCTAssertEqual(written, linksWritten, "Who speaks for whom read back as kept, not written again")
        await MainActor.run {
            back.close()
            mac.close()
        }
    }
}
