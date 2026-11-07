import XCTest
@testable import NullmereCore

/// The Houses a keeper is offered to name in a whisper, a prophecy or a
/// title: every House of a lake of up to ninety-six standing, as ever; past
/// that, the Houses they have reason to name, nearest their seat first, and
/// any other found by its name.
final class HouseChoiceTests: XCTestCase {
    private static let wide = RealmState(name: "The Widest Nullmere", seed: "a choice among a hundred and twenty-eight", seats: 128, now: 0).world

    func testEveryHouseOfALakeOfNinetySixIsOffered() {
        let small = GameState(settings: GameSettings(seedText: "a choice of six", houseCount: 6, radius: 20, keepers: 1))
        let me = small.player
        let choice = small.houseChoice(by: me, excluding: [me])
        XCTAssertFalse(choice.searchable, "No search where every House is shown")
        XCTAssertEqual(choice.offered.map(\.id), small.livingIDs.filter { $0 != me }, "Every other House, in the order of their seats")
        XCTAssertEqual(small.houseChoice(by: me, matching: "no such name").offered.map(\.id), small.livingIDs,
                       "Nothing looked for in a lake that shows them all, the keeper's own House among them")

        // Ninety-six standing of a hundred and twenty-eight seats are shown whole: it is the Houses standing that count.
        var thinned = HouseChoiceTests.wide
        for house in thinned.livingIDs.suffix(32) { thinned.houses[house].isEliminated = true }
        XCTAssertEqual(thinned.livingIDs.count, HouseChoice.shownWhole)
        XCTAssertFalse(thinned.houseChoice(by: 0).searchable)
        XCTAssertEqual(thinned.houseChoice(by: 0).offered.count, 96)
    }

    func testAWideRealmOffersTheHousesAKeeperHasReasonToName() throws {
        var state = HouseChoiceTests.wide
        let me = 40
        let home = try XCTUnwrap(state.seat(of: me)).position
        func distance(_ house: Int) -> Int { state.seat(of: house).map { $0.position.distance(to: home) } ?? Int.max }
        let others = state.livingIDs.filter { $0 != me }
        let nearest = others.sorted { (distance($0), $0) < (distance($1), $1) }
        let leaders = state.standings().prefix(Standing.leaders).map(\.house)

        let choice = state.houseChoice(by: me, excluding: [me])
        let offered = choice.offered.map(\.id)
        XCTAssertTrue(choice.searchable, "A search for the rest")
        XCTAssertFalse(offered.contains(me), "Excluded")
        XCTAssertEqual(Set(offered), Set(nearest.prefix(HouseChoice.nearest)).union(leaders.filter { $0 != me }),
                       "Its neighbours and the race's leaders, a House of no dealings and no alliance")
        XCTAssertEqual(offered.map(distance), offered.map(distance).sorted(), "Nearest first")
        XCTAssertLessThan(offered.count, 30, "Not a hundred and twenty-seven")
        XCTAssertEqual(state.houseChoice(by: me).offered.first?.id, me, "Its own first, where it may be named")
        XCTAssertEqual(state.houseChoice(by: me, excluding: [me], standings: state.standings()), choice, "The race as already worked out")

        // Those it has dealt with, its alliance and its vassals, however far.
        let far = nearest.reversed().filter { !leaders.contains($0) }
        let (foe, ally, vassal, liege) = (far[0], far[1], far[2], far[3])
        for house in [foe, ally, vassal, liege] { XCTAssertFalse(offered.contains(house), "Far, and nothing to it yet") }
        _ = state.keptRelationIndex(me, foe)
        state.setStance(.war, between: me, and: foe, by: me)
        var accord = Alliance(id: 1, name: "the Choosing Accord", leader: me, founded: state.watch)
        accord.members.append(ally)
        state.alliances = [accord]
        state.houses[vassal].liege = me
        let dealt = state.houseChoice(by: me, excluding: [me]).offered.map(\.id)
        for house in [foe, ally, vassal] { XCTAssertTrue(dealt.contains(house), "House \(house) has dealt with it") }
        XCTAssertFalse(dealt.contains(liege))
        state.houses[vassal].liege = nil
        state.houses[me].liege = liege
        XCTAssertTrue(state.houseChoice(by: me, excluding: [me]).offered.map(\.id).contains(liege), "Its liege")
        XCTAssertFalse(state.houseChoice(by: me, excluding: [me, liege]).offered.map(\.id).contains(liege), "Unless excluded")
    }

