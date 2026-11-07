import Foundation
@testable import NullmereCore
@testable import NullmereRealm
import NullmereTestSupport
import XCTest
@testable import NullmereCompanionCore

/// A keeper's phone through its session, over SpacetimeDB in memory and the
/// steward, beside the keeper's Mac: linked by the code the Mac shows and in
/// as the keeper, its House listed; an order the rules refuse is refused
/// here and sent nowhere, one they take is carried out by the realm and
/// seen on the Mac; set aside and back it comes in again as the keeper by
/// its own key; and let go from the Mac, it is told so and asks for a code.
@MainActor
final class CompanionSessionTests: XCTestCase {
    private func until(_ what: String, timeout: Double = 15, _ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(timeout)
        while !condition() {
            if Date() > deadline { throw SpacetimeError("Timed out waiting for \(what)") }
            try await Task.sleep(nanoseconds: 20_000_000)
        }
    }

    /// A realm of four seats, its steward running, and a keeper in by their Mac.
    private func realm() async throws -> (FakeSpacetime, Task<Void, Never>, NetworkRealmLink, Keeper, RealmSteward) {
        let db = FakeSpacetime()
        let key = try await db.createIdentity()
        let steward = try await RealmSteward(transport: db, token: key.token, name: "The Nullmere", seed: "phone", seats: 4,
                                             watchLength: 600, now: 0)
        let running = Task { await steward.run(clock: { 1 }) }
        let mac = NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        var arrived: Keeper?
        mac.onEvent = { if case .arrived(let keeper, _) = $0 { arrived = keeper } }
        mac.connect()
        mac.arrive(name: "Ama")
        try await until("the keeper in by their Mac") { arrived != nil }
        return (db, running, mac, try XCTUnwrap(arrived), steward)
    }

    private func offer(_ mac: NetworkRealmLink) async throws -> String {
        let code = LinkCode.make()
        var taken: Result<Int, LinkRefusal>?
        mac.offerLink(code: code) { taken = $0 }
        try await until("the realm to take the offer") { taken != nil }
        _ = try XCTUnwrap(taken).get()
        return code
    }

    func testAPhoneLinkedByTheMacsCodeKeepsTheHouse() async throws {
        let (db, running, mac, keeper, steward) = try await realm()
        defer { running.cancel() }
        let realm = try XCTUnwrap(URL(string: "https://realm.example/nullmere"))
        let memory = PassingMemory()
        let store = MemoryStore()
        var made = 0
        let phone = CompanionSession(memory: memory) { _ in
            made += 1
            return NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05)
        }
        XCTAssertEqual(phone.phase, .pairing)
        phone.resume()
        XCTAssertEqual(made, 0, "Linked to no realm, it reaches for none")

        // A code no Mac shows is refused, in the realm's words.
        phone.take(try XCTUnwrap(CompanionInvite(realm: realm, code: "ABCD2345EFGH")))
        XCTAssertEqual(phone.phase, .entering)
        try await until("the wrong code refused") { phone.phase == .pairing }
        XCTAssertTrue(phone.problem?.contains("No keeper's Mac shows that code") == true, "\(phone.problem ?? "none")")
        XCTAssertNil(memory.realm, "Nothing remembered")

