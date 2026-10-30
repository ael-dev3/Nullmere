import Foundation
import XCTest
@testable import NullmereCore

/// Every House has commanders: named, of an archetype, rising from level I
/// to XXX with experience, each leading one company and strengthening it,
/// with an active skill that fires in battle on its cadence. A commander
/// whose company falls is carried home wounded.
final class CommanderTests: XCTestCase {
    /// A keeper's House, its commander, and a spear of its own at its seat.
    private func world(_ seed: String = "commanders") throws -> (GameState, me: Int, commander: Int, spear: Int) {
        var state = Scene.world(seed)
        let me = state.player
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        let seat = try XCTUnwrap(state.seat(of: me))
        let spear = try XCTUnwrap(state.units(of: me).first { $0.kind == .spear })
        // The spear to the seat, whoever stood there to where it stood.
        if let there = state.unit(at: seat.position), let other = state.unitIndex(there.id) {
            state.units[other].position = spear.position
        }
        state.units[try XCTUnwrap(state.unitIndex(spear.id))].position = seat.position
        return (state, me, commander, spear.id)
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

    /// Makes a commander of an archetype and level.
    private func shape(_ id: Int, _ archetype: Archetype, level: Int, in state: inout GameState) {
        let old = state.commanders![id - 1]
        var made = Commander(id: id, name: old.name, archetype: archetype, owner: old.owner)
        made.experience = Commander.experience(forLevel: level)
        state.commanders![id - 1] = made
    }

    func testEveryHouseBeginsWithACommanderOfItsOwn() throws {
        let state = GameState(settings: GameSettings(seedText: "first commanders", houseCount: 12, radius: 36, keepers: 0))
        XCTAssertEqual(state.roster.count, 12)
        XCTAssertEqual(state.roster.map(\.id), Array(1...12))
        XCTAssertEqual(Set(state.roster.map(\.name)).count, 12, "Each its own name")
        for house in state.houses {
            let mine = state.commanders(of: house.id)
            XCTAssertEqual(mine.count, 1)
            XCTAssertEqual(mine.first?.level, 1)
            XCTAssertEqual(mine.first?.skills.count, 1)
        }
        XCTAssertEqual(state, GameState(settings: state.settings), "The same words, the same commanders")
        XCTAssertEqual(state.problems(), [])
    }

    func testLevelsFollowExperienceAndSkillsTheLevels() {
        XCTAssertEqual(Commander.level(forExperience: 0), 1)
        XCTAssertEqual(Commander.experience(forLevel: 1), 0)
        for level in 2...Commander.highestLevel {
            XCTAssertGreaterThan(Commander.experience(forLevel: level), Commander.experience(forLevel: level - 1))
            XCTAssertEqual(Commander.level(forExperience: Commander.experience(forLevel: level)), level)
            XCTAssertEqual(Commander.level(forExperience: Commander.experience(forLevel: level) - 1), level - 1)
        }
        XCTAssertEqual(Commander.level(forExperience: 10_000_000), Commander.highestLevel)
        for archetype in Archetype.allCases {
            XCTAssertEqual(archetype.skills.count, 4)
            XCTAssertEqual(archetype.skills.map(\.unlock), [1, 5, 10, 20])
            XCTAssertTrue(archetype.active.isActive)
            XCTAssertEqual(archetype.skills.filter(\.isActive), [archetype.active])
            XCTAssertNotEqual(archetype.active.fury.dealt * archetype.active.fury.taken, 100 * 100, "\(archetype)'s active does something")
            for skill in archetype.skills where !skill.isActive {
                XCTAssertFalse(skill.edges.isEmpty, "\(skill) gives its company something")
            }
            XCTAssertFalse(archetype.title.isEmpty)
        }
        XCTAssertEqual(Set(Skill.allCases.map(\.title)).count, Skill.allCases.count)
        XCTAssertTrue(Skill.allCases.allSatisfy { !$0.effect.isEmpty && $0.cadence >= 2 })
        var commander = Commander(id: 1, name: "Test", archetype: .vanguard, owner: 0)
        XCTAssertEqual(commander.skills, [.spearhead])
        commander.experience = Commander.experience(forLevel: 20)
        XCTAssertEqual(commander.skills, [.spearhead, .fellCharge, .bloodPace, .ironWill])
        XCTAssertEqual(commander.edge(.attack), 18)
        XCTAssertEqual(commander.edge(.moves), 1)
    }

    func testACommanderLeadsOneCompanyTakenUpAtAHold() throws {
        var (state, me, commander, spear) = try world()
        let other = try XCTUnwrap(state.commanders(of: 1).first).id
        XCTAssertEqual(refusal(.assign(commander: other, unit: spear), in: state, as: me), .unknownCommander)
        XCTAssertEqual(refusal(.assign(commander: 99, unit: spear), in: state, as: me), .unknownCommander)
        let lantern = try XCTUnwrap(state.units(of: me).first { $0.kind == .lantern })
        XCTAssertEqual(refusal(.assign(commander: commander, unit: lantern.id), in: state, as: me), .cannotLead(.lantern))
        XCTAssertEqual(refusal(.assign(commander: commander, unit: 98_765), in: state, as: me), .unknownUnit)
        let theirs = try XCTUnwrap(state.units(of: 1).first { $0.kind == .spear })
        XCTAssertEqual(refusal(.assign(commander: commander, unit: theirs.id), in: state, as: me), .notYours)
        let seat = try XCTUnwrap(state.seat(of: me))
        let far = try XCTUnwrap(state.freeHex(near: seat.position, within: 4...6))
        let afield = state.put(.spear, of: me, at: far)
        XCTAssertEqual(refusal(.assign(commander: commander, unit: afield), in: state, as: me), .awayFromHolds)

        XCTAssertEqual(try state.perform(.assign(commander: commander, unit: spear), as: me), [.commanderAssigned(commander: commander, unit: spear)])
        XCTAssertEqual(state.unit(spear)?.leader, commander)
        XCTAssertEqual(state.company(ledBy: commander)?.id, spear)
        let beside = try XCTUnwrap(state.freeHex(near: seat.position))
        let second = state.put(.bow, of: me, at: beside)
        XCTAssertEqual(refusal(.assign(commander: commander, unit: second), in: state, as: me), .commanderLeads)
        state.commanders = state.roster + [Commander(id: state.roster.count + 1, name: "Second", archetype: .warden, owner: me)]
        XCTAssertEqual(refusal(.assign(commander: state.roster.count, unit: spear), in: state, as: me), .alreadyLed)

        // It goes where its company goes, and leaves it anywhere.
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].position = far + Hex.directions[0]
        XCTAssertEqual(try state.perform(.unassign(commander: commander), as: me), [.commanderReleased(commander: commander)])
        XCTAssertNil(state.unit(spear)?.leader)
        XCTAssertEqual(refusal(.unassign(commander: commander), in: state, as: me), .notLeading)
        XCTAssertEqual(refusal(.unassign(commander: other), in: state, as: me), .unknownCommander)
        XCTAssertEqual(state.problems(), [])
    }

