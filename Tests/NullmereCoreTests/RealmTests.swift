import Foundation
import XCTest
@testable import NullmereCore

final class RealmTests: XCTestCase {
    /// The CPU time this thread has spent, in seconds.
    static func threadCPUSeconds() -> Double {
        var time = timespec()
        clock_gettime(CLOCK_THREAD_CPUTIME_ID, &time)
        return Double(time.tv_sec) + Double(time.tv_nsec) / 1e9
    }

    private func realm(seats: Int = 4, watchLength: Double = 60) -> RealmState {
        RealmState(name: "The Nullmere", seed: "realm test", seats: seats, radius: 18, watchLength: watchLength, now: 0)
    }

    func testANewRealmIsHeldByStewards() {
        let realm = realm()
        XCTAssertEqual(realm.world.houses.count, 4)
        XCTAssertTrue(realm.world.houses.allSatisfy { !$0.isPlayer }, "No keeper yet")
        XCTAssertEqual(Set(realm.world.houses.map(\.name)).count, 4, "Every House its own name")
        XCTAssertEqual(realm.status(now: 0).freeSeats, 4)
    }

    func testTheRealmProperSeatsTwelveFairly() throws {
        // One realm made and played first, untimed: the first a process
        // makes pays for what every later one finds made (tables, caches,
        // the allocator's first pages), which is no part of a watch's cost.
        var warming = RealmState(name: "The Nullmere", seed: "warming", now: 0)
        warming.arriveIfNeeded()
        _ = warming.tick(now: 1e12)
        for seed in ["twelve a", "twelve b", "twelve c"] {
            let started = Date()
            let cpuStarted = RealmTests.threadCPUSeconds()
            var realm = RealmState(name: "The Nullmere", seed: seed, now: 0)
            XCTAssertEqual(realm.seats, 12)
            XCTAssertEqual(realm.world.houses.count, 12)
            XCTAssertEqual(Set(realm.world.houses.map(\.name)).count, 12, "Every House its own name")
            XCTAssertEqual(Set(realm.world.houses.map(\.sigil)).count, 12, "and its own colours")
            let seats = realm.world.houses.compactMap { realm.world.seat(of: $0.id)?.position }
            XCTAssertEqual(seats.count, 12)
            var nearest = Int.max
            for (index, seat) in seats.enumerated() {
                for other in seats[(index + 1)...] { nearest = min(nearest, seat.distance(to: other)) }
            }
            XCTAssertGreaterThanOrEqual(nearest, 6, "Room between the seats (\(seed))")
            // A keeper takes one seat, and eleven stewards play thirty
            // watches in good time.
            realm.arriveIfNeeded()
            for _ in 0..<30 {
                _ = realm.tick(now: 1e12)
                realm.arriveIfNeeded()
            }
            let seconds = Date().timeIntervalSince(started)
            print("PERF realm of 12 (\(seed)): made and 30 watches in \(String(format: "%.2f", seconds)) s")
            // Held to its baseline by this thread's own CPU time, which
            // others' work on a shared runner doesn't stretch.
            let cpu = RealmTests.threadCPUSeconds() - cpuStarted
            print("PERFMETRIC realm.watch.\(seed.replacingOccurrences(of: " ", with: "-")) \(String(format: "%.3f", cpu * 1000 / 30))")
            XCTAssertLessThan(seconds, 60)
        }
    }