        // The Mac's code: in as the keeper, their House listed.
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: realm, code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping }
        XCTAssertEqual(phone.keeper?.id, keeper.id)
        XCTAssertNil(phone.problem)
        XCTAssertEqual(memory.realm, realm, "The realm remembered, to come in again")
        XCTAssertNotNil(phone.status)
        XCTAssertNotNil(phone.secondsLeft(at: Date()))
        let ledger = try XCTUnwrap(phone.ledger)
        let house = try XCTUnwrap(keeper.house)
        XCTAssertEqual(ledger.house, phone.world?.houses[house].title)
        XCTAssertFalse(ledger.companies.isEmpty)
        XCTAssertTrue(ledger.holds.contains(where: \.isSeat))
        XCTAssertEqual(ledger.stores.map(\.resource), Resource.allCases)

        // An order the rules take: carried out here at once, then by the
        // realm, and seen on the Mac.
        let company = try XCTUnwrap(ledger.companies.first { $0.orders.contains { $0.title == "Fortify" } })
        let fortify = try XCTUnwrap(company.orders.first { $0.title == "Fortify" })
        var macWorld: GameState?
        mac.onEvent = { event in
            switch event {
            case .changed(let world), .watchTurned(let world, _), .settled(let world, _): macWorld = world
            default: break
            }
        }
        phone.give(fortify.command, told: "Fortify \(company.name)")
        XCTAssertEqual(phone.word?.awaited, true, "Sent, its word to come")
        XCTAssertEqual(phone.world?.unit(company.id)?.fortified, true, "Carried out here as the realm will")
        try await until("the realm's word") { phone.word?.awaited == false }
        XCTAssertEqual(phone.word?.refused, false)
        XCTAssertTrue(phone.word?.text.contains("carried out by the realm") == true, "\(phone.word?.text ?? "")")
        try await until("the order seen on the Mac") { macWorld?.unit(company.id)?.fortified == true }
        XCTAssertFalse(phone.ledger?.companies.first { $0.id == company.id }?.orders.contains { $0.title == "Fortify" } ?? true,
                       "Dug in, it is offered no fortifying again")

        // One the rules refuse goes nowhere, with their reason: a company
        // drilled with no Muster Hall by it.
        let sent = await db.handled(kind: "order")
        phone.give(.drill(unit: company.id), told: "Drill \(company.name)")
        XCTAssertTrue(phone.word?.text.hasPrefix("Drill \(company.name): ") == true, "\(phone.word?.text ?? "")")
        XCTAssertEqual(phone.word?.refused, true)
        XCTAssertEqual(phone.word?.awaited, false)
        try await Task.sleep(nanoseconds: 200_000_000)
        let after = await db.handled(kind: "order")
        XCTAssertEqual(after, sent, "Never sent")

        // Set aside and back: in again as the keeper, by its own key.
        phone.pause()
        XCTAssertEqual(phone.phase, .away)
        phone.resume()
        XCTAssertEqual(phone.phase, .entering)
        try await until("in again as the keeper") { phone.phase == .keeping }
        XCTAssertEqual(phone.keeper?.id, keeper.id)
        XCTAssertEqual(phone.world?.unit(company.id)?.fortified, true, "The world as it stands")
        XCTAssertEqual(made, 3, "A link each time it reached for the realm")

        // A work raised from the phone, its stores given it by the realm.
        await steward.reshape { state in state.world.houses[house].stock = Stock(grain: 900, timber: 900, stone: 900, moonsalt: 100) }
        try await until("the stores the realm gave") { phone.ledger?.stores.first { $0.resource == .timber }?.amount == 900 }
        let seat = try XCTUnwrap(phone.ledger?.holds.first(where: \.isSeat))
        phone.give(.build(hold: seat.id, kind: .granary), told: "Raise a granary at \(seat.name)")
        try await until("the granary rising, in the phone's ledger") {
            phone.ledger?.holds.first(where: \.isSeat)?.work.contains { $0.hasPrefix("Raising Granary I,") } == true
        }

        // Words to the realm, said from the phone and heard there; nothing
        // said is nothing sent.
        phone.say("   ", toAlliance: false)
        phone.say("Well met, from the water's edge.", toAlliance: false)
        try await until("the words said, among the realm's") {
            phone.ledger?.realmWords.contains { $0.isOwn && $0.text == "Well met, from the water's edge." } == true
        }

        // Back to the front while in: the line woken, still in.
        phone.resume()
        XCTAssertEqual(phone.phase, .keeping)

        // Ready by the phone, alone in the realm: the watch turns, and with
        // it the phone's readiness.
        let watch = phone.ledger?.watch ?? 0
        phone.setReady(true)
        XCTAssertTrue(phone.isReady)
        try await until("the watch turned") { (phone.ledger?.watch ?? 0) > watch }
        XCTAssertFalse(phone.isReady, "Ready again only when asked")

        // Let go from the Mac: told so as it comes in again, the realm forgotten.
        var done: String??
        mac.unlinkDevices { done = .some($0) }
        try await until("the devices let go") { done != nil }
        phone.pause()
        phone.resume()
        try await until("told it speaks for no one") { phone.phase == .pairing }
        XCTAssertEqual(phone.problem, CompanionSession.unlinked)
        XCTAssertNil(memory.realm)
        XCTAssertNil(phone.ledger)

        // Linked again, then let go from the phone itself.
        let again = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: realm, code: again)))
        try await until("the phone in once more") { phone.phase == .keeping }
        phone.unlink()
        XCTAssertEqual(phone.phase, .pairing)
        XCTAssertNil(memory.realm, "The realm forgotten")
        for _ in 0..<500 where !(await db.companions).isEmpty { try await Task.sleep(nanoseconds: 20_000_000) }
        let left = await db.companions
        XCTAssertTrue(left.isEmpty, "Let go at the realm")
        mac.close()
    }

    /// Counsel from the phone: its commander told of the realm from the
    /// keeper's view as the phone holds it, and remembering what was said
    /// on this phone this age, and nothing of an age gone by; another
    /// House's commander isn't the phone's to ask; and let go, the phone
    /// forgets every word of it.
    func testCounselOnThePhoneIsTheKeepersAndStaysOnIt() async throws {
        let (db, running, mac, keeper, _) = try await realm()
        defer { running.cancel() }
        let memory = PassingMemory()
        let store = MemoryStore()
        let phone = CompanionSession(memory: memory) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let house = try XCTUnwrap(keeper.house)
        XCTAssertNil(phone.counsel(of: 1), "Speaking for no one, it asks no commander")
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping }
        let world = try XCTUnwrap(phone.world)
        let commander = try XCTUnwrap(phone.ledger?.commanders.first(where: \.canCounsel))
        let taken = try XCTUnwrap(phone.counsel(of: commander.id))
        XCTAssertEqual(taken.counsel.player, house)
        XCTAssertEqual(taken.counsel.commander.name, commander.name)
        XCTAssertTrue(taken.counsel.instructions.contains("of the House of \(world.houses[house].title)"), taken.counsel.instructions)
        XCTAssertTrue(taken.counsel.briefing.hasPrefix("It is watch \(world.watch)."), "Briefed from the keeper's view as the phone holds it")
        XCTAssertTrue(taken.memory.exchanges.isEmpty)
        let age = phone.status?.age ?? 0
        XCTAssertEqual(taken.memory.age, age)
        if let theirs = world.roster.first(where: { $0.owner != house }) {
            XCTAssertNil(phone.counsel(of: theirs.id), "Another House's commander")
        }

        // Remembered here, and recalled next counsel; an age gone by forgotten.
        var said = taken.memory
        said.remember("What do you see?", "The water lies still to the east.", at: world.watch)
        phone.remember(said)
        XCTAssertEqual(phone.counsel(of: commander.id)?.memory.exchanges.map(\.answered), ["The water lies still to the east."])
        memory.counsel[commander.id] = CounselMemory(commander: commander.id, age: age - 1,
                                                     exchanges: [.init(watch: 1, asked: "Old", answered: "An age gone by.")])
        XCTAssertEqual(phone.counsel(of: commander.id)?.memory.exchanges, [], "Nothing of an age gone by")
        phone.remember(said)
        XCTAssertEqual(memory.counsel.count, 1)

        // Let go: every word of it forgotten, and nothing kept after.
        phone.unlink()
        XCTAssertTrue(memory.counsel.isEmpty)
        phone.remember(said)
        XCTAssertTrue(memory.counsel.isEmpty, "Linked to no realm, it keeps no counsel")
        XCTAssertNil(phone.counsel(of: commander.id))
        mac.close()
    }

    /// The realm's other words, as the phone hears them while it keeps the
    /// House: an order the realm refused, its reason told with the world as
    /// it stands; a refusal of anything else, told as itself; the world
    /// settled after an order, the order carried out; readiness as the
    /// realm last said; news alone, nothing changed.
    func testTheRealmsOtherWordsAreToldAsTheyCome() async throws {
        let (db, running, mac, _, _) = try await realm()
        defer { running.cancel() }
        let store = MemoryStore()
        let phone = CompanionSession(memory: PassingMemory()) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping }
        let world = try XCTUnwrap(phone.world)
        let company = try XCTUnwrap(phone.ledger?.companies.first { $0.orders.contains { $0.title == "Fortify" } })

        phone.give(.fortify(unit: company.id), told: "Fortify the \(company.name)")
        phone.hear(.orderRefused(.rule(.notYours), world))
        XCTAssertEqual(phone.word?.refused, true)
        XCTAssertEqual(phone.word?.awaited, false)
        XCTAssertTrue(phone.word?.text.hasPrefix("Fortify the \(company.name): the realm refused it.") == true, phone.word?.text ?? "")
        XCTAssertEqual(phone.world?.unit(company.id)?.fortified, world.unit(company.id)?.fortified, "The world as the realm holds it")

        phone.hear(.refused(.manyNewcomers))
        XCTAssertEqual(phone.phase, .keeping, "Still in")
        XCTAssertEqual(phone.word, CompanionSession.Word(text: RealmError.manyNewcomers.description, refused: true, awaited: false))

        phone.give(.fortify(unit: company.id), told: "Fortify the \(company.name)")
        XCTAssertEqual(phone.word?.awaited, true)
        phone.hear(.settled(world, []))
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): carried out by the realm.")

        phone.hear(.readiness(true))
        XCTAssertTrue(phone.isReady)
        let before = phone.ledger
        phone.hear(.heard([]))
        XCTAssertEqual(phone.ledger, before, "News alone changes nothing")
        phone.unlink()
        mac.close()
    }

    /// A realm too old to link phones is said to be, and the phone asks for
    /// nothing more of it; one that can't be reached is told so.
    func testARealmThatCantLinkIsSaidToBe() async throws {
        let phone = CompanionSession(memory: PassingMemory()) { _ in nil }
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: "ABCD2345EFGH")))
        XCTAssertEqual(phone.phase, .pairing)
        XCTAssertTrue(phone.problem?.contains("can't reach a realm") == true)

        let store = MemoryStore()
        let db = FakeSpacetime()
        let old = CompanionSession(memory: PassingMemory()) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 60) }
        old.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: "ABCD2345EFGH")))
        XCTAssertEqual(old.phase, .entering)
        old.hear(.status(RealmStatus(name: "Old", age: 1, watch: 1, seats: 4, freeSeats: 4, keepers: 0, online: 0, ready: 0,
                                     secondsLeft: 100, isEnding: false, speech: 12, oldestSpeech: 12)))
        XCTAssertEqual(old.phase, .pairing)
        XCTAssertEqual(old.problem, CompanionSession.tooOld)
        old.hear(.unreachable("The realm can't be reached."))
        XCTAssertEqual(old.outOfReach, "The realm can't be reached.")
        XCTAssertEqual(old.secondsLeft(at: Date().addingTimeInterval(1_000)), 0, "Counted down to nothing, never below")
    }
}