    func testACommandersSkillsStrengthenItsCompany() throws {
        var (state, me, commander, spear) = try world()
        _ = try state.perform(.assign(commander: commander, unit: spear), as: me)
        let led = try XCTUnwrap(state.unit(spear))
        var plain = led
        plain.leader = nil
        for (archetype, check) in [
            (Archetype.vanguard, { (s: GameState, u: NullmereCore.Unit) in s.attackPercent(of: u) }),
            (.warden, { (s: GameState, u: NullmereCore.Unit) in s.defensePercent(of: u) }),
            (.outrider, { (s: GameState, u: NullmereCore.Unit) in s.sight(of: u) * 100 + s.movement(of: u) }),
            (.wallbreaker, { (s: GameState, u: NullmereCore.Unit) in s.wardDamage(by: u) }),
            (.gleaner, { (s: GameState, u: NullmereCore.Unit) in s.bonus(.gathering, for: u) + s.bonus(.load, for: u) }),
        ] {
            var shaped = state
            shape(commander, archetype, level: 20, in: &shaped)
            XCTAssertGreaterThan(check(shaped, led), check(shaped, plain), "\(archetype) strengthens its company")
        }
        shape(commander, .warden, level: 20, in: &state)
        let seat = try XCTUnwrap(state.seat(of: me))
        let foe = Unit(id: 9_000, kind: .spear, owner: 1, position: seat.position + Hex.directions[0])
        XCTAssertGreaterThan(state.strengths(of: foe, against: led, at: seat.position).defense,
                             state.strengths(of: foe, against: plain, at: seat.position).defense, "within its own walls the more")
        XCTAssertEqual(state.bonus(.healing, for: led), state.bonus(.healing, for: plain) + 5)
        XCTAssertEqual(state.bonus(.yield(.grain), for: led), state.bonus(.yield(.grain), for: me), "Nothing a company has no use for")
    }

