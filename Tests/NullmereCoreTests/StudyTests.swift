import Foundation
import XCTest
@testable import NullmereCore

/// A House studies at its Archive, one study at a time: a tree of four
/// branches whose studies need an Archive of their circle, the studies
/// they build on, and their price, and each changes the rule it names.
final class StudyTests: XCTestCase {
    /// A keeper's House with stores to spend and an Archive at its seat.
    private func world(archive: Int = 4) throws -> (GameState, me: Int, seat: Int) {
        var state = Scene.world("studies")
        let me = state.player
        state.richen(me)
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.archive] = archive
        return (state, me, seat)
    }

    private func refusal(_ command: Command, in state: GameState, as house: Int) -> RuleError? {
        var trial = state
        do {
            try trial.perform(command, as: house)
            return nil
        } catch {
            return error
        }
    }

    func testTheTreeHoldsTogether() {
        XCTAssertEqual(Study.allCases.count, 28)
        for branch in Branch.allCases {
            XCTAssertEqual(Study.of(branch).count, 7, "\(branch.title)")
        }
        XCTAssertEqual(Set(Study.allCases.map(\.title)).count, Study.allCases.count, "Each its own name")
        for study in Study.allCases {
            XCTAssertTrue((1...BuildingKind.deepestCircle).contains(study.circle), "\(study)")
            XCTAssertTrue((1...3).contains(study.grades), "\(study)")
            XCTAssertFalse(study.effect.isEmpty)
            for need in study.needs {
                XCTAssertLessThanOrEqual(need.study.circle, study.circle, "\(study) builds on no deeper study")
                XCTAssertLessThanOrEqual(need.grade, need.study.grades, "\(study) asks a grade \(need.study) has")
                XCTAssertNotEqual(need.study, study)
            }
            for grade in 1...study.grades {
                XCTAssertFalse(study.price(grade: grade).isZero)
                XCTAssertGreaterThan(study.watches(grade: grade), 1)
                if grade > 1 {
                    XCTAssertGreaterThan(study.price(grade: grade).grain, study.price(grade: grade - 1).grain)
                    XCTAssertGreaterThan(study.watches(grade: grade), study.watches(grade: grade - 1))
                }
            }
            XCTAssertTrue(!study.profile.gains.isEmpty || study == .bannerLore, "\(study) changes something")
        }
        XCTAssertEqual((2...5).compactMap(Study.opening), [.drill, .ironRanks, .greyCompanies, .moonsteel])
        XCTAssertNil(Study.opening(tier: 1))
        XCTAssertEqual(Branch.allCases.map(\.title), ["Husbandry", "Arms", "Masonry", "Lore"])
        XCTAssertEqual(BuildingKind.archive.title, "Archive")
        XCTAssertEqual(BuildingKind.archive.effect(atLevel: 2), "Studies of the second circle; every study 8% sooner")
        XCTAssertEqual(BuildingKind.archive.effect(atLevel: 5), "Studies of the fourth circle; every study 20% sooner")
    }

    func testAStudyNeedsItsArchiveItsGroundworkAndItsPrice() throws {
        var (state, me, seat) = try world(archive: 0)
        XCTAssertEqual(refusal(.study(.furrowLore), in: state, as: me), .needsArchive(1))
        state.holds[seat].levels[.archive] = 1
        XCTAssertNil(refusal(.study(.furrowLore), in: state, as: me))
        XCTAssertEqual(refusal(.study(.saltRaking), in: state, as: me), .needsArchive(2))
        state.holds[seat].levels[.archive] = 2
        XCTAssertEqual(refusal(.study(.saltRaking), in: state, as: me), .needsStudy(.stonecutting, 1))
        XCTAssertEqual(state.studiesOpen(to: me).count, Study.allCases.filter { $0.circle <= 2 && $0.needs.isEmpty }.count)

        let poor = { () -> GameState in
            var copy = state
            copy.houses[me].stock = .zero
            return copy
        }()
        XCTAssertEqual(refusal(.study(.stonecutting), in: poor, as: me), .shortOf(Study.stonecutting.price(grade: 1)))
        XCTAssertTrue(poor.studiesOpen(to: me).contains(.stonecutting), "Open, stores aside")

        let before = state.houses[me].stock
        let begun = try state.perform(.study(.stonecutting), as: me)
        XCTAssertEqual(begun, [.studyBegun(house: me, study: .stonecutting, grade: 1)])
        XCTAssertEqual(state.houses[me].stock.shortfall(for: before), Study.stonecutting.price(grade: 1))
        XCTAssertEqual(refusal(.study(.furrowLore), in: state, as: me), .studyUnderWay(.stonecutting), "One study at a time")
        let watches = try XCTUnwrap(state.houses[me].research.pursuit).watchesLeft
        XCTAssertEqual(watches, GameState.hastened(Study.stonecutting.watches(grade: 1), by: 2 * GameState.archivePace))
        var completed: [GameEvent] = []
        for _ in 0..<watches {
            completed += state.endWatch().filter { if case .studyCompleted = $0 { return true } else { return false } }
        }
        XCTAssertEqual(completed, [.studyCompleted(house: me, study: .stonecutting, grade: 1)])
        XCTAssertEqual(state.houses[me].research.grade(of: .stonecutting), 1)
        XCTAssertNil(state.houses[me].research.pursuit)
        XCTAssertNil(refusal(.study(.saltRaking), in: state, as: me), "Its groundwork laid")

        // Grade on grade, to the last.
        for grade in 2...3 {
            state.richen(me)
            _ = try state.perform(.study(.stonecutting), as: me)
            XCTAssertEqual(state.houses[me].research.pursuit?.grade, grade)
            while state.houses[me].research.pursuit != nil { _ = state.endWatch() }
        }
        XCTAssertEqual(state.houses[me].research.grade(of: .stonecutting), 3)
        XCTAssertEqual(refusal(.study(.stonecutting), in: state, as: me), .studiedFully)
    }

    /// A House that loses its Archive studies on only once it has another.
    /// What a study gives at a grade is its gains, once for each grade.
    func testAGradeGivesItsGainsAgain() {
        for study in Study.allCases {
            XCTAssertEqual(study.gains(atGrade: 1), study.profile.gains, "\(study)")
            XCTAssertEqual(study.gains(atGrade: study.grades), study.profile.gains.mapValues { $0 * study.grades }, "\(study)")
        }
        XCTAssertEqual(Study.furrowLore.gains(atGrade: 0).values.allSatisfy { $0 == 0 }, true)
    }

    func testAStudyWaitsWhileItsHouseHasNoArchive() throws {
        var (state, me, seat) = try world(archive: 1)
        _ = try state.perform(.study(.drill), as: me)
        let left = try XCTUnwrap(state.houses[me].research.pursuit).watchesLeft
        state.holds[seat].levels[.archive] = nil
        _ = state.endWatch()
        XCTAssertEqual(state.houses[me].research.pursuit?.watchesLeft, left, "Nowhere to study")
        state.holds[seat].levels[.archive] = 1
        _ = state.endWatch()
        XCTAssertEqual(state.houses[me].research.pursuit?.watchesLeft, left - 1)
    }

    /// Each study changes the rule it names, through the one bonus every
    /// rule asks.
    func testEachStudyChangesTheRuleItNames() throws {
        let (plain, me, seat) = try world()
        func learned(_ studies: [(Study, Int)]) -> GameState {
            var state = plain
            for (study, grade) in studies { state.houses[me].research.learn(study, grade: grade) }
            return state
        }
        let hold = plain.holds[seat]

        // The land and its stores.
        let fields = learned([(.furrowLore, 3)])
        XCTAssertEqual(fields.bonus(.yield(.grain), for: me), 24)
        XCTAssertEqual(fields.income(of: fields.holds[seat]).grain, plain.income(of: hold).grain * 124 / 100)
        XCTAssertEqual(fields.income(of: fields.holds[seat]).stone, plain.income(of: hold).stone, "Only the grain")
        let salt = learned([(.saltRaking, 2), (.woodcraft, 1), (.stonecutting, 1)])
        XCTAssertEqual(salt.yieldBonuses(for: me), Stock(timber: 8, stone: 8, moonsalt: 20))
        XCTAssertEqual(learned([(.deepCellars, 3)]).storage(of: me), plain.storage(of: me) * 130 / 100)

        // Companies.
        let spot = try XCTUnwrap(plain.freeHex(near: hold.position, within: 2...3))
        let spear = Unit(id: 900, kind: .spear, owner: me, position: spot)
        let foe = Unit(id: 901, kind: .spear, owner: 1, position: spot + Hex.directions[0])
        let drilled = learned([(.spearwork, 3)])
        XCTAssertEqual(drilled.attackPercent(of: spear), 115)
        XCTAssertGreaterThan(drilled.strengths(of: spear, against: foe, at: foe.position).attack,
                             plain.strengths(of: spear, against: foe, at: foe.position).attack)
        XCTAssertGreaterThan(drilled.strengths(of: foe, against: spear, at: spear.position).defense,
                             plain.strengths(of: foe, against: spear, at: spear.position).defense)
        XCTAssertGreaterThan(learned([(.fletching, 2)]).attackPercent(of: Unit(id: 1, kind: .bow, owner: me, position: spot)), 100)
        XCTAssertEqual(learned([(.horsemanship, 1)]).defensePercent(of: Unit(id: 1, kind: .rider, owner: me, position: spot)), 105)
        let walled = learned([(.bulwarks, 2)])
        let garrison = Unit(id: 902, kind: .spear, owner: me, position: hold.position)
        XCTAssertGreaterThan(walled.strengths(of: foe, against: garrison, at: hold.position).defense,
                             plain.strengths(of: foe, against: garrison, at: hold.position).defense, "Firmer within its own walls")
        XCTAssertEqual(walled.strengths(of: foe, against: spear, at: spear.position).defense,
                       plain.strengths(of: foe, against: spear, at: spear.position).defense, "Not in the field")
        XCTAssertEqual(learned([(.siegecraft, 2)]).wardDamage(by: spear), plain.wardDamage(by: spear) * 120 / 100)
        XCTAssertEqual(learned([(.roadcraft, 1)]).movement(of: spear), UnitKind.spear.movement + 1)
        XCTAssertEqual(learned([(.roadcraft, 1)]).movement(of: Unit(id: 1, kind: .rider, owner: me, position: spot)), UnitKind.rider.movement)
        XCTAssertEqual(learned([(.starreading, 1)]).sight(of: spear), plain.sight(of: spear) + 1)
        XCTAssertEqual(learned([(.beaconLore, 1)]).sight(of: hold), plain.sight(of: hold) + 1)
        let seen = learned([(.starreading, 1), (.beaconLore, 1)]).visibility(for: me).filter { $0 }.count
        XCTAssertGreaterThan(seen, plain.visibility(for: me).filter { $0 }.count, "and so a House sees more")

        // Works and musters.
        XCTAssertEqual(learned([(.scaffolding, 3)]).buildWatches(of: .moonspire, toLevel: 5, for: me),
                       GameState.hastened(BuildingKind.moonspire.buildWatches(toLevel: 5), by: 24))
        XCTAssertLessThan(learned([(.scaffolding, 3)]).buildWatches(of: .moonspire, toLevel: 5, for: me), BuildingKind.moonspire.buildWatches(toLevel: 5))
        XCTAssertEqual(learned([(.mortar, 3)]).nextLevelCost(of: .walls, in: hold), BuildingKind.walls.cost(toLevel: 1).scaled(percent: 85))
        XCTAssertEqual(learned([(.musterYards, 2)]).trainingWatches(of: .founder, at: hold), 2)
        XCTAssertEqual(learned([(.quartermasters, 3)]).trainingCost(of: .rider, tier: 2, for: me), UnitKind.rider.cost(tier: 2).scaled(percent: 85))
        XCTAssertLessThan(learned([(.quartermasters, 1)]).trainingCost(of: .founder, for: me).grain, plain.trainingCost(of: .founder, for: me).grain)
        XCTAssertGreaterThan(learned([(.lamplitLetters, 3)]).bonus(.studySpeed, for: me), plain.bonus(.studySpeed, for: me))
        XCTAssertLessThan(learned([(.lamplitLetters, 3)]).studyWatches(of: .moonsteel, grade: 1, for: me),
                          plain.studyWatches(of: .moonsteel, grade: 1, for: me))

        // Wards mend faster, and resting companies heal more.
        var mending = learned([(.wardstones, 2)])
        mending.holds[seat].ward = 0
        var unmended = plain
        unmended.holds[seat].ward = 0
        _ = mending.endWatch()
        _ = unmended.endWatch()
        XCTAssertEqual(mending.holds[seat].ward, Hold.wardRecovery * 150 / 100)
        XCTAssertEqual(unmended.holds[seat].ward, Hold.wardRecovery)
        var healing = learned([(.fieldSurgeons, 2)])
        var unhealed = plain
        let wounded = try XCTUnwrap(plain.units.firstIndex { $0.owner == me && $0.kind == .spear })
        healing.units[wounded].health = 40
        unhealed.units[wounded].health = 40
        _ = healing.endWatch()
        _ = unhealed.endWatch()
        XCTAssertEqual(try XCTUnwrap(healing.unit(plain.units[wounded].id)).health, try XCTUnwrap(unhealed.unit(plain.units[wounded].id)).health + 10)

        // The tiers.
        XCTAssertEqual(plain.studiedTier(for: me), 1)
        XCTAssertEqual(learned([(.drill, 1), (.ironRanks, 1)]).studiedTier(for: me), 3)
        var hall = plain
        hall.holds[seat].levels[.musterHall] = 5
        XCTAssertEqual(refusal(.train(hold: hold.id, kind: .spear, tier: 2), in: hall, as: me), .needsStudy(.drill, 1))
        hall.houses[me].research.learn(.drill, grade: 1)
        XCTAssertNil(refusal(.train(hold: hold.id, kind: .spear, tier: 2), in: hall, as: me))
        XCTAssertEqual(refusal(.train(hold: hold.id, kind: .spear, tier: 3), in: hall, as: me), .needsStudy(.ironRanks, 1))
        XCTAssertEqual(hall.highestTier(of: .bow, at: hall.holds[seat], for: me), 2)

        // What gathering and commanders will ask.
        XCTAssertEqual(learned([(.gleaning, 3)]).bonus(.gathering, for: me), 30)
        XCTAssertEqual(learned([(.ladenCarts, 2)]).bonus(.load, for: me), 30)
        XCTAssertEqual(learned([(.warChronicles, 1)]).bonus(.commanderExperience, for: me), 15)
        XCTAssertEqual(plain.bonus(.sight, for: 99), 0, "No such House, no bonus")
    }

    /// A House that masters a study opening a tier is chronicled.
    func testOpeningATierIsChronicled() throws {
        var (state, me, _) = try world(archive: 1)
        _ = try state.perform(.study(.drill), as: me)
        while state.houses[me].research.pursuit != nil { _ = state.endWatch() }
        let entry = try XCTUnwrap(state.chronicle.last { $0.kind == .learning })
        XCTAssertEqual(entry.houses, [me])
        XCTAssertTrue(entry.text.contains("masters Close Order"), entry.text)
        XCTAssertTrue(entry.text.contains("tier II"), entry.text)
    }

    func testStudiesAreToldInTheGamesWords() throws {
        let (state, me, _) = try world()
        XCTAssertEqual(RuleError.studyUnderWay(.drill).description, "Your House already studies Close Order; one study at a time.")
        XCTAssertEqual(RuleError.studiedFully.description, "That study is known to its last grade.")
        XCTAssertEqual(RuleError.needsArchive(3).description, "Needs an Archive III.")
        XCTAssertEqual(RuleError.needsStudy(.drill, 1).description, "Needs the study of Close Order.")
        XCTAssertEqual(RuleError.needsStudy(.gleaning, 2).description, "Needs the study of Gleaning II.")
        XCTAssertEqual(state.tidings(of: .studyBegun(house: me, study: .furrowLore, grade: 2), for: me),
                       Tidings("Your Archive takes up Furrow Lore II.", .neutral))
        XCTAssertEqual(state.tidings(of: .studyCompleted(house: me, study: .drill, grade: 1), for: me),
                       Tidings("Your House masters Close Order: companies of war of tier II.", .good))
        XCTAssertNil(state.tidings(of: .studyCompleted(house: 1, study: .drill, grade: 1), for: me), "Another House's studies are its own")
        XCTAssertNil(state.tidings(of: .starving(house: me), for: me), "Told elsewhere")
    }

    /// A keeper sees their own House's studies, and nothing of another's;
    /// what is studied is heard by its House alone.
    func testAViewKeepsOtherHousesStudies() throws {
        var (state, me, _) = try world()
        state.houses[me].research.learn(.drill, grade: 1)
        state.houses[1].research.learn(.furrowLore, grade: 2)
        state.houses[1].research.pursuit = Pursuit(study: .woodcraft, grade: 1, watchesLeft: 3)
        let view = state.view(for: me)
        XCTAssertEqual(view.houses[me].research, state.houses[me].research)
        XCTAssertTrue(view.houses[1].research.isEmpty)
        let events: [GameEvent] = [.studyBegun(house: 1, study: .woodcraft, grade: 1), .studyCompleted(house: me, study: .drill, grade: 1)]
        XCTAssertEqual(state.events(events, heardBy: me), [.studyCompleted(house: me, study: .drill, grade: 1)])
    }

    /// Saves from before studies know none, and a House's studies come back
    /// whole, kept only where there are any.
    func testSavesFromBeforeStudiesKnowNone() throws {
        var (state, me, _) = try world()
        state.houses[me].research.learn(.drill, grade: 1)
        state.houses[me].research.pursuit = Pursuit(study: .spearwork, grade: 1, watchesLeft: 2)
        let old = try Scene.without(["research"], in: state)
        let loaded = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertTrue(loaded.houses.allSatisfy(\.research.isEmpty))
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
        let quiet = String(decoding: try JSONEncoder().encode(state.houses[1]), as: UTF8.self)
        XCTAssertFalse(quiet.contains("research"), "A House that has studied nothing keeps no word of it")
    }

    /// Stewards raise Archives and study, each by its temper: with stores
    /// to spare, the first study of its temper's first branch; never with
    /// its last stores; never a second at once.
    func testStewardsStudy() throws {
        var state = GameState(settings: GameSettings(seedText: "stewards study", houseCount: 4, radius: 18, keepers: 0))
        for _ in 0..<70 where state.outcome == nil { _ = state.endWatch() }
        XCTAssertTrue(state.houses.contains { !$0.research.isEmpty }, "Some House has studied")
        XCTAssertTrue(state.holds.contains { $0.level(.archive) > 0 }, "at an Archive it raised")
        XCTAssertEqual(RivalMind.archiveWanted(at: 5), 0)
        XCTAssertEqual(RivalMind.archiveWanted(at: 150), 4)

        for temperament in Temperament.allCases {
            var scene = Scene.world("a steward studies")
            let steward = 1
            scene.houses[steward].temperament = temperament
            let seat = try XCTUnwrap(scene.holds.firstIndex { $0.owner == steward && $0.isSeat })
            XCTAssertEqual(RivalMind(house: steward).pursueStudies(in: &scene), [], "No Archive, no study")
            scene.holds[seat].levels[.archive] = 1
            let first = try XCTUnwrap(Study.of(RivalMind.studyOrder(for: temperament)[0]).first)
            scene.houses[steward].stock = first.price(grade: 1)
            XCTAssertEqual(RivalMind(house: steward).pursueStudies(in: &scene), [], "Not with its last stores")
            scene.richen(steward)
            XCTAssertEqual(RivalMind(house: steward).pursueStudies(in: &scene), [.studyBegun(house: steward, study: first, grade: 1)], "\(temperament)")
            XCTAssertEqual(RivalMind(house: steward).pursueStudies(in: &scene), [], "One at a time")
        }
    }
}