    func testKeepersArriveAndTakeSeats() throws {
        var realm = realm()
        let ilsen = try realm.arrive("id-ilsen", name: "  Ilsen ", now: 1)
        XCTAssertEqual(ilsen.name, "Ilsen")
        let seat = try XCTUnwrap(ilsen.house)
        XCTAssertTrue(realm.world.houses[seat].isPlayer)
        XCTAssertEqual(realm.world.houses[seat].title, "House Ilsen")
        XCTAssertTrue(realm.world.chronicle.contains { $0.text.contains("House Ilsen takes its seat") })

        XCTAssertThrowsError(try realm.arrive("id-other", name: "ilsen", now: 2)) { XCTAssertEqual($0 as? RealmError, .nameTaken) }
        let steward = realm.world.houses.first { !$0.isPlayer }!.name
        XCTAssertThrowsError(try realm.arrive("id-other", name: steward, now: 2)) { XCTAssertEqual($0 as? RealmError, .nameTaken) }
        for bad in ["", "x", "Name1", "-Ilsa", String(repeating: "a", count: 21)] {
            XCTAssertThrowsError(try realm.arrive("id-bad", name: bad, now: 2), bad) { XCTAssertEqual($0 as? RealmError, .nameInvalid) }
        }
        XCTAssertTrue(RealmState.isValidName("Mara d'Ost"))

        // A keeper returns by identity alone, to the same House.
        realm.depart("id-ilsen", now: 0)
        XCTAssertFalse(realm.keeper("id-ilsen")!.isOnline)
        let back = try realm.arrive("id-ilsen", name: nil, now: 3)
        XCTAssertEqual(back.house, seat)
        XCTAssertEqual(realm.keepers.count, 1)
        XCTAssertThrowsError(try realm.arrive("id-stranger", name: nil, now: 3)) { XCTAssertEqual($0 as? RealmError, .nameInvalid) }
    }

    /// A name and an identity are had for the asking, so the realm takes in
    /// new keepers a few at a time: one person can't fill the lake with
    /// names in a moment. Keepers it knows come and go as they please.
    func testKeepersNewToTheRealmComeInAFewAtATime() throws {
        var realm = realm()
        for (index, name) in ["Ama", "Bel", "Cor"].enumerated() {
            XCTAssertNotNil(try realm.arrive("id-\(index)", name: name, now: Double(index)).house)
        }
        XCTAssertThrowsError(try realm.arrive("id-dee", name: "Dee", now: 30)) {
            XCTAssertEqual($0 as? RealmError, .manyNewcomers)
        }
        XCTAssertNil(realm.keeper("id-dee"), "Not taken in, so no name held")
        realm.depart("id-0", now: 31)
        XCTAssertNotNil(try realm.arrive("id-0", name: nil, now: 32).house, "Ama, known, comes back at once")
        // A watch's length after the first came in, another may.
        XCTAssertNotNil(try realm.arrive("id-dee", name: "Dee", now: 60).house)
        XCTAssertThrowsError(try realm.arrive("id-eno", name: "Eno", now: 60))
        XCTAssertEqual(realm.keepers.map(\.arrival), [0, 1, 2, 3], "Each in the order they came")
    }

    /// A keeper long gone with no seat is forgotten, their name free again;
    /// a seat keeps its keeper's place however long they are away.
    func testAKeeperLongGoneWithNoSeatIsForgotten() throws {
        var realm = realm(seats: 2)
        try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        XCTAssertNil(try realm.arrive("c", name: "Cor", now: 0).house)
        realm.depart("a", now: 10)
        realm.depart("c", now: 10)
        XCTAssertFalse(realm.forgetTheLongGone(now: 10 + RealmState.unplayedSeatHeldFor - 1))
        XCTAssertTrue(realm.forgetTheLongGone(now: 10 + RealmState.unplayedSeatHeldFor))
        XCTAssertEqual(realm.keepers.map(\.name), ["Ama", "Bel"], "Ama's seat keeps her place")
        XCTAssertEqual(try realm.arrive("d", name: "Cor", now: 20 + RealmState.unplayedSeatHeldFor).name, "Cor", "The name free again")
        XCTAssertEqual(realm.keeper("d")?.arrival, 2, "and its keeper after those still kept")
    }

    func testAFullRealmSeatsNoMore() throws {
        var realm = realm(seats: 2)
        try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        let late = try realm.arrive("c", name: "Cor", now: 0)
        XCTAssertNil(late.house)
        XCTAssertEqual(realm.status(now: 0).freeSeats, 0)
        XCTAssertEqual(realm.status(now: 0).present, ["Ama", "Bel", "Cor"], "Who is there, in the order they came")
        XCTAssertThrowsError(try realm.perform(.fortify(unit: 1), by: "c")) { XCTAssertEqual($0 as? RealmError, .noSeat) }
    }