    /// A commander's fury rises with each battle; on its cadence its active
    /// skill fires, as the forecast says beforehand, and its fury begins
    /// again.
    func testTheActiveSkillFiresOnItsCadenceAsForecast() throws {
        var state = Scene.world("fury")
        let me = state.player, foe = 1
        state.units.removeAll()
        let ground = try XCTUnwrap(state.map.hexes.first { hex in
            state.map[hex]?.terrain == .greyfield && state.map.neighbors(of: hex).allSatisfy { state.map[$0]?.terrain == .greyfield }
                && hex.spiral(3).allSatisfy { state.hold(at: $0) == nil }
        })
        let commander = try XCTUnwrap(state.commanders(of: me).first).id
        shape(commander, .vanguard, level: 5, in: &state)
        _ = try state.perform(.declareWar(on: foe), as: me)
        let striker = state.put(.spear, of: me, at: ground)
        state.units[try XCTUnwrap(state.unitIndex(striker))].leader = commander
        let there = ground + Hex.directions[0]
        var fired = 0
        for battle in 0..<6 {
            let target = state.put(.spear, tier: 5, of: foe, at: there)
            let index = try XCTUnwrap(state.unitIndex(striker))
            state.units[index].movesLeft = 2
            state.units[index].health = 100
            let ready = state.furyReady(of: state.units[index])
            XCTAssertEqual(ready != nil, battle % 3 == 2, "Battle \(battle)")
            let forecast = try XCTUnwrap(state.forecast(unit: striker, at: there))
            var plain = state
            plain.units[index].leader = nil
            let unled = try XCTUnwrap(plain.forecast(unit: striker, at: there))
            if ready != nil {
                XCTAssertGreaterThan(forecast.dealt.lowerBound, unled.dealt.lowerBound, "Its fire foreseen")
            }
            let events = try state.perform(.attack(unit: striker, target: there), as: me)
            for case .battle(let blow) in events {
                XCTAssertTrue(forecast.dealt.contains(blow.damageDealt), "\(blow.damageDealt) in \(forecast.dealt)")
                XCTAssertTrue(forecast.taken.contains(blow.damageTaken))
            }
            let firing = events.filter { if case .skillFired = $0 { return true } else { return false } }
            XCTAssertEqual(firing.isEmpty, ready == nil)
            if !firing.isEmpty {
                XCTAssertEqual(firing, [.skillFired(commander: commander, house: me, skill: .fellCharge, at: there)])
                fired += 1
            }
            XCTAssertEqual(state.commander(commander)?.fury, (battle + 1) % 3)
            state.units.removeAll { $0.id == target }
        }
        XCTAssertEqual(fired, 2)
        XCTAssertGreaterThan(state.commander(commander)?.experience ?? 0, Commander.experience(forLevel: 5), "and it learned")
    }

    func testACommanderLearnsAndRises() throws {
        var (state, me, commander, spear) = try world()
        _ = try state.perform(.assign(commander: commander, unit: spear), as: me)
        let led = try XCTUnwrap(state.unit(spear))
        let rose = state.teach(led, Commander.experience(forLevel: 5))
        XCTAssertEqual(rose, [.commanderRose(commander: commander, house: me, level: 5)])
        XCTAssertEqual(state.commander(commander)?.skills.count, 2)
        state.houses[me].research.learn(.warChronicles, grade: 2)
        state.houses[me].heritage = .strandfolk  // whose commanders learn at no other pace
        let before = try XCTUnwrap(state.commander(commander)).experience
        _ = state.teach(led, 100)
        XCTAssertEqual(state.commander(commander)?.experience, before + 130, "War Chronicles teach faster")
        _ = state.teach(led, 10_000_000)
        XCTAssertEqual(state.commander(commander)?.level, Commander.highestLevel)
        XCTAssertTrue(state.chronicle.contains { $0.kind == .commander && $0.text.contains("30th level") })
        XCTAssertEqual(state.teach(led, 0), [])
        XCTAssertEqual(GameState.battleExperience(dealt: 40, felled: true), 60)
    }

