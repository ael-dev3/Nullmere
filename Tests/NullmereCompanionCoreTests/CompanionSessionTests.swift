import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
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

    /// The places a keeper keeps in their phone's own book (Rise of
    /// Kingdoms' bookmarks), as their Mac keeps its own: none until kept;
    /// each kept by the name it goes by or one of the keeper's, the newest
    /// first, once to a hex, a score at most; let go; kept in the phone's
    /// memory for the age, none of another; forgotten with the rest when
    /// the phone is let go.
    func testThePhoneKeepsItsOwnBookOfPlaces() async throws {
        let (db, running, mac, keeper, _) = try await realm()
        defer { running.cancel() }
        let memory = PassingMemory()
        let store = MemoryStore()
        let phone = CompanionSession(memory: memory) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        XCTAssertFalse(phone.keepPlace(Hex(0, 0)), "Speaking for no keeper, it keeps nothing")
        XCTAssertNil(memory.places)
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping && phone.status != nil }
        let world = try XCTUnwrap(phone.world)
        let age = try XCTUnwrap(phone.status?.age)
        let seat = try XCTUnwrap(world.seat(of: try XCTUnwrap(keeper.house)))
        XCTAssertTrue(phone.placeBook.places.isEmpty)
        XCTAssertEqual(phone.placeBook.summary, "No places kept. Keep one from a hold or the ground to come back to it.")

        // The seat by the name it goes by; ground beside it by the keeper's
        // own name, or by its own where the keeper's is empty.
        let ground = try XCTUnwrap(seat.position.neighbors.first { world.hold(at: $0) == nil })
        let farther = try XCTUnwrap(ground.neighbors.first { $0 != seat.position && $0 != ground && world.hold(at: $0) == nil })
        XCTAssertTrue(phone.keepPlace(seat.position))
        XCTAssertTrue(phone.keepPlace(ground, named: "  The ford\n by the seat "))
        XCTAssertTrue(phone.keepPlace(farther, named: " \n "))
        XCTAssertEqual(phone.placeBook.places.map(\.name), [world.keptName(of: farther), "The ford by the seat", seat.name], "The newest first")
        XCTAssertEqual(phone.placeBook.place(at: seat.position)?.kept, world.watch)
        XCTAssertEqual(world.keptLine(try XCTUnwrap(phone.placeBook.place(at: seat.position))), "Kept at watch \(world.watch)")
        XCTAssertEqual(world.keptLine(try XCTUnwrap(phone.placeBook.place(at: ground))),
                       "\(world.keptName(of: ground)), kept at watch \(world.watch)", "What it goes by now, beside the keeper's name")
        XCTAssertEqual(phone.placeBook.summary, "3 places kept, the newest \(world.keptName(of: farther)).")
        XCTAssertFalse(phone.keepPlace(seat.position, named: "Home"), "Once to a hex")
        XCTAssertEqual(memory.places, PhonePlaces(age: age, book: phone.placeBook), "Kept in the phone's memory for the age")
        let written = try JSONEncoder().encode(try XCTUnwrap(memory.places))
        XCTAssertEqual(try JSONDecoder().decode(PhonePlaces.self, from: written), memory.places, "As the phone's defaults keep it")

        // Named anew, kept since it was kept; never by no name, nor a place
        // the book doesn't keep.
        XCTAssertTrue(phone.renamePlace(ground, to: "  The ford\n at dusk "))
        XCTAssertEqual(phone.placeBook.place(at: ground)?.name, "The ford at dusk")
        XCTAssertEqual(phone.placeBook.place(at: ground)?.kept, world.watch)
        XCTAssertFalse(phone.renamePlace(ground, to: " \n "))
        XCTAssertFalse(phone.renamePlace(Hex(seat.position.q + 40, seat.position.r), to: "Nowhere"))
        XCTAssertEqual(memory.places?.book.place(at: ground)?.name, "The ford at dusk", "kept in the phone's memory too")

        // Shared with the realm in the words, its place with them, as the
        // Mac shares one; looked to from the words, the chart asked to turn
        // there, once.
        phone.give(.sharePlace(at: seat.position, named: seat.name, toAlliance: false), told: "\(seat.name), shared with the realm")
        try await until("the place shared in the realm's words") {
            phone.ledger?.realmWords.contains { $0.place?.at == seat.position } == true
        }
        let shared = try XCTUnwrap(phone.ledger?.realmWords.last { $0.place != nil })
        XCTAssertEqual(shared.place, SharedPlace(at: seat.position, name: seat.name))
        XCTAssertEqual(shared.text, seat.name)
        XCTAssertTrue(shared.isOwn)
        XCTAssertNil(phone.lookingTo)
        phone.look(to: seat.position)
        XCTAssertEqual(phone.lookingTo, seat.position)
        XCTAssertEqual(phone.takeLook(), seat.position)
        XCTAssertNil(phone.lookingTo)
        XCTAssertNil(phone.takeLook(), "taken once")

        // Let go, one place; one the book doesn't keep changes nothing.
        phone.forgetPlace(ground)
        XCTAssertNil(phone.placeBook.place(at: ground))
        phone.forgetPlace(Hex(seat.position.q + 40, seat.position.r))
        XCTAssertEqual(phone.placeBook.places.map(\.at), [farther, seat.position])
        XCTAssertEqual(memory.places?.book, phone.placeBook)

        // A score at most, and why no more.
        var q = 0
        while !phone.placeBook.isFull {
            q += 1
            XCTAssertTrue(phone.keepPlace(Hex(seat.position.q + 30 + q, seat.position.r)))
        }
        XCTAssertEqual(phone.placeBook.places.count, PlaceBook.limit)
        XCTAssertFalse(phone.keepPlace(ground))
        XCTAssertEqual(phone.placeBook.refusal, "Your book keeps \(PlaceBook.limit) places: forget one to keep another.")

        // A book of an age gone by is none of this one's, and keeping begins
        // this age's anew.
        memory.places = PhonePlaces(age: age - 1, book: phone.placeBook)
        XCTAssertTrue(phone.placeBook.places.isEmpty, "Nothing of an age gone by")
        XCTAssertTrue(phone.keepPlace(ground))
        XCTAssertEqual(memory.places?.age, age)
        XCTAssertEqual(phone.placeBook.places.map(\.at), [ground])

        // Let go from the phone: its book forgotten, and nothing kept after.
        phone.unlink()
        XCTAssertNil(memory.places)
        XCTAssertTrue(phone.placeBook.places.isEmpty)
        XCTAssertFalse(phone.keepPlace(ground), "Linked to no realm, it keeps no places")
        XCTAssertFalse(phone.renamePlace(ground, to: "Home"))
        XCTAssertNil(memory.places)
        mac.close()
    }

    /// The realm's other words, as the phone hears them while it keeps the
    /// House: an order the realm refused, its reason told with the world as
    /// it stands; a refusal of anything else, told as itself; the world
    /// settled after an order shown, and the order carried out once it is
    /// answered, as a realm in this process answers it; readiness as the
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
        XCTAssertEqual(phone.word?.awaited, true, "The world shown; the order not yet answered")
        phone.hear(.answered([]))
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): carried out by the realm.")

        phone.hear(.readiness(true))
        XCTAssertTrue(phone.isReady)
        let before = phone.ledger
        phone.hear(.heard([]))
        XCTAssertEqual(phone.ledger, before, "News alone changes nothing")

        // Battles the House had a part in filed as reports, as the Mac files
        // them, the latest first; none of battles it had no part in.
        let me = try XCTUnwrap(phone.keeper?.house)
        let foe = (me + 1) % world.houses.count
        let other = (me + 2) % world.houses.count
        let seat = try XCTUnwrap(world.seat(of: me))
        func battle(_ attacker: Int, _ defender: Int, fell: Bool) -> Battle {
            Battle(attacker: 90, attackerOwner: attacker, attackerKind: .rider, defender: 91, defenderOwner: defender, defenderKind: .spear,
                   hold: nil, at: seat.position, damageDealt: 30, damageTaken: 10, attackerFell: false, defenderFell: fell)
        }
        XCTAssertTrue(phone.reports.isEmpty)
        phone.hear(.settled(world, [.battle(battle(me, foe, fell: true)), .battle(battle(foe, other, fell: true))]))
        XCTAssertEqual(phone.reports.map(\.outcome), [.won], "None for a battle the House had no part in")
        XCTAssertEqual(phone.reports.first, world.report(of: battle(me, foe, fell: true), id: 1, for: me))
        phone.hear(.heard([.battle(battle(foe, me, fell: false))]))
        phone.hear(.watchTurned(world, [.battle(battle(foe, me, fell: true))]))
        XCTAssertEqual(phone.reports.map(\.id), [3, 2, 1], "The latest first")
        XCTAssertEqual(phone.reports.first?.outcome, .lost)

        // A field of battle a commander of the House led in: the phone may
        // ask them of it, as the Mac may, and their counsel remembers it.
        let commander = try XCTUnwrap(world.commanders(of: me).first { $0.captive == nil })
        var field = Field(id: 77, at: seat.position, joined: world.watch, first: me, second: foe)
        field.fighters = [Fighter(unit: 90, owner: me, side: 0, kind: .spear, tier: 1, leader: commander.name, troops: 1_000),
                          Fighter(unit: 91, owner: foe, side: 1, kind: .spear, tier: 1, leader: nil, troops: 900)]
        field.held = 0
        phone.hear(.heard([.fieldEnded(field)]))
        let led = try XCTUnwrap(phone.reports.first)
        XCTAssertEqual(led.led, [commander.name])
        XCTAssertEqual(phone.askable(of: led)?.id, commander.id)
        XCTAssertNil(phone.askable(of: phone.reports[1]), "A report naming none of its commanders offers no one")
        XCTAssertEqual(phone.counsel(of: commander.id)?.counsel.battles.map(\.id), [led.id], "Briefed with the battle they led")
        phone.unlink()
        XCTAssertTrue(phone.reports.isEmpty, "Forgotten with the link")
        XCTAssertNil(phone.askable(of: led), "Speaking for no one, it asks no one")
        mac.close()
    }

    /// The realm lost while the phone keeps the House: it says so, keeps the
    /// House as it last stood and stays in; when the realm answers again it
    /// says no more of it, and an order given then is carried out by the
    /// realm, without the phone set aside or linked again.
    func testTheRealmLostAndFoundAgainThePhoneKeepsTheHouse() async throws {
        let (db, running, mac, keeper, _) = try await realm()
        defer { running.cancel() }
        let store = MemoryStore()
        let phone = CompanionSession(memory: PassingMemory()) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping }
        let company = try XCTUnwrap(phone.ledger?.companies.first { $0.orders.contains { $0.title == "Fortify" } })

        await db.setReachable(false)
        try await until("the realm said out of reach", timeout: 30) { phone.outOfReach != nil }
        XCTAssertEqual(phone.phase, .keeping, "Still in, the House as it last stood")
        XCTAssertNotNil(phone.ledger)
        XCTAssertEqual(phone.keeper?.id, keeper.id)
        // Said while the realm is out of reach: told it waits, not that it went.
        phone.say("Hold the ford.", toAlliance: false)
        XCTAssertEqual(phone.word?.text, "Said to the realm: \(CompanionSession.waitsForReach)")
        XCTAssertEqual(phone.word?.awaited, true)

        var macWorld: GameState?
        mac.onEvent = { event in
            switch event {
            case .changed(let world), .watchTurned(let world, _), .settled(let world, _): macWorld = world
            default: break
            }
        }
        await db.setReachable(true)
        try await until("the realm in reach again", timeout: 30) { phone.outOfReach == nil }
        // What was said while it was out of reach is carried out, and told so.
        try await until("the realm's word on what was said while out of reach", timeout: 30) {
            phone.word?.text == "Said to the realm: carried out by the realm."
        }
        phone.give(.fortify(unit: company.id), told: "Fortify the \(company.name)")
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): sent to the realm.", "In reach, sent")
        try await until("the realm's word on the order", timeout: 30) { phone.word?.awaited == false }
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): carried out by the realm.")
        try await until("the order seen on the Mac, in reach again too", timeout: 60) { macWorld?.unit(company.id)?.fortified == true }
        phone.unlink()
        mac.close()
    }

    /// Orders given one after another before the realm answers the first are
    /// each told the realm's own word, in the order given, as the link sends
    /// them; one still unanswered when the phone is set aside is told so,
    /// never left waiting on a word that won't come.
    func testEachOrderIsToldTheRealmsWordOnItself() async throws {
        let (db, running, mac, _, _) = try await realm()
        defer { running.cancel() }
        let store = MemoryStore()
        let phone = CompanionSession(memory: PassingMemory()) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping }
        let company = try XCTUnwrap(phone.ledger?.companies.first { $0.orders.contains { $0.title == "Fortify" } })

        // Both wait while the realm is out of reach, each said to.
        await db.setReachable(false)
        try await until("the realm said out of reach", timeout: 30) { phone.outOfReach != nil }
        phone.say("Hold the ford.", toAlliance: false)
        phone.give(.fortify(unit: company.id), told: "Fortify the \(company.name)")
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): \(CompanionSession.waitsForReach)")

        // The realm's word on each, the first given first.
        phone.hear(.answered([]))
        XCTAssertEqual(phone.word?.text, "Said to the realm: carried out by the realm.", "The first answer is the first order's")
        let world = try XCTUnwrap(phone.world)
        phone.hear(.orderRefused(.refused("The realm refused the order."), world))
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): the realm refused it. The realm refused the order.")
        XCTAssertEqual(phone.word?.refused, true)
        phone.hear(.answered([]))
        XCTAssertEqual(phone.word?.text, "Fortify the \(company.name): the realm refused it. The realm refused the order.",
                       "No order waiting, no word on one")

        // Given, then set aside before the realm answers: told so.
        phone.say("And the bridge.", toAlliance: false)
        XCTAssertEqual(phone.word?.awaited, true)
        phone.pause()
        XCTAssertEqual(phone.word?.text, "Said to the realm: \(CompanionSession.letGo)")
        XCTAssertEqual(phone.word?.awaited, false)
        phone.unlink()
        mac.close()
    }

    /// Set aside while the realm goes on, the phone is told as it comes in
    /// again what happened to the House meanwhile, as the Mac tells it, until
    /// the keeper puts it away; let go, it remembers nothing of it.
    func testThePhoneTellsWhatHappenedWhileItWasAway() async throws {
        let (db, running, mac, keeper, steward) = try await realm()
        defer { running.cancel() }
        let memory = PassingMemory()
        let store = MemoryStore()
        let phone = CompanionSession(memory: memory) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping }
        XCTAssertNil(phone.away, "Nothing to tell, the first time in")
        let house = try XCTUnwrap(keeper.house)
        let watch = try XCTUnwrap(phone.world?.watch)

        phone.pause()
        XCTAssertEqual(memory.lastSeen?.watch, watch, "What the phone last saw, kept")
        await steward.reshape { state in state.world.houses[house].stock = Stock(grain: 777, timber: 666, stone: 555, moonsalt: 44) }
        var turned = false
        mac.onEvent = { if case .watchTurned = $0 { turned = true } }
        mac.setReady(true)
        try await until("the watch turned while the phone was away") { turned }

        phone.resume()
        try await until("in again") { phone.phase == .keeping }
        let away = try XCTUnwrap(phone.away)
        XCTAssertGreaterThanOrEqual(away.watches, 1)
        XCTAssertTrue(away.title.hasPrefix("While you were away"), away.title)
        XCTAssertFalse(away.changes.isEmpty, "The stores' change told")
        // Its caretaker's word, given first by the phone's own model, keyed
        // as the Mac keys it, from what the report holds.
        let title = try XCTUnwrap(phone.world).houses[house].title
        XCTAssertEqual(phone.voicedMoments.first?.key, "caretaker-\(away.watch)")
        XCTAssertEqual(phone.voicedMoments.first?.moment, away.voiced(house: title))
        XCTAssertEqual(phone.voicedMoments.count, 1 + (phone.ledger?.voices.count ?? 0))
        phone.dismissAway()
        XCTAssertNil(phone.away)
        XCTAssertFalse(phone.voicedMoments.contains { $0.key.hasPrefix("caretaker-") }, "put away, no word wanted")

        phone.unlink()
        XCTAssertNil(memory.lastSeen, "Let go, it remembers nothing of the House")
        XCTAssertNil(phone.away)
        mac.close()
    }

    /// The keeper's own record kept fresh on the phone as the watches turn,
    /// over the network: the favour won and the watches kept as the realm
    /// keeps them, not as they stood when the phone came in.
    func testThePhoneKeepsTheKeepersFavourAsTheWatchesTurn() async throws {
        let (db, running, mac, _, _) = try await realm()
        defer { running.cancel() }
        let phone = CompanionSession(memory: PassingMemory()) { _ in
            NetworkRealmLink(transport: db, credentials: MemoryStore(), pollInterval: 0.05)
        }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in as the keeper") { phone.phase == .keeping }
        let before = phone.keeper
        let watch = try XCTUnwrap(phone.world?.watch)
        mac.setReady(true)
        try await until("the watch turned on the phone") { (phone.world?.watch ?? 0) > watch }
        try await until("the keeper's record told anew") { phone.keeper != before }
        XCTAssertGreaterThan(phone.keeper?.favour ?? 0, before?.favour ?? 0, "Favour won for the watch kept")
        XCTAssertEqual(phone.keeper?.id, before?.id, "The same keeper")
        phone.unlink()
        mac.close()
    }

    /// The keeper asks to hear a commander of theirs from the phone, or a
    /// hold's reeve: their word is asked of the phone's own model first,
    /// keyed as the Mac keys it, from what the House knows alone; a company
    /// no commander leads has no word, nor another House's hold; let go, no
    /// one is heard.
    func testTheKeeperHearsACommanderOfTheirsFirst() async throws {
        let (db, running, mac, keeper, steward) = try await realm()
        defer { running.cancel() }
        let house = try XCTUnwrap(keeper.house)
        await steward.reshape { state in
            guard let commander = state.world.commanders(of: house).first,
                  let index = state.world.units.firstIndex(where: { $0.owner == house && $0.kind.isMilitary }) else { return }
            state.world.units[index].leader = commander.id
        }
        let store = MemoryStore()
        let phone = CompanionSession(memory: PassingMemory()) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in, a company of the House led") {
            phone.phase == .keeping && phone.world?.units(of: house).contains { $0.leader != nil } == true
        }
        let world = try XCTUnwrap(phone.world)
        let led = try XCTUnwrap(world.units(of: house).first { $0.leader != nil })
        let counsel = try XCTUnwrap(CommanderCounsel(state: world, player: house, commander: try XCTUnwrap(led.leader), reports: phone.reports))
        let key = try XCTUnwrap(counsel.wordKey)
        let word = try XCTUnwrap(phone.commanderWord(of: led.id))
        XCTAssertEqual(word.key, "commander-\(key)", "kept as the Mac keeps it")
        XCTAssertEqual(word.key, CompanionSession.commanderKey(key))
        XCTAssertEqual(word.moment, counsel.word, "from what the House knows of the company alone")
        XCTAssertFalse(phone.voicedMoments.contains { $0.key.hasPrefix("commander-") }, "none heard until asked")
        phone.hear(company: led.id)
        XCTAssertEqual(phone.hearing, .company(led.id))
        XCTAssertEqual(phone.voicedMoments.first, word, "the commander the keeper asked to hear, first")
        XCTAssertEqual(phone.voicedMoments.count, 1 + (phone.ledger?.voices.count ?? 0))
        if let unled = world.units(of: house).first(where: { $0.leader == nil }) {
            XCTAssertNil(phone.commanderWord(of: unled.id))
            phone.hear(company: unled.id)
            XCTAssertFalse(phone.voicedMoments.contains { $0.key.hasPrefix("commander-") }, "no commander, no word")
        }
        for foreign in world.units where foreign.owner != house {
            XCTAssertNil(phone.commanderWord(of: foreign.id), "another House's commanders are not the keeper's to hear")
        }
        // The reeve of the keeper's seat, heard as the keeper asks.
        let seat = try XCTUnwrap(world.seat(of: house))
        let reeve = try XCTUnwrap(phone.reeveWord(of: seat.id))
        XCTAssertEqual(reeve.key, CompanionSession.reeveKey(try XCTUnwrap(world.reeveWordKey(of: seat.id, for: house))), "kept as the Mac keeps it")
        XCTAssertEqual(reeve.moment, world.reeveWord(of: seat.id, for: house))
        phone.hear(hold: seat.id)
        XCTAssertEqual(phone.hearing, .hold(seat.id))
        XCTAssertEqual(phone.voicedMoments.first, reeve, "the reeve the keeper asked to hear, first")
        XCTAssertFalse(phone.voicedMoments.contains { $0.key.hasPrefix("commander-") }, "one heard at a time")
        for foreign in world.holds where foreign.owner != house {
            XCTAssertNil(phone.reeveWord(of: foreign.id), "another House's reeves are not the keeper's to hear")
        }
        // The Lanterns back from a hold they scouted, heard from their report
        // as the keeper asks, keyed as the Mac keys it; none for a battle.
        let scouted = BattleReport(id: 77, watch: world.watch, title: "Your Lanterns scouted Corfall, a hold of House Venn",
                                   place: "by the Reach", outcome: .scouted, lines: ["No company at its gates", "Its ward 30 of 40"])
        let lanterns = try XCTUnwrap(phone.scoutWord(of: scouted))
        XCTAssertEqual(lanterns.key, CompanionSession.scoutKey(try XCTUnwrap(scouted.scoutWordKey)), "kept as the Mac keeps it")
        XCTAssertEqual(lanterns.moment, scouted.scoutWord, "from their report alone")
        XCTAssertNil(phone.scoutWord(of: BattleReport(id: 78, watch: world.watch, title: "Your Spears struck the wilds", place: "",
                                                      outcome: .won, lines: [])))
        phone.hear(report: scouted.id)
        XCTAssertEqual(phone.hearing, .report(scouted.id))
        XCTAssertFalse(phone.voicedMoments.contains { $0.key.hasPrefix("scout-") }, "a report the phone never filed is not heard")
        phone.unlink()
        XCTAssertNil(phone.hearing)
        XCTAssertNil(phone.commanderWord(of: led.id), "let go, no one is heard")
        XCTAssertNil(phone.reeveWord(of: seat.id))
        XCTAssertNil(phone.scoutWord(of: scouted))
        mac.close()
    }

    /// A chest of the Lantern Inn opened from the phone: the realm's word on
    /// it says what it held, as the Mac tells it, and the key is spent.
    func testAChestOfTheInnOpenedFromThePhoneSaysWhatItHeld() async throws {
        let (db, running, mac, keeper, steward) = try await realm()
        defer { running.cancel() }
        let house = try XCTUnwrap(keeper.house)
        await steward.reshape { state in state.world.innBook = [house: InnKeys(silver: 1, gold: 0, sinceCommander: 0, opened: 0)] }
        let store = MemoryStore()
        let phone = CompanionSession(memory: PassingMemory()) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in, a silver key to spend") { phone.ledger?.inn.opens.contains { $0.command == .openInnChest(.silver) } == true }
        let open = try XCTUnwrap(phone.ledger?.inn.opens.first { $0.command == .openInnChest(.silver) })
        phone.give(open.command, told: open.title)
        try await until("the realm's word on the chest") { phone.word?.awaited == false }
        let word = try XCTUnwrap(phone.word?.text)
        XCTAssertTrue(word.hasPrefix("Open a silver chest: carried out by the realm. The Inn's silver chest holds "), word)
        try await until("the key spent") { phone.ledger?.inn.opens.contains { $0.command == .openInnChest(.silver) } == false }
        phone.unlink()
        mac.close()
    }

    /// A commander sent up the Spine from the phone: the realm's word on it
    /// says how it went, as the Mac tells it, and no other goes this watch.
    func testAVentureUpTheSpineFromThePhoneSaysHowItWent() async throws {
        let (db, running, mac, _, _) = try await realm()
        defer { running.cancel() }
        let store = MemoryStore()
        let phone = CompanionSession(memory: PassingMemory()) { _ in NetworkRealmLink(transport: db, credentials: store, pollInterval: 0.05) }
        let code = try await offer(mac)
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: code)))
        try await until("the phone in, a commander to send") { phone.ledger?.spine.ventures.isEmpty == false }
        let venture = try XCTUnwrap(phone.ledger?.spine.ventures.last)
        phone.give(venture.command, told: venture.title)
        try await until("the realm's word on the venture") { phone.word?.awaited == false }
        let word = try XCTUnwrap(phone.word?.text)
        XCTAssertTrue(word.hasPrefix("\(venture.title): carried out by the realm. "), word)
        XCTAssertTrue(word.contains(" takes the Scree Gate, stage 1 of the Spine") || word.contains(" is thrown back from the Scree Gate"), word)
        try await until("none sent again this watch") { phone.ledger?.spine.ventures.isEmpty == true }
        phone.unlink()
        mac.close()
    }

    /// A phone with no network says so of itself, never of a Mac: the
    /// realm's troubles are told on the phone in the phone's own words.
    func testAPhoneWithNoNetworkSaysSoOfItself() async throws {
        let phone = CompanionSession(memory: PassingMemory()) { _ in
            NetworkRealmLink(transport: Offline(), credentials: MemoryStore(), pollInterval: 0.05)
        }
        phone.take(try XCTUnwrap(CompanionInvite(realm: try XCTUnwrap(URL(string: "https://realm.example/n")), code: "ABCD2345EFGH")))
        try await until("the code's taking failed") { phone.phase == .pairing }
        XCTAssertEqual(phone.problem, "This phone isn't connected to the internet.")
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

/// A phone with no network at all: nothing it asks of the realm leaves it.
private struct Offline: SpacetimeTransport {
    func createIdentity() async throws -> SpacetimeCredentials { throw URLError(.notConnectedToInternet) }
    func call(_ reducer: String, _ arguments: [ReducerArgument], token: String) async throws { throw URLError(.notConnectedToInternet) }
    func query(_ sql: String, token: String) async throws -> [[JSONValue]] { throw URLError(.notConnectedToInternet) }
}