    /// A realm has two to ninety-six seats, as many as one lake can seat;
    /// the steward refuses aloud to begin one of any other size, never
    /// making it another without a word. The realm proper seats twelve; a
    /// realm of more lies on a lake as much wider as keeps each seat as
    /// much country.
    func testARealmHasTwoToNinetySixSeats() {
        XCTAssertEqual(RealmState.seatRange, 2...96)
        XCTAssertEqual(RealmState.seatRange.upperBound, Names.houses.count, "A name for every House a lake seats")
        XCTAssertEqual(RealmState.defaultSeats, 12)
        for seats in [2, 7, 12] {
            XCTAssertEqual(realm(seats: seats).seats, seats)
            XCTAssertEqual(realm(seats: seats).world.houses.count, seats)
            XCTAssertEqual(RealmState.radius(forSeats: seats), RealmState.defaultRadius)
            XCTAssertTrue(realm(seats: seats).world.houses.allSatisfy { Names.elder.contains($0.name) }, "Only elder Houses at a lake of twelve or fewer")
        }
        XCTAssertEqual(RealmState.radius(forSeats: 13), 37)
        XCTAssertEqual(RealmState.radius(forSeats: 48), 72)
        XCTAssertEqual(RealmState.radius(forSeats: 96), 102)
        XCTAssertEqual(realm(seats: 2).radius, 18, "A lake as wide as asked, when asked")
    }

    /// A realm of forty-eight seats: the twelve elder Houses and thirty-six
    /// younger ones, each with its own name and colour, room between their
    /// seats on a lake twice as wide, and a keeper's watches passing there.
    func testARealmOfFortyEightSeatsSeatsEveryHouse() throws {
        let started = Date()
        var realm = RealmState(name: "The Wide Nullmere", seed: "forty-eight", seats: 48, now: 0)
        XCTAssertEqual(realm.radius, 72)
        XCTAssertEqual(realm.world.map.radius, 72)
        let names = realm.world.houses.map(\.name)
        XCTAssertEqual(Set(names).count, 48, "Every House its own name")
        XCTAssertTrue(Set(Names.elder).isSubset(of: Set(names)), "Every elder House seated")
        XCTAssertEqual(Set(realm.world.houses.map(\.sigil)).count, 48, "and its own colours")
        XCTAssertTrue(realm.world.houses.allSatisfy { Names.houses.firstIndex(of: $0.name) == $0.sigil }, "Each colour its name's")
        let seats = realm.world.houses.compactMap { realm.world.seat(of: $0.id)?.position }
        XCTAssertEqual(seats.count, 48)
        var nearest = Int.max
        for (index, seat) in seats.enumerated() {
            for other in seats[(index + 1)...] { nearest = min(nearest, seat.distance(to: other)) }
        }
        XCTAssertGreaterThanOrEqual(nearest, 6, "Room between the seats")
        XCTAssertEqual(realm.world.relations.count, 48 * 47 / 2)
        let keeper = try realm.arrive("wide", name: "Ama", now: 0)
        let house = try XCTUnwrap(keeper.house)
        XCTAssertEqual(realm.world.houses[house].name, "Ama")
        for _ in 0..<3 {
            realm.arriveIfNeeded()
            _ = realm.tick(now: 1e12)
        }
        XCTAssertEqual(realm.world.watch, 4)
        XCTAssertEqual(realm.world.livingHouses.count, 48)
        print("PERF realm of 48: made and 3 watches in \(String(format: "%.2f", Date().timeIntervalSince(started))) s")
    }