    func testAFallenCompanysCommanderIsCarriedHomeWounded() throws {
        var (state, me, commander, spear) = try world()
        _ = try state.perform(.assign(commander: commander, unit: spear), as: me)
        let index = try XCTUnwrap(state.unitIndex(spear))
        state.units[index].health = 1
        let seat = try XCTUnwrap(state.seat(of: me))
        let striker = state.put(.rider, tier: 5, of: 1, at: try XCTUnwrap(state.freeHex(near: seat.position)))
        _ = try state.perform(.declareWar(on: me), as: 1)
        let events = try state.perform(.attack(unit: striker, target: seat.position), as: 1)
        XCTAssertNil(state.unit(spear), "The company falls")
        XCTAssertTrue(events.contains(.commanderWounded(commander: commander, house: me)))
        XCTAssertEqual(state.commander(commander)?.woundedUntil, state.watch + GameState.woundWatches)
        XCTAssertNil(state.company(ledBy: commander))
        // The war done with, the House left in peace while it mends.
        state.units.removeAll { $0.owner == 1 }
        state.setStance(.peace, between: 1, and: me, by: 1)
        let bow = state.put(.bow, of: me, at: try XCTUnwrap(state.freeHex(near: seat.position)))
        XCTAssertEqual(refusal(.assign(commander: commander, unit: bow), in: state, as: me), .commanderWounded(GameState.woundWatches))
        for _ in 0..<GameState.woundWatches { _ = state.endWatch() }
        XCTAssertNil(refusal(.assign(commander: commander, unit: bow), in: state, as: me), "Whole again")

        // Hunger wounds as surely: the newest companies starve first.
        var hungry = try world("hungry commanders").0
        let keeper = hungry.player
        let home = try XCTUnwrap(hungry.seat(of: keeper)).position
        for _ in 0..<14 {
            hungry.put(.rider, tier: 5, of: keeper, at: try XCTUnwrap(hungry.freeHex(near: home, within: 2...5)))
        }
        let led = hungry.put(.spear, of: keeper, at: try XCTUnwrap(hungry.freeHex(near: home)), health: 10)
        let first = try XCTUnwrap(hungry.commanders(of: keeper).first).id
        _ = try hungry.perform(.assign(commander: first, unit: led), as: keeper)
        hungry.houses[keeper].stock.grain = 0
        XCTAssertGreaterThan(hungry.upkeep(of: keeper), hungry.income(of: keeper).grain)
        let starved = hungry.endWatch()
        XCTAssertNil(hungry.unit(led))
        XCTAssertTrue(starved.contains(.commanderWounded(commander: first, house: keeper)))

        // Disbanded, its commander comes home whole.
        var (disbanding, owner, leader, company) = try world("disbanded")
        _ = try disbanding.perform(.assign(commander: leader, unit: company), as: owner)
        _ = try disbanding.perform(.disband(unit: company), as: owner)
        XCTAssertFalse(disbanding.commander(leader)?.isWounded(at: disbanding.watch) ?? true)
        XCTAssertNil(disbanding.company(ledBy: leader))
    }

    func testHousesGainCommanders() throws {
        var (state, me, _, _) = try world("more commanders")
        let seat = try XCTUnwrap(state.holds.firstIndex { $0.owner == me && $0.isSeat })
        state.holds[seat].levels[.musterHall] = 2
        state.holds[seat].project = Hold.Project(kind: .musterHall, targetLevel: 3, watchesLeft: 1)
        let raised = state.endWatch()
        XCTAssertEqual(state.commanders(of: me).count, 2, "A captain rises from the ranks of a third hall")
        let joined = try XCTUnwrap(state.commanders(of: me).last)
        XCTAssertTrue(raised.contains(.commanderJoined(commander: joined.id, house: me)))
        XCTAssertTrue(state.chronicle.contains { $0.kind == .commander && $0.text.contains(joined.name) })

        state.houses[me].research.pursuit = Pursuit(study: .bannerLore, grade: 1, watchesLeft: 1)
        state.holds[seat].levels[.archive] = 4
        _ = state.endWatch()
        XCTAssertEqual(state.commanders(of: me).count, 3, "and one answers the House's banner")

        // No more than five.
        var random = SeededRandom(seed: 1)
        for _ in 0..<5 { state.raiseCommander(for: me, using: &random) }
        XCTAssertEqual(state.commanders(of: me).count, GameState.rosterLimit)
        XCTAssertEqual(state.commanderJoins(me, why: "joins"), [])
        XCTAssertEqual(Set(state.roster.map(\.name)).count, state.roster.count, "Every commander on the lake its own name")
        XCTAssertEqual(state.problems(), [])
    }