    /// A letter goes to a keeper: only the Houses that may be named are
    /// offered, shown whole while they are ninety-six or fewer, however many
    /// Houses stand, and none of the rest is found by its name.
    func testOnlyTheHousesThatMayBeNamedAreOffered() throws {
        let state = HouseChoiceTests.wide
        let me = 40
        let few = Set(state.livingIDs.filter { $0 % 2 == 0 && $0 != me })
        let shown = state.houseChoice(by: me, excluding: [me], among: few)
        XCTAssertFalse(shown.searchable, "Sixty-three of a hundred and twenty-eight, shown whole")
        XCTAssertEqual(shown.offered.map(\.id), few.sorted(), "In the order of their seats")

        let many = Set(state.livingIDs.filter { $0 != me && $0 % 8 != 3 })
        let wide = state.houseChoice(by: me, excluding: [me], among: many)
        XCTAssertGreaterThan(many.count, HouseChoice.shownWhole)
        XCTAssertTrue(wide.searchable)
        XCTAssertFalse(wide.offered.isEmpty)
        XCTAssertTrue(wide.offered.allSatisfy { many.contains($0.id) }, "Only those that may be named")
        let unnamed = state.houseChoice(by: me, matching: state.houses[3].name, excluding: [me], among: many)
        XCTAssertFalse(unnamed.offered.contains { $0.id == 3 }, "One that may not be named isn't found by its name")
        XCTAssertTrue(state.houseChoice(by: me, matching: state.houses[3].name, excluding: [me]).offered.contains { $0.id == 3 })
    }

    func testAnyHouseOfAWideRealmIsFoundByItsName() throws {
        let state = HouseChoiceTests.wide
        let me = 40
        let far = try XCTUnwrap(state.livingIDs.filter { $0 != me }.max {
            (state.seat(of: $0)!.position.distance(to: state.seat(of: me)!.position), $1)
                < (state.seat(of: $1)!.position.distance(to: state.seat(of: me)!.position), $0)
        })
        let name = state.houses[far].name
        for asked in [name, name.uppercased(), "  house \(name.lowercased()) ", "House \(name)"] {
            let found = state.houseChoice(by: me, matching: asked, excluding: [me])
            XCTAssertTrue(found.offered.contains { $0.id == far }, "\(asked) finds \(name)")
            XCTAssertTrue(found.offered.allSatisfy { $0.name.lowercased().contains(name.lowercased()) }, "Only Houses going by it")
            XCTAssertEqual(found.more, 0)
            XCTAssertNil(HouseChoice.foundLine(found, query: asked))
        }

        // Many go by a letter: two dozen of them, nearest first, and how many more.
        let many = state.houseChoice(by: me, matching: "a", excluding: [me])
        let all = state.livingIDs.filter { $0 != me && state.houses[$0].name.lowercased().contains("a") }
        XCTAssertGreaterThan(all.count, HouseChoice.found)
        XCTAssertEqual(many.offered.count, HouseChoice.found)
        XCTAssertEqual(many.more, all.count - HouseChoice.found)
        let home = try XCTUnwrap(state.seat(of: me)).position
        let distances = many.offered.map { state.seat(of: $0.id)!.position.distance(to: home) }
        XCTAssertEqual(distances, distances.sorted(), "Nearest first")
        XCTAssertEqual(HouseChoice.foundLine(many, query: "a"),
                       "\(all.count - HouseChoice.found) more Houses go by such a name: give more of it to find them.")
        XCTAssertEqual(HouseChoice.foundLine(HouseChoice(offered: [], searchable: true, more: 1), query: "a"),
                       "1 more House goes by such a name: give more of it to find it.")

        // None, or only a House excluded, goes by it; nothing is looked for in "House" alone.
        let none = state.houseChoice(by: me, matching: "Qqx", excluding: [me])
        XCTAssertTrue(none.offered.isEmpty)
        XCTAssertEqual(HouseChoice.foundLine(none, query: "Qqx"), "None of the Houses you may name goes by such a name.")
        XCTAssertTrue(state.houseChoice(by: me, matching: state.houses[me].name, excluding: [me]).offered.allSatisfy { $0.id != me })
        XCTAssertEqual(state.houseChoice(by: me, matching: " House ", excluding: [me]), state.houseChoice(by: me, excluding: [me]))
        XCTAssertNil(HouseChoice.foundLine(state.houseChoice(by: me, excluding: [me]), query: ""))
        XCTAssertEqual(HouseChoice.folded("Housewright"), "housewright", "A name that begins with the word is looked for whole")
    }
}