    func testASeatLongLeftGoesToAKeeperWhoIsWaiting() throws {
        var realm = realm(seats: 2)
        let ama = try realm.arrive("a", name: "Ama", now: 0)
        let bel = try realm.arrive("b", name: "Bel", now: 0)
        // Both came to play.
        for (id, keeper) in [("a", ama), ("b", bel)] {
            let spear = try XCTUnwrap(realm.world.units(of: keeper.house!).first { $0.kind == .spear })
            _ = try realm.perform(.fortify(unit: spear.id), by: id)
        }
        realm.depart("a", now: 100)
        realm.depart("b", now: 200)
        // A day away: Cor waits; the seats are kept.
        XCTAssertNil(try realm.arrive("c", name: "Cor", now: 200 + 24 * 3600).house)
        // A week: the seat left longest goes to Cor, its House as it stood.
        let stock = realm.world.houses[ama.house!].stock
        let cor = try realm.arrive("c", name: nil, now: 100 + RealmState.seatHeldFor)
        XCTAssertEqual(cor.house, ama.house)
        XCTAssertEqual(realm.world.houses[ama.house!].title, "House Cor")
        XCTAssertEqual(realm.world.houses[ama.house!].stock, stock)
        XCTAssertNil(realm.keeper("a")?.house)
        XCTAssertNotNil(realm.keeper("b")?.house, "Bel's week isn't up")
        XCTAssertTrue(realm.world.chronicle.contains { $0.text.contains("without its keeper") })
        // Ama, back at last, waits for a seat in turn.
        XCTAssertNil(try realm.arrive("a", name: nil, now: 100 + RealmState.seatHeldFor + 1).house)
        // A keeper who is there keeps their seat however long it's been.
        let dee = try realm.arrive("d", name: "Dee", now: 300 + RealmState.seatHeldFor * 2)
        XCTAssertNotNil(dee.house, "Bel's seat, a fortnight left")
        XCTAssertNil(try realm.arrive("e", name: "Eno", now: RealmState.seatHeldFor * 9).house, "Cor and Dee never left")
    }

    func testASeatTakenAndNeverPlayedIsHeldOnlyAnHour() throws {
        var realm = realm(seats: 2)
        let ama = try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        _ = realm.setReady("b", true, now: 1)
        realm.depart("a", now: 10)
        realm.depart("b", now: 10)
        XCTAssertNil(try realm.arrive("c", name: "Cor", now: 1800).house, "Half an hour: Ama's seat is kept")
        let cor = try realm.arrive("c", name: nil, now: 10 + RealmState.unplayedSeatHeldFor)
        XCTAssertEqual(cor.house, ama.house, "An hour, and Ama never played: Cor takes the seat")
        XCTAssertTrue(realm.world.chronicle.contains { $0.text.contains("stood an hour without its keeper") })
        XCTAssertNil(try realm.arrive("d", name: "Dee", now: 20 + RealmState.unplayedSeatHeldFor).house, "Bel was ready once: a week")
    }

    func testAKeepersWordsGoWithTheirEnvoyToTheKeeperAlone() throws {
        var realm = realm()
        let ama = try realm.arrive("a", name: "Ama", now: 0)
        let bel = try realm.arrive("b", name: "Bel", now: 0)
        try realm.arrive("c", name: "Cor", now: 0)
        _ = try realm.perform(.declareWar(on: bel.house!), by: "a")
        _ = try realm.perform(.proposeWithWords(.peace, to: bel.house!, words: "  Enough blood\non the strand.  See http://x.example "), by: "a")
        let envoy = try XCTUnwrap(realm.world.envoys.first { $0.from == ama.house && $0.to == bel.house })
        XCTAssertNil(envoy.words, "No addresses: the words are dropped whole")
        _ = try realm.perform(.answer(envoy: envoy.id, accept: false), by: "b")
        _ = try realm.perform(.proposeWithWords(.peace, to: bel.house!, words: "Enough blood\non the strand."), by: "a")
        let second = try XCTUnwrap(realm.world.envoys.first { $0.from == ama.house && $0.to == bel.house })
        XCTAssertEqual(second.words, "Enough blood on the strand.")
        XCTAssertEqual(realm.view(for: "b")?.world.envoys.first?.words, "Enough blood on the strand.", "Bel reads them")
        XCTAssertTrue(realm.view(for: "c")?.world.envoys.isEmpty ?? false, "Cor never sees them")

        // Old worlds, kept before envoys carried words, still open.
        let old = #"{"id":1,"from":0,"to":1,"proposal":"peace","arrived":3}"#
        XCTAssertNil(try JSONDecoder().decode(Envoy.self, from: Data(old.utf8)).words)
    }