    /// A keeper knows their own commanders, and of others' only those
    /// leading companies in their sight; what befalls a commander is heard
    /// by its House, and a skill fired, by those who see it.
    func testAViewShowsItsOwnCommandersAndThoseInSight() throws {
        var (state, me, commander, spear) = try world("seen commanders")
        _ = try state.perform(.assign(commander: commander, unit: spear), as: me)
        let theirs = try XCTUnwrap(state.commanders(of: 1).first)
        let seen = state.visibility(for: me)
        let hidden = try XCTUnwrap(state.units(of: 1).first { $0.kind.isMilitary && !seen[state.map.index(of: $0.position)!] })
        state.units[try XCTUnwrap(state.unitIndex(hidden.id))].leader = theirs.id
        var view = state.view(for: me)
        XCTAssertEqual(view.commanders(of: me), state.commanders(of: me))
        XCTAssertNil(view.commander(theirs.id), "Out of sight, unknown")
        XCTAssertEqual(view.unit(spear)?.leader, commander)
        XCTAssertEqual(view.commander(commander)?.name, state.commander(commander)?.name, "Found in a view by its id")

        let seat = try XCTUnwrap(state.seat(of: me))
        state.units[try XCTUnwrap(state.unitIndex(hidden.id))].position = try XCTUnwrap(state.freeHex(near: seat.position, within: 2...2))
        view = state.view(for: me)
        XCTAssertEqual(view.commander(theirs.id), theirs, "Leading a company in sight, known")
        XCTAssertEqual(view.unit(hidden.id)?.leader, theirs.id)

        let far = try XCTUnwrap(state.map.hexes.first { !seen[state.map.index(of: $0)!] })
        let events: [GameEvent] = [
            .commanderJoined(commander: theirs.id, house: 1), .commanderRose(commander: commander, house: me, level: 2),
            .skillFired(commander: theirs.id, house: 1, skill: .holdFast, at: far),
            .skillFired(commander: theirs.id, house: 1, skill: .holdFast, at: seat.position),
            .commanderAssigned(commander: commander, unit: spear), .commanderAssigned(commander: theirs.id, unit: hidden.id),
            .commanderReleased(commander: theirs.id), .commanderWounded(commander: commander, house: me),
        ]
        XCTAssertEqual(state.events(events, heardBy: me), [
            .commanderRose(commander: commander, house: me, level: 2),
            .skillFired(commander: theirs.id, house: 1, skill: .holdFast, at: seat.position),
            .commanderAssigned(commander: commander, unit: spear), .commanderWounded(commander: commander, house: me),
        ])
    }

    /// Worlds from before commanders take them up at the next watch, every
    /// House its first; companies from before lead no one.
    func testWorldsFromBeforeCommandersRaiseThemAtTheNextWatch() throws {
        var (state, me, commander, spear) = try world("older commanders")
        _ = try state.perform(.assign(commander: commander, unit: spear), as: me)
        let old = try Scene.without(["commanders", "leader"], in: state)
        var loaded = try JSONDecoder().decode(GameState.self, from: old)
        XCTAssertTrue(loaded.roster.isEmpty)
        XCTAssertTrue(loaded.units.allSatisfy { $0.leader == nil })
        _ = loaded.endWatch()
        XCTAssertTrue(loaded.livingHouses.allSatisfy { loaded.commanders(of: $0.id).count == 1 })
        XCTAssertEqual(try JSONDecoder().decode(GameState.self, from: JSONEncoder().encode(state)), state)
    }

    /// A steward puts its commanders at the head of companies.
    func testStewardsAppointTheirCommanders() throws {
        var state = Scene.world("appointed")
        let steward = 1
        let commander = try XCTUnwrap(state.commanders(of: steward).first).id
        XCTAssertNil(state.company(ledBy: commander))
        _ = state.stewardTurn(for: steward)
        XCTAssertNotNil(state.company(ledBy: commander), "It leads a company")
        XCTAssertEqual(state.company(ledBy: commander)?.owner, steward)
    }