    func testWordsAreOnePlainLine() {
        XCTAssertEqual(Envoy.carried("  Hold   fast,\tfriend!  "), "Hold fast, friend!")
        XCTAssertNil(Envoy.carried("   "))
        XCTAssertNil(Envoy.carried("!!! ..."), "Words need a letter")
        XCTAssertNil(Envoy.carried("meet me at www.example.org"))
        XCTAssertNil(Envoy.carried("free gold example.com"))
        XCTAssertEqual(Envoy.carried("a<script>b"), "a script b")
        XCTAssertEqual(Envoy.carried(String(repeating: "word ", count: 60))?.count, Envoy.wordsLimit)
        XCTAssertEqual(Envoy.carried("Ysolde’s “oath” — kept…"), "Ysolde’s “oath” — kept…")
    }

    func testANameIsJudgedAsItIsTyped() {
        XCTAssertNil(RealmState.nameProblem(""))
        XCTAssertNil(RealmState.nameProblem("  "))
        XCTAssertNil(RealmState.nameProblem("Mara d'Ost"))
        XCTAssertEqual(RealmState.nameProblem("I"), "At least two letters.")
        XCTAssertEqual(RealmState.nameProblem("Ilsen7"), "Only letters, with spaces, hyphens or apostrophes between them.")
        XCTAssertEqual(RealmState.nameProblem("Ilsen-"), "A name begins and ends with a letter.")
        XCTAssertEqual(RealmState.nameProblem(String(repeating: "a", count: 21)), "No more than twenty letters.")
        XCTAssertFalse(RealmState.isValidName(""))
        XCTAssertTrue(RealmState.isValidName("Ilsen"))
    }

    func testOrdersOnlyForTheKeepersOwnHouse() throws {
        var realm = realm()
        let a = try realm.arrive("a", name: "Ama", now: 0)
        let b = try realm.arrive("b", name: "Bel", now: 0)
        let mine = try XCTUnwrap(realm.world.units(of: a.house!).first { $0.kind == .spear })
        let theirs = try XCTUnwrap(realm.world.units(of: b.house!).first { $0.kind == .spear })
        _ = try realm.perform(.fortify(unit: mine.id), by: "a")
        XCTAssertTrue(realm.world.unit(mine.id)!.fortified)
        XCTAssertThrowsError(try realm.perform(.fortify(unit: theirs.id), by: "a")) { error in
            guard case .rule = error as? RealmError else { return XCTFail("\(error)") }
        }
        XCTAssertThrowsError(try realm.perform(.fortify(unit: mine.id), by: "nobody")) { XCTAssertEqual($0 as? RealmError, .unknownKeeper) }
    }

    func testTheWatchTurnsWhenEveryoneOnlineIsReady() throws {
        var realm = realm()
        try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        XCTAssertNil(realm.setReady("a", true, now: 5))
        XCTAssertEqual(realm.status(now: 5).ready, 1)
        XCTAssertNotNil(realm.setReady("b", true, now: 6))
        XCTAssertEqual(realm.world.watch, 2)
        XCTAssertTrue(realm.keepers.allSatisfy { !$0.isReady }, "A new watch, no one ready")
        XCTAssertEqual(realm.status(now: 6).secondsLeft, 60)

        // One who leaves holds no one up past a third of the watch.
        realm.depart("b", now: 0)
        XCTAssertNil(realm.setReady("a", true, now: 7))
        XCTAssertNotNil(realm.tick(now: 6 + 20))
        XCTAssertEqual(realm.world.watch, 3)
    }

    func testTheWatchTurnsWhenItsTimeRunsOutButAnEmptyRealmSleeps() throws {
        var realm = realm(watchLength: 60)
        XCTAssertNil(realm.tick(now: 1_000), "No one there: the realm sleeps")
        try realm.arrive("a", name: "Ama", now: 1_000)
        XCTAssertNil(realm.tick(now: 1_030))
        XCTAssertEqual(realm.status(now: 1_030).secondsLeft, 30)
        XCTAssertNotNil(realm.tick(now: 1_060))
        XCTAssertEqual(realm.world.watch, 2)
        realm.depart("a", now: 0)
        XCTAssertNil(realm.tick(now: 5_000))
        XCTAssertEqual(realm.world.watch, 2)
    }

    func testKeepersTreatWithEachOther() throws {
        var realm = realm()
        let a = try realm.arrive("a", name: "Ama", now: 0)
        let b = try realm.arrive("b", name: "Bel", now: 0)
        _ = try realm.perform(.propose(.pact, to: b.house!), by: "a")
        let envoy = try XCTUnwrap(realm.world.envoys.first)
        XCTAssertEqual(envoy.from, a.house)
        XCTAssertEqual(envoy.to, b.house)
        XCTAssertThrowsError(try realm.perform(.answer(envoy: envoy.id, accept: true), by: "a"), "Only its addressee answers")
        _ = try realm.perform(.answer(envoy: envoy.id, accept: true), by: "b")
        XCTAssertEqual(realm.world.stance(a.house!, b.house!), .pact)
    }

    func testStewardsPlayTheSeatsNoOneHolds() throws {
        var realm = realm()
        try realm.arrive("a", name: "Ama", now: 0)
        let before = realm.world
        for watch in 1...15 {
            _ = realm.setReady("a", true, now: Double(watch))
        }
        XCTAssertEqual(realm.world.watch, 16)
        let stewards = realm.world.houses.filter { !$0.isPlayer }.map(\.id)
        let moved = realm.world.units.contains { unit in
            stewards.contains(unit.owner) && before.unit(unit.id).map { $0.position != unit.position } ?? true
        }
        XCTAssertTrue(moved, "The stewards' companies go about their business")
    }

    func testANewAgeFollowsAVictory() throws {
        var realm = realm()
        let a = try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        realm.world.outcome = Outcome(winner: a.house!, kind: .dominion, watch: 1)
        XCTAssertTrue(realm.status(now: 0).isEnding)
        realm.depart("b", now: 0)
        XCTAssertNotNil(realm.setReady("a", true, now: 20))
        XCTAssertEqual(realm.age, 2)
        XCTAssertNil(realm.world.outcome)
        XCTAssertEqual(realm.world.watch, 1)
        XCTAssertEqual(realm.keepers.compactMap(\.house).count, 2, "Every keeper seated again, present or not")
        XCTAssertEqual(realm.world.houses[realm.keeper("a")!.house!].title, "House Ama")
    }

    func testTheRealmKeeps() throws {
        var realm = realm()
        try realm.arrive("a", name: "Ama", now: 0)
        _ = realm.setReady("a", true, now: 1)
        let data = try JSONEncoder().encode(realm)
        XCTAssertEqual(try JSONDecoder().decode(RealmState.self, from: data), realm)
    }
}

final class RealmAroundAWorldTests: XCTestCase {
    func testOneHousesGameIsARealmWithOneKeeper() throws {
        let world = GameState(settings: GameSettings(seedText: "one house", houseCount: 3, radius: 16, keepers: 1))
        var realm = RealmState(name: "Rehearsal", world: world, keeper: "me", now: 0)
        XCTAssertEqual(realm.keeper("me")?.house, world.player)
        XCTAssertEqual(realm.world, world)
        XCTAssertNil(realm.tick(now: 1_000_000), "No watch turns of itself")
        let events = realm.stewardOrders(for: "me")
        XCTAssertFalse(events.isEmpty, "The steward gives the House its orders")
        XCTAssertNotNil(realm.setReady("me", true, now: 1))
        XCTAssertEqual(realm.world.watch, 2)
    }
}

final class FogTests: XCTestCase {
    private func game() -> GameState {
        var state = GameState(settings: GameSettings(seedText: "fog", houseCount: 4, radius: 18, keepers: 1))
        for _ in 0..<12 {
            state.stewardTurn(for: state.player)
            _ = state.endWatch()
        }
        return state
    }