    /// An unsound roster is caught.
    func testAnUnsoundRosterIsCaught() throws {
        var (state, me, commander, spear) = try world("unsound roster")
        _ = try state.perform(.assign(commander: commander, unit: spear), as: me)
        var twice = state
        let other = try XCTUnwrap(twice.units(of: me).first { $0.id != spear && $0.kind == .lantern })
        twice.units[try XCTUnwrap(twice.unitIndex(other.id))].leader = commander
        XCTAssertTrue(twice.problems().contains { $0.contains("leads two companies") })
        var stray = state
        stray.units[try XCTUnwrap(stray.unitIndex(spear))].leader = 1_000
        XCTAssertTrue(stray.problems().contains { $0.contains("no commander") })
        var foreign = state
        foreign.units[try XCTUnwrap(foreign.unitIndex(spear))].leader = try XCTUnwrap(state.commanders(of: 1).first).id
        XCTAssertTrue(foreign.problems().contains { $0.contains("another House's commander") })
        var misnumbered = state
        misnumbered.commanders![0] = Commander(id: 77, name: "Stray", archetype: .warden, owner: 0)
        XCTAssertTrue(misnumbered.problems().contains { $0.contains("numbered") })
    }

    func testCommandersAreToldInTheGamesWords() throws {
        var (state, me, commander, spear) = try world("told")
        let name = try XCTUnwrap(state.commander(commander)).name
        XCTAssertEqual(RuleError.unknownCommander.description, "No such commander serves your House.")
        XCTAssertEqual(RuleError.commanderWounded(3).description, "That commander is wounded; whole again in 3 watches.")
        XCTAssertEqual(RuleError.commanderWounded(1).description, "That commander is wounded; whole again in 1 watch.")
        XCTAssertEqual(RuleError.commanderLeads.description, "That commander already leads a company.")
        XCTAssertEqual(RuleError.alreadyLed.description, "That company already has a commander.")
        XCTAssertEqual(RuleError.cannotLead(.lantern).description, "Lanterns take no commander.")
        XCTAssertEqual(RuleError.awayFromHolds.description, "A commander takes up a company at or beside one of your holds.")
        XCTAssertEqual(RuleError.notLeading.description, "That commander leads no company.")
        let joined = state.commander(commander)!.archetype.named
        XCTAssertEqual(state.tidings(of: .commanderJoined(commander: commander, house: me), for: me), Tidings("\(name), \(joined), joins your House.", .good))
        XCTAssertEqual(Archetype.allCases.map(\.named), ["a warden", "a vanguard", "an outrider", "a gleaner", "a wallbreaker"])
        _ = try state.perform(.assign(commander: commander, unit: spear), as: me)
        XCTAssertEqual(state.tidings(of: .commanderAssigned(commander: commander, unit: spear), for: me), Tidings("\(name) takes command of your Spears.", .neutral))
        XCTAssertEqual(state.tidings(of: .commanderReleased(commander: commander), for: me), Tidings("\(name) rides home to your seat.", .neutral))
        XCTAssertEqual(state.tidings(of: .commanderRose(commander: commander, house: me, level: 5), for: me),
                       Tidings("\(name) rises to level 5, and with it \(state.commander(commander)!.archetype.active.title).", .good))
        XCTAssertEqual(state.tidings(of: .commanderRose(commander: commander, house: me, level: 6), for: me), Tidings("\(name) rises to level 6.", .good))
        XCTAssertEqual(state.tidings(of: .commanderWounded(commander: commander, house: me), for: me),
                       Tidings("\(name) is carried home wounded; whole again in \(GameState.woundWatches) watches.", .bad))
        XCTAssertEqual(state.tidings(of: .skillFired(commander: commander, house: me, skill: .holdFast, at: .origin), for: me),
                       Tidings("\(name) calls Hold Fast.", .good))
        let theirs = try XCTUnwrap(state.commanders(of: 1).first)
        XCTAssertEqual(state.tidings(of: .skillFired(commander: theirs.id, house: 1, skill: .breach, at: .origin), for: me),
                       Tidings("\(theirs.name) of \(state.houses[1].title) calls Breach.", .bad))
        XCTAssertNil(state.tidings(of: .commanderJoined(commander: theirs.id, house: 1), for: me))
        XCTAssertNil(state.tidings(of: .commanderRose(commander: 999, house: me, level: 2), for: me), "One no longer known")
    }
}