    func testAKeeperSeesTheirOwnHouseInFullAndNoMoreOfOthers() throws {
        let state = game()
        let me = state.player
        let view = state.view(for: me)
        XCTAssertEqual(view.settings.seedText, "", "The realm's words stay with the realm")
        XCTAssertEqual(view.houses[me], state.houses[me])
        // Their own companies in full, but for the ways the realm keeps for
        // their marches, which no view carries.
        XCTAssertEqual(view.units(of: me), state.units(of: me).map { unit in
            var unit = unit
            unit.way = nil
            return unit
        })
        XCTAssertTrue(view.units.allSatisfy { $0.way == nil })
        XCTAssertEqual(view.holds.count, state.holds.count, "Every hold is on the political map")
        let seen = state.visibility(for: me)
        for other in state.houses where other.id != me {
            XCTAssertEqual(view.houses[other.id].stock, .zero, "Another House's stores are its own")
            XCTAssertFalse(view.houses[other.id].explored.contains(true))
            for unit in state.units(of: other.id) {
                let visible = state.map.index(of: unit.position).map { seen[$0] } ?? false
                XCTAssertEqual(view.unit(unit.id) != nil, visible, "Only companies in sight")
            }
            for hold in state.holds(of: other.id) {
                XCTAssertNil(view.hold(hold.id)?.project)
            }
            XCTAssertEqual(view.strength(of: other.id), state.strength(of: other.id), "A House's strength is common knowledge")
        }
        for index in 0..<state.map.count where !state.houses[me].explored[index] {
            XCTAssertEqual(view.map[index], GameState.unknownGround, "Unexplored ground is unknown")
        }
        XCTAssertLessThan(try JSONEncoder().encode(view).count, try JSONEncoder().encode(state).count)
    }

    func testOrdersOnTheViewGoAsOnTheWorld() throws {
        var state = game()
        let me = state.player
        var view = state.view(for: me)
        let seat = try XCTUnwrap(state.seat(of: me))
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind.isMilitary && $0.movesLeft > 0 })
        let near = try XCTUnwrap(spear.position.ring(1).first { hex in
            state.map[hex]?.terrain.isPassable == true && state.unit(at: hex) == nil && state.hold(at: hex) == nil
        })
        for command in [Command.move(unit: spear.id, to: near), .build(hold: seat.id, kind: .granary)] {
            let truth = try? state.perform(command, as: me)
            let guess = try? view.perform(command, as: me)
            XCTAssertEqual(truth == nil, guess == nil, "\(command)")
        }
        XCTAssertEqual(view.unit(spear.id)?.position, state.unit(spear.id)?.position)
        XCTAssertEqual(view.houses[me].stock, state.houses[me].stock)
    }

    func testOnlyTheEventsAKeeperWouldHear() throws {
        let state = game()
        let me = state.player
        let far = try XCTUnwrap(state.map.hexes.first { hex in
            !(state.map.index(of: hex).map { state.visibility(for: me)[$0] } ?? true)
        })
        let unseen = Battle(attacker: 1, attackerOwner: 1, attackerKind: .spear, defender: 2, defenderOwner: 2, defenderKind: .spear,
                            hold: nil, at: far, damageDealt: 5, damageTaken: 5, attackerFell: false, defenderFell: false)
        let mine = Battle(attacker: 1, attackerOwner: me, attackerKind: .spear, defender: 2, defenderOwner: 2, defenderKind: .spear,
                          hold: nil, at: far, damageDealt: 5, damageTaken: 5, attackerFell: false, defenderFell: false)
        let war = GameEvent.stanceChanged(first: 1, second: 2, stance: .war, by: 1)
        let heard = state.events([.battle(unseen), .battle(mine), war, .starving(house: 2)], heardBy: me)
        XCTAssertEqual(heard, [.battle(mine), war])
    }

    func testTheRealmTellsEachKeeperTheirOwnView() throws {
        var realm = RealmState(name: "R", seed: "views", seats: 4, radius: 18, watchLength: 60, now: 0)
        let a = try realm.arrive("a", name: "Ama", now: 0)
        try realm.arrive("b", name: "Bel", now: 0)
        let view = try XCTUnwrap(realm.view(for: "a"))
        XCTAssertEqual(view.keeper, a)
        XCTAssertEqual(view.age, 1)
        XCTAssertEqual(view.world, realm.world.view(for: a.house!))
        XCTAssertNil(realm.view(for: "nobody"))
    }
}

private extension RealmState {
    /// Someone there, so the watch turns on the clock.
    mutating func arriveIfNeeded() {
        if keepers.isEmpty { _ = try? arrive("perf", name: "Perf", now: 0) }
        watchBegan = -1e13
    }
}
